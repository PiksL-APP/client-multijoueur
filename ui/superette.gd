extends Control
## LE MENU DE LA SUPÉRETTE : ce qu'on achète à manger et à boire.
##
## C'est le premier VRAI menu du jeu — le menu de triche mis à part, qui est un
## outil. Pourquoi un menu et pas des pastilles au sol comme l'atelier : huit
## articles, chacun avec un prix ET deux effets chiffrés, ça ne tient pas dans
## la ligne d'action du tableau de bord, et huit pastilles sur un trottoir,
## c'est un damier.
##
## ⚠ LA VILLE CONTINUE DE TOURNER DERRIÈRE. C'est du multijoueur : un monde
## figé qui reprend d'un coup à la fermeture saute de trois rues. Le joueur, lui,
## ne bouge plus — c'est `Commandes.saisie` qui ferme ses touches, comme pour le
## menu de triche.
##
## Le dessin suit la charte du reste : tout se peint dans `_draw`, une vingtaine
## de rectangles, pas un arbre de contrôles.

const LARGEUR := 540.0
const LIGNE := 30.0

## Rempli par l'écran de jeu avant chaque redessin.
var articles: Array = []       ## [{cle, nom, prix, effet, couleur, possede}]
var choix := 0
var argent := 0
var poches := 0                ## ce qu'on porte déjà
var poches_max := 0
var message := ""              ## la dernière réponse de la caisse
var message_couleur: Color = Palette.ENCRE_DOUCE

var _rect := Rect2()            ## le cartouche, tel que dessiné — pour le doigt
var _y0 := 0.0                  ## la ligne de base de la première ligne

func _ready() -> void:
	# Le menu prend la souris : au doigt, une ligne se vise puis se valide,
	# et un appui hors du cartouche est un ÉCHAP (`Charte.menu_touche`).
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.pressed \
			and (evenement as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		choix = Charte.menu_touche((evenement as InputEventMouseButton).position, _rect, _y0, articles.size(), LIGNE, choix)
		queue_redraw()
		accept_event()

func _draw() -> void:
	var taille := get_viewport_rect().size
	var hauteur := 170.0 + articles.size() * LIGNE
	# L'ARGENT ET LES POCHES en haut à droite, toujours visibles : ce sont les
	# deux seules raisons pour lesquelles un achat peut être refusé, et les
	# lire APRÈS le refus, c'est une fois de trop.
	var entete := "$%d   ·   %d/%d en poche" % [argent, poches, poches_max]
	var rect := Charte.menu(self, taille, LARGEUR, hauteur, "Supérette", entete, PlanVille.COULEUR_SUPERETTE)
	_rect = rect
	var x := rect.position.x + Charte.MARGE_MENU
	var y := Charte.haut_contenu(rect) + 10.0
	_y0 = y

	for i in articles.size():
		var a: Dictionary = articles[i]
		var vise := i == choix
		var abordable: bool = argent >= int(a.get("prix", 0)) and poches < poches_max
		# Ce qu'on ne peut pas s'offrir reste LISIBLE mais éteint : le griser
		# jusqu'à l'illisibilité, c'est cacher le prix qu'il faut atteindre.
		var couleur: Color = a.get("couleur", Charte.ENCRE_DOUCE)
		if not abordable:
			couleur = Color(couleur, 0.38)
		if vise:
			Charte.ligne_visee(self, Rect2(Vector2(rect.position.x + 10.0, y - 18.0),
				Vector2(rect.size.x - 20.0, LIGNE - 4.0)), couleur if abordable else Charte.ENCRE_FAIBLE)
		# La pastille de couleur devant le nom : c'est elle qu'on retrouve dans
		# l'inventaire du tableau de bord, et c'est ce qui relie les deux.
		draw_circle(Vector2(x + 4.0, y - 5.0), 4.0, couleur)
		Charte.capitales_dessinees(self, Vector2(x + 16.0, y), String(a.get("nom", "")), 14,
			Color.WHITE if vise and abordable else couleur, 0.14)
		var effet := String(a.get("effet", ""))
		Charte.texte_dessine(self, Vector2(x + 220.0, y), effet, 13, Charte.ENCRE_FAIBLE, 0)
		var possede := int(a.get("possede", 0))
		var droite := "$%d" % int(a.get("prix", 0))
		if possede > 0:
			droite = "×%d   %s" % [possede, droite]
		var ld := Charte.largeur_titre(droite, 13)
		Charte.titre_dessine(self, Vector2(rect.end.x - Charte.MARGE_MENU - ld, y), droite, 13,
			Charte.ORANGE if abordable else couleur, 0)
		y += LIGNE

	if message != "":
		var lm := Charte.largeur_texte(message, 14)
		Charte.texte_dessine(self, Vector2(rect.position.x + (rect.size.x - lm) * 0.5, rect.end.y - 44.0),
			message, 14, message_couleur, 0)
	Charte.aide_menu(self, rect, "↑ ↓ choisir · entrée acheter · échap sortir" if not Tactile.actif() else "toucher un article, puis le toucher encore pour l'acheter · hors du cadre : sortir")
