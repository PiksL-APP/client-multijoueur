extends SceneTree
## Coût d'un morceau de Pikstown, passe par passe : c'est ce que le joueur
## paie à chaque image quand il découvre du terrain.
##   godot --headless --path . --script outils/banc_morceaux.gd

func _init() -> void:
	var fiche: Dictionary = Quartiers.CATALOGUE["pikstown"]
	var prete: Dictionary = Quartiers.preparer(fiche)
	var totaux := [0, 0, 0, 0, 0, 0, 0]
	var pire := [0, 0, 0, 0, 0, 0, 0]
	var passes := [VilleMorcelee.PASSES[0], VilleMorcelee.PASSES[1], VilleMorcelee.PASSES[2], Quartiers.P_VERDURE, Quartiers.P_MOBILIER, Quartiers.P_OBJETS]
	var n := 0
	# Les 7×7 morceaux autour du cœur (159,150 cases → morceau 9,9).
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := Vector2i(9 + dx, 9 + dy)
			var zone := Rect2i(c.x * VilleMorcelee.COTE, c.y * VilleMorcelee.COTE, VilleMorcelee.COTE, VilleMorcelee.COTE)
			var noeud := Node3D.new()
			root.add_child(noeud)
			for p in passes.size():
				var t0 := Time.get_ticks_usec()
				Quartiers.batir_fiche(fiche, "b", zone, prete, passes[p], noeud)
				var dt := (Time.get_ticks_usec() - t0) / 1000
				totaux[p] += dt
				pire[p] = maxi(pire[p], dt)
			var carte: CarteVille = prete["carte"]
			var alea := RandomNumberGenerator.new()
			var t1 := Time.get_ticks_usec()
			Quartiers._poser_mobilier(noeud, carte, fiche["plan"], alea, zone)
			var d1 := (Time.get_ticks_usec() - t1) / 1000
			t1 = Time.get_ticks_usec()
			Quartiers._poser_panneaux(noeud, carte, fiche["plan"], alea, zone)
			var d2 := (Time.get_ticks_usec() - t1) / 1000
			print("[morceaux] %s mobilier seul %d ms, panneaux seuls %d ms" % [c, d1, d2])
			n += 1
			noeud.queue_free()
	print("[morceaux] %d morceaux — moyenne par passe (ms) : sols %d, chaussées %d, bâtiments %d, verdure %d, mobilier %d, objets %d" % [n, totaux[0] / n, totaux[1] / n, totaux[2] / n, totaux[3] / n, totaux[4] / n, totaux[5] / n])
	print("[morceaux] pire par passe (ms) : sols %d, chaussées %d, bâtiments %d, verdure %d, mobilier %d, objets %d" % [pire[0], pire[1], pire[2], pire[3], pire[4], pire[5]])
	print("[morceaux] moyenne par morceau : %d ms" % ((totaux[0] + totaux[1] + totaux[2] + totaux[3] + totaux[4] + totaux[5]) / n))
	quit()
