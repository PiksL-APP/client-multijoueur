#!/usr/bin/env python3
"""Le contrôle des intérieurs de repaire : orientation, passage, encombrement.

Ce qui ne se voit PAS sur une vue de trois quarts, et que ce contrôle attrape :

  1. un meuble qui REGARDE SA CLOISON. La façade des modèles Kenney est en +Z
     (cf. `interieurs.gd`), et un placard vu de dos a la même silhouette que vu
     de face : c'est l'erreur la plus coûteuse du lot ;
  2. un siège qui tourne le dos à sa table, un canapé qui tourne le dos à la télé ;
  3. un meuble PLANTÉ DEVANT UNE PORTE — on entre chez soi dans une armoire ;
  4. deux meubles qui s'interpénètrent, ou qui entrent dans un mur.

Les emprises viennent de `outils/empreintes.py` : la grille de présence RÉELLE
de chaque modèle, pas sa boîte englobante. C'est indispensable — un bureau
d'angle, une chaise à pieds, un canapé d'angle laissent un creux, et testés à
la boîte ils déclenchent un faux chevauchement dès qu'on range quelque chose
dedans. La hauteur de chaque case sert à distinguer « la lampe traverse la
table » de « la lampe est posée dessus ».

    python3 outils/paquet.py && python3 outils/empreintes.py   (une fois)
    godot --headless --path . --script outils/vider.gd          (le catalogue)
    python3 outils/verifier.py
"""
import json, math, os, re, sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(RACINE, '_transfert', 'vitrine')
cat = json.load(open(os.path.join(T, 'catalogue.json'), encoding='utf-8'))
EMP = json.load(open(os.path.join(T, 'empreintes.json'), encoding='utf-8'))
ORDRE = ['taudis', 'ouvrier', 'planque', 'atelier', 'pavillon', 'poste', 'loft', 'penthouse']
CAPS = ['N', 'O', 'S', 'E']
NORMALE = [(0, 1), (1, 0), (0, -1), (-1, 0)]     # façade en +Z à r = 0
NOURRITURE = 0.18
MAILLE = 0.04                                     # 8 cm : la finesse du contrôle
N = 16

FRONT = re.compile(r'^(kitchen(Cabinet|Sink|Stove|Fridge|Microwave|CoffeeMachine|Blender|Bar|BarEnd)'
                   r'|hood|bathroom(Cabinet|Mirror|Sink)|toilet|washer|dryer|bed(Single|Double|Bunk)'
                   r'|cabinet(Bed|Television)|bookcase|desk|television|computerScreen|laptop|lounge'
                   r'|chair|stool|bench|coatRack$|lampWall|paneling|speaker|radio|c:coffre)')
MURAL = re.compile(r'^(kitchenCabinetUpper|hood|bathroomMirror|bathroomCabinet|lampWall|paneling|coatRack$)')
ASSIS = re.compile(r'^(chair|stoolBar|benchCushion|loungeChair$)')
PLANS = re.compile(r'^(table|desk|kitchenBar|deskCorner|tableRound|tableCross|tableGlass|tableCloth'
                   r'|tableCrossCloth|kitchenBarEnd)')
PLAT = re.compile(r'^(rug|n:)')                   # tapis et vaisselle : on passe dessus


def facteur(nom):
    return NOURRITURE if nom.startswith('n:') else 1.0


def cases(m):
    """Les cases occupées par un meuble, en coordonnées de tuile : {(i,j): (bas, haut)}."""
    e = EMP.get(m['m'])
    if e is None:
        return {}
    f = facteur(m['m']) * (m.get('t', 1) or 1)
    lo, ech = e['lo'], e['ech']
    cx, cz = lo[0] + ech[0] / 2, lo[2] + ech[2] / 2      # le centre d'emprise
    r = m['r']
    out = {}
    for j in range(N):
        for i in range(N):
            h = e['h'][j][i]
            if h <= 0.004:
                continue
            # centre de la case, ramené au centre d'emprise puis mis à l'échelle
            u = (lo[0] + (i + 0.5) / N * ech[0] - cx) * f
            v = (lo[2] + (j + 0.5) / N * ech[2] - cz) * f
            if r == 1:   u, v = v, -u
            elif r == 2: u, v = -u, -v
            elif r == 3: u, v = -v, u
            x, z = m['x'] + u, m['z'] + v
            bas = m.get('y', 0.0)
            haut = bas + h * f
            cle = (int(math.floor(x / MAILLE)), int(math.floor(z / MAILLE)))
            vieux = out.get(cle)
            out[cle] = (bas, haut) if vieux is None else (min(vieux[0], bas), max(vieux[1], haut))
    return out


def murs(plan):
    out = []
    for r, ligne in enumerate(plan):
        for c, ch in enumerate(ligne):
            if r % 2 == c % 2 or ch not in '-|DAFBH':
                continue
            horiz = r % 2 == 0
            cx = (c - 1) / 2 + 0.5 if horiz else c / 2
            cz = r / 2 if horiz else (r - 1) / 2 + 0.5
            E = 0.06
            out.append(dict(ch=ch, cx=cx, cz=cz, horiz=horiz, dur=ch in '-|FB',
                            porte=ch in 'DA',
                            x0=cx - (0.5 if horiz else E), x1=cx + (0.5 if horiz else E),
                            z0=cz - (E if horiz else 0.5), z1=cz + (E if horiz else 0.5)))
    return out


def plancher(plan, x, z):
    c, l = int(x // 1), int(z // 1)
    if l < 0 or c < 0 or 2 * l + 1 >= len(plan):
        return False
    ligne = plan[2 * l + 1]
    return 2 * c + 1 < len(ligne) and ligne[2 * c + 1] != ' '


def dans(ms, x, z, durs=True):
    for w in ms:
        if durs and not w['dur']:
            continue
        if w['x0'] <= x <= w['x1'] and w['z0'] <= z <= w['z1']:
            return w
    return None


def mur_dedans(ms, m):
    """Le meuble franchit-il le PLAN MÉDIAN d'une cloison ?

    On ne mesure pas le recouvrement de l'épaisseur du mur : celle-ci vaut
    0.052 tuile, si bien qu'un seuil de 0.055 ne pouvait jamais se déclencher —
    l'ancien contrôle ne voyait que les meubles traversant de part en part.
    """
    if m.get('y', 0) >= 1.2 or PLAT.match(m['m']):
        return False
    t = m.get('t', 1) or 1
    l, p = (m['p'] * t, m['l'] * t) if m['r'] % 2 else (m['l'] * t, m['p'] * t)
    ax0, ax1, az0, az1 = m['x'] - l / 2, m['x'] + l / 2, m['z'] - p / 2, m['z'] + p / 2
    E = 0.026
    for w in ms:
        if not w['dur']:
            continue
        wx0, wx1 = (w['cx'] - 0.5, w['cx'] + 0.5) if w['horiz'] else (w['cx'] - E, w['cx'] + E)
        wz0, wz1 = (w['cz'] - E, w['cz'] + E) if w['horiz'] else (w['cz'] - 0.5, w['cz'] + 0.5)
        if min(ax1, wx1) - max(ax0, wx0) <= 0 or min(az1, wz1) - max(az0, wz0) <= 0:
            continue
        # Le meuble doit tenir ENTIÈREMENT d'un côté du plan médian, à 3 cm de
        # débord près. Comparer au seul côté de son centre laisserait passer un
        # meuble qui a fini de traverser.
        if w['horiz']:
            devant, derriere = az1 - w['cz'], w['cz'] - az0
        else:
            devant, derriere = ax1 - w['cx'], w['cx'] - ax0
        if devant > 0.03 and derriere > 0.03:
            return True
    return False


def pieces(plan):
    """Une étiquette de pièce par tuile : on ne déplace pas un meuble d'une
    pièce à l'autre pour le décoller de son voisin — une chaise de table n'a
    rien à faire dans la chambre, même si la géométrie le permet."""
    h, l = (len(plan) - 1) // 2, (max(len(x) for x in plan) - 1) // 2
    ids = [[-1] * l for _ in range(h)]
    n = 0
    for z0 in range(h):
        for x0 in range(l):
            if ids[z0][x0] != -1 or not plancher(plan, x0 + .5, z0 + .5):
                continue
            pile, n = [(x0, z0)], n + 1
            ids[z0][x0] = n
            while pile:
                x, z = pile.pop()
                for (dx, dz) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    a, b = x + dx, z + dz
                    if not (0 <= a < l and 0 <= b < h) or ids[b][a] != -1:
                        continue
                    # l'arête qui sépare les deux tuiles : franchissable ou non
                    r = 2 * z + 1 + dz
                    c = 2 * x + 1 + dx
                    ligne = plan[r] if r < len(plan) else ''
                    ch = ligne[c] if c < len(ligne) else ' '
                    # Une PORTE sépare deux pièces autant qu'un mur : on ne
                    # traverse que là où il n'y a aucune arête.
                    if ch != ' ':
                        continue
                    if not plancher(plan, a + .5, b + .5):
                        continue
                    ids[b][a] = n
                    pile.append((a, b))
    return ids


def piece(ids, x, z):
    c, l = int(x // 1), int(z // 1)
    if l < 0 or c < 0 or l >= len(ids) or c >= len(ids[0]):
        return 0
    return ids[l][c]


def controler(id):
    f = cat[id]
    ms = murs(f['plan'])
    ids = pieces(f['plan'])
    meubles = f['meubles']
    grilles = [cases(m) for m in meubles]
    pb = [None] * len(meubles)

    # --- le passage des portes : un mètre vingt de dégagement de chaque côté
    portes = []
    for w in ms:
        if not w['porte']:
            continue
        if w['horiz']:
            portes.append((w['cx'] - 0.25, w['cx'] + 0.25, w['cz'] - 0.42, w['cz'] + 0.42))
        else:
            portes.append((w['cx'] - 0.42, w['cx'] + 0.42, w['cz'] - 0.25, w['cz'] + 0.25))

    for i, m in enumerate(meubles):
        nom = m['m']
        if PLAT.match(nom):
            continue
        gene = 0
        for (cle, (bas, haut)) in grilles[i].items():
            if haut - bas < 0.02 or haut < 0.12:
                continue                                   # trop plat pour gêner
            x, z = (cle[0] + 0.5) * MAILLE, (cle[1] + 0.5) * MAILLE
            for (x0, x1, z0, z1) in portes:
                if x0 <= x <= x1 and z0 <= z <= z1:
                    gene += 1
                    break
        if gene * MAILLE * MAILLE > 0.012:                 # ~5 % d'une tuile
            pb[i] = 'devant une porte'

    for i, m in enumerate(meubles):
        if pb[i]:
            continue
        nom = m['m']
        # --- hors du plancher
        if not plancher(f['plan'], m['x'], m['z']):
            pb[i] = 'hors du plancher'
            continue
        # --- dans un mur
        if mur_dedans(ms, m):
            pb[i] = 'entre dans un mur'
            continue
        # --- à cheval sur deux pièces : la façade dessert l'une, le corps est
        # dans l'autre. Invisible en vue de trois quarts, aberrant en jeu.
        if not PLAT.match(nom) and m.get('y', 0) < 0.10:
            nx, nz = NORMALE[m['r']]
            ori = piece(ids, m['x'] + nx * 0.15, m['z'] + nz * 0.15)
            if ori <= 0:                       # façade tournée vers l'extérieur
                ori = piece(ids, m['x'], m['z'])
            t = m.get('t', 1) or 1
            l, p = (m['p'] * t, m['l'] * t) if m['r'] % 2 else (m['l'] * t, m['p'] * t)
            for sx in (-1, 1):
                for sz in (-1, 1):
                    # un coin hors du plan est derrière un mur extérieur :
                    # `mur_dedans` s'en charge, pas ce contrôle-ci
                    q = piece(ids, m['x'] + sx * (l / 2 - 0.06),
                              m['z'] + sz * (p / 2 - 0.06))
                    if q > 0 and q != ori:
                        pb[i] = 'à cheval sur deux pièces'
                        break
                if pb[i]:
                    break
            if pb[i]:
                continue
        # --- regarde une cloison
        if FRONT.match(nom):
            t = m.get('t', 1) or 1
            prof = m['p'] * t
            nx, nz = NORMALE[m['r']]
            dx, dz = m['x'] + nx * (prof / 2 + 0.10), m['z'] + nz * (prof / 2 + 0.10)
            if dans(ms, dx, dz):
                pb[i] = 'regarde un mur'
            elif not plancher(f['plan'], dx, dz):
                pb[i] = 'regarde le vide'
            elif MURAL.match(nom):
                ax, az = m['x'] - nx * (prof / 2 + 0.02), m['z'] - nz * (prof / 2 + 0.02)
                if not dans(ms, ax, az, False) and plancher(f['plan'], ax, az):
                    pb[i] = 'pas accroché à un mur'

    # --- deux meubles qui s'interpénètrent
    plats = [m for m in meubles if PLANS.match(m['m'])]
    for i in range(len(meubles)):
        for j in range(i + 1, len(meubles)):
            a, b = meubles[i], meubles[j]
            if PLAT.match(a['m']) or PLAT.match(b['m']):
                continue
            commun = 0
            for cle, (ba, ha) in grilles[i].items():
                bb_hb = grilles[j].get(cle)
                if bb_hb is None:
                    continue
                bb, hb = bb_hb
                if ba >= hb - 0.03 or ha <= bb + 0.03:
                    continue                                # l'un est posé sur l'autre
                commun += 1
            if commun * MAILLE * MAILLE > 0.03:             # 12 cm de côté
                if not pb[i]: pb[i] = 'chevauche ' + b['m'].replace('n:', '')
                if not pb[j]: pb[j] = 'chevauche ' + a['m'].replace('n:', '')

    # --- le coffre doit être SEUL : collé à un placard, il en devient un
    for i, m in enumerate(meubles):
        if m['m'] != 'c:coffre' or pb[i]:
            continue
        V = int(0.30 / MAILLE)
        proches = set()
        for j, q in enumerate(meubles):
            if j == i or PLAT.match(q['m']) or q['m'].startswith('n:'):
                continue
            proches |= set(grilles[j].keys())
        trop = False
        for (cx, cz) in grilles[i]:
            for a in range(-V, V + 1):
                for b in range(-V, V + 1):
                    if (cx + a, cz + b) in proches:
                        trop = True
                        break
                if trop: break
            if trop: break
        if trop:
            pb[i] = 'trop collé au mobilier (il doit rester seul)'

    # --- un siège qui tourne le dos à sa table, un canapé à sa télé
    for i, m in enumerate(meubles):
        if pb[i]:
            continue
        nom = m['m']
        nx, nz = NORMALE[m['r']]
        cibles = None
        if ASSIS.match(nom) and plats:
            cibles = plats
        elif re.match(r'^lounge(Sofa|Chair|DesignSofa|DesignChair)', nom):
            cibles = [q for q in meubles if q['m'].startswith('television')]
        if not cibles:
            continue
        q = min(cibles, key=lambda q: (q['x'] - m['x']) ** 2 + (q['z'] - m['z']) ** 2)
        vx, vz = q['x'] - m['x'], q['z'] - m['z']
        d = math.hypot(vx, vz)
        if d < (1.5 if cibles is plats else 2.6) and vx * nx + vz * nz <= 0.02:
            pb[i] = 'tourne le dos à ' + q['m']
    return pb


total = 0
for id in ORDRE:
    f = cat[id]
    pb = controler(id)
    lignes = ['    [%2d] %-26s (%.2f, %.2f) r=%d→%s   %s'
              % (i, f['meubles'][i]['m'], f['meubles'][i]['x'], f['meubles'][i]['z'],
                 f['meubles'][i]['r'], CAPS[f['meubles'][i]['r']], p)
              for i, p in enumerate(pb) if p]
    total += len(lignes)
    print('== %-10s %2d' % (id, len(lignes)))
    if lignes:
        print('\n'.join(lignes))
print('TOTAL', total)
