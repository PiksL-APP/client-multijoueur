"""Dessine les traces du banc de trafic.

    godot --headless -s outils/trafic.gd --duree=60 --traces=/tmp/traces.csv
    python3 outils/traces.py /tmp/traces.csv /tmp/traces.png

Le fond, ce sont les tuiles (eau, bâti, rue, boulevard, pâté) ; par-dessus,
la trajectoire de chaque voiture (une couleur par voiture) et, plus fins, les
passants. Un virage pris d'un coup se lit comme un angle vif ; un arc, comme
un arc. Une voiture dans l'eau se voit tout de suite.
"""
import csv
import sys
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

PAS = 100.0
COULEURS_SOL = {"eau": "#7fb3e0", "bati": "#5a5f6a", "rue": "#d8d8d8", "boulevard": "#e8dcc0", "pate": "#b9c9a6"}

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else src.rsplit(".", 1)[0] + ".png"
fond = src.rsplit(".", 1)[0] + "_fond.csv"

autos = defaultdict(list)
gens = defaultdict(list)
with open(src, encoding="utf-8") as f:
    for ligne in csv.DictReader(f, delimiter=";"):
        (autos if ligne["genre"] == "auto" else gens)[ligne["id"]].append((float(ligne["x"]), float(ligne["y"])))

fig, ax = plt.subplots(figsize=(12, 12), dpi=110)
xs, ys = [], []
with open(fond, encoding="utf-8") as f:
    for ligne in csv.DictReader(f, delimiter=";"):
        c, l = int(ligne["c"]), int(ligne["l"])
        ax.add_patch(Rectangle((c * PAS, l * PAS), PAS, PAS, facecolor=COULEURS_SOL[ligne["sol"]], edgecolor="none"))
        xs.append(c * PAS); ys.append(l * PAS)
x0, x1 = min(xs), max(xs) + PAS
y0, y1 = min(ys), max(ys) + PAS

cmap = plt.get_cmap("tab20")
for k, (ident, pts) in enumerate(autos.items()):
    pts = [p for p in pts if x0 <= p[0] <= x1 and y0 <= p[1] <= y1]
    if len(pts) < 2:
        continue
    ax.plot([p[0] for p in pts], [p[1] for p in pts], color=cmap(k % 20), linewidth=1.6, alpha=0.9)
    ax.plot(pts[-1][0], pts[-1][1], "o", color=cmap(k % 20), markersize=4)
for k, (ident, pts) in enumerate(gens.items()):
    pts = [p for p in pts if x0 <= p[0] <= x1 and y0 <= p[1] <= y1]
    if len(pts) < 2:
        continue
    ax.plot([p[0] for p in pts], [p[1] for p in pts], color="#c0392b", linewidth=0.7, alpha=0.7)

ax.set_xlim(x0, x1)
ax.set_ylim(y1, y0)   # y vers le bas, comme le jeu
ax.set_aspect("equal")
ax.set_xticks([]); ax.set_yticks([])
ax.set_title("Traces du trafic — voitures (couleurs), passants (rouge fin), eau (bleu)")
fig.tight_layout()
fig.savefig(dst)
print("écrit", dst, "—", len(autos), "voitures,", len(gens), "passants")
