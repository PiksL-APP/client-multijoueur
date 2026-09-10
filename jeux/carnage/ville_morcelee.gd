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

var _prete: Dictionary = {}
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

func _process(_delta: float) -> void:
	var faits := 0
	while faits < par_image and not _file.is_empty():
		_batir(_file.pop_front())
		faits += 1

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
	_prete = Quartiers.preparer(fiche)
	var a_refaire: Dictionary = {}
	for v in cases:
		var c: Vector2i = v
		# Les huit voisins aussi : un bâtiment ou un raccord de rue déborde sur
		# le morceau d'à côté, et le bord serait resté sur l'ancienne version.
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var m := Vector2i(floori(float(c.x + dx) / float(COTE)),
					floori(float(c.y + dy) / float(COTE)))
				a_refaire[m] = true
	for cle in a_refaire.keys():
		if not _morceaux.has(cle): continue
		(_morceaux[cle] as Node3D).queue_free()
		_morceaux.erase(cle)
		_batir(cle)

## Tout bâtir, pour le banc photo et pour l'export d'une image d'ensemble. À ne
## jamais appeler dans le jeu : c'est la minute qu'on cherche à éviter.
func tout() -> void:
	var colonnes := int(ceil(float(_large) / float(COTE)))
	var lignes := int(ceil(float(_haut) / float(COTE)))
	for y in lignes:
		for x in colonnes:
			_batir(Vector2i(x, y))
