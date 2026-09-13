class_name GenerateurVieilleVille
extends RefCounted
## LE SIXIÈME QUARTIER TÉMOIN : LA VIEILLE VILLE (cahier § 3 : « vieille ville
## — ruelles, pavés, église »).
##
## Les cinq premiers témoins ont éprouvé la ville dense, la côte, le relief, le
## pavillonnaire et l'industrie. Celui-ci éprouve LA RUELLE — c'est le seul
## quartier du cahier où la rue n'est pas un axe mais un interstice :
##
## * « pavés en vieille ville » (§ 5) → le sol est dallé d'un bord à l'autre,
##   il n'y a pas un brin d'herbe ;
## * « tracé : grille au centre, ORGANIQUE ailleurs » (§ 5) → aucune rue ne
##   traverse le quartier en ligne droite ; toutes sont des escaliers de tuiles
##   qui se coudent tous les trois ou quatre pas ;
## * « une grande place avec fontaine » (§ 3) → le parvis, devant l'église ;
## * « impasses partout où c'est utile » (§ 5) → une vieille ville en est
##   pleine, c'est même sa signature vue d'en haut.
##
## ⚠ CE QUI FAIT UNE VIEILLE VILLE, C'EST LA DENSITÉ, PAS LE STYLE DES MAISONS.
## Le kit n'a pas de colombages. Ce qui se lit d'en haut, c'est que les maisons
## SE TOUCHENT et que la rue est plus étroite que les bâtiments qui la bordent.
## On emploie donc les `low-detail-building-*` du kit bâtiments : mesurés, ils
## font UNE DEMI-CASE de côté (0,5 × 0,5) — deux fois plus étroits que tout le
## reste du catalogue. Posés bord à bord ils font un front continu, et une rue
## d'une case entre deux fronts paraît enfin une ruelle.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.

const ANGLES := preload("res://commun/ville2/angles.gd")
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const AFFICHES := preload("res://commun/ville2/affiches.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## LA PLACE DE L'ÉGLISE, le seul vide du quartier.
const PLACE := Rect2i(16, 17, 7, 6)

## ⚠ LES RUELLES SONT DES ESCALIERS, PAS DES LIGNES. Une rue droite d'un bout à
## l'autre est une rue de lotissement ; ce qui fait une vieille ville, c'est que
## la rue se décale tous les trois ou quatre pas. Le modèle refuse la diagonale
## (le kit ne sait pas la paver), donc chaque décalage est un coude à l'équerre
## — et `ANGLES.arrondir` passe derrière pour adoucir ceux qui peuvent l'être.
const RUELLES := [
	{"nom": "Rue des Lices", "pts": [[2, 6], [9, 6], [9, 9], [15, 9], [15, 6], [24, 6],
		[24, 10], [31, 10], [31, 6], [37, 6]]},
	{"nom": "Rue du Puits", "pts": [[2, 13], [7, 13], [7, 16], [13, 16], [13, 13],
		[20, 13], [20, 16], [27, 16], [27, 13], [37, 13]]},
	{"nom": "Rue Basse", "pts": [[2, 26], [10, 26], [10, 23], [17, 23], [17, 26],
		[26, 26], [26, 23], [33, 23], [33, 26], [37, 26]]},
	{"nom": "Rue du Rempart", "pts": [[2, 33], [37, 33]]},
	{"nom": "Ruelle des Teinturiers", "pts": [[6, 2], [6, 13]]},
	{"nom": "Ruelle du Change", "pts": [[12, 2], [12, 6], [11, 6], [11, 13]]},
	{"nom": "Ruelle Saint-Jean", "pts": [[20, 2], [20, 13]]},
	{"nom": "Ruelle des Orfèvres", "pts": [[28, 2], [28, 6], [29, 6], [29, 13]]},
	{"nom": "Ruelle du Beffroi", "pts": [[34, 2], [34, 13]]},
	{"nom": "Rue de l'Église", "pts": [[13, 16], [13, 23]]},
	{"nom": "Rue du Marché", "pts": [[25, 16], [25, 26]]},
	{"nom": "Ruelle Sombre", "pts": [[7, 16], [7, 26]]},
	{"nom": "Ruelle du Lavoir", "pts": [[31, 16], [31, 23]]},
	{"nom": "Rue du Bas", "pts": [[10, 26], [10, 33]]},
	{"nom": "Rue Neuve", "pts": [[19, 26], [19, 33]]},
	{"nom": "Rue de la Porte", "pts": [[30, 26], [30, 33]]},
]

## LES IMPASSES : la signature d'une vieille ville vue d'en haut.
const IMPASSES := [
	{"de": [16, 6], "vers": [0, 1], "long": 4},
	{"de": [23, 13], "vers": [0, -1], "long": 4},
	{"de": [4, 26], "vers": [0, -1], "long": 5},
	{"de": [35, 26], "vers": [0, -1], "long": 4},
	{"de": [22, 33], "vers": [0, -1], "long": 4},
	{"de": [15, 33], "vers": [0, -1], "long": 3},
]

## ⚠⚠ « LOW-DETAIL » VEUT DIRE PEU DE POLYGONES, PAS BAS. Premier jet : j'avais
## bâti tout le quartier avec les `batiments/low-detail-building-*` parce qu'ils
## font une DEMI-CASE de côté — la seule famille du catalogue assez étroite pour
## une ruelle. Mesuré ensuite : ils font DEUX CASES DE HAUT, soit quarante
## mètres. Le témoin est sorti en forêt de tours blanches, tout le contraire
## d'une vieille ville.
##
## La leçon vaut au-delà de ce fichier : l'emprise au sol ne dit rien de la
## hauteur, et le nom d'un modèle ne dit rien de sa taille. On mesure les deux.
##
## Ce qui fait une vieille ville, c'est un bâti BAS et SERRÉ. On prend donc ce
## que le catalogue a de plus bas — mesuré, entre 0,55 et 1,15 case de haut,
## soit onze à vingt-trois mètres — et on le colle bord à bord.
const MAISONS := ["batiments/low-detail-building-n", "batiments/low-detail-building-wide-a",
	"batiments/low-detail-building-wide-b", "ville/building-small-a",
	"pavillons/building-type-h", "pavillons/building-type-i", "pavillons/building-type-m",
	"pavillons/building-type-g", "pavillons/building-type-a", "pavillons/building-type-p",
	"pavillons/building-type-q"]
## Les plus basses encore : remises, ateliers, appentis. Elles cassent la ligne
## de toits, qui sans ça serait aussi régulière qu'un lotissement.
const BASSES := ["ville/building-garage", "batiments/low-detail-building-n",
	"pavillons/building-type-c", "pavillons/building-type-l"]
## ⚠ QUELQUES TOURS, ET SEULEMENT QUELQUES-UNES. Les `low-detail` hauts ne sont
## pas une erreur si on les emploie pour ce qu'ils sont : des tours de famille
## et des beffrois, comme à San Gimignano. Une sur vingt-cinq — au-delà, on
## retombe dans la forêt blanche.
const TOURS := ["batiments/low-detail-building-a", "batiments/low-detail-building-c",
	"batiments/low-detail-building-k", "batiments/low-detail-building-d"]
## Les bâtiments de belle taille : hôtels particuliers et halles.
const NOTABLES := ["ville/building-small-b", "ville/building-small-d",
	"batiments/building-k", "batiments/building-d", "batiments/building-c"]

static func generer(graine := 6, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-vieille-ville"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	_terrain(v)
	_quartiers(v)
	_rues(v)
	v.rasteriser()
	# ⚠ ON ARRONDIT PEU. Une vieille ville tourne à l'équerre : ses coudes sont
	# des angles de maison, pas des courbes de voirie. Une densité faible ne
	# garde que les virages les plus larges, là où il y avait vraiment la place.
	ANGLES.arrondir(v, alea, 0.22)
	v.rasteriser()
	_les_fronts(v, alea)
	v.rasteriser()
	_la_place(v, alea)
	v.rasteriser()
	_les_cours(v, alea)
	_details(v, alea)
	# ⚠ PEU D'AFFICHES ICI, ET AUCUNE AU BORD DES RUES. Une vieille ville en est
	# le contraire : ses murs portent des enseignes, pas des 4 × 3. On garde
	# quelques pignons, très espacés, et zéro panneau sur pieds — une ruelle n'a
	# pas la place, et ça jurerait.
	AFFICHES.semer(v, alea, 240.0, [], 0)
	# ⚠ PAS UN BRIN D'HERBE : le quartier est pavé d'un bord à l'autre, donc la
	# passe de remplissage n'a rien à faire ici. On lui passe zéro.
	PROPRETE.finir(v, alea, 0)
	return v

# ------------------------------------------------------------------ 1. le terrain

## ⚠ TOUT EST PAVÉ, ET C'EST LA DÉCISION QUI FAIT LE QUARTIER. Dans les autres
## témoins, le vide entre les rues est de l'herbe ou de la terre ; ici c'est de
## la pierre, jusque sous les maisons. Une vieille ville n'a pas de pelouse —
## elle a des cours, et les cours sont pavées.
static func _terrain(v: Ville2) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			v.poser_matiere(c, Ville2.M_DALLE)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "La Vieille Ville", "genre": Ville2.Q_VIEILLE_VILLE, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)

# ------------------------------------------------------------------ 2. les rues

static func _rues(v: Ville2) -> void:
	for r in RUELLES:
		var pts: Array = []
		for p in (r["pts"] as Array):
			pts.append(Vector2i(int(p[0]), int(p[1])))
		v.ajouter_route(Ville2.R_RUE, pts, String(r["nom"]))
	for k in IMPASSES.size():
		var im: Dictionary = IMPASSES[k]
		var de := Vector2i(int(im["de"][0]), int(im["de"][1]))
		var vers := Vector2i(int(im["vers"][0]), int(im["vers"][1]))
		v.ajouter_route(Ville2.R_RUE, [de, de + vers * int(im["long"])],
			"Impasse %d" % (k + 1))

# ------------------------------------------------------------------ 3. les fronts

## ⚠ ON BORDE LA RUE, ON NE LOTIT PAS DES PÂTÉS. Un pâté suppose qu'on sache où
## il commence et où il finit ; ici les ruelles se coupent n'importe où et les
## « pâtés » sont des morceaux de forme quelconque. On marche donc LE LONG DE
## CHAQUE RUE et on colle des maisons de chaque côté, bord à bord, tant qu'il y
## a la place. C'est exactement comme une vieille ville s'est construite.
static func _les_fronts(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in v.routes.duplicate():
		var cases := Ville2.cases_de_route(r)
		for cote in [1, -1]:
			_border(v, cases, cote, alea)

static func _border(v: Ville2, cases: Array, cote: int, alea: RandomNumberGenerator) -> void:
	var k := 1
	while k < cases.size() - 1:
		var a: Vector2i = cases[k - 1]
		var b: Vector2i = cases[k]
		var d: Vector2i = b - a
		if d == Vector2i.ZERO or (cases[mini(k + 1, cases.size() - 1)] - b) != d:
			k += 1
			continue
		var n := Vector2i(-d.y, d.x) * cote
		# Une maison sur dix est un notable, une sur cinq est basse : c'est ce
		# qui donne une ligne de toits irrégulière.
		var tirage := alea.randf()
		var choix: Array = MAISONS
		if tirage < 0.04: choix = TOURS
		elif tirage < 0.11: choix = NOTABLES
		elif tirage < 0.32: choix = BASSES
		var m: String = choix[alea.randi() % choix.size()]
		var q := _face_vers(-n)
		var e := KitVille2.emprise_tournee(m, q)
		# Le coin, en demi-cases, collé au bord de la case de rue : PAS DE
		# RECUL. C'est la différence entre une ruelle et une rue de banlieue.
		var cx := b.x * 2
		var cy := b.y * 2
		if n.x > 0: cx = (b.x + 1) * 2
		elif n.x < 0: cx = b.x * 2 - e.x
		if n.y > 0: cy = (b.y + 1) * 2
		elif n.y < 0: cy = b.y * 2 - e.y
		if Lotisseur.terrain_libre(v, cx, cy, e) and alea.randf() < 0.97:
			v.ajouter_lot(m, cx, cy, e.x, e.y, q, "vieille")
			k += maxi(1, (e.x if d.x != 0 else e.y) / 2)
		else:
			k += 1

static func _face_vers(sens: Vector2i) -> int:
	if sens == Vector2i(0, -1): return 0
	if sens == Vector2i(1, 0): return 3
	if sens == Vector2i(0, 1): return 2
	return 1

# ------------------------------------------------------------------ 4. la place

## LA PLACE DE L'ÉGLISE (cahier § 3 : « une grande place avec fontaine »). C'est
## le seul vide du quartier, et il n'en faut qu'un : deux places dans une
## vieille ville, et ce n'est plus une vieille ville.
static func _la_place(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := PLACE
	# L'église, au fond de la place, tournée vers elle.
	_poser_repere(v, "piksl/eglise", Vector2i(r.position.x + 2, r.position.y - 2), 2,
		"eglise", "Église Saint-Jean")
	# LA FONTAINE, au milieu : le modèle du kit ville, posé à l'échelle de la
	# case (c'est une pièce de sol, elle pave son carré).
	var fx := (float(r.position.x) + float(r.size.x) * 0.5) * CASE
	var fz := (float(r.position.y) + float(r.size.y) * 0.5) * CASE
	v.ajouter_objet("res://modeles/ville/pavement-fountain.glb", fx, fz, 0.0)
	# Les bancs autour, tournés vers la fontaine, et les lampadaires aux coins.
	for k in 6:
		var a := TAU * float(k) / 6.0
		v.ajouter_objet("banc", fx + cos(a) * 1.4 * CASE, fz + sin(a) * 1.2 * CASE,
			-a + PI * 0.5)
	for sx in [0.5, float(r.size.x) - 0.5]:
		for sy in [0.5, float(r.size.y) - 0.5]:
			v.ajouter_objet("lampadaire_parc", (float(r.position.x) + sx) * CASE,
				(float(r.position.y) + sy) * CASE, 0.0)
	# LES ÉTALS DU MARCHÉ : des parasols serrés le long du bord est de la place.
	for k in 7:
		v.ajouter_objet("parasol" if k % 2 == 0 else "parasol_b",
			(float(r.end.x) - 0.6) * CASE,
			(float(r.position.y) + 0.6 + float(k) * 0.75) * CASE, alea.randf() * TAU)
	v.ajouter_lieu("place", fx, fz, {"nom": "Place de la Fontaine"})

## Cherche une place pour un repère du client, en spirale et dans les quatre
## orientations (même règle que dans les autres générateurs : un repère qui
## abandonne au premier refus n'apparaît jamais, et rien ne le dit).
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

## ⚠ LE CŒUR DES ÎLOTS EST UNE COUR, PAS LA PLACE. Premier jet : le quartier
## était pavé d'un bord à l'autre et on ne bordait que les rues — tout ce qui
## restait entre les fronts gardait donc le pavé de la voirie, et le témoin
## sortait avec une esplanade grise de quinze cases au milieu. Vu d'en haut, on
## ne distinguait plus la rue de ce qui n'en était pas.
##
## Une vieille ville a des COURS : de la terre battue, des remises, un puits.
## On repeint donc en terre tout ce qui n'est ni rue, ni bâti, ni la place — et
## le réseau des ruelles se lit enfin, parce qu'il est le seul pavé.
static func _les_cours(v: Ville2, alea: RandomNumberGenerator) -> void:
	var cour := ["pot", "buisson_petit", "tas_de_bois", "caillou", "benne", "poubelle"]
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c): continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0: continue
			if PLACE.has_point(c): continue
			v.poser_matiere(c, Ville2.M_TERRE)
			if alea.randf() < 0.45:
				v.ajouter_objet(cour[alea.randi() % cour.size()],
					(float(i) + alea.randf_range(0.2, 0.8)) * CASE,
					(float(j) + alea.randf_range(0.2, 0.8)) * CASE, alea.randf() * TAU)

# ------------------------------------------------------------------ 5. les détails

## ⚠ LE MOBILIER FAIT LA MOITIÉ DU QUARTIER. Des maisons collées ne suffisent
## pas : ce sont les lampadaires à chaque coin, les bornes qui empêchent de se
## garer dans la ruelle et les pots devant les portes qui font qu'on y croit.
static func _details(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in v.routes:
		var cases := Ville2.cases_de_route(r)
		for k in range(1, cases.size(), 4):
			var c: Vector2i = cases[k]
			# Le lampadaire se plaque au coin de la case, contre les façades.
			v.ajouter_objet("lampadaire_parc", (float(c.x) + 0.08) * CASE,
				(float(c.y) + 0.08) * CASE, 0.0)
		# Les bornes, une case sur trois, du côté opposé.
		for k in range(2, cases.size(), 3):
			if alea.randf() > 0.5: continue
			var c: Vector2i = cases[k]
			v.ajouter_objet("borne", (float(c.x) + 0.9) * CASE,
				(float(c.y) + 0.9) * CASE, 0.0)
	# Les pots et les bacs devant les portes : le kit nature, à l'échelle.
	for l in v.lots:
		if String(l.get("genre", "")) != "vieille": continue
		if alea.randf() > 0.35: continue
		var c := v.centre_du_lot(l)
		var q := int(l["q"])
		var face: Vector2 = [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0)][q % 4]
		var portee := (float(l["h"]) if absf(face.y) > 0.5 else float(l["w"])) * DEMI * 0.5 + 1.6
		var pot := ["pot", "buisson_petit", "fleurs_rouges", "fleurs_jaunes"]
		v.ajouter_objet(pot[alea.randi() % pot.size()],
			c.x + face.x * portee + alea.randf_range(-3.0, 3.0),
			c.z + face.y * portee + alea.randf_range(-3.0, 3.0), alea.randf() * TAU)
	# Quelques voitures, garées de travers : une ruelle n'a pas de places.
	for k in 12:
		var r2: Dictionary = v.routes[alea.randi() % v.routes.size()]
		var cases2 := Ville2.cases_de_route(r2)
		if cases2.size() < 4: continue
		var c: Vector2i = cases2[2 + alea.randi() % (cases2.size() - 3)]
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, (float(c.x) + alea.randf_range(0.35, 0.65)) * CASE,
			(float(c.y) + alea.randf_range(0.35, 0.65)) * CASE,
			alea.randf() * TAU)
