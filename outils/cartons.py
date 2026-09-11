"""Les cartons sur la tête : la texture des boîtes et la planche des logos.

    python3 outils/logos.py             # d'abord : les SVG
    node outils/logos_png.mjs           # puis : les PNG 256 × 256
    python3 outils/cartons.py           # enfin : ce fichier

Écrit :
  modeles/cartons/planche.png   un atlas 8 × 8 de tuiles de 256 : les 55 logos
                                posés sur du carton kraft, puis trois tuiles de
                                service — carton nu, dessus avec son ruban,
                                dessous avec ses rabats. Une seule texture pour
                                toute la boîte : un seul envoi, une seule matière.
  modeles/cartons/cartons.json  le catalogue (indice, clé, nom, phrase, groupe)
                                que lit `Personnages` — et le kit web.
  web/kit/logos/NN_cle.png      les logos seuls, fond transparent, pour la page.
"""
import json
import math
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

RACINE = Path(__file__).resolve().parent.parent
LOGOS = RACINE / "_transfert" / "logos"
SORTIE = RACINE / "modeles" / "cartons"
KIT = RACINE / "web" / "kit" / "logos"
T = 256
COLONNES = 8
LIGNES = 8
TUILE_NU = 55       # carton sans rien : les côtés et l'arrière
TUILE_DESSUS = 56   # le ruban adhésif
TUILE_DESSOUS = 57  # les rabats du fond

random.seed(7)


def kraft(graine: int) -> Image.Image:
    """Une tuile de carton : un kraft chaud, grain fin, et les cannelures qui
    affleurent à peine — le carton d'un déménagement, pas un cuir."""
    rng = random.Random(graine)
    base = Image.new("RGB", (T, T), (201, 160, 110))
    px = base.load()
    for y in range(T):
        # Les cannelures : une ondulation horizontale très douce.
        onde = 6 * math.sin(y * 0.55)
        for x in range(T):
            g = rng.randint(-9, 9)
            r, v, b = px[x, y]
            px[x, y] = (
                max(0, min(255, int(r + g + onde))),
                max(0, min(255, int(v + g * 0.9 + onde * 0.8))),
                max(0, min(255, int(b + g * 0.7 + onde * 0.5))),
            )
    base = base.filter(ImageFilter.GaussianBlur(0.6))
    # Quelques fibres : des traits clairs, longs et rares.
    d = ImageDraw.Draw(base, "RGBA")
    for _ in range(26):
        x0 = rng.randint(0, T)
        y0 = rng.randint(0, T)
        lg = rng.randint(14, 60)
        d.line([(x0, y0), (x0 + lg, y0 + rng.randint(-2, 2))], fill=(255, 235, 200, 38), width=1)
    for _ in range(18):
        x0 = rng.randint(0, T)
        y0 = rng.randint(0, T)
        lg = rng.randint(10, 40)
        d.line([(x0, y0), (x0 + lg, y0 + rng.randint(-2, 2))], fill=(90, 60, 30, 30), width=1)
    # Les bords : un peu plus sombres, comme une arête de boîte.
    for e in range(6):
        a = 70 - e * 11
        d.rectangle([e, e, T - 1 - e, T - 1 - e], outline=(60, 38, 18, a))
    return base


def ruban(t: Image.Image) -> Image.Image:
    """Le dessus : une bande de ruban brun, luisante, sur la fente entre les
    deux rabats."""
    d = ImageDraw.Draw(t, "RGBA")
    # La fente entre les rabats.
    d.line([(T // 2, 8), (T // 2, T - 8)], fill=(70, 45, 22, 140), width=3)
    # Le ruban, un peu de travers, comme collé à la main.
    bande = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bande)
    bd.polygon([(T // 2 - 30, 0), (T // 2 + 34, 0), (T // 2 + 30, T), (T // 2 - 34, T)],
               fill=(120, 78, 40, 150))
    bd.polygon([(T // 2 - 22, 0), (T // 2 - 14, 0), (T // 2 - 18, T), (T // 2 - 26, T)],
               fill=(255, 230, 190, 60))
    t.paste(bande, (0, 0), bande)
    return t


def rabats(t: Image.Image) -> Image.Image:
    """Le dessous : quatre rabats, deux fentes, sans ruban."""
    d = ImageDraw.Draw(t, "RGBA")
    d.line([(T // 2, 6), (T // 2, T - 6)], fill=(70, 45, 22, 150), width=3)
    d.line([(6, T // 2), (T // 2, T // 2)], fill=(70, 45, 22, 120), width=2)
    d.line([(T // 2, T // 2), (T - 6, T // 2)], fill=(70, 45, 22, 120), width=2)
    return t


def face_logo(t: Image.Image, logo: Image.Image) -> Image.Image:
    """La face avant : le logo au marqueur, un peu absorbé par le carton (le
    feutre bave, il ne brille pas) et deux trous pour les yeux."""
    encre = logo.convert("RGBA")
    # L'encre s'assombrit et s'assèche dans le kraft : on baisse l'alpha.
    r, v, b, a = encre.split()
    a = a.point(lambda p: int(p * 0.88))
    encre = Image.merge("RGBA", (r, v, b, a))
    t = t.convert("RGBA")
    t.alpha_composite(encre)
    d = ImageDraw.Draw(t, "RGBA")
    # Les trous pour voir : deux fentes noires en haut, comme un déguisement.
    for cx in (T * 0.36, T * 0.64):
        d.rounded_rectangle([cx - 20, 18, cx + 20, 30], radius=6, fill=(20, 12, 8, 230))
    return t.convert("RGB")


def main() -> None:
    catalogue = json.loads((LOGOS / "logos.json").read_text(encoding="utf-8"))
    assert len(catalogue) <= TUILE_NU, "plus de logos que de tuiles libres"
    SORTIE.mkdir(parents=True, exist_ok=True)
    KIT.mkdir(parents=True, exist_ok=True)
    for vieux in KIT.glob("*.png"):
        vieux.unlink()

    planche = Image.new("RGB", (T * COLONNES, T * LIGNES), (201, 160, 110))
    for fiche in catalogue:
        i = int(fiche["indice"])
        nom_png = f"{i:02d}_{fiche['cle']}.png"
        logo = Image.open(LOGOS / "png" / nom_png)
        tuile = face_logo(kraft(i), logo)
        planche.paste(tuile, ((i % COLONNES) * T, (i // COLONNES) * T))
        shutil.copy(LOGOS / "png" / nom_png, KIT / nom_png)
    for i in range(len(catalogue), COLONNES * LIGNES):
        tuile = kraft(100 + i)
        if i == TUILE_DESSUS:
            tuile = ruban(tuile)
        elif i == TUILE_DESSOUS:
            tuile = rabats(tuile)
        planche.paste(tuile, ((i % COLONNES) * T, (i // COLONNES) * T))
    # Dessinée en 256 par tuile pour le trait, servie en 128 : la boîte se
    # regarde de haut, à vingt pixels de large, et le grain du kraft se
    # compresse mal — en 2048 la planche pesait cinq mégaoctets, en 1024
    # palettisée moins d'un.
    planche = planche.resize((T * COLONNES // 2, T * LIGNES // 2), Image.LANCZOS)
    planche = planche.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    planche.save(SORTIE / "planche.png", optimize=True)

    (SORTIE / "cartons.json").write_text(
        json.dumps(catalogue, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(catalogue)} logos sur la planche {planche.size}, {len(list(KIT.glob('*.png')))} PNG pour le kit")


if __name__ == "__main__":
    main()
