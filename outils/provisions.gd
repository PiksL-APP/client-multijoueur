extends SceneTree
## LE BANC DE LA FAIM ET DE LA SOIF.
##
## Ce qu'il doit prouver, dans cet ordre :
##
##   1. le catalogue tient debout — des prix ordonnés, des effets chiffrés, et
##      de quoi combler CHACUNE des deux jauges ;
##   2. le sac compte juste : on ne porte pas plus que ses poches, et on ne
##      doit jamais de sandwichs à personne (pas de compte négatif) ;
##   3. `le_mieux` choisit ce qui COMBLE, pas ce qui remonte le plus — c'est
##      toute la différence entre une touche utile et une touche qui gâche ;
##   4. les supérettes existent dans la ville engendrée, une par secteur, et
##      elles répondent là où la dalle est peinte ;
##   5. les chiffres de la faim donnent des durées jouables.
##
## ⚠ Les jauges elles-mêmes vivent chez le CLIENT (`jeux/carnage.gd`, qui n'a
## pas de `class_name` et ne se charge pas hors scène). Ce banc vérifie donc le
## catalogue, le sac, la ville et l'arithmétique ; la descente des barres se
## juge à l'écran.
##
##   godot --headless -s outils/provisions.gd [-- --code=ESSAI]

## Les constantes de `jeux/carnage.gd`, recopiées ICI À DESSEIN : le fichier
## du jeu ne se charge pas hors scène, et un banc qui ne peut pas lire une
## constante doit au moins dire laquelle il suppose. Si l'une bouge là-bas, le
## chiffre annoncé ci-dessous ne correspondra plus à ce qu'on joue — et c'est
## exactement ce qu'on veut voir.
const FAIM_MAX := 100.0
const DUREE_FAIM := 260.0
const DUREE_SOIF := 200.0
const DEGAT_JEUNE := 2.0
const VIE_MAX := 100.0

var _fautes := 0

func _init() -> void:
	var code := "PROVISIONS"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
	print("── code %s" % code)
	_catalogue()
	_le_sac()
	_le_choix()
	_la_ville(PlanVille.new(code))
	_les_durees()
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

# ------------------------------------------------------------ le catalogue

func _catalogue() -> void:
	print("\n1. LE CATALOGUE")
	var liste: Array = Provisions.CATALOGUE
	_dire(liste.size() >= 6, "%d articles" % liste.size())
	var prix_avant := 0
	var ordonne := true
	for a in liste:
		if int(a["prix"]) < prix_avant:
			ordonne = false
		prix_avant = int(a["prix"])
	# Un menu qui monte en prix se lit de haut en bas : on descend jusqu'à ce
	# qu'on ne puisse plus payer, et on s'arrête. Mélangé, il faut le lire en
	# entier à chaque passage.
	_dire(ordonne, "les prix montent du premier au dernier ($%d → $%d)"
		% [int(liste[0]["prix"]), int(liste[liste.size() - 1]["prix"])])
	var nourrit := false
	var desaltere := false
	var soigne := false
	for a in liste:
		nourrit = nourrit or float(a["faim"]) > 0.0
		desaltere = desaltere or float(a["soif"]) > 0.0
		soigne = soigne or float(a["vie"]) > 0.0
	_dire(nourrit and desaltere and soigne, "on y trouve de quoi manger, boire et se soigner")
	# ⚠ Un article qui donne SOIF est ce qui empêche de tenir la manche entière
	# sur un seul achat : sans lui, six burgers règlent les deux jauges.
	var donne_soif := false
	for a in liste:
		donne_soif = donne_soif or float(a["soif"]) < 0.0
	_dire(donne_soif, "et au moins un article qui donne soif")
	var moins_cher := int(liste[0]["prix"])
	_dire(moins_cher <= 60, "le premier prix est abordable ($%d)" % moins_cher)
	for a in liste:
		var e := Provisions.effet(String(a["cle"]))
		if e == "":
			_dire(false, "%s n'annonce AUCUN effet" % String(a["nom"]))
	_dire(true, "chaque article dit ce qu'il fait (ex. %s : %s)"
		% [String(liste[0]["nom"]).to_lower(), Provisions.effet(String(liste[0]["cle"]))])

# ----------------------------------------------------------------- le sac

func _le_sac() -> void:
	print("\n2. LE SAC COMPTE JUSTE")
	var sac: Dictionary = {}
	_dire(Provisions.compte(sac) == 0, "un sac neuf est vide")
	Provisions.ajouter(sac, "sandwich")
	Provisions.ajouter(sac, "sandwich")
	Provisions.ajouter(sac, "eau")
	_dire(Provisions.compte(sac) == 3, "trois articles, deux lignes : %s" % str(sac))
	_dire(Provisions.retirer(sac, "sandwich"), "on en retire un")
	_dire(int(sac["sandwich"]) == 1, "il en reste un")
	_dire(Provisions.retirer(sac, "sandwich"), "on retire le dernier")
	# ⚠ La ligne DISPARAÎT au lieu de tomber à zéro : sans ça, le tableau de
	# bord affichait « sandwich ×0 » et l'inventaire se remplissait de
	# fantômes au fil de la manche.
	_dire(not sac.has("sandwich"), "et la ligne disparaît au lieu de rester à zéro")
	_dire(not Provisions.retirer(sac, "sandwich"), "en retirer un de plus ne rend rien")
	_dire(Provisions.compte(sac) == 1, "et le compte reste juste (%d)" % Provisions.compte(sac))

# --------------------------------------------------------------- le choix

func _le_choix() -> void:
	print("\n3. `le_mieux` CHOISIT CE QUI COMBLE")
	var sac: Dictionary = {}
	Provisions.ajouter(sac, "burger")
	Provisions.ajouter(sac, "eau")
	# ⚠ LE PIÈGE. Le burger remonte 68 de faim, l'eau 55 de soif : « le plus
	# gros chiffre » prend le burger. Mais à 95 de faim et 10 de soif, le
	# burger ne comble que 5 points — la bouteille en comble 55. C'est ce que
	# le joueur attend de la touche, et ce qu'un simple max ne donne pas.
	_dire(Provisions.le_mieux(sac, 95.0, 10.0, 100.0, FAIM_MAX) == "eau",
		"ventre plein et gorge sèche : c'est la bouteille")
	_dire(Provisions.le_mieux(sac, 10.0, 95.0, 100.0, FAIM_MAX) == "burger",
		"l'inverse : c'est le burger")
	_dire(Provisions.le_mieux(sac, 100.0, 100.0, 100.0, FAIM_MAX) == "",
		"tout au maximum : la touche ne gâche rien")
	var trousse: Dictionary = {}
	Provisions.ajouter(trousse, "trousse")
	Provisions.ajouter(trousse, "barre")
	_dire(Provisions.le_mieux(trousse, 100.0, 100.0, 20.0, FAIM_MAX) == "trousse",
		"à vingt de vie, c'est la trousse de secours")

# --------------------------------------------------------------- la ville

func _la_ville(carte: PlanVille) -> void:
	print("\n4. LES SUPÉRETTES DANS LA VILLE")
	var trouvees: Array = []
	var secteurs := 0
	var sans := 0
	for sy in range(0, PlanVille.LIGNES / PlanVille.SECTEUR):
		for sx in range(0, PlanVille.COLONNES / PlanVille.SECTEUR):
			var centre := Vector2((float(sx) + 0.5) * PlanVille.SECTEUR * PlanVille.PAS,
				(float(sy) + 0.5) * PlanVille.SECTEUR * PlanVille.PAS)
			var liste: Array = carte.lieux_autour(centre, PlanVille.SECTEUR * PlanVille.PAS)["superettes"]
			secteurs += 1
			if liste.is_empty():
				sans += 1
			else:
				trouvees.append(liste[0])
	_dire(trouvees.size() > 0, "%d supérettes sur %d secteurs (%d secteurs sans)"
		% [trouvees.size(), secteurs, sans])
	# Un secteur fait huit pâtés de côté : une supérette y est à moins de deux
	# minutes de marche de partout. Quelques secteurs n'en ont pas — ce sont
	# les secteurs d'eau et de parc, où il n'y a pas de pâté bâtissable.
	_dire(float(sans) / float(secteurs) < 0.25,
		"moins d'un quart des secteurs en manque")

	var sp: Dictionary = trouvees[0]
	var ou: Vector2 = sp["p"]
	_dire(carte.superette_de(ou) == int(sp["id"]), "debout sur la dalle, la boutique répond")
	_dire(carte.superette_de(ou + Vector2(PlanVille.RAYON_SUPERETTE + 40.0, 0.0)) < 0,
		"quarante pixels au-delà de la dalle, plus rien")

	# ⚠ JAMAIS DEUX LIEUX VISITABLES SUR LE MÊME PÂTÉ. Deux portes au même
	# endroit, c'est un `F` qui ne sait plus à qui répondre — et le tirage de
	# `_lieux_du_secteur` les prend dans la même liste de candidats.
	var collision := 0
	var noyees := 0
	for s in trouvees:
		var pate: Vector2i = s["pate"]
		var fiche := carte.lieux_autour(Vector2(s["p"]), PlanVille.SECTEUR * PlanVille.PAS)
		for genre in ["hopitaux", "planques", "garages", "cabines", "repaires", "arenes"]:
			for autre in fiche[genre]:
				if Vector2i(autre["pate"]) == pate:
					collision += 1
		var coin := PlanVille.coin_pate(pate)
		for j in 3:
			for i in 3:
				if carte.eau(coin.x + i, coin.y + j) or carte.sur_le_rail(coin.x + i, coin.y + j):
					noyees += 1
	_dire(collision == 0, "aucune ne partage son pâté avec un autre lieu")
	_dire(noyees == 0, "aucune n'a les pieds dans l'eau ni sur la voie ferrée")

# -------------------------------------------------------------- les durées

func _les_durees() -> void:
	print("\n5. LES DURÉES SONT JOUABLES")
	# ⚠ Les chiffres ci-dessous sont recopiés de `jeux/carnage.gd` (voir
	# l'en-tête) : ce banc dit ce qu'on JOUE si ces constantes n'ont pas bougé.
	_dire(DUREE_SOIF < DUREE_FAIM,
		"la soif descend plus vite que la faim (%d s contre %d s)" % [int(DUREE_SOIF), int(DUREE_FAIM)])
	_dire(DUREE_SOIF >= 150.0 and DUREE_FAIM <= 400.0,
		"une jauge pleine tient entre deux et cinq minutes")
	var survie := VIE_MAX / (DEGAT_JEUNE * 2.0)
	_dire(survie >= 20.0 and survie <= 60.0,
		"les deux jauges à zéro, on tient %d s à pleine vie" % int(survie))
	# Ce qu'un article rend, en secondes de jauge : c'est la vraie unité, et
	# c'est elle qui dit si un prix est juste.
	for cle in ["eau", "sandwich", "burger"]:
		var a := Provisions.fiche(cle)
		var s_faim := float(a["faim"]) / FAIM_MAX * DUREE_FAIM
		var s_soif := float(a["soif"]) / FAIM_MAX * DUREE_SOIF
		print("   %-18s $%-4d = %3d s de faim, %3d s de soif"
			% [String(a["nom"]).to_lower(), int(a["prix"]), int(s_faim), int(s_soif)])
	var eau := Provisions.fiche("eau")
	var secondes := float(eau["soif"]) / FAIM_MAX * DUREE_SOIF
	_dire(secondes >= 60.0, "la bouteille la moins chère achète au moins une minute (%d s)" % int(secondes))
