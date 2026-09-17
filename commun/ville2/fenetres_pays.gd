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

func regler(p: Dictionary, c: Dictionary = {}) -> void:
	plan = p
	ctx = c if not c.is_empty() else PLAN.contexte(p)
	for f in _fenetres.values():
		_defaire(f)
	_fenetres.clear()
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
	fiche["tache"] = WorkerThreadPool.add_task(func() -> void:
		fiche["ville"] = PAYS.fenetre(plan, ctx, f,
			{"nom": "Aurones %d,%d" % [coin.x, coin.y]}),
		true, "fenêtre du pays %s" % coin)
	_fenetres[c] = fiche

func _process(_dt: float) -> void:
	for c0 in _fenetres.keys():
		var f: Dictionary = _fenetres[c0]
		if f.has("morceaux") or not f.has("tache"): continue
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
