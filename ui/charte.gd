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
