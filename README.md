# Piks-l Multijoueur

Un hub que l'on parcourt à plusieurs, des portails, et derrière chaque portail
un jeu de 2 à 4 joueurs avec son score. Le tout tourne dans le navigateur :
Godot 4.5 exporté en WebAssembly, Supabase Realtime pour le réseau, Vercel pour
l'hébergement.

En ligne : **https://multijoueur.piks-l.com**

## Ce qu'il y a dedans

| | |
| --- | --- |
| **Hub** | Monde partagé. On s'y croise, on lit les meilleurs scores affichés au pied de chaque portail, on entre par `E`. |
| **CARNAGE** | Vue de dessus, conduite arcade. Écraser un monstre rapporte, mais seulement lancé : sous 210 px/s c'est le monstre qui gagne l'échange. Les enchaînements en moins de 2,5 s multiplient jusqu'à ×5. Manche de 2 minutes. |
| **ÉNIGME** | Coopératif, trois chambres. Une dalle ne reste enfoncée que si quelqu'un — ou une caisse — pèse dessus, et la sortie d'une chambre n'accepte l'équipe qu'au complet. 3 minutes. |

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

### Banc d'essai sans interface

```bash
godot --headless --path . --banc
```

Le client rejoint le hub et écrit une ligne par seconde. Deux instances
lancées côte à côte (avec deux `HOME` différents, pour deux identités) doivent
se voir : c'est le contrôle qui dit si la présence et la diffusion tiennent,
sans ouvrir deux navigateurs.

### Réexporter

```bash
./outils/exporter.sh
```

L'export atterrit dans `sortie/`, **qui est versionné** : c'est ce que Vercel
sert tel quel. Le sortir du dépôt obligerait à installer Godot dans le build
Vercel — 1,3 Go de modèles d'export à chaque déploiement.

L'export est en variante *sans fils d'exécution* (`thread_support=false`) :
avec les fils, le navigateur exige les en-têtes d'isolation `COOP`/`COEP`, qui
cassent le chargement de ressources tierces. Pour de la 2D, on n'y perd rien.

## Ce qui n'est pas fait

- Clavier et souris seulement : rien pour le tactile.
- Pas de son.
- Le classement affiché est un top brut ; pas de saison, pas de remise à zéro.
- Chaque manche consomme des messages Realtime (≈ 50 par seconde à quatre
  joueurs). C'est confortable à l'échelle d'une démonstration, à surveiller si
  le hub devait devenir populaire.
