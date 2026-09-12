extends Node
## Porte un seul écran à la fois et fait la connexion au démarrage.

## ⚠ UN SEUL JEU. Le projet a porté un hub à portails et trois jeux (ÉNIGME,
## la ferme, BOUSCULADE) ; il ne porte plus que CARNAGE. Le hub, les autres
## jeux et l'écran de résultats ont été retirés, et le SALON est devenu
## l'écran d'accueil : on démarre dessus, on y revient à la fin d'une manche.
##
## Ce qui reste à côté du jeu : le choix du pseudo, les options, et l'éditeur
## de carte — un outil d'atelier (`--ecran=editeur`), pas un mode de jeu, et
## sans entrée dans l'interface.
const ECRANS := {
	"creation": "res://scenes/creation.gd",
	"options": "res://scenes/options.gd",
	"salon": "res://scenes/salon.gd",
	"carnage": "res://jeux/carnage.gd",
	"editeur": "res://scenes/editeur.gd",
	"editeur2": "res://scenes/editeur_v2.gd",
}
## Où l'on entre, et où l'on revient. Une constante plutôt qu'un littéral
## répété : le jour où l'accueil change encore, il change à un seul endroit.
const ACCUEIL := "salon"
const JEU := "carnage"

var _ecran: Ecran = null
var _nom_ecran := ""

func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	Reseau.connecter()
	var arguments := OS.get_cmdline_args()
	# Dans le navigateur, la ligne de commande est l'URL : `?pilote=carnage&manche=60`
	# ouvre une manche au pilote automatique, dans la file d'essai (jamais à la
	# table d'un vrai joueur). C'est le seul moyen de REGARDER le jeu tourner sur
	# un vrai GPU depuis une session à distance : les touches synthétiques
	# n'atteignent pas Godot, et le banc sous xvfb tourne au quart du temps réel.
	if OS.has_feature("web"):
		arguments = _arguments_depuis_url(arguments)
	# Les photos démarrent AVANT le choix du banc : sinon `--banc --photo`
	# repart en haut de la fonction et on ne photographie jamais le hub.
	var dossier_photos := _argument(arguments, "--photo")
	if dossier_photos != "":
		_photographier(dossier_photos)
	# `--ecran=editeur` ouvre un écran directement, sans passer par l'accueil ni
	# par les clés Supabase : c'est ce qui permet de photographier un écran
	# solo au banc, comme `--lieu=` le fait pour les pièces du hub.
	var ecran := _argument(arguments, "--ecran")
	if ecran != "" and ECRANS.has(ecran):
		aller_a(ecran, {})
		return
	if "--banc" in arguments:
		_banc_d_essai()
		return

	# `--solo` : on joue sans serveur (voir `Reseau.solo`). C'est aussi ce qui
	# permet au banc de jouer une manche entière : le socket temps réel ne
	# passe pas par un mandataire HTTP, et aucun conteneur d'intégration ne
	# verra donc jamais le Realtime.
	if arguments.has("--solo"):
		Reseau.solo = true
	var jeu := _argument(arguments, "--banc-jeu")
	if jeu != "":
		_banc_partie(jeu, float(_argument(arguments, "--manche", "25")))
		return
	# DANS LE NAVIGATEUR, C'EST LA PAGE QUI TIENT LES MENUS : le kit de la
	# maquette y tourne tel quel, en HTML, au-dessus de la toile du moteur.
	# On attend qu'il passe la main (`window.PK.depart`) plutôt que d'ouvrir
	# notre propre menu — deux menus, même dessinés pareil, ne le seraient
	# jamais tout à fait.
	if OS.has_feature("web") and _page_tient_les_menus():
		_attendre_la_page()
		return
	aller_a(ACCUEIL, {"jeu": JEU, "titre": JEU.to_upper()})

## Vrai si la page qui nous porte est celle du kit : elle expose `window.PK`.
## Une page qui ne l'expose pas (un essai, une intégration ailleurs) retombe
## sur l'accueil du moteur.
func _page_tient_les_menus() -> bool:
	var reponse = JavaScriptBridge.eval("typeof window.PK === 'object' ? '1' : ''", true)
	return typeof(reponse) == TYPE_STRING and String(reponse) == "1"

## On regarde la page trente fois par seconde jusqu'à ce qu'elle nous donne le
## départ : le pseudo, le personnage, le jeu, et les réglages qu'on y a posés.
func _attendre_la_page() -> void:
	while true:
		await get_tree().process_frame
		var brut = JavaScriptBridge.eval(
			"window.PK.depart ? JSON.stringify(window.PK.depart) : ''", true)
		if typeof(brut) != TYPE_STRING or String(brut) == "":
			continue
		var lu = JSON.parse_string(String(brut))
		if typeof(lu) != TYPE_DICTIONARY:
			continue
		_partir_de_la_page(lu as Dictionary)
		return

func _partir_de_la_page(choix: Dictionary) -> void:
	var pseudo := Session.nettoyer_pseudo(String(choix.get("pseudo", "")))
	if pseudo.length() < 2:
		pseudo = "Joueur-" + Session.id.substr(0, 4)
	Session.definir_pseudo(pseudo)
	# L'indice qu'on choisit dans le kit est un LOGO de carton (le visage,
	# à Pikstown, c'est la boîte) ; la peau du bonhomme en découle.
	var indice := int(choix.get("personnage", 0))
	Session.definir_carton(posmod(indice, Personnages.nombre_de_cartons()))
	Session.definir_personnage(String(Personnages.LISTE[posmod(indice, Personnages.LISTE.size())]["cle"]))
	Reglages.prendre_de_la_page(choix)
	var jeu := String(choix.get("jeu", "carnage"))
	aller_a("salon", {"jeu": jeu, "titre": "PIKS THEFT AUTO" if jeu == "carnage" else jeu.to_upper()})

## `?pilote=carnage&manche=60&etoiles=5&position=120,110` → `--banc-jeu=carnage
## --manche=60 --banc-etoiles=5 --banc-position=120,110`.
static func _arguments_depuis_url(arguments: PackedStringArray) -> PackedStringArray:
	var recherche = JavaScriptBridge.eval("window.location.search", true)
	if typeof(recherche) != TYPE_STRING or String(recherche).length() < 2:
		return arguments
	var copie := PackedStringArray(arguments)
	for morceau in String(recherche).substr(1).split("&"):
		var paire := String(morceau).split("=")
		if paire.size() != 2:
			continue
		match String(paire[0]):
			"pilote": copie.append("--banc-jeu=" + String(paire[1]))
			"solo": copie.append("--solo")
			"manche": copie.append("--manche=" + String(paire[1]))
			"etoiles": copie.append("--banc-etoiles=" + String(paire[1]))
			"position": copie.append("--banc-position=" + String(paire[1]))
			"nuit": copie.append("--nuit=" + String(paire[1]))
			"feu": copie.append("--banc-feu=" + String(paire[1]))
			# ⚠ `ecran` manquait à cette table : `?ecran=editeur` n'était donc
			# JAMAIS traduit, et l'adresse ouvrait l'accueil comme si de rien
			# n'était. Le défaut ne se voyait que dans le navigateur — en
			# ligne de commande, `--ecran=` marche sans passer par ici.
			"ecran": copie.append("--ecran=" + String(paire[1]))
			"lieu": copie.append("--lieu=" + String(paire[1]))
			"onglet": copie.append("--onglet=" + String(paire[1]))
	return copie

static func _argument(arguments: PackedStringArray, nom: String, defaut: String = "") -> String:
	for a in arguments:
		if a.begins_with(nom + "="):
			return a.substr(nom.length() + 1)
	return defaut

## Banc d'essai sans interface : `godot --headless -- --banc`.
## Il ouvre l'accueil et le tient ouvert : ce qu'on vérifie ici, c'est que la
## ville se bâtit, que les écrans se montent et que la connexion tient. La
## présence à plusieurs, elle, se vérifie dans les bancs de partie — c'est le
## salon qui apparie, depuis que le village n'est plus sur le chemin.
func _banc_d_essai() -> void:
	Session.definir_pseudo("Banc-" + Session.id.substr(0, 4))
	aller_a(ACCUEIL, {"jeu": JEU, "titre": JEU.to_upper()})
	for i in 12:
		await get_tree().create_timer(1.0).timeout
		print("[banc] t=%ds reseau=%s ecran=%s" % [i + 1, Reseau.libelle_etat(), _nom_ecran])
	get_tree().quit()

## Photographies périodiques de l'écran, pour contrôler le rendu d'un jeu sans
## y jouer à la main : `godot --path . --photo=/tmp/vues`, sous un serveur X
## virtuel au besoin. Un export qui compile ne prouve rien sur ce qui s'affiche.
func _photographier(dossier: String) -> void:
	DirAccess.make_dir_recursive_absolute(dossier)
	var numero := 0
	while numero < 40:
		await get_tree().create_timer(5.0).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%02d.png" % [dossier, numero])
		numero += 1

## Banc de partie : `godot --headless -- --banc-jeu=carnage --manche=25`.
##
## Deux instances lancées côte à côte doivent s'apparier dans le salon, jouer
## la manche au pilote automatique et déposer un score. C'est la seule
## vérification qui traverse TOUTE la chaîne — appariement, élection de
## l'hôte, simulation, diffusion, dépôt en base — sans ouvrir un navigateur.
func _banc_partie(jeu: String, manche: float) -> void:
	Session.definir_pseudo("Banc-" + Session.id.substr(0, 4))
	Partie.duree_forcee = manche
	Commandes.pilote_automatique = true
	aller_a(ACCUEIL, {"jeu": jeu, "titre": jeu.to_upper()})

	var lance := false
	var ecoule := 0.0
	while ecoule < manche + 45.0:
		await get_tree().create_timer(0.4).timeout
		ecoule += 0.4
		# Pilote automatique : on avance en tournant au hasard. Il ne s'agit
		# pas de bien jouer, mais de produire des collisions et des messages.
		Commandes.direction_simulee = Vector2(randf_range(-1.0, 1.0), 1.0)

		if not lance and ecoule > 7.0 and _nom_ecran == "salon" and _ecran.has_method("lancer_pour_banc"):
			if _ecran.lancer_pour_banc():
				lance = true
				print("[banc] manche lancée")
		# ⚠ La fin d'une manche ramène AU SALON depuis qu'il n'y a plus d'écran
		# de résultats : le banc guettait « resultats » et ne voyait donc plus
		# jamais la fin — il abandonnait au bout de son chrono, en annonçant
		# l'écran du salon comme s'il n'était jamais parti.
		if lance and _nom_ecran == ACCUEIL:
			var lignes: Array = _ecran.donnees.get("classement", [])
			for ligne in lignes:
				print("[banc] score %s = %d" % [String(ligne.get("pseudo", "?")), int(ligne.get("score", 0))])
			print("[banc] terminé")
			get_tree().quit()
			return
	print("[banc] ABANDON — écran courant : " + _nom_ecran)
	get_tree().quit()

func aller_a(nom: String, donnees: Dictionary = {}) -> void:
	if not ECRANS.has(nom):
		push_error("Écran inconnu : " + nom)
		return
	if _ecran != null:
		_ecran.queue_free()
		_ecran = null
	var script: Script = load(ECRANS[nom])
	var ecran: Ecran = script.new()
	ecran.donnees = donnees
	ecran.demande_ecran.connect(aller_a)
	add_child(ecran)
	_ecran = ecran
	_nom_ecran = nom
	# Le pavé tactile ne vit qu'en ville : sur le chargement et dans le salon
	# il n'a rien à commander, et un manche posé sur l'affiche fait défaut.
	Tactile.en_jeu = nom == JEU
	ecran.demarrer()
