extends RefCounted
## UN VRAI PARC, AU KIT NATURE — la brique commune du parc du centre et du bois
## du campus.
##
## ⚠ UNE PELOUSE AVEC TROIS ARBRES N'EST PAS UN PARC, C'EST UN TERRAIN VAGUE.
## Le client le dit pour deux témoins le même jour : « tu dois faire un vrai
## parc au centre avec Kenney nature » et « tu dois faire un Parc / Forêt » au
## campus. Ce qui distingue un parc d'un espace vert, vu d'en haut, ce sont
## QUATRE choses, et il les faut toutes :
##
## 1. UNE LISIÈRE. Les arbres sont serrés au bord et clairsemés au milieu. Un
##    semis uniforme fait un verger, pas un bois.
## 2. DES ALLÉES QUI MÈNENT QUELQUE PART. Elles relient les entrées entre elles
##    et passent par le centre. Une allée qui tourne en rond ne se lit pas.
##    ⚠ On les PEINT en terre battue, on ne les pave pas de tuiles : les tuiles
##    de chemin du kit sont à l'échelle de la case et ne se raccordent qu'à ce
##    pas-là — le client a déjà refusé une allée dont « aucune flèche ne se
##    suit » (12/09). Une bande de terre n'a pas d'orientation, donc pas de
##    raccord à rater.
## 3. UNE PIÈCE D'EAU. C'est le point de fuite du regard ; sans elle, le parc
##    est une texture. On la fait en surface colorée plutôt qu'en vraie eau :
##    creuser de l'eau dans un terrain plat ouvrirait la nappe du témoin.
## 4. DU MOBILIER SUR LES ALLÉES : bancs, lampadaires, corbeilles. C'est ce qui
##    dit que le parc est fréquenté, donc que c'est un parc.

const CASE := Ville2.CASE

## ⚠ TOUT LE KIT NATURE, ET PAS SIX MODÈLES (« le parc et le lac manquent de
## nature, utilise TOUT le kit Kenney nature », client, 14/09).
##
## Un parc fait de six essences répétées se lit comme un semis : l'œil
## reconnaît le motif avant de reconnaître le bois. Le kit nature en a
## QUARANTE — trois familles de feuillus en trois saisons, dix pins, des
## cactus, des palmiers — plus des dizaines de rochers, souches, troncs,
## champignons et fleurs. On les prend TOUS, et les hauteurs sont EN MÈTRES
## pour que l'échelle ne dépende pas de la façon dont le modèle a été dessiné.
##
## Chaque entrée : le modèle, et sa hauteur en mètres.
const FEUILLUS := [
	["nature/tree_default", 9.0], ["nature/tree_default_dark", 9.0],
	["nature/tree_default_fall", 9.0], ["nature/tree_oak", 11.0],
	["nature/tree_oak_dark", 11.0], ["nature/tree_oak_fall", 11.0],
	["nature/tree_detailed", 10.0], ["nature/tree_detailed_dark", 10.0],
	["nature/tree_detailed_fall", 10.0], ["nature/tree_fat", 8.5],
	["nature/tree_fat_darkh", 8.5], ["nature/tree_fat_fall", 8.5],
	["nature/tree_tall", 13.0], ["nature/tree_tall_dark", 13.0],
	["nature/tree_tall_fall", 13.0], ["nature/tree_thin", 11.0],
	["nature/tree_thin_dark", 11.0], ["nature/tree_thin_fall", 11.0],
	["nature/tree_plateau", 9.5], ["nature/tree_plateau_dark", 9.5],
	["nature/tree_plateau_fall", 9.5], ["nature/tree_blocks", 9.0],
	["nature/tree_blocks_dark", 9.0], ["nature/tree_blocks_fall", 9.0],
	["nature/tree_simple", 8.0], ["nature/tree_simple_dark", 8.0],
	["nature/tree_simple_fall", 8.0], ["nature/tree_small", 5.5],
	["nature/tree_small_dark", 5.5], ["nature/tree_small_fall", 5.5],
	["nature/tree_cone", 10.0], ["nature/tree_cone_dark", 10.0],
	["nature/tree_cone_fall", 10.0],
]
const CONIFERES := [
	["nature/tree_pineTallA", 16.0], ["nature/tree_pineTallB", 16.0],
	["nature/tree_pineTallC", 17.0], ["nature/tree_pineTallD", 15.0],
	["nature/tree_pineTallA_detailed", 16.5], ["nature/tree_pineTallB_detailed", 16.5],
	["nature/tree_pineTallC_detailed", 17.5], ["nature/tree_pineTallD_detailed", 15.5],
	["nature/tree_pineDefaultA", 12.0], ["nature/tree_pineDefaultB", 12.0],
	["nature/tree_pineRoundA", 11.0], ["nature/tree_pineRoundB", 11.0],
	["nature/tree_pineRoundC", 10.0], ["nature/tree_pineRoundD", 10.0],
	["nature/tree_pineRoundE", 12.5], ["nature/tree_pineRoundF", 12.5],
	["nature/tree_pineSmallA", 6.0], ["nature/tree_pineSmallB", 6.0],
	["nature/tree_pineSmallC", 5.0], ["nature/tree_pineSmallD", 5.0],
	["nature/tree_pineGroundA", 3.2], ["nature/tree_pineGroundB", 3.2],
]
## LE SOUS-BOIS : buissons, fleurs, champignons, souches, troncs, pierres. Ce
## sont eux qui font le SOL du bois ; sans eux, les arbres poussent sur un
## billard vert.
const SOUS_BOIS := [
	["nature/plant_bush", 1.1], ["nature/plant_bushDetailed", 1.2],
	["nature/plant_bushLarge", 1.8], ["nature/plant_bushLargeTriangle", 1.9],
	["nature/plant_bushSmall", 0.7], ["nature/plant_bushTriangle", 1.0],
	["nature/plant_flatShort", 0.5], ["nature/plant_flatTall", 0.9],
	["nature/grass", 0.45], ["nature/grass_large", 0.7],
	["nature/grass_leafs", 0.5], ["nature/grass_leafsLarge", 0.8],
	["nature/flower_purpleA", 0.45], ["nature/flower_purpleB", 0.45],
	["nature/flower_purpleC", 0.45], ["nature/flower_redA", 0.45],
	["nature/flower_redB", 0.45], ["nature/flower_redC", 0.45],
	["nature/flower_yellowA", 0.45], ["nature/flower_yellowB", 0.45],
	["nature/flower_yellowC", 0.45],
	["nature/mushroom_red", 0.35], ["nature/mushroom_redGroup", 0.4],
	["nature/mushroom_redTall", 0.6], ["nature/mushroom_tan", 0.35],
	["nature/mushroom_tanGroup", 0.4], ["nature/mushroom_tanTall", 0.6],
	["nature/stump_old", 0.8], ["nature/stump_oldTall", 1.6],
	["nature/stump_round", 0.6], ["nature/stump_roundDetailed", 0.65],
	["nature/stump_square", 0.6], ["nature/stump_squareDetailed", 0.65],
	["nature/stump_squareDetailedWide", 0.7],
	["nature/log", 0.7], ["nature/log_large", 1.1],
	["nature/log_stack", 1.0], ["nature/log_stackLarge", 1.4],
	["nature/rock_smallA", 0.55], ["nature/rock_smallB", 0.5],
	["nature/rock_smallC", 0.5], ["nature/rock_smallD", 0.45],
	["nature/rock_smallE", 0.5], ["nature/rock_smallF", 0.55],
	["nature/rock_smallG", 0.5], ["nature/rock_smallH", 0.45],
	["nature/rock_smallI", 0.5],
	["nature/rock_smallFlatA", 0.3], ["nature/rock_smallFlatB", 0.3],
	["nature/rock_smallFlatC", 0.3],
	["nature/stone_smallA", 0.5], ["nature/stone_smallB", 0.45],
	["nature/stone_smallC", 0.5], ["nature/stone_smallD", 0.45],
	["nature/stone_smallE", 0.5], ["nature/stone_smallF", 0.5],
	["nature/stone_smallFlatA", 0.3], ["nature/stone_smallFlatB", 0.3],
	["nature/stone_smallFlatC", 0.3],
	["nature/pot_small", 0.6], ["nature/pot_large", 1.0],
]
## LES BLOCS ERRATIQUES : les gros rochers qu'on pose au compte-gouttes et qui
## donnent leur relief au bois. Un parc entièrement plat n'a pas de repères.
const BLOCS := [
	["nature/rock_largeA", 3.2], ["nature/rock_largeB", 3.0],
	["nature/rock_largeC", 2.6], ["nature/rock_largeD", 2.8],
	["nature/rock_largeE", 3.4], ["nature/rock_largeF", 2.4],
	["nature/rock_tallA", 4.2], ["nature/rock_tallB", 4.6],
	["nature/rock_tallC", 3.8], ["nature/rock_tallD", 4.0],
	["nature/rock_tallE", 4.4], ["nature/rock_tallF", 3.6],
	["nature/rock_tallG", 4.8], ["nature/rock_tallH", 4.1],
	["nature/rock_tallI", 3.9], ["nature/rock_tallJ", 4.3],
	["nature/stone_largeA", 3.0], ["nature/stone_largeB", 2.8],
	["nature/stone_largeC", 2.6], ["nature/stone_largeD", 2.9],
	["nature/stone_largeE", 3.2], ["nature/stone_largeF", 2.4],
	["nature/stone_tallA", 4.0], ["nature/stone_tallB", 4.4],
	["nature/stone_tallC", 3.7], ["nature/stone_tallD", 3.9],
	["nature/stone_tallE", 4.2], ["nature/stone_tallF", 3.5],
]
## LA RIVE : ce qui pousse les pieds dans l'eau.
const RIVE := [
	["nature/grass_leafsLarge", 1.1], ["nature/plant_bushDetailed", 1.3],
	["nature/plant_flatTall", 1.0], ["nature/grass_large", 0.9],
	["nature/flower_yellowB", 0.5], ["nature/flower_purpleA", 0.5],
	["nature/mushroom_tanGroup", 0.4], ["nature/stone_smallFlatA", 0.35],
]
## CE QUI FLOTTE : nénuphars et mousse.
const FLOTTANTS := [
	["nature/lily_large", 0.14], ["nature/lily_small", 0.10],
]

## La couleur d'un plan d'eau de parc : plus verte et plus sombre que la mer.
const EAU_DE_PARC := "#2f6b74"
## La grève : la bande de sable qui borde l'eau et casse le bord net.
const GREVE := "#c9bb8e"
## Le parvis dallé du kiosque et du bassin.
const PARVIS := "#b9b2a4"

## Dessine un parc dans `zone`. `etang` : le rayon du plan d'eau en cases (0 :
## pas d'étang). `entrees` : les cases de bord par lesquelles les allées
## entrent (vide : les quatre milieux de côté).
static func dessiner(v: Ville2, alea: RandomNumberGenerator, zone: Rect2i,
		etang := 2, entrees: Array = [], densite := 1.0) -> int:
	var poses := 0
	# Le plan d'eau ne peut pas être plus grand que le quart du parc : sinon
	# il ne reste plus de parc autour.
	etang = mini(etang, mini(zone.size.x, zone.size.y) / 4)
	# 1. LE SOL. De l'herbe partout, et on efface ce qui traînait.
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			v.poser_matiere(c, Ville2.M_HERBE)

	# 2. LES ALLÉES, peintes en terre battue depuis chaque entrée vers le centre.
	var centre := Vector2i(zone.position.x + zone.size.x / 2, zone.position.y + zone.size.y / 2)
	var portes: Array = entrees
	if portes.is_empty():
		portes = [Vector2i(zone.position.x, centre.y), Vector2i(zone.end.x - 1, centre.y),
			Vector2i(centre.x, zone.position.y), Vector2i(centre.x, zone.end.y - 1)]
	# ⚠ L'ALLÉE SE MET À L'ÉCHELLE DU PARC. Une allée large de deux cases est
	# juste dans un bois de seize cases ; dans un jardin de quatre sur trois,
	# les quatre allées et leur élargissement couvrent TOUT — le premier essai
	# au centre a rendu un carré de terre battue avec trois arbres autour d'une
	# mare. Sous sept cases de côté, l'allée reste d'une case.
	var large_allee: bool = mini(zone.size.x, zone.size.y) >= 7
	var allee: Dictionary = {}
	for p in portes:
		_tracer(v, alea, p, centre, allee, large_allee)
	# Le tour du plan d'eau : seulement dans un GRAND parc. Dans un jardin de
	# quatre cases, cet anneau-là mangeait le peu de pelouse qui restait.
	if etang > 0 and large_allee:
		for k in 28:
			var a := TAU * float(k) / 28.0
			var c := centre + Vector2i(roundi(cos(a) * float(etang + 2)),
				roundi(sin(a) * float(etang + 2)))
			if zone.has_point(c): _peindre_allee(v, c, allee)

	# 3. LE PLAN D'EAU, au centre.
	#
	# ⚠ UN LAC N'EST PAS UN RECTANGLE (« le lac / parc à améliorer », client,
	# 14/09). Une seule surface colorée se lit comme une piscine : ce qui fait
	# un lac, c'est un CONTOUR IRRÉGULIER et une BERGE. On superpose donc
	# quatre ou cinq nappes d'eau décalées, qui font une tache aux bords
	# cassés ; on borde d'une grève de sable ; et on plante la rive de roseaux.
	var eau_cases: Dictionary = {}
	if etang > 0:
		var cx := (float(centre.x) + 0.5) * CASE
		var cz := (float(centre.y) + 0.5) * CASE
		var rx := float(etang) * 0.82 * CASE
		var rz := float(etang) * 0.72 * CASE
		# ⚠ AUCUNE NAPPE NE DOIT DOMINER LES AUTRES. Premier jet : une grande
		# nappe au centre plus des lobes autour — et le lac restait un carré,
		# parce qu'une union de rectangles dont l'un est le plus grand A LA FORME
		# DU PLUS GRAND. On n'en pose donc AUCUN au centre : sept lobes de taille
		# comparable, posés sur un anneau, d'allongements différents. Leur union
		# a un contour en escalier, et de la hauteur où l'on regarde un quartier,
		# un contour en escalier se lit comme une rive.
		var lobes: Array = []
		for k in 7:
			var a0 := TAU * float(k) / 7.0 + alea.randf_range(-0.25, 0.25)
			var d0 := alea.randf_range(0.34, 0.62)
			lobes.append({
				"x": cx + cos(a0) * rx * d0, "z": cz + sin(a0) * rz * d0,
				"w": rx * alea.randf_range(0.75, 1.45),
				"d": rz * alea.randf_range(0.75, 1.45)})
		# ⚠ ET CHAQUE NAPPE À SA PROPRE HAUTEUR. Sept surfaces planes au même
		# niveau se battent pour le même pixel : le lac se couvrait de rayures.
		# Un centimètre d'écart entre chacune suffit, et ne se voit pas.
		# La grève d'abord : les mêmes lobes, un peu plus larges.
		for k in lobes.size():
			var l: Dictionary = lobes[k]
			v.objets.append({"m": "pelouse", "x": l["x"], "z": l["z"], "r": 0.0, "h": 0.0,
				"w": float(l["w"]) + 11.0, "d": float(l["d"]) + 11.0, "c": GREVE,
				"dy": 0.012 * float(k)})
		# L'eau par-dessus.
		for k in lobes.size():
			var l2: Dictionary = lobes[k]
			v.objets.append({"m": "pelouse", "x": l2["x"], "z": l2["z"], "r": 0.0, "h": 0.0,
				"w": l2["w"], "d": l2["d"], "c": EAU_DE_PARC,
				"dy": 0.15 + 0.012 * float(k)})
		poses += lobes.size() * 2
		# ⚠ ET ON INTERDIT LE SOL SOUS L'EAU. La nappe n'est qu'une surface
		# peinte : la case reste de l'herbe, et toutes les passes de semis —
		# celle-ci comprise — y plantaient des arbres et des rochers AU MILIEU
		# DU LAC. On repasse donc ces cases en sable et on les réserve.
		var bx0 := floori((cx - rx * 1.4) / CASE)
		var bx1 := ceili((cx + rx * 1.4) / CASE)
		var bz0 := floori((cz - rz * 1.4) / CASE)
		var bz1 := ceili((cz + rz * 1.4) / CASE)
		for j in range(bz0, bz1):
			for i in range(bx0, bx1):
				var ce := Vector2i(i, j)
				if not v.dedans(ce): continue
				var dx := ((float(i) + 0.5) * CASE - cx) / maxf(rx, 0.01)
				var dz := ((float(j) + 0.5) * CASE - cz) / maxf(rz, 0.01)
				if dx * dx + dz * dz > 1.6: continue
				v.poser_matiere(ce, Ville2.M_SABLE)
				for b in 2:
					for a in 2:
						v.demi_prises[Vector2i(i * 2 + a, j * 2 + b)] = true
				eau_cases[ce] = true
		# Les nénuphars sur l'eau, les rochers et les roseaux sur la rive.
		for k in 14:
			var a := TAU * float(k) / 14.0 + alea.randf() * 0.3
			for _n in 3:
				var fl: Array = FLOTTANTS[alea.randi() % FLOTTANTS.size()]
				var an := a + alea.randf_range(-0.25, 0.25)
				v.ajouter_objet(String(fl[0]),
					cx + cos(an) * rx * alea.randf_range(0.15, 0.85),
					cz + sin(an) * rz * alea.randf_range(0.15, 0.85), alea.randf() * TAU,
					float(fl[1]))
			var bl: Array = SOUS_BOIS[alea.randi() % SOUS_BOIS.size()]
			v.ajouter_objet(String(bl[0]), cx + cos(a) * rx * 1.28, cz + sin(a) * rz * 1.28,
				alea.randf() * TAU, float(bl[1]) * alea.randf_range(0.9, 1.4))
			for _r in 6:
				var ar := a + alea.randf_range(-0.22, 0.22)
				var rv: Array = RIVE[alea.randi() % RIVE.size()]
				v.ajouter_objet(String(rv[0]),
					cx + cos(ar) * rx * alea.randf_range(1.0, 1.16),
					cz + sin(ar) * rz * alea.randf_range(1.0, 1.16), alea.randf() * TAU,
					float(rv[1]) * alea.randf_range(0.8, 1.5))
			poses += 10
		# LE KIOSQUE À MUSIQUE (lot 4), au bord de l'eau : c'est la pièce qui
		# fait d'un bois un PARC — un lieu où l'on va, pas seulement des arbres.
		if mini(zone.size.x, zone.size.y) >= 8:
			var kx := cx + rx * 1.55
			# Son parvis, sinon le kiosque est posé dans l'herbe.
			v.objets.append({"m": "pelouse", "x": kx, "z": cz, "r": 0.0, "h": 0.0,
				"w": 26.0, "d": 26.0, "c": PARVIS, "dy": 0.02})
			v.ajouter_objet("pxl/kiosque-a-musique", kx, cz, PI)
			for k in 8:
				var ak := TAU * float(k) / 8.0
				v.ajouter_objet("banc", kx + cos(ak) * 10.5, cz + sin(ak) * 10.5, ak + PI * 0.5)
				if k % 2 == 0:
					v.ajouter_objet("lampadaire_parc", kx + cos(ak) * 14.0,
						cz + sin(ak) * 14.0, 0.0)
			# Le bassin d'agrément, de l'autre côté du lac.
			var bx := cx - rx * 1.55
			v.objets.append({"m": "pelouse", "x": bx, "z": cz, "r": 0.0, "h": 0.0,
				"w": 24.0, "d": 20.0, "c": PARVIS, "dy": 0.02})
			v.ajouter_objet("pxl/bassin-de-parc", bx, cz, 0.0)
			for k in 4:
				v.ajouter_objet("banc", bx, cz - 8.0 + float(k) * 5.4, PI * 0.5)
			poses += 20
		# LES BANCS DE LA RIVE : on s'assoit face à l'eau, c'est à ça que sert un
		# lac dans un parc.
		for k in 10:
			var ab := TAU * float(k) / 10.0 + 0.31
			v.ajouter_objet("banc", cx + cos(ab) * rx * 1.34, cz + sin(ab) * rz * 1.34,
				ab + PI * 0.5)
			if k % 3 == 0:
				v.ajouter_objet("poubelle", cx + cos(ab + 0.1) * rx * 1.42,
					cz + sin(ab + 0.1) * rz * 1.42, 0.0)
		poses += 14

	# 4. LES ARBRES. Serrés en lisière, clairsemés au milieu, jamais sur une
	# allée ni sur l'eau.
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): continue
			if allee.has(c): continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0: continue
			if eau_cases.has(c): continue
			# La lisière : à deux cases du bord, on double la densité.
			var au_bord: bool = mini(mini(i - zone.position.x, zone.end.x - 1 - i),
				mini(j - zone.position.y, zone.end.y - 1 - j)) <= 1
			# ⚠ DEUX TENTATIVES AU MOINS PARTOUT. Une seule à l'intérieur, et un
			# petit parc ressortait presque nu : sur douze cases dont la moitié
			# en allée, « une chance sur trois par case » ne pose que deux
			# arbres. Un parc, ça se remplit.
			var combien := (4 if au_bord else 3)
			for _k in combien:
				if alea.randf() > 0.80 * densite: continue
				var sac: Array = CONIFERES if (au_bord or alea.randf() < 0.25) else FEUILLUS
				var e: Array = sac[alea.randi() % sac.size()]
				v.ajouter_objet(String(e[0]), (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					float(e[1]) * alea.randf_range(0.82, 1.22))
				poses += 1
			# LE SOUS-BOIS, qui remplit le pied des arbres. C'est lui qu'on voit à
			# hauteur d'homme, donc c'est lui qui fait la différence entre un bois
			# et un verger : cinq tentatives par case, pas deux.
			for _k in 5:
				if alea.randf() > 0.62 * densite: continue
				var b: Array = SOUS_BOIS[alea.randi() % SOUS_BOIS.size()]
				v.ajouter_objet(String(b[0]), (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					float(b[1]) * alea.randf_range(0.8, 1.3))
				poses += 1
			# Un bloc erratique de loin en loin : le relief du bois.
			if alea.randf() < 0.06 * densite:
				var g: Array = BLOCS[alea.randi() % BLOCS.size()]
				v.ajouter_objet(String(g[0]), (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					float(g[1]) * alea.randf_range(0.85, 1.3))
				poses += 1

	# 5. LE MOBILIER, le long des allées seulement.
	var n := 0
	for c in allee:
		n += 1
		if n % 4 == 0:
			v.ajouter_objet("banc", (float(c.x) + 0.5) * CASE, (float(c.y) + 0.2) * CASE,
				alea.randf() * TAU)
			poses += 1
		if n % 6 == 0:
			v.ajouter_objet("lampadaire_parc", (float(c.x) + 0.15) * CASE,
				(float(c.y) + 0.85) * CASE, 0.0)
			poses += 1
		if n % 11 == 0:
			v.ajouter_objet("poubelle", (float(c.x) + 0.8) * CASE,
				(float(c.y) + 0.8) * CASE, 0.0)
			poses += 1
	v.ajouter_lieu("parc", (float(centre.x) + 0.5) * CASE, (float(centre.y) + 0.5) * CASE,
		{"nom": "Parc"})
	return poses

## Une allée d'un point à l'autre : en L, avec le coude tiré au hasard, et
## deux cases de large par endroits — une allée d'un seul pixel se lit comme
## une rayure.
static func _tracer(v: Ville2, alea: RandomNumberGenerator, de: Vector2i, vers: Vector2i,
		allee: Dictionary, large := true) -> void:
	var coude := Vector2i(vers.x, de.y) if alea.randf() < 0.5 else Vector2i(de.x, vers.y)
	for etape in [[de, coude], [coude, vers]]:
		var a: Vector2i = etape[0]
		var b: Vector2i = etape[1]
		var d := (b - a).sign()
		var c := a
		var garde := 0
		while c != b and garde < 200:
			_peindre_allee(v, c, allee)
			# ⚠ L'ÉLARGISSEMENT EST CONTINU, PAS UNE CASE SUR TROIS. Essayé
			# d'abord en alternance, pour « casser la ligne » : vu d'en haut,
			# ça ne casse rien, ça fabrique un damier — l'allée ressemblait à
			# un escalier de cases brunes. Une allée large de deux cases sur
			# toute sa longueur se lit comme une allée.
			if large: _peindre_allee(v, c + Vector2i(d.y, d.x), allee)
			c += d
			garde += 1
		_peindre_allee(v, b, allee)

static func _peindre_allee(v: Ville2, c: Vector2i, allee: Dictionary) -> void:
	if not v.dedans(c) or not v.terre(c): return
	if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): return
	if v.lot_sur(c) >= 0: return
	v.poser_matiere(c, Ville2.M_TERRE)
	allee[c] = true
