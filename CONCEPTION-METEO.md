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
cycle du jour (`MatieresCarnage.nuit`). Poids : cinq créneaux sur douze au
clair, deux couverts, deux de pluie, un orage, un brouillard, une neige
(`TIRAGE`). Un temps rare se remarque, un temps fréquent s'oublie.

Six temps, cinq jauges (`TEMPS`) : `nuages`, `pluie`, `brume`, `orage`,
`neige`. Tout le reste s'interpole entre elles — c'est ce qui rend le fondu
gratuit.

| temps | nuages | pluie | brume | orage | neige |
|---|---|---|---|---|---|
| clair | 0 | 0 | 0 | 0 | 0 |
| couvert | 0,85 | 0 | 0,15 | 0 | 0 |
| pluie | 0,95 | 0,8 | 0,35 | 0 | 0 |
| orage | 1 | 1 | 0,45 | 1 | 0 |
| brouillard | 0,6 | 0 | 1 | 0 | 0 |
| neige | 0,75 | 0 | 0,25 | 0 | 1 |

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
- **neige** — elle tient sur ce qui regarde le ciel : les toits (kit et
  voxel), les trottoirs, les dalles, les têtes de lampadaire, les cimes des
  arbres — par plaques d'abord (le bruit), puis d'un tenant. La **chaussée
  reste roulée** : sur le shader `SOL`, deux bandes de roulement restent
  grises au milieu de la rue ; sur les tuiles du kit (Pikstown), l'asphalte
  (0,42 de luminance dans l'atlas, le trottoir est à 0,66) ne prend la neige
  que par plaques sales — sinon la rue disparaissait sous le même blanc que
  les trottoirs et on ne savait plus où rouler. Les voitures n'en prennent
  pas. À l'écran, des flocons ronds qui descendent lentement en se balançant,
  sur deux plans. La lumière : ambiante montée d'un cinquième et bleuie (la
  neige renvoie le ciel). Au volant, **28 % d'adhérence en moins**. Un blanc
  cassé (0,86 / 0,89 / 0,94), pas un blanc pur : le pur brûlait l'image et
  mangeait l'interface.
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

## La deuxième version : ce qui était moche, et pourquoi

La première livraison a été jugée « moche de fou », et c'était vrai. Sur
capture : des barres blanches sur un tiers de l'écran, une rue entière passée
au bleu-gris sans un dessin, un brouillard qui délavait tout comme une photo
passée à l'eau de Javel, des carrés qui scintillaient au sol. Ce qui a changé :

- **la pluie** est fine (un pixel et demi, adouci), longue, translucide, sur
  trois calques — les traits restent SOUS le seuil où l'œil les compte. Une
  averse se lit à ce qu'elle fait au sol et à la lumière, pas aux rayures ;
- **le sol** : l'asphalte mouillé fonce uniformément, et la FLAQUE rend le
  ciel — plus claire que la rue le jour, miroir sombre la nuit. Avant, tout
  fonçait dans les flaques et une lueur bleue s'ajoutait partout : une nappe
  bleu-gris sans grain ni bandes. Les dalles, pavés et bétons se mouillent
  aussi (la rosée de la nuit, elle, ne brille que sur l'asphalte) ;
- **les ronds dans l'eau** ont remplacé les carrés : un anneau qui s'ouvre et
  s'efface en une demi-seconde, à un endroit tiré dans la cellule ;
- **le brouillard** est une NAPPE au ras du sol (`MatieresCarnage.BRUME`) :
  des bancs qui dérivent dans les rues, que les toits percent, qui avalent une
  voiture et la rendent. Le brouillard d'ambiance ne fait plus qu'un peu — vu
  de dessus, tout est à la même distance et il ne peut que délaver ;
- **la lumière sous les nuages** garde ses ombres : le soleil perd 40 % (pas
  55), l'ombre garde plus de la moitié de sa force, l'ambiante monte de 12 %
  (pas 30). Un jour de pluie a des ombres, douces ; l'ancienne version
  faisait une bouillie grise sans relief ;
- **l'éclair** blanchit à 28 %, pas 45 : on doit encore voir la rue ;
- **un étalonnage** pour tout le jeu, dans `POST` : une courbe en S légère et
  huit pour cent de saturation. Le mode compatibilité n'a ni occlusion
  ambiante ni réflexions pour creuser l'image ; sans lui elle sortait plate.

## Des uniformes globaux

L'heure (`nuit`) et la météo (`mouille`, `couvert`, `vent`, `brume`, `pluie`,
`eclair`, `air`) sont des **`global uniform`** posés par
`RenderingServer.global_shader_parameter_set` (`MatieresCarnage.global`) :
une valeur pour tous les shaders, lue par CHAQUE matière — y compris les
duplicata que d'autres fichiers font des matières du kit (`Quartiers._matiere`
pour Pikstown, `FormesCarnage.matiere_peinte` pour les voitures). ⚠ Avant,
chaque valeur était poussée matière par matière dans des boucles sur des
registres : toute matière dupliquée hors registre restait en plein jour,
sèche, quand la ville passait à la nuit sous l'averse — et Pikstown en
duplique des dizaines (ses fenêtres ne s'allumaient pas). Un uniforme global
ne s'oublie pas. Ils sont déclarés une fois par processus dans `_materiau`
(`_preparer_les_globaux`) ; ⚠ pas de `global_shader_parameter_get` pour
vérifier s'ils existent — hors éditeur, Godot le refuse.

**Le sol de Pikstown** est fait de tuiles du kit (routes, dalles, pavés), donc
du shader `KENNEY`, pas de `SOL` : le même mouillé y est écrit — sur les faces
horizontales des matières qui ne sont ni un bâtiment (`fenetres`) ni un
véhicule (`peinture`), l'asphalte fonce, la flaque rend le ciel, les gouttes y
ouvrent des ronds ; l'herbe (un vert franc dans l'atlas) fonce sans flaque.

**Les lampadaires de Pikstown éclairent** : posés sans lumière par
`Quartiers._objet`, ils sont retrouvés toutes les deux secondes par leur
maillage (le cache `_kenney` sait lesquels viennent d'un `urbain/light-*`) et
reçoivent une flaque additive au sol, une fois chacun (`FormesCarnage.
lueur_de_lampadaire`, `_eclairer_les_lampadaires_dessines`) ; leur tête
s'allume dans le shader `KENNEY` (blanc de l'atlas à plus de six unités du
sol). ⚠ La flaque est à 0,6 unité au-dessus de la base du mât : la tuile de
route fait 0,4 d'épaisseur, et une flaque au ras du sol y restait enfermée —
photographié deux fois avant de comprendre.

**La nuit n'est pas noire** (`HEURES[2]`) : sur Pikstown, moins de lampadaires
et des tuiles plus sombres faisaient un écran d'encre — ambiante et lune
montées d'un bon tiers, et la courbe en S de l'étalonnage s'efface aux deux
tiers la nuit pour ne pas creuser des ombres déjà noires.

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

- le vent ne fait bouger que les arbres — ni la pluie (qui penche toujours
  pareil) ni les passants ; pas de traces de pas ni de pneus dans la neige ;
- un vrai reflet **des façades** dans les flaques (il faudrait des réflexions
  d'écran, que le mode compatibilité n'a pas) ;
- un fichier de pluie et un de tonnerre à la place des sons synthétisés, quand
  la session des sons en trouvera.
