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

if len(sys.argv) != 2:
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
ecrire(piece(0, 352, 640, 436), "interieur_armurerie.png")     # le couloir aux armes
ecrire(piece(136, 472, 278, 633), "interieur_auberge.png")     # une chambre

# ------------------------------------------------------------------ le sol
# Le jeu de sols du pack fonctionne par « trous » : un anneau de cases de
# terrain A entoure un trou de bords irréguliers où l'on voit le terrain B
# posé dessous. On remplit donc d'herbe, on pose la pierre de la place, et
# l'on borde la place avec l'anneau d'herbe : c'est exactement l'usage prévu.
sols = ouvrir("Environment/Tilesets/Floors_Tiles.png")
HERBE, PIERRE = 0, 5              # colonne de départ de chaque terrain
LARGEUR, HAUTEUR = 48, 34         # en cases → 768 × 544 pixels
PLACE = (12, 14, 36, 26)          # le trou (x0, y0, x1, y1), en cases, exclusif


def pleine(terrain, x, y):
    variante = [(1, 10), (2, 10), (3, 10)][(x * 7 + y * 13) % 3]
    return case(sols, (terrain + variante[0]) * T, variante[1] * T, T, T)


def gabarit(terrain, gx, gy):
    return case(sols, (terrain + gx) * T, gy * T, T, T)


sol = Image.new("RGBA", (LARGEUR * T, HAUTEUR * T))
for y in range(HAUTEUR):
    for x in range(LARGEUR):
        sol.alpha_composite(pleine(HERBE, x, y), (x * T, y * T))
x0, y0, x1, y1 = PLACE
for y in range(y0, y1):
    for x in range(x0, x1):
        sol.alpha_composite(pleine(PIERRE, x, y), (x * T, y * T))
        # Les quatre coins du trou sont arrondis par une case dédiée.
        coin = (1 if x == x0 else 3 if x == x1 - 1 else None,
                1 if y == y0 else 3 if y == y1 - 1 else None)
        if coin[0] and coin[1]:
            sol.alpha_composite(gabarit(HERBE, *coin), (x * T, y * T))
for x in range(x0, x1):
    gx = 1 if x == x0 else 3 if x == x1 - 1 else 2
    sol.alpha_composite(gabarit(HERBE, gx, 0), (x * T, (y0 - 1) * T))
    sol.alpha_composite(gabarit(HERBE, gx, 4), (x * T, y1 * T))
for y in range(y0, y1):
    gy = 1 if y == y0 else 3 if y == y1 - 1 else 2
    sol.alpha_composite(gabarit(HERBE, 0, gy), ((x0 - 1) * T, y * T))
    sol.alpha_composite(gabarit(HERBE, 4, gy), (x1 * T, y * T))

# Petites plantes et fleurs (cases de 16 de la planche de végétation),
# semées sur l'herbe seulement.
hasard = random.Random(20260907)
plantes = [case(vegetation, x * T, y * T, T, T) for (x, y) in ((4, 9), (0, 9), (2, 9), (1, 10), (3, 11))]
fleurs = [case(vegetation, x * T, y * T, T, T) for y in (23, 24, 25) for x in (3, 4, 6, 7)]
for _ in range(140):
    x, y = hasard.randrange(LARGEUR), hasard.randrange(HAUTEUR)
    if x0 - 1 <= x <= x1 and y0 - 1 <= y <= y1:
        continue
    motif = hasard.choice(plantes) if hasard.random() < 0.6 else hasard.choice(fleurs)
    sol.alpha_composite(motif, (x * T, y * T))
ecrire(sol, "sol_village.png")
