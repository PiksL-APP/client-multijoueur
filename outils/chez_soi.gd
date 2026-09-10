extends Node3D
## LE BANC DU REPAIRE EN JEU : l'appartement tel que CARNAGE le montrera.
##
## `outils/vitrine.sh` photographie un intérieur sous des lumières de studio,
## posé à l'origine, cadré sur son contenu. C'est ce qu'il faut pour juger une
## décoration — et ça ne dit RIEN de ce que le joueur verra : dans le jeu, le
## même appartement est bâti six cents unités sous la ville, éclairé par
## l'heure bleue de Carnage, et cadré par une caméra fixe à septante-deux
## degrés. Trois choses qui peuvent chacune le rendre illisible.
##
## Ce banc-là reprend LES MÊMES fonctions que le jeu — `Interieurs.SOUS_SOL`,
## `Interieurs.cadre`, `degager_la_vue`, `poser_pantin`, `MatieresCarnage.
## ambiance` — pour que l'image ne puisse pas mentir par construction. C'est
## exactement le piège dans lequel la vitrine nous avait fait tomber : elle
## escamotait les deux façades de devant dans son coin, donc le défaut
## « on entre chez soi et on regarde un mur » ne pouvait pas s'y voir.
##
##   outils/chez_soi.sh <intérieur> [sortie]

const INCLINAISON := 72.0          ## la valeur de `Carnage.INCLINAISON`
const CHAMP := 54.0                ## la valeur de `Carnage.preparer`

var _sortie := "/tmp/chez_soi.png"
var _images := 0

func _ready() -> void:
	var id := "taudis"
	for a in OS.get_cmdline_args():
		if a.begins_with("--interieur="): id = a.trim_prefix("--interieur=")
		if a.begins_with("--sortie="): _sortie = a.trim_prefix("--sortie=")

	# L'ambiance DU JEU, pas des lumières de studio : c'est elle qu'on éprouve.
	for n in MatieresCarnage.ambiance():
		add_child(n)

	var appart := Interieurs.batir(id)
	appart.position = Interieurs.SOUS_SOL
	Interieurs.degager_la_vue(appart, Vector2(0.0, 1.0))
	add_child(appart)

	var ou := Interieurs.degager(id, Interieurs.entree(id))
	var pantin := FormesCarnage.pieton(Color("#ff2ea6"), false, "", false, "")
	Interieurs.poser_pantin(pantin, ou, "banc", Interieurs.SOUS_SOL)
	add_child(pantin)

	var cam := Decor.camera(INCLINAISON, 1.0, CHAMP)
	add_child(cam)
	cam.make_current()
	var ecran := Vector2(get_viewport().get_visible_rect().size)
	var c: Dictionary = Interieurs.cadre(id, ecran.x / maxf(ecran.y, 1.0), CHAMP, INCLINAISON)
	var recul: float = c["recul"]
	cam.position = (c["centre"] as Vector3) + Vector3(0.0,
		sin(deg_to_rad(INCLINAISON)) * recul, cos(deg_to_rad(INCLINAISON)) * recul)

	print("[chez soi] %s — recul %.1f, caméra en %s" % [id, recul, cam.position])
	get_tree().process_frame.connect(_photographier)

func _photographier() -> void:
	_images += 1
	if _images < 24:
		return
	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("photo ", _sortie)
	get_tree().quit()
