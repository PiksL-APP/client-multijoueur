extends Node
## Les réglages du joueur : son, image, touches. Écrits dans `user://`, donc
## dans le stockage du navigateur — ils suivent la machine, pas le compte.
##
## Un seul endroit décide, et tout le reste vient LIRE ici. C'est pour ça que
## les valeurs sont des variables simples plutôt que des accesseurs : un écran
## qui règle le volume écrit `Reglages.volume_effets = 0.5` puis appelle
## `appliquer_le_son()`, et le reste du jeu n'a rien à savoir.
##
## Les volumes passent par trois bus audio créés au démarrage — « Musique » et
## « Effets » branchés sur « Master ». Régler un bus vaut mieux que parcourir
## les lecteurs : un son déjà en train de jouer suit le curseur.

const FICHIER := "user://reglages.cfg"

const BUS_MUSIQUE := "Musique"
const BUS_EFFETS := "Effets"

## Les valeurs de sortie d'usine, en un seul endroit : c'est ce que « tout
## remettre à zéro » restaure, et ce que porte un fichier de réglages absent.
const USINE := {
	"volume_general": 0.8, "volume_musique": 0.6, "volume_effets": 0.9,
	"effets": true, "ombres": true, "finesse": 1.0, "plein_ecran": false,
}

# ── Son ────────────────────────────────────────────────────────────────────
var volume_general: float = USINE["volume_general"]
var volume_musique: float = USINE["volume_musique"]
var volume_effets: float = USINE["volume_effets"]

# ── Image ──────────────────────────────────────────────────────────────────
## L'effet maquette (tilt-shift) et les fondus de couleur.
var effets: bool = USINE["effets"]
## Les ombres portées. C'est le premier réglage à couper sur une machine lente.
var ombres: bool = USINE["ombres"]
## Résolution du rendu 3D : 0,75 rend en 3/4 et remonte l'image — deux fois
## moins de pixels à calculer, une netteté à peine entamée sur du voxel.
var finesse: float = USINE["finesse"]
var plein_ecran: bool = USINE["plein_ecran"]

# ── Touches ────────────────────────────────────────────────────────────────
## Les codes sont PHYSIQUES : `KEY_W` tombe sur le Z d'un clavier AZERTY.
## Le libellé affiché, lui, est calculé à partir de la disposition réelle du
## clavier — un joueur AZERTY lit bien « Z » sous « avancer ».
const DEFAUTS := {
	"avancer": KEY_W,
	"reculer": KEY_S,
	"gauche": KEY_A,
	"droite": KEY_D,
	"tir": KEY_SPACE,
	"action": KEY_E,
	"affaire": KEY_F,
	"klaxon": KEY_H,
	"carte": KEY_TAB,
	"tchat": KEY_T,
}

## Ce qu'on écrit à côté de la touche dans l'écran des options.
const LIBELLES := {
	"avancer": "Avancer",
	"reculer": "Reculer",
	"gauche": "Aller à gauche",
	"droite": "Aller à droite",
	"tir": "Tirer / foncer",
	"action": "Monter en voiture, entrer",
	"affaire": "Acheter, déposer, se soigner",
	"klaxon": "Klaxonner",
	"carte": "Voir la carte",
	"tchat": "Parler",
}

## action -> code physique. Toujours complet : `charger` remplit les manques
## avec les défauts, pour qu'une action ajoutée plus tard ne casse pas un
## fichier de réglages écrit par une version précédente.
var touches: Dictionary = {}

func _ready() -> void:
	_creer_les_bus()
	touches = DEFAUTS.duplicate()
	charger()
	appliquer_tout()

## Le code physique d'une action, ou son défaut si elle n'a jamais été réglée.
func touche(action: String) -> int:
	return int(touches.get(action, DEFAUTS.get(action, KEY_NONE)))

func enfoncee(action: String) -> bool:
	return Input.is_physical_key_pressed(touche(action) as Key)

## Le nom lisible d'une touche, tel qu'il est GRAVÉ sur le clavier du joueur.
## `KEY_W` sur un clavier français, c'est la touche Z : afficher « W » dans
## les options enverrait tout le monde chercher au mauvais endroit.
func nom_de_touche(action: String) -> String:
	var code := touche(action)
	if code == KEY_NONE:
		return "—"
	var etiquette := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code as Key))
	if etiquette == "":
		etiquette = OS.get_keycode_string(code as Key)
	return String(NOMS_FR.get(etiquette, etiquette))

## Le moteur nomme les touches en anglais. Les lettres et les chiffres se
## lisent partout, les autres non : « Space » n'est pas « Espace ».
const NOMS_FR := {
	"Space": "Espace", "Tab": "Tabulation", "Enter": "Entrée", "Escape": "Échap",
	"Shift": "Maj", "Ctrl": "Ctrl", "Alt": "Alt", "Backspace": "Retour arrière",
	"Left": "Gauche", "Right": "Droite", "Up": "Haut", "Down": "Bas",
	"Insert": "Inser", "Delete": "Suppr", "Home": "Début", "End": "Fin",
	"PageUp": "Page haut", "PageDown": "Page bas",
}

func definir_touche(action: String, code: int) -> void:
	# Une touche ne sert qu'une fois : celle qu'on vient d'attribuer est
	# retirée de l'action qui la détenait, sinon deux actions se déclenchent
	# ensemble et le joueur croit à un bug.
	for autre in touches.keys():
		if autre != action and int(touches[autre]) == code:
			touches[autre] = KEY_NONE
	touches[action] = code
	ecrire()

## Tout remettre en sortie d'usine : le son, l'image et les touches.
func remettre_tout() -> void:
	volume_general = USINE["volume_general"]
	volume_musique = USINE["volume_musique"]
	volume_effets = USINE["volume_effets"]
	effets = USINE["effets"]
	ombres = USINE["ombres"]
	finesse = USINE["finesse"]
	plein_ecran = USINE["plein_ecran"]
	touches = DEFAUTS.duplicate()
	appliquer_tout()
	ecrire()

func remettre_les_touches() -> void:
	touches = DEFAUTS.duplicate()
	ecrire()

# ── Application ────────────────────────────────────────────────────────────

func appliquer_tout() -> void:
	appliquer_le_son()
	appliquer_l_image()

func appliquer_le_son() -> void:
	_volume_de_bus("Master", volume_general)
	_volume_de_bus(BUS_MUSIQUE, volume_musique)
	_volume_de_bus(BUS_EFFETS, volume_effets)

func appliquer_l_image() -> void:
	var fenetre := get_viewport()
	if fenetre != null:
		fenetre.scaling_3d_scale = clampf(finesse, 0.5, 1.0)
	# Le plein écran n'existe pas dans une page web au sens du moteur : c'est
	# le navigateur qui décide, et il exige un geste de l'utilisateur. Le
	# bouton des options en est un, donc l'appel passe.
	var vise := DisplayServer.WINDOW_MODE_FULLSCREEN if plein_ecran else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != vise:
		DisplayServer.window_set_mode(vise)

func _volume_de_bus(nom: String, part: float) -> void:
	var indice := AudioServer.get_bus_index(nom)
	if indice < 0:
		return
	# Sous 1 %, on coupe : `linear_to_db(0)` vaut moins l'infini et le moteur
	# garde alors un souffle résiduel sur certains pilotes.
	AudioServer.set_bus_mute(indice, part <= 0.01)
	AudioServer.set_bus_volume_db(indice, linear_to_db(clampf(part, 0.01, 1.0)))

func _creer_les_bus() -> void:
	for nom in [BUS_MUSIQUE, BUS_EFFETS]:
		if AudioServer.get_bus_index(nom) >= 0:
			continue
		var indice := AudioServer.bus_count
		AudioServer.add_bus(indice)
		AudioServer.set_bus_name(indice, nom)
		AudioServer.set_bus_send(indice, "Master")

# ── Fichier ────────────────────────────────────────────────────────────────

## Les réglages posés dans la PAGE (le kit de la maquette tient les options
## dans le navigateur). Ses volumes vont de 0 à 100, sa finesse aussi ; ses
## touches sont des libellés, qu'on retraduit en codes physiques.
func prendre_de_la_page(choix: Dictionary) -> void:
	if choix.has("general"):
		volume_general = clampf(float(choix["general"]) / 100.0, 0.0, 1.0)
	if choix.has("musique"):
		volume_musique = clampf(float(choix["musique"]) / 100.0, 0.0, 1.0)
	if choix.has("effets_son"):
		volume_effets = clampf(float(choix["effets_son"]) / 100.0, 0.0, 1.0)
	if choix.has("effets"):
		effets = bool(choix["effets"])
	if choix.has("ombres"):
		ombres = bool(choix["ombres"])
	if choix.has("finesse"):
		finesse = clampf(float(choix["finesse"]) / 100.0, 0.5, 1.0)
	if choix.has("plein_ecran"):
		plein_ecran = bool(choix["plein_ecran"])
	var touches_page = choix.get("touches", null)
	if touches_page is Array:
		var ordre := ["avancer", "reculer", "gauche", "droite", "tir", "action", "carte"]
		# Le kit liste : avancer, reculer, gauche, droite, sauter, sprint,
		# interagir, carte. « Sauter » est notre tir, « interagir » notre
		# action ; le sprint n'a pas d'équivalent, on le saute.
		var vers := [0, 1, 2, 3, 4, 6, 7]
		for i in ordre.size():
			if vers[i] < (touches_page as Array).size():
				var code := _code_de_libelle(String((touches_page as Array)[vers[i]]))
				if code != KEY_NONE:
					touches[ordre[i]] = code
	appliquer_tout()
	ecrire()

## Le chemin inverse de `nom_de_touche` : d'un libellé affiché au code. Le kit
## affiche les libellés QWERTY (W, S, A, D), qui SONT nos codes physiques —
## il n'y a donc rien à retourner, seulement à traduire les noms français.
func _code_de_libelle(libelle: String) -> int:
	var propre := libelle.strip_edges()
	for anglais in NOMS_FR:
		if String(NOMS_FR[anglais]) == propre:
			propre = anglais
			break
	return OS.find_keycode_from_string(propre)

func charger() -> void:
	var fichier := ConfigFile.new()
	if fichier.load(FICHIER) != OK:
		return
	volume_general = float(fichier.get_value("son", "general", volume_general))
	volume_musique = float(fichier.get_value("son", "musique", volume_musique))
	volume_effets = float(fichier.get_value("son", "effets", volume_effets))
	effets = bool(fichier.get_value("image", "effets", effets))
	ombres = bool(fichier.get_value("image", "ombres", ombres))
	finesse = float(fichier.get_value("image", "finesse", finesse))
	plein_ecran = bool(fichier.get_value("image", "plein_ecran", plein_ecran))
	for action in DEFAUTS:
		touches[action] = int(fichier.get_value("touches", action, DEFAUTS[action]))

func ecrire() -> void:
	var fichier := ConfigFile.new()
	fichier.set_value("son", "general", volume_general)
	fichier.set_value("son", "musique", volume_musique)
	fichier.set_value("son", "effets", volume_effets)
	fichier.set_value("image", "effets", effets)
	fichier.set_value("image", "ombres", ombres)
	fichier.set_value("image", "finesse", finesse)
	fichier.set_value("image", "plein_ecran", plein_ecran)
	for action in touches:
		fichier.set_value("touches", action, int(touches[action]))
	fichier.save(FICHIER)
