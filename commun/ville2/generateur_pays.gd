extends RefCounted
## L'ARCHIPEL DES AURONES, REMPLI À LA DEMANDE — une fenêtre à la fois.
##
## ⚠ OÙ EN EST-ON. Le client a fourni quatre cartes dessinées et imposé un ordre
## de travail : côtes et relief, PUIS gares et stations, PUIS les six réseaux,
## PUIS SEULEMENT les quartiers. Les trois premières étapes vivent dans
## `plan_pays.gd` ; la quatrième n'a pas commencé, donc `plan["implantations"]`
## est VIDE et tout ce qui suit sur la greffe des témoins ne pose rien
## aujourd'hui. Ce n'est pas du code mort : c'est l'étape 4, prête, et le
## raisonnement qui la gouverne est déjà payé — il serait absurde de l'effacer
## pour le réapprendre dans quinze jours.
##
## Ce qu'une fenêtre rend AUJOURD'HUI : le terrain de l'archipel, la voirie des
## trois îles (anneaux, radiales, trames, chemins côtiers), les voies ferrées de
## surface, les gares, les stations de métro, de tram et de bus en `lieux`, les
## ponts, et le semis de campagne.
##
## ═══════════════════════════════════════════════════════════════════════════
## CE QUE FAIT CE FICHIER, EN UNE PHRASE
## ═══════════════════════════════════════════════════════════════════════════
##
## `fenetre(plan, ctx, Rect2i)` rend une `Ville2` complète — terrain, routes,
## quartiers bâtis, objets — POUR CE RECTANGLE DE CASES ET RIEN D'AUTRE. Le
## reste du pays n'est pas calculé, n'est pas en mémoire, n'a jamais existé.
##
## ⚠ LES COORDONNÉES DE LA `Ville2` RENDUE SONT LOCALES : la case (0, 0) de la
## fenêtre est le coin nord-ouest du rectangle demandé, pas celui du pays. Tout
## ce qui lit une `Ville2` (le rendu, l'éditeur, `PlanV2`, la photo) travaille
## depuis l'origine ; une fenêtre qui porterait ses coordonnées de monde
## obligerait à changer tout ça. C'est donc à l'appelant de décaler son nœud de
## `fenetre.position * Ville2.CASE`, et c'est une ligne.
##
## ═══════════════════════════════════════════════════════════════════════════
## ⚠⚠⚠ LA QUESTION DIFFICILE : UN QUARTIER À CHEVAL SUR DEUX FENÊTRES
## ═══════════════════════════════════════════════════════════════════════════
##
## C'est LA pièce qui rend le reste possible, et c'est là qu'on se casse la
## figure si on réfléchit de travers. Posons le problème proprement.
##
## Un quartier fait 40 × 40 cases. Une fenêtre en fait 200 × 200. Un quartier
## tombe donc, au mieux, entièrement dans une fenêtre ; au pire, il est coupé
## en quatre par un coin de fenêtre. Le joueur, lui, voit les deux fenêtres en
## même temps, côte à côte. Il FAUT que la moitié gauche du quartier calculée
## par la fenêtre A et sa moitié droite calculée par la fenêtre B soient deux
## moitiés du MÊME quartier — même plan de rues, mêmes maisons, mêmes arbres.
##
## LA MAUVAISE IDÉE, et c'est la première qui vient : générer « la portion de
## quartier qui tombe dans la fenêtre ». Elle ne peut pas marcher. Un
## générateur de quartier trace des rues d'un bord à l'autre, pose des pâtés
## entre ces rues, et remplit les pâtés en marchant le long des trottoirs. Rien
## de tout ça n'est local : la troisième maison d'une rue dépend de la largeur
## des deux premières. Un demi-quartier n'est pas la moitié d'un quartier.
##
## ⭐ LA BONNE RÈGLE, ET ELLE TIENT EN UNE LIGNE :
##
##     ON GÉNÈRE TOUJOURS LE QUARTIER ENTIER, PUIS ON DÉCOUPE.
##
## Le quartier est bâti sur sa propre petite carte de 40 × 40, à partir de SA
## graine — celle que `plan_pays.gd` a tirée une fois pour toutes et rangée
## dans le plan. Cette génération ne sait RIEN de la fenêtre : ni sa position,
## ni sa taille, ni même qu'il en existe une. Elle rend donc toujours,
## strictement, le même quartier. C'est seulement APRÈS, à la recopie, qu'on
## jette ce qui tombe hors de la fenêtre.
##
## Deux fenêtres voisines ne produisent pas deux résultats qu'il faudrait
## raccorder : elles produisent DEUX DÉCOUPES DU MÊME RÉSULTAT. Il n'y a pas de
## couture, parce qu'il n'y a jamais eu deux calculs.
##
## ⚠ TROIS PIÈGES DÉTRUISENT CETTE GARANTIE, ET ILS SONT TOUS LES TROIS ACTIFS
## DANS CE PROJET. Il faut les nommer, sinon quelqu'un les rétablira :
##
## 1. LES SACS DE `Lotisseur`. `Lotisseur._sacs` est une variable STATIQUE,
##    partagée par tous les générateurs : elle garde, d'un appel à l'autre, où
##    en est le tirage sans remise de chaque liste de modèles. Bâtir le village
##    A puis le village B ne donne donc PAS le même B que bâtir B tout seul —
##    et une fenêtre ne bâtit pas les mêmes quartiers qu'une autre. C'est
##    exactement le genre de faute qui ne se voit qu'en regardant deux captures
##    côte à côte. La parade est une ligne, et elle est obligatoire :
##    `Lotisseur.oublier_les_sacs()` AVANT CHAQUE implantation. Le sac repart
##    alors de la même graine, et le quartier est le même partout.
## 2. LE SEMIS DE CAMPAGNE. Un `RandomNumberGenerator` déroulé case après case
##    donne une suite qui dépend de la CASE DE DÉPART, donc de la fenêtre :
##    deux fenêtres qui se recouvrent y planteraient deux forêts différentes.
##    On tire donc par case, avec une graine qui est une FONCTION DE LA CASE
##    (voir `_alea_en`) : le même arbre au même endroit, quelle que soit la
##    fenêtre qui le demande, et même si on ne demande jamais sa voisine.
## 3. LA PASSE D'HERBE DE `proprete.gd`. `remplir_l_herbe` déroule un seul
##    `alea` sur toute la carte : même défaut que le point 2. On appelle donc
##    `rien_sur_les_routes` (qui, lui, est purement local) et on sème l'herbe
##    ici, par case.
##
## ═══════════════════════════════════════════════════════════════════════════
## UN SEUL CHEMIN POUR TOUT CE QUI SE POSE
## ═══════════════════════════════════════════════════════════════════════════
##
## Un quartier de témoin, une ferme, un aérodrome : ce sont trois choses très
## différentes, et elles passent toutes les trois par la même mécanique.
##
##   UNE IMPLANTATION SE BÂTIT SUR SA PROPRE PETITE `Ville2`, À SA PROPRE
##   TAILLE, DEPUIS SA PROPRE GRAINE — PUIS ELLE EST GREFFÉE ET DÉCOUPÉE.
##
## Il n'y a donc qu'UN endroit où une translation de ville est écrite
## (`_greffer`), et qu'UN endroit où un découpage l'est. Si la translation est
## fausse, elle est fausse pour tout le pays d'un coup — ce qui se voit du
## premier regard, au lieu de se cacher dans un cas sur trente.
##
## C'est la greffe de `generateur_carte.gd`, à laquelle on a ajouté le
## découpage. Le diagnostic qui l'a fait choisir tient toujours mot pour mot :
## les neuf témoins ont leur plan de masse en constantes ABSOLUES, une centaine
## réparties sur neuf fichiers, chacune placée à l'œil contre le regard du
## client. On ne les réécrit pas ; on les appelle.
##
## ═══════════════════════════════════════════════════════════════════════════
## CE QU'IL FAUDRA CHANGER DANS LES NEUF TÉMOINS, ET QUAND
## ═══════════════════════════════════════════════════════════════════════════
##
## Rien, aujourd'hui. Et c'est le but : le pays se bâtit sans toucher une ligne
## des neuf quartiers qui ont été réglés capture après capture.
##
## Ce qui le forcera, dans cet ordre :
##
## * LE JOUR OÙ UNE VILLE MOYENNE DEVRA FAIRE 60 × 40. Aujourd'hui toute
##   implantation de témoin fait 40 × 40, parce que c'est la seule taille que
##   les témoins savent remplir (ils prennent un paramètre `taille` mais ne
##   s'en servent pas : agrandir leur carte laisse leur plan de masse au même
##   endroit et ajoute du vide autour). On contourne en ACCOLANT plusieurs
##   témoins — la grande ville est un bloc de six. Ça se voit un peu : deux
##   centres accolés ont deux plans de rues qui ne se répondent pas. C'est le
##   premier défaut à regarder sur l'image.
## * LE JOUR OÙ IL FAUDRA QUATORZE VILLAGES DIFFÉRENTS. Aujourd'hui les
##   quatorze sortent de trois témoins avec quatorze graines : ça varie, mais
##   ça se reconnaît. Il faudra un vrai générateur de village (un noyau, une
##   église, une place), qui est un chantier du calibre d'un témoin.
## * JAMAIS POUR LE STREAMING. La greffe suffit, et elle coûte ce qu'elle
##   coûte : un témoin entier généré même si deux colonnes seulement sont
##   visibles. Le cache (voir `_batie`) le paie une fois par quartier et par
##   session, pas une fois par fenêtre.

const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const REMPLISSEUR := preload("res://commun/ville2/remplisseur.gd")

## ⚠ `preload` ET JAMAIS `class_name` : le cache de classes n'est pas réécrit
## par `godot --headless --import`, donc une classe neuve compile au bureau et
## tombe en ligne. Piège déjà payé deux fois sur ce projet.
const TEMOINS := {
	"centre": preload("res://commun/ville2/generateur_centre.gd"),
	"plage": preload("res://commun/ville2/generateur_plage.gd"),
	"colline": preload("res://commun/ville2/generateur_colline.gd"),
	"banlieue": preload("res://commun/ville2/generateur_banlieue.gd"),
	"industrie": preload("res://commun/ville2/generateur_industrie.gd"),
	"vieille": preload("res://commun/ville2/generateur_vieille_ville.gd"),
	"chaud": preload("res://commun/ville2/generateur_chaud.gd"),
	"campus": preload("res://commun/ville2/generateur_campus.gd"),
	"bidonville": preload("res://commun/ville2/generateur_bidonville.gd"),
}

const CASE := Ville2.CASE
const PALIER := Ville2.PALIER

## Le tablier d'un pont, au niveau de la chaussée qu'il prolonge : `TABLIER`
## vaut exactement l'opposé du niveau de la mer, écrit comme un calcul et non
## comme un nombre (le jour où `NIVEAU_MER` bouge, les ponts suivent).
const TABLIER := -TerrainV2.NIVEAU_MER
const LARGE_TABLIER := 18.0

## LE SEMIS DE CAMPAGNE. Les listes sont courtes exprès : le kit nature au
## complet est déjà tiré par `parc.gd` et par la passe d'herbe. Ce semis-ci
## n'est là que pour que la campagne ne soit pas un tapis vert entre deux
## villages.
const ARBRES_DE_PLAINE := ["nature/tree_default", "nature/tree_oak", "nature/tree_fat",
	"nature/tree_simple", "nature/tree_blocks", "nature/tree_plateau"]
const H_PLAINE := [9.0, 11.0, 8.5, 8.0, 9.0, 9.5]
const ARBRES_DE_CRETE := ["nature/tree_pineTallA", "nature/tree_pineTallC",
	"nature/tree_pineRoundC", "nature/tree_cone_dark"]
const H_CRETE := [16.0, 17.0, 10.0, 10.0]
const ROCHES := ["nature/rock_largeA", "nature/rock_largeD", "nature/rock_tallA",
	"nature/stone_largeC", "nature/cliff_rock"]
const H_ROCHES := [3.2, 2.8, 4.2, 2.6, 0.0]
const PALMIERS := ["nature/tree_palm", "nature/tree_palmTall", "nature/tree_palmBend"]
const H_PALMIERS := [8.0, 11.0, 9.0]
const TOUFFES := ["nature/grass", "nature/grass_large", "nature/grass_leafs",
	"nature/plant_flatShort", "nature/plant_flatTall", "nature/plant_bushSmall"]
const H_TOUFFES := [0.45, 0.70, 0.50, 0.40, 0.60, 0.55]

## Les maisons de la campagne. Le kit pavillons est le seul dont les volumes
## (un corps simple sous un toit à deux pentes) se lisent comme de la
## campagne — c'est déjà le choix fait pour le village de la carte du 14/09.
const MAISONS_DE_FERME := ["pavillons/building-type-a", "pavillons/building-type-c",
	"pavillons/building-type-e", "pavillons/building-type-j",
	"pavillons/building-type-o", "pavillons/building-type-l"]

# ══════════════════════════════════════════════════════════════════ LA FENÊTRE

## ⭐ LE REMPLISSAGE D'UNE FENÊTRE. L'ordre est celui du cahier (§ 10), et il
## n'est pas négociable : terrain → côtes → axes → quartiers → rues → lots →
## détails. Un axe posé sur une côte qu'on n'a pas encore dessinée se retrouve
## dans l'eau ; un arbre semé avant les maisons se retrouve dans une cuisine.
static func fenetre(plan: Dictionary, ctx: Dictionary, f: Rect2i, curseurs := {}) -> Ville2:
	var v := Ville2.new(f.size)
	v.nom = String(curseurs.get("nom", "pays-%d-%d" % [f.position.x, f.position.y]))
	v.graine = int(plan.get("graine", 1))

	# 1. LE TERRAIN. Une seule fonction, la même que celle qui dessine l'image
	#    du pays : il ne peut pas y avoir de désaccord entre ce qu'on regarde
	#    et ce qu'on traverse.
	PLAN.remplir_terrain(plan, ctx, v, f.position)

	# 2. LES QUARTIERS (les zones, avant les rues — ordre du cahier : c'est ce
	#    qui permet aux axes de savoir ce qu'ils longent).
	var dedans := _implantations_visibles(plan, f)
	for k in dedans:
		var d: Dictionary = (plan["implantations"] as Array)[k]
		v.quartiers.append({"nom": String(d["nom"]), "genre": String(d["g"]), "gang": -1})
		var z := PLAN.rect_de(d)
		v.peindre_quartier(Rect2i(z.position - f.position, z.size), v.quartiers.size() - 1)

	# 3. LES AXES, découpés à la fenêtre.
	_les_routes(plan, ctx, v, f)
	_les_voies(plan, v, f)
	v.rasteriser()

	# 4. ⭐ LES QUARTIERS BÂTIS, D'APRÈS LEUR CHARTE ET PLUS PAR GREFFE. Le
	#    remplisseur lit `quartier_en` sous chaque case et `regles_quartier`
	#    pour savoir quoi y poser. Aucun témoin n'est appelé : ils ne sont plus
	#    des tampons, ils sont la source des chartes.
	if bool(curseurs.get("temoins", true)):
		REMPLISSEUR.remplir(plan, ctx, v, f.position)
		# Les grandes pièces posées à l'unité (ferme, aérodrome) passent encore
		# par la greffe — elles n'ont pas de charte, elles ont un plan.
		for k2 in dedans:
			_implanter(plan, v, f, k2)
		# ⚠ APRÈS LES QUARTIERS, PARCE QUE C'EST EUX QUI POSAIENT LE BITUME SOUS
		# LES RAILS. Voir `_pas_de_rue_sous_le_rail`.
		_pas_de_rue_sous_le_rail(v)
		v.rasteriser()

	# 5. LES OUVRAGES, puis L'AUTOROUTE AÉRIENNE.
	_les_ponts(plan, v, f)
	# ⚠ APRÈS LES LOTS, ET C'EST TOUT L'INTÉRÊT : une pile ne doit jamais se
	# poser sur un bâtiment, donc il faut que les bâtiments existent déjà.
	_les_autoroutes(plan, ctx, v, f)

	# 6. LES DÉTAILS, tirés par case et non en suite.
	_semer(plan, ctx, v, f, float(curseurs.get("densite", 1.0)),
		int(curseurs.get("herbe", 1)))
	v.rasteriser()
	# La règle commune, en dernier : rien ne reste sur la chaussée sauf le
	# mobilier de voirie, et rien du tout dans une zone interdite.
	PROPRETE.rien_sur_les_routes(v)
	return v

## ⭐⭐⭐ LA GRILLE D'UN QUARTIER NE POSE PAS DE RUE SOUS LES RAILS.
##
## ⚠ CE N'EST PAS LE MÊME DÉFAUT QUE `_ecarter_du_rail`, ET C'EST POURQUOI IL Y
## A DEUX REMÈDES. Là-bas, c'est le graphe routier du PLAN qui longe une ligne
## de train parce que les deux relient les mêmes gares : une route structurante,
## qu'on ne peut pas couper sans couper le pays en deux — on l'écarte d'une case.
## Ici, c'est la GRILLE d'un quartier, posée par le remplisseur bien après, qui
## ne sait rien de la voie et trace ses rues par-dessus. Mesuré sur la fenêtre
## (400,400,200,200) : 393 cases posées sur la voie par des rues et des avenues
## SANS NOM — la grille — contre une cinquantaine pour les axes nommés.
##
## Une rue de grille, elle, se COUPE : elle a dix sœurs parallèles à vingt
## mètres, ses rues transversales continuent de traverser la voie (passage à
## niveau ou pont, selon la classe), et les deux pâtés qu'elle séparait n'en
## font plus qu'un, de part et d'autre du remblai. C'est exactement ce qu'on voit
## le long d'une vraie voie ferrée en ville.
##
## ⚠ ON NE COUPE QUE CE QUI VA DANS LE MÊME SENS. Une rue qui coupe la voie à
## angle droit reste où elle est : c'est un croisement, pas un empiètement.
##
## ⚠ ET LE TEST EST PUREMENT LOCAL — « cette case porte-t-elle une voie qui va
## dans le même sens que moi » — donc indépendant du cadre de la fenêtre : deux
## fenêtres qui se recouvrent coupent aux mêmes endroits.
static func _pas_de_rue_sous_le_rail(v: Ville2) -> int:
	var axes: Dictionary = {}
	for r in v.rail:
		var cases: Array = Ville2.cases_de_route(r)
		for i in cases.size():
			var c: Vector2i = cases[i]
			var d: Vector2i = (cases[mini(i + 1, cases.size() - 1)] as Vector2i) \
				- (cases[maxi(i - 1, 0)] as Vector2i)
			if d == Vector2i.ZERO: continue
			axes[c] = d.x != 0
	if axes.is_empty(): return 0
	var gardees: Array = []
	var coupees := 0
	for r2 in v.routes:
		var d2: Dictionary = r2
		var cases2: Array = Ville2.cases_de_route(d2)
		var morceau: Array = []
		for i2 in cases2.size():
			var c2: Vector2i = cases2[i2]
			var dir: Vector2i = (cases2[mini(i2 + 1, cases2.size() - 1)] as Vector2i) \
				- (cases2[maxi(i2 - 1, 0)] as Vector2i)
			var conflit: bool = axes.has(c2) and bool(axes[c2]) == (dir.x != 0)
			if conflit:
				coupees += 1
				if morceau.size() >= 2: gardees.append(_route_de(d2, morceau))
				morceau = []
				continue
			morceau.append(c2)
		if morceau.size() >= 2: gardees.append(_route_de(d2, morceau))
		elif morceau.size() == 1 and cases2.size() == 1: gardees.append(_route_de(d2, morceau))
	v.routes = gardees
	return coupees

## La même route, réduite à ce tronçon-là : même genre, même nom, même niveau.
static func _route_de(modele: Dictionary, cases: Array) -> Dictionary:
	var pts: Array = []
	for i in cases.size():
		var c: Vector2i = cases[i]
		if i == 0 or i == cases.size() - 1:
			pts.append(c)
			continue
		if ((c - (cases[i - 1] as Vector2i)) != ((cases[i + 1] as Vector2i) - c)):
			pts.append(c)
	return {"genre": String(modele.get("genre", "rue")), "nom": String(modele.get("nom", "")),
		"points": pts, "niveau": int(modele.get("niveau", 0))}

## Les implantations qui touchent la fenêtre. La marge d'une case évite le cas
## limite d'un quartier qui affleure le bord sans le franchir.
static func _implantations_visibles(plan: Dictionary, f: Rect2i) -> Array:
	var vus: Array = []
	var impl: Array = plan["implantations"]
	for k in impl.size():
		var z := PLAN.rect_de(impl[k])
		if z.grow(1).intersects(f): vus.append(k)
	return vus

# ══════════════════════════════════════════════════════════════════ LES AXES

## LE DÉCOUPAGE D'UNE POLYLIGNE. Chaque segment est droit et dans un seul axe
## (`ajouter_route` refuse la diagonale) : le découper, c'est donc rogner son
## intervalle sur un axe et vérifier sa coordonnée fixe sur l'autre.
##
## ⚠ ON ROGNE JUSQU'AU BORD, PAS JUSQU'À L'AVANT-DERNIÈRE CASE. Une route qui
## s'arrêterait une case avant la limite laisserait un trou d'une case entre
## deux fenêtres voisines — un nid-de-poule long de vingt mètres, tous les
## quatre kilomètres, et personne ne saurait d'où il vient.
## ⭐⭐⭐ UNE RUE NE SE COUCHE JAMAIS SOUS LES RAILS — ELLE SE RANGE À CÔTÉ.
##
## « Une voie ferrée doit couper une route en passant par-dessus, mais jamais
## être étalée dessus » (client). Dans la ville, la voie a son couloir à elle ;
## dans le PAYS, non : le graphe routier et les lignes de train relient les
## mêmes gares, aux mêmes endroits, et se retrouvent donc dans le même couloir.
## Mesuré sur la fenêtre (400,400,200,200) AVANT correction : **314 des 575
## cases de rail étaient aussi des cases de rue, dont une suite ININTERROMPUE
## DE 37 CASES** — 740 mètres de voie posée au milieu d'un boulevard.
##
## ⚠ ON ÉCARTE LA ROUTE, PAS LA VOIE. Déplacer la voie la décaserait d'une
## fenêtre à l'autre (chaque fenêtre déciderait dans son coin) et casserait les
## ponts et les gares, qui la visent par ses coordonnées du plan. La rue, elle,
## se pousse d'une case et revient : le train longe le boulevard au lieu de
## rouler dessus, ce qui est exactement ce qu'on voit dans une vraie ville.
##
## ⚠ ET LE CALCUL NE REGARDE QUE LE PLAN, JAMAIS LA FENÊTRE. C'est la règle de
## l'archipel : le résultat ne doit pas dépendre du cadre. On écarte donc en
## coordonnées ABSOLUES, puis on découpe — jamais l'inverse, sinon deux fenêtres
## voisines choisiraient deux côtés différents et la rue ferait une marche sur
## la couture.
##
## ⚠ UN CROISEMENT N'EST PAS UN CONFLIT. Une rue qui coupe la voie à angle
## droit reste où elle est : c'est le passage à niveau (ou le pont, selon la
## classe de la rue — voir `RenduVille2._profil_du_rail`). Seules les cases où
## la rue et la voie vont DANS LE MÊME SENS sont écartées.
static func _les_routes(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i) -> void:
	var axes := _axes_du_rail(plan)
	for r in plan["routes"]:
		var d: Dictionary = r
		# ⚠⚠ LE PRIMAIRE NE TOUCHE PLUS LE SOL. « Toutes les autoroutes doivent
		# se trouver sur des voies aériennes posées sur des pylônes » (client,
		# 15/09) : le réseau primaire est l'autoroute, il passe en viaduc, et
		# poser en plus sa chaussée au sol ferait deux routes superposées — la
		# ville se retrouverait coupée en deux par une bande de bitume sous son
		# propre viaduc. Voir `_les_autoroutes`.
		if String(d.get("classe", "")) == PLAN.V_PRIMAIRE: continue
		for trace in _ecarter_du_rail(plan, ctx, d["points"], axes):
			for seg in _decouper(trace, f):
				var s: Array = seg
				v.ajouter_route(String(d["genre"]), s, String(d.get("nom", "")), 0)

## Les cases de voie ferrée du plan, avec l'AXE de la voie en chaque case :
## `true` = elle va d'est en ouest. C'est l'axe qui dit si une rue la longe ou
## la coupe.
static func _axes_du_rail(plan: Dictionary) -> Dictionary:
	var axes: Dictionary = {}
	for l in plan["lignes"]:
		var d: Dictionary = l
		if bool(d.get("souterrain", false)): continue
		if not EN_SURFACE.has(String(d["reseau"])): continue
		var pts: Array = d["points"]
		for k in range(1, pts.size()):
			var a := PLAN.case_de(pts[k - 1])
			var b := PLAN.case_de(pts[k])
			if a.y == b.y:
				for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					axes[Vector2i(x, a.y)] = true
			elif a.x == b.x:
				for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
					axes[Vector2i(a.x, y)] = false
	return axes

## ⭐ LE DÉTOUR. Rend la (ou les) polyligne(s) absolue(s) à poser à la place de
## celle du plan : identique partout où la rue ne longe pas la voie, écartée
## d'une case là où elle la longe, avec ses deux coudes.
static func _ecarter_du_rail(plan: Dictionary, ctx: Dictionary, points: Array,
		axes: Dictionary) -> Array:
	var cases := _cases_du_trace(points)
	if cases.size() < 2: return [points]
	# 1. OÙ ÇA COINCE : même case, même axe.
	var conflit: Array = []
	var quelconque := false
	for i in cases.size():
		var c: Vector2i = cases[i]
		var d: Vector2i = (cases[mini(i + 1, cases.size() - 1)] - cases[maxi(i - 1, 0)])
		var selon_x: bool = d.x != 0
		var pris: bool = axes.has(c) and bool(axes[c]) == selon_x
		conflit.append(pris)
		quelconque = quelconque or pris
	if not quelconque: return [points]
	# 2. LE DÉTOUR, tronçon par tronçon.
	var sortie: Array = []
	var i2 := 0
	while i2 < cases.size():
		if not conflit[i2]:
			sortie.append(cases[i2])
			i2 += 1
			continue
		# ⚠ UN TRONÇON S'ARRÊTE AU COUDE. Pousser d'un seul côté une rue qui
		# tourne au milieu du tronçon donnerait une diagonale, qu'`ajouter_route`
		# refuse — à juste titre. Un coude coupe donc le tronçon en deux.
		var dir: Vector2i = (cases[i2 + 1] as Vector2i) - (cases[i2] as Vector2i) \
			if i2 + 1 < cases.size() else (cases[i2] as Vector2i) - (cases[i2 - 1] as Vector2i)
		var j := i2
		while j < cases.size() and conflit[j]:
			if j + 1 < cases.size() and (cases[j + 1] as Vector2i) - (cases[j] as Vector2i) != dir:
				j += 1
				break
			j += 1
		var perp := Vector2i(1, 0) if dir.x == 0 else Vector2i(0, 1)
		perp = _meilleur_cote(plan, ctx, cases, axes, i2, j, perp)
		if perp == Vector2i.ZERO:
			# Les deux côtés sont impossibles (mer, ou voie des deux bords) :
			# on laisse la rue où elle est plutôt que de la jeter à l'eau.
			for k in range(i2, j): sortie.append(cases[k])
			i2 = j
			continue
		if i2 > 0: sortie.append(cases[i2 - 1] + perp)
		for k in range(i2, j): sortie.append(cases[k] + perp)
		if j < cases.size(): sortie.append(cases[j] + perp)
		i2 = j
	return [_sommets(sortie)]

## Le côté vers lequel pousser : celui qui est à terre et sans voie ferrée sur
## toute la longueur du tronçon. ⚠ On essaie TOUJOURS le même en premier, pour
## que deux fenêtres voisines tombent sur la même réponse.
static func _meilleur_cote(plan: Dictionary, ctx: Dictionary, cases: Array,
		axes: Dictionary, i: int, j: int, perp: Vector2i) -> Vector2i:
	for cote in [perp, -perp]:
		var bon := true
		for k in range(maxi(i - 1, 0), mini(j + 1, cases.size())):
			var c: Vector2i = (cases[k] as Vector2i) + cote
			if axes.has(c) or not PLAN.terre_en(plan, ctx, c):
				bon = false
				break
		if bon: return cote
	return Vector2i.ZERO

## Toutes les cases d'une polyligne du plan, dans l'ordre, sans doublon de coude.
static func _cases_du_trace(points: Array) -> Array:
	var cases: Array = []
	for k in range(1, points.size()):
		var a := PLAN.case_de(points[k - 1])
		var b := PLAN.case_de(points[k])
		if a.x != b.x and a.y != b.y: return []
		var pas := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		if cases.is_empty(): cases.append(c)
		while c != b:
			c += pas
			cases.append(c)
	return cases

## L'inverse : on ne garde que les coudes, `ajouter_route` n'attend que ça.
static func _sommets(cases: Array) -> Array:
	var pts: Array = []
	for i in cases.size():
		var c: Vector2i = cases[i]
		if i == 0 or i == cases.size() - 1:
			pts.append(c)
			continue
		var avant: Vector2i = cases[i - 1]
		var apres: Vector2i = cases[i + 1]
		if (c - avant) != (apres - c): pts.append(c)
	# ⚠ EN TABLEAUX, PAS EN `Vector2i` : `PLAN.case_de` lit `[x, y]`, comme
	# partout ailleurs dans le plan.
	var bruts: Array = []
	for p0 in pts:
		var p: Vector2i = p0
		bruts.append([p.x, p.y])
	return bruts

## ⚠⚠ DES SIX RÉSEAUX DU PLAN, DEUX SEULEMENT DESCENDENT EN 3D AUJOURD'HUI :
## LA VOIRIE ET LE TRAIN. Ce n'est pas un oubli, c'est une décision, et elle est
## écrite en long dans `plan_pays.gd` :
##
## * le MÉTRO est SOUTERRAIN, y compris sous la mer. `Ville2` n'a pas de niveau
##   négatif utilisable : posé dans `rail`, il apparaîtrait cinq mètres sous le
##   sol, donc flottant dans une tranchée invisible, et au milieu de la mer sur
##   les tronçons sous-marins. Un défaut visible, pour rien ;
## * le TRAM et le BUS n'ont pas de pièce dans le kit — ni rail de tramway, ni
##   abribus. Une ligne de tram posée comme du rail de train serait un train.
##
## Les trois descendent donc par leurs STATIONS seulement, en `lieux` : le jeu
## sait déjà ce qu'est un lieu, la mini-carte les affichera, et le jour où les
## pièces existeront il n'y aura qu'à lire `plan["lignes"]` ici même.
## On ne dessine pas ce qu'on ne sait pas dessiner.
const EN_SURFACE := ["train", "train2"]

static func _les_voies(plan: Dictionary, v: Ville2, f: Rect2i) -> void:
	for l in plan["lignes"]:
		var d: Dictionary = l
		if bool(d.get("souterrain", false)): continue
		if not EN_SURFACE.has(String(d["reseau"])): continue
		for seg in _decouper(d["points"], f):
			v.rail.append({"points": seg, "niveau": 0})
	# LES STATIONS. Une gare de train devient une `gare` (le jeu en fait un
	# point de voyage) ; tout le reste devient un `lieu` de son réseau. Hors
	# fenêtre, une station n'existe pas.
	for g in plan["stations"]:
		var d2: Dictionary = g
		var c := PLAN.case_de(d2["c"])
		if not f.has_point(c): continue
		var l2 := c - f.position
		var x := (float(l2.x) + 0.5) * CASE
		var z := (float(l2.y) + 0.5) * CASE
		var reseau := String(d2["reseau"])
		var nom := String(d2["nom"])
		if reseau in EN_SURFACE:
			v.gares.append({"nom": nom, "x": x, "z": z,
				"principale": bool(d2.get("principale", false))})
		else:
			v.ajouter_lieu(reseau, x, z, {"nom": nom, "ligne": String(d2.get("ligne", ""))})

static func _decouper(points: Array, f: Rect2i) -> Array:
	var sorties: Array = []
	# Le dernier indice valide : `Rect2i.end` est exclusif, une case de route
	# posée dessus tomberait hors de la `Ville2` de la fenêtre.
	var x0 := f.position.x
	var x1 := f.end.x - 1
	var y0 := f.position.y
	var y1 := f.end.y - 1
	for k in range(1, points.size()):
		var a := PLAN.case_de(points[k - 1])
		var b := PLAN.case_de(points[k])
		if a.y == b.y:
			if a.y < y0 or a.y > y1: continue
			var i0 := maxi(mini(a.x, b.x), x0)
			var i1 := mini(maxi(a.x, b.x), x1)
			if i0 > i1: continue
			sorties.append([Vector2i(i0, a.y) - f.position, Vector2i(i1, a.y) - f.position])
		elif a.x == b.x:
			if a.x < x0 or a.x > x1: continue
			var j0 := maxi(mini(a.y, b.y), y0)
			var j1 := mini(maxi(a.y, b.y), y1)
			if j0 > j1: continue
			sorties.append([Vector2i(a.x, j0) - f.position, Vector2i(a.x, j1) - f.position])
		# Un segment en diagonale n'existe pas dans le plan : `_escalier` n'en
		# produit pas. S'il en apparaît un, il est SILENCIEUSEMENT ignoré ici et
		# refusé par `ajouter_route` plus loin — deux filets pour la même faute.
	return sorties

## LES PONTS. Un tablier par case de travée, posé comme un OBJET avec ses piles
## qui descendent au fond, plus ses lampadaires une travée sur deux.
##
## ⚠ ON NE ROULE PAS DESSUS, et il faut le redire ici : `rasteriser()` ne pose
## une chaussée que sur une case de terre. La polyligne de route est bien là
## (le GPS et la mini-carte en ont besoin), la chaussée ne l'est pas. Corriger
## demande `rasteriser`, `Ville2.plate` et `TerrainV2.hauteur_coin` ENSEMBLE —
## sans quoi le fond de la mer se soulève jusqu'au tablier sur toute la
## longueur du pont. C'est un chantier à part, à faire avec les voies rapides
## surélevées qui posent exactement le même problème.
static func _les_ponts(plan: Dictionary, v: Ville2, f: Rect2i) -> void:
	for p in plan["ponts"]:
		var d: Dictionary = p
		# ⚠ UN TUNNEL N'EST PAS UN PONT. Le fichier du client en déclare un — le
		# ferroviaire Centrale ↔ Sud-Est — et il passe SOUS la mer. Lui poser un
		# tablier ferait une passerelle en travers du bras de mer, à l'endroit
		# exact où le client a demandé qu'il n'y en ait pas.
		if bool(d.get("tunnel", false)): continue
		var a := PLAN.case_de(d["de"])
		var b := PLAN.case_de(d["vers"])
		if a.x != b.x and a.y != b.y: continue
		var selon_x := a.y == b.y
		var pas := (b - a).sign()
		var c := a
		var k := 0
		for _m in (b - a).abs().x + (b - a).abs().y + 1:
			if c == b: break
			c += pas
			k += 1
			if c == b: break
			if not f.has_point(c): continue
			var l := c - f.position
			var x := (float(l.x) + 0.5) * CASE
			var z := (float(l.y) + 0.5) * CASE
			# ⚠ `zone: true` — le tablier est posé EXPRÈS dans une zone
			# interdite. Sans ce drapeau, la passe de propreté retire le pont
			# qu'on vient de poser.
			# ⚠ `dalle: false` — la chaussée de la travée est déjà posée case
			# par case au palier 0. La dalle de la plateforme faisait un SECOND
			# tablier juste dessous ; on ne garde que les pilotis.
			v.objets.append({"m": "plateforme", "x": x, "z": z,
				"r": 0.0 if selon_x else PI * 0.5, "h": 0.0, "dalle": false,
				"w": LARGE_TABLIER, "d": CASE, "y": TABLIER, "zone": true})
			# ⚠ ET PAS DE LAMPADAIRE TOUS LES DEUX PAS SUR UN PONT SUR L'EAU.
			# Un tous les deux, c'est un tous les quarante mètres : sur une
			# travée de deux kilomètres ça fait cinquante mâts, et de loin le
			# pont disparaît sous ses poteaux. Un sur huit suffit, comme sur un
			# vrai ouvrage.
			if k % 8 != 0: continue
			for s in [-1.0, 1.0]:
				var sf: float = s
				var ex: float = 0.0 if selon_x else sf * (LARGE_TABLIER * 0.5 - 1.4)
				var ez: float = sf * (LARGE_TABLIER * 0.5 - 1.4) if selon_x else 0.0
				v.objets.append({"m": "lampadaire", "x": x + ex, "z": z + ez,
					"r": 0.0, "h": 0.0,
					"y_abs": TerrainV2.NIVEAU_MER + TABLIER + 0.35, "zone": true})
		# LA ZONE INTERDITE DE LA TRAVÉE, découpée à la fenêtre : rien ne traîne
		# sur un pont, et rien ne pousse dessous à hauteur de tablier.
		var monde := Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)),
			Vector2i(absi(b.x - a.x) + 1, absi(b.y - a.y) + 1))
		if not monde.intersects(f): continue
		var loc := Rect2i(monde.position - f.position, monde.size)
		v.interdire(Rect2(Vector2(loc.position) * CASE, Vector2(loc.size) * CASE))
		v.ajouter_lieu("pont", (float(loc.position.x) + float(loc.size.x) * 0.5) * CASE,
			(float(loc.position.y) + float(loc.size.y) * 0.5) * CASE,
			{"nom": String(d.get("nom", ""))})

# ══════════════════════════════════════════════════════════════════ IMPLANTER

## LE CACHE DES IMPLANTATIONS BÂTIES. Un témoin coûte de l'ordre de la seconde ;
## un quartier à cheval sur quatre fenêtres serait bâti quatre fois, et rebâti
## à chaque fois que le joueur repasse. On le garde, par graine.
##
## ⚠ CE CACHE N'EST PAS UNE OPTIMISATION FACULTATIVE DU RÉSULTAT : il ne change
## RIEN à ce qui sort (c'est tout l'intérêt de la garantie de l'en-tête), il ne
## change que le temps. On peut le vider quand on veut.
static var _cache: Dictionary = {}

static func oublier() -> void:
	_cache.clear()

static func _batie(d: Dictionary) -> Ville2:
	var cle := "%s|%d" % [String(d["t"]), int(d["graine"])]
	if _cache.has(cle):
		var deja: Ville2 = _cache[cle]
		return deja
	# ⚠⚠ LA LIGNE QUI TIENT TOUTE LA GARANTIE DE RACCORD. `Lotisseur._sacs` est
	# statique et garde l'état des tirages sans remise d'un appel à l'autre :
	# sans cette remise à zéro, le quartier dépend de CE QUI A ÉTÉ BÂTI AVANT
	# LUI, donc de la fenêtre. Voir le piège n° 1 de l'en-tête.
	Lotisseur.oublier_les_sacs()
	var v: Ville2 = null
	var type := String(d["t"])
	var graine := int(d["graine"])
	if TEMOINS.has(type):
		# ⚠ UNE VARIABLE SANS TYPE, EXPRÈS. Typée `GDScript`, l'appel
		# `script.generer(…)` serait résolu à la compilation contre la classe
		# `GDScript`, qui n'a pas de `generer` : ça ne compile pas.
		var script = TEMOINS[type]
		v = script.generer(graine, Vector2i(PLAN.COTE_TEMOIN, PLAN.COTE_TEMOIN),
			{"nom": String(d["nom"])})
	elif type == "ferme":
		v = _la_ferme(graine)
	elif type == "aerodrome":
		v = _l_aerodrome(graine)
	else:
		v = Ville2.new(PLAN.rect_de(d).size)
	_cache[cle] = v
	return v

static func _implanter(plan: Dictionary, v: Ville2, f: Rect2i, k: int) -> void:
	var d: Dictionary = (plan["implantations"] as Array)[k]
	var petite := _batie(d)
	if petite == null: return
	var z := PLAN.rect_de(d)
	_greffer(v, petite, z.position - f.position, float(int(d["p"])) * PALIER)

## ⭐ LA GREFFE DÉCOUPÉE. Recopie une petite ville dans la fenêtre, décalée de
## `origine` (en cases, et souvent NÉGATIVE : un quartier qui déborde au nord a
## son coin hors de la fenêtre), remontée de `base` (en unités), en jetant tout
## ce qui tombe dehors.
##
## ⚠ LA LISTE CI-DESSOUS EST LA LISTE COMPLÈTE DE CE QU'UNE `Ville2` CONTIENT.
## Un champ oublié, c'est un quartier entier resté à l'origine de la fenêtre, et
## personne ne le verra sur une capture de vingt kilomètres. Si `ville2.gd`
## gagne un champ, il en gagne un ici le même jour.
static func _greffer(v: Ville2, petite: Ville2, origine: Vector2i, base: float) -> void:
	var dx := float(origine.x) * CASE
	var dz := float(origine.y) * CASE
	# 1. LES QUARTIERS. `quartier_de` ne garde qu'un indice : il se décale du
	#    nombre de quartiers déjà déclarés dans la fenêtre.
	var decalage := v.quartiers.size()
	for q in petite.quartiers:
		v.quartiers.append((q as Dictionary).duplicate(true))
	# 2. LE SOL. L'altitude du témoin s'AJOUTE à celle du plateau ; la mer, non
	#    — une mer perchée n'existe pas, et la plage doit rejoindre la vraie.
	for j in petite.taille.y:
		for i in petite.taille.x:
			var src := Vector2i(i, j)
			var c := origine + src
			if not v.dedans(c): continue
			var ks := petite.indice(src)
			var kd := v.indice(c)
			if petite.terre(src):
				v.poser_terre(c, petite.altitude[ks] + base)
			else:
				# ⚠ ON GARDE LE PLUS PROFOND DES DEUX FONDS, ET C'EST TOUT CE
				# QUI TIENT LA COUTURE DE LA PLAGE. Le témoin compte sa
				# profondeur depuis SA ligne d'eau ; le pays compte depuis la
				# côte et descend plus vite. Recopié tel quel, l'estran du
				# témoin REMONTERAIT le fond au bord de son carré — un haut-fond
				# rectangulaire de huit cents mètres, avec sa bande de sable
				# clair le long de la couture. Le fond ne remonte jamais.
				var creux := petite.altitude[ks]
				if not v.terre(c): creux = minf(creux, v.altitude[kd])
				v.poser_eau(c)
				v.altitude[kd] = creux
			v.matiere[kd] = petite.matiere[ks]
			# ⚠ ON N'EFFACE PAS UN QUARTIER PAR UN TROU. Une petite ville qui
			# ne déclare aucun quartier sur une case (une ferme, l'aérodrome,
			# et jusqu'aux cours intérieures de certains témoins) écrirait −1
			# par-dessus le quartier que la fenêtre vient de peindre : la
			# ferme perdrait son nom, et le semis de campagne viendrait planter
			# des arbres dans sa cour.
			var q2 := petite.quartier_de[ks]
			if q2 >= 0: v.quartier_de[kd] = q2 + decalage
	# 3. LES ROUTES ET LE RAIL, découpés comme ceux du plan.
	for r in petite.routes:
		var fr: Dictionary = r
		for seg in _decaler_et_couper(fr["points"], origine, v.taille):
			v.ajouter_route(String(fr["genre"]), seg, String(fr.get("nom", "")),
				int(fr.get("niveau", 0)))
	for r2 in petite.rail:
		var fr2: Dictionary = r2
		for seg2 in _decaler_et_couper(fr2["points"], origine, v.taille):
			v.rail.append({"points": seg2, "niveau": int(fr2.get("niveau", 0))})
	# 4. LES OUVRAGES (courbes larges, ronds-points), en cases.
	for o in petite.ouvrages:
		var fo: Dictionary = (o as Dictionary).duplicate()
		fo["i"] = int(fo["i"]) + origine.x
		fo["j"] = int(fo["j"]) + origine.y
		if not v.dedans(Vector2i(int(fo["i"]), int(fo["j"]))): continue
		v.ouvrages.append(fo)
	# 5. LES LOTS, en DEMI-cases : le décalage vaut donc double.
	#    ⚠⚠ LA RÈGLE DE DÉCOUPE D'UN BÂTIMENT, ET ELLE EST ARBITRAIRE — donc
	#    elle doit être ÉCRITE : UN LOT APPARTIENT À LA FENÊTRE QUI CONTIENT SA
	#    DEMI-CASE NORD-OUEST. Un bâtiment à cheval déborde donc de sa fenêtre
	#    au lieu d'être coupé en deux, et il n'est JAMAIS posé deux fois. Couper
	#    un bâtiment était l'autre option : elle donne deux moitiés de maison
	#    avec un mur manquant au milieu, ce qui est bien pire qu'un pignon qui
	#    dépasse chez le voisin — les fenêtres sont des nœuds voisins dans la
	#    scène, pas des boîtes qui rognent.
	for l in petite.lots:
		var fl: Dictionary = l
		var hx := int(fl["x"]) + origine.x * 2
		var hy := int(fl["y"]) + origine.y * 2
		if not v.dedans(Vector2i(floori(float(hx) * 0.5), floori(float(hy) * 0.5))): continue
		v.ajouter_lot(String(fl["m"]), hx, hy, int(fl["w"]), int(fl["h"]), int(fl["q"]),
			String(fl.get("genre", "")), String(fl.get("c", "")))
	# 6. LES OBJETS, en MÈTRES, à la case où ils se trouvent. On recopie la
	#    fiche ENTIÈRE : elle porte des clefs que seuls certains générateurs
	#    emploient (`w`, `d`, `dy`, `sol`, `zone`, `voirie`, `aplat`…).
	#    ⚠ `y_abs` EST UNE ALTITUDE ABSOLUE — la pile de carcasses de la casse,
	#    le bar sur le tablier de la jetée. Elle monte avec le plateau.
	var lx := float(v.taille.x) * CASE
	var lz := float(v.taille.y) * CASE
	for o2 in petite.objets:
		var fo2: Dictionary = (o2 as Dictionary).duplicate(true)
		var x := float(fo2["x"]) + dx
		var z := float(fo2["z"]) + dz
		if x < 0.0 or z < 0.0 or x >= lx or z >= lz: continue
		fo2["x"] = x
		fo2["z"] = z
		if fo2.has("y_abs"): fo2["y_abs"] = float(fo2["y_abs"]) + base
		v.objets.append(fo2)
	# 7. LES LIEUX DE JEU ET LES GARES.
	for li in petite.lieux:
		var fli: Dictionary = (li as Dictionary).duplicate(true)
		var x2 := float(fli["x"]) + dx
		var z2 := float(fli["z"]) + dz
		if x2 < 0.0 or z2 < 0.0 or x2 >= lx or z2 >= lz: continue
		fli["x"] = x2
		fli["z"] = z2
		v.lieux.append(fli)
	for ga in petite.gares:
		var fga: Dictionary = (ga as Dictionary).duplicate(true)
		var x3 := float(fga["x"]) + dx
		var z3 := float(fga["z"]) + dz
		if x3 < 0.0 or z3 < 0.0 or x3 >= lx or z3 >= lz: continue
		fga["x"] = x3
		fga["z"] = z3
		v.gares.append(fga)
	# 8. LES ZONES INTERDITES, en mètres : c'est ce qui garde propres une piste
	#    d'atterrissage et une voie ferrée. Une zone oubliée, et les panneaux
	#    publicitaires reviennent au milieu de la piste (client, 14/09).
	for zi in petite.interdits:
		var r3: Rect2 = zi
		v.interdire(Rect2(r3.position + Vector2(dx, dz), r3.size))
	# 9. LE REGISTRE DES DEMI-CASES. Un témoin en réserve sans y poser de lot —
	#    l'emprise de sa voie ferrée, le fond de son lac. Ces réservations-là
	#    n'ont pas d'autre trace : sans cette boucle, la fenêtre y bâtit.
	for cle in petite.demi_prises.keys():
		var h: Vector2i = cle
		v.demi_prises[Vector2i(h.x + origine.x * 2, h.y + origine.y * 2)] = true

static func _decaler_et_couper(points: Array, origine: Vector2i, taille: Vector2i) -> Array:
	var monde: Array = []
	for p in points:
		var c := Vector2i(p) + origine
		monde.append([c.x, c.y])
	return _decouper(monde, Rect2i(Vector2i.ZERO, taille))

# ══════════════════════════════════════════════════════════════════ LA CAMPAGNE

## ⭐ LE TIRAGE PAR CASE. Une graine qui est une FONCTION de la case, et non une
## suite qu'on déroule : c'est ce qui fait que l'arbre de la case (412, 883) est
## le même arbre, au même endroit, qu'on demande la fenêtre qui commence à 400
## ou celle qui commence à 350, et même si on ne demande jamais sa voisine.
##
## ⚠ NE PAS REMPLACER PAR UN `alea` DÉROULÉ « pour aller plus vite ». C'est
## exactement la faute que le semis de `generateur_carte.gd` ne pouvait pas
## commettre (il bâtissait tout d'un bloc) et que celui-ci commettrait au
## premier raccourci.
static func _alea_en(graine: int, i: int, j: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(graine, i, j))
	return r

## LA CAMPAGNE ET SON HERBE. Trois règles et pas une de plus : des pins sur les
## hauteurs, des feuillus en plaine, des palmiers sur le sable. Et de l'herbe
## sur toute case d'herbe libre — « une pelouse vide n'est pas une pelouse,
## c'est un tapis vert » (client, 12/09).
##
## ⚠ UN BRIN PAR CASE, ET PAS TROIS. Trois par case est le réglage d'un témoin
## de 1 600 cases ; sur les 40 000 d'une fenêtre c'est cent vingt mille touffes,
## plus que tout le reste réuni. Un brin suffit à tuer le vert plat dès qu'il y
## a des arbres par-dessus, et c'est le seul poste où l'on retire des dizaines
## de milliers d'objets sans rien changer au dessin.
static func _semer(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		densite: float, herbe: int) -> void:
	var g := int(plan.get("graine", 1))
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c) or v.plate(c): continue
			# ⚠⚠ ON NE SÈME PAS DANS UN QUARTIER BÂTI — MAIS ON SÈME DANS SES
			# JARDINS. Un arbre au milieu d'une rue du centre est ce que le
			# client a refusé trois fois ; un pavillonnaire sans un arbre, et un
			# parc pelé, c'est le défaut inverse et il est tout aussi visible.
			# La différence tient en un mot : la MATIÈRE que la charte a posée.
			# Dalle et terre battue = quartier bâti, on ne sème pas. Herbe et
			# sable = jardin, parc, grève — on sème.
			var q := v.quartier_en(c)
			if q >= 0:
				var mq := v.matiere_de(c)
				if mq != Ville2.M_HERBE and mq != Ville2.M_SABLE: continue
			if not v.demi_libre(i * 2, j * 2, 2, 2): continue
			var alea := _alea_en(g, f.position.x + i, f.position.y + j)
			var x := (float(i) + alea.randf()) * CASE
			var z := (float(j) + alea.randf()) * CASE
			var m := v.matiere_de(c)
			if m == Ville2.M_SABLE:
				if alea.randf() < 0.10 * densite:
					var n := alea.randi() % PALMIERS.size()
					v.ajouter_objet(PALMIERS[n], x, z, alea.randf() * TAU,
						float(H_PALMIERS[n]))
			elif m == Ville2.M_ROCHE:
				if alea.randf() < 0.18 * densite:
					var n2 := alea.randi() % ROCHES.size()
					v.ajouter_objet(ROCHES[n2], x, z, alea.randf() * TAU, float(H_ROCHES[n2]))
			elif m == Ville2.M_HERBE:
				if alea.randf() < 0.22 * densite:
					# La ligne de crête aux conifères, les basses terres aux
					# feuillus : c'est la règle déjà retenue pour le relief, et
					# elle suffit à faire lire une altitude sans la mesurer.
					var haut := v.sol(c) >= 12.0 * PALIER
					var liste: Array = ARBRES_DE_CRETE if haut else ARBRES_DE_PLAINE
					var hauteurs: Array = H_CRETE if haut else H_PLAINE
					var n3 := alea.randi() % liste.size()
					v.ajouter_objet(String(liste[n3]), x, z, alea.randf() * TAU,
						float(hauteurs[n3]))
				for _k in herbe:
					var n4 := alea.randi() % TOUFFES.size()
					v.ajouter_objet(TOUFFES[n4], (float(i) + alea.randf()) * CASE,
						(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
						float(H_TOUFFES[n4]) * alea.randf_range(0.8, 1.25))

# ══════════════════════════════════════════════════════════════════ LES PETITES

## LA FERME. Quatre bâtiments autour d'une cour, un champ labouré, une haie
## d'arbres au vent. Ce n'est PAS un témoin et ça n'a pas à l'être : une ferme
## qu'on croise à soixante à l'heure a besoin d'être RECONNAISSABLE d'en haut,
## pas d'être visitable. Le cahier le dit autrement : « montrer tôt et souvent,
## même moche ».
##
## Elle est bâtie sur sa propre petite `Ville2`, comme un témoin, et elle passe
## par la même greffe découpée : un seul chemin pour tout ce qui se pose.
static func _la_ferme(graine: int) -> Ville2:
	var t := PLAN.FERME
	var v := Ville2.new(t)
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()
	for j in t.y:
		for i in t.x:
			v.poser_terre(Vector2i(i, j), 0.0)
			# Le champ : de la terre labourée sur la moitié est, de l'herbe
			# autour de la cour. Vu d'en haut, c'est le champ qui dit « ferme ».
			v.poser_matiere(Vector2i(i, j),
				Ville2.M_TERRE if i >= t.x / 2 + 1 else Ville2.M_HERBE)
	# Le chemin d'accès, qui part vers l'ouest : sans lui la ferme est posée au
	# milieu d'un pré, et « une maison sans accès » est un des interdits du
	# cahier.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(0, t.y / 2), Vector2i(t.x / 2, t.y / 2)],
		"Chemin de la ferme")
	v.rasteriser()
	# Les bâtiments autour de la cour, sur le côté herbe.
	var cotes := [Vector2i(1, 1), Vector2i(1, t.y - 4), Vector2i(t.x / 2 - 3, 1),
		Vector2i(t.x / 2 - 3, t.y - 4)]
	for k in cotes.size():
		var hc: Vector2i = cotes[k]
		var m := String(MAISONS_DE_FERME[alea.randi() % MAISONS_DE_FERME.size()])
		var q := alea.randi() % 4
		var e := KitVille2.emprise_tournee(m, q)
		var hx := hc.x * 2
		var hy := hc.y * 2
		if Lotisseur.terrain_libre(v, hx, hy, e):
			v.ajouter_lot(m, hx, hy, e.x, e.y, q, Ville2.Q_PAVILLONS)
	# La haie brise-vent, au nord du champ.
	for i2 in range(t.x / 2 + 1, t.x, 2):
		v.ajouter_objet("nature/tree_tall", (float(i2) + 0.5) * CASE, 0.6 * CASE,
			alea.randf() * TAU, 13.0)
	v.ajouter_lieu("ferme", float(t.x) * CASE * 0.5, float(t.y) * CASE * 0.5)
	return v

## L'AÉRODROME. Une piste, sa manche à air, sa tour, ses hangars. La piste est
## une ZONE INTERDITE au sens strict — c'est elle qui a donné la règle, le
## 14/09 : « assure-toi qu'il n'y ait rien sur la piste d'atterrissage, les
## rails etc, je vois des panneaux publicitaires ».
static func _l_aerodrome(graine: int) -> Ville2:
	var t := PLAN.AERODROME
	var v := Ville2.new(t)
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	for j in t.y:
		for i in t.x:
			v.poser_terre(Vector2i(i, j), 0.0)
			v.poser_matiere(Vector2i(i, j), Ville2.M_HERBE)
	# LA PISTE : quatre cases de large, sur toute la longueur, en dalle. La
	# dalle est plate par définition (`Ville2.plate`), donc rien ne pousse
	# dessus et le terrain ne s'y soulève pas.
	var i0 := t.x / 2 - 2
	for j2 in range(2, t.y - 2):
		for i3 in range(i0, i0 + 4):
			v.poser_matiere(Vector2i(i3, j2), Ville2.M_DALLE)
	v.interdire(Rect2(Vector2(float(i0) * CASE, 2.0 * CASE),
		Vector2(4.0 * CASE, float(t.y - 4) * CASE)))
	# Les feux de balisage, posés PAR l'aérodrome : ils portent le drapeau
	# `zone`, donc ils survivent à la passe de propreté qui vide la piste.
	for j3 in range(3, t.y - 3, 4):
		for s in [-1, 1]:
			v.objets.append({"m": "borne",
				"x": (float(t.x / 2) + float(s) * 2.6) * CASE,
				"z": (float(j3) + 0.5) * CASE, "r": 0.0, "h": 1.2, "zone": true})
	# ⚠ PAS DE MANCHE À AIR : le kit n'en a pas, et un modèle de remplacement
	# qui ne ressemble pas à ce qu'il remplace est pire que rien (un palmier
	# planté au bout d'une piste se lit comme une faute, pas comme un
	# repère). Deux hangars et le balisage suffisent à ce qu'on reconnaisse un
	# aérodrome d'en haut ; la tour et la manche sont une pièce à modeler.
	v.ajouter_objet("lampadaire", 1.5 * CASE, 2.5 * CASE, 0.0, 0.0)
	v.rasteriser()
	for k in 2:
		var m: String = "industriel/building-h" if k == 0 else "industriel/building-i"
		var e := KitVille2.emprise_tournee(m, 0)
		var hx := 2
		var hy := (6 + k * 6) * 2
		if Lotisseur.terrain_libre(v, hx, hy, e):
			v.ajouter_lot(m, hx, hy, e.x, e.y, 0, Ville2.Q_INDUSTRIE)
	v.ajouter_lieu("aerodrome", float(t.x) * CASE * 0.5, float(t.y) * CASE * 0.5)
	return v

# ------------------------------------------------------------------
# CE QUI RESTE À FAIRE, dans l'ordre où je le ferais
# ------------------------------------------------------------------
#
# 1. LE STREAMING POUR DE VRAI. `MorceauxV2` bâtit par carrés de 16 × 16 cases
#    AUTOUR DU JOUEUR, mais il lui faut une `Ville2` ENTIÈRE en mémoire
#    (`ville.carte` couvre toute la carte, pour qu'une rue sache qu'elle
#    continue chez le voisin). Sur mille cases de côté, cette `Ville2` unique
#    est exactement ce qu'on vient d'éliminer. Il faut donc un étage au-dessus :
#    un nœud par FENÊTRE (200 × 200, soit 4 × 4 km, ce que `MorceauxV2` sait
#    déjà tenir), chaque fenêtre avec son `MorceauxV2` et sa `Ville2`, et une
#    grille de trois fenêtres sur trois autour du joueur. C'est un fichier neuf
#    (`fenetres_pays.gd`), pas une modification de `morceaux_v2.gd` — et c'est
#    le prochain chantier.
# 2. LE COÛT D'UNE FENÊTRE, MESURÉ. Je l'ai estimé, pas mesuré : il faut le
#    chronomètre de `outils/pays.gd` sur plusieurs fenêtres, dont une sur la
#    grande ville (six témoins) et une en pleine mer (rien du tout).
# 3. LES RUES QUI SE RÉPONDENT D'UN QUARTIER À L'AUTRE. Deux témoins accolés
#    ont deux plans de rue qui ne se raccordent pas. La carte du 14/09 mettait
#    un ANNEAU DE DESSERTE autour de chaque plateau pour ramasser les rues
#    sortantes ; il faut le refaire ici, et vérifier à la capture qu'une rue de
#    témoin tombe bien EN FACE de l'anneau.
# 4. LE CONTRÔLE DU PAYS. `outils/verifier_temoins.gd` compte les objets sur la
#    chaussée, les lots qui se chevauchent et les modèles absents. Il faut la
#    même table par fenêtre, plus la colonne que seul un pays réclame : deux
#    fenêtres voisines rendent-elles EXACTEMENT la même chose sur leur bande
#    commune ? Ça se teste sans les yeux, en comparant deux découpes décalées.


# ══════════════════════════════════════════════════ L'AUTOROUTE AÉRIENNE

## ⭐⭐ LE VIADUC — « elle peut traverser les villes mais les pylônes ne doivent
## jamais être reposés sur un bâtiment » (client, 15/09).
##
## Trois règles, et chacune vient d'un défaut qu'on aurait eu sans elle :
##
## 1. LE TABLIER SUIT LE RELIEF, IL N'EST PAS DE NIVEAU. Une autoroute posée à
##    une altitude constante au-dessus de la mer plonge dans la première colline
##    — et nos monts font soixante-dix mètres. Le tablier se cale donc sur le
##    sol de chaque case, PLUS un dégagement fixe.
## 2. MAIS IL EST LISSÉ. Case par case, le sol bouge d'un palier d'un coup : le
##    tablier ferait un escalier. On prend la MOYENNE GLISSANTE du sol sur une
##    douzaine de cases, et le viaduc monte comme une route monte.
## 3. LE LISSAGE SE CALCULE SUR TOUTE LA ROUTE, PAS SUR LA PART VISIBLE. Une
##    moyenne prise sur la tranche de la fenêtre donnerait deux altitudes
##    différentes de part et d'autre d'une couture — un décroché d'un mètre en
##    plein milieu du tablier, tous les deux kilomètres.
const HAUT_VIADUC := 11.0            ## dégagement sous tablier, en unités
const ECART_PILES := 4               ## une pile toutes les 4 cases (80 m)
const CHERCHE_PILE := 3              ## de combien de cases on décale une pile gênée
const LISSAGE := 6                   ## demi-fenêtre de la moyenne glissante

## ⭐⭐ LE KIT DE L'AUTOROUTE — liste donnée par le client le 16/09, après
## « vraiment ton autoroute rime à rien ». Il avait raison : le viaduc était une
## dalle grise avec une tuile de rue posée dessus, alors que le kit Kenney
## contient une VOIE RAPIDE COMPLÈTE, virages, ponts, bretelles et panneaux.
##
## Ce que chaque pièce sait faire, mesuré sur son maillage (`AABB`) et non
## deviné, parce que deux d'entre elles ne font PAS une case :
##
##   road-straight            1 × 1, plate            la chaussée courante
##   road-bend                1 × 1, virage sec       un quart de tour
##   road-curve               2 × 2  ← DEUX CASES     inutilisable case par case
##   road-curve-intersection  2 × 2  ← DEUX CASES     idem
##   road-bridge              1 × 1, 0,52 de haut     une travée avec sa structure
##   road-side-exit / entry   1 × 1,31 ← DÉBORDE      la bretelle, sortie et entrée
##   road-split               1 × 2  ← DEUX CASES     la séparation des voies
##   bridge-pillar            0,10 × 0,50            le poteau, mis à la hauteur
##   bridge-pillar-wide       0,14 × 0,50            le poteau des grandes portées
##   sign-highway(-wide)      0,13 × 0,71 × 1        le panneau de bord de voie
##
## ⚠ ET CE QUE JE N'UTILISE PAS, AVEC LA RAISON. Les `road-slant-*` montent de
## 0,27 unité de kit sur une case, c'est-à-dire CINQ MÈTRES SUR VINGT : 27 % de
## pente. Une bretelle de parking, pas une autoroute — et surtout un escalier,
## puisque le tablier, lui, monte de quelques centimètres par case. La montée et
## la descente se font donc en INCLINANT la chaussée droite sur la pente réelle
## du tablier (`pente`, voir `RenduVille2._assiette`), ce qui donne une voie
## continue au lieu d'une suite de marches. Les pièces à deux cases sont
## écartées pour la même raison de justesse : elles se chevaucheraient d'une
## case sur deux.
const AUTO_DROIT := "routes/road-straight"
const AUTO_VIRAGE := "routes/road-bend"
const AUTO_PONT := "routes/road-bridge"
const AUTO_SORTIE := "routes/road-side-exit"
const AUTO_ENTREE := "routes/road-side-entry"
const AUTO_PILE := "routes/bridge-pillar"
const AUTO_PILE_LARGE := "routes/bridge-pillar-wide"
const PANNEAUX := ["routes/sign-highway", "routes/sign-highway-detailed",
	"routes/sign-highway-wide"]
const ECART_PANNEAUX := 23           ## un panneau toutes les 23 cases (460 m)
const PORTEE_LARGE := 6              ## au-delà, la pile large
const MINCE_PILE := 0.5              ## ce qu'on reprend en largeur à une pile haute

## ⭐⭐⭐ L'AUTOROUTE VOLANTE EST FAITE DE `road-bridge`, ET DE RIEN D'AUTRE.
##
## Capture du client, 17/09 : une pièce `road-bridge` seule, au-dessus d'une rue
## — un tablier, ses deux bordures, ses quatre jambes. « Voici comment faire une
## autoroute volante ». Tout est déjà dans la pièce ; il n'y avait rien à
## fabriquer autour.
##
## ⚠⚠ CE QU'ON EMPILAIT AVANT, ET POURQUOI C'ÉTAIT TROIS FOIS TROP. Sur CHAQUE
## case on posait : (1) un ruban de tablier gris dessiné à la main, (2) une tuile
## de chaussée par-dessus à `+0,45`, (3) une pile du kit étirée en dessous. Trois
## objets superposés pour ce qu'une seule pièce du kit fait mieux — « tu empiles
## des choses les unes sur les autres, je ne comprends pas pourquoi », et « tu
## mets des dalles blanches … alors que tu n'en as pas besoin » (client, 17/09).
## La dalle blanche, c'était le ruban.
##
## ⚠ LA PIÈCE S'ÉTIRE, ELLE NE FLOTTE PAS. `road-bridge` mesure 0,52 unité de
## kit, soit 10,4 unités de monde : c'est la hauteur du tablier au-dessus de ses
## pieds. Le tablier de l'autoroute, lui, est à la hauteur que le profil lui
## donne, qui varie. On ÉTIRE donc la pièce EN HAUTEUR SEULEMENT (`aplat`, qui
## ne touche ni à la largeur du tablier ni à l'emprise) pour que ses pieds
## tombent exactement sur le terrain : jamais de jambe en l'air, jamais de pile
## en plus, un objet par case.
## ⚠⚠⚠ ET ON NE L'ÉTIRE PAS, ET ON NE LUI MET RIEN DESSOUS.
##
## Le client a monté l'échangeur à la main dans l'éditeur, et l'a dit en une
## phrase : « j'ai réussi à tout faire sans dalle ni rien en support, juste du
## Kenney ». C'est la règle, et elle est plus simple que tout ce que j'avais
## écrit : le tablier de l'autoroute est à LA HAUTEUR DE LA PIÈCE, pas à une
## hauteur qu'on choisit. Chaque `road-bridge` repose sur le terrain, porte sa
## chaussée à 10,4 unités (de quoi passer au-dessus d'un train, mesuré :
## `CAISSE_TRAIN` + `HAUT_RAIL_MAX` = 9) et n'a besoin de RIEN d'autre.
##
## Ce qui disparaît avec ça : l'étirement (une pièce déformée), les piles
## ajoutées dessous (un objet de plus), et toute possibilité qu'un morceau
## flotte — puisque la pièce pose ses pieds elle-même, sur le sol, à chaque case.
const PONT_HAUT := 10.4              ## `road-bridge` : 0,52 unité de kit, mesuré

static func _les_autoroutes(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i) -> void:
	for r in plan["routes"]:
		var d: Dictionary = r
		if String(d.get("classe", "")) != PLAN.V_PRIMAIRE: continue
		var cases := _cases_suivies(d["points"])
		if cases.size() < 2: continue
		var haut := _profil_du_tablier(plan, ctx, cases)
		var precedente := -99
		# ⭐⭐ UNE PIÈCE DU KIT PAR CASE, ET C'EST TOUT (voir `PONT_HAUT`).
		# Il y a eu ici, tour à tour, une file de cubes (« des trucs qui passent
		# à travers chaque cube », 16/09), puis un ruban de tablier dessiné à la
		# main avec une chaussée posée dessus et une pile en dessous (« tu
		# empiles des choses les unes sur les autres », 17/09). Les deux fois,
		# la faute était la même : fabriquer ce que le kit contient déjà.
		for i in cases.size():
			var c: Vector2i = cases[i]
			if not f.has_point(c): continue
			var l := c - f.position
			var x := (float(l.x) + 0.5) * CASE
			var z := (float(l.y) + 0.5) * CASE
			# Le cap : d'où l'on vient, où l'on va.
			var avant: Vector2i = cases[i - 1] if i > 0 else c
			var apres: Vector2i = cases[i + 1] if i + 1 < cases.size() else c
			var entre := c - avant
			var sort := apres - c
			if entre == Vector2i.ZERO: entre = sort
			if sort == Vector2i.ZERO: sort = entre
			var tourne := _cap(entre)
			# ⭐ LA PIÈCE JUSTE POUR CETTE CASE-LÀ, ET ELLE EST SEULE.
			var franchit := _coupee_dessous(v, l, entre)
			# ⚠ LE PIED SE PREND SUR LE PROFIL LISSÉ, PAS SUR LE SOL BRUT.
			# Posée sur le terrain tel quel, la file de tables suivrait chaque
			# palier : des montagnes russes. `_profil_du_tablier` a déjà lissé le
			# sol ; on lui reprend son dégagement pour retrouver ce sol-là.
			var assise := haut[i] - HAUT_VIADUC
			# ⭐ UNE PIÈCE, POSÉE SUR LE TERRAIN, ET RIEN D'AUTRE.
			# Le cap d'un virage se lit sur le COUPLE (entrée, sortie), pas sur
			# l'une des deux ; `road-bridge` étant droit, un coude se prend en
			# gardant le cap de la case, comme un vrai ouvrage à travées.
			v.objets.append({"m": AUTO_PONT, "x": x, "z": z,
				"r": tourne, "h": 0.0, "y_abs": assise, "zone": true})
			# ⭐ LES BRETELLES. Une sortie se pose là où une rue de la ville
			# croise le tracé : c'est le seul endroit où une voiture qui quitte
			# l'autoroute a quelque chose à rejoindre. Entrée puis sortie, de
			# part et d'autre du croisement, comme sur un vrai échangeur.
			if franchit and i - precedente > 8:
				precedente = i
				for paire in [[AUTO_SORTIE, -2], [AUTO_ENTREE, 2]]:
					var j: int = i + int(paire[1])
					if j < 0 or j >= cases.size(): continue
					var cj: Vector2i = cases[j]
					if not f.has_point(cj): continue
					if (cases[j] as Vector2i) - (cases[j - 1] as Vector2i) != entre: continue
					var lj := cj - f.position
					v.objets.append({"m": String(paire[0]),
						"x": (float(lj.x) + 0.5) * CASE, "z": (float(lj.y) + 0.5) * CASE,
						"r": tourne, "h": 0.0,
						"y_abs": haut[j] - HAUT_VIADUC + PONT_HAUT, "zone": true})
			# ⭐ LES PANNEAUX, au bord de la voie et tournés vers le conducteur.
			# Ils se posent sur la POSITION ABSOLUE et non sur l'indice : une
			# fenêtre décalée doit retrouver les mêmes panneaux aux mêmes cases.
			if posmod(c.x * 7 + c.y * 13, ECART_PANNEAUX) == 0 and entre == sort:
				# ⚠ LA DEMI-LARGEUR EST CELLE DE LA CASE, plus celle du ruban
				# d'autrefois : le tablier, c'est la pièce du kit, une case.
				var cote := Vector2(sin(tourne), cos(tourne)).orthogonal() * (CASE * 0.5 - 1.0)
				v.objets.append({"m": String(PANNEAUX[posmod(c.x + c.y, PANNEAUX.size())]),
					"x": x + cote.x, "z": z + cote.y,
					"r": tourne, "h": 0.0,
					"y_abs": assise + PONT_HAUT, "zone": true})

## ⭐⭐ UNE ROUTE QUI PASSE DESSOUS N'EST PAS UNE ROUTE QUI COUPE.
##
## `road-bridge` se posait dès qu'il y avait de la chaussée sous le tablier. Or
## l'autoroute longe des avenues sur des kilomètres : chaque case était « au-
## dessus d'une route », donc chaque case devenait une travée de pont, et le
## viaduc entier se couvrait de parapets — « si une route en dessous passe en la
## coupant, pas partout » (client, 16/09).
##
## La travée de pont marque un FRANCHISSEMENT, et un franchissement se
## reconnaît à ce que la voie du dessous est PERPENDICULAIRE à celle du dessus :
## elle entre d'un côté du tablier et ressort de l'autre. Une rue parallèle, si
## près soit-elle, ne se franchit pas — on roule au-dessus d'elle, c'est tout.
##
## Une avenue large qui croise donne plusieurs travées d'affilée, et c'est juste :
## le pont fait la largeur de ce qu'il enjambe.
static func _coupee_dessous(v: Ville2, l: Vector2i, entre: Vector2i) -> bool:
	if not v.carte.route(l): return false
	# Le travers de l'autoroute : là où la rue du dessous doit se poursuivre.
	var travers := Vector2i(entre.y, entre.x)
	if travers == Vector2i.ZERO: return false
	var a: Vector2i = l + travers
	var b: Vector2i = l - travers
	if not v.dedans(a) or not v.dedans(b): return false
	return v.carte.route(a) and v.carte.route(b)

## Le cap d'un pas d'une case : vers l'est, le sud, l'ouest ou le nord.
static func _cap(pas: Vector2i) -> float:
	if pas.x > 0: return 0.0
	if pas.x < 0: return PI
	if pas.y > 0: return -PI * 0.5
	return PI * 0.5

## ⚠ LE CAP D'UN VIRAGE NE SE LIT PAS SUR SON ENTRÉE. `road-bend` est dessiné
## dans UNE orientation : la table dit, pour chaque couple (on arrivait comme
## ça, on repart comme ça), le quart de tour qui met la pièce au bon sens. Les
## quatre entrées manquantes sont les mêmes lues à l'envers.
const VIRAGES := {
	"1,0|0,1": 0, "0,-1|-1,0": 0,
	"0,1|-1,0": 1, "1,0|0,-1": 1,
	"-1,0|0,-1": 2, "0,1|1,0": 2,
	"0,-1|1,0": 3, "-1,0|0,1": 3}

static func _cap_du_virage(entre: Vector2i, sort: Vector2i) -> float:
	var cle := "%d,%d|%d,%d" % [entre.x, entre.y, sort.x, sort.y]
	return PI * 0.5 * float(int(VIRAGES.get(cle, 0)))

## Les cases d'une polyligne, dans l'ordre et sans trou.
static func _cases_suivies(points: Array) -> Array:
	var sortie: Array = []
	for k in range(1, points.size()):
		var a := PLAN.case_de(points[k - 1])
		var b := PLAN.case_de(points[k])
		# ⚠⚠ UN SEGMENT EN DIAGONALE NE SE SAUTE PAS, IL SE MONTE EN L.
		# Ce `continue` abandonnait le segment ENTIER : le tablier s'arrêtait net
		# en plein ciel et repartait plus loin — un bout de viaduc de trois cases
		# posé sur quatre piles au milieu de la ville (client, capture du 16/09).
		# On passe par le coude : d'abord en X, puis en Y.
		var c := a
		if sortie.is_empty(): sortie.append(c)
		var coude := Vector2i(b.x, a.y)
		for cible0 in [coude, b]:
			var cible: Vector2i = cible0
			var pas := (cible - c).sign()
			while c != cible:
				c += pas
				sortie.append(c)
	return sortie

## L'altitude du tablier, case par case : le sol lissé plus le dégagement.
## ⭐⭐ LE GABARIT DU TRAIN, ET IL NE SE DEVINE PAS.
##
## « Le train passe souvent sous des ponts et n'a logiquement pas la place de
## passer » (client, 16/09). Le tablier se calait sur le SOL plus un dégagement
## fixe — ce qui suffit au-dessus d'une rue, jamais au-dessus d'une voie ferrée,
## puisque celle-ci se soulève elle-même pour franchir les routes (voir
## `RenduVille2._profil_du_rail`) et peut déjà être à neuf unités en l'air.
##
## Là où une voie passe dessous, le tablier se cale donc sur le gabarit du
## TRAIN : la hauteur maximale que la voie peut atteindre, plus la caisse d'un
## convoi. Ailleurs il reste au ras du sol, sans quoi toute l'autoroute
## monterait d'un étage pour trois passages à niveau.
const HAUT_RAIL_MAX := 9.0           ## ce que la voie peut se soulever
const CAISSE_TRAIN := 9.0            ## la hauteur d'un convoi, toit compris

static func _cases_de_rail(plan: Dictionary) -> Dictionary:
	var sortie := {}
	for l in plan.get("lignes", []):
		var d: Dictionary = l
		if String(d.get("reseau", "")) not in ["train", "train2"]: continue
		if bool(d.get("souterrain", false)): continue
		for c in _cases_suivies(d["points"]):
			# Une case de part et d'autre : la voie est large, et lissée.
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					sortie[(c as Vector2i) + Vector2i(di, dj)] = true
	return sortie

static func _profil_du_tablier(plan: Dictionary, ctx: Dictionary, cases: Array) -> PackedFloat32Array:
	var rails := _cases_de_rail(plan)
	var brut := PackedFloat32Array()
	brut.resize(cases.size())
	for i in cases.size():
		var sol := PLAN.sol_en(plan, ctx, cases[i])
		# Au-dessus de l'eau on part du niveau de la mer, pas du fond : sinon le
		# viaduc s'enfonce de onze mètres à chaque bras de mer franchi.
		brut[i] = maxf(float(sol[0]), TerrainV2.NIVEAU_MER)
		if rails.has(cases[i]):
			brut[i] += HAUT_RAIL_MAX + CAISSE_TRAIN
	var lisse := PackedFloat32Array()
	lisse.resize(cases.size())
	for i in cases.size():
		var somme := 0.0
		var n := 0
		for t in range(maxi(0, i - LISSAGE), mini(cases.size(), i + LISSAGE + 1)):
			somme += brut[t]
			n += 1
		lisse[i] = somme / float(n) + HAUT_VIADUC
	return lisse

## ⭐ OÙ POSER LES PILES. On en veut une toutes les `ECART_PILES` cases ; si
## l'emplacement prévu tombe sur un bâtiment, on cherche la case libre la plus
## proche LE LONG DU TRACÉ. La portée du tablier varie donc un peu — c'est ce
## que font les vrais viaducs urbains, et c'est la seule solution qui ne laisse
## ni pile sur un toit ni trou dans le tissu.
##
## ⚠ UNE CASE HORS FENÊTRE N'A PAS DE LOT CONNU, donc elle a l'air libre. On ne
## décide donc une pile QUE pour les cases dont le voisinage de recherche est
## entièrement dans la fenêtre ; les autres seront décidées par la fenêtre
## voisine, qui les voit en entier.
static func _ou_poser_les_piles(v: Ville2, f: Rect2i, cases: Array) -> Dictionary:
	var sortie := {}
	var i := 0
	while i < cases.size():
		var choisi := -1
		for t in range(0, CHERCHE_PILE + 1):
			for s in ([0] if t == 0 else [t, -t]):
				var j: int = i + int(s)
				if j < 0 or j >= cases.size(): continue
				var c: Vector2i = cases[j]
				if not f.has_point(c): continue
				if v.lot_sur(c - f.position) >= 0: continue
				choisi = j
				break
			if choisi >= 0: break
		if choisi >= 0: sortie[choisi] = true
		i += ECART_PILES
	return sortie
