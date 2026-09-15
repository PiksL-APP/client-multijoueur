# `modeles/pxl/` — les modèles faits pour ce jeu

Les GLB commandés à Claude Design se déposent ICI, et nulle part ailleurs.

## Pourquoi pas `modeles/piksl/`

C'est une question d'échelle, et elle vaut un facteur vingt.

| dossier | ce qu'il contient | `KitVille2.echelle()` |
|---|---|---|
| `modeles/piksl/` | les modèles du client, déjà en unités de JEU | **1,0** |
| `modeles/pxl/` | les modèles neufs, taillés comme un kit Kenney | **20,0** (une case) |

Un modèle taillé en unités Kenney (1 unité = 1 case = 20 m) et rangé dans
`piksl/` sortirait vingt fois trop petit. L'inverse aussi.

## Pourquoi pas `modeles/kenney/…`

Parce qu'on doit pouvoir remplacer un kit Kenney d'un bloc — c'est déjà arrivé.
Ce qui est à nous reste séparé de ce qui est téléchargé.

## Les règles, en trois lignes

1. **1 unité = 20 mètres.** Une maison de 7 m se modélise à 0,35 unité.
2. **Y en haut, −Z vers l'avant** (la façade, la porte, la calandre).
3. **Pivot au centre de l'emprise au sol, base à y = 0** — sauf pièce de sol
   (voir `claude/sol-et-tuiles.md` : celles-là se dessinent SOUS zéro).

Le reste — atlas, vitres qui s'allument, budget de polygones — est dans
`claude/modeles-manquants.md`.
