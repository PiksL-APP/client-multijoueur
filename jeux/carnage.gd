extends Partie
## CARNAGE — une ville, des monstres, et de quoi les traiter.
##
## Répartition du travail : chaque client conduit SA voiture, tire ses propres
## projectiles et annonce le tout ; l'hôte fait vivre les monstres, distribue
## les armes, tranche les impacts et tient le score. Laisser le tireur déclarer
## ses victimes serait plus nerveux, mais deux joueurs revendiqueraient le même
## monstre à cent millisecondes près — et rien n'empêcherait un client modifié
## d'annoncer trente victimes par seconde.
##
## La ville est engendrée à partir du CODE de la manche, identique chez tout le
## monde : aucun plan n'a besoin de circuler sur le réseau, et un joueur qui
## rejoint en retard reconstruit exactement la même ville.

const DUREE := 150.0

# Une ville, pas une arène : pas de mur, pas de cage. Les bords se perdent
# dans la verdure, et on est simplement ramené vers le centre si on s'éloigne
# trop loin.
#
# Elle est pavée avec le kit de ville de Kenney (CC0) : des tuiles d'une unité
# de côté, posées sur une grille. Une rue tous les quatre pas, des pâtés de
# trois sur trois entre les rues.
const TUILE := 14.0                          ## côté d'une tuile, en unités 3D
const PAS := TUILE / Decor.ECHELLE           ## le même, en pixels de jeu
const COLONNES := 22
const LIGNES := 16
const CEINTURE := 3                          ## anneau de verdure autour de la ville
const RETOUR := 260.0                        ## au-delà, la voiture est ramenée

const VILLE := "res://modeles/ville/"
## Le kit de Kenney est clair : cette teinte le refroidit à peine, juste assez
## pour qu'il tienne dans la palette sombre de la maison. Elle MULTIPLIE
## l'atlas de couleurs plutôt que de le remplacer — trop appuyée, elle
## éteindrait les pelouses, les fontaines et le marquage au sol.
const TEINTE_VILLE := Color(0.82, 0.85, 0.92)
const IMMEUBLES := ["building-small-a", "building-small-b", "building-small-c",
	"building-small-d", "building-garage"]

# Conduite : des valeurs d'arcade, pas de simulation. On veut qu'une voiture
# reparte vite après un choc, sinon le jeu punit la maladresse trop longtemps.
const ACCELERATION := 940.0
const FREIN := 1550.0
const VITESSE_MAX := 760.0
const VITESSE_ARRIERE := -270.0
const FROTTEMENT := 1.6
const BRAQUAGE := 3.6
const PRISE_PLEINE := 165.0        ## vitesse à partir de laquelle on braque à fond
const RAYON_VOITURE := 26.0

const VIE_MAX := 100.0
const DEGAT_MONSTRE := 22.0
const REGEN := 7.0                 ## points de vie par seconde, après une accalmie
const ACCALMIE := 5.0              ## secondes sans coup avant que ça reparte
const HORS_SERVICE := 3.5

const SEUIL_ECRASEMENT := 210.0    ## en dessous, on pousse le monstre sans l'écraser
const SEUIL_EPERON := 90.0         ## l'éperon écrase presque à l'arrêt
const CADENCE_VOITURE := 1.0 / 12.0
const CADENCE_MONSTRES := 1.0 / 9.0
const MONSTRES_MAX := 70
const COMBO_FENETRE := 2.5

# Caméra presque à la verticale : en ville, une inclinaison basse met un
# immeuble entre l'œil et la voiture toutes les trois secondes.
const INCLINAISON := 70.0
const DISTANCE := 52.0

## Les armes. `points` est volontairement plus bas que l'écrasement : l'arme
## sert à se sortir d'une mêlée, pas à remplacer la conduite — sinon plus
## personne ne roule.
const ARMES := {
	"mitraillette": {
		"nom": "Mitraillette", "munitions": 45, "cadence": 0.11, "portee": 950.0,
		"vitesse": 1500.0, "souffle": 0.0, "points": 6, "couleur": Palette.AVERTISSEMENT,
	},
	"roquette": {
		"nom": "Roquettes", "munitions": 5, "cadence": 0.9, "portee": 1200.0,
		"vitesse": 900.0, "souffle": 150.0, "points": 12, "couleur": Palette.SERIEUX,
	},
	"eperon": {
		"nom": "Éperon", "munitions": 0, "cadence": 0.0, "portee": 0.0,
		"vitesse": 0.0, "souffle": 0.0, "points": 0, "couleur": Palette.SERIE,
	},
}
const DUREE_EPERON := 14.0
const CAISSES_MAX := 7

var _position := Vector2.ZERO
var _angle := 0.0
var _vitesse := 0.0
var _sonne := 0.0                  ## secondes de perte de contrôle après un choc
var _vie := VIE_MAX
var _hors_service := 0.0
var _depuis_coup := 99.0
var _barre: Node3D

var _autres: Dictionary = {}       # cle -> {p, a, v, cible, angle_cible, noeud}
var _monstres: Array = []
var _batiments: Array[Rect2] = []  # emprise au sol des immeubles
var _caisses: Array = []           # {id, p, arme, noeud}
var _projectiles: Array = []       # {p, v, restant, par, arme, noeud}
var _arme := ""
var _munitions := 0
var _eperon := 0.0
var _recharge := 0.0
var _prochain_id := 1
var _prochaine_caisse := 1
var _depuis_envoi := 0.0
var _depuis_snapshot := 0.0
var _depuis_apparition := 0.0
var _depuis_caisse := 0.0
var _amorce := false
var _combos: Dictionary = {}       # cle -> {dernier, facteur}
var _eclats: Array = []
var _taches: Array = []
var _camera: Camera3D
var _corps: Node3D
var _secousse := 0.0
var _rng := RandomNumberGenerator.new()
var _hors_ville := 0.0

func duree_manche() -> float:
	return DUREE

func aide() -> String:
	return "Z/S : accélérer et freiner · Q/D : tourner · ESPACE : tirer · ramassez les caisses · écraser lancé rapporte le plus, les enchaînements multiplient."

# ------------------------------------------------------- la ville

func centre_ville() -> Vector2:
	return etendue() * 0.5

func etendue() -> Vector2:
	return Vector2(COLONNES, LIGNES) * PAS

func banlieue() -> float:
	return CEINTURE * PAS

## Le plan se déduit du code de la manche : même code, même ville, chez tout le
## monde et à tout moment. Diffuser le plan aurait coûté un message de plusieurs
## kilo-octets et un cas de plus pour qui rejoint en retard.
##
## Renvoie, par modèle de tuile, la liste des transformations à poser.
func _batir_ville() -> Dictionary:
	var graine := RandomNumberGenerator.new()
	graine.seed = hash(code)
	_batiments.clear()
	var nappes: Dictionary = {}

	for colonne in range(-CEINTURE, COLONNES + CEINTURE):
		for ligne in range(-CEINTURE, LIGNES + CEINTURE):
			var dedans := colonne >= 0 and colonne < COLONNES and ligne >= 0 and ligne < LIGNES
			var tuile := ""
			var rotation := 0.0
			var bloque := false

			if not dedans:
				# La ceinture : de l'herbe et des bosquets. Ils ferment
				# l'horizon sans qu'on ait à poser un mur.
				var t := graine.randf()
				tuile = "grass" if t < 0.62 else ("grass-trees" if t < 0.88 else "grass-trees-tall")
				bloque = t >= 0.62
			elif colonne % 4 == 0 and ligne % 4 == 0:
				tuile = "road-intersection"
			elif colonne % 4 == 0:
				# La tuile de route droite est orientée selon Z, donc selon
				# l'axe Y du jeu : une avenue verticale se pose sans rotation.
				tuile = "road-straight-lightposts" if ligne % 3 == 1 else "road-straight"
			elif ligne % 4 == 0:
				tuile = "road-straight-lightposts" if colonne % 3 == 1 else "road-straight"
				rotation = PI * 0.5
			else:
				var t2 := graine.randf()
				if t2 < 0.58:
					tuile = String(IMMEUBLES[graine.randi_range(0, IMMEUBLES.size() - 1)])
					rotation = PI * 0.5 * graine.randi_range(0, 3)
					bloque = true
				elif t2 < 0.88:
					tuile = "pavement-fountain" if graine.randf() < 0.08 else "pavement"
					bloque = tuile == "pavement-fountain"
				else:
					tuile = "grass-trees"
					bloque = true

			var centre := Vector2(colonne + 0.5, ligne + 0.5) * PAS
			if bloque:
				# Un peu plus petit que la tuile : on doit pouvoir raser un
				# immeuble sans rester collé au trottoir.
				var cote := PAS - 22.0
				_batiments.append(Rect2(centre - Vector2(cote, cote) * 0.5, Vector2(cote, cote)))

			if not nappes.has(tuile):
				nappes[tuile] = []
			# Les immeubles sont tassés en hauteur : à l'échelle du sol, le
			# kit monte à vingt-cinq unités et on ne voit plus que des toits.
			# Une ville écrasée se survole ; une ville haute se subit.
			var elevation: float = TUILE * (0.5 if bloque and tuile.begins_with("building") else 1.0)
			var base := Basis(Vector3.UP, rotation).scaled(Vector3(TUILE, elevation, TUILE))
			nappes[tuile].append(Transform3D(base, Decor.vers3d(centre)))
	return nappes

func _dans_un_batiment(point: Vector2, marge: float = 0.0) -> bool:
	for rect: Rect2 in _batiments:
		if rect.grow(marge).has_point(point):
			return true
	return false

## Repousse un point hors des immeubles par le plus petit chevauchement.
## Renvoie le point corrigé et si une correction a eu lieu.
func _degager(point: Vector2, rayon: float) -> Array:
	for rect: Rect2 in _batiments:
		var etendu := rect.grow(rayon)
		if not etendu.has_point(point):
			continue
		var gauche := point.x - etendu.position.x
		var droite := etendu.end.x - point.x
		var haut := point.y - etendu.position.y
		var bas := etendu.end.y - point.y
		var minimum: float = min(min(gauche, droite), min(haut, bas))
		var corrige := point
		if minimum == gauche: corrige.x = etendu.position.x
		elif minimum == droite: corrige.x = etendu.end.x
		elif minimum == haut: corrige.y = etendu.position.y
		else: corrige.y = etendu.end.y
		return [corrige, true]
	return [point, false]

func _point_de_rue(autour: Vector2, rayon_min: float, rayon_max: float) -> Vector2:
	for essai in 12:
		var p: Vector2 = autour + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(rayon_min, rayon_max)
		p.x = clamp(p.x, -banlieue() * 0.5, etendue().x + banlieue() * 0.5)
		p.y = clamp(p.y, -banlieue() * 0.5, etendue().y + banlieue() * 0.5)
		if not _dans_un_batiment(p, 40.0):
			return p
	return autour + Vector2.RIGHT.rotated(_rng.randf() * TAU) * rayon_min

# ------------------------------------------------------- mise en place

func preparer() -> void:
	Tactile.mode = Tactile.CONDUITE
	_rng.randomize()
	_planter_decor(_batir_ville())

	# Départ réparti sur un cercle, dans la rue : quatre voitures au même
	# endroit se poussent mutuellement dans un mur avant même le décompte.
	var place := 0
	for membre in donnees.get("equipe", []):
		if String(membre.get("cle", "")) == Session.cle:
			break
		place += 1
	var angle := TAU * float(place) / 4.0
	_position = _point_de_rue(centre_ville() + Vector2.RIGHT.rotated(angle) * 320.0, 0.0, 200.0)
	_angle = angle + PI

	_corps = _batir_voiture(Palette.couleur_joueur(place), Session.pseudo)
	monde().add_child(_corps)

	_camera = Decor.camera(INCLINAISON, DISTANCE, 54.0)
	monde().add_child(_camera)
	_camera.make_current()

func _planter_decor(nappes: Dictionary) -> void:
	poser_ambiance(true, 0.92)

	# Une nappe de fond, très sombre, sous la ville : elle rattrape ce que la
	# caméra voit au-delà de la ceinture, là où il n'y a plus de tuiles.
	var fond := Decor.sol(etendue() + Vector2(banlieue(), banlieue()) * 2.0, 140.0, Color("#101010"), 3000.0)
	fond.position = Decor.vers3d(centre_ville(), -0.15)
	monde().add_child(fond)

	for tuile in nappes:
		var sans_ombre := String(tuile) in ["road-straight", "road-intersection", "pavement", "grass"]
		monde().add_child(Decor.nappe(VILLE + String(tuile) + ".glb", nappes[tuile],
			not sans_ombre, TEINTE_VILLE))

func _batir_voiture(couleur: Color, pseudo: String) -> Node3D:
	var racine := Node3D.new()

	# Un halo au sol, à la couleur du joueur, insensible à l'éclairage : dans
	# l'ombre d'un immeuble la carrosserie devient noire et on ne se retrouve
	# plus. Il sert aussi à distinguer les quatre voitures d'un coup d'œil.
	var halo := Decor.anneau(2.7, 0.22, couleur, 0.95)
	halo.rotation_degrees = Vector3(90, 0, 0)
	halo.position = Vector3(0, 0.04, 0)
	racine.add_child(halo)

	var carrosserie := Decor.carrosserie(couleur)
	# La coque de modélisme n'a pas de garde au sol : on la soulève de la
	# hauteur des roues, sinon la voiture rase le bitume et les roues
	# dépassent par-dessus les ailes.
	carrosserie.position = Vector3(0, 0.42, 0)
	racine.add_child(carrosserie)

	# La coque de modélisme est creuse et ses vitres sont ouvertes : vu de
	# dessus, on voyait la route à travers l'habitacle. Un bloc sombre glissé
	# dedans referme la voiture sans coûter de géométrie.
	var habitacle := Decor.boite(Vector3(4.2, 0.55, 1.7), Palette.FOND.lightened(0.06))
	habitacle.position = Vector3(-0.15, 0.78, 0)
	habitacle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(habitacle)

	for cote in [-1.0, 1.0]:
		for avant in [-1.0, 1.0]:
			var roue := Decor.cylindre(0.62, 0.42, Color("#0b0b0b"))
			roue.rotation_degrees = Vector3(90, 0, 0)
			roue.position = Vector3(avant * 1.95, 0.62, cote * 1.02)
			racine.add_child(roue)
			var jante := Decor.cylindre(0.34, 0.46, Palette.ENCRE_FAIBLE)
			jante.rotation_degrees = Vector3(90, 0, 0)
			jante.position = Vector3(avant * 1.95, 0.62, cote * 1.02)
			racine.add_child(jante)

	# Deux phares : ils disent dans quel sens la voiture regarde, ce qu'une
	# silhouette vue de haut ne montre pas.
	for cote in [-1.0, 1.0]:
		var phare := Decor.sphere(0.22, Palette.AVERTISSEMENT)
		phare.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 1.2)
		phare.position = Vector3(2.85, 1.0, cote * 0.72)
		racine.add_child(phare)

	# Le pare-buffle n'apparaît qu'avec l'éperon : il devient ainsi le signe
	# visible du bonus, au lieu d'un accessoire permanent qui alourdit la
	# silhouette d'une berline.
	var pare_buffle := Decor.boite(Vector3(0.3, 0.85, 2.2), Palette.SERIE)
	pare_buffle.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.1)
	pare_buffle.position = Vector3(3.05, 0.75, 0)
	pare_buffle.name = "Buffle"
	pare_buffle.visible = false
	racine.add_child(pare_buffle)

	var jauge := Decor.barre(3.4)
	jauge.name = "Vie"
	jauge.position = Vector3(0, 2.9, 0)
	racine.add_child(jauge)

	if pseudo != "":
		var nom := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 32)
		nom.name = "Nom"
		nom.position = Vector3(0, 4.2, 0)
		racine.add_child(nom)
	return racine

func _batir_monstre(type: int) -> Node3D:
	var racine := Node3D.new()
	var rayon := _rayon_monstre(type) * Decor.ECHELLE
	var couleur := Palette.BON if type == 0 else (Palette.SERIEUX if type == 1 else Palette.AVERTISSEMENT)

	var corps := Decor.instance(Decor.CREATURE, couleur, 0.62)
	# Le modèle fait 1,2 de large : on l'échelonne sur le rayon de collision,
	# pour que ce qu'on voit soit exactement ce qui écrase.
	corps.scale = Vector3.ONE * (rayon * 2.0 / 1.2)
	corps.name = "Corps"
	racine.add_child(corps)

	# Une ombre portée simple sous la créature : elle vole, et sans marque au
	# sol on ne sait pas où elle est vraiment quand on fonce dessus.
	var marque := Decor.cylindre(rayon * 0.8, 0.05, Color(0, 0, 0, 0.5), false)
	marque.material_override = Decor.matiere_voile(Color.BLACK, 0.35)
	marque.position = Vector3(0, 0.04, 0)
	marque.name = "Ombre"
	racine.add_child(marque)

	if type == 1:
		var jauge := Decor.barre(rayon * 1.6)
		jauge.name = "Vie"
		jauge.position = Vector3(0, rayon * 2.6, 0)
		racine.add_child(jauge)
	return racine

const MODELES_ARMES := {
	"mitraillette": "res://modeles/creatures/blaster-repeater.glb",
	"roquette": "res://modeles/creatures/blaster.glb",
	"eperon": "res://modeles/personnages/coin.glb",
}

func _batir_caisse(arme: String) -> Node3D:
	var couleur: Color = ARMES[arme]["couleur"]
	var racine := Node3D.new()

	# Un socle lumineux au sol, l'objet qui flotte au-dessus : c'est la
	# grammaire habituelle du ramassage, et elle se repère de loin dans une
	# rue encombrée là où une caisse posée se confond avec le mobilier.
	var socle := Decor.cylindre(1.9, 0.12, couleur, false)
	socle.material_override = Decor.matiere_lumineuse(couleur, 0.75, 0.5)
	socle.position = Vector3(0, 0.08, 0)
	racine.add_child(socle)
	var couronne := Decor.anneau(2.1, 0.16, couleur, 1.15)
	couronne.rotation_degrees = Vector3(90, 0, 0)
	couronne.position = Vector3(0, 0.2, 0)
	racine.add_child(couronne)

	var objet := Decor.instance(String(MODELES_ARMES[arme]), couleur, 0.5)
	objet.scale = Vector3.ONE * (4.2 if arme == "eperon" else 2.0)
	objet.name = "Objet"
	objet.position = Vector3(0, 1.6, 0)
	racine.add_child(objet)
	return racine

# ------------------------------------------------------- simulation locale

func simuler_local(delta: float) -> void:
	if Commandes.pilote_automatique:
		Commandes.direction_simulee = _viser_le_plus_proche()
		Commandes.tir_simule = _arme != "" and _munitions > 0
	_conduire(delta)
	_tirer(delta)

	if _eperon > 0.0:
		_eperon -= delta

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["p"] = (a["p"] as Vector2).lerp(a["cible"], clamp(delta * 14.0, 0, 1))
		a["a"] = lerp_angle(a["a"], a["angle_cible"], clamp(delta * 14.0, 0, 1))

	_depuis_envoi += delta
	if _depuis_envoi >= CADENCE_VOITURE:
		_depuis_envoi = 0.0
		canal.envoyer("v", {
			"x": int(_position.x), "y": int(_position.y),
			"a": snapped(_angle, 0.01), "s": int(_vitesse), "h": int(_vie),
		})

	if not est_hote():
		for m in _monstres:
			m["p"] = (m["p"] as Vector2).lerp(m["cible"], clamp(delta * 10.0, 0, 1))

	_avancer_projectiles(delta)
	_ramasser_caisses()

## Pilote automatique du banc d'essai : viser le monstre le plus proche.
## Une manche d'essai qui tourne au hasard se termine à zéro — elle ne
## vérifierait alors ni la collision, ni le score, ni le dépôt en base.
func _viser_le_plus_proche() -> Vector2:
	var cible := Vector2.INF
	var distance := INF
	for m in _monstres:
		var d: float = _position.distance_squared_to(m["p"])
		if d < distance:
			distance = d
			cible = m["p"]
	if cible == Vector2.INF:
		cible = centre_ville()
	var ecart := wrapf((cible - _position).angle() - _angle, -PI, PI)
	return Vector2(clamp(ecart * 2.0, -1.0, 1.0), 1.0)

func _conduire(delta: float) -> void:
	if _hors_service > 0.0:
		_hors_service -= delta
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta)
		_position += Vector2.RIGHT.rotated(_angle) * _vitesse * delta
		if _hors_service <= 0.0:
			_reparer()
		return

	_depuis_coup += delta
	if _depuis_coup > ACCALMIE:
		_vie = min(VIE_MAX, _vie + REGEN * delta)

	if _sonne > 0.0:
		_sonne -= delta
		_angle += delta * 4.0
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta * 0.5)
	else:
		var commande := Commandes.conduite()
		if commande.y > 0.1:
			_vitesse = min(_vitesse + ACCELERATION * delta, VITESSE_MAX)
		elif commande.y < -0.1:
			_vitesse = max(_vitesse - FREIN * delta, VITESSE_ARRIERE)
		else:
			_vitesse = move_toward(_vitesse, 0.0, FROTTEMENT * abs(_vitesse) * delta + 40.0 * delta)

		# Le braquage atteint son plein dès 165 px/s — avant, la voiture ne
		# tournait qu'à pleine vitesse, ce qui la rendait inconduisible dans
		# des rues de cent quarante pixels. Il se resserre ensuite un peu à
		# haute vitesse, ce qui donne le poids sans enlever le contrôle.
		var prise: float = clamp(abs(_vitesse) / PRISE_PLEINE, 0.0, 1.0) * signf(_vitesse)
		var tenue: float = lerp(1.0, 0.74, clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))
		_angle += commande.x * BRAQUAGE * delta * prise * tenue

	_position += Vector2.RIGHT.rotated(_angle) * _vitesse * delta
	_heurter_les_murs()
	_surveiller_la_friche(delta)
	Sons.regime(clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))

## Un mur ne stoppe pas : il fait GLISSER. On ne perd que la part de vitesse
## qu'on a mise dedans, et la voiture se réaligne sur la façade quand on la
## frôle. Avant, le moindre angle de trottoir coupait les deux tiers de la
## vitesse et clouait la voiture — dans une ville, c'est toutes les trois
## secondes.
func _heurter_les_murs() -> void:
	var resultat := _degager(_position, RAYON_VOITURE)
	if not resultat[1]:
		return
	var correction: Vector2 = (resultat[0] as Vector2) - _position
	_position = resultat[0]
	var normale := correction.normalized()
	if normale == Vector2.ZERO:
		return
	var direction := Vector2.RIGHT.rotated(_angle)
	var frontal: float = abs(direction.dot(normale))

	if frontal > 0.62 and abs(_vitesse) > 330.0:
		Sons.jouer("choc", 0.8, -10.0)
		_secousse = max(_secousse, 0.28)
	_vitesse *= lerp(0.95, 0.28, frontal)

	var tangente := Vector2(-normale.y, normale.x)
	if tangente.dot(direction) < 0.0:
		tangente = -tangente
	_angle = lerp_angle(_angle, tangente.angle(), (1.0 - frontal) * 0.4)

func _reparer() -> void:
	_vie = VIE_MAX
	_hors_service = 0.0
	_sonne = 0.0
	_vitesse = 0.0
	_position = _point_de_rue(centre_ville(), 200.0, max(etendue().x, etendue().y) * 0.45)
	Sons.jouer("depart", 0.8, -8.0)

## Il n'y a pas de mur : au-delà de la friche on est ramené, doucement d'abord.
## Un mur invisible qui arrête net donne l'impression d'un défaut ; une
## inertie qui ramène se comprend sans explication.
func _surveiller_la_friche(delta: float) -> void:
	var limite := Rect2(-banlieue(), -banlieue(), etendue().x + banlieue() * 2.0, etendue().y + banlieue() * 2.0)
	if limite.has_point(_position):
		_hors_ville = max(0.0, _hors_ville - delta * 2.0)
		return
	_hors_ville += delta
	var vers_centre := (centre_ville() - _position).normalized()
	_position += vers_centre * RETOUR * delta * min(_hors_ville, 3.0)

# ------------------------------------------------------- armes

func _tirer(delta: float) -> void:
	_recharge = max(0.0, _recharge - delta)
	if _arme == "" or _arme == "eperon" or _munitions <= 0 or _recharge > 0.0:
		return
	if not Commandes.tir():
		return
	var fiche: Dictionary = ARMES[_arme]
	_recharge = float(fiche["cadence"])
	_munitions -= 1
	var depart := _position + Vector2.RIGHT.rotated(_angle) * 40.0
	canal.envoyer("tir", {"x": int(depart.x), "y": int(depart.y), "a": snapped(_angle, 0.01), "arme": _arme})
	_creer_projectile(depart, _angle, _arme, Session.cle)
	Sons.jouer("clic" if _arme == "mitraillette" else "choc", 1.6 if _arme == "mitraillette" else 0.7, -12.0)
	if _munitions == 0:
		_arme = ""

func _creer_projectile(depart: Vector2, angle: float, arme: String, par: String) -> void:
	var fiche: Dictionary = ARMES[arme]
	var couleur: Color = fiche["couleur"]
	var noeud := Decor.sphere(0.5 if arme == "mitraillette" else 0.9, couleur, false)
	noeud.material_override = Decor.matiere_lumineuse(couleur, 1.25)
	noeud.position = Decor.vers3d(depart, 1.6)
	monde().add_child(noeud)
	_projectiles.append({
		"p": depart,
		"v": Vector2.RIGHT.rotated(angle) * float(fiche["vitesse"]),
		"restant": float(fiche["portee"]),
		"par": par, "arme": arme, "noeud": noeud,
	})

func _avancer_projectiles(delta: float) -> void:
	var restants: Array = []
	for tir in _projectiles:
		var pas: Vector2 = (tir["v"] as Vector2) * delta
		tir["p"] = (tir["p"] as Vector2) + pas
		tir["restant"] = float(tir["restant"]) - pas.length()
		var mort: bool = float(tir["restant"]) <= 0.0 or _dans_un_batiment(tir["p"])
		if est_hote() and not mort:
			mort = _resoudre_impact(tir)
		if mort:
			if String(tir["arme"]) == "roquette":
				_effet_explosion(tir["p"])
			(tir["noeud"] as Node3D).queue_free()
			continue
		(tir["noeud"] as Node3D).position = Decor.vers3d(tir["p"], 1.6)
		restants.append(tir)
	_projectiles = restants

## Seul l'hôte tranche : il seul voit tous les monstres à la même date.
func _resoudre_impact(tir: Dictionary) -> bool:
	var souffle := float(ARMES[tir["arme"]]["souffle"])
	var touches: Array = []
	for m in _monstres:
		var rayon: float = _rayon_monstre(int(m["type"]))
		if (m["p"] as Vector2).distance_to(tir["p"]) <= rayon + 14.0:
			touches.append(m)
			break
	if touches.is_empty():
		return false
	if souffle > 0.0:
		var centre: Vector2 = touches[0]["p"]
		touches.clear()
		for m in _monstres:
			if (m["p"] as Vector2).distance_to(centre) <= souffle:
				touches.append(m)
	for m in touches:
		m["pv"] = int(m["pv"]) - (2 if souffle > 0.0 else 1)
		if int(m["pv"]) > 0:
			continue
		_compter_victime(String(tir["par"]), m, int(ARMES[tir["arme"]]["points"]), false)
		_liberer(m)
		_monstres.erase(m)
	return true

func _ramasser_caisses() -> void:
	for caisse in _caisses:
		if (caisse["p"] as Vector2).distance_to(_position) > 46.0:
			continue
		canal.envoyer("ramasse", {"id": int(caisse["id"])})
		if est_hote():
			_accorder(Session.cle, String(caisse["arme"]))
			_retirer_caisse(int(caisse["id"]))
		return

func _accorder(cle: String, arme: String) -> void:
	canal.envoyer("arme", {"j": cle, "arme": arme})
	if cle == Session.cle:
		_equiper(arme)

func _equiper(arme: String) -> void:
	if arme == "eperon":
		_eperon = DUREE_EPERON
	else:
		_arme = arme
		_munitions = int(ARMES[arme]["munitions"])
	Sons.jouer("depart", 1.0, -8.0)

func seuil_ecrasement() -> float:
	return SEUIL_EPERON if _eperon > 0.0 else SEUIL_ECRASEMENT

# ------------------------------------------------------- simulation hôte

func simuler_hote(delta: float) -> void:
	_reprendre_la_main()

	var vague := int(temps / 20.0) + 1
	# Une bouffée au coup d'envoi : sans elle, les vingt premières secondes se
	# passent à chercher un monstre à l'écran, et la manche commence mollement.
	if not _amorce:
		_amorce = true
		for i in 8:
			_faire_apparaitre(vague)
		for i in 4:
			_poser_caisse()

	_depuis_apparition += delta
	var intervalle: float = max(0.14, 0.62 - vague * 0.07)
	if _depuis_apparition >= intervalle and _monstres.size() < MONSTRES_MAX:
		_depuis_apparition = 0.0
		_faire_apparaitre(vague)

	_depuis_caisse += delta
	if _depuis_caisse >= 6.0 and _caisses.size() < CAISSES_MAX:
		_depuis_caisse = 0.0
		_poser_caisse()

	var voitures := _voitures_connues()
	for m in _monstres:
		var cible := _plus_proche(m["p"], voitures)
		if cible != Vector2.INF:
			var direction: Vector2 = (cible - m["p"]).normalized()
			m["p"] = (m["p"] as Vector2) + direction * float(m["vitesse"]) * delta
		var degage := _degager(m["p"], _rayon_monstre(int(m["type"])))
		m["p"] = degage[0]

	_arbitrer_collisions(voitures)

	_depuis_snapshot += delta
	if _depuis_snapshot >= CADENCE_MONSTRES:
		_depuis_snapshot = 0.0
		var liste: Array = []
		for m in _monstres:
			liste.append([int(m["id"]), int(m["p"].x), int(m["p"].y), int(m["type"]), int(m["pv"])])
		var caisses: Array = []
		for c in _caisses:
			caisses.append([int(c["id"]), int(c["p"].x), int(c["p"].y), String(c["arme"])])
		canal.envoyer("m", {"l": liste, "v": vague, "c": caisses})

## Si l'hôte précédent est parti, celui qui reprend hérite de monstres reçus
## par instantané : ils ont une position et un type, pas de vitesse ni de
## points de vie. Sans cette remise en état ils resteraient figés et
## invulnérables — un troupeau de statues au milieu de la ville.
func _reprendre_la_main() -> void:
	for m in _monstres:
		if not m.has("vitesse") or float(m["vitesse"]) <= 0.0:
			var type := int(m["type"])
			m["vitesse"] = _vitesse_monstre(type, int(temps / 20.0) + 1)
			m["pv"] = _pv_monstre(type)
			m["pv_max"] = _pv_monstre(type)
		_prochain_id = max(_prochain_id, int(m["id"]) + 1)
	for c in _caisses:
		_prochaine_caisse = max(_prochaine_caisse, int(c["id"]) + 1)

## Une épave n'intéresse plus les monstres : la laisser dans la liste, c'est
## la faire harceler pendant qu'elle ne peut pas répondre.
func _voitures_connues() -> Dictionary:
	var v := {}
	if _hors_service <= 0.0:
		v[Session.cle] = {"p": _position, "s": abs(_vitesse), "seuil": seuil_ecrasement()}
	for cle in _autres:
		if float(_autres[cle].get("vie", VIE_MAX)) <= 0.0:
			continue
		v[cle] = {
			"p": _autres[cle]["p"],
			"s": abs(float(_autres[cle]["v"])),
			"seuil": float(_autres[cle].get("seuil", SEUIL_ECRASEMENT)),
		}
	return v

func _plus_proche(depuis: Vector2, voitures: Dictionary) -> Vector2:
	var meilleure := Vector2.INF
	var distance := INF
	for cle in voitures:
		var d: float = depuis.distance_squared_to(voitures[cle]["p"])
		if d < distance:
			distance = d
			meilleure = voitures[cle]["p"]
	return meilleure

func _rayon_monstre(type: int) -> float:
	return 26.0 if type == 0 else (42.0 if type == 1 else 20.0)

## Le gros encaisse : c'est ce qui rend sa barre de vie utile, et ce qui
## justifie qu'il rapporte trois fois plus.
func _pv_monstre(type: int) -> int:
	return 3 if type == 1 else 1

func _vitesse_monstre(type: int, vague: int) -> float:
	var base := 78.0 + vague * 5.0
	if type == 1:
		return base * 0.62
	if type == 2:
		return base * 1.75
	return base

func _faire_apparaitre(vague: int) -> void:
	var type := 0
	var tirage := _rng.randf()
	if vague >= 3 and tirage < 0.18:
		type = 1                      # gros : lent, encaisse, rapporte
	elif vague >= 2 and tirage < 0.42:
		type = 2                      # rapide : nerveux, fragile
	# Ils surgissent dans une rue autour d'une voiture, hors de vue mais à
	# portée de marche. Les faire naître aux confins de la ville les
	# obligerait à traverser des milliers de pixels avant d'être menaçants.
	var autour := _position
	if not _autres.is_empty() and _rng.randf() < 0.5:
		var cles := _autres.keys()
		autour = _autres[cles[_rng.randi_range(0, cles.size() - 1)]]["p"]
	var p := _point_de_rue(autour, 520.0, 860.0)
	_monstres.append({
		"id": _prochain_id, "p": p, "cible": p, "type": type,
		"vitesse": _vitesse_monstre(type, vague), "pv": _pv_monstre(type), "pv_max": _pv_monstre(type),
	})
	_prochain_id += 1

func _poser_caisse() -> void:
	var noms := ARMES.keys()
	var arme := String(noms[_rng.randi_range(0, noms.size() - 1)])
	var p := _point_de_rue(centre_ville(), 200.0, max(etendue().x, etendue().y) * 0.5)
	_caisses.append({"id": _prochaine_caisse, "p": p, "arme": arme})
	_prochaine_caisse += 1

func _retirer_caisse(id: int) -> void:
	for c in _caisses:
		if int(c["id"]) == id:
			var noeud = c.get("noeud")
			if noeud != null:
				(noeud as Node3D).queue_free()
			_caisses.erase(c)
			return

func _arbitrer_collisions(voitures: Dictionary) -> void:
	var a_retirer: Array = []
	for m in _monstres:
		var rayon: float = _rayon_monstre(int(m["type"]))
		for cle in voitures:
			var voiture: Dictionary = voitures[cle]
			if (m["p"] as Vector2).distance_to(voiture["p"]) > rayon + RAYON_VOITURE:
				continue
			if float(voiture["s"]) >= float(voiture["seuil"]):
				m["pv"] = int(m["pv"]) - 1
				if int(m["pv"]) > 0:
					continue
				a_retirer.append(m)
				_compter_victime(cle, m, _points_ecrasement(int(m["type"])), true)
			else:
				# Trop lent : c'est le monstre qui gagne l'échange.
				canal.envoyer("choc", {"j": cle, "x": int(m["p"].x), "y": int(m["p"].y)})
				if cle == Session.cle:
					_encaisser()
				_reculer_monstre(m, voiture["p"])
			break
	for m in a_retirer:
		_liberer(m)
		_monstres.erase(m)

func _points_ecrasement(type: int) -> int:
	if type == 1:
		return 30
	if type == 2:
		return 18
	return 10

## Un monstre disparaît de la simulation ET de la scène. Oublier le maillage
## laisse un fantôme immobile que plus rien ne référence.
func _liberer(m: Dictionary) -> void:
	var noeud = m.get("noeud")
	if noeud != null:
		(noeud as Node3D).queue_free()

func _compter_victime(cle: String, monstre: Dictionary, base: int, avec_combo: bool) -> void:
	var facteur := 1
	if avec_combo:
		var combo: Dictionary = _combos.get(cle, {"dernier": -99.0, "facteur": 0})
		if temps - float(combo["dernier"]) <= COMBO_FENETRE:
			combo["facteur"] = min(int(combo["facteur"]) + 1, 4)
		else:
			combo["facteur"] = 0
		combo["dernier"] = temps
		_combos[cle] = combo
		facteur = int(combo["facteur"]) + 1

	var points := base * facteur
	if joueurs.has(cle):
		joueurs[cle]["score"] = int(joueurs[cle]["score"]) + points
	canal.envoyer("k", {
		"j": cle, "x": int(monstre["p"].x), "y": int(monstre["p"].y),
		"p": points, "f": facteur, "s": int(joueurs.get(cle, {}).get("score", points)),
	})
	_effet_ecrasement(monstre["p"], points, facteur, cle)

func _reculer_monstre(monstre: Dictionary, depuis: Vector2) -> void:
	var direction: Vector2 = (monstre["p"] - depuis).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	monstre["p"] = monstre["p"] + direction * 70.0

# ------------------------------------------------------- réception

func recevoir(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"v":
			var cle := String(charge.get("cle", ""))
			if cle == "" or cle == Session.cle:
				return
			var cible := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			if not _autres.has(cle):
				var noeud := _batir_voiture(
					Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))),
					String(joueurs.get(cle, {}).get("pseudo", "")))
				noeud.position = Decor.vers3d(cible)
				monde().add_child(noeud)
				_autres[cle] = {"p": cible, "a": 0.0, "v": 0.0, "vie": VIE_MAX,
					"cible": cible, "angle_cible": 0.0, "noeud": noeud}
			_autres[cle]["cible"] = cible
			_autres[cle]["angle_cible"] = float(charge.get("a", 0.0))
			_autres[cle]["v"] = float(charge.get("s", 0))
			_autres[cle]["vie"] = float(charge.get("h", VIE_MAX))
		"m":
			if est_hote():
				return
			_appliquer_snapshot(charge.get("l", []), charge.get("c", []))
		"tir":
			if String(charge.get("cle", "")) == Session.cle:
				return
			_creer_projectile(
				Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				float(charge.get("a", 0.0)), String(charge.get("arme", "mitraillette")),
				String(charge.get("cle", "")))
		"ramasse":
			if not est_hote():
				return
			var qui := String(charge.get("cle", ""))
			for c in _caisses:
				if int(c["id"]) == int(charge.get("id", -1)):
					_accorder(qui, String(c["arme"]))
					_retirer_caisse(int(c["id"]))
					return
		"arme":
			if String(charge.get("j", "")) == Session.cle:
				_equiper(String(charge.get("arme", "")))
			elif _autres.has(String(charge.get("j", ""))):
				_autres[String(charge.get("j", ""))]["seuil"] = \
					SEUIL_EPERON if String(charge.get("arme", "")) == "eperon" else SEUIL_ECRASEMENT
		"k":
			var cle_k := String(charge.get("j", ""))
			if joueurs.has(cle_k):
				joueurs[cle_k]["score"] = int(charge.get("s", joueurs[cle_k]["score"]))
			_effet_ecrasement(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				int(charge.get("p", 0)), int(charge.get("f", 1)), cle_k)
		"choc":
			if String(charge.get("j", "")) == Session.cle:
				_encaisser()

func _appliquer_snapshot(liste, caisses) -> void:
	if typeof(liste) == TYPE_ARRAY:
		var vus := {}
		for entree in liste:
			if typeof(entree) != TYPE_ARRAY or (entree as Array).size() < 4:
				continue
			var id := int(entree[0])
			vus[id] = true
			var p := Vector2(float(entree[1]), float(entree[2]))
			var trouve := false
			for m in _monstres:
				if int(m["id"]) == id:
					m["cible"] = p
					if (entree as Array).size() >= 5:
						m["pv"] = int(entree[4])
					trouve = true
					break
			if not trouve:
				var type_recu := int(entree[3])
				_monstres.append({"id": id, "p": p, "cible": p, "type": type_recu,
					"vitesse": 0.0, "pv": _pv_monstre(type_recu), "pv_max": _pv_monstre(type_recu)})
		# Un monstre absent du dernier état a été tué (ou l'hôte a changé) :
		# on ne le garde pas à l'écran, sinon il devient un fantôme intouchable.
		var restants: Array = []
		for m in _monstres:
			if vus.has(int(m["id"])):
				restants.append(m)
			else:
				_liberer(m)
		_monstres = restants

	if typeof(caisses) == TYPE_ARRAY:
		var vues := {}
		for entree in caisses:
			if typeof(entree) != TYPE_ARRAY or (entree as Array).size() < 4:
				continue
			var id := int(entree[0])
			vues[id] = true
			var connue := false
			for c in _caisses:
				if int(c["id"]) == id:
					connue = true
					break
			if not connue:
				_caisses.append({
					"id": id, "arme": String(entree[3]),
					"p": Vector2(float(entree[1]), float(entree[2])),
				})
		var gardees: Array = []
		for c in _caisses:
			if vues.has(int(c["id"])):
				gardees.append(c)
			else:
				var noeud = c.get("noeud")
				if noeud != null:
					(noeud as Node3D).queue_free()
		_caisses = gardees

func _encaisser() -> void:
	if _sonne > 0.0 or _hors_service > 0.0:
		return
	_depuis_coup = 0.0
	_vie -= DEGAT_MONSTRE
	_vitesse *= 0.25
	_secousse = 0.6
	if _vie <= 0.0:
		_vie = 0.0
		_hors_service = HORS_SERVICE
		Sons.jouer("ecrasement", 0.5, -3.0)
	else:
		_sonne = 0.45
		Sons.jouer("choc", 1.0, -6.0)

# ------------------------------------------------------- effets

func _effet_ecrasement(position: Vector2, points: int, facteur: int, cle: String) -> void:
	var couleur := Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 0)))
	Sons.jouer("ecrasement", _rng.randf_range(0.85, 1.2), -8.0)

	# Une flaque au sol, bien plus sombre que les monstres : à la même teinte,
	# elle se lit comme une cible et on fonce dessus pour rien. Leur nombre est
	# borné — sans plafond, une manche pleine empile des centaines de maillages.
	var flaque := Decor.cylindre(_rng.randf_range(1.1, 1.9), 0.08, Palette.BON.darkened(0.78), false)
	flaque.position = Decor.vers3d(position, 0.05)
	flaque.rotation.y = _rng.randf() * TAU
	monde().add_child(flaque)
	_taches.append(flaque)
	if _taches.size() > 90:
		(_taches.pop_front() as Node3D).queue_free()

	for i in 12:
		var eclat := Decor.sphere(_rng.randf_range(0.18, 0.42), Palette.BON, false)
		eclat.position = Decor.vers3d(position, 1.0)
		monde().add_child(eclat)
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(1.4, 3.2), _rng.randf_range(-1, 1))
		_eclats.append({"noeud": eclat, "v": direction * _rng.randf_range(6, 14), "t": 1.0, "t0": 1.0})

	var mention := Decor.etiquette("+%d%s" % [points, ("  x%d" % facteur) if facteur > 1 else ""], couleur, 44)
	mention.position = Decor.vers3d(position, 3.0)
	monde().add_child(mention)
	_eclats.append({"noeud": mention, "v": Vector3(0, 7.0, 0), "t": 1.1, "t0": 1.1, "texte": true})

func _effet_explosion(position: Vector2) -> void:
	Sons.jouer("ecrasement", 0.6, -4.0)
	_secousse = max(_secousse, 0.35)
	for i in 18:
		var eclat := Decor.sphere(_rng.randf_range(0.3, 0.7), Palette.SERIEUX, false)
		eclat.material_override = Decor.matiere_lumineuse(Palette.SERIEUX, 1.2)
		eclat.position = Decor.vers3d(position, 1.2)
		monde().add_child(eclat)
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.6, 2.4), _rng.randf_range(-1, 1))
		_eclats.append({"noeud": eclat, "v": direction * _rng.randf_range(14, 26), "t": 0.7, "t0": 0.7})

func _animer_effets(delta: float) -> void:
	var restants: Array = []
	for e in _eclats:
		e["t"] = float(e["t"]) - delta
		var noeud: Node3D = e["noeud"]
		if float(e["t"]) <= 0.0:
			noeud.queue_free()
			continue
		var v: Vector3 = e["v"]
		noeud.position += v * delta
		if not e.has("texte"):
			v.y -= 26.0 * delta          # les éclats retombent
			e["v"] = v
			if noeud.position.y < 0.12:
				noeud.position.y = 0.12
				e["v"] = Vector3(v.x * 0.4, -v.y * 0.35, v.z * 0.4)
		var reste: float = clamp(float(e["t"]) / float(e["t0"]), 0.0, 1.0)
		if noeud is Label3D:
			(noeud as Label3D).modulate.a = reste
		else:
			noeud.scale = Vector3.ONE * max(0.05, reste)
		restants.append(e)
	_eclats = restants

# ------------------------------------------------------- rendu

func rafraichir_scene(delta: float) -> void:
	_corps.position = Decor.vers3d(_position, 0.0)
	_corps.rotation.y = -_angle
	# Assiette : la voiture pique du nez au freinage et se cabre à
	# l'accélération. Trois degrés suffisent à faire sentir la masse.
	var assiette: float = clamp(_vitesse / VITESSE_MAX, -1.0, 1.0)
	_corps.rotation.z = lerp(_corps.rotation.z, deg_to_rad(-assiette * 3.0), clamp(delta * 6.0, 0, 1))
	if _sonne > 0.0:
		_corps.rotation.z = sin(_sonne * 40.0) * 0.25
	var buffle := _corps.get_node_or_null("Buffle") as MeshInstance3D
	if buffle:
		buffle.visible = _eperon > 0.0
	_regler_jauge(_corps, _vie / VIE_MAX)
	_corps.visible = _hors_service <= 0.0 or fmod(_hors_service, 0.3) > 0.15

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var noeud: Node3D = a["noeud"]
		noeud.position = Decor.vers3d(a["p"])
		noeud.rotation.y = -float(a["a"])
		_regler_jauge(noeud, float(a.get("vie", VIE_MAX)) / VIE_MAX)

	for m in _monstres:
		var noeud_m = m.get("noeud")
		if noeud_m == null:
			noeud_m = _batir_monstre(int(m["type"]))
			monde().add_child(noeud_m)
			m["noeud"] = noeud_m
		(noeud_m as Node3D).position = Decor.vers3d(m["p"])
		var corps := (noeud_m as Node3D).get_node_or_null("Corps") as Node3D
		if corps:
			corps.position.y = 1.7 + sin(temps * 3.4 + float(int(m["id"])) * 1.3) * 0.45
			corps.rotation.z = sin(temps * 3.0 + float(int(m["id"]))) * 0.12
		_regler_jauge(noeud_m, float(int(m.get("pv", 1))) / float(max(1, int(m.get("pv_max", 1)))))

	for c in _caisses:
		var noeud_c = c.get("noeud")
		if noeud_c == null:
			noeud_c = _batir_caisse(String(c["arme"]))
			monde().add_child(noeud_c)
			c["noeud"] = noeud_c
		(noeud_c as Node3D).position = Decor.vers3d(c["p"])
		var objet := (noeud_c as Node3D).get_node_or_null("Objet") as Node3D
		if objet:
			objet.rotation.y = temps * 1.3
			objet.position.y = 1.6 + sin(temps * 2.2 + float(int(c["id"]))) * 0.28

	_animer_effets(delta)
	_placer_camera(delta)

## La jauge est fille de la voiture : sans compenser la rotation, elle
## tournerait avec elle et deviendrait illisible dès le premier virage.
func _regler_jauge(porteur: Node3D, part: float) -> void:
	var jauge := porteur.get_node_or_null("Vie") as Node3D
	if jauge == null:
		return
	jauge.rotation.y = -porteur.rotation.y
	jauge.visible = part < 0.999
	if jauge.visible:
		Decor.remplir(jauge, part)

func _placer_camera(delta: float) -> void:
	if _camera == null:
		return
	var vise := Decor.viser(_camera, _position, INCLINAISON, DISTANCE)
	if _secousse > 0.0:
		_secousse = max(0.0, _secousse - delta * 2.0)
		vise += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _secousse * 2.5
	_camera.position = _camera.position.lerp(vise, clamp(delta * 7.0, 0, 1))

## Ce que le socle affiche en bas de l'écran : l'arme en main, ses munitions,
## et l'avertissement quand on quitte la ville.
func etat_joueur() -> String:
	var morceaux: Array = []
	if _hors_service > 0.0:
		return "HORS SERVICE — retour dans %d s" % int(ceil(_hors_service))
	morceaux.append("Vie %d%%" % int(_vie))
	if _eperon > 0.0:
		morceaux.append("Éperon %ds" % int(ceil(_eperon)))
	if _arme != "":
		morceaux.append("%s %d" % [String(ARMES[_arme]["nom"]), _munitions])
	if morceaux.is_empty():
		morceaux.append("À mains nues — ramassez une caisse")
	if _hors_ville > 0.2:
		morceaux.append("VOUS QUITTEZ LA VILLE")
	return "   ·   ".join(morceaux)
