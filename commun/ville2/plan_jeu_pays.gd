extends PlanV2
## ⭐⭐⭐ LE PAYS, VU PAR LE JEU — le dernier maillon.
##
## `FenetresPays` sait BÂTIR l'archipel autour du joueur, fenêtre par fenêtre.
## Mais le jeu ne parle jamais à une `Ville2` : il parle à `PlanVille`, et
## c'est `PlanV2` qui répond depuis UNE ville. Il manquait la pièce qui répond
## depuis NEUF — sans quoi l'archipel se voyait sans se jouer.
##
## ⚠ LA RUSE, ET POURQUOI ELLE EST SÛRE.
## `PlanV2` ne garde de la ville que deux poignées : `ville` et `carte`. Elles
## sont lues À CHAQUE APPEL, jamais recopiées. On peut donc, avant de répondre
## à une question, POINTER ces deux poignées sur la fenêtre qui porte la case
## demandée, et régler `decalage` sur son coin — le reste de `PlanV2` marche
## alors mot pour mot, y compris ce que `PlanVille` bâtit par-dessus
## (`degager`, `point_de_rue`, `dans_un_batiment`), qui ne lit que `tuile()`.
## C'est tout le travail de `_viser()`, et c'est le seul endroit du fichier où
## quelque chose de neuf se passe. Le banc `outils/banc_plan_v2.gd` tient le
## filet : tant que `decalage` vaut zéro, les neuf témoins ne bougent pas d'un
## caractère.
##
## ⚠ CE QUI SE PASSE QUAND LA FENÊTRE N'EST PAS ENCORE LÀ.
## Une fenêtre coûte des secondes et se fabrique dans un fil. Tant qu'elle
## n'est pas prête, on répond « mer » : pas de sol, pas de rue, pas de lot.
## C'est la seule réponse honnête — et c'est aussi la plus sûre, puisque le
## jeu sait déjà ne pas poser un joueur dans l'eau. Une seule exception, le
## DÉPART : là on ATTEND la fenêtre (`exiger`), parce qu'un joueur posé dans
## la mer au premier dixième de seconde ne se rattrape pas.

const PLAN := preload("res://commun/ville2/plan_pays.gd")

var fenetres: FenetresPays
var plan_du_pays: Dictionary = {}

## La fenêtre actuellement visée, et celles dont on a déjà rangé les objets et
## les lieux (on ne les range qu'une fois : les deux registres sont ABSOLUS).
var _cle := Vector2i(999999, 999999)
var _vues: Dictionary = {}

## ⚠ Le cache de tuiles de `PlanV2` est indexé en absolu : il reste juste d'une
## fenêtre à l'autre, mais il grossit sans fin sur mille cases de côté. On le
## vide au-delà de ce seuil — une tuile se recalcule en quelques microsecondes.
const TUILES_EN_CACHE := 400000

func _init(code_de_manche: String, f: FenetresPays, plan: Dictionary) -> void:
	# ⚠ Le chemin vide dit à `PlanV2` de ne charger AUCUNE ville : ici, c'est
	# `_viser()` qui en pose une, et elle change.
	super(code_de_manche, "")
	fenetres = f
	plan_du_pays = plan
	cases_x = PLAN.TAILLE.x
	cases_y = PLAN.TAILLE.y

# ------------------------------------------------------------ la visée

## ⭐ POINTER LES POIGNÉES SUR LA FENÊTRE QUI PORTE CETTE CASE DU MONDE.
## Rend `false` si elle n'est pas (encore) fabriquée : l'appelant répond mer.
func _viser(c: Vector2i, exiger := false) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cases_x or c.y >= cases_y:
		return false
	var cle := FenetresPays.cle_de_case(c)
	if cle == _cle and ville != null:
		return true
	var v: Ville2 = fenetres.exiger(c) if exiger else fenetres.ville_de_case(c)
	if v == null:
		return false
	_cle = cle
	ville = v
	carte = v.carte
	decalage = cle * FenetresPays.COTE
	# ⚠ LES OBJETS ET LES LIEUX SE RANGENT UNE FOIS PAR FENÊTRE, ET EN ABSOLU.
	# `_classer_obstacles` et `_ranger_les_lieux` lisent `decalage` : il faut
	# donc qu'il soit déjà posé quand on les appelle — d'où l'ordre ici.
	if not _vues.has(cle):
		_vues[cle] = true
		_classer_obstacles()
		_ranger_les_lieux()
	return true

## Le pays n'a pas de « lieux prêts » une fois pour toutes : ils arrivent
## fenêtre par fenêtre, dans `_viser`.
func _preparer_lieux() -> void:
	pass

# ------------------------------------------------------------ l'eau, le relief

func eau(colonne: int, ligne: int) -> bool:
	if not _viser(case_de_tuile(colonne, ligne)): return true
	return super(colonne, ligne)

func sur_le_rail(colonne: int, ligne: int) -> bool:
	if not _viser(case_de_tuile(colonne, ligne)): return false
	return super(colonne, ligne)

func rail() -> Vector3:
	if not _viser(case_de_point(coeur())): return Vector3(0.0, 1.0, -1.0e9)
	return super()

func hauteur_en(p: Vector2) -> float:
	if not _viser(case_de_point(p)): return NIVEAU_MER_JEU
	return super(p)

func terre_de_case(c: Vector2i) -> bool:
	if not _viser(c): return false
	return super(c)

func route_de_case(c: Vector2i) -> bool:
	if not _viser(c): return false
	return super(c)

func lot_de_case(c: Vector2i) -> int:
	if not _viser(c): return -1
	return super(c)

# ------------------------------------------------------------ districts et gangs

func district_de_case(c: Vector2i) -> int:
	if not _viser(c): return EAU
	return super(c)

func gang_de_case(c: Vector2i) -> int:
	if not _viser(c): return -1
	return super(c)

func nom_du_quartier(point: Vector2) -> String:
	if not _viser(case_de_point(point)): return NOMS_QUARTIERS[EAU]
	return super(point)

# ------------------------------------------------------------ les tuiles

func tuile(colonne: int, ligne: int) -> Dictionary:
	if not _viser(case_de_tuile(colonne, ligne)):
		# ⚠ ON NE MET PAS CETTE RÉPONSE EN CACHE. La fenêtre arrive dans une
		# seconde ; une mer mise en mémoire resterait de la mer pour toujours.
		return _mer(colonne, ligne)
	if _tuiles.size() > TUILES_EN_CACHE:
		_tuiles.clear()
	return super(colonne, ligne)

# ------------------------------------------------------------ la voirie

func sur_la_chaussee(point: Vector2) -> bool:
	if not _viser(case_de_point(point)): return false
	return super(point)

func sur_une_rue(point: Vector2, tolerance: float = 0.0) -> bool:
	if not _viser(case_de_point(point)): return false
	return super(point, tolerance)

func carrefour_proche(point: Vector2) -> Vector2:
	if not _viser(case_de_point(point)): return point
	return super(point)

## ⚠ CELLE-CI TRAVERSE LES FENÊTRES. On ne peut pas viser une fois pour tout le
## segment : il peut aller d'une fenêtre à sa voisine, et c'est justement ce
## qu'on lui demande de vérifier.
func meme_terre(a: Vector2, b: Vector2) -> bool:
	var pas := int(ceilf(a.distance_to(b) / (PAS * 0.5)))
	for i in range(1, maxi(2, pas)):
		var p: Vector2 = a.lerp(b, float(i) / float(pas))
		if not terre_de_case(case_de_point(p)):
			return false
	return true

# ------------------------------------------------------------ le coeur

func un_pont() -> Vector2:
	if not _viser(case_de_point(coeur())): return coeur()
	return super()

## ⭐ OÙ L'ON COMMENCE. Pas au milieu de la carte — ce serait la mer neuf fois
## sur dix — mais au repère du plan, et de là, la case de rue la plus proche,
## en spirale. ⚠ On EXIGE la fenêtre : au premier dixième de seconde, rien
## n'est encore monté, et un joueur posé dans l'eau ne se rattrape pas.
func coeur() -> Vector2:
	if _coeur_d != Vector2.ZERO:
		return _coeur_d
	var c0 := _case_de_depart()
	_coeur_d = centre_case(c0)
	for rayon in 40:
		for dl in range(-rayon, rayon + 1):
			for dk in range(-rayon, rayon + 1):
				if maxi(absi(dk), absi(dl)) != rayon: continue
				var c: Vector2i = c0 + Vector2i(dk, dl)
				if not _viser(c, true): continue
				var lc := _l(c)
				if not carte.route(lc) or carte.case_prise(lc): continue
				_coeur_d = centre_case(c)
				return _coeur_d
	return _coeur_d

## Le point d'ancrage du pays : la gare centrale si le plan en a une, sinon le
## centre de la première île, sinon le milieu de la carte.
func _case_de_depart() -> Vector2i:
	for id in ["gare_centrale", "centre_ville"]:
		for s in plan_du_pays.get("stations", []):
			var f: Dictionary = s
			if String(f.get("id", "")) == id:
				return PLAN.case_de(f["c"])
	if not (plan_du_pays.get("iles", []) as Array).is_empty():
		return PLAN.centre_ile(plan_du_pays, 0)
	return Vector2i(cases_x / 2, cases_y / 2)

# ------------------------------------------------------------ la carte du radar

## ⚠ MILLE CASES DE CÔTÉ, C'EST UN MILLION DE PÂTÉS : la carte peinte d'avance
## de `PlanVille` n'a plus de sens ici (elle mettrait deux minutes à se
## remplir, pour une image que personne ne regarde en entier). Le radar du pays
## se dessine en direct, case par case, autour du joueur — `ui/radar.gd` sait
## déjà le faire, par `terre_de_case` / `route_de_case` / `lot_de_case`.
func nombre_de_pates() -> int:
	return 0

func peindre_pate(_image: Image, _indice: int) -> void:
	pass
