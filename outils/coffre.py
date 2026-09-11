#!/usr/bin/env python3
"""Le COFFRE des repaires : de l'acier, une molette, une diode.

Kenney n'a pas de coffre-fort, et c'est le meuble le plus important de la
pièce — c'est là qu'on range l'argent. Le tampon glTF et les conventions du kit
vivent dans `outils/meuble.py` ; ici, il ne reste que la forme.

    python3 outils/coffre.py   ->  modeles/interieur/coffre.glb
"""
import os, sys
# Appelé depuis la racine du projet (`python3 outils/coffre.py`), le dossier
# du script n'est PAS dans le chemin d'import : sans cette ligne, `meuble`
# reste introuvable et la seule façon de fabriquer le meuble est de se
# déplacer d'abord — ce que personne ne lit dans une docstring.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meuble

# Les matières, dans le vocabulaire du kit : un nom, une couleur linéaire.
MATIERES = [
    ("acier",       [0.150, 0.160, 0.172, 1.0]),
    ("acierClair",  [0.245, 0.262, 0.280, 1.0]),
    ("acierSombre", [0.070, 0.076, 0.082, 1.0]),
    ("laiton",      [0.620, 0.430, 0.110, 1.0]),
    ("lamp",        [0.050, 0.700, 0.180, 1.0]),
]

# Un coffre de soixante centimètres : 0,30 × 0,34 × 0,26 en unités de kit, soit
# 0,60 × 0,68 × 0,52 m une fois l'échelle du jeu appliquée. Posé au sol, porte
# vers +Z. Les boîtes sont données en (centre, demi-dimensions, matière).
L, H, P = 0.30, 0.34, 0.26
PIED = 0.022
BOITES = [
    # corps, monté sur quatre petits pieds
    ((0, PIED + (H - PIED) / 2, -P / 2), (L / 2, (H - PIED) / 2, P / 2), "acier"),
    ((-L / 2 + 0.03, PIED / 2, -0.03), (0.026, PIED / 2, 0.026), "acierSombre"),
    (( L / 2 - 0.03, PIED / 2, -0.03), (0.026, PIED / 2, 0.026), "acierSombre"),
    ((-L / 2 + 0.03, PIED / 2, -P + 0.03), (0.026, PIED / 2, 0.026), "acierSombre"),
    (( L / 2 - 0.03, PIED / 2, -P + 0.03), (0.026, PIED / 2, 0.026), "acierSombre"),
    # la porte, en léger relief : c'est elle qui dit de quel côté on ouvre
    ((0, PIED + (H - PIED) / 2, 0.012), (L / 2 - 0.028, (H - PIED) / 2 - 0.028, 0.014), "acierClair"),
    # la molette et sa croix de manœuvre
    ((0.055, H * 0.55, 0.030), (0.043, 0.043, 0.018), "laiton"),
    ((0.055, H * 0.55, 0.044), (0.056, 0.010, 0.008), "laiton"),
    ((0.055, H * 0.55, 0.044), (0.010, 0.056, 0.008), "laiton"),
    # la poignée
    ((-0.078, H * 0.55, 0.034), (0.012, 0.052, 0.014), "laiton"),
    # la diode : allumée d'office par la matière `lamp`
    ((-0.078, H * 0.80, 0.032), (0.013, 0.013, 0.010), "lamp"),
]

meuble.ecrire("coffre", MATIERES, BOITES, "modeles/interieur/coffre.glb")
