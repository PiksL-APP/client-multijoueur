extends SceneTree
## De quel côté monte `road-slant` sans rotation ? On mesure la hauteur
## moyenne des sommets du bord OUEST et du bord EST. Le deviner à l'œil sur
## une planche de contact, c'est une ville entière de rampes à l'envers.
func _init():
	for nom in ["road-slant", "road-slant-high", "tile-slant"]:
		var m := FormesCarnage.maillage_kenney("res://modeles/kenney/routes/%s.glb" % nom, 0.0, Vector3.AXIS_X, 0.0)
		var a := m.surface_get_arrays(0)
		var s: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var yo := 0.0; var no := 0; var ye := 0.0; var ne := 0
		var yn := 0.0; var nn := 0; var ys := 0.0; var ns := 0
		for v in s:
			if v.x < -0.4: yo += v.y; no += 1
			if v.x > 0.4: ye += v.y; ne += 1
			if v.z < -0.4: yn += v.y; nn += 1
			if v.z > 0.4: ys += v.y; ns += 1
		print("%-18s ouest %.3f  est %.3f  nord %.3f  sud %.3f" % [nom,
			yo / maxf(no, 1), ye / maxf(ne, 1), yn / maxf(nn, 1), ys / maxf(ns, 1)])
	quit()
