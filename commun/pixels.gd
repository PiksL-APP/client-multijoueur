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

## Le héros : marche et repos dans les trois orientations dessinées. La gauche
## n'existe pas dans le pack — c'est la droite retournée, ce qui est la
## convention de tous ces kits et divise le nombre d'images par deux.
static func heros() -> SpriteFrames:
	var poses := SpriteFrames.new()
	poses.remove_animation("default")
	var base := "res://modeles/village/"
	for sens in ["down", "side", "up"]:
		ajouter(poses, "marche_" + sens, base + "heros_marche_%s.png" % sens, 10.0)
		ajouter(poses, "repos_" + sens, base + "heros_repos_%s.png" % sens, 6.0)
	return poses

static func personnage_non_joueur(nom: String) -> SpriteFrames:
	var poses := SpriteFrames.new()
	poses.remove_animation("default")
	ajouter(poses, "repos", "res://modeles/village/pnj_%s.png" % nom, 5.0)
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
