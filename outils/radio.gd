extends Node
## LE BANC DE L'AUTORADIO (phase 10). Il vérifie ce qui, sinon, ne fait
## AUCUN BRUIT ET AUCUNE ERREUR : une station dont le nom de piste a une
## faute. Godot charge `res://sons/tavrne.ogg`, ne trouve rien, renvoie null,
## et `_fondre` sort sans un mot — la station est muette pour toujours.
##
##   godot --headless --path . res://outils/radio.tscn

var _fautes := 0

func _ready() -> void:
	print("── l'autoradio")
	_stations()
	_carrosseries()
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	get_tree().quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

func _stations() -> void:
	print("\n1. LES STATIONS ET LEURS PISTES")
	for i in Sons.STATIONS.size():
		var s: Dictionary = Sons.STATIONS[i]
		var piste := String(s["piste"])
		if piste == "":
			# Les deux stations sans piste sont VOULUES : la police (des voix)
			# et le silence.
			var prevue := i == Sons.STATION_POLICE or i == Sons.STATION_SILENCE
			_dire(prevue, "%-18s sans piste, et c'est voulu" % String(s["nom"]))
			continue
		var chemin := "res://sons/%s.ogg" % piste
		var flux := load(chemin) as AudioStream
		_dire(flux != null, "%-18s -> %s" % [String(s["nom"]), chemin])
	_dire(Sons.STATIONS.size() >= 4, "%d stations" % Sons.STATIONS.size())
	# ⚠ LA ROUE SE LIT, OU NE SERT À RIEN. En dessous de trois secteurs elle
	# n'a pas de sens ; au-delà de huit, les noms se marchent dessus et viser
	# devient un jeu d'adresse. C'est la contrainte qui plafonne le nombre de
	# stations qu'on peut ajouter — pas le nombre de morceaux qu'on possède.
	_dire(Sons.STATIONS.size() >= 3 and Sons.STATIONS.size() <= 8,
		"la roue reste lisible (%d secteurs)" % Sons.STATIONS.size())
	var noms_courts := true
	for s2 in Sons.STATIONS:
		if String(s2["nom"]).length() > 18:
			noms_courts = false
			print("   « %s » est trop long pour un secteur" % String(s2["nom"]))
	_dire(noms_courts, "et les noms tiennent dans leur secteur")

func _carrosseries() -> void:
	print("\n2. CHAQUE CARROSSERIE A LA SIENNE")
	var hors := 0
	for modele in Sons.STATION_DU_MODELE:
		var indice: int = Sons.STATION_DU_MODELE[modele]
		if indice < 0 or indice >= Sons.STATIONS.size():
			hors += 1
			print("   station %d hors table pour le modèle %d" % [indice, modele])
		if int(modele) < 0 or int(modele) >= FormesCarnage.MODELES_VOITURES.size():
			hors += 1
			print("   modèle %d inconnu" % int(modele))
	_dire(hors == 0, "les %d carrosseries citées existent, et leurs stations aussi"
		% Sons.STATION_DU_MODELE.size())
	# ⚠ Le silence ne doit être le DÉFAUT de personne : on monte en voiture,
	# la radio s'allume. Une carrosserie réglée sur « silence » d'usine, c'est
	# un joueur qui croit que la radio est cassée.
	var muettes := 0
	for modele in Sons.STATION_DU_MODELE:
		if int(Sons.STATION_DU_MODELE[modele]) == Sons.STATION_SILENCE:
			muettes += 1
	_dire(muettes == 0, "aucune carrosserie ne démarre sur le silence")
	# Et une carrosserie inconnue tombe sur la station de la ville, pas sur rien.
	_dire(Sons.station_du_modele(999) == 0, "un modèle inconnu tombe sur %s"
		% String(Sons.STATIONS[Sons.station_du_modele(999)]["nom"]))
	# Toutes les carrosseries du parc ont une station jouable.
	var couvertes := 0
	for m in FormesCarnage.MODELES_VOITURES.size():
		if Sons.station_du_modele(m) >= 0:
			couvertes += 1
	_dire(couvertes == FormesCarnage.MODELES_VOITURES.size(),
		"les %d carrosseries du parc ont une station" % couvertes)
