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

## LES ESSENCES. Feuillus au centre et sur les allées, conifères en lisière :
## c'est la composition d'un parc dessiné, et les deux silhouettes se
## distinguent d'en haut.
const FEUILLUS := ["arbre", "arbre_oak", "arbre_rond", "arbre_plateau", "arbre_automne",
	"arbre_fin"]
const CONIFERES := ["pin", "pin_b", "pin_rond", "sapin", "pin_petit"]
const SOUS_BOIS := ["buisson", "buisson_grand", "buisson_petit", "souche", "tronc",
	"rocher", "rocher_b", "fleurs_rouges", "fleurs_jaunes", "fleurs_violettes",
	"champignon", "champignons", "herbes", "touffe"]

## La couleur d'un plan d'eau de parc : plus verte et plus sombre que la mer.
const EAU_DE_PARC := "#2f6b74"

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

	# 3. LE PLAN D'EAU, au centre, en surface colorée avec ses berges.
	if etang > 0:
		var cx := (float(centre.x) + 0.5) * CASE
		var cz := (float(centre.y) + 0.5) * CASE
		v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0,
			"w": float(etang) * 2.0 * CASE, "d": float(etang) * 1.7 * CASE,
			"c": EAU_DE_PARC})
		poses += 1
		for k in 9:
			var a := TAU * float(k) / 9.0 + alea.randf() * 0.4
			v.ajouter_objet("nenuphar", cx + cos(a) * float(etang) * 0.7 * CASE,
				cz + sin(a) * float(etang) * 0.6 * CASE, alea.randf() * TAU)
			v.ajouter_objet(["rocher", "rocher_b", "pierre_plate"][alea.randi() % 3],
				cx + cos(a) * float(etang) * 1.15 * CASE,
				cz + sin(a) * float(etang) * 1.0 * CASE, alea.randf() * TAU)
			poses += 2

	# 4. LES ARBRES. Serrés en lisière, clairsemés au milieu, jamais sur une
	# allée ni sur l'eau.
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): continue
			if allee.has(c): continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0: continue
			if etang > 0 and (c - centre).length() <= float(etang) + 0.8: continue
			# La lisière : à deux cases du bord, on double la densité.
			var au_bord: bool = mini(mini(i - zone.position.x, zone.end.x - 1 - i),
				mini(j - zone.position.y, zone.end.y - 1 - j)) <= 1
			# ⚠ DEUX TENTATIVES AU MOINS PARTOUT. Une seule à l'intérieur, et un
			# petit parc ressortait presque nu : sur douze cases dont la moitié
			# en allée, « une chance sur trois par case » ne pose que deux
			# arbres. Un parc, ça se remplit.
			var combien := (4 if au_bord else 2)
			for _k in combien:
				if alea.randf() > 0.78 * densite: continue
				var essence: String = (CONIFERES[alea.randi() % CONIFERES.size()] if au_bord \
					else FEUILLUS[alea.randi() % FEUILLUS.size()])
				v.ajouter_objet(essence, (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU)
				poses += 1
			# Le sous-bois, qui remplit le pied des arbres.
			for _k in 2:
				if alea.randf() > 0.5 * densite: continue
				v.ajouter_objet(SOUS_BOIS[alea.randi() % SOUS_BOIS.size()],
					(float(i) + alea.randf()) * CASE, (float(j) + alea.randf()) * CASE,
					alea.randf() * TAU)
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
