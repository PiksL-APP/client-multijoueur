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
	_les_routes(plan, v, f)
	_les_voies(plan, v, f)
	v.rasteriser()

	# 4. LES QUARTIERS BÂTIS. Chaque implantation est bâtie ENTIÈRE puis
	#    découpée — c'est la garantie de raccord, voir l'en-tête.
	if bool(curseurs.get("temoins", true)):
		for k2 in dedans:
			_implanter(plan, v, f, k2)
		v.rasteriser()

	# 5. LES OUVRAGES.
	_les_ponts(plan, v, f)

	# 6. LES DÉTAILS, tirés par case et non en suite.
	_semer(plan, ctx, v, f, float(curseurs.get("densite", 1.0)),
		int(curseurs.get("herbe", 1)))
	v.rasteriser()
	# La règle commune, en dernier : rien ne reste sur la chaussée sauf le
	# mobilier de voirie, et rien du tout dans une zone interdite.
	PROPRETE.rien_sur_les_routes(v)
	return v

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
static func _les_routes(plan: Dictionary, v: Ville2, f: Rect2i) -> void:
	for r in plan["routes"]:
		var d: Dictionary = r
		for seg in _decouper(d["points"], f):
			var s: Array = seg
			v.ajouter_route(String(d["genre"]), s, String(d.get("nom", "")), 0)

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
			v.objets.append({"m": "plateforme", "x": x, "z": z,
				"r": 0.0 if selon_x else PI * 0.5, "h": 0.0,
				"w": LARGE_TABLIER, "d": CASE, "y": TABLIER, "zone": true})
			if k % 2 != 0: continue
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
			# ⚠ ON NE SÈME PAS SUR UN QUARTIER. Un témoin greffé a déjà rempli
			# son carré, et un arbre de plus au milieu d'une rue du centre est
			# exactement ce que le client a refusé trois fois. Le registre des
			# demi-cases et `plate()` s'en chargent ; ce test-ci est la
			# dernière ligne de défense, et il ne coûte rien.
			if v.quartier_en(c) >= 0: continue
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
