#!/usr/bin/env python3
"""Écrire un meuble en BOÎTES dans un .glb, dans le style du kit Kenney.

Kenney n'a ni coffre-fort ni râtelier d'armes, et ce sont les deux meubles les
plus importants des intérieurs : c'est là qu'on range l'argent et les fusils.
On les fabrique donc à la main, en boîtes, faces plates et sans texture — une
matière NOMMÉE par pièce, pour que chaque intérieur puisse les repeindre comme
le reste du mobilier (`Interieurs._teinter`).

⚠ Ce fichier existe parce que `coffre.py` et `ratelier.py` partageaient
quatre-vingt-dix lignes de tampon glTF identiques au caractère près. Le
troisième meuble aurait fait une troisième copie, et la première correction de
normale n'en aurait touché qu'une.

⚠ LA FAÇADE REGARDE +Z, comme tout le kit (cf. `interieurs.gd`). Un meuble
dessiné à l'envers s'adosse à l'envers et sa porte donne dans le mur.

⚠ La matière nommée `lamp` est rendue ÉMISSIVE par `Interieurs._teinter` : une
diode s'allume sans une ligne de plus, et le meuble se repère dans une pièce
sombre. C'est une convention, pas un hasard — ne pas renommer.
"""
import json, struct, os

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FACES = [  # (normale, quatre coins en signes de demi-dimensions)
    ((0, 0, 1),  [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
    ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)]),
    ((1, 0, 0),  [(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)]),
    ((-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
    ((0, 1, 0),  [(-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)]),
    ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
]


def ecrire(nom, matieres, boites, sortie):
    """`matieres` : [(nom, couleur linéaire RGBA)]. `boites` : [(centre,
    demi-dimensions, nom de matière)]. `sortie` : chemin relatif à la racine."""
    index = {n: i for i, (n, _) in enumerate(matieres)}
    groupes = {n: {"p": [], "n": [], "i": []} for n, _ in matieres}
    for (cx, cy, cz), (hx, hy, hz), mat in boites:
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

    for m, _ in matieres:
        g = groupes[m]
        if not g["p"]:
            continue
        nb = len(g["p"]) // 3
        mini = [min(g["p"][k::3]) for k in range(3)]
        maxi = [max(g["p"][k::3]) for k in range(3)]
        ap = ajouter(struct.pack("<%df" % len(g["p"]), *g["p"]), 34962, nb, "VEC3", 5126, mini, maxi)
        an = ajouter(struct.pack("<%df" % len(g["n"]), *g["n"]), 34962, nb, "VEC3", 5126)
        ai = ajouter(struct.pack("<%dH" % len(g["i"]), *g["i"]), 34963, len(g["i"]), "SCALAR", 5123)
        primitives.append({"attributes": {"POSITION": ap, "NORMAL": an}, "indices": ai,
                           "material": index[m]})

    gltf = {
        "asset": {"version": "2.0", "generator": "Piks-l outils/meuble.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": nom}],
        "meshes": [{"name": nom, "primitives": primitives}],
        "materials": [{"name": n, "pbrMetallicRoughness":
                       {"baseColorFactor": c, "metallicFactor": 0.0, "roughnessFactor": 0.55},
                       "doubleSided": False} for n, c in matieres],
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
    chemin = os.path.join(RACINE, sortie)
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    open(chemin, "wb").write(glb)
    print("%s : %d triangles, %d octets"
          % (os.path.basename(chemin), sum(len(g["i"]) for g in groupes.values()) // 3, len(glb)))
