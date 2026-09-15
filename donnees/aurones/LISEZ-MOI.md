# Archipel des Aurones – Données pour Godot 4.5

## Fichiers fournis

| Fichier | Description |
|---------|-------------|
| `archipel_complet.json` | Toutes les îles (3 grandes + 7 petites), stations, ponts, lignes train/métro/tram |
| `road_graph.json` | Graphe de routes (nodes + edges) prêt pour AStar2D |
| `transit_paths.json` | Listes de points pour créer les Path2D de chaque ligne |
| `ArchipelLoader.gd` | Script de chargement principal |
| `NavigationSetup.gd` | Aide pour NavigationRegion2D + construction AStar |

## Installation rapide

1. Crée un dossier `res://data/` dans ton projet Godot.
2. Copie les 3 fichiers JSON dedans.
3. Copie les deux scripts `.gd` où tu veux (ex: `res://scripts/`).
4. Dans ta scène principale, ajoute un Node avec le script `ArchipelLoader.gd`.

## Échelle

- Toutes les positions sont en **kilomètres**.
- Multiplie par **1000** pour obtenir des mètres dans Godot.
- La carte fait **20 km × 20 km**.

## Structure de scène recommandée

```
MapRoot (Node2D)
├── ArchipelLoader (Node)          ← script ArchipelLoader.gd
├── Islands (Node2D)
├── Roads (Node2D)
├── Transit (Node2D)
│   ├── TrainPaths
│   ├── MetroPaths
│   └── TramPaths
├── Stations (Node2D)
├── NavigationCars (NavigationRegion2D)
├── NavigationBuses (NavigationRegion2D)
├── NavigationTrams (NavigationRegion2D)
└── NavigationPedestrians (NavigationRegion2D)
```

## Exemple d’utilisation

```gdscript
# Dans un script qui a accès au loader
@onready var loader = $ArchipelLoader

func _ready():
    await loader.data_loaded   # si tu utilises le signal
    
    # Créer tous les Path2D train
    loader.create_all_train_paths($Transit/TrainPaths)
    
    # Construire l’AStar pour les voitures / bus
    var astar = loader.build_astar_from_road_graph()
    
    # Position d’une gare
    var pos = loader.get_station_position("gare_centrale")
```

## Lignes disponibles

**Train** : T1, T2, T3, T4  
**Métro** : M1, M2, M3, MN1, MS1  
**Tram** : TR1, TR2, TR3, TRN1, TRS1, TRS2

## Ponts inclus

- Centrale ↔ Nord (routier + ferroviaire)
- Centrale ↔ Sud-Est (mixte + tunnel rail)
- Centrale ↔ Pins
- Centrale ↔ Îlot du Large
- Centrale ↔ Brumes
- Nord ↔ Baie
- Sud-Est ↔ Côte
- Ouest ↔ Brumes

## Prochaines améliorations possibles

- Génération automatique des polygones de navigation à partir des edges (offset)
- Ajout des lignes de bus détaillées
- Export des colliders de ponts
- Version TileMap / Terrain3D ready

Bon développement !
