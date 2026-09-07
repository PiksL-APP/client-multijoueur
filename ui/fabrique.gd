class_name UI
extends RefCounted
## Fabrique de contrôles. Tout l'habillage passe par ici : c'est le seul moyen
## de garder la même typographie et les mêmes filets d'un écran à l'autre quand
## l'interface est construite en code plutôt qu'en scènes.
##
## La charte est celle d'une borne d'arcade : angles droits, bordures de deux
## pixels, fonds sombres translucides posés sur le jeu, et une barre d'accent
## sur le bord gauche des panneaux. Les coins arrondis de la première version
## juraient avec les polices pixel — un rectangle doux sous une lettre crénelée,
## ça se voit tout de suite. La même grammaire sert à l'accueil, au village, au
## salon, aux jeux et aux résultats : le joueur ne doit jamais se demander s'il
## a changé de logiciel.
##
## Deux polices pixel (OFL, dans `polices/`) : Pixelify Sans pour le texte,
## dessinée sur une grille de ONZE pixels par cadratin — elle n'est nette
## qu'à 11, 22, 33 ; Press Start 2P pour les titres et les inscriptions dans
## le décor, grille de HUIT — nette à 8, 16, 24, 32. Toute taille demandée
## est ramenée au multiple le plus proche : une police pixel à une taille
## intermédiaire, c'est une police floue.

const TEXTE_POLICE := preload("res://polices/PixelifySans.ttf")
const TITRE_POLICE := preload("res://polices/PressStart2P.ttf")

const BORDURE := 2                       ## épaisseur des cadres, en pixels
const ACCENT := 4                        ## barre d'accent à gauche des panneaux
const VOILE := Color("#0d0d0d", 0.78)    ## fond d'un cartouche posé sur le jeu
const CADRE := Color(1, 1, 1, 0.22)      ## bordure des cartouches
const CADRE_FORT := Color(1, 1, 1, 0.45)

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

## Un en-tête d'écran : le titre en capitales pixel, un sous-titre en dessous,
## et une barre d'accent qui court sous les deux. C'est la même tête sur
## l'accueil, le salon et les résultats — on reconnaît la maison au premier
## coup d'œil.
static func entete(principal: String, secondaire: String = "", accent: Color = Palette.SERIE) -> VBoxContainer:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 6)
	colonne.add_child(titre(principal.to_upper(), 24))
	if secondaire != "":
		colonne.add_child(texte(secondaire, 15, Palette.ENCRE_DOUCE, true))
	var barre := ColorRect.new()
	barre.color = accent
	barre.custom_minimum_size = Vector2(0, 3)
	colonne.add_child(barre)
	return colonne

static func _boite(fond_couleur: Color, bordure: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond_couleur
	style.border_color = bordure
	style.set_border_width_all(BORDURE)
	style.set_corner_radius_all(0)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func bouton(libelle: String, principal: bool = false) -> Button:
	var b := Button.new()
	b.text = libelle.to_upper() if principal else libelle
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", TITRE_POLICE if principal else TEXTE_POLICE)
	b.add_theme_font_size_override("font_size", 16 if principal else 22)
	var teinte := Palette.SERIE if principal else Palette.SURFACE
	var encre := Palette.FOND if principal else Palette.ENCRE
	b.add_theme_stylebox_override("normal", _boite(teinte, CADRE if not principal else teinte.lightened(0.25)))
	b.add_theme_stylebox_override("hover", _boite(teinte.lightened(0.12), CADRE_FORT))
	b.add_theme_stylebox_override("pressed", _boite(teinte.darkened(0.2), Palette.ENCRE))
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
	c.add_theme_color_override("caret_color", Palette.SERIE)
	c.add_theme_stylebox_override("normal", _boite(Palette.FOND, CADRE))
	c.add_theme_stylebox_override("focus", _boite(Palette.FOND, Palette.SERIE))
	return c

## Le panneau : surface sombre, cadre de deux pixels, barre d'accent à gauche.
## `accent` sans alpha retire la barre — pour un panneau secondaire (dialogue
## du village) qui ne doit pas rivaliser avec le principal.
static func panneau(accent: Color = Palette.SERIE) -> PanelContainer:
	var p := PanelContainer.new()
	var style := _boite(Palette.SURFACE, CADRE)
	style.content_margin_left = 24 + (ACCENT if accent.a > 0.0 else 0)
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", style)
	if accent.a > 0.0:
		# Un StyleBoxFlat n'a qu'une couleur de bordure : la barre d'accent est
		# donc un enfant qui se dessine hors de son propre rectangle, sur le
		# bord gauche du panneau. Les enfants d'un PanelContainer se superposent
		# tous dans la zone de contenu, celui-ci ne gêne donc pas la mise en page.
		var barre := Control.new()
		barre.name = "Accent"
		barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barre.draw.connect(func():
			barre.draw_rect(Rect2(Vector2(-style.content_margin_left + BORDURE, -style.content_margin_top + BORDURE),
				Vector2(ACCENT, barre.size.y + style.content_margin_top + style.content_margin_bottom - 2 * BORDURE)), accent, true))
		p.add_child(barre)
	return p

## Une touche du clavier et ce qu'elle fait : « [E] monter ». Les aides
## écrites en phrase (« appuyez sur E pour… ») se lisent mal en jouant ; la
## touche dessinée comme un cabochon se repère du coin de l'œil.
static func touche(cle: String, action: String) -> HBoxContainer:
	var boite := HBoxContainer.new()
	boite.add_theme_constant_override("separation", 6)
	var cabochon := Label.new()
	cabochon.text = cle
	cabochon.add_theme_font_override("font", TITRE_POLICE)
	cabochon.add_theme_font_size_override("font_size", 8)
	cabochon.add_theme_color_override("font_color", Palette.FOND)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.ENCRE_DOUCE
	style.set_corner_radius_all(0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	cabochon.add_theme_stylebox_override("normal", style)
	cabochon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boite.add_child(cabochon)
	boite.add_child(texte(action, 13, Palette.ENCRE_DOUCE))
	return boite

## Une rangée de touches, retour à la ligne automatique : c'est l'aide d'un
## écran entier en une fois — `[["Z Q S D", "se déplacer"], ["E", "entrer"]]`.
static func touches(liste: Array) -> HFlowContainer:
	var rangee := HFlowContainer.new()
	rangee.add_theme_constant_override("h_separation", 18)
	rangee.add_theme_constant_override("v_separation", 8)
	for paire in liste:
		rangee.add_child(touche(String(paire[0]), String(paire[1])))
	return rangee

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
	style.set_corner_radius_all(0)
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
		style.set_corner_radius_all(0)
		pastille.add_theme_stylebox_override("panel", style)
	var etiquette := boite.get_node_or_null("Libelle") as Label
	if etiquette:
		etiquette.text = Reseau.libelle_etat()
		etiquette.add_theme_color_override("font_color", couleur)

# ------------------------------------------------------- dessin direct
# Les cartouches du jeu (HUD, radar, manche tactile) se peignent dans `_draw`
# plutôt qu'en contrôles : trente rectangles à repositionner chaque image,
# c'est un `_draw`, pas un arbre de nœuds. Ces fonctions donnent aux dessins
# la même main qu'aux panneaux.

## Le cartouche : fond translucide, cadre, barre d'accent à gauche.
static func cartouche(sur: CanvasItem, rect: Rect2, accent: Color = Color(0, 0, 0, 0), voile: Color = VOILE) -> void:
	sur.draw_rect(rect, voile, true)
	sur.draw_rect(rect.grow(-BORDURE * 0.5), CADRE, false, BORDURE)
	if accent.a > 0.0:
		sur.draw_rect(Rect2(rect.position, Vector2(ACCENT, rect.size.y)), accent, true)

## Une jauge : le libellé à gauche, la barre à droite, la valeur en chiffres
## dans la barre. La barre vire au rouge sous un quart : une jauge qu'on ne
## lit pas est une jauge qui ne sert à rien.
static func jauge(sur: CanvasItem, rect: Rect2, libelle: String, part: float, couleur: Color, valeur: String = "") -> void:
	var police_texte := TEXTE_POLICE
	var largeur_libelle := 46.0
	sur.draw_string(police_texte, Vector2(rect.position.x, rect.end.y - 4.0), libelle,
		HORIZONTAL_ALIGNMENT_LEFT, largeur_libelle, 11, Palette.ENCRE_DOUCE)
	var barre := Rect2(rect.position + Vector2(largeur_libelle, 0.0), Vector2(rect.size.x - largeur_libelle, rect.size.y))
	sur.draw_rect(barre, Color(0, 0, 0, 0.55), true)
	var p := clampf(part, 0.0, 1.0)
	var teinte := couleur if p > 0.25 else Palette.CRITIQUE
	if p > 0.0:
		sur.draw_rect(Rect2(barre.position + Vector2(BORDURE, BORDURE),
			Vector2(maxf(1.0, (barre.size.x - 2 * BORDURE) * p), barre.size.y - 2 * BORDURE)), teinte, true)
	sur.draw_rect(barre.grow(-BORDURE * 0.5), CADRE, false, BORDURE)
	if valeur != "":
		var largeur := police_texte.get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		sur.draw_string(police_texte, Vector2(barre.end.x - largeur - 6.0, rect.end.y - 4.0), valeur,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE)

## Un cabochon de touche dessiné : le pendant de `touche()` pour les `_draw`.
## Renvoie la largeur occupée, pour enchaîner les touches sur une ligne.
static func cabochon(sur: CanvasItem, ou: Vector2, cle: String, action: String) -> float:
	var largeur_cle := TITRE_POLICE.get_string_size(cle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var boite := Rect2(ou, Vector2(largeur_cle + 12.0, 18.0))
	sur.draw_rect(boite, Palette.ENCRE_DOUCE, true)
	sur.draw_string(TITRE_POLICE, ou + Vector2(6.0, 13.0), cle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.FOND)
	sur.draw_string(TEXTE_POLICE, ou + Vector2(boite.size.x + 6.0, 14.0), action,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_DOUCE)
	return boite.size.x + 6.0 + TEXTE_POLICE.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 18.0

## Une étoile à cinq branches, pleine : celles de la recherche. Le caractère
## « ★ » n'existe pas dans les polices pixel, il tombe sur la police de secours
## et n'a ni la même taille ni le même trait — mieux vaut la dessiner.
static func etoile(sur: CanvasItem, centre: Vector2, rayon: float, couleur: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := rayon if i % 2 == 0 else rayon * 0.45
		var angle := -PI * 0.5 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	sur.draw_colored_polygon(points, couleur)

## Une ligne de titre pixel centrée, avec son ombre portée d'un pixel : c'est
## ce qui la garde lisible sur un ciel clair comme sur une rue noire.
static func inscription(sur: CanvasItem, centre: Vector2, texte_: String, taille: int, couleur: Color) -> void:
	var t := taille_titre(taille)
	var largeur := TITRE_POLICE.get_string_size(texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
	var ou := centre + Vector2(-largeur * 0.5, t * 0.4)
	# L'ombre suit la grille de la police : deux pixels sous un corps de huit,
	# c'est une lettre dédoublée, pas une ombre.
	var decalage := maxf(1.0, floor(t / 16.0))
	sur.draw_string(TITRE_POLICE, ou + Vector2(decalage, decalage), texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, t, Color(0, 0, 0, 0.7 * couleur.a))
	sur.draw_string(TITRE_POLICE, ou, texte_, HORIZONTAL_ALIGNMENT_LEFT, -1, t, couleur)
