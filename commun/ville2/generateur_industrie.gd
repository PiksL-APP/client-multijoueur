class_name GenerateurIndustrie
extends RefCounted
## LE CINQUIÈME QUARTIER TÉMOIN : LA ZONE INDUSTRIELLE (cahier § 3).
##
## Les quatre premiers témoins ont éprouvé la ville dense, la côte, le relief
## et le pavillonnaire. Celui-ci éprouve LE SOL QUI N'EST PAS BEAU — le seul
## quartier du cahier où le vide, la terre battue et le grillage font le décor
## autant que les bâtiments :
##
## * « hangars, entrepôts, silos, cuves » (§ 3) → de grandes parcelles au
##   cordeau, desservies par une voie large ;
## * « casse auto (compacteur) et décharge » (§ 3) → un enclos de carcasses
##   empilées, ceint de grillage ;
## * « usine avec cheminées et fumée » (§ 3) → le bloc le plus haut du
##   quartier, ses cheminées et ses cuves ;
## * « chantier de construction (grues, grillages) » (§ 3) → une parcelle
##   encore nue, terrassée, clôturée ;
## * « terrains vagues et gravats en zone industrielle » (§ 4) → c'est la
##   matière de sol par défaut ici, pas l'exception ;
## * « places réservées (camions au port) » (§ 8) et « voie ferrée » (§ 6) →
##   une desserte ferroviaire longe le quartier, avec son quai de chargement.
##
## ⚠ CE QUI FAIT UNE ZONE INDUSTRIELLE, C'EST L'ÉCHELLE, PAS LE STYLE. Un
## hangar occupe dix fois la surface d'un pavillon et il est SEUL sur sa
## parcelle, entouré de bitume et de camions. Un quartier industriel dessiné
## comme une rue de ville — des façades qui se suivent — ne se lit pas. On pose
## donc de GRANDES PARCELLES espacées, et on remplit le vide entre elles de ce
## qui traîne sur une vraie friche.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.

## Les courbes larges (cahier § 5) : brique commune, appelée par `preload` — un
## `class_name` neuf n'existe pas dans l'export web.
const ANGLES := preload("res://commun/ville2/angles.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## LA VOIE FERRÉE longe le quartier au nord : c'est la raison d'être d'une zone
## industrielle, et c'est ce qui la sépare du reste de la ville.
const J_RAIL := 4
## LA ROCADE, l'axe lourd du quartier, d'ouest en est.
const J_ROCADE := 12
## Les deux dessertes transversales.
const J_DESSERTE := 24
const J_SUD := 34

## LES GRANDES PARCELLES, en cases : l'usine, la casse, le chantier, le dépôt.
const USINE := Rect2i(4, 14, 11, 8)
const CASSE := Rect2i(26, 14, 11, 8)
const CHANTIER := Rect2i(5, 26, 9, 6)
const DEPOT := Rect2i(24, 26, 13, 6)
## Le parc à conteneurs, entre le rail et la rocade.
const CONTENEURS := Rect2i(17, 6, 14, 5)

const PRENOMS := ["de la Fonderie", "des Entrepôts", "du Dépôt", "des Ateliers",
	"de la Zone", "des Forges", "du Fret", "des Silos", "de la Casse", "du Chantier"]

## Les hangars du kit industriel, du plus petit au plus grand.
const HANGARS := ["industriel/building-c", "industriel/building-h", "industriel/building-i",
	"industriel/building-l", "industriel/building-p", "industriel/building-q",
	"industriel/building-r", "industriel/building-s", "industriel/building-e",
	"industriel/building-f", "industriel/building-g", "industriel/building-j"]
## Les bâtiments d'usine, les plus hauts du quartier.
const USINES := ["industriel/building-a", "industriel/building-b", "industriel/building-d",
	"industriel/building-k", "industriel/building-m", "industriel/building-n",
	"industriel/building-o", "industriel/building-t"]
## Les bureaux de la zone, sur la rocade.
const BUREAUX := ["batiments/building-c", "batiments/building-e", "batiments/building-h",
	"batiments/low-detail-building-a", "batiments/low-detail-building-c"]

## LES CUVES, CHEMINÉES ET CHÂTEAUX D'EAU. Les hauteurs sont EN MÈTRES, comme
## partout depuis le 12/09 : une cheminée d'usine fait 25 m, un château d'eau
## 18, une cuve 6.
const APPAREILS := [
	{"m": "industriel/chimney-large", "h": 25.0},
	{"m": "industriel/chimney-medium", "h": 20.0},
	{"m": "industriel/chimney-basic", "h": 14.0},
	{"m": "industriel/chimney-small", "h": 9.0},
	{"m": "industriel/detail-tank", "h": 4.5},
	{"m": "industriel/detail-tank-large", "h": 7.0},
	{"m": "industriel/water-tower", "h": 18.0},
]
const CONTENEUR := ["industriel/shipping-container-a", "industriel/shipping-container-b",
	"industriel/shipping-container-c"]
## Un conteneur maritime fait 2,6 m de haut. Posé à l'échelle du kit il en
## ferait sept — mesuré 0,348 unité Kenney.
const H_CONTENEUR := 2.60

## Ce qui traîne sur une friche. Hauteurs en mètres.
const GRAVATS := ["nature/rock_smallA", "nature/rock_smallD", "nature/stone_smallFlatA",
	"nature/stone_smallB", "nature/log_stack", "nature/stump_squareDetailed"]
const H_GRAVATS = [0.55, 0.45, 0.30, 0.40, 1.00, 0.60]
## La végétation qui repousse sur une friche : des herbes, jamais des arbres
## d'alignement. Un bel arbre en zone industrielle, ça sonne faux.
const FRICHE := ["nature/grass_large", "nature/grass", "nature/plant_bushTriangle",
	"nature/plant_flatTall", "nature/plant_bushSmall"]
const H_FRICHE = [0.70, 0.45, 0.85, 0.60, 0.55]

## Le grillage de chantier du kit urbain, à hauteur d'homme et demi.
const H_GRILLAGE := 2.20

static func generer(graine := 5, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-industrie"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine

	_terrain(v, alea)
	_quartiers(v)
	_rues(v)
	_le_rail(v)
	v.rasteriser()
	ANGLES.arrondir(v, alea, 0.5)
	v.rasteriser()
	_les_parcelles(v, alea)
	v.rasteriser()
	_l_usine(v, alea)
	_la_casse(v, alea)
	_le_chantier(v, alea)
	_le_depot(v, alea)
	_les_conteneurs(v, alea)
	_la_friche(v, alea)
	_details(v, alea)
	return v

# ------------------------------------------------------------------ 1. le terrain

## ⚠ LE SOL PAR DÉFAUT EST DE LA TERRE, PAS DE L'HERBE. C'est la décision qui
## fait tout le quartier : dans les quatre autres témoins, le vide entre les
## rues est une pelouse ; ici c'est du remblai. L'herbe ne revient que sur les
## bandes qu'on n'a pas touchées depuis longtemps — le talus du rail, les
## bordures de la zone.
static func _terrain(v: Ville2, alea: RandomNumberGenerator) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			# Le talus du rail et les marges du quartier reverdissent.
			var au_bord := j < J_RAIL - 1 or j >= v.taille.y - 2 \
				or i < 2 or i >= v.taille.x - 2
			v.poser_matiere(c, Ville2.M_HERBE if au_bord and alea.randf() < 0.85 \
				else Ville2.M_TERRE)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "La Zone", "genre": Ville2.Q_INDUSTRIE, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)

# ------------------------------------------------------------------ 2. les rues

static func _rues(v: Ville2) -> void:
	var n := 0
	# LA ROCADE : large, droite, sans trottoir marchand. C'est une route de
	# camions.
	v.ajouter_route(Ville2.R_AVENUE,
		[Vector2i(0, J_ROCADE), Vector2i(v.taille.x - 1, J_ROCADE)],
		"Rocade Industrielle")
	for jr in [J_DESSERTE, J_SUD]:
		v.ajouter_route(Ville2.R_AVENUE, [Vector2i(0, jr), Vector2i(v.taille.x - 1, jr)],
			"Rue " + PRENOMS[n % PRENOMS.size()])
		n += 1
	# Les dessertes nord-sud, espacées : une parcelle industrielle est large.
	for x in [3, 16, 23, 38]:
		v.ajouter_route(Ville2.R_RUE, [Vector2i(x, J_ROCADE - 6), Vector2i(x, J_SUD + 3)],
			"Rue " + PRENOMS[n % PRENOMS.size()])
		n += 1
	# La contre-allée qui longe le rail, pour desservir le parc à conteneurs.
	v.ajouter_route(Ville2.R_RUE,
		[Vector2i(3, J_RAIL + 2), Vector2i(v.taille.x - 3, J_RAIL + 2)],
		"Quai de Chargement")

## LA VOIE FERRÉE de desserte (cahier § 6 : « un train de marchandises en plus
## du train de voyageurs »), au nord, avec son embranchement vers le dépôt.
static func _le_rail(v: Ville2) -> void:
	v.rail.append({"points": [Vector2i(0, J_RAIL), Vector2i(v.taille.x - 1, J_RAIL)]})
	v.rail.append({"points": [Vector2i(20, J_RAIL), Vector2i(20, J_RAIL + 1),
		Vector2i(31, J_RAIL + 1)]})

# ------------------------------------------------------------------ 3. les parcelles

## Les hangars bordent les dessertes, mais À GRANDS ÉCARTS : un hangar est seul
## sur sa parcelle, avec sa cour de manœuvre.
static func _les_parcelles(v: Ville2, alea: RandomNumberGenerator) -> void:
	# Le long de la rocade, au sud : la façade de la zone, bureaux et hangars.
	Lotisseur.aligner(v, alea, BUREAUX, "n",
		Vector2i(4 * 2, (J_ROCADE + 1) * 2), 10 * 2, "bureau", 0.9, 2)
	Lotisseur.aligner(v, alea, HANGARS, "n",
		Vector2i(17 * 2, (J_ROCADE + 1) * 2), 20 * 2, "hangar", 0.85, 3)
	# Entre la desserte et la rue sud, deux rangées de hangars dos à dos.
	Lotisseur.aligner(v, alea, HANGARS, "n",
		Vector2i(4 * 2, (J_DESSERTE + 1) * 2), 32 * 2, "hangar", 0.8, 4)
	Lotisseur.aligner(v, alea, HANGARS, "s",
		Vector2i(4 * 2, (J_SUD - 1) * 2), 32 * 2, "hangar", 0.7, 5)

# ------------------------------------------------------------------ 4. l'usine

## L'USINE (cahier § 3 : « usine avec cheminées et fumée »). Le bloc bâti au
## nord de la parcelle, la cour au sud, et les appareils — cheminées, cuves,
## château d'eau — qui font sa silhouette.
static func _l_usine(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := USINE
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			v.poser_matiere(Vector2i(i, j), Ville2.M_DALLE)
	Lotisseur.aligner(v, alea, USINES, "s",
		Vector2i(r.position.x * 2, (r.position.y + 3) * 2), r.size.x * 2, "usine", 0.95, 0)
	# LES CHEMINÉES, alignées le long du pignon : une usine a une batterie de
	# cheminées, pas une cheminée solitaire.
	for k in 3:
		var f: Dictionary = APPAREILS[k]
		v.ajouter_objet(String(f["m"]), (float(r.position.x) + 1.2 + float(k) * 1.1) * CASE,
			(float(r.position.y) + 4.2) * CASE, 0.0, float(f["h"]))
	# Les cuves et le château d'eau, dans la cour.
	for k in 4:
		var f: Dictionary = APPAREILS[4 + (k % 3)]
		v.ajouter_objet(String(f["m"]),
			(float(r.position.x) + 5.5 + float(k % 2) * 2.2) * CASE,
			(float(r.position.y) + 5.4 + float(k / 2) * 1.6) * CASE,
			float(alea.randi() % 4) * PI * 0.5, float(f["h"]))
	_clore(v, r, alea, "urbain/construction-fence", 0.10)
	v.ajouter_lieu("usine", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(r.position.y) + float(r.size.y) * 0.5) * CASE, {"nom": "Fonderie du Levant"})

# ------------------------------------------------------------------ 5. la casse

## LA CASSE AUTO (cahier § 3 : « casse auto (compacteur) et décharge »). Ce qui
## la dessine, ce sont les CARCASSES EMPILÉES — on reprend les modèles du Car
## Kit, posés de travers, à trois hauteurs.
static func _la_casse(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := CASSE
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			v.poser_matiere(Vector2i(i, j), Ville2.M_TERRE)
	# Le hangar du compacteur, au coin.
	var m := "industriel/building-l"
	var e := KitVille2.emprise_tournee(m, 2)
	if Lotisseur.terrain_libre(v, r.position.x * 2, r.position.y * 2, e):
		v.ajouter_lot(m, r.position.x * 2, r.position.y * 2, e.x, e.y, 2, "casse")
	# LES PILES DE CARCASSES. ⚠ `y_abs` OU RIEN : sans altitude imposée, chaque
	# voiture se repose au sol et la pile s'effondre en tas plat.
	for k in 26:
		var x := (float(r.position.x) + 3.5 + alea.randf() * (float(r.size.x) - 4.5)) * CASE
		var z := (float(r.position.y) + 0.6 + alea.randf() * (float(r.size.y) - 1.2)) * CASE
		var haut := alea.randi_range(1, 3)
		for n in haut:
			var voiture: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
			v.ajouter_objet(voiture, x + alea.randf_range(-1.5, 1.5),
				z + alea.randf_range(-1.5, 1.5), alea.randf() * TAU)
			v.objets[v.objets.size() - 1]["y_abs"] = float(n) * 1.55
	# Les bennes de tri.
	for k in 6:
		v.ajouter_objet("benne", (float(r.position.x) + 1.0) * CASE,
			(float(r.position.y) + 1.4 + float(k) * 0.9) * CASE, PI * 0.5)
	_clore(v, r, alea, "urbain/construction-fence", 0.05)
	v.ajouter_lieu("casse", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(r.position.y) + float(r.size.y) * 0.5) * CASE, {"nom": "Casse du Levant"})

# ------------------------------------------------------------------ 6. le chantier

## LE CHANTIER (cahier § 3 : « chantier de construction (grues, grillages) »).
## Une parcelle terrassée, son grillage, ses cônes et ses tas — le kit n'a pas
## de grue, c'est le VIDE CLÔTURÉ qui dit le chantier.
static func _le_chantier(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := CHANTIER
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			v.poser_matiere(Vector2i(i, j), Ville2.M_TERRE)
	# Les fondations : deux rectangles de dalle, comme une dalle coulée.
	for j in range(r.position.y + 1, r.position.y + 4):
		for i in range(r.position.x + 1, r.position.x + 5):
			v.poser_matiere(Vector2i(i, j), Ville2.M_DALLE)
	for k in 14:
		var n := alea.randi() % GRAVATS.size()
		v.ajouter_objet(GRAVATS[n],
			(float(r.position.x) + alea.randf() * float(r.size.x)) * CASE,
			(float(r.position.y) + alea.randf() * float(r.size.y)) * CASE,
			alea.randf() * TAU, float(H_GRAVATS[n]))
	for k in 8:
		v.ajouter_objet("cone", (float(r.position.x) + alea.randf() * float(r.size.x)) * CASE,
			(float(r.position.y) + alea.randf() * float(r.size.y)) * CASE, 0.0)
	for k in 3:
		v.ajouter_objet("benne", (float(r.position.x) + 6.2) * CASE,
			(float(r.position.y) + 1.0 + float(k) * 1.1) * CASE, 0.0)
	_clore(v, r, alea, "urbain/construction-fence", 0.08)
	v.ajouter_lieu("chantier", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(r.position.y) + float(r.size.y) * 0.5) * CASE, {"nom": "Chantier de la Zone"})

# ------------------------------------------------------------------ 7. le dépôt

## LE DÉPÔT DE CAMIONS (cahier § 8 : « places réservées, camions au port »). Une
## dalle, ses hangars au fond, et les camions rangés en épi.
static func _le_depot(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := DEPOT
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			v.poser_matiere(Vector2i(i, j), Ville2.M_DALLE)
	Lotisseur.aligner(v, alea, HANGARS, "s",
		Vector2i(r.position.x * 2, (r.end.y - 1) * 2), r.size.x * 2, "hangar", 0.9, 1)
	# Les camions en épi, nez vers la sortie.
	for k in 10:
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, (float(r.position.x) + 0.8 + float(k) * 1.15) * CASE,
			(float(r.position.y) + 1.1) * CASE, 0.0)
	v.ajouter_lieu("depot", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(r.position.y) + 1.0) * CASE, {"nom": "Dépôt du Fret"})

# ------------------------------------------------------------------ 8. les conteneurs

## LE PARC À CONTENEURS, entre le rail et la rocade : des piles de trois, en
## rangées, avec les allées de gerbage entre elles.
static func _les_conteneurs(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := CONTENEURS
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			v.poser_matiere(Vector2i(i, j), Ville2.M_DALLE)
	for j in range(r.position.y, r.end.y):
		# Une rangée sur deux : l'autre est l'allée du portique.
		if (j - r.position.y) % 2 == 1: continue
		for i in range(r.position.x, r.end.x):
			if alea.randf() < 0.18: continue
			var haut := alea.randi_range(1, 3)
			for n in haut:
				var m: String = CONTENEUR[alea.randi() % CONTENEUR.size()]
				v.ajouter_objet(m, (float(i) + 0.5) * CASE, (float(j) + 0.5) * CASE,
					PI * 0.5, H_CONTENEUR)
				v.objets[v.objets.size() - 1]["y_abs"] = float(n) * H_CONTENEUR

# ------------------------------------------------------------------ 9. la friche

## LA FRICHE : tout ce qui n'est ni bâti, ni roulant, ni clôturé. C'est la
## moitié de la surface du quartier, et c'est elle qu'on voit.
static func _la_friche(v: Ville2, alea: RandomNumberGenerator) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c) or v.plate(c): continue
			if v.matiere_de(c) != Ville2.M_TERRE: continue
			if alea.randf() < 0.30:
				var n := alea.randi() % FRICHE.size()
				v.ajouter_objet(FRICHE[n], (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					float(H_FRICHE[n]))
			if alea.randf() < 0.16:
				var g := alea.randi() % GRAVATS.size()
				v.ajouter_objet(GRAVATS[g], (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					float(H_GRAVATS[g]))

# ------------------------------------------------------------------ 10. les détails

static func _details(v: Ville2, alea: RandomNumberGenerator) -> void:
	# Les lampadaires de la rocade, hauts et espacés.
	for r in v.routes:
		if String(r["genre"]) != Ville2.R_AVENUE: continue
		var cases := Ville2.cases_de_route(r)
		for k in range(2, cases.size(), 7):
			var c: Vector2i = cases[k]
			v.ajouter_objet("lampadaire_double", (float(c.x) + 0.1) * CASE,
				(float(c.y) + 0.1) * CASE, 0.0)
	# Les poteaux électriques, le long du rail : c'est ce qui fait lire la voie
	# de loin, avant même de distinguer les rails.
	for i in range(2, v.taille.x - 1, 5):
		v.ajouter_objet("res://modeles/kenney/urbain/electricity-pole.glb",
			(float(i) + 0.5) * CASE, (float(J_RAIL) - 1.2) * CASE, 0.0, 11.0)
	# Les camions garés le long de la rocade.
	for k in 8:
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, (3.0 + alea.randf() * 33.0) * CASE,
			(float(J_ROCADE) + 0.82) * CASE, PI * 0.5)
	# Bennes et cônes au hasard, le long des dessertes.
	for k in 14:
		var x := (2.0 + alea.randf() * 36.0) * CASE
		var z := (float(J_DESSERTE) + alea.randf_range(0.75, 1.6)) * CASE
		v.ajouter_objet("benne" if alea.randf() < 0.6 else "cone", x, z, alea.randf() * TAU)

## Un grillage autour d'un rectangle de cases, avec un portail : une case du
## bord tirée au sort reste ouverte, sinon on n'entre pas.
static func _clore(v: Ville2, r: Rect2i, alea: RandomNumberGenerator, modele: String,
		breche := 0.08) -> void:
	for i in range(r.position.x, r.end.x):
		for j in [r.position.y, r.end.y - 1]:
			if alea.randf() < breche: continue
			v.ajouter_objet(modele, (float(i) + 0.5) * CASE,
				(float(j) + (0.02 if j == r.position.y else 0.98)) * CASE, 0.0, H_GRILLAGE)
	for j in range(r.position.y, r.end.y):
		for i in [r.position.x, r.end.x - 1]:
			if alea.randf() < breche: continue
			v.ajouter_objet(modele, (float(i) + (0.02 if i == r.position.x else 0.98)) * CASE,
				(float(j) + 0.5) * CASE, PI * 0.5, H_GRILLAGE)
