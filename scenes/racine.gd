extends Node
## Porte un seul écran à la fois et fait la connexion au démarrage.

const ECRANS := {
	"accueil": "res://scenes/accueil.gd",
	"hub": "res://scenes/hub.gd",
	"salon": "res://scenes/salon.gd",
	"carnage": "res://jeux/carnage.gd",
	"enigme": "res://jeux/enigme.gd",
	"resultats": "res://scenes/resultats.gd",
}

var _ecran: Ecran = null
var _nom_ecran := ""

func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	Reseau.connecter()
	var arguments := OS.get_cmdline_args()
	if "--banc" in arguments:
		_banc_d_essai()
		return
	var jeu := _argument(arguments, "--banc-jeu")
	if jeu != "":
		_banc_partie(jeu, float(_argument(arguments, "--manche", "25")))
		return
	aller_a("accueil", {})

static func _argument(arguments: PackedStringArray, nom: String, defaut: String = "") -> String:
	for a in arguments:
		if a.begins_with(nom + "="):
			return a.substr(nom.length() + 1)
	return defaut

## Banc d'essai sans interface : `godot --headless -- --banc`.
## Deux instances lancées côte à côte doivent se voir dans le hub. C'est le
## seul moyen de vérifier la présence et la diffusion sans ouvrir deux
## navigateurs, et ça tient dans un script de contrôle avant déploiement.
func _banc_d_essai() -> void:
	Session.definir_pseudo("Banc-" + Session.id.substr(0, 4))
	aller_a("hub", {})
	for i in 12:
		await get_tree().create_timer(1.0).timeout
		var hub := _ecran
		var vus := 0
		if hub and hub.has_method("nombre_de_joueurs"):
			vus = hub.nombre_de_joueurs()
		print("[banc] t=%ds reseau=%s joueurs_vus=%d" % [i + 1, Reseau.libelle_etat(), vus])
	get_tree().quit()

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
	aller_a("salon", {"jeu": jeu, "titre": jeu.to_upper()})

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
		if _nom_ecran == "resultats":
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
	ecran.demarrer()
