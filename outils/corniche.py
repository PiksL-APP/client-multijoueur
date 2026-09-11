#!/usr/bin/env python3
"""LA CORNICHE : LES BELVÉDÈRES, LES DÉPÔTS DE QUAI ET LES CHANTIERS.

Le client redemande la même chose depuis des séances : **tout le kit doit
servir**. L'inventaire répond par une liste de modèles jamais posés, et cette
liste a fini par se réduire à une seule famille : les **glissières de
sécurité**. Le kit en a une par pièce de chaussée ; le jeu n'en pose que là où
la rue SURPLOMBE quelque chose — la mer, ou deux paliers de vide. C'est la
bonne règle : une rambarde au milieu d'un quartier plat ne veut rien dire.

Restaient donc des glissières de pièces qui, dans Pikstown, ne se trouvaient
jamais au bord du vide. Ce n'est pas un défaut du code : c'est que la ville
n'avait aucune **corniche**. Ce script en dessine, et les glissières suivent.

    la raquette au bord de l'eau  →  road-end-round-barrier
    le quai de dépôt              →  road-side-entry-barrier, road-side-exit-barrier
    le chantier du bord de mer    →  road-straight-barrier-half
    le rond-point de la corniche  →  road-roundabout-barrier

Rien n'est inventé côté code : on écrit dans le DESSIN les mêmes caractères
qu'ailleurs, aux endroits où ils ont un sens. Un éperon de deux cases qui part
d'une rue et s'arrête au bord de l'eau EST une raquette panoramique ; un `X`
posé entre une rue de quai et la mer EST un dépôt de port.

⚠ LE PALIER NE BOUGE PAS. Chaque case écrite prend le palier de la rue d'où
part l'éperon : un éperon qui monte ou descend créerait une marche au pied d'un
carrefour, et `outils/verifier.gd` a raison de le refuser.

    python3 outils/corniche.py [--essai]
"""
import re, sys
from collections import deque

FICHIER = "jeux/carnage/pikstown.gd"
ROUTE = set("#=O(/")
EAU = set(".~")
LIBRE = set(",;o^'")             # ce qu'on s'autorise à percer : du terrain nu
ECART = 24                       # cases entre deux belvédères
BELVEDERES = 14
QUAIS = 6                        # dépôts de quai (moitié entrée, moitié sortie)
CHANTIERS = 4
COTES = ((0, -1), (1, 0), (0, 1), (-1, 0))


def lire(src, nom):
    m = re.search(r"const %s: Array\[String\] = \[\n(.*?)\n\]" % nom, src, re.S)
    return [l.strip().rstrip(",").strip('"') for l in m.group(1).split("\n")], m.span(1)


def ecrire(grille):
    return ",\n".join('\t"%s"' % l for l in grille)


class Ville:
    def __init__(self, plan, relief):
        self.p = [list(l) for l in plan]
        self.r = [list(l) for l in relief]
        self.H = len(self.p)
        self.W = len(self.p[0])

    def dedans(self, i, j):
        return 0 <= i < self.W and 0 <= j < self.H

    def car(self, i, j):
        return self.p[j][i] if self.dedans(i, j) else "."

    def palier(self, i, j):
        return self.r[j][i] if self.dedans(i, j) else "0"

    def eau(self, i, j):
        return not self.dedans(i, j) or self.car(i, j) in EAU

    def route(self, i, j):
        return self.dedans(i, j) and self.car(i, j) in ROUTE

    ## ⚠ UNE GROSSE PIÈCE OCCUPE PLUS QUE SON CARACTÈRE. Un `(` mange 2 x 2
    ## cases, un `O` en mange 3 x 3, une `/` deux cases dans l'axe : ces cases-
    ## là ne portent QUE la pièce, et le terrain nu qu'on y voit dans le dessin
    ## lui appartient déjà. Sans cette carte, la corniche écrivait ses éperons
    ## en plein milieu d'une bretelle — le vérificateur n'y voyait rien (le
    ## compte de pièces suivait) et la bretelle disparaissait en silence.
    def marquer_pieces(self):
        self.occupe = set()
        for j in range(self.H):
            for i in range(self.W):
                c = self.car(i, j)
                if c == "(":
                    for a in (0, 1):
                        for b in (0, 1):
                            self.occupe.add((i + a, j + b))
                elif c == "O":
                    for a in (-1, 0, 1):
                        for b in (-1, 0, 1):
                            self.occupe.add((i + a, j + b))
                elif c == "/":
                    for d in COTES:
                        self.occupe.add((i + d[0], j + d[1]))
                    self.occupe.add((i, j))

    def libre(self, i, j):
        return (self.dedans(i, j) and self.car(i, j) in LIBRE
                and (i, j) not in self.occupe)

    def voisins_rue(self, i, j):
        return [(i + d[0], j + d[1]) for d in COTES if self.route(i + d[0], j + d[1])]


# ──────────────────────────────────────────────────────── ce qui existe déjà

## ⚠ UN OUTIL QUI NE SE RELIT PAS EST UN OUTIL À UN COUP. Relancé, ce script
## redessinait quatorze belvédères DE PLUS, puis quatorze encore : au bout de
## trois passes la côte était un peigne. Chaque passe compte donc d'abord ce
## qu'elle a déjà posé, et ne complète que la différence — c'est ce qui rend le
## dessin réparable sans le régénérer.

def deja_belvederes(v):
    """Les raquettes de bord d'eau déjà dessinées, par leur case de départ."""
    out = []
    for j in range(v.H):
        for i in range(v.W):
            if not v.route(i, j):
                continue
            vr = v.voisins_rue(i, j)
            if len(vr) != 1:
                continue
            if not any(v.eau(i + d[0], j + d[1]) for d in COTES):
                continue
            out.append(vr[0])
    return out


def deja_marques(v, marque):
    """Les dépôts ou chantiers déjà posés au bord de l'eau."""
    n = 0
    for j in range(v.H):
        for i in range(v.W):
            if v.car(i, j) != marque:
                continue
            if any(v.route(i + d[0], j + d[1]) for d in COTES) \
                    and any(v.eau(i + 2 * d[0], j + 2 * d[1]) for d in COTES):
                n += 1
    return n


# ──────────────────────────────────────────────────────────── les belvédères

def belvederes(v, pris, deja=0):
    """Un éperon de deux cases, d'une rue jusqu'au bord de l'eau.

    La case du bout n'a qu'UNE voisine de rue : le pavage y pose donc
    `road-end-round`, la raquette de retournement. Et comme sa voisine d'en
    face est de l'eau, elle SURPLOMBE — d'où la glissière.
    """
    sites = []
    for j in range(v.H):
        for i in range(v.W):
            if not v.route(i, j):
                continue
            for dx, dy in COTES:
                cells = []
                for k in (1, 2):
                    a, b = i + dx * k, j + dy * k
                    if not v.libre(a, b) or v.palier(a, b) != v.palier(i, j):
                        cells = []
                        break
                    cells.append((a, b))
                if not cells or not v.eau(i + dx * 3, j + dy * 3):
                    continue
                # ⚠ UN ÉPERON NE LONGE PAS UNE AUTRE RUE. Collé à une rue
                # parallèle, le pavage y verrait un virage ou un T, plus une
                # impasse — et la raquette ne sortirait jamais.
                flanc = False
                for (x, y) in cells:
                    for ex, ey in COTES:
                        if (ex, ey) in ((dx, dy), (-dx, -dy)):
                            continue
                        if v.route(x + ex, y + ey):
                            flanc = True
                if flanc:
                    continue
                # ⚠ PAS DE MARCHE AU PIED D'UN CARREFOUR (règle 1 du vérificateur).
                # L'éperon ajoute une branche à sa case de départ. DEUX
                # branches suffisent à créer la faute : une rue droite qui
                # enjambait un cran devient, dès qu'on lui greffe un éperon
                # perpendiculaire, une case à voisines sur les deux axes — et
                # la marche n'est plus « selon l'axe ». La règle est donc :
                # TOUTES les voisines de rue de la case de départ, plus la case
                # elle-même, au même palier. Sans quoi le vérificateur sort
                # trois fautes qu'on met une heure à rattacher à cet éperon-ci.
                if any(v.palier(a, b) != v.palier(i, j)
                       for (a, b) in v.voisins_rue(i, j)):
                    continue
                sites.append((int(v.palier(i, j)), i, j, cells))
    # Les plus hautes d'abord : une rambarde au-dessus d'une falaise se voit,
    # au ras de l'eau elle se devine.
    sites.sort(key=lambda s: (-s[0], s[1] * 7919 + s[2] * 104729))
    poses = deja
    for _, i, j, cells in sites:
        if poses >= BELVEDERES:
            break
        if any(abs(i - x) + abs(j - y) < ECART for (x, y) in pris):
            continue
        for (a, b) in cells:
            v.p[b][a] = "#"
        pris.append((i, j))
        poses += 1
    return poses


# ──────────────────────────────────────────────────── les quais et chantiers

def quais(v, marque, combien, cote_voulu, deja=0):
    """Écrit `marque` entre une rue de bord de mer et la terre.

    La rue doit être DROITE (deux voisines de rue alignées) et avoir la mer
    d'un côté : c'est ce qui fait qu'elle surplombe. `road-side-entry` sort
    quand le dépôt est du côté +, `road-side-exit` quand il est du côté −.
    """
    poses, pris = deja, []
    for j in range(v.H):
        for i in range(v.W):
            if poses >= combien:
                return poses
            if not v.route(i, j) or v.car(i, j) != "#":
                continue
            vr = v.voisins_rue(i, j)
            if len(vr) != 2:
                continue
            selon_x = vr[0][1] == vr[1][1] == j
            if not selon_x and not (vr[0][0] == vr[1][0] == i):
                continue
            # `_droit_special` regarde le côté + (sud si la rue va selon X,
            # est sinon) puis le côté −. On veut la mer d'un côté, la marque
            # de l'autre, et c'est le côté de la marque qui choisit la pièce.
            d = (0, 1) if selon_x else (1, 0)
            plus = (i + d[0], j + d[1])
            moins = (i - d[0], j - d[1])
            cible, mer = (plus, moins) if cote_voulu > 0 else (moins, plus)
            if not v.eau(*mer) or not v.libre(*cible):
                continue
            if v.palier(*cible) != v.palier(i, j):
                continue
            if any(abs(i - x) + abs(j - y) < 12 for (x, y) in pris):
                continue
            v.p[cible[1]][cible[0]] = marque
            pris.append((i, j))
            poses += 1
    return poses


# ──────────────────────────────────────────────── le rond-point de la corniche

def surplombe(v, i, j, n):
    """La même règle que `Quartiers._surplombe` : l'eau, ou deux paliers de vide."""
    for dx, dy in COTES:
        a, b = i + dx, j + dy
        if v.eau(a, b) or int(v.palier(a, b)) <= n - 2:
            return True
    return False


def ronds_de_bord(v, combien=2):
    """Fait d'un carrefour de bord de terrasse un rond-point.

    ⚠ UN ROND-POINT NE SURPLOMBE JAMAIS DE LUI-MÊME. Le kit a
    `road-roundabout-barrier`, et Pikstown avait trente-deux ronds-points, tous
    au milieu d'un quartier plat. La pièce mange 3 x 3 cases de terre au même
    palier ; il suffit que ce carré de neuf touche un bord pour que la
    glissière tombe — encore fallait-il en dessiner un là.

    On écrit le centre en `O`, les quatre branches en `#` et les quatre coins
    en `o` : l'esplanade pavée, parce que `road-roundabout` est une pièce
    AJOURÉE — ses coins laissent voir le sol, et une pelouse sous un anneau de
    bitume se lit comme un trou.
    """
    poses, pris = 0, []
    for j in range(v.H):
        for i in range(v.W):
            if v.car(i, j) != "O":
                continue
            n = int(v.palier(i, j))
            if any(surplombe(v, i + a, j + b, n)
                   for a in (-1, 0, 1) for b in (-1, 0, 1)):
                poses += 1
                pris.append((i, j))
    for j in range(2, v.H - 2):
        for i in range(2, v.W - 2):
            if poses >= combien:
                return poses
            if v.car(i, j) != "#":
                continue
            n = int(v.palier(i, j))
            carre = [(i + a, j + b) for a in (-1, 0, 1) for b in (-1, 0, 1)]
            if any(not v.libre(*c) and v.car(*c) != "#" for c in carre):
                continue
            if any(int(v.palier(*c)) != n for c in carre):
                continue
            if not any(surplombe(v, c[0], c[1], n) for c in carre):
                continue
            # Il faut que deux branches OPPOSÉES arrivent au rond-point, sinon
            # c'est un giratoire au bout d'une impasse.
            bras = [d for d in COTES if v.route(i + d[0] * 2, j + d[1] * 2)]
            if not any((-d[0], -d[1]) in bras for d in bras):
                continue
            if any(abs(i - x) + abs(j - y) < 40 for (x, y) in pris):
                continue
            for a in (-1, 1):
                for b in (-1, 1):
                    v.p[j + b][i + a] = "o"
            for dx, dy in COTES:
                v.p[j + dy][i + dx] = "#"
            v.p[j][i] = "O"
            pris.append((i, j))
            poses += 1
    return poses


# ──────────────────────────────────────────────────────────── le contrôle

def morceaux(v):
    vu = [[False] * v.W for _ in range(v.H)]
    n = 0
    grand = 0
    for j in range(v.H):
        for i in range(v.W):
            if not v.route(i, j) or vu[j][i]:
                continue
            q = deque([(i, j)])
            vu[j][i] = True
            t = 0
            while q:
                x, y = q.popleft()
                t += 1
                for dx, dy in COTES:
                    a, b = x + dx, y + dy
                    if v.route(a, b) and not vu[b][a]:
                        vu[b][a] = True
                        q.append((a, b))
            n += 1
            grand = max(grand, t)
    return n, grand


def main():
    essai = "--essai" in sys.argv
    src = open(FICHIER, encoding="utf-8").read()
    plan, span = lire(src, "PLAN")
    relief, _ = lire(src, "RELIEF")
    v = Ville(plan, relief)
    v.marquer_pieces()

    avant = morceaux(v)
    pris = deja_belvederes(v)
    vieux_x = deja_marques(v, "X")
    vieux_p = deja_marques(v, "%")
    nb = belvederes(v, pris, len(pris))
    ne = quais(v, "X", QUAIS // 2, +1, vieux_x // 2)
    ns = quais(v, "X", QUAIS - QUAIS // 2, -1, vieux_x - vieux_x // 2)
    nc = quais(v, "%", CHANTIERS, +1, vieux_p)
    nr = ronds_de_bord(v)
    apres = morceaux(v)

    print("belvédères : %d    dépôts de quai : %d + %d    chantiers : %d"
          "    ronds-points de corniche : %d" % (nb, ne, ns, nc, nr))
    print("voirie : %d morceau(x) avant, %d après (le plus grand : %d cases)"
          % (avant[0], apres[0], apres[1]))
    if apres[0] > avant[0]:
        print("⚠ le réseau s'est fragmenté, rien n'est écrit")
        return 1
    if essai:
        print("(essai : rien n'est écrit)")
        return 0
    neuf = src[:span[0]] + ecrire(["".join(l) for l in v.p]) + src[span[1]:]
    open(FICHIER, "w", encoding="utf-8").write(neuf)
    print("écrit dans", FICHIER)
    return 0


if __name__ == "__main__":
    sys.exit(main())
