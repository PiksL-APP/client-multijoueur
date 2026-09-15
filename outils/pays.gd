extends SceneTree
## LA CARTE DE L'ARCHIPEL DES AURONES — l'image que le client valide.
##
##     godot --headless --path . --script res://outils/pays.gd
##     godot --headless --path . --script res://outils/pays.gd -- \
##         --graine=1 --image=/tmp/aurones.png --echelle=2 \
##         --json=cartes/aurones-fenetre.json --fenetre=400,420,200,200
##
## ⚠ C'EST LE LIVRABLE DU JOUR, ET IL PASSE AVANT TOUTE SCÈNE 3D. Le client a
## fourni quatre cartes dessinées et demandé à valider POINT PAR POINT avant
## qu'on génère quoi que ce soit : « on va juste mettre en place le réseau de
## TGV, le TRAM, le MÉTRO, les autoroutes, les ruelles, etc. Ensuite on va
## mettre en place tout le reste ». Cette image est la réponse, et elle doit
## ressembler à la sienne — même archipel, mêmes six réseaux, mêmes couleurs.
##
## ⚠ ET POURQUOI UNE IMAGE PLUTÔT QU'UN RENDU. Vingt kilomètres de côté, c'est
## un million de cases : une capture verticale de l'archipel demanderait de
## bâtir un million de cases de décor, c'est-à-dire précisément ce que
## l'architecture vient de rendre impossible. Un pixel par case se calcule sans
## le moindre maillage et se regarde d'un coup d'œil. La 3D vient après, sur une
## fenêtre de quatre kilomètres — la taille que les outils existants savent déjà
## photographier.
##
## Les chiffres imprimés ne sont pas de la décoration : ce sont les seuls qui
## disent si le plan tient. Si l'Île Centrale ne fait pas ses 5,5 km, si une
## ligne de métro a zéro station, si le trait de côte vaut le périmètre d'un
## cercle parfait, c'est là qu'on le voit — pas sur l'image, où tout se
## ressemble de loin.

const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")

## ═══════════════════════════════════════════════════════════════════════════
## LA PALETTE — celle de la carte du client, relevée sur ses quatre dessins
## ═══════════════════════════════════════════════════════════════════════════
##
## Elle n'imite pas le jeu : elle imite UNE CARTE, parce que c'est ce qui se lit
## à un pixel par case. Un dégradé continu ne se lit pas ; des bandes, si.
const C_LARGE := Color("#2f7fb5")        ## le large
const C_COTE := Color("#9fd0e8")         ## les hauts-fonds
const C_ECUME := Color("#cfe8f4")        ## le liseré de rivage
const C_SABLE := Color("#e8dcb4")
const C_PLAINE := Color("#cfd9a8")       ## la plaine bâtie, claire
const C_PRE := Color("#a9c47e")
const C_BOIS := Color("#7ba05b")
const C_COLLINE := Color("#93a86a")
const C_ROCHE := Color("#b3ab97")
const C_CIME := Color("#e4e0d4")

## LES SIX RÉSEAUX. L'ordre du dessin est celui de la légende du client, du plus
## fin au plus structurant : le train passe PAR-DESSUS tout, parce que c'est lui
## qui tient l'archipel.
const C_COTIER := Color("#b9a97e")
const C_LOCALE := Color("#9a968c")
const C_SECONDAIRE := Color("#e3c05a")
const C_PRIMAIRE := Color("#d9822b")
const C_BUS := Color("#f2c230")
const C_TRAM := Color("#2f8b57")
const C_METRO := Color("#2166b0")
const C_TRAIN2 := Color("#e2761b")
const C_TRAIN := Color("#cf3227")
## La voie maritime : un blanc cassé en longs tirets, la convention des cartes
## marines. Elle ne peut pas se confondre avec le pointillé serré du métro.
const C_FERRY := Color("#f2f7fa")
const C_STATION := Color("#14181e")
const C_HALO := Color("#ffffff")
## ⚠ LE TABLIER D'UN PONT SE DESSINE, ET C'EST LA RÉPONSE DIRECTE AU DÉFAUT DU
## CLIENT. Sur le premier rendu, les lignes rouges franchissaient des bras de
## mer de cinq kilomètres SANS RIEN DESSOUS : un train sur l'eau. Les ouvrages
## existent maintenant dans le plan ; encore faut-il qu'on les VOIE. Une bande
## sombre de quatre cases, posée sous les réseaux, et le pont se lit comme un
## pont au lieu d'un trait rouge qui traverse la mer.
const C_TABLIER := Color("#5b5f66")

## [réseau, couleur, épaisseur en cases, longueur du tiret (0 = trait plein)].
## ⚠ LE POINTILLÉ DU MÉTRO N'EST PAS UNE COQUETTERIE : c'est la seule chose qui
## dise, sur une carte, qu'une ligne est SOUTERRAINE. Sans lui, le métro qui
## traverse un bras de mer se lit comme un train posé sur l'eau.
const RESEAUX := [
	["ferry", C_FERRY, 2, 9],
	["bus", C_BUS, 1, 0],
	["tram", C_TRAM, 2, 0],
	["metro", C_METRO, 2, 5],
	["train2", C_TRAIN2, 2, 0],
	["train", C_TRAIN, 3, 0],
]
## [classe de voirie, couleur, épaisseur, tiret].
const VOIRIES := [
	["cotier", C_COTIER, 1, 3],
	["locale", C_LOCALE, 1, 0],
	["secondaire", C_SECONDAIRE, 2, 0],
	["primaire", C_PRIMAIRE, 3, 0],
]

## Les emprises des tunnels, remplies à chaque image. ⚠ Une ligne qui passe
## dessus doit se dessiner EN POINTILLÉ, comme le métro et pour la même raison :
## c'est la seule convention qui dise, sur une carte, « cette voie passe
## dessous ». Un trait plein au-dessus d'un bras de mer, c'est un train qui roule
## sur l'eau — le reproche exact du client.
var _tunnels: Array = []

func _sous_terre(c: Vector2i) -> bool:
	for r in _tunnels:
		if (r as Rect2i).has_point(c): return true
	return false

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_args():
		if a.begins_with("--" + nom + "="):
			return a.trim_prefix("--" + nom + "=")
	return defaut

func _init() -> void:
	var graine := int(_arg("graine", "1"))
	var t0 := Time.get_ticks_msec()
	var plan := PLAN.batir(graine)
	var ctx := PLAN.contexte(plan)
	print("plan bâti en %d ms (graine %d)" % [Time.get_ticks_msec() - t0, graine])

	# LE PLAN SUR DISQUE. C'est le chiffre qui justifie toute l'architecture :
	# s'il se compte en mégaoctets, on n'a rien gagné sur le fichier unique.
	var chemin_plan := _arg("plan", "cartes/aurones-plan.json")
	if not chemin_plan.begins_with("res://"): chemin_plan = "res://" + chemin_plan
	PLAN.enregistrer(plan, chemin_plan)
	var texte := JSON.stringify(plan)
	print("plan : %d octets (%.1f Ko) — %s" % [texte.length(),
		float(texte.length()) / 1024.0, chemin_plan])

	# LE TERRAIN DE TOUT L'ARCHIPEL, dans une `Ville2` SANS UN SEUL OBJET. Un
	# million de cases de terrain, c'est dix mégaoctets de tableaux et quelques
	# secondes ; un million de cases de DÉCOR, c'est ce qu'on ne fera jamais. La
	# différence entre les deux est toute l'affaire de ce chantier.
	var t1 := Time.get_ticks_msec()
	var v := Ville2.new(PLAN.TAILLE)
	PLAN.remplir_terrain(plan, ctx, v, Vector2i.ZERO)
	print("terrain (%d x %d) en %d ms" % [PLAN.TAILLE.x, PLAN.TAILLE.y,
		Time.get_ticks_msec() - t1])

	# D'OÙ VIENT LA GÉOGRAPHIE. Si le fichier canonique manque, le plan se bâtit
	# quand même sur le relevé au pixel — mais il faut LE DIRE, sinon on regarde
	# une carte périmée en croyant regarder celle du client.
	var source := "RELEVÉ AU PIXEL — le fichier canonique est absent"
	if FileAccess.file_exists(PLAN.FICHIER_ARCHIPEL):
		source = "donnees/aurones/archipel_complet.json (canonique)"
	print("géographie : " + source)
	_les_chiffres(plan, v)
	_l_image(plan, v, _arg("image", "/tmp/aurones.png"), int(_arg("echelle", "1")))

	# LA FENÊTRE : la preuve que le remplissage à la demande marche, et ce qu'on
	# donne à `photo_v2.sh` pour voir l'archipel en 3D.
	var json := _arg("json", "")
	if json != "":
		var m: PackedStringArray = _arg("fenetre", "").split(",")
		var f := Rect2i(400, 420, 200, 200)
		if m.size() == 4:
			f = Rect2i(int(m[0]), int(m[1]), int(m[2]), int(m[3]))
		var t2 := Time.get_ticks_msec()
		var fen := PAYS.fenetre(plan, ctx, f, {"nom": "aurones"})
		print("fenêtre %s : %d lots, %d objets, %d routes, %d rails, %d lieux — en %d ms" % [
			f, fen.lots.size(), fen.objets.size(), fen.routes.size(), fen.rail.size(),
			fen.lieux.size(), Time.get_ticks_msec() - t2])
		fen.enregistrer(json if json.begins_with("res://") else "res://" + json)
		print("fenêtre écrite : ", json)
	quit()

# ══════════════════════════════════════════════════════════════════ CHIFFRES

func _les_chiffres(plan: Dictionary, v: Ville2) -> void:
	var n := v.taille.x * v.taille.y
	var terre := 0
	var cote := 0
	var haut := 0.0
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			var k := v.indice(c)
			if v.eau[k] == 1: continue
			terre += 1
			haut = maxf(haut, v.altitude[k])
			for p in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = c + (p as Vector2i)
				if v.dedans(q) and v.eau[v.indice(q)] == 1:
					cote += 1
					break
	print("")
	print("─── L'ARCHIPEL ────────────────────────────────────────────")
	print("terre         : %d cases (%.1f %%) = %.0f km²" % [terre,
		100.0 * float(terre) / float(n), float(terre) * 0.0004])
	print("trait de côte : %d cases = %.0f km" % [cote, float(cote) * 0.02])
	print("point culminant : %.0f m (%d paliers)" % [haut, roundi(haut / Ville2.PALIER)])
	print("masses de terre séparées (≥ 4 cases) : %d — le plan en dessine %d" % [
		_composantes(v), (plan["iles"] as Array).size()])
	# ⚠ LE DIAMÈTRE DE L'ÎLE CENTRALE EST UN POINT À TENIR : le client a écrit
	# « 5,5 KM DE DIAMÈTRE » en gros sur sa carte de détail. On le MESURE sur le
	# terrain rendu, pas sur la table de constantes — c'est le bruit de côte qui
	# décide du dernier mot, et il peut en manger trois cents mètres.
	# ⚠ ON MESURE LA BANDE DE TERRE QUI CONTIENT LE CENTRE, PAS TOUTE LA RANGÉE.
	# Le parallèle de la Gare Centrale traverse aussi l'Île de l'Ouest : compter
	# toutes les cases de terre de la rangée ajoutait trois kilomètres à l'Île
	# Centrale et aurait fait croire que le rayon canonique n'était pas tenu.
	var c0 := PLAN.centre_ile(plan, PLAN.CENTRALE)
	var largeur := 0
	if v.dedans(c0) and v.eau[v.indice(c0)] == 0:
		largeur = 1
		for s in [-1, 1]:
			for pas in range(1, v.taille.x):
				var q := Vector2i(c0.x + s * pas, c0.y)
				if not v.dedans(q) or v.eau[v.indice(q)] == 1: break
				largeur += 1
	print("Île Centrale, largeur sur son parallèle : %d cases = %.2f km" % [largeur,
		float(largeur) * 0.02])

	print("")
	print("─── LES RÉSEAUX ───────────────────────────────────────────")
	var longueurs: Dictionary = {}
	var compte: Dictionary = {}
	for l in plan["lignes"]:
		var f: Dictionary = l
		var r := String(f["reseau"])
		longueurs[r] = float(longueurs.get(r, 0.0)) + _longueur(f["points"])
		compte[r] = int(compte.get(r, 0)) + 1
	for cl in ["train", "train2", "metro", "tram", "bus", "ferry"]:
		print("  %-9s %2d lignes  %6.0f cases = %5.1f km" % [cl, int(compte.get(cl, 0)),
			float(longueurs.get(cl, 0.0)), float(longueurs.get(cl, 0.0)) * 0.02])
	var voirie: Dictionary = {}
	var nb_v: Dictionary = {}
	for r2 in plan["routes"]:
		var f2: Dictionary = r2
		var cl2 := String(f2.get("classe", "locale"))
		voirie[cl2] = float(voirie.get(cl2, 0.0)) + _longueur(f2["points"])
		nb_v[cl2] = int(nb_v.get(cl2, 0)) + 1
	for cl3 in ["primaire", "secondaire", "locale", "cotier"]:
		print("  %-9s %2d voies   %6.0f cases = %5.1f km" % [cl3, int(nb_v.get(cl3, 0)),
			float(voirie.get(cl3, 0.0)), float(voirie.get(cl3, 0.0)) * 0.02])
	var tunnels := 0
	var rails := 0
	var long_pont := 0.0
	for p2 in plan["ponts"]:
		var fp: Dictionary = p2
		if bool(fp.get("tunnel", false)): tunnels += 1
		if String(fp.get("g", "")) == "rail": rails += 1
		var da := PLAN.case_de(fp["de"])
		var db := PLAN.case_de(fp["vers"])
		long_pont += float((db - da).abs().x + (db - da).abs().y)
	print("  ouvrages  %d, dont %d tunnels et %d ferroviaires — %.1f km au total" % [
		(plan["ponts"] as Array).size(), tunnels, rails, long_pont * 0.02])
	print("  détroits creusés sous les ouvrages : %d" % (plan["detroits"] as Array).size())

	print("")
	print("─── LES STATIONS ──────────────────────────────────────────")
	var par_reseau: Dictionary = {}
	var nommees: Array = []
	for s in plan["stations"]:
		var f3: Dictionary = s
		var r3 := String(f3["reseau"])
		par_reseau[r3] = int(par_reseau.get(r3, 0)) + 1
		if bool(f3.get("principale", false)): nommees.append(f3)
	print("  total %d, dont %d nommées" % [(plan["stations"] as Array).size(),
		nommees.size()])
	print("  par réseau : %s" % str(par_reseau))
	for s2 in nommees:
		var f4: Dictionary = s2
		var c := PLAN.case_de(f4["c"])
		print("    %-24s case %4d, %4d   (%.2f km, %.2f km)" % [String(f4["nom"]),
			c.x, c.y, float(c.x) * 0.02, float(c.y) * 0.02])

	# ⚠⚠ LE CONTRÔLE QUI COMPTE LE PLUS, ET IL TIENT EN SIX LIGNES : UNE STATION
	# EN MER. Le fichier du client PLACE les gares ; c'est nous qui dessinons la
	# côte autour, avec un bruit qui déplace le trait de quinze cases. Une gare
	# tombée à l'eau ne se voit PAS sur une image de mille pixels — elle se
	# découvre trois semaines plus tard, quand quelqu'un va la chercher en 3D.
	# `_ile_depuis` donne son propre lobe à chaque station éloignée pour que ça
	# n'arrive pas ; cette ligne-ci vérifie que ça a marché. ZÉRO ATTENDU.
	var noyees: Array = []
	for s3 in plan["stations"]:
		var f5: Dictionary = s3
		var c2 := PLAN.case_de(f5["c"])
		if not v.dedans(c2): continue
		if String(f5.get("reseau", "")) == "ferry": continue   ## un embarcadère EST en mer
		if v.eau[v.indice(c2)] == 1: noyees.append(String(f5["nom"]))
	print("  ⚠ stations en mer : %d %s" % [noyees.size(),
		"" if noyees.is_empty() else str(noyees)])
	print("")

func _longueur(points: Array) -> float:
	var l := 0.0
	for k in range(1, points.size()):
		var a := PLAN.case_de(points[k - 1])
		var b := PLAN.case_de(points[k])
		l += float((b - a).abs().x + (b - a).abs().y)
	return l

## LES MASSES DE TERRE SÉPARÉES — une propagation en largeur sur le million de
## cases. C'est le seul chiffre qui dise si l'archipel EN EST un : le plan
## promet onze îles, le bruit de côte en coupe, en fusionne et en fabrique, et
## seul ce compte-là dit ce qu'il en reste. On ignore les bouts de moins de
## quatre cases : un rocher n'est pas une île.
func _composantes(v: Ville2) -> int:
	var n := v.taille.x * v.taille.y
	var vu := PackedByteArray()
	vu.resize(n)
	vu.fill(0)
	var trouvees := 0
	var file := PackedInt32Array()
	for depart in n:
		if vu[depart] == 1 or v.eau[depart] == 1: continue
		file.clear()
		file.append(depart)
		vu[depart] = 1
		var taille := 0
		var tete := 0
		while tete < file.size():
			var k: int = file[tete]
			tete += 1
			taille += 1
			var i := k % v.taille.x
			var j := k / v.taille.x
			for p in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(i, j) + (p as Vector2i)
				if not v.dedans(q): continue
				var kq := v.indice(q)
				if vu[kq] == 1 or v.eau[kq] == 1: continue
				vu[kq] = 1
				file.append(kq)
		if taille >= 4: trouvees += 1
	return trouvees

# ══════════════════════════════════════════════════════════════════ L'IMAGE

## L'IMAGE DE L'ARCHIPEL. L'ordre de dessin est celui de la LECTURE, et il n'est
## pas négociable : le sol, puis la voirie du plus fin au plus large, puis les
## cinq réseaux du plus fin au plus structurant, puis les stations. Un train
## sous une rue ne se voit pas ; une rue sous un train, si — et c'est le train
## qu'on veut voir, parce que c'est lui qui explique l'archipel.
##
## `echelle` : combien de pixels par case. À 1 on a l'image demandée (1000 ×
## 1000, un pixel par case) ; à 2 on lit les noms de rues du damier portuaire.
func _l_image(plan: Dictionary, v: Ville2, sortie: String, echelle: int) -> void:
	var e := clampi(echelle, 1, 4)
	var t0 := Time.get_ticks_msec()
	var img := Image.create(v.taille.x * e, v.taille.y * e, false, Image.FORMAT_RGB8)
	# 1. LE SOL, avec son ombrage.
	for j in v.taille.y:
		for i in v.taille.x:
			var c := _teinte(v, Vector2i(i, j))
			for dj in e:
				for di in e:
					img.set_pixel(i * e + di, j * e + dj, c)
	# 2. LA VOIRIE.
	for reg in VOIRIES:
		var f: Array = reg
		for r in plan["routes"]:
			var fr: Dictionary = r
			if String(fr.get("classe", "locale")) != String(f[0]): continue
			_tracer(img, fr["points"], f[1], int(f[2]), int(f[3]), e)
	# 3. LES TABLIERS DES PONTS, SOUS LES RÉSEAUX. Les tunnels n'en ont pas —
	#    ils passent dessous, et c'est leur tracé qui se dessinera en pointillé.
	_tunnels.clear()
	for p in plan["ponts"]:
		var fp: Dictionary = p
		var da := PLAN.case_de(fp["de"])
		var db := PLAN.case_de(fp["vers"])
		if bool(fp.get("tunnel", false)):
			_tunnels.append(Rect2i(Vector2i(mini(da.x, db.x), mini(da.y, db.y)),
				Vector2i(absi(db.x - da.x) + 1, absi(db.y - da.y) + 1)).grow(3))
			continue
		_tracer(img, [[da.x, da.y], [db.x, db.y]], C_TABLIER, 4, 0, e)
	# 4. LES CINQ RÉSEAUX DE TRANSPORT.
	for reg2 in RESEAUX:
		var f2: Array = reg2
		for l in plan["lignes"]:
			var fl: Dictionary = l
			if String(fl["reseau"]) != String(f2[0]): continue
			_tracer(img, fl["points"], f2[1], int(f2[2]), int(f2[3]), e)
	# 5. LES STATIONS. Carré noir pour tout le monde — c'est le symbole du
	#    client — et un halo blanc pour les quinze nommées, qui doivent se
	#    trouver du premier coup d'œil sur une image de mille pixels.
	for s in plan["stations"]:
		var fs: Dictionary = s
		var c2 := PLAN.case_de(fs["c"])
		if bool(fs.get("principale", false)):
			_carre(img, c2, 5, C_HALO, e)
			_carre(img, c2, 3, C_STATION, e)
		else:
			_carre(img, c2, 1, C_STATION, e)
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	img.save_png(sortie)
	print("image %s (%d x %d, %d px/case) en %d ms" % [sortie, img.get_width(),
		img.get_height(), e, Time.get_ticks_msec() - t0])
	print("légende : train rouge · train secondaire orange · métro bleu pointillé ·")
	print("          tram vert · bus jaune · voirie primaire orangée, secondaire")
	print("          jaune pâle, locale grise, chemin côtier pointillé beige")

## LA TEINTE D'UNE CASE, RELIEF COMPRIS.
##
## ⚠ L'OMBRAGE EST CE QUI FAIT QU'ON VOIT LE RELIEF SUR UNE CARTE À PLAT. Sans
## lui, un mont de cent mètres et une plaine se distinguent par une nuance de
## vert que personne ne lit. On éclaire du nord-ouest, comme toutes les cartes
## depuis deux siècles : la pente qui regarde la lumière s'éclaircit, celle qui
## lui tourne le dos s'assombrit, et la montagne SORT de la feuille.
func _teinte(v: Ville2, c: Vector2i) -> Color:
	var k := v.indice(c)
	var y := v.altitude[k]
	if v.eau[k] == 1:
		var p := clampf(-y / 11.0, 0.0, 1.0)
		var m := C_COTE.lerp(C_LARGE, p)
		# Le liseré d'écume : une case d'eau qui touche la terre. C'est ce
		# détail-là qui donne son trait net à une côte, sur la carte du client
		# comme sur les cartes marines.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + (d as Vector2i)
			if v.dedans(q) and v.eau[v.indice(q)] == 0:
				return C_ECUME
		return m
	var base := C_PRE
	var mat := v.matiere_de(c)
	if mat == Ville2.M_SABLE:
		base = C_SABLE
	elif mat == Ville2.M_TERRE:
		base = C_SABLE.lerp(C_COLLINE, 0.5)
	else:
		var p2 := y / Ville2.PALIER
		if p2 <= 1.0: base = C_PLAINE.lerp(C_PRE, p2)
		elif p2 <= 5.0: base = C_PRE.lerp(C_BOIS, (p2 - 1.0) / 4.0)
		elif p2 <= 12.0: base = C_BOIS.lerp(C_ROCHE, (p2 - 5.0) / 7.0)
		else: base = C_ROCHE.lerp(C_CIME, clampf((p2 - 12.0) / 10.0, 0.0, 1.0))
	# L'ombrage : la différence d'altitude avec les voisines du nord-ouest.
	var nord := v.sol(c + Vector2i(0, -1))
	var ouest := v.sol(c + Vector2i(-1, 0))
	var pente := ((nord - y) + (ouest - y)) * 0.5 / Ville2.PALIER
	var f := clampf(1.0 + pente * 0.22, 0.62, 1.32)
	return Color(clampf(base.r * f, 0.0, 1.0), clampf(base.g * f, 0.0, 1.0),
		clampf(base.b * f, 0.0, 1.0))

## Trace une polyligne AXIALE. `epaisseur` en cases, `tiret` en cases (0 : trait
## plein). Le compteur de tirets court d'un segment à l'autre : sinon chaque
## coude relancerait le motif et le pointillé se mettrait à bégayer dans les
## virages, ce qui saute aux yeux sur un anneau.
func _tracer(img: Image, points: Array, teinte: Color, epaisseur: int, tiret: int,
		e: int) -> void:
	var pas_total := 0
	for k in range(1, points.size()):
		var a := PLAN.case_de(points[k - 1])
		var b := PLAN.case_de(points[k])
		if a.x != b.x and a.y != b.y: continue
		var pas := (b - a).sign()
		var c := a
		for _m in (b - a).abs().x + (b - a).abs().y + 1:
			pas_total += 1
			var motif := tiret
			# Au-dessus d'un tunnel, le trait devient pointillé quoi qu'il soit.
			if motif <= 0 and _sous_terre(c): motif = 4
			var visible := motif <= 0 or (pas_total / motif) % 2 == 0
			if visible: _carre(img, c, epaisseur, teinte, e)
			if c == b: break
			c += pas

## Un carré de `cote` cases centré sur une case, en pixels.
func _carre(img: Image, c: Vector2i, cote: int, teinte: Color, e: int) -> void:
	var r := cote / 2
	for dj in range(-r, cote - r):
		for di in range(-r, cote - r):
			var q := c + Vector2i(di, dj)
			if q.x < 0 or q.y < 0 or q.x >= PLAN.TAILLE.x or q.y >= PLAN.TAILLE.y: continue
			for pj in e:
				for pi in e:
					img.set_pixel(q.x * e + pi, q.y * e + pj, teinte)
