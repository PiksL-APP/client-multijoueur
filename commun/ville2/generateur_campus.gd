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
const ATLAS := preload("res://commun/ville2/atlas.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")
const AFFICHES := preload("res://commun/ville2/affiches.gd")
const PARC := preload("res://commun/ville2/parc.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## ⚠⚠ LE PLAN A ÉTÉ REFAIT LE 13/09, ET LA RAISON TIENT EN UNE LIGNE : L'AVENUE
## NORD-SUD TRAVERSAIT LE STADE. `X_AVENUE` valait 21, le stade allait de 11 à
## 29 : la chaussée coupait la pelouse en deux et la couronne de gradins
## s'arrêtait de part et d'autre. D'en haut, on ne voyait pas un stade mais
## deux hangars blancs séparés par une route — d'où « tu dois faire un Stade »
## alors qu'un stade était bel et bien codé.
##
## La leçon : une ZONE RÉSERVÉE et un AXE se déclarent dans le même fichier,
## à dix lignes l'un de l'autre, et personne ne vérifie qu'ils ne se coupent
## pas. Le plan est donc réécrit en QUADRANTS, les deux avenues en croix au
## milieu, une grande pièce par quadrant, et plus rien ne peut se croiser.
##
##      bois  │  stade          (l'avenue passe entre les deux)
##     ───────┼───────
##     campus │ gymnase + foire
const J_AVENUE := 19
const X_AVENUE := 20

## LE BOIS, au nord-ouest : le « Parc / Forêt » demandé, bâti par `parc.gd`.
const BOIS := Rect2i(2, 2, 17, 16)
## LE STADE, au nord-est, entier dans son quadrant.
const STADE := Rect2i(22, 3, 16, 14)
## La pelouse, à l'intérieur de la couronne de gradins.
const PELOUSE := Rect2i(24, 5, 12, 10)
## LE CAMPUS, au sud-ouest.
const CAMPUS := Rect2i(2, 22, 15, 15)
## LE GYMNASE et LA FOIRE, au sud-est.
const GYMNASE := Rect2i(22, 22, 6, 8)
const FOIRE := Rect2i(29, 21, 9, 16)
## Le parking, sous le gymnase.
const PARKING := Rect2i(22, 31, 6, 5)

const PRENOMS := ["du Stade", "de l'Université", "des Facultés", "du Manège",
	"de la Foire", "des Étudiants", "du Vélodrome", "des Jeux"]

## Les bâtiments du campus : grands, larges, peu nombreux.
## ⚠ LA VARIANTE A DU KIT COMMERCIAL EN TÊTE (demande du client, 13/09 : « tu
## dois utiliser la variation A du kit modèle Commercial »). Le kit Commercial,
## c'est `kenney/batiments` — `modeles/commerce/` n'en est qu'une copie,
## vérifiée octet pour octet le même jour. `building-a` est donc le modèle
## nommé ; on le met deux fois dans le sac pour qu'il domine sans que le
## quadrangle devienne quatre fois le même bâtiment.
const FACULTES := ["batiments/building-a", "batiments/building-a", "batiments/building-b",
	"batiments/building-l", "batiments/building-m", "batiments/building-n",
	"batiments/building-j", "batiments/building-i", "batiments/building-h",
	"batiments/building-e"]
## Les gradins : des volumes bas et longs, posés en couronne. Ce ne sont pas
## des tribunes — c'est leur ALIGNEMENT qui fait la tribune.
const GRADINS := ["batiments/low-detail-building-wide-a", "batiments/low-detail-building-wide-b"]
## Les baraques de la foire et les vestiaires du stade.
const BARAQUES := ["ville/building-garage", "batiments/low-detail-building-n",
	"industriel/building-c", "industriel/building-h"]

## LE GYMNASE : une halle. Le kit n'a pas de gymnase, mais il a des halles
## industrielles — un volume long, bas, à toit plat, c'est exactement la
## silhouette d'un gymnase, et c'est ce qu'on reconnaît d'en haut.
const HALLE := "industriel/building-c"
## Les annexes du gymnase : vestiaires et local technique.
const ANNEXES := ["industriel/building-h", "industriel/building-d",
	"batiments/low-detail-building-n"]

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
	_le_gymnase(v, alea)
	v.rasteriser()
	# LE BOIS, au nord-ouest : le « Parc / Forêt » demandé le 13/09, bâti par
	# la brique commune — la même qui fait le parc du centre.
	PARC.dessiner(v, alea, BOIS, 3, [Vector2i(BOIS.end.x - 1, 9), Vector2i(10, BOIS.end.y - 1),
		Vector2i(BOIS.position.x, 6)])
	_la_foire(v, alea)
	_details(v, alea)
	# ⚠ LES REPÈRES DU CLIENT. Ce sont ses propres modèles, faits pour ce
	# jeu : un quartier qui n'en porte aucun se lit comme du Kenney tout nu.
	_poser_repere(v, "piksl/hospital", Vector2i(31, 5), 0, "hopital", "CHU du Levant")
	_poser_repere(v, "piksl/supermarket", Vector2i(33, 34), 0, "supermarche", "Supérette du Campus")
	v.rasteriser()
	AFFICHES.semer(v, alea, 120.0, [], 4)
	# ⚠ AUCUNE TOITURE VERTE (client, 13/09). Voir `atlas.gd` : la bande
	# verte de l'atlas est repeinte par bâtiment, murs inchangés.
	TEINTES.couvrir(v, alea, "", ATLAS.VIEILLE)
	PROPRETE.finir(v, alea, 4)
	return v

# ------------------------------------------------------------------ 1. le terrain

## De l'herbe partout, sauf les trois surfaces dures : le parking, le parvis du
## campus et l'esplanade de la foire.
static func _terrain(v: Ville2) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			var dur := PARKING.has_point(c) or GYMNASE.grow(1).has_point(c)
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
	# ⚠ LA DESSERTE LONGE LES GRANDES PIÈCES, ELLE NE LES TRAVERSE JAMAIS.
	# Chaque tracé ci-dessous passe dans la bande d'une case laissée libre
	# entre une zone réservée et le bord du quadrant.
	# Le tour du stade, par le nord et l'est.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(X_AVENUE + 1, 2), Vector2i(38, 2),
		Vector2i(38, J_AVENUE - 1)], "Rue " + PRENOMS[n])
	n += 1
	# La boucle du campus, par le sud et l'ouest.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(1, J_AVENUE + 1), Vector2i(1, 38),
		Vector2i(38, 38)], "Rue " + PRENOMS[n % PRENOMS.size()])
	n += 1
	# L'allée qui sépare le gymnase de la foire.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(28, J_AVENUE + 1), Vector2i(28, 37)],
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
	# ⚠ LES LIGNES BLANCHES. Une pelouse verte au milieu d'un anneau, ça peut
	# être un jardin ; ce qui dit « terrain de sport », c'est le tracé. Deux
	# surfaces blanches très fines posées par-dessus font la ligne médiane et
	# le rond central, et de la hauteur où l'on juge un témoin, ça suffit.
	v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0,
		"w": float(PELOUSE.size.x) * CASE * 0.86, "d": 0.8, "c": "#e8efe4"})
	v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0,
		"w": 18.0, "d": 18.0, "c": "#7fb35f"})
	# Les buts, aux deux bouts.
	for s2 in [-1.0, 1.0]:
		v.objets.append({"m": "pelouse", "x": cx, "z": cz + s2 * float(PELOUSE.size.y) * CASE * 0.42,
			"r": 0.0, "h": 0.0, "w": 42.0, "d": 0.8, "c": "#e8efe4"})
	# LA COURONNE DE GRADINS, sur les quatre côtés, SANS UN TROU. Un anneau
	# percé n'est pas un stade : c'est une rangée de hangars. La densité est
	# donc à 1,0 et l'écart à zéro, et `aligner` avance de l'emprise réelle.
	for cote in ["n", "s", "o", "e"]:
		Lotisseur.aligner(v, alea, GRADINS, cote, _depart_du_cote(STADE, cote),
			(STADE.size.x * 2) if (cote == "n" or cote == "s") else (STADE.size.y * 2),
			"gradin", 1.0, 0)
	# LA CASQUETTE DE TRIBUNE : une bande sombre posée en haut du gradin ouest,
	# le côté couvert. C'est ce qui, d'en haut, distingue la tribune d'honneur
	# du reste de l'anneau — tous les stades en ont une.
	v.objets.append({"m": "pelouse",
		"x": (float(STADE.position.x) + 0.9) * CASE,
		"z": (float(STADE.position.y) + float(STADE.size.y) * 0.5) * CASE,
		"r": 0.0, "h": 0.0, "w": 26.0, "d": float(STADE.size.y) * CASE * 0.62,
		"c": "#3b4149"})
	# Les mâts d'éclairage aux quatre coins : c'est ce qui se voit de loin.
	for sx in [0.6, float(STADE.size.x) - 0.6]:
		for sy in [0.6, float(STADE.size.y) - 0.6]:
			v.ajouter_objet("lampadaire_double", (float(STADE.position.x) + sx) * CASE,
				(float(STADE.position.y) + sy) * CASE, 0.0, 16.0)
	# Les vestiaires, dans la bande entre le stade et l'avenue.
	Lotisseur.aligner(v, alea, BARAQUES, "n",
		Vector2i(STADE.position.x * 2 + 4, (STADE.end.y) * 2), 10 * 2, "vestiaire", 0.9, 1)
	v.ajouter_lieu("stade", (float(STADE.position.x) + float(STADE.size.x) * 0.5) * CASE,
		(float(STADE.position.y) + float(STADE.size.y) * 0.5) * CASE,
		{"nom": "Stade Municipal"})

# ------------------------------------------------------------------ le gymnase

## LE GYMNASE (demande du client, 13/09). Une halle, ses annexes, son parvis et
## son parking — et un terrain extérieur à côté, parce qu'un gymnase sans
## terrain de plein air se lit comme un entrepôt.
static func _le_gymnase(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := GYMNASE
	var e := KitVille2.emprise_tournee(HALLE, 0)
	var hx := r.position.x * 2
	var hy := r.position.y * 2
	if Lotisseur.terrain_libre(v, hx, hy, e):
		v.ajouter_lot(HALLE, hx, hy, e.x, e.y, 0, "gymnase")
		v.ajouter_lieu("gymnase", (float(r.position.x) + 2.0) * CASE,
			(float(r.position.y) + 2.0) * CASE, {"nom": "Gymnase du Levant"})
	# Les annexes, en file au sud de la halle.
	Lotisseur.aligner(v, alea, ANNEXES, "n",
		Vector2i(r.position.x * 2, (r.position.y + 4) * 2), r.size.x * 2, "annexe", 0.9, 1)
	# LE TERRAIN DE PLEIN AIR, à l'est : une aire bleue avec ses lignes.
	var tx := (float(r.end.x) + 1.4) * CASE
	var tz := (float(r.position.y) + 2.0) * CASE
	v.objets.append({"m": "pelouse", "x": tx, "z": tz, "r": 0.0, "h": 0.0,
		"w": 2.0 * CASE, "d": 3.4 * CASE, "c": "#3f6f8c"})
	v.objets.append({"m": "pelouse", "x": tx, "z": tz, "r": 0.0, "h": 0.0,
		"w": 1.7 * CASE, "d": 0.8, "c": "#e8efe4"})
	for s2 in [-1.0, 1.0]:
		v.ajouter_objet("lampadaire_double", tx + s2 * 1.2 * CASE, tz + s2 * 1.8 * CASE,
			0.0, 12.0)
	for k in 6:
		v.ajouter_objet("banc", tx + 1.3 * CASE, tz + (float(k) - 2.5) * 0.5 * CASE, PI * 0.5)
	# LE PARKING, en épis, sous le gymnase.
	# ⚠ UN PARKING SE REMPLIT EN RANGS SERRÉS, PAS UNE VOITURE PAR DEUX CASES.
	# Une voiture fait 4,75 m et une case 20 : à une voiture toutes les deux
	# cases, il en tenait dix sur cent vingt mètres de large et la dalle
	# paraissait abandonnée. Quatre par case en largeur, deux rangs dos à dos
	# par bande, l'allée entre les bandes — c'est un vrai plan de parking.
	for j in range(PARKING.position.y, PARKING.end.y):
		for k in 4:
			for rang in [0.26, 0.60]:
				if alea.randf() > 0.78: continue
				var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
				v.ajouter_objet(m,
					(float(PARKING.position.x) + float(k) * 1.5 + rang * 0.3 + 0.4) * CASE,
					(float(j) + rang) * CASE, PI * 0.5)
	for j in range(PARKING.position.y, PARKING.end.y, 2):
		v.ajouter_objet("lampadaire", (float(PARKING.position.x) + 0.1) * CASE,
			(float(j) + 0.5) * CASE, 0.0)

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
	# ⚠ UN QUADRANGLE N'EST PAS UNE PELOUSE VIDE. Premier jet : quatre
	# bâtiments, un gazon au milieu, quatorze arbres en cercle — et le client
	# répond « pas assez d'éléments ». Un campus se vit dehors : il lui faut
	# ses allées, ses bosquets, ses bancs. On y passe donc la même brique que
	# pour le bois, en petit et sans étang.
	PARC.dessiner(v, alea, dedans.grow(1), 0, [], 0.55)
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
	# ⚠ L'ESPLANADE EST DE LA TERRE BATTUE, PAS DU BÉTON. Une dalle grise de
	# treize cases sur treize avec quatre objets dessus, c'est un parking de
	# supermarché — et c'est ce que le client a vu (« pas assez d'éléments »).
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			v.poser_matiere(c, Ville2.M_TERRE)
	var cx := (float(r.position.x) + float(r.size.x) * 0.5) * CASE
	var cz := (float(r.position.y) + 4.0) * CASE
	# ⚠ LA GRANDE ROUE DOIT ÊTRE GRANDE. À 62 unités de diamètre — trois cases,
	# soixante mètres — elle était juste. Elle ne se VOYAIT pas, parce qu'elle
	# était plantée seule au milieu d'une dalle de deux cent soixante mètres de
	# côté : un objet isolé au milieu d'un vide paraît petit, quelle que soit
	# sa taille. On la grandit ET on resserre la foire autour d'elle — c'est le
	# rapport qui compte, pas la cote.
	v.ajouter_objet("roue", cx, cz, 0.0)
	v.objets[v.objets.size() - 1]["w"] = 64.0
	# LES STANDS, en deux allées face à face, sur toute la longueur de
	# l'esplanade. C'est comme ça qu'une foire se range, et l'allée entre les
	# deux est ce qui la fait lire d'en haut.
	# ⚠ UN CHAPITEAU FAIT HUIT MÈTRES, PAS DEUX. La tente du kit nature est
	# dessinée pour le petit bonhomme : 2,20 m de haut. Posée telle quelle sur
	# une esplanade de trois cents mètres, elle est invisible — c'est la même
	# erreur que les baraques du bidonville, « des jouets sur une plage ». Une
	# fête foraine est faite de VOLUMES : on force donc la hauteur des
	# chapiteaux, et on les espace de ce que leur nouvelle taille demande.
	var chapiteaux := ["tente", "parasol", "parasol_b"]
	var hauteurs = [9.0, 7.0, 7.0]
	for k in 8:
		for cote in [-1.0, 1.0]:
			var z: float = (float(r.position.y) + 7.0 + float(k) * 1.15) * CASE
			var x: float = cx + cote * 1.9 * CASE
			var n := (k + int(cote) + 1) % chapiteaux.size()
			v.ajouter_objet(chapiteaux[n], x, z, alea.randf() * TAU,
				float(hauteurs[n]) * alea.randf_range(0.85, 1.15))
			if alea.randf() < 0.7:
				v.ajouter_objet("banc", x + cote * 0.75 * CASE, z, 0.0, 1.6)
			if alea.randf() < 0.6:
				v.ajouter_objet(["poubelle", "pot"][alea.randi() % 2],
					x + cote * 0.45 * CASE, z + 0.5 * CASE, alea.randf() * TAU, 2.2)
	# LES MANÈGES : le kit n'a pas de chevaux de bois, mais un anneau de tentes
	# serrées autour d'un mât fait un carrousel vu d'en haut, et une ronde de
	# barrières fait une auto-tamponneuse. Deux de chaque, aux quatre coins de
	# l'esplanade.
	for coin in [Vector2(2.2, 13.2), Vector2(6.6, 13.4), Vector2(6.6, 2.2)]:
		var mx: float = (float(r.position.x) + coin.x) * CASE
		var mz: float = (float(r.position.y) + coin.y) * CASE
		v.ajouter_objet("monument", mx, mz, 0.0, 14.0)
		for t in 10:
			var a := TAU * float(t) / 10.0
			v.ajouter_objet("tente", mx + cos(a) * 16.0, mz + sin(a) * 16.0, -a, 7.5)
			v.ajouter_objet("lampadaire_parc", mx + cos(a + 0.3) * 26.0,
				mz + sin(a + 0.3) * 26.0, 0.0)
	# Les baraques du fond, et les poubelles.
	Lotisseur.aligner(v, alea, BARAQUES, "n",
		Vector2i(r.position.x * 2 + 2, (r.end.y - 2) * 2), (r.size.x - 2) * 2, "baraque", 0.8, 2)
	for k in 24:
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
