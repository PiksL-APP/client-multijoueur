class_name UI
extends RefCounted
## Fabrique de contrôles. Tout l'habillage passe par ici : c'est le seul moyen
## de garder la même typographie et les mêmes filets d'un écran à l'autre quand
## l'interface est construite en code plutôt qu'en scènes.
##
## Deux polices pixel (OFL, dans `polices/`) : Pixelify Sans pour le texte,
## dessinée sur une grille de ONZE pixels par cadratin — elle n'est nette
## qu'à 11, 22, 33 ; Press Start 2P pour les titres et les inscriptions dans
## le décor, grille de HUIT — nette à 8, 16, 24, 32. Toute taille demandée
## est ramenée au multiple le plus proche : une police pixel à une taille
## intermédiaire, c'est une police floue.

const TEXTE_POLICE := preload("res://polices/PixelifySans.ttf")
const TITRE_POLICE := preload("res://polices/PressStart2P.ttf")

static func taille_texte(demandee: int) -> int:
	# 22 est la taille de lecture ; 11 ne sert qu'aux mentions (version).
	if demandee <= 12:
		return 11
	if demandee <= 27:
		return 22
	return int(round(demandee / 11.0)) * 11

static func taille_titre(demandee: int) -> int:
	return maxi(8, int(round(demandee / 8.0)) * 8)

static func fond(parent: Node) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Palette.FOND
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

static func titre(texte: String, taille: int = 32) -> Label:
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_override("font", TITRE_POLICE)
	etiquette.add_theme_font_size_override("font_size", taille_titre(taille))
	etiquette.add_theme_color_override("font_color", Palette.ENCRE)
	return etiquette

## `retour_ligne` est explicite et non pas par défaut : une étiquette qui
## se replie a une largeur minimale d'un caractère, et dans une boîte
## horizontale elle s'affiche alors verticalement, un caractère par ligne.
## Le défaut s'est vu sur l'écran d'accueil, pas au build.
static func texte(contenu: String, taille: int = 22, couleur: Color = Palette.ENCRE_DOUCE, retour_ligne: bool = false) -> Label:
	var etiquette := Label.new()
	etiquette.text = contenu
	etiquette.add_theme_font_override("font", TEXTE_POLICE)
	etiquette.add_theme_font_size_override("font_size", taille_texte(taille))
	etiquette.add_theme_color_override("font_color", couleur)
	if retour_ligne:
		etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return etiquette

static func _boite(fond_couleur: Color, bordure: Color, rayon: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond_couleur
	style.border_color = bordure
	style.set_border_width_all(1)
	style.set_corner_radius_all(rayon)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func bouton(libelle: String, principal: bool = false) -> Button:
	var b := Button.new()
	b.text = libelle
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", TEXTE_POLICE)
	b.add_theme_font_size_override("font_size", 22)
	var teinte := Palette.SERIE if principal else Palette.SURFACE
	var encre := Palette.FOND if principal else Palette.ENCRE
	b.add_theme_stylebox_override("normal", _boite(teinte, Palette.FILET if not principal else teinte))
	b.add_theme_stylebox_override("hover", _boite(teinte.lightened(0.12), Color(1, 1, 1, 0.25)))
	b.add_theme_stylebox_override("pressed", _boite(teinte.darkened(0.15), Color(1, 1, 1, 0.3)))
	b.add_theme_stylebox_override("disabled", _boite(Palette.SURFACE, Palette.FILET))
	b.add_theme_color_override("font_color", encre)
	b.add_theme_color_override("font_hover_color", encre)
	b.add_theme_color_override("font_pressed_color", encre)
	b.add_theme_color_override("font_disabled_color", Palette.ENCRE_FAIBLE)
	return b

static func champ(indication: String, valeur: String = "") -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = indication
	c.text = valeur
	c.custom_minimum_size = Vector2(320, 44)
	c.add_theme_font_override("font", TEXTE_POLICE)
	c.add_theme_font_size_override("font_size", 22)
	c.add_theme_color_override("font_color", Palette.ENCRE)
	c.add_theme_color_override("font_placeholder_color", Palette.ENCRE_FAIBLE)
	c.add_theme_stylebox_override("normal", _boite(Palette.SURFACE, Palette.FILET))
	c.add_theme_stylebox_override("focus", _boite(Palette.SURFACE, Palette.SERIE))
	return c

static func panneau() -> PanelContainer:
	var p := PanelContainer.new()
	var style := _boite(Palette.SURFACE, Palette.FILET, 10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", style)
	return p

## Pastille + libellé : la couleur ne porte jamais seule le sens.
static func etat_reseau() -> HBoxContainer:
	var boite := HBoxContainer.new()
	boite.add_theme_constant_override("separation", 8)
	boite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pastille := Panel.new()
	pastille.custom_minimum_size = Vector2(10, 10)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastille.name = "Pastille"
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.ENCRE_FAIBLE
	style.set_corner_radius_all(5)
	pastille.add_theme_stylebox_override("panel", style)
	var etiquette := texte("hors ligne", 13, Palette.ENCRE_FAIBLE)
	etiquette.name = "Libelle"
	boite.add_child(pastille)
	boite.add_child(etiquette)
	return boite

static func rafraichir_etat_reseau(boite: HBoxContainer) -> void:
	var couleur := Palette.ENCRE_FAIBLE
	match Reseau.etat:
		Reseau.EN_LIGNE: couleur = Palette.BON
		Reseau.CONNEXION: couleur = Palette.AVERTISSEMENT
		_: couleur = Palette.CRITIQUE
	var pastille := boite.get_node_or_null("Pastille") as Panel
	if pastille:
		var style := StyleBoxFlat.new()
		style.bg_color = couleur
		style.set_corner_radius_all(5)
		pastille.add_theme_stylebox_override("panel", style)
	var etiquette := boite.get_node_or_null("Libelle") as Label
	if etiquette:
		etiquette.text = Reseau.libelle_etat()
		etiquette.add_theme_color_override("font_color", couleur)
