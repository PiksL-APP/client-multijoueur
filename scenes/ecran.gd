class_name Ecran
extends Node
## Un écran du jeu. La racine n'en garde qu'un à la fois.
##
## `Node` et non `Node2D` : les écrans montent une scène 3D, et un Node3D sous
## un Node2D est une construction que le moteur ne garantit pas. L'interface,
## elle, vit dans une CanvasLayer — donc hors de portée de la caméra.
##
## La navigation passe par un signal plutôt qu'un appel direct : un écran n'a
## pas à connaître la racine, ni les autres écrans.

signal demande_ecran(nom: String, donnees: Dictionary)

var donnees: Dictionary = {}

var _couche: CanvasLayer = null
var _monde: Node3D = null

## Les contrôles vont dans une couche, jamais en enfant direct : un Control
## dont le parent n'est pas un Control n'a pas de rectangle de référence, ses
## ancres ne s'appliquent pas, et il reste collé en haut à gauche à sa taille
## minimale. Le défaut s'est vu à l'écran, pas au build.
func interface() -> CanvasLayer:
	if _couche == null:
		_couche = CanvasLayer.new()
		add_child(_couche)
	return _couche

func monde() -> Node3D:
	if _monde == null:
		_monde = Node3D.new()
		add_child(_monde)
	return _monde

## Ambiance commune : fond, brouillard, soleil qui porte les ombres, et une
## seconde source froide pour que les faces à l'ombre gardent leur volume.
## `jour` module l'heure : à 1 on est en plein soleil, à 0,5 au crépuscule.
## Le kit de ville est d'un blanc éclatant — laissé en plein jour, il écrase
## la palette sombre de la maison et rend les voitures illisibles.
func poser_ambiance(brouillard: bool = true, jour: float = 1.0) -> void:
	monde().add_child(Decor.ambiance(Palette.FOND, brouillard, 0.34 * jour))
	monde().add_child(Decor.lumiere(1.12 * jour))
	monde().add_child(Decor.contre_jour())

func demarrer() -> void:
	pass
