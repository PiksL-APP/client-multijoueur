extends Partie
## CARNAGE — quatre voitures, une arène, des monstres à écraser.
##
## Répartition du travail : chaque client conduit SA voiture et annonce sa
## position ; l'hôte fait vivre les monstres, tranche les collisions et tient
## le score. Faire trancher la collision par celui qui écrase serait plus
## nerveux, mais deux joueurs revendiqueraient le même monstre à 100 ms près.

const ARENE := Rect2(0, 0, 2200, 1400)
const DUREE := 120.0

# Conduite : des valeurs d'arcade, pas de simulation. On veut qu'une voiture
# reparte vite après un choc, sinon le jeu punit la maladresse trop longtemps.
const ACCELERATION := 900.0
const FREIN := 1500.0
const VITESSE_MAX := 720.0
const VITESSE_ARRIERE := -260.0
const FROTTEMENT := 1.6
const BRAQUAGE := 2.9
const RAYON_VOITURE := 26.0

const INCLINAISON := 52.0
const DISTANCE := 46.0

const SEUIL_ECRASEMENT := 210.0    ## en dessous, on pousse le monstre sans l'écraser
const CADENCE_VOITURE := 1.0 / 12.0
const CADENCE_MONSTRES := 1.0 / 9.0
const MONSTRES_MAX := 60
const COMBO_FENETRE := 2.5

var _position := Vector2.ZERO
var _angle := 0.0
var _vitesse := 0.0
var _sonne := 0.0                  ## secondes de perte de contrôle après un choc

var _autres: Dictionary = {}       # cle -> {p, a, v, cible, angle_cible}
var _monstres: Array = []          # hôte : dicts ; client : copie interpolée
var _prochain_id := 1
var _depuis_envoi := 0.0
var _depuis_snapshot := 0.0
var _depuis_apparition := 0.0
var _combos: Dictionary = {}       # cle -> {dernier, facteur}
var _eclats: Array = []            # particules 3D
var _taches: Array = []            # flaques au sol, en nombre borné
var _camera: Camera3D
var _corps: Node3D                 # notre voiture
var _rng := RandomNumberGenerator.new()
var _secousse := 0.0
var _amorce := false

func duree_manche() -> float:
	return DUREE

func aide() -> String:
	return "Z/S ou ↑/↓ : accélérer et freiner · Q/D ou ←/→ : tourner · écraser un monstre lancé rapporte, les enchaînements multiplient."

func preparer() -> void:
	_rng.randomize()
	_batir_arene()

	# Départ réparti sur un cercle : quatre voitures au même endroit se
	# poussent mutuellement hors de l'arène avant même le décompte.
	var place := 0
	for membre in donnees.get("equipe", []):
		if String(membre.get("cle", "")) == Session.cle:
			break
		place += 1
	var angle := TAU * float(place) / 4.0
	_position = ARENE.get_center() + Vector2.RIGHT.rotated(angle) * 260.0
	_angle = angle + PI

	_corps = _batir_voiture(Palette.couleur_joueur(place), Session.pseudo)
	monde().add_child(_corps)

	_camera = Decor.camera(INCLINAISON, DISTANCE, 52.0)
	monde().add_child(_camera)
	_camera.make_current()

func _batir_arene() -> void:
	poser_ambiance()
	var sol := Decor.sol(ARENE.size, 100.0, Color("#141312"))
	sol.position = Decor.vers3d(ARENE.get_center())
	monde().add_child(sol)

	# Un muret bas tout autour : il borne le terrain à l'œil et son ombre
	# rasante donne au sol une épaisseur qu'un plan nu n'a pas.
	var e := 24.0
	var t := ARENE.size
	for mur in [
		[Vector2(t.x * 0.5, -e * 0.5), Vector2(t.x + e * 2.0, e)],
		[Vector2(t.x * 0.5, t.y + e * 0.5), Vector2(t.x + e * 2.0, e)],
		[Vector2(-e * 0.5, t.y * 0.5), Vector2(e, t.y)],
		[Vector2(t.x + e * 0.5, t.y * 0.5), Vector2(e, t.y)],
	]:
		var boite := Decor.boite(
			Vector3(mur[1].x * Decor.ECHELLE, 4.2, mur[1].y * Decor.ECHELLE),
			Palette.CRITIQUE.darkened(0.6))
		boite.position = Decor.vers3d(mur[0], 2.1)
		monde().add_child(boite)

func _batir_voiture(couleur: Color, pseudo: String) -> Node3D:
	var racine := Node3D.new()
	var chassis := Decor.boite(Vector3(5.6, 1.5, 3.2), couleur)
	chassis.position = Vector3(0, 1.05, 0)
	racine.add_child(chassis)
	var cabine := Decor.boite(Vector3(2.4, 1.2, 2.6), couleur.darkened(0.35))
	cabine.position = Vector3(-0.3, 2.3, 0)
	racine.add_child(cabine)
	var pare_buffle := Decor.boite(Vector3(0.7, 1.5, 3.6), Palette.ENCRE_DOUCE)
	pare_buffle.position = Vector3(3.0, 1.2, 0)
	racine.add_child(pare_buffle)
	for cote in [-1.0, 1.0]:
		for avant in [-1.0, 1.0]:
			var roue := Decor.cylindre(0.75, 0.5, Color("#0a0a0a"))
			roue.rotation_degrees = Vector3(90, 0, 0)
			roue.position = Vector3(avant * 1.9, 0.75, cote * 1.7)
			racine.add_child(roue)
	# Deux phares : ils disent dans quel sens la voiture regarde, ce qu'une
	# boîte vue de haut ne montre pas.
	for cote in [-1.0, 1.0]:
		var phare := Decor.sphere(0.34, Palette.AVERTISSEMENT)
		phare.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 1.2)
		phare.position = Vector3(3.1, 1.5, cote * 1.0)
		racine.add_child(phare)
	if pseudo != "":
		var nom := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 32)
		nom.name = "Nom"
		nom.position = Vector3(0, 5.2, 0)
		racine.add_child(nom)
	return racine

func _batir_monstre(type: int) -> Node3D:
	var racine := Node3D.new()
	var rayon: float = 2.6 if type == 0 else (4.2 if type == 1 else 2.0)
	var couleur := Palette.BON if type == 0 else (Palette.SERIEUX if type == 1 else Palette.AVERTISSEMENT)
	var corps := Decor.sphere(rayon, couleur.darkened(0.25))
	corps.position = Vector3(0, rayon * 0.85, 0)
	corps.name = "Corps"
	racine.add_child(corps)
	for cote in [-1.0, 1.0]:
		var oeil := Decor.sphere(rayon * 0.22, Palette.FOND, false)
		oeil.position = Vector3(rayon * 0.62, rayon * 1.15, cote * rayon * 0.42)
		racine.add_child(oeil)
	var crete := Decor.boite(Vector3(rayon * 0.4, rayon * 0.9, rayon * 0.3), couleur.lightened(0.3))
	crete.position = Vector3(-rayon * 0.4, rayon * 1.5, 0)
	racine.add_child(crete)
	return racine

# ------------------------------------------------------- simulation locale

func simuler_local(delta: float) -> void:
	if Commandes.pilote_automatique:
		Commandes.direction_simulee = _viser_le_plus_proche()
	_conduire(delta)
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["p"] = (a["p"] as Vector2).lerp(a["cible"], clamp(delta * 14.0, 0, 1))
		a["a"] = lerp_angle(a["a"], a["angle_cible"], clamp(delta * 14.0, 0, 1))

	_depuis_envoi += delta
	if _depuis_envoi >= CADENCE_VOITURE:
		_depuis_envoi = 0.0
		canal.envoyer("v", {
			"x": int(_position.x), "y": int(_position.y),
			"a": snapped(_angle, 0.01), "s": int(_vitesse),
		})

	if not est_hote():
		for m in _monstres:
			m["p"] = (m["p"] as Vector2).lerp(m["cible"], clamp(delta * 10.0, 0, 1))

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
		return Vector2(0.4, 1.0)
	var ecart := wrapf((cible - _position).angle() - _angle, -PI, PI)
	return Vector2(clamp(ecart * 2.0, -1.0, 1.0), 1.0)

func _conduire(delta: float) -> void:
	if _sonne > 0.0:
		_sonne -= delta
		_angle += delta * 7.0        # la voiture part en toupie : le choc se voit
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta * 0.6)
	else:
		var commande := Commandes.conduite()
		var avant := commande.y > 0.1
		var arriere := commande.y < -0.1
		var gauche := commande.x < -0.1
		var droite := commande.x > 0.1

		if avant:
			_vitesse = min(_vitesse + ACCELERATION * delta, VITESSE_MAX)
		elif arriere:
			_vitesse = max(_vitesse - FREIN * delta, VITESSE_ARRIERE)
		else:
			_vitesse = move_toward(_vitesse, 0.0, FROTTEMENT * abs(_vitesse) * delta + 40.0 * delta)

		# Le braquage suit la vitesse : à l'arrêt, on ne pivote pas sur place.
		var prise: float = clamp(abs(_vitesse) / 260.0, 0.0, 1.0) * signf(_vitesse)
		if gauche:
			_angle -= BRAQUAGE * delta * prise
		if droite:
			_angle += BRAQUAGE * delta * prise

	_position += Vector2.RIGHT.rotated(_angle) * _vitesse * delta

	# Les murs rendent la vitesse : ils ne tuent pas, ils coûtent l'élan.
	var avant_choc := _position
	_position.x = clamp(_position.x, ARENE.position.x + RAYON_VOITURE, ARENE.end.x - RAYON_VOITURE)
	_position.y = clamp(_position.y, ARENE.position.y + RAYON_VOITURE, ARENE.end.y - RAYON_VOITURE)
	if _position != avant_choc:
		_vitesse *= 0.35

# ------------------------------------------------------- simulation hôte

func simuler_hote(delta: float) -> void:
	var vague := int(temps / 20.0) + 1
	# Une bouffée au coup d'envoi : sans elle, les vingt premières secondes se
	# passent à chercher un monstre à l'écran, et la manche commence mollement.
	if not _amorce:
		_amorce = true
		for i in 10:
			_faire_apparaitre(vague)
	_depuis_apparition += delta
	var intervalle: float = max(0.14, 0.62 - vague * 0.07)
	if _depuis_apparition >= intervalle and _monstres.size() < MONSTRES_MAX:
		_depuis_apparition = 0.0
		_faire_apparaitre(vague)

	var voitures := _voitures_connues()
	for m in _monstres:
		var cible := _plus_proche(m["p"], voitures)
		if cible != Vector2.INF:
			var direction: Vector2 = (cible - m["p"]).normalized()
			m["p"] = (m["p"] as Vector2) + direction * float(m["vitesse"]) * delta
		m["p"].x = clamp(m["p"].x, ARENE.position.x, ARENE.end.x)
		m["p"].y = clamp(m["p"].y, ARENE.position.y, ARENE.end.y)

	_arbitrer_collisions(voitures)

	_depuis_snapshot += delta
	if _depuis_snapshot >= CADENCE_MONSTRES:
		_depuis_snapshot = 0.0
		var liste: Array = []
		for m in _monstres:
			liste.append([int(m["id"]), int(m["p"].x), int(m["p"].y), int(m["type"])])
		canal.envoyer("m", {"l": liste, "v": vague})

func _voitures_connues() -> Dictionary:
	var v := {Session.cle: {"p": _position, "s": abs(_vitesse)}}
	for cle in _autres:
		v[cle] = {"p": _autres[cle]["p"], "s": abs(float(_autres[cle]["v"]))}
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

func _faire_apparaitre(vague: int) -> void:
	var type := 0
	var tirage := _rng.randf()
	if vague >= 3 and tirage < 0.18:
		type = 1                      # gros : lent, encaisse, rapporte
	elif vague >= 2 and tirage < 0.42:
		type = 2                      # rapide : nerveux, fragile
	# Ils surgissent en couronne autour d'une voiture, hors de vue mais à
	# portée de marche. Les faire naître aux bords de l'arène — ce qu'on
	# faisait d'abord — les obligeait à traverser douze cents pixels avant
	# d'être menaçants : le joueur ne croisait presque personne.
	var autour := _position
	if not _autres.is_empty() and _rng.randf() < 0.5:
		var cles := _autres.keys()
		autour = _autres[cles[_rng.randi_range(0, cles.size() - 1)]]["p"]
	var p: Vector2 = autour + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(520.0, 820.0)
	p.x = clamp(p.x, ARENE.position.x + 30.0, ARENE.end.x - 30.0)
	p.y = clamp(p.y, ARENE.position.y + 30.0, ARENE.end.y - 30.0)
	var vitesse := 78.0 + vague * 5.0
	if type == 1:
		vitesse *= 0.62
	elif type == 2:
		vitesse *= 1.75
	_monstres.append({
		"id": _prochain_id, "p": p, "cible": p, "type": type,
		"vitesse": vitesse, "pv": 2 if type == 1 else 1,
	})
	_prochain_id += 1

func _arbitrer_collisions(voitures: Dictionary) -> void:
	var a_retirer: Array = []
	for m in _monstres:
		var rayon: float = 20.0 if m["type"] == 0 else (32.0 if m["type"] == 1 else 16.0)
		for cle in voitures:
			var voiture: Dictionary = voitures[cle]
			if (m["p"] as Vector2).distance_to(voiture["p"]) > rayon + RAYON_VOITURE:
				continue
			if float(voiture["s"]) >= SEUIL_ECRASEMENT:
				m["pv"] = int(m["pv"]) - 1
				if int(m["pv"]) > 0:
					continue
				a_retirer.append(m)
				_compter_ecrasement(cle, m)
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

## Un monstre disparaît de la simulation ET de la scène. Oublier le maillage
## laisse un fantôme immobile que plus rien ne référence.
func _liberer(m: Dictionary) -> void:
	var noeud = m.get("noeud")
	if noeud != null:
		(noeud as Node3D).queue_free()

func _compter_ecrasement(cle: String, monstre: Dictionary) -> void:
	var base := 10
	if monstre["type"] == 1:
		base = 30
	elif monstre["type"] == 2:
		base = 18

	var combo: Dictionary = _combos.get(cle, {"dernier": -99.0, "facteur": 0})
	if temps - float(combo["dernier"]) <= COMBO_FENETRE:
		combo["facteur"] = min(int(combo["facteur"]) + 1, 4)
	else:
		combo["facteur"] = 0
	combo["dernier"] = temps
	_combos[cle] = combo

	var facteur := int(combo["facteur"]) + 1
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
				_autres[cle] = {"p": cible, "a": 0.0, "v": 0.0, "cible": cible, "angle_cible": 0.0, "noeud": noeud}
			_autres[cle]["cible"] = cible
			_autres[cle]["angle_cible"] = float(charge.get("a", 0.0))
			_autres[cle]["v"] = float(charge.get("s", 0))
		"m":
			if est_hote():
				return
			_appliquer_snapshot(charge.get("l", []))
		"k":
			var cle_k := String(charge.get("j", ""))
			if joueurs.has(cle_k):
				joueurs[cle_k]["score"] = int(charge.get("s", joueurs[cle_k]["score"]))
			_effet_ecrasement(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				int(charge.get("p", 0)), int(charge.get("f", 1)), cle_k)
		"choc":
			if String(charge.get("j", "")) == Session.cle:
				_encaisser()

func _appliquer_snapshot(liste) -> void:
	if typeof(liste) != TYPE_ARRAY:
		return
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
				trouve = true
				break
		if not trouve:
			_monstres.append({"id": id, "p": p, "cible": p, "type": int(entree[3]), "vitesse": 0.0, "pv": 1})
	# Un monstre absent du dernier état a été écrasé (ou l'hôte a changé) :
	# on ne le garde pas à l'écran, sinon il devient un fantôme intouchable.
	var restants: Array = []
	for m in _monstres:
		if vus.has(int(m["id"])):
			restants.append(m)
		else:
			_liberer(m)
	_monstres = restants

func _encaisser() -> void:
	if _sonne > 0.0:
		return
	_sonne = 0.7
	_vitesse *= 0.2
	_secousse = 0.5

# ------------------------------------------------------- effets

func _effet_ecrasement(position: Vector2, points: int, facteur: int, cle: String) -> void:
	var couleur := Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 0)))

	# Une flaque au sol : la trace de ce qui vient d'être écrasé. Le nombre en
	# est borné — sans plafond, une manche pleine finit par empiler des
	# centaines de maillages et le rendu s'effondre en fin de partie.
	# Bien plus sombres que les monstres : à la même teinte, une flaque au sol
	# se lit comme une cible et on fonce dessus pour rien.
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

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var noeud: Node3D = a["noeud"]
		noeud.position = Decor.vers3d(a["p"])
		noeud.rotation.y = -float(a["a"])

	for m in _monstres:
		var noeud: Node3D = m.get("noeud")
		if noeud == null:
			noeud = _batir_monstre(int(m["type"]))
			monde().add_child(noeud)
			m["noeud"] = noeud
		noeud.position = Decor.vers3d(m["p"])
		# Ils sautillent, et se tournent vers là où ils vont : un monstre qui
		# glisse sans bouger ne fait pas peur.
		var corps := noeud.get_node_or_null("Corps") as Node3D
		if corps:
			corps.position.y = abs(sin(temps * 7.0 + float(int(m["id"])) * 1.3)) * 0.7 + 1.4
		var vers: Vector2 = (m["cible"] as Vector2) - (m["p"] as Vector2) if m.has("cible") else Vector2.ZERO
		if vers.length() > 1.0:
			noeud.rotation.y = atan2(-vers.x, -vers.y) - PI * 0.5

	_animer_effets(delta)
	_placer_camera(delta)

func _placer_camera(delta: float) -> void:
	if _camera == null:
		return
	var vise := Decor.viser(_camera, _position, INCLINAISON, DISTANCE)
	if _secousse > 0.0:
		_secousse = max(0.0, _secousse - delta * 2.0)
		vise += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _secousse * 2.5
	_camera.position = _camera.position.lerp(vise, clamp(delta * 7.0, 0, 1))
