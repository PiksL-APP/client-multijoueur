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

const SEUIL_ECRASEMENT := 210.0    ## en dessous, on pousse le monstre sans l'écraser
const CADENCE_VOITURE := 1.0 / 12.0
const CADENCE_MONSTRES := 1.0 / 9.0
const MONSTRES_MAX := 48
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
var _eclats: Array = []            # particules
var _taches: Array = []            # traces au sol
var _camera: Camera2D
var _rng := RandomNumberGenerator.new()

func duree_manche() -> float:
	return DUREE

func aide() -> String:
	return "Z/S ou ↑/↓ : accélérer et freiner · Q/D ou ←/→ : tourner · écraser un monstre lancé rapporte, les enchaînements multiplient."

func preparer() -> void:
	_rng.randomize()
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.85, 0.85)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()
	# Départ réparti sur un cercle : quatre voitures au même endroit se
	# poussent mutuellement hors de l'arène avant même le décompte.
	var place := 0
	for cle in donnees.get("equipe", []):
		if String(cle.get("cle", "")) == Session.id:
			break
		place += 1
	var angle := TAU * float(place) / 4.0
	_position = ARENE.get_center() + Vector2.RIGHT.rotated(angle) * 260.0
	_angle = angle + PI

# ------------------------------------------------------- simulation locale

func simuler_local(delta: float) -> void:
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

	_animer_effets(delta)

func _conduire(delta: float) -> void:
	if _sonne > 0.0:
		_sonne -= delta
		_angle += delta * 7.0        # la voiture part en toupie : le choc se voit
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta * 0.6)
	else:
		var avant := Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
		var arriere := Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		var gauche := Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
		var droite := Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)

		if avant:
			_vitesse = min(_vitesse + ACCELERATION * delta, VITESSE_MAX)
		elif arriere:
			_vitesse = max(_vitesse - FREIN * delta, VITESSE_ARRIERE)
		else:
			_vitesse = move_toward(_vitesse, 0.0, FROTTEMENT * abs(_vitesse) * delta + 40.0 * delta)

		# Le braquage suit la vitesse : à l'arrêt, on ne pivote pas sur place.
		var prise := clamp(abs(_vitesse) / 260.0, 0.0, 1.0) * signf(_vitesse)
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
	_depuis_apparition += delta
	var intervalle: float = max(0.28, 1.4 - vague * 0.16)
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
	var v := {Session.id: {"p": _position, "s": abs(_vitesse)}}
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
	var bord := _rng.randi_range(0, 3)
	var p := Vector2.ZERO
	match bord:
		0: p = Vector2(_rng.randf_range(ARENE.position.x, ARENE.end.x), ARENE.position.y + 10)
		1: p = Vector2(_rng.randf_range(ARENE.position.x, ARENE.end.x), ARENE.end.y - 10)
		2: p = Vector2(ARENE.position.x + 10, _rng.randf_range(ARENE.position.y, ARENE.end.y))
		_: p = Vector2(ARENE.end.x - 10, _rng.randf_range(ARENE.position.y, ARENE.end.y))
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
				if cle == Session.id:
					_encaisser()
				_reculer_monstre(m, voiture["p"])
			break
	for m in a_retirer:
		_monstres.erase(m)

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
	var direction := (monstre["p"] - depuis).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	monstre["p"] = monstre["p"] + direction * 70.0

# ------------------------------------------------------- réception

func recevoir(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"v":
			var cle := String(charge.get("cle", ""))
			if cle == "" or cle == Session.id:
				return
			var cible := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			if not _autres.has(cle):
				_autres[cle] = {"p": cible, "a": 0.0, "v": 0.0, "cible": cible, "angle_cible": 0.0}
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
			if String(charge.get("j", "")) == Session.id:
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
	_monstres = restants

func _encaisser() -> void:
	if _sonne > 0.0:
		return
	_sonne = 0.7
	_vitesse *= 0.2
	_camera.offset = Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-14, 14))
	var tween := create_tween()
	tween.tween_property(_camera, "offset", Vector2.ZERO, 0.35)

# ------------------------------------------------------- effets

func _effet_ecrasement(position: Vector2, points: int, facteur: int, cle: String) -> void:
	var couleur := Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 0)))
	for i in 14:
		var angle := _rng.randf() * TAU
		_eclats.append({
			"p": position, "v": Vector2.RIGHT.rotated(angle) * _rng.randf_range(80, 320),
			"t": _rng.randf_range(0.35, 0.8), "t0": 0.8, "c": Palette.BON.darkened(0.15),
		})
	_taches.append({"p": position, "r": _rng.randf_range(14, 26), "a": _rng.randf() * TAU})
	if _taches.size() > 140:
		_taches.pop_front()
	_eclats.append({
		"p": position, "v": Vector2(0, -60), "t": 1.0, "t0": 1.0, "c": couleur,
		"texte": "+%d%s" % [points, ("  x%d" % facteur) if facteur > 1 else ""],
	})

func _animer_effets(delta: float) -> void:
	var restants: Array = []
	for e in _eclats:
		e["t"] = float(e["t"]) - delta
		if float(e["t"]) <= 0.0:
			continue
		e["p"] = (e["p"] as Vector2) + (e["v"] as Vector2) * delta
		e["v"] = (e["v"] as Vector2) * (1.0 - 3.0 * delta)
		restants.append(e)
	_eclats = restants

# ------------------------------------------------------- rendu

func dessiner_scene() -> void:
	draw_rect(ARENE, Color("#111110"), true)
	var pas := 100
	var x := int(ARENE.position.x)
	while x <= int(ARENE.end.x):
		draw_line(Vector2(x, ARENE.position.y), Vector2(x, ARENE.end.y), Color(1, 1, 1, 0.035), 1.0)
		x += pas
	var y := int(ARENE.position.y)
	while y <= int(ARENE.end.y):
		draw_line(Vector2(ARENE.position.x, y), Vector2(ARENE.end.x, y), Color(1, 1, 1, 0.035), 1.0)
		y += pas
	draw_rect(ARENE, Palette.CRITIQUE.darkened(0.3), false, 4.0)

	for t in _taches:
		draw_circle(t["p"], float(t["r"]), Color(Palette.BON.darkened(0.55), 0.5))

	for m in _monstres:
		_dessiner_monstre(m)

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		_dessiner_voiture(a["p"], float(a["a"]),
			Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))),
			String(joueurs.get(cle, {}).get("pseudo", "")))
	_dessiner_voiture(_position, _angle, Palette.couleur_joueur(ma_place()), Session.pseudo)

	for e in _eclats:
		var opacite: float = clamp(float(e["t"]) / float(e["t0"]), 0.0, 1.0)
		if e.has("texte"):
			draw_string(Palette.police(), e["p"] + Vector2(-20, 0), String(e["texte"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(e["c"], opacite))
		else:
			draw_circle(e["p"], 4.0 * opacite + 1.0, Color(e["c"], opacite))

func _dessiner_monstre(m: Dictionary) -> void:
	var type := int(m["type"])
	var rayon: float = 20.0 if type == 0 else (32.0 if type == 1 else 16.0)
	var couleur := Palette.BON if type == 0 else (Palette.SERIEUX if type == 1 else Palette.AVERTISSEMENT)
	var p: Vector2 = m["p"]
	draw_circle(p + Vector2(0, 5), rayon * 0.9, Color(0, 0, 0, 0.35))
	draw_circle(p, rayon, couleur.darkened(0.35))
	draw_arc(p, rayon, 0, TAU, 24, couleur, 2.0, true)
	draw_circle(p + Vector2(-rayon * 0.32, -rayon * 0.2), rayon * 0.16, Palette.FOND)
	draw_circle(p + Vector2(rayon * 0.32, -rayon * 0.2), rayon * 0.16, Palette.FOND)

func _dessiner_voiture(position: Vector2, angle: float, couleur: Color, pseudo: String) -> void:
	draw_set_transform(position, angle, Vector2.ONE)
	draw_rect(Rect2(-30, -18, 60, 36), Color(0, 0, 0, 0.35), true)
	draw_rect(Rect2(-28, -16, 56, 32), couleur, true)
	draw_rect(Rect2(-28, -16, 56, 32), Palette.FOND, false, 2.0)
	draw_rect(Rect2(2, -12, 16, 24), Palette.FOND.lightened(0.12), true)   # pare-brise
	draw_rect(Rect2(26, -14, 8, 28), Palette.ENCRE_DOUCE, true)            # pare-buffle
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if pseudo != "":
		var police := Palette.police()
		var largeur := police.get_string_size(pseudo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(police, position + Vector2(-largeur * 0.5, -34), pseudo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.ENCRE_DOUCE)

func _process(delta: float) -> void:
	super._process(delta)
	if _camera and phase != FIN:
		_camera.position = _position
