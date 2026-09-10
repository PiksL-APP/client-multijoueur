class_name Atelier
extends RefCounted
## L'HABILLAGE DE L'ÉDITEUR — ET DE LUI SEUL.
##
## ⚠ POURQUOI IL NE SUIT PAS LA CHARTE DE `UI`. Tout le reste du projet porte
## celle d'une borne d'arcade : polices pixel, angles droits, gros corps, fonds
## translucides. C'est juste pour un ÉCRAN DE JEU et faux pour un OUTIL. Un
## éditeur de carte se regarde des heures d'affilée, montre cent réglages à la
## fois, et le client l'a tranché : « l'interface doit ressembler à du Blender
## et non à un truc bricolé à la main ». Il lui faut donc une police de système
## à douze pixels, des rangées serrées, des gris neutres et UN accent.
##
## Ce fichier est cette exception — écrite une fois, nommée, et bornée à
## `scenes/editeur.gd`. Le jour où un deuxième écran-outil arrive, il tape ici ;
## le jeu, lui, ne connaît que `UI`.
##
## Les gris sont ceux de Blender 4 (relevés sur son thème sombre par défaut) :
## on ne cherche pas à l'imiter par coquetterie, on cherche à ce qu'un habitué
## sache où cliquer sans lire.

const FOND := Color("#1d1d1d")           ## le fond d'une zone
const PANNEAU := Color("#303030")        ## une boîte de réglages
const ENTETE := Color("#282828")         ## la barre d'un panneau, une en-tête de liste
const CHAMP := Color("#545454")          ## un widget au repos
const CHAMP_SURVOL := Color("#656565")
const CHAMP_ENFONCE := Color("#3d3d3d")
const ACCENT := Color("#4772b3")         ## la sélection, l'état actif
const ACCENT_VIF := Color("#5680c2")
const ENCRE := Color("#e5e5e5")
const ENCRE_DOUCE := Color("#a8a8a8")
const ENCRE_FAIBLE := Color("#7c7c7c")
const FILET := Color("#1a1a1a")
const ROUGE := Color("#d2544f")
const VERT := Color("#5fa855")
const ORANGE := Color("#e0a63c")

## ⚠ QUATRE PIXELS D'ARRONDI, PAS ZÉRO ET PAS HUIT. C'est la valeur de Blender ;
## à zéro l'interface redevient la borne d'arcade, à huit elle devient un site
## web. La différence se voit sur une rangée de six boutons.
const RAYON := 4
const CORPS := 12                        ## la taille de lecture d'un outil
const CORPS_PETIT := 11

## La police est celle du SYSTÈME (celle du moteur, en fait) : aucune ressource
## à embarquer, et surtout aucune police pixel — c'est elle qui faisait « truc
## bricolé ». Une police pixel est belle sur un titre de jeu et illisible sur
## trente libellés de réglages.
static func police() -> Font:
	return ThemeDB.fallback_font

static func texte(contenu: String, taille: int = CORPS,
		couleur: Color = ENCRE_DOUCE, retour_ligne: bool = false) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_override("font", police())
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if retour_ligne:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func boite(fond: Color, bordure: Color = Color(0, 0, 0, 0),
		rayon: int = RAYON, marge: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	if bordure.a > 0.0:
		s.border_color = bordure
		s.set_border_width_all(1)
	s.set_corner_radius_all(rayon)
	s.content_margin_left = marge
	s.content_margin_right = marge
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

## Un bouton d'outil. `actif` le peint à l'accent — c'est le seul état que
## Blender montre par la couleur, tout le reste est du gris.
static func bouton(libelle: String, actif := false) -> Button:
	var b := Button.new()
	b.text = libelle
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 22)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", police())
	b.add_theme_font_size_override("font_size", CORPS)
	peindre(b, actif)
	return b

static func peindre(b: Button, actif: bool) -> void:
	var fond := ACCENT if actif else CHAMP
	b.add_theme_stylebox_override("normal", boite(fond))
	b.add_theme_stylebox_override("hover", boite(ACCENT_VIF if actif else CHAMP_SURVOL))
	b.add_theme_stylebox_override("pressed", boite(ACCENT_VIF if actif else CHAMP_ENFONCE))
	b.add_theme_stylebox_override("disabled", boite(CHAMP_ENFONCE))
	for cle in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(cle, ENCRE)
	b.add_theme_color_override("font_disabled_color", ENCRE_FAIBLE)

## Le panneau de fond de la colonne : pas de bordure, pas d'accent, juste un
## gris qui recule. Les cadres de deux pixels de la charte de jeu font, alignés
## par dix, une grille de tableur.
static func panneau(fond: Color = PANNEAU) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", boite(fond, Color(0, 0, 0, 0), RAYON, 10))
	return p

## L'EN-TÊTE REPLIABLE de Blender : un triangle, un titre, toute la barre est
## cliquable. C'est le seul moyen de tenir dix sections dans une colonne sans la
## faire défiler — et de laisser à celui qui édite le choix de ce qu'il voit.
static func entete(titre: String) -> Button:
	var b := Button.new()
	b.text = "  ▾  " + titre
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", police())
	b.add_theme_font_size_override("font_size", CORPS)
	for etat in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(etat,
			boite(ENTETE if etat == "normal" else CHAMP_ENFONCE, Color(0, 0, 0, 0), RAYON, 4))
	for cle in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(cle, ENCRE)
	return b

static func plier(b: Button, titre: String, ouvert: bool) -> void:
	b.text = ("  ▾  " if ouvert else "  ▸  ") + titre

## Un champ de saisie, à la mode de l'outil : fond enfoncé, pas de bordure.
static func champ(indication: String = "") -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = indication
	c.custom_minimum_size = Vector2(0, 22)
	c.add_theme_font_override("font", police())
	c.add_theme_font_size_override("font_size", CORPS)
	c.add_theme_color_override("font_color", ENCRE)
	c.add_theme_color_override("font_placeholder_color", ENCRE_FAIBLE)
	c.add_theme_color_override("caret_color", ENCRE)
	c.add_theme_stylebox_override("normal", boite(CHAMP_ENFONCE))
	c.add_theme_stylebox_override("focus", boite(CHAMP_ENFONCE, ACCENT))
	return c

## Une LISTE, pas trente boutons. Deux cents modèles ne se posent pas en
## boutons : il faut une liste qui défile, qui se cherche et qui garde une
## sélection — c'est exactement ce que l'`ItemList` du moteur sait faire, et
## c'est le widget que Blender emploie pour ses navigateurs.
static func liste() -> ItemList:
	var l := ItemList.new()
	l.add_theme_font_override("font", police())
	l.add_theme_font_size_override("font_size", CORPS)
	l.add_theme_color_override("font_color", ENCRE_DOUCE)
	l.add_theme_color_override("font_selected_color", ENCRE)
	l.add_theme_stylebox_override("panel", boite(FOND, Color(0, 0, 0, 0), RAYON, 4))
	var sel := boite(ACCENT, Color(0, 0, 0, 0), 2, 2)
	l.add_theme_stylebox_override("selected", sel)
	l.add_theme_stylebox_override("selected_focus", sel)
	l.add_theme_constant_override("v_separation", 2)
	l.focus_mode = Control.FOCUS_NONE
	return l

## Une glissière à la Blender : la valeur écrite DANS la barre, pas à côté.
static func glissiere(mini_v: float, maxi_v: float, pas: float, valeur: float) -> HSlider:
	var g := HSlider.new()
	g.min_value = mini_v
	g.max_value = maxi_v
	g.step = pas
	g.value = valeur
	g.custom_minimum_size = Vector2(0, 20)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.focus_mode = Control.FOCUS_NONE
	var fond := boite(CHAMP_ENFONCE, Color(0, 0, 0, 0), RAYON, 0)
	fond.content_margin_top = 0
	fond.content_margin_bottom = 0
	g.add_theme_stylebox_override("slider", fond)
	var prise := StyleBoxFlat.new()
	prise.bg_color = ACCENT
	prise.set_corner_radius_all(RAYON)
	g.add_theme_stylebox_override("grabber_area", prise)
	g.add_theme_stylebox_override("grabber_area_highlight", prise)
	return g
