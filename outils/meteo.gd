extends SceneTree
## LE BANC DE LA MÉTÉO : le tirage est le même pour tout le monde, les jauges
## se fondent sans à-coup, un temps forcé tient, et le bruit de pluie a la
## bonne longueur.
##
##   godot --headless -s outils/meteo.gd

var _fautes := 0

func _init() -> void:
	_tirage()
	_fondu()
	_force()
	_bruit()
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

func _tirage() -> void:
	print("\n1. LE TIRAGE")
	MeteoCarnage.meteo_forcee = -1
	var comptes := {}
	for k in 2000:
		var t := MeteoCarnage.temps_au_creneau(k)
		comptes[t] = int(comptes.get(t, 0)) + 1
	for t in MeteoCarnage.NOMS.size():
		print("   %-11s %4d créneaux sur 2000" % [MeteoCarnage.nom_du_temps(t), int(comptes.get(t, 0))])
	_dire(comptes.size() == MeteoCarnage.NOMS.size(), "les cinq temps sortent")
	_dire(int(comptes.get(MeteoCarnage.CLAIR, 0)) > int(comptes.get(MeteoCarnage.ORAGE, 0)) * 2,
		"le beau temps est au moins deux fois plus fréquent que l'orage")
	# Deux machines, le même créneau : le même temps — c'est ce qui dispense
	# la météo de passer par le réseau.
	var pareil := true
	for k in 50:
		if MeteoCarnage.temps_au_creneau(k) != MeteoCarnage.temps_au_creneau(k):
			pareil = false
	_dire(pareil, "et le tirage d'un créneau ne dépend que du créneau")

func _fondu() -> void:
	print("\n2. LE FONDU")
	MeteoCarnage.meteo_forcee = -1
	# On cherche un changement de temps et on regarde les jauges glisser.
	var k := 0
	while k < 500 and MeteoCarnage.temps_au_creneau(k) == MeteoCarnage.temps_au_creneau(k + 1):
		k += 1
	_dire(k < 500, "deux créneaux voisins différents (créneaux %d et %d : %s -> %s)" % [k, k + 1,
		MeteoCarnage.nom_du_temps(MeteoCarnage.temps_au_creneau(k)),
		MeteoCarnage.nom_du_temps(MeteoCarnage.temps_au_creneau(k + 1))])
	var debut := float(k + 1) * MeteoCarnage.CYCLE
	var saut_max := 0.0
	var precedent := MeteoCarnage.jauges(debut - 0.5)
	for i in range(1, 200):
		var j := MeteoCarnage.jauges(debut - 0.5 + float(i) * 0.5)
		for cle in ["nuages", "pluie", "brume", "orage"]:
			saut_max = maxf(saut_max, absf(float(j[cle]) - float(precedent[cle])))
		precedent = j
	_dire(saut_max < 0.06, "aucune jauge ne saute de plus de 0,06 par demi-seconde (max %.3f)" % saut_max)
	var apres := MeteoCarnage.jauges(debut + MeteoCarnage.TRANSITION + 1.0)
	var cible: Dictionary = MeteoCarnage.TEMPS[MeteoCarnage.temps_au_creneau(k + 1)]
	_dire(absf(float(apres["pluie"]) - float(cible["pluie"])) < 0.001
		and absf(float(apres["nuages"]) - float(cible["nuages"])) < 0.001,
		"la transition finie, les jauges sont celles du nouveau temps")

func _force() -> void:
	print("\n3. LE TEMPS FORCÉ")
	MeteoCarnage.meteo_forcee = MeteoCarnage.ORAGE
	var j := MeteoCarnage.jauges(123456.0)
	_dire(float(j["orage"]) == 1.0 and float(j["pluie"]) == 1.0, "--meteo=orage : orage et pluie à fond, tout de suite")
	_dire(MeteoCarnage.indice_du_temps("brouillard") == MeteoCarnage.BROUILLARD
		and MeteoCarnage.indice_du_temps("pluie") == MeteoCarnage.PLUIE, "les noms se relisent")
	_dire(MeteoCarnage.indice_du_temps("neige") == -1, "un nom inconnu rend -1 (et le ciel reste à l'horloge)")
	MeteoCarnage.meteo_forcee = -1

func _bruit() -> void:
	print("\n4. LE BRUIT DE PLUIE")
	var m := MeteoCarnage.new()
	var flux: AudioStreamWAV = m._bruit_de_pluie()
	_dire(flux.data.size() == MeteoCarnage.TAUX * 4 * 2, "quatre secondes de 16 bits (%d octets)" % flux.data.size())
	_dire(flux.loop_mode == AudioStreamWAV.LOOP_FORWARD and flux.loop_end == MeteoCarnage.TAUX * 4, "en boucle sur toute sa longueur")
	# Pas un silence, pas une saturation : la crête entre 0,3 et 1,0.
	var crete := 0
	for i in range(0, flux.data.size(), 2 * 37):
		crete = maxi(crete, absi(flux.data.decode_s16(i)))
	_dire(crete > 9000 and crete <= 30000, "une crête raisonnable (%d)" % crete)
	m.free()
