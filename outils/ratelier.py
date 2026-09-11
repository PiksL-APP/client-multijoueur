#!/usr/bin/env python3
"""Le RÂTELIER des repaires de gang : trois fusils sur un panneau, et la caisse
de munitions au pied.

Kenney n'a pas d'arme — le kit est un kit de meubles — et c'est justement le
meuble qui donne une raison de franchir la porte d'un repaire : c'est là qu'on
achète l'arme du gang. Une bibliothèque ouverte y aurait fait l'affaire dans le
code et pas du tout à l'écran, où l'on ne voit que la silhouette.

Le tampon glTF et les conventions du kit vivent dans `outils/meuble.py`.

    python3 outils/ratelier.py   ->  modeles/interieur/ratelier.glb
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meuble

# Les matières portent les noms du kit là où elles existent (`wood`,
# `metalDark`) : un intérieur qui repeint son bois repeint le râtelier sans
# rien savoir de lui.
MATIERES = [
    ("wood",        [0.230, 0.150, 0.085, 1.0]),
    ("woodDark",    [0.120, 0.078, 0.045, 1.0]),
    ("metal",       [0.180, 0.190, 0.200, 1.0]),
    ("metalDark",   [0.062, 0.068, 0.074, 1.0]),
    ("laiton",      [0.620, 0.430, 0.110, 1.0]),
    ("lamp",        [0.700, 0.120, 0.060, 1.0]),
]

# Un panneau de 0,90 × 0,78 en unités de kit, soit 1,80 × 1,56 m en jeu : la
# hauteur d'un homme, ce qu'il faut pour qu'on le voie de la porte. Adossé à un
# mur, donc tout le volume part vers −Z depuis la façade en z = 0.
L, H, P = 0.90, 0.78, 0.14
BOITES = [
    # le panneau, et son cadre
    ((0, H / 2, -P + 0.02), (L / 2, H / 2, 0.02), "woodDark"),
    ((0, H - 0.02, -P + 0.07), (L / 2, 0.02, 0.07), "wood"),
    ((0, 0.03, -P + 0.07), (L / 2, 0.03, 0.07), "wood"),
    ((-L / 2 + 0.02, H / 2, -P + 0.07), (0.02, H / 2, 0.07), "wood"),
    ((L / 2 - 0.02, H / 2, -P + 0.07), (0.02, H / 2, 0.07), "wood"),
]

# TROIS FUSILS, debout, régulièrement espacés. Chacun tient en quatre boîtes :
# le canon, le boîtier, la crosse, le chargeur. C'est le minimum qui donne une
# silhouette d'arme et pas de bâton — le chargeur en oblique est ce qui la
# rend lisible de loin, plus que la longueur du canon.
for k, x in enumerate((-0.28, 0.0, 0.28)):
    z = -P + 0.10
    BOITES += [
        ((x, 0.52, z), (0.014, 0.20, 0.014), "metalDark"),          # canon
        ((x, 0.30, z), (0.035, 0.075, 0.030), "metal"),             # boîtier
        ((x, 0.14, z), (0.030, 0.090, 0.026), "woodDark"),          # crosse
        ((x + 0.055, 0.26, z), (0.020, 0.055, 0.016), "metalDark"), # chargeur
    ]

# LA CAISSE DE MUNITIONS au pied du panneau : c'est elle qui pose le meuble au
# sol. Sans elle, trois fusils flottaient sur une planche et le râtelier
# n'avait ni assise ni ombre — vu de trois quarts, il ressemblait à un poster.
BOITES += [
    ((-0.24, 0.075, -0.16), (0.20, 0.075, 0.13), "metalDark"),
    ((-0.24, 0.158, -0.16), (0.205, 0.010, 0.135), "metal"),
    ((-0.24, 0.158, -0.03), (0.05, 0.014, 0.008), "laiton"),
    # La diode du râtelier : matière `lamp`, donc émissive d'office. C'est ce
    # qui distingue l'armurerie d'une étagère dans une pièce mal éclairée.
    ((0.40, H - 0.09, -P + 0.10), (0.022, 0.022, 0.012), "lamp"),
]

meuble.ecrire("ratelier", MATIERES, BOITES, "modeles/interieur/ratelier.glb")
