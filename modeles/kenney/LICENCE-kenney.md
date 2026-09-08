# Kits Kenney (CC0)

Modèles de Kenney (kenney.nl), domaine public CC0 1.0 : on peut les utiliser,
modifier et redistribuer, y compris commercialement, sans attribution — elle
reste appréciée, et on la donne ici.

- `voitures/` — Car Kit (25 véhicules ; on en garde dix-sept + trois roues)
- `urbain/` — City Kit: Roads (lampadaires, feux, panneaux, bennes, cônes)
- `batiments/` — City Kit: Commercial (immeubles et gratte-ciels)
- `pavillons/` — City Kit: Suburban (maisons de banlieue)
- `industriel/` — City Kit: Industrial (hangars, cuves, entrepôts)
- `nature/` — Nature Kit (arbres, buissons, rochers, herbes)
- `personnages/` — Animated Characters (le corps `characterMedium.fbx` et onze
  peaux : passants, skateurs, truand, cyborg, survivants, zombies)

⚠ CHAQUE kit a SON atlas `Textures/colormap.png`, et les glTF le référencent en
fichier EXTERNE : copier les seuls maillages donne des modèles entièrement
blancs, sans le moindre message d'erreur. Les atlas de deux kits ne sont PAS
interchangeables (un bâtiment de banlieue peint avec l'atlas commercial sort
avec les mauvaises couleurs).

⚠ Le personnage, lui, ne se peint PAS avec un atlas mais avec une TEXTURE
ENTIÈRE par tenue (`personnages/skins/*.png`), et le `.fbx` ne la référence
pas : c'est le jeu qui la pose (`FormesCarnage.matiere_peau`). Le kit livre
aussi des animations (`idle`, `run`, `jump`) qu'on n'importe pas : quatre os
pivotés par code coûtent moins qu'un lecteur d'animation par piéton, et une
ville en compte cinquante.
