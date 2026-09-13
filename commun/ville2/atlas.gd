extends RefCounted
## LES VARIANTES DE COULEUR DES KITS — la réponse à « arrête d'utiliser le
## modèle avec les toitures vertes ».
##
## ⚠ IL N'Y A QU'UN SEUL MODÈLE, ET IL N'Y EN A JAMAIS EU DEUX. Le dépôt porte
## `modeles/banlieue/`, `modeles/commerce/`, `modeles/industrie/` et
## `modeles/ville/` à côté des kits Kenney, et tout laissait croire que
## c'étaient les « variantes » du client. Vérifié au md5, le 13/09 :
## `banlieue/building-type-a.glb` est OCTET POUR OCTET
## `kenney/pavillons/building-type-a.glb`, et leurs deux `colormap.png` sont
## identiques eux aussi. Ce sont des copies, pas des variantes — et
## `suburb-building-type-*` de même.
##
## Le vert des toits ne vient donc pas du modèle : il vient de l'ATLAS. Les
## kits Kenney ne texturent pas, ils PALETTISENT — le `colormap.png` est une
## grille de bandes de couleur unies, et chaque face du maillage pointe une
## bande. Les toits de tout le kit pavillon pointent la même bande verte
## (teinte 0,40 · saturation 0,52 · valeur 0,80, 16 384 pixels sur 262 144).
##
## Changer la couleur d'un toit, c'est donc repeindre CETTE BANDE. On fabrique
## une copie de l'atlas où les pixels verts sont remplacés par la couleur
## voulue — en gardant leur clair-obscur, sinon le toit devient un aplat et
## perd son volume — et on la donne au shader du kit. Le reste de la palette
## (murs, fenêtres, portes, bois) n'est pas touché.
##
## ⚠ CE N'EST PAS LA MÊME CHOSE QUE `teinte`. La teinte d'instance MULTIPLIE
## tout le modèle : elle colore les murs et salit le toit du même geste. Ici on
## ne touche qu'une bande, et les murs restent blancs — c'est ce qui permet
## d'avoir dix maisons blanches à toitures différentes, qui est très exactement
## ce qu'on voit dans un vrai lotissement.

## La bande à repeindre, en TSV. Une fourchette large : le kit nuance sa bande
## (0,40 à 0,46 selon l'éclairage cuit dans la texture).
const TEINTE_MIN := 0.28
const TEINTE_MAX := 0.47
const SAT_MIN := 0.20
const VAL_MIN := 0.15
## La valeur moyenne de la bande d'origine : elle sert de référence pour
## reporter le clair-obscur sur la couleur neuve.
const VAL_REF := 0.80

static var _faits: Dictionary = {}

## Rend une copie de l'atlas dont la bande verte est repeinte en `cible`.
## Le résultat est mis en cache : une variante par (atlas, couleur).
static func toiture(source: Texture2D, cible: Color) -> Texture2D:
	if source == null: return source
	var cle := "%s|%s" % [source.resource_path, cible.to_html(false)]
	if _faits.has(cle): return _faits[cle]
	var img := source.get_image()
	if img == null: return source
	img = img.duplicate()
	# ⚠ UNE TEXTURE IMPORTÉE EST COMPRESSÉE. `get_pixel` sur une image VRAM
	# rend du noir sans se plaindre ; il faut la décompresser d'abord, puis la
	# ramener en RGBA8, sinon `set_pixel` n'écrit nulle part.
	if img.is_compressed():
		if img.decompress() != OK: return source
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5: continue
			if c.h < TEINTE_MIN or c.h > TEINTE_MAX: continue
			if c.s < SAT_MIN or c.v < VAL_MIN: continue
			# Le clair-obscur du pixel, reporté sur la couleur neuve : c'est
			# lui qui donne au toit ses pentes et son arête faîtière.
			var facteur := c.v / VAL_REF
			img.set_pixel(x, y, Color.from_hsv(cible.h, cible.s,
				clampf(cible.v * facteur, 0.0, 1.0), 1.0))
	var tex := ImageTexture.create_from_image(img)
	_faits[cle] = tex
	return tex

## ⚠ DES TOITS QUI EXISTENT. Ce ne sont pas des couleurs choisies au hasard :
## une toiture est en tuile, en ardoise, en zinc, en bardeau ou en tôle, et
## ça ne fait qu'une poignée de familles. Dix toits pris là-dedans se lisent
## comme un vrai lotissement ; dix toits pris dans la roue chromatique se
## lisent comme un nuancier.
const TUILE := "#b4553a"          ## tuile romane, la plus courante
const TUILE_CLAIRE := "#c9744d"
const TUILE_VIEILLE := "#9c5340"
const ARDOISE := "#4d5560"        ## ardoise bleutée
const ARDOISE_SOMBRE := "#3b4149"
const ZINC := "#8e959b"
const BARDEAU := "#6b5c4c"        ## bardeau de bois grisé
const TOLE_ROUGE := "#a2453c"
const TOLE_BLEUE := "#4a6c86"
const CHAUME := "#a89060"

## Les gammes par quartier.
const PAVILLONNAIRE := [TUILE, TUILE_CLAIRE, ARDOISE, BARDEAU, ZINC,
	TUILE_VIEILLE, ARDOISE_SOMBRE, TOLE_BLEUE]
## LE SUD DE LA FRANCE : que de la tuile, et rien d'autre. C'est ce qui fait
## qu'un village du Midi se reconnaît d'une photo aérienne — un seul matériau,
## dix nuances de cuisson.
const MIDI := [TUILE, TUILE_CLAIRE, TUILE_VIEILLE, "#c07a52", "#a85c3c",
	"#bd6842", "#b06a4a"]
## La vieille ville : tuile passée et ardoise, plus sombre.
const VIEILLE := [TUILE_VIEILLE, ARDOISE, ARDOISE_SOMBRE, TUILE, BARDEAU, ZINC]
## Le bidonville : de la tôle, rien que de la tôle, et elle rouille.
const TOLE := [TOLE_ROUGE, "#8a6a4e", ZINC, "#7d8a82", "#9c6b4a", "#6f7a80"]


# ------------------------------------------------------------------ la verdure

## ⚠ LE KIT NATURE NE PASSE PAS PAR UN ATLAS : IL PORTE SA COULEUR AU SOMMET.
## La méthode `toiture()` ci-dessus repeint une bande d'une texture — elle ne
## peut rien pour une tuile du kit nature, dont la matière est un
## `StandardMaterial3D` en `vertex_color_use_as_albedo`. Le même besoin se pose
## pourtant, et pour la même raison.
##
## LE PROBLÈME EXACT. Une tuile `ground_path*` est un carré d'HERBE dans lequel
## le chemin est creusé. Posée sur la terre battue d'un bidonville, elle
## apporte son herbe avec elle : un rectangle vert par case de sente.
##
## Et la teinte d'instance n'y peut rien. Elle MULTIPLIE : pour faire brunir un
## vert (0,45 · 0,78 · 0,42) il faut écraser la composante verte, ce qui
## écrase du même coup le beige clair du chemin (0,93 · 0,88 · 0,78) et le rend
## rose. Un seul facteur ne peut pas transformer un vert en brun ET laisser un
## neutre neutre — c'est arithmétique, pas une question de réglage.
##
## On repeint donc LES SOMMETS, ce qui est le strict équivalent de repeindre
## une bande d'atlas : on ne touche qu'aux sommets verts, le chemin ne bouge
## pas, et son ornière garde son clair-obscur.
const VERT_MIN := 0.22
const VERT_MAX := 0.47
const VERT_SAT_MIN := 0.18
## La valeur moyenne de l'herbe du kit : la référence du clair-obscur.
const VERT_VAL_REF := 0.78

static var _sans_verdure: Dictionary = {}

## Rend une copie du maillage où l'herbe est remplacée par `cible`.
## `echelle` et les autres arguments sont ceux de `FormesCarnage.maillage_kenney`.
static func sans_verdure(chemin: String, cible: Color) -> Mesh:
	var cle := "%s|%s" % [chemin, cible.to_html(false)]
	if _sans_verdure.has(cle): return _sans_verdure[cle]
	var source: ArrayMesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	if source == null: return source
	var neuf := ArrayMesh.new()
	for s in source.get_surface_count():
		var tab: Array = source.surface_get_arrays(s)
		var couleurs: PackedColorArray = tab[Mesh.ARRAY_COLOR]
		for k in couleurs.size():
			var c := couleurs[k]
			if c.h < VERT_MIN or c.h > VERT_MAX: continue
			if c.s < VERT_SAT_MIN: continue
			couleurs[k] = Color.from_hsv(cible.h, cible.s,
				clampf(cible.v * (c.v / VERT_VAL_REF), 0.0, 1.0), c.a)
		tab[Mesh.ARRAY_COLOR] = couleurs
		neuf.add_surface_from_arrays(source.surface_get_primitive_type(s), tab)
	_sans_verdure[cle] = neuf
	return neuf

## La terre sèche d'un bidonville : ce que devient l'herbe d'une tuile de
## chemin quand le quartier n'en a pas un brin.
const TERRE_SECHE := Color("#8a7355")
