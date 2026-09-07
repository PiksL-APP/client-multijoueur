class_name Terrain
extends RefCounted
## Le sol de la ferme, et l'ombre des personnages.
##
## Le pack ne livre pas de tuiles de terrain : `sol_village.png` est une seule
## image de 768×544, de l'herbe bruitée avec une place pavée. On ne peut donc
## pas y découper un jeu de tuiles — mais on peut refaire la recette. Les
## couleurs ci-dessous sont RELEVÉES dans les fichiers du pack, pas inventées :
## les verts et les gris dans le sol du village, les bruns dans le bois des
## caisses et du banc. La ferme est de la même main que le village, et rien
## n'a été ajouté au dépôt.
##
## Le grain est de quatre pixels, mesuré sur l'image d'origine. En un pixel le
## bruit grésille, en huit il fait des taches.

## Grain du bruit du sol. UN pixel, pas quatre.
##
## ⚠ Mesuré sur `sol_village.png` : l'herbe du pack n'a que TROIS verts, tous
## très proches, tirés pixel par pixel. Ma première version en prenait cinq —
## dont deux nettement plus sombres — par blocs de quatre : ça faisait des
## taches, et la ferme jurait à côté du village alors que la palette était
## censée être la même. Trois teintes voisines à un pixel de grain sont
## indiscernables de l'original.
const BLOC := 1

const HERBE: Array[Color] = [
	Color8(0x33, 0x79, 0x03), Color8(0x32, 0x74, 0x04), Color8(0x33, 0x76, 0x04),
]

## Les tons de la terre retournée, relevés dans le bois du pack (`caisses`,
## `banc`) : c'est la seule terre dont il dispose. Le contour est presque noir,
## comme tous les sprites du pack — c'est ce cerne qui fait qu'un champ
## appartient au dessin au lieu de flotter dessus.
const TERRE: Array[Color] = [
	Color8(0x5a, 0x36, 0x1e), Color8(0x4e, 0x2f, 0x1a), Color8(0x66, 0x3e, 0x22),
]
const MOTTE_CLAIRE := Color8(0x7d, 0x4c, 0x28)
const MOTTE_SOMBRE := Color8(0x40, 0x26, 0x14)
const CONTOUR := Color8(0x1a, 0x0f, 0x08)

## Les brins d'herbe, champignons et fleurs du pack, repérés dans
## `sol_village.png` — ce sont de vrais pixels du pack, pas des dessins de mon
## cru. Sans eux, une prairie fabriquée est une surface unie de six cents
## pixels de côté, et l'œil n'a rien où se poser.
const DETAILS: Array[Rect2i] = [
	Rect2i(564, 149, 10, 8), Rect2i(134, 150, 5, 7), Rect2i(805, 164, 7, 9),
	Rect2i(837, 181, 7, 6), Rect2i(468, 197, 8, 7), Rect2i(693, 197, 6, 6),
	Rect2i(917, 197, 7, 6), Rect2i(341, 229, 7, 6), Rect2i(389, 229, 7, 6),
	Rect2i(740, 229, 8, 7), Rect2i(244, 309, 8, 7), Rect2i(847, 320, 9, 6),
]
const SOL_VILLAGE := "res://modeles/village/sol_village.png"

static var _cache: Dictionary = {}

## Une grande nappe d'herbe, en un seul sprite.
##
## Une image entière plutôt qu'une tuile répétée : le bruit ne se répète alors
## jamais, et surtout le sol coûte UN appel de dessin.
static func nappe(largeur: int, hauteur: int, palette: Array[Color], graine: int) -> Sprite2D:
	var cle := "nappe:%d:%d:%d:%d" % [largeur, hauteur, palette[0].to_rgba32(), graine]
	if not _cache.has(cle):
		var tirage := RandomNumberGenerator.new()
		tirage.seed = graine
		var toile := Image.create(largeur, hauteur, false, Image.FORMAT_RGBA8)
		for y in hauteur:
			for x in largeur:
				toile.set_pixel(x, y, palette[tirage.randi_range(0, palette.size() - 1)])
		_cache[cle] = ImageTexture.create_from_image(toile)
	return _sprite(_cache[cle])

## Un brin d'herbe ou une fleur du pack, à semer sur la prairie.
static func detail(indice: int) -> Sprite2D:
	var region: Rect2i = DETAILS[posmod(indice, DETAILS.size())]
	var sprite := _sprite(_planche(SOL_VILLAGE))
	sprite.region_enabled = true
	sprite.region_rect = Rect2(region)
	sprite.offset = Vector2(-region.size.x * 0.5, -region.size.y)
	return sprite

## Une parcelle labourée.
##
## `bords` porte les quatre voisines déjà retournées (1 haut, 2 bas, 4 gauche,
## 8 droite) : le cerne noir n'est tracé que du côté OUVERT. Sans ça, chaque
## case garde son cadre et le champ ressemble à un damier de tuiles au lieu
## d'une seule terre travaillée — c'était le défaut le plus visible de la
## première version.
##
## La texture est faite de PIQUETÉ et de courts tirets, jamais de lignes
## continues : des sillons pleins d'un bord à l'autre donnent un parquet.
static func parcelle(cote: int, graine: int, arrosee: bool, bords: int) -> Sprite2D:
	var cle := "parcelle:%d:%d:%s:%d" % [cote, graine, arrosee, bords]
	if not _cache.has(cle):
		var tirage := RandomNumberGenerator.new()
		tirage.seed = graine
		var toile := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
		for y in cote:
			for x in cote:
				toile.set_pixel(x, y, TERRE[tirage.randi_range(0, TERRE.size() - 1)])
		for i in int(cote * cote / 14.0):
			var x := tirage.randi_range(0, cote - 1)
			var y := tirage.randi_range(0, cote - 1)
			var teinte := MOTTE_CLAIRE if tirage.randf() < 0.45 else MOTTE_SOMBRE
			for k in tirage.randi_range(2, 4):
				if x + k < cote:
					toile.set_pixel(x + k, y, teinte)
		if arrosee:
			for y in cote:
				for x in cote:
					var p := toile.get_pixel(x, y)
					toile.set_pixel(x, y, Color(p.r * 0.62, p.g * 0.60, p.b * 0.66, 1.0))
		if not (bords & 1):
			for x in cote:
				toile.set_pixel(x, 0, CONTOUR)
		if not (bords & 2):
			for x in cote:
				toile.set_pixel(x, cote - 1, CONTOUR)
		if not (bords & 4):
			for y in cote:
				toile.set_pixel(0, y, CONTOUR)
		if not (bords & 8):
			for y in cote:
				toile.set_pixel(cote - 1, y, CONTOUR)
		_cache[cle] = ImageTexture.create_from_image(toile)
	return _sprite(_cache[cle])

## Une ombre portée, à poser sous un personnage.
##
## Sans elle, un sprite debout dans une vue de dessus FLOTTE : rien ne dit à
## quelle case il touche le sol, et deux personnages décalés d'une rangée
## paraissent à la même place. Ellipse pixelisée en deux tons, PAS un dégradé
## doux : un dégradé dans un décor en pixel art se repère tout de suite comme
## un corps étranger.
static func ombre(largeur: int = 22, hauteur: int = 8) -> Sprite2D:
	var cle := "ombre:%dx%d" % [largeur, hauteur]
	if not _cache.has(cle):
		var toile := Image.create(largeur, hauteur, false, Image.FORMAT_RGBA8)
		toile.fill(Color(0, 0, 0, 0))
		var cx := (largeur - 1) * 0.5
		var cy := (hauteur - 1) * 0.5
		for y in hauteur:
			for x in largeur:
				var d := pow((x - cx) / (cx + 0.5), 2.0) + pow((y - cy) / (cy + 0.5), 2.0)
				if d <= 0.55:
					toile.set_pixel(x, y, Color(0, 0, 0, 0.46))
				elif d <= 1.0:
					toile.set_pixel(x, y, Color(0, 0, 0, 0.26))
		_cache[cle] = ImageTexture.create_from_image(toile)
	var sprite := _sprite(_cache[cle])
	sprite.offset = Vector2(-largeur * 0.5, -hauteur * 0.5)
	# Sous son porteur, jamais devant : `z_index` négatif place l'enfant
	# derrière le dessin du parent sans toucher au tri par profondeur du plan.
	sprite.z_index = -1
	return sprite

static func _assombrir(teinte: Color, facteur: float) -> Color:
	return Color(clampf(teinte.r * facteur, 0, 1), clampf(teinte.g * facteur, 0, 1),
		clampf(teinte.b * facteur, 0, 1), teinte.a)

static func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

# ------------------------------------------------------------------ cultures
#
# Les plants sont les VRAIS légumes du pack — `culture_radis.png` et ses
# voisins, seize pixels de côté, la moitié d'une parcelle une fois doublés.
#
# ⚠ Le stade de croissance est une tranche prise par le HAUT, posée au ras du
# sol. C'est contre-intuitif et c'est pourtant le bon sens du dessin : ces
# sprites ont le feuillage en haut et le légume en bas. Une tranche haute ne
# montre donc QUE les feuilles — exactement ce qu'on voit d'un plant jeune —
# et le radis ne gonfle qu'au dernier stade, quand la tranche atteint le bas
# de l'image. Pris par le bas, on verrait le légume avant les feuilles : la
# plante pousserait à l'envers.
#
# Réduire le sprite à l'échelle aurait donné de la bouillie : on ne
# redimensionne pas du pixel art.

## Les quatre cultures du pack. L'ordre est celui du semoir.
const CULTURES := ["radis", "carottes", "laitues", "choux"]

## Hauteur de la tranche visible, par stade. Mesurée à l'image : sous cinq
## pixels un chou ne se voit pas, et le dernier stade est le sprite entier.
const STADES := [5, 8, 12, 16]

static func nom_culture(culture: int) -> String:
	return String(CULTURES[posmod(culture, CULTURES.size())])

static func dernier_stade() -> int:
	return STADES.size() - 1

## Le plant, ancré à ses pieds au bas de la parcelle.
static func plant(culture: int, stade: int) -> Sprite2D:
	var chemin := "res://modeles/village/culture_%s.png" % nom_culture(culture)
	var texture := _planche(chemin)
	if texture == null:
		return _sprite(null)
	var hauteur: int = STADES[clampi(stade, 0, STADES.size() - 1)]
	var largeur := texture.get_width()
	var sprite := _sprite(texture)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, largeur, hauteur)
	sprite.scale = Vector2(2, 2)
	sprite.offset = Vector2(-largeur * 0.5, -hauteur)
	return sprite

## Le cageot d'une récolte, pour le tas devant la grange.
static func cageot(culture: int) -> Sprite2D:
	var texture := _planche("res://modeles/village/cageot_%s.png" % nom_culture(culture))
	var sprite := _sprite(texture)
	if texture:
		sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	return sprite

## Le cadre de la case visée.
##
## Sans lui, on ne sait pas OÙ la houe va tomber : l'action porte sur la case
## sous les pieds, et le personnage en chevauche deux la moitié du temps. Le
## défaut ne se voit pas sur une capture, seulement à la manette — on laboure
## systématiquement la rangée d'à côté.
static func curseur(cote: int) -> Sprite2D:
	var cle := "curseur:%d" % cote
	if not _cache.has(cle):
		var toile := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
		toile.fill(Color(0, 0, 0, 0))
		var blanc := Color(1, 1, 1, 0.85)
		# Quatre équerres plutôt qu'un cadre plein : un cadre continu se
		# confond avec le liseré des parcelles labourées.
		for i in 6:
			for point in [Vector2i(i, 0), Vector2i(0, i), Vector2i(cote - 1 - i, 0),
					Vector2i(cote - 1, i), Vector2i(i, cote - 1), Vector2i(0, cote - 1 - i),
					Vector2i(cote - 1 - i, cote - 1), Vector2i(cote - 1, cote - 1 - i)]:
				toile.set_pixel(point.x, point.y, blanc)
		_cache[cle] = ImageTexture.create_from_image(toile)
	return _sprite(_cache[cle])

static func _planche(chemin: String) -> Texture2D:
	if not _cache.has(chemin):
		_cache[chemin] = load(chemin) as Texture2D
	return _cache[chemin]
