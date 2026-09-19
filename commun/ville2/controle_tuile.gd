extends RefCounted
## ⭐ LE CONTRÔLE D'UNE TUILE — ce qu'on refuse de publier.
##
## Une tuile retouchée dans l'éditeur part dans le dépôt en un bouton, et le
## jeu la relit telle quelle (`FenetresPays._lire_ou_engendrer`). Rien, entre
## le clic et la mise en ligne, ne la regardait : un lot posé dans l'eau, deux
## bâtiments l'un dans l'autre, une maison sur la voie ferrée seraient partis
## en ligne comme le reste. Ce fichier est ce regard, et il sert à DEUX
## endroits avec le MÊME code : le bouton Publier de l'éditeur (qui refuse), et
## `outils/verifier_tuiles.gd` dans le workflow d'export (qui abandonne).
##
## ⚠ `preload`, pas `class_name` : le cache de classes n'est pas réécrit par
## un import sans tête (voir `scenes/editeur.gd`).
##
## Ce sont des FAUTES, pas des goûts : chacune est quelque chose qui se voit à
## l'écran comme cassé. Un cul-de-sac n'en est pas une — une rue peut finir.

const CASE := 20.0

## Les fautes d'une tuile, en clair, prêtes à afficher. Vide : la tuile est
## bonne. Chaque ligne commence par la case fautive, pour qu'on s'y rende.
static func fautes(v: Ville2, maxi: int = 30) -> Array[String]:
	var f: Array[String] = []
	if v == null: return ["tuile illisible"]
	if v.taille.x <= 0 or v.taille.y <= 0: return ["tuile sans taille"]
	if v.carte == null: v.rasteriser()

	# 1. DEUX LOTS L'UN DANS L'AUTRE, en demi-cases.
	var prises: Dictionary = {}
	var deja: Dictionary = {}
	for k in v.lots.size():
		var l: Dictionary = v.lots[k]
		for b in int(l["h"]):
			for a in int(l["w"]):
				var c := Vector2i(int(l["x"]) + a, int(l["y"]) + b)
				if prises.has(c):
					var paire := "%d/%d" % [mini(k, int(prises[c])), maxi(k, int(prises[c]))]
					if not deja.has(paire):
						deja[paire] = true
						f.append("(%d,%d) deux bâtiments se chevauchent : %s et %s" % [
							c.x / 2, c.y / 2, _nom(l), _nom(v.lots[int(prises[c])])])
				else:
					prises[c] = k

	# 2. UN LOT DANS L'EAU (une seule case d'eau suffit : un mur qui trempe).
	for k2 in v.lots.size():
		var l2: Dictionary = v.lots[k2]
		for c2 in Ville2.cases_du_lot(l2):
			var cc: Vector2i = c2
			if v.dedans(cc) and not v.terre(cc):
				f.append("(%d,%d) bâtiment dans l'eau : %s" % [cc.x, cc.y, _nom(l2)])
				break

	# 3. UN LOT SUR LA VOIE FERRÉE.
	var rails: Dictionary = {}
	for r in v.rail:
		var pts: Array = (r as Dictionary)["points"]
		for i in range(1, pts.size()):
			var a2 := _case(pts[i - 1])
			var b2 := _case(pts[i])
			var pas := (b2 - a2).sign()
			var c3 := a2
			rails[c3] = true
			while c3 != b2:
				c3 += pas
				rails[c3] = true
	if not rails.is_empty():
		for k3 in v.lots.size():
			var l3: Dictionary = v.lots[k3]
			for c4 in Ville2.cases_du_lot(l3):
				if rails.has(c4):
					f.append("(%d,%d) bâtiment sur la voie ferrée : %s" % [(c4 as Vector2i).x, (c4 as Vector2i).y, _nom(l3)])
					break

	# 4. UN LOT SUR UNE RUE — l'éditeur le refuse à la pose, mais « Chevauchement »
	# le permet exprès, et une rue tracée APRÈS passe à travers les lots qu'elle
	# n'a pas ôtés.
	for k4 in v.lots.size():
		var l4: Dictionary = v.lots[k4]
		for c5 in Ville2.cases_du_lot(l4):
			var cc5: Vector2i = c5
			if v.dedans(cc5) and v.carte.route(cc5):
				f.append("(%d,%d) bâtiment sur une rue : %s" % [cc5.x, cc5.y, _nom(l4)])
				break

	# (Pas de contrôle « objet planté dans un bâtiment » : le générateur pose
	# exprès bornes et vélos contre les façades, sur la case du lot, et c'est
	# juste. Un contrôle que le générateur ne passe pas refuserait toute tuile.)

	if f.size() > maxi:
		var reste := f.size() - maxi
		f.resize(maxi)
		f.append("… et %d autres fautes" % reste)
	return f

static func _nom(l: Dictionary) -> String:
	return String(l.get("m", "?")).get_file()

static func _case(p) -> Vector2i:
	if p is Vector2i: return p
	var t: Array = p
	return Vector2i(int(t[0]), int(t[1]))
