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

## L'ÎLE DU RELEVÉ, GARNIE DES GARES DU FICHIER. La forme est celle du relevé —
## on ne la retouche pas, elle a été réglée lobe par lobe sur les cartes du
## client. Seules s'y ajoutent les gares du fichier qui tomberaient hors de
## l'enveloppe : la règle 3 de `_ile_depuis` vaut ici aussi, une gare en mer ne
## se voit pas sur une image de mille pixels.
static func _ile_du_releve(mien: Dictionary, src: Dictionary, cle: String) -> Dictionary:
	var sortie := mien.duplicate(true)
	sortie["id"] = cle
	var c := case_de(mien["c"])
	var rm: Array = mien["r"]
	var rx := float(rm[0])
	var rz := float(rm[1])
	var bruit := float(mien.get("bruit", 12.0))
	var util := minf(rx, rz) - bruit * MARGE_ENVELOPPE
	var caps: Array = sortie["caps"]
	for s2 in src.get("stations", []):
		var fs: Dictionary = s2
		var p := _point(fs["pos"]) - c
		var d := Vector2(p).length()
		if d <= 0.62 * util: continue
		var mini := bruit * PART_BRUIT_CAP + 6.0
		var large := clampf(0.22 * minf(rx, rz), mini, maxf(util - d, mini))
		caps.append([p.x, p.y, large, large])
	return sortie

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
	var iles := _les_iles(donnees, graine)
	## ⭐ LE RECALAGE DES ÎLES. Deux corrections d'un coup, et la seconde est une
	## demande du client : « qu'aucune île ne se touche, qu'on puisse voir de
	## l'espace entre ». Voir `_ecarter_les_iles`. Le tableau rendu dit de
	## combien CHAQUE île a bougé — les gares du fichier suivront (voir
	## `_les_reperes`), sans quoi une île déplacée laisserait ses quais
	## derrière elle, en pleine mer.
	var recalage := _ecarter_les_iles(iles, donnees)
	var plan := {
		"version": 3,
		"nom": "Archipel des Aurones",
		"graine": graine,
		"taille": [TAILLE.x, TAILLE.y],
		## 1. les côtes et le relief.
		"iles": iles,
		"recalage": recalage,
		"detroits": _les_detroits(donnees, iles, recalage),
		"monts": [], "plaines": [],
		## 2. les gares et les stations — le squelette.
		"stations": [], "lieux_dits": [],
		## 3. les six réseaux. `lignes` porte le train, le métro, le tram, le bus
		##    et le ferry ; `routes` porte la voirie, qui est le sixième et le
		##    seul qui descende en 3D telle quelle.
		"lignes": [], "routes": [], "ponts": [],
		## 4. LES QUARTIERS, EN TACHES ET PAS EN CARRÉS (voir `QUARTIERS`).
		##    `implantations` reste pour les grandes pièces posées à l'unité
		##    (une ferme, un aérodrome) ; il est vide aujourd'hui.
		"quartiers": [], "implantations": [], "rivieres": [],
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
	## ⚠⚠ LES RIVIÈRES AVANT TOUT LE RESTE DU PLAN, ET C'EST UNE LEÇON PAYÉE. Une
	## rivière est de l'EAU posée en travers de la terre : creusée après les
	## stations, elle en a noyé quatre d'un coup — et une station noyée ne se voit
	## pas sur une image de mille pixels. Creusée AVANT, la voirie la longe, les
	## stations l'évitent, et le recensement des ouvrages lui pose ses ponts.
	## `contexte` est REFAIT tout de suite : tout ce qui suit doit voir cette eau.
	plan["rivieres"] = _les_rivieres(plan, ctx, alea)
	ctx = contexte(plan)
	## ⚠ LES PORTS SUR LEUR RIVAGE AVANT LA VOIRIE : les routes et les lignes
	## vont chercher les stations par leur nom, et une station déplacée après
	## coup laisserait tout le réseau pointer l'ancien endroit.
	_les_ports_au_bord(plan, ctx)
	_la_voirie(plan, ctx, alea)
	_le_graphe_routier(plan, ctx, alea)
	_les_reseaux(plan, ctx, alea, donnees)
	_les_voies_maritimes(plan, ctx, alea)
	_les_ponts_du_fichier(plan, donnees)
	_les_stations(plan, ctx)
	_recenser_les_ponts(plan, ctx)
	## 4. LES QUARTIERS — après les stations, qui leur servent d'ancre.
	plan["quartiers"] = _les_quartiers(plan)
	_indexer_les_quartiers(plan, ctx)
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

## ⭐ CHARGER UN PLAN DÉJÀ BÂTI. Le bâtir coûte une quinzaine de secondes : au
## navigateur, c'est un onglet figé et un joueur qui croit que la page a planté.
## Le plan est donc cuit d'avance par `outils/pays.gd`, versionné dans
## `cartes/`, et relu ici en quelques millisecondes.
##
## ⚠ RIEN NE SE RECALCULE À LA LECTURE. Un plan relu doit être identique au plan
## écrit, sinon deux machines ne verraient pas le même pays — c'est la même
## garantie que pour les fenêtres, à l'échelle du fichier.
const PLAN_CUIT := "res://cartes/aurones-plan.json"

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
	var vus := {}
	var index := 0
	for cle in donnees["islands"]:
		var ile := _ile_depuis(donnees["islands"][cle], String(cle), index, graine)
		vus[String(ile["nom"])] = true
		sortie.append(ile)
		index += 1
	# ⚠ ET LES ÎLES QUE LE FICHIER NE CONNAÎT PAS. Le relevé en dessine onze, le
	# fichier en décrit dix : la onzième n'est pas une erreur du relevé, c'est un
	# oubli du fichier. On la garde.
	for e in ILES_SECOURS:
		var mien: Dictionary = e
		if vus.has(String(mien["nom"])): continue
		sortie.append(mien.duplicate(true))
	return sortie

## ⭐ LE RELEVÉ, PAR NOM D'ÎLE. Le fichier de l'archipel est une SOURCE
## D'INFORMATION, pas une autorité : il nomme les gares et place les ponts mieux
## que le relevé au pixel, mais ses cercles sont plus petits que les îles que le
## client a dessinées. Là où le relevé est plus grand, LE RELEVÉ GAGNE — et avec
## le rayon, on reprend sa forme complète (centre, lobes, caps, golfes), parce
## qu'un rayon repris sans ses lobes ne fait que gonfler un cercle.
static func _releve(nom: String) -> Dictionary:
	for e in ILES_SECOURS:
		var mien: Dictionary = e
		if String(mien["nom"]) == nom: return mien
	return {}

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
	var nom := String(src.get("name", cle))
	# LE RELEVÉ D'ABORD S'IL EST PLUS GRAND (voir `_releve`). On reprend alors
	# TOUT de lui — centre, rayons, bruit, lobes, golfes — et on n'emprunte au
	# fichier que ce qu'il fait mieux : les gares, qui vont se tailler leurs caps
	# plus bas, par-dessus ceux du relevé.
	var mien := _releve(nom)
	if not mien.is_empty():
		var rm: Array = mien["r"]
		if maxf(float(rm[0]), float(rm[1])) > r:
			return _ile_du_releve(mien, src, cle)
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
	# ⚠⚠ LA RÈGLE QUI GOUVERNE TOUTE EAU DOUCE, ET QU'ON OUBLIE TOUJOURS : dans
	# ce moteur, `TerrainV2.maillage_eau` pose TOUTE nappe à `NIVEAU_MER`. Une
	# rivière perchée est donc IMPOSSIBLE tant qu'il n'y aura pas une cote par
	# pièce d'eau : nos rivières sont des rivières de plaine côtière, creusées
	# jusqu'au niveau de la mer — des estuaires qui remontent dans les terres.
	# C'est aussi ce qui les empêche de monter dans les collines : une rivière
	# qui traverserait un mont de 70 m y ouvrirait un canyon de 70 m.
	# `lacs` reste vide, et le mécanisme ne coûte qu'un `has()` par case.
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
	# ⚠ LES LITS EN DERNIER, ET C'EST UNE DÉPENDANCE, PAS UN GOÛT : creuser une
	# rivière demande l'altitude du sol, donc `sol_en`, donc les plateaux.
	_creuser_les_lits(plan, ctx)
	_indexer_les_quartiers(plan, ctx)
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
## ⭐⭐⭐ LE PAYS EST PLAT, ET C'EST UNE DÉCISION DU CLIENT.
##
## « Tu vas faire en sorte que la map n'ait aucune hauteur car ça rend moche :
## tout doit être au niveau 0 sauf les autoroutes et les rails » (17/09).
##
## Le relief du pays — plaines, collines, monts, aplanissement urbain — est
## donc ÉTEINT, pas effacé : tout le calcul reste écrit juste en dessous, et
## `RELIEF` le rallume d'un mot. Le supprimer aurait coûté une semaine à
## réécrire le jour où il le redemande.
##
## ⚠ CE QUI RESTE, ET POURQUOI. La MER et les LITS DE RIVIÈRE gardent leur
## creusement (ce n'est pas du relief, c'est ce qui fait qu'on voit de l'eau),
## et l'ESTRAN garde ses deux cases de descente vers la mer : sans lui, une
## terre à zéro contre une mer à −2,85 ferait une falaise de trois mètres tout
## autour de chaque île. Le reste est plat.
##
## ⚠ ET UN SEUL ENDROIT SUFFIT. `remplir_terrain` (le décor), `sol_en` (le
## plan, les ponts, les chemins) et `palier_en` passent TOUS par ici : il ne
## peut donc pas y avoir de désaccord entre ce qu'on regarde et ce qu'on
## traverse. C'est pour ça que le levier est ici et nulle part ailleurs.
const RELIEF := false

static func _altitude_terre(plan: Dictionary, ctx: Dictionary, i: int, j: int,
		inl: float) -> float:
	if not RELIEF: return 0.0
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
			# ⭐⭐⭐ PAS DE CAILLOU D'UNE CASE AU MILIEU DE L'OCÉAN.
			#
			# Mesuré sur toute la carte : VINGT-TROIS masses de terre distinctes
			# pour ONZE îles déclarées. Les onze vraies y sont, de 67 656 cases à
			# 1 239 ; les douze autres sont des miettes — une de 328 cases, une
			# de 16, deux de 2, et HUIT D'UNE SEULE CASE. Vingt mètres de terre
			# en pleine mer, que le bruit du trait de côte a laissés derrière
			# lui, et sur lesquels le pays peut poser un quartier.
			#
			# ⚠ PAS DE REMPLISSAGE PAR DIFFUSION ICI, ET C'EST LA CONTRAINTE QUI
			# DÉCIDE DE LA MÉTHODE. Le terrain se remplit PAR FENÊTRE : une
			# diffusion ne verrait qu'un morceau de chaque île et raserait de la
			# vraie terre au bord de la fenêtre. On teste donc le VOISINAGE, qui
			# est local — et on le teste avec `distance_signee`, pas avec la
			# grille : c'est une fonction de la position absolue, donc elle
			# répond juste même pour une case qui tombe hors de la fenêtre.
			if d <= 0.0 and _isolee(plan, ctx, wi, wj):
				v.eau[k] = 1
				v.altitude[k] = PREMIER_FOND
				v.matiere[k] = Ville2.M_SABLE
				continue
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
	return _sol_creuse(plan, ctx, c, _altitude_terre(plan, ctx, c.x, c.y, -d))

## ⚠⚠ LE LIT DE LA RIVIÈRE COMPTE COMME DE L'EAU, ET IL FAUT LE DIRE ICI. Le
## creusement est appliqué dans `remplir_terrain` ; tant que `sol_en` et
## `terre_en` l'ignoraient, le PLAN croyait marcher sur de la terre là où le
## TERRAIN posait de la rivière — et deux stations se sont retrouvées au milieu
## de l'eau sans que rien ne le signale. Une seule vérité sur ce qui est mouillé.
static func _sol_creuse(plan: Dictionary, ctx: Dictionary, c: Vector2i, y: float) -> Array:
	var lit: Dictionary = ctx["lit"]
	if not lit.has(c): return [y, 0.0]
	var creuse := y - float(lit[c])
	if creuse <= TerrainV2.NIVEAU_MER + 0.35:
		return [minf(creuse, TerrainV2.NIVEAU_MER - 2.0), 1.0]
	return [creuse, 0.0]

## ⚠ DEUX VOISINES, PAS UNE. Une case seule n'en a aucune et disparaît ; une
## PAIRE de cases s'en donne une l'une à l'autre et survivrait au seuil de 1 —
## or deux cases de terre en pleine mer, c'est le même défaut en plus large. À
## deux voisines, la paire part aussi, et une pointe de cap en garde toujours
## trois ou quatre : le trait de côte, lui, n'est pas touché.
const VOISINES_MINI := 2

## ⚠ CE QUE CETTE RÈGLE NE SAIT PAS FAIRE, ET POURQUOI ON S'ARRÊTE LÀ.
## Mesuré avant : 23 masses de terre pour 11 îles. Après : 15 — les onze vraies
## îles intactes, au caillou près, plus un îlot de 328 cases et un de 15 qui sont
## de vrais bouts de terre, plus DEUX cases seules qui résistent.
##
## Elles résistent parce qu'un test de voisinage est LOCAL par construction :
## ces deux-là s'appuient sur des voisines qui tiennent debout au premier coup
## d'œil et que la règle noie ensuite, et rien de local ne peut voir cette
## chaîne. Seul un remplissage par diffusion sur toute la carte la verrait — et
## on ne peut pas en faire un ici, puisque le terrain se calcule PAR FENÊTRE.
##
## Deux cases sur un million, soit quarante mètres carrés de terre perdue au
## milieu de quatre cents kilomètres carrés : le prix d'un balayage global de la
## carte à chaque ouverture de fenêtre ne vaut pas ces deux cailloux.

## ⚠⚠⚠ UNE VOISINE « PAS EN MER » N'EST PAS FORCÉMENT DE LA TERRE.
##
## Mon premier test comptait comme voisine toute case hors de la mer. Il restait
## trois cailloux d'une case, et la mesure a dit pourquoi : deux étaient cernés
## de LAC, le troisième de LIT DE RIVIÈRE. Ni l'un ni l'autre n'est de la mer,
## donc ils passaient pour de la terre — et le caillou gardait ses deux voisines
## sur le papier tout en se retrouvant seul au milieu de l'eau dans le terrain.
## C'est exactement la faute qui avait mis deux stations dans une rivière (voir
## `sol_en`) : UNE SEULE VÉRITÉ SUR CE QUI EST MOUILLÉ.
static func _terre_ferme(plan: Dictionary, ctx: Dictionary, x: int, y: int) -> bool:
	if distance_signee(plan, ctx, x, y) > 0.0: return false
	var c := Vector2i(x, y)
	if (ctx["lacs"] as Dictionary).has(c): return false
	if not (ctx["lit"] as Dictionary).has(c): return true
	return float(sol_en(plan, ctx, c)[1]) < 0.5

## ⚠⚠ ET IL FAUT DEUX NIVEAUX, PARCE QUE NOYER UNE CASE EN ISOLE UNE AUTRE.
## Après une passe simple, il restait TROIS cailloux d'une case sur vingt-trois
## masses : chacun s'appuyait sur deux voisines qui étaient elles-mêmes des
## cailloux, condamnées au même moment. Une case ne compte donc comme voisine
## que si elle TIENT toute seule — et le second niveau, lui, s'arrête là :
## au-delà, on descendrait une chaîne sans fin pour quelques mètres carrés.
##
## Le coût reste modeste parce que le test sort tôt : dès quatre voisines
## franches, la case est manifestement en pleine terre et on ne va pas plus loin
## — ce qui est le cas de 99 % des cases d'une île.
static func _isolee(plan: Dictionary, ctx: Dictionary, x: int, y: int,
		profond := true) -> bool:
	var n := 0
	var douteuses: Array = []
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			if di == 0 and dj == 0: continue
			if not _terre_ferme(plan, ctx, x + di, y + dj): continue
			n += 1
			if n >= 4: return false
			douteuses.append(Vector2i(x + di, y + dj))
	if n < VOISINES_MINI: return true
	if not profond: return false
	# Deux ou trois voisines seulement : elles ne comptent que si elles tiennent.
	var solides := 0
	for c0 in douteuses:
		var c: Vector2i = c0
		if _isolee(plan, ctx, c.x, c.y, false): continue
		solides += 1
		if solides >= VOISINES_MINI: return false
	return true

static func terre_en(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= TAILLE.x or c.y >= TAILLE.y: return false
	if distance_signee(plan, ctx, c.x, c.y) > 0.0: return false
	# ⚠ LA MÊME RÈGLE QUE LE TERRAIN, SINON LES DEUX SE CONTREDISENT. Le plan
	# décide où l'on peut poser une rue ou un port ; le terrain décide où il y a
	# du sol. Si le premier croit qu'un caillou d'une case est de la terre et que
	# le second l'a noyé, on pose une station sur l'eau — c'est déjà arrivé avec
	# les lits de rivière (voir `sol_en`), et c'est la même leçon.
	if _isolee(plan, ctx, c.x, c.y): return false
	var lit: Dictionary = ctx["lit"]
	if not lit.has(c): return true
	return float(sol_en(plan, ctx, c)[1]) < 0.5

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
	var recalage: Array = plan.get("recalage", [])
	var index := 0
	for cle in donnees.get("islands", {}):
		var ile: Dictionary = donnees["islands"][cle]
		# ⚠⚠ LA GARE SUIT SON ÎLE, ET C'EST LA CORRECTION LA PLUS RENTABLE DU
		# LOT. Le fichier donne les gares en kilomètres sur SES cercles ; notre
		# île est plus grande, plus loin, et le fichier l'ignore. Sans ce
		# décalage, Port-Nord se retrouvait à cinq cents mètres dans les terres
		# et les gares du chapelet à la limite du rivage.
		var dep: Vector2i = recalage[index] if index < recalage.size() else Vector2i.ZERO
		index += 1
		for s in ile.get("stations", []):
			var f: Dictionary = s
			var c := _point(f["pos"]) + dep
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
## ⚠⚠ UN DÉTROIT EST UN BRAS DE MER, PAS UN TROU. Il valait 70 cases de large —
## 1,4 km — et le client l'a vu tout de suite : « sans les gros trous ». Une
## découpe de cette taille ne se lit plus comme un chenal, elle se lit comme un
## morceau d'île manquant. 14 cases = 280 m : un bras de mer qu'un pont franchit,
## et qui ne mange pas la côte autour.
const DETROIT_TRAVERS := 14.0        ## largeur minimale de la découpe, en travers
const DETROIT_DEBORD := 1.15         ## ce que le chenal dépasse de la travée, en part

## ⚠ NI LES OUVRAGES QUE L'AGRANDISSEMENT A MIS À TERRE. Le fichier place ses
## ponts sur SES cercles ; là où le relevé est plus grand, un de ces ponts se
## retrouve à un kilomètre à l'intérieur des terres. Lui creuser son chenal
## ouvrait un lagon en plein milieu de l'Île Sud-Est. Un pont dont les DEUX
## extrémités sont bien à l'intérieur d'une même île n'enjambe plus rien : il
## devient une route, et on ne creuse pas la mer sous une route.
const DEDANS := 0.80                 ## part du rayon en deçà de laquelle on est « en pleine terre »

static func _les_detroits(donnees: Dictionary, iles: Array, recalage: Array) -> Array:
	var sortie: Array = []
	for b in donnees.get("bridges", []):
		var f: Dictionary = b
		if String(f.get("type", "road")) == "rail_tunnel": continue
		var t := _travee(f, iles, recalage)
		if t.is_empty(): continue
		var a: Vector2i = t[0]
		var z: Vector2i = t[1]
		if _meme_terre(iles, a, z): continue
		var m := (a + z) / 2
		# ⚠ ET IL NE DÉPASSE PLUS LA TRAVÉE QUE DE QUINZE POUR CENT. Il valait
		# trois fois la demi-travée : un pont de 600 m creusait 1,8 km de côte.
		var demi := float(maxi(absi(z.x - a.x), absi(z.y - a.y))) * 0.5 * DETROIT_DEBORD
		var travers := DETROIT_TRAVERS
		if absi(z.x - a.x) >= absi(z.y - a.y):
			sortie.append([m.x, m.y, demi, travers, DETROIT_BRUIT])
		else:
			sortie.append([m.x, m.y, travers, demi, DETROIT_BRUIT])
	return sortie

## Les deux bouts tombent-ils en pleine terre sur la MÊME île ? Un test
## d'ellipse, pas de contour : le contour n'existe pas encore quand les détroits
## se décident, et `DEDANS` garde assez de marge pour qu'un bruit de côte ne
## puisse pas démentir la réponse.
static func _meme_terre(iles: Array, a: Vector2i, z: Vector2i) -> bool:
	for e in iles:
		var ile: Dictionary = e
		var c := case_de(ile["c"])
		var r: Array = ile["r"]
		var rx := float(r[0]) * DEDANS
		var rz := float(r[1]) * DEDANS
		if _dans_l_ellipse(a, c, rx, rz) and _dans_l_ellipse(z, c, rx, rz):
			return true
	return false

static func _dans_l_ellipse(p: Vector2i, c: Vector2i, rx: float, rz: float) -> bool:
	var dx := float(p.x - c.x) / maxf(rx, 1.0)
	var dz := float(p.y - c.y) / maxf(rz, 1.0)
	return dx * dx + dz * dz <= 1.0

## LA TRAVÉE D'UN PONT DU FICHIER, ALIGNÉE SUR SON AXE DOMINANT. Les deux
## extrémités données sont des points quelconques (9,6 / 7,4 vers 9,7 / 6,6) :
## un pont en biais ne se pave pas, et `generateur_pays` le sauterait en silence.
## Partagée par les détroits et les ponts — deux calculs séparés dériveraient, et
## le chenal ne tomberait plus sous l'ouvrage.
## ⚠⚠ UN PONT DU FICHIER EST DONNÉ DANS LES COORDONNÉES DU FICHIER, et nos îles
## ont bougé — recalées sur le relevé, puis écartées les unes des autres. Sans
## recalage, le chenal d'un pont se creuse à l'ancienne place : le 16/09 il
## tranchait l'Île Centrale en deux, et le compte des masses de terre est passé
## de 11 à 13 sans autre signe. Chaque extrémité suit l'île dont elle est la plus
## proche — un pont relie deux îles, ses deux bouts ne bougent donc pas
## forcément du même vecteur.
static func _travee(f: Dictionary, iles: Array, recalage: Array) -> Array:
	var pts: Array = f.get("points", [])
	if pts.size() < 2: return []
	var a := _recaler(iles, recalage, _point(pts[0]))
	var z := _recaler(iles, recalage, _point(pts[pts.size() - 1]))
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
		var t := _travee(f, plan["iles"], plan.get("recalage", []))
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
## ⚠ CINQ DEPUIS LE 15/09, ET LE DIX A COÛTÉ DEUX LIGNES DE FERRY. En
## agrandissant les îles, le bras de mer entre l'Île Nord et l'Île Centrale est
## tombé à trente et une cases : avec un treillis de dix et une marge de côte de
## quatorze, il ne restait AUCUN nœud navigable dedans, et F1 comme F3 rendaient
## « pas de passage par la mer » — deux lignes disparues en silence. À cinq, le
## chenal porte cinq nœuds. Le coût : quatre fois plus de nœuds à explorer, soit
## quarante mille — quelques dizaines de millisecondes.
const PAS_MER := 7
## Le rayon, en cases, dans lequel une case de terre rend la navigation chère.
const MARGE_COTE := 9
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
## ⭐⭐ LA MER, ET PAS SEULEMENT « CE QUI N'EST PAS DE LA TERRE ». Depuis que le
## pays a des rivières, `terre_en` rend faux sur un lit de rivière : un ferry qui
## cherchait « la première case qui n'est pas de la terre » s'amarrait dans LE RU
## VERT, à trois cases de large, et le treillis de navigation n'y trouvait aucun
## nœud — F1 et F3 rendaient « pas de passage par la mer » sans qu'on sache
## pourquoi. La mer, c'est le champ de distance signée positif ; une rivière est
## de la terre creusée.
static func mer_en(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= TAILLE.x or c.y >= TAILLE.y: return false
	return distance_signee(plan, ctx, c.x, c.y) > 0.0

## ⭐ LES PORTS SUR LA CÔTE, ET C'EST UNE CORRECTION D'ÉCHELLE. Le fichier place
## les trois ports en kilomètres sur SES cercles ; nos îles sont plus grandes, et
## Port-Nord s'est retrouvé à cinq cents mètres DANS LES TERRES — un port de
## commerce sans eau. On les ramène donc sur leur rivage, avant que la voirie et
## les réseaux n'aillent les chercher.
const PORTS := ["Port-Nord", "Port-des-Alpes", "Gare Maritime"]

static func _les_ports_au_bord(plan: Dictionary, ctx: Dictionary) -> void:
	for s in plan["stations"]:
		var f: Dictionary = s
		if not PORTS.has(String(f["nom"])): continue
		var q := _bord_de_mer(plan, ctx, case_de(f["c"]))
		if q.x < 0: continue
		f["c"] = [q.x, q.y]

## La case de TERRE la plus proche qui ait la mer à deux cases : un quai.
static func _bord_de_mer(plan: Dictionary, ctx: Dictionary, ou: Vector2i) -> Vector2i:
	# ⚠ ON PARCOURT LE PÉRIMÈTRE DE L'ANNEAU, PAS SON CARRÉ. Balayer le carré et
	# jeter l'intérieur coûte r² par anneau, donc r³ en tout : sur cent vingt
	# anneaux, deux millions de sondes par port, et le plan passait de quatre à
	# trente et une secondes. Le périmètre coûte r.
	for r in 120:
		for c in _anneau(ou, r):
			var d: Vector2i = c
			if not terre_en(plan, ctx, d): continue
			for p in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				if mer_en(plan, ctx, d + (p as Vector2i)): return d
	return Vector2i(-9999, -9999)

## Les cases du CARRÉ de rayon `r` autour de `ou` — son périmètre seulement.
static func _anneau(ou: Vector2i, r: int) -> Array:
	if r == 0: return [ou]
	var sortie: Array = []
	for t in range(-r, r + 1):
		sortie.append(ou + Vector2i(t, -r))
		sortie.append(ou + Vector2i(t, r))
	for t2 in range(-r + 1, r):
		sortie.append(ou + Vector2i(-r, t2))
		sortie.append(ou + Vector2i(r, t2))
	return sortie

static func _rade(plan: Dictionary, ctx: Dictionary, ou: Vector2i) -> Vector2i:
	if ou.x < 0: return Vector2i(-1, -1)
	if mer_en(plan, ctx, ou): return ou
	for r in range(1, 60):
		for k in range(0, 8 * r):
			var a := TAU * float(k) / float(8 * r)
			var c := ou + Vector2i(int(round(cos(a) * float(r))), int(round(sin(a) * float(r))))
			if mer_en(plan, ctx, c): return c
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
				if mer_en(plan, ctx, n * PAS_MER): return n
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


## ⭐⭐ ÉCARTER LES ÎLES — « qu'aucune île ne se touche et qu'on puisse voir de
## l'espace entre » (client, 16/09).
##
## Deux décalages s'additionnent ici, et il faut les distinguer :
##
## 1. LE RECALAGE SUR LE RELEVÉ. Là où le relevé a gagné (île plus grande), son
##    centre n'est pas celui du fichier. Tout ce que le fichier place — les
##    gares — doit suivre le même décalage, sinon un port se retrouve dans les
##    terres. C'est le défaut qui a coûté deux lignes de ferry.
## 2. L'ÉCARTEMENT. On mesure, pour chaque paire, le vide entre les deux
##    enveloppes SUR LA LIGNE DES CENTRES, bruit de côte compris ; s'il manque
##    de quoi voir la mer, on repousse les deux îles d'un demi-manque chacune.
##    Quelques passes suffisent : chaque passe corrige le pire, la suivante ce
##    qu'elle a créé.
##
## ⚠ ON DÉPLACE, ON NE RÉTRÉCIT PAS. Rétrécir aurait été plus simple — et aurait
## défait l'agrandissement que le client venait de demander.
const ECART_ILES := 26.0             ## vide minimal entre deux côtes, en cases (520 m)
const PASSES_ECART := 6
const BORD_CARTE := 30.0             ## on ne pousse pas une île hors du monde

static func _ecarter_les_iles(iles: Array, donnees: Dictionary) -> Array:
	var recalage: Array = []
	var centres: Array = []
	# 1. le recalage sur le relevé, île par île, dans l'ordre du fichier.
	var index := 0
	var origines: Array = []
	for cle in donnees.get("islands", {}):
		var f: Dictionary = donnees["islands"][cle]
		origines.append(_point(f["center"]))
		index += 1
	for k in iles.size():
		var ile: Dictionary = iles[k]
		var c := case_de(ile["c"])
		centres.append(Vector2(c))
		var o: Vector2i = origines[k] if k < origines.size() else c
		recalage.append(c - o)
	# 2. l'écartement, par relaxation.
	for _p in PASSES_ECART:
		for a in iles.size():
			for b in range(a + 1, iles.size()):
				var ca: Vector2 = centres[a]
				var cb: Vector2 = centres[b]
				var axe := cb - ca
				var d := axe.length()
				if d < 0.001: continue
				var u := axe / d
				var vide := d - _rayon_vers(iles[a], u) - _rayon_vers(iles[b], -u)
				if vide >= ECART_ILES: continue
				var pousse := (ECART_ILES - vide) * 0.5
				centres[a] = ca - u * pousse
				centres[b] = cb + u * pousse
	# 3. on réécrit les centres et on ajoute le déplacement au recalage.
	for k2 in iles.size():
		var ile2: Dictionary = iles[k2]
		var avant := case_de(ile2["c"])
		var v: Vector2 = centres[k2]
		var apres := Vector2i(
			clampi(roundi(v.x), int(BORD_CARTE), TAILLE.x - int(BORD_CARTE)),
			clampi(roundi(v.y), int(BORD_CARTE), TAILLE.y - int(BORD_CARTE)))
		ile2["c"] = [apres.x, apres.y]
		recalage[k2] = (recalage[k2] as Vector2i) + (apres - avant)
	return recalage

## Le décalage à appliquer à un point du fichier : celui de l'île dont il était
## le plus proche AVANT déplacement. On compare donc aux centres d'origine —
## centre actuel moins recalage —, pas aux centres d'arrivée : après un
## écartement, la plus proche des nouvelles positions n'est pas forcément celle
## à laquelle le point appartenait.
static func _recaler(iles: Array, recalage: Array, c: Vector2i) -> Vector2i:
	var mieux := -1
	var d2 := 1.0e20
	for k in iles.size():
		if k >= recalage.size(): continue
		var ile: Dictionary = iles[k]
		var origine: Vector2i = case_de(ile["c"]) - (recalage[k] as Vector2i)
		var e := Vector2(c - origine).length_squared()
		if e < d2:
			d2 = e
			mieux = k
	if mieux < 0: return c
	return c + (recalage[mieux] as Vector2i)

## Le rayon de l'enveloppe d'une île dans la direction `u`, bruit de côte
## compris. C'est un rayon d'ELLIPSE, pas de cercle : nos îles sont toutes plus
## larges que hautes ou l'inverse, et prendre le grand rayon les écarterait deux
## fois trop.
static func _rayon_vers(e, u: Vector2) -> float:
	var ile: Dictionary = e
	var r: Array = ile["r"]
	var rx := maxf(float(r[0]), 1.0)
	var rz := maxf(float(r[1]), 1.0)
	var dx := u.x / rx
	var dz := u.y / rz
	var n := sqrt(dx * dx + dz * dz)
	if n < 0.000001: return maxf(rx, rz)
	return 1.0 / n + float(ile.get("bruit", 10.0))

# ══════════════════════════════════════════════════════════════════ LES RIVIÈRES

## ⭐ QUATRE RIVIÈRES, ET PAS UNE DE PLUS. « Je voulais juste quelques rivières » :
## ce sont des cours d'eau de plaine côtière, pas des chenaux de navigation. Une
## rivière remonte depuis son embouchure jusqu'à ce que le terrain se relève —
## c'est un ESTUAIRE, et c'est la seule eau douce que ce moteur sache poser
## (voir la règle de `maillage_eau` dans `contexte`).
##
## `[île, angle de l'embouchure en degrés, nom]`. L'angle est celui du rayon qui
## part du centre de l'île : 0° à l'est, 90° au sud.
const RIVIERES := [
	[CENTRALE, 118.0, "La Sèvre"],
	[NORD, 130.0, "Le Ru Vert"],              ## descend de la Vallée Verte
	[SUDEST, 137.0, "La Pinède"],             ## descend de la Vallée des Pins
	[SUDEST, -40.0, "L'Aube"],                ## descend vers la Pointe de l'Aube
]

const RIVIERE_LONG := 150            ## remontée maximale, en cases (3 km)
const RIVIERE_PLAFOND := 4           ## on s'arrête quand le sol dépasse 4 paliers (20 m)
const RIVIERE_LARGE := 1.3           ## demi-largeur du lit, en cases (~50 m de rivière)
const RIVIERE_BERGE := 1.4           ## la berge, en plus du lit
const RIVIERE_MEANDRE := 7.0         ## amplitude du méandre, en cases
const RIVIERE_FOND := 1.6            ## ce qu'on creuse SOUS le niveau de la mer

## ⚠ UNE RIVIÈRE SE REMONTE, ELLE NE SE DESCEND PAS. Partir d'une source et
## chercher la mer, c'est un problème d'écoulement — il faut un champ de pente
## fiable, et le nôtre est bruité : la rivière tourne en rond ou s'arrête dans
## une cuvette. Partir de l'EMBOUCHURE et remonter tant que le sol est bas donne
## le même dessin, sans jamais échouer : la mer est trouvée d'avance.
static func _les_rivieres(plan: Dictionary, ctx: Dictionary, alea: RandomNumberGenerator) -> Array:
	var sortie: Array = []
	var iles: Array = plan["iles"]
	for e in RIVIERES:
		var f: Array = e
		var k := int(f[0])
		if k >= iles.size(): continue
		var pts := _remonter(plan, ctx, k, deg_to_rad(float(f[1])), alea)
		if pts.size() < 8: continue
		sortie.append({"nom": String(f[2]), "points": pts, "large": RIVIERE_LARGE})
	return sortie

static func _remonter(plan: Dictionary, ctx: Dictionary, k: int, angle: float,
		alea: RandomNumberGenerator) -> Array:
	var c := centre_ile(plan, k)
	var r := rayon_ile(plan, k)
	var u := Vector2(cos(angle), sin(angle))
	# 1. L'EMBOUCHURE : la dernière case de terre sur le rayon.
	var bouche := Vector2i(-1, -1)
	var pas := 1.0
	while pas < maxf(r.x, r.y) * 1.6:
		var p := Vector2i(roundi(float(c.x) + u.x * pas), roundi(float(c.y) + u.y * pas))
		if not terre_en(plan, ctx, p):
			break
		bouche = p
		pas += 1.0
	if bouche.x < 0: return []
	# 2. LA REMONTÉE, vers le centre, en serpentant.
	var v := -u
	var n := Vector2(-v.y, v.x)
	var f1 := alea.randf_range(0.030, 0.055)
	var f2 := alea.randf_range(0.075, 0.115)
	var p1 := alea.randf_range(0.0, TAU)
	var p2 := alea.randf_range(0.0, TAU)
	var pts: Array = []
	var dernier := Vector2i(-9999, -9999)
	for t in RIVIERE_LONG:
		var d := float(t)
		# ⚠ LE MÉANDRE S'OUVRE EN REMONTANT. À l'embouchure la rivière est droite
		# (une enveloppe qui part de zéro) : sinon le premier méandre tombe dans
		# la mer et l'estuaire se dédouble en delta, ce qui n'est pas demandé.
		var ouvre := clampf(d / 26.0, 0.0, 1.0)
		var lat := RIVIERE_MEANDRE * ouvre * (0.62 * sin(TAU * f1 * d + p1)
			+ 0.38 * sin(TAU * f2 * d + p2))
		var q := Vector2(float(bouche.x), float(bouche.y)) + v * d + n * lat
		var cc := Vector2i(roundi(q.x), roundi(q.y))
		if cc.x < 2 or cc.y < 2 or cc.x >= TAILLE.x - 2 or cc.y >= TAILLE.y - 2: break
		# On s'arrête quand le sol se relève : une rivière creusée jusqu'au
		# niveau de la mer à travers un mont de 70 m serait un canyon.
		if terre_en(plan, ctx, cc) and palier_en(plan, ctx, cc) > RIVIERE_PLAFOND: break
		if cc != dernier:
			pts.append([cc.x, cc.y])
			dernier = cc
	return pts

## LE CREUSEMENT DU LIT, dans le contexte. `ctx["lit"]` porte, par case, LA
## PROFONDEUR À RETIRER au terrain ; `remplir_terrain` fait la soustraction et
## met de l'eau si le résultat passe sous la mer.
##
## ⚠ LA BERGE N'EST PAS UN DÉTAIL. Sans elle, le lit est une tranchée à parois
## verticales : la rivière se lit comme une saignée, pas comme un cours d'eau. La
## couronne qui entoure le lit reçoit une fraction décroissante du creusement, et
## c'est ce qui donne le talus.
static func _creuser_les_lits(plan: Dictionary, ctx: Dictionary) -> void:
	var lit: Dictionary = ctx["lit"]
	var portee := int(ceil(RIVIERE_LARGE + RIVIERE_BERGE)) + 1
	for e in plan.get("rivieres", []):
		var f: Dictionary = e
		var large := float(f.get("large", RIVIERE_LARGE))
		for p in f["points"]:
			var a := case_de(p)
			for dj in range(-portee, portee + 1):
				for di in range(-portee, portee + 1):
					var c := Vector2i(a.x + di, a.y + dj)
					if c.x < 0 or c.y < 0 or c.x >= TAILLE.x or c.y >= TAILLE.y: continue
					var d := Vector2(float(di), float(dj)).length()
					if d > large + RIVIERE_BERGE: continue
					# ⚠ PAS `sol_en` ICI : il lit `ctx["lit"]`, qu'on est en train
					# d'écrire — le creusement dépendrait de l'ordre des cases.
					var ds := distance_signee(plan, ctx, c.x, c.y)
					if ds > 0.0: continue                     ## déjà la mer
					var y := _altitude_terre(plan, ctx, c.x, c.y, -ds)
					# Le creusement PLEIN dans le lit, dégressif sur la berge.
					var part := 1.0
					if d > large:
						part = 1.0 - (d - large) / RIVIERE_BERGE
					var vise := TerrainV2.NIVEAU_MER - RIVIERE_FOND
					var creuse := (y - vise) * part
					if creuse <= 0.0: continue
					if creuse > float(lit.get(c, 0.0)): lit[c] = creuse


# ══════════════════════════════════════════════════ LES QUARTIERS, EN TACHES

## ⭐⭐ UN QUARTIER N'EST PAS UN CARRÉ, ET LES NEUF TÉMOINS NE SONT PAS DES TAMPONS.
##
## La première version posait les témoins tels quels, en blocs de 40 × 40 collés
## les uns aux autres. Le client a tranché, et il a raison : « de base les témoins
## sont pas là pour être collés tels quels mais pour établir des règles par
## quartier », et « on va partir sur quelque chose d'organique donc non carré ».
##
## Donc : un quartier est une TACHE — un centre, deux rayons, un contour bruité —
## exactement comme une île. C'est la même machine (`_lobe`, l'index par secteur,
## le bruit de contour), et c'est voulu : une forme qui a déjà fait ses preuves à
## l'échelle de l'archipel n'a pas besoin d'être réinventée à l'échelle de la
## ville.
##
## Ce que le témoin donne alors, ce n'est plus son plan de masse : c'est sa
## CHARTE — sa liste de modèles et leurs poids, l'écart entre ses rues, la
## matière de son sol hors chaussée, la densité de son mobilier. Le remplissage
## la lira quartier par quartier (chantier suivant).
##
## ⚠ LE RANG DÉCIDE, PAS L'ORDRE. Deux taches se recouvrent toujours — une
## vieille ville est DANS un centre, un front de mer MORD le port. Le rang le
## plus haut gagne la case. Sans lui, le quartier peint en dernier gagnerait, et
## le dessin dépendrait de l'ordre de la table : le genre de règle qu'on ne
## retrouve jamais trois semaines plus tard.
const RANG_CAMPAGNE := 0
## ⚠ L'AMPLITUDE FAIT LA DIFFÉRENCE ENTRE UNE TACHE ET UN DISQUE. À 0,16 du
## rayon, le contour d'un centre-ville de 34 cases bouge de cinq cases : sur une
## image d'île entière, ça se lit comme un CERCLE PARFAIT posé sur la ville, et
## c'est le défaut le plus voyant du premier jet. À 0,30 la tache a des anses et
## des pointes, et plus personne ne devine le compas.
const Z_BRUIT := 0.30                ## amplitude du contour, en part du rayon
const Z_FREQ := 0.022                ## une anse de quartier toutes les ~45 cases

## `[genre, dx, dy, rx, rz, rang, nom]` — dx/dy/rx/rz en CASES, depuis le repère.
const QUARTIERS := {
	## ⭐ LA CAPITALE VA JUSQU'À LA PLAGE. « L'île centrale doit être remplie un
	## max jusqu'au bord de plage » : le faubourg couvre donc TOUT le rayon de
	## l'île (142 × 137) et huit cases de plus, pour que le contour bruité du
	## quartier morde le trait de côte au lieu de s'arrêter avant. Une tache
	## déborde en mer sans dommage — le remplissage ne bâtit que la terre.
	##
	## Et une ville pleine n'est pas une ville uniforme : les couronnes portent
	## des poches — une seconde zone industrielle à l'ouest, deux bidonvilles en
	## marge, deux parcs, et QUATRE FRONTS DE MER qui font la couture avec la
	## plage. Sans elles, remplir l'île donne deux mille hectares du même
	## pavillonnaire, ce qui est pire que le trou qu'on vient de boucher.
	"Gare Centrale": [
		## ⚠ LE FAUBOURG EST CENTRÉ SUR L'ÎLE, PAS SUR LA GARE. La Gare Centrale est à
		## 22 cases au nord du centre de l'Île Centrale : une tache centrée sur elle
		## laissait 440 m de campagne sur toute la côte sud. Le décalage rattrape
		## l'écart, le rayon couvre l'île et huit cases de plus.
		[Ville2.Q_PAVILLONS, 5, 22, 150, 145, 1, "Les Faubourgs"],
		[Ville2.Q_CENTRE, 0, 0, 34, 31, 5, "Le Centre"],
		[Ville2.Q_VIEILLE_VILLE, -36, -15, 25, 22, 6, "La Vieille Ville"],
		[Ville2.Q_CHAUD, 35, 18, 21, 18, 6, "Le Mirage"],
		[Ville2.Q_INDUSTRIE, -92, 14, 30, 26, 4, "La Zone de l'Ouest"],
		[Ville2.Q_BIDONVILLE, -52, 66, 22, 18, 4, "Les Tôles"],
		[Ville2.Q_BIDONVILLE, 74, -54, 20, 17, 4, "Le Haut-Talus"],
		[Ville2.Q_PARC, -20, -72, 24, 20, 3, "Le Grand Parc"],
		[Ville2.Q_PARC, 62, 48, 20, 17, 3, "Le Bois de l'Est"],
		## LES FRONTS DE MER, posés SUR le trait de côte aux quatre orients.
		[Ville2.Q_PLAGE, -8, 128, 44, 22, 7, "La Grève du Sud"],
		[Ville2.Q_PLAGE, -126, -20, 22, 40, 7, "La Grève de l'Ouest"],
		[Ville2.Q_PLAGE, 122, 34, 22, 38, 7, "La Grève de l'Est"],
		[Ville2.Q_PLAGE, 24, -128, 40, 22, 7, "La Grève du Nord"],
	],
	"Université": [[Ville2.Q_CAMPUS, 0, 0, 27, 24, 6, "Le Campus"]],
	"Cité Administrative": [[Ville2.Q_CENTRE, 0, 0, 23, 20, 5, "La Cité"]],
	"Port-des-Alpes": [
		[Ville2.Q_INDUSTRIE, 0, 0, 25, 20, 8, "Le Port des Alpes"],
		[Ville2.Q_PLAGE, 4, 26, 24, 15, 7, "Le Front de Mer"],
	],
	"Port-Nord": [[Ville2.Q_INDUSTRIE, 0, 0, 27, 22, 8, "Les Bassins"]],
	## L'ÎLE NORD, PLEINE ELLE AUSSI. Son centre-ville est à 20 cases au sud du
	## centre de l'île : même correction que pour la capitale.
	"Centre-Ville Nord": [
		[Ville2.Q_PAVILLONS, 0, -20, 136, 112, 1, "Les Vergers"],
		[Ville2.Q_CENTRE, 0, 0, 27, 24, 5, "Le Centre Nord"],
		[Ville2.Q_VIEILLE_VILLE, -29, 11, 18, 16, 6, "Le Vieux Nord"],
		[Ville2.Q_CHAUD, -52, 8, 16, 14, 6, "Les Quais"],
		[Ville2.Q_BIDONVILLE, -72, -42, 20, 17, 4, "La Corniche Basse"],
		[Ville2.Q_PARC, 44, -72, 24, 20, 3, "Le Bois du Mont"],
		[Ville2.Q_PLAGE, 6, -116, 40, 20, 7, "La Grève du Nord"],
		[Ville2.Q_PLAGE, 22, 80, 38, 20, 7, "La Grève du Sud"],
		[Ville2.Q_PLAGE, -118, -18, 20, 34, 7, "La Grève de l'Ouest"],
		[Ville2.Q_PLAGE, 118, -12, 20, 34, 7, "La Grève de l'Est"],
	],
	"Sommet": [[Ville2.Q_PAVILLONS, 0, 0, 21, 18, 4, "Le Belvédère"]],
	"Gare Maritime": [[Ville2.Q_INDUSTRIE, 0, 0, 27, 22, 8, "La Gare Maritime"]],
	## L'ÎLE SUD-EST, PLEINE. Son centre est à 36 cases à l'ouest et 12 au nord
	## du centre de l'île — c'est la plus décentrée des trois.
	"Centre Sud-Est": [
		[Ville2.Q_PAVILLONS, 36, 12, 158, 134, 1, "Les Vignes"],
		[Ville2.Q_CENTRE, 0, 0, 27, 24, 5, "Le Centre Sud-Est"],
		[Ville2.Q_CHAUD, 27, -15, 17, 15, 6, "Les Enseignes"],
		[Ville2.Q_VIEILLE_VILLE, -28, 26, 19, 17, 6, "Le Vieux Bourg"],
		[Ville2.Q_BIDONVILLE, -58, 72, 21, 18, 4, "Les Cabanes"],
		[Ville2.Q_INDUSTRIE, 118, 62, 26, 22, 4, "La Zone de l'Est"],
		[Ville2.Q_PARC, 104, 58, 26, 22, 3, "Le Bois des Brises"],
		[Ville2.Q_PARC, 12, -74, 22, 19, 3, "Le Parc du Nord"],
		[Ville2.Q_PLAGE, 36, 126, 44, 22, 7, "La Grève du Sud"],
		[Ville2.Q_PLAGE, 36, -102, 44, 22, 7, "La Grève du Nord"],
		[Ville2.Q_PLAGE, 176, 12, 22, 38, 7, "La Grève de l'Est"],
		[Ville2.Q_PLAGE, -102, 12, 22, 38, 7, "La Grève de l'Ouest"],
	],
	"Plage-des-Vents": [[Ville2.Q_PLAGE, 0, 0, 27, 17, 7, "Plage-des-Vents"]],
	"Gare de l'Ouest": [[Ville2.Q_PAVILLONS, 0, 0, 24, 21, 2, "Le Bourg de l'Ouest"]],
	"Halte aux Brumes": [[Ville2.Q_PAVILLONS, 0, 0, 20, 17, 2, "Les Brumes"]],
	"Halte du Large": [[Ville2.Q_PAVILLONS, 0, 0, 16, 14, 2, "Le Large"]],
	"Gare des Pins": [[Ville2.Q_PAVILLONS, 0, 0, 22, 19, 2, "Les Pins"]],
	"Halte de la Baie": [[Ville2.Q_PAVILLONS, 0, 0, 18, 15, 2, "La Baie"]],
	"Halte du Levant": [[Ville2.Q_PAVILLONS, 0, 0, 18, 15, 2, "Le Levant"]],
	"Gare de la Côte": [[Ville2.Q_PAVILLONS, 0, 0, 20, 17, 2, "La Côte"]],
	## LES LIEUX-DITS : des hameaux, un cran au-dessus de la campagne.
	"Mont Aurélien": [[Ville2.Q_PAVILLONS, 0, 0, 13, 11, 3, "Mont Aurélien"]],
	"Vallée Verte": [[Ville2.Q_PAVILLONS, 0, 0, 15, 13, 3, "Vallée Verte"]],
	"Baie du Sud": [[Ville2.Q_PAVILLONS, 0, 0, 14, 12, 3, "Baie du Sud"]],
	"Mont des Brises": [[Ville2.Q_PAVILLONS, 0, 0, 13, 11, 3, "Mont des Brises"]],
	"Pointe de l'Aube": [[Ville2.Q_PAVILLONS, 0, 0, 14, 12, 3, "Pointe de l'Aube"]],
	"Colline de l'Est": [[Ville2.Q_PAVILLONS, 0, 0, 13, 11, 3, "Colline de l'Est"]],
	"Vallée des Pins": [[Ville2.Q_PAVILLONS, 0, 0, 15, 13, 3, "Vallée des Pins"]],
}

## Les taches, ancrées sur les repères. Aucun tirage : deux plans de même graine
## ont les mêmes quartiers, et deux fenêtres voisines les découpent au même
## endroit — c'est la garantie de raccord, à l'échelle du quartier.
static func _les_quartiers(plan: Dictionary) -> Array:
	var sortie: Array = []
	for nom in QUARTIERS:
		var ou := repere(plan, String(nom))
		if ou.x < 0: continue
		for e in QUARTIERS[nom]:
			var f: Array = e
			sortie.append({
				"g": String(f[0]), "nom": String(f[6]), "rang": int(f[5]),
				"c": [ou.x + int(f[1]), ou.y + int(f[2])],
				"r": [int(f[3]), int(f[4])],
			})
	return sortie

## L'index des taches, monté comme celui des îles. Une case de pleine campagne
## n'interroge alors aucune tache au lieu des quarante de la carte.
static func _indexer_les_quartiers(plan: Dictionary, ctx: Dictionary) -> void:
	var lobes: Array = []
	for e in plan.get("quartiers", []):
		var f: Dictionary = e
		var c := case_de(f["c"])
		var r: Array = f["r"]
		var rx := float(r[0])
		var rz := float(r[1])
		lobes.append(_lobe(float(c.x), float(c.y), rx, rz,
			maxf(rx, rz) * Z_BRUIT))
	ctx["q_lobes"] = lobes
	ctx["q_secteurs"] = _indexer_les_lobes(lobes)
	var b := FastNoiseLite.new()
	b.seed = int(plan["graine"]) + 5171
	b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	b.frequency = Z_FREQ
	b.fractal_type = FastNoiseLite.FRACTAL_FBM
	b.fractal_octaves = 3
	ctx["q_bruit"] = b

## ⭐ LE QUARTIER D'UNE CASE, ou −1 pour la campagne. Rend l'indice dans
## `plan["quartiers"]`. C'est LA fonction que le remplissage interrogera : elle
## remplace à elle seule les emprises carrées et leur découpage.
static func quartier_en(plan: Dictionary, ctx: Dictionary, c: Vector2i) -> int:
	var secteurs: Dictionary = ctx["q_secteurs"]
	var cle := Vector2i(int(floor(float(c.x) / float(COTE_SECTEUR))),
		int(floor(float(c.y) / float(COTE_SECTEUR))))
	if not secteurs.has(cle): return -1
	var lobes: Array = ctx["q_lobes"]
	var b: FastNoiseLite = ctx["q_bruit"]
	var n := b.get_noise_2d(float(c.x), float(c.y))
	var quartiers: Array = plan["quartiers"]
	var gagnant := -1
	var rang := RANG_CAMPAGNE
	var marge := 0.0
	for k in (secteurs[cle] as Array):
		var f: Dictionary = lobes[k]
		var dx := (float(c.x) - float(f["x"])) / float(f["rx"])
		var dz := (float(c.y) - float(f["z"])) / float(f["rz"])
		var e := (sqrt(dx * dx + dz * dz) - 1.0) * float(f["r"]) + n * float(f["amp"])
		if e >= 0.0: continue
		var r2 := int((quartiers[k] as Dictionary)["rang"])
		# ⚠ À RANG ÉGAL, LA TACHE LA PLUS ENFONCÉE GAGNE — sinon deux faubourgs
		# voisins se disputeraient leur frontière au gré de l'ordre de la table,
		# et la couture se verrait comme une ligne droite entre deux tirages.
		if r2 > rang or (r2 == rang and e < marge):
			rang = r2
			marge = e
			gagnant = k
	return gagnant

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

static func charger(chemin := PLAN_CUIT) -> Dictionary:
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
