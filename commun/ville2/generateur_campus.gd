class_name GenerateurCampus
extends RefCounted
## LE HUITIÈME QUARTIER TÉMOIN : LE CAMPUS, LE STADE ET LA FÊTE FORAINE
## (cahier § 3 : « campus / stade / parc d'attractions — stade avec parking et
## pelouse accessible, grande roue et manèges qui tournent, golf / hippodrome,
## volley et skatepark sur la plage »).
##
## ⚠ CE TÉMOIN EST FAIT DE TROIS GRANDS VIDES, ET C'EST SON SUJET. Tous les
## autres quartiers se remplissent : on borde les rues, on serre les maisons, on
## sème de l'herbe. Celui-ci se CREUSE — une pelouse de stade, un parvis de
## campus, une esplanade de fête foraine. Le générateur doit donc savoir faire
## quelque chose qu'aucun autre ne faisait : réserver de grandes surfaces et les
## défendre contre le lotisseur.
##
## Ses trois morceaux :
##
## * LE STADE, au nord : la pelouse, sa piste en terre battue, sa couronne de
##   gradins et son parking. Le kit n'a pas de tribune — c'est l'ANNEAU de
##   volumes bas tout autour qui la dessine, et il suffit ;
## * LE CAMPUS, à l'est : quatre grands bâtiments autour d'une pelouse
##   traversée d'allées, comme un quadrangle ;
## * LA FÊTE FORAINE, au sud-ouest : la grande roue (le jeu sait déjà la
##   fabriquer et la faire tourner — `RenduVille2` a une pièce `roue`), les
##   stands sous parasols, et la foule de bancs autour.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.

const ANGLES := preload("res://commun/ville2/angles.gd")
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const AFFICHES := preload("res://commun/ville2/affiches.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## LES TROIS GRANDS : le stade, le quadrangle du campus, l'esplanade foraine.
const STADE := Rect2i(11, 3, 18, 13)
## La pelouse, à l'intérieur de la couronne de gradins.
const PELOUSE := Rect2i(13, 5, 14, 9)
const CAMPUS := Rect2i(26, 20, 12, 12)
const FOIRE := Rect2i(3, 22, 13, 13)
## Le parking du stade, entre le stade et l'avenue.
const PARKING := Rect2i(3, 5, 6, 11)

## Les axes : une avenue qui longe le stade, une autre qui monte à l'est.
const J_AVENUE := 18
const X_AVENUE := 21

const PRENOMS := ["du Stade", "de l'Université", "des Facultés", "du Manège",
	"de la Foire", "des Étudiants", "du Vélodrome", "des Jeux"]

## Les bâtiments du campus : grands, larges, peu nombreux.
const FACULTES := ["batiments/building-l", "batiments/building-m", "batiments/building-n",
	"batiments/building-j", "batiments/building-i", "commerce/building-l"]
## Les gradins : des volumes bas et longs, posés en couronne. Ce ne sont pas
## des tribunes — c'est leur ALIGNEMENT qui fait la tribune.
const GRADINS := ["batiments/low-detail-building-wide-a", "batiments/low-detail-building-wide-b"]
## Les baraques de la foire et les vestiaires du stade.
const BARAQUES := ["ville/building-garage", "batiments/low-detail-building-n",
	"industriel/building-c", "industriel/building-h"]

## La couleur d'une pelouse de stade — un vert plus franc que l'herbe du
## terrain, parce qu'elle est tondue.
const VERT_PELOUSE := "#4e9b36"
## La terre battue de la piste.
const TEINTE_PISTE := "#b06a42"

static func generer(graine := 8, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-campus"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	_terrain(v)
	_quartiers(v)
	_rues(v)
	v.rasteriser()
	ANGLES.arrondir(v, alea, 0.6)
	v.rasteriser()
	_le_stade(v, alea)
	_le_campus(v, alea)
	v.rasteriser()
	_la_foire(v, alea)
	_details(v, alea)
	# ⚠ LES REPÈRES DU CLIENT. Ce sont ses propres modèles, faits pour ce
	# jeu : un quartier qui n'en porte aucun se lit comme du Kenney tout nu.
	_poser_repere(v, "piksl/hospital", Vector2i(31, 5), 0, "hopital", "CHU du Levant")
	_poser_repere(v, "piksl/supermarket", Vector2i(33, 34), 0, "supermarche", "Supérette du Campus")
	v.rasteriser()
	AFFICHES.semer(v, alea, 120.0, [], 4)
	PROPRETE.finir(v, alea, 2)
	return v

# ------------------------------------------------------------------ 1. le terrain

## De l'herbe partout, sauf les trois surfaces dures : le parking, le parvis du
## campus et l'esplanade de la foire.
static func _terrain(v: Ville2) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			var dur := PARKING.has_point(c) or FOIRE.has_point(c)
			v.poser_matiere(c, Ville2.M_DALLE if dur else Ville2.M_HERBE)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "Le Campus", "genre": Ville2.Q_CAMPUS, "gang": -1})
	v.quartiers.append({"nom": "Le Parc des Sports", "genre": Ville2.Q_PARC, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)
	v.peindre_quartier(STADE, 1)

# ------------------------------------------------------------------ 2. les rues

## ⚠ PEU DE RUES, ET AUCUNE QUI TRAVERSE LES GRANDS ÉQUIPEMENTS. C'est
## l'inverse du quartier chaud : là-bas la trame serrée faisait le sujet, ici
## c'est le vide. Deux avenues qui se croisent, une desserte autour du stade, et
## rien d'autre.
static func _rues(v: Ville2) -> void:
	var n := 0
	v.ajouter_route(Ville2.R_AVENUE,
		[Vector2i(0, J_AVENUE), Vector2i(v.taille.x - 1, J_AVENUE)],
		"Avenue du Stade")
	v.ajouter_route(Ville2.R_AVENUE,
		[Vector2i(X_AVENUE, 0), Vector2i(X_AVENUE, v.taille.y - 1)],
		"Avenue de l'Université")
	# La desserte du stade : elle en fait le tour par l'ouest et le nord.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(2, J_AVENUE - 1), Vector2i(2, 2),
		Vector2i(31, 2), Vector2i(31, J_AVENUE - 1)], "Rue " + PRENOMS[n])
	n += 1
	# L'entrée de la foire, et la boucle du campus.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(2, 36), Vector2i(36, 36)],
		"Rue " + PRENOMS[n % PRENOMS.size()])
	n += 1
	v.ajouter_route(Ville2.R_RUE, [Vector2i(36, 36), Vector2i(36, 20)],
		"Rue " + PRENOMS[n % PRENOMS.size()])

# ------------------------------------------------------------------ 3. le stade

## LE STADE. Trois anneaux emboîtés : la pelouse, la piste, les gradins.
##
## ⚠ LE KIT N'A PAS DE TRIBUNE, ET IL N'EN FAUT PAS. Ce qui fait lire un stade
## d'en haut, c'est la COURONNE FERMÉE autour d'un ovale vert — pas le détail
## des sièges. Une file de volumes bas posés bord à bord sur les quatre côtés
## suffit, et c'est le même principe que la clôture de parcelle en banlieue :
## la forme d'ensemble porte le sens, pas la pièce.
static func _le_stade(v: Ville2, alea: RandomNumberGenerator) -> void:
	# La piste, en terre battue, entre la pelouse et les gradins.
	for j in range(STADE.position.y + 1, STADE.end.y - 1):
		for i in range(STADE.position.x + 1, STADE.end.x - 1):
			var c := Vector2i(i, j)
			if PELOUSE.has_point(c): continue
			v.poser_matiere(c, Ville2.M_TERRE)
	# LA PELOUSE : une seule grande pièce plate, pas une case par case — c'est
	# la brique `pelouse` du rendu, celle des pelouses de la place du centre.
	var cx := (float(PELOUSE.position.x) + float(PELOUSE.size.x) * 0.5) * CASE
	var cz := (float(PELOUSE.position.y) + float(PELOUSE.size.y) * 0.5) * CASE
	v.ajouter_objet("pelouse", cx, cz, 0.0, 0.0, VERT_PELOUSE)
	v.objets[v.objets.size() - 1]["w"] = float(PELOUSE.size.x) * CASE
	v.objets[v.objets.size() - 1]["d"] = float(PELOUSE.size.y) * CASE
	# LA COURONNE DE GRADINS, sur les quatre côtés.
	for cote in ["n", "s", "o", "e"]:
		Lotisseur.aligner(v, alea, GRADINS, cote, _depart_du_cote(STADE, cote),
			(STADE.size.x * 2) if (cote == "n" or cote == "s") else (STADE.size.y * 2),
			"gradin", 1.0, 0)
	# Les mâts d'éclairage aux quatre coins : c'est ce qui se voit de loin.
	for sx in [0.6, float(STADE.size.x) - 0.6]:
		for sy in [0.6, float(STADE.size.y) - 0.6]:
			v.ajouter_objet("lampadaire_double", (float(STADE.position.x) + sx) * CASE,
				(float(STADE.position.y) + sy) * CASE, 0.0, 16.0)
	# Les vestiaires, contre le gradin sud.
	Lotisseur.aligner(v, alea, BARAQUES, "n",
		Vector2i(STADE.position.x * 2 + 4, (STADE.end.y + 1) * 2), 8 * 2, "vestiaire", 0.9, 1)
	# LE PARKING et ses voitures, en épis.
	for j in range(PARKING.position.y, PARKING.end.y):
		for i in range(PARKING.position.x, PARKING.end.x, 2):
			if alea.randf() > 0.72: continue
			var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
			v.ajouter_objet(m, (float(i) + alea.randf_range(0.3, 0.7)) * CASE,
				(float(j) + 0.5) * CASE, PI * 0.5)
	v.ajouter_lieu("stade", (float(STADE.position.x) + float(STADE.size.x) * 0.5) * CASE,
		(float(STADE.position.y) + float(STADE.size.y) * 0.5) * CASE,
		{"nom": "Stade Municipal"})

static func _depart_du_cote(r: Rect2i, cote: String) -> Vector2i:
	match cote:
		"n": return Vector2i(r.position.x * 2, r.position.y * 2)
		"s": return Vector2i(r.position.x * 2, r.end.y * 2)
		"o": return Vector2i(r.position.x * 2, r.position.y * 2)
		_: return Vector2i(r.end.x * 2, r.position.y * 2)

# ------------------------------------------------------------------ 4. le campus

## LE CAMPUS : un quadrangle. Quatre facultés autour d'une pelouse, des allées
## en diagonale — c'est la forme universitaire, de Cambridge à n'importe quel
## campus américain, et elle se lit d'en haut.
static func _le_campus(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := CAMPUS
	Lotisseur.border(v, r, alea, FACULTES, 0.9, "faculte")
	# La pelouse du quadrangle, au milieu.
	var dedans := r.grow(-3)
	var cx := (float(dedans.position.x) + float(dedans.size.x) * 0.5) * CASE
	var cz := (float(dedans.position.y) + float(dedans.size.y) * 0.5) * CASE
	v.ajouter_objet("pelouse", cx, cz, 0.0, 0.0, VERT_PELOUSE)
	v.objets[v.objets.size() - 1]["w"] = float(dedans.size.x) * CASE
	v.objets[v.objets.size() - 1]["d"] = float(dedans.size.y) * CASE
	# Les arbres d'alignement et les bancs autour de la pelouse.
	var arbres := ["arbre_oak", "arbre", "arbre_rond", "arbre_plateau"]
	for k in 14:
		var a := TAU * float(k) / 14.0
		v.ajouter_objet(arbres[alea.randi() % arbres.size()],
			cx + cos(a) * float(dedans.size.x) * 0.55 * CASE,
			cz + sin(a) * float(dedans.size.y) * 0.55 * CASE, alea.randf() * TAU)
		if k % 3 == 0:
			v.ajouter_objet("banc", cx + cos(a) * float(dedans.size.x) * 0.4 * CASE,
				cz + sin(a) * float(dedans.size.y) * 0.4 * CASE, -a + PI * 0.5)
	v.ajouter_objet("monument", cx, cz, 0.0)
	v.ajouter_lieu("campus", cx, cz, {"nom": "Université du Levant"})

# ------------------------------------------------------------------ 5. la foire

## LA FÊTE FORAINE (cahier § 3 : « grande roue et manèges qui tournent »).
##
## ⚠ LA GRANDE ROUE EXISTE DÉJÀ, ET ELLE TOURNE. `RenduVille2` sait fabriquer
## une pièce `roue` (elle est au bout de la jetée, dans le témoin de la plage) :
## on la réemploie telle quelle plutôt que d'empiler des modèles du kit. Le
## `w` de la fiche est son diamètre.
static func _la_foire(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := FOIRE
	var cx := (float(r.position.x) + float(r.size.x) * 0.5) * CASE
	var cz := (float(r.position.y) + float(r.size.y) * 0.45) * CASE
	v.ajouter_objet("roue", cx, cz, 0.0)
	v.objets[v.objets.size() - 1]["w"] = 62.0
	# Les stands, en deux allées face à face : c'est comme ça qu'une foire se
	# range, et l'allée entre les deux est ce qui la fait lire.
	for k in 7:
		for cote in [-1.0, 1.0]:
			var x: float = (float(r.position.x) + 2.0 + float(k) * 1.3) * CASE
			var z: float = cz + cote * 3.2 * CASE
			v.ajouter_objet("parasol" if (k + int(cote)) % 2 == 0 else "parasol_b",
				x, z, alea.randf() * TAU)
			if alea.randf() < 0.6:
				v.ajouter_objet("banc", x, z + cote * 0.6 * CASE,
					0.0 if cote > 0.0 else PI)
	# Les baraques du fond, et les poubelles.
	Lotisseur.aligner(v, alea, BARAQUES, "n",
		Vector2i(r.position.x * 2 + 2, (r.end.y - 2) * 2), (r.size.x - 2) * 2, "baraque", 0.8, 2)
	for k in 8:
		v.ajouter_objet("poubelle",
			(float(r.position.x) + alea.randf() * float(r.size.x)) * CASE,
			(float(r.position.y) + alea.randf() * float(r.size.y)) * CASE, 0.0)
	# Les guirlandes de lampadaires tout autour de l'esplanade.
	for i in range(r.position.x, r.end.x, 3):
		for j in [r.position.y, r.end.y - 1]:
			v.ajouter_objet("lampadaire_parc", (float(i) + 0.5) * CASE,
				(float(j) + 0.5) * CASE, 0.0)
	v.ajouter_lieu("foire", cx, cz, {"nom": "Fête Foraine du Levant"})

# ------------------------------------------------------------------ 6. les détails

static func _details(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in v.routes:
		var cases := Ville2.cases_de_route(r)
		var pas := 5 if String(r.get("genre", "")) == Ville2.R_AVENUE else 7
		for k in range(2, cases.size(), pas):
			var c: Vector2i = cases[k]
			v.ajouter_objet("lampadaire", (float(c.x) + 0.1) * CASE,
				(float(c.y) + 0.1) * CASE, 0.0)
	# Les arbres le long de l'avenue du stade : un campus est planté.
	var arbres := ["arbre", "arbre_oak", "arbre_rond", "arbre_petit", "arbre_plateau"]
	for i in range(2, v.taille.x - 2, 2):
		for j in [J_AVENUE - 1, J_AVENUE + 1]:
			var c := Vector2i(i, j)
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0 or v.matiere_de(c) != Ville2.M_HERBE: continue
			if alea.randf() > 0.6: continue
			v.ajouter_objet(arbres[alea.randi() % arbres.size()],
				(float(i) + alea.randf_range(0.3, 0.7)) * CASE,
				(float(j) + alea.randf_range(0.3, 0.7)) * CASE, alea.randf() * TAU)
	# Les vélos… le kit n'en a pas : des voitures d'étudiants le long de
	# l'avenue de l'Université, alors.
	for k in 10:
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, (float(X_AVENUE) + 0.82) * CASE,
			(2.0 + alea.randf() * 34.0) * CASE, 0.0)

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
