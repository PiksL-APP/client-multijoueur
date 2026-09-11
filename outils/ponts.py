#!/usr/bin/env python3
"""RACCORDER LES PONTS À LA RUE, ET DIRE CE QUI RESTE COUPÉ.

Le générateur a tracé douze ponts. Il les a fait traverser l'eau, mais il ne
les a jamais **raccordés** : sur la berge, le tablier s'arrête et il reste deux
à quatre cases de maisons et de pelouse entre lui et le premier carrefour. Vu
d'avion ça ne se remarque pas — le pont a l'air fini. En jeu, ça coupe la ville.

Mesuré avant : le réseau de voirie de Pikstown était en **onze morceaux**, dont
trois gros de 9 077, 4 569 et 4 078 cases — **tous sur la même île**. Un joueur
du centre ne pouvait pas rouler jusqu'au port. Il n'y a aucune recherche de
chemin dans ce jeu : une voiture qui bute tourne au hasard, une patrouille reste
plaquée contre la berge.

Le script prolonge chaque bout de pont DANS SON AXE jusqu'à la première case de
rue, en écrivant des `#`, puis recompte les morceaux. Il ne devine rien : il
suit la droite que le pont trace déjà.

    python3 outils/ponts.py [--essai]
"""
import re, sys
from collections import deque

FICHIER = "jeux/carnage/pikstown.gd"
ROUTE = set("#=O(/")
EAU = set(".~")
PORTEE = 8          # cases de berge qu'on accepte de percer pour rejoindre la rue
PONT_MAX = 34       # longueur maximale d'un pont d'île, en cases


def lire(src, nom):
    m = re.search(r"const %s: Array\[String\] = \[\n(.*?)\n\]" % nom, src, re.S)
    return [l.strip().rstrip(",").strip('"') for l in m.group(1).split("\n")], m.span(1)


def morceaux(grille, W, H):
    """Les composantes connexes de la voirie, de la plus grande à la plus petite."""
    vu = [[False] * W for _ in range(H)]
    out = []
    for j in range(H):
        for i in range(W):
            if grille[j][i] not in ROUTE or vu[j][i]:
                continue
            q = deque([(i, j)]); vu[j][i] = True; cells = []
            while q:
                x, y = q.popleft(); cells.append((x, y))
                for d in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                    a, b = x + d[0], y + d[1]
                    if 0 <= a < W and 0 <= b < H and not vu[b][a] and grille[b][a] in ROUTE:
                        vu[b][a] = True; q.append((a, b))
            out.append(cells)
    out.sort(key=len, reverse=True)
    return out


def main():
    essai = "--essai" in sys.argv
    src = open(FICHIER, encoding="utf-8").read()
    plan, span = lire(src, "PLAN")
    relief, span_r = lire(src, "RELIEF")
    H, W = len(plan), len(plan[0])
    g = [list(l) for l in plan]
    r = [list(l) for l in relief]

    def ch(i, j):
        return g[j][i] if 0 <= i < W and 0 <= j < H else "."

    avant = morceaux(g, W, H)
    print("avant : %d morceau(x) de voirie, le plus grand %d cases sur %d"
          % (len(avant), len(avant[0]), sum(len(c) for c in avant)))

    # ── les bouts de pont ────────────────────────────────────────────────
    # Un bout de pont est une case `=` dont le voisin, DANS L'AXE du pont, n'est
    # ni du pont ni de la rue. C'est là que le tablier s'arrête en l'air.
    perces = 0
    rejoints = 0
    for j in range(H):
        for i in range(W):
            if ch(i, j) != "=":
                continue
            for d in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                # L'AXE : le pont continue de l'autre côté. Sans cette garde on
                # percerait aussi les deux flancs du tablier, c'est-à-dire l'eau.
                if ch(i - d[0], j - d[1]) != "=":
                    continue
                a, b = i + d[0], j + d[1]
                if ch(a, b) in ROUTE:
                    continue
                # On avance dans l'axe jusqu'à la première rue.
                chemin = []
                k = 0
                while k < PORTEE:
                    c = ch(a, b)
                    if c in ROUTE:
                        break
                    if c in EAU:
                        # Le pont s'arrête AVANT la berge : on prolonge le
                        # tablier plutôt que de poser une rue sur l'eau.
                        chemin.append((a, b, "="))
                    else:
                        chemin.append((a, b, "#"))
                    a += d[0]; b += d[1]; k += 1
                else:
                    print("  ⚠ (%d,%d) : pas de rue à moins de %d cases dans l'axe %s"
                          % (i, j, PORTEE, d))
                    continue
                # Le palier de la berge qu'on rejoint : le raccord doit être de
                # plain-pied avec la rue, pas avec le tablier.
                niveau = r[b][a] if r[b][a].isdigit() else "0"
                for (x, y, quoi) in chemin:
                    g[y][x] = quoi
                    if quoi == "#":
                        r[y][x] = niveau
                perces += len(chemin)
                rejoints += 1

    print("percé %d case(s) de berge sur %d bout(s) de pont" % (perces, rejoints))

    # ── deuxième passe : RELIER LES ÎLES ─────────────────────────────────
    # Cinq îles satellites portent 150 à 330 cases de rue chacune — des
    # quartiers entiers, avec leurs immeubles et leurs services, où aucune
    # voiture ne pourra jamais aller. Dans GTA 2 les îles sont reliées ; ici
    # elles ne l'étaient pas, et ça ne se voyait pas sur une photo d'avion.
    #
    # ⚠ ON TIRE UN TRAIT DROIT, LE PLUS COURT. Chercher un joli tracé sur une
    # carte dessinée à la main, c'est inventer une route que le dessinateur n'a
    # pas voulue. Un pont droit se lit comme un pont ; une courbe cherchée se
    # lit comme une erreur.
    for tour in range(12):
        liste = morceaux(g, W, H)
        if len(liste) <= 1:
            break
        gros = set(liste[0])
        meilleur = None
        for c in liste[1:]:
            for (x, y) in c:
                for d in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                    a, b = x + d[0], y + d[1]
                    n = 0; eau = 0; trace = []
                    while 0 <= a < W and 0 <= b < H and n < PONT_MAX:
                        if (a, b) in gros:
                            if eau > 0 and (meilleur is None or n < meilleur[0]):
                                meilleur = (n, list(trace))
                            break
                        cc = g[b][a]
                        if cc in EAU:
                            eau += 1; trace.append((a, b, "="))
                        elif cc in ROUTE:
                            break          # une autre orpheline : on ne coud pas deux îles
                        else:
                            trace.append((a, b, "#"))
                        a += d[0]; b += d[1]; n += 1
        if meilleur is None:
            print("  ⚠ %d morceau(x) restent sans trait droit vers le réseau"
                  % (len(liste) - 1))
            break
        n, trace = meilleur
        for (x, y, quoi) in trace:
            g[y][x] = quoi
            # Un tablier est au niveau de la mer ; une case de berge prend le
            # palier de sa voisine de terre, sinon on pose une rue en l'air.
            if quoi == "=":
                r[y][x] = "0"
            else:
                autour = [r[y + dy][x + dx] for dx, dy in
                          ((0, -1), (1, 0), (0, 1), (-1, 0))
                          if 0 <= x + dx < W and 0 <= y + dy < H
                          and g[y + dy][x + dx] in ROUTE and g[y + dy][x + dx] != "="]
                r[y][x] = autour[0] if autour and autour[0].isdigit() else "0"
        print("  île reliée : pont de %d cases depuis (%d,%d)"
              % (len(trace), trace[0][0], trace[0][1]))

    apres = morceaux(g, W, H)
    print("après : %d morceau(x) de voirie, le plus grand %d cases sur %d (%.1f %%)"
          % (len(apres), len(apres[0]), sum(len(c) for c in apres),
             100.0 * len(apres[0]) / sum(len(c) for c in apres)))
    for c in apres[1:]:
        xs = [p[0] for p in c]; ys = [p[1] for p in c]
        print("   reste coupé : %4d cases autour de (%d,%d)"
              % (len(c), sum(xs) // len(xs), sum(ys) // len(ys)))
    if essai:
        return
    neuf = ",\n".join('\t"%s"' % "".join(l) for l in g)
    neuf_r = ",\n".join('\t"%s"' % "".join(l) for l in r)
    # ⚠ On réécrit le RELIEF d'abord : son emplacement dans le fichier est
    # APRÈS le plan, et remplacer le plan d'abord décalerait ses bornes.
    src = src[:span_r[0]] + neuf_r + src[span_r[1]:]
    src = src[:span[0]] + neuf + src[span[1]:]
    open(FICHIER, "w", encoding="utf-8").write(src)
    print("écrit dans " + FICHIER)


main()
