#!/usr/bin/env python3
"""LES BRETELLES ET LES RAMPES DOUCES DE PIKSTOWN.

Deux pièces du kit ne se posaient nulle part parce que le dessin ne les
appelait jamais :

  - la COURBE LARGE (`road-curve*`), un virage de 2 x 2 cases qui entre par le
    milieu d'un côté et sort DEUX CASES PLUS LOIN. Aucun virage de rue ne
    ressemble à ça : c'est une bretelle, elle coupe un angle au lieu de le
    prendre. On la pose donc là où deux rues déjà tracées passent de part et
    d'autre d'un carré de terrain nu — le raccourci existe, il n'était pas
    dessiné. Effet de bord voulu : ça casse le damier, ce que le client
    demandait depuis le début.

  - la RAMPE DOUCE (`road-slant-curve`), deux cases pour monter deux paliers
    en s'adoucissant aux deux bouts. Partout où la ville faisait une marche de
    deux paliers d'un coup sur une rue droite, elle posait `road-slant-high` :
    la même montée en UNE case, c'est-à-dire un tremplin de garage. La rampe
    douce, c'est la même montée en deux cases.

Le script ne touche QUE des caractères isolés du dessin, jamais sa forme :
il écrit `(` sur le coin nord-ouest d'une bretelle, `#` sur son autre bout,
`/` sur la case basse d'une rampe. Relancé, il ne refait pas ce qu'il a fait.

    python3 outils/bretelles.py [--essai]
"""
import re, sys, math

FICHIER = "jeux/carnage/pikstown.gd"
ROUTE = set("#=O(/")
SOUPLE = set(",;o^'P")   # ⚠ `P` compte : dans la ville refondue, le parking EST le coeur d'îlot, et c'est la plus grande réserve de terrain souple du dessin
ECART_BRETELLES = 15      # cases entre deux bretelles : sinon ça fait un plat de nouilles

# quart de tour -> (case d'entrée, côté d'entrée, case de sortie, côté de sortie),
# les cases étant relatives au coin nord-ouest. Doit rester le jumeau exact de
# CarteVille.COURBE_BOUTS ; c'est la seule chose que les deux fichiers partagent.
BOUTS = {
    0: ((0, 0), (-1, 0), (1, 1), (0, 1)),
    1: ((0, 1), (0, 1), (1, 0), (1, 0)),
    2: ((1, 1), (1, 0), (0, 0), (0, -1)),
    3: ((1, 0), (0, -1), (0, 1), (-1, 0)),
}


def lire(src, nom):
    m = re.search(r"const %s: Array\[String\] = \[\n(.*?)\n\]" % nom, src, re.S)
    lignes = [l.strip().rstrip(",").strip('"') for l in m.group(1).split("\n")]
    return lignes, m.span(1)


def main():
    essai = "--essai" in sys.argv
    src = open(FICHIER, encoding="utf-8").read()
    plan, span = lire(src, "PLAN")
    relief, _ = lire(src, "RELIEF")
    H, W = len(plan), len(plan[0])
    grille = [list(l) for l in plan]

    def ch(i, j):
        return grille[j][i] if 0 <= i < W and 0 <= j < H else "."

    def rel(i, j):
        if not (0 <= i < W and 0 <= j < H):
            return -99
        c = relief[j][i]
        return int(c) if c.isdigit() else 0

    def droit(i, j, d):
        """La rue passe ici tout droit, dans l'axe de `d` ?"""
        vois = [v for v in ((0, -1), (1, 0), (0, 1), (-1, 0)) if ch(i + v[0], j + v[1]) in ROUTE]
        return len(vois) <= 2 and all(v[0] * d[0] + v[1] * d[1] != 0 for v in vois)

    def raccord_propre(a, dA, dd, dD, n):
        """Les deux bouts raccordent-ils SANS créer de marche au carrefour ?

        Une bretelle transforme une rue droite en T. La règle du plan interdit
        une marche au pied d'un croisement : une rue qui passait tout droit à
        cheval sur un cran devient fautive dès qu'on lui greffe un bras. On
        exige donc que TOUT le voisinage en rue des deux bouts soit au palier
        de la bretelle. Sans ça, sept bretelles sur soixante-huit sortaient un
        carrefour en marche d'escalier — invisible sur le dessin, criant en
        jeu.
        """
        for c, d in ((a, dA), (dd, dD)):
            v = (c[0] + d[0], c[1] + d[1])
            if ch(*v) not in ROUTE or rel(*v) != n:
                return False
            for w in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                u = (v[0] + w[0], v[1] + w[1])
                if ch(*u) in ROUTE and rel(*u) != n:
                    return False
        return True

    # ⚠ UNE GROSSE PIÈCE EN RÉSERVE D'AUTRES. `poser_piece` refuse une pièce
    # dont une seule case est déjà prise — et le rond-point, posé AVANT les
    # courbes, en mange neuf. Quatre bretelles tombaient sur l'emprise d'un
    # giratoire : le script les écrivait, le moteur les refusait en silence, et
    # seul le compte de pièces du vérificateur le disait.
    pris = set()          # cases déjà données à une pièce
    for j in range(H):
        for i in range(W):
            if ch(i, j) == "O":
                for a in (-1, 0, 1):
                    for b in (-1, 0, 1):
                        pris.add((i + a, j + b))
    rampes = 0

    # ------------------------------------------------- reprise d'une passe
    # Le script se relit : une bretelle déjà posée qui ne passerait plus la
    # règle est DÉFAITE, ses deux cases de chaussée rendues au terrain. C'est
    # ce qui rend le fichier réparable sans le régénérer en entier.
    defaites = 0
    gardees = []
    for j in range(H):
        for i in range(W):
            if ch(i, j) != "(":
                continue
            carre = [(i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)]
            niveaux = {rel(*c) for c in carre}
            bon = False
            # Une bretelle déjà écrite qui empiète sur un rond-point est aussi
            # fautive qu'une neuve : on la défait.
            if any(c in pris for c in carre):
                niveaux = {-1, -2}
            if len(niveaux) == 1:
                n = next(iter(niveaux))
                for q in range(4):
                    A, dA, D, dD = BOUTS[q]
                    a = (i + A[0], j + A[1]); dd = (i + D[0], j + D[1])
                    if raccord_propre(a, dA, dd, dD, n):
                        bon = True
                        break
            if bon:
                for c in carre:
                    pris.add(c)
                gardees.append((i, j))
                continue
            # On rend le terrain : le caractère souple des cases restées
            # intactes dit ce qu'il y avait là.
            reste = [ch(*c) for c in carre if ch(*c) in SOUPLE]
            fond = reste[0] if reste else ","
            for c in carre:
                if ch(*c) in "(#":
                    grille[c[1]][c[0]] = fond
            defaites += 1

    # ---------------------------------------------------------- rampes douces
    # On rend d'abord toutes les rampes à la rue ordinaire : le choix de
    # celles qu'on adoucit peut changer, et une rampe oubliée là où la règle
    # ne la veut plus est un caractère qu'on ne retrouve jamais à la main.
    for j in range(H):
        for i in range(W):
            if grille[j][i] == "/":
                grille[j][i] = "#"

    for j in range(H):
        for i in range(W):
            if ch(i, j) not in ROUTE:
                continue
            for d in ((1, 0), (0, 1), (-1, 0), (0, -1)):
                v = (i + d[0], j + d[1])
                if ch(*v) not in ROUTE or rel(*v) - rel(i, j) != 2:
                    continue
                if not droit(i, j, d) or not droit(v[0], v[1], d):
                    continue
                if (i, j) in pris or v in pris:
                    continue
                # ⚠ ON N'ADOUCIT PAS TOUT. `road-slant-high` monte les deux
                # paliers en UNE case : c'est raide, mais c'est la rampe d'une
                # rue étroite, et l'ôter partout revenait à ne plus jamais
                # poser deux modèles du kit. Une marche sur quatre reste raide,
                # tirée sur la CASE pour que le résultat ne bouge pas d'une
                # reconstruction à l'autre.
                if (i * 73856093 ^ j * 19349663) % 4 == 0:
                    continue
                grille[j][i] = "/"
                pris.add((i, j)); pris.add(v)
                rampes += 1
                break

    # ------------------------------------------------------------- bretelles
    # ⚠ ON RAMASSE D'ABORD, ON CHOISIT ENSUITE. Poser au fil du balayage
    # remplissait le nord de la ville et laissait le sud nu : le premier
    # candidat venu gagnait, et l'écart minimum interdisait tous ses voisins.
    candidats = []
    for j in range(1, H - 3):
        for i in range(1, W - 3):
            carre = [(i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)]
            if any(c in pris for c in carre):
                continue
            if not all(ch(*c) in SOUPLE for c in carre):
                continue
            niveaux = {rel(*c) for c in carre}
            if len(niveaux) != 1:
                continue
            n = niveaux.pop()
            for q in range(4):
                A, dA, D, dD = BOUTS[q]
                a = (i + A[0], j + A[1]); dd = (i + D[0], j + D[1])
                na = (a[0] + dA[0], a[1] + dA[1]); nd = (dd[0] + dD[0], dd[1] + dD[1])
                if ch(*na) not in ROUTE or ch(*nd) not in ROUTE:
                    continue
                if not raccord_propre(a, dA, dd, dD, n):
                    continue
                candidats.append((i, j, q, a, dd))
                break

    # ⚠ LES BRETELLES DU BORD DE MER PASSENT DEVANT. La glissière ne se pose
    # que sur une pièce qui SURPLOMBE ; sur soixante bretelles tirées au fil de
    # la ville, aucune ne touchait l'eau, et `road-curve-barrier` restait au
    # fond du kit. Une bretelle de corniche est de toute façon la plus jolie du
    # lot : elle coupe l'angle au-dessus du vide.
    # ⚠ « SURPLOMBER », C'EST L'EAU **OU** DEUX PALIERS DE VIDE — la même règle
    # que `Quartiers._surplombe`. Cherchée sur la seule eau, la bretelle de
    # corniche n'existait nulle part : les carrés de terrain nu du bord de mer
    # n'ont pas de rue aux deux bouts. Au bord d'une terrasse, il y en a.
    def au_bord(i, j):
        n = rel(i, j)
        for c in ((i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)):
            for d in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                u = (c[0] + d[0], c[1] + d[1])
                if ch(*u) in ".~" or rel(*u) <= n - 2:
                    return True
        return False

    # L'ordre de tri disperse : on passe la ville en damier grossier plutôt que
    # ligne par ligne, et l'écart minimum fait le reste.
    candidats.sort(key=lambda c: (0 if au_bord(c[0], c[1]) else 1,
                                  (c[0] % 7) * 7 + (c[1] % 7), c[1], c[0]))
    choisies = list(gardees)
    for i, j, q, a, dd in candidats:
        carre = [(i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)]
        if any(c in pris for c in carre):
            continue
        # ⚠ LA BRETELLE DE CORNICHE A DROIT D'ÊTRE PLUS PRÈS. L'écart de quinze
        # cases est là pour que la ville ne devienne pas un plat de nouilles ;
        # il n'a aucune raison de faire renoncer à la SEULE bretelle du dessin
        # qui surplombe quelque chose — celle dont dépendent
        # `road-curve-barrier` et `road-curve-intersection-barrier`.
        ecart = ECART_BRETELLES // 3 if au_bord(i, j) else ECART_BRETELLES
        if any(math.dist((i, j), c) < ecart for c in choisies):
            continue
        # ⚠ LE `(` S'ÉCRIT EN DERNIER. Le coin nord-ouest de la pièce EST le
        # bout de sortie pour un quart de tour sur quatre (`BOUTS[2]` a
        # D = (0,0)) : écrire le `(` puis les deux bouts remettait un `#`
        # par-dessus, et la bretelle disparaissait sans que rien ne le dise —
        # le compteur en annonçait une de plus que le dessin n'en portait, et
        # le vérificateur ne voyait rien puisqu'il compte les caractères.
        grille[dd[1]][dd[0]] = "#"
        grille[a[1]][a[0]] = "#"
        grille[j][i] = "("
        for c in carre:
            pris.add(c)
        choisies.append((i, j))

    print("rampes douces : %d    bretelles : %d (%d gardées, %d défaites)"
          % (rampes, len(choisies), len(gardees), defaites))
    if essai:
        return
    neuf = ",\n".join('\t"%s"' % "".join(l) for l in grille)
    open(FICHIER, "w", encoding="utf-8").write(src[:span[0]] + neuf + src[span[1]:])
    print("écrit dans " + FICHIER)


main()
