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
## L'ENCEINTE du stade, en cases : la dalle de terre battue qui porte la piste
## et les gradins. Tout ce qui est dedans est réservé — aucun lot n'y entre.
const ENCEINTE := Rect2i(26, 7, 8, 6)
## LE TERRAIN, en MÈTRES et à la cote réelle : 120 × 80, centré dans l'enceinte.
const PELOUSE_M := Rect2(540.0, 160.0, 120.0, 80.0)
## LE CAMPUS, au sud-ouest.
const CAMPUS := Rect2i(2, 22, 15, 15)
## LE GYMNASE et LA FOIRE, au sud-est.
const GYMNASE := Rect2i(22, 22, 6, 8)
const FOIRE := Rect2i(29, 21, 9, 16)
## L'ESPLANADE de la foire, à l'intérieur : la dalle de terre battue serrée
## autour des manèges. Le reste de FOIRE reste en herbe.
const ESPLANADE := Rect2i(30, 22, 7, 13)
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
	_planter_le_reste(v, alea)
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
	# L'ENCEINTE, en terre battue : la bande qui porte la piste et les gradins.
	# ⚠ ELLE NE FAIT PLUS TOUT LE QUARTIER. Avant le lot 2, la « pelouse »
	# faisait 240 × 200 mètres — deux fois et demie un vrai terrain — et
	# l'anneau de gradins qui l'entourait se lisait comme une clôture. Un stade
	# se dessine À LA COTE RÉELLE : 120 × 80 pour l'aire de jeu, dix mètres de
	# piste, et des tribunes de vingt mètres qui font alors leur effet.
	for j in range(ENCEINTE.position.y, ENCEINTE.end.y):
		for i in range(ENCEINTE.position.x, ENCEINTE.end.x):
			var c := Vector2i(i, j)
			if v.carte != null and v.carte.route(c): continue
			v.poser_matiere(c, Ville2.M_TERRE)
	# ⚠ ET ON RÉSERVE LES CASES. Rien ne le faisait : un repère du client
	# (l'hôpital, au tirage 8) se posait au milieu du terrain, parce que
	# `terrain_libre` ne connaît que les lots et que le stade n'en est pas un.
	_reserver(v, ENCEINTE)
	var cx := PELOUSE_M.position.x + PELOUSE_M.size.x * 0.5
	var cz := PELOUSE_M.position.y + PELOUSE_M.size.y * 0.5
	# LA PELOUSE : une seule grande pièce plate, pas une case par case — c'est
	# la brique `pelouse` du rendu, celle des pelouses de la place du centre.
	v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0,
		"w": PELOUSE_M.size.x, "d": PELOUSE_M.size.y, "c": VERT_PELOUSE})
	# LE TRACÉ. Une pelouse verte au milieu d'un anneau, ça peut être un
	# jardin ; ce qui dit « terrain de football », c'est la ligne médiane, le
	# rond central, les deux surfaces de réparation et la touche.
	var blanc := "#e8efe4"
	# la touche : quatre bandes qui font le rectangle
	for s2 in [-1.0, 1.0]:
		v.objets.append({"m": "pelouse", "x": cx, "z": cz + s2 * (PELOUSE_M.size.y * 0.5 - 4.0),
			"r": 0.0, "h": 0.0, "w": PELOUSE_M.size.x - 8.0, "d": 0.6, "c": blanc})
		v.objets.append({"m": "pelouse", "x": cx + s2 * (PELOUSE_M.size.x * 0.5 - 4.0), "z": cz,
			"r": 0.0, "h": 0.0, "w": 0.6, "d": PELOUSE_M.size.y - 8.0, "c": blanc})
	# la médiane et le rond central
	v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0,
		"w": PELOUSE_M.size.x - 8.0, "d": 0.6, "c": blanc})
	v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0,
		"w": 18.0, "d": 18.0, "c": "#7fb35f"})
	# les deux surfaces de réparation
	for s2 in [-1.0, 1.0]:
		var zs: float = cz + s2 * (PELOUSE_M.size.y * 0.5 - 20.0)
		v.objets.append({"m": "pelouse", "x": cx, "z": zs, "r": 0.0, "h": 0.0,
			"w": 40.0, "d": 0.6, "c": blanc})
		for s3 in [-1.0, 1.0]:
			v.objets.append({"m": "pelouse", "x": cx + s3 * 20.0,
				"z": cz + s2 * (PELOUSE_M.size.y * 0.5 - 14.0), "r": 0.0, "h": 0.0,
				"w": 0.6, "d": 12.0, "c": blanc})
	# LA COURONNE DE TRIBUNES (lot 2, 14/09). Ce ne sont plus des hangars posés
	# bord à bord : ce sont de vraies tribunes, dessinées pour ça — gradins,
	# sièges, muret devant, mur arrière derrière, et les pièces d'angle qui
	# ferment les quatre coins. L'anneau n'a plus un seul trou, et de près il
	# tient aussi bien que de haut.
	_couronne_de_gradins(v)
	# LES BUTS, aux deux bouts du terrain, face au jeu.
	v.ajouter_objet("pxl/but-football", cx, PELOUSE_M.position.y + 5.0, PI)
	v.ajouter_objet("pxl/but-football", cx, PELOUSE_M.end.y - 5.0, 0.0)
	# LES MÂTS D'ÉCLAIRAGE aux quatre coins : dix-huit mètres, six projecteurs,
	# tournés vers le terrain. C'est ce qui se voit de loin, et c'est ce qui
	# dit « stade » avant même qu'on distingue les gradins.
	for coin in _coins_des_mats():
		v.ajouter_objet("pxl/mat-eclairage", coin.x, coin.y, _vise(coin, Vector2(cx, cz)))
	# LE TERRAIN D'ENTRAÎNEMENT, dans la bande libre au nord de l'enceinte.
	# Le stade ramené à sa vraie cote a libéré tout le tour : un club a
	# toujours un second terrain, et c'est ce qui remplit la bande.
	var ex := (float(STADE.position.x) + float(STADE.size.x) * 0.5) * CASE
	var ez := (float(STADE.position.y) + 2.0) * CASE
	v.objets.append({"m": "pelouse", "x": ex, "z": ez, "r": 0.0, "h": 0.0,
		"w": 96.0, "d": 52.0, "c": VERT_PELOUSE})
	# Sa touche, sinon le rectangle tondu se perd dans l'herbe du terrain.
	for s2 in [-1.0, 1.0]:
		v.objets.append({"m": "pelouse", "x": ex, "z": ez + s2 * 24.0, "r": 0.0, "h": 0.0,
			"w": 88.0, "d": 0.6, "c": "#e8efe4"})
		v.objets.append({"m": "pelouse", "x": ex + s2 * 44.0, "z": ez, "r": 0.0, "h": 0.0,
			"w": 0.6, "d": 48.0, "c": "#e8efe4"})
	v.objets.append({"m": "pelouse", "x": ex, "z": ez, "r": 0.0, "h": 0.0,
		"w": 0.6, "d": 48.0, "c": "#e8efe4"})
	v.ajouter_objet("pxl/but-football", ex - 40.0, ez, PI * 0.5)
	v.ajouter_objet("pxl/but-football", ex + 40.0, ez, -PI * 0.5)
	# Une file de gradins le long du terrain d'entraînement : celle des parents.
	for k in 3:
		v.ajouter_objet("pxl/tribune-droite", ex + (float(k) - 1.0) * 20.0, ez + 32.0, 0.0)
	for s2 in [-1.0, 1.0]:
		var m := Vector2(ex + s2 * 58.0, ez + 30.0)
		v.ajouter_objet("pxl/mat-eclairage", m.x, m.y, _vise(m, Vector2(ex, ez)))
	_reserver(v, Rect2i(STADE.position.x + 1, STADE.position.y, STADE.size.x - 2, 4))
	# LE PARKING DES SUPPORTERS, dans la bande est, et les caisses à l'entrée.
	# ⚠ UN STADE À LA COTE RÉELLE LAISSE DU VIDE AUTOUR DE LUI, et un quartier
	# vide est un défaut que le client a déjà relevé ailleurs. Ce qui remplit
	# le tour d'un stade, c'est ce qui sert à un jour de match : des voitures,
	# des caisses, des arbres.
	var px := ENCEINTE.end.x
	for j in range(ENCEINTE.position.y, ENCEINTE.end.y):
		for i in range(px, STADE.end.x - 1):
			v.poser_matiere(Vector2i(i, j), Ville2.M_DALLE)
	_reserver(v, Rect2i(px, ENCEINTE.position.y, STADE.end.x - 1 - px, ENCEINTE.size.y))
	for j in range(ENCEINTE.position.y, ENCEINTE.end.y):
		for k in 4:
			for rang in [0.26, 0.60]:
				if alea.randf() > 0.94: continue
				var mo: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
				v.ajouter_objet(mo, (float(px) + float(k) * 0.62 + 0.2) * CASE,
					(float(j) + rang) * CASE, PI * 0.5)
	for j in range(ENCEINTE.position.y, ENCEINTE.end.y, 2):
		v.ajouter_objet("lampadaire", (float(px) + 0.05) * CASE, (float(j) + 0.5) * CASE, 0.0)
	# Les caisses, contre le muret est, face au parking.
	for k in 4:
		v.ajouter_objet("pxl/caisse-foraine", MURET.end.x + 14.0,
			MURET.position.y + 16.0 + float(k) * 24.0, PI * 0.5)
	# Les arbres de la bande ouest : un stade de quartier est planté.
	var essences := ["arbre", "arbre_oak", "arbre_rond", "arbre_plateau"]
	for j in range(ENCEINTE.position.y, ENCEINTE.end.y):
		for i in range(STADE.position.x + 1, ENCEINTE.position.x):
			if alea.randf() > 0.5: continue
			v.ajouter_objet(essences[alea.randi() % essences.size()],
				(float(i) + alea.randf_range(0.2, 0.8)) * CASE,
				(float(j) + alea.randf_range(0.2, 0.8)) * CASE, alea.randf() * TAU)
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
	# ⚠ LE VRAI GYMNASE (lot 4, 14/09). Jusqu'ici c'était une halle industrielle
	# détournée : « un volume long, bas, à toit plat, c'est la silhouette d'un
	# gymnase ». De haut, oui ; de près, c'était un entrepôt. Le modèle du lot 4
	# fait trente mètres sur vingt-trois avec sa toiture à redents.
	var gx := (float(r.position.x) + 1.0) * CASE
	var gz := (float(r.position.y) + 1.2) * CASE
	v.ajouter_objet("pxl/gymnase", gx, gz, 0.0)
	_reserver(v, Rect2i(r.position.x, r.position.y, 2, 2))
	v.ajouter_lieu("gymnase", gx, gz, {"nom": "Gymnase du Levant"})
	# LA PISCINE MUNICIPALE (lot 4), derrière le gymnase : vingt-cinq mètres,
	# ses lignes d'eau et sa plage. C'est la deuxième pièce que le client
	# attendait d'un « parc des sports ».
	var pz := (float(r.position.y) + 3.1) * CASE
	v.objets.append({"m": "pelouse", "x": gx, "z": pz, "r": 0.0, "h": 0.0,
		"w": 46.0, "d": 30.0, "c": "#cfd6d2"})
	v.ajouter_objet("pxl/piscine-municipale", gx, pz, 0.0)
	for k in 8:
		v.ajouter_objet("parasol", gx - 18.0 + float(k) * 5.2, pz - 12.0, 0.0)
		v.ajouter_objet("banc", gx - 18.0 + float(k) * 5.2, pz + 12.0, PI)
	_reserver(v, Rect2i(r.position.x, r.position.y + 2, 3, 2))
	# Les annexes, en file au sud de la piscine.
	Lotisseur.aligner(v, alea, ANNEXES, "n",
		Vector2i(r.position.x * 2, (r.position.y + 5) * 2), r.size.x * 2, "annexe", 0.9, 1)
	# LE TERRAIN DE PLEIN AIR, à l'est : une aire bleue avec ses lignes.
	var tx := (float(r.end.x) + 1.4) * CASE
	var tz := (float(r.position.y) + 2.0) * CASE
	v.objets.append({"m": "pelouse", "x": tx, "z": tz, "r": 0.0, "h": 0.0,
		"w": 2.0 * CASE, "d": 3.4 * CASE, "c": "#3f6f8c"})
	v.objets.append({"m": "pelouse", "x": tx, "z": tz, "r": 0.0, "h": 0.0,
		"w": 1.7 * CASE, "d": 0.8, "c": "#e8efe4"})
	# LES DEUX PANIERS, aux deux bouts du terrain, face à face (lot 2). Un
	# rectangle bleu avec une ligne blanche, ça peut être n'importe quoi ; ce
	# sont les paniers qui disent « terrain de basket ».
	v.ajouter_objet("pxl/panier-basket", tx, tz - 1.5 * CASE, PI)
	v.ajouter_objet("pxl/panier-basket", tx, tz + 1.5 * CASE, 0.0)
	# LE TERRAIN DE VOLLEY, sur le sable, au sud du terrain bleu.
	var vz := tz + 2.6 * CASE
	v.objets.append({"m": "pelouse", "x": tx, "z": vz, "r": 0.0, "h": 0.0,
		"w": 1.0 * CASE, "d": 0.9 * CASE, "c": "#cdb98a"})
	v.ajouter_objet("pxl/filet-volley", tx, vz, 0.0)
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
				if alea.randf() > 0.94: continue
				var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
				v.ajouter_objet(m,
					(float(PARKING.position.x) + float(k) * 1.5 + rang * 0.3 + 0.4) * CASE,
					(float(j) + rang) * CASE, PI * 0.5)
	for j in range(PARKING.position.y, PARKING.end.y, 2):
		v.ajouter_objet("lampadaire", (float(PARKING.position.x) + 0.1) * CASE,
			(float(j) + 0.5) * CASE, 0.0)

# ------------------------------------------------- la couronne de tribunes

## LES TROIS PIÈCES DE GRADINS DU LOT 2, ET COMMENT ELLES S'EMBOÎTENT.
##
## Les trois modèles sont dessinés sur la même règle : ils REGARDENT −Z, leur
## muret (le petit mur de devant, côté terrain) est à z = −4 m, leur mur
## arrière à z = +4 m, et leurs dix rangs montent de 0 à 5,5 m entre les deux.
## Une droite fait 20 m de long, une couverte aussi (son auvent déborde d'un
## mètre à 10,5 m de haut, au-dessus de tout le reste), un angle fait 8 × 8 et
## ouvre son coin vers −X et −Z.
##
## On pose donc un RECTANGLE DE MURETS `MURET` : les droites s'alignent le long
## de ses quatre côtés, décalées de 4 m vers l'extérieur, et les angles tombent
## pile aux quatre intersections des deux lignes de centres. Pour que les
## droites tombent juste, il suffit que la largeur et la profondeur du
## rectangle soient des multiples de 20 — d'où les cotes ci-dessous.
const MURET := Rect2(530.0, 150.0, 140.0, 100.0)
## La demi-profondeur d'une tribune : du muret à son centre.
const RECUL := 4.0
## Le côté ouest est la TRIBUNE D'HONNEUR : couverte, plus haute, avec son
## auvent. Un stade n'en a qu'une, et c'est elle qui donne son sens à l'anneau.
const COTE_COUVERT := "o"

static func _couronne_de_gradins(v: Ville2) -> void:
	var x0 := MURET.position.x
	var x1 := MURET.end.x
	var z0 := MURET.position.y
	var z1 := MURET.end.y
	# Les quatre files de droites. `r` est le quart de tour qui met le muret
	# face au terrain : nord → demi-tour, est → un quart, ouest → moins un quart.
	var files := [
		{"cote": "n", "r": PI, "z": z0 - RECUL, "x": 0.0},
		{"cote": "s", "r": 0.0, "z": z1 + RECUL, "x": 0.0},
		{"cote": "o", "r": -PI * 0.5, "x": x0 - RECUL, "z": 0.0},
		{"cote": "e", "r": PI * 0.5, "x": x1 + RECUL, "z": 0.0},
	]
	for f in files:
		var cote := String(f["cote"])
		var modele: String = "pxl/tribune-couverte" if cote == COTE_COUVERT else "pxl/tribune-droite"
		var horizontal: bool = cote == "n" or cote == "s"
		var longueur: float = MURET.size.x if horizontal else MURET.size.y
		var depart: float = x0 if horizontal else z0
		var combien := int(longueur / 20.0)
		for k in combien:
			var le_long := depart + 10.0 + float(k) * 20.0
			if horizontal:
				v.ajouter_objet(modele, le_long, float(f["z"]), float(f["r"]))
			else:
				v.ajouter_objet(modele, float(f["x"]), le_long, float(f["r"]))
	# LES QUATRE ANGLES. Le modèle ouvre son coin vers −X et −Z : au repos il
	# est donc au coin sud-est (le terrain est chez lui vers −X et −Z), et
	# chaque quart de tour le fait passer au coin suivant.
	var angles := [
		{"x": x1 + RECUL, "z": z1 + RECUL, "r": 0.0},          # sud-est
		{"x": x1 + RECUL, "z": z0 - RECUL, "r": PI * 0.5},     # nord-est
		{"x": x0 - RECUL, "z": z0 - RECUL, "r": PI},           # nord-ouest
		{"x": x0 - RECUL, "z": z1 + RECUL, "r": PI * 1.5},     # sud-ouest
	]
	for a in angles:
		v.ajouter_objet("pxl/tribune-angle", float(a["x"]), float(a["z"]), float(a["r"]))

## Les quatre points de mât, juste en dehors des angles de l'anneau.
static func _coins_des_mats() -> Array:
	var out := []
	for sx in [MURET.position.x - 12.0, MURET.end.x + 12.0]:
		for sz in [MURET.position.y - 12.0, MURET.end.y + 12.0]:
			out.append(Vector2(sx, sz))
	return out

## L'angle qui met le devant d'un modèle (il regarde −Z) face à `cible`.
static func _vise(depuis: Vector2, cible: Vector2) -> float:
	var d := cible - depuis
	if d.length() < 0.001: return 0.0
	return atan2(-d.x, -d.y)

# ------------------------------------------------------------------ 4. le campus

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
	PARC.dessiner(v, alea, dedans.grow(1), 0, [], 0.95)
	# LA VIE DU CAMPUS (lot 3). Un quadrangle vide est une pelouse ; ce qui en
	# fait un campus, c'est ce qui s'y gare et ce qui s'y assoit — racks à
	# vélos pleins, bancs, abribus sur l'allée.
	for k in 10:
		var ax := cx + cos(TAU * float(k) / 10.0) * float(dedans.size.x) * CASE * 0.32
		var az := cz + sin(TAU * float(k) / 10.0) * float(dedans.size.y) * CASE * 0.32
		v.ajouter_objet("pxl/rack-velos", ax, az, TAU * float(k) / 10.0)
		for b in 5:
			v.ajouter_objet("pxl/velo", ax - 1.4 + float(b) * 0.7, az + 0.5,
				TAU * float(k) / 10.0 + PI * 0.5)
		v.ajouter_objet("banc", ax + 4.0, az, TAU * float(k) / 10.0)
		v.ajouter_objet("poubelle", ax + 6.0, az + 2.0, 0.0)
		if k % 3 == 0:
			v.ajouter_objet("pxl/abribus", ax - 7.0, az, TAU * float(k) / 10.0 + PI)
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
	# ⚠ L'ESPLANADE EST DE LA TERRE BATTUE, PAS DU BÉTON — et elle est SERRÉE.
	# Elle occupait tout le quartier : cent quatre-vingts mètres sur trois cent
	# vingt de dalle nue avec quatre objets dessus, c'est-à-dire exactement ce
	# que le client a vu (« pas assez d'éléments »). La leçon est la même qu'au
	# stade : on ne grossit pas les pièces, ON RÉTRÉCIT LE SOL jusqu'à ce que
	# les pièces le remplissent. Le reste du quartier redevient de l'herbe.
	var r := ESPLANADE
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			v.poser_matiere(c, Ville2.M_TERRE)
	_reserver(v, r)
	var cx := (float(r.position.x) + float(r.size.x) * 0.5) * CASE
	var cz := (float(r.position.y) + 2.4) * CASE
	# LA GRANDE ROUE, à l'entrée nord : soixante-quatre mètres, et cette fois
	# une esplanade à sa mesure autour d'elle.
	v.ajouter_objet("roue", cx, cz, 0.0)
	v.objets[v.objets.size() - 1]["w"] = 64.0
	# DEUX ALLÉES, QUATRE FILES DE STANDS (lot 2).
	# ⚠ CE NE SONT PLUS DES TENTES GONFLÉES. Jusqu'ici la foire était faite de
	# tentes du kit nature forcées à neuf mètres de haut et de « monuments »
	# entourés de parasols : de loin ça passait, de près c'était un bricolage.
	# Le lot 2 apporte les vraies pièces — baraque de tir, caisse, chapiteau,
	# carrousel, auto-tamponneuse — et elles sont à leur taille réelle. Une
	# baraque de tir fait trois mètres : ce qui fait la foire, ce n'est pas sa
	# taille, c'est qu'il y en ait SOIXANTE-DOUZE, alignées en files serrées.
	var z0 := (float(r.position.y) + 5.0) * CASE
	var ecart := 10.0
	var rangs := 13
	var bis := 1
	var allees := [cx - 36.0, cx + 36.0]
	for allee in allees:
		# Les deux caisses, à l'entrée de chaque allée : c'est par là qu'on paie.
		for cote in [-1.0, 1.0]:
			var cxx: float = float(allee) + float(cote) * 11.0
			if _sol_libre(v, cxx, z0 - 16.0):
				v.ajouter_objet("pxl/caisse-foraine", cxx, z0 - 16.0, 0.0)
		for k in rangs:
			var z: float = z0 + float(k) * ecart
			for cote in [-1.0, 1.0]:
				var x: float = float(allee) + float(cote) * 13.0
				if not _sol_libre(v, x, z): continue
				v.ajouter_objet("pxl/stand-forain", x, z, -float(cote) * PI * 0.5)
				# Une seconde file adossée à la première : c'est comme ça qu'une
				# foire se serre, dos à dos, et ça double la densité sans élargir
				# l'esplanade.
				v.ajouter_objet("pxl/stand-forain", x + float(cote) * 6.0, z,
					float(cote) * PI * 0.5)
				if k % 2 == 0:
					v.ajouter_objet("pxl/caisse-foraine", x + float(cote) * 3.0,
						z + ecart * 0.5, -float(cote) * PI * 0.5)
				if k % 4 == 1:
					v.ajouter_objet("lampadaire_parc", x + float(cote) * 6.0, z + ecart * 0.5, 0.0)
				if alea.randf() < 0.3:
					v.ajouter_objet("poubelle", x + float(cote) * 5.0, z - ecart * 0.4, 0.0)
	# LES GROSSES ATTRACTIONS, dans la bande centrale, entre les deux allées :
	# le carrousel, l'auto-tamponneuse, le chapiteau. Le carrousel porte un
	# nœud `plateau` — c'est lui qui tournera.
	var manèges := [
		{"m": "pxl/manege-carrousel", "z": z0 + 1.0 * ecart, "r": 0.0},
		{"m": "pxl/auto-tamponneuse", "z": z0 + 6.0 * ecart, "r": 0.0},
		{"m": "pxl/chapiteau", "z": z0 + 11.5 * ecart, "r": 0.0},
	]
	for m in manèges:
		v.ajouter_objet(String(m["m"]), cx, float(m["z"]), float(m["r"]))
		for t in 10:
			var a := TAU * float(t) / 10.0
			v.ajouter_objet("lampadaire_parc", cx + cos(a) * 13.0,
				float(m["z"]) + sin(a) * 13.0, 0.0)
	# Un second carrousel et un second chapiteau ferment l'esplanade au sud :
	# une foire n'a jamais un seul manège.
	var z_fond := z0 + float(rangs) * ecart + 14.0
	v.ajouter_objet("pxl/manege-carrousel", cx - 36.0, z_fond, 0.0)
	v.ajouter_objet("pxl/chapiteau", cx + 36.0, z_fond, 0.0)
	v.ajouter_objet("pxl/auto-tamponneuse", cx, z_fond + 2.0, 0.0)
	for k in 10:
		v.ajouter_objet("poubelle",
			(float(r.position.x) + alea.randf() * float(r.size.x)) * CASE,
			(float(r.position.y) + alea.randf() * float(r.size.y)) * CASE, 0.0)
	# Les guirlandes de lampadaires tout autour de l'esplanade.
	for i in range(r.position.x, r.end.x, 2):
		for j in [r.position.y, r.end.y - 1]:
			v.ajouter_objet("lampadaire_parc", (float(i) + 0.5) * CASE,
				(float(j) + 0.5) * CASE, 0.0)
	v.ajouter_lieu("foire", cx, cz, {"nom": "Fête Foraine du Levant"})

## Réserve un rectangle de cases dans le registre vivant des lots : plus rien ne
## viendra s'y poser.
static func _reserver(v: Ville2, zone: Rect2i) -> void:
	for j in range(zone.position.y * 2, zone.end.y * 2):
		for i in range(zone.position.x * 2, zone.end.x * 2):
			v.demi_prises[Vector2i(i, j)] = true

## Vrai si la case qui porte ce point n'est ni une route ni une case déjà prise.
static func _sol_libre(v: Ville2, x: float, z: float) -> bool:
	var c := Vector2i(int(floor(x / CASE)), int(floor(z / CASE)))
	if v.carte == null: return true
	return not (v.carte.route(c) or v.carte.case_prise(c))

# ------------------------------------------------------------------ 6. les détails

## ⚠ UN QUARTIER VIDE EST UN DÉFAUT, MÊME QUAND TOUT CE QU'IL FAUT Y EST
## (« j'aimerais que le campus soit plus rempli », client, 14/09). Le stade et
## la foire ramenés à leur vraie cote ont libéré des hectares d'herbe rase, et
## de l'herbe rase à côté d'un stade, ça se lit comme un terrain vague. On
## PLANTE donc tout ce qui reste libre : bosquets, haies et fourrés, denses au
## bord des routes, clairsemés au milieu.
static func _planter_le_reste(v: Ville2, alea: RandomNumberGenerator) -> void:
	var essences := ["arbre", "arbre_oak", "arbre_rond", "arbre_plateau", "arbre_automne",
		"pin", "pin_rond", "sapin", "arbre_petit"]
	var fourres := ["buisson", "buisson_grand", "buisson_petit", "rocher", "rocher_b",
		"fleurs_rouges", "fleurs_jaunes", "herbes", "touffe"]
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c) or v.matiere_de(c) != Ville2.M_HERBE: continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0 or not v.demi_libre(i * 2, j * 2, 2, 2): continue
			# Au bord d'une route, on plante serré : c'est ce qu'on voit en
			# roulant, et c'est ce qui cadre la voie.
			var longe := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if v.carte != null and v.dedans(c + d) and v.carte.route(c + d): longe = true
			for _k in (3 if longe else 2):
				if alea.randf() > (0.62 if longe else 0.26): continue
				v.ajouter_objet(essences[alea.randi() % essences.size()],
					(float(i) + alea.randf()) * CASE, (float(j) + alea.randf()) * CASE,
					alea.randf() * TAU)
			for _k in 3:
				if alea.randf() > 0.38: continue
				v.ajouter_objet(fourres[alea.randi() % fourres.size()],
					(float(i) + alea.randf()) * CASE, (float(j) + alea.randf()) * CASE,
					alea.randf() * TAU)

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
