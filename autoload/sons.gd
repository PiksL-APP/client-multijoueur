extends Node
## Le son du jeu : les bruitages sont synthétisés au démarrage, les musiques
## et les ambiances viennent de fichiers.
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

var actif := true

var _banque: Dictionary = {}
var _voix: Array[AudioStreamPlayer] = []
var _prochaine := 0
var _moteur: AudioStreamPlayer
var _musique: AudioStreamPlayer
var _ambiance: AudioStreamPlayer
var _musique_en_cours := ""
var _ambiance_en_cours := ""
## Le thème du menu doit s'entendre : à -10 dB derrière un bus « Musique » à
## soixante pour cent, il ne restait qu'un murmure. C'est le curseur des
## options qui décide du reste.
const MUSIQUE_DB := -5.0
const AMBIANCE_DB := -14.0

## Les sons d'INTERFACE, tirés du jeu de bruitages de la maison
## (`sons/interface/`) : ce sont des enregistrements, pas des ondes calculées
## comme le reste de la banque — un menu qui bipe en carré sonne comme un
## prototype, et celui-ci ne l'est plus.
const INTERFACE := ["haut", "bas", "gauche", "droite", "valider", "retour",
	"effacer", "frappe", "special"]

## Le thème du jeu, celui qui tourne sous le menu et tant qu'on n'est pas
## descendu en ville. Il est nommé ici et pas dans chaque écran : trois écrans
## qui demandent la même piste ne la redémarrent pas (`musique` compare au nom
## en cours), mais il faut encore que ce soit le MÊME nom des trois côtés.
const THEME := "vice-city-drift"

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

## Les navigateurs interdisent au son de partir avant que l'utilisateur n'ait
## touché la page : la musique lancée au démarrage du menu jouait dans un
## contexte audio suspendu — elle avançait, muette, et restait muette une fois
## le contexte réveillé. On la RELANCE donc au premier geste, quel qu'il soit.
var _debloque := false

func _input(evenement: InputEvent) -> void:
	if _debloque:
		return
	if not (evenement is InputEventKey or evenement is InputEventMouseButton
			or evenement is InputEventScreenTouch):
		return
	if not evenement.is_pressed():
		return
	_debloque = true
	_reprendre_musiques()

func _ready() -> void:
	_charger_preference()
	_fabriquer_banque()
	# Chaque lecteur part sur son bus : le curseur « effets » des options
	# règle alors un bus, pas seize lecteurs, et un son déjà lancé suit.
	for i in VOIX:
		var lecteur := AudioStreamPlayer.new()
		lecteur.bus = Reglages.BUS_EFFETS
		add_child(lecteur)
		_voix.append(lecteur)
	_moteur = AudioStreamPlayer.new()
	_moteur.stream = _banque["moteur"]
	_moteur.volume_db = -24.0
	_moteur.bus = Reglages.BUS_EFFETS
	add_child(_moteur)
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
func jouer(nom: String, hauteur: float = 1.0, volume_db: float = -6.0) -> void:
	if not actif or not _banque.has(nom):
		return
	# Tourniquet de voix : couper le son le plus ancien vaut mieux qu'ignorer
	# le nouveau. Dans Carnage, six écrasements peuvent tomber sur la même
	# seconde, et c'est le dernier qui porte l'information.
	var lecteur := _voix[_prochaine]
	_prochaine = (_prochaine + 1) % VOIX
	lecteur.stream = _banque[nom]
	lecteur.pitch_scale = clamp(hauteur, 0.3, 3.0)
	lecteur.volume_db = volume_db
	lecteur.play()

func demarrer_moteur() -> void:
	if actif and not _moteur.playing:
		_moteur.play()

func arreter_moteur() -> void:
	if _moteur and _moteur.playing:
		_moteur.stop()

## Régime moteur, de 0 à 1. Le volume monte moins vite que la hauteur : un
## moteur qui gagne surtout en aigu s'entend comme une accélération, alors
## qu'un moteur qui gagne surtout en volume s'entend comme un défaut.
func regime(part: float) -> void:
	if not _moteur:
		return
	if not actif:
		return
	if not _moteur.playing:
		demarrer_moteur()
	_moteur.pitch_scale = 0.75 + clamp(part, 0.0, 1.0) * 1.15
	_moteur.volume_db = -30.0 + clamp(part, 0.0, 1.0) * 11.0

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
