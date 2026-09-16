extends RefCounted
## ⭐⭐ LA CHARTE D'UN QUARTIER — ce que les neuf témoins ont appris, en données.
##
## « De base les témoins sont pas là pour être collés tels quels mais pour
## établir des règles par quartier. » (client, 15/09)
##
## Un témoin est un quartier de 40 × 40 réglé à la main, capture après capture.
## Ce qu'il contient se range en DEUX TAS, et tout le travail est de les séparer :
##
## * CE QUI EST SA COMPOSITION — `J_ARTERE = 19`, les quatorze sommets de la
##   boucle de banlieue, `PARC = Rect2i(14,16,9,8)`, « 34 bennes », un axe tracé
##   de bord à bord. Rien de tout ça ne se transpose : ce sont des coordonnées
##   dans un carré de 800 m, et un compteur absolu posé sur une emprise deux fois
##   plus grande donne un quartier à moitié vide.
##
## * CE QUI EST SA CHARTE — sa liste de modèles, l'écart entre ses rues, la
##   matière de son sol hors chaussée, ses densités, ses gammes de teintes. Ça,
##   c'est vrai partout, et c'est ce fichier.
##
## ⚠ LES DENSITÉS SONT DES PROBABILITÉS PAR EMPLACEMENT, PAS DES COMPTEURS. C'est
## la conversion qui coûte le plus cher à oublier : « douze voitures » devient
## « une voiture toutes les cinq cases de rue », sinon une ville de vingt
## kilomètres reçoit douze voitures en tout.

const KIT := preload("res://commun/ville2/kit.gd")

## Les hauts du kit, pour les cœurs de ville.
const TOURS := ["batiments/building-skyscraper-a", "batiments/building-skyscraper-b",
	"batiments/building-skyscraper-c", "batiments/building-skyscraper-d",
	"batiments/building-skyscraper-e"]
const IMMEUBLES_HAUTS := ["batiments/building-l", "batiments/building-m",
	"batiments/building-n", "batiments/building-i", "batiments/building-j"]
const IMMEUBLES := ["batiments/building-a", "batiments/building-b",
	"batiments/building-d", "batiments/building-f", "batiments/building-g",
	"batiments/building-h", "batiments/building-k"]
const COMMERCES := ["batiments/building-c", "batiments/building-e"]

## Les vingt et un pavillons, et la sélection « vieille ville » qui en sort.
const PAVILLONS := ["pavillons/building-type-a", "pavillons/building-type-b",
	"pavillons/building-type-c", "pavillons/building-type-d", "pavillons/building-type-e",
	"pavillons/building-type-f", "pavillons/building-type-g", "pavillons/building-type-h",
	"pavillons/building-type-i", "pavillons/building-type-j", "pavillons/building-type-k",
	"pavillons/building-type-l", "pavillons/building-type-m", "pavillons/building-type-n",
	"pavillons/building-type-o", "pavillons/building-type-p", "pavillons/building-type-q",
	"pavillons/building-type-r", "pavillons/building-type-s", "pavillons/building-type-t",
	"pavillons/building-type-u"]
const MAISONS_ANCIENNES := ["pavillons/building-type-a", "pavillons/building-type-c",
	"pavillons/building-type-f", "pavillons/building-type-j", "pavillons/building-type-m",
	"pavillons/building-type-q", "pavillons/building-type-h", "pavillons/building-type-i",
	"batiments/low-detail-building-n", "batiments/low-detail-building-wide-a",
	"batiments/low-detail-building-wide-b"]
const NOTABLES := ["batiments/building-k", "batiments/building-d",
	"batiments/building-c", "batiments/building-a", "batiments/building-h"]
const HANGARS := ["industriel/building-c", "industriel/building-h",
	"industriel/building-i", "industriel/building-l", "industriel/building-p",
	"industriel/building-q", "industriel/building-r", "industriel/building-s",
	"industriel/building-e", "industriel/building-f", "industriel/building-g",
	"industriel/building-j"]
const USINES := ["industriel/building-a", "industriel/building-b",
	"industriel/building-d", "industriel/building-k", "industriel/building-m",
	"industriel/building-n", "industriel/building-o", "industriel/building-t"]
const FACULTES := ["batiments/building-a", "batiments/building-b", "batiments/building-l",
	"batiments/building-m", "batiments/building-n", "batiments/building-j",
	"batiments/building-i", "batiments/building-h", "batiments/building-e"]
const HOTELS := ["batiments/building-l", "batiments/building-i", "batiments/building-j",
	"batiments/building-f", "batiments/building-g", "batiments/building-m"]
const PETITS_DE_MER := ["pavillons/building-type-b", "pavillons/building-type-d",
	"pavillons/building-type-f", "pavillons/building-type-n", "pavillons/building-type-t",
	"pavillons/building-type-u", "pavillons/building-type-g"]
const CABANES := ["pxl/cabane-tole-a", "pxl/cabane-tole-b", "pxl/cabane-tole-c",
	"pxl/cabane-bois-a", "pxl/cabane-bois-b", "pxl/abri-bache",
	"pxl/caravane", "pxl/camping-car"]

## L'ARBRE D'ALIGNEMENT, par ambiance.
const ALIGNEMENT := ["arbre_oak", "arbre_rond", "arbre", "arbre_plateau", "arbre_fin"]
const PALMIERS := ["nature/tree_palm", "nature/tree_palmTall", "nature/tree_palmBend"]

## ⭐ LES NEUF CHARTES.
##
## `pas`      écart entre deux rues du quartier, EN CASES (l'îlot fait donc
##            `pas − 1` de côté). C'est le réglage le plus visible de tous : à 5
##            on lit un centre-ville, à 9 un lotissement.
## `meandre`  amplitude du serpentement de la rue, en cases. Zéro = une grille
##            orthogonale ; 2 = une trame qui respire. ⚠ C'est un DÉPORT, donc
##            la rue reste faite de segments droits — `ajouter_route` refuse la
##            diagonale.
## `sacs`     `[[part, liste], …]` — la part est cumulative sur 1.0.
## `densite`  probabilité de poser à un emplacement libre.
## `recul`    en DEMI-cases, entre le bord de la chaussée et la façade.
## `sol`      matière hors chaussée.
## `toits`    gamme de l'atlas ; `murs` gamme de peinture, `garder` la part
##            qu'on laisse à la couleur du kit.
## `lampes`   une lampe toutes les N cases de rue ; `voitures` idem ;
## `arbres`   probabilité d'un arbre d'alignement par case de rue.
const CHARTES := {
	"centre": {
		"pas": 5, "meandre": 1.0, "recul": 0, "densite": 0.92,
		"sacs": [[0.80, IMMEUBLES + COMMERCES], [0.95, IMMEUBLES_HAUTS], [1.0, TOURS]],
		## ⚠ ON PEINT UN MUR SUR DEUX, ET C'EST UN CORRECTIF D'ÉCHELLE. Le témoin
		## du centre ne peignait aucun mur : sur 800 m de côté, ses toits
		## d'ardoise suffisaient à varier l'image. Sur une capture de six
		## kilomètres, le même quartier vire au GRIS UNIFORME — mille immeubles
		## blancs sous mille toits d'ardoise. À 0,55 de « garder », un immeuble
		## sur deux prend une façade colorée et le quartier reprend du relief.
		"sol": Ville2.M_DALLE, "toits": "VIEILLE", "murs": "PAVILLONS", "garder": 0.55,
		"lampes": 3, "voitures": 5, "arbres": 0.22, "essence": ALIGNEMENT,
	},
	"vieille_ville": {
		## Les ruelles de la vieille ville sont serrées et tordues : c'est le
		## seul quartier où le méandre dépasse la largeur d'un îlot.
		"pas": 4, "meandre": 2.0, "recul": 0, "densite": 0.95,
		"sacs": [[0.68, MAISONS_ANCIENNES], [0.89, MAISONS_ANCIENNES],
			[0.96, NOTABLES], [1.0, IMMEUBLES]],
		"sol": Ville2.M_TERRE, "toits": "VIEILLE", "murs": "VIEILLE_PIERRE",
		"garder": 0.16, "lampes": 4, "voitures": 12, "arbres": 0.0,
		"essence": ALIGNEMENT,
	},
	"chaud": {
		"pas": 5, "meandre": 0.6, "recul": 0, "densite": 0.92,
		"sacs": [[0.75, IMMEUBLES + COMMERCES], [1.0, IMMEUBLES_HAUTS]],
		"sol": Ville2.M_DALLE, "toits": "VIEILLE", "murs": "INDUSTRIE",
		"garder": 0.35, "lampes": 2, "voitures": 4, "arbres": 0.0,
		"essence": ALIGNEMENT,
	},
	"pavillons": {
		## ⚠ NEUF CASES, PAS CINQ. C'est ce qui distingue un lotissement d'un
		## centre-ville bien plus que la liste des maisons : des îlots de huit
		## cases, des jardins au milieu, et une rue qu'on voit rarement droite.
		"pas": 9, "meandre": 2.2, "recul": 1, "densite": 0.88,
		"sacs": [[1.0, PAVILLONS]],
		"sol": Ville2.M_HERBE, "toits": "PAVILLONNAIRE", "murs": "PAVILLONS",
		"garder": 0.25, "lampes": 7, "voitures": 6, "arbres": 0.30,
		"essence": ALIGNEMENT,
	},
	"campus": {
		"pas": 8, "meandre": 1.4, "recul": 2, "densite": 0.70,
		"sacs": [[1.0, FACULTES]],
		"sol": Ville2.M_HERBE, "toits": "PAVILLONNAIRE", "murs": "",
		"garder": 1.0, "lampes": 5, "voitures": 8, "arbres": 0.45,
		"essence": ALIGNEMENT,
	},
	"industrie": {
		"pas": 8, "meandre": 0.4, "recul": 1, "densite": 0.80,
		"sacs": [[0.72, HANGARS], [1.0, USINES]],
		"sol": Ville2.M_DALLE, "toits": "TOLE", "murs": "INDUSTRIE",
		"garder": 0.20, "lampes": 6, "voitures": 9, "arbres": 0.0,
		"essence": ALIGNEMENT,
	},
	"plage": {
		"pas": 5, "meandre": 0.8, "recul": 0, "densite": 0.90,
		"sacs": [[0.45, HOTELS], [1.0, PETITS_DE_MER + COMMERCES]],
		"sol": Ville2.M_SABLE, "toits": "PAVILLONNAIRE", "murs": "PAVILLONS",
		"garder": 0.35, "lampes": 4, "voitures": 7, "arbres": 0.35,
		"essence": PALMIERS,
	},
	"bidonville": {
		## ⚠ LES CABANES SE POSENT À LEUR TAILLE NATURELLE ET NE SE TEIGNENT PAS.
		## Les dix modèles `pxl/` portent leurs propres matières nommées —
		## quarante-trois couleurs. Une teinte d'instance par-dessus les
		## multiplierait et effacerait ce travail.
		"pas": 6, "meandre": 2.6, "recul": 0, "densite": 0.85,
		"sacs": [[1.0, CABANES]],
		"sol": Ville2.M_TERRE, "toits": "", "murs": "", "garder": 1.0,
		"lampes": 12, "voitures": 16, "arbres": 0.0, "essence": ALIGNEMENT,
	},
	"port": {
		"pas": 8, "meandre": 0.3, "recul": 1, "densite": 0.78,
		"sacs": [[1.0, HANGARS]],
		"sol": Ville2.M_DALLE, "toits": "TOLE", "murs": "INDUSTRIE",
		"garder": 0.20, "lampes": 6, "voitures": 10, "arbres": 0.0,
		"essence": ALIGNEMENT,
	},
	## LE PARC N'A NI RUE NI BÂTIMENT : `pas` à zéro le dit, et le remplisseur
	## s'arrête là. Sa végétation vient de la passe de semis, comme la campagne.
	"parc": {
		"pas": 0, "meandre": 0.0, "recul": 0, "densite": 0.0,
		"sacs": [], "sol": Ville2.M_HERBE, "toits": "", "murs": "", "garder": 1.0,
		"lampes": 0, "voitures": 0, "arbres": 0.0, "essence": ALIGNEMENT,
	},
}

static func charte(genre: String) -> Dictionary:
	return CHARTES.get(genre, CHARTES["pavillons"])
