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

## Les règles communes à tous les quartiers : rien sur la chaussée, et pas
## une pelouse nue. Appelées en dernier (voir `commun/ville2/proprete.gd`).
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const ATLAS := preload("res://commun/ville2/atlas.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")

## Les panneaux publicitaires (cahier § 7) : toits, pignons aveugles, bords
## d'axe. Brique commune — l'affichage est une règle de ville, pas de quartier.
const AFFICHES := preload("res://commun/ville2/affiches.gd")

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

## ⚠ LES TROIS GRANDS ÉQUIPEMENTS DEMANDÉS LE 13/09 — « il manque une petite
## gare, il manque un aéroport, il manque un parc automobile géant ».
##
## Ils ont chacun leur place logique, et ce n'est pas un hasard : une zone
## industrielle EST un nœud de transport. La gare marchandises se colle au
## rail parce que c'est sa raison d'être ; le parc automobile prend le vide
## central, qui était la plus grande friche du témoin ; la piste prend la
## bande sud, la seule assez longue pour qu'une piste soit crédible (trente-six
## cases, sept cent vingt mètres — une piste courte réelle).
const GARE := Rect2i(3, 5, 12, 4)
const PARC_AUTO := Rect2i(16, 14, 10, 8)
const AEROPORT := Rect2i(2, 35, 36, 5)

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
## La hauteur FORCÉE de la machine et des wagons — voir `_la_gare`.
const H_LOCO := 7.6
const H_WAGON := 6.6

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
	Lotisseur.oublier_les_sacs()

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
	_les_pylones(v, alea)
	_interdire_le_rail(v)
	_la_gare(v, alea)
	_le_parc_automobile(v, alea)
	_l_aeroport(v, alea)
	v.rasteriser()
	_encore_des_hangars(v, alea, 26)
	v.rasteriser()
	_la_friche(v, alea)
	_details(v, alea)
	# ⚠ MOINS DE PANNEAUX SUR PIEDS, ET PLUS BAS. « J'ai des pubs qui volent »
	# (13/09) : posé au bord d'un axe, le panneau de bord de route montait son
	# bas à cinq mètres sur deux poteaux de soixante-dix centimètres, au milieu
	# d'une friche nue. De loin, on ne voit plus les poteaux — on voit une
	# image en l'air. On descend le pied, on épaissit les poteaux (voir
	# `affiches.gd`) et on en met deux au lieu de six : sur une friche, le vide
	# autour d'un panneau le rend plus visible, pas moins.
	AFFICHES.semer(v, alea, 130.0, [], 2)
	# ⚠ AUCUNE TOITURE VERTE (client, 13/09). Voir `atlas.gd` : la bande
	# verte de l'atlas est repeinte par bâtiment, murs inchangés.
	TEINTES.couvrir(v, alea, "", ATLAS.TOLE)
	TEINTES.peindre(v, alea, "", TEINTES.INDUSTRIE, 0.35)
	PROPRETE.finir(v, alea)
	return v

# ------------------------------------------------------------------ la densité

## ⚠ « J'AI PAS ASSEZ D'INDUSTRIE » (client, 13/09), ET C'ÉTAIT VRAI. Le témoin
## posait cinq grandes pièces et bordait trois axes ; tout le reste — la moitié
## de la carte — restait du remblai nu. Or une zone industrielle réelle n'a pas
## de terrain vague AU MILIEU : elle en a en LISIÈRE, là où elle n'a pas encore
## poussé. Le vide au centre se lit comme un oubli, pas comme une friche.
##
## On repasse donc sur la carte finie et on plante des hangars partout où il
## reste un carré libre, tournés vers l'axe le plus proche. C'est une passe de
## REMPLISSAGE, délibérément bête : elle ne dessine rien, elle bouche.
static func _encore_des_hangars(v: Ville2, alea: RandomNumberGenerator, combien: int) -> void:
	var poses := 0
	var essais := 0
	while poses < combien and essais < 900:
		essais += 1
		var i := 2 + alea.randi() % (v.taille.x - 6)
		var j := 2 + alea.randi() % (v.taille.y - 6)
		# Jamais dans les grandes pièces : elles ont leur composition.
		var dedans := false
		for r in [USINE, CASSE, CHANTIER, DEPOT, CONTENEURS, GARE, PARC_AUTO, AEROPORT]:
			if (r as Rect2i).grow(1).has_point(Vector2i(i, j)): dedans = true
		if dedans: continue
		var m: String = HANGARS[alea.randi() % HANGARS.size()]
		var q := alea.randi() % 4
		var e := KitVille2.emprise_tournee(m, q)
		if not Lotisseur.terrain_libre(v, i * 2, j * 2, e): continue
		v.ajouter_lot(m, i * 2, j * 2, e.x, e.y, q, "hangar")
		poses += 1
		# Sa cour : des camions, des palettes, une cuve, et le grillage devant.
		if alea.randf() < 0.5:
			var f: Dictionary = APPAREILS[4 + alea.randi() % 3]
			v.ajouter_objet(String(f["m"]), (float(i) + float(e.x) * 0.5 + 1.6) * CASE,
				(float(j) + 0.5) * CASE, 0.0, float(f["h"]))
		for k in alea.randi_range(1, 3):
			v.ajouter_objet(CONTENEUR[alea.randi() % CONTENEUR.size()],
				(float(i) + alea.randf_range(-0.9, float(e.x) * 0.5 + 0.9)) * CASE,
				(float(j) + float(e.y) * 0.5 + 0.7 + float(k) * 0.5) * CASE,
				PI * 0.5, H_CONTENEUR)
		if alea.randf() < 0.6:
			var camion: String = ["voitures/truck", "voitures/delivery", "voitures/box"][alea.randi() % 3]
			v.ajouter_objet(camion, (float(i) - 0.7) * CASE,
				(float(j) + float(e.y) * 0.25) * CASE, 0.0)

# ------------------------------------------------------------------ la gare

## LA PETITE GARE DE MARCHANDISES. Pas la gare voyageurs du client
## (`piksl/gare` fait cent soixante mètres de long, c'est la gare centrale) :
## ici, un bâtiment de service, un quai de chargement le long du rail, une
## grue, et les wagons qui attendent.
static func _la_gare(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := GARE
	var debut := v.objets.size()
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			v.poser_matiere(c, Ville2.M_DALLE)
	# LE QUAI (lot 3) : des pièces de quai bout à bout le long du rail. Un quai
	# se lit d'en haut mieux que n'importe quel bâtiment — c'est la seule chose
	# longue et étroite d'un quartier fait de boîtes.
	# ⚠ La pièce est dessinée dans l'axe Z ; le rail court en X : quart de tour.
	var zq := (float(J_RAIL) + 1.4) * CASE
	var nq := int(float(r.size.x) * CASE / 36.0)
	for k in nq:
		v.ajouter_objet("pxl/quai-gare",
			(float(r.position.x) * CASE) + 18.0 + float(k) * 36.0, zq, PI * 0.5)
	# Le bâtiment de la gare, au milieu du quai.
	_poser(v, "batiments/building-e", Vector2i(r.position.x + 4, r.position.y + 1), 2, "gare")
	# LE TRAIN, sur la voie : machine en tête, wagons derrière. Un rail nu est
	# un trait par terre ; un train dessus, c'est une gare.
	var zr := (float(J_RAIL) + 0.5) * CASE
	var xt := (float(r.position.x) + 0.6) * CASE
	# ⚠ UN TRAIN DOIT PESER AUTANT QUE LES HANGARS QUI L'ENTOURENT. À sa cote
	# réelle — 17,5 m de long, 4,5 m de haut — la machine ressemblait à un
	# jouet à côté d'une usine Kenney de quarante mètres de large (« le train
	# m'a l'air petit comparé aux bâtiments à côté », client, 14/09). On force
	# donc sa hauteur : la même exagération que le kit s'autorise partout
	# ailleurs, et c'est le RAPPORT qui compte, pas la cote.
	v.ajouter_objet("pxl/locomotive", xt, zr, PI * 0.5, H_LOCO)
	xt += 18.5 * (H_LOCO / 4.54)
	var rame := ["pxl/wagon-marchandises", "pxl/wagon-citerne", "pxl/wagon-plat",
		"pxl/wagon-marchandises", "pxl/wagon-citerne"]
	for m in rame:
		v.ajouter_objet(m, xt, zr, PI * 0.5, H_WAGON)
		xt += 15.6 * (H_LOCO / 4.54)
	# Une grue mobile au bout du quai, et les palettes qu'elle décharge.
	v.ajouter_objet("pxl/grue-mobile", (float(r.end.x) - 1.2) * CASE,
		(float(J_RAIL) + 2.1) * CASE, PI)
	# Les lampadaires du quai.
	for k in 8:
		v.ajouter_objet("lampadaire", (float(r.position.x) + 0.8 + float(k) * 1.5) * CASE,
			(float(J_RAIL) + 2.0) * CASE, 0.0)
	# Les conteneurs et les palettes en attente de chargement.
	for k in 12:
		v.ajouter_objet(CONTENEUR[alea.randi() % CONTENEUR.size()],
			(float(r.position.x) + 0.7 + alea.randf() * (float(r.size.x) - 1.4)) * CASE,
			(float(r.position.y) + 2.2 + alea.randf() * 1.4) * CASE,
			PI * 0.5, H_CONTENEUR)
	for k in range(debut, v.objets.size()):
		v.objets[k]["zone"] = true
	v.ajouter_lieu("gare", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(J_RAIL) + 1.2) * CASE, {"nom": "Gare de Fret"})

## ⚠ LA VOIE FERRÉE EST UNE ZONE INTERDITE, elle aussi. Le client a vu des
## panneaux publicitaires ENTRE LES RAILS. Un rail n'est ni une rue ni une
## parcelle : la passe de propreté doit pouvoir tout en retirer.
static func _interdire_le_rail(v: Ville2) -> void:
	var large := float(v.taille.x) * CASE
	v.interdire(Rect2(0.0, (float(J_RAIL) + 0.15) * CASE, large, CASE * 0.7))
	v.interdire(Rect2(20.0 * CASE, (float(J_RAIL) + 1.15) * CASE, 11.0 * CASE, CASE * 0.7))

# ------------------------------------------------------------------ le parc automobile

## LE PARC AUTOMOBILE GÉANT. Un dépôt de véhicules neufs : c'est la pièce qui
## remplit le vide central, et c'est un décor d'une efficacité rare parce qu'il
## est fait d'une seule chose répétée des centaines de fois.
##
## ⚠ QUATRE VOITURES PAR CASE EN LARGEUR, DEUX RANGS DOS À DOS. Une voiture
## fait 4,75 m et une case vingt : à une voiture par case, quatre-vingts
## voitures sur huit cases sur dix paraissent abandonnées. À quatre par case,
## on en compte six cents et le parc est plein. Même arithmétique que le
## parking du campus.
static func _le_parc_automobile(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := PARC_AUTO
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0: continue
			v.poser_matiere(c, Ville2.M_DALLE)
	for j in range(r.position.y, r.end.y):
		# Une bande sur quatre est l'allée de circulation : sans elle, c'est
		# une nappe de tôle et plus un parking.
		if (j - r.position.y) % 4 == 3: continue
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0: continue
			for k in 4:
				for rang in [0.24, 0.62]:
					if alea.randf() > 0.88: continue
					var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
					v.ajouter_objet(m, (float(i) + 0.13 + float(k) * 0.25) * CASE,
						(float(j) + rang) * CASE, PI * 0.5)
	# Le grillage tout autour, et le bureau de livraison au coin.
	_ceindre(v, r, alea)
	_poser(v, "industriel/building-h", Vector2i(r.position.x, r.end.y - 2), 0, "livraison")
	for j in range(r.position.y, r.end.y, 3):
		v.ajouter_objet("lampadaire_double", (float(r.position.x) + 0.1) * CASE,
			(float(j) + 0.5) * CASE, 0.0)
		v.ajouter_objet("lampadaire_double", (float(r.end.x) - 0.1) * CASE,
			(float(j) + 0.5) * CASE, 0.0)
	v.ajouter_lieu("parc_auto", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(r.position.y) + float(r.size.y) * 0.5) * CASE,
		{"nom": "Parc Automobile du Fret"})

# ------------------------------------------------------------------ l'aéroport

## L'AÉRODROME (client, 13/09 : « il manque un aéroport »).
##
## Ce qui fait lire un aérodrome d'en haut, c'est LA PISTE : une bande sombre
## très longue et très étroite, son axe en pointillés, ses seuils marqués, un
## taxiway parallèle, un tarmac au bout. Aucune autre chose au monde n'a cette
## forme, et ça, le kit savait déjà le faire.
##
## Ce qu'il ne savait pas faire, c'est le poser au sol : les hangars étaient
## trois bâtiments industriels et la tour de contrôle un château d'eau. Le
## LOT 3 (14/09) apporte les vraies pièces — hangar à toit en demi-cylindre,
## tour de contrôle vitrée, manche à air, et surtout DES AVIONS, parce qu'un
## aérodrome sans avion est un parking.
##
## ⚠ TOUT REGARDE −Z, comme le reste des pièces `pxl/` : la porte du hangar,
## le nez des avions, la porte de la tour. Le tarmac étant au SUD de la piste,
## tout s'y pose sans tourner, nez vers le taxiway.
const PISTE := "#3f4247"
const MARQUE := "#eef1ec"
## Le tarmac, un gris plus clair que la piste — c'est ce qui les sépare d'en
## haut, et c'est vrai : une aire de stationnement n'est pas un revêtement de
## piste.
const TARMAC := "#5b6068"

static func _l_aeroport(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := AEROPORT
	var debut := v.objets.size()
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			v.poser_matiere(c, Ville2.M_DALLE)
	var z0 := float(r.position.y) * CASE
	var zp := z0 + 15.0                 ## l'axe de la piste
	var zt := z0 + 40.0                 ## l'axe du taxiway
	var za := z0 + 65.0                 ## l'axe du tarmac
	var xc := (float(r.position.x) + float(r.size.x) * 0.5) * CASE
	var lg := float(r.size.x) * CASE * 0.97
	# La piste.
	v.objets.append({"m": "pelouse", "x": xc, "z": zp, "r": 0.0, "h": 0.0,
		"w": lg, "d": 26.0, "c": PISTE})
	# L'axe en pointillés : trente traits, c'est ce qui donne l'échelle.
	for k in 30:
		v.objets.append({"m": "pelouse",
			"x": (float(r.position.x) + 0.8 + float(k) * (float(r.size.x) - 1.6) / 29.0) * CASE,
			"z": zp, "r": 0.0, "h": 0.0, "w": 9.0, "d": 1.1, "c": MARQUE})
	# Les seuils : les grandes barres perpendiculaires des deux bouts.
	for s2 in [-1.0, 1.0]:
		for k in 6:
			v.objets.append({"m": "pelouse", "x": xc + s2 * (lg * 0.5 - 14.0),
				"z": zp + (float(k) - 2.5) * 3.6, "r": 0.0, "h": 0.0,
				"w": 18.0, "d": 1.6, "c": MARQUE})
	# LE TAXIWAY, parallèle, plus étroit, et ses deux bretelles vers le tarmac.
	v.objets.append({"m": "pelouse", "x": xc, "z": zt, "r": 0.0, "h": 0.0,
		"w": lg * 0.86, "d": 13.0, "c": PISTE})
	# LE TARMAC, au sud : c'est là que tout se gare.
	v.objets.append({"m": "pelouse", "x": xc, "z": za, "r": 0.0, "h": 0.0,
		"w": lg * 0.95, "d": 34.0, "c": TARMAC})
	# LES HANGARS (lot 3) : vingt-quatre mètres de large, toit en demi-cylindre,
	# portes ouvrant sur le tarmac.
	var hx := (float(r.end.x) - 5.5) * CASE
	for k in 3:
		v.ajouter_objet("pxl/hangar-avion", hx - float(k) * 32.0, za + 5.0, 0.0)
	# LA TOUR DE CONTRÔLE : quatorze mètres, cabine vitrée en encorbellement.
	# C'est le seul volume haut de la bande, et il se voit de tout le quartier.
	v.ajouter_objet("pxl/tour-controle", hx + 22.0, za + 2.0, 0.0)
	# LA MANCHE À AIR, au bord de la piste : elle dit le vent, et elle dit
	# « aérodrome » à elle seule.
	v.ajouter_objet("pxl/manche-a-air", hx + 22.0, zp + 20.0, 0.0)
	# LES APPAREILS. Un aérodrome sans avion est un parking : le régional au
	# poste de chargement, deux légers en file, l'hélico sur sa plateforme.
	var ax := (float(r.position.x) + float(r.size.x) * 0.42) * CASE
	v.ajouter_objet("pxl/avion-regional", ax, za - 1.0, 0.0)
	for k in 3:
		v.ajouter_objet("pxl/avion-leger", ax - 40.0 - float(k) * 13.0, za + 1.0, 0.0)
	# L'hélistation : un rond plus clair, sa croix, et l'appareil dessus.
	var hex := (float(r.position.x) + 2.0) * CASE
	v.objets.append({"m": "pelouse", "x": hex, "z": za, "r": 0.0, "h": 0.0,
		"w": 24.0, "d": 24.0, "c": TARMAC})
	v.objets.append({"m": "pelouse", "x": hex, "z": za, "r": 0.0, "h": 0.0,
		"w": 12.0, "d": 1.4, "c": MARQUE})
	v.objets.append({"m": "pelouse", "x": hex, "z": za, "r": 0.0, "h": 0.0,
		"w": 1.4, "d": 12.0, "c": MARQUE})
	v.ajouter_objet("pxl/helicoptere", hex, za, 0.0)
	# Un avion léger en finale de piste, prêt à décoller, au seuil ouest.
	v.ajouter_objet("pxl/avion-leger", xc - lg * 0.42, zp, PI * 0.5)
	# Les balises de piste, tous les deux cents mètres, des deux côtés.
	for k in 10:
		var bx := (float(r.position.x) + 1.0 + float(k) * (float(r.size.x) - 2.0) / 9.0) * CASE
		for s3 in [-1.0, 1.0]:
			v.ajouter_objet("cone", bx, zp + s3 * 16.0, 0.0)
	# Le grillage : un aérodrome est toujours clos.
	_ceindre(v, r, alea)
	# ⚠ ET ON FERME LA BANDE. Tout ce que l'aérodrome vient de poser porte le
	# drapeau `zone` ; ensuite la bande devient interdite, et la passe de
	# propreté balaie TOUT ce que les autres passes y déposeraient — panneaux
	# publicitaires compris, qui sont pourtant de la voirie ailleurs.
	for k in range(debut, v.objets.size()):
		v.objets[k]["zone"] = true
	v.interdire(Rect2(float(r.position.x) * CASE, z0,
		float(r.size.x) * CASE, float(r.size.y) * CASE))
	v.ajouter_lieu("aeroport", xc, za, {"nom": "Aérodrome du Fret"})

## ⚠ LE GRILLAGE, ET IL EST EN TREILLIS — c'est la « fence en verre » du client
## (13/09) : `urbain/construction-fence` est un panneau de grillage à mailles
## fines, qui se lit comme une vitre de loin. C'est la clôture des zones
## industrielles, et il en manquait partout.
static func _ceindre(v: Ville2, r: Rect2i, alea: RandomNumberGenerator) -> void:
	var pas := 0.98
	for i in range(0, int(float(r.size.x) / pas)):
		var x := (float(r.position.x) + float(i) * pas + 0.5) * CASE
		for j in [float(r.position.y), float(r.end.y)]:
			if alea.randf() < 0.06: continue      # le portail
			v.ajouter_objet("urbain/construction-fence", x, j * CASE, 0.0, H_GRILLAGE)
	for j in range(0, int(float(r.size.y) / pas)):
		var z := (float(r.position.y) + float(j) * pas + 0.5) * CASE
		for i in [float(r.position.x), float(r.end.x)]:
			if alea.randf() < 0.06: continue
			v.ajouter_objet("urbain/construction-fence", i * CASE, z, PI * 0.5, H_GRILLAGE)

## Pose un bâtiment à la case donnée, s'il y a la place.
static func _poser(v: Ville2, modele: String, c: Vector2i, quarts: int, genre: String) -> bool:
	var e := KitVille2.emprise_tournee(modele, quarts)
	if not Lotisseur.terrain_libre(v, c.x * 2, c.y * 2, e): return false
	v.ajouter_lot(modele, c.x * 2, c.y * 2, e.x, e.y, quarts, genre)
	return true

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
	# ⚠ ET LA VOIE SE RÉSERVE, SINON ON BÂTIT DESSUS (« je vois des bâtiments
	# sur la voie de train », client, 14/09). `terrain_libre` ne connaît que les
	# routes, les pièces et les lots : un rail n'est aucun des trois, et deux
	# usines se sont donc posées à cheval sur les rails. On marque ses cases
	# dans le registre vivant AVANT la passe des parcelles.
	for i in v.taille.x:
		for j in [J_RAIL, J_RAIL + 1]:
			if j == J_RAIL + 1 and (i < 20 or i > 31): continue
			for b in 2:
				for a in 2:
					v.demi_prises[Vector2i(i * 2 + a, j * 2 + b)] = true

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
	# ⚠ LE COMPACTEUR EST UN MODÈLE DU CLIENT, ET C'EST LUI QUI NOMME LA CASSE.
	# Le cahier le cite explicitement (§ 3 : « casse auto (compacteur) ») et il
	# dormait dans `modeles/piksl/` sans qu'aucun générateur le pose.
	var m := "piksl/compacteur_voitures"
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
	# LA GRUE À TOUR (lot 3) : trente-cinq mètres de flèche. C'est la pièce la
	# plus haute du quartier et elle dit « chantier » de l'autre bout de la
	# carte — un tas de gravats, non.
	v.ajouter_objet("pxl/grue-tour", (float(r.position.x) + 3.0) * CASE,
		(float(r.position.y) + 2.5) * CASE, alea.randf() * TAU)
	v.ajouter_objet("pxl/grue-mobile", (float(r.position.x) + 6.5) * CASE,
		(float(r.position.y) + 4.2) * CASE, PI * 0.5)
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

## LA LIGNE HAUTE TENSION (lot 4). Une zone industrielle est alimentée, et
## c'est ce qui la relie au reste de la carte : une file de pylônes de
## vingt-huit mètres, alignée, qui traverse tout le quartier. Rien d'autre dans
## le kit ne donne cette échelle-là.
static func _les_pylones(v: Ville2, alea: RandomNumberGenerator) -> void:
	var j := float(J_ROCADE) - 1.35
	for k in 7:
		var x := (2.0 + float(k) * 5.5) * CASE
		var c := Vector2i(floori(x / CASE), floori(j))
		if not v.dedans(c) or v.lot_sur(c) >= 0: continue
		if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
		v.ajouter_objet("pxl/pylone-haute-tension", x, j * CASE, 0.0)
	# Le relais télécom, sur le point haut de la zone.
	v.ajouter_objet("pxl/pylone-telecom", (float(CASSE.end.x) + 0.6) * CASE,
		(float(CASSE.position.y) + 0.6) * CASE, 0.0)

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
	# LA CASERNE ET LE GARAGE DE PEINTURE, deux repères du client, sur la
	# rocade : les services de la zone (cahier § 8).
	for f in [["piksl/firestation", Vector2i(19, 13), "caserne", "Caserne de la Zone"],
			["piksl/garage_de_peinture", Vector2i(9, 25), "garage", "Garage du Fret"],
			["piksl/supermarket", Vector2i(6, 21), "supermarche", "Cash du Fret"]]:
		_poser_repere(v, String(f[0]), f[1], 0, String(f[2]), String(f[3]))
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

## Cherche une place pour un repère du client, en spirale autour du point voulu
## et dans les quatre orientations. Voir le même commentaire dans le générateur
## de banlieue : un repère qui abandonne au premier refus n'apparaît jamais, et
## rien ne le dit.
static func _poser_repere(v: Ville2, modele: String, depart: Vector2i, quarts: int,
		genre: String, nom: String, portee := 8) -> bool:
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
