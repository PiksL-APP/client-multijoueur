extends Control
## LE MENU DE LA PLANQUE : le coffre, et les travaux qu'on y paie.
##
## Jusqu'ici le coffre se manœuvrait à l'aveugle : `F` déposait, puis `F`
## achetait « le prochain » travail — sans jamais montrer les trois, ni leurs
## prix, ni ce qu'ils font. On payait cinq mille dollars un garage sans savoir
## ce qu'il gardait. GTA 2 n'a pas de menu de planque, mais il n'a pas non plus
## trois travaux à cinq mille dollars.
##
## Même charte que la supérette (`ui/superette.gd`) : tout se peint dans
## `_draw`, la ville continue derrière, `Commandes.saisie` fige le joueur.
##
## L'ORDRE DES TRAVAUX TIENT : le coffre d'abord, puis l'arsenal, puis le
## garage — un travail se grise tant que le précédent n'est pas fait, et la
## ligne dit lequel. Le menu montre le catalogue, il ne change pas la règle.

const LARGEUR := 560.0
const LIGNE := 34.0

## Rempli par l'écran de jeu avant chaque redessin.
var lignes: Array = []         ## [{cle, nom, effet, prix, etat, couleur}] — etat : "achat", "fait", "apres:<cle>", "depot", "retrait", "rien"
var choix := 0
var argent := 0
var banque := 0
var message := ""
var message_couleur: Color = Charte.ENCRE_DOUCE

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
	var hauteur := 176.0 + lignes.size() * LIGNE
	var entete := "$%d sur soi   ·   $%d au coffre" % [argent, banque]
	var rect := Charte.menu(self, taille, LARGEUR, hauteur, "Chez soi", entete, Charte.ORANGE)
	_rect = rect
	var x := rect.position.x + Charte.MARGE_MENU
	var y := Charte.haut_contenu(rect) + 12.0
	_y0 = y

	for i in lignes.size():
		var l: Dictionary = lignes[i]
		var vise := i == choix
		var etat := String(l.get("etat", "rien"))
		var possible := etat == "achat" or etat == "depot" or etat == "retrait"
		var couleur: Color = l.get("couleur", Charte.ENCRE_DOUCE)
		if not possible:
			couleur = Color(couleur, 0.38)
		if vise:
			Charte.ligne_visee(self, Rect2(Vector2(rect.position.x + 10.0, y - 20.0),
				Vector2(rect.size.x - 20.0, LIGNE - 4.0)), couleur if possible else Charte.ENCRE_FAIBLE)
		draw_circle(Vector2(x + 4.0, y - 6.0), 4.0, couleur)
		Charte.capitales_dessinees(self, Vector2(x + 16.0, y), String(l.get("nom", "")), 14,
			Color.WHITE if vise and possible else couleur, 0.14)
		Charte.texte_dessine(self, Vector2(x + 150.0, y), String(l.get("effet", "")), 13, Charte.ENCRE_FAIBLE, 0)
		# À droite : le prix, ou ce qui tient lieu de prix — « installé », ou
		# le travail à faire avant.
		var droite := ""
		var teinte_d: Color = Charte.ORANGE
		match etat:
			"achat": droite = "$%d" % int(l.get("prix", 0))
			"fait":
				droite = "installé"
				teinte_d = Charte.ENCRE_FAIBLE
			"depot": droite = "→ $%d" % argent
			"retrait": droite = "← $%d" % banque
			"rien":
				droite = "—"
				teinte_d = Charte.ENCRE_FAIBLE
			_:
				if etat.begins_with("apres:"):
					droite = "d'abord : %s" % etat.trim_prefix("apres:")
					teinte_d = Charte.ENCRE_FAIBLE
				elif etat.begins_with("manque:"):
					droite = "il manque $%s" % etat.trim_prefix("manque:")
					teinte_d = Charte.ENCRE_FAIBLE
		var ld := Charte.largeur_titre(droite, 13)
		Charte.titre_dessine(self, Vector2(rect.end.x - Charte.MARGE_MENU - ld, y), droite, 13, teinte_d, 0)
		y += LIGNE

	if message != "":
		var lm := Charte.largeur_texte(message, 14)
		Charte.texte_dessine(self, Vector2(rect.position.x + (rect.size.x - lm) * 0.5, rect.end.y - 44.0),
			message, 14, message_couleur, 0)
	Charte.aide_menu(self, rect, "↑ ↓ choisir · entrée valider · échap sortir" if not Tactile.actif() else "toucher une ligne, puis la toucher encore · hors du cadre : sortir")
