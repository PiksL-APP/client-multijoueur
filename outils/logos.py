#!/usr/bin/env python3
"""Les cinquante logos des cartons — dessinés au marqueur, en SVG.

    python3 outils/logos.py            # écrit _transfert/logos/*.svg + logos.json

Chaque habitant de Pikstown porte un carton sur la tête, et le carton porte
UN signe sur sa face avant : c'est lui qui distingue les gens, puisqu'on ne
voit jamais un visage. Le kit du menu en avait huit (couronne, cœur, croix…) ;
en voici cinquante, dans le même trait — un feutre noir, épais, un peu
tremblé, sur du carton brut.

Tout est dessiné ICI, en primitives SVG, sans rien reprendre d'ailleurs : un
logo, c'est un nom, une phrase, et une poignée de traits. Le tremblé vient
d'un filtre de déplacement (bruit + décalage), le même sur les cinquante,
pour qu'ils aient l'air de la même main.

Le rendu en PNG se fait ensuite dans un navigateur sans tête (Chromium via
Playwright) : c'est le seul moteur SVG complet à portée, et il rend le filtre
de tremblé fidèlement.
"""
import json
from pathlib import Path

SORTIE = Path(__file__).resolve().parent.parent / "_transfert" / "logos"
SORTIE.mkdir(parents=True, exist_ok=True)

T = 256                      # côté du dessin
E = 20                       # épaisseur du trait
ENCRE = "#1a120c"

ENTETE = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {T} {T}" width="{T}" height="{T}">
<defs>
  <filter id="feutre" x="-10%" y="-10%" width="120%" height="120%">
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="SEED" result="b"/>
    <feDisplacementMap in="SourceGraphic" in2="b" scale="6" xChannelSelector="R" yChannelSelector="G"/>
  </filter>
</defs>
<g filter="url(#feutre)" fill="none" stroke="{ENCRE}" stroke-width="{E}" stroke-linecap="round" stroke-linejoin="round">
'''
PIED = "</g></svg>\n"


def texte(mot, taille=96, y=None, poids=900, largeur=None):
    """Un mot en capitales, en trait plein — la police est celle du navigateur
    qui rend ; on force une grasse sans empattement, et on ne compte pas sur
    une fonte précise : à cette taille et tremblé, ça passe pour du feutre."""
    y = y if y is not None else T / 2 + taille * 0.36
    ls = f' textLength="{largeur}" lengthAdjust="spacingAndGlyphs"' if largeur else ""
    return (f'<text x="{T/2}" y="{y}" text-anchor="middle" font-family="Archivo Black, Impact, '
            f'Arial Black, sans-serif" font-weight="{poids}" font-size="{taille}" '
            f'fill="{ENCRE}" stroke="none"{ls}>{mot}</text>')


def plein(chemin):
    return f'<path d="{chemin}" fill="{ENCRE}" stroke="{ENCRE}" stroke-width="6"/>'


def trait(chemin, e=E):
    return f'<path d="{chemin}" stroke-width="{e}"/>'


def cercle(cx, cy, r, e=E, rempli=False):
    if rempli:
        return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{ENCRE}" stroke="none"/>'
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" stroke-width="{e}"/>'


# ───────────────────────────── les cinquante ─────────────────────────────
# (cle, nom, phrase, groupe, dessin)
LOGOS = [
    # ── les tags — ceux du kit, redessinés ──
    ("couronne", "Le Roi", "Couronne au marqueur. Il dirige le crew.", "tag",
     trait("M40 190 L40 90 L84 130 L128 66 L172 130 L216 90 L216 190 Z") + trait("M56 190 L200 190", 14)),
    ("coeur", "Le Cœur", "Charme d'abord, braquage ensuite.", "tag",
     plein("M128 210 C40 150 30 90 70 70 C95 58 118 70 128 92 C138 70 161 58 186 70 C226 90 216 150 128 210 Z")),
    ("croix", "Le Fantôme", "Personne ne l'a jamais identifié.", "tag",
     trait("M56 56 L200 200") + trait("M200 56 L56 200")),
    ("dollar", "Le Comptable", "Blanchit tout, ne salit rien.", "tag",
     trait("M176 84 C176 60 150 50 128 50 C96 50 78 66 78 90 C78 138 178 118 178 168 C178 194 154 206 128 206 C100 206 80 194 78 170")
     + trait("M128 30 L128 226", 14)),
    ("sourire", "Le Souriant", "Toujours de bonne humeur, même armé.", "tag",
     trait("M60 130 C80 190 176 190 196 130")),
    ("trois_traits", "Le Vétéran", "Vice City, première génération.", "tag",
     trait("M56 80 L200 80") + trait("M56 128 L200 128") + trait("M56 176 L200 176")),
    ("question", "La Recrue", "Vient d'arriver. Ça se voit.", "tag",
     trait("M80 90 C80 50 176 46 176 96 C176 130 130 130 128 160") + cercle(128, 204, 10, rempli=True)),
    ("triangle", "Le Boss", "On ne le voit jamais deux fois.", "tag",
     trait("M128 48 L212 196 L44 196 Z")),
    ("etoile", "La Star", "Se prend pour une affiche. En est une.", "tag",
     trait("M128 40 L152 106 L222 108 L166 150 L186 218 L128 178 L70 218 L90 150 L34 108 L104 106 Z")),
    ("eclair", "Le Voltage", "Ne s'arrête jamais au rouge.", "tag",
     plein("M148 30 L70 140 L124 140 L100 226 L186 108 L134 108 Z")),
    ("losange", "Le Diamant", "Tout ce qui brille lui appartient.", "tag",
     trait("M128 40 L212 128 L128 216 L44 128 Z") + trait("M44 128 L212 128", 12)),
    ("spirale", "Le Vertige", "Tourne en rond, mais vite.", "tag",
     trait("M128 128 C150 128 156 148 140 160 C118 176 92 156 96 128 C102 92 150 82 176 108 C206 140 186 196 132 200 C74 204 42 148 60 100")),

    # ── l'humour ──
    ("louche", "Le Louche", "Un œil sur toi, l'autre sur la sortie.", "humour",
     cercle(86, 104, 26) + cercle(170, 104, 26) + cercle(96, 110, 9, rempli=True) + cercle(160, 98, 9, rempli=True)
     + trait("M84 172 C110 196 150 190 176 166")),
    ("moustache", "Le Moustachu", "Elle a son propre casier.", "humour",
     plein("M128 132 C112 110 80 104 56 118 C36 130 40 156 62 158 C92 160 116 150 128 138 C140 150 164 160 194 158 C216 156 220 130 200 118 C176 104 144 110 128 132 Z")),
    ("lunettes", "Le Cool", "Nuit et jour. Surtout la nuit.", "humour",
     plein("M30 104 L118 104 L112 150 C110 166 60 166 56 150 Z") + plein("M226 104 L138 104 L144 150 C146 166 196 166 200 150 Z")
     + trait("M118 112 L138 112", 12) + trait("M30 104 L18 92", 12) + trait("M226 104 L238 92", 12)),
    ("lol", "Le Rieur", "Rit avant, pendant, après.", "humour", texte("LOL", 104)),
    ("nope", "Le Refus", "Sa réponse à tout.", "humour", texte("NOPE", 82)),
    ("pouce", "L'Approbateur", "Valide tout, y compris les mauvaises idées.", "humour",
     trait("M60 120 L60 208 L96 208 L96 120 Z", 16)
     + trait("M96 128 L130 60 C146 40 172 50 164 80 L156 112 L204 112 C222 112 222 136 206 140 C220 146 218 168 200 170 C214 178 208 200 190 202 L96 202")),
    ("pizza", "Le Livreur", "Trente minutes ou c'est offert.", "humour",
     trait("M128 40 L212 200 L44 200 Z") + trait("M70 178 C100 160 156 160 186 178", 14)
     + cercle(128, 120, 10, rempli=True) + cercle(104, 160, 9, rempli=True) + cercle(154, 156, 9, rempli=True)),
    ("banane", "La Banane", "Glisse toujours entre les doigts.", "humour",
     trait("M60 70 C40 150 90 210 180 200 C200 198 208 184 196 180 C120 180 84 130 88 70 C88 60 66 56 60 70 Z", 14)),
    ("cocktail", "Le Noctambule", "Sa tournée, ses règles.", "humour",
     trait("M48 56 L208 56 L128 140 Z") + trait("M128 140 L128 200") + trait("M86 200 L170 200") + trait("M170 40 L196 20", 10)),
    ("ouvert", "Le Veilleur", "Ouvert 24 h sur 24. Fermé pour vous.", "humour", texte("24/7", 84)),
    ("wanted", "Le Recherché", "Sa tête vaut plus que la vôtre.", "humour", texte("WANTED", 58, largeur=224)),
    ("oeil", "Le Guetteur", "Voit tout, ne dit rien, vend tout.", "humour",
     trait("M32 128 C70 60 186 60 224 128 C186 196 70 196 32 128 Z") + cercle(128, 128, 34) + cercle(128, 128, 14, rempli=True)),
    ("langue", "L'Insolent", "Tire la langue aux flics. Depuis la voiture.", "humour",
     trait("M60 100 C80 150 176 150 196 100") + plein("M112 132 L146 132 C150 170 108 170 112 132 Z")
     + cercle(90, 74, 9, rempli=True) + cercle(166, 74, 9, rempli=True)),
    ("dormeur", "Le Dormeur", "Réveillé pour les braquages seulement.", "humour",
     texte("ZZZ", 88)),

    # ── les gangs ──
    ("serpent", "Les Cobras", "Ils mordent, ils ne préviennent pas.", "gang",
     trait("M188 66 C188 40 120 34 96 60 C70 90 190 100 186 140 C182 184 100 190 68 170") + cercle(84, 158, 7, rempli=True)),
    ("griffes", "Les Griffes", "Trois traits, pas de pardon.", "gang",
     trait("M70 40 C80 110 84 160 76 216") + trait("M128 32 C136 110 138 160 128 224") + trait("M186 40 C176 110 172 160 180 216")),
    ("poing", "Les Poings", "Ils négocient à la main.", "gang",
     # Vu de face : quatre phalanges en haut, le pouce replié en travers.
     trait("M52 118 C52 84 76 80 88 96 C92 74 124 74 128 96 C132 74 164 74 168 96 C180 80 204 84 204 118 L204 176 C204 206 176 214 128 214 C80 214 52 206 52 176 Z")
     + trait("M88 96 L88 118", 12) + trait("M128 96 L128 118", 12) + trait("M168 96 L168 118", 12)
     + trait("M52 150 C80 138 130 138 166 154", 14)),
    ("ancre", "Les Docks", "Tout ce qui arrive par la mer est à eux.", "gang",
     cercle(128, 52, 18) + trait("M128 70 L128 210") + trait("M84 110 L172 110")
     + trait("M52 150 C60 200 196 200 204 150") + trait("M40 160 L52 150 L66 166", 14) + trait("M216 160 L204 150 L190 166", 14)),
    ("crane", "Les Crânes", "Ils ne rient que des autres.", "gang",
     trait("M128 40 C70 40 56 100 68 140 C74 158 86 160 86 176 L86 206 L170 206 L170 176 C170 160 182 158 188 140 C200 100 186 40 128 40 Z")
     + cercle(104, 118, 16, rempli=True) + cercle(152, 118, 16, rempli=True)
     + trait("M112 206 L112 186", 10) + trait("M128 206 L128 186", 10) + trait("M144 206 L144 186", 10)),
    ("flamme", "Les Brûlés", "Ils allument, les pompiers arrivent.", "gang",
     plein("M128 30 C150 80 190 90 176 150 C170 180 150 200 128 226 C106 200 86 180 80 150 C70 110 100 100 104 70 C112 90 130 96 128 30 Z")),
    ("vague", "Les Marées", "Ils passent, ils reviennent, ils emportent.", "gang",
     trait("M30 100 C60 70 90 130 128 100 C166 70 196 130 226 100") + trait("M30 160 C60 130 90 190 128 160 C166 130 196 190 226 160")),
    ("soleil", "Les Solaires", "Jamais avant midi.", "gang",
     cercle(128, 128, 40) + "".join(
         trait(f"M{128 + 64 * __import__('math').cos(a):.0f} {128 + 64 * __import__('math').sin(a):.0f} "
               f"L{128 + 92 * __import__('math').cos(a):.0f} {128 + 92 * __import__('math').sin(a):.0f}", 14)
         for a in [i * 3.14159 / 4 for i in range(8)])),
    ("lune", "Les Nocturnes", "La ville leur appartient de minuit à six.", "gang",
     plein("M150 40 C90 50 70 130 120 190 C140 214 170 220 190 210 C130 190 110 100 150 40 Z")),
    ("treize", "Le Treize", "Ni chanceux, ni malchanceux : dangereux.", "gang", texte("13", 120)),
    ("cible", "Les Tireurs", "Ils ne ratent que ce qu'ils veulent.", "gang",
     cercle(128, 128, 84) + cercle(128, 128, 48) + cercle(128, 128, 14, rempli=True)
     + trait("M128 24 L128 60", 12) + trait("M128 196 L128 232", 12) + trait("M24 128 L60 128", 12) + trait("M196 128 L232 128", 12)),
    ("bombe", "Les Détonateurs", "Comptez jusqu'à trois. Ou pas.", "gang",
     cercle(116, 148, 60) + trait("M150 100 L168 78") + trait("M168 78 C180 60 196 66 200 52", 12)
     + trait("M196 40 L206 30", 10) + trait("M210 52 L224 50", 10)),
    ("palmier", "Les Tropicaux", "Pikstown est leur plage privée.", "gang",
     trait("M128 214 C128 170 124 130 118 96") + trait("M118 96 C90 80 60 84 40 104") + trait("M118 96 C100 66 106 40 128 30")
     + trait("M118 96 C150 66 180 70 200 90") + trait("M118 96 C150 96 176 116 190 140")),

    # ── divers ──
    ("pta", "Le Fan", "Il a la casquette, le tee-shirt, le carton.", "divers", texte("PTA", 100)),
    ("piks", "Le Local", "Né ici, restera ici.", "divers", texte("PIKS", 84)),
    ("fleche", "Le Grimpeur", "Toujours plus haut. Surtout en voiture.", "divers",
     trait("M128 210 L128 46") + trait("M70 104 L128 46 L186 104")),
    ("exclamation", "L'Alerte", "Il a toujours quelque chose à crier.", "divers",
     trait("M128 40 L128 156", 26) + cercle(128, 204, 14, rempli=True)),
    ("coeur_brise", "L'Éconduit", "Une histoire par quartier.", "divers",
     plein("M128 210 C40 150 30 90 70 70 C95 58 118 70 128 92 C138 70 161 58 186 70 C226 90 216 150 128 210 Z")
     + f'<path d="M132 84 L112 120 L140 140 L118 190" stroke="#d9b184" stroke-width="12" fill="none"/>'),
    ("damier", "Le Pilote", "Drapeau à damier, ligne d'arrivée, garde à vue.", "divers",
     "".join(f'<rect x="{40 + (i % 4) * 44}" y="{40 + (i // 4) * 44}" width="44" height="44" fill="{ENCRE}" stroke="none"/>'
             for i in range(16) if (i + i // 4) % 2 == 0)),
    ("rayures", "Le Détenu", "Sorti hier. Rentre demain.", "divers",
     "".join(trait(f"M40 {60 + i * 34} L216 {60 + i * 34}", 18) for i in range(5))),
    ("sos", "Le Naufragé", "Appelle à l'aide. Personne ne vient.", "divers", texte("SOS", 100)),
    ("vip", "Le Privilégié", "Entre partout, ne paie jamais.", "divers", texte("VIP", 104)),
    ("interdit", "Le Barré", "Ce qu'il voulait faire est interdit. Il le fait.", "divers",
     cercle(128, 128, 84, 22) + trait("M70 70 L186 186", 22)),
    ("billets", "Le Flambeur", "Tout ce qu'il gagne part le soir même.", "divers", texte("$$$", 96)),
    ("cassette", "Le Rétro", "Il a encore les cassettes de la radio.", "divers",
     trait("M36 76 L220 76 L220 180 L36 180 Z") + cercle(90, 128, 18) + cercle(166, 128, 18) + trait("M108 128 L148 128", 12)
     + trait("M60 180 L72 156 L184 156 L196 180", 12)),
    ("paix", "Le Pacifiste", "Ne tire jamais le premier. Rarement le second.", "divers",
     cercle(128, 128, 88) + trait("M128 40 L128 216") + trait("M128 128 L66 190") + trait("M128 128 L190 190")),
    ("mort", "Le Défunt", "Officiellement. Pas vraiment.", "divers",
     trait("M64 70 L112 118") + trait("M112 70 L64 118") + trait("M144 70 L192 118") + trait("M192 70 L144 118")
     + trait("M84 176 L172 176")),
    ("sherif", "Le Shérif", "Autoproclamé. Personne n'a contesté.", "divers",
     trait("M128 40 L152 106 L222 108 L166 150 L186 218 L128 178 L70 218 L90 150 L34 108 L104 106 Z") + cercle(128, 136, 22)),
    ("anarchie", "Le Sans-Loi", "Il a lu la loi. Une fois. De travers.", "divers",
     cercle(128, 128, 88) + trait("M96 200 L128 56 L160 200") + trait("M108 150 L150 150", 16)),
]

assert len(LOGOS) >= 50, len(LOGOS)          # « une cinquantaine » : cinquante-cinq, on garde tout
assert len({c for c, *_ in LOGOS}) == len(LOGOS), "deux logos portent la même clé"

catalogue = []
for i, (cle, nom, phrase, groupe, dessin) in enumerate(LOGOS):
    svg = ENTETE.replace("SEED", str(7 + i)) + dessin + "\n" + PIED
    (SORTIE / f"{i:02d}_{cle}.svg").write_text(svg, encoding="utf-8")
    catalogue.append({"indice": i, "cle": cle, "nom": nom, "phrase": phrase, "groupe": groupe})
(SORTIE / "logos.json").write_text(json.dumps(catalogue, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"{len(LOGOS)} logos écrits dans {SORTIE}")
