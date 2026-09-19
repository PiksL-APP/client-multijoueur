extends Ecran
## L'ÉDITEUR DE CARTE — LE SEUL. Cahier § 10.
##
## Depuis le 19/09 il n'y a plus d'« éditeur 1 » (le dessin ASCII de Pikstown)
## ni d'« éditeur 2 » : le jeu ne tourne que sur l'Archipel des Aurones, et
## cet écran est son unique atelier. Il a sa propre page en ligne,
## multijoueur.piks-l.com/editeur (voir `web/editeur.html`), et s'ouvre aussi
## par `--ecran=editeur` en ligne de commande, `?ecran=editeur` dans le
## navigateur, ou seul par F6 sur `scenes/editeur.tscn`. Il charge `cartes/<nom>.json`,
## bâtit la ville avec le même rendu que le jeu, et laisse :
##   - TRACER UNE ROUTE par points cliqués sur la grille (R) : chaque clic pose
##     un sommet, un tracé en biais devient un coude, Entrée ou clic droit
##     termine ; le genre (rue / avenue / voie rapide) se change avec G ;
##   - POSER UN BÂTIMENT (B) du kit sur la grille des demi-cases, tourner
##     avec Q / E, refusé sur une rue, un autre lot ou l'eau ;
##   - POSER UN OBJET (O) — lampadaire, arbre, banc, voiture… — aimanté au
##     sol, tourné avec Q / E, refusé sur une rue (sauf les voitures) ;
##   - SCULPTER LE TERRAIN (T) : clic gauche monte d'un palier, droit descend,
##     rayon avec + / − ; PEINDRE L'EAU (W) : gauche = eau, droit = terre ;
##   - SÉLECTIONNER (S) : clic sur un lot, un objet ou une rue, Suppr efface,
##     Q / E tourne un lot ou un objet ;
##   - Ctrl+Z / Ctrl+Y, Ctrl+S enregistre (dans `res://cartes/` au bureau,
##     dans `user://cartes/` au navigateur), P photographie.
##
## LA PALETTE montre TOUS les modèles du dossier `modeles/`, variantes
## comprises — filtrés par famille et par recherche — et le modèle choisi
## tourne dans un aperçu 3D à côté. « Pose libre » lève les refus (rue, eau,
## lot) pour retoucher à la main ; Page haut / Page bas décalent l'objet en
## hauteur, ce qui permet de poser sur une jetée ou un toit.
##
## Caméra : clic droit tenu = orbite, molette = zoom, clic milieu ou
## Maj + clic = déplacer, flèches / ZQSD = déplacer, Début = tout voir.

## ⚠ UN `preload`, PAS LE NOM DE CLASSE. `class_name` ne se résout qu'à travers
## `.godot/global_script_class_cache.cfg`, que `godot --headless --import` NE
## RÉÉCRIT PAS : seul l'éditeur le fait. Un générateur tout neuf compilait donc
## au bureau et tombait en ligne — « Identifier "GenerateurColline" not declared
## in the current scope », et l'écran entier refusait de se charger. Un preload
## se résout par CHEMIN : il n'a besoin de personne.
const COLLINE := preload("res://commun/ville2/generateur_colline.gd")
## ⭐ LE PAYS. `?ecran=editeur&pays=1` ouvre l'Archipel des Aurones au lieu
## d'une carte enregistrée : le plan cuit est relu, et la FENÊTRE demandée est
## bâtie à la volée. Vingt kilomètres sur vingt ne tiennent pas dans une seule
## `Ville2` — un million de cases et un million et demi de lots — donc on en
## regarde un morceau à la fois, et on se déplace en changeant `ou`.
const PLAN_PAYS := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")
const FENETRES := preload("res://commun/ville2/fenetres_pays.gd")
const CONTROLE := preload("res://commun/ville2/controle_tuile.gd")
const COTE_PAYS: int = FENETRES.COTE   ## la tuile du jeu : 200 cases

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI
const PALIER := Ville2.PALIER

enum { OUTIL_SELECTION, OUTIL_ROUTE, OUTIL_LOT, OUTIL_OBJET, OUTIL_TERRAIN, OUTIL_EAU, OUTIL_SOL }
const NOMS_OUTILS := ["Sélection", "Route", "Bâtiment", "Objet", "Terrain", "Eau", "Sol"]
## LES MATIÈRES DU SOL, pour l'outil Sol (19/09) : ce que le terrain continu
## peint sous les pieds — herbe, sable, terre, roche, dalle. Le centre-ville est
## en dalle et la banlieue en herbe parce que le générateur l'a décidé ; l'outil
## laisse le client en décider autrement, au pinceau.
const MATIERES := [
	["Herbe", Ville2.M_HERBE], ["Sable", Ville2.M_SABLE], ["Terre", Ville2.M_TERRE],
	["Roche", Ville2.M_ROCHE], ["Dalle", Ville2.M_DALLE],
]
var _matiere_choisie := 0
## ⚠ DES CHIFFRES, PAS DES LETTRES. Les lettres servent à SE DÉPLACER
## (ZQSD, comme dans le jeu et comme dans Godot) : tant que « S » choisissait
## l'outil Sélection, avancer la caméra changeait d'outil.
const RACCOURCIS_OUTILS := ["1", "2", "3", "4", "5", "6", "7"]
const GENRES_ROUTE := [Ville2.R_RUE, Ville2.R_AVENUE, Ville2.R_VOIE_RAPIDE]

## LES RACCOURCIS DE LA PALETTE : les props que les générateurs posent, avec
## leur hauteur réglée. Ils ouvrent la liste, avant le catalogue complet.
##
## ⚠ PLUS DE LISTE TENUE À LA MAIN. Elle en comptait trente, figés ; le jour où
## `KitVille2.PROPS` en a gagné trente-cinq de plus (le kit nature), l'éditeur
## n'en montrait toujours que trente. Elle se DÉDUIT maintenant du kit.
static func raccourcis() -> Array:
	var l: Array = KitVille2.PROPS.keys()
	l.sort()
	l.append("pelouse")
	for v in KitVille2.VOITURES:
		l.append(v)
	for v in ["voitures/police", "voitures/ambulance", "voitures/firetruck",
			"voitures/garbage-truck", "voitures/truck"]:
		if not l.has(v): l.append(v)
	return l
const FAMILLE_TOUT := "— tout —"
const FAMILLE_RACCOURCIS := "★ raccourcis"
## LES RÉCENTS : les douze derniers modèles posés, en tête du catalogue. On
## pose rarement un modèle une seule fois ; le retrouver dans sept cents
## vignettes à chaque fois, c'est ce que le rayon « ↺ récents » évite. Gardés
## dans le profil du navigateur (`user://`), d'une séance à l'autre.
const FAMILLE_RECENTS := "↺ récents"
const RECENTS_MAXI := 12
const FICHIER_RECENTS := "user://recents_editeur.json"
var _recents: Array = []

const TEINTE_GRILLE := Color(1, 1, 1, 0.18)
const TEINTE_OK := Color("#2fe0d0")
const TEINTE_NON := Color("#ff2f86")
const TEINTE_ROUTE := Color("#ff9040")
const TEINTE_SELECTION := Color("#ffe14d")

var _chemin := PlanV2.CHEMIN_PAR_DEFAUT
var _ville: Ville2
var _morceaux: MorceauxV2
var _camera: Camera3D
var _grille: MeshInstance3D
var _apercu: Node3D                    ## le fantôme du geste en cours
var _cadre: MeshInstance3D              ## le cadre de la sélection

var _outil := OUTIL_SELECTION
var _genre_route := 0
var _lot_choisi := 0
var _objet_choisi := 0
var _quarts := 0
var _rayon_terrain := 2
var _trace: Array = []                  ## les sommets de la route en cours
var _selection := {}                    ## {"genre": "lot"|"objet"|"route", "k": int}
## LA SÉLECTION AU LASSO (19/09) : à l'outil Sélection, tirer sur du vide
## dessine un rectangle au sol ; au relâchement, tout objet et tout bâtiment
## dedans est retenu dans `_multi`, et Suppr les efface d'un coup. C'est la
## seule façon de nettoyer un pâté sans cliquer cent fois.
var _multi: Array = []                  ## [{"genre": "objet"|"lot", "k": int}, …]
var _presse_papier := {}                ## Ctrl+C : {"objets": [...], "lots": [...]} en relatif à l'ancre
var _lasso_depart := Vector3(-1e9, 0, 0)
var _lasso_fin := Vector3.ZERO

var _pivot := Vector3.ZERO
var _distance := 420.0
var _azimut := 0.6
var _inclinaison := 0.9
var _orbite := false
var _glisse := false
var _souris := Vector2.ZERO
var _case := Vector2i(-1, -1)
var _point := Vector3.ZERO              ## le point visé, au sol
var _presse := false
var _tire := false                      ## on déplace la sélection à la souris
var _tire_depart := Vector3.ZERO        ## le point du sol sous le curseur au clic
var _tire_ref := Vector2.ZERO           ## la position de l'objet (ou du lot) au clic
var _tire_bouge := false                ## le seuil de 3 unités a été franchi

var _pile: Array[String] = []
var _refaire: Array[String] = []
var _etat: Label
var _titre: Label
var _palette: ItemList
var _cartes: OptionButton
var _familles: OptionButton
var _recherche: LineEdit
var _libre: CheckBox
var _sens: CheckBox                     ## afficher les sens de circulation
var _fleches: Node3D                    ## la surcouche des sens
var _aimant: OptionButton

## LES PAS D'AIMANT. « libre » vaut zéro : rien n'est arrondi, l'objet se pose
## là où pointe la souris. Les autres sont les trames du jeu — le décimètre pour
## l'ajustement fin, le demi-mètre (l'ancien réglage en dur), le mètre, puis la
## demi-case et la case, qui sont les trames du kit.
const PAS_AIMANT := [
	{"nom": "libre", "pas": 0.0},
	{"nom": "0,1", "pas": 0.1},
	{"nom": "0,5", "pas": 0.5},
	{"nom": "1", "pas": 1.0},
	{"nom": "demi-case", "pas": Ville2.DEMI},
	{"nom": "case", "pas": Ville2.CASE},
]
const PAS_DEFAUT := 2                   ## 0,5 — ce qui se faisait avant

## Le pas d'aimant courant, en unités. Zéro : pose libre.
func pas_d_aimant() -> float:
	if _aimant == null: return 0.5
	var k := clampi(_aimant.selected, 0, PAS_AIMANT.size() - 1)
	return float((PAS_AIMANT[k] as Dictionary)["pas"])

## Arrondit une coordonnée au pas courant — ou la laisse telle quelle.
func _aimanter(valeur: float) -> float:
	var pas := pas_d_aimant()
	return valeur if pas <= 0.0 else snappedf(valeur, pas)
var _apercu3d: SubViewport
var _apercu_noeud: MeshInstance3D
var _apercu_nom: Label
var _compteur: Label
var _aide: Label
var _info: RichTextLabel
var _champ_rayon: SpinBox
var _champ_decalage: SpinBox
var _boutons_outils: Array[Button] = []
var _liste: Array[String] = []          ## ce que la palette montre en ce moment
var _decalage := 0.0                    ## la hauteur ajoutée à l'objet posé
var _cle_pays := Vector2i(2, 2)         ## la tuile ouverte, sur la grille du jeu
var _centre_pays := Vector2i(500, 500)  ## le centre de la fenêtre ouverte, en cases
var _cote_pays := 200                   ## son côté, en cases
var _minicarte: Control                 ## le plan du pays entier, cliquable
var _tourne_apercu := 0.0
var _photo_sortie := ""
var _manque := ""                       ## la carte demandée et introuvable

# ------------------------------------------------------------------ mise en place

func _ready() -> void:
	if get_parent() == get_tree().root:
		demarrer()

## LA FENÊTRE DU PAYS, bâtie à la demande. `ou` est le CENTRE en cases
## (« 500,500 » = le milieu de la carte, la Gare Centrale), `large` le côté.
##
## ⚠ UN REPLI QUI SE VOIT. Sans le plan cuit dans le paquet, on rendrait une
## ville vide et l'écran montrerait la mer : on préfère le dire.
## Est-on en train de regarder le pays ? La question se pose AVANT que le
## terrain soit bâti (pour la nappe d'eau) et APRÈS (pour l'enregistrement) :
## elle relit donc les paramètres, elle ne se déduit pas de l'état.
func _est_le_pays() -> bool:
	if String(donnees.get("pays", "")) not in ["", "0"]: return true
	for a in OS.get_cmdline_args():
		if a.begins_with("--pays=") and a.trim_prefix("--pays=") not in ["", "0"]:
			return true
	return false

## ⭐⭐⭐ LA FENÊTRE DE L'ÉDITEUR EST UNE TUILE DU JEU (19/09).
##
## Jusqu'ici l'éditeur ouvrait une fenêtre centrée N'IMPORTE OÙ, de la taille
## qu'on voulait — et le jeu, lui, bâtit le pays par tuiles fixes de 200 cases
## alignées sur la grille (`FenetresPays.COTE`, clé = case ÷ 200). Une fenêtre
## retouchée en 500,500 × 120 ne correspondait à AUCUNE tuile du jeu : on
## pouvait l'enregistrer, la publier, elle ne serait jamais jouée. L'éditeur
## travaille donc maintenant tuile par tuile, sous le nom que le jeu relit
## (`cartes/pays-<kx>-<ky>.json`) — ce qu'on enregistre ici est ce qu'on joue.
## `ou` reste un centre : on en déduit la tuile.
func _la_fenetre_du_pays(ou: String, _large: int) -> Ville2:
	var plan := PLAN_PAYS.charger()
	if plan.is_empty():
		_manque = PLAN_PAYS.PLAN_CUIT
		return GenerateurCentre.generer(1)
	var m: PackedStringArray = ou.split(",")
	var c := Vector2i(500, 500)
	if m.size() == 2: c = Vector2i(int(m[0]), int(m[1]))
	c = Vector2i(clampi(c.x, 0, PLAN_PAYS.TAILLE.x - 1), clampi(c.y, 0, PLAN_PAYS.TAILLE.y - 1))
	var cle := FENETRES.cle_de_case(c)
	var coin := cle * COTE_PAYS
	var taille := Vector2i(mini(COTE_PAYS, PLAN_PAYS.TAILLE.x - coin.x),
		mini(COTE_PAYS, PLAN_PAYS.TAILLE.y - coin.y))
	var cote := COTE_PAYS
	# La minicarte a besoin de savoir OÙ l'on regarde pour dessiner son cadre.
	_cle_pays = cle
	_centre_pays = coin + taille / 2
	_cote_pays = cote
	# ⭐⭐⭐ UNE FENÊTRE RETOUCHÉE GAGNE SUR LA FENÊTRE ENGENDRÉE.
	#
	# Jusqu'ici, tout ce qu'on posait en mode pays était perdu à la fermeture :
	# l'éditeur rebâtissait la fenêtre depuis le plan à chaque ouverture, et le
	# Ctrl+S écrivait un fichier que personne ne relisait jamais. C'est la même
	# règle que pour les témoins (« la version enregistrée gagne sur celle
	# livrée ») — elle manquait simplement ici.
	#
	# ⚠ LA CLÉ DOIT PORTER LA TAILLE, PAS SEULEMENT LE CENTRE. Deux fenêtres
	# centrées au même endroit mais larges de 60 et de 200 cases ne sont pas la
	# même carte ; sans la taille dans le nom, la petite écrasait la grande.
	_chemin = _carte_du_pays(cle)
	# ⚠ ON PASSE PAR `carte_modifiee`, PAS PAR `FileAccess` EN DIRECT. C'est la
	# même question que se posent la liste des cartes, le bouton Rétablir et la
	# pastille « ● modifiée » ; s'ils ne la posent pas de la même façon, l'un
	# d'eux finit par répondre autrement que les autres.
	# ⚠ ET LA VERSION LIVRÉE DANS LE PAQUET AUSSI : une tuile publiée
	# (`cartes/pays-2-2.json` dans le dépôt) gagne sur la tuile engendrée,
	# exactement comme dans le jeu (`FenetresPays._commander`).
	if Ville2.carte_modifiee(_chemin) or FileAccess.file_exists(_chemin):
		var reprise := Ville2.charger(_chemin)
		if reprise != null and reprise.taille == taille:
			_dire("Tuile %d,%d : %s (%d lots)." % [cle.x, cle.y,
				"ta version enregistrée" if Ville2.carte_modifiee(_chemin) else "la version livrée",
				reprise.lots.size()])
			return reprise
	var f := Rect2i(coin, taille)
	var ctx := PLAN_PAYS.contexte(plan)
	return PAYS.fenetre(plan, ctx, f, {"nom": "Aurones %d,%d" % [coin.x, coin.y]})

## Relit le centre et le côté écrits dans le nom d'une fenêtre du pays.
## `pays-472-505-160` → centre (472, 505), côté 160. Sans effet sur un témoin.
func _relire_le_cadre(nom: String) -> void:
	if not nom.begins_with("pays-"): return
	var m := nom.trim_prefix("pays-").split("-")
	if m.size() == 2:
		# Une tuile du jeu : `pays-<kx>-<ky>`.
		_cle_pays = Vector2i(int(m[0]), int(m[1]))
		_centre_pays = _cle_pays * COTE_PAYS + Vector2i(COTE_PAYS, COTE_PAYS) / 2
		_cote_pays = COTE_PAYS
	elif m.size() == 3:
		# L'ancien nommage (centre et côté), gardé pour relire un fichier d'avant.
		_centre_pays = Vector2i(int(m[0]), int(m[1]))
		_cote_pays = int(m[2])
		_cle_pays = FENETRES.cle_de_case(_centre_pays)
	if _minicarte != null: _minicarte.queue_redraw()

## Le nom de fichier d'une tuile du pays : sa clé sur la grille du jeu.
func _carte_du_pays(cle: Vector2i) -> String:
	return "res://cartes/pays-%d-%d.json" % [cle.x, cle.y]

func demarrer() -> void:
	# ⚠ `donnees` D'ABORD, LA LIGNE DE COMMANDE ENSUITE. Dans le navigateur la
	# ligne de commande est vide : c'est `scenes/racine.gd` qui lit l'URL et
	# nous passe ses paramètres ici. Au bureau, les deux disent la même chose.
	for a in OS.get_cmdline_args():
		if a.begins_with("--carte="): _chemin = a.trim_prefix("--carte=")
		if a.begins_with("--cliche="): _photo_sortie = a.trim_prefix("--cliche=")
	if donnees.has("carte"): _chemin = String(donnees["carte"])
	if donnees.has("cliche"): _photo_sortie = String(donnees["cliche"])
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb:
		monde().add_child(n)
	MatieresCarnage.nuit_forcee = 0.0
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], 0.0)
	MatieresCarnage.regler_nuit(0.0)
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.04
	var soleil := amb[1] as DirectionalLight3D
	soleil.directional_shadow_max_distance = 2600.0
	soleil.light_color = Color("#fff3dc")
	soleil.light_energy = 1.75
	env.ambient_light_color = Color("#cfd6e4")
	env.ambient_light_energy = 0.55

	# ⚠⚠ LA NAPPE D'EAU DE L'ÉDITEUR NE VAUT QUE POUR UNE CARTE DE TÉMOIN. C'est
	# un plan de six cents cases posé au niveau de la mer, qui donne son fond
	# bleu à une petite carte. Sur une fenêtre du PAYS, dont le terrain porte
	# déjà sa propre mer case par case et dont les plaines sont à quelques
	# centimètres au-dessus du niveau zéro, cette nappe passe DEVANT la ville :
	# la capitale entière se retrouvait sous un voile turquoise quadrillé. Le
	# pays fait sa mer tout seul.
	if not _est_le_pays():
		var mer := MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = Vector2(600.0 * CASE, 600.0 * CASE)
		mer.mesh = plan
		mer.material_override = MatieresCarnage.eau()
		mer.position = Vector3(0, -2.85, 0)
		monde().add_child(mer)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 9000.0
	monde().add_child(_camera)
	_camera.make_current()

	# `--temoin=plage` (ou `?temoin=plage`) engendre un témoin neuf plutôt que
	# de lire un fichier : c'est la façon la plus courte de REGARDER ce que le
	# générateur vient de produire, sans rien enregistrer.
	var temoin := String(donnees.get("temoin", ""))
	var pays := String(donnees.get("pays", ""))
	var ou := String(donnees.get("ou", "500,500"))
	var large := int(String(donnees.get("large", "160")))
	for a2 in OS.get_cmdline_args():
		if a2.begins_with("--temoin="): temoin = a2.trim_prefix("--temoin=")
		if a2.begins_with("--pays="): pays = a2.trim_prefix("--pays=")
		if a2.begins_with("--ou="): ou = a2.trim_prefix("--ou=")
		if a2.begins_with("--large="): large = int(a2.trim_prefix("--large="))
	if pays != "" and pays != "0":
		# ⚠ `_chemin` EST POSÉ PAR `_la_fenetre_du_pays` : c'est lui qui connaît
		# le centre et la taille effectivement retenus (bornés), donc lui seul
		# peut nommer la carte que le Ctrl+S écrira et que la prochaine
		# ouverture relira.
		_ville = _la_fenetre_du_pays(ou, large)
	elif temoin == "plage":
		_ville = GenerateurPlage.generer(2)
		_chemin = "res://cartes/temoin-plage.json"
	elif temoin == "colline":
		_ville = COLLINE.generer(3)
		_chemin = "res://cartes/temoin-colline.json"
	elif temoin == "centre":
		_ville = GenerateurCentre.generer(1)
	else:
		_ville = Ville2.charger(_chemin)
		# ⚠ LE REPLI DOIT SE VOIR. Une carte absente du paquet rendait une
		# ville vide, on repliait sur le générateur du centre… et l'écran
		# montrait le centre en silence : impossible de distinguer « la carte
		# demandée n'existe pas » de « elle est arrivée ».
		if _ville.lots.is_empty() and _ville.routes.is_empty():
			_manque = _chemin
			_ville = GenerateurCentre.generer(1)
	_morceaux = MorceauxV2.new()
	# ⚠ PAS `tout()` ICI. Bâtir seize cents cases d'un bloc fige l'onglet
	# plusieurs secondes dans le navigateur, et l'utilisateur croit que la page
	# a planté. `suivre()` remplit la file, `_process` la vide une passe par
	# image : la ville paraît morceau par morceau, et la page répond tout du
	# long.
	_morceaux.par_image = 2
	_morceaux.regler(_ville, 99)
	monde().add_child(_morceaux)
	_morceaux.suivre(Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5))
	if "--essai" in OS.get_cmdline_args() or _photo_sortie != "":
		_morceaux.tout()

	_apercu = Node3D.new()
	monde().add_child(_apercu)
	_fleches = Node3D.new()
	_fleches.visible = false
	monde().add_child(_fleches)
	_cadre = MeshInstance3D.new()
	_cadre.visible = false
	monde().add_child(_cadre)
	_poser_grille()
	_tout_voir()
	# L'état de référence : à partir d'ici, toute différence est du travail non
	# enregistré, et `_changer_de_carte` préviendra avant de le jeter.
	_dernier_enregistre = _ville.vers_json()
	_interface()
	if _manque != "":
		_dire("⚠ « %s » introuvable dans le paquet — c'est le centre qui s'affiche." % _manque)
		return
	_dire("Ville « %s » — %d lots, %d objets, %d routes. R route · B bâtiment · O objet · T terrain · W eau · S sélection · Ctrl+S enregistre" % [
		_ville.nom, _ville.lots.size(), _ville.objets.size(), _ville.routes.size()])
	if "--essai" in OS.get_cmdline_args():
		get_tree().create_timer(1.0).timeout.connect(_essai)
	elif _photo_sortie != "":
		get_tree().create_timer(2.0).timeout.connect(_photographier)

## LE BANC DE L'ÉDITEUR (`--ecran=editeur --essai --cliche=/tmp/e.png`) :
## chaque outil est joué comme si la souris cliquait, et on compte.
func _essai() -> void:
	var t0 := Time.get_ticks_msec()
	var lots0 := _ville.lots.size()
	var objets0 := _ville.objets.size()
	var routes0 := _ville.routes.size()
	# Une route en L dans la bande vide du sud, de (3,38) à (30,39).
	_choisir_outil(OUTIL_ROUTE)
	_genre_route = 1
	for c in [Vector2i(3, 38), Vector2i(30, 39)]:
		_case = c
		_point = Vector3((float(c.x) + 0.5) * CASE, 0, (float(c.y) + 0.5) * CASE)
		_appliquer(true)
	_finir_route(true)
	print("[essai] route : %d -> %d routes, %s" % [routes0, _ville.routes.size(), _etat.text])
	# Un bâtiment sur la bande vide de l'ouest, puis un refusé sur la rue.
	_choisir_outil(OUTIL_LOT)
	_lot_choisi = 0
	_quarts = 1
	_case = Vector2i(0, 20)
	_point = Vector3(1.0 * CASE, 0, 20.5 * CASE)
	_appliquer(true)
	var lots1 := _ville.lots.size()
	_case = Vector2i(2, 20)
	_point = Vector3(2.5 * CASE, 0, 20.5 * CASE)
	_appliquer(true)
	print("[essai] lots : %d -> %d (posé) -> %d (refusé sur rue) — %s" % [lots0, lots1, _ville.lots.size(), _etat.text])
	# Un objet, puis un refusé sur la rue.
	_choisir_outil(OUTIL_OBJET)
	_objet_choisi = 5
	_case = Vector2i(1, 24)
	_point = Vector3(1.5 * CASE, 0, 24.5 * CASE)
	_appliquer(true)
	var objets1 := _ville.objets.size()
	_case = Vector2i(2, 24)
	_point = Vector3(2.5 * CASE, 0, 24.5 * CASE)
	_appliquer(true)
	print("[essai] objets : %d -> %d (posé) -> %d (refusé) — %s" % [objets0, objets1, _ville.objets.size(), _etat.text])
	# Le terrain : une bosse au coin sud-est, deux paliers.
	_choisir_outil(OUTIL_TERRAIN)
	_case = Vector2i(37, 36)
	_appliquer(true)
	_appliquer(true)
	print("[essai] terrain : palier %d en (37,36), %d en (39,39) — %s" % [_ville.palier(Vector2i(37, 36)), _ville.palier(Vector2i(39, 39)), _etat.text])
	# LA SÉLECTION SE VÉRIFIE SUR UN OBJET QUI EXISTE, pas sur une case choisie
	# d'avance : le banc visait (0,20) et ne trouvait rien, et c'est ce trou
	# qui a laissé passer « la sélection ne marche pas » jusqu'au client.
	_choisir_outil(OUTIL_SELECTION)
	var cible: Dictionary = _ville.objets[_ville.objets.size() / 2]
	var ox := float(cible["x"])
	var oz := float(cible["z"])
	_point = Vector3(ox + 1.0, 0, oz + 1.0)
	_case = Vector2i(floori(_point.x / CASE), floori(_point.z / CASE))
	_selectionner()
	print("[essai] sélection objet : %s — %s" % [str(_selection), _etat.text])
	# Le glissé : on attrape, on tire de deux cases, on relâche.
	_armer_le_glisse()
	_point += Vector3(2.0 * CASE, 0, 0)
	_glisser()
	_poser_le_glisse()
	print("[essai] glissé : x %.1f -> %.1f (%s)" % [ox, float(cible["x"]), _etat.text])
	_annuler()
	print("[essai] glissé annulé : x %.1f" % float((_ville.objets[_ville.objets.size() / 2] as Dictionary)["x"]))
	# Le lasso : un rectangle de dix cases sur dix, tout ce qui est dedans, Suppr.
	_choisir_outil(OUTIL_SELECTION)
	_lasso_depart = Vector3(5.0 * CASE, 0, 5.0 * CASE)
	_lasso_fin = Vector3(15.0 * CASE, 0, 15.0 * CASE)
	_finir_le_lasso()
	var avant_l := _ville.objets.size() + _ville.lots.size()
	var pris := _multi.size()
	_supprimer_selection()
	print("[essai] lasso : %d pris, %d -> %d objets+lots — %s" % [pris, avant_l,
		_ville.objets.size() + _ville.lots.size(), _etat.text])
	_annuler()
	# Dupliquer (Ctrl+D) et la pose en série (Maj + deux clics).
	_selectionner()
	if not _selection.is_empty() and String(_selection["genre"]) == "objet":
		var avant_d := _ville.objets.size()
		_dupliquer_selection()
		print("[essai] dupliqué : %d -> %d objets, sélection %s" % [avant_d, _ville.objets.size(), str(_selection)])
		_annuler()
	_choisir_outil(OUTIL_OBJET)
	_objet_choisi = 0
	var avant_s := _ville.objets.size()
	_serie_depart = Vector3(2.0 * CASE, 0, 30.0 * CASE)
	_poser_en_serie(Vector3(2.0 * CASE, 0, 36.0 * CASE))
	print("[essai] série : %d -> %d objets — %s ; récents = %s" % [avant_s, _ville.objets.size(), _etat.text, str(_recents)])
	_annuler()
	_choisir_outil(OUTIL_SELECTION)
	# La fiche : taper un X, un angle et une hauteur, et voir l'objet suivre.
	_selectionner()
	if not _selection.is_empty() and String(_selection["genre"]) == "objet":
		_fiche_changee(ox + 15.0, "x")
		_fiche_changee(90.0, "r")
		_fiche_changee(0.5, "y")
		# ⚠ `cible` est périmé : l'annulation a rechargé la ville, et ses objets
		# sont de nouveaux dictionnaires. On relit celui que la sélection désigne.
		var tenu: Dictionary = _ville.objets[int(_selection["k"])]
		print("[essai] fiche : x %.1f (attendu %.1f), r %.2f rad, y_abs %s (champ X = %.1f)" % [float(tenu["x"]),
			ox + 15.0, float(tenu.get("r", 0.0)), str(tenu.get("y_abs", "absent")), (_champs_fiche["x"] as SpinBox).value])
		_annuler(); _annuler(); _annuler()
	else:
		print("[essai] fiche : rien sous le curseur après l'annulation (%s) — étape sautée" % str(_selection))
	# Puis un bâtiment : sélection, rotation, effacement.
	# On cherche un bâtiment dont le centre n'est pas encombré : un banc ou une
	# voiture garée pile au milieu volerait le clic, et le banc dirait « raté »
	# là où l'éditeur a bien fait son travail.
	var essais := 0
	for k in range(_ville.lots.size() / 2, _ville.lots.size()):
		var centre := _ville.centre_du_lot(_ville.lots[k])
		_point = centre
		_case = Vector2i(floori(centre.x / CASE), floori(centre.z / CASE))
		_selectionner()
		essais += 1
		if not _selection.is_empty() and String(_selection["genre"]) == "lot": break
	print("[essai] sélection lot : %s en %d essai(s) — %s" % [str(_selection), essais, _etat.text])
	_tourner_selection(1)
	_supprimer_selection()
	print("[essai] après suppression : %d lots — %s" % [_ville.lots.size(), _etat.text])
	_annuler()
	print("[essai] annulé : %d lots" % _ville.lots.size())
	_annuler()
	_annuler()
	# ⚠ UN VRAI CLIC, POUSSÉ DANS LA FENÊTRE. Tous les essais ci-dessus
	# appellent les gestes en direct : ils ont dit « la sélection marche »
	# pendant que le client, lui, ne pouvait RIEN sélectionner — un test plein
	# écran avalait chaque clic avant la ville. Celui-ci traverse tout le
	# chemin, `_unhandled_input` compris, et c'est le seul qui prouve quelque
	# chose sur ce qu'on livre.
	_tout_voir()
	_choisir_outil(OUTIL_SELECTION)
	_case = Vector2i(-9, -9)
	var ecran := get_viewport().get_visible_rect().size
	for presse in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = presse
		clic.position = ecran * 0.5
		get_viewport().push_input(clic)
	if _case == Vector2i(-9, -9):
		push_error("[essai] LE CLIC N'ARRIVE PAS JUSQU'À LA VILLE")
	print("[essai] clic réel au centre : case %s, sélection %s" % [str(_case), str(_selection)])
	# ⚠ LE BANC N'ÉCRIT PAS SUR LA CARTE QU'IL A OUVERTE. Il l'a couverte de
	# ses gestes d'essai : enregistrée en place, elle partait au dépôt.
	_chemin = "user://essai_editeur.json"
	_enregistrer()
	print("[essai] %s — %d ms" % [_etat.text, Time.get_ticks_msec() - t0])
	# La palette : on montre le catalogue complet et un modèle choisi, pour que
	# la capture du banc dise si l'aperçu 3D marche.
	_choisir_outil(OUTIL_OBJET)
	for k in _familles.item_count:
		if _familles.get_item_text(k).begins_with("kenney/batiments"):
			_familles.select(k)
			break
	_remplir_palette()
	_objet_choisi = 14
	_palette.select(mini(14, _palette.item_count - 1))
	_maj_apercu()
	print("[essai] palette : %d modèles, aperçu « %s »" % [_palette.item_count, _apercu_nom.text])
	_choisir_outil(OUTIL_OBJET)
	_case = Vector2i(10, 38)
	_point = Vector3(10.5 * CASE, 0, 38.5 * CASE)
	_montrer_apercu()
	# L'outil Sol : du sable sur un rond d'herbe, et la matière doit suivre.
	_choisir_outil(OUTIL_SOL)
	_matiere_choisie = 1
	_palette.select(1)
	_rayon_terrain = 3
	_case = Vector2i(20, 20)
	var avant_m := _ville.matiere_de(_case)
	_appliquer(true)
	print("[essai] sol : matière %d -> %d en (20,20) — %s" % [avant_m, _ville.matiere_de(_case), _etat.text])
	_annuler()
	# La pipette : on sélectionne un objet de la ville, I le met en main.
	if not _ville.objets.is_empty():
		var o_p: Dictionary = _ville.objets[0]
		_choisir_outil(OUTIL_SELECTION)
		_selection = {"genre": "objet", "k": 0}
		_pipette()
		print("[essai] pipette : « %s » -> outil %d, modèle « %s », %d quart(s) — %s" % [
			String(o_p["m"]), _outil, _modele_objet(), _quarts, _etat.text])
		if _outil != OUTIL_OBJET or _chemin_de(_modele_objet()) != _chemin_de(String(o_p["m"])):
			push_error("[essai] LA PIPETTE N'A PAS REPRIS LE BON MODÈLE")
	# Copier / coller : le lasso de tout à l'heure a été annulé, on en refait
	# un petit autour de la série d'arbres, Ctrl+C, puis Ctrl+V trois cases
	# plus loin.
	_choisir_outil(OUTIL_SELECTION)
	var k_a := _ville.objets.size() - 1
	var k_b := k_a - 1
	var pa := Vector2(float(_ville.objets[k_a]["x"]), float(_ville.objets[k_a]["z"]))
	for kk in range(k_a - 1, -1, -1):
		var ob: Dictionary = _ville.objets[kk]
		if pa.distance_to(Vector2(float(ob["x"]), float(ob["z"]))) < 3.0 * CASE:
			k_b = kk
			break
	_multi = [{"genre": "objet", "k": k_a}, {"genre": "objet", "k": k_b}]
	var objets_c := _ville.objets.size()
	_copier()
	_case = Vector2i(10, 30)
	_point = Vector3(10.5 * CASE, 0, 30.5 * CASE)
	_coller()
	print("[essai] copier/coller : %d -> %d objets, %d collé(s) — %s" % [objets_c, _ville.objets.size(), _multi.size(), _etat.text])
	if _ville.objets.size() != objets_c + 2:
		push_error("[essai] LE COLLAGE N'A PAS POSÉ LES DEUX OBJETS")
	var r_avant := float(_ville.objets[_ville.objets.size() - 1].get("r", 0.0))
	_tourner_multi(1)
	print("[essai] groupe tourné : cap %.2f -> %.2f — %s" % [r_avant,
		float(_ville.objets[_ville.objets.size() - 1].get("r", 0.0)), _etat.text])
	_annuler()
	_annuler()
	# Le contrôle de la boîte Publier : on plante un bâtiment dans l'eau exprès
	# (Chevauchement coché), et la boîte doit le dire et fermer le bouton.
	_libre.button_pressed = true
	_choisir_outil(OUTIL_LOT)
	_lot_choisi = 0
	var mer := Vector2i(-1, -1)
	for j in _ville.taille.y:
		for i in _ville.taille.x:
			if not _ville.terre(Vector2i(i, j)) and mer.x < 0: mer = Vector2i(i, j)
	if mer.x >= 0:
		_case = mer
		_point = Vector3((float(mer.x) + 0.5) * CASE, 0, (float(mer.y) + 0.5) * CASE)
		_appliquer(true)
	_libre.button_pressed = false
	_basculer_publier()
	print("[essai] contrôle : %d faute(s) listée(s), bouton %s — %s" % [_liste_fautes.get_child_count(),
		"fermé" if _bouton_publier.disabled else "OUVERT", _etat_publication.text])
	if _photo_sortie != "":
		_photographier()

# ------------------------------------------------------------------ l'interface

## L'INTERFACE EST CELLE D'UN OUTIL MODERNE, pas d'un menu de jeu — et depuis
## le 19/09 il n'y a plus qu'UN éditeur : celui-ci. Sa disposition :
##
##   ┌ barre du haut : la carte ouverte, annuler/refaire, ENREGISTRER, exporter ┐
##   │ rail │ contexte │            la vue 3D             │     catalogue      │
##   │ 6    │ l'outil  │   (la souris la traverse)        │  recherche, rayons │
##   │ icô- │ courant  │                                  │  vignettes 3D      │
##   │ nes  │ et ses   │  ┌ plan du pays ┐                │  aperçu 3D         │
##   │      │ réglages │  └──────────────┘                │                    │
##   └ barre d'état : ce qui vient de se passer · la case visée · l'aide ──────┘
##
## Trois idées la tiennent :
##  1. LE RAIL. Six icônes verticales, comme dans tout outil de dessin ; on ne
##     lit plus « 4  Objet » dans une colonne de boutons gris, on reconnaît
##     l'arbre. Le nom et le raccourci sont dans l'info-bulle.
##  2. LE CONTEXTE. Le panneau de gauche ne montre que ce qui sert à l'outil
##     courant : l'aimant et la hauteur pour une pose, le pinceau pour le
##     terrain, la fiche de ce qu'on tient pour la sélection. Un réglage qu'on
##     ne peut pas utiliser n'a rien à faire à l'écran.
##  3. LE CATALOGUE SE VOIT. Chaque modèle a sa VIGNETTE, photographiée en 3D
##     à la volée (une par image, dans un viewport à part, mise en cache) : on
##     choisit un arbre à sa silhouette, pas à son nom de fichier.
##
## Et Tab efface tout sauf la ville : « j'aimerais voir la 3D » (client, 19/09).
##
## ⚠ CHAQUE PANNEAU ARRÊTE LA SOURIS (`MOUSE_FILTER_STOP`) et le centre la
## LAISSE PASSER (`IGNORE`). C'est ce qui fait que la molette fait défiler la
## liste des modèles quand on est dessus, et zoome la carte quand on est sur
## la vue — et non les deux à la fois.

const LARGE_RAIL := 54
const LARGE_CONTEXTE := 236
const LARGE_DROITE := 318
const HAUT_BARRE := 46
const VIGNETTE := 64                    ## le côté d'une vignette du catalogue
const COLONNE := 88                     ## la largeur d'une tuile du catalogue (trois par rangée)

## Un mot pour dire à quoi sert chaque outil, sous son nom, dans le contexte.
const CONSEILS_OUTILS := [
	"Clique un lot, un objet ou une rue. Tire pour déplacer, A / E pour tourner, Suppr pour effacer, flèches pour pousser d'un pas. I ou Alt + clic reprend le modèle (pipette). Tire sur du vide : un lasso.",
	"Un clic par sommet ; Entrée ou clic droit termine. G change le genre (rue, avenue, voie rapide).",
	"Choisis un modèle dans le catalogue, tourne avec A / E, clique pour poser. Refusé sur une rue, un lot ou l'eau.",
	"Choisis un objet dans le catalogue, clique pour le poser au sol. Page haut / bas le lève. Maj + deux clics : une rangée.",
	"Clic gauche monte d'un palier, clic droit descend. + / − changent le pinceau.",
	"Clic gauche met de l'eau, clic droit remet de la terre.",
	"Choisis une matière dans le catalogue et peins le sol. + / − changent le pinceau.",
]

var _rail: PanelContainer
var _contexte: PanelContainer
var _droite: PanelContainer
var _boite_plan: PanelContainer         ## le plan du pays, posé sur la vue
var _boite_aide: Control                ## l'aide des raccourcis (H)
var _panneaux_visibles := true
var _titre_outil: Label
var _conseil_outil: Label
var _bloc_pose: VBoxContainer
var _bloc_terrain: VBoxContainer
var _bloc_selection: VBoxContainer
var _bloc_route: VBoxContainer
var _bouton_enregistrer: Button
var _fiche: GridContainer               ## les champs de la sélection (x, z, angle, hauteur)
var _champs_fiche: Dictionary = {}      ## clé → SpinBox
var _remplit_la_fiche := false          ## vrai pendant qu'on écrit dans les champs
var _etiquette_case: Label
var _etiquette_chantier: Label          ## « bâtit… 42 morceaux » tant que la tuile monte
var _pastille_modifiee: Label

## LES VIGNETTES DU CATALOGUE. Un viewport à part, avec son propre monde, rend
## UN modèle par image ; l'image est mise en cache par chemin, et posée sur
## chaque tuile qui montre ce modèle. Sept cents modèles font douze secondes à
## soixante images par seconde — et on ne les paie qu'une fois par session.
var _vignettes: Dictionary = {}         ## chemin → Texture2D (ou null si raté)
var _file_vignettes: Array[String] = [] ## ce qui reste à photographier
var _vue_vignette: SubViewport
var _vignette_noeud: MeshInstance3D
var _vignette_occupee := false
var _vignette_vide: Texture2D

## UNE ICÔNE D'OUTIL, dessinée au trait. Pas d'image à embarquer, pas de police
## d'icônes : six formes de vingt-quatre pixels, tracées dans `_draw`. La
## teinte suit l'état du bouton qui la porte.
class Icone extends Control:
	var nom := ""
	var teinte := Color.WHITE
	func _init(n: String) -> void:
		nom = n
		custom_minimum_size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func peindre(c: Color) -> void:
		teinte = c
		queue_redraw()
	func _draw() -> void:
		# Le dessin fait 24 × 24 : on le centre dans le rectangle qu'on nous
		# donne, quelle que soit la taille du bouton qui nous porte.
		draw_set_transform((size - Vector2(24, 24)) * 0.5)
		var e := 2.0
		var t := teinte
		match nom:
			"selection":
				# Une flèche de curseur.
				draw_colored_polygon(PackedVector2Array([Vector2(6, 3), Vector2(6, 19),
					Vector2(10, 15), Vector2(13, 21), Vector2(16, 20), Vector2(13, 14),
					Vector2(18, 14)]), t)
			"route":
				# Un ruban de route en biais, avec sa ligne pointillée.
				draw_polyline(PackedVector2Array([Vector2(3, 21), Vector2(11, 3)]), t, e)
				draw_polyline(PackedVector2Array([Vector2(13, 21), Vector2(21, 3)]), t, e)
				draw_polyline(PackedVector2Array([Vector2(8, 20), Vector2(9.5, 16.5)]), t, e)
				draw_polyline(PackedVector2Array([Vector2(11, 13), Vector2(12.5, 9.5)]), t, e)
				draw_polyline(PackedVector2Array([Vector2(14, 6), Vector2(15.5, 3)]), t, e)
			"lot":
				# Un immeuble et ses fenêtres.
				draw_rect(Rect2(5, 4, 14, 17), t, false, e)
				for y in [8.0, 12.0, 16.0]:
					draw_rect(Rect2(8, y, 2.5, 2.5), t, true)
					draw_rect(Rect2(13.5, y, 2.5, 2.5), t, true)
				draw_line(Vector2(3, 21), Vector2(21, 21), t, e)
			"objet":
				# Un arbre : une boule et un tronc.
				draw_circle(Vector2(12, 9.5), 6.5, t)
				draw_rect(Rect2(10.8, 14, 2.4, 7), t, true)
			"terrain":
				# Deux monts.
				draw_polyline(PackedVector2Array([Vector2(2, 20), Vector2(8, 8), Vector2(12, 14),
					Vector2(15, 6), Vector2(22, 20), Vector2(2, 20)]), t, e)
			"eau":
				# Trois vagues.
				for y in [7.0, 12.5, 18.0]:
					var pts := PackedVector2Array()
					for i in 13:
						var x := 3.0 + float(i) * 1.5
						pts.append(Vector2(x, y + sin(float(i) * 1.0) * 1.8))
					draw_polyline(pts, t, e)
			"sol":
				# Un pinceau large : la matière du sol.
				draw_rect(Rect2(4, 15, 16, 5), t, true)
				draw_rect(Rect2(10, 4, 4, 10), t, true)
				draw_line(Vector2(4, 21), Vector2(20, 21), Color(t, 0.5), 1.5)
			"sens":
				# Deux flèches qui se croisent : le sens de circulation.
				draw_polyline(PackedVector2Array([Vector2(4, 8), Vector2(18, 8)]), t, e)
				draw_polyline(PackedVector2Array([Vector2(14, 4), Vector2(18, 8), Vector2(14, 12)]), t, e)
				draw_polyline(PackedVector2Array([Vector2(20, 16), Vector2(6, 16)]), t, e)
				draw_polyline(PackedVector2Array([Vector2(10, 12), Vector2(6, 16), Vector2(10, 20)]), t, e)
			"plan":
				# Le plan : un carré et un repère.
				draw_rect(Rect2(4, 4, 16, 16), t, false, e)
				draw_rect(Rect2(9, 9, 6, 6), t, true)
			"aide":
				draw_arc(Vector2(12, 12), 9, 0, TAU, 32, t, e)
				draw_string(ThemeDB.fallback_font, Vector2(8.5, 17), "?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, t)

## Un bouton du rail : carré, muet, une icône dedans. L'état enfoncé vient du
## thème (l'accent) ; l'icône suit.
func _bouton_de_rail(icone: String, bulle: String, bascule: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = bascule
	b.tooltip_text = bulle
	var ic := Icone.new(icone)
	b.add_child(ic)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.peindre(Atelier.ENCRE_DOUCE)
	var suivre := func() -> void:
		ic.peindre(Color.WHITE if b.button_pressed else
			(Atelier.ENCRE if b.is_hovered() else Atelier.ENCRE_DOUCE))
	b.toggled.connect(func(_o: bool) -> void: suivre.call())
	b.mouse_entered.connect(suivre)
	b.mouse_exited.connect(suivre)
	return b

func _interface() -> void:
	var couche := interface()
	var racine := VBoxContainer.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_theme_constant_override("separation", 0)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le thème descend sur TOUT l'arbre : une seule ligne habille les boutons,
	# les listes, les champs, les onglets et les info-bulles.
	racine.theme = Atelier.theme()
	couche.add_child(racine)
	racine.add_child(_la_barre_du_haut())

	# ---- le milieu : rail, contexte, vue, catalogue
	var milieu := HBoxContainer.new()
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	milieu.add_theme_constant_override("separation", 0)
	milieu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(milieu)
	_rail = _le_rail()
	milieu.add_child(_rail)
	_contexte = _le_contexte()
	milieu.add_child(_contexte)

	# ---- le centre : la vue 3D, que la souris traverse — et ce qui flotte dessus
	var vue := Control.new()
	vue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	milieu.add_child(vue)
	if _est_le_pays():
		_boite_plan = _le_plan_flottant()
		vue.add_child(_boite_plan)
	_boite_aide = _l_aide()
	vue.add_child(_boite_aide)
	_boite_publier = _la_publication()
	vue.add_child(_boite_publier)

	_droite = _le_catalogue()
	milieu.add_child(_droite)
	racine.add_child(_la_barre_d_etat())

	_monter_apercu()
	_monter_vignettes()
	_remplir_palette()
	_maj_compteur()
	_choisir_outil(_outil)

## LA BARRE DU HAUT : le logo, la carte ouverte, et les actions sur le fichier.
## Enregistrer est LE bouton à l'accent — c'est le seul dont l'oubli coûte.
func _la_barre_du_haut() -> Control:
	var haut := Atelier.panneau(Atelier.PANNEAU, 8)
	haut.custom_minimum_size.y = HAUT_BARRE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	haut.add_child(hb)
	var logo := Atelier.texte("PIKS", 15, Atelier.ACCENT)
	logo.add_theme_font_override("font", Atelier.POLICE_LOGO)
	hb.add_child(logo)
	_titre = Atelier.texte("ÉDITEUR DE CARTE", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE, true)
	_titre.add_theme_constant_override("font_spacing_glyph", 2)
	hb.add_child(_titre)
	hb.add_child(VSeparator.new())
	_cartes = OptionButton.new()
	_cartes.custom_minimum_size.x = 230
	_cartes.focus_mode = Control.FOCUS_NONE
	_cartes.tooltip_text = "La carte ouverte. Un ● dit qu'une version enregistrée existe."
	_remplir_les_cartes()
	_cartes.item_selected.connect(_changer_de_carte)
	hb.add_child(_cartes)
	_pastille_modifiee = Atelier.pastille("non enregistré", Atelier.ALERTE)
	_pastille_modifiee.visible = false
	hb.add_child(_pastille_modifiee)
	hb.add_child(Atelier.ressort())
	var annuler := Atelier.fantome("Annuler", "Ctrl + Z")
	annuler.pressed.connect(_annuler)
	hb.add_child(annuler)
	var refaire := Atelier.fantome("Refaire", "Ctrl + Y")
	refaire.pressed.connect(_refaire_geste)
	hb.add_child(refaire)
	hb.add_child(VSeparator.new())
	_bouton_enregistrer = Atelier.action("Enregistrer", "Ctrl + S", true)
	_bouton_enregistrer.pressed.connect(_enregistrer)
	hb.add_child(_bouton_enregistrer)
	for paire in [["Publier", "pousse la tuile dans le dépôt — en ligne 5 minutes après", _basculer_publier],
			["Exporter", "télécharge le JSON de la carte", _exporter],
			["Rétablir", "remet la carte livrée", _retablir],
			["Photo", "P", _photographier], ["Tout voir", "Début", _tout_voir]]:
		var b := Atelier.action(String(paire[0]), String(paire[1]))
		b.pressed.connect(paire[2])
		hb.add_child(b)
	hb.add_child(Atelier.ressort())
	_compteur = Atelier.pastille("")
	hb.add_child(_compteur)
	return haut

## LE RAIL : les six outils, en icônes. En bas, les bascules d'affichage.
func _le_rail() -> PanelContainer:
	var rail := Atelier.panneau(Atelier.PANNEAU, 7)
	rail.custom_minimum_size.x = LARGE_RAIL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	rail.add_child(vb)
	var groupe := ButtonGroup.new()
	_boutons_outils.clear()
	var icones := ["selection", "route", "lot", "objet", "terrain", "eau", "sol"]
	for k in NOMS_OUTILS.size():
		var b := _bouton_de_rail(icones[k], "%s   ·   %s" % [NOMS_OUTILS[k], RACCOURCIS_OUTILS[k]], true)
		b.button_group = groupe
		b.button_pressed = k == _outil
		b.pressed.connect(func() -> void: _choisir_outil(k))
		vb.add_child(b)
		_boutons_outils.append(b)
	vb.add_child(Atelier.filet())
	# Le sens de circulation, en bascule d'icône. `_sens` reste une CheckBox
	# pour que le reste du code n'ait pas à changer — elle est juste invisible.
	_sens = CheckBox.new()
	_sens.visible = false
	vb.add_child(_sens)
	var sens := _bouton_de_rail("sens", "Sens de circulation — rouge dans un sens, bleu dans l'autre. La conduite est à droite.", true)
	sens.toggled.connect(func(o: bool) -> void:
		_sens.button_pressed = o
		_montrer_les_sens())
	vb.add_child(sens)
	if _est_le_pays():
		var plan := _bouton_de_rail("plan", "Le plan du pays   ·   M", true)
		plan.button_pressed = true
		plan.toggled.connect(func(o: bool) -> void:
			if _boite_plan != null: _boite_plan.visible = o and _panneaux_visibles)
		vb.add_child(plan)
	vb.add_child(Atelier.ressort())
	var aide := _bouton_de_rail("aide", "Les raccourcis   ·   H", false)
	aide.pressed.connect(_basculer_l_aide)
	vb.add_child(aide)
	return rail

## LE CONTEXTE : l'outil courant, son conseil, et SEULEMENT ses réglages.
func _le_contexte() -> PanelContainer:
	var p := Atelier.panneau(Atelier.PANNEAU, 12)
	p.custom_minimum_size.x = LARGE_CONTEXTE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	_titre_outil = Atelier.texte("", Atelier.CORPS_TITRE, Atelier.ENCRE, true)
	vb.add_child(_titre_outil)
	_conseil_outil = Atelier.texte("", Atelier.CORPS_PETIT + 1, Atelier.ENCRE_DOUCE)
	_conseil_outil.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_conseil_outil)

	# -- la pose : l'aimant, le chevauchement, la hauteur
	_bloc_pose = VBoxContainer.new()
	_bloc_pose.add_theme_constant_override("separation", 6)
	_bloc_pose.add_child(Atelier.entete("Pose"))
	# ⚠ DEUX RÉGLAGES DISTINCTS, ET ILS L'ÉTAIENT MAL. « Pose libre » ne levait
	# que les REFUS (rue, eau, lot occupé) ; la POSITION, elle, restait aimantée
	# au demi-mètre quoi qu'il arrive. D'où « je n'arrive pas à le bouger au
	# pixel près même en libre » (client, 12/09) : deux besoins différents
	# derrière une seule case à cocher. Désormais : une liste pour le PAS
	# D'AIMANT (jusqu'à « libre », où rien n'arrondit), et une case pour le
	# CHEVAUCHEMENT.
	_aimant = OptionButton.new()
	for f in PAS_AIMANT:
		_aimant.add_item(String(f["nom"]))
	_aimant.selected = PAS_DEFAUT
	_aimant.focus_mode = Control.FOCUS_NONE
	_aimant.tooltip_text = "Le pas auquel les poses et les déplacements s'arrondissent."
	_bloc_pose.add_child(Atelier.ligne("Aimant", _aimant))
	_bloc_pose.add_child(Atelier.ligne("Hauteur", _regle_decalage(), "cases"))
	_libre = CheckBox.new()
	_libre.text = "Chevauchement"
	_libre.tooltip_text = "Autorise la pose sur une rue, l'eau ou un lot déjà posé,\net laisse deux pièces se recouvrir."
	_libre.focus_mode = Control.FOCUS_NONE
	_bloc_pose.add_child(_libre)
	vb.add_child(_bloc_pose)

	# -- la route : son genre
	_bloc_route = VBoxContainer.new()
	_bloc_route.add_theme_constant_override("separation", 6)
	_bloc_route.add_child(Atelier.entete("Genre"))
	var genres := Atelier.texte("Rue, avenue ou voie rapide : choisis dans le catalogue, ou G pour passer au suivant.",
		Atelier.CORPS_PETIT + 1, Atelier.ENCRE_DOUCE)
	genres.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bloc_route.add_child(genres)
	vb.add_child(_bloc_route)

	# -- le terrain : le pinceau
	_bloc_terrain = VBoxContainer.new()
	_bloc_terrain.add_theme_constant_override("separation", 6)
	_bloc_terrain.add_child(Atelier.entete("Pinceau"))
	_bloc_terrain.add_child(Atelier.ligne("Rayon", _regle_rayon(), "cases"))
	vb.add_child(_bloc_terrain)

	# -- la sélection : la fiche de ce qu'on tient, et ce qu'on peut en faire
	_bloc_selection = VBoxContainer.new()
	_bloc_selection.add_theme_constant_override("separation", 6)
	_bloc_selection.add_child(Atelier.entete("Sélection"))
	_info = RichTextLabel.new()
	_info.fit_content = true
	_info.bbcode_enabled = true
	_info.custom_minimum_size.y = 40
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloc_selection.add_child(_info)
	# LA FICHE : les nombres de ce qu'on tient, ÉDITABLES. Tirer à la souris
	# et pousser aux flèches, c'est bien ; taper « 412,5 » quand on sait où
	# la chose doit être, c'est ce que fait un inspecteur.
	_fiche = GridContainer.new()
	_fiche.columns = 2
	_fiche.add_theme_constant_override("h_separation", 8)
	_fiche.add_theme_constant_override("v_separation", 4)
	for f in [["x", "X", -100000.0, 100000.0, 0.1], ["z", "Z", -100000.0, 100000.0, 0.1],
			["r", "Angle", -360.0, 360.0, 1.0], ["y", "Hauteur", -5.0, 20.0, 0.1],
			["q", "Quarts", 0.0, 3.0, 1.0]]:
		var l := Atelier.texte(String(f[1]), Atelier.CORPS, Atelier.ENCRE_DOUCE)
		l.custom_minimum_size.x = 64
		_fiche.add_child(l)
		var c := SpinBox.new()
		c.min_value = float(f[2])
		c.max_value = float(f[3])
		c.step = float(f[4])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.value_changed.connect(_fiche_changee.bind(String(f[0])))
		_fiche.add_child(c)
		_champs_fiche[String(f[0])] = c
	_bloc_selection.add_child(_fiche)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	for trio in [["⟲", "Tourner à gauche · A", -1], ["⟳", "Tourner à droite · E", 1]]:
		var b := Atelier.action(String(trio[0]), String(trio[1]))
		var sens_rot: int = int(trio[2])
		b.pressed.connect(func() -> void:
			_quarts = posmod(_quarts + sens_rot, 4)
			_tourner_selection(sens_rot))
		actions.add_child(b)
	var suppr := Atelier.action("Supprimer", "Suppr")
	suppr.add_theme_color_override("font_color", Atelier.ERREUR)
	suppr.pressed.connect(_supprimer_selection)
	suppr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(suppr)
	_bloc_selection.add_child(actions)
	vb.add_child(_bloc_selection)

	vb.add_child(Atelier.ressort())
	var version := Atelier.texte(Version.etiquette(), Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE)
	version.tooltip_text = "La version du paquet : le commit et la date de l'export."
	vb.add_child(version)
	return p

## LE PLAN DU PAYS, posé sur la vue en bas à gauche. ⚠ « JE PENSAIS VOIR TOUTE
## LA MAP ET NON UNE PETITE ZONE » (client, 16/09). Une fenêtre du pays fait au
## mieux 400 cases de côté sur une carte qui en fait MILLE : bâtir le pays
## entier tiendrait des minutes et des gigaoctets. La réponse n'est pas de tout
## bâtir, c'est de ne jamais perdre la vue d'ensemble : le plan cuit des
## Aurones s'affiche ici en entier, le cadre jaune dit où l'on travaille, et un
## clic déplace la fenêtre n'importe où sur les vingt kilomètres.
func _le_plan_flottant() -> PanelContainer:
	var p := Atelier.panneau(Color(Atelier.PANNEAU, 0.92), 8, Atelier.RAYON + 2)
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.position = Vector2(12, -12)
	p.offset_left = 12
	p.offset_bottom = -12
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var titre := HBoxContainer.new()
	titre.add_child(Atelier.texte("LE PAYS", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE, true))
	titre.add_child(Atelier.ressort())
	titre.add_child(Atelier.texte("tuile %d,%d · %d cases" % [_cle_pays.x, _cle_pays.y, _cote_pays],
		Atelier.CORPS_PETIT, Atelier.ENCRE_DOUCE))
	vb.add_child(titre)
	vb.add_child(_la_minicarte())
	# LES VOISINES : quatre boutons, une tuile par bord. On travaille une tuile
	# à la fois, et la suivante est presque toujours celle d'à côté.
	var voisines := HBoxContainer.new()
	voisines.add_theme_constant_override("separation", 4)
	voisines.alignment = BoxContainer.ALIGNMENT_CENTER
	for f in [["◀", Vector2i(-1, 0)], ["▲", Vector2i(0, -1)], ["▼", Vector2i(0, 1)], ["▶", Vector2i(1, 0)]]:
		var d: Vector2i = f[1]
		var cle := _cle_pays + d
		var b := Atelier.fantome(String(f[0]), "tuile %d,%d" % [cle.x, cle.y])
		b.custom_minimum_size.x = 36
		var dedans := cle.x >= 0 and cle.y >= 0 \
			and cle.x * COTE_PAYS < PLAN_PAYS.TAILLE.x and cle.y * COTE_PAYS < PLAN_PAYS.TAILLE.y
		b.disabled = not dedans
		b.pressed.connect(func() -> void:
			_aller_au_pays(cle * COTE_PAYS + Vector2i(COTE_PAYS, COTE_PAYS) / 2))
		voisines.add_child(b)
	vb.add_child(voisines)
	return p

const PLAN_IMAGE := "res://cartes/aurones-plan.png"
const PAYS_COTE := 1000.0               ## le côté de la carte, en cases
const PLAN_MINI := 176                  ## le côté du plan à l'écran

## LE PLAN DU PAYS, en entier, dans cent soixante-seize pixels. Il se dessine à
## la main plutôt que par un TextureRect parce qu'il porte deux choses de plus
## que l'image : le cadre de la fenêtre ouverte, et la croix du curseur. Un
## clic gauche recentre la fenêtre là où l'on a cliqué.
func _la_minicarte() -> Control:
	var t: Texture2D = null
	if ResourceLoader.exists(PLAN_IMAGE):
		t = load(PLAN_IMAGE) as Texture2D
	var c := Control.new()
	c.custom_minimum_size = Vector2(PLAN_MINI, PLAN_MINI)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_CROSS
	c.tooltip_text = "Le plan des Aurones, et la grille des tuiles du jeu (200 cases).\nClique une tuile pour l'ouvrir."
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		if t != null:
			c.draw_texture_rect(t, r, false)
		else:
			c.draw_rect(r, Color("#1b2430"), true)
			c.draw_string(Atelier.POLICE, Vector2(8, 24), "plan absent",
				HORIZONTAL_ALIGNMENT_LEFT, -1, Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE)
		# La grille des tuiles du jeu, en filigrane : c'est par elles qu'on
		# travaille, autant les voir.
		var u := c.size.x / PAYS_COTE
		var pas := float(COTE_PAYS) * u
		var x := pas
		while x < c.size.x - 0.5:
			c.draw_line(Vector2(x, 0), Vector2(x, c.size.y), Color(1, 1, 1, 0.18), 1.0)
			c.draw_line(Vector2(0, x), Vector2(c.size.x, x), Color(1, 1, 1, 0.18), 1.0)
			x += pas
		# Le cadre de ce qu'on regarde, à l'échelle du plan.
		var cote := maxf(float(_cote_pays) * u, 3.0)
		var coin := Vector2(float(_centre_pays.x), float(_centre_pays.y)) * u \
			- Vector2(cote, cote) * 0.5
		c.draw_rect(Rect2(coin, Vector2(cote, cote)), Color(Atelier.ACCENT, 0.2), true)
		c.draw_rect(Rect2(coin, Vector2(cote, cote)), Atelier.ACCENT, false, 2.0))
	c.gui_input.connect(func(ev: InputEvent) -> void:
		var clic := ev as InputEventMouseButton
		if clic == null or not clic.pressed: return
		if clic.button_index != MOUSE_BUTTON_LEFT: return
		var u := c.size.x / PAYS_COTE
		if u <= 0.0: return
		var vise := Vector2i(roundi(clic.position.x / u), roundi(clic.position.y / u))
		_aller_au_pays(vise))
	_minicarte = c
	return c

## Recharger l'éditeur sur une autre fenêtre du pays. On repasse par l'écran
## plutôt que de rebâtir en place : la fenêtre est une VILLE entière, avec son
## terrain, ses lots et son historique d'annulation — la remplacer sous les
## pieds de l'éditeur laisserait derrière elle une sélection et des annulations
## qui désignent une ville qui n'existe plus.
func _aller_au_pays(vise: Vector2i) -> void:
	var c := Vector2i(clampi(vise.x, 0, 1000), clampi(vise.y, 0, 1000))
	var cle := FENETRES.cle_de_case(c)
	if cle == _cle_pays:
		_dire("C'est déjà la tuile %d,%d." % [cle.x, cle.y])
		return
	# ⚠ ON NE JETTE PAS DU TRAVAIL EN SILENCE — la même règle que pour la
	# liste des cartes : changer de tuile recharge tout. Le premier clic
	# prévient, le second confirme.
	var nom := "pays-%d-%d" % [cle.x, cle.y]
	if _des_choses_non_enregistrees() and _a_prevenir != nom:
		_a_prevenir = nom
		_dire("⚠ La tuile %d,%d a des modifications NON ENREGISTRÉES. Ctrl+S pour les garder, ou reclique la tuile %d,%d pour les abandonner." % [
			_cle_pays.x, _cle_pays.y, cle.x, cle.y])
		return
	_a_prevenir = ""
	_dire("Le pays : on ouvre la tuile %d,%d…" % [cle.x, cle.y])
	demande_ecran.emit("editeur", {"pays": "1",
		"ou": "%d,%d" % [c.x, c.y], "large": str(_cote_pays)})

## LE CATALOGUE : la recherche, les rayons, les vignettes, l'aperçu 3D.
func _le_catalogue() -> PanelContainer:
	var droite := Atelier.panneau(Atelier.PANNEAU, 12)
	droite.custom_minimum_size.x = LARGE_DROITE
	var db := VBoxContainer.new()
	db.add_theme_constant_override("separation", 6)
	droite.add_child(db)
	var entete := HBoxContainer.new()
	entete.add_child(Atelier.texte("Catalogue", Atelier.CORPS_TITRE, Atelier.ENCRE, true))
	entete.add_child(Atelier.ressort())
	db.add_child(entete)
	_recherche = LineEdit.new()
	_recherche.placeholder_text = "Chercher un modèle…"
	_recherche.clear_button_enabled = true
	_recherche.custom_minimum_size.y = 30
	_recherche.text_changed.connect(func(_t: String) -> void: _remplir_palette())
	db.add_child(_recherche)
	_familles = OptionButton.new()
	_familles.add_item(FAMILLE_RECENTS)
	_familles.add_item(FAMILLE_RACCOURCIS)
	_familles.add_item(FAMILLE_TOUT)
	_lire_les_recents()
	# ⚠ UNE ÉTAGÈRE PAR CATÉGORIE, ET SES RAYONS EN DESSOUS (demande du client,
	# 12/09 : « range-moi les objets par catégories, tout nature dans un dossier
	# nature »). « nature » montre les 330 modèles du dossier ; « nature · tree »
	# n'en montre que les arbres. Les deux sont dans la liste, la catégorie
	# d'abord.
	#
	# ⚠ LA CLÉ EST DANS LES MÉTADONNÉES, PAS DANS LE LIBELLÉ. Le libellé porte
	# une puce et un compte (« ↳ tree · 61 ») pour que la hiérarchie SE VOIE
	# dans la liste déroulante ; le filtre, lui, a besoin du nom exact.
	var vues: Dictionary = {}
	var combien: Dictionary = {}
	for m in KitVille2.catalogue():
		var cat := KitVille2.categorie(m)
		if not vues.has(cat): vues[cat] = {}
		combien[cat] = int(combien.get(cat, 0)) + 1
		var fam := KitVille2.famille(m)
		if fam != cat:
			(vues[cat] as Dictionary)[fam] = true
			combien[fam] = int(combien.get(fam, 0)) + 1
	_familles.set_item_metadata(0, {"cle": FAMILLE_RECENTS})
	_familles.set_item_metadata(1, {"cle": FAMILLE_RACCOURCIS})
	_familles.set_item_metadata(2, {"cle": FAMILLE_TOUT})
	# On ouvre sur les raccourcis, comme avant — les récents sont vides à la
	# première séance.
	_familles.selected = 0 if not _recents.is_empty() else 1
	var cats: Array = vues.keys()
	cats.sort()
	for cat in cats:
		_familles.add_item("%s  ·  %d" % [cat, int(combien.get(cat, 0))])
		_familles.set_item_metadata(_familles.item_count - 1, {"cle": cat})
		var rayons: Array = (vues[cat] as Dictionary).keys()
		rayons.sort()
		for r in rayons:
			var court := String(r).get_slice(KitVille2.SEPARATEUR_RAYON, 1).strip_edges()
			_familles.add_item("      ↳ %s  ·  %d" % [court, int(combien.get(r, 0))])
			_familles.set_item_metadata(_familles.item_count - 1, {"cle": r})
	# ⚠ AUCUN FOCUS SUR LES LISTES. Une liste qui a le clavier avale les
	# flèches : on croyait déplacer la caméra, on faisait défiler le catalogue.
	_familles.focus_mode = Control.FOCUS_NONE
	_familles.item_selected.connect(func(_k: int) -> void: _remplir_palette())
	db.add_child(_familles)
	_palette = ItemList.new()
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.custom_minimum_size.y = 200
	_palette.focus_mode = Control.FOCUS_NONE
	_palette.item_selected.connect(_palette_choisie)
	db.add_child(_palette)
	db.add_child(Atelier.entete("Aperçu"))
	var cadre := SubViewportContainer.new()
	cadre.custom_minimum_size = Vector2(LARGE_DROITE - 24, 150)
	cadre.stretch = true
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	_apercu3d = SubViewport.new()
	_apercu3d.own_world_3d = true
	_apercu3d.transparent_bg = false
	_apercu3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cadre.add_child(_apercu3d)
	db.add_child(cadre)
	_apercu_nom = Atelier.texte("", Atelier.CORPS_PETIT + 1, Atelier.ENCRE_DOUCE)
	_apercu_nom.autowrap_mode = TextServer.AUTOWRAP_WORD
	_apercu_nom.custom_minimum_size.y = 34
	db.add_child(_apercu_nom)
	return droite

## LA BARRE D'ÉTAT : ce qui vient de se passer, la case sous le curseur, et
## comment ouvrir l'aide. Une seule ligne, jamais plus.
func _la_barre_d_etat() -> Control:
	var bas := Atelier.panneau(Atelier.PANNEAU, 6)
	bas.custom_minimum_size.y = 30
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 14)
	bas.add_child(bb)
	_etat = Atelier.texte("", Atelier.CORPS - 1, Atelier.ENCRE_DOUCE)
	_etat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etat.clip_text = true
	_etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bb.add_child(_etat)
	_etiquette_chantier = Atelier.pastille("", Atelier.CYAN)
	_etiquette_chantier.visible = false
	bb.add_child(_etiquette_chantier)
	_etiquette_case = Atelier.texte("", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE)
	_etiquette_case.custom_minimum_size.x = 120
	_etiquette_case.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bb.add_child(_etiquette_case)
	_aide = Atelier.texte("H  aide   ·   Tab  la ville seule", Atelier.CORPS_PETIT, Atelier.ENCRE_FAIBLE)
	bb.add_child(_aide)
	return bas

## L'AIDE : les raccourcis, en cabochons, au milieu de la vue. H l'ouvre et la
## ferme ; Échap la ferme. Elle ne vit nulle part ailleurs — collés sous la
## ligne d'état, les raccourcis criaient aussi fort que la case sous le curseur
## et personne ne les lisait.
func _l_aide() -> Control:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.visible = false
	var p := Atelier.panneau(Color(Atelier.PANNEAU, 0.97), 18, Atelier.RAYON + 4)
	centre.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var titre := HBoxContainer.new()
	titre.add_child(Atelier.texte("Raccourcis", Atelier.CORPS_TITRE, Atelier.ENCRE, true))
	titre.add_child(Atelier.ressort())
	var fermer := Atelier.fantome("Fermer", "H ou Échap")
	fermer.pressed.connect(_basculer_l_aide)
	titre.add_child(fermer)
	vb.add_child(titre)
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 22)
	grille.add_theme_constant_override("v_separation", 6)
	vb.add_child(grille)
	var lignes := [
		[["1", "…", "7"], "choisir l'outil"], [["Z", "Q", "S", "D"], "déplacer la caméra"],
		[["clic droit"], "tourner la caméra"], [["molette"], "zoomer"],
		[["clic milieu"], "faire glisser la vue"], [["Début"], "tout voir"],
		[["A", "E"], "tourner la pièce (ou tout le lasso)"], [["Pg↑", "Pg↓"], "hauteur de pose"],
		[["G"], "genre de route"], [["Entrée"], "finir la route"],
		[["+", "−"], "rayon du pinceau"], [["Suppr"], "effacer la sélection"],
		[["flèches"], "pousser la sélection d'un pas"], [["Échap"], "lâcher"],
		[["Ctrl", "Z"], "annuler"], [["Ctrl", "Y"], "refaire"],
		[["Ctrl", "S"], "enregistrer"], [["P"], "photographier"],
		[["Tab"], "la ville seule"], [["M"], "le plan du pays"],
		[["V"], "vue de dessus / oblique"], [["H"], "cette aide"],
		[["Ctrl", "D"], "dupliquer la sélection"], [["Ctrl", "C"], "copier la sélection (lasso compris)"], [["Ctrl", "V"], "coller sous le curseur"], [["F"], "cadrer la sélection"],
		[["I"], "pipette : reprendre le modèle visé"], [["Alt", "clic"], "la même pipette, à la souris"],
		[["tirer"], "lasso : sélectionner tout un rectangle"], [["Suppr"], "… et l'effacer d'un coup"],
		[["Maj", "clic"], "pose en série (outil Objet)"], [["Maj", "clic"], "glisser la vue (autres outils)"],
	]
	for l in lignes:
		var touches := HBoxContainer.new()
		touches.add_theme_constant_override("separation", 3)
		for t in (l[0] as Array):
			touches.add_child(Atelier.touche(String(t)))
		grille.add_child(touches)
		grille.add_child(Atelier.texte(String(l[1]), Atelier.CORPS - 1, Atelier.ENCRE_DOUCE))
	return centre

func _basculer_l_aide() -> void:
	if _boite_aide != null:
		_boite_aide.visible = not _boite_aide.visible

## TAB : LA VILLE SEULE. Tout ce qui n'est pas la vue 3D disparaît — c'est la
## façon la plus courte de juger un quartier qu'on vient de poser.
func _basculer_les_panneaux() -> void:
	_panneaux_visibles = not _panneaux_visibles
	for p in [_rail, _contexte, _droite]:
		if p != null: (p as Control).visible = _panneaux_visibles
	if _boite_plan != null: _boite_plan.visible = _panneaux_visibles
	_dire("La ville seule — Tab pour retrouver les panneaux." if not _panneaux_visibles else "")

func _regle_rayon() -> SpinBox:
	_champ_rayon = SpinBox.new()
	_champ_rayon.min_value = 1
	_champ_rayon.max_value = 8
	_champ_rayon.value = _rayon_terrain
	_champ_rayon.value_changed.connect(func(v: float) -> void:
		_rayon_terrain = int(v)
		_montrer_apercu())
	return _champ_rayon

## ⚠⚠ CE CHAMP ÉTAIT EN UNITÉS, ET C'EST POUR ÇA QU'IL NE FAISAIT RIEN.
## Le client écrit « impossible de mettre un objet flottant à 1 de hauteur ou 2 »
## (16/09) : il pensait en ÉTAGES, le champ comptait en unités Kenney. Une case
## fait VINGT unités — taper 1 levait l'objet d'un vingtième de case, soit un
## déplacement qu'aucun œil ne voit à la caméra de l'éditeur. Le champ compte
## désormais en CASES, comme tout le reste de l'éditeur, et la conversion se
## fait à un seul endroit : `_decalage`, lui, reste en unités pour le rendu.
func _regle_decalage() -> SpinBox:
	_champ_decalage = SpinBox.new()
	_champ_decalage.min_value = -2.0
	_champ_decalage.max_value = 10.0
	# ⚠ UN DIXIÈME DE CASE, PAS UN QUART. « Je ne peux pas monter la hauteur de
	# 0,1 par 0,1 » (client, 16/09) : à 0,25 le champ refusait sa saisie et la
	# ramenait au quart le plus proche.
	_champ_decalage.step = 0.1
	_champ_decalage.value = _decalage / CASE
	_champ_decalage.tooltip_text = "La hauteur à laquelle l'objet est posé, en cases au-dessus du sol.\nPage Haut / Page Bas montent et descendent d'un dixième de case.\nUne hauteur non nulle autorise la pose au-dessus d'une rue ou d'un toit."
	_champ_decalage.value_changed.connect(func(v: float) -> void: _decalage = v * CASE)
	return _champ_decalage

## Le compte de la barre du haut : ce que porte la ville en ce moment.
func _maj_compteur() -> void:
	if _compteur == null or _ville == null: return
	_compteur.text = "%d lots  ·  %d objets  ·  %d routes  ·  %d × %d" % [
		_ville.lots.size(), _ville.objets.size(), _ville.routes.size(),
		_ville.taille.x, _ville.taille.y]
	if _pastille_modifiee != null:
		_pastille_modifiee.visible = _des_choses_non_enregistrees()

## Ce que dit le contexte sur ce qui est sélectionné.
func _maj_info() -> void:
	if _info == null: return
	if _bloc_selection != null:
		_bloc_selection.visible = not _selection.is_empty() or _outil == OUTIL_SELECTION
	if _fiche != null: _fiche.visible = false
	if _selection.is_empty():
		_info.text = "[color=#5f6776]Rien — clique un lot, un objet ou une rue.[/color]"
		return
	var k := int(_selection["k"])
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[k]
			_info.text = "[color=#9ea5b4]objet[/color]\n[b][color=#e9ebf1]%s[/color][/b]" % [
				_nom_lisible(String(o["m"]))]
			var sol := TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"]))
			var y := (float(o["y_abs"]) - sol) / CASE if o.has("y_abs") else 0.0
			_montrer_la_fiche({"x": float(o["x"]), "z": float(o["z"]),
				"r": rad_to_deg(float(o.get("r", 0.0))), "y": y}, ["x", "z", "r", "y"])
		"lot":
			var l: Dictionary = _ville.lots[k]
			_info.text = "[color=#9ea5b4]bâtiment[/color]\n[b][color=#e9ebf1]%s[/color][/b]\n%d × %d demi-cases" % [
				_nom_lisible(String(l["m"])), int(l["w"]), int(l["h"])]
			_montrer_la_fiche({"x": float(l["x"]), "z": float(l["y"]), "q": float(l["q"])}, ["x", "z", "q"])
		"route":
			var r: Dictionary = _ville.routes[k]
			_info.text = "[color=#9ea5b4]route[/color]\n[b][color=#e9ebf1]%s[/color][/b]\n%s, %d points" % [
				String(r["nom"]), String(r["genre"]), (r["points"] as Array).size()]

## Écrit les valeurs dans les champs sans que ça compte comme une saisie.
func _montrer_la_fiche(valeurs: Dictionary, visibles: Array) -> void:
	if _fiche == null: return
	_remplit_la_fiche = true
	for cle in _champs_fiche.keys():
		var c: SpinBox = _champs_fiche[cle]
		var montre: bool = visibles.has(cle)
		c.visible = montre
		(_fiche.get_child(c.get_index() - 1) as Control).visible = montre
		if montre: c.value = float(valeurs[cle])
	# Un bâtiment vit sur la trame des demi-cases : ses X et Z sont entiers.
	var lot: bool = visibles.has("q")
	for cle2 in ["x", "z"]:
		(_champs_fiche[cle2] as SpinBox).step = 1.0 if lot else 0.1
	_fiche.visible = true
	_remplit_la_fiche = false

## Une valeur tapée dans la fiche : on l'applique à ce qu'on tient.
func _fiche_changee(valeur: float, cle: String) -> void:
	if _remplit_la_fiche or _selection.is_empty(): return
	_empiler()
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			var avant := Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE))
			match cle:
				"x": o["x"] = valeur
				"z": o["z"] = valeur
				"r": o["r"] = deg_to_rad(valeur)
				"y":
					if absf(valeur) < 0.01: o.erase("y_abs")
					else: o["y_abs"] = TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"])) + valeur * CASE
			_rebatir([avant, Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE))])
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			var cases_avant := Ville2.cases_du_lot(l)
			match cle:
				"x": l["x"] = int(valeur)
				"z": l["y"] = int(valeur)
				"q":
					var q := posmod(int(valeur), 4)
					var e := KitVille2.emprise_tournee(String(l["m"]), q)
					l["q"] = q
					l["w"] = e.x
					l["h"] = e.y
			_rebatir(cases_avant + Ville2.cases_du_lot(l))
		_:
			return
	_montrer_cadre()

# ------------------------------------------------------------------ publier

## ⭐ PUBLIER — la tuile part dans le dépôt, en un bouton.
##
## ⚠ POURQUOI. Ctrl+S écrit dans le stockage du navigateur : ça survit à un
## rechargement, pas à un vidage du cache, et ça n'atteint jamais le dépôt.
## Exporter télécharge un fichier qu'il faut ensuite déposer, commiter,
## pousser — et le dernier geste s'oublie une fois sur deux. Ici la tuile part
## à `api/publier-carte` (fonction Vercel, même origine que la page), qui la
## commite sur `main` par l'API GitHub ; le push déclenche l'export web, et
## cinq minutes plus tard le jeu en ligne joue la tuile retouchée — parce que
## `FenetresPays` relit `cartes/pays-<kx>-<ky>.json` avant d'engendrer.
##
## La clé est celle que le client a choisie sur Vercel (`CLE_PUBLICATION`) ;
## tapée une fois, elle reste dans le profil du navigateur (`user://`). Elle ne
## passe jamais par ici autrement que par ses doigts.
##
## ⚠ LE JSON PART GZIPPÉ EN BASE64. Une tuile de 200 cases fait trois
## mégaoctets ; le corps d'une requête Vercel plafonne à 4,5 Mo. Gzippé, dix
## fois moins.
const ADRESSE_PUBLICATION := "https://multijoueur.piks-l.com/api/publier-carte"
const FICHIER_CLE := "user://cle_publication.txt"

var _boite_publier: Control
var _champ_cle: LineEdit
var _champ_note: LineEdit
var _bouton_publier: Button
var _etat_publication: Label
var _liste_fautes: VBoxContainer
var _publication_en_cours := false

func _lire_cle() -> String:
	var f := FileAccess.open(FICHIER_CLE, FileAccess.READ)
	if f == null: return ""
	var t := f.get_as_text().strip_edges()
	f.close()
	return t

func _garder_cle(texte: String) -> void:
	var f := FileAccess.open(FICHIER_CLE, FileAccess.WRITE)
	if f != null:
		f.store_string(texte.strip_edges())
		f.close()

func _adresse_publication() -> String:
	# Dans le navigateur, la fonction vit sur la même origine que la page :
	# c'est ce qui la fait marcher aussi sur un aperçu Vercel.
	if OS.has_feature("web"):
		var origine = JavaScriptBridge.eval("window.location.origin", true)
		if typeof(origine) == TYPE_STRING and String(origine).begins_with("http"):
			return String(origine) + "/api/publier-carte"
	return ADRESSE_PUBLICATION

func _la_publication() -> Control:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.visible = false
	var p := Atelier.panneau(Color(Atelier.PANNEAU, 0.97), 18, Atelier.RAYON + 4)
	p.custom_minimum_size.x = 420
	centre.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	var titre := HBoxContainer.new()
	titre.add_child(Atelier.texte("Publier la tuile", Atelier.CORPS_TITRE, Atelier.ENCRE, true))
	titre.add_child(Atelier.ressort())
	var fermer := Atelier.fantome("Fermer", "Échap")
	fermer.pressed.connect(_basculer_publier)
	titre.add_child(fermer)
	vb.add_child(titre)
	var expl := Atelier.texte("La tuile ouverte part dans le dépôt (cartes/) et l'export web suit : le jeu en ligne la joue cinq minutes après. Enregistre d'abord si tu veux la garder ici aussi.",
		Atelier.CORPS - 1, Atelier.ENCRE_DOUCE)
	expl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(expl)
	_champ_cle = LineEdit.new()
	_champ_cle.placeholder_text = "clé de publication (une fois — celle de Vercel)"
	_champ_cle.secret = true
	_champ_cle.text = _lire_cle()
	_champ_cle.text_changed.connect(_garder_cle)
	vb.add_child(Atelier.ligne("Clé", _champ_cle))
	_champ_note = LineEdit.new()
	_champ_note.placeholder_text = "note du commit (facultatif)"
	vb.add_child(Atelier.ligne("Note", _champ_note))
	# LE CONTRÔLE, AVANT LE BOUTON. Les fautes de la tuile (le même contrôle
	# que le workflow d'export : `controle_tuile.gd`) s'affichent ici, une par
	# ligne, cliquables — et tant qu'il y en a, on ne publie pas. Publier une
	# tuile que l'export refusera, c'est un commit pour rien.
	_liste_fautes = VBoxContainer.new()
	_liste_fautes.add_theme_constant_override("separation", 2)
	vb.add_child(_liste_fautes)
	_etat_publication = Atelier.texte("", Atelier.CORPS_PETIT + 1, Atelier.ENCRE_FAIBLE)
	_etat_publication.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_etat_publication)
	var rang := HBoxContainer.new()
	rang.add_child(Atelier.ressort())
	_bouton_publier = Atelier.action("Publier en ligne", "", true)
	_bouton_publier.pressed.connect(_publier)
	rang.add_child(_bouton_publier)
	vb.add_child(rang)
	return centre

func _basculer_publier() -> void:
	if _boite_publier == null: return
	_boite_publier.visible = not _boite_publier.visible
	if _boite_publier.visible:
		_controler_la_tuile()
		# Un clic dans la vue rend le clavier à la vue ; ici on le DONNE au
		# champ, sinon la première frappe déplace la caméra.
		if _champ_cle.text == "": _champ_cle.grab_focus()
		else: _champ_note.grab_focus()

## Passe la tuile au contrôle et montre le résultat dans la boîte Publier :
## une ligne verte, ou les fautes une par une — chacune est un bouton qui
## emmène la caméra sur la case coupable.
func _controler_la_tuile() -> bool:
	for n in _liste_fautes.get_children():
		n.queue_free()
	var fautes: Array[String] = CONTROLE.fautes(_ville, 12)
	if fautes.is_empty():
		_etat_publier("✓ Tuile %s propre — rien ne s'oppose à la publication." % _chemin.get_file(), Atelier.OK)
		_bouton_publier.disabled = false
		return true
	for f in fautes:
		var b := Atelier.fantome(f, "aller voir")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_color_override("font_color", Atelier.ERREUR)
		# La case est entre parenthèses en tête de ligne : « (69,98) … ».
		if f.begins_with("("):
			var xy := f.substr(1, f.find(")") - 1).split(",")
			if xy.size() == 2:
				var c := Vector2i(int(xy[0]), int(xy[1]))
				b.pressed.connect(func() -> void:
					_pivot = Vector3((float(c.x) + 0.5) * CASE, 0, (float(c.y) + 0.5) * CASE)
					_distance = 160.0
					_placer_camera())
		_liste_fautes.add_child(b)
	_etat_publier("%d faute(s) — l'export les refuserait. Corrige, puis rouvre cette boîte." % fautes.size(), Atelier.ERREUR)
	_bouton_publier.disabled = true
	return false

func _etat_publier(texte: String, couleur: Color) -> void:
	if _etat_publication == null: return
	_etat_publication.text = texte
	_etat_publication.add_theme_color_override("font_color", couleur)
	_dire(texte)

func _publier() -> void:
	if _publication_en_cours: return
	var nom := _chemin.get_file().get_basename()
	if not (nom.begins_with("pays-") or nom.begins_with("temoin-")):
		_etat_publier("Seules les tuiles du pays (pays-x-y) et les témoins se publient.", Atelier.ERREUR)
		return
	var cle := _champ_cle.text.strip_edges()
	if cle == "":
		_etat_publier("Il faut la clé de publication (celle de Vercel, CLE_PUBLICATION).", Atelier.ERREUR)
		return
	if not _controler_la_tuile(): return
	var texte := _ville.vers_json()
	var gz := texte.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	_publication_en_cours = true
	_bouton_publier.disabled = true
	_etat_publier("Publication… (%d Ko, %d Ko gzippés)" % [texte.length() / 1024, gz.size() / 1024],
		Atelier.ENCRE_FAIBLE)
	var requete := HTTPRequest.new()
	requete.timeout = 90.0
	add_child(requete)
	requete.request_completed.connect(func(resultat: int, code: int, _entetes: PackedStringArray, corps: PackedByteArray) -> void:
		requete.queue_free()
		_publication_en_cours = false
		_bouton_publier.disabled = false
		if resultat != HTTPRequest.RESULT_SUCCESS:
			_etat_publier("Pas de réponse du serveur (%d) — réseau ?" % resultat, Atelier.ERREUR)
			return
		var reponse = JSON.parse_string(corps.get_string_from_utf8())
		if typeof(reponse) != TYPE_DICTIONARY:
			_etat_publier("Réponse illisible (HTTP %d)." % code, Atelier.ERREUR)
			return
		if code == 200 and bool(reponse.get("ok", false)):
			_etat_publier("Poussée : %s (commit %s). L'export web tourne — en ligne dans 3 à 5 minutes." % [
				String(reponse.get("fichier", nom)), String(reponse.get("commit", "?"))], Atelier.OK)
			_champ_note.text = ""
		else:
			_etat_publier("Refusé : %s" % String(reponse.get("erreur", "HTTP %d" % code)), Atelier.ERREUR)
	)
	var charge := JSON.stringify({"cle": cle, "nom": nom,
		"contenu_gz": Marshalls.raw_to_base64(gz),
		"note": _champ_note.text.strip_edges()})
	var erreur := requete.request(_adresse_publication(), PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, charge)
	if erreur != OK:
		requete.queue_free()
		_publication_en_cours = false
		_bouton_publier.disabled = false
		_etat_publier("Requête impossible (%d)." % erreur, Atelier.ERREUR)

# ------------------------------------------------------------------ les récents

func _lire_les_recents() -> void:
	_recents.clear()
	if not FileAccess.file_exists(FICHIER_RECENTS): return
	var brut = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_RECENTS))
	if typeof(brut) != TYPE_ARRAY: return
	for m in brut:
		if typeof(m) == TYPE_STRING and (_chemin_de(String(m)) != "" or String(m) == "pelouse"):
			_recents.append(String(m))

## Un modèle vient d'être posé : il passe en tête des récents, sans doublon.
func _noter_recent(m: String) -> void:
	if m == "": return
	_recents.erase(m)
	_recents.push_front(m)
	while _recents.size() > RECENTS_MAXI: _recents.pop_back()
	var f := FileAccess.open(FICHIER_RECENTS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_recents))
		f.close()
	# Si le catalogue montre les récents, il se met à jour — en gardant le
	# modèle courant choisi.
	if _familles != null and _familles.selected == 0:
		var courant := _modele_lot() if _outil == OUTIL_LOT else _modele_objet()
		_remplir_palette()
		var k := _liste.find(courant)
		if k >= 0:
			_palette.select(k)
			_palette_choisie(k)

# ------------------------------------------------------------------ le lasso

func _rect_du_lasso() -> Rect2:
	var a := Vector2(minf(_lasso_depart.x, _lasso_fin.x), minf(_lasso_depart.z, _lasso_fin.z))
	var b := Vector2(maxf(_lasso_depart.x, _lasso_fin.x), maxf(_lasso_depart.z, _lasso_fin.z))
	return Rect2(a, b - a)

func _montrer_le_lasso() -> void:
	var r := _rect_du_lasso()
	if r.size.x < 1.0 and r.size.y < 1.0: return
	_cadre.mesh = _rectangle(r, Color(Atelier.ACCENT, 0.18))
	_cadre.position = Vector3(0, _ville.sol(_case) + 0.9, 0)
	_cadre.visible = true

## Le relâchement : ce qui est dans le rectangle devient la sélection multiple.
## Un rectangle plus petit qu'une demi-case est un simple clic dans le vide.
func _finir_le_lasso() -> void:
	var r := _rect_du_lasso()
	_lasso_depart = Vector3(-1e9, 0, 0)
	_multi.clear()
	if r.size.x < DEMI * 0.5 and r.size.y < DEMI * 0.5:
		_cadre.visible = false
		return
	for k in _ville.objets.size():
		var o: Dictionary = _ville.objets[k]
		if bool(o.get("zone", false)): continue   # le mobilier posé par le générateur d'une zone
		if r.has_point(Vector2(float(o["x"]), float(o["z"]))):
			_multi.append({"genre": "objet", "k": k})
	for k2 in _ville.lots.size():
		var c := _ville.centre_du_lot(_ville.lots[k2])
		if r.has_point(Vector2(c.x, c.z)):
			_multi.append({"genre": "lot", "k": k2})
	_selection = {}
	if _multi.is_empty():
		_cadre.visible = false
		_dire("Rien dans le rectangle.")
		return
	var nb_o := 0
	var nb_l := 0
	for m in _multi:
		if String((m as Dictionary)["genre"]) == "objet": nb_o += 1
		else: nb_l += 1
	_cadre.mesh = _rectangle(r, Color(TEINTE_SELECTION, 0.15))
	_cadre.visible = true
	_maj_info()
	_dire("Sélection : %d objet(s), %d bâtiment(s) — Suppr efface tout, Échap lâche." % [nb_o, nb_l])
	if _info != null:
		_info.text = "[color=#9ea5b4]lasso[/color]\n[b][color=#e9ebf1]%d objets, %d bâtiments[/color][/b]" % [nb_o, nb_l]
		_bloc_selection.visible = true

## Suppr sur une sélection multiple : les index du plus grand au plus petit,
## pour qu'un retrait ne décale pas les suivants.
func _supprimer_multi() -> void:
	_empiler()
	var objets: Array = []
	var lots: Array = []
	var touchees: Array = []
	for m in _multi:
		var d: Dictionary = m
		if String(d["genre"]) == "objet": objets.append(int(d["k"]))
		else: lots.append(int(d["k"]))
	objets.sort(); objets.reverse()
	lots.sort(); lots.reverse()
	for k in objets:
		var o: Dictionary = _ville.objets[k]
		touchees.append(Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE)))
		_ville.objets.remove_at(k)
	for k2 in lots:
		touchees.append_array(Ville2.cases_du_lot(_ville.lots[k2]))
		_ville.lots.remove_at(k2)
	var n := _multi.size()
	_multi.clear()
	_selection = {}
	_cadre.visible = false
	_rebatir(touchees)
	_maj_info()
	_dire("Effacé : %d élément(s). (Ctrl+Z annule)" % n)

# ------------------------------------------------------------------ dupliquer, cadrer, série

## Ctrl+D : une copie de ce qu'on tient, une case plus loin, et c'est elle
## qu'on tient maintenant — pour poser dix bancs identiques sans repasser par
## le catalogue.
func _dupliquer_selection() -> void:
	if _selection.is_empty(): return
	_empiler()
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = (_ville.objets[int(_selection["k"])] as Dictionary).duplicate()
			o["x"] = float(o["x"]) + CASE
			_ville.objets.append(o)
			_selection = {"genre": "objet", "k": _ville.objets.size() - 1}
			_rebatir([_case_de(float(o["x"]), float(o["z"]))])
		"lot":
			var l: Dictionary = (_ville.lots[int(_selection["k"])] as Dictionary).duplicate()
			l["x"] = int(l["x"]) + int(l["w"])
			if not _lot_possible(String(l["m"]), Vector2i(int(l["x"]), int(l["y"]))) and not _libre.button_pressed:
				_pile.pop_back()
				_dire("Pas de place à côté pour le double — déplace-le, ou coche Chevauchement.")
				return
			_ville.lots.append(l)
			_selection = {"genre": "lot", "k": _ville.lots.size() - 1}
			_rebatir(Ville2.cases_du_lot(l))
		_:
			_pile.pop_back()
			_dire("Une route ne se duplique pas — trace-la.")
			return
	_montrer_cadre()
	_dire("Dupliqué. Tire-le où tu veux, A / E pour tourner.")

## ⭐ CTRL+C / CTRL+V : UN GROUPE ENTIER, RECOLLÉ SOUS LE CURSEUR. Ctrl+D
## double une pièce ; le lasso en prend cinquante. Entre les deux il manquait
## le geste qui fait un éditeur : garnir un bout de rue (deux bancs, trois
## arbres, un abribus, une voiture), le copier, et le recoller dix fois le
## long de la même rue. On garde tout en RELATIF à une ancre (le centre du
## groupe), et Ctrl+V le repose autour de la case visée : les objets à
## l'aimant, les bâtiments à la demi-case, ceux qui ne trouvent pas leur
## place sautés (sauf Chevauchement coché). Ce qui vient d'être collé devient
## la sélection : Suppr l'ôte, un second Ctrl+V en repose un autre.
func _copier() -> void:
	var groupe: Array = []
	if not _multi.is_empty():
		groupe = _multi
	elif not _selection.is_empty() and String(_selection["genre"]) != "route":
		groupe = [_selection]
	if groupe.is_empty():
		_dire("Rien à copier — sélectionne un objet, un bâtiment, ou un lasso.")
		return
	var objets: Array = []
	var lots: Array = []
	var somme := Vector2.ZERO
	var n := 0
	for m in groupe:
		var d: Dictionary = m
		if String(d["genre"]) == "objet":
			var o: Dictionary = _ville.objets[int(d["k"])]
			var oc := o.duplicate()
			if oc.has("y_abs"):
				# Une hauteur absolue ne veut rien dire ailleurs : on garde la
				# hauteur AU-DESSUS DU SOL, et le sol d'arrivée fera le reste.
				oc["_h"] = float(oc["y_abs"]) - TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"]))
				oc.erase("y_abs")
			objets.append(oc)
			somme += Vector2(float(o["x"]), float(o["z"]))
		else:
			var l: Dictionary = _ville.lots[int(d["k"])]
			lots.append(l.duplicate())
			var c := _ville.centre_du_lot(l)
			somme += Vector2(c.x, c.z)
		n += 1
	var ancre := somme / float(n)
	for o2 in objets:
		var od: Dictionary = o2
		od["x"] = float(od["x"]) - ancre.x
		od["z"] = float(od["z"]) - ancre.y
	for l2 in lots:
		var ld: Dictionary = l2
		ld["x"] = int(ld["x"]) - roundi(ancre.x / DEMI)
		ld["y"] = int(ld["y"]) - roundi(ancre.y / DEMI)
	_presse_papier = {"objets": objets, "lots": lots}
	_dire("Copié : %d objet(s), %d bâtiment(s) — Ctrl+V les recolle sous le curseur." % [objets.size(), lots.size()])

func _coller() -> void:
	if _presse_papier.is_empty():
		_dire("Rien dans le presse-papier — Ctrl+C d'abord.")
		return
	if not _ville.dedans(_case):
		_dire("Vise la carte pour coller.")
		return
	_empiler()
	var ancre := Vector2(_aimanter(_point.x), _aimanter(_point.z))
	var demi := Vector2i(roundi(ancre.x / DEMI), roundi(ancre.y / DEMI))
	var touchees: Array = []
	var poses: Array = []
	var sautes := 0
	for l in _presse_papier["lots"]:
		var ld: Dictionary = (l as Dictionary).duplicate()
		ld["x"] = int(ld["x"]) + demi.x
		ld["y"] = int(ld["y"]) + demi.y
		if not _lot_possible(String(ld["m"]), Vector2i(int(ld["x"]), int(ld["y"]))) \
				and not (_libre != null and _libre.button_pressed):
			sautes += 1
			continue
		_ville.lots.append(ld)
		poses.append({"genre": "lot", "k": _ville.lots.size() - 1})
		touchees.append_array(Ville2.cases_du_lot(ld))
		# Le registre des demi-cases suit, pour que le lot suivant du même
		# groupe ne se pose pas dessus.
		_ville.rasteriser()
	for o in _presse_papier["objets"]:
		var od: Dictionary = (o as Dictionary).duplicate()
		od["x"] = float(od["x"]) + ancre.x
		od["z"] = float(od["z"]) + ancre.y
		var c := _case_de(float(od["x"]), float(od["z"]))
		if not _ville.dedans(c):
			sautes += 1
			continue
		if od.has("_h"):
			od["y_abs"] = TerrainV2.hauteur_en(_ville, float(od["x"]), float(od["z"])) + float(od["_h"])
			od.erase("_h")
		_ville.objets.append(od)
		poses.append({"genre": "objet", "k": _ville.objets.size() - 1})
		touchees.append(c)
	if poses.is_empty():
		_pile.pop_back()
		_dire("Rien n'a pu se poser ici (%d sauté(s)) — une rue, l'eau ou un bâtiment. Coche Chevauchement pour forcer." % sautes)
		return
	_multi = poses
	_selection = {}
	_rebatir(touchees)
	for m in _multi:
		var d: Dictionary = m
		if String(d["genre"]) == "objet": _noter_recent(String(_ville.objets[int(d["k"])]["m"]))
	# Le cadre autour de ce qu'on vient de coller.
	var r := Rect2(ancre, Vector2.ZERO)
	for m2 in _multi:
		var d2: Dictionary = m2
		if String(d2["genre"]) == "objet":
			var o3: Dictionary = _ville.objets[int(d2["k"])]
			r = r.expand(Vector2(float(o3["x"]), float(o3["z"])))
		else:
			var c3 := _ville.centre_du_lot(_ville.lots[int(d2["k"])])
			r = r.expand(Vector2(c3.x, c3.z))
	r = r.grow(DEMI * 0.5)
	_cadre.mesh = _rectangle(r, Color(TEINTE_SELECTION, 0.15))
	_cadre.visible = true
	_maj_info()
	_dire("Collé : %d élément(s)%s — Ctrl+V encore pour un autre, Suppr pour l'ôter." % [poses.size(),
		(", %d sauté(s)" % sautes) if sautes > 0 else ""])

## F : la caméra vient sur ce qu'on tient (ou sur la case visée).
func _cadrer_selection() -> void:
	var cible := Vector3.ZERO
	if _selection.is_empty():
		if not _ville.dedans(_case): return
		cible = Vector3((float(_case.x) + 0.5) * CASE, 0, (float(_case.y) + 0.5) * CASE)
	else:
		match String(_selection["genre"]):
			"objet":
				var o: Dictionary = _ville.objets[int(_selection["k"])]
				cible = Vector3(float(o["x"]), 0, float(o["z"]))
			"lot":
				cible = _ville.centre_du_lot(_ville.lots[int(_selection["k"])])
			"route":
				var cases := Ville2.cases_de_route(_ville.routes[int(_selection["k"])])
				var c: Vector2i = cases[cases.size() / 2]
				cible = Vector3((float(c.x) + 0.5) * CASE, 0, (float(c.y) + 0.5) * CASE)
	_pivot = Vector3(cible.x, 0, cible.z)
	_distance = minf(_distance, 220.0)
	_placer_camera()

## LA POSE EN SÉRIE : Maj tenue à l'outil Objet, on clique un premier point
## puis un second, et les objets se posent tous les `PAS_SERIE` entre les deux
## — une rangée de lampadaires, une haie, une file de voitures. Le pas est
## celui de l'aimant s'il est d'au moins une demi-case, une demi-case sinon.
var _serie_depart := Vector3(-1e9, 0, 0)

func _pas_de_serie() -> float:
	return maxf(pas_d_aimant(), DEMI)

func _poser_en_serie(fin: Vector3) -> void:
	var m := _modele_objet()
	if m == "": return
	var depart := _serie_depart
	_serie_depart = Vector3(-1e9, 0, 0)
	var vec := fin - depart
	vec.y = 0.0
	var longueur := vec.length()
	if longueur < _pas_de_serie() * 0.5:
		_dire("Série : les deux points sont trop proches.")
		return
	var pas := _pas_de_serie()
	var n := int(floor(longueur / pas)) + 1
	var dir := vec / longueur
	# Les objets regardent perpendiculairement à la rangée (un banc, un
	# lampadaire), sauf les voitures qui la suivent.
	var cap := atan2(-dir.x, -dir.z) + (0.0 if m.begins_with("voitures/") else PI * 0.5)
	_empiler()
	var poses := 0
	var touchees: Array = []
	for i in n:
		var p := depart + dir * (pas * float(i))
		var c := _case_de(p.x, p.z)
		if not _ville.dedans(c): continue
		if not _objet_possible(m, c): continue
		var o := {"m": m, "x": _aimanter(p.x), "z": _aimanter(p.z), "r": cap, "h": 0.0}
		if absf(_decalage) > 0.01:
			o["y_abs"] = TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"])) + _decalage
		_ville.objets.append(o)
		touchees.append(c)
		poses += 1
	if poses == 0:
		_pile.pop_back()
		_dire("Série : rien ne pouvait se poser sur cette ligne.")
		return
	_rebatir(touchees)
	_noter_recent(m)
	_dire("Série : %d × %s, tous les %.1f." % [poses, _nom_lisible(m), pas])

# ------------------------------------------------------------------ les vignettes

## Le viewport des vignettes : son propre monde, un fond transparent, une
## lumière et une caméra ; il ne rend que quand on le lui demande.
func _monter_vignettes() -> void:
	_vue_vignette = SubViewport.new()
	_vue_vignette.size = Vector2i(VIGNETTE * 2, VIGNETTE * 2)
	_vue_vignette.own_world_3d = true
	_vue_vignette.transparent_bg = true
	_vue_vignette.msaa_3d = Viewport.MSAA_4X
	_vue_vignette.render_target_update_mode = SubViewport.UPDATE_DISABLED
	interface().add_child(_vue_vignette)
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-50.0, -35.0, 0)
	lumiere.light_energy = 1.4
	lumiere.light_color = Color("#fff3dc")
	_vue_vignette.add_child(lumiere)
	var monde_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#aab8cc")
	env.ambient_light_energy = 0.9
	monde_env.environment = env
	_vue_vignette.add_child(monde_env)
	_vignette_noeud = MeshInstance3D.new()
	_vue_vignette.add_child(_vignette_noeud)
	var cam := Camera3D.new()
	cam.name = "Camera"
	_vue_vignette.add_child(cam)
	cam.make_current()
	# La tuile vide : un carré de la couleur du champ, le temps que la photo
	# arrive. Sans lui, les tuiles sans image sont plus petites que les autres
	# et la grille saute quand les vignettes tombent.
	var img := Image.create(VIGNETTE, VIGNETTE, false, Image.FORMAT_RGBA8)
	img.fill(Color(Atelier.SURFACE, 0.6))
	_vignette_vide = ImageTexture.create_from_image(img)

## Photographie le prochain modèle de la file, puis pose l'image sur toutes les
## tuiles qui le montrent. Une par image ; `_process` rappelle.
func _rendre_une_vignette() -> void:
	if _vignette_occupee or _file_vignettes.is_empty(): return
	_vignette_occupee = true
	var m: String = _file_vignettes.pop_front()
	var chemin := _chemin_de(m)
	if chemin == "" or not ResourceLoader.exists(chemin):
		_vignettes[m] = null
		_vignette_occupee = false
		return
	var maillage := FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	_vignette_noeud.mesh = maillage
	_vignette_noeud.material_override = FormesCarnage.matiere_kenney(chemin)
	var boite := maillage.get_aabb()
	var rayon := maxf(0.001, boite.size.length() * 0.5)
	_vignette_noeud.position = Vector3(0, -boite.size.y * 0.5, 0)
	_vignette_noeud.rotation = Vector3(0, -0.6, 0)
	var cam := _vue_vignette.get_node("Camera") as Camera3D
	cam.near = rayon * 0.01
	cam.far = rayon * 20.0
	cam.position = Vector3(0, rayon * 0.7, rayon * 2.1)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	_vue_vignette.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	var img := _vue_vignette.get_texture().get_image()
	img.resize(VIGNETTE, VIGNETTE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_vignettes[m] = tex
	for k in _liste.size():
		if _liste[k] == m and k < _palette.item_count:
			_palette.set_item_icon(k, tex)
	_vignette_occupee = false

## Pose sur chaque tuile son image si on l'a, la tuile vide sinon — et met en
## file ce qui manque. On vide la file d'abord : les modèles de l'ancien
## filtre n'ont plus de tuile où atterrir.
func _garnir_les_vignettes() -> void:
	_file_vignettes.clear()
	for k in _liste.size():
		var m := _liste[k]
		if _vignettes.has(m):
			var t: Variant = _vignettes[m]
			_palette.set_item_icon(k, t if t != null else _vignette_vide)
		else:
			_palette.set_item_icon(k, _vignette_vide)
			_file_vignettes.append(m)

# ------------------------------------------------------------------ l'aperçu 3D

## LA PETITE FENÊTRE 3D. Un `SubViewport` avec SON PROPRE monde : sans
## `own_world_3d`, l'aperçu montrerait la ville entière, et la ville
## recevrait la lumière de l'aperçu.
func _monter_apercu() -> void:
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-45.0, -40.0, 0)
	lumiere.light_energy = 1.5
	lumiere.light_color = Color("#fff3dc")
	_apercu3d.add_child(lumiere)
	var monde_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1f2733")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb0c4")
	env.ambient_light_energy = 0.8
	monde_env.environment = env
	_apercu3d.add_child(monde_env)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	_apercu3d.add_child(pivot)
	_apercu_noeud = MeshInstance3D.new()
	pivot.add_child(_apercu_noeud)
	var cam := Camera3D.new()
	cam.name = "Camera"
	_apercu3d.add_child(cam)
	cam.make_current()

## Montre le modèle choisi, cadré sur sa boîte : un lampadaire et un
## gratte-ciel doivent remplir la fenêtre autant l'un que l'autre.
func _maj_apercu() -> void:
	if _apercu_noeud == null: return
	var m := _modele_lot() if _outil == OUTIL_LOT else _modele_objet()
	if _outil == OUTIL_ROUTE or _outil == OUTIL_SOL: m = ""
	if m == "":
		_apercu_noeud.mesh = null
		_apercu_nom.text = ""
		return
	var chemin := _chemin_de(m)
	if chemin == "" or not ResourceLoader.exists(chemin):
		_apercu_noeud.mesh = null
		_apercu_nom.text = m + " (pas un modèle)"
		return
	var maillage := FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	_apercu_noeud.mesh = maillage
	_apercu_noeud.material_override = FormesCarnage.matiere_kenney(chemin)
	var boite := maillage.get_aabb()
	var rayon := maxf(0.001, boite.size.length() * 0.5)
	# Le modèle est recentré en X et Z et posé sur y = 0 : on vise son milieu.
	_apercu_noeud.position = Vector3(0, -boite.size.y * 0.5, 0)
	var cam := _apercu3d.get_node("Camera") as Camera3D
	cam.near = rayon * 0.01
	cam.far = rayon * 20.0
	cam.position = Vector3(0, rayon * 0.55, rayon * 2.4)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	# ⚠ UN RACCOURCI N'A PAS D'EMPRISE, IL A UNE HAUTEUR. « lampadaire » n'est
	# pas un modèle mais une fiche du catalogue : mesuré comme un bâtiment, il
	# sortait à « 1,0 × 1,0 × 1,0 case », ce qui ne veut rien dire.
	var fiche: Dictionary = KitVille2.PROPS.get(m, {})
	if not fiche.is_empty():
		_apercu_nom.text = "%s — %s, %.1f unité(s) de haut" % [m,
			KitVille2.nom_court(chemin), float(fiche.get("h", 0.0))]
		return
	var t := KitVille2.mesurer(m)
	_apercu_nom.text = "%s — %.1f × %.1f × %.1f cases (%.0f × %.0f × %.0f unités)" % [
		_nom_lisible(m), t.x, t.y, t.z, t.x * CASE, t.y * CASE, t.z * CASE]

func _process(delta: float) -> void:
	_rendre_une_vignette()
	if _etiquette_chantier != null and _morceaux != null:
		var reste := _morceaux.en_attente()
		if (reste > 0) != _etiquette_chantier.visible:
			_etiquette_chantier.visible = reste > 0
		if reste > 0:
			var t := "bâtit…  %d morceaux" % reste
			if _etiquette_chantier.text != t: _etiquette_chantier.text = t
	if _etiquette_case != null and _case.x >= 0:
		var texte_case := "case %d, %d" % [_case.x, _case.y]
		if _etiquette_case.text != texte_case: _etiquette_case.text = texte_case
	if _apercu3d == null: return
	var pivot := _apercu3d.get_node_or_null("Pivot") as Node3D
	if pivot != null and _apercu_noeud != null and _apercu_noeud.mesh != null:
		_tourne_apercu += delta * 0.6
		pivot.rotation.y = _tourne_apercu

## Les cartes livrées dans `res://cartes/`. ⚠ `DirAccess` ne voit pas les
## mêmes noms dans un paquet exporté qu'au bureau : au navigateur on lit la
## liste écrite dans `cartes/index.json`, qui est engendrée avec les cartes.
func _cartes_du_dossier() -> Array:
	var noms: Array = []
	var index := FileAccess.get_file_as_string("res://cartes/index.json")
	if index != "":
		var brut = JSON.parse_string(index)
		if typeof(brut) == TYPE_ARRAY:
			for n in brut: noms.append(String(n))
	if noms.is_empty():
		var d := DirAccess.open("res://cartes")
		if d != null:
			for f in d.get_files():
				if f.ends_with(".json") and f != "index.json":
					noms.append(f.get_basename())
	# ⭐⭐⭐ LES FENÊTRES DU PAYS QU'ON A ENREGISTRÉES ENTRENT DANS LA LISTE.
	#
	# `res://cartes/` ne contient que les cartes LIVRÉES : les neuf témoins. Une
	# fenêtre du pays retouchée n'existe que dans `user://cartes/`, sous un nom
	# que le plan ne connaît pas — elle n'apparaissait donc nulle part, et le
	# seul moyen d'y revenir était de retaper son URL à la main. Enregistrer un
	# travail qu'on ne sait pas rouvrir, ce n'est pas l'enregistrer.
	#
	# ⚠ ON NE LES INVENTE PAS : on lit le dossier des versions personnelles et on
	# ne garde que ce qui porte le préfixe `pays-`. Un témoin retouché est déjà
	# dans la liste par son nom livré — l'ajouter deux fois ferait deux entrées
	# pour la même carte.
	for f2 in _fenetres_enregistrees():
		if not noms.has(f2): noms.append(f2)
	noms.sort()
	return noms

## Les fenêtres du pays présentes dans les versions personnelles.
func _fenetres_enregistrees() -> Array:
	var sortie: Array = []
	var d := DirAccess.open("user://cartes")
	if d == null: return sortie
	for f in d.get_files():
		if f.begins_with("pays-") and f.ends_with(".json"):
			sortie.append(f.get_basename())
	return sortie

func _changer_de_carte(k: int) -> void:
	var nom := _nom_de_carte(k)
	# ⚠ ON NE JETTE PAS DU TRAVAIL EN SILENCE. Changer de carte recharge tout :
	# si la ville courante a bougé depuis le dernier enregistrement, le premier
	# clic ne fait que PRÉVENIR, et il faut re-cliquer pour confirmer. C'est la
	# moitié du « mes modifications disparaissent » — l'autre moitié était le
	# chemin de relecture (voir `Ville2.chemin_utile`).
	if _des_choses_non_enregistrees() and _a_prevenir != nom:
		_a_prevenir = nom
		# On remet la liste sur la carte courante : sinon elle affiche déjà la
		# nouvelle alors qu'on n'a pas changé.
		for j in _cartes.item_count:
			if _nom_de_carte(j) == _chemin.get_file().get_basename(): _cartes.select(j)
		_dire("⚠ « %s » a des modifications NON ENREGISTRÉES. Ctrl+S pour les garder, ou rechoisis « %s » pour les abandonner." % [
			_chemin.get_file(), nom])
		return
	_a_prevenir = ""
	_chemin = "res://cartes/%s.json" % nom
	var v := Ville2.charger(_chemin)
	if v.lots.is_empty() and v.routes.is_empty():
		_dire("Carte « %s » illisible." % nom)
		return
	_pile.clear()
	_refaire.clear()
	_recharger(v.vers_json())
	_dernier_enregistre = _ville.vers_json()
	# ⚠ UNE FENÊTRE DU PAYS DOIT RETROUVER SON CADRE. Le nom porte son centre et
	# son côté ; sans les relire, la minicarte continuerait d'encadrer la
	# fenêtre précédente et le Ctrl+S écrirait sous l'ancien nom.
	_relire_le_cadre(nom)
	_remplir_les_cartes()
	_tout_voir()
	_maj_compteur()
	var doù := "ta version enregistrée" if Ville2.carte_modifiee(_chemin) else "la carte livrée"
	_dire("Ville « %s » (%s) — %d lots, %d objets, %d routes." % [_ville.nom, doù,
		_ville.lots.size(), _ville.objets.size(), _ville.routes.size()])

## La carte pour laquelle on vient de prévenir : un second choix du même nom
## vaut confirmation.
var _a_prevenir := ""

func _remplir_palette() -> void:
	_palette.clear()
	_liste.clear()
	if _outil == OUTIL_SOL:
		# Cinq matières, chacune avec sa couleur en pastille.
		_palette.icon_mode = ItemList.ICON_MODE_LEFT
		_palette.max_columns = 1
		_palette.fixed_column_width = 0
		_palette.fixed_icon_size = Vector2i(24, 24)
		for f0 in MATIERES:
			var nom_m := String(f0[0])
			_liste.append(nom_m)
			_palette.add_item(nom_m, _pastille_de_couleur(TerrainV2.COULEURS[int(f0[1])]))
		_palette.select(clampi(_matiere_choisie, 0, _palette.item_count - 1))
		_palette.visible = true
		_maj_apercu()
		return
	if _outil == OUTIL_ROUTE:
		# Trois genres : une liste, pas une grille de vignettes.
		_palette.icon_mode = ItemList.ICON_MODE_LEFT
		_palette.max_columns = 1
		_palette.fixed_column_width = 0
		_palette.fixed_icon_size = Vector2i.ZERO
		for g in GENRES_ROUTE:
			_liste.append(String(g))
			_palette.add_item(String(g).capitalize())
		_palette.select(clampi(_genre_route, 0, _palette.item_count - 1))
		_palette.visible = true
		_maj_apercu()
		return
	# LA GRILLE DE VIGNETTES : l'image au-dessus du nom, des colonnes égales,
	# le nom coupé d'une ellipse plutôt que la tuile élargie.
	_palette.icon_mode = ItemList.ICON_MODE_TOP
	_palette.max_columns = 0
	_palette.same_column_width = true
	_palette.fixed_column_width = COLONNE
	_palette.fixed_icon_size = Vector2i(VIGNETTE, VIGNETTE)
	_palette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# ⚠ LA PALETTE RESTE VISIBLE MÊME HORS POSE. Le client veut VOIR le
	# catalogue et son aperçu ; la cacher dès qu'on prend l'outil Sélection
	# revenait à lui retirer la moitié de l'écran.
	var fiche: Variant = _familles.get_item_metadata(_familles.selected)
	var f: String = String((fiche as Dictionary).get("cle", FAMILLE_TOUT)) \
		if fiche is Dictionary else FAMILLE_TOUT
	var cherche := _recherche.text.strip_edges().to_lower()
	var source: Array = []
	if f == FAMILLE_RECENTS:
		source = _recents.duplicate()
	elif f == FAMILLE_RACCOURCIS:
		source = raccourcis()
	else:
		source = KitVille2.catalogue().duplicate()
		if f != FAMILLE_TOUT:
			var par_categorie := not f.contains(KitVille2.SEPARATEUR_RAYON)
			var gardes: Array = []
			for m in source:
				var va := KitVille2.categorie(String(m)) if par_categorie \
					else KitVille2.famille(String(m))
				if va == f: gardes.append(m)
			source = gardes
	for m in source:
		var nom := _nom_lisible(String(m))
		if cherche != "" and not nom.to_lower().contains(cherche): continue
		_liste.append(String(m))
		_palette.add_item(nom)
		_palette.set_item_tooltip(_palette.item_count - 1, nom)
	_garnir_les_vignettes()
	_palette.visible = true
	var choisi: int = _lot_choisi if _outil == OUTIL_LOT else _objet_choisi
	if _palette.item_count > 0:
		_palette.select(clampi(choisi, 0, _palette.item_count - 1))
	_maj_apercu()

## Le nom montré dans la liste : le nom de fichier pour un modèle, le mot du
## catalogue pour un raccourci.
func _nom_lisible(m: String) -> String:
	if m.begins_with("res://"): return KitVille2.nom_court(m)
	return m

## Le chemin `res://…` d'une entrée de la palette (un raccourci passe par son
## catalogue de props).
func _chemin_de(m: String) -> String:
	if m.begins_with("res://"): return m
	var fiche: Dictionary = KitVille2.PROPS.get(m, {})
	if not fiche.is_empty(): return KitVille2.chemin(String(fiche["m"]))
	if m == "pelouse": return ""
	return KitVille2.chemin(m)

func _palette_choisie(k: int) -> void:
	match _outil:
		OUTIL_LOT: _lot_choisi = k
		OUTIL_OBJET: _objet_choisi = k
		OUTIL_ROUTE: _genre_route = k
		OUTIL_SOL: _matiere_choisie = k
	_maj_apercu()
	_montrer_apercu()

func _choisir_outil(k: int) -> void:
	_finir_route(false)
	_outil = k
	if k < _boutons_outils.size() and not _boutons_outils[k].button_pressed:
		_boutons_outils[k].button_pressed = true
	_selection = {}
	_multi.clear()
	_cadre.visible = false
	# LE CONTEXTE NE MONTRE QUE CE QUI SERT À L'OUTIL.
	if _titre_outil != null:
		_titre_outil.text = NOMS_OUTILS[k]
		_conseil_outil.text = CONSEILS_OUTILS[k]
		_bloc_pose.visible = k in [OUTIL_LOT, OUTIL_OBJET, OUTIL_SELECTION]
		_bloc_route.visible = k == OUTIL_ROUTE
		_bloc_terrain.visible = k == OUTIL_TERRAIN or k == OUTIL_EAU or k == OUTIL_SOL
	_maj_info()
	_remplir_palette()
	_montrer_apercu()
	_dire("Outil : " + NOMS_OUTILS[k])

func _dire(texte: String) -> void:
	if _etat != null:
		_etat.text = texte

# ------------------------------------------------------------------ la grille

func _poser_grille() -> void:
	if _grille != null:
		_grille.queue_free()
	_grille = MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = TEINTE_GRILLE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var lx := float(_ville.taille.x) * CASE
	var lz := float(_ville.taille.y) * CASE
	for i in _ville.taille.x + 1:
		im.surface_add_vertex(Vector3(float(i) * CASE, 0.6, 0))
		im.surface_add_vertex(Vector3(float(i) * CASE, 0.6, lz))
	for j in _ville.taille.y + 1:
		im.surface_add_vertex(Vector3(0, 0.6, float(j) * CASE))
		im.surface_add_vertex(Vector3(lx, 0.6, float(j) * CASE))
	im.surface_end()
	_grille.mesh = im
	monde().add_child(_grille)

# ------------------------------------------------------------------ la caméra

## LE RECUL QUI TIENT LA CARTE ENTIÈRE. Avec un champ de 50°, il faut à peu
## près un côté et quart de distance pour cadrer un carré de ce côté.
func _recul_maxi() -> float:
	return float(maxi(_ville.taille.x, _ville.taille.y)) * CASE * 1.15

func _recul_mini() -> float:
	return CASE * 1.5

func _placer_camera() -> void:
	_distance = clampf(_distance, _recul_mini(), _recul_maxi())
	# ⚠ LE PIVOT RESTE AU-DESSUS DE LA CARTE. On peut regarder un peu au-delà
	# du bord — c'est utile pour poser contre la lisière — mais pas partir à
	# l'infini et perdre la ville de vue.
	var marge := CASE * 6.0
	_pivot.x = clampf(_pivot.x, -marge, float(_ville.taille.x) * CASE + marge)
	_pivot.z = clampf(_pivot.z, -marge, float(_ville.taille.y) * CASE + marge)
	_pivot.y = 0.0
	var d := Vector3(sin(_azimut) * cos(_inclinaison), sin(_inclinaison), cos(_azimut) * cos(_inclinaison)) * _distance
	_camera.look_at_from_position(_pivot + d, _pivot, Vector3.UP)
	# ⚠ LES DOCKS MANGENT L'ÉCRAN. La caméra rend la vue ENTIÈRE, docks
	# compris : cadrée sur le milieu de la fenêtre, la ville se retrouve à
	# moitié sous le panneau de droite. On décale donc la caméra de la moitié
	# de la différence des deux docks, en unités du monde à cette distance.
	var ecran := get_viewport().get_visible_rect().size
	if ecran.y > 1.0:
		var par_pixel := 2.0 * _distance * tan(deg_to_rad(_camera.fov) * 0.5) / ecran.y
		var gauche := 0.0
		var droite := 0.0
		if _panneaux_visibles:
			gauche = float(LARGE_RAIL + LARGE_CONTEXTE)
			droite = float(LARGE_DROITE)
		_camera.global_position += _camera.global_transform.basis.x \
			* (droite - gauche) * 0.5 * par_pixel

## Cadrer toute la carte — le bouton de la barre et la touche Début.
func _tout_voir() -> void:
	_pivot = Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5)
	_distance = _recul_maxi()
	_placer_camera()

func _viser() -> void:
	var origine := _camera.project_ray_origin(_souris)
	var dir := _camera.project_ray_normal(_souris)
	var p = _sur_plan(origine, dir, 0.0)
	if p == null:
		_case = Vector2i(-1, -1)
		return
	var c := Vector2i(floori((p as Vector3).x / CASE), floori((p as Vector3).z / CASE))
	# Deuxième passe à l'altitude de la case visée : sur un plateau, la
	# première suffit ; sur une colline, on corrige.
	if _ville.dedans(c):
		var y := _ville.sol(c)
		if y != 0.0:
			var p2 = _sur_plan(origine, dir, y)
			if p2 != null:
				p = p2
				c = Vector2i(floori((p as Vector3).x / CASE), floori((p as Vector3).z / CASE))
	_point = p as Vector3
	_case = c

func _sur_plan(origine: Vector3, dir: Vector3, y: float):
	if absf(dir.y) < 1.0e-5: return null
	var t := (y - origine.y) / dir.y
	if t < 0.0: return null
	return origine + dir * t

# ------------------------------------------------------------------ l'entrée

## ⚠ `_unhandled_input`, PAS `_input`. `_input` passe AVANT l'interface : la
## molette au-dessus de la liste des modèles zoomait la carte au lieu de faire
## défiler la liste, et taper « route » dans la recherche déclenchait les
## outils R, O, U, T, E. En `_unhandled_input`, un panneau qui arrête la souris
## et un champ qui a le clavier ont servi les premiers ; on ne reçoit que ce
## qui tombe sur la vue.
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var m := ev as InputEventMouseMotion
		_souris = m.position
		if _orbite:
			_azimut -= m.relative.x * 0.006
			_inclinaison = clampf(_inclinaison + m.relative.y * 0.006, 0.15, 1.5)
			_placer_camera()
		elif _glisse:
			var droite := _camera.global_transform.basis.x
			var avant := Vector3(-_camera.global_transform.basis.z.x, 0, -_camera.global_transform.basis.z.z).normalized()
			_pivot -= (droite * m.relative.x - avant * m.relative.y) * _distance * 0.0016
			_placer_camera()
		elif _tire:
			_viser()
			_glisser()
		elif _presse and _lasso_depart.x > -1e8:
			_viser()
			_lasso_fin = _point
			_montrer_le_lasso()
		else:
			_viser()
			_montrer_apercu()
			if _presse and (_outil == OUTIL_TERRAIN or _outil == OUTIL_EAU):
				pass
	elif ev is InputEventMouseButton:
		var b := ev as InputEventMouseButton
		_souris = b.position
		match b.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if b.pressed:
					_distance = maxf(_recul_mini(), _distance * 0.88)
					_placer_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					# ⚠ LE DÉZOOM A UNE BUTÉE. Sans elle, une roulette un peu
					# vive envoyait la caméra à six mille unités : la ville
					# devenait un point, et il fallait « Tout voir » pour la
					# retrouver. On ne recule pas plus loin que ce qu'il faut
					# pour tenir la carte entière à l'écran.
					_distance = minf(_recul_maxi(), _distance * 1.14)
					_placer_camera()
			MOUSE_BUTTON_RIGHT:
				if b.pressed and _outil == OUTIL_ROUTE and not _trace.is_empty():
					_finir_route(true)
				elif b.pressed and (_outil == OUTIL_TERRAIN or _outil == OUTIL_EAU):
					_viser()
					_appliquer(false)
				else:
					_orbite = b.pressed
			MOUSE_BUTTON_MIDDLE:
				_glisse = b.pressed
			MOUSE_BUTTON_LEFT:
				if b.shift_pressed and _outil == OUTIL_OBJET:
					# La pose en série : premier clic = départ, second = fin.
					if b.pressed:
						_viser()
						if _serie_depart.x < -1e8:
							_serie_depart = _point
							_dire("Série : clique le second point (Maj tenue). Échap annule.")
						else:
							_poser_en_serie(_point)
				elif b.shift_pressed:
					_glisse = b.pressed
				elif b.alt_pressed:
					# Alt + clic : la pipette à la souris, quel que soit l'outil.
					if b.pressed:
						get_viewport().gui_release_focus()
						_viser()
						_pipette(true)
				elif b.pressed:
					# ⚠ NE PLUS TESTER « EST-CE QUE JE SUIS SUR L'INTERFACE ».
					# Depuis la refonte en logiciel, le premier enfant de la
					# couche est un conteneur PLEIN ÉCRAN : le test répondait
					# « oui » partout et AUCUN CLIC n'arrivait jamais à la
					# ville — ni sélection, ni pose. Le filtre de souris fait
					# déjà le travail : les panneaux ARRÊTENT l'événement
					# (`MOUSE_FILTER_STOP`), le centre le LAISSE PASSER, et
					# `_unhandled_input` ne reçoit que ce qui tombe sur la vue.
					# Un clic dans la vue rend le clavier à la vue : sans ça,
					# un champ resté actif avalait les flèches et le ZQSD.
					get_viewport().gui_release_focus()
					_viser()
					_presse = true
					_appliquer(true)
					_armer_le_glisse()
					# Rien sous le clic à l'outil Sélection : on arme le lasso.
					if _outil == OUTIL_SELECTION and _selection.is_empty():
						_multi.clear()
						_lasso_depart = _point
						_lasso_fin = _point
				else:
					_presse = false
					_poser_le_glisse()
					if _lasso_depart.x > -1e8:
						_finir_le_lasso()
	elif ev is InputEventKey and (ev as InputEventKey).pressed:
		_touche(ev as InputEventKey)

func _touche(k: InputEventKey) -> void:
	if k.ctrl_pressed:
		match k.keycode:
			KEY_Z: _annuler()
			KEY_Y: _refaire_geste()
			KEY_S: _enregistrer()
			KEY_D: _dupliquer_selection()
			KEY_C: _copier()
			KEY_V: _coller()
			# ⚠ AVEC Ctrl, LES FLÈCHES POUSSENT LA SÉLECTION, PAS LA CAMÉRA.
			# C'est le seul moyen d'être VRAIMENT au pixel près : à cette
			# distance la souris ne peut pas viser un dixième d'unité, le
			# clavier si. Le pas est celui de l'aimant, ou un dixième quand
			# l'aimant est sur « libre ».
			KEY_LEFT, KEY_Q: _pousser(-1, 0)
			KEY_RIGHT, KEY_D: _pousser(1, 0)
			KEY_UP: _pousser(0, -1)
			KEY_DOWN: _pousser(0, 1)
		return
	# ⚠ À L'OUTIL SÉLECTION, LES FLÈCHES POUSSENT CE QU'ON A SÉLECTIONNÉ.
	# Le raccourci existait, mais seulement avec Ctrl : personne ne le trouve, et
	# le client demandait encore « me permettre de déplacer l'objet avec les
	# flèches, pixel par pixel » (16/09). Quand on tient déjà quelque chose à
	# l'outil Sélection, déplacer la CAMÉRA n'est pas ce qu'on veut — ZQSD et
	# Ctrl+flèches restent là pour ça.
	if _outil == OUTIL_SELECTION and not _selection.is_empty():
		match k.keycode:
			KEY_LEFT: _pousser(-1, 0); return
			KEY_RIGHT: _pousser(1, 0); return
			KEY_UP: _pousser(0, -1); return
			KEY_DOWN: _pousser(0, 1); return
	match k.keycode:
		KEY_1, KEY_KP_1: _choisir_outil(OUTIL_SELECTION)
		KEY_2, KEY_KP_2: _choisir_outil(OUTIL_ROUTE)
		KEY_3, KEY_KP_3: _choisir_outil(OUTIL_LOT)
		KEY_4, KEY_KP_4: _choisir_outil(OUTIL_OBJET)
		KEY_5, KEY_KP_5: _choisir_outil(OUTIL_TERRAIN)
		KEY_6, KEY_KP_6: _choisir_outil(OUTIL_EAU)
		KEY_7, KEY_KP_7: _choisir_outil(OUTIL_SOL)
		KEY_G:
			_genre_route = (_genre_route + 1) % GENRES_ROUTE.size()
			if _outil == OUTIL_ROUTE: _palette.select(_genre_route)
			_dire("Genre de route : " + GENRES_ROUTE[_genre_route])
		KEY_A:
			_quarts = posmod(_quarts + 1, 4)
			if not _multi.is_empty(): _tourner_multi(1)
			else: _tourner_selection(1)
			_montrer_apercu()
		KEY_E:
			_quarts = posmod(_quarts - 1, 4)
			if not _multi.is_empty(): _tourner_multi(-1)
			else: _tourner_selection(-1)
			_montrer_apercu()
		KEY_PAGEUP:
			_decalage = minf(_decalage + CASE * 0.1, CASE * 10.0)
			if _champ_decalage != null: _champ_decalage.value = _decalage / CASE
			_dire("Hauteur de pose : %.2f case." % (_decalage / CASE))
		KEY_PAGEDOWN:
			_decalage = maxf(_decalage - CASE * 0.1, CASE * -2.0)
			if _champ_decalage != null: _champ_decalage.value = _decalage / CASE
			_dire("Hauteur de pose : %.2f case." % (_decalage / CASE))
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			_rayon_terrain = mini(8, _rayon_terrain + 1)
			if _champ_rayon != null: _champ_rayon.value = _rayon_terrain
		KEY_MINUS, KEY_KP_SUBTRACT:
			_rayon_terrain = maxi(1, _rayon_terrain - 1)
			if _champ_rayon != null: _champ_rayon.value = _rayon_terrain
		KEY_ENTER, KEY_KP_ENTER:
			_finir_route(true)
		KEY_H:
			_basculer_l_aide()
		KEY_F:
			_cadrer_selection()
		KEY_I:
			_pipette()
		KEY_V:
			# La vue de dessus, et retour : la seule façon de juger un tracé
			# de rues comme sur un plan.
			_inclinaison = 0.9 if _inclinaison > 1.4 else 1.5
			_placer_camera()
			_dire("Vue de dessus." if _inclinaison > 1.4 else "Vue oblique.")
		KEY_TAB:
			_basculer_les_panneaux()
		KEY_M:
			if _boite_plan != null and _panneaux_visibles:
				_boite_plan.visible = not _boite_plan.visible
		KEY_ESCAPE:
			if _boite_aide != null and _boite_aide.visible:
				_boite_aide.visible = false
				return
			if _boite_publier != null and _boite_publier.visible:
				_boite_publier.visible = false
				return
			_serie_depart = Vector3(-1e9, 0, 0)
			_lasso_depart = Vector3(-1e9, 0, 0)
			_multi.clear()
			_finir_route(false)
			_selection = {}
			_cadre.visible = false
		KEY_DELETE, KEY_BACKSPACE:
			_supprimer_selection()
		KEY_P:
			_photographier()
		KEY_HOME:
			_tout_voir()
		# La caméra se conduit au ZQSD ET aux flèches. Le déplacement suit les
		# AXES DE L'ÉCRAN, pas ceux du monde : « avancer » va vers le haut de
		# l'écran quelle que soit l'orientation de la caméra.
		# ⚠ AVEC Ctrl, LES FLÈCHES POUSSENT LA SÉLECTION, PAS LA CAMÉRA. C'est
		# le seul moyen d'être VRAIMENT au pixel près : la souris ne peut pas
		# viser un dixième d'unité à cette distance, le clavier si. Le pas est
		# celui de l'aimant, ou un dixième quand il est sur « libre ».
		KEY_LEFT, KEY_Q: _deplacer(-1.0, 0.0)
		KEY_RIGHT, KEY_D: _deplacer(1.0, 0.0)
		KEY_UP, KEY_Z: _deplacer(0.0, 1.0)
		KEY_DOWN, KEY_S: _deplacer(0.0, -1.0)

## Pousse la sélection d'un pas, à la touche. Rien sans sélection.
func _pousser(dx: int, dz: int) -> void:
	if _selection.is_empty(): return
	var pas := pas_d_aimant()
	if pas <= 0.0: pas = 0.1
	_empiler()
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			o["x"] = float(o.get("x", 0.0)) + float(dx) * pas
			o["z"] = float(o.get("z", 0.0)) + float(dz) * pas
			_dire("x %.2f  z %.2f  (pas %.2f)" % [float(o["x"]), float(o["z"]), pas])
		"lot":
			# Un bâtiment vit sur la trame des demi-cases : il s'y pousse.
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			l["x"] = int(l["x"]) + dx
			l["y"] = int(l["y"]) + dz
			_dire("demi-case %d, %d" % [int(l["x"]), int(l["y"])])
		_:
			return
	_rebatir([])
	_montrer_cadre()

func _deplacer(cote: float, avant: float) -> void:
	var b := _camera.global_transform.basis
	var droite := Vector3(b.x.x, 0, b.x.z).normalized()
	var devant := Vector3(-b.z.x, 0, -b.z.z).normalized()
	_pivot += (droite * cote + devant * avant) * _distance * 0.08
	_placer_camera()

# ------------------------------------------------------------------ les gestes

func _appliquer(gauche: bool) -> void:
	if not _ville.dedans(_case): return
	match _outil:
		OUTIL_ROUTE: _ajouter_sommet()
		OUTIL_LOT: _poser_lot()
		OUTIL_OBJET: _poser_objet()
		OUTIL_TERRAIN: _sculpter(gauche)
		OUTIL_EAU: _peindre_eau(gauche)
		OUTIL_SOL: _peindre_sol()
		OUTIL_SELECTION: _selectionner()

## LA ROUTE PAR POINTS. Un sommet par clic ; entre deux sommets qui ne sont
## ni sur la même ligne ni sur la même colonne, on passe par le coude
## (horizontal d'abord, puis vertical) — le kit ne sait pas paver en biais.
func _ajouter_sommet() -> void:
	if not _ville.terre(_case):
		_dire("Une route ne se trace pas sur l'eau.")
		return
	if _trace.is_empty():
		_trace.append(_case)
		_dire("Route : premier point posé. Clic pour les suivants, Entrée ou clic droit pour finir, Échap pour abandonner.")
		return
	var dernier: Vector2i = _trace[_trace.size() - 1]
	if dernier == _case: return
	if dernier.x != _case.x and dernier.y != _case.y:
		_trace.append(Vector2i(_case.x, dernier.y))
	_trace.append(_case)
	_montrer_apercu()

func _finir_route(garder: bool) -> void:
	if _trace.is_empty(): return
	if garder and _trace.size() >= 2:
		_empiler()
		var k := _ville.ajouter_route(GENRES_ROUTE[_genre_route], _trace, "Rue %d" % (_ville.routes.size() + 1))
		if k >= 0:
			var cases := Ville2.cases_de_route(_ville.routes[k])
			# Un lot sous la nouvelle rue est ôté : la rue a la priorité, on
			# le dit.
			var otes := _oter_lots_sur(cases)
			_rebatir(cases)
			_dire("Route tracée (%d cases%s)." % [cases.size(), ", %d lot(s) ôté(s)" % otes if otes > 0 else ""])
	_trace.clear()
	_montrer_apercu()

func _oter_lots_sur(cases: Array) -> int:
	var pris: Dictionary = {}
	for c in cases: pris[c] = true
	var restants: Array = []
	var otes := 0
	for l in _ville.lots:
		var dedans := false
		for c in Ville2.cases_du_lot(l):
			if pris.has(c): dedans = true
		if dedans: otes += 1
		else: restants.append(l)
	_ville.lots = restants
	return otes

## ⚠ UN LOT EST TOUJOURS UN CHEMIN. Un raccourci de la palette (« lampadaire »)
## n'a de sens que pour un OBJET, qui sait sa hauteur voulue ; posé comme lot,
## il partait en `res://modeles/kenney/lampadaire.glb` — un fichier qui
## n'existe pas. On le ramène donc à son modèle.
func _modele_lot() -> String:
	if _liste.is_empty(): return ""
	var m := _liste[clampi(_lot_choisi, 0, _liste.size() - 1)]
	return m if m.begins_with("res://") else _chemin_de(m)

## Le coin du lot fantôme, en demi-cases, centré sous la souris.
func _coin_lot(m: String) -> Vector2i:
	var e := KitVille2.emprise_tournee(m, _quarts)
	var hx := roundi(_point.x / DEMI - float(e.x) * 0.5)
	var hy := roundi(_point.z / DEMI - float(e.y) * 0.5)
	return Vector2i(hx, hy)

func _lot_possible(m: String, coin: Vector2i) -> bool:
	if m == "": return false
	if _libre != null and _libre.button_pressed: return true
	# ⚠⚠ UN BÂTIMENT EN L'AIR NON PLUS NE POSE PAS SUR LE SOL.
	# J'avais corrigé ça pour l'outil OBJET et cru l'affaire close ; le client
	# travaillait avec l'outil BÂTIMENT — les pièces de route s'y posent comme
	# des lots — et se faisait toujours refuser sa dalle à deux cases de haut,
	# Hauteur réglée et Chevauchement coché (capture du 16/09). Un lot n'avait
	# tout simplement AUCUNE altitude : ni le refus ni le rendu ne savaient qu'un
	# bâtiment puisse ne pas toucher terre.
	if absf(_decalage) > 0.01:
		var eh := KitVille2.emprise_tournee(m, _quarts)
		var rh := Rect2i(coin, eh)
		return rh.position.x >= 0 and rh.position.y >= 0 \
			and rh.end.x <= _ville.taille.x * 2 and rh.end.y <= _ville.taille.y * 2
	var e := KitVille2.emprise_tournee(m, _quarts)
	var essai := {"x": coin.x, "y": coin.y, "w": e.x, "h": e.y}
	for c in Ville2.cases_du_lot(essai):
		if not _ville.terre(c) or _ville.carte.route(c) or _ville.carte.case_prise(c):
			return false
	# Pas deux lots l'un dans l'autre : les rectangles en demi-cases.
	var r := Rect2i(coin, e)
	for l in _ville.lots:
		if r.intersects(Rect2i(int(l["x"]), int(l["y"]), int(l["w"]), int(l["h"]))):
			return false
	return true

func _poser_lot() -> void:
	var m := _modele_lot()
	var coin := _coin_lot(m)
	if not _lot_possible(m, coin):
		_dire("Impossible ici : une rue, l'eau ou un autre bâtiment.")
		return
	_empiler()
	var e := KitVille2.emprise_tournee(m, _quarts)
	var k := _ville.ajouter_lot(m, coin.x, coin.y, e.x, e.y, _quarts, "editeur")
	if absf(_decalage) > 0.01:
		var c: Vector2i = Ville2.cases_du_lot(_ville.lots[k])[0]
		_ville.lots[k]["y_abs"] = TerrainV2.hauteur_en(_ville,
			(float(c.x) + 0.5) * CASE, (float(c.y) + 0.5) * CASE) + _decalage
	_rebatir(Ville2.cases_du_lot(_ville.lots[k]))
	_noter_recent(m)
	_dire("Posé : %s (%d x %d demi-cases)%s." % [m, e.x, e.y,
		"" if absf(_decalage) < 0.01 else " à %.2f case de haut" % (_decalage / CASE)])

func _modele_objet() -> String:
	if _liste.is_empty(): return ""
	return _liste[clampi(_objet_choisi, 0, _liste.size() - 1)]

func _objet_possible(m: String, c: Vector2i) -> bool:
	if m == "": return false
	if _libre != null and _libre.button_pressed: return true
	# ⚠ UN OBJET EN L'AIR NE POSE PAS SUR LE SOL, DONC LE SOL N'A PAS SON MOT.
	# Le refus « une rue, l'eau ou un bâtiment » interrogeait la case même quand
	# la hauteur demandée mettait la pièce à deux cases au-dessus : impossible de
	# suspendre une enseigne au-dessus d'une rue, une passerelle entre deux
	# toits, un lampadaire sur un quai. Dès que la hauteur n'est pas nulle, la
	# seule condition qui reste est d'être dans la carte.
	if absf(_decalage) > 0.01: return _ville.dedans(c)
	if not _ville.terre(c): return false
	if _ville.carte.route(c) and not m.begins_with("voitures/"): return false
	if _ville.lot_sur(c) >= 0: return false
	return true

func _poser_objet() -> void:
	var m := _modele_objet()
	if not _objet_possible(m, _case):
		_dire("Impossible ici : une rue, l'eau ou un bâtiment. Règle la Hauteur pour poser au-dessus.")
		return
	_empiler()
	var o := {"m": m, "x": _aimanter(_point.x), "z": _aimanter(_point.z),
		"r": PI * 0.5 * float(_quarts), "h": 0.0}
	if absf(_decalage) > 0.01:
		o["y_abs"] = TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"])) + _decalage
	_ville.objets.append(o)
	_rebatir([_case])
	_noter_recent(m)
	_dire("Posé : %s%s." % [_nom_lisible(m), "" if absf(_decalage) < 0.01 else " (+%.1f)" % _decalage])

func _sculpter(monte: bool) -> void:
	_empiler()
	var touchees: Array = []
	for dj in range(-_rayon_terrain, _rayon_terrain + 1):
		for di in range(-_rayon_terrain, _rayon_terrain + 1):
			if di * di + dj * dj > _rayon_terrain * _rayon_terrain: continue
			var c := _case + Vector2i(di, dj)
			if not _ville.dedans(c) or not _ville.terre(c): continue
			var y := _ville.sol(c) + (PALIER if monte else -PALIER)
			_ville.poser_terre(c, clampf(y, 0.0, 12.0 * PALIER))
			touchees.append(c)
	_rebatir(touchees)
	_dire("Terrain : palier %d au centre." % _ville.palier(_case))

func _peindre_eau(eau: bool) -> void:
	_empiler()
	var touchees: Array = []
	for dj in range(-_rayon_terrain, _rayon_terrain + 1):
		for di in range(-_rayon_terrain, _rayon_terrain + 1):
			if di * di + dj * dj > _rayon_terrain * _rayon_terrain: continue
			var c := _case + Vector2i(di, dj)
			if not _ville.dedans(c): continue
			if eau: _ville.poser_eau(c)
			else: _ville.poser_terre(c, _ville.sol(c))
			touchees.append(c)
	if eau:
		_oter_lots_sur(touchees)
	_rebatir(touchees)

## L'OUTIL SOL : la matière, au pinceau, avec le rayon du terrain. Le terrain
## continu se rebâtit sur les cases touchées, comme après un coup de pioche.
func _peindre_sol() -> void:
	var m: int = int((MATIERES[clampi(_matiere_choisie, 0, MATIERES.size() - 1)] as Array)[1])
	_empiler()
	var touchees: Array = []
	for dj in range(-_rayon_terrain, _rayon_terrain + 1):
		for di in range(-_rayon_terrain, _rayon_terrain + 1):
			if di * di + dj * dj > _rayon_terrain * _rayon_terrain: continue
			var c := _case + Vector2i(di, dj)
			if not _ville.dedans(c) or not _ville.terre(c): continue
			_ville.poser_matiere(c, m)
			touchees.append(c)
	_rebatir(touchees)
	_dire("Sol : %s sur %d cases." % [String((MATIERES[_matiere_choisie] as Array)[0]), touchees.size()])

## Une pastille de couleur pour la liste des matières.
func _pastille_de_couleur(teinte: Color) -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 24:
		for x in 24:
			if (x - 11.5) * (x - 11.5) + (y - 11.5) * (y - 11.5) <= 100.0:
				img.set_pixel(x, y, teinte)
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ la sélection

## ⚠ LE RAYON DE PIOCHE SUIT LA TAILLE DU MODÈLE. Six unités fixes, c'était
## moins d'un tiers de conteneur : il fallait viser le nombril de l'objet pour
## l'attraper, et le client a conclu que la sélection ne marchait pas. On prend
## maintenant la demi-emprise réelle du modèle, plus deux unités de tolérance.
func _rayon_pioche(o: Dictionary) -> float:
	var large := float(o.get("w", 0.0))
	var profond := float(o.get("d", 0.0))
	if large <= 0.0 or profond <= 0.0:
		# `taille()` répond en CASES, la ville compte en unités.
		var t := KitVille2.taille(String(o["m"])) * CASE
		large = t.x
		profond = t.z
	return clampf(maxf(large, profond) * 0.5 + 2.0, 4.0, 60.0)

## ⚠ TROIS PASSES, DANS CET ORDRE. Le doigt sur un objet l'emporte ; sinon le
## bâtiment sous le curseur ; sinon seulement un objet voisin, à la tolérance.
## Sans cette hiérarchie, une voiture garée devant un immeuble prenait le clic
## qui visait l'immeuble.
func _objet_pique(large: bool) -> int:
	var meilleur := -1
	var meilleure := INF
	for k in _ville.objets.size():
		var o: Dictionary = _ville.objets[k]
		var r := _rayon_pioche(o)
		if not large: r = maxf(r - 2.0, 2.0) * 0.6
		var d := Vector2(float(o["x"]), float(o["z"])).distance_to(Vector2(_point.x, _point.z))
		if d <= r and d < meilleure:
			meilleure = d
			meilleur = k
	return meilleur

func _selectionner() -> void:
	_selection = {}
	var meilleur := _objet_pique(false)
	if meilleur < 0 and _ville.lot_sur(_case) < 0:
		meilleur = _objet_pique(true)
	if meilleur >= 0:
		_selection = {"genre": "objet", "k": meilleur}
		_dire("Objet : %s — glisser déplace, Suppr efface, A/E tourne." % _nom_lisible(String(_ville.objets[meilleur]["m"])))
	else:
		var l := _ville.lot_sur(_case)
		if l >= 0:
			_selection = {"genre": "lot", "k": l}
			_dire("Bâtiment : %s — glisser déplace, Suppr efface, A/E tourne." % _nom_lisible(String(_ville.lots[l]["m"])))
		elif _ville.carte.route(_case):
			for k in _ville.routes.size():
				if _case in Ville2.cases_de_route(_ville.routes[k]):
					_selection = {"genre": "route", "k": k, "c": _case}
					var r: Dictionary = _ville.routes[k]
					_dire("Route : %s « %s » (%d points) — Suppr efface." % [r["genre"], r["nom"], (r["points"] as Array).size()])
					break
	_montrer_cadre()

## LE DÉPLACEMENT À LA SOURIS. Un clic sélectionne ; si la souris bouge
## ensuite de plus de trois unités avant le relâchement, la sélection SUIT le
## curseur. Rien n'est rebâti pendant le glissé — seul le cadre suit, et la
## ville se refait une fois, au relâchement : sinon chaque pixel de souris
## reconstruisait un morceau de seize cases.
func _armer_le_glisse() -> void:
	_tire = false
	_tire_bouge = false
	if _outil != OUTIL_SELECTION or _selection.is_empty(): return
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			_tire_ref = Vector2(float(o["x"]), float(o["z"]))
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			_tire_ref = Vector2(float(l["x"]), float(l["y"]))
		_:
			return
	_tire_depart = _point
	_tire = true

func _glisser() -> void:
	if not _tire: return
	var d := Vector2(_point.x - _tire_depart.x, _point.z - _tire_depart.z)
	if not _tire_bouge and d.length() < 3.0: return
	# ⚠ ON EMPILE AU PREMIER MOUVEMENT, pas au clic : sinon chaque clic de
	# sélection laissait un « Annuler » qui ne défaisait rien. À cet instant
	# la sélection n'a pas encore bougé — c'est le bon état à garder.
	if not _tire_bouge: _empiler()
	_tire_bouge = true
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			o["x"] = _aimanter(_tire_ref.x + d.x)
			o["z"] = _aimanter(_tire_ref.y + d.y)
			_dire("Déplacement : x %.2f  z %.2f" % [float(o["x"]), float(o["z"])])
		"lot":
			# Un bâtiment se pose sur la trame : il se déplace en DEMI-CASES.
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			l["x"] = int(_tire_ref.x) + roundi(d.x / DEMI)
			l["y"] = int(_tire_ref.y) + roundi(d.y / DEMI)
			_dire("Déplacement : demi-case %d, %d" % [int(l["x"]), int(l["y"])])
	_montrer_cadre()
	_suivre_le_glisse()

## ⚠ LE MODÈLE SUIT LA SOURIS, PAS SEULEMENT LE CADRE. Jusqu'ici seul le cadre
## de sélection bougeait pendant le glissé : on lâchait, on regardait, on
## recommençait. « J'aimerais le voir se déplacer avant que je relâche, pour
## une meilleure précision et moins de tests de placement » (client, 12/09) —
## et il a raison, ajuster à l'aveugle coûte trois essais là où un suffi.
##
## ⚠⚠ MAIS PAS À CHAQUE PIXEL DE SOURIS. Refaire le morceau à chaque
## `mouse_motion`, c'est rebâtir quelques centaines de maillages soixante fois
## par seconde : l'éditeur devient une diapositive et le glissé saccade — donc
## imprécis, exactement ce qu'on cherchait à corriger. On refait au plus tous
## les `MS_SUIVI` millièmes, ce qui donne environ vingt-cinq images par seconde
## de retour : l'œil suit, la machine tient.
## ⚠ SOIXANTE IMAGES PAR SECONDE, PAS VINGT-CINQ. À quarante millisecondes le
## glissé avançait par à-coups visibles ; à seize, la pièce colle à la souris.
## C'est le coût d'un morceau rebâti par image, et il se paie sans broncher.
const MS_SUIVI := 16

var _dernier_suivi := 0

func _suivre_le_glisse() -> void:
	var t := Time.get_ticks_msec()
	if t - _dernier_suivi < MS_SUIVI: return
	_dernier_suivi = t
	_rebatir(_cases_du_glisse())

## Les cases à refaire pendant un glissé : celle d'où l'on vient et celle où
## l'on est. Sans la première, l'objet reste dessiné à son ancienne place.
func _cases_du_glisse() -> Array:
	match String(_selection.get("genre", "")):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			return [_case_de(_tire_ref.x, _tire_ref.y),
				_case_de(float(o["x"]), float(o["z"]))]
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			var cases := Ville2.cases_du_lot(l)
			for c in Ville2.cases_du_lot({"x": int(_tire_ref.x), "y": int(_tire_ref.y),
					"w": int(l["w"]), "h": int(l["h"])}):
				cases.append(c)
			return cases
	return []

func _poser_le_glisse() -> void:
	if not _tire: return
	_tire = false
	if not _tire_bouge: return
	_tire_bouge = false
	var touchees: Array = []
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			# L'objet reprend l'altitude de son nouveau sol, sauf s'il avait
			# été posé à une hauteur voulue (`y_abs`) — un panneau au mur.
			if o.has("y_abs"):
				o["y_abs"] = TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"])) + _decalage
			touchees = [_case_de(_tire_ref.x, _tire_ref.y),
				_case_de(float(o["x"]), float(o["z"]))]
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			touchees = Ville2.cases_du_lot(l)
			for c in Ville2.cases_du_lot({"x": int(_tire_ref.x), "y": int(_tire_ref.y),
					"w": int(l["w"]), "h": int(l["h"])}):
				touchees.append(c)
	_rebatir(touchees)
	_dire("Déplacé. (Ctrl+Z annule)")

## Coupe la route `k` sur la case `c` : le tracé devient deux tracés, l'un
## avant la case, l'autre après. Rend les cases à rebâtir.
##
## ⚠ ON RECONSTRUIT DEPUIS LA LISTE DES CASES, PAS DEPUIS LES SOMMETS. Les
## sommets d'une route sont des points de grille reliés par des coudes ; retirer
## une case au milieu d'un coude ne se dit pas avec des sommets. La liste des
## cases, elle, est exacte : on la coupe, et chaque morceau se redécrit par ses
## changements de direction.
func _couper_la_route(k: int, c: Vector2i) -> Array:
	var route: Dictionary = _ville.routes[k]
	var cases := Ville2.cases_de_route(route)
	var genre := String(route["genre"])
	var nom := String(route.get("nom", ""))
	var niveau := int(route.get("niveau", 0))
	_ville.routes.remove_at(k)
	var morceau: Array = []
	var morceaux: Array = []
	for cc in cases:
		if cc == c:
			if morceau.size() >= 2: morceaux.append(morceau)
			morceau = []
			continue
		morceau.append(cc)
	if morceau.size() >= 2: morceaux.append(morceau)
	for m in morceaux:
		_ville.ajouter_route(genre, _sommets_de(m), nom, niveau)
	return cases

## Les sommets d'une suite de cases : le premier, chaque changement de
## direction, et le dernier.
func _sommets_de(cases: Array) -> Array:
	var points: Array = [cases[0]]
	for i in range(1, cases.size() - 1):
		var avant: Vector2i = cases[i] - cases[i - 1]
		var apres: Vector2i = cases[i + 1] - cases[i]
		if avant != apres: points.append(cases[i])
	points.append(cases[cases.size() - 1])
	return points

func _case_de(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CASE), floori(z / CASE))

func _montrer_cadre() -> void:
	_cadre.visible = false
	if _selection.is_empty(): return
	var r := Rect2()
	var y := 0.0
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			r = Rect2(float(o["x"]) - 4.0, float(o["z"]) - 4.0, 8.0, 8.0)
			y = _ville.sol(Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE)))
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			r = Rect2(float(l["x"]) * DEMI, float(l["y"]) * DEMI, float(l["w"]) * DEMI, float(l["h"]) * DEMI)
			y = _ville.centre_du_lot(l).y
		"route":
			var cases := Ville2.cases_de_route(_ville.routes[int(_selection["k"])])
			var c0: Vector2i = cases[0]
			r = Rect2(float(c0.x) * CASE, float(c0.y) * CASE, CASE, CASE)
			for c in cases:
				r = r.merge(Rect2(float((c as Vector2i).x) * CASE, float((c as Vector2i).y) * CASE, CASE, CASE))
			y = _ville.sol(c0)
	# ⚠ LE CADRE EST UN VOILE, PAS UN COUVERCLE. À pleine opacité il cachait
	# précisément la pièce qu'on est en train de placer : « j'aimerais que le
	# carré jaune dessus soit transparent pour voir mon déplacement » (client,
	# 16/09). Un aplat à quinze pour cent teinte la zone sans rien masquer.
	_cadre.mesh = _rectangle(r, Color(TEINTE_SELECTION, 0.15))
	_cadre.position = Vector3(0, y + 0.9, 0)
	_cadre.visible = true
	_maj_info()

func _supprimer_selection() -> void:
	if not _multi.is_empty():
		_supprimer_multi()
		return
	if _selection.is_empty(): return
	_empiler()
	var touchees: Array = []
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			touchees.append(Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE)))
			_ville.objets.remove_at(int(_selection["k"]))
		"lot":
			touchees = Ville2.cases_du_lot(_ville.lots[int(_selection["k"])])
			_ville.lots.remove_at(int(_selection["k"]))
		"route":
			# ⚠ ON EFFACE UN BOUT DE RUE, PAS LA RUE (demande du client, 12/09 :
			# « quand j'essaye de supprimer un bout de rue ça me sélectionne
			# toute la rue »). La case visée est ôtée du tracé, qui se coupe en
			# deux morceaux de part et d'autre ; effacer le dernier bout efface
			# la rue, ce qui est la seule façon d'en finir avec elle.
			touchees = _couper_la_route(int(_selection["k"]), Vector2i(_selection.get("c", _case)))
	_selection = {}
	_cadre.visible = false
	_rebatir(touchees)
	_dire("Effacé.")

## LA PIPETTE (I). « Le même que celui-là » est le geste le plus fréquent
## quand on garnit une rue : on a un banc sous les yeux, on en veut un
## deuxième, et le retrouver dans un catalogue de mille modèles prend plus
## de temps que de le poser. La pipette reprend le modèle ET l'orientation
## de ce qu'on a sélectionné — ou, sans sélection, de ce qui est sous le
## curseur — et le met en main dans l'outil qui va avec (Bâtiment ou Objet).
## Le catalogue se cale dessus : dans la famille affichée s'il y est, sinon
## dans « tout », la recherche effacée.
func _pipette(sous_le_curseur := false) -> void:
	var genre := ""
	var k := -1
	if not sous_le_curseur and not _selection.is_empty() and String(_selection["genre"]) != "route":
		genre = String(_selection["genre"])
		k = int(_selection["k"])
	else:
		k = _objet_pique(false)
		if k >= 0:
			genre = "objet"
		else:
			k = _ville.lot_sur(_case)
			if k >= 0: genre = "lot"
	if genre == "" or k < 0:
		_dire("Pipette : rien sous le curseur — vise un bâtiment ou un objet, ou sélectionne-le d'abord.")
		return
	var m := ""
	var quarts := 0
	var outil := OUTIL_OBJET
	if genre == "objet":
		var o: Dictionary = _ville.objets[k]
		m = String(o["m"])
		quarts = posmod(roundi(float(o.get("r", 0.0)) / (PI * 0.5)), 4)
	else:
		var l: Dictionary = _ville.lots[k]
		m = String(l["m"])
		quarts = posmod(int(l.get("q", 0)), 4)
		outil = OUTIL_LOT
	_choisir_outil(outil)
	_quarts = quarts
	var rang := _rang_dans_la_liste(m)
	if rang < 0 and _familles != null:
		# Pas dans la famille affichée : on ouvre « tout », sans filtre.
		_recherche.text = ""
		_familles.selected = 2
		_remplir_palette()
		rang = _rang_dans_la_liste(m)
	if rang < 0:
		_dire("Pipette : « %s » n'est pas dans le catalogue." % _nom_lisible(m))
		return
	_palette.select(rang)
	_palette.ensure_current_is_visible()
	_palette_choisie(rang)
	_noter_recent(m)
	_montrer_apercu()
	_dire("Pipette : « %s » en main%s — clique pour en poser un autre." % [_nom_lisible(m),
		(", tourné de %d quart(s)" % quarts) if quarts > 0 else ""])

## Le rang d'un modèle dans la liste affichée du catalogue, −1 s'il n'y est
## pas. On compare par le chemin `res://` : un objet posé depuis un raccourci
## porte le nom du raccourci, un lot du générateur porte le chemin.
func _rang_dans_la_liste(m: String) -> int:
	var cible := _chemin_de(m)
	for i in _liste.size():
		var e := String(_liste[i])
		if e == m: return i
		if cible != "" and _chemin_de(e) == cible: return i
	return -1

## A / E SUR UN LASSO : TOUT LE GROUPE TOURNE D'UN QUART, autour de son
## centre. Un bout de rue garni, copié, collé — puis la rue d'à côté est
## perpendiculaire, et il fallait tout retourner pièce par pièce. Les objets
## tournent en position ET en cap ; les bâtiments changent d'emprise avec
## leur quart et gardent leur centre. Aucune vérification de place : c'est un
## geste, Ctrl+Z le défait.
func _tourner_multi(sens: int) -> void:
	if _multi.is_empty(): return
	_empiler()
	var somme := Vector2.ZERO
	var touchees: Array = []
	for m in _multi:
		var d: Dictionary = m
		if String(d["genre"]) == "objet":
			var o: Dictionary = _ville.objets[int(d["k"])]
			somme += Vector2(float(o["x"]), float(o["z"]))
			touchees.append(_case_de(float(o["x"]), float(o["z"])))
		else:
			var l: Dictionary = _ville.lots[int(d["k"])]
			var c := _ville.centre_du_lot(l)
			somme += Vector2(c.x, c.z)
			touchees.append_array(Ville2.cases_du_lot(l))
	var centre := somme / float(_multi.size())
	# Le centre à la demi-case, pour que les bâtiments retombent sur la trame.
	centre = Vector2(roundf(centre.x / DEMI) * DEMI, roundf(centre.y / DEMI) * DEMI)
	var angle := PI * 0.5 * float(sens)
	for m2 in _multi:
		var d2: Dictionary = m2
		if String(d2["genre"]) == "objet":
			var o2: Dictionary = _ville.objets[int(d2["k"])]
			var p := (Vector2(float(o2["x"]), float(o2["z"])) - centre).rotated(angle) + centre
			o2["x"] = p.x
			o2["z"] = p.y
			o2["r"] = float(o2.get("r", 0.0)) + angle
			touchees.append(_case_de(p.x, p.y))
		else:
			var l2: Dictionary = _ville.lots[int(d2["k"])]
			var c2 := _ville.centre_du_lot(l2)
			var pc := (Vector2(c2.x, c2.z) - centre).rotated(angle) + centre
			var q := posmod(int(l2["q"]) + sens, 4)
			var e := KitVille2.emprise_tournee(String(l2["m"]), q)
			l2["q"] = q
			l2["w"] = e.x
			l2["h"] = e.y
			l2["x"] = roundi(pc.x / DEMI - float(e.x) * 0.5)
			l2["y"] = roundi(pc.y / DEMI - float(e.y) * 0.5)
			touchees.append_array(Ville2.cases_du_lot(l2))
	_rebatir(touchees)
	# Le cadre suit le groupe.
	var r := Rect2(centre, Vector2.ZERO)
	for m3 in _multi:
		var d3: Dictionary = m3
		if String(d3["genre"]) == "objet":
			var o3: Dictionary = _ville.objets[int(d3["k"])]
			r = r.expand(Vector2(float(o3["x"]), float(o3["z"])))
		else:
			var c3 := _ville.centre_du_lot(_ville.lots[int(d3["k"])])
			r = r.expand(Vector2(c3.x, c3.z))
	_cadre.mesh = _rectangle(r.grow(DEMI * 0.5), Color(TEINTE_SELECTION, 0.15))
	_cadre.visible = true
	_dire("Groupe tourné d'un quart (%d élément(s)). Ctrl+Z annule." % _multi.size())

func _tourner_selection(sens: int) -> void:
	if _selection.is_empty(): return
	_empiler()
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			o["r"] = float(o.get("r", 0.0)) + PI * 0.5 * float(sens)
			_rebatir([Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE))])
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			var avant := Ville2.cases_du_lot(l)
			var q := posmod(int(l["q"]) + sens, 4)
			var e := KitVille2.emprise_tournee(String(l["m"]), q)
			# On tourne autour du centre : le coin bouge pour garder le centre.
			var cx := float(l["x"]) + float(l["w"]) * 0.5
			var cy := float(l["y"]) + float(l["h"]) * 0.5
			l["q"] = q
			l["x"] = roundi(cx - float(e.x) * 0.5)
			l["y"] = roundi(cy - float(e.y) * 0.5)
			l["w"] = e.x
			l["h"] = e.y
			_rebatir(avant + Ville2.cases_du_lot(l))
	_montrer_cadre()

# ------------------------------------------------------------------ l'aperçu

func _montrer_apercu() -> void:
	for n in _apercu.get_children():
		n.queue_free()
	if not _ville.dedans(_case): return
	var y := _ville.sol(_case) + 0.8
	match _outil:
		OUTIL_ROUTE:
			var cases: Array = []
			if not _trace.is_empty():
				var essai := {"points": _trace.duplicate()}
				var dernier: Vector2i = _trace[_trace.size() - 1]
				if dernier.x != _case.x and dernier.y != _case.y:
					(essai["points"] as Array).append(Vector2i(_case.x, dernier.y))
				(essai["points"] as Array).append(_case)
				cases = Ville2.cases_de_route(essai)
			else:
				cases = [_case]
			for c in cases:
				_dalle(Rect2(float((c as Vector2i).x) * CASE, float((c as Vector2i).y) * CASE, CASE, CASE),
					TEINTE_ROUTE if _ville.terre(c) else TEINTE_NON, y)
		OUTIL_LOT:
			var m := _modele_lot()
			var coin := _coin_lot(m)
			var e := KitVille2.emprise_tournee(m, _quarts)
			_dalle(Rect2(float(coin.x) * DEMI, float(coin.y) * DEMI, float(e.x) * DEMI, float(e.y) * DEMI),
				TEINTE_OK if _lot_possible(m, coin) else TEINTE_NON, y)
		OUTIL_OBJET:
			_dalle(Rect2(_point.x - 3.0, _point.z - 3.0, 6.0, 6.0),
				TEINTE_OK if _objet_possible(_modele_objet(), _case) else TEINTE_NON, y)
			if _serie_depart.x > -1e8:
				# La rangée à venir : un point tous les pas, du départ au curseur.
				var vec := _point - _serie_depart
				vec.y = 0.0
				var lg := vec.length()
				if lg > 0.1:
					var pas := _pas_de_serie()
					for i in int(floor(lg / pas)) + 1:
						var pt := _serie_depart + vec / lg * (pas * float(i))
						_dalle(Rect2(pt.x - 2.0, pt.z - 2.0, 4.0, 4.0), Atelier.ACCENT, y)
		OUTIL_TERRAIN, OUTIL_EAU, OUTIL_SOL:
			for dj in range(-_rayon_terrain, _rayon_terrain + 1):
				for di in range(-_rayon_terrain, _rayon_terrain + 1):
					if di * di + dj * dj > _rayon_terrain * _rayon_terrain: continue
					var c := _case + Vector2i(di, dj)
					if _ville.dedans(c):
						_dalle(Rect2(float(c.x) * CASE, float(c.y) * CASE, CASE, CASE), TEINTE_OK, _ville.sol(c) + 0.8)
		_:
			# Le survol : la case sous le curseur, en cyan discret, pour que l'œil
			# sache où le clic va tomber avant de cliquer.
			_dalle(Rect2(float(_case.x) * CASE, float(_case.y) * CASE, CASE, CASE),
				Color(Atelier.CYAN, 0.28), y)

func _dalle(r: Rect2, teinte: Color, y: float) -> void:
	var n := MeshInstance3D.new()
	n.mesh = _rectangle(r, Color(teinte, 0.45))
	n.position = Vector3(0, y, 0)
	_apercu.add_child(n)

## ⭐⭐⭐ LE SENS DE CIRCULATION, UNE FLÈCHE PAR VOIE.
##
## « Voici comment on pourrait faire en sorte que les choses soient logiques, en
## mettant avec une flèche les sens de direction » (client, 16/09, deux schémas à
## l'appui). C'est d'abord un outil de CONTRÔLE : une carte où deux flèches se
## font face au milieu d'une rue, ou bien où tout un quartier tourne dans le même
## sens, se voit d'un coup d'œil — alors que la même faute ne se lit pas du tout
## sur le bitume. Et c'est ensuite la base du trafic : une voiture a besoin de
## savoir de quel côté rouler, pas seulement où est la route.
##
## ⚠ LA RÈGLE TIENT EN UNE PHRASE : ON ROULE À DROITE. Sur une rue est-ouest,
## celui qui va vers l'EST tient le côté SUD ; celui qui va vers l'OUEST tient le
## côté NORD. Les deux flèches se déduisent donc de l'AXE de la rue et de rien
## d'autre — pas d'un tirage, pas d'une table à maintenir.
##
## ⚠⚠ ET ON NE FLÉCHE PAS UN CARREFOUR. Une case dont les quatre côtés sont de la
## chaussée n'a pas d'axe : y poser deux flèches, c'est affirmer un sens là où
## justement tout se croise. On la laisse nue, et le regard suit les branches.
const C_SENS_ALLER := Color("#e5393c")
const C_SENS_RETOUR := Color("#2f7fd6")
const HAUT_FLECHE := 0.6

func _montrer_les_sens() -> void:
	for n in _fleches.get_children():
		n.queue_free()
	_fleches.visible = _sens != null and _sens.button_pressed
	if not _fleches.visible: return
	var posees := 0
	for j in _ville.taille.y:
		for i in _ville.taille.x:
			var c := Vector2i(i, j)
			if not _ville.carte.route(c): continue
			var axe := _axe_de_la_rue(c)
			if axe == Vector2i.ZERO: continue
			var y := _ville.sol(c) + HAUT_FLECHE
			var centre := Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE)
			# Le côté droit de chaque sens : on roule à droite.
			var u := Vector2(float(axe.x), float(axe.y))
			var droite := u.orthogonal()
			for s0 in [1.0, -1.0]:
				var s: float = s0
				var v: Vector2 = u * s
				var d: Vector2 = droite * s
				_une_fleche(centre + Vector3(d.x, 0, d.y) * (CASE * 0.22),
					v, C_SENS_ALLER if s > 0.0 else C_SENS_RETOUR)
			posees += 1
	_dire("Sens de circulation : %d cases fléchées." % posees)

## L'axe d'une rue : la direction dans laquelle elle continue. `ZERO` si la case
## est un carrefour (quatre branches) ou un cul-de-sac isolé.
func _axe_de_la_rue(c: Vector2i) -> Vector2i:
	var m := _ville.carte.masque(c)
	var selon_x := (m & 2) != 0 or (m & 8) != 0
	var selon_y := (m & 1) != 0 or (m & 4) != 0
	if selon_x and selon_y: return Vector2i.ZERO
	if selon_x: return Vector2i(1, 0)
	if selon_y: return Vector2i(0, 1)
	return Vector2i.ZERO

## Une flèche plate : un fût et une pointe, posés à plat sur la chaussée.
func _une_fleche(ou: Vector3, sens: Vector2, teinte: Color) -> void:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = teinte
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var av := Vector3(sens.x, 0, sens.y).normalized()
	var co := av.cross(Vector3.UP).normalized()
	var l := CASE * 0.34
	var e := CASE * 0.055
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	# le fût
	var a := -av * l * 0.5
	var b := av * l * 0.1
	for v in [a - co * e, b - co * e, b + co * e, a - co * e, b + co * e, a + co * e]:
		im.surface_add_vertex(v)
	# la pointe
	for v in [b - co * e * 2.6, av * l * 0.5, b + co * e * 2.6]:
		im.surface_add_vertex(v)
	im.surface_end()
	var n := MeshInstance3D.new()
	n.mesh = im
	n.position = ou
	_fleches.add_child(n)

func _rectangle(r: Rect2, teinte: Color) -> Mesh:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = teinte
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var a := Vector3(r.position.x, 0, r.position.y)
	var b := Vector3(r.end.x, 0, r.position.y)
	var c := Vector3(r.end.x, 0, r.end.y)
	var d := Vector3(r.position.x, 0, r.end.y)
	for v in [a, b, c, a, c, d]:
		im.surface_add_vertex(v)
	im.surface_end()
	return im

# ------------------------------------------------------------------ rebâtir, annuler, enregistrer

func _rebatir(cases: Array) -> void:
	_morceaux.refaire(cases)
	_montrer_apercu()
	_maj_compteur()

func _empiler() -> void:
	# La pastille « non enregistré » de la barre du haut suit chaque geste.
	call_deferred("_maj_compteur")
	_pile.append(_ville.vers_json())
	if _pile.size() > 40: _pile.pop_front()
	_refaire.clear()

func _annuler() -> void:
	if _pile.is_empty():
		_dire("Rien à annuler.")
		return
	_refaire.append(_ville.vers_json())
	_recharger(_pile.pop_back())
	_maj_compteur()
	_dire("Annulé.")

func _refaire_geste() -> void:
	if _refaire.is_empty(): return
	_pile.append(_ville.vers_json())
	_recharger(_refaire.pop_back())
	_dire("Refait.")

func _recharger(json: String) -> void:
	_ville = Ville2.depuis_json(json)
	_selection = {}
	_cadre.visible = false
	_morceaux.regler(_ville, 99)
	_morceaux.suivre(Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5))
	_poser_grille()

## ⚠ LA RÈGLE VIT DANS `Ville2`, PAS ICI. Elle doit être la même pour celui qui
## écrit et pour tous ceux qui relisent (l'éditeur, le jeu, la photo) : quand
## elle était écrite des deux côtés, les deux côtés ont divergé et les
## enregistrements ne revenaient jamais.
## ⚠ LA LISTE DIT CE QUI EST À MOI ET CE QUI EST LIVRÉ. Sans marque, rien à
## l'écran ne distingue une carte du paquet d'une carte qu'on a enregistrée
## soi-même : on change de carte, on revient, on retrouve la sienne — et on ne
## le SAIT pas, donc on croit l'avoir perdue (« je n'ai pas la possibilité de
## revoir la save après un changement de map », client, 13/09).
##
## Une carte modifiée porte donc un point, et le bouton « Rétablir » remet la
## version livrée. C'est la moitié manquante de l'enregistrement : pouvoir
## revenir en arrière est ce qui rend la sauvegarde sûre.
const MARQUE_MODIFIEE := "  ●"

func _remplir_les_cartes() -> void:
	var choisi := _chemin.get_file().get_basename()
	_cartes.clear()
	var noms := _cartes_du_dossier()
	# ⚠ LA CARTE OUVERTE EST DANS LA LISTE, MÊME PAS ENCORE ENREGISTRÉE. Une
	# fenêtre du pays fraîchement bâtie n'existe dans aucun dossier : la liste
	# affichait alors la PREMIÈRE carte venue (« temoin-banlieue ») pendant
	# qu'on regardait les Aurones, et le premier clic dans la liste rechargeait
	# une autre ville.
	if not noms.has(choisi):
		noms.append(choisi)
		noms.sort()
	for k in noms.size():
		var nom := String(noms[k])
		var modifiee := Ville2.carte_modifiee("res://cartes/%s.json" % nom)
		_cartes.add_item(nom + (MARQUE_MODIFIEE if modifiee else ""))
		_cartes.set_item_metadata(k, nom)
		if nom == choisi: _cartes.select(k)

## Le nom de carte derrière l'entrée `k`, sans la marque.
func _nom_de_carte(k: int) -> String:
	var m = _cartes.get_item_metadata(k)
	return String(m) if m != null else _cartes.get_item_text(k).replace(MARQUE_MODIFIEE, "")

## Remet la carte LIVRÉE à la place de la version enregistrée.
func _retablir() -> void:
	if not Ville2.carte_modifiee(_chemin):
		_dire("« %s » est déjà la carte livrée — rien à rétablir." % _chemin.get_file())
		return
	# Le geste est annulable : on empile l'état courant avant d'écraser.
	_pile.append(_ville.vers_json())
	Ville2.oublier_les_modifications(_chemin)
	# ⚠⚠ UNE FENÊTRE DU PAYS N'A PAS DE CARTE LIVRÉE À RÉTABLIR : elle n'existe
	# que dans le plan. `charger` sur son nom aurait rendu une ville VIDE, et
	# Rétablir aurait effacé le quartier au lieu de le remettre d'aplomb. On la
	# REFABRIQUE depuis le plan, ce qui est exactement ce que « la version
	# livrée » veut dire pour elle.
	var v: Ville2 = null
	if _chemin.get_file().begins_with("pays-"):
		v = _la_fenetre_du_pays("%d,%d" % [_centre_pays.x, _centre_pays.y], _cote_pays)
	else:
		v = Ville2.charger(_chemin)
	_recharger(v.vers_json())
	_dernier_enregistre = _ville.vers_json()
	_remplir_les_cartes()
	_tout_voir()
	_maj_compteur()
	_dire("Carte livrée rétablie : %s — ta version enregistrée est effacée." % _chemin.get_file())

## ⚠ LE TEXTE DE LA VILLE AU DERNIER ENREGISTREMENT (ou au dernier chargement).
## Il sert à une seule chose, et elle compte : savoir s'il y a du travail non
## enregistré AVANT de changer de carte. Changer de carte recharge tout ; sans
## ce garde-fou, un quart d'heure de pose part sans un mot.
var _dernier_enregistre := ""

func _des_choses_non_enregistrees() -> bool:
	return _dernier_enregistre != "" and _ville.vers_json() != _dernier_enregistre

func _chemin_d_enregistrement() -> String:
	return Ville2.chemin_d_ecriture(_chemin)

func _enregistrer() -> void:
	var ou := _chemin_d_enregistrement()
	if _ville.enregistrer(ou):
		# On redit le nom de la carte : c'est lui qu'on rechargera, et c'est
		# la version enregistrée qui gagnera sur celle livrée.
		_dernier_enregistre = _ville.vers_json()
		_remplir_les_cartes()
		_maj_compteur()
		_dire("Enregistré : %s ● — %d lots, %d objets. C'est cette version-là qui reviendra." % [
			_chemin.get_file(), _ville.lots.size(), _ville.objets.size()])
	else:
		_dire("Impossible d'écrire " + ou)

## ⭐⭐⭐ EXPORTER — sortir une carte du navigateur pour de bon.
##
## ⚠ CE QUI EST ENREGISTRÉ N'EST PAS CONSERVÉ. Au navigateur, `Ctrl+S` écrit
## dans `user://`, c'est-à-dire dans le STOCKAGE DU NAVIGATEUR : ça survit à un
## rechargement de page, pas à un vidage du cache, pas à un changement de
## machine, et ça n'atteint jamais le dépôt. Une fenêtre du pays retouchée
## pendant une heure vivait donc dans un endroit dont le client ne peut rien
## sortir — ce qui est une façon coûteuse de perdre du travail sans le savoir.
##
## Exporter télécharge le JSON de la carte courante. C'est ce fichier-là qu'on
## dépose dans `cartes/` pour que la retouche devienne définitive et parte avec
## le paquet.
##
## ⚠ AU BUREAU IL N'Y A PAS DE TÉLÉCHARGEMENT : on écrit directement dans le
## dossier des cartes du projet, ce qui revient au même et évite un aller-retour
## par le dossier des téléchargements.
func _exporter() -> void:
	var nom := _chemin.get_file()
	var texte := _ville.vers_json()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(texte.to_utf8_buffer(), nom, "application/json")
		_dire("Exporté : %s — dépose-le dans cartes/ du dépôt pour le rendre définitif." % nom)
		return
	var ou := "res://cartes/" + nom
	var f := FileAccess.open(ou, FileAccess.WRITE)
	if f == null:
		_dire("Impossible d'écrire " + ou)
		return
	f.store_string(texte)
	f.close()
	_dire("Écrit dans le projet : %s — %d lots, %d objets." % [ou, _ville.lots.size(),
		_ville.objets.size()])

func _photographier() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ou := _photo_sortie if _photo_sortie != "" else "user://editeur_v2.png"
	DirAccess.make_dir_recursive_absolute(ou.get_base_dir())
	get_viewport().get_texture().get_image().save_png(ou)
	print("photo ", ou)
	_dire("Photo : " + ou)
	if _photo_sortie != "":
		get_tree().quit()
