extends Control
## LA CARTE DE LA VILLE, plein écran : celle de GTA 2 — l'île, la rivière, la
## voie ferrée, les quartiers, où l'on est — mais qu'on MANIPULE. Molette pour
## zoomer (autour du curseur), glisser pour se déplacer, clic pour poser un
## repère GPS, clic droit ou clic sur le repère pour l'ôter. TAB l'ouvre et la
## laisse ouverte ; TAB ou ÉCHAP la referme.
##
## Les LIEUX y sont cliquables : une supérette, un garage, un repaire, une
## planque à vendre ont un glyphe — le même que sur le radar — et cliquer
## dessus pose le GPS SUR LE LIEU, pas à côté. Le nom se lit en survolant.
##
## Sans clavier ni molette (un téléphone), trois boutons en tête de panneau
## font le travail : − et + pour le zoom, ✕ pour fermer ; et le pincement
## zoome comme sur n'importe quelle carte en ligne.
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
signal fermer                          ## le bouton ✕ — l'écran de jeu referme
signal logement_choisi(id: String)     ## une ligne de la boutique : « je veux celui-là »

const ZOOM_MAX := 12.0
const ZOOM_PAS := 1.25                 ## un cran de molette
const RAYON_REPERE := 9.0
const RAYON_LIEU := 11.0               ## pixels d'écran : la tolérance du clic sur un lieu
const BOUTON := 26.0                   ## le côté des boutons de tête

var texture: Texture2D = null          ## un pixel par tuile
var etendue := Vector2.ONE             ## la ville, en pixels de jeu
var tuiles := Vector2i(1, 1)           ## la ville, en tuiles
var moi := Vector2.ZERO                ## en pixels de jeu
var mon_angle := 0.0
var ma_couleur := Color.WHITE
var autres: Array = []                 ## [{p: Vector2, couleur: Color}]
var gps := Vector2.ZERO                ## le repère, ZERO s'il n'y en a pas
var gps_nom := ""                      ## le lieu visé, s'il y en a un — lu par l'écran de jeu au signal
var route := PackedVector2Array()      ## l'itinéraire, en pixels de jeu
var legende: Array = []                ## [[nom, couleur], …]
var boutique: Array = []               ## les lignes « où loger », vides si on a sa planque
var boutique_ids: Array = []           ## l'appartement de chaque ligne, dans le même ordre
var _boutique_rects: Array = []        ## les lignes telles que dessinées — pour le clic
var lieux: Array = []                  ## [{p: Vector2, genre: String, nom: String, couleur: Color}]
var titre := "Pikstown"
var touche_fermer := "tab"             ## le nom de la touche, pour la ligne d'aide

var zoom := 1.0                        ## 1 = la ville entière tient dans le cadre
var centre_vue := Vector2.ZERO         ## en tuiles ; ZERO = pas encore cadré
var _glisse := false
var _depart_glisse := Vector2.ZERO
var _a_glisse := false
var _souris := Vector2(-1.0, -1.0)     ## la dernière position du curseur, pour le survol

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP

## Le cadre de la carte à l'écran : sous une tête de panneau, au-dessus de la
## légende — et de la boutique quand on n'a pas encore de planque.
func _cadre() -> Rect2:
	var taille := size
	var marge := 28.0
	var haut := 62.0
	var bas := 54.0
	if not boutique.is_empty():
		# La boutique prend ce qu'il lui faut : quatre colonnes sur un grand
		# écran, deux sur un téléphone — et le cadre de la carte recule
		# d'autant, plutôt que d'écrire par-dessus.
		bas += 38.0 + ceilf(float(boutique.size()) / float(_colonnes_boutique())) * 17.0
	return Rect2(Vector2(marge, haut), Vector2(taille.x - 2.0 * marge, taille.y - haut - bas))

func _colonnes_boutique() -> int:
	return 4 if size.x >= 1180.0 else 2

## Les trois boutons de tête, de gauche à droite : −, +, ✕. Alignés sur le
## bord droit du cadre, à hauteur du titre.
func _boutons(cadre: Rect2) -> Dictionary:
	var y := 24.0
	var x := cadre.end.x - BOUTON
	var r := {}
	r["fermer"] = Rect2(Vector2(x, y), Vector2(BOUTON, BOUTON))
	x -= BOUTON + 8.0
	r["plus"] = Rect2(Vector2(x, y), Vector2(BOUTON, BOUTON))
	x -= BOUTON + 4.0
	r["moins"] = Rect2(Vector2(x, y), Vector2(BOUTON, BOUTON))
	return r

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

## Le lieu sous un point d'écran, ou {} : le plus proche à moins de
## `RAYON_LIEU`. Les cabines ne comptent qu'au zoom où on les dessine —
## sinon on viserait une cabine invisible en cliquant une rue.
func _lieu_sous(ecran: Vector2, cadre: Rect2) -> Dictionary:
	var meilleur := {}
	var d_min := RAYON_LIEU
	var e := _echelle(cadre)
	for l in lieux:
		var lieu: Dictionary = l
		if String(lieu["genre"]) == "cabine" and e < 2.5:
			continue
		var d := _vers_ecran(_en_tuiles(lieu["p"]), cadre).distance_to(ecran)
		if d < d_min:
			d_min = d
			meilleur = lieu
	return meilleur

func _draw() -> void:
	var taille := size
	draw_rect(Rect2(Vector2.ZERO, taille), Color(Charte.NUIT, 0.86), true)
	var cadre := _cadre()
	_recadrer(cadre)

	# La tête : le nom de la ville en Archivo Black, les trois boutons à
	# droite, le mode d'emploi entre les deux, le filet de la maquette entre
	# la tête et la carte.
	Charte.titre_dessine(self, Vector2(cadre.position.x, 40.0), titre.to_upper(), 22, Color.WHITE, 0)
	var boutons := _boutons(cadre)
	_bouton_dessine(boutons["moins"], "−", zoom > 1.0)
	_bouton_dessine(boutons["plus"], "+", zoom < ZOOM_MAX)
	_bouton_dessine(boutons["fermer"], "✕", true)
	var aide := "molette zoom  ·  glisser déplacer  ·  clic gps  ·  clic droit effacer  ·  %s fermer" % touche_fermer
	if Tactile.actif():
		aide = "pincer ou − + zoom  ·  glisser déplacer  ·  toucher gps  ·  toucher le repère effacer"
	var la := Charte.largeur_capitales(aide, 11, 0.16)
	var droite: float = (boutons["moins"] as Rect2).position.x - 18.0
	if cadre.position.x + Charte.largeur_titre(titre.to_upper(), 22) + 24.0 + la <= droite:
		Charte.capitales_dessinees(self, Vector2(droite - la, 38.0), aide, 11, Charte.ENCRE_FAIBLE, 0.16)
	Charte.filet_dessine(self, Vector2(cadre.position.x, 50.0), cadre.size.x)

	# Le fond : la part visible de l'image, agrandie sans lissage — un plan de
	# ville est fait de pixels, et flouter la rue ne la rend pas plus lisible.
	draw_rect(cadre, Color(PlanVille.CARTE_EAU, 1.0), true)
	var e := _echelle(cadre)
	if texture != null:
		var t0 := _vers_tuiles(cadre.position, cadre)
		var t1 := _vers_tuiles(cadre.end, cadre)
		var src := Rect2(t0, t1 - t0).intersection(Rect2(Vector2.ZERO, Vector2(tuiles)))
		if src.size.x > 0.0 and src.size.y > 0.0:
			var dest := Rect2(_vers_ecran(src.position, cadre), src.size * e)
			draw_texture_rect_region(texture, dest, src)
	draw_rect(cadre.grow(-0.5), Charte.CADRE, false, 1.0)

	# L'ITINÉRAIRE, en rose, sous les joueurs : la couleur de l'affiche pour
	# la seule chose qu'on soit venu chercher ici. Sans route (une île, l'eau),
	# un pointillé à vol d'oiseau dit au moins DANS QUELLE DIRECTION.
	if route.size() >= 2:
		var points := PackedVector2Array()
		for p in route:
			points.append(_vers_ecran(_en_tuiles(p), cadre))
		draw_polyline(points, Color(Charte.ROSE, 0.95), 3.0, true)
	elif gps != Vector2.ZERO:
		draw_dashed_line(_vers_ecran(_en_tuiles(moi), cadre), _vers_ecran(_en_tuiles(gps), cadre),
			Color(Charte.ROSE, 0.55), 2.0, 8.0)

	# LES LIEUX, avec les glyphes du radar : on reconnaît d'un écran à l'autre.
	# Les cabines n'apparaissent qu'en se rapprochant — il y en a une par pâté
	# et, au zoom 1, elles feraient une carte de confettis.
	var survole := _lieu_sous(_souris, cadre) if cadre.has_point(_souris) and not _glisse else {}
	for l in lieux:
		var lieu: Dictionary = l
		var genre := String(lieu["genre"])
		if genre == "cabine" and e < 2.5:
			continue
		var ou := _vers_ecran(_en_tuiles(lieu["p"]), cadre)
		if not cadre.grow(-4.0).has_point(ou):
			continue
		var couleur: Color = lieu["couleur"]
		match genre:
			"repaire", "supérette":
				draw_rect(Rect2(ou - Vector2(3.5, 3.5), Vector2(7, 7)), Color(Charte.NUIT, 0.8), true)
				draw_rect(Rect2(ou - Vector2(2.5, 2.5), Vector2(5, 5)), couleur, true)
			"hôpital":
				draw_line(ou - Vector2(4, 0), ou + Vector2(4, 0), couleur, 2.0)
				draw_line(ou - Vector2(0, 4), ou + Vector2(0, 4), couleur, 2.0)
			"arène":
				draw_arc(ou, maxf(5.0, PlanVille.RAYON_ARENE / etendue.x * float(tuiles.x) * e), 0, TAU, 20, couleur, 1.5)
			"cabine":
				draw_circle(ou, 2.5, couleur)
			_:
				draw_circle(ou, 4.5, Color(Charte.NUIT, 0.8))
				draw_circle(ou, 3.5, couleur)

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
			var mot := gps_nom
			if route.size() >= 2:
				var km := Gps.longueur(route) / PlanVille.PAS * 0.02  # une tuile fait vingt mètres
				var dist := "%.1f km" % km if km >= 1.0 else "%d m" % int(km * 1000.0)
				mot = dist if mot == "" else "%s · %s" % [mot, dist]
			if mot != "":
				Charte.capitales_dessinees(self, ou + Vector2(RAYON_REPERE + 6.0, 5.0), mot, 12, Color.WHITE, 0.14, 4)

	# LE SURVOL : le nom du lieu sous le curseur, dans un petit cartouche qui
	# suit la souris. C'est ce qui rend les glyphes lisibles sans légende
	# collée à chacun.
	if not survole.is_empty():
		var nom := String(survole["nom"])
		var ln := Charte.largeur_capitales(nom, 12, 0.14)
		var boite := Rect2(_souris + Vector2(14.0, -30.0), Vector2(ln + 20.0, 24.0))
		if boite.end.x > cadre.end.x:
			boite.position.x = _souris.x - 14.0 - boite.size.x
		if boite.position.y < cadre.position.y:
			boite.position.y = _souris.y + 14.0
		Charte.cartouche(self, boite, survole["couleur"])
		Charte.capitales_dessinees(self, boite.position + Vector2(10.0, 17.0), nom, 12, Color.WHITE, 0.14)

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
		Charte.capitales_dessinees(self, Vector2(cadre.position.x, y), "où loger — le quartier décide de l'appartement · cliquer une ligne : gps vers la plus proche", 11, Charte.ENCRE_FAIBLE, 0.16)
		var colonnes := _colonnes_boutique()
		var colonne := cadre.size.x / float(colonnes)
		_boutique_rects.clear()
		for i in boutique.size():
			var ou := Vector2(cadre.position.x + float(i % colonnes) * colonne, y + 20.0 + float(i / colonnes) * 17.0)
			var ligne := Rect2(ou + Vector2(-6.0, -14.0), Vector2(colonne - 12.0, 17.0))
			_boutique_rects.append(ligne)
			# Une ligne se survole comme un lien : c'en est un — elle mène à
			# la planque la plus proche qui donne cet appartement.
			var sous := ligne.has_point(_souris)
			if sous:
				draw_rect(ligne, Color(Charte.ROSE, 0.16), true)
			Charte.texte_dessine(self, ou, String(boutique[i]), 14, Color.WHITE if sous else Charte.ENCRE_DOUCE, 0)
	else:
		_boutique_rects.clear()

## Un bouton de tête : un carré au filet blanc, le signe au milieu. Éteint
## quand il ne ferait rien (− au zoom 1), pour ne pas inviter à un clic mort.
func _bouton_dessine(rect: Rect2, signe: String, actif: bool) -> void:
	var alpha := 1.0 if actif else 0.35
	var sous := rect.has_point(_souris) and actif
	draw_rect(rect, Color(1, 1, 1, 0.16 if sous else 0.07), true)
	draw_rect(rect.grow(-0.5), Color(1, 1, 1, 0.34 * alpha), false, 1.0)
	# Les signes sont TRACÉS, pas écrits : la police condensée n'a ni le
	# moins typographique ni la croix, et une case vide à la place d'un
	# bouton, c'est un bouton qu'on ne trouve pas.
	var c := rect.get_center()
	var d := 5.0
	var encre := Color(1, 1, 1, alpha)
	match signe:
		"−":
			draw_line(c - Vector2(d, 0), c + Vector2(d, 0), encre, 2.0)
		"+":
			draw_line(c - Vector2(d, 0), c + Vector2(d, 0), encre, 2.0)
			draw_line(c - Vector2(0, d), c + Vector2(0, d), encre, 2.0)
		_:
			draw_line(c - Vector2(d, d), c + Vector2(d, d), encre, 2.0)
			draw_line(c - Vector2(d, -d), c + Vector2(d, -d), encre, 2.0)

func _gui_input(evenement: InputEvent) -> void:
	var cadre := _cadre()
	if evenement is InputEventMouseButton:
		var e := evenement as InputEventMouseButton
		_souris = e.position
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoomer(ZOOM_PAS, e.position, cadre)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoomer(1.0 / ZOOM_PAS, e.position, cadre)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				# Les boutons de tête d'abord : un appui dessus n'est ni un
				# clic sur la rue ni le début d'un glisser.
				var boutons := _boutons(cadre)
				if (boutons["fermer"] as Rect2).has_point(e.position):
					fermer.emit()
				elif (boutons["plus"] as Rect2).has_point(e.position):
					_zoomer(ZOOM_PAS * ZOOM_PAS, cadre.get_center(), cadre)
				elif (boutons["moins"] as Rect2).has_point(e.position):
					_zoomer(1.0 / (ZOOM_PAS * ZOOM_PAS), cadre.get_center(), cadre)
				else:
					_glisse = true
					_a_glisse = false
					_depart_glisse = e.position
			else:
				if _glisse and not _a_glisse:
					if cadre.has_point(e.position):
						_cliquer(e.position, cadre)
					else:
						for i in _boutique_rects.size():
							if (_boutique_rects[i] as Rect2).has_point(e.position) and i < boutique_ids.size():
								logement_choisi.emit(String(boutique_ids[i]))
								break
				_glisse = false
			accept_event()
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			gps_efface.emit()
			accept_event()
	elif evenement is InputEventMouseMotion:
		var m := evenement as InputEventMouseMotion
		_souris = m.position
		if _glisse:
			# Quatre pixels de tolérance : un clic n'est pas un glisser, mais une
			# main qui tremble un peu non plus.
			if _a_glisse or m.position.distance_to(_depart_glisse) > 4.0:
				_a_glisse = true
				centre_vue -= m.relative / _echelle(cadre)
		queue_redraw()
		accept_event()
	elif evenement is InputEventMagnifyGesture:
		# Le pincement (téléphone, pavé tactile) : le facteur arrive tel quel,
		# légèrement au-dessus ou au-dessous de 1 à chaque image du geste.
		var g := evenement as InputEventMagnifyGesture
		_zoomer(g.factor, g.position, cadre)
		accept_event()
	elif evenement is InputEventPanGesture:
		var g := evenement as InputEventPanGesture
		centre_vue += g.delta * 24.0 / _echelle(cadre)
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
	# Cliquer sur le repère l'efface ; sur un lieu, on vise LE LIEU (sa porte,
	# pas le pâté d'à côté) ; ailleurs, on le pose là.
	if gps != Vector2.ZERO and _vers_ecran(_en_tuiles(gps), cadre).distance_to(souris) <= RAYON_REPERE + 4.0:
		gps_efface.emit()
		return
	var lieu := _lieu_sous(souris, cadre)
	if not lieu.is_empty():
		gps_nom = String(lieu["nom"])
		gps_choisi.emit(Vector2(lieu["p"]))
		return
	var t := _vers_tuiles(souris, cadre)
	if t.x < 0.0 or t.y < 0.0 or t.x >= float(tuiles.x) or t.y >= float(tuiles.y):
		return
	gps_nom = ""
	gps_choisi.emit(t / Vector2(tuiles) * etendue)

## Recentrer sur soi, au zoom courant : appelé à l'ouverture.
func centrer_sur_moi() -> void:
	centre_vue = _en_tuiles(moi)
	queue_redraw()
