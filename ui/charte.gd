class_name Charte
extends RefCounted
## La charte de Pikstown : les couleurs de la jaquette, les deux polices de
## l'affiche, et les quelques libellés qu'on répète d'un écran à l'autre.
##
## Elle ne remplace pas `UI` (`ui/fabrique.gd`), qui habille le JEU : là-bas
## c'est une borne d'arcade, filets de deux pixels et police à grille. Ici
## c'est l'affiche du film — capitales condensées très espacées, néon rose et
## cyan, titres en Archivo Black. Les deux ne se mélangent pas : l'un est ce
## qu'on voit avant d'entrer en ville, l'autre ce qu'on voit une fois dedans.

const ROSE := Color("#ff2ea6")
const CYAN := Color("#22e3f2")
const ORANGE := Color("#ff9d2e")
const VIOLET := Color("#7b2ff7")
const VERT := Color("#39ff88")
const NUIT := Color("#05040a")
const CERNE := Color(0.04, 0.02, 0.06, 0.95)

const TITRE := preload("res://polices/ArchivoBlack.ttf")
const CAPITALES := preload("res://polices/BarlowCondensed-Bold.ttf")
const COURANTE := preload("res://polices/BarlowCondensed-SemiBold.ttf")

## `clamp(min, Nvw, max)` de la maquette, rendu en pixels. Les tailles y sont
## toutes exprimées ainsi : un plancher, une fraction de la largeur de la
## fenêtre, un plafond. On les reprend telles quelles plutôt que de choisir des
## tailles fixes — c'est ce qui fait que l'écran tient du téléphone au grand
## moniteur exactement comme sur le dessin.
static func serre(mini: float, part_vw: float, maxi: float) -> int:
	var boucle := Engine.get_main_loop()
	var largeur := 1280.0
	if boucle is SceneTree and (boucle as SceneTree).root != null:
		var v: float = (boucle as SceneTree).root.get_visible_rect().size.x
		if v > 1.0:
			largeur = v
	return int(round(clampf(largeur * part_vw * 0.01, mini, maxi)))

## Un libellé en CAPITALES ESPACÉES, cerné de noir. C'est la signature de tout
## l'habillage d'avant-partie ; l'espacement se donne en fraction de cadratin
## comme dans une feuille de style, et se convertit ici en pixels — le moteur
## ne connaît que les pixels.
static func capitales(texte: String, taille: int, couleur: Color,
		espacement: float = 0.24, cerne: int = 6) -> Label:
	var e := Label.new()
	e.text = texte.to_upper()
	e.add_theme_font_override("font", CAPITALES)
	e.add_theme_font_size_override("font_size", taille)
	e.add_theme_color_override("font_color", couleur)
	e.add_theme_color_override("font_outline_color", CERNE)
	e.add_theme_constant_override("outline_size", cerne)
	e.add_theme_constant_override("font_spacing_glyph", int(round(taille * espacement)))
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e

## Un titre d'écran, en Archivo Black.
static func titre(texte: String, taille: int = 40, couleur: Color = Color.WHITE) -> Label:
	var e := Label.new()
	e.text = texte.to_upper()
	e.add_theme_font_override("font", TITRE)
	e.add_theme_font_size_override("font_size", taille)
	e.add_theme_color_override("font_color", couleur)
	e.add_theme_color_override("font_outline_color", CERNE)
	e.add_theme_constant_override("outline_size", 8)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e

## Du texte courant, condensé, pour les explications.
static func texte(contenu: String, taille: int = 17,
		couleur: Color = Color(1, 1, 1, 0.62), replier: bool = false) -> Label:
	var e := Label.new()
	e.text = contenu
	e.add_theme_font_override("font", COURANTE)
	e.add_theme_font_size_override("font_size", taille)
	e.add_theme_color_override("font_color", couleur)
	e.add_theme_color_override("font_outline_color", CERNE)
	e.add_theme_constant_override("outline_size", 5)
	if replier:
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e

## Le filet violet–rose–cyan qui souligne chaque en-tête de la maquette. Deux
## pixels de haut, et c'est lui qui dit qu'on est chez Pikstown.
static func filet() -> TextureRect:
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	degrade.colors = PackedColorArray([VIOLET, ROSE, CYAN])
	var t := GradientTexture2D.new()
	t.gradient = degrade
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	var n := TextureRect.new()
	n.texture = t
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode = TextureRect.STRETCH_SCALE
	n.custom_minimum_size = Vector2(0, 2)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

## L'en-tête d'un écran d'avant-partie : le titre, sa ligne d'explication, et
## le filet dessous.
static func entete(principal: String, secondaire: String = "", taille: int = 40) -> VBoxContainer:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 6)
	colonne.add_child(titre(principal, taille))
	if secondaire != "":
		colonne.add_child(texte(secondaire, 17, Color(1, 1, 1, 0.6)))
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 6)
	colonne.add_child(espace)
	colonne.add_child(filet())
	return colonne

## Un bouton d'action. `principal` : celui qu'on vient chercher — fond rose
## plein, texte noir, comme sur la maquette. Les autres sont des cadres nus
## qui s'allument en cyan au survol.
static func bouton(libelle: String, principal: bool = false) -> Button:
	var b := Button.new()
	b.text = libelle.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", TITRE if principal else CAPITALES)
	b.add_theme_font_size_override("font_size", 20 if principal else 17)
	if not principal:
		b.add_theme_constant_override("font_spacing_glyph", 3)

	var repos := StyleBoxFlat.new()
	repos.bg_color = ROSE if principal else Color(1, 1, 1, 0.05)
	repos.border_color = ROSE if principal else Color(1, 1, 1, 0.20)
	repos.set_border_width_all(0 if principal else 1)
	repos.set_content_margin_all(14)
	var survol := repos.duplicate() as StyleBoxFlat
	survol.bg_color = CYAN if principal else Color(1, 1, 1, 0.09)
	survol.border_color = CYAN
	var eteint := repos.duplicate() as StyleBoxFlat
	eteint.bg_color = Color(1, 1, 1, 0.04)
	eteint.border_color = Color(1, 1, 1, 0.10)

	b.add_theme_stylebox_override("normal", repos)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("disabled", eteint)
	b.add_theme_color_override("font_color", NUIT if principal else Color.WHITE)
	b.add_theme_color_override("font_hover_color", NUIT if principal else CYAN)
	b.add_theme_color_override("font_pressed_color", NUIT if principal else CYAN)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	return b

## Le champ de saisie : fond noir, filet rose, texte condensé. Un seul dans
## tout l'avant-partie — le pseudo.
static func champ(indication: String, valeur: String = "") -> LineEdit:
	var c := LineEdit.new()
	c.text = valeur
	c.placeholder_text = indication
	c.add_theme_font_override("font", CAPITALES)
	c.add_theme_font_size_override("font_size", 22)
	c.add_theme_color_override("font_color", Color.WHITE)
	c.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.32))
	c.add_theme_color_override("caret_color", ROSE)
	var boite := StyleBoxFlat.new()
	boite.bg_color = Color(0, 0, 0, 0.55)
	boite.border_color = ROSE
	boite.set_border_width_all(1)
	boite.set_content_margin_all(14)
	c.add_theme_stylebox_override("normal", boite)
	c.add_theme_stylebox_override("focus", boite)
	return c

## Le voyant de connexion : une pastille et son libellé, verts en ligne, roses
## sinon. Renvoie la rangée ; `rafraichir_etat` la remet à jour.
static func etat_reseau() -> HBoxContainer:
	var boite := HBoxContainer.new()
	boite.add_theme_constant_override("separation", 8)
	var pastille := ColorRect.new()
	pastille.name = "pastille"
	pastille.custom_minimum_size = Vector2(8, 8)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boite.add_child(pastille)
	var libelle := capitales("", 14, VERT)
	libelle.name = "libelle"
	boite.add_child(libelle)
	rafraichir_etat(boite)
	return boite

## L'EN-TÊTE DE PIKSTOWN, celui de la maquette : le lettrage en haut à gauche
## avec son halo rose, et à droite le nom de la ville, sa devise, et le bouton
## qui coupe le son. Le même sur l'écran de chargement et sur le menu — c'est
## le seul élément que la maquette garde d'un écran à l'autre, et le déplacer
## ou le refaire ailleurs se verrait tout de suite.
static func entete_pikstown(couche: Node) -> Control:
	var marge: int = serre(18, 2.6, 42)
	var haut := HBoxContainer.new()
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = marge
	haut.offset_right = -marge
	haut.offset_top = marge
	haut.alignment = BoxContainer.ALIGNMENT_BEGIN
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(haut)

	var logo := TextureRect.new()
	logo.texture = load("res://images/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var t: Texture2D = logo.texture
	var large: float = serre(180, 26.0, 420)
	logo.custom_minimum_size = Vector2(large, large * float(t.get_height()) / float(t.get_width()))
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haut.add_child(logo)

	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(espace)

	var droite := VBoxContainer.new()
	droite.alignment = BoxContainer.ALIGNMENT_BEGIN
	droite.add_theme_constant_override("separation", 6)
	haut.add_child(droite)

	droite.add_child(bouton_son())
	var ville := capitales("Pikstown", serre(13, 1.35, 22), CYAN, 0.34, 0)
	ville.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ville.size_flags_horizontal = Control.SIZE_SHRINK_END
	droite.add_child(ville)
	var devise := capitales("The Heart of Vice", serre(10, 1.0, 15), Color(1, 1, 1, 0.6), 0.28, 0)
	devise.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	devise.size_flags_horizontal = Control.SIZE_SHRINK_END
	droite.add_child(devise)
	return haut

## Le bouton « SON » de la maquette : quatre barres d'égaliseur qui montent et
## descendent, et le libellé à côté. Il coupe vraiment le son.
static func bouton_son() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	var taille: int = serre(10, 0.95, 14)
	b.add_theme_font_override("font", CAPITALES)
	b.add_theme_font_size_override("font_size", taille)
	b.add_theme_constant_override("font_spacing_glyph", int(round(taille * 0.24)))
	var boite := StyleBoxFlat.new()
	boite.bg_color = Color(NUIT, 0.55)
	boite.border_color = Color(1, 1, 1, 0.22)
	boite.set_border_width_all(1)
	boite.content_margin_top = 8
	boite.content_margin_bottom = 8
	# La marge gauche réserve la place des quatre barres d'égaliseur, qui sont
	# DESSINÉES et non écrites : sans elle, elles se posent sur le libellé.
	boite.content_margin_left = 14 + 21 + 10
	boite.content_margin_right = 14
	var survol := boite.duplicate() as StyleBoxFlat
	survol.border_color = ROSE
	for etat in ["normal", "pressed"]:
		b.add_theme_stylebox_override(etat, boite)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", ROSE)
	b.set_script(load("res://ui/bouton_son.gd"))
	return b

static func rafraichir_etat(boite: HBoxContainer) -> void:
	if boite == null or not is_instance_valid(boite):
		return
	var pastille := boite.get_node_or_null("pastille") as ColorRect
	var libelle := boite.get_node_or_null("libelle") as Label
	if pastille == null or libelle == null:
		return
	var teinte: Color = VERT if Reseau.etat == Reseau.EN_LIGNE else ROSE
	pastille.color = teinte
	libelle.text = Reseau.libelle_etat().to_upper()
	libelle.add_theme_color_override("font_color", teinte)

# ------------------------------------------------------- dessin direct
# Le tableau de bord, le radar, la carte et les menus de la ville se peignent
# dans `_draw` : trente rectangles à recaler à chaque image, c'est un dessin,
# pas un arbre de nœuds. Ces fonctions leur donnent la même main qu'aux écrans
# d'avant-partie — c'est ce qui fait qu'on ne change pas de logiciel en
# passant du menu à la rue. Elles remplacent, pour Carnage, celles de `UI`
# (la borne d'arcade), qui restent aux autres jeux.

const VOILE := Color(0.02, 0.016, 0.04, 0.74)     ## le fond d'un cartouche posé sur la ville
const CADRE := Color(1, 1, 1, 0.16)               ## son filet
const ENCRE_DOUCE := Color(1, 1, 1, 0.66)
const ENCRE_FAIBLE := Color(1, 1, 1, 0.40)
const FILET_HAUT := 2.0                           ## le dégradé qui coiffe chaque cartouche

## Le cartouche de la ville : voile nuit, filet blanc léger, et le dégradé
## violet–rose–cyan sur son bord haut — la signature de la maquette. `accent`
## remplace le dégradé par une couleur pleine : un cartouche qui a quelque
## chose à dire (le contrat, la supérette) prend la couleur de son sujet.
static func cartouche(sur: CanvasItem, rect: Rect2, accent: Color = Color(0, 0, 0, 0),
		voile: Color = VOILE) -> void:
	sur.draw_rect(rect, voile, true)
	sur.draw_rect(rect.grow(-0.5), CADRE, false, 1.0)
	if accent.a > 0.0:
		sur.draw_rect(Rect2(rect.position, Vector2(rect.size.x, FILET_HAUT)), accent, true)
	else:
		filet_dessine(sur, rect.position, rect.size.x)

## Le dégradé de la maquette, en trois aplats fondus : VIOLET, ROSE, CYAN.
## Douze segments suffisent — sur deux pixels de haut, l'œil ne voit pas les
## marches.
static func filet_dessine(sur: CanvasItem, ou: Vector2, largeur: float, epaisseur: float = FILET_HAUT) -> void:
	var n := 12
	for i in n:
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		var c := VIOLET.lerp(ROSE, t0 * 2.0) if t0 < 0.5 else ROSE.lerp(CYAN, (t0 - 0.5) * 2.0)
		sur.draw_rect(Rect2(ou + Vector2(largeur * t0, 0.0), Vector2(largeur * (t1 - t0) + 0.5, epaisseur)), c, true)

## Des CAPITALES ESPACÉES, dessinées lettre à lettre : `draw_string` ne connaît
## pas l'interlettrage, et c'est l'interlettrage qui fait le style. Renvoie
## la largeur occupée. `cerne` : l'ourlet sombre qui garde la lettre lisible
## sur une rue claire.
static func capitales_dessinees(sur: CanvasItem, ou: Vector2, texte_: String, taille: int,
		couleur: Color, espacement: float = 0.22, cerne: int = 0) -> float:
	var x := ou.x
	var pas := roundf(taille * espacement)
	for lettre in texte_.to_upper():
		var l := CAPITALES.get_string_size(lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		if cerne > 0:
			sur.draw_string_outline(CAPITALES, Vector2(x, ou.y), lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, cerne, Color(CERNE, couleur.a))
		sur.draw_string(CAPITALES, Vector2(x, ou.y), lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
		x += l + pas
	return x - ou.x - pas

static func largeur_capitales(texte_: String, taille: int, espacement: float = 0.22) -> float:
	var total := 0.0
	var pas := roundf(taille * espacement)
	for lettre in texte_.to_upper():
		total += CAPITALES.get_string_size(lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + pas
	return maxf(0.0, total - pas)

## Un chiffre ou un titre en Archivo Black, cerné : le chrono, l'argent, le
## nom de l'arme. C'est la police du lettrage de l'affiche.
static func titre_dessine(sur: CanvasItem, ou: Vector2, texte_: String, taille: int, couleur: Color, cerne: int = 4) -> float:
	if cerne > 0:
		sur.draw_string_outline(TITRE, ou, texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, cerne, Color(CERNE, couleur.a))
	sur.draw_string(TITRE, ou, texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
	return TITRE.get_string_size(texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

static func largeur_titre(texte_: String, taille: int) -> float:
	return TITRE.get_string_size(texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

## Du texte courant condensé, cerné.
static func texte_dessine(sur: CanvasItem, ou: Vector2, texte_: String, taille: int, couleur: Color, cerne: int = 3) -> float:
	if cerne > 0:
		sur.draw_string_outline(COURANTE, ou, texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, cerne, Color(CERNE, couleur.a))
	sur.draw_string(COURANTE, ou, texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
	return COURANTE.get_string_size(texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

static func largeur_texte(texte_: String, taille: int) -> float:
	return COURANTE.get_string_size(texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

## Une inscription centrée, en capitales cernées : « RECHERCHE », le décompte,
## la station qu'on vise.
static func inscription(sur: CanvasItem, centre: Vector2, texte_: String, taille: int, couleur: Color,
		espacement: float = 0.22) -> void:
	var l := largeur_capitales(texte_, taille, espacement)
	capitales_dessinees(sur, centre + Vector2(-l * 0.5, taille * 0.36), texte_, taille, couleur, espacement, 5)

## Une inscription en Archivo Black, centrée, cernée : le décompte du départ.
static func inscription_titre(sur: CanvasItem, centre: Vector2, texte_: String, taille: int, couleur: Color) -> void:
	var l := largeur_titre(texte_, taille)
	titre_dessine(sur, centre + Vector2(-l * 0.5, taille * 0.36), texte_, taille, couleur, 8)

## Une jauge de la maquette : le libellé en capitales à gauche, la valeur à
## droite, et dessous une barre fine sur un fond à peine plus clair que le
## voile — celle des réglages du son, pas celle d'une borne. Elle vire au rose
## sous un quart : une jauge qu'on ne lit pas est une jauge qui ne sert à rien.
static func jauge(sur: CanvasItem, rect: Rect2, libelle: String, part: float, couleur: Color, valeur: String = "") -> void:
	var haut := rect.position.y + 11.0
	capitales_dessinees(sur, Vector2(rect.position.x, haut), libelle, 11, ENCRE_DOUCE, 0.20)
	if valeur != "":
		var l := largeur_texte(valeur, 12)
		texte_dessine(sur, Vector2(rect.end.x - l, haut), valeur, 12, Color.WHITE, 0)
	var barre := Rect2(Vector2(rect.position.x, rect.end.y - 4.0), Vector2(rect.size.x, 4.0))
	sur.draw_rect(barre, Color(1, 1, 1, 0.10), true)
	var p := clampf(part, 0.0, 1.0)
	var teinte := couleur if p > 0.25 else ROSE
	if p > 0.0:
		sur.draw_rect(Rect2(barre.position, Vector2(maxf(1.0, barre.size.x * p), barre.size.y)), teinte, true)
		# La perle au bout de la barre : le curseur des réglages, en plus petit.
		sur.draw_circle(barre.position + Vector2(barre.size.x * p, 2.0), 3.0, Color.WHITE)

## Un cabochon de touche : le cadre nu des boutons secondaires de la maquette,
## la touche en capitales, l'action en texte courant à côté. Renvoie la
## largeur occupée pour enchaîner les touches sur une ligne.
static func cabochon(sur: CanvasItem, ou: Vector2, cle: String, action: String, alpha: float = 1.0) -> float:
	var lc := largeur_capitales(cle, 11, 0.12)
	var boite := Rect2(ou, Vector2(lc + 14.0, 20.0))
	sur.draw_rect(boite, Color(1, 1, 1, 0.07 * alpha), true)
	sur.draw_rect(boite.grow(-0.5), Color(1, 1, 1, 0.28 * alpha), false, 1.0)
	capitales_dessinees(sur, ou + Vector2(7.0, 14.0), cle, 11, Color(1, 1, 1, alpha), 0.12)
	var la := texte_dessine(sur, ou + Vector2(boite.size.x + 7.0, 14.5), action, 13, Color(ENCRE_DOUCE, alpha), 3)
	return boite.size.x + 7.0 + la + 20.0

## Une étoile à cinq branches, pleine : celles de la recherche.
static func etoile(sur: CanvasItem, centre: Vector2, rayon: float, couleur: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := rayon if i % 2 == 0 else rayon * 0.45
		var angle := -PI * 0.5 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	sur.draw_colored_polygon(points, couleur)

## La ligne visée d'un menu : un surlignage plein, et une barre rose à gauche
## — le « bouton principal » de la maquette, couché.
static func ligne_visee(sur: CanvasItem, rect: Rect2, couleur: Color = ROSE) -> void:
	sur.draw_rect(rect, Color(couleur, 0.14), true)
	sur.draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), couleur, true)

## LE MENU POSÉ SUR LA VILLE : un voile sur tout l'écran, le cartouche, son
## titre en Archivo Black avec le filet dessous — l'en-tête des écrans
## d'avant-partie, en réduction. Renvoie le rectangle du cartouche ; le
## contenu commence sous `haut_contenu(rect)`.
static func menu(sur: CanvasItem, taille_ecran: Vector2, largeur: float, hauteur: float,
		titre_: String, sous_titre: String = "", couleur_titre: Color = Color.WHITE) -> Rect2:
	var rect := Rect2((taille_ecran - Vector2(largeur, hauteur)) * 0.5, Vector2(largeur, hauteur))
	sur.draw_rect(Rect2(Vector2.ZERO, taille_ecran), Color(NUIT, 0.60), true)
	sur.draw_rect(rect, Color(NUIT, 0.90), true)
	sur.draw_rect(rect.grow(-0.5), CADRE, false, 1.0)
	var x := rect.position.x + MARGE_MENU
	var y := rect.position.y + 40.0
	titre_dessine(sur, Vector2(x, y), titre_.to_upper(), 24, couleur_titre, 0)
	if sous_titre != "":
		var l := largeur_texte(sous_titre, 13)
		texte_dessine(sur, Vector2(rect.end.x - MARGE_MENU - l, y - 1.0), sous_titre, 13, ENCRE_DOUCE, 0)
	filet_dessine(sur, Vector2(x, y + 12.0), rect.size.x - 2.0 * MARGE_MENU)
	return rect

const MARGE_MENU := 26.0

static func haut_contenu(rect: Rect2) -> float:
	return rect.position.y + 78.0

## La ligne d'aide d'un menu, centrée en bas du cartouche.
static func aide_menu(sur: CanvasItem, rect: Rect2, texte_: String) -> void:
	var l := largeur_capitales(texte_, 11, 0.14)
	capitales_dessinees(sur, Vector2(rect.position.x + (rect.size.x - l) * 0.5, rect.end.y - 16.0),
		texte_, 11, ENCRE_FAIBLE, 0.14)

## LE MENU AU DOIGT. Les menus se lisent aux flèches et à ENTRÉE ; sur un
## téléphone il n'y a ni l'une ni l'autre. Un doigt sur une ligne la VISE, un
## second doigt sur la ligne visée la VALIDE (deux gestes : un achat ou
## « quitter la ville » ne partent pas sur un frôlement), et un doigt hors du
## cartouche, c'est ÉCHAP. On ne réécrit pas les menus : on leur fait croire
## à la touche (`Commandes.appuyer`), et l'écran de jeu lit le front comme
## d'habitude. Renvoie le nouvel indice visé, ou `choix` inchangé.
##
## `y0` est la ligne de base de la première ligne, `pas` sa hauteur, et le
## rectangle d'une ligne est celui de `ligne_visee` (20 px au-dessus de la
## base) — le doigt vise ce que l'œil voit.
static func menu_touche(souris: Vector2, rect: Rect2, y0: float, n: int, pas: float, choix: int) -> int:
	if not rect.has_point(souris):
		Commandes.appuyer(KEY_ESCAPE)
		return choix
	for i in n:
		var ligne := Rect2(Vector2(rect.position.x + 10.0, y0 + float(i) * pas - 20.0),
			Vector2(rect.size.x - 20.0, pas - 4.0))
		if ligne.has_point(souris):
			if i == choix:
				Commandes.appuyer(KEY_ENTER)
			return i
	return choix
