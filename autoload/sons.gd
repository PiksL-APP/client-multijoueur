extends Node
## Le son du jeu : des échantillons de rue en fichiers, une synthèse en filet
## de sécurité, les musiques et les ambiances en boucle.
##
## Les bruitages de Carnage viennent de `sons/sfx/` : 238 échantillons OGG
## mono 22 kHz — armes, moteurs, tôle, pas, voix de trottoir, radio de la
## police. Chacun est chargé au premier usage puis gardé : rien à attendre au
## démarrage, rien à télécharger pour un son qu'on n'entendra jamais.
##
## Les bruitages en synthèse : une banque de quelques dizaines de kilo-octets
## fabriquée en une trentaine de millisecondes, réglable en changeant un
## chiffre plutôt qu'en rouvrant un éditeur audio. Les musiques, elles, ne se
## synthétisent pas : ce sont les thèmes CC0 de Pixel-boy (Sparklin Labs),
## dans `sons/`, normalisés à -18 LUFS. Une musique par lieu, en fondu.
##
## Le navigateur refuse de jouer un son avant un geste de l'utilisateur. Ce
## n'est pas un problème ici : on ne fait de bruit qu'après le clic « Entrer
## dans le hub ».

const TAUX := 22050
const VOIX := 12                    ## sons simultanés
const FICHIER := "user://son.cfg"
const DOSSIER := "res://sons/sfx/%s.ogg"

## Les familles à variantes : un nom, plusieurs prises. Tirer au sort évite
## qu'une fusillade sonne comme le même claquement répété quarante fois.
const VARIANTES := {
	"alarme_vehicule": 2,
	"balle_mur": 3,
	"balle_vehicule": 3,
	"demarreur": 2,
	"flic_arme": 4,
	"flic_insiste": 7,
	"flic_stop": 7,
	"foule": 2,
	"klaxon": 4,
	"pas_beton": 4,
	"pas_bois": 4,
	"pas_herbe": 4,
	"pas_metal": 4,
	"voix_aide": 10,
	"voix_attention": 6,
	"voix_carjack": 5,
	"voix_cri": 11,
	"voix_grognement": 3,
	"voix_hey": 5,
	"voix_insulte": 8,
	"voix_menace": 10,
	"voix_rire": 4,
	"voix_surprise": 9,
}

## Les noms historiques de la banque de synthèse, redirigés vers les
## échantillons. Les jeux appellent toujours `jouer("choc")` ; ce qui sort a
## changé. Ce qui n'est pas ici — `clic`, `bip`, `portail` — reste synthétisé :
## l'ÉNIGME est un jeu abstrait, elle n'a rien à gagner à sonner comme une rue.
const ALIAS := {
	"choc": "choc_moyen",
	"ecrasement": "ecrase_pieton",
	"sirene": "sirene_lente",
	"klaxon": "klaxon",
	"cri": "voix_cri",
	"pas": "pas_beton",
	"porte": "portiere_ouvre",
}

## Ce qui doit tourner sans couture : moteurs, sirènes, alarmes, foule.
const BOUCLES := ["moteur_compact", "moteur_sport", "moteur_standard",
	"moteur_super", "moteur_camion", "moteur_van", "sirene_lente",
	"sirene_rapide", "alarme_banque", "alarme_prison", "alarme_vehicule_1",
	"alarme_vehicule_2", "foule_1", "foule_2", "feu", "riviere",
	"lance_flammes", "statique_radio"]

## Chargés d'avance : ceux qu'on entend dans la première seconde de jeu et
## ceux qui partent en rafale. Charger un fichier pendant un tir s'entend
## comme un raté d'image.
const NOYAU := ["tir_pistolet", "tir_mitraillette", "choc_doux", "choc_moyen",
	"choc_dur", "pas_beton_1", "pas_beton_2", "pas_beton_3", "pas_beton_4",
	"ecrase_pieton", "balle_mur_1", "balle_mur_2", "balle_mur_3",
	"moteur_standard"]

## Le moteur selon le châssis : la sportive siffle, le camion gronde.
const MOTEURS := {
	"compact": "moteur_compact", "sport": "moteur_sport",
	"standard": "moteur_standard", "super": "moteur_super",
	"camion": "moteur_camion", "van": "moteur_van",
}

var actif := true

var _banque: Dictionary = {}
var _voix: Array[AudioStreamPlayer] = []
var _prochaine := 0
var _moteur: AudioStreamPlayer
var _musique: AudioStreamPlayer
var _ambiance: AudioStreamPlayer
var _sirene: AudioStreamPlayer
var _radio: AudioStreamPlayer
var _echantillons: Dictionary = {}   ## cache fichier : nom -> AudioStream
var _musique_en_cours := ""
var _ambiance_en_cours := ""
var _moteur_en_cours := ""
var _rng := RandomNumberGenerator.new()
const MUSIQUE_DB := -10.0
const AMBIANCE_DB := -14.0

## Les sons d'INTERFACE, tirés du jeu de bruitages de la maison
## (`sons/interface/`) : ce sont des enregistrements, pas des ondes calculées
## comme le reste de la banque — un menu qui bipe en carré sonne comme un
## prototype, et celui-ci ne l'est plus.
const INTERFACE := ["haut", "bas", "gauche", "droite", "valider", "retour",
	"effacer", "frappe", "special"]

var _clavier: Array[AudioStreamPlayer] = []
var _prochain_clavier := 0

## Joue un son d'interface. Le tourniquet est à part de celui des bruitages
## de jeu : dans le menu des touches, on peut cliquer plus vite que le jeu
## ne tire, et il ne faut pas que l'un vide les voix de l'autre.
func interface(nom: String, volume_db: float = -8.0) -> void:
	if not actif or not nom in INTERFACE or _clavier.is_empty():
		return
	var lecteur := _clavier[_prochain_clavier]
	_prochain_clavier = (_prochain_clavier + 1) % _clavier.size()
	lecteur.stream = load("res://sons/interface/%s.ogg" % nom)
	lecteur.volume_db = volume_db
	lecteur.play()

func _ready() -> void:
	_rng.randomize()
	_charger_preference()
	_fabriquer_banque()
	for nom in NOYAU:
		_echantillon(nom)
	# Chaque lecteur part sur son bus : le curseur « effets » des options
	# règle alors un bus, pas seize lecteurs, et un son déjà lancé suit.
	for i in VOIX:
		var lecteur := AudioStreamPlayer.new()
		lecteur.bus = Reglages.BUS_EFFETS
		add_child(lecteur)
		_voix.append(lecteur)
	_moteur = AudioStreamPlayer.new()
	_moteur.stream = _flux_moteur("standard")
	_moteur.volume_db = -24.0
	_moteur.bus = Reglages.BUS_EFFETS
	add_child(_moteur)
	# La sirène a son lecteur à elle : une poursuite est un état, pas un
	# événement. Elle démarre, elle tient, elle s'arrête — sans que la file
	# des voix ne la coupe au premier coup de feu.
	_sirene = AudioStreamPlayer.new()
	_sirene.bus = Reglages.BUS_EFFETS
	_sirene.volume_db = -18.0
	add_child(_sirene)
	# La radio parle en bribes qui s'enchaînent : un lecteur, une file.
	_radio = AudioStreamPlayer.new()
	_radio.bus = Reglages.BUS_EFFETS
	_radio.volume_db = -12.0
	add_child(_radio)
	_musique = AudioStreamPlayer.new()
	_musique.bus = Reglages.BUS_MUSIQUE
	add_child(_musique)
	_ambiance = AudioStreamPlayer.new()
	_ambiance.bus = Reglages.BUS_MUSIQUE
	add_child(_ambiance)
	for i in 4:
		var lecteur := AudioStreamPlayer.new()
		lecteur.bus = Reglages.BUS_EFFETS
		add_child(lecteur)
		_clavier.append(lecteur)

## Lance la musique d'un lieu (`res://sons/<nom>.ogg`, en boucle), en fondu
## depuis la précédente. `""` arrête. Rejouer le même nom ne redémarre rien.
func musique(nom: String) -> void:
	if nom == _musique_en_cours:
		return
	_musique_en_cours = nom
	_fondre(_musique, nom, MUSIQUE_DB)

func ambiance(nom: String) -> void:
	if nom == _ambiance_en_cours:
		return
	_ambiance_en_cours = nom
	_fondre(_ambiance, nom, AMBIANCE_DB)

func _fondre(lecteur: AudioStreamPlayer, nom: String, volume_db: float) -> void:
	var tween := create_tween()
	if lecteur.playing:
		tween.tween_property(lecteur, "volume_db", -40.0, 0.8)
		tween.tween_callback(lecteur.stop)
	if nom != "" and actif:
		var flux := load("res://sons/%s.ogg" % nom) as AudioStream
		if flux == null:
			return
		tween.tween_callback(func() -> void:
			lecteur.stream = flux
			lecteur.volume_db = -40.0
			lecteur.play())
		tween.tween_property(lecteur, "volume_db", volume_db, 1.2)

func _reprendre_musiques() -> void:
	var m := _musique_en_cours
	var a := _ambiance_en_cours
	_musique_en_cours = ""
	_ambiance_en_cours = ""
	musique(m)
	ambiance(a)

func basculer() -> bool:
	actif = not actif
	if not actif:
		arreter_moteur()
		if _sirene:
			_sirene.stop()
		if _radio:
			_radio.stop()
		_musique.stop()
		_ambiance.stop()
	else:
		_reprendre_musiques()
	var fichier := ConfigFile.new()
	fichier.set_value("son", "actif", actif)
	fichier.save(FICHIER)
	return actif

func _charger_preference() -> void:
	var fichier := ConfigFile.new()
	if fichier.load(FICHIER) == OK:
		actif = bool(fichier.get_value("son", "actif", true))

## `hauteur` multiplie la fréquence de lecture : un même échantillon sert de
## grave et d'aigu, ce qui évite d'en fabriquer dix variantes.
##
## L'échantillon passe avant la synthèse ; un nom inconnu des deux ne fait
## rien. Un jeu qui demande un son absent doit rester silencieux, pas tomber.
func jouer(nom: String, hauteur: float = 1.0, volume_db: float = -6.0) -> void:
	if not actif:
		return
	var flux := _echantillon(_resoudre(nom))
	if flux == null:
		if not _banque.has(nom):
			return
		flux = _banque[nom]
	# Tourniquet de voix : couper le son le plus ancien vaut mieux qu'ignorer
	# le nouveau. Dans Carnage, six écrasements peuvent tomber sur la même
	# seconde, et c'est le dernier qui porte l'information.
	var lecteur := _voix[_prochaine]
	_prochaine = (_prochaine + 1) % VOIX
	lecteur.stream = flux
	lecteur.pitch_scale = clamp(hauteur, 0.3, 3.0)
	lecteur.volume_db = volume_db
	lecteur.play()

## Une réplique de trottoir : même famille, prise au hasard, hauteur dérivée.
## Deux passants qui crient exactement pareil s'entendent comme un défaut ; un
## demi-ton d'écart et ce sont deux personnes.
func voix(famille: String, volume_db: float = -10.0) -> void:
	jouer(famille, _rng.randf_range(0.9, 1.12), volume_db)

# ------------------------------------------------------------ échantillons

## Charge un échantillon au premier usage et le garde. `null` si le fichier
## n'existe pas — l'appelant retombe alors sur la synthèse.
func _echantillon(nom: String) -> AudioStream:
	if _echantillons.has(nom):
		return _echantillons[nom]
	var chemin := DOSSIER % nom
	var flux: AudioStream = null
	if ResourceLoader.exists(chemin):
		flux = load(chemin) as AudioStream
	if flux is AudioStreamOggVorbis:
		(flux as AudioStreamOggVorbis).loop = BOUCLES.has(nom)
	_echantillons[nom] = flux
	return flux

## Résout un nom d'appel en nom de fichier : l'alias d'abord, puis le tirage
## de variante. `voix_cri` devient `voix_cri_7`.
func _resoudre(nom: String) -> String:
	var vrai: String = ALIAS.get(nom, nom)
	if VARIANTES.has(vrai):
		vrai = "%s_%d" % [vrai, _rng.randi_range(1, int(VARIANTES[vrai]))]
	return vrai

# ------------------------------------------------------------ moteur

func _flux_moteur(type: String) -> AudioStream:
	var flux := _echantillon(String(MOTEURS.get(type, "moteur_standard")))
	return flux if flux != null else _banque.get("moteur")

## `type` choisit le grain du moteur : « sport », « camion », « super »…
## Changer de véhicule change le son, et c'est ce qui fait qu'en voler un
## autre s'entend avant de se voir au compteur.
func demarrer_moteur(type: String = "standard") -> void:
	if not actif or _moteur == null:
		return
	if type != _moteur_en_cours:
		_moteur_en_cours = type
		var flux := _flux_moteur(type)
		if flux != null:
			_moteur.stream = flux
	if not _moteur.playing:
		_moteur.play()

func arreter_moteur() -> void:
	if _moteur and _moteur.playing:
		_moteur.stop()

## Régime moteur, de 0 à 1. Le volume monte moins vite que la hauteur : un
## moteur qui gagne surtout en aigu s'entend comme une accélération, alors
## qu'un moteur qui gagne surtout en volume s'entend comme un défaut.
func regime(part: float) -> void:
	if _moteur == null or not actif:
		return
	if not _moteur.playing:
		demarrer_moteur(_moteur_en_cours if _moteur_en_cours != "" else "standard")
	_moteur.pitch_scale = 0.75 + clamp(part, 0.0, 1.0) * 1.15
	_moteur.volume_db = -30.0 + clamp(part, 0.0, 1.0) * 11.0

# ------------------------------------------------------------ police

## La sirène d'une poursuite : un état, pas un événement. `niveau` à 0
## l'éteint ; à trois étoiles elle passe au régime rapide, ce qui s'entend
## avant que la voiture n'apparaisse au coin de la rue.
func sirene(niveau: int, volume_db: float = -20.0) -> void:
	if _sirene == null:
		return
	if niveau <= 0 or not actif:
		if _sirene.playing:
			_sirene.stop()
		return
	var flux := _echantillon("sirene_rapide" if niveau >= 3 else "sirene_lente")
	if flux == null:
		return
	if _sirene.stream != flux:
		_sirene.stream = flux
		_sirene.play()
	elif not _sirene.playing:
		_sirene.play()
	_sirene.pitch_scale = 0.94 + 0.04 * float(niveau)
	_sirene.volume_db = volume_db + min(6.0, 1.5 * float(niveau))

## Le dispatch : la radio de la police assemble des bribes enregistrées mot à
## mot — « all units », « respond to », un code, une zone, un cap. C'est ainsi
## qu'elle parlait dans le jeu dont viennent ces bruitages, et c'est ce qui
## fait qu'une poursuite se RACONTE au lieu de seulement hurler.
##
## Les bribes sont montées en `AudioStreamPlaylist` et données au lecteur en
## une fois. Les enchaîner à la main sur le signal `finished` marchait, mais
## relancer une lecture au milieu du mixage fait râler le décodeur à chaque
## mot ; ici, c'est le serveur audio qui enchaîne.
func radio_police(niveau: int, zone: int = 0, cap: String = "") -> void:
	if not actif or _radio == null or _radio.playing:
		return
	var noms: Array[String] = ["radio_all_units", "radio_spacer_a"]
	if niveau >= 4:
		noms.append("radio_swat_team" if niveau == 4 else "radio_armed_forces")
	noms.append("radio_respond_to")
	noms.append("radio_a_ten")
	var codes: Array = [90, 91, 96, 24, 28] if niveau >= 3 else [10, 12, 14, 32]
	noms.append("radio_code_%d" % int(codes[_rng.randi() % codes.size()]))
	noms.append("radio_in_vincinity_of")
	noms.append("radio_zone_%d" % clampi(zone if zone > 0 else _rng.randi_range(1, 12), 1, 12))
	if cap != "":
		noms.append("radio_heading")
		noms.append("radio_%s" % cap)
	if niveau >= 3:
		noms.append("radio_suspect")
		noms.append("radio_is_armed")
	# Le blanc de fin : la radio raccroche sur son souffle, et la liste ne se
	# termine pas au milieu d'un mot.
	noms.append("radio_spacer_b")

	var bribes: Array[AudioStream] = []
	for nom in noms:
		var flux := _echantillon(nom)
		if flux != null:
			bribes.append(flux)
	if bribes.is_empty():
		return
	var message := AudioStreamPlaylist.new()
	message.loop = false
	message.fade_time = 0.0
	message.shuffle = false
	message.stream_count = mini(bribes.size(), 64)
	for i in message.stream_count:
		message.set_list_stream(i, bribes[i])
	_radio.stream = message
	_radio.play()

# ------------------------------------------------------------ synthèse

func _fabriquer_banque() -> void:
	_banque["clic"] = _rendre(_carre(880.0, 0.045, 0.35), 0.045)
	_banque["bip"] = _rendre(_sinus(620.0, 0.10, 0.5), 0.10)
	_banque["depart"] = _rendre(_sinus(1240.0, 0.22, 0.55), 0.22)
	_banque["dalle"] = _rendre(_carre(520.0, 0.07, 0.4), 0.07)
	_banque["porte"] = _rendre(_glissando(190.0, 620.0, 0.42, 0.4), 0.42)
	_banque["portail"] = _rendre(_accord([110.0, 164.8, 220.0], 0.9, 0.35), 0.9)
	_banque["fin"] = _rendre(_arpege([523.0, 659.0, 784.0], 0.16, 0.45), 0.48)
	_banque["choc"] = _rendre(_impact(140.0, 0.16, 0.7), 0.16)
	_banque["ecrasement"] = _rendre(_ecrasement(), 0.30)
	# La sirène : deux glissandos collés bout à bout. Un son de police qui ne
	# monte ET ne descend pas se confond avec une alarme de four.
	var sirene := _glissando(720.0, 1180.0, 0.30, 0.30)
	sirene.append_array(_glissando(1180.0, 720.0, 0.30, 0.30))
	_banque["sirene"] = _rendre(sirene, 0.60)
	# Le klaxon : deux notes tenues, une tierce — un seul son carré se prend pour
	# une alarme. Le cri : un glissando qui tombe. Le battement : la pale de
	# l'hélicoptère, un coup sourd qu'on répète.
	_banque["klaxon"] = _rendre(_accord([349.0, 440.0], 0.28, 0.42), 0.28)
	_banque["cri"] = _rendre(_glissando(980.0, 420.0, 0.34, 0.30), 0.34)
	_banque["battement"] = _rendre(_impact(62.0, 0.12, 0.75), 0.12)
	_banque["moteur"] = _rendre_boucle(_moteur_echantillon(), 0.5)
	# Le pas : un coup sourd très court. Joué grave dehors, plus sec dedans.
	_banque["pas"] = _rendre(_impact(210.0, 0.05, 0.35), 0.05)

func _enveloppe(i: int, total: int, attaque: float, extinction: float) -> float:
	var t := float(i) / float(total)
	var montee: float = 1.0 if attaque <= 0.0 else min(1.0, t / attaque)
	var descente: float = pow(1.0 - t, extinction * 8.0)
	return montee * descente

func _sinus(frequence: float, duree: float, force: float) -> PackedFloat32Array:
	var total := int(duree * TAUX)
	var e := PackedFloat32Array()
	e.resize(total)
	for i in total:
		e[i] = sin(TAU * frequence * float(i) / TAUX) * force * _enveloppe(i, total, 0.01, 0.45)
	return e

func _carre(frequence: float, duree: float, force: float) -> PackedFloat32Array:
	var total := int(duree * TAUX)
	var e := PackedFloat32Array()
	e.resize(total)
	for i in total:
		var phase := fmod(frequence * float(i) / TAUX, 1.0)
		e[i] = (1.0 if phase < 0.5 else -1.0) * force * _enveloppe(i, total, 0.005, 0.6)
	return e

func _glissando(depart: float, arrivee: float, duree: float, force: float) -> PackedFloat32Array:
	var total := int(duree * TAUX)
	var e := PackedFloat32Array()
	e.resize(total)
	var phase := 0.0
	for i in total:
		var t := float(i) / float(total)
		phase += TAU * lerp(depart, arrivee, t) / TAUX
		e[i] = sin(phase) * force * _enveloppe(i, total, 0.05, 0.35)
	return e

func _accord(frequences: Array, duree: float, force: float) -> PackedFloat32Array:
	var total := int(duree * TAUX)
	var e := PackedFloat32Array()
	e.resize(total)
	for i in total:
		var somme := 0.0
		for f in frequences:
			somme += sin(TAU * float(f) * float(i) / TAUX)
		e[i] = somme / frequences.size() * force * _enveloppe(i, total, 0.25, 0.25)
	return e

func _arpege(frequences: Array, par_note: float, force: float) -> PackedFloat32Array:
	var e := PackedFloat32Array()
	for f in frequences:
		e.append_array(_sinus(float(f), par_note, force))
	return e

## Un impact, c'est du bruit qui s'éteint vite sur une basse courte. Le bruit
## est lissé sur trois échantillons : brut, il siffle comme une friture.
func _impact(grave: float, duree: float, force: float) -> PackedFloat32Array:
	var total := int(duree * TAUX)
	var e := PackedFloat32Array()
	e.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var precedent := 0.0
	for i in total:
		var bruit := rng.randf_range(-1.0, 1.0)
		precedent = lerp(precedent, bruit, 0.35)
		var basse := sin(TAU * grave * float(i) / TAUX)
		e[i] = (precedent * 0.55 + basse * 0.7) * force * _enveloppe(i, total, 0.002, 0.9)
	return e

func _ecrasement() -> PackedFloat32Array:
	var total := int(0.30 * TAUX)
	var e := PackedFloat32Array()
	e.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var precedent := 0.0
	var phase := 0.0
	for i in total:
		var t := float(i) / float(total)
		var bruit := rng.randf_range(-1.0, 1.0)
		precedent = lerp(precedent, bruit, 0.22)
		# La basse descend : c'est ce glissement vers le grave qui fait
		# entendre quelque chose qui s'écrase plutôt qu'un simple choc.
		phase += TAU * lerp(300.0, 70.0, t) / TAUX
		e[i] = (precedent * 0.7 + sin(phase) * 0.6) * 0.8 * _enveloppe(i, total, 0.004, 0.5)
	return e

func _moteur_echantillon() -> PackedFloat32Array:
	# Une demi-seconde bouclée. La fréquence est choisie pour que la boucle
	# tombe juste : 70 Hz sur 0,5 s font exactement 35 périodes, sans quoi on
	# entend un clic à chaque tour.
	var total := int(0.5 * TAUX)
	var e := PackedFloat32Array()
	e.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var precedent := 0.0
	for i in total:
		var t := float(i) / TAUX
		var dent := fmod(70.0 * t, 1.0) * 2.0 - 1.0
		var harmonique := sin(TAU * 140.0 * t) * 0.25
		precedent = lerp(precedent, rng.randf_range(-1.0, 1.0), 0.08)
		e[i] = (dent * 0.5 + harmonique + precedent * 0.18) * 0.5
	return e

func _rendre(echantillons: PackedFloat32Array, _duree: float) -> AudioStreamWAV:
	return _vers_wav(echantillons, false)

func _rendre_boucle(echantillons: PackedFloat32Array, _duree: float) -> AudioStreamWAV:
	return _vers_wav(echantillons, true)

func _vers_wav(echantillons: PackedFloat32Array, boucle: bool) -> AudioStreamWAV:
	var octets := PackedByteArray()
	octets.resize(echantillons.size() * 2)
	for i in echantillons.size():
		var valeur := int(clamp(echantillons[i], -1.0, 1.0) * 32767.0)
		octets.encode_s16(i * 2, valeur)
	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = TAUX
	flux.stereo = false
	flux.data = octets
	if boucle:
		flux.loop_mode = AudioStreamWAV.LOOP_FORWARD
		flux.loop_begin = 0
		flux.loop_end = echantillons.size()
	return flux
