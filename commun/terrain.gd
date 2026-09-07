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

const BLOC := 4
const SILLON := 8                  ## pas des sillons d'une parcelle labourée

const HERBE: Array[Color] = [
	Color8(0x33, 0x79, 0x03), Color8(0x32, 0x74, 0x04), Color8(0x33, 0x76, 0x04),
	Color8(0x2e, 0x6d, 0x03), Color8(0x26, 0x5a, 0x02),
]
const PIERRE: Array[Color] = [
	Color8(0x92, 0x7e, 0x65), Color8(0x84, 0x70, 0x56),
]
## Les bruns du bois du pack : c'est la seule terre dont il dispose.
const TERRE: Array[Color] = [
	Color8(0x7d, 0x4c, 0x28), Color8(0x6b, 0x42, 0x23), Color8(0x5a, 0x36, 0x1e),
]

static var _cache: Dictionary = {}

## Une grande nappe de sol, en un seul sprite.
##
## Une image entière plutôt qu'une tuile répétée : le bruit ne se répète alors
## jamais, et surtout le sol coûte UN appel de dessin. En tuiles de trente-deux
## pixels, une ferme entière en demanderait des centaines par image, ce qui ne
## passe pas dans un navigateur en mode compatibilité.
static func nappe(largeur: int, hauteur: int, palette: Array[Color], graine: int) -> Sprite2D:
	var cle := "nappe:%d:%d:%d:%d" % [largeur, hauteur, palette[0].to_rgba32(), graine]
	if not _cache.has(cle):
		var tirage := RandomNumberGenerator.new()
		tirage.seed = graine
		var toile := Image.create(largeur, hauteur, false, Image.FORMAT_RGBA8)
		for by in range(0, hauteur, BLOC):
			for bx in range(0, largeur, BLOC):
				toile.fill_rect(Rect2i(bx, by, BLOC, BLOC),
					palette[tirage.randi_range(0, palette.size() - 1)])
		_cache[cle] = ImageTexture.create_from_image(toile)
	return _sprite(_cache[cle])

## Une parcelle labourée. `arrosee` l'assombrit : c'est ainsi qu'on voit d'un
## coup d'œil ce qui a soif, sans avoir à survoler chaque case.
static func parcelle(cote: int, graine: int, arrosee: bool) -> Sprite2D:
	var cle := "parcelle:%d:%d:%s" % [cote, graine, arrosee]
	if not _cache.has(cle):
		var tirage := RandomNumberGenerator.new()
		tirage.seed = graine
		var toile := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
		var mouille := 0.72 if arrosee else 1.0
		for by in range(0, cote, BLOC):
			for bx in range(0, cote, BLOC):
				toile.fill_rect(Rect2i(bx, by, BLOC, BLOC), _assombrir(
					TERRE[tirage.randi_range(0, TERRE.size() - 1)], mouille))
		# Les sillons sont HACHÉS, pas continus : une ligne pleine d'un bord à
		# l'autre donne un joint de plancher, et vingt parcelles alignées font
		# un parquet. Une motte sur cinq laissée intacte casse le trait.
		for y in cote:
			var reste := y % SILLON
			var facteur := 0.0
			if reste <= 1:
				facteur = 0.80
			elif reste == 4 or reste == 5:
				facteur = 1.14
			else:
				continue
			for x in cote:
				if tirage.randf() < 0.22:
					continue
				toile.set_pixel(x, y, _assombrir(toile.get_pixel(x, y), facteur))
		# Un liseré sombre sur le pourtour : sans lui, vingt parcelles côte à
		# côte forment une seule dalle brune et on ne voit plus la case qu'on
		# travaille.
		for x in cote:
			toile.set_pixel(x, 0, _assombrir(toile.get_pixel(x, 0), 0.78))
			toile.set_pixel(x, cote - 1, _assombrir(toile.get_pixel(x, cote - 1), 0.78))
		for y in cote:
			toile.set_pixel(0, y, _assombrir(toile.get_pixel(0, y), 0.78))
			toile.set_pixel(cote - 1, y, _assombrir(toile.get_pixel(cote - 1, y), 0.78))
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
# Les plants sont des BUISSONS DU PACK, pas un dessin de mon cru : le fichier
# `buisson_petit_*.png` fait trente-deux pixels, exactement la taille d'une
# parcelle, et il est dessiné par la même main que le reste.
#
# Le stade de croissance est une BANDE prise par le BAS du buisson. Le procédé
# marche parce que ces buissons sont éclairés d'en haut : la base est sombre et
# touffue, la cime est claire. Une bande basse donne donc une touffe sombre qui
# sort à peine de la terre, et la coupe franche ne se voit pas — elle tombe là
# où le feuillage est déjà dense. Réduire le buisson à l'échelle aurait donné
# de la bouillie : on ne redimensionne pas du pixel art.
#
# Les quatre variantes du pack sont SAISONNIÈRES (vert, vert-jaune, jaune,
# roux). Elles serviront de saisons le jour où le calendrier existera ; en
# attendant, `saison` permet déjà de distinguer deux cultures à l'œil.

## Hauteur de la bande visible, par stade. Mesurée à l'image : sous huit
## pixels on ne voit rien pousser, au-delà de vingt-six le plant déborde sur
## la rangée voisine et le champ devient illisible.
const STADES := [9, 16, 26]

## Le plant à un stade donné, ancré à ses pieds au bas de la parcelle.
static func plant(stade: int, saison: int = 0) -> Sprite2D:
	var chemin := "res://modeles/village/buisson_petit_%d.png" % clampi(saison, 0, 3)
	var texture := _planche(chemin)
	if texture == null:
		return _sprite(null)
	var hauteur: int = STADES[clampi(stade, 0, STADES.size() - 1)]
	var largeur := texture.get_width()
	var sprite := _sprite(texture)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, texture.get_height() - hauteur, largeur, hauteur)
	sprite.offset = Vector2(-largeur * 0.5, -hauteur)
	return sprite

static func _planche(chemin: String) -> Texture2D:
	if not _cache.has(chemin):
		_cache[chemin] = load(chemin) as Texture2D
	return _cache[chemin]
