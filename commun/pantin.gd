class_name Pantin
extends Node3D
## Un personnage voxel : les six parties nommées du glTF (`tete`, `corps`,
## `bras_g`, `bras_d`, `jambe_g`, `jambe_d`), chacune exprimée autour de son
## pivot par `outils/voxel.py`. On les balance en marchant, on penche le
## buste dans une charge. Le visage regarde vers +z au repos ; le pantin se
## tourne vers la direction de son dernier pas.

const MODELES := "res://modeles/voxel/"

var parties: Dictionary = {}
var phase := 0.0
var marche := false
var cap := 0.0                     # l'orientation visée, en radians
var penche := 0.0                  # inclinaison du buste (une charge), en radians

static func depuis(chemin: String) -> Pantin:
	var p := Pantin.new()
	var modele := (load(chemin) as PackedScene).instantiate() as Node3D
	p.add_child(modele)
	for n in modele.find_children("*", "MeshInstance3D", true, false):
		p.parties[n.name] = n
	return p

func regarder(direction: Vector2) -> void:
	if direction.length() > 0.01:
		cap = atan2(direction.x, direction.y)

func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, cap, clampf(delta * 14.0, 0.0, 1.0))
	var cible := 0.0
	if marche:
		phase += delta * 11.0
		cible = sin(phase) * 0.7
	else:
		phase = 0.0
	var lisse: float = clamp(delta * 12.0, 0.0, 1.0)
	for nom in parties:
		var partie: Node3D = parties[nom]
		match nom:
			"jambe_g", "bras_d":
				partie.rotation.x = lerp(partie.rotation.x, cible, lisse)
			"jambe_d", "bras_g":
				partie.rotation.x = lerp(partie.rotation.x, -cible, lisse)
	# Le buste et la tête sautillent d'un voxel en marchant.
	var saut := (absf(sin(phase)) * 0.06) if marche else 0.0
	for nom in ["corps", "tete", "bras_g", "bras_d"]:
		if parties.has(nom):
			var partie: Node3D = parties[nom]
			partie.position.y = _base_y(nom) + saut
	rotation.x = lerp(rotation.x, penche, lisse)

func _base_y(nom: String) -> float:
	match nom:
		"tete": return 1.5
		"bras_g", "bras_d": return 1.4375
		_: return 0.75
