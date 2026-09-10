extends Control
## LA ROUE DES STATIONS : on tient `R`, on pousse dans une direction, on
## relâche. C'est le geste de la roue d'armes des GTA modernes, et il vaut
## mieux qu'un défilement pour une raison simple — avec six stations, appuyer
## cinq fois pour revenir à la précédente, ça se paie en tôle.
##
## ⚠ Elle ne met RIEN en pause : la manche est multijoueur, et trois autres
## joueurs n'ont pas à attendre qu'on choisisse une musique. La voiture roule
## donc pendant qu'on vise — seul le braquage est neutralisé, sinon pousser à
## gauche pour choisir une station envoie la voiture dans le trottoir.

const RAYON := 104.0          ## rayon de la couronne
const EPAISSEUR := 54.0       ## largeur d'un secteur
const SEGMENTS := 24          ## finesse d'un arc

var stations: Array = []      ## la table de `Sons.STATIONS`
var choix := 0                ## la station visée
var actuelle := 0             ## celle qui joue en ce moment
var temps := 0.0

func _draw() -> void:
	if stations.is_empty():
		return
	var centre := get_viewport_rect().size * 0.5
	var pas := TAU / float(stations.size())
	# Un voile léger, pas un noir d'écran de pause : on doit continuer à voir
	# la rue dans laquelle on roule.
	draw_circle(centre, RAYON + EPAISSEUR * 0.6, Color(0, 0, 0, 0.42))

	for i in stations.size():
		var station: Dictionary = stations[i]
		var couleur: Color = station.get("couleur", Palette.ENCRE_DOUCE)
		var vise := i == choix
		# Le secteur i est centré sur le HAUT pour i = 0, puis on tourne dans
		# le sens des aiguilles — l'ordre de la table est l'ordre de la roue.
		var milieu := -PI * 0.5 + pas * float(i)
		var depart := milieu - pas * 0.44
		var fin := milieu + pas * 0.44
		var rayon := RAYON + (10.0 if vise else 0.0)
		var largeur := EPAISSEUR + (10.0 if vise else 0.0)
		var teinte := Color(couleur, 0.9 if vise else 0.30)
		draw_arc(centre, rayon, depart, fin, SEGMENTS, teinte, largeur)
		# Le nom, posé EN DEHORS de la couronne. Écrit dedans, il tombait sur
		# la couleur du secteur — texte sombre sur vert vif, illisible pile sur
		# celui qu'on vise. Dehors, il est toujours sur le fond de la ville.
		var ou := centre + Vector2.RIGHT.rotated(milieu) * (rayon + largeur * 0.62)
		var nom := String(station.get("nom", ""))
		var taille := UI.TEXTE_POLICE.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var coin := ou - taille * Vector2(0.5, -0.25)
		# Un cartouche derrière le nom : la ville est claire par endroits, et
		# un texte blanc sur un mur beige ne se lit pas.
		draw_rect(Rect2(coin - Vector2(5.0, 11.0), taille + Vector2(10.0, 5.0)),
			Color(0, 0, 0, 0.55), true)
		draw_string(UI.TEXTE_POLICE, coin, nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Palette.ENCRE if vise else Palette.ENCRE_DOUCE)
		# Une pastille sur la station qui JOUE : sans elle, on ne sait pas d'où
		# l'on part, et on relâche sur une autre par erreur.
		if i == actuelle:
			draw_circle(centre + Vector2.RIGHT.rotated(milieu) * (RAYON - EPAISSEUR * 0.62),
				4.0, couleur)

	var vise: Dictionary = stations[posmod(choix, stations.size())]
	UI.inscription(self, centre - Vector2(0, 8), String(vise.get("nom", "")), 13,
		vise.get("couleur", Palette.ENCRE))
	UI.inscription(self, centre + Vector2(0, 14), "relâchez R", 8, Palette.ENCRE_FAIBLE)
