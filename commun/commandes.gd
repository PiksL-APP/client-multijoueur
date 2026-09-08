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

## Vrai pendant qu'on écrit dans un champ (le tchat du village) : les lettres
## vont au texte, pas aux pieds du personnage.
static var saisie := false

static var pilote_automatique := false
static var direction_simulee := Vector2.ZERO
static var tir_simule := false

static func direction() -> Vector2:
	if pilote_automatique:
		return direction_simulee
	if saisie:
		return Vector2.ZERO
	if Tactile.actif() and Tactile.direction != Vector2.ZERO:
		return Tactile.direction_de_marche()
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1
	return d.normalized()

## Tir maintenu : espace, ou le bouton tactile.
static func tir() -> bool:
	if pilote_automatique:
		return tir_simule
	if Tactile.actif() and Tactile.bouton_tenu:
		return true
	return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_CTRL)

## Action ponctuelle : monter dans une voiture, en descendre, décrocher un
## téléphone. Elle se lit au FRONT et non à l'état : une touche maintenue
## ferait sortir et rentrer douze fois par seconde.
##
## ⚠ Un seul appelant par image. Le premier qui interroge consomme le front,
## le second ne voit rien — c'est l'écran de jeu, et lui seul, qui l'appelle.
static var action_simulee := false
static var _action_avant := false

static func action_tenue() -> bool:
	if pilote_automatique:
		return action_simulee
	if Tactile.actif() and Tactile.bouton_action_tenu:
		return true
	return Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER)

static func action_declenchee() -> bool:
	var maintenant := action_tenue()
	var front := maintenant and not _action_avant
	_action_avant = maintenant
	return front

## L'AFFAIRE : F. Acheter une planque, y déposer son argent, l'améliorer, se
## faire soigner — tout ce qui se traite avec de l'argent passe par cette
## touche, jamais par l'action (E) qui sert à monter en voiture.
static var affaire_simulee := false
static var _affaire_avant := false

static func affaire_tenue() -> bool:
	if pilote_automatique:
		return affaire_simulee
	return Input.is_physical_key_pressed(KEY_F)

static func affaire_declenchee() -> bool:
	var maintenant := affaire_tenue()
	var front := maintenant and not _affaire_avant
	_affaire_avant = maintenant
	return front

## Le klaxon : H, ou le bouton d'action tenu au volant plus d'un instant.
## Tenu, pas déclenché : un klaxon se module.
static var klaxon_simule := false

static func klaxon() -> bool:
	if pilote_automatique:
		return klaxon_simule
	return Input.is_physical_key_pressed(KEY_H)

## La carte de la ville : TAB tenu. Tenue, pas déclenchée — on la consulte
## d'un coup d'œil et on la lâche, comme dans GTA 2.
static var carte_simulee := false

static func carte() -> bool:
	if pilote_automatique:
		return carte_simulee
	return Input.is_physical_key_pressed(KEY_TAB)

## Pour la conduite : x = braquage (-1 à gauche), y = accélération (-1 en
## marche arrière). Non normalisé — accélérer en tournant ne doit pas coûter
## de la vitesse.
static func conduite() -> Vector2:
	if pilote_automatique:
		return direction_simulee
	if Tactile.actif() and Tactile.direction != Vector2.ZERO:
		return Tactile.direction_de_conduite()
	var braquage := 0.0
	var poussee := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): poussee += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): poussee -= 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): braquage -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): braquage += 1.0
	return Vector2(braquage, poussee)
