@echo off
REM =====================================================================
REM  UN SEUL JEU : CARNAGE.
REM
REM  Ce script retire du depot le hub a portails, les deux autres jeux
REM  (ENIGME / la ferme, BOUSCULADE), l'ecran de resultats et les modules
REM  qui n'existaient que pour eux. Le code qui reste a deja ete recable :
REM  loading -> salon -> Carnage, plus le pseudo, les options et l'editeur.
REM
REM  Il passe par `git rm` : rien n'est perdu, tout se retrouve dans
REM  l'historique, et un `git checkout <commit> -- <fichier>` ramene ce
REM  qu'on regretterait.
REM
REM  A lancer depuis la racine du depot (client-multijoueur).
REM =====================================================================

echo.
echo == Les ecrans et les jeux retires
git rm -q scenes/menu.gd scenes/menu.gd.uid
git rm -q scenes/ferme.gd scenes/ferme.gd.uid
git rm -q scenes/resultats.gd scenes/resultats.gd.uid
git rm -q jeux/enigme.gd jeux/enigme.gd.uid
git rm -q jeux/bousculade.gd jeux/bousculade.gd.uid

echo == Les modules qui n'avaient plus de client
REM  terrain : la ferme. pixels : les heros 2D. pantin : BOUSCULADE.
REM  voxels  : plus aucun appelant depuis que la ville est en Kenney.
git rm -q commun/terrain.gd commun/terrain.gd.uid
git rm -q commun/pixels.gd commun/pixels.gd.uid
git rm -q commun/pantin.gd commun/pantin.gd.uid
git rm -q commun/voxels.gd commun/voxels.gd.uid

echo == Les bancs et les documents de conception devenus sans objet
git rm -q outils/ferme.gd outils/ferme.gd.uid outils/ferme.tscn outils/ferme.sh
git rm -q CONCEPTION-ENIGME.md

echo == Les modeles qui n'etaient qu'a eux
git rm -q -r modeles/ferme
git rm -q -r modeles/village
git rm -q -r modeles/creatures

echo.
echo == Reste a faire, a la main si vous le voulez :
echo    - `godot --headless --path . --import` pour nettoyer le cache .godot
echo    - verifier que tout compile : `godot --headless --path . res://outils/compiler.tscn`
echo.
echo Termine. Rien n'est perdu : `git status` montre ce qui part.
