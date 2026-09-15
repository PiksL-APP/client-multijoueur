class_name GenerateurBanlieue
extends RefCounted
## LE QUATRIÈME QUARTIER TÉMOIN : LA BANLIEUE PAVILLONNAIRE (cahier § 3).
##
## Les trois premiers témoins ont éprouvé la ville dense (le centre), la côte
## (la plage) et le relief (la colline). Celui-ci éprouve LE CONTRAIRE DE LA
## GRILLE — c'est le seul quartier du cahier dont le tracé n'est pas régulier :
##
## * « tracé : grille au centre, ORGANIQUE ailleurs » (§ 5) → une boucle qui
##   serpente et des impasses qui s'en détachent, jamais deux rues parallèles ;
## * « impasses partout où c'est utile, mais jamais sans raison » (§ 5) → une
##   impasse dessert un chapelet de pavillons et finit sur une raquette de
##   retournement, comme dans une vraie banlieue ;
## * « maisons avec jardin, clôture, allée et voiture devant » (§ 3) → chaque
##   pavillon a sa parcelle clôturée, son allée goudronnée et souvent sa
##   voiture ;
## * « piscines, barbecues, trampolines » (§ 3) → dans les jardins arrière,
##   c'est-à-dire du côté opposé à la rue ;
## * « école, église, terrain de sport » et « petits commerces (épicerie,
##   station-service) » (§ 3) → un pôle de quartier sur la route d'entrée.
##
## ⚠ LA PASSE DU 14/09, en quatre reproches et une phrase chacun :
##
## * « pas assez de route qui mène aux maisons » → deux impasses qui ne
##   desservaient rien ont sauté, trois dessertes descendent maintenant dans le
##   sud resté vide, et CHAQUE maison a son allée peinte jusqu'à la chaussée
##   (`_allee_privee`) ;
## * « revoir ou me laisser faire les fences autour des maisons » → la clôture
##   suit désormais la LARGEUR DE PARCELLE notée à la pose, et non plus la
##   taille de la maison : plus de rectangles flottants entre deux terrains, et
##   plus de barrière dans les murs ;
## * « tu dois faire des hangars et des champs de légumes » → la ferme passe
##   AVANT le lotisseur et réserve son bloc, au lieu de mendier les restes ;
## * « tu dois utiliser d'autres variantes de maison » → le tirage se faisait
##   avec remise, ce qui annulait tout le sac ; il passe par `Lotisseur`, et le
##   sac contient les vingt-et-un pavillons plus deux modèles du kit ville.
##
## ⚠ CE QUI FAIT UNE BANLIEUE, C'EST LA PARCELLE, PAS LA MAISON. Une rangée de
## pavillons collés les uns aux autres est un lotissement de promoteur vu de
## haut, pas une banlieue : ce qu'on reconnaît, c'est le rythme maison / jardin
## / clôture / maison. On pose donc la PARCELLE d'abord (une largeur tirée au
## sort), la maison dedans, et le reste est du jardin.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.

## Les courbes larges (cahier § 5) : brique commune, appelée par `preload` — un
## `class_name` neuf n'existe pas dans l'export web.
const ANGLES := preload("res://commun/ville2/angles.gd")

## Les règles communes à tous les quartiers : rien sur la chaussée, et pas
## une pelouse nue. Appelées en dernier (voir `commun/ville2/proprete.gd`).
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const ATLAS := preload("res://commun/ville2/atlas.gd")
const CHEMINS := preload("res://commun/ville2/chemins.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")

## Les panneaux publicitaires (cahier § 7) : toits, pignons aveugles, bords
## d'axe. Brique commune — l'affichage est une règle de ville, pas de quartier.
const AFFICHES := preload("res://commun/ville2/affiches.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## La route d'entrée du quartier, d'ouest en est : c'est par là qu'on arrive
## du centre, et c'est elle qui porte les commerces.
const J_ENTREE := 31

## LA BOUCLE. Une banlieue américaine se dessine autour d'une `loop road` : une
## seule rue qui part de l'entrée, fait le tour du quartier et y revient. Les
## impasses s'y greffent. Les points sont les sommets du tracé — les segments
## sont droits (le modèle refuse la diagonale), et `ANGLES.arrondir` passe
## derrière pour adoucir les coudes.
const BOUCLE := [
	Vector2i(7, 31), Vector2i(7, 24), Vector2i(4, 24), Vector2i(4, 13),
	Vector2i(11, 13), Vector2i(11, 6), Vector2i(24, 6), Vector2i(24, 11),
	Vector2i(31, 11), Vector2i(31, 19), Vector2i(35, 19), Vector2i(35, 27),
	Vector2i(28, 27), Vector2i(28, 31),
]

## LES IMPASSES : le point de greffe sur la boucle, le sens où elles partent et
## leur longueur en cases. Une impasse trop longue n'est plus une impasse, c'est
## une rue qu'on a oublié de finir.
##
## ⚠ DEUX IMPASSES ONT SAUTÉ, ET TROIS SONT NÉES — la desserte, c'est d'abord
## le tracé (« pas assez de route qui mène aux maisons », client, 13/09).
##
## * `(15,13)` vers le nord et `(20,13)` vers le sud desservaient le CREUX DE
##   LA BOUCLE, c'est-à-dire le seul morceau du quartier qui n'avait pas besoin
##   d'elles : la boucle le borde déjà sur ses quatre côtés. Pire, la seconde
##   descendait de sept cases, donc jusqu'en (20,20) — EN PLEIN MILIEU DU PARC,
##   qu'elle coupait en deux sans que rien ne le signale, puisque `_le_parc`
##   plante ses arbres sans regarder la chaussée. Ce creux devient la ferme ;
## * TOUT LE SUD DE LA ROUTE D'ENTRÉE ÉTAIT VIDE. `_parcelles` saute la « Route
##   de la Ville » (on ne borde pas une avenue de traverse de pavillons), donc
##   huit lignes de cases sur quarante n'avaient ni rue ni maison — un tiers du
##   témoin en pelouse rase. Trois dessertes y descendent maintenant.
const IMPASSES := [
	{"de": Vector2i(4, 20), "vers": Vector2i(1, 0), "long": 6},
	{"de": Vector2i(4, 16), "vers": Vector2i(1, 0), "long": 5},
	{"de": Vector2i(24, 9), "vers": Vector2i(1, 0), "long": 6},
	{"de": Vector2i(31, 15), "vers": Vector2i(-1, 0), "long": 6},
	{"de": Vector2i(35, 23), "vers": Vector2i(-1, 0), "long": 7},
	{"de": Vector2i(28, 29), "vers": Vector2i(-1, 0), "long": 8},
	{"de": Vector2i(11, 9), "vers": Vector2i(-1, 0), "long": 5},
	{"de": Vector2i(12, J_ENTREE), "vers": Vector2i(0, 1), "long": 6},
	{"de": Vector2i(20, J_ENTREE), "vers": Vector2i(0, 1), "long": 5},
	{"de": Vector2i(33, J_ENTREE), "vers": Vector2i(0, 1), "long": 6},
]

## LE PARC DU QUARTIER (cahier § 3 : « banlieue pavillonnaire + parcs »), au
## creux de la boucle, et LE TERRAIN DE SPORT à côté de l'école.
const PARC := Rect2i(14, 16, 9, 8)
const ECOLE := Rect2i(13, 27, 8, 3)

const PRENOMS := ["des Tilleuls", "des Acacias", "du Verger", "des Pinsons",
	"de la Clairière", "des Écoliers", "du Moulin", "des Peupliers", "des Cerisiers",
	"du Petit Bois", "des Alouettes", "de la Fontaine"]
const IMPASSES_NOMS := ["Impasse des Roses", "Impasse du Lavoir", "Impasse des Mésanges",
	"Impasse du Puits", "Impasse des Lilas", "Impasse de la Grange", "Impasse du Clos",
	"Impasse des Vignes", "Impasse du Sentier", "Impasse des Noyers",
	"Impasse du Pré", "Impasse des Cigales"]

## ⚠⚠ LE SAC DE MAISONS, ET IL A ÉTÉ REPROCHÉ DEUX FOIS (« tu as l'air de
## toujours utiliser les mêmes maisons avec les mêmes variantes », 12/09, puis
## « tu dois utiliser d'autres variantes de maison que celles que tu utilises »,
## 13/09). Il y avait TROIS causes, et la liste n'était que la troisième :
##
## 1. LE TIRAGE SE FAISAIT AVEC REMISE. `_border_la_rue` faisait
##    `choix[alea.randi() % choix.size()]` — exactement ce que `lotisseur.gd`
##    explique de ne jamais faire : sur vingt maisons prises parmi seize
##    modèles, sept sortent en double et cinq ne sortent jamais. Toute la
##    variété du sac était annulée par la façon d'y puiser. On passe donc par
##    `Lotisseur.modele_qui_tient`, qui tire SANS remise et ne rebat qu'une
##    fois le sac vide ;
## 2. CINQ MODÈLES ÉTAIENT EN QUARANTAINE. `GRANDES` ne sortait que sur une
##    parcelle de huit demi-cases, c'est-à-dire une fois sur cinq : b, d, f, n
##    et t n'apparaissaient presque jamais. Le seuil descend à sept, et les
##    vingt-et-un pavillons sont maintenant dans le sac ordinaire ;
## 3. il manquait des modèles. Les vingt-et-un pavillons Kenney y sont tous, et
##    deux pièces du kit VILLE s'y ajoutent — vérifiées au md5 le 14/09, elles
##    ne sont le doublon d'aucun autre modèle du dépôt, contrairement à
##    `modeles/banlieue/` et aux `suburb-building-type-*`, qui sont octet pour
##    octet les `pavillons/building-type-*` (voir `atlas.gd`). Leur emprise
##    d'une case pile casse le rythme des pavillons, tous larges de 1,2 à 1,8.
##
## ⚠ ET `ville/building-small-b` ET `-c` RESTENT DEHORS : 1,63 et 1,75 case de
## HAUT, soit 33 et 35 m — deux fois le plus haut des pavillons. Une banlieue
## n'a pas d'immeuble de dix étages entre deux jardins.
const MAISONS := ["pavillons/building-type-a", "pavillons/building-type-b",
	"pavillons/building-type-c", "pavillons/building-type-d", "pavillons/building-type-e",
	"pavillons/building-type-f", "pavillons/building-type-g", "pavillons/building-type-h",
	"pavillons/building-type-i", "pavillons/building-type-j", "pavillons/building-type-k",
	"pavillons/building-type-l", "pavillons/building-type-m", "pavillons/building-type-n",
	"pavillons/building-type-o", "pavillons/building-type-p", "pavillons/building-type-q",
	"pavillons/building-type-r", "pavillons/building-type-s", "pavillons/building-type-t",
	"pavillons/building-type-u", "ville/building-small-a", "ville/building-small-d"]
## Les grandes maisons, qui passent en tête sur les parcelles larges : les trois
## plus LARGES du kit (b, d, n : 1,76 à 1,83 case) et les trois plus PROFONDES
## (f, m, t : 1,41 case). Elles restent dans `MAISONS` — ce sac-ci ne fait que
## leur donner leur chance là où la place existe.
const GRANDES := ["pavillons/building-type-b", "pavillons/building-type-d",
	"pavillons/building-type-n", "pavillons/building-type-f", "pavillons/building-type-m",
	"pavillons/building-type-t"]
## Le pôle de quartier, sur la route d'entrée.
const COMMERCES := ["batiments/building-c", "batiments/building-e", "batiments/building-k",
	"batiments/building-d", "batiments/building-g"]

## LES CLÔTURES, ET ELLES SONT DROITES.
##
## ⚠ `fence-1x2`, `-1x3`, `-1x4` DU KIT PAVILLONS SONT DES PANNEAUX PLIÉS.
## Mesurés : 0,875 × 0,27 × 0,438 — quatre dixièmes d'épaisseur là où un
## panneau droit en fait sept centièmes. Ce sont des ANGLES, dessinés pour
## tourner le coin d'une parcelle, et alignés bout à bout ils donnaient une
## clôture en zigzag (« utilise d'autres barrières, il y en a sans le pli,
## toutes droites », client, 12/09). Le kit nature a les bonnes : `fence_simple`
## et `fence_planks` font une case de long sur sept centièmes d'épaisseur.
##
## Et il a mieux : `fence_corner`, une pièce d'angle d'une case sur une case.
## On aligne donc des panneaux droits sur les côtés et on POSE UN ANGLE À
## CHAQUE COIN — c'est comme ça qu'on monte une clôture, et c'est ce que le
## client a dessiné.
##
## Les hauteurs restent imposées : à l'échelle du kit un panneau ferait sept
## unités de haut. Une clôture de jardin fait 1,10 m.
const H_CLOTURE := 1.10
const CLOTURES := ["nature/fence_simple", "nature/fence_planks", "nature/fence_simpleLow"]
const ANGLE_CLOTURE := "nature/fence_corner"
## Ce qu'on met dans un jardin de derrière.
const JARDIN := ["nature/plant_bushDetailed", "nature/plant_bushLarge", "nature/tree_default",
	"nature/tree_oak", "nature/tree_fat", "nature/grass_large", "nature/flower_redA",
	"nature/flower_yellowB", "nature/flower_purpleA", "nature/pot_large",
	"nature/stump_round", "nature/log_stack"]
const H_JARDIN = [0.90, 1.30, 7.60, 6.40, 6.00, 0.70, 0.45, 0.45, 0.45, 0.80, 0.50, 1.00]
## ⚠ L'AXE NATIF DU CHEMIN D'UNE TUILE `ground_path*` : le sens dans lequel
## court son chemin quand elle est posée SANS rotation. Tout le raccord des
## sentiers tient à cette seule constante — se tromper d'un quart de tour, et
## chaque tuile présente son chemin en travers de la précédente.
const AXE_DU_SENTIER := PI * 0.5

## Les arbres d'alignement de la banlieue : plus petits qu'en ville.
const ALIGNEMENT := ["nature/tree_small", "nature/tree_oak", "nature/tree_default",
	"nature/tree_plateau", "nature/tree_cone_dark"]

static func generer(graine := 4, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-banlieue"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	_terrain(v)
	_quartiers(v)
	_rues(v)
	v.rasteriser()
	# Les coudes de la boucle s'arrondissent AVANT les maisons : une courbe
	# large mange quatre cases, et si les lots sont posés il n'en reste aucune.
	ANGLES.arrondir(v, alea, 0.85)
	v.rasteriser()
	# ⚠ LA FERME PASSE AVANT LE LOTISSEUR, ET C'EST TOUTE LA DIFFÉRENCE. Elle
	# était appelée en avant-dernier, donc elle cherchait sa place APRÈS que
	# soixante parcelles aient mangé les bords de chaque rue — d'où le
	# rétrécissement en cascade du premier jet, et une ferme de sept cases sur
	# six coincée dans un angle. C'est la leçon du stade du campus, prise à
	# l'envers : une grande pièce se RÉSERVE d'abord, et le lotisseur se range.
	# `_la_ferme` marque ses cases dans `v.demi_prises`, que `terrain_libre`
	# interroge — aucune maison ne peut plus s'y poser.
	_la_ferme(v, alea)
	v.rasteriser()
	_parcelles(v, alea)
	v.rasteriser()
	_le_pole(v, alea)
	v.rasteriser()
	_le_parc(v, alea)
	v.rasteriser()
	_les_jardins(v, alea)
	_details(v, alea)
	AFFICHES.semer(v, alea, 150.0, [], 4)
	# ⚠ AUCUNE TOITURE VERTE (client, 13/09). Voir `atlas.gd` : la bande
	# verte de l'atlas est repeinte par bâtiment, murs inchangés.
	#
	# ⚠ ET UNE GAMME PAR MÉTIER, PAS UNE POUR TOUT LE MONDE. Un seul appel sur
	# le genre vide coiffait les hangars agricoles de tuile romane et l'école de
	# bardeau de bois : le quartier entier sortait dans les huit mêmes couleurs,
	# ce qui est une autre façon de « toujours utiliser la même variante ». Un
	# hangar est en TÔLE, un pavillon en tuile ou en ardoise, et ça se voit d'en
	# haut. `couvrir` saute les lots déjà coiffés : l'ordre suffit à trancher.
	TEINTES.couvrir(v, alea, "hangar", ATLAS.TOLE)
	TEINTES.couvrir(v, alea, "pavillon", ATLAS.PAVILLONNAIRE)
	TEINTES.couvrir(v, alea, "", ATLAS.PAVILLONNAIRE, 0.25)
	TEINTES.peindre(v, alea, "hangar", TEINTES.INDUSTRIE, 0.20)
	TEINTES.peindre(v, alea, "pavillon", TEINTES.PAVILLONS, 0.22)
	TEINTES.peindre(v, alea, "", TEINTES.PAVILLONS, 0.45)
	PROPRETE.finir(v, alea)
	return v

# ------------------------------------------------------------------ 1. le terrain

## ⚠ PLAT, ET EN HERBE. Une banlieue est bâtie sur du plat (cahier § 4 : « pas
## de pente sous les quartiers bâtis »), et son sol est de l'herbe, pas du
## béton : c'est même ce qui la distingue du centre d'un seul coup d'œil. Les
## trottoirs viennent des tuiles de route ; tout le reste est pelouse.
static func _terrain(v: Ville2) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			v.poser_matiere(c, Ville2.M_HERBE)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "Les Jardins", "genre": Ville2.Q_PAVILLONS, "gang": -1})
	v.quartiers.append({"nom": "Parc des Tilleuls", "genre": Ville2.Q_PARC, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)
	v.peindre_quartier(PARC, 1)

# ------------------------------------------------------------------ 2. les rues

static func _rues(v: Ville2) -> void:
	# La route d'entrée : la seule qui traverse, et la seule en avenue.
	v.ajouter_route(Ville2.R_AVENUE,
		[Vector2i(0, J_ENTREE), Vector2i(v.taille.x - 1, J_ENTREE)],
		"Route de la Ville")
	# LA BOUCLE, en un seul tracé : c'est ce qui lui donne un nom unique sur la
	# carte et ce qui garantit qu'elle se referme.
	var points: Array = BOUCLE.duplicate()
	v.ajouter_route(Ville2.R_RUE, points, "Rue du Grand Tour")
	# Les impasses.
	for k in IMPASSES.size():
		var im: Dictionary = IMPASSES[k]
		var de: Vector2i = im["de"]
		var vers: Vector2i = im["vers"]
		var bout: Vector2i = de + vers * int(im["long"])
		v.ajouter_route(Ville2.R_RUE, [de, bout], IMPASSES_NOMS[k % IMPASSES_NOMS.size()])

# ------------------------------------------------------------------ 3. les parcelles

## De combien la maison recule par rapport au bord de la chaussée, en
## demi-cases : le devant de jardin.
const RECUL := 1
## La largeur d'une parcelle, en demi-cases — tirée dans cette fourchette.
const PARCELLE_MINI := 4
const PARCELLE_MAXI := 8

## ⚠ ON POSE LA PARCELLE, PUIS LA MAISON DEDANS. `Lotisseur.aligner` colle les
## façades les unes aux autres : parfait pour une rue commerçante, faux pour
## une banlieue, où le vide entre deux maisons compte autant que les maisons.
## On découpe donc le bord de rue en parcelles de largeur variable, on centre
## la maison dans la sienne, et ce qui reste devient jardin et clôture.
static func _parcelles(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in v.routes.duplicate():
		if String(r["nom"]) == "Route de la Ville": continue
		var cases := Ville2.cases_de_route(r)
		if cases.size() < 3: continue
		# Les deux bords de la rue, chacun avec le sens où regarde la façade.
		for cote in [1, -1]:
			_border_la_rue(v, cases, cote, alea)

static func _border_la_rue(v: Ville2, cases: Array, cote: int,
		alea: RandomNumberGenerator) -> void:
	var k := 1
	while k < cases.size() - 1:
		var a: Vector2i = cases[k - 1]
		var b: Vector2i = cases[k]
		var d: Vector2i = b - a
		# Un coude : on saute. Une parcelle à cheval sur un virage n'a pas de
		# façade sur rue, et le lotisseur la refuserait de toute façon.
		if d == Vector2i.ZERO or (cases[mini(k + 1, cases.size() - 1)] - b) != d:
			k += 1
			continue
		# La normale à la rue, du côté demandé.
		var n := Vector2i(-d.y, d.x) * cote
		var large := alea.randi_range(PARCELLE_MINI, PARCELLE_MAXI)
		var choix: Array = GRANDES if large >= PARCELLE_MAXI - 1 else MAISONS
		# ⚠ ON TIRE DANS LE SAC, ET LE QUART DE TOUR DEMANDÉ EST ZÉRO — ce qui a
		# l'air faux et ne l'est pas. `modele_qui_tient` filtre sur
		# `emprise_tournee(m, q).x`, c'est-à-dire l'étendue du modèle SELON X une
		# fois tourné ; ce qu'on veut limiter, c'est sa FAÇADE, son étendue le
		# long du trottoir. Les deux coïncident toujours sur `q = 0` : une rue
		# horizontale donne un `q` pair (façade = e.x), une rue verticale un `q`
		# impair (façade = e.y, qui est le e.x d'avant rotation). Dans les deux
		# cas la façade vaut `emprise(m).x`, et c'est ce que rend
		# `emprise_tournee(m, 0).x`.
		var m := Lotisseur.modele_qui_tient(choix, 0, large, alea)
		# Le sac peut ne rien avoir d'assez étroit pour cette parcelle-ci : on
		# passe, on ne force pas un modèle qui déborderait sur le voisin.
		if m == "":
			k += 2
			continue
		var q := _face_vers(-n)
		var e := KitVille2.emprise_tournee(m, q)
		# LA FAÇADE : l'étendue de la maison LE LONG DU TROTTOIR, en demi-cases.
		var facade := e.x if d.x != 0 else e.y
		# ⚠ LA PARCELLE FAIT TOUJOURS AU MOINS LA FAÇADE PLUS UNE DEMI-CASE.
		# L'ancienne formule, `(maxi(large, facade) + 1) / 2`, rendait DEUX
		# cases pour une façade de quatre demi-cases : quarante mètres de
		# terrain pour quarante mètres de maison, c'est-à-dire zéro jardin
		# latéral et deux pavillons qui se touchent. Ça ne se voyait pas tant
		# que la clôture serrait la maison ; dès qu'elle a suivi la parcelle,
		# les barrières de deux voisins se sont croisées. `facade + 1` garantit
		# cinq mètres de chaque côté, ce qui est le minimum pour qu'on lise deux
		# maisons et non un immeuble.
		var pas := maxi(2, (maxi(large, facade + 1) + 1) / 2)
		# ⚠ ET LA MAISON SE CENTRE DANS SA PARCELLE. Elle était calée sur le
		# BORD : le terrain lui tombait tout entier d'un seul côté, et une
		# clôture centrée sur la maison (la seule information dont dispose
		# `_les_jardins`, qui ne relit que le lot) mordait forcément sur le
		# voisin d'en face. On décale donc de la moitié du reste, en demi-cases
		# — la division entière laisse au pire cinq mètres de travers, que la
		# marge de clôture absorbe.
		var jeu := (pas * 2 - facade) / 2
		# ⚠ LE COIN SE CALCULE DEPUIS LE BORD DE LA CASE DE RUE, PAS DEPUIS SON
		# MILIEU. Tout est en demi-cases : la case de rue (i, j) occupe les
		# demi-cases 2i et 2i+1. Une maison à l'EST commence donc en 2(i+1),
		# plus le recul ; une maison à l'OUEST FINIT en 2i moins le recul, donc
		# son coin est encore `e.x` plus loin. Mélanger les deux donnait des
		# maisons plantées dans la chaussée, que `terrain_libre` refusait — d'où
		# une banlieue à moitié vide au premier jet.
		# Le décalage de centrage se compte LE LONG de la rue, donc sur l'axe
		# que la normale ne touche pas — d'où les deux `else`.
		var cx := b.x * 2
		var cy := b.y * 2
		if n.x > 0: cx = (b.x + 1) * 2 + RECUL
		elif n.x < 0: cx = b.x * 2 - RECUL - e.x
		else: cx = b.x * 2 + d.x * jeu
		if n.y > 0: cy = (b.y + 1) * 2 + RECUL
		elif n.y < 0: cy = b.y * 2 - RECUL - e.y
		else: cy = b.y * 2 + d.y * jeu
		if Lotisseur.terrain_libre(v, cx, cy, e) and alea.randf() < 0.93:
			var k_lot := v.ajouter_lot(m, cx, cy, e.x, e.y, q, "pavillon")
			# ⚠ LA PARCELLE ET SON OUVERTURE SE NOTENT SUR LE LOT. La clôture
			# est posée plus tard (`_les_jardins`), et il lui faut deux choses
			# que seul ce moment-ci connaît : DE QUEL CÔTÉ EST LA RUE, et OÙ
			# L'ALLÉE la traverse. Sans le premier elle ferme la parcelle du
			# mauvais côté ; sans le second elle barre l'entrée du garage.
			v.lots[k_lot]["rue"] = [n.x, n.y]
			v.lots[k_lot]["allee"] = _devant_de_maison(v, Vector2i(cx, cy), e, n, alea)
			# ⚠ ON NOTE LE PAS SUR LE LOT. C'est la LARGEUR RÉELLE de la
			# parcelle, en cases de trottoir — la seule mesure qui dise où
			# s'arrête ce terrain et où commence celui du voisin. La clôture la
			# lisait jusqu'ici dans la taille de la MAISON, ce qui est un autre
			# nombre : deux maisons étroites plantées sur des parcelles larges
			# se retrouvaient ceintes de deux petits rectangles séparés par
			# quinze mètres de pelouse à personne, et une grande maison sur une
			# parcelle serrée voyait sa clôture lui passer dans les murs.
			v.lots[k_lot]["parcelle"] = pas
			# On avance de toute la parcelle : l'emprise de la maison, plus le
			# jardin latéral. C'est ce vide-là qui fait la banlieue.
			k += pas
		else:
			k += 2

## Le quart de tour qui met la façade (le −Z du modèle) dans ce sens.
static func _face_vers(sens: Vector2i) -> int:
	if sens == Vector2i(0, -1): return 0
	if sens == Vector2i(1, 0): return 3
	if sens == Vector2i(0, 1): return 2
	return 1

## L'ALLÉE ET LA VOITURE DEVANT (cahier § 3). L'allée part du trottoir et
## rejoint la maison ; la voiture est dessus, une fois sur deux.
## Rend le décalage de l'allée le long de la façade, en unités : c'est là que
## la clôture devra s'ouvrir.
static func _devant_de_maison(v: Ville2, coin: Vector2i, e: Vector2i, n: Vector2i,
		alea: RandomNumberGenerator) -> float:
	var cx := (float(coin.x) + float(e.x) * 0.5) * DEMI
	var cz := (float(coin.y) + float(e.y) * 0.5) * DEMI
	# Le milieu de la façade, décalé d'un quart de largeur : une allée au
	# milieu de la façade passe par la porte d'entrée.
	var travers := Vector2(float(-n.y), float(n.x))
	var biais := (alea.randf_range(0.22, 0.34)) * float(e.x if n.y != 0 else e.y) * DEMI
	var ax := cx - float(n.x) * float(e.x) * 0.5 * DEMI + travers.x * biais
	var az := cz - float(n.y) * float(e.y) * 0.5 * DEMI + travers.y * biais
	var vers_rue := atan2(float(n.x), float(n.y))
	# ⚠ L'ALLÉE DOIT ALLER JUSQU'À LA RUE (demande du client, 13/09 : « pas
	# assez de route qui mène aux maisons »). Elle était bien là — deux dalles —
	# mais elle s'arrêtait à seize mètres de la façade, et le recul de la
	# parcelle en fait dix de plus : entre le bout de l'allée et le trottoir, il
	# restait de la pelouse. Une allée qui ne touche pas la rue ne se lit pas
	# comme une allée, elle se lit comme une tache.
	#
	# La dalle `driveway-long` mesure 7,2 × 8,0 m : quatre bout à bout font
	# trente-deux mètres, soit le recul, la marge et le débord sur le trottoir.
	for t in 4:
		v.ajouter_objet("pavillons/driveway-long",
			ax + float(n.x) * float(t) * DEMI * 0.8,
			az + float(n.y) * float(t) * DEMI * 0.8, vers_rue)
	# ET LE SOL SOUS L'ALLÉE, PEINT PLUTÔT QUE PAVÉ (voir `_allee_privee`).
	_allee_privee(v, Vector2(ax, az), n)
	if alea.randf() < 0.55:
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, ax + float(n.x) * DEMI * 0.4, az + float(n.y) * DEMI * 0.4,
			vers_rue + PI * 0.5)
	# La boîte aux lettres et un arbre d'alignement au bord du trottoir.
	if alea.randf() < 0.5:
		v.ajouter_objet("borne", ax + float(n.x) * DEMI * 1.5 - travers.x * 6.0,
			az + float(n.y) * DEMI * 1.5 - travers.y * 6.0, 0.0)
	if alea.randf() < 0.45:
		var arbre: String = ALIGNEMENT[alea.randi() % ALIGNEMENT.size()]
		v.ajouter_objet(arbre, ax + float(n.x) * DEMI * 1.6 + travers.x * 9.0,
			az + float(n.y) * DEMI * 1.6 + travers.y * 9.0,
			alea.randf() * TAU, alea.randf_range(4.5, 7.0))
	return biais

## ⚠ LA DESSERTE SE PEINT DANS LE SOL, ELLE NE SE POSE PAS DESSUS — et le choix
## a été pesé, parce que le projet sait faire les deux.
##
## Ce qui manquait au client (« pas assez de route qui mène aux maisons »,
## 13/09) n'était pas la dalle d'allée : il y en avait quatre, alignées de la
## façade au trottoir. C'est qu'une dalle de 7,2 × 8 m posée en coordonnées
## LIBRES ne tombe jamais pile au bord d'une tuile de route, qui, elle, est
## calée sur la case. Entre la dernière dalle et le bitume il restait toujours
## un ou deux mètres d'herbe — assez pour que l'œil coupe l'allée en deux et ne
## lise plus une desserte, mais une tache claire dans une pelouse.
##
## TROIS FAÇONS DE RACCORDER, DEUX ÉCARTÉES :
##
## * des TUILES DE CHEMIN du kit nature (`chemins.gd`) : c'est de la terre
##   battue, et ça se raccorde case à case. Mais une allée de garage n'est pas
##   un sentier de sous-bois, et ces tuiles apportent leur carré d'herbe, qu'il
##   faut alors repeindre sommet par sommet — beaucoup de machinerie pour un
##   résultat qui reste un chemin de terre devant un pavillon ;
## * de la MATIÈRE `M_TERRE`, comme les allées de `parc.gd` : le raccord est
##   parfait (une case entière, donc bord à bord avec la tuile de route), mais
##   la couleur est celle d'un labour. Devant une maison, ça se lit comme une
##   cour de ferme ;
## * de la MATIÈRE `M_DALLE`, retenu. C'est le trottoir du kit, le même béton
##   clair que les bords de l'avenue ; il remplit la case ENTIÈRE, donc il
##   touche la chaussée exactement, sans raccord à rater — ce pour quoi
##   `parc.gd` peint au lieu de poser. Les quatre dalles `driveway-long`
##   restent par-dessus : elles portent le dessin de l'allée (les deux bandes
##   de roulement), le béton peint ne fait que la relier à la rue.
##
## ⚠ ON NE PEINT PAS SOUS LA MAISON. `matiere == M_DALLE` fait poser une tuile
## de trottoir à la case (voir `rendu_ville2`), et le client a déjà refusé le
## socle de béton sous un pavillon (« je place un cliff, le sol se transforme en
## béton », 12/09). `demi_libre` écarte les cases que le lot occupe — on les
## saute, on ne s'arrête pas : le recul met parfois la maison à cheval sur deux
## cases, et il faut peindre celle d'après.
static func _allee_privee(v: Ville2, depart: Vector2, n: Vector2i) -> void:
	var c := Vector2i(floori(depart.x / CASE), floori(depart.y / CASE))
	# Quatre cases suffisent : le recul d'une demi-case et la marge de parcelle
	# ne font jamais plus de deux cases. Au-delà, on bétonnerait le jardin.
	for _k in 4:
		if not v.dedans(c) or not v.terre(c): return
		# La rue est atteinte : elle porte déjà sa tuile, il n'y a plus rien à
		# raccorder. C'est la condition d'arrêt, et c'est aussi la garantie
		# qu'on ne peint jamais par-dessus une chaussée ou une courbe large.
		if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): return
		if v.demi_libre(c.x * 2, c.y * 2, 2, 2):
			v.poser_matiere(c, Ville2.M_DALLE)
		c += n

# ------------------------------------------------------------------ la ferme

## LES HANGARS ET LES CHAMPS DE LÉGUMES (demande du client, 13/09, redemandée
## le 14/09 : « tu dois faire des hangars et des champs de légumes »).
##
## ⚠ ET ILS ONT LEUR PLACE TOUTE TROUVÉE : une banlieue, c'est ce qui reste
## quand la ville a mangé la campagne, et le bout qu'elle n'a pas encore mangé
## est justement le terrain agricole du fond. C'est aussi ce qui manquait le
## plus à ce témoin — des hectares d'herbe rase sans rien dessus.
##
## Le kit nature a de vrais sillons (`crops_dirt*`, une case de long) et de
## vraies cultures à quatre stades de pousse. On alterne les planches : maïs,
## blé, feuillu, bambou, potager — un champ d'une seule culture se lit comme
## une moquette.
##
## ⚠ ET LES LÉGUMES-RACINES SONT PLUS BAS QUE TOUT LE RESTE. `crop_pumpkin` et
## `crop_melon` posent à quarante centimètres : à seize pieds la case, ils ne
## couvrent que six mètres sur vingt et la planche ressort en terre nue. On les
## relève (une citrouille de jeu fait 70 cm, pas 40) ET on en met vingt par
## case au lieu de seize. C'est la même arithmétique que le maïs, refaite pour
## la moitié de la hauteur.
const CULTURES := ["nature/crops_cornStageC", "nature/crops_cornStageD",
	"nature/crops_wheatStageB", "nature/crops_leafsStageB", "nature/crops_bambooStageB",
	"nature/crops_cornStageB", "nature/crops_leafsStageA", "nature/crops_wheatStageA",
	"nature/crops_bambooStageA", "nature/crops_cornStageA",
	"nature/crop_carrot", "nature/crop_turnip", "nature/crop_pumpkin", "nature/crop_melon"]
const H_CULTURES = [2.4, 2.4, 1.1, 1.3, 1.8, 1.9, 0.9, 0.7, 1.2, 1.0,
	0.95, 0.95, 0.70, 0.65]
## Combien de pieds par case, et sur combien de rangs. Vingt pieds sur deux
## rangs de dix : c'est le minimum pour qu'une case de vingt mètres soit
## CULTIVÉE et non semée.
const PLANTS_PAR_CASE := 20
const RANGS := 10

## ⚠ LES SILLONS SE POSENT PAR-DESSOUS, ET IL EN FAUT DEUX PAR CASE. Une seule
## tuile brune sur de la terre brune ne se voyait pas — le champ sortait en
## rectangle plat. `crops_dirtDoubleRow` fait une case de long sur 0,94 de
## large : deux décalées donnent à la planche sa rayure de labour.
const SILLONS := ["nature/crops_dirtDoubleRow", "nature/crops_dirtDoubleRow",
	"nature/crops_dirtRow"]

## LES HANGARS AGRICOLES. Le kit n'a pas de grange, mais le kit industriel est
## plein de HALLES : un volume long, bas, à toit à deux pentes ou plat, c'est
## exactement la silhouette d'un hangar de ferme vu d'en haut, et la tôle dont
## on les coiffe (`ATLAS.TOLE`) finit de les sortir de l'usine. Mesurés, ceux-ci
## font tous moins d'une case de haut — c'est le critère : au-delà, ce n'est
## plus un hangar, c'est une usine.
const HANGARS := ["industriel/building-c", "industriel/building-h", "industriel/building-i",
	"industriel/building-q", "industriel/building-s", "industriel/building-p",
	"industriel/building-j", "industriel/building-k"]
## LE SILO, posé en objet et non en lot : `water-tower` fait 43 m à l'échelle du
## kit, ce qui est un château d'eau de ville ; ramené à 22 m c'est un silo de
## coopérative, et c'est le repère qui dit « ferme » de l'autre bout du témoin.
const SILO := "industriel/water-tower"
const H_SILO := 22.0

## ⚠ OÙ LA FERME A SA PLACE, ET POURQUOI ON LA NOMME PLUTÔT QUE DE LA CHERCHER.
##
## `_zone_libre` balaie et prend le premier trou : c'était la bonne réponse tant
## que la ferme passait APRÈS le lotisseur, parce qu'alors il ne restait que des
## trous. Maintenant qu'elle passe avant, le balayage rendrait le coin
## nord-ouest — deux cases du bord de carte, là où personne ne regarde.
##
## Les deux endroits ci-dessous sont choisis, et chacun pour une raison :
##
## * LE CREUX DE LA BOUCLE (13,7 → 22,12). La boucle le borde sur ses quatre
##   côtés : les hangars donnent directement sur la chaussée au nord, et le
##   champ est vu depuis trois rues. C'est aussi le morceau que les deux
##   impasses supprimées desservaient pour rien ;
## * LA LISIÈRE SUD-EST (22,33 → 31,38), sous la route d'entrée, entre la
##   desserte de la rue du Pré et celle des Cigales : le bout de campagne que
##   la ville n'a pas encore mangé, littéralement au bord du témoin.
##
## Les deux s'arrêtent à une case des angles de la boucle : `ANGLES.arrondir`
## pose des courbes de deux cases sur deux, et une courbe posée dans un champ
## le couperait en deux.
const FERMES_POSSIBLES := [Rect2i(13, 7, 10, 6), Rect2i(22, 33, 10, 6)]

static func _la_ferme(v: Ville2, alea: RandomNumberGenerator) -> void:
	var zone := Rect2i()
	for r in FERMES_POSSIBLES:
		var candidate: Rect2i = r
		if _zone_est_libre(v, candidate):
			zone = candidate
			break
	# ⚠ ON RÉTRÉCIT PLUTÔT QUE D'ABANDONNER. Si les deux emplacements nommés
	# sont pris — ce qui n'arrive qu'avec une autre taille de carte ou un autre
	# tracé — on balaie, et on réessaie plus petit à chaque échec. Une demande
	# de place qui échoue en silence, c'est la ferme qui n'existe pas et rien
	# dans l'image pour le dire : c'est déjà arrivé au casino du quartier chaud
	# et à l'église de ce témoin-ci.
	if zone.size.x == 0:
		for taille in [Vector2i(10, 6), Vector2i(9, 6), Vector2i(8, 5), Vector2i(7, 5)]:
			zone = _zone_libre(v, taille.x, taille.y)
			if zone.size.x > 0: break
	if zone.size.x == 0:
		push_warning("ferme : pas de place")
		return
	# LES HANGARS D'ABORD, en tête de champ, façade au nord : ils doivent se
	# poser AVANT que la cour soit réservée, sinon `terrain_libre` les refuse
	# sur les cases que la ferme vient de prendre pour elle-même.
	Lotisseur.aligner(v, alea, HANGARS, "n",
		Vector2i(zone.position.x * 2, zone.position.y * 2), (zone.size.x - 2) * 2,
		"hangar", 0.9, 1)
	# LES PLANCHES DE CULTURE. Une planche = une bande d'une case de large, avec
	# ses sillons au sol et ses plants dessus. Elles courent toutes dans le même
	# sens : c'est le labour qui l'impose, et c'est ce qui se lit d'en haut.
	var champs := Rect2i(zone.position.x, zone.position.y + 3, zone.size.x, zone.size.y - 3)
	for j in range(champs.position.y, champs.end.y):
		var n := alea.randi() % CULTURES.size()
		var sillon: String = SILLONS[alea.randi() % SILLONS.size()]
		for i in range(champs.position.x, champs.end.x):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0: continue
			v.poser_matiere(c, Ville2.M_TERRE)
			_reserver(v, c)
			for d in [0.28, 0.72]:
				v.ajouter_objet(sillon, (float(i) + 0.5) * CASE,
					(float(j) + d) * CASE, 0.0)
			# ⚠ ET IL FAUT BEAUCOUP DE PLANTS. Un pied de maïs ramené à sa
			# taille réelle (2,4 m) fait soixante centimètres de large ; cinq
			# par case en couvrent trois mètres sur vingt. Le premier champ est
			# sorti en terre nue pour cette raison — la même arithmétique que
			# les baraques du bidonville, le même oubli.
			for k in PLANTS_PAR_CASE:
				v.ajouter_objet(CULTURES[n],
					(float(i) + 0.05 + float(k % RANGS) * (0.90 / float(RANGS - 1))) * CASE,
					(float(j) + (0.30 if k < RANGS else 0.72)
						+ alea.randf_range(-0.05, 0.05)) * CASE,
					alea.randf() * TAU, float(H_CULTURES[n]) * alea.randf_range(0.9, 1.1))
	# ⚠ LA COUR SE MEUBLE SUR CE QUI RESTE, ET ON LE DEMANDE AU REGISTRE VIVANT.
	# Les hangars viennent d'être posés à coups de `terrain_libre` : on ne sait
	# pas lesquels sont passés, ni où. Poser le tracteur sur une coordonnée
	# écrite en dur, c'est une chance sur deux de le planter DANS un hangar —
	# et `lot_sur()` ne le dirait pas, puisqu'il date de la rastérisation
	# d'avant. `demi_libre`, lui, connaît la halle posée il y a trois lignes.
	var cour: Array = []
	for j in range(zone.position.y, champs.position.y):
		for i in range(zone.position.x, zone.end.x):
			if v.demi_libre(i * 2, j * 2, 2, 2): cour.append(Vector2i(i, j))
	# Le tracteur, le silo et les bottes, sur les cases restées vides. Le silo
	# prend la dernière (l'est de la cour), le tracteur la première.
	if not cour.is_empty():
		var t: Vector2i = cour[0]
		v.ajouter_objet("voitures/tractor", (float(t.x) + 0.5) * CASE,
			(float(t.y) + 0.6) * CASE, PI * 0.5)
		var s: Vector2i = cour[cour.size() - 1]
		v.ajouter_objet(SILO, (float(s.x) + 0.5) * CASE, (float(s.y) + 0.5) * CASE,
			0.0, H_SILO)
		for k in 12:
			var c2: Vector2i = cour[alea.randi() % cour.size()]
			v.ajouter_objet(["nature/log_stack", "nature/pot_large", "nature/crops_dirtSingle"][k % 3],
				(float(c2.x) + alea.randf()) * CASE, (float(c2.y) + alea.randf()) * CASE,
				alea.randf() * TAU, [1.6, 1.0, 0.5][k % 3])
	# LA COUR EST RÉSERVÉE ELLE AUSSI, une fois meublée : sans ça le lotisseur
	# vient planter des pavillons entre les hangars et le champ, et la ferme
	# n'a plus de cour.
	for j in range(zone.position.y, champs.position.y):
		for i in range(zone.position.x, zone.end.x):
			_reserver(v, Vector2i(i, j))
	v.ajouter_lieu("ferme", (float(zone.position.x) + float(zone.size.x) * 0.5) * CASE,
		(float(zone.position.y) + float(zone.size.y) * 0.5) * CASE,
		{"nom": "Les Maraîchers"})

## Réserve une case contre tout lot à venir. C'est le seul registre que
## `Lotisseur.terrain_libre` consulte à l'instant même (`lot_sur` date de la
## dernière rastérisation) : une zone qu'on veut garder se marque ici.
static func _reserver(v: Ville2, c: Vector2i) -> void:
	for b in 2:
		for a in 2:
			v.demi_prises[Vector2i(c.x * 2 + a, c.y * 2 + b)] = true

## Vrai si ce rectangle de cases est entièrement disponible : à terre, sans
## route, sans grosse pièce, sans lot et sans réservation.
static func _zone_est_libre(v: Ville2, r: Rect2i) -> bool:
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): return false
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): return false
			if v.lot_sur(c) >= 0: return false
			if not v.demi_libre(c.x * 2, c.y * 2, 2, 2): return false
	return true

## ⚠ ON CHERCHE LA PLACE, ON NE LA DÉCRÈTE PAS. Écrire un `Rect2i` en dur pour
## la ferme, c'est reproduire l'erreur du stade du campus : la boucle de rues
## de ce témoin est tracée à la main, et le moindre décalage la ferait passer
## au travers. On balaie donc la carte et on prend le premier rectangle
## entièrement libre — terre, sans route, sans pièce, sans lot.
static func _zone_libre(v: Ville2, larg: int, haut: int) -> Rect2i:
	for j in range(2, v.taille.y - haut - 1):
		for i in range(2, v.taille.x - larg - 1):
			var bon := true
			for b in range(haut + 1):
				for a in range(larg + 1):
					var c := Vector2i(i + a, j + b)
					if not v.dedans(c) or not v.terre(c): bon = false
					elif v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): bon = false
					elif v.lot_sur(c) >= 0: bon = false
					if not bon: break
				if not bon: break
			if bon: return Rect2i(i, j, larg, haut)
	return Rect2i()

# ------------------------------------------------------------------ 4. le pôle

## L'ÉCOLE, LE TERRAIN DE SPORT ET LES COMMERCES (cahier § 3), sur la route
## d'entrée : c'est le seul endroit du quartier où l'on ne vient pas que pour
## rentrer chez soi.
static func _le_pole(v: Ville2, alea: RandomNumberGenerator) -> void:
	# Les commerces bordent la route d'entrée, au sud.
	Lotisseur.aligner(v, alea, COMMERCES, "n",
		Vector2i(4 * 2, (J_ENTREE + 1) * 2), 18 * 2, "commerce", 0.8, 1)
	# L'école : un bâtiment large, face à la route.
	var m := "batiments/building-n"
	if not ResourceLoader.exists(KitVille2.chemin(m)): m = "batiments/building-l"
	var e := KitVille2.emprise_tournee(m, 2)
	if Lotisseur.terrain_libre(v, ECOLE.position.x * 2, ECOLE.position.y * 2, e):
		v.ajouter_lot(m, ECOLE.position.x * 2, ECOLE.position.y * 2, e.x, e.y, 2, "ecole")
		v.ajouter_lieu("ecole", (float(ECOLE.position.x) + 2.0) * CASE,
			(float(ECOLE.position.y) + 1.5) * CASE, {"nom": "École des Tilleuls"})
	# ⚠ LES REPÈRES DU CLIENT, ET PAS SEULEMENT DES BOÎTES DU KIT. L'église et
	# la supérette sont des modèles faits pour ce jeu (`modeles/piksl/`) : un
	# quartier qui n'en porte aucun se lit comme du Kenney tout nu. L'église
	# marque le cœur du village, la supérette la route d'entrée — c'est là
	# qu'on s'arrête en rentrant.
	_poser_repere(v, "piksl/eglise", Vector2i(24, 28), 2, "eglise", "Église du Verger")
	_poser_repere(v, "piksl/supermarket", Vector2i(16, 32), 0, "supermarche",
		"Supérette des Tilleuls")
	# La cabine téléphonique, au coin de la place : le détail qui date le
	# quartier.
	v.ajouter_objet("cabine", 15.4 * CASE, 32.8 * CASE, PI)

	# LE TERRAIN DE SPORT : une dalle et une clôture autour. Le kit n'a pas de
	# terrain tout fait — c'est le grillage qui le dessine.
	var t := Rect2i(ECOLE.position.x + 6, ECOLE.position.y - 4, 6, 4)
	for j in range(t.position.y, t.end.y):
		for i in range(t.position.x, t.end.x):
			v.poser_matiere(Vector2i(i, j), Ville2.M_TERRE)
	_clore(v, t, alea, 1.9, "urbain/construction-fence")
	v.ajouter_lieu("sport", (float(t.position.x) + 3.0) * CASE,
		(float(t.position.y) + 2.0) * CASE, {"nom": "Stade du Quartier"})

# ------------------------------------------------------------------ 5. le parc

## LE PARC DU QUARTIER : des allées de dalles, des massifs, des bancs, et
## surtout des ARBRES EN NOMBRE — un parc est d'abord une masse d'arbres.
static func _le_parc(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := PARC
	# ⚠ LES TUILES DE SENTIER SE RACCORDENT — C'ÉTAIT MA ROTATION QUI ÉTAIT
	# FAUSSE. Premier jet : le chemin de chaque tuile sortait EN TRAVERS de
	# l'allée, d'où un damier de bandes qui ne se suivaient pas (« tu vois bien
	# qu'aucune flèche ne se suit », client, 12/09, capture annotée). Le tort
	# n'était pas au kit : `ground_pathStraight` porte son chemin selon un axe
	# précis, et je l'avais posé de travers dans les deux branches.
	#
	# ⚠⚠ ET MON BANC D'ESSAI M'A MENTI. J'avais aligné trois tuiles sur la
	# planche d'échelle pour trancher — mais elle espace les modèles de trois
	# unités, et une tuile de sol en fait vingt : elles se chevauchaient, et le
	# résultat illisible m'a fait conclure qu'elles n'étaient pas modulaires.
	# UNE TUILE DE SOL NE SE TESTE QU'AU PAS DE LA CASE. Le client, lui, les
	# raccorde à la main sans difficulté : « si elles le sont, j'y arrive ».
	#
	# La croix : `ground_pathStraight` sur les branches, `ground_pathCross` au
	# croisement, `ground_pathEnd` aux quatre bouts.
	var jm := r.position.y + r.size.y / 2
	var im := r.position.x + r.size.x / 2
	for i in range(r.position.x, r.end.x):
		var m := "nature/ground_pathStraight"
		if i == im: m = "nature/ground_pathCross"
		elif i == r.position.x or i == r.end.x - 1: m = "nature/ground_pathEnd"
		var tour := AXE_DU_SENTIER + (PI if i == r.end.x - 1 else 0.0)
		v.ajouter_objet(m, (float(i) + 0.5) * CASE, (float(jm) + 0.5) * CASE, tour)
		v.objets[v.objets.size() - 1]["aplat"] = CHEMINS.APLAT
	for j in range(r.position.y, r.end.y):
		if j == jm: continue
		var m := "nature/ground_pathStraight"
		if j == r.position.y or j == r.end.y - 1: m = "nature/ground_pathEnd"
		var tour := AXE_DU_SENTIER + PI * 0.5 + (PI if j == r.position.y else 0.0)
		v.ajouter_objet(m, (float(im) + 0.5) * CASE, (float(j) + 0.5) * CASE, tour)
		v.objets[v.objets.size() - 1]["aplat"] = CHEMINS.APLAT
	var clairiere := Rect2i(r.position + Vector2i(1, 1), Vector2i(2, 2))
	# Les bancs, en bordure de la clairière, tournés vers elle.
	for k in 8:
		var a := TAU * float(k) / 8.0
		var x := (float(clairiere.position.x) + float(clairiere.size.x) * 0.5) * CASE \
			+ cos(a) * 2.2 * CASE
		var z := (float(clairiere.position.y) + float(clairiere.size.y) * 0.5) * CASE \
			+ sin(a) * 2.0 * CASE
		v.ajouter_objet("banc", x, z, -a + PI * 0.5)
	# Les arbres et les massifs, partout sauf dans la clairière.
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			if i == im or j == jm: continue
			if clairiere.has_point(Vector2i(i, j)): continue
			if alea.randf() < 0.78:
				var m: String = ALIGNEMENT[alea.randi() % ALIGNEMENT.size()]
				v.ajouter_objet(m, (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					alea.randf_range(5.0, 8.5))
			if alea.randf() < 0.35:
				var f := ["nature/flower_redA", "nature/flower_yellowB",
					"nature/flower_purpleC", "nature/plant_bushDetailed"]
				v.ajouter_objet(f[alea.randi() % f.size()],
					(float(i) + alea.randf()) * CASE, (float(j) + alea.randf()) * CASE,
					alea.randf() * TAU, alea.randf_range(0.45, 0.90))
	# LE BASSIN (cahier § 7 : « grands parcs dessinés — allées, plans d'eau »),
	# dans le quart nord-est, avec ses nénuphars.
	var bx := (float(r.position.x) + float(r.size.x) * 0.78) * CASE
	var bz := (float(r.position.y) + float(r.size.y) * 0.25) * CASE
	# ⚠ UN BASSIN DE PARC N'EST PAS UNE PISCINE. Le cyan de piscine (#4fb3d9)
	# faisait un rectangle turquoise au milieu des arbres, visible d'un bout à
	# l'autre du témoin : une eau de parc est verte et sombre, elle reçoit le
	# reflet des feuillages. La même couleur que les étangs de `parc.gd`.
	v.ajouter_objet("pelouse", bx, bz, 0.0, 0.0, "#2f6b74")
	v.objets[v.objets.size() - 1]["w"] = 2.2 * CASE
	v.objets[v.objets.size() - 1]["d"] = 1.6 * CASE
	for _k in 6:
		v.ajouter_objet("nenuphar", bx + alea.randf_range(-1.0, 1.0) * CASE,
			bz + alea.randf_range(-0.7, 0.7) * CASE, alea.randf() * TAU)
	v.ajouter_lieu("parc", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(r.position.y) + float(r.size.y) * 0.5) * CASE,
		{"nom": "Parc des Tilleuls"})

# ------------------------------------------------------------------ 6. les jardins

## LE JARDIN DE DERRIÈRE (cahier § 3 : « piscines, barbecues, trampolines »).
## On relit les lots posés et on meuble la bande qui se trouve DERRIÈRE la
## maison, c'est-à-dire du côté opposé à sa façade.
static func _les_jardins(v: Ville2, alea: RandomNumberGenerator) -> void:
	for l in v.lots:
		if String(l.get("genre", "")) != "pavillon": continue
		var rue: Array = l.get("rue", [0, 1])
		var n := Vector2(float(rue[0]), float(rue[1]))       # vers la rue
		var fond := -n
		var travers := Vector2(-n.y, n.x)
		var c := v.centre_du_lot(l)
		# LA PARCELLE : la maison, plus une marge de jardin tout autour. C'est
		# ce rectangle que la clôture suit.
		var large := float(l["w"]) * DEMI
		var profond := float(l["h"]) * DEMI
		# L'étendue de la MAISON le long de la rue : c'est elle qu'il ne faut
		# jamais recouper, quoi que dise la largeur de parcelle.
		var lateral: float = large if absf(n.y) > 0.5 else profond
		# ⚠ LA CLÔTURE SUIT LA PARCELLE, PAS LA MAISON. `parcelle` est le pas
		# dont `_border_la_rue` a avancé le long du trottoir après avoir posé
		# cette maison-ci : c'est la largeur du terrain, en cases, et la maison
		# y a été centrée exprès pour que ce rectangle-ci, centré sur elle,
		# tombe juste. La clôture lisait jusqu'ici la taille de la MAISON, ce
		# qui est un autre nombre : deux pavillons étroits sur des parcelles
		# larges se retrouvaient ceints de deux petits rectangles séparés par
		# quinze mètres de pelouse à personne.
		#
		# Les trois mètres retirés sont le passage entre deux propriétés — il
		# fait partie du dessin — et ils absorbent aussi la demi-case de travers
		# que laisse le centrage en nombres entiers. Le plancher (la maison plus
		# trois mètres) protège le cas inverse : sur une parcelle serrée, une
		# clôture calée sur le terrain passerait dans les murs.
		var pas := int(l.get("parcelle", 2))
		var demi_lat := maxf(float(pas) * CASE * 0.5 - 3.0, lateral * 0.5 + 3.0)
		var vers_rue := (profond if absf(n.y) > 0.5 else large) * 0.5 + MARGE_RUE
		var vers_fond := (profond if absf(n.y) > 0.5 else large) * 0.5 + MARGE_FOND
		var centre := Vector2(c.x, c.z)
		var allee := float(l.get("allee", 0.0))
		_clore_la_parcelle(v, centre, n, travers, demi_lat, vers_rue, vers_fond, allee, alea)
		_meubler_le_jardin(v, centre, fond, travers, demi_lat, vers_fond, alea)

## Les marges de la parcelle DEVANT et DERRIÈRE la maison, en unités. Sur les
## côtés il n'y a plus de marge : c'est la largeur de parcelle notée à la pose
## qui commande (voir `_les_jardins`), parce qu'elle seule sait où s'arrête ce
## terrain-ci et où commence celui du voisin.
const MARGE_RUE := 5.0
const MARGE_FOND := 9.0
## La largeur de l'ouverture laissée devant l'allée.
const PASSAGE := 9.0

## ⚠ LA CLÔTURE FAIT LE TOUR DE LA PARCELLE, PAS UN BOUT DE FOND DE JARDIN.
## Premier jet : trois panneaux au fond du jardin — ça donnait des morceaux de
## barrière posés dans l'herbe, sans rien clore. Le client a envoyé le dessin :
## un RECTANGLE autour de la propriété, ouvert là où l'allée traverse. C'est
## ce que fait cette fonction — les quatre côtés, panneaux bout à bout, et une
## brèche sur le côté rue.
static func _clore_la_parcelle(v: Ville2, centre: Vector2, n: Vector2, travers: Vector2,
		demi_lat: float, vers_rue: float, vers_fond: float, allee: float,
		alea: RandomNumberGenerator) -> void:
	var m: String = CLOTURES[alea.randi() % CLOTURES.size()]
	var pan := _longueur_de_cloture(m)
	# Les quatre coins de la parcelle, dans le repère (travers, n).
	var a := centre + travers * -demi_lat + n * vers_rue      # rue, gauche
	var b := centre + travers * demi_lat + n * vers_rue       # rue, droite
	var c2 := centre + travers * demi_lat - n * vers_fond     # fond, droite
	var d2 := centre + travers * -demi_lat - n * vers_fond    # fond, gauche
	# ⚠ LES ANGLES D'ABORD, LES CÔTÉS ENSUITE. Une pièce d'angle occupe une
	# case pleine : si on aligne les panneaux jusqu'au coin, ils la traversent.
	# On retire donc un demi-angle à chaque bout de côté.
	var angle_long := _longueur_de_cloture(ANGLE_CLOTURE)
	for coin in [[a, 0], [b, 1], [c2, 2], [d2, 3]]:
		var p: Vector2 = coin[0]
		v.ajouter_objet(ANGLE_CLOTURE, p.x, p.y,
			atan2(n.x, n.y) + PI * 0.5 * float(int(coin[1])), H_CLOTURE)
	# Le côté rue s'ouvre devant l'allée ; les trois autres sont pleins.
	var marge := angle_long * 0.5
	_un_cote(v, a, b, m, pan, allee, PASSAGE, marge)
	_un_cote(v, b, c2, m, pan, 0.0, 0.0, marge)
	_un_cote(v, c2, d2, m, pan, 0.0, 0.0, marge)
	_un_cote(v, d2, a, m, pan, 0.0, 0.0, marge)

## Un côté de clôture, de `a` à `b`, en panneaux bout à bout. `ouvre` est le
## décalage du centre de la brèche depuis le MILIEU du côté, `passage` sa
## largeur (0 : pas de brèche).
static func _un_cote(v: Ville2, a: Vector2, b: Vector2, modele: String, pan: float,
		ouvre: float, passage: float, marge := 0.0) -> void:
	var brut := a.distance_to(b)
	if brut < 0.5 or pan < 0.1: return
	var sens := (b - a) / brut
	# On s'arrête avant les pièces d'angle, à chaque bout.
	a += sens * marge
	var longueur := brut - marge * 2.0
	if longueur < pan * 0.5: return
	# On ajuste le pas pour tomber juste : mieux vaut des panneaux un chouïa
	# plus courts qu'un trou au coin.
	var combien := maxi(1, int(round(longueur / pan)))
	var pas := longueur / float(combien)
	var angle := atan2(sens.x, sens.y) + PI * 0.5
	for k in combien:
		var t := (float(k) + 0.5) * pas
		# La brèche se compte depuis le milieu du côté.
		if passage > 0.0 and absf(t - (longueur * 0.5 + ouvre)) < passage * 0.5: continue
		var p := a + sens * t
		v.ajouter_objet(modele, p.x, p.y, angle, H_CLOTURE)

## LA PISCINE PRIVÉE, et c'est un vrai modèle maintenant (`modeles/pxl/`).
## Jusqu'ici c'était un rectangle de sol plat teinté en cyan — la même brique
## que les pelouses de la place du centre. Ça faisait une flaque turquoise sans
## margelle, sans échelle et sans épaisseur : de loin, une bâche. Le modèle
## mesure 8 × 0,88 × 4 m, ce qui est une piscine de jardin, et il porte sa
## margelle et son eau.
const PISCINE := "pxl/piscine-privee"
## LE GARAGE DÉTACHÉ DU FOND DE JARDIN : `building-garage` fait 11 m de haut à
## l'échelle du kit — un hangar. Ramené à 6 m, c'est le garage-atelier qu'on
## voit au bout d'une allée de banlieue, et il donne au jardin un second
## volume, ce qui manquait le plus aux arrière-cours.
const GARAGE := "ville/building-garage"
const H_GARAGE := 6.0

## Ce qu'il y a DANS la parcelle, derrière la maison : la piscine et le jardin.
static func _meubler_le_jardin(v: Ville2, centre: Vector2, fond: Vector2, travers: Vector2,
		demi_lat: float, vers_fond: float, alea: RandomNumberGenerator) -> void:
	# ⚠ LA PISCINE EST TOUJOURS DANS LE JARDIN DE DERRIÈRE, ET JAMAIS À CHEVAL
	# SUR LA CLÔTURE. Les trois nombres qui le garantissent :
	#   * elle est posée à 55 % du fond, alors que la clôture est à 100 % ;
	#   * elle fait 4 m dans ce sens-là, donc son bord tombe à 0,55·f + 2, et
	#     `vers_fond` ne descend jamais sous 19 m — il reste six mètres de
	#     pelouse derrière elle ;
	#   * son grand axe (8 m) est mis EN TRAVERS du jardin, où `demi_lat` fait
	#     au moins 18 m de chaque côté.
	# Une maison sur six, comme demandé : plus souvent, la banlieue devient un
	# village de vacances.
	if alea.randf() < 0.17:
		var p := centre + fond * (vers_fond * 0.55)
		# Le modèle est couché selon X au repos : on l'aligne sur `travers`.
		# Le −Z d'un modèle tourné de `r` pointe (−sin r, −cos r), donc son +X
		# pointe (cos r, −sin r) — d'où l'atan2 inversé.
		v.ajouter_objet(PISCINE, p.x, p.y, atan2(-travers.y, travers.x))
	# Le garage du fond, une fois sur cinq, dans un coin de la parcelle et
	# tourné vers la maison.
	if alea.randf() < 0.20:
		var cote: float = 1.0 if alea.randf() < 0.5 else -1.0
		var g := centre + fond * (vers_fond * 0.68) + travers * (demi_lat * 0.62 * cote)
		v.ajouter_objet(GARAGE, g.x, g.y, atan2(fond.x, fond.y), H_GARAGE)
	for _k in alea.randi_range(3, 6):
		var n := alea.randi() % JARDIN.size()
		var q := centre + fond * (vers_fond * alea.randf_range(0.35, 0.9)) \
			+ travers * alea.randf_range(-0.8, 0.8) * demi_lat
		v.ajouter_objet(JARDIN[n], q.x, q.y, alea.randf() * TAU, float(H_JARDIN[n]))

## La longueur au sol d'un panneau de clôture posé à `H_CLOTURE`. Un modèle mis
## à une hauteur voulue est mis à l'échelle DANS LES TROIS AXES : sa longueur
## suit sa hauteur, et c'est elle qu'il faut connaître pour les aligner.
static func _longueur_de_cloture(modele: String) -> float:
	var t := KitVille2.taille(modele) * CASE
	if t.y < 0.01: return DEMI
	return maxf(t.x, t.z) * (H_CLOTURE / t.y)

# ------------------------------------------------------------------ 7. les détails

static func _details(v: Ville2, alea: RandomNumberGenerator) -> void:
	# Les lampadaires le long de la boucle, un carrefour sur deux.
	for r in v.routes:
		var cases := Ville2.cases_de_route(r)
		var pas := 6 if String(r["genre"]) == Ville2.R_AVENUE else 8
		for k in range(2, cases.size(), pas):
			var c: Vector2i = cases[k]
			v.ajouter_objet("lampadaire_parc", (float(c.x) + 0.12) * CASE,
				(float(c.y) + 0.12) * CASE, 0.0)
	# LA RAQUETTE DE RETOURNEMENT au bout de chaque impasse : quelques bornes
	# en arc. Sans elle, une impasse se lit comme une rue coupée.
	for im in IMPASSES:
		var de: Vector2i = im["de"]
		var vers: Vector2i = im["vers"]
		var bout: Vector2i = de + vers * int(im["long"])
		for k in 5:
			var a := PI * (0.25 + 0.5 * float(k) / 4.0) + atan2(float(vers.x), float(vers.y))
			v.ajouter_objet("borne", (float(bout.x) + 0.5) * CASE + cos(a) * 13.0,
				(float(bout.y) + 0.5) * CASE + sin(a) * 13.0, 0.0)
	# Un ou deux terrains vagues : une banlieue qui s'étend a toujours une
	# parcelle pas encore bâtie.
	for coin in [Vector2i(8, 27)]:
		for j in range(coin.y, coin.y + 3):
			for i in range(coin.x, coin.x + 3):
				var c := Vector2i(i, j)
				if not v.dedans(c) or v.lot_sur(c) >= 0: continue
				if v.carte != null and v.carte.route(c): continue
				v.poser_matiere(c, Ville2.M_TERRE)
				if alea.randf() < 0.4:
					v.ajouter_objet("nature/grass_large", (float(i) + alea.randf()) * CASE,
						(float(j) + alea.randf()) * CASE, alea.randf() * TAU, 0.70)
		_clore(v, Rect2i(coin, Vector2i(3, 3)), alea, 1.9, "urbain/construction-fence")

## ⚠ UN REPÈRE CHERCHE SA PLACE, IL N'ABANDONNE PAS AU PREMIER REFUS. Premier
## jet : une seule case essayée, et si elle était prise le bâtiment n'existait
## pas — l'église du quartier n'est jamais apparue une seule fois, sans que rien
## ne le signale. On s'écarte donc en SPIRALE CARRÉE autour du point voulu, et
## on essaie les quatre orientations. Ce n'est qu'après avoir tout essayé qu'on
## renonce, et alors c'est un vrai manque de place, pas un hasard.
static func _poser_repere(v: Ville2, modele: String, depart: Vector2i, quarts: int,
		genre: String, nom: String, portee := 7) -> bool:
	for tour in [quarts, (quarts + 2) % 4, (quarts + 1) % 4, (quarts + 3) % 4]:
		var e := KitVille2.emprise_tournee(modele, tour)
		for rayon in range(0, portee):
			for dj in range(-rayon, rayon + 1):
				for di in range(-rayon, rayon + 1):
					if maxi(absi(di), absi(dj)) != rayon: continue
					var c := depart + Vector2i(di, dj)
					if c.x < 1 or c.y < 1: continue
					if not Lotisseur.terrain_libre(v, c.x * 2, c.y * 2, e): continue
					v.ajouter_lot(modele, c.x * 2, c.y * 2, e.x, e.y, tour, genre)
					v.ajouter_lieu(genre, (float(c.x) + float(e.x) * 0.25) * CASE,
						(float(c.y) + float(e.y) * 0.25) * CASE, {"nom": nom})
					return true
	push_warning("repère « %s » : pas de place" % nom)
	return false

## Un grillage autour d'un rectangle de cases : un panneau par case de bord.
static func _clore(v: Ville2, r: Rect2i, alea: RandomNumberGenerator, hauteur: float,
		modele: String) -> void:
	for i in range(r.position.x, r.end.x):
		for j in [r.position.y, r.end.y - 1]:
			if alea.randf() < 0.12: continue          # une brèche de temps en temps
			v.ajouter_objet(modele, (float(i) + 0.5) * CASE,
				(float(j) + (0.02 if j == r.position.y else 0.98)) * CASE, 0.0, hauteur)
	for j in range(r.position.y, r.end.y):
		for i in [r.position.x, r.end.x - 1]:
			if alea.randf() < 0.12: continue
			v.ajouter_objet(modele, (float(i) + (0.02 if i == r.position.x else 0.98)) * CASE,
				(float(j) + 0.5) * CASE, PI * 0.5, hauteur)
