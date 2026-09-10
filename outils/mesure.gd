extends Node3D
## LE BANC DE LA VILLE MORCELÉE — ce que coûte un morceau, et ce que coûterait
## la ville entière.
##
##     godot --headless --path . outils/mesure.tscn
##
## ⚠ C'EST CE CHIFFRE QUI A DÉCIDÉ DE TOUTE L'ARCHITECTURE. Pikstown entière :
## quatre secondes et cinquante-quatre mille nœuds en NATIF — donc environ une
## minute dans le navigateur, où le jeu tourne. D'où `VilleMorcelee`. Et c'est
## ce même banc qui a montré qu'un morceau coûtait 302 ms parce que chaque
## poseur balayait les 28 000 cases de la ville : 124 ms une fois les boucles
## bornées à la zone. On ne discute pas ces choses-là, on les mesure.

func _compter(n: Node) -> int:
	var t := 1
	for e in n.get_children(): t += _compter(e)
	return t

func _ready() -> void:
	var fiche: Dictionary = Quartiers.CATALOGUE["pikstown"]
	var liste: Array = Quartiers.fautes(fiche)
	print("FAUTES ", liste.size())
	for f in liste.slice(0, 5): print("   ", f)
	var t0 := Time.get_ticks_msec()
	var prete := Quartiers.preparer(fiche)
	print("PREPARER %d ms, %d cases, %d batiments" % [Time.get_ticks_msec() - t0,
		prete["carte"].cases.size(), (prete["batiments"] as Array).size()])
	var ville := VilleMorcelee.new()
	add_child(ville)
	ville.regler(fiche, "pikstown", 3)
	var t1 := Time.get_ticks_msec()
	var n := 0
	for y in range(3, 9):
		for x in range(3, 9):
			ville._batir(Vector2i(x, y))
			n += 1
	var t2 := Time.get_ticks_msec()
	print("%d MORCEAUX %d ms (%.1f ms par morceau), %d noeuds, %d cases couvertes"
		% [n, t2 - t1, float(t2 - t1) / float(n), _compter(ville),
		n * VilleMorcelee.COTE * VilleMorcelee.COTE])
	var t3 := Time.get_ticks_msec()
	var entier := Quartiers.batir_fiche(fiche, "entier")
	print("ENTIERE %d ms, %d noeuds" % [Time.get_ticks_msec() - t3, _compter(entier)])
	get_tree().quit()
