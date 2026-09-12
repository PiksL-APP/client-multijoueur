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
## sans carte d'entrées à configurer. Ils viennent tous de `Reglages`, où le
## joueur peut les réattribuer depuis l'écran des options ; les flèches, elles,
## restent câblées en second sur les déplacements — c'est un repli universel.

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
	if Reglages.enfoncee("avancer") or Input.is_key_pressed(KEY_UP): d.y -= 1
	if Reglages.enfoncee("reculer") or Input.is_key_pressed(KEY_DOWN): d.y += 1
	if Reglages.enfoncee("gauche") or Input.is_key_pressed(KEY_LEFT): d.x -= 1
	if Reglages.enfoncee("droite") or Input.is_key_pressed(KEY_RIGHT): d.x += 1
	return d.normalized()

## Tir maintenu : espace, ou le bouton tactile.
static func tir() -> bool:
	if pilote_automatique:
		return tir_simule
	if Tactile.actif() and Tactile.bouton_tenu:
		return true
	return Reglages.enfoncee("tir") or Input.is_key_pressed(KEY_CTRL)

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
	# ⚠ `saisie` ferme AUSSI cette touche depuis le menu de triche. Elle ne
	# fermait que les déplacements et le tir, parce qu'elle n'avait servi qu'au
	# tchat du village : la touche ENTRÉE qui valide une ligne du menu ouvrait
	# donc la portière de la voiture en même temps.
	if saisie:
		return false
	if Tactile.actif() and Tactile.bouton_action_tenu:
		return true
	return Reglages.enfoncee("action") or Input.is_key_pressed(KEY_ENTER)

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
	if saisie:
		return false
	if Tactile.actif() and Tactile.bouton_affaire_tenu:
		return true
	return Reglages.enfoncee("affaire")

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
	if saisie:
		return false
	if Tactile.actif() and Tactile.bouton_klaxon_tenu:
		return true
	return Reglages.enfoncee("klaxon")

## La carte de la ville : TAB, ou le bouton CARTE du pavé tactile. On rend
## l'ÉTAT de la touche ; c'est l'écran de jeu qui en lit le front et bascule
## la carte — ouverte, elle reste ouverte, on ne conduit pas un pouce sur TAB.
static var carte_simulee := false

static func carte() -> bool:
	if pilote_automatique:
		return carte_simulee
	if saisie:
		return false
	if Tactile.actif() and Tactile.bouton_carte_tenu:
		return true
	return Reglages.enfoncee("carte")

## LES TOUCHES VIRTUELLES : un doigt qui tape une ligne de menu, ou le bouton
## PAUSE du pavé tactile, « appuie » sur ENTRÉE ou ÉCHAP. Les menus lisent le
## clavier au front (`_front_de_triche` dans l'écran de jeu) ; plutôt que de
## leur apprendre la souris un par un, on leur fait croire à une touche —
## tenue deux images, le temps qu'un front soit vu quel que soit l'ordre des
## lectures (l'entrée arrive avant `_process`, jamais après).
static var _virtuelles := {}          ## code → image de l'appui

static func appuyer(code: int) -> void:
	_virtuelles[code] = Engine.get_process_frames()

static func virtuelle(code: int) -> bool:
	if not _virtuelles.has(code):
		return false
	var depuis := Engine.get_process_frames() - int(_virtuelles[code])
	return depuis >= 0 and depuis <= 1

## Une touche de menu, physique ou virtuelle.
static func touche_menu(code: int) -> bool:
	return Input.is_key_pressed(code) or virtuelle(code)

## LE CODE KONAMI : ↑ ↑ ↓ ↓ ← → ← → B A.
##
## Il ouvre le menu de triche (`ui/triche.gd`). Pourquoi ici plutôt que dans
## l'écran de jeu : c'est une LECTURE DE COMMANDES, et ce fichier est le seul
## endroit du projet qui a le droit d'interroger `Input`.
##
## ⚠ B et A se lisent par CODE DE TOUCHE et non par code physique, à l'inverse
## de tout le reste du fichier : le joueur tape les lettres IMPRIMÉES sur son
## clavier. Sur un AZERTY, la touche physique « A » est le Q — celui qui fait
## le code Konami sur un clavier français appuie sur la touche marquée A, pas
## sur celle qui serait A en QWERTY.
##
## Les flèches conduisent la voiture en même temps. C'est voulu : on entre le
## code en roulant, comme dans les GTA d'alors, et ça fait partie du plaisir.
const KONAMI := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
const KONAMI_DELAI := 2.5     ## secondes entre deux touches avant d'oublier
static var _konami_pas := 0
static var _konami_tenue := 0
static var _konami_reste := 0.0

## Renvoie vrai UNE FOIS, à l'image où le code s'achève.
static func konami(delta: float) -> bool:
	if pilote_automatique:
		return false
	_konami_reste = max(0.0, _konami_reste - delta)
	if _konami_reste == 0.0 and _konami_pas > 0:
		# Trop lent : on oublie. Sans ce délai, un code entamé il y a deux
		# minutes se terminerait tout seul en conduisant.
		_konami_pas = 0
	# La touche du moment : la PREMIÈRE du code qui est enfoncée. On ne lit
	# que ces six touches-là — inutile de balayer le clavier.
	var enfoncee := 0
	for code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]:
		if Input.is_key_pressed(code):
			enfoncee = code
			break
	if enfoncee == _konami_tenue:
		return false          # rien de neuf : la même touche est tenue
	_konami_tenue = enfoncee
	if enfoncee == 0:
		return false          # on a simplement relâché
	if enfoncee != int(KONAMI[_konami_pas]):
		# Faux pas. On repart de zéro — mais une flèche haut relance le code
		# à son deuxième cran, sinon « ↑ ↑ » tapé trois fois n'aboutit jamais.
		_konami_pas = 1 if enfoncee == int(KONAMI[0]) else 0
		_konami_reste = KONAMI_DELAI if _konami_pas > 0 else 0.0
		return false
	_konami_pas += 1
	_konami_reste = KONAMI_DELAI
	if _konami_pas < KONAMI.size():
		return false
	_konami_pas = 0
	_konami_reste = 0.0
	return true

## LA RADIO : R, au front. Une station se choisit, elle ne se module pas —
## tenue, la touche ferait défiler les six stations en une seconde.
static var radio_simulee := false
static var _radio_avant := false

## ⚠ Pas de garde `saisie` ici, contrairement aux autres touches : la roue des
## stations SE TIENT, et c'est elle qui met `saisie` pendant qu'elle est
## ouverte. Coupée par son propre effet, elle se refermait à l'image suivante.
static func radio_tenue() -> bool:
	if pilote_automatique:
		return radio_simulee
	return Reglages.enfoncee("radio")

static func radio_declenchee() -> bool:
	var maintenant := radio_tenue()
	var front := maintenant and not _radio_avant
	_radio_avant = maintenant
	return front

## MANGER : G. Comme l'affaire, elle se DÉCLENCHE (un appui, un article) et
## elle est fermée pendant une saisie — sinon taper « gratin » dans le tchat
## viderait les poches.
static var manger_simulee := false
static var _manger_avant := false

static func manger_tenue() -> bool:
	if pilote_automatique:
		return manger_simulee
	if saisie:
		return false
	if Tactile.actif() and Tactile.bouton_manger_tenu:
		return true
	return Reglages.enfoncee("manger")

static func manger_declenchee() -> bool:
	var maintenant := manger_tenue()
	var front := maintenant and not _manger_avant
	_manger_avant = maintenant
	return front

## LA VUE : V. Comme les autres, elle se déclenche et se tait pendant une
## saisie — basculer la caméra depuis un menu de pause n'aurait aucun sens.
static var vue_simulee := false
static var _vue_avant := false

static func vue_tenue() -> bool:
	if pilote_automatique:
		return vue_simulee
	if saisie:
		return false
	return Reglages.enfoncee("vue")

static func vue_declenchee() -> bool:
	var maintenant := vue_tenue()
	var front := maintenant and not _vue_avant
	_vue_avant = maintenant
	return front

## Pour la conduite : x = braquage (-1 à gauche), y = accélération (-1 en
## marche arrière). Non normalisé — accélérer en tournant ne doit pas coûter
## de la vitesse.
static func conduite() -> Vector2:
	if pilote_automatique:
		return direction_simulee
	# ⚠ `saisie` coupe AUSSI le volant : c'est ce qui permet à la roue des
	# stations de se viser aux flèches sans envoyer la voiture dans le
	# trottoir. La voiture ne freine pas pour autant — elle roule sur son élan,
	# et c'est très bien ainsi : on n'ouvre pas un menu au milieu d'un virage.
	if saisie:
		return Vector2.ZERO
	if Tactile.actif() and Tactile.direction != Vector2.ZERO:
		return Tactile.direction_de_conduite()
	var braquage := 0.0
	var poussee := 0.0
	if Reglages.enfoncee("avancer") or Input.is_key_pressed(KEY_UP): poussee += 1.0
	if Reglages.enfoncee("reculer") or Input.is_key_pressed(KEY_DOWN): poussee -= 1.0
	if Reglages.enfoncee("gauche") or Input.is_key_pressed(KEY_LEFT): braquage -= 1.0
	if Reglages.enfoncee("droite") or Input.is_key_pressed(KEY_RIGHT): braquage += 1.0
	return Vector2(braquage, poussee)
