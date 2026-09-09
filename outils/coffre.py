#!/usr/bin/env python3
"""Le COFFRE des repaires : le seul meuble du jeu qui ne vienne pas d'un kit.

Kenney n'a pas de coffre-fort, et c'est le meuble le plus important de la
pièce — c'est là qu'on range l'argent. On le fabrique donc en boîtes, à la
main, dans le style du kit : faces plates, pas de texture, une matière NOMMÉE
par pièce pour que chaque intérieur puisse le repeindre comme le reste.

⚠ La façade regarde +Z, comme tout le kit (cf. `interieurs.gd`), sinon il
s'adosse à l'envers et la porte donne dans le mur.

⚠ La matière du voyant s'appelle `lamp` À DESSEIN : `Interieurs._teinter` rend
émissive toute matière de ce nom, donc la diode s'allume sans une ligne de plus,
et le joueur repère le coffre dans une pièce sombre.

    python3 outils/coffre.py   ->  modeles/interieur/coffre.glb
"""
import json, struct, os

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Les matières, dans le vocabulaire du kit : un nom, une couleur linéaire.
MATIERES = [
    ("acier",       [0.150, 0.160, 0.172, 1.0]),
    ("acierClair",  [0.245, 0.262, 0.280, 1.0]),
    ("acierSombre", [0.070, 0.076, 0.082, 1.0]),
    ("laiton",      [0.620, 0.430, 0.110, 1.0]),
    ("lamp",        [0.050, 0.700, 0.180, 1.0]),
]
INDEX = {n: i for i, (n, _) in enumerate(MATIERES)}

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

FACES = [  # (normale, quatre coins en signes de demi-dimensions)
    ((0, 0, 1),  [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
    ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)]),
    ((1, 0, 0),  [(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)]),
    ((-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
    ((0, 1, 0),  [(-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)]),
    ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
]

groupes = {n: {"p": [], "n": [], "i": []} for n, _ in MATIERES}
for (cx, cy, cz), (hx, hy, hz), mat in BOITES:
    g = groupes[mat]
    for normale, coins in FACES:
        base = len(g["p"]) // 3
        for sx, sy, sz in coins:
            g["p"] += [cx + sx * hx, cy + sy * hy, cz + sz * hz]
            g["n"] += list(normale)
        g["i"] += [base, base + 1, base + 2, base, base + 2, base + 3]

tampon = bytearray()
accesseurs, vues, primitives = [], [], []


def ajouter(donnees, cible, compte, genre, composant, mini=None, maxi=None):
    while len(tampon) % 4:
        tampon.append(0)
    debut = len(tampon)
    tampon.extend(donnees)
    vues.append({"buffer": 0, "byteOffset": debut, "byteLength": len(donnees), "target": cible})
    a = {"bufferView": len(vues) - 1, "componentType": composant, "count": compte, "type": genre}
    if mini is not None:
        a["min"], a["max"] = mini, maxi
    accesseurs.append(a)
    return len(accesseurs) - 1


for nom, _ in MATIERES:
    g = groupes[nom]
    if not g["p"]:
        continue
    nb = len(g["p"]) // 3
    mini = [min(g["p"][k::3]) for k in range(3)]
    maxi = [max(g["p"][k::3]) for k in range(3)]
    ap = ajouter(struct.pack("<%df" % len(g["p"]), *g["p"]), 34962, nb, "VEC3", 5126, mini, maxi)
    an = ajouter(struct.pack("<%df" % len(g["n"]), *g["n"]), 34962, nb, "VEC3", 5126)
    ai = ajouter(struct.pack("<%dH" % len(g["i"]), *g["i"]), 34963, len(g["i"]), "SCALAR", 5123)
    primitives.append({"attributes": {"POSITION": ap, "NORMAL": an}, "indices": ai,
                       "material": INDEX[nom]})

gltf = {
    "asset": {"version": "2.0", "generator": "Piks-l outils/coffre.py"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"mesh": 0, "name": "coffre"}],
    "meshes": [{"name": "coffre", "primitives": primitives}],
    "materials": [{"name": n, "pbrMetallicRoughness":
                   {"baseColorFactor": c, "metallicFactor": 0.0, "roughnessFactor": 0.55},
                   "doubleSided": False} for n, c in MATIERES],
    "accessors": accesseurs,
    "bufferViews": vues,
    "buffers": [{"byteLength": len(tampon)}],
}
js = json.dumps(gltf, separators=(",", ":")).encode()
js += b" " * (-len(js) % 4)
bi = bytes(tampon) + b"\0" * (-len(tampon) % 4)
glb = (struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bi))
       + struct.pack("<II", len(js), 0x4E4F534A) + js
       + struct.pack("<II", len(bi), 0x004E4942) + bi)
sortie = os.path.join(RACINE, "modeles", "interieur", "coffre.glb")
open(sortie, "wb").write(glb)
print("coffre.glb : %d triangles, %d octets" % (sum(len(g["i"]) for g in groupes.values()) // 3, len(glb)))
