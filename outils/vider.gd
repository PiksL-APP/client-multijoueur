extends SceneTree
## Vide le catalogue des intérieurs dans `_transfert/vitrine/catalogue.json`,
## POSITIONS RÉSOLUES : `contre()` déjà calculé, gabarits mesurés.
##
## C'est l'entrée de tout le reste — `outils/verifier.py` et l'éditeur web
## travaillent sur ce fichier, jamais sur le GDScript : eux n'ont pas de moteur
## pour mesurer un modèle.
##
##     godot --headless --path . --script outils/vider.gd
func _init() -> void:
	var tout := {}
	for id in Interieurs.CATALOGUE.keys():
		var f: Dictionary = Interieurs.plan(id)
		var meubles := []
		for m in f["meubles"]:
			var b := Interieurs.gabarit(m[0])
			meubles.append({"m": m[0], "x": snappedf(m[1], 0.01), "z": snappedf(m[2], 0.01),
				"r": m[3], "y": snappedf(m[4], 0.01), "t": snappedf(m[5], 0.01),
				"l": snappedf(b.size.x, 0.01), "h": snappedf(b.size.y, 0.01),
				"p": snappedf(b.size.z, 0.01)})
		tout[id] = {
			"nom": Interieurs.CATALOGUE[id]["nom"], "prix": Interieurs.CATALOGUE[id]["prix"],
			"quartier": Interieurs.CATALOGUE[id]["quartier"],
			"resume": Interieurs.CATALOGUE[id]["resume"],
			"plan": f["plan"], "meubles": meubles,
			"sols": Array(f["sols"]).map(func(c): return c.to_html(false)),
			"teintes": f["teintes"].keys().reduce(func(a, k): a[k] = f["teintes"][k].to_html(false); return a, {}),
			"teintes_meubles": f["teintes_meubles"].keys().reduce(func(a, k): a[k] = f["teintes_meubles"][k].to_html(false); return a, {}),
			"coffre": Interieurs.coffre(id),
		}
	var fic := FileAccess.open("res://_transfert/vitrine/catalogue.json", FileAccess.WRITE)
	fic.store_string(JSON.stringify(tout, "\t"))
	fic.close()
	print("catalogue vidé : %d intérieurs" % tout.size())
	quit()
