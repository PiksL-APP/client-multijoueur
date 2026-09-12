# Les à-côtés

*Phase 9 du guide « GTA 2 Voxel » (§4.3) : taxi, Kill Frenzy, colis cachés,
cascades. Ce qu'on trouve dans la rue sans que personne l'ait demandé.*

**Pourquoi ils comptent.** Sans eux, une manche de Carnage est un bac à sable
où l'on tourne en rond entre deux contrats. Un colis qui brille à trois rues
donne une RAISON de tourner à droite.

## Les colis cachés

Huit colis dorés posés dans la ville à tout moment, entre 420 et 1 500 pixels
d'un joueur — ni sous le capot, ni à l'autre bout de la carte. Chacun rapporte
220 $ ; les **dix** trouvés valent 3 000 $ de plus et une annonce à l'écran.
Ils se ramassent en roulant : le rayon est de 78 pixels, pas 52 comme une
caisse d'arme, parce qu'à trois cents pixels par seconde on traverse un rayon
de cinquante entre deux images.

## Le Kill Frenzy

Un crâne rouge au sol. On le prend, et le défi commence : **huit victimes en
trente secondes**, avec **l'arme qui vient avec** — sans elle, le Frenzy
consisterait à courir chercher une caisse et le chrono serait fini avant de
commencer. Mitraillette ou roquette : à la roquette on cherche la foule, à la
mitraillette on cherche le trottoir, et ce sont deux défis différents.

Réussi : 1 800 $. Manqué : le compte s'affiche, et rien.

Le compte passe par `_abattre`, exactement là où le score est compté : il n'y
a pas de second comptage à côté qui pourrait diverger.

## La course de taxi

**Un métier attaché à une carrosserie.** On devient chauffeur en volant un
taxi, on cesse de l'être en le laissant — pas de menu, pas de bouton « prendre
le service » : la voiture EST le contrat.

Au pas (moins de 90 px/s), un piéton à moins de 110 pixels hèle. `F` le prend :
il quitte le trottoir — c'est **l'hôte** qui le retire, sinon les trois autres
joueurs le verraient marcher pendant toute la course. Une destination est
tirée dans la rue entre 900 et 2 600 pixels (à quatre mille, la course dure
plus longtemps que la manche) et le radar la pointe. `F` à l'arrivée paie
32 $ par pâté, 140 $ minimum.

Descendre du taxi annule la course : le client ne suit pas à pied.

## Les cascades — et l'écart avec le guide

⚠ **Le guide parle de SAUTS** (« Insane Stunt »). Notre ville est plate et la
voiture n'a pas d'altitude : un tremplin ne peut rien décoller, et simuler un
saut serait une animation, pas une cascade.

La cascade est donc le **FRÔLEMENT** : passer à plus de 240 px/s au ras d'une
voiture **qui roule**, sans la toucher. Même geste, même risque, même
récompense — et c'est vérifiable, ce qu'un saut simulé ne serait pas.

La fenêtre est étroite par construction : entre le rayon de choc (38 px, au-delà
on s'est percutés) et 54. Les frôlements s'**enchaînent** : trois secondes pour
le suivant, jusqu'à ×5, soit 450 $.

⚠ Chaque voiture ne compte qu'une fois par passage (2,5 s de mémoire par
identifiant). Sans ça, longer une file de voitures rapportait quinze primes à
la seconde.

## Les bonus nommés (§4.3)

GTA 2 crie un nom en lettres capitales quand on fait quelque chose d'énorme
d'un coup — c'est ce qui manque à un combo, qui ne dit qu'un chiffre. Trois
séries, chacune sa fenêtre :

| bonus | il faut | fenêtre | prime |
|---|---|---|---|
| **MEDICAL EMERGENCY** | cinq passants **écrasés** | 8 s | 900 $ |
| **WIPE OUT** | trois voitures détruites | 6 s | 1 200 $ |
| **INSANE STUNT** | la chaîne de frôlements au maximum (×5) | — | 600 $, en plus du frôlement |

Les deux premières vivent chez l'**hôte** (`VilleVivante.SERIES`,
`_avancer_la_serie`), là où les victimes et les épaves sont déjà comptées : un
client qui annoncerait ses propres exploits les inventerait. ⚠ **Écrasés, pas
abattus** : `_abattre` porte déjà le drapeau `ecrase`, et cinq passants à la
roquette ne sont pas un exploit — vérifié au banc. La série se **remet à zéro**
quand elle paie : sinon le sixième passant rejouerait le bonus, et le septième,
et l'annonce ne voudrait plus rien dire.

L'INSANE STUNT est le seul à vivre chez le client, qui seul voit ses
frôlements (`_compter_les_frolements`) ; quand la chaîne touche `CASCADE_MAX`,
le bonus s'ajoute à la prime du frôlement et la chaîne repart de zéro.

Tous paient par le guichet commun (`payer`, donc un « k » avec `q` =
« bonus ») et s'annoncent à part (« bonus », avec leur nom) : le nom en
capitales au milieu de l'écran, pour celui qui l'a fait seulement — un bonus
qui s'annonce chez tout le monde ressemble à une publicité.

## Où ça vit

| quoi | qui décide |
|---|---|
| poser les colis et les crânes | l'hôte (`_semer_les_a_cotes`) |
| ramasser | l'hôte tranche — deux joueurs sur le même colis à cent millisecondes près, et le premier arrivé est celui que l'hôte a vu |
| le chrono du Frenzy | l'hôte |
| la course de taxi | le client — sauf le client qui monte et le paiement |
| les frôlements | le client, qui envoie le paiement à l'hôte |

Le paiement de tout ce qui n'est pas une victime passe par `VilleVivante.payer`
— le même guichet que le reste : même tableau, même effet de gain, même argent
sur soi. Un montant négatif ne rapporte rien (vérifié au banc).

## Le banc

```bash
godot --headless --path . -s outils/missions.gd   # semailles, colis, frenzy, taxi, bonus nommés
./outils/voir.sh "d:colis,d:frenzy" 7             # les deux ramassages
```

Il vérifie ce que l'hôte voit : que la ville garde huit colis et deux crânes,
qu'aucun n'est posé dans un mur, qu'un colis pris deux fois ne compte qu'une,
que la collection paie, que le chrono du Frenzy ne pardonne pas, que le client
ne monte pas deux fois. La conduite (le taxi, les frôlements) se juge à
l'écran : elle vit chez le client, qui ne se charge pas hors scène.

## Ce qui reste

- le **taxi Xpress** et sa carrosserie (§7.1) ;
- les colis sont **réapprovisionnés** autour des joueurs ; GTA 2 en cache cent
  à des endroits fixes, ce qui récompense la mémoire plutôt que le hasard.
  C'est un choix de manche courte, pas un oubli.
