class_name FenetresPays
extends Node3D
## ⭐⭐⭐ LE PAYS, BÂTI AUTOUR DU JOUEUR — l'étage qui manquait.
##
## Jusqu'ici l'archipel n'existait que dans l'éditeur, une fenêtre à la fois :
## on pouvait le REGARDER, pas le TRAVERSER. Ce nœud est ce qui le rend
## jouable.
##
## ⚠ POURQUOI UN ÉTAGE DE PLUS, ET PAS UN `MorceauxV2` PLUS GRAND.
## `MorceauxV2` sait déjà bâtir une ville par carrés de seize cases autour de
## celui qui regarde — mais il lui faut une `Ville2` ENTIÈRE en mémoire, parce
## qu'une rue doit savoir qu'elle continue chez le voisin (`ville.carte` couvre
## toute la carte). Sur mille cases de côté, cette `Ville2` unique est
## exactement ce que l'architecture du pays a été faite pour ne jamais avoir à
## construire : un million de cases de décor.
##
## On empile donc deux niveaux de découpe :
##
##   le PAYS          1000 × 1000 cases, qui n'existe que sous forme de plan
##     └ la FENÊTRE   `COTE` × `COTE` cases, une `Ville2` complète, bâtie à la
##                    demande depuis le plan — neuf au plus, autour du joueur
##        └ le MORCEAU 16 × 16 cases de décor, ce que `MorceauxV2` sait faire
##
## ⚠⚠ ET LA FENÊTRE SE FABRIQUE DANS UN FIL, PARCE QU'ELLE COÛTE DES SECONDES.
## Mesuré : deux à sept secondes selon la densité. Fabriquée dans l'image, elle
## gèlerait le jeu à chaque fois que le joueur franchit une limite — c'est-à-dire
## tous les quatre kilomètres, en voiture toutes les deux minutes. `PAYS.fenetre`
## ne touche à AUCUN nœud (elle ne produit que des tableaux), donc elle peut
## tourner dans un fil sans rien savoir de la scène ; seul `MorceauxV2`, qui crée
## des nœuds, reste dans l'image — et lui sait déjà s'étaler.

const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")

## ⚠ DEUX CENTS CASES, SOIT QUATRE KILOMÈTRES DE CÔTÉ. C'est la taille que
## `MorceauxV2` tient sans transpirer (mesuré à l'éditeur), et c'est assez grand
## pour qu'un joueur en voiture ne change pas de fenêtre toutes les trente
## secondes. Plus petit, on fabrique tout le temps ; plus grand, chaque
## fabrication coûte trop cher pour être absorbée.
const COTE := 200

## Le rayon en fenêtres autour du joueur. 1 = les neuf fenêtres qui l'entourent,
## soit douze kilomètres de côté : de quoi voir loin sans rien fabriquer d'avance
## qu'on ne verra jamais.
const RAYON := 1

## ⚠ ON NE LIBÈRE PAS À LA LIMITE OÙ L'ON FABRIQUE. Un joueur qui longe une
## frontière la franchit vingt fois par minute ; si la fenêtre mourait dès qu'il
## repasse de l'autre côté, on la refabriquerait vingt fois. On garde donc un
## anneau de plus que ce qu'on bâtit.
const GARDE := RAYON + 1

var plan: Dictionary = {}
var ctx: Dictionary = {}

## Par fenêtre : {"ville": Ville2, "morceaux": MorceauxV2, "tache": int}
var _fenetres: Dictionary = {}
var _centre := Vector2i(999999, 999999)

## ⚠⚠⚠ LA TOUTE PREMIÈRE FENÊTRE SE BÂTIT SUR LE FIL PRINCIPAL, ET C'EST
## OBLIGATOIRE.
##
## Mesuré, et cela a coûté une matinée : une fenêtre fabriquée dans un fil
## AVANT que le fil principal en ait jamais fabriqué une NE FINIT JAMAIS — le
## jeu se fige au démarrage, sans erreur, sans trace. (Le générateur charge des
## choses la première fois qu'on les lui demande ; ce premier chargement-là ne
## supporte pas d'être demandé d'ailleurs que du fil principal.) Une fois la
## première faite, toutes les suivantes passent dans un fil sans broncher :
## vérifié au banc `outils/verifier_plan_pays.gd`.
##
## On ne perd rien à ça : cette première fenêtre est celle où l'on commence, on
## l'attend de toute façon (`exiger`), et l'écran n'a pas encore commencé à
## tourner quand elle se bâtit.
var _chauffe := false

func regler(p: Dictionary, c: Dictionary = {}) -> void:
	plan = p
	ctx = c if not c.is_empty() else PLAN.contexte(p)
	for f in _fenetres.values():
		_defaire(f)
	_fenetres.clear()
	_chauffe = false
	_centre = Vector2i(999999, 999999)
	set_process(true)

## Combien de fenêtres sont prêtes, et combien sont en cours de fabrication.
func etat() -> Array:
	var pretes := 0
	var en_cours := 0
	for f0 in _fenetres.values():
		var f: Dictionary = f0
		if f.has("morceaux"): pretes += 1
		else: en_cours += 1
	return [pretes, en_cours]

## La fenêtre qui contient ce point du monde, ou `null`.
func ville_en(point: Vector3) -> Ville2:
	var cle := _fenetre_de(point)
	var f: Dictionary = _fenetres.get(cle, {})
	return f.get("ville", null)

## ⭐ LA FENÊTRE QUI PORTE CETTE CASE DU MONDE, ou `null` si elle n'est pas
## encore fabriquée. C'est par ici que `PlanJeuPays` interroge le pays : lui
## compte en CASES (le jeu ne connaît que ça), pas en mètres.
func ville_de_case(c: Vector2i) -> Ville2:
	var f: Dictionary = _fenetres.get(cle_de_case(c), {})
	return f.get("ville", null)

## La fenêtre à laquelle appartient une case du monde, et son coin.
static func cle_de_case(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / float(COTE)), floori(float(c.y) / float(COTE)))

static func coin_de_case(c: Vector2i) -> Vector2i:
	return cle_de_case(c) * COTE

## ⭐ LA PREMIÈRE FENÊTRE SE FAIT ATTENDRE — et une seule fois.
##
## ⚠ CELLE-CI BLOQUE LE FIL PRINCIPAL, exprès. Au tout début d'une partie, le
## jeu demande où poser les joueurs AVANT d'avoir affiché quoi que ce soit :
## répondre « mer » là reviendrait à les noyer. On paie donc les quelques
## secondes une fois, sur un écran qui n'a pas encore commencé à tourner ;
## partout ailleurs, `ville_de_case` rend `null` et le pays se remplit dans son
## fil, sans jamais faire attendre une image.
func exiger(c: Vector2i) -> Ville2:
	var cle := cle_de_case(c)
	if not _fenetres.has(cle):
		if not _dans_le_pays(cle): return null
		_commander(cle)
	var f: Dictionary = _fenetres[cle]
	if f.has("tache"):
		WorkerThreadPool.wait_for_task_completion(int(f["tache"]))
		f.erase("tache")
	return f.get("ville", null)

func suivre(point: Vector3) -> void:
	var cle := _fenetre_de(point)
	# Les morceaux de chaque fenêtre suivent le joueur, même quand il ne change
	# pas de fenêtre : c'est eux qui font le gros du travail image par image.
	for f0 in _fenetres.values():
		var f: Dictionary = f0
		if f.has("morceaux"): (f["morceaux"] as MorceauxV2).suivre(point)
	if cle == _centre: return
	_centre = cle
	_revoir()

## Combien de morceaux de décor sont bâtis, toutes fenêtres confondues — la
## même question que `MorceauxV2.morceaux_batis()`, pour la même trace au départ.
func morceaux_batis() -> int:
	var total := 0
	for f0 in _fenetres.values():
		var f: Dictionary = f0
		if f.has("morceaux"): total += (f["morceaux"] as MorceauxV2).morceaux_batis()
	return total

func _fenetre_de(point: Vector3) -> Vector2i:
	var local := global_transform.affine_inverse() * point
	return Vector2i(floori(local.x / Ville2.CASE / float(COTE)),
		floori(local.z / Ville2.CASE / float(COTE)))

## On demande ce qui manque autour du joueur, on rend ce qui est parti loin.
func _revoir() -> void:
	for c0 in _fenetres.keys():
		var c: Vector2i = c0
		if maxi(absi(c.x - _centre.x), absi(c.y - _centre.y)) <= GARDE: continue
		_defaire(_fenetres[c])
		_fenetres.erase(c)
	# ⚠ LA PLUS PROCHE D'ABORD. Le joueur voit d'abord ce qui l'entoure ; une
	# fenêtre de coin qu'il ne regardera peut-être jamais peut attendre.
	var voulues: Array = []
	for dj in range(-RAYON, RAYON + 1):
		for di in range(-RAYON, RAYON + 1):
			voulues.append(_centre + Vector2i(di, dj))
	voulues.sort_custom(func(a, b):
		var da: Vector2i = (a as Vector2i) - _centre
		var db: Vector2i = (b as Vector2i) - _centre
		return da.length_squared() < db.length_squared())
	for c1 in voulues:
		var c2: Vector2i = c1
		if _fenetres.has(c2): continue
		if not _dans_le_pays(c2): continue
		_commander(c2)

## Une fenêtre entièrement hors de la carte n'a rien à montrer.
func _dans_le_pays(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 \
		and c.x * COTE < PLAN.TAILLE.x and c.y * COTE < PLAN.TAILLE.y

## ⭐ LA COMMANDE : on lance la fabrication dans un fil et on note la tâche.
## Rien n'est ajouté à la scène tant que le fil n'a pas fini — `_process` s'en
## charge, parce que seul le fil principal a le droit de toucher à l'arbre.
func _commander(c: Vector2i) -> void:
	var coin := c * COTE
	var taille := Vector2i(mini(COTE, PLAN.TAILLE.x - coin.x),
		mini(COTE, PLAN.TAILLE.y - coin.y))
	if taille.x <= 0 or taille.y <= 0: return
	var f := Rect2i(coin, taille)
	var fiche := {"coin": coin, "rect": f, "ville": null}
	var nom := {"nom": "Aurones %d,%d" % [coin.x, coin.y]}
	var batir := func() -> Ville2: return _lire_ou_engendrer(c, f, nom)
	if not _chauffe:
		# Voir `_chauffe` : la première ne passe PAS par un fil.
		_chauffe = true
		fiche["ville"] = batir.call()
		_fenetres[c] = fiche
		return
	fiche["tache"] = WorkerThreadPool.add_task(func() -> void:
		fiche["ville"] = batir.call(),
		true, "fenêtre du pays %s" % coin)
	_fenetres[c] = fiche

## ⭐⭐⭐ UNE TUILE RETOUCHÉE GAGNE SUR LA TUILE ENGENDRÉE (19/09).
##
## L'éditeur travaille tuile par tuile, sur cette même grille, et enregistre
## `cartes/pays-<kx>-<ky>.json` — dans `user://` au navigateur (le Ctrl+S), dans
## le dépôt une fois publiée. Ici on la relit avant d'engendrer : ce que le
## client a posé dans l'éditeur est ce qu'il joue, sur la même machine tout de
## suite, partout après l'export. Sans ça, l'éditeur du pays était un outil
## dont rien ne sortait.
##
## ⚠ LA TAILLE DOIT CORRESPONDRE. Un fichier d'un autre nommage, ou d'une
## tuile de bord tronquée autrement, ne se pose pas à la place d'une tuile
## pleine : on l'ignore et on engendre.
## ⚠ `depuis_json` ne touche à aucun nœud : ce chemin passe dans le fil comme
## l'autre.
func _lire_ou_engendrer(c: Vector2i, f: Rect2i, nom: Dictionary) -> Ville2:
	var chemin := "res://cartes/pays-%d-%d.json" % [c.x, c.y]
	var vrai := Ville2.chemin_utile(chemin)
	if FileAccess.file_exists(vrai):
		var v := Ville2.charger(chemin)
		if v != null and v.taille == f.size and not (v.lots.is_empty() and v.routes.is_empty()):
			return v
		push_warning("tuile %s ignorée (taille %s au lieu de %s, ou vide)" % [chemin, v.taille, f.size])
	return PAYS.fenetre(plan, ctx, f, nom)

func _process(_dt: float) -> void:
	for c0 in _fenetres.keys():
		var f: Dictionary = _fenetres[c0]
		if f.has("morceaux"): continue
		# ⚠ Une fenêtre sans tâche est déjà faite (la première, ou une qu'on a
		# attendue) : elle n'a plus qu'à monter.
		if f.has("tache"):
			if not WorkerThreadPool.is_task_completed(int(f["tache"])): continue
			WorkerThreadPool.wait_for_task_completion(int(f["tache"]))
			f.erase("tache")
		var v: Ville2 = f.get("ville", null)
		if v == null: continue
		_monter(f, v)
		# ⚠ UNE SEULE PAR IMAGE. Monter une fenêtre, c'est créer son nœud et
		# lancer ses morceaux ; deux d'un coup rendraient le fil de fabrication
		# inutile, puisqu'on aurait déplacé la saccade au lieu de la supprimer.
		return

## La fenêtre entre en scène : son propre `MorceauxV2`, posé à sa place dans le
## pays. ⚠ C'EST LE NŒUD QUI PORTE LE DÉCALAGE, pas la `Ville2` : celle-ci
## compte depuis son propre coin, comme dans l'éditeur, et c'est ce qui permet
## de réutiliser tout le rendu sans y toucher.
func _monter(f: Dictionary, v: Ville2) -> void:
	var m := MorceauxV2.new()
	m.par_image = 1
	m.position = Vector3(float((f["coin"] as Vector2i).x) * Ville2.CASE, 0.0,
		float((f["coin"] as Vector2i).y) * Ville2.CASE)
	add_child(m)
	m.regler(v, 2)
	f["morceaux"] = m

func _defaire(f: Dictionary) -> void:
	if f.has("tache"):
		WorkerThreadPool.wait_for_task_completion(int(f["tache"]))
		f.erase("tache")
	if f.has("morceaux"):
		(f["morceaux"] as Node3D).queue_free()
		f.erase("morceaux")
