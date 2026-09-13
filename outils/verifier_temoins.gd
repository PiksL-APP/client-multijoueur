extends SceneTree
## LE CONTRÔLE DES NEUF TÉMOINS, en une table.
##
##     godot --headless --path . --script res://outils/verifier_temoins.gd
##
## ⚠ POURQUOI CET OUTIL EXISTE. Trois défauts du 13/09 sur neuf étaient
## INVISIBLES sur une capture et se comptent en une seconde : des objets restés
## sur la chaussée, des bâtiments qui se chevauchent, des modèles dont le
## chemin ne résout pas (le lot est alors sauté en silence — trente-six maisons
## évaporées en vieille ville sans que rien ne le dise). Une capture montre ce
## qu'on a mis ; elle ne montre pas ce qui manque.
##
## Les trois colonnes de droite doivent être à ZÉRO, toujours.
## Le contrôle des neuf témoins : rien sur la chaussée, aucun lot qui en
## chevauche un autre, aucun modèle manquant.
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const NOMS := ["centre", "plage", "colline", "banlieue", "industrie",
	"vieille-ville", "chaud", "campus", "bidonville"]

func _init() -> void:
	print("%-16s %6s %8s %6s %10s %10s" % ["témoin", "lots", "objets", "pubs", "sur route", "chevauch."])
	for n in NOMS:
		var v := Ville2.charger("res://cartes/temoin-%s.json" % n)
		var pubs := 0
		for o in v.objets:
			if String(o["m"]) == "pub": pubs += 1
		# Rien sur la chaussée : on relance la règle et on compte ce qu'elle
		# retirerait encore. Zéro attendu.
		var avant := v.objets.size()
		PROPRETE.rien_sur_les_routes(v)
		var sur_route := avant - v.objets.size()
		# Chevauchements de lots, en demi-cases.
		var pris := {}
		var chev := 0
		for l in v.lots:
			var touche := false
			for b in int(l["h"]):
				for a in int(l["w"]):
					var k := Vector2i(int(l["x"]) + a, int(l["y"]) + b)
					if pris.has(k): touche = true
					pris[k] = true
			if touche: chev += 1
		# Modèles introuvables.
		var absents := {}
		for l in v.lots:
			var ch := KitVille2.chemin(String(l["m"]))
			if not ResourceLoader.exists(ch): absents[String(l["m"])] = true
		print("%-16s %6d %8d %6d %10d %10d %s" % [n, v.lots.size(), v.objets.size(),
			pubs, sur_route, chev, ("" if absents.is_empty() else str(absents.keys()))])
	quit()
