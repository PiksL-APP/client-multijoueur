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

func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	Reseau.connecter()
	if "--banc" in OS.get_cmdline_args():
		_banc_d_essai()
		return
	aller_a("accueil", {})

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
	ecran.demarrer()
