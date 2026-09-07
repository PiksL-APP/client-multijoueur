#!/usr/bin/env python3
"""Fabrique le hub en voxels : les modèles (glTF), le terrain et le plan.

    python3 outils/voxel.py

Tout est construit ici, cube par cube, à partir d'une palette : le terrain du
village, les maisons, les arbres, le mobilier, les habitants et les héros,
les pièces où l'on entre. Rien n'est découpé dans un dessin d'autrui — le
village est dessiné par ce script, qui est sa seule source.

Échelle : une case du plan fait 16 pixels dans la simulation (inchangée, les
positions réseau restent compatibles) et UNE unité dans le monde 3D. Un
modèle fin est bâti en voxels de 1/8 d'unité (un personnage fait seize
voxels de haut, deux unités) ; les arbres et le terrain en voxels plus gros.

Sortie : `modeles/voxel/*.glb` (maillages à couleurs par sommet, faces
plates) et `modeles/voxel/plan.json` (cases bloquées, objets posés, portes,
lumières…) que le moteur lit tel quel.
"""
import json
import math
import random
from pathlib import Path

import numpy as np
import trimesh

SORTIE = Path(__file__).resolve().parent.parent / "modeles" / "voxel"
SORTIE.mkdir(parents=True, exist_ok=True)
T = 16                      # pixels par case, dans la simulation
FIN = 1 / 8                 # taille d'un voxel fin, en unités (une case = 8 voxels)
GROS = 1 / 4                # taille d'un gros voxel (arbres, rochers)

# ------------------------------------------------------------------ palette
# Des teintes franches et chaudes, peu nombreuses : c'est ce qui fait qu'un
# monde en cubes reste lisible. Chaque teinte a une variante claire/sombre
# obtenue par `nuance`.
P = {
    "herbe": (98, 170, 74), "herbe2": (92, 162, 70), "herbe3": (104, 176, 78),
    "terre": (172, 128, 82), "terre2": (160, 118, 74),
    "pierre": (156, 148, 134), "pierre2": (150, 142, 128), "pierre3": (162, 154, 140),
    "brique": (128, 104, 92), "brique2": (118, 96, 84),
    "fond_mare": (58, 92, 112), "eau": (74, 146, 214),
    "falaise": (118, 106, 98), "falaise2": (104, 94, 86), "falaise3": (132, 120, 110),
    "tronc": (112, 74, 42), "tronc2": (96, 62, 34),
    "feuille": (72, 152, 62), "feuille2": (58, 132, 52), "feuille3": (96, 172, 70),
    "feuille_jaune": (206, 176, 54), "feuille_jaune2": (182, 152, 42),
    "feuille_rousse": (214, 116, 42), "feuille_rousse2": (188, 96, 34),
    "feuille_rouge": (176, 62, 44), "feuille_rouge2": (150, 50, 36),
    "pin": (44, 112, 74), "pin2": (36, 96, 62), "pin3": (56, 128, 86),
    "rocher": (128, 126, 122), "rocher2": (108, 106, 102), "rocher3": (148, 146, 140),
    "platre": (234, 222, 198), "poutre": (110, 74, 42), "rondin": (142, 98, 56), "rondin2": (124, 84, 48),
    "moellon": (142, 136, 126), "moellon2": (128, 122, 112),
    "toit_brun": (152, 82, 42), "toit_brun2": (134, 70, 36),
    "toit_vert": (62, 150, 118), "toit_vert2": (52, 130, 102),
    "toit_rouge": (172, 72, 52), "toit_rouge2": (150, 60, 44),
    "porte": (92, 60, 30), "cadre": (84, 56, 30), "vitre": (154, 204, 232), "vitre_nuit": (255, 214, 120),
    "cheminee": (120, 114, 108), "bois": (168, 118, 66), "bois2": (146, 100, 54), "bois_clair": (204, 160, 100),
    "fer": (92, 96, 104), "fer2": (70, 74, 82), "feu": (255, 150, 40), "braise": (220, 60, 20),
    "carotte": (232, 120, 40), "radis": (214, 56, 84), "chou": (120, 190, 90), "laitue": (150, 210, 90),
    "fleur_rouge": (226, 70, 70), "fleur_jaune": (244, 210, 70), "fleur_bleue": (90, 130, 230), "fleur_blanche": (240, 240, 236),
    "paille": (222, 190, 96), "sac": (196, 168, 118), "tissu": (222, 88, 76), "tissu2": (236, 232, 220),
    "peau": (240, 200, 162), "peau2": (222, 178, 138), "cheveux": (92, 60, 34), "cheveux2": (214, 170, 80), "cheveux3": (40, 32, 30),
    "acier": (176, 182, 192), "acier2": (140, 146, 156), "plume": (220, 60, 50), "or": (236, 196, 70),
    "capuche": (68, 96, 66), "capuche2": (52, 76, 50), "cuir": (128, 90, 56),
    "robe": (122, 70, 164), "robe2": (98, 54, 136), "etoile": (244, 214, 90),
    "robe_paysanne": (208, 126, 92), "tablier": (240, 234, 222), "robe_taverne": (96, 122, 176), "robe_auberge": (176, 96, 120),
    "os": (232, 228, 210), "os2": (200, 196, 180), "noir": (24, 22, 26), "blanc": (245, 245, 240),
    "plancher": (176, 128, 74), "plancher2": (160, 116, 66), "dalle": (150, 146, 140), "dalle2": (138, 134, 128),
    "mur_int": (222, 206, 178), "mur_int2": (206, 190, 164), "tapis": (150, 60, 60), "tapis2": (200, 170, 90),
    "drap": (236, 236, 228), "couverture": (176, 70, 66), "coussin": (90, 130, 90), "biere": (230, 180, 60),
    "lueur": (255, 180, 80),
}
P = {k: tuple(v) for k, v in P.items()}


def nuance(couleur, facteur):
    return tuple(max(0, min(255, int(round(c * facteur)))) for c in couleur)


def grainer(couleur, grain, hasard):
    """Trois teintes au plus par couleur (sombre, base, claire), tirées au
    hasard : assez pour casser l'aplat, assez peu pour que les faces
    voisines se fusionnent encore en grands rectangles."""
    if not grain or hasard is None:
        return couleur
    tirage = hasard.random()
    if tirage < 0.14:
        return nuance(couleur, 1.0 - grain)
    if tirage > 0.86:
        return nuance(couleur, 1.0 + grain)
    return couleur


# ------------------------------------------------------------------ voxels
class Modele:
    """Un nuage de voxels colorés, indexé par (x, y, z) en voxels entiers.
    y est vers le haut ; l'origine (0, 0, 0) est le point d'appui au sol,
    au centre du modèle en x et z."""

    def __init__(self, taille=FIN):
        self.v = {}
        self.taille = taille

    def poser(self, x, y, z, couleur):
        self.v[(int(x), int(y), int(z))] = couleur

    def boite(self, x0, y0, z0, x1, y1, z1, couleur, grain=0.0, hasard=None):
        """Un pavé plein, coins inclus ; `grain` fait varier la teinte."""
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    self.v[(x, y, z)] = grainer(couleur, grain, hasard)

    def creux(self, x0, y0, z0, x1, y1, z1):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    self.v.pop((x, y, z), None)

    def boule(self, cx, cy, cz, r, couleur, grain=0.0, hasard=None, aplat=1.0):
        """Une boule (aplatie en y par `aplat`), au grain près."""
        R = int(math.ceil(r)) + 1
        for x in range(int(cx) - R, int(cx) + R + 1):
            for y in range(int(cy) - R, int(cy) + R + 1):
                for z in range(int(cz) - R, int(cz) + R + 1):
                    dx, dy, dz = x + 0.5 - cx, (y + 0.5 - cy) / aplat, z + 0.5 - cz
                    if dx * dx + dy * dy + dz * dz <= r * r:
                        self.v[(x, y, z)] = grainer(couleur, grain, hasard)

    def cone(self, cx, y0, cz, r, hauteur, couleur, grain=0.0, hasard=None):
        for y in range(int(y0), int(y0 + hauteur)):
            ry = r * (1.0 - (y - y0) / hauteur)
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                for z in range(int(cz - r) - 1, int(cz + r) + 2):
                    if (x + 0.5 - cx) ** 2 + (z + 0.5 - cz) ** 2 <= ry * ry:
                        self.v[(x, y, z)] = grainer(couleur, grain, hasard)

    def fusion(self, autre, dx=0, dy=0, dz=0):
        for (x, y, z), c in autre.v.items():
            self.v[(x + dx, y + dy, z + dz)] = c

    def bornes(self):
        xs = [k[0] for k in self.v]
        ys = [k[1] for k in self.v]
        zs = [k[2] for k in self.v]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    # -------------------------------------------------- maillage
    def maillage(self, decalage=(0.0, 0.0, 0.0)):
        """Faces visibles seulement, fusionnées en rectangles par couleur
        (maillage glouton), en couleurs par sommet. Retourne un Trimesh."""
        if not self.v:
            return None
        (x0, y0, z0), (x1, y1, z1) = self.bornes()
        dims = (x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1)
        couleurs = {}
        index = {}
        grille = np.zeros(dims, dtype=np.int32)
        for (x, y, z), c in self.v.items():
            if c not in index:
                index[c] = len(index) + 1
                couleurs[index[c]] = c
            grille[x - x0, y - y0, z - z0] = index[c]
        sommets, faces, teintes = [], [], []
        s = self.taille

        def quad(points, couleur):
            b = len(sommets)
            sommets.extend(points)
            teintes.extend([couleur + (255,)] * 4)
            faces.append((b, b + 1, b + 2))
            faces.append((b, b + 2, b + 3))

        for d in range(3):
            u, w = [a for a in range(3) if a != d]      # les axes restants, dans l'ordre de la tranche
            for sens in (1, -1):
                for k in range(dims[d]):
                    # Masque des faces visibles dans cette tranche.
                    tranche = np.take(grille, k, axis=d)
                    voisin_k = k + sens
                    if 0 <= voisin_k < dims[d]:
                        voisin = np.take(grille, voisin_k, axis=d)
                        masque = np.where(voisin == 0, tranche, 0)
                    else:
                        masque = tranche.copy()
                    # Glouton : rectangles de même couleur.
                    n_u, n_w = masque.shape
                    for i in range(n_u):
                        j = 0
                        while j < n_w:
                            c = masque[i, j]
                            if c == 0:
                                j += 1
                                continue
                            largeur = 1
                            while j + largeur < n_w and masque[i, j + largeur] == c:
                                largeur += 1
                            hauteur = 1
                            while i + hauteur < n_u and all(masque[i + hauteur, j:j + largeur] == c):
                                hauteur += 1
                            masque[i:i + hauteur, j:j + largeur] = 0
                            # Les quatre coins, dans le repère (d, u, w).
                            kd = k + (1 if sens == 1 else 0)
                            coins = [(i, j), (i + hauteur, j), (i + hauteur, j + largeur), (i, j + largeur)]
                            # (u, w) tourne dans le sens direct autour de +d pour x et
                            # z, dans l'autre pour y : on inverse alors, et de même
                            # pour la face opposée.
                            if (sens == -1) != (d == 1):
                                coins.reverse()
                            points = []
                            for (a, b) in coins:
                                p = [0.0, 0.0, 0.0]
                                p[d] = kd
                                p[u] = a
                                p[w] = b
                                points.append(((p[0] + x0) * s + decalage[0], (p[1] + y0) * s + decalage[1], (p[2] + z0) * s + decalage[2]))
                            quad(points, couleurs[c])
                            j += largeur
        return trimesh.Trimesh(vertices=np.array(sommets, dtype=np.float32), faces=np.array(faces),
                               vertex_colors=np.array(teintes, dtype=np.uint8), process=False)


def centrer_xz(modele):
    """Ramène le modèle pour que son appui soit centré en x et z."""
    (x0, _, z0), (x1, _, z1) = modele.bornes()
    return -(x0 + x1 + 1) / 2 * modele.taille, -(z0 + z1 + 1) / 2 * modele.taille


ECRITS = []


def ecrire(nom, modele, centrer=True, decalage=None):
    """Un modèle → un glTF binaire, appui au sol centré."""
    d = decalage
    if d is None:
        dx, dz = centrer_xz(modele) if centrer else (0.0, 0.0)
        d = (dx, 0.0, dz)
    m = modele.maillage(d)
    m.export(SORTIE / f"{nom}.glb")
    ECRITS.append(nom)
    print(f"{nom:28s} {len(m.faces):6d} triangles")


def ecrire_parties(nom, parties):
    """Un modèle articulé : {nom_de_partie: (modele, pivot)} → un glTF dont
    chaque partie est un nœud nommé, placé à son pivot (le maillage est
    exprimé autour de ce pivot, pour tourner juste)."""
    scene = trimesh.Scene()
    total = 0
    for partie, (modele, pivot) in parties.items():
        px, py, pz = pivot
        m = modele.maillage((-px * modele.taille, -py * modele.taille, -pz * modele.taille))
        total += len(m.faces)
        transformation = np.eye(4)
        transformation[:3, 3] = (px * modele.taille, py * modele.taille, pz * modele.taille)
        scene.add_geometry(m, node_name=partie, geom_name=partie, transform=transformation)
    scene.export(SORTIE / f"{nom}.glb")
    ECRITS.append(nom)
    print(f"{nom:28s} {total:6d} triangles ({len(parties)} parties)")

# ------------------------------------------------------------------ végétation
hasard = random.Random(20260907)


def arbre_feuillu(couleurs, rayon=6.0, tronc=7, graine=0):
    """Un feuillu : tronc, trois boules de feuillage décalées, grain léger.
    En gros voxels (1/4 d'unité) : une cime de rayon 6 fait 3 unités."""
    h = random.Random(graine)
    m = Modele(GROS)
    m.boite(-1, 0, -1, 0, tronc, 0, P["tronc"], 0.1, h)
    haut = tronc
    m.boule(0, haut + rayon * 0.7, 0, rayon, couleurs[0], 0.1, h, aplat=0.85)
    m.boule(-rayon * 0.45, haut + rayon * 0.5, rayon * 0.3, rayon * 0.7, couleurs[1], 0.07, h)
    m.boule(rayon * 0.5, haut + rayon * 0.9, -rayon * 0.25, rayon * 0.65, couleurs[2], 0.07, h)
    m.boule(0.2, haut + rayon * 1.25, 0.3, rayon * 0.55, couleurs[2], 0.07, h)
    return m


def pin(couleurs, etages=3, base=5.0, tronc=4, graine=0):
    h = random.Random(graine)
    m = Modele(GROS)
    m.boite(-1, 0, -1, 0, tronc + etages * 3, 0, P["tronc2"], 0.05, h)
    y = tronc
    r = base
    for e in range(etages):
        m.cone(0, y, 0, r, 5, couleurs[e % len(couleurs)], 0.06, h)
        y += 3
        r *= 0.78
    m.cone(0, y, 0, max(1.5, r), 4, couleurs[0], 0.06, h)
    return m


def buisson(couleur, rayon=3.0, graine=0):
    h = random.Random(graine)
    m = Modele(GROS)
    m.boule(0, rayon * 0.6, 0, rayon, couleur, 0.08, h, aplat=0.75)
    m.boule(rayon * 0.6, rayon * 0.5, rayon * 0.4, rayon * 0.6, nuance(couleur, 1.1), 0.08, h, aplat=0.8)
    return m


def rocher(rayon=2.5, graine=0):
    h = random.Random(graine)
    m = Modele(GROS)
    m.boule(0, rayon * 0.35, 0, rayon, P["rocher"], 0.08, h, aplat=0.6)
    m.boule(rayon * 0.5, rayon * 0.45, -rayon * 0.3, rayon * 0.6, P["rocher3"], 0.08, h, aplat=0.7)
    return m


def fleur(couleur):
    m = Modele(FIN)
    m.poser(0, 0, 0, P["feuille2"])
    m.poser(0, 1, 0, P["feuille"])
    m.poser(0, 2, 0, couleur)
    m.poser(1, 2, 0, couleur)
    m.poser(-1, 2, 0, couleur)
    m.poser(0, 2, 1, couleur)
    m.poser(0, 2, -1, couleur)
    m.poser(0, 3, 0, P["fleur_jaune"] if couleur != P["fleur_jaune"] else P["fleur_rouge"])
    return m


def touffe():
    m = Modele(FIN)
    for (x, z, hh) in ((-1, 0, 2), (0, -1, 3), (1, 1, 2), (0, 1, 1), (1, -1, 1)):
        m.boite(x, 0, z, x, hh - 1, z, P["feuille3"])
    return m


for i, (a, b, c) in enumerate(((P["feuille"], P["feuille2"], P["feuille3"]),
                               (P["feuille_jaune"], P["feuille_jaune2"], P["feuille_jaune"]),
                               (P["feuille_rousse"], P["feuille_rousse2"], P["feuille_rousse"]),
                               (P["feuille_rouge"], P["feuille_rouge2"], P["feuille_rouge"]))):
    ecrire(f"arbre_{i}", arbre_feuillu((a, b, c), 6.0, 7, graine=i))
    ecrire(f"grand_arbre_{i}", arbre_feuillu((a, b, c), 8.5, 11, graine=10 + i))
    ecrire(f"petit_arbre_{i}", arbre_feuillu((a, b, c), 4.0, 4, graine=20 + i))
for i in range(3):
    ecrire(f"pin_{i}", pin((P["pin"], P["pin2"], P["pin3"]), 3, 5.0, 4, graine=30 + i))
    ecrire(f"grand_pin_{i}", pin((P["pin"], P["pin2"], P["pin3"]), 5, 6.5, 6, graine=40 + i))
for i, c in enumerate((P["feuille"], P["feuille3"], P["feuille_jaune"], P["feuille_rousse"])):
    ecrire(f"buisson_{i}", buisson(c, 3.2, graine=50 + i))
    ecrire(f"buisson_petit_{i}", buisson(c, 2.0, graine=60 + i))
ecrire("rocher_grand", rocher(3.2, graine=70))
ecrire("rocher_moyen", rocher(2.2, graine=71))
ecrire("rocher_petit", rocher(1.3, graine=72))
for i, c in enumerate((P["fleur_rouge"], P["fleur_jaune"], P["fleur_bleue"], P["fleur_blanche"])):
    ecrire(f"fleur_{i}", fleur(c))
ecrire("touffe", touffe())

# ------------------------------------------------------------------ maisons
# Un corps de 6 × 4 cases (48 × 32 voxels fins), murs de 18 voxels, pignon
# sur la façade sud (z positif : vers la caméra), toit à deux pans qui
# déborde d'un demi-voxel de case. La porte au milieu de la façade, une
# fenêtre de chaque côté, une souche de cheminée à droite pour celles qui
# en ont. Le plan retient les vitres (elles s'allument la nuit) et la
# cheminée (elle fume).
LARGEUR_MAISON, PROFONDEUR_MAISON, HAUT_MUR = 48, 32, 22
DETAILS = {}


def maison(nom, mur, toit, cheminee=True, grange=False):
    h = random.Random(hash(nom) % 1000)
    m = Modele(FIN)
    L, D, H = LARGEUR_MAISON, PROFONDEUR_MAISON, HAUT_MUR
    x0, x1 = -L // 2, L // 2 - 1
    z0, z1 = -D // 2, D // 2 - 1
    # Les murs, selon leur nature.
    if mur == "platre":
        m.boite(x0, 0, z0, x1, H - 1, z1, P["platre"])
        for x in (x0, x0 + 12, x0 + 24, x0 + 36, x1):        # colombages
            m.boite(x, 0, z0, x, H - 1, z0, P["poutre"])
            m.boite(x, 0, z1, x, H - 1, z1, P["poutre"])
        for z in (z0, z0 + 10, z0 + 21, z1):
            m.boite(x0, 0, z, x0, H - 1, z, P["poutre"])
            m.boite(x1, 0, z, x1, H - 1, z, P["poutre"])
        for y in (0, 11, H - 1):
            m.boite(x0, y, z0, x1, y, z0, P["poutre"])
            m.boite(x0, y, z1, x1, y, z1, P["poutre"])
            m.boite(x0, y, z0, x0, y, z1, P["poutre"])
            m.boite(x1, y, z0, x1, y, z1, P["poutre"])
    elif mur == "rondins":
        for y in range(H):
            c = P["rondin"] if y % 2 == 0 else P["rondin2"]
            m.boite(x0, y, z0, x1, y, z1, c)
        for x in (x0, x1):
            for z in (z0, z1):
                m.boite(x, 0, z, x, H, z, P["tronc2"])
    else:  # pierre
        for y in range(H):
            for x in range(x0, x1 + 1):
                for z in (z0, z1):
                    c = P["moellon"] if ((x // 3) + y) % 2 == 0 else P["moellon2"]
                    m.poser(x, y, z, grainer(c, 0.06, h))
            for z in range(z0, z1 + 1):
                for x in (x0, x1):
                    c = P["moellon"] if ((z // 3) + y) % 2 == 0 else P["moellon2"]
                    m.poser(x, y, z, grainer(c, 0.06, h))
        m.boite(x0 + 1, 0, z0 + 1, x1 - 1, H - 1, z1 - 1, P["moellon2"])
    # Le pignon : un triangle plein au-dessus de chaque façade nord et sud,
    # de la même matière que le mur.
    couleur_pignon = {"platre": P["platre"], "rondins": P["rondin"], "pierre": P["moellon"]}[mur]
    HP = L // 2 + 2
    for y in range(H, H + HP):
        retrait = y - H
        if x0 + retrait > x1 - retrait:
            break
        m.boite(x0 + retrait, y, z0, x1 - retrait, y, z1, couleur_pignon)
    if mur == "platre":
        for y in range(H, H + HP):
            retrait = y - H
            if x0 + retrait <= x1 - retrait:
                for z in (z0, z1):
                    m.poser(x0 + retrait, y, z, P["poutre"])
                    m.poser(x1 - retrait, y, z, P["poutre"])
                    if y % 6 == 0:
                        m.boite(x0 + retrait, y, z, x1 - retrait, y, z, P["poutre"])
    # Le toit : deux pans en escalier, qui débordent de 3 voxels de chaque
    # côté et de 3 devant/derrière, épais de 2.
    tuile, tuile2 = {"brun": (P["toit_brun"], P["toit_brun2"]), "vert": (P["toit_vert"], P["toit_vert2"]),
                     "rouge": (P["toit_rouge"], P["toit_rouge2"])}[toit]
    for y in range(H - 2, H + HP + 1):
        retrait = y - H
        xa, xb = x0 + retrait - 3, x1 - retrait + 3
        if xa > xb:
            break
        # Une rangée de tuiles sur six est plus sombre : le rythme des rangs.
        c = tuile2 if retrait % 6 == 3 else tuile
        for x in list(range(xa, min(xa + 3, xb + 1))) + list(range(max(xb - 2, xa), xb + 1)):
            m.boite(x, y, z0 - 3, x, y, z1 + 3, c)
    # Le faîte.
    for z in range(z0 - 3, z1 + 4):
        m.boite(-1, H + HP - 1, z, 0, H + HP, z, P["poutre"])
    # La porte, au milieu de la façade sud, et son encadrement.
    m.boite(-4, 0, z1, 3, 15, z1, P["cadre"])
    m.boite(-3, 0, z1, 2, 14, z1, P["porte"])
    m.boite(-3, 0, z1 + 1, 2, 14, z1 + 1, nuance(P["porte"], 0.9))
    m.boite(-3, 12, z1 + 1, 2, 13, z1 + 1, P["cadre"])
    m.poser(2, 7, z1 + 2, P["or"])
    # Les fenêtres : deux sur la façade, une sur chaque flanc ; vitre en
    # retrait d'un voxel, cadre en saillie.
    vitres = []
    if grange:
        for x in (-16, 12):
            m.boite(x, 9, z1, x + 4, 13, z1, P["cadre"])
            m.boite(x + 1, 10, z1, x + 3, 12, z1, P["noir"])
    else:
        for x in (-17, 11):
            m.boite(x, 8, z1, x + 6, 14, z1, P["cadre"])
            m.boite(x + 1, 9, z1, x + 5, 13, z1, P["vitre"])
            m.boite(x + 3, 9, z1, x + 3, 13, z1, P["cadre"])
            m.boite(x + 1, 11, z1, x + 5, 11, z1, P["cadre"])
            m.boite(x, 7, z1 + 1, x + 6, 7, z1 + 1, P["cadre"])   # l'appui
            vitres.append((x + 3.5, 11.5, z1 + 1))
        for z in (z0 + 8, z1 - 8):
            for x in (x0, x1):
                m.boite(x, 8, z - 3, x, 14, z + 3, P["cadre"])
                m.boite(x, 9, z - 2, x, 13, z + 2, P["vitre"])
                m.boite(x, 9, z, x, 13, z, P["cadre"])
    # La cheminée : une souche de pierre sur le flanc droit, qui dépasse du toit.
    fumee = None
    if cheminee:
        m.boite(x1 - 4, 0, -3, x1 + 2, H + HP + 3, 3, P["cheminee"])
        m.boite(x1 - 5, H + HP + 3, -4, x1 + 3, H + HP + 4, 4, nuance(P["cheminee"], 0.85))
        m.creux(x1 - 3, H + HP + 3, -2, x1 + 1, H + HP + 4, 2)
        fumee = ((x1 - 1) * FIN, (H + HP + 5) * FIN, 0.0)
    DETAILS[nom] = {"fenetres": [(x * FIN, y * FIN, z * FIN) for (x, y, z) in vitres], "fumee": fumee}
    ecrire(f"maison_{nom}", m, centrer=False)


maison("taverne", "platre", "brun")
maison("armurerie", "rondins", "vert")
maison("auberge", "pierre", "brun")
maison("maison", "platre", "vert")
maison("grange", "rondins", "rouge", cheminee=False, grange=True)

# ------------------------------------------------------------------ mobilier
# Tout en voxels fins. L'origine est au sol, au centre de l'emprise.
def banc():
    m = Modele()
    m.boite(-12, 3, -2, 11, 3, 1, P["bois"])                 # l'assise (3 unités)
    m.boite(-12, 4, -2, 11, 7, -2, P["bois2"])               # le dossier
    for x in (-11, 10):
        m.boite(x, 0, -2, x + 1, 2, 1, P["bois2"])
        m.boite(x, 4, -2, x + 1, 4, 1, P["bois2"])
    return m


def caisse(taille=6):
    m = Modele()
    h = taille
    m.boite(-h // 2, 0, -h // 2, h // 2 - 1, h - 1, h // 2 - 1, P["bois"])
    for y in (0, h - 1):
        m.boite(-h // 2, y, -h // 2, h // 2 - 1, y, h // 2 - 1, P["bois2"])
    for x in (-h // 2, h // 2 - 1):
        m.boite(x, 0, -h // 2, x, h - 1, -h // 2, P["bois2"])
        m.boite(x, 0, h // 2 - 1, x, h - 1, h // 2 - 1, P["bois2"])
    return m


def caisses():
    m = Modele()
    a = caisse(7)
    m.fusion(a, -4, 0, 0)
    m.fusion(a, 4, 0, 1)
    m.fusion(a, 0, 7, 0)
    return m


def cageot(legume):
    m = Modele()
    m.boite(-3, 0, -3, 2, 3, 2, P["bois_clair"])
    m.creux(-2, 2, -2, 1, 3, 1)
    m.boite(-2, 2, -2, 1, 3, 1, legume)
    for (x, z) in ((-2, -2), (0, -1), (1, 1), (-1, 1)):
        m.poser(x, 4, z, legume)
    return m


def cloture():
    """Un lé d'une case : deux poteaux, deux lisses. Tourné de 90° pour les côtés."""
    m = Modele()
    for x in (-4, 3):
        m.boite(x, 0, -1, x, 7, 0, P["bois2"])
    m.boite(-4, 2, 0, 3, 2, 0, P["bois"])
    m.boite(-4, 5, 0, 3, 5, 0, P["bois"])
    return m


def jardiniere():
    m = Modele()
    m.boite(-6, 0, -2, 5, 3, 1, P["bois2"])
    m.boite(-5, 3, -1, 4, 3, 0, P["terre2"])
    for i, (x, c) in enumerate(((-4, P["fleur_rouge"]), (-1, P["fleur_jaune"]), (2, P["fleur_bleue"]), (4, P["fleur_rouge"]))):
        m.boite(x, 4, 0, x, 5, 0, P["feuille"])
        m.poser(x, 6, 0, c)
        m.poser(x - 1, 6, 0, c)
        m.poser(x, 6, -1, c)
    return m


def epouvantail():
    m = Modele()
    m.boite(0, 0, 0, 0, 15, 0, P["bois2"])
    m.boite(-5, 11, 0, 5, 11, 0, P["bois2"])
    m.boite(-2, 6, -1, 2, 11, 1, P["tissu"])              # la veste
    m.boite(-5, 9, -1, -3, 11, 1, P["tissu"])
    m.boite(3, 9, -1, 5, 11, 1, P["tissu"])
    m.boite(-1, 3, -1, 1, 5, 1, P["paille"])
    m.boite(-2, 12, -2, 2, 15, 2, P["sac"])                # la tête
    m.poser(-1, 14, 3, P["noir"])
    m.poser(1, 14, 3, P["noir"])
    m.boite(-4, 16, -4, 4, 16, 4, P["paille"])             # le chapeau
    m.boite(-2, 17, -2, 2, 18, 2, P["paille"])
    return m


def culture(couleur, haut=3):
    m = Modele()
    for (x, z) in ((-2, -2), (1, -2), (-2, 1), (1, 1)):
        m.boite(x, 0, z, x + 1, haut - 1, z + 1, P["feuille"])
        m.boite(x, haut, z, x + 1, haut, z + 1, couleur)
    return m


def foyer():
    """Le foyer : un cercle de pierres, des bûches, des braises émissives."""
    m = Modele()
    for a in range(12):
        x = int(round(math.cos(a * math.pi / 6) * 6.5))
        z = int(round(math.sin(a * math.pi / 6) * 6.5))
        m.boite(x - 1, 0, z - 1, x, 1, z, P["rocher"] if a % 2 else P["rocher3"])
    m.boite(-4, 0, -1, 3, 1, 0, P["tronc"])
    m.boite(-1, 0, -4, 0, 1, 3, P["tronc2"])
    m.boite(-2, 1, -2, 1, 2, 1, P["braise"])
    return m


def forge():
    m = Modele()
    m.boite(-3, 0, -3, 2, 4, 2, P["tronc2"])               # la souche
    m.boite(-5, 5, -2, 4, 6, 1, P["fer2"])                 # l'enclume
    m.boite(-7, 6, -1, -5, 6, 0, P["fer"])
    m.boite(-4, 7, -2, 4, 7, 1, P["fer"])
    m.boite(5, 0, 5, 8, 1, 8, P["fer2"])                   # un seau
    return m


def fourneau():
    m = Modele()
    m.boite(-8, 0, -6, 7, 13, 5, P["cheminee"])
    m.boite(-7, 0, -5, 6, 12, 4, nuance(P["cheminee"], 0.9))
    m.boite(-3, 2, 5, 2, 6, 6, P["noir"])                  # la gueule
    m.boite(-2, 2, 5, 1, 3, 6, P["feu"])
    m.boite(-3, 14, -3, 2, 19, 2, P["cheminee"])           # le conduit
    m.creux(-2, 14, -2, 1, 19, 1)
    return m


def rotissoire():
    m = Modele()
    for x in (-8, 7):
        m.boite(x, 0, -1, x + 1, 11, 0, P["bois2"])
        m.boite(x - 1, 11, -2, x + 2, 12, 1, P["bois2"])
    m.boite(-8, 10, 0, 7, 10, 0, P["fer"])                 # la broche
    m.boite(-4, 7, -2, 3, 10, 2, P["tissu"])               # la pièce de viande
    m.boite(-3, 8, -3, 2, 9, 3, nuance(P["tissu"], 0.8))
    m.boite(-5, 0, -3, 4, 1, 3, P["rocher"])               # les pierres
    m.boite(-3, 1, -2, 2, 2, 2, P["braise"])
    return m


def scierie():
    m = Modele()
    for x in (-12, 8):
        m.boite(x, 0, -4, x + 2, 5, -3, P["bois2"])
        m.boite(x, 0, 2, x + 2, 5, 3, P["bois2"])
        m.boite(x, 5, -4, x + 2, 6, 3, P["bois"])
    m.boite(-14, 7, -2, 13, 10, 1, P["tronc"])             # le tronc à débiter
    m.boite(-14, 8, -2, 13, 9, 1, P["tronc2"])
    m.boite(0, 4, -6, 0, 13, 6, P["fer"])                  # la lame
    m.creux(0, 7, -2, 0, 10, 1)
    m.boite(-1, 4, -6, 1, 13, -6, P["fer2"])
    m.boite(16, 0, -6, 24, 3, 6, P["tronc"])               # des bûches empilées
    m.boite(17, 4, -5, 23, 6, 5, P["tronc2"])
    return m


def tableau():
    """Le tableau d'affichage : un panneau sombre sur deux poteaux ; le
    moteur écrit dessus."""
    m = Modele()
    for x in (-30, 27):
        m.boite(x, 0, -1, x + 2, 15, 0, P["bois2"])
    m.boite(-38, 8, 0, 37, 30, 0, P["bois2"])              # le cadre
    m.boite(-37, 9, 0, 36, 29, 0, P["noir"])
    m.boite(-38, 30, -1, 37, 31, 1, P["bois"])              # le chapeau
    return m


def etal():
    m = Modele()
    m.boite(-11, 5, -5, 10, 6, 4, P["bois"])               # la table
    m.boite(-11, 6, -5, 10, 6, 4, P["tissu2"])
    for x in (-11, 9):
        for z in (-5, 3):
            m.boite(x, 0, z, x + 1, 17, z + 1, P["bois2"])
    for i in range(-12, 12):                               # l'auvent rayé
        c = P["tissu"] if (i // 3) % 2 == 0 else P["tissu2"]
        m.boite(i, 18, -7, i, 18, 6, c)
    m.boite(-12, 17, 6, 11, 17, 6, P["tissu"])
    for (x, z, c) in ((-7, -2, P["carotte"]), (-2, 0, P["radis"]), (3, -2, P["chou"]), (7, 1, P["laitue"])):
        m.boite(x - 1, 7, z - 1, x + 1, 8, z + 1, c)
    return m


def lanterne():
    """Un réverbère de bois : un poteau, une potence, une lanterne de fer à
    vitres jaunes. Le moteur y accroche une lumière la nuit."""
    m = Modele()
    m.boite(-1, 0, -1, 0, 20, 0, P["bois2"])
    m.boite(-2, 0, -2, 1, 0, 1, P["rocher"])
    m.boite(-1, 20, -1, 4, 20, 0, P["bois2"])
    m.boite(3, 15, -2, 6, 19, 1, P["fer2"])                # la cage
    m.creux(4, 16, -1, 5, 18, 0)
    m.boite(4, 16, -1, 5, 18, 0, P["vitre_nuit"])
    m.boite(4, 14, -1, 5, 14, 0, P["fer2"])
    return m


ecrire("lanterne", lanterne())
ecrire("banc", banc())
ecrire("caisses", caisses())
for nom, c in (("carottes", P["carotte"]), ("radis", P["radis"]), ("choux", P["chou"]), ("laitues", P["laitue"])):
    ecrire(f"cageot_{nom}", cageot(c))
    ecrire(f"culture_{nom}", culture(c, 3 if nom in ("carottes", "radis") else 2))
ecrire("cloture", cloture())
ecrire("jardiniere", jardiniere())
ecrire("epouvantail", epouvantail())
ecrire("foyer", foyer())
ecrire("forge", forge())
ecrire("fourneau", fourneau())
ecrire("rotissoire", rotissoire())
ecrire("scierie", scierie())
ecrire("tableau", tableau())
ecrire("etal", etal())

# ------------------------------------------------------------------ l'arène
# L'île de la Bousculade : un disque de terre et d'herbe qui flotte, découpé
# en anneaux d'une unité pour qu'ils puissent s'effondrer un à un. Voxels
# d'une demi-unité : le bord est franc, le dessous en gradins.
RAYON_ARENE = 8


def anneau_arene(r_int, r_ext, graine=0):
    m = Modele(0.5)
    R = int(math.ceil(r_ext * 2))
    for x in range(-R, R):
        for z in range(-R, R):
            d = math.hypot(x + 0.5, z + 0.5) / 2.0
            if r_int <= d < r_ext:
                m.poser(x, -1, z, P["herbe"] if r_int % 2 == 0 else P["herbe2"])
                m.poser(x, -2, z, P["terre"])
                # Le dessous s'amincit vers le bord : une île qui flotte.
                fond = -3 - int((RAYON_ARENE - d) * 0.5)
                for y in range(fond, -2):
                    m.poser(x, y, z, P["falaise"] if y % 2 else P["falaise2"])
    return m


for i in range(RAYON_ARENE):
    ecrire(f"arene_{i}", anneau_arene(i, i + 1, graine=100 + i), centrer=False)
# Des îlots pour le lointain : un disque plein ; le moteur y plante un arbre.
for i, r in enumerate((2.5, 3.5, 2.0)):
    ecrire(f"ilot_{i}", anneau_arene(0, r, graine=200 + i), centrer=False)
# Un pavage de brique au centre, pour le point de départ.
centre_arene = Modele(0.5)
for x in range(-4, 4):
    for z in range(-4, 4):
        if math.hypot(x + 0.5, z + 0.5) < 3.8:
            centre_arene.poser(x, -1, z, P["brique"] if (x + z) % 2 else P["brique2"])
ecrire("arene_centre", centre_arene, centrer=False)

# ------------------------------------------------------------------ personnages
# Seize voxels de haut, six de large : jambes, corps, bras, tête, chacun un
# nœud à part pour que le moteur les balance en marchant. Le visage regarde
# vers +z (le sud, la caméra).
def personnage(peau, cheveux, haut, bas, coiffe=None, tenue=None):
    """`coiffe` et `tenue` sont des fonctions qui ajoutent casque, chapeau,
    tablier… `haut`/`bas` : couleurs du buste et des jambes (une robe se
    fait en donnant la même). Tout est en coordonnées absolues : le sol est
    y = 0, la tête va de 12 à 17 ; chaque partie a son pivot."""
    tete = Modele()
    tete.boite(-3, 12, -3, 2, 17, 2, peau)
    tete.boite(-3, 16, -3, 2, 17, 2, cheveux)              # le dessus des cheveux
    tete.boite(-3, 13, -3, 2, 17, -3, cheveux)             # la nuque
    tete.boite(-3, 15, -2, -3, 17, 2, cheveux)
    tete.boite(2, 15, -2, 2, 17, 2, cheveux)
    tete.poser(-2, 14, 2, P["noir"])                       # les yeux
    tete.poser(1, 14, 2, P["noir"])
    corps = Modele()
    corps.boite(-3, 6, -1, 2, 11, 1, haut)
    bras_g = Modele()
    bras_g.boite(-5, 6, -1, -4, 11, 0, haut)
    bras_g.boite(-5, 6, -1, -4, 7, 0, peau)
    bras_d = Modele()
    bras_d.boite(3, 6, -1, 4, 11, 0, haut)
    bras_d.boite(3, 6, -1, 4, 7, 0, peau)
    jambe_g = Modele()
    jambe_g.boite(-3, 0, -1, -1, 5, 1, bas)
    jambe_g.boite(-3, 0, -1, -1, 0, 1, P["cuir"])
    jambe_d = Modele()
    jambe_d.boite(0, 0, -1, 2, 5, 1, bas)
    jambe_d.boite(0, 0, -1, 2, 0, 1, P["cuir"])
    parties = {"tete": tete, "corps": corps, "bras_g": bras_g, "bras_d": bras_d, "jambe_g": jambe_g, "jambe_d": jambe_d}
    if coiffe:
        coiffe(tete)
    if tenue:
        tenue(parties)
    return {
        "jambe_g": (jambe_g, (-1.5, 6, 0.5)), "jambe_d": (jambe_d, (1.5, 6, 0.5)),
        "corps": (corps, (0, 6, 0.5)),
        "bras_g": (bras_g, (-4, 11.5, 0)), "bras_d": (bras_d, (4, 11.5, 0)),
        "tete": (tete, (0, 12, 0)),
    }


def casque(tete):
    tete.boite(-3, 12, -3, 2, 18, 2, P["acier"])
    tete.boite(-3, 14, 2, 2, 14, 2, P["noir"])             # la fente du heaume
    tete.boite(-2, 13, 3, 1, 13, 3, P["acier2"])
    tete.boite(0, 18, -3, 0, 20, 1, P["plume"])            # le cimier
    tete.boite(0, 21, -3, 0, 21, -1, P["plume"])


def capuche(tete):
    tete.boite(-4, 12, -4, 3, 18, 2, P["capuche"])
    tete.creux(-2, 12, 2, 1, 15, 2)                        # l'ouverture sur le visage
    tete.boite(-2, 12, 2, 1, 13, 2, P["capuche2"])         # le masque
    tete.poser(-2, 14, 2, P["noir"])
    tete.poser(1, 14, 2, P["noir"])


def chapeau_pointu(tete):
    tete.boite(-3, 12, 2, 2, 13, 2, P["blanc"])            # la barbe
    tete.boite(-2, 12, 3, 1, 12, 3, P["blanc"])
    tete.poser(-2, 14, 2, P["noir"])
    tete.poser(1, 14, 2, P["noir"])
    tete.boite(-5, 17, -5, 4, 17, 4, P["robe"])            # le bord du chapeau
    tete.boite(-3, 18, -3, 2, 19, 2, P["robe2"])
    tete.boite(-2, 20, -2, 1, 21, 1, P["robe"])
    tete.boite(-1, 22, -1, 0, 23, 0, P["robe2"])
    tete.poser(0, 24, 0, P["etoile"])
    tete.poser(-2, 18, 2, P["etoile"])
    tete.poser(1, 20, 1, P["etoile"])


def chignon(couleur):
    def f(tete):
        tete.boite(-1, 17, -4, 0, 18, -3, couleur)
    return f


def crane(tete):
    tete.boite(-3, 12, -3, 2, 17, 2, P["os"])
    tete.boite(-2, 14, 2, -2, 15, 2, P["noir"])
    tete.boite(1, 14, 2, 1, 15, 2, P["noir"])
    tete.boite(-1, 12, 2, 0, 12, 2, P["os2"])


def epee(parties):
    b = parties["bras_d"]
    b.boite(4, 5, 1, 4, 6, 1, P["cuir"])                   # la poignée
    b.boite(3, 7, 1, 5, 7, 1, P["or"])
    b.boite(4, 8, 1, 4, 18, 1, P["acier"])                 # la lame, dressée


def baton(parties):
    b = parties["bras_g"]
    b.boite(-5, 4, 1, -5, 21, 1, P["tronc"])
    b.boite(-6, 21, 0, -4, 23, 2, P["etoile"])


def tablier(parties):
    parties["corps"].boite(-2, 6, 2, 1, 10, 2, P["tablier"])
    parties["jambe_g"].boite(-3, 3, 2, -1, 5, 2, P["tablier"])
    parties["jambe_d"].boite(0, 3, 2, 2, 5, 2, P["tablier"])


def plateau(parties):
    b = parties["bras_g"]
    b.creux(-5, 6, -1, -4, 8, 0)
    b.boite(-5, 9, 1, -4, 9, 3, P["peau"])                 # l'avant-bras levé
    b.boite(-7, 10, 2, -2, 10, 4, P["bois"])               # le plateau
    b.boite(-6, 11, 3, -5, 12, 3, P["biere"])
    b.boite(-3, 11, 3, -3, 12, 3, P["biere"])


def cotte(parties):
    c = parties["corps"]
    c.boite(-3, 6, -1, 2, 11, 1, P["acier"])
    c.boite(-3, 11, -1, 2, 11, 1, P["acier2"])
    c.boite(-1, 8, 2, 0, 10, 2, P["plume"])                # le tabard


def cape(parties):
    parties["corps"].boite(-3, 6, -2, 2, 11, -2, P["capuche2"])
    parties["bras_d"].boite(4, 4, 1, 4, 6, 1, P["acier"])  # la dague


ecrire_parties("heros_knight", personnage(P["peau"], P["cheveux"], P["acier"], P["fer2"], casque, lambda p: (cotte(p), epee(p))))
ecrire_parties("heros_rogue", personnage(P["peau2"], P["cheveux3"], P["capuche"], P["cuir"], capuche, cape))
ecrire_parties("heros_wizzard", personnage(P["peau"], P["blanc"], P["robe"], P["robe2"], chapeau_pointu, baton))
ecrire_parties("pnj_paysanne", personnage(P["peau"], P["cheveux2"], P["robe_paysanne"], P["robe_paysanne"], chignon(P["cheveux2"]), tablier))
ecrire_parties("pnj_taverniere", personnage(P["peau"], P["cheveux"], P["robe_taverne"], P["robe_taverne"], chignon(P["cheveux"]), tablier))
ecrire_parties("pnj_aubergiste", personnage(P["peau2"], P["cheveux3"], P["robe_auberge"], P["robe_auberge"], chignon(P["cheveux3"]), tablier))
ecrire_parties("pnj_serveuse", personnage(P["peau"], P["cheveux2"], P["robe_taverne"], P["robe_taverne"], None, lambda p: (tablier(p), plateau(p))))
ecrire_parties("pnj_squelette", personnage(P["os"], P["os"], P["os2"], P["os2"], crane))

# ------------------------------------------------------------------ le plan
# Le village est dessiné sur une grille de cases (16 pixels dans la
# simulation, une unité dans le monde). Le même plan produit le terrain, la
# liste des objets à poser et la carte des cases bloquées : ce qu'on voit et
# ce qui arrête le joueur sortent de la même source.
LARGEUR, HAUTEUR = 64, 52
FALAISE = 5                          # rangées du plateau nord (hauteur 3)
CLAIRIERE = (5, 8, 59, 47)           # x0, y0, x1, y1 exclusif : au-delà, la forêt

terrain = {}                          # (x, y) -> nom de matière du sol
hauteur = {}                          # (x, y) -> hauteur du sol en unités


def zone(nom, x0, y0, x1, y1, h=None):
    for y in range(y0, y1):
        for x in range(x0, x1):
            terrain[(x, y)] = nom
            if h is not None:
                hauteur[(x, y)] = h


for y in range(HAUTEUR):
    for x in range(LARGEUR):
        terrain[(x, y)] = "herbe"
        hauteur[(x, y)] = 0.0
zone("herbe", 0, 0, LARGEUR, 2, 3.5)                       # le haut du plateau
zone("herbe", 0, 2, LARGEUR, FALAISE, 3.0)
zone("pierre", 16, 24, 48, 34)                              # l'esplanade
zone("brique", 28, 26, 36, 32)                              # le rond-point du feu
zone("terre", 30, 34, 34, HAUTEUR)                          # la grand-rue vers le sud
zone("terre", 10, 20, 12, 28)                               # le sentier de la maison de l'ouest
zone("terre", 10, 26, 16, 28)
zone("terre", 51, 20, 53, 26)                               # le sentier de la grange
zone("terre", 48, 24, 53, 26)
MARE = (8, 37, 8, 7)
for j in range(MARE[3]):
    retrait = {0: 2, 1: 1, 5: 1, 6: 2}.get(j, 0)
    for i in range(retrait, MARE[2] - retrait):
        terrain[(MARE[0] + i, MARE[1] + j)] = "eau"
        hauteur[(MARE[0] + i, MARE[1] + j)] = -1.0

COULEURS_SOL = {
    "herbe": (P["herbe"], P["herbe2"], P["herbe3"]),
    "pierre": (P["pierre"], P["pierre2"], P["pierre3"]),
    "brique": (P["brique"], P["brique2"], P["brique"]),
    "terre": (P["terre"], P["terre2"], P["terre"]),
    "eau": (P["fond_mare"], P["fond_mare"], P["fond_mare"]),
}


def maillage_terrain():
    """Le sol en blocs d'une demi-unité : le dessus de chaque case à sa
    hauteur, et les flancs là où la hauteur change (la falaise, la mare)."""
    h = random.Random(3)
    m = Modele(0.5)
    for (x, y), nom in terrain.items():
        alt = hauteur[(x, y)]
        haut = int(round(alt * 2))            # en demi-unités
        teintes = COULEURS_SOL[nom]
        for i in range(2):
            for j in range(2):
                r = h.random()
                c = teintes[0] if r < 0.6 else (teintes[1] if r < 0.8 else teintes[2])
                m.poser(x * 2 + i, haut - 1, y * 2 + j, c)
                # Sous la surface : la roche de la falaise, la vase de la mare.
                if haut > 0:
                    for k in range(0, haut - 1):
                        r2 = h.random()
                        cf = P["falaise"] if r2 < 0.6 else (P["falaise2"] if r2 < 0.85 else P["falaise3"])
                        m.poser(x * 2 + i, k, y * 2 + j, cf)
                elif haut < 0:
                    for k in range(haut - 1, -1):
                        m.poser(x * 2 + i, k, y * 2 + j, P["falaise2"])
    return m


# -------------------------------------------------- les objets
# Chaque modèle : son emprise au sol (largeur, profondeur en cases, centrée
# sur son origine) et les cases qu'il bloque. Un arbre ne bloque que son
# tronc ; sa cime est en l'air.
MODELES = {}


def declarer(nom, largeur, profondeur, bloque=True, marge=0):
    """`marge` : cases libres exigées autour (la cime d'un arbre)."""
    MODELES[nom] = {"l": largeur, "p": profondeur, "bloque": bloque, "marge": marge}


for i in range(4):
    declarer(f"arbre_{i}", 1, 1, marge=1)
    declarer(f"grand_arbre_{i}", 1, 1, marge=2)
    declarer(f"petit_arbre_{i}", 1, 1, marge=1)
    declarer(f"buisson_{i}", 2, 2)
    declarer(f"buisson_petit_{i}", 1, 1)
    declarer(f"fleur_{i}", 1, 1, bloque=False)
for i in range(3):
    declarer(f"pin_{i}", 1, 1, marge=1)
    declarer(f"grand_pin_{i}", 1, 1, marge=2)
declarer("touffe", 1, 1, bloque=False)
declarer("rocher_grand", 2, 2)
declarer("rocher_moyen", 1, 1)
declarer("rocher_petit", 1, 1, bloque=False)
declarer("banc", 3, 1)
declarer("caisses", 2, 2)
for nom in ("carottes", "radis", "choux", "laitues"):
    declarer(f"cageot_{nom}", 1, 1)
    declarer(f"culture_{nom}", 1, 1)
declarer("cloture", 1, 1)
declarer("jardiniere", 2, 1)
declarer("epouvantail", 1, 1)
declarer("foyer", 2, 2)
declarer("forge", 2, 2)
declarer("fourneau", 2, 2)
declarer("rotissoire", 3, 1)
declarer("scierie", 6, 2)
declarer("tableau", 10, 1)
declarer("etal", 3, 2)
for nom in ("taverne", "armurerie", "auberge", "maison", "grange"):
    declarer(f"maison_{nom}", 6, 4)

objets = []
bloque = set()
occupe = set()


def cases_de(nom, cx, cy):
    """Les cases couvertes par un modèle dont l'origine est au centre de la
    case (cx, cy) — pour une emprise paire, l'origine est sur un coin."""
    l, p = MODELES[nom]["l"], MODELES[nom]["p"]
    x0 = cx - (l - 1) // 2
    y0 = cy - (p - 1) // 2
    return [(x0 + i, y0 + j) for j in range(p) for i in range(l)]


def origine_px(nom, cx, cy):
    """Le point d'appui du modèle, en pixels : le centre de son emprise."""
    cases = cases_de(nom, cx, cy)
    xs = [c[0] for c in cases]
    ys = [c[1] for c in cases]
    return ((min(xs) + max(xs) + 1) * T / 2, (min(ys) + max(ys) + 1) * T / 2)


def libre(nom, cx, cy):
    marge = MODELES[nom]["marge"]
    cases = cases_de(nom, cx, cy)
    if not all(0 <= x < LARGEUR and 0 <= y < HAUTEUR for (x, y) in cases):
        return False
    for (x, y) in cases:
        for dx in range(-marge, marge + 1):
            for dy in range(-marge, marge + 1):
                if (x + dx, y + dy) in occupe:
                    return False
    return True


def poser(nom, cx, cy, rot=0):
    px, py = origine_px(nom, cx, cy)
    objets.append({"modele": nom, "x": px, "y": py, "rot": rot, "h": hauteur.get((cx, cy), 0.0)})
    for c in cases_de(nom, cx, cy):
        occupe.add(c)
        if MODELES[nom]["bloque"]:
            bloque.add(c)


def cloture(x0, y0, x1, y1, ouvertures=()):
    for x in range(x0, x1 + 1):
        for y in (y0, y1):
            if (x, y) not in ouvertures:
                poser("cloture", x, y, 0)
    for y in range(y0 + 1, y1):
        for x in (x0, x1):
            if (x, y) not in ouvertures:
                poser("cloture", x, y, 90)


# Les maisons : (nom, case du coin haut-gauche de leur ancien gabarit de
# 8 × 8) — le corps occupe les colonnes 1..6 et les rangées 4..7 ; la porte
# donne sur la rangée 8, au milieu.
MAISONS = [("armurerie", 17, 16), ("taverne", 28, 16), ("auberge", 39, 16), ("maison", 7, 12), ("grange", 48, 12)]
portes = []
fenetres = []
fumees = []
for nom, X, Y in MAISONS:
    cx, cy = X + 3, Y + 5            # emprise 6 × 4 : origine sur le coin, ici (X+4, Y+6)
    poser(f"maison_{nom}", cx, cy)
    px, py = origine_px(f"maison_{nom}", cx, cy)
    portes.append({"lieu": nom, "nom": nom.upper(), "x": (X + 3) * T, "y": (Y + 8) * T, "l": 2 * T, "h": T})
    d = DETAILS[nom]
    for (fx, fy, fz) in d["fenetres"]:
        fenetres.append([px / T + fx, fy, py / T + fz])
    if d["fumee"]:
        fumees.append([px / T + d["fumee"][0], d["fumee"][1], py / T + d["fumee"][2]])

# Le cœur de l'esplanade : le feu, deux bancs, le marché.
poser("foyer", 31, 28)
FEU = (32 * T, 29 * T)
poser("banc", 24, 28)
poser("banc", 37, 28)
poser("caisses", 36, 24)
for i, nom in enumerate(("carottes", "radis", "choux", "laitues")):
    poser(f"cageot_{nom}", 38 + i, 23)
poser("etal", 43, 24)
poser("forge", 14, 22)
poser("fourneau", 13, 19)
poser("jardiniere", 27, 23)
poser("jardiniere", 34, 23)
poser("rotissoire", 23, 22)
poser("scierie", 55, 21)
# Des réverbères aux coins de la place et le long de la grand-rue : ils
# s'allument à la nuit.
declarer("lanterne", 1, 1)
LANTERNES = [(17, 25), (46, 25), (17, 33), (29, 36), (35, 36), (29, 44), (35, 44)]
for (x, y) in LANTERNES:
    poser("lanterne", x, y)
# Le tableau d'affichage : dix cases de large, au sud-est de la place.
poser("tableau", 42, 33)
TABLEAU = (42.5, 33.5)               # centre du panneau, en cases
# Le potager de la grange : un enclos, des rangs de cultures, l'épouvantail.
cloture(49, 27, 58, 34, ouvertures={(51, 27), (52, 27)})
for i, nom in enumerate(("carottes", "radis", "choux", "laitues")):
    for x in range(50, 57):
        poser(f"culture_{nom}", x, 29 + i)
poser("epouvantail", 47, 29)
# Le jardin de la maison de l'ouest.
cloture(5, 29, 13, 35, ouvertures={(10, 29), (11, 29)})
for (x, y) in ((6, 30), (9, 30), (6, 32), (9, 32)):
    poser(f"buisson_{(x + y) % 4}", x, y)
# Autour de la mare : rochers et buissons.
for nom, x, y in (("rocher_grand", 6, 36), ("rocher_moyen", 14, 36), ("rocher_moyen", 15, 42), ("rocher_petit", 8, 44),
                  ("rocher_grand", 16, 39), ("rocher_petit", 12, 44), ("buisson_petit_3", 6, 41), ("buisson_petit_1", 14, 44)):
    poser(nom, x, y)
for (x, y) in terrain:
    if terrain[(x, y)] == "eau":
        bloque.add((x, y))
        occupe.add((x, y))


def dans_la_clairiere(x, y):
    x0, y0, x1, y1 = CLAIRIERE
    if x0 <= x < x1 and y0 <= y < y1:
        return True
    return 29 <= x <= 34 and y >= y1          # la grand-rue sort au sud


for y in range(HAUTEUR):
    for x in range(LARGEUR):
        if not dans_la_clairiere(x, y):
            bloque.add((x, y))
# Les chemins et la place restent libres d'objets.
for (x, y), nom in terrain.items():
    if nom in ("pierre", "brique", "terre") and (x, y) not in bloque:
        occupe.add((x, y))

# La forêt : hors de la clairière, serrée ; grands sujets dans la masse,
# jamais adossés à la clairière (leur cime cacherait le joueur).
hasard = random.Random(20260907)


def arbre():
    tirage = hasard.random()
    if tirage < 0.40:
        return f"arbre_{hasard.randrange(4)}"
    if tirage < 0.62:
        return f"pin_{hasard.randrange(3)}"
    if tirage < 0.80:
        return f"grand_arbre_{hasard.randrange(4)}"
    if tirage < 0.90:
        return f"grand_pin_{hasard.randrange(3)}"
    return f"petit_arbre_{hasard.randrange(4)}"


essais, plantes = 0, 0
while plantes < 320 and essais < 60000:
    essais += 1
    nom = arbre()
    cx, cy = hasard.randrange(LARGEUR), hasard.randrange(HAUTEUR)
    if dans_la_clairiere(cx, cy) or 2 <= cy < FALAISE + 1:
        continue
    marge = MODELES[nom]["marge"]
    if any(dans_la_clairiere(cx + dx, cy + dy) for dx in range(-marge, marge + 1) for dy in range(-marge, marge + 1)):
        continue
    if not libre(nom, cx, cy):
        continue
    poser(nom, cx, cy, hasard.choice((0, 90, 180, 270)))
    plantes += 1
# Des rochers et des buissons sur le plateau.
for _ in range(3000):
    nom = hasard.choice(("rocher_moyen", "rocher_grand", "buisson_petit_0", "buisson_petit_2", "rocher_petit"))
    cx, cy = hasard.randrange(LARGEUR), hasard.randrange(0, 2)
    if libre(nom, cx, cy):
        poser(nom, cx, cy, hasard.choice((0, 90, 180, 270)))
    if len([o for o in objets if o["h"] > 2 and not o["modele"].startswith(("arbre", "pin", "grand", "petit"))]) >= 14:
        break
# Des bosquets dans les coins de la clairière, des buissons épars, des fleurs.
for nom, x, y in (("arbre_0", 6, 9), ("pin_1", 9, 9), ("arbre_2", 56, 9), ("pin_0", 53, 10),
                  ("arbre_1", 6, 44), ("pin_2", 56, 43), ("arbre_0", 44, 41), ("arbre_1", 20, 41)):
    if libre(nom, x, y):
        poser(nom, x, y)
essais = 0
while essais < 4000 and len([o for o in objets if o["modele"].startswith("buisson_petit")]) < 26:
    essais += 1
    nom = f"buisson_petit_{hasard.randrange(4)}"
    cx, cy = hasard.randrange(LARGEUR), hasard.randrange(HAUTEUR)
    if not dans_la_clairiere(cx, cy) or terrain[(cx, cy)] != "herbe":
        continue
    if libre(nom, cx, cy) and all(abs(cx - o["x"] / T) + abs(cy - o["y"] / T) > 6 for o in objets if o["modele"].startswith("buisson_petit")):
        poser(nom, cx, cy, hasard.choice((0, 90, 180, 270)))
for _ in range(2500):
    nom = f"fleur_{hasard.randrange(4)}" if hasard.random() < 0.45 else "touffe"
    cx, cy = hasard.randrange(LARGEUR), hasard.randrange(HAUTEUR)
    if dans_la_clairiere(cx, cy) and terrain[(cx, cy)] == "herbe" and libre(nom, cx, cy):
        poser(nom, cx, cy, hasard.choice((0, 90, 180, 270)))
    if len([o for o in objets if o["modele"].startswith(("fleur", "touffe"))]) >= 160:
        break

ecrire("terrain_village", maillage_terrain(), centrer=False)

# ------------------------------------------------------------------ intérieurs
# Chaque pièce est UN maillage : sol, trois murs (le sud reste ouvert, la
# caméra regarde dedans comme dans une maison de poupée), meubles fondus
# dedans. Le plan retient les cases bloquées, la sortie, le portail, les
# vitres et l'ardoise des scores. Origine : le coin nord-ouest du sol.
def tourner(modele, rot):
    """Un quart de tour à la fois autour de y ; l'origine reste au sol."""
    if rot % 360 == 0:
        return modele
    m = Modele(modele.taille)
    for (x, y, z), c in modele.v.items():
        for _ in range((rot // 90) % 4):
            x, z = -z - 1, x
        m.v[(x, y, z)] = c
    return m


def table():
    m = Modele()
    m.boite(-6, 5, -4, 5, 5, 3, P["bois"])
    m.boite(-6, 6, -4, 5, 6, 3, P["bois_clair"])
    for (x, z) in ((-5, -3), (4, -3), (-5, 2), (4, 2)):
        m.boite(x, 0, z, x, 4, z, P["bois2"])
    m.boite(-1, 7, -1, 0, 8, 0, P["biere"])                # une chope
    return m


def chaise():
    m = Modele()
    m.boite(-2, 3, -2, 1, 3, 1, P["bois"])
    for (x, z) in ((-2, -2), (1, -2), (-2, 1), (1, 1)):
        m.boite(x, 0, z, x, 2, z, P["bois2"])
    m.boite(-2, 4, -2, 1, 7, -2, P["bois2"])
    return m


def tabouret():
    m = Modele()
    m.boite(-1, 3, -1, 1, 3, 1, P["bois"])
    for (x, z) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        m.boite(x, 0, z, x, 2, z, P["bois2"])
    return m


def tonneau():
    m = Modele()
    m.boite(-3, 0, -3, 2, 7, 2, P["bois"])
    for y in (1, 6):
        m.boite(-3, y, -3, 2, y, 2, P["fer2"])
    m.creux(-3, 0, -3, -3, 7, -3)
    m.creux(2, 0, -3, 2, 7, -3)
    m.creux(-3, 0, 2, -3, 7, 2)
    m.creux(2, 0, 2, 2, 7, 2)
    return m


def coffre(couleur=None):
    m = Modele()
    m.boite(-3, 0, -2, 2, 4, 1, couleur or P["bois"])
    m.boite(-3, 4, -2, 2, 4, 1, P["bois2"])
    m.boite(-3, 2, -2, 2, 2, 1, P["fer"])
    m.poser(0, 2, 2, P["or"])
    return m


def lit():
    m = Modele()
    m.boite(-3, 0, -8, 2, 3, 7, P["bois2"])
    m.boite(-3, 3, -8, 2, 4, 7, P["drap"])
    m.boite(-3, 4, -2, 2, 5, 7, P["couverture"])
    m.boite(-2, 5, -7, 1, 5, -5, P["tablier"])              # l'oreiller
    m.boite(-3, 0, -8, 2, 8, -8, P["bois2"])                # la tête de lit
    m.boite(-3, 0, 7, 2, 5, 7, P["bois2"])
    return m


def armoire():
    m = Modele()
    m.boite(-7, 0, -3, 6, 19, 2, P["bois2"])
    m.boite(-6, 1, 2, -1, 18, 2, P["bois"])
    m.boite(0, 1, 2, 5, 18, 2, P["bois"])
    m.poser(-1, 9, 3, P["or"])
    m.poser(0, 9, 3, P["or"])
    return m


def comptoir(longueur=48):
    m = Modele()
    x0, x1 = -longueur // 2, longueur // 2 - 1
    m.boite(x0, 0, -3, x1, 7, 2, P["bois2"])
    m.boite(x0 - 1, 8, -4, x1 + 1, 8, 3, P["bois_clair"])
    for x in range(x0 + 4, x1, 12):
        m.boite(x, 9, -2, x, 10, -2, P["biere"])
        m.boite(x + 5, 9, 0, x + 5, 10, 0, P["blanc"])
    return m


def cheminee_int():
    """La cheminée d'une pièce, à sceller dans le mur du fond."""
    m = Modele()
    m.boite(-9, 0, -4, 8, 19, 3, P["cheminee"])
    m.boite(-8, 0, -4, 7, 18, 4, nuance(P["cheminee"], 0.92))
    m.creux(-5, 0, -1, 4, 9, 4)
    m.boite(-5, 0, -1, 4, 9, -1, P["noir"])
    m.boite(-4, 0, 0, 3, 1, 2, P["tronc"])
    m.boite(-3, 1, 0, 2, 3, 2, P["feu"])
    m.boite(-2, 3, 0, 1, 4, 1, P["braise"])
    m.boite(-10, 10, -4, 9, 11, 5, P["bois2"])               # le manteau
    return m


def candelabre():
    m = Modele()
    m.boite(-2, 0, -2, 1, 0, 1, P["fer2"])
    m.boite(0, 1, 0, 0, 11, 0, P["fer2"])
    m.boite(-3, 12, 0, 2, 12, 0, P["fer2"])
    for x in (-3, 0, 2):
        m.boite(x, 13, 0, x, 14, 0, P["blanc"])
        m.poser(x, 15, 0, P["feu"])
    return m


def tapis(largeur=32, profondeur=24, couleur=None):
    m = Modele()
    c = couleur or P["tapis"]
    m.boite(-largeur // 2, 0, -profondeur // 2, largeur // 2 - 1, 0, profondeur // 2 - 1, c)
    m.boite(-largeur // 2 + 2, 0, -profondeur // 2 + 2, largeur // 2 - 3, 0, profondeur // 2 - 3, P["tapis2"])
    m.boite(-largeur // 2 + 4, 0, -profondeur // 2 + 4, largeur // 2 - 5, 0, profondeur // 2 - 5, c)
    return m


def plante():
    m = Modele()
    m.boite(-2, 0, -2, 1, 3, 1, P["brique"])
    m.boite(-1, 4, -1, 0, 6, 0, P["feuille2"])
    for (x, z) in ((-2, 0), (1, 0), (0, -2), (0, 1)):
        m.boite(x, 6, z, x, 7, z, P["feuille"])
    m.boite(-1, 7, -1, 0, 8, 0, P["feuille3"])
    return m


def baignoire():
    m = Modele()
    m.boite(-4, 0, -7, 3, 5, 6, P["blanc"])
    m.creux(-3, 2, -6, 2, 5, 5)
    m.boite(-3, 4, -6, 2, 4, 5, P["vitre"])
    return m


def etabli():
    m = Modele()
    m.boite(-8, 0, -3, 7, 6, 2, P["bois2"])
    m.boite(-9, 7, -4, 8, 7, 3, P["bois"])
    m.boite(-6, 8, -2, 0, 9, 1, P["fer2"])                  # l'enclume dessus
    m.boite(-7, 9, -1, -6, 9, 0, P["fer"])
    m.boite(3, 8, -1, 5, 8, 1, P["fer"])                    # un marteau
    m.boite(4, 9, 0, 4, 12, 0, P["bois"])
    return m


def ratelier():
    """Le râtelier d'armes, contre le mur du fond."""
    m = Modele()
    m.boite(-8, 0, -1, 7, 1, 0, P["bois2"])
    m.boite(-8, 12, -1, 7, 12, 0, P["bois2"])
    for x, c in ((-6, P["acier"]), (-2, P["acier"]), (2, P["bois"]), (6, P["acier2"])):
        m.boite(x, 2, 0, x, 14, 0, c)
        m.boite(x - 1, 5, 0, x + 1, 5, 0, P["or"])
    return m


def etagere():
    m = Modele()
    for y in (10, 15, 20):
        m.boite(-8, y, -1, 7, y, 0, P["bois2"])
    for i, x in enumerate(range(-7, 8, 3)):
        m.boite(x, 11, 0, x, 13, 0, (P["biere"], P["robe"], P["feuille"], P["tissu"], P["vitre"])[i % 5])
        m.boite(x, 16, 0, x, 18, 0, (P["vitre"], P["biere"], P["tissu"], P["feuille"], P["robe"])[i % 5])
    return m


def ardoise(largeur=64):
    """L'ardoise des scores, au mur ; le moteur écrit dessus."""
    m = Modele()
    m.boite(-largeur // 2 - 1, 16, -1, largeur // 2, 33, 0, P["bois2"])
    m.boite(-largeur // 2, 17, 0, largeur // 2 - 1, 32, 0, P["noir"])
    return m


def portail_pierre():
    m = Modele()
    for x in (-8, 7):
        m.boite(x, 0, -2, x + 2, 20, 1, P["moellon"])
    m.boite(-8, 21, -2, 9, 24, 1, P["moellon2"])
    for y in range(0, 21, 4):
        m.boite(-8, y, 1, -6, y, 1, P["moellon2"])
        m.boite(7, y, 1, 9, y, 1, P["moellon2"])
    m.boite(-5, 0, -1, 6, 20, -1, P["noir"])                 # le vide, que le moteur éclaire
    return m


class Piece:
    def __init__(self, nom, largeur, profondeur, sol, mur):
        self.nom, self.l, self.p = nom, largeur, profondeur
        self.m = Modele(FIN)
        self.bloque = set()
        self.vitres = []
        self.tableau = None
        self.portail = None
        L, D, H = largeur * 8, profondeur * 8, 30
        h = random.Random(len(nom))
        # Le sol : des lames de plancher ou des dalles, par bandes de 8.
        for x in range(L):
            for z in range(D):
                if sol == "bois":
                    c = P["plancher"] if ((z // 8) + (x // 24)) % 2 == 0 else P["plancher2"]
                else:
                    c = P["dalle"] if ((x // 8) + (z // 8)) % 2 == 0 else P["dalle2"]
                self.m.poser(x, -1, z, c)
        # Les murs : nord, ouest, est ; le sud n'a qu'une plinthe.
        c1, c2 = (P["mur_int"], P["mur_int2"]) if mur == "platre" else ((P["rondin"], P["rondin2"]) if mur == "rondins" else (P["moellon"], P["moellon2"]))
        for y in range(H):
            c = c1 if (mur == "platre" or y % 2 == 0) else c2
            self.m.boite(-4, y, -4, L + 3, y, -1, c)
            self.m.boite(-4, y, -1, -1, y, D + 3, c)
            self.m.boite(L, y, -1, L + 3, y, D + 3, c)
        if mur == "platre":
            for x in range(-4, L + 4, 16):
                self.m.boite(x, 0, -1, x, H - 1, -1, P["poutre"])
            self.m.boite(-4, H - 1, -1, L + 3, H - 1, -1, P["poutre"])
            self.m.boite(-4, 0, -1, L + 3, 0, -1, P["poutre"])
        for x in range(-4, L + 4):
            self.m.boite(x, 0, D, x, 2, D + 3, c2)             # la plinthe sud
        self.m.boite(-4, 0, -4, -1, 3, -1, c2)

    def cases(self, cx, cy, l, p):
        for j in range(p):
            for i in range(l):
                self.bloque.add((cx + i, cy + j))

    def meuble(self, modele, cx, cy, l=1, p=1, rot=0, bloque=True, contre_le_mur=False):
        """Pose un meuble dont l'emprise est l × p cases à partir de (cx, cy)."""
        m = tourner(modele, rot)
        ox = int((cx + l / 2) * 8)
        oz = int((cy + p / 2) * 8) if not contre_le_mur else 0
        self.m.fusion(m, ox, 0, oz)
        if bloque:
            self.cases(cx, cy, l, p)

    def fenetre(self, cx):
        x = cx * 8
        self.m.boite(x, 12, -2, x + 7, 21, -1, P["cadre"])
        self.m.boite(x + 1, 13, -2, x + 6, 20, -1, P["vitre"])
        self.m.boite(x + 4, 13, -2, x + 4, 20, -1, P["cadre"])
        self.m.boite(x + 1, 17, -2, x + 6, 17, -1, P["cadre"])
        self.vitres.append([(x + 4) * FIN, 17 * FIN, -1 * FIN])

    def sortie_sud(self):
        """L'ouverture dans la plinthe sud, au milieu ; la zone de sortie."""
        cx = self.l // 2 - 1
        self.m.creux(cx * 8, 0, self.p * 8, cx * 8 + 15, 3, self.p * 8 + 3)
        return [cx * T, (self.p - 1) * T, 2 * T, T]

    def porte_portail(self, cx):
        self.meuble(portail_pierre(), cx, -1, 2, 1, contre_le_mur=True, bloque=False)
        self.portail = [cx * T, 0, 2 * T, T]
        self.cases(cx - 1, -1, 4, 1)

    def scores(self, cx, largeur_cases=8):
        self.meuble(ardoise(largeur_cases * 8), cx, -1, largeur_cases, 1, contre_le_mur=True, bloque=False)
        self.tableau = [(cx + largeur_cases / 2), 25 * FIN, 1.3 * FIN, largeur_cases - 0.5, 15 * FIN]

    def lignes(self):
        return ["".join("#" if (x, y) in self.bloque else "." for x in range(self.l)) for y in range(self.p)]


PIECES = {}

# La taverne : le bar à gauche, la cheminée à droite, les tables au milieu,
# le portail du Carnage au fond.
tav = Piece("taverne", 18, 11, "bois", "platre")
tav.meuble(comptoir(48), 1, 1, 6, 1)
tav.meuble(etagere(), 2, -1, 2, 1, contre_le_mur=True, bloque=False)
tav.meuble(etagere(), 5, -1, 2, 1, contre_le_mur=True, bloque=False)
tav.meuble(tonneau(), 0, 9)
tav.meuble(tonneau(), 1, 9)
tav.meuble(tonneau(), 0, 8)
tav.meuble(tapis(40, 32), 8, 4, 5, 4, bloque=False)
for (x, y) in ((5, 4), (10, 4), (5, 8), (10, 8)):
    tav.meuble(table(), x, y, 2, 1)
    tav.meuble(chaise(), x - 1, y, 1, 1, rot=270)
    tav.meuble(chaise(), x + 2, y, 1, 1, rot=90)
tav.meuble(cheminee_int(), 12, -1, 2, 1, contre_le_mur=True)
tav.cases(12, 0, 2, 1)
tav.meuble(candelabre(), 15, 9)
tav.meuble(plante(), 17, 10)
tav.fenetre(16)
tav.scores(7, 7)
tav.porte_portail(15)
PIECES["taverne"] = {"piece": tav, "sortie": tav.sortie_sud(), "rondes": {"serveuse": [[3 * T, 7 * T], [14 * T, 7 * T], [14 * T, 3 * T], [3 * T, 3 * T]]}}

# L'armurerie : l'établi et la forge, le râtelier, le comptoir, le portail de l'Énigme.
arm = Piece("armurerie", 14, 9, "pierre", "pierre")
arm.meuble(ratelier(), 0, -1, 2, 1, contre_le_mur=True, bloque=False)
arm.meuble(cheminee_int(), 3, -1, 2, 1, contre_le_mur=True)
arm.cases(3, 0, 2, 1)
arm.meuble(etabli(), 1, 2, 2, 1)
arm.meuble(comptoir(32), 8, 3, 4, 1)
arm.meuble(coffre(), 12, 7)
arm.meuble(coffre(P["fer2"]), 13, 7)
arm.meuble(tonneau(), 0, 7)
arm.meuble(tonneau(), 0, 6)
arm.meuble(tapis(32, 24, P["coussin"]), 5, 4, 4, 3, bloque=False)
arm.meuble(candelabre(), 13, 1)
arm.fenetre(2)
arm.scores(5, 6)
arm.porte_portail(11)
PIECES["armurerie"] = {"piece": arm, "sortie": arm.sortie_sud(), "rondes": {}}

# L'auberge : des lits, une armoire, la cheminée, une table, la baignoire.
aub = Piece("auberge", 14, 9, "bois", "rondins")
for y in (1, 4):
    aub.meuble(lit(), 0, y, 1, 2)
aub.meuble(lit(), 12, 5, 1, 2)
aub.meuble(armoire(), 2, 0, 2, 1)
aub.meuble(table(), 7, 5, 2, 1)
aub.meuble(chaise(), 6, 5, rot=270)
aub.meuble(chaise(), 9, 5, rot=90)
aub.meuble(baignoire(), 12, 1, 1, 2)
aub.meuble(tapis(32, 24, P["coussin"]), 6, 2, 4, 3, bloque=False)
aub.meuble(plante(), 13, 8)
aub.meuble(plante(), 3, 8)
aub.meuble(candelabre(), 10, 1)
aub.fenetre(4)
aub.scores(5, 6)
aub.porte_portail(11)
PIECES["auberge"] = {"piece": aub, "sortie": aub.sortie_sud(), "rondes": {}}

for nom, p in PIECES.items():
    ecrire(f"piece_{nom}", p["piece"].m, centrer=False)

# ------------------------------------------------------------------ plan.json
def carte(blocs, largeur, hauteur):
    return ["".join("#" if (x, y) in blocs else "." for x in range(largeur)) for y in range(hauteur)]


plan = {
    "case": T,
    "village": {
        "taille": [LARGEUR * T, HAUTEUR * T],
        "depart": [32 * T, 40 * T],
        "bloque": carte(bloque, LARGEUR, HAUTEUR),
        "objets": objets,
        "portes": portes,
        "feu": [FEU[0], FEU[1]],
        "tableau": [TABLEAU[0], 19 * FIN, TABLEAU[1] + 0.1, 9.0, 2.5],
        "fenetres": fenetres,
        "fumees": fumees,
        "lanternes": [[x + 0.5 + 4.5 * FIN, 17 * FIN, y + 0.5] for (x, y) in LANTERNES],
        "mare": {"cases": [[x, y] for (x, y), t in terrain.items() if t == "eau"], "niveau": -0.35},
        "plateau": FALAISE,
        "rondes": {"paysanne": [[352, 416], [576, 416], [576, 528], [352, 528]]},
    },
}
for nom, p in PIECES.items():
    piece = p["piece"]
    plan[nom] = {
        "taille": [piece.l * T, piece.p * T],
        "bloque": piece.lignes(),
        "sortie": p["sortie"],
        "rondes": p["rondes"],
        "fenetres": piece.vitres,
    }
    if piece.portail:
        plan[nom]["portail"] = piece.portail
    if piece.tableau:
        plan[nom]["tableau"] = piece.tableau
(SORTIE / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, separators=(",", ":")))
print(f"plan.json écrit : {len(objets)} objets, {len(bloque)} cases bloquées, {len(ECRITS)} modèles")
