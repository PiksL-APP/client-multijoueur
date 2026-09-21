extends RefCounted
## ⭐⭐ LE REMPLISSEUR — il bâtit un quartier D'APRÈS SA CHARTE, sur une tache de
## forme quelconque, et il remplace la greffe des témoins.
##
## Avant : on générait le témoin entier (40 × 40) et on le recopiait. Un quartier
## était donc un carré, et deux quartiers voisins étaient deux carrés accolés
## dont les plans de rues ne se répondaient pas.
##
## Maintenant : `plan_pays` dit QUEL quartier est sous chaque case
## (`quartier_en`), `regles_quartier` dit COMMENT on bâtit ce genre-là, et ce
## fichier fait le travail. Aucun témoin n'est appelé.
##
## ⚠⚠ LA RÈGLE QUI TIENT TOUT : LE RÉSULTAT NE DOIT PAS DÉPENDRE DE LA FENÊTRE.
## Le pays se bâtit par morceaux autour du joueur ; deux fenêtres voisines
## recalculent la même rue et doivent poser LA MÊME MAISON AU MÊME ENDROIT,
## sinon la couture se voit à chaque déplacement. D'où deux disciplines, et
## elles ne se négocient pas :
##
## 1. TOUT SE CALCULE EN COORDONNÉES ABSOLUES. Une rue est une fonction de sa
##    position sur la carte, pas de sa position dans la fenêtre.
## 2. ON PARCOURT LA RUE ENTIÈRE, MÊME CE QU'ON NE VOIT PAS. Le tirage avance
##    d'un cran par emplacement : commencer au bord de la fenêtre décalerait
##    toute la série. On parcourt donc du vrai début de la rue, et on ne POSE
##    que ce qui tombe dans la fenêtre. C'est le seul surcoût de la garantie, et
##    il se chiffre en dizaines de cases parcourues pour rien.

const PLAN := preload("res://commun/ville2/plan_pays.gd")
const REGLES := preload("res://commun/ville2/regles_quartier.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")
const ATLAS := preload("res://commun/ville2/atlas.gd")

const GAMMES_TOIT := {
	"VIEILLE": ATLAS.VIEILLE, "PAVILLONNAIRE": ATLAS.PAVILLONNAIRE,
	"TOLE": ATLAS.TOLE, "MIDI": ATLAS.MIDI,
}
const GAMMES_MUR := {
	"PAVILLONS": TEINTES.PAVILLONS, "INDUSTRIE": TEINTES.INDUSTRIE,
	"VIEILLE_PIERRE": TEINTES.VIEILLE_PIERRE, "PIERRE_DU_SUD": TEINTES.PIERRE_DU_SUD,
	"PIERRE_DE_TAILLE": TEINTES.PIERRE_DE_TAILLE, "BETON_VERRE": TEINTES.BETON_VERRE,
}
const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## La graine d'une rue : elle ne dépend que de la rue, donc pas de la fenêtre.
static func _graine(a: int, b: int, c: int) -> int:
	return absi(a * 73856093 ^ b * 19349663 ^ c * 83492791)

## ⭐ LE POINT D'ENTRÉE. `origine` est le coin nord-ouest de la fenêtre, en cases
## absolues. La fenêtre porte déjà son terrain et ses grands axes.
static func remplir(plan: Dictionary, ctx: Dictionary, v: Ville2, origine: Vector2i) -> void:
	var quartiers: Array = plan.get("quartiers", [])
	if quartiers.is_empty(): return
	var f := Rect2i(origine, v.taille)
	var vus := _visibles(plan, f)
	# 0. LE QUARTIER SOUS CHAQUE CASE, ÉCRIT DANS LA VILLE. Le jeu s'en sert
	#    ensuite sans repasser par le plan : gangs, radar, contrats, et la passe
	#    de semis qui doit savoir où elle a le droit de planter.
	_peindre(plan, ctx, v, f, vus)
	# 1. LES RUES DE QUARTIER. Toutes d'abord, et on rastérise : les lots ont
	#    besoin de savoir où est la chaussée, y compris celle du voisin.
	#    ⚠⚠ ET JAMAIS DEUX CHAUSSÉES CÔTE À CÔTE. « Ne fais jamais de double voie
	#    à part pour des autoroutes » (client, 15/09). Une rue de quartier posée
	#    à une case d'un axe du plan donne deux chaussées parallèles séparées par
	#    un ruban de trottoir large de vingt mètres : ça ne se lit ni comme une
	#    avenue ni comme deux rues, ça se lit comme une faute. On tient donc un
	#    registre des cases déjà roulantes et on COUPE la rue dès qu'elle passe à
	#    moins d'une case de l'une d'elles — sauf voie rapide, qui a le droit
	#    d'avoir sa contre-allée.
	var prises := _les_chaussees(plan, f)
	# ⭐⭐⭐ LE TERRAIN DU STADE SE RÉSERVE AVANT LES RUES, ET C'EST LA SEULE
	# FAÇON QUE ÇA MARCHE. `Proprete.rien_sur_les_routes` retire tout objet
	# dont la case porte de la chaussée : une rue de quartier qui traverse
	# l'enceinte emporte EN SILENCE les tribunes et les mâts qu'elle touche
	# (compté au premier essai : 23 pièces au lieu de 30). Et le campus est
	# quadrillé — aucune emprise de huit cases sur six n'y est libre de rue.
	# On inscrit donc l'emprise dans le registre des chaussées AVANT de tracer
	# les rues : `_ecarter` les coupe autour, exactement comme elles se
	# coupent le long de la voie ferrée.
	var choix := _le_choix_du_stade(plan, ctx)
	var coin_stade: Vector2i = choix["coin"]
	if coin_stade.x > -9000:
		for j in range(-1, STADE_CASES.y + 1):
			for i in range(-1, STADE_CASES.x + 1):
				prises[coin_stade + Vector2i(i, j)] = true
	var voies: Array = []
	#    ⭐⭐ ET ON JETTE LES MIETTES. C'est `_ecarter` lui-même qui fabrique les
	#    moignons : quand une rue longe un axe existant, elle est COUPÉE, et il
	#    reste de part et d'autre des bouts de deux ou trois cases qui ne mènent
	#    nulle part.
	#
	#    ⚠⚠ ET LA MESURE DIT QUE CE N'EST PAS LA CAUSE DES CULS-DE-SAC. J'ai
	#    compté avant et après : 3652 cases de chaussée et 124 culs-de-sac dans
	#    les deux cas, donc AUCUN bout n'était sous le seuil. Les 124 impasses
	#    viennent d'ailleurs — des rues qui butent sur le trait de côte ou sur la
	#    limite de leur quartier. Le garde-fou reste, parce qu'une découpe plus
	#    agressive en produirait, mais il ne faut pas lui attribuer un mérite
	#    qu'il n'a pas : le vrai chantier des moignons est ailleurs.
	#
	#    ⚠ ON LES JETTE, MAIS ON GARDE LEUR TRACE DANS `prises`. Sans ça le
	#    morceau suivant de la même rue reviendrait se poser à côté d'elles, et
	#    on retomberait sur la double voie que tout ce registre sert à éviter.
	var rect_stade := Rect2i(coin_stade - Vector2i(1, 1), STADE_CASES + Vector2i(2, 2)) \
		if coin_stade.x > -9000 else Rect2i(-9999, -9999, 1, 1)
	for k in vus:
		for pts in _les_voies(plan, ctx, k):
			for bout0 in _ecarter(pts, prises):
				# ⚠ ET ON COUPE CE QUI TRAVERSE LE STADE. `_ecarter` ne coupe
				# qu'une rue qui LONGE une emprise prise : une rue qui la
				# traverse à l'équerre est un croisement, et un croisement est
				# légitime partout — sauf au milieu d'une pelouse.
				for bout1 in _hors_de(_prolonger(bout0, prises), rect_stade):
					var bout: Array = bout1
					for c in bout: prises[c] = true
					if bout.size() < MIN_RUE: continue
					voies.append({"k": k, "cases": bout})
	for e in voies:
		var d: Dictionary = e
		_tracer(v, f, d["cases"], REGLES.charte(_genre(plan, int(d["k"]))))
	v.rasteriser()
	# 2. LE SOL du quartier, hors chaussée.
	_le_sol(plan, ctx, v, f, vus)
	# 2 bis. ⭐⭐ RÉSERVER CE QUI N'EST PAS UNE ROUTE ET QUI INTERDIT DE BÂTIR.
	#        `Lotisseur.terrain_libre` connaît trois choses : la terre, les
	#        routes et les lots. Le RAIL n'est aucune des trois, et le TABLIER
	#        DE L'AUTOROUTE non plus — il est en l'air, donc invisible pour le
	#        sol. Résultat mesuré sur une fenêtre de 2,2 km : 74 maisons posées
	#        SUR la voie ferrée et 529 sous le viaduc, qui leur passait au
	#        travers. On réserve donc les deux emprises dans `demi_prises`, et
	#        on le fait AVANT les lots — après, il est trop tard.
	_reserver(plan, v, f)
	# 2 ter. ⭐⭐⭐ LE STADE — et l'unique ARÈNE du jeu, à son rond central.
	_le_stade(plan, v, f, coin_stade)
	# 3. ⭐ LES REPÈRES ET LES GARES AVANT LES LOTS, ET C'EST UN ORDRE QU'ON NE
	#    DEVINE PAS : posés en dernier, ils ne trouvaient PLUS UNE SEULE PLACE
	#    LIBRE — la rue était déjà bordée sur toute sa longueur, et l'hôpital,
	#    la caserne et la gare disparaissaient en silence. Les grosses pièces
	#    d'abord, le tissu ordinaire ensuite : c'est l'ordre d'un vrai plan de
	#    ville, et c'est le seul qui marche ici.
	for k0 in vus:
		_les_reperes(plan, ctx, v, f, k0, prises)
	_les_gares(plan, ctx, v, f, prises)
	v.rasteriser()
	# 4. LES LOTS, des deux côtés de chaque rue.
	for e2 in voies:
		var d2: Dictionary = e2
		_border(plan, ctx, v, f, int(d2["k"]), d2["cases"])
	v.rasteriser()
	# 5. LE MOBILIER, à la densité de la charte.
	for e3 in voies:
		var d3: Dictionary = e3
		_mobilier(plan, ctx, v, f, int(d3["k"]), d3["cases"])
	# 5 bis. LES CABINES, à la densité du QUARTIER et pas de la rue. Voir
	#        `_les_cabines` : c'est par elles qu'on décroche un contrat.
	_les_cabines(v, f, voies)
	# 6. ⭐ LES TEINTES, ET C'EST LA MOITIÉ DE L'IMAGE. Toutes les toitures du
	#    kit pointent la même bande verte de l'atlas : tant qu'elle n'est pas
	#    repeinte, changer les murs ne change presque rien. Un quartier se juge
	#    d'en haut, et d'en haut c'est 70 % de toiture.
	#
	#    ⚠ ET LA GRAINE NE DOIT PAS DÉPENDRE DE LA FENÊTRE, ici non plus. On
	#    teinte donc PAR GENRE, chaque genre avec sa propre graine : deux
	#    fenêtres voisines repeignent la même série de toits dans le même ordre.
	_les_teintes(plan, v, f, vus)
	# 6. LES REPÈRES DU CLIENT — église, hôpital, caserne, supérette. Ce sont les
	#    quatre pièces qui font qu'un quartier se RECONNAÎT au lieu de se
	#    ressembler : sans elles, quinze centres-villes sont le même damier.
	# 7. ⭐ LES REPÈRES HABITABLES, SEMÉS PARTOUT. Un quartier n'est pas qu'un
	#    décor : le jeu a besoin de PORTES — planques, garages, supérettes,
	#    cabines. On ne pose pas de nouveaux bâtiments pour ça, on RE-QUALIFIE
	#    ceux qui sont déjà là : un lot devient une planque, et il garde sa
	#    façade, son toit et sa place dans la rue. Poser un bâtiment de plus
	#    aurait demandé une place libre qui n'existe plus à ce stade.
	_les_habitables(plan, v, f)
	# 7 bis. ⭐⭐ LE CŒUR DES ÎLOTS, qui était nu.
	_les_coeurs(plan, ctx, v, f, vus)
	# 8. LE MOBILIER DES STATIONS — la gare des lignes de train, l'abribus et le rack à vélos
	#    de tout le reste. Trois cent quarante-deux stations sur le pays : c'est
	#    le mobilier le plus RÉPANDU de la carte, et jusqu'ici aucune n'avait
	#    autre chose qu'un point dans un fichier.
	_les_stations(plan, ctx, v, f)

# ══════════════════════════════════════════════════════════ LE STADE ET L'ARÈNE

## ⭐⭐⭐ LE STADE DU PAYS, ET IL N'Y EN A QU'UN.
##
## « Il ne faut qu'une arène dans le jeu, elle sera au milieu du stade »
## (client, 21/09).
##
## L'arène est ce qui autorise le tir ami : `Carnage` ne laisse un joueur en
## blesser un autre que si le coup part d'une arène et arrive dans la même, et
## ne compte un frag qu'au même prix. Le pays n'en avait aucune — donc pas de
## mode Carnage du tout. Une par secteur aurait rendu le tir ami possible
## partout, c'est-à-dire nulle part : le client veut UN LIEU, un rendez-vous,
## un stade où l'on monte se battre.
##
## Le témoin `campus` sait dessiner un stade depuis le 13/09 (pelouse à la
## cote réelle, tracé, couronne de tribunes, buts, mâts) — mais les témoins ne
## sont plus greffés sur le pays : les quartiers s'y bâtissent par charte. Le
## stade est donc REDESSINÉ ici, à la même cote et avec les mêmes pièces, une
## seule fois, dans un seul quartier.
##
## ⚠ SON EMPLACEMENT NE DÉPEND QUE DU PLAN, jamais de la fenêtre : le quartier
## de genre `campus` le plus vaste (à surface égale, le premier du plan), puis
## la première emprise libre en spirale autour de son centre — deux critères
## que toutes les fenêtres lisent pareil. Une fenêtre qui n'en voit qu'un
## morceau dessine ce morceau ; la fenêtre qui contient le ROND CENTRAL est la
## seule à poser le lieu `arene`, et c'est ce qui garantit qu'il n'y en a
## qu'une dans tout le pays.
const STADE_CASES := Vector2i(8, 6)       ## l'enceinte de terre battue, en cases (160 × 120 unités)
const STADE_MURET := Rect2(10.0, 10.0, 140.0, 100.0)   ## le rectangle des tribunes, en unités depuis le coin
const STADE_PELOUSE := Rect2(20.0, 20.0, 120.0, 80.0)  ## l'aire de jeu, 120 × 80 m, à la cote réelle
const STADE_RECUL := 4.0                  ## du muret au centre d'une tribune
const STADE_VERT := "#4e9b36"
const STADE_BLANC := "#e8efe4"

## ⭐⭐ LE CHOIX DE L'EMPLACEMENT SE FAIT UNE FOIS POUR TOUT LE PAYS, et il ne
## regarde QUE le plan : ni la fenêtre, ni ce qui a déjà été bâti. Deux tuiles
## voisines doivent trouver le même stade au même endroit, sans quoi la
## couture le couperait en deux ou le poserait deux fois.
##
## Les candidats, dans cet ordre : les quartiers de genre `campus` du plus
## vaste au plus petit, puis les `parc`. Un stade est d'abord un équipement de
## campus ; mais le campus du pays est quadrillé d'axes tous les dix cases, et
## un parc, lui, est vide — si aucun campus n'a douze cases sur dix sans
## bitume, le stade municipal va au parc plutôt que de se faire traverser par
## une avenue.
##
## ⚠ LE RÉSULTAT EST MIS EN CACHE : la spirale coûte quelques dizaines de
## milliers d'interrogations du plan, et vingt-cinq tuiles la paieraient
## vingt-cinq fois. Le cache est une décision du PLAN, pas de la fenêtre.
static var _stade_choisi: Dictionary = {}

## Le centre du terrain (le rond central, donc l'arène), en cases depuis le
## coin de l'enceinte. `PlanJeuPays` en a besoin pour poser l'arène avant
## qu'aucune tuile n'existe.
const CENTRE_DU_TERRAIN := Vector2(4.0, 3.0)

## L'ENTRÉE PUBLIQUE : où est le stade du pays, sans rien construire.
## Rend `{"coin": Vector2i, "k": int}` — `coin.x < -9000` s'il n'y en a pas.
static func le_stade_du_pays(plan: Dictionary, ctx: Dictionary) -> Dictionary:
	return _le_choix_du_stade(plan, ctx)

static func _le_choix_du_stade(plan: Dictionary, ctx: Dictionary) -> Dictionary:
	if not _stade_choisi.is_empty(): return _stade_choisi
	var candidats: Array = []
	for genre in ["campus", "parc"]:
		var lot: Array = []
		for k in (plan.get("quartiers", []) as Array).size():
			var z: Dictionary = plan["quartiers"][k]
			if String(z.get("g", "")) != genre: continue
			var r := PLAN.case_de(z.get("r", [0, 0]))
			lot.append([r.x * r.y, k])
		lot.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
		for e in lot: candidats.append(int((e as Array)[1]))
	# Deux cases de vide autour de l'enceinte d'abord, une seule ensuite, et
	# en dernier recours une emprise qu'un axe traverse : sans stade il n'y a
	# pas d'arène, donc pas de tir ami de toute la partie.
	for marge in [2, 1, 0]:
		for k2 in candidats:
			var c := _coin_dans_le_quartier(plan, ctx, int(k2), marge)
			if c.x > -9000:
				_stade_choisi = {"coin": c, "k": int(k2)}
				return _stade_choisi
	_stade_choisi = {"coin": Vector2i(-9999, -9999), "k": -1}
	return _stade_choisi

## La première emprise tenable d'un quartier, en spirale à pas de deux cases
## depuis son centre. `(-9999, -9999)` s'il n'y en a pas.
static func _coin_dans_le_quartier(plan: Dictionary, ctx: Dictionary, k: int,
		marge: int) -> Vector2i:
	var z: Dictionary = plan["quartiers"][k]
	var centre := PLAN.case_de(z["c"])
	var r := PLAN.case_de(z.get("r", [0, 0]))
	# ⚠⚠ LE REGISTRE DES CHAUSSÉES SE FAIT SUR LE QUARTIER, PAS SUR UNE
	# FENÊTRE. Celui d'une fenêtre s'arrête à seize cases de son bord : une
	# candidate plus loin y paraissait libre de route, et le stade changeait
	# de place selon le cadrage — la faute que tout ce fichier s'interdit.
	var prises := _les_chaussees(plan, Rect2i(centre - r, r * 2))
	var vise := centre - Vector2i(STADE_CASES.x / 2, STADE_CASES.y / 2)
	var portee: int = clampi(maxi(r.x, r.y) / 2, 4, 16)
	for anneau in portee:
		for dj in range(-anneau, anneau + 1):
			for di in range(-anneau, anneau + 1):
				if maxi(absi(di), absi(dj)) != anneau: continue
				var c := vise + Vector2i(di, dj) * 2
				if _emprise_de_stade(plan, ctx, k, c, prises, marge): return c
	return Vector2i(-9999, -9999)

static func _emprise_de_stade(plan: Dictionary, ctx: Dictionary, k: int, c: Vector2i,
		prises: Dictionary, marge: int) -> bool:
	# Une case de marge : les mâts d'éclairage débordent de l'enceinte.
	for j in range(-1, STADE_CASES.y + 1):
		for i in range(-1, STADE_CASES.x + 1):
			var d := c + Vector2i(i, j)
			if not PLAN.terre_en(plan, ctx, d): return false
			if PLAN.quartier_en(plan, ctx, d) != k: return false
	# ⚠ ET LA MARGE DE CHAUSSÉE VAUT DEUX CASES, LA SECONDE EST PAYÉE : le
	# registre ne tient que l'AXE d'une route du plan, et `rasteriser` pose
	# une avenue plus large que son axe. Une emprise qui frôlait l'axe se
	# retrouvait avec une colonne de bitume au travers de la pelouse — donc
	# une file de tribunes effacée par `Proprete.rien_sur_les_routes`, en
	# silence.
	if marge <= 0: return true
	for j2 in range(-marge, STADE_CASES.y + marge):
		for i2 in range(-marge, STADE_CASES.x + marge):
			if prises.has(c + Vector2i(i2, j2)): return false
	return true

static func _le_stade(plan: Dictionary, v: Ville2, f: Rect2i, coin: Vector2i) -> void:
	if coin.x < -9000: return
	var k := int(_stade_choisi.get("k", -1))
	if k < 0: return
	var z: Dictionary = plan["quartiers"][k]
	var l0 := coin - f.position                      # le coin, en cases de la fenêtre
	var o := Vector2(l0) * CASE                      # le même, en unités
	# 1. L'ENCEINTE en terre battue, réservée : ni lot, ni mobilier, ni repère,
	#    ni rue recousue — `interdire` le dit à tout le monde d'un coup
	#    (`Proprete.rien_sur_les_routes` pour les objets semés,
	#    `GenerateurPays._relier_les_bouts` pour la voirie). Les pièces du
	#    stade lui-même portent le drapeau `zone`, comme celles de
	#    l'aérodrome sur sa piste : elles sont chez elles.
	v.interdire(Rect2(o, Vector2(STADE_CASES) * CASE))
	for j in range(-1, STADE_CASES.y + 1):
		for i in range(-1, STADE_CASES.x + 1):
			var c := l0 + Vector2i(i, j)
			if not v.dedans(c): continue
			if v.carte != null and v.carte.route(c): continue
			if i >= 0 and j >= 0 and i < STADE_CASES.x and j < STADE_CASES.y:
				v.poser_matiere(c, Ville2.M_TERRE)
			_reserver_la_case(v, c)
	# 2. LA PELOUSE, son tracé, et l'ARÈNE au rond central.
	var p := Rect2(o + STADE_PELOUSE.position, STADE_PELOUSE.size)
	var cx := p.position.x + p.size.x * 0.5
	var cz := p.position.y + p.size.y * 0.5
	_bande(v, f, cx, cz, p.size.x, p.size.y, STADE_VERT)
	for s2 in [-1.0, 1.0]:
		_bande(v, f, cx, cz + s2 * (p.size.y * 0.5 - 4.0), p.size.x - 8.0, 0.6, STADE_BLANC)
		_bande(v, f, cx + s2 * (p.size.x * 0.5 - 4.0), cz, 0.6, p.size.y - 8.0, STADE_BLANC)
		var zs: float = cz + s2 * (p.size.y * 0.5 - 20.0)
		_bande(v, f, cx, zs, 40.0, 0.6, STADE_BLANC)
		for s3 in [-1.0, 1.0]:
			_bande(v, f, cx + s3 * 20.0, cz + s2 * (p.size.y * 0.5 - 14.0), 0.6, 12.0, STADE_BLANC)
	_bande(v, f, cx, cz, p.size.x - 8.0, 0.6, STADE_BLANC)
	_bande(v, f, cx, cz, 18.0, 18.0, "#7fb35f")
	# 3. LA COURONNE DE TRIBUNES — la tribune d'honneur couverte à l'ouest.
	var m := Rect2(o + STADE_MURET.position, STADE_MURET.size)
	for k2 in int(m.size.x / 20.0):
		var lx := m.position.x + 10.0 + float(k2) * 20.0
		_objet(v, f, "pxl/tribune-droite", lx, m.position.y - STADE_RECUL, PI)
		_objet(v, f, "pxl/tribune-droite", lx, m.end.y + STADE_RECUL, 0.0)
	for k3 in int(m.size.y / 20.0):
		var lz := m.position.y + 10.0 + float(k3) * 20.0
		_objet(v, f, "pxl/tribune-couverte", m.position.x - STADE_RECUL, lz, -PI * 0.5)
		_objet(v, f, "pxl/tribune-droite", m.end.x + STADE_RECUL, lz, PI * 0.5)
	# Les quatre angles : le modèle ouvre son coin vers −X et −Z, donc au repos
	# il ferme le coin sud-est, et chaque quart de tour le fait tourner.
	_objet(v, f, "pxl/tribune-angle", m.end.x + STADE_RECUL, m.end.y + STADE_RECUL, 0.0)
	_objet(v, f, "pxl/tribune-angle", m.end.x + STADE_RECUL, m.position.y - STADE_RECUL, PI * 0.5)
	_objet(v, f, "pxl/tribune-angle", m.position.x - STADE_RECUL, m.position.y - STADE_RECUL, PI)
	_objet(v, f, "pxl/tribune-angle", m.position.x - STADE_RECUL, m.end.y + STADE_RECUL, PI * 1.5)
	# 4. LES BUTS et LES MÂTS — c'est le mât qu'on voit de loin, et c'est lui
	#    qui dit « stade » avant qu'on distingue les gradins.
	_objet(v, f, "pxl/but-football", cx, p.position.y + 5.0, PI)
	_objet(v, f, "pxl/but-football", cx, p.end.y - 5.0, 0.0)
	for mx in [m.position.x - 12.0, m.end.x + 12.0]:
		for mz in [m.position.y - 12.0, m.end.y + 12.0]:
			_objet(v, f, "pxl/mat-eclairage", mx, mz,
				Vector2(cx - mx, cz - mz).angle() + PI * 0.5)
	# 5. ⭐ L'ARÈNE, au rond central — et seulement si le rond central est DANS
	#    cette fenêtre. C'est la ligne qui fait qu'il n'y en a qu'une.
	var c_centre := Vector2i(floori(cx / CASE), floori(cz / CASE))
	if v.dedans(c_centre):
		v.ajouter_lieu("arene", cx, cz, {"nom": "Stade " + String(z.get("nom", ""))})

## Une bande de pelouse peinte (la brique `pelouse` du rendu), posée seulement
## si son centre est dans la fenêtre : une pièce dont le centre est chez la
## voisine est dessinée par la voisine.
static func _bande(v: Ville2, f: Rect2i, x: float, z: float, w: float, d: float,
		teinte: String) -> void:
	if not v.dedans(Vector2i(floori(x / CASE), floori(z / CASE))): return
	v.objets.append({"m": "pelouse", "x": x, "z": z, "r": 0.0, "h": 0.0,
		"w": w, "d": d, "c": teinte, "zone": true})

static func _objet(v: Ville2, f: Rect2i, modele: String, x: float, z: float, r: float) -> void:
	if not v.dedans(Vector2i(floori(x / CASE), floori(z / CASE))): return
	v.objets.append({"m": modele, "x": x, "z": z, "r": r, "h": 0.0, "zone": true})

## ⭐⭐ LE GENRE D'UN QUARTIER, avec une exception qui ne coûte pas un recuit.
##
## Le plan ne connaît qu'un genre « centre » pour les quatre quartiers centraux.
## Le client en veut deux matières : pierre et brique sur le centre historique,
## béton et verre sur le quartier d'affaires (17/09). Plutôt que de rouvrir le
## plan des vingt kilomètres et de le recuire pour une question de peinture, on
## déduit le quartier d'affaires de son NOM — « La Cité », et toute Gare
## Centrale — et on lui donne sa propre charte.
##
## ⚠ LE NOM EST UNE DONNÉE DU PLAN, DONC STABLE d'une fenêtre à l'autre : deux
## fenêtres voisines déduisent le même genre pour le même quartier, et la
## couture ne se voit pas.
const AFFAIRES := ["cité", "cite", "gare centrale", "affaires"]

static func _genre(plan: Dictionary, k: int) -> String:
	var q: Dictionary = plan["quartiers"][k]
	var g := String(q["g"])
	if g != "centre": return g
	var nom := String(q.get("n", q.get("nom", ""))).to_lower()
	for mot in AFFAIRES:
		if nom.contains(String(mot)): return "affaires"
	return g

## Les quartiers qui touchent la fenêtre. La marge couvre le bruit du contour.
static func _visibles(plan: Dictionary, f: Rect2i) -> Array:
	var sortie: Array = []
	var quartiers: Array = plan["quartiers"]
	for k in quartiers.size():
		var z: Dictionary = quartiers[k]
		var c := PLAN.case_de(z["c"])
		var r: Array = z["r"]
		var b := Rect2i(c - Vector2i(int(r[0]), int(r[1])),
			Vector2i(int(r[0]), int(r[1])) * 2).grow(8)
		# ⚠ ET ON N'ÉLARGIT PAS CETTE FENÊTRE-CI, C'EST MESURÉ. J'ai essayé de
		# la faire regarder `MARGE_REGISTRE` cases plus loin, pour la même raison
		# que le registre des chaussées : les deux dernières cases de désaccord
		# entre deux cadrages n'ont PAS bougé, et la fabrication d'une fenêtre a
		# pris une seconde et demie de plus. On garde donc la fenêtre nue.
		if b.intersects(f): sortie.append(k)
	return sortie

# ──────────────────────────────────────────────────────────────── LES RUES

## ⭐ LA TRAME D'UN QUARTIER, EN COORDONNÉES ABSOLUES. Les rues sont posées sur
## le multiple de `pas` le plus proche — donc au même endroit quelle que soit la
## fenêtre — et DÉPORTÉES par une sinusoïde lente : c'est ce qui les rend
## organiques sans jamais produire de diagonale.
##
## ⚠ UN DÉPORT N'EST PAS UN BRUIT. Un bruit par case donne une rue en zigzag
## d'une case, illisible et impossible à border : chaque tronçon droit fait deux
## cases et aucune maison n'y tient. La sinusoïde a une période d'une trentaine
## de cases : la rue part en biais, revient, et ses tronçons droits font vingt
## cases — de quoi border.
static func _les_voies(plan: Dictionary, ctx: Dictionary, k: int) -> Array:
	var z: Dictionary = plan["quartiers"][k]
	var charte := REGLES.charte(String(z["g"]))
	var pas := int(charte["pas"])
	if pas <= 0: return []
	var amp := float(charte["meandre"])
	var c := PLAN.case_de(z["c"])
	var r: Array = z["r"]
	var rx := int(r[0]) + 6
	var rz := int(r[1]) + 6
	var sortie: Array = []
	# LES VERTICALES.
	var x0 := int(floor(float(c.x - rx) / float(pas))) * pas
	for x in range(x0, c.x + rx + pas, pas):
		var cases: Array = []
		for y in range(c.y - rz, c.y + rz + 1):
			var dx := roundi(amp * sin(float(y) * 0.055 + float(x) * 0.37))
			cases.append(Vector2i(x + dx, y))
		_ajouter(sortie, _continuer(plan, ctx, k, cases, true))
	# LES HORIZONTALES.
	var y0 := int(floor(float(c.y - rz) / float(pas))) * pas
	for y2 in range(y0, c.y + rz + pas, pas):
		var cases2: Array = []
		for x2 in range(c.x - rx, c.x + rx + 1):
			var dy := roundi(amp * sin(float(x2) * 0.048 + float(y2) * 0.61))
			cases2.append(Vector2i(x2, y2 + dy))
		_ajouter(sortie, _continuer(plan, ctx, k, cases2, false))
	return sortie

static func _ajouter(sortie: Array, morceaux: Array) -> void:
	for m in morceaux: sortie.append(m)

## ⚠ DEUX TRAVAUX EN UN, ET IL FAUT LES FAIRE ENSEMBLE : on COUPE la ligne aux
## limites du quartier (une rue de centre-ville ne continue pas dans les champs)
## et on COMBLE les sauts de déport (passer de x à x+1 en changeant de y est une
## diagonale ; la rue doit faire le coude).
static func _continuer(plan: Dictionary, ctx: Dictionary, k: int, cases: Array,
		vertical: bool) -> Array:
	var sortie: Array = []
	var courant: Array = []
	var precedent := Vector2i(-9999, -9999)
	for e in cases:
		var c: Vector2i = e
		var dedans := PLAN.quartier_en(plan, ctx, c) == k and PLAN.terre_en(plan, ctx, c)
		if not dedans:
			if courant.size() >= 6: sortie.append(courant)
			courant = []
			precedent = Vector2i(-9999, -9999)
			continue
		if precedent.x > -9000:
			# LE COUDE. On avance d'abord sur l'axe transverse, puis on reprend.
			if vertical and c.x != precedent.x:
				var pas := 1 if c.x > precedent.x else -1
				var x := precedent.x
				while x != c.x:
					x += pas
					courant.append(Vector2i(x, precedent.y))
			elif not vertical and c.y != precedent.y:
				var pas2 := 1 if c.y > precedent.y else -1
				var y := precedent.y
				while y != c.y:
					y += pas2
					courant.append(Vector2i(precedent.x, y))
		courant.append(c)
		precedent = c
	if courant.size() >= 6: sortie.append(courant)
	return sortie

## La rue, découpée à la fenêtre, en segments droits. `ajouter_route` refuse la
## diagonale : on lui donne donc les COINS, pas les cases.
static func _tracer(v: Ville2, f: Rect2i, cases: Array, charte: Dictionary) -> void:
	var coins: Array = []
	var dedans: Array = []
	for e in cases:
		var c: Vector2i = e
		if f.has_point(c):
			dedans.append(c - f.position)
		else:
			_poser_la_voie(v, dedans, coins)
			dedans = []
	_poser_la_voie(v, dedans, coins)

static func _poser_la_voie(v: Ville2, dedans: Array, coins: Array) -> void:
	if dedans.size() < 2: return
	var pts: Array = [dedans[0]]
	for i in range(1, dedans.size() - 1):
		var a: Vector2i = dedans[i - 1]
		var b: Vector2i = dedans[i]
		var c: Vector2i = dedans[i + 1]
		if (b - a) != (c - b): pts.append(b)
	pts.append(dedans[dedans.size() - 1])
	v.ajouter_route(Ville2.R_RUE, pts, "")

# ──────────────────────────────────────────────────────────────── LE SOL

static func _le_sol(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		vus: Array) -> void:
	if vus.is_empty(): return
	for j in v.taille.y:
		for i in v.taille.x:
			var l := Vector2i(i, j)
			var kk := v.indice(l)
			if v.eau[kk] == 1: continue
			var k := PLAN.quartier_en(plan, ctx, f.position + l)
			if k < 0: continue
			var charte := REGLES.charte(_genre(plan, k))
			v.matiere[kk] = int(charte["sol"])

# ──────────────────────────────────────────────────────────────── LES LOTS

## ⭐ BORDER UNE RUE. On marche le long du trottoir, des deux côtés, et on avance
## de l'EMPRISE RÉELLE du modèle posé — jamais d'un pas fixe. C'est la règle du
## cahier (« le lot s'adapte au modèle ») et c'est ce qui donne un front de rue
## sans fente ni chevauchement.
##
## ⚠ ON SAUTE LES COUDES. Une parcelle à cheval sur un virage n'a pas de façade :
## elle sortirait de travers, un coin dans la chaussée.
static func _border(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		k: int, cases: Array) -> void:
	var charte := REGLES.charte(_genre(plan, k))
	if (charte["sacs"] as Array).is_empty(): return
	var genre := _genre(plan, k)
	var recul := int(charte["recul"])
	var densite := float(charte["densite"])
	var alea := RandomNumberGenerator.new()
	var a0: Vector2i = cases[0]
	for cote in [1, -1]:
		alea.seed = _graine(a0.x, a0.y, k * 2 + (1 if cote > 0 else 0))
		var i := 0
		while i < cases.size() - 1:
			var b: Vector2i = cases[i]
			var d: Vector2i = (cases[i + 1] as Vector2i) - b
			# le coude : la direction change à la case suivante
			if i + 2 < cases.size() and ((cases[i + 2] as Vector2i) - (cases[i + 1] as Vector2i)) != d:
				i += 1
				continue
			var n: Vector2i = Vector2i(-d.y, d.x) * cote
			var q := _face_vers(-n)
			if alea.randf() >= densite:
				# Le trou voulu par la charte : la largeur d'un lot moyen.
				i += 2
				continue
			# ⭐ TROIS TIRAGES AVANT DE RENONCER, ET UN PAS D'UNE CASE SI RIEN
			# NE PASSE. Photographié sur la Gare Centrale (19/09) : le front de
			# rue du centre était troué de dalles blanches larges comme un
			# immeuble. La cause : un seul tirage par place, et quand la pièce
			# tirée ne tenait pas (une réserve, le lot d'en face au coin, la
			# voie ferrée), on avançait de TOUTE SA LARGEUR sans rien poser —
			# là où un immeuble étroit serait entré. On retire deux fois, et si
			# rien n'entre on avance d'une seule case.
			var avance := 1
			for essai in 3:
				var m := _tirer(charte, alea)
				if m == "": continue
				var e := KitVille2.emprise_tournee(m, q)
				# Le coin du lot, en demi-cases ABSOLUES, collé au bord de la
				# case de rue puis reculé de `recul`.
				var hx := 0
				var hy := 0
				if n.x > 0: hx = (b.x + 1) * 2 + recul
				elif n.x < 0: hx = b.x * 2 - e.x - recul
				else: hx = b.x * 2
				if n.y > 0: hy = (b.y + 1) * 2 + recul
				elif n.y < 0: hy = b.y * 2 - e.y - recul
				else: hy = b.y * 2
				if _poser(v, f, m, hx, hy, e, q, genre):
					_devant_la_maison(v, f, charte, alea, b, n, genre)
					avance = maxi(1, (e.x if absi(d.x) > 0 else e.y) / 2)
					break
			i += avance
	return

## La pose, en demi-cases absolues → demi-cases de la fenêtre. Hors fenêtre, on
## ne pose pas — mais le tirage a bien avancé (voir l'en-tête).
static func _poser(v: Ville2, f: Rect2i, m: String, hx: int, hy: int, e: Vector2i,
		q: int, genre: String) -> bool:
	var lx := hx - f.position.x * 2
	var ly := hy - f.position.y * 2
	if lx < 0 or ly < 0 or lx + e.x > v.taille.x * 2 or ly + e.y > v.taille.y * 2: return false
	if not Lotisseur.terrain_libre(v, lx, ly, e): return false
	if not _assez_plat(v, lx, ly, e): return false
	v.ajouter_lot(m, lx, ly, e.x, e.y, q, genre)
	return true

## ⭐⭐ ON NE BÂTIT QUE SUR DU PLAT — « certains bâtiments flottent ».
##
## `Lotisseur.terrain_libre` exige que les cases d'une parcelle soient au même
## PALIER. Sur un témoin, où le sol est un plateau, palier égal veut dire
## altitude égale. Sur le pays, le terrain est CONTINU : deux cases voisines
## partagent le même palier arrondi et diffèrent d'un mètre en altitude réelle.
## Le moteur pose alors le bâtiment à l'altitude de sa case centrale, et le coin
## aval décolle.
##
## ⚠ ET ON NE TERRASSE PAS. J'ai d'abord aplani la parcelle à l'altitude de son
## centre : `poser_terre` remet aussi `eau` à zéro et écrase le relief case par
## case, et le quartier entier s'est transformé en un empilement de dalles
## grises — la ville avait perdu ses bâtiments et son sol. Refuser un terrain
## trop penché ne casse rien : on perd quelques maisons sur les fortes pentes,
## là où une vraie ville n'en met pas non plus.
const PENTE_TOLEREE := 0.9           ## écart d'altitude admis sous une parcelle, en unités

static func _assez_plat(v: Ville2, hx: int, hy: int, e: Vector2i) -> bool:
	var mini := 1.0e20
	var maxi := -1.0e20
	for b in range(0, e.y + 1):
		for a in range(0, e.x + 1):
			var c := Vector2i(floori(float(hx + a) * 0.5), floori(float(hy + b) * 0.5))
			if not v.dedans(c): return false
			var y := v.sol(c)
			mini = minf(mini, y)
			maxi = maxf(maxi, y)
	return maxi - mini <= PENTE_TOLEREE

static func _tirer(charte: Dictionary, alea: RandomNumberGenerator) -> String:
	var t := alea.randf()
	for e in charte["sacs"]:
		var f: Array = e
		if t <= float(f[0]):
			var liste: Array = f[1]
			if liste.is_empty(): return ""
			return String(liste[alea.randi() % liste.size()])
	return ""

static func _face_vers(d: Vector2i) -> int:
	if d.y < 0: return 0
	if d.y > 0: return 2
	if d.x > 0: return 3
	return 1

# ──────────────────────────────────────────────────────────────── LE MOBILIER

static func _mobilier(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		k: int, cases: Array) -> void:
	var charte := REGLES.charte(_genre(plan, k))
	var lampes := int(charte["lampes"])
	var autos := int(charte["voitures"])
	var arbres := float(charte["arbres"])
	var essence: Array = charte["essence"]
	var a0: Vector2i = cases[0]
	var alea := RandomNumberGenerator.new()
	alea.seed = _graine(a0.x, a0.y, k * 7 + 3)
	for i in cases.size():
		var c: Vector2i = cases[i]
		var l := c - f.position
		if not v.dedans(l): continue
		# ⚠ UNE CASE PRISE PAR UN BÂTIMENT N'A PAS DE TROTTOIR. Un lampadaire,
		# une cabine ou un arbre pouvait se retrouver dans un salon. Et c'est
		# `demi_libre` qu'il faut interroger, pas `lot_sur` — voir
		# `_case_de_mobilier` pour pourquoi le second ment pendant le
		# remplissage.
		if not v.demi_libre(l.x * 2, l.y * 2, 2, 2): continue
		if lampes > 0 and i % lampes == 0:
			v.ajouter_objet("lampadaire", (float(l.x) + 0.12) * CASE,
				(float(l.y) + 0.12) * CASE, 0.0)
		if autos > 0 and i % autos == 3:
			var m := String(KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()])
			v.ajouter_objet(m, (float(l.x) + 0.78) * CASE, (float(l.y) + 0.5) * CASE,
				0.0)
		# ⚠ UN ARBRE NE POUSSE PAS SUR LE TROTTOIR DE LA RUE QU'IL BORDE.
		# Il se plantait sur la case de RUE, à quatre-vingt-six centièmes — donc
		# pile sur la bordure, et deux troncs sortaient du béton juste devant un
		# passage piéton (client, 16/09). On le met sur la case d'à côté, celle
		# qui n'est ni chaussée ni bâtie ; si elle n'existe pas, pas d'arbre.
		if arbres > 0.0 and alea.randf() < arbres:
			var ou := _a_cote_libre(v, l)
			if ou != Vector2i(-999, -999):
				v.ajouter_objet(String(essence[alea.randi() % essence.size()]),
					(float(ou.x) + 0.5) * CASE, (float(ou.y) + 0.5) * CASE, 0.0)

## ⚠ UN SAC PAR GENRE, PAS UN SAC PAR FENÊTRE. `TEINTES.couvrir` tire sans remise
## dans un sac : deux fenêtres qui n'ont pas les mêmes lots dans le même ordre
## tireraient des couleurs différentes pour le même toit. Tant que le tirage est
## par genre et par graine fixe, la série est la même — ce n'est pas parfait au
## toit près (l'ordre des lots dépend de la fenêtre), mais la GAMME, elle, ne
## bouge pas, et c'est ce qui se voit à vingt kilomètres.
static func _les_teintes(plan: Dictionary, v: Ville2, f: Rect2i, vus: Array) -> void:
	var faits := {}
	for k in vus:
		var genre := _genre(plan, k)
		if faits.has(genre): continue
		faits[genre] = true
		var charte := REGLES.charte(genre)
		var alea := RandomNumberGenerator.new()
		alea.seed = _graine(genre.hash(), 17, 4021)
		# ⚠ PAS DE `get(nom)` SUR UNE CLASSE GDSCRIPT. Une constante de classe ne
		# se lit pas par son nom : `ATLAS.get("VIEILLE")` rend `null`, le sac de
		# tirage part sur une gamme vide et la génération TOURNE SANS FIN — 560
		# secondes sans un message. Deux tables explicites, et c'est réglé.
		var toits: Array = GAMMES_TOIT.get(String(charte["toits"]), [])
		if not toits.is_empty():
			TEINTES.couvrir(v, alea, genre, toits)
		var murs: Array = GAMMES_MUR.get(String(charte["murs"]), [])
		if not murs.is_empty():
			TEINTES.peindre(v, alea, genre, murs, float(charte["garder"]))

## LE QUARTIER, PEINT CASE PAR CASE. ⚠ PAS `peindre_quartier(Rect2i)` : une tache
## n'a pas de rectangle, c'est tout l'objet de la refonte.
##
## L'indice écrit dans la ville est celui de la table LOCALE `v.quartiers`, pas
## celui du plan : le jeu lit `v.quartier_de[k]` puis `v.quartiers[i]`, et il ne
## connaît pas le plan du pays.
static func _peindre(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		vus: Array) -> void:
	var rang := {}
	for k in vus:
		var z: Dictionary = plan["quartiers"][k]
		rang[k] = v.quartiers.size()
		v.quartiers.append({"nom": String(z["nom"]), "genre": String(z["g"]), "gang": -1})
	for j in v.taille.y:
		for i in v.taille.x:
			var k2 := PLAN.quartier_en(plan, ctx, f.position + Vector2i(i, j))
			if k2 < 0 or not rang.has(k2): continue
			v.quartier_de[j * v.taille.x + i] = int(rang[k2])

## ⭐ LES QUATRE REPÈRES, ET LA RÈGLE QUI LES REND POSSIBLES À CHEVAL SUR DEUX
## FENÊTRES : ON CHERCHE LEUR PLACE DANS LE PLAN, PAS DANS LA FENÊTRE.
##
## La tentation est de chercher en spirale le premier terrain libre — sauf que
## « libre » se lit dans la grille de la fenêtre : une case hors fenêtre n'est
## jamais libre, donc deux fenêtres voisines choisiraient DEUX PLACES
## DIFFÉRENTES pour la même église, et le joueur la verrait sauter en marchant.
## On choisit donc sur des critères que le plan connaît — à terre, dans le bon
## quartier — et la fenêtre ne décide plus que de POSER ou NON.
## ⚠ IL N'Y A PAS DE MODÈLE DE COMMISSARIAT. Le client en demande un (« Central
## de police ») et le dossier `piksl/` n'en contient pas : gare, hôpital,
## supérette, caserne, église, garage, compacteur, cabine. En attendant le
## modèle, le commissariat est un immeuble du kit POSÉ COMME REPÈRE — il a son
## genre de lot (`commissariat`), donc sa place réservée, son nom de lieu et son
## point sur le radar ; le jour où le modèle arrive, une ligne change.
const COMMISSARIAT := "batiments/building-n"

const REPERES_PAR_GENRE := {
	"centre": [["hopital", -7, -5], ["caserne", 9, 6], ["supermarche", -10, 8],
		["commissariat", 4, -9], ["eglise", -13, -11]],
	# ⭐⭐ UN HÔPITAL PAR QUARTIER HABITÉ (21/09). C'est là qu'on rouvre les
	# yeux en tombant (`Carnage._relever` → `Plan.hopital_le_plus_proche`,
	# rayon d'un secteur et demi) : sans hôpital dans le coin, on se réveille
	# trois rues plus loin, au hasard, sans repère. Le pays n'en posait que
	# dans les quartiers « centre » et « campus » — donc aucun dans les
	# villages des îles, là même où l'on commence la partie, dans un taudis.
	# L'industrie et le port n'en ont toujours pas : on ne loge personne dans
	# une zone de hangars.
	"vieille_ville": [["eglise", 2, -3], ["commissariat", -6, 6], ["hopital", 8, 7]],
	"pavillons": [["eglise", 6, -8], ["supermarche", -12, 9], ["caserne", 14, 11],
		["hopital", -9, -10]],
	"chaud": [["caserne", 7, 7], ["commissariat", -7, -6], ["hopital", -9, 8]],
	"industrie": [["caserne", -8, 5], ["garage", 9, -6], ["compacteur", 12, 8]],
	"port": [["caserne", -8, 5], ["garage", 9, -6]],
	"plage": [["supermarche", 5, -7], ["caserne", -9, 6], ["hopital", 10, 8]],
	"campus": [["supermarche", 8, 9], ["hopital", -9, -7]],
	"bidonville": [["supermarche", 6, 5], ["hopital", -7, -6]],
}

## ⭐⭐⭐ UN REPÈRE TOUS LES QUARANTE CASES, PAS UN PAR QUARTIER.
##
## Un quartier du pays n'est pas un quartier de la ville dessinée : « Les
## Faubourgs » mesure 300 × 290 cases — six kilomètres de pavillonnaire — et
## recevait UN hôpital, UNE supérette, UNE église. Le jeu, lui, cherche ce
## dont il a besoin dans un rayon d'un secteur et demi (`Plan.RAYON_*`,
## `hopital_le_plus_proche` : 6 400 px, soit 32 cases) : au milieu d'un tel
## quartier, il ne trouvait rien, et on rouvrait les yeux au hasard, trois
## rues plus loin, sans repère.
##
## La liste du genre se REPÈTE donc sur un damier de `PAVE_REPERES` cases,
## calé sur le CENTRE DU QUARTIER (donc absolu : deux fenêtres voisines
## trouvent les mêmes ancres, et un repère à cheval sur la couture se pose au
## même endroit des deux côtés). Un petit quartier n'a qu'une ancre et ne
## change pas. Chaque ancre garde le décalage propre au repère : l'hôpital et
## la caserne ne se marchent pas dessus d'un pavé à l'autre.
##
## ⚠ ON NE PARCOURT QUE LES ANCRES DE LA FENÊTRE (plus douze cases de marge) :
## balayer les trois cents cases du quartier pour chaque tuile coûterait
## quatre-vingts recherches en spirale pour rien.
const PAVE_REPERES := 40

static func _les_reperes(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		k: int, prises: Dictionary) -> void:
	var z: Dictionary = plan["quartiers"][k]
	var liste: Array = REPERES_PAR_GENRE.get(String(z["g"]), [])
	if liste.is_empty(): return
	var c := PLAN.case_de(z["c"])
	var r := PLAN.case_de(z.get("r", [0, 0]))
	var proche := f.grow(12)
	var ancres: Array = []
	var na := Vector2i(maxi(0, r.x / PAVE_REPERES), maxi(0, r.y / PAVE_REPERES))
	for aj in range(-na.y, na.y + 1):
		for ai in range(-na.x, na.x + 1):
			var ancre := c + Vector2i(ai, aj) * PAVE_REPERES
			if proche.has_point(ancre): ancres.append(ancre)
	for a0 in ancres:
		_les_reperes_autour(plan, ctx, v, f, k, prises, z, liste, a0)

static func _les_reperes_autour(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		k: int, prises: Dictionary, z: Dictionary, liste: Array, c: Vector2i) -> void:
	for e in liste:
		var d: Array = e
		var genre := String(d[0])
		var modele := COMMISSARIAT if genre == "commissariat" \
			else String(KitVille2.REPERES.get(genre, ""))
		if modele == "": continue
		var vise := c + Vector2i(int(d[1]), int(d[2]))
		var q := 0
		var emp := KitVille2.emprise_tournee(modele, q)
		var ou := _place_de_repere(plan, ctx, k, vise, prises,
			Vector2i((emp.x + 1) / 2, (emp.y + 1) / 2))
		if ou.x < -9000: continue
		var hx := (ou.x - f.position.x) * 2
		var hy := (ou.y - f.position.y) * 2
		if hx < 0 or hy < 0 or hx + emp.x > v.taille.x * 2 or hy + emp.y > v.taille.y * 2:
			continue
		if not Lotisseur.terrain_libre(v, hx, hy, emp): continue
		v.ajouter_lot(modele, hx, hy, emp.x, emp.y, q, genre)
		# ⚠⚠ LE LIEU SE RANGE EN CASES DE LA FENÊTRE, PAS EN CASES DU PAYS.
		# `ou` vient du PLAN, donc en absolu (c'est ce qu'il faut pour que deux
		# fenêtres voisines posent le repère au même endroit) — mais le lot,
		# lui, est déjà converti (`hx`, `hy`), et le lieu ne l'était pas. Sur
		# une tuile dont le coin est en (600,200), l'hôpital se VOYAIT à sa
		# place et le jeu le cherchait trois mille cases plus loin, en pleine
		# mer : sur le pays, AUCUNE supérette, AUCUN hôpital, AUCUNE caserne,
		# AUCUN commissariat n'était trouvable (`lieux_autour`), donc ni F, ni
		# GPS, ni pastille au radar. Mesuré sur l'Île de la Baie : la supérette
		# « la plus proche » à 624 cases, au large. Un témoin (fenêtre unique,
		# coin à zéro) ne montrait rien de tout ça.
		v.ajouter_lieu(genre, (float(ou.x - f.position.x) + 0.5) * CASE,
			(float(ou.y - f.position.y) + 0.5) * CASE, {"nom": String(z["nom"])})

## La place d'un repère : la première case, en spirale carrée depuis la visée,
## qui soit à terre ET dans le bon quartier. Deux critères du PLAN — donc la même
## réponse dans toutes les fenêtres.
## ⚠⚠ ET IL FAUT CHERCHER AVEC L'EMPRISE, PAS AVEC UN POINT. Le premier jet
## cherchait une CASE à terre dans le bon quartier, puis posait un hôpital de
## trois cases dessus : une case sur deux tombait sur une chaussée, `terrain_libre`
## refusait, et le repère disparaissait EN SILENCE. Sur la fenêtre d'essai, un
## repère posé sur onze. On teste donc tout le rectangle, chaussées comprises —
## et toujours avec des critères que le PLAN connaît, pour que deux fenêtres
## voisines trouvent la même place.
static func _place_de_repere(plan: Dictionary, ctx: Dictionary, k: int,
		vise: Vector2i, prises: Dictionary, emprise: Vector2i) -> Vector2i:
	for r in 16:
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r: continue
				var c := vise + Vector2i(di, dj)
				if _emprise_libre(plan, ctx, k, c, prises, emprise): return c
	return Vector2i(-9999, -9999)

static func _emprise_libre(plan: Dictionary, ctx: Dictionary, k: int, c: Vector2i,
		prises: Dictionary, emprise: Vector2i) -> bool:
	# Une case de marge tout autour : un hôpital collé à la chaussée n'a pas de
	# parvis, et son angle mord le trottoir d'en face au moindre arrondi.
	for j in range(-1, emprise.y + 1):
		for i in range(-1, emprise.x + 1):
			var d := c + Vector2i(i, j)
			if prises.has(d): return false
			if not PLAN.terre_en(plan, ctx, d): return false
			if i < 0 or j < 0 or i >= emprise.x or j >= emprise.y: continue
			if PLAN.quartier_en(plan, ctx, d) != k: return false
	return true

## ⭐ CE QU'IL Y A DEVANT UNE MAISON, et c'est ce qui sépare un lotissement d'un
## alignement de boîtes : une allée, une voiture dessus, une boîte aux lettres au
## bord de la rue. Trois objets par maison, pas un de plus — à treize taches de
## pavillonnaire sur le pays, chaque objet en trop se paie par million.
##
## ⚠ SEULEMENT LÀ OÙ LA CHARTE A LAISSÉ DE L'HERBE. Devant un immeuble de centre-
## ville il y a un trottoir, pas une allée de garage.
const ALLEE := "pavillons/driveway-long"

## Marquer une case comme prise, dans le registre vivant des demi-cases : c'est
## le même registre que celui des parcelles, donc le lotisseur la respectera.
static func _reserver_la_case(v: Ville2, c: Vector2i) -> void:
	for b in 2:
		for a in 2:
			v.demi_prises[Vector2i(c.x * 2 + a, c.y * 2 + b)] = true

## Une case où l'on a le droit de poser du mobilier de jardin : dans la fenêtre,
## sur la terre, et ni dans un bâtiment ni sur la chaussée.
##
## ⚠⚠ `lot_sur()` NE SERT À RIEN ICI, ET C'EST CE QUI M'A FAIT CROIRE QUE LA
## CORRECTION MARCHAIT ALORS QU'ELLE EMPIRAIT LE DÉFAUT. `_lot_de`, le registre
## que `lot_sur` interroge, n'est reconstruit que par `rasteriser()` — c'est-à-
## dire UNE FOIS, avant que le remplisseur ne pose le moindre bâtiment. Pendant
## tout le remplissage il ne contient que des −1 : il répond « libre » partout,
## y compris au milieu de la maison posée trois lignes plus haut. Le registre
## VIVANT, celui qui sait, est `demi_prises`, qu'on lit par `demi_libre` — c'est
## déjà ce que fait `Lotisseur.terrain_libre`, et pour la même raison.
static func _case_de_mobilier(v: Ville2, c: Vector2i) -> bool:
	if not v.dedans(c): return false
	if not v.terre(c): return false
	if v.carte.route(c) or v.carte.case_prise(c): return false
	return v.demi_libre(c.x * 2, c.y * 2, 2, 2)

static func _devant_la_maison(v: Ville2, f: Rect2i, charte: Dictionary,
		alea: RandomNumberGenerator, b: Vector2i, n: Vector2i, genre: String) -> void:
	if int(charte["sol"]) != Ville2.M_HERBE: return
	if int(charte["recul"]) <= 0: return
	var l := b - f.position
	if not v.dedans(l): return
	# ⚠⚠ L'ALLÉE PARTAIT DU BORD DU BÂTIMENT, DONC À MOITIÉ DEDANS. Son origine
	# était le centre de la case de la maison plus une DEMI-case : c'est-à-dire
	# pile sur le mur de façade. Mesuré : six cent soixante-cinq allées, cent
	# vingt-deux bornes et cent quarante voitures plantées dans un bâtiment sur
	# une seule fenêtre — « certains bâtiments se chevauchent », et ce n'étaient
	# pas deux lots, c'était le mobilier qui entrait dans les murs.
	#
	# L'allée commence donc UNE CASE ENTIÈRE devant la façade, sur la case du
	# recul, et chaque pièce vérifie sa propre case avant de se poser : le
	# lotisseur ne connaît que les lots, personne ne relisait pour le mobilier.
	var devant := l + n
	if not _case_de_mobilier(v, devant): return
	# ⚠⚠ ON RÉSERVE LA CASE DE L'ALLÉE, SINON LA MAISON D'APRÈS SE POSE DESSUS.
	# Mesuré après l'allongement des rues : trois objets se retrouvaient dans un
	# mur. La cause n'était plus le registre — il disait vrai à l'instant du
	# test — mais l'ORDRE : l'allée de la maison A est posée, puis la maison B
	# prend la même case, et l'allée se retrouve dans son salon. Une case de
	# jardin doit donc être PRISE comme l'est une parcelle.
	_reserver_la_case(v, devant)
	var x0 := (float(devant.x) + 0.5) * CASE
	var z0 := (float(devant.y) + 0.5) * CASE
	var r := 0.0 if n.x == 0 else PI * 0.5
	for t in 2:
		var c := devant + n * t
		if not _case_de_mobilier(v, c): break
		v.ajouter_objet(ALLEE, (float(c.x) + 0.5) * CASE, (float(c.y) + 0.5) * CASE, r)
	if alea.randf() < 0.55:
		var m := String(KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()])
		v.ajouter_objet(m, x0, z0, r)
	if alea.randf() < 0.5:
		# La boîte aux lettres se décale LE LONG de la rue, pas en travers : de
		# côté elle rentrait dans la maison une fois sur deux.
		var cote := Vector2i(-n.y, n.x)
		var bl := devant + cote
		if _case_de_mobilier(v, bl):
			v.ajouter_objet("borne", (float(bl.x) + 0.5) * CASE,
				(float(bl.y) + 0.5) * CASE, 0.0)

## Le registre des chaussées DÉJÀ posées dans la fenêtre — les axes du plan,
## rastérisés avant que le remplisseur n'arrive. En cases ABSOLUES : c'est la
## seule façon que les rues d'un quartier à cheval sur deux fenêtres se coupent
## au même endroit des deux côtés de la couture.
##
## ⚠ LA VOIE RAPIDE N'Y ENTRE PAS. C'est le seul axe qui a le droit d'avoir une
## chaussée parallèle — une autoroute a deux sens séparés et ses contre-allées,
## et c'est même à ça qu'on la reconnaît d'en haut.
## ⚠⚠⚠ LE REGISTRE SE LIT DANS LE PLAN, PAS DANS LA FENÊTRE — et c'est la
## différence entre un pays et un pays qui change de forme quand on le regarde
## autrement.
##
## Il lisait la grille de la `Ville2`, donc les axes VISIBLES DANS LA FENÊTRE.
## Une rue qui longe un axe passant juste dehors ne voyait rien et se posait ;
## la fenêtre voisine, elle, voyait l'axe et la coupait. Mesuré en fabriquant
## deux fenêtres qui se chevauchent et en comparant la zone commune case par
## case : le terrain était identique au centième près et l'eau aussi, mais
## QUARANTE ET UNE cases de chaussée existaient d'un cadrage et pas de l'autre.
## Une rue qui apparaît quand on déplace la caméra.
##
## On rastérise donc les axes du PLAN sur la fenêtre ÉLARGIE : le plan ne dépend
## d'aucun cadrage, donc le registre non plus, et les deux fenêtres prennent la
## même décision sur la même rue.
##
## ⚠ LA VOIE RAPIDE N'Y ENTRE PAS. C'est le seul axe qui a le droit d'avoir une
## chaussée parallèle — une autoroute a deux sens séparés et ses contre-allées,
## et c'est même à ça qu'on la reconnaît d'en haut.
const MARGE_REGISTRE := 16

static func _les_chaussees(plan: Dictionary, f: Rect2i) -> Dictionary:
	var prises := {}
	# Les axes du plan, y compris ceux qui passent juste à côté de la fenêtre.
	var large := f.grow(MARGE_REGISTRE)
	for r in plan.get("routes", []):
		var d: Dictionary = r
		if String(d.get("classe", "")) == PLAN.V_PRIMAIRE: continue
		var pts: Array = d["points"]
		for k in range(1, pts.size()):
			var a := PLAN.case_de(pts[k - 1])
			var b := PLAN.case_de(pts[k])
			var pas := (b - a).sign()
			if pas == Vector2i.ZERO: continue
			var c := a
			if large.has_point(c): prises[c] = true
			var coude := Vector2i(b.x, a.y)
			for cible0 in [coude, b]:
				var cible: Vector2i = cible0
				var p := (cible - c).sign()
				while c != cible:
					c += p
					if large.has_point(c): prises[c] = true
	return prises

## ⭐ ÉCARTER LA RUE DES CHAUSSÉES EXISTANTES — ET LA LAISSER LES TRAVERSER.
##
## ⚠⚠ C'EST LA DISTINCTION QUI FAIT TOUT, ET LE PREMIER JET L'AVAIT RATÉE : une
## rue qui CROISE un axe a, le temps d'une case, de la chaussée à sa gauche et à
## sa droite — exactement la même lecture qu'un doublon. Couper là supprimait un
## carrefour sur deux et faisait tomber le quartier de 426 à 215 bâtiments.
##
## Une DOUBLE VOIE, c'est une chaussée qui LONGE la nôtre : il faut donc qu'elle
## soit là sur PLUSIEURS cases d'affilée du même côté. Trois suffisent — un
## carrefour n'en donne qu'une, un doublon les donne toutes.
## ⭐⭐⭐ UNE RUE VA JUSQU'À UNE AUTRE RUE — sinon elle meurt dans un champ.
##
## Les rues d'un quartier sont une grille calée sur SON `pas` : cinq cases au
## centre, huit en pavillonnaire. Deux quartiers voisins n'ont donc pas le même
## peigne, leurs rues ne tombent pas en face, et chacune s'arrête à la limite de
## son quartier — dans l'herbe. C'est l'origine des culs-de-sac que j'ai comptés
## (124 sur une fenêtre de 110 cases) et des raccords biscornus entre une rue
## étroite et une avenue.
##
## ⚠ J'AI D'ABORD ESSAYÉ UN ANNEAU DE DESSERTE autour de chaque quartier, et il
## n'a rien donné : mesuré, +27 cases de chaussée et UN cul-de-sac en moins. La
## raison est bonne — l'anneau longe la rue la plus extérieure de la grille, et
## la règle anti-double-voie le coupe sur presque toute sa longueur. Deux
## chaussées parallèles à une case l'une de l'autre, c'est précisément ce qu'on
## refuse depuis le 15/09.
##
## La réponse qui marche prend le problème par l'autre bout : au lieu d'ajouter
## une voie pour ramasser les bouts, on PROLONGE chaque bout jusqu'à ce qu'il
## touche une chaussée existante. Une rue qui trouve une avenue à six cases va
## la chercher ; une rue qui ne trouve rien reste telle quelle, et le seuil
## `MIN_RUE` s'en occupe.
## ⚠ ONZE CASES, MESURÉ. À sept, les culs-de-sac tombent de 124 à 62 ; à onze,
## à 56 ; au-delà la rue traverse un pâté entier pour aller chercher une avenue
## qu'elle n'avait aucune raison de rejoindre. Onze cases, c'est deux cent vingt
## mètres : la distance qu'un lotisseur accepte de faire pour raccorder.
const ALLONGE := 11

static func _prolonger(bout: Array, prises: Dictionary) -> Array:
	if bout.size() < 2: return bout
	var sortie: Array = bout.duplicate()
	# Les deux extrémités, chacune dans la direction où la rue filait.
	for cote in [1, -1]:
		var n := sortie.size()
		var fin: Vector2i = sortie[n - 1] if cote == 1 else sortie[0]
		var avant: Vector2i = sortie[n - 2] if cote == 1 else sortie[1]
		var d := (fin - avant).sign()
		if d == Vector2i.ZERO or (d.x != 0 and d.y != 0): continue
		var ajout: Array = []
		var c := fin
		for _t in ALLONGE:
			c += d
			ajout.append(c)
			if prises.has(c): break
		# On ne garde l'allonge QUE si elle a trouvé quelque chose. Sinon on
		# vient d'allonger un moignon, ce qui est pire que de le laisser court.
		if ajout.is_empty() or not prises.has(ajout[ajout.size() - 1]): continue
		if cote == 1:
			for a in ajout: sortie.append(a)
		else:
			ajout.reverse()
			for a2 in ajout: sortie.push_front(a2)
	return sortie

## En deçà, ce n'est pas une rue, c'est une miette laissée par la découpe.
## Cinq cases, c'est cent mètres : de quoi border trois maisons.
const MIN_RUE := 5

const LONGE := 3

## Les morceaux d'une rue qui restent hors d'un rectangle interdit.
static func _hors_de(cases: Array, interdit: Rect2i) -> Array:
	var sortie: Array = []
	var courant: Array = []
	for c in cases:
		if interdit.has_point(c):
			if not courant.is_empty(): sortie.append(courant)
			courant = []
		else:
			courant.append(c)
	if not courant.is_empty(): sortie.append(courant)
	return sortie

static func _ecarter(cases: Array, prises: Dictionary) -> Array:
	var sortie: Array = []
	var courant: Array = []
	for i in cases.size():
		var c: Vector2i = cases[i]
		var d := Vector2i(0, 1)
		if i + 1 < cases.size():
			d = (cases[i + 1] as Vector2i) - c
		elif i > 0:
			d = c - (cases[i - 1] as Vector2i)
		var n := Vector2i(-d.y, d.x)
		var double := false
		for cote in [1, -1]:
			var suite := 0
			for t in LONGE:
				if prises.has(c + d * t + n * cote): suite += 1
			if suite >= LONGE:
				double = true
				break
		if not double:
			courant.append(c)
		else:
			if courant.size() >= 8: sortie.append(courant)
			courant = []
	if courant.size() >= 8: sortie.append(courant)
	return sortie

# ──────────────────────────────────────────────────────── LES STATIONS

## ⭐ CE QU'IL Y A AU PIED D'UNE STATION.
##
## Une gare de train est un BÂTIMENT (`piksl/gare`, 8 cases de long) ; un arrêt
## de métro, de tram ou de bus est du MOBILIER — un abribus, un banc, un rack à
## vélos et deux ou trois vélos dessus. La différence n'est pas une question de
## goût : une gare a une emprise et doit réserver son terrain, un abribus se
## pose sur le trottoir et ne réserve rien.
##
## ⚠ LES MODÈLES `pxl/` SE POSENT À LEUR TAILLE NATURELLE — hauteur zéro. Ils
## sont dessinés pour ce jeu, à l'échelle de la case ; leur imposer une hauteur
## les écraserait ou les étirerait. C'est la règle déjà payée sur les cabanes du
## bidonville.
const ABRIBUS := "pxl/abribus"
const RACK := "pxl/rack-velos"
const VELO := "pxl/velo"

## Les gares : des BÂTIMENTS, donc posés avec les repères, avant le tissu.
static func _les_gares(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		prises: Dictionary) -> void:
	for e in plan.get("stations", []):
		var st: Dictionary = e
		var reseau := String(st.get("reseau", "bus"))
		# ⭐ LE TRAIN EST SOUS TERRE (client, 21/09) — mais sa GARE reste en
		# surface : c'est par elle qu'on descend, et un bâtiment de huit cases
		# est un repère de quartier. Le métro, lui, roule maintenant à ciel
		# ouvert et prend les quais.
		if reseau not in PLAN.RESEAUX_DE_SURFACE and reseau != "train" \
			and reseau != "train2": continue
		if not bool(st.get("principale", false)): continue
		var c := PLAN.case_de(st["c"])
		if not f.grow(12).has_point(c): continue
		_la_gare(v, f, c, String(st.get("nom", "")))

## De combien on rentre le mobilier depuis le bord de la case : assez pour ne
## pas mordre sur la chaussée, assez peu pour la toucher.
const MARGE_TROTTOIR := 2.2

## La première case voisine où l'on peut planter quelque chose : hors chaussée,
## hors bâtiment, dans la fenêtre. `(-999, -999)` s'il n'y en a pas.
static func _a_cote_libre(v: Ville2, l: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var n: Vector2i = l + d
		if _case_de_mobilier(v, n): return n
	return Vector2i(-999, -999)

## ⭐⭐⭐ LE CŒUR DES ÎLOTS — « les cœurs d'îlots sont vides ».
##
## Le lotisseur BORDE la rue : il pose les façades le long du trottoir et laisse
## le milieu du pâté intact. C'est la bonne façon de bâtir une rue, et ça laisse
## une clairière de béton nu au centre de chaque îlot — vu d'en haut, la moitié
## du centre-ville est une dalle grise vide.
##
## On ne bâtit pas ce milieu : un bâtiment de plus au centre d'un îlot n'aurait
## ni rue ni entrée. On le MEUBLE, comme un vrai arrière d'immeuble : des
## voitures garées, une benne, quelques arbres, un banc.
##
## ⚠ SEULEMENT LES CASES VRAIMENT ENCLAVÉES. Une case libre au bord de l'îlot
## donne sur la rue : c'est un trottoir, pas une cour. On ne meuble que celles
## dont les QUATRE voisines sont prises — par un bâtiment, par une chaussée ou
## par le bord de la fenêtre. Sinon on remplit des pelouses et des parvis qui
## n'ont rien demandé.
##
## ⚠⚠ ET LE TIRAGE SE FAIT SUR LA POSITION ABSOLUE. Un îlot à cheval sur deux
## fenêtres doit recevoir la même cour des deux côtés de la couture, sinon la
## voiture change de place quand on marche.
const BENNE := "benne"
const COUR_VOITURES := 0.42          ## part des cases de cour qui reçoivent des voitures
const COUR_ARBRES := 0.30
const COUR_BENNE := 0.12
const COUR_OUVERTE_VIDE := 0.5     ## part des cases de cœur NON enclavées qu'on laisse nues

## ⭐ LA ZONE INDUSTRIELLE SE MEUBLE PLUS LARGE (19/09). Ses pâtés sont grands
## et ses hangars espacés : presque aucune case n'y est « enclavée » au sens
## des quatre voisines prises, et la photo de contrôle de la Zone de l'Ouest
## montrait des hectares de dalle blanche entre les usines. Là, toute case
## libre qui n'est pas collée à une rue est une cour d'usine : camions garés,
## conteneurs, benne — au même tirage par position que les cœurs.
const INDUSTRIE_CAMIONS := 0.30
const INDUSTRIE_CONTENEURS := 0.22
const INDUSTRIE_BENNE := 0.08
const CAMIONS := ["voitures/truck", "voitures/delivery", "voitures/box"]

static func _cour_d_usine(v: Ville2, l: Vector2i) -> bool:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var n: Vector2i = l + d
		if v.dedans(n) and v.carte.route(n): return false
	return true

static func _les_coeurs(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		vus: Array) -> void:
	var poses := 0
	for j in v.taille.y:
		for i in v.taille.x:
			var l := Vector2i(i, j)
			if not _case_de_mobilier(v, l): continue
			var c := f.position + l
			var k := PLAN.quartier_en(plan, ctx, c)
			var usine := k >= 0 and _genre(plan, k) == "industrie"
			if usine:
				if not _cour_d_usine(v, l): continue
				var alea_u := RandomNumberGenerator.new()
				alea_u.seed = _graine(c.x, c.y, 4213)
				var x_u := (float(l.x) + 0.5) * CASE
				var z_u := (float(l.y) + 0.5) * CASE
				var t_u := alea_u.randf()
				if t_u < INDUSTRIE_CAMIONS:
					var cap := PI * 0.5 * float(alea_u.randi() % 2)
					for n in 2:
						var m := String(CAMIONS[alea_u.randi() % CAMIONS.size()])
						var dx := -4.5 + float(n) * 9.0
						v.ajouter_objet(m, x_u + (dx if cap == 0.0 else 0.0), z_u + (0.0 if cap == 0.0 else dx), cap, 0.0, "")
				elif t_u < INDUSTRIE_CAMIONS + INDUSTRIE_CONTENEURS:
					var cap2 := PI * 0.5 * float(alea_u.randi() % 2)
					v.ajouter_objet("conteneur", x_u, z_u, cap2, 0.0, "")
					if alea_u.randf() < 0.5:
						v.ajouter_objet("conteneur", x_u, z_u, cap2, 0.0, "")
				elif t_u < INDUSTRIE_CAMIONS + INDUSTRIE_CONTENEURS + INDUSTRIE_BENNE:
					v.ajouter_objet(BENNE, x_u, z_u, PI * 0.5, 0.0, "")
				else:
					continue
				poses += 1
				continue
			# ⚠ UNE COUR N'EST PAS SEULEMENT UNE CASE ENCLAVÉE. Photographié sur
			# la Gare Centrale (19/09) : les cœurs d'îlot du centre étaient des
			# dalles blanches de plusieurs cases, parce que seule une case aux
			# QUATRE voisines prises comptait comme cour. Une case libre qui ne
			# touche aucune rue est une arrière-cour aussi — elle se meuble, mais
			# une fois sur deux, pour que le cœur respire encore.
			var enclavee := _enclavee(v, l)
			if not enclavee and not _cour_d_usine(v, l): continue
			# ⚠ LE CŒUR D'UN ÎLOT DE CENTRE-VILLE N'EST PAS UNE DALLE. Vu d'en
			# haut, le centre était blanc d'un bord à l'autre : la charte y met de
			# la dalle (le trottoir, la place), et l'arrière des immeubles la
			# recevait aussi. Une arrière-cour, c'est de la terre et un peu
			# d'herbe ; on la repeint, et les voitures et les arbres qui suivent
			# se posent dessus.
			if k >= 0 and int(REGLES.charte(_genre(plan, k))["sol"]) == Ville2.M_DALLE \
					and v.matiere_de(l) == Ville2.M_DALLE:
				v.poser_matiere(l, Ville2.M_HERBE)
			var alea := RandomNumberGenerator.new()
			alea.seed = _graine(c.x, c.y, 4211)
			if not enclavee and alea.randf() < COUR_OUVERTE_VIDE: continue
			var essence: Array = REGLES.charte(_genre(plan, k))["essence"] if k >= 0 \
				else ["nature/tree_default"]
			var x := (float(l.x) + 0.5) * CASE
			var z := (float(l.y) + 0.5) * CASE
			var t := alea.randf()
			if t < COUR_VOITURES:
				# Deux voitures rangées côte à côte, comme sur un parking d'arrière-cour.
				for n in 2:
					var m := String(KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()])
					v.ajouter_objet(m, x - 4.0 + float(n) * 8.0, z, PI * 0.5, 0.0, "")
			elif t < COUR_VOITURES + COUR_ARBRES:
				for n2 in (1 + alea.randi() % 2):
					v.ajouter_objet(String(essence[alea.randi() % essence.size()]),
						x - 3.0 + float(n2) * 6.0, z + 2.0, 0.0, 0.0, "")
			elif t < COUR_VOITURES + COUR_ARBRES + COUR_BENNE:
				v.ajouter_objet(BENNE, x, z, PI * 0.5, 0.0, "")
			else:
				continue
			poses += 1
	if poses > 0: print("[cœurs] %d cases de cour meublées" % poses)

## Les quatre voisines sont-elles prises ? Le bord de la fenêtre compte comme
## pris : ce qui continue dehors n'est pas une cour qu'on peut juger d'ici.
static func _enclavee(v: Ville2, l: Vector2i) -> bool:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var n: Vector2i = l + d
		if not v.dedans(n): continue
		if _case_de_mobilier(v, n): return false
	return true

## De quel côté est la rue ? Les quatre côtés d'abord — c'est là qu'un arrêt
## se colle — puis les diagonales, qui donnent au moins un cap plausible quand
## la station tombe au coin d'un pâté. `ZERO` si la rue est trop loin.
static func _vers_la_rue(v: Ville2, l: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var n: Vector2i = l + d
		if v.dedans(n) and v.carte.route(n): return d
	for d in [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n2: Vector2i = l + d
		if v.dedans(n2) and v.carte.route(n2): return Vector2i(d.x, 0)
	return Vector2i.ZERO

static func _les_stations(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i) -> void:
	for e in plan.get("stations", []):
		var st: Dictionary = e
		var c := PLAN.case_de(st["c"])
		if not f.has_point(c): continue
		var reseau := String(st.get("reseau", "bus"))
		var alea := RandomNumberGenerator.new()
		alea.seed = _graine(c.x, c.y, 917)
		if (reseau == "train" or reseau == "train2") and bool(st.get("principale", false)):
			continue
		var l := c - f.position
		if not v.dedans(l): continue
		# ⭐ « IL FAUT UNE GARE DEVANT CHAQUE QUAI » (client, 21/09). Un arrêt de
		# train n'est pas un arrêt de bus : à la place de l'abribus contre la
		# rue, la petite gare du client (`pxl/quai-gare`, un quai couvert de
		# deux cases) se pose LE LONG DE LA VOIE, du côté libre. Le jeu arrête
		# ses rames pile là (`VilleVivante.gares`).
		if reseau in PLAN.RESEAUX_DE_SURFACE:
			if _la_petite_gare(v, l): continue
		# ⭐⭐ « LES ARRÊTS DE BUS DOIVENT ÊTRE COLLÉS À LA ROUTE » (client, 16/09).
		#
		# L'abribus se posait à un coin FIXE de sa case — toujours le même, en
		# haut à gauche — quel que soit le côté où passait la chaussée. Une fois
		# sur quatre il touchait la rue ; les trois autres fois il attendait le
		# bus au fond d'une pelouse, dos à la route.
		#
		# On cherche donc la RUE, et tout le mobilier se range par rapport à
		# elle : l'abri contre le bord, tourné vers la chaussée, le banc à côté
		# de lui LE LONG du trottoir, le rack à vélos un peu plus loin sur la
		# même ligne. Sans rue voisine (une station posée en pleine campagne),
		# on garde l'ancien coin plutôt que de ne rien poser.
		# ⚠ LA CASE DE LA STATION PEUT AVOIR ÉTÉ BÂTIE ENTRE-TEMPS. Les stations
		# se posent en dernier, après les lots : dix-neuf abribus, bancs et
		# racks se retrouvaient dans un mur. On glisse alors d'une case le long
		# de la rue, et on renonce plutôt que de meubler un salon.
		if not _case_de_mobilier(v, l):
			var repli := Vector2i(-999, -999)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n2: Vector2i = l + d
				if _case_de_mobilier(v, n2) and _vers_la_rue(v, n2) != Vector2i.ZERO:
					repli = n2
					break
			if repli.x == -999: continue
			l = repli
		var vers := _vers_la_rue(v, l)
		var bord := Vector2(float(l.x) + 0.5, float(l.y) + 0.5) * CASE
		var cap := 0.0
		var long := Vector2(1.0, 0.0)
		if vers != Vector2i.ZERO:
			var u := Vector2(float(vers.x), float(vers.y))
			bord += u * (CASE * 0.5 - MARGE_TROTTOIR)
			cap = atan2(-u.x, -u.y)
			long = u.orthogonal()
		else:
			bord = Vector2((float(l.x) + 0.18) * CASE, (float(l.y) + 0.82) * CASE)
		var x := bord.x
		var z := bord.y
		v.ajouter_objet(ABRIBUS, x, z, cap, 0.0, "")
		var banc := bord + long * 9.0
		v.ajouter_objet("banc", banc.x, banc.y, cap, 0.0, "")
		if alea.randf() < 0.55:
			var r := bord - long * 9.0
			v.ajouter_objet(RACK, r.x, r.y, cap, 0.0, "")
			for t in (1 + alea.randi() % 3):
				var vv := r + long * (float(t) * 3.0 - 3.0)
				v.ajouter_objet(VELO, vv.x, vv.y, cap + PI * 0.5, 0.0, "")
		if alea.randf() < 0.30:
			var pb := bord + long * 14.0
			if _case_de_mobilier(v, Vector2i(floori(pb.x / CASE), floori(pb.y / CASE))):
				v.ajouter_objet("poubelle", pb.x, pb.y, cap, 0.0, "")

const PETITE_GARE := "pxl/quai-gare"     ## le quai couvert du client : 0,4 × 0,26 × 1,78 cases, long en Z

## La petite gare d'un arrêt : on lit l'axe de la voie sous la station (la
## polyligne du rail qui passe par sa case), on la pose parallèle, décalée
## d'une case du côté où les deux cases qu'elle couvre sont libres. Rend
## `false` si aucun côté n'est libre — l'appelant garde alors l'abribus.
static func _la_petite_gare(v: Ville2, l0: Vector2i) -> bool:
	var axe := _axe_du_rail_en(v, l0)
	if axe == Vector2i.ZERO: return false
	var perp := Vector2i(-axe.y, axe.x)
	# La station est souvent posée sur un carrefour (une rue coupe la voie
	# juste là) : on glisse le long de la voie, d'une case puis deux, jusqu'à
	# trouver un bord libre — le train s'arrête à la station, le quai fait
	# deux cases, ça se touche encore.
	for decal in [0, 1, -1, 2, -2, 3, -3]:
		var l: Vector2i = l0 + axe * decal
		if not v.dedans(l) or _axe_du_rail_en(v, l) != axe: continue
		if _le_quai_ici(v, l, axe, perp): return true
	return false

static func _le_quai_ici(v: Ville2, l: Vector2i, axe: Vector2i, perp: Vector2i) -> bool:
	for cote in [1, -1]:
		var d: Vector2i = perp * int(cote)
		var a: Vector2i = l + d
		var b: Vector2i = l + d + axe
		var b2: Vector2i = l + d - axe
		# ⚠ Pas `_case_de_mobilier` : le couloir du rail est RÉSERVÉ (rien ne
		# s'y bâtit), et c'est précisément là qu'un quai se pose. On regarde
		# la terre, la chaussée, les lots et les pièces — pas la réserve.
		if not (_case_de_quai(v, a) and (_case_de_quai(v, b) or _case_de_quai(v, b2))):
			continue
		# Collée à la voie : son bord à un quart de case de l'axe du rail (le
		# quai fait 0,4 case de large), allongée vers la case libre voisine.
		# Centrée sur la case d'à côté, elle laissait un pré entre elle et le
		# train.
		var vers: Vector2i = axe if _case_de_quai(v, b) else -axe
		var centre := (Vector2(l) + Vector2(0.5, 0.5) + Vector2(d) * 0.45 + Vector2(vers) * 0.4) * CASE
		# Le modèle est long en Z : sur une voie est-ouest, un quart de tour.
		var cap := PI * 0.5 if axe.x != 0 else 0.0
		v.ajouter_objet(PETITE_GARE, centre.x, centre.y, cap, 0.0, "")
		return true
	return false

static func _case_de_quai(v: Ville2, c: Vector2i) -> bool:
	if not v.dedans(c) or not v.terre(c): return false
	if v.carte.route(c) or v.carte.case_prise(c): return false
	return v.lot_sur(c) < 0

## L'axe de la voie ferrée sous une case de la fenêtre, ou zéro si aucune
## polyligne du rail n'y passe.
static func _axe_du_rail_en(v: Ville2, l: Vector2i) -> Vector2i:
	for r in v.rail:
		var pts: Array = (r as Dictionary)["points"]
		for k in range(1, pts.size()):
			var a: Vector2i = pts[k - 1]
			var b: Vector2i = pts[k]
			if a.x == b.x and l.x == a.x and l.y >= mini(a.y, b.y) and l.y <= maxi(a.y, b.y):
				return Vector2i(0, 1)
			if a.y == b.y and l.y == a.y and l.x >= mini(a.x, b.x) and l.x <= maxi(a.x, b.x):
				return Vector2i(1, 0)
	return Vector2i.ZERO

## LA GARE, POSÉE À CÔTÉ DE SA STATION ET PAS DESSUS. Huit cases de long : posée
## sur le point de la station, elle enjamberait la voie qu'elle est censée
## desservir. On la décale d'une demi-longueur, du côté où il y a de la terre.
## ⭐⭐ « LES GARES DOIVENT ÊTRE COLLÉES AUX RAILS » (client, 16/09).
##
## Elle cherchait sa place « du côté où il y a de la terre », dans un ordre fixe
## de quatre décalages de trois cases, sans jamais regarder OU PASSE LA VOIE.
## Une gare finissait donc à soixante mètres du rail, de travers, séparée de son
## quai par un pré — un bâtiment de gare qui ne dessert rien.
##
## Maintenant on lit d'abord l'AXE DE LA VOIE sous le point de station, puis :
##
## 1. le bâtiment se tourne pour présenter son LONG CÔTÉ à la voie — c'est ce
##    côté-là qui porte le quai ;
## 2. on l'approche PERPENDICULAIREMENT à la voie, du plus près au plus loin, et
##    des deux côtés : la première position libre gagne, donc la plus collée ;
## 3. on garde un jeu d'une case, parce que le couloir du rail est réservé
##    (`_reserver`) et qu'une gare POSÉE SUR la voie est le défaut d'à côté.
##
## Sans voie repérée (une station de bus principale, un bord de fenêtre), on
## retombe sur l'ancienne recherche en croix plutôt que de ne rien poser.
static func _axe_du_rail(v: Ville2, lc: Vector2i) -> Vector2i:
	for r in v.rail:
		var cases := Ville2.cases_de_route(r)
		for k in cases.size():
			var a: Vector2i = cases[k]
			if absi(a.x - lc.x) + absi(a.y - lc.y) > 3: continue
			var b: Vector2i = cases[k + 1] if k + 1 < cases.size() else cases[maxi(0, k - 1)]
			if b == a: continue
			return Vector2i(1, 0) if b.y == a.y else Vector2i(0, 1)
	return Vector2i.ZERO

static func _la_gare(v: Ville2, f: Rect2i, c: Vector2i, nom: String) -> void:
	var modele := String(KitVille2.REPERES["gare"])
	var lc := c - f.position
	# ⭐ UNE HALTE EST UNE PETITE GARE (21/09). Le grand bâtiment du client fait
	# huit cases : sur l'Île de la Baie — le bourg où l'on commence — il ne
	# rentrait nulle part, et la halte n'avait RIEN, pas même un quai. Une
	# halte (le nom le dit) reçoit le quai couvert ; et une grande gare qui
	# ne trouve pas sa place le reçoit aussi, plutôt que rien.
	if not v.dedans(lc): return
	if nom.begins_with("Halte"):
		if _la_petite_gare(v, lc):
			v.ajouter_lieu("gare", (float(lc.x) + 0.5) * CASE, (float(lc.y) + 0.5) * CASE, {"nom": nom})
		return
	var axe := _axe_du_rail(v, lc)
	var essais: Array = []
	if axe != Vector2i.ZERO:
		# Le quart de tour qui met le long côté le long de la voie, puis son
		# opposé : si la première orientation ne rentre nulle part, mieux vaut
		# une gare tournée que pas de gare.
		var e0 := KitVille2.emprise_tournee(modele, 0)
		var long_selon_x := e0.x >= e0.y
		var veut_x := axe == Vector2i(1, 0)
		var q0 := 0 if long_selon_x == veut_x else 1
		var perp := Vector2i(axe.y, axe.x)
		for q in [q0, q0 + 2, q0 + 1, q0 + 3]:
			for t in [2, 3, 4, 5]:
				for sens in [1, -1]:
					essais.append([posmod(q, 4), perp * (t * sens)])
	else:
		for q in [0, 2, 1, 3]:
			for d0 in [Vector2i(0, 3), Vector2i(0, -3), Vector2i(3, 0), Vector2i(-3, 0)]:
				essais.append([q, d0])
	for paire in essais:
		var q: int = int(paire[0])
		var d: Vector2i = paire[1]
		var e := KitVille2.emprise_tournee(modele, q)
		var a := c + d
		var hx := (a.x - f.position.x) * 2 - e.x / 2
		var hy := (a.y - f.position.y) * 2 - e.y / 2
		if hx < 0 or hy < 0 or hx + e.x > v.taille.x * 2 or hy + e.y > v.taille.y * 2:
			continue
		if not Lotisseur.terrain_libre(v, hx, hy, e): continue
		v.ajouter_lot(modele, hx, hy, e.x, e.y, q, "gare")
		v.ajouter_lieu("gare", (float(a.x - f.position.x) + 0.5) * CASE,
			(float(a.y - f.position.y) + 0.5) * CASE, {"nom": nom})
		return
	# Pas de place pour la grande : la petite, plutôt que rien.
	if _la_petite_gare(v, lc):
		v.ajouter_lieu("gare", (float(lc.x) + 0.5) * CASE, (float(lc.y) + 0.5) * CASE, {"nom": nom})

# ─────────────────────────────────────────────── LES REPÈRES HABITABLES

## ⚠ LA FRÉQUENCE EST UN LOT SUR N, PAS UN COMPTE PAR FENÊTRE. « Deux planques
## par fenêtre » donnerait deux planques par kilomètre carré dans la capitale et
## deux aussi dans un bourg de trente maisons. Un lot sur soixante donne une
## densité, et elle suit la ville.
##
## ⚠⚠ ET LE TIRAGE SE FAIT SUR LA POSITION ABSOLUE DU LOT, pas sur son rang dans
## la liste : le rang dépend de l'ordre de parcours des rues, donc de la fenêtre.
## Deux fenêtres voisines n'auraient pas eu les mêmes planques, et une porte
## aurait disparu en marchant.
const HABITABLES := [
	## [genre, un lot sur N, ce qu'on écrit comme nom de lieu]
	["planque", 60, "Planque"],
	["garage", 130, "Garage"],
	["supermarche", 170, "Supérette"],
	["bar", 90, "Bar"],
	["atelier", 210, "Atelier"],
]

## ⭐⭐ CE QU'IL FAUT AU MOINS UNE FOIS PAR QUARTIER (21/09).
##
## « Un lot sur 130 » donne un garage tous les deux kilomètres et demi dans une
## capitale, et ZÉRO dans un bourg de soixante maisons : sur l'Île de la Baie —
## celle où l'on commence — le garage le plus proche était à 139 cases, à
## l'autre bout de l'île, alors que le premier contrat qu'un gang propose est
## « repeins cette voiture, et vite ». Le jeu demandait donc, dès la première
## minute, une chose qu'on ne pouvait pas faire.
##
## Un quartier BÂTI (au moins `LOTS_POUR_MINIMUM` lots ordinaires) reçoit donc
## d'office ce qui fait qu'on peut y jouer : un garage pour repeindre, une
## supérette pour manger. Les lots choisis sont ceux de plus petite graine —
## un choix qui ne dépend ni de l'ordre des lots ni du cadrage. Ce qui existe
## déjà dans le quartier compte : un supermarché posé en repère (`_les_reperes`)
## dispense d'en re-qualifier un.
const MINIMUM_PAR_QUARTIER := ["garage", "supermarche"]
const LOTS_POUR_MINIMUM := 10

## ⭐⭐ LE MINIMUM SE COMPTE PAR PAVÉ, PAS PAR QUARTIER (21/09).
##
## C'est la même mesure que pour les repères : « Les Faubourgs » fait 300 × 290
## cases et recevait UN garage, UNE supérette, UNE cabine. Le jeu, lui, cherche
## ce dont il a besoin dans un rayon d'un secteur et demi. Le banc des lieux le
## disait sans détour au point de départ : `cab=0` à vingt cases — donc aucun
## contrat possible, donc aucun premier billet, dans le village où l'on
## commence la partie.
##
## Le casier est donc `quartier / pavé de 40 cases`, calé sur l'origine du
## MONDE (jamais sur la fenêtre : deux tuiles voisines doivent ranger la même
## case dans le même casier, sinon la couture aurait deux garages côte à côte
## et le pavé suivant aucun).
static func _casier(q: int, c: Vector2i) -> String:
	return "%d/%d,%d" % [q, floori(float(c.x) / float(PAVE_REPERES)),
		floori(float(c.y) / float(PAVE_REPERES))]

static func _les_habitables(plan: Dictionary, v: Ville2, f: Rect2i) -> void:
	# Ce que le quartier a déjà : les repères posés avant nous en font partie.
	var deja: Dictionary = {}
	for li in v.lieux:
		var d0: Dictionary = li
		var cl := Vector2i(int(float(d0["x"]) / CASE), int(float(d0["z"]) / CASE))
		deja[_casier(v.quartier_en(cl), cl + f.position) + "/" + String(d0["genre"])] = true
	var libres: Dictionary = {}          # casier -> [[graine, lot], …]
	for l in v.lots:
		var lot: Dictionary = l
		var genre := String(lot.get("genre", ""))
		# On ne touche ni aux repères déjà posés ni aux pièces spéciales : une
		# planque dans l'hôpital n'a pas de sens, et la gare n'est pas un bar.
		if genre == "" or genre == "gare" or KitVille2.REPERES.has(genre): continue
		if genre == "commissariat": continue
		var hx := int(lot.get("x", 0)) + f.position.x * 2
		var hy := int(lot.get("y", 0)) + f.position.y * 2
		var h := _graine(hx, hy, 6607)
		var cl2 := Vector2i(int(lot["x"]) / 2, int(lot["y"]) / 2)
		var q := _casier(v.quartier_en(cl2), cl2 + f.position)
		var pose := ""
		for e in HABITABLES:
			var d: Array = e
			if h % int(d[1]) != 0: continue
			pose = String(d[0])
			lot["genre"] = pose
			_le_lieu_du_lot(v, lot, pose, String(d[2]))
			break
		if pose != "":
			deja[q + "/" + pose] = true
			continue
		if not libres.has(q): libres[q] = []
		(libres[q] as Array).append([h, lot])
	for q2 in libres:
		var candidats: Array = libres[q2]
		if candidats.size() < LOTS_POUR_MINIMUM: continue
		candidats.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		var i := 0
		for genre_min in MINIMUM_PAR_QUARTIER:
			if deja.has(String(q2) + "/" + String(genre_min)): continue
			if i >= candidats.size(): break
			var lot2: Dictionary = candidats[i][1]
			i += 1
			lot2["genre"] = String(genre_min)
			_le_lieu_du_lot(v, lot2, String(genre_min), _nom_habitable(String(genre_min)))
			deja[String(q2) + "/" + String(genre_min)] = true

static func _le_lieu_du_lot(v: Ville2, lot: Dictionary, genre: String, nom: String) -> void:
	v.ajouter_lieu(genre, (float(int(lot["x"])) * 0.5 + 0.5) * CASE,
		(float(int(lot["y"])) * 0.5 + 0.5) * CASE, {"nom": nom})

static func _nom_habitable(genre: String) -> String:
	for e in HABITABLES:
		if String((e as Array)[0]) == genre: return String((e as Array)[2])
	return genre

## ⚠ LA CABINE EST UN OBJET, PAS UN LOT. Elle se pose sur le trottoir, à
## l'écart de la chaussée pour ne pas être balayée par la passe de propreté.
const CABINE := "cabine"

## ⭐⭐⭐ LA CABINE EST LA PORTE D'ENTRÉE DU JEU, et il n'y en avait PAS.
##
## C'est à une cabine qu'un gang décroche et propose un contrat : sans elle, un
## joueur qui débarque à zéro dollar n'a rien à faire que voler une voiture.
## Elle se posait dans `_mobilier`, sur la case numéro 7 de chaque voie, une
## fois sur deux — or une « voie » est UNE RUE, et une rue de quartier fait
## trois à six cases : la condition n'était presque jamais atteinte. Mesuré sur
## les tuiles cuites : **quatre cabines pour 11 812 cases de rue** au centre du
## pays (une tous les six kilomètres), **zéro** sur l'Île de la Baie — celle où
## l'on commence — et zéro sur l'Île Nord.
##
## Maintenant la densité est celle d'un quartier, pas celle d'une rue : une
## cabine toutes les `CABINE_TOUS_LES` cases de rue environ, tirée sur la
## POSITION ABSOLUE de la case (deux fenêtres voisines posent la même cabine au
## même endroit), et **au moins une par quartier** — un bourg de cent cases de
## rue doit avoir son téléphone, c'est le seul moyen d'y gagner son premier
## billet.
const CABINE_TOUS_LES := 241         ## premier : `_graine` se répartit mal modulo une puissance de deux

static func _les_cabines(v: Ville2, f: Rect2i, voies: Array) -> void:
	var par_quartier: Dictionary = {}
	for e in voies:
		var d: Dictionary = e
		var k := int(d["k"])
		for c1 in (d["cases"] as Array):
			# Une garantie par PAVÉ de quarante cases, pas par quartier : voir
			# `_casier`. Un quartier du pays fait trois cents cases.
			var cle := _casier(k, c1)
			if not par_quartier.has(cle): par_quartier[cle] = []
			(par_quartier[cle] as Array).append(c1)
	var poses := 0
	var couverts: Dictionary = {}
	for k2 in par_quartier:
		var mises := 0
		var repli := Vector2i(-999, -999)
		var repli_g := 0
		for c0 in (par_quartier[k2] as Array):
			var c: Vector2i = c0
			var l: Vector2i = c - f.position
			# Le trottoir d'une case de rue : la case ne doit pas être bâtie.
			if not v.dedans(l) or not v.demi_libre(l.x * 2, l.y * 2, 2, 2): continue
			var g := _graine(c.x, c.y, 8831)
			# Le repli : la case de plus petite graine du quartier — un choix
			# qui ne dépend ni de l'ordre des rues ni du cadrage.
			if repli.x == -999 or g < repli_g:
				repli = l
				repli_g = g
			if g % CABINE_TOUS_LES != 0: continue
			_poser_la_cabine(v, l)
			mises += 1
		if mises == 0 and repli.x != -999:
			_poser_la_cabine(v, repli)
			mises += 1
		poses += mises
		if mises > 0: couverts[int(String(k2).split("/")[0])] = true
	# ⭐⭐ ET UN DERNIER FILET POUR LES BOURGS. Le casier ci-dessus part des
	# RUES TRACÉES (`voies`) : un village d'île dont les rues sont trop courtes
	# pour être retenues (`MIN_RUE`) n'a aucun casier, donc aucune cabine —
	# mesuré à l'Île de la Baie, là même où l'on commence la partie : zéro
	# téléphone à vingt cases, donc aucun contrat, donc aucun premier billet.
	# On balaie alors la fenêtre pour les quartiers restés sans rien, et on
	# prend leur case de chaussée de plus petite graine : un choix qui ne
	# dépend ni de l'ordre des rues ni du cadrage.
	var repechage: Dictionary = {}
	for j in v.taille.y:
		for i in v.taille.x:
			var l := Vector2i(i, j)
			var q := v.quartier_en(l)
			if q < 0 or couverts.has(q): continue
			if v.carte == null or not v.carte.route(l): continue
			if not v.demi_libre(l.x * 2, l.y * 2, 2, 2): continue
			var g2 := _graine(l.x + f.position.x, l.y + f.position.y, 8831)
			if not repechage.has(q) or g2 < int((repechage[q] as Array)[0]):
				repechage[q] = [g2, l]
	for q2 in repechage:
		_poser_la_cabine(v, (repechage[q2] as Array)[1])
		poses += 1
	if poses > 0: print("[cabines] %d posée(s)" % poses)

static func _poser_la_cabine(v: Ville2, l: Vector2i) -> void:
	v.ajouter_objet(CABINE, (float(l.x) + 0.86) * CASE, (float(l.y) + 0.14) * CASE,
		PI * 0.5)

# ──────────────────────────────────────────── CE QU'ON NE BÂTIT PAS DESSUS

## La demi-largeur réservée, en cases, de part et d'autre de l'axe.
## ⚠ Le viaduc est plus large que le rail : son tablier fait 22 unités, plus
## l'ombre des piles et le recul qu'on veut voir sous un ouvrage.
## ⚠ LE COULOIR DU RAIL EST PLUS LARGE QUE SON TRACÉ. Depuis que la voie est
## lissée (voir `RenduVille2._trace_arrondi`), elle COUPE ses virages : elle
## passe à une case et demie à l'intérieur de l'angle que décrit le tracé. Un
## couloir réservé à la largeur du tracé laissait donc bâtir pile où la courbe
## passe, et le train traversait une maison à chaque coude.
const LARGE_RESERVE_RAIL := 2
const LARGE_RESERVE_VIADUC := 1

static func _reserver(plan: Dictionary, v: Ville2, f: Rect2i) -> void:
	for r in v.rail:
		var fr: Dictionary = r
		var cases_r := _cases_de(fr["points"])
		_reserver_la_ligne(v, cases_r, LARGE_RESERVE_RAIL, Vector2i.ZERO)
		_l_emprise_du_rail(v, f, cases_r)
	for r2 in plan.get("routes", []):
		var f2: Dictionary = r2
		if String(f2.get("classe", "")) != "primaire": continue
		var cases_v := _cases_de(f2["points"])
		_reserver_la_ligne(v, cases_v, LARGE_RESERVE_VIADUC, f.position)
		_sous_le_viaduc(v, f, cases_v)

## Les cases d'une polyligne, qu'elle soit en `Vector2i` (une voie bâtie en
## mémoire) ou en `[x, y]` (une route relue du plan JSON).
static func _cases_de(points: Array) -> Array:
	var sortie: Array = []
	for k in range(1, points.size()):
		var a := _vers_case(points[k - 1])
		var b := _vers_case(points[k])
		var pas := (b - a).sign()
		if pas.x != 0 and pas.y != 0: continue
		var c := a
		if sortie.is_empty(): sortie.append(c)
		while c != b:
			c += pas
			sortie.append(c)
	return sortie

static func _vers_case(p) -> Vector2i:
	if typeof(p) == TYPE_VECTOR2I: return p
	var t: Array = p
	return Vector2i(int(t[0]), int(t[1]))

## ⭐ L'EMPRISE FERROVIAIRE SE VOIT. Le couloir réservé au rail fait cinq
## cases de large et rien ne s'y bâtit — c'était le but. Mais photographié
## sur la Gare Centrale (19/09), il restait de la couleur du quartier : au
## centre, une bande de DALLE BLANCHE de cent mètres de large qui traverse
## la ville, avec un fil de rail au milieu. Une vraie emprise, c'est du
## ballast et de la terre battue, et des broussailles au bord. On repeint le
## couloir en terre (hors chaussée : un passage à niveau reste du bitume) et
## on sème des buissons sur ses deux lisières, jamais sur la voie — qui,
## lissée, coupe ses virages à une case et demie du tracé.
const BUISSONS_DU_RAIL := ["nature/plant_bush", "nature/plant_bushDetailed",
	"nature/grass_large", "nature/plant_bushLarge"]
const RAIL_BUISSONS := 0.28

static func _l_emprise_du_rail(v: Ville2, f: Rect2i, cases: Array) -> void:
	var vues: Dictionary = {}
	for e in cases:
		var c: Vector2i = e
		for dj in range(-LARGE_RESERVE_RAIL, LARGE_RESERVE_RAIL + 1):
			for di in range(-LARGE_RESERVE_RAIL, LARGE_RESERVE_RAIL + 1):
				var d := c + Vector2i(di, dj)
				if vues.has(d) or not v.dedans(d) or not v.terre(d): continue
				vues[d] = true
				if v.carte.route(d): continue
				# La terre sur trois cases (la voie et ses deux bords) : sur les
				# cinq du couloir, une gare de bout de ligne devenait un aplat
				# brun aussi large que son bourg.
				var anneau := maxi(absi(di), absi(dj))
				if anneau <= 1: v.poser_matiere(d, Ville2.M_TERRE)
				# La lisière : l'anneau extérieur seulement.
				if anneau < LARGE_RESERVE_RAIL: continue
				var alea := RandomNumberGenerator.new()
				alea.seed = _graine(f.position.x + d.x, f.position.y + d.y, 4217)
				if alea.randf() >= RAIL_BUISSONS: continue
				var m := String(BUISSONS_DU_RAIL[alea.randi() % BUISSONS_DU_RAIL.size()])
				v.ajouter_objet(m, (float(d.x) + 0.2 + alea.randf() * 0.6) * CASE,
					(float(d.y) + 0.2 + alea.randf() * 0.6) * CASE, alea.randf() * TAU, 0.0, "")

## ⭐ SOUS LE VIADUC, UN PARKING. Le couloir de l'autoroute (l'axe et une case
## de chaque côté) est réservé, donc nu : au centre, une bande de dalle de
## soixante mètres le long du viaduc. Ce qu'on trouve sous un vrai viaduc
## urbain, c'est des voitures garées en épi. On en pose sur les deux cases
## de bord (jamais sur l'axe : c'est là que tombent les poteaux et les pieds
## de rampe), par paires, perpendiculaires au tablier.
const VIADUC_VOITURES := 0.30

static func _sous_le_viaduc(v: Ville2, f: Rect2i, cases: Array) -> void:
	var axe: Dictionary = {}
	for e in cases:
		axe[(e as Vector2i) - f.position] = true
	var vues: Dictionary = {}
	for e2 in cases:
		var c: Vector2i = (e2 as Vector2i) - f.position
		# Le sens du tablier ici : une voisine d'axe à gauche ou à droite.
		var horizontal := axe.has(c + Vector2i(1, 0)) or axe.has(c + Vector2i(-1, 0))
		var cotes: Array = [Vector2i(0, 1), Vector2i(0, -1)] if horizontal else [Vector2i(1, 0), Vector2i(-1, 0)]
		for dc in cotes:
			var d: Vector2i = c + dc
			if vues.has(d) or axe.has(d): continue
			vues[d] = true
			if not v.dedans(d) or not v.terre(d) or v.carte.route(d): continue
			var alea := RandomNumberGenerator.new()
			alea.seed = _graine(f.position.x + d.x, f.position.y + d.y, 4219)
			if alea.randf() >= VIADUC_VOITURES: continue
			var x := (float(d.x) + 0.5) * CASE
			var z := (float(d.y) + 0.5) * CASE
			for n in 2:
				var m := String(KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()])
				var dx := -4.0 + float(n) * 8.0
				if horizontal:
					v.ajouter_objet(m, x + dx, z, PI * 0.5, 0.0, "")
				else:
					v.ajouter_objet(m, x, z + dx, 0.0, 0.0, "")

static func _reserver_la_ligne(v: Ville2, cases: Array, large: int, origine: Vector2i) -> void:
	for e in cases:
		var c: Vector2i = (e as Vector2i) - origine
		for dj in range(-large, large + 1):
			for di in range(-large, large + 1):
				var d := c + Vector2i(di, dj)
				if not v.dedans(d): continue
				for b in 2:
					for a in 2:
						v.demi_prises[Vector2i(d.x * 2 + a, d.y * 2 + b)] = true
