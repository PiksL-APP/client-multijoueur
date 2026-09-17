extends RefCounted
## LA COULEUR DES MAISONS — la brique qui répond à « tu utilises toujours les
## mêmes maisons ».
##
## ⚠ CE N'ÉTAIT PAS UN PROBLÈME DE MODÈLES. Le générateur de banlieue alterne
## déjà seize modèles de pavillon, tirés sans remise (`VarierVille2`) pour que
## les seize passent avant qu'aucun ne revienne. Et le client voit quand même
## « toujours les mêmes maisons avec les mêmes variantes » (12/09).
##
## La raison est dans le kit : les vingt-et-un pavillons de Kenney partagent UN
## atlas. Murs blancs, toit menthe, pour tous les vingt-et-un. À la distance où
## l'on juge un quartier — celle d'une capture vue d'en haut — la différence
## entre deux plans de masse ne se lit pas ; la différence entre un mur crème et
## un mur ocre se lit de très loin. La variété qu'on avait ajoutée était donc
## réelle et INVISIBLE.
##
## On repeint donc. Le shader des kits multiplie l'atlas par la teinte
## d'instance : une teinte claire ne fait que colorer, une teinte saturée
## salit. Toutes les palettes ci-dessous restent au-dessus de 0,62 en valeur —
## en dessous, la maison devient une tache et le quartier un damier.
##
## ⚠ ON PEINT APRÈS COUP, PAS À LA POSE. Les lots se posent depuis six endroits
## différents (`Lotisseur.border`, `aligner`, les poses à la main de chaque
## générateur) ; passer une teinte à chacun, c'est six occasions de l'oublier.
## Une passe qui relit `v.lots` à la fin n'en a aucune.

const VARIER := preload("res://commun/ville2/varier.gd")

## Le pavillonnaire d'Amérique : blanc, crème, bleu pâle, jaune paille, rose
## poudré, vert d'eau, brique claire. C'est la gamme d'un lotissement réel, où
## deux maisons voisines ne sont jamais de la même couleur.
const PAVILLONS := ["#ffffff", "#f3e7cf", "#cfdce8", "#f0e2b0", "#eed3cf",
	"#cfe3d4", "#e7c3a8", "#dfe4e8", "#f6ddb8", "#d8cfe0"]

## LA PIERRE DU SUD (demande du client pour la colline, 13/09 : « des maisons
## de pierre style sud de la France »). Calcaire, ocre jaune, ocre rouge, sable
## — la gamme d'un village du Lubéron. Aucun blanc pur : une maison de pierre
## n'est jamais blanche, elle est beige.
const PIERRE_DU_SUD := ["#e8d3ab", "#dcc08d", "#d6b482", "#e3cfa6", "#cfae7d",
	"#e0c19a", "#d2a874", "#e6d8ba"]

## La vieille ville : le même calcaire, plus sale, avec des enduits passés.
const VIEILLE_PIERRE := ["#ded2bb", "#d3c6ad", "#e4dac6", "#c9bda6", "#d8c9ae",
	"#cdc4b4", "#e0d4b8"]

## Le bidonville : tôle rouillée, bois gris, bâche fanée. Ici on descend plus
## bas — c'est le seul quartier où la saleté est le sujet.
const TOLE := ["#c2a184", "#b9917a", "#a89a86", "#c8b79d", "#9fa89b",
	"#b08b72", "#aeb2a6", "#c6a68c"]

## L'industrie : béton, tôle peinte, rouille.
const INDUSTRIE := ["#d5d7d2", "#c3c7c4", "#d8cdbc", "#bfae9c", "#cdd4d8", "#c9b7a4"]

## ⭐⭐⭐ LE CENTRE-VILLE, EN DEUX PALETTES — « les deux, par quartier » (client,
## 17/09), après plusieurs captures où tout le centre lisait gris.
##
## ⚠ POURQUOI UN CENTRE EST GRIS ALORS QU'ON A VINGT MODÈLES. Les immeubles du
## kit partagent tous le même atlas : murs blancs, toit ardoise, pour TOUS. La
## variété de FORME ne se lit pas à la distance où l'on juge un quartier — la
## variété de COULEUR, si. Mille blocs blancs sous des toits gris font une
## bouillie, et c'est exactement ce qu'on voyait sur une capture à six
## kilomètres.
##
## PIERRE_DE_TAILLE : le centre ancien européen. Crème, ocre, sable, brique
## cuite. Aucun blanc pur — une façade de pierre est beige, jamais blanche — et
## une seule brique vraiment sombre, qui sert d'accent : au-delà, la rue vire au
## rouge et ne lit plus comme de la pierre.
const PIERRE_DE_TAILLE := ["#e8dcc0", "#e0cfae", "#d9b98a", "#cba07a", "#c08a5e",
	"#e3d6b8", "#d2b593", "#9c5a44", "#dcc9a4", "#c89a72"]

## BETON_VERRE : le quartier d'affaires. Gris chauds et froids, anthracite, et
## deux bleus de vitrage qui font les tours. ⚠ Les bleus restent MINORITAIRES :
## une tour sur quatre en verre se lit comme une ville moderne, une sur deux se
## lit comme un aquarium.
const BETON_VERRE := ["#c9cbcf", "#b4b8be", "#9aa0a8", "#8d9299", "#5b6672",
	"#d5d8dc", "#a8c4d8", "#7f9db5", "#c0c4c8", "#6e7883"]

## Repeint tous les lots d'un genre (ou tous, si `genre` est vide) dans une
## palette, sans deux voisins de même couleur : on tire dans un sac, donc la
## palette passe en entier avant qu'une couleur revienne.
##
## `garder` laisse une part des maisons à la couleur du kit — un quartier dont
## CHAQUE maison est peinte se remarque autant qu'un quartier où aucune ne l'est.
static func peindre(v: Ville2, alea: RandomNumberGenerator, genre: String,
		palette: Array, garder := 0.0) -> int:
	var sac: RefCounted = VARIER.new(palette, alea)
	var peints := 0
	for l in v.lots:
		if genre != "" and String(l.get("genre", "")) != genre: continue
		if l.has("c"): continue
		if garder > 0.0 and alea.randf() < garder: continue
		l["c"] = sac.tirer()
		peints += 1
	return peints

## ⚠ LES TOITS, QUI SONT L'AUTRE MOITIÉ — ET LA PLUS VISIBLE. Un quartier se
## juge d'en haut : ce qu'on voit d'une capture oblique, c'est 70 % de toiture
## et 30 % de mur. Toutes les toitures du kit pointent la même bande verte de
## l'atlas (voir `atlas.gd`) ; tant qu'elle n'est pas repeinte, changer les
## murs ne change presque rien à l'image. « Arrête d'utiliser le modèle avec
## les toitures vertes » (client, 13/09) dit exactement ça.
##
## On tire dans un sac, comme pour les murs : la gamme passe en entier avant
## qu'une couleur revienne, donc deux maisons voisines n'ont jamais le même
## toit.
static func couvrir(v: Ville2, alea: RandomNumberGenerator, genre: String,
		gamme: Array, garder := 0.0) -> int:
	var sac: RefCounted = VARIER.new(gamme, alea)
	var faits := 0
	for l in v.lots:
		if genre != "" and String(l.get("genre", "")) != genre: continue
		if l.has("toit"): continue
		if garder > 0.0 and alea.randf() < garder: continue
		l["toit"] = sac.tirer()
		faits += 1
	return faits

static func couvrir_genres(v: Ville2, alea: RandomNumberGenerator, genres: Array,
		gamme: Array, garder := 0.0) -> int:
	var n := 0
	for g in genres: n += couvrir(v, alea, String(g), gamme, garder)
	return n

## La même chose, mais pour une liste de genres.
static func peindre_genres(v: Ville2, alea: RandomNumberGenerator, genres: Array,
		palette: Array, garder := 0.0) -> int:
	var n := 0
	for g in genres: n += peindre(v, alea, String(g), palette, garder)
	return n
