class_name VoileChargement
extends CanvasLayer
## L'écran de chargement de Pikstown, tel qu'il est dessiné sur la maquette :
## une affiche plein cadre qui respire, le lettrage en haut à gauche, une
## astuce qui tourne, un compteur circulaire, et une barre biseautée qui va du
## violet au cyan.
##
## Il ne CHARGE rien lui-même : il montre où en est celui qui charge. L'écran
## qui bâtit la ville l'appelle avec `avancer(part)` à chaque morceau posé,
## puis `effacer()` — le voile se fond alors, et ce qu'il y avait derrière
## paraît. C'est pour ça qu'il vit dans sa propre couche, au-dessus de tout.

## Les neuf affiches se croisent lentement, dans l'ordre : une seule image,
## fixe, se lit comme un écran figé au bout de dix secondes.
const AFFICHES := ["res://images/chargement/1.jpg", "res://images/chargement/2.jpg",
	"res://images/chargement/3.jpg", "res://images/chargement/4.jpg",
	"res://images/chargement/5.jpg", "res://images/chargement/6.jpg",
	"res://images/chargement/7.jpg", "res://images/chargement/8.jpg",
	"res://images/chargement/9.jpg"]
const CROISEMENT := 6.0             ## secondes par affiche
const FONDU := 1.2                  ## durée du croisement

const LOGO := "res://images/logo.png"

const ROSE := Charte.ROSE
const CYAN := Charte.CYAN
const VIOLET := Charte.VIOLET
const NUIT := Charte.NUIT

## Ce qu'on lit pendant que ça charge. Ce ne sont pas des conseils de jeu :
## c'est la voix de la ville, et c'est elle qui donne le ton avant même qu'on
## y soit entré.
const ASTUCES := [
	"Ne laisse jamais ta caisse ouverte dans le quartier des docks. Pikstown n'oublie pas.",
	"Les feux rouges sont une suggestion. Les hélicos, beaucoup moins.",
	"Appuie sur le klaxon pour saluer. Ou pour prévenir.",
	"La couronne se porte sur la tête. Le carton aussi.",
	"Un braquage propre commence par un plein d'essence.",
	"No trust, just greed. C'est écrit sur les murs.",
]
const DUREE_ASTUCE := 6.0

## Les étapes annoncées en bas, par seuil d'avancement. Un chargement muet
## qui reste à 40 % passe pour une panne ; nommé, il passe pour du travail.
const ETAPES := [
	[0.0, "Connexion"], [0.18, "Chargement du monde"], [0.42, "Synchronisation"],
	[0.68, "Chargement des joueurs"], [0.88, "Presque prêt"],
]

var _part := 0.0
var _t := 0.0
var _astuce := 0
var _rang := 0                      ## l'affiche en cours
var _sortie := -1.0                 ## < 0 tant qu'on n'efface pas

var _affiche_a: TextureRect
var _affiche_b: TextureRect
var _texte_astuce: Label
var _pourcent: Label
var _etape: Label
var _barre: ColorRect
var _creux: Control
var _anneau: Control
var _racine: Control
var _balayage: TextureRect

static func poser(sur: Node) -> VoileChargement:
	var v := VoileChargement.new()
	v.layer = 3
	sur.add_child(v)
	return v

func _ready() -> void:
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_racine)

	var fond := ColorRect.new()
	fond.color = NUIT
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(fond)

	_affiche_a = _affiche(AFFICHES[0], 1.0)
	_affiche_b = _affiche(AFFICHES[1 % AFFICHES.size()], 0.0)

	# Trois voiles empilés : un dégradé du haut vers le bas qui assombrit les
	# deux bords, un vignettage, et de fines rayures horizontales. Ensemble ils
	# font l'écran cathodique de l'affiche sans qu'on ait à peindre dessus.
	_racine.add_child(_degrade_vertical())
	_racine.add_child(_vignettage())
	_racine.add_child(_rayures())
	_balayage = _bande_de_balayage()
	_racine.add_child(_balayage)

	Charte.entete_pikstown(_racine)
	_bas()

func _affiche(chemin: String, opacite: float) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(chemin)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.modulate.a = opacite
	# Un peu plus grande que le cadre : c'est ce débord qui permet de la faire
	# dériver sans découvrir de bord noir.
	image.pivot_offset = Vector2.ZERO
	_racine.add_child(image)
	return image

func _degrade_vertical() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.32, 0.62, 1.0])
	g.colors = PackedColorArray([Color(NUIT, 0.72), Color(NUIT, 0.12), Color(NUIT, 0.45), Color(NUIT, 0.94)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	return _nappe(t)

func _vignettage() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.72)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.45)
	t.fill_to = Vector2(1.1, 0.45)
	return _nappe(t)

## Les rayures : une texture de trois pixels de haut, répétée. Un shader
## coûterait une passe plein écran pour un effet qu'une image de trois pixels
## rend exactement.
func _rayures() -> TextureRect:
	var image := Image.create(1, 3, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(1, 1, 1, 0.16))
	image.set_pixel(0, 1, Color(0, 0, 0, 0))
	image.set_pixel(0, 2, Color(0, 0, 0, 0))
	var t := ImageTexture.create_from_image(image)
	var nappe := _nappe(t)
	nappe.stretch_mode = TextureRect.STRETCH_TILE
	nappe.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	nappe.modulate.a = 0.9
	return nappe

## La bande qui balaie l'écran de haut en bas toutes les sept secondes : rose
## en haut, blanche au milieu, cyan en bas, et transparente aux deux bouts.
func _bande_de_balayage() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(ROSE, 0.0), Color(1, 1, 1, 0.055), Color(CYAN, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	var n := TextureRect.new()
	n.texture = t
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode = TextureRect.STRETCH_SCALE
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

func _nappe(t: Texture2D) -> TextureRect:
	var nappe := TextureRect.new()
	nappe.texture = t
	nappe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nappe.stretch_mode = TextureRect.STRETCH_SCALE
	nappe.set_anchors_preset(Control.PRESET_FULL_RECT)
	nappe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return nappe

## Un libellé en capitales espacées, sans cerne : sur une affiche déjà
## assombrie par ses trois voiles, le contour noir empâterait les petites
## tailles au lieu de les détacher.
func _capitales(texte: String, taille: int, couleur: Color, espacement: float) -> Label:
	return Charte.capitales(texte, taille, couleur, espacement, 0)

# ── Bas de l'écran : l'astuce, le compteur, la barre ────────────────────────

func _bas() -> void:
	var bas := VBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var marge: int = Charte.serre(18, 2.6, 42)
	bas.offset_left = marge
	bas.offset_right = -marge
	bas.offset_top = -230
	bas.offset_bottom = -marge
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", Charte.serre(12, 1.5, 22))
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(bas)

	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", Charte.serre(20, 4.0, 64))
	bas.add_child(rangee)

	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", 8)
	rangee.add_child(colonne)

	var titre := HBoxContainer.new()
	titre.add_theme_constant_override("separation", 10)
	colonne.add_child(titre)
	var point := ColorRect.new()
	point.color = ROSE
	point.custom_minimum_size = Vector2(9, 9)
	point.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.add_child(point)
	titre.add_child(_capitales("Astuce Pikstown", Charte.serre(11, 1.05, 16), ROSE, 0.30))

	_texte_astuce = Label.new()
	_texte_astuce.add_theme_font_override("font", Charte.COURANTE)
	_texte_astuce.add_theme_font_size_override("font_size", Charte.serre(19, 2.2, 38))
	_texte_astuce.add_theme_color_override("font_color", Color.WHITE)
	_texte_astuce.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_texte_astuce.add_theme_constant_override("shadow_offset_y", 2)
	_texte_astuce.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte_astuce.custom_minimum_size = Vector2(0, 84)
	_texte_astuce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texte_astuce.text = ASTUCES[0]
	colonne.add_child(_texte_astuce)

	# Le compteur : un anneau qui tourne, dessiné à la main, et le nombre au
	# milieu. Une barre seule ne dit pas que ça travaille encore quand elle
	# n'avance pas ; l'anneau, si.
	_anneau = Control.new()
	var rond: int = Charte.serre(76, 7.4, 124)
	_anneau.custom_minimum_size = Vector2(rond, rond)
	_anneau.size_flags_vertical = Control.SIZE_SHRINK_END
	_anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anneau.draw.connect(_dessiner_anneau)
	rangee.add_child(_anneau)
	_pourcent = Label.new()
	_pourcent.text = "0"
	_pourcent.add_theme_font_override("font", Charte.TITRE)
	_pourcent.add_theme_font_size_override("font_size", Charte.serre(19, 1.95, 32))
	_pourcent.add_theme_color_override("font_color", Color.WHITE)
	_pourcent.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pourcent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pourcent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pourcent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anneau.add_child(_pourcent)

	# La barre, biseautée aux deux bouts comme sur la maquette : le biseau est
	# taillé par le dessin, pas par un masque — un ColorRect ne sait pas se
	# rogner en losange.
	_creux = Control.new()
	_creux.custom_minimum_size = Vector2(0, Charte.serre(10, 1.1, 16))
	_creux.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_creux.draw.connect(_dessiner_barre)
	bas.add_child(_creux)

	var pied := HBoxContainer.new()
	var pied_taille: int = Charte.serre(10, 0.95, 14)
	pied.add_theme_constant_override("separation", 16)
	bas.add_child(pied)
	pied.add_child(_capitales("Piks Theft Auto — Online Session", pied_taille, Color(1, 1, 1, 0.42), 0.24))
	var e1 := Control.new(); e1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pied.add_child(e1)
	_etape = _capitales("Connexion", pied_taille, CYAN, 0.24)
	pied.add_child(_etape)
	var e2 := Control.new(); e2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pied.add_child(e2)
	pied.add_child(_capitales("Est. 1986 · No Trust Just Greed", pied_taille, Color(1, 1, 1, 0.42), 0.24))

func _dessiner_anneau() -> void:
	var r := _anneau.size * 0.5
	var rayon := minf(r.x, r.y) - 4.0
	_anneau.draw_arc(r, rayon, 0, TAU, 64, Color(1, 1, 1, 0.14), 4.0, true)
	# Deux quarts d'arc, cyan et rose, qui tournent : c'est le cercle de
	# chargement de la maquette, sans image à charger.
	var depart := _t * 6.0
	_anneau.draw_arc(r, rayon, depart, depart + PI * 0.5, 24, CYAN, 4.0, true)
	_anneau.draw_arc(r, rayon, depart + PI * 0.5, depart + PI, 24, ROSE, 4.0, true)

func _dessiner_barre() -> void:
	var l := _creux.size.x
	var h := _creux.size.y
	var biseau := 10.0
	var creux := PackedVector2Array([Vector2(0, 0), Vector2(l - biseau, 0), Vector2(l, h), Vector2(biseau, h)])
	_creux.draw_colored_polygon(creux, Color(1, 1, 1, 0.08))
	_creux.draw_polyline(creux + PackedVector2Array([creux[0]]), Color(1, 1, 1, 0.18), 1.0)
	if _part <= 0.001:
		return
	# Le remplissage suit le même biseau, coupé à la bonne longueur, et son
	# dégradé va du violet au cyan en passant par le rose.
	var x := maxf(biseau + 1.0, l * _part)
	# Le dégradé va du violet au cyan en passant par le rose à 55 %. Quatre
	# sommets ne suffisent pas à porter trois arrêts — le rose disparaissait
	# entre les deux autres —, alors on découpe le remplissage en bandes.
	var bandes := 48
	for i in bandes:
		var g := x * float(i) / float(bandes)
		var d := x * float(i + 1) / float(bandes)
		if d <= g:
			continue
		var f: float = clampf((g + d) * 0.5 / maxf(1.0, l), 0.0, 1.0)
		var teinte: Color = VIOLET.lerp(ROSE, f / 0.55) if f < 0.55 else ROSE.lerp(CYAN, (f - 0.55) / 0.45)
		# Le creux est un parallélogramme : son bord HAUT est décalé d'un biseau
		# vers la gauche par rapport à son bord BAS. Chaque bande suit la même
		# inclinaison, sinon le remplissage déborderait du cadre au début.
		_creux.draw_colored_polygon(PackedVector2Array([
			Vector2(maxf(0.0, g - biseau), 0.0), Vector2(maxf(0.0, d - biseau), 0.0),
			Vector2(d, h), Vector2(g, h)]), teinte)
	# Les hachures verticales de la maquette, par-dessus TOUT le creux : deux
	# pixels sombres tous les huit. C'est ce qui donne à la barre son air
	# d'afficheur segmenté plutôt que de dégradé lisse.
	var x2 := 0.0
	while x2 < l:
		_creux.draw_rect(Rect2(x2, 0, 2, h), Color(0, 0, 0, 0.35))
		x2 += 8.0

# ── Ce que l'écran qui charge appelle ───────────────────────────────────────

## `part` va de 0 à 1. L'étape affichée s'en déduit — l'appelant n'a pas à
## savoir comment on nomme les seuils.
func avancer(part: float) -> void:
	_part = clampf(part, 0.0, 1.0)
	if _pourcent != null:
		_pourcent.text = "%d" % roundi(_part * 100.0)
	if _etape != null:
		for seuil in ETAPES:
			if _part >= float(seuil[0]):
				_etape.text = String(seuil[1]).to_upper()
	if _creux != null:
		_creux.queue_redraw()

## Le voile se retire. Il se libère tout seul une fois fondu : l'appelant n'a
## rien à ranger.
func effacer() -> void:
	if _sortie < 0.0:
		_sortie = 0.0

func _process(delta: float) -> void:
	_t += delta
	if _anneau != null:
		_anneau.queue_redraw()

	# Les affiches se relaient sur DEUX calques seulement : celui qui vient de
	# s'effacer va chercher l'affiche suivante pendant qu'on regarde l'autre.
	# Empiler les neuf coûterait leur poids entier en mémoire vidéo pour un
	# écran qui n'en montre qu'une à la fois.
	var rang := int(_t / CROISEMENT)
	if rang != _rang:
		_rang = rang
		var suivante: String = AFFICHES[(rang + 1) % AFFICHES.size()]
		var dessous: TextureRect = _affiche_b if rang % 2 == 0 else _affiche_a
		if dessous != null:
			dessous.texture = load(suivante)
	var avance: float = fmod(_t, CROISEMENT) / CROISEMENT
	var croise: float = clampf((avance - (1.0 - FONDU / CROISEMENT)) / (FONDU / CROISEMENT), 0.0, 1.0)
	# Rang pair : A est en place, B monte. Rang impair : l'inverse.
	var part_a: float = (1.0 - croise) if rang % 2 == 0 else croise
	if _affiche_a != null:
		_affiche_a.modulate.a = part_a
		_derive(_affiche_a, _t * 0.012, 1.0)
	if _affiche_b != null:
		_affiche_b.modulate.a = 1.0 - part_a
		_derive(_affiche_b, _t * 0.012, -1.0)

	if _texte_astuce != null:
		var i := int(_t / DUREE_ASTUCE) % ASTUCES.size()
		if i != _astuce:
			_astuce = i
			_texte_astuce.text = ASTUCES[i]

	if _balayage != null:
		var cadre := _racine.size
		_balayage.size = Vector2(cadre.x, cadre.y * 0.22)
		_balayage.position.y = lerpf(-cadre.y * 0.10, cadre.y * 1.10, fmod(_t, 7.0) / 7.0)

	if _sortie >= 0.0:
		_sortie += delta * 1.6
		_racine.modulate.a = maxf(0.0, 1.0 - _sortie)
		if _sortie >= 1.0:
			queue_free()

## Un débord de six pour cent, et un va-et-vient dedans : l'image bouge sans
## jamais laisser voir son bord.
func _derive(image: TextureRect, avance: float, sens: float) -> void:
	var cadre := _racine.size
	var marge := cadre * 0.06
	image.size = cadre + marge * 2.0
	image.position = -marge + marge * Vector2(sin(avance * TAU) * sens, cos(avance * TAU * 0.7) * sens)
