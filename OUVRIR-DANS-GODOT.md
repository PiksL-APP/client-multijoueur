# Ouvrir Piks Theft Auto dans Godot

Le projet vit dans `F:\Claude\Projects\PXL\client-multijoueur`. Tout y est déjà :
le code, les modèles, les sons. Il n'y a rien à compiler, rien à installer en
plus — il faut le BON Godot, un fichier de clés, et trois minutes d'import.

---

## 1. La bonne version : Godot 4.5, pas la dernière

Le projet est marqué `4.5` et rendu en **GL Compatibility** (c'est ce qui lui
permet de tourner dans un navigateur). Godot 4.6 est sorti depuis : si vous
l'ouvrez avec, l'éditeur proposera de **convertir** le projet, et une
conversion qu'on accepte par réflexe est un dépôt qu'on ne peut plus pousser
tel quel — `EXPORTER.bat` cherche d'ailleurs un Godot 4.5.

Prenez donc **4.5.1 stable**, *Windows Desktop*, version **standard** (pas la
.NET — il n'y a pas une ligne de C# ici) :

> https://godotengine.org/download/archive/4.5.1-stable/

C'est un `.exe` seul, sans installateur : posez-le où vous voulez. Le plus
pratique est `F:\Claude\Projects\PXL\client-multijoueur\outils\godot\godot.exe` —
c'est le premier endroit où `EXPORTER.bat` va le chercher, et il le trouvera
sans qu'on lui dise.

Si vous avez déjà installé 4.6 : gardez-le, les deux cohabitent très bien.
Ouvrez simplement le projet avec le 4.5, et si l'éditeur parle de convertir,
répondez **non** et vérifiez que vous avez lancé le bon exécutable.

---

## 2. `config.cfg` : les clés, ou pas de clés

Au démarrage, `autoload/config.gd` cherche `config.cfg` à la racine. S'il
manque, le jeu s'arrête sur *« config.cfg absent : copiez config.exemple.cfg
et renseignez les clés »*.

Sur votre poste **il est déjà là** — c'est lui qui porte les clés Supabase, et
il est hors dépôt (`.gitignore`) : aucun secret ne part dans un commit. Vous
n'avez donc rien à faire. S'il venait à disparaître :

```bash
cp config.exemple.cfg config.cfg
```

⚠ **Et là, attention au piège.** Le fichier d'exemple contient des valeurs
FACTICES (`https://VOTRE-PROJET.supabase.co`). Le jeu les prend pour de vraies
clés, essaie de joindre un serveur qui n'existe pas, et le salon reste bloqué
sur *« En attente de l'hôte »* — le bouton « Lancer la manche » ne se
déverrouille jamais. Pour jouer **seul, sans serveur**, laissez les deux
valeurs VIDES :

```ini
[supabase]
url=""
cle_publique=""

[jeu]
version="0.1.0"
```

Vides, `Reseau` bascule tout seul en mode solo : on se rejoint soi-même, la
manche se lance, seul le classement en ligne manque. Renseignées pour de vrai,
on joue à plusieurs.

---

## 3. Importer le projet

1. Lancez `godot.exe` : la **liste des projets** s'ouvre.
2. Bouton **Importer**, puis allez chercher le fichier
   `F:\Claude\Projects\PXL\client-multijoueur\project.godot`.
   (Vous pouvez aussi simplement faire glisser `project.godot` sur la fenêtre.)
3. **Importer et éditer**.

Le premier import prend quelques minutes : il y a 40 Mo de modèles glTF, des
polices et des sons à transformer en ressources du moteur. La barre de
progression est en bas à droite — **laissez-la finir** avant de toucher à
quoi que ce soit. Godot dépose le résultat dans `.godot/`, qui est hors dépôt :
c'est du cache, il se refabrique.

Les fois suivantes, le projet apparaît directement dans la liste et s'ouvre en
deux secondes.

---

## 4. Lancer le jeu : F5

**F5** lance le projet (le bouton ▶ en haut à droite fait la même chose).
Le parcours est celui d'un joueur, pas celui d'un développeur :

1. Vous arrivez dans le **salon**. Boutons *Pseudo* et *Options* en bas si
   vous voulez vous nommer ou revoir les touches.
2. **« Lancer la manche (1 joueur) »** — en solo, vous êtes l'hôte, le bouton
   est actif tout de suite.
3. Décompte, et vous êtes en ville.

Les touches, une fois dedans :

| | |
|---|---|
| `Z S` / `Q D` | avancer, freiner · tourner |
| `ESPACE` | tirer |
| `E` | monter en voiture, en descendre |
| `F` | l'affaire du lieu : acheter, déposer, se soigner, entrer |
| `G` | manger ou boire |
| `TAB` | la carte (molette pour zoomer, clic pour poser un GPS) |
| `V` | vue subjective |
| `H` | klaxon — à pied, le détonateur |
| `ÉCHAP` | la pause, et **LES TOUCHES** : la fiche complète |
| `M` | couper le son |

Pour sortir : `ÉCHAP` → *QUITTER LA VILLE* (c'est la seule façon de terminer
proprement une manche, avec son classement), ou **F8** pour tuer la fenêtre.

---

## 5. Quelle ville allez-vous voir ?

Depuis aujourd'hui, `cartes/temoin-centre.json` existe — c'est le **centre
témoin de la ville v2**, le chantier en cours. Tant que ce fichier est là,
c'est LUI qui se charge, pas Pikstown.

Pour rejouer Pikstown, il suffit de déplacer le fichier ailleurs (ou de le
renommer en `temoin-centre.json.off`) : le jeu ne le trouve plus et reprend la
ville dessinée. Rien d'autre à changer.

---

## 6. Voir l'interface mobile sans téléphone

Le pavé tactile ne s'affiche que sur un écran tactile. Deux options pour le
juger depuis le PC :

**Depuis l'éditeur** — *Projet → Paramètres du projet*, cochez **Avancé** en
haut à droite, tapez `main run args` dans le filtre, et posez dans le champ :

```
--tactile --telephone
```

`--tactile` force le manche et les boutons, `--telephone` fait passer la scène
en 960×540 (tout grandit d'un tiers, comme sur un six pouces). Videz le champ
pour revenir au jeu au clavier.

Deux autres drapeaux utiles pour regarder le pavé en détail :
`--banc-volet=menu` (l'éventail du menu ≡ ouvert) et `--banc-fiche` (la fiche
des commandes tactiles, ouverte toute seule au bout de huit secondes).

**Depuis une console**, sans toucher aux réglages :

```bash
godot --path . --tactile --telephone
```

---

## 7. Les outils

Chaque atelier est une scène à part. Ouvrez-la dans l'éditeur et faites **F6**
(« lancer la scène courante ») :

- `outils/apercu.tscn`, `outils/vitrine.tscn` — regarder un modèle, une voiture
- `outils/chez_soi.tscn` — les intérieurs de planque
- `outils/carte.tscn` — la carte de la ville
- `outils/pavage.tscn`, `outils/pont.tscn`, `outils/bord.tscn` — la route, les
  ponts, les bords de mer

L'**éditeur de carte** s'ouvre par la ligne de commande :

```bash
godot --path . --ecran=editeur
```

Et les bancs d'essai tournent **sans fenêtre** — c'est ce qui permet de
vérifier une manche entière sans la jouer :

```bash
godot --headless --path . --solo --banc-jeu=carnage --manche=30
```

---

## 8. Mettre en ligne

Double-cliquez **`EXPORTER.bat`**. Il trouve Godot, exporte le jeu web dans
`sortie/`, et c'est ce dossier que Vercel sert.

La première fois, l'export réclamera les **modèles d'export** (les *export
templates*) : dans l'éditeur, *Éditeur → Gérer les modèles d'exportation… →
Télécharger et installer*. C'est un gros téléchargement, une fois pour toutes,
et il doit correspondre à la version de l'éditeur — 4.5.1 avec 4.5.1.

⚠ Un `git push` n'exporte rien. Pousser sans avoir lancé `EXPORTER.bat` laisse
la page en ligne exactement comme avant, sans que rien ne le signale.

---

## 9. Ce qui peut vous surprendre

**Des erreurs dans le panneau du bas, au premier import.** Godot charge les
scripts avant d'avoir fini d'indexer les classes. *Projet → Recharger le
projet courant* et elles disparaissent. Si elles persistent sur une classe
précise (`Cannot find member … in base …`), c'est le cache de classes :
`godot --headless --path . --import` une fois le règle.

**`outils/atelier.gd` est cassé** — il appelle `VilleVivante.BOMBE_DELAI` qui
n'existe pas. C'est un script d'outil, il ne gêne ni le jeu ni l'export ; il
apparaîtra simplement en rouge dans la liste des erreurs. À réparer quand son
auteur y repassera.

**Ne changez pas le moteur de rendu.** Godot propose volontiers de passer en
*Forward+*, qui est plus joli : le web ne le supporte pas, et tout le jeu est
réglé pour **GL Compatibility** (ombres, brouillard, shaders du sol).

**Ne commitez jamais** `config.cfg` (les clés), `.godot/` (le cache) ni
`Claude outputs/` — ils sont déjà dans `.gitignore`, c'est simplement bon à
savoir avant un `git add -A`.

---

## Où vit quoi

| Dossier | Ce qu'on y trouve |
|---|---|
| `scenes/` | la racine, le salon, l'éditeur de carte, les options |
| `jeux/carnage.gd` | **le jeu** : la manche, le joueur, la conduite, les affaires |
| `jeux/carnage/` | la ville : plan, formes, voxels, trafic, intérieurs, météo, GPS |
| `commun/` | ce qui sert à plusieurs écrans : plans, décor, personnages |
| `ui/` | tout ce qui se dessine par-dessus : HUD, radar, carte, menus, pavé tactile |
| `autoload/` | les singletons : réseau, sons, réglages, tactile, config |
| `outils/` | les ateliers et les bancs d'essai |
| `modeles/` | les kits Kenney (CC0), un dossier par kit avec sa licence |

Le `README.md` raconte le reste — la ville, les gangs, la recherche, le train,
la météo. Il fait soixante pages, mais chaque section se lit seule.
