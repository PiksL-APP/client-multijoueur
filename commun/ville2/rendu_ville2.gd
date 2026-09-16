class_name RenduVille2
extends RefCounted
## LE RENDU DE LA VILLE V2 : un `Ville2` entre, un `Node3D` sort.
##
## Une seule règle : TOUT VIENT DU KIT, À SON ÉCHELLE. Une tuile de route est
## posée telle quelle, une unité Kenney = une case (20 unités 3D). Un bâtiment
## est posé tel quel à la même échelle, au centre de son lot. Rien n'est
## étiré. Les props (lampadaires, arbres…) viennent de kits à d'autres
## échelles : ils sont mis à la hauteur que le jeu leur donne déjà.
##
## Le sol : chaque case de terre reçoit une dalle `tile-low` du kit (le
## trottoir du kit, au ras des tuiles de route) ou, sur une rue, la tuile de
## route que `CarteVille.tuile()` désigne — la table de pavage mesurée au banc.
## Les tuiles AJOURÉES (voir `CarteVille.AJOUREES`) reçoivent une dalle dessous.

## ⚠ `preload` ET PAS LE NOM DE CLASSE : un `class_name` créé après coup
## n'existe pas dans l'export web (il n'est inscrit que dans le cache de
## l'éditeur, que le workflow d'export ne régénère pas).
const ANGLES := preload("res://commun/ville2/angles.gd")

const CASE := Ville2.CASE
const PALIER := Ville2.PALIER
const ROUTES := "res://modeles/kenney/routes/"
## Le relief d'une tuile du kit (0,02 unité Kenney) : la dalle passe dessous.
const EPAISSEUR_TUILE := 0.02 * CASE
## La dalle des pâtés, un rien plus sombre que le trottoir blanc du kit : sans
## ça, une ville entière sort d'un seul blanc et rien ne se détache.
const TEINTE_DALLE := Color("#d9d6cf")
const TEINTE_RAIL := Color("#8c8f96")
const TEINTE_TRAVERSE := Color("#5b4a3a")

static var _matieres: Dictionary = {}
static var inventaire := false
static var poses: Dictionary = {}          ## chemin -> nombre de poses (banc)

## Les passes, pour bâtir un morceau en plusieurs images (voir `MorceauxV2`).
enum { P_SOLS = 1, P_LOTS = 2, P_OBJETS = 4, P_RAIL = 8 }
const P_TOUT := 15
const PASSES := [P_SOLS, P_LOTS, P_OBJETS | P_RAIL]

## Bâtit la ville entière, ou la seule `zone` (en cases) si elle est donnée.
## `racine` non nulle : on CONTINUE un morceau commencé, passe par passe.
static func batir(ville: Ville2, zone: Rect2i = Rect2i(), passes: int = P_TOUT,
		racine: Node3D = null) -> Node3D:
	if ville.carte == null:
		ville.rasteriser()
	if racine == null:
		racine = Node3D.new()
		racine.name = "VilleV2"
	if zone.size == Vector2i.ZERO:
		zone = Rect2i(Vector2i.ZERO, ville.taille)
	if passes & P_SOLS:
		_poser_terrain(racine, ville, zone)
		_poser_sols(racine, ville, zone)
		_poser_soutenements(racine, ville, zone)
		_poser_ouvrages(racine, ville, zone)
	if passes & P_LOTS: _poser_lots(racine, ville, zone)
	if passes & P_OBJETS: _poser_objets(racine, ville, zone)
	if passes & P_RAIL: _poser_rail(racine, ville, zone)
	return racine

# ------------------------------------------------------------------ le sol

static func _poser_sols(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	var carte := ville.carte
	# ⚠⚠ LES RONDS-POINTS SE CALCULENT UNE FOIS, PAS PAR CASE. La règle demande
	# de comparer un candidat à tous ceux d'un rayon de quatre cases ; appelée
	# depuis la boucle, et une seconde fois pour les huit voisines de chaque
	# case, elle coûtait six cents examens PAR CASE DE RUE — des millions sur
	# une fenêtre, et le triple sur une grande. On balaie donc la zone une fois,
	# élargie d'une case pour attraper un rond-point dont le centre est juste
	# dehors et dont un bras entre dans la vue.
	var ronds := {}
	var large := zone.grow(1)
	for j0 in range(large.position.y, large.end.y):
		for i0 in range(large.position.x, large.end.x):
			var c0 := Vector2i(i0, j0)
			if _rond_point_ici(ville, c0): ronds[c0] = true
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			# Une case de terrain (herbe, sable, terre, roche) est portée par le
			# maillage continu, pas par une dalle du kit.
			if not carte.terre(c) or not ville.plate(c): continue
			var y := float(carte.palier(c)) * PALIER
			var centre := Vector3((float(i) + 0.5) * CASE, y, (float(j) + 0.5) * CASE)
			# ⚠ PLUS DE DALLE DE BOUCHAGE SOUS LES TUILES AJOURÉES. Le maillage
			# du terrain couvre désormais les cases plates : il passe sous la
			# tuile, bouche sa rainure et remplit ses coins ouverts, de la
			# couleur du sol. Une dalle de plus par case ne servirait qu'à
			# poser du béton dans l'herbe — et à doubler le nombre de tuiles.
			if carte.case_prise(c):
				continue
			if carte.route(c):
				if ronds.has(c):
					# Le rond-point tient les neuf cases : il se pose seul, à
					# trois cases de large, et ses voisines s'abstiennent.
					_tuile(racine, "road-roundabout", centre, 0, Color.WHITE, 3.0)
					continue
				if _sous_un_rond(ronds, c): continue
				var f: Array = carte.tuile(c)
				var nom := String(f[0])
				nom = _variante_avenue(ville, c, nom)
				nom = _variante_campagne(ville, c, nom)
				_tuile(racine, nom, centre, int(f[1]))
				# ⭐ LES GLISSIÈRES. Systématiques sur une voie rapide, et POSÉES
				# AU BORD DU VIDE partout ailleurs : « de temps en temps place les
				# objets avec la terminaison barrier pour ajouter des sécurités
				# de sortir de la route en se cognant dessus » (client, 16/09).
				# Le bon « de temps en temps » n'est pas un tirage au sort : c'est
				# là où la chaussée SURPLOMBE quelque chose — un remblai, un
				# quai, l'eau. Une glissière au milieu d'un lotissement plat ne
				# protège de rien et encombre le trottoir ; une glissière au bord
				# d'une descente, c'est ce qui rend le dénivelé lisible.
				if CarteVille.BARRIERES.has(nom) and _barriere_ici(ville, c):
					# ⚠ LA GLISSIÈRE A SON PROPRE QUART DE TOUR, pas celui de la
					# chaussée : voir `CarteVille.quarts_de_barriere`, et les
					# rambardes en travers de la route qui l'ont motivé.
					var nb := String(CarteVille.BARRIERES[nom])
					_tuile(racine, nb, centre,
						CarteVille.quarts_de_barriere(nb, carte.masque(c)))
			elif ville.matiere_de(c) == Ville2.M_DALLE:
				_tuile(racine, _dalle_de(ville, c), centre, 0, TEINTE_DALLE)
			# ⚠ SINON, ON NE POSE RIEN — ET SURTOUT PAS DU BÉTON. `plate()` est
			# vrai dès qu'un LOT occupe la case : jusqu'ici, poser un bâtiment
			# faisait donc apparaître une dalle de trottoir sous lui, quelle que
			# soit la matière du sol. Une maison de banlieue se retrouvait sur
			# un socle de béton au milieu de sa pelouse, et dans l'éditeur le
			# moindre rocher posé bétonnait son carré (« quand je place un
			# cliff, le sol se transforme en béton, j'aimerais que le sol ne
			# change pas », client, 12/09).
			#
			# `plate()` veut dire « cette case est un plateau, le terrain s'y
			# soude à plat » — pas « cette case est pavée ». Seule la MATIÈRE
			# dit ce qu'on voit, et le maillage du terrain la rend déjà, à la
			# bonne couleur et à la bonne hauteur.

## LES TUILES DE CAMPAGNE (demande du client, 12/09 : « road-bend plutôt que
## road-bend-sidewalk sur l'herbe »). Le kit a deux dessins pour le même
## raccord : l'un remplit son carré d'un trottoir, l'autre n'est que la bande
## de chaussée. En ville le trottoir est juste ; dans un champ il fait une
## place de village autour d'un virage.
const NUES := {
	"road-bend-sidewalk": "road-bend", "road-bend-square": "road-bend",
	"road-curve-pavement": "road-curve",
	"road-straight-half": "road-straight",
}

static func _variante_campagne(ville: Ville2, c: Vector2i, nom: String) -> String:
	if not NUES.has(nom): return nom
	if not ANGLES.a_la_campagne(ville, c): return nom
	return String(NUES[nom])

## La couleur du sol d'une case : le béton en ville, la matière du terrain
## dehors — c'est ce qui va sous une tuile ajourée.
static func _teinte_du_sol(ville: Ville2, c: Vector2i) -> Color:
	if not ANGLES.a_la_campagne(ville, c): return TEINTE_DALLE
	return TerrainV2.COULEURS.get(ville.matiere_de(c), TEINTE_DALLE)

## ⭐⭐ LES PASSAGES PIÉTONS — « il ne faut pas mettre de passage piéton l'un à
## côté de l'autre » (client, 16/09, capture à l'appui : une avenue entière
## pavée de zébras, en long ET en large).
##
## D'où venait le tapis rayé : les tuiles `-path` du kit portent leurs propres
## passages sur CHACUN de leurs quatre bras, et toute case d'avenue entourée de
## chaussée porte le masque d'un carrefour. Sur une avenue large de trois
## cases, l'INTÉRIEUR de la chaussée est donc « un carrefour » du point de vue
## du masque : chaque case prenait sa tuile zébrée, et l'avenue devenait un
## passage clouté de deux cents mètres de long.
##
## Deux règles, et il faut les deux :
##
## 1. UN ZÉBRA SE POSE AU BORD D'UN CARREFOUR, PAS DANS SON VENTRE. On traverse
##    là où le trottoir commence : une case dont les quatre voisines sont de la
##    chaussée est au milieu du bitume, personne n'y traverse. Cette seule règle
##    vide l'intérieur des avenues larges.
## 2. JAMAIS DEUX CÔTE À CÔTE. Parmi deux voisines qui remplissent toutes deux
##    la règle 1, une seule garde son zébra : celle dont le tirage de position
##    est le plus bas. Le tirage ne dépend que de la case, donc l'arbitrage
##    donne le même résultat d'une reconstruction à l'autre et d'une fenêtre à
##    la voisine — sans quoi le passage sauterait d'un côté à l'autre de la rue
##    à chaque coup de pinceau.
## ⭐⭐⭐ LA GLISSIÈRE EST LA RÈGLE, PAS L'EXCEPTION.
##
## « Étudie l'image 1 pour revoir tout ton système de route, et fais tout avec
## les barrières par-dessus, quitte à fusionner les deux objets ensemble »
## (client, 16/09). Sa référence montre un réseau où CHAQUE ruban est bordé sur
## toute sa longueur : ce sont les glissières qui donnent à la route son épaisseur
## et son tracé lisible, pas le bitume.
##
## ⚠ LE KIT SÉPARE LA CHAUSSÉE DE SA GLISSIÈRE, ET C'EST UNE CHANCE. Un
## `-barrier` n'est pas une tuile, c'est la paire de rails à poser dessus
## (mesuré au banc : le modèle seul ne montre que deux traits). On ne fusionne
## donc rien dans les fichiers : on pose SYSTÉMATIQUEMENT les deux pièces, ce
## qui revient au même à l'écran et laisse le kit intact.
##
## ⚠⚠ SAUF AUX CARREFOURS, ET C'EST TOUTE LA RÈGLE. Le modèle `-barrier` porte
## ses rails sur ses DEUX côtés. Posé partout, il en met donc entre les voies
## d'une avenue large et en travers de chaque croisement — on grillagerait la
## ville. Une case dont les quatre voisines sont de la chaussée est un carrefour
## ou le ventre d'une avenue : elle n'a pas de bord, donc pas de glissière. Dès
## qu'un côté donne sur autre chose que du bitume, la route a un bord, et ce
## bord se borde.
static func _barriere_ici(ville: Ville2, c: Vector2i) -> bool:
	if ville.genre_de_route(c) == Ville2.R_VOIE_RAPIDE: return true
	for d in CarteVille.COTES:
		if not ville.carte.route(c + d): return true
	return false

## La chaussée surplombe-t-elle quelque chose ? Une voisine sous l'eau, ou plus
## basse d'un palier entier : dans les deux cas on tombe si on sort de la route.
static func _au_bord_du_vide(ville: Ville2, c: Vector2i) -> bool:
	var mien := ville.carte.palier(c)
	for d in CarteVille.COTES:
		var n: Vector2i = c + d
		if not ville.carte.terre(n): return true
		if mien - ville.carte.palier(n) >= 1: return true
	return false

## ⭐⭐ LE ROND-POINT, « avec parcimonie » (client, 16/09, photo à l'appui).
##
## ⚠ IL FAIT TROIS CASES SUR TROIS, PAS UNE. Mesuré : `road-roundabout` va de
## −1,5 à +1,5 dans les deux sens. Posé comme une tuile ordinaire il serait
## neuf fois trop petit, et posé à sa taille sans rien dégager il écraserait
## les huit cases autour de lui. Le centre le dessine à trois cases, et ses huit
## voisines ne posent plus rien : c'est LUI, leur chaussée.
##
## Quatre conditions, et la parcimonie vient de la troisième :
## 1. un vrai carrefour à quatre branches (masque 15) ;
## 2. une rue ordinaire — ni avenue, ni voie rapide : un rond-point sur une
##    deux fois deux voies ne se lit pas ;
## 3. les quatre bras sont de la chaussée et les quatre COINS sont libres —
##    le modèle apporte ses propres coins, il lui faut la place ;
## 4. un carrefour sur quatorze environ, et jamais deux dans un rayon de
##    quatre cases : entre deux candidats, celui dont le tirage de position est
##    le plus bas gagne, donc le choix ne dépend pas de la fenêtre regardée.
const RARETE_ROND := 14
const ECART_RONDS := 4

static func _candidat_rond(ville: Ville2, c: Vector2i) -> bool:
	if not ville.carte.route(c): return false
	if ville.carte.masque(c) != 15: return false
	var genre := ville.genre_de_route(c)
	if genre == Ville2.R_AVENUE or genre == Ville2.R_VOIE_RAPIDE: return false
	for d in CarteVille.COTES:
		if not ville.carte.route(c + d): return false
	for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var coin: Vector2i = c + d
		if ville.carte.route(coin): return false
		if ville.lot_sur(coin) >= 0: return false
		if not ville.carte.terre(coin): return false
		if ville.carte.palier(coin) != ville.carte.palier(c): return false
	return CarteVille.tirage_de(c) % RARETE_ROND == 0

static func _rond_point_ici(ville: Ville2, c: Vector2i) -> bool:
	if not _candidat_rond(ville, c): return false
	var mien := CarteVille.tirage_de(c)
	for dy in range(-ECART_RONDS, ECART_RONDS + 1):
		for dx in range(-ECART_RONDS, ECART_RONDS + 1):
			if dx == 0 and dy == 0: continue
			var n := c + Vector2i(dx, dy)
			if _candidat_rond(ville, n) and CarteVille.tirage_de(n) < mien:
				return false
	return true

## Cette case est-elle SOUS un rond-point voisin ? Alors elle ne pose rien.
static func _sous_un_rond(ronds: Dictionary, c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0: continue
			if ronds.has(c + Vector2i(dx, dy)): return true
	return false

static func _bord_de_carrefour(ville: Ville2, c: Vector2i) -> bool:
	if not ville.carte.route(c): return false
	var m := ville.carte.masque(c)
	if m != 15 and m != 7 and m != 11 and m != 13 and m != 14: return false
	for d in CarteVille.COTES:
		if not ville.carte.route(c + d): return true
	return false

static func _zebre_ici(ville: Ville2, c: Vector2i) -> bool:
	if not _bord_de_carrefour(ville, c): return false
	var mien := CarteVille.tirage_de(c)
	for d in CarteVille.COTES:
		var n: Vector2i = c + d
		if not _bord_de_carrefour(ville, n): continue
		if CarteVille.tirage_de(n) < mien: return false
	return true

static func _variante_avenue(ville: Ville2, c: Vector2i, nom: String) -> String:
	var zebre := _zebre_ici(ville, c)
	if nom.begins_with("road-crossroad"):
		return "road-crossroad-path" if zebre else "road-crossroad-line"
	if nom.begins_with("road-intersection"):
		return "road-intersection-path" if zebre else "road-intersection-line"
	return nom

## Quelle dalle sous une case pavée sans rue : le trottoir du kit. Les cases
## de terrain ne passent pas par ici (voir `_poser_terrain`).
static func _dalle_de(_ville: Ville2, _c: Vector2i) -> String:
	return "tile-low"

# ------------------------------------------------------------------ le terrain

## LE TERRAIN CONTINU ET LA MER, en deux maillages par morceau (voir
## `TerrainV2`). Un morceau entièrement pavé n'en produit aucun.
static func _poser_terrain(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	var sol := TerrainV2.maillage(ville, zone)
	if sol != null:
		var n := MeshInstance3D.new()
		n.mesh = sol
		n.material_override = TerrainV2.matiere()
		n.set_meta("modele", "terrain")
		racine.add_child(n)
	var mer := TerrainV2.maillage_eau(ville, zone)
	if mer != null:
		var n := MeshInstance3D.new()
		n.mesh = mer
		n.material_override = MatieresCarnage.eau()
		n.set_meta("modele", "eau")
		racine.add_child(n)

static func _poser_ouvrages(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	var carte := ville.carte
	for o in ville.ouvrages:
		var coin := Vector2i(int(o["i"]), int(o["j"]))
		if not zone.has_point(coin): continue
		var t := Vector2i(int(o["w"]), int(o.get("h", o["w"])))
		var y := float(carte.palier(coin)) * PALIER
		var centre := Vector3((float(coin.x) + float(t.x) * 0.5) * CASE, y,
			(float(coin.y) + float(t.y) * 0.5) * CASE)
		_tuile(racine, String(o["t"]), centre, int(o["q"]))

# ------------------------------------------------------------------ les soutènements

## LES MURS DE SOUTÈNEMENT (cahier § 4 : « béton en ville, rochers hors
## ville »). Une case PLATE — une dalle, une rue, un lot — est un plateau : son
## bord donne sur le vide dès que la voisine est plus basse. Sans mur, on voit
## la tranche d'une dalle de deux centimètres flotter au-dessus du terrain, et
## le quai d'un port a l'air posé sur l'eau.
##
## ⚠ LE MUR DESCEND JUSQU'À LA VOISINE, PAS D'UNE HAUTEUR FIXE. Contre un
## terrain il s'arrête au sol ; contre la mer il plonge sous la nappe, sinon on
## voit le dessous du quai à travers l'eau.
const TEINTE_BETON := Color("#b4b2ab")
const TEINTE_ROCHE := Color("#9b978e")
const EPAISSEUR_MUR := 1.2
## ⚠ DE COMBIEN UNE TUILE DÉBORDE DE SA CASE — ET POURQUOI IL LE FAUT MÊME
## SANS BISEAU. Mesuré sur les .glb : la face haute d'une tuile de route va
## exactement de −0,5 à +0,5, sans chanfrein. Deux tuiles voisines se touchent
## donc au millième près, et pourtant un LISERÉ CLAIR d'un ou deux pixels reste
## visible à chaque joint (« je vois toujours des écarts entre les routes »,
## client, 12/09).
##
## Ce n'est PAS un trou : en peignant le sol sous la chaussée en rouge vif, pas
## un pixel rouge n'apparaît. C'est la couture entre DEUX MAILLAGES SÉPARÉS :
## chaque tuile est son propre `MeshInstance3D`, donc son bord est anticrénelé
## pour son propre compte, et l'arête commune se retrouve mélangée deux fois.
## Aucune valeur de sol ne peut corriger ça — il faut que les tuiles SE
## CHEVAUCHENT.
##
## Le chevauchement est minuscule (0,3 unité sur 20) et ne peut pas faire
## clignoter : `DECALAGE_DAMIER` descend une case sur deux d'un cheveu, si bien
## que le débord d'une tuile passe toujours SOUS le dessus plat de sa voisine
## au lieu d'être coplanaire avec lui.
const RECOUVREMENT := 1.015
const DECALAGE_DAMIER := 0.006
## ⚠ LE SEUIL DOIT ÊTRE PLUS GRAND QUE L'ÉPAISSEUR D'UNE TUILE. À 0,35 il était
## plus PETIT que les 0,4 d'une dalle du kit : sur un sol parfaitement plat,
## chaque case se trouvait « plus haute » que sa voisine et se bordait d'un
## muret de béton. Vu du ciel, la ville entière était quadrillée de liserés
## clairs — ce que le client a lu comme « aucune route n'est collée, on voit
## l'écart entre deux routes » (12/09). Un mur ne se justifie qu'à partir
## d'une vraie marche.
const MUR_MINI := 1.2

static func _poser_soutenements(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not ville.dedans(c) or not ville.plate(c): continue
			var haut := ville.sol(c) + EPAISSEUR_TUILE
			# ⚠ LE BÉTON SOUS CE QUI EST BÂTI, les rochers ailleurs (cahier
			# § 4) — et une terrasse en herbe reste de la ville : c'est la RUE
			# ou le LOT qui décide, pas la pelouse.
			var en_ville := ville.matiere_de(c) == Ville2.M_DALLE \
				or ville.carte.route(c) or ville.lot_sur(c) >= 0
			# ⚠ UNE RAMPE MONTE AU-DESSUS DE SA PROPRE CASE. `road-slant`
			# grimpe d'un palier entre l'entrée et la sortie de la case : un
			# mur arrêté à l'altitude de la case laissait, sur les DEUX CÔTÉS
			# du lacet, un triangle ouvert par lequel on voyait le dessous de
			# la colline. On monte donc le mur jusqu'au haut de la rampe, et
			# on le construit en DEUX DEMI-MURS pour épouser la pente au lieu
			# de faire une marche.
			var vers_le_haut := _sens_de_la_rampe(ville, c)
			# ⚠ UNE RAMPE SE BORDE TOUJOURS, MÊME POUR UN RIEN. Sa tuile monte
			# d'un palier au-dessus de sa propre case : sous la moitié haute, il
			# n'y a rien, et l'on voyait le ciel par deux triangles sombres de
			# part et d'autre de chaque lacet. Le seuil ordinaire (qui évite de
			# border chaque case d'un sol plat) ne s'applique donc pas à elle.
			var seuil: float = 0.05 if vers_le_haut != Vector2i.ZERO else MUR_MINI
			for d in CarteVille.COTES:
				var v: Vector2i = c + d
				var bas := _pied_du_mur(ville, v)
				if haut - bas < seuil: continue
				var teinte: Color = TEINTE_BETON if en_ville else TEINTE_ROCHE
				if vers_le_haut == Vector2i.ZERO or d == -vers_le_haut:
					_mur(racine, i, j, d, bas, haut, 1.0, 0.0, teinte)
				elif d == vers_le_haut:
					_mur(racine, i, j, d, bas, haut + PALIER, 1.0, 0.0, teinte)
				else:
					# Un côté qui longe la pente : deux demis, en escalier.
					_mur(racine, i, j, d, bas, haut + PALIER * 0.25, 0.5, -0.25, teinte)
					_mur(racine, i, j, d, bas, haut + PALIER * 0.75, 0.5, 0.25, teinte)

## Un pan de mur le long du côté `d` de la case (i, j), de `bas` à `haut`.
## `part` est la fraction de la case couverte, `glisse` le décalage du centre
## le long de ce côté (en fraction de case) : c'est ce qui permet de poser deux
## demi-murs à deux hauteurs pour suivre une rampe.
static func _mur(racine: Node3D, i: int, j: int, d: Vector2i, bas: float, haut: float,
		part: float, glisse: float, teinte: Color) -> void:
	if haut - bas < MUR_MINI: return
	var le_long := Vector3(float(d.y), 0.0, float(d.x)) * glisse * CASE
	var centre := Vector3((float(i) + 0.5 + float(d.x) * 0.5) * CASE, (haut + bas) * 0.5,
		(float(j) + 0.5 + float(d.y) * 0.5) * CASE) + le_long
	var dims := Vector3(CASE * part, haut - bas, EPAISSEUR_MUR) if d.x == 0 \
		else Vector3(EPAISSEUR_MUR, haut - bas, CASE * part)
	_boite(racine, dims, centre, teinte)

## Le sens dans lequel cette case de chaussée GRIMPE : la voisine en chaussée
## qui est un palier plus haut, ou zéro si la case est plate.
static func _sens_de_la_rampe(ville: Ville2, c: Vector2i) -> Vector2i:
	if not ville.carte.route(c): return Vector2i.ZERO
	var mien := ville.carte.palier(c)
	for d in CarteVille.COTES:
		var v: Vector2i = c + d
		if ville.dedans(v) and ville.carte.route(v) and ville.carte.palier(v) > mien:
			return d
	return Vector2i.ZERO

## Le pied d'un mur du côté de la case `v` : le sol si c'est de la terre, le
## fond sous la nappe si c'est de l'eau, et très bas hors carte (un bord de
## carte ne doit pas montrer sa tranche).
## ⚠ LE MUR DESCEND JUSQU'AU COIN LE PLUS BAS DE LA VOISINE, pas jusqu'à son
## altitude de case. Le terrain est un maillage LISSÉ : ses coins sont soudés
## à la moyenne des quatre cases, si bien que la nappe passe sous l'altitude
## nominale dès qu'elle plonge. Un mur arrêté à `sol(v)` laissait une fente
## ouverte sous le lacet — on voyait le DESSOUS de la colline, en bleu sombre,
## entre la chaussée et l'herbe.
static func _pied_du_mur(ville: Ville2, v: Vector2i) -> float:
	if not ville.dedans(v):
		return -6.0
	if not ville.terre(v):
		return minf(ville.sol(v), TerrainV2.NIVEAU_MER) - 0.6
	var bas := ville.sol(v)
	for dj in 2:
		for di in 2:
			bas = minf(bas, TerrainV2.hauteur_coin(ville, v.x + di, v.y + dj))
	# ⚠ PAS DE MARGE ICI. Les 0,25 unités que ce mur creusait « pour être sûr »
	# suffisaient, sur un sol plat, à déclencher un muret par case.
	return bas

# ------------------------------------------------------------------ les lots

static func _poser_lots(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for l in ville.lots:
		var cases := Ville2.cases_du_lot(l)
		if cases.is_empty() or not zone.has_point(cases[0]): continue
		var chemin := KitVille2.chemin(String(l["m"]))
		if not ResourceLoader.exists(chemin):
			push_warning("modèle absent : " + chemin)
			continue
		var n := MeshInstance3D.new()
		n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
		# ⚠ LA TEINTE DU LOT. Les 21 pavillons du kit partagent UN seul atlas :
		# murs blancs, toit menthe, pour tous. Le client voit donc « toujours
		# les mêmes maisons » même quand le générateur alterne consciencieusement
		# vingt-et-un modèles différents — la variété de FORME ne se lit pas à
		# la distance où l'on juge un quartier, la variété de COULEUR si.
		# Le shader des kits multiplie l'atlas par `teinte` (`peinture` à 0 pour
		# les bâtiments) : un ocre donne des murs ocre et un toit olive, ce qui
		# est exactement ce qu'on veut pour la colline « pierre du Sud ».
		var couleur := Color.WHITE
		var dit := String(l.get("c", ""))
		if dit != "": couleur = Color(dit)
		# ⚠ ET LA COULEUR DU TOIT, QUI N'EST PAS UNE TEINTE. Voir `atlas.gd` :
		# la teinte multiplie tout le bâtiment, la toiture repeint UNE bande de
		# l'atlas. Un lot peut porter les deux — murs crème, toit ardoise.
		var toit := String(l.get("toit", ""))
		n.material_override = _matiere(chemin, couleur) if toit == "" \
			else _matiere_toit(chemin, couleur, toit)
		# Posé SUR la dalle : une tuile du kit a une épaisseur, et un modèle posé
		# au palier avait le pied enterré de 0,4 unité.
		var ou := ville.centre_du_lot(l) + Vector3(0, EPAISSEUR_TUILE, 0)
		# ⭐ UN LOT PEUT ÊTRE EN L'AIR. Une pièce de route posée sur des pylônes
		# pour relier deux voies n'a pas d'altitude de terrain : elle a la
		# SIENNE. `y_abs` la porte, comme pour un objet.
		if l.has("y_abs"): ou.y = float(l["y_abs"]) + EPAISSEUR_TUILE
		n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(int(l["q"]))).scaled(Vector3.ONE * KitVille2.echelle(String(l["m"]))), ou)
		n.set_meta("modele", String(l["m"]))
		_noter(chemin)
		racine.add_child(n)

# ------------------------------------------------------------------ les objets

static func _poser_objets(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for o in ville.objets:
		var x := float(o["x"])
		var z := float(o["z"])
		var c := Vector2i(floori(x / CASE), floori(z / CASE))
		if not zone.has_point(c): continue
		# ⚠ L'ALTITUDE VIENT DU SOL RÉEL. Sur une case plate c'est le palier de
		# la tuile ; sur du terrain c'est le maillage interpolé — sinon un arbre
		# planté sur une dune s'enfonce d'un côté et flotte de l'autre.
		# ⚠ TROIS SOLS POSSIBLES, ET PAS UN DE MOINS.
		#   • une CHAUSSÉE est une tuile du kit, posée au palier ARRONDI ;
		#   • une autre case plate (dalle, lot) suit son altitude EXACTE — la
		#     promenade du bord de mer descend par quarts de palier, et l'objet
		#     posé dessus au palier arrondi flottait d'une demi-marche : c'est
		#     le « certains cailloux volent » du client ;
		#   • le reste suit le maillage lissé.
		var y := 0.0
		if ville.carte.route(c):
			y = float(ville.carte.palier(c)) * PALIER + EPAISSEUR_TUILE
		elif ville.plate(c):
			y = ville.sol(c) + EPAISSEUR_TUILE
		else:
			y = TerrainV2.hauteur_en(ville, x, z)
		# `y_abs` : une altitude IMPOSÉE, pour ce qui n'est pas posé au sol —
		# le bar et les lampadaires d'une jetée sont sur son tablier.
		if o.has("y_abs"): y = float(o["y_abs"])
		# `dy` : une hauteur AU-DESSUS du sol trouvé — un conteneur empilé sur
		# un autre, une caisse sur une pile. C'est la différence avec `y_abs` :
		# la pile suit le quai s'il n'est pas à zéro.
		if o.has("dy"): y += float(o["dy"])
		poser_objet(racine, String(o["m"]), Vector3(x, y, z), float(o.get("r", 0.0)),
			float(o.get("h", 0.0)), String(o.get("c", "")), o)

## Pose un objet : `modele` est un nom du catalogue (`KitVille2.PROPS`), une
## voiture (`voitures/...`), ou un chemin `res://` posé à l'échelle du kit.
## ⭐ L'ASSIETTE D'UNE PIÈCE : son cap, PUIS son inclinaison.
##
## Le moteur ne savait poser quà plat. Ça suffit pour une maison ; ça ne suffit
## pas pour une chaussée d'autoroute, qui monte et descend avec le tablier. Une
## tuile de route posée à plat sur un tablier en pente laisse une MARCHE à
## chaque case — un escalier de vingt centimètres tous les vingt mètres, sur
## vingt kilomètres.
##
## ⚠ L'ORDRE COMPTE, ET IL N'EST PAS INTERCHANGEABLE. On tourne d'abord la
## pièce vers son cap (autour de la verticale), puis on la bascule autour de son
## propre axe TRANSVERSAL — le X local, celui qui vient de tourner avec elle.
## Basculer d'abord et tourner ensuite ferait pencher la route sur le côté dès
## qu'elle ne va plus vers l'est.
static func _assiette(tourne: float, pente: float) -> Basis:
	var b := Basis(Vector3.UP, tourne)
	if absf(pente) < 0.0005: return b
	return b * Basis(Vector3.RIGHT, pente)

static func poser_objet(parent: Node3D, modele: String, ou: Vector3, tourne := 0.0,
		hauteur := 0.0, teinte := "", fiche_objet := {}) -> void:
	if modele == "pelouse":
		_pelouse(parent, ou, float(fiche_objet.get("w", CASE)),
			float(fiche_objet.get("d", CASE)), String(fiche_objet.get("c", "")))
		return
	if modele == "plateforme":
		# Le tablier se compte AU-DESSUS DE LA MER, pas au-dessus du fond :
		# une jetée est plate, le fond ne l'est pas.
		_plateforme(parent, ou, tourne, float(fiche_objet.get("w", CASE)),
			float(fiche_objet.get("d", CASE)),
			TerrainV2.NIVEAU_MER + float(fiche_objet.get("y", 2.5)) - ou.y)
		return
	# ⭐ L'AUTOROUTE AÉRIENNE. Deux objets et pas un seul : le TABLIER se pose par
	# case, la PILE se pose là où il y a de la place. Les fondre en un seul
	# objet — comme le fait `plateforme`, qui descend ses pilotis toute seule —
	# donnerait des piles tous les six mètres, donc forcément sur des toits :
	# c'est exactement ce que le client interdit.
	if modele == "viaduc":
		if fiche_objet.has("pts"):
			_viaduc_ruban(parent, fiche_objet["pts"], float(fiche_objet.get("w", 22.0)))
		else:
			_viaduc(parent, ou, tourne, float(fiche_objet.get("w", 22.0)),
				float(fiche_objet.get("d", CASE)))
		return
	if modele == "pile":
		_pile(parent, ou, float(fiche_objet.get("w", 3.2)),
			float(fiche_objet.get("y", 0.0)))
		return
	if modele == "roue":
		_grande_roue(parent, ou, tourne, float(fiche_objet.get("w", 40.0)))
		return
	if modele.begins_with("bateau:"):
		_bateau(parent, modele.trim_prefix("bateau:"), ou, tourne)
		return
	if modele == "neon":
		_enseigne(parent, ou + Vector3(0, float(fiche_objet.get("y", 8.0)), 0), tourne,
			float(fiche_objet.get("w", 6.0)), float(fiche_objet.get("hh", 1.6)),
			String(fiche_objet.get("c", "#ff3c78")))
		return
	if modele == "pub":
		_panneau(parent, ou + Vector3(0, float(fiche_objet.get("y", 0.0)), 0), tourne,
			float(fiche_objet.get("w", 14.0)), float(fiche_objet.get("hh", 8.0)),
			float(fiche_objet.get("pied", 3.0)), int(fiche_objet.get("image", 0)))
		return
	var chemin := ""
	var h := hauteur
	var couleur := Color.WHITE
	var fiche: Dictionary = KitVille2.PROPS.get(modele, {})
	if not fiche.is_empty():
		chemin = KitVille2.chemin(String(fiche["m"]))
		if h <= 0.0: h = float(fiche.get("h", 0.0))
		if fiche.has("c"): couleur = Color(String(fiche["c"]))
	else:
		chemin = KitVille2.chemin(modele)
	if teinte != "": couleur = Color(teinte)
	if not ResourceLoader.exists(chemin):
		push_warning("objet absent : " + chemin)
		return
	# Un OBJET aussi peut avoir sa toiture repeinte : les baraques du
	# bidonville sont des objets libres, pas des lots, et elles doivent être en
	# tôle comme le reste du quartier.
	var toit_o := String(fiche_objet.get("toit", ""))
	var n := MeshInstance3D.new()
	if modele.begins_with("voitures/"):
		# ⚠ Le Car Kit regarde +Z quand les props regardent −Z (mesuré,
		# `FormesCarnage.maillage_voiture`) : un quart de tour dans l'autre sens.
		n.mesh = FormesCarnage.maillage_kenney(chemin, KitVille2.LONGUEUR_VOITURE, Vector3.AXIS_Z, PI * 0.5)
		n.transform = Transform3D(Basis(Vector3.UP, tourne), ou)
	elif h > 0.0:
		n.mesh = FormesCarnage.maillage_kenney(chemin, h, Vector3.AXIS_Y, 0.0)
		n.transform = Transform3D(_assiette(tourne, float(fiche_objet.get("pente", 0.0))), ou)
	else:
		# À l'échelle du kit (auvents, conteneurs, dalles de sentier…).
		# ⚠ PAS `CASE` EN DUR : les accessoires du kit nature sont dessinés pour
		# le bonhomme du kit, pas pour la case — à 20, un champignon fait quatre
		# mètres. `KitVille2.echelle_libre` fait le tri (voir son commentaire).
		# ⚠ ET SON HERBE PEUT ÊTRE REPEINTE. Les tuiles de chemin du kit nature
		# apportent leur carré d'herbe avec elles ; sur un sol nu, ça fait un
		# rectangle vert par case. `sol` demande de remplacer les sommets verts
		# par cette couleur-là — voir `atlas.sans_verdure`, et pourquoi la
		# teinte d'instance ne peut pas le faire.
		var sol := String(fiche_objet.get("sol", ""))
		n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0) if sol == "" \
			else ATLAS.sans_verdure(chemin, Color(sol))
		# ⚠ `aplat` ÉCRASE LA TUILE EN HAUTEUR, ET C'EST INDISPENSABLE POUR UNE
		# PIÈCE DE SOL.
		#
		# `maillage_kenney` repose tout modèle BASE À ZÉRO : il descend la boîte
		# englobante pour que son plancher tombe sur le sol. C'est juste pour un
		# arbre ou une maison. Pour une tuile de chemin, c'est faux : sa boîte va
		# de −0,10 à −0,05 unité Kenney, c'est-à-dire qu'elle est dessinée ENTRE
		# 1 ET 2 MÈTRES SOUS le niveau du sol — elle est faite pour être
		# ENFONCÉE. Reposée base à zéro, elle ressort entière : un mètre de
		# ruban posé sur la terre, avec son mur de côté et son ombre (« pourquoi
		# la route sort de la terre, on dirait qu'elle n'est pas enfoncée
		# dedans », client, 13/09).
		#
		# On ne peut pas simplement la redescendre : le terrain est une surface
		# continue, pas un volume, et il n'y a aucun trou dessous — enfoncée,
		# elle disparaîtrait. On l'ÉCRASE donc : son mètre devient quinze
		# centimètres, l'ornière garde son relief et son ombre portée, et la
		# tuile se lit comme du sol, plus comme une dalle.
		var aplat := float(fiche_objet.get("aplat", 1.0))
		var e := KitVille2.echelle_libre(chemin)
		n.transform = Transform3D(_assiette(tourne, float(fiche_objet.get("pente", 0.0))).scaled(
			Vector3(e, e * aplat, e)), ou)
	n.material_override = _matiere(chemin, couleur) if toit_o == "" \
		else _matiere_toit(chemin, couleur, toit_o)
	n.set_meta("modele", modele)
	_noter(chemin)
	parent.add_child(n)

# ------------------------------------------------------------------ le rail

## Le rail : deux files et des traverses, en boîtes — le kit n'a pas de voie
## ferrée. Posé au sol, entre les cases, au niveau du palier.
## ⭐⭐ LA VOIE NE S'ÉTALE PAS SUR LA CHAUSSÉE, ELLE LA FRANCHIT.
##
## « Une voie ferrée doit couper une route en passant par-dessus mais jamais
## être étalée dessus » (client, 16/09), et sa capture le montrait : les
## traverses couraient à plat sur l'avenue, comme un tapis posé sur la route.
##
## La voie porte donc un PROFIL D'ALTITUDE, pas une hauteur par case :
##
## 1. Au repos elle est au sol, sur le palier de sa case.
## 2. Au-dessus d'une chaussée elle est à `HAUT_FRANCHIT` au-dessus du sol —
##    de quoi laisser passer un camion.
## 3. ENTRE LES DEUX, ELLE MONTE, elle ne saute pas. Le profil brut est lissé
##    sur une dizaine de cases : la rampe s'étale de part et d'autre du
##    croisement, et c'est ce qui fait un remblai plutôt qu'une marche.
## 4. Là où elle est en l'air, elle prend son TABLIER et ses PILES. Sans ça la
##    voie volerait, ce qui est le même défaut d'un cran plus haut.
const HAUT_FRANCHIT := 9.0           ## le gabarit libre au-dessus d'une chaussée
const LISSAGE_RAIL := 5              ## demi-fenêtre de la rampe, en cases
const AU_SOL := 1.2                  ## en dessous, la voie est réputée au sol
const ECART_PILES_RAIL := 3          ## une pile toutes les 3 cases
const TEINTE_TABLIER_RAIL := Color("#9aa0a8")

## Le sol sous une case de voie. ⚠ Une case d'eau n'a pas de palier (`palier`
## rend −999) : la voie y est sur un pont, dont le tablier de cette carte est au
## palier 0 — on y retombe, ce qui pose les traverses exactement dessus.
static func _sol_du_rail(ville: Ville2, c: Vector2i) -> float:
	var niveau := ville.carte.palier(c)
	return 0.3 if niveau <= -900 else float(niveau) * PALIER + 0.3

## Le profil d'une voie : au sol partout, en l'air au-dessus des chaussées, et
## une rampe pour relier les deux.
static func _profil_du_rail(ville: Ville2, cases: Array) -> PackedFloat32Array:
	var brut := PackedFloat32Array()
	brut.resize(cases.size())
	for i in cases.size():
		var c: Vector2i = cases[i]
		brut[i] = _sol_du_rail(ville, c) + (HAUT_FRANCHIT if ville.carte.route(c) else 0.0)
	var lisse := PackedFloat32Array()
	lisse.resize(cases.size())
	for i in cases.size():
		# ⚠ LA MOYENNE NE DOIT JAMAIS FAIRE REDESCENDRE LA VOIE SOUS SON GABARIT.
		# Un lissage seul rabote le sommet de la rampe : au-dessus de la
		# chaussée la voie retomberait à mi-hauteur, et le camion passerait
		# dedans. On prend donc le PLUS HAUT des deux, la moyenne pour la
		# douceur et le brut pour la sécurité.
		var somme := 0.0
		var n := 0
		for t in range(maxi(0, i - LISSAGE_RAIL), mini(cases.size(), i + LISSAGE_RAIL + 1)):
			somme += brut[t]
			n += 1
		lisse[i] = maxf(somme / float(n), brut[i])
	return lisse

## ⭐⭐ UN CHEMIN DE FER N'A AUCUN ANGLE DROIT. AUCUN.
##
## « Il n'y a aucun virage dans un vrai chemin de fer, aucun angle droit n'est
## accepté, que des courbes petit à petit » (client, 16/09).
##
## Ma première réponse coupait les coins un par un, avec une courbe par virage.
## Elle laissait passer tout ce qui n'était pas un virage franc et isolé : deux
## coudes rapprochés restaient vifs, et les embranchements aussi — c'est ce que
## montrait sa capture, trois voies qui se rejoignent à l'équerre.
##
## La bonne réponse n'est pas de rattraper les coins : c'est de ne jamais en
## fabriquer. Le tracé du pays est posé sur une grille de cases, donc il est fait
## d'angles droits par construction. On le LISSE ENTIÈREMENT, en deux temps :
##
## 1. ON DÉCIME. Une case sur `DECIME` devient un point de conduite. Un polygone
##    de conduite plus lâche donne un rayon de courbure plus grand — c'est le
##    seul réglage qui décide si la voie tourne comme un train ou comme un
##    tramway.
## 2. ON COUPE LES COINS, ENCORE ET ENCORE (Chaikin). À chaque passe, chaque
##    segment perd ses deux quarts d'extrémité au profit de deux points neufs :
##    un angle devient deux angles moitié moins vifs, puis quatre, puis huit.
##    Après quatre passes il n'y a plus d'angle du tout, seulement une courbe —
##    et une portion droite, dont les points sont alignés, reste parfaitement
##    droite parce que couper le coin d'une ligne droite ne donne rien d'autre
##    que la même ligne droite.
##
## ⚠ LES DEUX BOUTS NE BOUGENT PAS. Une voie se termine là où une autre commence
## — un embranchement, une gare, le bord de la carte. Si le lissage déplaçait les
## extrémités, chaque raccord s'ouvrirait de quelques mètres : « les rails se
## collent mal ». Chaikin garde donc le premier et le dernier point tels quels.
const DECIME := 2              ## une case de conduite sur deux
const PASSES_LISSAGE := 4      ## le nombre de fois qu'on coupe les coins

## Le profil, lu à un rang flottant.
static func _haut_a(haut: PackedFloat32Array, u: float) -> float:
	var n := haut.size()
	if n == 0: return 0.0
	var f := clampf(u, 0.0, float(n - 1))
	var i := int(floor(f))
	var j := mini(i + 1, n - 1)
	return lerpf(haut[i], haut[j], f - float(i))

## Le centre d'une case, à l'altitude du profil.
static func _point_rail(cases: Array, haut: PackedFloat32Array, u: float) -> Vector3:
	var n := cases.size()
	var f := clampf(u, 0.0, float(n - 1))
	var i := int(floor(f))
	var j := mini(i + 1, n - 1)
	var a: Vector2i = cases[i]
	var b: Vector2i = cases[j]
	var t := f - float(i)
	return Vector3((lerpf(float(a.x), float(b.x), t) + 0.5) * CASE,
		_haut_a(haut, f),
		(lerpf(float(a.y), float(b.y), t) + 0.5) * CASE)

## Une passe de Chaikin, les deux bouts tenus.
static func _couper_les_coins(pts: Array) -> Array:
	if pts.size() < 3: return pts
	var sortie: Array = [pts[0]]
	for k in range(pts.size() - 1):
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		sortie.append(a.lerp(b, 0.25))
		sortie.append(a.lerp(b, 0.75))
	sortie.append(pts[pts.size() - 1])
	return sortie

## La voie dessinée : plus un seul angle droit, du premier mètre au dernier.
static func _trace_arrondi(cases: Array, haut: PackedFloat32Array) -> Array:
	var n := cases.size()
	if n < 2: return []
	var pts: Array = []
	var u := 0.0
	while u < float(n - 1):
		pts.append(_point_rail(cases, haut, u))
		u += float(DECIME)
	pts.append(_point_rail(cases, haut, float(n - 1)))
	for _t in PASSES_LISSAGE:
		pts = _couper_les_coins(pts)
	return _reechantillonner(pts)

## ⚠ QUATRE PASSES DE CHAIKIN MULTIPLIENT LES POINTS PAR SEIZE, et chaque point
## de plus est un bout de rail, un tablier et une traverse : la voie coûtait
## huit fois son prix pour un dessin identique. On repasse donc la courbe à pas
## CONSTANT — une traverse tous les `PAS_TRAVERSE`, en ville comme en courbe —
## ce qui rend au passage l'espacement des traverses régulier, alors qu'il se
## resserrait dans les virages.
const PAS_TRAVERSE := 6.0

static func _reechantillonner(pts: Array) -> Array:
	if pts.size() < 2: return pts
	var sortie: Array = [pts[0]]
	var reste := 0.0
	for k in range(1, pts.size()):
		var a: Vector3 = pts[k - 1]
		var b: Vector3 = pts[k]
		var d := a.distance_to(b)
		if d < 0.0001: continue
		var parcouru := PAS_TRAVERSE - reste
		while parcouru <= d:
			sortie.append(a.lerp(b, parcouru / d))
			parcouru += PAS_TRAVERSE
		reste = d - (parcouru - PAS_TRAVERSE)
	var dernier: Vector3 = pts[pts.size() - 1]
	if (sortie[sortie.size() - 1] as Vector3).distance_to(dernier) > 0.5:
		sortie.append(dernier)
	return sortie

## ⭐⭐⭐ RABOUTER AVANT DE LISSER — ET C'EST POURQUOI MON LISSAGE NE FAISAIT RIEN.
##
## « Je vois toujours des angles droits dans les rails » (client, 16/09), après
## une correction qui supprimait tous les angles. Les deux étaient vrais, et
## voici pourquoi : le réseau n'est pas fait de voies, il est fait de TRONÇONS
## DROITS. Mesuré sur une fenêtre de 45 cases — douze polylignes, dont neuf
## extrémités partagées avec une voisine : chaque coin du réseau est le point où
## DEUX POLYLIGNES SE TOUCHENT, pas un coude à l'intérieur d'une polyligne.
##
## Or le lissage tient ses deux bouts (il le faut, sinon les raccords s'ouvrent).
## Chaque tronçon était donc lissé… et restait une ligne parfaitement droite,
## pendant que tous les angles du réseau, qui vivent exactement aux jointures,
## passaient entre les mailles. Je lissais consciencieusement ce qui n'avait
## aucun coin.
##
## On recoud donc la voie AVANT de la lisser. Deux tronçons qui partagent un bout
## que personne d'autre ne touche sont la même voie : on les colle. Là où trois
## tronçons se rejoignent — un embranchement — on s'arrête : c'est un vrai nœud,
## il a le droit d'être un nœud, et coller deux branches au hasard inventerait
## une voie qui n'existe pas.
static func _chaines_de_rail(ville: Ville2) -> Array:
	var voies: Array = []
	for r in ville.rail:
		var c := Ville2.cases_de_route(r)
		if c.size() >= 2: voies.append(c)
	# Le degré de chaque extrémité : combien de tronçons s'y touchent.
	var degre := {}
	for c in voies:
		for e in [(c as Array)[0], (c as Array)[(c as Array).size() - 1]]:
			degre[e] = int(degre.get(e, 0)) + 1
	# Qui part de quel bout.
	var par_bout := {}
	for k in voies.size():
		var c: Array = voies[k]
		for e in [c[0], c[c.size() - 1]]:
			if not par_bout.has(e): par_bout[e] = []
			(par_bout[e] as Array).append(k)
	var vus := {}
	var chaines: Array = []
	# On démarre par les tronçons dont un bout N'EST PAS un simple raccord :
	# une extrémité libre ou un embranchement. Ce qui reste ensuite est une
	# boucle fermée, qu'on ouvre n'importe où.
	for depart in [false, true]:
		for k in voies.size():
			if vus.has(k): continue
			var c: Array = voies[k]
			var tete: Vector2i = c[0]
			var queue: Vector2i = c[c.size() - 1]
			var libre_tete := int(degre.get(tete, 0)) != 2
			var libre_queue := int(degre.get(queue, 0)) != 2
			if not depart and not libre_tete and not libre_queue: continue
			# On part du bout libre, pour parcourir la voie dans son sens.
			var suite: Array = c.duplicate()
			if libre_queue and not libre_tete: suite.reverse()
			vus[k] = true
			# Et on avance tant que le bout suivant n'est qu'un raccord.
			while true:
				var bout: Vector2i = suite[suite.size() - 1]
				if int(degre.get(bout, 0)) != 2: break
				var voisin := -1
				for j in (par_bout.get(bout, []) as Array):
					if not vus.has(int(j)): voisin = int(j)
				if voisin < 0: break
				var d: Array = (voies[voisin] as Array).duplicate()
				if d[0] != bout: d.reverse()
				vus[voisin] = true
				for t in range(1, d.size()): suite.append(d[t])
			chaines.append(suite)
	return chaines

static func _poser_rail(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for cases in _chaines_de_rail(ville):
		if cases.size() < 2: continue
		var haut := _profil_du_rail(ville, cases)
		var pts := _trace_arrondi(cases, haut)
		# ⚠ UNE PILE PAR CASE, PAS UNE PAR SEGMENT. Dans un virage arrondi, huit
		# segments courts tombent sur la même case : sans ce registre, huit
		# poteaux se plantaient au même endroit.
		var posees := {}
		for k in range(1, pts.size()):
			var pa: Vector3 = pts[k - 1]
			var pb: Vector3 = pts[k]
			var milieu := (pa + pb) * 0.5
			var a := Vector2i(int(floor(milieu.x / CASE)), int(floor(milieu.z / CASE)))
			if not zone.has_point(a): continue
			var ecart := 3.2
			# ⚠⚠ « TES CHEMINS DE FER SE CASSENT DES FOIS » (client, 16/09), et
			# la faute était à moi, d'un cran en amont : les rails et les
			# traverses étaient des boîtes ALIGNÉES SUR LES AXES, posées à
			# l'altitude du milieu du tronçon. Tant que la voie était à plat
			# c'était invisible. Depuis qu'elle monte pour franchir les routes,
			# deux tronçons voisins ne sont plus à la même hauteur : chacun
			# restait horizontal, et la voie devenait un escalier de bouts de
			# rail qui ne se touchent plus — cassée, exactement.
			#
			# Le tronçon se dessine donc dans SON PROPRE REPÈRE : l'axe X suit
			# la pente réelle de A vers B, et la longueur est la vraie distance
			# en trois dimensions, pas la largeur d'une case. Deux tronçons se
			# rejoignent alors bout à bout quelle que soit la rampe.
			var av := (pb - pa)
			var longueur := av.length()
			if longueur < 0.001: continue
			av = av / longueur
			var cote := av.cross(Vector3.UP).normalized()
			var dessus := cote.cross(av).normalized()
			var base := Basis(av, dessus, cote)
			# L'ouvrage, quand la voie a quitté le sol : un tablier plein sous
			# les traverses, et des piles jusqu'au terrain.
			var sol := _sol_du_rail(ville, a)
			var creux := milieu.y - sol
			if creux > AU_SOL:
				_boite_tournee(racine, base, Vector3(longueur, 1.1, 9.4),
					milieu - dessus * 0.75, TEINTE_TABLIER_RAIL)
				if posmod(a.x + a.y, ECART_PILES_RAIL) == 0 and not posees.has(a):
					posees[a] = true
					_boite(racine, Vector3(2.6, creux, 2.6),
						Vector3(milieu.x, sol + creux * 0.5 - 0.7, milieu.z), TEINTE_TABLIER_RAIL)
			for s in [-1.0, 1.0]:
				_boite_tournee(racine, base, Vector3(longueur, 0.5, 0.6),
					milieu + cote * (ecart * s) + dessus * 0.25, TEINTE_RAIL)
			# Une traverse par tronçon : le pas est déjà celui des traverses.
			_boite_tournee(racine, base, Vector3(1.2, 0.3, 9.0),
				milieu + dessus * 0.15, TEINTE_TRAVERSE)

# ------------------------------------------------------------------ les panneaux pub

## LES 24 VISUELS DU CLIENT (cahier § 7) : sur les toits des immeubles moyens
## (cadre + poteaux courts) et sur les pignons aveugles. Plus jamais sur pieds
## au milieu d'un trottoir. Les affiches vivent dans `images/panneaux/pubNN.jpg`
## et se comptent : le client en dépose une de plus, elle est en ville.
const PUB_DOSSIER := "res://images/panneaux/"
static var _affiches: Array[String] = []
static var _pub_matieres: Dictionary = {}
static var _pub_cadre: StandardMaterial3D = null
static var _cube: BoxMesh = null

static func affiches() -> Array[String]:
	if not _affiches.is_empty(): return _affiches
	var trous := 0
	var n := 1
	while trous < 3 and n < 200:
		var chemin := PUB_DOSSIER + "pub%02d.jpg" % n
		if ResourceLoader.exists(chemin):
			_affiches.append(chemin)
			trous = 0
		else:
			trous += 1
		n += 1
	return _affiches

static func _matiere_pub(chemin: String) -> StandardMaterial3D:
	if _pub_matieres.has(chemin): return _pub_matieres[chemin]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(chemin)
	m.roughness = 0.62
	# Éclairé : faible de jour (noyé dans le soleil), lisible la nuit.
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.18
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_pub_matieres[chemin] = m
	return m

## Deux poteaux, un cadre, une affiche, l'affiche vers +Z tourné de `tour`.
## `ou` est le pied (le toit, ou le sol au pied du pignon avec `pied` = 0).
static func _panneau(parent: Node3D, ou: Vector3, tour: float, large: float, haut: float,
		pied: float, image: int) -> void:
	var liste := affiches()
	if liste.is_empty(): return
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	if _pub_cadre == null:
		_pub_cadre = StandardMaterial3D.new()
		_pub_cadre.albedo_color = Color("#2f3338")
		_pub_cadre.roughness = 0.8
	var base := Basis(Vector3.UP, tour)
	# ⚠ `Basis.scaled()` MET À L'ÉCHELLE DANS LE MONDE, PAS DANS L'OBJET. Un
	# `Basis(UP, 90°).scaled(Vector3(14, 8, 3))` étire l'axe X DU MONDE de 14 :
	# sur un panneau tourné d'un quart, le caisson sortait perpendiculaire au
	# mur — quatorze unités de profondeur, trois de large, en travers de
	# l'affiche. On met donc l'échelle AVANT la rotation.
	var boite := func(dims: Vector3, centre: Vector3) -> Transform3D:
		return Transform3D(base * Basis.from_scale(dims), centre)
	var mi_h := pied + haut * 0.5
	# ⚠ UN PANNEAU MURAL EST UN CAISSON, PAS UNE PEINTURE. Les façades Kenney
	# ont du relief — descente d'eau au milieu, bandeaux, appuis de fenêtre. Une
	# affiche plaquée au mur se faisait TRAVERSER par la descente d'eau, qui la
	# barrait de haut en bas. Le cadre d'un panneau mural est donc un caisson
	# épais : il coiffe le relief, et l'affiche se pose sur sa face avant.
	var ep := 3.2 if pied <= 0.0 else 0.5
	if pied > 0.0:
		# ⚠ DES POTEAUX QU'ON VOIE. À soixante-dix centimètres de section, un
		# poteau disparaît à la distance où l'on regarde un quartier, et le
		# panneau semble flotter — c'est exactement le défaut signalé en zone
		# industrielle le 13/09. Un vrai mât de 4 × 3 mètres en fait un bon
		# mètre ; on le dessine à un mètre vingt, et on lui ajoute sa semelle
		# de béton, qui est ce qui ancre l'objet au sol pour l'œil.
		for s in [-1.0, 1.0]:
			var n := MeshInstance3D.new()
			n.mesh = _cube
			n.material_override = _pub_cadre
			n.transform = boite.call(Vector3(1.2, pied + haut * 0.5, 1.2),
				ou + base * Vector3(s * large * 0.36, (pied + haut * 0.5) * 0.5, 0.0))
			parent.add_child(n)
		var semelle := MeshInstance3D.new()
		semelle.mesh = _cube
		semelle.material_override = _teinte_unie(Color("#8d8f8c"))
		semelle.transform = boite.call(Vector3(large * 0.86, 0.5, 3.2),
			ou + Vector3(0, 0.25, 0))
		parent.add_child(semelle)
	# ⚠ L'AFFICHE DONNE SES PROPORTIONS, PAS LE PANNEAU. `large` et `haut` ne
	# sont qu'un ENCOMBREMENT MAXIMAL (ce que le mur ou le toit peut porter) :
	# on y inscrit l'image à son format, sinon un visuel qui n'est pas en 16:9
	# sort étiré, et le client dépose ce qu'il veut dans `images/panneaux/`.
	var chemin := String(liste[posmod(image, liste.size())])
	var matiere := _matiere_pub(chemin)
	var rapport := 9.0 / 16.0
	var tex: Texture2D = matiere.albedo_texture
	if tex != null and tex.get_width() > 0:
		rapport = float(tex.get_height()) / float(tex.get_width())
	if large * rapport > haut:
		large = haut / rapport
	else:
		haut = large * rapport
	mi_h = pied + haut * 0.5
	var cadre := MeshInstance3D.new()
	cadre.mesh = _cube
	cadre.material_override = _pub_cadre
	cadre.transform = boite.call(Vector3(large + 1.0, haut + 1.0, ep), ou + Vector3(0, mi_h, 0))
	parent.add_child(cadre)
	var toile := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(large, haut)
	toile.mesh = q
	toile.material_override = matiere
	toile.transform = Transform3D(base, ou + Vector3(0, mi_h, 0) + base * Vector3(0, 0, ep * 0.5 + 0.06))
	toile.set_meta("modele", "pub")
	parent.add_child(toile)

## ⚠ UNE ENSEIGNE AU NÉON, PAS UN PANNEAU. Le client demande « pas assez de
## néon » dans le quartier chaud, et une affiche de plus n'y répondrait pas :
## une pub est une IMAGE mate qu'on éclaire, un néon est une SOURCE. Ce qui
## fait le quartier la nuit, c'est la couleur saturée posée à hauteur de
## premier étage, répétée sur chaque façade — pas la surface imprimée.
##
## Un caisson sombre, une face émissive devant. L'émissif porte en mode
## compatibilité (WebGL 2) là où une vraie lumière ne porterait pas : le moteur
## n'en accepte que huit par objet, et une rue en compte quarante.
const TEINTE_CAISSON := Color("#23252a")

static func _enseigne(parent: Node3D, ou: Vector3, tour: float, large: float,
		haut: float, couleur: String) -> void:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	var base := Basis(Vector3.UP, tour)
	var caisson := MeshInstance3D.new()
	caisson.mesh = _cube
	caisson.material_override = _teinte_unie(TEINTE_CAISSON)
	caisson.transform = Transform3D(base * Basis.from_scale(
		Vector3(large + 0.5, haut + 0.5, 0.7)), ou)
	parent.add_child(caisson)
	var tube := MeshInstance3D.new()
	tube.mesh = _cube
	tube.material_override = _neon_matiere(couleur)
	tube.transform = Transform3D(base * Basis.from_scale(Vector3(large, haut, 0.35)),
		ou + base * Vector3(0, 0, 0.45))
	tube.set_meta("modele", "neon")
	parent.add_child(tube)

static var _neons: Dictionary = {}

static func _neon_matiere(couleur: String) -> StandardMaterial3D:
	if _neons.has(couleur): return _neons[couleur]
	var c := Color(couleur)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	# Fort : c'est ce qui passe le seuil du halo et fait la flaque de couleur
	# sur la façade voisine. Un néon discret ne se voit pas de nuit, et c'est
	# de nuit que ce quartier se juge.
	m.emission_energy_multiplier = 2.4
	m.roughness = 0.5
	_neons[couleur] = m
	return m

# ------------------------------------------------------------------ le bord de mer

## UNE PLATEFORME SUR PILOTIS : le tablier d'une jetée ou d'un ponton. Le
## tablier est posé à `y` au-dessus du niveau de la mer, les pilotis
## descendent jusqu'au fond — c'est ce qui fait qu'une jetée a l'air POSÉE sur
## l'eau et non peinte dessus.
const TEINTE_TABLIER := Color("#c9c3b4")
const TEINTE_PILOTIS := Color("#6b5a44")

static func _plateforme(parent: Node3D, ou: Vector3, tourne: float, largeur: float,
		profondeur: float, y: float) -> void:
	var base := Basis(Vector3.UP, tourne)
	var haut := ou + Vector3(0, y, 0)
	_boite_tournee(parent, base, Vector3(largeur, 0.7, profondeur), haut, TEINTE_TABLIER)
	# Un pilotis tous les six unités le long de la jetée, par paires.
	var n := maxi(2, int(profondeur / 6.0))
	var fond := TerrainV2.NIVEAU_MER - 3.0
	var hauteur := (haut.y - 0.35) - fond
	for k in n:
		var t := (float(k) + 0.5) / float(n) - 0.5
		for s in [-1.0, 1.0]:
			var p := haut + base * Vector3(s * (largeur * 0.5 - 0.9), 0, t * profondeur)
			_boite_tournee(parent, base, Vector3(0.9, hauteur, 0.9),
				Vector3(p.x, fond + hauteur * 0.5, p.z), TEINTE_PILOTIS)

## LE TABLIER D'AUTOROUTE : une dalle et ses deux bordures. `ou` est DÉJÀ à
## l'altitude du tablier (posé par `y_abs`) — le tablier ne cherche pas le sol,
## c'est la pile qui l'atteint.
const TEINTE_VIADUC := Color("#b9bcc0")
const TEINTE_PILE := Color("#a2a6ab")
const BORDURE := 0.55

## ⭐⭐⭐ LE TABLIER D'UN TRAIT, ET PLUS EN CUBES.
##
## « Tes autoroutes sur les ponts sont vraiment mal faites, tu as des trucs qui
## passent à travers chaque cube » (client, 16/09). Le mot était exact : le
## tablier ÉTAIT une file de cubes. Une dalle par case, chacune posée à plat à
## l'altitude de sa propre case, chacune avec ses deux bordures qui s'arrêtaient
## et repartaient. Résultat : un joint visible tous les vingt mètres, une marche
## à chaque changement de pente, et les bouts de bordure dessinant une échelle
## en travers de la chaussée.
##
## Le tablier se dessine maintenant comme la voie ferrée : segment par segment,
## chacun dans SON repère — l'axe X suit la pente réelle d'un point au suivant,
## et la longueur est la vraie distance en trois dimensions. Deux segments se
## rejoignent alors bout à bout, et les bordures deviennent deux lignes continues
## au lieu de quarante bouts.
##
## ⚠ ET ILS SE CHEVAUCHENT D'UN CHEVEU. Deux boîtes qui se touchent PILE laissent
## voir un trait de fond entre elles dès que l'angle change : on les rallonge de
## `RECOUVRE` de chaque côté, ce qui noie le joint dans la matière.
const RECOUVRE := 0.35

static func _viaduc_ruban(parent: Node3D, pts: Array, largeur: float) -> void:
	for k in range(1, pts.size()):
		var a: Array = pts[k - 1]
		var b: Array = pts[k]
		var pa := Vector3(float(a[0]), float(a[1]), float(a[2]))
		var pb := Vector3(float(b[0]), float(b[1]), float(b[2]))
		var av := pb - pa
		var longueur := av.length()
		if longueur < 0.001: continue
		av = av / longueur
		var cote := av.cross(Vector3.UP).normalized()
		var dessus := cote.cross(av).normalized()
		var base := Basis(av, dessus, cote)
		var milieu := (pa + pb) * 0.5
		_boite_tournee(parent, base, Vector3(longueur + RECOUVRE, 0.8, largeur),
			milieu, TEINTE_VIADUC)
		for si in [-1.0, 1.0]:
			_boite_tournee(parent, base, Vector3(longueur + RECOUVRE, 1.1, BORDURE),
				milieu + cote * (si * (largeur * 0.5 - BORDURE * 0.5)) + dessus * 0.85,
				TEINTE_VIADUC)

static func _viaduc(parent: Node3D, ou: Vector3, tourne: float, largeur: float,
		profondeur: float) -> void:
	var base := Basis(Vector3.UP, tourne)
	_boite_tournee(parent, base, Vector3(largeur, 0.8, profondeur), ou, TEINTE_VIADUC)
	# Les deux bordures : sans elles le tablier est une planche, et une voiture
	# qui roule dessus semble flotter au-dessus du vide.
	for s in [-1.0, 1.0]:
		var p := ou + base * Vector3(s * (largeur * 0.5 - BORDURE * 0.5), 0.85, 0)
		_boite_tournee(parent, base, Vector3(BORDURE, 1.1, profondeur), p, TEINTE_VIADUC)

## LA PILE : une colonne du sol au tablier. `ou` est au sol, `sommet` est
## l'altitude du tablier.
static func _pile(parent: Node3D, ou: Vector3, largeur: float, sommet: float) -> void:
	var haut := sommet - 0.4 - ou.y
	if haut <= 0.5: return
	_boite_tournee(parent, Basis(), Vector3(largeur, haut, largeur),
		Vector3(ou.x, ou.y + haut * 0.5, ou.z), TEINTE_PILE)

## LA GRANDE ROUE (cahier § 3 : « une jetée avec bar et grande roue »). Le kit
## n'en a pas : deux jantes, des rayons, des nacelles et deux jambes en A.
const TEINTE_ROUE := Color("#e8e4dc")
const NACELLES := [Color("#ff2f86"), Color("#ff9040"), Color("#2fe0d0"), Color("#ffe14d")]

static func _grande_roue(parent: Node3D, ou: Vector3, tourne: float, diametre: float) -> void:
	var base := Basis(Vector3.UP, tourne)
	var r := diametre * 0.5
	var moyeu := ou + Vector3(0, r + 3.0, 0)
	# Les deux jambes : un A de chaque côté du moyeu.
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			var pied := ou + base * Vector3(t * r * 0.45, 0, s * 3.2)
			var haut := moyeu + base * Vector3(0, 0, s * 1.6)
			_poutre(parent, pied, haut, 1.2, TEINTE_PILOTIS)
	# Les deux jantes et leurs rayons.
	var pas := 16
	for s in [-1.0, 1.0]:
		var centre := moyeu + base * Vector3(0, 0, s * 1.6)
		for k in pas:
			var a := TAU * float(k) / float(pas)
			var b := TAU * float(k + 1) / float(pas)
			var pa := centre + base * Vector3(cos(a) * r, sin(a) * r, 0)
			var pb := centre + base * Vector3(cos(b) * r, sin(b) * r, 0)
			_poutre(parent, pa, pb, 0.6, TEINTE_ROUE)
			if k % 2 == 0:
				_poutre(parent, centre, pa, 0.4, TEINTE_ROUE)
	# Les nacelles, accrochées au bord.
	for k in pas:
		var a := TAU * float(k) / float(pas)
		var p := moyeu + base * Vector3(cos(a) * r, sin(a) * r, 0)
		_boite_tournee(parent, base, Vector3(2.4, 2.0, 3.4), p - Vector3(0, 1.6, 0),
			NACELLES[k % NACELLES.size()])

## Une poutre entre deux points : une boîte orientée le long du segment.
static func _poutre(parent: Node3D, a: Vector3, b: Vector3, section: float, teinte: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01: return
	var axe := d / l
	var cote := Vector3.UP.cross(axe)
	if cote.length_squared() < 1.0e-6: cote = Vector3.RIGHT
	cote = cote.normalized()
	var base := Basis(cote, axe, cote.cross(axe)).orthonormalized()
	_boite_tournee(parent, base, Vector3(section, l, section), a + d * 0.5, teinte)

static func _boite_tournee(parent: Node3D, base: Basis, dims: Vector3, ou: Vector3, teinte: Color) -> void:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	var n := MeshInstance3D.new()
	n.mesh = _cube
	n.material_override = _teinte_unie(teinte)
	# ⚠ L'ÉCHELLE AVANT LA ROTATION (voir `_panneau`) : `Basis.scaled()` met à
	# l'échelle dans le monde, et une poutre en biais sortait de travers.
	n.transform = Transform3D(base * Basis.from_scale(dims), ou)
	parent.add_child(n)

static var _unies: Dictionary = {}

static func _teinte_unie(teinte: Color) -> StandardMaterial3D:
	var cle := teinte.to_html()
	if _unies.has(cle): return _unies[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
	m.roughness = 0.9
	_unies[cle] = m
	return m

## UN BATEAU À FLOT : la coque posée à la ligne de flottaison, enfoncée de son
## tirant d'eau. Sans le tirant, une coque flottait deux mètres au-dessus de
## la mer, et un cargo avait l'air d'un jouet posé sur une vitre.
static func _bateau(parent: Node3D, nom: String, ou: Vector3, tourne: float) -> void:
	var fiche: Dictionary = KitVille2.BATEAUX.get(nom, {})
	if fiche.is_empty(): return
	var chemin := KitVille2.chemin(String(fiche["m"]))
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	# Les coques sont longues selon Z : on demande la longueur sur cet axe.
	n.mesh = FormesCarnage.maillage_kenney(chemin, float(fiche["l"]), Vector3.AXIS_Z, 0.0)
	n.material_override = _matiere(chemin, Color.WHITE)
	n.transform = Transform3D(Basis(Vector3.UP, tourne),
		Vector3(ou.x, TerrainV2.NIVEAU_MER - float(fiche["tirant"]), ou.z))
	n.set_meta("modele", "bateau:" + nom)
	_noter(chemin)
	parent.add_child(n)

## Une pelouse : un plan vert, posé un rien au-dessus de la dalle.
const TEINTE_PELOUSE := Color("#5d9a3c")

## ⚠ LA COULEUR DEMANDÉE, PAS LA COULEUR PAR DÉFAUT. Le générateur du campus
## passait `VERT_PELOUSE` (un vert tondu, plus franc que l'herbe du terrain)
## depuis le premier jour, et la pelouse sortait quand même de la couleur de
## la constante : le paramètre était ignoré. Une pelouse de stade de la même
## couleur que le pré d'à côté ne se voit pas — et un stade dont on ne voit pas
## la pelouse n'est pas un stade.
static func _pelouse(parent: Node3D, ou: Vector3, largeur: float, profondeur: float,
		teinte := "") -> void:
	var n := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(largeur, profondeur)
	n.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(teinte) if teinte != "" else TEINTE_PELOUSE
	m.roughness = 1.0
	n.material_override = m
	n.position = ou + Vector3(0, 0.06, 0)
	n.set_meta("modele", "pelouse")
	parent.add_child(n)

static func _boite(racine: Node3D, dims: Vector3, ou: Vector3, teinte: Color) -> void:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = dims
	n.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
	m.roughness = 0.9
	n.material_override = m
	n.position = ou
	racine.add_child(n)

# ------------------------------------------------------------------ outils

static func _tuile(parent: Node3D, nom: String, ou: Vector3, quarts: int,
		teinte := Color.WHITE, cases := 1.0) -> void:
	var chemin := ROUTES + nom + ".glb"
	if not ResourceLoader.exists(chemin):
		push_warning("tuile absente : " + chemin)
		return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	n.material_override = _matiere(chemin, teinte)
	# ⚠ LA TUILE DÉBORDE DE SA CASE, EXPRÈS. Une tuile Kenney mesure exactement
	# une case (mesuré : 1,0000 x 1,0000, centrée sur son origine) — donc deux
	# tuiles voisines se touchent pile. Mais leur dessus est BISEAUTÉ : le
	# chanfrein de l'une plus celui de l'autre font, vu du ciel, un LISERÉ CLAIR
	# à chaque joint, et toute la ville se lit comme un damier de dalles
	# séparées (« aucune route n'est collée, on voit l'écart entre deux
	# routes », client, 12/09). Un chouïa d'échelle en plus et le biseau d'une
	# tuile passe SOUS le dessus plat de sa voisine : le joint disparaît, sans
	# rien déplacer et sans z-fighting — le chanfrein est plus bas que la face
	# qui le couvre.
	# Une case sur deux descend d'un cheveu : voir `DECALAGE_DAMIER`.
	var damier := float((posmod(roundi(ou.x / CASE) + roundi(ou.z / CASE), 2)))
	n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(quarts)).scaled(
		Vector3.ONE * CASE * RECOUVREMENT * cases),
		ou - Vector3(0.0, damier * DECALAGE_DAMIER, 0.0))
	n.set_meta("tuile", nom)
	_noter(chemin)
	parent.add_child(n)

const ATLAS := preload("res://commun/ville2/atlas.gd")

## La matière d'un modèle dont on a repeint la bande de toiture.
static func _matiere_toit(chemin: String, teinte: Color, toit: String) -> Material:
	var cle := chemin + teinte.to_html() + "|t" + toit
	if _matieres.has(cle): return _matieres[cle]
	var m := FormesCarnage.matiere_kenney(chemin).duplicate()
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("teinte", teinte)
		var source: Texture2D = sm.get_shader_parameter("atlas")
		sm.set_shader_parameter("atlas", ATLAS.toiture(source, Color(toit)))
	elif m is BaseMaterial3D:
		# Pas d'atlas (couleur de sommet) : on ne peut pas isoler le toit.
		(m as BaseMaterial3D).albedo_color = teinte
	_matieres[cle] = m
	return m

static func _matiere(chemin: String, teinte: Color) -> Material:
	var cle := chemin + teinte.to_html()
	if _matieres.has(cle): return _matieres[cle]
	var m := FormesCarnage.matiere_kenney(chemin).duplicate()
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("teinte", teinte)
	elif m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = teinte
	_matieres[cle] = m
	return m

static func _noter(chemin: String) -> void:
	if not inventaire: return
	poses[chemin] = int(poses.get(chemin, 0)) + 1
