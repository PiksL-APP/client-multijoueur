extends Control
## L'affichage tête haute d'une manche, dans la charte de l'AFFICHE — celle du
## chargement et des écrans d'avant-partie : Archivo Black pour les chiffres,
## capitales condensées espacées pour les libellés, voile nuit cerné d'un filet,
## et le dégradé violet–rose–cyan qui coiffe chaque cartouche. Le chrono et
## les fortunes en haut à gauche, les étoiles de recherche en haut au milieu,
## la fiche du joueur — jauges, arme, argent, puces — en bas à gauche, le
## contrat en bas au milieu, et les touches sur la dernière ligne.
##
## ⚠ Il a porté la borne d'arcade (`UI`) jusqu'à la phase 9. Le client a
## tranché : « quelque chose comme le chargement et nos écrans d'accueil ». On
## ne change pas de logiciel en passant du menu à la rue.
##
## Tout se peint dans `_draw` : une trentaine de rectangles et de chiffres qui
## changent à chaque image, c'est un dessin, pas un arbre de contrôles à
## recaler. Le socle (`Partie`) remplit les champs ; le jeu ne connaît que
## la fiche qu'il renvoie.

const MARGE := 14.0
const LARGEUR_SCORES := 250.0
const LARGEUR_FICHE := 264.0
const HAUTEUR_JAUGE := 22.0
const RETRAIT := 14.0                ## la marge intérieure d'un cartouche

var chrono := 0.0                 ## secondes restantes — ou écoulées si `sans_limite`
var sans_limite := false          ## le chrono monte au lieu de descendre
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
var viseur := false               ## la croix au centre : vue subjective

func _draw() -> void:
	var taille := get_viewport_rect().size
	_peindre_les_scores()
	_peindre_le_reseau(taille)
	if fiche.has("etoiles"):
		_peindre_les_etoiles(taille)
	var bas := taille.y - MARGE - 26.0     # au-dessus de la ligne d'aide
	if not fiche.is_empty():
		bas = _peindre_la_fiche(bas)
		if fiche.has("respect"):
			bas = _peindre_le_respect(bas)
	elif etat_texte != "":
		bas = _peindre_l_etat(bas)
	if fiche.has("alerte"):
		_peindre_l_alerte(taille)
	_peindre_l_aide(taille)
	if viseur:
		_peindre_le_viseur(taille)
	if message != "":
		# Le décompte en très gros ; une phrase en capitales, plus modeste,
		# sinon « EN ATTENTE DES JOUEURS » déborde d'un écran de 960 pixels.
		if message.length() <= 2:
			Charte.inscription_titre(self, taille * 0.5, message, 96, Color.WHITE)
		else:
			Charte.inscription(self, taille * 0.5, message, 26, Color.WHITE, 0.30)

## LE VISEUR de la vue subjective : quatre traits fins autour d'un centre vide,
## avec une ombre pour rester lisible sur un ciel clair comme sur une façade
## sombre. Vide au milieu — un point plein cache précisément ce qu'on vise.
func _peindre_le_viseur(taille: Vector2) -> void:
	var c := taille * 0.5
	for ombre in [true, false]:
		var couleur := Color(0, 0, 0, 0.55) if ombre else Color(1, 1, 1, 0.9)
		var e := 3.0 if ombre else 1.5
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 5.0, c + d * 13.0, couleur, e)

## Chrono et fortunes : un cartouche, le chrono en Archivo Black, les joueurs
## dans l'ordre de la table, chacun souligné d'une barre à la longueur de sa
## fortune — la course se lit sans comparer des chiffres.
func _peindre_les_scores() -> void:
	var lignes := scores.size()
	var hauteur := 16.0 + 34.0 + lignes * 24.0 + 4.0
	var rect := Rect2(Vector2(MARGE, MARGE), Vector2(LARGEUR_SCORES, hauteur))
	Charte.cartouche(self, rect, Charte.ROSE if chrono_critique else Color(0, 0, 0, 0))
	var x := rect.position.x + RETRAIT
	var y := rect.position.y + 14.0
	var minutes := int(chrono) / 60
	var secondes := int(chrono) % 60
	var texte_chrono := "%d:%02d" % [minutes, secondes]
	var couleur_chrono := Charte.ROSE if chrono_critique and fmod(temps, 0.6) < 0.35 else Color.WHITE
	Charte.titre_dessine(self, Vector2(x, y + 26.0), texte_chrono, 28, couleur_chrono, 0)
	var libelle_chrono := "en ville" if sans_limite else "restant"
	var ll := Charte.largeur_capitales(libelle_chrono, 11)
	Charte.capitales_dessinees(self, Vector2(rect.end.x - RETRAIT - ll, y + 24.0), libelle_chrono, 11, Charte.ENCRE_FAIBLE)
	y += 42.0
	var maximum := 1
	for s in scores:
		maximum = max(maximum, int(s.get("score", 0)))
	for s in scores:
		var couleur: Color = s.get("couleur", Color.WHITE)
		var moi: bool = s.get("moi", false)
		draw_rect(Rect2(Vector2(x, y + 3.0), Vector2(8, 8)), couleur, true)
		var pseudo := String(s.get("pseudo", "?")).left(14)
		Charte.capitales_dessinees(self, Vector2(x + 16.0, y + 11.0), pseudo, 12,
			Color.WHITE if moi else Charte.ENCRE_DOUCE, 0.16)
		# La fortune, en dollars : c'est de l'argent, pas des points.
		var points := "$" + str(int(s.get("score", 0)))
		var largeur := Charte.largeur_titre(points, 13)
		Charte.titre_dessine(self, Vector2(rect.end.x - RETRAIT - largeur, y + 11.0), points, 13,
			Color.WHITE if moi else Charte.ENCRE_DOUCE, 0)
		# La barre de course, sous le nom : proportionnelle au meneur.
		var part := float(s.get("score", 0)) / float(maximum)
		var largeur_barre := rect.size.x - 2.0 * RETRAIT - 16.0
		draw_rect(Rect2(Vector2(x + 16.0, y + 17.0), Vector2(largeur_barre, 2.0)), Color(couleur, 0.20), true)
		if part > 0.0:
			draw_rect(Rect2(Vector2(x + 16.0, y + 17.0), Vector2(largeur_barre * part, 2.0)), couleur, true)
		y += 24.0

## En haut à droite : l'état du réseau et du son, en petites capitales. Le
## radar de Carnage se pose juste en dessous.
func _peindre_le_reseau(taille: Vector2) -> void:
	var y := MARGE + 12.0
	# Au doigt, pas de touche : le son se coupe dans le menu ≡ du pavé.
	var son := ("son coupé" if not son_actif else "son") if Tactile.actif() \
		else ("son coupé  [M]" if not son_actif else "[M] son")
	var largeur_son := Charte.largeur_capitales(son, 10, 0.16)
	var x := taille.x - MARGE - largeur_son
	Charte.capitales_dessinees(self, Vector2(x, y), son, 10,
		Charte.ENCRE_FAIBLE if son_actif else Charte.ORANGE, 0.16, 3)
	var largeur_reseau := Charte.largeur_capitales(reseau_libelle, 10, 0.16)
	x -= 20.0 + largeur_reseau
	Charte.capitales_dessinees(self, Vector2(x, y), reseau_libelle, 10, reseau_couleur, 0.16, 3)
	draw_rect(Rect2(Vector2(x - 13.0, y - 8.0), Vector2(7, 7)), reseau_couleur, true)

## Les étoiles de recherche : six emplacements, toujours visibles — une
## étoile qui apparaît de nulle part n'annonce pas qu'il en reste cinq.
## À cinq, elles clignotent : c'est l'hélicoptère. Elles sont ORANGE, la
## couleur chaude de l'affiche ; le rose est réservé au danger immédiat.
func _peindre_les_etoiles(taille: Vector2) -> void:
	var niveau := int(fiche.get("etoiles", 0))
	var centre_x := taille.x * 0.5
	var pas := 26.0
	for i in 6:
		var centre := Vector2(centre_x + (float(i) - 2.5) * pas, MARGE + 18.0)
		var allumee := i < niveau
		var couleur := Color(1, 1, 1, 0.12)
		if allumee:
			couleur = Charte.ORANGE
			if niveau >= 5 and fmod(temps, 0.5) < 0.25:
				couleur = Charte.ROSE
		Charte.etoile(self, centre + Vector2(1, 2), 11.0, Color(0, 0, 0, 0.5 if allumee else 0.0))
		Charte.etoile(self, centre, 11.0, couleur)
	if niveau > 0:
		Charte.inscription(self, Vector2(centre_x, MARGE + 44.0), "recherche", 11, Charte.ORANGE, 0.34)

## La fiche du joueur, en bas à gauche : jauges, arme, argent, puces d'état.
## Renvoie le bord haut du cartouche, pour qui voudrait poser autre chose
## au-dessus.
func _peindre_la_fiche(bas: float) -> float:
	var jauges: Array = fiche.get("jauges", [])
	var puces: Array = fiche.get("puces", [])
	var arme: Dictionary = fiche.get("arme", {})
	var argent: Dictionary = fiche.get("argent", {})
	var hauteur := 12.0 + jauges.size() * (HAUTEUR_JAUGE + 4.0)
	if not arme.is_empty():
		hauteur += 28.0
	if not argent.is_empty():
		hauteur += 26.0
	if not puces.is_empty():
		hauteur += 24.0
	hauteur += 8.0
	var rect := Rect2(Vector2(MARGE, bas - hauteur), Vector2(LARGEUR_FICHE, hauteur))
	Charte.cartouche(self, rect)
	var x := rect.position.x + RETRAIT
	var y := rect.position.y + 12.0
	var largeur := rect.size.x - 2.0 * RETRAIT
	for j in jauges:
		Charte.jauge(self, Rect2(Vector2(x, y), Vector2(largeur, HAUTEUR_JAUGE)), String(j.get("nom", "")),
			float(j.get("part", 0.0)), j.get("couleur", Charte.VERT), String(j.get("valeur", "")))
		y += HAUTEUR_JAUGE + 4.0
	if not arme.is_empty():
		var nom := String(arme.get("nom", "")).to_upper()
		Charte.titre_dessine(self, Vector2(x, y + 20.0), nom, 18, Color.WHITE, 0)
		var munitions := String(arme.get("munitions", ""))
		if munitions != "":
			var l := Charte.largeur_titre(munitions, 16)
			Charte.titre_dessine(self, Vector2(rect.end.x - RETRAIT - l, y + 20.0), munitions, 16, Charte.CYAN, 0)
		y += 28.0
	if not argent.is_empty():
		# Sur soi en gros — c'est ce qu'on perd — et le coffre à côté, en petit.
		var sur_soi := "$%d" % int(argent.get("sur_soi", 0))
		Charte.titre_dessine(self, Vector2(x, y + 19.0), sur_soi, 18, Charte.ORANGE, 0)
		if bool(argent.get("planque", false)):
			var coffre := "coffre $%d" % int(argent.get("banque", 0))
			var lc := Charte.largeur_capitales(coffre, 11, 0.14)
			Charte.capitales_dessinees(self, Vector2(rect.end.x - RETRAIT - lc, y + 18.0), coffre, 11, Charte.VERT, 0.14)
		else:
			var sans := "pas de planque"
			var ls := Charte.largeur_capitales(sans, 11, 0.14)
			Charte.capitales_dessinees(self, Vector2(rect.end.x - RETRAIT - ls, y + 18.0), sans, 11, Charte.ENCRE_FAIBLE, 0.14)
		y += 26.0
	if not puces.is_empty():
		var px := x
		for p in puces:
			var texte_puce := String(p.get("texte", ""))
			var couleur: Color = p.get("couleur", Charte.ENCRE_DOUCE)
			var l := Charte.largeur_texte(texte_puce, 13)
			if px + l + 14.0 > rect.end.x - RETRAIT + 4.0 and px > x:
				break     # une puce de trop ne déborde pas, elle attend
			draw_rect(Rect2(Vector2(px, y + 1.0), Vector2(l + 12.0, 20.0)), Color(couleur, 0.14), true)
			draw_rect(Rect2(Vector2(px, y + 1.0), Vector2(2.0, 20.0)), couleur, true)
			Charte.texte_dessine(self, Vector2(px + 7.0, y + 15.5), texte_puce, 13, couleur, 0)
			px += l + 18.0
		y += 24.0
	return rect.position.y

## LES TROIS BARRES DE RESPECT du district où l'on se trouve — pas les sept de
## la ville. Trois, c'est la question du moment : qui, ICI, vous laisse
## passer. Elles se peignent AU-DESSUS de la fiche.
func _peindre_le_respect(bas: float) -> float:
	var barres: Array = fiche.get("respect", [])
	if barres.is_empty():
		return bas
	var hauteur := 14.0 + barres.size() * 19.0
	var rect := Rect2(Vector2(MARGE, bas - hauteur - 6.0), Vector2(LARGEUR_FICHE, hauteur))
	Charte.cartouche(self, rect, Color(1, 1, 1, 0.22))
	var x := rect.position.x + RETRAIT
	var largeur := rect.size.x - 2.0 * RETRAIT
	var y := rect.position.y + 10.0
	for b in barres:
		var couleur: Color = b.get("couleur", Charte.ENCRE_DOUCE)
		var teinte: Color = b.get("teinte", couleur)
		var part: float = clamp(float(b.get("part", 0.0)), 0.0, 1.0)
		# Le nom à gauche, l'humeur à droite, la barre par-dessous : le nom
		# seul ne dit pas ce qu'il faut en penser, et l'humeur seule ne dit pas
		# de qui l'on parle.
		Charte.capitales_dessinees(self, Vector2(x, y + 9.0), String(b.get("nom", "")), 11, couleur, 0.16)
		var mot := String(b.get("humeur", ""))
		var lm := Charte.largeur_capitales(mot, 10, 0.14)
		Charte.capitales_dessinees(self, Vector2(rect.end.x - RETRAIT - lm, y + 9.0), mot, 10, teinte, 0.14)
		draw_rect(Rect2(Vector2(x, y + 13.0), Vector2(largeur, 3.0)), Color(couleur, 0.18), true)
		draw_rect(Rect2(Vector2(x, y + 13.0), Vector2(largeur * part, 3.0)), teinte, true)
		y += 19.0
	return rect.position.y

## La ligne d'état libre des jeux qui n'ont pas de fiche : un cartouche, une
## phrase.
func _peindre_l_etat(bas: float) -> float:
	var largeur := Charte.largeur_texte(etat_texte, 17)
	var rect := Rect2(Vector2(MARGE, bas - 42.0), Vector2(largeur + 2.0 * RETRAIT, 42.0))
	Charte.cartouche(self, rect)
	Charte.texte_dessine(self, Vector2(rect.position.x + RETRAIT, rect.position.y + 28.0), etat_texte, 17, Color.WHITE, 0)
	return rect.position.y

## L'alerte : le contrat en cours, en bas au milieu, avec son sablier en barre.
## Le cartouche prend la couleur du contrat sur son filet.
func _peindre_l_alerte(taille: Vector2) -> void:
	var alerte: Dictionary = fiche.get("alerte", {})
	var texte_alerte := String(alerte.get("texte", ""))
	if texte_alerte == "":
		return
	var couleur: Color = alerte.get("couleur", Charte.ORANGE)
	var part := float(alerte.get("part", -1.0))
	var largeur := Charte.largeur_capitales(texte_alerte, 12, 0.14) + 2.0 * RETRAIT + 4.0
	var hauteur := 36.0 if part >= 0.0 else 30.0
	var rect := Rect2(Vector2(taille.x * 0.5 - largeur * 0.5, taille.y - MARGE - 26.0 - 8.0 - hauteur), Vector2(largeur, hauteur))
	Charte.cartouche(self, rect, couleur)
	Charte.capitales_dessinees(self, Vector2(rect.position.x + RETRAIT + 2.0, rect.position.y + 21.0), texte_alerte, 12, Color.WHITE, 0.14)
	if part >= 0.0:
		var barre := Rect2(Vector2(rect.position.x + RETRAIT, rect.end.y - 8.0), Vector2(largeur - 2.0 * RETRAIT, 3.0))
		draw_rect(barre, Color(couleur, 0.22), true)
		draw_rect(Rect2(barre.position, Vector2(barre.size.x * clampf(part, 0.0, 1.0), 3.0)), couleur, true)

## Les touches, sur la dernière ligne. Elles s'estompent après le départ :
## on les a lues pendant le décompte, elles n'ont plus à crier.
func _peindre_l_aide(taille: Vector2) -> void:
	if aide.is_empty() or aide_visible <= 0.0:
		return
	var x := MARGE
	var y := taille.y - MARGE - 20.0
	var alpha := clampf(aide_visible, 0.0, 1.0)
	for paire in aide:
		var largeur_attendue := Charte.largeur_capitales(String(paire[0]), 11, 0.12) + 21.0 \
			+ Charte.largeur_texte(String(paire[1]), 13) + 20.0
		if x + largeur_attendue > taille.x - 240.0 and x > MARGE:
			break    # les boutons tactiles vivent à droite ; on ne passe pas dessous
		x += Charte.cabochon(self, Vector2(x, y), String(paire[0]), String(paire[1]), alpha)
