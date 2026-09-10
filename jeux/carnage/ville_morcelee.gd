class_name VilleMorcelee
extends Node3D
## PIKSTOWN, BÂTIE PAR MORCEAUX AUTOUR DE CELUI QUI REGARDE.
##
## ⚠ POURQUOI CE FICHIER EXISTE. La ville fait 225 × 215 cases : bâtie d'un
## bloc, elle coûte SIX SECONDES et SOIXANTE MILLE NŒUDS en natif — donc près
## d'une minute et un onglet à bout de souffle dans le navigateur, où tout le
## jeu tourne. Mesuré, pas supposé (`outils/mesure.gd`). Un joueur ne voit
## jamais plus d'un dixième de la carte : on ne bâtit donc que les morceaux
## autour de lui, et on rend les autres à la mémoire quand il s'éloigne.
##
## LES TROIS DÉCISIONS
##
## 1. LA CARTE EST ENTIÈRE, LE DÉCOR EST MORCELÉ. `Quartiers.preparer` calcule
##    une fois la carte des cases et la liste des bâtiments — des tables, elles
##    coûtent des microsecondes. Si chaque morceau ne connaissait que ses
##    propres cases, une rue ne saurait pas qu'elle continue chez le voisin :
##    on aurait une impasse tous les vingt-quatre pas, et le kit poserait une
##    tuile de cul-de-sac à chaque bord de morceau.
## 2. UN MORCEAU PAR IMAGE, LES PLUS PROCHES D'ABORD. En bâtir quatre d'un coup
##    fait sauter l'image ; en bâtir un ne se voit pas. La file est retriée à
##    chaque déplacement, sinon on passe son temps à bâtir derrière soi.
## 3. LE TIRAGE ALÉATOIRE DÉPEND DE LA CASE, PAS DE L'ORDRE (`_resemer` dans
##    `Quartiers`). Sans ça, un morceau rebâti après un aller-retour revient
##    avec d'autres immeubles — la ville change dans le dos du joueur.

## ⚠ SEIZE, PAS VINGT-QUATRE. Le coût d'un morceau est proportionnel à sa
## surface : 24 × 24 coûtaient 166 ms — onze images sautées d'un coup au
## franchissement d'un bord. 16 × 16 en coûtent 74, soit quatre images. On
## charge un peu plus souvent, mais on ne le sent plus.
const COTE := 16                       ## cases par morceau

var fiche: Dictionary = {}
var identifiant := "pikstown"
var rayon := 3                         ## morceaux bâtis autour du regard
var par_image := 1

## L'ORDRE DES PASSES est celui dans lequel on veut voir un morceau paraître :
## le sol d'abord (sinon on voit à travers), la chaussée, les façades, puis ce
## qui décore. Chaque passe tient dans une image.
const PASSES := [
	Quartiers.P_SOLS,
	Quartiers.P_CHAUSSEES | Quartiers.P_BATEAUX,
	Quartiers.P_BATIMENTS,
	# Le mobilier libre arrive avec la verdure : c'est de la décoration, elle
	# n'a aucune raison de paraître avant les façades.
	Quartiers.P_VERDURE | Quartiers.P_MOBILIER | Quartiers.P_OBJETS,
]

var _prete: Dictionary = {}
var _chantier := Vector2i(999999, 999999)   ## le morceau en cours de montage
var _chantier_noeud: Node3D = null
var _chantier_passe := 0
## Vrai quand le dessin a changé depuis la dernière carte complète : le prochain
## morceau à découvrir la fera refaire.
var _prete_perime := false
var _morceaux: Dictionary = {}         ## Vector2i -> Node3D
var _file: Array[Vector2i] = []
var _centre := Vector2i(999999, 999999)
var _large := 0
var _haut := 0

func regler(f: Dictionary, id: String = "pikstown", r: int = 3) -> void:
	fiche = f
	identifiant = id
	rayon = r
	_prete = Quartiers.preparer(fiche)
	_large = 0
	for ligne in fiche["plan"]:
		_large = maxi(_large, String(ligne).length())
	_haut = (fiche["plan"] as Array).size()
	for n in _morceaux.values():
		n.queue_free()
	_morceaux.clear()
	_file.clear()
	_chantier_noeud = null
	_chantier_passe = 0
	_centre = Vector2i(999999, 999999)
	var org: Vector2 = fiche.get("origine", Vector2.ZERO)
	transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(fiche.get("angle", 0.0)))),
		Vector3(org.x * Quartiers.CASE, 0, org.y * Quartiers.CASE))
	set_process(true)

func morceaux_batis() -> int:
	return _morceaux.size()

## Le point est en MONDE : c'est la caméra ou le joueur qui appelle, et ni l'un
## ni l'autre n'a à connaître le repère du quartier.
func suivre(point: Vector3) -> void:
	var local := global_transform.affine_inverse() * point
	var c := Vector2i(floori(local.x / Quartiers.CASE / float(COTE)),
		floori(local.z / Quartiers.CASE / float(COTE)))
	if c == _centre: return
	_centre = c
	_revoir()

func _revoir() -> void:
	var derniers := rayon + 1
	for cle in _morceaux.keys():
		var d: Vector2i = cle
		if maxi(absi(d.x - _centre.x), absi(d.y - _centre.y)) > derniers:
			# ⚠ Ne pas jeter le morceau qu'on est en train de monter : le
			# chantier garderait un nœud libéré et les passes suivantes
			# tomberaient dans le vide.
			if _chantier_noeud != null and cle == _chantier:
				_chantier_noeud = null
			(_morceaux[cle] as Node3D).queue_free()
			_morceaux.erase(cle)
	_file.clear()
	var colonnes := int(ceil(float(_large) / float(COTE)))
	var lignes := int(ceil(float(_haut) / float(COTE)))
	for dy in range(-rayon, rayon + 1):
		for dx in range(-rayon, rayon + 1):
			var c := _centre + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= colonnes or c.y >= lignes: continue
			if _morceaux.has(c): continue
			_file.append(c)
	# Les plus proches d'abord : bâtir derrière soi pendant qu'on avance, c'est
	# exactement l'ordre qu'il ne faut pas.
	var ici := _centre
	_file.sort_custom(func(a: Vector2i, b: Vector2i):
		return (a - ici).length_squared() < (b - ici).length_squared())

## Une PASSE par image, pas un morceau. `par_image` compte maintenant des
## passes : à 1, un morceau paraît en quatre images sans jamais en figer une.
func _process(_delta: float) -> void:
	var faits := 0
	while faits < par_image:
		if _chantier_noeud == null:
			if _file.is_empty(): return
			if _prete_perime:
				# Une seule fois, et seulement parce qu'on découvre du terrain
				# neuf : tant qu'on peint sur place, elle ne se refait jamais.
				_prete = Quartiers.preparer(fiche)
				_prete_perime = false
			var c: Vector2i = _file.pop_front()
			if _morceaux.has(c): continue
			_chantier = c
			_chantier_passe = 0
			_chantier_noeud = Node3D.new()
			_chantier_noeud.name = "%s_%d_%d" % [identifiant, c.x, c.y]
			add_child(_chantier_noeud)
			# ⚠ Inscrit TOUT DE SUITE dans la table, même à peine commencé :
			# sinon `_revoir` le remet dans la file à chaque pas du joueur et
			# le morceau recommence sans jamais finir.
			_morceaux[c] = _chantier_noeud
		var zone := Rect2i(_chantier.x * COTE, _chantier.y * COTE, COTE, COTE)
		Quartiers.batir_fiche(fiche, identifiant, zone, _prete,
			PASSES[_chantier_passe], _chantier_noeud)
		_chantier_passe += 1
		faits += 1
		if _chantier_passe >= PASSES.size():
			_chantier_noeud = null

## Le montage EN UNE FOIS, pour l'éditeur et le banc : au relâchement d'un coup
## de pinceau, on veut le morceau rebâti tout de suite, pas dans quatre images.
func _batir(c: Vector2i) -> void:
	if _morceaux.has(c): return
	var zone := Rect2i(c.x * COTE, c.y * COTE, COTE, COTE)
	var n := Quartiers.batir_fiche(fiche, "%s_%d_%d" % [identifiant, c.x, c.y], zone, _prete)
	# ⚠ Le nœud rendu porte DÉJÀ l'origine et l'angle du quartier ; ce nœud-ci
	# les porte aussi. Ajouté tel quel, le morceau serait décalé deux fois.
	n.transform = Transform3D.IDENTITY
	add_child(n)
	_morceaux[c] = n

## APRÈS UNE RETOUCHE : on rebâtit les morceaux qui portent les cases touchées,
## et EUX SEULS. C'est ce qui rend l'éditeur utilisable sur 48 000 cases : au
## relâchement du pinceau, une avenue de trente cases ne rebâtit que deux
## morceaux, pas la ville.
func refaire(cases: Array) -> void:
	# ⚠ LE VOISIN N'EST REFAIT QUE S'IL EST CONCERNÉ. Première version : les huit
	# morceaux voisins de CHAQUE case touchée. Une avenue de vingt cases peinte
	# au milieu d'un morceau en rebâtissait neuf — 2 304 cases pour vingt
	# modifiées, et 424 ms de gel par coup de pinceau.
	#
	# Ce qui déborde vraiment d'un morceau tient en deux choses : un bâtiment,
	# large de quatre cases au plus (emprise du hangar), et le raccord d'une rue,
	# qui lit sa voisine immédiate. Au-delà de DÉBORD cases du bord, une case
	# n'a aucun effet chez le voisin.
	const DEBORD := 4
	var a_refaire: Dictionary = {}
	for v in cases:
		var c: Vector2i = v
		var m := Vector2i(floori(float(c.x) / float(COTE)), floori(float(c.y) / float(COTE)))
		a_refaire[m] = true
		var dans_x := c.x - m.x * COTE       # position dans le morceau
		var dans_y := c.y - m.y * COTE
		if dans_x < DEBORD: a_refaire[m + Vector2i(-1, 0)] = true
		if dans_x >= COTE - DEBORD: a_refaire[m + Vector2i(1, 0)] = true
		if dans_y < DEBORD: a_refaire[m + Vector2i(0, -1)] = true
		if dans_y >= COTE - DEBORD: a_refaire[m + Vector2i(0, 1)] = true
		# Les diagonales seulement si l'on est dans un COIN.
		if dans_x < DEBORD and dans_y < DEBORD: a_refaire[m + Vector2i(-1, -1)] = true
		if dans_x >= COTE - DEBORD and dans_y < DEBORD: a_refaire[m + Vector2i(1, -1)] = true
		if dans_x < DEBORD and dans_y >= COTE - DEBORD: a_refaire[m + Vector2i(-1, 1)] = true
		if dans_x >= COTE - DEBORD and dans_y >= COTE - DEBORD: a_refaire[m + Vector2i(1, 1)] = true
	# ⚠ UNE CARTE DE FENÊTRE, PAS LA VILLE ENTIÈRE. `preparer()` complet coûte
	# 250 ms : c'était le prix de CHAQUE coup de pinceau, geste après geste.
	# On ne prépare que le rectangle des morceaux à refaire, plus trois cases
	# de marge pour que les rues s'y raccordent — quelques millisecondes.
	var mini_x := 999999
	var mini_y := 999999
	var maxi_x := -999999
	var maxi_y := -999999
	for cle in a_refaire.keys():
		var m: Vector2i = cle
		mini_x = mini(mini_x, m.x * COTE)
		mini_y = mini(mini_y, m.y * COTE)
		maxi_x = maxi(maxi_x, m.x * COTE + COTE - 1)
		maxi_y = maxi(maxi_y, m.y * COTE + COTE - 1)
	if maxi_x < mini_x: return
	var marge := 3
	var fenetre := Rect2i(mini_x - marge, mini_y - marge,
		maxi_x - mini_x + 1 + marge * 2, maxi_y - mini_y + 1 + marge * 2)
	var avant := _prete
	_prete = Quartiers.preparer(fiche, fenetre)
	for cle in a_refaire.keys():
		if not _morceaux.has(cle): continue
		if _chantier_noeud != null and cle == _chantier:
			_chantier_noeud = null
		(_morceaux[cle] as Node3D).queue_free()
		_morceaux.erase(cle)
		_batir(cle)
	# ⚠ LA CARTE DE FENÊTRE NE VAUT QUE POUR CES MORCEAUX-LÀ. Gardée pour la
	# suite, elle ferait bâtir les morceaux suivants — ceux qu'on découvre en se
	# déplaçant — sur une carte vide : une ville de trous. On la jette, et on ne
	# refait la carte complète qu'au moment où un NOUVEAU morceau la réclame.
	_prete = avant
	_prete_perime = true

## Tout bâtir, pour le banc photo et pour l'export d'une image d'ensemble. À ne
## jamais appeler dans le jeu : c'est la minute qu'on cherche à éviter.
func tout() -> void:
	var colonnes := int(ceil(float(_large) / float(COTE)))
	var lignes := int(ceil(float(_haut) / float(COTE)))
	for y in lignes:
		for x in colonnes:
			_batir(Vector2i(x, y))
