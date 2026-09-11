#!/usr/bin/env python3
"""LA REFONTE DE PIKSTOWN — le tracé de la ville, repris à zéro.

Trois défauts, mesurés et non supposés, sur le dessin précédent :

  * **34 % des blocs de bâtiment n'avaient AUCUN accès à la rue** — 5 243 blocs,
    8 756 cases. Des maisons et des immeubles sans porte sur rue : c'est le
    défaut que le client a vu, et c'est le plus grave, parce qu'en jeu on ne
    peut ni les atteindre ni y entrer.
  * **La médiane d'un pâté valait UNE case.** La ville n'était pas faite de
    pâtés mais de quinze mille bâtiments semés un par un. Vu d'avion, du bruit.
  * **Quinze mille fragments de rue** pour aucune hiérarchie : toutes les rues
    de la même largeur, aucune artère, aucun ordre. « Tu n'arrives absolument
    pas à gérer les suites de route et leur ordre. »

La refonte inverse l'ordre de fabrication. AVANT : on semait des bâtiments,
puis on faisait passer des rues entre eux. MAINTENANT : on trace d'abord le
réseau — rocade, avenues, rues, dessertes — puis on ne bâtit QUE sur les cases
qui touchent une rue. L'accès n'est plus une propriété qu'on espère : c'est la
définition même d'une case bâtie.

    python3 outils/refonte.py [--essai] [--graine=N]
"""
import math, random, re, sys
from collections import deque

FICHIER = "jeux/carnage/pikstown.gd"
W, H = 320, 300
COTES = ((0, -1), (1, 0), (0, 1), (-1, 0))
MER = "."
ROUTE = "#"
VOIRIE = "#=O(/"
## Les lettres qui sont VRAIMENT un bâtiment. `o` (esplanade), `P` (parking),
## `X` (dépôt) sont des lettres pour Python mais du sol pour le jeu : les
## compter comme des bâtiments faisait dire à l'audit qu'un tiers de la ville
## était sans accès alors qu'il s'agissait de places et de parkings.
BATI = set("TBCMVHtbcmvh+FS$?*EK")


# ════════════════════════════════════════════════════════════ 1. LES ÎLES

## ⚠ UNE CÔTE DESSINÉE, PAS UN BRUIT. L'ancienne carte tirait ses rivages d'un
## bruit de Perlin seuillé : vu d'avion, trois taches déchiquetées. Une île se
## compose ici d'un petit nombre de galets (ellipses) dont on prend la réunion,
## puis on passe un filtre de majorité qui mange les dentelles et referme les
## criques d'une case. Le résultat a des caps et des baies parce qu'on les a
## posés, pas parce que le hasard en a laissé.
ILES = [
    # (nom, district, [(cx, cy, rx, ry), ...])
    ("nord", "centre", [
        (108, 62, 78, 40), (196, 58, 66, 38), (150, 40, 52, 26),
        (238, 84, 40, 30), (70, 78, 34, 24),
    ]),
    ("centre", "residentiel", [
        (140, 172, 80, 36), (208, 166, 48, 30), (92, 188, 42, 26),
        (172, 194, 52, 20),
    ]),
    ("sud", "industriel", [
        (150, 262, 94, 32), (248, 256, 50, 26), (74, 254, 38, 22),
        (196, 276, 60, 20),
    ]),
    ("ilot-ouest", "residentiel", [(38, 148, 20, 16)]),
    ("ilot-est", "residentiel", [(286, 158, 22, 17)]),
    ("ilot-nord", "centre", [(286, 30, 18, 14)]),
]


def grille(v=MER):
    return [[v] * W for _ in range(H)]


def poser_iles():
    terre = grille(False)
    quartier = grille(None)
    for nom, district, galets in ILES:
        for (cx, cy, rx, ry) in galets:
            for j in range(max(0, cy - ry - 1), min(H, cy + ry + 2)):
                for i in range(max(0, cx - rx - 1), min(W, cx + rx + 2)):
                    dx = (i - cx) / float(rx)
                    dy = (j - cy) / float(ry)
                    if dx * dx + dy * dy <= 1.0:
                        terre[j][i] = True
                        quartier[j][i] = (nom, district)
    # Le filtre de majorité : deux passes suffisent à rendre une côte lisible.
    for _ in range(2):
        neuf = [l[:] for l in terre]
        for j in range(1, H - 1):
            for i in range(1, W - 1):
                n = sum(1 for a in (-1, 0, 1) for b in (-1, 0, 1)
                        if (a or b) and terre[j + b][i + a])
                if n >= 6:
                    neuf[j][i] = True
                elif n <= 2:
                    neuf[j][i] = False
        terre = neuf
    # ⚠ TROIS CASES DE MARGE. Une case de terre collée au bord du dessin n'a
    # pas de voisine : la falaise y sort à vif et la rue s'y arrête en impasse.
    for j in range(H):
        for i in range(W):
            if i < 3 or j < 3 or i >= W - 3 or j >= H - 3:
                terre[j][i] = False
    # Chaque case de terre garde son district ; celles que le lissage a créées
    # prennent celui de la voisine la plus proche.
    for _ in range(3):
        for j in range(1, H - 1):
            for i in range(1, W - 1):
                if terre[j][i] and quartier[j][i] is None:
                    for d in COTES:
                        q = quartier[j + d[1]][i + d[0]]
                        if q:
                            quartier[j][i] = q
                            break
    return terre, quartier


def morceaux_de_terre(terre):
    """Les composantes connexes de la terre, de la plus grande à la plus petite."""
    vu = grille(False)
    out = []
    for j in range(H):
        for i in range(W):
            if not terre[j][i] or vu[j][i]:
                continue
            q = deque([(i, j)])
            vu[j][i] = True
            cells = []
            while q:
                x, y = q.popleft()
                cells.append((x, y))
                for d in COTES:
                    a, b = x + d[0], y + d[1]
                    if 0 <= a < W and 0 <= b < H and terre[b][a] and not vu[b][a]:
                        vu[b][a] = True
                        q.append((a, b))
            out.append(cells)
    out.sort(key=len, reverse=True)
    return out


# ═══════════════════════════════════════════════════════ 2. LE SQUELETTE

## ⚠ L'ORDRE DES ROUTES, C'EST UNE HIÉRARCHIE, PAS UN DAMIER. Le dessin
## précédent n'avait qu'un seul rang de rue, répété quinze mille fois. Ici il y
## en a quatre, et chacun a un rôle :
##
##   1. LA CORNICHE — un boulevard qui suit la côte à distance constante. Il
##      est COURBE parce que la côte l'est : c'est lui qui casse le damier, et
##      il donne à chaque île un tour complet qu'on peut faire en voiture.
##   2. LES AVENUES — trois à cinq longues droites qui traversent l'île de part
##      en part et viennent mourir sur la corniche.
##   3. LES RUES — entre les avenues, à pas IRRÉGULIER, et qui SE DÉCALENT en
##      franchissant une avenue : deux rues parallèles ne sont jamais dans le
##      même alignement sur toute la longueur.
##   4. LES DESSERTES — des impasses courtes qui entrent dans les gros pâtés.
##      Elles existent pour une seule raison : donner une façade sur rue au
##      coeur d'îlot, qui sans elles serait bâti sans accès.

def distance_a_la_mer(terre):
    """Combien de cases séparent chaque case de terre de la mer la plus proche."""
    d = [[-1] * W for _ in range(H)]
    q = deque()
    for j in range(H):
        for i in range(W):
            if not terre[j][i]:
                d[j][i] = 0
                q.append((i, j))
    while q:
        x, y = q.popleft()
        for dd in COTES:
            a, b = x + dd[0], y + dd[1]
            if 0 <= a < W and 0 <= b < H and d[b][a] < 0:
                d[b][a] = d[y][x] + 1
                q.append((a, b))
    return d


def corniche(plan, terre, dist, ile, k):
    """Le boulevard de ceinture : toutes les cases à exactement `k` de la mer.

    ⚠ ON AMINCIT. La courbe de niveau `dist == k` fait par endroits deux ou
    trois cases de large — là où la côte tourne serré. Posée telle quelle, elle
    donne une nappe de bitume au lieu d'un boulevard. On ne garde donc une case
    que si l'enlever couperait le tour.
    """
    dedans = set(ile)
    anneau = [c for c in ile if dist[c[1]][c[0]] == k]
    if len(anneau) < 40:
        return []
    pose = set(anneau)

    def voisins(s, c):
        return [(c[0] + d[0], c[1] + d[1]) for d in COTES
                if (c[0] + d[0], c[1] + d[1]) in s]

    # On enlève les cases superflues en balayant plusieurs fois : une case s'en
    # va si ses voisines restent reliées entre elles sans elle.
    change = True
    while change:
        change = False
        for c in sorted(pose, key=lambda p: (p[0] * 7919 + p[1] * 104729) % 1013):
            v = voisins(pose, c)
            if len(v) < 2:
                continue
            reste = pose - {c}
            vu = {v[0]}
            f = deque([v[0]])
            while f:
                x = f.popleft()
                for y in voisins(reste, x):
                    if y not in vu:
                        vu.add(y)
                        f.append(y)
            if all(w in vu for w in v[1:]):
                pose = reste
                change = True
    for (i, j) in pose:
        plan[j][i] = ROUTE
    return sorted(pose)


def trace_droite(plan, terre, i0, j0, i1, j1):
    """Une avenue droite, posée uniquement sur la terre."""
    poses = []
    if i0 == i1:
        for j in range(min(j0, j1), max(j0, j1) + 1):
            if terre[j][i0]:
                plan[j][i0] = ROUTE
                poses.append((i0, j))
    else:
        for i in range(min(i0, i1), max(i0, i1) + 1):
            if terre[j0][i]:
                plan[j0][i] = ROUTE
                poses.append((i, j0))
    return poses


def avenues(plan, terre, ile, alea, pas_min, pas_max):
    """Les longues droites, à pas irrégulier, dans les deux sens."""
    xs = [c[0] for c in ile]
    ys = [c[1] for c in ile]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    lignes = []
    j = y0 + alea.randint(pas_min // 2, pas_min)
    while j < y1:
        lignes.append(("h", j))
        j += alea.randint(pas_min, pas_max)
    i = x0 + alea.randint(pas_min // 2, pas_min)
    while i < x1:
        lignes.append(("v", i))
        i += alea.randint(pas_min, pas_max)
    dedans = set(ile)
    for sens, n in lignes:
        if sens == "h":
            for i2 in range(x0, x1 + 1):
                if (i2, n) in dedans:
                    plan[n][i2] = ROUTE
        else:
            for j2 in range(y0, y1 + 1):
                if (n, j2) in dedans:
                    plan[j2][n] = ROUTE
    return lignes


## ⚠ LA DIAGONALE EST CE QUI TUE LE DAMIER. Un décalage de rue casse
## l'alignement, mais la trame reste orthogonale et le regard la retrouve.
## Une avenue qui traverse l'île EN BIAIS, elle, découpe les pâtés en
## triangles et en trapèzes : c'est la percée haussmannienne, et c'est le seul
## trait qui change vraiment la lecture d'une ville. On n'a que quatre
## directions, donc elle se trace EN ESCALIER — deux à cinq cases dans un
## sens, deux à cinq dans l'autre — et le kit la rend en enfilade de virages.
def diagonale(plan, terre, ile, alea, depart, sens, longueur):
    dedans = set(ile)
    i, j = depart
    dx, dy = sens
    poses = 0
    pas_h = True
    while poses < longueur:
        n = alea.randint(2, 5)
        for _ in range(n):
            if (i, j) not in dedans:
                return poses
            plan[j][i] = ROUTE
            poses += 1
            if pas_h:
                i += dx
            else:
                j += dy
        pas_h = not pas_h
    return poses


def rues(plan, terre, ile, lignes, alea, pas_min, pas_max, decalage):
    """Les rues ordinaires entre les avenues — à pas irrégulier ET DÉCALÉES.

    ⚠ C'EST ICI QUE SE JOUE « TROP CARRÉ ». Une rue tracée d'un bord à l'autre
    de l'île donne un damier, quelle que soit la finesse du pas. On trace donc
    chaque rue PAR TRONÇONS — d'une avenue à la suivante — et on la décale
    latéralement de une à trois cases à chaque franchissement. Deux rues
    parallèles ne restent jamais alignées sur toute la longueur, et le regard
    n'y lit plus un quadrillage mais un tissu.
    """
    dedans = set(ile)
    xs = [c[0] for c in ile]
    ys = [c[1] for c in ile]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    av_h = sorted([n for s, n in lignes if s == "h"])
    av_v = sorted([n for s, n in lignes if s == "v"])
    bornes_h = [y0] + av_h + [y1]
    bornes_v = [x0] + av_v + [x1]

    def poser(i, j):
        if (i, j) in dedans:
            plan[j][i] = ROUTE

    # ⚠ LES MARGES AUSSI. Les rues n'étaient tracées qu'ENTRE deux avenues :
    # la bande comprise entre le rivage et la première avenue n'en recevait
    # aucune, et sortait en grand carré de pelouse au bord de la ville. On
    # borne donc avec les limites de l'île, pas avec les seules avenues.
    for a, b in zip(bornes_h, bornes_h[1:]):
        j = a + alea.randint(pas_min, pas_max)
        while j < b - pas_min // 2:
            n = j
            for u, v in zip(bornes_v, bornes_v[1:]):
                for i in range(u, v + 1):
                    poser(i, n)
                m = max(a + 2, min(b - 2, n + alea.randint(-decalage, decalage)))
                if m != n:
                    for k in range(min(n, m), max(n, m) + 1):
                        poser(v, k)
                    n = m
            j += alea.randint(pas_min, pas_max)
    # les rues verticales, même principe
    for a, b in zip(bornes_v, bornes_v[1:]):
        i = a + alea.randint(pas_min, pas_max)
        while i < b - pas_min // 2:
            n = i
            for u, v in zip(bornes_h, bornes_h[1:]):
                for j in range(u, v + 1):
                    poser(n, j)
                m = max(a + 2, min(b - 2, n + alea.randint(-decalage, decalage)))
                if m != n:
                    for k in range(min(n, m), max(n, m) + 1):
                        poser(k, v)
                    n = m
            i += alea.randint(pas_min, pas_max)


# ════════════════════════════════════════════════════════ 3. LA CONNEXITÉ

## ⚠ « FAIT EN SORTE QUE TOUTES LES ROUTES SOIENT BRANCHÉES ET COHÉRENTES. »
## Une rue qui ne mène nulle part n'est pas une rue. Deux passes :
##   1. on RACCROCHE : tout morceau de voirie détaché du grand réseau est relié
##      par le chemin de terre le plus court, ou effacé s'il est minuscule ;
##   2. on ÉBARBE : tout bout de rue d'une seule case qui ne dessert rien —
##      ni pâté, ni raquette — disparaît.

def composantes(plan, quoi=ROUTE):
    """Les morceaux d'un même caractère — ou d'un même JEU de caractères."""
    vu = grille(False)
    out = []
    for j in range(H):
        for i in range(W):
            if plan[j][i] not in quoi or vu[j][i]:
                continue
            q = deque([(i, j)])
            vu[j][i] = True
            cells = []
            while q:
                x, y = q.popleft()
                cells.append((x, y))
                for d in COTES:
                    a, b = x + d[0], y + d[1]
                    if 0 <= a < W and 0 <= b < H and plan[b][a] in quoi and not vu[b][a]:
                        vu[b][a] = True
                        q.append((a, b))
            out.append(cells)
    out.sort(key=len, reverse=True)
    return out


def raccrocher(plan, terre, ile, mini=6):
    """Un seul réseau par île : on relie ou on efface, jamais on ne laisse."""
    dedans = set(ile)
    efface = relie = 0
    while True:
        comps = [c for c in composantes(plan) if set(c) & dedans]
        if len(comps) <= 1:
            break
        grand = set(comps[0])
        bouge = False
        for c in comps[1:]:
            if len(c) < mini:
                for (i, j) in c:
                    plan[j][i] = ","
                efface += 1
                bouge = True
                continue
            # le chemin de terre le plus court entre ce morceau et le réseau
            vu = {p: None for p in c}
            q = deque(c)
            but = None
            while q and but is None:
                x, y = q.popleft()
                for d in COTES:
                    a, b = x + d[0], y + d[1]
                    if (a, b) in vu or not (0 <= a < W and 0 <= b < H):
                        continue
                    if not terre[b][a]:
                        continue
                    vu[(a, b)] = (x, y)
                    if (a, b) in grand:
                        but = (a, b)
                        break
                    q.append((a, b))
            if but is None:
                for (i, j) in c:
                    plan[j][i] = ","
                efface += 1
            else:
                p = but
                while p is not None:
                    plan[p[1]][p[0]] = ROUTE
                    p = vu[p]
                relie += 1
            bouge = True
            break
        if not bouge:
            break
    return relie, efface


def ebarber(plan, terre, tours=25):
    """Les bouts de rue qui ne desservent rien s'en vont."""
    otes = 0
    for _ in range(tours):
        a_oter = []
        for j in range(H):
            for i in range(W):
                if plan[j][i] != ROUTE:
                    continue
                v = [d for d in COTES if plan[j + d[1]][i + d[0]] == ROUTE]
                if len(v) == 1:
                    a_oter.append((i, j))
        if not a_oter:
            break
        for (i, j) in a_oter:
            plan[j][i] = ","
            otes += 1
    return otes


# ═══════════════════════════════════════════════ 4. LES PÂTÉS ET LES FAÇADES

## ⚠ L'INVERSION QUI RÈGLE TOUT. L'ancien dessin semait des bâtiments puis
## faisait passer des rues entre eux : un tiers n'avait aucune porte sur rue.
## Ici, on part du pâté — le morceau de terre enfermé par les rues — et on
## calcule pour chaque case sa PROFONDEUR, c'est-à-dire sa distance à la rue.
##
##   profondeur 1, 2 (3 en centre-ville)  →  la FAÇADE : on y bâtit
##   profondeur supérieure                →  le COEUR D'ÎLOT : cour, parking,
##                                            arbres — jamais un bâtiment
##
## Un bâtiment est donc, par construction, un rectangle qui contient au moins
## une case de profondeur 1 : il a toujours une façade sur rue. Le compte de
## bâtiments sans accès ne peut plus être que zéro, et l'audit le vérifie.
##
## ⚠ ET SI LE COEUR EST TROP GROS, ON Y ENTRE. Un pâté profond de huit cases a
## un coeur que personne n'atteint : c'est du terrain perdu. On y pousse une
## DESSERTE — une impasse d'une case de large qui va chercher le fond — et la
## façade se recalcule autour. C'est ce qui donne les raquettes de
## retournement, et accessoirement ce qui casse encore un peu le damier.

PROFOND = {"centre": 3, "residentiel": 2, "industriel": 3}
TAILLE_BATI = {"centre": (2, 5), "residentiel": (1, 3), "industriel": (3, 7)}

## ⚠ UNE VILLE A UNE SILHOUETTE, PAS UNE MOYENNE. Tirée au hasard dans la même
## liste d'un bout à l'autre du district, la hauteur sortait uniforme : des
## tours semées au milieu des pavillons, et vu de loin un tapis de la même
## épaisseur partout. Une ville a un CENTRE ; on s'en éloigne et ça descend.
##
## La lettre se choisit donc à la DISTANCE DU COEUR du district — le coeur
## étant posé à la main, comme les îles. Près : les tours. Loin : les maisons.
## Et un peu de désordre, sinon on lit un cône au lieu d'une ville.
##
##   distance au coeur (cases)   centre        résidentiel     industriel
##   moins de 26                 T T T B       C C V M         H H B C
##   26 à 55                     T B B C       M V C M         H H C M
##   55 à 90                     B C C M       M M V C         H C M M
##   au-delà                     C M V M       M M M V         H M V M
COEURS_DISTRICT = {
    "centre": [(150, 52), (232, 78)],
    "residentiel": [(150, 172)],
    "industriel": [(140, 262), (248, 258)],
}
LETTRES = {
    "centre":      ["TTTB", "TBBC", "BCCM", "CMVM"],
    "residentiel": ["CCVM", "MVCM", "MMVC", "MMMV"],
    "industriel":  ["HHBC", "HHCM", "HCMM", "HMVM"],
}
PALIERS_VILLE = (26, 55, 90)


def rang_urbain(district, i, j, alea):
    """À quelle distance du coeur du district — donc à quelle hauteur ?"""
    coeurs = COEURS_DISTRICT.get(district, [(W // 2, H // 2)])
    d = min(abs(i - c[0]) + abs(j - c[1]) * 1.35 for c in coeurs)
    # Le désordre : sans lui, la silhouette est un cône parfait. Trois cases
    # de flou suffisent à ce qu'une tour dépasse de temps en temps.
    d += alea.uniform(-16.0, 16.0)
    for k, seuil in enumerate(PALIERS_VILLE):
        if d < seuil:
            return k
    return 3


def profondeurs(plan, cells):
    """La distance à la rue, mesurée DANS le pâté."""
    dedans = set(cells)
    d = {}
    q = deque()
    for (i, j) in cells:
        if any(plan[j + e[1]][i + e[0]] == ROUTE for e in COTES):
            d[(i, j)] = 1
            q.append((i, j))
    while q:
        x, y = q.popleft()
        for e in COTES:
            p = (x + e[0], y + e[1])
            if p in dedans and p not in d:
                d[p] = d[(x, y)] + 1
                q.append(p)
    for c in cells:
        d.setdefault(c, 99)
    return d


def desservir(plan, terre, cells, prof, seuil=4):
    """Pousse une impasse dans le coeur d'un pâté trop profond."""
    dedans = set(cells)
    fond = [c for c in cells if prof[c] >= seuil]
    if not fond:
        return False
    cible = max(fond, key=lambda c: (prof[c], c[0] * 31 + c[1]))
    # on redescend la pente des profondeurs jusqu'à la rue : c'est le chemin
    # le plus court, et il est forcément d'une case de large.
    chemin = [cible]
    c = cible
    while prof[c] > 1:
        suite = None
        for e in COTES:
            p = (c[0] + e[0], c[1] + e[1])
            if p in dedans and prof[p] == prof[c] - 1:
                suite = p
                break
        if suite is None:
            return False
        c = suite
        chemin.append(c)
    for (i, j) in chemin:
        plan[j][i] = ROUTE
    return True


## ⚠ LA BRETELLE A BESOIN D'UN COIN LIBRE, ET LA VILLE N'EN LAISSAIT AUCUN.
## `road-curve` coupe l'angle entre deux rues perpendiculaires : il lui faut un
## carré de 2 x 2 de terrain SOUPLE dont un côté touche une rue et le côté
## d'à côté une autre. Or, par construction, tout ce qui touche une rue est
## bâti, et tout ce qui ne l'est pas est au fond du pâté. Résultat : sur mille
## neuf cent vingt-neuf carrés souples au bon palier, ZÉRO n'avait de rue à ses
## deux bouts, et la pièce restait au fond du kit.
##
## On RÉSERVE donc quelques coins de pâté : deux cases sur deux au coin d'un
## îlot, qu'on ne bâtit pas et qu'on pave en esplanade. C'est la petite place
## de quartier, et c'est exactement là qu'un raccourci se coupe.
##
## Les quatre configurations sont celles de `CarteVille.COURBE_BOUTS`, jumelles
## de `BOUTS` dans `bretelles.py` : entrée par le milieu d'un côté, sortie par
## le milieu du côté d'à côté, deux cases plus loin.
COINS = [
    ((0, 0), (-1, 0), (1, 1), (0, 1)),
    ((0, 1), (0, 1), (1, 0), (1, 0)),
    ((1, 1), (1, 0), (0, 0), (0, -1)),
    ((1, 0), (0, -1), (0, 1), (-1, 0)),
]


def places_de_coin(plan, relief, cells, prof, pris, ecart=26):
    """Les 2 x 2 de coin d'îlot laissés libres pour une future bretelle."""
    dedans = set(cells)
    out = []
    for (i, j) in sorted(cells):
        carre = [(i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)]
        if any(c not in dedans for c in carre):
            continue
        if any(prof[c] > 2 for c in carre):
            continue
        if len({relief[c[1]][c[0]] for c in carre}) != 1:
            continue
        bon = False
        for (A, dA, D, dD) in COINS:
            a = (i + A[0] + dA[0], j + A[1] + dA[1])
            d = (i + D[0] + dD[0], j + D[1] + dD[1])
            if plan[a[1]][a[0]] == ROUTE and plan[d[1]][d[0]] == ROUTE:
                bon = True
                break
        if not bon:
            continue
        if any(abs(i - x) + abs(j - y) < ecart for (x, y) in pris):
            continue
        pris.append((i, j))
        out += carre
    return out


def batir(plan, cells, prof, district, alea, reserve=frozenset()):
    """Découpe la façade en rectangles — un rectangle, un bâtiment."""
    pmax = PROFOND[district]
    tmin, tmax = TAILLE_BATI[district]
    zone = {c for c in cells if prof[c] <= pmax and c not in reserve}
    libre = set(zone)
    poses = []
    jardins = []
    for (i, j) in sorted(zone, key=lambda c: (c[1], c[0])):
        if (i, j) not in libre or prof[(i, j)] != 1:
            continue
        # ⚠ UNE MAISON A UN JARDIN, ET LE JARDIN EST CE QUI FAIT SORTIR LA
        # MOITIÉ DU KIT PAVILLONNAIRE. Les clôtures, les allées, les dalles de
        # pierre, les arbres d'agrément ne se posent que sur une PELOUSE COLLÉE
        # À UN PAVILLON ET TOURNÉE VERS LA RUE. En bâtissant toute la façade,
        # la refonte n'en laissait aucune : quatorze modèles du kit sont sortis
        # de la ville d'un coup. On saute donc une case de façade sur cinq dans
        # le résidentiel — ce qui est aussi, tout simplement, à quoi ressemble
        # une rue de pavillons.
        if alea.random() < (0.20 if district == "residentiel" else 0.08):
            libre.discard((i, j))
            jardins.append((i, j))
            continue
        # on grandit vers l'est puis vers le sud, tant que ça reste dans la zone
        # ⚠ LA TAILLE SE TIRE UNE FOIS, PAS À CHAQUE PAS. Écrit dans la
        # condition de boucle, `randint` se retirait à chaque tour : la
        # probabilité de continuer s'effondrait et la médiane d'un bâtiment
        # tombait à deux cases. C'est exactement le défaut que le client
        # voyait — « la ville fait encore trop carré », parce qu'une ville de
        # bâtiments d'une case n'a pas de front de rue, seulement une trame.
        # ⚠ UNE TOUR A UNE PLUS GROSSE EMPRISE QU'UN PAVILLON. Sans ça, le
        # centre-ville sortait en aiguilles d'une case : haut, mais maigre.
        rang = rang_urbain(district, i, j, alea)
        gros = 2 if rang == 0 else (1 if rang == 1 else 0)
        vl = alea.randint(tmin, tmax) + gros
        vh = alea.randint(tmin, tmax) + gros
        larg = 1
        while larg < vl and (i + larg, j) in libre:
            larg += 1
        haut = 1
        while haut < vh and all((i + a, j + haut) in libre for a in range(larg)):
            haut += 1
        rect = [(i + a, j + b) for a in range(larg) for b in range(haut)]
        libre -= set(rect)
        poses.append(rect)
    # ⚠ DEUX BÂTIMENTS VOISINS NE DOIVENT PAS FUSIONNER. Un bloc de lettres
    # identiques EST un seul bâtiment : deux rectangles collés de même lettre
    # n'en font qu'un, tout en longueur. On alterne donc majuscule et minuscule
    # en damier — c'est exactement ce que le vocabulaire du dessin prévoit.
    for rect in poses:
        i, j = rect[0]
        choix = LETTRES[district][rang_urbain(district, i, j, alea)]
        lettre = choix[(i * 7 + j * 13) % len(choix)]
        if ((i // 2) + (j // 2)) % 2:
            lettre = lettre.lower() if lettre.isupper() else lettre.upper()
        for (x, y) in rect:
            plan[y][x] = lettre
    return jardins


## ⚠ UNE COUR EST D'UNE SEULE MATIÈRE. Tirée case par case, elle sortait en
## confettis : une case de pelouse, une de parking, une d'esplanade, un arbre.
## De loin, du bruit — le même bruit que le client a refusé. On tire donc UNE
## matière par coeur d'îlot, et on n'y sème que quelques arbres.
COEURS = [(",", 5), ("o", 2), ("P", 3), ("^", 2), (";", 0)]


def coeur(plan, cells, prof, district, alea):
    """Le coeur d'îlot : cour, pelouse, bosquet, parking — jamais un mur."""
    reste = [c for c in cells if plan[c[1]][c[0]] == ","]
    if not reste:
        return
    # ⚠ UN DÉPÔT EST UNE COUR ENTIÈRE, PAS UNE CASE. Les cuves, les cheminées,
    # le château d'eau et les éoliennes ne sortent qu'à la place d'un `X`, et
    # avec un écart minimum entre deux : vingt-huit `X` semés un par un le long
    # des quais n'en produisaient aucun. Un coeur d'îlot entier en dépôt, dans
    # le district industriel, en produit.
    fond = alea.choices([c for c, _ in COEURS[:4]],
                        [p for _, p in COEURS[:4]])[0]
    if district == "industriel" and alea.random() < 0.34:
        fond = "X"
    elif alea.random() < 0.05:
        fond = "%"
    for (i, j) in reste:
        plan[j][i] = fond
    if fond in ",o":  # on ne sème pas d'arbre dans un dépôt
        for (i, j) in reste:
            if alea.random() < 0.14:
                plan[j][i] = "^" if alea.random() < 0.7 else "'"


# ═════════════════════════════════════════════════════════════ 5. LE RELIEF

## ⚠ LE RELIEF SE RÉPARE, IL NE SE DEVINE PAS. Trois règles du vérificateur le
## contraignent, et deux d'entre elles portent sur la VOIRIE :
##
##   1. pas de marche au pied d'un croisement — une case de rue qui a des
##      voisines sur les DEUX axes doit être de plain-pied avec toutes ;
##   2. le long d'une droite, deux paliers d'écart au plus (c'est ce dont le
##      kit sait monter en une case) ;
##   3. un bâtiment tient sur un seul palier.
##
## On tire donc un relief lisse, on le quantifie, puis on le RÉPARE :
##   — les carrefours et les virages verrouillent leur voisinage à plat ;
##   — entre deux verrous, la portion droite interpole par paliers de deux ;
##   — chaque bâtiment prend le palier majoritaire de ses cases.
## C'est ce qui donne des rues plates aux croisements et des montées AU MILIEU
## des pâtés : exactement la façon dont une ville en pente se conduit.


def reparer_relief(plan, terre, relief, tours=8):
    """Verrouille les croisements, lisse les droites, met à plat les bâtiments."""
    def pal(i, j):
        return int(relief[j][i])

    for _ in range(tours):
        change = 0
        # 1. les croisements et les virages : leur voisinage passe à plat.
        for j in range(1, H - 1):
            for i in range(1, W - 1):
                if plan[j][i] != ROUTE:
                    continue
                nord_sud = plan[j - 1][i] == ROUTE or plan[j + 1][i] == ROUTE
                est_ouest = plan[j][i - 1] == ROUTE or plan[j][i + 1] == ROUTE
                if not (nord_sud and est_ouest):
                    continue
                # ⚠ ON DESCEND, ON NE MONTE JAMAIS. Deux croisements voisins de
                # paliers différents se renverraient la balle indéfiniment si
                # chacun imposait le sien. En prenant toujours le MINIMUM, la
                # somme des paliers ne peut que baisser : la réparation
                # converge, et elle converge vite.
                n = pal(i, j)
                for d in COTES:
                    a, b = i + d[0], j + d[1]
                    if plan[b][a] == ROUTE:
                        n = min(n, pal(a, b))
                if n != pal(i, j):
                    relief[j][i] = str(n)
                    change += 1
                for d in COTES:
                    a, b = i + d[0], j + d[1]
                    if plan[b][a] == ROUTE and pal(a, b) != n:
                        relief[b][a] = str(n)
                        change += 1
        # 2. les droites : deux paliers d'écart au plus entre deux voisines.
        for j in range(1, H - 1):
            for i in range(1, W - 1):
                if plan[j][i] != ROUTE:
                    continue
                for d in COTES:
                    a, b = i + d[0], j + d[1]
                    if plan[b][a] != ROUTE:
                        continue
                    e = pal(a, b) - pal(i, j)
                    if e > 2:
                        relief[b][a] = str(pal(i, j) + 2)
                        change += 1
        if change == 0:
            break
    # 3. la terre suit la rue la plus proche, puis chaque bâtiment se met à plat.
    d = {}
    q = deque()
    for j in range(H):
        for i in range(W):
            if plan[j][i] == ROUTE:
                d[(i, j)] = relief[j][i]
                q.append((i, j))
    while q:
        x, y = q.popleft()
        for e in COTES:
            a, b = x + e[0], y + e[1]
            if 0 <= a < W and 0 <= b < H and terre[b][a] and (a, b) not in d:
                d[(a, b)] = d[(x, y)]
                q.append((a, b))
    for (i, j), v in d.items():
        relief[j][i] = v
    durcir_marches(plan, relief)
    # ⚠ UN BÂTIMENT TIENT SUR UN SEUL PALIER (règle 3). Une façade posée entre
    # deux rues de paliers différents en attraperait deux. On met chaque bloc
    # de lettres identiques au palier de sa case la plus basse : un immeuble
    # s'assied dans la pente, il ne flotte pas au-dessus.
    vu = grille(False)
    for j in range(H):
        for i in range(W):
            c = plan[j][i]
            if c not in BATI or vu[j][i]:
                continue
            q = deque([(i, j)])
            vu[j][i] = True
            cells = []
            while q:
                x, y = q.popleft()
                cells.append((x, y))
                for e in COTES:
                    a, b = x + e[0], y + e[1]
                    if 0 <= a < W and 0 <= b < H and plan[b][a] == c and not vu[b][a]:
                        vu[b][a] = True
                        q.append((a, b))
            n = min(int(relief[y][x]) for (x, y) in cells)
            for (x, y) in cells:
                relief[y][x] = str(n)
    return relief


## ⚠ SANS MARCHE DE DEUX PALIERS, PAS DE RAMPE. Le kit a `road-slant` (un
## palier en une case), `road-slant-high` (deux en une case, la marche de
## garage) et `road-slant-curve` (deux en DEUX cases, la montée douce d'une voie
## rapide). Le relief lissé puis réparé ne faisait plus que des marches d'un
## palier : les deux dernières pièces ne se posaient nulle part.
##
## On DURCIT donc une montée sur deux. Là où une rue droite monte d'un palier
## puis encore d'un, on remonte la case du milieu : les deux marches d'un
## deviennent une marche de DEUX, suivie d'un plat. La règle tient toujours —
## la case durcie est au milieu d'une droite, elle n'a pas de voisine
## perpendiculaire, donc la marche est « selon l'axe » — et `bretelles.py` a de
## quoi poser ses rampes douces.
##
## ⚠ UNE SUR DEUX, PAS TOUTES. Durcies toutes, `road-slant` disparaîtrait à son
## tour : c'est le même défaut à l'envers.
def durcir_marches(plan, relief, part=2):
    n = 0
    for j in range(2, H - 2):
        for i in range(2, W - 2):
            if plan[j][i] != ROUTE:
                continue
            for (dx, dy) in ((1, 0), (0, 1)):
                px, py = -dx, -dy
                # la case doit être AU MILIEU D'UNE DROITE : aucune voisine de
                # rue sur l'axe perpendiculaire, sinon la marche tombe au pied
                # d'un croisement et le vérificateur la refuse.
                if plan[j + dx][i + dy] == ROUTE or plan[j - dx][i - dy] == ROUTE:
                    continue
                a = (i + px, j + py)
                b = (i + dx, j + dy)
                if plan[a[1]][a[0]] != ROUTE or plan[b[1]][b[0]] != ROUTE:
                    continue
                p0 = int(relief[a[1]][a[0]])
                p1 = int(relief[j][i])
                p2 = int(relief[b[1]][b[0]])
                if p1 != p0 + 1 or p2 != p1 + 1:
                    continue
                if (i * 73856093 ^ j * 19349663) % part:
                    continue
                relief[j][i] = str(p2)
                n += 1
                break
    return n


## ⚠ LE RIVAGE SE DÉCIDE AVANT DE BÂTIR, PAS APRÈS. Les plages étaient
## ajoutées en dernier, en arcs, sur ce qui restait de pelouse : là où le front
## de mer était bâti — c'est-à-dire presque partout — il n'y avait plus rien à
## ensabler, et la ville tombait dans l'eau à pic comme une maquette posée sur
## un miroir. Le rivage est donc tracé AVANT les pâtés, et les pâtés se
## calculent sur ce qui reste.
##
## Et il suit la logique d'une vraie côte — celle des GTA, où l'on fait le tour
## d'une île en voiture en voyant la plage d'un côté et les façades de l'autre :
##
##   côte BASSE (palier 0-1), quartier d'habitation ou centre   →  la plage,
##       trois cases de sable entre la corniche et l'eau ; en centre-ville, la
##       case contre la corniche est une promenade pavée
##   côte HAUTE (palier 2 et plus)                             →  la falaise :
##       pas de sable, la ville bâtit jusqu'au bord et les rochers font le reste
##   zone industrielle, ou à moins de cinq cases d'un poste à quai  →  le quai :
##       pas de sable, la terre tombe dans l'eau, les conteneurs derrière
def rivage(plan, relief, terre, dist, quartier):
    n_sable = n_prom = 0
    for j in range(H):
        for i in range(W):
            if not terre[j][i] or plan[j][i] != "," or dist[j][i] > 3:
                continue
            if int(relief[j][i]) >= 2:
                continue                       # falaise : pas de plage
            q = quartier[j][i]
            district = q[1] if q else "residentiel"
            if district == "industriel" and (i * 31 + j * 17) % 5:
                continue                       # le quai, sauf une anse sur cinq
            if any(plan[y][x] == "~"
                   for x in range(max(0, i - 5), min(W, i + 6))
                   for y in range(max(0, j - 5), min(H, j + 6))):
                continue                       # le port a des quais, pas des plages
            if district == "centre" and dist[j][i] == 3:
                plan[j][i] = "o"
                n_prom += 1
            else:
                plan[j][i] = ";"
                n_sable += 1
    return n_sable, n_prom


# ═══════════════════════════════════════════════════════════ 6. LES DÉTAILS

## ⚠ UNE PLAGE EST UN ARC, PAS UNE PROBABILITÉ. Semée case par case à une
## chance sur deux, elle sortait en confettis : un liseré grésillant tout
## autour de chaque île, qui de loin ressemblait à de la neige électronique.
## On tire donc quelques ARCS du rivage — début, longueur — et on les remplit
## en entier, avec la dune d'herbe derrière.
def plages(plan, terre, dist, ile, alea, combien):
    bord = sorted([c for c in ile if dist[c[1]][c[0]] == 1],
                  key=lambda c: (c[1], c[0]))
    if len(bord) < 60:
        return 0
    n = 0
    # Les cases de rivage, regroupées en morceaux qui se touchent : un arc ne
    # saute pas d'un cap à l'autre.
    reste = set(bord)
    arcs = []
    while reste:
        d0 = reste.pop()
        f = deque([d0])
        arc = [d0]
        while f:
            x, y = f.popleft()
            for a in (-1, 0, 1):
                for b in (-1, 0, 1):
                    p = (x + a, y + b)
                    if p in reste:
                        reste.discard(p)
                        arc.append(p)
                        f.append(p)
        if len(arc) > 40:
            arcs.append(arc)
    for arc in arcs:
        for _ in range(combien):
            depart = alea.randrange(len(arc))
            long = alea.randint(14, 34)
            for k in range(long):
                (i, j) = arc[(depart + k) % len(arc)]
                for a in (-2, -1, 0, 1, 2):
                    for b in (-2, -1, 0, 1, 2):
                        x, y = i + a, j + b
                        if 0 <= x < W and 0 <= y < H and plan[y][x] in ",^'o" \
                                and dist[y][x] <= 3:
                            plan[y][x] = ";"
                n += 1
    return n


def port(plan, terre, ile, alea, combien=7):
    """Le port : des postes d'amarrage le long d'un quai, et le dépôt derrière.

    Une file de `~` est une place à quai, et sa LONGUEUR choisit le bateau.
    On la trace à l'extérieur du rivage, perpendiculairement, pour que le quai
    reste droit et que les navires s'alignent.
    """
    bord = [c for c in ile
            if any(not terre[c[1] + d[1]][c[0] + d[0]] for d in COTES)]
    bord.sort(key=lambda c: (c[1], c[0]))
    poses = 0
    dernier = None
    for (i, j) in bord:
        if poses >= combien:
            break
        if dernier and abs(j - dernier) < 6:
            continue
        # la mer est-elle à l'est ?
        if terre[j][i + 1] or not all(
                0 <= i + k < W and not terre[j][i + k] for k in range(1, 10)):
            continue
        if plan[j][i] not in ",^';oP":
            continue
        n = alea.choice([2, 3, 5, 6, 8])
        for k in range(1, n + 1):
            plan[j][i + k] = "~"
        plan[j][i] = "X"
        poses += 1
        dernier = j
    return poses


def ronds_points(plan, relief, terre, alea, combien, ecart=34):
    """Un rond-point aux grands croisements — il lui faut 3 x 3 au même palier."""
    cands = []
    for j in range(2, H - 2):
        for i in range(2, W - 2):
            if plan[j][i] != ROUTE:
                continue
            bras = [d for d in COTES if plan[j + d[1]][i + d[0]] == ROUTE]
            if len(bras) < 4:
                continue
            carre = [(i + a, j + b) for a in (-1, 0, 1) for b in (-1, 0, 1)]
            if any(not terre[y][x] for (x, y) in carre):
                continue
            if len({relief[y][x] for (x, y) in carre}) != 1:
                continue
            if not all(plan[j + d[1] * 2][i + d[0] * 2] == ROUTE for d in COTES):
                continue
            cands.append((i, j))
    # ⚠ LE ROND-POINT DU BORD PASSE DEVANT. `road-roundabout-barrier` ne se
    # pose que si l'un des neuf carrés du giratoire surplombe l'eau ou deux
    # paliers de vide. Tirés au hasard, les vingt-deux ronds-points tombaient
    # tous au milieu d'un quartier plat et la glissière circulaire restait au
    # fond du kit. On trie donc les candidats : ceux du bord d'abord.
    def au_bord(i, j):
        n = int(relief[j][i])
        for a in (-2, -1, 0, 1, 2):
            for b in (-2, -1, 0, 1, 2):
                x, y = i + a, j + b
                if not (0 <= x < W and 0 <= y < H):
                    return True
                if not terre[y][x] or int(relief[y][x]) <= n - 2:
                    return True
        return False

    alea.shuffle(cands)
    cands.sort(key=lambda c: 0 if au_bord(c[0], c[1]) else 1)
    pris = []
    for (i, j) in cands:
        if len(pris) >= combien:
            break
        if any(abs(i - x) + abs(j - y) < ecart for (x, y) in pris):
            continue
        for a in (-1, 1):
            for b in (-1, 1):
                plan[j + b][i + a] = "o"
        for d in COTES:
            plan[j + d[1]][i + d[0]] = ROUTE
        plan[j][i] = "O"
        pris.append((i, j))
    return len(pris)


## LES BÂTIMENTS À INTERACTION. Ils remplacent un bâtiment existant, donc ils
## héritent de son accès à la rue : pas d'hôpital au fond d'un pré.
## `E` l'église et `K` la casse automobile : les deux bâtiments Piks-l livrés le
## 11 septembre. L'église va dans les quartiers d'habitation et le centre, la
## casse dans la zone industrielle uniquement — une casse au milieu des
## pavillons, ça ne se voit que dans les mauvais quartiers de GTA, et on n'en a
## pas encore.
INTERACTIONS = [("+", 8), ("F", 8), ("S", 14), ("$", 10), ("?", 40), ("*", 30),
                ("E", 7), ("K", 4)]
DISTRICT_DE = {"K": ("industriel",), "E": ("residentiel", "centre")}


def interactions(plan, alea, quartier=None):
    cases = [(i, j) for j in range(H) for i in range(W) if plan[j][i] in BATI]
    alea.shuffle(cases)
    poses = {}
    k = 0
    for (lettre, combien) in INTERACTIONS:
        n = 0
        while n < combien and k < len(cases):
            i, j = cases[k]
            k += 1
            if plan[j][i] not in BATI:
                continue
            if quartier is not None and lettre in DISTRICT_DE:
                q = quartier[j][i]
                if not q or q[1] not in DISTRICT_DE[lettre]:
                    continue
            if any(abs(i - x) + abs(j - y) < 26
                   for (x, y) in poses.get(lettre, [])):
                continue
            # ⚠ UN HÔPITAL FAIT 2 x 2, UNE CABINE UNE CASE. Un caractère
            # d'interaction posé sur UNE case d'un bâtiment de six couperait le
            # bâtiment en deux ; on remplace donc tout le bloc de lettres.
            c = plan[j][i]
            bloc = [(i, j)]
            q = deque([(i, j)])
            vu = {(i, j)}
            while q:
                x, y = q.popleft()
                for d in COTES:
                    a, b = x + d[0], y + d[1]
                    if (a, b) not in vu and 0 <= a < W and 0 <= b < H \
                            and plan[b][a] == c:
                        vu.add((a, b))
                        bloc.append((a, b))
                        q.append((a, b))
            if lettre in "?*" and len(bloc) > 2:
                continue
            if lettre not in "?*" and not (3 <= len(bloc) <= 9):
                continue
            for (x, y) in bloc:
                plan[y][x] = lettre
            poses.setdefault(lettre, []).append((i, j))
            n += 1
    return {k2: len(v) for k2, v in poses.items()}


# ══════════════════════════════════════════════════════════ 7. L'ASSEMBLAGE

REGLAGES = {
    # district      corniche  pas avenue   pas rue   décalage  bosses
    "centre":      dict(k=4,  av=(22, 33), rue=(8, 13), dec=3),
    "residentiel": dict(k=4,  av=(24, 36), rue=(9, 14), dec=3),
    "industriel":  dict(k=4,  av=(26, 38), rue=(9, 15), dec=2),
}

## ⚠ UN RELIEF TROP DOUX N'A PAS DE MARCHE. Des bosses larges et basses
## donnaient une pente de sept centièmes de palier par case : il fallait
## vingt-sept cases pour monter de deux, et une rue ne monte jamais de deux
## d'un coup. Des bosses PLUS SERRÉES ET PLUS HAUTES donnent des coteaux au
## lieu de dunes — et des marches à durcir.
##
## ⚠ ET UNE VILLE À RELIEF A DES CRÊTES, PAS SEULEMENT DES BOSSES. Une bosse
## ronde fait une colline ; une crête ALLONGÉE fait un coteau, une ligne de
## faîte, un quartier haut qui domine un quartier bas d'un seul côté — et
## c'est ce qui donne des rues qui MONTENT sur toute leur longueur. Chaque
## entrée porte donc un allongement (rx, ry) et un angle.
##
##   (cx, cy, rx, ry, angle°, amplitude, falaise)
##   falaise = True : la bosse ne s'efface PAS en approchant du rivage, elle
##   tombe dans la mer — c'est la corniche haute, le cap rocheux.
BOSSES = [
    # ⚠ D'ABORD LE SOCLE : une ondulation large par île, pour qu'aucun
    # quartier ne soit un billard. Sans lui, quatre cases sur cinq restaient
    # au palier zéro et tout le relief tenait sur trois collines.
    (150, 60, 120, 50, 0, 2.6, False), (150, 172, 100, 40, 0, 2.4, False),
    (160, 262, 110, 34, 0, 1.8, False),
    # l'île nord — le centre : une colline haute au coeur, une crête vers l'est
    (112, 56, 34, 24, 20, 8.5, False), (196, 46, 44, 18, -15, 6.8, False),
    (238, 84, 20, 15, 0, 5.4, True), (150, 66, 18, 28, 60, 5.0, False),
    (78, 74, 18, 13, 0, 4.4, True), (60, 40, 15, 11, 30, 3.8, True),
    # l'île du milieu — le résidentiel : une longue crête, deux buttes
    (132, 170, 48, 18, -12, 7.6, False), (210, 168, 20, 20, 0, 5.6, False),
    (104, 190, 15, 13, 0, 4.4, True), (232, 150, 13, 11, 0, 4.0, True),
    # l'île sud — l'industriel : plus bas, mais un cap et un plateau
    (150, 258, 34, 16, 8, 5.0, False), (250, 256, 16, 13, 0, 4.2, False),
    (100, 262, 13, 11, 0, 4.2, True), (200, 280, 18, 9, 0, 3.2, False),
]


def champ(terre, dist, alea, bosses):
    h = [[0.0] * W for _ in range(H)]
    pre = []
    for (cx, cy, rx, ry, ang, a, falaise) in bosses:
        t = math.radians(ang)
        pre.append((cx, cy, rx, ry, math.cos(t), math.sin(t), a, falaise))
    for j in range(H):
        for i in range(W):
            if not terre[j][i]:
                continue
            v = 0.0
            for (cx, cy, rx, ry, c, s_, a, falaise) in pre:
                dx, dy = i - cx, j - cy
                u = (dx * c + dy * s_) / float(rx)
                w = (-dx * s_ + dy * c) / float(ry)
                d2 = u * u + w * w
                if d2 < 1.0:
                    b = a * (1.0 - d2) ** 1.3
                    # ⚠ LE RIVAGE RESTE BAS — sauf falaise voulue. Une bosse
                    # ordinaire s'efface sur les neuf dernières cases avant
                    # l'eau ; une falaise garde toute sa hauteur jusqu'au bord.
                    if not falaise:
                        b *= min(1.0, dist[j][i] / 6.0)
                    v += b
            h[j][i] = v
    return h


def quantifier(terre, h, maxi=9):
    r = [["0"] * W for _ in range(H)]
    for j in range(H):
        for i in range(W):
            if terre[j][i]:
                r[j][i] = str(max(0, min(maxi, int(h[j][i] + 0.5))))
    return r


def construire(graine=7):
    alea = random.Random(graine)
    terre, quartier = poser_iles()
    dist = distance_a_la_mer(terre)
    plan = grille(MER)
    for j in range(H):
        for i in range(W):
            if terre[j][i]:
                plan[j][i] = ","

    iles = [m for m in morceaux_de_terre(terre)]
    rapport = {"iles": len(iles), "desservies": 0, "raccroches": 0,
               "ebarbes": 0, "diagonales": 0, "places": 0, "jardins": 0}

    for ile in iles:
        nom, district = quartier[ile[0][1]][ile[0][0]]
        r = REGLAGES[district]
        petite = len(ile) < 2500
        corniche(plan, terre, dist, ile, 3 if petite else r["k"])
        lignes = avenues(plan, terre, ile, alea,
                         12 if petite else r["av"][0], 18 if petite else r["av"][1])
        rues(plan, terre, ile, lignes, alea,
             6 if petite else r["rue"][0], 9 if petite else r["rue"][1], r["dec"])
        # ⚠ UN QUARTIER RÉSIDENTIEL N'A PAS LA TRAME D'UN CENTRE-VILLE. Les
        # districts ne se distinguaient que par leurs LETTRES : mêmes rues,
        # mêmes pâtés, seulement des maisons au lieu de tours. On ajoute donc
        # au résidentiel des rues DE NIVEAU — la même courbe de distance à la
        # mer que la corniche, mais plus loin dans les terres. Concentriques et
        # courbes, elles coupent la trame droite en biais : c'est le lotissement
        # de banlieue, et ça ne ressemble à rien d'autre dans la ville.
        if district == "residentiel" and not petite:
            for k in range(r["k"] + 11, 60, alea.randint(11, 16)):
                corniche(plan, terre, dist, ile, k)
        if not petite:
            # ⚠ LE DÉPART SE PREND DANS L'ÎLE, PAS DANS SON RECTANGLE. Tiré au
            # hasard dans la boîte englobante, un point sur deux tombait dans
            # l'eau et la diagonale s'arrêtait au premier pas.
            xs = [c[0] for c in ile]
            gauche = sorted(ile, key=lambda c: c[0])[:len(ile) // 6]
            for _ in range(3):
                d = alea.choice([(1, 1), (1, -1)])
                depart = alea.choice(gauche)
                rapport["diagonales"] += 1 if diagonale(
                    plan, terre, ile, alea, depart, d, 400) > 60 else 0

    # UN SEUL RÉSEAU PAR ÎLE, PUIS PLUS AUCUN BOUT MORT.
    for ile in iles:
        a, b = raccrocher(plan, terre, ile)
        rapport["raccroches"] += a
        rapport["ebarbes"] += b
    rapport["ebarbes"] += ebarber(plan, terre)

    # LES PÂTÉS : desserte du coeur, puis façade, puis coeur d'îlot.
    # ⚠ ON RECREUSE TANT QUE LE COEUR RESTE HORS D'ATTEINTE. Une seule passe
    # laissait de grands pâtés dont le milieu restait à cinq ou six cases de
    # la rue : vus d'avion, des carrés de pelouse au milieu de la ville. Cinq
    # tours suffisent à ce qu'aucun coeur ne dépasse la profondeur 3.
    for tour in range(6):
        reste = 0
        for bloc in composantes(plan, ","):
            if len(bloc) < 22:
                continue
            prof = profondeurs(plan, bloc)
            if max(prof.values()) >= 4:
                reste += 1
                if desservir(plan, terre, bloc, prof):
                    rapport["desservies"] += 1
        if reste == 0:
            break
    # ⚠ LE RELIEF SE CALCULE AVANT DE BÂTIR. Les places de coin réservées aux
    # bretelles doivent être d'un seul palier, et on ne peut le savoir qu'une
    # fois le relief posé. Le bâti, lui, ne change rien au terrain — sauf la
    # mise à plat des blocs, qu'on refait après.
    relief = quantifier(terre, champ(terre, dist, alea, BOSSES))
    reparer_relief(plan, terre, relief)

    # LE PORT D'ABORD — ses quais chassent la plage —, PUIS LE RIVAGE, avant
    # les pâtés : les plages ne se bâtissent pas.
    rapport["port"] = sum(port(plan, terre, ile, alea, 8 if len(ile) > 8000 else 2)
                          for ile in iles if len(ile) > 900)
    rapport["sable"], rapport["promenade"] = rivage(plan, relief, terre, dist, quartier)

    coins = []
    for bloc in composantes(plan, ","):
        i0, j0 = bloc[0]
        q = quartier[j0][i0]
        district = q[1] if q else "residentiel"
        prof = profondeurs(plan, bloc)
        reserve = set(places_de_coin(plan, relief, bloc, prof, coins))
        rapport["places"] = len(coins)
        jardins = batir(plan, bloc, prof, district, alea, reserve)
        coeur(plan, bloc, prof, district, alea)
        rapport["jardins"] += len(jardins)
        # Le jardin reste de la PELOUSE : c'est le caractère que le jeu lit
        # pour y poser l'allée, la clôture et l'arbre d'agrément.
        #
        # ⚠ SAUF DEVANT UN PARKING : là, c'est l'ENTRÉE du parking, et la rue
        # qui la longe s'ouvre en contre-allée (`road-side`). Un parking au
        # fond d'un îlot sans accès n'est pas un parking, c'est une cour — et
        # les deux pièces de contre-allée du kit ne sortaient nulle part.
        for (i, j) in jardins:
            voisin_p = any(plan[j + d[1]][i + d[0]] == "P" for d in COTES)
            plan[j][i] = "P" if voisin_p else ","
        for (i, j) in reserve:
            plan[j][i] = "o"

    # On remet les blocs de lettres à plat : ils n'existaient pas encore au
    # moment de la réparation.
    reparer_relief(plan, terre, relief)

    # LES DÉTAILS.
    rapport["plages"] = rapport["sable"]
    rapport["ronds"] = ronds_points(plan, relief, terre, alea, 22)
    rapport["interactions"] = interactions(plan, alea, quartier)
    return plan, relief, rapport


# ═══════════════════════════════════════════════════════════ 8. L'ÉCRITURE

def audit(plan):
    """Les trois chiffres qui disent si la refonte tient."""
    blocs, sans = 0, 0
    vu = grille(False)
    tailles = []
    for j in range(H):
        for i in range(W):
            c = plan[j][i]
            if c not in BATI or vu[j][i]:
                continue
            q = deque([(i, j)])
            vu[j][i] = True
            cells = []
            while q:
                x, y = q.popleft()
                cells.append((x, y))
                for d in COTES:
                    a, b = x + d[0], y + d[1]
                    if 0 <= a < W and 0 <= b < H and plan[b][a] == c and not vu[b][a]:
                        vu[b][a] = True
                        q.append((a, b))
            blocs += 1
            tailles.append(len(cells))
            if not any(plan[y + d[1]][x + d[0]] in VOIRIE
                       for (x, y) in cells for d in COTES):
                sans += 1
    comps = composantes(plan, VOIRIE)
    tailles.sort()
    imp = sum(1 for j in range(H) for i in range(W)
              if plan[j][i] == ROUTE
              and sum(1 for d in COTES if plan[j + d[1]][i + d[0]] in VOIRIE) == 1)
    return {"blocs": blocs, "sans_acces": sans,
            "mediane": tailles[len(tailles) // 2] if tailles else 0,
            "max_bloc": tailles[-1] if tailles else 0,
            "voirie": sum(len(c) for c in comps), "morceaux": len(comps),
            "impasses": imp}


def ecrire(plan, relief):
    src = open(FICHIER, encoding="utf-8").read()
    for nom, g in (("PLAN", plan), ("RELIEF", relief)):
        m = re.search(r"(const %s: Array\[String\] = \[\n)(.*?)(\n\])" % nom, src, re.S)
        corps = ",\n".join('\t"%s"' % "".join(l) for l in g)
        src = src[:m.start(2)] + corps + src[m.end(2):]
    open(FICHIER, "w", encoding="utf-8").write(src)


## ⚠ TOUT CE QUI AJOUTE UNE RUE APRÈS COUP CASSE LE RELIEF. `ponts.py` perce
## des berges, `corniche.py` pousse des éperons : chaque case de rue neuve peut
## transformer une droite qui enjambait un cran en croisement à marche, que le
## vérificateur refuse à juste titre. Plutôt que d'apprendre les trois règles à
## chaque outil, on repasse le RÉPARATEUR à la fin de la chaîne.
##
## ⚠ ET ON PROTÈGE LES GROSSES PIÈCES. Le réparateur ne sait que DESCENDRE une
## case ; descendre une seule case du carré d'un rond-point le rend non
## uniforme, la pièce est refusée en silence et le compte ne tombe plus juste.
## On remet donc chaque emprise à plat — au minimum de ses cases — après coup.
def reparer_fichier():
    src = open(FICHIER, encoding="utf-8").read()
    plan, _ = lire(src, "PLAN")
    relief, _ = lire(src, "RELIEF")
    v = Ville(plan, relief)
    terre = [[v.p[j][i] not in ".~" for i in range(W)] for j in range(H)]
    reparer_relief(v.p, terre, v.r)
    for j in range(H):
        for i in range(W):
            c = v.p[j][i]
            emprise = None
            if c == "O":
                emprise = [(i + a, j + b) for a in (-1, 0, 1) for b in (-1, 0, 1)]
            elif c == "(":
                emprise = [(i + a, j + b) for a in (0, 1) for b in (0, 1)]
            if not emprise:
                continue
            if any(not (0 <= x < W and 0 <= y < H) for (x, y) in emprise):
                continue
            n = min(int(v.r[y][x]) for (x, y) in emprise)
            for (x, y) in emprise:
                v.r[y][x] = str(n)
    ecrire(["".join(l) for l in v.p], ["".join(l) for l in v.r])
    print("relief réparé dans", FICHIER)


class Ville:
    """Le strict minimum pour relire un dessin déjà écrit."""
    def __init__(self, plan, relief):
        self.p = [list(l) for l in plan]
        self.r = [list(l) for l in relief]


def lire(src, nom):
    m = re.search(r"const %s: Array\[String\] = \[\n(.*?)\n\]" % nom, src, re.S)
    return [l.strip().rstrip(",").strip(chr(34)) for l in m.group(1).split("\n")], m.span(1)


def main():
    if "--reparer" in sys.argv:
        reparer_fichier()
        return 0
    essai = "--essai" in sys.argv
    graine = 7
    for a in sys.argv:
        if a.startswith("--graine="):
            graine = int(a.split("=")[1])
    plan, relief, rap = construire(graine)
    a = audit(plan)
    print("îles : %d   diagonales : %d   dessertes : %d   raccrochages : %d   ébarbages : %d"
          % (rap["iles"], rap["diagonales"], rap["desservies"],
             rap["raccroches"], rap["ebarbes"]))
    print("ronds-points : %d   places de coin : %d   jardins : %d   postes à quai : %d"
          % (rap["ronds"], rap["places"], rap["jardins"], rap["port"]))
    print("rivage : %d cases de sable, %d de promenade" % (rap["sable"], rap["promenade"]))
    print("interactions : %s" % rap["interactions"])
    print("BÂTIMENTS : %d blocs, %d SANS ACCÈS, médiane %d cases, plus gros %d"
          % (a["blocs"], a["sans_acces"], a["mediane"], a["max_bloc"]))
    print("VOIRIE : %d cases en %d morceau(x), %d impasses"
          % (a["voirie"], a["morceaux"], a["impasses"]))
    if essai:
        return 0
    ecrire(plan, relief)
    print("écrit dans", FICHIER)
    return 0


if __name__ == "__main__":
    sys.exit(main())
