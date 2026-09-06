class_name Commandes
extends RefCounted
## Lecture des commandes du joueur, en un seul endroit.
##
## Pourquoi une indirection plutôt que `Input` appelé partout : le banc d'essai
## doit pouvoir jouer une manche sans clavier. Sans ce passage obligé, la seule
## façon de vérifier une partie de bout en bout serait de la jouer à la main,
## et personne ne le fait avant chaque livraison.
##
## Les codes sont PHYSIQUES : W A S D tombent sur Z Q S D d'un clavier AZERTY,
## sans carte d'entrées à configurer.

static var pilote_automatique := false
static var direction_simulee := Vector2.ZERO

static func direction() -> Vector2:
	if pilote_automatique:
		return direction_simulee
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1
	return d.normalized()

## Pour la conduite : x = braquage (-1 à gauche), y = accélération (-1 en
## marche arrière). Non normalisé — accélérer en tournant ne doit pas coûter
## de la vitesse.
static func conduite() -> Vector2:
	if pilote_automatique:
		return direction_simulee
	var braquage := 0.0
	var poussee := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): poussee += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): poussee -= 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): braquage -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): braquage += 1.0
	return Vector2(braquage, poussee)
