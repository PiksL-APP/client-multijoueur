class_name GenerateurBidonville
extends RefCounted
## LE NEUVIÈME QUARTIER TÉMOIN : LE BIDONVILLE (cahier § 3 : « bidonville /
## quartier délabré »).
##
## ⚠ C'EST LE SEUL QUARTIER QUI N'EST PAS SUR LA GRILLE, ET C'EST TOUT SON
## SUJET. Les huit autres témoins posent des LOTS : une emprise en demi-cases,
## un quart de tour, une façade alignée sur la rue. C'est ce qui fait tenir une
## ville — et c'est exactement ce qu'un bidonville n'a pas. Une baraque n'est
## pas lotie : elle est posée là où il restait de la place, de travers, contre
## la précédente.
##
## On emploie donc des OBJETS LIBRES (`ajouter_objet`, angle quelconque) au lieu
## de lots, pour la première fois du projet. Conséquences assumées :
##
## * ⚠ LES BARAQUES NE SE CHEVAUCHENT PAS. C'était écrit ici le 12/09 comme un
##   parti pris (« un bidonville se construit en s'appuyant sur le voisin ») et
##   le client l'a tranché le 13/09 : « tu ne dois pas fusionner deux bâtiments
##   l'un à l'autre ». Il a raison et le parti pris était faux : deux volumes
##   qui s'interpénètrent ne font pas un appentis, ils font un défaut de rendu —
##   on voit un mur sortir d'un toit. Serré n'est pas confondu. Elles se TOUCHENT
##   donc, à quelques centimètres, et jamais plus ;
## * elles ne bloquent pas le lotisseur, mais il n'y en a pas ici ;
## * elles suivent la règle des hauteurs en mètres comme tout le reste : une
##   baraque fait trois à quatre mètres et demi, pas onze.
##
## Le reste du quartier :
##
## * le sol est de la TERRE d'un bord à l'autre, jamais de l'herbe ni du pavé ;
## * deux rues seulement, en périphérie — on n'entre pas en voiture dans le
##   bidonville, on s'arrête au bord ;
## * des SENTES, tracées en peignant la terre plus claire : ce sont les seuls
##   « axes » de l'intérieur, et elles ne sont pas carrossables ;
## * un point d'eau, quelques feux, et des tas partout.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.

const PROPRETE := preload("res://commun/ville2/proprete.gd")
const ATLAS := preload("res://commun/ville2/atlas.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")
const AFFICHES := preload("res://commun/ville2/affiches.gd")
const CHEMINS := preload("res://commun/ville2/chemins.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## LES DEUX RUES, en périphérie : celle par où l'on arrive et celle qui longe.
const J_ROUTE := 35
const X_ROUTE := 3

## LE CŒUR : tout ce qui est dedans est bâti à la main, sans grille.
const COEUR := Rect2i(5, 3, 32, 30)
## Le point d'eau, seul équipement commun.
const POINT_D_EAU := Vector2i(20, 17)

const PRENOMS := ["de la Décharge", "du Talus", "des Tôles", "du Fossé", "de la Sente"]

## ⚠ LES BARAQUES SONT POSÉES À UNE HAUTEUR VOULUE, COMME TOUT LE RESTE. Ces
## modèles sont des garages et des hangars : à l'échelle du kit ils font onze à
## vingt mètres. Ramenés à trois ou quatre, ce sont des cabanes — le même
## modèle, la même règle qu'ailleurs, un résultat qui n'a plus rien à voir.
## ⚠ TOUTES LES VARIANTES DU KIT SUBURBAN, ET TOUTES À LA MÊME HAUTEUR
## (demandes du client, 13/09 : « tu dois utiliser toutes les variantes du
## modèle Suburban » et « tu ne dois pas gérer de différence de taille »).
##
## La seconde demande a l'air d'un détail et n'en est pas un : la variation de
## hauteur (0,85 à 1,25) faisait sortir des baraques de trois mètres à côté de
## baraques de cinq, et comme l'emprise suit la hauteur, elle faisait varier
## aussi la LARGEUR — d'où des voisines qui se recouvraient. Une seule hauteur,
## et le pavage redevient calculable.
const HAUTEUR_BARAQUE := 3.8

## Les vingt-et-une variantes du kit, sans exception.
const SUBURBAN := ["pavillons/building-type-a", "pavillons/building-type-b",
	"pavillons/building-type-c", "pavillons/building-type-d", "pavillons/building-type-e",
	"pavillons/building-type-f", "pavillons/building-type-g", "pavillons/building-type-h",
	"pavillons/building-type-i", "pavillons/building-type-j", "pavillons/building-type-k",
	"pavillons/building-type-l", "pavillons/building-type-m", "pavillons/building-type-n",
	"pavillons/building-type-o", "pavillons/building-type-p", "pavillons/building-type-q",
	"pavillons/building-type-r", "pavillons/building-type-s", "pavillons/building-type-t",
	"pavillons/building-type-u"]

## ⚠⚠ LES VRAIES CABANES, ARRIVÉES LE 13/09 — et elles changent la règle.
##
## Jusqu'ici, une cabane de bidonville était un PAVILLON DE LOTISSEMENT rétréci
## à 3,80 m et teinté brun : il gardait ses fenêtres à croisillon, son avancée
## de toit et sa porte de villa. Les caravanes étaient des caisses de remorque
## du kit voitures. C'était la bricole la plus voyante des neuf témoins.
##
## Ces dix modèles-là sont dessinés pour ce jeu. Mesurés à la livraison : neuf
## sur dix sont **exacts au centimètre** par rapport au cahier, et les dix ont
## leur base à y = 0. On les pose donc À LEUR TAILLE NATURELLE — hauteur zéro,
## le facteur de la case fait le reste — au lieu de leur imposer une hauteur.
##
## ⚠ ET ON NE LES TEINTE PAS. Ils portent leurs propres matières nommées
## (`toleRouille`, `toitVert`, `bacheBleue`, `pneu`…) : quarante-trois couleurs
## réparties sur les dix. Une teinte d'instance par-dessus multiplierait tout
## et effacerait ce travail — c'est exactement l'inverse de ce qu'on faisait
## quand les cabanes étaient des pavillons blancs à repeindre.
const PXL_CABANES := ["pxl/cabane-tole-a", "pxl/cabane-tole-b", "pxl/cabane-tole-c",
	"pxl/cabane-bois-a", "pxl/cabane-bois-b", "pxl/abri-bache"]

## Les vraies caravanes et le camping-car, à leur taille naturelle.
const PXL_ROULANTS := ["pxl/caravane", "pxl/camping-car"]

## Ce qui se pose SUR un toit de cabane : la cuve d'eau et la parabole. C'est
## le détail qui dit qu'on habite là — un toit de bidonville n'est jamais nu.
const PXL_SUR_LE_TOIT := ["pxl/citerne-eau-toit", "pxl/antenne-parabole"]

## ⚠ LES ANCIENS REMPLAÇANTS SONT RETIRÉS. `voitures/box` et ses voisins
## tenaient lieu de caravanes faute de mieux ; à côté des vraies, ce sont des
## CUBES LISSES SANS UN DÉTAIL, et ils sautent aux yeux — une bricole ne se
## voit jamais autant que le jour où la vraie pièce arrive à côté d'elle.
## Le constat vaut pour tout le reste du chantier : chaque lot livré rendra
## visible la bricole voisine.

## Les cabanes de fortune : les tentes et les appentis, plus bas.
const CABANES := [
	{"m": "nature/tent_detailedOpen", "h": 2.6},
	{"m": "nature/tent_detailedClosed", "h": 2.6},
	{"m": "nature/tent_smallClosed", "h": 2.2},
	{"m": "ville/building-garage", "h": 3.2},
	{"m": "industriel/building-h", "h": 3.4},
]
## Ce qui traîne entre les baraques.
const TAS := ["nature/log_stack", "nature/rock_smallA", "nature/stone_smallB",
	"nature/stump_squareDetailed", "nature/log", "industriel/detail-tank"]
const H_TAS = [1.00, 0.55, 0.40, 0.60, 0.80, 1.60]
## Les tôles et les grillages de récupération.
const TOLES := ["urbain/construction-fence", "nature/fence_planks", "nature/fence_simple"]
const H_TOLES = [2.00, 1.40, 1.30]

## Combien de baraques par côté de case. Trois par trois : une baraque de six
## mètres, une case de vingt — il en faut neuf pour la couvrir.
## ⚠ QUATRE, DEPUIS QUE LES VRAIES CABANES SONT LÀ. La sous-grille était à
## trois parce qu'une baraque bricolée avec un pavillon rétréci faisait six
## mètres de large : à trois par côté, le pas vaut 6,67 m et ça pavait. Les
## cabanes dessinées pour l'usage font trois à quatre mètres — au même pas,
## elles laissent deux mètres de vide entre chacune et le quartier s'est
## clairsemé d'un coup. À quatre, le pas tombe à 5 m et le serré revient.
const SOUS_GRILLE := 4

static func generer(graine := 9, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-bidonville"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	_terrain(v, alea)
	_quartiers(v)
	_rues(v)
	v.rasteriser()
	var sentes := _les_sentes(v, alea)
	# ⚠ UNE SENTE QUI NE SE VOIT PAS N'EN EST PAS UNE. Elle était calculée,
	# respectée par les baraques… et invisible, parce que tout le quartier est
	# de la même terre. On la peint donc en `M_ROCHE` : le gris de la caillasse
	# tassée par les pas, juste assez différent du remblai pour dessiner le
	# réseau d'en haut.
	# ⚠ PAS UN BRIN D'HERBE, PAS MÊME SOUS LES SENTES. Le quartier est de la
	# terre nue d'un bord à l'autre : c'est sa définition. Les deux essais
	# précédents mettaient de l'herbe sous les tuiles de chemin, puis une bande
	# débordante, pour cacher le liseré vert que la tuile apporte avec elle —
	# et ça donnait des pelouses au milieu d'un bidonville. La verdure est
	# maintenant retirée DE LA TUILE (voir `chemins.gd` et `atlas.sans_verdure`),
	# donc le sol n'a plus rien à compenser : on le laisse en terre, et on
	# marque juste la sente d'un ton de caillasse tassée.
	# ⚠ ET RIEN SOUS LA SENTE : LA MÊME TERRE QUE PARTOUT. La case était peinte
	# en `M_ROCHE` (le gris de la caillasse) pour que le réseau se voie d'en
	# haut. Maintenant que les tuiles portent le chemin, ce gris ne sert plus à
	# rien — il ne fait que dépasser d'un liseré autour de chaque tuile, ce qui
	# est exactement le défaut qu'on vient de corriger côté verdure.
	pass
	_les_baraques(v, alea, sentes)
	# ⚠ ET LES SENTES SONT DE VRAIES TUILES DE CHEMIN (demande du client, 13/09 :
	# « tu dois faire des routes de terre du kit Kenney nature »). Peindre la
	# case en `M_ROCHE` dessinait bien le réseau d'en haut, mais de près il n'y
	# avait rien : une nuance de gris, pas un chemin. Les tuiles `ground_path*`
	# du kit ont l'ornière, le bord relevé et les cailloux ; raccordées par
	# `chemins.gd`, elles font le chemin creusé qu'on attend.
	CHEMINS.poser(v, alea, sentes, "", ATLAS.TERRE_SECHE.to_html(false))
	_le_point_d_eau(v, alea)
	_details(v, alea, sentes)
	# Deux ou trois affiches en lisière, jamais dedans : ce sont les panneaux de
	# la route, et ils regardent ailleurs.
	AFFICHES.semer(v, alea, 150.0, [], 3)
	# Pas d'herbe : le sol est nu.
	# ⚠ AUCUNE TOITURE VERTE (client, 13/09). Voir `atlas.gd` : la bande
	# verte de l'atlas est repeinte par bâtiment, murs inchangés.
	TEINTES.couvrir(v, alea, "", ATLAS.TOLE)
	TEINTES.peindre(v, alea, "", TEINTES.TOLE, 0.00)
	PROPRETE.finir(v, alea, 0)
	return v

# ------------------------------------------------------------------ 1. le terrain

static func _terrain(v: Ville2, alea: RandomNumberGenerator) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			# Quelques touffes d'herbe survivent en lisière, jamais au cœur.
			var lisiere := not COEUR.grow(-1).has_point(c)
			v.poser_matiere(c, Ville2.M_HERBE if lisiere and alea.randf() < 0.25 \
				else Ville2.M_TERRE)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "Les Tôles", "genre": Ville2.Q_BIDONVILLE, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)

# ------------------------------------------------------------------ 2. les rues

## ⚠ DEUX RUES, ET TOUTES DEUX EN PÉRIPHÉRIE. Une rue qui traverse un bidonville
## n'en est plus un : ce qui le définit, c'est justement qu'on y entre à pied.
static func _rues(v: Ville2) -> void:
	v.ajouter_route(Ville2.R_AVENUE,
		[Vector2i(0, J_ROUTE), Vector2i(v.taille.x - 1, J_ROUTE)],
		"Route " + PRENOMS[0])
	v.ajouter_route(Ville2.R_RUE,
		[Vector2i(X_ROUTE, J_ROUTE), Vector2i(X_ROUTE, 2)],
		"Rue " + PRENOMS[1])

# ------------------------------------------------------------------ 3. les sentes

## LES SENTES. Ce sont les seuls « axes » de l'intérieur, et elles ne sont pas
## des routes : le kit n'a pas de tuile pour un chemin de terre entre deux
## cabanes, et une tuile de route ferait un boulevard. On les trace donc en
## MARQUANT DES CASES ; `chemins.gd` pose ensuite les tuiles `ground_path*` qui
## conviennent au voisinage de chacune.
##
## ⚠⚠ ET LE RÉSEAU DOIT ÊTRE D'UN SEUL TENANT. « Fais en sorte que dans le
## bidonville chaque rue soit connectée entre elle, car là ce n'est pas le cas »
## (client, 13/09). Il avait raison, et la faute tenait à UNE LIGNE :
##
##     for _k in ...:           # on descend, on écrit (i, j), puis j -= 1
##     i = i ± 1                # on se décale
##     sentes[Vector2i(i, j)]   # on écrit (i ± 1, j)
##
## La dernière case du tronçon était (i, j + 1) et la première du suivant
## (i ± 1, j) : elles sont EN DIAGONALE. Or `chemins.gd` ne raccorde que les
## voisins nord/est/sud/ouest — une case en diagonale n'est pas un voisin. À
## chaque zigzag, la sente se coupait donc en deux, et il y en avait un tous
## les deux ou trois pas. Vu d'en haut ça ressemblait à un chemin ; parcouru,
## ça n'en était pas un.
##
## ⚠ LA LEÇON, plus générale : un décalage se dessine en L, jamais en diagonale.
## Il faut écrire la CASE DE COIN. C'est la même contrainte que le tracé des
## routes du cahier (« le modèle refuse la diagonale, le kit ne sait pas la
## paver ») ; elle vaut pour tout ce qui se pave à la case.
##
## Et comme un tracé juste ne prouve pas un réseau connexe — deux sentes
## peuvent parfaitement ne jamais se croiser —, on VÉRIFIE à la fin par
## propagation, et on creuse ce qu'il faut. Voir `_rendre_connexe`.
##
## Rend l'ensemble des cases de sente.
static func _les_sentes(v: Ville2, alea: RandomNumberGenerator) -> Dictionary:
	var sentes: Dictionary = {}
	# Trois sentes qui montent de la route vers le fond, deux transversales.
	# Elles zigzaguent d'une case tous les deux ou trois pas — une sente droite
	# serait une rue — mais chaque zigzag est un COUDE, pas un saut.
	for depart in [8, 18, 29]:
		var i: int = depart
		var j := J_ROUTE - 1
		while j > COEUR.position.y:
			var bas := j
			j = maxi(COEUR.position.y, j - alea.randi_range(2, 4))
			_couloir(sentes, Vector2i(i, bas), Vector2i(i, j))
			if j <= COEUR.position.y: break
			var suivant := clampi(i + (1 if alea.randf() < 0.5 else -1),
				COEUR.position.x + 1, COEUR.end.x - 2)
			# Le coude : on parcourt la ligne AVANT de redescendre. C'est cette
			# case-là qui manquait.
			_couloir(sentes, Vector2i(i, j), Vector2i(suivant, j))
			i = suivant
	for jj in [12, 24]:
		var i2 := COEUR.position.x + 1
		var j2: int = jj
		while i2 < COEUR.end.x - 1:
			var gauche := i2
			i2 = mini(COEUR.end.x - 1, i2 + alea.randi_range(2, 4))
			_couloir(sentes, Vector2i(gauche, j2), Vector2i(i2, j2))
			if i2 >= COEUR.end.x - 1: break
			var suivant2 := clampi(j2 + (1 if alea.randf() < 0.5 else -1),
				COEUR.position.y + 1, COEUR.end.y - 2)
			_couloir(sentes, Vector2i(i2, j2), Vector2i(i2, suivant2))
			j2 = suivant2
	# ⚠ ET ON RACCORDE LA ROUTE. Une sente qui s'arrête une case avant la
	# chaussée ne débouche nulle part : le bidonville n'aurait aucune entrée.
	for depart in [8, 18, 29]:
		_couloir(sentes, Vector2i(depart, J_ROUTE - 1), Vector2i(depart, J_ROUTE - 1))
	_rendre_connexe(v, sentes, alea)
	return sentes

## Creuse un couloir d'une case entre deux points ALIGNÉS (même x ou même y),
## bornes comprises. C'est la seule primitive de tracé : tout passe par elle,
## donc aucun tracé ne peut produire de diagonale.
static func _couloir(sentes: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var d := (b - a).sign()
	var c := a
	sentes[c] = true
	var garde := 0
	while c != b and garde < 200:
		c += d
		sentes[c] = true
		garde += 1

## ⚠ LA PREUVE, PAS L'INTENTION. Le tracé ci-dessus est juste, mais rien ne
## garantit que les cinq sentes se croisent : elles zigzaguent au hasard, et
## une graine peut très bien les faire passer à côté les unes des autres. On
## vérifie donc, par propagation de proche en proche (voisins orthogonaux
## seulement, comme `chemins.gd` les raccorde), que TOUT est d'un seul tenant —
## et quand ça ne l'est pas, on creuse.
##
## Le rattachement se fait vers la case du grand morceau la plus proche, en L :
## c'est le chemin le plus court qui reste orthogonal.
static func _rendre_connexe(v: Ville2, sentes: Dictionary, alea: RandomNumberGenerator) -> void:
	var tours := 0
	while tours < 12:
		tours += 1
		var morceaux := _morceaux(sentes)
		if morceaux.size() <= 1: return
		# Le plus gros morceau est le réseau ; tous les autres s'y rattachent.
		var principal: Array = morceaux[0]
		for m in morceaux:
			if (m as Array).size() > principal.size(): principal = m
		var relie := false
		for m in morceaux:
			if m == principal: continue
			var de: Vector2i = (m as Array)[0]
			var vers: Vector2i = principal[0]
			var mieux := 1 << 30
			for a in (m as Array):
				for b in principal:
					var d: int = absi(int(a.x) - int(b.x)) + absi(int(a.y) - int(b.y))
					if d < mieux:
						mieux = d
						de = a
						vers = b
			# Le L : d'abord en x, puis en y (ou l'inverse, au hasard, pour que
			# les raccords ne se ressemblent pas tous).
			if alea.randf() < 0.5:
				_couloir(sentes, de, Vector2i(vers.x, de.y))
				_couloir(sentes, Vector2i(vers.x, de.y), vers)
			else:
				_couloir(sentes, de, Vector2i(de.x, vers.y))
				_couloir(sentes, Vector2i(de.x, vers.y), vers)
			relie = true
			break
		if not relie: return

## Les morceaux connexes de l'ensemble, par propagation orthogonale.
static func _morceaux(sentes: Dictionary) -> Array:
	var vus: Dictionary = {}
	var morceaux: Array = []
	for depart in sentes:
		if vus.has(depart): continue
		var morceau: Array = []
		var pile: Array = [depart]
		vus[depart] = true
		while not pile.is_empty():
			var c: Vector2i = pile.pop_back()
			morceau.append(c)
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var n: Vector2i = c + d
				if sentes.has(n) and not vus.has(n):
					vus[n] = true
					pile.append(n)
		morceaux.append(morceau)
	return morceaux

# ------------------------------------------------------------------ 4. les baraques

## ⚠ UNE BARAQUE N'EST PAS UN LOT. On sème des OBJETS, avec un angle quelconque
## et un chevauchement toléré : c'est la seule façon d'obtenir le désordre
## caractéristique. Deux garde-fous seulement — jamais sur une sente, jamais sur
## la route — parce qu'un bidonville est désordonné, pas impraticable.
## ⚠ LE PAVAGE SANS CHEVAUCHEMENT. Deux contraintes qui se combattent : il en
## faut BEAUCOUP (une baraque de six mètres, une case de vingt — il en faut une
## douzaine pour paver une case, sinon le témoin sort en « jouets semés sur une
## plage ») et il n'en faut AUCUNE qui en traverse une autre.
##
## La solution n'est ni une grille (trop régulière : ça fait un lotissement) ni
## un semis pur (il laisse des trous et fait des paquets). On garde la
## SOUS-GRILLE, qui garantit la couverture, et on lui ajoute un REGISTRE des
## cercles déjà occupés : chaque baraque réserve son rayon, et une candidate
## qui empiéterait n'est pas posée. Le jeu autorisé dans la sous-grille est
## alors ce qui défait l'alignement, et le registre ce qui interdit la fusion.
##
## Le rayon vient de l'emprise RÉELLE du modèle à la hauteur voulue — pas d'une
## constante : une caravane fait deux mètres de large et un pavillon six.
static func _les_baraques(v: Ville2, alea: RandomNumberGenerator, sentes: Dictionary) -> void:
	var pris: Dictionary = {}
	for j in range(COEUR.position.y, COEUR.end.y):
		for i in range(COEUR.position.x, COEUR.end.x):
			var c := Vector2i(i, j)
			if sentes.has(c): continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if c.distance_to(Vector2(POINT_D_EAU)) < 2.5: continue
			var proche := absf(float(j) - float(J_ROUTE)) < 18.0
			var densite := 0.92 if proche else 0.6
			for sj in SOUS_GRILLE:
				for si in SOUS_GRILLE:
					if alea.randf() > densite: continue
					var pas := 1.0 / float(SOUS_GRILLE)
					var x := (float(i) + (float(si) + 0.5) * pas
						+ alea.randf_range(-0.05, 0.05)) * CASE
					var z := (float(j) + (float(sj) + 0.5) * pas
						+ alea.randf_range(-0.05, 0.05)) * CASE
					_essayer(v, alea, pris, x, z)

## Tire un abri au hasard et le pose s'il tient sans toucher ses voisins.
##
## ⚠ LA RÉPARTITION A CHANGÉ LE 13/09, quand les vraies cabanes sont arrivées.
## Avant, tout reposait sur les vingt-et-une variantes du kit Suburban, faute
## de mieux — le client avait demandé de toutes les employer, et il avait
## raison de le demander tant qu'il n'y avait que ça. Maintenant qu'il existe
## six cabanes dessinées pour l'usage, ce sont ELLES qui font le quartier.
##
## Le kit Suburban reste, en minorité : dans un vrai bidonville, quelques
## maisons en dur se mêlent aux cabanes — c'est même ce qui donne l'échelle du
## reste. Une sur six, donc, et les vingt-et-une variantes y passent toujours.
static func _essayer(v: Ville2, alea: RandomNumberGenerator, pris: Dictionary,
		x: float, z: float) -> bool:
	var tirage := alea.randf()
	var modele := ""
	var hauteur := 0.0          ## zéro = à la taille naturelle du modèle
	var teinte := ""
	var couverture := ""
	if tirage < 0.52:
		# LE CŒUR DU QUARTIER : les six cabanes, à leur taille naturelle.
		modele = PXL_CABANES[alea.randi() % PXL_CABANES.size()]
	elif tirage < 0.64:
		modele = PXL_ROULANTS[alea.randi() % PXL_ROULANTS.size()]
	elif tirage < 0.82:
		var f: Dictionary = CABANES[alea.randi() % CABANES.size()]
		modele = String(f["m"])
		hauteur = float(f["h"])
	else:
		# Les maisons en dur, rétrécies et repeintes comme avant.

		modele = SUBURBAN[alea.randi() % SUBURBAN.size()]
		hauteur = HAUTEUR_BARAQUE
		teinte = TEINTES.TOLE[alea.randi() % TEINTES.TOLE.size()]
		couverture = ATLAS.TOLE[alea.randi() % ATLAS.TOLE.size()]
	var r := _rayon(modele, hauteur)
	if not _place_libre(pris, x, z, r): return false
	_prendre(pris, x, z, r)
	var fiche := {"m": modele, "x": x, "z": z, "r": alea.randf() * TAU, "h": hauteur}
	# ⚠ NI TEINTE NI TOITURE SUR LES MODÈLES `pxl/` : ils portent leurs propres
	# matières. Multiplier par-dessus effacerait la tôle rouillée et la bâche
	# bleue qu'ils ont déjà.
	if teinte != "": fiche["c"] = teinte
	if couverture != "": fiche["toit"] = couverture
	v.objets.append(fiche)
	# LE TOIT HABITÉ : une cabane sur quatre porte sa cuve d'eau ou sa parabole.
	# On les pose avec `dy`, à la hauteur réelle du modèle qu'on vient de poser.
	if modele.begins_with("pxl/cabane") and alea.randf() < 0.28:
		var haut := _hauteur_posee(modele, hauteur)
		v.objets.append({"m": PXL_SUR_LE_TOIT[alea.randi() % PXL_SUR_LE_TOIT.size()],
			"x": x + alea.randf_range(-0.6, 0.6), "z": z + alea.randf_range(-0.6, 0.6),
			"r": alea.randf() * TAU, "h": 0.0, "dy": haut - 0.15})
	return true

## ⚠ LE REGISTRE EST INDEXÉ PAR CASE, PAS EN LISTE. À la sous-grille de quatre,
## on tente seize poses par case sur mille cases : seize mille essais, contre un
## registre qui finit à cinq mille cercles. En liste, c'est quatre-vingts
## MILLIONS de distances — le générateur passait de deux secondes à plusieurs
## minutes. Indexé par case de vingt unités, chaque essai ne regarde que les
## neuf cases autour de lui, donc une poignée de voisins.
const RAYON_MAX := 6.0        ## le plus gros abri du quartier, en unités

static func _clef(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CASE), floori(z / CASE))

static func _place_libre(pris: Dictionary, x: float, z: float, r: float) -> bool:
	var c := _clef(x, z)
	# Une case de plus autour : un cercle posé dans la case voisine peut
	# déborder jusqu'ici si son rayon est grand.
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			var liste = pris.get(c + Vector2i(di, dj))
			if liste == null: continue
			for q in (liste as Array):
				var w: Vector3 = q
				if Vector2(w.x, w.y).distance_to(Vector2(x, z)) < r + w.z: return false
	return true

static func _prendre(pris: Dictionary, x: float, z: float, r: float) -> void:
	var c := _clef(x, z)
	if not pris.has(c): pris[c] = []
	(pris[c] as Array).append(Vector3(x, z, r))

## La hauteur à laquelle se trouve le TOIT d'un modèle une fois posé : sa
## hauteur voulue, ou sa hauteur naturelle si on ne lui en impose pas.
static func _hauteur_posee(modele: String, hauteur: float) -> float:
	if hauteur > 0.0: return hauteur
	return KitVille2.taille(modele).y * CASE

## Le demi-diamètre au sol d'un modèle, en unités.
## ⚠ ON MESURE, ON NE DEVINE PAS. `KitVille2.taille()` rend la boîte en CASES ;
## à hauteur imposée, tout est mis à l'échelle par le rapport des hauteurs, et
## à hauteur naturelle le facteur vaut un. Une constante « six mètres » aurait
## fait tenir une caravane pour une cabane et laissé des trous partout.
static func _rayon(modele: String, hauteur: float) -> float:
	var t := KitVille2.taille(modele)
	if t.y <= 0.001: return 3.0
	var facteur := 1.0
	if hauteur > 0.0: facteur = hauteur / (t.y * CASE)
	return 0.5 * sqrt(pow(t.x * CASE * facteur, 2.0) + pow(t.z * CASE * facteur, 2.0)) * 0.88

# ------------------------------------------------------------------ 5. le point d'eau

## LE POINT D'EAU : le seul équipement commun, et le seul endroit dégagé. Dans
## un vrai bidonville c'est là qu'on se retrouve — donc c'est là qu'il faut
## laisser de la place, sinon le quartier n'a pas de centre du tout.
static func _le_point_d_eau(v: Ville2, alea: RandomNumberGenerator) -> void:
	var cx := (float(POINT_D_EAU.x) + 0.5) * CASE
	var cz := (float(POINT_D_EAU.y) + 0.5) * CASE
	v.ajouter_objet("res://modeles/kenney/industriel/water-tower.glb", cx, cz, 0.0, 14.0)
	for k in 6:
		var a := TAU * float(k) / 6.0
		v.ajouter_objet("nature/pot_large", cx + cos(a) * 14.0, cz + sin(a) * 14.0,
			alea.randf() * TAU, 0.8)
	for k in 4:
		v.ajouter_objet("benne", cx + alea.randf_range(-24.0, 24.0),
			cz + alea.randf_range(-24.0, 24.0), alea.randf() * TAU)
	v.ajouter_lieu("point_d_eau", cx, cz, {"nom": "Le Robinet"})

# ------------------------------------------------------------------ 6. les détails

static func _details(v: Ville2, alea: RandomNumberGenerator, sentes: Dictionary) -> void:
	# Les tas, partout sauf sur les sentes.
	for j in range(COEUR.position.y, COEUR.end.y):
		for i in range(COEUR.position.x, COEUR.end.x):
			var c := Vector2i(i, j)
			if sentes.has(c) or alea.randf() > 0.5: continue
			var n := alea.randi() % TAS.size()
			v.ajouter_objet(TAS[n], (float(i) + alea.randf()) * CASE,
				(float(j) + alea.randf()) * CASE, alea.randf() * TAU, float(H_TAS[n]))
	# Les tôles dressées : des bouts de clôture plantés au hasard, jamais
	# alignés — c'est ce qui distingue une palissade d'un bidonville.
	for k in 90:
		var i := COEUR.position.x + alea.randi() % COEUR.size.x
		var j := COEUR.position.y + alea.randi() % COEUR.size.y
		if sentes.has(Vector2i(i, j)): continue
		var n := alea.randi() % TOLES.size()
		v.ajouter_objet(TOLES[n], (float(i) + alea.randf()) * CASE,
			(float(j) + alea.randf()) * CASE, alea.randf() * TAU, float(H_TOLES[n]))
	# Les feux de camp, sur les sentes : c'est là qu'on se tient.
	var cases: Array = sentes.keys()
	for k in 9:
		if cases.is_empty(): break
		var c: Vector2i = cases[alea.randi() % cases.size()]
		v.ajouter_objet("feu_de_camp", (float(c.x) + 0.5) * CASE,
			(float(c.y) + 0.5) * CASE, 0.0)
		if alea.randf() < 0.6:
			v.ajouter_objet("tronc", (float(c.x) + 0.85) * CASE,
				(float(c.y) + 0.5) * CASE, alea.randf() * TAU)
	# Les épaves, au bord de la route : on ne roule pas plus loin.
	for k in 7:
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, (5.0 + alea.randf() * 30.0) * CASE,
			(float(J_ROUTE) - 1.0 - alea.randf() * 1.6) * CASE, alea.randf() * TAU)
	# Les lampadaires de la route : la lumière s'arrête au bord du quartier, et
	# c'est le détail qui dit le plus.
	for i in range(2, v.taille.x - 2, 6):
		v.ajouter_objet("lampadaire", (float(i) + 0.5) * CASE,
			(float(J_ROUTE) + 0.9) * CASE, 0.0)
