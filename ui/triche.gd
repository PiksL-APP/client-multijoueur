extends Control
## LE MENU DE TRICHE, ouvert par le code Konami (↑ ↑ ↓ ↓ ← → ← → B A).
##
## C'est un clin d'œil autant qu'un outil : la moitié des tricheurs de GTA 2
## n'ont jamais fini le jeu autrement, et pour nous c'est surtout la façon la
## plus rapide de VOIR une mécanique — six étoiles, un char, l'atelier complet
## — sans jouer vingt minutes pour y arriver.
##
## ⚠ IL COÛTE LE CLASSEMENT. Dès qu'un code est activé, la manche n'est plus
## déposée en base pour ce joueur (`Partie.tricheurs`). Sans cette règle, le
## tableau des scores ne veut plus rien dire, et un tableau qui ne veut rien
## dire, autant l'enlever.
##
## Le dessin suit la charte du reste : tout se peint dans `_draw`, comme le
## tableau de bord — une quinzaine de rectangles, pas un arbre de contrôles.

const LARGEUR := 460.0
const LIGNE := 26.0

## LE CATALOGUE. Il vit ICI et pas dans l'écran de jeu : le menu le dessine, le
## banc d'image le photographie, et Carnage en fait une copie de travail
## (`_codes_de_triche`) où il coche ce qui est actif. Une seule liste, trois
## lecteurs — sinon le banc photographie des codes que le jeu n'a pas.
##
## `unique` : un coup qu'on rejoue autant qu'on veut (le magot) plutôt qu'un
## interrupteur qu'on rallume (le blindage).
const CODES := [
	{"cle": "blindage", "nom": "BLINDAGE — on ne vous touche plus", "unique": false},
	{"cle": "arsenal", "nom": "ARSENAL — roquettes pleines", "unique": true},
	{"cle": "magot", "nom": "LE MAGOT — $50 000", "unique": true},
	{"cle": "casier", "nom": "CASIER VIERGE — plus recherché", "unique": true},
	{"cle": "traque", "nom": "TOUTE LA VILLE VOUS CHERCHE — six étoiles", "unique": true},
	{"cle": "atelier", "nom": "ATELIER COMPLET — tout sous le capot", "unique": true},
	{"cle": "ami", "nom": "AMI DE TOUS — respect au maximum", "unique": true},
	{"cle": "ennemi", "nom": "ENNEMI PUBLIC — respect à zéro", "unique": true},
	{"cle": "char", "nom": "L'ARMÉE ARRIVE — un char pour vous", "unique": true},
	{"cle": "nuit", "nom": "NUIT NOIRE — l'heure s'arrête", "unique": false},
]

## Une copie de travail : le menu y coche ce qui est allumé, sans toucher au
## catalogue (une constante de dictionnaires se modifie en Godot, et se
## modifierait pour toute la session).
static func codes_neufs() -> Array:
	var liste: Array = []
	for c in CODES:
		liste.append({"cle": String(c["cle"]), "nom": String(c["nom"]),
			"unique": bool(c["unique"]), "actif": false})
	return liste

var codes: Array = []          ## [{nom, mot, actif, unique}] — rempli par le jeu
var choix := 0
var temps := 0.0

func _draw() -> void:
	var taille := get_viewport_rect().size
	var hauteur := 96.0 + codes.size() * LIGNE
	var rect := Rect2(Vector2((taille.x - LARGEUR) * 0.5, (taille.y - hauteur) * 0.5),
		Vector2(LARGEUR, hauteur))
	# Un voile sur toute la ville : le menu est une PAUSE de l'attention, même
	# si la manche continue de tourner derrière.
	draw_rect(Rect2(Vector2.ZERO, taille), Color(0, 0, 0, 0.55), true)
	UI.cartouche(self, rect, Palette.CRITIQUE)
	var x := rect.position.x + UI.ACCENT + 16.0
	var y := rect.position.y + 30.0
	draw_string(UI.TITRE_POLICE, Vector2(x, y), "TRICHE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.CRITIQUE)
	var mot := "la manche ne comptera pas"
	var lm := UI.TEXTE_POLICE.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(UI.TEXTE_POLICE, Vector2(rect.end.x - 16.0 - lm, y), mot,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.AVERTISSEMENT)
	y += 22.0

	for i in codes.size():
		var code: Dictionary = codes[i]
		var vise := i == choix
		var couleur: Color = Palette.ENCRE_DOUCE
		if bool(code.get("actif", false)):
			couleur = Palette.BON
		if vise:
			# La ligne visée est surlignée ET fléchée : à la manette comme au
			# clavier, une simple couleur se perd sur un fond de ville.
			draw_rect(Rect2(Vector2(rect.position.x + UI.ACCENT + 6.0, y - 12.0),
				Vector2(rect.size.x - UI.ACCENT - 22.0, LIGNE - 4.0)), Color(couleur, 0.16), true)
			draw_string(UI.TEXTE_POLICE, Vector2(x - 10.0, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, couleur)
		draw_string(UI.TEXTE_POLICE, Vector2(x + 6.0, y), String(code.get("nom", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, couleur)
		var etat := ""
		if bool(code.get("unique", false)):
			etat = "fait" if bool(code.get("actif", false)) else ""
		else:
			etat = "ON" if bool(code.get("actif", false)) else "off"
		var le := UI.TEXTE_POLICE.get_string_size(etat, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(UI.TEXTE_POLICE, Vector2(rect.end.x - 16.0 - le, y), etat,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, couleur)
		y += LIGNE

	# La ligne d'aide, en bas du cartouche.
	var aide := "↑ ↓ choisir · ENTRÉE activer · ÉCHAP fermer"
	var la := UI.TEXTE_POLICE.get_string_size(aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(UI.TEXTE_POLICE, Vector2(rect.position.x + (rect.size.x - la) * 0.5, rect.end.y - 14.0),
		aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.ENCRE_FAIBLE)
