class_name Quartiers
extends RefCounted
## LA VILLE DESSINÉE À LA MAIN, comme les intérieurs de repaire.
##
## Trois maquettes générées ont été refusées : le procédural sait remplir, il
## ne sait pas avoir du goût. On reprend donc ici EXACTEMENT le geste des
## intérieurs (`jeux/carnage/interieurs.gd`) : le plan est un DESSIN, un
## caractère par case, qu'on relit d'un coup d'œil et où déplacer une rue est
## un caractère dans le diff. Une photo suffit à vérifier
## (`outils/carte.sh <quartier>`).
##
## UNE CASE = VINGT UNITÉS = deux tuiles de jeu = une tuile du City Kit: Roads
## à l'échelle UNIFORME. Rien n'est jamais étiré : c'est ce qui bavait sur les
## marquages et les trottoirs des premières maquettes.
##
## LA VILLE EST FAITE DE QUARTIERS QUI N'ONT PAS LA MÊME TRAME. Chacun a son
## origine et son ANGLE ; entre deux quartiers il y a de l'eau, une falaise ou
## un parc — jamais un raccord de tuiles. C'est la seule chose qui casse
## vraiment le damier : une grille reste une grille, si irrégulière soit-elle.
##
## ─────────────────────────── LE DESSIN ───────────────────────────
##
##   .   l'eau (rien du tout)
##   ,   pelouse, terrain nu
##   ;   sable — le bord de mer
##   o   esplanade pavée, place, parvis
##   P   parking
##   #   rue — les tuiles se raccordent TOUTES SEULES (droite, virage, T,
##       carrefour, impasse) et grimpent en rampe là où le relief monte
##   =   pont
##   O   rond-point : posé sur son CENTRE, il mange 3 x 3 cases
##   (   COURBE LARGE : le grand virage de voie rapide du kit. Posé sur son
##       coin NORD-OUEST, il mange 2 x 2 cases. Il entre par le milieu d'un
##       côté et ressort par le milieu du côté d'à côté, DEUX CASES PLUS LOIN —
##       ce n'est pas un virage de rue, c'est une bretelle. Son quart de tour
##       se DÉDUIT des rues qui l'entourent, on n'a rien à écrire.
##   /   RAMPE DOUCE : `road-slant-curve`, deux cases pour monter DEUX paliers
##       en s'adoucissant aux deux bouts. Posée sur sa case BASSE ; le sens et
##       l'axe se déduisent du relief et des rues voisines.
##   ^   bosquet d'arbres        '   buissons et hautes herbes
##   ~   plan d'eau du port : pas de terre, mais un bateau amarré. LA LONGUEUR
##       DE LA FILE DE `~` CHOISIT LE BATEAU — cinq cases d'affilée valent un
##       cargo, deux un remorqueur, une un canot. On dessine un mouillage, pas
##       un bateau à la fois.
##   X   dépôt : conteneurs, cuves, palettes — le sol d'un port
##   %   chantier : barrières, cônes, palissade
##   P   parking : le sol est pavé et il y a des voitures dessus
##
##   T tour   B bureau   C commerce   M maison   V vieille ville   H hangar
##
##   LES BÂTIMENTS À INTERACTION — le jeu s'y passe quelque chose :
##   +   hôpital        F   caserne de pompiers
##   S   supermarché    $   garage de peinture
##   ?   cabine téléphonique (une case)   *   caisse à ramasser (une case)
##   Un BLOC de lettres identiques est UN SEUL bâtiment qui remplit exactement
##   ce rectangle : c'est ce qui donne des fronts de rue continus au lieu
##   d'immeubles semés sur une pelouse. Pour en mettre deux côte à côte sans
##   qu'ils fusionnent, alterner MAJUSCULE et minuscule : `TTtt` fait deux
##   immeubles, `TTTT` un seul.
##
## ─────────────────────────── LE RELIEF ───────────────────────────
##
## Une deuxième grille, même taille, un CHIFFRE par case : le palier, cinq
## unités par cran (c'est exactement ce dont `road-slant` grimpe en une case —
## d'où le choix du cran). Espace ou absence = palier zéro.

const CASE := CarteVille.CASE
const PALIER := CarteVille.PALIER
const ROUTES := CarteVille.CHEMIN_ROUTES

## ⚠ LE JOURNAL D'INVENTAIRE. Éteint en jeu — deux comparaisons par objet posé,
## rien de plus. Allumé, il note QUEL MODÈLE a réellement été posé, et combien
## de fois. C'est le seul moyen de répondre à « est-ce que tout le kit sert ? »
## autrement qu'en relisant le code : un chemin de modèle qui n'existe pas ne
## fait rien ET NE DIT RIEN (`_objet` sort en silence), donc une entrée de
## table ne prouve pas qu'un modèle est posé. Voir `outils/inventaire.sh`.
static var inventaire := false
static var journal: Dictionary = {}

static func _noter(chemin: String) -> void:
	journal[chemin] = int(journal.get(chemin, 0)) + 1

const CHAUSSEE := "#=O(/"
const PAVE := "oP"
const FAMILLES := {
	"T": PlanVille.F_TOUR, "B": PlanVille.F_BUREAUX, "C": PlanVille.F_COMMERCE,
	"M": PlanVille.F_MAISON, "V": PlanVille.F_VIEUX, "H": PlanVille.F_HANGAR,
}

const TEINTE_ROUTE := Color("#8e929c")
const TEINTE_PAVE := Color("#b9b6ac")
const TEINTE_SABLE := Color("#d9c9a2")


# ------------------------------------------------------------ LE CATALOGUE

## LES QUARTIERS. Chacun a son origine (en cases, dans le monde), son ANGLE,
## son dessin et son relief. C'est CE BLOC qu'on reprend à la main : déplacer
## une rue, c'est déplacer des `#` ; poser un immeuble, c'est écrire des
## lettres ; creuser un port, c'est écrire des points.
##
## ⚠ Les deux grilles d'un quartier doivent faire la MÊME taille, sinon le
## relief est lu à zéro là où il manque — ce qui se voit comme une falaise
## sans raison.
## LA VILLE. ⚠ UN SEUL QUARTIER, UNE SEULE TRAME, AUCUN ANGLE.
##
## La version précédente en portait six, chacun avec son angle : c'était le
## parti « moins carré » — deux quartiers voisins qui ne sont pas d'accord sur
## la direction du nord cassent le damier mieux que n'importe quelle rue
## courbe. Le client l'a tranché autrement : tout doit être droit et sur le
## même plan. Les six quartiers inclinés sont dans l'historique du dépôt
## (commit f3081cd) — ils ne sont pas perdus, ils ne sont plus la ville.
##
## Ce qui remplace l'angle pour casser le damier : le RYTHME D'ÎLOTS. Le centre
## est tramé en 6 × 4, le résidentiel en 8 × 6, l'industrie en 12 × 8, et les
## chenaux passent en biais à travers les trois. Vu d'avion, les trois secteurs
## ne se ressemblent pas — et c'était tout ce qu'on demandait aux angles.
##
## Le dessin lui-même est dans `PlanPikstown` : 215 lignes de 225 caractères ne
## tiennent pas au milieu d'un fichier de code qu'on relit.
const CATALOGUE := {
	"pikstown": {
		"nom": "Pikstown", "origine": Vector2(0.0, 0.0), "angle": 0.0, "graine": 2609,
		"herbe": Color("#7f9464"), "roche": Color("#8b8578"),
		# ⚠ LES BORNES DE HAUTEUR CHOISISSENT LE MODÈLE, pas seulement l'étirage.
		# `batiment_kenney` cherche le modèle dont le rapport hauteur/largeur
		# ressemble le plus au volume demandé : des bornes serrées demandent
		# toujours le même rapport, donc toujours les mêmes maillages. Les
		# fourchettes ci-dessous couvrent l'étendue des ratios de chaque
		# famille (mesurés sur les `.glb`) — c'est ce qui fait sortir les
		# vingt-sept pavillons au lieu de dix, et les vingt hangars au lieu de
		# neuf. Vérifiable : `./outils/inventaire.sh`.
		"hauteurs": {"T": [42.0, 104.0], "B": [22.0, 66.0], "C": [12.0, 34.0],
			"M": [9.0, 19.0], "V": [9.0, 20.0], "H": [13.0, 44.0]},
		# ⚠ `source` DIT OÙ LE DESSIN VIT VRAIMENT. Sans elle, l'éditeur
		# ressortait un bloc `"plan": [...]` à recoller dans ce fichier-ci — or
		# le dessin n'y est plus depuis qu'il fait 96 000 caractères. Un export
		# qu'on ne peut recoller nulle part, c'est un éditeur qui ne sert à rien.
		"source": "PlanPikstown",
		"plan": PlanPikstown.PLAN,
		"relief": PlanPikstown.RELIEF,
	},
}

# ------------------------------------------------------------ lecture du dessin

## ⚠ LES BÂTIMENTS À INTERACTION NE VIENNENT PAS DU KIT. Ce sont des modèles
## dessinés pour Piks Theft Auto (`modeles/piksl/`), et le jeu S'Y PASSE quelque
## chose : l'hôpital rend la santé, le garage repeint la voiture et fait sauter
## la police, la cabine donne les missions, la caisse se ramasse. Ils ont donc
## leur table à eux : un caractère du dessin, un modèle, et le rapport
## hauteur/plus petit côté MESURÉ sur la boîte englobante du `.glb` — c'est lui
## qui empêche un supermarché de sortir en tour et un hôpital en hangar.
##
## Un bloc de ces caractères est UN SEUL bâtiment qui remplit le rectangle,
## comme un bloc de lettres ; mais il n'est jamais DÉCOUPÉ — il n'y a qu'un
## hôpital par hôpital.
const SERVICES := {
	"+": ["piksl/hospital", 1.45, "Hôpital"],
	"F": ["piksl/firestation", 0.61, "Caserne de pompiers"],
	"S": ["piksl/supermarket", 0.30, "Supermarché"],
	"$": ["piksl/garage_de_peinture", 0.50, "Garage de peinture"],
}
## Les deux objets à ramasser : ils ne remplissent pas de rectangle, ils se
## posent sur une case comme un arbre.
const CABINE := "?"
const CAISSE := "*"

static func _lettre(c: String) -> String:
	if SERVICES.has(c): return c
	return c.to_upper() if FAMILLES.has(c.to_upper()) else ""

static func _car(dessin: Array, i: int, j: int) -> String:
	if j < 0 or j >= dessin.size(): return "."
	var ligne: String = dessin[j]
	if i < 0 or i >= ligne.length(): return "."
	return ligne[i]

static func _niveau(relief: Array, i: int, j: int) -> int:
	if j < 0 or j >= relief.size(): return 0
	var ligne: String = relief[j]
	if i < 0 or i >= ligne.length(): return 0
	var c := ligne[i]
	return int(c) if c >= "0" and c <= "9" else 0

## Le dessin devient une carte : terre, paliers, chaussée. Le pavage des rues
## et les rampes se déduisent ensuite tout seuls (`CarteVille.tuile`).
## ⚠ UN SEUL BALAYAGE, ET LES LIGNES LUES DIRECTEMENT. Cette fonction est
## appelée à CHAQUE relâchement de pinceau dans l'éditeur — deux fois, même,
## puisque `fautes` la rappelait pour son compte. Mesurée sur Pikstown
## (96 000 cases) : 463 ms. Sur les quartiers de 32 × 20 pour lesquels elle a
## été écrite, personne ne pouvait le voir.
##
## Trois choses la ralentissaient, aucune n'était nécessaire :
##  - DEUX balayages complets, le second uniquement pour retrouver les `O` :
##    on note leur position au passage du premier ;
##  - `_car()` par case, qui refait deux bornes et un accès tableau : la ligne
##    est lue une fois par rangée et indexée directement ;
##  - la conversion `String(l)` dans la boucle des largeurs.
## ⚠ `fenetre` : LA CARTE D'UN MORCEAU DE VILLE. Le contenu d'une case ne dépend
## que d'elle-même — son caractère et son chiffre de relief —, jamais de ses
## voisines. On peut donc n'en calculer qu'un rectangle, et c'est ce qui rend
## l'éditeur utilisable : rebâtir quatre morceaux après un coup de pinceau
## n'exige pas de reconstruire les 63 536 cases de Pikstown.
##
## Les seules choses qui débordent d'une case sont les ronds-points (3 × 3) et
## le pavage des rues, qui lit les quatre voisines. La fenêtre doit donc être
## prise avec une MARGE de trois cases autour de ce qu'on rebâtit, sinon les
## rues se raccorderaient en impasse au bord de la fenêtre.
static func carte_de(fiche: Dictionary, fenetre: Rect2i = Rect2i()) -> CarteVille:
	var dessin: Array = fiche["plan"]
	var relief: Array = fiche.get("relief", [])
	var carte := CarteVille.new()
	var ronds: Array = []
	var courbes: Array = []
	var rampes: Array = []
	var j0 := 0
	var j1 := dessin.size() - 1
	if fenetre.size != Vector2i.ZERO:
		j0 = maxi(0, fenetre.position.y)
		j1 = mini(dessin.size() - 1, fenetre.position.y + fenetre.size.y - 1)
	for j in range(j0, j1 + 1):
		var ligne: String = dessin[j]
		var haut: String = relief[j] if j < relief.size() else ""
		var i0 := 0
		var i1 := ligne.length() - 1
		if fenetre.size != Vector2i.ZERO:
			i0 = maxi(0, fenetre.position.x)
			i1 = mini(ligne.length() - 1, fenetre.position.x + fenetre.size.x - 1)
		for i in range(i0, i1 + 1):
			var c := ligne[i]
			if c == "." or c == "~":
				continue
			var niveau := 0
			if i < haut.length():
				var d := haut[i]
				if d >= "0" and d <= "9":
					niveau = int(d)
			carte.poser_sol(Vector2i(i, j), niveau)
			if CHAUSSEE.contains(c):
				carte.poser_route(Vector2i(i, j), true)
				if c == "O": ronds.append(Vector2i(i, j))
				elif c == "(": courbes.append(Vector2i(i, j))
				elif c == "/": rampes.append(Vector2i(i, j))
	# LES GROSSES PIÈCES APRÈS LE BALAYAGE : elles ont besoin que toutes leurs
	# cases existent, et leur orientation se lit sur les rues VOISINES — donc
	# une fois que les rues sont là.
	for r in ronds:
		var c2: Vector2i = r
		if not carte.poser_piece("road-roundabout", Vector2i(c2.x - 1, c2.y - 1),
				Vector2i(3, 3), 0):
			push_warning("rond-point refusé en (%d,%d) : il lui faut 3x3 cases de terre au même palier" % [c2.x, c2.y])
	for r in courbes:
		var c2: Vector2i = r
		var q := CarteVille.quarts_courbe(carte, c2, true)
		if q < 0 or not carte.poser_piece(CarteVille.modele_courbe(carte, c2, q), c2,
				Vector2i(2, 2), q):
			push_warning("courbe large refusée en (%d,%d) : il lui faut 2x2 cases de terre au même palier et une rue à chaque bout" % [c2.x, c2.y])
	for r in rampes:
		var c2: Vector2i = r
		var f: Array = _rampe_douce(carte, c2)
		if f.is_empty() or not carte.poser_piece(String(f[0]), f[3], f[1],
				int(f[2]), true):
			push_warning("rampe douce refusée en (%d,%d) : il lui faut deux cases alignées et deux paliers d'écart" % [c2.x, c2.y])
	return carte

## LA RAMPE DOUCE. `road-slant-curve` fait deux cases de long et monte de DEUX
## paliers en s'adoucissant aux deux bouts — c'est la montée d'une voie rapide,
## là où `road-slant-high` est une marche de garage. Elle se pose sur sa case
## BASSE ; la case d'à côté qui est deux paliers plus haut donne l'axe ET le
## sens. Sans rotation, le modèle monte vers l'EST ; un quart de tour envoie
## l'est au NORD.
## Retourne [modèle, emprise dans le monde, quarts] ou [] si rien ne colle.
static func _rampe_douce(carte: CarteVille, bas: Vector2i) -> Array:
	var n := carte.palier(bas)
	for k in 4:
		var d: Vector2i = CarteVille.COTES[k]
		var haut: Vector2i = bas + d
		if not carte.route(haut) or carte.palier(haut) != n + 2: continue
		var quarts: int = CarteVille.VERS_LE_HAUT[k]
		# L'emprise part du coin NORD-OUEST : vers l'ouest ou vers le nord,
		# c'est la case HAUTE qui tient le coin.
		var coin: Vector2i = bas if (d.x > 0 or d.y > 0) else haut
		var taille := Vector2i(2, 1) if d.x != 0 else Vector2i(1, 2)
		var modele := "road-slant-curve" if CarteVille._tirage(bas) % 2 == 0 \
			else "road-slant-flat-curve"
		return [modele, taille, quarts, coin]
	return []

# ------------------------------------------------------------ les bâtiments

## Les rectangles de lettres. On balaye ; à la première case non vue, on étire
## vers l'est tant que c'est la même lettre, puis vers le sud tant que la
## rangée entière l'est aussi. Le dessinateur trace des rectangles : inutile
## d'aller chercher des formes en L qu'il ne dessinera jamais.
## ⚠ UN TABLEAU DE BOOLÉENS, PAS UN DICTIONNAIRE DE `Vector2i`. Le marquage des
## cases déjà prises passait par `vus.has(Vector2i(i, j))` : sur Pikstown, ça
## fait plus de deux cent mille hachages de vecteur pour un balayage — 258 ms.
## Une ligne de booléens par rangée coûte un accès tableau. La sortie est
## identique, rectangle pour rectangle et dans le même ordre : c'est vérifié au
## banc, pas supposé.
static func batiments(dessin: Array) -> Array:
	var sortie: Array = []
	var hauteur := dessin.size()
	if hauteur == 0: return sortie
	var lignes: Array = []
	var large := 0
	for l in dessin:
		var t := String(l)
		lignes.append(t)
		large = maxi(large, t.length())
	var vus: Array = []
	for j in hauteur:
		var rangee: PackedByteArray = PackedByteArray()
		rangee.resize(large)
		vus.append(rangee)

	# Le caractère en (i, j), ou "." hors du dessin — la même convention que
	# `_car`, écrite ici pour éviter l'appel.
	var lire := func(i: int, j: int) -> String:
		if j < 0 or j >= hauteur: return "."
		var t: String = lignes[j]
		if i < 0 or i >= t.length(): return "."
		return t[i]

	for j in hauteur:
		var pris: PackedByteArray = vus[j]
		var ligne: String = lignes[j]
		for i in ligne.length():
			if pris[i] != 0: continue
			var c := ligne[i]
			var lettre := _lettre(c)
			if lettre == "": continue
			var w := 1
			while i + w < large and lire.call(i + w, j) == c \
					and (vus[j] as PackedByteArray)[i + w] == 0:
				w += 1
			var h := 1
			while j + h < hauteur:
				var entier := true
				for k in w:
					if lire.call(i + k, j + h) != c \
							or (vus[j + h] as PackedByteArray)[i + k] != 0:
						entier = false
						break
				if not entier: break
				h += 1
			for b in h:
				var r: PackedByteArray = vus[j + b]
				for a in w:
					r[i + a] = 1
			sortie.append({"lettre": lettre, "i": i, "j": j, "w": w, "h": h})
	return sortie

# ------------------------------------------------------------ vérification

## LES FAUTES D'UN PLAN, en un seul endroit — le banc (`outils/verifier.gd`) et
## l'éditeur s'en servent tous les deux. Écrites deux fois, elles auraient
## divergé au premier ajout, et l'éditeur aurait laissé passer ce que le banc
## refuse.
## Trois fautes, qui ne se voient QUE sur la photo et trop tard :
##  1. une marche de relief au pied d'un carrefour, d'un virage ou d'un T : le
##     kit n'a pas de croisement en pente, la rue fait un ressaut ;
##  2. une marche de plus de deux paliers : la rampe la plus raide du kit
##     (`road-slant-high`) en monte deux, pas trois ;
##  3. un bâtiment à cheval sur deux paliers : il se pose sur le plus haut et
##     flotte au-dessus du plus bas.
## Plus un compte : un rond-point qui n'a pas trouvé ses 3 x 3 cases disparaît
## sans bruit.
## ⚠ `prete` : NE PAS REFAIRE CE QUI VIENT D'ÊTRE FAIT. L'éditeur appelle
## `preparer()` pour rebâtir les morceaux touchés, puis `fautes()` pour
## rafraîchir la vérification — et les deux reconstruisaient chacun leur carte
## et leur liste de bâtiments. Un coup de pinceau coûtait 1 093 ms, dont 720 en
## double. Le banc, lui, appelle sans `prete` et ne change pas.
static func fautes(fiche: Dictionary, prete: Dictionary = {}) -> Array:
	var dessin: Array = fiche["plan"]
	var carte: CarteVille = prete["carte"] if prete.has("carte") else carte_de(fiche)
	var liste: Array = []
	for c in carte.cases.keys():
		if not carte.route(c) or carte.case_prise(c): continue
		var m := carte.masque(c)
		for k in 4:
			var v: Vector2i = c + CarteVille.COTES[k]
			if not carte.route(v): continue
			var ecart: int = carte.palier(v) - carte.palier(c)
			if ecart <= 0: continue
			var selon_axe := ((m & 5) == 0 and (k == 1 or k == 3)) \
				or ((m & 10) == 0 and (k == 0 or k == 2))
			if not selon_axe:
				liste.append({"i": c.x, "j": c.y,
					"texte": "marche de %d au pied d'un croisement" % ecart})
			elif ecart > 2:
				liste.append({"i": c.x, "j": c.y,
					"texte": "marche de %d : le kit monte de deux paliers au plus" % ecart})
	for b in (prete["batiments"] if prete.has("batiments") else batiments(dessin)):
		var niv := -99
		var faute := false
		for a in int(b["w"]):
			for d in int(b["h"]):
				var cc := Vector2i(int(b["i"]) + a, int(b["j"]) + d)
				if not carte.terre(cc): continue
				if niv == -99: niv = carte.palier(cc)
				elif niv != carte.palier(cc): faute = true
		if faute:
			liste.append({"i": int(b["i"]), "j": int(b["j"]),
				"texte": "bâtiment %s à cheval sur deux paliers" % b["lettre"]})
	# LES GROSSES PIÈCES SE COMPTENT. Une pièce refusée ne fait rien et ne dit
	# rien de plus qu'un avertissement dans un journal que personne ne lit ;
	# comparer le nombre de caractères au nombre de pièces posées est le seul
	# contrôle qui tienne, et il tient pour les trois familles.
	var demandes := 0
	for l in dessin:
		var t := String(l)
		demandes += t.count("O") + t.count("(") + t.count("/")
	if demandes != carte.pieces.size():
		liste.append({"i": -1, "j": -1, "texte": "%d grosse(s) pièce(s) demandée(s) (O, ( ou /), %d posée(s) : rond-point 3x3 et courbe large 2x2 veulent des cases de terre au même palier ; la courbe veut en plus une rue à chaque bout, la rampe deux paliers d'écart" % [demandes, carte.pieces.size()]})
	return liste

# ------------------------------------------------------------ construction

## Bâtit un quartier. Le nœud rendu porte déjà son origine et son ANGLE : on
## l'ajoute tel quel, et deux quartiers voisins n'ont aucune raison d'être
## d'accord sur la direction du nord.
static func batir(id: String) -> Node3D:
	var fiche: Dictionary = CATALOGUE.get(id, {})
	if fiche.is_empty():
		push_error("Quartier inconnu : " + id)
		return Node3D.new()
	return batir_fiche(fiche, id)

## ⚠ L'ÉDITEUR passe par ici, pas par une copie : une fiche qu'on vient de
## modifier à la souris doit se bâtir EXACTEMENT comme celle du catalogue,
## sinon l'éditeur montre une ville et le jeu en bâtit une autre.
## ⚠ `zone` EST CE QUI REND LA GRANDE ÎLE POSSIBLE. Pikstown fait 48 375 cases :
## la bâtir d'un bloc coûte six secondes et soixante mille nœuds en natif, donc
## une bonne minute et un onglet mort dans le navigateur. On la bâtit donc par
## MORCEAUX (`VilleMorcelee`), et un morceau n'est rien d'autre que cette même
## fonction bornée à un rectangle de cases. La CARTE, elle, est toujours
## calculée en entier : c'est une table, elle coûte des microsecondes, et sans
## elle une rue ne saurait pas qu'elle continue dans le morceau d'à côté — les
## raccords tomberaient en impasse à chaque bord de morceau.
##
## Une zone vide (taille nulle) veut dire « tout », pour que les vieux appels
## et le banc photo n'aient rien à changer.
## ⚠ `prete` : LA CARTE ET LA LISTE DES BÂTIMENTS, CALCULÉES UNE FOIS. Elles ne
## dépendent que du dessin, pas du morceau qu'on bâtit — mais les recalculer à
## chaque morceau coûtait plus cher que de poser les meshes. Sur Pikstown, cent
## morceaux × (une carte de 28 000 cases + un balayage des bâtiments), c'est la
## différence entre une ville qui se charge et une ville qui rame.
## ⚠ LES BÂTIMENTS SONT RANGÉS PAR SEAUX DE SEIZE CASES. Pikstown en compte
## 15 901 : les parcourir tous pour bâtir un morceau de 24 × 24 — qui en
## contient une centaine — coûtait à lui seul la moitié des 354 ms d'un
## morceau. Un bâtiment est inscrit dans chaque seau qu'il touche ; bâtir un
## morceau ne lit plus que les seaux qui le recouvrent.
const SEAU := 16

## `fenetre` vide = toute la ville. ⚠ LES BÂTIMENTS SE CALCULENT TOUJOURS EN
## ENTIER, eux : un bâtiment est un RECTANGLE de lettres identiques, et le
## découper à la fenêtre en ferait deux là où il n'y en a qu'un — une façade
## coupée en deux au bord d'un morceau. Ils ne coûtent que 68 ms.
static func preparer(fiche: Dictionary, fenetre: Rect2i = Rect2i()) -> Dictionary:
	var carte := carte_de(fiche, fenetre)
	_depots_caches[carte] = _compter_depots(carte, fiche["plan"])
	var tous: Array = batiments(fiche["plan"])
	# ⚠ HORS FENÊTRE, ON N'INDEXE PAS. Les rectangles se calculent en entier —
	# c'est la seule façon d'avoir les bons —, mais ranger les 16 784 en seaux
	# alors qu'on en pose une centaine, c'est le reste du coût d'un geste.
	var liste: Array = tous
	if fenetre.size != Vector2i.ZERO:
		liste = []
		for b in tous:
			var bi := int(b["i"])
			var bj := int(b["j"])
			if bi + int(b["w"]) - 1 < fenetre.position.x: continue
			if bi > fenetre.position.x + fenetre.size.x - 1: continue
			if bj + int(b["h"]) - 1 < fenetre.position.y: continue
			if bj > fenetre.position.y + fenetre.size.y - 1: continue
			liste.append(b)
	var seaux: Dictionary = {}
	for k in liste.size():
		var b: Dictionary = liste[k]
		var i0: int = int(b["i"]) / SEAU
		var j0: int = int(b["j"]) / SEAU
		var i1: int = (int(b["i"]) + int(b["w"]) - 1) / SEAU
		var j1: int = (int(b["j"]) + int(b["h"]) - 1) / SEAU
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var cle := Vector2i(i, j)
				if not seaux.has(cle): seaux[cle] = PackedInt32Array()
				seaux[cle].append(k)
	return {"carte": carte, "batiments": liste, "seaux": seaux}

## Les bâtiments qui peuvent toucher la zone. Une zone vide vaut « tous ».
static func _batiments_de(listes: Array, seaux: Dictionary, zone: Rect2i) -> Array:
	if zone.size == Vector2i.ZERO or seaux.is_empty():
		return listes
	var rangs: Dictionary = {}
	var i0 := zone.position.x / SEAU
	var j0 := zone.position.y / SEAU
	var i1 := (zone.position.x + zone.size.x - 1) / SEAU
	var j1 := (zone.position.y + zone.size.y - 1) / SEAU
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var cle := Vector2i(i, j)
			if not seaux.has(cle): continue
			for k in (seaux[cle] as PackedInt32Array):
				rangs[k] = true
	var sortie: Array = []
	for k in rangs.keys():
		sortie.append(listes[k])
	return sortie

static var _depots_caches: Dictionary = {}

static func depots_de(carte: CarteVille, dessin: Array) -> int:
	if _depots_caches.has(carte): return int(_depots_caches[carte])
	var n := _compter_depots(carte, dessin)
	_depots_caches[carte] = n
	return n

static func _compter_depots(carte: CarteVille, dessin: Array) -> int:
	var n := 0
	for c in carte.cases.keys():
		if _car(dessin, c.x, c.y) == "X": n += 1
	return n

## LES PASSES. Un morceau se bâtit en quatre fois plutôt qu'en une : le coût est
## le même, mais il se répartit sur quatre images au lieu d'en figer une seule.
## Soixante-quatre millisecondes d'un coup, c'est quatre images sautées au
## franchissement de chaque bord de morceau — et on en franchit un toutes les
## trois secondes en voiture. Étalé, ça ne se voit plus : le sol paraît, puis la
## chaussée, puis les façades, puis les arbres. C'est aussi l'ordre dans lequel
## on veut qu'ils paraissent si on regarde.
enum {
	P_SOLS = 1, P_CHAUSSEES = 2, P_BATIMENTS = 4, P_VERDURE = 8,
	P_MOBILIER = 16, P_BATEAUX = 32, P_OBJETS = 64,
}
const P_TOUT := 127

static func batir_fiche(fiche: Dictionary, id: String = "atelier",
		zone: Rect2i = Rect2i(), prete: Dictionary = {}, passes: int = P_TOUT,
		racine: Node3D = null) -> Node3D:
	# ⚠ `racine` non nulle = on CONTINUE un morceau commencé. Sans ce paramètre,
	# chaque passe fabriquerait son propre nœud et le morceau sortirait en
	# quatre exemplaires superposés.
	if racine == null:
		racine = Node3D.new()
		racine.name = "Quartier_" + id
		var org: Vector2 = fiche.get("origine", Vector2.ZERO)
		racine.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(fiche.get("angle", 0.0)))),
			Vector3(org.x * CASE, 0, org.y * CASE))
	var carte: CarteVille = prete.get("carte", null) if prete.has("carte") else carte_de(fiche)
	var listes: Array = prete.get("batiments", [])
	var seaux: Dictionary = prete.get("seaux", {})
	var dessin: Array = fiche["plan"]
	var alea := RandomNumberGenerator.new()
	alea.seed = int(fiche.get("graine", 1))

	if passes & P_SOLS: _poser_sols(racine, carte, dessin, fiche, zone)
	if passes & P_CHAUSSEES: _poser_chaussees(racine, carte, dessin, zone)
	if passes & P_BATIMENTS: _poser_batiments(racine, carte, dessin, fiche, alea, zone, listes, seaux)
	if passes & P_VERDURE: _poser_verdure(racine, carte, dessin, alea, zone)
	if passes & P_MOBILIER: _poser_mobilier(racine, carte, dessin, alea, zone)
	if passes & P_BATEAUX: _poser_bateaux(racine, dessin, alea, zone)
	if passes & P_OBJETS: _poser_objets(racine, carte, fiche, zone)
	return racine

## LE MOBILIER LIBRE — ce que l'éditeur pose À LA MAIN.
##
## ⚠ LE DESSIN NE SAIT PAS TOUT DIRE. Un caractère par case dit « ici, un
## bosquet » ; il ne dira jamais « CE palmier-là, à ce point-là de la case,
## tourné comme ça, de cette taille ». Tant que la ville se peignait au pinceau,
## ça suffisait. Dès qu'on veut poser un modèle précis — et le client le veut :
## « je veux avoir accès à tous les modèles moi-même » — il faut une liste à
## côté du dessin. C'est celle-ci.
##
## ⚠ LE CHEMIN EST RELATIF À `res://modeles/` (« kenney/nature/tree_palm »). Un
## chemin absolu écrit dans une fiche, c'est un dessin qui ne survit pas au
## premier déplacement de dossier.
##
## Une entrée : {m: chemin, i, j: la case, x, z: la fraction dans la case,
## r: l'angle en degrés, h: la hauteur en unités}. La case donne le PALIER —
## poser un objet sur une terrasse et le retrouver enterré après un coup de
## rabot serait la pire façon de perdre une heure de placement.
static func _poser_objets(racine: Node3D, carte: CarteVille, fiche: Dictionary,
		zone: Rect2i = Rect2i()) -> void:
	for o in fiche.get("objets", []):
		var c := Vector2i(int(o["i"]), int(o["j"]))
		if not _dedans(zone, c): continue
		var y := carte.hauteur(c) if carte.terre(c) else NIVEAU_MER
		_objet(racine, "res://modeles/" + String(o["m"]) + ".glb",
			Vector3((float(c.x) + float(o.get("x", 0.5))) * CASE, y,
				(float(c.y) + float(o.get("z", 0.5))) * CASE),
			float(o.get("h", 10.0)), deg_to_rad(float(o.get("r", 0.0))))

## Une zone de taille nulle vaut « toute la grille ».
static func _dedans(zone: Rect2i, c: Vector2i) -> bool:
	return zone.size == Vector2i.ZERO or zone.has_point(c)

## ⚠ LES CASES DE LA ZONE, PAS TOUTES LES CASES FILTRÉES. Première version :
## chaque poseur balayait les 28 581 cases de la ville et jetait celles qui
## n'étaient pas dans le morceau. Quatre poseurs × 28 581 × cent morceaux, ça
## faisait onze millions d'itérations pour poser cinquante mille objets — et
## un morceau coûtait 302 ms, soit un à-coup visible à chaque pas du joueur.
## En parcourant le rectangle et en demandant à la table si la case existe, un
## morceau ne regarde plus que ses 576 cases.
static func _cases_de(carte: CarteVille, zone: Rect2i) -> Array:
	if zone.size == Vector2i.ZERO:
		return carte.cases.keys()
	var liste: Array = []
	for j in range(zone.position.y, zone.position.y + zone.size.y):
		for i in range(zone.position.x, zone.position.x + zone.size.x):
			var c := Vector2i(i, j)
			if carte.cases.has(c): liste.append(c)
	return liste

## ⚠ LE TIRAGE DOIT DÉPENDRE DE LA CASE, PAS DE L'ORDRE. Tant que la ville se
## bâtissait d'un bloc, tirer les hauteurs et les essences à la file donnait un
## résultat stable. Bâtie par morceaux, la même case reçoit un tirage différent
## selon les cases construites avant elle : un pâté rebâti après une retouche
## changeait d'immeubles, et deux morceaux voisins ne se raccordaient plus.
## On resème donc à chaque case, sur (graine, i, j).
static func _resemer(alea: RandomNumberGenerator, base: int, c: Vector2i) -> void:
	alea.seed = hash(Vector3i(base, c.x, c.y))

static func _poser_sols(racine: Node3D, carte: CarteVille, dessin: Array, fiche: Dictionary,
		zone: Rect2i = Rect2i()) -> void:
	var herbe: Color = fiche.get("herbe", Color("#7f9464"))
	var roche: Color = fiche.get("roche", Color("#8b8578"))
	for c in _cases_de(carte, zone):
		var y := carte.hauteur(c)
		var centre := Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE)
		var car := _car(dessin, c.x, c.y)
		var socle := _socle_dun_cran(carte, c)
		# ⚠ UNE CASE PRISE PAR UNE GROSSE PIÈCE GARDE SON SOL — sauf en l'air.
		# Les deux cases d'angle d'une courbe large ne portent pas de chaussée :
		# au sol, ce sont le dedans et le dehors du virage, et il leur faut
		# l'herbe ou le pavé du dessin comme à n'importe quelle case. Les leur
		# refuser laissait un trou carré à côté de chaque bretelle. En
		# revanche, sous une bretelle en l'air, cette même pelouse flotterait.
		var prise := carte.case_prise(c)
		var flotte := prise and _en_lair(carte, c, PILES)
		if not carte.route(c) and not flotte and not carte.case_couverte(c):
			# TOUT CE QUI PORTE UN BÂTIMENT EST PAVÉ. C'était le défaut le plus
			# criant des maquettes : des immeubles posés sur une pelouse. Dans
			# une ville, l'herbe est l'exception, pas le fond.
			var teinte := herbe
			if car in PAVE or _lettre(car) != "": teinte = TEINTE_PAVE
			elif car == ";": teinte = TEINTE_SABLE
			# ⚠ `tile-high` EST une dalle d'un palier de haut (0,25 × 20 unités
			# = exactement 5). Quand une case ne domine que d'UN cran tout son
			# voisinage, elle se dessine donc d'une seule pièce du kit, posée au
			# niveau du bas — au lieu d'une dalle plate plus quatre murets de
			# talus. Même image, quatre maillages de moins, et le socle est
			# celui du kit plutôt qu'une boîte grise.
			var pente: Array = pente_ici(carte, dessin, c)
			if not pente.is_empty():
				var d: Vector2i = pente[0]
				var creux := int(pente[1])
				# La crête regarde le HAUT, c'est-à-dire l'opposé du vide ; la
				# pièce monte vers +X, d'où `atan2(dz, -dx)`.
				_pose(racine, "tile-slant" if creux == 1 else "tile-slantHigh",
					centre - Vector3(0, PALIER * float(creux), 0),
					atan2(float(d.y), -float(d.x)), teinte)
			elif car == "P":
				# ⚠ UN PARKING N'EST PAS UNE PELOUSE PAVÉE. `road-square` est une
				# dalle d'asphalte bordée de trottoir : c'est exactement une aire
				# de stationnement, et c'est la seule tuile du kit que le
				# raccordement de rue ne pourra jamais atteindre — il lui
				# faudrait une case de rue sans AUCUNE voisine de rue.
				_tuile(racine, "road-square", centre, 0, TEINTE_ROUTE)
				if _surplombe(carte, c):
					_tuile(racine, "road-square-barrier", centre, 0, TEINTE_RAIL)
			elif socle > 0:
				_tuile(racine, "tile-high" if socle == 1 else "tile-slantHigh",
					centre - Vector3(0, PALIER * float(socle), 0), 0, teinte)
			else:
				_tuile(racine, "tile-low", centre, 0, teinte)
		# ⚠ LE TALUS DESCEND JUSQU'AU VOISIN LE PLUS BAS, PAS JUSQU'À LA MER.
		# Tant que la ville était plate, les deux revenaient au même : seules
		# les cases du rivage avaient un voisin plus bas. Avec cinq paliers de
		# dénivelé, une terrasse au palier 5 posée contre une terrasse au
		# palier 4 sortait un mur de six étages dont cinq étaient sous terre —
		# des dizaines de milliers de boîtes invisibles, et la moitié du coût
		# d'un morceau.
		var plus_bas := 99
		var sur_mer := false
		for d in CarteVille.COTES:
			var v: Vector2i = c + d
			if not carte.cases.has(v):
				sur_mer = true
			else:
				plus_bas = mini(plus_bas, carte.palier(v))
		# ⚠ PAS DE TALUS SOUS UN SOCLE : `tile-high` EST le mur de ce palier-là.
		# Les poser tous les deux donnait deux surfaces au même endroit, et le
		# rendu choisissait au hasard laquelle montrer d'un pixel à l'autre.
		var plate := carte.route(c) or flotte or pente_ici(carte, dessin, c).is_empty()
		if (sur_mer or plus_bas < carte.palier(c)) \
				and plate and not (socle > 0 and not carte.route(c)):
			var fond := -2.6 if sur_mer else float(plus_bas) * PALIER
			# ⚠ UNE ROUTE EN L'AIR SE POSE SUR DES PILES, PAS SUR UN REMBLAI.
			if (carte.route(c) or prise) and (car == "=" or flotte or _en_lair(carte, c, PILES)):
				_pilotis(racine, centre, y, fond)
			else:
				_falaise(racine, centre, y, roche, fond)

## LE TALUS ENHERBÉ. Une terrasse dont UN SEUL côté descend, l'autre restant de
## plain-pied, n'est pas une falaise : c'est une pente. Le kit a la pièce —
## `tile-slant` monte d'un palier, `tile-slantHigh` de deux, tous deux VERS +X
## sans rotation (mesuré : leurs sommets hauts sont TOUS à X = +0,50, comme
## `road-slant`). Posée au niveau du bas et tournée pour que sa crête regarde le
## haut, elle remplace le mur de roche par un remblai — et c'est ce qui fait
## qu'un dénivelé se lit comme du terrain plutôt que comme une découpe.
##
## ⚠ RIEN NE SE POSE SUR UNE PENTE. Une case en pente n'a pas de sol plat :
## l'arbre qu'on y sème flotte d'un côté et s'enterre de l'autre. Elle est donc
## réservée à la pelouse nue, et `_poser_verdure` la saute — les deux passes
## posent la MÊME question à la MÊME fonction, sinon elles se contredisent.
## Retourne [direction du bas, dénivelé en paliers], ou [] s'il n'y a pas de
## pente ici.
static func pente_ici(carte: CarteVille, dessin: Array, c: Vector2i) -> Array:
	if _car(dessin, c.x, c.y) != ",": return []
	var n := carte.palier(c)
	var bas := Vector2i.ZERO
	var creux := 0
	for k in 4:
		var d: Vector2i = CarteVille.COTES[k]
		if not carte.cases.has(c + d): return []
		var q := carte.palier(c + d)
		if q > n: return []
		if q == n: continue
		if creux > 0: return []              # deux côtés qui tombent : un éperon
		if n - q > 2: return []              # trop raide pour la pièce du kit
		creux = n - q
		bas = d
	if creux == 0: return []
	# L'opposé du vide doit être de plain-pied, sinon c'est une crête.
	if carte.palier(c - bas) != n: return []
	return [bas, creux]

## Vrai si la case ne domine son voisinage QUE D'UN CRAN : aucune voisine ne
## manque (au bord de l'eau il faut une vraie falaise), aucune n'est plus haute,
## et au moins une est un palier plus bas.
## ⚠ La première version exigeait les QUATRE voisines à n−1. Sur une ville
## terrassée, ça n'arrive jamais : une terrasse a toujours au moins une voisine
## de son niveau. Zéro case sur soixante mille — le banc d'inventaire l'a dit
## avant que ça ne se voie.
## Retourne le nombre de crans (1 ou 2) dont la case domine son voisinage sans
## jamais être dominée, ou 0. Le kit a la pièce portée pour l'un comme pour
## l'autre : `tile-high` et `road-slant-flat` montent d'un palier,
## `tile-slantHigh` et `road-slant-flat-high` de deux.
static func _socle_dun_cran(carte: CarteVille, c: Vector2i) -> int:
	var n := carte.palier(c)
	var creux := 0
	for d in CarteVille.COTES:
		var v: Vector2i = c + d
		if not carte.cases.has(v): return 0
		var q := carte.palier(v)
		if q > n or q < n - 2: return 0
		creux = maxi(creux, n - q)
	return creux

## ⚠ UNE ROUTE QUI S'ÉLÈVE NE S'APPUIE PAS SUR UN TERRE-PLEIN. Le kit dessine
## ses routes surélevées sur POTEAUX ; un mur de roche pleine sous une avenue en
## l'air se lit comme une erreur de terrain, pas comme un ouvrage. Sous une case
## de rue qui a le vide DES DEUX CÔTÉS — c'est ça, un franchissement — on pose
## donc quatre piles de béton au lieu du talus.
##
## ⚠ ET SEULEMENT DES DEUX CÔTÉS. La première règle regardait le voisin le plus
## bas : une rue qui longeait simplement le BORD d'une terrasse passait sur
## piles, alors que la moitié de sa case repose sur la terre ferme — on voyait
## le jour sous une route posée par terre. Un viaduc a le vide au nord ET au
## sud, ou à l'est ET à l'ouest ; le reste est du remblai, et le remblai a bien
## le droit d'exister.
const PILES := 2                       ## le dénivelé, en paliers, qui fait passer aux piles
const COTE_PILE := 0.13                ## la section d'une pile, en cases
const ECART_PILE := 0.29               ## son écart au centre, en cases

static func _en_lair(carte: CarteVille, c: Vector2i, seuil: int) -> bool:
	var n := carte.palier(c)
	var vide: Array = []
	for d in CarteVille.COTES:                     # N, E, S, O
		var v: Vector2i = c + d
		vide.append(not carte.cases.has(v) or carte.palier(v) <= n - seuil)
	return (vide[0] and vide[2]) or (vide[1] and vide[3])

static var _pile: BoxMesh = null
static var _beton: StandardMaterial3D = null

static func _pilotis(racine: Node3D, centre: Vector3, y: float, fond: float) -> void:
	if _pile == null:
		_pile = BoxMesh.new()
		_pile.size = Vector3(COTE_PILE * CASE, 1.0, COTE_PILE * CASE)
	if _beton == null:
		_beton = StandardMaterial3D.new()
		_beton.albedo_color = Color("#9c9992")
		_beton.roughness = 1.0
	# La pile part SOUS le tablier : la chaussée fait déjà son épaisseur, et une
	# pile qui monte jusqu'au ras de la route lui mange le trottoir.
	var haut := y - PALIER * 0.16
	if haut - fond < 1.0: return
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			var n := MeshInstance3D.new()
			n.mesh = _pile
			n.material_override = _beton
			n.transform = Transform3D(Basis().scaled(Vector3(1.0, haut - fond, 1.0)),
				centre + Vector3(a * ECART_PILE * CASE,
					(haut + fond) * 0.5 - y, b * ECART_PILE * CASE))
			racine.add_child(n)

## LA FALAISE. Un seul bloc du sol jusqu'à la mer donnait un mur de plâtre de
## quarante unités : la ville avait l'air posée sur un socle de maquette. On la
## dessine en STRATES d'un palier, chacune rentrée d'un poil et un ton plus
## sombre que celle du dessus — c'est ce qui fait lire une falaise plutôt
## qu'une découpe, et ça ne coûte que quelques boîtes de plus par case de bord.
## ⚠ UNE MATIÈRE ET UN MAILLAGE PARTAGÉS, PAS UN PAR BOÎTE. Chaque strate de
## talus fabriquait son propre `BoxMesh` et son propre `StandardMaterial3D` :
## sur une ville plate ça passait (seul le rivage a des talus), sur une ville à
## cinq paliers c'était la moitié du temps de construction d'un morceau, et
## autant d'appels de rendu que de boîtes. Il n'y a que huit teintes possibles,
## et une seule boîte.
static var _boites: BoxMesh = null
static var _roches: Dictionary = {}

static func _boite_talus() -> BoxMesh:
	if _boites == null:
		_boites = BoxMesh.new()
		_boites.size = Vector3(CASE, 1.0, CASE)
	return _boites

static func _teinte_roche(roche: Color, strate: int) -> Material:
	var cle := roche.to_html() + str(strate)
	if _roches.has(cle): return _roches[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = roche.darkened(0.06 + 0.055 * float(strate))
	m.roughness = 1.0
	_roches[cle] = m
	return m

static func _falaise(racine: Node3D, centre: Vector3, y: float, roche: Color,
		fond: float = -2.6) -> void:
	var bas := fond
	var strates := maxi(1, ceili((y - bas) / PALIER))
	for k in strates:
		var haut: float = y - float(k) * PALIER
		var sous: float = maxf(bas, haut - PALIER)
		var n := MeshInstance3D.new()
		n.mesh = _boite_talus()
		n.material_override = _teinte_roche(roche, k)
		var e := 1.0 - 0.028 * float(k)     # chaque strate rentre un peu
		n.transform = Transform3D(Basis().scaled(Vector3(e, haut - sous, e)),
			centre + Vector3(0, (haut + sous) * 0.5 - y, 0))
		racine.add_child(n)

const TEINTE_RAIL := Color("#c9ccd2")

## Vrai si la case surplombe : un voisin manque (la mer) ou tombe d'au moins
## deux paliers. C'est la condition de la glissière — et deux paliers, c'est
## dix unités, soit cinq mètres : de quoi se tuer, donc de quoi mettre un rail.
const SURPLOMB := 2

static func _surplombe(carte: CarteVille, c: Vector2i) -> bool:
	var n := carte.palier(c)
	for d in CarteVille.COTES:
		var v: Vector2i = c + d
		if not carte.cases.has(v) or carte.palier(v) <= n - SURPLOMB:
			return true
	return false

## ⚠ LA DALLE SOUS LES TUILES AJOURÉES. Une case de rue ne recevait aucun sol :
## la chaussée ÉTAIT le plancher. Ça marche tant que la tuile remplit son carré
## — et `CarteVille.AJOUREES` dit lesquelles ne le font pas. Sous celles-là, le
## joueur voyait la mer dans le coin du virage ou derrière la raquette d'une
## impasse. On glisse donc une dalle de trottoir dessous.
##
## ⚠ DE COMBIEN ON LA DESCEND : DE TOUTE SON ÉPAISSEUR, PAS D'UN POIL. Une
## tuile du kit n'est pas plate — son BITUME est à Y = 0 et ses TROTTOIRS
## dépassent de 0,02 unité de modèle, soit 0,4 unité de jeu une fois à
## l'échelle de la case. `tile-low` fait exactement cette épaisseur-là. Rentrée
## de 0,08, la dalle avait donc son dessus 0,32 unité AU-DESSUS du bitume
## qu'elle était censée soutenir : elle le recouvrait, et toutes les tuiles
## ajourées — chaque impasse en raquette, chaque courbe large — sortaient en
## ruban gris clair au lieu d'une chaussée. Le trou était bouché, la route
## avait disparu. On descend donc la dalle de son épaisseur plus une marge.
const EPAISSEUR_TUILE := 0.02 * CASE      ## le relief d'une tuile du kit, à l'échelle
const SOUS_DALLE := EPAISSEUR_TUILE + 0.05

## ⚠ CE QUI SE DÉCIDE ICI ET PAS DANS `CarteVille.tuile()`. La carte ne connaît
## que le raccordement : qui touche qui, et à quel palier. Elle ne sait pas ce
## qu'il y a DERRIÈRE le trottoir — un pavillon, un parking, un hangar, la mer.
## Or c'est ça qui choisit entre une rue nue, une rue à bateaux d'accès, une
## contre-allée de parking et un tablier de pont. Le dessin tranche, donc la
## substitution se fait ici, où on l'a sous la main.
##
## Toutes ces tuiles sont des DROITS de même raccordement et de même rotation
## (mesuré : elles remplissent le même carré, seul le bord change) — les
## échanger ne casse aucun raccord.
static func _droit_special(dessin: Array, c: Vector2i, quarts: int) -> Array:
	var car := _car(dessin, c.x, c.y)
	if car == "=":
		# LE PONT : le kit a son tablier à parapets, autrement plus lisible
		# qu'une chaussée posée en l'air.
		return ["road-bridge", quarts]
	var selon_x := quarts % 2 == 0
	# Le « côté » d'une rue : ses deux voisines perpendiculaires à la voie.
	var d: Vector2i = CarteVille.S if selon_x else CarteVille.E
	var plus := _car(dessin, c.x + d.x, c.y + d.y)
	var moins := _car(dessin, c.x - d.x, c.y - d.y)
	# ⚠ `road-driveway-single` a SON bateau du côté +Z sans rotation (mesuré :
	# la bordure s'abaisse à Z = +0,4 et nulle part ailleurs). Deux quarts de
	# tour l'envoient de l'autre côté ; la version double en a des deux.
	# ⚠ L'ORDRE COMPTE. Testées après les lettres, les bretelles de dépôt ne
	# sortaient jamais : les trente rues qui longent un dépôt ont presque
	# toujours un bâtiment de l'autre côté, et le bateau d'accès gagnait.
	# ⚠ UN CHANTIER MANGE UNE VOIE. `road-straight-half` n'est qu'une
	# demi-chaussée : le long d'un `%`, c'est la moitié de rue qui reste
	# ouverte, et les cônes du chantier disent pourquoi. C'est aussi la seule
	# situation du dessin qui justifie une demi-tuile.
	if plus == "%": return ["road-straight-half", quarts]
	if moins == "%": return ["road-straight-half", posmod(quarts + 2, 4)]
	if plus == "X": return ["road-side-entry", quarts]
	if moins == "X": return ["road-side-exit", quarts]
	if plus == "~" or moins == "~": return ["road-straight-half", quarts]
	var p_bati := _lettre(plus) != ""
	var m_bati := _lettre(moins) != ""
	if p_bati and m_bati:
		return ["road-driveway-double", quarts]
	if p_bati:
		return ["road-driveway-single", quarts]
	if m_bati:
		return ["road-driveway-single", posmod(quarts + 2, 4)]
	# LA CONTRE-ALLÉE : le long d'un parking, la rue s'ouvre. `road-side` a son
	# accotement du côté +Z, comme le bateau.
	if plus == "P": return ["road-side", quarts]
	if moins == "P": return ["road-side", posmod(quarts + 2, 4)]
	return []

static func _poser_chaussees(racine: Node3D, carte: CarteVille, dessin: Array,
		zone: Rect2i = Rect2i()) -> void:
	for c in _cases_de(carte, zone):
		if not carte.route(c) or carte.case_prise(c): continue
		var fiche: Array = carte.tuile(c)
		var nom := String(fiche[0])
		var ou_bas := 0
		if nom == "road-straight":
			var sp: Array = _droit_special(dessin, c, int(fiche[1]))
			if not sp.is_empty(): fiche = sp
			elif CarteVille.passage_ici(carte, c): fiche = ["road-crossing", int(fiche[1])]
			# ⚠ `road-slant-flat` N'EST PAS UNE RAMPE : c'est un tronçon droit
			# PORTÉ d'un palier (0,27 × 20 ≈ 5 unités), sa version `-high` de
			# deux. Posé au niveau du BAS, il fait à lui seul la chaussée et son
			# remblai — une pièce du kit au lieu d'une dalle plus quatre murets.
			else:
				var porte := _socle_dun_cran(carte, c)
				if porte > 0:
					fiche = ["road-slant-flat" if porte == 1 else "road-slant-flat-high",
						int(fiche[1])]
					ou_bas = porte
			nom = String(fiche[0])
		var ou := carte.centre(c)
		if ou_bas > 0: ou -= Vector3(0, PALIER * float(ou_bas), 0)
		if CarteVille.AJOUREES.has(nom):
			_tuile(racine, "tile-low", ou - Vector3(0, SOUS_DALLE, 0), 0, TEINTE_PAVE)
		_tuile(racine, nom, ou, int(fiche[1]), TEINTE_ROUTE)
		# LA GLISSIÈRE DIT LE VIDE. Une rue au bord de l'eau ou en surplomb de
		# deux paliers reçoit ses rails ; c'est le seul repère qui fasse LIRE un
		# dénivelé de loin, là où une falaise vue de dessus ne se voit pas.
		if _surplombe(carte, c):
			var rail: String = CarteVille.BARRIERES.get(nom, "")
			if rail != "": _tuile(racine, rail, ou, int(fiche[1]), TEINTE_RAIL)
			# ⚠ UNE GLISSIÈRE A UN BOUT. Là où la case suivante n'en porte pas,
			# le rail s'arrête net dans le vide ; le kit a la pièce qui le
			# referme, et c'est le genre de détail qu'on ne remarque que quand
			# il manque.
			if rail == "road-straight-barrier":
				var axe: Vector2i = CarteVille.E if int(fiche[1]) % 2 == 0 else CarteVille.S
				for sens in [1, -1]:
					var v: Vector2i = c + axe * sens
					if carte.route(v) and _surplombe(carte, v): continue
					_tuile(racine, "road-straight-barrier-end", ou,
						posmod(int(fiche[1]) + (0 if sens > 0 else 2), 4), TEINTE_RAIL)
	for p in carte.pieces:
		var taille := CarteVille.taille_de(p)
		var coin := Vector2i(int(p["i"]), int(p["j"]))
		if not _dedans(zone, coin): continue
		var nom_p := String(p["t"])
		# ⚠ UNE PIÈCE EN PENTE SE POSE AU NIVEAU DE SON BOUT LE PLUS BAS. Son
		# coin nord-ouest n'est pas forcément ce bout-là — une rampe qui monte
		# vers le nord a son coin en haut. On prend donc le MINIMUM.
		var plancher := 9999
		for a in taille.x:
			for b in taille.y:
				plancher = mini(plancher, carte.palier(coin + Vector2i(a, b)))
		var centre_piece := Vector3((float(coin.x) + float(taille.x) * 0.5) * CASE,
			float(plancher) * PALIER, (float(coin.y) + float(taille.y) * 0.5) * CASE)
		# Une grosse pièce ajourée (le rond-point, la courbe large nue) demande
		# une dalle PAR CASE qu'elle couvre : sa dalle à elle serait à sa
		# taille, donc trois fois trop grande pour `tile-low`. En l'air, on ne
		# la pose pas — un carré de trottoir flottant sous une bretelle est
		# pire que le trou qu'il bouche.
		# ⚠ LA DALLE NE VA QUE SOUS LA CHAUSSÉE. Les cases d'angle d'une courbe
		# ont déjà leur sol (voir `_poser_sols`) ; leur ajouter une dalle
		# refaisait le carré blanc qu'on vient d'ôter.
		if CarteVille.AJOUREES.has(nom_p) and not _en_lair(carte, coin, PILES):
			for a in taille.x:
				for b in taille.y:
					var cc := coin + Vector2i(a, b)
					if not carte.route(cc): continue
					_tuile(racine, "tile-low", carte.centre(cc) - Vector3(0, SOUS_DALLE, 0),
						0, TEINTE_PAVE)
		_tuile(racine, nom_p, centre_piece, int(p["q"]), TEINTE_ROUTE)
		# LA GLISSIÈRE D'UNE GROSSE PIÈCE. Une bretelle au bord du vide sans
		# rambarde ne se lit pas comme un ouvrage : elle se lit comme un bogue.
		# ⚠ ON REGARDE TOUTES SES CASES, pas seulement son coin. Une courbe
		# large fait deux cases de côté : c'est presque toujours son autre bout
		# qui longe l'eau, et n'interroger que le coin nord-ouest revenait à
		# n'en border aucune.
		var au_bord := false
		for a in taille.x:
			for b in taille.y:
				if _surplombe(carte, coin + Vector2i(a, b)): au_bord = true
		if au_bord:
			var rail_p: String = CarteVille.BARRIERES.get(nom_p, "")
			if rail_p != "":
				_tuile(racine, rail_p, centre_piece, int(p["q"]), TEINTE_RAIL)

## ⚠ Une pièce du kit EST DÉJÀ à sa taille : `road-roundabout` mesure trois
## unités de côté. On multiplie par UNE case, jamais par son côté — le rond-
## point est sorti une fois à neuf cases de large, et ça s'est vu tout de suite.
static func _pose(parent: Node3D, nom: String, ou: Vector3, angle: float,
		teinte: Color) -> void:
	var chemin := ROUTES + nom + ".glb"
	if not ResourceLoader.exists(chemin): return
	if inventaire: _noter(chemin)
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * CASE), ou)
	parent.add_child(n)

static func _tuile(parent: Node3D, nom: String, ou: Vector3, quarts: int, teinte: Color) -> void:
	var chemin := ROUTES + nom + ".glb"
	if not ResourceLoader.exists(chemin): return
	if inventaire: _noter(chemin)
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(quarts)).scaled(Vector3.ONE * CASE), ou)
	parent.add_child(n)

static var _matieres: Dictionary = {}

static func _matiere(chemin: String, teinte: Color) -> Material:
	var cle := chemin + teinte.to_html()
	if _matieres.has(cle): return _matieres[cle]
	var m := FormesCarnage.matiere_kenney(chemin).duplicate()
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("teinte", teinte)
	elif m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = teinte
	_matieres[cle] = m
	return m

## Un bâtiment remplit SON rectangle, moins un retrait. Le retrait est ce qui
## fait qu'on voit le jour entre deux immeubles ; sans lui le pâté n'est plus
## qu'un bloc, et avec trop, la ville redevient un lotissement.
const RETRAIT := 0.10

## ⚠ L'EMPRISE MAXIMALE D'UN MODÈLE, en cases. Un pavillon Kenney est dessiné
## pour tenir sur une case ; étiré sur quatre, il devient un bungalow de
## quarante mètres avec une porte de garage de dix — c'est exactement ce qui
## rendait la vieille ville risible. Au-delà de son emprise, un rectangle de
## lettres est DÉCOUPÉ en autant de bâtiments qu'il faut : `MMMM` sur deux
## rangées ne fait pas une maison géante, il fait huit maisons mitoyennes.
const EMPRISES := {"T": 3.0, "B": 3.0, "C": 2.0, "V": 1.0, "M": 1.0, "H": 4.0,
	"+": 99.0, "F": 99.0, "S": 99.0, "$": 99.0}

static func _poser_batiments(racine: Node3D, carte: CarteVille, dessin: Array,
		fiche: Dictionary, alea: RandomNumberGenerator, zone: Rect2i = Rect2i(),
		listes: Array = [], seaux: Dictionary = {}) -> void:
	var etages: Dictionary = fiche.get("hauteurs", {})
	var base := int(fiche.get("graine", 1))
	var voulus: Array = _batiments_de(listes, seaux, zone) if not listes.is_empty() \
		else batiments(dessin)
	for b in voulus:
		if not _dedans(zone, Vector2i(int(b["i"]), int(b["j"]))): continue
		_resemer(alea, base, Vector2i(int(b["i"]), int(b["j"])))
		var lettre := String(b["lettre"])
		var style: int = FAMILLES.get(lettre, PlanVille.F_COMMERCE)
		var coin := Vector2i(int(b["i"]), int(b["j"]))
		var w := float(b["w"])
		var h := float(b["h"])
		# À cheval sur deux paliers, on prend le PLUS HAUT : un immeuble à
		# moitié enterré vaut mieux qu'un immeuble sur pilotis invisibles.
		var niveau := 0
		var pose := true
		for a in int(w):
			for c in int(h):
				var cc := coin + Vector2i(a, c)
				if not carte.terre(cc) or carte.case_prise(cc): pose = false
				niveau = maxi(niveau, carte.palier(cc))
		if not pose: continue
		if SERVICES.has(lettre):
			var svc: Array = SERVICES[lettre]
			var lg := (w - RETRAIT * 2.0) * CASE
			var pf := (h - RETRAIT * 2.0) * CASE
			var ht := minf(lg, pf) * float(svc[1])
			var ch := "res://modeles/" + String(svc[0]) + ".glb"
			if ResourceLoader.exists(ch):
				if inventaire: _noter(ch)
				var ns := MeshInstance3D.new()
				ns.mesh = FormesCarnage.maillage_batiment(ch)
				ns.material_override = FormesCarnage.matiere_kenney(ch)
				ns.transform = Transform3D(Basis().scaled(Vector3(lg, ht, pf)),
					Vector3((float(coin.x) + w * 0.5) * CASE, float(niveau) * PALIER,
						(float(coin.y) + h * 0.5) * CASE))
				racine.add_child(ns)
			continue
		var bornes: Array = etages.get(lettre, [14.0, 26.0])
		var emax: float = float(EMPRISES.get(lettre, 3.0))
		var na := maxi(1, ceili(w / emax - 0.001))
		var nb := maxi(1, ceili(h / emax - 0.001))
		var pas_a := w / float(na)
		var pas_b := h / float(nb)
		var precedent := ""
		for a in na:
			for c in nb:
				var hauteur: float = alea.randf_range(float(bornes[0]), float(bornes[1]))
				var larg := (pas_a - RETRAIT * 2.0) * CASE
				var prof := (pas_b - RETRAIT * 2.0) * CASE
				if larg < 3.0 or prof < 3.0: continue
				var chemin := FormesCarnage.batiment_kenney(style, minf(larg, prof), hauteur,
					alea.randi(), precedent)
				if chemin == "": continue
				precedent = chemin
				if inventaire: _noter(chemin)
				var teintes: Array = PlanVille.TEINTES.get(style, [Color.WHITE])
				var teinte: Color = teintes[alea.randi() % teintes.size()]
				var n := MeshInstance3D.new()
				n.mesh = FormesCarnage.maillage_batiment(chemin)
				n.material_override = _matiere(chemin, teinte)
				n.transform = Transform3D(Basis().scaled(Vector3(larg, hauteur, prof)),
					Vector3((float(coin.x) + (float(a) + 0.5) * pas_a) * CASE,
						float(niveau) * PALIER,
						(float(coin.y) + (float(c) + 0.5) * pas_b) * CASE))
				racine.add_child(n)

const ARBRES := ["nature/tree_default", "nature/tree_oak", "nature/tree_fat",
	"nature/tree_detailed", "nature/tree_cone"]
## ⚠ LE PALMIER NE POUSSE PAS N'IMPORTE OÙ. Il est réservé au sable : semé avec
## les autres, il donnait des cocotiers devant les tours de bureaux.
const PALMIERS := ["nature/tree_palm", "nature/tree_palm", "nature/tree_cone"]
## Ce qui se pose sur une pelouse nue sans en faire un parc : des touffes et
## des cailloux, rarement. Une case sur six, pas une sur une.
const FRICHE := [
	["nature/grass_large", 2.0], ["nature/plant_bush", 2.4],
	["nature/plant_bushDetailed", 2.6], ["nature/rock_smallA", 2.0],
	["nature/rock_largeA", 4.2], ["nature/grass_large", 2.0],
]
## LE MOBILIER D'UNE ESPLANADE. Une place pavée vide n'est pas une place : c'est
## un parking sans voitures. Bancs, jardinières, parasols, une colonne de temps
## en temps — ça et rien d'autre, une esplanade n'est pas un square.
const ESPLANADE := [
	["nature/bench", 2.0], ["nature/bench", 2.0], ["pavillons/planter", 1.6],
	["batiments/detail-parasol-a", 4.6], ["batiments/detail-parasol-b", 4.6],
	["nature/plant_bushLarge", 3.0],
]
## LES GROSSES PIÈCES D'UN PORT ou d'une zone industrielle. Elles ne sortent
## qu'à la place d'une cuve, sous le même plafond : trois châteaux d'eau côte à
## côte, ça ne fait pas une usine, ça fait une erreur.
## LE JARDIN D'UNE MAISON. Ce qui se pose sur une pelouse COLLÉE À UN PAVILLON :
## une allée, un bout de clôture, une jardinière, un arbre d'agrément. Sur une
## pelouse isolée, ce serait du mobilier sans maison — d'où le test de voisinage.
## ⚠ Les allées sont PLATES (un centième d'unité de haut) : leur « hauteur »
## demandée à `_objet` ne règle pas leur épaisseur mais leur ÉCHELLE, donc leur
## emprise au sol. 0,45 donne une allée d'environ huit unités, soit quatre
## mètres — la largeur d'une entrée de garage.
const JARDIN := [
	["pavillons/path-short", 0.45], ["pavillons/path-long", 0.45],
	["pavillons/path-stones-short", 0.45], ["pavillons/path-stones-long", 0.45],
	["pavillons/path-stones-messy", 0.45], ["pavillons/driveway-short", 0.45],
	["pavillons/driveway-long", 0.45], ["pavillons/planter", 1.8],
	["pavillons/tree-small", 7.5], ["pavillons/tree-large", 11.0],
]
## LES CLÔTURES, en pièces de longueurs différentes : le kit en donne neuf, et
## une rue de pavillons tous ceints du même modèle se voit tout de suite.
const CLOTURES := [
	["pavillons/fence", 2.6], ["pavillons/fence-low", 1.7],
	["pavillons/fence-1x2", 2.6], ["pavillons/fence-1x3", 2.6],
	["pavillons/fence-1x4", 2.6], ["pavillons/fence-2x2", 2.6],
	["pavillons/fence-2x3", 2.6], ["pavillons/fence-3x2", 2.6],
	["pavillons/fence-3x3", 2.6],
]
## LA MARQUISE D'UNE BOUTIQUE. Elle se colle à la FAÇADE, tournée vers la rue :
## le modèle est dessiné à Z ≈ +0,17, c'est-à-dire déjà en saillie — il suffit
## de le tourner vers la voie, pas de le décaler.
const MARQUISES := [
	["batiments/detail-awning", 7.0], ["batiments/detail-awning-wide", 12.0],
	["batiments/detail-overhang", 8.0], ["batiments/detail-overhang-wide", 14.0],
]

const OUVRAGES := [
	["industriel/detail-tank-large", 19.0], ["industriel/detail-tank-large", 19.0],
	["industriel/water-tower", 26.0], ["industriel/chimney-large", 30.0],
	["industriel/chimney-medium", 24.0], ["industriel/windmill", 44.0],
	["industriel/detail-tank", 11.0], ["industriel/chimney-basic", 16.0],
	["industriel/windmill-low", 34.0], ["industriel/building-d", 24.0],
	["industriel/building-f", 28.0], ["industriel/building-n", 32.0],
]

## Le décor de sol : ce qui n'est ni rue ni bâtiment mais qui empêche une case
## d'être un trou. Un pâté vide se lit comme un bogue, et un port sans
## conteneurs n'est qu'un lotissement au bord de l'eau.
## ⚠ Les proportions, pas les modèles : à l'échelle du jeu une voiture fait dix
## unités de long, donc une unité vaut à peu près un demi-mètre. Un conteneur
## de deux mètres soixante fait SIX unités, pas neuf ; et une cuve à dix mètres
## en fait vingt — d'où la règle de ne pas en semer partout, sinon le port
## n'est plus qu'un champ de citernes plus hautes que ses hangars.
const DEPOT := [
	["industriel/shipping-container-a", 6.0], ["industriel/shipping-container-b", 6.0],
	["industriel/shipping-container-c", 6.0], ["industriel/shipping-container-a", 6.0],
	["industriel/shipping-container-b", 6.0], ["industriel/shipping-container-c", 6.0],
	["industriel/shipping-container-a", 6.0], ["industriel/shipping-container-b", 6.0],
	["industriel/solar-panel-flat", 2.4],
	["industriel/solar-panel-landscape-group", 3.4],
	["industriel/solar-panel-portrait-group", 4.2],
	["bateaux/cargo-pile-a", 5.0], ["bateaux/cargo-pile-b", 5.0],
	["industriel/chimney-small", 7.0],
	["industriel/solar-panel-landscape", 2.6], ["industriel/solar-panel-portrait", 3.0],
]
## ⚠ `urbain/`, PAS `routes/`. Ces cinq-là étaient cherchés dans le dossier des
## tuiles de chaussée, où ils n'ont jamais été : `_objet` ne trouvait rien et
## sortait EN SILENCE, si bien que les 201 cases de chantier de la ville ne
## posaient pas un cône. Trouvé en photographiant le pinceau « Chantier »
## (`outils/vignettes.gd`) : sa vignette est sortie vide, et une vignette vide
## ne se discute pas. Le cinquième modèle, `construction-light`, n'existe dans
## aucun dossier du kit — remplacé par un deuxième cône plutôt qu'inventé.
const CHANTIER := [
	["urbain/construction-barrier", 4.0], ["urbain/construction-cone", 2.6],
	["urbain/construction-fence", 6.0], ["urbain/construction-cone", 2.6],
	["urbain/dumpster", 5.0],
	# Le tracteur est l'engin de chantier du kit : il n'y a pas de pelleteuse.
	["voitures/tractor", 9.0],
]

## Une cuve n'a le droit de sortir que si aucune autre n'est à moins de trois
## cases, et pas plus d'une pour dix cases de dépôt. Trois cuves côte à côte,
## ça ne fait pas un port : ça fait une usine à gaz.
const ECART_CUVES := 3
const PART_CUVES := 0.10

static func _cuve_ici(c: Vector2i, cuves: Array, alea: RandomNumberGenerator) -> bool:
	for v in cuves:
		if absi((v as Vector2i).x - c.x) < ECART_CUVES and absi((v as Vector2i).y - c.y) < ECART_CUVES:
			return false
	return alea.randf() < 0.5

static func _poser_verdure(racine: Node3D, carte: CarteVille, dessin: Array,
		alea: RandomNumberGenerator, zone: Rect2i = Rect2i()) -> void:
	var cuves: Array = []
	# ⚠ Le plafond de cuves est GLOBAL — il se compte sur toute la ville, pas
	# sur le morceau —, mais le recompter à chaque morceau coûtait un balayage
	# complet de plus. Il vient donc de `preparer`.
	var plafond := maxi(1, int(float(depots_de(carte, dessin)) * PART_CUVES))
	for c in _cases_de(carte, zone):
		_resemer(alea, 7717, c)
		var car := _car(dessin, c.x, c.y)
		var y := carte.hauteur(c)
		match car:
			"^":
				for k in 3:
					_objet(racine, ARBRES[alea.randi() % ARBRES.size()], _dans(c, y, alea),
						alea.randf_range(9.0, 15.0), alea.randf() * TAU)
			"\'":
				for k in 5:
					_objet(racine, "nature/plant_bushLarge", _dans(c, y, alea),
						alea.randf_range(2.2, 3.4), alea.randf() * TAU)
			"X":
				# Les conteneurs s'alignent sur la case, pas au hasard : un
				# dépôt, ça s'empile en rangées, sinon on dirait une décharge.
				if cuves.size() < plafond and _cuve_ici(c, cuves, alea):
					cuves.append(c)
					var o: Array = OUVRAGES[alea.randi() % OUVRAGES.size()]
					_objet(racine, String(o[0]),
						Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE),
						float(o[1]))
					continue
				for k in 3:
					for l in 2:
						if alea.randf() < 0.28: continue
						var f: Array = DEPOT[alea.randi() % DEPOT.size()]
						_objet(racine, String(f[0]),
							Vector3((float(c.x) + 0.2 + 0.3 * float(k)) * CASE, y,
								(float(c.y) + 0.28 + 0.44 * float(l)) * CASE),
							float(f[1]), 0.0)
			"%":
				for k in 4:
					var g: Array = CHANTIER[alea.randi() % CHANTIER.size()]
					_objet(racine, String(g[0]), _dans(c, y, alea), float(g[1]), alea.randf() * TAU)
			"C", "c":
				# LA MARQUISE ne se pose que sur la façade qui DONNE SUR LA RUE.
				# Un store au fond d'un pâté, personne ne le voit, et il traverse
				# l'immeuble d'à côté.
				var rue := _vers(dessin, c, CHAUSSEE)
				if rue != Vector2i.ZERO and alea.randf() < 0.42:
					var q: Array = MARQUISES[alea.randi() % MARQUISES.size()]
					_objet(racine, String(q[0]),
						centre_de(c, y) + Vector3(rue.x, 0, rue.y) * (CASE * 0.30),
						float(q[1]), atan2(float(rue.x), float(rue.y)))
			"?":
				# LA CABINE donne les missions : elle se plante au bord du
				# trottoir, tournée vers la rue, jamais au milieu d'une place.
				var vr := _vers(dessin, c, CHAUSSEE)
				_objet(racine, "res://modeles/piksl/cabine_telephonique.glb",
					centre_de(c, y) + Vector3(vr.x, 0, vr.y) * (CASE * 0.26), 5.6,
					atan2(float(vr.x), float(vr.y)))
			"*":
				# LA CAISSE À RAMASSER, posée à plat au milieu de sa case : on
				# doit pouvoir rouler dessus.
				_objet(racine, "res://modeles/piksl/caisse_a_ramasser.glb",
					centre_de(c, y), 3.2, alea.randf() * TAU)
			"P":
				# Un parking sans voitures n'est qu'une dalle grise.
				for k in 2:
					_voiture(racine, Vector3((float(c.x) + 0.3 + 0.4 * float(k)) * CASE, y,
						(float(c.y) + 0.5) * CASE), false, alea)
			";":
				# LE SABLE : palmiers et rochers, clairsemés. Une plage plantée
				# aussi dru qu'un bosquet n'est plus une plage.
				if alea.randf() < 0.34:
					_objet(racine, PALMIERS[alea.randi() % PALMIERS.size()],
						_dans(c, y, alea), alea.randf_range(13.0, 19.0), alea.randf() * TAU)
				if alea.randf() < 0.22:
					_objet(racine, "nature/rock_smallA", _dans(c, y, alea),
						alea.randf_range(1.6, 3.0), alea.randf() * TAU)
			",":
				# UNE PELOUSE CONTRE UN PAVILLON EST UN JARDIN, pas un terrain
				# vague : allée vers la rue, clôture sur la limite, jardinière,
				# arbre d'agrément. Ailleurs, trois touffes et un caillou —
				# assez pour qu'un terrain nu se lise comme volontaire et non
				# comme un trou dans le dessin.
				var vers_rue := _vers(dessin, c, CHAUSSEE)
				if not pente_ici(carte, dessin, c).is_empty():
					pass                       # rien ne tient sur un talus
				elif _voisin_de(dessin, c, "MmVv") and vers_rue != Vector2i.ZERO:
					var j: Array = JARDIN[alea.randi() % JARDIN.size()]
					_objet(racine, String(j[0]),
						centre_de(c, y) + Vector3(vers_rue.x, 0, vers_rue.y) * (CASE * 0.18),
						float(j[1]), atan2(float(vers_rue.x), float(vers_rue.y)))
					if alea.randf() < 0.55:
						var k: Array = CLOTURES[alea.randi() % CLOTURES.size()]
						_objet(racine, String(k[0]),
							centre_de(c, y) + Vector3(vers_rue.x, 0, vers_rue.y) * (CASE * 0.42),
							float(k[1]), atan2(float(vers_rue.x), float(vers_rue.y)))
				elif alea.randf() < 0.17:
					var f: Array = FRICHE[alea.randi() % FRICHE.size()]
					_objet(racine, String(f[0]), _dans(c, y, alea),
						float(f[1]) * alea.randf_range(0.8, 1.4), alea.randf() * TAU)
			"o":
				# L'ESPLANADE. Le pavé est déjà posé par `_poser_sols` ; ici on
				# ne met que ce qui s'assoit dessus.
				if alea.randf() < 0.30:
					var e: Array = ESPLANADE[alea.randi() % ESPLANADE.size()]
					_objet(racine, String(e[0]), _dans(c, y, alea), float(e[1]),
						alea.randf() * TAU)
				elif alea.randf() < 0.06:
					_objet(racine, "nature/statue_column",
						Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE), 11.0)

## Le centre d'une case, à la hauteur donnée. (`carte.centre` demande la carte ;
## ici on n'a que le dessin.)
static func centre_de(c: Vector2i, y: float) -> Vector3:
	return Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE)

## La direction de la première voisine dont le caractère est dans `lettres`.
## Zéro s'il n'y en a pas. Sert à TOURNER un objet vers la rue : une allée qui
## part vers le fond du pâté, une marquise qui donne sur un mur.
static func _vers(dessin: Array, c: Vector2i, lettres: String) -> Vector2i:
	for d in CarteVille.COTES:
		if lettres.contains(_car(dessin, c.x + d.x, c.y + d.y)):
			return d
	return Vector2i.ZERO

static func _voisin_de(dessin: Array, c: Vector2i, lettres: String) -> bool:
	return _vers(dessin, c, lettres) != Vector2i.ZERO

## Un point DANS la case, mais rentré des bords : semé jusqu'au bord, un arbre
## déborde de moitié sur la case d'à côté — souvent un immeuble.
static func _dans(c: Vector2i, y: float, alea: RandomNumberGenerator) -> Vector3:
	return Vector3((float(c.x) + 0.22 + alea.randf() * 0.56) * CASE, y,
		(float(c.y) + 0.22 + alea.randf() * 0.56) * CASE)

## ⚠ LE PARC AUTOMOBILE SE COMPTE EN PROPORTIONS, PAS EN MODÈLES. La liste est
## tirée à plat : y écrire `police` une fois sur dix, c'est une ville où une
## voiture sur dix est un gyrophare. Les banales sont donc répétées, les rares
## ne le sont pas — et `firetruck`, `ambulance` ne sortent qu'une fois sur
## trente-deux, ce qui est déjà beaucoup pour une rue au hasard.
const VOITURES := ["sedan", "sedan", "sedan", "sedan-sports", "hatchback-sports",
	"hatchback-sports", "suv", "suv", "suv-luxury", "van", "van", "delivery",
	"delivery-flat", "taxi", "taxi", "truck", "truck-flat", "police",
	"garbage-truck", "ambulance", "firetruck", "race"]

## ⚠ LE FEU REGARDE VERS −X SANS ROTATION, la tête en porte-à-faux au-dessus
## de la voie, le mât à l'origine (mesuré sur le maillage, tranche par tranche
## en Y : le mât est un cylindre centré, la tête déborde de 0,07 vers −X et de
## rien vers +X). Comme un quart de tour en Y envoie −X vers... ce qu'il envoie,
## on ne le devine pas : posé au coin de coordonnées (sx, sz), le feu doit
## regarder le centre du carrefour, ce qui donne `atan2(-sz, sx)`. Vérifié en
## photo, pas au raisonnement.
##
## ⚠ ET SURTOUT : AU COIN, PAS SUR LA CHAUSSÉE. La première version les posait
## sur les quatre AXES, à 0,42 case du centre — c'est-à-dire au milieu de
## chaque voie, en plein sur la ligne blanche. Un feu se plante sur le trottoir.
const COIN := 0.38                     ## en cases, depuis le centre, sur X ET sur Z
const BORD := 0.42                     ## le trottoir d'un tronçon droit

## Les quatre coins d'une case, et l'angle qui fait regarder le centre.
const COINS := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

static func _au_coin(centre: Vector3, k: int) -> Array:
	var s: Vector2i = COINS[k]
	return [centre + Vector3(float(s.x), 0.0, float(s.y)) * (COIN * CASE),
		atan2(-float(s.y), float(s.x))]

## Ce qui donne l'ÉCHELLE : lampadaires, feux, panneaux, arbres d'alignement,
## voitures. Sans eux la ville est une maquette d'architecte — c'est le
## reproche qu'on s'est pris sur la toute première.
static func _poser_mobilier(racine: Node3D, carte: CarteVille, dessin: Array,
		alea: RandomNumberGenerator, zone: Rect2i = Rect2i()) -> void:
	for c in _cases_de(carte, zone):
		_resemer(alea, 4242, c)
		if not carte.route(c) or carte.case_prise(c): continue
		var fiche: Array = carte.tuile(c)
		var nom := String(fiche[0])
		var y := carte.hauteur(c)
		var centre := carte.centre(c)
		var bord := CASE * BORD
		if nom == "road-straight" or nom == "road-slant" or nom == "road-slant-high":
			var selon_x := int(fiche[1]) == 0
			var vers: Vector2i = CarteVille.S if selon_x else CarteVille.E
			var d := Vector3(0, 0, bord) if selon_x else Vector3(bord, 0, 0)
			var t := 0.0 if selon_x else PI * 0.5
			# UNE RUE, UN LAMPADAIRE. Tirer le modèle case par case donnait une
			# avenue qui changeait de luminaire tous les dix mètres ; on tire
			# sur la coordonnée FIXE de la rue, si bien que toute la rue porte
			# le même, et que la rue d'à côté en porte un autre.
			var rue: int = c.y if selon_x else c.x
			var lampe := "urbain/light-curved" if posmod(rue, 3) == 0 else "urbain/light-square"
			# ⚠ UNE AVENUE À DEUX CHAUSSÉES SE MÂTE AU MILIEU. `light-square-double`
			# porte ses deux têtes de part et d'autre (Z de −0,21 à +0,21) : c'est
			# le luminaire du terre-plein, et le poser au bord d'une rue simple
			# éclairerait les façades.
			var large_voie := carte.route(c + vers) and carte.route(c - vers)
			# Un lampadaire tient sur le trottoir ; un arbre, non : il ne se
			# plante que du côté où la case voisine est LIBRE.
			if large_voie and alea.randf() < 0.34:
				_objet(racine, "urbain/light-square-double", centre, 11.0, t,
					Color("#6e737c"))
			elif alea.randf() < 0.30:
				# ⚠ `urbain/`, PAS `routes/` — un chemin de modèle qui n'existe
				# pas ne fait rien et ne dit rien ; c'est le banc de vignettes
				# qui avait montré la ville sans un seul lampadaire.
				_objet(racine, lampe, centre + d, 9.5, t, Color("#6e737c"))
				_objet(racine, lampe, centre - d, 9.5, t + PI, Color("#6e737c"))
			if alea.randf() < 0.30:
				var libres: Array = []
				if _lettre(_car(dessin, c.x + vers.x, c.y + vers.y)) == "": libres.append(d)
				if _lettre(_car(dessin, c.x - vers.x, c.y - vers.y)) == "": libres.append(-d)
				if not libres.is_empty():
					_objet(racine, ARBRES[alea.randi() % ARBRES.size()],
						centre + libres[alea.randi() % libres.size()] * 0.82,
						alea.randf_range(8.0, 12.0), alea.randf() * TAU)
			# LE POTEAU ÉLECTRIQUE EST UN SIGNE DE ZONE, pas une décoration : il
			# ne sort que le long de l'industrie et des dépôts. Une ligne
			# électrique au pied d'une tour de bureaux ne se voit nulle part.
			if alea.randf() < 0.16 and _industriel(dessin, c, vers):
				_objet(racine, "urbain/electricity-pole", centre + d, 17.0, t)
			if alea.randf() < 0.28:
				_voiture(racine, centre, selon_x, alea)
			# LE PANNEAU VIERGE fait l'affichage d'une rue commerçante.
			if alea.randf() < 0.07 and _voisin_de(dessin, c, "Cc"):
				_objet(racine, "routes/road-sign-empty", centre + d, 9.0, t)
			# ⚠ LE PANNEAU DE DANGER SE POSE EN BAS DE LA RAMPE, pas dessus : au
			# milieu d'une pente, il est planté de travers dans le talus.
			if nom != "road-straight" and alea.randf() < 0.5:
				var cote: Array = _au_coin(centre, alea.randi() % 4)
				_objet(racine, "urbain/road-sign-warning", cote[0], 8.0, float(cote[1]))
		elif nom.begins_with("road-crossroad"):
			# UN CARREFOUR À QUATRE BRANCHES EST RÉGLÉ. Un sur trois ne l'est
			# pas : c'est ce qui distingue une avenue d'une rue de quartier.
			# Et un carrefour sur trois parmi les réglés l'est PAR POTENCES —
			# le kit en a, et une ville où tous les feux sont identiques se
			# lit comme un décor de circuit.
			# ⚠ DEUX POTENCES, PAS QUATRE. La première version en plantait une à
			# chaque coin : de loin, un carrefour ressemblait à une cage. Une
			# potence porte au-dessus de la voie, donc deux en diagonale
			# couvrent les quatre branches — c'est d'ailleurs ce qu'on voit dans
			# une vraie rue.
			var tire := alea.randf()
			if tire < 0.16:
				for k in [0, 2]:
					var pot: Array = _au_coin(centre, k)
					_potence(racine, "routes/traffic-light-hanging",
						TETES[alea.randi() % TETES.size()], pot[0], 11.0, k)
			elif tire < 0.68:
				for k in 4:
					var cote: Array = _au_coin(centre, k)
					_objet(racine, "routes/traffic-light", cote[0], 8.0, float(cote[1]))
			else:
				for k in 4:
					if alea.randf() < 0.5: continue
					var cote: Array = _au_coin(centre, k)
					_objet(racine, "urbain/road-sign-stop", cote[0], 7.5, float(cote[1]))
			# LA POTENCE DE SIGNALISATION, au-dessus de la voie. Rare : elle est
			# faite pour les grands axes, pas pour un croisement de quartier.
			if tire >= 0.16 and alea.randf() < 0.05:
				var g := alea.randi() % 4
				var gant: Array = _au_coin(centre, g)
				_potence(racine, "routes/road-sign-empty-hanging",
					PANNEAUX[alea.randi() % PANNEAUX.size()], gant[0], 10.0, g)
		elif nom.begins_with("road-intersection"):
			# UN T N'A PAS DE FEUX EN CROIX : il a un stop sur la branche qui se
			# jette dans l'autre, et une plaque de rue au coin. Mettre quatre
			# feux à un T donnait un feu qui réglait un trottoir.
			if alea.randf() < 0.22:
				var f: Array = _au_coin(centre, alea.randi() % 4)
				_objet(racine, "urbain/traffic-light", f[0], 8.0, float(f[1]))
			elif alea.randf() < 0.55:
				var cote: Array = _au_coin(centre, alea.randi() % 4)
				var panneau := "urbain/road-sign-stop" if alea.randf() < 0.7 \
					else "routes/road-sign-warning"
				_objet(racine, panneau, cote[0], 7.5, float(cote[1]))
			if alea.randf() < 0.35:
				var plaque: Array = _au_coin(centre, alea.randi() % 4)
				_objet(racine, "routes/road-sign-street", plaque[0], 8.5, float(plaque[1]))

## ⚠ UNE POTENCE ET SA TÊTE SONT DEUX MODÈLES. Le kit sépare le mât en
## porte-à-faux (`*-hanging`) de ce qu'il porte (`*-object-*`) : le mât seul
## est un crochet vide, la tête seule flotte en l'air. Le bras part vers −Z
## sans rotation (mesuré : Z va de −0,25 à +0,04), donc pour qu'il surplombe le
## carrefour depuis le coin `k`, il faut `atan2(sx, sz)` — l'autre convention
## que celle du feu sur mât, qui regarde vers −X. Deux modèles, deux repères ;
## c'est pour ça qu'on mesure au lieu de deviner.
const PORTEE := 0.22                   ## la longueur du bras, en cases
## Les têtes que porte une potence, et les panneaux d'une potence de
## signalisation : le kit les livre SÉPARÉMENT du mât, en trois orientations
## pour les feux et trois symboles pour les panneaux.
const TETES := ["routes/traffic-light-object-horizontal",
	"routes/traffic-light-object-vertical", "routes/traffic-light-object-hanging"]
const PANNEAUX := ["routes/road-sign-object-street", "routes/road-sign-object-stop",
	"routes/road-sign-object-warning"]

static func _potence(racine: Node3D, mat: String, tete: String, ou: Vector3,
		hauteur: float, k: int) -> void:
	var sx := float(COINS[k].x)
	var sz := float(COINS[k].y)
	var vers := atan2(sx, sz)
	_objet(racine, mat, ou, hauteur, vers)
	# La tête pend au bout du bras, aux neuf dixièmes de la hauteur du mât.
	_objet(racine, tete, ou + Vector3(-sx, 0.0, -sz).normalized() * (PORTEE * CASE)
		+ Vector3(0.0, hauteur * 0.86, 0.0), 2.6, vers)

## Vrai si la rue longe de l'industrie ou un dépôt — c'est ce qui autorise le
## poteau électrique. On regarde les deux côtés de la voie, pas les quatre :
## une rue est bordée par ce qu'elle longe, pas par ce qu'elle croise.
static func _industriel(dessin: Array, c: Vector2i, vers: Vector2i) -> bool:
	for s in [1, -1]:
		var car := _car(dessin, c.x + vers.x * s, c.y + vers.y * s)
		if car == "H" or car == "h" or car == "X" or car == "%":
			return true
	return false

static func _voiture(racine: Node3D, ou: Vector3, selon_x: bool, alea: RandomNumberGenerator) -> void:
	var chemin := "res://modeles/kenney/voitures/%s.glb" % VOITURES[alea.randi() % VOITURES.size()]
	if not ResourceLoader.exists(chemin): return
	if inventaire: _noter(chemin)
	var n := MeshInstance3D.new()
	# ⚠ Les carrosseries du Car Kit regardent +Z là où le reste du kit regarde
	# −Z : un quart de tour dans l'AUTRE sens, sinon la ville roule à reculons.
	n.mesh = FormesCarnage.maillage_kenney(chemin, 10.0, Vector3.AXIS_Z, PI * 0.5)
	n.material_override = FormesCarnage.matiere_kenney(chemin)
	var voie := CASE * 0.16 * (1.0 if alea.randf() < 0.5 else -1.0)
	var sens := 0.0 if voie > 0.0 else PI
	var decal := alea.randf_range(-6.0, 6.0)
	n.transform = Transform3D(Basis(Vector3.UP, sens + (0.0 if selon_x else PI * 0.5)),
		ou + (Vector3(decal, 0, voie) if selon_x else Vector3(voie, 0, decal)))
	racine.add_child(n)

static func _objet(parent: Node3D, sous_chemin: String, ou: Vector3, hauteur: float,
		tourne: float = 0.0, teinte := Color.WHITE) -> void:
	# Un chemin qui commence par `res://` est pris tel quel : c'est ce qui laisse
	# poser un modèle de `modeles/piksl/` avec la même fonction que le kit.
	var chemin := sous_chemin if sous_chemin.begins_with("res://") \
		else "res://modeles/kenney/" + sous_chemin + ".glb"
	if not ResourceLoader.exists(chemin): return
	if inventaire: _noter(chemin)
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, hauteur, Vector3.AXIS_Y, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, tourne), ou)
	parent.add_child(n)

# ------------------------------------------------------------ les bateaux

## LE MOUILLAGE. Une file de `~` est une place d'amarrage : sa LONGUEUR dit
## quel bateau vient s'y mettre. Écrire un modèle par case aurait demandé un
## caractère par bateau ; là, on dessine l'eau du port et la flotte suit.
## ⚠ Les coques du Watercraft Pack sont toutes longues selon Z (mesuré,
## `outils/bateaux.gd`) : on les tourne pour les aligner sur la file.
const FLOTTE := [
	# longueur mini de la file (en cases), modèle, longueur en unités de jeu
	[6, ["bateaux/ship-ocean-liner-small", 220.0], ["bateaux/ship-cargo-a", 200.0],
		["bateaux/ship-cargo-b", 200.0], ["bateaux/ship-large", 180.0]],
	[4, ["bateaux/ship-small", 140.0], ["bateaux/ship-cargo-b", 200.0]],
	[2, ["bateaux/boat-tug-a", 50.0], ["bateaux/boat-tug-b", 46.0],
		["bateaux/boat-fishing-small", 28.0]],
	[1, ["bateaux/boat-speed-a", 16.0], ["bateaux/boat-speed-c", 16.0],
		["bateaux/boat-sail-a", 24.0], ["bateaux/boat-row-large", 12.0],
		["bateaux/buoy", 5.0], ["bateaux/buoy-flag", 6.0]],
]
const NIVEAU_MER := -2.4

static func _poser_bateaux(racine: Node3D, dessin: Array, alea: RandomNumberGenerator,
		zone: Rect2i = Rect2i()) -> void:
	var vues: Dictionary = {}
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	# ⚠ ON BORNE LE BALAYAGE À LA ZONE, ÉLARGIE DE DOUZE CASES. Une file de
	# mouillages fait au plus dix cases : douze suffisent pour qu'un morceau
	# voie entièrement une file qui commence chez son voisin. Sans cette borne,
	# chaque morceau relisait les 48 375 caractères du dessin pour poser zéro
	# bateau — la ville n'a qu'un port.
	var j0 := 0
	var j1 := dessin.size() - 1
	var i0 := 0
	var i1 := large - 1
	if zone.size != Vector2i.ZERO:
		j0 = maxi(0, zone.position.y - 12)
		j1 = mini(dessin.size() - 1, zone.position.y + zone.size.y + 12)
		i0 = maxi(0, zone.position.x - 12)
		i1 = mini(large - 1, zone.position.x + zone.size.x + 12)
	# Les files horizontales, puis les verticales : une place d'amarrage se lit
	# dans le sens du quai.
	for j in range(j0, j1 + 1):
		var i := i0
		while i <= i1:
			if _car(dessin, i, j) != "~" or vues.has(Vector2i(i, j)):
				i += 1
				continue
			var n := 0
			while _car(dessin, i + n, j) == "~" and not vues.has(Vector2i(i + n, j)):
				n += 1
			for k in n: vues[Vector2i(i + k, j)] = true
			# ⚠ Le bateau appartient au morceau qui contient le MILIEU de sa
			# file, et à lui seul : sinon une file à cheval sur deux morceaux
			# sort deux fois, et deux cargos se traversent au même quai.
			if _dedans(zone, Vector2i(i + n / 2, j)):
				_amarrer(racine, Vector2(float(i) + float(n) * 0.5, float(j) + 0.5), n, true, alea)
			i += n
	for i in range(i0, i1 + 1):
		var j := j0
		while j <= j1:
			if _car(dessin, i, j) != "~" or vues.has(Vector2i(i, j)):
				j += 1
				continue
			var n := 0
			while _car(dessin, i, j + n) == "~" and not vues.has(Vector2i(i, j + n)):
				n += 1
			for k in n: vues[Vector2i(i, j + k)] = true
			if _dedans(zone, Vector2i(i, j + n / 2)):
				_amarrer(racine, Vector2(float(i) + 0.5, float(j) + float(n) * 0.5), n, false, alea)
			j += n

static func _amarrer(racine: Node3D, centre: Vector2, longueur: int, selon_x: bool,
		alea: RandomNumberGenerator) -> void:
	for fiche in FLOTTE:
		if longueur < int(fiche[0]): continue
		var choix: Array = fiche[1 + alea.randi() % (fiche.size() - 1)]
		var chemin := "res://modeles/kenney/" + String(choix[0]) + ".glb"
		if not ResourceLoader.exists(chemin): return
		if inventaire: _noter(chemin)
		var n := MeshInstance3D.new()
		n.mesh = FormesCarnage.maillage_kenney(chemin, float(choix[1]), Vector3.AXIS_Z, 0.0)
		n.material_override = FormesCarnage.matiere_kenney(chemin)
		var tour := (PI * 0.5 if selon_x else 0.0) + alea.randf_range(-0.03, 0.03)
		n.transform = Transform3D(Basis(Vector3.UP, tour),
			Vector3(centre.x * CASE, NIVEAU_MER, centre.y * CASE))
		racine.add_child(n)
		_annexes(racine, centre, longueur, selon_x, alea)
		return

## ⚠ UN QUAI N'A PAS QU'UN CARGO. La flotte était choisie par la LONGUEUR de la
## file, et une seule pièce sortait : comme le port de Pikstown n'a que des
## files longues, les dix petits bateaux du kit — remorqueurs, vedettes,
## voilier, barque — n'étaient JAMAIS posés. Constaté au banc d'inventaire, pas
## à l'œil. Le gros navire garde donc le milieu du poste, et les menues
## embarcations s'amarrent le long, décalées vers le bord ; les bouées marquent
## les deux bouts de la file.
const MENUS := [
	["bateaux/boat-tug-a", 50.0], ["bateaux/boat-tug-b", 46.0],
	["bateaux/boat-fishing-small", 28.0], ["bateaux/boat-speed-a", 16.0],
	["bateaux/boat-speed-c", 16.0], ["bateaux/boat-sail-a", 24.0],
	["bateaux/boat-row-large", 12.0], ["bateaux/ship-small", 140.0],
]

static func _annexes(racine: Node3D, centre: Vector2, longueur: int, selon_x: bool,
		alea: RandomNumberGenerator) -> void:
	var demi := float(longueur) * 0.5
	for k in 2:
		if longueur < 3 or alea.randf() < 0.45: continue
		var m: Array = MENUS[alea.randi() % MENUS.size()]
		var le_long := alea.randf_range(-demi + 0.6, demi - 0.6)
		var ecart := (0.9 if k == 0 else -0.9)
		var ou := centre + (Vector2(le_long, ecart) if selon_x else Vector2(ecart, le_long))
		_flotter(racine, String(m[0]), ou, float(m[1]),
			(PI * 0.5 if selon_x else 0.0) + alea.randf_range(-0.25, 0.25))
	# LES BOUÉES aux deux bouts : c'est ce qui fait lire un chenal plutôt qu'une
	# flaque, et ça ne coûte que deux modèles.
	for k in 2:
		if alea.randf() < 0.5: continue
		var bout := demi - 0.35 if k == 0 else -demi + 0.35
		var ou2 := centre + (Vector2(bout, 0.0) if selon_x else Vector2(0.0, bout))
		_flotter(racine, "bateaux/buoy-flag" if alea.randf() < 0.5 else "bateaux/buoy",
			ou2, 7.0, alea.randf() * TAU)

static func _flotter(racine: Node3D, sous_chemin: String, ou: Vector2, longueur: float,
		tour: float) -> void:
	var chemin := "res://modeles/kenney/" + sous_chemin + ".glb"
	if not ResourceLoader.exists(chemin): return
	if inventaire: _noter(chemin)
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, longueur, Vector3.AXIS_Z, 0.0)
	n.material_override = FormesCarnage.matiere_kenney(chemin)
	n.transform = Transform3D(Basis(Vector3.UP, tour),
		Vector3(ou.x * CASE, NIVEAU_MER, ou.y * CASE))
	racine.add_child(n)

# ------------------------------------------------------------ la ville entière

## ⚠ IL N'Y A PLUS DE PONTS EN MONDE. Ils existaient parce que deux quartiers
## d'angles différents ne pouvaient pas se raccorder dans une grille commune :
## le pont était forcément en biais, donc forcément hors des dessins. Avec une
## trame unique, un pont est un `=` dans le plan comme une rue est un `#` — il
## se dessine, se déplace et se vérifie comme le reste. Sept ponts franchissent
## les deux chenaux de Pikstown, tous dans `PlanPikstown.PLAN`.
const PONTS := []

static func ville() -> Node3D:
	var racine := Node3D.new()
	racine.name = "Ville"
	var mer := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(3000.0 * CASE, 3000.0 * CASE)
	mer.mesh = plan
	var eau := StandardMaterial3D.new()
	eau.albedo_color = Color("#2b5f7a")
	eau.roughness = 0.15
	eau.metallic = 0.25
	mer.material_override = eau
	mer.position = Vector3(0, -2.4, 0)
	racine.add_child(mer)
	for id in CATALOGUE.keys():
		racine.add_child(batir(String(id)))
	for p in PONTS:
		_pont(racine, Vector3(p[0].x * CASE, float(p[2]) * PALIER, p[0].y * CASE),
			Vector3(p[1].x * CASE, float(p[3]) * PALIER, p[1].y * CASE))
	return racine

static func _pont(racine: Node3D, a: Vector3, b: Vector3) -> void:
	var pas := maxf(1.0, a.distance_to(b) / CASE)
	var dir := (b - a).normalized()
	var angle := atan2(-dir.z, dir.x)
	for k in int(pas) + 1:
		var p := a.lerp(b, float(k) / pas)
		var n := MeshInstance3D.new()
		var chemin := ROUTES + "road-bridge.glb"
		n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
		n.material_override = _matiere(chemin, Color("#9aa0aa"))
		# Le tablier suit la CORDE, pas la grille — et chaque pièce est
		# allongée d'un poil, sinon deux voisines laissent une fente en biais.
		n.transform = Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(CASE * 1.08, CASE, CASE)), p)
		racine.add_child(n)
