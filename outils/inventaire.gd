extends SceneTree
## L'INVENTAIRE DU KIT : quels modèles la ville pose VRAIMENT, et lesquels
## dorment. C'est la seule réponse honnête à « est-ce que tout le kit sert ? ».
##
## Pourquoi un banc et pas une relecture du code : `_objet` et `_tuile` sortent
## EN SILENCE quand le chemin n'existe pas. Une entrée dans une table ne prouve
## donc rien — on a eu la ville entière sans un lampadaire, avec `light-square`
## écrit noir sur blanc dans le code, parce qu'il était cherché dans `routes/`.
## Ici, on bâtit la ville pour de vrai et on compte ce qui sort.
##
##     ./outils/inventaire.sh
##
## Les familles hors ville sont exclues : `interieur/` et `nourriture/` sont le
## mobilier des repaires, `peaux/` le casting des personnages, `Textures/` les
## images. Les roues sont des pièces de carrosserie, pas des objets à poser.
const HORS_VILLE := ["interieur", "nourriture", "peaux", "Textures"]
const PIECES := ["wheel-dark", "wheel-default", "wheel-truck"]

func _init() -> void:
	Quartiers.inventaire = true
	Quartiers.journal = {}
	var t0 := Time.get_ticks_msec()
	var racine := Quartiers.batir_fiche(Quartiers.CATALOGUE["pikstown"], "pikstown")
	print("ville bâtie en %d ms, %d nœuds" % [Time.get_ticks_msec() - t0, _compter(racine)])

	var tous: Array[String] = []
	_lister("res://modeles/kenney", tous)
	tous.sort()
	var poses: Dictionary = Quartiers.journal
	# ⚠ LE KIT SE RECOUPE : cinq modèles sont livrés À L'IDENTIQUE dans deux
	# dossiers (`routes/traffic-light` et `urbain/traffic-light` ont le même
	# octet à octet). Les compter comme deux modèles oubliés obligerait à poser
	# deux fois le même objet pour faire tomber la liste à zéro — c'est-à-dire
	# à mentir. On les regroupe par empreinte : poser l'un, c'est poser l'autre.
	var empreintes: Dictionary = {}
	for chemin in tous:
		var e := str(FileAccess.get_file_as_bytes(chemin).size()) + ":" \
			+ str(hash(FileAccess.get_file_as_bytes(chemin)))
		if not empreintes.has(e): empreintes[e] = []
		empreintes[e].append(chemin)
	var pose_par_empreinte: Dictionary = {}
	for e in empreintes.keys():
		for chemin in empreintes[e]:
			if poses.has(chemin): pose_par_empreinte[e] = chemin
	var oublies: Array[String] = []
	var doublons := 0
	for chemin in tous:
		if poses.has(chemin): continue
		var e2 := str(FileAccess.get_file_as_bytes(chemin).size()) + ":" \
			+ str(hash(FileAccess.get_file_as_bytes(chemin)))
		if pose_par_empreinte.has(e2):
			doublons += 1
			continue
		oublies.append(chemin)
	if doublons > 0:
		print("(%d modèles sont des doublons exacts d'un modèle posé)" % doublons)

	print("\n── POSÉS : %d modèles sur %d" % [tous.size() - oublies.size(), tous.size()])
	var classement: Array = []
	for cle in poses.keys(): classement.append([int(poses[cle]), String(cle)])
	classement.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	for f in classement:
		print("  %7d  %s" % [int(f[0]), String(f[1]).trim_prefix("res://modeles/kenney/")])

	if oublies.is_empty():
		print("\n── AUCUN MODÈLE OUBLIÉ. Tout le kit de ville est posé.")
	else:
		print("\n── JAMAIS POSÉS : %d" % oublies.size())
		for o in oublies:
			print("  %s" % o.trim_prefix("res://modeles/kenney/"))
	quit()

func _compter(n: Node) -> int:
	var t := 1
	for e in n.get_children(): t += _compter(e)
	return t

func _lister(dossier: String, dedans: Array[String]) -> void:
	var d := DirAccess.open(dossier)
	if d == null: return
	for sous in d.get_directories():
		if sous in HORS_VILLE: continue
		_lister(dossier + "/" + sous, dedans)
	for f in d.get_files():
		if not f.ends_with(".glb"): continue
		if f.trim_suffix(".glb") in PIECES: continue
		dedans.append(dossier + "/" + f)
