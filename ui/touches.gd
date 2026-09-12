extends Control
## LA FICHE DES TOUCHES — depuis le menu de pause (ÉCHAP → LES TOUCHES).
##
## La ligne d'aide en bas de l'écran ne montre que six touches, et la ligne du
## HUD ne dit que l'affaire du moment. Tout le reste — le détonateur, la roue
## des stations, ce que fait `F` chez soi, la lance du camion de pompiers — on
## le découvrait en appuyant au hasard, ou jamais. Cette fiche dit TOUT, en
## trois colonnes : ce qui vaut partout, à pied, au volant.
##
## ⚠ LES TOUCHES SONT LUES DANS LES RÉGLAGES, jamais écrites en dur : un joueur
## qui a remis « avancer » sur la flèche haut dans les options lit sa flèche
## ici, pas un « Z » qui ne fait plus rien. Et `Reglages.nom_de_touche` rend le
## nom GRAVÉ sur son clavier — « Z » sur un AZERTY là où le moteur dit « W ».
##
## La ville continue derrière, comme pour la pause : c'est du multijoueur.

const LARGEUR := 900.0
const LIGNE := 26.0

## Les trois colonnes : [titre, couleur, [[touche, action], …]]. Une touche est
## soit un nom d'action des réglages (`t:avancer`), soit un libellé littéral.
func _colonnes() -> Array:
	if Tactile.actif():
		return _colonnes_tactiles()
	return [
		["PARTOUT", Charte.ORANGE, [
			["Échap", "la pause, et la sortie de la ville"],
			["t:carte", "la carte : molette pour zoomer, clic pour un GPS, clic sur un lieu pour y aller"],
			["t:vue", "la vue subjective — la souris regarde, on marche là où l'on regarde — et retour ; sa vitesse : ligne LA SOURIS de la pause, ou les options"],
			["t:manger", "manger ou boire ce qui manque le plus"],
			["t:tchat", "parler à la table"],
			["↑ ↓  Entrée", "choisir et valider dans un menu"],
			["M", "couper ou remettre le son"],
		]],
		["À PIED", Charte.VERT, [
			["t:avancer|t:reculer", "marcher, reculer"],
			["t:gauche|t:droite", "tourner"],
			["t:tir", "tirer avec l'arme en main"],
			["t:action", "monter dans une voiture — ou dans le train, à quai"],
			["t:affaire", "l'affaire du lieu : cabine, planque, hôpital, repaire, tag, casse"],
			["t:klaxon", "le DÉTONATEUR des voitures piégées à l'atelier"],
			["t:affaire", "chez soi : le coffre, la garde-robe, la porte ; au repaire : le râtelier, le patron"],
			["t:action", "chez soi : retirer tout du coffre, d'un coup"],
		]],
		["AU VOLANT", Charte.ROSE, [
			["t:avancer|t:reculer", "accélérer, freiner et reculer"],
			["t:gauche|t:droite", "tourner"],
			["t:tir", "la mitrailleuse de bord (atelier) — camion de pompiers : ARROSER"],
			["t:action", "descendre — la bombe de l'atelier s'arme en descendant"],
			["t:affaire", "garage, atelier, supérette, taxi (prendre, déposer) — sinon larguer mine ou huile"],
			["t:affaire", "camion de pompiers : basculer la lance eau / feu (avec le lance-flammes)"],
			["t:klaxon", "klaxonner : les passants s'écartent"],
			["t:radio", "la roue des stations — tenue, on pousse dans une direction"],
		]],
	]

## LA MÊME FICHE AU DOIGT : pas une touche, pas un « M » — le manche, les
## ronds et l'éventail du menu ≡, tels qu'ils sont à l'écran. Un joueur sur
## téléphone qui lirait « Z : avancer » chercherait un clavier.
func _colonnes_tactiles() -> Array:
	return [
		["PARTOUT", Charte.ORANGE, [
			["≡", "le menu : carte, sac, radio, son, pause"],
			["≡ CARTE", "pincer ou − + : zoom · toucher un lieu : GPS · ✕ : fermer"],
			["≡ SAC", "manger ou boire ce qu'on a en poche"],
			["≡ PAUSE", "la pause, et la sortie de la ville"],
			["toucher", "un menu : une ligne pour viser, encore pour valider"],
		]],
		["À PIED", Charte.VERT, [
			["manche", "à gauche, n'importe où : marcher"],
			["TIR", "tirer avec l'arme en main"],
			["ENTRER", "monter en voiture — ou dans le train à quai"],
			["AFFAIRE", "surgit quand il y a quelque chose à faire ici"],
			["≡ BOUM", "faire sauter la voiture piégée"],
		]],
		["AU VOLANT", Charte.ROSE, [
			["manche", "haut : accélérer · bas : freiner · côtés : tourner"],
			["TIR", "la mitrailleuse (atelier) — pompiers : arroser"],
			["SORTIR", "descendre — la bombe s'arme en descendant"],
			["AFFAIRE", "garage, atelier, supérette, taxi — sinon mine ou huile"],
			["≡ KLAXON", "tenu : les passants s'écartent"],
			["≡ RADIO", "la station suivante"],
		]],
	]

func _ready() -> void:
	# Au doigt, n'importe quel appui referme la fiche — et il ne passe pas
	# au menu de pause qu'elle couvre.
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.pressed:
		Commandes.appuyer(KEY_ENTER)
		accept_event()

func _draw() -> void:
	var taille := get_viewport_rect().size
	var colonnes := _colonnes()
	var largeur := minf(LARGEUR, taille.x - 40.0)
	# La hauteur se MESURE : une action qui se coupe sur deux lignes prend
	# deux lignes, et un cartouche calculé au nombre d'entrées débordait au
	# doigt, où les descriptions sont plus longues que « tourner ».
	var pas := (largeur - 2.0 * Charte.MARGE_MENU) / float(colonnes.size())
	var plus_haute := 0.0
	for c in colonnes:
		var h := 0.0
		for ligne in c[2]:
			var l: Array = ligne
			h += LIGNE + 14.0 * float(_lignes_coupees(String(l[1]), pas - 24.0 - _largeur_touches(String(l[0]))).size() - 1)
		plus_haute = maxf(plus_haute, h)
	# 88 px de tête (titre, filet), les colonnes, 44 px pour la ligne d'aide.
	var hauteur := minf(88.0 + 34.0 + plus_haute + 44.0, taille.y - 16.0)
	var rect := Charte.menu(self, taille, largeur, hauteur, "Les commandes" if Tactile.actif() else "Les touches",
		"le manche et les boutons du pavé" if Tactile.actif()
		else "les noms sont ceux de votre clavier — touches et souris se changent dans les options de l'accueil")
	var x0 := rect.position.x + Charte.MARGE_MENU
	var y0 := Charte.haut_contenu(rect) + 10.0
	for i in colonnes.size():
		var c: Array = colonnes[i]
		var x := x0 + pas * float(i)
		var couleur: Color = c[1]
		# L'en-tête de colonne : la couleur du groupe, et un filet dessous.
		Charte.capitales_dessinees(self, Vector2(x, y0), String(c[0]), 13, couleur, 0.22)
		draw_rect(Rect2(Vector2(x, y0 + 8.0), Vector2(pas - 24.0, 1.0)), Color(couleur, 0.5), true)
		var y := y0 + 34.0
		for ligne in c[2]:
			var l: Array = ligne
			var dx := _touches_dessinees(Vector2(x, y - 14.0), String(l[0]))
			# L'action se coupe sur deux lignes si elle déborde de la colonne :
			# une fiche qui tronque « larguer mine ou hu… » n'apprend rien.
			var yy := y
			for morceau in _lignes_coupees(String(l[1]), pas - 24.0 - dx):
				Charte.texte_dessine(self, Vector2(x + dx, yy), String(morceau), 12, Charte.ENCRE_DOUCE, 0)
				yy += 14.0
			y = yy - 14.0 + LIGNE
	Charte.aide_menu(self, rect, "échap ou entrée : retour à la pause" if not Tactile.actif() else "toucher pour revenir à la pause")

## Le texte coupé aux mots pour tenir dans `largeur` : une liste de lignes.
func _lignes_coupees(texte: String, largeur: float) -> Array:
	var lignes: Array = []
	var courant := ""
	for mot in texte.split(" "):
		var essai: String = (courant + " " + String(mot)).strip_edges()
		if Charte.largeur_texte(essai, 12) > largeur and courant != "":
			lignes.append(courant)
			courant = String(mot)
		else:
			courant = essai
	lignes.append(courant)
	return lignes

## La largeur qu'occuperaient les cabochons d'une entrée, sans les dessiner.
func _largeur_touches(spec: String) -> float:
	var dx := 0.0
	for morceau in spec.split("|"):
		var m := String(morceau)
		var nom := Reglages.nom_de_touche(m.substr(2)) if m.begins_with("t:") else m
		dx += Charte.largeur_capitales(nom, 11, 0.12) + 14.0 + 5.0
	return dx + 6.0

## Un ou plusieurs cabochons (« Z | S » écrit `t:avancer|t:reculer`), et la
## largeur occupée, pour poser l'action juste après.
func _touches_dessinees(ou: Vector2, spec: String) -> float:
	var dx := 0.0
	for morceau in spec.split("|"):
		var m := String(morceau)
		var nom := m
		if m.begins_with("t:"):
			nom = Reglages.nom_de_touche(m.substr(2))
		var lc := Charte.largeur_capitales(nom, 11, 0.12)
		var boite := Rect2(ou + Vector2(dx, 0.0), Vector2(lc + 14.0, 20.0))
		draw_rect(boite, Color(1, 1, 1, 0.07), true)
		draw_rect(boite.grow(-0.5), Color(1, 1, 1, 0.28), false, 1.0)
		Charte.capitales_dessinees(self, boite.position + Vector2(7.0, 14.0), nom, 11, Color.WHITE, 0.12)
		dx += boite.size.x + 5.0
	return dx + 6.0
