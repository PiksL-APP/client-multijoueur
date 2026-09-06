class_name Ecran
extends Node2D
## Un écran du jeu. La racine n'en garde qu'un à la fois.
##
## La navigation passe par un signal plutôt qu'un appel direct : un écran n'a
## pas à connaître la racine, ni les autres écrans, ce qui évite les cycles au
## chargement des classes.

signal demande_ecran(nom: String, donnees: Dictionary)

var donnees: Dictionary = {}

func demarrer() -> void:
	pass
