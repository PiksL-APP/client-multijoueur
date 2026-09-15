extends RefCounted
## LA CARTE ENTIÈRE — l'archipel, la côte et son arrière-pays (cahier § 2).
##
## Les neuf témoins ont éprouvé les neuf façons de bâtir un quartier, chacun
## sur sa carte neuve de 40 × 40. Ce fichier-ci n'en éprouve aucune : il
## éprouve LA GÉOGRAPHIE — où est la mer, où sont les îles, où se franchit le
## relief, par où passent les grands axes — et il prévoit la place de chaque
## témoin. C'est l'étape que le client a annoncée en toutes lettres : « le but
## est d'avoir des témoins parfaits pour que tu puisses ensuite construire
## TOUTE LA CARTE en gardant les règles appliquées ».
##
## L'ordre du cahier (§ 10) est tenu, et il l'est à l'échelle de la carte :
## terrain → côtes → axes → quartiers → rues → lots → détails. Les quartiers
## ne sont pas « remplis » ici : on leur réserve un PLATEAU, et le générateur
## de témoin vient y poser sa ville (voir `_greffer` et le diagnostic ci-après).
##
## ═══════════════════════════════════════════════════════════════════════════
## ⚠⚠⚠ LE DIAGNOSTIC : COMMENT RECOMPOSER NEUF TÉMOINS SUR UNE GRANDE CARTE
## ═══════════════════════════════════════════════════════════════════════════
##
## LE PROBLÈME, EXACTEMENT. Les neuf générateurs ne savent écrire QUE sur une
## carte de 40 × 40 dont l'origine est (0, 0). Ce n'est pas un défaut de
## paramétrage, c'est leur façon d'exister : leur plan de masse est fait de
## constantes ABSOLUES — `const STADE := Rect2i(22, 3, 16, 14)` au campus,
## `const J_ROCADE := 12` à l'industrie, `const J_RIVAGE := 24` à la plage,
## `const TERRASSES := [{"j0": 21, …}]` à la colline. Il y en a une bonne
## centaine réparties sur neuf fichiers, et chacune a été placée À L'ŒIL, une
## capture après l'autre, contre le regard du client. C'est ce travail-là qui
## fait que les témoins sont bons ; c'est aussi ce qui les cloue au sol.
##
## Ils prennent bien un paramètre `taille`, mais ne s'en servent presque pas :
## agrandir la carte d'un témoin laisse son plan de masse au même endroit et
## ajoute du vide autour. Aucun d'eux ne prend d'ORIGINE.
##
## TROIS SOLUTIONS, ET CE QU'ELLES COÛTENT.
##
## 1. LA REFONTE — chaque générateur prend une zone en paramètre et écrit ses
##    constantes en RELATIF.
##    Coût : neuf fichiers, ~5 000 lignes, chaque constante de position à
##    réécrire (`Rect2i(22, 3, …)` → `zone.position + Vector2i(22, 3)`), et
##    toutes les coordonnées en mètres à décaler (`(float(i) + 0.5) * CASE`
##    devient `(float(zone.position.x + i) + 0.5) * CASE` — il y en a des
##    centaines). Risque : chaque oubli est un objet à huit cents mètres de sa
##    place, et il n'y a AUCUN moyen de s'en apercevoir autrement qu'à l'œil,
##    sur une capture de quatre kilomètres de côté où un bâtiment fait trois
##    pixels. C'est exactement le genre de faute que `verifier_temoins.gd` ne
##    voit pas. Je la déconseille aujourd'hui.
##
## 2. LE CURSEUR `origine` — on ajoute à chaque générateur la lecture d'un
##    `curseurs["origine"]` et on l'ajoute partout où une coordonnée est
##    calculée.
##    Coût : identique à la refonte (c'est la même réécriture), avec en plus
##    le piège d'un générateur à moitié converti, qui pose la moitié de son
##    quartier au bon endroit et l'autre à l'origine. Pire que la refonte.
##
## 3. ⭐ LA GREFFE — RETENUE. On laisse les neuf générateurs STRICTEMENT
##    intacts. On les appelle tels quels, chacun sur sa carte de 40 × 40, et
##    on RECOPIE la carte obtenue dans la grande, décalée de son origine.
##    C'est `greffer()`, plus bas : quatre-vingts lignes, UN seul endroit où
##    la translation est écrite, donc un seul endroit où elle peut être
##    fausse — et si elle est fausse, elle l'est pour les neuf témoins d'un
##    coup, ce qui se voit du premier regard au lieu de se cacher.
##    Coût : le temps de génération (neuf témoins complets, dont on jette le
##    terrain de bordure), et trois servitudes, énumérées ci-dessous.
##
## LES TROIS SERVITUDES DE LA GREFFE, ET COMMENT ON LES TIENT.
##
## a) LE TÉMOIN APPORTE SON TERRAIN. Un témoin écrit l'altitude, l'eau et la
##    matière de ses 1 600 cases : greffé au milieu d'une colline, il y
##    découpe un carré plat de huit cents mètres de côté, à vif. On ne greffe
##    donc QUE sur un PLATEAU déjà réservé et déjà plat (voir `PLATEAUX`), et
##    l'altitude du plateau est ajoutée à tout ce que le témoin pose — sol,
##    lots, objets, et jusqu'aux `y_abs` des piles de carcasses. Le cahier dit
##    la même chose autrement : « les quartiers sont sur des plateaux, le
##    relief se franchit entre eux ».
##
## b) DEUX TÉMOINS APPORTENT LEUR CÔTE. La plage taille sa mer à partir de sa
##    rangée `J_RIVAGE` (24), la colline son coteau de cent mètres. Leur
##    plateau n'est donc pas placé n'importe où : celui de la plage est posé
##    de sorte que ses seize rangées d'eau tombent DANS la mer de la grande
##    carte, celui de la colline sur le relief de l'arrière-pays. C'est la
##    seule contrainte de plan que la greffe impose, et c'est celle qu'il faut
##    REGARDER à la couture au premier rendu.
##
## c) LA COUTURE. Le bord d'un témoin ne connaît pas son voisin : ses rues
##    s'arrêtent net au bord de son carré. C'est pourquoi chaque plateau est
##    ceint d'un anneau de desserte (`_ceintures`) qui ramasse les rues
##    sortantes, et pourquoi le plateau est entouré d'une marge d'herbe. Une
##    rue de témoin qui bute sur cet anneau est une rue qui débouche ; sans
##    l'anneau ce serait une impasse, et le cahier les refuse « sans raison ».
##
## CE QU'IL FAUDRA FAIRE PLUS TARD, ET DANS CET ORDRE. La greffe ne dispense
## pas de la refonte : elle la REPORTE jusqu'à ce qu'on sache ce qu'on veut.
## Le jour où le client demandera un centre de 60 × 40 plutôt que 40 × 40, ou
## deux banlieues de tailles différentes, il faudra la solution 1 — mais on
## la fera alors sur un plan de masse ÉPROUVÉ, pas sur une hypothèse. Et on la
## fera générateur par générateur, la greffe servant de filet : un générateur
## converti se greffe encore, avec une origine nulle.
##
## ═══════════════════════════════════════════════════════════════════════════
## LA TAILLE, ET CE QU'ELLE COÛTE EN OBJETS
## ═══════════════════════════════════════════════════════════════════════════
##
## ⚠ UNE CASE FAIT VINGT MÈTRES, PAS DIX. Le cahier (§ 2) écrit « 20 unités,
## ~10 m » : c'est une estimation d'avant que l'échelle du jeu ne soit fixée,
## et elle est fausse d'un facteur deux. L'unité du jeu est LE MÈTRE — le
## joueur fait 1,75, une voiture 4,75 de long, et toutes les hauteurs du kit
## sont données en mètres depuis le 12/09. Une case vaut donc 20 unités,
## c'est-à-dire VINGT MÈTRES. Trois kilomètres font 150 cases, et non 300.
##
## `TAILLE` = 200 × 200 cases = 4,0 × 4,0 km, seize kilomètres carrés.
##
## Pourquoi 200 et pas 180 (3,6 km), qui suffirait au « plus de 3 × 3 km » :
##
## * la géométrie commande. Neuf témoins font 9 × 40 × 40 = 14 400 cases de
##   quartier bâti. Il faut en plus les CHENAUX entre les îles (un pont de
##   moins de six cases ne se lit pas comme un pont), les ceintures autour des
##   plateaux, et un arrière-pays qui ne soit pas une lisière. À 180, en
##   posant les quatre quartiers de l'île mère, il ne restait pas six cases
##   entre l'île et sa voisine ; à 200, il en reste six à sept partout ;
## * les dix minutes de traversée. Une voiture de ce jeu tient 50 à 60 km/h en
##   ville : dix minutes font huit à dix kilomètres de roulage. La diagonale
##   de la carte fait 5,6 km — avec les ponts obligés, la rocade et les feux,
##   un bout à l'autre coûte bien dix minutes. À 3,6 km on était juste en
##   dessous.
##
## LE COMPTE D'OBJETS, ET IL EST TENABLE — MAIS PAS D'UN SEUL BLOC.
##
##   témoins greffés   14 400 cases   ~30 400 objets, ~1 400 lots (mesurés sur
##                                    les neuf `cartes/temoin-*.json`)
##   arrière-pays       ~8 000 cases  ~12 000 objets (1 touffe et 0,35 arbre
##                                    par case — voir `DENSITE`)
##   axes et ouvrages                 ~3 000 objets (tabliers, garde-corps,
##                                    lampadaires, panneaux)
##   ─────────────────────────────────────────────────────────────────────
##   TOTAL                            ~45 000 objets, ~1 400 lots, ~6 Mo de JSON
##
## Quarante-cinq mille objets, c'est six fois le plus chargé des témoins. En
## bâtir le décor d'un seul coup est HORS DE QUESTION au navigateur, et on le
## sait déjà pour l'avoir payé sur Pikstown : la ville v1 sortait 126 778
## nœuds en 17 secondes en natif, « comptez ×4 à ×6 dans le navigateur ».
##
## LA PARADE EXISTE DÉJÀ, ET ELLE N'EST PAS À ÉCRIRE : `MorceauxV2` bâtit par
## carrés de 16 × 16 cases autour du joueur, une passe par image. À `rayon` 3,
## ce sont 7 × 7 morceaux, soit 12 544 cases — moins du tiers des terres, donc
## de l'ordre de 14 000 objets vivants à un instant donné. C'est deux témoins.
## Le cahier prévoit les deux leviers : « ville bâtie par morceaux » et
## « distance d'affichage réglable dans les options » (§ 2) — le second, c'est
## `rayon`.
##
## Restent DEUX coûts qui, eux, ne se morcellent pas, et il faut les mesurer
## avant de promettre quoi que ce soit (je ne les ai pas mesurés) :
##
## 1. LE JSON. Six mégaoctets à charger et à parser avant le premier morceau.
##    Compressé sur le fil c'est ~1 Mo, mais `JSON.parse_string` sur six
##    mégaoctets au navigateur est une pause franche. Si elle se voit : couper
##    la carte en fichiers par secteur, ou passer les tableaux de terrain
##    (altitude, eau, matière, quartier — 160 000 nombres) en base64 plutôt
##    qu'en texte, ce qui en retire les trois quarts à lui seul ;
## 2. LA GÉNÉRATION. Neuf témoins complets plus la géographie. Au bureau c'est
##    une affaire de secondes et ça n'a lieu qu'une fois, hors ligne : la
##    carte est ENREGISTRÉE, et le jeu ne fait que la relire.
##
## Et le curseur `densite` est là pour ça : il ne touche qu'à ce qui se compte
## en dizaines de milliers — l'herbe et le semis de l'arrière-pays — parce que
## c'est le seul poste où l'on peut retirer la moitié des objets sans que la
## carte change de dessin.
##
## ═══════════════════════════════════════════════════════════════════════════
## POUR LA REGARDER
## ═══════════════════════════════════════════════════════════════════════════
##
## Ce fichier ne se lance pas tout seul (un générateur est un `RefCounted`,
## comme ses neuf frères ; c'est un outil qui l'appelle). Deux lignes à
## ajouter dans `outils/photo_v2.gd`, que je n'ai pas le droit de toucher :
##
##     const CARTE := preload("res://commun/ville2/generateur_carte.gd")
##     …
##     elif _arg("temoin", "centre") == "carte":
##         ville = CARTE.generer(int(_arg("graine", "100")))
##
## puis, pour l'enregistrer et la photographier de haut :
##
##     ./outils/photo_v2.sh /tmp/carte.png --temoin=carte \
##         --json=cartes/carte.json --vue=dessus --images=30
##
## Une fois le JSON écrit, tout le reste la lit sans rien changer :
## `--carte=res://cartes/carte.json` à la photo, et l'éditeur par son menu.

## ⚠ `preload` ET JAMAIS `class_name` : le cache de classes n'est pas réécrit
## par `godot --headless --import`, donc une classe neuve compile au bureau et
## tombe en ligne. Piège déjà payé deux fois sur ce projet.
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const ANGLES := preload("res://commun/ville2/angles.gd")
## Pour les teintes du plan d'eau et de la grève du lac : elles ont été réglées
## une fois, pour le bassin du parc, et elles n'ont pas à l'être deux fois.
const PARC := preload("res://commun/ville2/parc.gd")

## Les neuf témoins, tels quels. On ne les modifie pas : on les APPELLE.
const TEMOINS := {
	"centre": preload("res://commun/ville2/generateur_centre.gd"),
	"plage": preload("res://commun/ville2/generateur_plage.gd"),
	"colline": preload("res://commun/ville2/generateur_colline.gd"),
	"banlieue": preload("res://commun/ville2/generateur_banlieue.gd"),
	"industrie": preload("res://commun/ville2/generateur_industrie.gd"),
	"vieille": preload("res://commun/ville2/generateur_vieille_ville.gd"),
	"chaud": preload("res://commun/ville2/generateur_chaud.gd"),
	"campus": preload("res://commun/ville2/generateur_campus.gd"),
	"bidonville": preload("res://commun/ville2/generateur_bidonville.gd"),
}

const CASE := Ville2.CASE
const PALIER := Ville2.PALIER

## Quatre kilomètres de côté (voir l'en-tête). Un témoin fait 40 × 40 : la
## carte en vaut vingt-cinq en surface.
const TAILLE := Vector2i(200, 200)
const COTE_TEMOIN := 40

# ------------------------------------------------------------------ la géographie

## ⚠ UNE ÎLE N'EST PAS UN RECTANGLE, ET PAS DAVANTAGE UN RECTANGLE ONDULÉ.
## La leçon a déjà été payée deux fois sur ce projet — sur l'île de Pikstown
## (« de haut on voyait le rectangle à travers l'ondulation ») et sur le lac du
## parc (« une union de rectangles dont l'un est le plus grand A LA FORME DU
## PLUS GRAND »). La règle qui en sort est toujours la même : AUCUN LOBE NE
## DOIT DOMINER LES AUTRES.
##
## Chaque île est donc l'union de `lobes` ellipses de taille COMPARABLE, posées
## sur un anneau autour du centre — jamais une grande au milieu — et la
## frontière du résultat est bruitée. Le champ vaut, pour une case :
##
##     f = max sur les lobes de ( 1 − (dx/rx)² − (dz/rz)² )  +  bruit
##
## et la case est à terre si f > 0. Le bruit se prend sur une fréquence de
## l'ordre de la dizaine de cases : plus fin, il fait de l'écume et des îlots
## d'une case ; plus gros, il déplace l'île au lieu de la découper.
##
## `r` est le rayon de l'île, pas celui d'un lobe : un lobe fait `PART_LOBE`
## fois ce rayon et son centre est à `ANNEAU` fois ce rayon.
const PART_LOBE := 0.70
const ANNEAU := 0.42
const BRUIT_COTE := 0.34               ## amplitude, en unités du champ
const BRUIT_ECHELLE := 0.055           ## fréquence : une bosse toutes les ~18 cases

## LES CINQ MASSES DE TERRE : quatre îles et un continent (cahier § 2,
## « archipel de 4 îles ou plus reliées par de grands ponts, PLUS une côte avec
## arrière-pays »).
##
## Le continent est traité comme une île de plus, à ceci près qu'il DÉBORDE de
## la carte à l'est : c'est ce qui fait qu'on le lit comme une terre qui
## continue, et non comme la cinquième île.
const ILES := [
	{"nom": "L'Île Mère", "c": Vector2i(69, 106), "r": Vector2(53, 50), "lobes": 7},
	{"nom": "L'Île du Port", "c": Vector2i(82, 26), "r": Vector2(38, 24), "lobes": 5},
	{"nom": "L'Île aux Bains", "c": Vector2i(52, 178), "r": Vector2(30, 15), "lobes": 5},
	{"nom": "L'Île Basse", "c": Vector2i(156, 176), "r": Vector2(26, 22), "lobes": 5},
	{"nom": "Le Continent", "c": Vector2i(164, 76), "r": Vector2(38, 74), "lobes": 9},
]

## ⚠ LE PLAN DÉCIDE DE LA TOPOLOGIE, LE BRUIT DÉCIDE DU DESSIN. Un plateau de
## quartier, une piste d'atterrissage ou une tête de pont ne peuvent pas
## dépendre d'un tirage : on les FORCE à terre après coup. Sans ça, une graine
## sur trois noie un morceau de banlieue et le témoin se greffe dans l'eau —
## et rien dans le rendu ne le dirait, sinon des maisons qui flottent.

## LES NEUF PLATEAUX, un par témoin. `p` est le palier du plateau (un palier =
## 5 m) ; `t` le témoin qui viendra le remplir.
##
## ⚠ LES COULOIRS ENTRE PLATEAUX FONT SIX À HUIT CASES, ET C'EST LÀ QUE PASSENT
## LES AXES. Un axe ne traverse JAMAIS un plateau : le témoin y a déjà tracé
## ses rues, et deux plans de rue superposés font une bouillie. C'est la faute
## du campus du 13/09 — « l'avenue nord-sud traversait le stade » — mais à
## l'échelle de la carte, donc neuf fois pire. Toute modification d'un `Rect2i`
## ci-dessous se vérifie contre `ROCADE`, `TRAVERSANTE` et `RAIL`.
const PLATEAUX := [
	{"t": "centre", "z": Rect2i(26, 62, 40, 40), "p": 0, "nom": "Le Centre", "g": Ville2.Q_CENTRE},
	{"t": "chaud", "z": Rect2i(74, 62, 40, 40), "p": 0, "nom": "Le Quartier Chaud", "g": Ville2.Q_CHAUD},
	{"t": "vieille", "z": Rect2i(26, 110, 40, 40), "p": 2, "nom": "La Vieille Ville", "g": Ville2.Q_VIEILLE_VILLE},
	{"t": "campus", "z": Rect2i(74, 110, 40, 40), "p": 0, "nom": "Le Campus", "g": Ville2.Q_CAMPUS},
	{"t": "industrie", "z": Rect2i(62, 2, 40, 40), "p": 0, "nom": "La Zone", "g": Ville2.Q_INDUSTRIE},
	{"t": "plage", "z": Rect2i(32, 162, 40, 40), "p": 0, "nom": "Le Front de Mer", "g": Ville2.Q_PLAGE},
	{"t": "banlieue", "z": Rect2i(138, 30, 40, 40), "p": 1, "nom": "Les Coteaux", "g": Ville2.Q_PAVILLONS},
	{"t": "colline", "z": Rect2i(134, 78, 40, 40), "p": 1, "nom": "Le Village Perché", "g": Ville2.Q_PAVILLONS},
	{"t": "bidonville", "z": Rect2i(136, 156, 40, 40), "p": 0, "nom": "La Basse-Ville", "g": Ville2.Q_BIDONVILLE},
]

## ⚠ LA PLAGE APPORTE SA MER, ET C'EST POUR ÇA QUE SON PLATEAU DÉBORDE.
## `GenerateurPlage` met de l'eau à partir de sa rangée 24 environ : sur les
## quarante rangées de son plateau, seize sont de la mer. Son plateau est donc
## posé à cheval sur le trait de côte de l'Île aux Bains — ses rangées bâties
## sur la terre, ses rangées d'eau au large — et seules ses `RANGEES_PLAGE`
## premières rangées sont forcées à terre.
const RANGEES_PLAGE := 24

## L'ARRIÈRE-PAYS (cahier § 2). Ce sont des emprises réservées et forcées à
## terre ; leur contenu n'est pour l'instant qu'un semis de repérage — voir
## « ce qui reste à faire » à la fin du fichier.
const AERODROME := Rect2i(178, 76, 20, 46)     ## piste de 46 cases = 920 m
const VILLAGE := Rect2i(132, 122, 16, 14)
const LAC := Rect2i(152, 124, 20, 14)
const BARRAGE_J := 138                          ## la ligne du couronnement
const CARRIERE := Rect2i(154, 142, 16, 10)
const OBSERVATOIRE := Vector2i(188, 40)

## LE RELIEF DE L'ARRIÈRE-PAYS. Le cahier veut « une colline de 30-50 m avec
## vue sur la baie » et garde « les pentes fortes hors ville ». Les îles
## restent donc BASSES (leur relief, c'est celui que les témoins apportent) et
## seul le continent monte, en s'éloignant de la mer.
const PALIER_ARRIERE_PAYS := 8                  ## 8 × 5 m = 40 m au plus loin
const MONTEE_PAR_CASE := 0.11                   ## en paliers : 40 m en ~70 cases
## ⚠⚠⚠ LE FOND DE LA MER — ET C'EST ICI QUE LA PREMIÈRE CARTE N'AVAIT PAS DE
## MER DU TOUT.
##
## Ce que le client a vu au premier rendu : « tout ce qui n'est pas une île est
## une nappe CRÈME uniforme — du sable, pas de l'eau ». Mesuré sur le JSON
## livré : 11 714 des 12 441 cases d'eau étaient à l'altitude −0,40, et le
## niveau de la mer est à `TerrainV2.NIVEAU_MER` = −2,85. Autrement dit,
## 96,4 % DU FOND MARIN ÉTAIT AU-DESSUS DE LA SURFACE DE L'EAU. La nappe bleue
## était bien posée par `TerrainV2.maillage_eau` — sous le fond, donc invisible,
## et l'on voyait le fond : du sable, puisque `_couleur_case` teinte le fond
## marin en sable tant qu'il est peu profond.
##
## LA FAUTE, EXACTEMENT. `_distances_a_la_mer` donne la distance À LA MER : elle
## vaut ZÉRO pour toute case d'eau, puisque les cases d'eau sont les SOURCES de
## la propagation. En la réutilisant pour creuser le fond, toute la mer se
## retrouvait à la profondeur du premier pas — une seule et même flaque de
## quarante centimètres.
##
## Une case d'eau ne veut pas savoir sa distance à la mer (elle EST la mer) :
## elle veut sa distance À LA TERRE. Ce sont deux champs différents, calculés
## par deux propagations inverses — `_distances_a_la_mer` et `_profondeurs`.
##
## LA LEÇON GÉNÉRALE, et elle vaut au-delà de ce fichier : DANS CE MODÈLE, UNE
## CASE D'EAU N'EST PAS UNE CASE SANS ALTITUDE. `eau[k]` dit qu'il y a de l'eau,
## `altitude[k]` dit où est LE FOND, et rien ne vérifie que le fond est sous la
## surface. Le témoin de la plage est le seul qui l'avait fait juste, et il
## comptait sa profondeur depuis SA ligne d'eau, pas depuis une rangée fixe —
## c'est le même calcul que `_profondeurs`, en local.
##
## Les cotes : la première case d'eau est à −3,1 (25 cm sous la surface : on
## voit le sable à travers, c'est une plage), puis on descend de 1,9 par case
## jusqu'à −11. Un chenal de six cases atteint donc −6,9 en son milieu : assez
## pour se lire comme un bras de mer et non comme un gué.
const PREMIER_FOND := -1.2
const PENTE_FOND := -1.9
const FOND_MAX := -11.0

## ⚠ ET LA TERRE DESCEND À SA RENCONTRE. Sans ça, l'île est un plateau à zéro
## posé sur une fosse à −3,1 : une marche de trois mètres tout autour de chaque
## île, c'est-à-dire une baignoire. Le cahier veut l'inverse (§ 4, « plages en
## pente douce, le sable entre dans l'eau »), et le témoin de la plage a payé
## la leçon le 12/09. Les deux dernières cases de terre avant l'eau descendent
## donc, et elles seules : plus loin, un sol qui penche fait flotter ce qu'on y
## pose. Les deux cotes restent AU-DESSUS de la surface — c'est du sable sec.
const ESTRAN := [-1.1, -0.35]

# ------------------------------------------------------------------ les axes

## LA ROCADE DE L'ÎLE MÈRE (cahier § 5 : « une rocade autour de l'île
## principale »). Un anneau, donc un rectangle : `ajouter_route` refuse la
## diagonale, le kit ne sait pas la paver.
const ROCADE := [Vector2i(19, 57), Vector2i(120, 57), Vector2i(120, 154),
	Vector2i(19, 154), Vector2i(19, 57)]
## LA TRAVERSANTE centre → aérodrome, par le couloir entre les plateaux nord et
## sud de l'île mère, puis par le grand pont.
const TRAVERSANTE := [Vector2i(19, 106), Vector2i(178, 106)]

## LES PONTS. `de`/`vers` sont les deux bouts de la TRAVÉE (les cases de
## chaussée sur l'eau) ; `genre` décide de l'ouvrage à poser. Un pont est
## toujours droit et toujours dans un seul axe : le kit ne sait pas faire
## autrement, et une travée qui tourne n'a pas de pile où la poser.
const P_HAUBANS := "haubans"
const P_ROUTIER := "routier"
const P_RAIL := "rail"
const PONTS := [
	{"g": P_HAUBANS, "de": Vector2i(120, 106), "vers": Vector2i(132, 106),
		"nom": "Pont du Détroit"},
	{"g": P_ROUTIER, "de": Vector2i(84, 44), "vers": Vector2i(84, 58),
		"nom": "Pont du Port"},
	{"g": P_ROUTIER, "de": Vector2i(46, 154), "vers": Vector2i(46, 166),
		"nom": "Pont des Bains"},
	{"g": P_ROUTIER, "de": Vector2i(152, 146), "vers": Vector2i(152, 158),
		"nom": "Pont de la Basse-Ville"},
	{"g": P_RAIL, "de": Vector2i(70, 46), "vers": Vector2i(70, 60), "nom": ""},
	{"g": P_RAIL, "de": Vector2i(96, 46), "vers": Vector2i(96, 60), "nom": ""},
]
## ⚠ LE TABLIER EST AU NIVEAU DE LA CHAUSSÉE QU'IL PROLONGE, ET PAS À UNE
## HAUTEUR CHOISIE. Premier réglage : huit mètres au-dessus de la mer, « pour
## qu'on voie les piles ». Mais la route qui arrive au pont est au palier 0,
## c'est-à-dire à Y = 0 : un tablier à +5,15 fait une MARCHE DE CINQ MÈTRES à
## chaque culée, et une voiture ne monte pas une marche.
##
## Un vrai pont haut se gagne par des RAMPES (`road-slant` du kit, cahier § 5),
## et les rampes sont un chantier à part. En attendant, le tablier est posé à
## Y = 0 : `_plateforme` cote son tablier à `NIVEAU_MER + y`, donc `y` vaut
## exactement l'opposé du niveau de la mer. Il reste 2,85 m de tirant d'air —
## une vedette passe, un cargo non — et les piles descendent jusqu'au fond,
## bien visibles. Écrit comme un calcul et non comme un nombre : le jour où
## `NIVEAU_MER` bouge, les cinq ponts suivent.
const TABLIER := -TerrainV2.NIVEAU_MER
## Le rail est dessiné par `RenduVille2` à 0,3 au-dessus de son palier : au
## palier 0, ses traverses reposent donc sur un tablier à la même cote.
const TABLIER_RAIL := TABLIER

## LA BOUCLE FERROVIAIRE (cahier § 6 : « une ligne en boucle avec 4-6 gares »).
## Elle fait le tour des quatre plateaux de l'île mère, puis pousse une anse
## par-dessus le chenal du nord pour desservir la zone industrielle — c'est
## elle qui justifie les deux ponts ferroviaires « séparés » du § 5.
## ⚠ LE BRIN SUD EST À 152 ET NON À 151, ET CE N'EST PAS UN DÉTAIL : 151 est
## exactement la ligne de l'anneau de ceinture de la vieille ville et du campus
## (leur plateau finit à 150, `grow(1)` met l'anneau à 151). Rail et avenue sur
## les mêmes cases, c'est la chaussée qui gagne à la rastérisation et la voie
## qui disparaît — sans un mot. Toute retouche de `PLATEAUX` se revérifie ici.
const RAIL := [Vector2i(22, 60), Vector2i(70, 60), Vector2i(70, 46), Vector2i(96, 46),
	Vector2i(96, 60), Vector2i(117, 60), Vector2i(117, 152), Vector2i(22, 152),
	Vector2i(22, 60)]
## CINQ GARES sur la boucle, dans la fourchette du cahier (4 à 6). La centrale
## porte le modèle du client (`piksl/gare`, cent soixante mètres de long) ; les
## quatre autres sont des arrêts, et c'est le témoin voisin qui les habille.
const GARES := [
	{"nom": "Gare Centrale", "c": Vector2i(22, 82), "p": true},
	{"nom": "Gare du Port", "c": Vector2i(82, 46), "p": false},
	{"nom": "Gare de l'Est", "c": Vector2i(117, 106), "p": false},
	{"nom": "Gare du Vieux Port", "c": Vector2i(48, 152), "p": false},
	{"nom": "Gare des Facultés", "c": Vector2i(96, 152), "p": false},
]

## LES ROUTES DE L'ARRIÈRE-PAYS. Elles ne sont PAS droites : le cahier veut
## « grille au centre, organique ailleurs » (§ 5). Une route organique, dans
## un kit qui ne sait poser que des tuiles carrées, c'est un ESCALIER — des
## segments droits de longueur variable qui dérivent vers leur but. Voir
## `_escalier`.
const ROUTES_DE_CAMPAGNE := [
	{"de": Vector2i(132, 106), "vers": Vector2i(150, 70), "nom": "Route des Coteaux"},
	{"de": Vector2i(150, 70), "vers": Vector2i(158, 34), "nom": "Route de la Crête"},
	{"de": Vector2i(150, 70), "vers": Vector2i(186, 42), "nom": "Route de l'Observatoire"},
	{"de": Vector2i(140, 106), "vers": Vector2i(138, 126), "nom": "Chemin du Village"},
	{"de": Vector2i(146, 126), "vers": Vector2i(150, 138), "nom": "Route du Barrage"},
	{"de": Vector2i(174, 138), "vers": Vector2i(160, 148), "nom": "Route de la Carrière"},
]

# ------------------------------------------------------------------ le semis

## Ce qui pousse sur l'arrière-pays. Les listes sont courtes ici EXPRÈS : le
## kit nature au complet est déjà tiré par `parc.gd` (qui fait les bois) et par
## la passe d'herbe de `proprete.gd`. Ce semis-ci n'est là que pour que la
## campagne ne soit pas un tapis vert entre deux quartiers.
const ARBRES_DE_PLAINE := ["nature/tree_default", "nature/tree_oak", "nature/tree_fat",
	"nature/tree_simple", "nature/tree_blocks", "nature/tree_plateau"]
const H_PLAINE := [9.0, 11.0, 8.5, 8.0, 9.0, 9.5]
const ARBRES_DE_CRETE := ["nature/tree_pineTallA", "nature/tree_pineTallC",
	"nature/tree_pineRoundC", "nature/tree_cone_dark"]
const H_CRETE := [16.0, 17.0, 10.0, 10.0]
const ROCHES := ["nature/rock_largeA", "nature/rock_largeD", "nature/rock_tallA",
	"nature/stone_largeC", "nature/cliff_rock"]
const H_ROCHES := [3.2, 2.8, 4.2, 2.6, 0.0]
const PALMIERS := ["nature/tree_palm", "nature/tree_palmTall", "nature/tree_palmBend"]
const H_PALMIERS := [8.0, 11.0, 9.0]

## La densité du semis de campagne, par case et par graine. `DENSITE` est le
## curseur qui décide de la moitié du budget d'objets de la carte : voir
## l'en-tête.
const DENSITE := 1.0

# ------------------------------------------------------------------ générer

static func generer(graine := 100, taille := TAILLE, curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "carte"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	# 1. TERRAIN ET CÔTES (cahier § 10 : c'est le premier temps, et il commande
	#    tout le reste — un axe posé sur une côte qu'on n'a pas encore dessinée
	#    se retrouve dans l'eau).
	_mer_et_terre(v, graine)
	var distances := _distances_a_la_mer(v)
	var profondeurs := _profondeurs(v)
	_relief(v, distances, profondeurs)
	_matieres(v, distances)

	# 2. LES QUARTIERS : les zones, avant les rues. C'est l'ordre du cahier, et
	#    c'est aussi celui qui permet aux axes de savoir ce qu'ils longent.
	_quartiers(v)

	# 3. LES AXES.
	_axes(v)
	_le_rail(v)
	v.rasteriser()
	# ⚠ LES VIRAGES S'ARRONDISSENT AVANT LES MAISONS (leçon de la colline et de
	# la plage) : une courbe large mange quatre cases, et si les lots sont déjà
	# posés il n'en reste aucune de libre.
	ANGLES.arrondir(v, alea, 0.6)
	v.rasteriser()

	# 4. LES QUARTIERS BÂTIS : chaque témoin vient remplir son plateau.
	if bool(curseurs.get("temoins", true)):
		_greffer_les_temoins(v, graine, curseurs)
	v.rasteriser()

	# 5. LES OUVRAGES ET L'ARRIÈRE-PAYS.
	_les_ponts(v)
	_l_arriere_pays(v, alea)
	v.rasteriser()

	# 6. LES DÉTAILS.
	_semer_la_campagne(v, alea, float(curseurs.get("densite", DENSITE)))
	# ⚠ L'HERBE À UN BRIN PAR CASE, ET PAS TROIS. Trois par case est le réglage
	# d'un témoin de 1 600 cases ; sur 40 000, c'est cent mille touffes à lui
	# seul — plus du double de tout le reste de la carte. Un brin par case
	# suffit à tuer le vert plat dès qu'il y a des arbres par-dessus, et c'est
	# le seul poste où l'on retire cinquante mille objets sans rien changer au
	# dessin.
	PROPRETE.finir(v, alea, int(curseurs.get("herbe", 1)))
	return v

# ------------------------------------------------------------------ 1. la mer et la terre

## L'ARCHIPEL. Toute la carte est de la mer ; les cinq masses de terre s'y
## posent par leur champ de lobes bruité (voir `ILES`), puis le plan reprend la
## main sur ce que le bruit n'a pas le droit de décider.
static func _mer_et_terre(v: Ville2, graine: int) -> void:
	var bruit := FastNoiseLite.new()
	bruit.seed = graine
	bruit.frequency = BRUIT_ECHELLE
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Les lobes, une fois pour toutes : les tirer par case ferait du bruit
	# blanc au lieu d'une île.
	var lobes := _lobes(graine)
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			var f := -1.0
			for l in lobes:
				var d: Dictionary = l
				var dx := (float(i) - float(d["x"])) / float(d["rx"])
				var dz := (float(j) - float(d["z"])) / float(d["rz"])
				f = maxf(f, 1.0 - dx * dx - dz * dz)
			f += bruit.get_noise_2d(float(i), float(j)) * BRUIT_COTE
			if f > 0.0:
				v.poser_terre(c, 0.0)
			else:
				v.poser_eau(c)
	# ⚠ CE QUE LE BRUIT N'A PAS LE DROIT DE DÉCIDER. Un plateau de quartier,
	# une piste, une tête de pont : leur place est un choix de plan. Forcées à
	# terre APRÈS le bruit, elles font au pire un promontoire — jamais un
	# quartier noyé.
	for p in PLATEAUX:
		var f2: Dictionary = p
		var z: Rect2i = f2["z"]
		# La plage est à cheval sur son propre rivage : seules ses rangées
		# bâties sont de la terre (voir `RANGEES_PLAGE`).
		if String(f2["t"]) == "plage":
			z = Rect2i(z.position, Vector2i(z.size.x, RANGEES_PLAGE))
		_forcer_terre(v, z.grow(2))
	for r in [AERODROME, VILLAGE, CARRIERE, LAC]:
		_forcer_terre(v, (r as Rect2i).grow(2))
	for p in PONTS:
		var f3: Dictionary = p
		_forcer_terre(v, Rect2i(Vector2i(f3["de"]) - Vector2i.ONE * 2, Vector2i(5, 5)))
		_forcer_terre(v, Rect2i(Vector2i(f3["vers"]) - Vector2i.ONE * 2, Vector2i(5, 5)))
		# ⚠ ET ON CREUSE SOUS LA TRAVÉE. Un pont dont le bruit a rempli le
		# chenal n'est plus un pont mais un remblai : la travée elle-même est
		# forcée à L'EAU, sauf ses deux têtes.
		_forcer_eau(v, Vector2i(f3["de"]), Vector2i(f3["vers"]))

## Les lobes de toutes les îles, posés sur un anneau — aucun au centre.
static func _lobes(graine: int) -> Array:
	var alea := RandomNumberGenerator.new()
	alea.seed = graine * 7919
	var tous: Array = []
	for ile in ILES:
		var f: Dictionary = ile
		var c: Vector2i = f["c"]
		var r: Vector2 = f["r"]
		var n := int(f["lobes"])
		for k in n:
			var a := TAU * float(k) / float(n) + alea.randf_range(-0.22, 0.22)
			var d := alea.randf_range(ANNEAU * 0.8, ANNEAU * 1.15)
			tous.append({
				"x": float(c.x) + cos(a) * r.x * d,
				"z": float(c.y) + sin(a) * r.y * d,
				"rx": r.x * PART_LOBE * alea.randf_range(0.88, 1.12),
				"rz": r.y * PART_LOBE * alea.randf_range(0.88, 1.12),
			})
	return tous

static func _forcer_terre(v: Ville2, zone: Rect2i) -> void:
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if v.dedans(c): v.poser_terre(c, 0.0)

static func _forcer_eau(v: Ville2, de: Vector2i, vers: Vector2i) -> void:
	var d := (vers - de).sign()
	var c := de + d
	while c != vers:
		if v.dedans(c): v.poser_eau(c)
		c += d

# ------------------------------------------------------------------ les distances

## LA DISTANCE DE CHAQUE CASE À LA MER, en cases, par propagation depuis toutes
## les cases d'eau à la fois. C'est la mesure la plus utile de toute la carte :
## elle donne la plage (distance 1), le relief de l'arrière-pays (qui monte
## avec elle) et la profondeur du fond marin (la même, en négatif). Quarante
## mille cases, une passe : c'est gratuit devant le reste.
static func _distances_a_la_mer(v: Ville2) -> PackedInt32Array:
	var n := v.taille.x * v.taille.y
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(-1)
	var file: Array[Vector2i] = []
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c):
				d[v.indice(c)] = 0
				file.append(c)
	var tete := 0
	const VOISINS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while tete < file.size():
		var c2: Vector2i = file[tete]
		tete += 1
		var ici := d[v.indice(c2)]
		for p in VOISINS:
			var n2: Vector2i = c2 + (p as Vector2i)
			if not v.dedans(n2): continue
			var k := v.indice(n2)
			if d[k] >= 0: continue
			d[k] = ici + 1
			file.append(n2)
	return d

## LA PROFONDEUR DE CHAQUE CASE D'EAU, en cases depuis la terre la plus proche.
## C'est la propagation INVERSE de la précédente, et il faut les deux : une case
## de terre veut savoir à quelle distance est la mer, une case d'eau veut savoir
## à quelle distance est la côte. Confondre les deux, c'est une mer entièrement
## à quarante centimètres de fond — voir l'avertissement sur `PREMIER_FOND`.
static func _profondeurs(v: Ville2) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(v.taille.x * v.taille.y)
	d.fill(-1)
	var file: Array[Vector2i] = []
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if v.terre(c):
				d[v.indice(c)] = 0
				file.append(c)
	# ⚠ LE BORD DE LA CARTE NE COMPTE PAS COMME UNE CÔTE. Sans source hors
	# carte, la mer du large s'approfondit jusqu'à `FOND_MAX` et y reste : c'est
	# exactement ce qu'on veut. (Pour la distance à la mer, c'est l'inverse qui
	# est vrai — mais aucune terre de cette carte n'est à plus de soixante-dix
	# cases d'une côte, donc la question ne se pose pas.)
	var tete := 0
	const VOISINS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while tete < file.size():
		var c2: Vector2i = file[tete]
		tete += 1
		var ici := d[v.indice(c2)]
		for p in VOISINS:
			var n2: Vector2i = c2 + (p as Vector2i)
			if not v.dedans(n2): continue
			var k := v.indice(n2)
			if d[k] >= 0: continue
			d[k] = ici + 1
			file.append(n2)
	return d

# ------------------------------------------------------------------ le relief

## LE RELIEF, EN TROIS TEMPS ET DANS CET ORDRE : le paysage voulu, les plateaux
## qui l'écrasent, la relaxation qui rend les pentes franchissables.
##
## ⚠ LE RELIEF NE SE POSE PAS, IL SE CONTRAINT. C'est la leçon la plus chère de
## Pikstown v1 : un champ de hauteur posé librement fabrique des marches que
## le kit ne sait pas paver (le kit ne monte que de deux paliers d'un coup, et
## jamais sous un carrefour). On pose donc le paysage, puis on le RABOTE
## jusqu'à ce qu'il soit conduisible.
static func _relief(v: Ville2, distances: PackedInt32Array, profondeurs: PackedInt32Array) -> void:
	# A. LE PAYSAGE VOULU. Les îles restent basses — leur relief, ce sont les
	#    témoins qui l'apportent. Seul le continent monte en s'éloignant de la
	#    mer, et il plafonne : le cahier garde la montagne pour plus tard.
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			var k := v.indice(c)
			if not v.terre(c):
				# LE FOND DE LA MER, compté depuis LA CÔTE (`profondeurs`) et
				# non depuis la mer : voir l'avertissement sur `PREMIER_FOND`.
				# C'est ce qui met le fond SOUS la surface, donc ce qui fait
				# qu'on voit de l'eau.
				# ⚠ `maxi(1, …)` : une case d'eau que la propagation n'aurait
				# pas atteinte garderait −1, et −1,2 − (−1) × 1,9 rendrait
				# +0,7 — c'est-à-dire un banc de sable AU-DESSUS de la surface,
				# le défaut même qu'on est en train de corriger. Ça ne peut pas
				# arriver tant qu'il reste de la terre sur la carte ; on s'en
				# protège quand même, parce que cette faute-là ne se voit
				# qu'à l'image et qu'elle a déjà coûté un rendu.
				v.altitude[k] = maxf(FOND_MAX,
					PREMIER_FOND + float(maxi(1, profondeurs[k])) * PENTE_FOND)
				continue
			if not _sur_le_continent(c):
				v.altitude[k] = 0.0
			else:
				var p := minf(float(distances[k]) * MONTEE_PAR_CASE, float(PALIER_ARRIERE_PAYS))
				# La bosse de l'observatoire : le point haut de l'arrière-pays,
				# et le seul endroit d'où l'on voit toute la baie.
				var dobs := Vector2(c - OBSERVATOIRE).length()
				p += maxf(0.0, 4.0 * (1.0 - dobs / 22.0))
				v.altitude[k] = roundf(p) * PALIER
			# L'ESTRAN : les deux dernières cases de terre avant l'eau
			# descendent à sa rencontre, et elles seules (voir `ESTRAN`). On ne
			# rabaisse que ce qui est déjà au niveau de la mer : une côte qui
			# monte est une falaise, et une falaise ne se creuse pas.
			var dm := distances[k]
			if dm >= 1 and dm <= ESTRAN.size() and v.altitude[k] <= 0.01:
				v.altitude[k] = float(ESTRAN[dm - 1])
	# B. LES PLATEAUX. Chaque quartier bâti est PLAT, d'un bord à l'autre : le
	#    cahier l'exige (§ 4, « pas de pente sous les quartiers bâtis ») et la
	#    greffe en dépend (le témoin pose son propre sol à plat).
	for f in PLATEAUX:
		var d: Dictionary = f
		var z: Rect2i = (d["z"] as Rect2i).grow(2)
		var y := float(d["p"]) * PALIER
		for j in range(z.position.y, z.end.y):
			for i in range(z.position.x, z.end.x):
				var c2 := Vector2i(i, j)
				if v.dedans(c2) and v.terre(c2): v.poser_terre(c2, y)
	# ⚠⚠ LE LAC DE L'ARRIÈRE-PAYS N'EST PAS FAIT DE CASES D'EAU, ET C'EST LA
	# MÊME LEÇON QUE LE BASSIN DU PARC, PAYÉE UNE SECONDE FOIS.
	#
	# Premier jet : on creusait de vraies cases d'eau, et on perchait leur fond
	# à trente unités pour que le barrage retienne quelque chose. Mais
	# `TerrainV2.maillage_eau` pose la nappe bleue de TOUTE case d'eau à
	# `NIVEAU_MER` — une seule altitude pour toute la carte, la mer étant la
	# mer. Un lac perché à +30 avec sa surface dessinée à −2,85 : le fond perce
	# la nappe, et l'on voit un bassin de roche. Exactement le défaut qu'on
	# vient de corriger sur la mer, à l'envers.
	#
	# `parc.gd` avait déjà tranché, et pour la même raison : « on la fait en
	# surface colorée plutôt qu'en vraie eau ». Le lac est donc un BASSIN PLAT
	# de terre, et son eau est peinte par-dessus (voir `_le_lac`). Il suit son
	# sol, donc il peut être à n'importe quelle altitude — et on peut enfin
	# construire un barrage devant.
	#
	# Sa cote se prend SUR LE TERRAIN, plus la hauteur de retenue : un barrage
	# de dix mètres dans un paysage qui en fait vingt-cinq, et non une retenue
	# de trente mètres au milieu d'une plaine.
	var y_lac := v.sol(Vector2i(LAC.get_center())) + float(RETENUE) * PALIER
	for j in range(LAC.position.y - 1, LAC.end.y + 1):
		for i in range(LAC.position.x - 1, LAC.end.x + 1):
			var c3 := Vector2i(i, j)
			if v.dedans(c3) and v.terre(c3): v.poser_terre(c3, y_lac)
	for i2 in range(LAC.position.x - 2, LAC.end.x + 2):
		var c4 := Vector2i(i2, BARRAGE_J)
		if v.dedans(c4) and v.terre(c4): v.poser_terre(c4, y_lac)
	# C. LA RELAXATION. Deux cases de terre voisines ne peuvent différer de plus
	#    de `MARCHE_MAX` paliers, sauf au nez d'un plateau — là, la marche est
	#    VOULUE, et c'est le mur de soutènement qui l'habille. On ne fait que
	#    DESCENDRE : c'est ce qui garantit que la passe converge.
	_relaxer(v)

const MARCHE_MAX := 2
## La hauteur de retenue du barrage, en paliers : dix mètres au-dessus du
## terrain naturel. Au-delà, la retenue domine un arrière-pays qui culmine à
## quarante mètres, et le barrage ne se lit plus comme un ouvrage mais comme
## une faute de terrain.
const RETENUE := 2

static func _relaxer(v: Ville2) -> void:
	var plateaux: Dictionary = {}
	for f in PLATEAUX:
		var z: Rect2i = (f as Dictionary)["z"]
		for j in range(z.position.y - 2, z.end.y + 2):
			for i in range(z.position.x - 2, z.end.x + 2):
				plateaux[Vector2i(i, j)] = true
	# ⚠ LA RETENUE ÉCHAPPE À LA RELAXATION, ELLE AUSSI — et c'est tout le
	# propos d'un barrage : une marche que le terrain n'aurait jamais faite
	# seul. Rabotée comme le reste, la retenue redescendait au niveau de
	# l'aval en deux passes, et il ne restait qu'un mur devant une mare.
	for j2 in range(LAC.position.y - 2, LAC.end.y + 2):
		for i2 in range(LAC.position.x - 2, LAC.end.x + 2):
			plateaux[Vector2i(i2, j2)] = true
	for _passe in 6:
		var bouge := false
		for j in v.taille.y:
			for i in v.taille.x:
				var c := Vector2i(i, j)
				if not v.terre(c) or plateaux.has(c): continue
				var bas := v.sol(c)
				for p in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + (p as Vector2i)
					if not v.dedans(n) or not v.terre(n): continue
					bas = minf(bas, v.sol(n) + float(MARCHE_MAX) * PALIER)
				if bas < v.sol(c) - 0.001:
					v.poser_terre(c, bas)
					bouge = true
		if not bouge: break

## Vrai si la case appartient au continent — la seule masse qui monte.
static func _sur_le_continent(c: Vector2i) -> bool:
	var f: Dictionary = ILES[ILES.size() - 1]
	var ce: Vector2i = f["c"]
	var r: Vector2 = f["r"]
	var dx := (float(c.x) - float(ce.x)) / (r.x * 1.35)
	var dz := (float(c.y) - float(ce.y)) / (r.y * 1.35)
	return dx * dx + dz * dz <= 1.0

# ------------------------------------------------------------------ les matières

## LA MATIÈRE DU SOL. Elle ne se décore pas, elle se DÉDUIT : du sable là où la
## terre touche l'eau, de la roche là où ça tombe, de l'herbe partout ailleurs.
## Les plateaux, eux, garderont ce que leur témoin y posera.
static func _matieres(v: Ville2, distances: PackedInt32Array) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c): continue
			var d := distances[v.indice(c)]
			if d <= 1:
				v.poser_matiere(c, Ville2.M_SABLE)
				continue
			# La roche marque les cassures : c'est là que le rendu accrochera
			# les falaises du kit nature.
			var chute := 0.0
			for p in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + (p as Vector2i)
				if v.dedans(n) and v.terre(n):
					chute = maxf(chute, v.sol(c) - v.sol(n))
			v.poser_matiere(c, Ville2.M_ROCHE if chute >= PALIER * 1.5 else Ville2.M_HERBE)

# ------------------------------------------------------------------ 2. les quartiers

## LES ZONES. Un quartier par plateau, plus une zone de campagne par masse de
## terre non bâtie — le jeu en a besoin pour nommer un endroit, pour donner un
## territoire à un gang et pour choisir une ambiance sonore.
##
## ⚠ L'ORDRE DE CE TABLEAU EST UN CONTRAT. `quartier_de` ne garde qu'un INDICE
## dans `v.quartiers` : la greffe d'un témoin décale les siens de la taille
## courante du tableau (voir `greffer`), donc on n'y insère jamais au milieu.
static func _quartiers(v: Ville2) -> void:
	for f in PLATEAUX:
		var d: Dictionary = f
		v.quartiers.append({"nom": String(d["nom"]), "genre": String(d["g"]), "gang": -1})
		v.peindre_quartier((d["z"] as Rect2i), v.quartiers.size() - 1)
	# ⚠ CES QUARTIERS-LÀ SERONT RECOUVERTS. Chaque témoin greffé apporte SES
	# propres quartiers et repeint son carré avec. Ceux d'ici servent tant que
	# la greffe n'a pas eu lieu (carte nue, curseur `temoins` à faux) — et une
	# carte nue doit rester lisible : c'est la consigne « montrer tôt et
	# souvent, même moche ».
	v.quartiers.append({"nom": "L'Arrière-Pays", "genre": Ville2.Q_PARC, "gang": -1})
	var campagne := v.quartiers.size() - 1
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if v.terre(c) and v.quartier_en(c) < 0 and _sur_le_continent(c):
				v.quartier_de[v.indice(c)] = campagne

# ------------------------------------------------------------------ 3. les axes

static func _axes(v: Ville2) -> void:
	v.ajouter_route(Ville2.R_VOIE_RAPIDE, ROCADE, "Rocade de l'Île", 1)
	v.ajouter_route(Ville2.R_VOIE_RAPIDE, TRAVERSANTE, "Voie de l'Aérodrome", 1)
	# LES ACCÈS AUX PONTS : chaque travée se raccorde à la rocade ou à la
	# rocade la plus proche par une avenue. Sans elles, les ponts ne mènent
	# nulle part — et « une rue qui ne mène nulle part sans raison » est le
	# deuxième des interdits du cahier (§ 0).
	for p in PONTS:
		var f: Dictionary = p
		if String(f["g"]) == P_RAIL: continue
		v.ajouter_route(Ville2.R_AVENUE, [Vector2i(f["de"]), Vector2i(f["vers"])],
			String(f["nom"]), 1)
	# LES CEINTURES : l'anneau de desserte qui fait le tour de chaque plateau et
	# ramasse les rues que le témoin arrête à son bord (voir la servitude « c »
	# du diagnostic).
	_ceintures(v)
	# LES ROUTES DE CAMPAGNE, en escalier : « organique ailleurs » (§ 5).
	for r in ROUTES_DE_CAMPAGNE:
		var f2: Dictionary = r
		v.ajouter_route(Ville2.R_RUE, _escalier(Vector2i(f2["de"]), Vector2i(f2["vers"])),
			String(f2["nom"]))
	# LA ROUTE DU BARRAGE, sur le couronnement (cahier § 2 : « un barrage avec
	# route dessus »). Elle est droite : un barrage l'est.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(LAC.position.x - 3, BARRAGE_J),
		Vector2i(LAC.end.x + 3, BARRAGE_J)], "Route du Barrage")
	# LA DESSERTE DE L'AÉRODROME, le long de la piste.
	v.ajouter_route(Ville2.R_RUE, [Vector2i(AERODROME.position.x - 2, 106),
		Vector2i(AERODROME.position.x - 2, AERODROME.end.y - 2)], "Voie des Hangars")

## L'ANNEAU DE DESSERTE d'un plateau, posé à une case de son bord. Il est en
## AVENUE et non en rue : c'est lui qui porte le trafic d'un quartier entier.
static func _ceintures(v: Ville2) -> void:
	for f in PLATEAUX:
		var d: Dictionary = f
		var z: Rect2i = (d["z"] as Rect2i).grow(1)
		# La plage n'a d'anneau que sur ses trois côtés à terre : le quatrième
		# est la mer, et une avenue sur l'eau ne se rastérise même pas.
		var cotes: Array = [
			[z.position, Vector2i(z.end.x, z.position.y)],
			[Vector2i(z.end.x, z.position.y), z.end],
			[z.end, Vector2i(z.position.x, z.end.y)],
			[Vector2i(z.position.x, z.end.y), z.position],
		]
		for k in cotes.size():
			var seg: Array = cotes[k]
			var a: Vector2i = seg[0]
			var b: Vector2i = seg[1]
			if not _tout_a_terre(v, a, b): continue
			v.ajouter_route(Ville2.R_AVENUE, [a, b], "Ceinture " + String(d["nom"]))

static func _tout_a_terre(v: Ville2, a: Vector2i, b: Vector2i) -> bool:
	# ⚠ PAS DE `while true` SANS SORTIE ÉCRITE. L'analyseur de GDScript ne sait
	# pas qu'une boucle infinie ne peut que sortir par un `return` : il refuse
	# de compiler (« Not all code paths return a value »). On borne donc la
	# boucle sur la longueur du segment, ce qui est de toute façon plus sûr.
	var d := (b - a).sign()
	var c := a
	for _k in ((b - a).abs().x + (b - a).abs().y + 1):
		if not v.dedans(c) or not v.terre(c): return false
		if c == b: return true
		c += d
	return false

## UNE ROUTE ORGANIQUE, c'est-à-dire UN ESCALIER. Le kit ne pave que des
## segments droits dans l'un des deux axes (`ajouter_route` refuse la
## diagonale) : une route qui « serpente » est donc une suite de marches de
## longueur inégale. Les marches courtes font un virage, les longues une ligne
## droite — c'est ce mélange qui distingue une route de campagne d'un escalier
## de pixels.
static func _escalier(de: Vector2i, vers: Vector2i) -> Array:
	var pts: Array = [de]
	var c := de
	var horizontal := absi(vers.x - de.x) >= absi(vers.y - de.y)
	var garde := 0
	while c != vers and garde < 64:
		garde += 1
		var suivant := c
		if horizontal:
			var pas := clampi(vers.x - c.x, -9, 9)
			if pas == 0:
				horizontal = false
				continue
			suivant = Vector2i(c.x + pas, c.y)
		else:
			var pas2 := clampi(vers.y - c.y, -7, 7)
			if pas2 == 0:
				horizontal = true
				continue
			suivant = Vector2i(c.x, c.y + pas2)
		pts.append(suivant)
		c = suivant
		horizontal = not horizontal
	# ⚠ ON FERME EN DEUX SEGMENTS, JAMAIS EN UN. Rejoindre le but d'un trait
	# depuis un point qui en diffère sur les DEUX axes, c'est une diagonale —
	# et `ajouter_route` refuse une diagonale : elle rend −1 et la route
	# entière est perdue, EN SILENCE. Une route de campagne évaporée sur une
	# carte de quatre kilomètres ne se voit pas.
	if c.x != vers.x:
		c = Vector2i(vers.x, c.y)
		pts.append(c)
	if c.y != vers.y:
		pts.append(vers)
	return pts

# ------------------------------------------------------------------ le rail

static func _le_rail(v: Ville2) -> void:
	v.rail.append({"points": RAIL.duplicate(), "niveau": 0})
	for g in GARES:
		var f: Dictionary = g
		var c: Vector2i = f["c"]
		v.gares.append({"nom": String(f["nom"]), "x": (float(c.x) + 0.5) * CASE,
			"z": (float(c.y) + 0.5) * CASE, "principale": bool(f["p"])})
		v.ajouter_lieu("gare", (float(c.x) + 0.5) * CASE, (float(c.y) + 0.5) * CASE,
			{"nom": String(f["nom"])})
	# ⚠ LA VOIE SE RÉSERVE, SINON ON BÂTIT DESSUS. `terrain_libre` ne connaît
	# que les routes, les pièces et les lots : un rail n'est aucun des trois,
	# et deux usines se sont déjà posées à cheval sur les rails du témoin
	# industriel (« je vois des bâtiments sur la voie de train », client,
	# 14/09). On marque ses cases dans le registre vivant, et on interdit la
	# bande : rien n'y traîne, pas même un panneau publicitaire.
	for c in Ville2.cases_de_route({"points": RAIL}):
		var ce: Vector2i = c
		for b in 2:
			for a in 2:
				v.demi_prises[Vector2i(ce.x * 2 + a, ce.y * 2 + b)] = true
	# ⚠ UNE ZONE PAR SEGMENT, ET SURTOUT PAS UNE PAR CASE. `est_interdit` est
	# appelé pour CHAQUE objet de la carte et parcourt la liste en entier :
	# quarante-cinq mille objets contre trois cent cinquante rectangles, c'est
	# seize millions de tests pour la seule passe de propreté. Huit rectangles
	# longs valent trois cent cinquante courts, et coûtent quarante fois moins.
	for k in range(1, RAIL.size()):
		var a2: Vector2i = RAIL[k - 1]
		var b2: Vector2i = RAIL[k]
		var x0 := float(mini(a2.x, b2.x)) * CASE + 4.0
		var z0 := float(mini(a2.y, b2.y)) * CASE + 4.0
		var x1 := float(maxi(a2.x, b2.x) + 1) * CASE - 4.0
		var z1 := float(maxi(a2.y, b2.y) + 1) * CASE - 4.0
		v.interdire(Rect2(x0, z0, x1 - x0, z1 - z0))

# ------------------------------------------------------------------ 4. la greffe

## ⭐ LA GREFFE — voir le diagnostic en tête de fichier.
static func _greffer_les_temoins(v: Ville2, graine: int, curseurs: Dictionary) -> void:
	for f in PLATEAUX:
		var d: Dictionary = f
		var nom := String(d["t"])
		if not TEMOINS.has(nom): continue
		# ⚠ UNE VARIABLE SANS TYPE, EXPRÈS. Typée `GDScript`, l'appel
		# `script.generer(…)` est résolu à la compilation contre la classe
		# `GDScript`, qui n'a évidemment pas de `generer` : ça ne compile pas.
		# Sans type, l'appel est dynamique — c'est ce que fait déjà
		# `outils/photo_v2.gd` avec ses neuf constantes préchargées.
		var script = TEMOINS[nom]
		# ⚠ CHAQUE TÉMOIN GARDE SA PROPRE GRAINE, DÉRIVÉE DE CELLE DE LA CARTE.
		# Avec la même graine pour les neuf, les sacs de `Lotisseur` et les
		# tirages tombent en phase : deux quartiers voisins alignent les mêmes
		# maisons dans le même ordre, et ça se voit.
		var petite: Ville2 = script.generer(graine * 31 + nom.hash() % 1021,
			Vector2i(COTE_TEMOIN, COTE_TEMOIN), {"nom": String(d["nom"])})
		greffer(v, petite, (d["z"] as Rect2i).position, float(d["p"]) * PALIER)
	# La greffe a ajouté des lots, des routes et des pièces : la carte dérivée
	# ne les connaît pas encore.
	v.rasteriser()
	if bool(curseurs.get("verbeux", false)):
		print("carte : %d lots, %d objets, %d routes" % [v.lots.size(), v.objets.size(),
			v.routes.size()])

## RECOPIE une petite ville dans la grande, décalée de `origine` (en cases) et
## remontée de `base` (en unités). C'est le SEUL endroit du projet où une
## translation de ville est écrite ; tout ce qui suit y passe, et rien ne doit
## la contourner.
##
## ⚠ LA LISTE CI-DESSOUS EST LA LISTE COMPLÈTE DE CE QU'UNE `Ville2` CONTIENT.
## Un champ oublié, c'est un quartier entier resté à l'origine de la carte, et
## personne ne le verra sur une capture de quatre kilomètres. Si `ville2.gd`
## gagne un champ, il en gagne un ici le même jour.
static func greffer(v: Ville2, petite: Ville2, origine: Vector2i, base: float) -> void:
	var dx := float(origine.x) * CASE
	var dz := float(origine.y) * CASE
	# 1. LES QUARTIERS. `quartier_de` ne garde qu'un indice : il se décale du
	#    nombre de quartiers déjà déclarés dans la grande carte.
	var decalage := v.quartiers.size()
	for q in petite.quartiers:
		v.quartiers.append((q as Dictionary).duplicate(true))
	# 2. LE SOL. L'altitude du témoin s'AJOUTE à celle du plateau ; la mer, non
	#    — une mer perchée n'existe pas, et la plage doit rejoindre la vraie.
	for j in petite.taille.y:
		for i in petite.taille.x:
			var src := Vector2i(i, j)
			var c := origine + src
			if not v.dedans(c): continue
			var ks := petite.indice(src)
			var kd := v.indice(c)
			if petite.terre(src):
				v.poser_terre(c, petite.altitude[ks] + base)
			else:
				# ⚠ ON GARDE LE PLUS PROFOND DES DEUX FONDS, ET C'EST TOUT CE
				# QUI TIENT LA COUTURE DE LA PLAGE.
				#
				# Le témoin de la plage compte sa profondeur depuis SA ligne
				# d'eau : ses premières rangées d'eau sont un estran de un
				# mètre trente. La grande carte, elle, compte depuis la côte la
				# plus proche et descend bien plus vite. Recopié tel quel,
				# l'estran du témoin REMONTAIT le fond de la mer au bord de son
				# carré — un haut-fond rectangulaire de huit cents mètres de
				# large, avec sa bande de sable clair le long de la couture,
				# exactement le défaut qu'on vient de corriger sur toute la mer.
				#
				# Le fond ne remonte donc jamais : là où le témoin est plus
				# creux, il gagne (c'est sa baie) ; là où la grande carte l'est,
				# elle gagne (c'est le large). Dans les deux cas la ligne d'eau
				# tombe au même endroit et il n'y a pas de marche.
				var creux := petite.altitude[ks]
				if not v.terre(c): creux = minf(creux, v.altitude[kd])
				v.poser_eau(c)
				v.altitude[kd] = creux
			v.matiere[kd] = petite.matiere[ks]
			var q2 := petite.quartier_de[ks]
			v.quartier_de[kd] = (q2 + decalage) if q2 >= 0 else -1
	# 3. LES ROUTES ET LE RAIL.
	for r in petite.routes:
		var fr: Dictionary = r
		v.ajouter_route(String(fr["genre"]), _decaler(fr["points"], origine),
			String(fr.get("nom", "")), int(fr.get("niveau", 0)))
	for r2 in petite.rail:
		var fr2: Dictionary = r2
		v.rail.append({"points": _decaler(fr2["points"], origine),
			"niveau": int(fr2.get("niveau", 0))})
	# 4. LES OUVRAGES (courbes larges, ronds-points), en cases.
	for o in petite.ouvrages:
		var fo: Dictionary = (o as Dictionary).duplicate()
		fo["i"] = int(fo["i"]) + origine.x
		fo["j"] = int(fo["j"]) + origine.y
		v.ouvrages.append(fo)
	# 5. LES LOTS, en DEMI-cases : le décalage vaut donc double. On passe par
	#    `ajouter_lot` et non par un `append` pour que `demi_prises` — le
	#    registre vivant qui empêche deux maisons de s'encastrer — soit tenu à
	#    jour dans la grande carte aussi.
	for l in petite.lots:
		var fl: Dictionary = l
		v.ajouter_lot(String(fl["m"]), int(fl["x"]) + origine.x * 2,
			int(fl["y"]) + origine.y * 2, int(fl["w"]), int(fl["h"]), int(fl["q"]),
			String(fl.get("genre", "")), String(fl.get("c", "")))
	# 6. LES OBJETS, en MÈTRES. On recopie la fiche ENTIÈRE : elle porte des
	#    clefs que seuls certains générateurs emploient (`w`, `d`, `dy`, `sol`,
	#    `zone`, `voirie`, `aplat`…) et qu'on n'a pas le droit de perdre.
	#    ⚠ `y_abs` EST UNE ALTITUDE ABSOLUE — la pile de carcasses de la casse,
	#    le bar sur le tablier de la jetée. Elle monte avec le plateau ; sans
	#    ça, une pile de voitures greffée à dix mètres d'altitude s'enterre.
	for o2 in petite.objets:
		var fo2: Dictionary = (o2 as Dictionary).duplicate(true)
		fo2["x"] = float(fo2["x"]) + dx
		fo2["z"] = float(fo2["z"]) + dz
		if fo2.has("y_abs"): fo2["y_abs"] = float(fo2["y_abs"]) + base
		v.objets.append(fo2)
	# 7. LES LIEUX DE JEU ET LES GARES.
	for li in petite.lieux:
		var fli: Dictionary = (li as Dictionary).duplicate(true)
		fli["x"] = float(fli["x"]) + dx
		fli["z"] = float(fli["z"]) + dz
		v.lieux.append(fli)
	for ga in petite.gares:
		var fga: Dictionary = (ga as Dictionary).duplicate(true)
		fga["x"] = float(fga["x"]) + dx
		fga["z"] = float(fga["z"]) + dz
		v.gares.append(fga)
	# 8. LES ZONES INTERDITES, en mètres : c'est ce qui garde propres une piste
	#    d'atterrissage et une voie ferrée. Une zone oubliée, et les panneaux
	#    publicitaires reviennent au milieu de la piste (client, 14/09).
	for z in petite.interdits:
		var r3: Rect2 = z
		v.interdire(Rect2(r3.position + Vector2(dx, dz), r3.size))
	# 9. LE REGISTRE DES DEMI-CASES. Un témoin en réserve sans y poser de lot —
	#    l'emprise de sa voie ferrée, le fond de son lac. Ces réservations-là
	#    n'ont pas d'autre trace : sans cette boucle, la grande carte y bâtit.
	for k in petite.demi_prises.keys():
		var h: Vector2i = k
		v.demi_prises[Vector2i(h.x + origine.x * 2, h.y + origine.y * 2)] = true

static func _decaler(points: Array, origine: Vector2i) -> Array:
	var pts: Array = []
	for p in points:
		pts.append(Vector2i(p) + origine)
	return pts

# ------------------------------------------------------------------ 5. les ponts

## LES PONTS ENTRE ÎLES (cahier § 5).
##
## ⚠⚠ ET VOICI CE QUI MANQUE AU MOTEUR, ÉCRIT ICI PARCE QUE C'EST ICI QU'ON
## BUTE DESSUS : `Ville2.rasteriser()` ne pose une chaussée QUE sur une case de
## terre —
##
##     for c in cases_de_route(r):
##         if carte.terre(c): carte.poser_route(c, true)
##
## — donc une route qui traverse l'eau N'EST PAS RENDUE. Aujourd'hui, sur cette
## carte, les cinq ponts seraient des trous. Ce n'est pas une négligence du
## rastériseur : jusqu'à ce fichier, aucune route n'avait jamais franchi l'eau.
##
## La parade, en attendant que le rendu sache poser une chaussée sur pilotis :
## LE TABLIER EST UN OBJET. `RenduVille2` sait déjà faire une `plateforme` —
## un tablier posé à une hauteur donnée au-dessus de la mer, avec ses pilotis
## qui descendent jusqu'au fond. C'est la pièce de la jetée du témoin de la
## plage, et c'est exactement ce qu'il faut : une travée par case, ses piles
## visibles, son ombre portée. On y ajoute les garde-corps et les lampadaires
## que le cahier réclame « sur toute la longueur ».
##
## La polyligne de route, elle, reste posée : le jeu, la mini-carte et le GPS
## en ont besoin pour savoir qu'on peut passer. Elle ne se voit simplement pas
## encore.
##
## ⚠⚠ LE 14/09, J'AI EU LE DROIT DE TOUCHER À `ville2.gd` POUR ÇA, ET JE NE
## L'AI PAS PRIS. Voici pourquoi, parce que c'est une décision et non un oubli.
##
## Faire rouler sur l'eau demande bien plus qu'une ligne dans `rasteriser()` :
##
## * `rasteriser` devrait appeler `carte.poser_sol` sur la case d'eau, à la
##   cote du tablier — sans quoi `carte.palier()` rend −999 et la tuile part à
##   cinq kilomètres sous la carte ;
## * `Ville2.plate()` devrait rendre vrai pour cette case — c'est elle qui
##   décide qu'une tuile du kit y est posée ;
## * ET ALORS `TerrainV2.hauteur_coin()` remonterait les quatre coins de la
##   case à la cote de la chaussée, parce qu'il fait gagner toute case plate :
##   LE FOND DE LA MER SE SOULÈVERAIT JUSQU'AU TABLIER, tout le long du pont.
##   Corriger ça, c'est toucher à `terrain_v2.gd` — qui n'est pas dans la
##   liste, et surtout qui porte le sol des neuf témoins.
##
## Trois fichiers, dont celui dont dépend le moindre gradin de la carte, pour
## une pièce qui a un substitut qui marche : le rapport est mauvais. Le
## tablier-objet reste. Ce qu'on perd est réel et il faut le dire — ON NE ROULE
## PAS SUR LES PONTS, la chaussée n'y est pas rastérisée — mais on le perdait
## déjà, et maintenant au moins on VOIT le pont, ses piles et ses lampadaires.
## Le jour où le joueur devra les franchir, ce sera un chantier à part, avec
## les voies rapides surélevées qui posent exactement le même problème.
##
## ⚠ LE PONT À HAUBANS N'EST PAS FAIT. Le kit n'a ni pylône ni câble, et je ne
## sais pas le bâtir en boîtes de façon présentable ; c'est une pièce à
## modeler (`modeles/pxl/`), comme le mur de soutènement l'a été le 14/09. En
## attendant, il est posé comme un pont routier plus large et plus haut : il se
## lit comme le grand pont de la carte sans prétendre être la pièce maîtresse.
const LARGE_TABLIER := 18.0
const LARGE_HAUBANS := 26.0

static func _les_ponts(v: Ville2) -> void:
	for p in PONTS:
		var f: Dictionary = p
		var a: Vector2i = f["de"]
		var b: Vector2i = f["vers"]
		var g := String(f["g"])
		var selon_x := a.y == b.y
		var large: float = LARGE_HAUBANS if g == P_HAUBANS else LARGE_TABLIER
		var haut: float = TABLIER_RAIL if g == P_RAIL else TABLIER
		var d := (b - a).sign()
		var c := a
		var k := 0
		while c != b:
			c += d
			k += 1
			if c == b: break
			var x := (float(c.x) + 0.5) * CASE
			var z := (float(c.y) + 0.5) * CASE
			# ⚠ `zone: true` — LE TABLIER EST POSÉ EXPRÈS DANS UNE ZONE
			# INTERDITE (voir plus bas). Sans ce drapeau, la passe de propreté
			# retire le pont qu'on vient de poser.
			v.objets.append({"m": "plateforme", "x": x, "z": z,
				"r": 0.0 if selon_x else PI * 0.5,
				"h": 0.0, "w": large, "d": CASE, "y": haut, "zone": true})
			if g == P_RAIL: continue
			# Les lampadaires, une travée sur deux, des deux côtés — « rambardes
			# et lampadaires sur toute la longueur » (§ 5).
			if k % 2 != 0: continue
			for s in [-1.0, 1.0]:
				var ex: float = 0.0 if selon_x else s * (large * 0.5 - 1.4)
				var ez: float = s * (large * 0.5 - 1.4) if selon_x else 0.0
				# ⚠ SUR LE TABLIER, PAS DEDANS. `_plateforme` centre son tablier
				# sur la cote demandée et lui donne 0,7 d'épaisseur : le pied
				# d'un lampadaire posé à cette cote-là est à mi-tablier.
				v.objets.append({"m": "lampadaire", "x": x + ex, "z": z + ez,
					"r": 0.0, "h": 0.0,
					"y_abs": TerrainV2.NIVEAU_MER + haut + 0.35, "zone": true})
		# LA ZONE INTERDITE DE LA TRAVÉE : rien ne traîne sur un pont, et
		# surtout rien ne pousse dessous à hauteur de tablier.
		var r := Rect2(Vector2(mini(a.x, b.x), mini(a.y, b.y)) * CASE,
			Vector2(absi(b.x - a.x) + 1, absi(b.y - a.y) + 1) * CASE)
		v.interdire(r)
		if g != P_RAIL:
			v.ajouter_lieu("pont", r.get_center().x, r.get_center().y,
				{"nom": String(f["nom"])})

# ------------------------------------------------------------------ 6. l'arrière-pays

## L'ARRIÈRE-PAYS (cahier § 2). ⚠ CE QUI SUIT EST UN REPÉRAGE, PAS UN QUARTIER.
## Chaque pièce est posée à sa place, à sa taille, avec ce qu'il faut pour la
## RECONNAÎTRE d'en haut — et rien de plus. Le cahier veut « montrer tôt et
## souvent, même moche » : mieux vaut une piste d'atterrissage nue et juste
## qu'un aérodrome complet dans six semaines. Chacune de ces six fonctions est
## un chantier à part entière, du calibre d'un témoin.
static func _l_arriere_pays(v: Ville2, alea: RandomNumberGenerator) -> void:
	_l_aerodrome(v, alea)
	_le_barrage(v)
	_la_carriere(v, alea)
	_le_village(v, alea)
	_l_observatoire(v)
	_le_lac(v, alea)

## L'AÉRODROME : une piste, sa manche à air, sa tour, ses hangars. La piste est
## une zone interdite au sens strict — c'est elle qui a donné la règle, le
## 14/09 (« assure-toi qu'il n'y ait rien sur la piste d'atterrissage »).
static func _l_aerodrome(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := AERODROME
	var debut := v.objets.size()
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.dedans(c): v.poser_matiere(c, Ville2.M_DALLE)
	var xc := (float(r.position.x) + float(r.size.x) * 0.5) * CASE
	v.interdire(Rect2(xc - CASE, float(r.position.y) * CASE, CASE * 2.0,
		float(r.size.y) * CASE))
	v.ajouter_objet("pxl/tour-controle", (float(r.position.x) + 1.5) * CASE,
		(float(r.position.y) + 2.0) * CASE, 0.0)
	v.ajouter_objet("pxl/manche-a-air", xc + CASE * 1.6,
		(float(r.position.y) + 1.0) * CASE, 0.0)
	for k in 4:
		v.ajouter_objet("pxl/hangar-avion", (float(r.position.x) + 2.0) * CASE,
			(float(r.position.y) + 6.0 + float(k) * 4.0) * CASE, PI * 0.5)
	for k2 in 5:
		v.ajouter_objet("pxl/avion-leger" if k2 % 2 == 0 else "pxl/avion-regional",
			xc + alea.randf_range(-6.0, 6.0),
			(float(r.position.y) + 6.0 + float(k2) * 7.0) * CASE, alea.randf() * TAU)
	for k3 in range(debut, v.objets.size()):
		v.objets[k3]["zone"] = true
	v.ajouter_lieu("aerodrome", xc, (float(r.position.y) + float(r.size.y) * 0.5) * CASE,
		{"nom": "Aérodrome de l'Est"})

## LE BARRAGE : le couronnement porte la route, le parement descend vers l'aval.
## Il est fait de murs de soutènement du client, posés bout à bout — la pièce
## mesure une case de long et un palier de haut, donc elle s'empile sans le
## moindre calcul d'échelle (mesuré le 14/09 pour la colline).
static func _le_barrage(v: Ville2) -> void:
	# La cote du couronnement, c'est celle du lac — et elle a été décidée par le
	# terrain (`_relief`), pas par une constante. On la RELIT plutôt que de la
	# recalculer : deux calculs du même nombre finissent toujours par diverger,
	# et ici la divergence serait un barrage à côté de sa retenue.
	var y := v.sol(Vector2i(LAC.get_center()))
	for i in range(LAC.position.x - 2, LAC.end.x + 2):
		var c := Vector2i(i, BARRAGE_J)
		if not v.dedans(c): continue
		v.poser_terre(c, y)
		v.poser_matiere(c, Ville2.M_DALLE)
		# Le parement : trois rangs de mur empilés sous le couronnement, soit
		# quinze mètres — la retenue plus l'encastrement dans le terrain aval.
		for k in 3:
			v.objets.append({"m": "pxl/mur-soutenement", "x": (float(i) + 0.5) * CASE,
				"z": (float(BARRAGE_J) + 1.0) * CASE, "r": 0.0, "h": 0.0,
				"y_abs": y - float(k + 1) * PALIER, "zone": true})
	v.interdire(Rect2(float(LAC.position.x - 2) * CASE, float(BARRAGE_J) * CASE + 6.0,
		float(LAC.size.x + 4) * CASE, CASE * 2.0))
	v.ajouter_lieu("barrage", (float(LAC.position.x) + float(LAC.size.x) * 0.5) * CASE,
		(float(BARRAGE_J) + 0.5) * CASE, {"nom": "Barrage du Haut-Lac"})

## LA CARRIÈRE : de la roche à nu, des gradins, des engins. C'est le seul
## endroit de la carte où l'on creuse SOUS le terrain naturel.
static func _la_carriere(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := CARRIERE
	var centre := Vector2(r.get_center())
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): continue
			var d := (Vector2(c) - centre).length() / (float(r.size.x) * 0.5)
			# Des gradins concentriques : c'est ce qui fait lire une carrière,
			# et c'est la même géométrie que les terrasses de la colline.
			var creux := roundf(maxf(0.0, 3.0 - d * 3.0))
			v.poser_terre(c, v.sol(c) - creux * PALIER)
			v.poser_matiere(c, Ville2.M_ROCHE)
	for k in 24:
		var n := alea.randi() % ROCHES.size()
		v.ajouter_objet(ROCHES[n], (float(r.position.x) + alea.randf() * float(r.size.x)) * CASE,
			(float(r.position.y) + alea.randf() * float(r.size.y)) * CASE,
			alea.randf() * TAU, float(H_ROCHES[n]))
	v.ajouter_objet("pxl/grue-mobile", (float(r.position.x) + 1.0) * CASE,
		(float(r.position.y) + 1.0) * CASE, 0.0)
	v.ajouter_lieu("carriere", centre.x * CASE, centre.y * CASE, {"nom": "Carrière du Levant"})

## LE VILLAGE : « un village avec église et bar » (§ 2). Le bâti vient du kit
## pavillons, comme le village perché de la colline — c'est le seul kit dont
## les volumes (un corps simple sous un toit à deux pentes) se lisent comme de
## la campagne.
const MAISONS_DE_VILLAGE := ["pavillons/building-type-a", "pavillons/building-type-c",
	"pavillons/building-type-e", "pavillons/building-type-j",
	"pavillons/building-type-o", "pavillons/building-type-l"]

static func _le_village(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := VILLAGE
	var y := v.sol(Vector2i(r.get_center()))
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var c := Vector2i(i, j)
			if v.dedans(c) and v.terre(c): v.poser_terre(c, y)
	# La rue du village, d'un bout à l'autre, et les maisons qui la bordent.
	var jr := r.position.y + r.size.y / 2
	v.ajouter_route(Ville2.R_RUE, [Vector2i(r.position.x, jr), Vector2i(r.end.x - 1, jr)],
		"Grand-Rue")
	v.rasteriser()
	Lotisseur.aligner(v, alea, MAISONS_DE_VILLAGE, "n",
		Vector2i(r.position.x * 2, (jr + 1) * 2), (r.size.x - 1) * 2, "maison", 0.85, 1)
	Lotisseur.aligner(v, alea, MAISONS_DE_VILLAGE, "s",
		Vector2i(r.position.x * 2, (jr - 1) * 2), (r.size.x - 1) * 2, "maison", 0.85, 1)
	# L'ÉGLISE, le repère du village : c'est un modèle du client, et un village
	# sans clocher ne se reconnaît pas d'en haut.
	var e := KitVille2.emprise_tournee("piksl/eglise", 0)
	var hx := (r.position.x + 1) * 2
	var hy := (jr - 4) * 2
	if Lotisseur.terrain_libre(v, hx, hy, e):
		v.ajouter_lot("piksl/eglise", hx, hy, e.x, e.y, 0, "eglise")
	v.ajouter_lieu("bar", (float(r.end.x) - 2.5) * CASE, (float(jr) - 1.5) * CASE,
		{"nom": "Le Café de la Place"})
	v.ajouter_lieu("village", float(r.get_center().x) * CASE, float(r.get_center().y) * CASE,
		{"nom": "Sainte-Colombe"})

## L'OBSERVATOIRE au sommet (§ 2). Faute de coupole dans le kit, c'est
## l'antenne du client qui tient le point haut — et de tout l'arrière-pays,
## c'est elle qu'on voit en premier.
static func _l_observatoire(v: Ville2) -> void:
	var c := OBSERVATOIRE
	if not v.dedans(c) or not v.terre(c): return
	v.ajouter_objet("pxl/pylone-telecom", (float(c.x) + 0.5) * CASE,
		(float(c.y) + 0.5) * CASE, 0.0)
	v.ajouter_objet("pxl/antenne-parabole", (float(c.x) + 1.6) * CASE,
		(float(c.y) + 0.6) * CASE, 0.0)
	v.ajouter_lieu("observatoire", (float(c.x) + 0.5) * CASE, (float(c.y) + 0.5) * CASE,
		{"nom": "L'Observatoire"})

## LE LAC : une retenue peinte sur un bassin plat, sa grève et ses pontons
## (§ 2 : « un lac (plage, cabanes, pontons) »).
##
## ⚠ SON EAU EST PEINTE, PAS CREUSÉE — voir l'avertissement de `_relief` : la
## nappe d'eau du moteur est à la cote de la MER, une pour toute la carte, donc
## une retenue perchée ne peut pas en être faite. `parc.gd` avait tranché
## pareil pour son bassin.
##
## ⚠⚠ ET AUCUN LOBE NE DOMINE LES AUTRES. C'est la troisième fois que cette
## règle se paie sur ce projet — l'île de Pikstown, le bassin du parc, et ici :
## « une union de rectangles (ou d'ellipses) dont l'un est le plus grand A LA
## FORME DU PLUS GRAND ». Sept lobes de taille comparable posés sur un anneau,
## aucun au centre : leur union a un contour cassé, et un contour cassé se lit
## comme une rive.
const LOBES_DU_LAC := 7

static func _le_lac(v: Ville2, alea: RandomNumberGenerator) -> void:
	var centre := Vector2(LAC.get_center())
	var rx := float(LAC.size.x) * 0.5 * CASE * 0.78
	var rz := float(LAC.size.y) * 0.5 * CASE * 0.78
	var cx := (centre.x + 0.5) * CASE
	var cz := (centre.y + 0.5) * CASE
	var lobes: Array = []
	for k in LOBES_DU_LAC:
		var a := TAU * float(k) / float(LOBES_DU_LAC) + alea.randf_range(-0.25, 0.25)
		var d := alea.randf_range(0.34, 0.62)
		lobes.append({"x": cx + cos(a) * rx * d, "z": cz + sin(a) * rz * d,
			"w": rx * alea.randf_range(0.75, 1.45), "d": rz * alea.randf_range(0.75, 1.45)})
	# ⚠ CHAQUE NAPPE À SA PROPRE HAUTEUR. Sept surfaces planes au même niveau se
	# battent pour le même pixel et le lac se couvre de rayures (leçon du parc,
	# 14/09). Un centimètre d'écart entre chacune suffit et ne se voit pas.
	for k2 in lobes.size():
		var l: Dictionary = lobes[k2]
		v.objets.append({"m": "pelouse", "x": l["x"], "z": l["z"], "r": 0.0, "h": 0.0,
			"w": float(l["w"]) + 14.0, "d": float(l["d"]) + 14.0, "c": PARC.GREVE,
			"dy": 0.012 * float(k2), "zone": true})
	for k3 in lobes.size():
		var l2: Dictionary = lobes[k3]
		v.objets.append({"m": "pelouse", "x": l2["x"], "z": l2["z"], "r": 0.0, "h": 0.0,
			"w": l2["w"], "d": l2["d"], "c": PARC.EAU_DE_PARC,
			"dy": 0.15 + 0.012 * float(k3), "zone": true})
	# ⚠ ET ON RÉSERVE LE SOL SOUS L'EAU PEINTE. La case reste de la terre : sans
	# réservation, la passe de semis y plante des arbres AU MILIEU DU LAC, et la
	# passe d'herbe y sème des touffes. C'est mot pour mot ce qui est arrivé au
	# bassin du parc.
	for j in range(LAC.position.y - 1, LAC.end.y + 1):
		for i in range(LAC.position.x - 1, LAC.end.x + 1):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): continue
			var dx := ((float(i) + 0.5) * CASE - cx) / maxf(rx, 0.01)
			var dz := ((float(j) + 0.5) * CASE - cz) / maxf(rz, 0.01)
			var r2 := dx * dx + dz * dz
			if r2 > 1.7: continue
			v.poser_matiere(c, Ville2.M_SABLE)
			for b in 2:
				for a2 in 2:
					v.demi_prises[Vector2i(i * 2 + a2, j * 2 + b)] = true
			# La rive : des pins sur la grève, jamais dans l'eau.
			if r2 > 1.25 and alea.randf() < 0.35:
				v.ajouter_objet("nature/tree_pineSmallB", (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU, 6.0)
	# Trois pontons sur la rive ouest. ⚠ Ils ne sont PAS des `plateforme` : le
	# tablier d'une plateforme se cote au-dessus de LA MER (`NIVEAU_MER + y`),
	# ce qui est juste pour une jetée et faux de vingt mètres pour un ponton de
	# lac perché. Des planches posées au sol, à quelques centimètres, font le
	# même office et suivent leur terrain.
	for k4 in 3:
		var jz := LAC.position.y + 3 + k4 * 4
		v.ajouter_objet("nature/bridge_wood", (float(LAC.position.x) + 1.5) * CASE,
			(float(jz) + 0.5) * CASE, 0.0)
	v.ajouter_lieu("lac", cx, cz, {"nom": "Le Haut-Lac"})

# ------------------------------------------------------------------ 7. le semis

## LA CAMPAGNE. Trois règles, et pas une de plus : des pins sur les hauteurs,
## des feuillus en plaine, des palmiers sur le sable. Le reste — les touffes
## d'herbe — est la passe commune de `proprete.gd`.
##
## ⚠ ON NE SÈME PAS SUR UN PLATEAU. Un témoin greffé a déjà rempli son carré,
## et un arbre de plus au milieu d'une rue du centre est exactement ce que le
## client a refusé trois fois. `plate()` et le registre des demi-cases s'en
## chargent, mais la vérification est ici aussi : elle ne coûte rien et elle
## est la dernière ligne de défense.
static func _semer_la_campagne(v: Ville2, alea: RandomNumberGenerator, densite: float) -> void:
	if densite <= 0.0: return
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c) or v.plate(c): continue
			if v.quartier_en(c) >= 0 and _sur_un_plateau(c): continue
			if not v.demi_libre(i * 2, j * 2, 2, 2): continue
			var m := v.matiere_de(c)
			var x := (float(i) + alea.randf()) * CASE
			var z := (float(j) + alea.randf()) * CASE
			if m == Ville2.M_SABLE:
				if alea.randf() > 0.10 * densite: continue
				var n := alea.randi() % PALMIERS.size()
				v.ajouter_objet(PALMIERS[n], x, z, alea.randf() * TAU, float(H_PALMIERS[n]))
			elif m == Ville2.M_ROCHE:
				if alea.randf() > 0.18 * densite: continue
				var n2 := alea.randi() % ROCHES.size()
				v.ajouter_objet(ROCHES[n2], x, z, alea.randf() * TAU, float(H_ROCHES[n2]))
			else:
				if alea.randf() > 0.30 * densite: continue
				# La ligne de crête aux conifères, les basses terres aux
				# feuillus : c'est la règle déjà retenue pour le relief
				# (`claude/relief-et-assets.md`), et elle suffit à faire lire
				# une altitude sans qu'on ait à la mesurer.
				var haut := v.sol(c) >= float(PALIER_ARRIERE_PAYS - 3) * PALIER
				var liste: Array = ARBRES_DE_CRETE if haut else ARBRES_DE_PLAINE
				var hauteurs: Array = H_CRETE if haut else H_PLAINE
				var n3 := alea.randi() % liste.size()
				v.ajouter_objet(String(liste[n3]), x, z, alea.randf() * TAU,
					float(hauteurs[n3]))

static func _sur_un_plateau(c: Vector2i) -> bool:
	for f in PLATEAUX:
		if ((f as Dictionary)["z"] as Rect2i).grow(1).has_point(c): return true
	return false

# ------------------------------------------------------------------
# CE QUI RESTE À FAIRE, dans l'ordre où je le ferais
# ------------------------------------------------------------------
#
# 1. ROULER SUR LES PONTS. Les cinq ponts se voient (tablier, piles,
#    lampadaires, et les rails y sont posés depuis la correction du 14/09 dans
#    `rendu_ville2.gd`) mais leur chaussée n'est pas rastérisée : on ne roule
#    pas dessus. Ce n'est PAS une ligne à changer — c'est `rasteriser`,
#    `Ville2.plate` et `TerrainV2.hauteur_coin` ensemble, faute de quoi le fond
#    de la mer se soulève jusqu'au tablier (voir l'avertissement de
#    `_les_ponts`). À faire avec les voies rapides surélevées, qui posent le
#    même problème, et pas avant.
# 2. LE PONT À HAUBANS, en pièce modelée (`modeles/pxl/`) : deux pylônes et ses
#    câbles. C'est « la pièce maîtresse » du cahier, et c'est la seule chose de
#    la carte qu'on photographiera pour elle-même.
# 3. LES VOIES RAPIDES SURÉLEVÉES. La rocade et la traversante portent déjà
#    `niveau: 1`, et rien ne lit ce champ : elles sont au sol. Même mécanique
#    que les ponts — un tablier, des piles, des bretelles en courbe large.
# 4. L'ARRIÈRE-PAYS POUR DE VRAI. Aérodrome, village, carrière, barrage et lac
#    sont des repérages ; chacun vaut un témoin de travail.
# 5. LA COUTURE DES TÉMOINS. Les anneaux de ceinture ramassent les rues, mais
#    personne n'a encore vérifié qu'une rue de témoin tombe bien EN FACE de
#    l'anneau. Ça se regarde à la capture, plateau par plateau.
# 6. LE CONTRÔLE. `outils/verifier_temoins.gd` compte les objets sur la
#    chaussée, les lots qui se chevauchent et les modèles absents. Il faut la
#    même table pour la carte entière, plus trois colonnes qu'elle seule
#    réclame : composantes connexes de la voirie (la carte est-elle d'un seul
#    tenant, ponts compris ?), îles réellement séparées, et cases de quartier
#    laissées à découvert entre deux plateaux.
