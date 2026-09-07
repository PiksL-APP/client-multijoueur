# ÉNIGME — la ferme d'Aperture

> Cahier de conception. Rédigé le 07/09/2026, avant la première ligne de code.
> Il fixe ce qu'on fait, ce qu'on ne fait pas, et **ce que chaque choix coûte**.

## Ce qui change, et pourquoi il faut le dire tout de suite

ÉNIGME est aujourd'hui une manche coopérative de trois minutes : trois chambres
à dalles, un score, un dépôt en base, fin. Ce qui est demandé — un *Stardew
Valley* mâtiné de *Portal* et *Portal 2* — n'est pas une extension de ce jeu.
C'est **un autre genre** : une boucle longue, un monde qui survit à la
déconnexion, un inventaire, des saisons.

Concrètement, trois piliers du dépôt sautent :

| Pilier actuel | Ce qu'il devient | Pourquoi ça compte |
| --- | --- | --- |
| Une manche bornée, un dépôt de score en fin | Un monde persistant, une écriture par action | `jeux/partie.gd` ne convient plus tel quel |
| L'hôte simule, la base ne fait que recevoir | La base **fait autorité** sur la ferme | Un hôte qui ment sur un score fausse un classement ; un hôte qui ment sur une récolte s'enrichit **pour toujours** |
| Identité tirée au sort par le navigateur | Identité **rattrapable** | Une ferme perdue au vidage du cache est une promesse rompue |

Rien de tout ça n'est un obstacle. Mais aucun ne se règle en cours de route.

---

## 1. Le jeu

**Une ferme coopérative installée dans une installation Aperture désaffectée.**

On cultive en surface. Mais l'eau, la lumière et l'engrais ne viennent pas du
ciel : ils viennent d'en dessous, des chambres de test. Chaque chambre résolue
**branche définitivement un service sur la ferme** — une conduite d'irrigation,
un puits de lumière, une lampe chauffante pour l'hiver.

C'est ce qui marie les deux jeux au lieu de les juxtaposer : la boucle Stardew
donne l'enjeu (il faut de l'eau, il faut de la lumière, il faut passer l'hiver),
la boucle Portal donne le moyen. Sans ça on aurait deux jeux dans le même
exécutable, ce qui ne se voit pas sur une capture d'écran mais se sent à la
manette au bout de dix minutes.

### La boucle d'une journée

1. On se réveille à la ferme. L'énergie est pleine.
2. On laboure, on sème, on arrose, on récolte. Chaque geste coûte de l'énergie.
3. Quand l'énergie manque — ou quand il faut une ressource qu'on n'a pas — on
   descend dans une chambre. Les chambres ne coûtent pas d'énergie : elles
   coûtent du **temps**, ce qui est la même chose autrement.
4. On dort. La journée avance, les plants poussent d'un cran, la saison suit.

Deux à quatre joueurs sur **la même ferme**, en même temps ou non. La ferme
existe entre les sessions ; les joueurs vont et viennent.

### Les mécaniques de Portal, vues du dessus

La caméra est en vue de dessus. La gravité de *Portal* — se laisser tomber pour
prendre de la vitesse — n'existe donc pas. C'est la seule mécanique qu'on perd,
et il faut la remplacer plutôt que la simuler mal : **la vitesse se gagne au
sol**, sur du gel de propulsion, jamais dans une chute. Tout le reste se
transpose sans perte.

| Mécanique | Transposition en vue du dessus | Double emploi à la ferme |
| --- | --- | --- |
| **Pistolet à portails** (bleu / orange) | Deux portails sur les parois autorisées. L'élan est conservé : ce qui entre vite ressort vite, dans l'axe de la paroi de sortie | Déplacer une caisse — ou un seau d'eau — d'un bout du domaine à l'autre |
| **Gel de propulsion** (orange) | Le sol devient glissant et rapide ; c'est **là** qu'on prend l'élan | Une rigole : l'eau court sur le gel orange et irrigue au bout |
| **Gel de rebond** (bleu) | On ricoche sur les parois au lieu de s'y arrêter | Une parcelle en gel bleu renvoie la récolte au coffre : chaîne de moisson |
| **Gel de conversion** (blanc) | Rend n'importe quelle paroi portable au portail | Décape une parcelle épuisée et la rend labourable |
| **Pont lumineux** | Une surface franchissable au-dessus d'un vide ; bloque aussi le laser | Toiture de serre : une parcelle sous pont est protégée du gel |
| **Tunnel d'excursion** | Un courant qui porte joueurs, caisses et cubes | Convoyeur permanent entre la ferme et le silo |
| **Laser + redirecteur** | Un rayon, des cubes prismatiques pour le plier | Lampe chauffante : la parcelle éclairée pousse en hiver |
| **Dalles de poids et cubes** | *Déjà écrits* — `jeux/enigme.gd` d'aujourd'hui | Une dalle sous un silo pèse le stock |
| **Tourelles** | Obstacle mobile : elles voient un cône, on se cache | Épouvantails, une fois retournées |
| **Cube-compagnon** | Suit un joueur, pèse sur les dalles | L'animal de la ferme. Il a un nom, et on ne l'incinère pas |

### Les personnages

Pas de village d'humains : des **cœurs de personnalité** récupérés dans les
chambres, qu'on rebranche à la ferme. Chacun a une voix, une obsession et une
jauge d'affinité qui monte quand on lui apporte ce qu'il aime — une récolte
précise, un cube, un cœur rival.

Ce choix est délibéré : écrire dix villageois avec sept dialogues saisonniers
chacun, c'est trois cents répliques et un mois. Quatre cœurs qui commentent en
continu la ferme et les chambres, c'est le même sentiment de compagnie pour un
dixième de l'écriture — et ça donne la **voix narratrice** demandée sans avoir
à inventer un narrateur en plus.

L'Intendance — la voix du système — commente sans jamais aider. C'est le ton
de la maison : sec, faussement bienveillant, et **toujours en français**.

---

## 2. Les trois arbitrages techniques

### 2.1 L'image : on reprend le pack du hub

Le hub est déjà un village en pixel art vu de dessus — pack Anokolisa dans
`modeles/village/`, chargé par `commun/pixels.gd`, trié en profondeur par le
`y_sort_enabled` de `Ecran.plan()`. Sol, maisons, intérieurs, arbres, rochers,
héros à six animations, habitants : tout est là et tourne.

**Décision : ÉNIGME se construit avec ce pack, en vraie 2D comme le hub**, et
non en 2,5D comme CARNAGE. Fabriquer une seconde grammaire visuelle pour le
même jeu serait long, moins beau, et donnerait un hub et une ferme qui ne se
ressemblent pas alors qu'on passe de l'un à l'autre par une porte.

Ce que ça implique concrètement :

- ÉNIGME hérite d'un écran 2D (`plan()`), pas de `monde()`. `commun/decor.gd`
  ne sert plus pour ce jeu ;
- les parcelles, les cultures et les outils demandent des tuiles que le pack
  n'a pas encore : elles se prennent dans le même pack Anokolisa (même main,
  même palette) plutôt qu'ailleurs ;
- **l'appareillage Aperture se DESSINE, il ne se pixellise pas.** Portails,
  gels, ponts lumineux, tunnels, lasers : ce sont des formes lumineuses qui
  palpitent, et `scenes/lueur_portail.gd` a déjà posé ce précédent dans le
  hub. Un sprite fixe ne pulserait pas et ne s'accorderait pas à la palette.
  C'est aussi ce qui fera lire au premier coup d'œil ce qui relève de la ferme
  et ce qui relève de la machine.

Une piste écartée en route, notée pour ne pas y revenir : fabriquer les
sprites en **grilles de caractères dans le source** (un caractère = une
couleur), à la manière de `autoload/sons.gd` pour l'audio. Le procédé marche —
il a été écrit et photographié — mais le résultat est nettement plus laid que
le pack, pour beaucoup plus de travail. Il ne se justifierait que si l'on
devait renoncer aux ressources binaires, ce qui n'est plus le cas depuis que
le hub en porte.

### 2.2 L'identité, sans compte

Aujourd'hui : un identifiant tiré au sort au premier passage, dans le
navigateur. Parfait pour un score, inacceptable pour une ferme.

**Décision : un code de ferme.** Six mots, affichés en jeu, notés par le
joueur. N'importe quel navigateur qui saisit ce code rejoint la ferme et y
retrouve ses affaires. La ferme appartient au code, pas au navigateur.

Ce que ça coûte : quiconque connaît le code entre. Il n'y a pas de mot de
passe, donc pas de récupération de mot de passe, donc pas de courriel, donc pas
de compte — c'est exactement le compromis qu'on veut à ce stade, mais il faut
le dire à l'écran, pas seulement ici.

### 2.3 Sortir du modèle « manche + dépôt »

`jeux/partie.gd` fait deux choses : la plomberie (canal, présences, élection
d'hôte, HUD) et la manche (décompte, chrono, fin, dépôt du score). La première
sert au monde persistant, la seconde non.

**Décision : on scinde.** `jeux/socle.gd` garde la plomberie ; `jeux/partie.gd`
en hérite et ajoute la manche (CARNAGE ne bouge pas d'une ligne) ;
`jeux/monde.gd` en hérite et ajoute le temps long. Une refonte de trente lignes,
faite une fois, plutôt qu'un `if persistant:` semé dans le socle.

**Et la base fait autorité.** Aujourd'hui, un hôte malveillant gonfle un score
d'une manche : la fonction SQL borne les dégâts. Demain, il se donnerait mille
récoltes **définitivement**. Donc :

- l'état de la ferme vit en Postgres, pas seulement dans la diffusion ;
- chaque geste passe par une fonction `security definer` qui **vérifie
  elle-même la plausibilité** : on ne récolte pas un plant semé il y a dix
  secondes, parce que c'est la base qui détient la date de semis ;
- la diffusion temps réel ne sert qu'à ce que les autres **voient** le geste
  tout de suite. Elle n'écrit rien.

C'est le point où ce jeu cesse d'être un mini-jeu. On peut le repousser, on ne
peut pas le sauter.

---

## 3. Modèle de données (esquisse)

Strictement additif, préfixe `jeu_`, dans la lignée de la migration existante.

| Table | Contenu |
| --- | --- |
| `jeu_fermes` | code de ferme, jour courant, saison, date de création |
| `jeu_fermiers` | rattachement `joueur_id` ↔ ferme, énergie, position de réveil |
| `jeu_parcelles` | ferme, x, y, état (friche / labourée / semée), culture, date de semis, arrosée le, gel posé |
| `jeu_inventaire` | ferme ou fermier, objet, quantité |
| `jeu_chambres` | ferme, chambre, résolue le, service débloqué |
| `jeu_coeurs` | ferme, cœur, affinité, dernier cadeau |

RLS inchangée dans l'esprit : **lecture publique, aucune écriture directe.**
Une fonction par geste : `jeu_labourer`, `jeu_semer`, `jeu_arroser`,
`jeu_recolter`, `jeu_dormir`, `jeu_resoudre_chambre`, `jeu_offrir`.

Et il faudra compléter la contrainte `check (jeu in (...))` sur `jeu_parties`
ainsi que le plafond dans `jeu_deposer_partie` — le classement du hub survit,
sous la forme d'un tableau d'honneur par ferme (chambres résolues, journées
tenues) plutôt qu'un score de manche.

---

## 4. Feuille de route

Sept jalons. Chacun se termine par quelque chose qui **se joue**, pas par une
couche invisible : c'est la seule façon de s'apercevoir tôt qu'une mécanique
n'est pas amusante.

| | Jalon | Contenu | Ce qui se joue à la fin |
| --- | --- | --- | --- |
| **J0** | Le socle | Scission `socle`/`partie`/`monde` ; écran 2D sur `plan()`, pack du hub, tuiles de ferme | On marche sur une ferme vide, dans le style du village |
| **J1** | La terre | Parcelles, houe, arrosoir, graines, croissance en jours, cycle jour/nuit, énergie | Une saison complète de navets, à plusieurs |
| **J2** | La persistance | Tables, fonctions SQL, code de ferme, reprise à la reconnexion | On ferme l'onglet, on revient, la ferme est là |
| **J3** | Le pistolet | Portails, conservation de l'élan, deux chambres qui réutilisent dalles et caisses | La première chambre branche l'irrigation |
| **J4** | Les gels | Propulsion, rebond, conversion — et leur double emploi agricole | Trois chambres de plus, une rigole qui coule |
| **J5** | La lumière | Ponts lumineux, tunnels d'excursion, lasers et redirecteurs | La serre, le convoyeur, la lampe d'hiver |
| **J6** | La compagnie | Cœurs, affinité, cadeaux, tourelles, cube-compagnon, voix de l'Intendance | Le jeu a une voix |
| **J7** | L'atelier | Bois, minerai, artisanat, améliorations d'outils | La boucle longue se referme |

**Sur la taille du chantier, sans enrobage :** J0 à J2 forment le minimum
jouable et représentent l'essentiel du risque technique. J3 à J7 sont du
contenu — long, mais prévisible. Ce n'est pas un week-end. Vouloir les huit
jalons d'un coup, c'est la meilleure façon de n'en finir aucun.

---

## 5. Ce qu'on ne fait pas

- **Pas de mariage, pas de mine à cent étages, pas de pêche.** Stardew a dix
  ans de contenu. On en prend la boucle, pas le catalogue.
- **Pas de portails en volume.** ÉNIGME se joue à plat, comme le hub : la
  gravité de *Portal* n'existe pas ici et la vitesse se gagne au sol.
- **Pas de 2,5D pour ce jeu.** CARNAGE garde son volume, ÉNIGME prend le
  pixel du hub. Deux grammaires visuelles, assumées, séparées par une porte.
- **Pas de sauvegarde locale.** Une ferme dans le `localStorage` d'un
  navigateur n'est pas partagée, donc n'est pas coopérative.
- **Pas de serveur de jeu.** Inchangé : Postgres arbitre, l'hôte simule.

## 6. Ce qu'il reste à trancher

1. **Le sort de l'ÉNIGME actuelle.** Les trois chambres à dalles existent et
   fonctionnent. Elles deviennent les trois premières chambres de la nouvelle
   ÉNIGME, ou elles disparaissent ?
2. **Le temps.** Une journée dure combien de minutes réelles ? En dessous de
   huit, on n'a pas le temps de descendre dans une chambre ; au-dessus de
   quinze, une session ne fait plus une saison.
3. **La ferme hors ligne.** Les plants poussent-ils quand personne n'est
   connecté ? Oui = on revient à quelque chose ; non = on ne perd rien à
   s'absenter. Les deux se défendent, mais c'est structurant pour le SQL.

---

## 7. État vérifié du socle (07/09/2026)

Le dépôt a été monté dans un conteneur avec Godot 4.5 et photographié sous
`xvfb` : `--headless --import` sans erreur, puis `--banc --lieu=village` et
`--banc --lieu=armurerie`. Le hub s'affiche, le héros s'anime, les maisons
s'ancrent aux pieds, le tri par profondeur tient, le portail de l'armurerie
palpite. **Le socle sur lequel ÉNIGME va se construire est sain.**

Deux remarques nées de cette séance :

1. **Le héros était nu — corrigé.** Les planches `heros_*.png` sont le CORPS
   DE BASE du pack Anokolisa, système en calques dont les vêtements sont des
   planches séparées, absentes du dépôt. `Pixels` les **habille au
   chargement** : seuls les pixels de peau sont teintés, par bandes
   horizontales calculées sur la hauteur de la silhouette, image par image.
   Les bandes suivent l'animation toutes seules — un vêtement dessiné à
   position fixe se décalerait à chaque pas. Les trois tons de peau donnent
   les trois tons du vêtement, donc le volume du dessin d'origine est
   conservé. Changer la tenue du héros, c'est changer cinq constantes.
2. **Trois défauts corrigés dans la foulée**, tous vus à l'image et aucun
   signalé par un test : le héros était **deux fois trop petit dans les
   intérieurs** (ils sont dessinés à une échelle plus grande que le village, et
   le pack livre déjà les habitants doublés — d'où `echelle` par lieu) ; les
   autres joueurs partageaient **une seule couleur passée au `modulate`**, qui
   déteignait sur la peau et le contour et transformait quatre personnes en
   quatre fantômes — c'est la **tunique** qui porte désormais la couleur du
   joueur ; et personne ne portait d'**ombre au sol**, sans quoi un sprite
   debout en vue de dessus flotte et deux personnages décalés d'une rangée
   paraissent à la même place.
3. **`commun/pixels.gd` a été reconstruit** à partir de ses appels dans
   `scenes/hub.gd` (voir l'avertissement en tête du fichier). Son interface
   est vérifiée à l'image ; ses commentaires d'origine sont perdus.
