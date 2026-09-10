extends SceneTree
## LE BANC DE LA FLOTTE : les mouillages existent-ils, et un bateau tient-il
## sur l'eau ?
##
## On ne peut pas lancer une manche depuis une session sans réseau, et une
## capture ne dirait rien d'une mécanique de navigation. Ici on interroge le
## PLAN directement — c'est lui qui décide de tout, et il est pur.
##
##   godot --headless -s outils/flotte.gd [-- --code=ESSAI]

const PAS := PlanVille.PAS

func _init() -> void:
	var code := "FLOTTE"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
	var carte := PlanVille.new(code)
	print("── code %s — %d × %d tuiles" % [code, PlanVille.COLONNES, PlanVille.LIGNES])

	# On balaye une BANDE de la ville, pas la ville entière : trois cent
	# cinquante mille tuiles bâties d'un coup, c'est ce que le jeu se refuse à
	# faire, et le banc n'a pas de raison d'être moins sage.
	var eau := 0
	var bord := 0
	var mouillages := 0
	var flotte := {}
	for l in range(120, 260):
		for c in range(120, 400):
			if not carte.eau(c, l):
				continue
			eau += 1
			var quai := false
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if not carte.eau(c + d.x, l + d.y):
					quai = true
			if quai:
				bord += 1
			for place in carte.tuile(c, l)["places"]:
				mouillages += 1
				var d2 := carte.decrire(carte.tuile(c, l), place)
				var nom := String(FormesCarnage.MODELES_VOITURES[int(d2["modele"])])
				flotte[nom] = int(flotte.get(nom, 0)) + 1

	print("  %d cases d'eau, dont %d au bord d'un quai" % [eau, bord])
	print("  %d bateaux amarrés (%.1f %% des cases de quai)"
		% [mouillages, 100.0 * float(mouillages) / float(maxi(bord, 1))])
	var fautes := 0
	if mouillages == 0:
		print("  ⚠ AUCUN BATEAU : le port est vide")
		fautes += 1
	for nom in flotte:
		print("    %-18s %d" % [String(nom), int(flotte[nom])])

	# LE BATEAU TIENT-IL SUR L'EAU ? On pousse une coque vers la terre et on
	# vérifie qu'elle est repoussée — puis qu'un point d'eau ne l'est pas.
	var essais := 0
	var arretes := 0
	for l in range(120, 260):
		for c in range(120, 400):
			if not carte.eau(c, l) or carte.eau(c + 1, l):
				continue
			essais += 1
			if essais > 200:
				break
			var vers_la_terre := carte.centre_tuile(c + 1, l)
			if bool(carte.degager_bateau(vers_la_terre, 20.0)[1]):
				arretes += 1
		if essais > 200:
			break
	print("  la terre arrête la coque : %d fois sur %d" % [arretes, essais])
	if essais > 0 and arretes < essais:
		print("  ⚠ une coque entre dans la terre")
		fautes += 1

	# Et l'inverse : au large, rien ne doit gêner.
	var libre := 0
	var testes := 0
	for l in range(160, 200):
		for c in range(160, 240):
			if not carte.eau(c, l):
				continue
			var large := true
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if not carte.eau(c + d.x, l + d.y):
					large = false
			if not large:
				continue
			testes += 1
			if not bool(carte.degager_bateau(carte.centre_tuile(c, l), 20.0)[1]):
				libre += 1
	print("  au large, la coque passe : %d fois sur %d" % [libre, testes])
	if testes > 0 and libre < testes:
		print("  ⚠ quelque chose arrête la coque en pleine eau")
		fautes += 1

	print("")
	print("FLOTTE EN PLACE." if fautes == 0 else "%d défaut(s)." % fautes)
	quit(0 if fautes == 0 else 1)
