# Piks-l Multijoueur

Un hub que l'on parcourt à plusieurs, des portails, et derrière chaque portail
un jeu de 2 à 4 joueurs avec son score. Le tout tourne dans le navigateur :
Godot 4.5 exporté en WebAssembly, Supabase Realtime pour le réseau, Vercel pour
l'hébergement.

**Un mur ne stoppe pas, il fait glisser.** Une collision ne coûte que la part
de vitesse mise dans la façade, et la voiture se réaligne dessus quand on la
frôle. Le braquage atteint son plein dès 165 px/s : avant, la voiture ne
tournait qu'à pleine vitesse, ce qui la rendait inconduisible dans des rues de
cent quarante pixels.

**La ville se déduit du code de la manche**, jamais du réseau : même code, même
plan, chez tout le monde et à tout instant. Diffuser le plan aurait coûté
plusieurs kilo-octets par partie et un cas de plus pour qui rejoint en retard.

**Pourquoi le hub est en 2D alors que les jeux sont en 3D.** Le décor du
village vient du pack *Pixel Crawler* d'Anokolisa, dessiné en vue de dessus —
murs et toits compris. Dressé en panneaux dans une scène en perspective, il se
tordrait : ces sprites n'ont pas de face. Le contraste assumé — un village
pixel, des jeux en volume — vaut mieux qu'un mélange qui trahirait les deux.
Le socle (`scenes/ecran.gd`) sait porter l'un ou l'autre : `plan()` pour la 2D,
`monde()` pour la 3D, jamais les deux dans le même écran.

Le village et ses intérieurs sont **préparés hors moteur** par
`outils/village.py`, qui lit le pack et écrit `modeles/village/*.png`. Règle
du script : on ne découpe jamais un dessin. Chaque image est un sprite entier
pris dans sa case de grille (un arbre = sa case de 48 × 96), une pièce entière
de la maquette de taverne (murs compris, ramenée à l'échelle native — la
maquette est livrée doublée), ou une planche d'animation recopiée telle quelle.
Les maisons sont assemblées (un toit entier, un pan de mur entier, une porte
entière), jamais rognées. Le même script dessine le **plan** du village sur
une grille de cases de 16 — sol, objets, portes, cases bloquées — et la zone
de marche de chaque pièce, et écrit le tout dans `modeles/village/plan.json` :
ce qu'on voit et ce qui arrête le joueur sortent de la même source, donc ne
divergent jamais (les calques de vérification sortent dans `/tmp/apercu`).
Une seule échelle partout : la case fait 16 pixels,
un personnage 30, et la caméra zoome d'un facteur entier ; les planches de
personnages sont remises au même gabarit (cases de 64, pieds sur le bord bas)
pour qu'un seul point d'ancrage serve à tous, sans agrandir personne.

**2,5D.** La simulation se fait sur un plan — tout l'état réseau tient en
`Vector2` — mais le rendu est en vraie 3D : caméra en perspective inclinée,
lumière directionnelle avec ombres portées, contre-jour froid pour que les
faces à l'ombre gardent leur volume, brouillard de profondeur. Les objets ont
une hauteur (voitures à châssis et cabine, monstres qui sautillent, dalles qui
s'enfoncent, portes qui descendent dans le sol) sans que la logique de jeu
n'ait jamais à connaître un axe vertical. Toute la fabrique est dans
`commun/decor.gd`, y compris le facteur d'échelle : les coordonnées de jeu sont
en pixels, gardées telles quelles en unités 3D elles ruineraient la précision
des ombres.

En ligne : **https://multijoueur.piks-l.com**

## Ce qu'il y a dedans

| | |
| --- | --- |
| **Hub** | Un village en **pixel art vu de dessus** : on s'y croise, et on ENTRE dans les maisons. La taverne, l'armurerie et l'atelier ont chacune leur intérieur, son classement au mur, son habitant qui explique le jeu, et — pour deux d'entre elles — le portail au fond de la pièce. |
| **CARNAGE** | Un GTA 2. Une ville de vingt-six par vingt tuiles, une rue tous les quatre pas, pas de mur : on est ramené vers le centre si on part dans la friche. On conduit, on **descend** (E), on court, on tire, on prend n'importe quelle voiture qui passe. Les passants rapportent, les gangs rapportent plus, les flics encore plus — et tout cela fait monter les **étoiles de recherche**. Trois gangs tiennent leurs rues et se souviennent ; trois **garages** effacent le casier et réparent la tôle ; trois **cabines** donnent des contrats chronométrés ; deux **arènes** cerclées de rouge sont les seuls endroits où les joueurs peuvent se blesser. Manche de 4 minutes. |
| **ÉNIGME** | Coopératif, trois chambres. Une dalle ne reste enfoncée que si quelqu'un — ou une caisse — pèse dessus, et la sortie d'une chambre n'accepte l'équipe qu'au complet. 3 minutes. |

### CARNAGE, dans le détail

**On descend de voiture.** C'est le geste qui sépare un jeu de voiture d'un
GTA : tant qu'on ne peut pas sortir, une ville n'est qu'un circuit. `E` ouvre
la portière dans les deux sens. À pied on est deux fois plus fragile, et c'est
voulu — sinon personne ne remonterait jamais au volant.

**Le vol de voiture est arbitré par l'hôte.** Le client DEMANDE, l'hôte
accorde. Sans cet aller-retour, deux joueurs arrivés à cent millisecondes
d'intervalle repartent chacun avec la même berline et chacun voit l'autre
rouler dans le vide. Une voiture conduite sort de la simulation de l'hôte et
n'est plus diffusée : c'est son conducteur qui l'annonce, douze fois par
seconde, comme n'importe quel joueur.

**Les étoiles.** Chaque crime chauffe une jauge : un passant vaut douze
points, une voiture quinze, un flic cinquante-deux, un coup de feu deux et
demi. Cinq paliers, cinq étoiles. La jauge redescend de neuf points par
seconde après quatre secondes et demie de calme. La réponse est graduée : une
patrouille par étoile, des flics à pied dès la deuxième, des barrages de rue
à la quatrième. Le **garage de peinture** remet tout à zéro — sans
échappatoire, cinq étoiles sont une condamnation et le joueur repose la
manette.

**Le respect.** Trois gangs, trois bandes de ville, une jauge par gang et par
joueur. Tuer chez l'un fait perdre vingt-deux points chez lui et en gagner
douze chez les deux autres. En dessous de −60 — soit trois morts, pas une — le
gang tire à vue ; au-dessus de +50 il laisse passer. Brûler une de leurs
voitures compte aussi, sinon on ferait le vide au lance-roquettes sans jamais
fâcher personne.

**Les contrats.** Une cabine par territoire. Le gang du quartier paie pour
nettoyer chez un rival, faire repeindre une voiture, ou tenir deux étoiles
jusqu'au bout. La prime se touche en argent ET en respect : c'est la seule
façon de remonter une jauge qu'on a fait plonger.

**Les arènes.** Deux esplanades qui enjambent une frontière de territoire —
contestées par construction. Le tir ami n'existe QUE là, et seulement si le
coup part de l'arène ET y arrive : un tireur posté dehors nettoierait
l'esplanade sans jamais y entrer. Partout ailleurs, les joueurs ne peuvent pas
se blesser et jouent la ville ensemble.

**Le plan, en haut à droite.** La ville fait vingt-six par vingt tuiles et la
caméra n'en montre que trois. Sans plan, on ne retrouve ni le garage quand on
a cinq étoiles, ni la cabine, ni l'arène — et un joueur qui ne sait pas où
aller tourne en rond puis s'en va.

Les deux portails restants sont éteints : ils marquent la place des jeux
suivants sans faire croire qu'ils existent.

## L'architecture, en une page

```
Navigateur (Godot 4.5 → WebAssembly)
   │
   ├─ WebSocket ──► Supabase Realtime      présence + diffusion, un canal par salle
   └─ HTTPS ──────► Supabase PostgREST     dépôt du score, lecture du classement
```

**Il n'y a pas de serveur de jeu.** Vercel ne sait pas héberger un processus qui
vit entre deux requêtes, et en monter un ailleurs pour deux mini-jeux aurait
ajouté une infrastructure à payer et à surveiller. À la place :

- **un hôte parmi les joueurs**, désigné par la plus petite clé de présence.
  Tout le monde calcule la même chose à partir des mêmes métadonnées, donc
  personne n'a besoin d'arbitrer, et la réélection après un départ est
  immédiate ;
- **l'hôte simule ce qui est partagé** — monstres, caisses, portes, score — et
  le diffuse ;
- **chaque client simule son propre personnage** : la commande répond à
  l'image, pas au réseau.

Ce que ça coûte, en toute honnêteté : un hôte qui modifierait son client
pourrait mentir sur le score de la manche. La fonction SQL de dépôt borne les
valeurs au vraisemblable (voir plus bas), ce qui limite les dégâts sans les
supprimer. Un serveur autoritaire est le seul vrai remède, et il se branchera
sans toucher aux jeux : il suffira de remplacer l'élection d'hôte.

### Ce qui vit où

```
jeux/carnage.gd          l'écran : commandes, réseau, rendu, interface
jeux/carnage/plan.gd     le plan de ville, déduit du code de la manche
jeux/carnage/vivant.gd   ce que l'HÔTE simule : foule, gangs, trafic, police, contrats
jeux/carnage/formes.gd   la fabrique de volumes (voitures, piétons, cabines, barrages)
ui/radar.gd              le plan de la ville en petit, dans un coin
```

⚠ Les collisions de la ville ne balayent PAS une liste de rectangles. Elle en
compte plus de trois cents ; avec quarante-six piétons, dix-huit voitures et
des projectiles, un balayage linéaire coûtait vingt mille tests par image et
l'hôte perdait ses trames. Une tuile se déduit d'une position par deux
divisions — on ne teste jamais plus des quatre tuiles qui touchent le cercle.

⚠ L'instantané de l'hôte ne porte que ce qu'un joueur peut VOIR (1 500 px).
Une ville entière diffusée, ce serait vingt-cinq kilo-octets par seconde pour
des passants que personne ne regarde.

⚠ Deux pièges de GDScript rencontrés ici : `trait` est un mot réservé et
l'erreur ne parle que d'un « nom de variable attendu » sans jamais nommer le
mot ; et `plan` est pris par le socle `Ecran` — le plan de ville s'appelle
`carte` dans l'écran de jeu.

### Le client temps réel

`autoload/reseau.gd` parle le protocole Phoenix de Supabase Realtime
directement sur `WebSocketPeer` — pas de SDK JavaScript via `JavaScriptBridge`.
Raison : un pont JS n'existerait que dans l'export web, et plus rien ne serait
testable sans déployer. Là, le même code tourne dans l'éditeur, en `--headless`
et dans le navigateur.

Quatre messages suffisent : `phx_join`, `heartbeat`, `broadcast`, `presence`.

- **présence** : rare et fiable → identité, table, composition de l'équipe ;
- **diffusion** : fréquente et jetable → positions (12 fois par seconde),
  états, événements.

`broadcast.self` est à `false` : se faire renvoyer ses propres messages
doublerait la facture pour un état déjà connu.

### Les salons

Pas de service d'appariement. Le salon d'un jeu est un canal ; chacun annonce
un numéro de table dans sa méta de présence, et la répartition se **lit** dans
la présence — tout le monde calcule le même découpage. On rejoint la première
table qui a de la place, ce qui regroupe les joueurs au lieu de les éparpiller.

## La base

Migration : `supabase/migrations/20260906_multijoueur.sql`. Strictement
additive, préfixe `jeu_`.

- `jeu_joueurs` — identifiant tiré au sort par le navigateur à la première
  visite. Pas de compte, pas de donnée personnelle.
- `jeu_parties` — une manche, déposée une seule fois, par l'hôte.
- `jeu_scores` — un score par joueur et par manche.

RLS : **lecture publique, aucune écriture directe.** Tout passe par
`jeu_deposer_partie(jeu, code, duree_s, resultats)`, en `security definer`, qui

- refuse un jeu inconnu, une durée hors bornes, une équipe hors 1–4 ;
- ramène chaque score au plafond de la manche (Carnage : 40 points par seconde
  de jeu ; Énigme : 2 000) ;
- refuse plus de 60 dépôts par heure et par joueur.

## Développer

```bash
cp config.exemple.cfg config.cfg      # puis renseigner les clés Supabase
godot --editor --path .               # ou : godot --path .
```

`config.cfg` est hors dépôt : aucun secret dans un commit.

### Bancs d'essai sans interface

Deux instances côte à côte, chacune avec son `HOME` (donc sa propre identité) :

```bash
# 1. la présence et la diffusion tiennent-elles ?
HOME=/tmp/a godot --headless --path . --banc &
HOME=/tmp/b godot --headless --path . --banc

# 2. une manche complète, du salon au dépôt du score
HOME=/tmp/a godot --headless --path . --banc-jeu=carnage --manche=30 &
HOME=/tmp/b godot --headless --path . --banc-jeu=carnage --manche=30
```

Le second traverse TOUTE la chaîne : appariement dans le salon, élection de
l'hôte, décompte, simulation, diffusion des scores, dépôt en base. Il joue au
pilote automatique — dans Carnage, la voiture vise le monstre le plus proche,
sans quoi une manche d'essai finirait à zéro et ne vérifierait ni la
collision, ni le score, ni le dépôt.

C'est ce que permet `commun/commandes.gd` : les touches ne sont jamais lues
ailleurs. Sans ce passage obligé, la seule façon de vérifier une partie de
bout en bout serait de la jouer à la main — et personne ne le fait avant
chaque livraison.

### Photographier un jeu sans y jouer

```bash
xvfb-run -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --resolution 1280x720 \
  --banc-jeu=carnage --manche=30 --photo=/tmp/vues
```

Une image toutes les cinq secondes dans `/tmp/vues`. C'est ce contrôle qui a
montré ce qu'aucun test ne disait : les monstres apparaissaient aux bords de
l'arène et mettaient douze cents pixels à devenir menaçants — à l'écran, on
n'en croisait aucun.

`--manche` raccourcit la manche : attendre deux minutes par vérification,
personne ne le fait deux fois.

### Réexporter

```bash
./outils/exporter.sh
```

L'export atterrit dans `sortie/`, **qui est versionné** : c'est ce que Vercel
sert tel quel. Le sortir du dépôt obligerait à installer Godot dans le build
Vercel — 1,3 Go de modèles d'export à chaque déploiement.

`index.wasm` et `index.pck` sont servis en `must-revalidate`, pas en
`immutable` : leur nom ne change JAMAIS d'une version à l'autre. Mis en cache
immuable, un navigateur qui a déjà vu le jeu ne verrait plus jamais une mise à
jour — on l'a constaté en déployant une correction qui n'apparaissait pas.
La revalidation coûte un aller-retour et répond 304.

L'export est en variante *sans fils d'exécution* (`thread_support=false`) :
avec les fils, le navigateur exige les en-têtes d'isolation `COOP`/`COEP`, qui
cassent le chargement de ressources tierces. Pour de la 2D, on n'y perd rien.

## Ce qui n'est pas fait

- Rendu en mode compatibilité (exigé par le web) : ombres directionnelles
  seulement, pas d'occlusion ambiante ni de reflets.
- Sur téléphone, un manche virtuel et un bouton apparaissent — et n'apparaissent
  que là : un pavé tactile affiché à quelqu'un qui a un clavier passe pour un
  défaut. `--tactile` les force, pour pouvoir les vérifier au banc.
- Deux ressources binaires au dépôt, et pas une de plus : `modeles/volvo-242.glb`
  (décimée de 44 000 à 5 900 triangles depuis un STL de modélisme) et
  `modeles/ville/` — le [kit de ville de Kenney](https://github.com/KenneyNL/Starter-Kit-City-Builder),
  CC0, quinze tuiles pour 412 Ko — **avec `modeles/ville/Textures/colormap.png`** :
  les glTF de Kenney référencent leur atlas en fichier EXTERNE, et copier les
  seuls maillages donne une ville entièrement blanche, sans le moindre message
  d'erreur. Le reste du décor est fabriqué en code.
  La ville est posée en **nappes** (`MultiMeshInstance3D`) : quatre cents
  tuiles dessinées une par une, c'est quatre cents appels de dessin par image,
  ce qui ne passe pas dans un navigateur en mode compatibilité. Regroupées par
  modèle, il en reste une quinzaine.
- Le son est entièrement synthétisé au démarrage (`autoload/sons.gd`) : aucun
  fichier binaire au dépôt. **M** le coupe, et le choix survit à la session.
- Le classement affiché est un top brut ; pas de saison, pas de remise à zéro.
- Chaque manche consomme des messages Realtime (≈ 50 par seconde à quatre
  joueurs). C'est confortable à l'échelle d'une démonstration, à surveiller si
  le hub devait devenir populaire.
