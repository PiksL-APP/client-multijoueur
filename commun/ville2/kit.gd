class_name KitVille2
extends RefCounted
## LE KIT, MESURÉ. Les emprises des bâtiments Kenney (largeur, hauteur,
## profondeur en unités Kenney = en CASES, puisqu'une tuile du kit fait une
## case), relevées dans les GLB (`scratchpad/mesure_glb.py`, 12/09). C'est ce
## qui permet au lot de s'adapter au modèle : on ne pose jamais un bâtiment
## sur un lot plus petit que lui, et on ne l'étire jamais.
##
## Les props (lampadaires, feux, arbres, bancs) viennent d'autres kits, à
## d'autres échelles : ils sont donnés avec la HAUTEUR voulue en unités 3D,
## celle qui va avec les voitures et les piétons du jeu (proportions validées
## par le client, cahier § 2).

const RACINE := "res://modeles/kenney/"
const CASE := 20.0

## [largeur X, hauteur Y, profondeur Z] en cases.
const BATIMENTS := {
	"batiments/building-a": [0.884, 1.293, 0.940],
	"batiments/building-b": [0.970, 1.293, 0.940],
	"batiments/building-c": [0.884, 0.893, 1.090],
	"batiments/building-d": [0.840, 1.293, 0.900],
	"batiments/building-e": [1.640, 0.893, 1.008],
	"batiments/building-f": [0.840, 1.693, 1.030],
	"batiments/building-g": [0.970, 1.693, 0.922],
	"batiments/building-h": [0.884, 1.293, 1.008],
	"batiments/building-i": [1.240, 1.680, 1.302],
	"batiments/building-j": [2.084, 1.693, 1.340],
	"batiments/building-k": [2.084, 1.470, 0.942],
	"batiments/building-l": [1.370, 2.270, 1.402],
	"batiments/building-m": [1.240, 3.150, 1.242],
	"batiments/building-n": [2.320, 2.480, 1.820],
	"batiments/building-skyscraper-a": [1.360, 2.880, 1.360],
	"batiments/building-skyscraper-b": [1.360, 4.480, 1.360],
	"batiments/building-skyscraper-c": [1.280, 4.080, 1.388],
	"batiments/building-skyscraper-d": [1.280, 5.470, 1.388],
	"batiments/building-skyscraper-e": [1.295, 4.080, 1.242],
	"industriel/building-a": [2.084, 1.470, 1.242],
	"industriel/building-b": [2.084, 1.470, 1.262],
	"industriel/building-c": [1.876, 1.250, 2.108],
	"industriel/building-d": [0.884, 1.415, 1.420],
	"industriel/building-e": [1.684, 1.650, 1.290],
	"industriel/building-f": [1.790, 1.925, 1.280],
	"industriel/building-g": [1.678, 1.280, 1.284],
	"industriel/building-h": [1.322, 0.734, 1.310],
	"industriel/building-i": [1.028, 0.734, 1.300],
	"industriel/building-j": [1.027, 0.861, 1.300],
	"industriel/building-k": [1.303, 0.773, 0.914],
	"industriel/building-l": [2.084, 1.925, 1.870],
	"industriel/building-m": [1.316, 1.519, 1.700],
	"industriel/building-n": [0.977, 1.905, 1.420],
	"industriel/building-o": [0.884, 0.918, 1.240],
	"industriel/building-p": [1.684, 0.715, 0.992],
	"industriel/building-q": [2.140, 0.880, 1.770],
	"industriel/building-r": [2.484, 1.393, 1.272],
	"industriel/building-s": [2.120, 0.837, 0.916],
	"industriel/building-t": [1.722, 1.015, 1.390],
	"pavillons/building-type-a": [1.300, 0.834, 1.028],
	"pavillons/building-type-b": [1.828, 1.138, 1.140],
	"pavillons/building-type-c": [1.286, 1.034, 1.028],
	"pavillons/building-type-d": [1.756, 1.238, 1.028],
	"pavillons/building-type-e": [1.300, 1.138, 1.028],
	"pavillons/building-type-f": [1.428, 1.138, 1.406],
	"pavillons/building-type-g": [1.450, 0.768, 1.178],
	"pavillons/building-type-h": [1.300, 0.737, 0.916],
	"pavillons/building-type-i": [1.286, 0.737, 1.028],
	"pavillons/building-type-j": [1.370, 1.038, 0.916],
	"pavillons/building-type-k": [0.921, 1.150, 1.020],
	"pavillons/building-type-l": [1.034, 1.049, 1.020],
	"pavillons/building-type-m": [1.428, 0.737, 1.428],
	"pavillons/building-type-n": [1.784, 1.138, 1.378],
	"pavillons/building-type-o": [1.270, 1.138, 1.028],
	"pavillons/building-type-p": [1.240, 0.918, 0.990],
	"pavillons/building-type-q": [1.240, 0.918, 0.886],
	"pavillons/building-type-r": [1.028, 1.141, 1.020],
	"pavillons/building-type-s": [1.406, 1.138, 1.086],
	"pavillons/building-type-t": [1.314, 1.156, 1.406],
	"pavillons/building-type-u": [1.428, 1.138, 1.087],
}

## Les familles du centre (cahier § 3 : « quelques tours au milieu d'immeubles
## de 5-8 étages »). Un étage du kit fait ~0,32 unité Kenney.
const TOURS := ["batiments/building-skyscraper-a", "batiments/building-skyscraper-b",
	"batiments/building-skyscraper-c", "batiments/building-skyscraper-d",
	"batiments/building-skyscraper-e"]
const IMMEUBLES_HAUTS := ["batiments/building-l", "batiments/building-m", "batiments/building-n",
	"batiments/building-i", "batiments/building-j"]
const IMMEUBLES := ["batiments/building-a", "batiments/building-b", "batiments/building-d",
	"batiments/building-f", "batiments/building-g", "batiments/building-h",
	"batiments/building-k"]
const COMMERCES := ["batiments/building-c", "batiments/building-e"]

## Les props : modèle, hauteur voulue (unités 3D). Les hauteurs reprennent
## celles du jeu actuel (`FormesCarnage.PROPS_KENNEY`), validées à l'image.
const PROPS := {
	"lampadaire": {"m": "urbain/light-square", "h": 5.6, "c": "#5a5f68"},
	"lampadaire_double": {"m": "urbain/light-square-double", "h": 5.6, "c": "#5a5f68"},
	"lampadaire_parc": {"m": "urbain/light-curved", "h": 4.0, "c": "#5a5f68"},
	"feu": {"m": "urbain/traffic-light", "h": 4.4},
	"stop": {"m": "routes/road-sign-stop", "h": 2.40},
	"plaque": {"m": "routes/road-sign-street", "h": 2.60},
	"poubelle": {"m": "urbain/dumpster", "h": 1.10},
	"benne": {"m": "urbain/dumpster", "h": 1.60},
	"borne": {"m": "urbain/construction-barrier", "h": 0.90},
	"cone": {"m": "urbain/construction-cone", "h": 0.60},
	"arbre": {"m": "nature/tree_default", "h": 7.6},
	"arbre_oak": {"m": "nature/tree_oak", "h": 6.4},
	"arbre_rond": {"m": "nature/tree_fat", "h": 6.0},
	"arbre_petit": {"m": "nature/tree_oak", "h": 5.2},
	"palmier": {"m": "nature/tree_palm", "h": 8.0},
	"buisson": {"m": "nature/plant_bushDetailed", "h": 0.90},
	"banc": {"m": "nature/bench", "h": 0.85},
	"monument": {"m": "nature/statue_column", "h": 4.50},
	"auvent": {"m": "batiments/detail-awning", "h": 0.0},
	"auvent_large": {"m": "batiments/detail-awning-wide", "h": 0.0},
	"parasol": {"m": "batiments/detail-parasol-a", "h": 2.50},
	"parasol_b": {"m": "batiments/detail-parasol-b", "h": 2.50},
	"conteneur": {"m": "industriel/shipping-container-a", "h": 0.0},

	# LE KIT NATURE AU COMPLET (demande du client, 12/09 : « le kit nature
	# comprend énormément de choses, utilise-les »). Trois cents modèles sont
	# arrivés dans `modeles/kenney/nature/` ; ceux-ci sont les NOMS COURTS que
	# les générateurs et les raccourcis de l'éditeur emploient. Les autres
	# restent accessibles par leur chemin — un objet peut toujours être posé
	# par `res://…`, c'est ce que fait la palette.
	"pin": {"m": "nature/tree_pineTallA", "h": 13.0},
	"pin_b": {"m": "nature/tree_pineTallC", "h": 12.0},
	"pin_rond": {"m": "nature/tree_pineRoundC", "h": 10.0},
	"pin_petit": {"m": "nature/tree_pineSmallB", "h": 6.0},
	"sapin": {"m": "nature/tree_cone_dark", "h": 9.0},
	"arbre_automne": {"m": "nature/tree_default_fall", "h": 7.6},
	"arbre_plateau": {"m": "nature/tree_plateau", "h": 8.2},
	"arbre_fin": {"m": "nature/tree_thin", "h": 9.5},
	"palmier_haut": {"m": "nature/tree_palmTall", "h": 11.0},
	"palmier_courbe": {"m": "nature/tree_palmBend", "h": 9.0},
	"cactus": {"m": "nature/cactus_tall", "h": 2.20},
	"buisson_petit": {"m": "nature/plant_bushSmall", "h": 0.55},
	"buisson_grand": {"m": "nature/plant_bushLarge", "h": 1.30},
	"herbes": {"m": "nature/grass_large", "h": 0.70},
	"touffe": {"m": "nature/grass", "h": 0.45},
	"fleurs_rouges": {"m": "nature/flower_redA", "h": 0.45},
	"fleurs_jaunes": {"m": "nature/flower_yellowB", "h": 0.45},
	"fleurs_violettes": {"m": "nature/flower_purpleC", "h": 0.45},
	"champignon": {"m": "nature/mushroom_red", "h": 0.25},
	"champignons": {"m": "nature/mushroom_tanGroup", "h": 0.30},
	"souche": {"m": "nature/stump_round", "h": 0.50},
	"tronc": {"m": "nature/log", "h": 0.45},
	"tas_de_bois": {"m": "nature/log_stack", "h": 1.00},
	"rocher": {"m": "nature/rock_largeA", "h": 5.0},
	"rocher_b": {"m": "nature/rock_largeD", "h": 5.6},
	"rocher_haut": {"m": "nature/rock_tallA", "h": 8.5},
	"caillou": {"m": "nature/rock_smallA", "h": 0.70},
	"pierre_plate": {"m": "nature/stone_smallFlatA", "h": 0.30},
	"cloture": {"m": "nature/fence_simple", "h": 1.10},
	"cloture_planches": {"m": "nature/fence_planks", "h": 1.20},
	"portail": {"m": "nature/fence_gate", "h": 1.60},
	"pot": {"m": "nature/pot_large", "h": 0.80},
	"statue": {"m": "nature/statue_head", "h": 3.60},
	"obelisque": {"m": "nature/statue_obelisk", "h": 5.00},
	"tente": {"m": "nature/tent_detailedClosed", "h": 2.20},
	"feu_de_camp": {"m": "nature/campfire_stones", "h": 0.45},
	"nenuphar": {"m": "nature/lily_large", "h": 0.15},
	"escalier_pierre": {"m": "nature/cliff_steps_stone", "h": 0.0},
}

## LES BATEAUX (cahier § 3) : modèle, longueur voulue en unités, et le tirant
## d'eau — de combien la coque descend sous la ligne de flottaison. Les coques
## du Watercraft Pack sont toutes longues selon Z (mesuré) : on les tourne pour
## les aligner sur leur quai.
const BATEAUX := {
	"barque": {"m": "bateaux/boat-row-large", "l": 7.0, "tirant": 0.5},
	"peche": {"m": "bateaux/boat-fishing-small", "l": 12.0, "tirant": 1.2},
	"voilier": {"m": "bateaux/boat-sail-a", "l": 13.0, "tirant": 1.2},
	"vedette": {"m": "bateaux/boat-speed-a", "l": 10.0, "tirant": 0.8},
	"vedette_b": {"m": "bateaux/boat-speed-c", "l": 9.0, "tirant": 0.8},
	"remorqueur": {"m": "bateaux/boat-tug-a", "l": 14.0, "tirant": 1.4},
	"cargo": {"m": "bateaux/ship-cargo-a", "l": 62.0, "tirant": 4.0},
	"cargo_b": {"m": "bateaux/ship-cargo-b", "l": 62.0, "tirant": 4.0},
	"paquebot": {"m": "bateaux/ship-ocean-liner-small", "l": 78.0, "tirant": 5.0},
	"bouee": {"m": "bateaux/buoy", "l": 2.6, "tirant": 0.6},
	"bouee_drapeau": {"m": "bateaux/buoy-flag", "l": 3.4, "tirant": 0.6},
}

## Les voitures garées : Car Kit Kenney et modèles du client, longueur voulue.
const VOITURES := ["voitures/sedan", "voitures/sedan-sports", "voitures/hatchback-sports",
	"voitures/suv", "voitures/suv-luxury", "voitures/van", "voitures/taxi", "voitures/delivery"]
const LONGUEUR_VOITURE := 4.75            ## 19 voxels x 0,25 : le gabarit du jeu

## LES MODÈLES DU CLIENT (`modeles/piksl/`), déjà en unités du jeu : ils se
## posent à l'échelle 1, tels quels (cahier § 10 : « GLB exporté de Blender
## déposé dans modeles/piksl/, posé tel quel »). Tailles mesurées dans le GLB,
## en unités 3D. `echelle` corrige un modèle dessiné trop petit.
const PIKSL := {
	"piksl/gare": {"taille": [159.8, 59.5, 63.05], "echelle": 1.0},
	"piksl/hospital": {"taille": [30.0, 15.46, 30.0], "echelle": 1.0},
	"piksl/supermarket": {"taille": [30.0, 6.64, 24.6], "echelle": 1.0},
	"piksl/firestation": {"taille": [23.8, 15.1, 18.0], "echelle": 1.0},
	"piksl/eglise": {"taille": [14.6, 20.3, 24.6], "echelle": 1.0},
	"piksl/garage_de_peinture": {"taille": [8.32, 4.71, 6.75], "echelle": 2.4},
}

## La taille d'un modèle EN CASES (largeur X, hauteur Y, profondeur Z).
##
## ⚠ LES TABLES NE COUVRENT PAS TOUT. `BATIMENTS` et `PIKSL` sont les modèles
## que les générateurs posent ; l'éditeur, lui, laisse poser N'IMPORTE QUEL
## modèle du dossier `modeles/`. Pour ceux-là on MESURE la boîte du maillage,
## une fois, et on la garde : sans ça un modèle hors table valait une case sur
## une case, et son lot était trop petit pour lui.
static var _mesures: Dictionary = {}

static func taille(modele: String) -> Vector3:
	if PIKSL.has(modele):
		var f: Dictionary = PIKSL[modele]
		var t: Array = f["taille"]
		var e := float(f.get("echelle", 1.0)) / CASE
		return Vector3(float(t[0]) * e, float(t[1]) * e, float(t[2]) * e)
	if BATIMENTS.has(modele):
		var t2: Array = BATIMENTS[modele]
		return Vector3(float(t2[0]), float(t2[1]), float(t2[2]))
	return mesurer(modele)

## La boîte d'un modèle, en cases, mesurée sur son maillage.
static func mesurer(modele: String) -> Vector3:
	if _mesures.has(modele): return _mesures[modele]
	var boite := Vector3.ONE
	var chemin := chemin(modele)
	if ResourceLoader.exists(chemin):
		var m := FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
		if m.get_surface_count() > 0:
			var b := m.get_aabb().size
			# Les modèles du client sont déjà en unités du jeu ; ceux des kits
			# sont en unités Kenney, c'est-à-dire en cases.
			boite = b * echelle_libre(chemin) / CASE
	_mesures[modele] = boite
	return boite

static func est_du_client(chemin_ou_modele: String) -> bool:
	return chemin_ou_modele.contains("/piksl/") or chemin_ou_modele.begins_with("piksl/")

## Le facteur à appliquer au maillage brut pour le poser dans le monde : une
## unité Kenney = une case ; un modèle du client est déjà en unités du jeu.
static func echelle(modele: String) -> float:
	if PIKSL.has(modele):
		return float((PIKSL[modele] as Dictionary).get("echelle", 1.0))
	return 1.0 if est_du_client(modele) else CASE

## ⚠ LE KIT NATURE A DEUX ÉCHELLES, PAS UNE — mesuré sur ses 330 .glb.
##
## Ses pièces de TERRAIN pavent la case, comme le reste des kits Kenney :
## `cliff_block` fait 1 × 1 × 1 unité, `ground_pathStraight` 1 × 0,05 × 1,
## `bridge_wood` 1,04 × 0,4 × 1,04. Une unité Kenney = une case = 20 unités de
## jeu, et tout va bien.
##
## Ses ACCESSOIRES, eux, sont dessinés pour le petit bonhomme du kit, pas pour
## la case : un banc fait 0,47 unité de haut, une clôture 0,345, un champignon
## 0,203, un arbre 1,708. Posés « à l'échelle du kit », ça donne un banc de
## NEUF MÈTRES, une clôture de sept et un champignon de quatre — et c'est
## exactement ce que le client a vu dans l'éditeur : « toutes les fences et les
## fleurs champignon etc sont énormes comparé au personnage » (12/09).
##
## La palette de l'éditeur pose N'IMPORTE QUEL modèle du dossier, sans hauteur
## voulue : sans cette règle, tout le kit nature sort vingt fois trop grand.
## Le facteur vient des rapports mesurés sur les accessoires dont on connaît la
## bonne taille (arbre 7,6 m / 1,708 = 4,45 ; clôture 1,10 / 0,345 = 3,19 ;
## tente 2,20 / 0,561 = 3,92 ; banc 0,85 / 0,47 = 1,81) — le kit est stylisé,
## les rapports ne sont pas constants, on prend la médiane. Les générateurs,
## eux, imposent une hauteur exacte via `PROPS` : cette règle ne les concerne
## pas, elle rattrape ce qui est posé à la main.
const FAMILLES_DE_TERRAIN := ["cliff_", "ground_", "bridge_", "path_", "platform_",
	"crops_dirt"]
const ECHELLE_NATURE := 3.2

## Le facteur d'un modèle posé SANS hauteur voulue (`h` nul) : comme
## `echelle()`, sauf pour les accessoires du kit nature.
static func echelle_libre(chemin_ou_modele: String) -> float:
	var e := echelle(chemin_ou_modele)
	if e != CASE: return e
	if not chemin_ou_modele.contains("nature/"): return e
	var nom := chemin_ou_modele.get_file().trim_suffix(".glb")
	if nom == "": nom = chemin_ou_modele.get_slice("nature/", 1)
	for f in FAMILLES_DE_TERRAIN:
		if nom.begins_with(f): return e
	return ECHELLE_NATURE

## TOUS LES MODÈLES POSABLES, chemins `res://…`, variantes comprises. La liste
## vient de `ModelesDuKit` (écrite par `outils/modeles.sh`) : `DirAccess` ne
## voit pas les mêmes noms dans un paquet exporté. Le voxel est exclu — le
## client l'a abandonné le 12/09.
static var _catalogue: Array[String] = []

static func catalogue() -> Array[String]:
	if not _catalogue.is_empty(): return _catalogue
	for m in ModelesDuKit.TOUS:
		var nom := String(m)
		if nom.begins_with("voxel/") or nom.begins_with("personnages/") or nom.begins_with("creatures/"):
			continue
		_catalogue.append("res://modeles/" + nom + ".glb")
	return _catalogue

## La famille d'un modèle, telle qu'elle paraît dans la liste déroulante :
## `kenney/batiments`, `piksl`, `voitures`…
##
## ⚠ LES GROS DOSSIERS SE COUPENT EN RAYONS. Le kit nature compte 330 modèles :
## dans une seule liste, trouver un pin demandait de dérouler trente écrans. Au
## delà de `SEUIL_RAYON` modèles, le dossier se découpe sur le PRÉFIXE du nom
## (`tree_pineTallA` → `kenney/nature · tree`), qui est la façon dont Kenney
## nomme ses familles. Les modèles sans préfixe tombent dans « divers ».
const SEUIL_RAYON := 60

## ⚠ LE NOM DE LA FAMILLE EST CELUI DU DOSSIER, SANS LE KIT DEVANT. « nature »,
## « batiments », « voitures » — pas « kenney/nature ». Le client range par
## CATÉGORIE, et le kit d'origine ne l'intéresse pas : deux dossiers de nature
## venus de deux kits sont la même étagère.
static func famille(chemin_modele: String) -> String:
	var dossier := categorie(chemin_modele)
	if _gros.is_empty(): _compter()
	if not _gros.has(dossier): return dossier
	var fichier := chemin_modele.get_file().get_basename()
	return "%s · %s" % [dossier, _rayon(fichier)]

## La catégorie d'un modèle : le dernier dossier de son chemin. C'est elle qui
## fait l'étagère dans l'éditeur.
static func categorie(chemin_modele: String) -> String:
	var nom := chemin_modele.trim_prefix("res://modeles/").trim_suffix(".glb")
	var bouts := nom.split("/")
	if bouts.size() >= 3: return String(bouts[1])
	if bouts.size() == 2: return String(bouts[0])
	return "divers"

static var _gros: Dictionary = {}

static func _compter() -> void:
	_gros = {"—": true}
	var n: Dictionary = {}
	for m in catalogue():
		var d := categorie(String(m))
		n[d] = int(n.get(d, 0)) + 1
	for d in n:
		if int(n[d]) > SEUIL_RAYON: _gros[d] = true

## Le rayon d'un nom de modèle : ce qui précède le premier `_`, ou le premier
## `-` à défaut. `tree_pineTallA` → `tree` ; `road-bend-square` → `road`.
static func _rayon(fichier: String) -> String:
	var k := fichier.find("_")
	if k < 0: k = fichier.find("-")
	if k <= 0: return "divers"
	return fichier.substr(0, k)

static func nom_court(chemin_modele: String) -> String:
	return chemin_modele.get_file().get_basename()

## L'emprise d'un modèle en DEMI-cases, arrondie au-dessus, AVANT rotation.
static func emprise(modele: String) -> Vector2i:
	var t := taille(modele)
	return Vector2i(ceili(t.x * 2.0 - 0.02), ceili(t.z * 2.0 - 0.02))

## L'emprise dans le monde après `quarts` quarts de tour.
static func emprise_tournee(modele: String, quarts: int) -> Vector2i:
	var e := emprise(modele)
	return Vector2i(e.y, e.x) if posmod(quarts, 4) % 2 == 1 else e

static func chemin(modele: String) -> String:
	if modele.begins_with("res://"): return modele
	if modele.begins_with("piksl/"): return "res://modeles/" + modele + ".glb"
	return RACINE + modele + ".glb"

static func etages(modele: String) -> int:
	return maxi(1, roundi(taille(modele).y / 0.32))
