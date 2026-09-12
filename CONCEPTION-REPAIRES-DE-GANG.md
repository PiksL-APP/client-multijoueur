# Ouvrir les repaires de gang (guide §3)

⚠ Ne pas confondre avec `CONCEPTION-REPAIRES.md`, qui parle des **huit
appartements** qu'on achète (le mot « repaire » y désigne la planque du joueur).
Ici il s'agit des **quartiers généraux des sept gangs** : le tag peint au sol,
les hommes autour, les voitures dans les cours.

Jusqu'ici c'était du **décor et du territoire** : ils coloraient le quartier,
disaient chez qui l'on était, peuplaient la rue de leurs hommes — et on n'y
entrait pas. C'était le dernier point ouvert de la phase 4.

## La règle : quatre-vingts de respect

On entre à pied, debout sur le tag, `F`. La porte ne s'ouvre qu'au **palier
allié** (`VilleVivante.SEUIL_ALLIE`, 80) avec le gang du repaire.

C'est la seule chose que le respect ouvre et qu'on ne peut **pas** obtenir
autrement. Tout le reste vient à vous : les contrats sonnent dans une cabine que
vous croisez, les alliés se battent à côté de vous quand on vous attaque. Le
repaire, il faut y aller — et savoir chez qui.

⚠ **Le refus dit le chiffre.** « Les Braises n'ouvre qu'à 80 de respect (vous :
54). » C'est la leçon des cabines de couleur : sans le nombre, une porte qui ne
s'ouvre pas se lit comme une porte cassée, et le joueur n'y revient jamais.

## Derrière la porte : l'armurerie

Le râtelier est le **seul comptoir d'armes du jeu**. Jusqu'ici une arme ne
tombait que d'une caisse ou d'un corps, c'est-à-dire du hasard ; ici on la
choisit — à condition d'avoir mérité la porte.

| gang | vend | prix |
|---|---|---|
| Les Braises, Le Lierre, Les Néons | mitraillette (60 balles) | 700 $ |
| La Fonte, Les Scories, Les Ronces, Le Consortium | roquettes (6 tubes) | 1 700 $ |

Le Consortium vend des roquettes **à dessein** : c'est le gang commun aux trois
districts, celui qu'on peut fréquenter partout, et il vaut mieux que la
marchandise rare ne soit pas celle du gang qu'on croise le plus.

⚠ **On recharge, on ne remplace pas.** Payer 700 $ pour repartir avec le même
chargeur à moitié vide serait la meilleure façon de ne jamais revenir : si
l'arme achetée est déjà celle en main, les munitions **s'ajoutent**.

## Un seul dessin, sept teintes

Sept plans auraient été sept fois le travail des huit appartements pour un lieu
qu'on **traverse** : le joueur y passe dix secondes. Ce qui doit changer d'un
gang à l'autre, c'est ce qu'on reconnaît tout de suite — la couleur au mur, au
sol, sur le canapé — et une table de teintes le fait.

⚠ **On garde la teinte, pas la saturation.** Premier essai : `darkened()` et un
mélange vers le gris sur la bannière du gang. Le Lierre a rendu une **boîte
verte** — murs, sol et plafond de la même couleur franche, où plus rien ne se
distinguait. On reprend donc la TEINTE (`h`) du gang et l'on IMPOSE la
saturation et la luminosité : les sept repaires sont également sombres et
également lisibles, et seule la nuance change. L'accent, lui, reste franc, et il
est sur le canapé et le tapis — au sol, là où une caméra de trois quarts le voit.

⚠ **L'identifiant porte le numéro du gang** (`repaire3`). `Interieurs.plan(id)`
est appelé de partout avec l'identifiant seul — les collisions, l'entrée, les
postes, les bancs ; lui passer le gang à côté aurait voulu dire ajouter un
paramètre à huit fonctions pour un seul cas.

⚠ **Un repaire n'a pas de coffre**, et ce n'est pas une faute : on n'y range pas
son argent, on y achète une arme. `Interieurs.coffre()` criait au manque —
c'était le cri des bancs (vitrine, marche, vider), qui cherchent tous le coffre
pour cadrer ou pour commencer leur inondation. Ils se rabattent sur le râtelier.

⚠ **On ne sort pas sa voiture du garage d'un autre.** `_sortir_de_chez_soi()`
sert aux deux : sans le drapeau, quitter le repaire des Braises faisait
apparaître sous soi la voiture rangée chez soi, à l'autre bout de la ville.

## Il y a du monde dedans

Trois hommes du gang : celui qui tient la table, l'armurier à côté de son
râtelier, celui qui surveille l'entrée dos au mur ouest. Sans eux on entrait
chez des gens qui n'y sont pas — une pièce meublée, éclairée, un râtelier plein,
et personne : ça se lit moins comme un repaire que comme un appartement témoin.

Ils sont **décoratifs** et ne bloquent pas le passage (`libre()` ne connaît que
les meubles du dessin) : trois silhouettes dans six tuiles et l'on se coince en
allant au râtelier. Ils sont donc posés là où l'on ne passe pas.

⚠ **On n'utilise pas `poser_pantin` ici.** Elle multiplie la position par
`ECHELLE` parce qu'elle sert à des appelants dont la racine n'est *pas* mise à
l'échelle (le banc de vitrine). Dans `batir()`, le pantin est enfant de la
coque, qui porte déjà `scale = ECHELLE` : les trois hommes se sont retrouvés au
double de leur place, deux dehors sur le bitume et le troisième à travers une
cloison. On pose en tuiles, comme les meubles, et on divise la taille par la
même échelle.

⚠ **La casquette est taillée pour une vue de dessus.** Dehors, la caméra ne voit
à peu près que ça : elle est volontairement trop grande, et c'est ce qui rend un
homme de gang repérable dans une rue. Ici la caméra est à trois mètres — la même
calotte devient un béret qui déborde des épaules. On la ramène à 0,5 × 0,62.

⚠ **Pas d'anneau d'humeur à l'intérieur.** Dans la rue il dit ce que le gang
pense de vous ; chez lui, la réponse est connue (on n'entre qu'au palier allié),
et trois disques verts au sol d'une pièce de six tuiles éclairent le plancher
comme une piste de danse.

## L'autre bout de la jauge : le RAID

Le repaire s'ouvre au palier allié. Restait ce qu'on fait d'un gang qui vous
**tire à vue** : rien, jusqu'ici. On évitait son quartier, et c'était tout ce
que le palier « vous chasse » valait.

Le raid **ne se déclenche pas** : il commence quand on se tient sur le tag d'un
gang hostile. C'est le geste, pas une touche — on est chez eux, ils tirent, et
le compteur descend à chaque homme tombé. Cinq hommes (`PAR_REPAIRE`), et le
repaire tombe : 2 600 $, le tag passe **à vos couleurs**, l'armurerie s'ouvre à
vous quel que soit le respect, et le gang **n'y renaît plus**.

⚠ **Il faut être hostile.** Nettoyer le repaire d'un gang neutre, ce serait le
contrat de la cabine avec un autre nom, et sans l'aller-retour de respect qui le
rend intéressant. Le raid est réservé à ceux qui vous chassent déjà : on ne perd
rien qu'on n'ait déjà perdu.

⚠ **On compte les hommes DU REPAIRE, pas ceux du gang.** Un raid qu'on avance en
abattant des passants de la même bannière trois rues plus loin, ce n'est plus un
raid, c'est une chasse — et on le finirait sans jamais s'approcher du tag. Le
banc abat un homme à quatre rayons et vérifie que le compteur ne bouge pas.

⚠ **Sortir du tag ne l'annule pas tout de suite** (22 s). Un raid qu'on perd
parce qu'on s'est mis à couvert derrière un mur serait un raid qu'on ne gagne
qu'en restant planté au milieu, c'est-à-dire en mourant.

⚠ **Un repaire pris ne se repeuple plus.** Sans ça le gang renaissait sur le tag
qu'on venait de lui prendre, et la prise ne voulait rien dire : on rejouait le
même raid en boucle sur le même terrain.

⚠ **Un morceau bâti APRÈS la prise porte un tag neuf**, aux couleurs du gang
chassé : le repaint de l'événement n'a repeint que les morceaux chargés à ce
moment-là. On s'éloigne, on revient, et le repaire est redevenu à eux — alors
que la simulation, elle, sait qu'il est pris. Une passe par image remet les tags
d'accord avec la ville.

La prise voyage dans l'instantané (deux entiers par repaire) : les trois autres
joueurs voient le tag changer de camp, et le banc le vérifie en appliquant
l'instantané à une seconde ville.

## Les hommes du repaire réagissent : la colère

Les cinq gars qui traînent autour du tag (`_peupler_les_repaires`, ceux qui ont
une `attache`) obéissaient à la même règle que n'importe quel homme de gang dans
la rue : ils ne tirent que si leur **gang** vous chasse. Tant que le gang était
neutre, on pouvait donc en abattre cinq d'affilée sous leur propre tag, et les
survivants continuaient à flâner autour du cadavre de leurs copains. Un repaire
se lisait comme une rue un peu plus peuplée.

Depuis le 11/09, un repaire **se défend**. Deux gestes le mettent en colère :

- **abattre un des siens** (`_abattre` appelle `facher_le_repaire` dès que le
  mort porte une `attache`) ;
- **ouvrir un raid** en se tenant sur le tag (`tenir_le_terrain`, juste après
  l'événement « raid ouvre »).

Tous les hommes attachés à ce tag reçoivent alors `colere = {j: cle, t: 25 s}`
et, dans `_animer_les_gens`, cette branche passe **avant** celle de l'allié et
celle du gang hostile : ils chargent le coupable à `VITESSE_GANG` et lui tirent
dessus, quoi que leur bannière pense de lui par ailleurs. La colère retombe seule
(le compteur descend à chaque image), et elle s'éteint aussi si le coupable est
mort, parti, ou trop loin (`COLERE_PORTEE`, 700 px) — ils ne traversent pas la
ville pour vous retrouver, ils défendent *leur* coin.

⚠ **C'est le repaire qui se fâche, pas le gang.** Le respect ne bouge que par
les règles habituelles (tuer un homme de gang coûte ce qu'il coûtait). Un gang
neutre dont on a saigné le repaire vous laisse tranquille trois rues plus loin —
c'est ce qui distingue une rixe locale du palier « vous chasse », et ce qui fait
que la jauge garde un sens.

⚠ **La colère ne connaît pas les alliés.** Un allié qui abat un des hommes du
repaire (par une balle perdue, ou une bombe) se fait charger comme un autre :
on n'a pas ajouté d'exception, parce qu'un repaire qui pardonne à celui qui
vient de tuer un de ses gars n'est pas un repaire. Vingt-cinq secondes plus
tard, tout est oublié, et le palier allié reprend ses droits.

Pendant un raid, la colère est rafraîchie par les morts eux-mêmes : chaque homme
tombé remet 25 s à ceux qui restent. C'est ce qui donne au raid sa forme — les
cinq sortent ensemble à l'ouverture, et le dernier vous court encore après.

Le banc (`outils/respect.gd`, chapitre 7) pose un repaire d'un gang neutre,
abat un homme, vérifie que ses copains prennent le tireur en chasse et se
rapprochent (273 px → 81 px en deux secondes de simulation), puis que la colère
retombée à zéro les calme.

## Le patron confie du travail : les missions du repaire

Une cabine confie un travail de rue — trois hommes, une voiture, deux étoiles
— et le paie en une minute. Le repaire, jusqu'ici, ne confiait rien : on y
entrait pour le râtelier et on ressortait. Depuis le 11/09, **celui qui tient
la table** a du travail pour ceux qui ont mérité la porte. On se tient au bout
de la table (la marque **orange** au sol, `postes.patron` dans la fiche), `F`,
et le patron donne l'une des deux missions :

| mission | ce qu'on fait | durée | prime | respect |
|---|---|---|---|---|
| **la mallette** | elle est posée **chez un rival**, à cent ou deux cents pixels de son tag, au milieu de ses gars. On la ramasse comme un colis, puis on la **rapporte sur le tag du patron** — à pied ou au volant | 120 s | 2 200 $ | +22 chez le patron, −11 chez le rival |
| **le lieutenant** | un homme du repaire rival, **trois fois plus dur** (9 points de tôle), attaché à son tag, coiffé d'une flèche orange. On l'abat | 100 s | 2 600 $ | idem |

Plus long qu'un contrat, plus rare (il faut la porte, donc quatre-vingts de
respect), et payé en conséquence : c'est ce que le palier allié donne d'autre
que l'aide en combat et le râtelier. Deux genres seulement, à dessein — un
troisième qui ressemblerait à un contrat de cabine n'aurait pas sa place ici.

⚠ **Une mission occupe la même place qu'un contrat.** On n'a qu'un travail en
main : `contrats[cle]`, le même dictionnaire, les mêmes `_avancer_contrats`,
`_solder_contrat`, le même événement `ctr`. Sinon on prenait la mission chez
soi, puis un contrat à la cabine d'en face, et le tableau de bord ne savait
plus quel chrono montrer. La ligne du HUD dit **MISSION** au lieu de CONTRAT,
c'est la seule différence visible.

⚠ **La mission vise un POINT, le contrat non.** Un contrat de cabine laisse le
client chercher le repaire ou le garage le plus proche ; une mission envoie
`x, y` dans `ctr` — la mallette, puis le tag où la rapporter ; le repaire du
lieutenant — et le radar le pointe comme il pointe une course de taxi.

⚠ **La mallette n'est à personne d'autre.** Un coéquipier qui passe dessus ne
la ramasse pas (`pour` porte la clé du preneur, dans l'instantané aussi) :
sinon il la faisait disparaître de la mission de celui qui l'a prise, qui
courait vers un point vide. **Le lieutenant, lui, tombe pour tout le monde** :
un coéquipier qui l'abat à votre place ne vous vole pas la mission — le patron
voulait sa tête, il l'a. Compter seulement les balles du preneur, c'était deux
joueurs qui se gênent devant le même homme au lieu de se couvrir.

⚠ **Prendre la mallette, ou toucher le lieutenant, sort le repaire au
complet.** C'est la colère du repaire (plus haut), branchée sur `ramasser` et
sur `abattre_par_id` : avant, on fouillait le repaire d'un gang neutre sous
son nez et personne ne bougeait ; et le lieutenant, avec ses neuf points, se
laissait cribler pendant que ses gars regardaient.

⚠ **Le rival visé est celui qui a encore un repaire par ici.** Un rival dont
on a pris le repaire n'a plus de mallette à garder ni de lieutenant à
protéger, et pointer un tag vide, c'est deux minutes à tourner autour. À
défaut d'un rival du trio, n'importe quel autre gang qui a un repaire fait
l'affaire : **sur une ville dessinée, les gangs sont posés par île et le trio
du secteur n'y veut rien dire.** Et s'il n'y a rien, le patron le dit (« leurs
rivaux n'ont plus de repaire par ici ») plutôt que de confier une mission
impossible.

⚠ **Pikstown, au 11/09, n'a que les repaires de La Fonte** : les ponts relient
les îles, `_classer` n'en voit qu'une, et toute la terre est à un seul gang.
Une mission y est donc refusée tant que les gangs ne sont pas répartis — le
banc photo (`--banc-mission`) accepte un repaire du même gang pour pouvoir
photographier quand même. C'est un chantier de la carte, pas des missions.

⚠ **`.get(clé, défaut)` évalue son défaut.** `PRIME_CONTRAT[genre]` en défaut
de `c.get("prime", …)` plantait le solde d'une mission — qui a sa prime, mais
pas de ligne dans PRIME_CONTRAT — avant de payer. Le banc l'a vu à la
première mission gagnée.

Ce qu'une mission laisse derrière elle quand elle s'arrête, gagnée ou perdue
(`_ranger_la_mission`) : la mallette est ramassée par la ville, le lieutenant
redevient un homme du repaire comme les autres, à trois points de tôle.

**Et le patron laisse le lance-flammes** (guide §6.2 : « débloqué par une
mission ») à la première mission rendue, une fois pour toute la manche —
c'est un outil, pas une prime. Au volant d'un camion de pompiers, `F` bascule
la lance eau/feu et ESPACE crache : les passants grillent, les voitures des
autres brûlent, un foyer s'allume au bout du jet. Détail :
`CONCEPTION-VEHICULES.md` (le camion de pompiers) et `outils/atelier.gd` §7.

### Ce qu'on voit

- **la marque orange** au bout de la table, à côté du patron. ⚠ Posée devant
  lui, à soixante centimètres de la porte, c'est la porte qui répondait à
  `F` ; posée derrière lui, son propre corps la cachait sous la caméra de
  trois quarts. On l'a cherchée sur la photo avant de comprendre ;
- **la mallette** : une valise fauve à fermoirs de laiton, couchée (un
  rectangle vu de dessus), sur un anneau et un disque orange qui luit. ⚠ Le
  premier essai était en cuir sombre et en classe `LUMIERE` : sous le soleil,
  un bloc noir — `LUMIERE` est la classe des fenêtres allumées, que le shader
  remplace par du verre sombre le jour ;
- **le lieutenant** : un disque orange qui bat à ses pieds, une flèche orange
  À PLAT au-dessus de sa tête, qui pointe vers le bas de l'écran. ⚠ Debout,
  dans le plan vertical, la caméra de soixante-douze degrés n'en voyait que
  la tranche ; en voxels éclairés, elle rendait un T brun. Elle est unshaded
  et couchée, et elle se lit ;
- ⚠ **les anneaux sont posés à 0,6, pas au ras du sol** : sur Pikstown, le
  trottoir est une dalle que `hauteur_en` ne compte pas, et un anneau à cinq
  centimètres est DANS la dalle. Même leçon que les flaques des lampadaires —
  les anneaux des colis, des caisses et du Frenzy ont encore ce défaut sur
  la ville dessinée.

## Le râtelier : un meuble qui n'existait pas

Kenney est un kit de **meubles** — il n'a pas d'arme. Une bibliothèque ouverte
aurait fait l'affaire dans le code et pas du tout à l'écran, où l'on ne voit que
la silhouette. `outils/ratelier.py` fabrique donc un panneau de bois, trois
fusils et la caisse de munitions au pied, en boîtes, comme `outils/coffre.py`
fabrique le coffre-fort.

Les deux partageaient quatre-vingt-dix lignes de tampon glTF identiques au
caractère près : elles vivent maintenant dans **`outils/meuble.py`**, et le
troisième meuble n'en fera pas une troisième copie.

⚠ **Le râtelier garde ses métaux.** Repeint aux couleurs du gang comme le reste
du mobilier, il devenait une planche unie et les trois fusils disparaissaient
dedans — c'est précisément la silhouette qui fait le meuble.

## Les bancs

```bash
godot --headless --path . -s outils/respect.gd     # chapitre 5 : les repaires, 7 : la colère
godot --headless --path . -s outils/missions.gd    # chapitre 6 : les missions du repaire
godot --headless --path . -s outils/marche.gd      # praticabilité des 15 intérieurs, patron compris
./outils/chez_soi.sh repaire2                      # l'intérieur EN JEU, avec ses marques
./outils/voir.sh "d:mallette,d:lieutenant"         # la valise et le repère, en vitrine
# la mission en ville, photographiée (le pilote est tenu à côté de la cible) :
xvfb-run -a godot --path . --rendering-driver opengl3 --solo --banc-jeu=carnage --manche=10 \
  --banc-position=repaire:3 --banc-mission=mallette --photo=/tmp/vues
./outils/vitrine.sh repaire2 "" "" "" pantin       # le repaire du Lierre, à l'échelle
./outils/vitrine.sh repaire4 "" "" "" pantin       # celui des Néons, pour comparer
python3 outils/ratelier.py                         # refabriquer le meuble
```

`outils/marche.gd` **inonde maintenant les quinze intérieurs**, pas les huit :
un repaire est un intérieur comme un autre, il a un dessin, des meubles, une
porte, et exactement les mêmes façons de se rendre impraticable. Sept dessins de
plus à surveiller pour zéro ligne de test en plus.

⚠ **Tous les postes ne sont pas attendus partout.** Le banc parcourait
`Interieurs.POSTES` en entier et criait donc « PAS DE ARMURERIE » dans les huit
appartements le jour où le râtelier est devenu un poste — quinze fautes d'un
coup, aucune vraie. Un banc qui crie pour rien n'est plus lu : il attend
maintenant le coffre et la penderie dans un appartement, le râtelier dans un
repaire.

Au 10/09 : les quinze intérieurs praticables, le râtelier atteint en 2,0 s
depuis la porte dans les sept repaires, sept murs de couleurs différentes pour
sept gangs, et les deux armes du jeu vendues quelque part.

## Ce qui reste

- **Répartir les gangs de Pikstown** (la carte) : tant que toute la terre est
  à La Fonte, le patron n'a personne à envoyer chez qui que ce soit.
- **Une troisième mission** qui ne soit ni une mallette ni une tête — un
  convoi à escorter, par exemple — demanderait une voiture de l'hôte qui suit
  le joueur, ce qui n'existe pas encore.
- **Faire réagir ceux de l'intérieur.** Dehors, les hommes du tag se
  défendent (la colère, plus haut) ; dedans, les trois hommes restent plantés
  en animation de repos. Se retourner quand on entre, ou s'écarter du
  râtelier, demanderait de les faire vivre — et donc de les rendre solides,
  donc de rouvrir la question du passage dans six tuiles.
- **Le territoire ne change pas de main.** Le repaire est pris, le tag est à
  vos couleurs, mais les pâtés autour restent peints de la bannière du gang
  chassé : `territoire_du_pate` est procédural, et le faire mentir demanderait
  une table d'exceptions consultée par toute la ville.
