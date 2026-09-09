#!/usr/bin/env python3
"""L'empreinte au sol RÉELLE de chaque modèle, en grille de 16 sur 16.

Pourquoi pas la boîte englobante : un bureau d'angle, un canapé d'angle, une
chaise à pieds, une table — tout ce qui a un creux — occupe la moitié de sa
boîte. Testés à la boîte, ils se « chevauchent » à chaque fois qu'on range
quelque chose dans leur angle, et les vrais défauts se noient dans le bruit.

On relit le paquet de géométrie de l'Établi (`outils/paquet.py`) et on RASTÉRISE
les triangles au sol — pas les sommets. Sur du lowpoly la différence est totale :
un lit est six quadrilatères, ses sommets ne marquent que huit coins et le
milieu du matelas passe pour du vide. On garde la hauteur maximale par case : c'est ce qui permet de dire qu'une lampe
posée sur une table ne la traverse pas, et qu'un tabouret glissé sous un bar
n'est pas un défaut.

    python3 outils/paquet.py && python3 outils/empreintes.py
        -> _transfert/vitrine/empreintes.json
"""
import base64, gzip, json, os, struct, array

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(RACINE, '_transfert', 'vitrine')
N = 16

index = json.load(open(os.path.join(T, 'paquet-index.json'), encoding='utf-8'))
tampon = gzip.decompress(base64.b64decode(open(os.path.join(T, 'paquet.b64')).read()))

sortie = {}
for nom, f in index['modeles'].items():
    lo, ech = f['lo'], f['ech']
    cases = [[0.0] * N for _ in range(N)]      # hauteur max par case, en unités
    for g in f['g']:
        q = array.array('H')
        q.frombytes(tampon[g['po']:g['po'] + g['nv'] * 6])
        idx = array.array('I' if g.get('i32') else 'H')
        idx.frombytes(tampon[g['io']:g['io'] + g['ni'] * (4 if g.get('i32') else 2)])
        for t in range(0, len(idx) - 2, 3):
            a, b, c = idx[t], idx[t + 1], idx[t + 2]
            px = [q[a * 3] * N / 65535.0, q[b * 3] * N / 65535.0, q[c * 3] * N / 65535.0]
            pz = [q[a * 3 + 2] * N / 65535.0, q[b * 3 + 2] * N / 65535.0, q[c * 3 + 2] * N / 65535.0]
            h = max(q[a * 3 + 1], q[b * 3 + 1], q[c * 3 + 1]) / 65535.0 * ech[1]
            i0 = max(0, int(min(px))); i1 = min(N - 1, int(max(px)))
            j0 = max(0, int(min(pz))); j1 = min(N - 1, int(max(pz)))
            aire = ((px[1] - px[0]) * (pz[2] - pz[0]) - (px[2] - px[0]) * (pz[1] - pz[0]))
            for j in range(j0, j1 + 1):
                for i in range(i0, i1 + 1):
                    if h <= cases[j][i]:
                        continue
                    x, z = i + 0.5, j + 0.5
                    if abs(aire) < 1e-9:
                        # triangle vu par la tranche : il ne couvre qu'une ligne
                        dedans = (i0 == i1 or j0 == j1)
                    else:
                        w0 = ((px[1] - x) * (pz[2] - z) - (px[2] - x) * (pz[1] - z)) / aire
                        w1 = ((px[2] - x) * (pz[0] - z) - (px[0] - x) * (pz[2] - z)) / aire
                        w2 = 1.0 - w0 - w1
                        dedans = w0 >= -0.02 and w1 >= -0.02 and w2 >= -0.02
                    if dedans:
                        cases[j][i] = h
    # Une case n'est « pleine » que si de la matière y monte : un plateau de
    # table couvre tout, ses pieds non — mais le plateau est EN HAUTEUR, et
    # c'est la hauteur qui dira si une chaise passe dessous.
    sortie[nom] = {'lo': lo, 'ech': ech,
                   'h': [[round(v, 3) for v in ligne] for ligne in cases]}
json.dump(sortie, open(os.path.join(T, 'empreintes.json'), 'w'), separators=(',', ':'))
print('%d empreintes, %d ko' % (len(sortie), os.path.getsize(os.path.join(T, 'empreintes.json')) // 1024))
