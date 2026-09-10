# Le respect des gangs

*Phase 4 du guide « GTA 2 Voxel » (§3). Ce que le code fait aujourd'hui, avec
les chiffres et les raisons.*

## Sept gangs, trois par district

Le guide (§3.1) demande **trois gangs par district, dont un commun aux trois**
— le Zaibatsu de GTA 2. Notre ville n'a pas trois districts découpés à la
main : elle a **trois secteurs angulaires** aux frontières bruitées, tirés de
la graine de la manche. On y a donc posé la même règle :

| secteur | gang local | gang local | gang commun |
|---|---|---|---|
| 0 | **Les Braises** (rouge, industrie) | **Les Scories** (jaune, port) | **Le Consortium** |
| 1 | **La Fonte** (orange, commerce) | **Les Néons** (rose, bureaux) | **Le Consortium** |
| 2 | **Le Lierre** (vert, banlieue) | **Les Ronces** (violet, cités) | **Le Consortium** |

Table : `PlanVille.GANGS`, `PlanVille.TRIOS`, `PlanVille.CONSORTIUM`.

**Pourquoi pas trois gangs tout court, comme avant.** Avec un seul gang par
secteur, traverser son territoire ne posait aucune question : le respect se
gagnait ou se perdait en bloc sur un tiers de la carte, et le joueur n'avait
jamais à *choisir*. À deux locaux qui se détestent, plus un commun qu'ils
détestent tous les deux, chaque mort devient un arbitrage — elle réjouit
quelqu'un d'autre à trois rues de là.

Le propriétaire d'un pâté est tiré à la **graine** (une cellule de huit pâtés),
pas au secteur : sans ce second tirage, les deux locaux se partageraient la
région en deux demi-lunes bien nettes, alors qu'une frontière de gang doit se
découvrir au coin d'une rue. Le Consortium prend **une graine sur cinq**
(`PART_CONSORTIUM`) : à un tiers il tenait autant de rues que les locaux et
son territoire cessait d'être une anomalie ; à moins d'un dixième on pouvait
faire une manche entière sans jamais le croiser.

**Le secteur d'un point** (`PlanVille.secteur`) se recalcule depuis l'angle au
centre — il ne se lit pas dans le propriétaire du pâté, puisque Le Consortium
est chez lui dans les trois. L'angle des graines est bruité de ±0,45 rad : un
pâté sur vingt tombe donc dans le trio voisin de celui que sa couleur annonce.
C'est un demi-pâté d'erreur au bord d'un secteur, contre une table de deux
mille entrées à porter partout.

## Cinq paliers, de zéro à cent

`VilleVivante` — la jauge part à **50** : le joueur n'est ni attendu ni
chassé, il est **inconnu**. Avant, elle partait de zéro et ne pouvait que
descendre en pratique, faute d'une raison de monter avant le premier contrat.

| respect | humeur | conséquence |
|---|---|---|
| < 20 | *vous chasse* | les hommes du gang **tirent à vue** |
| 20 – 40 | *vous cherche* | mauvaise tête : **aucun contrat** |
| 40 – 60 | *vous ignore* | contrats **faciles** |
| 60 – 80 | *vous salue* | contrats **moyens**, prime × 1,6 |
| > 80 | *vous couvre* | **aide en combat**, contrats **difficiles**, prime × 2,4 |

Un seul endroit traduit le nombre en intention : `VilleVivante.humeur()`. Deux
tables de seuils divergentes, ce serait un gang qui tire à vue sur un joueur
que l'écran annonce comme ami.

## Ce qui fait bouger la jauge

| geste | le gang visé | ses rivaux du secteur |
|---|---|---|
| abattre un de ses hommes | −11 | +5 |
| brûler une de ses voitures | −6,6 | +2,5 |
| lui voler une voiture | −4,4 | — |
| lui rendre un contrat | +10,4 à +16,9 selon le palier | le rival du contrat : la moitié en moins |

**Trois morts, pas une.** Le chiffre a déjà été remonté une fois : à −34 par
mort, abattre un seul passant en couleurs retournait le quartier entier contre
le joueur, et la jauge ne servait plus qu'à annoncer une catastrophe. Depuis
50, onze points par mort donnent 39 (le gang ne confie plus rien), 28, puis 17
— et là seulement on vous tire dessus. La sanction s'annonce **deux fois**
avant de tomber. Un mort coûte les contrats immédiatement, et c'est voulu : à
moins de dix points la mort, il fallait quatre cadavres pour se faire chasser,
et descendre un gars en couleurs ne se payait plus du tout.

**Qui se réjouit** (`PlanVille.rivaux`) : pour un local, l'autre local de son
secteur et Le Consortium. Pour Le Consortium, qui n'a pas de secteur à lui, les
deux locaux **de l'endroit où le coup est parti** — sans le point, une seule
rafale suffirait à se faire aimer de six gangs à la fois.

## Les alliés qui prêtent main-forte

Au-dessus de quatre-vingts, un homme de gang ne se contente plus de laisser
passer : il court vers **ce qui vous attaque** et lui tire dessus — le flic qui
vous poursuit (seulement si vous êtes recherché) ou l'homme d'un autre gang qui
vous a en ligne de mire. C'est la seule récompense du respect qui se voie sans
regarder l'écran : un flic qui tombe sans qu'on ait appuyé sur rien.

Trois garde-fous :

- **il ne vise jamais un joueur.** Un allié qui canarderait un adversaire
  ferait du respect une arme à distance : on monterait sa jauge chez un gang
  et on lâcherait le quartier sur quelqu'un qui n'a rien demandé, sans risque
  et sans y être. Les joueurs ne se blessent qu'en arène ;
- **il ne touche pas aux passants.** Un allié zélé viderait la rue en dix
  secondes et vous collerait la police sur le dos ;
- **personne ne marque.** La victime d'un allié ne rapporte ni argent, ni
  étoile, ni ligne au tableau : ce n'est pas le joueur qui a tiré. Ce qu'il
  gagne, c'est un ennemi de moins.

L'ennemi est cherché autour de **l'allié**, pas du joueur : sinon il part en
courant traverser deux avenues pour un flic qu'il ne rejoindra jamais.

## Ce qui se lit à l'écran

- **trois barres** au-dessus de la fiche : les deux gangs locaux puis le
  commun. Pas les sept — sept barres, c'est un tableau de bord de simulateur,
  et cinq d'entre elles parlent de quartiers qu'on ne voit pas. Le **nom**
  porte la couleur du gang (la même que sur la carte, les casquettes et les
  voitures), la **barre et le mot** portent celle de l'humeur : une barre verte
  annonçant « vous chasse » parce que le gang a le vert pour bannière, c'est un
  contresens qu'on lit avant de lire le mot ;
- un **anneau au sol** sous les hommes de gang, dès que leur humeur n'est plus
  neutre. Pas la couleur du personnage, comme le suggère le guide (§3.4) : sa
  couleur à lui dit de quel gang il est, et sept gangs qui changeraient tous de
  teinte selon l'humeur, on ne saurait plus qui l'on abat ;
- l'**enseigne des cabines**, une couleur par palier — la même table
  (`FormesCarnage.COULEURS_HUMEUR`) que l'anneau, sinon la rue et le téléphone
  raconteraient deux histoires différentes ;
- la **carte** (TAB) teinte chaque pâté de son gang. La teinte est passée de
  0,25 à 0,45 : à sept bannières, on ne distinguait plus les territoires du
  fond de quartier.

## Les contrats

L'employeur est le gang **du territoire**. C'était `posmod(cabine, 3)` —
l'indice d'un pâté modulo trois : une cabine plantée chez Le Lierre faisait
travailler pour Les Braises deux fois sur trois, et son enseigne annonçait un
employeur qui n'était pas celui qui décrochait. Sur terrain neutre (le centre
d'affaires n'appartient à personne), c'est le trio du secteur qui se partage
les téléphones — sinon les cabines du centre ne sonneraient jamais.

La difficulté n'est pas tirée au sort, elle se **mérite** : c'est ce qui fait
du respect une progression et pas un thermomètre. Et rendre service à un gang
fâche celui contre qui on l'a servi, moitié moins fort — sans ce second
mouvement, on enchaînait les contrats des deux camps et on finissait ami avec
tout le monde ; le triangle de rivalité (§3.1) ne tenait plus.

## Les bancs

```bash
godot --headless --path . -s outils/respect.gd        # les quatre chapitres ci-dessus
godot --headless --path . -s outils/territoires.gd    # la carte des territoires en PNG
./outils/tableau.sh                                   # les barres et les cinq humeurs
./outils/compiler.sh                                  # tout le jeu se compile-t-il ?
```

`outils/respect.gd` vérifie, sur les **fonctions du jeu** et non sur des
copies : qu'aucun pâté n'est tenu hors de son trio (13 936 pâtés balayés), que
les trois paliers tombent aux bons chiffres, que les rivaux du secteur gagnent
et que les gangs d'ailleurs n'en savent rien, qu'une cabine refuse sous
quarante, qu'un contrat rendu déplace deux jauges, et qu'un allié abat pour de
vrai un flic qu'un neutre laisse tranquille.

⚠ Deux pièges déjà tombés dedans, gardés ici pour ne pas y retomber :

1. le banc balayait un **coin** de la carte, n'y trouvait qu'un secteur, et
   annonçait fièrement que deux districts sur trois n'avaient aucun gang ;
2. il cherchait un pâté du gang 0 dans ce même coin, retombait sur le
   centre-ville — qui n'appartient à personne —, testait alors les contrats
   d'un gang tiré au sort et s'étonnait que le respect ne bouge pas.

Un banc qui simplifie ce qu'il regarde ne prouve rien.

## Ce qui reste

- les **repaires** ne sont toujours que décor et territoire : y entrer, ou y
  déclencher une mission de gang, est un contenu à part entière ;
- les **téléphones de trois couleurs** (§4.1) : la difficulté existe et se
  mérite, mais une seule cabine la porte — le guide en veut trois, plantées à
  des endroits différents ;
- le **triangle de rivalité** est vérifié par les chiffres, pas par une
  contrainte : rien n'interdit formellement d'être à 100 chez les trois gangs
  d'un district, il faut simplement des contrats qui ne se fâchent jamais.
