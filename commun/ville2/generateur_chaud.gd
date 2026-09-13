class_name GenerateurChaud
extends RefCounted
## LE SEPTIÈME QUARTIER TÉMOIN : LE QUARTIER CHAUD (cahier § 3 : « néons animés,
## casino visitable, clubs, bars, motels, rues étroites et foule la nuit »).
##
## ⚠ C'EST LE SEUL TÉMOIN QUI SE JUGE DE NUIT. Les six autres se photographient
## à midi ; celui-ci n'existe qu'allumé. Sa capture de référence se prend donc
## avec `--heure=0.72` — de jour, il n'est qu'un quartier dense de plus, et
## c'est normal : ce qui le distingue, ce sont les enseignes, les néons et les
## vitrines, pas le plan.
##
## Ce qui le fait, dans l'ordre d'importance :
##
## * LES AFFICHES, en nombre — c'est le seul quartier où l'on en veut trop.
##   Ailleurs on les espace (cahier § 7, et « il y a trop de panneaux en ville
##   et pas assez ailleurs ») ; ici leur accumulation EST le décor ;
## * les rues étroites : une trame serrée, des pâtés courts, beaucoup de
##   carrefours — on tourne à chaque coin ;
## * le casino, seul bâtiment haut, au bout de l'artère ;
## * les motels en U autour de leur parking, à l'écart de l'artère ;
## * les lampadaires à CHAQUE case de rue, et pas une sur quatre : la nuit se
##   dessine avec des points lumineux.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.

const ANGLES := preload("res://commun/ville2/angles.gd")
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const AFFICHES := preload("res://commun/ville2/affiches.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## L'ARTÈRE : la seule avenue, celle qu'on remonte en voiture le samedi soir.
const J_ARTERE := 19
## Les rues transversales, serrées : un pâté fait quatre cases, pas huit.
const PAS_RUES := 5
## ⚠ LE CASINO ET LES MOTELS ONT BESOIN D'UN ÎLOT À EUX, ET IL FAUT LE
## DÉCOUPER DANS LA TRAME. Premier jet : je les avais posés sur des rectangles
## choisis à vue, et la trame serrée (une rue toutes les cinq cases) les
## traversait de part en part — `terrain_libre` refusait, et NI LE CASINO NI
## TROIS DES QUATRE AILES DE MOTEL n'ont jamais existé. Rien ne le signalait :
## un lot refusé ne fait pas de bruit.
##
## On réserve donc de vrais SUPER-ÎLOTS : les rues qui les traverseraient
## s'arrêtent à leur bord (voir `_rues`). Un quartier a le droit d'avoir des
## îlots plus grands que les autres — c'est même ce qui fait un repère.
const CASINO := Rect2i(29, 20, 8, 8)
const MOTELS := [Rect2i(4, 5, 8, 8), Rect2i(4, 25, 8, 8)]
## Les îlots réservés, que la trame contourne.
const RESERVES := [CASINO, Rect2i(4, 5, 8, 8), Rect2i(4, 25, 8, 8)]

const PRENOMS := ["des Néons", "du Tripot", "de la Nuit", "des Enseignes", "du Mirage",
	"des Paillettes", "du Dernier Verre", "de la Roulette", "des Ombres", "du Trottoir"]

## Les bars, clubs et boutiques : des bâtiments moyens à rez-de-chaussée
## commercial, ceux du kit qui ont des auvents et des vitrines.
const CLUBS := ["batiments/building-c", "batiments/building-d", "batiments/building-e",
	"batiments/building-g", "batiments/building-a", "batiments/building-b",
	"batiments/building-h", "batiments/building-k", "batiments/building-f",
	"batiments/building-i", "batiments/building-j"]
## Les immeubles de rapport au-dessus des bars : hôtels de passe et meublés.
const MEUBLES := ["batiments/low-detail-building-wide-a", "batiments/low-detail-building-wide-b",
	"ville/building-small-b", "ville/building-small-c", "ville/building-small-d"]
## Les chambres de motel : basses, alignées, toutes pareilles — c'est le
## principe d'un motel.
const CHAMBRES := ["pavillons/building-type-h", "pavillons/building-type-i",
	"pavillons/building-type-c", "pavillons/building-type-l"]
## Les tours du fond : le casino et son hôtel.
const TOURS := ["batiments/building-skyscraper-a", "batiments/building-skyscraper-c",
	"batiments/building-skyscraper-e", "batiments/building-l", "batiments/building-m"]

static func generer(graine := 7, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-chaud"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	_terrain(v)
	_quartiers(v)
	_rues(v)
	v.rasteriser()
	ANGLES.arrondir(v, alea, 0.3)
	v.rasteriser()
	_les_pates(v, alea)
	_le_casino(v, alea)
	_les_motels(v, alea)
	v.rasteriser()
	_details(v, alea)
	# ⚠ ICI ON EN MET TROP, ET C'EST VOULU. L'écart est le plus court de tous
	# les témoins (40 contre 110 à 240 ailleurs) : dans ce quartier, la
	# surenchère d'affiches n'est pas un défaut de réglage, c'est le sujet.
	# ⚠ LES REPÈRES DU CLIENT. Ce sont ses propres modèles, faits pour ce
	# jeu : un quartier qui n'en porte aucun se lit comme du Kenney tout nu.
	_poser_repere(v, "piksl/garage_de_peinture", Vector2i(24, 32), 0, "garage", "Garage du Mirage")
	_poser_repere(v, "piksl/firestation", Vector2i(15, 34), 0, "caserne", "Poste du Mirage")
	v.rasteriser()
	AFFICHES.semer(v, alea, 40.0, [], 10)
	PROPRETE.finir(v, alea, 0)
	return v

# ------------------------------------------------------------------ 1. le terrain

static func _terrain(v: Ville2) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			v.poser_matiere(c, Ville2.M_DALLE)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "Le Mirage", "genre": Ville2.Q_CHAUD, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)

# ------------------------------------------------------------------ 2. les rues

static func _rues(v: Ville2) -> void:
	var n := 0
	# L'artère traverse tout : c'est la seule qui ne se laisse pas interrompre.
	v.ajouter_route(Ville2.R_AVENUE,
		[Vector2i(0, J_ARTERE), Vector2i(v.taille.x - 1, J_ARTERE)],
		"Avenue du Mirage")
	for jr in [4, 9, 14, 24, 29, 34]:
		for bout in _morceaux_libres(0, v.taille.x - 1, jr, true):
			v.ajouter_route(Ville2.R_RUE,
				[Vector2i(int(bout[0]), jr), Vector2i(int(bout[1]), jr)],
				"Rue " + PRENOMS[n % PRENOMS.size()])
		n += 1
	var x := 3
	while x < v.taille.x - 2:
		for bout in _morceaux_libres(2, v.taille.y - 3, x, false):
			v.ajouter_route(Ville2.R_RUE,
				[Vector2i(x, int(bout[0])), Vector2i(x, int(bout[1]))],
				"Rue " + PRENOMS[n % PRENOMS.size()])
		n += 1
		x += PAS_RUES

## ⚠ UNE RUE QUI RENCONTRE UN ÎLOT RÉSERVÉ S'ARRÊTE ET REPART DE L'AUTRE CÔTÉ.
## Elle ne le traverse pas, et elle ne disparaît pas non plus : elle le
## CONTOURNE, comme dans une vraie ville où un grand équipement coupe la trame.
## Rend la liste des morceaux [début, fin] à tracer. Un morceau de moins de deux
## cases n'est pas une rue, c'est un moignon : on le laisse tomber.
static func _morceaux_libres(debut: int, fin: int, fixe: int, horizontal: bool) -> Array:
	var coupe: Array = []
	for r in RESERVES:
		var a: int = (r.position.x if horizontal else r.position.y) - 1
		var b: int = (r.end.x if horizontal else r.end.y)
		var dedans: bool = (fixe >= r.position.y - 1 and fixe <= r.end.y) if horizontal \
			else (fixe >= r.position.x - 1 and fixe <= r.end.x)
		if dedans: coupe.append([a, b])
	coupe.sort_custom(func(p, q): return int(p[0]) < int(q[0]))
	var morceaux: Array = []
	var ici := debut
	for c in coupe:
		if int(c[0]) - ici >= 2: morceaux.append([ici, int(c[0])])
		ici = maxi(ici, int(c[1]))
	if fin - ici >= 2: morceaux.append([ici, fin])
	return morceaux

# ------------------------------------------------------------------ 3. les pâtés

## ⚠ LES CLUBS DONNENT SUR L'ARTÈRE, LES MEUBLÉS SUR LES RUES. Un quartier
## chaud a une géographie : la vitrine est sur l'axe passant, et tout ce qui se
## cache est un pâté derrière. Border les quatre côtés d'un pâté avec la même
## liste donnerait un quartier commerçant ordinaire.
static func _les_pates(v: Ville2, alea: RandomNumberGenerator) -> void:
	var x := 3
	while x < v.taille.x - 6:
		for bande in [[4, 9], [9, 14], [14, J_ARTERE], [J_ARTERE, 24], [24, 29], [29, 34]]:
			var r := Rect2i(x + 1, int(bande[0]) + 1, PAS_RUES - 1, int(bande[1]) - int(bande[0]) - 1)
			if r.size.x < 2 or r.size.y < 2: continue
			var reserve := false
			for res in RESERVES:
				if res.grow(1).intersects(r): reserve = true
			if reserve: continue
			var touche_artere := int(bande[0]) == J_ARTERE or int(bande[1]) == J_ARTERE
			var choix: Array = CLUBS if touche_artere else MEUBLES
			Lotisseur.border(v, r, alea, choix, 0.92, "club")
		x += PAS_RUES

# ------------------------------------------------------------------ 4. le casino

## LE CASINO (cahier § 3 : « casino visitable »). C'est le repère du quartier :
## le seul bâtiment haut, au bout de l'artère, avec son parvis et son parking.
static func _le_casino(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := CASINO
	var m: String = TOURS[0]
	var e := KitVille2.emprise_tournee(m, 0)
	if Lotisseur.terrain_libre(v, r.position.x * 2, r.position.y * 2, e):
		v.ajouter_lot(m, r.position.x * 2, r.position.y * 2, e.x, e.y, 0, "casino")
		v.ajouter_lieu("casino", (float(r.position.x) + 2.0) * CASE,
			(float(r.position.y) + 2.0) * CASE, {"nom": "Casino du Mirage"})
	# L'hôtel du casino, juste derrière.
	var m2: String = TOURS[1 + alea.randi() % 2]
	var e2 := KitVille2.emprise_tournee(m2, 0)
	if Lotisseur.terrain_libre(v, (r.position.x + 4) * 2, (r.position.y + 5) * 2, e2):
		v.ajouter_lot(m2, (r.position.x + 4) * 2, (r.position.y + 5) * 2, e2.x, e2.y, 0, "hotel")
	# Le parvis : des bornes, des lampadaires doubles et les voitures de luxe.
	for k in 8:
		v.ajouter_objet("borne", (float(r.position.x) - 0.4) * CASE,
			(float(r.position.y) + 0.5 + float(k)) * CASE, 0.0)
	for k in 4:
		v.ajouter_objet("lampadaire_double", (float(r.position.x) - 1.1) * CASE,
			(float(r.position.y) + 1.0 + float(k) * 2.4) * CASE, 0.0)
	for k in 6:
		var voiture: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(voiture, (float(r.position.x) - 2.0) * CASE,
			(float(r.position.y) + 0.8 + float(k) * 1.4) * CASE, PI * 0.5)

# ------------------------------------------------------------------ 5. les motels

## LE MOTEL EN U (cahier § 3 : « motels »). Trois ailes de chambres identiques
## autour d'un parking ouvert sur la rue — c'est la forme qui dit « motel »,
## pas le modèle de la chambre.
static func _les_motels(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in MOTELS:
		var m: String = CHAMBRES[alea.randi() % CHAMBRES.size()]
		# ⚠ LE MÊME MODÈLE POUR TOUTE L'AILE. C'est la seule fois du projet où
		# l'on VEUT la répétition : des chambres toutes différentes ne sont pas
		# un motel, ce sont des maisons.
		for cote in ["n", "o", "s"]:
			var q: int = Lotisseur.VERS[cote]
			var e := KitVille2.emprise_tournee(m, q)
			var pas: int = e.x if cote != "o" else e.y
			var long: int = (r.size.x * 2) if cote != "o" else (r.size.y * 2)
			var k := 0
			while k + pas <= long:
				var hx: int = r.position.x * 2 + (k if cote != "o" else 0)
				var hy: int = r.position.y * 2 + (k if cote == "o" else 0)
				if cote == "s": hy = r.end.y * 2 - e.y
				if Lotisseur.terrain_libre(v, hx, hy, e):
					v.ajouter_lot(m, hx, hy, e.x, e.y, q, "motel")
				k += pas
		# Le parking au milieu, et son enseigne.
		for k in 5:
			var voiture: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
			v.ajouter_objet(voiture,
				(float(r.position.x) + 4.0) * CASE,
				(float(r.position.y) + 1.5 + float(k) * 0.9) * CASE, PI * 0.5)
		v.ajouter_objet("lampadaire_double", (float(r.end.x) - 0.3) * CASE,
			(float(r.position.y) + float(r.size.y) * 0.5) * CASE, 0.0)
		v.ajouter_lieu("motel", (float(r.position.x) + 4.0) * CASE,
			(float(r.position.y) + 3.0) * CASE, {"nom": "Motel " + PRENOMS[alea.randi() % PRENOMS.size()]})

# ------------------------------------------------------------------ 6. les détails

## ⚠ UN LAMPADAIRE PAR CASE DE RUE, ET PAS UN SUR QUATRE. C'est le réglage qui
## fait la nuit : ailleurs on les espace pour ne pas surcharger, ici leur
## alignement serré dessine l'artère de loin quand tout le reste est noir.
static func _details(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in v.routes:
		var cases := Ville2.cases_de_route(r)
		var artere := String(r.get("genre", "")) == Ville2.R_AVENUE
		var pas := 2 if artere else 3
		for k in range(1, cases.size(), pas):
			var c: Vector2i = cases[k]
			v.ajouter_objet("lampadaire_double" if artere else "lampadaire",
				(float(c.x) + 0.1) * CASE, (float(c.y) + 0.1) * CASE, 0.0)
	# Les terrasses des bars, le long de l'artère.
	for i in range(3, v.taille.x - 3, 3):
		if alea.randf() > 0.6: continue
		var z := (float(J_ARTERE) + (0.12 if alea.randf() < 0.5 else 0.88)) * CASE
		v.ajouter_objet("parasol" if alea.randf() < 0.5 else "parasol_b",
			(float(i) + 0.5) * CASE, z, alea.randf() * TAU)
		v.ajouter_objet("banc", (float(i) + 0.9) * CASE, z, PI * 0.5)
	# Les poubelles et les bennes des arrière-cours : un quartier chaud est sale.
	for k in 26:
		var i := 2 + alea.randi() % (v.taille.x - 4)
		var j := 2 + alea.randi() % (v.taille.y - 4)
		var c := Vector2i(i, j)
		if v.carte != null and v.carte.route(c): continue
		if v.lot_sur(c) >= 0: continue
		v.ajouter_objet("benne" if alea.randf() < 0.5 else "poubelle",
			(float(i) + alea.randf()) * CASE, (float(j) + alea.randf()) * CASE,
			alea.randf() * TAU)
	# Les voitures garées le long de l'artère, des deux côtés.
	for k in 16:
		var i := 3 + alea.randi() % (v.taille.x - 6)
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, (float(i) + alea.randf_range(0.2, 0.8)) * CASE,
			(float(J_ARTERE) + (0.18 if alea.randf() < 0.5 else 0.82)) * CASE, PI * 0.5)
	# Les cabines téléphoniques, le détail qui date le quartier.
	for k in 4:
		var i := 4 + alea.randi() % (v.taille.x - 8)
		v.ajouter_objet("cabine", (float(i) + 0.15) * CASE,
			(float(J_ARTERE) + 0.85) * CASE, PI)

## Cherche une place pour un repère du client, en spirale autour du point voulu
## et dans les quatre orientations. Même règle partout : un repère qui abandonne
## au premier refus n'apparaît jamais, et rien ne le dit.
static func _poser_repere(v: Ville2, modele: String, depart: Vector2i, quarts: int,
		genre: String, nom: String, portee := 9) -> bool:
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
