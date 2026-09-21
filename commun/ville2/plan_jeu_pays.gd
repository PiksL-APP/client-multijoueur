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

## ⭐⭐ LE PAYS N'A PAS DE « LIEUX PRÊTS » UNE FOIS POUR TOUTES : ils arrivent
## fenêtre par fenêtre, dans `_viser`. UNE EXCEPTION, ET ELLE COMPTE :
## L'ARÈNE DU STADE.
##
## Il n'y en a qu'une dans tout le pays (client, 21/09), elle est le seul
## endroit où les joueurs peuvent se blesser — et elle était invisible tant
## qu'on n'était pas déjà dessus : la grande carte (TAB) ne dessine que les
## lieux des fenêtres CHARGÉES, c'est-à-dire les neuf autour du joueur. Une
## arène unique qu'on ne peut pas trouver ne sert à personne.
##
## Son emplacement, lui, ne dépend que du plan (`Remplisseur` le choisit sans
## rien construire) : on peut donc la poser dès le départ, avant qu'une seule
## tuile n'existe. La carte la montre alors partout, et un clic dessus met le
## GPS au stade.
const REMPLISSEUR := preload("res://commun/ville2/remplisseur.gd")

var _arene_du_stade := Vector2.ZERO

func _preparer_lieux() -> void:
	if _arene_du_stade != Vector2.ZERO: return
	var choix: Dictionary = REMPLISSEUR.le_stade_du_pays(plan_du_pays, fenetres.ctx)
	var coin: Vector2i = choix.get("coin", Vector2i(-9999, -9999))
	if coin.x < -9000: return
	# Le rond central : le coin de l'enceinte plus la moitié de la pelouse.
	_arene_du_stade = (Vector2(coin) + REMPLISSEUR.CENTRE_DU_TERRAIN) * CASE_PX
	_ajouter_lieu_du_jeu("arenes", _arene_du_stade, {})

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
## ⭐ ON COMMENCE PETIT : la halte d'une petite île — un bourg de pavillons,
## une gare de bout de ligne, la mer autour — avant la grande ville. « Peut-
## être commencer dans une petite ville sur une île » (client, 19/09). La gare
## centrale reste le second choix si le plan n'a pas cette halte.
func _case_de_depart() -> Vector2i:
	for id in ["halte_baie", "gare_centrale", "centre_ville"]:
		for s in plan_du_pays.get("stations", []):
			var f: Dictionary = s
			if String(f.get("id", "")) == id:
				return PLAN.case_de(f["c"])
	if not (plan_du_pays.get("iles", []) as Array).is_empty():
		return PLAN.centre_ile(plan_du_pays, 0)
	return Vector2i(cases_x / 2, cases_y / 2)

# ------------------------------------------------------------ les gangs et les lieux du jeu

## ⭐⭐ LE PAYS ENTRE DANS LE JEU DES GANGS (21/09). Les tuiles sortent du
## générateur avec `gang = -1` sur chaque quartier : partout « terrain
## neutre », aucun repaire, aucune cabine enregistrée — tout ce qui fait
## l'économie de Carnage (contrats, respect, raids) était éteint sur
## l'Archipel. Ici, quand une fenêtre entre en scène :
##
## 1. chaque quartier bâti reçoit un gang de SON SECTEUR (deux locaux et le
##    Consortium, un cinquième des quartiers pour lui — la règle de la ville),
##    tiré du nom du quartier : le même chez les quatre joueurs, et le même
##    d'une fenêtre à l'autre pour un quartier à cheval sur la couture ;
## 2. le premier BAR du quartier devient son repaire (`repaires`, avec `gang`) ;
## 3. les cabines téléphoniques (des objets, pas des lieux) deviennent des
##    `cabines` — c'est là qu'on décroche un contrat.
const GENRES_SANS_GANG := ["parc", "plage", "campagne", ""]

## Le pavé des lieux garantis, en cases — le même que `Remplisseur.PAVE_REPERES`.
## Quarante cases, c'est huit cents mètres : la portée où le jeu cherche ce qui
## l'entoure, et la distance qu'on accepte de faire pour un bar.
const PAVE_LIEUX := 40

func _ranger_les_lieux() -> void:
	# 0. ⚠ L'ARÈNE DU STADE D'ABORD, ET C'EST UNE QUESTION D'ORDRE. Elle vient
	#    du plan, pas de la fenêtre (`_preparer_lieux`) ; posée APRÈS le
	#    rangement de la fenêtre du stade, elle faisait doublon avec celle que
	#    la tuile porte — deux pastilles au même endroit sur la carte.
	_preparer_lieux()
	# 1. Les gangs des quartiers, avant tout : `super` lit `gang` pour les
	#    repaires, et `gang_de_case` pour tout le reste.
	var centres: Dictionary = {}
	for q in plan_du_pays.get("quartiers", []):
		var d: Dictionary = q
		centres[String(d.get("nom", ""))] = centre_case(PLAN.case_de(d["c"]))
	for k in ville.quartiers.size():
		var q2: Dictionary = ville.quartiers[k]
		if int(q2.get("gang", -1)) >= 0: continue
		if String(q2.get("genre", "")) in GENRES_SANS_GANG: continue
		var nom := String(q2.get("nom", ""))
		if not centres.has(nom): continue
		var graine := absi(nom.hash())
		var sect := _secteur_angulaire(centres[nom])
		var trio: Array = TRIOS[posmod(sect, TRIOS.size())]
		q2["gang"] = CONSORTIUM if graine % 5 == 0 else int(trio[graine % 2])
	super()
	# 2. et 3. Les repaires et les cabines, dans les mêmes casiers que le reste.
	#
	# ⭐⭐ UN REPAIRE PAR PAVÉ DE QUARANTE CASES, PAS PAR QUARTIER (21/09).
	# C'est la même mesure que pour les repères, les garages et les cabines :
	# un quartier du pays fait jusqu'à trois cents cases de côté, et le jeu ne
	# cherche les lieux qu'à un secteur et demi. Un seul repaire par quartier,
	# c'est un gang qu'on ne croise jamais — mesuré au campus de la capitale :
	# `rep=0` à quarante-cinq cases. Le territoire d'un gang doit avoir une
	# porte quelque part près de soi, sinon le respect ne se joue nulle part.
	#
	# ⚠ Le pavé se calcule en cases du MONDE : deux tuiles voisines rangent la
	# même case dans le même pavé, et la couture ne pose pas deux repaires
	# côte à côte.
	var repaire_pose: Dictionary = {}
	for l in ville.lieux:
		var d2: Dictionary = l
		if String(d2.get("genre", "")) != "bar": continue
		var p := Vector2(float(d2["x"]), float(d2["z"])) / Decor.ECHELLE + _px()
		var c3 := case_de_point(p)
		var q3 := ville.quartier_en(_l(c3))
		if q3 < 0: continue
		var cle3 := "%d/%d,%d" % [q3, floori(float(c3.x) / float(PAVE_LIEUX)),
			floori(float(c3.y) / float(PAVE_LIEUX))]
		if repaire_pose.has(cle3): continue
		var gang := int(ville.quartiers[q3].get("gang", -1))
		if gang < 0: continue
		repaire_pose[cle3] = true
		_ajouter_lieu_du_jeu("repaires", p, {"gang": gang})
	for o in ville.objets:
		var od: Dictionary = o
		if String(od.get("m", "")) != "cabine": continue
		var pc := Vector2(float(od["x"]), float(od["z"])) / Decor.ECHELLE + _px()
		_ajouter_lieu_du_jeu("cabines", pc, {})
	# 4. ⚠ ET ON NE COMPTE PAS L'ARÈNE DEUX FOIS. `super()` vient de ranger
	#    les lieux de la fenêtre, arène du stade comprise — mais elle est
	#    déjà posée depuis le plan (voir `_preparer_lieux`). Deux arènes au
	#    même endroit, ce sont deux pastilles sur la carte et deux cercles
	#    dans le décor.
	if _arene_du_stade != Vector2.ZERO:
		var s2 := _secteur_de(_arene_du_stade)
		if _lieux_par_secteur.has(s2):
			var gardees: Array = []
			var vue := false
			for a in (_lieux_par_secteur[s2]["arenes"] as Array):
				var d: Dictionary = a
				if Vector2(d["p"]).distance_to(_arene_du_stade) < CASE_PX:
					if vue: continue
					vue = true
				gardees.append(d)
			_lieux_par_secteur[s2]["arenes"] = gardees
	# 5. ⭐⭐⭐ ET PAS D'ARÈNE SEMÉE. « Il ne faut qu'une arène dans le jeu,
	#    elle sera au milieu du stade » (client, 21/09). J'en avais posé une
	#    par secteur de lieux — une centaine sur le pays — parce que la ville
	#    dessinée fait comme ça et que sans arène personne ne peut toucher
	#    personne. Le client tranche autrement, et il a raison : une arène
	#    unique est un LIEU, un rendez-vous, quelque chose qu'on rejoint.
	#    Cent arènes, c'est du tir ami partout, c'est-à-dire nulle part.
	#
	#    Elle est donc posée par `Remplisseur._le_stade`, au rond central, en
	#    même temps que la pelouse et les gradins — et comme le rond central
	#    n'est que dans UNE fenêtre, il n'y en a qu'une dans tout le pays.

func _ajouter_lieu_du_jeu(pluriel: String, p: Vector2, extra: Dictionary) -> void:
	var lieu := {"p": p, "id": _id_lieu, "pate": case_de_point(p)}
	_id_lieu += 1
	lieu.merge(extra)
	var s := _secteur_de(p)
	if not _lieux_par_secteur.has(s):
		_lieux_par_secteur[s] = _lieux_vides()
	(_lieux_par_secteur[s][pluriel] as Array).append(lieu)

## Le secteur angulaire d'un point autour du milieu du pays — la même règle
## que `secteur_du_pate` pour un pâté sans gang.
func _secteur_angulaire(p: Vector2) -> int:
	var milieu := Vector2(float(cases_x), float(cases_y)) * 0.5 * CASE_PX
	if p.distance_squared_to(milieu) < 1.0: return 0
	return posmod(int(floor(((p - milieu).angle() + PI * 0.5) / (TAU / 3.0))), 3)

# ------------------------------------------------------------ le train

## ⭐ LES LIGNES DE RAME DU PAYS, pour `VilleVivante.lignes()` : les lignes
## de surface du plan — le MÉTRO depuis le 21/09, le train étant passé
## sous terre (`PlanPays.RESEAUX_DE_SURFACE`) — en pixels de jeu, avec leurs
## arrêts — les stations du plan qui portent son nom (`ligne`), plus les
## gares nommées (`types` contient un réseau de surface) sur son tracé, à moins
## de deux cases. Sans ça le train du pays roulait sur la droite de Pikstown.
const PRES_DE_LA_VOIE := 2.5

func lignes_de_train() -> Array:
	var sortie: Array = []
	var noms: Dictionary = {}
	for l in plan_du_pays.get("lignes", []):
		var d: Dictionary = l
		if bool(d.get("souterrain", false)): continue
		if String(d.get("reseau", "")) not in PLAN.RESEAUX_DE_SURFACE: continue
		var pts: Array = []
		for p in d["points"]:
			pts.append(centre_case(PLAN.case_de(p)))
		if pts.size() < 2: continue
		var nom := String(d.get("nom", ""))
		noms[nom] = sortie.size()
		sortie.append({"nom": nom, "points": pts, "gares": []})
	for st in plan_du_pays.get("stations", []):
		var f: Dictionary = st
		var p := centre_case(PLAN.case_de(f["c"]))
		var ligne := String(f.get("ligne", ""))
		if ligne != "" and noms.has(ligne):
			(sortie[noms[ligne]]["gares"] as Array).append(p)
		elif Array(f.get("types", [])).any(func(t): return String(t) in PLAN.RESEAUX_DE_SURFACE):
			# Une gare nommée : sur toute ligne qui passe à côté.
			for e in sortie:
				if _distance_a_la_polyligne(p, e["points"]) <= PRES_DE_LA_VOIE * CASE_PX:
					(e["gares"] as Array).append(p)
	return sortie

static func _distance_a_la_polyligne(p: Vector2, pts: Array) -> float:
	var mieux := INF
	for i in range(1, pts.size()):
		mieux = minf(mieux, Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i]).distance_to(p))
	return mieux

# ------------------------------------------------------------ la carte du radar

## ⭐ LA GRANDE CARTE (TAB) DU PAYS SE PEINT DEPUIS LE PLAN, PAS DEPUIS LES
## TUILES. Mille cases de côté, c'est un million de cases : peintes une à une
## depuis les fenêtres chargées, la carte restait BLEUE — le joueur ouvrait
## TAB sur l'Archipel et ne voyait que la mer (19/09). Le plan, lui, sait tout
## du pays sans qu'aucune tuile soit bâtie : la terre (`terre_en`), le
## quartier (`quartier_en`), les routes et les lignes de train (des
## polylignes). On peint donc par BLOCS de `BLOC` cases — un échantillon par
## bloc, 62 500 au lieu d'un million — dans le budget par image de
## `Carnage._peindre_le_plan`, puis les routes et le rail d'un trait, au
## premier « secteur ». Le radar, lui, reste dessiné case par case autour du
## joueur, depuis les tuiles.
const BLOC := 4
const DISTRICT_DU_GENRE := {
	"centre": PlanVille.CENTRE, "plage": PlanVille.PORT, "port": PlanVille.PORT,
	"pavillons": PlanVille.BANLIEUE, "industrie": PlanVille.INDUSTRIE,
	"vieille_ville": PlanVille.VIEUX, "chaud": PlanVille.COMMERCE,
	"campus": PlanVille.RESIDENCES, "bidonville": PlanVille.INDUSTRIE,
	"parc": PlanVille.PARC,
}
const CARTE_CAMPAGNE := Color("#7aa860")
const CARTE_PLAGE := Color("#e0cb9a")
var _plan_ctx: Dictionary = {}
var _traits_peints := false

func nombre_de_pates() -> int:
	return (cases_x / BLOC) * (cases_y / BLOC)

func peindre_pate(image: Image, indice: int) -> void:
	var par_ligne := cases_x / BLOC
	var bi := posmod(indice, par_ligne)
	var bj := indice / par_ligne
	if bj >= cases_y / BLOC: return
	if _plan_ctx.is_empty(): _plan_ctx = fenetres.ctx if not fenetres.ctx.is_empty() else PLAN.contexte(plan_du_pays)
	var c := Vector2i(bi * BLOC + BLOC / 2, bj * BLOC + BLOC / 2)
	var couleur: Color
	if not PLAN.terre_en(plan_du_pays, _plan_ctx, c):
		couleur = PlanVille.CARTE_EAU
	else:
		var q := PLAN.quartier_en(plan_du_pays, _plan_ctx, c)
		if q < 0:
			couleur = CARTE_CAMPAGNE
		else:
			var genre := String((plan_du_pays["quartiers"][q] as Dictionary).get("g", ""))
			couleur = PlanVille.COULEURS_CARTE.get(int(DISTRICT_DU_GENRE.get(genre, PlanVille.PARC)), CARTE_CAMPAGNE)
			if genre == "plage": couleur = CARTE_PLAGE
	var cote := BLOC * TUILES_PAR_CASE
	var x0 := bi * cote
	var y0 := bj * cote
	image.fill_rect(Rect2i(x0, y0, mini(cote, image.get_width() - x0), mini(cote, image.get_height() - y0)), couleur)

## Les routes et le rail du plan, tracés une fois — au premier secteur — puis
## les lieux des fenêtres chargées, comme en ville.
func peindre_secteur(image: Image, secteur: Vector2i) -> void:
	if not _traits_peints:
		_traits_peints = true
		for r in plan_du_pays.get("routes", []):
			var d: Dictionary = r
			var classe := String(d.get("classe", ""))
			var couleur := PlanVille.CARTE_AVENUE.lightened(0.25) if classe == PLAN.V_PRIMAIRE \
				else (PlanVille.CARTE_AVENUE if classe == PLAN.V_SECONDAIRE else PlanVille.CARTE_RUE)
			var large := 3 if classe == PLAN.V_PRIMAIRE else (2 if classe == PLAN.V_SECONDAIRE else 1)
			_tracer(image, d["points"], couleur, large)
		for l in plan_du_pays.get("lignes", []):
			var d2: Dictionary = l
			if bool(d2.get("souterrain", false)): continue
			if String(d2.get("reseau", "")) not in PLAN.RESEAUX_DE_SURFACE: continue
			_tracer(image, d2["points"], PlanVille.CARTE_RAIL, 2)
	super(image, secteur)

func _tracer(image: Image, points: Array, couleur: Color, large: int) -> void:
	for k in range(1, points.size()):
		var a := PLAN.case_de(points[k - 1]) * TUILES_PAR_CASE
		var b := PLAN.case_de(points[k]) * TUILES_PAR_CASE
		var n := maxi(1, maxi(absi(b.x - a.x), absi(b.y - a.y)))
		for i in n + 1:
			var p := Vector2i((Vector2(a) + (Vector2(b - a)) * (float(i) / float(n))).round())
			for dy in large:
				for dx in large:
					var x := p.x + dx - large / 2
					var y := p.y + dy - large / 2
					if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
						image.set_pixel(x, y, couleur)
