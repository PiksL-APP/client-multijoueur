extends Control
## L'affichage tête haute d'une manche, façon borne d'arcade : le chrono et les
## scores en cartouche en haut à gauche, les étoiles de recherche en haut au
## milieu, la fiche du joueur — jauges, arme, humeur du quartier — en bas à
## gauche, l'alerte du moment (le contrat) en bas au milieu, et les touches
## en cabochons sur la dernière ligne.
##
## Tout se peint dans `_draw` : une trentaine de rectangles et de chiffres qui
## changent à chaque image, c'est un dessin, pas un arbre de contrôles à
## recaler. Le socle (`Partie`) remplit les champs ; le jeu ne connaît que
## la fiche qu'il renvoie. Ainsi l'énigme et Carnage ont le même HUD, chacun
## avec ses propres rubriques.

const MARGE := 12.0
const LARGEUR_SCORES := 250.0
const LARGEUR_FICHE := 262.0
const HAUTEUR_JAUGE := 16.0

var chrono := 0.0                 ## secondes restantes
var chrono_critique := false
var scores: Array = []            ## [{pseudo, score, couleur: Color, moi: bool}]
var message := ""                 ## au centre de l'écran : décompte, attente, fin
var aide: Array = []              ## [[touche, action], …]
var aide_visible := 1.0           ## alpha de la ligne d'aide
var etat_texte := ""              ## ligne libre, pour les jeux sans fiche structurée
var fiche: Dictionary = {}        ## voir `Partie.fiche_joueur`
var reseau_libelle := ""
var reseau_couleur := Palette.ENCRE_FAIBLE
var son_actif := true
var temps := 0.0                  ## pour les clignotements

func _draw() -> void:
	var taille := get_viewport_rect().size
	_peindre_les_scores()
	_peindre_le_reseau(taille)
	if fiche.has("etoiles"):
		_peindre_les_etoiles(taille)
	var bas := taille.y - MARGE - 24.0     # au-dessus de la ligne d'aide
	if not fiche.is_empty():
		bas = _peindre_la_fiche(bas)
	elif etat_texte != "":
		bas = _peindre_l_etat(bas)
	if fiche.has("alerte"):
		_peindre_l_alerte(taille)
	_peindre_l_aide(taille)
	if message != "":
		# Le décompte en très gros ; une phrase, en corps plus modeste, sinon
		# « EN ATTENTE DES JOUEURS » déborde d'un écran de 960 pixels.
		UI.inscription(self, taille * 0.5, message, 48 if message.length() <= 2 else 24, Palette.ENCRE)

## Chrono et scores : un cartouche, les joueurs dans l'ordre de la table, le
## meneur souligné d'une barre à la longueur de son score — la course se lit
## sans comparer des chiffres.
func _peindre_les_scores() -> void:
	var lignes := scores.size()
	var hauteur := 14.0 + 28.0 + lignes * 22.0 + 6.0
	var rect := Rect2(Vector2(MARGE, MARGE), Vector2(LARGEUR_SCORES, hauteur))
	UI.cartouche(self, rect, Palette.CRITIQUE if chrono_critique else Palette.SERIE)
	var x := rect.position.x + UI.ACCENT + 12.0
	var y := rect.position.y + 12.0
	var minutes := int(chrono) / 60
	var secondes := int(chrono) % 60
	var texte_chrono := "%d:%02d" % [minutes, secondes]
	var couleur_chrono := Palette.CRITIQUE if chrono_critique and fmod(temps, 0.6) < 0.35 else Palette.ENCRE
	draw_string(UI.TITRE_POLICE, Vector2(x, y + 22.0), texte_chrono, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, couleur_chrono)
	draw_string(UI.TEXTE_POLICE, Vector2(rect.end.x - 12.0 - UI.TEXTE_POLICE.get_string_size("restant", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x,
		y + 20.0), "restant", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_FAIBLE)
	y += 34.0
	var maximum := 1
	for s in scores:
		maximum = max(maximum, int(s.get("score", 0)))
	for s in scores:
		var couleur: Color = s.get("couleur", Palette.ENCRE)
		var moi: bool = s.get("moi", false)
		draw_rect(Rect2(Vector2(x, y + 4.0), Vector2(10, 10)), couleur, true)
		var pseudo := String(s.get("pseudo", "?")).to_upper().left(12)
		draw_string(UI.TITRE_POLICE, Vector2(x + 18.0, y + 13.0), pseudo, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Palette.ENCRE if moi else Palette.ENCRE_DOUCE)
		var points := str(int(s.get("score", 0)))
		var largeur := UI.TITRE_POLICE.get_string_size(points, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(UI.TITRE_POLICE, Vector2(rect.end.x - 12.0 - largeur, y + 15.0), points,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.ENCRE if moi else Palette.ENCRE_DOUCE)
		# La barre de course, sous le nom : proportionnelle au meneur.
		var part := float(s.get("score", 0)) / float(maximum)
		var largeur_barre := rect.size.x - UI.ACCENT - 24.0 - 18.0 - largeur - 8.0
		draw_rect(Rect2(Vector2(x + 18.0, y + 17.0), Vector2(largeur_barre, 2.0)), Color(couleur, 0.25), true)
		if part > 0.0:
			draw_rect(Rect2(Vector2(x + 18.0, y + 17.0), Vector2(largeur_barre * part, 2.0)), couleur, true)
		y += 22.0

## En haut à droite : l'état du réseau et du son, en petit. Le radar de
## Carnage se pose juste en dessous.
func _peindre_le_reseau(taille: Vector2) -> void:
	var y := MARGE + 14.0
	var son := "son coupé  [M]" if not son_actif else "[M] son"
	var largeur_son := UI.TEXTE_POLICE.get_string_size(son, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x := taille.x - MARGE - largeur_son
	draw_string(UI.TEXTE_POLICE, Vector2(x, y), son, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Palette.ENCRE_FAIBLE if son_actif else Palette.AVERTISSEMENT)
	var largeur_reseau := UI.TEXTE_POLICE.get_string_size(reseau_libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	x -= 18.0 + largeur_reseau
	draw_string(UI.TEXTE_POLICE, Vector2(x, y), reseau_libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, reseau_couleur)
	draw_rect(Rect2(Vector2(x - 14.0, y - 9.0), Vector2(8, 8)), reseau_couleur, true)

## Les étoiles de recherche : cinq emplacements, toujours visibles — une
## étoile qui apparaît de nulle part n'annonce pas qu'il en reste quatre.
## À cinq, elles clignotent : c'est l'hélicoptère.
func _peindre_les_etoiles(taille: Vector2) -> void:
	var niveau := int(fiche.get("etoiles", 0))
	var centre_x := taille.x * 0.5
	var pas := 30.0
	for i in 5:
		var centre := Vector2(centre_x + (i - 2) * pas, MARGE + 18.0)
		var allumee := i < niveau
		var couleur := Color(1, 1, 1, 0.14)
		if allumee:
			couleur = Palette.AVERTISSEMENT
			if niveau >= 5 and fmod(temps, 0.5) < 0.25:
				couleur = Palette.CRITIQUE
		UI.etoile(self, centre + Vector2(1, 2), 11.0, Color(0, 0, 0, 0.5 if allumee else 0.0))
		UI.etoile(self, centre, 11.0, couleur)
	if niveau > 0:
		UI.inscription(self, Vector2(centre_x, MARGE + 44.0), "RECHERCHE", 8, Palette.AVERTISSEMENT)

## La fiche du joueur, en bas à gauche : jauges, arme, puces d'état. Renvoie
## le bord haut du cartouche, pour qui voudrait poser autre chose au-dessus.
func _peindre_la_fiche(bas: float) -> float:
	var jauges: Array = fiche.get("jauges", [])
	var puces: Array = fiche.get("puces", [])
	var arme: Dictionary = fiche.get("arme", {})
	var hauteur := 12.0 + jauges.size() * (HAUTEUR_JAUGE + 6.0)
	if not arme.is_empty():
		hauteur += 24.0
	if not puces.is_empty():
		hauteur += 22.0
	hauteur += 6.0
	var rect := Rect2(Vector2(MARGE, bas - hauteur), Vector2(LARGEUR_FICHE, hauteur))
	var accent: Color = fiche.get("accent", Palette.SERIE)
	UI.cartouche(self, rect, accent)
	var x := rect.position.x + UI.ACCENT + 12.0
	var y := rect.position.y + 12.0
	var largeur := rect.size.x - UI.ACCENT - 24.0
	for j in jauges:
		UI.jauge(self, Rect2(Vector2(x, y), Vector2(largeur, HAUTEUR_JAUGE)), String(j.get("nom", "")),
			float(j.get("part", 0.0)), j.get("couleur", Palette.BON), String(j.get("valeur", "")))
		y += HAUTEUR_JAUGE + 6.0
	if not arme.is_empty():
		var nom := String(arme.get("nom", "")).to_upper()
		draw_string(UI.TITRE_POLICE, Vector2(x, y + 16.0), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.ENCRE)
		var munitions := String(arme.get("munitions", ""))
		if munitions != "":
			var l := UI.TITRE_POLICE.get_string_size(munitions, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(UI.TITRE_POLICE, Vector2(rect.end.x - 12.0 - l, y + 16.0), munitions,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AVERTISSEMENT)
		y += 24.0
	if not puces.is_empty():
		var px := x
		for p in puces:
			var texte_puce := String(p.get("texte", ""))
			var couleur: Color = p.get("couleur", Palette.ENCRE_DOUCE)
			var l := UI.TEXTE_POLICE.get_string_size(texte_puce, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			if px + l + 12.0 > rect.end.x - 8.0 and px > x:
				break     # une puce de trop ne déborde pas, elle attend
			draw_rect(Rect2(Vector2(px, y + 1.0), Vector2(l + 10.0, 18.0)), Color(couleur, 0.18), true)
			draw_rect(Rect2(Vector2(px, y + 1.0), Vector2(2.0, 18.0)), couleur, true)
			draw_string(UI.TEXTE_POLICE, Vector2(px + 6.0, y + 15.0), texte_puce, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, couleur)
			px += l + 16.0
		y += 22.0
	return rect.position.y

## La ligne d'état libre des jeux qui n'ont pas de fiche : un cartouche, une
## phrase.
func _peindre_l_etat(bas: float) -> float:
	var largeur := UI.TEXTE_POLICE.get_string_size(etat_texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var rect := Rect2(Vector2(MARGE, bas - 40.0), Vector2(largeur + UI.ACCENT + 28.0, 40.0))
	UI.cartouche(self, rect, Palette.SERIE)
	draw_string(UI.TEXTE_POLICE, Vector2(rect.position.x + UI.ACCENT + 14.0, rect.position.y + 27.0), etat_texte,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.ENCRE)
	return rect.position.y

## L'alerte : le contrat en cours, en bas au milieu, avec son sablier en barre.
func _peindre_l_alerte(taille: Vector2) -> void:
	var alerte: Dictionary = fiche.get("alerte", {})
	var texte_alerte := String(alerte.get("texte", ""))
	if texte_alerte == "":
		return
	var couleur: Color = alerte.get("couleur", Palette.AVERTISSEMENT)
	var part := float(alerte.get("part", -1.0))
	var largeur := UI.TITRE_POLICE.get_string_size(texte_alerte, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 40.0
	var hauteur := 30.0 if part >= 0.0 else 26.0
	var rect := Rect2(Vector2(taille.x * 0.5 - largeur * 0.5, taille.y - MARGE - 24.0 - 8.0 - hauteur), Vector2(largeur, hauteur))
	UI.cartouche(self, rect, couleur)
	draw_string(UI.TITRE_POLICE, Vector2(rect.position.x + UI.ACCENT + 16.0, rect.position.y + 17.0), texte_alerte,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.ENCRE)
	if part >= 0.0:
		var barre := Rect2(Vector2(rect.position.x + UI.ACCENT + 16.0, rect.end.y - 7.0), Vector2(largeur - UI.ACCENT - 32.0, 3.0))
		draw_rect(barre, Color(couleur, 0.25), true)
		draw_rect(Rect2(barre.position, Vector2(barre.size.x * clampf(part, 0.0, 1.0), 3.0)), couleur, true)

## Les touches, sur la dernière ligne. Elles s'estompent après le départ :
## on les a lues pendant le décompte, elles n'ont plus à crier.
func _peindre_l_aide(taille: Vector2) -> void:
	if aide.is_empty() or aide_visible <= 0.0:
		return
	var x := MARGE
	var y := taille.y - MARGE - 18.0
	var alpha := clampf(aide_visible, 0.0, 1.0)
	for paire in aide:
		var largeur_attendue := UI.TITRE_POLICE.get_string_size(String(paire[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 18.0 \
			+ UI.TEXTE_POLICE.get_string_size(String(paire[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 18.0
		if x + largeur_attendue > taille.x - 240.0 and x > MARGE:
			break    # les boutons tactiles vivent à droite ; on ne passe pas dessous
		x += _cabochon_estompe(Vector2(x, y), String(paire[0]), String(paire[1]), alpha)

func _cabochon_estompe(ou: Vector2, cle: String, action: String, alpha: float) -> float:
	var largeur_cle := UI.TITRE_POLICE.get_string_size(cle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var boite := Rect2(ou, Vector2(largeur_cle + 12.0, 18.0))
	draw_rect(boite, Color(Palette.ENCRE_DOUCE, alpha), true)
	draw_string(UI.TITRE_POLICE, ou + Vector2(6.0, 13.0), cle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Palette.FOND, alpha))
	draw_string(UI.TEXTE_POLICE, ou + Vector2(boite.size.x + 6.0, 14.0), action,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Palette.ENCRE_DOUCE, alpha))
	return boite.size.x + 6.0 + UI.TEXTE_POLICE.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 18.0
