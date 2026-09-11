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

const LARGEUR := 520.0
const LIGNE := 28.0

## Rempli par l'écran de jeu avant chaque redessin.
var articles: Array = []       ## [{cle, nom, prix, effet, couleur, possede}]
var choix := 0
var argent := 0
var poches := 0                ## ce qu'on porte déjà
var poches_max := 0
var message := ""              ## la dernière réponse de la caisse
var message_couleur: Color = Palette.ENCRE_DOUCE

func _draw() -> void:
	var taille := get_viewport_rect().size
	# ⚠ 120 NE SUFFISAIT PAS : l'en-tête prend 56 px, et il reste la réponse de
	# la caisse ET la ligne d'aide à loger sous la liste. Le cartouche coupait
	# les deux en deux — on voyait le haut des lettres et rien d'autre.
	var hauteur := 152.0 + articles.size() * LIGNE
	var rect := Rect2(Vector2((taille.x - LARGEUR) * 0.5, (taille.y - hauteur) * 0.5),
		Vector2(LARGEUR, hauteur))
	draw_rect(Rect2(Vector2.ZERO, taille), Color(0, 0, 0, 0.55), true)
	UI.cartouche(self, rect, PlanVille.COULEUR_SUPERETTE)
	var x := rect.position.x + UI.ACCENT + 16.0
	var y := rect.position.y + 30.0
	draw_string(UI.TITRE_POLICE, Vector2(x, y), "SUPÉRETTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		PlanVille.COULEUR_SUPERETTE)
	# L'ARGENT ET LES POCHES en haut à droite, toujours visibles : ce sont les
	# deux seules raisons pour lesquelles un achat peut être refusé, et les
	# lire APRÈS le refus, c'est une fois de trop.
	var entete := "$%d   ·   %d/%d en poche" % [argent, poches, poches_max]
	var le := UI.TEXTE_POLICE.get_string_size(entete, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(UI.TEXTE_POLICE, Vector2(rect.end.x - 16.0 - le, y), entete,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Palette.AVERTISSEMENT if poches >= poches_max else Palette.ENCRE_DOUCE)
	y += 26.0

	for i in articles.size():
		var a: Dictionary = articles[i]
		var vise := i == choix
		var abordable: bool = argent >= int(a.get("prix", 0)) and poches < poches_max
		# Ce qu'on ne peut pas s'offrir reste LISIBLE mais éteint : le griser
		# jusqu'à l'illisibilité, c'est cacher le prix qu'il faut atteindre.
		var couleur: Color = a.get("couleur", Palette.ENCRE_DOUCE)
		if not abordable:
			couleur = couleur.darkened(0.45).lerp(Palette.ENCRE_FAIBLE, 0.5)
		if vise:
			draw_rect(Rect2(Vector2(rect.position.x + UI.ACCENT + 6.0, y - 13.0),
				Vector2(rect.size.x - UI.ACCENT - 22.0, LIGNE - 4.0)), Color(couleur, 0.16), true)
			draw_string(UI.TEXTE_POLICE, Vector2(x - 10.0, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, couleur)
		# La pastille de couleur devant le nom : c'est elle qu'on retrouve dans
		# l'inventaire du tableau de bord, et c'est ce qui relie les deux.
		draw_circle(Vector2(x + 4.0, y - 4.0), 4.0, couleur)
		draw_string(UI.TEXTE_POLICE, Vector2(x + 16.0, y), String(a.get("nom", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, couleur)
		var effet := String(a.get("effet", ""))
		draw_string(UI.TEXTE_POLICE, Vector2(x + 216.0, y), effet,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_FAIBLE)
		var possede := int(a.get("possede", 0))
		var droite := "$%d" % int(a.get("prix", 0))
		if possede > 0:
			droite = "×%d   %s" % [possede, droite]
		var ld := UI.TEXTE_POLICE.get_string_size(droite, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(UI.TEXTE_POLICE, Vector2(rect.end.x - 16.0 - ld, y), droite,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, couleur)
		y += LIGNE

	if message != "":
		var lm := UI.TEXTE_POLICE.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(UI.TEXTE_POLICE, Vector2(rect.position.x + (rect.size.x - lm) * 0.5, rect.end.y - 46.0),
			message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, message_couleur)
	var aide := "↑ ↓ choisir · ENTRÉE acheter · ÉCHAP sortir"
	var la := UI.TEXTE_POLICE.get_string_size(aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(UI.TEXTE_POLICE, Vector2(rect.position.x + (rect.size.x - la) * 0.5, rect.end.y - 22.0),
		aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.ENCRE_FAIBLE)
