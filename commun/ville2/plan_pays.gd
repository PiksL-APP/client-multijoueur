extends RefCounted
## L'ARCHIPEL DES AURONES — le plan de la carte, 20 × 20 km.
##
## ═══════════════════════════════════════════════════════════════════════════
## ⚠⚠⚠ CE N'EST PLUS UNE GÉOGRAPHIE INVENTÉE, C'EST UNE GÉOGRAPHIE DESSINÉE
## ═══════════════════════════════════════════════════════════════════════════
##
## Le client a fourni QUATRE CARTES : l'archipel d'ensemble avec ses six
## réseaux de transport, l'Île Centrale en détail, l'Île Nord, l'Île Sud-Est.
## Il les a validées. Ce fichier ne cherche donc plus une belle forme : il
## RETROUVE la sienne. Tout ce qui est écrit dans `claude/archipel-des-aurones.md`
## est un point à tenir, pas une suggestion.
##
## LA MÉTHODE, ET C'EST LA SEULE QUI MARCHE POUR ÇA :
##
##     LE DESSIN EST POSÉ À LA MAIN. LE BRUIT NE FAIT QUE CASSER LE CONTOUR.
##
## Chaque île est une union de LOBES de taille comparable, placés par une table
## (angle, distance, rayons) relevée sur les cartes du client, plus des CAPS
## (presqu'îles : Port-Nord, la Pointe de l'Aube, le port de la Gare Maritime)
## et des GOLFES (baies : la Baie du Sud, l'anse de Plage-des-Vents) qui sont
## des lobes SOUSTRAITS. Par-dessus seulement, un bruit déformé de douze à
## seize cases d'amplitude découpe le trait.
##
## ⚠ AUCUN LOBE NE DOIT DOMINER LES AUTRES. La leçon a été payée trois fois sur
## ce projet — l'île de Pikstown (« de haut on voyait le rectangle à travers
## l'ondulation »), le lac du parc (« une union de rectangles dont l'un est le
## plus grand A LA FORME DU PLUS GRAND »), l'archipel du 14/09. Une grande
## ellipse plus des petites bosses reste une grande ellipse. Sept ou huit lobes
## comparables sur un anneau, et le contour cesse d'avoir un centre.
##
## ═══════════════════════════════════════════════════════════════════════════
## L'ARCHITECTURE N'A PAS BOUGÉ : LA CARTE EST UNE FONCTION, PAS UN FICHIER
## ═══════════════════════════════════════════════════════════════════════════
##
## 1 000 000 de cases. Au remplissage des témoins, ce serait ~0,9 M d'objets et
## ~110 Mo de JSON, plus de dix minutes de génération — et le jeu tourne dans un
## navigateur. Il n'y a donc PAS de `cartes/aurones.json`. Ce qui est cuit
## d'avance, c'est CE PLAN : quelques dizaines de kilo-octets de nombres, à
## partir desquels n'importe quelle fenêtre de terrain se RECALCULE.
##
## LA RÈGLE QUI COMMANDE TOUT LE FICHIER :
##
##     LE SOL D'UNE CASE NE DÉPEND QUE DE SES PROPRES COORDONNÉES.
##
## Pas de ses voisines, pas d'une passe globale, pas d'un ordre de parcours.
## C'est ce qui garantit que deux fenêtres voisines se raccordent : elles ne se
## raccordent pas, elles CALCULENT LA MÊME CHOSE.
##
## ⚠ CE QUE CETTE RÈGLE INTERDIT, et que `generateur_carte.gd` faisait :
##
## * les propagations en largeur (`_distances_a_la_mer`, `_profondeurs`) : sur
##   un million de cases, il faudrait visiter toute la carte pour répondre sur
##   une seule. Remplacées par une DISTANCE SIGNÉE ANALYTIQUE en cases
##   (`distance_signee`), qui rend la même information en O(1) et sans voisinage ;
## * la relaxation du relief (`_relaxer`, six passes de rabotage) : un processus
##   itératif et global. Remplacée par une altitude DONT LA PENTE EST BORNÉE PAR
##   CONSTRUCTION (voir `_altitude_terre`) : il n'y a rien à raboter parce qu'il
##   ne se fabrique jamais de marche de plus de deux paliers.
##
## Ce qui reste global — un anneau, une ligne de métro, le trait d'un chemin
## côtier — est calculé UNE FOIS ici et rangé en POLYLIGNES. Quelques milliers
## de nombres, pas un million.
##
## Le plan est un DICTIONNAIRE PUR (que des nombres, des chaînes, des
## tableaux) : il part en JSON sans une ligne de conversion, donc il
## s'enregistre, se relit, se compare et SE RETOUCHE À LA MAIN. Et il n'a pas de
## `class_name` : une classe neuve compile au bureau et tombe en ligne, parce
## que `godot --headless --import` ne réécrit pas le cache de classes. Piège
## déjà payé deux fois.
##
## ═══════════════════════════════════════════════════════════════════════════
## L'ORDRE DE TRAVAIL, IMPOSÉ PAR LE CLIENT
## ═══════════════════════════════════════════════════════════════════════════
##
## « On va juste mettre en place le réseau de TGV (train), le TRAM, le MÉTRO,
## les autoroutes, les ruelles, etc. Ensuite on va mettre en place tout le
## reste. »
##
##   1. côtes et relief des trois îles + le chapelet ;
##   2. LES GARES ET LES STATIONS — elles fixent le squelette ;
##   3. les six réseaux, du plus structurant au plus fin ;
##   4. SEULEMENT APRÈS, les quartiers, en instanciant les témoins.
##
## `batir()` suit cet ordre, et `implantations` reste donc VIDE aujourd'hui :
## c'est l'étape 4, et elle n'a pas commencé. Tout ce qu'il faut pour elle est
## conservé (`emprise_plateau`, `COTE_TEMOIN`, `FERME`, `AERODROME`) et
## `generateur_pays.gd` la traite déjà — elle ne pose simplement rien tant que
## la liste est vide. Le client valide LE PLAN avant qu'on génère une scène.
##
## ═══════════════════════════════════════════════════════════════════════════
## ⚠⚠ LE MÉTRO PASSE SOUS LA MER, ET CE MODÈLE NE SAIT PAS ENCORE LE DESSINER
## ═══════════════════════════════════════════════════════════════════════════
##
## C'est explicite sur la carte d'ensemble : le tracé bleu pointillé traverse
## les bras de mer et c'est LUI qui relie les trois îles sans pont — le train,
## lui, prend les ponts.
##
## `Ville2` sait stocker trois choses : des routes (polylignes avec un `genre`
## et un `niveau`), du rail (polylignes avec un `niveau`), des lieux. Il n'a
## rien pour un tunnel, et le rendu ne sait pas en faire un. Trois options ont
## été pesées :
##
## a) le métro dans `rail` avec `niveau: -1`. `RenduVille2` pose les traverses
##    à `palier × 5 + 0,3` : la voie apparaîtrait cinq mètres SOUS le sol,
##    c'est-à-dire flottant dans une tranchée invisible, au milieu de la mer
##    pour les tronçons sous-marins. Un défaut visible, pour rien ;
## b) toucher au rendu. Hors périmètre, et ce serait un vrai chantier (tunnel,
##    trémie, station souterraine) ;
## c) ⭐ RETENUE : le métro vit DANS LE PLAN et SUR L'IMAGE, en entier, avec ses
##    stations. Dans une fenêtre 3D, seules ses STATIONS descendent (comme des
##    `lieux`) ; la voie, non. On ne dessine pas ce qu'on ne sait pas dessiner,
##    et le plan reste complet pour le jour où on saura.
##
## La même règle vaut pour le tram et le bus : le kit n'a ni rail de tramway ni
## abribus. Ils sont dans le plan, ils sont sur l'image du client, et ils ne
## descendent en 3D que par leurs arrêts. AUJOURD'HUI, DANS UNE FENÊTRE, IL N'Y
## A QUE LES ROUTES ET LE TRAIN. C'est dit ici pour que personne ne cherche le
## tramway dans une capture.

const CASE := Ville2.CASE
const PALIER := Ville2.PALIER

## Mille cases de vingt mètres : 20 × 20 km. Le chiffre du client.
const TAILLE := Vector2i(1000, 1000)

## ⚠ `preload` ET JAMAIS `class_name`, ici comme ailleurs.
const TRACE := preload("res://commun/ville2/trace.gd")

## ═══════════════════════════════════════════════════════════════════════════
## ⭐⭐ LA SOURCE DE VÉRITÉ EST UN FICHIER, PLUS UNE TABLE DE CONSTANTES
## ═══════════════════════════════════════════════════════════════════════════
##
## Le client a fait produire un JEU DE DONNÉES EXACT de son archipel : les dix
## îles avec leur centre et leur rayon, les dix-huit stations avec leur
## position, les dix ponts avec leurs deux extrémités, la composition des
## quinze lignes, et un graphe de routes. Il est dans `donnees/aurones/`.
##
## AVANT, ces nombres étaient RELEVÉS AU PIXEL sur ses dessins — donc devinés,
## donc faux de quelques centaines de mètres, et impossibles à retoucher
## autrement qu'en rouvrant ce fichier-ci. Maintenant ils VIENNENT DU FICHIER.
## C'est lui que le client peut modifier, c'est lui qui gagne en cas de
## désaccord, et c'est la seule façon d'avoir une géographie qui ne dérive pas.
##
## ⚠ CE QUE LE FICHIER DONNE ET CE QU'IL NE DONNE PAS. Il donne UN CENTRE ET UN
## RAYON : un CERCLE. Il ne donne aucune forme de côte. Le travail de ce
## fichier-ci reste donc entier — casser le cercle en lobes comparables et
## bruiter le contour — avec une contrainte de plus, et elle est nette :
## L'ENVELOPPE DOIT TENIR DANS LE RAYON DONNÉ. D'où le calcul de `util` dans
## `_ile_depuis` : on dessine à `rayon − amplitude du bruit`, et le bruit
## ramène le trait exactement au rayon. Sans ça, l'Île Centrale dépasserait ses
## 5,5 km, ce qu'elle faisait déjà (6,92 km, mesurés).
##
## ⚠ LA CONVENTION DE COORDONNÉES, VÉRIFIÉE. Les positions du fichier sont en
## KILOMÈTRES, et malgré ce que dit son `meta.origin` (« bottom_left »), Y CROÎT
## VERS LE SUD comme chez nous — l'Île Nord est à y = 5,4, la Centrale à 10, la
## Sud-Est à 13,6, et le nord est bien en haut sur les quatre dessins. Une case
## fait vingt mètres, donc :
const KM := 50.0                     ## cases par kilomètre
## La part du bruit de côte qu'on applique à un lobe de station. Voir le calcul
## dans `contexte()` : c'est le compromis entre « la gare reste à terre » et
## « l'île tient dans son rayon ».
const PART_BRUIT_CAP := 0.35
## De combien on rentre l'enveloppe nominale sous le rayon canonique, en parts
## de l'amplitude du bruit. À 1,0 l'île tient STRICTEMENT dans son rayon mais
## perd en moyenne une amplitude entière de diamètre ; à 0 elle déborde d'autant.
## Trois quarts : l'Île Centrale mesure 5,25 km en moyenne pour 5,5 km au plus
## large, là où le client en demande 5,5 — et c'est `outils/pays.gd` qui le
## MESURE sur le terrain rendu, pas cette constante qui le promet.
const MARGE_ENVELOPPE := 0.75
## ⚠ LA CAPITALE A LA CÔTE LA PLUS LISSE, ET CE N'EST PAS UN CAPRICE.
##
## Le bruit déplace le trait de côte de ± son amplitude : à onze pour cent du
## rayon, l'Île Centrale a une côte qui oscille de trois cents mètres. Or elle
## porte un plan RADIOCONCENTRIQUE dont l'anneau extérieur et le bout des huit
## radiales passent tout près du rivage — et une chaussée sur une case d'eau
## n'est pas rastérisée : on n'obtient pas une route fautive, on obtient une
## route TROUÉE EN SILENCE, et sur l'image un trait gris sur la mer.
##
## Six pour cent au lieu de onze, et le rayon de terre GARANTI (enveloppe moins
## amplitude) repasse au-dessus de l'anneau extérieur. C'est aussi ce que montre
## le dessin du client : sa capitale est nettement plus ronde que son Île
## Sud-Est, parce qu'elle est bâtie et endiguée.
const PART_BRUIT := {"ile_centrale": 0.06}
const PART_BRUIT_DEFAUT := 0.11

const FICHIER_ARCHIPEL := "res://donnees/aurones/archipel_complet.json"
const FICHIER_TRAJETS := "res://donnees/aurones/transit_paths.json"
const FICHIER_ROUTES := "res://donnees/aurones/road_graph.json"

# ══════════════════════════════════════════════════════════════════ LA GÉOGRAPHIE

## ⚠ CE QUI SUIT EST UN FILET, PAS LA SOURCE. Ces îles-ci sont mon relevé au
## pixel des dessins du client, et il ne sert PLUS QUE si
## `donnees/aurones/archipel_complet.json` est absent ou illisible — on ne casse
## pas un générateur pour un fichier de données manquant. Les vraies îles sont
## bâties par `_les_iles()` à partir du fichier ; celles-ci sont périmées de
## quelques centaines de mètres et le resteront.
##
## LES ÎLES, RELEVÉES SUR LES CARTES DU CLIENT.
##
## `c` le centre en cases, `r` le demi-diamètre de l'île, `bruit` l'amplitude du
## découpage de côte EN CASES (une grande île supporte seize cases de morsure,
## un îlot de vingt cases n'en supporte que cinq — sinon le bruit ne découpe pas
## l'île, il l'efface).
##
## `lobes` : [angle en degrés, distance au centre en parts de `r`, largeur et
## hauteur du lobe en parts de `r`]. Les distances tournent autour de 0,40 et
## les rayons autour de 0,65 : c'est le réglage qui donne une forme pleine sans
## qu'aucun lobe ne domine. Les valeurs sont VOLONTAIREMENT INÉGALES d'un lobe
## à l'autre — huit lobes identiques font un octogone flou, qui est encore une
## forme géométrique.
##
## `caps` : des lobes de plus, en coordonnées RELATIVES au centre — les
## presqu'îles nommées sur les cartes. `golfes` : des lobes SOUSTRAITS, les
## baies. C'est la seule façon d'obtenir une concavité : un contour bruité sait
## faire des criques d'une dizaine de cases, pas une baie d'un kilomètre.
const ILES_SECOURS := [
	{
		"nom": "Île Centrale", "c": [505, 522], "r": [142, 137], "bruit": 15.0,
		"lobes": [
			[0.0, 0.40, 0.70, 0.66], [45.0, 0.44, 0.62, 0.68],
			[90.0, 0.38, 0.68, 0.62], [135.0, 0.43, 0.66, 0.70],
			[180.0, 0.40, 0.72, 0.64], [225.0, 0.45, 0.60, 0.66],
			[270.0, 0.39, 0.67, 0.68], [315.0, 0.42, 0.64, 0.63],
		],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Île Nord", "c": [500, 250], "r": [128, 104], "bruit": 13.0,
		"lobes": [
			[10.0, 0.42, 0.66, 0.70], [62.0, 0.40, 0.70, 0.64],
			[118.0, 0.44, 0.62, 0.68], [168.0, 0.41, 0.68, 0.66],
			[212.0, 0.43, 0.64, 0.70], [258.0, 0.39, 0.70, 0.62],
			[308.0, 0.42, 0.66, 0.67],
		],
		## Port-Nord à l'ouest (la presqu'île aux bassins) et le Sommet au
		## nord-est (le promontoire du belvédère).
		"caps": [[-112, -10, 30, 19], [104, -58, 26, 22]],
		## La Baie du Sud : l'échancrure du sud de l'île.
		"golfes": [[6, 104, 36, 32]],
	},
	{
		"nom": "Île Sud-Est", "c": [764, 690], "r": [150, 126], "bruit": 16.0,
		"lobes": [
			[5.0, 0.43, 0.68, 0.66], [52.0, 0.40, 0.64, 0.70],
			[104.0, 0.44, 0.70, 0.62], [152.0, 0.39, 0.66, 0.68],
			[198.0, 0.42, 0.62, 0.66], [248.0, 0.45, 0.68, 0.64],
			[296.0, 0.40, 0.65, 0.70], [340.0, 0.43, 0.70, 0.65],
		],
		## La presqu'île du port (Gare Maritime) à l'ouest, la Pointe de l'Aube
		## au nord-est.
		"caps": [[-136, -8, 34, 28], [136, -86, 28, 22]],
		## L'anse de Plage-des-Vents : la grande baie sableuse du sud.
		"golfes": [[-4, 124, 56, 36]],
	},
	## LE CHAPELET. Les petites îles de la carte d'ensemble, dans le sens des
	## aiguilles depuis l'ouest. Trois à cinq lobes chacune : la règle « aucun
	## lobe ne domine » ne souffre pas d'exception, et c'est sur un îlot de
	## vingt cases qu'un rectangle se voit le plus.
	{
		"nom": "Île de l'Ouest", "c": [115, 411], "r": [78, 112], "bruit": 11.0,
		## Une île ALLONGÉE NORD-OUEST / SUD-EST : ses lobes sont posés le long
		## d'un axe, pas sur un anneau. C'est la seule de l'archipel dans ce cas,
		## et c'est ce que la carte d'ensemble montre.
		"lobes": [
			[300.0, 0.62, 0.42, 0.40], [305.0, 0.22, 0.46, 0.44],
			[120.0, 0.24, 0.44, 0.46], [125.0, 0.64, 0.40, 0.42],
		],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Île aux Brumes", "c": [300, 375], "r": [28, 24], "bruit": 5.0,
		"lobes": [[20.0, 0.38, 0.66, 0.70], [140.0, 0.40, 0.70, 0.64],
			[260.0, 0.36, 0.64, 0.68]],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Îlot du Large", "c": [234, 534], "r": [21, 18], "bruit": 4.0,
		"lobes": [[50.0, 0.34, 0.70, 0.66], [190.0, 0.36, 0.64, 0.70],
			[300.0, 0.32, 0.68, 0.64]],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Île des Pins", "c": [274, 743], "r": [46, 72], "bruit": 8.0,
		"lobes": [[280.0, 0.48, 0.52, 0.48], [300.0, 0.10, 0.56, 0.50],
			[100.0, 0.22, 0.50, 0.52], [95.0, 0.56, 0.46, 0.46]],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Île de la Baie", "c": [717, 327], "r": [32, 27], "bruit": 6.0,
		"lobes": [[10.0, 0.36, 0.68, 0.66], [130.0, 0.38, 0.64, 0.70],
			[250.0, 0.34, 0.70, 0.64]],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Île du Levant", "c": [915, 430], "r": [28, 24], "bruit": 5.0,
		"lobes": [[40.0, 0.36, 0.66, 0.68], [160.0, 0.34, 0.70, 0.64],
			[280.0, 0.38, 0.64, 0.70]],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Île de la Côte", "c": [806, 543], "r": [23, 19], "bruit": 4.0,
		"lobes": [[70.0, 0.34, 0.68, 0.66], [200.0, 0.36, 0.64, 0.70],
			[320.0, 0.32, 0.70, 0.64]],
		"caps": [], "golfes": [],
	},
	{
		"nom": "Île de la Côte du Levant", "c": [958, 661], "r": [23, 20],
		"bruit": 4.0,
		"lobes": [[100.0, 0.34, 0.66, 0.68], [230.0, 0.36, 0.70, 0.64],
			[350.0, 0.32, 0.64, 0.70]],
		"caps": [], "golfes": [],
	},
]

## LE BRUIT DE CÔTE. La fréquence donne des criques d'environ soixante cases
## (1,2 km) ; la DÉFORMATION (domain warp) les replie en anses et en pointes —
## c'est elle qui fait la différence entre une côte qui ONDULE et une côte qui
## RENTRE. Sans elle, toutes les îles ressemblent à des galets.
const COTE_FREQ := 0.016
const COTE_OCTAVES := 4
const WARP_AMPLI := 22.0
const WARP_FREQ := 0.012

## Au-delà de cette distance, plus aucun lobe ne compte : c'est le large.
## L'index par secteur s'en sert pour n'interroger qu'une poignée de lobes par
## case au lieu des cinquante de l'archipel — sans quoi l'image de mille sur
## mille demanderait des minutes.
const PORTEE_LOBE := 90.0
const COTE_SECTEUR := 32

## ⭐ LES DIX ÎLES, DANS L'ORDRE DU FICHIER DU CLIENT. Écrites une fois : une
## ligne de train qui va « à l'île 8 » est illisible et devient fausse à la
## première insertion dans la table. `batir()` VÉRIFIE que le fichier est bien
## dans cet ordre et hurle sinon — un décalage d'un cran mettrait toutes les
## villes sur les mauvaises îles, et rien sur l'image ne le dirait.
const CENTRALE := 0
const NORD := 1
const SUDEST := 2
const ILE_OUEST := 3
const ILE_BRUMES := 4
const ILOT_LARGE := 5
const ILE_PINS := 6
const ILE_BAIE := 7
const ILE_LEVANT := 8
const ILE_COTE := 9
## L'ordre attendu, par identifiant du fichier.
const ORDRE_ILES := ["ile_centrale", "ile_nord", "ile_sud_est", "ile_ouest",
	"ile_brumes", "ilot_large", "ile_pins", "ile_baie", "ile_levant", "ile_cote"]

# ------------------------------------------------------------------ le relief

## LE RELIEF. Une plaine côtière, des collines, et les sommets NOMMÉS par le
## client : le Mont Aurélien et le Sommet sur l'Île Nord, le Mont des Brises et
## la Colline de l'Est sur l'Île Sud-Est. L'Île Centrale, elle, est urbaine et
## reste basse — c'est ce que montre sa carte de détail, et c'est aussi ce qu'il
## faut pour qu'un plan radioconcentrique soit conduisible.
const P_PLAINE := 2.0                ## paliers gagnés par la plaine côtière
const LARGEUR_PLAINE := 45.0         ## en cases, pour les gagner
const P_COLLINES := 3.5
const COLLINE_FREQ := 0.018
const P_MAX := 26.0                  ## 130 m : le toit de l'archipel

## [x, y, rayon en cases, hauteur en paliers, nom]. La hauteur est celle du
## sommet AU-DESSUS du terrain naturel.
##
## ⚠ LA PENTE EST LE CALCUL QUI COMPTE, PAS LA HAUTEUR. Un mont de 18 paliers
## sur 62 cases de rayon, avec l'exposant 1,8, monte au plus fort de
## 18 × 1,8 / 62 ≈ 0,52 palier par case. Avec les collines (0,12) et la plaine
## (0,04), on reste à 0,7 — sous les deux paliers que le kit sait paver. C'est
## ce calcul-là qui remplace les six passes de rabotage.
## ⚠ EN FRACTIONS DU RAYON DE LEUR ÎLE, ET PLUS EN CASES ABSOLUES. Le fichier
## du client donne les centres et les rayons ; le jour où il bouge une île de
## trois cents mètres ou en change le rayon, ses montagnes doivent suivre — pas
## rester en mer. [île, dx, dy, rayon, hauteur en paliers, nom], dx/dy/rayon en
## parts du rayon de l'île.
const MONTS_F := [
	[NORD, 0.05, -0.66, 0.55, 18.0, "Mont Aurélien"],
	[NORD, 0.70, -0.42, 0.38, 13.0, "Sommet"],
	[SUDEST, -0.10, -0.62, 0.48, 15.0, "Mont des Brises"],
	[SUDEST, 0.55, -0.08, 0.42, 11.0, "Colline de l'Est"],
	[ILE_OUEST, 0.0, -0.20, 0.60, 12.0, "Hauts de l'Ouest"],
	[ILE_PINS, -0.10, -0.30, 0.45, 8.0, "Crête des Pins"],
]

## LES PLAINES URBAINES : [x, y, rayon, palier]. Le terrain y est ramené à un
## palier constant, en fondu sur `MARGE_URBAINE` cases.
##
## ⚠ C'EST LA CONDITION DU PLAN RADIOCONCENTRIQUE. Huit radiales et deux
## anneaux sur un relief bosselé, ce sont des dizaines de marches en travers de
## la chaussée, et le kit ne sait pas paver une rue qui monte sous un carrefour.
## Le cahier disait déjà la même chose autrement : « les quartiers bâtis sont
## sur des plateaux plats, le relief se franchit ENTRE eux ».
const MARGE_URBAINE := 34.0
## ⚠ ANCRÉES SUR UNE STATION DU FICHIER, et plus sur un point relevé à l'œil.
## Une ville est plate AUTOUR DE SA GARE : c'est la gare qui a une position
## canonique, pas le centre géométrique du quartier. [nom de station, île de
## référence pour le rayon, rayon en parts du rayon de l'île, palier].
const PLAINES_F := [
	["Gare Centrale", CENTRALE, 0.95, 0],     ## l'Île Centrale entière est plate
	["Centre-Ville Nord", NORD, 0.70, 1],
	["Centre Sud-Est", SUDEST, 0.52, 1],
	["Gare Maritime", SUDEST, 0.34, 0],       ## la presqu'île du port
	["Plage-des-Vents", SUDEST, 0.40, 0],
]

## Le fond de la mer. Mêmes cotes que la carte du 14/09 : elles ont été réglées
## contre l'œil du client et il n'y a pas de raison de les rejouer.
##
## ⚠⚠ DANS CE MODÈLE, UNE CASE D'EAU N'EST PAS UNE CASE SANS ALTITUDE. `eau[k]`
## dit qu'il y a de l'eau, `altitude[k]` dit où est LE FOND, et rien ne vérifie
## que le fond est sous la surface. Une session a passé une journée sur une mer
## invisible parce que son fond était à −0,40 quand la surface est à −2,85.
## CREUSE TES FONDS.
const PREMIER_FOND := -1.2
const PENTE_FOND := -1.9
const FOND_MAX := -11.0
## L'estran : les deux dernières cases de terre descendent à la rencontre de
## l'eau, et elles seules. Plus loin, un sol qui penche fait flotter ce qu'on y
## pose.
const ESTRAN := [-1.1, -0.35]

# ══════════════════════════════════════════════════════════════════ LES VILLES

## ⭐ L'ÎLE CENTRALE, RADIOCONCENTRIQUE STRICTE. C'est le point le plus
## caractéristique de toute la carte et le seul que le client ait dessiné au
## détail : « 2 anneaux primaires + 8 radiales » partant de la Gare Centrale,
## au centre exact, plus des anneaux secondaires et une trame locale.
##
## Les rayons sont donnés en CASES, relevés sur la carte de détail en parts du
## rayon de l'île (137 cases pour 5,5 km de diamètre).
## ⚠ EN PARTS DU RAYON DE L'ÎLE, ET PLUS EN CASES. Le fichier du client donne
## 2,75 km de rayon, soit 137,5 cases ; l'ancienne table disait 137 et se serait
## tue le jour où le rayon change. Une ville radioconcentrique se décrit en
## proportions — c'est d'ailleurs comme ça qu'elle a été dessinée.
const C_ANNEAUX_PRIMAIRES := [0.41, 0.81]
const C_ANNEAUX_SECONDAIRES := [0.25, 0.61, 0.86]
const C_ANNEAUX_LOCAUX := [0.51, 0.71]
const C_RADIALES := 8
const C_SOUS_RADIALES := 8           ## à 22,5°, la trame locale
## ⚠ 0,87 ET NON 0,97 : LE BOUT D'UNE RADIALE DOIT ÊTRE À TERRE À COUP SÛR.
## Le rayon de terre garanti est l'enveloppe moins l'amplitude du bruit, soit
## 0,89 du rayon canonique pour l'Île Centrale. Une radiale poussée jusqu'au
## rayon plein finissait dans l'eau une fois sur deux — et une route dans l'eau
## ne se rastérise pas : elle DISPARAÎT, sans un mot.
const C_RAYON_VILLE := 0.87

## L'ÎLE NORD : le même principe, mais un seul anneau — « Centre-Ville Nord
## radioconcentrique lui aussi mais plus petit ».
const N_ANNEAU := 0.55
const N_ANNEAU_SECONDAIRE := 0.32
const N_RADIALES := 8
const N_RAYON_VILLE := 0.67

## L'ÎLE SUD-EST n'est PAS radioconcentrique : sa carte montre une toile —
## un axe port → centre → Pointe de l'Aube, une ceinture autour du centre, et
## des branches vers la plage et la côte est.
const S_CEINTURE := 0.38

## ⚠⚠ LES STATIONS NE SONT PLUS ICI : ELLES VIENNENT DU FICHIER. Les dix-huit
## gares, haltes et stations de l'archipel ont une position canonique dans
## `archipel_complet.json`, au mètre près, et c'est elle qui fait foi.
##
## CE QUI RESTE ICI, CE SONT LES LIEUX-DITS : les noms que le client a écrits
## sur ses dessins SANS QU'ILS SOIENT DES STATIONS — le Mont Aurélien, la Vallée
## Verte, la Baie du Sud, la Pointe de l'Aube, la Colline de l'Est, la Vallée
## des Pins, le Mont des Brises. Le fichier ne les connaît pas (il ne décrit que
## du transport) et ils ont pourtant un rôle : ce sont les DESTINATIONS des
## routes et des lignes de bus. Une route qui va « vers la Vallée Verte » se
## comprend ; une route qui va vers la case (450, 320), non.
##
## ⚠ EN PARTS DU RAYON DE L'ÎLE, et jamais au-delà de 0,80 : un lieu-dit sert de
## bout de route, donc il doit être À TERRE, et le contour bruité ne garantit la
## terre que bien en deçà du rayon nominal.
const LIEUX_DITS := [
	## [île, dx, dy, nom]
	[NORD, 0.05, -0.66, "Mont Aurélien"],
	[NORD, -0.45, 0.54, "Vallée Verte"],
	## ⚠ SUR LA RIVE DE LA BAIE, PAS DEDANS. La Baie du Sud est un GOLFE — donc
	## de l'eau (voir `GOLFES_F`) — et c'est en même temps le terminus d'une
	## route et d'une ligne de bus. Le lieu-dit est donc posé sur son rivage
	## nord, assez haut pour que le bruit du golfe ne vienne pas le noyer.
	[NORD, 0.05, 0.54, "Baie du Sud"],
	[SUDEST, -0.10, -0.62, "Mont des Brises"],
	[SUDEST, 0.60, -0.46, "Pointe de l'Aube"],
	[SUDEST, 0.55, -0.08, "Colline de l'Est"],
	[SUDEST, -0.29, 0.27, "Vallée des Pins"],
]

## LES GOLFES, en parts du rayon de l'île, par identifiant du fichier. Ce sont
## les deux baies que le client dessine et que le fichier ignore — il ne donne
## qu'un cercle. Un contour bruité sait faire une crique de dix cases, pas une
## baie d'un kilomètre : il faut la SOUSTRAIRE.
## [dx, dy, rx, ry] en parts du rayon.
const GOLFES_F := {
	"ile_nord": [[0.05, 0.98, 0.30, 0.30]],          ## la Baie du Sud
	"ile_sud_est": [[0.16, 1.02, 0.40, 0.26]],       ## l'anse de Plage-des-Vents
}

## LES SIX RÉSEAUX, dans l'ordre de la légende du client. L'ordre COMPTE : c'est
## celui du dessin sur l'image (le plus structurant par-dessus) et celui de la
## hiérarchie à coder.
const R_TRAIN := "train"
## ⚠ LE TRAIN SECONDAIRE N'A PLUS DE LIGNE. Je l'avais inventé — cinq dessertes
## orange vers le chapelet — d'après la légende de la carte d'ensemble. Le
## fichier canonique, lui, ne connaît que quatre lignes de train, T1 à T4, et
## elles desservent DÉJÀ tout le chapelet (T1 les Pins, T2 la Côte, T3 le Large
## et l'Ouest, T4 le Levant et la Baie). Le réseau reste déclaré — le client
## distingue bien deux rouges sur sa légende, et il faudra peut-être reclasser
## T3 et T4 en secondaires — mais AUCUNE LIGNE NE LE PORTE AUJOURD'HUI.
const R_TRAIN2 := "train2"
const R_METRO := "metro"
const R_TRAM := "tram"
const R_BUS := "bus"
## ⚠ ET LE SIXIÈME RÉSEAU, QU'ON AVAIT OUBLIÉ : LA MER. Voir plus bas.
const R_FERRY := "ferry"
## Et la voirie, qui a sa propre hiérarchie.
const V_PRIMAIRE := "primaire"
const V_SECONDAIRE := "secondaire"
const V_LOCALE := "locale"
const V_COTIER := "cotier"

## L'écart entre deux stations, par réseau, en cases. Un train s'arrête tous les
## trois kilomètres, un bus tous les quatre cents mètres : c'est ce rapport-là
## qui fait qu'on lit six réseaux et pas six fois le même.
const ECART_STATIONS := {
	R_TRAIN: 62, R_TRAIN2: 70, R_METRO: 34, R_TRAM: 22, R_BUS: 16,
	## ⚠ ZÉRO POUR LE FERRY, ET CE N'EST PAS UN OUBLI. Un bateau ne s'arrête pas
	## tous les huit cents mètres au milieu de l'eau : ses seules stations sont
	## ses embarcadères, posés à la main aux deux bouts de chaque ligne.
	R_FERRY: 0,
}

# ------------------------------------------------------------------ hérité

## CE QUI RESTE POUR L'ÉTAPE 4 (les quartiers). Rien ne s'en sert aujourd'hui —
## `implantations` est vide — mais `generateur_pays.gd` sait déjà les traiter,
## et les effacer obligerait à le défaire puis à le refaire.
const COTE_TEMOIN := 40
const RANGEES_PLAGE := 24
const FERME := Vector2i(12, 12)
const AERODROME := Vector2i(22, 52)

# ══════════════════════════════════════════════════════════════════ BÂTIR

## LE PLAN, DANS L'ORDRE IMPOSÉ PAR LE CLIENT : les côtes et le relief, puis
## les gares et les stations, puis les six réseaux, et RIEN d'autre pour
## l'instant.
static func batir(graine := 1) -> Dictionary:
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	var donnees := _lire(FICHIER_ARCHIPEL)
	var plan := {
		"version": 3,
		"nom": "Archipel des Aurones",
		"graine": graine,
		"taille": [TAILLE.x, TAILLE.y],
		## 1. les côtes et le relief.
		"iles": _les_iles(donnees, graine),
		"detroits": _les_detroits(donnees),
		"monts": [], "plaines": [],
		## 2. les gares et les stations — le squelette.
		"stations": [], "lieux_dits": [],
		## 3. les six réseaux. `lignes` porte le train, le métro, le tram, le bus
		##    et le ferry ; `routes` porte la voirie, qui est le sixième et le
		##    seul qui descende en 3D telle quelle.
		"lignes": [], "routes": [], "ponts": [],
		## 4. les quartiers : pas encore.
		"implantations": [],
	}
	_verifier_l_ordre(plan)
	# ⚠ LES REPÈRES AVANT LE RELIEF, ET LE RELIEF AVANT LE CONTEXTE. Les plaines
	# urbaines sont ancrées sur des GARES (voir `PLAINES_F`) : il faut donc les
	# stations d'abord. Et `contexte()` déplie les monts et les plaines : il faut
	# donc le relief avant lui. Trois lignes dans le désordre, et la capitale se
	# retrouve bâtie sur une colline.
	_les_reperes(plan, donnees)
	plan["monts"] = _les_monts(plan)
	plan["plaines"] = _les_plaines(plan)
	var ctx := contexte(plan)
	_la_voirie(plan, ctx, alea)
	_le_graphe_routier(plan, ctx, alea)
	_les_reseaux(plan, ctx, alea, donnees)
	_les_voies_maritimes(plan, ctx, alea)
	_les_ponts_du_fichier(plan, donnees)
	_les_stations(plan, ctx)
	_recenser_les_ponts(plan, ctx)
	return plan

# ------------------------------------------------------------------ le fichier

## LA LECTURE D'UN FICHIER DE DONNÉES. Elle ne lève jamais : un fichier absent
## rend un dictionnaire vide, et chaque appelant a son repli.
##
## ⚠ `res://` ET RIEN D'AUTRE. Au navigateur, le projet exporté est un paquet :
## il n'y a pas de système de fichiers, et un chemin absolu du bureau n'existe
## pas. `FileAccess.open("res://…")` lit dans le paquet, partout.
static func _lire(chemin: String) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		push_warning("données de l'archipel absentes : " + chemin)
		return {}
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		push_warning("données de l'archipel illisibles : " + chemin)
		return {}
	var brut = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) != TYPE_DICTIONARY:
		push_warning("données de l'archipel mal formées : " + chemin)
		return {}
	return brut

## Un point du fichier (en kilomètres) en case de la carte.
static func _point(p: Dictionary) -> Vector2i:
	return Vector2i(roundi(float(p["x"]) * KM), roundi(float(p["y"]) * KM))

## ⚠ L'ORDRE DES ÎLES EST UN CONTRAT. `CENTRALE`, `NORD`, `SUDEST` et le
## chapelet sont des INDICES : un fichier qui change l'ordre de ses îles mettrait
## la capitale sur un îlot de onze hectares, et rien sur l'image ne le dirait —
## on verrait un archipel plausible, avec les villes aux mauvais endroits.
static func _verifier_l_ordre(plan: Dictionary) -> void:
	var iles: Array = plan["iles"]
	for k in ORDRE_ILES.size():
		if k >= iles.size():
			push_warning("archipel : il manque l'île « %s »" % String(ORDRE_ILES[k]))
			return
		var id := String((iles[k] as Dictionary).get("id", ""))
		if id != "" and id != String(ORDRE_ILES[k]):
			push_warning("archipel : l'île %d est « %s », on attendait « %s » — "
				% [k, id, String(ORDRE_ILES[k])]
				+ "les villes vont se poser sur les mauvaises îles")
			return

# ------------------------------------------------------------------ les îles

## ⭐ LES ÎLES : LE FICHIER DONNE UN CERCLE, ON EN FAIT UNE CÔTE.
##
## Le repli sur `ILES_SECOURS` n'est pas une politesse : sans lui, un fichier de
## données absent ferait planter la génération du plan, donc l'éditeur, donc le
## jeu. On ne casse pas un générateur pour un fichier de données.
static func _les_iles(donnees: Dictionary, graine: int) -> Array:
	if not donnees.has("islands"):
		push_warning("archipel : pas d'îles dans le fichier, repli sur le relevé au pixel")
		return ILES_SECOURS.duplicate(true)
	var sortie: Array = []
	var index := 0
	for cle in donnees["islands"]:
		sortie.append(_ile_depuis(donnees["islands"][cle], String(cle), index, graine))
		index += 1
	return sortie

## ⭐ UNE ÎLE, DU CERCLE DU FICHIER À LA CÔTE DESSINÉE. Trois règles, et les
## trois se paient si on les oublie :
##
## 1. L'ENVELOPPE TIENT DANS LE RAYON DONNÉ. Le bruit déplace le trait de ±
##    `bruit` cases : on dessine donc les lobes à `util = rayon − bruit`, et le
##    trait bruité revient exactement au rayon. L'Île Centrale faisait 6,92 km
##    au lieu de 5,5 — c'est ce calcul-là qui manquait.
## 2. AUCUN LOBE NE DOMINE. Leçon payée trois fois (Pikstown, le lac du parc,
##    l'archipel du 14/09) : une grande ellipse plus des petites bosses reste une
##    grande ellipse. Quatre à huit lobes COMPARABLES sur un anneau, et le
##    contour cesse d'avoir un centre.
## 3. ⭐ LA CÔTE CONTIENT SES STATIONS. Le fichier place les gares ; le contour,
##    lui, est bruité. Une gare posée à 0,96 du rayon nominal tombe à l'eau une
##    fois sur deux — et une gare en mer ne se voit pas sur une image de mille
##    pixels, elle se découvre trois semaines plus tard. Toute station éloignée
##    reçoit donc SON PROPRE LOBE, assez large pour que le bruit ne puisse pas
##    l'engloutir. C'est aussi ce qui dessine les presqu'îles nommées — Port-Nord,
##    le Sommet, la Gare Maritime, Plage-des-Vents — sans avoir à les relever.
static func _ile_depuis(brut, cle: String, index: int, graine: int) -> Dictionary:
	var src: Dictionary = brut
	var c := _point(src["center"])
	var r := float(src["radius_km"]) * KM
	# L'amplitude du bruit : onze pour cent du rayon, bornée. Une grande île
	# supporte seize cases de morsure ; un îlot de vingt-sept cases n'en supporte
	# que trois, sinon le bruit ne le découpe pas, il l'efface.
	var bruit := clampf(r * float(PART_BRUIT.get(cle, PART_BRUIT_DEFAUT)), 3.0, 16.0)
	var util := r - bruit * MARGE_ENVELOPPE
	var part := util / maxf(r, 1.0)
	var alea := RandomNumberGenerator.new()
	alea.seed = graine * 7919 + index * 131
	var n := 8 if r >= 90.0 else (6 if r >= 50.0 else 4)
	var lobes: Array = []
	for k in n:
		lobes.append([
			360.0 * float(k) / float(n) + alea.randf_range(-14.0, 14.0),
			0.40 * part * alea.randf_range(0.90, 1.10),
			0.60 * part * alea.randf_range(0.88, 1.12),
			0.60 * part * alea.randf_range(0.88, 1.12),
		])
	# LES LOBES DE STATION (règle 3). En cases absolues relatives au centre.
	var caps: Array = []
	for s in src.get("stations", []):
		var fs: Dictionary = s
		var p := _point(fs["pos"]) - c
		var d := Vector2(p).length()
		if d <= 0.62 * util: continue
		# Assez large pour que le bruit ne mange pas la station ; pas plus large
		# que ce que l'enveloppe autorise.
		# Assez large pour que le bruit du lobe (réduit, voir `PART_BRUIT_CAP`) ne
		# puisse pas noyer la station ; jamais plus large que ce que l'enveloppe
		# autorise, pour que l'île garde son rayon.
		var mini := bruit * PART_BRUIT_CAP + 6.0
		var large := clampf(0.22 * r, mini, maxf(util - d, mini))
		caps.append([p.x, p.y, large, large])
	var golfes: Array = []
	for g in GOLFES_F.get(cle, []):
		var fg: Array = g
		golfes.append([float(fg[0]) * r, float(fg[1]) * r, float(fg[2]) * r,
			float(fg[3]) * r])
	return {
		"id": cle, "nom": String(src.get("name", cle)),
		"c": [c.x, c.y], "r": [r, r], "bruit": bruit,
		"lobes": lobes, "caps": caps, "golfes": golfes,
	}

# ------------------------------------------------------------------ le relief

static func _les_monts(plan: Dictionary) -> Array:
	var sortie: Array = []
	for e in MONTS_F:
		var f: Array = e
		var k := int(f[0])
		if k >= (plan["iles"] as Array).size(): continue
		var c := centre_ile(plan, k)
		var r := rayon_ile(plan, k)
		sortie.append([c.x + roundi(float(f[1]) * r.x), c.y + roundi(float(f[2]) * r.y),
			roundi(float(f[3]) * r.x), float(f[4]), String(f[5])])
	return sortie

static func _les_plaines(plan: Dictionary) -> Array:
	var sortie: Array = []
	for e in PLAINES_F:
		var f: Array = e
		var c := repere(plan, String(f[0]))
		if c.x < 0: continue
		var r := rayon_ile(plan, int(f[1]))
		sortie.append([c.x, c.y, roundi(float(f[2]) * r.x), int(f[3])])
	return sortie

# ══════════════════════════════════════════════════════════════════ CONTEXTE

## LE PLAN DÉPLIÉ — ce qui coûte trop cher à ranger dans un fichier et trop cher
## à recalculer par case. À bâtir une fois, à garder, à passer partout.
##
## ⚠ RIEN ICI N'EST UNE DÉCISION. Deux contextes bâtis sur le même plan sont
## identiques, case pour case. Si un jour quelque chose se décide ici — un
## tirage, un curseur — la garantie de raccord des fenêtres tombe le même jour.
static func contexte(plan: Dictionary) -> Dictionary:
	var ctx := {}
	var lobes: Array = []
	var golfes: Array = []
	for e in plan["iles"]:
		var ile: Dictionary = e
		var c := case_de(ile["c"])
		var r: Array = ile["r"]
		var rx := float(r[0])
		var rz := float(r[1])
		var amp := float(ile.get("bruit", 12.0))
		for l in ile["lobes"]:
			var f: Array = l
			var a := deg_to_rad(float(f[0]))
			var d := float(f[1])
			lobes.append(_lobe(float(c.x) + cos(a) * rx * d, float(c.y) + sin(a) * rz * d,
				rx * float(f[2]), rz * float(f[3]), amp))
		for p in ile.get("caps", []):
			var g: Array = p
			# ⚠ UN LOBE DE STATION EST PEU BRUITÉ, ET C'EST UN CALCUL, PAS UN
			# GOÛT. Il doit tenir deux promesses contradictoires : contenir sa
			# gare quoi que fasse le bruit, et ne pas faire déborder l'île de son
			# rayon canonique. Avec un bruit plein, Port-des-Alpes — à 117 cases
			# du centre pour un rayon de 137 — aurait exigé un lobe si large que
			# l'Île Centrale aurait repassé les 5,5 km qu'on vient de lui rendre.
			# À 0,35 du bruit de l'île, les deux tiennent : voir `PART_BRUIT_CAP`.
			lobes.append(_lobe(float(c.x) + float(g[0]), float(c.y) + float(g[1]),
				float(g[2]), float(g[3]), amp * PART_BRUIT_CAP))
		for p2 in ile.get("golfes", []):
			var g2: Array = p2
			golfes.append(_lobe(float(c.x) + float(g2[0]), float(c.y) + float(g2[1]),
				float(g2[2]), float(g2[3]), amp * 0.7))
	# ⚠⚠ LES DÉTROITS SONT DES GOLFES, ET C'EST POUR ÇA QU'ILS ARRIVENT ICI. Un
	# chenal entre deux îles, c'est de la terre qu'on RETIRE des deux rives à la
	# fois : exactement un lobe soustrait, posé à cheval. Voir `_les_detroits`.
	for t in plan.get("detroits", []):
		var ft: Array = t
		golfes.append(_lobe(float(ft[0]), float(ft[1]), float(ft[2]), float(ft[3]),
			float(ft[4])))
	ctx["lobes"] = lobes
	ctx["golfes"] = golfes
	ctx["secteurs"] = _indexer_les_lobes(lobes)

	var g3 := int(plan["graine"])
	var cote := FastNoiseLite.new()
	cote.seed = g3
	cote.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cote.frequency = COTE_FREQ
	cote.fractal_type = FastNoiseLite.FRACTAL_FBM
	cote.fractal_octaves = COTE_OCTAVES
	# LA DÉFORMATION, et c'est elle qui fait les anses et les pointes.
	cote.domain_warp_enabled = true
	cote.domain_warp_amplitude = WARP_AMPLI
	cote.domain_warp_frequency = WARP_FREQ
	ctx["cote"] = cote

	var colline := FastNoiseLite.new()
	colline.seed = g3 + 977
	colline.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	colline.frequency = COLLINE_FREQ
	colline.fractal_type = FastNoiseLite.FRACTAL_FBM
	colline.fractal_octaves = 3
	ctx["colline"] = colline

	ctx["monts"] = plan["monts"]
	ctx["plaines"] = plan["plaines"]
	# ⚠ LES DEUX TABLES D'EAU DOUCE RESTENT, VIDES. La carte du client ne montre
	# ni fleuve ni lac — l'archipel est une géographie maritime. Le mécanisme
	# reste en place (il ne coûte qu'un `has()` par case) parce que la Vallée
	# Verte et la Vallée des Pins réclameront un ruisseau, et parce que la règle
	# qui les gouverne est celle qu'on oublie toujours : dans ce moteur,
	# `TerrainV2.maillage_eau` pose TOUTE nappe à `NIVEAU_MER`, donc une eau
	# douce au-dessus du niveau de la mer est impossible tant qu'on n'aura pas
	# une cote par pièce d'eau.
	ctx["lit"] = {}
	ctx["lacs"] = {}
	ctx["plateaux"] = {}
	var impl: Array = plan["implantations"]
	for k in impl.size():
		var d2: Dictionary = impl[k]
		var z := emprise_plateau(d2)
		for j in range(z.position.y, z.end.y):
			for i in range(z.position.x, z.end.x):
				ctx["plateaux"][Vector2i(i, j)] = int(d2["p"])
	return ctx

static func _lobe(x: float, z: float, rx: float, rz: float, amp: float) -> Dictionary:
	return {"x": x, "z": z, "rx": maxf(rx, 1.0), "rz": maxf(rz, 1.0),
		"r": (maxf(rx, 1.0) + maxf(rz, 1.0)) * 0.5, "amp": amp}

## L'INDEX DES LOBES PAR SECTEUR. Sans lui, chaque case interroge les cinquante
## lobes de l'archipel : cinquante millions d'appels pour une image de mille sur
## mille, c'est-à-dire des minutes. Avec lui, une case de pleine terre en voit
## une poignée et une case de large aucun — et « aucun lobe » est une réponse en
## soi : c'est le large, fond maximal, rien à calculer.
static func _indexer_les_lobes(lobes: Array) -> Dictionary:
	var index: Dictionary = {}
	for k in lobes.size():
		var f: Dictionary = lobes[k]
		var x0 := int(floor((float(f["x"]) - float(f["rx"]) - PORTEE_LOBE) / float(COTE_SECTEUR)))
		var x1 := int(floor((float(f["x"]) + float(f["rx"]) + PORTEE_LOBE) / float(COTE_SECTEUR)))
		var z0 := int(floor((float(f["z"]) - float(f["rz"]) - PORTEE_LOBE) / float(COTE_SECTEUR)))
		var z1 := int(floor((float(f["z"]) + float(f["rz"]) + PORTEE_LOBE) / float(COTE_SECTEUR)))
		for sz in range(z0, z1 + 1):
			for sx in range(x0, x1 + 1):
				var cle := Vector2i(sx, sz)
				if not index.has(cle): index[cle] = []
				(index[cle] as Array).append(k)
	return index

# ══════════════════════════════════════════════════════════════════ LE SOL

## ⭐ LA DISTANCE SIGNÉE À LA CÔTE, EN CASES. Négative à terre, positive en mer.
## C'est LA fonction du fichier : le trait de côte en est le zéro, la profondeur
## de l'eau une fonction affine, l'altitude du relief aussi. Elle ne regarde
## aucune voisine, donc elle est la même quelle que soit la fenêtre.
##
## La distance d'une UNION de formes, c'est le MINIMUM des distances ; celle
## d'une SOUSTRACTION, le maximum avec l'opposé. Les golfes sont donc retirés
## après coup, et le bruit s'applique aux deux — sans quoi la baie serait une
## ellipse parfaite au milieu d'une côte découpée, et ça se verrait de très loin.
##
## ⚠ LA DISTANCE EST EN CASES, PAS EN CHAMP SANS UNITÉ. `generateur_carte`
## testait `1 − (dx/rx)² − (dz/rz)² > 0` : un champ dont la pente dépend du rayon
## de l'ellipse, si bien que le même bruit découpe à peine un continent et
## efface un îlot. Ici, `(distance elliptique − 1) × rayon moyen` rend des
## cases, comparables d'un lobe à l'autre — c'est ce qui permet de donner seize
## cases de morsure à l'Île Sud-Est et quatre à l'Îlot du Large.
static func distance_signee(plan: Dictionary, ctx: Dictionary, i: int, j: int) -> float:
	var secteurs: Dictionary = ctx["secteurs"]
	var cle := Vector2i(int(floor(float(i) / float(COTE_SECTEUR))),
		int(floor(float(j) / float(COTE_SECTEUR))))
	if not secteurs.has(cle): return PORTEE_LOBE
	var lobes: Array = ctx["lobes"]
	var b: FastNoiseLite = ctx["cote"]
	var n := b.get_noise_2d(float(i), float(j))
	var d := PORTEE_LOBE
	for k in (secteurs[cle] as Array):
		var f: Dictionary = lobes[k]
		var dx := (float(i) - float(f["x"])) / float(f["rx"])
		var dz := (float(j) - float(f["z"])) / float(f["rz"])
		var e := (sqrt(dx * dx + dz * dz) - 1.0) * float(f["r"]) + n * float(f["amp"])
		d = minf(d, e)
	for g in ctx["golfes"]:
		var fg: Dictionary = g
		var gx := (float(i) - float(fg["x"])) / float(fg["rx"])
		var gz := (float(j) - float(fg["z"])) / float(fg["rz"])
		var dg := (sqrt(gx * gx + gz * gz) - 1.0) * float(fg["r"]) + n * float(fg["amp"])
		d = maxf(d, -dg)
	return d

## L'ALTITUDE DE LA TERRE, en unités 3D, à `inl` cases de la côte. La pente de
## chaque terme est bornée (voir `MONTS`) : c'est ce qui remplace les six passes
## de rabotage de l'ancienne carte.
static func _altitude_terre(plan: Dictionary, ctx: Dictionary, i: int, j: int,
		inl: float) -> float:
	var p := P_PLAINE * clampf(inl / LARGEUR_PLAINE, 0.0, 1.0)
	var b: FastNoiseLite = ctx["colline"]
	var col := b.get_noise_2d(float(i), float(j)) * 0.5 + 0.5
	p += P_COLLINES * col * clampf((inl - 8.0) / 40.0, 0.0, 1.0)
	for m in ctx["monts"]:
		var f: Array = m
		var dx := float(i) - float(f[0])
		var dz := float(j) - float(f[1])
		var r := float(f[2])
		var d := sqrt(dx * dx + dz * dz)
		if d >= r: continue
		p += float(f[3]) * pow(1.0 - d / r, 1.8)
	p = minf(p, P_MAX)
	# ⭐ L'APLANISSEMENT URBAIN, EN DERNIER. Il écrase tout ce qui précède, et
	# c'est tout son intérêt : une ville radioconcentrique se pose sur du plat.
	# Le fondu sur `MARGE_URBAINE` cases garantit qu'on n'y entre pas par une
	# falaise — 3 paliers sur 34 cases, c'est 0,09 palier par case.
	for u in ctx["plaines"]:
		var f2: Array = u
		var ux := float(i) - float(f2[0])
		var uz := float(j) - float(f2[1])
		var du := sqrt(ux * ux + uz * uz)
		var rr := float(f2[2])
		if du >= rr + MARGE_URBAINE: continue
		var t := clampf((rr + MARGE_URBAINE - du) / MARGE_URBAINE, 0.0, 1.0)
		# Lissage en cosinus : une interpolation linéaire laisse deux arêtes
		# franches, une à chaque bout du fondu, et le terrain en gradins les
		# transforme en deux anneaux de marches autour de chaque ville.
		t = 0.5 - 0.5 * cos(PI * t)
		p = lerpf(p, float(f2[3]), t)
	return roundf(p) * PALIER

## ⭐ LE SOL D'UNE CASE, ET IL N'Y A QUE CE CHEMIN-LÀ. L'image que le client
## valide et le remplissage des fenêtres 3D passent tous les deux par ici : il
## ne peut donc pas y avoir de désaccord entre ce qu'il regarde et ce qu'il
## traversera.
static func remplir_terrain(plan: Dictionary, ctx: Dictionary, v: Ville2,
		origine: Vector2i) -> void:
	var plateaux: Dictionary = ctx["plateaux"]
	var lacs: Dictionary = ctx["lacs"]
	var lit: Dictionary = ctx["lit"]
	for j in v.taille.y:
		for i in v.taille.x:
			var wi := origine.x + i
			var wj := origine.y + j
			var c := Vector2i(wi, wj)
			var k := j * v.taille.x + i
			# 1. LE PLATEAU D'UN QUARTIER (étape 4, vide aujourd'hui).
			if plateaux.has(c):
				v.eau[k] = 0
				v.altitude[k] = float(plateaux[c]) * PALIER
				v.matiere[k] = Ville2.M_HERBE
				continue
			var d := distance_signee(plan, ctx, wi, wj)
			if d <= 0.0 and lacs.has(c):
				v.eau[k] = 1
				v.altitude[k] = float(lacs[c])
				v.matiere[k] = Ville2.M_SABLE
				continue
			# 2. LA MER, ET SON FOND CREUSÉ.
			if d > 0.0:
				v.eau[k] = 1
				v.altitude[k] = maxf(FOND_MAX, PREMIER_FOND + d * PENTE_FOND)
				v.matiere[k] = Ville2.M_SABLE
				continue
			# 3. LA TERRE.
			var inl := -d
			var y := _altitude_terre(plan, ctx, wi, wj, inl)
			var creuse := 0.0
			if lit.has(c):
				creuse = float(lit[c])
				y -= creuse
			if creuse > 0.0 and y <= TerrainV2.NIVEAU_MER + 0.35:
				v.eau[k] = 1
				v.altitude[k] = minf(y, TerrainV2.NIVEAU_MER - 2.0)
				v.matiere[k] = Ville2.M_SABLE
				continue
			v.eau[k] = 0
			# L'ESTRAN : les deux dernières cases avant l'eau descendent à sa
			# rencontre, et seulement si elles sont déjà au niveau de la mer.
			# Une côte qui monte est une falaise, et une falaise ne se creuse pas.
			if inl <= float(ESTRAN.size()) and y <= 0.01 and creuse <= 0.0:
				var e: float = ESTRAN[clampi(int(ceil(inl)) - 1, 0, ESTRAN.size() - 1)]
				y = e
			v.altitude[k] = y
			# LA MATIÈRE SE DÉDUIT, elle ne se décore pas.
			if creuse > PALIER * 0.5:
				v.matiere[k] = Ville2.M_TERRE
			elif inl <= 2.5:
				v.matiere[k] = Ville2.M_SABLE
			elif y >= 11.0 * PALIER:
				v.matiere[k] = Ville2.M_ROCHE
			else:
				v.matiere[k] = Ville2.M_HERBE

## Le sol d'UNE case, pour qui n'a pas de `Ville2` sous la main — le tracé des
## chemins côtiers et le recensement des ponts. Rend [altitude, eau (0/1)].
static func sol_en(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> Array:
	var plateaux: Dictionary = ctx["plateaux"]
	if plateaux.has(c): return [float(plateaux[c]) * PALIER, 0.0]
	var d := distance_signee(plan, ctx, c.x, c.y)
	if d > 0.0:
		return [maxf(FOND_MAX, PREMIER_FOND + d * PENTE_FOND), 1.0]
	return [_altitude_terre(plan, ctx, c.x, c.y, -d), 0.0]

static func terre_en(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= TAILLE.x or c.y >= TAILLE.y: return false
	return distance_signee(plan, ctx, c.x, c.y) <= 0.0

static func palier_en(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> int:
	return roundi(float(sol_en(plan, ctx, c)[0]) / PALIER)

# ══════════════════════════════════════════════════════════════════ LES REPÈRES

## ⭐ LE SQUELETTE : LES DIX-HUIT STATIONS DU FICHIER, PUIS LES SEPT LIEUX-DITS.
##
## « Les gares et les stations fixent le squelette » (étape 2 du client), et
## elles sont posées AVANT tout réseau : chaque ligne ira ensuite de station en
## station, dans l'ordre que le fichier lui donne, au lieu d'aller d'un point
## deviné à un autre.
##
## Le `reseau` d'une station est le PREMIER de ses `types` — le fichier les
## classe par importance (train avant métro avant tram avant bus), et c'est
## celui-là qui décide de sa couleur sur la carte. Les correspondances ne sont
## pas perdues pour autant : `types` est recopié tel quel.
static func _les_reperes(plan: Dictionary, donnees: Dictionary) -> void:
	var trouvees := 0
	for cle in donnees.get("islands", {}):
		var ile: Dictionary = donnees["islands"][cle]
		for s in ile.get("stations", []):
			var f: Dictionary = s
			var c := _point(f["pos"])
			var types: Array = f.get("types", ["train"])
			plan["stations"].append({
				"nom": String(f["name"]), "id": String(f.get("id", "")),
				"c": [c.x, c.y], "reseau": String(types[0]) if types.size() > 0 else "train",
				"types": types, "ligne": "", "principale": true,
			})
			trouvees += 1
	if trouvees == 0:
		push_warning("archipel : aucune station dans le fichier — le squelette manque")
	# LES LIEUX-DITS : les noms du dessin qui ne sont pas des stations, et qui
	# servent de destination aux routes et aux lignes de bus.
	for e in LIEUX_DITS:
		var f2: Array = e
		var k := int(f2[0])
		if k >= (plan["iles"] as Array).size(): continue
		var c2 := centre_ile(plan, k)
		var r := rayon_ile(plan, k)
		plan["lieux_dits"].append({"nom": String(f2[3]),
			"c": [c2.x + roundi(float(f2[1]) * r.x), c2.y + roundi(float(f2[2]) * r.y)]})

## Le repère nommé `nom`, en cases : une station du fichier d'abord, un lieu-dit
## ensuite. Rend (-1, -1) s'il n'existe pas — un appelant qui se tromperait de nom
## poserait sa ligne au coin nord-ouest de la carte, et ça se verrait ; c'est
## voulu, une ligne fantôme doit sauter aux yeux.
static func repere(plan: Dictionary, nom: String) -> Vector2i:
	for s in plan["stations"]:
		var f: Dictionary = s
		if String(f["nom"]) == nom: return case_de(f["c"])
	for l in plan.get("lieux_dits", []):
		var f2: Dictionary = l
		if String(f2["nom"]) == nom: return case_de(f2["c"])
	push_warning("repère inconnu : " + nom)
	return Vector2i(-1, -1)

## La station portant cet identifiant de fichier (`gare_centrale`, `port_nord`…).
## C'est par l'IDENTIFIANT que les lignes désignent leurs arrêts, jamais par le
## nom : un nom s'affiche et se traduit, un identifiant est une clef.
static func station_id(plan: Dictionary, id: String) -> Vector2i:
	for s in plan["stations"]:
		var f: Dictionary = s
		if String(f.get("id", "")) == id: return case_de(f["c"])
	push_warning("station inconnue : " + id)
	return Vector2i(-1, -1)

static func centre_ile(plan: Dictionary, indice: int) -> Vector2i:
	var iles: Array = plan["iles"]
	return case_de((iles[indice] as Dictionary)["c"])

static func rayon_ile(plan: Dictionary, indice: int) -> Vector2:
	var iles: Array = plan["iles"]
	var r: Array = (iles[indice] as Dictionary)["r"]
	return Vector2(float(r[0]), float(r[1]))

# ══════════════════════════════════════════════════════════════════ LA VOIRIE

## ⭐ LA VOIRIE DES TROIS ÎLES. C'est l'étape 3 pour son réseau le plus lourd, et
## c'est là que se joue la ressemblance avec la carte du client : si l'Île
## Centrale ne se lit pas comme une cible, rien d'autre ne sauvera l'image.
static func _la_voirie(plan: Dictionary, ctx: Dictionary, alea: RandomNumberGenerator) -> void:
	_ile_centrale(plan, ctx, alea)
	_ile_nord(plan, ctx, alea)
	_ile_sudest(plan, ctx, alea)
	# LES CHEMINS CÔTIERS des trois grandes îles, plus ceux des deux plus
	# grosses petites. Le client les dessine en pointillé tout autour.
	for k in [CENTRALE, NORD, SUDEST, ILE_OUEST, ILE_PINS]:
		_chemin_cotier(plan, ctx, alea, int(k))

## ⭐ L'ÎLE CENTRALE : deux anneaux primaires, huit radiales, des anneaux
## secondaires, une trame locale. Tout passe par `trace.gd` — un anneau et une
## radiale oblique n'existent pas dans un kit qui ne pave que deux axes, il faut
## les approcher en ESCALIER, et un escalier raté se reconnaît de très loin.
##
## ⚠ LE NOMBRE DE MARCHES N'EST PAS UN DÉTAIL. Un anneau de 112 cases de rayon
## fait 700 cases de tour : à 32 marches, chaque marche fait 22 cases et l'œil
## lit un cercle ; à 120 marches, il lit un escalier de pixels ; à 12, un
## dodécagone. On vise une marche tous les quinze à vingt-cinq cases, donc un
## nombre de marches PROPORTIONNEL au rayon — d'où `_marches()`.
static func _ile_centrale(plan: Dictionary, ctx: Dictionary,
		alea: RandomNumberGenerator) -> void:
	var c := centre_ile(plan, CENTRALE)
	var r := rayon_ile(plan, CENTRALE)
	var forme := Vector2(1.0, r.y / r.x)      ## l'île est très légèrement ovale
	for k in C_ANNEAUX_PRIMAIRES.size():
		var ray := int(round(float(C_ANNEAUX_PRIMAIRES[k]) * r.x))
		_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE,
			"Anneau Primaire %d" % (k + 1),
			TRACE.anneau(c, Vector2(float(ray), float(ray) * forme.y),
				_marches(ray), alea, 0.045))
	for k2 in C_ANNEAUX_SECONDAIRES.size():
		var ray2 := int(round(float(C_ANNEAUX_SECONDAIRES[k2]) * r.x))
		_poser_route(plan, V_SECONDAIRE, Ville2.R_AVENUE,
			"Anneau Secondaire %d" % (k2 + 1),
			TRACE.anneau(c, Vector2(float(ray2), float(ray2) * forme.y),
				_marches(ray2), alea, 0.05))
	for k3 in C_ANNEAUX_LOCAUX.size():
		var ray3 := int(round(float(C_ANNEAUX_LOCAUX[k3]) * r.x))
		_poser_route(plan, V_LOCALE, Ville2.R_RUE, "Boulevard %d" % (k3 + 1),
			TRACE.anneau(c, Vector2(float(ray3), float(ray3) * forme.y),
				_marches(ray3), alea, 0.06))
	# LES HUIT RADIALES. Elles partent de la place de la Gare Centrale (rayon 10
	# : on ne fait pas converger huit avenues sur une seule case, ça ferait un
	# carrefour de huit branches que le kit ne sait pas paver) et vont jusqu'au
	# bord de la ville.
	var noms := ["Nord", "Nord-Est", "Est", "Sud-Est", "Sud", "Sud-Ouest",
		"Ouest", "Nord-Ouest"]
	for k4 in C_RADIALES:
		# −90° pour que la radiale 0 pointe au NORD : sur la carte du client,
		# c'est l'axe de la Cité Administrative, et c'est le repère de lecture.
		var a := -PI * 0.5 + TAU * float(k4) / float(C_RADIALES)
		_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE,
			"Radiale " + String(noms[k4]),
			TRACE.radiale(c, a, 10.0, C_RAYON_VILLE * r.x,
				Vector2(1.0, forme.y), 12, alea, 0.025))
	# LA TRAME LOCALE : huit demi-radiales à 22,5°, du premier anneau primaire au
	# bord. Elles ne touchent pas le centre — dans une ville radioconcentrique,
	# les rues de secteur naissent sur un anneau, pas sur la place.
	for k5 in C_SOUS_RADIALES:
		var a2 := -PI * 0.5 + TAU * (float(k5) + 0.5) / float(C_SOUS_RADIALES)
		_poser_route(plan, V_LOCALE, Ville2.R_RUE, "",
			TRACE.radiale(c, a2, float(C_ANNEAUX_PRIMAIRES[0]) * r.x,
				C_RAYON_VILLE * r.x - 4.0, Vector2(1.0, forme.y), 10, alea, 0.04))

## L'ÎLE NORD : un seul anneau et ses radiales, plus l'avenue principale
## est-ouest qui traverse l'île de Port-Nord au Sommet — c'est l'axe gris épais
## de la carte de détail, et c'est lui qui porte le train régional T1.
static func _ile_nord(plan: Dictionary, ctx: Dictionary,
		alea: RandomNumberGenerator) -> void:
	var v := repere(plan, "Centre-Ville Nord")
	if v.x < 0: return
	var r := rayon_ile(plan, NORD)
	var an := int(round(N_ANNEAU * r.x))
	var an2 := int(round(N_ANNEAU_SECONDAIRE * r.x))
	_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE, "Anneau du Centre-Ville Nord",
		TRACE.anneau(v, Vector2(float(an), float(an) * 0.92), _marches(an), alea, 0.05))
	_poser_route(plan, V_SECONDAIRE, Ville2.R_RUE, "Anneau Intérieur Nord",
		TRACE.anneau(v, Vector2(float(an2), float(an2) * 0.92), _marches(an2), alea, 0.06))
	for k in N_RADIALES:
		var a := -PI * 0.5 + TAU * float(k) / float(N_RADIALES)
		_poser_route(plan, V_SECONDAIRE, Ville2.R_AVENUE, "",
			TRACE.radiale(v, a, 8.0, N_RAYON_VILLE * r.x, Vector2(1.0, 0.92), 9, alea, 0.03))
	# L'AVENUE PRINCIPALE EST-OUEST, de Port-Nord au Sommet en passant par le
	# centre. Deux escaliers et non un seul : une avenue qui traverse une ville
	# doit PASSER PAR sa place, pas la frôler.
	_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE, "Avenue de Port-Nord",
		TRACE.escalier(repere(plan, "Port-Nord"), v, 7, alea, 5.0))
	_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE, "Avenue du Sommet",
		TRACE.escalier(v, repere(plan, "Sommet"), 7, alea, 6.0))
	# Les deux dessertes du sud : la Vallée Verte et la Baie du Sud.
	_poser_route(plan, V_SECONDAIRE, Ville2.R_RUE, "Route de la Vallée Verte",
		TRACE.escalier(v, repere(plan, "Vallée Verte"), 6, alea, 6.0))
	_poser_route(plan, V_SECONDAIRE, Ville2.R_RUE, "Route de la Baie du Sud",
		TRACE.escalier(v, repere(plan, "Baie du Sud"), 6, alea, 5.0))

## L'ÎLE SUD-EST : pas de radioconcentrique, une TOILE. Sa carte montre un axe
## port → centre → Pointe de l'Aube, une ceinture autour du centre, et des
## branches vers la plage et la côte est.
static func _ile_sudest(plan: Dictionary, ctx: Dictionary,
		alea: RandomNumberGenerator) -> void:
	var centre := repere(plan, "Centre Sud-Est")
	if centre.x < 0: return
	var rs := rayon_ile(plan, SUDEST)
	var ce := int(round(S_CEINTURE * rs.x))
	_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE, "Ceinture du Centre Sud-Est",
		TRACE.anneau(centre, Vector2(float(ce), float(ce) * 0.88),
			_marches(ce), alea, 0.06))
	var axes := [
		["Gare Maritime", V_PRIMAIRE, Ville2.R_AVENUE, "Avenue du Port", 8.0],
		["Pointe de l'Aube", V_PRIMAIRE, Ville2.R_AVENUE, "Route de l'Aube", 9.0],
		["Plage-des-Vents", V_PRIMAIRE, Ville2.R_AVENUE, "Avenue des Vents", 6.0],
		["Colline de l'Est", V_SECONDAIRE, Ville2.R_RUE, "Route de la Colline", 7.0],
		["Vallée des Pins", V_SECONDAIRE, Ville2.R_RUE, "Chemin des Pins", 6.0],
	]
	for e in axes:
		var f: Array = e
		_poser_route(plan, String(f[1]), String(f[2]), String(f[3]),
			TRACE.escalier(centre, repere(plan, String(f[0])), 7, alea, float(f[4])))
	# LA TRAME DU PORT : la carte montre un quartier en damier sur la presqu'île
	# de la Gare Maritime. Une grille, et c'est le seul endroit de l'archipel qui
	# en ait une — « grille au centre, organique ailleurs » (cahier § 5) vaut
	# aussi à l'échelle d'un archipel.
	var gm := repere(plan, "Gare Maritime")
	for k in range(-3, 4):
		_rue_a_terre(plan, ctx, Vector2i(gm.x - 34, gm.y + k * 11),
			Vector2i(gm.x + 26, gm.y + k * 11))
	for k2 in range(-3, 4):
		_rue_a_terre(plan, ctx, Vector2i(gm.x + k2 * 10, gm.y - 34),
			Vector2i(gm.x + k2 * 10, gm.y + 34))
	# LA TRAME DE PLAGE-DES-VENTS : le front de mer et ses rues perpendiculaires.
	var pv := repere(plan, "Plage-des-Vents")
	_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE, "Front de Mer",
		TRACE.escalier(pv + Vector2i(-56, -6), pv + Vector2i(56, -6), 8, alea, 4.0))
	for k3 in range(-4, 5):
		_rue_a_terre(plan, ctx, Vector2i(pv.x + k3 * 12, pv.y - 22),
			Vector2i(pv.x + k3 * 12, pv.y + 4))

## ⭐ LE GRAPHE ROUTIER DU FICHIER — le squelette que mes anneaux ne donnent pas.
##
## `road_graph.json` décrit vingt-neuf nœuds et trente-cinq arêtes : les liaisons
## entre gares, les quatre points cardinaux de l'anneau de la capitale, et
## surtout LES ENTRÉES ET SORTIES DE PONT. C'est ce qui manquait le plus : mes
## anneaux et mes radiales meublent l'intérieur des villes, mais rien ne menait
## aux ponts, et « une route qui ne mène nulle part » est le deuxième des
## interdits du cahier. Un pont sans route d'accès est pire : c'est un ouvrage
## qui ne sert à rien.
##
## ⚠ LES ARÊTES DE PONT SONT SAUTÉES ICI. Une travée doit être DROITE (le kit ne
## sait pas faire autrement, et une travée qui tourne n'a pas de pile où se
## poser) : elle est posée par `_les_ponts_du_fichier`, qui l'aligne sur son axe
## dominant. La poser deux fois, une fois droite et une fois en escalier, ferait
## deux chaussées décalées d'une case sur toute la longueur du pont.
static func _le_graphe_routier(plan: Dictionary, ctx: Dictionary,
		alea: RandomNumberGenerator) -> void:
	var g := _lire(FICHIER_ROUTES)
	if not g.has("nodes") or not g.has("edges"): return
	var noeuds: Dictionary = {}
	for n in g["nodes"]:
		var f: Dictionary = n
		noeuds[String(f["id"])] = _point(f["pos"])
	for e in g["edges"]:
		var f2: Dictionary = e
		var type := String(f2.get("type", "local"))
		if type == "bridge": continue
		var a: Vector2i = noeuds.get(String(f2["from"]), Vector2i(-1, -1))
		var b: Vector2i = noeuds.get(String(f2["to"]), Vector2i(-1, -1))
		if a.x < 0 or b.x < 0: continue
		# ⚠⚠ LE GRAPHE DESCEND D'UN CRAN, ET C'EST LE DESSIN DE LA CAPITALE QUI
		# L'EXIGE. Classé « primaire », il ajoutait trente voies orange épaisses
		# sur l'Île Centrale : les deux anneaux et les huit radiales — LA
		# signature du dessin du client, la seule chose qui fasse lire une cible
		# plutôt qu'une ville — disparaissaient dans l'enchevêtrement. Le graphe
		# reste, c'est lui qui amène aux ponts et sans lui les ouvrages ne
		# desservent rien ; mais en SECONDAIRE. Sur l'image, seuls les anneaux et
		# les radiales sont orange.
		var classe: String = V_SECONDAIRE if type in ["primary", "highway"] else V_LOCALE
		var genre: String = Ville2.R_AVENUE if classe == V_SECONDAIRE else Ville2.R_RUE
		var d := float((b - a).length())
		var marches := clampi(int(round(d / 18.0)), 1, 20)
		_poser_route(plan, classe, genre, "",
			TRACE.escalier(a, b, marches, alea, minf(d * 0.06, 8.0)))

## ⭐⭐ LES DÉTROITS — ET C'EST LE PONT QUI DIT OÙ EST LE CHENAL.
##
## ⚠ LE DÉFAUT QUE ÇA CORRIGE, ET IL VENAIT DU FICHIER LUI-MÊME. Les rayons
## canoniques se CHEVAUCHENT par endroits : l'Île Centrale (2,75 km) et l'Île
## Nord (2,10 km) ont leurs centres à 4,60 km, soit 250 m de moins que la somme
## de leurs rayons. Dessinées telles quelles, elles se soudent — et le contrôle
## le disait : « 8 masses de terre pour 10 dessinées ». Même chose pour l'Île
## Sud-Est et l'Île de la Côte.
##
## On ne peut pas rétrécir les îles : le rayon est une donnée du client, et
## l'Île Centrale vient tout juste de retrouver ses 5,5 km. On ne peut pas
## davantage déplacer les centres. IL FAUT DONC CREUSER LE CHENAL.
##
## ⭐ ET LE FICHIER DIT DÉJÀ OÙ IL EST : LÀ OÙ IL A MIS UN PONT. Un pont ne se
## pose pas n'importe où — il enjambe le passage le plus étroit, et ses deux
## extrémités SONT les deux rives. On creuse donc, sous chaque ouvrage, une
## ellipse soustraite dont le demi-axe le long de la travée vaut exactement la
## demi-longueur du pont : les deux côtes reculent jusqu'aux culées, ni plus ni
## moins. Le pont Centrale–Nord mesure quarante cases : le chenal en fera
## quarante, et les deux têtes de pont tomberont sur la terre ferme.
##
## C'est la seule règle du fichier qui s'auto-répare : le jour où le client
## bouge un pont, le chenal suit.
##
## ⚠ SAUF LES TUNNELS. Un tunnel passe SOUS — sous la mer comme sous la terre.
## Lui creuser un chenal entaillerait la côte à l'endroit précis où l'ouvrage
## était censé ne rien déranger : le tunnel ferroviaire Centrale ↔ Sud-Est
## mordait quatre-vingts cases de la côte sud-est de la capitale.
const DETROIT_BRUIT := 4.0           ## peu bruité : un chenal ne doit pas se refermer
const DETROIT_TRAVERS := 70.0        ## largeur minimale de la découpe, en travers

static func _les_detroits(donnees: Dictionary) -> Array:
	var sortie: Array = []
	for b in donnees.get("bridges", []):
		var f: Dictionary = b
		if String(f.get("type", "road")) == "rail_tunnel": continue
		var t := _travee(f)
		if t.is_empty(): continue
		var a: Vector2i = t[0]
		var z: Vector2i = t[1]
		var m := (a + z) / 2
		var demi := float(maxi(absi(z.x - a.x), absi(z.y - a.y))) * 0.5
		var travers := maxf(DETROIT_TRAVERS, demi * 3.0)
		if absi(z.x - a.x) >= absi(z.y - a.y):
			sortie.append([m.x, m.y, demi, travers, DETROIT_BRUIT])
		else:
			sortie.append([m.x, m.y, travers, demi, DETROIT_BRUIT])
	return sortie

## LA TRAVÉE D'UN PONT DU FICHIER, ALIGNÉE SUR SON AXE DOMINANT. Les deux
## extrémités données sont des points quelconques (9,6 / 7,4 vers 9,7 / 6,6) :
## un pont en biais ne se pave pas, et `generateur_pays` le sauterait en silence.
## Partagée par les détroits et les ponts — deux calculs séparés dériveraient, et
## le chenal ne tomberait plus sous l'ouvrage.
static func _travee(f: Dictionary) -> Array:
	var pts: Array = f.get("points", [])
	if pts.size() < 2: return []
	var a := _point(pts[0])
	var z := _point(pts[pts.size() - 1])
	if absi(z.x - a.x) >= absi(z.y - a.y):
		var y := (a.y + z.y) / 2
		a.y = y
		z.y = y
	else:
		var x := (a.x + z.x) / 2
		a.x = x
		z.x = x
	return [a, z]

## ⭐ LES DIX PONTS DU FICHIER, AVEC LEURS EXTRÉMITÉS EXACTES.
##
## ⚠⚠ ILS REMPLACENT LE RECENSEMENT, ILS NE S'Y AJOUTENT PAS. Avant, on cherchait
## après coup les endroits où une route traversait l'eau et on y posait un
## tablier : une déduction, donc une source d'écart avec le dessin du client. Le
## fichier dit OÙ SONT LES PONTS. Le recensement automatique reste, mais en
## second rideau, et seulement à plus de `LOIN_D_UN_PONT` cases d'un pont connu :
## il rattrape une route qui traverserait un bras de mer que le client n'avait
## pas prévu, au lieu de doubler chaque travée.
##
## ⚠ UN PONT EST DROIT. Les deux extrémités du fichier sont des points
## quelconques (9,6 / 7,4 vers 9,7 / 6,6) : on les ALIGNE sur leur axe dominant,
## en prenant la coordonnée moyenne sur l'autre axe. Un pont en biais ne se pave
## pas, et `generateur_pays` le sauterait en silence.
##
## ⚠ ET LE TUNNEL N'EST PAS UN PONT. `rail_tunnel` (Centrale ↔ Sud-Est) passe
## SOUS la mer : il est rangé avec le drapeau `tunnel`, et aucun tablier n'est
## posé. C'est la même règle que pour le métro — on ne dessine pas ce qu'on ne
## sait pas dessiner.
static func _les_ponts_du_fichier(plan: Dictionary, donnees: Dictionary) -> void:
	for b in donnees.get("bridges", []):
		var f: Dictionary = b
		var t := _travee(f)
		if t.is_empty(): continue
		var a: Vector2i = t[0]
		var z: Vector2i = t[1]
		var type := String(f.get("type", "road"))
		var modes: Array = f.get("modes", [])
		var tunnel := type == "rail_tunnel"
		plan["ponts"].append({
			"g": "rail" if type.begins_with("rail") else "routier",
			"de": [a.x, a.y], "vers": [z.x, z.y], "nom": String(f.get("name", "")),
			"id": String(f.get("id", "")), "tunnel": tunnel,
		})
		# LA CHAUSSÉE DU PONT, pour les ponts qui portent des voitures. Elle est
		# posée sur la travée EXACTE, pas sur une approximation : c'est la seule
		# façon que la route et le tablier tombent sur les mêmes cases.
		if not tunnel and ("car" in modes or "bus" in modes):
			_poser_route(plan, V_PRIMAIRE, Ville2.R_AVENUE, String(f.get("name", "")),
				[a, z])

## À quelle distance un pont recensé après coup est considéré comme UN AUTRE
## pont que celui du fichier. Deux cents mètres : un chenal franchi deux fois à
## cette distance-là, ce sont deux ouvrages ; en dessous, c'est le même.
const LOIN_D_UN_PONT := 10.0

## ⭐ LE CHEMIN CÔTIER, ET IL SUIT VRAIMENT LA CÔTE. Un anneau posé à 0,94 du
## rayon de l'île passerait dans l'eau à chaque anse — le contour est bruité, pas
## circulaire — et le rastériseur ne pose de chaussée que sur la terre : on
## verrait un chemin en pointillés de trous, sans un mot d'avertissement.
##
## On sonde donc le terrain : pour chacun des quarante-huit azimuts, on descend
## du bord vers le centre jusqu'à toucher la terre, on recule de trois cases, et
## on relie les quarante-huit points en escalier. C'est quarante-huit fois
## quarante sondages par île, donc rien du tout, et ça donne un trait qui épouse
## les caps et rentre dans les baies.
const COTIER_AZIMUTS := 48
const COTIER_RETRAIT := 3

static func _chemin_cotier(plan: Dictionary, ctx: Dictionary,
		alea: RandomNumberGenerator, indice: int) -> void:
	var c := centre_ile(plan, indice)
	var r := rayon_ile(plan, indice)
	var pts: Array = []
	for k in COTIER_AZIMUTS:
		var a := TAU * float(k) / float(COTIER_AZIMUTS)
		var trouve := false
		# Du large vers le centre, de deux cases en deux cases.
		var t := 1.25
		for _pas in 60:
			var q := Vector2i(c.x + roundi(cos(a) * r.x * t), c.y + roundi(sin(a) * r.y * t))
			if terre_en(plan, ctx, q):
				var tt := maxf(t - float(COTIER_RETRAIT) / maxf(r.x, r.y), 0.1)
				pts.append(Vector2i(c.x + roundi(cos(a) * r.x * tt),
					c.y + roundi(sin(a) * r.y * tt)))
				trouve = true
				break
			t -= 0.025
		if not trouve: continue
	if pts.size() < 8: return
	pts.append(pts[0])
	var ile: Dictionary = (plan["iles"] as Array)[indice]
	_poser_route(plan, V_COTIER, Ville2.R_RUE, "Chemin Côtier — " + String(ile["nom"]),
		TRACE.simplifier(_axialiser(pts)))

## ⚠ UNE RUE DE TRAME S'ARRÊTE AU RIVAGE. Les deux quartiers en damier de l'Île
## Sud-Est sont posés au cordeau, sur des presqu'îles au contour bruité : sans
## ce rognage, une rue sur trois finirait dans l'eau. Le rastériseur ne pose de
## chaussée que sur la terre, donc on ne verrait pas une rue fautive mais une rue
## TRONQUÉE EN SILENCE — et sur l'image du client, un trait gris sur la mer.
## On rogne les deux bouts jusqu'à la terre et on abandonne ce qui est trop court.
static func _rue_a_terre(plan: Dictionary, ctx: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var pas := (b - a).sign()
	var lg := (b - a).abs().x + (b - a).abs().y
	var debut := -1
	var fin := -1
	for k in lg + 1:
		var c := a + pas * k
		if terre_en(plan, ctx, c):
			if debut < 0: debut = k
			fin = k
		elif debut >= 0:
			break
	if debut < 0 or fin - debut < 6: return
	_poser_route(plan, V_LOCALE, Ville2.R_RUE, "", [a + pas * debut, a + pas * fin])

## Transforme une suite de points quelconques en polyligne strictement axiale.
## `trace.gd` le fait déjà pour ses propres tracés ; ici on part d'un relevé de
## terrain, donc de points qui n'ont aucune raison d'être alignés.
static func _axialiser(pts: Array) -> Array:
	var sortie: Array = []
	for k in pts.size():
		var p: Vector2i = pts[k]
		if sortie.is_empty():
			sortie.append(p)
			continue
		var prec: Vector2i = sortie[sortie.size() - 1]
		if p == prec: continue
		var coin := TRACE.coin(prec, p)
		if coin != prec: sortie.append(coin)
		if p != coin: sortie.append(p)
	return sortie

## Le nombre de marches d'un anneau : une marche tous les vingt cases environ,
## jamais moins de huit (en dessous, ce n'est plus un anneau mais un polygone).
static func _marches(rayon: int) -> int:
	return maxi(8, int(round(TAU * float(rayon) / 20.0)))

static func _poser_route(plan: Dictionary, classe: String, genre: String, nom: String,
		points: Array) -> void:
	if points.size() < 2: return
	var bruts: Array = []
	for p in points:
		var c := Vector2i(p)
		bruts.append([c.x, c.y])
	plan["routes"].append({"genre": genre, "classe": classe, "nom": nom, "points": bruts})

# ══════════════════════════════════════════════════════════════════ LES RÉSEAUX

## ⭐ LES RÉSEAUX DE TRANSPORT, ET ILS VIENNENT DU FICHIER.
##
## ⚠⚠ CE BLOC A CHANGÉ DE NATURE. Avant, j'INVENTAIS les lignes : quatre trains
## par la Gare Centrale, cinq trains secondaires vers le chapelet, une ceinture
## de métro sous la mer, des trams et des bus — tout cela déduit des dessins, au
## jugé. Le fichier du client donne maintenant les QUINZE LIGNES, chacune avec
## ses arrêts dans l'ordre (`archipel_complet.json`) et son tracé point par point
## (`transit_paths.json`). Ce n'est plus à moi d'en décider.
##
## DEUX SOURCES, ET L'ORDRE DE PRÉFÉRENCE EST ÉCRIT :
##
## 1. `transit_paths.json` — la géométrie complète, points de forme compris.
##    C'est la meilleure : elle passe par les stations ET dit par où la ligne
##    tourne entre deux stations. C'est elle qu'on prend quand elle existe ;
## 2. `archipel_complet.json` — la liste des arrêts. On relie alors les stations
##    en ligne droite. Moins bon (une ligne qui coupe au plus court traverse ce
##    qu'elle devrait contourner) mais toujours juste sur l'essentiel : l'ordre
##    de desserte.
##
## Le BUS reste inventé : le fichier n'en a aucun, et son propre LISEZ-MOI le
## range dans les « prochaines améliorations ». Il est signalé comme tel.
##
## ⚠ ET LE TRACÉ RESTE UN ESCALIER. Les points du fichier sont des flottants en
## kilomètres, donc des diagonales. `ajouter_route` refuse la diagonale et le
## rail ne se pave pas mieux : chaque paire de points guides passe par
## `TRACE.escalier`, qui rend une polyligne strictement axiale.
static func _les_reseaux(plan: Dictionary, ctx: Dictionary,
		alea: RandomNumberGenerator, donnees: Dictionary) -> void:
	var trajets := _lire(FICHIER_TRAJETS)
	var groupes := [["train", R_TRAIN, false, "train_lines"],
		["metro", R_METRO, true, "metro_lines"],
		["tram", R_TRAM, false, "tram_lines"]]
	var posees := 0
	for g in groupes:
		var f: Array = g
		var famille := String(f[0])
		var reseau := String(f[1])
		var souterrain := bool(f[2])
		var table := String(f[3])
		# La liste des lignes : celle du fichier de trajets si elle existe, sinon
		# celle des compositions.
		var noms: Array = []
		if trajets.has(famille): noms = (trajets[famille] as Dictionary).keys()
		elif donnees.has(table): noms = (donnees[table] as Dictionary).keys()
		for nom in noms:
			var guides := _guides(plan, trajets, donnees, famille, table, String(nom))
			if guides.size() < 2: continue
			var couleur := ""
			if donnees.has(table) and (donnees[table] as Dictionary).has(nom):
				couleur = String(((donnees[table] as Dictionary)[nom] as Dictionary)
					.get("color", ""))
			var vrai_reseau := reseau
			# ⚠ T3 ET T4 SONT DES LIGNES SECONDAIRES. La légende du client
			# distingue deux rouges — « train, inter-îles et liaisons
			# principales » et « train secondaire, dessertes et tunnels » — et
			# le second n'avait aucune ligne. T1 (les Pins ↔ le Sommet, par la
			# capitale) et T2 (la capitale ↔ la Côte, par le Sud-Est) sont les
			# deux grandes transversales ; T3 (l'Ouest) et T4 (le Levant et la
			# Baie) sont des antennes. C'est le seul classement que les données
			# permettent, et il rend sa légende au dessin.
			if reseau == R_TRAIN and String(nom) in TRAINS_SECONDAIRES:
				vrai_reseau = R_TRAIN2
			_ligne(plan, vrai_reseau, String(nom), souterrain,
				_chainer(plan, ctx, guides, alea), couleur)
			posees += 1
	if posees == 0:
		push_warning("archipel : aucune ligne de transport lue, repli sur le bus seul")
	_les_bus(plan, alea)

## LES POINTS GUIDES D'UNE LIGNE. Voir l'ordre de préférence ci-dessus.
static func _guides(plan: Dictionary, trajets: Dictionary, donnees: Dictionary,
		famille: String, table: String, nom: String) -> Array:
	var pts: Array = []
	if trajets.has(famille) and (trajets[famille] as Dictionary).has(nom):
		var src: Dictionary = (trajets[famille] as Dictionary)[nom]
		for p in src.get("points", []):
			pts.append(_point(p))
		if pts.size() >= 2: return pts
	# Repli : la liste des arrêts.
	if donnees.has(table) and (donnees[table] as Dictionary).has(nom):
		var src2: Dictionary = (donnees[table] as Dictionary)[nom]
		for id in src2.get("stations", []):
			var c := station_id(plan, String(id))
			if c.x >= 0: pts.append(c)
	return pts

## Les lignes de train classées « secondaires » — voir le commentaire ci-dessus.
const TRAINS_SECONDAIRES := ["T3", "T4"]

## ⚠ CHAÎNER DES GUIDES, C'EST PLUS QUE LES RELIER. Deux guides distants de trois
## kilomètres reliés par UNE marche donnent un grand L au milieu de la carte ;
## reliés par une marche tous les deux cents mètres, ils donnent un escalier de
## pixels. On échelonne donc le nombre de marches sur la distance — une tous les
## quatorze cases, soit deux cent quatre-vingts mètres, qui est la maille à
## laquelle une voie ferrée cesse de se lire comme un escalier.
##
## ⚠⚠ SAUF AU-DESSUS DE L'EAU, ET C'EST LE DÉFAUT BLOQUANT QUE ÇA CORRIGE.
##
## Sur le premier rendu, les lignes rouges franchissaient des bras de mer de
## CINQ KILOMÈTRES en longues diagonales en escalier, sans un ouvrage dessous :
## un train qui roule sur l'eau, exactement ce que le client venait de reprocher
## au tracé maritime dans l'autre sens.
##
## La cause n'était pas le recensement des ponts, elle était ICI. Une diagonale
## en escalier au-dessus de l'eau, c'est vingt marches, donc vingt petites
## traversées dont aucune n'est alignée sur un axe — et `_ponts_du_trace`, qui
## exige une travée DROITE (le kit ne sait pas paver autrement, et une travée
## qui tourne n'a pas de pile où se poser), les abandonnait toutes en silence.
## Le pont manquant n'était pas oublié : il était IMPOSSIBLE À POSER.
##
## ⭐ ON NE FRANCHIT DONC PAS LA MER EN ESCALIER, ON LA FRANCHIT EN ÉQUERRE. Dès
## qu'un tronçon passe au-dessus de l'eau, il devient DEUX SEGMENTS DROITS à
## angle droit — deux travées qui se pavent, se posent et se voient. Le coude
## est mis à terre quand c'est possible : une pile de pont sur un îlot vaut
## mieux qu'une pile en pleine eau.
static func _chainer(plan: Dictionary, ctx: Dictionary, guides: Array,
		alea: RandomNumberGenerator) -> Array:
	var pts: Array = []
	for k in range(1, guides.size()):
		var a: Vector2i = guides[k - 1]
		var b: Vector2i = guides[k]
		var bout: Array = []
		if _traverse_l_eau(plan, ctx, a, b):
			bout = _en_equerre(plan, ctx, a, b)
		else:
			var d := float((b - a).length())
			var marches := clampi(int(round(d / 14.0)), 1, 24)
			bout = TRACE.escalier(a, b, marches, alea, 0.0)
		if pts.is_empty(): pts.append_array(bout)
		else:
			for q in bout:
				pts.append(q)
	return pts

## Vrai si la droite qui joint deux guides passe au-dessus de l'eau. On sonde de
## quatre en quatre : une langue de mer de moins de quatre-vingts mètres n'est
## pas un bras de mer, c'est une crique, et le tracé la franchit sans ouvrage.
static func _traverse_l_eau(plan: Dictionary, ctx: Dictionary, a: Vector2i,
		b: Vector2i) -> bool:
	var d := (b - a).length()
	var n := maxi(1, int(d / 4.0))
	for k in range(1, n):
		var t := float(k) / float(n)
		var c := Vector2i(roundi(lerpf(float(a.x), float(b.x), t)),
			roundi(lerpf(float(a.y), float(b.y), t)))
		if not terre_en(plan, ctx, c): return true
	return false

## L'ÉQUERRE : deux segments droits à angle droit. Des deux coudes possibles, on
## prend celui qui tombe à TERRE ; à défaut, celui de l'axe dominant, qui est
## celui que `trace.gd` choisirait de toute façon.
static func _en_equerre(plan: Dictionary, ctx: Dictionary, a: Vector2i,
		b: Vector2i) -> Array:
	var c1 := Vector2i(b.x, a.y)
	var c2 := Vector2i(a.x, b.y)
	var terre1 := terre_en(plan, ctx, c1)
	var terre2 := terre_en(plan, ctx, c2)
	var coin := TRACE.coin(a, b)
	if terre1 and not terre2: coin = c1
	elif terre2 and not terre1: coin = c2
	if coin == a or coin == b: return [a, b]
	return [a, coin, b]

## LE BUS, ET C'EST LE SEUL RÉSEAU QUI RESTE INVENTÉ. Le fichier du client n'en
## donne aucun ; son LISEZ-MOI range « l'ajout des lignes de bus détaillées »
## dans les prochaines améliorations. On garde donc le maillage fin déduit de la
## carte d'ensemble — deux couronnes sur la capitale, une boucle par grande île,
## et les dessertes de lieux-dits que personne d'autre ne fait — et on le SIGNALE
## comme tel, pour que personne ne le prenne pour une donnée validée.
static func _les_bus(plan: Dictionary, alea: RandomNumberGenerator) -> void:
	var cc := centre_ile(plan, CENTRALE)
	var rc := rayon_ile(plan, CENTRALE)
	for part in [0.52, 0.90]:
		var ray := int(round(part * rc.x))
		_ligne(plan, R_BUS, "B%d" % ray, false,
			TRACE.anneau(cc, Vector2(float(ray), float(ray) * rc.y / rc.x),
				_marches(ray), alea, 0.06), "")
	var cvn := repere(plan, "Centre-Ville Nord")
	var rn := rayon_ile(plan, NORD)
	_ligne(plan, R_BUS, "BN1", false,
		TRACE.anneau(cvn, Vector2(rn.x * 0.72, rn.y * 0.66), _marches(int(rn.x * 0.72)),
			alea, 0.06), "")
	_ligne(plan, R_BUS, "BN2", false, TRACE.escalier(repere(plan, "Vallée Verte"),
		repere(plan, "Baie du Sud"), 7, alea, 9.0), "")
	var cse := repere(plan, "Centre Sud-Est")
	var rs := rayon_ile(plan, SUDEST)
	_ligne(plan, R_BUS, "BS1", false,
		TRACE.anneau(cse, Vector2(rs.x * 0.74, rs.y * 0.64), _marches(int(rs.x * 0.74)),
			alea, 0.06), "")
	_ligne(plan, R_BUS, "BS2", false, TRACE.escalier(repere(plan, "Vallée des Pins"),
		repere(plan, "Pointe de l'Aube"), 8, alea, 10.0), "")

## ⚠ LA COULEUR DU FICHIER EST RANGÉE, PAS UTILISÉE. Le client donne une couleur
## PAR LIGNE (T2 orange, T3 violet, T4 bleu) — c'est la convention d'un plan de
## transport, où l'on suit une ligne du doigt. Notre image, elle, est une CARTE :
## elle doit répondre « par où passe le train ? » avant « par où passe le T3 ? »,
## donc elle colore PAR RÉSEAU. On garde la couleur pour le jour où l'on fera le
## plan de transport, qui est un autre dessin.
static func _ligne(plan: Dictionary, reseau: String, nom: String, souterrain: bool,
		points: Array, couleur := "") -> void:
	var propre := TRACE.simplifier(points)
	if propre.size() < 2: return
	var bruts: Array = []
	for p in propre:
		var c := Vector2i(p)
		bruts.append([c.x, c.y])
	plan["lignes"].append({"reseau": reseau, "nom": nom, "souterrain": souterrain,
		"couleur": couleur, "points": bruts})

# ═════════════════════════════════════════════════════════ LES VOIES MARITIMES

## ⚠ UN FERRY NE TRAVERSE PAS LA TERRE, ET C'EST TOUT LE SUJET DE CE BLOC.
##
## Le client, en regardant le premier plan : « là où la voie maritime passe dans
## les îles, assure-toi que ce soit dans un cours d'eau, car j'ai l'impression
## que le bateau va avancer sur la terre ». Ce qu'il voyait était en réalité le
## MÉTRO — un tunnel, donc légitimement sous la terre comme sous la mer — mais
## le reproche a révélé un vrai manque : il n'y avait AUCUNE ligne maritime,
## alors que ses propres cartes en montrent trois fois (la Gare Maritime, le
## ferry de Port-Nord, « vers les autres îles de l'archipel »).
##
## LA RÈGLE EST TENUE PAR CONSTRUCTION, PAS PAR VÉRIFICATION APRÈS COUP. Un
## tracé de ferry est CHERCHÉ DANS L'EAU, de case d'eau en case d'eau : il ne
## peut pas toucher terre parce qu'il n'a jamais le droit d'entrer sur une case
## de terre. C'est la différence entre « on corrigera si ça déborde » et « ça ne
## peut pas déborder » — et sur une carte d'un million de cases, seule la
## seconde tient.
##
## ⚠ ET IL PASSE AU LARGE, PAS AU RAS DES CAILLOUX. Une recherche nue rend le
## plus court chemin, qui longe la côte au plus près : un ferry qui frôle chaque
## cap se lit comme une erreur même s'il est techniquement en mer. On PÉNALISE
## donc les cases proches du rivage, et c'est ce qui donne au trait sa forme de
## VOIE — tenue au large, rentrant franchement vers son port.

## Le pas du treillis de recherche, en cases. Chercher case par case sur un
## million de cases coûterait des secondes par ligne, pour une précision utile
## de deux cents mètres : on cherche de dix en dix, puis on rabat au cas près.
const PAS_MER := 10
## Le rayon, en cases, dans lequel une case de terre rend la navigation chère.
const MARGE_COTE := 14
## Le surcoût par voisin terrestre trouvé dans ce rayon. Assez haut pour que le
## détour au large soit rentable, assez bas pour qu'un chenal étroit reste
## franchissable : à l'infini, le ferry n'entrerait plus dans les ports.
const COUT_COTE := 4

static func _les_voies_maritimes(plan: Dictionary, ctx: Dictionary, alea: RandomNumberGenerator) -> void:
	# LES EMBARCADÈRES. Trois ports nommés par le client, plus les deux îles du
	# chapelet qui portent une halte. Chacun se ramène à la case d'EAU la plus
	# proche : un port est un bâtiment à terre, un ferry part de l'eau devant.
	var rades := {
		"Port-Nord": _rade(plan, ctx, repere(plan, "Port-Nord")),
		"Port-des-Alpes": _rade(plan, ctx, repere(plan, "Port-des-Alpes")),
		"Gare Maritime": _rade(plan, ctx, repere(plan, "Gare Maritime")),
	}
	var lignes := [
		["F1", "Port-Nord", "Port-des-Alpes"],
		["F2", "Port-des-Alpes", "Gare Maritime"],
		["F3", "Gare Maritime", "Port-Nord"],
	]
	for e in lignes:
		var f: Array = e
		var a: Vector2i = rades[String(f[1])]
		var b: Vector2i = rades[String(f[2])]
		if a.x < 0 or b.x < 0: continue
		var pts := _cap(plan, ctx, a, b)
		if pts.size() < 2:
			push_warning("voie maritime « %s » : pas de passage par la mer" % String(f[0]))
			continue
		_ligne(plan, R_FERRY, String(f[0]), false, pts)
	# Les embarcadères deviennent des stations : c'est ce qui les rend visibles
	# sur le plan et adressables en jeu.
	for nom in rades:
		var c: Vector2i = rades[nom]
		if c.x < 0: continue
		plan["stations"].append({"nom": "Embarcadère " + String(nom),
			"c": [c.x, c.y], "reseau": R_FERRY, "ligne": "", "principale": true})

## LA RADE D'UN PORT : la case d'eau la plus proche du repère, cherchée en
## spirale. Un repère est posé à terre ; sans ce rabattement, la ligne partirait
## d'une case de terre et le premier pas serait déjà une faute.
static func _rade(plan: Dictionary, ctx: Dictionary, ou: Vector2i) -> Vector2i:
	if ou.x < 0: return Vector2i(-1, -1)
	if not terre_en(plan, ctx, ou): return ou
	for r in range(1, 60):
		for k in range(0, 8 * r):
			var a := TAU * float(k) / float(8 * r)
			var c := ou + Vector2i(int(round(cos(a) * float(r))), int(round(sin(a) * float(r))))
			if not terre_en(plan, ctx, c): return c
	push_warning("aucune eau autour de %s" % ou)
	return Vector2i(-1, -1)

## LE CAP D'UN PORT À L'AUTRE, entièrement en mer.
##
## Recherche de Dijkstra sur un treillis de `PAS_MER`, avec une file par
## paliers de coût (les coûts sont de petits entiers : une file à seaux suffit,
## et elle évite le tri d'un tas). Puis on rabat le chemin du treillis en
## polyligne à angles droits, case par case, en refusant toute case de terre.
static func _cap(plan: Dictionary, ctx: Dictionary, a: Vector2i, b: Vector2i) -> Array:
	# ⚠ ARRONDIR AU TREILLIS PEUT POSER LE DÉPART À TERRE, et alors la recherche
	# ne part de nulle part : elle n'accepte que des voisins en eau, et un nœud
	# de terre n'en a aucun. Deux lignes maritimes sur trois échouaient ainsi —
	# la rade était bien dans l'eau, mais le nœud de treillis le plus proche
	# tombait dix mètres plus loin, sur le quai. On cherche donc, autour de
	# l'arrondi, le premier nœud de treillis QUI EST EN EAU.
	var na := _noeud_marin(plan, ctx, a)
	var nb := _noeud_marin(plan, ctx, b)
	if na.x < 0 or nb.x < 0: return []
	var large := Vector2i(TAILLE.x / PAS_MER, TAILLE.y / PAS_MER)
	var couts := {}
	var venu = {}
	var seaux: Array = []
	seaux.resize(4096)
	for k in seaux.size(): seaux[k] = []
	var mettre := func(n: Vector2i, c: int, d: Vector2i) -> void:
		if couts.has(n) and int(couts[n]) <= c: return
		couts[n] = c
		venu[n] = d
		if c < seaux.size(): (seaux[c] as Array).append(n)
	mettre.call(na, 0, Vector2i(-9999, -9999))
	var trouve := false
	for c in seaux.size():
		var file: Array = seaux[c]
		for k in file.size():
			var n: Vector2i = file[k]
			if int(couts.get(n, 999999)) != c: continue
			if n == nb:
				trouve = true
				break
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var m: Vector2i = n + d
				if m.x < 0 or m.y < 0 or m.x > large.x or m.y > large.y: continue
				var cm := m * PAS_MER
				if terre_en(plan, ctx, cm): continue
				mettre.call(m, c + 1 + _cout_de_rive(plan, ctx, cm), n)
		if trouve: break
	if not trouve: return []
	# On remonte le chemin, puis on le rabat en cases.
	var treillis: Array = [nb]
	var cur := nb
	for _k in 20000:
		var pre: Vector2i = venu[cur]
		if pre.x == -9999: break
		treillis.push_front(pre)
		cur = pre
	var pts: Array = [a]
	var ici := a
	for k in range(1, treillis.size()):
		var vers: Vector2i = (treillis[k] as Vector2i) * PAS_MER
		if k == treillis.size() - 1: vers = b
		var bout := _segment_marin(plan, ctx, pts, ici, vers)
		if bout.x < 0: return []
		ici = bout
	if pts[pts.size() - 1] != b: pts.append(b)
	return TRACE.simplifier(pts)

## Le nœud de treillis en eau le plus proche d'une case, cherché en carré
## croissant. −1 si l'on est dans une flaque trop petite pour le treillis.
static func _noeud_marin(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> Vector2i:
	var n0 := Vector2i(roundi(float(c.x) / float(PAS_MER)), roundi(float(c.y) / float(PAS_MER)))
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var n := n0 + Vector2i(dx, dy)
				if n.x < 0 or n.y < 0: continue
				if n.x * PAS_MER >= TAILLE.x or n.y * PAS_MER >= TAILLE.y: continue
				if not terre_en(plan, ctx, n * PAS_MER): return n
	return Vector2i(-1, -1)

## Combien de terre il y a autour de cette case, dans le rayon `MARGE_COTE`.
## Huit sondes suffisent : on cherche un ordre de grandeur, pas une mesure.
static func _cout_de_rive(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> int:
	var n := 0
	for k in 8:
		var a := TAU * float(k) / 8.0
		var s := c + Vector2i(int(round(cos(a) * float(MARGE_COTE))),
			int(round(sin(a) * float(MARGE_COTE))))
		if terre_en(plan, ctx, s): n += 1
	return n * COUT_COTE

## UN SEGMENT DU TREILLIS, rabattu en deux droites à angle droit, TOUTES CASES
## EN EAU. On essaie les deux ordres (d'abord en X, puis en Y, et l'inverse) :
## dans un chenal, l'un des deux passe presque toujours quand l'autre coupe un
## cap. Si aucun ne passe, la ligne est abandonnée — mieux vaut pas de ferry
## qu'un ferry sur la plage.
static func _segment_marin(plan: Dictionary, ctx: Dictionary, pts: Array,
		de: Vector2i, vers: Vector2i) -> Vector2i:
	if de == vers: return de
	for ordre in 2:
		var coude: Vector2i = Vector2i(vers.x, de.y) if ordre == 0 else Vector2i(de.x, vers.y)
		if _eau_partout(plan, ctx, de, coude) and _eau_partout(plan, ctx, coude, vers):
			if coude != de: pts.append(coude)
			if vers != coude: pts.append(vers)
			return vers
	# ⚠ ET S'IL LE FAUT, ON CHERCHE CASE PAR CASE. Dans un chenal étroit ou
	# devant une passe, les deux coudes à angle droit coupent tous les deux un
	# cap : le treillis de dix cases a trouvé un passage que le rabattement
	# grossier ne sait pas suivre. Deux lignes maritimes sur trois tombaient
	# ainsi — non pas parce qu'il n'y avait pas de mer, mais parce qu'on ne
	# savait pas la longer. On repasse donc en fin par une propagation d'eau en
	# eau, bornée à la fenêtre du segment : c'est court, et c'est le seul endroit
	# où le tracé a besoin de finesse.
	var chemin := _passe(plan, ctx, de, vers)
	if chemin.is_empty(): return Vector2i(-1, -1)
	for p in chemin: pts.append(p)
	return vers

## LA PASSE : une propagation d'eau en eau de `de` à `vers`, bornée à la boîte
## des deux points élargie de `MARGE_PASSE`, rendue en polyligne à angles
## droits. Vide si la mer ne relie pas les deux.
const MARGE_PASSE := 22

static func _passe(plan: Dictionary, ctx: Dictionary, de: Vector2i, vers: Vector2i) -> Array:
	var boite := Rect2i(de, Vector2i.ZERO).expand(vers).grow(MARGE_PASSE)
	var venu := {}
	var file: Array = [de]
	venu[de] = Vector2i(-9999, -9999)
	var trouve := false
	var t := 0
	while t < file.size():
		var n: Vector2i = file[t]
		t += 1
		if n == vers:
			trouve = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var m: Vector2i = n + d
			if venu.has(m) or not boite.has_point(m): continue
			if m != vers and terre_en(plan, ctx, m): continue
			venu[m] = n
			file.append(m)
	if not trouve: return []
	# On remonte, puis on ne garde que les CHANGEMENTS DE DIRECTION : une passe
	# rendue case par case ferait quatre cents points pour deux kilomètres, et
	# `angles.gd` trouverait un coude partout.
	var brut: Array = [vers]
	var cur := vers
	for _k in 20000:
		var pre: Vector2i = venu[cur]
		if pre.x == -9999: break
		brut.push_front(pre)
		cur = pre
	var sortie: Array = []
	for k in range(1, brut.size()):
		var a: Vector2i = brut[k - 1]
		var b: Vector2i = brut[k]
		var c: Vector2i = brut[mini(k + 1, brut.size() - 1)]
		if (b - a) != (c - b) or k == brut.size() - 1: sortie.append(b)
	return sortie

static func _eau_partout(plan: Dictionary, ctx: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	var d := (b - a).sign()
	var c := a
	for _k in ((b - a).abs().x + (b - a).abs().y + 1):
		if terre_en(plan, ctx, c): return false
		if c == b: return true
		c += d
	return true

# ══════════════════════════════════════════════════════════════════ LES STATIONS

## LES STATIONS INTERMÉDIAIRES, semées le long de chaque ligne à l'écart de son
## réseau (voir `ECART_STATIONS`). Les quinze repères NOMMÉS sont déjà posés ;
## celles-ci sont les arrêts ordinaires, et c'est leur DENSITÉ qui fait qu'on lit
## un métro plutôt qu'un train.
##
## ⚠ ON NE POSE PAS DEUX STATIONS AU MÊME ENDROIT. Cinq réseaux qui passent par
## la Gare Centrale y poseraient cinq carrés l'un sur l'autre : sur l'image ça
## fait une tache, et dans le jeu ça fera cinq lieux pour un seul bâtiment. Une
## station à moins de `SERRAGE` cases d'une autre du même réseau est abandonnée.
const SERRAGE := 9

## ⚠⚠ ET UN ARRÊT NE SE POSE QU'À TERRE. Le contrôle annonçait « stations en
## mer : 32 », toutes anonymes : c'étaient les arrêts semés. Semer tous les N
## cases le long d'un tracé sans regarder le sol met des quais au milieu d'un
## bras de mer — et le contrôle avait beau le dire, il ne servait à rien tant que
## personne n'en corrigeait la cause. On repousse au pas suivant : un arrêt sauté
## revient dès que la ligne retouche la terre.
static func _les_stations(plan: Dictionary, ctx: Dictionary) -> void:
	var posees: Array = []
	for s in plan["stations"]:
		posees.append(case_de((s as Dictionary)["c"]))
	for l in plan["lignes"]:
		var f: Dictionary = l
		var reseau := String(f["reseau"])
		var ecart := int(ECART_STATIONS.get(reseau, 30))
		# ⚠ UN ÉCART NUL VEUT DIRE « PAS D'ARRÊT SEMÉ », PAS « UN ARRÊT PAR CASE ».
		# Le ferry en avait soixante-douze au milieu de l'eau : `depuis >= 0` est
		# vrai au premier pas. Ses seules stations sont ses embarcadères.
		if ecart <= 0: continue
		var depuis := ecart / 2
		var pts: Array = f["points"]
		for k in range(1, pts.size()):
			var a := case_de(pts[k - 1])
			var b := case_de(pts[k])
			var pas := (b - a).sign()
			var c := a
			for _m in (b - a).abs().x + (b - a).abs().y + 1:
				depuis += 1
				if depuis >= ecart and terre_en(plan, ctx, c):
					var libre := true
					for p in posees:
						if ((p as Vector2i) - c).abs().length() < float(SERRAGE):
							libre = false
							break
					if libre:
						plan["stations"].append({"nom": "", "c": [c.x, c.y],
							"reseau": reseau, "ligne": String(f["nom"]),
							"principale": false})
						posees.append(c)
						depuis = 0
				if c == b: break
				c += pas

# ══════════════════════════════════════════════════════════════════ LES PONTS

## LE RECENSEMENT DES TRAVERSÉES D'EAU. Une route ou une voie ferrée qui passe
## sur l'eau a besoin d'un pont, et c'est le seul endroit qui le sait.
##
## ⚠ LE MÉTRO N'EN A PAS, ET C'EST TOUT LE PROPOS : il passe SOUS la mer. C'est
## la ligne `if souterrain: continue`, et c'est elle qui fait la différence entre
## les deux façons de relier les îles sur la carte du client.
##
## ⚠⚠ ET VOICI CE QU'ON NE SAIT TOUJOURS PAS FAIRE, écrit ici parce que c'est ici
## qu'on bute dessus : `Ville2.rasteriser()` ne pose une chaussée QUE sur une
## case de terre. ON NE ROULE DONC PAS SUR LES PONTS. C'était déjà vrai sur la
## carte du 14/09 et la raison n'a pas changé — corriger demande `rasteriser`,
## `Ville2.plate` ET `TerrainV2.hauteur_coin` ensemble, faute de quoi le fond de
## la mer se soulève jusqu'au tablier sur toute la longueur du pont. Le pont est
## posé comme un OBJET (une plateforme avec ses piles), la polyligne reste pour
## le GPS et la mini-carte, et on le VOIT.
const PONT_MINI := 3

static func _recenser_les_ponts(plan: Dictionary, ctx: Dictionary) -> void:
	var traces: Array = []
	for r in plan["routes"]:
		var fr: Dictionary = r
		# ⚠ UNE RUELLE ET UN SENTIER N'ONT PAS DE PONT. Le chemin côtier longe un
		# trait de côte bruité : il coupe une crique tous les deux cents mètres,
		# et recenser ces traversées-là donnerait cinquante ouvrages d'art pour
		# des passerelles de six mètres. Seules la voirie structurante et les
		# voies ferrées ont droit à une travée.
		if String(fr.get("classe", "")) not in [V_PRIMAIRE, V_SECONDAIRE]: continue
		traces.append([fr["points"], String(fr.get("nom", "")), "routier"])
	for l in plan["lignes"]:
		var f: Dictionary = l
		if bool(f.get("souterrain", false)): continue
		if String(f["reseau"]) not in [R_TRAIN, R_TRAIN2]: continue
		traces.append([f["points"], String(f["nom"]), "rail"])
	for t in traces:
		var e: Array = t
		_ponts_du_trace(plan, ctx, e[0], String(e[1]), String(e[2]))

## ⭐⭐ UN OUVRAGE POUR CHAQUE TRAVERSÉE, SANS EXCEPTION ET SANS SILENCE.
##
## ⚠ L'ANCIENNE VERSION ABANDONNAIT LES TRAVERSÉES EN BIAIS — « elle apparaîtra
## comme un trou, et c'est visible, donc corrigeable ». C'était faux. Sur une
## carte de vingt kilomètres, un trou de cinq kilomètres au milieu de la mer ne
## se lit pas comme un défaut : il se lit comme un train qui roule sur l'eau, et
## c'est ce que le client a vu. Une traversée qu'on renonce à équiper doit être
## équipée AUTREMENT, jamais laissée nue.
##
## TROIS CAS, ET ILS COUVRENT TOUT :
##
## 1. la traversée est DROITE et courte → UNE TRAVÉE. Le cas normal, et le seul
##    que l'ancienne version traitait ;
## 2. elle est EN BIAIS → DEUX TRAVÉES À ANGLE DROIT, par le coude. Deux ponts
##    droits qui se rejoignent valent mieux qu'une diagonale qui ne se pave pas.
##    (Avec le franchissement en équerre de `_chainer`, ce cas ne se présente
##    plus pour les lignes ; il reste pour les routes, qui serpentent) ;
## 3. elle dépasse `PONT_LONG` → ce n'est plus un pont, c'est un TUNNEL. Deux
##    kilomètres de travée sur pilotis n'existent pas dans ce kit et guère
##    ailleurs ; le fichier du client emploie déjà la convention pour sa liaison
##    ferroviaire Centrale ↔ Sud-Est. Drapeau `tunnel`, pas de tablier, et
##    l'image le dessine en pointillé — comme le métro, pour la même raison.
##
## Une traversée très longue relèverait plutôt du FERRY : les trois lignes
## maritimes existent déjà et desservent les trois ports. C'est au client de
## trancher ligne par ligne ; le tunnel est le choix qui ne ment pas en attendant.
const PONT_LONG := 100               ## 2 km : au-delà, un pont devient un tunnel

static func _ouvrage(plan: Dictionary, debut: Vector2i, fin: Vector2i, nom: String,
		genre: String) -> void:
	var longueur := absi(fin.x - debut.x) + absi(fin.y - debut.y)
	if longueur < PONT_MINI: return
	if _deja_un_pont(plan, (debut + fin) / 2): return
	if longueur > PONT_LONG:
		plan["ponts"].append({"g": genre, "de": [debut.x, debut.y],
			"vers": [fin.x, fin.y], "nom": nom, "tunnel": true})
		return
	if debut.x == fin.x or debut.y == fin.y:
		plan["ponts"].append({"g": genre, "de": [debut.x, debut.y],
			"vers": [fin.x, fin.y], "nom": nom, "tunnel": false})
		return
	# EN BIAIS : deux travées droites par le coude.
	var coin := TRACE.coin(debut, fin)
	plan["ponts"].append({"g": genre, "de": [debut.x, debut.y],
		"vers": [coin.x, coin.y], "nom": nom, "tunnel": false})
	plan["ponts"].append({"g": genre, "de": [coin.x, coin.y],
		"vers": [fin.x, fin.y], "nom": nom, "tunnel": false})

## Vrai si un pont du fichier couvre déjà cette traversée (voir `LOIN_D_UN_PONT`).
static func _deja_un_pont(plan: Dictionary, milieu: Vector2i) -> bool:
	for p in plan["ponts"]:
		var f: Dictionary = p
		var m := (case_de(f["de"]) + case_de(f["vers"])) / 2
		if Vector2(m - milieu).length() <= LOIN_D_UN_PONT: return true
	return false

static func _ponts_du_trace(plan: Dictionary, ctx: Dictionary, pts: Array, nom: String,
		genre: String) -> void:
	var debut := Vector2i(-1, -1)
	var precedent := Vector2i(-1, -1)
	for k in range(1, pts.size()):
		var a := case_de(pts[k - 1])
		var b := case_de(pts[k])
		var pas := (b - a).sign()
		var c := a
		for _m in (b - a).abs().x + (b - a).abs().y + 1:
			var eau := not terre_en(plan, ctx, c)
			if eau and debut.x < 0:
				debut = precedent if precedent.x >= 0 else c
			elif not eau and debut.x >= 0:
				_ouvrage(plan, debut, c, nom, genre)
				debut = Vector2i(-1, -1)
			precedent = c
			if c == b: break
			c += pas

# ══════════════════════════════════════════════════════════════════ utilitaires

static func _rect(a) -> Rect2i:
	var t: Array = a
	return Rect2i(int(t[0]), int(t[1]), int(t[2]), int(t[3]))

static func rect_de(d: Dictionary) -> Rect2i:
	return _rect(d["z"])

static func case_de(a) -> Vector2i:
	var t: Array = a
	return Vector2i(int(t[0]), int(t[1]))

## ⚠⚠ LE PLATEAU D'UNE IMPLANTATION N'EST PAS TOUJOURS SON EMPRISE, ET C'EST LA
## PLAGE QUI FAIT L'EXCEPTION. `GenerateurPlage` met de l'eau à partir de sa
## rangée 24 : son emprise sera posée À CHEVAL sur le trait de côte, ses rangées
## bâties à terre et ses rangées d'eau au large. Forcer tout son carré à terre —
## ce que fait un plateau — LUI RETIRERAIT SA MER. (Étape 4 ; rien ne s'en sert
## encore, mais la règle est connue et il serait absurde de la réapprendre.)
static func emprise_plateau(d: Dictionary) -> Rect2i:
	var z := _rect(d["z"])
	if String(d["t"]) == "plage":
		return Rect2i(z.position, Vector2i(z.size.x, RANGEES_PLAGE))
	return z

## Le plan sur disque. Il n'a rien d'un `Ville2` : que des nombres.
static func enregistrer(plan: Dictionary, chemin: String) -> bool:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(plan))
	f.close()
	return true

static func charger(chemin: String) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		push_warning("plan de l'archipel introuvable : " + chemin)
		return {}
	var brut = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	return brut if typeof(brut) == TYPE_DICTIONARY else {}

# ------------------------------------------------------------------
# CE QUI RESTE À FAIRE, dans l'ordre où je le ferais
# ------------------------------------------------------------------
#
# 1. LES QUARTIERS (étape 4 du client). `implantations` est vide. Le semis se
#    fera à partir des repères : la Cité Administrative appelle le témoin
#    `centre`, l'Université le `campus`, Port-des-Alpes la `plage`, Port-Nord
#    et la Gare Maritime l'`industrie`, Plage-des-Vents la `plage`, et les
#    secteurs entre radiales les autres. `generateur_pays.gd` sait déjà les
#    greffer et les découper : il n'y a que la liste à remplir.
# 2. LA TRAME LOCALE POUR DE VRAI. Aujourd'hui l'Île Centrale a huit
#    demi-radiales entre ses anneaux ; la carte du client montre une trame
#    complète, un vrai damier courbe secteur par secteur. C'est le témoin
#    `centre` qui devra la poser, à l'intérieur de son emprise, en suivant les
#    deux anneaux qui le bordent — donc un témoin qui prend une GÉOMÉTRIE
#    POLAIRE en paramètre, ce qu'aucun des neuf ne sait faire. Chantier à part.
# 3. LE MÉTRO EN 3D : tunnel, trémie, station souterraine. Trois pièces à
#    modeler et une notion de niveau dans `Ville2`. C'est ce qui débloquerait
#    aussi les voies rapides surélevées et les ponts carrossables, qui butent
#    tous les trois sur la même chose : `hauteur_coin` fait gagner toute case
#    plate, donc le terrain monte rejoindre tout ce qu'on pose en l'air.
# 4. LES BASSINS DE PORT-NORD ET DE LA GARE MARITIME. Les deux cartes montrent
#    des môles et des darses dessinés au trait. Ce sont des GOLFES en plus,
#    minces et rectangulaires — la mécanique existe (`golfes`), il n'y a qu'à
#    les relever.
