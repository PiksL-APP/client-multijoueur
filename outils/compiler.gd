extends Node
## LE BANC DE COMPILATION : tous les scripts du jeu se chargent-ils ?
##
## ⚠ Pourquoi il existe. `--check-only --script` refuse tout fichier qui parle
## à un autoload (`Session`, `Reseau`, `Sons`…) : il compile hors du projet et
## ne les connaît pas. Résultat, les deux plus gros fichiers du jeu —
## `jeux/carnage.gd` et `ui/hud.gd` — n'étaient vérifiés par RIEN entre deux
## parties, et une faute de frappe n'apparaissait qu'à l'écran noir. Ici on
## charge dans une SCÈNE, donc avec les autoloads, et on compte les refus.
##
##   godot --headless --path . res://outils/compiler.tscn

const DOSSIERS := ["res://jeux", "res://ui", "res://commun", "res://reseau",
	"res://autoload", "res://scenes", "res://outils"]

func _ready() -> void:
	var fautes := 0
	var vus := 0
	for dossier in DOSSIERS:
		for chemin in _scripts(dossier):
			vus += 1
			# ⚠ `load()` ne suffit pas TOUJOURS : un script refusé revient
			# parfois non nul. C'est `outils/compiler.sh` qui tranche, en
			# lisant les « Parse Error » du journal — on a essayé
			# `GDScript.is_valid()` ici, il fait tourner le moteur en rond
			# (plus de deux minutes sans rendre la main sur soixante fichiers).
			if load(chemin) == null:
				fautes += 1
				print("   REFUSÉ %s" % chemin)
	print("── %d scripts, %s" % [vus, "tout compile" if fautes == 0 else "%d REFUS" % fautes])
	get_tree().quit(1 if fautes > 0 else 0)

func _scripts(dossier: String) -> Array:
	var liste: Array = []
	var d := DirAccess.open(dossier)
	if d == null:
		return liste
	d.list_dir_begin()
	var nom := d.get_next()
	while nom != "":
		if d.current_is_dir() and not nom.begins_with("."):
			liste.append_array(_scripts(dossier.path_join(nom)))
		elif nom.ends_with(".gd"):
			liste.append(dossier.path_join(nom))
		nom = d.get_next()
	return liste
