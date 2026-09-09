extends SceneTree
## LE VÉRIFICATEUR DE PLAN — `godot --headless --path . -s outils/verifier.gd`
##
## Un dessin peut être joli et faux. Les règles vivent dans `Quartiers.fautes`
## (l'éditeur s'en sert aussi) ; ce banc ne fait que les dérouler et les dire
## avec la case en clair. Le lancer après chaque retouche du dessin coûte deux
## secondes et évite une photo pour rien.

func _init() -> void:
	var total := 0
	for id in Quartiers.CATALOGUE.keys():
		var fiche: Dictionary = Quartiers.CATALOGUE[id]
		var liste: Array = Quartiers.fautes(fiche)
		print("── ", id)
		for f in liste:
			if int(f["i"]) < 0:
				print("  ", f["texte"])
			else:
				print("  (%d,%d) %s" % [f["i"], f["j"], f["texte"]])
		if liste.is_empty():
			var carte := Quartiers.carte_de(fiche)
			print("  rien à signaler (%d cases, %d bâtiments, %d grosses pièces)" % [
				carte.cases.size(), Quartiers.batiments(fiche["plan"]).size(), carte.pieces.size()])
		total += liste.size()
	print("PLAN PROPRE." if total == 0 else "%d FAUTES." % total)
	quit()
