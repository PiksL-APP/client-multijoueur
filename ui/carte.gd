extends Control
## LA CARTE DE LA VILLE, plein écran : celle de GTA 2 — l'île, la rivière, la
## voie ferrée, les quartiers, où l'on est — mais qu'on MANIPULE. Molette pour
## zoomer (autour du curseur), glisser pour se déplacer, clic pour poser un
## repère GPS, clic droit ou clic sur le repère pour l'ôter. TAB l'ouvre et la
## laisse ouverte ; TAB ou ÉCHAP la referme.
##
## ⚠ Elle n'arrête pas la ville : c'est du multijoueur, et on la consulte en
## roulant comme on regarderait son téléphone au feu rouge. Seule la souris
## lui est réservée pendant qu'elle est ouverte.
##
## Le fond est une image d'un pixel par tuile, peinte par `carte_ville.gd`
## secteur par secteur pendant la manche ; on n'en redessine jamais un pixel
## ici, on la CADRE. Le dessin suit la charte de l'affiche (`Charte`) : voile
## nuit, filet blanc, dégradé sur le bord haut, capitales espacées.

signal gps_choisi(p: Vector2)          ## un point en pixels de jeu
signal gps_efface

const ZOOM_MAX := 12.0
const ZOOM_PAS := 1.25                 ## un cran de molette
const RAYON_REPERE := 9.0

var texture: Texture2D = null          ## un pixel par tuile
var etendue := Vector2.ONE             ## la ville, en pixels de jeu
var tuiles := Vector2i(1, 1)           ## la ville, en tuiles
var moi := Vector2.ZERO                ## en pixels de jeu
var mon_angle := 0.0
var ma_couleur := Color.WHITE
var autres: Array = []                 ## [{p: Vector2, couleur: Color}]
var gps := Vector2.ZERO                ## le repère, ZERO s'il n'y en a pas
var route := PackedVector2Array()      ## l'itinéraire, en pixels de jeu
var legende: Array = []                ## [[nom, couleur], …]
var boutique: Array = []               ## les lignes « où loger », vides si on a sa planque
var titre := "Pikstown"

var zoom := 1.0                        ## 1 = la ville entière tient dans le cadre
var centre_vue := Vector2.ZERO         ## en tuiles ; ZERO = pas encore cadré
var _glisse := false
var _depart_glisse := Vector2.ZERO
var _a_glisse := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP

## Le cadre de la carte à l'écran : sous une tête de panneau, au-dessus de la
## légende — et de la boutique quand on n'a pas encore de planque.
func _cadre() -> Rect2:
	var taille := size
	var marge := 28.0
	var haut := 62.0
	var bas := 54.0 + (78.0 if not boutique.is_empty() else 0.0)
	return Rect2(Vector2(marge, haut), Vector2(taille.x - 2.0 * marge, taille.y - haut - bas))

## Pixels d'écran par tuile, au zoom courant.
func _echelle(cadre: Rect2) -> float:
	var base := minf(cadre.size.x / float(tuiles.x), cadre.size.y / float(tuiles.y))
	return base * zoom

func _recadrer(cadre: Rect2) -> void:
	if centre_vue == Vector2.ZERO:
		centre_vue = Vector2(tuiles) * 0.5
	# La vue ne quitte pas la ville : au zoom 1 elle est centrée, au-delà on la
	# borne pour ne jamais montrer le vide autour.
	var e := _echelle(cadre)
	var demi := cadre.size * 0.5 / e
	if demi.x * 2.0 >= float(tuiles.x):
		centre_vue.x = float(tuiles.x) * 0.5
	else:
		centre_vue.x = clampf(centre_vue.x, demi.x, float(tuiles.x) - demi.x)
	if demi.y * 2.0 >= float(tuiles.y):
		centre_vue.y = float(tuiles.y) * 0.5
	else:
		centre_vue.y = clampf(centre_vue.y, demi.y, float(tuiles.y) - demi.y)

func _vers_ecran(p_tuiles: Vector2, cadre: Rect2) -> Vector2:
	return cadre.get_center() + (p_tuiles - centre_vue) * _echelle(cadre)

func _vers_tuiles(ecran: Vector2, cadre: Rect2) -> Vector2:
	return centre_vue + (ecran - cadre.get_center()) / _echelle(cadre)

func _en_tuiles(p: Vector2) -> Vector2:
	return p / etendue * Vector2(tuiles)

func _draw() -> void:
	var taille := size
	draw_rect(Rect2(Vector2.ZERO, taille), Color(Charte.NUIT, 0.86), true)
	var cadre := _cadre()
	_recadrer(cadre)

	# La tête : le nom de la ville en Archivo Black, le mode d'emploi à droite,
	# le filet de la maquette entre les deux et la carte.
	Charte.titre_dessine(self, Vector2(cadre.position.x, 40.0), titre.to_upper(), 22, Color.WHITE, 0)
	var aide := "molette zoom  ·  glisser déplacer  ·  clic gps  ·  clic droit effacer  ·  tab fermer"
	var la := Charte.largeur_capitales(aide, 11, 0.16)
	Charte.capitales_dessinees(self, Vector2(cadre.end.x - la, 38.0), aide, 11, Charte.ENCRE_FAIBLE, 0.16)
	Charte.filet_dessine(self, Vector2(cadre.position.x, 50.0), cadre.size.x)

	# Le fond : la part visible de l'image, agrandie sans lissage — un plan de
	# ville est fait de pixels, et flouter la rue ne la rend pas plus lisible.
	draw_rect(cadre, Color(PlanVille.CARTE_EAU, 1.0), true)
	if texture != null:
		var e := _echelle(cadre)
		var t0 := _vers_tuiles(cadre.position, cadre)
		var t1 := _vers_tuiles(cadre.end, cadre)
		var src := Rect2(t0, t1 - t0).intersection(Rect2(Vector2.ZERO, Vector2(tuiles)))
		if src.size.x > 0.0 and src.size.y > 0.0:
			var dest := Rect2(_vers_ecran(src.position, cadre), src.size * e)
			draw_texture_rect_region(texture, dest, src)
	draw_rect(cadre.grow(-0.5), Charte.CADRE, false, 1.0)

	# L'ITINÉRAIRE, en rose, sous les joueurs : la couleur de l'affiche pour
	# la seule chose qu'on soit venu chercher ici.
	if route.size() >= 2:
		var points := PackedVector2Array()
		for p in route:
			points.append(_vers_ecran(_en_tuiles(p), cadre))
		draw_polyline(points, Color(Charte.ROSE, 0.95), 3.0, true)

	for cle in autres:
		var a: Dictionary = cle
		var ou := _vers_ecran(_en_tuiles(a["p"]), cadre)
		if cadre.has_point(ou):
			draw_circle(ou, 5.0, a["couleur"])
	var moi_ecran := _vers_ecran(_en_tuiles(moi), cadre)
	if cadre.has_point(moi_ecran):
		var avant := Vector2.RIGHT.rotated(mon_angle)
		var cote := Vector2(-avant.y, avant.x)
		draw_colored_polygon(PackedVector2Array([moi_ecran + avant * 11.0,
			moi_ecran - avant * 6.0 + cote * 6.0, moi_ecran - avant * 6.0 - cote * 6.0]), ma_couleur)
		draw_arc(moi_ecran, 15.0, 0, TAU, 24, ma_couleur, 2.0)

	# LE REPÈRE GPS : un disque rose cerné, et un point blanc — le drapeau des
	# GTA. Hors du cadre, on ne le montre pas : la route y mène.
	if gps != Vector2.ZERO:
		var ou := _vers_ecran(_en_tuiles(gps), cadre)
		if cadre.has_point(ou):
			draw_circle(ou, RAYON_REPERE + 2.0, Color(Charte.NUIT, 0.8))
			draw_circle(ou, RAYON_REPERE, Charte.ROSE)
			draw_circle(ou, 3.0, Color.WHITE)
			var km := Gps.longueur(route) / PlanVille.PAS * 0.02  # une tuile fait vingt mètres
			if route.size() >= 2:
				var mot := "%.1f km" % km if km >= 1.0 else "%d m" % int(km * 1000.0)
				Charte.capitales_dessinees(self, ou + Vector2(RAYON_REPERE + 6.0, 5.0), mot, 12, Color.WHITE, 0.14, 4)

	# La légende, puis la boutique, sous le cadre — dans le panneau, jamais sur
	# la rue.
	var x := cadre.position.x
	var y := cadre.end.y + 24.0
	for entree in legende:
		var nom := String(entree[0])
		var l := Charte.largeur_capitales(nom, 11, 0.16)
		if x + l + 26.0 > cadre.end.x and x > cadre.position.x:
			x = cadre.position.x
			y += 16.0
		draw_rect(Rect2(Vector2(x, y - 9.0), Vector2(8, 8)), entree[1], true)
		Charte.capitales_dessinees(self, Vector2(x + 13.0, y), nom, 11, Charte.ENCRE_DOUCE, 0.16)
		x += 13.0 + l + 22.0
	if not boutique.is_empty():
		y += 26.0
		Charte.capitales_dessinees(self, Vector2(cadre.position.x, y), "où loger — le quartier décide de l'appartement", 11, Charte.ENCRE_FAIBLE, 0.16)
		var colonne := cadre.size.x * 0.25
		for i in boutique.size():
			Charte.texte_dessine(self, Vector2(cadre.position.x + float(i % 4) * colonne, y + 20.0 + float(i / 4) * 17.0),
				String(boutique[i]), 14, Charte.ENCRE_DOUCE, 0)

func _gui_input(evenement: InputEvent) -> void:
	var cadre := _cadre()
	if evenement is InputEventMouseButton:
		var e := evenement as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoomer(ZOOM_PAS, e.position, cadre)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoomer(1.0 / ZOOM_PAS, e.position, cadre)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_glisse = true
				_a_glisse = false
				_depart_glisse = e.position
			else:
				if _glisse and not _a_glisse and cadre.has_point(e.position):
					_cliquer(e.position, cadre)
				_glisse = false
			accept_event()
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			gps_efface.emit()
			accept_event()
	elif evenement is InputEventMouseMotion and _glisse:
		var m := evenement as InputEventMouseMotion
		# Quatre pixels de tolérance : un clic n'est pas un glisser, mais une
		# main qui tremble un peu non plus.
		if _a_glisse or m.position.distance_to(_depart_glisse) > 4.0:
			_a_glisse = true
			centre_vue -= m.relative / _echelle(cadre)
			queue_redraw()
		accept_event()

## Le zoom se fait AUTOUR DU CURSEUR : le point qu'on regarde reste sous la
## souris, comme sur n'importe quelle carte en ligne.
func _zoomer(facteur: float, souris: Vector2, cadre: Rect2) -> void:
	var avant := _vers_tuiles(souris, cadre)
	zoom = clampf(zoom * facteur, 1.0, ZOOM_MAX)
	var apres := _vers_tuiles(souris, cadre)
	centre_vue += avant - apres
	queue_redraw()

func _cliquer(souris: Vector2, cadre: Rect2) -> void:
	# Cliquer sur le repère l'efface ; ailleurs, on le pose là.
	if gps != Vector2.ZERO and _vers_ecran(_en_tuiles(gps), cadre).distance_to(souris) <= RAYON_REPERE + 4.0:
		gps_efface.emit()
		return
	var t := _vers_tuiles(souris, cadre)
	if t.x < 0.0 or t.y < 0.0 or t.x >= float(tuiles.x) or t.y >= float(tuiles.y):
		return
	gps_choisi.emit(t / Vector2(tuiles) * etendue)

## Recentrer sur soi, au zoom courant : appelé à l'ouverture.
func centrer_sur_moi() -> void:
	centre_vue = _en_tuiles(moi)
	queue_redraw()
