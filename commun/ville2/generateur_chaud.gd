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
## * LES ENSEIGNES, en nombre — et NON les affiches. C'est la correction du
##   13/09, et elle porte sur l'objet, pas sur la quantité : l'accumulation
##   reste le sujet du quartier, mais ce qui s'accumule est l'ENSEIGNE (petite,
##   colorée, une par devanture, lisible à hauteur de trottoir) et non la PUB
##   (grande, mate, imprimée, qu'on lit depuis la voiture). Le client a compté
##   quatorze panneaux publicitaires et jugé « beaucoup trop de pub, pas assez
##   de néon » : quatre panneaux restent, sur l'artère, et des dizaines
##   d'enseignes les remplacent ;
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
const ATLAS := preload("res://commun/ville2/atlas.gd")
const AFFICHES := preload("res://commun/ville2/affiches.gd")
const NEONS := preload("res://commun/ville2/neons.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")

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
	"ville/building-small-b", "ville/building-small-c", "ville/building-small-d",
	"batiments/low-detail-building-e", "batiments/low-detail-building-h"]

## ⚠ LES DEUX IMMEUBLES AUX VITRES CONDAMNÉES (demande du client, 13/09 : « tu
## dois utiliser la variante A du kit modèle Industrial sur les 2 bâtiments qui
## ressemblent à des immeubles, vitres condamnées par des planches »).
##
## ⚠ LA VARIANTE A SUR LES DEUX, PAS A ET B. Premier jet : `building-a` et
## `building-b`, au motif que ce sont les deux seuls du kit industriel qui ont
## la silhouette d'un immeuble d'habitation. Mais la demande ne parle pas d'une
## famille, elle nomme UN modèle — c'est `building-a` que le client a regardé,
## et lui seul, dont l'atlas remplace le vitrage par du bardage à planches. Le
## `-b` est sa variante à bardage lisse : de loin on ne voit pas les planches,
## et la demande tombe à plat sur la moitié du sujet.
##
## La répétition ne gêne pas ici : deux barres identiques au bout de deux rues
## différentes se lisent comme un programme de logement, pas comme un copié-
## collé. On les pose à la main, pas dans la liste des pâtés : deux, pas douze.
## Une barre murée est un repère ; douze, c'est une friche.
const MURES := ["industriel/building-a", "industriel/building-a"]
const OU_MURES := [Vector2i(14, 21), Vector2i(25, 6)]
## Les chambres de motel : basses, alignées, toutes pareilles — c'est le
## principe d'un motel.
const CHAMBRES := ["pavillons/building-type-h", "pavillons/building-type-i",
	"pavillons/building-type-c", "pavillons/building-type-l"]
## ⚠ LES TROIS ENSEIGNES DU LOT 4, ET ELLES SONT DESSINÉES EN MÈTRES.
## Contrairement à tout le reste du dossier `pxl/`, taillé comme un kit Kenney
## (une unité = une case = 20 m), ces trois-là sont modélisés à l'échelle du
## monde. `KitVille2.echelle()` ne le sait pas : il voit `pxl/`, applique le
## facteur de la case, et le caisson de quatre mètres en fait QUATRE-VINGTS —
## une enseigne plus large que le pâté qu'elle surplombe. On leur impose donc
## TOUJOURS leur hauteur réelle en posant l'objet ; `h = 0` est interdit ici.
const ENSEIGNE_LETTRES := "pxl/enseigne-neon-lettres"
const ENSEIGNE_FLECHE := "pxl/enseigne-neon-fleche"
const ENSEIGNE_VERTICALE := "pxl/enseigne-neon-verticale"
const H_LETTRES := 1.4                    ## le caisson de façade, 4 × 1,4 m
const H_FLECHE := 2.0                     ## l'enseigne à flèche, 2,5 × 2 m
const H_VERTICALE := 6.0                  ## le panneau d'hôtel, 1,2 × 6 m

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
	_les_barres_murees(v, alea)
	v.rasteriser()
	_details(v, alea)
	# ⚠ LES REPÈRES DU CLIENT. Ce sont ses propres modèles, faits pour ce
	# jeu : un quartier qui n'en porte aucun se lit comme du Kenney tout nu.
	_poser_repere(v, "piksl/garage_de_peinture", Vector2i(24, 32), 0, "garage", "Garage du Mirage")
	_poser_repere(v, "piksl/firestation", Vector2i(15, 34), 0, "caserne", "Poste du Mirage")
	v.rasteriser()
	# ⚠ LA PUB NE SE POSE PLUS QUE SUR L'AXE, ET ON LES COMPTE SUR UNE MAIN.
	# Le client en a dénombré quatorze et tranché : « beaucoup trop de pub ».
	# Le compte venait pour l'essentiel des supports de LOT — toits et pignons
	# des clubs —, et dans une trame à pâtés de quatre cases il y en a partout :
	# un écart de 150 unités ne freine rien quand chaque pâté offre huit murs.
	#
	# On coupe donc la pub de lot à la racine en ne lui laissant qu'un genre
	# porteur, `casino` (un seul lot dans tout le quartier, et c'est le bon : le
	# panneau du casino au bout de l'artère se justifie tout seul), et on garde
	# QUATRE panneaux sur pieds, que `affiches.gd` ne plante que le long des
	# avenues. Total visé : quatre ou cinq, tous sur l'axe.
	AFFICHES.semer(v, alea, 220.0, ["casino"], 4)
	# Le fond lumineux : un caisson émissif dessiné en code sur chaque façade.
	# Il ne fait pas une enseigne à lui seul (voir `_les_enseignes`), mais c'est
	# lui qui met de la couleur sur les murs d'en face.
	NEONS.semer(v, alea, ["club", "casino", "hotel", "mure"], 0.85)
	# ... et par-dessus, les vraies enseignes : c'est elles que le client
	# réclame quand il écrit « pas assez de néon ».
	_les_enseignes(v, alea, ["club", "casino", "hotel", "mure", "motel"], 0.9)
	# ⚠ LA SALETÉ À FOND (« pas assez de poubelle, de saleté au sol », 13/09).
	# Le réglage précédent (0,7 façade sur deux genres, quatre déchets au plus)
	# laissait un trottoir sur trois parfaitement net — et un trottoir net au
	# milieu d'un quartier chaud se remarque plus qu'il n'y paraît. On sale
	# TOUTES les façades, meublés et motels compris, et on double la portée.
	PROPRETE.salir(v, alea, ["club", "mure", "hotel", "motel"], 1.0, 8)
	_les_poubelles(v, alea)
	# ⚠ PAS DE PASTELS ICI. Premier essai avec la gamme pavillonnaire : de nuit,
	# un mur lilas sous une lumière bleue devient violet fluo et les clubs
	# ressemblaient à des immeubles de dessin animé. Un quartier chaud est en
	# béton sale ; la couleur doit venir des ENSEIGNES, pas des façades.
	TEINTES.peindre_genres(v, alea, ["club", "mure"], TEINTES.INDUSTRIE, 0.35)
	# ⚠ AUCUNE TOITURE VERTE (client, 13/09). Voir `atlas.gd` : la bande
	# verte de l'atlas est repeinte par bâtiment, murs inchangés.
	TEINTES.couvrir(v, alea, "", ATLAS.VIEILLE)
	PROPRETE.finir(v, alea, 0)
	return v

# ------------------------------------------------------------------ les barres murées

static func _les_barres_murees(v: Ville2, alea: RandomNumberGenerator) -> void:
	for k in MURES.size():
		var m: String = MURES[k]
		var ou: Vector2i = OU_MURES[k]
		if not _poser_repere(v, m, ou, 0, "mure", "Barre murée %d" % (k + 1), 7):
			continue
		# Les planches sur les vitres du rez : des palettes empilées contre la
		# façade, et la benne de chantier qui n'est jamais repartie.
		for _n in 6:
			v.ajouter_objet("benne" if alea.randf() < 0.4 else "nourriture/barrel",
				(float(ou.x) + alea.randf_range(-1.0, 2.4)) * CASE,
				(float(ou.y) + alea.randf_range(-1.0, 2.4)) * CASE, alea.randf() * TAU)

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
	# Les bennes des ARRIÈRE-COURS — celles qu'on voit par-dessus les toits et
	# dans les dents creuses. Le trottoir, lui, est servi par `_les_poubelles` :
	# ce sont deux endroits différents, et il en faut aux deux.
	for k in 34:
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

# ------------------------------------------------------------------ 7. les enseignes

## LES VRAIES ENSEIGNES, ET C'EST LE CŒUR DE LA DEMANDE DU 13/09.
##
## ⚠ POURQUOI `NEONS.semer` NE SUFFISAIT PAS. La brique `neons.gd` pose sur
## chaque façade un caisson émissif dessiné en code : deux boîtes, une sombre,
## une colorée. C'est excellent comme FOND — ça met de la couleur sur les murs
## d'en face et ça coûte trois sommets —, mais ça ne se reconnaît pas. De nuit,
## quarante rectangles lumineux identiques se lisent comme un éclairage, pas
## comme une rue de bars. Ce qui fait l'enseigne, c'est la FORME qu'on nomme :
## des lettres au-dessus d'une devanture, une flèche en drapeau qui barre le
## trottoir, le panneau d'hôtel qui descend le long d'un angle. On garde donc
## les deux : le caisson en fond, les trois modèles par-dessus.
##
## ⚠ LA FAÇADE ET SON ORIENTATION SE CALCULENT COMME DANS `neons.gd`. C'est le
## travail difficile et il est déjà fait : la façade d'un modèle est son −Z,
## tournée de `q` quarts de tour, et elle ne porte une enseigne que si la case
## d'en face est de la chaussée. Refaire ce calcul autrement ici, c'est se
## garantir deux règles qui divergent au premier modèle ajouté au kit.
##
## ⚠ MAIS L'ANGLE, LUI, N'EST PAS LE MÊME. Le caisson de `neons.gd` est dessiné
## face à +Z (le renderer décale son tube de `base * (0, 0, 0.45)`) ; les trois
## modèles `pxl/`, comme toutes les pièces du dossier, regardent −Z. Reprendre
## tel quel le `atan2(facade.x, facade.y)` de `neons.gd` collerait donc chaque
## enseigne DOS À LA RUE, face au mur — invisible, et rien ne le signalerait.
## D'où le demi-tour : `atan2(−facade.x, −facade.y)`.
##
## ⚠ ET LE DRAPEAU DE VOIRIE. Une enseigne est en encorbellement au-dessus du
## trottoir, c'est-à-dire au-dessus de la chaussée : sans `voirie`, la passe
## `rien_sur_les_routes` les balaierait TOUTES à la dernière ligne du
## générateur, et l'image reviendrait exactement comme avant.
static func _les_enseignes(v: Ville2, alea: RandomNumberGenerator, genres: Array,
		densite := 0.9) -> int:
	if v.carte == null: return 0
	var poses := 0
	for l in v.lots:
		if not genres.has(String(l.get("genre", ""))): continue
		if alea.randf() > densite: continue
		var t := KitVille2.taille(String(l["m"]))
		var q := int(l["q"])
		var centre := v.centre_du_lot(l)
		var ici := Vector2i(floori(centre.x / CASE), floori(centre.z / CASE))
		var facade := Vector2i(0, -1)
		for _k in q: facade = Vector2i(facade.y, -facade.x)
		if not v.carte.route(ici + facade): continue
		# Le mur qui porte l'enseigne, la demi-profondeur qui la met dehors, et
		# la hauteur du bâtiment — tout en mètres.
		var mur: float = (t.x if q % 2 == 0 else t.z) * CASE
		var demi: float = (t.z if q % 2 == 0 else t.x) * CASE * 0.5
		var haut: float = t.y * CASE
		# Le long du mur, pour se ranger contre un angle plutôt qu'au milieu.
		var cote := Vector2i(-facade.y, facade.x)
		# L'angle qui met le −Z du modèle — sa face — vers la rue.
		var vers := atan2(float(-facade.x), float(-facade.y))
		var fiche := {}
		# ⚠ JAMAIS PLUS HAUT QUE LE BÂTIMENT, la même règle que `neons.gd` : une
		# enseigne de six mètres accrochée à huit sur une échoppe qui en fait
		# douze dépasse du toit et flotte. Chaque forme a donc son plancher de
		# hauteur bâtie, et son `dy` redescend si le mur est juste.
		if haut >= 30.0 and mur >= 12.0:
			# LA VERTICALE, plaquée sur l'ANGLE des bâtiments hauts : c'est sa
			# place naturelle — un panneau d'hôtel se lit depuis les deux rues
			# du coin, pas depuis la seule façade.
			var dx: float = maxf(mur * 0.5 - 1.6, 0.0)
			fiche = {"m": ENSEIGNE_VERTICALE, "h": H_VERTICALE, "r": vers,
				"x": centre.x + float(facade.x) * (demi + 0.4) + float(cote.x) * dx,
				"z": centre.z + float(facade.y) * (demi + 0.4) + float(cote.y) * dx,
				"dy": minf(8.0, haut - H_VERTICALE - 2.0)}
		elif haut >= 12.0 and alea.randf() < 0.45:
			# LA FLÈCHE EN DRAPEAU, perpendiculaire au mur et en encorbellement
			# au-dessus du trottoir : un quart de tour de plus que la façade,
			# sinon elle serait plaquée comme les autres et perdrait tout son
			# intérêt. Décalée vers un angle, là où on la voit en enfilade.
			var dxf: float = maxf(mur * 0.25, 0.0)
			fiche = {"m": ENSEIGNE_FLECHE, "h": H_FLECHE, "r": vers + PI * 0.5,
				"x": centre.x + float(facade.x) * (demi + 1.8) + float(cote.x) * dxf,
				"z": centre.z + float(facade.y) * (demi + 1.8) + float(cote.y) * dxf,
				"dy": minf(5.0, haut - H_FLECHE - 1.5)}
		elif haut >= 8.0:
			# LES LETTRES, en bandeau centré au-dessus de la devanture. C'est la
			# forme la plus modeste, donc celle qui reste quand le bâtiment est
			# trop bas pour les deux autres.
			fiche = {"m": ENSEIGNE_LETTRES, "h": H_LETTRES, "r": vers,
				"x": centre.x + float(facade.x) * (demi + 0.4),
				"z": centre.z + float(facade.y) * (demi + 0.4),
				"dy": minf(4.0, haut - H_LETTRES - 1.5)}
		else:
			continue
		fiche["voirie"] = true
		v.objets.append(fiche)
		poses += 1
	return poses

# ------------------------------------------------------------------ 8. la saleté

## ⚠ CE QUI MANQUAIT, C'EST LA POUBELLE DU TROTTOIR. `_details` en sème déjà sur
## les cases libres, mais une case libre dans cette trame est presque toujours
## un cœur d'îlot, où la caméra ne va jamais : le client traversait donc un
## quartier propre et disait « pas assez de poubelle » alors qu'il y en avait
## vingt-six. Une poubelle ne salit que si elle est SUR LE TRAJET — au caniveau,
## à portée du trottoir qu'on remonte. On longe donc les rues, toutes.
##
## Le caniveau est de la chaussée, mais `poubelle` et `benne` sont dans la
## liste blanche de la voirie (`proprete.gd`) : la passe finale les garde, comme
## elle garde les lampadaires. Rien à déclarer.
static func _les_poubelles(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in v.routes:
		var cases := Ville2.cases_de_route(r)
		if cases.size() < 4: continue
		for k in range(1, cases.size() - 1, 3):
			if alea.randf() > 0.45: continue
			var c: Vector2i = cases[k]
			# Le sens de la rue, pour savoir de quel côté est le caniveau : le
			# bord d'une rue est-ouest se compte en Z, et l'inverse.
			var d: Vector2i = cases[k + 1] - cases[k - 1]
			var bord: float = -0.36 if alea.randf() < 0.5 else 0.36
			var x := (float(c.x) + 0.5) * CASE
			var z := (float(c.y) + 0.5) * CASE
			if d.x != 0: z += bord * CASE
			else: x += bord * CASE
			v.ajouter_objet("benne" if alea.randf() < 0.3 else "poubelle",
				x, z, alea.randf() * TAU)

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
