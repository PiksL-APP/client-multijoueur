extends Control
## Le plan de la ville, en petit, dans un coin de l'écran.
##
## Pourquoi il a fallu l'ajouter : la ville fait vingt-six par vingt tuiles et
## la caméra n'en montre que trois. Sans plan, on ne retrouve ni le garage de
## peinture quand on a cinq étoiles, ni la cabine qui donne un contrat, ni
## l'arène — et un joueur qui ne sait pas où aller tourne en rond puis s'en va.
##
## Il montre la ville ENTIÈRE et non les alentours : ce qu'on cherche dessus
## est toujours à l'autre bout, jamais à dix mètres.
##
## Séparé de l'écran de jeu comme `ui/manche.gd` l'est du tactile : ici on ne
## fait que peindre ce qu'on nous a donné.

const COTE := 172.0
const MARGE := 8.0

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
	var etendue := carte.etendue()
	var cadre := Rect2(Vector2(MARGE, MARGE), Vector2(COTE, COTE))
	draw_rect(cadre, Color(Palette.FOND, 0.86), true)
	draw_rect(cadre, Palette.FILET, false, 1.0)

	# Les territoires d'abord, en aplat léger : c'est la première chose qu'on
	# cherche sur le plan quand on a un contrat — où est le gang visé.
	for py in PlanVille.pates_y():
		for px in PlanVille.pates_x():
			var pate := Vector2i(px, py)
			var gang := carte.territoire_du_pate(pate)
			var coin := _vers_plan(Vector2(px * 4 + 1, py * 4 + 1) * PlanVille.PAS, etendue)
			var taille := _vers_plan(Vector2(3, 3) * PlanVille.PAS, etendue) - _vers_plan(Vector2.ZERO, etendue)
			if gang >= 0:
				draw_rect(Rect2(coin, taille), Color(carte.couleur_du_gang(gang), 0.22), true)
			elif carte.quartier_du_pate(pate) == PlanVille.PARC:
				draw_rect(Rect2(coin, taille), Color(Palette.BON, 0.10), true)
			else:
				draw_rect(Rect2(coin, taille), Color(Palette.ENCRE, 0.08), true)
	for r in carte.repaires:
		draw_rect(Rect2(_vers_plan(r["p"], etendue) - Vector2(3, 3), Vector2(6, 6)),
			carte.couleur_du_gang(int(r["gang"])), true)

	# Les rues : une ligne tous les quatre pas, dans les deux sens. Dessiner
	# les immeubles ferait cinq cents rectangles pour un carré de cent
	# soixante-douze pixels — illisible et cher.
	for colonne in range(0, PlanVille.COLONNES + 1, 4):
		var abscisse := _vers_plan(Vector2(float(colonne) * PlanVille.PAS, 0.0), etendue).x
		draw_line(Vector2(abscisse, cadre.position.y), Vector2(abscisse, cadre.end.y),
			Color(1, 1, 1, 0.16), 1.0)
	for ligne in range(0, PlanVille.LIGNES + 1, 4):
		var ordonnee := _vers_plan(Vector2(0.0, float(ligne) * PlanVille.PAS), etendue).y
		draw_line(Vector2(cadre.position.x, ordonnee), Vector2(cadre.end.x, ordonnee),
			Color(1, 1, 1, 0.16), 1.0)

	for centre_arene: Vector2 in carte.arenes():
		draw_arc(_vers_plan(centre_arene, etendue), 9.0, 0, TAU, 20, Palette.CRITIQUE, 1.5)
	for centre_garage: Vector2 in carte.garages():
		_pastille(_vers_plan(centre_garage, etendue), 4.0, Palette.SERIE)
	for centre_cabine: Vector2 in carte.cabines():
		_pastille(_vers_plan(centre_cabine, etendue), 3.0, Palette.AVERTISSEMENT)

	# La cible du contrat clignote : les repaires du gang à nettoyer, ou les
	# garages où livrer. Un contrat sans cible sur le plan, c'est un chrono qui
	# tourne pendant qu'on cherche.
	if not cible.is_empty() and fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5:
		var genre := String(cible.get("k", ""))
		if genre == "nettoyage":
			for r in carte.repaires:
				if int(r["gang"]) == int(cible.get("g", -1)):
					draw_arc(_vers_plan(r["p"], etendue), 8.0, 0, TAU, 16, Palette.AVERTISSEMENT, 2.0)
		elif genre == "livraison":
			for g: Vector2 in carte.garages():
				draw_arc(_vers_plan(g, etendue), 8.0, 0, TAU, 16, Palette.AVERTISSEMENT, 2.0)

	for p: Vector2 in patrouilles:
		_pastille(_vers_plan(p, etendue), 2.5, Palette.SERIE.lightened(0.3))
	for a in autres:
		_pastille(_vers_plan(a["p"], etendue), 3.5, a["couleur"])

	# Soi-même : un triangle, pas un rond. Sur un plan, savoir où l'on regarde
	# vaut autant que savoir où l'on est.
	var point := _vers_plan(moi, etendue)
	var avant := Vector2.RIGHT.rotated(mon_angle)
	var cote := Vector2(-avant.y, avant.x)
	draw_colored_polygon(PackedVector2Array([
		point + avant * 6.0, point - avant * 3.5 + cote * 3.5,
		point - avant * 3.5 - cote * 3.5]), ma_couleur)

	# La couleur ne porte jamais seule le sens : chaque pastille est nommée à
	# côté d'elle. La légende en une phrase — « bleu : garage, jaune : … » —
	# débordait du cadre et se coupait au milieu du dernier mot.
	var police := Palette.police()
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

## Les coordonnées de jeu peuvent sortir de la ville — la friche est jouable.
## On les serre dans le cadre plutôt que de les laisser peindre par-dessus le
## chrono.
func _vers_plan(point: Vector2, etendue: Vector2) -> Vector2:
	var part := Vector2(
		clamp(point.x / max(1.0, etendue.x), -0.06, 1.06),
		clamp(point.y / max(1.0, etendue.y), -0.06, 1.06))
	return Vector2(MARGE, MARGE) + part * COTE
