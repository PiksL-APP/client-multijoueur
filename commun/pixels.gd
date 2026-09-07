class_name Pixels
extends RefCounted
## Découpe des planches de sprites en animations.
##
## Le pack est livré en bandes horizontales : une image de 384 sur 64 tient six
## poses de 64. Rien dans le fichier ne dit combien : on le déduit de la
## largeur, ce qui évite d'écrire un tableau de comptes que le premier ajout
## de pose rendrait faux.

static func planche(chemin: String) -> Texture2D:
	return load(chemin) as Texture2D

## Ajoute une animation à un jeu de poses. `cote` est la taille d'une case ;
## la hauteur de la planche fait foi quand on ne la précise pas.
static func ajouter(poses: SpriteFrames, nom: String, chemin: String,
		vitesse: float = 8.0, boucle: bool = true, cote: int = 0) -> void:
	var texture := planche(chemin)
	if texture == null:
		return
	var hauteur := texture.get_height()
	var largeur_case := cote if cote > 0 else hauteur
	var nombre := int(texture.get_width() / largeur_case)
	if not poses.has_animation(nom):
		poses.add_animation(nom)
	poses.set_animation_speed(nom, vitesse)
	poses.set_animation_loop(nom, boucle)
	for i in nombre:
		var morceau := AtlasTexture.new()
		morceau.atlas = texture
		morceau.region = Rect2(i * largeur_case, 0, largeur_case, hauteur)
		poses.add_frame(nom, morceau)

## Un héros jouable : repos et course, vus de côté. La gauche n'existe pas
## dans le pack — c'est la droite retournée, ce qui est la convention de tous
## ces kits. Les trois héros existent en `knight`, `rogue` et `wizzard`.
const HEROS := ["knight", "rogue", "wizzard"]

static func heros(nom: String) -> SpriteFrames:
	var poses := SpriteFrames.new()
	poses.remove_animation("default")
	var base := "res://modeles/village/heros_%s_" % nom
	ajouter(poses, "repos", base + "repos.png", 5.0)
	ajouter(poses, "marche", base + "marche.png", 10.0)
	return poses

## Le héros d'un joueur découle de son identité : tous les clients font le
## même calcul, donc tous voient le même personnage pour la même personne.
static func heros_de(id: String) -> String:
	return HEROS[absi(id.hash()) % HEROS.size()]

static func personnage_non_joueur(nom: String) -> SpriteFrames:
	var poses := animation("repos", "res://modeles/village/pnj_%s.png" % nom, 5.0)
	var marche := "res://modeles/village/pnj_%s_marche.png" % nom
	if ResourceLoader.exists(marche):
		ajouter(poses, "marche", marche, 10.0)
	return poses

## Une seule animation tirée d'une planche : le feu de camp, par exemple.
static func animation(nom: String, chemin: String, vitesse: float = 8.0, cote: int = 0) -> SpriteFrames:
	var poses := SpriteFrames.new()
	poses.remove_animation("default")
	ajouter(poses, nom, chemin, vitesse, true, cote)
	return poses

## Un sprite de pixel art doit être filtré au plus proche voisin et posé sur
## un pixel entier : interpolé, il bave ; à mi-pixel, il scintille dès qu'on
## bouge.
static func poser(sprite: Node2D, position: Vector2) -> void:
	sprite.position = position.round()

static func image(chemin: String, ancre_en_bas: bool = true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = planche(chemin)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	if s.texture and ancre_en_bas:
		s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height())
	return s
