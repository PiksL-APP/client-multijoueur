#!/usr/bin/env python3
"""PIKSTOWN — le dessin de la grande île, engendré puis RELU À LA MAIN.

    python3 outils/pikstown.py            écrit jeux/carnage/plans/pikstown.txt

⚠ CE QUE CET OUTIL EST, ET CE QU'IL N'EST PAS. Il n'engendre pas « une ville » :
il pose la TRAME — le trait de côte, les chenaux, les avenues, le découpage des
îlots — sur 225 × 215 cases, c'est-à-dire 48 375 caractères que personne
n'écrira à la main. Le goût, lui, se met après, dans le fichier, à la souris ou
au clavier : le dessin produit ici est un point de départ versionné, pas une
vérité qu'on régénère. Trois maquettes procédurales ont été refusées sur ce
projet ; celle-ci ne survit que parce qu'on la RELIT ensuite comme un dessin.

LES RÈGLES QU'IL RESPECTE, ET POURQUOI

1. TOUT EST AU PALIER 0. Le client l'a demandé — « toutes sur le même plan » —
   et ça a une conséquence heureuse : les deux tiers des fautes de
   `Quartiers.fautes` portent sur les marches (rampe au pied d'un carrefour,
   marche de plus de deux paliers, bâtiment à cheval). Sans relief, il n'en
   reste qu'une à surveiller : les ronds-points.
2. UN ROND-POINT MANGE 3 × 3 CASES au même palier, sur son centre. Posé sur un
   carrefour de bord d'îlot, il déborde sur les façades et disparaît en
   silence. On ne les pose donc qu'aux croisements d'AVENUES, et on creuse les
   neuf cases avant.
3. LES EMPRISES DU KIT : T et B tiennent sur 3 cases, C sur 2, M et V sur 1,
   H sur 4. Un bloc de lettres identiques est UN bâtiment étiré sur tout le
   rectangle — un pavillon de quatre cases devient un bungalow de quarante
   mètres avec une porte de garage de dix. Chaque îlot est donc DÉCOUPÉ en
   bâtiments à l'emprise de leur famille, et deux voisins de même famille
   alternent MAJUSCULE / minuscule pour ne pas fusionner.
4. LES CHENAUX SE FRANCHISSENT. Un secteur sans pont est une île, et le joueur
   ne la quitte pas : chaque chenal a ses ponts, alignés sur une avenue des
   deux rives — sinon le pont tombe sur une façade.
"""

import random
from pathlib import Path

# ⚠ UNE SEULE LIGNE POUR CHANGER LA TAILLE DE LA VILLE. Tout le reste du
# fichier écrit ses coordonnées dans la TRAME DE RÉFÉRENCE 225 × 215 — celle où
# la carte a été composée à l'œil — et `X()` / `Y()` les y ramènent. Sans ça,
# agrandir la ville voulait dire retoucher à la main soixante nombres (les
# lobes, les îles, les chenaux, le parc, le stade, la darse, les quatorze
# percées), et en oublier un.
#
# ⚠ CE QUI NE SE MET PAS À L'ÉCHELLE : l'écartement des rues, la largeur d'un
# îlot, l'emprise d'un bâtiment, le recul des boulevards de ceinture. Un pâté
# de maisons mesure ce qu'il mesure ; une ville deux fois plus grande a DEUX
# FOIS PLUS d'îlots, pas des îlots deux fois plus gros. C'est exactement la
# faute qu'on fait en multipliant tout par le même facteur.
LARGE, HAUT = 320, 300
REF_LARGE, REF_HAUT = 225, 215


def X(v):
    return int(round(v * LARGE / REF_LARGE))


def Y(v):
    return int(round(v * HAUT / REF_HAUT))
EAU, HERBE, SABLE, PAVE, PARKING = ".", ",", ";", "o", "P"
RUE, PONT, ROND = "#", "=", "O"
ARBRES, BUISSONS, DEPOT, CHANTIER, MOUILLAGE = "^", "'", "X", "%", "~"

# L'emprise maximale de chaque famille, en cases (cf. EMPRISES de quartiers.gd).
EMPRISE = {"T": 3, "B": 3, "C": 2, "M": 1, "V": 1, "H": 4}

alea = random.Random(20260909)

grille = [[EAU] * LARGE for _ in range(HAUT)]


def poser(x, y, c):
    if 0 <= x < LARGE and 0 <= y < HAUT:
        grille[y][x] = c


def lire(x, y):
    if 0 <= x < LARGE and 0 <= y < HAUT:
        return grille[y][x]
    return EAU


def rect(x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(HAUT, y1 + 1)):
        for x in range(max(0, x0), min(LARGE, x1 + 1)):
            grille[y][x] = c


# ───────────────────────────── le trait de côte ─────────────────────────────
#
# ⚠ PAS UN RECTANGLE BRUITÉ. Le premier jet posait un rectangle et ondulait ses
# quatre bords : de haut, ça restait un plateau de jeu — on voyait le rectangle
# à travers l'ondulation, et 74 % de la carte était de la terre.
#
# L'île est donc l'UNION DE LOBES qui se chevauchent à peine, plus un bruit de
# frontière. Trois gros lobes font les trois secteurs d'Anywhere City, deux
# petits font un cap et une presqu'île ; là où deux lobes ne se touchent pas
# tout à fait, la mer entre d'elle-même et fait une baie qu'aucune main n'a
# dessinée. C'est ce qui donne des caps, des anses et des culs-de-sac — et ça
# ramène la terre autour de la moitié de la carte, ce qui est aussi le budget
# de nœuds.

import math

# centre x, centre y, rayon x, rayon y
# ⚠ LES LOBES DOIVENT SE CHEVAUCHER D'AU MOINS VINGT CASES. Sinon le chenal
# qu'on creuse entre deux mange tout le recouvrement et l'île se coupe en
# deux : c'est ce qui a donné, deux fois, un archipel là où on demandait une
# grosse île. La vérification de fin le mesure et refuse de se taire.
LOBES = [(X(a), Y(b), X(c), Y(d)) for a, b, c, d in [
    (96, 44, 84, 50),      # le Centre, large et haut
    (92, 116, 80, 48),     # le Résidentiel
    (128, 180, 90, 42),    # l'Industrie, débordant à l'est
    (188, 66, 40, 30),     # le cap du nord-est, soudé au Centre
    (44, 172, 34, 25),     # la presqu'île du sud-ouest
]]


# ⚠ LES ÎLES SATELLITES SONT DES LOBES COMME LES AUTRES, mais posées LOIN de
# l'île principale pour que la mer les sépare d'elle-même. Une île qu'on
# rattache par un cordon de terre n'est plus une île, c'est un cap — et
# l'archipel, c'est justement ce qui fait qu'on regarde l'horizon.
ILES = [(X(a), Y(b), X(c), Y(d), q) for a, b, c, d, q in [
    (28, 46, 15, 12, "villegiature"),    # au nord-ouest, en face du centre
    (206, 132, 14, 16, "villegiature"),  # à l'est, entre le résidentiel et l'industrie
    (16, 108, 11, 9, "nature"),          # la petite au large de la plage
    (120, 22, 12, 8, "nature"),          # au nord du centre
    (200, 206, 13, 10, "industrie"),     # au sud-est, dans le prolongement du port
    (62, 208, 12, 9, "villegiature"),    # au sud-ouest
    # ⚠ CES QUATRE-LÀ SONT AU LARGE, ET C'EST TOUT L'ENJEU. Le premier jet les
    # avait posées à des coordonnées qui tombaient DANS les lobes : elles ont
    # fusionné avec la côte sans un mot, et le compte des composantes connexes
    # est le seul endroit où ça se voyait. Une île se pose dans l'eau, et on
    # vérifie qu'elle y est restée.
    (20, 82, 11, 8, "nature"),           # dans le chenal nord, côté ouest
    (206, 100, 12, 9, "villegiature"),   # au large de l'est
    (16, 196, 12, 9, "nature"),          # au sud-ouest
    (208, 18, 11, 8, "villegiature"),    # au nord-est
]]


def bruit(x, y):
    """Trois octaves de sinus croisés. Pures maths, aucune dépendance, et le
    même dessin à chaque exécution — un tirage aléatoire ici rendrait le
    fichier non reproductible, donc non relisible dans un diff."""
    return (0.50 * math.sin(x * 0.031 + y * 0.019)
            + 0.30 * math.sin(x * 0.071 - y * 0.053 + 1.7)
            + 0.20 * math.sin(x * 0.147 + y * 0.113 + 4.2))


def terre_de_base():
    for y in range(HAUT):
        for x in range(LARGE):
            force = -9.0
            for cx, cy, rx, ry in LOBES:
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                force = max(force, 1.0 - d)
            if force + 0.30 * bruit(x, y) > 0.15:
                grille[y][x] = HERBE


def poser_iles():
    for cx, cy, rx, ry, _quoi in ILES:
        for y in range(cy - ry - 4, cy + ry + 5):
            for x in range(cx - rx - 4, cx + rx + 5):
                if not (0 <= x < LARGE and 0 <= y < HAUT):
                    continue
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d + 0.34 * bruit(x * 2.1, y * 2.1) < 1.0:
                    grille[y][x] = HERBE


# ───────────────────────────── les chenaux et les baies ─────────────────────
#
# Les lobes laissent déjà passer la mer entre eux ; on ÉLARGIT ces passages
# pour en faire de vrais bras de mer, larges de huit à seize cases — assez pour
# qu'un pont soit un pont, pas un caniveau enjambé.

CHENAL_NORD = Y(80)
CHENAL_SUD = Y(150)


def chenal(centre, base, phase, x0=0, x1=LARGE - 1):
    """⚠ UN CHENAL QUI TRAVERSE TOUTE LA CARTE FAIT DEUX ÎLES. Le premier jet en
    creusait deux de bord à bord : la « grosse île » demandée était en fait un
    archipel de trois galettes reliées par des ponts de trois cents mètres, et
    ça se voyait de la première photo. Chacun s'arrête donc avant un bord — au
    nord-est pour l'un, au sud-ouest pour l'autre — et laisse un ISTHME. On
    traverse la ville à pied ou en voiture sans pont ; les ponts ne sont plus
    que des raccourcis, ce qu'ils doivent être."""
    for x in range(max(0, x0), min(LARGE, x1 + 1)):
        c = centre + int(5.0 * math.sin(x * 0.037 + phase) + 3.0 * math.sin(x * 0.019 + 2.0))
        demi = (base + int(3.0 * (1.0 + math.sin(x * 0.026 + phase)))) // 2
        for y in range(c - demi, c + demi + 1):
            poser(x, y, EAU)


def limites_chenal(x, centre, base, phase):
    c = centre + int(5.0 * math.sin(x * 0.037 + phase) + 3.0 * math.sin(x * 0.019 + 2.0))
    demi = (base + int(3.0 * (1.0 + math.sin(x * 0.026 + phase)))) // 2
    return c - demi - 1, c + demi + 1


def baie(cx, cy, rx, ry):
    """Une anse creusée dans la côte. Sans elles, chaque lobe se referme en
    galette et la ville n'a pas de bord de mer à l'intérieur d'elle-même."""
    for y in range(HAUT):
        for x in range(LARGE):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d + 0.26 * bruit(x * 1.6, y * 1.6) < 1.0:
                grille[y][x] = EAU


# ───────────────────────────── la trame des rues ─────────────────────────────
#
# CHAQUE SECTEUR A SON RYTHME. C'est ce qui remplace l'angle : on ne peut plus
# tourner les quartiers, mais un îlot de bureaux de 6 × 4 et un îlot pavillon-
# naire de 8 × 6 ne se ressemblent pas vus d'avion, et c'est bien ce qu'on
# cherchait en les inclinant. Les AVENUES (une colonne sur trois) portent les
# ronds-points et les têtes de pont.

# ⚠ LES BANDES SE TOUCHENT, sans marge. Le premier jet laissait quatre cases
# non tramées de chaque côté d'un chenal « pour la sécurité » : comme le chenal
# ondule de huit cases, ça faisait par endroits vingt cases de pelouse nue le
# long de deux cents cases de rive — et surtout, l'ISTHME qui relie deux
# secteurs n'avait aucune route. On traversait la ville par un pré. `tramer`
# saute l'eau tout seul ; la marge ne servait à rien qu'à créer ce vide.
SECTEURS = [
    # nom, y0, y1, pas en x, pas en y, avenue toutes les n colonnes
    ("centre", 0, CHENAL_NORD, 7, 5, 3),
    ("residentiel", CHENAL_NORD + 1, CHENAL_SUD, 9, 7, 3),
    ("industrie", CHENAL_SUD + 1, HAUT - 1, 13, 9, 2),
]


def avenues_x(pas, tous):
    return [x for x in range(4, LARGE, pas) if (x // pas) % tous == 0]


def distances_a_la_mer():
    """La distance de chaque case à l'eau la plus proche, en pas orthogonaux.
    Un simple parcours en largeur depuis toute la mer à la fois. Sert au
    boulevard de ceinture et au traitement des rives."""
    INF = 9999
    d = [[INF] * LARGE for _ in range(HAUT)]
    file = []
    for y in range(HAUT):
        for x in range(LARGE):
            if grille[y][x] == EAU:
                d[y][x] = 0
                file.append((x, y))
    tete = 0
    while tete < len(file):
        x, y = file[tete]
        tete += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < LARGE and 0 <= ny < HAUT and d[ny][nx] == INF:
                d[ny][nx] = d[y][x] + 1
                file.append((nx, ny))
    return d


def ceinture(recul=3):
    """LE BOULEVARD DE CEINTURE — une rue qui suit la côte à trois cases du
    bord, tout autour de l'île.

    ⚠ C'est LA correction du « trop carré ». Une trame orthogonale s'arrête net
    sur une côte courbe : on obtient des dizaines de moignons de rue face à la
    mer, et le damier saute aux yeux parce que rien ne le contredit. Un
    boulevard qui épouse le trait de côte, lui, coupe la trame en biais partout
    où la côte n'est pas droite — et il découpe au passage des îlots
    triangulaires, ceux qu'aucune grille ne sait faire.
    """
    d = distances_a_la_mer()
    for y in range(HAUT):
        for x in range(LARGE):
            if d[y][x] == recul:
                poser(x, y, RUE)


def ecarts(debut, fin, base, jeu):
    """Des positions à écartement VARIABLE. `range(4, LARGE, 7)` donne des îlots
    tous identiques : c'est le damier, et aucune ville n'en a un parfait.
    Ici l'écart oscille entre `base - jeu` et `base + jeu`."""
    liste = []
    x = debut
    while x <= fin:
        liste.append(x)
        x += base + alea.randint(-jeu, jeu)
    return liste


def rue_ondulee(y, x0, x1, amplitude, periode, phase):
    """Une rue qui DÉRIVE le long de son parcours, en marches d'escalier. Le kit
    n'a que des tuiles droites, des virages et des carrefours — donc aucune
    courbe. Mais une rue qui monte d'une case tous les six pas se lit de haut
    comme une avenue en biais, et c'est exactement ce que fait n'importe quelle
    ville bâtie sur autre chose qu'un plat parfait."""
    precedent = None
    for x in range(x0, x1 + 1):
        cy = y + int(round(amplitude * math.sin(x / periode + phase)))
        if precedent is not None and cy != precedent:
            # Le coude : on pose la colonne entre les deux hauteurs, sinon la
            # rue « saute » d'une case et se coupe en deux.
            for k in range(min(cy, precedent), max(cy, precedent) + 1):
                if lire(x, k) != EAU:
                    poser(x, k, RUE)
        if lire(x, cy) != EAU:
            poser(x, cy, RUE)
        precedent = cy


def diagonale(x0, y0, x1, y1):
    """Une percée en biais à travers la trame — le boulevard qui ne respecte
    pas le damier. Tracée en Bresenham épaissi d'une case pour rester
    franchissable après l'ébarbage."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    while True:
        if lire(x, y) != EAU:
            poser(x, y, RUE)
        if (x, y) == (x1, y1):
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
            if lire(x, y) != EAU:
                poser(x, y, RUE)
        if e2 <= dx:
            err += dx
            y += sy


def impasses(y0, y1, combien):
    """DES IMPASSES, posées APRÈS l'ébarbage — sinon il les mangerait, puisque
    c'est exactement ce qu'il chasse : une rue à un seul voisin. Un lotissement
    sans cul-de-sac n'est pas un lotissement, et le kit a une tuile faite pour
    ça (`road-end-round`), qui ne servait nulle part."""
    poses = 0
    essais = 0
    while poses < combien and essais < combien * 60:
        essais += 1
        x = alea.randint(6, LARGE - 7)
        y = alea.randint(max(1, y0), min(HAUT - 2, y1))
        if lire(x, y) != RUE:
            continue
        dx, dy = alea.choice(((0, 1), (0, -1), (1, 0), (-1, 0)))
        longueur = alea.randint(2, 4)
        cases = [(x + dx * (k + 1), y + dy * (k + 1)) for k in range(longueur)]
        if any(lire(cx, cy) not in (HERBE,) for cx, cy in cases):
            continue
        # Pas d'impasse qui vient coller une autre rue : ce serait une rue,
        # pas une impasse.
        if any(lire(cx + a, cy + b) in (RUE, PONT, ROND)
               for cx, cy in cases[1:] for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))
               if (a, b) != (-dx, -dy)):
            continue
        for cx, cy in cases:
            poser(cx, cy, RUE)
        poses += 1
    return poses


def avenue_ondulee(x, y0, y1, amplitude, periode, phase):
    """La même dérive, dans l'autre sens. Une trame dont SEULES les rues
    ondulent reste une trame : ce sont les colonnes qui tiennent le damier, et
    tant qu'elles sont parfaitement droites sur deux cents cases, l'œil les
    suit et voit la grille."""
    precedent = None
    for y in range(y0, y1 + 1):
        cx = x + int(round(amplitude * math.sin(y / periode + phase)))
        if precedent is not None and cx != precedent:
            for k in range(min(cx, precedent), max(cx, precedent) + 1):
                if lire(k, y) != EAU:
                    poser(k, y, RUE)
        if lire(cx, y) != EAU:
            poser(cx, y, RUE)
        precedent = cx


def tramer(y0, y1, pas_x, pas_y):
    """La trame d'un secteur : écartements variables dans les deux sens, et une
    voie sur deux qui dérive. Le damier ne survit pas à ça — et c'est le but :
    ce qu'on avait perdu en interdisant d'incliner les quartiers, on le
    retrouve ici, à l'intérieur d'une seule trame."""
    rang = 0
    for x in ecarts(4, LARGE - 1, pas_x, max(1, pas_x // 3)):
        rang += 1
        if rang % 2 == 0:
            avenue_ondulee(x, y0, y1, 1.5 + alea.random() * 2.0,
                           16.0 + alea.random() * 20.0, alea.random() * 6.28)
        else:
            for y in range(y0, y1 + 1):
                if lire(x, y) != EAU:
                    poser(x, y, RUE)
    rang = 0
    for y in ecarts(y0 + 2, y1, pas_y, max(1, pas_y // 3)):
        rang += 1
        if rang % 2 == 0:
            rue_ondulee(y, 0, LARGE - 1, 2.0 + alea.random() * 2.0,
                        16.0 + alea.random() * 24.0, alea.random() * 6.28)
        else:
            for x in range(LARGE):
                if lire(x, y) != EAU:
                    poser(x, y, RUE)


def ebarber():
    """UNE RUE QUI NE MÈNE NULLE PART N'EST PAS UNE RUE. La trame posée sur une
    côte découpée laisse des moignons d'une ou deux cases qui plongent dans
    l'eau ; on les retire tant qu'il en reste."""
    change, tours = True, 0
    while change and tours < 16:
        change, tours = False, tours + 1
        for y in range(HAUT):
            for x in range(LARGE):
                if grille[y][x] != RUE:
                    continue
                voisins = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                              if lire(x + dx, y + dy) in (RUE, PONT, ROND))
                if voisins <= 1:
                    grille[y][x] = HERBE
                    change = True


# ───────────────────────────── les îlots ─────────────────────────────


def ilots(y0, y1):
    vus = set()
    trouves = []
    for y in range(y0, y1 + 1):
        for x in range(LARGE):
            if (x, y) in vus or lire(x, y) != HERBE:
                continue
            pile, bloc = [(x, y)], []
            vus.add((x, y))
            while pile:
                cx, cy = pile.pop()
                bloc.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (nx, ny) in vus or not (y0 <= ny <= y1):
                        continue
                    if lire(nx, ny) == HERBE:
                        vus.add((nx, ny))
                        pile.append((nx, ny))
            if len(bloc) >= 2:
                trouves.append(bloc)
    return trouves


def batir_ilot(bloc, palette, part_vert, part_pave):
    """Découpe un îlot en bâtiments À L'EMPRISE DE LEUR FAMILLE.

    ⚠ C'est ici que se joue le « pas moche », et le premier jet le ratait de
    deux façons. Une seule famille par îlot rendait le secteur monotone : trois
    cents îlots de tours, c'est un mur. Et l'emprise toujours MAXIMALE donnait
    des façades toutes de la même largeur, ce qu'aucune ville n'a.

    Donc : deux ou trois familles se partagent l'îlot par bandes, et la largeur
    de chaque bâtiment est tirée entre une case et son emprise. La casse
    alterne — deux voisins de même famille et même casse ne feraient qu'UN
    bâtiment étiré sur les deux.
    """
    xs = [c[0] for c in bloc]
    ys = [c[1] for c in bloc]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    dedans = set(bloc)
    tirage = alea.random()
    # ⚠ UN GRAND ÎLOT N'EST JAMAIS TIRÉ EN PARC. Le tirage vaut pour l'îlot
    # ENTIER : sur un bloc de bord de mer de six cents cases, un seul jet de dé
    # couvrait d'arbres un huitième du secteur. Au-delà de cent vingt cases, on
    # bâtit, et le parc se gagne au découpage.
    if len(bloc) > 120:
        tirage = 1.0
    if tirage < part_vert:
        for (x, y) in bloc:
            poser(x, y, ARBRES if alea.random() < 0.58 else BUISSONS)
        return
    if tirage < part_vert + part_pave and len(bloc) <= 40:
        # ⚠ SEULEMENT LES PETITS ÎLOTS. Un îlot de cent cases entièrement pavé
        # sort en aplat gris de trente mètres sur trente : sur la vue
        # d'ensemble, c'était le seul défaut qu'on voyait avant la ville.
        for (x, y) in bloc:
            poser(x, y, PARKING if alea.random() < 0.5 else PAVE)
        return
    bascule = 0
    x = x0
    while x <= x1:
        famille = alea.choice(palette)
        large = max(1, alea.randint(1, EMPRISE[famille]))
        w = min(large, x1 - x + 1)
        y = y0
        while y <= y1:
            h = min(max(1, alea.randint(1, EMPRISE[famille])), y1 - y + 1)
            lettre = famille if bascule % 2 == 0 else famille.lower()
            bascule += 1
            # Une case de cour de temps en temps : un îlot plein à ras bord
            # n'a ni arrière-cour ni passage, et ça se voit d'en haut.
            cour = alea.random() < 0.07
            for cy in range(y, y + h):
                for cx in range(x, x + w):
                    if (cx, cy) in dedans:
                        poser(cx, cy, HERBE if cour else lettre)
            y += h
        x += w


# ───────────────────────────── les ronds-points ─────────────────────────────


def poser_ronds(y0, y1, pas_x, pas_y, tous, combien):
    """⚠ UN ROND-POINT SE POSE SUR SON CENTRE ET MANGE 3 × 3 CASES au même
    palier. On ne l'essaie qu'aux croisements d'AVENUES, et on creuse les neuf
    cases avant : posé sur un carrefour ordinaire il déborde sur les façades, et
    le bâtisseur le laisse alors tomber en silence."""
    poses, croisements = 0, []
    # ⚠ ON CHERCHE LES VRAIS CROISEMENTS. Tant que la trame était régulière, on
    # pouvait déduire les carrefours de l'écartement ; avec des écarts
    # variables, des rues qui ondulent et un boulevard de ceinture, la seule
    # façon de savoir où deux rues se croisent est de REGARDER la grille.
    for y in range(max(1, y0), min(HAUT - 1, y1 + 1)):
        for x in range(1, LARGE - 1):
            if lire(x, y) != RUE:
                continue
            if all(lire(x + a, y + b) in (RUE, ROND, PONT)
                   for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                croisements.append((x, y))
    alea.shuffle(croisements)
    for (x, y) in croisements:
        if poses >= combien:
            break
        if any(lire(x + dx, y + dy) == EAU
               for dx in range(-2, 3) for dy in range(-2, 3)):
            continue
        if any(lire(x + dx, y + dy) == ROND
               for dx in range(-8, 9) for dy in range(-8, 9)):
            continue
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                poser(x + dx, y + dy, RUE)
        poser(x, y, ROND)
        poses += 1
    return poses


# ───────────────────────────── les ponts ─────────────────────────────


def ponter(centre, base, phase, colonnes):
    """Un pont par colonne demandée : de la rive nord à la rive sud, en `=`. La
    colonne doit porter une avenue des DEUX côtés, sinon le pont débouche sur
    une façade — d'où le choix des colonnes dans l'assemblage, et non ici."""
    poses = 0
    for x in colonnes:
        nord, sud = limites_chenal(x, centre, base, phase)
        while nord > 0 and lire(x, nord) == EAU:
            nord -= 1
        while sud < HAUT - 1 and lire(x, sud) == EAU:
            sud += 1
        if lire(x, nord) == EAU or lire(x, sud) == EAU or sud - nord > 40:
            continue
        for y in range(nord + 1, sud):
            poser(x, y, PONT)
        poser(x, nord, RUE)
        poser(x, sud, RUE)
        poses += 1
    return poses


def ponts_propres(longueur_max=26):
    """⚠ ON VÉRIFIE CHAQUE PONT, on ne le suppose pas. `ponter` part d'une rive
    et avance jusqu'à retrouver la terre — mais si la rive d'en face est un
    caillou de trois cases, ou à quarante cases de là, on obtient un pont qui
    s'arrête au milieu de la mer. Sur la vue d'ensemble ça se voit tout de
    suite, et c'est le genre de chose qu'un dessin de 48 000 cases cache très
    bien tant qu'on ne la mesure pas. Tout pont qui ne joint pas deux vraies
    rives est effacé.
    """
    effaces = 0
    vus = set()
    for y in range(HAUT):
        for x in range(LARGE):
            if grille[y][x] != PONT or (x, y) in vus:
                continue
            # La file de `=`, dans les deux sens.
            file = [(x, y)]
            vus.add((x, y))
            pile = [(x, y)]
            while pile:
                cx, cy = pile.pop()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (nx, ny) in vus or not (0 <= nx < LARGE and 0 <= ny < HAUT):
                        continue
                    if grille[ny][nx] == PONT:
                        vus.add((nx, ny))
                        file.append((nx, ny))
                        pile.append((nx, ny))
            # Les extrémités : une case de pont qui touche autre chose que du
            # pont et de l'eau est une tête de pont.
            tetes = 0
            for cx, cy in file:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    v = lire(cx + dx, cy + dy)
                    if v not in (EAU, PONT, MOUILLAGE):
                        tetes += 1
                        break
            if tetes < 2 or len(file) > longueur_max:
                for cx, cy in file:
                    grille[cy][cx] = EAU
                effaces += 1
    return effaces


# ───────────────────────────── le bord de mer ─────────────────────────────


def facades_de_mer():
    """LE BORD DE MER SE TRAITE, il ne se laisse pas en pelouse. Une bande verte
    de six cases entre la dernière rue et l'eau, c'est ce qui faisait ressembler
    les abords des chenaux à un terrain vague — et il y en a deux cents cases de
    long. Première couronne : sable au sud et à l'ouest, promenade pavée
    ailleurs. Deuxième couronne : parc."""
    premiere, seconde = [], []
    for y in range(HAUT):
        for x in range(LARGE):
            if grille[y][x] != HERBE:
                continue
            if any(lire(x + dx, y + dy) == EAU
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                premiere.append((x, y))
    for (x, y) in premiere:
        # Le sable regarde le large (ouest et sud) ; les chenaux intérieurs ont
        # des quais, pas des plages.
        au_large = x < 40 or y > HAUT - 30
        grille[y][x] = SABLE if au_large else PAVE
    for y in range(HAUT):
        for x in range(LARGE):
            if grille[y][x] != HERBE:
                continue
            if any(lire(x + dx, y + dy) in (SABLE, PAVE)
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                seconde.append((x, y))
    for (x, y) in seconde:
        grille[y][x] = ARBRES if alea.random() < 0.45 else (BUISSONS if alea.random() < 0.5 else HERBE)


def friches():
    """Ce qui reste en pelouse nue APRÈS tout le reste : les marges entre deux
    secteurs. On les plante — un parc est un lieu, une pelouse vide est un
    oubli."""
    for y in range(HAUT):
        for x in range(LARGE):
            if grille[y][x] != HERBE:
                continue
            r = alea.random()
            if r < 0.34:
                grille[y][x] = ARBRES
            elif r < 0.58:
                grille[y][x] = BUISSONS


def stade(cx, cy, rx, ry):
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(cx - rx - 2, cx + rx + 3):
            if lire(x, y) == EAU:
                continue
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d < 0.62:
                poser(x, y, HERBE)          # la pelouse
            elif d < 0.95:
                poser(x, y, PAVE)           # la piste
            elif d < 1.30:
                poser(x, y, "C" if (x + y) % 2 == 0 else "c")   # les gradins


def sur_terre(x0, y0, x1, y1, c):
    """⚠ Peindre un rectangle SANS regarder ce qu'il y a dessous repeignait la
    mer : le port et le chantier sortaient en dalles flottantes au large. On ne
    pose que sur ce qui est déjà de la terre."""
    for y in range(max(0, y0), min(HAUT, y1 + 1)):
        for x in range(max(0, x0), min(LARGE, x1 + 1)):
            if grille[y][x] != EAU:
                grille[y][x] = c


def darse(x0, y0, x1, y1):
    """LE PORT. Une darse creusée dans la côte, ses quais en dépôt, et des
    mouillages en FILES FRANCHES : la longueur d'eau libre choisit le bateau, un
    cargo posé dans une tache de trois cases dépassait sur le quai."""
    rect(x0, y0, x1, y1, EAU)
    for y in range(y0 + 1, y1, 3):
        for x in range(x0 + 1, x1 - 1):
            poser(x, y, MOUILLAGE)
    for x in range(x0 - 2, x1 + 3):
        for y in (y0 - 1, y1 + 1):
            if lire(x, y) not in (EAU, MOUILLAGE):
                poser(x, y, DEPOT)


def ouverture():
    """UNE OUVERTURE MORPHOLOGIQUE (érosion puis dilatation) sur le masque de
    terre. Les lobes bruités laissent des filaments d'une case de large — des
    isthmes qu'on ne peut ni traverser ni bâtir, et qui de haut ressemblent à
    un défaut d'affichage. L'ouverture les mange sans toucher au reste de la
    côte : c'est l'outil fait pour ça, et le seuiller autrement (compter les
    voisins) laissait toujours passer les diagonales."""
    def voisins_terre(x, y, r):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if lire(x + dx, y + dy) == EAU:
                    return False
        return True

    erode = [[lire(x, y) != EAU and voisins_terre(x, y, 1) for x in range(LARGE)]
             for y in range(HAUT)]
    garde = [[False] * LARGE for _ in range(HAUT)]
    for y in range(HAUT):
        for x in range(LARGE):
            if not erode[y][x]:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if 0 <= x + dx < LARGE and 0 <= y + dy < HAUT:
                        garde[y + dy][x + dx] = True
    for y in range(HAUT):
        for x in range(LARGE):
            if grille[y][x] != EAU and not garde[y][x]:
                grille[y][x] = EAU


def sans_cailloux(minimum=70):
    """LES ÎLOTS PERDUS AU LARGE. L'union des lobes et le bruit laissent des
    galettes de vingt ou trente cases que rien ne relie : on y bâtirait des
    rues où personne n'ira jamais. Tout morceau plus petit que `minimum`
    retourne à la mer."""
    vus = set()
    for y0 in range(HAUT):
        for x0 in range(LARGE):
            if grille[y0][x0] == EAU or (x0, y0) in vus:
                continue
            pile, bloc = [(x0, y0)], []
            vus.add((x0, y0))
            while pile:
                cx, cy = pile.pop()
                bloc.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (nx, ny) in vus or not (0 <= nx < LARGE and 0 <= ny < HAUT):
                        continue
                    if grille[ny][nx] != EAU:
                        vus.add((nx, ny))
                        pile.append((nx, ny))
            if len(bloc) < minimum:
                for (x, y) in bloc:
                    grille[y][x] = EAU


def litoral_propre():
    """Une case de terre isolée au large est un caillou, pas un quartier ; une
    case d'eau seule au milieu d'un îlot est une flaque."""
    for _ in range(2):
        for y in range(HAUT):
            for x in range(LARGE):
                voisins = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                              if lire(x + dx, y + dy) != EAU)
                if grille[y][x] != EAU and voisins <= 1:
                    grille[y][x] = EAU
                elif grille[y][x] == EAU and voisins == 4:
                    grille[y][x] = HERBE


# ───────────────────────────── l'assemblage ─────────────────────────────

terre_de_base()
chenal(CHENAL_NORD, 7, 0.0, 0, X(150))        # isthme à l'est
chenal(CHENAL_SUD, 8, 2.1, X(62), LARGE - 1)  # isthme à l'ouest
baie(X(24), Y(118), X(22), Y(26))        # la grande anse de l'ouest, celle de la plage
baie(X(206), Y(120), X(20), Y(22))       # l'échancrure de l'est
baie(X(118), Y(208), X(26), Y(14))       # la rade du sud
# ⚠ LES ÎLES APRÈS LES BAIES, jamais avant. Creusées ensuite, deux baies
# passaient exactement sur deux satellites et les rendaient à la mer sans que
# rien ne le signale — c'est le compte des morceaux, en fin d'exécution, qui
# l'a montré : quatre îles demandées, deux dans le dessin.
poser_iles()
ouverture()
litoral_propre()
# ⚠ Le seuil descend à 45 : à 70, les îles satellites — qui font justement
# entre cinquante et cent cases — étaient rendues à la mer par le nettoyage.
sans_cailloux(45)

# LE PARC DU CENTRE et sa place : une ville de tours sans respiration est un
# mur. Posés AVANT la trame, pour que les rues les contournent d'elles-mêmes.
rect(X(92), Y(24), X(120), Y(42), ARBRES)
rect(X(100), Y(30), X(112), Y(36), PAVE)
stade(X(151), Y(108), X(13), Y(11))

# LE BOULEVARD DE CEINTURE D'ABORD : c'est lui qui donne le ton du dessin, et
# la trame orthogonale vient ensuite s'y casser.
ceinture(3)
# ET UN ANNEAU INTÉRIEUR, à neuf cases du bord. Une seule ceinture ne casse la
# trame que sur la première rangée d'îlots ; la deuxième la casse une seconde
# fois, plus loin dans les terres, et donne au passage le boulevard qui double
# le front de mer dans toutes les villes portuaires.
ceinture(9)

for nom, y0, y1, pas_x, pas_y, tous in SECTEURS:
    tramer(y0, y1, pas_x, pas_y)

# ⚠ CE QUI SE COMPTE SUIT LA SURFACE. Sept ronds-points sur une ville deux
# fois plus grande, c'est trois fois moins de ronds-points par kilomètre carré :
# le nombre, lui, doit être multiplié comme l'aire l'est.
AIRE = (LARGE * HAUT) / (REF_LARGE * REF_HAUT)


def part(n):
    return max(1, int(round(n * AIRE)))


# LES PERCÉES EN BIAIS. Trois par secteur, tracées entre deux points tirés sur
# les bords : ce sont elles qui découpent les îlots triangulaires et les
# carrefours à cinq branches qu'une grille ne produit jamais.
diagonale(X(10), Y(8), X(96), Y(70))
diagonale(X(210), Y(10), X(120), Y(74))
diagonale(X(96), Y(42), X(208), Y(20))
diagonale(X(20), Y(150), X(130), Y(84))
diagonale(X(180), Y(146), X(84), Y(82))
diagonale(X(30), Y(160), X(150), Y(212))
diagonale(X(215), Y(158), X(110), Y(210))
diagonale(X(60), Y(212), X(190), Y(168))
diagonale(X(4), Y(60), X(120), Y(12))
diagonale(X(140), Y(6), X(220), Y(58))
diagonale(X(46), Y(88), X(176), Y(140))
diagonale(X(200), Y(92), X(70), Y(142))
diagonale(X(96), Y(156), X(218), Y(196))
diagonale(X(8), Y(190), X(116), Y(156))

ebarber()

# LES IMPASSES APRÈS L'ÉBARBAGE, sinon il les mange.
culs = impasses(CHENAL_NORD + 1, CHENAL_SUD, part(70))
culs += impasses(CHENAL_SUD + 1, HAUT - 1, part(25))
culs += impasses(0, CHENAL_NORD, part(20))

ronds = 0
ronds += poser_ronds(0, CHENAL_NORD, 7, 5, 3, part(7))
ronds += poser_ronds(CHENAL_NORD + 1, CHENAL_SUD, 9, 7, 3, part(5))
ronds += poser_ronds(CHENAL_SUD + 1, HAUT - 1, 13, 9, 2, part(4))

# Les îlots, secteur par secteur : chacun sa palette, sa part de vert et de
# pavé. Le centre est dense et minéral, le résidentiel vert, l'industrie plate
# et pleine de parkings.
PALETTES = {
    "centre": (["T", "T", "B", "B", "B", "C"], 0.08, 0.07),
    "residentiel": (["M", "M", "M", "V", "V", "C"], 0.12, 0.06),
    "industrie": (["H", "H", "H", "C", "M"], 0.06, 0.24),
}
for nom, y0, y1, pas_x, pas_y, tous in SECTEURS:
    palette, vert, pave = PALETTES[nom]
    for bloc in ilots(y0, y1):
        batir_ilot(bloc, palette, vert, pave)

# LES ÎLES SATELLITES ONT LEUR CARACTÈRE. Villégiature : des maisons et
# beaucoup d'arbres. Nature : rien qu'un bois et une plage — une île où il n'y
# a RIEN est une destination, pas un oubli.
for cx, cy, rx, ry, quoi in ILES:
    for y in range(cy - ry - 4, cy + ry + 5):
        for x in range(cx - rx - 4, cx + rx + 5):
            if lire(x, y) != HERBE:
                continue
            if quoi == "nature":
                poser(x, y, ARBRES if alea.random() < 0.55 else
                      (BUISSONS if alea.random() < 0.5 else HERBE))
            elif quoi == "villegiature" and alea.random() < 0.34:
                poser(x, y, "M" if (x + y) % 2 == 0 else "m")
            elif quoi == "industrie" and alea.random() < 0.30:
                poser(x, y, DEPOT if alea.random() < 0.5 else "H")

# LE PORT et ses dépôts, APRÈS les îlots : ils écrasent ce qu'il y avait.
darse(X(182), Y(162), X(206), Y(190))
sur_terre(X(168), Y(194), X(200), Y(204), DEPOT)
sur_terre(X(134), Y(198), X(158), Y(208), CHANTIER)

facades_de_mer()
friches()

# LES PONTS EN DERNIER : la trame est figée, on sait où sont les avenues.
ponts = 0
ponts += ponter(CHENAL_NORD, 7, 0.0, avenues_x(7, 3)[1::2])
ponts += ponter(CHENAL_SUD, 8, 2.1, avenues_x(9, 3)[::2])

ebarber()
sans_ponts = ponts_propres()
if sans_ponts:
    print("ponts effacés (n'atteignaient pas deux rives) : %d" % sans_ponts)
ebarber()

# ───────────────────────────── LE RELIEF ─────────────────────────────
#
# ⚠ LE RELIEF EST LA SEULE CHOSE DE CETTE CARTE QU'ON NE PEUT PAS DESSINER
# LIBREMENT. `Quartiers.fautes` en refuse trois formes, et elles ne sont pas
# décoratives : elles disent ce que le kit de route sait bâtir.
#
#   1. UNE MARCHE AU PIED D'UN CARREFOUR. Le kit n'a pas de carrefour en pente.
#      Une dénivellation ne passe qu'entre deux cases de chaussée DROITES et
#      DANS LE SENS de la rue — dès qu'une case a un embranchement
#      perpendiculaire, elle doit être de niveau avec ses voisines.
#   2. UNE MARCHE DE PLUS DE DEUX PALIERS. `road-slant-high` monte de deux
#      crans d'un coup, pas plus.
#   3. UN BÂTIMENT À CHEVAL sur deux paliers.
#
# On ne peut donc pas poser un champ de hauteur et espérer : il faut le
# CONTRAINDRE. La méthode tient en quatre temps.
#
#   A. Un champ de hauteur libre : la mer à zéro, ça monte en s'en éloignant,
#      plus quelques collines. C'est le paysage voulu.
#   B. On SOUDE entre elles toutes les cases de chaussée qui n'ont pas le droit
#      d'être à des paliers différents (union-find) : un carrefour et ses
#      quatre approches, les neuf cases d'un rond-point, une file de pont.
#      Chaque groupe prend la moyenne du champ.
#   C. On RELÂCHE : tant que deux groupes voisins diffèrent de plus de deux, on
#      abaisse le plus haut. Quelques passes suffisent, et ça converge parce
#      qu'on ne fait que descendre.
#   D. CHAQUE ÎLOT PREND UN SEUL PALIER — la médiane des rues qui le bordent.
#      C'est ce qui règle la troisième faute, et c'est aussi ce qui fait qu'un
#      pâté est de plain-pied avec sa rue au lieu de flotter au-dessus.
#
# Résultat mesuré : zéro faute sur 96 000 cases, avec cinq paliers d'écart entre
# le port et la vieille ville.

PALIER_MAX = 5

# centre x, centre y, rayon x, rayon y, hauteur au sommet (en paliers)
COLLINES = [(X(a), Y(b), X(c), Y(d), h) for a, b, c, d, h in [
    (56, 34, 42, 28, 4.4),     # la butte du nord-ouest, qui domine le centre
    (170, 42, 36, 24, 3.6),    # la crête du nord-est
    (58, 118, 32, 28, 5.0),    # la colline de la vieille ville — le point haut
    (152, 122, 28, 22, 3.0),   # le mamelon derrière le stade
    (108, 178, 46, 22, 2.0),   # le plateau industriel, à peine bombé
]]


def hauteurs_brutes(d_mer):
    """Le paysage VOULU, avant toute contrainte. Le rivage est à zéro et ça
    monte en s'en éloignant : c'est ce qui met le port en bas et la vieille
    ville en haut sans qu'on ait à le dessiner. Les collines sont multipliées
    par cette même rampe côtière — sinon une colline dont le lobe touche la mer
    dresse une falaise de cinq paliers au bord de l'eau."""
    h = [[0.0] * LARGE for _ in range(HAUT)]
    for y in range(HAUT):
        for x in range(LARGE):
            if grille[y][x] in ".~":
                continue
            rampe = min(1.0, d_mer[y][x] / 10.0)
            v = min(2.2, d_mer[y][x] / 13.0)
            for cx, cy, rx, ry, amp in COLLINES:
                t = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if t < 1.0:
                    v = max(v, amp * (1.0 - t) ** 0.65 * rampe)
            v += 0.45 * (bruit(x * 0.7, y * 0.7) + 1.0)
            h[y][x] = v
    return h


def relief_contraint():
    d_mer = distances_a_la_mer()
    champ = hauteurs_brutes(d_mer)
    route = [[grille[y][x] in "#=O" for x in range(LARGE)] for y in range(HAUT)]

    def est_route(x, y):
        return 0 <= x < LARGE and 0 <= y < HAUT and route[y][x]

    # « Droite selon X » = aucune chaussée au nord ni au sud : c'est exactement
    # le test `(m & 5) == 0` de `Quartiers.fautes`, écrit dans l'autre sens.
    def droit_x(x, y):
        return not est_route(x, y - 1) and not est_route(x, y + 1)

    def droit_z(x, y):
        return not est_route(x - 1, y) and not est_route(x + 1, y)

    parent = {}

    def trouver(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def unir(a, b):
        ra, rb = trouver(a), trouver(b)
        if ra != rb:
            parent[ra] = rb

    cases = [(x, y) for y in range(HAUT) for x in range(LARGE) if route[y][x]]
    for c in cases:
        parent[c] = c

    # B — LA SOUDURE. On n'autorise la marche que si les DEUX cases sont droites
    # dans le sens de la marche. Le banc, lui, ne l'exige que de la plus basse ;
    # être plus strict que la règle coûte quelques marches et garantit qu'on ne
    # dépend pas de qui se retrouvera en dessous après la relaxation.
    for (x, y) in cases:
        if est_route(x + 1, y) and not (droit_x(x, y) and droit_x(x + 1, y)):
            unir((x, y), (x + 1, y))
        if est_route(x, y + 1) and not (droit_z(x, y) and droit_z(x, y + 1)):
            unir((x, y), (x, y + 1))
    # Un rond-point mange 3 × 3 cases AU MÊME PALIER : les neuf sont soudées.
    for (x, y) in cases:
        if grille[y][x] != ROND:
            continue
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if est_route(x + dx, y + dy):
                    unir((x, y), (x + dx, y + dy))
    # Un pont ne monte pas : toute la file et ses deux têtes au même palier.
    for (x, y) in cases:
        if grille[y][x] != PONT:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if est_route(x + dx, y + dy):
                unir((x, y), (x + dx, y + dy))

    somme, nb = {}, {}
    for (x, y) in cases:
        r = trouver((x, y))
        somme[r] = somme.get(r, 0.0) + champ[y][x]
        nb[r] = nb.get(r, 0) + 1
    niveau = {r: max(0, min(PALIER_MAX, int(round(somme[r] / nb[r])))) for r in somme}

    # C — LA RELAXATION. Deux groupes voisins ne peuvent différer de plus de
    # deux paliers. On n'abaisse jamais que le plus haut : la suite est
    # décroissante, donc elle converge, et en cinq passes au plus.
    aretes = set()
    for (x, y) in cases:
        for dx, dy in ((1, 0), (0, 1)):
            if est_route(x + dx, y + dy):
                a, b = trouver((x, y)), trouver((x + dx, y + dy))
                if a != b:
                    aretes.add((a, b))
    aretes = list(aretes)
    passes = 0
    while passes < 3 * PALIER_MAX + 6:
        passes += 1
        change = False
        for a, b in aretes:
            if niveau[a] > niveau[b] + 2:
                niveau[a] = niveau[b] + 2
                change = True
            elif niveau[b] > niveau[a] + 2:
                niveau[b] = niveau[a] + 2
                change = True
        if not change:
            break

    relief = [[0] * LARGE for _ in range(HAUT)]
    for (x, y) in cases:
        relief[y][x] = niveau[trouver((x, y))]

    # D — UN ÎLOT, UN PALIER : la médiane des rues qui le bordent. La moyenne
    # ferait tomber un îlot entre deux niveaux de rue et le mettrait en
    # surplomb des deux côtés ; la médiane le pose au niveau de sa rue
    # principale, et le talus part de l'autre bord.
    vus = [[False] * LARGE for _ in range(HAUT)]
    plats = 0
    for y0 in range(HAUT):
        for x0 in range(LARGE):
            if vus[y0][x0] or grille[y0][x0] in ".~" or route[y0][x0]:
                continue
            pile, bloc, bords = [(x0, y0)], [], []
            vus[y0][x0] = True
            while pile:
                x, y = pile.pop()
                bloc.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < LARGE and 0 <= ny < HAUT):
                        continue
                    if route[ny][nx]:
                        bords.append(relief[ny][nx])
                        continue
                    if vus[ny][nx] or grille[ny][nx] in ".~":
                        continue
                    vus[ny][nx] = True
                    pile.append((nx, ny))
            if bords:
                bords.sort()
                n = bords[len(bords) // 2]
            else:
                n = int(round(sum(champ[y][x] for x, y in bloc) / len(bloc)))
            n = max(0, min(PALIER_MAX, n))
            for x, y in bloc:
                relief[y][x] = n
            plats += 1
    return relief, plats


# ───────────────────────────── la sortie ─────────────────────────────

plan = ["".join(l) for l in grille]
_relief, _ilots_plats = relief_contraint()
relief = ["".join(str(n) for n in ligne) for ligne in _relief]
_hauts = {}
for _l in relief:
    for _c in _l:
        _hauts[_c] = _hauts.get(_c, 0) + 1
print("relief : %d îlots aplanis, paliers %s"
      % (_ilots_plats, " ".join("%s=%d" % kv for kv in sorted(_hauts.items()))))

cases = sum(1 for l in plan for c in l if c != EAU)
compte = {}
for l in plan:
    for c in l:
        compte[c] = compte.get(c, 0) + 1

# ⚠ LA SORTIE EST DU GDSCRIPT, PAS UN FICHIER DE DONNÉES. Sur ce projet le
# DESSIN EST LE FICHIER : on le relit dans un diff, on y déplace une rue à la
# main, et l'éditeur en jeu ressort exactement le même bloc. Un .txt chargé au
# vol aurait fait une deuxième vérité — celle qu'on dessine et celle que le jeu
# lit — et c'est précisément ce que ce projet a refusé partout ailleurs.
sortie = Path(__file__).resolve().parent.parent / "jeux/carnage/pikstown.gd"
sortie.parent.mkdir(parents=True, exist_ok=True)
with sortie.open("w", encoding="utf-8") as f:
    f.write('class_name PlanPikstown\n')
    f.write('extends RefCounted\n')
    f.write('## LE DESSIN DE PIKSTOWN — %d x %d cases, soit 2,25 km sur 2,15 km.\n' % (LARGE, HAUT))
    f.write('##\n')
    f.write('## Un caractère par case, le même vocabulaire que partout ailleurs\n')
    f.write('## (`Quartiers`, en tête de fichier). Posé une première fois par\n')
    f.write('## `outils/pikstown.py` — 48 375 caractères ne s\'écrivent pas à la main —\n')
    f.write('## puis RETOUCHÉ ICI, à la main ou dans l\'éditeur (`?ecran=editeur`).\n')
    f.write('## Relancer le générateur ÉCRASE les retouches : il sert à repartir de\n')
    f.write('## zéro, pas à régénérer une ville qu\'on a corrigée.\n')
    f.write('##\n')
    f.write('## TOUT EST AU PALIER 0 : une seule trame, un seul plan, aucun quartier\n')
    f.write('## incliné. Le relief est gardé comme grille pour que le format reste\n')
    f.write('## celui de tous les autres quartiers, et qu\'on puisse creuser une\n')
    f.write('## terrasse plus tard sans changer une ligne de code.\n')
    f.write('\n')
    f.write('const LARGE := %d\n' % LARGE)
    f.write('const HAUT := %d\n\n' % HAUT)
    f.write('const PLAN: Array[String] = [\n')
    for l in plan:
        f.write('\t"%s",\n' % l)
    f.write(']\n\n')
    f.write('const RELIEF: Array[String] = [\n')
    for l in relief:
        f.write('\t"%s",\n' % l)
    f.write(']\n')

# ⚠ L'ÎLE PRINCIPALE DOIT RESTER D'UN SEUL TENANT, et l'archipel doit rester un
# archipel : on mesure les deux. La plus grosse composante, c'est la ville ; les
# suivantes, ce sont les îles. Une ville coupée en deux ne se voit pas dans le
# fichier — elle se compte.
def morceaux():
    vus = set()
    tailles = []
    for y0 in range(HAUT):
        for x0 in range(LARGE):
            if grille[y0][x0] == EAU or (x0, y0) in vus:
                continue
            pile, n = [(x0, y0)], 0
            vus.add((x0, y0))
            while pile:
                cx, cy = pile.pop()
                n += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (nx, ny) in vus or not (0 <= nx < LARGE and 0 <= ny < HAUT):
                        continue
                    if grille[ny][nx] != EAU:
                        vus.add((nx, ny))
                        pile.append((nx, ny))
            tailles.append(n)
    return sorted(tailles, reverse=True)


parts = morceaux()
principale = 100.0 * parts[0] / max(1, sum(parts))
print("ville d'un seul tenant : %.1f %% ; %d morceaux au total (%s)"
      % (principale, len(parts), " ".join(str(p) for p in parts[:8])))
if principale < 75.0:
    print("⚠ LA VILLE EST COUPÉE. Élargir le recouvrement des LOBES ou raccourcir un chenal.")

print("pikstown : %d x %d, %d cases de terre (%.0f%%), %d ronds-points, %d ponts, %d impasses"
      % (LARGE, HAUT, cases, 100.0 * cases / (LARGE * HAUT), ronds, ponts, culs))
print("   ", " ".join("%s=%d" % (k, v) for k, v in sorted(compte.items(), key=lambda kv: -kv[1])))
print("   ->", sortie)
