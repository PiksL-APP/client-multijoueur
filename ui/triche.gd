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

const LARGEUR := 520.0
const LIGNE := 24.0

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
	# La seconde fournée. Chacun sert à VOIR quelque chose qui demande sinon
	# vingt minutes de jeu : les provisions pleines pour regarder les jauges
	# remonter, un repaire pris pour voir le tag changer de camp, le train
	# pour ne pas l'attendre au bord de la voie.
	{"cle": "garde_manger", "nom": "GARDE-MANGER — poches et frigo pleins", "unique": true},
	{"cle": "festin", "nom": "FESTIN — faim et soif au maximum", "unique": true},
	{"cle": "flotte", "nom": "LA FLOTTE — une voiture de gang armée sous soi", "unique": true},
	{"cle": "clefs", "nom": "LES CLEFS DE LA VILLE — tous les repaires à vous", "unique": true},
	{"cle": "express", "nom": "L'EXPRESS — le train s'arrête ici", "unique": true},
	{"cle": "immobilier", "nom": "L'IMMOBILIER — la planque et ses trois améliorations", "unique": true},
	{"cle": "fantome", "nom": "FANTÔME — la police vous oublie", "unique": false},
	{"cle": "meteo", "nom": "MÉTÉO — le temps suivant, à chaque allumage", "unique": false},
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
	var hauteur := 116.0 + codes.size() * LIGNE
	# Un voile sur toute la ville : le menu est une PAUSE de l'attention, même
	# si la manche continue de tourner derrière.
	var rect := Charte.menu(self, taille, LARGEUR, hauteur, "Triche", "la manche ne comptera pas", Charte.ROSE)
	var x := rect.position.x + Charte.MARGE_MENU
	var y := Charte.haut_contenu(rect) + 8.0

	for i in codes.size():
		var code: Dictionary = codes[i]
		var vise := i == choix
		var actif := bool(code.get("actif", false))
		var couleur: Color = Charte.VERT if actif else Charte.ENCRE_DOUCE
		if vise:
			# La ligne visée est surlignée ET barrée de rose : à la manette
			# comme au clavier, une simple couleur se perd sur un fond de ville.
			Charte.ligne_visee(self, Rect2(Vector2(rect.position.x + 10.0, y - 16.0),
				Vector2(rect.size.x - 20.0, LIGNE - 3.0)))
		Charte.texte_dessine(self, Vector2(x, y), String(code.get("nom", "")), 14,
			Color.WHITE if vise else couleur, 0)
		var etat := ""
		if bool(code.get("unique", false)):
			etat = "fait" if actif else ""
		else:
			etat = "on" if actif else "off"
		var le := Charte.largeur_capitales(etat, 11, 0.16)
		Charte.capitales_dessinees(self, Vector2(rect.end.x - Charte.MARGE_MENU - le, y), etat, 11, couleur, 0.16)
		y += LIGNE

	Charte.aide_menu(self, rect, "↑ ↓ choisir · entrée activer · échap fermer")
