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
godot --headless --path . -s outils/respect.gd     # chapitre 5 : les repaires
godot --headless --path . -s outils/marche.gd      # praticabilité des 15 intérieurs
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

- **Y déclencher une mission de gang.** Les contrats passent toujours par les
  cabines ; un repaire pourrait en donner de plus longs, ou de plus rares.
- **Les faire réagir.** Les trois hommes sont plantés en animation de repos.
  Se retourner quand on entre, ou s'écarter du râtelier, demanderait de les
  faire vivre — et donc de les rendre solides, donc de rouvrir la question du
  passage dans six tuiles.
- **Le repaire d'un gang hostile.** Aujourd'hui la porte reste simplement
  fermée. Y entrer de force — un raid, la prise du territoire — est un contenu
  à part entière, et c'est ce que le guide (§3) laisse entrevoir.
