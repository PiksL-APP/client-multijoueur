extends SceneTree
## LE BANC DE COHÉRENCE — `godot --headless -s outils/coherence.gd`
##
## « Un arbre ne doit pas être sur une route, une fleur doit être sur de la
## terre. » On ne le vérifie pas à l'oeil : on bâtit Pikstown, on relit chaque
## objet posé par `_objet`, et on regarde ce qu'il y a SOUS SON PIED — la case
## du dessin, et la pièce qui la couvre. Tout objet de nature dont le pied tombe
## sur une case de rue, ou dans la bande de chaussée d'une grosse pièce, est une
## faute. Le banc les compte, les nomme, et donne la case.

const NATURE := ["nature/", "voxel/", "pavillons/tree", "pavillons/fence",
	"pavillons/path", "pavillons/planter"]

func _init() -> void:
	var fiche: Dictionary = Quartiers.CATALOGUE["pikstown"]
	Quartiers.inventaire = true
	var carte := Quartiers.carte_de(fiche)
	var dessin: Array = fiche["plan"]
	var racine := Quartiers.batir_fiche(fiche, "pikstown", Rect2i(), {"carte": carte},
		Quartiers.P_VERDURE | Quartiers.P_MOBILIER)
	var total := 0
	var fautes := {}
	var exemples := {}
	for n in racine.get_children():
		if not n.has_meta("modele"): continue
		var m := String(n.get_meta("modele"))
		var nature := false
		for pref in NATURE:
			if m.contains(pref): nature = true
		if not nature: continue
		total += 1
		var p: Vector3 = (n as Node3D).position
		var c := Vector2i(floori(p.x / Quartiers.CASE), floori(p.z / Quartiers.CASE))
		var car: String = Quartiers._car(dessin, c.x, c.y)
		var motif := ""
		if carte.route(c):
			# ⚠ LE TROTTOIR FAIT PARTIE DE LA CASE DE RUE. Un arbre d'alignement
			# se plante sur le trottoir, à 0,42 case du centre ; il n'est PAS
			# sur la chaussée. On mesure donc l'écart au centre selon l'axe
			# perpendiculaire à la rue : à moins de 0,30 case, c'est le bitume.
			var f: Array = carte.tuile(c)
			var selon_x: bool = int(f[1]) % 2 == 0
			var centre := carte.centre(c)
			var ecart: float = absf((p.z - centre.z) if selon_x else (p.x - centre.x)) / Quartiers.CASE
			if String(f[0]) != "road-straight" and String(f[0]) != "road-crossing":
				motif = "sur %s" % String(f[0])
			elif ecart < 0.30:
				motif = "sur le bitume (%.2f case du centre)" % ecart
			# sinon : sur le trottoir, à sa place
		elif carte.case_prise(c) and not carte.case_couverte(c) == false and carte.piece_sur(c).get("t", "") != "":
			var pc: Dictionary = carte.piece_sur(c)
			motif = "dans l'emprise de %s" % String(pc.get("t", "?"))
		elif not carte.terre(c): motif = "dans l'eau"
		if motif == "": continue
		var cle := m.get_file().get_basename() + " " + motif
		fautes[cle] = int(fautes.get(cle, 0)) + 1
		if not exemples.has(cle): exemples[cle] = c
	print("── cohérence : %d objets de nature relus" % total)
	var liste := fautes.keys()
	liste.sort_custom(func(a, b): return int(fautes[a]) > int(fautes[b]))
	var somme := 0
	for k in liste:
		somme += int(fautes[k])
		print("  %5d  %s   ex. (%d,%d)" % [fautes[k], k, exemples[k].x, exemples[k].y])
	print("COHÉRENT." if somme == 0 else "%d OBJET(S) MAL POSÉ(S)." % somme)
	quit()
