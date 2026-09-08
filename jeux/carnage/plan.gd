class_name PlanVille
extends RefCounted
## Le plan de la ville de CARNAGE, déduit du CODE de la manche.
##
## Rien de tout ceci ne circule sur le réseau : même code, même ville, chez
## tout le monde et à tout instant, y compris pour qui rejoint en retard.
##
## La ville fait six cent quatre-vingts tuiles sur cinq cent vingt — cent fois
## la surface de la précédente. Elle ne se génère donc JAMAIS d'un bloc : tout
## est une FONCTION PURE des coordonnées et du code (`_bruit`), calculée à la
## demande, pâté par pâté, et mise en cache. Un joueur ne voit jamais qu'une
## poignée de morceaux ; l'hôte ne simule qu'autour des joueurs. Générer trois
## cent cinquante mille tuiles au coup d'envoi bloquerait le navigateur dix
## secondes et ferait tomber le socket — pour bâtir une ville dont personne ne
## visitera jamais les neuf dixièmes.
##
## Dix types de quartiers, tirés par un zonage de Voronoï à graines jetées sur
## une grille : le centre d'affaires neutre et ses tours, les quartiers de
## bureaux, les rues commerçantes, la vieille ville, les cités, la banlieue
## pavillonnaire, la zone industrielle, le port, les parcs et les plans d'eau.
## Trois gangs se partagent la ville par secteurs angulaires bruités : les
## frontières sont irrégulières, et le décor dit chez qui on est avant la jauge.
##
## Les rues font DEUX tuiles de large : trottoir, file de stationnement, voie
## de circulation, de chaque côté d'un axe. Une rue d'une tuile ne laissait pas
## la place à la fois aux voitures garées et au trafic : celui-ci freinait
## derrière les garées et klaxonnait sans fin.
##
## ⚠ Les collisions ne balayent PAS une liste de rectangles : une tuile se
## déduit d'une position par deux divisions, et chaque tuile porte au plus un
## rectangle. On ne teste jamais plus des quatre tuiles qui touchent le cercle.

const TUILE := 10.0                          ## côté d'une tuile, en unités 3D
const PAS := TUILE / Decor.ECHELLE           ## le même, en pixels de jeu (100)
const PERIODE := 5                           ## 2 tuiles de rue + 3 tuiles de pâté
const COLONNES := 680
const LIGNES := 520
const MORCEAU := 20                          ## tuiles par morceau rendu (4 pâtés)
const SECTEUR := 40                          ## tuiles par secteur de lieux (8 pâtés)
const TROTTOIR := 20.0                       ## px : la bande piétonne au bord d'une rue
const FILE := 25.0                           ## px : la voie de circulation, depuis l'axe
const STATIONNEMENT := 35.0                  ## px : la file de stationnement, depuis le bord
## px : ce qu'une façade laisse au bord de sa tuile. Deux immeubles voisins
## sont donc séparés du DOUBLE. ⚠ À douze, avec les quartiers qui rognaient
## encore (le commerce à la moitié, le vieux au tiers), les façades se
## touchaient et la ville n'était plus qu'un bloc : il faut voir le jour entre
## deux immeubles pour croire que ce sont deux immeubles.
const RETRAIT := 15.0
## Ce qu'un quartier serré garde quand même — aucun réglage ne descend en
## dessous.
const RETRAIT_MIN := 11.0
const RAYON_CENTRE := 8.0                    ## en pâtés : le centre d'affaires, neutre

## Les quartiers.
enum { CENTRE, AFFAIRES, COMMERCE, VIEUX, RESIDENCES, BANLIEUE, INDUSTRIE, PORT, PARC, EAU }
const NOMS_QUARTIERS := ["centre d'affaires", "quartier des bureaux", "rues commerçantes",
	"vieille ville", "les cités", "banlieue pavillonnaire", "zone industrielle", "le port",
	"parc", "plan d'eau"]

## Les sols, tels que le shader du sol les dessine (`jeux/carnage/matieres.gd`).
enum { S_ROUTE, S_PASSAGE_A, S_PASSAGE_B, S_CARREFOUR, S_TROTTOIR, S_PAVES, S_HERBE,
	S_ALLEE_V, S_ALLEE_H, S_ALLEE_X, S_BETON, S_PARKING, S_EAU, S_TERRE, S_RAIL, S_BOULEVARD, S_PLACE, S_ESPLANADE }

## Les styles de façade, tels que le shader des immeubles les dessine.
enum { F_BUREAUX, F_LOGEMENTS, F_COMMERCE, F_VIEUX, F_HANGAR, F_MAISON, F_PLEIN, F_TOUR }

## Trois gangs, trois territoires, trois façons de bâtir. La couleur du gang
## n'est jamais SÉRIE : le bleu est à la police, et on ne confond pas celui qui
## vous verbalise avec celui qui vous canarde.
const GANGS := [
	{"nom": "Les Braises", "couleur": Palette.CRITIQUE, "quartier": INDUSTRIE},
	{"nom": "La Fonte", "couleur": Palette.SERIEUX, "quartier": COMMERCE},
	{"nom": "Le Lierre", "couleur": Palette.BON, "quartier": BANLIEUE},
]

## Les teintes de façade par style. Ce sont des matières de décor, pas des
## couleurs d'interface : elles restent sourdes pour que la palette (joueurs,
## gangs, lieux) garde seule le droit d'être vive.
const TEINTES := {
	F_BUREAUX: [Color("#8fa3b5"), Color("#b9b2a2"), Color("#6f8aa6"), Color("#c9c2b4"), Color("#7e9aa8"), Color("#a7a59c")],
	F_TOUR: [Color("#3f6f8f"), Color("#4a7f96"), Color("#2f5a78"), Color("#5a8aa0"), Color("#476a8a")],
	F_LOGEMENTS: [Color("#d9b58a"), Color("#c98f6c"), Color("#e0c9a6"), Color("#b98a72"), Color("#d8a878"), Color("#c4a07e")],
	F_COMMERCE: [Color("#c8553a"), Color("#3f8a86"), Color("#d9a441"), Color("#7a4f8a"), Color("#e2d3b0"), Color("#b8443f"), Color("#4f7a9c"), Color("#d47a3c")],
	F_VIEUX: [Color("#d29a5e"), Color("#b8624a"), Color("#e0b98a"), Color("#a8674d"), Color("#e8c99a"), Color("#c47a5a"), Color("#9c5a4a")],
	F_HANGAR: [Color("#7d8a8f"), Color("#9a8570"), Color("#6b7f86"), Color("#a08a6a"), Color("#8c9a7c"), Color("#b0a08a")],
	F_MAISON: [Color("#f0e6d0"), Color("#e8d8b8"), Color("#d8e4e8"), Color("#f2d9b0"), Color("#e6e0d0"), Color("#d0dcc0"), Color("#f0d0c0")],
	F_PLEIN: [Color("#4a4d52"), Color("#54575c"), Color("#3e4146")],
}
## Les toits, par style : tuile et terre cuite pour les logements et la vieille
## ville, gravier clair pour les bureaux, goudron sombre pour les hangars, et
## des terrasses. Vus de dessus — et la caméra les voit d'abord — ce sont eux
## qui colorent la ville.
const TOITS_PAR_STYLE := {
	F_BUREAUX: [Color("#a8a49c"), Color("#8c8a84"), Color("#b8b0a0"), Color("#6e7278")],
	F_TOUR: [Color("#4a5560"), Color("#5a6a78"), Color("#3c4650")],
	F_LOGEMENTS: [Color("#a8503a"), Color("#b86a48"), Color("#8c4a3a"), Color("#7a6a60"), Color("#c07a5a")],
	F_COMMERCE: [Color("#7a5a4a"), Color("#8c8278"), Color("#a05a40"), Color("#606870")],
	F_VIEUX: [Color("#a8503a"), Color("#c06a48"), Color("#8c4a3a"), Color("#b86a4a"), Color("#5a5a60")],
	F_HANGAR: [Color("#5a6068"), Color("#6a6a62"), Color("#7a5a4a"), Color("#50585e")],
	F_MAISON: [Color("#a8503a"), Color("#4a4f5a"), Color("#c06a48"), Color("#3f4046"), Color("#946444"), Color("#5a4a44")],
	F_PLEIN: [Color("#3a3d42")],
}
## Les toits des maisons : tuile, ardoise, zinc. Vus de dessus, ce sont eux
## qui font la banlieue.
const TOITS := [Color("#7a3f2e"), Color("#4a4f5a"), Color("#8a4f38"), Color("#3f4046"), Color("#946444"), Color("#5a4a44")]
## Les enseignes : uniquement des couleurs de la palette, pour que le néon d'un
## bar ne se confonde pas avec un signal du jeu — il les EMPRUNTE, ce qui reste
## lisible parce qu'une enseigne est en hauteur, sur une façade.
const NEONS := [Palette.CRITIQUE, Palette.SERIEUX, Palette.AVERTISSEMENT, Palette.BON, Palette.SERIE]

## Ce qui casse la grille — une ville n'est pas un quadrillage : des AVENUES
## (une rue sur quatre, arborée, jamais coupée), des rues fermées qui fondent
## deux pâtés en un seul îlot avec une cour au milieu (souvent dans la zone
## industrielle et les parcs, jamais dans la vieille ville), une RIVIÈRE qui
## serpente d'ouest en est et ne se franchit que par les avenues, et une côte
## irrégulière tout autour. C'est la carte de GTA 2 : des îlots de toutes
## tailles, de l'eau, des ponts.
const AVENUE := 4                            ## une rue sur quatre est une avenue
const LARGEUR_RIVIERE := 7.0                 ## en tuiles
## Deux échelles de fermeture : des ÎLOTS de deux pâtés sur deux fondus d'un
## bloc (leurs quatre rues intérieures deviennent une cour en croix), puis
## quelques rues fermées une à une. Les fermetures au hasard seules donnaient
## un semis de petits carrés sans structure ; les îlots donnent de vrais gros
## blocs — l'usine, le parc, la cité — comme sur la carte de GTA 2.
const FUSION := {CENTRE: 0.22, AFFAIRES: 0.32, COMMERCE: 0.18, VIEUX: 0.12, RESIDENCES: 0.55,
	BANLIEUE: 0.40, INDUSTRIE: 0.65, PORT: 0.55, PARC: 0.75, EAU: 0.0}
const FERMETURE := {CENTRE: 0.14, AFFAIRES: 0.18, COMMERCE: 0.16, VIEUX: 0.20, RESIDENCES: 0.28,
	BANLIEUE: 0.26, INDUSTRIE: 0.30, PORT: 0.26, PARC: 0.40, EAU: 0.0}
## Le DÉCALAGE : entre deux avenues, une rue transversale sur deux s'arrête
## en T — comme les briques d'un mur, jamais alignées d'un rang à l'autre. C'est
## LE motif qui fait qu'une ville ne se lit pas comme un quadrillage : on
## remplace la plupart des carrefours par des T. Une rue « décalée » devient
## une cour qu'on traverse quand même (voir `_cour`).
const DECALAGE := {CENTRE: 0.6, AFFAIRES: 0.6, COMMERCE: 0.65, VIEUX: 0.7, RESIDENCES: 0.65,
	BANLIEUE: 0.65, INDUSTRIE: 0.50, PORT: 0.45, PARC: 0.60, EAU: 0.0}
## Les PÂTÉS LONGS : par secteur, la ville a un sens — ses rues courent d'est
## en ouest ou du nord au sud — et une rue transversale sur deux se ferme sur
## trois pâtés d'affilée. Des blocs de trois par huit ou treize tuiles, comme à
## Manhattan ou Barcelone : c'est ce qui casse le damier de pâtés carrés.
const LONG := {CENTRE: 0.55, AFFAIRES: 0.6, COMMERCE: 0.5, VIEUX: 0.4, RESIDENCES: 0.55,
	BANLIEUE: 0.35, INDUSTRIE: 0.5, PORT: 0.4, PARC: 0.3, EAU: 0.0}
## Dans les quartiers denses, une rue fermée est BÂTIE — les immeubles des deux
## pâtés se rejoignent — et non laissée en cour pavée : une cour de la largeur
## d'une rue, vue d'en haut, c'est encore une rue.
const QUARTIERS_BATIS := [CENTRE, AFFAIRES, COMMERCE, VIEUX, RESIDENCES]
## La voie ferrée : une ligne droite, en biais, d'un bord à l'autre. C'est le
## seul trait de la ville qui ne suive pas la grille — et c'est ce qui la fait
## lire comme une ville plutôt que comme un quadrillage.
const LARGEUR_RAIL := 2.2                    ## en tuiles

const RAYON_ARENE := 190.0
const RAYON_GARAGE := 60.0
const RAYON_CABINE := 68.0
const RAYON_REPAIRE := 230.0
const RAYON_HOPITAL := 90.0
const RAYON_PLANQUE := 70.0
## Le prix d'une planque : trois gammes, du studio à la villa. Le pâté décide,
## comme tout le reste — même prix chez tout le monde, sans rien diffuser.
## Les prix sont calés sur ce qu'on gagne : un contrat rapporte quelques
## centaines de dollars, une planque de quartier s'atteint en une dizaine de
## minutes, la villa demande une vraie soirée.
const PRIX_PLANQUE := [2500, 6000, 12000]
## Le prix des améliorations, dans l'ordre : coffre (garde plus d'argent),
## arsenal (garde les armes), garage (garde un véhicule).
const PRIX_AMELIORATION := {"coffre": 1800, "arsenal": 3200, "garage": 5000}

## Identifiant de la première voiture dormante. Une voiture garée par le plan
## n'existe chez l'hôte qu'une fois RÉVEILLÉE (volée, percutée, tirée) : son
## identifiant se déduit de sa tuile, et ne croise jamais ceux de l'hôte.
const ID_DORMANTE := 1000000
const COTES := 6            ## quatre bords de tuile + deux places de parking intérieur

var code := ""
var _sel := 0
var _phases: Array = [0.0, 0.0, 0.0, 0.0]   ## déphasages de la côte et de la rivière
var _semences: Dictionary = {}    ## Vector2i (cellule de 8 pâtés) -> {p, type, gang}
var _zones: Dictionary = {}       ## indice de pâté -> type | (gang + 1) << 8
var _pates: Dictionary = {}       ## Vector2i (pâté) -> Array[9] de fiches de tuile
var _rues: Dictionary = {}        ## indice de tuile -> fiche de tuile de rue
var _secteurs: Dictionary = {}    ## Vector2i -> {garages, cabines, arenes, repaires}
var _libres: Dictionary = {}      ## indice de tuile -> fiche de voie libre ({} si aucune)

# ------------------------------------------------------------ construction

func _init(code_de_manche: String) -> void:
	code = code_de_manche
	_sel = hash(code)
	for i in 4:
		_phases[i] = _bruit(i, 0, 5) * TAU
	_tracer_les_voies_libres()

func etendue() -> Vector2:
	return Vector2(COLONNES, LIGNES) * PAS

func centre() -> Vector2:
	return etendue() * 0.5

## Marge jouable au-delà des dernières tuiles : c'est de l'eau, et le rappel
## vers le centre ramène qui s'y aventure.
func banlieue() -> float:
	return 3.0 * PAS

# ------------------------------------------------------------ le bruit

## LE générateur de toute la ville : un nombre dans [0,1) qui ne dépend que de
## deux coordonnées, d'un sel et du code. Pas d'état, pas d'ordre d'appel :
## n'importe quel morceau peut se calculer avant n'importe quel autre, chez
## n'importe quel joueur, et donner la même chose.
func _bruit(a: int, b: int, sel: int) -> float:
	var h := hash(Vector4i(a, b, sel, _sel))
	return float(h & 0x7FFFFF) / 8388608.0

func _entier(a: int, b: int, sel: int, n: int) -> int:
	return min(n - 1, int(_bruit(a, b, sel) * float(n)))

func _parmi(liste: Array, a: int, b: int, sel: int):
	return liste[_entier(a, b, sel, liste.size())]

# ------------------------------------------------------------ la grille

## Vrai si cette colonne (ou cette ligne) porte une rue. Deux tuiles de rue
## puis trois de pâté : la période est de cinq.
static func est_voie(indice: int) -> bool:
	return posmod(indice, PERIODE) < 2

static func centre_tuile(colonne: int, ligne: int) -> Vector2:
	return Vector2(colonne + 0.5, ligne + 0.5) * PAS

static func pates_x() -> int:
	return COLONNES / PERIODE

static func pates_y() -> int:
	return LIGNES / PERIODE

## Le pâté (3×3 tuiles entre les rues) qui contient une tuile, ou (-1,-1).
static func pate_de(colonne: int, ligne: int) -> Vector2i:
	if colonne < 0 or ligne < 0 or colonne >= COLONNES or ligne >= LIGNES:
		return Vector2i(-1, -1)
	if est_voie(colonne) or est_voie(ligne):
		return Vector2i(-1, -1)
	return Vector2i(colonne / PERIODE, ligne / PERIODE)

## Première tuile (nord-ouest) d'un pâté.
static func coin_pate(pate: Vector2i) -> Vector2i:
	return Vector2i(pate.x * PERIODE + 2, pate.y * PERIODE + 2)

static func centre_pate(pate: Vector2i) -> Vector2:
	return centre_tuile(pate.x * PERIODE + 3, pate.y * PERIODE + 3)

static func indice_pate(pate: Vector2i) -> int:
	return pate.y * pates_x() + pate.x

static func pate_par_indice(indice: int) -> Vector2i:
	return Vector2i(posmod(indice, pates_x()), indice / pates_x())

## L'axe de la rue la plus proche, dans un axe : entre les deux tuiles de rue.
func voie_proche(valeur: float) -> float:
	var k := int(round((valeur / PAS - 1.0) / float(PERIODE)))
	return float(k * PERIODE + 1) * PAS

func carrefour_proche(point: Vector2) -> Vector2:
	return Vector2(voie_proche(point.x), voie_proche(point.y))

## Vrai sur le BITUME d'une rue — pas sur son trottoir. C'est ce que le passant
## consulte avant de descendre du trottoir, et il se ravise deux fois sur
## trois : sans ça, la moitié de la foule marche au milieu des avenues.
func sur_la_chaussee(point: Vector2) -> bool:
	var colonne := int(floor(point.x / PAS))
	var ligne := int(floor(point.y / PAS))
	var libre := voie_libre(colonne, ligne)
	if not libre.is_empty():
		if String(libre["genre"]) == "esplanade":
			return false
		if String(libre["genre"]) == "place":
			var r: float = libre["r"]
			return r > float(_etoiles[int(libre["e"])]["ilot"]) and r < float(_etoiles[int(libre["e"])]["r"]) - TROTTOIR_BOULEVARD
		return abs(float(libre["s"])) < LARGEUR_BOULEVARD * 0.5 - TROTTOIR_BOULEVARD
	var vc := est_voie(colonne)
	var vl := est_voie(ligne)
	if not vc and not vl:
		return false
	var dx: float = abs(point.x - voie_proche(point.x))
	var dy: float = abs(point.y - voie_proche(point.y))
	return (vc and dx < PAS - TROTTOIR) or (vl and dy < PAS - TROTTOIR)

func sur_une_rue(point: Vector2, tolerance: float = 0.0) -> bool:
	var colonne := int(floor(point.x / PAS))
	var ligne := int(floor(point.y / PAS))
	if est_voie(colonne) or est_voie(ligne) or not voie_libre(colonne, ligne).is_empty():
		return true
	if tolerance <= 0.0:
		return false
	return abs(point.x - voie_proche(point.x)) < PAS + tolerance \
		or abs(point.y - voie_proche(point.y)) < PAS + tolerance

# ------------------------------------------------------------ les voies libres

## Ce qui casse le damier. Une ville qui n'est qu'une grille se lit comme un
## circuit imprimé : GTA 2 avait ses diagonales, Paris son étoile et ses
## boulevards. Ici : une PLACE EN ÉTOILE un peu au nord du centre, six avenues
## qui en rayonnent en diagonale jusqu'à la côte, deux places secondaires avec
## leurs quatre avenues, un BOULEVARD CIRCULAIRE (une ellipse) autour de la
## grande place, et les GRANDS BOULEVARDS — une seconde ellipse, large, qui
## ceinture le centre et franchit la rivière sur deux ponts.
##
## Ces voies ne suivent pas la grille : une tuile qu'elles traversent devient
## du boulevard quoi qu'en dise la grille, le pâté qu'elles coupent perd ses
## immeubles, et le shader du sol trace la chaussée en espace monde (comme la
## voie ferrée). Le trafic les suit par leur tangente (`voie_libre_en`).
const LARGEUR_BOULEVARD := 3.0       ## en tuiles : chaussée et trottoirs
const TROTTOIR_BOULEVARD := 0.6      ## en tuiles, de chaque côté
const FILE_BOULEVARD := 0.6          ## en tuiles : la file de droite, depuis l'axe
const ESPLANADE := 5.0               ## en tuiles : autour d'une place, les rues de la grille deviennent une esplanade pavée
const MAX_LIGNES := 7                ## ce que le shader du sol accepte

var _etoiles: Array = []          ## {p: Vector2 (tuiles), r: rayon, lignes: [indices dans _lignes]}
var _lignes: Array = []           ## {o: origine (tuiles), d: direction, n: normale, l_plus, l_moins}
var _anneaux: Array = []          ## {c: centre (tuiles), rx, ry}

func _tracer_les_voies_libres() -> void:
	_etoiles = []
	_lignes = []
	_anneaux = []
	# La grande place : au nord de la rivière, jamais dessus. Trois lignes, six
	# branches, à soixante degrés les unes des autres à peu près — et jamais à
	# moins de quinze degrés d'un axe de la grille, sinon l'avenue longe une
	# rue sur trois pâtés et les deux se marchent dessus.
	var grande := Vector2(float(COLONNES) * lerpf(0.42, 0.58, _bruit(3, 0, 7)),
		float(LIGNES) * lerpf(0.30, 0.42, _bruit(4, 0, 7)))
	_etoile(grande, 4.2, 3, deg_to_rad(lerpf(18.0, 42.0, _bruit(5, 0, 7))), 120.0, 260.0, 20)
	# Deux places secondaires : une au sud de la rivière, une à l'est, quatre
	# branches chacune, plus courtes.
	_etoile(Vector2(float(COLONNES) * lerpf(0.28, 0.44, _bruit(3, 1, 7)), float(LIGNES) * lerpf(0.70, 0.80, _bruit(4, 1, 7))),
		3.0, 2, deg_to_rad(lerpf(20.0, 70.0, _bruit(5, 1, 7))), 50.0, 120.0, 40)
	_etoile(Vector2(float(COLONNES) * lerpf(0.72, 0.84, _bruit(3, 2, 7)), float(LIGNES) * lerpf(0.36, 0.52, _bruit(4, 2, 7))),
		3.0, 2, deg_to_rad(lerpf(20.0, 70.0, _bruit(5, 2, 7))), 50.0, 110.0, 60)
	# Le boulevard circulaire autour de la grande place, et les grands
	# boulevards autour du centre de la ville — assez larges pour couper la
	# rivière et la voie ferrée.
	var r1 := lerpf(40.0, 52.0, _bruit(12, 0, 7))
	_anneaux.append({"c": grande, "rx": r1, "ry": r1 * lerpf(0.78, 0.92, _bruit(13, 0, 7))})
	var centre_v := Vector2(float(COLONNES) * lerpf(0.47, 0.53, _bruit(14, 0, 7)), float(LIGNES) * lerpf(0.50, 0.56, _bruit(15, 0, 7)))
	_anneaux.append({"c": centre_v, "rx": float(COLONNES) * lerpf(0.21, 0.25, _bruit(16, 0, 7)),
		"ry": float(LIGNES) * lerpf(0.23, 0.28, _bruit(17, 0, 7))})

func _etoile(p: Vector2, rayon: float, combien: int, base: float, court: float, long: float, sel: int) -> void:
	var indices: Array = []
	for i in combien:
		if _lignes.size() >= MAX_LIGNES:
			break
		var angle := base + float(i) * PI / float(combien) + deg_to_rad((_bruit(sel + i, 0, 7) - 0.5) * 16.0)
		var reste := fmod(angle, PI * 0.5)
		if reste < deg_to_rad(15.0):
			angle += deg_to_rad(15.0) - reste
		elif reste > deg_to_rad(75.0):
			angle -= reste - deg_to_rad(75.0)
		var d := Vector2.RIGHT.rotated(angle)
		indices.append(_lignes.size())
		_lignes.append({"o": p, "d": d, "n": Vector2(-d.y, d.x),
			"l_plus": lerpf(court, long, _bruit(sel + 5 + i, 0, 7)), "l_moins": lerpf(court, long, _bruit(sel + 9 + i, 0, 7))})
	# L'îlot central grandit avec la place : le monument a besoin de place.
	_etoiles.append({"p": p, "r": rayon, "ilot": rayon * 0.38, "lignes": indices})

## La fiche de voie libre d'un point (en TUILES, flottant) : vide si la grille
## commande. Sinon {genre: "place" | "avenue" | "anneau", d: tangente (sens
## arbitraire), s: distance signée à l'axe en tuiles (positive à DROITE de d),
## et pour une place : c (son centre en tuiles), r (distance au centre), e
## (l'indice de la place)}.
func _voie_libre_a(p: Vector2) -> Dictionary:
	for e in _etoiles.size():
		var etoile: Dictionary = _etoiles[e]
		var vers_e: Vector2 = p - etoile["p"]
		var r := vers_e.length()
		var rayon: float = etoile["r"]
		var ilot: float = etoile["ilot"]
		if r < rayon:
			var radial := vers_e / maxf(r, 0.001)
			# `s` suit la même convention que sur un boulevard : positif à DROITE
			# de la tangente, c'est-à-dire vers l'îlot. L'axe de la chaussée est
			# au milieu de l'anneau roulable ; la file de droite, une file plus
			# près de l'îlot.
			var axe := (ilot + rayon - TROTTOIR_BOULEVARD) * 0.5
			return {"genre": "place", "d": Vector2(-radial.y, radial.x), "s": axe - r,
				"r": r, "c": etoile["p"], "e": e}
		# Autour de la place, les rues de la GRILLE deviennent une esplanade
		# pavée : c'est ce qui donne à la place son parvis, au lieu d'une mer
		# de bitume où six avenues et quatre rues se rejoignent.
		if r < rayon + ESPLANADE:
			var c := int(floor(p.x))
			var l := int(floor(p.y))
			if est_voie(c) or est_voie(l):
				var radial := vers_e / maxf(r, 0.001)
				return {"genre": "esplanade", "d": Vector2(-radial.y, radial.x), "s": 0.0, "r": r, "c": etoile["p"], "e": e}
	var meilleure := {}
	var plus_pres := 1e9
	for b in _lignes:
		var vers: Vector2 = p - b["o"]
		var le_long: float = vers.dot(b["d"])
		var s: float = vers.dot(b["n"])
		if le_long < -float(b["l_moins"]) or le_long > float(b["l_plus"]):
			continue
		if abs(s) < LARGEUR_BOULEVARD * 0.5 and abs(s) < plus_pres:
			plus_pres = abs(s)
			# Une branche va DE la place VERS le large : sa tangente est orientée
			# dans le sens du côté où l'on est. Deux branches opposées d'une même
			# ligne ont ainsi la même géométrie et une tangente cohérente.
			var d: Vector2 = b["d"] if le_long >= 0.0 else -(b["d"] as Vector2)
			meilleure = {"genre": "avenue", "d": d, "s": s if le_long >= 0.0 else -s}
	# Les anneaux : la distance signée à une ellipse, approchée par le rayon moyen.
	for a in _anneaux:
		var vers: Vector2 = p - a["c"]
		var rx: float = a["rx"]
		var ry: float = a["ry"]
		var q := Vector2(vers.x / rx, vers.y / ry)
		var s_anneau := (q.length() - 1.0) * (rx + ry) * 0.5
		if abs(s_anneau) < LARGEUR_BOULEVARD * 0.5 and abs(s_anneau) < plus_pres:
			plus_pres = abs(s_anneau)
			var radial := Vector2(q.x / rx, q.y / ry).normalized()
			# « À droite » de la tangente (-ry, rx), c'est vers le CENTRE : la
			# distance signée change donc de signe pour suivre la convention.
			meilleure = {"genre": "anneau", "d": Vector2(-radial.y, radial.x), "s": -s_anneau}
	return meilleure

## La fiche de voie libre d'une TUILE, mise en cache : c'est elle que `tuile`
## consulte, et le morceau après elle.
func voie_libre(colonne: int, ligne: int) -> Dictionary:
	var indice := ligne * COLONNES + colonne
	if not _libres.has(indice):
		_libres[indice] = _voie_libre_a(Vector2(float(colonne) + 0.5, float(ligne) + 0.5))
	return _libres[indice]

## La même chose en un point en PIXELS, sans cache et sans quantification : le
## trafic s'en sert pour tenir sa file sur le boulevard.
func voie_libre_en(point: Vector2) -> Dictionary:
	return _voie_libre_a(point / PAS)

## Le pâté est-il coupé par une voie libre ? Une de ses neuf tuiles suffit.
func _coupe(pate: Vector2i) -> bool:
	var coin := coin_pate(pate)
	for j in 3:
		for i in 3:
			if not voie_libre(coin.x + i, coin.y + j).is_empty():
				return true
	return false

## La grande place en étoile, en pixels : c'est là qu'on regarde d'abord.
func place_etoile() -> Vector2:
	return Vector2(_etoiles[0]["p"]) * PAS

## Les avenues qui partent d'une place : directions unitaires, dans les deux
## sens — pour le trafic qui en sort.
func sorties_de_la_place(e: int) -> Array:
	var liste: Array = []
	for i in _etoiles[e]["lignes"]:
		liste.append(Vector2(_lignes[i]["d"]))
		liste.append(-Vector2(_lignes[i]["d"]))
	return liste

## Les paramètres pour le shader du sol, en unités monde : les lignes
## (normale, offset, +), leurs origines et longueurs, les ellipses, les places.
func lignes_libres() -> PackedVector4Array:
	var liste := PackedVector4Array()
	for b in _lignes:
		var n: Vector2 = b["n"]
		liste.append(Vector4(n.x, n.y, n.dot(b["o"]) * TUILE, 0.0))
	while liste.size() < MAX_LIGNES:
		liste.append(Vector4(0.0, 1.0, -100000.0, 0.0))
	return liste

func origines_libres() -> PackedVector4Array:
	var liste := PackedVector4Array()
	for b in _lignes:
		var o: Vector2 = b["o"]
		liste.append(Vector4(o.x * TUILE, o.y * TUILE, float(b["l_plus"]) * TUILE, float(b["l_moins"]) * TUILE))
	while liste.size() < MAX_LIGNES:
		liste.append(Vector4(0.0, 0.0, 0.0, 0.0))
	return liste

func anneaux_libres() -> PackedVector4Array:
	var liste := PackedVector4Array()
	for a in _anneaux:
		liste.append(Vector4(Vector2(a["c"]).x * TUILE, Vector2(a["c"]).y * TUILE, float(a["rx"]) * TUILE, float(a["ry"]) * TUILE))
	while liste.size() < 2:
		liste.append(Vector4(-100000.0, -100000.0, 1.0, 1.0))
	return liste

func etoiles_libres() -> PackedVector4Array:
	var liste := PackedVector4Array()
	for e in _etoiles:
		liste.append(Vector4(Vector2(e["p"]).x * TUILE, Vector2(e["p"]).y * TUILE, float(e["r"]) * TUILE, float(e["ilot"]) * TUILE))
	while liste.size() < 3:
		liste.append(Vector4(-100000.0, -100000.0, 1.0, 0.5))
	return liste

# ------------------------------------------------------------ le zonage

## La graine de zonage d'une cellule de huit pâtés : une position bruitée dans
## la cellule, un type de quartier tiré selon la distance au centre, un gang
## tiré selon l'angle. Voronoï sur ces graines : chaque pâté revient à la plus
## proche, avec un peu de bruit pour que la frontière ne soit pas une droite.
const CELLULE := 8.0

func _semence(cellule: Vector2i) -> Dictionary:
	if _semences.has(cellule):
		return _semences[cellule]
	var p := Vector2(cellule) * CELLULE + Vector2(
		0.5 + (_bruit(cellule.x, cellule.y, 11) - 0.5) * 0.9,
		0.5 + (_bruit(cellule.x, cellule.y, 12) - 0.5) * 0.9) * CELLULE
	var milieu := Vector2(pates_x(), pates_y()) * 0.5
	var r := p.distance_to(milieu)
	var au_bord: float = min(min(p.x, float(pates_x()) - p.x), min(p.y, float(pates_y()) - p.y))
	var angle := (p - milieu).angle() + (_bruit(cellule.x, cellule.y, 13) - 0.5) * 0.9
	var gang := posmod(int(floor((angle + PI * 0.5) / (TAU / 3.0))), 3)
	var t := _bruit(cellule.x, cellule.y, 14)
	var type := BANLIEUE
	if r < RAYON_CENTRE + 9.0:
		type = AFFAIRES if t < 0.42 else (COMMERCE if t < 0.72 else VIEUX)
	elif r < RAYON_CENTRE + 26.0:
		if t < 0.18: type = COMMERCE
		elif t < 0.42: type = RESIDENCES
		elif t < 0.52: type = VIEUX
		elif t < 0.68: type = INDUSTRIE
		elif t < 0.80: type = PARC
		elif t < 0.92: type = BANLIEUE
		else: type = EAU
	else:
		if t < 0.30: type = BANLIEUE
		elif t < 0.48: type = INDUSTRIE
		elif t < 0.60: type = RESIDENCES
		elif t < 0.74: type = PARC
		elif t < 0.86: type = EAU
		else: type = PORT if au_bord < 14.0 else INDUSTRIE
	# Chaque gang bâtit à sa façon : une graine sur trois de son secteur prend
	# le type de quartier qui le caractérise. C'est ce qui fait que les terres
	# des Braises FUMENT et que celles du Lierre ont des jardins.
	if r >= RAYON_CENTRE + 9.0 and type != EAU and type != PORT and _bruit(cellule.x, cellule.y, 15) < 0.34:
		type = int(GANGS[gang]["quartier"])
	var fiche := {"p": p, "type": type, "gang": gang}
	_semences[cellule] = fiche
	return fiche

func _zone(pate: Vector2i) -> int:
	var indice := indice_pate(pate)
	if _zones.has(indice):
		return _zones[indice]
	var ici := Vector2(pate) + Vector2(0.5, 0.5)
	var milieu := Vector2(pates_x(), pates_y()) * 0.5
	var valeur := 0
	if ici.distance_to(milieu) < RAYON_CENTRE:
		valeur = CENTRE                      # gang -1 -> 0 dans l'octet haut
	else:
		var cellule := Vector2i(int(floor(ici.x / CELLULE)), int(floor(ici.y / CELLULE)))
		var meilleure := INF
		var gagnante := {}
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var s := _semence(cellule + Vector2i(dx, dy))
				var d: float = ici.distance_to(s["p"]) + (_bruit(pate.x, pate.y, 16 + dx * 3 + dy) - 0.5) * 1.6
				if d < meilleure:
					meilleure = d
					gagnante = s
		var type := int(gagnante["type"])
		var gang := int(gagnante["gang"])
		# Le premier anneau autour du centre reste commerçant et se dégrade
		# doucement : une ville a un dégradé, pas une frontière au carrefour.
		if ici.distance_to(milieu) < RAYON_CENTRE + 3.0 and type != EAU and _bruit(pate.x, pate.y, 17) < 0.5:
			type = AFFAIRES if _bruit(pate.x, pate.y, 18) < 0.5 else COMMERCE
		# Un peu de parc partout : c'est ce qui aère les cités et la banlieue.
		elif type != EAU and type != PARC and type != CENTRE and _bruit(pate.x, pate.y, 19) < 0.06:
			type = PARC
		valeur = type | ((gang + 1) << 8)
	_zones[indice] = valeur
	return valeur

func quartier_du_pate(pate: Vector2i) -> int:
	if pate.x < 0 or pate.y < 0 or pate.x >= pates_x() or pate.y >= pates_y():
		return EAU
	return _zone(pate) & 0xFF

func territoire_du_pate(pate: Vector2i) -> int:
	if pate.x < 0 or pate.y < 0 or pate.x >= pates_x() or pate.y >= pates_y():
		return -1
	return (_zone(pate) >> 8) - 1

# ------------------------------------------------------------ l'eau

## Hors de la côte : la ville est une île aux contours irréguliers, pas un
## rectangle. Le rayon limite varie avec l'angle, doucement.
func _hors_cote(colonne: int, ligne: int) -> bool:
	var d := Vector2((float(colonne) + 0.5) / float(COLONNES) - 0.5, (float(ligne) + 0.5) / float(LIGNES) - 0.5) * 2.0
	var angle := d.angle()
	var limite := 0.88 + 0.09 * sin(angle * 3.0 + float(_phases[0])) + 0.06 * sin(angle * 7.0 + float(_phases[1])) \
		+ 0.03 * sin(angle * 13.0 + float(_phases[2]))
	# Entre le cercle et le carré : le carré seul fait une île rectangulaire,
	# le cercle seul mange les quatre coins de la ville.
	var r: float = lerpf(d.length(), max(abs(d.x), abs(d.y)), 0.45)
	return r > limite

## La rivière : une bande qui serpente d'ouest en est, un peu au sud du centre.
func _ligne_de_riviere(colonne: int) -> float:
	var x := float(colonne)
	return float(LIGNES) * 0.58 + 26.0 * sin(x / 64.0 + float(_phases[3])) + 11.0 * sin(x / 21.0 + float(_phases[0]) * 2.0)

func _dans_la_riviere(colonne: int, ligne: int) -> bool:
	return abs(float(ligne) + 0.5 - _ligne_de_riviere(colonne)) < LARGEUR_RIVIERE * 0.5

## La voie ferrée passe-t-elle par cette tuile ? La ligne va du nord-ouest au
## sud-est, décalée par le code ; ses paramètres sont aussi donnés au shader du
## sol, qui trace les rails en espace monde.
func rail() -> Vector3:
	# ax + bz = c, en unités 3D ; la pente vient du code.
	var pente: float = lerpf(0.28, 0.42, _bruit(1, 1, 6))
	var origine: float = float(LIGNES) * lerpf(0.18, 0.32, _bruit(2, 2, 6))
	# z = origine + pente * x  ->  pente * x - z = -origine
	var n := Vector2(pente, -1.0).normalized()
	return Vector3(n.x, n.y, origine * TUILE * n.y)

func sur_le_rail(colonne: int, ligne: int) -> bool:
	var r := rail()
	var p := Vector2((float(colonne) + 0.5) * TUILE, (float(ligne) + 0.5) * TUILE)
	return abs(r.x * p.x + r.y * p.y - r.z) < LARGEUR_RAIL * 0.5 * TUILE

## De l'eau à cette tuile, quelle qu'en soit la raison — hors carte, hors côte,
## dans la rivière. Les ponts ne sont PAS de l'eau.
func eau(colonne: int, ligne: int) -> bool:
	if colonne < 0 or ligne < 0 or colonne >= COLONNES or ligne >= LIGNES:
		return true
	if _hors_cote(colonne, ligne):
		return true
	if _dans_la_riviere(colonne, ligne):
		return not (_est_pont(colonne) or sur_le_rail(colonne, ligne) or not voie_libre(colonne, ligne).is_empty())
	return false

## Une avenue (une rue verticale sur quatre) franchit la rivière : c'est un pont.
func _est_pont(colonne: int) -> bool:
	return est_voie(colonne) and posmod(colonne / PERIODE, AVENUE) == 0

static func est_avenue(indice: int) -> bool:
	return est_voie(indice) and posmod(indice / PERIODE, AVENUE) == 0

## Les rues FERMÉES : la rue verticale k, le long du pâté py, n'existe pas si
## les deux pâtés qu'elle sépare sont du même quartier et du même gang et que
## le tirage le veut. Les avenues ne se ferment jamais : c'est ce qui garantit
## qu'on traverse toujours la ville.
func rue_fermee_v(k: int, py: int) -> bool:
	if posmod(k, AVENUE) == 0:
		return false
	var a := Vector2i(k - 1, py)
	var b := Vector2i(k, py)
	if not _fermable(a, b):
		return false
	# La rue intérieure d'un îlot fondu : k impair, entre les pâtés 2g et 2g+1.
	if posmod(k, 2) == 1 and _ilot_fondu(Vector2i((k - 1) / 2, py / 2)):
		return true
	var quartier := quartier_du_pate(a)
	# Les pâtés longs : dans un secteur orienté est-ouest, une rue verticale sur
	# deux se ferme par tranches de trois pâtés.
	if posmod(k, 2) == 1 and _sens_est_ouest(a) and _bruit(k, py / 3, 305) < float(LONG.get(quartier, 0.0)):
		return true
	# Le décalage : les segments verticaux des rangs pairs (k + py pair).
	if posmod(k + py, 2) == 0 and _bruit(k, py, 303) < float(DECALAGE.get(quartier, 0.0)):
		return true
	return _bruit(k, py, 300) < float(FERMETURE.get(quartier, 0.0))

func rue_fermee_h(kl: int, px: int) -> bool:
	if posmod(kl, AVENUE) == 0:
		return false
	var a := Vector2i(px, kl - 1)
	var b := Vector2i(px, kl)
	if not _fermable(a, b):
		return false
	if posmod(kl, 2) == 1 and _ilot_fondu(Vector2i(px / 2, (kl - 1) / 2)):
		return true
	var quartier := quartier_du_pate(a)
	if posmod(kl, 2) == 1 and not _sens_est_ouest(a) and _bruit(kl, px / 3, 306) < float(LONG.get(quartier, 0.0)):
		return true
	# Et les segments horizontaux des rangs impairs : jamais les deux à la fois
	# autour d'un même carrefour, sinon la rue devient une impasse en croix.
	if posmod(kl + px, 2) == 1 and _bruit(kl, px, 304) < float(DECALAGE.get(quartier, 0.0)) * 0.6:
		return true
	return _bruit(kl, px, 301) < float(FERMETURE.get(quartier, 0.0))

## Le sens d'un secteur de huit pâtés : vrai si ses rues longues courent
## d'est en ouest (les pâtés s'allongent en x).
func _sens_est_ouest(pate: Vector2i) -> bool:
	var secteur := Vector2i(pate.x * PERIODE / SECTEUR, pate.y * PERIODE / SECTEUR)
	return _bruit(secteur.x, secteur.y, 307) < 0.5

## Un îlot de deux pâtés sur deux est fondu si ses quatre pâtés sont du même
## quartier, du même gang, sans lieu ni eau, et que le tirage le veut.
func _ilot_fondu(groupe: Vector2i) -> bool:
	var origine := groupe * 2
	var quartier := quartier_du_pate(origine)
	var gang := territoire_du_pate(origine)
	for dy in 2:
		for dx in 2:
			var pate := origine + Vector2i(dx, dy)
			if pate.x >= pates_x() or pate.y >= pates_y():
				return false
			if quartier_du_pate(pate) != quartier or territoire_du_pate(pate) != gang:
				return false
			if quartier == EAU or _lieu_du_pate(pate) != "":
				return false
			var coin := coin_pate(pate)
			if eau(coin.x + 1, coin.y + 1) or sur_le_rail(coin.x + 1, coin.y + 1):
				return false
	return _bruit(groupe.x, groupe.y, 302) < float(FUSION.get(quartier, 0.0))

func _fermable(a: Vector2i, b: Vector2i) -> bool:
	if a.x < 0 or a.y < 0 or b.x >= pates_x() or b.y >= pates_y():
		return false
	var qa := quartier_du_pate(a)
	if qa == EAU or qa != quartier_du_pate(b) or territoire_du_pate(a) != territoire_du_pate(b):
		return false
	# Un pâté qui porte un lieu garde ses quatre rues : un garage au fond
	# d'une cour ne se trouve pas.
	if _lieu_du_pate(a) != "" or _lieu_du_pate(b) != "":
		return false
	return true

# ------------------------------------------------------------ les lieux

## Les lieux d'un secteur de huit pâtés sur huit : un garage de peinture, une
## cabine à contrats, un ou deux repaires, et une arène une fois sur deux. À
## l'échelle de la ville, c'est un garage à moins de deux minutes de partout —
## le précédent plan en avait trois pour toute la ville, et à cinq étoiles on
## mourait avant d'en voir un.
func _lieux_du_secteur(secteur: Vector2i) -> Dictionary:
	if _secteurs.has(secteur):
		return _secteurs[secteur]
	var fiche := {"garages": [], "cabines": [], "arenes": [], "repaires": [], "hopitaux": [], "planques": []}
	var par_pate := SECTEUR / PERIODE
	var candidats: Array = []
	var frontieres: Array = []
	for j in par_pate:
		for i in par_pate:
			var pate := Vector2i(secteur.x * par_pate + i, secteur.y * par_pate + j)
			if pate.x < 0 or pate.y < 0 or pate.x >= pates_x() or pate.y >= pates_y():
				continue
			var q := quartier_du_pate(pate)
			if q == EAU or q == PARC:
				continue
			# Ni dans l'eau, ni sur la voie : un garage qui a les pieds dans la
			# rivière ne se trouve pas.
			var coin_l := coin_pate(pate)
			var noye := false
			for j2 in 3:
				for i2 in 3:
					if eau(coin_l.x + i2, coin_l.y + j2) or sur_le_rail(coin_l.x + i2, coin_l.y + j2):
						noye = true
			if noye or _coupe(pate):
				continue
			candidats.append(pate)
			var t := territoire_du_pate(pate)
			for voisin in [Vector2i(1, 0), Vector2i(0, 1)]:
				var autre := territoire_du_pate(pate + voisin)
				if autre >= 0 and t >= 0 and autre != t:
					frontieres.append(pate)
					break
	if candidats.is_empty():
		_secteurs[secteur] = fiche
		return fiche
	# Un tirage déterministe : le même secteur donne les mêmes lieux chez tout
	# le monde, sans qu'il faille les diffuser.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(secteur.x, secteur.y, _sel))
	var pris: Array = []
	var choisir := func(liste: Array) -> Vector2i:
		for essai in 24:
			var p: Vector2i = liste[rng.randi_range(0, liste.size() - 1)]
			if not (p in pris):
				pris.append(p)
				return p
		return Vector2i(-1, -1)
	var g: Vector2i = choisir.call(candidats)
	if g.x >= 0:
		var coin := coin_pate(g)
		fiche["garages"].append({"p": centre_tuile(coin.x, coin.y), "id": indice_pate(g), "pate": g})
	var c: Vector2i = choisir.call(candidats)
	if c.x >= 0:
		var coin_c := coin_pate(c)
		# Sur le trottoir du carrefour nord-ouest du pâté : au milieu du
		# carrefour, la première voiture qui tourne l'emporte.
		fiche["cabines"].append({"p": centre_tuile(coin_c.x, coin_c.y) - Vector2(PAS * 0.5 + 10.0, PAS * 0.5 + 10.0),
			"id": indice_pate(c), "pate": c})
	if rng.randf() < 0.55:
		var a: Vector2i = choisir.call(frontieres if frontieres.size() > 2 else candidats)
		if a.x >= 0:
			fiche["arenes"].append({"p": centre_pate(a), "id": indice_pate(a), "pate": a})
	var combien := 1 + (1 if rng.randf() < 0.6 else 0)
	for k in combien:
		var r: Vector2i = choisir.call(candidats)
		if r.x >= 0 and territoire_du_pate(r) >= 0:
			fiche["repaires"].append({"p": centre_pate(r), "gang": territoire_du_pate(r),
				"id": indice_pate(r), "pate": r})
	# L'HÔPITAL : un par secteur, jamais dans l'industrie ni au port. On y est
	# recousu contre argent — et c'est là qu'on rouvre les yeux quand on tombe.
	var h: Vector2i = choisir.call(candidats)
	if h.x >= 0:
		var coin_h := coin_pate(h)
		# Au CENTRE du pâté : la tuile que `_lieu_visitable` laisse en dalle.
		fiche["hopitaux"].append({"p": centre_tuile(coin_h.x + 1, coin_h.y + 1), "id": indice_pate(h), "pate": h})
	# La PLANQUE : la maison qu'on achète. Une par secteur, en périphérie du
	# pâté (on s'y gare devant), jamais dans le même pâté qu'un repaire.
	var pl: Vector2i = choisir.call(candidats)
	if pl.x >= 0:
		var coin_p := coin_pate(pl)
		fiche["planques"].append({"p": centre_tuile(coin_p.x, coin_p.y + 2), "id": indice_pate(pl), "pate": pl,
			"prix": PRIX_PLANQUE[posmod(indice_pate(pl), PRIX_PLANQUE.size())]})
	_secteurs[secteur] = fiche
	return fiche

func _secteur_de(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / (SECTEUR * PAS))), int(floor(point.y / (SECTEUR * PAS))))

## Tous les lieux à moins de `rayon` d'un point : on ne regarde que les
## secteurs que le cercle touche.
func lieux_autour(point: Vector2, rayon: float) -> Dictionary:
	var resultat := {"garages": [], "cabines": [], "arenes": [], "repaires": [], "hopitaux": [], "planques": []}
	var s0 := _secteur_de(point - Vector2(rayon, rayon))
	var s1 := _secteur_de(point + Vector2(rayon, rayon))
	for sy in range(max(0, s0.y), min(LIGNES / SECTEUR, s1.y + 1)):
		for sx in range(max(0, s0.x), min(COLONNES / SECTEUR, s1.x + 1)):
			var fiche := _lieux_du_secteur(Vector2i(sx, sy))
			for genre in resultat:
				for lieu in fiche[genre]:
					if Vector2(lieu["p"]).distance_to(point) <= rayon:
						resultat[genre].append(lieu)
	return resultat

func _lieu_du_pate(pate: Vector2i) -> String:
	var fiche := _lieux_du_secteur(Vector2i(pate.x * PERIODE / SECTEUR, pate.y * PERIODE / SECTEUR))
	for genre in ["arenes", "repaires", "garages", "cabines", "hopitaux", "planques"]:
		for lieu in fiche[genre]:
			if Vector2i(lieu["pate"]) == pate:
				return genre
	return ""

## Dans quelle arène se trouve ce point, ou -1. C'est cette réponse, et elle
## seule, qui autorise un joueur à en blesser un autre.
func arene_de(point: Vector2) -> int:
	return _lieu_de(point, "arenes", RAYON_ARENE)

func garage_de(point: Vector2) -> int:
	return _lieu_de(point, "garages", RAYON_GARAGE)

func hopital_de(point: Vector2) -> int:
	return _lieu_de(point, "hopitaux", RAYON_HOPITAL)

func planque_de(point: Vector2) -> int:
	return _lieu_de(point, "planques", RAYON_PLANQUE)

## La fiche complète d'une planque (son prix, sa position) par identifiant.
func planque_par_id(point_indicatif: Vector2, id: int) -> Dictionary:
	for pl in lieux_autour(point_indicatif, SECTEUR * PAS * 2.0)["planques"]:
		if int(pl["id"]) == id:
			return pl
	return {}

## L'hôpital ou la planque la plus proche : c'est là qu'on rouvre les yeux.
func hopital_le_plus_proche(point: Vector2) -> Dictionary:
	var meilleur := {}
	var distance := INF
	for h in lieux_autour(point, SECTEUR * PAS * 1.6)["hopitaux"]:
		var d: float = Vector2(h["p"]).distance_to(point)
		if d < distance:
			distance = d
			meilleur = h
	return meilleur

func cabine_de(point: Vector2) -> int:
	return _lieu_de(point, "cabines", RAYON_CABINE)

func _lieu_de(point: Vector2, genre: String, rayon: float) -> int:
	for lieu in lieux_autour(point, rayon)[genre]:
		return int(lieu["id"])
	return -1

func repaire_le_plus_proche(point: Vector2, gang: int) -> Dictionary:
	var meilleur := {}
	var distance := INF
	for r in lieux_autour(point, SECTEUR * PAS * 1.6)["repaires"]:
		if gang >= 0 and int(r["gang"]) != gang:
			continue
		var d: float = Vector2(r["p"]).distance_to(point)
		if d < distance:
			distance = d
			meilleur = r
	return meilleur

func garage_le_plus_proche(point: Vector2) -> Dictionary:
	var meilleur := {}
	var distance := INF
	for g in lieux_autour(point, SECTEUR * PAS * 1.6)["garages"]:
		var d: float = Vector2(g["p"]).distance_to(point)
		if d < distance:
			distance = d
			meilleur = g
	return meilleur

# ------------------------------------------------------------ les tuiles

## La fiche d'une tuile : son sol, ce qui y est bâti, son mobilier, ses
## voitures dormantes, et son rectangle de collision. Tout le rendu et toute la
## physique lisent ces fiches ; rien d'autre n'est jamais calculé.
func tuile(colonne: int, ligne: int) -> Dictionary:
	if colonne < 0 or ligne < 0 or colonne >= COLONNES or ligne >= LIGNES:
		return _mer(colonne, ligne)
	var pate := pate_de(colonne, ligne)
	var libre := voie_libre(colonne, ligne)
	if pate.x < 0 or eau(colonne, ligne) or sur_le_rail(colonne, ligne) or not libre.is_empty():
		var indice := ligne * COLONNES + colonne
		if not _rues.has(indice):
			if eau(colonne, ligne):
				_rues[indice] = _mer(colonne, ligne)
			elif sur_le_rail(colonne, ligne):
				_rues[indice] = _voie_ferree(colonne, ligne)
			elif not libre.is_empty():
				_rues[indice] = _boulevard(colonne, ligne, libre)
			else:
				_rues[indice] = _amenager_rue(colonne, ligne)
		return _rues[indice]
	var coin := coin_pate(pate)
	return _fiches_du_pate(pate)[(ligne - coin.y) * 3 + (colonne - coin.x)]

func _fiches_du_pate(pate: Vector2i) -> Array:
	if not _pates.has(pate):
		_pates[pate] = _amenager_pate(pate)
	return _pates[pate]

func _vierge(colonne: int, ligne: int, sol: int) -> Dictionary:
	return {"c": colonne, "l": ligne, "sol": sol, "rot": 0, "bloc": false, "rect": null, "rects": [],
		"batis": [], "props": [], "places": [], "teinte": Color.WHITE, "neons": [], "graine": 0.0}

## Une tuile de voie ferrée : du ballast, les rails tracés par le shader en
## espace monde. Rien n'y est bâti, on la traverse — les passages à niveau
## sont partout.
func _voie_ferree(colonne: int, ligne: int) -> Dictionary:
	var fiche := _vierge(colonne, ligne, S_RAIL)
	var pate := _pate_proche_de(colonne, ligne)
	fiche["teinte"] = _teinte_territoire(territoire_du_pate(pate), 0.1)
	return fiche

## Une tuile de boulevard ou de place. Le shader dessine la chaussée d'après
## la géométrie de la voie ; ici on ne pose que le mobilier des trottoirs —
## lampadaires et arbres en quinconce sur la bande extérieure, comme sur les
## avenues de la grille — et l'îlot de la place, avec son monument.
func _boulevard(colonne: int, ligne: int, libre: Dictionary) -> Dictionary:
	var genre := String(libre["genre"])
	var place := genre == "place"
	var fiche := _vierge(colonne, ligne, S_PLACE if place else (S_ESPLANADE if genre == "esplanade" else S_BOULEVARD))
	var pate := _pate_proche_de(colonne, ligne)
	fiche["teinte"] = _teinte_territoire(territoire_du_pate(pate), 0.10)
	fiche["graine"] = 0.75
	var centre_px := centre_tuile(colonne, ligne)
	if _dans_la_riviere(colonne, ligne):
		fiche["pont"] = true
	if genre == "esplanade":
		# Le parvis : des pavés, des arbres en quinconce, des bancs, des lampes.
		var t := _bruit(colonne, ligne, 335)
		var ou: Vector2 = centre_px + Vector2((_bruit(colonne, ligne, 336) - 0.5) * 30.0, (_bruit(colonne, ligne, 337) - 0.5) * 30.0)
		if t < 0.30:
			_prop(fiche, "arbre" if t < 0.12 else "arbre_petit", ou, 0.0, 0.9)
			_bloquer(fiche, Rect2(ou - Vector2(8, 8), Vector2(16, 16)))
		elif t < 0.42:
			_prop(fiche, "banc", ou, PI * 0.5 * float(_entier(colonne, ligne, 338, 4)))
		elif t < 0.50:
			_prop(fiche, "lampadaire_parc", ou)
		elif t < 0.56:
			_prop(fiche, "fontaine", centre_px)
			_bloquer(fiche, Rect2(centre_px - Vector2(22, 22), Vector2(44, 44)))
		return fiche
	if place:
		var r: float = libre["r"]
		var centre_place: Vector2 = libre["c"]
		var rayon_place: float = _etoiles[int(libre["e"])]["r"]
		var ilot: float = _etoiles[int(libre["e"])]["ilot"]
		if r < ilot:
			# L'îlot : une dalle qu'on ne traverse pas, un monument au milieu —
			# l'obélisque sur la grande place, une fontaine sur les autres — et
			# des arbres autour.
			_bloquer(fiche, Rect2(centre_px - Vector2(PAS, PAS) * 0.5, Vector2(PAS, PAS)))
			if r < 0.5:
				_prop(fiche, "monument" if int(libre["e"]) == 0 else "fontaine", centre_place * PAS)
			elif r > ilot - 0.8 and _bruit(colonne, ligne, 339) < 0.55:
				_prop(fiche, "arbre_petit", centre_px, 0.0, 0.9)
		elif r > rayon_place - TROTTOIR_BOULEVARD - 0.3 and _bruit(colonne, ligne, 330) < 0.5:
			var radial := (Vector2(float(colonne) + 0.5, float(ligne) + 0.5) - centre_place).normalized()
			_prop(fiche, "lampadaire", (centre_place + radial * (rayon_place - TROTTOIR_BOULEVARD * 0.5)) * PAS, radial.angle() + PI)
		return fiche
	# Le bord : la cellule de trottoir la plus extérieure de la tuile.
	var s: float = libre["s"]
	var bord := LARGEUR_BOULEVARD * 0.5 - TROTTOIR_BOULEVARD * 0.5
	if abs(s) > bord - 0.5 and not fiche.has("pont"):
		var d: Vector2 = libre["d"]
		var n := Vector2(-d.y, d.x) * signf(s)
		var sur_trottoir: Vector2 = centre_px + n * (bord - abs(s)) * PAS
		var t := _bruit(colonne, ligne, 331)
		if t < 0.28:
			_prop(fiche, "lampadaire", sur_trottoir, n.angle())
		elif t < 0.62:
			_prop(fiche, "arbre_petit", sur_trottoir, 0.0, 0.9)
		elif t < 0.70:
			_prop(fiche, "banc", sur_trottoir, n.angle() + PI * 0.5)
	return fiche

func _mer(colonne: int, ligne: int) -> Dictionary:
	var fiche := _vierge(colonne, ligne, S_EAU)
	fiche["bloc"] = true
	fiche["rect"] = Rect2(Vector2(colonne, ligne) * PAS, Vector2(PAS, PAS))
	return fiche

func _teinte_territoire(gang: int, force: float) -> Color:
	if gang < 0:
		return Color.WHITE
	return Color.WHITE.lerp(GANGS[gang]["couleur"], force)

## Un accessoire posé : un modèle du kit, une position en pixels, un angle et
## une échelle. Le morceau les regroupe par modèle en nappes.
func _prop(fiche: Dictionary, modele: String, p: Vector2, angle: float = 0.0, echelle: float = 1.0) -> void:
	fiche["props"].append({"m": modele, "p": p, "a": angle, "s": echelle})

## Un volume bâti : centre en pixels, emprise en pixels, hauteur en unités 3D,
## style de façade et teinte. `bloque` à faux pour un auvent qu'on traverse.
func _bati(fiche: Dictionary, p: Vector2, largeur: float, profondeur: float, hauteur: float,
		style: int, couleur: Color, bloque: bool = true, base: float = 0.0) -> void:
	fiche["batis"].append({"p": p, "w": largeur, "d": profondeur, "h": hauteur, "y": base,
		"style": style, "c": couleur})
	if bloque:
		_bloquer(fiche, Rect2(p - Vector2(largeur, profondeur) * 0.5, Vector2(largeur, profondeur)))

## Bloque un rectangle de la tuile. ⚠ On garde CHAQUE rectangle (`rects`) :
## l'ancienne union en un seul rectangle par tuile faisait, d'un arbre et d'un
## banc aux deux coins d'une cour, un mur invisible sur toute la tuile — les
## « hitbox mal faites ». `rect` (l'union) ne sert plus qu'à la peinture.
func _bloquer(fiche: Dictionary, rect: Rect2) -> void:
	fiche["bloc"] = true
	(fiche["rects"] as Array).append(rect)
	if fiche["rect"] == null:
		fiche["rect"] = rect
	else:
		fiche["rect"] = (fiche["rect"] as Rect2).merge(rect)

func _teinte_de(style: int, a: int, b: int, sel: int) -> Color:
	var liste: Array = TEINTES[style]
	var base: Color = liste[_entier(a, b, sel, liste.size())]
	# Une pointe de variation : deux immeubles voisins du même style ne sont
	# jamais exactement de la même couleur, sinon la rue se lit comme un motif.
	return base.lightened((_bruit(a, b, sel + 100) - 0.5) * 0.12)

# ------------------------------------------------------------ les rues

func _amenager_rue(colonne: int, ligne: int) -> Dictionary:
	var vc := est_voie(colonne)
	var vl := est_voie(ligne)
	var pate := _pate_proche_de(colonne, ligne)
	var gang := territoire_du_pate(pate)
	var quartier := quartier_du_pate(pate)
	var fiche := _vierge(colonne, ligne, S_ROUTE)
	# Au milieu d'un plan d'eau, pas de rue : une grille de chaussées posée sur
	# un lac se lit comme un défaut de génération, pas comme des ponts. La rue
	# s'arrête au rivage — les voitures aussi.
	if _dans_l_eau(colonne, ligne, vc, vl):
		return _mer(colonne, ligne)
	# La rue prend une pointe de la couleur du territoire qu'elle traverse :
	# pas assez pour changer le bitume, assez pour lire la frontière au sol.
	fiche["teinte"] = _teinte_territoire(gang, 0.12)
	var dense := quartier in [CENTRE, AFFAIRES, COMMERCE, VIEUX]
	var pc := posmod(colonne, PERIODE)
	var pl := posmod(ligne, PERIODE)
	var centre_px := centre_tuile(colonne, ligne)
	var k := colonne / PERIODE
	var kl := ligne / PERIODE

	# Un pont : de la chaussée au-dessus de l'eau, un lampadaire, rien d'autre.
	if _dans_la_riviere(colonne, ligne):
		fiche["rot"] = 0 if pc == 0 else 2
		fiche["pont"] = true
		fiche["graine"] = 0.75
		if pl == 3:
			_prop(fiche, "lampadaire", centre_px + Vector2(-1.0 if pc == 0 else 1.0, 0.0) * (PAS * 0.5 - TROTTOIR * 0.5),
				0.0 if pc == 1 else PI)
		return fiche

	# Une rue fermée : les deux pâtés n'en font qu'un. Dans un quartier dense,
	# on bâtit dessus (les immeubles se rejoignent) ; ailleurs c'est leur cour.
	var fermee := (vc and not vl and rue_fermee_v(k, kl)) or (vl and not vc and rue_fermee_h(kl, k)) \
		or (vc and vl and rue_fermee_v(k, kl - 1) and rue_fermee_v(k, kl) and rue_fermee_h(kl, k - 1) and rue_fermee_h(kl, k))
	if fermee:
		if quartier in QUARTIERS_BATIS and not _dans_la_riviere(colonne, ligne):
			return _rue_batie(fiche, centre_px, quartier, gang, pate, colonne, ligne)
		return _cour(fiche, centre_px, quartier, gang, colonne, ligne)

	# Une avenue : le shader lit la graine ≥ 0,5 et trace la double ligne.
	if est_avenue(colonne) != est_avenue(ligne):
		fiche["graine"] = 0.75

	if vc and vl:
		fiche["sol"] = S_CARREFOUR
		# Le quart de trottoir est à l'angle EXTÉRIEUR du carrefour ; la
		# rotation le tourne vers le pâté voisin.
		var coin := Vector2(-1, -1)
		if pc == 0 and pl == 0: fiche["rot"] = 0
		elif pc == 1 and pl == 0: fiche["rot"] = 1; coin = Vector2(1, -1)
		elif pc == 1 and pl == 1: fiche["rot"] = 2; coin = Vector2(1, 1)
		else: fiche["rot"] = 3; coin = Vector2(-1, 1)
		if dense and _bruit(colonne, ligne, 21) < 0.7:
			_prop(fiche, "feu", centre_px + coin * (PAS * 0.5 - 12.0), coin.angle() + PI * 0.75)
		return fiche

	if vc:
		# Rue verticale : la tuile ouest a son trottoir à l'ouest, la tuile est
		# à l'est. Le passage piéton est au bout qui touche le carrefour.
		var ouest := pc == 0
		fiche["rot"] = 0 if ouest else 2
		if pl == 2:
			fiche["sol"] = S_PASSAGE_A if ouest else S_PASSAGE_B
		elif pl == 4:
			fiche["sol"] = S_PASSAGE_B if ouest else S_PASSAGE_A
		var bord := Vector2(-1.0 if ouest else 1.0, 0.0)
		_mobilier_de_trottoir(fiche, centre_px, bord, Vector2(0, 1), pl, quartier, colonne, ligne)
		return fiche

	var nord := pl == 0
	fiche["rot"] = 1 if nord else 3
	if pc == 2:
		fiche["sol"] = S_PASSAGE_B if nord else S_PASSAGE_A
	elif pc == 4:
		fiche["sol"] = S_PASSAGE_A if nord else S_PASSAGE_B
	var bord_h := Vector2(0.0, -1.0 if nord else 1.0)
	_mobilier_de_trottoir(fiche, centre_px, bord_h, Vector2(1, 0), pc, quartier, colonne, ligne)
	return fiche

## La cour d'un îlot fondu : ce qu'il y a à la place d'une rue fermée. Elle se
## traverse (à pied, en voiture), c'est un raccourci — et ce qui la meuble
## dit le quartier autant que les façades.
## Une rue fermée BÂTIE : un immeuble d'une tuile, du style et de la hauteur
## des pâtés qu'il relie, avec le même retrait qu'eux — de haut, le bloc n'est
## plus qu'un seul long pâté. Une tuile sur six reste une cour intérieure.
func _rue_batie(fiche: Dictionary, c: Vector2, quartier: int, gang: int, pate: Vector2i, colonne: int, ligne: int) -> Dictionary:
	var sel := 320
	if _bruit(colonne, ligne, 321) < 0.16:
		return _cour(fiche, c, quartier, gang, colonne, ligne)
	var style := F_LOGEMENTS
	match quartier:
		COMMERCE, CENTRE: style = F_COMMERCE
		AFFAIRES: style = F_BUREAUX
		VIEUX: style = F_VIEUX
	fiche["sol"] = S_PAVES
	fiche["teinte"] = _teinte_territoire(gang, 0.16)
	var basse := 7.0 if quartier in [CENTRE, AFFAIRES, COMMERCE] else 5.5
	var hauteur := _hauteur(pate, sel + posmod(colonne + ligne, 3), basse, basse + 5.0)
	var cote := PAS - 2.0 * RETRAIT
	_bati(fiche, c, cote, cote, hauteur, style, _teinte_de(style, colonne, ligne, sel))
	return fiche

func _cour(fiche: Dictionary, c: Vector2, quartier: int, gang: int, colonne: int, ligne: int) -> Dictionary:
	fiche["teinte"] = _teinte_territoire(gang, 0.16)
	var t := _bruit(colonne, ligne, 310)
	var ou := c + Vector2((_bruit(colonne, ligne, 311) - 0.5) * 40.0, (_bruit(colonne, ligne, 312) - 0.5) * 40.0)
	match quartier:
		PARC, BANLIEUE, RESIDENCES:
			fiche["sol"] = S_HERBE
			if t < 0.45:
				_prop(fiche, "arbre" if t < 0.25 else "arbre_petit", ou, 0.0, lerpf(0.9, 1.2, _bruit(colonne, ligne, 313)))
				_bloquer(fiche, Rect2(ou - Vector2(12, 12), Vector2(24, 24)))
			elif t < 0.7:
				_prop(fiche, "buisson", ou, 0.0, lerpf(0.8, 1.3, _bruit(colonne, ligne, 313)))
			elif t < 0.8 and quartier != PARC:
				_prop(fiche, "banc", ou, PI * 0.5 * float(_entier(colonne, ligne, 314, 4)))
		INDUSTRIE, PORT:
			fiche["sol"] = S_BETON
			if t < 0.3:
				_prop(fiche, "conteneur_a" if t < 0.15 else "conteneur_b", ou, PI * 0.5 * float(_entier(colonne, ligne, 314, 2)))
				_bloquer(fiche, Rect2(ou - Vector2(30, 16), Vector2(60, 32)))
			elif t < 0.4:
				_prop(fiche, "benne", ou, _bruit(colonne, ligne, 315) * 0.6)
			elif t < 0.5:
				_prop(fiche, "lampadaire_parc", ou)
		_:
			fiche["sol"] = S_PAVES
			if t < 0.2:
				_prop(fiche, "arbre_petit", ou, 0.0, 0.9)
				_bloquer(fiche, Rect2(ou - Vector2(10, 10), Vector2(20, 20)))
			elif t < 0.45:
				_prop(fiche, "banc", ou, PI * 0.5 * float(_entier(colonne, ligne, 314, 4)))
			elif t < 0.6:
				_prop(fiche, "lampadaire_parc", ou)
			elif t < 0.7 and quartier == COMMERCE:
				_prop(fiche, "benne", ou, 0.3)
	return fiche

## Ce qui vit sur un trottoir : un lampadaire au milieu de chaque façade de
## pâté, et selon le quartier, une bouche d'incendie, une poubelle, un banc, un
## arbre. Les lampadaires sont ce qui fait la nuit : sans leurs flaques de
## lumière, une rue au crépuscule n'est qu'un ruban gris.
func _mobilier_de_trottoir(fiche: Dictionary, centre_px: Vector2, bord: Vector2, le_long: Vector2,
		rang: int, quartier: int, colonne: int, ligne: int) -> void:
	var sur_trottoir: Vector2 = centre_px + bord * (PAS * 0.5 - TROTTOIR * 0.5)
	var face := bord.angle()
	if rang == 3:
		_prop(fiche, "lampadaire", sur_trottoir, face)
		return
	# Une avenue est arborée : un arbre au milieu de chaque demi-façade, des
	# deux côtés. C'est ce qui la distingue d'une rue au premier coup d'œil.
	if fiche.get("graine", 0.0) >= 0.5 and (rang == 2 or rang == 4):
		_prop(fiche, "arbre_petit", sur_trottoir, 0.0, 0.85)
		return
	var t := _bruit(colonne, ligne, 22)
	var decale: Vector2 = sur_trottoir + le_long * (_bruit(colonne, ligne, 23) - 0.5) * 50.0
	match quartier:
		CENTRE, AFFAIRES:
			if t < 0.14: _prop(fiche, "borne", decale)
			elif t < 0.26: _prop(fiche, "poubelle", decale)
			elif t < 0.40: _prop(fiche, "arbre_petit", decale, 0.0, 0.8)
		COMMERCE, VIEUX:
			if t < 0.12: _prop(fiche, "borne", decale)
			elif t < 0.30: _prop(fiche, "poubelle", decale)
			elif t < 0.42: _prop(fiche, "banc", decale, face + PI * 0.5)
		RESIDENCES, BANLIEUE, PARC:
			if t < 0.34: _prop(fiche, "arbre_petit" if t < 0.2 else "arbre", decale, 0.0, 0.85)
			elif t < 0.44: _prop(fiche, "banc", decale, face + PI * 0.5)
			elif t < 0.50: _prop(fiche, "borne", decale)
		INDUSTRIE, PORT:
			if t < 0.10: _prop(fiche, "borne", decale)
			elif t < 0.18: _prop(fiche, "poubelle", decale)

## Une tuile de rue est noyée si tous les pâtés qu'elle borde sont de l'eau.
func _dans_l_eau(colonne: int, ligne: int, vc: bool, vl: bool) -> bool:
	var px := colonne / PERIODE
	var py := ligne / PERIODE
	var autour: Array = []
	if vc and vl:
		autour = [Vector2i(px - 1, py - 1), Vector2i(px, py - 1), Vector2i(px - 1, py), Vector2i(px, py)]
	elif vc:
		autour = [Vector2i(px - 1, py), Vector2i(px, py)]
	else:
		autour = [Vector2i(px, py - 1), Vector2i(px, py)]
	for pate in autour:
		if quartier_du_pate(pate) != EAU:
			return false
	return true

func _pate_proche_de(colonne: int, ligne: int) -> Vector2i:
	var pate := pate_de(colonne, ligne)
	if pate.x >= 0:
		return pate
	# Sur une rue : le pâté au sud-est (les deux tuiles de rue 5k et 5k+1
	# précèdent le pâté k). Arbitraire, mais identique chez tout le monde —
	# c'est tout ce qu'on demande d'une rue frontière.
	var px: int = clamp(colonne / PERIODE, 0, pates_x() - 1)
	var py: int = clamp(ligne / PERIODE, 0, pates_y() - 1)
	return Vector2i(px, py)

# ------------------------------------------------------------ les pâtés

func _amenager_pate(pate: Vector2i) -> Array:
	var coin := coin_pate(pate)
	var quartier := quartier_du_pate(pate)
	var gang := territoire_du_pate(pate)
	var fiches: Array = []
	var sol_de_base := S_TROTTOIR
	match quartier:
		CENTRE, AFFAIRES: sol_de_base = S_PAVES
		VIEUX: sol_de_base = S_PAVES
		RESIDENCES, BANLIEUE, PARC: sol_de_base = S_HERBE
		INDUSTRIE, PORT: sol_de_base = S_BETON
		EAU: sol_de_base = S_EAU
	for j in 3:
		for i in 3:
			var fiche := _vierge(coin.x + i, coin.y + j, sol_de_base)
			fiche["teinte"] = _teinte_territoire(gang, 0.16)
			fiches.append(fiche)

	if quartier == EAU:
		for fiche in fiches:
			_bloquer(fiche, Rect2(Vector2(fiche["c"], fiche["l"]) * PAS, Vector2(PAS, PAS)))
		return fiches

	# Un pâté que l'eau touche (rivière, côte) devient un quai : de la dalle, des
	# bancs, des lampadaires, et des immeubles d'une seule tuile pour ne jamais
	# poser une tour à cheval sur l'eau.
	var au_bord_de_l_eau := false
	for j in 3:
		for i in 3:
			if eau(coin.x + i, coin.y + j) or sur_le_rail(coin.x + i, coin.y + j):
				au_bord_de_l_eau = true
	if au_bord_de_l_eau:
		_rive(fiches, pate, quartier, gang)
		_garer(fiches, pate, quartier, gang, false)
		return fiches

	# Un pâté qu'un boulevard traverse : des immeubles d'une seule tuile, un
	# peu plus hauts que la moyenne — c'est la façade sur boulevard — et rien
	# sur les tuiles que la voie emprunte (elles sont réécrites par `tuile`).
	if _coupe(pate):
		_bordure(fiches, pate, quartier, gang)
		_garer(fiches, pate, quartier, gang, false)
		return fiches

	var lieu := _lieu_du_pate(pate)
	match lieu:
		"arenes":
			_esplanade(fiches, pate)
		"repaires":
			_repaire(fiches, pate, quartier, gang)
		"garages", "cabines":
			_simple(fiches, pate, quartier, gang, lieu == "garages")
		"hopitaux", "planques":
			# Le pâté d'un lieu qu'on VISITE se bâtit en petit, et sa tuile
			# centrale (hôpital) ou son coin (planque) reste dégagé : sinon le
			# bâti se pose dessus et on ne voit plus ni la croix ni la porte.
			_lieu_visitable(fiches, pate, quartier, gang, lieu)
		_:
			match quartier:
				CENTRE: _centre(fiches, pate)
				AFFAIRES: _affaires(fiches, pate)
				COMMERCE: _commerce(fiches, pate)
				VIEUX: _vieux(fiches, pate)
				RESIDENCES: _residences(fiches, pate)
				BANLIEUE: _banlieue(fiches, pate)
				INDUSTRIE: _industrie(fiches, pate, false)
				PORT: _industrie(fiches, pate, true)
				PARC: _parc(fiches, pate)

	# Les voitures dormantes le long des rues, sauf sur une esplanade d'arène.
	if lieu != "arenes":
		_garer(fiches, pate, quartier, gang, lieu == "repaires")
	return fiches

func _f(fiches: Array, i: int, j: int) -> Dictionary:
	return fiches[j * 3 + i]

func _centre_de(fiches: Array, i: int, j: int) -> Vector2:
	var fiche: Dictionary = _f(fiches, i, j)
	return centre_tuile(int(fiche["c"]), int(fiche["l"]))

## Un immeuble sur une emprise de `w`×`d` tuiles ancrée en (i, j). Toutes les
## tuiles couvertes reçoivent le même rectangle : `degager` retrouve ainsi le
## mur complet depuis n'importe laquelle.
func _immeuble(fiches: Array, i: int, j: int, w: int, d: int, hauteur: float, style: int,
		pate: Vector2i, sel: int, retrait: float = RETRAIT, plein: float = 1.0) -> Dictionary:
	var coin_px := _centre_de(fiches, i, j) - Vector2(PAS, PAS) * 0.5
	var taille := Vector2(w, d) * PAS
	var emprise := Rect2(coin_px + Vector2(retrait, retrait), taille - Vector2(retrait, retrait) * 2.0)
	if plein < 1.0:
		var reduit := emprise.size * plein
		emprise = Rect2(emprise.get_center() - reduit * 0.5, reduit)
	var couleur := _teinte_de(style, pate.x * 3 + i, pate.y * 3 + j, sel)
	var ancre: Dictionary = _f(fiches, i, j)
	_bati(ancre, emprise.get_center(), emprise.size.x, emprise.size.y, hauteur, style, couleur)
	for jj in range(j, j + d):
		for ii in range(i, i + w):
			if ii == i and jj == j:
				continue
			_bloquer(_f(fiches, ii, jj), emprise)
	return ancre["batis"][-1]

func _hauteur(pate: Vector2i, sel: int, basse: float, haute: float) -> float:
	return lerpf(basse, haute, _bruit(pate.x, pate.y, sel))

## Une enseigne au néon sur la façade tournée vers la rue. `cote` : le bord de
## la tuile qui donne sur la rue.
func _neon(fiches: Array, i: int, j: int, bati: Dictionary, pate: Vector2i, sel: int) -> void:
	var cotes: Array = []
	if i == 0: cotes.append(Vector2(-1, 0))
	if i == 2: cotes.append(Vector2(1, 0))
	if j == 0: cotes.append(Vector2(0, -1))
	if j == 2: cotes.append(Vector2(0, 1))
	if cotes.is_empty():
		return
	var cote: Vector2 = cotes[_entier(pate.x * 3 + i, pate.y * 3 + j, sel, cotes.size())]
	var p: Vector2 = bati["p"] + cote * (Vector2(bati["w"], bati["d"]) * 0.5 + Vector2(1.0, 1.0)).abs()
	var couleur: Color = _parmi(NEONS, pate.x * 3 + i, pate.y * 3 + j, sel + 1)
	var largeur: float = (float(bati["d"]) if cote.x != 0.0 else float(bati["w"])) * lerpf(0.35, 0.7, _bruit(i, j, sel + 2))
	_f(fiches, i, j)["neons"].append({"p": p, "n": cote, "w": largeur, "h": 0.9,
		"y": lerpf(3.6, 5.2, _bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 3)), "c": couleur})

# --- les gabarits de pâté

func _centre(fiches: Array, pate: Vector2i) -> void:
	var t := _bruit(pate.x, pate.y, 30)
	if t < 0.45:
		_immeuble(fiches, 0, 0, 2, 2, _hauteur(pate, 31, 18.0, 30.0), F_TOUR, pate, 31)
		_immeuble(fiches, 2, 0, 1, 1, _hauteur(pate, 32, 10.0, 16.0), F_BUREAUX, pate, 32)
		_immeuble(fiches, 2, 1, 1, 1, _hauteur(pate, 33, 9.0, 14.0), F_BUREAUX, pate, 33)
		_immeuble(fiches, 0, 2, 1, 1, _hauteur(pate, 34, 9.0, 14.0), F_BUREAUX, pate, 34)
		_immeuble(fiches, 1, 2, 1, 1, _hauteur(pate, 35, 8.0, 14.0), F_COMMERCE, pate, 35)
		_place(fiches, 2, 2, pate, 36)
	elif t < 0.75:
		var tour := _immeuble(fiches, 1, 1, 1, 1, _hauteur(pate, 37, 24.0, 34.0), F_TOUR, pate, 37, RETRAIT, 0.86)
		tour["chapeau"] = true
		for j in 3:
			for i in 3:
				if i == 1 and j == 1:
					continue
				_place(fiches, i, j, pate, 38 + j * 3 + i)
	else:
		_immeuble(fiches, 0, 0, 1, 2, _hauteur(pate, 47, 14.0, 22.0), F_BUREAUX, pate, 47)
		_immeuble(fiches, 2, 0, 1, 2, _hauteur(pate, 48, 12.0, 18.0), F_BUREAUX, pate, 48)
		_place(fiches, 1, 0, pate, 49)
		_place(fiches, 1, 1, pate, 50)
		for i in 3:
			var b := _immeuble(fiches, i, 2, 1, 1, _hauteur(pate, 51 + i, 6.0, 9.0), F_COMMERCE, pate, 51 + i)
			_neon(fiches, i, 2, b, pate, 60 + i)

## Une place : dallage, et selon le tirage une fontaine, des arbres ou des bancs.
func _place(fiches: Array, i: int, j: int, pate: Vector2i, sel: int) -> void:
	var fiche: Dictionary = _f(fiches, i, j)
	fiche["sol"] = S_PAVES
	var c := _centre_de(fiches, i, j)
	var t := _bruit(pate.x * 3 + i, pate.y * 3 + j, sel)
	if t < 0.25:
		_prop(fiche, "fontaine", c)
		_bloquer(fiche, Rect2(c - Vector2(30, 30), Vector2(60, 60)))
	elif t < 0.6:
		_prop(fiche, "arbre", c + Vector2(-22, -18), 0.0, 0.9)
		_prop(fiche, "arbre_petit", c + Vector2(24, 20), 0.0, 0.9)
		_prop(fiche, "banc", c + Vector2(20, -24), PI * 0.5)
	else:
		_prop(fiche, "banc", c + Vector2(-24, 0), 0.0)
		_prop(fiche, "banc", c + Vector2(24, 0), PI)
		_prop(fiche, "lampadaire_parc", c + Vector2(0, -30))

func _affaires(fiches: Array, pate: Vector2i) -> void:
	if _bruit(pate.x, pate.y, 70) < 0.5:
		_immeuble(fiches, 0, 0, 2, 1, _hauteur(pate, 71, 10.0, 18.0), F_BUREAUX, pate, 71)
		_immeuble(fiches, 2, 0, 1, 1, _hauteur(pate, 72, 8.0, 14.0), F_BUREAUX, pate, 72)
		_parking(fiches, 0, 1, pate, 73)
		_immeuble(fiches, 1, 1, 2, 1, _hauteur(pate, 74, 9.0, 15.0), F_BUREAUX, pate, 74)
		if _bruit(pate.x, pate.y, 75) < 0.4:
			_immeuble(fiches, 0, 2, 2, 1, _hauteur(pate, 76, 10.0, 18.0), F_BUREAUX, pate, 76)
			_immeuble(fiches, 2, 2, 1, 1, _hauteur(pate, 77, 8.0, 12.0), F_COMMERCE, pate, 77)
		else:
			for i in 3:
				_immeuble(fiches, i, 2, 1, 1, _hauteur(pate, 78 + i, 8.0, 16.0), F_BUREAUX, pate, 78 + i)
	else:
		_immeuble(fiches, 1, 1, 2, 2, _hauteur(pate, 81, 14.0, 24.0), F_TOUR, pate, 81)
		_immeuble(fiches, 0, 0, 1, 1, _hauteur(pate, 82, 8.0, 14.0), F_BUREAUX, pate, 82)
		_immeuble(fiches, 0, 1, 1, 1, _hauteur(pate, 83, 8.0, 14.0), F_BUREAUX, pate, 83)
		_immeuble(fiches, 0, 2, 1, 1, _hauteur(pate, 84, 6.0, 10.0), F_COMMERCE, pate, 84)
		_place(fiches, 1, 0, pate, 85)
		_place(fiches, 2, 0, pate, 86)

## Un parking : des places au sol et deux voitures qui dorment.
func _parking(fiches: Array, i: int, j: int, pate: Vector2i, sel: int) -> void:
	var fiche: Dictionary = _f(fiches, i, j)
	fiche["sol"] = S_PARKING
	var c := _centre_de(fiches, i, j)
	for k in 2:
		if _bruit(pate.x * 3 + i, pate.y * 3 + j, sel + k) < 0.62:
			fiche["places"].append({"p": c + Vector2(-22.0 + 44.0 * float(k), 0.0), "a": PI * 0.5,
				"cote": 4 + k})

func _commerce(fiches: Array, pate: Vector2i) -> void:
	for j in 3:
		for i in 3:
			if i == 1 and j == 1:
				# L'arrière-cour : du béton, des bennes. Une rue commerçante a
				# un envers, c'est ce qui la rend crédible.
				var cour: Dictionary = _f(fiches, 1, 1)
				cour["sol"] = S_BETON
				var c := _centre_de(fiches, 1, 1)
				_prop(cour, "benne", c + Vector2(-20, -18), 0.3)
				_prop(cour, "benne", c + Vector2(18, 14), -0.2)
				_prop(cour, "poubelle", c + Vector2(28, -22))
				continue
			var sel := 90 + j * 3 + i
			var haut := _bruit(pate.x * 3 + i, pate.y * 3 + j, sel) < 0.3
			var b := _immeuble(fiches, i, j, 1, 1, _hauteur(pate, sel, 10.0, 15.0) if haut else _hauteur(pate, sel, 5.0, 9.0),
				F_COMMERCE, pate, sel, RETRAIT_MIN + 1.0)
			if _bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 20) < 0.6:
				_neon(fiches, i, j, b, pate, sel + 40)

func _vieux(fiches: Array, pate: Vector2i) -> void:
	for j in 3:
		for i in 3:
			if i == 1 and j == 1:
				var cour: Dictionary = _f(fiches, 1, 1)
				cour["sol"] = S_PAVES
				var c := _centre_de(fiches, 1, 1)
				_prop(cour, "arbre", c, 0.0, 0.95)
				_bloquer(cour, Rect2(c - Vector2(14, 14), Vector2(28, 28)))
				_prop(cour, "banc", c + Vector2(0, 30), 0.0)
				continue
			var sel := 120 + j * 3 + i
			var clocher := _bruit(pate.x * 3 + i, pate.y * 3 + j, sel) < 0.08
			var b := _immeuble(fiches, i, j, 1, 1, 10.0 if clocher else _hauteur(pate, sel, 4.2, 7.0),
				F_VIEUX, pate, sel, RETRAIT_MIN)
			if not clocher and _bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 30) < 0.25:
				_neon(fiches, i, j, b, pate, sel + 50)

func _residences(fiches: Array, pate: Vector2i) -> void:
	if _bruit(pate.x, pate.y, 140) < 0.7:
		_immeuble(fiches, 0, 0, 3, 1, _hauteur(pate, 141, 9.0, 15.0), F_LOGEMENTS, pate, 141)
		_immeuble(fiches, 0, 2, 3, 1, _hauteur(pate, 142, 9.0, 15.0), F_LOGEMENTS, pate, 142)
		_parking(fiches, 0, 1, pate, 143)
		_jardin(fiches, 1, 1, pate, 144)
		_jardin(fiches, 2, 1, pate, 145)
	else:
		_immeuble(fiches, 0, 0, 1, 3, _hauteur(pate, 146, 10.0, 16.0), F_LOGEMENTS, pate, 146)
		_immeuble(fiches, 2, 0, 1, 3, _hauteur(pate, 147, 10.0, 16.0), F_LOGEMENTS, pate, 147)
		_jardin(fiches, 1, 0, pate, 148)
		_parking(fiches, 1, 1, pate, 149)
		_jardin(fiches, 1, 2, pate, 150)

## Un coin d'herbe : un arbre (qui bloque, un tronc n'est pas une pelouse), des
## buissons, parfois un banc.
func _jardin(fiches: Array, i: int, j: int, pate: Vector2i, sel: int) -> void:
	var fiche: Dictionary = _f(fiches, i, j)
	fiche["sol"] = S_HERBE
	var c := _centre_de(fiches, i, j)
	var t := _bruit(pate.x * 3 + i, pate.y * 3 + j, sel)
	if t < 0.7:
		var ou := c + Vector2((_bruit(i, j, sel + 1) - 0.5) * 30.0, (_bruit(i, j, sel + 2) - 0.5) * 30.0)
		_prop(fiche, "arbre" if t < 0.4 else "arbre_petit", ou, 0.0, lerpf(0.85, 1.1, _bruit(i, j, sel + 3)))
		_bloquer(fiche, Rect2(ou - Vector2(12, 12), Vector2(24, 24)))
	_prop(fiche, "buisson", c + Vector2(-32, 26), 0.0, lerpf(0.8, 1.2, _bruit(i, j, sel + 4)))
	_prop(fiche, "buisson", c + Vector2(30, -28), 0.0, lerpf(0.8, 1.2, _bruit(i, j, sel + 5)))
	if t > 0.5:
		_prop(fiche, "banc", c + Vector2(28, 24), PI)

func _banlieue(fiches: Array, pate: Vector2i) -> void:
	for j in 3:
		for i in 3:
			var sel := 160 + j * 3 + i
			var fiche: Dictionary = _f(fiches, i, j)
			var c := _centre_de(fiches, i, j)
			if i == 1 and j == 1 and _bruit(pate.x, pate.y, 159) < 0.5:
				_jardin(fiches, 1, 1, pate, sel)
				continue
			# La maison n'est pas au milieu de sa parcelle : elle est du côté
			# de la rue, et le jardin derrière — comme partout.
			var vers_rue := Vector2(-1 if i == 0 else (1 if i == 2 else 0), -1 if j == 0 else (1 if j == 2 else 0))
			var ou := c + vers_rue * 12.0 + Vector2((_bruit(pate.x * 3 + i, pate.y * 3 + j, sel) - 0.5) * 16.0,
				(_bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 1) - 0.5) * 16.0)
			var w: float = lerp(48.0, 60.0, _bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 2))
			var d: float = lerp(42.0, 54.0, _bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 3))
			var h := _hauteur(pate, sel + 4, 3.2, 4.4)
			var couleur := _teinte_de(F_MAISON, pate.x * 3 + i, pate.y * 3 + j, sel)
			_bati(fiche, ou, w, d, h, F_MAISON, couleur)
			# Le toit : une dalle sombre qui déborde. C'est ce qui fait
			# « maison » vu de dessus, là où une boîte fait « garage ».
			_bati(fiche, ou, w + 6.0, d + 6.0, 0.5, F_PLEIN, _parmi(TOITS, pate.x * 3 + i, pate.y * 3 + j, sel + 5), false, h)
			var jardin: Vector2 = c - vers_rue * 30.0
			_prop(fiche, "buisson", jardin + Vector2(-18, 10), 0.0, 1.0)
			if _bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 6) < 0.5:
				_prop(fiche, "arbre_petit", jardin + Vector2(14, -8), 0.0, 0.9)
				_bloquer(fiche, Rect2(jardin + Vector2(14, -8) - Vector2(10, 10), Vector2(20, 20)))

func _industrie(fiches: Array, pate: Vector2i, port: bool) -> void:
	var t := _bruit(pate.x, pate.y, 180)
	if t < 0.5:
		_immeuble(fiches, 0, 0, 2, 2, _hauteur(pate, 181, 5.0, 7.5), F_HANGAR, pate, 181)
		_chantier(fiches, 2, 0, pate, 182, port)
		_chantier(fiches, 2, 1, pate, 183, port)
		_immeuble(fiches, 0, 2, 1, 1, _hauteur(pate, 184, 5.0, 6.5), F_HANGAR, pate, 184)
		_prop(_f(fiches, 0, 2), "cheminee", _centre_de(fiches, 0, 2) + Vector2(-30, -30))
		_chantier(fiches, 1, 2, pate, 185, port)
		_chantier(fiches, 2, 2, pate, 186, port)
	else:
		_immeuble(fiches, 0, 0, 3, 1, _hauteur(pate, 187, 6.0, 8.5), F_HANGAR, pate, 187)
		for i in 3:
			_chantier(fiches, i, 1, pate, 188 + i, port)
		_immeuble(fiches, 0, 2, 2, 1, _hauteur(pate, 191, 5.0, 6.5), F_HANGAR, pate, 191)
		var chateau: Dictionary = _f(fiches, 2, 2)
		var c := _centre_de(fiches, 2, 2)
		_prop(chateau, "chateau_eau", c)
		_bloquer(chateau, Rect2(c - Vector2(26, 26), Vector2(52, 52)))
	if port:
		# La grue : le repère du port, visible de loin. Deux boîtes suffisent.
		var q: Dictionary = _f(fiches, 2, 1) if t < 0.5 else _f(fiches, 1, 1)
		var pied := _centre_de(fiches, 2, 1) if t < 0.5 else _centre_de(fiches, 1, 1)
		_bati(q, pied, 14.0, 14.0, 17.0, F_PLEIN, Color("#8a4a3a"))
		_bati(q, pied + Vector2(0.0, -40.0), 9.0, 110.0, 1.4, F_PLEIN, Color("#8a4a3a"), false, 17.0)

## Une cour d'usine : des conteneurs, une citerne, une benne — du volume bas qui
## se contourne. Tout bloque : c'est de l'acier.
func _chantier(fiches: Array, i: int, j: int, pate: Vector2i, sel: int, port: bool) -> void:
	var fiche: Dictionary = _f(fiches, i, j)
	fiche["sol"] = S_BETON
	var c := _centre_de(fiches, i, j)
	var t := _bruit(pate.x * 3 + i, pate.y * 3 + j, sel)
	if t < (0.6 if port else 0.4):
		var angle := PI * 0.5 * float(_entier(pate.x * 3 + i, pate.y * 3 + j, sel + 1, 2))
		_prop(fiche, "conteneur_a" if t < 0.3 else "conteneur_b", c + Vector2(-16, -10), angle)
		_prop(fiche, "conteneur_b" if t < 0.3 else "conteneur_a", c + Vector2(18, 16), angle)
		_bloquer(fiche, Rect2(c - Vector2(38, 34), Vector2(76, 68)))
	elif t < 0.7:
		_prop(fiche, "citerne", c)
		_bloquer(fiche, Rect2(c - Vector2(34, 34), Vector2(68, 68)))
	elif t < 0.85:
		_prop(fiche, "benne", c + Vector2(-24, 0), 0.2)
		_prop(fiche, "benne", c + Vector2(20, 6), -0.15)
	# sinon : une dalle vide, où l'on se garera

func _parc(fiches: Array, pate: Vector2i) -> void:
	for j in 3:
		for i in 3:
			var fiche: Dictionary = _f(fiches, i, j)
			var c := _centre_de(fiches, i, j)
			var sel := 200 + j * 3 + i
			if i == 1 and j == 1:
				fiche["sol"] = S_ALLEE_X
				_prop(fiche, "fontaine", c)
				_bloquer(fiche, Rect2(c - Vector2(30, 30), Vector2(60, 60)))
				continue
			if i == 1:
				fiche["sol"] = S_ALLEE_V
				_prop(fiche, "banc", c + Vector2(-26, 0), 0.0)
				_prop(fiche, "lampadaire_parc", c + Vector2(26, 20))
				continue
			if j == 1:
				fiche["sol"] = S_ALLEE_H
				_prop(fiche, "banc", c + Vector2(0, -26), PI * 0.5)
				_prop(fiche, "lampadaire_parc", c + Vector2(20, 26))
				continue
			fiche["sol"] = S_HERBE
			var ou := c + Vector2((_bruit(pate.x * 3 + i, pate.y * 3 + j, sel) - 0.5) * 36.0,
				(_bruit(pate.x * 3 + i, pate.y * 3 + j, sel + 1) - 0.5) * 36.0)
			_prop(fiche, "arbre", ou, 0.0, lerpf(0.95, 1.25, _bruit(i, j, sel + 2)))
			_bloquer(fiche, Rect2(ou - Vector2(13, 13), Vector2(26, 26)))
			_prop(fiche, "arbre_petit", c - (ou - c) * 0.9, 0.0, 0.9)
			_prop(fiche, "buisson", c + Vector2(34, -30), 0.0, 1.1)
			_prop(fiche, "buisson", c + Vector2(-32, 32), 0.0, 0.9)

## Une esplanade : une arène. Pas de mur, on y entre lancé et on en ressort de
## même. Les pièges se posent tout seuls quand quatre voitures s'y croisent.
func _esplanade(fiches: Array, _pate: Vector2i) -> void:
	for fiche in fiches:
		fiche["sol"] = S_PAVES

## Un repaire : la dalle du gang au milieu, deux cours où dorment ses voitures,
## et de la vieille bâtisse basse autour — un squat, pas une rue.
func _repaire(fiches: Array, pate: Vector2i, quartier: int, gang: int) -> void:
	var milieu: Dictionary = _f(fiches, 1, 1)
	milieu["sol"] = S_PAVES
	milieu["teinte"] = _teinte_territoire(gang, 0.45)
	var cours: Array = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]
	var a: Vector2i = cours[_entier(pate.x, pate.y, 210, 4)]
	var b: Vector2i = cours[posmod(_entier(pate.x, pate.y, 210, 4) + 2, 4)]
	for j in 3:
		for i in 3:
			if i == 1 and j == 1:
				continue
			var ici := Vector2i(i, j)
			if ici == a or ici == b:
				var cour: Dictionary = _f(fiches, i, j)
				cour["sol"] = S_BETON
				cour["teinte"] = _teinte_territoire(gang, 0.3)
				var c := _centre_de(fiches, i, j)
				var le_long := Vector2(1, 0) if a.y == 1 else Vector2(0, 1)
				for k in 2:
					cour["places"].append({"p": c + le_long * (-22.0 + 44.0 * float(k)),
						"a": le_long.angle() + PI * 0.5, "cote": 4 + k, "gang": gang})
				continue
			var sel := 211 + j * 3 + i
			var style := F_VIEUX if quartier in [VIEUX, COMMERCE, CENTRE, AFFAIRES] else \
				(F_HANGAR if quartier in [INDUSTRIE, PORT] else F_LOGEMENTS)
			_immeuble(fiches, i, j, 1, 1, _hauteur(pate, sel, 4.0, 7.0), style, pate, sel)

## Un quai : les tuiles qui touchent l'eau restent libres et meublées, les
## autres portent des immeubles bas d'une tuile.
func _rive(fiches: Array, pate: Vector2i, quartier: int, _gang: int) -> void:
	var style := F_LOGEMENTS
	match quartier:
		COMMERCE, CENTRE, AFFAIRES: style = F_COMMERCE
		VIEUX: style = F_VIEUX
		INDUSTRIE, PORT: style = F_HANGAR
		BANLIEUE: style = F_MAISON
	for j in 3:
		for i in 3:
			var fiche: Dictionary = _f(fiches, i, j)
			var c := int(fiche["c"])
			var l := int(fiche["l"])
			if eau(c, l) or sur_le_rail(c, l):
				continue
			var touche := eau(c - 1, l) or eau(c + 1, l) or eau(c, l - 1) or eau(c, l + 1)
			var sel := 320 + j * 3 + i
			if touche or quartier == PARC:
				fiche["sol"] = S_PAVES if quartier != PARC else S_HERBE
				var centre_px := _centre_de(fiches, i, j)
				var t := _bruit(c, l, sel)
				if t < 0.3:
					_prop(fiche, "banc", centre_px, PI * 0.5 * float(_entier(c, l, sel + 1, 4)))
				elif t < 0.55:
					_prop(fiche, "lampadaire_parc", centre_px)
				elif t < 0.7:
					_prop(fiche, "arbre_petit", centre_px, 0.0, 0.9)
					_bloquer(fiche, Rect2(centre_px - Vector2(10, 10), Vector2(20, 20)))
				continue
			if quartier == BANLIEUE:
				var centre_b := _centre_de(fiches, i, j)
				var h := _hauteur(pate, sel, 3.2, 4.2)
				_bati(fiche, centre_b, 52.0, 46.0, h, F_MAISON, _teinte_de(F_MAISON, c, l, sel))
				_bati(fiche, centre_b, 58.0, 52.0, 0.5, F_PLEIN, _parmi(TOITS, c, l, sel + 5), false, h)
				continue
			_immeuble(fiches, i, j, 1, 1, _hauteur(pate, sel, 5.0, 9.0), style, pate, sel)

## Les façades sur boulevard : une tuile, un immeuble, dans le style du
## quartier mais d'un étage de plus, avec un rez-de-chaussée commerçant dans
## les quartiers denses. Les tuiles que la voie coupe restent vierges.
func _bordure(fiches: Array, pate: Vector2i, quartier: int, _gang: int) -> void:
	var style := F_LOGEMENTS
	match quartier:
		COMMERCE, CENTRE: style = F_COMMERCE
		AFFAIRES: style = F_BUREAUX
		VIEUX: style = F_VIEUX
		INDUSTRIE, PORT: style = F_HANGAR
		BANLIEUE: style = F_MAISON
		PARC: style = F_PLEIN
	for j in 3:
		for i in 3:
			var fiche: Dictionary = _f(fiches, i, j)
			var c := int(fiche["c"])
			var l := int(fiche["l"])
			if not voie_libre(c, l).is_empty():
				continue
			var sel := 340 + j * 3 + i
			if quartier == PARC:
				fiche["sol"] = S_HERBE
				if _bruit(c, l, sel) < 0.5:
					var centre_px := _centre_de(fiches, i, j)
					_prop(fiche, "arbre", centre_px, 0.0, 1.0)
					_bloquer(fiche, Rect2(centre_px - Vector2(10, 10), Vector2(20, 20)))
				continue
			if quartier == BANLIEUE:
				var centre_b := _centre_de(fiches, i, j)
				var h := _hauteur(pate, sel, 3.4, 4.4)
				_bati(fiche, centre_b, 54.0, 48.0, h, F_MAISON, _teinte_de(F_MAISON, c, l, sel))
				_bati(fiche, centre_b, 60.0, 54.0, 0.5, F_PLEIN, _parmi(TOITS, c, l, sel + 5), false, h)
				continue
			var basse := 7.0 if quartier in [CENTRE, AFFAIRES, COMMERCE] else 5.5
			_immeuble(fiches, i, j, 1, 1, _hauteur(pate, sel, basse, basse + 5.0), style, pate, sel)

## Le pâté d'un HÔPITAL ou d'une PLANQUE : des immeubles d'une tuile tout
## autour, et la tuile du lieu laissée en dalle — c'est le parvis où l'on entre.
func _lieu_visitable(fiches: Array, pate: Vector2i, quartier: int, _gang: int, lieu: String) -> void:
	var style := F_LOGEMENTS
	match quartier:
		COMMERCE, CENTRE: style = F_COMMERCE
		AFFAIRES: style = F_BUREAUX
		VIEUX: style = F_VIEUX
		INDUSTRIE, PORT: style = F_HANGAR
		BANLIEUE: style = F_MAISON
	var libre := Vector2i(1, 1) if lieu == "hopitaux" else Vector2i(0, 2)
	for j in 3:
		for i in 3:
			if i == libre.x and j == libre.y:
				var fiche: Dictionary = _f(fiches, i, j)
				fiche["sol"] = S_BETON if lieu == "hopitaux" else S_PAVES
				continue
			var sel := 360 + j * 3 + i
			var basse := 6.0 if lieu == "hopitaux" else 4.5
			_immeuble(fiches, i, j, 1, 1, _hauteur(pate, sel, basse, basse + 3.5), style, pate, sel)

## Un pâté SIMPLE : des immeubles d'une tuile, pour que le garage ou la cabine
## qu'il porte en (0,0) ne se retrouve pas sous une tour de quatre tuiles.
func _simple(fiches: Array, pate: Vector2i, quartier: int, _gang: int, garage: bool) -> void:
	var style := F_BUREAUX
	match quartier:
		COMMERCE: style = F_COMMERCE
		VIEUX: style = F_VIEUX
		RESIDENCES, BANLIEUE: style = F_LOGEMENTS
		INDUSTRIE, PORT: style = F_HANGAR
		CENTRE: style = F_TOUR
	for j in 3:
		for i in 3:
			if i == 0 and j == 0 and garage:
				# Le garage : une dalle, quatre piliers, un auvent qu'on traverse.
				# La seule façade de la ville dans laquelle on ENTRE.
				var fiche: Dictionary = _f(fiches, 0, 0)
				fiche["sol"] = S_BETON
				var c := _centre_de(fiches, 0, 0)
				for dx in [-1.0, 1.0]:
					for dy in [-1.0, 1.0]:
						_bati(fiche, c + Vector2(dx, dy) * 36.0, 6.0, 6.0, 4.2, F_PLEIN, Color("#3a3d42"), false)
				_bati(fiche, c, 92.0, 92.0, 0.6, F_PLEIN, Palette.SERIE.darkened(0.55), false, 4.2)
				continue
			if i == 1 and j == 1 and quartier in [PARC, RESIDENCES, BANLIEUE]:
				_jardin(fiches, 1, 1, pate, 230)
				continue
			var sel := 231 + j * 3 + i
			var haute := style == F_TOUR
			_immeuble(fiches, i, j, 1, 1, _hauteur(pate, sel, 14.0, 24.0) if haute else _hauteur(pate, sel, 5.0, 10.0),
				style, pate, sel)

## Les voitures qui dorment le long des rues : sur la file de stationnement de
## la rue voisine, dans le sens de la circulation. `cote` : 0 ouest, 1 nord,
## 2 est, 3 sud. Près d'un repaire, une sur deux porte les couleurs du gang ;
## ailleurs sur son territoire, une sur sept.
func _garer(fiches: Array, pate: Vector2i, quartier: int, gang: int, repaire: bool) -> void:
	var chance := 0.45
	match quartier:
		CENTRE: chance = 0.5
		COMMERCE, VIEUX: chance = 0.58
		BANLIEUE: chance = 0.36
		INDUSTRIE, PORT: chance = 0.28
		PARC: chance = 0.14
	for j in 3:
		for i in 3:
			var fiche: Dictionary = _f(fiches, i, j)
			var c := _centre_de(fiches, i, j)
			var bords: Array = []
			if i == 0: bords.append([Vector2(-1, 0), 0, -PI * 0.5])
			if i == 2: bords.append([Vector2(1, 0), 2, PI * 0.5])
			if j == 0: bords.append([Vector2(0, -1), 1, 0.0])
			if j == 2: bords.append([Vector2(0, 1), 3, PI])
			for bord in bords:
				var cote := int(bord[1])
				if _bruit(int(fiche["c"]), int(fiche["l"]), 240 + cote) > chance:
					continue
				var cv := int(fiche["c"]) + int((bord[0] as Vector2).x)
				var lv := int(fiche["l"]) + int((bord[0] as Vector2).y)
				if eau(int(fiche["c"]), int(fiche["l"])) or eau(cv, lv):
					continue
				# Ni sur un boulevard ni le long : la place serait sur le trottoir
				# du boulevard, en travers du sens de sa circulation.
				if not voie_libre(int(fiche["c"]), int(fiche["l"])).is_empty() or not voie_libre(cv, lv).is_empty():
					continue
				var place := {"p": c + (bord[0] as Vector2) * (PAS * 0.5 + STATIONNEMENT), "a": float(bord[2]), "cote": cote}
				if gang >= 0 and (repaire or _bruit(int(fiche["c"]), int(fiche["l"]), 250 + cote) < 0.14):
					place["gang"] = gang
				fiche["places"].append(place)

# ------------------------------------------------------------ voitures dormantes

## L'identifiant d'une place : la tuile et son côté. C'est lui que le client
## demande à l'hôte quand il ouvre une portière, et que l'hôte diffuse quand
## la voiture se réveille.
static func id_dormante(colonne: int, ligne: int, cote: int) -> int:
	return ID_DORMANTE + (ligne * COLONNES + colonne) * COTES + cote

static func est_dormante(id: int) -> bool:
	return id >= ID_DORMANTE

## La fiche complète d'une voiture dormante : {id, p, a, modele, gang, quartier}
## ou vide si l'identifiant ne correspond à rien.
func dormante(id: int) -> Dictionary:
	if id < ID_DORMANTE:
		return {}
	var brut := id - ID_DORMANTE
	var cote := posmod(brut, COTES)
	var indice := brut / COTES
	var colonne := posmod(indice, COLONNES)
	var ligne := indice / COLONNES
	if ligne >= LIGNES:
		return {}
	var fiche := tuile(colonne, ligne)
	for place in fiche["places"]:
		if int(place["cote"]) == cote:
			return decrire(fiche, place)
	return {}

## La fiche complète d'une place d'une tuile : identifiant, position, angle,
## modèle (tiré selon le quartier) et gang. Le morceau s'en sert pour poser la
## carrosserie, l'hôte pour réveiller la voiture.
func decrire(fiche: Dictionary, place: Dictionary) -> Dictionary:
	var colonne := int(fiche["c"])
	var ligne := int(fiche["l"])
	var quartier := quartier_du_pate(_pate_proche_de(colonne, ligne))
	var gang := int(place.get("gang", -1))
	var liste: Array = FormesCarnage.VOITURES_PAR_QUARTIER.get(quartier, [0])
	var modele := int(liste[_entier(colonne, ligne, 260 + int(place["cote"]), liste.size())])
	if gang >= 0:
		modele = 1 if _bruit(colonne, ligne, 270) < 0.5 else 4
	return {"id": id_dormante(colonne, ligne, int(place["cote"])), "p": place["p"], "a": float(place["a"]),
		"modele": modele, "gang": gang, "quartier": quartier}

## Les voitures dormantes autour d'un point : pour la collision, le vol, et le
## trafic qui freine. On balaie les tuiles du carré, pas la ville.
func dormantes_autour(point: Vector2, rayon: float) -> Array:
	var liste: Array = []
	var c0 := int(floor((point.x - rayon) / PAS))
	var c1 := int(floor((point.x + rayon) / PAS))
	var l0 := int(floor((point.y - rayon) / PAS))
	var l1 := int(floor((point.y + rayon) / PAS))
	for l in range(l0, l1 + 1):
		for c in range(c0, c1 + 1):
			if c < 0 or l < 0 or c >= COLONNES or l >= LIGNES or est_voie(c) or est_voie(l):
				continue
			var fiche := tuile(c, l)
			for place in fiche["places"]:
				if Vector2(place["p"]).distance_to(point) <= rayon:
					liste.append(decrire(fiche, place))
	return liste

# ------------------------------------------------------------ collisions

func bloquee(colonne: int, ligne: int) -> bool:
	return bool(tuile(colonne, ligne)["bloc"])

func rectangle_tuile(colonne: int, ligne: int) -> Rect2:
	var fiche := tuile(colonne, ligne)
	if fiche["rect"] != null:
		return fiche["rect"]
	return Rect2(Vector2(colonne, ligne) * PAS + Vector2(RETRAIT, RETRAIT), Vector2(PAS - RETRAIT * 2.0, PAS - RETRAIT * 2.0))

## Les rectangles qui bloquent une tuile, un par volume posé : c'est contre eux
## qu'on cogne, pas contre leur union.
func rectangles_tuile(colonne: int, ligne: int) -> Array:
	var fiche := tuile(colonne, ligne)
	var rects: Array = fiche["rects"]
	if not rects.is_empty():
		return rects
	return [rectangle_tuile(colonne, ligne)]

## Les tuiles bloquées susceptibles de toucher un cercle. Au plus quatre : c'est
## ce qui remplace le balayage de milliers de rectangles.
func _tuiles_autour(point: Vector2, rayon: float) -> Array:
	var c0 := int(floor((point.x - rayon) / PAS))
	var c1 := int(floor((point.x + rayon) / PAS))
	var l0 := int(floor((point.y - rayon) / PAS))
	var l1 := int(floor((point.y + rayon) / PAS))
	var liste: Array = []
	for c in range(c0, c1 + 1):
		for l in range(l0, l1 + 1):
			if bloquee(c, l):
				liste.append(Vector2i(c, l))
	return liste

func dans_un_batiment(point: Vector2, marge: float = 0.0) -> bool:
	for t: Vector2i in _tuiles_autour(point, marge):
		for r in rectangles_tuile(t.x, t.y):
			if (r as Rect2).grow(marge).has_point(point):
				return true
	return false

## Repousse un point hors des murs par le plus petit chevauchement.
## Renvoie [point corrigé, y a-t-il eu correction].
func degager(point: Vector2, rayon: float) -> Array:
	var corrige := point
	var touche := false
	for t: Vector2i in _tuiles_autour(point, rayon):
		for r in rectangles_tuile(t.x, t.y):
			var etendu := (r as Rect2).grow(rayon)
			if not etendu.has_point(corrige):
				continue
			var gauche := corrige.x - etendu.position.x
			var droite := etendu.end.x - corrige.x
			var haut := corrige.y - etendu.position.y
			var bas := etendu.end.y - corrige.y
			var minimum: float = min(min(gauche, droite), min(haut, bas))
			if minimum == gauche: corrige.x = etendu.position.x
			elif minimum == droite: corrige.x = etendu.end.x
			elif minimum == haut: corrige.y = etendu.position.y
			else: corrige.y = etendu.end.y
			touche = true
	return [corrige, touche]

# ------------------------------------------------------------ points utiles

## Un point libre dans une rue, autour d'un lieu. Quatorze essais puis on
## abandonne : insister davantage coûterait plus cher que le défaut à éviter.
func point_de_rue(rng: RandomNumberGenerator, autour: Vector2,
		rayon_min: float, rayon_max: float) -> Vector2:
	for essai in 14:
		var p: Vector2 = autour + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(rayon_min, rayon_max)
		p.x = clamp(p.x, PAS, etendue().x - PAS)
		p.y = clamp(p.y, PAS, etendue().y - PAS)
		if not dans_un_batiment(p, 40.0):
			return p
	return degager(autour + Vector2.RIGHT.rotated(rng.randf() * TAU) * rayon_min, 40.0)[0]

## Un point de la chaussée, pour faire naître une voiture qui roule : sur la
## file de droite de la rue la plus proche, dans un sens ou l'autre.
func point_de_chaussee(rng: RandomNumberGenerator, autour: Vector2,
		rayon_min: float, rayon_max: float) -> Dictionary:
	var p := point_de_rue(rng, autour, rayon_min, rayon_max)
	var libre := voie_libre_en(p)
	# Pas sur le parvis ni sur l'îlot de la place : une voiture qui y naît ne
	# suit aucune file.
	for essai in 6:
		if libre.is_empty() or String(libre["genre"]) in ["avenue", "anneau"]:
			break
		p = point_de_rue(rng, autour, rayon_min, rayon_max)
		libre = voie_libre_en(p)
	if not libre.is_empty() and String(libre["genre"]) in ["avenue", "anneau"]:
		# Sur un boulevard : dans un sens ou l'autre, sur la file de droite.
		var d: Vector2 = libre["d"]
		if rng.randf() < 0.5:
			d = -d
		var n := Vector2(-d.y, d.x)
		var ecart: float = float(libre["s"]) * (1.0 if d == Vector2(libre["d"]) else -1.0)
		return {"p": p + n * (FILE_BOULEVARD * PAS - ecart * PAS), "d": d}
	var carrefour := carrefour_proche(p)
	var horizontal: bool = abs(p.y - carrefour.y) < abs(p.x - carrefour.x)
	var sens: float = 1.0 if rng.randf() < 0.5 else -1.0
	if horizontal:
		var d := Vector2(sens, 0.0)
		return {"p": Vector2(p.x, carrefour.y + Vector2(-d.y, d.x).y * FILE), "d": d}
	var dv := Vector2(0.0, sens)
	return {"p": Vector2(carrefour.x + Vector2(-dv.y, dv.x).x * FILE, p.y), "d": dv}

# ------------------------------------------------------------ qui, où

func territoire(point: Vector2) -> int:
	return territoire_du_pate(_pate_proche(point))

func quartier(point: Vector2) -> int:
	return quartier_du_pate(_pate_proche(point))

func nom_du_quartier(point: Vector2) -> String:
	return String(NOMS_QUARTIERS[clamp(quartier(point), 0, NOMS_QUARTIERS.size() - 1)])

func _pate_proche(point: Vector2) -> Vector2i:
	var colonne: int = clamp(int(floor(point.x / PAS)), 0, COLONNES - 1)
	var ligne: int = clamp(int(floor(point.y / PAS)), 0, LIGNES - 1)
	return _pate_proche_de(colonne, ligne)

func nom_du_gang(indice: int) -> String:
	return String(GANGS[posmod(indice, GANGS.size())]["nom"])

## « de Le Lierre » ne se dit pas. Les noms de gang portent leur article : il
## faut contracter avant de les coller dans une phrase.
func du_gang(indice: int) -> String:
	var nom := nom_du_gang(indice)
	if nom.begins_with("Les "):
		return "des " + nom.substr(4)
	if nom.begins_with("Le "):
		return "du " + nom.substr(3)
	return "de " + nom

func couleur_du_gang(indice: int) -> Color:
	return GANGS[posmod(indice, GANGS.size())]["couleur"]

## Départs répartis sur un cercle au centre, dans la rue : quatre voitures au
## même endroit se poussent mutuellement dans un mur avant même le décompte.
func depart(place: int, rng: RandomNumberGenerator) -> Dictionary:
	var angle := TAU * float(posmod(place, 4)) / 4.0
	var p := point_de_rue(rng, centre() + Vector2.RIGHT.rotated(angle) * 420.0, 0.0, 240.0)
	return {"p": p, "a": angle + PI}

# ------------------------------------------------------------ la casse

## L'immeuble qui contient (ou frôle) un point : {id, b} ou vide. Les immeubles
## de plusieurs tuiles sont ancrés sur une seule ; on regarde donc les tuiles
## voisines aussi. Rare (un impact), donc pas mis en cache.
func immeuble_a(point: Vector2, marge: float = 8.0) -> Dictionary:
	var c0 := int(floor(point.x / PAS))
	var l0 := int(floor(point.y / PAS))
	for l in range(l0 - 2, l0 + 1):
		for c in range(c0 - 2, c0 + 1):
			if c < 0 or l < 0 or c >= COLONNES or l >= LIGNES:
				continue
			var fiche := tuile(c, l)
			var rang := 0
			for b in fiche["batis"]:
				var rect := Rect2(Vector2(b["p"]) - Vector2(float(b["w"]), float(b["d"])) * 0.5, Vector2(float(b["w"]), float(b["d"])))
				if float(b["h"]) >= 1.0 and rect.grow(marge).has_point(point):
					return {"id": (c * LIGNES + l) * 8 + rang, "b": b, "c": c, "l": l}
				rang += 1
	return {}

## Un immeuble éventré (son rez-de-chaussée est parti) ne bloque plus : on
## traverse la ruine. Toutes les tuiles que son emprise couvre s'ouvrent.
func eventrer(id: int) -> void:
	var tuile_ancre := id / 8
	var c := tuile_ancre / LIGNES
	var l := posmod(tuile_ancre, LIGNES)
	var rang := posmod(id, 8)
	var fiche := tuile(c, l)
	if rang >= (fiche["batis"] as Array).size():
		return
	var b: Dictionary = fiche["batis"][rang]
	var rect := Rect2(Vector2(b["p"]) - Vector2(float(b["w"]), float(b["d"])) * 0.5, Vector2(float(b["w"]), float(b["d"])))
	for ll in range(int(floor(rect.position.y / PAS)), int(floor((rect.end.y - 1.0) / PAS)) + 1):
		for cc in range(int(floor(rect.position.x / PAS)), int(floor((rect.end.x - 1.0) / PAS)) + 1):
			if cc < 0 or ll < 0 or cc >= COLONNES or ll >= LIGNES:
				continue
			var f := tuile(cc, ll)
			f["bloc"] = false
			f["rect"] = null
			f["rects"] = []

# ------------------------------------------------------------ la carte

## Peint un pâté et ses deux rues (ouest et nord) sur l'image de la carte : un
## pixel par tuile. La carte entière fait quatorze mille pâtés ; on la peint
## par lots, quelques centaines par image, jamais d'un bloc.
const COULEURS_CARTE := {
	CENTRE: Color("#d8d0c0"), AFFAIRES: Color("#a8b0c0"), COMMERCE: Color("#c09070"),
	VIEUX: Color("#d0a060"), RESIDENCES: Color("#9090a0"), BANLIEUE: Color("#b0c890"),
	INDUSTRIE: Color("#807870"), PORT: Color("#907060"), PARC: Color("#50a050"), EAU: Color("#204060")}
const CARTE_EAU := Color("#1a3a5c")
const CARTE_RUE := Color("#262628")
const CARTE_AVENUE := Color("#3c3c3e")
const CARTE_RAIL := Color("#0c0c0c")

func peindre_pate(image: Image, indice: int) -> void:
	var pate := pate_par_indice(indice)
	var zone: Color = COULEURS_CARTE[quartier_du_pate(pate)]
	var gang := territoire_du_pate(pate)
	if gang >= 0:
		zone = zone.lerp(couleur_du_gang(gang), 0.25)
	var cour := zone.darkened(0.15)
	var k := pate.x
	var kl := pate.y
	var fermee_v := rue_fermee_v(k, kl)
	var fermee_h := rue_fermee_h(kl, k)
	var croisement := fermee_v and rue_fermee_v(k, kl - 1) and fermee_h and rue_fermee_h(kl, k - 1)
	for dl in PERIODE:
		for dc in PERIODE:
			var c := pate.x * PERIODE + dc
			var l := pate.y * PERIODE + dl
			var couleur := zone
			if eau(c, l):
				couleur = CARTE_EAU
			elif sur_le_rail(c, l):
				couleur = CARTE_RAIL
			elif not voie_libre(c, l).is_empty():
				couleur = CARTE_AVENUE.lightened(0.12)
			elif dc < 2 and dl < 2:
				couleur = cour if croisement else (CARTE_AVENUE if est_avenue(c) or est_avenue(l) else CARTE_RUE)
			elif dc < 2:
				couleur = cour if fermee_v else (CARTE_AVENUE if est_avenue(c) else CARTE_RUE)
			elif dl < 2:
				couleur = cour if fermee_h else (CARTE_AVENUE if est_avenue(l) else CARTE_RUE)
			image.set_pixel(c, l, couleur)

## Les lieux d'un secteur, en pastilles de trois pixels.
func peindre_secteur(image: Image, secteur: Vector2i) -> void:
	var fiche := _lieux_du_secteur(secteur)
	for entree in [["garages", Palette.SERIE], ["cabines", Palette.AVERTISSEMENT],
			["arenes", Palette.CRITIQUE], ["repaires", Palette.ENCRE]]:
		for lieu in fiche[entree[0]]:
			var c := int(Vector2(lieu["p"]).x / PAS)
			var l := int(Vector2(lieu["p"]).y / PAS)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if c + dx >= 0 and l + dy >= 0 and c + dx < COLONNES and l + dy < LIGNES:
						image.set_pixel(c + dx, l + dy, entree[1])

## Le nombre de fiches en cache : pour le journal du banc, qui vérifie que la
## ville se génère à la demande et pas d'un bloc.
func fiches_en_cache() -> int:
	return _pates.size() * 9 + _rues.size()
