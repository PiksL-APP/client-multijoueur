# La météo de Carnage

La ville n'avait qu'une **heure** : le même ciel bleu à chaque manche, la même
lumière rasante au même moment du cycle. Le temps qu'il fait est la seconde
chose qui change une rue sans toucher à un cube — et la seule qui change d'une
manche à l'autre. C'est la première pièce de l'« amélioration graphique » au
sens où l'utilisateur l'entend : **la météo, les éclairages, les shaders**, pas
les modèles.

## Le principe : lu sur l'horloge, comme l'heure

`jeux/carnage/meteo.gd` (`MeteoCarnage`). Un temps dure **dix minutes**
(`CYCLE`) ; le passage de l'un à l'autre se fond sur **quarante-cinq secondes**
(`TRANSITION`, adoucie en S). Le tirage d'un créneau est un hachage entier du
numéro du créneau (`temps_au_creneau`) : deux machines tombent pareil, et la
météo ne passe donc **pas par l'instantané de l'hôte** — même principe que le
cycle du jour (`MatieresCarnage.nuit`). Poids : quatre créneaux sur dix au
clair, deux couverts, deux de pluie, un orage, un brouillard (`TIRAGE`). Un
temps rare se remarque, un temps fréquent s'oublie.

Cinq temps, quatre jauges (`TEMPS`) : `nuages`, `pluie`, `brume`, `orage`. Tout
le reste s'interpole entre elles — c'est ce qui rend le fondu gratuit.

| temps | nuages | pluie | brume | orage |
|---|---|---|---|---|
| clair | 0 | 0 | 0 | 0 |
| couvert | 0,85 | 0 | 0,15 | 0 |
| pluie | 0,95 | 0,8 | 0,35 | 0 |
| orage | 1 | 1 | 0,45 | 1 |
| brouillard | 0,6 | 0 | 1 | 0 |

## Ce que chaque jauge fait

`MeteoCarnage.appliquer` est appelé à chaque image **après**
`MatieresCarnage.regler_heure` : il retouche ce que l'heure a réglé, il ne le
remplace pas.

- **nuages** — le ciel vire au gris (un gris qui suit l'heure : chape claire le
  jour, plafond d'encre la nuit, sinon un gris de jour sur une nuit noire fait
  une aube), le soleil perd 55 % et blanchit, son ombre s'estompe
  (`shadow_opacity`), l'ambiante monte de 30 % (une lumière plate, pas une nuit
  en plein jour). Au sol et sur les voxels, l'**ombre des nuages** qui glissait
  s'efface (`couvert` dans `SOL` et `VOXEL`) : sous une chape uniforme, plus
  rien ne se détache.
- **pluie** — le bitume se mouille **de jour** : le bloc « nuit humide » du
  shader du sol lit maintenant `max(nuit, mouille)`, et les flaques gagnent du
  terrain avec l'averse. Des **impacts** : une cellule sur cent s'allume un
  dixième de seconde — c'est ce qui dit que la pluie *tombe*, quand les traits
  à l'écran ne disent qu'elle passe. L'herbe et la terre foncent sans luire.
  À l'écran (`POST`), deux calques de traits penchés, de vitesses et d'échelles
  différentes pour la profondeur ; l'image se refroidit un peu. Au volant,
  **18 % d'adhérence en moins** à pleine averse : assez pour rater un virage
  qu'on prenait les yeux fermés, pas assez pour que la voiture parte seule —
  l'huile de l'atelier reste le vrai piège.
- **brume** — la densité du brouillard monte jusqu'à manger l'horizon
  (`fog_sky_affect`), le soleil est voilé, le ciel se confond avec le sol.
- **orage** — un éclair toutes les cinq à seize secondes : l'ambiante triple,
  le ciel et l'écran blanchissent, puis tout retombe en un dixième de seconde.
  Le **tonnerre** suit avec le retard de la distance (0,5 à 2,6 s) : la grande
  explosion ralentie de moitié, plus grave, plus longue — il n'y a pas de
  fichier de tonnerre dans le dossier des sons.

## Ce que la pluie fait aux lumières

- **Le reflet dans le mouillé** (`MatieresCarnage.FLAQUE`) : chaque flaque de
  lumière au sol — lampadaire, enseigne, phare — rend un **trait allongé** dans
  l'axe du regard (l'axe z du monde, la caméra regardant toujours vers -z),
  étroit, plus vif que la flaque, qui tremble un peu. Il n'existe que quand le
  sol est mouillé : la rosée de la nuit en fait la moitié, l'averse le reste.
  C'est ce qui manquait pour que « la rue rend les enseignes » soit vrai des
  lampadaires et des phares aussi.
- **Le faisceau des phares** (`MatieresCarnage.FAISCEAU`, bâti dans
  `FormesCarnage.phares`) : un coin de lumière additif devant chaque voiture
  qui roule, à hauteur de calandre, qui retombe vers le sol en s'élargissant.
  Par temps clair il reste une lueur ; dans la brume ou sous la pluie (`air`),
  c'est le faisceau qu'on voit avant la voiture. Vu de dessus, un vrai
  projecteur ne se lit que par sa tache au sol ; le coin, lui, dit la
  DIRECTION. ⚠ Enfant du nœud « Phares », pas frère : `_placer_les_autos`
  éteint « Phares » par son nom quand la voiture est garée, et un frère serait
  resté allumé au parking.
- **Le halo monte** sous l'averse (`glow_intensity + 0,3 × pluie`) : l'air
  chargé d'eau fait baver les enseignes et les phares.
- **L'eau** se hache d'un clapot court, se grise, se dépolit, et les impacts y
  scintillent comme au sol (`EAU`, `mouille`).

## Le vent dans les arbres

Les arbres et les buissons du Nature Kit passent par un shader à eux
(`MatieresCarnage.VEGETAL`) : la couleur au sommet, comme avant, et un
**balancement** qui croît avec la hauteur au carré — le tronc tient, la cime va
— à une phase tirée de la position dans le monde, pour que deux arbres voisins
n'ondulent pas comme une seule vague. `vent` = 0,15 par beau temps (une brise),
0,45 sous la pluie, 1 sous l'orage. Mouillé, le feuillage fonce et luit un peu.
C'est le seul mouvement de la ville qui ne soit ni une voiture ni un passant,
et c'est ce qui fait qu'un parc a l'air vivant même vide. Les bancs, le
monument et les rochers du même kit ne bougent pas : le shader ne s'applique
qu'aux chemins `nature/tree`, `nature/plant` et `voxel/arbre`.

## Une voiture luit, un mur non

Le shader des kits (`KENNEY`) donnait à tout — murs, tôles, vitres — la
rugosité d'un crépi (0,86) : vu de haut, une voiture était un aplat sans le
moindre reflet. En mode `peinture` (véhicules et bateaux), la tôle passe à 0,5
et le vitrage et les chromes — les gris **bleutés** de l'atlas, que ni la tôle
ni les pneus n'ont (`t.b - t.r > 0,12`) — à 0,2 : le soleil accroche les
toits, les pare-brise renvoient le ciel. Sous la pluie, tout le monde luit
encore un peu plus (`mouille`). Les duplicata peints (`matiere_peinte`) sont
inscrits dans un registre (`suivre_kenney`) pour recevoir la nuit et la pluie
comme l'original — sans lui, une voiture repeinte restait sèche sous l'averse.

## Le bruit de la pluie

Aucun fichier de pluie non plus, et une averse muette est une averse qu'on ne
croit pas. `MeteoCarnage._bruit_de_pluie` **synthétise** quatre secondes de
bruit filtré (un souffle grave, des gouttes par-dessus) dans un
`AudioStreamWAV` bouclé, dont le volume suit la jauge. Fabriqué à la première
averse seulement — cent soixante-seize mille échantillons ne se calculent pas
au démarrage pour un temps qui ne viendra peut-être pas.

## Pourquoi pas de particules

Le mode compatibilité (WebGL 2) dessine mal les `GPUParticles3D` et les
`CPUParticles3D` coûtent ce qu'elles coûtent sur trois cents voitures. Vu de
haut, des traits par-dessus l'image — ce que faisait GTA 2 — se lisent mieux
qu'un nuage de gouttes en 3D dont on ne voit que le dessus. ⚠ Des **points**
plutôt que des traits (essayé) : on croyait à de la neige, ou à du bruit de
compression.

## Les bancs

```bash
godot --headless -s outils/meteo.gd                                   # tirage, fondu, temps forcé, bruit
godot --path . --solo --banc-jeu=carnage --manche=4 --meteo=pluie --nuit=0.0 --photo=/tmp/vues
godot --path . --solo --banc-jeu=carnage --manche=4 --meteo=orage --nuit=0.9 --banc-eclair --photo=/tmp/vues
```

`outils/meteo.gd` vérifie que les cinq temps sortent aux poids voulus, que le
tirage d'un créneau ne dépend que du créneau, qu'aucune jauge ne saute de plus
de 0,06 par demi-seconde pendant un fondu, qu'un temps forcé s'applique tout de
suite, et que le bruit de pluie a sa longueur, sa boucle et une crête
raisonnable. `--meteo=<nom>` fige un temps dans une manche ; le code **MÉTÉO**
du menu Konami passe au temps suivant à chaque allumage et rend le ciel à
l'horloge quand on l'éteint ; `--banc-eclair` tient l'éclair allumé pour le
photographier — un dixième de seconde ne se prend pas au vol sous xvfb.

## Ce qui reste

- la **neige** (GTA 2 n'en a pas non plus) ; le vent ne fait bouger que les
  arbres — ni la pluie (qui penche toujours pareil) ni les passants ;
- un vrai reflet **des façades** dans les flaques (il faudrait des réflexions
  d'écran, que le mode compatibilité n'a pas) ;
- un fichier de pluie et un de tonnerre à la place des sons synthétisés, quand
  la session des sons en trouvera.
