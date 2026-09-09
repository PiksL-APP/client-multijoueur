class_name Interieurs
extends RefCounted
## Les INTÉRIEURS des repaires de Carnage : ce qu'on achète, et ce qu'on voit
## une fois la porte franchie.
##
## Pourquoi un kit importé alors que la ville est en voxels : un repaire se
## regarde de près, et de près un canapé en cubes d'un mètre n'est plus un
## canapé. Le Furniture Kit de Kenney (CC0) est du lowpoly à facettes plates,
## sans texture — que des matières nommées (`wood`, `carpet`, `_defaultMat`) —
## donc il se REPEINT par intérieur : le même canapé sort rouge au taudis et
## anthracite au penthouse, et rien ne trahit le kit d'un appartement à l'autre.
##
## Le plan est un DESSIN, pas une liste de rectangles : une grille de
## `2·largeur+1` sur `2·hauteur+1` caractères où les cases impaires sont les
## tuiles et les paires les arêtes. On relit un appartement d'un coup d'œil, et
## une porte déplacée est un caractère dans le diff — c'était la condition pour
## en tenir huit dans un fichier.
##
## ⚠ Une tuile du kit fait UNE unité de modèle et DEUX mètres de jeu : `ECHELLE`
## est appliquée à la racine. Sans elle, un mur de 1,29 arrive à la taille de la
## hanche du personnage (1,80 unité de jeu).

## Une tuile de kit vaut deux unités de jeu. Le personnage Kenney fait 1,80 :
## un plafond à 1,29 × 2 = 2,58 le laisse passer avec l'air qu'il faut.
const ECHELLE := 2.0
const MOBILIER := "res://modeles/kenney/interieur/%s.glb"
const NOURRITURE := "res://modeles/kenney/nourriture/%s.glb"
## Ce qui n'est pas Kenney : fabriqué par `outils/coffre.py`, préfixé `c:`.
const MAISON := "res://modeles/interieur/%s.glb"
## LE meuble qui compte : c'est là que le joueur dépose son argent. Chaque
## repaire en a exactement un, et `batir()` le signale par un méta sur la
## racine — le jeu n'a pas à fouiller la scène pour le retrouver.
const COFFRE := "c:coffre"
## Hauteur d'un mur du kit, en unités de modèle : tout ce qui se suspend s'y
## rapporte (plafonnier, ventilateur).
const HAUT := 1.29

## Le kit de nourriture n'est pas à la même échelle que le mobilier : une pomme
## y fait vingt centimètres. Réduite d'un facteur cinq et demi, elle rentre dans
## la main — sans ça une boîte à pizza couvre la table entière.
const ECHELLE_NOURRITURE := 0.18

## LA convention du kit, et elle ne se devine pas : la façade d'un modèle Kenney
## regarde +Z. Pas −Z, l'avant habituel d'un moteur 3D — +Z. Un placard montre
## ses portes du côté sud, une télé son écran, un canapé son assise, et le
## volume du modèle part donc vers l'ARRIÈRE, en −Z.
##
## Ça s'est payé cher : `contre()` posait tout à l'envers, chaque meuble adossé
## regardait sa propre cloison, et sur une vue de trois quarts ça ne se voit
## pas — un placard vu de dos et vu de face ont la même silhouette. La table
## est vérifiable : `outils/faces.gd` photographie les 74 modèles depuis le nord
## PUIS depuis le sud ; la face qui montre les poignées est celle du sud.

static var _scenes := {}
static var _gabarits := {}

# ------------------------------------------------------------ le kit

static func _chemin(nom: String) -> String:
	if nom.begins_with("n:"):
		return NOURRITURE % nom.substr(2)
	if nom.begins_with("c:"):
		return MAISON % nom.substr(2)
	return MOBILIER % nom

static func _scene(nom: String) -> PackedScene:
	if not _scenes.has(nom):
		_scenes[nom] = load(_chemin(nom))
	return _scenes[nom]

static func _facteur(nom: String) -> float:
	return ECHELLE_NOURRITURE if nom.begins_with("n:") else 1.0

## L'encombrement d'un modèle, mesuré une fois. C'est lui qui permet d'écrire
## « contre le mur nord » sans connaître la profondeur du meuble : la donnée
## reste lisible et le calcul ne se répète pas dans huit appartements.
static func gabarit(nom: String) -> AABB:
	var b := _brut(nom)
	var f := _facteur(nom)
	return AABB(b.position * f, b.size * f)

static func _brut(nom: String) -> AABB:
	if _gabarits.has(nom):
		return _gabarits[nom]
	var inst: Node = _scene(nom).instantiate()
	var boite := [AABB(), false]
	_cumuler(inst, Transform3D(), boite)
	inst.free()
	_gabarits[nom] = boite[0]
	return boite[0]

static func _cumuler(noeud: Node, t: Transform3D, boite: Array) -> void:
	var t2 := t
	if noeud is Node3D:
		t2 = t * (noeud as Node3D).transform
	if noeud is VisualInstance3D:
		var b: AABB = t2 * (noeud as VisualInstance3D).get_aabb()
		boite[0] = b if not boite[1] else (boite[0] as AABB).merge(b)
		boite[1] = true
	for enfant in noeud.get_children():
		_cumuler(enfant, t2, boite)

# ------------------------------------------------------------ les collisions

## CE QUI ARRÊTE LE JOUEUR, déduit du MÊME dessin que ce qui se voit.
##
## C'est le parti du hub (`modeles/voxel/plan.json`) : le décor et les murs
## sortent d'une seule source, donc ils ne peuvent pas diverger. Une table de
## collisions écrite à la main à côté du plan aurait vieilli au premier meuble
## déplacé, et personne ne s'en serait aperçu avant de traverser un canapé.
##
## ⚠ TOUT CE QUI SUIT EST EN TUILES, comme le dessin et comme `coffre()` — pas
## en unités de monde ni en pixels de jeu. L'appelant multiplie par `ECHELLE`.
## Mélanger les deux repères est l'erreur qui coûte le plus cher ici : elle ne
## se voit pas, elle donne juste des murs deux fois trop loin.

## Le demi-encombrement du personnage, en tuiles. Une tuile fait deux mètres :
## 0,14 fait donc un bonhomme de 56 cm de large, épaules comprises — la mesure
## d'un adulte, pas celle de sa boîte englobante.
## ⚠ Essayé à 0,22 (88 cm) d'abord, en croyant prendre une marge : le banc a
## déclaré les huit repaires impraticables, portes comprises. Une porte du kit
## n'ouvre que sur 0,8 tuile, et le joueur n'y passait plus.
const RAYON_MARCHE := 0.14

## Un meuble plus bas que ça ne bloque pas : c'est un tapis, un magazine, une
## assiette. Mesuré sur le modèle, jamais deviné — le kit mélange allègrement
## les échelles, et lister à la main ce qui bloque, c'est une liste à tenir.
const HAUTEUR_OBSTACLE := 0.30

## Les arêtes qu'on FRANCHIT. Tout le reste du dessin (mur plein, fenêtre,
## muret) arrête : on ne saute pas par la fenêtre d'un repaire.
const PASSAGES := ["D", "A"]

static var _collisions := {}

## L'emprise au sol de chaque meuble bloquant, en tuiles.
## Les quarts de tour sont les seules rotations du plan : une emprise reste
## donc TOUJOURS alignée sur les axes — il suffit d'échanger largeur et
## profondeur pour un quart impair. C'est ce qui permet des `Rect2` partout au
## lieu de rectangles tournés, et un test dix fois plus court.
static func obstacles(id: String) -> Array:
	return _table(id)["obstacles"]

## Les tuiles où l'on a le droit d'être, et les arêtes qui bloquent.
static func murs(id: String) -> Dictionary:
	return _table(id)["murs"]

static func _table(id: String) -> Dictionary:
	if _collisions.has(id):
		return _collisions[id]
	var fiche := plan(id)
	var dessin: Array = fiche["plan"]
	var haut := (dessin.size() - 1) / 2
	var large := (String(dessin[0]).length() - 1) / 2
	var tuiles := {}
	for l in haut:
		for c in large:
			if _car(dessin, 2 * l + 1, 2 * c + 1) != " ":
				tuiles[Vector2i(c, l)] = true
	var liste: Array = []
	for m in fiche.get("meubles", []):
		var rect: Variant = _emprise(m)
		if rect != null:
			liste.append(rect)
	var t := {"murs": {"tuiles": tuiles, "large": large, "haut": haut, "dessin": dessin},
		"obstacles": liste}
	_collisions[id] = t
	return t

## L'emprise d'une ligne de meuble, ou `null` s'il ne bloque pas.
static func _emprise(m: Array):
	var nom := String(m[0])
	var taille: float = float(m[5]) if m.size() > 5 else 1.0
	var y: float = float(m[4]) if m.size() > 4 else 0.0
	var b := gabarit(nom)
	var hauteur: float = b.size.y * taille
	# Posé sur une table ou pendu au plafond : on passe dessous ou à côté, et
	# le bloquer condamnait la moitié d'une cuisine à cause d'une casserole.
	if y > 0.01 or hauteur < HAUTEUR_OBSTACLE:
		return null
	var demi := Vector2(b.size.x, b.size.z) * taille * 0.5
	if int(m[3]) % 2 == 1:
		demi = Vector2(demi.y, demi.x)
	# Un meuble déborde un peu moins que son gabarit : les modèles Kenney
	# portent des poignées et des coussins dans leur boîte, et s'arrêter à la
	# boîte fait buter le joueur dix centimètres avant le meuble.
	demi *= 0.92
	return Rect2(Vector2(float(m[1]), float(m[2])) - demi, demi * 2.0)

## Peut-on tenir DEBOUT là, avec ce rayon ? C'est la question qu'on pose au
## dessin ; `degager` s'en sert pour repousser.
static func libre(id: String, p: Vector2, rayon: float = RAYON_MARCHE) -> bool:
	var t := _table(id)
	var m: Dictionary = t["murs"]
	var c := Vector2i(floori(p.x), floori(p.y))
	if not (m["tuiles"] as Dictionary).has(c):
		return false
	# Les quatre côtés de la tuile : un côté fermé doit rester à plus d'un
	# rayon. On teste la TUILE et non le monde entier — c'est ce qui rend le
	# test constant quelle que soit la taille de l'appartement.
	if _ferme(m, c, 0) and p.y - float(c.y) < rayon: return false
	if _ferme(m, c, 1) and float(c.y) + 1.0 - p.y < rayon: return false
	if _ferme(m, c, 2) and p.x - float(c.x) < rayon: return false
	if _ferme(m, c, 3) and float(c.x) + 1.0 - p.x < rayon: return false
	for r in t["obstacles"]:
		if (r as Rect2).grow(rayon).has_point(p):
			return false
	return true

## Le côté `k` de la tuile est-il fermé ? 0 nord, 1 sud, 2 ouest, 3 est.
## Fermé = une arête qui n'est pas une porte, OU le vide de l'autre côté (un
## dessin peut très bien oublier un mur au bord ; on ne sort pas pour autant).
static func _ferme(m: Dictionary, c: Vector2i, k: int) -> bool:
	var dessin: Array = m["dessin"]
	var voisine: Vector2i = c + [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)][k]
	if not (m["tuiles"] as Dictionary).has(voisine):
		return true
	var car := ""
	match k:
		0: car = _car(dessin, 2 * c.y, 2 * c.x + 1)
		1: car = _car(dessin, 2 * c.y + 2, 2 * c.x + 1)
		2: car = _car(dessin, 2 * c.y + 1, 2 * c.x)
		_: car = _car(dessin, 2 * c.y + 1, 2 * c.x + 2)
	return ARETES.has(car) and not (car in PASSAGES)

## Repousse un point hors des murs et des meubles. Deux passes : la première
## sort des meubles, la seconde recolle aux murs — dans l'autre ordre, un
## joueur poussé par une armoire finissait DANS la cloison derrière.
static func degager(id: String, p: Vector2, rayon: float = RAYON_MARCHE) -> Vector2:
	var t := _table(id)
	var m: Dictionary = t["murs"]
	var point := p
	for _passe in 2:
		for r in t["obstacles"]:
			point = _hors_du_rect(point, r as Rect2, rayon)
		point = _dans_la_piece(point, m, rayon)
	return point

static func _hors_du_rect(p: Vector2, r: Rect2, rayon: float) -> Vector2:
	var g := r.grow(rayon)
	if not g.has_point(p):
		return p
	# On sort par le plus PETIT chevauchement : c'est ce qui fait glisser le
	# long d'un meuble au lieu de se faire téléporter de l'autre côté.
	var gauche := p.x - g.position.x
	var droite := g.end.x - p.x
	var haut := p.y - g.position.y
	var bas := g.end.y - p.y
	var mini_ := minf(minf(gauche, droite), minf(haut, bas))
	if mini_ == gauche: return Vector2(g.position.x, p.y)
	if mini_ == droite: return Vector2(g.end.x, p.y)
	if mini_ == haut: return Vector2(p.x, g.position.y)
	return Vector2(p.x, g.end.y)

static func _dans_la_piece(p: Vector2, m: Dictionary, rayon: float) -> Vector2:
	var point := p
	var c := Vector2i(floori(point.x), floori(point.y))
	if not (m["tuiles"] as Dictionary).has(c):
		# Déjà dehors : on rejoint le centre de la tuile habitable la plus
		# proche. Ça n'arrive qu'au premier pas d'une téléportation ratée,
		# mais laisser le joueur dehors le fait tomber dans le vide.
		var mieux := Vector2i.ZERO
		var trouve := false
		for k in (m["tuiles"] as Dictionary).keys():
			var d := Vector2(k) + Vector2(0.5, 0.5)
			if not trouve or d.distance_to(point) < (Vector2(mieux) + Vector2(0.5, 0.5)).distance_to(point):
				mieux = k
				trouve = true
		return Vector2(mieux) + Vector2(0.5, 0.5) if trouve else point
	if _ferme(m, c, 0): point.y = maxf(point.y, float(c.y) + rayon)
	if _ferme(m, c, 1): point.y = minf(point.y, float(c.y) + 1.0 - rayon)
	if _ferme(m, c, 2): point.x = maxf(point.x, float(c.x) + rayon)
	if _ferme(m, c, 3): point.x = minf(point.x, float(c.x) + 1.0 - rayon)
	return point

## PAR OÙ L'ON ENTRE : la première porte du dessin qui donne sur le vide, et la
## tuile de l'autre côté. Le jeu y pose le joueur, et le banc de marche y
## commence son inondation.
static func entree(id: String) -> Vector2:
	var m: Dictionary = _table(id)["murs"]
	var dessin: Array = m["dessin"]
	var tuiles: Dictionary = m["tuiles"]
	for c: Vector2i in tuiles.keys():
		for k in 4:
			var d: Vector2i = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)][k]
			if tuiles.has(c + d):
				continue
			var car := ""
			match k:
				0: car = _car(dessin, 2 * c.y, 2 * c.x + 1)
				1: car = _car(dessin, 2 * c.y + 2, 2 * c.x + 1)
				2: car = _car(dessin, 2 * c.y + 1, 2 * c.x)
				_: car = _car(dessin, 2 * c.y + 1, 2 * c.x + 2)
			if car in PASSAGES:
				return Vector2(c) + Vector2(0.5, 0.5)
	# Pas de porte sur l'extérieur : on entre au milieu, c'est mieux que rien.
	return Vector2(float(m["large"]) * 0.5, float(m["haut"]) * 0.5)

# ------------------------------------------------------------ écriture d'une fiche

## Un meuble posé librement : `(x, z)` est le CENTRE de son emprise au sol, en
## tuiles, et `r` son quart de tour (0 regarde le nord, 1 l'ouest, 2 le sud,
## 3 l'est — la façade regarde +Z à `r = 0`, cf. la note de `A_ENVERS`
## ci-dessus). `y` sert à ce qui se pose sur un plan ou se pend au plafond, et
## `taille` à rattraper un modèle du kit qui sort trop grand ou trop petit —
## toutes ces valeurs se reprennent À LA MAIN, ligne par ligne, et une photo
## suffit à vérifier (`outils/vitrine.sh <intérieur>`).
static func pose(nom: String, x: float, z: float, r: int = 0, y: float = 0.0, taille: float = 1.0) -> Array:
	return [nom, x, z, r, y, taille]

## Un meuble ADOSSÉ : `cote` est le mur de la pièce contre lequel il vient
## (N/S/O/E), `u` sa position LE LONG de ce mur et `mur` la ligne du mur. Le
## meuble se retourne vers la pièce et se colle à la cloison tout seul —
## écrire la profondeur à la main, c'est la réécrire à chaque essai.
static func contre(nom: String, cote: String, u: float, mur: float, decal: float = 0.0,
		y: float = 0.0, taille: float = 1.0) -> Array:
	var prof: float = gabarit(nom).size.z * taille
	# Façade en +Z : contre le mur NORD, un meuble ne tourne pas du tout ; il
	# regarde déjà la pièce. C'est l'inverse de ce que l'intuition dicte.
	match cote:
		"N": return [nom, u, mur + prof * 0.5 + decal, 0, y, taille]
		"S": return [nom, u, mur - prof * 0.5 - decal, 2, y, taille]
		"O": return [nom, mur + prof * 0.5 + decal, u, 1, y, taille]
		_:   return [nom, mur - prof * 0.5 - decal, u, 3, y, taille]

# ------------------------------------------------------------ construction

## Bâtit l'intérieur `id` : coque (sols, murs, portes, fenêtres), meubles,
## lumières. Le nœud rendu est à l'échelle du JEU — on l'ajoute tel quel sous
## `monde()`, l'origine au coin nord-ouest du plan.
static func batir(id: String) -> Node3D:
	var fiche: Dictionary = plan(id)
	var racine := Node3D.new()
	racine.name = "Interieur_" + id
	racine.scale = Vector3.ONE * ECHELLE
	var teintes: Dictionary = fiche.get("teintes", {})
	_coque(racine, fiche, teintes)
	for m in fiche.get("meubles", []):
		var noeud := _instancier(String(m[0]), teintes if fiche.get("teindre_tout", false) else fiche.get("teintes_meubles", {}))
		noeud.position = Vector3(float(m[1]), float(m[4]), float(m[2]))
		noeud.rotation.y = int(m[3]) * PI * 0.5
		if m.size() > 5:
			noeud.scale *= float(m[5])
		if String(m[0]) == COFFRE:
			noeud.name = "Coffre"
			racine.set_meta("coffre", noeud.position)
		racine.add_child(noeud)
	for f in fiche.get("lumieres", []):
		var l := OmniLight3D.new()
		l.position = Vector3(float(f[0]), HAUT * 0.82, float(f[1]))
		l.light_color = f[2]
		l.omni_range = float(f[3])
		l.light_energy = float(f[4]) if f.size() > 4 else 1.4
		l.shadow_enabled = false
		racine.add_child(l)
	return racine

## Le dessin devient des murs. Une arête vaut un modèle du kit ; un point de
## grille où deux murs se rencontrent reçoit un poteau, sans quoi chaque angle
## laisse voir un carré de cinq centimètres — et par-dessus une caméra de trois
## quarts, ce carré se remarque.
static func _coque(racine: Node3D, fiche: Dictionary, teintes: Dictionary) -> void:
	var dessin: Array = fiche["plan"]
	var hauteur := (dessin.size() - 1) / 2
	var largeur := (String(dessin[0]).length() - 1) / 2
	var sols: Array = fiche.get("sols", ["wood"])
	for l in hauteur:
		for c in largeur:
			var t := _car(dessin, 2 * l + 1, 2 * c + 1)
			if t == " ":
				continue
			var sol := _instancier("floorFull", _sol_teinte(teintes, sols, t))
			sol.position = Vector3(c + 0.5, 0, l + 0.5)
			racine.add_child(sol)
	var aretes := {}
	for l in hauteur + 1:
		for c in largeur:
			var d := Vector2(0, -1) if _car(dessin, 2 * l - 1, 2 * c + 1) == " " else (
				Vector2(0, 1) if _car(dessin, 2 * l + 1, 2 * c + 1) == " " else Vector2.ZERO)
			_arete(racine, aretes, teintes, _car(dessin, 2 * l, 2 * c + 1), c + 0.5, float(l), 0, d,
				Vector2i(2 * c + 1, 2 * l))
	for l in hauteur:
		for c in largeur + 1:
			var d := Vector2(-1, 0) if _car(dessin, 2 * l + 1, 2 * c - 1) == " " else (
				Vector2(1, 0) if _car(dessin, 2 * l + 1, 2 * c + 1) == " " else Vector2.ZERO)
			_arete(racine, aretes, teintes, _car(dessin, 2 * l + 1, 2 * c), float(c), l + 0.5, 1, d,
				Vector2i(2 * c, 2 * l + 1))
	_poteaux(racine, aretes, teintes, dessin, largeur, hauteur)

const ARETES := {"-": "wall", "|": "wall", "D": "wallDoorway", "A": "wallDoorwayWide",
	"F": "wallWindow", "B": "wallWindowSlide", "H": "wallHalf"}

## `dehors` dit vers où ce mur donne sur le vide (zéro s'il sépare deux pièces).
## C'est ce qui permet, vue de trois quarts, d'escamoter les deux façades qui
## sont entre la caméra et le salon — sans ça on photographie une boîte fermée.
static func _arete(racine: Node3D, aretes: Dictionary, teintes: Dictionary, car: String,
		x: float, z: float, r: int, dehors: Vector2, cle: Vector2i) -> void:
	if not ARETES.has(car):
		return
	var mur := _instancier(ARETES[car], teintes)
	mur.position = Vector3(x, 0, z)
	mur.rotation.y = r * PI * 0.5
	mur.set_meta("dehors", dehors)
	racine.add_child(mur)
	aretes[cle] = mur

static func _poteaux(racine: Node3D, aretes: Dictionary, teintes: Dictionary, dessin: Array,
		largeur: int, hauteur: int) -> void:
	var boite := BoxMesh.new()
	boite.size = Vector3(0.062, HAUT, 0.062)
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = teintes.get("_defaultMat", Color(1, 1, 1))
	matiere.roughness = 0.9
	for l in hauteur + 1:
		for c in largeur + 1:
			var voisins := []
			for cle in [Vector2i(2 * c - 1, 2 * l), Vector2i(2 * c + 1, 2 * l),
					Vector2i(2 * c, 2 * l - 1), Vector2i(2 * c, 2 * l + 1)]:
				if aretes.has(cle):
					voisins.append(aretes[cle])
			if voisins.is_empty():
				continue
			var poteau := MeshInstance3D.new()
			poteau.mesh = boite
			poteau.material_override = matiere
			poteau.position = Vector3(c, HAUT * 0.5, l)
			# Un poteau ne tient que par ses murs : quand les deux qu'il joint
			# sont escamotés, il reste planté seul au milieu du vide.
			poteau.set_meta("aretes", voisins)
			racine.add_child(poteau)

static func _car(dessin: Array, ligne: int, colonne: int) -> String:
	if ligne < 0 or ligne >= dessin.size():
		return " "
	var s := String(dessin[ligne])
	return " " if colonne < 0 or colonne >= s.length() else s[colonne]

## Le sol d'une pièce : le caractère de la tuile choisit sa teinte dans `sols`
## (`.` = la première). C'est ce qui distingue un carrelage de salle d'eau d'un
## parquet de séjour sans changer de modèle.
static func _sol_teinte(teintes: Dictionary, sols: Array, car: String) -> Dictionary:
	var i := 0
	if car >= "1" and car <= "9":
		i = mini(car.to_int(), sols.size() - 1)
	var t := teintes.duplicate()
	t["wood"] = sols[i]
	return t

## Une instance du kit, recentrée sur son emprise et posée sur le sol : les
## modèles Kenney ont chacun leur origine (coin, milieu, dessous), donc placer
## par l'origine oblige à connaître chaque modèle. Recentrer une fois rend la
## donnée de plan indépendante du kit.
static func _instancier(nom: String, teintes: Dictionary) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = nom.replace(":", "_")
	pivot.scale = Vector3.ONE * _facteur(nom)
	var inst := _scene(nom).instantiate() as Node3D
	var b := _brut(nom)
	inst.position = Vector3(-b.position.x - b.size.x * 0.5, -b.position.y, -b.position.z - b.size.z * 0.5)
	pivot.add_child(inst)
	_teinter(inst, teintes)
	return pivot

## Repeindre par NOM de matière. Le kit n'a pas d'atlas : chaque surface porte
## une matière nommée (`wood`, `carpet`, `metalDark`…), donc une table de
## teintes suffit à refaire toute une décoration — et deux appartements meublés
## des mêmes modèles ne se ressemblent plus.
static func _teinter(noeud: Node, teintes: Dictionary) -> void:
	if noeud is MeshInstance3D:
		var m := noeud as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i)
			if mat == null:
				continue
			var luminaire := mat.resource_name == "lamp"
			if not luminaire and not teintes.has(mat.resource_name):
				continue
			var copie := mat.duplicate() as StandardMaterial3D
			if teintes.has(mat.resource_name):
				copie.albedo_color = teintes[mat.resource_name]
			# Un abat-jour éteint n'est qu'une boîte blanche : de trois quarts,
			# rien ne dit que c'est une lampe. L'émission fait la différence.
			if luminaire:
				copie.emission_enabled = true
				copie.emission = copie.albedo_color
				copie.emission_energy_multiplier = 2.4
			m.set_surface_override_material(i, copie)
	for enfant in noeud.get_children():
		_teinter(enfant, teintes)

# ------------------------------------------------------------ le catalogue

## Ce que la boutique d'un repaire affiche. Léger EXPRÈS : la liste se lit sans
## charger un seul modèle, et seul l'intérieur qu'on visite paie son kit.
const CATALOGUE := {
	"taudis": {"nom": "Le Taudis", "prix": 0, "quartier": "cités",
		"resume": "Un studio squatté au pied d'une barre. Un matelas, une plaque, l'eau froide."},
	"ouvrier": {"nom": "L'Appart ouvrier", "prix": 12000, "quartier": "vieille ville",
		"resume": "Trois pièces sur cour, du carrelage d'époque et une chambre qui ferme."},
	"planque": {"nom": "La Planque", "prix": 24000, "quartier": "zone industrielle",
		"resume": "Un plateau de hangar cloisonné à la va-vite. Personne ne vient frapper."},
	"atelier": {"nom": "L'Atelier", "prix": 38000, "quartier": "port",
		"resume": "Un garage avec la place d'une voiture, et un coin vie au fond."},
	"pavillon": {"nom": "Le Pavillon", "prix": 55000, "quartier": "banlieue",
		"resume": "Quatre pièces de plain-pied, cuisine ouverte, jardin derrière."},
	"poste": {"nom": "L'Ancien poste", "prix": 72000, "quartier": "rues commerçantes",
		"resume": "Un commissariat de quartier reconverti. La cellule sert de chambre d'amis."},
	"loft": {"nom": "Le Loft", "prix": 110000, "quartier": "quartier des bureaux",
		"resume": "Un plateau ouvert, béton ciré et baies vitrées jusqu'au sol."},
	"penthouse": {"nom": "Le Penthouse", "prix": 250000, "quartier": "centre d'affaires",
		"resume": "Le dernier étage d'une tour. Suite, bar, et la ville tout autour."},
}

## Où se dépose l'argent, en tuiles et en quart de tour. Le repaire acheté, le
## jeu n'a plus qu'à poser sa zone d'interaction là — sans connaître le plan.
static func coffre(id: String) -> Dictionary:
	for m in plan(id).get("meubles", []):
		if String(m[0]) == COFFRE:
			return {"p": Vector2(float(m[1]), float(m[2])), "r": int(m[3])}
	push_error("Pas de coffre dans l'intérieur " + id)
	return {}

## L'ordre de la boutique : du gratuit au hors de prix.
static func liste() -> Array:
	var ids := CATALOGUE.keys()
	ids.sort_custom(func(a, b): return int(CATALOGUE[a]["prix"]) < int(CATALOGUE[b]["prix"]))
	return ids

## Le plan complet d'un intérieur — dessin, teintes, meubles, lumières.
## Séparé du catalogue parce qu'il MESURE les modèles pour adosser les meubles :
## l'appeler, c'est charger le kit.
static func plan(id: String) -> Dictionary:
	match id:
		"taudis": return _taudis()
		"ouvrier": return _ouvrier()
		"planque": return _planque()
		"atelier": return _atelier()
		"pavillon": return _pavillon()
		"poste": return _poste()
		"loft": return _loft()
		"penthouse": return _penthouse()
	push_error("Intérieur inconnu : " + id)
	return _taudis()

# ------------------------------------------------------------ 0 $ — Le Taudis

## Quatre tuiles sur trois, une salle d'eau grande comme un placard. Tout est
## d'occasion : c'est le repaire qu'on a sans rien payer, et il doit se lire
## comme tel dès la première image — murs jaunis, cartons jamais défaits.
static func _taudis() -> Dictionary:
	return {
		"plan": [
			"---F---F-",
			"|. . . .|",
			"|     -D-",
			"|. . .|1|",
			"|       |",
			"|. . .|1|",
			"-D-------",
		],
		"teintes": {"_defaultMat": Color("#9c9583"), "wood": Color("#6b5a44"),
			"metalDark": Color("#3c3f3d")},
		"sols": [Color("#6d5c46"), Color("#8d9490")],
		"teintes_meubles": {"carpet": Color("#7d4d3e"), "carpetDarker": Color("#5a382d"),
			"wood": Color("#7a6647"), "woodDark": Color("#57462f"), "carpetBlue": Color("#6f4a3c")},
		"lumieres": [[1.2, 0.7, Color("#ffd9a0"), 4.0, 1.1], [2.4, 1.8, Color("#ffe0b0"), 4.2, 1.1],
			[3.5, 2.5, Color("#cfe0ff"), 2.4, 0.8]],
		"meubles": [
			# Réagencé À LA MAIN dans l'Établi (08/09/2026) : la cuisine est passée
			# le long du mur ouest et le coin repas au nord. Les positions sont donc
			# ABSOLUES — plus un seul contre(), qui ne saurait pas les redonner.
			pose("kitchenSink", 0.26, 2.09, 1),
			pose("kitchenStove", 0.26, 1.66, 1),
			pose("kitchenCabinet", 0.26, 1.23, 1),
			pose("kitchenFridgeSmall", 0.3, 0.2, 0),
			pose("kitchenCabinetUpper", 0.12, 2.0, 1, 0.78),
			pose("kitchenCabinetUpper", 0.12, 1.4, 1, 0.78),
			pose("n:pot", 0.2, 1.6, 2, 0.45),
			pose("n:bottle-oil", 0.2, 1.4, 2, 0.45),
			pose("trashcan", 0.7, 0.2, 3),
			pose("table", 2, 0.3, 2),
			pose("chair", 1.4, 0.3, 1),
			pose("chair", 2.54, 0.30, 3),
			pose("n:pizza-box", 1.8, 0.3, 1, 0.33),
			pose("n:soda-can", 2.1, 0.3, 2, 0.33),
			pose("bedSingle", 3.44, 0.32, 3),
			pose("cabinetBed", 2.85, 0.16, 0),
			pose("n:can-open", 2.85, 0.16, 0, 0.24),
			pose("cabinetTelevision", 2.45, 2.87, 2),
			pose("televisionVintage", 2.45, 2.87, 2, 0.31),
			pose("rugRectangle", 2.6, 2.4, 2),
			pose("loungeSofa", 2.4, 2.2, 0),
			pose("lampSquareFloor", 2.9, 1.9, 2),
			pose("cardboardBoxOpen", 1.3, 2.8, 3),
			pose("cardboardBoxClosed", 1.6, 2.8, 2),
			pose("cardboardBoxClosed", 1.7, 2.2, 0),
			# ⚠ DEVANT LA PORTE À L'ORIGINE (0,9 ; 2,8) : le porte-manteau muré
			# l'entrée, avec l'évier au nord et les cartons à l'est — on entrait
			# dans un sas de deux pas. Aucune photo ne le montrait ;
			# `outils/marche.gd` a déclaré 97 % du sol inatteignable.
			pose("coatRackStanding", 0.28, 2.72, 3),
			pose("rugDoormat", 0.5, 2.86, 2),
			pose("lampSquareCeiling", 1.2, 0.7, 2, 1.06),
			pose("lampSquareCeiling", 2.4, 1.6, 2, 1.06),
			pose("toilet", 3.76, 1.70, 3),
			pose("bathroomSink", 3.15, 1.75, 1),
			pose("bathroomMirror", 3.07, 1.75, 1, 0.72),
			pose("showerRound", 3.72, 2.72, 1),
			pose("pottedPlant", 1, 0.2, 2),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 2.81, 1.05, 3),
		],
	}

# ------------------------------------------------------------ 12 000 $ — L'Appart ouvrier

## Cinq sur quatre, quatre pièces vraies : la première fois qu'on ferme une
## porte derrière soi. Carrelage d'immeuble ancien à la cuisine et à l'entrée,
## parquet ailleurs — c'est le sol qui raconte l'époque, pas le mobilier.
static func _ouvrier() -> Dictionary:
	return {
		"plan": [
			"---F---F---",
			"|2 2 .|. .|",
			"|         |",
			"|. . .D. .|",
			"|     -----",
			"|. . .|1 1|",
			"|     -D---",
			"|. . .D3 3|",
			"---F-----D-",
		],
		"teintes": {"_defaultMat": Color("#d6ccb6"), "wood": Color("#8a6a45"),
			"metalDark": Color("#3a3d3c")},
		"sols": [Color("#7d6242"), Color("#a9b4b5"), Color("#c6c2b1"), Color("#8f877b")],
		"teintes_meubles": {"carpet": Color("#4d6b7a"), "carpetDarker": Color("#35505c"),
			"wood": Color("#8a6f4a"), "woodDark": Color("#5f4a30"), "carpetBlue": Color("#41606f")},
		"lumieres": [[1.1, 0.6, Color("#ffe6c0"), 4.2, 1.0], [1.4, 2.6, Color("#ffe2b8"), 4.6, 1.1],
			[4.0, 1.0, Color("#ffdcb0"), 4.0, 0.9], [4.0, 2.5, Color("#dfeaff"), 3.0, 0.8],
			[4.2, 3.6, Color("#ffe0b8"), 3.0, 0.7]],
		"meubles": [
			# cuisine : le frigo prend l'angle, le plan de travail file vers l'est
			contre("kitchenFridge", "O", 0.55, 0),
			contre("kitchenCabinet", "N", 0.62, 0),
			contre("kitchenSink", "N", 1.07, 0),
			contre("kitchenStove", "N", 1.52, 0),
			contre("kitchenCabinetDrawer", "N", 1.97, 0),
			contre("kitchenCabinetUpperDouble", "N", 0.62, 0, 0.0, 0.80),
			contre("hoodModern", "N", 1.52, 0, 0.0, 0.86),
			contre("kitchenCabinetUpper", "N", 1.97, 0, 0.0, 0.80),
			pose("n:pot", 1.52, 0.22, 2, 0.45),
			pose("n:knife-block", 1.05, 0.24, 2, 0.49),
			pose("kitchenCoffeeMachine", 1.90, 0.24, 0, 0.45),
			# le bar sépare la cuisine du séjour : dans cinq mètres, une cloison
			# de plus rendrait les deux pièces inhabitables
			pose("kitchenBar", 1.05, 1.15, 2),
			pose("kitchenBar", 1.48, 1.15, 2),
			pose("kitchenBarEnd", 1.74, 1.15, 2),
			pose("stoolBar", 1.05, 1.58, 2),
			pose("stoolBar", 1.50, 1.58, 2),
			pose("n:mug", 1.20, 1.05, 2, 0.42),
			pose("n:cup-coffee", 1.45, 1.08, 2, 0.42),
			pose("trashcan", 2.41, 0.19, 2),
			# séjour
			contre("loungeSofaLong", "O", 2.60, 0),
			pose("rugRounded", 1.55, 2.60, 3),
			pose("tableCoffee", 1.35, 2.60, 3),
			contre("cabinetTelevisionDoors", "E", 2.60, 3),
			pose("televisionModern", 2.80, 2.60, 3, 0.31),
			contre("bookcaseOpen", "E", 2.05, 3, 0.03),
			contre("bookcaseClosedWide", "S", 1.00, 4),
			pose("pottedPlant", 0.35, 3.60, 2),
			# ⚠ EN TRAVERS DE LA PORTE DU SÉJOUR à l'origine (2,25 ; 3,45) : avec
			# le meuble de télé contre le mur est, le salon n'avait plus aucune
			# issue — 80 % de l'appartement coupé de l'entrée. Ramené du côté du
			# canapé, face à la télé (r = 3 regarde l'est).
			pose("loungeChair", 0.85, 3.30, 3),
			pose("lampRoundFloor", 0.35, 1.80, 2),
			pose("lampSquareCeiling", 1.40, 2.60, 2, HAUT - 0.23),
			pose("speakerSmall", 2.80, 3.05, 3),
			# chambre
			contre("bedDouble", "N", 4.00, 0),
			contre("cabinetBedDrawer", "N", 3.30, 0),
			contre("cabinetBedDrawerTable", "N", 4.70, 0),
			pose("lampSquareTable", 3.30, 0.12, 2, 0.263),
			pose("n:apple", 4.70, 0.12, 2, 0.263),
			contre("bookcaseClosedDoors", "S", 3.60, 2),
			pose("rugRound", 3.70, 1.50, 2),
			contre("desk", "E", 1.55, 5),
			pose("computerScreen", 4.72, 1.55, 3, 0.384),
			pose("chairDesk", 4.35, 1.55, 1),
			pose("lampSquareCeiling", 4.00, 1.05, 2, HAUT - 0.23),
			# salle de bain
			contre("bathtub", "N", 3.65, 2),
			contre("toilet", "E", 2.72, 5),
			contre("bathroomSinkSquare", "S", 4.35, 3),
			contre("bathroomMirror", "S", 4.35, 3, 0.0, 0.75),
			# entrée
			contre("washerDryerStacked", "E", 3.45, 5),
			contre("coatRack", "S", 3.60, 4, 0.0, 0.92),
			pose("rugDoormat", 4.45, 3.85, 2),
			pose("cardboardBoxClosed", 4.10, 3.22, 2),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 2.81, 0.75, 3),
		],
	}

# ------------------------------------------------------------ 24 000 $ — La Planque

## Un plateau de hangar recloisonné à la va-vite : parpaing brut, béton au sol,
## et rien qui ressemble à une décoration. C'est le premier repaire qu'on tient
## VRAIMENT — le confort viendra plus tard, la porte, elle, ferme.
static func _planque() -> Dictionary:
	return {
		"plan": [
			"---F-------",
			"|. . .|1 1|",
			"|         |",
			"|. . .D1 1|",
			"|     -D---",
			"|. . .|2 2|",
			"|         |",
			"|. . .|2 2|",
			"-D-B-------",
		],
		"teintes": {"_defaultMat": Color("#7c7c73"), "wood": Color("#5c5346"),
			"metalDark": Color("#33383a")},
		"sols": [Color("#55564f"), Color("#4a4b45"), Color("#5a5b53")],
		"teintes_meubles": {"carpet": Color("#5b5348"), "carpetDarker": Color("#423c34"),
			"wood": Color("#6a5a44"), "woodDark": Color("#4a3f30"), "carpetBlue": Color("#4e5a5f")},
		"lumieres": [[1.5, 1.6, Color("#ffdca0"), 5.0, 1.2], [1.4, 3.2, Color("#ffd08a"), 4.0, 0.9],
			[4.0, 0.9, Color("#cfd8e0"), 3.0, 0.6], [4.0, 3.0, Color("#ffd8a8"), 3.6, 0.9]],
		"meubles": [
			# la grande salle : une table de réunion improvisée et de quoi manger
			pose("tableCross", 1.45, 1.55, 2),
			pose("chair", 0.85, 1.55, 1),
			pose("chair", 2.05, 1.55, 3),
			pose("chair", 1.45, 1.10, 0),
			pose("chair", 1.45, 2.00, 2),
			pose("n:pizza-box", 1.30, 1.45, 2, 0.35),
			pose("n:soda-can", 1.75, 1.42, 2, 0.35),
			pose("n:soda-can-crushed", 1.85, 1.68, 3, 0.35),
			pose("n:bottle-ketchup", 1.20, 1.72, 2, 0.35),
			pose("lampSquareCeiling", 1.45, 1.55, 2, HAUT - 0.23),
			# le coin cuisine, réduit à ce qui branche
			contre("kitchenCabinet", "N", 0.30, 0),
			contre("kitchenSink", "N", 0.75, 0),
			contre("kitchenFridgeSmall", "N", 1.25, 0),
			pose("kitchenMicrowave", 0.30, 0.24, 0, 0.45),
			contre("trashcan", "N", 1.75, 0),
			# ce qui traîne : cartons, fûts, matériel
			pose("n:barrel", 2.60, 0.40, 2, 0.0, 2.4),
			pose("n:barrel", 2.55, 0.85, 3, 0.0, 2.4),
			pose("cardboardBoxClosed", 0.35, 2.55, 2),
			pose("cardboardBoxClosed", 0.35, 2.90, 3),
			pose("cardboardBoxOpen", 0.70, 2.75, 0),
			pose("cardboardBoxClosed", 0.38, 2.72, 2, 0.281),
			pose("radio", 2.60, 0.78, 3),
			pose("bookcaseOpenLow", 2.68, 3.35, 3),
			pose("televisionVintage", 2.66, 3.35, 3, 0.40),
			pose("loungeSofa", 1.55, 3.35, 1),
			pose("rugRectangle", 2.05, 3.35, 3),
			pose("lampSquareFloor", 0.40, 3.20, 2),
			# la réserve : tout ce qui ne doit pas se voir de la rue
			pose("cardboardBoxClosed", 3.30, 0.30, 2),
			pose("cardboardBoxClosed", 3.30, 0.65, 3),
			pose("cardboardBoxClosed", 3.32, 0.47, 2, 0.281),
			pose("cardboardBoxOpen", 3.70, 0.35, 0),
			pose("n:barrel", 4.55, 0.40, 2, 0.0, 2.4),
			pose("n:barrel", 4.55, 0.90, 0, 0.0, 2.4),
			contre("bookcaseOpen", "E", 1.50, 5),
			pose("cardboardBoxClosed", 3.80, 1.32, 1),
			# le coin nuit : deux lits de camp et une caisse en guise de table
			contre("bedSingle", "E", 2.55, 5),
			contre("bedSingle", "E", 3.65, 5),
			pose("cardboardBoxClosed", 3.35, 3.10, 2),
			pose("lampSquareTable", 3.35, 3.10, 2, 0.281),
			pose("coatRackStanding", 3.30, 2.75, 2),
			pose("trashcan", 3.30, 3.70, 2),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 4.50, 0.19, 0),
		],
	}

# ------------------------------------------------------------ 38 000 $ — L'Atelier

## Un garage du port : quatre tuiles de dalle nue devant la porte basculante,
## et la vie tassée au fond sur deux tuiles. Le vide au milieu est VOULU — c'est
## la place d'une voiture, et un repaire de mécano sans fosse ne veut rien dire.
static func _atelier() -> Dictionary:
	return {
		"plan": [
			"---------F---",
			"|1 1 1 1|. .|",
			"|           |",
			"|1 1 1 1D. .|",
			"|       -D---",
			"|1 1 1 1|2 2|",
			"|       ---D-",
			"|1 1 1 1|3 3|",
			"---B-B---D---",
		],
		"teintes": {"_defaultMat": Color("#8c887c"), "wood": Color("#6b5c48"),
			"metalDark": Color("#343a3c")},
		"sols": [Color("#7b6244"), Color("#4e4f4a"), Color("#a6adae"), Color("#57584f")],
		"teintes_meubles": {"carpet": Color("#7a5a3a"), "carpetDarker": Color("#573f28"),
			"wood": Color("#7d6748"), "woodDark": Color("#584631"), "carpetBlue": Color("#4d5f6b")},
		"lumieres": [[1.2, 1.0, Color("#e8f0ff"), 5.0, 1.0], [2.6, 3.0, Color("#e8f0ff"), 5.0, 1.0],
			[5.0, 1.0, Color("#ffdcae"), 4.0, 1.0], [5.0, 2.5, Color("#dfeaff"), 2.6, 0.7],
			[5.0, 3.6, Color("#ffd8a0"), 2.6, 0.6]],
		"meubles": [
			# l'établi court le long du mur nord, la baie de travail reste libre
			contre("desk", "N", 0.55, 0),
			contre("desk", "N", 1.30, 0),
			contre("bookcaseOpen", "N", 2.00, 0),
			contre("bookcaseOpenLow", "N", 2.60, 0),
			pose("computerScreen", 1.30, 0.24, 0, 0.384),
			pose("kitchenBlender", 0.40, 0.24, 0, 0.384),
			pose("radio", 2.60, 0.30, 0, 0.40),
			contre("cardboardBoxClosed", "O", 1.20, 0),
			contre("cardboardBoxClosed", "O", 1.55, 0),
			pose("cardboardBoxOpen", 0.30, 1.38, 1, 0.281),
			pose("n:barrel", 0.42, 2.10, 2, 0.0, 2.4),
			pose("n:barrel", 0.42, 2.60, 0, 0.0, 2.4),
			pose("trashcan", 0.35, 3.01, 2),
			contre("cabinetTelevision", "O", 3.60, 0),
			pose("televisionVintage", 0.30, 3.60, 1, 0.31),
			pose("lampSquareCeiling", 1.20, 1.00, 2, HAUT - 0.23),
			pose("lampSquareCeiling", 2.60, 3.00, 2, HAUT - 0.23),
			pose("cardboardBoxClosed", 3.65, 3.60, 3),
			pose("cardboardBoxClosed", 3.65, 3.25, 2),
			pose("bench", 3.55, 2.35, 3),
			pose("table", 1.90, 2.55, 3),
			pose("cardboardBoxOpen", 1.90, 2.55, 3, 0.33),
			pose("n:barrel", 2.60, 2.35, 3, 0.0, 2.4),
			pose("cardboardBoxClosed", 1.35, 3.70, 2),
			pose("cardboardBoxClosed", 1.70, 3.70, 3),
			pose("cardboardBoxClosed", 1.52, 3.68, 2, 0.281),
			pose("stoolBar", 2.35, 2.90, 2),
			# le coin vie, deux tuiles au nord-est
			contre("bedDouble", "N", 5.05, 0),
			contre("cabinetBedDrawer", "N", 4.35, 0),
			pose("lampSquareTable", 4.35, 0.13, 2, 0.263),
			contre("kitchenFridgeSmall", "E", 0.60, 6),
			contre("kitchenSink", "E", 1.10, 6),
			contre("kitchenCabinet", "E", 1.55, 6),
			pose("kitchenMicrowave", 5.75, 1.55, 3, 0.45),
			pose("table", 5.20, 1.55, 0),
			pose("chairCushion", 5.20, 1.30, 0),
			pose("chairCushion", 4.85, 1.55, 1),
			pose("n:plate-dinner", 5.20, 1.55, 2, 0.33),
			pose("n:soda-can", 5.42, 1.42, 2, 0.33),
			pose("lampSquareCeiling", 5.00, 1.00, 2, HAUT - 0.23),
			# salle d'eau
			pose("shower", 4.29, 2.72, 1),
			contre("toilet", "E", 2.30, 6),
			contre("bathroomSink", "N", 5.15, 2),
			contre("bathroomMirror", "N", 5.15, 2, 0.0, 0.72),
			# réserve
			contre("washerDryerStacked", "O", 3.35, 4),
			contre("bookcaseClosedWide", "N", 4.87, 3),
			pose("cardboardBoxClosed", 5.02, 3.38, 2),
			pose("cardboardBoxClosed", 5.02, 3.72, 3),
			pose("n:barrel", 5.55, 3.65, 2, 0.0, 2.4),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 3.50, 0.19, 0),
		],
	}

# ------------------------------------------------------------ 55 000 $ — Le Pavillon

## Le rêve du quartier : plain-pied, cuisine ouverte sur le séjour par une
## arche, chambre au fond, salle de bain qui ferme. Rien de spectaculaire —
## c'est le premier repaire où l'on n'a plus l'impression de camper.
static func _pavillon() -> Dictionary:
	return {
		"plan": [
			"---F-----F---",
			"|. . .|2 2 2|",
			"|           |",
			"|. . .A2 2 2|",
			"|     -----D-",
			"|. . .|. . .|",
			"-D---       |",
			"|1 1|3 . . .|",
			"-----D---F---",
		],
		"teintes": {"_defaultMat": Color("#e4ddcc"), "wood": Color("#8f6b41"),
			"metalDark": Color("#3b4142")},
		"sols": [Color("#8f6b41"), Color("#b3bdb9"), Color("#bfb9a6"), Color("#7e786b")],
		"teintes_meubles": {"carpet": Color("#6b8f6a"), "carpetDarker": Color("#4c6a4b"),
			"wood": Color("#a8814f"), "woodDark": Color("#7a5c36"), "carpetBlue": Color("#5d8a72")},
		"lumieres": [[1.5, 1.5, Color("#ffe8c4"), 5.0, 1.1], [4.4, 1.0, Color("#fff0d6"), 4.6, 1.0],
			[4.6, 3.0, Color("#ffe4bc"), 4.6, 1.0], [1.0, 3.5, Color("#e2eeff"), 3.0, 0.8],
			[2.5, 3.5, Color("#ffe4bc"), 2.6, 0.6]],
		"meubles": [
			# séjour : le canapé d'angle contre l'ouest, la télé au nord
			contre("loungeSofaCorner", "O", 1.45, 0),
			pose("rugRounded", 1.60, 1.55, 2),
			pose("tableCoffeeGlass", 1.60, 1.55, 2),
			contre("cabinetTelevisionDoors", "N", 1.55, 0),
			pose("televisionModern", 1.55, 0.14, 0, 0.31),
			pose("speakerSmall", 1.00, 0.20, 0),
			pose("speakerSmall", 2.10, 0.20, 0),
			contre("bookcaseClosedWide", "S", 1.55, 3),
			pose("pottedPlant", 2.70, 0.35, 2),
			pose("loungeChair", 2.45, 2.15, 3),
			pose("lampRoundFloor", 0.40, 2.15, 2),
			contre("lampWall", "O", 0.60, 0, 0.0, 0.88),
			pose("lampSquareCeiling", 1.55, 1.55, 2, HAUT - 0.23),
			# cuisine ouverte : le plan file d'un mur à l'autre
			contre("kitchenCabinet", "N", 3.30, 0),
			contre("kitchenSink", "N", 3.78, 0),
			contre("kitchenCabinetDrawer", "N", 4.23, 0),
			contre("kitchenStove", "N", 4.68, 0),
			contre("kitchenCabinet", "N", 5.13, 0),
			contre("kitchenCabinetCornerRound", "N", 5.60, 0),
			contre("kitchenCabinetUpperDouble", "N", 3.78, 0, 0.0, 0.80),
			contre("hoodLarge", "N", 4.68, 0, 0.0, 0.86),
			contre("kitchenCabinetUpper", "N", 5.13, 0, 0.0, 0.80),
			pose("n:pot-stew-lid", 4.68, 0.24, 2, 0.45),
			pose("kitchenCoffeeMachine", 3.35, 0.24, 0, 0.45),
			pose("n:knife-block", 4.05, 0.24, 2, 0.45),
			contre("kitchenFridgeLarge", "E", 1.10, 6),
			pose("tableRound", 4.20, 1.55, 2),
			pose("chairRounded", 3.65, 1.55, 1),
			pose("chairRounded", 4.75, 1.55, 3),
			pose("chairRounded", 4.20, 0.96, 0),
			pose("n:plate-dinner", 4.20, 1.55, 2, 0.37),
			pose("n:glass-wine", 4.45, 1.42, 2, 0.37),
			pose("lampSquareCeiling", 4.30, 1.10, 2, HAUT - 0.23),
			# chambre
			contre("bedDouble", "E", 3.05, 6),
			contre("cabinetBedDrawerTable", "E", 2.50, 6),
			contre("cabinetBedDrawerTable", "E", 3.70, 6),
			pose("lampSquareTable", 5.45, 2.50, 3, 0.263),
			pose("n:cup-tea", 5.45, 3.70, 3, 0.263),
			pose("rugSquare", 4.35, 3.20, 2),
			contre("bookcaseClosed", "S", 4.10, 4),
			contre("cabinetTelevision", "S", 4.80, 4),
			pose("televisionModern", 4.80, 3.86, 2, 0.31),
			pose("coatRackStanding", 3.30, 2.40, 2),
			pose("pottedPlant", 3.30, 3.10, 2),
			pose("lampSquareCeiling", 4.60, 3.00, 2, HAUT - 0.23),
			# salle de bain
			contre("bathtub", "N", 1.35, 3),
			contre("toilet", "S", 0.45, 4),
			contre("bathroomSinkSquare", "S", 1.20, 4),
			contre("bathroomMirror", "S", 1.20, 4, 0.0, 0.75),
			contre("washer", "S", 1.75, 4),
			# entrée
			pose("rugDoormat", 2.50, 3.85, 2),
			contre("coatRack", "O", 3.40, 2, 0.0, 0.95),
			pose("pottedPlant", 2.75, 3.25, 2),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 3.45, 3.81, 2),
		],
	}

# ------------------------------------------------------------ 72 000 $ — L'Ancien poste

## Un commissariat de quartier fermé pour cause d'économies, racheté tel quel :
## le lino vert, les classeurs, et la cellule qu'on n'a jamais démontée. C'est
## le seul repaire dont la porte d'entrée est blindée d'origine.
static func _poste() -> Dictionary:
	return {
		"plan": [
			"---F-------",
			"|. . .|1 1F",
			"|         |",
			"|. . .D1 1|",
			"|     -----",
			"|. . .D2 2|",
			"|     -----",
			"|. . .D3 3F",
			"-D---------",
		],
		"teintes": {"_defaultMat": Color("#c2c6bc"), "wood": Color("#6f6350"),
			"metalDark": Color("#2f3538")},
		"sols": [Color("#6a7166"), Color("#585c56"), Color("#a4adaa"), Color("#6a7166")],
		"teintes_meubles": {"carpet": Color("#3f5a6b"), "carpetDarker": Color("#2c414e"),
			"wood": Color("#6f6350"), "woodDark": Color("#4e4436"), "metalDark": Color("#2f3538"), "carpetBlue": Color("#3f5a6b")},
		"lumieres": [[1.4, 1.0, Color("#eaf2ff"), 4.4, 1.0], [1.4, 3.0, Color("#eaf2ff"), 4.4, 0.9],
			[4.0, 1.0, Color("#dfe6ee"), 3.0, 0.6], [4.0, 2.5, Color("#e8f0ff"), 2.6, 0.7],
			[4.0, 3.5, Color("#ffe0b4"), 2.6, 0.7]],
		"meubles": [
			# la salle de garde devenue bureau : deux postes qui se font face
			contre("deskCorner", "O", 1.00, 0),
			pose("computerScreen", 0.70, 0.75, 0, 0.384),
			pose("computerScreen", 1.05, 0.75, 0, 0.384),
			pose("computerKeyboard", 0.88, 1.05, 0, 0.384),
			pose("computerMouse", 1.15, 1.05, 0, 0.384),
			pose("chairDesk", 1.28, 1.35, 3),
			contre("desk", "N", 2.10, 0),
			pose("laptop", 2.10, 0.28, 0, 0.384),
			pose("chairDesk", 2.10, 0.75, 2),
			contre("bookcaseClosedDoors", "N", 1.55, 0),
			contre("bookcaseClosed", "S", 1.05, 4),
			contre("bookcaseClosedDoors", "S", 1.50, 4),
			contre("bookcaseOpen", "S", 1.95, 4),
			pose("cardboardBoxClosed", 2.10, 3.65, 2),
			pose("cardboardBoxClosed", 2.45, 3.65, 3),
			pose("trashcan", 2.65, 0.35, 2),
			pose("pottedPlant", 0.35, 3.30, 2),
			pose("coatRackStanding", 0.35, 2.15, 2),
			pose("table", 1.60, 2.30, 3),
			pose("chair", 1.60, 1.75, 0),
			pose("chair", 1.60, 2.85, 2),
			pose("n:cup-coffee", 1.55, 2.20, 2, 0.33),
			pose("n:donut", 1.72, 2.42, 2, 0.33),
			pose("radio", 2.55, 2.30, 3),
			pose("lampSquareCeiling", 1.40, 1.00, 2, HAUT - 0.23),
			pose("lampSquareCeiling", 1.40, 3.00, 2, HAUT - 0.23),
			pose("rugRectangle", 1.45, 3.20, 3),
			# la cellule : on y dort, les barreaux sont restés
			contre("bedBunk", "E", 0.90, 5),
			contre("cabinetBed", "N", 3.30, 0),
			pose("lampSquareTable", 3.30, 0.13, 2, 0.233),
			pose("toiletSquare", 4.81, 1.70, 3),
			pose("cardboardBoxClosed", 3.35, 0.95, 2),
			pose("lampSquareCeiling", 4.00, 1.00, 2, HAUT - 0.23),
			# les vestiaires devenus salle d'eau
			contre("showerRound", "E", 2.35, 5),
			contre("toilet", "E", 2.85, 5),
			contre("bathroomSinkSquare", "S", 4.35, 3),
			contre("bathroomMirror", "S", 4.35, 3, 0.0, 0.75),
			pose("washerDryerStacked", 3.62, 2.20, 1),
			# le fond : le vrai coin nuit
			contre("bedDouble", "E", 3.55, 5),
			contre("cabinetBedDrawer", "S", 3.35, 4),
			pose("rugRound", 3.90, 3.20, 2),
			pose("lampSquareCeiling", 4.00, 3.50, 2, HAUT - 0.23),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 0.19, 2.75, 1),
		],
	}

# ------------------------------------------------------------ 110 000 $ — Le Loft

## Sept tuiles sur quatre sans une cloison, sauf la salle d'eau : béton ciré,
## baies vitrées au sud et à l'est, et le mobilier pour seul plan. Un loft se
## meuble par ÎLOTS — chaque usage a son tapis, sinon c'est un entrepôt meublé.
static func _loft() -> Dictionary:
	return {
		"plan": [
			"---F---F-------",
			"|. . . . .|1 1|",
			"|         -D---",
			"|. . . . . . .B",
			"|             |",
			"|. . . . . . .B",
			"|             |",
			"|. . . . . . .|",
			"-D---B-B---B-B-",
		],
		"teintes": {"_defaultMat": Color("#d3cfc7"), "wood": Color("#6b5030"),
			"metalDark": Color("#2b2e31")},
		"sols": [Color("#73726d"), Color("#9aa1a2")],
		"teintes_meubles": {"carpet": Color("#3f4349"), "carpetDarker": Color("#2a2d31"),
			"wood": Color("#6b5030"), "woodDark": Color("#46331e"), "metalDark": Color("#2b2e31"), "carpetBlue": Color("#3f4349")},
		"lumieres": [[1.6, 0.8, Color("#ffeccf"), 5.0, 1.0], [4.6, 1.2, Color("#ffe8c8"), 5.0, 1.0],
			[2.0, 3.0, Color("#ffe8c8"), 5.0, 1.1], [5.4, 3.0, Color("#ffe0b8"), 4.4, 0.9],
			[6.4, 0.6, Color("#e6f0ff"), 2.6, 0.7]],
		"meubles": [
			# la cuisine occupe le mur nord, l'îlot fait la frontière
			contre("kitchenCabinetCornerRound", "N", 0.30, 0),
			contre("kitchenCabinetDrawer", "N", 0.76, 0),
			contre("kitchenSink", "N", 1.21, 0),
			contre("kitchenCabinet", "N", 1.66, 0),
			contre("kitchenStoveElectric", "N", 2.11, 0),
			contre("kitchenCabinetDrawer", "N", 2.56, 0),
			contre("kitchenFridgeBuiltIn", "N", 3.05, 0),
			contre("kitchenCabinetUpperDouble", "N", 1.21, 0, 0.0, 0.80),
			contre("hoodModern", "N", 2.11, 0, 0.0, 0.86),
			contre("kitchenCabinetUpper", "N", 2.56, 0, 0.0, 0.80),
			pose("n:pot", 2.11, 0.24, 2, 0.45),
			pose("kitchenCoffeeMachine", 0.80, 0.24, 0, 0.45),
			pose("n:knife-block", 1.55, 0.24, 2, 0.45),
			pose("kitchenBar", 1.30, 1.30, 2),
			pose("kitchenBar", 1.73, 1.30, 2),
			pose("kitchenBar", 2.16, 1.30, 2),
			pose("kitchenBarEnd", 2.42, 1.30, 2),
			pose("stoolBarSquare", 1.35, 1.72, 2),
			pose("stoolBarSquare", 1.80, 1.72, 2),
			pose("stoolBarSquare", 2.25, 1.72, 2),
			pose("n:cocktail", 1.60, 1.22, 2, 0.42),
			pose("n:glass-wine", 2.05, 1.24, 2, 0.42),
			# la salle à manger
			pose("tableCross", 4.60, 1.20, 3),
			pose("chairModernCushion", 4.20, 0.90, 1),
			pose("chairModernCushion", 4.20, 1.50, 1),
			pose("chairModernCushion", 4.91, 0.90, 3),
			pose("chairModernCushion", 5.00, 1.50, 3),
			pose("n:plate-dinner", 4.60, 1.20, 2, 0.33),
			pose("lampSquareCeiling", 4.60, 1.20, 2, HAUT - 0.23),
			pose("pottedPlant", 5.60, 2.20, 2),
			pose("rugSquare", 4.60, 1.25, 2),
			contre("bookcaseOpen", "N", 4.20, 0),
			pose("pottedPlant", 3.60, 2.35, 2),
			pose("loungeChairRelax", 4.10, 3.05, 3),
			pose("sideTable", 3.55, 3.05, 2),
			pose("lampRoundTable", 3.55, 3.05, 2, 0.384),
			# le salon, sur son tapis
			pose("rugRounded", 2.20, 3.00, 2),
			pose("loungeDesignSofaCorner", 1.90, 2.90, 0),
			pose("loungeDesignChair", 3.10, 3.40, 3),
			pose("tableCoffeeGlassSquare", 2.45, 3.52, 2),
			pose("n:bowl", 2.45, 3.52, 2, 0.23),
			contre("cabinetTelevisionDoors", "S", 2.30, 4),
			pose("televisionModern", 2.30, 3.86, 2, 0.31),
			pose("speaker", 1.40, 3.72, 0),
			pose("speaker", 3.58, 3.72, 0),
			pose("lampRoundFloor", 0.40, 3.20, 2),
			pose("pottedPlant", 0.40, 2.20, 2),
			# le coin nuit et le bureau, au fond du plateau
			contre("bedDouble", "E", 2.70, 7),
			contre("cabinetBedDrawerTable", "E", 2.15, 7),
			contre("cabinetBedDrawerTable", "E", 3.30, 7),
			pose("lampSquareTable", 6.45, 2.15, 3, 0.263),
			pose("rugSquare", 5.50, 2.90, 2),
			contre("deskCorner", "S", 5.20, 4),
			pose("computerScreen", 5.05, 3.60, 0, 0.384),
			pose("computerKeyboard", 5.15, 3.85, 0, 0.384),
			pose("chairDesk", 5.15, 3.30, 0),
			contre("bookcaseOpen", "N", 5.30, 2),
			pose("lampSquareCeiling", 5.60, 2.90, 2, HAUT - 0.23),
			# la salle d'eau, seule pièce fermée du plateau
			contre("bathtub", "N", 6.20, 0),
			contre("toilet", "E", 0.70, 7),
			contre("bathroomSinkSquare", "O", 0.32, 5),
			contre("bathroomMirror", "O", 0.32, 5, 0.0, 0.75),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 0.19, 1.50, 1),
		],
	}

# ------------------------------------------------------------ 250 000 $ — Le Penthouse

## Huit sur cinq au dernier étage d'une tour du centre d'affaires : baies du sol
## au plafond sur trois côtés, suite fermée à l'est, bar et salle à manger au
## sud. Le luxe se dit ici par le VIDE — on aère, on n'entasse pas.
static func _penthouse() -> Dictionary:
	return {
		"plan": [
			"---B-B---B-B-F-F-",
			"|. . . . . .|1 1B",
			"|               |",
			"|. . . . . .D1 1|",
			"|               |",
			"|. . . . . .|1 1F",
			"|           -D---",
			"|. . . . . .|2 2|",
			"|               |",
			"|. . . . . .|2 2|",
			"-D---B-B-B-----F-",
		],
		"teintes": {"_defaultMat": Color("#efece4"), "wood": Color("#9a7c4d"),
			"metalDark": Color("#33383c")},
		"sols": [Color("#9a7c4d"), Color("#8b7146"), Color("#c9cecd")],
		"teintes_meubles": {"carpet": Color("#2f3338"), "carpetDarker": Color("#1e2126"),
			"wood": Color("#7a5a33"), "woodDark": Color("#56391d"), "metal": Color("#c9a44a"), "carpetBlue": Color("#2f3338")},
		"lumieres": [[1.8, 1.2, Color("#ffeed2"), 5.4, 1.1], [4.6, 1.2, Color("#ffe8c6"), 5.0, 1.0],
			[2.0, 3.4, Color("#ffe8c6"), 5.4, 1.1], [4.8, 4.0, Color("#ffdfb2"), 4.4, 0.9],
			[7.0, 1.6, Color("#ffe6c4"), 4.4, 1.0], [7.0, 4.0, Color("#e8f2ff"), 3.4, 0.9]],
		"meubles": [
			# Salon, bureau et salle de bain réagencés À LA MAIN dans l'Établi
			# (09/09/2026) : la télé passe au mur ouest, le coin bureau au sud,
			# la baignoire à l'est. Positions ABSOLUES — plus un seul contre().
			pose("kitchenCabinetCornerInner", 0.3, 0.23, 1),
			pose("kitchenCabinetDrawer", 0.77, 0.22, 0),
			pose("kitchenSink", 1.22, 0.22, 0),
			pose("kitchenCabinetDrawer", 1.67, 0.22, 0),
			pose("kitchenStoveElectric", 2.12, 0.22, 0),
			pose("kitchenCabinet", 2.57, 0.22, 0),
			pose("kitchenFridgeBuiltIn", 3.06, 0.22, 0),
			pose("kitchenCabinetUpperDouble", 0.8, 0.1, 0, 0.8),
			pose("hoodModern", 2.12, 0.14, 0, 0.86),
			pose("n:pot-stew", 2.12, 0.24, 2, 0.45),
			pose("kitchenCoffeeMachine", 0.82, 0.24, 0, 0.45),
			pose("n:knife-block", 1.55, 0.24, 2, 0.45),
			pose("kitchenBar", 1.35, 1.35, 2),
			pose("kitchenBar", 1.78, 1.35, 2),
			pose("kitchenBar", 2.21, 1.35, 2),
			pose("kitchenBarEnd", 2.47, 1.35, 2),
			pose("stoolBarSquare", 1.4, 1.77, 2),
			pose("stoolBarSquare", 1.85, 1.77, 2),
			pose("stoolBarSquare", 2.3, 1.77, 2),
			pose("n:cocktail", 1.6, 1.28, 2, 0.42),
			pose("n:cocktail", 2.05, 1.3, 2, 0.42),
			pose("n:wine-red", 2.35, 1.28, 2, 0.42),
			pose("tableCross", 4.6, 1.3, 3),
			pose("chairModernFrameCushion", 4.2, 1, 1),
			pose("chairModernFrameCushion", 4.2, 1.6, 1),
			pose("chairModernFrameCushion", 5, 1, 3),
			pose("chairModernFrameCushion", 5, 1.6, 3),
			pose("n:plate-dinner", 4.6, 1.3, 2, 0.33),
			pose("n:glass-wine", 4.85, 1.15, 2, 0.33),
			pose("lampSquareCeiling", 4.6, 1.3, 2, 1.06),
			pose("pottedPlant", 5.65, 0.4, 2),
			pose("pottedPlant", 0.1, 2.7, 2),
			pose("rugRounded", 2.2, 3.4, 2),
			pose("loungeDesignSofaCorner", 1.9, 3.7, 3),
			pose("loungeDesignSofa", 1.6, 2.6, 0),
			pose("loungeDesignChair", 5.8, 2.7, 3),
			pose("tableCoffeeGlass", 1.6, 3.5, 2),
			pose("n:bowl", 1.6, 3.5, 2, 0.23),
			pose("cabinetTelevisionDoors", 0.13, 3.6, 1),
			pose("televisionModern", 0.1, 3.6, 1, 0.31),
			pose("speaker", 0.1, 3, 1),
			pose("speaker", 0.1, 4.2, 1),
			pose("lampRoundFloor", 3.88, 4.62, 2),
			pose("deskCorner", 5.1, 4.51, 2),
			pose("computerScreen", 5.2, 4.9, 2, 0.38),
			pose("computerKeyboard", 5.2, 4.7, 2, 0.38),
			pose("computerMouse", 5, 4.7, 0, 0.38),
			pose("chairDesk", 5.2, 4.4, 0),
			pose("bookcaseOpen", 5.78, 4.87, 2),
			pose("lampSquareCeiling", 4.8, 4, 2, 1.06),
			pose("bedDouble", 7, 0.56, 0),
			pose("cabinetBedDrawerTable", 6.35, 0.11, 0),
			pose("cabinetBedDrawerTable", 7.65, 0.11, 0),
			pose("lampSquareTable", 6.35, 0.13, 2, 0.26),
			pose("lampSquareTable", 7.65, 0.13, 2, 0.26),
			pose("rugSquare", 7, 1.9, 2),
			pose("bookcaseClosedWide", 6.13, 2.2, 1),
			pose("sideTableDrawers", 7.89, 1.3, 3),
			pose("lampRoundTable", 7.72, 1.3, 3, 0.38),
			pose("loungeChairRelax", 7.6, 1.9, 3),
			pose("pottedPlant", 7.7, 2.8, 2),
			pose("lampSquareCeiling", 7, 1.6, 2, 1.06),
			pose("bathtub", 7.4, 3.3, 0),
			pose("showerRound", 6.3, 4.7, 2),
			pose("toilet", 7.7, 4.8, 3),
			pose("bathroomSinkSquare", 7.8, 3.9, 3),
			pose("bathroomMirror", 7.9, 3.9, 3, 0.75),
			pose("bathroomCabinetDrawer", 7, 4.8, 2),
			pose("lampSquareCeiling", 7, 4, 2, 1.06),
			# LE COFFRE : un par repaire, un seul, et JAMAIS dans une file de
			# meubles — adossé à côté d'un placard, il se lit comme un placard.
			# `outils/verifier.py` lui impose soixante centimètres de vide.
			pose("c:coffre", 0.19, 1.50, 1),
		],
	}
