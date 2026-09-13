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
## * les baraques peuvent se toucher et se chevaucher un peu — c'est voulu, un
##   bidonville se construit en s'appuyant sur le voisin ;
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
const AFFICHES := preload("res://commun/ville2/affiches.gd")

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
const BARAQUES := [
	{"m": "ville/building-garage", "h": 3.4},
	{"m": "batiments/low-detail-building-n", "h": 4.2},
	{"m": "industriel/building-c", "h": 3.8},
	{"m": "industriel/building-h", "h": 4.4},
	{"m": "industriel/building-i", "h": 3.6},
	{"m": "pavillons/building-type-c", "h": 4.0},
	{"m": "pavillons/building-type-l", "h": 3.8},
	{"m": "nature/tent_detailedOpen", "h": 2.4},
	{"m": "nature/tent_detailedClosed", "h": 2.4},
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
const SOUS_GRILLE := 3

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
	for c in sentes: v.poser_matiere(c, Ville2.M_ROCHE)
	_les_baraques(v, alea, sentes)
	_le_point_d_eau(v, alea)
	_details(v, alea, sentes)
	# Deux ou trois affiches en lisière, jamais dedans : ce sont les panneaux de
	# la route, et ils regardent ailleurs.
	AFFICHES.semer(v, alea, 150.0, [], 3)
	# Pas d'herbe : le sol est nu.
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
## MARQUANT DES CASES, et on s'en sert ensuite pour deux choses : n'y poser
## aucune baraque, et y semer les détails de passage.
##
## Rend l'ensemble des cases de sente.
static func _les_sentes(v: Ville2, alea: RandomNumberGenerator) -> Dictionary:
	var sentes: Dictionary = {}
	# Trois sentes qui partent de la route et serpentent vers le fond, plus
	# deux transversales. Elles zigzaguent d'une case tous les deux ou trois
	# pas : une sente droite serait une rue.
	for depart in [8, 18, 29]:
		var i: int = depart
		var j := J_ROUTE - 1
		while j > COEUR.position.y:
			for _k in alea.randi_range(2, 4):
				if j <= COEUR.position.y: break
				sentes[Vector2i(i, j)] = true
				j -= 1
			i = clampi(i + (1 if alea.randf() < 0.5 else -1), COEUR.position.x + 1,
				COEUR.end.x - 2)
			sentes[Vector2i(i, j)] = true
	for jj in [12, 24]:
		var i2 := COEUR.position.x + 1
		var j2: int = jj
		while i2 < COEUR.end.x - 1:
			for _k in alea.randi_range(2, 4):
				if i2 >= COEUR.end.x - 1: break
				sentes[Vector2i(i2, j2)] = true
				i2 += 1
			j2 = clampi(j2 + (1 if alea.randf() < 0.5 else -1), COEUR.position.y + 1,
				COEUR.end.y - 2)
			sentes[Vector2i(i2, j2)] = true
	return sentes

# ------------------------------------------------------------------ 4. les baraques

## ⚠ UNE BARAQUE N'EST PAS UN LOT. On sème des OBJETS, avec un angle quelconque
## et un chevauchement toléré : c'est la seule façon d'obtenir le désordre
## caractéristique. Deux garde-fous seulement — jamais sur une sente, jamais sur
## la route — parce qu'un bidonville est désordonné, pas impraticable.
static func _les_baraques(v: Ville2, alea: RandomNumberGenerator, sentes: Dictionary) -> void:
	for j in range(COEUR.position.y, COEUR.end.y):
		for i in range(COEUR.position.x, COEUR.end.x):
			var c := Vector2i(i, j)
			if sentes.has(c): continue
			if v.carte != null and v.carte.route(c): continue
			if c.distance_to(Vector2(POINT_D_EAU)) < 2.5: continue
			# ⚠⚠ IL EN FAUT BEAUCOUP PLUS QU'ON NE CROIT. Premier jet : une ou
			# deux baraques par case. Une baraque ramenée à quatre mètres fait
			# SIX MÈTRES DE CÔTÉ, une case en fait vingt : deux baraques n'en
			# couvrent qu'un cinquième, et le témoin est sorti en jouets semés
			# sur une plage. Un bidonville est mur à mur — il en faut de quoi
			# PAVER la case, soit une douzaine.
			#
			# On les pose donc sur une sous-grille de trois par trois, avec du
			# jeu : la sous-grille garantit la couverture, le jeu défait
			# l'alignement. Poser au hasard pur laisse des trous et des paquets.
			var proche := absf(float(j) - float(J_ROUTE)) < 18.0
			var densite := 0.86 if proche else 0.52
			for sj in SOUS_GRILLE:
				for si in SOUS_GRILLE:
					if alea.randf() > densite: continue
					var f: Dictionary = BARAQUES[alea.randi() % BARAQUES.size()]
					var pas := 1.0 / float(SOUS_GRILLE)
					v.ajouter_objet(String(f["m"]),
						(float(i) + (float(si) + 0.5) * pas
							+ alea.randf_range(-0.12, 0.12)) * CASE,
						(float(j) + (float(sj) + 0.5) * pas
							+ alea.randf_range(-0.12, 0.12)) * CASE,
						alea.randf() * TAU,
						float(f["h"]) * alea.randf_range(0.85, 1.25))

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
