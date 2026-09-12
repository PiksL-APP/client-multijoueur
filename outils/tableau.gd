extends Node3D
## LE BANC DU TABLEAU DE BORD DU RESPECT : les trois barres du district, et
## les cinq humeurs sous les pieds des hommes de gang.
##
## ⚠ CE QUE CE BANC PROUVE, ET CE QU'IL NE PROUVE PAS. La ville, les gangs et
## la jauge sont VRAIS : on bâtit un `PlanVille`, une `VilleVivante`, on règle
## le respect et on demande les barres à `VilleVivante.barres_de_respect` — la
## fonction que le tableau de bord appelle en jeu. Les pantins sortent de
## `FormesCarnage.pieton` et leur anneau de `FormesCarnage.anneau_humeur`.
## Ce que le banc ne prouve pas, c'est que CARNAGE branche bien la fiche : ça,
## c'est `outils/respect.gd` qui le vérifie, sur les mêmes fonctions.
##
##   outils/tableau.sh [sortie]

var _sortie := "/tmp/tableau/respect.png"
var _triche := false
var _roue := false
var _superette := false
var _planque := false
var _pause := false

func _ready() -> void:
	var code := "RESPECT"
	for a in OS.get_cmdline_args():
		if a.begins_with("--sortie="): _sortie = a.trim_prefix("--sortie=")
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
		if a == "--triche": _triche = true
		if a == "--roue": _roue = true
		if a == "--superette": _superette = true
		if a == "--pause": _pause = true
		if a == "--planque": _planque = true

	# La nuit forcée : le cycle jour/nuit tourne en temps réel, et deux photos
	# prises à trois minutes d'écart n'ont pas la même lumière.
	MatieresCarnage.nuit_forcee = 0.55
	var amb: Array = MatieresCarnage.ambiance()
	add_child(amb[0])
	add_child(amb[1])

	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); sol.mesh = pm
	var ms := StandardMaterial3D.new(); ms.albedo_color = Color("#2a2a2c")
	sol.material_override = ms
	add_child(sol)

	var carte := PlanVille.new(code)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ville := VilleVivante.new(carte, rng)
	var moi := "banc"

	# Un endroit tenu par un gang : les barres montrent le trio DE CE
	# DISTRICT, pas trois gangs tirés au sort.
	var ou := carte.centre()
	var chez := 0
	for py in PlanVille.pates_y():
		for px in PlanVille.pates_x():
			if carte.territoire_du_pate(Vector2i(px, py)) >= 0:
				ou = PlanVille.centre_pate(Vector2i(px, py))
				chez = carte.territoire_du_pate(Vector2i(px, py))
				break
		if chez >= 0 and ou != carte.centre():
			break
	var trio: Array = carte.trio(ou)
	# Un trio qui raconte quelque chose : le local vous chasse, l'autre vous
	# couvre, le Consortium hésite.
	ville._ajuster_respect(moi, int(trio[0]), -38.0)
	ville._ajuster_respect(moi, int(trio[1]), 35.0)
	ville._ajuster_respect(moi, int(trio[2]), 8.0)

	# Cinq hommes, cinq humeurs, dans l'ordre des paliers.
	var x := -16.0
	for etat in 5:
		var gang := int(trio[etat % trio.size()])
		var homme := FormesCarnage.pieton(carte.couleur_du_gang(gang), true, "", false,
			FormesCarnage.PEAUX_GANG[etat % FormesCarnage.PEAUX_GANG.size()])
		homme.position = Vector3(x, 0, 0)
		homme.rotation.y = PI
		if etat != VilleVivante.H_NEUTRE:
			homme.add_child(FormesCarnage.anneau_humeur(FormesCarnage.COULEURS_HUMEUR[etat]))
		add_child(homme)
		var mot := Decor.etiquette(String(VilleVivante.NOMS_HUMEUR[etat]).to_upper(),
			FormesCarnage.COULEURS_HUMEUR[etat], 22)
		mot.position = Vector3(x, 3.6, 0)
		add_child(mot)
		x += 8.0

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 7.5, 17.0)
	cam.look_at(Vector3(0, 1.4, 0))

	# Le tableau de bord, monté comme `Partie` le monte.
	var interface := CanvasLayer.new()
	add_child(interface)
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_script(load("res://ui/hud.gd"))
	interface.add_child(hud)
	hud.aide = [["ZQSD", "conduire"], ["E", "monter"], ["ESPACE", "tirer"]]
	hud.scores = [{"pseudo": "VOUS", "score": 4200, "couleur": Palette.SERIE, "moi": true}]
	hud.sans_limite = false
	hud.chrono = 96.0
	hud.fiche = {
		# QUATRE JAUGES : vie, tôle, faim, soif — telles que `fiche_joueur` les
		# empile. La soif est sous le seuil du creux, donc rouge : c'est l'état
		# qu'il faut pouvoir juger sur une image, pas celui où tout va bien.
		"jauges": [
			{"nom": "VIE", "part": 0.72, "couleur": Palette.BON, "valeur": "72"},
			{"nom": "TÔLE", "part": 0.55, "couleur": Palette.SERIE, "valeur": "110"},
			{"nom": "FAIM", "part": 0.48, "couleur": Palette.SERIEUX, "valeur": "48"},
			{"nom": "SOIF", "part": 0.14, "couleur": Palette.CRITIQUE, "valeur": "14"},
		],
		"etoiles": 2,
		"arme": {"nom": "mitraillette", "munitions": "48"},
		"argent": {"sur_soi": 1840, "banque": 6200, "planque": true},
		"puces": [ville.puce_de_gang(moi, chez),
			{"texte": "sandwich ×2", "couleur": Provisions.fiche("sandwich")["couleur"]},
			{"texte": "bouteille d'eau ×1", "couleur": Provisions.fiche("eau")["couleur"]}],
		"respect": ville.barres_de_respect(moi, ou),
		"accent": Palette.SERIE,
	}
	hud.queue_redraw()

	# `--triche` pose PAR-DESSUS le menu du code Konami, avec deux lignes
	# allumées : c'est la seule façon de le photographier sans taper
	# ↑ ↑ ↓ ↓ ← → ← → B A dans un navigateur.
	# `--roue` pose la roue des stations : six secteurs, celui du haut visé.
	if _roue:
		var roue := Control.new()
		roue.set_anchors_preset(Control.PRESET_FULL_RECT)
		roue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roue.set_script(load("res://ui/roue.gd"))
		interface.add_child(roue)
		roue.stations = Sons.STATIONS
		roue.choix = 2
		roue.actuelle = 0
		roue.queue_redraw()

	# `--superette` pose le menu de la boutique, panier à moitié plein et une
	# réponse de caisse : c'est l'état qu'on ne voit jamais en photographiant
	# un menu vide.
	if _superette:
		var boutique := Control.new()
		boutique.set_anchors_preset(Control.PRESET_FULL_RECT)
		boutique.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boutique.set_script(load("res://ui/superette.gd"))
		interface.add_child(boutique)
		var articles: Array = []
		for a in Provisions.CATALOGUE:
			articles.append({"cle": String(a["cle"]), "nom": String(a["nom"]),
				"prix": int(a["prix"]), "effet": Provisions.effet(String(a["cle"])),
				"couleur": a["couleur"],
				"possede": 2 if String(a["cle"]) == "sandwich" else (
					1 if String(a["cle"]) == "eau" else 0)})
		boutique.articles = articles
		boutique.argent = 140
		boutique.poches = 3
		boutique.poches_max = Provisions.POCHES
		boutique.choix = 4
		boutique.message = "sandwich dans le sac"
		boutique.message_couleur = PlanVille.COULEUR_SUPERETTE
		boutique.queue_redraw()

	# `--planque` pose le menu du coffre, avec un peu d'argent sur soi, le
	# coffre déjà installé et l'arsenal à portée : l'état où l'on hésite.
	if _planque:
		var coffre := Control.new()
		coffre.set_anchors_preset(Control.PRESET_FULL_RECT)
		coffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coffre.set_script(load("res://ui/planque.gd"))
		interface.add_child(coffre)
		coffre.lignes = [
			{"cle": "depot", "nom": "déposer", "effet": "mettre son argent à l'abri du coffre", "etat": "depot", "couleur": Palette.BON},
			{"cle": "retrait", "nom": "retirer", "effet": "reprendre tout ce qu'il y a au coffre", "etat": "retrait", "couleur": Palette.AVERTISSEMENT},
			{"cle": "coffre", "nom": "coffre", "effet": "on garde le double de sa fortune en mourant", "prix": 1800, "etat": "fait", "couleur": Palette.SERIE},
			{"cle": "arsenal", "nom": "arsenal", "effet": "on ne perd plus son arme en mourant", "prix": 3200, "etat": "achat", "couleur": Palette.SERIE},
			{"cle": "garage", "nom": "garage", "effet": "la voiture ramenée ici vous attend après la mort", "prix": 5000, "etat": "apres:arsenal", "couleur": Palette.SERIE},
		]
		coffre.argent = 640
		coffre.banque = 3450
		coffre.choix = 3
		coffre.message = "coffre installé"
		coffre.message_couleur = Palette.BON
		coffre.queue_redraw()

	# `--pause` pose le menu de sortie : c'est le seul écran par lequel une
	# manche se termine, et il ne se voit qu'en appuyant sur ÉCHAP en jeu.
	if _pause:
		var repos := Control.new()
		repos.set_anchors_preset(Control.PRESET_FULL_RECT)
		repos.mouse_filter = Control.MOUSE_FILTER_IGNORE
		repos.set_script(load("res://ui/pause.gd"))
		interface.add_child(repos)
		repos.sous_titre = "$1840 sur soi · $6200 au coffre"
		repos.lignes = [
			{"texte": "REPRENDRE", "detail": "", "couleur": Palette.BON},
			{"texte": "QUITTER LA VILLE", "detail": "la manche s'arrête pour la table",
				"couleur": Palette.SERIEUX},
		]
		repos.choix = 1
		repos.queue_redraw()

	if _triche:
		var menu := Control.new()
		menu.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.set_script(load("res://ui/triche.gd"))
		interface.add_child(menu)
		menu.codes = menu.codes_neufs()
		menu.codes[0]["actif"] = true      # blindage allumé
		menu.codes[2]["actif"] = true      # le magot, déjà encaissé
		menu.choix = 4
		menu.queue_redraw()

	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("photo %s — district %s" % [_sortie, carte.nom_du_gang(chez)])
	get_tree().quit()
