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
	var prises := _les_chaussees(v, f)
	var voies: Array = []
	for k in vus:
		for pts in _les_voies(plan, ctx, k):
			for bout in _ecarter(pts, prises):
				voies.append({"k": k, "cases": bout})
				for c in bout: prises[c] = true
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
	# 8. LE MOBILIER DES STATIONS — la gare des lignes de train, l'abribus et le rack à vélos
	#    de tout le reste. Trois cent quarante-deux stations sur le pays : c'est
	#    le mobilier le plus RÉPANDU de la carte, et jusqu'ici aucune n'avait
	#    autre chose qu'un point dans un fichier.
	_les_stations(plan, ctx, v, f)

static func _genre(plan: Dictionary, k: int) -> String:
	return String((plan["quartiers"][k] as Dictionary)["g"])

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
			var m := _tirer(charte, alea)
			if m == "":
				i += 1
				continue
			var e := KitVille2.emprise_tournee(m, q)
			# Le coin du lot, en demi-cases ABSOLUES, collé au bord de la case de
			# rue puis reculé de `recul`.
			var hx := 0
			var hy := 0
			if n.x > 0: hx = (b.x + 1) * 2 + recul
			elif n.x < 0: hx = b.x * 2 - e.x - recul
			else: hx = b.x * 2
			if n.y > 0: hy = (b.y + 1) * 2 + recul
			elif n.y < 0: hy = b.y * 2 - e.y - recul
			else: hy = b.y * 2
			if alea.randf() < densite:
				if _poser(v, f, m, hx, hy, e, q, genre):
					_devant_la_maison(v, f, charte, alea, b, n, genre)
			i += maxi(1, (e.x if absi(d.x) > 0 else e.y) / 2)
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
		if i % 34 == 7 and alea.randf() < 0.5:
			v.ajouter_objet(CABINE, (float(l.x) + 0.86) * CASE,
				(float(l.y) + 0.14) * CASE, PI * 0.5)
		if arbres > 0.0 and alea.randf() < arbres:
			v.ajouter_objet(String(essence[alea.randi() % essence.size()]),
				(float(l.x) + 0.5) * CASE, (float(l.y) + 0.86) * CASE, 0.0)

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
	"vieille_ville": [["eglise", 2, -3], ["commissariat", -6, 6]],
	"pavillons": [["eglise", 6, -8], ["supermarche", -12, 9], ["caserne", 14, 11]],
	"chaud": [["caserne", 7, 7], ["commissariat", -7, -6]],
	"industrie": [["caserne", -8, 5], ["garage", 9, -6], ["compacteur", 12, 8]],
	"port": [["caserne", -8, 5], ["garage", 9, -6]],
	"plage": [["supermarche", 5, -7], ["caserne", -9, 6]],
	"campus": [["supermarche", 8, 9], ["hopital", -9, -7]],
	"bidonville": [["supermarche", 6, 5]],
}

static func _les_reperes(plan: Dictionary, ctx: Dictionary, v: Ville2, f: Rect2i,
		k: int, prises: Dictionary) -> void:
	var z: Dictionary = plan["quartiers"][k]
	var liste: Array = REPERES_PAR_GENRE.get(String(z["g"]), [])
	if liste.is_empty(): return
	var c := PLAN.case_de(z["c"])
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
		v.ajouter_lieu(genre, (float(ou.x) + 0.5) * CASE, (float(ou.y) + 0.5) * CASE,
			{"nom": String(z["nom"])})

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
static func _les_chaussees(v: Ville2, f: Rect2i) -> Dictionary:
	var prises := {}
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			var g := v.genre_de_route(c)
			if g == "" or g == Ville2.R_VOIE_RAPIDE: continue
			prises[f.position + c] = true
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
const LONGE := 3

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
		if reseau != "train" and reseau != "train2": continue
		if not bool(st.get("principale", false)): continue
		var c := PLAN.case_de(st["c"])
		if not f.grow(12).has_point(c): continue
		_la_gare(v, f, c, String(st.get("nom", "")))

## De combien on rentre le mobilier depuis le bord de la case : assez pour ne
## pas mordre sur la chaussée, assez peu pour la toucher.
const MARGE_TROTTOIR := 2.2

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
			v.ajouter_objet("poubelle", pb.x, pb.y, cap, 0.0, "")

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

static func _les_habitables(plan: Dictionary, v: Ville2, f: Rect2i) -> void:
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
		for e in HABITABLES:
			var d: Array = e
			if h % int(d[1]) != 0: continue
			lot["genre"] = String(d[0])
			v.ajouter_lieu(String(d[0]),
				(float(int(lot["x"])) * 0.5 + 0.5) * CASE,
				(float(int(lot["y"])) * 0.5 + 0.5) * CASE,
				{"nom": String(d[2])})
			break

## ⚠ LA CABINE EST UN OBJET, PAS UN LOT. Elle se pose sur le trottoir, à
## l'écart de la chaussée pour ne pas être balayée par la passe de propreté.
const CABINE := "cabine"

static func _les_cabines(v: Ville2, f: Rect2i, cases: Array, tous_les: int,
		alea: RandomNumberGenerator) -> void:
	if tous_les <= 0: return
	for i in cases.size():
		if i % tous_les != 0: continue
		var c: Vector2i = cases[i]
		var l := c - f.position
		if not v.dedans(l): continue
		if alea.randf() > 0.5: continue
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
		_reserver_la_ligne(v, _cases_de(fr["points"]), LARGE_RESERVE_RAIL, Vector2i.ZERO)
	for r2 in plan.get("routes", []):
		var f2: Dictionary = r2
		if String(f2.get("classe", "")) != "primaire": continue
		_reserver_la_ligne(v, _cases_de(f2["points"]), LARGE_RESERVE_VIADUC, f.position)

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
