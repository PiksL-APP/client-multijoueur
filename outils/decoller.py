#!/usr/bin/env python3
"""Séparer ce qui se touche sans raison.

Le coffre ne devait pas fusionner avec un meuble ; la règle vaut pour le reste.
Une file de cuisine, un lit et sa table de chevet, une table et ses chaises,
un bar et ses tabourets, une télé sur son meuble : ces suites-là SE LISENT
comme un ensemble et ont le droit de se toucher. Une poubelle contre un meuble
télé, une bibliothèque contre une baignoire : non — ça se lit comme un seul
bloc informe.

On ne redessine pas les pièces : on écarte le moins ancré des deux (une
poubelle bouge, une baignoire non) du plus petit décalage qui résout le
contact SANS rien casser d'autre — mur, porte, chevauchement, orientation.
Le résultat s'imprime en `pose()` prêt à coller dans `interieurs.gd`.

    godot --headless --path . --script outils/vider.gd
    python3 outils/decoller.py
"""
import json, math, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verifier as V

cat, EMP = V.cat, V.EMP
M = V.MAILLE

# Familles : deux meubles de la même famille ont le droit de se toucher.
FAM = [('cuisine', r'^(kitchen(?!Bar)|hood|toaster)'),
       ('bar',     r'^(kitchenBar|stoolBar)'),
       ('lit',     r'^(bed|cabinetBed|pillow)'),
       ('repas',   r'^(table(?!Coffee|Round)|chair(?!Desk)|bench)'),
       ('bureau',  r'^(desk|deskCorner|chairDesk|computer|laptop)'),
       ('salon',   r'^(lounge|tableCoffee|tableRound|sideTable|television|cabinetTelevision|speaker|radio)'),
       ('poubelle', r'^trashcan'),
       ('rangement', r'^(bookcase|cardboard|coatRack)'),
       ('eau',     r'^(bathroom|bath|toilet|shower|washer|dryer)'),
       ('deco',    r'^(lamp|plant|potted|bear|books|ceilingFan|rug)'),
       ('coffre',  r'^c:')]

# Mobilité : qui cède le passage. Une baignoire est scellée, une poubelle non.
MOBILITE = [(r'^trashcan', 6), (r'^(cardboard|potted|plant)', 6),
            (r'^(sideTable|stool|chair|bench)', 5), (r'^coatRack', 5),
            (r'^bookcase', 4), (r'^(cabinetTelevision|television|speaker|radio)', 3),
            (r'^(lounge|tableCoffee|tableRound)', 3),
            (r'^(desk|table)', 2), (r'^(bed|cabinetBed)', 1),
            (r'^kitchen', 1), (r'^(bathroom|bath|toilet|shower|washer|dryer|hood)', 0),
            (r'^c:', 0)]


# Les voisinages qui se LISENT comme une suite voulue : une table poussée
# contre le plan de travail d'un studio, une bibliothèque à côté du bureau ou
# du meuble télé, un tabouret au bar. Tout le reste — et surtout la salle de
# bains ou la poubelle contre un meuble de séjour — fait un bloc informe.
ADMIS = {frozenset(p) for p in (('cuisine', 'repas'), ('cuisine', 'bar'),
         ('bar', 'repas'), ('bar', 'salon'), ('bureau', 'rangement'),
         ('salon', 'rangement'), ('bureau', 'salon'), ('lit', 'rangement'))}


def admis(a, b):
    return a == b or frozenset((a, b)) in ADMIS


def fam(n):
    n = n[2:] if n.startswith('n:') else n
    for f, r in FAM:
        if re.match(r, n):
            return f
    return 'autre'


def mob(n):
    for r, v in MOBILITE:
        if re.match(r, n):
            return v
    return 3


def touche(ga, gb, v=1):
    """Deux emprises se frôlent : cases voisines et hauteurs qui se croisent.
    `v` = 2 exige un vrai vide (16 cm de jeu) — c'est le critère d'acceptation,
    plus exigeant que la détection, pour que l'écart se VOIE."""
    for (cx, cz), (a0, a1) in ga.items():
        for dx in range(-v, v + 1):
            for dz in range(-v, v + 1):
                o = gb.get((cx + dx, cz + dz))
                if o and not (a0 >= o[1] - 0.03 or a1 <= o[0] + 0.03):
                    return True
    return False


def separes(ms, a, b):
    """Une cloison entre les deux : ils ne « se touchent » qu'à travers le mur.
    Sans ce test, une bibliothèque et une baignoire dos à dos de part et d'autre
    d'une paroi passent pour un bloc collé, alors qu'elles sont dans deux pièces."""
    n = 24
    for k in range(n + 1):
        x = a['x'] + (b['x'] - a['x']) * k / n
        z = a['z'] + (b['z'] - a['z']) * k / n
        if V.dans(ms, x, z):
            return True
    return False


def sert(ids, m):
    """La pièce que ce meuble DESSERT : on la lit devant sa façade, pas sous son
    centre — un meuble plaqué contre une cloison a le centre pile sur la limite,
    et on le croirait de l'autre côté."""
    nx, nz = V.NORMALE[m['r']]
    p = V.piece(ids, m['x'] + nx * 0.15, m['z'] + nz * 0.15)
    return p if p > 0 else V.piece(ids, m['x'], m['z'])


def tient(ids, m, ori):
    """Le meuble entier reste dans SA pièce : on teste les quatre coins, pas le
    seul centre. Une chaise de table qui aurait fini de traverser la cloison
    serait « d'un seul côté » et passerait, dans la chambre."""
    if sert(ids, m) != ori:
        return False
    t = m.get('t', 1) or 1
    l, p = (m['p'] * t, m['l'] * t) if m['r'] % 2 else (m['l'] * t, m['p'] * t)
    for sx in (-1, 1):
        for sz in (-1, 1):
            q = V.piece(ids, m['x'] + sx * (l / 2 - 0.06),
                        m['z'] + sz * (p / 2 - 0.06))
            if q > 0 and q != ori:
                return False
    return True


def libre(f, ms, portes, meubles, grilles, i, g, ids=None, ori=None):
    """Le meuble i, déplacé, tient-il encore la maison ?"""
    m = meubles[i]
    if not V.plancher(f['plan'], m['x'], m['z']):
        return False
    if ids is not None and not tient(ids, m, ori):
        return False
    # porte
    if not V.PLAT.match(m['m']):
        gene = 0
        for (cle, (bas, haut)) in g.items():
            if haut - bas < 0.02 or haut < 0.12:
                continue
            x, z = (cle[0] + 0.5) * M, (cle[1] + 0.5) * M
            for (x0, x1, z0, z1) in portes:
                if x0 <= x <= x1 and z0 <= z <= z1:
                    gene += 1
                    break
        if gene * M * M > 0.012:
            return False
    if V.mur_dedans(ms, m):
        return False
    t = m.get('t', 1) or 1
    # orientation : la façade doit rester sur la pièce
    if V.FRONT.match(m['m']):
        nx, nz = V.NORMALE[m['r']]
        prof = m['p'] * t
        dx, dz = m['x'] + nx * (prof / 2 + .10), m['z'] + nz * (prof / 2 + .10)
        if V.dans(ms, dx, dz) or not V.plancher(f['plan'], dx, dz):
            return False
        if V.MURAL.match(m['m']):
            ax, az = m['x'] - nx * (prof / 2 + .02), m['z'] - nz * (prof / 2 + .02)
            if not V.dans(ms, ax, az, False) and V.plancher(f['plan'], ax, az):
                return False
    # chevauchement + contact injustifié avec tout le reste
    for j, q in enumerate(meubles):
        if j == i or V.PLAT.match(q['m']) or V.PLAT.match(m['m']):
            continue
        commun = 0
        for cle, (ba, ha) in g.items():
            o = grilles[j].get(cle)
            if o and not (ba >= o[1] - .03 or ha <= o[0] + .03):
                commun += 1
        if commun * M * M > 0.03:
            return False
        if (not q['m'].startswith('n:') and not m['m'].startswith('n:')
                and fam(q['m']) != 'deco' and fam(m['m']) != 'deco'
                and not admis(fam(q['m']), fam(m['m']))
                and not separes(ms, m, q) and touche(g, grilles[j], 2)):
            return False
    # le coffre garde ses 60 cm : ne pas venir le coller
    for j, q in enumerate(meubles):
        if j == i or q['m'] != 'c:coffre':
            continue
        Vr = int(0.30 / M)
        for (cx, cz) in grilles[j]:
            for a in range(-Vr, Vr + 1):
                for b in range(-Vr, Vr + 1):
                    if (cx + a, cz + b) in g:
                        return False
    return True


def paires(meubles, grilles, ms):
    out = []
    for i in range(len(meubles)):
        if meubles[i]['m'].startswith('n:') or fam(meubles[i]['m']) == 'deco':
            continue
        for j in range(i + 1, len(meubles)):
            if meubles[j]['m'].startswith('n:') or fam(meubles[j]['m']) == 'deco':
                continue
            if separes(ms, meubles[i], meubles[j]):
                continue
            if admis(fam(meubles[i]['m']), fam(meubles[j]['m'])):
                continue
            if touche(grilles[i], grilles[j]):
                out.append((i, j))
    return out


PAS = 0.03
BORNE = 0.75
bouges = {}
reste = 0
for id in V.ORDRE:
    f = cat[id]
    meubles = f['meubles']
    ms = V.murs(f['plan'])
    portes = []
    for w in ms:
        if not w['porte']:
            continue
        if w['horiz']:
            portes.append((w['cx'] - .25, w['cx'] + .25, w['cz'] - .42, w['cz'] + .42))
        else:
            portes.append((w['cx'] - .42, w['cx'] + .42, w['cz'] - .25, w['cz'] + .25))
    grilles = [V.cases(m) for m in meubles]
    ids = V.pieces(f['plan'])
    faits, echecs = [], []
    for tour in range(12):
        p = paires(meubles, grilles, ms)
        seuls = [k for k in range(len(meubles)) if V.mur_dedans(ms, meubles[k])]
        if not p and not seuls:
            break
        if seuls and not p:
            i, j = seuls[0], seuls[0]
        else:
            i, j = p[0]
        # on écarte le plus mobile ; à mobilité égale, le plus petit
        if i != j and mob(meubles[j]['m']) > mob(meubles[i]['m']):
            i, j = j, i
        elif i != j and mob(meubles[j]['m']) == mob(meubles[i]['m']) and len(grilles[j]) < len(grilles[i]):
            i, j = j, i
        m = meubles[i]
        x0, z0 = m['x'], m['z']
        ori = sert(ids, m)
        essais = []
        n = int(BORNE / PAS)
        for k in range(1, n + 1):
            for (ux, uz) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                essais.append((ux * k * PAS, uz * k * PAS))
            for (ux, uz) in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
                essais.append((ux * k * PAS * .71, uz * k * PAS * .71))
        trouve = None
        for (dx, dz) in essais:
            m['x'], m['z'] = round(x0 + dx, 3), round(z0 + dz, 3)
            g = V.cases(m)
            if libre(f, ms, portes, meubles, grilles, i, g, ids, ori):
                trouve = (m['x'], m['z'], g)
                break
        if trouve:
            m['x'], m['z'], grilles[i] = trouve
            faits.append('    %-24s (%.2f,%.2f) -> (%.2f,%.2f)  [+%.0f cm]  (dégagé de %s)'
                         % (m['m'], x0, z0, m['x'], m['z'],
                            math.hypot(m['x'] - x0, m['z'] - z0) * 200,
                            'la cloison' if i == j else meubles[j]['m']))
            bouges.setdefault(id, []).append((i, m['m'], m['x'], m['z'], m['r'], m.get('y', 0), m.get('t', 1)))
        else:
            m['x'], m['z'] = x0, z0
            echecs.append('    !! %s / %s : pas de place' % (m['m'], meubles[j]['m']))
            break
    reste += len(echecs)
    print('== %-10s %d déplacés, %d bloqués' % (id, len(faits), len(echecs)))
    for l in faits + echecs:
        print(l)

print('\n--- à recopier dans interieurs.gd ---')
for id, lst in bouges.items():
    print('# %s' % id)
    for (i, nom, x, z, r, y, t) in lst:
        a = ['"%s"' % nom.replace('"', ''), '%.2f' % x, '%.2f' % z, '%d' % r]
        if y or (t and t != 1):
            a.append('%.2f' % y)
        if t and t != 1:
            a.append('%.2f' % t)
        print('    pose(%s),' % ', '.join(a))
json.dump({k: [list(v) for v in vs] for k, vs in bouges.items()},
          open(os.path.join(V.T, 'decolles.json'), 'w'), indent=1)
print('BLOQUÉS', reste)
