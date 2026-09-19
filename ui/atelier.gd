class_name Atelier
extends RefCounted
## L'HABILLAGE DE L'ÉDITEUR DE CARTE — ET DE LUI SEUL.
##
## ⚠ POURQUOI IL NE SUIT PAS LA CHARTE DE `UI`. Le jeu porte celle d'une borne
## d'arcade : polices pixel, angles droits, gros corps. C'est juste pour un
## ÉCRAN DE JEU et faux pour un OUTIL qu'on regarde des heures et qui montre
## cent réglages à la fois. Le client l'a tranché deux fois : « du Blender, pas
## un truc bricolé » (12/09), puis « un éditeur moderne » (19/09) — sombre et
## neutre comme un outil pro, avec l'accent néon du hub pour qu'il reste de la
## même famille que le site, et épuré : pas de cadres autour de tout.
##
## Ce fichier est cette exception — écrite une fois, nommée, et bornée à
## `scenes/editeur.gd`. Le jeu, lui, ne connaît que `UI`.
##
## LES TROIS PLANS. Le fond recule, les panneaux sont posés dessus, les champs
## et les tuiles sont posés sur les panneaux : trois gris, du plus sombre au
## plus clair, et RIEN d'autre pour dire « ceci est au-dessus de cela » — pas
## de bordure, pas d'ombre. Un seul filet, à peine visible, sépare deux
## panneaux qui se touchent.

const FOND := Color("#0e1014")           ## derrière tout (la vue 3D porte sa propre couleur)
const PANNEAU := Color("#171a20")        ## un dock, une barre
const SURFACE := Color("#1f232b")        ## un champ, une tuile, un bouton au repos
const SURVOL := Color("#2a2f3a")         ## le même, sous la souris
const ENFONCE := Color("#141719")
const FILET := Color("#262b35")          ## la seule ligne qu'on s'autorise
const ENCRE := Color("#e9ebf1")
const ENCRE_DOUCE := Color("#9ea5b4")
const ENCRE_FAIBLE := Color("#5f6776")
## L'ACCENT EST CELUI DU HUB : le rose de `#pk-panne`, des portails et des
## titres. C'est ce qui fait que l'éditeur et le site se reconnaissent.
const ACCENT := Color("#ff2ea6")
const ACCENT_DOUX := Color("#ff2ea6", 0.18)
## Le cyan reste pour ce qui est VALIDE (une pose possible, une case
## sélectionnée dans la ville) : le rose dit « actif », le cyan dit « ok ».
const CYAN := Color("#2fe0d0")
const OK := Color("#3ddc97")
const ALERTE := Color("#ffb648")
const ERREUR := Color("#ff4d6d")

## ⚠ SIX PIXELS D'ARRONDI. À zéro, l'interface redevient la borne d'arcade ; à
## douze elle devient un site web de 2020. Six, c'est ce que font les outils
## modernes (Figma, Linear, Blender 4) et ça se voit sur une rangée de boutons.
const RAYON := 6
const CORPS := 15
const CORPS_PETIT := 12
const CORPS_TITRE := 20

## Les polices du menu du jeu (`ui/charte.gd`) : la condensée demi-grasse pour
## le courant, la grasse pour les titres, l'Archivo pour le logo. Pas de
## police pixel — c'est elle qui faisait « bricolé ».
const POLICE := preload("res://polices/BarlowCondensed-SemiBold.ttf")
const POLICE_GRASSE := preload("res://polices/BarlowCondensed-Bold.ttf")
const POLICE_LOGO := preload("res://polices/ArchivoBlack.ttf")

static func boite(fond: Color, rayon: int = RAYON, marge_x: int = 8, marge_y: int = 4,
		bordure: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(rayon)
	s.content_margin_left = marge_x
	s.content_margin_right = marge_x
	s.content_margin_top = marge_y
	s.content_margin_bottom = marge_y
	if bordure.a > 0.0:
		s.border_color = bordure
		s.set_border_width_all(1)
	return s

static func vide() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

## LE THÈME ENTIER, posé une fois sur la racine : il descend sur tout l'arbre.
## Une seule ligne habille les boutons, les listes, les champs, les onglets,
## les curseurs et les info-bulles — et personne n'a plus à retoucher un
## contrôle un par un.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = POLICE
	t.default_font_size = CORPS

	# Les boutons : plats, sans bordure ; le survol éclaircit, l'état enfoncé
	# (un outil actif, un onglet choisi) se teinte à l'accent.
	for classe in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		t.set_stylebox("normal", classe, boite(SURFACE))
		t.set_stylebox("hover", classe, boite(SURVOL))
		t.set_stylebox("pressed", classe, boite(ACCENT_DOUX, RAYON, 8, 4, Color(ACCENT, 0.6)))
		t.set_stylebox("hover_pressed", classe, boite(ACCENT_DOUX, RAYON, 8, 4, Color(ACCENT, 0.8)))
		t.set_stylebox("disabled", classe, boite(Color(SURFACE, 0.5)))
		t.set_stylebox("focus", classe, vide())
		t.set_color("font_color", classe, ENCRE)
		t.set_color("font_hover_color", classe, Color.WHITE)
		t.set_color("font_pressed_color", classe, Color.WHITE)
		t.set_color("font_hover_pressed_color", classe, Color.WHITE)
		t.set_color("font_disabled_color", classe, ENCRE_FAIBLE)
		t.set_color("font_focus_color", classe, ENCRE)
	# La case à cocher n'est pas un bouton : pas de fond, sinon on ne sait plus
	# si elle est cochée ou enfoncée.
	for etat in ["normal", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(etat, "CheckBox", boite(Color(0, 0, 0, 0), RAYON, 2, 2))
	t.set_color("font_pressed_color", "CheckBox", ENCRE)
	t.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)

	# Les champs : un fond enfoncé, pas de bordure, le curseur à l'accent.
	for classe in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", classe, boite(ENFONCE, RAYON, 8, 4))
		t.set_stylebox("focus", classe, boite(ENFONCE, RAYON, 8, 4, Color(ACCENT, 0.7)))
		t.set_stylebox("read_only", classe, boite(ENFONCE, RAYON, 8, 4))
		t.set_color("font_color", classe, ENCRE)
		t.set_color("font_placeholder_color", classe, ENCRE_FAIBLE)
		t.set_color("caret_color", classe, ACCENT)
		t.set_color("selection_color", classe, ACCENT_DOUX)
	t.set_color("font_uneditable_color", "LineEdit", ENCRE_DOUCE)

	# Les listes et le catalogue : fond enfoncé, tuile choisie à l'accent.
	t.set_stylebox("panel", "ItemList", boite(ENFONCE, RAYON, 4, 4))
	t.set_stylebox("focus", "ItemList", vide())
	t.set_stylebox("selected", "ItemList", boite(ACCENT_DOUX, RAYON, 2, 2, Color(ACCENT, 0.8)))
	t.set_stylebox("selected_focus", "ItemList", boite(ACCENT_DOUX, RAYON, 2, 2, Color(ACCENT, 0.8)))
	t.set_stylebox("hovered", "ItemList", boite(SURVOL, RAYON, 2, 2))
	t.set_stylebox("cursor", "ItemList", vide())
	t.set_stylebox("cursor_unfocused", "ItemList", vide())
	t.set_color("font_color", "ItemList", ENCRE_DOUCE)
	t.set_color("font_hovered_color", "ItemList", ENCRE)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("guide_color", "ItemList", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "ItemList", 4)
	t.set_constant("h_separation", "ItemList", 4)
	t.set_constant("icon_margin", "ItemList", 4)

	# Le menu déroulant d'un OptionButton.
	t.set_stylebox("panel", "PopupMenu", boite(SURVOL, RAYON, 6, 6, FILET))
	t.set_stylebox("hover", "PopupMenu", boite(ACCENT_DOUX, RAYON - 2, 6, 2))
	t.set_stylebox("separator", "PopupMenu", boite(FILET, 0, 0, 0))
	t.set_color("font_color", "PopupMenu", ENCRE)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", ENCRE_FAIBLE)
	t.set_constant("v_separation", "PopupMenu", 4)

	# Les onglets (Catalogue / Sélection) : un trait d'accent sous l'onglet
	# ouvert, rien d'autre.
	var onglet_ouvert := boite(PANNEAU, 0, 12, 6)
	onglet_ouvert.border_color = ACCENT
	onglet_ouvert.border_width_bottom = 2
	var onglet_ferme := boite(Color(0, 0, 0, 0), 0, 12, 6)
	onglet_ferme.border_color = FILET
	onglet_ferme.border_width_bottom = 1
	t.set_stylebox("tab_selected", "TabContainer", onglet_ouvert)
	t.set_stylebox("tab_unselected", "TabContainer", onglet_ferme)
	t.set_stylebox("tab_hovered", "TabContainer", onglet_ferme)
	t.set_stylebox("tab_focus", "TabContainer", vide())
	t.set_stylebox("panel", "TabContainer", boite(Color(0, 0, 0, 0), 0, 0, 6))
	t.set_stylebox("tabbar_background", "TabContainer", vide())
	t.set_color("font_selected_color", "TabContainer", ENCRE)
	t.set_color("font_unselected_color", "TabContainer", ENCRE_FAIBLE)
	t.set_color("font_hovered_color", "TabContainer", ENCRE_DOUCE)
	t.set_font("font", "TabContainer", POLICE_GRASSE)
	t.set_font_size("font_size", "TabContainer", CORPS_PETIT + 1)

	# Les info-bulles : sombres, arrondies, lisibles.
	t.set_stylebox("panel", "TooltipPanel", boite(Color("#0b0d11", 0.96), RAYON, 10, 6, FILET))
	t.set_color("font_color", "TooltipLabel", ENCRE)
	t.set_font_size("font_size", "TooltipLabel", CORPS - 1)

	# Les ascenseurs : un trait fin, pas de rails.
	t.set_stylebox("scroll", "VScrollBar", boite(Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", boite(Color(ENCRE_FAIBLE, 0.5), 3, 2, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", boite(ENCRE_DOUCE, 3, 2, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", boite(ACCENT, 3, 2, 2))
	t.set_stylebox("scroll", "HScrollBar", boite(Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber", "HScrollBar", boite(Color(ENCRE_FAIBLE, 0.5), 3, 2, 2))

	t.set_stylebox("normal", "RichTextLabel", boite(Color(0, 0, 0, 0), 0, 0, 0))
	t.set_color("default_color", "RichTextLabel", ENCRE_DOUCE)
	t.set_color("font_color", "Label", ENCRE)
	t.set_stylebox("separator", "VSeparator", boite(FILET, 0, 0, 0))
	t.set_stylebox("separator", "HSeparator", boite(FILET, 0, 0, 0))
	t.set_constant("separation", "VSeparator", 12)
	return t

static func texte(contenu: String, taille: int = CORPS, couleur: Color = ENCRE,
		grasse: bool = false) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_override("font", POLICE_GRASSE if grasse else POLICE)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l

## L'entête d'une section : petites capitales espacées, en encre faible. Il
## sépare sans crier — c'est l'espace au-dessus qui fait le travail.
static func entete(titre: String) -> Label:
	var l := texte(titre.to_upper(), CORPS_PETIT, ENCRE_FAIBLE, true)
	l.add_theme_constant_override("font_spacing_glyph", 2)
	l.custom_minimum_size.y = 26
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l

## Un panneau : un fond, une marge, et LA SOURIS QUI S'ARRÊTE — c'est ce qui
## fait que la molette fait défiler la liste quand on est dessus, et zoome la
## ville quand on est sur la vue, et non les deux.
static func panneau(fond: Color = PANNEAU, marge: int = 10, rayon: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", boite(fond, rayon, marge, marge))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## Une pastille : un chiffre ou un mot dans une capsule (« 1 313 lots »).
static func pastille(contenu: String, teinte: Color = ENCRE_DOUCE) -> Label:
	var l := texte(contenu, CORPS_PETIT, teinte, true)
	l.add_theme_stylebox_override("normal", boite(SURFACE, 10, 8, 2))
	return l

## Un bouton d'action de la barre du haut : compact, avec son raccourci dans
## l'info-bulle. `principal` le peint à l'accent — un seul par barre.
static func action(libelle: String, raccourci: String = "", principal: bool = false) -> Button:
	var b := Button.new()
	b.text = libelle
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 28
	if raccourci != "":
		b.tooltip_text = "%s  ·  %s" % [libelle, raccourci]
	if principal:
		b.add_theme_stylebox_override("normal", boite(ACCENT, RAYON, 12, 4))
		b.add_theme_stylebox_override("hover", boite(ACCENT.lightened(0.12), RAYON, 12, 4))
		b.add_theme_stylebox_override("pressed", boite(ACCENT.darkened(0.15), RAYON, 12, 4))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_font_override("font", POLICE_GRASSE)
	return b

## Un petit bouton « fantôme » : pas de fond au repos, un fond au survol. Pour
## ce qui se clique rarement (replier un panneau, ouvrir l'aide).
static func fantome(libelle: String, bulle: String = "") -> Button:
	var b := Button.new()
	b.text = libelle
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = bulle
	b.add_theme_stylebox_override("normal", boite(Color(0, 0, 0, 0), RAYON, 8, 4))
	b.add_theme_stylebox_override("hover", boite(SURVOL, RAYON, 8, 4))
	b.add_theme_stylebox_override("pressed", boite(ACCENT_DOUX, RAYON, 8, 4))
	b.add_theme_color_override("font_color", ENCRE_DOUCE)
	return b

## Une ligne « étiquette — réglage — unité », comme l'inspecteur de Godot.
static func ligne(nom: String, champ: Control, unite: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := texte(nom, CORPS, ENCRE_DOUCE)
	l.custom_minimum_size.x = 64
	h.add_child(l)
	champ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(champ)
	if unite != "":
		var u := texte(unite, CORPS_PETIT, ENCRE_FAIBLE)
		h.add_child(u)
	return h

## Un séparateur horizontal d'un pixel, avec de l'air autour.
static func filet() -> Control:
	var c := ColorRect.new()
	c.color = FILET
	c.custom_minimum_size.y = 1
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 4)
	m.add_child(c)
	return m

## Un espace qui pousse ce qui suit à l'autre bout d'une rangée.
static func ressort() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Une touche dessinée en cabochon (« Ctrl », « S »), pour l'aide.
static func touche(t: String) -> Label:
	var l := texte(t, CORPS_PETIT, ENCRE, true)
	l.add_theme_stylebox_override("normal", boite(SURFACE, 4, 6, 1, FILET))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 24
	return l
