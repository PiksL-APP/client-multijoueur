extends Control
## LE MENU DE PAUSE — et surtout la SORTIE D'UNE MANCHE.
##
## Carnage n'a pas de chrono : on reste en ville tant qu'on veut. C'est ce qui
## fait le jeu, et c'est aussi ce qui lui a fait perdre sa fin le jour où le hub
## et l'écran de résultats ont disparu : `Partie.terminer()` n'était plus appelé
## de nulle part. Une manche ne se terminait donc JAMAIS — ni retour au salon,
## ni classement, ni dépôt du score en base. Ce menu est la sortie.
##
## ⚠ LA VILLE CONTINUE DE TOURNER DERRIÈRE, comme pour la triche et la
## supérette : c'est du multijoueur, on ne met pas trois autres joueurs en pause
## pour lire deux lignes. Seul le joueur qui lit est figé (`Commandes.saisie`).
##
## Le dessin suit la charte du reste : tout se peint dans `_draw`.

const LARGEUR := 440.0
const LIGNE := 34.0

## Quatre lignes : reprendre, la fiche des touches, la souris, quitter. On
## avait dit deux — « un menu de pause se lit sans lire » — et c'est encore
## vrai : la fiche des touches n'est pas un choix qu'on hésite à faire, c'est
## ce qu'on vient chercher quand on ne sait plus quelle touche fait quoi, et
## c'est PRÉCISÉMENT dans la pause qu'on le cherche. La souris, c'est pareil :
## sa sensibilité se juge en vue subjective, pas dans un menu d'accueil, et
## la ligne se règle sur place (← →) sans quitter la ville.
var lignes: Array = []          ## [{texte, detail, couleur}] — rempli par le jeu
var choix := 0
var titre := "PAUSE"
var sous_titre := ""

var _rect := Rect2()            ## le cartouche, tel que dessiné — pour le doigt
var _y0 := 0.0                  ## la ligne de base de la première ligne

func _ready() -> void:
	# Le menu prend la souris : au doigt, une ligne se vise puis se valide,
	# et un appui hors du cartouche est un ÉCHAP (`Charte.menu_touche`).
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.pressed \
			and (evenement as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		choix = Charte.menu_touche((evenement as InputEventMouseButton).position, _rect, _y0, lignes.size(), LIGNE, choix)
		queue_redraw()
		accept_event()

func _draw() -> void:
	var taille := get_viewport_rect().size
	var hauteur := 118.0 + lignes.size() * LIGNE
	var rect := Charte.menu(self, taille, LARGEUR, hauteur, titre, sous_titre)
	_rect = rect
	var x := rect.position.x + Charte.MARGE_MENU
	var y := Charte.haut_contenu(rect) + 14.0
	_y0 = y

	for i in lignes.size():
		var l: Dictionary = lignes[i]
		var vise := i == choix
		var couleur: Color = l.get("couleur", Charte.ENCRE_DOUCE)
		if vise:
			Charte.ligne_visee(self, Rect2(Vector2(rect.position.x + 10.0, y - 20.0),
				Vector2(rect.size.x - 20.0, LIGNE - 4.0)), couleur)
		Charte.capitales_dessinees(self, Vector2(x, y), String(l.get("texte", "")), 15,
			Color.WHITE if vise else couleur, 0.18)
		# LE DÉTAIL est à droite, en petit : « la manche s'arrête pour la table »
		# n'est pas une décoration, c'est ce qu'on a besoin de savoir AVANT
		# d'appuyer, et pas après.
		var detail := String(l.get("detail", ""))
		if detail != "":
			var ld := Charte.largeur_texte(detail, 13)
			Charte.texte_dessine(self, Vector2(rect.end.x - Charte.MARGE_MENU - ld, y), detail, 13, Charte.ENCRE_FAIBLE, 0)
		y += LIGNE

	Charte.aide_menu(self, rect, "↑ ↓ choisir · entrée valider · échap reprendre" if not Tactile.actif() else "toucher une ligne, puis la toucher encore · hors du cadre : reprendre")
