# L'atelier de modification

*Phase 7 du guide « GTA 2 Voxel » (§7.2). Ce que le code fait, et pourquoi il
le fait comme ça.*

## Ce n'est pas un lieu de plus

Un garage de peinture sur deux vend aussi des modifications
(`FormesCarnage.est_atelier`, tiré du pâté — la carte est engendrée, la liste
ne peut donc pas être écrite à la main, et elle doit tomber pareil chez les
quatre joueurs sans passer par le réseau). Deux raisons :

1. GTA 2 fait pareil — on entre chez « Max Paynt » pour repeindre **et** pour
   s'équiper ;
2. un septième genre de lieu, c'est une pastille de plus sur une carte qui en
   porte déjà six, et un joueur qui cherche un garage en trouverait un sur deux
   qui ne repeint pas.

Mesuré au banc : 505 garages dans la ville, dont 249 ateliers.

## Le choix se fait au volant

Cinq pastilles peintes en couronne sur la dalle. On se gare sur celle qu'on
veut, `F` achète — la ligne du tableau de bord dit toujours quoi et combien.

**Pourquoi pas un menu.** Ce jeu a trois touches en tout. Ouvrir une liste
déroulante au milieu d'une poursuite, c'est demander au joueur de mourir en
lisant. La baie est *la plus proche*, sans seuil : un seuil laisserait le
joueur au milieu de la dalle sans rien acheter et sans savoir pourquoi.

| baie | prix | ce que ça fait |
|---|---|---|
| **PLAQUES** (bleu) | 450 $ | la jauge de recherche **cesse de monter** 45 s |
| **MITRAILLEUSE** (jaune) | 950 $ | `ESPACE` au volant : tir avant, munitions infinies |
| **MINES** (rouge) | 750 $ | quatre mines ; `F` en largue une derrière soi |
| **HUILE** (violet) | 550 $ | quatre flaques ; `F` en répand une |
| **BOMBE** (orange) | 650 $ | la voiture saute six secondes après qu'on l'a quittée |

Les plaques **ne sont pas** le garage de peinture : la jauge ne redescend pas,
elle se **fige**. C'est ce qui en fait un achat de poursuite — on ne va pas au
garage avec trois voitures aux fesses, on essaie de tenir quarante-cinq
secondes. Elles suivent le JOUEUR (c'est une affaire de police) ; tout le reste
reste avec la CARROSSERIE quand on descend.

## Ce que l'hôte décide

Les mines et les flaques vivent dans `VilleVivante`, comme les caisses et les
barrages : un client qui annoncerait ses propres victimes ferait sauter la
ville depuis son navigateur.

- **une mine s'amorce** (1,4 s) avant de mordre. Sans ce délai elle explosait
  sous la voiture qui venait de la lâcher : on payait sept cent cinquante
  dollars pour se tuer soi-même, une fois, et on n'en rachetait plus jamais ;
- **une mine ne saute qu'une fois**, et le poseur marque la victime — le gang
  de la voiture le lui reproche, comme s'il avait tiré ;
- **une flaque reste** et sert plusieurs fois. Elle ne blesse pas : elle fait
  perdre le cap. En poursuite, le poursuivant ne meurt pas, il part dans le
  décor et se retrouve trois rues en arrière ;
- **elle glisse aussi sous celui qui l'a posée.** Une flaque inoffensive pour
  son propriétaire serait une arme sans risque : on en sèmerait une devant
  chaque carrefour sans jamais se retourner. Pour un joueur, on réutilise
  l'état « sonné » du choc — la voiture part en toupie et ne répond plus une
  seconde ;
- **dix-huit pièges** au maximum dans la ville ; au-delà, le plus vieux
  s'efface. Refuser la pose punirait celui qui a payé, et il ne verrait même
  pas pourquoi ;
- **la bombe est attachée au VÉHICULE**, pas au joueur : sinon un joueur qui se
  déconnecte emporterait la bombe avec lui et la voiture resterait piégée
  jusqu'à la fin de la manche.

## La mitrailleuse de bord

C'est une arme de plus dans la table (`ARMES["canon"]`), mais elle n'entre
jamais dans `_arme` : on la prend à la place de son arme **tant qu'on est au
volant**, et on retrouve la sienne en descendant. Sinon l'achat coûtait au
joueur le fusil qu'il venait de ramasser.

## Deux défauts trouvés en chemin

**Toutes les auréoles du jeu étaient debout.** Un `TorusMesh` de Godot est déjà
couché dans le plan du sol ; le `rotation_degrees = Vector3(90, 0, 0)` que ce
fichier lui collait depuis douze versions le mettait **debout**. Garages,
hôpitaux, arènes, repaires, cabines, joueurs : des arceaux de six mètres
plantés en travers de la rue, qui se croisaient d'un carrefour à l'autre.
Personne ne l'avait vu parce que les bancs les photographiaient **de face**, où
un arceau ressemble à un cercle. `outils/voir.sh d:atelier` les prend de trois
quarts. (`jeux/bousculade.gd` et `jeux/enigme.gd` ont le même quart de tour ;
ils n'ont pas été touchés — ce sont d'autres jeux.)

**Les pastilles étaient noyées dans la dalle.** Posées à 0,14 sous une dalle
qui va de 0,06 à 0,16, et translucides par-dessus le marché : les cinq
couleurs viraient toutes au même kaki. C'est la deuxième fois que ce piège se
referme ici — la première, c'étaient les marques des repaires dans l'épaisseur
du plancher.

## Les bancs

```bash
godot --headless --path . -s outils/atelier.gd   # baies, mines, huile, bombe, plaques
./outils/voir.sh d:atelier                       # la dalle, de trois quarts
./outils/voir.sh "d:mine,d:huile" 12             # ce qu'on sème
```

`outils/atelier.gd` vérifie sur les fonctions du jeu : la part des garages qui
vendent, que chaque pastille se désigne elle-même et qu'entre deux pastilles on
tombe toujours sur l'une des deux, l'amorce et l'unicité d'une mine, le plafond
de pièges, que l'huile fait tourner sans abîmer, que la bombe attend, et que
les plaques gèlent la recherche puis se font repérer.

## Le garage repeint pour de vrai (§1.3)

Le garage effaçait le casier et rendait la voiture telle quelle. GTA 2 la
**repeint**, et c'est ce qui fait qu'une voiture qui sort du garage n'est plus
celle que la police cherchait : la mécanique et l'image racontent enfin la
même chose.

- Dix peintures (`FormesCarnage.PEINTURES`), **aucune couleur de gang** — une
  voiture repeinte aux couleurs des Braises serait prise pour une voiture des
  Braises. Jamais deux fois la même à la suite (`peinture_au_hasard`) : un
  garage qui rend la voiture de la couleur d'entrée n'a rien fait.
- La teinte **voyage** : dans le paquet de position (`tc`), dans le « pris »
  (`t`), dans le « sort » (`t`), et l'hôte la garde sur la voiture
  (`auto["teinte"]`, dixième colonne de la ligne `a` de l'instantané). Une
  voiture repeinte puis garée se retrouve de sa couleur, chez tout le monde.
  ⚠ `Color(int)` n'existe pas en 4.5 : c'est `Color.hex(int)` qui relit ce
  que `Color.to_rgba32()` a écrit (vérifié au banc, aller et retour).
- Le **halo** garde la couleur du joueur : `voiture(peinture)` le repeignait
  aussi, et un halo violet sous un joueur bleu est un joueur qu'on ne
  retrouve plus.
- La peinture ne touche que la **tôle** : voir « La peinture ne recouvre que la
  tôle » dans `CONCEPTION-VEHICULES.md`.

Au banc : `--banc-position=garage` pose le pilote sous un portail — la voiture
ressort repeinte à la première image et le journal l'écrit (`[banc] repeinte
en #… au garage …`). `outils/voir.sh v:peintures` sort les dix peintures sur
une même carrosserie ; `outils/recherche.gd` §7 vérifie l'aller-retour hôte →
instantané → client → « pris ».

## Ce qui reste

- la **bombe à distance** du guide (un bouton pour la déclencher) n'existe pas :
  on n'a plus de touche libre ;
- le **lance-flammes monté** sur le camion de pompiers (§6.2) reste à faire, et
  dépend d'une mission.
