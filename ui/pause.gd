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

const LARGEUR := 420.0
const LIGNE := 30.0

## Les deux seules choses qu'on puisse vouloir ici. Trois lignes, et il faudrait
## déjà se demander laquelle on visait — un menu de pause se lit sans lire.
var lignes: Array = []          ## [{texte, detail, couleur}] — rempli par le jeu
var choix := 0
var titre := "PAUSE"
var sous_titre := ""

func _draw() -> void:
	var taille := get_viewport_rect().size
	var hauteur := 104.0 + lignes.size() * LIGNE
	var rect := Rect2(Vector2((taille.x - LARGEUR) * 0.5, (taille.y - hauteur) * 0.5),
		Vector2(LARGEUR, hauteur))
	draw_rect(Rect2(Vector2.ZERO, taille), Color(0, 0, 0, 0.62), true)
	UI.cartouche(self, rect, Palette.SERIE)
	var x := rect.position.x + UI.ACCENT + 16.0
	var y := rect.position.y + 32.0
	draw_string(UI.TITRE_POLICE, Vector2(x, y), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.SERIE)
	if sous_titre != "":
		var ls := UI.TEXTE_POLICE.get_string_size(sous_titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(UI.TEXTE_POLICE, Vector2(rect.end.x - 16.0 - ls, y), sous_titre,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_FAIBLE)
	y += 30.0

	for i in lignes.size():
		var l: Dictionary = lignes[i]
		var vise := i == choix
		var couleur: Color = l.get("couleur", Palette.ENCRE_DOUCE)
		if vise:
			draw_rect(Rect2(Vector2(rect.position.x + UI.ACCENT + 6.0, y - 14.0),
				Vector2(rect.size.x - UI.ACCENT - 22.0, LIGNE - 4.0)), Color(couleur, 0.18), true)
			draw_string(UI.TEXTE_POLICE, Vector2(x - 10.0, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, couleur)
		draw_string(UI.TEXTE_POLICE, Vector2(x + 6.0, y), String(l.get("texte", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, couleur)
		# LE DÉTAIL est à droite, en petit : « la manche s'arrête pour la table »
		# n'est pas une décoration, c'est ce qu'on a besoin de savoir AVANT
		# d'appuyer, et pas après.
		var detail := String(l.get("detail", ""))
		if detail != "":
			var ld := UI.TEXTE_POLICE.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(UI.TEXTE_POLICE, Vector2(rect.end.x - 16.0 - ld, y), detail,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.ENCRE_FAIBLE)
		y += LIGNE

	var aide := "↑ ↓ choisir · ENTRÉE valider · ÉCHAP reprendre"
	var la := UI.TEXTE_POLICE.get_string_size(aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(UI.TEXTE_POLICE, Vector2(rect.position.x + (rect.size.x - la) * 0.5, rect.end.y - 20.0),
		aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.ENCRE_FAIBLE)
