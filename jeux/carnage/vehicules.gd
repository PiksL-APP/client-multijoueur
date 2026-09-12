class_name VehiculesCarnage
extends RefCounted
## LA FICHE TECHNIQUE DE CHAQUE VÉHICULE. Une seule table pour le joueur (la
## conduite dans `carnage.gd`) et pour la ville (le trafic et les points de
## tôle des voitures de l'hôte, dans `vivant.gd` et `trafic.gd`) : avant, le
## joueur avait trois chiffres par carrosserie et le trafic n'en avait aucun —
## un bus et une voiture de course roulaient à la même vitesse, tournaient au
## même endroit et encaissaient pareil.
##
## Les colonnes, toutes relatives à la berline (1,0) sauf la tôle :
##   v   vitesse de pointe          a   accélération
##   f   freinage                   b   braquage (rayon court quand c'est haut)
##   g   adhérence — bas, ça glisse et ça dérive ; haut, ça colle à la route
##   m   masse — ce qu'on pèse dans un choc et ce qu'on pousse
##   pv  points de tôle : la jauge, pleine, de CE véhicule
##   vt  allure en circulation, pour la ville : un camion ne roule pas comme
##       un taxi, et ça se voit depuis le trottoir
##   t   gardé pour ce qui le lisait : un facteur d'armure, désormais à 1 — la
##       durée de vie d'une carrosserie est portée par `pv`
##
## ⚠ L'indice est celui du réseau (`FormesCarnage.MODELES_VOITURES`) ; -1 est
## la voiture de départ.
const FICHES := {
	-1: {"nom": "la Volvo", "v": 1.0, "a": 1.0, "f": 1.0, "b": 1.0, "g": 1.0, "m": 1.0, "pv": 100.0, "vt": 1.0, "t": 1.0},
	0: {"nom": "berline", "v": 1.0, "a": 1.0, "f": 1.0, "b": 1.0, "g": 1.0, "m": 1.0, "pv": 100.0, "vt": 1.0, "t": 1.0},
	1: {"nom": "berline sport", "v": 1.22, "a": 1.25, "f": 1.05, "b": 1.1, "g": 0.88, "m": 0.95, "pv": 85.0, "vt": 1.15, "t": 1.0},
	2: {"nom": "compacte", "v": 1.08, "a": 1.2, "f": 1.0, "b": 1.3, "g": 1.1, "m": 0.8, "pv": 75.0, "vt": 1.0, "t": 1.0},
	3: {"nom": "4x4", "v": 0.95, "a": 0.9, "f": 0.95, "b": 0.85, "g": 1.15, "m": 1.35, "pv": 140.0, "vt": 0.95, "t": 1.0},
	4: {"nom": "4x4 de luxe", "v": 1.05, "a": 1.0, "f": 1.0, "b": 0.85, "g": 1.1, "m": 1.4, "pv": 135.0, "vt": 1.0, "t": 1.0},
	5: {"nom": "taxi", "v": 1.02, "a": 1.1, "f": 1.05, "b": 1.1, "g": 1.05, "m": 1.0, "pv": 95.0, "vt": 1.08, "t": 1.0},
	6: {"nom": "fourgon", "v": 0.88, "a": 0.8, "f": 0.9, "b": 0.75, "g": 1.0, "m": 1.5, "pv": 150.0, "vt": 0.9, "t": 1.0},
	7: {"nom": "camion de livraison", "v": 0.8, "a": 0.65, "f": 0.85, "b": 0.6, "g": 1.05, "m": 2.0, "pv": 190.0, "vt": 0.85, "t": 1.0},
	8: {"nom": "camion", "v": 0.76, "a": 0.6, "f": 0.8, "b": 0.55, "g": 1.05, "m": 2.4, "pv": 220.0, "vt": 0.8, "t": 1.0},
	9: {"nom": "police", "v": 1.15, "a": 1.2, "f": 1.15, "b": 1.15, "g": 1.1, "m": 1.05, "pv": 120.0, "vt": 1.1, "t": 1.0},
	10: {"nom": "coupé", "v": 1.25, "a": 1.3, "f": 1.05, "b": 1.15, "g": 0.85, "m": 0.9, "pv": 80.0, "vt": 1.15, "t": 1.0},
	11: {"nom": "break", "v": 0.98, "a": 0.95, "f": 1.0, "b": 0.95, "g": 1.05, "m": 1.1, "pv": 110.0, "vt": 1.0, "t": 1.0},
	12: {"nom": "pick-up", "v": 0.95, "a": 0.9, "f": 0.95, "b": 0.8, "g": 1.0, "m": 1.3, "pv": 130.0, "vt": 0.95, "t": 1.0},
	13: {"nom": "bus", "v": 0.7, "a": 0.5, "f": 0.75, "b": 0.45, "g": 1.1, "m": 3.2, "pv": 260.0, "vt": 0.7, "t": 1.0},
	14: {"nom": "limousine", "v": 0.98, "a": 0.8, "f": 0.95, "b": 0.6, "g": 1.0, "m": 1.6, "pv": 140.0, "vt": 0.9, "t": 1.0},
	15: {"nom": "ambulance", "v": 1.02, "a": 0.95, "f": 1.05, "b": 0.8, "g": 1.05, "m": 1.5, "pv": 150.0, "vt": 1.05, "t": 1.0},
	# Les deux-roues : ils partent et tournent comme rien, ne dérivent presque
	# pas, et il n'y a rien autour de soi — un choc, et c'est fini.
	16: {"nom": "moto", "v": 1.24, "a": 1.45, "f": 1.1, "b": 1.6, "g": 1.3, "m": 0.35, "pv": 45.0, "vt": 1.1, "t": 1.0},
	17: {"nom": "moto de course", "v": 1.38, "a": 1.6, "f": 1.1, "b": 1.5, "g": 1.2, "m": 0.35, "pv": 40.0, "vt": 1.2, "t": 1.0},
	18: {"nom": "camion de pompiers", "v": 0.85, "a": 0.7, "f": 0.85, "b": 0.55, "g": 1.05, "m": 2.6, "pv": 260.0, "vt": 0.85, "t": 1.0},
	# Les deux BOUTS de l'échelle, et c'est fait exprès : trouver l'une ou
	# l'autre doit changer la minute qui suit.
	19: {"nom": "voiture de course", "v": 1.5, "a": 1.6, "f": 1.15, "b": 1.2, "g": 0.8, "m": 0.85, "pv": 60.0, "vt": 1.25, "t": 1.0},
	20: {"nom": "tracteur", "v": 0.5, "a": 0.5, "f": 1.2, "b": 0.9, "g": 1.4, "m": 2.2, "pv": 240.0, "vt": 0.55, "t": 1.0},
	21: {"nom": "benne à ordures", "v": 0.68, "a": 0.55, "f": 0.8, "b": 0.5, "g": 1.05, "m": 2.8, "pv": 230.0, "vt": 0.7, "t": 1.0},
	22: {"nom": "plateau de livraison", "v": 0.85, "a": 0.72, "f": 0.85, "b": 0.6, "g": 1.05, "m": 1.9, "pv": 180.0, "vt": 0.85, "t": 1.0},
	# LA FLOTTE. Un bateau n'a pas de freins (sa décélération, c'est le
	# frottement de l'eau) et il glisse : l'adhérence est basse, c'est ce qui
	# fait qu'une vedette dérape dans son virage.
	23: {"nom": "chaloupe", "v": 0.55, "a": 0.5, "f": 1.0, "b": 0.9, "g": 0.6, "m": 0.8, "pv": 70.0, "vt": 0.6, "t": 1.0},
	24: {"nom": "vedette", "v": 1.05, "a": 0.9, "f": 1.0, "b": 1.0, "g": 0.5, "m": 1.0, "pv": 85.0, "vt": 1.0, "t": 1.0},
	25: {"nom": "vedette rapide", "v": 1.18, "a": 1.0, "f": 1.0, "b": 1.1, "g": 0.45, "m": 0.9, "pv": 75.0, "vt": 1.1, "t": 1.0},
	26: {"nom": "barque de pêche", "v": 0.7, "a": 0.6, "f": 1.0, "b": 0.7, "g": 0.6, "m": 1.3, "pv": 120.0, "vt": 0.7, "t": 1.0},
	27: {"nom": "remorqueur", "v": 0.62, "a": 0.45, "f": 1.0, "b": 0.4, "g": 0.7, "m": 3.0, "pv": 280.0, "vt": 0.6, "t": 1.0},
}

## La fiche d'un modèle ; un indice inconnu roule en berline.
static func fiche(modele: int) -> Dictionary:
	return FICHES.get(modele, FICHES[0])

## Un chiffre de la fiche, avec la berline pour défaut.
static func valeur(modele: int, cle: String, defaut: float = 1.0) -> float:
	return float(fiche(modele).get(cle, defaut))

## La jauge pleine de ce véhicule.
static func pv(modele: int) -> float:
	return valeur(modele, "pv", 100.0)

## Longueur du véhicule en pixels de jeu : le gabarit en voxels, à l'échelle
## des voitures (un voxel = 0,25 unité, une unité = dix pixels). C'est ce qui
## règle la distance de sécurité d'un bus derrière une compacte.
static func longueur(modele: int) -> float:
	var g: Dictionary = VoxelsCarnage.GABARITS.get(modele, VoxelsCarnage.GABARITS[0])
	return float(g["l"]) * VoxelsCarnage.VOXEL_VOITURE / Decor.ECHELLE

## Ce qu'un choc entre deux carrosseries fait à chacune : le rapport des masses,
## borné — un bus pousse une compacte, mais une compacte ne traverse pas un bus.
static func part_du_choc(modele_recu: int, modele_donne: int) -> float:
	var m1 := valeur(modele_recu, "m")
	var m2 := valeur(modele_donne, "m")
	return clampf(m2 / maxf(m1, 0.1), 0.35, 2.8)
