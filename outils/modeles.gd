extends SceneTree
## ENGENDRE `commun/modeles_du_kit.gd` : la liste de TOUS les `.glb` de
## `modeles/`, chemins relatifs, triés.
##
## ⚠ POURQUOI UNE LISTE ÉCRITE ET PAS UN `DirAccess` À L'EXÉCUTION. Le jeu tourne
## dans un NAVIGATEUR : les `.glb` y sont des ressources importées, remappées
## dans le paquet, et `DirAccess.get_files()` n'y voit pas les mêmes noms qu'au
## bureau. Un navigateur de modèles qui marche en local et sort une liste vide
## en ligne, c'est le genre de panne qu'on ne découvre qu'après l'export.
## `ResourceLoader.exists()`, lui, suit le remappage : on peut donc CHARGER
## n'importe lequel — il suffit de savoir lesquels existent, et c'est ce que
## cette liste dit.
##
##     ./outils/modeles.sh          (à relancer quand on ajoute un modèle)
const SORTIE := "res://commun/modeles_du_kit.gd"
## Ce qui n'a rien à faire dans un navigateur de décor : les peaux de
## personnages, les textures, et les pièces de carrosserie.
const HORS := ["Textures", "peaux"]
const PIECES := ["wheel-dark", "wheel-default", "wheel-truck"]

func _init() -> void:
	var tous: Array[String] = []
	_lister("res://modeles", "", tous)
	tous.sort()
	var t := "class_name ModelesDuKit\n"
	t += "extends RefCounted\n"
	t += "## LA LISTE DE TOUS LES MODÈLES, chemins relatifs à `res://modeles/`,\n"
	t += "## sans l'extension. ÉCRIT PAR `outils/modeles.sh` — ne pas modifier à la\n"
	t += "## main : la prochaine exécution l'écrasera.\n"
	t += "##\n"
	t += "## Elle existe parce que `DirAccess` ne voit pas les mêmes noms dans un\n"
	t += "## paquet exporté qu'au bureau. Voir `outils/modeles.gd`.\n\n"
	t += "const TOUS: Array[String] = [\n"
	for n in tous:
		t += "\t\"%s\",\n" % n
	t += "]\n"
	var f := FileAccess.open(SORTIE, FileAccess.WRITE)
	f.store_string(t)
	f.close()
	print("modeles : %d écrits dans %s" % [tous.size(), SORTIE])
	quit()

func _lister(dossier: String, prefixe: String, dedans: Array[String]) -> void:
	var d := DirAccess.open(dossier)
	if d == null: return
	for sous in d.get_directories():
		if sous in HORS: continue
		_lister(dossier + "/" + sous, prefixe + sous + "/", dedans)
	for f in d.get_files():
		if not f.ends_with(".glb"): continue
		var n := f.trim_suffix(".glb")
		if n in PIECES: continue
		dedans.append(prefixe + n)
