#!/usr/bin/env python3
"""Prépare les images du hub à partir du pack « Pixel Crawler – Free Pack ».

    python3 outils/village.py "/chemin/vers/Pixel Crawler - Free Pack"

Règle absolue : on ne DÉCOUPE jamais un dessin. Chaque image produite est
soit un sprite entier tel que l'auteur l'a rangé dans sa grille (un arbre
occupe une case de 48 × 96, on prend la case), soit une pièce entière de la
maquette de taverne (murs compris), soit une planche d'animation copiée
telle quelle. Les maisons sont ASSEMBLÉES — un toit entier posé sur un
module de mur entier, une porte entière dessus — jamais rognées.

Tout est à l'échelle native du pack : une case de sol fait 16 pixels, un
personnage 30 pixels de haut. Le moteur affiche le tout avec un zoom entier,
sans jamais redimensionner un sprite.
"""
import random
import sys
from pathlib import Path

from PIL import Image

if len(sys.argv) < 2:
    sys.exit(__doc__)
PACK = Path(sys.argv[1])
SORTIE = Path(__file__).resolve().parent.parent / "modeles" / "village"
SORTIE.mkdir(parents=True, exist_ok=True)
T = 16  # la case du pack


def ouvrir(relatif):
    return Image.open(PACK / relatif).convert("RGBA")


def case(image, x, y, largeur, hauteur):
    """Une case entière de la grille d'une planche."""
    return image.crop((x, y, x + largeur, y + hauteur))


def ecrire(image, nom):
    image.save(SORTIE / nom, optimize=True)
    print(f"{nom:32s} {image.width} × {image.height}")


# ------------------------------------------------------------------ végétation
arbres_feuillus = ouvrir("Environment/Props/Static/Trees/Model_01/Size_03.png")
arbres_pins = ouvrir("Environment/Props/Static/Trees/Model_02/Size_03.png")
vegetation = ouvrir("Environment/Props/Static/Vegetation.png")
rochers = ouvrir("Environment/Props/Static/Rocks.png")

# Feuillus : cases de 48 × 96 (vert, jaune ; rangée du bas : roux).
ecrire(case(arbres_feuillus, 0, 0, 48, 96), "arbre_0.png")
ecrire(case(arbres_feuillus, 48, 0, 48, 96), "arbre_1.png")
ecrire(case(arbres_feuillus, 48, 96, 48, 96), "arbre_2.png")
# Pins : cases de 48 × 80.
ecrire(case(arbres_pins, 0, 0, 48, 80), "pin_0.png")
ecrire(case(arbres_pins, 48, 0, 48, 80), "pin_1.png")
ecrire(case(arbres_pins, 48, 80, 48, 80), "pin_2.png")
# Buissons : la rangée des 48 × 48 (quatre teintes) et celle des 32 × 32.
for i in range(4):
    ecrire(case(vegetation, i * 48, 96, 48, 48), f"buisson_{i}.png")
    ecrire(case(vegetation, i * 48, 0, 32, 32), f"buisson_petit_{i}.png")
# Rochers : le grand (32 × 48), le moyen (32 × 32) et deux petits (16 × 16),
# dans la teinte grise puis la teinte brune.
ecrire(case(rochers, 0, 16, 32, 48), "rocher_grand_0.png")
ecrire(case(rochers, 96, 16, 32, 48), "rocher_grand_1.png")
ecrire(case(rochers, 32, 16, 32, 32), "rocher_moyen_0.png")
ecrire(case(rochers, 128, 16, 32, 32), "rocher_moyen_1.png")
ecrire(case(rochers, 64, 16, 16, 16), "rocher_petit_0.png")
ecrire(case(rochers, 80, 16, 16, 16), "rocher_petit_1.png")

# ------------------------------------------------------------------ mobilier
props = ouvrir("Environment/Structures/Buildings/Props.png")
ecrire(case(props, 80, 160, 64, 32), "banc.png")
ecrire(case(props, 144, 128, 32, 32), "caisses.png")
foyer = ouvrir("Environment/Structures/Stations/Bonfire/Bonfire.png")
ecrire(case(foyer, 0, 0, 32, 32), "foyer.png")
ecrire(ouvrir("Environment/Structures/Stations/Bonfire/Fire_01-Sheet.png"), "feu.png")
# La clôture est un jeu de cases de 16 : un lé horizontal, un lé vertical.
ecrire(case(props, 24, 176, 16, 16), "cloture_h.png")
ecrire(case(props, 8, 208, 16, 16), "cloture_v.png")
ecrire(case(props, 48, 152, 32, 24), "jardiniere.png")
ferme = ouvrir("Environment/Props/Static/Farm.png")
ecrire(case(ferme, 240, 32, 32, 48), "epouvantail.png")
for nom, y in (("carottes", 16), ("radis", 48), ("choux", 80), ("laitues", 112)):
    ecrire(case(ferme, 80, y, 16, 16), f"culture_{nom}.png")     # le plant mûr
    ecrire(case(ferme, 160, y, 16, 32), f"cageot_{nom}.png")     # le cageot plein
ecrire(case(ouvrir("Environment/Structures/Stations/Anvil/Anvil.png"), 0, 32, 64, 48), "forge.png")
ecrire(case(ouvrir("Environment/Structures/Stations/Furnace/Furnace.png"), 64, 64, 64, 64), "fourneau.png")
# La rôtissoire est une planche de quatre images de 64 ; copiée telle quelle.
ecrire(ouvrir("Environment/Structures/Stations/Cooking Station/Grill/Grill_03-Sheet.png"), "rotissoire.png")


def en_bande(planche, largeur, hauteur):
    """Une planche rangée en grille devient une bande horizontale : chaque
    image est recopiée entière, dans l'ordre de lecture. Le moteur ne lit que
    des bandes."""
    colonnes, rangees = planche.width // largeur, planche.height // hauteur
    images = []
    for r in range(rangees):
        for c in range(colonnes):
            image = case(planche, c * largeur, r * hauteur, largeur, hauteur)
            if image.getbbox():
                images.append(image)
    bande = Image.new("RGBA", (len(images) * largeur, hauteur))
    for i, image in enumerate(images):
        bande.alpha_composite(image, (i * largeur, 0))
    return bande


# La scierie : soixante images de 80 × 64 rangées en grille.
ecrire(en_bande(ouvrir("Environment/Structures/Stations/Sawmill/Level_2-Sheet.png"), 80, 64), "scierie.png")

# ------------------------------------------------------------------ personnages
# Les planches d'animation sont copiées image par image, sans rien rogner,
# dans des cases uniformes de 64 × 64 où les pieds touchent le bas de la
# case. Le pack range ses personnages dans des cases de 32, de 64 pieds à 48
# ou de 64 pieds à 64 selon les planches ; les mettre au même gabarit, c'est
# ce qui permet au moteur de les poser tous avec le même point d'ancrage,
# sans agrandir personne : un personnage fait trente pixels partout.
CASE = 64


def normaliser(planche, cote, pieds):
    """`cote` : la case de la planche d'origine ; `pieds` : la ligne des pieds
    dans cette case. Chaque image est recopiée entière, centrée, les pieds
    posés sur la ligne 64 de la nouvelle case."""
    nombre = planche.width // cote
    sortie = Image.new("RGBA", (nombre * CASE, CASE))
    for i in range(nombre):
        image = case(planche, i * cote, 0, cote, planche.height)
        sortie.alpha_composite(image, (i * CASE + (CASE - cote) // 2, CASE - pieds))
    return sortie


PNJ = "Entities/Npc's/"
# Les trois héros jouables : au repos (cases de 32, pieds en bas) et en
# course (cases de 64, pieds en bas). Vus de côté ; la gauche est la droite
# retournée, comme dans tout le pack.
for nom in ("Knight", "Rogue", "Wizzard"):
    ecrire(normaliser(ouvrir(PNJ + f"{nom}/Idle/Idle-Sheet.png"), 32, 32), f"heros_{nom.lower()}_repos.png")
    ecrire(normaliser(ouvrir(PNJ + f"{nom}/Run/Run-Sheet.png"), 64, 64), f"heros_{nom.lower()}_marche.png")
# Les habitants : les citadines sont dans des cases de 64 avec les pieds à 48.
ecrire(normaliser(ouvrir(PNJ + "Citizen_F/Peasant_A/Idle/Idle-Sheet.png"), 64, 48), "pnj_paysanne.png")
ecrire(normaliser(ouvrir(PNJ + "Citizen_F/Tavern_A/Idle_Hold/Idle_Side-Sheet.png"), 64, 48), "pnj_taverniere.png")
ecrire(normaliser(ouvrir(PNJ + "Citizen_F/Tavern_B/Idle/Idle_Side-Sheet.png"), 64, 48), "pnj_aubergiste.png")
# Ceux qui marchent ont aussi leur planche de marche.
ecrire(normaliser(ouvrir(PNJ + "Citizen_F/Peasant_A/Walk/Walk-Sheet.png"), 64, 48), "pnj_paysanne_marche.png")
ecrire(normaliser(ouvrir(PNJ + "Citizen_F/Tavern_B/Idle_Hold/Idle_Side-Sheet.png"), 64, 48), "pnj_serveuse.png")
ecrire(normaliser(ouvrir(PNJ + "Citizen_F/Tavern_B/Walk_Hold/Walk_Side-Sheet.png"), 64, 48), "pnj_serveuse_marche.png")
ecrire(normaliser(ouvrir("Entities/Mobs/Skeleton Crew/Skeleton - Warrior/Idle/Idle-Sheet.png"), 32, 32), "pnj_squelette.png")

# ------------------------------------------------------------------ maisons
murs = ouvrir("Environment/Structures/Buildings/Walls.png")
toits = ouvrir("Environment/Structures/Buildings/Roofs.png")


def maison(mur, toit, porte):
    """Un toit entier (128 × 96) posé sur un pan de mur entier (96 × 56, la
    bande de façades de la planche) et une porte entière au milieu. Le bas du
    toit est en chevron : c'est un pignon vu de face, et le mur remonte sous
    lui jusqu'à la ligne des chevrons. Le petit auvent au centre du toit
    coiffe la porte — il fait exactement sa largeur."""
    image = Image.new("RGBA", (128, 128))
    image.alpha_composite(case(murs, mur * 96, 184, 96, 56), (16, 72))
    image.alpha_composite(case(toits, toit * 128, 0, 128, 96), (0, 0))
    image.alpha_composite(case(props, porte * 32, 16, 32, 48), (48, 80))
    return image


ecrire(maison(mur=3, toit=0, porte=1), "maison_taverne.png")
ecrire(maison(mur=0, toit=1, porte=0), "maison_armurerie.png")
ecrire(maison(mur=2, toit=0, porte=2), "maison_auberge.png")
ecrire(maison(mur=5, toit=1, porte=0), "maison_maison.png")    # la maison fermée de l'ouest
ecrire(maison(mur=1, toit=0, porte=1), "maison_grange.png")    # la grange fermée de l'est

# ------------------------------------------------------------------ intérieurs
# Des pièces ENTIÈRES de la maquette, murs compris. La maquette est livrée
# agrandie deux fois (chaque pixel y est un bloc de 2 × 2, on l'a vérifié) :
# on la ramène à l'échelle du pack en gardant un pixel sur deux, sans perte.
# Le noir entre les pièces n'est pas du décor : on le rend transparent.
maquette = ouvrir("MockUps/Tavern.png")
maquette = maquette.resize((maquette.width // 2, maquette.height // 2), Image.NEAREST)


def piece(x0, y0, x1, y1):
    image = maquette.crop((x0, y0, x1, y1))
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if r < 8 and g < 8 and b < 8:
                pixels[x, y] = (0, 0, 0, 0)
    return image


ecrire(piece(176, 8, 632, 345), "interieur_taverne.png")      # la grande salle

# ------------------------------------------------------------------ pièces composées
# L'armurerie et l'auberge sont ASSEMBLÉES avec le kit d'intérieur du pack :
# un mur du fond (rebord, face, plinthe), des rebords latéraux et bas, un sol
# en cases, puis des meubles entiers de la planche « Interior_Props_01 ».
# Chaque meuble déclare son emprise au sol ; le masque de marche en découle.
class Masque:
    def __init__(self, colonnes, rangees):
        self.cases = [["#"] * colonnes for _ in range(rangees)]

    def marquer(self, c, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.cases[y][x] = c
        return self

    def libre(self, x0, y0, x1, y1):
        return self.marquer(".", x0, y0, x1, y1)

    def bloque(self, x0, y0, x1, y1):
        return self.marquer("#", x0, y0, x1, y1)

    def lignes(self):
        return ["".join(l) for l in self.cases]


kit = ouvrir("Environment/Structures/Buildings/Interior/Interior_Walls_01.png")
meubles = ouvrir("Environment/Structures/Buildings/Interior/Interior_Props_01.png")
KITS = {"rondins": 0, "pierre": 6, "planches": 12, "platre": 18}   # colonne de départ
SOLS = {"bois": 0, "pierre": 5, "sombre": 10, "chevrons": 15}      # blocs de sol (y = 20)


def case_kit(kx, x, y, noir_transparent=False):
    image = case(kit, (kx + x) * T, y * T, T, T)
    if noir_transparent:
        # Le noir du gabarit est l'intérieur de la pièce, pas du mur.
        px = image.load()
        for j in range(T):
            for i in range(T):
                if px[i, j][:3] == (0, 0, 0):
                    px[i, j] = (0, 0, 0, 0)
    return image


class Piece:
    """Une pièce de `largeur` × `hauteur` cases : quatre rangées de mur du
    fond, un sol, un rebord tout autour. `poser` ajoute un meuble entier
    (rectangle de la planche, en pixels) à une case, avec son emprise."""

    def __init__(self, largeur, hauteur, mur, sol):
        self.largeur, self.hauteur = largeur, hauteur
        self.image = Image.new("RGBA", (largeur * T, hauteur * T), (0, 0, 0, 0))
        self.masque = Masque(largeur, hauteur)
        kx, sx = KITS[mur], SOLS[sol]
        for y in range(3, hauteur):
            for x in range(largeur):
                self._put(case(kit, (sx + 1 + x % 3) * T, (21 + y % 3) * T, T, T), x, y)
        for x in range(largeur):
            fx = 0 if x == 0 else 1 if x == 1 else 5 if x == largeur - 1 else 4 if x == largeur - 2 else 2 + x % 2
            for r in range(4):
                self._put(case_kit(kx, fx, 5 + r), x, r)
        for y in range(4, hauteur - 1):
            self._put(case_kit(kx, 0, 2 + y % 2, True), 0, y)
            self._put(case_kit(kx, 5, 2 + y % 2, True), largeur - 1, y)
        self._put(case_kit(kx, 0, 4, True), 0, hauteur - 1)
        self._put(case_kit(kx, 5, 4, True), largeur - 1, hauteur - 1)
        for x in range(1, largeur - 1):
            self._put(case_kit(kx, 2 + x % 2, 5, True), x, hauteur - 1)
        self.masque.libre(1, 4, largeur - 2, hauteur - 2)

    def _put(self, image, x, y):
        self.image.alpha_composite(image, (x * T, y * T))

    def poser(self, rect, x, y, emprise=None):
        """`rect` : (x, y, largeur, hauteur) en pixels sur la planche des
        meubles ; `emprise` : (x0, y0, x1, y1) en cases, relatives au coin du
        meuble, bornes incluses ; None = décor mural, on passe devant."""
        image = case(meubles, *rect)
        self.image.alpha_composite(image, (x * T, y * T))
        if emprise:
            self.masque.bloque(x + emprise[0], y + emprise[1], x + emprise[2], y + emprise[3])

    def sortie(self, x0, y0, x1, y1):
        self.masque.marquer("S", x0, y0, x1, y1)

    def portail(self, x0, y0, x1, y1):
        self.masque.marquer("P", x0, y0, x1, y1)


# Les meubles, en pixels sur la planche : (x, y, largeur, hauteur).
CHEMINEE_PIERRE = (272, 40, 48, 104)
CHEMINEE_BRIQUE = (384, 40, 48, 104)
ETABLI_ENCLUME = (128, 96, 52, 32)
COMPTOIR = (368, 0, 64, 52)
TONNEAU = (224, 120, 16, 24)
CAISSE = (208, 120, 16, 24)
COFFRE = (144, 72, 32, 24)
COFFRE_FORT = (176, 72, 32, 24)
CANDELABRE = (240, 104, 32, 56)
TAPIS_SOMBRE = (384, 330, 48, 54)
TAPIS_VERT = (336, 330, 48, 54)
EPEE = (96, 256, 32, 16)
HACHE = (128, 256, 32, 16)
BOUCLIER = (128, 272, 16, 16)
ECUSSON = (64, 256, 32, 32)
TETE_DE_LOUP = (544, 0, 32, 32)
TETE_D_OURS = (576, 0, 32, 32)
LIT = (0, 288, 32, 64)
GRAND_LIT = (32, 288, 48, 64)
BANQUETTE = (80, 300, 48, 36)
TABLE_RONDE = (80, 0, 32, 48)
CHAISE_DROITE = (64, 0, 16, 32)
CHAISE_GAUCHE = (64, 64, 16, 32)
FENETRE = (64, 176, 32, 40)
TABLEAU_PEINT = (80, 320, 16, 16)
PLANTE = (16, 352, 16, 32)
PLANTE_LARGE = (48, 352, 32, 32)
ARMOIRE = (272, 0, 48, 48)
BAIGNOIRE = (124, 140, 56, 36)

armurerie_piece = Piece(20, 12, "pierre", "pierre")
armurerie_piece.poser(CHEMINEE_PIERRE, 2, 0, (0, 4, 2, 6))          # la forge, âtre sur le sol
armurerie_piece.poser(EPEE, 6, 1)
armurerie_piece.poser(HACHE, 6, 2)
armurerie_piece.poser(BOUCLIER, 8, 1)
armurerie_piece.poser(ECUSSON, 8, 2)
armurerie_piece.poser(TETE_DE_LOUP, 17, 0)
armurerie_piece.poser(TAPIS_SOMBRE, 8, 7)
armurerie_piece.poser(COMPTOIR, 14, 3, (0, 1, 3, 2))                # le comptoir, appuyé au mur
armurerie_piece.poser(ETABLI_ENCLUME, 6, 5, (0, 0, 2, 1))
armurerie_piece.poser(COFFRE, 1, 7, (0, 0, 1, 1))
armurerie_piece.poser(COFFRE_FORT, 3, 7, (0, 0, 1, 1))
armurerie_piece.poser(TONNEAU, 1, 9, (0, 0, 0, 1))
armurerie_piece.poser(TONNEAU, 2, 9, (0, 0, 0, 1))
armurerie_piece.poser(CAISSE, 3, 9, (0, 0, 0, 1))
armurerie_piece.poser(CANDELABRE, 12, 5, (0, 2, 1, 3))
armurerie_piece.sortie(9, 10, 10, 10)
armurerie_piece.portail(17, 9, 18, 10)
ecrire(armurerie_piece.image, "interieur_armurerie.png")

auberge_piece = Piece(18, 12, "rondins", "bois")
auberge_piece.poser(CHEMINEE_BRIQUE, 8, 0, (0, 4, 2, 6))
auberge_piece.poser(FENETRE, 3, 1)
auberge_piece.poser(FENETRE, 13, 1)
auberge_piece.poser(TABLEAU_PEINT, 6, 1)
auberge_piece.poser(ARMOIRE, 11, 1, (0, 2, 2, 2))
auberge_piece.poser(LIT, 1, 3, (0, 0, 1, 3))
auberge_piece.poser(LIT, 4, 3, (0, 0, 1, 3))
auberge_piece.poser(GRAND_LIT, 14, 3, (0, 0, 2, 3))
auberge_piece.poser(PLANTE, 6, 5, (0, 1, 0, 1))
auberge_piece.poser(PLANTE_LARGE, 12, 5, (0, 1, 1, 1))
auberge_piece.poser(TAPIS_VERT, 7, 8)
auberge_piece.poser(TABLE_RONDE, 8, 7, (0, 1, 1, 2))
auberge_piece.poser(CHAISE_DROITE, 7, 7, (0, 1, 0, 1))
auberge_piece.poser(CHAISE_GAUCHE, 10, 7, (0, 1, 0, 1))
auberge_piece.poser(BAIGNOIRE, 1, 8, (0, 0, 2, 1))
auberge_piece.sortie(8, 10, 9, 10)
ecrire(auberge_piece.image, "interieur_auberge.png")

# ------------------------------------------------------------------ le plan
# Le village est dessiné sur une grille de cases de 16 pixels. Le même plan
# produit l'image du sol, la liste des objets à poser (le moteur les trie par
# profondeur) et la carte des cases bloquées : ce qu'on voit et ce qui arrête
# le joueur sortent de la même source, donc ne divergent jamais.
import json
import random

sols = ouvrir("Environment/Tilesets/Floors_Tiles.png")
eau = ouvrir("Environment/Tilesets/Water_tiles.png")
HERBE, PIERRE, TERRE = 0, 5, 10   # colonne de départ de chaque terrain
LARGEUR, HAUTEUR = 64, 52         # en cases → 1024 × 832 pixels


def pleine(terrain, x, y):
    """Une case pleine du terrain, en alternant ses trois variantes."""
    if terrain == "eau":
        # Les cases pleines du jeu d'eau : la plupart ridées, une lisse.
        vx, vy = [(1, 6), (2, 6), (3, 6), (1, 7), (2, 7), (3, 7), (1, 8), (2, 8), (3, 8)][(x * 5 + y * 11) % 9]
        return case(eau, vx * T, vy * T, T, T)
    variante = ((x * 7 + y * 13) % 3) + 1
    return case(sols, (terrain + variante) * T, 10 * T, T, T)


def gabarit(gx, gy):
    return case(sols, (HERBE + gx) * T, gy * T, T, T)


# Les trous dans l'herbe : une pierre pour l'esplanade, de la terre pour les
# chemins, de l'eau pour la mare. (terrain, x0, y0, x1, y1) en cases, exclusif.
TROUS = [
    (PIERRE, 16, 24, 48, 34),     # l'esplanade
    (TERRE, 30, 34, 34, 52),      # la grand-rue vers le sud
    (TERRE, 10, 20, 12, 28),      # le sentier de la maison de l'ouest
    (TERRE, 10, 26, 16, 28),
    (TERRE, 51, 20, 53, 26),      # le sentier de la grange
    (TERRE, 48, 24, 53, 26),
    ("eau", 8, 37, 14, 43),       # la mare
]
trou = {}
for terrain, x0, y0, x1, y1 in TROUS:
    for y in range(y0, y1):
        for x in range(x0, x1):
            trou[(x, y)] = terrain


def alpha_min(a, b):
    """Garde l'herbe là où les DEUX cases en ont : c'est ainsi qu'on compose
    un bord d'herbe qui tourne, à partir des seuls bords droits du pack."""
    c = a.copy()
    alpha = Image.eval(a.split()[3], lambda v: v)
    pa, pb, pc = a.split()[3].load(), b.split()[3].load(), alpha.load()
    for j in range(T):
        for i in range(T):
            pc[i, j] = min(pa[i, j], pb[i, j])
    c.putalpha(alpha)
    return c


sol = Image.new("RGBA", (LARGEUR * T, HAUTEUR * T))
for y in range(HAUTEUR):
    for x in range(LARGEUR):
        terrain = trou.get((x, y))
        sol.alpha_composite(pleine(HERBE if terrain is None else terrain, x, y), (x * T, y * T))
        if terrain is not None:
            continue
        # Une case d'herbe qui touche un trou reçoit le bord du pack pour
        # chaque côté concerné ; un coin rentrant se compose de deux bords.
        cote = {
            "haut": trou.get((x, y - 1)) is not None,
            "bas": trou.get((x, y + 1)) is not None,
            "gauche": trou.get((x - 1, y)) is not None,
            "droite": trou.get((x + 1, y)) is not None,
        }
        bords = []
        if cote["bas"]:
            bords.append(gabarit(2, 0))
        if cote["haut"]:
            bords.append(gabarit(2, 4))
        if cote["droite"]:
            bords.append(gabarit(0, 2))
        if cote["gauche"]:
            bords.append(gabarit(4, 2))
        if not bords:
            # Un trou seulement en diagonale : le coin arrondi du gabarit.
            for (dx, dy, gx, gy) in ((1, 1, 1, 1), (-1, 1, 3, 1), (1, -1, 1, 3), (-1, -1, 3, 3)):
                if trou.get((x + dx, y + dy)) is not None:
                    bords.append(gabarit(gx, gy))
        if bords:
            bord = bords[0]
            for autre in bords[1:]:
                bord = alpha_min(bord, autre)
            sol.alpha_composite(bord, (x * T, y * T))

# ------------------------------------------------------------------ les objets
# Chaque objet : son image, la case de son coin haut-gauche, et son emprise
# au sol (les cases qu'il bloque, relatives à son coin). L'image est posée
# entière ; l'emprise ne couvre que ce qu'on ne peut pas traverser à pied —
# un tronc, pas une cime.
TAILLES = {}                       # image -> (largeur, hauteur) en cases
EMPRISES = {}                      # image -> cases bloquées


def declarer(image, emprise):
    with Image.open(SORTIE / image) as im:
        TAILLES[image] = (im.width // T, im.height // T)
    EMPRISES[image] = emprise


bas = lambda l, h, lignes=1: [(x, y) for y in range(h - lignes, h) for x in range(l)]
for i in range(3):
    declarer(f"arbre_{i}.png", [(1, 5)])
    declarer(f"pin_{i}.png", [(1, 4)])
for i in range(4):
    declarer(f"buisson_{i}.png", bas(3, 3, 2))
    declarer(f"buisson_petit_{i}.png", bas(2, 2))
for i in range(2):
    declarer(f"rocher_grand_{i}.png", bas(2, 3, 2))
    declarer(f"rocher_moyen_{i}.png", bas(2, 2, 2))
    declarer(f"rocher_petit_{i}.png", bas(1, 1))
for nom in ("taverne", "armurerie", "auberge", "maison", "grange"):
    declarer(f"maison_{nom}.png", [(x, y) for y in (5, 6, 7) for x in range(1, 7)])
declarer("banc.png", bas(4, 2, 2))
declarer("caisses.png", bas(2, 2, 2))
declarer("foyer.png", bas(2, 2, 2))
declarer("cloture_h.png", bas(1, 1))
declarer("cloture_v.png", bas(1, 1))
declarer("jardiniere.png", bas(2, 2))
declarer("epouvantail.png", bas(2, 3))
declarer("forge.png", bas(4, 3, 2))
declarer("fourneau.png", bas(4, 4, 2))
for nom in ("carottes", "radis", "choux", "laitues"):
    declarer(f"culture_{nom}.png", bas(1, 1))
    declarer(f"cageot_{nom}.png", bas(1, 2))

objets = []
bloque = set()
occupe = set()                     # cases déjà prises par un objet (pour ne rien superposer)


def emprise_visuelle(image):
    """Les cases qu'un objet s'approprie : toute son image, sauf les arbres,
    dont seules les deux rangées du tronc comptent — leurs cimes se
    chevauchent, c'est ce qui fait une forêt."""
    l, h = TAILLES[image]
    depuis = h - 2 if image.startswith(("arbre_", "pin_")) else 0
    return [(x, y) for y in range(depuis, h) for x in range(l)]


def poser(image, cx, cy):
    objets.append({"image": image, "x": cx * T, "y": cy * T})
    for (dx, dy) in EMPRISES[image]:
        bloque.add((cx + dx, cy + dy))
    for (dx, dy) in emprise_visuelle(image):
        occupe.add((cx + dx, cy + dy))


def cloture(x0, y0, x1, y1, ouvertures=()):
    """Un enclos : lés horizontaux en haut et en bas, verticaux sur les côtés.
    `ouvertures` : cases laissées libres (le portillon)."""
    for x in range(x0, x1):
        for y in (y0, y1 - 1):
            if (x, y) not in ouvertures:
                poser("cloture_h.png", x, y)
    for y in range(y0 + 1, y1 - 1):
        for x in (x0, x1 - 1):
            if (x, y) not in ouvertures:
                poser("cloture_v.png", x, y)


# Les maisons, alignées sur le bord nord de l'esplanade, porte sur la place.
MAISONS = [
    ("armurerie", 17, 16, "ARMURERIE"),
    ("taverne", 28, 16, "TAVERNE"),
    ("auberge", 39, 16, "AUBERGE"),
    ("maison", 7, 12, "MAISON"),   # fermée : elle habille l'ouest
    ("grange", 48, 12, "GRANGE"),  # fermée : elle habille l'est
]
portes = []
for lieu, cx, cy, nom in MAISONS:
    poser(f"maison_{lieu}.png", cx, cy)
    portes.append({"lieu": lieu, "nom": nom,
                   "x": (cx + 3) * T, "y": (cy + 8) * T, "l": 2 * T, "h": T})

# Le cœur de l'esplanade : le feu, deux bancs, les cageots du marché.
poser("foyer.png", 31, 28)
poser("banc.png", 25, 28)
poser("banc.png", 35, 28)
poser("caisses.png", 36, 24)
for i, nom in enumerate(("carottes", "radis", "choux", "laitues")):
    poser(f"cageot_{nom}.png", 37 + i, 23)
poser("forge.png", 14, 22)         # l'enclume du forgeron, devant l'armurerie
poser("fourneau.png", 13, 18)      # et son fourneau, derrière
poser("jardiniere.png", 27, 23)
poser("jardiniere.png", 34, 23)

# Le potager de la grange : un enclos, des rangs de cultures, l'épouvantail.
cloture(49, 27, 58, 34, ouvertures={(51, 27), (52, 27)})
for i, nom in enumerate(("carottes", "radis", "choux", "laitues")):
    for x in range(50, 57):
        poser(f"culture_{nom}.png", x, 29 + i)
poser("epouvantail.png", 47, 29)
# Le jardin de la maison de l'ouest : des buissons fleuris derrière une clôture.
cloture(5, 29, 13, 35, ouvertures={(10, 29), (11, 29)})
for (x, y) in ((6, 30), (9, 30), (6, 32), (9, 32)):
    poser(f"buisson_{(x + y) % 4}.png", x, y)
# Autour de la mare : des rochers.
for image, x, y in (("rocher_grand_0.png", 6, 35), ("rocher_moyen_1.png", 14, 36),
                    ("rocher_moyen_0.png", 14, 42), ("rocher_petit_0.png", 8, 43),
                    ("rocher_grand_1.png", 15, 39), ("rocher_petit_1.png", 12, 44)):
    poser(image, x, y)

# Les ateliers animés : le moteur les anime, le plan leur réserve la place.
ANIMES = [
    {"image": "rotissoire.png", "cote": 64, "x": 22, "y": 22, "vitesse": 6, "emprise": bas(4, 4, 2)},
    {"image": "scierie.png", "cote": 80, "x": 54, "y": 20, "vitesse": 10, "emprise": bas(5, 4, 2)},
]
for a in ANIMES:
    TAILLES[a["image"]] = (a["cote"] // T, 4)
    EMPRISES[a["image"]] = a["emprise"]
    poser(a["image"], a["x"], a["y"])
    objets.pop()                    # il n'est pas un objet fixe : il part dans « animes »
    a["x"] *= T
    a["y"] *= T

# La clairière : tout ce qui est dehors est forêt, et infranchissable.
CLAIRIERE = (5, 9, 59, 47)         # x0, y0, x1, y1 exclusif


def dans_la_clairiere(x, y):
    x0, y0, x1, y1 = CLAIRIERE
    if x0 <= x < x1 and y0 <= y < y1:
        return True
    return 29 <= x <= 34 and y >= y1    # la grand-rue sort au sud


for y in range(HAUTEUR):
    for x in range(LARGEUR):
        if not dans_la_clairiere(x, y) or trou.get((x, y)) == "eau":
            bloque.add((x, y))

# La forêt : des arbres entiers, serrés mais jamais superposés à un autre
# objet, en dehors de la clairière ; quelques-uns dans ses coins.
hasard = random.Random(20260907)


def libre(image, cx, cy):
    l, h = TAILLES[image]
    if cx < 0 or cy < 0 or cx + l > LARGEUR or cy + h > HAUTEUR:
        return False
    return all((cx + x, cy + y) not in occupe for (x, y) in emprise_visuelle(image))


def arbre():
    return (f"arbre_{hasard.randrange(3)}.png" if hasard.random() < 0.65 else f"pin_{hasard.randrange(3)}.png")


essais = 0
plantes = 0
while plantes < 420 and essais < 60000:
    essais += 1
    image = arbre()
    l, h = TAILLES[image]
    cx, cy = hasard.randrange(LARGEUR - l + 1), hasard.randrange(HAUTEUR - h + 1)
    pied = (cx + 1, cy + h - 1)
    if dans_la_clairiere(*pied):
        continue
    if not libre(image, cx, cy):
        continue
    poser(image, cx, cy)
    plantes += 1
# Des bosquets dans les coins de la clairière, et des buissons épars.
for image, x, y in (("arbre_0.png", 6, 9), ("pin_1.png", 9, 10), ("arbre_2.png", 55, 9),
                    ("pin_0.png", 52, 10), ("arbre_1.png", 6, 43), ("pin_2.png", 54, 42),
                    ("arbre_0.png", 44, 40), ("arbre_1.png", 20, 40)):
    if libre(image, x, y):
        poser(image, x, y)
essais = 0
while essais < 4000 and len([o for o in objets if o["image"].startswith("buisson_petit")]) < 24:
    essais += 1
    image = f"buisson_petit_{hasard.randrange(2)}.png"
    cx, cy = hasard.randrange(LARGEUR), hasard.randrange(HAUTEUR)
    if not dans_la_clairiere(cx, cy + 1) or trou.get((cx, cy + 1)) or trou.get((cx + 1, cy + 1)) or trou.get((cx, cy)) or trou.get((cx + 1, cy)):
        continue
    if libre(image, cx, cy) and all(abs(cx - o["x"] // T) + abs(cy - o["y"] // T) > 6 for o in objets if o["image"].startswith("buisson_petit")):
        poser(image, cx, cy)

# Petites plantes et fleurs sur l'herbe libre.
plantes_sol = [case(vegetation, x * T, y * T, T, T) for (x, y) in ((4, 9), (0, 9), (2, 9), (1, 10), (3, 11))]
fleurs = [case(vegetation, x * T, y * T, T, T) for y in (23, 24, 25) for x in (3, 4, 6, 7)]
for _ in range(260):
    x, y = hasard.randrange(LARGEUR), hasard.randrange(HAUTEUR)
    if (x, y) in trou or (x, y) in occupe or not dans_la_clairiere(x, y):
        continue
    sol.alpha_composite(hasard.choice(plantes_sol) if hasard.random() < 0.6 else hasard.choice(fleurs), (x * T, y * T))
# Les ombres au sol, cuites dans l'image : le pack les dessine comme des
# ellipses noires à 15 % — on fait pareil, au pied de chaque objet.
from PIL import ImageDraw
ombres = Image.new("RGBA", sol.size, (0, 0, 0, 0))
dessin = ImageDraw.Draw(ombres)
for o in objets + [{"image": a["image"], "x": a["x"], "y": a["y"]} for a in ANIMES]:
    l, h = TAILLES[o["image"]]
    nom = o["image"]
    pied_x, pied_y = o["x"] + l * T // 2, o["y"] + h * T
    if nom.startswith(("arbre_", "pin_")):
        dessin.ellipse((pied_x - 18, pied_y - 9, pied_x + 18, pied_y + 3), fill=(0, 0, 0, 39))
    elif nom.startswith("buisson_petit"):
        dessin.ellipse((pied_x - 12, pied_y - 6, pied_x + 12, pied_y + 2), fill=(0, 0, 0, 39))
    elif nom.startswith("buisson_"):
        dessin.ellipse((pied_x - 20, pied_y - 8, pied_x + 20, pied_y + 3), fill=(0, 0, 0, 39))
    elif nom.startswith("rocher_grand"):
        dessin.ellipse((pied_x - 14, pied_y - 7, pied_x + 14, pied_y + 2), fill=(0, 0, 0, 39))
    elif nom.startswith("rocher_moyen"):
        dessin.ellipse((pied_x - 12, pied_y - 6, pied_x + 12, pied_y + 2), fill=(0, 0, 0, 39))
    elif nom.startswith("maison_"):
        # Le mur fait 96 de large sous le toit ; l'ombre s'étale à son pied
        # et déborde à droite, comme celles du pack (plus denses).
        dessin.rounded_rectangle((o["x"] + 14, pied_y - 6, o["x"] + 122, pied_y + 6), radius=4, fill=(0, 0, 0, 70))
        dessin.rectangle((o["x"] + 112, o["y"] + 96, o["x"] + 120, pied_y), fill=(0, 0, 0, 50))
    elif nom in ("banc.png", "forge.png", "caisses.png", "fourneau.png", "epouvantail.png", "rotissoire.png", "scierie.png"):
        dessin.ellipse((o["x"] + 4, pied_y - 6, o["x"] + l * T - 4, pied_y + 3), fill=(0, 0, 0, 39))
sol.alpha_composite(ombres)
ecrire(sol, "sol_village.png")

# Les objets se dessinent du plus haut au plus bas ; le moteur les trie par
# le bas de leur image, ce qui suffit puisque aucun ne se chevauche.
objets.sort(key=lambda o: (o["y"] + TAILLES[o["image"]][1] * T, o["x"]))


def carte(blocs, largeur, hauteur):
    return ["".join("#" if (x, y) in blocs else "." for x in range(largeur)) for y in range(hauteur)]


plan = {
    "case": T,
    "village": {
        "taille": [LARGEUR * T, HAUTEUR * T],
        "depart": [32 * T, 48 * T],
        "bloque": carte(bloque, LARGEUR, HAUTEUR),
        "objets": objets,
        "portes": portes,
        "feu": [32 * T, 30 * T],
        "animes": ANIMES,
        # La paysanne fait le tour de la place ; elle s'arrête pour parler.
        "rondes": {"paysanne": [[352, 416], [672, 416], [672, 528], [352, 528]]},
    },
}

# ------------------------------------------------------------------ intérieurs
# La zone de marche de chaque pièce, sur la grille de 16 de son image : on
# part d'une pièce entièrement bloquée, on LIBÈRE le sol, puis on rebloque
# les meubles. `S` marque la sortie, `P` le portail. Les rectangles sont en
# cases, bornes incluses, relevés sur l'image quadrillée (`grille_*.png`).


taverne = Masque(29, 22)
taverne.libre(3, 9, 27, 20).libre(0, 14, 2, 20)          # la salle et le tapis
taverne.libre(16, 3, 27, 5).libre(16, 6, 17, 8)          # l'alcôve et ses marches
taverne.bloque(5, 9, 9, 12).bloque(3, 11, 4, 12).bloque(5, 13, 8, 13)   # le comptoir, les tabourets
for col in (11, 18, 25):
    taverne.bloque(col, 9, col, 12)                      # les piliers du haut
for col in (4, 11, 18, 25):
    taverne.bloque(col, 15, col, 18)                     # les torchères du bas
taverne.bloque(13, 9, 16, 11).bloque(13, 13, 16, 15)     # les deux tables du milieu
taverne.bloque(19, 10, 24, 18)                           # la grande table bleue
taverne.bloque(5, 17, 10, 19).bloque(12, 17, 17, 19)     # les tables du bas
taverne.bloque(9, 16, 9, 16)                             # la cliente debout
taverne.bloque(18, 3, 20, 5).bloque(23, 3, 25, 5)        # les tables de l'alcôve
for col in (16, 21, 27):
    taverne.bloque(col, 3, col, 3)                       # les plantes
taverne.marquer("S", 0, 20, 2, 20).marquer("P", 10, 9, 10, 9).marquer("P", 12, 9, 12, 9)

armurerie = armurerie_piece.masque
auberge = auberge_piece.masque

INTERIEURS = {"taverne": taverne.lignes(), "armurerie": armurerie.lignes(), "auberge": auberge.lignes()}
for nom, lignes in INTERIEURS.items():
    with Image.open(SORTIE / f"interieur_{nom}.png") as im:
        largeur, hauteur = im.size
    colonnes = (largeur + T - 1) // T
    rangees = (hauteur + T - 1) // T
    assert len(lignes) == rangees and all(len(l) == colonnes for l in lignes), (nom, colonnes, rangees, len(lignes), [len(l) for l in lignes])
    sortie = [(x, y) for y, l in enumerate(lignes) for x, c in enumerate(l) if c == "S"]
    portail = [(x, y) for y, l in enumerate(lignes) for x, c in enumerate(l) if c == "P"]

    def rect(cases):
        if not cases:
            return None
        xs = [c[0] for c in cases]
        ys = [c[1] for c in cases]
        return [min(xs) * T, min(ys) * T, (max(xs) - min(xs) + 1) * T, (max(ys) - min(ys) + 1) * T]

    plan[nom] = {
        "taille": [largeur, hauteur],
        "bloque": ["".join("#" if c == "#" else "." for c in l) for l in lignes],
        "sortie": rect(sortie),
        "portail": rect(portail),
    }
# La serveuse fait le tour de la salle par l'allée du bas et celle de droite.
plan["taverne"]["rondes"] = {"serveuse": [[56, 328], [424, 328], [424, 152], [424, 328]]}

with open(SORTIE / "plan.json", "w", encoding="utf-8") as f:
    json.dump(plan, f, ensure_ascii=False, indent=1)
print("plan.json écrit :", len(objets), "objets,", len(bloque), "cases bloquées")

# Calques de vérification : la carte des cases bloquées posée sur l'image.
if True:
    def calque(nom, image, lignes, k=3):
        im = image.convert("RGBA")
        voile = Image.new("RGBA", im.size, (0, 0, 0, 0))
        px = voile.load()
        for y, l in enumerate(lignes):
            for x, c in enumerate(l):
                if c == "#":
                    for j in range(T):
                        for i in range(T):
                            if x * T + i < im.width and y * T + j < im.height:
                                px[x * T + i, y * T + j] = (255, 0, 0, 90)
        im.alpha_composite(voile)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        im.convert("RGB").save(f"/tmp/apercu/calque_{nom}.png")
    for nom in INTERIEURS:
        with Image.open(SORTIE / f"interieur_{nom}.png") as im:
            calque(nom, im, plan[nom]["bloque"], 3)

# Aperçu complet du village (sol + objets), pour juger le plan sans le moteur.
apercu = sol.copy()
for o in objets:
    with Image.open(SORTIE / o["image"]) as im:
        apercu.alpha_composite(im.convert("RGBA"), (o["x"], o["y"]))
apercu.convert("RGB").save("/tmp/apercu/village_complet.png")
calque("village", apercu, plan["village"]["bloque"], 1)
