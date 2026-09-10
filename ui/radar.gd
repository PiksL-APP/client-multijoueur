extends Control
## Le radar : les alentours du joueur, vus de haut, dans un coin de l'écran.
##
## L'ancien plan montrait la ville ENTIÈRE : elle faisait quarante-huit tuiles
## de large et tenait dans cent soixante-douze pixels. Celle-ci en fait six
## cent quatre-vingts — un pixel vaudrait quatre tuiles, et un garage y serait
## un point qu'on ne trouve pas. Le radar est donc centré sur soi, le nord en
## haut, et ce qu'il ne montre pas — la cible d'un contrat — il l'indique par
## une flèche au bord. C'est la grammaire de GTA depuis toujours.
##
## Séparé de l'écran de jeu comme `ui/manche.gd` l'est du tactile : ici on ne
## fait que peindre ce qu'on nous a donné, en interrogeant le plan pour le
## décor.

const COTE := 172.0
const MARGE := 8.0
const ECHELLE := 1.0 / 26.0          ## pixels de radar par pixel de jeu

var carte: PlanVille = null
var moi := Vector2.ZERO
var mon_angle := 0.0
var ma_couleur := Palette.ENCRE
var autres: Array = []        ## {p: Vector2, couleur: Color}
var patrouilles: Array = []   ## Vector2
var etoiles := 0
var cible: Dictionary = {}    ## {k: genre du contrat, g: gang visé} — ce qu'il faut aller chercher

func _draw() -> void:
	if carte == null:
		return
	var cadre := Rect2(Vector2(MARGE, MARGE), Vector2(COTE, COTE))
	var centre := cadre.get_center()
	UI.cartouche(self, cadre, Color(0, 0, 0, 0), Color(Palette.FOND, 0.88))
	var rayon_vue := COTE * 0.5 / ECHELLE     # en pixels de jeu, la moitié du cadre

	# Les pâtés : un aplat par territoire, plus fort pour les parcs et l'eau,
	# qui se lisent comme du relief sur un plan.
	var pas := PlanVille.PAS
	var p0 := Vector2i(int(floor((moi.x - rayon_vue) / pas / PlanVille.PERIODE)) - 1,
		int(floor((moi.y - rayon_vue) / pas / PlanVille.PERIODE)) - 1)
	var p1 := Vector2i(int(floor((moi.x + rayon_vue) / pas / PlanVille.PERIODE)) + 1,
		int(floor((moi.y + rayon_vue) / pas / PlanVille.PERIODE)) + 1)
	for py in range(p0.y, p1.y + 1):
		for px in range(p0.x, p1.x + 1):
			var pate := Vector2i(px, py)
			var coin := PlanVille.coin_pate(pate)
			var rect := Rect2(_vers_radar(Vector2(coin) * pas, centre), Vector2(3, 3) * pas * ECHELLE)
			var visible := rect.intersection(cadre)
			if visible.size.x <= 0.0 or visible.size.y <= 0.0:
				continue
			var quartier := carte.quartier_du_pate(pate)
			var gang := carte.territoire_du_pate(pate)
			var couleur := Color(Palette.ENCRE, 0.10)
			if quartier == PlanVille.EAU or carte.eau(coin.x + 1, coin.y + 1):
				couleur = Color(Palette.SERIE, 0.22)
			elif quartier == PlanVille.PARC:
				couleur = Color(Palette.BON, 0.16)
			elif gang >= 0:
				couleur = Color(carte.couleur_du_gang(gang), 0.24)
			draw_rect(visible, couleur, true)

	# Les rues : deux tuiles de large, en sombre, segment par segment — une rue
	# fermée ou noyée ne se dessine pas, c'est ce qui fait lire les îlots et
	# la rivière sur le radar. Les avenues sont un peu plus claires.
	var largeur_rue := 2.0 * pas * ECHELLE
	var bitume := Color(0.05, 0.05, 0.06, 0.9)
	var avenue := Color(0.12, 0.12, 0.1, 0.95)
	var periode := PlanVille.PERIODE
	for k in range(p0.x, p1.x + 2):
		var x := _vers_radar(Vector2(float(k * periode + 1) * pas, 0.0), centre).x
		if x + largeur_rue * 0.5 < cadre.position.x or x - largeur_rue * 0.5 > cadre.end.x:
			continue
		for py in range(p0.y, p1.y + 1):
			if carte.rue_fermee_v(k, py) or carte.eau(k * periode, py * periode + 3):
				continue
			var y0 := _vers_radar(Vector2(0.0, float(py * periode) * pas), centre).y
			var y1 := _vers_radar(Vector2(0.0, float(py * periode + periode) * pas), centre).y
			draw_line(Vector2(x, clamp(y0, cadre.position.y, cadre.end.y)), Vector2(x, clamp(y1, cadre.position.y, cadre.end.y)),
				avenue if posmod(k, PlanVille.AVENUE) == 0 else bitume, largeur_rue)
	for kl in range(p0.y, p1.y + 2):
		var y := _vers_radar(Vector2(0.0, float(kl * periode + 1) * pas), centre).y
		if y + largeur_rue * 0.5 < cadre.position.y or y - largeur_rue * 0.5 > cadre.end.y:
			continue
		for px in range(p0.x, p1.x + 1):
			if carte.rue_fermee_h(kl, px) or carte.eau(px * periode + 3, kl * periode):
				continue
			var x0 := _vers_radar(Vector2(float(px * periode) * pas, 0.0), centre).x
			var x1 := _vers_radar(Vector2(float(px * periode + periode) * pas, 0.0), centre).x
			draw_line(Vector2(clamp(x0, cadre.position.x, cadre.end.x), y), Vector2(clamp(x1, cadre.position.x, cadre.end.x), y),
				avenue if posmod(kl, PlanVille.AVENUE) == 0 else bitume, largeur_rue)

	# Les lieux à portée : repaires, arènes, garages, cabines.
	var lieux := carte.lieux_autour(moi, rayon_vue * 1.5)
	for r in lieux["repaires"]:
		var ou := _vers_radar(r["p"], centre)
		if cadre.has_point(ou):
			draw_rect(Rect2(ou - Vector2(3, 3), Vector2(6, 6)), carte.couleur_du_gang(int(r["gang"])), true)
	for a in lieux["arenes"]:
		var ou := _vers_radar(a["p"], centre)
		if cadre.grow(-6.0).has_point(ou):
			draw_arc(ou, PlanVille.RAYON_ARENE * ECHELLE, 0, TAU, 20, Palette.CRITIQUE, 1.5)
	for g in lieux["garages"]:
		var ou := _vers_radar(g["p"], centre)
		if cadre.has_point(ou):
			_pastille(ou, 4.0, Palette.SERIE)
	for c in lieux["cabines"]:
		var ou := _vers_radar(c["p"], centre)
		if cadre.has_point(ou):
			_pastille(ou, 3.0, Palette.AVERTISSEMENT)
	for h in lieux["hopitaux"]:
		var ou := _vers_radar(h["p"], centre)
		if cadre.has_point(ou):
			# Une petite croix : on la distingue d'une pastille au premier regard.
			draw_line(ou - Vector2(4, 0), ou + Vector2(4, 0), Color("#f0f4f8"), 2.0)
			draw_line(ou - Vector2(0, 4), ou + Vector2(0, 4), Color("#f0f4f8"), 2.0)
	for pl in lieux["planques"]:
		var ou := _vers_radar(pl["p"], centre)
		if cadre.has_point(ou):
			_pastille(ou, 4.0, Color("#b070d0"))

	# La cible du contrat : le repaire du gang à nettoyer ou le garage où livrer.
	# Dans le cadre, elle clignote ; hors du cadre, une flèche au bord dit où
	# aller. Un contrat sans cible visible, c'est un chrono qui tourne pendant
	# qu'on cherche.
	if not cible.is_empty():
		var genre := String(cible.get("k", ""))
		var visee := {}
		# Une cible peut être un POINT tout court : c'est le cas de la course
		# de taxi, qui n'a ni repaire ni garage à viser. Le reste du dessin ne
		# change pas — flèche au bord, distance en pâtés.
		if cible.has("p"):
			visee = {"p": cible["p"]}
		elif genre == "nettoyage":
			visee = carte.repaire_le_plus_proche(moi, int(cible.get("g", -1)))
		elif genre == "livraison":
			visee = carte.garage_le_plus_proche(moi)
		if not visee.is_empty():
			var ou := _vers_radar(visee["p"], centre)
			var clignote := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5
			if cadre.grow(-8.0).has_point(ou):
				if clignote:
					draw_arc(ou, 8.0, 0, TAU, 16, Palette.AVERTISSEMENT, 2.0)
			else:
				var direction := (ou - centre).normalized()
				var bord := centre + direction * (COTE * 0.5 - 9.0)
				var cote := Vector2(-direction.y, direction.x)
				draw_colored_polygon(PackedVector2Array([bord + direction * 7.0,
					bord - direction * 4.0 + cote * 5.0, bord - direction * 4.0 - cote * 5.0]),
					Palette.AVERTISSEMENT if clignote else Palette.AVERTISSEMENT.darkened(0.3))
				var police: Font = UI.TITRE_POLICE
				var distance := int(Vector2(visee["p"]).distance_to(moi) / PlanVille.PAS)
				draw_string(police, bord - direction * 16.0 - Vector2(10, -4), "%d" % distance,
					HORIZONTAL_ALIGNMENT_CENTER, 20, 8, Palette.AVERTISSEMENT)

	for p: Vector2 in patrouilles:
		var ou := _vers_radar(p, centre)
		if cadre.has_point(ou):
			_pastille(ou, 2.5, Palette.SERIE.lightened(0.3))
	for a in autres:
		var ou := _vers_radar(a["p"], centre)
		if cadre.has_point(ou):
			_pastille(ou, 3.5, a["couleur"])
		else:
			# Un coéquipier hors du cadre : un point au bord, dans sa direction.
			var direction := (ou - centre).normalized()
			_pastille(centre + direction * (COTE * 0.5 - 4.0), 2.5, a["couleur"])

	# Soi-même : un triangle au centre, pas un rond. Sur un plan, savoir où l'on
	# regarde vaut autant que savoir où l'on est.
	var avant := Vector2.RIGHT.rotated(mon_angle)
	var cote_m := Vector2(-avant.y, avant.x)
	draw_colored_polygon(PackedVector2Array([
		centre + avant * 7.0, centre - avant * 4.0 + cote_m * 4.0,
		centre - avant * 4.0 - cote_m * 4.0]), ma_couleur)

	draw_rect(cadre.grow(-UI.BORDURE * 0.5), UI.CADRE, false, UI.BORDURE)

	# La couleur ne porte jamais seule le sens : chaque pastille est nommée à
	# côté d'elle, sous le cadre.
	var police: Font = UI.TEXTE_POLICE
	var x := MARGE + 4.0
	var y := MARGE + COTE + 14.0
	for entree in [["garage", Palette.SERIE], ["cabine", Palette.AVERTISSEMENT],
			["arène", Palette.CRITIQUE], ["repaire", Palette.ENCRE]]:
		draw_circle(Vector2(x, y - 4.0), 3.0, entree[1])
		draw_string(police, Vector2(x + 7.0, y), String(entree[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_DOUCE)
		x += 8.0 + police.get_string_size(String(entree[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0

func _pastille(ou: Vector2, rayon: float, couleur: Color) -> void:
	draw_circle(ou, rayon, couleur)

func _vers_radar(point: Vector2, centre: Vector2) -> Vector2:
	return centre + (point - moi) * ECHELLE
