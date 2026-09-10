class_name Terrain
extends RefCounted
## Le kit de la ferme : Serene Village (LimeZu, CC-BY) pour le monde, les
## cultures de josehzz (CC0), deux icônes d'outils de Tiny Town (CC0).
##
## Serene Village est le pack qui a le STYLE demandé — celui de Stardew : des
## contours doux, des couleurs pleines, des maisons à toit rouge, une mare aux
## rives dessinées. Il ne contient ni terre labourée ni légumes : la terre
## labourée est sa terre de chemin, teintée, et les légumes viennent d'une
## planche CC0 au même gabarit.

const VILLAGE := "res://modeles/ferme/serene_village.png"
const AUTOTUILES := "res://modeles/ferme/serene_autotiles.png"
const FEU := "res://modeles/ferme/serene_feu.png"
const EAU := "res://modeles/ferme/serene_eau.png"
const CULTURES_PNG := "res://modeles/ferme/cultures.png"
const TINY_TOWN := "res://modeles/ferme/tiny_town.png"
const TUILE := 16

# ---------------------------------------------------------- Serene Village
# Tout est repéré en (colonne, ligne) de la planche 19 × 45.

const HERBE: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
const PAVES: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)]
## L'eau pleine, sans reflet. La tuile centrale de l'auto-tuile porte un
## reflet fixe : sur un lac, il se répète en grille et fait un motif de papier
## peint, vu à l'image. Le reflet devient un sprite ANIMÉ, semé rarement.
const EAU_PLEINE := Vector2i(12, 1)
## La terre pleine du village, la seule tuile de terre SANS liseré d'herbe.
const TERRE_PLEINE := Vector2i(10, 2)

## La clôture, en neuf tuiles : angles, côtés, et deux bouts de poteaux.
const CLOTURE := {
	"hg": Vector2i(4, 15), "h": Vector2i(5, 15), "hd": Vector2i(6, 15),
	"g": Vector2i(4, 16), "d": Vector2i(6, 16),
	"bg": Vector2i(4, 17), "b": Vector2i(5, 17), "bd": Vector2i(6, 17),
	"poteau": Vector2i(5, 14),
}

## ⚠ Les arbres et les maisons ne sont PAS sur la grille de 16. Ces boîtes
## sont MESURÉES sur la planche (composantes de pixels opaques), pas déduites
## d'une vue d'ensemble : un arbre fait 32 × 38 — découpé en 32 × 32 à partir
## de la ligne de cases, il perdait le haut de sa cime, et c'est ce que le
## client a vu. La planche range ses arbres en quatre bandes :
##  · y 154 : une HAIE de forêt, quatre segments de 32 qui se raccordent bord
##    à bord (gardée pour les lisières dessinées à la main, plus tard) ;
##  · y 202 : quatre arbres isolés, et un petit arbre rond ;
##  · y 245 et y 293 : des BOSQUETS de trois ou quatre arbres, 80 de large.
const ARBRES: Array[Rect2i] = [
	Rect2i(144, 202, 32, 38), Rect2i(176, 202, 32, 38), Rect2i(208, 202, 32, 38), Rect2i(240, 202, 32, 38),
]
const PETIT_ARBRE := Rect2i(274, 212, 26, 28)
const HAIE: Array[Rect2i] = [
	Rect2i(144, 154, 32, 38), Rect2i(176, 154, 32, 38), Rect2i(208, 154, 32, 38), Rect2i(240, 154, 32, 38),
]
const BOSQUETS: Array[Rect2i] = [
	Rect2i(144, 245, 80, 43), Rect2i(224, 245, 80, 43), Rect2i(144, 293, 80, 43), Rect2i(224, 293, 80, 43),
]
## Les maisons, en pixels. Celle de la ferme : pignon, deux fenêtres, perron.
## (L'ancienne boîte 165 × 400 × 75 prenait DEUX maisonnettes voisines pour
## une seule, d'où une façade à deux portes.)
const MAISON_RECT := Rect2i(166, 336, 69, 59)
const MAISONS: Array[Rect2i] = [
	Rect2i(2, 344, 43, 51), Rect2i(50, 344, 43, 51), Rect2i(99, 336, 56, 59), Rect2i(166, 336, 69, 59),
	Rect2i(7, 405, 67, 54), Rect2i(87, 405, 67, 54), Rect2i(165, 400, 38, 60), Rect2i(213, 400, 38, 60),
]
const BUISSON := Vector2i(7, 12)
const FLEURS: Array[Vector2i] = [
	Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12),
]
const FLEURETTES: Array[Vector2i] = [Vector2i(2, 13), Vector2i(2, 14)]
## Les petits rochers tiennent dans une case ; les gros font deux cases de
## large et se découpent au pixel — à la case, on en posait des moitiés.
const ROCHERS: Array[Vector2i] = [Vector2i(0, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(3, 15)]
const GROS_ROCHERS: Array[Rect2i] = [
	Rect2i(6, 270, 21, 18), Rect2i(35, 269, 24, 19), Rect2i(3, 298, 24, 22), Rect2i(32, 296, 28, 23),
]
const PANCARTE := Vector2i(0, 13)
const PANNEAU := Vector2i(7, 13)
const BOITE_AUX_LETTRES := Vector2i(7, 16)   ## une tuile : la case du dessous est une AUTRE boîte, orange
const FRUITS: Array[Vector2i] = [Vector2i(15, 21), Vector2i(16, 21), Vector2i(17, 21), Vector2i(18, 21)]


# ---------------------------------------------------------- bords
#
# `serene_autotiles.png` n'est PAS une auto-tuile « matière au centre, bords
# autour » : ses trois blocs 4 × 4 (terre, falaise, eau) dessinent des ÎLOTS
# D'HERBE dans la matière. La tuile de bord se pose donc sur la case d'HERBE
# qui touche la matière, pas sur la matière — qui, elle, est pleine. Un lac,
# c'est de l'eau pleine, et une rive dessinée sur l'herbe tout autour ; la
# matière déborde de 8 px en haut et en bas, de 12 px sur les côtés, ce qui
# arrondit les angles tout seul. Lue comme une auto-tuile classique, la
# planche donnait des rives en escalier et un lac « à reflets répétés », vu.
#
# Dans chaque bloc : 3 × 3 d'îlot (angles, côtés, centre), la ligne 0 est une
# bande d'herbe horizontale (bouts en 1 et 3), la colonne 0 une bande
# verticale (bouts en 1 et 3), et (0, 0) l'herbe pleine.

const BLOC_TERRE := 0
const BLOC_FALAISE := 4
const BLOC_EAU := 8
const RIEN := Vector2i(-1, -1)

## La tuile de bord d'une case d'herbe d'après les côtés où se trouve la
## MATIÈRE (1 haut, 2 bas, 4 gauche, 8 droite). `RIEN` si aucun.
static func bord(bloc: int, matiere: int) -> Vector2i:
	if matiere == 0:
		return RIEN
	var haut := bool(matiere & 1)
	var bas := bool(matiere & 2)
	var gauche := bool(matiere & 4)
	var droite := bool(matiere & 8)
	if haut and bas:
		return Vector2i(bloc + (1 if gauche else (3 if droite else 2)), 0)
	if gauche and droite:
		return Vector2i(bloc, 1 if haut else (3 if bas else 2))
	return Vector2i(bloc + (1 if gauche else (3 if droite else 2)), 1 if haut else (3 if bas else 2))

## L'EAU suit l'autre grammaire, la classique : la planche du village a une
## mare complète — angles arrondis et côtés en (11..13, 0..2), eau pleine en
## (12, 1) — et une île dont les angles font les angles RENTRANTS en
## (3, 4), (8, 4), (3, 6), (8, 6). La tuile se pose sur la case d'EAU d'après
## ses huit voisines : 1 haut, 2 bas, 4 gauche, 8 droite, puis 16 haut-gauche,
## 32 haut-droite, 64 bas-gauche, 128 bas-droite. C'est ce qui arrondit une
## rive en diagonale au lieu de la laisser en escalier, vu à l'image.
static func eau(voisines: int) -> Vector2i:
	var haut := bool(voisines & 1)
	var bas := bool(voisines & 2)
	var gauche := bool(voisines & 4)
	var droite := bool(voisines & 8)
	if not (haut and bas and gauche and droite):
		var colonne := 11 if not gauche else (13 if not droite else 12)
		var ligne := 0 if not haut else (2 if not bas else 1)
		return Vector2i(colonne, ligne)
	if not (voisines & 16):
		return Vector2i(8, 6)
	if not (voisines & 32):
		return Vector2i(3, 6)
	if not (voisines & 64):
		return Vector2i(8, 4)
	if not (voisines & 128):
		return Vector2i(3, 4)
	return EAU_PLEINE

const TUILES_EAU: Array[Vector2i] = [
	Vector2i(11, 0), Vector2i(12, 0), Vector2i(13, 0), Vector2i(11, 1), Vector2i(13, 1),
	Vector2i(11, 2), Vector2i(12, 2), Vector2i(13, 2), Vector2i(3, 4), Vector2i(8, 4), Vector2i(3, 6), Vector2i(8, 6),
]

## La terre pleine, dans la planche des bords (voir `_bords`).
const BORD_TERRE_PLEINE := Vector2i(BLOC_TERRE + 2, 2)
const BORD_EAU_PLEINE := Vector2i(BLOC_EAU, 0)

# ---------------------------------------------------------- cultures josehzz

## `teinte`, `hauteur` (en huitièmes de bloc) et `racine` servent au plant en
## voxels ; `rang` reste le portrait pixel de l'interface.
const CULTURES := [
	{"nom": "navet", "rang": 0, "nuits": 2, "graine": 2, "prix": 5, "teinte": Color8(222, 200, 236), "hauteur": 3, "racine": true},
	{"nom": "pomme de terre", "rang": 14, "nuits": 3, "graine": 3, "prix": 8, "teinte": Color8(200, 160, 100), "hauteur": 4, "racine": true},
	{"nom": "blé", "rang": 10, "nuits": 3, "graine": 2, "prix": 7, "teinte": Color8(232, 200, 90), "hauteur": 7, "racine": false},
	{"nom": "tomate", "rang": 4, "nuits": 4, "graine": 4, "prix": 12, "teinte": Color8(222, 60, 60), "hauteur": 6, "racine": false},
	{"nom": "fraise", "rang": 12, "nuits": 4, "graine": 5, "prix": 14, "teinte": Color8(232, 70, 96), "hauteur": 3, "racine": false},
	{"nom": "maïs", "rang": 18, "nuits": 5, "graine": 5, "prix": 18, "teinte": Color8(246, 212, 80), "hauteur": 9, "racine": false},
]
const STADES := 5

const ICONE_HOUE := Rect2(112, 144, 16, 16)      ## Tiny Town, tuile 115
const ICONE_ARROSOIR := Rect2(176, 160, 16, 16)  ## Tiny Town, tuile 131

static var _cache: Dictionary = {}

# ---------------------------------------------------------- sprites

static func region(case: Vector2i, hauteur: int = 1, largeur: int = 1) -> Rect2:
	return Rect2(case.x * TUILE, case.y * TUILE, TUILE * largeur, TUILE * hauteur)

## Une tuile de la planche, ancrée en haut à gauche.
static func tuile(case: Vector2i) -> Sprite2D:
	var s := _sprite(_planche(VILLAGE))
	s.region_enabled = true
	s.region_rect = region(case)
	return s

## Un élément dressé, ancré aux PIEDS pour le tri par profondeur : `hauteur`
## tuiles empilées à partir de la cime.
static func dresse(cime: Vector2i, hauteur: int = 1, largeur: int = 1) -> Sprite2D:
	var s := _sprite(_planche(VILLAGE))
	s.region_enabled = true
	s.region_rect = region(cime, hauteur, largeur)
	s.offset = Vector2(-TUILE * largeur * 0.5, -TUILE * hauteur)
	return s

## Un élément dressé découpé au PIXEL (arbre, maison), ancré aux pieds.
static func dresse_rect(r: Rect2i) -> Sprite2D:
	var s := _sprite(_planche(VILLAGE))
	s.region_enabled = true
	s.region_rect = Rect2(r)
	s.offset = Vector2(-r.size.x * 0.5, -r.size.y)
	return s

## Une animation d'une planche horizontale d'images carrées.
static func animation(chemin: String, nom: String, vitesse: float) -> SpriteFrames:
	var texture := _planche(chemin)
	var poses := SpriteFrames.new()
	poses.remove_animation("default")
	poses.add_animation(nom)
	poses.set_animation_speed(nom, vitesse)
	poses.set_animation_loop(nom, true)
	if texture:
		var cote := texture.get_height()
		for i in int(texture.get_width() / cote):
			var morceau := AtlasTexture.new()
			morceau.atlas = texture
			morceau.region = Rect2(i * cote, 0, cote, cote)
			poses.add_frame(nom, morceau)
	return poses

static func icone(chemin: String, r: Rect2) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = _planche(chemin)
	t.region = r
	return t

## Le plant d'une culture à un stade (0 = graine, 4 = mûr).
## ⚠ La planche va de la plante MÛRE (colonne 1) à la GRAINE (colonne 5).
static func plant(culture: int, stade: int) -> Sprite2D:
	var f: Dictionary = CULTURES[posmod(culture, CULTURES.size())]
	var rang: int = int(f["rang"])
	var colonne := (rang % 2) * 6 + (STADES - clampi(stade, 0, STADES - 1))
	var s := _sprite(_planche(CULTURES_PNG))
	s.region_enabled = true
	s.region_rect = Rect2(colonne * TUILE, (rang / 2) * TUILE, TUILE, TUILE)
	s.offset = Vector2(-TUILE * 0.5, -TUILE)
	return s

static func portrait(culture: int) -> AtlasTexture:
	var f: Dictionary = CULTURES[posmod(culture, CULTURES.size())]
	var rang: int = int(f["rang"])
	return icone(CULTURES_PNG, Rect2((rang % 2) * 6 * TUILE, (rang / 2) * TUILE, TUILE, TUILE))

static func nom_culture(culture: int) -> String:
	return String(CULTURES[posmod(culture, CULTURES.size())]["nom"])

static func fiche(culture: int) -> Dictionary:
	return CULTURES[posmod(culture, CULTURES.size())]

# ---------------------------------------------------------- couches de tuiles
#
# Quatre sources dans le même jeu : la planche du village (herbe, pavés), et
# les auto-tuiles en trois teintes — chemin, terre labourée, terre arrosée.
# Une couche ne se teinte pas cellule par cellule, mais chaque tuile d'une
# source porte sa propre teinte : trois sources, trois terres.

const SOURCE_VILLAGE := 0
const SOURCE_CHEMIN := 1
const SOURCE_LABOUR := 2
const SOURCE_MOUILLE := 3
const TEINTE_LABOUR := Color(0.80, 0.70, 0.62)
const TEINTE_MOUILLE := Color(0.56, 0.50, 0.50)

static func jeu_de_tuiles() -> TileSet:
	if _cache.has("tileset"):
		return _cache["tileset"]
	var jeu := TileSet.new()
	jeu.tile_size = Vector2i(TUILE, TUILE)
	var village := TileSetAtlasSource.new()
	village.texture = _planche(VILLAGE)
	village.texture_region_size = Vector2i(TUILE, TUILE)
	for case in HERBE + PAVES + TUILES_EAU + [EAU_PLEINE, TERRE_PLEINE]:
		village.create_tile(case)

	jeu.add_source(village, SOURCE_VILLAGE)
	for entree in [[SOURCE_CHEMIN, Color.WHITE], [SOURCE_LABOUR, TEINTE_LABOUR], [SOURCE_MOUILLE, TEINTE_MOUILLE]]:
		var source := TileSetAtlasSource.new()
		source.texture = _bords()
		source.texture_region_size = Vector2i(TUILE, TUILE)
		for c in 12:
			for l in 4:
				source.create_tile(Vector2i(c, l))
				source.get_tile_data(Vector2i(c, l), 0).modulate = entree[1]
		jeu.add_source(source, int(entree[0]))
	_cache["tileset"] = jeu
	return jeu

static func couche(z: int) -> TileMapLayer:
	var c := TileMapLayer.new()
	c.tile_set = jeu_de_tuiles()
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.z_index = z
	c.y_sort_enabled = false
	return c

# ---------------------------------------------------------- la ferme
#
## ⚠ CES SIX-LÀ AVAIENT DISPARU, ET AVEC ELLES TOUT UN JEU. `scenes/ferme.gd`
## (l'écran ÉNIGME) les appelle depuis toujours ; la réécriture de ce fichier
## pour Serene Village les a laissées derrière elle, et la ferme ne se
## chargeait plus du tout — « Parse Error: Static function parcelle() not
## found », six fois, à l'ouverture de l'écran. Personne ne l'a vu parce que
## rien ne CHARGE les scripts entre deux parties : `--check-only` refuse tout
## fichier qui parle à un autoload. C'est ce trou-là qui a donné
## `outils/compiler.sh`.
##
## Elles sont réécrites AVEC le nouveau vocabulaire (cases en (colonne, ligne),
## planche du village, sources teintées du jeu de tuiles) et non recopiées de
## l'ancien : les teintes `TEINTE_LABOUR` et `TEINTE_MOUILLE` du jeu de tuiles
## avaient été préparées pour la ferme et n'avaient jamais servi.

## Ce qu'on sème sur la pelouse pour qu'elle ne soit pas une moquette : un
## buisson, cinq fleurs, deux fleurettes, quatre cailloux.
const DETAILS: Array[Vector2i] = [
	Vector2i(7, 12),
	Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12),
	Vector2i(2, 13), Vector2i(2, 14),
	Vector2i(0, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(3, 15),
]

static func detail(espece: int) -> Sprite2D:
	return tuile(DETAILS[posmod(espece, DETAILS.size())])

## Le dernier stade d'une culture — celui où elle se récolte.
static func dernier_stade() -> int:
	return STADES - 1

## LA PELOUSE, en une seule couche de tuiles. `largeur` et `hauteur` sont en
## PIXELS (c'est la taille du monde que l'appelant connaît), la graine rend le
## semis reproductible : sans elle, la pelouse change à chaque partie et les
## captures ne se comparent plus.
static func nappe(largeur: int, hauteur: int, tuiles: Array, graine: int) -> TileMapLayer:
	var couche_herbe := couche(-100)
	var tirage := RandomNumberGenerator.new()
	tirage.seed = graine
	# ⚠ Une COUCHE de tuiles, pas mille Sprite2D. À seize pixels la case, un
	# monde de 768 × 544 fait 1 632 cases : autant de nœuds, c'est autant
	# d'appels de dessin, et le jeu tombait à vingt images par seconde avant
	# d'avoir posé un seul légume.
	for l in int(ceil(float(hauteur) / float(TUILE))):
		for c in int(ceil(float(largeur) / float(TUILE))):
			var case: Vector2i = tuiles[tirage.randi_range(0, tuiles.size() - 1)]
			couche_herbe.set_cell(Vector2i(c, l), SOURCE_VILLAGE, case)
	return couche_herbe

## UNE PARCELLE labourée, de `cote` pixels de côté. `voisines` porte les côtés
## où la terre CONTINUE (1 haut, 2 bas, 4 gauche, 8 droite) : c'est ce qui
## donne le liseré d'herbe sur les bords libres, et une parcelle qui se fond
## dans la suivante quand on laboure deux cases côte à côte.
##
## Arrosée, elle passe sur la source MOUILLÉE : la même planche, une teinte
## plus sombre. C'est ce qui rend l'arrosage visible d'un coup d'œil sans
## ajouter un seul sprite.
static func parcelle(cote: int, graine: int, arrosee: bool, voisines: int) -> TileMapLayer:
	var couche_terre := couche(-50)
	var source := SOURCE_MOUILLE if arrosee else SOURCE_LABOUR
	var cases := maxi(1, int(cote / TUILE))
	var tirage := RandomNumberGenerator.new()
	tirage.seed = graine
	for l in cases:
		for c in cases:
			# Le masque LOCAL : la terre continue vers l'intérieur du carré, et
			# vers l'extérieur seulement si la parcelle voisine est labourée.
			var matiere := 0
			matiere |= 1 if (l > 0 or (voisines & 1)) else 0
			matiere |= 2 if (l < cases - 1 or (voisines & 2)) else 0
			matiere |= 4 if (c > 0 or (voisines & 4)) else 0
			matiere |= 8 if (c < cases - 1 or (voisines & 8)) else 0
			couche_terre.set_cell(Vector2i(c, l), source, case_de_terre(matiere))
	return couche_terre

## La tuile de TERRE d'après les côtés où la terre continue (1 haut, 2 bas,
## 4 gauche, 8 droite).
##
## ⚠ CE N'EST PAS `bord()`, et le premier jet s'y était trompé : `bord` donne
## la tuile d'une case d'HERBE qui touche de la matière — l'inverse. Utilisée
## ici, elle posait des bandes d'herbe au MILIEU du champ, et la parcelle
## sortait trouée (vu au banc, `outils/ferme.sh`).
##
## Le bloc est un 4 × 4 classique : le plein au centre (2, 2), la colonne 0 une
## bande verticale (l'herbe des deux côtés), la ligne 0 une bande horizontale.
static func case_de_terre(matiere: int) -> Vector2i:
	var haut := bool(matiere & 1)
	var bas := bool(matiere & 2)
	var gauche := bool(matiere & 4)
	var droite := bool(matiere & 8)
	# ⚠ LE SENS SE MESURE, IL NE SE DEVINE PAS. Dans cette planche, la ligne 1
	# porte sa décoration EN BAS de la tuile et la ligne 3 EN HAUT (idem pour
	# les colonnes 1 et 3, à droite et à gauche). Pris à l'envers, le liseré
	# d'herbe se dessinait UNE CASE À L'INTÉRIEUR du champ, comme un cadre —
	# vu au banc (`outils/ferme.sh`), invisible dans le code.
	# Une case de terre dont la terre continue EN BAS a donc de l'herbe EN
	# HAUT : ligne 3.
	var colonne := 2 if (gauche and droite) else (3 if droite else (1 if gauche else 0))
	var ligne := 2 if (haut and bas) else (3 if bas else (1 if haut else 0))
	return Vector2i(BLOC_TERRE + colonne, ligne)

## UN CAGEOT de récolte : une caisse de bois et ce qu'on y a mis. La caisse est
## dessinée ici (la planche du village n'en a pas), le légume sort de la
## planche des cultures à son dernier stade — c'est la même image que celle
## qu'on vient de cueillir, et c'est ce qui rend la pile lisible.
static func cageot(culture: int) -> Node2D:
	var racine := Node2D.new()
	var cle := "cageot"
	if not _cache.has(cle):
		var toile := Image.create(18, 12, false, Image.FORMAT_RGBA8)
		toile.fill(Color(0, 0, 0, 0))
		var bois := Color8(150, 103, 62)
		var clair := Color8(184, 133, 84)
		var sombre := Color8(104, 70, 42)
		for y in 12:
			for x in 18:
				if y < 2:
					continue
				var bord_caisse := x == 0 or x == 17 or y == 11
				var latte := (y - 2) % 4 == 0
				toile.set_pixel(x, y, sombre if bord_caisse else (clair if latte else bois))
		_cache[cle] = ImageTexture.create_from_image(toile)
	var caisse := _sprite(_cache[cle])
	caisse.offset = Vector2(-9, -12)
	racine.add_child(caisse)
	var recolte := plant(culture, STADES - 1)
	recolte.position = Vector2(0, -4)
	racine.add_child(recolte)
	return racine

# ---------------------------------------------------------- petits fabriqués

## Une ombre portée, à poser sous un personnage.
static func ombre(largeur: int = 18, hauteur: int = 7) -> Sprite2D:
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
					toile.set_pixel(x, y, Color(0, 0, 0, 0.40))
				elif d <= 1.0:
					toile.set_pixel(x, y, Color(0, 0, 0, 0.20))
		_cache[cle] = ImageTexture.create_from_image(toile)
	var s := _sprite(_cache[cle])
	s.offset = Vector2(-largeur * 0.5, -hauteur * 0.5)
	s.z_index = -1
	return s

## Le cadre de la case visée : quatre équerres.
static func curseur(cote: int) -> Sprite2D:
	var cle := "curseur:%d" % cote
	if not _cache.has(cle):
		var toile := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
		toile.fill(Color(0, 0, 0, 0))
		var blanc := Color(1, 1, 1, 0.9)
		for i in 4:
			for point in [Vector2i(i, 0), Vector2i(0, i), Vector2i(cote - 1 - i, 0),
					Vector2i(cote - 1, i), Vector2i(i, cote - 1), Vector2i(0, cote - 1 - i),
					Vector2i(cote - 1 - i, cote - 1), Vector2i(cote - 1, cote - 1 - i)]:
				toile.set_pixel(point.x, point.y, blanc)
		_cache[cle] = ImageTexture.create_from_image(toile)
	return _sprite(_cache[cle])

## La planche des bords, préparée au chargement : l'herbe de l'intérieur des
## îlots (deux verts en damier, les mêmes que la tuile d'herbe) devient
## transparente — opaque, elle prenait la teinte de la terre labourée et
## faisait un liseré d'herbe sombre ; et la case centrale du bloc terre reçoit
## la terre pleine du village, que la planche n'a pas.
const VERT_A := Color8(118, 197, 100)
const VERT_B := Color8(123, 203, 105)

static func _bords() -> Texture2D:
	if not _cache.has("bords"):
		var image: Image = _planche(AUTOTUILES).get_image()
		image.convert(Image.FORMAT_RGBA8)
		var a := VERT_A.to_rgba32()
		var b := VERT_B.to_rgba32()
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y).to_rgba32()
				if c == a or c == b:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
		var village: Image = _planche(VILLAGE).get_image()
		village.convert(Image.FORMAT_RGBA8)
		image.blit_rect(village, Rect2i(TERRE_PLEINE * TUILE, Vector2i(TUILE, TUILE)), BORD_TERRE_PLEINE * TUILE)
		_cache["bords"] = ImageTexture.create_from_image(image)
	return _cache["bords"]

static func _planche(chemin: String) -> Texture2D:
	if not _cache.has(chemin):
		_cache[chemin] = load(chemin) as Texture2D
	return _cache[chemin]

static func _sprite(texture: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s
