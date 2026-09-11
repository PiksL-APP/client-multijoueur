class_name EditeurCarte
extends Ecran
## L'ÉDITEUR DE CARTE 3D.
##
## ⚠ CE QU'IL MANIPULE : le DESSIN ASCII de `jeux/carnage/quartiers.gd`, un
## caractère par case — pas un format à lui. Le premier jet avait son propre
## fichier JSON : il y avait alors deux vérités, celle qu'on dessinait à la
## souris et celle que le jeu bâtissait, et rien ne garantissait qu'elles
## disent la même chose. Ici on peint des caractères dans la grille, on rebâtit
## le quartier avec `Quartiers.batir_fiche` — LA MÊME fonction que le banc de
## photo et que le jeu — et on ressort le bloc GDScript à recoller dans le
## catalogue. L'éditeur et le fichier sont le même objet vu de deux côtés.
##
## LES CINQ DÉCISIONS QUI COMPTENT
##
## 1. On rebâtit à la FIN du geste, pas à chaque case. Bâtir un quartier prend
##    une fraction de seconde ; le faire à chaque case peinte rendait le tracé
##    d'une avenue impossible. Pendant le geste, les cases modifiées sont
##    montrées par des dalles de couleur — instantanées — et le vrai décor
##    arrive au relâchement.
## 2. Les FAUTES sont celles du banc (`Quartiers.fautes`), affichées en rouge
##    sur la case coupable et listées dans le panneau. Un éditeur qui laisse
##    dessiner une rampe au pied d'un carrefour ne sert à rien.
## 3. La grille s'AGRANDIT par les bords. Un quartier qu'on ne peut pas
##    étendre, c'est un quartier qu'on recommence.
## 4. LE GESTE A UNE FORME : libre, ligne, rectangle, rectangle plein, godet,
##    pipette. Une avenue de trente cases peinte case par case, c'est trente
##    occasions de rater la ligne droite — et la ville est faite de lignes
##    droites. La forme est choisie une fois, elle vaut pour le dessin ET pour
##    le relief.
## 5. LE TRAVAIL EN COURS EST GARDÉ (`user://brouillon_<id>.json`, donc dans
##    le navigateur en ligne). Un onglet fermé par erreur ne coûte plus le
##    quartier. La VÉRITÉ reste le catalogue : « Recharger » jette le
##    brouillon et repart du fichier.

const CASE := CarteVille.CASE
const PALIER := CarteVille.PALIER

## Les quatre côtés, pour le godet. En dur plutôt qu'empruntés à `CarteVille` :
## un remplissage n'a pas à dépendre du modèle de carte du jeu.
const COTES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## La palette, dans l'ordre où on s'en sert : le sol, puis ce qui pousse, puis
## ce qui se bâtit — et c'est CET ordre que suivent les touches 1‑9 puis
## Maj+1‑9. La couleur sert à l'aperçu du geste ET à la mini-carte.
const PINCEAUX := [
	["#", "Rue", Color("#7d828c")],
	["=", "Pont", Color("#9aa0a8")],
	["O", "Rond-point", Color("#5f6874")],
	# LES DEUX GROSSES PIÈCES DE VOIE RAPIDE. Elles ne se posent pas comme une
	# rue : un caractère commande une pièce qui déborde sur ses voisines, et
	# l'éditeur ne peut pas le deviner à la souris. La bretelle se pose sur son
	# coin NORD-OUEST et prend 2 x 2 cases ; la rampe se pose sur sa case BASSE
	# et prend la voisine qui est deux paliers plus haut. Toutes deux se
	# tournent toutes seules d'après les rues autour — c'est ce qui les rend
	# posables d'un clic malgré leur taille.
	["(", "Bretelle 2x2", Color("#6b7480")],
	["/", "Rampe douce", Color("#78838f")],
	[".", "Eau", Color("#2b5f7a")],
	["~", "Mouillage", Color("#1f4d63")],
	[",", "Pelouse", Color("#7f9464")],
	[";", "Sable", Color("#d9c9a2")],
	["o", "Esplanade", Color("#b9b6ac")],
	["P", "Parking", Color("#a8a49c")],
	["^", "Arbres", Color("#4f7a3a")],
	["'", "Buissons", Color("#6d8a4a")],
	["X", "Dépôt", Color("#c0784a")],
	["%", "Chantier", Color("#d9a441")],
	["T", "Tour", Color("#3f6f8f")],
	["B", "Bureau", Color("#8fa3b5")],
	["C", "Commerce", Color("#c8553a")],
	["M", "Maison", Color("#e8d8b8")],
	["V", "Vieille", Color("#d29a5e")],
	["H", "Hangar", Color("#7d8a8f")],
	# LES BÂTIMENTS À INTERACTION viennent après les familles de décor : ce sont
	# eux qui font le JEU (l'hôpital soigne, le garage repeint, la cabine donne
	# les missions, la caisse se ramasse), et on ne les pose pas au mètre carré
	# comme un pâté d'immeubles. Leurs couleurs sont volontairement vives : sur
	# la mini-carte d'une ville de soixante mille cases, un service doit se
	# repérer d'un coup d'œil.
	["+", "Hôpital", Color("#e8483f")],
	["F", "Pompiers", Color("#c22f2a")],
	["S", "Supermarché", Color("#3fa64f")],
	["$", "Garage peinture", Color("#8f4fd0")],
	["?", "Cabine", Color("#2f7fd0")],
	["*", "Caisse", Color("#e0b93f")],
]
## ⚠ VINGT-CINQ PINCEAUX NE TIENNENT PAS DANS UNE COLONNE. À dix-neuf, il
## fallait déjà la faire défiler à chaque changement de couleur ; depuis que les
## bâtiments à interaction sont arrivés, les six derniers étaient carrément hors
## de l'écran — on ne peut pas poser un hôpital qu'on ne voit pas. On les range
## donc PAR USAGE, une famille visible à la fois.
##
## Les touches 1-9 et Maj+1-9 continuent de viser la liste ENTIÈRE : choisir un
## pinceau au clavier bascule l'onglet tout seul. Personne n'a à réapprendre ses
## doigts parce que l'affichage a changé.
const FAMILLES_PINCEAUX := [
	["Sol", ".~,;oP"],
	["Voirie", "#=O(/"],
	["Nature", "^'"],
	["Bâti", "TBCMVH"],
	["Activité", "X%"],
	["Services", "+FS$?*"],
]

## Les familles s'écrivent aussi en minuscule : deux bâtiments de même famille
## côte à côte fusionnent en un seul s'ils portent la même lettre.
const FAMILLES := "TBCMVH"
## Ce qui roule : rue, pont, rond-point. La mini-carte les fonce pour que le
## plan de rues se détache des façades.
const CHAUSSEE := "#=O(/"
const TEINTE_VOIE := Color("#3f444d")
## La rampe du relief : du vert du niveau de la mer au rouge des hauteurs. Dix
## crans, parce que la grille en autorise dix — même si la ville n'en use que six.
const RAMPE := [
	Color("#40704f"), Color("#5e8656"), Color("#8c9658"), Color("#b09656"),
	Color("#c48454"), Color("#d67860"), Color("#dd6f74"), Color("#e0708c"),
	Color("#e07aa6"), Color("#e089bf"),
]
## Ce qui n'est PAS de la terre : l'eau nue et le mouillage du port. Une case
## d'eau ne prend pas de palier, et la visée ne s'y pose pas.
const EAUX := ".~"

enum { OUTIL_DESSIN, OUTIL_RELIEF, OUTIL_OBJET }
enum { FORME_LIBRE, FORME_LIGNE, FORME_CADRE, FORME_PLEIN, FORME_GODET, FORME_PIPETTE,
	FORME_SELECTION }

## La forme du geste, son libellé et sa touche. L'ordre est celui des boutons.
const FORMES := [
	[FORME_LIBRE, "Libre", "B"],
	[FORME_LIGNE, "Ligne", "L"],
	[FORME_CADRE, "Cadre", "K"],
	[FORME_PLEIN, "Plein", "J"],
	[FORME_GODET, "Godet", "G"],
	[FORME_PIPETTE, "Pipette", "I"],
	[FORME_SELECTION, "Sélection", "C"],
]

var _id := "pikstown"
var _fiche: Dictionary = {}
var _quartier: Node3D
var _decor: Node3D                      ## les autres quartiers, pour le contexte
var _apercu: Node3D                     ## les dalles du geste en cours
var _marques: Node3D                    ## les blocs rouges des fautes
var _ville: VilleMorcelee               ## le décor, bâti par morceaux
var _maillage: MeshInstance3D           ## le quadrillage posé au sol
var _cadre_selection: MeshInstance3D    ## le rectangle jaune de la sélection
var _nappe: MeshInstance3D              ## le plan du palier courant, en relief
var _curseur: MeshInstance3D
var _camera: Camera3D

var _outil := OUTIL_DESSIN
var _forme := FORME_LIBRE
var _pinceau := "#"
var _minuscule := false
var _palier := 0
var _voir_grille := true
var _relief_relatif := false
## LA SÉLECTION ET LE PRESSE-PAPIER. Une ville de 96 000 cases ne se dessine pas
## deux fois : un pâté réussi, un quai, une place, on veut les reposer ailleurs.
## Le presse-papier garde le PLAN ET LE RELIEF ensemble — copier un quartier
## perché et le recoller à plat en ferait un autre quartier.
var _selection := Rect2i()
var _presse: Dictionary = {}
var _collage := false
var _carte_relief := false
var _dessus := false

var _pivot := Vector3.ZERO
var _distance := 500.0
var _azimut := 0.75
var _inclinaison := 0.55
var _azimut_avant := 0.75
var _inclinaison_avant := 0.55

## ⚠ TROIS CACHES, ET CE NE SONT PAS DES OPTIMISATIONS PRÉMATURÉES. Sur les
## six petits quartiers d'avant, `_large()`, `_haut()` et le calcul du palier
## le plus haut coûtaient quelques centaines d'itérations : on pouvait les
## appeler à chaque mouvement de souris. Sur Pikstown ils en coûtent 48 375
## CHACUN, et la visée les appelle à chaque pixel parcouru — l'éditeur passait
## sous la seconde par image avant d'avoir posé une case.
var _large_cache := 0
var _haut_cache := 0
var _plus_haut := 0

var _case := Vector2i.ZERO
## ⚠ LE POINT D'IMPACT, pas seulement la case. Un pinceau ne veut que la case ;
## un objet posé à la main veut savoir OÙ dans la case, sinon dix arbres
## d'affilée s'empilent au même millimètre.
var _impact := Vector3.ZERO
var _depart := Vector2i.ZERO
var _vise := false
var _peint := false
var _peint_carte := false
var _gauche := true
var _orbite := false
var _pile: Array = []
var _refaire: Array = []
var _touchees: Dictionary = {}
var _fautives: Dictionary = {}

# ---------------------------------------------------------------- montage

func _ready() -> void:
	# Ouvert tout seul (F6 sur `scenes/editeur.tscn`), l'éditeur se démarre
	# lui-même : la racine, qui appelle `demarrer()` d'habitude, n'est pas là.
	if get_parent() == get_tree().root:
		demarrer()

func demarrer() -> void:
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb:
		monde().add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], 0.10)
	MatieresCarnage.regler_nuit(0.10)
	# La brume du jeu est réglée pour une caméra à trente unités du sol ; à vol
	# d'oiseau elle efface la carte.
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.12
	(amb[1] as DirectionalLight3D).directional_shadow_max_distance = 2600.0

	var mer := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(600.0 * CASE, 600.0 * CASE)
	mer.mesh = plan
	var eau := StandardMaterial3D.new()
	eau.albedo_color = Color("#2b5f7a")
	eau.roughness = 0.15
	eau.metallic = 0.25
	mer.material_override = eau
	mer.position = Vector3(0, -2.4, 0)
	monde().add_child(mer)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 9000.0
	monde().add_child(_camera)
	_camera.make_current()

	_interface()
	for a in OS.get_cmdline_args():
		if a.begins_with("--quartier="): _id = a.substr(11)
	_charger(_id)
	set_process(true)
	set_process_input(true)
	# Le banc : `--photo-editeur=<fichier>` prend une image et sort. C'est le
	# seul moyen de vérifier l'éditeur depuis une session sans écran.
	# `--essai-dessus` prépare l'écran le plus dur à vérifier de mémoire : le
	# relief au palier 3, un rectangle en aperçu, la vue de dessus et le
	# quadrillage — tout ce qui ne se voit QUE sur une photo. Il n'écrit rien.
	if "--essai-dessus" in OS.get_cmdline_args():
		_outil = OUTIL_RELIEF
		_relief_relatif = true
		_carte_relief = true
		_redessiner_carte()
		_palier = 3
		_forme = FORME_PLEIN
		_gauche = true
		_depart = Vector2i(4, 4)
		_case = Vector2i(mini(11, _large() - 1), mini(9, _haut() - 1))
		_apercu_forme()
		# ⚠ ON FABRIQUE DES FAUTES EXPRÈS. Le panneau plein de fautes, avec ses
		# lignes cliquables, est l'état de l'éditeur qu'on ne sait pas atteindre
		# à la main : il faut trouver un carrefour, y monter une marche, et
		# c'est justement ce qu'on passe son temps à éviter. Une marche de trois
		# paliers posée en travers d'une rue en donne à coup sûr.
		_empiler()
		_forme = FORME_LIBRE
		for k in 8:
			_poser(_large() / 2 - 4 + k, _haut() / 2, true)
		_touchees.clear()
		_montrer_fautes()
		_forme = FORME_PLEIN
		_rafraichir_boutons()
		_vue_dessus()
	# ⚠ L'ALLER-RETOUR. `--essai-export=<fichier>` ressort le dessin SANS y avoir
	# touché : ce qui sort doit être exactement ce qui est entré. Un export qui
	# perd une ligne, décale une colonne ou casse une chaîne, on ne s'en aperçoit
	# qu'en le recollant dans le projet — c'est-à-dire une fois le dessin perdu.
	for a in OS.get_cmdline_args():
		if a.begins_with("--essai-export="):
			var chemin := a.substr(15)
			var f2 := FileAccess.open(chemin, FileAccess.WRITE)
			if f2 != null:
				f2.store_string(_texte_source())
				f2.close()
				print("export écrit : ", chemin)
			get_tree().quit()
			return
	# ⚠ LE BANC DU GESTE. Ce que coûte un coup de pinceau, du clic au
	# relâchement, est le seul chiffre qui dit si l'éditeur est utilisable — et
	# c'est celui qu'aucune capture d'écran ne montre. Il valait 1 093 ms sur
	# Pikstown sans que rien ne le signale.
	if "--essai-copie" in OS.get_cmdline_args():
		_essai_copie()
	if "--essai-geste" in OS.get_cmdline_args():
		_essai_geste()
	if "--essai-reparer" in OS.get_cmdline_args():
		_essai_reparer()
	if "--essai-reseau" in OS.get_cmdline_args():
		_essai_reseau()
	if "--essai-semis" in OS.get_cmdline_args():
		_essai_semis()
	if "--essai-objets" in OS.get_cmdline_args():
		_essai_objets()
	if "--essai-editeur" in OS.get_cmdline_args():
		_essai()
	for a in OS.get_cmdline_args():
		if a.begins_with("--photo-editeur="):
			_photo = a.substr(16)
			get_tree().process_frame.connect(_photographier)
		# Le banc doit pouvoir photographier CHAQUE état de la colonne, pas
		# seulement celui du démarrage : une famille de six pinceaux ne se
		# vérifie pas en regardant celle qui en a trois.
		if a.begins_with("--pinceau="):
			_choisir(a.trim_prefix("--pinceau="))
		if a == "--aide":
			_basculer_aide()
		# Le banc doit pouvoir photographier un plan FAUTIF : le bandeau rouge,
		# la liste cliquable et le bouton de rabot ne se voient pas sur une
		# carte propre, et c'est justement eux qu'on veut vérifier.
		# Le banc doit pouvoir photographier le navigateur de modèles ouvert.
		if a.begins_with("--modeles"):
			_choisir_outil(OUTIL_OBJET)
			if a.begins_with("--modeles="):
				_choisir_modele(a.trim_prefix("--modeles="))
				_remplir_liste()
		# Le banc doit pouvoir photographier l'INVENTAIRE, c'est-à-dire l'état
		# où il y a des objets posés ET un objet choisi : la colonne vide ne dit
		# rien de ce qu'on vient d'ajouter.
		if a == "--inventaire":
			_choisir_outil(OUTIL_OBJET)
			_ouvrir_bloc("MODÈLES", false)
			_ouvrir_bloc("OBJETS POSÉS", true)
			var c0 := Vector2i(_large() / 2, _haut() / 2)
			for k in 6:
				_modele = ModelesDuKit.TOUS[(k * 97) % ModelesDuKit.TOUS.size()]
				_hauteur_objet = 8.0 + float(k) * 3.0
				_case = c0 + Vector2i(k % 3, k / 3)
				_impact = Vector3((float(_case.x) + 0.4) * CASE, 0.0,
					(float(_case.y) + 0.6) * CASE)
				_poser_objet(_case)
			_choisir_objet(2)
			_viser_objet()
			_remplir_objets()
		# Le banc doit pouvoir photographier le RECENSEMENT — et le vérifier :
		# un tableau de chiffres se relit, mais seul un banc dit s'ils sont
		# justes.
		# Le banc doit pouvoir PHOTOGRAPHIER un semis : « vingt et un objets »
		# ne dit pas si la haie a l'air d'une haie ou d'un rang d'oignons.
		if a == "--semis":
			_choisir_outil(OUTIL_OBJET)
			_semer = true
			_pas_semis = 0.8
			_dispersion = 0.5
			_variation = 0.3
			_angle_libre = true
			# ⚠ UN MODÈLE QUI SE DISTINGUE DU DÉCOR. Semé en chênes, le banc
			# sortait une photo où l'on ne savait pas dire ce qui venait du
			# semis et ce que la ville avait déjà planté.
			_choisir_modele("kenney/nature/tree_palm")
			_hauteur_objet = 16.0
			var j0 := _haut() / 2
			var i1 := _large() / 2
			_case = Vector2i(i1, j0)
			_empiler()
			_peint = true
			_semes = 0
			_vise = true
			_gauche = true
			# Une courbe, pas une droite : c'est là qu'on voit si le pas suit le
			# trait ou seulement l'axe des X.
			_impact = Vector3((float(i1) + 0.5) * CASE, 0.0, (float(j0) + 0.5) * CASE)
			_dernier_semis = _impact
			_semer_un(_impact)
			for k in range(1, 120):
				var t := float(k) * 0.14
				_impact = Vector3((float(i1) + 0.5 + t) * CASE, 0.0,
					(float(j0) + 0.5 + sin(t * 0.55) * 1.6) * CASE)
				_case = Vector2i(floori(_impact.x / CASE), floori(_impact.z / CASE))
				_semer_le_long()
			_relacher()
			# On cadre APRÈS avoir semé : le milieu de la courbe, de près.
			_pivot = Vector3((float(i1) + 8.0) * CASE, 0.0, (float(j0) + 1.0) * CASE)
			_distance = CASE * 11.0
			_inclinaison = 0.72
			_azimut = 0.9
			_poser_camera()
			if _ville != null: _ville.suivre(_pivot)
		if a == "--recensement":
			for titre in ["PINCEAU", "MODÈLES", "OBJETS POSÉS", "PLAN",
					"FORME DU GESTE", "GESTE", "ATELIER"]:
				_ouvrir_bloc(titre, false)
			_ouvrir_bloc("RECENSEMENT", true)
			_recenser()
			var attendus := {"+": 0, "(": 0, "/": 0}
			for l in _lignes("plan"):
				for c in attendus.keys():
					attendus[c] = int(attendus[c]) + String(l).count(String(c))
			var bon := true
			for c in attendus.keys():
				var vu := int(_compte_reperes.get(c, 0))
				if vu != int(attendus[c]): bon = false
				print("--- « %s » : recensé %d, compté à part %d" % [c, vu, attendus[c]])
			print("--- %s" % _resume_reperes.text)
			var lignes_liste := _liste_reperes.item_count
			print("--- la liste montre %d caractère(s) présent(s)" % lignes_liste)
			# Sauter d'une occurrence à l'autre doit BOUGER la vue.
			var rang := _chars_recenses.find("+")
			if rang >= 0:
				_liste_reperes.select(rang)
				_rang_repere = -1
				var ou := _pivot
				_sauter_repere(1)
				var un := _pivot
				_sauter_repere(1)
				var deux := _pivot
				var bouge := un != ou and deux != un
				print("--- saut d'un hôpital à l'autre : %s" % ("oui" if bouge else "NON"))
				bon = bon and bouge
			print("--- BANC DU RECENSEMENT : %s" % ("RÉUSSI" if bon and lignes_liste > 10 else "ÉCHOUÉ"))
		if a == "--gacher":
			for j in range(78, 92):
				for i in range(96, 112):
					if _dans_grille(i, j) and not (_lire("plan", i, j) in EAUX):
						_ecrire("relief", i, j, "5")
			_remesurer()
			_rebatir()
			_redessiner_carte()
			_outil = OUTIL_RELIEF
			_palier = 5
			_rafraichir_boutons()
			_montrer_fautes()
			_etat()

## LE BANC. Il peint par le code exactement ce que la souris peindrait — et il
## se sert des FORMES, sinon elles ne seraient vérifiées nulle part.
## ⚠ CE QUI EST COLLÉ DOIT ÊTRE EXACTEMENT CE QUI A ÉTÉ COPIÉ, RELIEF COMPRIS.
## Un collage qui perd le relief ne se voit pas tout de suite : le pâté a l'air
## juste, et c'est trois gestes plus tard que le banc annonce quatre bâtiments à
## cheval sur deux paliers. On compare donc case par case, ici, tout de suite.
func _essai_copie() -> void:
	var src := Rect2i(40, 40, 9, 6)
	var dst := Vector2i(120, 200)
	_selection = src
	_copier()
	# On note ce qu'on croit avoir copié, LU DEPUIS LA GRILLE, pas depuis le
	# presse-papier : sinon on comparerait le presse-papier à lui-même.
	var attendu: Array = []
	for j in src.size.y:
		var l := ""
		for i in src.size.x:
			l += _lire("plan", src.position.x + i, src.position.y + j) \
				+ _lire("relief", src.position.x + i, src.position.y + j)
		attendu.append(l)
	_case = dst
	_collage = true
	_poser_collage()
	var faux := 0
	for j in src.size.y:
		var l := ""
		for i in src.size.x:
			l += _lire("plan", dst.x + i, dst.y + j) + _lire("relief", dst.x + i, dst.y + j)
		if l != attendu[j]: faux += 1
	print("--- COPIE/COLLAGE %d x %d : %s" % [src.size.x, src.size.y,
		"IDENTIQUE (plan et relief)" if faux == 0 else "*** %d rangées DIFFÉRENTES ***" % faux])
	print("    source  : ", attendu[0])
	var rendu := ""
	for i in src.size.x:
		rendu += _lire("plan", dst.x + i, dst.y) + _lire("relief", dst.x + i, dst.y)
	print("    collage : ", rendu)
	print("--- fautes après collage : ", Quartiers.fautes(_fiche).size())
	get_tree().quit()

## LE BANC DU MOBILIER LIBRE. Poser, compter dans la SCÈNE (pas dans la liste :
## une liste peut très bien décrire des objets que personne ne bâtit), ôter,
## annuler, et relire ce que l'export écrit. Un placement à la main qui ne
## ressort pas à l'export, c'est une heure de travail perdue sans un mot.
func _essai_objets() -> void:
	_choisir_modele("kenney/industriel/water-tower")
	_hauteur_objet = 26.0
	var c := Vector2i(160, 150)
	_case = c
	_impact = Vector3((float(c.x) + 0.3) * CASE, 0.0, (float(c.y) + 0.7) * CASE)
	# ⚠ LE MORCEAU DOIT EXISTER. `refaire()` ne refait que ce qui est déjà bâti :
	# sans cette amorce, le banc posait trois objets dans un décor vide et
	# comptait zéro nœud de plus — puis criait à la panne alors que tout allait
	# bien. Un banc qui ne bâtit rien ne mesure rien.
	var m := Vector2i(c.x / VilleMorcelee.COTE, c.y / VilleMorcelee.COTE)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			_ville._batir(m + Vector2i(dx, dy))
	var avant := _compter_noeuds(_ville)
	for k in 3:
		_impact.x += CASE * 0.2
		_empiler()
		_poser_objet(c)
	print("\n--- MOBILIER : %d objet(s) dans la fiche" % _objets().size())
	var apres := _compter_noeuds(_ville)
	print("--- nœuds du décor : %d → %d (%+d)" % [avant, apres, apres - avant])
	var t := _texte_source()
	var lignes := 0
	for l in t.split("\n"):
		if l.begins_with("\t{\"m\":"): lignes += 1
	print("--- l'export écrit %d ligne(s) d'objet" % lignes)
	# ─── L'INVENTAIRE : choisir, régler, supprimer ───
	# ⚠ ON VISE LE PREMIER DES TROIS, PAS LE DERNIER. Les trois sont sur la même
	# case ; si `_objet_ici` rendait simplement le dernier posé, le banc
	# passerait sans rien prouver. On remet donc le point d'impact là où on a
	# posé le PREMIER, et on exige que ce soit lui qui sorte.
	_impact.x -= CASE * 0.6
	var vise := _objet_ici(c)
	_choisir_objet(vise)
	var bon_choix := vise == 0 and _objet_choisi == 0 and _halo != null and _halo.visible
	print("--- choix au curseur : indice %d (attendu 0), mire allumée : %s" % [
		vise, "oui" if (_halo != null and _halo.visible) else "non"])
	_remplir_objets()
	print("--- l'inventaire montre %d ligne(s)" % _liste_objets.item_count)
	_regler_objet("h", 41.0)
	_regler_objet("r", 90.0)
	var o0: Dictionary = _objets()[0]
	var bon_reglage := is_equal_approx(float(o0["h"]), 41.0) \
		and is_equal_approx(float(o0["r"]), 90.0)
	print("--- après réglage : hauteur %s, angle %s" % [o0["h"], o0["r"]])
	_regler_objet("m", "kenney/nature/tree_palm")
	var bon_modele := String(_objets()[0]["m"]).ends_with("tree_palm")
	print("--- après remplacement du modèle : %s" % _objets()[0]["m"])
	_supprimer_objet()
	var apres_suppr := _objets().size()
	print("--- après Suppr : %d objet(s), rien de choisi : %s" % [
		apres_suppr, "oui" if _objet_choisi < 0 else "non"])
	_annuler()
	print("--- après Ctrl+Z : %d objet(s)" % _objets().size())
	var bon := _objets().size() == 3 and lignes == 3 and apres > avant \
		and bon_choix and bon_reglage and bon_modele and apres_suppr == 2 \
		and _objet_choisi < 0 and _liste_objets.item_count == 3
	print("--- BANC DU MOBILIER : %s" % ("RÉUSSI" if bon else "ÉCHOUÉ"))
	get_tree().quit()

## LE BANC DU SEMIS. Il traîne une ligne droite de vingt cases et vérifie les
## trois choses qui font qu'un semis est utile plutôt qu'agaçant : le NOMBRE
## (le pas est-il respecté ?), la DISPERSION (une haie parfaitement alignée est
## une haie de cimetière) et l'ANNULATION (un glissé = UN Ctrl+Z, pas quarante).
func _essai_semis() -> void:
	_choisir_modele("kenney/nature/tree_oak")
	_hauteur_objet = 12.0
	_semer = true
	_pas_semis = 1.0
	_dispersion = 0.6
	_variation = 0.25
	_angle_libre = true
	# ⚠ LA MESURE DU PAS SE FAIT SANS LE FILTRE DE VOIRIE. Un trait de vingt
	# cases en pleine ville en traverse trois ou quatre : compter les grains
	# avec le filtre allumé, c'est mesurer le tracé du banc, pas le pas.
	_semis_hors_voirie = false
	var j := 150
	var i0 := 150
	var longueur := 20
	var m := Vector2i(i0 / VilleMorcelee.COTE, j / VilleMorcelee.COTE)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			_ville._batir(m + Vector2i(dx, dy))
	var avant_pile := _pile.size()
	var avant := _objets().size()
	# Le geste : on clique au début, on traîne case par demi-case, on relâche.
	# ⚠ ON N'APPELLE PAS `_commencer` : sa première ligne est `_viser()`, qui
	# relit la VRAIE souris — à (0,0) dans un banc sans écran — et écrase le
	# point d'impact qu'on vient de poser. On refait donc ce que fait
	# `_commencer` pour un semis, moins la visée.
	_case = Vector2i(i0, j)
	_impact = Vector3((float(i0) + 0.5) * CASE, 0.0, (float(j) + 0.5) * CASE)
	_vise = true
	_gauche = true
	_empiler()
	_peint = true
	_semes = 0
	_dernier_semis = _impact
	_semer_un(_impact)
	for k in range(1, longueur * 2 + 1):
		_impact = Vector3((float(i0) + 0.5 + float(k) * 0.5) * CASE, 0.0,
			(float(j) + 0.5) * CASE)
		_case = Vector2i(floori(_impact.x / CASE), j)
		_semer_le_long()
	_relacher()
	var poses := _objets().size() - avant
	print("\n--- SEMIS : %d objet(s) sur %d cases, pas demandé %s" % [
		poses, longueur, _nombre(_pas_semis)])
	# ⚠ ON RETIENT LE COMPTE AVANT D'ANNULER : `_annuler()` DÉPILE, et le
	# vérifier après l'annulation faisait échouer un banc qui passait.
	var empiles := _pile.size() - avant_pile
	print("--- états d'annulation ajoutés : %d (attendu 1)" % empiles)
	# Dispersion et variété : les grains ne doivent pas être tous identiques.
	var zs: Array[float] = []
	var hs: Array[float] = []
	var rs: Array[float] = []
	for k in range(avant, _objets().size()):
		var o: Dictionary = _objets()[k]
		zs.append(float(o.get("z", 0.5)))
		hs.append(float(o.get("h", 0.0)))
		rs.append(float(o.get("r", 0.0)))
	var z_min: float = zs.min() if not zs.is_empty() else 0.0
	var z_max: float = zs.max() if not zs.is_empty() else 0.0
	var h_min: float = hs.min() if not hs.is_empty() else 0.0
	var h_max: float = hs.max() if not hs.is_empty() else 0.0
	var angles := {}
	for r in rs: angles[r] = true
	print("--- écart de côté : z de %.2f à %.2f — hauteurs de %s à %s — %d angle(s) distinct(s)" % [
		z_min, z_max, _nombre(h_min), _nombre(h_max), angles.size()])
	_annuler()
	print("--- après UN Ctrl+Z : %d objet(s) (attendu %d)" % [_objets().size(), avant])
	# ─── LE FILTRE DE VOIRIE, sur le MÊME trait ───
	_semis_hors_voirie = true
	var rues := 0
	for k in range(0, longueur):
		if CHAUSSEE.contains(_lire("plan", i0 + k, j)): rues += 1
	_empiler()
	_peint = true
	_semes = 0
	_impact = Vector3((float(i0) + 0.5) * CASE, 0.0, (float(j) + 0.5) * CASE)
	_dernier_semis = _impact
	_semer_un(_impact)
	for k in range(1, longueur * 2 + 1):
		_impact = Vector3((float(i0) + 0.5 + float(k) * 0.5) * CASE, 0.0,
			(float(j) + 0.5) * CASE)
		_case = Vector2i(floori(_impact.x / CASE), j)
		_semer_le_long()
	_relacher()
	var filtres := _objets().size() - avant
	print("--- même trait, voirie évitée : %d objet(s) — %d case(s) de rue sur le trajet" % [
		filtres, rues])
	var bon_filtre: bool = rues == 0 or filtres < poses
	_annuler()
	var bon: bool = poses >= longueur - 2 and poses <= longueur + 2 \
		and empiles == 1 \
		and z_max - z_min > 0.1 and h_max - h_min > 1.0 and angles.size() > longueur / 2 \
		and _objets().size() == avant and bon_filtre
	print("--- BANC DU SEMIS : %s" % ("RÉUSSI" if bon else "ÉCHOUÉ"))
	get_tree().quit()

## LE BANC DU RÉSEAU. Un contrôle qui ne dit jamais « c'est cassé » n'est pas un
## contrôle : le banc COUPE un pont exprès, vérifie qu'on le voit, recolle, et
## vérifie qu'on ne le voit plus.
func _essai_reseau() -> void:
	_ouvrir_bloc("RECENSEMENT", true)
	_verifier_reseau()
	var propre := _orphelins.is_empty()
	print("\n--- réseau tel quel : %d morceau(x) coupé(s)" % _orphelins.size())
	# ⚠ ON COUPE LE PONT D'UNE ÎLE, pas n'importe lequel. Les grands bras de
	# mer ont plusieurs traversées : en effacer une ne coupe rien, et le banc
	# passait au vert sur un contrôle qui n'avait rien vu. Le pont de la
	# colonne 284 est le SEUL accès à son île — deux cases de tablier.
	_empiler()
	var coupees := 0
	for j in range(126, 128):
		if _lire("plan", 284, j) == "=":
			_ecrire("plan", 284, j, ".")
			coupees += 1
	_verifier_reseau()
	var casse := _orphelins.size()
	print("--- %d case(s) de tablier effacée(s) → %d morceau(x) coupé(s) vus" % [
		coupees, casse])
	_annuler()
	_verifier_reseau()
	var recolle := _orphelins.is_empty()
	print("--- après Ctrl+Z : %s" % ("d'un seul tenant" if recolle else "TOUJOURS COUPÉ"))
	var bon := propre and coupees == 2 and casse == 1 and recolle
	print("--- BANC DU RÉSEAU : %s" % ("RÉUSSI" if bon else "ÉCHOUÉ"))
	get_tree().quit()

func _compter_noeuds(n: Node) -> int:
	if n == null: return 0
	var t := 1
	for e in n.get_children(): t += _compter_noeuds(e)
	return t

## LE BANC DU RABOT. Il FABRIQUE des fautes exprès — une terrasse posée en plein
## centre, à cheval sur des pâtés et des carrefours, c'est exactement le geste
## qui en produit — puis il rabote et compte ce qui reste. Un réparateur qu'on
## n'a jamais vu échouer sur une carte tordue n'est pas un réparateur, c'est un
## espoir.
func _essai_reparer() -> void:
	var avant_total := Quartiers.fautes(_fiche).size()
	print("\n--- BANC DU RABOT : %d faute(s) avant de toucher à quoi que ce soit" % avant_total)
	var alea := RandomNumberGenerator.new()
	alea.seed = 2609
	var pires := 0
	# Trois terrasses au hasard dans le centre bâti, de tailles et de hauteurs
	# différentes : une petite bosse, une grande, une marche haute.
	for essai in 3:
		var i0 := 60 + essai * 40
		var j0 := 60 + essai * 30
		var w := 7 + essai * 6
		var niveau := 2 + essai * 2
		for j in range(j0, j0 + w):
			for i in range(i0, i0 + w):
				if not _dans_grille(i, j): continue
				if _lire("plan", i, j) in EAUX: continue
				_ecrire("relief", i, j, str(mini(9, niveau)))
		pires += w * w
	_remesurer()
	var fautes_apres := Quartiers.fautes(_fiche)
	print("--- après avoir posé trois terrasses (%d cases) : %d faute(s)" % [pires, fautes_apres.size()])
	if fautes_apres.size() <= avant_total:
		print("    ⚠ le banc n'a rien cassé — il ne prouve donc rien. Revoir les terrasses.")
	var mes := _reparer()
	var reste: Array = Quartiers.fautes(_fiche)
	print("--- après le rabot : %d faute(s), %d ms" % [reste.size(), int(mes["total"])])
	print("    carte %d ms · blocs %d ms · %d passes %d ms · rebâtir %d ms" % [
		mes["carte"], mes["blocs"], mes["passes"], mes["passes_ms"], mes["rebatir"]])
	for f in reste.slice(0, mini(5, reste.size())):
		print("    reste : (%d,%d) %s" % [f["i"], f["j"], f["texte"]])
	print("--- BANC DU RABOT : %s" % ("RÉUSSI" if reste.size() <= avant_total else "ÉCHOUÉ"))
	get_tree().quit()

func _essai_geste() -> void:
	var ou := Vector2i(_large() / 2, _haut() / 2)
	# Les morceaux autour du geste doivent exister : on ne rebâtit que ce qui
	# est déjà bâti, et un banc qui ne rebâtit rien mesure zéro.
	var m := Vector2i(ou.x / VilleMorcelee.COTE, ou.y / VilleMorcelee.COTE)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			_ville._batir(m + Vector2i(dx, dy))
	print("--- banc du geste : %d morceaux bâtis autour de %s" % [_ville.morceaux_batis(), ou])
	_empiler()
	_choisir("#")
	for k in 20:
		_poser(ou.x - 10 + k, ou.y, true)
	var t0 := Time.get_ticks_msec()
	_finir_geste()
	print("--- UN GESTE (avenue de 20 cases) : %d ms" % [Time.get_ticks_msec() - t0])
	var t1 := Time.get_ticks_msec()
	_montrer_fautes()
	print("--- LA VÉRIFICATION, différée : %d ms" % [Time.get_ticks_msec() - t1])
	get_tree().quit()

func _essai() -> void:
	_empiler()
	_depart = Vector2i(2, 16)                    # une avenue en travers, à la ligne
	_case = Vector2i(13, 16)
	_forme = FORME_LIGNE
	_appliquer_forme(true)
	_choisir("T")
	_forme = FORME_PLEIN                         # un bloc de tours au bord de l'eau
	_depart = Vector2i(6, 17)
	_case = Vector2i(8, 18)
	_appliquer_forme(true)
	_outil = OUTIL_RELIEF                        # une terrasse au godet
	_palier = 3
	_forme = FORME_CADRE
	_depart = Vector2i(2, 1)
	_case = Vector2i(5, 1)
	_appliquer_forme(true)
	_forme = FORME_LIBRE
	_finir_geste()
	print("--- essai : grille %d x %d" % [_large(), _haut()])
	for l in _lignes("plan"):
		print("    ", l)
	print(_texte_fiche().substr(0, 300))
	var liste: Array = Quartiers.fautes(_fiche)
	print("--- fautes après essai : ", liste.size())
	for f in liste:
		print("    ", f)

var _photo := ""
var _images := 0

func _photographier() -> void:
	_images += 1
	if _images < 16: return
	DirAccess.make_dir_recursive_absolute(_photo.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_photo)
	print("photo ", _photo)
	get_tree().quit()

# ---------------------------------------------------------------- le quartier

func _charger(id: String) -> void:
	if not Quartiers.CATALOGUE.has(id):
		return
	_id = id
	# Une COPIE PROFONDE : on ne veut surtout pas modifier le catalogue en
	# mémoire, sinon « recharger » ne recharge rien.
	_fiche = (Quartiers.CATALOGUE[id] as Dictionary).duplicate(true)
	_pile.clear(); _refaire.clear()
	var repris := _reprendre_brouillon()
	_rebatir()
	_recadrer()
	_synchroniser_liste()
	# ⚠ LA MINI-CARTE SE PEINT ICI, une fois le dessin chargé. `_interface()`
	# tourne AVANT `_charger()` : appelée là-haut, la première image se peignait
	# sur une grille encore vide (zéro sur zéro) et le plan restait blanc
	# jusqu'au premier coup de pinceau — c'est-à-dire jusqu'à ce qu'on ait
	# renoncé à s'en servir pour se repérer.
	_redessiner_carte()
	_remplir_objets()
	if repris:
		_dire("Brouillon repris — il était gardé dans ce navigateur. « Recharger » revient au catalogue.")
	else:
		_dire("")

## ⚠ ON NE REBÂTIT PLUS LA VILLE, ON LA SUIT. Pikstown coûte quatre secondes et
## cinquante-quatre mille nœuds : rebâtir tout au relâchement de chaque coup de
## pinceau, c'était quatre secondes par case peinte. Le décor passe donc par
## `VilleMorcelee`, qui bâtit les morceaux autour du pivot de la caméra ; et
## `_finir_geste` ne refait que les morceaux touchés.
func _rebatir() -> void:
	_remesurer()
	if _quartier != null: _quartier.queue_free()
	_quartier = Node3D.new()
	_quartier.name = "Repere_" + _id
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	_quartier.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(float(_fiche.get("angle", 0.0)))),
		Vector3(org.x * CASE, 0, org.y * CASE))
	monde().add_child(_quartier)
	if _ville != null: _ville.queue_free()
	_ville = VilleMorcelee.new()
	monde().add_child(_ville)
	# ⚠ TROIS MORCEAUX PAR IMAGE, pas un. Dans le jeu, un à-coup de 124 ms se
	# paye en pilotage ; dans l'éditeur on ne pilote rien, et attendre vingt
	# secondes que le quartier paraisse coûte bien plus cher que trois images
	# sautées.
	_ville.par_image = 3
	_ville.regler(_fiche, _id, _rayon_utile())
	_ville.suivre(_pivot)

	_curseur = MeshInstance3D.new()
	_curseur.mesh = _cadre()
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color("#ffd23f")
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_curseur.material_override = mc
	_quartier.add_child(_curseur)
	# ⚠ LE HALO VIT DANS `_quartier`, PAS DANS LA VILLE. Reconstruire un morceau
	# efface tout ce qu'il contient : accroché à la ville, le repère de l'objet
	# choisi disparaissait au premier réglage — c'est-à-dire exactement quand on
	# le regarde.
	_halo = MeshInstance3D.new()
	_halo.mesh = _mire()
	var mh := StandardMaterial3D.new()
	# ⚠ ORANGE VIF, PAS LE BLEU DU PANNEAU. La mire se lit PAR-DESSUS la ville :
	# sur des toits bleus et gris, le bleu d'accent de l'atelier disparaissait.
	# L'orange ne se confond avec rien dans cette ville — et le curseur de case,
	# lui, reste jaune : deux repères, deux couleurs.
	mh.albedo_color = Color("#ff7a1a")
	mh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mh.no_depth_test = true
	_halo.material_override = mh
	_halo.visible = false
	_quartier.add_child(_halo)
	_apercu = Node3D.new()
	_quartier.add_child(_apercu)
	_marques = Node3D.new()
	_quartier.add_child(_marques)
	_poser_maillage()
	_poser_nappe()
	_montrer_fautes()
	_etat()


## LE RAYON SUIT LE ZOOM. Un rayon fixe ne peut pas convenir aux deux bouts :
## à trois morceaux, la vue d'ensemble de Pikstown ne montre qu'un huitième de
## l'île ; à dix, un simple coup d'œil sur un pâté en bâtit cent soixante-neuf
## et l'éditeur met vingt secondes à s'ouvrir. On demande donc exactement de
## quoi remplir ce qu'on regarde.
func _rayon_utile() -> int:
	var cases := _distance / CASE
	return clampi(int(cases / float(VilleMorcelee.COTE)) + 1, 2, 6)

## LA MIRE DE L'OBJET CHOISI : un carré au sol, un mât, un carré en haut. Une
## boîte pleine cacherait le modèle qu'on est en train de régler ; trois traits
## disent où il est et jusqu'où il monte sans rien masquer. Le maillage est en
## unités : le nœud l'étire à la hauteur de l'objet.
func _mire() -> ArrayMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for y in [0.0, 1.0]:
		var coins := [Vector3(-0.5, y, -0.5), Vector3(0.5, y, -0.5),
			Vector3(0.5, y, 0.5), Vector3(-0.5, y, 0.5)]
		for k in 4:
			im.surface_add_vertex(coins[k])
			im.surface_add_vertex(coins[(k + 1) % 4])
	im.surface_add_vertex(Vector3(0, 0, 0))
	im.surface_add_vertex(Vector3(0, 1.15, 0))
	im.surface_end()
	var m := ArrayMesh.new()
	for si in im.get_surface_count():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, im.surface_get_arrays(si))
	return m

func _cadre() -> ArrayMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var h := CASE * 0.5
	var coins := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	for k in 4:
		im.surface_add_vertex(coins[k] + Vector3(0, 0.8, 0))
		im.surface_add_vertex(coins[(k + 1) % 4] + Vector3(0, 0.8, 0))
		im.surface_add_vertex(coins[k] + Vector3(0, 0.8, 0))
		im.surface_add_vertex(coins[k] + Vector3(0, PALIER * 0.9, 0))
	im.surface_end()
	var m := ArrayMesh.new()
	for s in im.get_surface_count():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, im.surface_get_arrays(s))
	return m

# ------------------------------------------------------- les repères au sol

## LE QUADRILLAGE. Sans lui on vise une case en la devinant entre deux toits :
## le curseur dit où l'on est, il ne dit pas où sont les autres cases. Les
## lignes de cinq sont plus franches — on compte par cinq, pas par un — et le
## contour du quartier est de la couleur du panneau, pour qu'on voie d'un coup
## d'œil ce qui appartient au quartier COURANT et ce qui est le décor voisin.
func _poser_maillage() -> void:
	var l := _large()
	var h := _haut()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var y := 0.35
	for i in range(0, l + 1):
		var c := _teinte_ligne(i, l)
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(float(i) * CASE, y, 0.0))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(float(i) * CASE, y, float(h) * CASE))
	for j in range(0, h + 1):
		var c2 := _teinte_ligne(j, h)
		im.surface_set_color(c2)
		im.surface_add_vertex(Vector3(0.0, y, float(j) * CASE))
		im.surface_set_color(c2)
		im.surface_add_vertex(Vector3(float(l) * CASE, y, float(j) * CASE))
	im.surface_end()
	_maillage = MeshInstance3D.new()
	_maillage.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_maillage.material_override = m
	_maillage.visible = _voir_grille
	_quartier.add_child(_maillage)

func _teinte_ligne(k: int, fin: int) -> Color:
	if k == 0 or k == fin:
		return Color(0.22, 0.53, 0.90, 0.85)
	if k % 5 == 0:
		return Color(1, 1, 1, 0.30)
	return Color(1, 1, 1, 0.11)

## LE PALIER COURANT, en relief : un voile posé à la hauteur où l'on peint. Un
## chiffre dans un panneau ne dit pas si l'on est au-dessus ou en dessous du
## toit qu'on regarde ; ce plan-là le dit.
func _poser_nappe() -> void:
	_nappe = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(float(_large()) * CASE, float(_haut()) * CASE)
	_nappe.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.68, 1.0, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_nappe.material_override = m
	_nappe.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	_nappe.visible = false
	_quartier.add_child(_nappe)

func _regler_nappe() -> void:
	if _nappe == null: return
	_nappe.visible = _outil == OUTIL_RELIEF
	_nappe.position = Vector3(float(_large()) * 0.5 * CASE,
		float(_palier) * PALIER + 0.6, float(_haut()) * 0.5 * CASE)

# ---------------------------------------------------------------- la grille

## ⚠ `.get`, PAS `[]`. L'interface se bâtit AVANT le chargement du quartier :
## tout ce qui, dans un panneau, veut connaître l'état — l'aperçu d'un modèle,
## la ligne du bas — tombait sur une fiche encore vide et sortait une erreur au
## démarrage. Une grille absente est une grille vide, pas une panne.
func _lignes(cle: String) -> Array:
	return _fiche.get(cle, [])

func _large() -> int:
	return _large_cache

func _haut() -> int:
	return _haut_cache

## À rappeler quand la GRILLE change de forme : charger, agrandir un bord,
## annuler, reprendre un brouillon.
##
## ⚠ PAS APRÈS UN COUP DE PINCEAU. Elle relit les 96 000 chiffres du relief pour
## retrouver le palier le plus haut : un tiers du coût d'un geste, pour une
## valeur qui ne peut que MONTER quand on peint. `_poser` la tient donc à jour
## case par case, et cette fonction-ci ne sert plus qu'aux changements de forme.
func _remesurer() -> void:
	_recense_a_jour = false
	_large_cache = 0
	for ligne in _lignes("plan"):
		_large_cache = maxi(_large_cache, String(ligne).length())
	_haut_cache = _lignes("plan").size()
	_plus_haut = 0
	for l in _lignes("relief"):
		var ligne := String(l)
		for k in ligne.length():
			var c := ligne[k]
			if c > "0" and c <= "9":
				_plus_haut = maxi(_plus_haut, int(c))

func _lire(cle: String, i: int, j: int) -> String:
	var lignes: Array = _lignes(cle)
	if j < 0 or j >= lignes.size(): return "." if cle == "plan" else "0"
	var ligne: String = lignes[j]
	if i < 0 or i >= ligne.length(): return "." if cle == "plan" else "0"
	return ligne[i]

## ⚠ Une chaîne GDScript ne se modifie pas par indice : on la recompose. Et on
## complète les lignes trop courtes, sinon peindre à droite d'une ligne courte
## ne fait rien du tout, en silence.
func _ecrire(cle: String, i: int, j: int, c: String) -> void:
	var lignes: Array = _lignes(cle)
	if j < 0 or j >= lignes.size() or i < 0: return
	var ligne: String = lignes[j]
	var bouche := "." if cle == "plan" else "0"
	while ligne.length() <= i:
		ligne += bouche
	lignes[j] = ligne.substr(0, i) + c + ligne.substr(i + 1)
	# Un caractère écrit, et le recensement ne vaut plus. Un booléen par case
	# peinte, c'est le prix qu'on accepte ; recompter, non (voir `_recenser`).
	_recense_a_jour = false

func _palier_de(i: int, j: int) -> int:
	var c := _lire("relief", i, j)
	return int(c) if c >= "0" and c <= "9" else 0

func _terre(i: int, j: int) -> bool:
	return not EAUX.contains(_lire("plan", i, j))

func _dans_grille(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < _large() and j < _haut()

# ---------------------------------------------------------------- visée

## Où pointe la souris, DANS LE REPÈRE DU QUARTIER : il a son propre angle, et
## viser en coordonnées du monde donnait des cases décalées dès que l'angle
## n'était pas nul.
func _viser() -> void:
	if _camera == null or _quartier == null: return
	var souris := get_viewport().get_mouse_position()
	var inverse := _quartier.global_transform.affine_inverse()
	var origine := inverse * _camera.project_ray_origin(souris)
	var direction := (inverse.basis * _camera.project_ray_normal(souris)).normalized()
	if absf(direction.y) < 0.0001:
		_vise = false
		return
	for niveau in range(_plus_haut, -1, -1):
		var t := (float(niveau) * PALIER - origine.y) / direction.y
		if t <= 0.0: continue
		var p := origine + direction * t
		var c := Vector2i(floori(p.x / CASE), floori(p.z / CASE))
		if _terre(c.x, c.y) and _palier_de(c.x, c.y) == niveau:
			_case = c; _impact = p; _vise = true; return
	var t0 := (float(_palier) * PALIER - origine.y) / direction.y
	if t0 <= 0.0:
		_vise = false
		return
	var p0 := origine + direction * t0
	_case = Vector2i(floori(p0.x / CASE), floori(p0.z / CASE))
	_impact = p0
	_vise = true

# ---------------------------------------------------------------- le geste

func _input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseMotion:
		if _orbite:
			var m := evenement as InputEventMouseMotion
			_azimut -= m.relative.x * 0.006
			_inclinaison = clampf(_inclinaison + m.relative.y * 0.005, 0.14, 1.45)
			_dessus = false
			_poser_camera()
			return
		_viser()
		_montrer_curseur()
		if _collage:
			_apercu_collage()
			return
		if _peint:
			if _outil == OUTIL_OBJET:
				_semer_le_long()
			elif _forme == FORME_LIBRE:
				_appliquer(_gauche)
			else:
				_apercu_forme()
		return
	if evenement is InputEventMouseButton:
		var b := evenement as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(50.0, _distance * 0.9); _poser_camera(); return
		if b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(6000.0, _distance * 1.1); _poser_camera(); return
		if b.button_index == MOUSE_BUTTON_MIDDLE:
			_orbite = b.pressed; return
		if get_viewport().gui_get_hovered_control() != null:
			return
		if b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT:
			if b.pressed:
				_commencer(b.button_index == MOUSE_BUTTON_LEFT, b.alt_pressed)
			else:
				_relacher()
			return
	if evenement is InputEventKey and (evenement as InputEventKey).pressed:
		_touche(evenement as InputEventKey)

## Le début d'un geste. La PIPETTE et le GODET n'ont pas de durée : ils
## agissent au clic et il n'y a rien à faire au relâchement — d'où leur sortie
## avant que `_peint` ne soit levé.
func _commencer(gauche: bool, alt: bool) -> void:
	_viser()
	if not _vise: return
	_gauche = gauche
	_depart = _case
	# ⚠ LE COLLAGE PASSE AVANT TOUT. Sinon le clic qui doit poser le presse-
	# papier peint aussi une case avec le pinceau courant, sous le collage.
	if _collage:
		if gauche:
			_poser_collage()
		else:
			_collage = false
			_vider_apercu()
			_dire("Collage annulé.")
		return
	if alt or _forme == FORME_PIPETTE:
		_prelever()
		return
	# ⚠ L'OBJET SE POSE AU CLIC, PAS AU GESTE. Un modèle libre n'est pas une
	# couleur : traîner la souris en poserait quarante sur vingt cases, et les
	# retirer un par un coûterait plus cher que de les avoir posés.
	if _outil == OUTIL_OBJET:
		_empiler()
		if gauche and _semer:
			_peint = true
			_semes = 0
			# ⚠ LE PREMIER GRAIN TOMBE AU CLIC, pas au premier pas. Sans lui,
			# un clic sans traîner ne posait RIEN et le mode semis avait l'air
			# cassé pour qui l'essaie d'abord d'un clic.
			_dernier_semis = _impact
			_semer_un(_impact)
			return
		if gauche:
			_poser_objet(_case)
		else:
			_oter_objet(_case)
		return
	if _forme == FORME_GODET:
		_empiler()
		_remplir(_case, gauche)
		_finir_geste()
		return
	if _forme == FORME_SELECTION:
		# Elle ne peint pas : elle délimite. Rien à empiler, rien à annuler.
		_peint = true
		_selection = Rect2i(_case, Vector2i.ONE)
		_apercu_forme()
		return
	_empiler()
	_peint = true
	if _forme == FORME_LIBRE:
		_appliquer(gauche)
	else:
		_apercu_forme()

func _relacher() -> void:
	if not _peint:
		return
	_peint = false
	# ⚠ LE SEMIS N'EST PAS UNE FORME. Sans cette sortie, relâcher après avoir
	# semé appliquait EN PLUS la forme du geste avec le pinceau courant : on
	# semait des arbres et l'on repeignait une bande de rue par-dessus.
	if _outil == OUTIL_OBJET:
		_finir_geste()
		if _semes > 0:
			_dire("%d objet(s) semé(s) — %s, pas %s case(s)." % [
				_semes, _modele.get_file(), _nombre(_pas_semis)])
		return
	if _forme == FORME_SELECTION:
		_selection = _rectangle(_depart, _case)
		_dire("Sélection %d × %d — Ctrl+C pour copier." % [_selection.size.x, _selection.size.y])
		_montrer_selection()
		_etat()
		return
	if _forme != FORME_LIBRE:
		_appliquer_forme(_gauche)
	_finir_geste()

static func _rectangle(a: Vector2i, b: Vector2i) -> Rect2i:
	return Rect2i(mini(a.x, b.x), mini(a.y, b.y), absi(b.x - a.x) + 1, absi(b.y - a.y) + 1)

func _touche(k: InputEventKey) -> void:
	if k.ctrl_pressed and k.keycode == KEY_Z: _annuler(); return
	if k.ctrl_pressed and k.keycode == KEY_Y: _refaire_geste(); return
	if k.ctrl_pressed and k.keycode == KEY_C: _copier(); return
	if k.ctrl_pressed and k.keycode == KEY_V: _coller(); return
	if k.keycode == KEY_ESCAPE:
		_collage = false
		_selection = Rect2i()
		_montrer_selection()
		_vider_apercu()
		_dire("")
		return
	if k.keycode == KEY_C: _choisir_forme(FORME_SELECTION); return
	# Les chiffres choisissent le pinceau : les neuf premiers, puis les neuf
	# suivants avec Maj. Dix-neuf pinceaux ne tiennent pas sur dix touches, et
	# lâcher la souris pour aller cliquer dans la colonne casse le geste.
	# ⚠ `physical_keycode` et non `keycode` : sur un clavier AZERTY, la rangée
	# des chiffres se lit « & é " ' » sans Maj, et `keycode` rendrait donc
	# KEY_AMPERSAND là où l'on attend KEY_1. La position de la touche, elle, ne
	# dépend pas de la disposition.
	if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
		var rang := k.physical_keycode - KEY_1 + (9 if k.shift_pressed else 0)
		if rang < PINCEAUX.size(): _choisir(String(PINCEAUX[rang][0]))
		return
	match k.keycode:
		KEY_TAB:
			# Tab fait le TOUR des trois outils : dessin, relief, objet. Deux
			# outils se basculent, trois se parcourent — et rien ne dit à
			# personne qu'il existe une troisième touche.
			_choisir_outil((_outil + 1) % 3)
		KEY_B: _choisir_forme(FORME_LIBRE)
		KEY_L: _choisir_forme(FORME_LIGNE)
		KEY_K: _choisir_forme(FORME_CADRE)
		KEY_J: _choisir_forme(FORME_PLEIN)
		KEY_G: _choisir_forme(FORME_GODET)
		KEY_I: _choisir_forme(FORME_PIPETTE)
		KEY_DELETE: _supprimer_objet()
		KEY_X: _basculer_grille()
		KEY_V: _vue_dessus()
		KEY_R:
			_minuscule = not _minuscule
			_etat()
		KEY_PAGEUP, KEY_KP_ADD:
			_palier = mini(_palier + 1, 9); _etat()
		KEY_PAGEDOWN, KEY_KP_SUBTRACT:
			_palier = maxi(_palier - 1, 0); _etat()
		KEY_F:
			_recadrer()
		KEY_E:
			_exporter()
		KEY_H:
			_basculer_aide()
		KEY_P:
			_reparer()

## Ce que le pinceau écrit vraiment : une famille passe en minuscule quand on
## le demande, pour poser deux bâtiments voisins sans qu'ils fusionnent.
func _caractere() -> String:
	if _minuscule and FAMILLES.contains(_pinceau):
		return _pinceau.to_lower()
	return _pinceau

func _appliquer(gauche: bool) -> void:
	if not _vise: return
	_poser(_case.x, _case.y, gauche)
	_etat()

## UNE case écrite. Tout passe par ici — la souris, les formes, le godet, la
## mini-carte et le banc — pour qu'il n'y ait qu'un seul endroit qui sache ce
## que « peindre » veut dire.
func _poser(i: int, j: int, gauche: bool) -> void:
	if not _dans_grille(i, j): return
	if _outil == OUTIL_RELIEF:
		# ⚠ ABSOLU OU RELATIF. En absolu, le pinceau POSE le palier courant —
		# c'est ce qu'il faut pour aplanir une terrasse. En relatif il monte ou
		# descend d'un cran ce qui est déjà là : c'est ce qu'il faut pour
		# creuser un vallon ou relever une rue, et sans lui il fallait relever
		# le palier de chaque case à la pipette avant de la peindre.
		var n := 0
		if _relief_relatif:
			n = clampi(_palier_de(i, j) + (1 if gauche else -1), 0, 9)
		else:
			n = _palier if gauche else maxi(0, _palier_de(i, j) - 1)
		if _palier_de(i, j) == n: return
		_ecrire("relief", i, j, str(n))
		_plus_haut = maxi(_plus_haut, n)
	else:
		var c := _caractere() if gauche else "."
		if _lire("plan", i, j) == c: return
		_ecrire("plan", i, j, c)
		# Une case qu'on sort de l'eau doit prendre le palier courant, sinon
		# elle arrive à zéro au milieu d'une terrasse.
		if gauche and not EAUX.contains(c):
			_ecrire("relief", i, j, str(_palier))
			_plus_haut = maxi(_plus_haut, _palier)
	_touchees[Vector2i(i, j)] = true
	_dalle(Vector2i(i, j), _teinte_pose(gauche))

## La couleur de l'aperçu. En relief elle éclaircit avec le palier : sinon
## trois terrasses de hauteurs différentes se ressemblent toutes.
func _teinte_pose(gauche: bool) -> Color:
	if _outil == OUTIL_RELIEF:
		var n := _palier if gauche else 0
		return Color(0.42, 0.55, 0.68).lightened(float(n) * 0.07)
	return _couleur(_caractere() if gauche else ".")

## L'aperçu : une dalle plate de la couleur du pinceau, posée tout de suite.
## Rebâtir le quartier à chaque case rendait le tracé d'une avenue impossible ;
## la dalle coûte un quad et dit exactement ce qu'on vient d'écrire.
func _dalle(c: Vector2i, teinte: Color) -> void:
	var n := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CASE * 0.92, CASE * 0.92)
	n.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
	m.albedo_color.a = 0.85
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	n.material_override = m
	n.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
		Vector3((float(c.x) + 0.5) * CASE, float(_palier_de(c.x, c.y)) * PALIER + 1.2,
			(float(c.y) + 0.5) * CASE))
	_apercu.add_child(n)

func _couleur(c: String) -> Color:
	for p in PINCEAUX:
		if String(p[0]) == c or String(p[0]).to_lower() == c:
			return p[2]
	return Color("#ff00ff")

func _finir_geste() -> void:
	if _touchees.is_empty(): return
	var cases: Array = _touchees.keys()
	_touchees.clear()
	if _ville != null:
		_ville.refaire(cases)
	for e in _apercu.get_children():
		_apercu.remove_child(e)
		e.queue_free()
	_verifier_plus_tard()
	_toucher_carte(cases)
	_etat()

## ⚠ LA VÉRIFICATION NE SUIT PAS LE PINCEAU. `Quartiers.fautes` relit les 63 536
## cases et les 16 784 bâtiments : 370 ms. Lancée au relâchement de chaque coup,
## elle collait ce prix à tous les gestes — pour une réponse dont on n'a besoin
## que quand on s'arrête. On la repousse donc à huit dixièmes de seconde après
## le DERNIER geste : en peignant d'affilée, elle ne tourne pas une seule fois.
##
## Et on le DIT pendant ce temps. Une liste de fautes qui date du geste
## précédent, sans rien qui l'indique, c'est pire que pas de liste : on corrige
## une faute déjà corrigée.
func _verifier_plus_tard() -> void:
	if _minuteur == null: return
	if _fautes_texte != null:
		_fautes_texte.text = "vérification…"
		_fautes_texte.add_theme_color_override("font_color", Palette.ENCRE_FAIBLE)
	for b in _boutons_faute:
		b.queue_free()
	_boutons_faute.clear()
	_minuteur.start(0.8)

func _montrer_curseur() -> void:
	if _curseur == null: return
	_curseur.visible = _vise
	if not _vise: return
	_curseur.position = Vector3((float(_case.x) + 0.5) * CASE,
		float(_palier_de(_case.x, _case.y)) * PALIER + 0.4, (float(_case.y) + 0.5) * CASE)
	_etat()

# ------------------------------------------------------- les formes du geste

func _choisir_forme(f: int) -> void:
	_forme = f
	_rafraichir_boutons()
	_etat()

## Les cases que couvre le geste en cours. La pipette et le godet n'ont pas de
## traînée : ils ne passent jamais par ici.
func _cases_forme() -> Array:
	var a := _depart
	var b := _case
	if _forme == FORME_LIGNE:
		return _tracer_ligne(a, b)
	if _forme == FORME_SELECTION:
		var r := _rectangle(a, b)
		var bord: Array = []
		for j in range(r.position.y, r.position.y + r.size.y):
			for i in range(r.position.x, r.position.x + r.size.x):
				if i == r.position.x or i == r.position.x + r.size.x - 1 \
						or j == r.position.y or j == r.position.y + r.size.y - 1:
					bord.append(Vector2i(i, j))
		return bord
	if _forme == FORME_CADRE or _forme == FORME_PLEIN:
		var x0 := mini(a.x, b.x)
		var x1 := maxi(a.x, b.x)
		var y0 := mini(a.y, b.y)
		var y1 := maxi(a.y, b.y)
		var pts: Array = []
		for j in range(y0, y1 + 1):
			for i in range(x0, x1 + 1):
				if _forme == FORME_PLEIN or i == x0 or i == x1 or j == y0 or j == y1:
					pts.append(Vector2i(i, j))
		return pts
	return [b]

## Bresenham. Une ligne tirée à la souris qui « saute » des cases laisse des
## trous dans l'avenue — et un trou dans une rue, le jeu le voit comme une
## impasse.
static func _tracer_ligne(a: Vector2i, b: Vector2i) -> Array:
	var pts: Array = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var c := a
	while true:
		pts.append(c)
		if c == b or pts.size() > 4000: break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			c.x += sx
		if e2 <= dx:
			err += dx
			c.y += sy
	return pts

## L'aperçu d'une forme se REFAIT à chaque mouvement — on efface d'abord. Et
## on retire les dalles tout de suite au lieu de les mettre en file : un
## `queue_free` ne prend effet qu'en fin d'image, et pendant cette image-là on
## verrait les deux rectangles à la fois.
func _apercu_forme() -> void:
	if _apercu == null: return
	for e in _apercu.get_children():
		_apercu.remove_child(e)
		e.queue_free()
	var teinte := _teinte_pose(_gauche)
	for c in _cases_forme():
		if _dans_grille(c.x, c.y):
			_dalle(c, teinte)
	_etat()

func _appliquer_forme(gauche: bool) -> void:
	for c in _cases_forme():
		_poser(c.x, c.y, gauche)
	_etat()

## LE GODET. Il remplit la tache contiguë de même valeur — le plan en dessin,
## le relief en relief. Le plafond de six mille cases n'est pas de la prudence
## théorique : une grille de cent sur cent remplie d'un coup, dans le
## navigateur, c'est une image perdue à chaque clic.
func _remplir(depart: Vector2i, gauche: bool) -> void:
	var cle := "relief" if _outil == OUTIL_RELIEF else "plan"
	var source := _lire(cle, depart.x, depart.y)
	var cible := "0"
	if _outil == OUTIL_RELIEF:
		cible = str(_palier) if gauche else "0"
	else:
		cible = _caractere() if gauche else "."
	if source == cible: return
	var vues := {}
	var file: Array = [depart]
	var n := 0
	while not file.is_empty() and n < 6000:
		var c: Vector2i = file.pop_back()
		if vues.has(c): continue
		if not _dans_grille(c.x, c.y): continue
		if _lire(cle, c.x, c.y) != source: continue
		vues[c] = true
		n += 1
		_poser(c.x, c.y, gauche)
		for d in COTES:
			file.append(c + d)
	_etat()

## LA PIPETTE. Elle reprend ce qui est SOUS le curseur — en dessin le
## caractère, en relief le palier. C'est le geste qu'on fait vingt fois par
## séance : retrouver la teinte exacte du pâté d'à côté sans la chercher des
## yeux dans la colonne.
func _prelever() -> void:
	if not _vise or not _dans_grille(_case.x, _case.y): return
	if _outil == OUTIL_RELIEF:
		_palier = _palier_de(_case.x, _case.y)
		_dire("Palier %d prélevé." % _palier)
		_etat()
		return
	var c := _lire("plan", _case.x, _case.y)
	for p in PINCEAUX:
		if String(p[0]) == c or String(p[0]).to_lower() == c:
			_minuscule = c != String(p[0])
			_choisir(String(p[0]))
			_dire("Pinceau « %s » prélevé." % _caractere())
			return

# ------------------------------------------------------------ mobilier libre

## ⚠ LE POINT DANS LA CASE VIENT DU CURSEUR, PAS DU CENTRE. Poser dix arbres
## d'affilée les empilait tous au milieu de leur case, en rangs d'oignons :
## c'est exactement ce qu'un placement à la main est censé éviter.
func _poser_objet(c: Vector2i) -> void:
	if not _dans_grille(c.x, c.y): return
	var objets: Array = _objets()
	var p := _point_dans_case()
	objets.append({"m": _modele, "i": c.x, "j": c.y,
		"x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01),
		"r": snappedf(_angle_objet, 1.0), "h": snappedf(_hauteur_objet, 0.5)})
	_fiche["objets"] = objets
	# Le dernier posé devient le CHOISI : neuf fois sur dix, le réglage qu'on
	# veut faire ensuite porte sur celui qu'on vient de poser.
	_objet_choisi = objets.size() - 1
	_apres_objets(c, "%s posé (%d en tout)" % [_modele.get_file(), objets.size()])
	_choisir_objet(_objet_choisi)

## ⚠ LE CLIC DROIT CHOISIT AVANT DE SUPPRIMER. La première version ôtait le
## DERNIER objet posé sur la case : sur une case qui en porte cinq, on ne
## savait pas lequel partait avant qu'il soit parti, et Ctrl+Z était la seule
## façon de voir ce qu'on avait fait. Maintenant le premier clic droit CHOISIT
## le plus proche du curseur — il s'allume, et le panneau montre son modèle,
## sa hauteur, son angle — et le clic droit suivant, sur le même, le supprime.
## Deux clics au lieu d'un, mais on sait ce qu'on supprime.
func _oter_objet(c: Vector2i) -> void:
	var k := _objet_ici(c)
	if k < 0:
		_choisir_objet(-1)
		_dire("Aucun objet sur cette case.")
		return
	if k != _objet_choisi:
		_choisir_objet(k)
		_dire("%s choisi — clic droit à nouveau pour le supprimer." % _nom_objet(k))
		return
	_supprimer_objet()

## L'objet de cette case le plus proche du point visé, ou -1. Le plus proche et
## non le dernier : sur une pelouse à dix arbres, c'est celui qu'on montre du
## doigt qu'on veut.
func _objet_ici(c: Vector2i) -> int:
	var objets: Array = _objets()
	var p := _point_dans_case()
	var mieux := -1
	var court := INF
	for k in objets.size():
		var o: Dictionary = objets[k]
		if int(o["i"]) != c.x or int(o["j"]) != c.y: continue
		var d := Vector2(float(o.get("x", 0.5)), float(o.get("z", 0.5))).distance_to(p)
		if d < court:
			court = d
			mieux = k
	return mieux

func _nom_objet(k: int) -> String:
	var objets: Array = _objets()
	if k < 0 or k >= objets.size(): return "?"
	return String(objets[k]["m"]).get_file()

## Choisit un objet posé : la mire va dessus, la liste s'aligne, les deux
## glissières prennent SES valeurs — sans quoi bouger la hauteur écrirait la
## valeur du pinceau sur l'objet qu'on vient de choisir.
func _choisir_objet(k: int) -> void:
	var objets: Array = _objets()
	_objet_choisi = k if (k >= 0 and k < objets.size()) else -1
	_montrer_halo()
	if _objet_choisi >= 0:
		var o: Dictionary = objets[_objet_choisi]
		if _gliss_h_objet != null:
			Atelier.poser_regle(_gliss_h_objet, float(o.get("h", 10.0)))
		if _gliss_r_objet != null:
			Atelier.poser_regle(_gliss_r_objet, float(o.get("r", 0.0)))
	if _liste_objets != null:
		var rang := _rangs_objets.find(_objet_choisi)
		if rang >= 0:
			_liste_objets.select(rang)
			_liste_objets.ensure_current_is_visible()
		else:
			_liste_objets.deselect_all()
	_etat()

func _montrer_halo() -> void:
	if _halo == null: return
	var objets: Array = _objets()
	_halo.visible = _objet_choisi >= 0 and _objet_choisi < objets.size()
	if not _halo.visible: return
	var o: Dictionary = objets[_objet_choisi]
	var c := Vector2i(int(o["i"]), int(o["j"]))
	var h := maxf(float(o.get("h", 10.0)), 2.0)
	var large := maxf(h * 0.55, 4.0)
	_halo.transform = Transform3D(
		Basis().scaled(Vector3(large, h, large)),
		Vector3((float(c.x) + float(o.get("x", 0.5))) * CASE,
			float(_palier_de(c.x, c.y)) * PALIER + 0.3,
			(float(c.y) + float(o.get("z", 0.5))) * CASE))

func _supprimer_objet() -> void:
	var objets: Array = _objets()
	if _objet_choisi < 0 or _objet_choisi >= objets.size():
		_dire("Aucun objet choisi.")
		return
	_empiler()
	var o: Dictionary = objets[_objet_choisi]
	var c := Vector2i(int(o["i"]), int(o["j"]))
	var nom := _nom_objet(_objet_choisi)
	objets.remove_at(_objet_choisi)
	_fiche["objets"] = objets
	_choisir_objet(-1)
	_apres_objets(c, "%s ôté (%d restants)" % [nom, objets.size()])

## Change une valeur de l'objet choisi et rebâtit sa case. `empiler` est faux
## pendant qu'on TIRE une glissière : empiler à chaque cran donnerait cinquante
## états d'annulation pour un seul réglage.
func _regler_objet(cle: String, valeur, empiler := true) -> void:
	var objets: Array = _objets()
	if _objet_choisi < 0 or _objet_choisi >= objets.size(): return
	if empiler: _empiler()
	var o: Dictionary = objets[_objet_choisi]
	o[cle] = valeur
	_fiche["objets"] = objets
	_montrer_halo()
	_remplir_objets()
	_apres_objets(Vector2i(int(o["i"]), int(o["j"])), "")

func _objets() -> Array:
	if not _fiche.has("objets"): _fiche["objets"] = []
	return _fiche["objets"]

func _apres_objets(c: Vector2i, message: String) -> void:
	if _ville != null: _ville.refaire([c])
	else: _rebatir()
	_remplir_objets()
	if message != "": _dire(message)
	_sauver_brouillon()
	_etat()

## Où le curseur tombe DANS sa case, en fraction. `_viser()` donne déjà le point
## d'impact ; on n'en garde que le reste.
func _point_dans_case() -> Vector2:
	var p := _impact
	return Vector2(clampf(p.x / CASE - float(_case.x), 0.05, 0.95),
		clampf(p.z / CASE - float(_case.y), 0.05, 0.95))

# ------------------------------------------------------- copier et coller

## ⚠ LE PLAN ET LE RELIEF PARTENT ENSEMBLE. Un pâté copié depuis la vieille
## ville — perchée au palier 5 — et recollé sans son relief se retrouve à plat
## au bord de l'eau : ce n'est plus le même quartier, et les bâtiments qu'on
## croyait dupliquer sortent à cheval sur deux paliers.
func _copier() -> void:
	if _selection.size == Vector2i.ZERO:
		_dire("Rien de sélectionné — forme « Sélection » (C), puis un rectangle.")
		return
	var plan: Array = []
	var relief: Array = []
	for j in range(_selection.position.y, _selection.position.y + _selection.size.y):
		var lp := ""
		var lr := ""
		for i in range(_selection.position.x, _selection.position.x + _selection.size.x):
			lp += _lire("plan", i, j)
			lr += _lire("relief", i, j)
		plan.append(lp)
		relief.append(lr)
	_presse = {"plan": plan, "relief": relief,
		"w": _selection.size.x, "h": _selection.size.y}
	_dire("Copié %d × %d — Ctrl+V, puis clic gauche pour poser." % [_selection.size.x, _selection.size.y])
	_etat()

func _coller() -> void:
	if _presse.is_empty():
		_dire("Presse-papier vide — sélectionnez (C) puis Ctrl+C.")
		return
	_collage = true
	_forme = FORME_LIBRE
	_rafraichir_boutons()
	_dire("Collage %d × %d : clic gauche pour poser, Échap pour annuler."
		% [int(_presse["w"]), int(_presse["h"])])
	_apercu_collage()

## L'aperçu du collage suit le curseur. Le coin visé est le coin HAUT-GAUCHE :
## viser le centre obligerait à calculer de tête où tombe un rectangle pair.
func _apercu_collage() -> void:
	_vider_apercu()
	if not _collage or _presse.is_empty() or not _vise: return
	var plan: Array = _presse["plan"]
	for j in plan.size():
		var ligne: String = plan[j]
		for i in ligne.length():
			var c := Vector2i(_case.x + i, _case.y + j)
			if not _dans_grille(c.x, c.y): continue
			_dalle(c, _couleur(ligne[i]))

func _poser_collage() -> void:
	if _presse.is_empty(): return
	_empiler()
	var plan: Array = _presse["plan"]
	var relief: Array = _presse["relief"]
	var n := 0
	for j in plan.size():
		var lp: String = plan[j]
		var lr: String = relief[j]
		for i in lp.length():
			var x := _case.x + i
			var y := _case.y + j
			if not _dans_grille(x, y): continue
			_ecrire("plan", x, y, lp[i])
			if i < lr.length():
				_ecrire("relief", x, y, lr[i])
				var d := lr[i]
				if d >= "0" and d <= "9": _plus_haut = maxi(_plus_haut, int(d))
			_touchees[Vector2i(x, y)] = true
			n += 1
	_collage = false
	_dire("%d cases collées." % n)
	_finir_geste()

func _vider_apercu() -> void:
	if _apercu == null: return
	for e in _apercu.get_children():
		_apercu.remove_child(e)
		e.queue_free()

## Le rectangle de sélection, tracé au sol comme le quadrillage : un aperçu en
## dalles disparaîtrait au premier geste, or une sélection doit rester visible
## pendant qu'on va chercher où la coller.
func _montrer_selection() -> void:
	if _cadre_selection != null:
		_cadre_selection.queue_free()
		_cadre_selection = null
	if _selection.size == Vector2i.ZERO or _quartier == null: return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var y := float(_plus_haut) * PALIER + 2.0
	var x0 := float(_selection.position.x) * CASE
	var z0 := float(_selection.position.y) * CASE
	var x1 := float(_selection.position.x + _selection.size.x) * CASE
	var z1 := float(_selection.position.y + _selection.size.y) * CASE
	var coins := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	for k in 4:
		im.surface_add_vertex(coins[k])
		im.surface_add_vertex(coins[(k + 1) % 4])
		im.surface_add_vertex(coins[k])
		im.surface_add_vertex(coins[k] - Vector3(0, y + 4.0, 0))
	im.surface_end()
	_cadre_selection = MeshInstance3D.new()
	_cadre_selection.mesh = im
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#ffd23f")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cadre_selection.material_override = m
	_quartier.add_child(_cadre_selection)
	if _carte2d != null: _carte2d.queue_redraw()

# ---------------------------------------------------------------- annuler

## ⚠ L'ANNULATION EMPORTE LES OBJETS. Sans eux dans l'état, Ctrl+Z après un
## arbre posé rendait le dessin d'avant ET gardait l'arbre : l'annulation
## mentait, ce qui est pire que pas d'annulation.
func _empiler() -> void:
	_pile.append({"plan": _lignes("plan").duplicate(), "relief": _lignes("relief").duplicate(),
		"objets": _objets().duplicate(true)})
	if _pile.size() > 60: _pile.pop_front()
	_refaire.clear()

func _annuler() -> void:
	if _pile.is_empty(): return
	_refaire.append({"plan": _lignes("plan").duplicate(), "relief": _lignes("relief").duplicate(),
		"objets": _objets().duplicate(true)})
	_restaurer(_pile.pop_back())

func _refaire_geste() -> void:
	if _refaire.is_empty(): return
	_pile.append({"plan": _lignes("plan").duplicate(), "relief": _lignes("relief").duplicate(),
		"objets": _objets().duplicate(true)})
	_restaurer(_refaire.pop_back())

func _restaurer(etat: Dictionary) -> void:
	_fiche["plan"] = etat["plan"]
	_fiche["relief"] = etat["relief"]
	_fiche["objets"] = etat.get("objets", [])
	# ⚠ L'OBJET CHOISI EST UN INDICE : après une annulation, le tableau n'est
	# plus le même et l'indice ne désigne plus rien. On le lâche plutôt que de
	# laisser la mire allumée sur un objet qui n'existe plus.
	if _objet_choisi >= _objets().size(): _objet_choisi = -1
	_rebatir()
	_choisir_objet(_objet_choisi)
	_remplir_objets()
	_sauver_brouillon()

# ---------------------------------------------------------------- caméra

func _process(delta: float) -> void:
	# L'aperçu de modèle tourne tant qu'on ne l'a pas attrapé à la souris : un
	# objet vu sous un seul angle, c'est une photo — et le client en a assez des
	# photos.
	if _apercu_tourne and _apercu_pivot != null:
		_apercu_azimut += delta * 0.5
		_cadrer_apercu()
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.z += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
	if d == Vector3.ZERO: return
	# On se déplace dans le repère de la CAMÉRA : après une orbite, « avant »
	# doit rester ce qu'on voit en haut de l'écran.
	var avant := Vector3(sin(_azimut), 0, cos(_azimut))
	var droite := Vector3(cos(_azimut), 0, -sin(_azimut))
	_pivot += (avant * d.z + droite * d.x) * delta * _distance * 1.1
	_poser_camera()
	if _ville != null: _ville.suivre(_pivot)

func _poser_camera() -> void:
	var oeil := _pivot + Vector3(sin(_azimut) * cos(_inclinaison), sin(_inclinaison),
		cos(_azimut) * cos(_inclinaison)) * _distance
	_camera.look_at_from_position(oeil, _pivot, Vector3.UP)

func _recadrer() -> void:
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	var angle := deg_to_rad(float(_fiche.get("angle", 0.0)))
	var centre_local := Vector3(float(_large()) * 0.5 * CASE, 0, float(_haut()) * 0.5 * CASE)
	if _pivot != Vector3.ZERO and _distance <= 80.0 * CASE:
		# Recadrer depuis un point de travail garde ce point : on veut revenir
		# au pâté qu'on dessinait, pas au milieu de l'île.
		centre_local = _quartier.global_transform.affine_inverse() * _pivot \
			if _quartier != null else centre_local
	_pivot = Vector3(org.x * CASE, 0, org.y * CASE) + Basis(Vector3.UP, angle) * centre_local
	# ⚠ ON NE CADRE PAS UNE VILLE DE DEUX KILOMÈTRES COMME UN QUARTIER DE TRENTE
	# CASES. Cadrée en entier, Pikstown demande cent soixante-neuf morceaux au
	# chargement : vingt secondes d'écran presque vide. On cadre donc au plus un
	# voisinage de cinquante-six cases, et « F » depuis un point de la ville
	# recentre là où l'on travaille. La vue d'ensemble, c'est la mini-carte —
	# elle est faite pour ça, et elle est instantanée.
	var etendue := maxf(float(_large()), float(_haut())) * CASE * 1.25
	_distance = clampf(minf(etendue, 56.0 * CASE), 200.0, 4000.0)
	_poser_camera()
	if _ville != null:
		_ville.rayon = _rayon_utile()
		_ville.suivre(_pivot)

## LA VUE DE DESSUS, calée sur l'ANGLE DU QUARTIER — pas sur le nord du monde.
## Un quartier tourné de dix-sept degrés vu à plat depuis le nord se dessine en
## escalier ; vu depuis son propre angle, la grille redevient une grille et on
## peint une avenue droite sans compenser à l'œil.
func _vue_dessus() -> void:
	_dessus = not _dessus
	if _dessus:
		_azimut_avant = _azimut
		_inclinaison_avant = _inclinaison
		_azimut = deg_to_rad(float(_fiche.get("angle", 0.0)))
		_inclinaison = 1.45
	else:
		_azimut = _azimut_avant
		_inclinaison = _inclinaison_avant
	_recadrer()
	_rafraichir_boutons()

func _basculer_grille() -> void:
	_voir_grille = not _voir_grille
	if _maillage != null: _maillage.visible = _voir_grille
	_rafraichir_boutons()

# ---------------------------------------------------------------- les fautes

## Les fautes du banc, posées SUR la case coupable. Un message dans un panneau
## se lit ; un bloc rouge sur le carrefour fautif se comprend.
## Les fautes du banc, posées SUR la case coupable — et CLIQUABLES. Sur une
## ville de 320 cases de large, « (218, 143) marche de 3 » est une adresse qu'on
## ne rejoint pas à la main : on clique la ligne, la caméra y va.
## Ce qu'on fait quand la main s'arrête : vérifier, et garder le brouillon.
##
## ⚠ LE BROUILLON AUSSI EST DIFFÉRÉ. Il fait 192 Ko de JSON — les 600 lignes du
## plan et du relief — et il était réécrit à chaque relâchement de pinceau. Le
## garder huit dixièmes de seconde après le dernier geste ne coûte rien : au
## pire on perd le dernier coup si l'onglet meurt dans cet intervalle, et c'est
## un filet de sécurité, pas une transaction.
func _au_repos() -> void:
	_montrer_fautes()
	_sauver_brouillon()

func _montrer_fautes() -> void:
	if _marques == null: return
	for e in _marques.get_children(): e.queue_free()
	for b in _boutons_faute:
		b.queue_free()
	_boutons_faute.clear()
	var liste: Array = Quartiers.fautes(_fiche)
	_fautives.clear()
	for f in liste:
		if int(f["i"]) < 0: continue
		_fautives[Vector2i(int(f["i"]), int(f["j"]))] = true
		var n := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CASE * 0.5, CASE * 1.4, CASE * 0.5)
		n.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.15, 0.15, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		n.material_override = m
		n.position = Vector3((float(f["i"]) + 0.5) * CASE,
			float(_palier_de(int(f["i"]), int(f["j"]))) * PALIER + CASE * 0.7,
			(float(f["j"]) + 0.5) * CASE)
		_marques.add_child(n)
	if _fautes_texte != null:
		# LE BANDEAU DIT L'ESSENTIEL EN GROS, et la taille de la ville en petit :
		# c'est ce qu'on regarde avant d'exporter, et le nombre de cases dit du
		# même coup si on a bien chargé ce qu'on croyait charger.
		_fautes_texte.text = "✓  PLAN PROPRE" if liste.is_empty() \
			else "✕  %d FAUTE%s" % [liste.size(), "S" if liste.size() > 1 else ""]
		_peindre_bandeau(liste.is_empty())
	if _bouton_reparer != null:
		_bouton_reparer.visible = not liste.is_empty()
	if _fautes_boite == null: return
	# QUATRE au plus : une colonne pleine de rouge repousse le pinceau hors de
	# l'écran, et on les corrige de toute façon une par une.
	for k in mini(liste.size(), 4):
		var f: Dictionary = liste[k]
		var ou := Vector2i(int(f["i"]), int(f["j"]))
		# ⚠ COURT DANS LE BOUTON, ENTIER DANS L'INFOBULLE. « marche de 3 : le kit
		# monte de deux paliers au pl… » : rogné, un libellé ne dit plus rien —
		# et à trois cent vingt pixels de colonne, tout ce qui dépasse est rogné.
		var court := String(f["texte"]).split(" :")[0].split(" au pied")[0]
		var b := UI.bouton("(%d,%d)  %s" % [ou.x, ou.y, court] if ou.x >= 0
			else String(f["texte"]).substr(0, 34))
		_petit(b)
		b.tooltip_text = String(f["texte"]) + "\n(cliquer pour s'y rendre)"
		b.add_theme_color_override("font_color", Palette.CRITIQUE)
		b.add_theme_color_override("font_hover_color", Palette.ENCRE)
		if ou.x >= 0:
			b.pressed.connect(_aller_a.bind(ou))
		_fautes_boite.add_child(b)
		_boutons_faute.append(b)
	if liste.size() > 4:
		var reste := UI.texte("… et %d autre(s)." % (liste.size() - 4), 12, Palette.CRITIQUE)
		_fautes_boite.add_child(reste)
		_boutons_faute.append(reste)

# ---------------------------------------------------------------- réparer

## RÉPARER LE RELIEF.
##
## ⚠ C'EST LA RÉPONSE À « JE N'ARRIVE PAS À GÉRER LES HAUTEURS ». Les trois
## règles de `Quartiers.fautes` ne disent pas ce qu'il FAUT faire, elles disent
## ce qui ne va pas — et corriger une marche à la main en recrée souvent deux
## plus loin. Ce bouton résout le système d'un coup.
##
## ⚠ RÉPARER, C'EST RABOTER — JAMAIS REMBLAYER. Chaque marche interdite se règle
## en BAISSANT la case trop haute, jamais en montant sa voisine. Deux raisons :
## baisser TERMINE (les paliers sont bornés par zéro, donc la boucle ne peut pas
## tourner sans fin), alors que monter peut courir jusqu'en haut de la grille en
## tirant tout le quartier derrière soi ; et c'est le geste qu'on ferait à la
## main — on rabote la marche, on ne surélève pas la rue.
##
## Les trois règles, dans l'ordre où elles se corrigent :
##  1. un BLOC DE LETTRES tient sur un seul palier — on prend le plus bas ;
##  2. une RUE ne monte de plus de deux paliers que dans le sens de la voie, et
##     jamais au pied d'un croisement (le kit n'a pas de carrefour en pente) ;
##  3. un ROND-POINT veut trois cases sur trois au même palier.
## Elles se contredisent : aplanir un bâtiment peut créer une marche de rue.
## D'où les passes — on recommence jusqu'à ce que plus rien ne bouge.
const REPARE_PASSES := 40

func _reparer() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var carte: CarteVille = Quartiers.carte_de(_fiche)
	# Le PLAN ne change pas : masques de raccord, blocs bâtis et ronds-points se
	# calculent UNE fois, hors des passes. Recalculer `batiments()` à chaque
	# passe, c'est quarante balayages de soixante mille caractères.
	var routes: Array[Vector2i] = []
	var masques: Dictionary = {}
	for c in carte.cases.keys():
		if not carte.route(c) or carte.case_prise(c): continue
		routes.append(c)
		masques[c] = carte.masque(c)
	var t_carte := Time.get_ticks_msec() - t0
	var blocs: Array = Quartiers.batiments(_lignes("plan"))
	var ronds: Array[Vector2i] = []
	var courbes: Array[Vector2i] = []
	var rampes: Array[Vector2i] = []
	var lignes: Array = _lignes("plan")
	for j in lignes.size():
		var t: String = lignes[j]
		for i in t.length():
			if t[i] == "O": ronds.append(Vector2i(i, j))
			elif t[i] == "(": courbes.append(Vector2i(i, j))
			elif t[i] == "/": rampes.append(Vector2i(i, j))
	# ⚠ UNE LISTE DE TRAVAIL, PAS ONZE BALAYAGES COMPLETS. La première version
	# repassait sur les 16 800 blocs et les 18 000 rues à CHAQUE passe : onze
	# passes à 124 ms, alors que dès la deuxième il ne bouge plus qu'une
	# poignée de cases. On indexe donc case → bloc et case → rond-point une
	# fois, et les passes suivantes ne regardent que le voisinage de ce qui a
	# bougé. L'index coûte un balayage ; il en économise dix.
	var bloc_de: Dictionary = {}
	for k in blocs.size():
		var b: Dictionary = blocs[k]
		for a in int(b["w"]):
			for d in int(b["h"]):
				var cle := Vector2i(int(b["i"]) + a, int(b["j"]) + d)
				if bloc_de.has(cle): bloc_de[cle].append(k)
				else: bloc_de[cle] = [k]
	var rond_de: Dictionary = {}
	for k in ronds.size():
		var o: Vector2i = ronds[k]
		for a in [-1, 0, 1]:
			for d in [-1, 0, 1]:
				var cle2 := o + Vector2i(a, d)
				if rond_de.has(cle2): rond_de[cle2].append(k)
				else: rond_de[cle2] = [k]
	# La bretelle veut son carré de plain-pied comme le rond-point, mais elle
	# veut aussi ses DEUX BOUTS au même palier qu'elle : le voisinage à
	# surveiller déborde donc d'une case autour du 2 x 2.
	var courbe_de: Dictionary = {}
	for k in courbes.size():
		var o: Vector2i = courbes[k]
		for a in range(-1, 3):
			for d in range(-1, 3):
				var cle3 := o + Vector2i(a, d)
				if courbe_de.has(cle3): courbe_de[cle3].append(k)
				else: courbe_de[cle3] = [k]
	var t_blocs := Time.get_ticks_msec() - t0 - t_carte

	_empiler()
	var bouges := 0
	var passes := 0
	var deplacees: Dictionary = {}          ## tout ce qui a changé, pour le rebâti
	# La première passe regarde TOUT ; les suivantes ne regardent que le
	# voisinage de ce qui vient de bouger.
	var voir_blocs: Array = range(blocs.size())
	var voir_routes: Array = routes
	var voir_ronds: Array = range(ronds.size())
	var voir_courbes: Array = range(courbes.size())
	for _p in REPARE_PASSES:
		passes += 1
		var bouge: Dictionary = {}
		# 1. UN BLOC DE LETTRES TIENT SUR UN PALIER.
		for k in voir_blocs:
			var b: Dictionary = blocs[k]
			var mn := 99
			for a in int(b["w"]):
				for d in int(b["h"]):
					mn = mini(mn, _palier_de(int(b["i"]) + a, int(b["j"]) + d))
			if mn > 9: continue
			for a in int(b["w"]):
				for d in int(b["h"]):
					var i: int = int(b["i"]) + a
					var j: int = int(b["j"]) + d
					if _palier_de(i, j) != mn:
						_ecrire("relief", i, j, str(mn))
						bouge[Vector2i(i, j)] = true
		# 2. LES MARCHES DE RUE.
		for c in voir_routes:
			if not masques.has(c): continue
			var m: int = masques[c]
			var n := _palier_de(c.x, c.y)
			for k in 4:
				var v: Vector2i = c + CarteVille.COTES[k]
				if not carte.route(v): continue
				var ecart := _palier_de(v.x, v.y) - n
				if ecart <= 0: continue
				var selon_axe := ((m & 5) == 0 and (k == 1 or k == 3)) \
					or ((m & 10) == 0 and (k == 0 or k == 2))
				var permis := 2 if selon_axe else 0
				if ecart > permis:
					_ecrire("relief", v.x, v.y, str(n + permis))
					bouge[v] = true
		# 3. UN ROND-POINT VEUT SON CARRÉ DE PLAIN-PIED.
		for k in voir_ronds:
			var o: Vector2i = ronds[k]
			var mn2 := 99
			for a in [-1, 0, 1]:
				for d in [-1, 0, 1]:
					mn2 = mini(mn2, _palier_de(o.x + a, o.y + d))
			if mn2 > 9: continue
			for a in [-1, 0, 1]:
				for d in [-1, 0, 1]:
					if _palier_de(o.x + a, o.y + d) != mn2:
						_ecrire("relief", o.x + a, o.y + d, str(mn2))
						bouge[o + Vector2i(a, d)] = true
		# 4. UNE BRETELLE AUSSI. Son carré de 2 x 2 ET les deux cases par où la
		# rue y entre : la pièce est refusée si l'un des six n'est pas au même
		# palier, et une bretelle refusée, c'est un trou dans la ville.
		for k in voir_courbes:
			var o3: Vector2i = courbes[k]
			var vus: Array[Vector2i] = []
			for a in 2:
				for d in 2:
					vus.append(o3 + Vector2i(a, d))
			var q3 := CarteVille.quarts_courbe(carte, o3, true)
			if q3 >= 0:
				var b3: Array = CarteVille.COURBE_BOUTS[q3]
				vus.append(o3 + b3[0] + b3[1])
				vus.append(o3 + b3[2] + b3[3])
			var mn3 := 99
			for c3 in vus:
				mn3 = mini(mn3, _palier_de(c3.x, c3.y))
			if mn3 > 9: continue
			for c3 in vus:
				if _palier_de(c3.x, c3.y) != mn3:
					_ecrire("relief", c3.x, c3.y, str(mn3))
					bouge[c3] = true
		bouges += bouge.size()
		if bouge.is_empty(): break
		for c in bouge.keys(): deplacees[c] = true
		# LE VOISINAGE DE CE QUI A BOUGÉ : le bloc et le rond-point qui couvrent
		# la case, la case elle-même et ses quatre voisines en tant que rues —
		# baisser une case peut violer la contrainte vue depuis sa voisine.
		var b2: Dictionary = {}
		var r2: Dictionary = {}
		var v2: Dictionary = {}
		var c2: Dictionary = {}
		for c in bouge.keys():
			for k in bloc_de.get(c, []): b2[k] = true
			for k in rond_de.get(c, []): r2[k] = true
			for k in courbe_de.get(c, []): c2[k] = true
			v2[c] = true
			for d in CarteVille.COTES: v2[c + d] = true
		voir_blocs = b2.keys()
		voir_ronds = r2.keys()
		voir_courbes = c2.keys()
		voir_routes = v2.keys()

	# ⚠ CE QUI NE TIENT PLUS REDEVIENT UNE RUE. Le rabot ne fait que DESCENDRE
	# le terrain : il peut donc rendre impossible une rampe douce, qui exige
	# exactement deux paliers d'écart. Laisser son `/` dans le dessin, c'est
	# laisser une faute que le rabot ne saura jamais réparer et qu'on relance en
	# boucle. On rend donc la case à la rue ordinaire : la ville reste juste, et
	# le dessinateur voit dans le diff ce qu'il a perdu.
	var rendues := 0
	if bouges > 0:
		for o4 in courbes:
			if _bretelle_tient(o4): continue
			_ecrire("plan", o4.x, o4.y, "#")
			deplacees[o4] = true
			rendues += 1
		for o5 in rampes:
			if _rampe_tient(o5): continue
			_ecrire("plan", o5.x, o5.y, "#")
			deplacees[o5] = true
			rendues += 1
	var t_passes := Time.get_ticks_msec() - t0 - t_carte - t_blocs
	_remesurer()
	# ⚠ ON REBÂTIT CE QUI A BOUGÉ, PAS LA VILLE. `_rebatir()` refait le décor
	# entier : 1,7 s, soit la moitié du prix du rabot pour redessiner des
	# quartiers auxquels on n'a pas touché. `refaire()` est le chemin du coup de
	# pinceau — le même, et il ne refait que les morceaux concernés.
	if not deplacees.is_empty():
		if _ville != null:
			_ville.refaire(deplacees.keys())
		else:
			_rebatir()
		_toucher_carte(deplacees.keys())
	_montrer_fautes()
	_redessiner_carte()
	_etat()
	var t_rebatir := Time.get_ticks_msec() - t0 - t_carte - t_blocs - t_passes
	var reste: int = Quartiers.fautes(_fiche).size()
	var mesures := {"bouges": bouges, "rendues": rendues, "passes": passes, "carte": t_carte,
		"blocs": t_blocs, "passes_ms": t_passes, "rebatir": t_rebatir,
		"total": Time.get_ticks_msec() - t0, "reste": reste}
	if bouges == 0 and rendues == 0:
		_dire("Rien à raboter : le relief tient déjà les trois règles.")
	elif reste == 0:
		_dire("Réparé : %d case(s) rabotée(s) en %d passe(s)%s, %d ms." % [
			bouges, passes,
			"" if rendues == 0 else ", %d pièce(s) rendue(s) à la rue" % rendues,
			Time.get_ticks_msec() - t0])
	else:
		# ⚠ ON LE DIT PLUTÔT QUE DE FAIRE SEMBLANT. Une faute qui ne vient pas du
		# relief — un rond-point qui n'a pas la place, un bâtiment posé sur
		# l'eau — ne se rabote pas : elle se redessine.
		_dire("%d case(s) rabotée(s), mais %d faute(s) restent : elles ne viennent pas du relief." % [
			bouges, reste])
	return mesures

## ⚠ ON RELIT LE DESSIN, PAS UNE CARTE. Savoir si une grosse pièce tient encore
## après un coup de rabot demandait jusqu'ici un `Quartiers.carte_de` complet —
## 1,8 s sur Pikstown, pour une question qui ne porte que sur six cases. Les
## deux fonctions ci-dessous répondent en lisant les caractères et les paliers,
## et elles disent EXACTEMENT ce que disent `CarteVille.quarts_courbe` et
## `Quartiers._rampe_douce` ; si l'une des deux change, celles-ci changent.
func _roule(i: int, j: int) -> bool:
	return _dans_grille(i, j) and CHAUSSEE.contains(_lire("plan", i, j))

func _bretelle_tient(o: Vector2i) -> bool:
	var n := _palier_de(o.x, o.y)
	for a in 2:
		for d in 2:
			var c := o + Vector2i(a, d)
			if not _dans_grille(c.x, c.y) or not _terre(c.x, c.y) \
					or _palier_de(c.x, c.y) != n: return false
	for q in 4:
		var b: Array = CarteVille.COURBE_BOUTS[q]
		var un: Vector2i = o + b[0] + b[1]
		var deux: Vector2i = o + b[2] + b[3]
		if _roule(un.x, un.y) and _palier_de(un.x, un.y) == n \
				and _roule(deux.x, deux.y) and _palier_de(deux.x, deux.y) == n:
			return true
	return false

func _rampe_tient(o: Vector2i) -> bool:
	var n := _palier_de(o.x, o.y)
	for d in CarteVille.COTES:
		var v: Vector2i = o + d
		if _roule(v.x, v.y) and _palier_de(v.x, v.y) == n + 2: return true
	return false

# ---------------------------------------------------------------- agrandir

## Agrandir par un bord. Vers le NORD ou l'OUEST, la grille pousse ET l'origine
## recule d'autant : sans ça le quartier se déplacerait dans le monde à chaque
## rangée ajoutée, et les ponts ne tomberaient plus en face.
func _agrandir(cote: String) -> void:
	_empiler()
	var l := _large()
	var lignes: Array = _lignes("plan")
	var reliefs: Array = _lignes("relief")
	match cote:
		"est":
			for j in lignes.size():
				lignes[j] = String(lignes[j]).rpad(l + 1, ".")
				reliefs[j] = String(reliefs[j]).rpad(l + 1, "0")
		"ouest":
			for j in lignes.size():
				lignes[j] = "." + String(lignes[j])
				reliefs[j] = "0" + String(reliefs[j])
			_fiche["origine"] = (_fiche["origine"] as Vector2) - Vector2(1, 0)
		"sud":
			lignes.append(".".repeat(l))
			reliefs.append("0".repeat(l))
		"nord":
			lignes.insert(0, ".".repeat(l))
			reliefs.insert(0, "0".repeat(l))
			_fiche["origine"] = (_fiche["origine"] as Vector2) - Vector2(0, 1)
	_rebatir()
	_sauver_brouillon()

func _tourner(pas: float) -> void:
	_fiche["angle"] = snappedf(float(_fiche.get("angle", 0.0)) + pas, 0.5)
	_rebatir()
	_sauver_brouillon()

func _deplacer(pas: Vector2) -> void:
	_fiche["origine"] = (_fiche.get("origine", Vector2.ZERO) as Vector2) + pas
	_rebatir()
	_sauver_brouillon()

## Un quartier NEUF : une grille vide posée à côté du courant, tournée
## autrement. On garde les teintes et les hauteurs du quartier d'où l'on part —
## il est plus rapide de les corriger que de les retaper.
func _nouveau() -> void:
	var modele: Dictionary = _fiche.duplicate(true)
	modele["nom"] = "Quartier neuf"
	modele["angle"] = snappedf(float(_fiche.get("angle", 0.0)) + 17.0, 0.5)
	modele["origine"] = (_fiche.get("origine", Vector2.ZERO) as Vector2) + Vector2(float(_large()) + 4.0, 6.0)
	modele["graine"] = randi() % 9000 + 1
	var plan: Array = []
	var relief: Array = []
	for j in 12:
		plan.append(",".repeat(16))
		relief.append("0".repeat(16))
	modele["plan"] = plan
	modele["relief"] = relief
	_id = "neuf"
	_fiche = modele
	_pile.clear(); _refaire.clear()
	_rebatir()
	_recadrer()
	_sauver_brouillon()
	_dire("Quartier neuf. Dessine-le, puis « Exporter » et colle le bloc dans Quartiers.CATALOGUE.")

# ------------------------------------------------------------- le brouillon

## LE TRAVAIL EN COURS, gardé à côté du catalogue — jamais à sa place. En
## ligne, `user://` est l'IndexedDB du navigateur : fermer l'onglet ne coûte
## plus rien. Mais un brouillon N'EST PAS une source de vérité : il n'y a que
## le plan et le relief dedans, et « Recharger » le jette.
func _chemin_brouillon(id: String) -> String:
	return "user://brouillon_%s.json" % id

func _sauver_brouillon() -> void:
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	var d := {
		"nom": String(_fiche.get("nom", _id)),
		"angle": float(_fiche.get("angle", 0.0)),
		"origine": [org.x, org.y],
		"graine": int(_fiche.get("graine", 1)),
		"plan": _lignes("plan"),
		"relief": _lignes("relief"),
	}
	var f := FileAccess.open(_chemin_brouillon(_id), FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(d))
	f.close()

## ⚠ UN BANC NE REPREND JAMAIS UN BROUILLON. L'éditeur garde le travail en
## cours dans `user://` — ce qu'on veut en séance, et ce qu'on ne veut SURTOUT
## pas dans un banc : le banc du réseau tournait sur le dessin gribouillé par
## le banc du rabot de la veille, trouvait onze morceaux coupés dans une ville
## qui n'en a qu'un, et accusait le code. Un banc part du CATALOGUE.
static func _sous_banc() -> bool:
	for a in OS.get_cmdline_args():
		if a.begins_with("--essai") or a == "--gacher" or a == "--recensement" \
				or a == "--inventaire" or a == "--semis":
			return true
	return false

func _reprendre_brouillon() -> bool:
	if _sous_banc(): return false
	var chemin := _chemin_brouillon(_id)
	if not FileAccess.file_exists(chemin): return false
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null: return false
	var brut := f.get_as_text()
	f.close()
	var d = JSON.parse_string(brut)
	if typeof(d) != TYPE_DICTIONARY: return false
	if not d.has("plan") or not d.has("relief"): return false
	var plan: Array = []
	for l in d["plan"]: plan.append(String(l))
	var relief: Array = []
	for l in d["relief"]: relief.append(String(l))
	if plan.is_empty() or relief.size() != plan.size(): return false
	_fiche["plan"] = plan
	_fiche["relief"] = relief
	_fiche["angle"] = float(d.get("angle", _fiche.get("angle", 0.0)))
	var o: Array = d.get("origine", [])
	if o.size() == 2: _fiche["origine"] = Vector2(float(o[0]), float(o[1]))
	if d.has("graine"): _fiche["graine"] = int(d["graine"])
	return true

func _recharger() -> void:
	var chemin := _chemin_brouillon(_id)
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)
	_charger(_id)
	_dire("Rechargé depuis le catalogue — le brouillon est jeté.")

# ---------------------------------------------------------------- l'export

## LE BLOC À RECOLLER dans `Quartiers.CATALOGUE`. C'est la sortie de
## l'éditeur : pas un fichier à part, le texte exact du catalogue. On le met au
## presse-papier ET dans une fenêtre — dans le navigateur, l'écriture du
## presse-papier passe, sa lecture non, et il faut pouvoir sélectionner à la
## main.
## ⚠ CE QUE L'ÉDITEUR REND DÉPEND DE L'ENDROIT OÙ LE DESSIN VIT. Tant qu'un
## quartier tenait en trente lignes, il vivait dans `Quartiers.CATALOGUE` et on
## recollait un bloc de dictionnaire. Pikstown fait 300 lignes de 320
## caractères : le dessin a son propre fichier (`PlanPikstown`), et un bloc de
## catalogue ne se recolle plus nulle part. On ressort donc LE FICHIER ENTIER,
## prêt à écraser `jeux/carnage/pikstown.gd`.
##
## La fiche (nom, origine, angle, graine, teintes, hauteurs) reste dans le
## catalogue et ne bouge presque jamais : elle a son propre bouton.
func _texte_source() -> String:
	var classe := String(_fiche.get("source", ""))
	var t := "class_name %s\n" % classe
	t += "extends RefCounted\n"
	t += "## LE DESSIN DE %s — %d x %d cases.\n" % [_fiche.get("nom", _id), _large(), _haut()]
	t += "##\n"
	t += "## Un caractère par case, le vocabulaire de `Quartiers`. Ressorti par\n"
	t += "## l'éditeur (`?ecran=editeur`) : ce fichier EST ce qu'on a dessiné.\n"
	t += "\n"
	t += "const LARGE := %d\n" % _large()
	t += "const HAUT := %d\n\n" % _haut()
	for cle in [["plan", "PLAN"], ["relief", "RELIEF"]]:
		t += "const %s: Array[String] = [\n" % cle[1]
		for ligne in _lignes(String(cle[0])):
			t += "\t\"%s\",\n" % String(ligne)
		t += "]\n\n"
	# ⚠ LE MOBILIER LIBRE SORT AVEC LE DESSIN. Sans lui, une heure de placement
	# à la main disparaît au premier export — et rien ne le dirait.
	t += "## Le mobilier posé à la main : un modèle, une case, un point dans la\n"
	t += "## case, un angle en degrés, une hauteur en unités. Voir\n"
	t += "## `Quartiers._poser_objets`.\n"
	t += "const OBJETS: Array[Dictionary] = [\n"
	for o in _objets():
		t += "\t{\"m\": \"%s\", \"i\": %d, \"j\": %d, \"x\": %s, \"z\": %s, \"r\": %s, \"h\": %s},\n" % [
			o["m"], int(o["i"]), int(o["j"]), _nombre(float(o.get("x", 0.5))),
			_nombre(float(o.get("z", 0.5))), _nombre(float(o.get("r", 0.0))),
			_nombre(float(o.get("h", 10.0)))]
	t += "]\n"
	return t

func _texte_fiche() -> String:
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	var t := "\t\"%s\": {\n" % _id
	t += "\t\t\"nom\": \"%s\", \"origine\": Vector2(%s, %s), \"angle\": %s, \"graine\": %d,\n" % [
		_fiche.get("nom", _id), _nombre(org.x), _nombre(org.y),
		_nombre(float(_fiche.get("angle", 0.0))), int(_fiche.get("graine", 1))]
	t += "\t\t\"herbe\": Color(\"%s\"), \"roche\": Color(\"%s\"),\n" % [
		"#" + (_fiche.get("herbe", Color.WHITE) as Color).to_html(false),
		"#" + (_fiche.get("roche", Color.WHITE) as Color).to_html(false)]
	var h: Dictionary = _fiche.get("hauteurs", {})
	var morceaux: Array[String] = []
	for cle in h.keys():
		morceaux.append("\"%s\": [%s, %s]" % [cle, _nombre(float(h[cle][0])), _nombre(float(h[cle][1]))])
	t += "\t\t\"hauteurs\": {%s},\n" % ", ".join(morceaux)
	if String(_fiche.get("source", "")) != "":
		t += "\t\t\"objets\": %s.OBJETS,\n" % String(_fiche["source"])
	for cle in ["plan", "relief"]:
		t += "\t\t\"%s\": [\n" % cle
		for ligne in _lignes(cle):
			t += "\t\t\t\"%s\",\n" % String(ligne)
		t += "\t\t],\n"
	return t + "\t},\n"

static func _nombre(v: float) -> String:
	return ("%d" % int(v)) + (".0" if absf(v - float(int(v))) < 0.001 else "") \
		if absf(v - roundf(v)) < 0.001 else ("%.1f" % v)

## `E` sort LE DESSIN ; le bouton « Fiche » sort les quelques lignes de
## catalogue. C'est le dessin qu'on modifie cent fois par séance.
func _exporter() -> void:
	if String(_fiche.get("source", "")) != "":
		_sortir(_texte_source(), "pikstown.gd", "à écraser dans jeux/carnage/")
	else:
		_sortir(_texte_fiche(), "quartier_%s.txt" % _id, "à recoller dans Quartiers.CATALOGUE")

func _exporter_fiche() -> void:
	_sortir(_texte_fiche(), "fiche_%s.txt" % _id, "à recoller dans Quartiers.CATALOGUE")

func _sortir(t: String, nom: String, ou: String) -> void:
	DisplayServer.clipboard_set(t)
	var f := FileAccess.open("user://" + nom, FileAccess.WRITE)
	if f != null:
		f.store_string(t); f.close()
	_dire("%s copié (%d caractères) — %s" % [nom, t.length(), ou])
	_montrer_texte(t)

var _boite: Window
var _zone: TextEdit

func _montrer_texte(t: String) -> void:
	if _boite == null:
		_boite = Window.new()
		_boite.size = Vector2i(860, 560)
		_boite.title = "Déjà dans le presse-papier — sélectionnable ici au besoin"
		_boite.close_requested.connect(func(): _boite.hide())
		_zone = TextEdit.new()
		_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boite.add_child(_zone)
		interface().add_child(_boite)
	_zone.text = t
	_boite.popup_centered()

# ---------------------------------------------------------------- interface

var _etiquette: Label
var _bandeau: PanelContainer
var _aide_panneau: PanelContainer
var _atelier: VBoxContainer
var _bouton_atelier: Button
var _bouton_reparer: Button
var _reglette: Control
## LE NAVIGATEUR DE MODÈLES. Cinq cent quatre-vingt-neuf `.glb` : ça ne se pose
## pas en boutons, ça se cherche. La liste, le filtre, le dossier, et l'aperçu
## qui tourne.
var _modele := "kenney/nature/tree_oak"
var _hauteur_objet := 12.0
var _angle_objet := 0.0
## ⚠ L'OBJET CHOISI EST UN INDICE DANS `_objets()`, pas une copie. Une copie
## aurait été plus commode à lire et se serait désynchronisée au premier
## Ctrl+Z : l'annulation remplace le tableau entier.
## ─────────────────────────────── LE SEMIS ───────────────────────────────
## ⚠ « L'objet se pose au clic » RESTE VRAI — pour un objet. Mais une allée de
## quarante platanes ou une rangée de lampadaires posée un clic à la fois, ce
## n'est pas du placement à la main, c'est de la saisie. Le semis est donc un
## MODE EXPLICITE, avec son pas et sa dispersion : on ne l'attrape pas par
## accident en traînant la souris, on l'allume quand on veut une haie.
var _semer := false
var _pas_semis := 1.0                    ## en cases, d'un objet au suivant
var _dispersion := 0.6                   ## écart au trait, en cases
var _variation := 0.25                   ## variation de taille, en part de 1
var _angle_libre := true                 ## chaque objet tourné au hasard
## ⚠ ET ON NE SÈME PAS SUR LA CHAUSSÉE. Le trait qu'on tire longe presque
## toujours une rue ; un pas sur trois tombait dessus, et l'on passait ensuite
## plus de temps à ôter les arbres du milieu du boulevard qu'on n'en avait
## gagné à les semer. Le semis saute donc les cases de voirie — sauf si on le
## veut vraiment, pour une rangée de plots ou de cônes de chantier.
var _semis_hors_voirie := true
var _dernier_semis := Vector3.ZERO
var _semes := 0
var _alea_semis := RandomNumberGenerator.new()

var _objet_choisi := -1
var _halo: MeshInstance3D
var _liste_objets: ItemList
var _filtre_objets: LineEdit
var _compte_objets: Label
var _rangs_objets: Array[int] = []       ## ligne de la liste -> indice réel
var _gliss_h_objet: HSlider
var _gliss_r_objet: HSlider
var _liste_modeles: ItemList
var _filtre_modeles: LineEdit
var _choix_dossier: OptionButton
var _dossiers: Array[String] = []
var _visibles: Array[String] = []
var _apercu3d: SubViewport
var _apercu_pivot: Node3D
var _apercu_cam: Camera3D
var _apercu_azimut := 0.7
var _apercu_tourne := true
var _etiquette_modele: Label
var _bouton_objet: Button
var _blocs: Dictionary = {}              ## titre -> [en-tête, corps]
var _boutons_famille: Array[Button] = []
var _famille := 1                       ## l'onglet de pinceaux montré (Voirie)
var _apercu_image: TextureRect
var _apercu_nom: Label
var _apercu_touche: Label
var _aide: Label
var _message: Label
var _fautes_texte: Label
var _fautes_boite: VBoxContainer
var _boutons_faute: Array[Control] = []
var _minuteur: Timer
var _boutons: Array[Button] = []
var _boutons_forme: Array[Button] = []
var _choix_quartier: OptionButton
var _bouton_relief: Button
var _bouton_dessin: Button
var _bouton_grille: Button
var _bouton_dessus: Button
var _bouton_relatif: Button
var _bouton_carte_relief: Button
var _carte2d: Control
var _carte_pas := 1.0
var _carte_org := Vector2.ZERO
var _carte_image: ImageTexture
var _carte_img: Image
## La couleur d'un caractère, cherchée UNE fois. `_couleur()` parcourt les
## dix-neuf pinceaux à chaque appel : sur une carte de 96 000 cases repeinte en
## entier, ça fait presque deux millions de comparaisons de chaînes.
var _teintes: Dictionary = {}

## Un bouton de la colonne. Deux choses à savoir : il ne doit JAMAIS réclamer
## plus de largeur que la colonne — sinon c'est lui qui décide de la taille du
## panneau — et les marges de la charte (dix-huit pixels de chaque côté) sont
## faites pour des boutons d'accueil, pas pour dix-neuf pinceaux sur deux
## colonnes. On les resserre ici, et seulement ici.
## ⚠ TOUS LES BOUTONS DE L'ÉDITEUR PASSENT PAR ICI, et c'est le seul endroit
## qui connaît `Atelier`. Le jour où l'on veut revenir à la charte de jeu, on
## change ces deux fonctions et rien d'autre.
func _petit(b: Button) -> Button:
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 22)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", Atelier.police())
	b.add_theme_font_size_override("font_size", Atelier.CORPS)
	b.add_theme_constant_override("h_separation", 6)
	_teinter(b, false)
	return b

## L'ÉTAT D'UN BOUTON SE PEINT, il ne se déclare pas. La première version
## fabriquait le pinceau courant en « bouton principal » et changeait ensuite
## `button_pressed` — sur un bouton qui n'est pas en mode bascule, cela ne
## repeint rien : le surlignage restait collé sur « Rue » quoi qu'on clique.
func _teinter(b: Button, actif: bool) -> void:
	Atelier.peindre(b, actif)

## ⚠ LA VRAIE IMAGE DU PINCEAU, PHOTOGRAPHIÉE. `outils/vignettes.gd` bâtit une
## parcelle avec CE pinceau — par `Quartiers.batir_fiche`, la fonction du jeu —
## et la photographie. Un carré de couleur dit « du orange » ; la vignette dit
## « des conteneurs empilés et une cuve », et c'est ce qu'on cherche quand on
## hésite entre « Dépôt » et « Chantier ». C'est le geste des repaires, où
## aucune affirmation sur un modèle n'est admise sans photo.
##
## La pastille de couleur reste le SECOURS : si les vignettes n'ont pas été
## engendrées, la colonne garde ses repères de couleur au lieu de se vider.
static func _vignette(c: String) -> Texture2D:
	var chemin := "res://images/pinceaux/p%d.png" % c.unicode_at(0)
	if ResourceLoader.exists(chemin):
		return load(chemin) as Texture2D
	return null

## La pastille de couleur d'un pinceau. Un caractère et un mot ne disent pas de
## quelle couleur sera la case ; la mini-carte, elle, ne parle QUE couleur —
## sans pastille dans la colonne, les deux ne se répondent pas.
static func _pastille(c: Color) -> ImageTexture:
	var cote := 14
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var bord := Color(0, 0, 0, 0.65)
	for k in cote:
		img.set_pixel(k, 0, bord)
		img.set_pixel(k, cote - 1, bord)
		img.set_pixel(0, k, bord)
		img.set_pixel(cote - 1, k, bord)
	return ImageTexture.create_from_image(img)

func _rang_texte(boite: VBoxContainer, titre: String) -> HBoxContainer:
	boite.add_child(UI.texte(titre, 12, Palette.ENCRE_FAIBLE))
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 4)
	boite.add_child(rang)
	return rang

## ⚠ UN EN-TÊTE DE SECTION SE VOIT OU NE SERT À RIEN. Les titres de la première
## version étaient au même corps que les libellés — onze pixels de police pixel,
## en gris — si bien qu'un panneau de neuf sections se lisait comme une seule
## liste de trente boutons. Ici : la police de lecture (vingt-deux), de l'encre
## franche, et une barre d'accent à gauche. Ça coûte vingt pixels par section et
## ça rend la colonne parcourable à l'œil.
## ⚠ UNE SECTION REPLIABLE, PAS UN TITRE. Blender range ses réglages en
## panneaux qu'on ouvre et qu'on ferme, et c'est le seul moyen de tenir dix
## sections dans une colonne sans la faire défiler. Les titres à barre d'accent
## de la version d'avant étaient déjà mieux qu'un gris de onze pixels, mais ils
## ne fermaient rien : la palette restait à sept cents pixels du haut.
##
## Retourne le CORPS — c'est là qu'on ajoute le contenu.
func _bloc(colonne: VBoxContainer, titre: String, ouvert := true) -> VBoxContainer:
	var tete := Atelier.entete(titre)
	colonne.add_child(tete)
	var corps := VBoxContainer.new()
	corps.add_theme_constant_override("separation", 4)
	corps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.visible = ouvert
	colonne.add_child(corps)
	tete.pressed.connect(func():
		corps.visible = not corps.visible
		Atelier.plier(tete, titre, corps.visible))
	Atelier.plier(tete, titre, ouvert)
	_blocs[titre] = [tete, corps]
	return corps

## Ouvre un bloc et ferme celui qu'il remplace : choisir l'outil « Objet » sans
## dérouler les modèles, ce serait choisir un outil sans son réglage.
func _ouvrir_bloc(titre: String, ouvert: bool) -> void:
	if not _blocs.has(titre): return
	var t: Button = _blocs[titre][0]
	var c: VBoxContainer = _blocs[titre][1]
	c.visible = ouvert
	Atelier.plier(t, titre, ouvert)

func _rang(corps: VBoxContainer) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 3)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(r)
	return r

## LE BANDEAU DE VÉRIFICATION. Vert quand le plan est propre, rouge quand il ne
## l'est pas — et de loin, c'est la seule chose qu'on regarde avant d'exporter.
func _peindre_bandeau(bon: bool) -> void:
	if _bandeau == null: return
	var teinte := Atelier.VERT if bon else Atelier.ROUGE
	_bandeau.add_theme_stylebox_override("panel",
		Atelier.boite(Color(teinte.r, teinte.g, teinte.b, 0.22), teinte))
	_fautes_texte.add_theme_color_override("font_color", teinte.lightened(0.30))

func _basculer_aide() -> void:
	if _aide_panneau == null: return
	_aide_panneau.visible = not _aide_panneau.visible

func _interface() -> void:
	var couche := interface()
	var colonne := Atelier.panneau(Atelier.PANNEAU)
	colonne.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	colonne.offset_left = 0
	colonne.offset_right = 384
	colonne.offset_top = 0
	colonne.offset_bottom = 0
	couche.add_child(colonne)
	var defilement := ScrollContainer.new()
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_child(defilement)
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 3)
	boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(boite)

	# ── L'EN-TÊTE : nom de l'outil, quartier, version, aide. Une barre, pas un
	# titre d'affiche : un outil n'a pas à crier son nom sur trois lignes.
	var chapeau := _rang(boite)
	var tt := Atelier.texte("ÉDITEUR DE CARTE", 13, Atelier.ENCRE)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapeau.add_child(tt)
	var baide := Atelier.bouton("H")
	baide.custom_minimum_size = Vector2(26, 22)
	baide.size_flags_horizontal = Control.SIZE_SHRINK_END
	baide.tooltip_text = "Les raccourcis"
	baide.pressed.connect(_basculer_aide)
	chapeau.add_child(baide)

	var rangQ := _rang(boite)
	# ⚠ UN `OptionButton` NON HABILLÉ GARDE LE THÈME DU MOTEUR.
	_choix_quartier = OptionButton.new()
	_choix_quartier.clip_text = true
	_choix_quartier.focus_mode = Control.FOCUS_NONE
	_choix_quartier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choix_quartier.custom_minimum_size = Vector2(0, 22)
	_choix_quartier.add_theme_font_override("font", Atelier.police())
	_choix_quartier.add_theme_font_size_override("font_size", Atelier.CORPS)
	_choix_quartier.add_theme_color_override("font_color", Atelier.ENCRE)
	for etat in ["normal", "hover", "pressed", "focus"]:
		_choix_quartier.add_theme_stylebox_override(etat,
			Atelier.boite(Atelier.CHAMP_SURVOL if etat == "hover" else Atelier.CHAMP))
	for id in Quartiers.CATALOGUE.keys():
		_choix_quartier.add_item(String(Quartiers.CATALOGUE[id]["nom"]))
	_choix_quartier.item_selected.connect(func(k):
		_charger(String(Quartiers.CATALOGUE.keys()[k])))
	rangQ.add_child(_choix_quartier)
	# ⚠ QUELLE VERSION REGARDE-T-ON ? `sortie/` est un artefact versionné servi
	# tel quel : on peut avoir poussé une journée de travail et voir encore la
	# page de la veille. Sans cette ligne, rien dans le jeu ne le disait.
	var ver := Atelier.texte(Version.etiquette(), Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE)
	ver.size_flags_horizontal = Control.SIZE_SHRINK_END
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rangQ.add_child(ver)

	_message = Atelier.texte("", Atelier.CORPS_PETIT, Atelier.ORANGE, true)
	_message.visible = false
	boite.add_child(_message)

	_bandeau = PanelContainer.new()
	_bandeau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boite.add_child(_bandeau)
	_fautes_texte = Atelier.texte("", 13, Atelier.ENCRE, true)
	_bandeau.add_child(_fautes_texte)
	_peindre_bandeau(true)
	_fautes_boite = VBoxContainer.new()
	_fautes_boite.add_theme_constant_override("separation", 2)
	_fautes_boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boite.add_child(_fautes_boite)
	_bouton_reparer = Atelier.bouton("Raboter les marches   (P)")
	_bouton_reparer.tooltip_text = "Baisse les cases qui font une marche interdite, jusqu'à ce que les trois règles tiennent"
	_bouton_reparer.visible = false
	_bouton_reparer.pressed.connect(_reparer)
	boite.add_child(_bouton_reparer)
	_minuteur = Timer.new()
	_minuteur.one_shot = true
	_minuteur.timeout.connect(_au_repos)
	add_child(_minuteur)

	# ── OUTIL ────────────────────────────────────────────────────────────────
	var cO := _bloc(boite, "OUTIL")
	var rang := _rang(cO)
	_bouton_dessin = Atelier.bouton("Dessin")
	_bouton_dessin.pressed.connect(_choisir_outil.bind(OUTIL_DESSIN))
	rang.add_child(_bouton_dessin)
	_bouton_relief = Atelier.bouton("Relief")
	_bouton_relief.pressed.connect(_choisir_outil.bind(OUTIL_RELIEF))
	rang.add_child(_bouton_relief)
	_bouton_objet = Atelier.bouton("Objet")
	_bouton_objet.tooltip_text = "Poser un modèle à la main : clic gauche pose, clic droit ôte"
	_bouton_objet.pressed.connect(_choisir_outil.bind(OUTIL_OBJET))
	rang.add_child(_bouton_objet)
	var rangP := _rang(cO)
	var moins := Atelier.bouton("−")
	moins.custom_minimum_size = Vector2(26, 22)
	moins.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	moins.tooltip_text = "Palier − 1  (Pg↓)"
	moins.pressed.connect(func(): _palier = maxi(0, _palier - 1); _etat())
	rangP.add_child(moins)
	_reglette = Control.new()
	_reglette.custom_minimum_size = Vector2(0, 22)
	_reglette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reglette.mouse_filter = Control.MOUSE_FILTER_STOP
	_reglette.tooltip_text = "Les dix paliers. Cliquer en choisit un ; Pg↑ Pg↓ aussi."
	_reglette.draw.connect(_dessiner_reglette)
	_reglette.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_palier = clampi(int((e.position.x / maxf(_reglette.size.x, 1.0)) * 10.0), 0, 9)
			_choisir_outil(OUTIL_RELIEF))
	rangP.add_child(_reglette)
	var plus := Atelier.bouton("+")
	plus.custom_minimum_size = Vector2(26, 22)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plus.tooltip_text = "Palier + 1  (Pg↑)"
	plus.pressed.connect(func(): _palier = mini(9, _palier + 1); _etat())
	rangP.add_child(plus)
	_bouton_relatif = Atelier.bouton("±")
	_bouton_relatif.custom_minimum_size = Vector2(26, 22)
	_bouton_relatif.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bouton_relatif.tooltip_text = "Relatif : monter / descendre d'un cran au lieu de poser le palier courant"
	_bouton_relatif.pressed.connect(func():
		_relief_relatif = not _relief_relatif
		_choisir_outil(OUTIL_RELIEF))
	rangP.add_child(_bouton_relatif)

	# ── PLAN ─────────────────────────────────────────────────────────────────
	var cP := _bloc(boite, "PLAN")
	var titre_plan := _rang(cP)
	var lbl := Atelier.texte("clic milieu : s'y rendre", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre_plan.add_child(lbl)
	_bouton_carte_relief = Atelier.bouton("Relief")
	_bouton_carte_relief.size_flags_horizontal = Control.SIZE_SHRINK_END
	_bouton_carte_relief.custom_minimum_size = Vector2(60, 22)
	_bouton_carte_relief.tooltip_text = "Montrer les paliers au lieu du dessin"
	_bouton_carte_relief.pressed.connect(func():
		_carte_relief = not _carte_relief
		_rafraichir_boutons()
		_redessiner_carte())
	titre_plan.add_child(_bouton_carte_relief)
	_carte2d = Control.new()
	_carte2d.custom_minimum_size = Vector2(0, 150)
	_carte2d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carte2d.mouse_filter = Control.MOUSE_FILTER_STOP
	_carte2d.draw.connect(_dessiner_carte)
	_carte2d.gui_input.connect(_carte_souris)
	cP.add_child(_carte2d)

	# ── PINCEAU ──────────────────────────────────────────────────────────────
	var cB := _bloc(boite, "PINCEAU")
	var carte_p := PanelContainer.new()
	carte_p.add_theme_stylebox_override("panel", Atelier.boite(Atelier.ENTETE))
	carte_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cB.add_child(carte_p)
	var rangA := HBoxContainer.new()
	rangA.add_theme_constant_override("separation", 8)
	carte_p.add_child(rangA)
	_apercu_image = TextureRect.new()
	_apercu_image.custom_minimum_size = Vector2(40, 40)
	_apercu_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_apercu_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rangA.add_child(_apercu_image)
	var colA := VBoxContainer.new()
	colA.add_theme_constant_override("separation", 1)
	colA.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colA.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangA.add_child(colA)
	_apercu_nom = Atelier.texte("", 13, Atelier.ENCRE)
	colA.add_child(_apercu_nom)
	_apercu_touche = Atelier.texte("", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE)
	colA.add_child(_apercu_touche)
	var onglets := GridContainer.new()
	onglets.columns = 3
	onglets.add_theme_constant_override("h_separation", 3)
	onglets.add_theme_constant_override("v_separation", 3)
	onglets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cB.add_child(onglets)
	for k in FAMILLES_PINCEAUX.size():
		var bo := Atelier.bouton(String(FAMILLES_PINCEAUX[k][0]))
		var dedans: Array[String] = []
		for q in PINCEAUX:
			if String(FAMILLES_PINCEAUX[k][1]).contains(String(q[0])):
				dedans.append(String(q[1]))
		bo.tooltip_text = ", ".join(dedans)
		bo.pressed.connect(func():
			_famille = k
			_rafraichir_boutons())
		_boutons_famille.append(bo)
		onglets.add_child(bo)
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 3)
	grille.add_theme_constant_override("v_separation", 3)
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cB.add_child(grille)
	for k in PINCEAUX.size():
		var p: Array = PINCEAUX[k]
		var vig := _vignette(String(p[0]))
		var b3 := Atelier.bouton(String(p[1]) if vig != null else "%s  %s" % [p[0], p[1]])
		b3.custom_minimum_size = Vector2(0, 30)
		b3.icon = vig if vig != null else _pastille(p[2])
		b3.add_theme_constant_override("icon_max_width", 26)
		b3.tooltip_text = "%s — touche %s%d" % [p[0], "Maj+" if k >= 9 else "", (k % 9) + 1]
		b3.pressed.connect(_choisir.bind(String(p[0])))
		_boutons.append(b3)
		grille.add_child(b3)

	# ── MODÈLES ──────────────────────────────────────────────────────────────
	_bloc_modeles(_bloc(boite, "MODÈLES", false))
	_bloc_objets(_bloc(boite, "OBJETS POSÉS", false))
	_bloc_reperes(_bloc(boite, "RECENSEMENT", false))

	# ── FORME ────────────────────────────────────────────────────────────────
	var cF := _bloc(boite, "FORME DU GESTE")
	var colF := GridContainer.new()
	colF.columns = 3
	colF.add_theme_constant_override("h_separation", 3)
	colF.add_theme_constant_override("v_separation", 3)
	colF.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cF.add_child(colF)
	for f6 in FORMES:
		var bf := Atelier.bouton("%s  %s" % [String(f6[2]), String(f6[1])])
		bf.tooltip_text = "Touche %s" % String(f6[2])
		bf.pressed.connect(_choisir_forme.bind(int(f6[0])))
		_boutons_forme.append(bf)
		colF.add_child(bf)

	# ── GESTE ────────────────────────────────────────────────────────────────
	var cG := _bloc(boite, "GESTE")
	var barre2 := GridContainer.new()
	barre2.columns = 3
	barre2.add_theme_constant_override("h_separation", 3)
	barre2.add_theme_constant_override("v_separation", 3)
	barre2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cG.add_child(barre2)
	for f5 in [["Annuler", _annuler], ["Refaire", _refaire_geste], ["Recadrer", _recadrer],
			["Copier", _copier], ["Coller", _coller]]:
		var b7 := Atelier.bouton(String(f5[0]))
		b7.pressed.connect(f5[1])
		barre2.add_child(b7)
	_bouton_grille = Atelier.bouton("Quadrillage")
	_bouton_grille.pressed.connect(_basculer_grille)
	barre2.add_child(_bouton_grille)
	_bouton_dessus = Atelier.bouton("De dessus")
	_bouton_dessus.pressed.connect(_vue_dessus)
	barre2.add_child(_bouton_dessus)

	# ── ATELIER (fermé) ──────────────────────────────────────────────────────
	var cA := _bloc(boite, "ATELIER", false)
	var barre := _rang(cA)
	for f in [["Exporter", _exporter], ["Fiche", _exporter_fiche],
			["Recharger", _recharger], ["Nouveau", _nouveau]]:
		var b := Atelier.bouton(String(f[0]))
		barre.add_child(b)
		b.pressed.connect(f[1])
	cA.add_child(Atelier.texte("ANGLE ET POSITION", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE))
	var rA := _rang(cA)
	for f3 in [["−5°", -5.0], ["+5°", 5.0], ["−1°", -1.0], ["+1°", 1.0]]:
		var b5 := Atelier.bouton(String(f3[0]))
		b5.pressed.connect(_tourner.bind(float(f3[1])))
		rA.add_child(b5)
	var rB := _rang(cA)
	for f4 in [["O", Vector2(-1, 0)], ["N", Vector2(0, -1)], ["S", Vector2(0, 1)], ["E", Vector2(1, 0)]]:
		var b6 := Atelier.bouton(String(f4[0]))
		b6.pressed.connect(_deplacer.bind(f4[1]))
		rB.add_child(b6)
	cA.add_child(Atelier.texte("AGRANDIR LA GRILLE", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE))
	var rC := _rang(cA)
	for f2 in [["+O", "ouest"], ["+N", "nord"], ["+S", "sud"], ["+E", "est"]]:
		var b2 := Atelier.bouton(String(f2[0]))
		b2.pressed.connect(_agrandir.bind(String(f2[1])))
		rC.add_child(b2)

	# ── LA BARRE DU BAS ──────────────────────────────────────────────────────
	var bas := PanelContainer.new()
	bas.add_theme_stylebox_override("panel",
		Atelier.boite(Color(Atelier.ENTETE.r, Atelier.ENTETE.g, Atelier.ENTETE.b, 0.92),
			Color(0, 0, 0, 0), 0, 12))
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = 384
	bas.offset_top = -42
	couche.add_child(bas)
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", 1)
	bas.add_child(pile)
	_etiquette = Atelier.texte("", 13, Atelier.ENCRE, true)
	pile.add_child(_etiquette)
	_aide = Atelier.texte("", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE, true)
	pile.add_child(_aide)

	_batir_aide(couche)
	_remplir_liste()
	_choisir_modele(_modele)
	_rafraichir_boutons()

func _choisir_outil(o: int) -> void:
	_outil = o
	# ⚠ CHOISIR UN OUTIL DÉROULE SON RÉGLAGE. « Objet » sans la liste des
	# modèles, c'est un outil sans son réglage : il faut alors deviner qu'une
	# section fermée plus bas contient ce qu'on va poser.
	_ouvrir_bloc("MODÈLES", o == OUTIL_OBJET)
	_ouvrir_bloc("PINCEAU", o != OUTIL_OBJET)
	_rafraichir_boutons()
	_etat()

# ------------------------------------------------------ navigateur de modèles

## ⚠ CINQ CENT QUATRE-VINGT-NEUF MODÈLES NE SE POSENT PAS EN BOUTONS. Le client
## veut « accès à tous les modèles » : ça veut dire une liste qui défile, un
## filtre qui cherche, un dossier qui restreint — et un APERÇU QUI EST LE
## MODÈLE, pas sa photo. Une photo ment sur le volume : on croit poser un banc,
## on pose une statue de six mètres. Ici l'aperçu est une vraie vue 3D, bâtie
## par les MÊMES fonctions que la ville (`FormesCarnage`), et elle tourne.
func _bloc_modeles(corps: VBoxContainer) -> void:
	_filtre_modeles = Atelier.champ("rechercher…")
	_filtre_modeles.text_changed.connect(func(_t): _remplir_liste())
	corps.add_child(_filtre_modeles)

	_choix_dossier = OptionButton.new()
	_choix_dossier.clip_text = true
	_choix_dossier.focus_mode = Control.FOCUS_NONE
	_choix_dossier.custom_minimum_size = Vector2(0, 22)
	_choix_dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choix_dossier.add_theme_font_override("font", Atelier.police())
	_choix_dossier.add_theme_font_size_override("font_size", Atelier.CORPS)
	_choix_dossier.add_theme_color_override("font_color", Atelier.ENCRE)
	for etat in ["normal", "hover", "pressed", "focus"]:
		_choix_dossier.add_theme_stylebox_override(etat,
			Atelier.boite(Atelier.CHAMP_SURVOL if etat == "hover" else Atelier.CHAMP))
	_dossiers = ["tous"]
	for m in ModelesDuKit.TOUS:
		var d := String(m).get_base_dir()
		if d != "" and not _dossiers.has(d): _dossiers.append(d)
	for d in _dossiers:
		_choix_dossier.add_item(d)
	_choix_dossier.item_selected.connect(func(_k): _remplir_liste())
	corps.add_child(_choix_dossier)

	# L'APERÇU. Un `SubViewport` avec son propre monde : la ville de 140 000
	# nœuds n'a rien à faire dans une vignette de trois cents pixels.
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.custom_minimum_size = Vector2(0, 132)
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	cadre.gui_input.connect(_apercu_souris)
	cadre.tooltip_text = "Glisser pour tourner autour du modèle"
	corps.add_child(cadre)
	_apercu3d = SubViewport.new()
	_apercu3d.size = Vector2i(360, 132)
	_apercu3d.own_world_3d = true
	_apercu3d.transparent_bg = false
	_apercu3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cadre.add_child(_apercu3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Atelier.FOND
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b9c6d6")
	e.ambient_light_energy = 1.0
	env.environment = e
	_apercu3d.add_child(env)
	var lum := DirectionalLight3D.new()
	lum.rotation_degrees = Vector3(-48, -38, 0)
	lum.light_energy = 1.4
	_apercu3d.add_child(lum)
	_apercu_pivot = Node3D.new()
	_apercu3d.add_child(_apercu_pivot)
	_apercu_cam = Camera3D.new()
	_apercu_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_apercu_cam.far = 4000.0
	_apercu3d.add_child(_apercu_cam)

	_liste_modeles = Atelier.liste()
	_liste_modeles.custom_minimum_size = Vector2(0, 132)
	_liste_modeles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste_modeles.item_selected.connect(func(k):
		if k >= 0 and k < _visibles.size(): _choisir_modele(_visibles[k]))
	corps.add_child(_liste_modeles)

	_etiquette_modele = Atelier.texte("", Atelier.CORPS_PETIT, Atelier.ENCRE_DOUCE, true)
	corps.add_child(_etiquette_modele)

	# LES DEUX RÉGLAGES QUI COMPTENT : la taille et l'angle. Le reste — le point
	# dans la case — vient du curseur, et c'est mieux ainsi.
	var pH: Array = Atelier.regle("Hauteur", 1.0, 60.0, 0.5, _hauteur_objet, 1)
	corps.add_child(pH[0])
	(pH[1] as HSlider).value_changed.connect(func(v):
		_hauteur_objet = v
		_cadrer_apercu()
		_dire_modele())
	var pR: Array = Atelier.regle("Angle", 0.0, 355.0, 5.0, _angle_objet)
	corps.add_child(pR[0])
	(pR[1] as HSlider).value_changed.connect(func(v):
		_angle_objet = v
		if _apercu_pivot != null: _apercu_pivot.rotation.y = deg_to_rad(v)
		_dire_modele())
	# ─── LE SEMIS ───
	var rS := _rang(corps)
	var bsem := Atelier.bouton("Semer en traînant")
	bsem.tooltip_text = "Poser une rangée d'objets le long du glissé, au lieu d'un par clic"
	bsem.pressed.connect(func():
		_semer = not _semer
		Atelier.peindre(bsem, _semer)
		_dire("Semis %s — le clic gauche traîné pose une rangée." % \
			("allumé" if _semer else "éteint"))
		_etat())
	Atelier.peindre(bsem, _semer)
	rS.add_child(bsem)
	var bvoie := Atelier.bouton("Éviter la voirie")
	bvoie.tooltip_text = "Ne rien semer sur les rues, ponts, ronds-points et bretelles"
	bvoie.pressed.connect(func():
		_semis_hors_voirie = not _semis_hors_voirie
		Atelier.peindre(bvoie, _semis_hors_voirie))
	Atelier.peindre(bvoie, _semis_hors_voirie)
	rS.add_child(bvoie)
	var rS2 := _rang(corps)
	var bang := Atelier.bouton("Angle au hasard")
	bang.tooltip_text = "Chaque objet semé prend son propre angle"
	bang.pressed.connect(func():
		_angle_libre = not _angle_libre
		Atelier.peindre(bang, _angle_libre))
	Atelier.peindre(bang, _angle_libre)
	rS2.add_child(bang)
	var pP: Array = Atelier.regle("Pas", 0.2, 4.0, 0.1, _pas_semis, 1)
	corps.add_child(pP[0])
	(pP[1] as HSlider).value_changed.connect(func(v): _pas_semis = v)
	var pD: Array = Atelier.regle("Écart", 0.0, 1.0, 0.05, _dispersion, 2)
	corps.add_child(pD[0])
	(pD[1] as HSlider).value_changed.connect(func(v): _dispersion = v)
	var pV: Array = Atelier.regle("Variété", 0.0, 0.6, 0.05, _variation, 2)
	corps.add_child(pV[0])
	(pV[1] as HSlider).value_changed.connect(func(v): _variation = v)

	var rT := _rang(corps)
	var bt := Atelier.bouton("Tourne tout seul")
	bt.pressed.connect(func():
		_apercu_tourne = not _apercu_tourne
		Atelier.peindre(bt, _apercu_tourne))
	Atelier.peindre(bt, _apercu_tourne)
	rT.add_child(bt)
	var bp := Atelier.bouton("Poser  →  outil Objet")
	bp.pressed.connect(func(): _choisir_outil(OUTIL_OBJET))
	rT.add_child(bp)

## ─────────────────────────── LE RECENSEMENT ───────────────────────────
##
## ⚠ UNE CARTE DE 96 000 CASES NE SE RELIT PAS À L'ŒIL. « Combien d'hôpitaux
## ai-je posés ? », « où est la deuxième caserne ? », « est-ce que mes
## bretelles sont réparties ou toutes dans le nord ? » — trois questions qu'on
## se pose vingt fois par séance et auxquelles l'éditeur ne savait pas
## répondre. On les comptait à la main sur une capture d'écran, ce qui est le
## contraire d'un éditeur.
##
## Le bloc compte CHAQUE caractère du dessin, dit le total, et sait SAUTER
## d'une occurrence à l'autre. Pour les lettres, une occurrence est un
## BÂTIMENT (le bloc de lettres), pas une case : sauter case par case dans une
## tour de 3 × 3 n'apprend rien.
##
## ⚠ LES CARACTÈRES FRÉQUENTS SONT REGROUPÉS EN AMAS. La pelouse compte vingt
## mille cases : « suivant » qui avance d'une case serait un bouton inutile. On
## ne garde donc qu'une occurrence par carré de PAS_AMAS cases — on saute d'un
## coin de la ville à l'autre, ce qui est la question qu'on pose vraiment.
const PAS_AMAS := 10
const AMAS_MAX := 600

var _liste_reperes: ItemList
var _resume_reperes: Label
var _chars_recenses: Array[String] = []
var _compte_reperes: Dictionary = {}     ## caractère -> nombre de cases
var _lieux_reperes: Dictionary = {}      ## caractère -> Array[Vector2i]
var _rang_repere := 0
var _recense_a_jour := false

func _bloc_reperes(corps: VBoxContainer) -> void:
	_resume_reperes = Atelier.texte("", Atelier.CORPS_PETIT, Atelier.ENCRE_DOUCE, true)
	corps.add_child(_resume_reperes)
	_liste_reperes = Atelier.liste()
	_liste_reperes.custom_minimum_size = Vector2(0, 150)
	_liste_reperes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste_reperes.item_selected.connect(func(k):
		if k < 0 or k >= _chars_recenses.size(): return
		_rang_repere = -1
		_sauter_repere(1))
	corps.add_child(_liste_reperes)
	var r := _rang(corps)
	var bp := Atelier.bouton("◀")
	bp.tooltip_text = "Occurrence précédente"
	bp.pressed.connect(func(): _sauter_repere(-1))
	r.add_child(bp)
	var bs := Atelier.bouton("suivant ▶")
	bs.tooltip_text = "Occurrence suivante du caractère choisi"
	bs.pressed.connect(func(): _sauter_repere(1))
	r.add_child(bs)
	var bres := Atelier.bouton("Réseau")
	bres.tooltip_text = "Le réseau de rues est-il d'un seul tenant ? Rappuyer visite les morceaux coupés"
	bres.pressed.connect(_verifier_reseau)
	r.add_child(bres)
	var br := Atelier.bouton("Recenser")
	br.tooltip_text = "Recompter le dessin"
	br.pressed.connect(func():
		_recense_a_jour = false
		_recenser())
	r.add_child(br)
	# ⚠ LE COMPTE SE FAIT QUAND ON OUVRE LE BLOC, pas au démarrage. Ouvrir
	# l'éditeur ne doit pas coûter un balayage de 96 000 caractères pour un
	# panneau que l'on ne déroulera peut-être jamais ; et le dérouler doit
	# montrer des chiffres justes, pas ceux d'il y a vingt coups de pinceau.
	corps.visibility_changed.connect(func():
		if corps.visible: _recenser())

## ⚠ ON NE RECENSE PAS À CHAQUE COUP DE PINCEAU. Un balayage de 96 000
## caractères plus la liste des bâtiments coûte le prix d'un geste entier ;
## payé à chaque case peinte, il rendrait le pinceau poisseux. Le compte est
## donc marqué PÉRIMÉ par l'édition et refait quand on le regarde.
func _recenser() -> void:
	if _recense_a_jour or _liste_reperes == null: return
	_recense_a_jour = true
	_compte_reperes.clear()
	_lieux_reperes.clear()
	var lignes: Array = _lignes("plan")
	var terre := 0
	var eau := 0
	var rues := 0
	for j in lignes.size():
		var t: String = lignes[j]
		for i in t.length():
			var c := t[i]
			_compte_reperes[c] = int(_compte_reperes.get(c, 0)) + 1
			if EAUX.contains(c): eau += 1
			else: terre += 1
			if CHAUSSEE.contains(c): rues += 1
			# Les lettres passent par les BÂTIMENTS, plus bas.
			if _lettre_de_famille(c): continue
			var amas: Array = _lieux_reperes.get(c, [])
			if amas.size() >= AMAS_MAX: continue
			var dernier: Vector2i = amas[amas.size() - 1] if not amas.is_empty() \
				else Vector2i(-999, -999)
			if absi(dernier.x - i) < PAS_AMAS and absi(dernier.y - j) < PAS_AMAS: continue
			amas.append(Vector2i(i, j))
			_lieux_reperes[c] = amas
	var blocs: Array = Quartiers.batiments(lignes)
	var batis: Dictionary = {}
	for b in blocs:
		var l := String(b["lettre"])
		batis[l] = int(batis.get(l, 0)) + 1
		var amas2: Array = _lieux_reperes.get(l, [])
		if amas2.size() < AMAS_MAX:
			amas2.append(Vector2i(int(b["i"]), int(b["j"])))
			_lieux_reperes[l] = amas2

	# LA LISTE SUIT L'ORDRE DES PINCEAUX, pas l'ordre alphabétique : c'est
	# l'ordre qu'on a déjà dans les doigts, et il range le sol avec le sol.
	_chars_recenses.clear()
	_liste_reperes.clear()
	for p in PINCEAUX:
		var c := String(p[0])
		var n := int(_compte_reperes.get(c, 0)) + int(_compte_reperes.get(c.to_lower(), 0)) \
			if _lettre_de_famille(c) else int(_compte_reperes.get(c, 0))
		if n == 0: continue
		var suffixe := ""
		if _lettre_de_famille(c):
			var nb := int(batis.get(c, 0)) + int(batis.get(c.to_lower(), 0))
			suffixe = "  ·  %d bâtiment(s)" % nb
		_chars_recenses.append(c)
		_liste_reperes.add_item("%s  %s  —  %d case(s)%s" % [c, String(p[1]), n, suffixe])
	# ⚠ ET LA SURFACE EN KILOMÈTRES CARRÉS. Le client raisonne en « cinq fois la
	# map de GTA 2 », pas en cases : un nombre de cases ne lui dit rien, six
	# kilomètres carrés lui disent tout de suite si la ville a la bonne taille.
	# Une case = 20 unités = 10 m de côté, donc 100 m² par case.
	var km2 := float(terre) * 100.0 / 1_000_000.0
	_resume_reperes.text = "%d cases de terre (%.2f km²) · %d d'eau · %d de voirie · %d bâtiments · %d grosses pièces · %d objets · paliers 0 à %d" % [
		terre, km2, eau, rues, blocs.size(), _pieces_du_plan(), _objets().size(), _plus_haut]

func _lettre_de_famille(c: String) -> bool:
	return c.length() == 1 and FAMILLES.contains(c.to_upper()) and c.to_upper() != c.to_lower()

## Les grosses pièces DEMANDÉES par le dessin. On les compte sur les
## caractères et non sur la carte bâtie : recalculer une `CarteVille` de
## Pikstown pour afficher un nombre coûterait deux secondes.
func _pieces_du_plan() -> int:
	var n := 0
	for l in _lignes("plan"):
		var t := String(l)
		n += t.count("O") + t.count("(") + t.count("/")
	return n

## Saute à l'occurrence suivante (ou précédente) du caractère choisi. La vue s'y
## rend et la case visée devient celle-là : on peut enchaîner « suivant » et
## corriger au passage.
func _sauter_repere(sens: int) -> void:
	if _liste_reperes == null: return
	var k := _liste_reperes.get_selected_items()
	if k.is_empty():
		_dire("Choisissez d'abord une ligne du recensement.")
		return
	var c: String = _chars_recenses[k[0]]
	var lieux: Array = _lieux_reperes.get(c, [])
	# Les minuscules d'une famille sont le MÊME sujet que leur majuscule : on
	# saute d'un immeuble à l'autre, pas d'une casse à l'autre.
	if _lettre_de_famille(c):
		lieux = lieux + Array(_lieux_reperes.get(c.to_lower(), []))
	if lieux.is_empty():
		_dire("Rien à viser pour « %s »." % c)
		return
	_rang_repere = posmod(_rang_repere + sens, lieux.size())
	var cc: Vector2i = lieux[_rang_repere]
	_case = cc
	_pivot = Vector3((float(cc.x) + 0.5) * CASE,
		float(_palier_de(cc.x, cc.y)) * PALIER, (float(cc.y) + 0.5) * CASE)
	_distance = minf(_distance, CASE * 26.0)
	_poser_camera()
	if _ville != null: _ville.suivre(_pivot)
	_montrer_curseur()
	_dire("« %s » — %d sur %d, en (%d, %d)." % [c, _rang_repere + 1, lieux.size(), cc.x, cc.y])

## Sème un grain si le curseur s'est assez éloigné du dernier. On mesure sur le
## POINT D'IMPACT et non sur la case : à un pas d'une demi-case, raisonner en
## cases ne saurait pas où poser le deuxième grain.
func _semer_le_long() -> void:
	if not _vise or not _semer or not _gauche: return
	var pas := maxf(_pas_semis, 0.15) * CASE
	# ⚠ UN SAUT DU CURSEUR NE SE SÈME PAS. Le point d'impact peut bondir de
	# cent cases — la souris passe derrière un immeuble, la vue tourne, le
	# rayon accroche une autre terrasse. Combler le trajet remplissait alors la
	# moitié d'un quartier d'arbres en une image. Au-delà de SAUT_SEMIS pas,
	# on considère qu'il n'y a pas eu de trait : on se replace, sans semer.
	const SAUT_SEMIS := 8
	if _impact.distance_to(_dernier_semis) > pas * float(SAUT_SEMIS):
		_dernier_semis = _impact
		return
	while _impact.distance_to(_dernier_semis) >= pas:
		var d := (_impact - _dernier_semis).normalized()
		_dernier_semis += d * pas
		_semer_un(_dernier_semis)

## ⚠ UN GRAIN N'EST PAS UN OBJET POSÉ : il ne rebâtit PAS son morceau. Une haie
## de quarante arbres reconstruirait quarante fois le même bout de ville — deux
## secondes par arbre. On note la case dans `_touchees` et `_finir_geste` refait
## tout d'un coup au relâchement, exactement comme un coup de pinceau.
func _semer_un(ou: Vector3) -> void:
	var c := Vector2i(floori(ou.x / CASE), floori(ou.z / CASE))
	if not _dans_grille(c.x, c.y) or not _terre(c.x, c.y): return
	if _semis_hors_voirie and CHAUSSEE.contains(_lire("plan", c.x, c.y)): return
	_alea_semis.seed = hash(Vector3i(c.x, c.y, _objets().size() * 7919))
	# La dispersion s'ajoute AU POINT, pas à la case : une haie parfaitement
	# alignée est une haie de cimetière, et une dispersion par case ferait
	# sauter les grains d'un carré à l'autre.
	var p := Vector2(ou.x / CASE, ou.z / CASE) - Vector2(c)
	p += Vector2(_alea_semis.randf_range(-1.0, 1.0),
		_alea_semis.randf_range(-1.0, 1.0)) * _dispersion * 0.5
	p = p.clamp(Vector2(0.02, 0.02), Vector2(0.98, 0.98))
	var h := _hauteur_objet * (1.0 + _alea_semis.randf_range(-_variation, _variation))
	var r := _alea_semis.randf_range(0.0, 355.0) if _angle_libre else _angle_objet
	var objets: Array = _objets()
	objets.append({"m": _modele, "i": c.x, "j": c.y,
		"x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01),
		"r": snappedf(r, 1.0), "h": snappedf(maxf(h, 0.5), 0.5)})
	_fiche["objets"] = objets
	_touchees[c] = true
	_semes += 1
	_recense_a_jour = false

## ─────────────────────── LE RÉSEAU D'UN SEUL TENANT ───────────────────────
##
## ⚠ IL N'Y A AUCUNE RECHERCHE DE CHEMIN DANS CE JEU. Une voiture qui bute sur
## l'eau tourne au hasard, une patrouille reste plaquée contre la berge. Un
## morceau de voirie qui ne touche pas le reste, c'est un quartier entier —
## immeubles, hôpital, cabines — où personne n'ira jamais, et ça ne se voit sur
## AUCUNE photo : le pont a l'air fini, il s'arrête juste deux cases avant la
## rue.
##
## Mesuré le 11/09 sur Pikstown : le réseau était en ONZE morceaux, le plus
## grand à 48 % — trois gros, tous sur la même île. Le dessinateur ne pouvait
## pas le savoir. L'éditeur le dit maintenant en une seconde, et emmène voir.
var _orphelins: Array[Vector2i] = []
var _rang_orphelin := 0

func _verifier_reseau() -> void:
	var lignes: Array = _lignes("plan")
	var h := lignes.size()
	var vu: Array = []
	for j in h:
		var l: Array[bool] = []
		l.resize(String(lignes[j]).length())
		vu.append(l)
	var morceaux: Array = []          # [taille, case de tête]
	var total := 0
	for j in h:
		var t: String = lignes[j]
		for i in t.length():
			if vu[j][i] or not CHAUSSEE.contains(t[i]): continue
			# Un parcours en largeur sur un tableau de booléens : sur 96 000
			# cases, un dictionnaire de Vector2i coûterait dix fois le prix.
			var file: Array[Vector2i] = [Vector2i(i, j)]
			vu[j][i] = true
			var n := 0
			var tete := Vector2i(i, j)
			while not file.is_empty():
				var c: Vector2i = file.pop_back()
				n += 1
				for d in CarteVille.COTES:
					var v: Vector2i = c + d
					if v.y < 0 or v.y >= h or v.x < 0: continue
					var tv: String = lignes[v.y]
					if v.x >= tv.length() or vu[v.y][v.x]: continue
					if not CHAUSSEE.contains(tv[v.x]): continue
					vu[v.y][v.x] = true
					file.append(v)
			total += n
			morceaux.append([n, tete])
	morceaux.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	if morceaux.is_empty():
		_dire("Aucune rue dans ce dessin.")
		return
	if morceaux.size() == 1:
		_dire("Réseau d'un seul tenant : %d cases de rue, toutes reliées." % total)
		_orphelins.clear()
		return
	_orphelins.clear()
	for k in range(1, morceaux.size()):
		_orphelins.append(morceaux[k][1])
	var gros: int = int(morceaux[0][0])
	_dire("%d morceaux de voirie — le plus grand fait %d cases sur %d (%.1f %%). Rappuyez sur « Réseau » pour visiter les %d coupés." % [
		morceaux.size(), gros, total, 100.0 * float(gros) / float(total), _orphelins.size()])
	_visiter_orphelin()

## Emmène la vue sur le morceau coupé suivant. Un nombre ne suffit pas : ce
## qu'on veut savoir, c'est OÙ ça casse, et il n'y a qu'un endroit pour le voir.
func _visiter_orphelin() -> void:
	if _orphelins.is_empty(): return
	_rang_orphelin = posmod(_rang_orphelin, _orphelins.size())
	var c: Vector2i = _orphelins[_rang_orphelin]
	_rang_orphelin += 1
	_case = c
	_pivot = Vector3((float(c.x) + 0.5) * CASE,
		float(_palier_de(c.x, c.y)) * PALIER, (float(c.y) + 0.5) * CASE)
	_distance = minf(_distance, CASE * 34.0)
	_poser_camera()
	if _ville != null: _ville.suivre(_pivot)
	_montrer_curseur()

## L'INVENTAIRE DES OBJETS POSÉS. Un éditeur qui pose sans savoir montrer ce
## qui est posé n'est pas un éditeur : on retrouvait un arbre mal placé en
## tournant autour à la souris. La liste dit le modèle, la case et la hauteur ;
## la choisir allume la mire, et les deux glissières deviennent celles de CET
## objet-là.
const OBJETS_MONTRES := 400

func _bloc_objets(corps: VBoxContainer) -> void:
	_filtre_objets = Atelier.champ("filtrer par nom ou par case (i,j)")
	_filtre_objets.text_changed.connect(func(_t): _remplir_objets())
	corps.add_child(_filtre_objets)

	_liste_objets = Atelier.liste()
	_liste_objets.custom_minimum_size = Vector2(0, 120)
	_liste_objets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste_objets.item_selected.connect(func(rang):
		if rang >= 0 and rang < _rangs_objets.size():
			_choisir_objet(_rangs_objets[rang]))
	corps.add_child(_liste_objets)

	_compte_objets = Atelier.texte("", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE, true)
	corps.add_child(_compte_objets)

	var pH: Array = Atelier.regle("Hauteur", 1.0, 60.0, 0.5, _hauteur_objet, 1)
	corps.add_child(pH[0])
	_gliss_h_objet = pH[1]
	_gliss_h_objet.value_changed.connect(func(v): _regler_objet("h", v, false))
	_gliss_h_objet.drag_started.connect(func(): _empiler())
	var pR: Array = Atelier.regle("Angle", 0.0, 355.0, 5.0, _angle_objet)
	corps.add_child(pR[0])
	_gliss_r_objet = pR[1]
	_gliss_r_objet.value_changed.connect(func(v): _regler_objet("r", v, false))
	_gliss_r_objet.drag_started.connect(func(): _empiler())

	# ⚠ TROIS BOUTONS COURTS SUR UNE LIGNE. « Remplacer par le modèle choisi »
	# tenait toute la largeur de la colonne et sortait quand même du cadre :
	# dans un panneau de 300 pixels, un libellé de trente caractères est un
	# libellé tronqué. Ce que fait chaque bouton est dit dans l'infobulle.
	var r1 := _rang(corps)
	var bv := Atelier.bouton("Viser")
	bv.tooltip_text = "Amener la vue sur l'objet choisi"
	bv.pressed.connect(_viser_objet)
	r1.add_child(bv)
	var br := Atelier.bouton("Remplacer")
	br.tooltip_text = "Donner à l'objet choisi le modèle sélectionné dans MODÈLES"
	br.pressed.connect(func(): _regler_objet("m", _modele))
	r1.add_child(br)
	var bs := Atelier.bouton("Supprimer")
	bs.tooltip_text = "Ôter l'objet choisi (touche Suppr)"
	bs.pressed.connect(_supprimer_objet)
	r1.add_child(bs)

func _remplir_objets() -> void:
	if _liste_objets == null: return
	var filtre := _filtre_objets.text.strip_edges().to_lower()
	var objets: Array = _objets()
	_rangs_objets.clear()
	_liste_objets.clear()
	var caches := 0
	for k in objets.size():
		var o: Dictionary = objets[k]
		var etiquette := "%s   (%d,%d)  h%.0f" % [String(o["m"]).get_file(),
			int(o["i"]), int(o["j"]), float(o.get("h", 10.0))]
		if filtre != "" and not etiquette.to_lower().contains(filtre): continue
		if _rangs_objets.size() >= OBJETS_MONTRES:
			caches += 1
			continue
		_rangs_objets.append(k)
		_liste_objets.add_item(etiquette)
	_compte_objets.text = "%d objet(s) dans le quartier" % objets.size()
	if caches > 0:
		_compte_objets.text += " — %d de plus au-delà des %d premiers : filtrez." % [
			caches, OBJETS_MONTRES]
	var rang := _rangs_objets.find(_objet_choisi)
	if rang >= 0:
		_liste_objets.select(rang)

## Amène la vue sur l'objet choisi. Chercher à la main un arbre dans une ville
## de 320 cases, c'est ce qui rend une liste inutile.
func _viser_objet() -> void:
	var objets: Array = _objets()
	if _objet_choisi < 0 or _objet_choisi >= objets.size():
		_dire("Aucun objet choisi.")
		return
	var o: Dictionary = objets[_objet_choisi]
	_case = Vector2i(int(o["i"]), int(o["j"]))
	_pivot = Vector3((float(_case.x) + 0.5) * CASE,
		float(_palier_de(_case.x, _case.y)) * PALIER, (float(_case.y) + 0.5) * CASE)
	_distance = minf(_distance, CASE * 9.0)
	_poser_camera()
	if _ville != null: _ville.suivre(_pivot)
	_montrer_curseur()
	_dire("%s en (%d,%d)." % [_nom_objet(_objet_choisi), _case.x, _case.y])

func _remplir_liste() -> void:
	if _liste_modeles == null: return
	var filtre := _filtre_modeles.text.strip_edges().to_lower()
	var dossier := "" if _choix_dossier.selected <= 0 \
		else _dossiers[maxi(_choix_dossier.selected, 0)]
	_visibles.clear()
	for m in ModelesDuKit.TOUS:
		if dossier != "" and not String(m).begins_with(dossier + "/"): continue
		if filtre != "" and not String(m).to_lower().contains(filtre): continue
		_visibles.append(String(m))
	_liste_modeles.clear()
	for m in _visibles:
		# Le NOM en clair, le dossier en gris derrière : dans une liste de six
		# cents lignes, c'est le nom qu'on lit, pas le chemin.
		_liste_modeles.add_item("%s      %s" % [m.get_file(), m.get_base_dir()])
	var rang := _visibles.find(_modele)
	if rang >= 0:
		_liste_modeles.select(rang)
		_liste_modeles.ensure_current_is_visible()
	if _etiquette_modele != null:
		_dire_modele()

func _choisir_modele(chemin: String) -> void:
	_modele = chemin
	_batir_apercu()
	_dire_modele()
	_etat()

func _dire_modele() -> void:
	if _etiquette_modele == null: return
	_etiquette_modele.text = "%s  ·  %d modèle(s) listé(s)  ·  %.1f unités de haut (%.1f m)" % [
		_modele, _visibles.size(), _hauteur_objet, _hauteur_objet * 0.5]

## ⚠ LE MAILLAGE EST CELUI DU JEU. Le bâtir autrement — en instanciant la scène
## du `.glb` — donnerait un aperçu plus joli que le résultat : couleurs par
## matière, alors que la ville fond tout en une surface à couleurs de sommet.
## Un aperçu qui ment est pire qu'une photo.
func _batir_apercu() -> void:
	if _apercu_pivot == null: return
	for e in _apercu_pivot.get_children():
		_apercu_pivot.remove_child(e)
		e.queue_free()
	var chemin := "res://modeles/" + _modele + ".glb"
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, _hauteur_objet, Vector3.AXIS_Y, 0.0)
	n.material_override = FormesCarnage.matiere_kenney(chemin)
	_apercu_pivot.add_child(n)
	_apercu_pivot.rotation.y = deg_to_rad(_angle_objet)
	_cadrer_apercu()

func _cadrer_apercu() -> void:
	if _apercu_cam == null: return
	# Le modèle est bâti à la hauteur demandée : on cadre là-dessus, avec un
	# peu d'air. Ainsi la glissière de hauteur ne change pas la taille APPARENTE
	# — ce qu'on juge, c'est la forme, pas le zoom.
	_apercu_cam.size = maxf(_hauteur_objet, 2.0) * 1.5
	var centre := Vector3(0, _hauteur_objet * 0.5, 0)
	_apercu_cam.look_at_from_position(
		centre + Vector3(sin(_apercu_azimut), 0.62, cos(_apercu_azimut)).normalized() * 400.0,
		centre, Vector3.UP)

func _apercu_souris(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_apercu_azimut -= e.relative.x * 0.012
		_apercu_tourne = false
		_cadrer_apercu()

## LES RACCOURCIS, EN CABOCHONS. Écrits en phrase et collés sous l'état, ils
## faisaient une ligne de trois cents caractères que personne ne lit ; dessinés
## comme des touches, on les repère du coin de l'œil — et derrière H, ils ne
## mangent plus le bas de l'écran en permanence.
const RACCOURCIS := [
	["Clic G", "peindre / poser"], ["Clic D", "effacer / choisir un objet"],
	["Alt + clic", "pipette"], ["Clic M", "tourner la vue"],
	["Molette", "zoom"], ["ZQSD", "déplacer la vue"],
	["Tab", "dessin / relief / objet"], ["Pg↑ Pg↓", "palier"],
	["1-9", "pinceau"], ["Maj + 1-9", "pinceau (suite)"],
	["R", "MAJUSCULE / minuscule"], ["C", "sélection"],
	["B L K J G I", "forme du geste"], ["Ctrl+C  Ctrl+V", "copier / coller"],
	["Ctrl+Z  Ctrl+Y", "annuler / refaire"], ["Échap", "annuler le geste"],
	["F", "recadrer"], ["V", "vue de dessus"],
	["X", "quadrillage"], ["E", "exporter"],
	["P", "raboter le relief"], ["Suppr", "supprimer l'objet choisi"],
	["H", "fermer cette aide"],
]

func _batir_aide(couche: Node) -> void:
	_aide_panneau = Atelier.panneau(Atelier.PANNEAU)
	_aide_panneau.set_anchors_preset(Control.PRESET_CENTER)
	_aide_panneau.offset_left = -330
	_aide_panneau.offset_right = 330
	_aide_panneau.offset_top = -210
	_aide_panneau.offset_bottom = 210
	_aide_panneau.visible = false
	couche.add_child(_aide_panneau)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_aide_panneau.add_child(col)
	col.add_child(Atelier.texte("RACCOURCIS", 15, Atelier.ENCRE))
	col.add_child(Atelier.texte("H referme ce panneau", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE))
	var filet := ColorRect.new()
	filet.color = Atelier.ACCENT
	filet.custom_minimum_size = Vector2(0, 2)
	col.add_child(filet)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 5)
	col.add_child(g)
	for r in RACCOURCIS:
		g.add_child(_cabochon(String(r[0]), String(r[1])))

## Une touche dessinée comme un cabochon : on la repère du coin de l'œil, là où
## « appuyez sur E pour… » se lit une fois et s'oublie.
func _cabochon(cle: String, action: String) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", 7)
	var t := Atelier.texte(cle, Atelier.CORPS_PETIT, Atelier.FOND)
	var boite := PanelContainer.new()
	boite.add_theme_stylebox_override("panel",
		Atelier.boite(Atelier.ENCRE_DOUCE, Color(0, 0, 0, 0), 3, 6))
	boite.add_child(t)
	boite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_child(boite)
	b.add_child(Atelier.texte(action, Atelier.CORPS, Atelier.ENCRE_DOUCE))
	return b

# ------------------------------------------------------------ liste et états

func _synchroniser_liste() -> void:
	if _choix_quartier == null: return
	var rang := Quartiers.CATALOGUE.keys().find(_id)
	if rang >= 0: _choix_quartier.selected = rang

func _dire(message: String) -> void:
	if _message != null:
		_message.text = message
		_message.visible = message != ""

func _choisir(c: String) -> void:
	_pinceau = c
	_famille = _famille_de(c)
	_outil = OUTIL_DESSIN
	if _forme == FORME_PIPETTE: _forme = FORME_LIBRE
	_rafraichir_boutons()
	_etat()

## Le surlignage de TOUS les boutons d'état, au même endroit. Éparpillé, il
## finit toujours par en oublier un — c'est exactement ce qui laissait « Rue »
## en bleu après un clic sur « Tour ».
func _famille_de(c: String) -> int:
	for k in FAMILLES_PINCEAUX.size():
		if String(FAMILLES_PINCEAUX[k][1]).contains(c): return k
	return 0

func _rafraichir_boutons() -> void:
	for k in _boutons.size():
		var c := String(PINCEAUX[k][0])
		_teinter(_boutons[k], _outil == OUTIL_DESSIN and c == _pinceau)
		# ⚠ ON CACHE, ON NE DÉTRUIT PAS. Un `GridContainer` saute ses enfants
		# invisibles : la grille se reflue toute seule sur la famille montrée,
		# et les boutons gardent leur état et leurs branchements.
		_boutons[k].visible = _famille_de(c) == _famille
	for k in _boutons_famille.size():
		_teinter(_boutons_famille[k], k == _famille)
	if _apercu_nom != null:
		for p in PINCEAUX:
			if String(p[0]) != _pinceau: continue
			_apercu_nom.text = String(p[1])
			var rang := 0
			for q in PINCEAUX.size():
				if String(PINCEAUX[q][0]) == _pinceau: rang = q
			_apercu_touche.text = "« %s »   touche %s%d" % [
				_caractere(), "Maj+" if rang >= 9 else "", (rang % 9) + 1]
			var v := _vignette(String(p[0]))
			_apercu_image.texture = v if v != null else _pastille(p[2])
	for k in _boutons_forme.size():
		_teinter(_boutons_forme[k], int(FORMES[k][0]) == _forme)
	if _bouton_dessin != null: _teinter(_bouton_dessin, _outil == OUTIL_DESSIN)
	if _bouton_relief != null: _teinter(_bouton_relief, _outil == OUTIL_RELIEF)
	if _bouton_objet != null: _teinter(_bouton_objet, _outil == OUTIL_OBJET)
	if _bouton_grille != null: _teinter(_bouton_grille, _voir_grille)
	if _bouton_dessus != null: _teinter(_bouton_dessus, _dessus)
	if _bouton_relatif != null: _teinter(_bouton_relatif, _relief_relatif)
	if _bouton_carte_relief != null: _teinter(_bouton_carte_relief, _carte_relief)

## ⚠ UNE LIGNE, PAS TRENTE-CINQ. Le pavé de raccourcis qui vivait ici criait
## aussi fort que la case sous le curseur, et personne ne le lisait. Il est
## passé derrière H ; il ne reste que de quoi savoir que H existe.
const AIDE := "clic gauche peindre · clic droit effacer · molette zoom · clic milieu tourner · H : tous les raccourcis"

func _etat() -> void:
	if _etiquette == null: return
	var quoi := ("SEMIS « %s »" % _modele.get_file() if _semer \
		else "OBJET « %s »" % _modele.get_file()) if _outil == OUTIL_OBJET \
		else (("RELIEF ±1" if _relief_relatif else "RELIEF palier %d" % _palier) \
			if _outil == OUTIL_RELIEF else "DESSIN « %s »" % _caractere())
	var nom_forme := "Libre"
	for f in FORMES:
		if int(f[0]) == _forme: nom_forme = String(f[1])
	# ⚠ COURT. Écrite en toutes lettres, cette ligne passait à deux lignes dans
	# le cartouche et poussait l'aide hors du cadre : ce qu'on lit vingt fois
	# par minute doit tenir sur UNE ligne.
	_etiquette.text = "%s · %s · case (%d, %d) palier %d · %d×%d · angle %s° · origine (%s, %s)" % [
		quoi, nom_forme, _case.x, _case.y, _palier_de(_case.x, _case.y), _large(), _haut(),
		_nombre(float(_fiche.get("angle", 0.0))),
		_nombre((_fiche.get("origine", Vector2.ZERO) as Vector2).x),
		_nombre((_fiche.get("origine", Vector2.ZERO) as Vector2).y)]
	# L'OBJET CHOISI PASSE DEVANT LE RESTE : tant qu'il y en a un, c'est lui
	# qu'on règle, et la ligne d'état doit dire lequel.
	if _objet_choisi >= 0 and _objet_choisi < _objets().size():
		var oc: Dictionary = _objets()[_objet_choisi]
		_etiquette.text = "OBJET CHOISI « %s » en (%d, %d) · hauteur %s · angle %s° · Suppr pour l'ôter" % [
			_nom_objet(_objet_choisi), int(oc["i"]), int(oc["j"]),
			_nombre(float(oc.get("h", 10.0))), _nombre(float(oc.get("r", 0.0)))]
	if _aide != null: _aide.text = AIDE
	if _collage and not _presse.is_empty():
		_etiquette.text = "COLLAGE %d × %d en (%d, %d) — clic gauche pose, clic droit ou Échap annule" % [
			int(_presse["w"]), int(_presse["h"]), _case.x, _case.y]
	_regler_nappe()
	if _carte2d != null: _carte2d.queue_redraw()
	if _reglette != null: _reglette.queue_redraw()

# ------------------------------------------------------------- la mini-carte

## LE PLAN, à plat, tel qu'il est écrit. Les couleurs sont celles des pinceaux
## — la colonne et la carte disent donc la même chose — et le palier ÉCLAIRCIT
## la case : sans ça, une terrasse à trois crans et le trottoir d'à côté sont
## du même gris et le relief ne se voit que dans la vue 3D.
## ⚠ UNE TEXTURE, PAS QUARANTE-HUIT MILLE RECTANGLES. La première version
## dessinait la carte case par case à chaque `queue_redraw` — donc à chaque
## pixel parcouru par la souris. Sur les six petits quartiers, six cents
## rectangles passaient inaperçus ; sur Pikstown, 48 375 rectangles par
## mouvement de souris figeaient l'éditeur. On peint donc une IMAGE d'un pixel
## par case, une seule fois par modification du plan, et le `draw` ne fait plus
## que l'étirer et poser le curseur et les fautes par-dessus.
## La teinte d'une case, prête à poser dans l'image.
func _teinte_case(c: String, i: int, j: int) -> Color:
	if _carte_relief:
		# LA CARTE DU RELIEF : la chaussée reste plus sombre, pour garder le
		# plan de rues comme repère par-dessus les paliers.
		var t: Color = RAMPE[clampi(_palier_de(i, j), 0, RAMPE.size() - 1)]
		return t.darkened(0.42) if CHAUSSEE.contains(c) else t
	if _teintes.is_empty():
		for p in PINCEAUX:
			_teintes[String(p[0])] = p[2]
			_teintes[String(p[0]).to_lower()] = p[2]
		for k in CHAUSSEE.length():
			_teintes[CHAUSSEE[k]] = TEINTE_VOIE
	var teinte: Color = _teintes.get(c, Color("#ff00ff"))
	teinte = teinte.lightened(float(_palier_de(i, j)) * 0.07)
	# La minuscule d'une famille est un AUTRE bâtiment : sans ça, `TTtt` et
	# `TTTT` se ressemblent sur la carte.
	if FAMILLES.contains(c.to_upper()) and c == c.to_lower():
		teinte = teinte.darkened(0.22)
	return teinte

## ⚠ SEULEMENT LES CASES TOUCHÉES. Repeindre les 96 000 pixels au relâchement de
## chaque coup de pinceau coûtait plus cher que de rebâtir les morceaux — pour
## vingt cases changées. L'image est gardée, on y pose les cases modifiées et on
## dit à la texture de se rafraîchir.
func _toucher_carte(cases: Array) -> void:
	if _carte_img == null or _carte_image == null:
		_redessiner_carte()
		return
	for v in cases:
		var c: Vector2i = v
		if not _dans_grille(c.x, c.y): continue
		var car := _lire("plan", c.x, c.y)
		_carte_img.set_pixel(c.x, c.y,
			Color("#16323f") if car == "." else _teinte_case(car, c.x, c.y))
	_carte_image.update(_carte_img)
	if _carte2d != null: _carte2d.queue_redraw()

func _redessiner_carte() -> void:
	var l := _large()
	var h := _haut()
	if l <= 0 or h <= 0: return
	var img := Image.create(l, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#16323f"))
	for j in h:
		var ligne := String(_lignes("plan")[j])
		for i in mini(l, ligne.length()):
			var c := ligne[i]
			if c == ".": continue
			# La chaussée est peinte plus sombre que son pinceau : au gris du
			# pinceau, les rues et les bureaux se confondaient et la carte
			# devenait un aplat laiteux où le plan de rues ne se voyait plus.
			var teinte := _teinte_case(c, i, j)
			img.set_pixel(i, j, teinte)
	_carte_img = img
	_carte_image = ImageTexture.create_from_image(img)
	if _carte2d != null: _carte2d.queue_redraw()

## Dix cases de couleur, un chiffre dans chacune, la courante encadrée de blanc.
func _dessiner_reglette() -> void:
	if _reglette == null: return
	var l := _reglette.size.x / 10.0
	var police := Atelier.police()
	for k in 10:
		var r := Rect2(Vector2(float(k) * l, 0), Vector2(l - 1.0, _reglette.size.y))
		_reglette.draw_rect(r, RAMPE[k], true)
		if k == _palier:
			_reglette.draw_rect(r, Palette.ENCRE, false, 2.0)
		_reglette.draw_string(police, Vector2(r.position.x, r.position.y + 16.0),
			str(k), HORIZONTAL_ALIGNMENT_CENTER, l - 1.0, Atelier.CORPS_PETIT,
			Atelier.FOND if k < 5 else Atelier.ENCRE)

func _dessiner_carte() -> void:
	var l := _large()
	var h := _haut()
	if l <= 0 or h <= 0 or _carte_image == null: return
	var s: Vector2 = _carte2d.size
	var pas := minf(s.x / float(l), s.y / float(h))
	var org := Vector2((s.x - pas * float(l)) * 0.5, (s.y - pas * float(h)) * 0.5)
	_carte_pas = pas
	_carte_org = org
	var emprise := Rect2(org, Vector2(pas * float(l), pas * float(h)))
	_carte2d.draw_texture_rect(_carte_image, emprise, false)
	if l <= 64:
		for i in range(0, l + 1, 5):
			var x := org.x + float(i) * pas
			_carte2d.draw_line(Vector2(x, org.y), Vector2(x, org.y + pas * float(h)), Color(1, 1, 1, 0.10))
		for j in range(0, h + 1, 5):
			var y := org.y + float(j) * pas
			_carte2d.draw_line(Vector2(org.x, y), Vector2(org.x + pas * float(l), y), Color(1, 1, 1, 0.10))
	for f in _fautives.keys():
		var c2: Vector2i = f
		_carte2d.draw_rect(Rect2(org + Vector2(float(c2.x), float(c2.y)) * pas,
			Vector2(maxf(pas, 2.0), maxf(pas, 2.0))), Palette.CRITIQUE, false, maxf(1.0, pas * 0.3))
	if _selection.size != Vector2i.ZERO:
		_carte2d.draw_rect(Rect2(org + Vector2(_selection.position) * pas,
			Vector2(_selection.size) * pas), Color("#ffd23f"), false, maxf(1.0, pas * 0.4))
	_carte2d.draw_rect(emprise, Color(1, 1, 1, 0.25), false, 1.0)
	if _dans_grille(_case.x, _case.y):
		_carte2d.draw_rect(Rect2(org + Vector2(float(_case.x), float(_case.y)) * pas,
			Vector2(maxf(pas, 3.0), maxf(pas, 3.0))), Color("#ffd23f"), false, maxf(1.0, pas * 0.5))
	# LA VUE : sur une carte de 225 cases, savoir OÙ l'on regarde dans la ville
	# est plus utile que n'importe quel autre repère de la mini-carte.
	if _camera != null:
		var vue := _quartier.global_transform.affine_inverse() * _pivot if _quartier != null else _pivot
		var p := org + Vector2(vue.x / CASE, vue.z / CASE) * pas
		_carte2d.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("#3987e5"), false, 2.0)

func _carte_souris(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		# ⚠ SE DÉPLACER DEPUIS LA MINI-CARTE. Sur 320 × 300 cases, traverser la
		# ville au clavier prend une minute, et la mini-carte était le seul
		# endroit où l'on voyait où aller — sans pouvoir y aller. Clic milieu,
		# ou Ctrl+clic : la caméra se pose sur la case visée.
		if b.button_index == MOUSE_BUTTON_MIDDLE or (b.ctrl_pressed and b.pressed):
			if b.pressed:
				_carte_viser(b.position)
				if _vise: _aller_a(_case)
			return
		if b.button_index != MOUSE_BUTTON_LEFT and b.button_index != MOUSE_BUTTON_RIGHT: return
		if b.pressed:
			_gauche = b.button_index == MOUSE_BUTTON_LEFT
			if b.alt_pressed or _forme == FORME_PIPETTE:
				_carte_viser(b.position)
				_prelever()
				return
			_empiler()
			_peint_carte = true
			_carte_poser(b.position)
		else:
			_peint_carte = false
			_finir_geste()
	elif e is InputEventMouseMotion:
		_carte_viser((e as InputEventMouseMotion).position)
		if _peint_carte:
			_carte_poser((e as InputEventMouseMotion).position)
		else:
			_etat()

func _aller_a(c: Vector2i) -> void:
	if _quartier == null: return
	_pivot = _quartier.global_transform * Vector3((float(c.x) + 0.5) * CASE,
		float(_palier_de(c.x, c.y)) * PALIER, (float(c.y) + 0.5) * CASE)
	_dessus = false
	_poser_camera()
	if _ville != null:
		_ville.rayon = _rayon_utile()
		_ville.suivre(_pivot)
	_dire("Déplacé en (%d, %d)." % [c.x, c.y])
	_etat()

func _carte_viser(p: Vector2) -> void:
	if _carte_pas <= 0.0: return
	var c := Vector2i(floori((p.x - _carte_org.x) / _carte_pas), floori((p.y - _carte_org.y) / _carte_pas))
	_vise = _dans_grille(c.x, c.y)
	if _vise:
		_case = c
		_montrer_curseur()

## La carte peint TOUJOURS à main levée, quelle que soit la forme choisie : on
## y vient pour corriger une case précise, pas pour tirer une avenue — et un
## rectangle tracé sur cent quatre-vingt-dix pixels de haut se rate.
func _carte_poser(p: Vector2) -> void:
	_carte_viser(p)
	if not _vise: return
	_poser(_case.x, _case.y, _gauche)
	_etat()
