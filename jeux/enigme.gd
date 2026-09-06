extends Partie
## ÉNIGME — trois chambres, une seule sortie, et rien qui s'ouvre tout seul.
##
## Toutes les énigmes reposent sur la même contrainte : une dalle ne reste
## enfoncée que si quelqu'un — ou quelque chose — pèse dessus, et la sortie
## d'une chambre exige que TOUT LE MONDE y soit en même temps. C'est ce qui
## empêche un joueur rapide de finir seul et de laisser les autres derrière.
##
## Deux portes se verrouillent une fois ouvertes (chambres 1 et 3) : sans ce
## verrou, le dernier joueur resté sur sa dalle ne pourrait jamais franchir la
## porte qu'il tient ouverte.

const MONDE := Rect2(0, 0, 1600, 896)
const SORTIE := Rect2(1330, 320, 210, 256)
const DUREE := 180.0
const VITESSE := 260.0
const RAYON := 20.0
const DEMI_CAISSE := 27.0
const PORTEE_DALLE := 46.0
const CADENCE_ENVOI := 1.0 / 12.0
const CADENCE_ETAT := 1.0 / 9.0

var _chambre := 0
var _position := Vector2(140, 448)
var _autres: Dictionary = {}       # cle -> {p, cible}
var _caisses: Array = []           # {id, p}
var _dalles: Array = []            # {id, p}
var _pressees: Dictionary = {}
var _portes: Array = []            # {id, rect, dalles, verrou, ouverte}
var _depuis_envoi := 0.0
var _depuis_etat := 0.0
var _chambres_faites := 0
var _score_equipe := 0
var _message := ""
var _camera: Camera2D

func duree_manche() -> float:
	return DUREE

func aide() -> String:
	return "Z Q S D ou les flèches · marcher dans une caisse la pousse · une dalle ne compte que si quelque chose pèse dessus · la sortie n'accepte l'équipe qu'au complet."

func preparer() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.8, 0.8)
	_camera.position = MONDE.get_center()
	add_child(_camera)
	_camera.make_current()
	_charger_chambre(0)

# ------------------------------------------------------- les chambres

func _plan(indice: int) -> Dictionary:
	match indice:
		0:
			return {
				"nom": "Les deux dalles",
				"consigne": "La porte ne s'ouvre que si les deux dalles sont enfoncées EN MÊME TEMPS. Une caisse pèse autant qu'un joueur.",
				"dalles": [{"id": 1, "p": Vector2(220, 200)}, {"id": 2, "p": Vector2(220, 696)}],
				"caisses": [{"id": 1, "p": Vector2(430, 448)}],
				"portes": [{"id": 1, "dalles": [1, 2], "verrou": true}],
			}
		1:
			return {
				"nom": "Le seuil qu'il faut tenir",
				"consigne": "Cette porte-ci retombe dès que la dalle se relève. Posez la caisse dessus, puis traversez tous ensemble.",
				"dalles": [{"id": 1, "p": Vector2(320, 448)}],
				"caisses": [{"id": 1, "p": Vector2(600, 210)}],
				"portes": [{"id": 1, "dalles": [1], "verrou": false}],
			}
		_:
			return {
				"nom": "Trois dalles, deux caisses",
				"consigne": "Trois dalles à la fois, et vous n'êtes pas forcément trois. Comptez les caisses.",
				"dalles": [
					{"id": 1, "p": Vector2(220, 180)},
					{"id": 2, "p": Vector2(220, 716)},
					{"id": 3, "p": Vector2(580, 448)},
				],
				"caisses": [{"id": 1, "p": Vector2(400, 300)}, {"id": 2, "p": Vector2(400, 600)}],
				"portes": [{"id": 1, "dalles": [1, 2, 3], "verrou": true}],
			}

func _murs() -> Array:
	return [
		Rect2(0, 0, MONDE.size.x, 32),
		Rect2(0, MONDE.size.y - 32, MONDE.size.x, 32),
		Rect2(0, 0, 32, MONDE.size.y),
		Rect2(MONDE.size.x - 32, 0, 32, MONDE.size.y),
		Rect2(832, 32, 32, 288),
		Rect2(832, 576, 32, 288),
	]

func _rect_porte() -> Rect2:
	return Rect2(832, 320, 32, 256)

func _charger_chambre(indice: int) -> void:
	_chambre = indice
	var plan := _plan(indice)
	_dalles = plan["dalles"].duplicate(true)
	_caisses = []
	for c in plan["caisses"]:
		_caisses.append({"id": int(c["id"]), "p": c["p"] as Vector2, "cible": c["p"] as Vector2})
	_portes = []
	for p in plan["portes"]:
		_portes.append({"id": int(p["id"]), "dalles": p["dalles"], "verrou": bool(p["verrou"]), "ouverte": false})
	_pressees = {}
	_message = "Chambre %d — %s\n%s" % [indice + 1, String(plan["nom"]), String(plan["consigne"])]
	# Les joueurs repartent en colonne à gauche : personne ne se réveille de
	# l'autre côté d'une porte qu'il n'a pas ouverte.
	_position = Vector2(120, 340 + ma_place() * 72)
	for cle in _autres:
		_autres[cle]["p"] = Vector2(120, 340)
		_autres[cle]["cible"] = _autres[cle]["p"]

# ------------------------------------------------------- simulation locale

func simuler_local(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if direction != Vector2.ZERO:
		_position += direction.normalized() * VITESSE * delta
		_degager()

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["p"] = (a["p"] as Vector2).lerp(a["cible"], clamp(delta * 14.0, 0, 1))
	if not est_hote():
		for c in _caisses:
			c["p"] = (c["p"] as Vector2).lerp(c["cible"], clamp(delta * 12.0, 0, 1))

	_depuis_envoi += delta
	if _depuis_envoi >= CADENCE_ENVOI:
		_depuis_envoi = 0.0
		canal.envoyer("p", {"x": int(_position.x), "y": int(_position.y)})

## Repousse le joueur hors des murs et des portes fermées. Test axe par axe :
## sortir par le plus petit chevauchement évite de traverser un mur fin quand
## on l'aborde de biais.
func _degager() -> void:
	var obstacles := _murs()
	for porte in _portes:
		if not porte["ouverte"]:
			obstacles.append(_rect_porte())
	for mur in obstacles:
		var etendu := Rect2(mur.position - Vector2(RAYON, RAYON), mur.size + Vector2(RAYON, RAYON) * 2.0)
		if not etendu.has_point(_position):
			continue
		var gauche := _position.x - etendu.position.x
		var droite := etendu.end.x - _position.x
		var haut := _position.y - etendu.position.y
		var bas := etendu.end.y - _position.y
		var minimum: float = min(min(gauche, droite), min(haut, bas))
		if minimum == gauche: _position.x = etendu.position.x
		elif minimum == droite: _position.x = etendu.end.x
		elif minimum == haut: _position.y = etendu.position.y
		else: _position.y = etendu.end.y

# ------------------------------------------------------- simulation hôte

func simuler_hote(delta: float) -> void:
	var positions := _positions_connues()
	_pousser_caisses(positions)
	_evaluer_dalles(positions)
	_evaluer_sortie(positions)

	_depuis_etat += delta
	if _depuis_etat >= CADENCE_ETAT:
		_depuis_etat = 0.0
		var caisses: Array = []
		for c in _caisses:
			caisses.append([int(c["id"]), int(c["p"].x), int(c["p"].y)])
		var ouvertes: Array = []
		for porte in _portes:
			if porte["ouverte"]:
				ouvertes.append(int(porte["id"]))
		canal.envoyer("e", {"c": _chambre, "b": caisses, "d": ouvertes, "z": _pressees.keys()})

func _positions_connues() -> Array:
	var liste := [_position]
	for cle in _autres:
		liste.append(_autres[cle]["p"] as Vector2)
	return liste

func _pousser_caisses(positions: Array) -> void:
	for caisse in _caisses:
		for p in positions:
			var ecart: Vector2 = (caisse["p"] as Vector2) - p
			var distance := ecart.length()
			var contact := RAYON + DEMI_CAISSE
			if distance >= contact or distance == 0.0:
				continue
			var candidate: Vector2 = (caisse["p"] as Vector2) + ecart.normalized() * (contact - distance)
			if _caisse_libre(candidate, int(caisse["id"])):
				caisse["p"] = candidate
			else:
				# Caisse coincée : on ne la fait pas traverser le mur, on
				# laisse le joueur buter. Une caisse dans un mur est un
				# blocage sans issue au milieu d'une énigme.
				var glissement := Vector2(candidate.x, caisse["p"].y)
				if _caisse_libre(glissement, int(caisse["id"])):
					caisse["p"] = glissement
				else:
					glissement = Vector2(caisse["p"].x, candidate.y)
					if _caisse_libre(glissement, int(caisse["id"])):
						caisse["p"] = glissement

func _caisse_libre(position: Vector2, id: int) -> bool:
	var boite := Rect2(position - Vector2(DEMI_CAISSE, DEMI_CAISSE), Vector2(DEMI_CAISSE, DEMI_CAISSE) * 2.0)
	for mur in _murs():
		if boite.intersects(mur):
			return false
	for porte in _portes:
		if not porte["ouverte"] and boite.intersects(_rect_porte()):
			return false
	for autre in _caisses:
		if int(autre["id"]) == id:
			continue
		if boite.intersects(Rect2((autre["p"] as Vector2) - Vector2(DEMI_CAISSE, DEMI_CAISSE), Vector2(DEMI_CAISSE, DEMI_CAISSE) * 2.0)):
			return false
	return MONDE.encloses(boite)

func _evaluer_dalles(positions: Array) -> void:
	_pressees.clear()
	for dalle in _dalles:
		var centre: Vector2 = dalle["p"]
		var pesee := false
		for p in positions:
			if centre.distance_to(p) <= PORTEE_DALLE:
				pesee = true
				break
		if not pesee:
			for caisse in _caisses:
				if centre.distance_to(caisse["p"]) <= PORTEE_DALLE:
					pesee = true
					break
		if pesee:
			_pressees[int(dalle["id"])] = true

	for porte in _portes:
		var toutes := true
		for id in porte["dalles"]:
			if not _pressees.has(int(id)):
				toutes = false
				break
		if toutes:
			porte["ouverte"] = true
		elif not porte["verrou"]:
			porte["ouverte"] = false

func _evaluer_sortie(positions: Array) -> void:
	if positions.is_empty():
		return
	for p in positions:
		if not SORTIE.has_point(p):
			return
	_chambres_faites += 1
	if _chambre >= 2:
		_score_equipe = _calculer_score()
		for cle in joueurs:
			joueurs[cle]["score"] = _score_equipe
			canal.envoyer("score", {"j": cle, "s": _score_equipe})
		terminer("Les trois chambres, à %d secondes de la fin." % int(duree_manche() - temps))
	else:
		canal.envoyer("chambre", {"c": _chambre + 1})
		_charger_chambre(_chambre + 1)
		_annoncer_progression()

func _annoncer_progression() -> void:
	var partiel := _chambres_faites * 300
	for cle in joueurs:
		joueurs[cle]["score"] = partiel
		canal.envoyer("score", {"j": cle, "s": partiel})

## Trois cents points par chambre, plus ce qui reste au chrono. Le temps pèse
## assez pour récompenser une équipe qui parle, pas assez pour transformer
## l'énigme en course.
func _calculer_score() -> int:
	return _chambres_faites * 300 + int(max(0.0, duree_manche() - temps) * 4.0)

# ------------------------------------------------------- réception

func recevoir(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"p":
			var cle := String(charge.get("cle", ""))
			if cle == "" or cle == Session.id:
				return
			var cible := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			if not _autres.has(cle):
				_autres[cle] = {"p": cible, "cible": cible}
			_autres[cle]["cible"] = cible
		"chambre":
			if not est_hote():
				_charger_chambre(int(charge.get("c", 0)))
		"e":
			if est_hote():
				return
			_appliquer_etat(charge)

func _appliquer_etat(charge: Dictionary) -> void:
	if int(charge.get("c", _chambre)) != _chambre:
		return
	var caisses = charge.get("b", [])
	if typeof(caisses) == TYPE_ARRAY:
		for entree in caisses:
			if typeof(entree) != TYPE_ARRAY or (entree as Array).size() < 3:
				continue
			for c in _caisses:
				if int(c["id"]) == int(entree[0]):
					c["cible"] = Vector2(float(entree[1]), float(entree[2]))
					break
	var ouvertes = charge.get("d", [])
	for porte in _portes:
		porte["ouverte"] = typeof(ouvertes) == TYPE_ARRAY and (ouvertes as Array).has(int(porte["id"]))
	_pressees.clear()
	var pressees = charge.get("z", [])
	if typeof(pressees) == TYPE_ARRAY:
		for id in pressees:
			_pressees[int(id)] = true

# ------------------------------------------------------- rendu

func dessiner_scene() -> void:
	draw_rect(MONDE, Color("#111110"), true)
	var pas := 64
	var x := 0
	while x <= int(MONDE.size.x):
		draw_line(Vector2(x, 0), Vector2(x, MONDE.size.y), Color(1, 1, 1, 0.03), 1.0)
		x += pas
	var y := 0
	while y <= int(MONDE.size.y):
		draw_line(Vector2(0, y), Vector2(MONDE.size.x, y), Color(1, 1, 1, 0.03), 1.0)
		y += pas

	# La sortie : hachurée tant que l'équipe n'est pas au complet dedans.
	draw_rect(SORTIE, Color(Palette.BON, 0.10), true)
	draw_rect(SORTIE, Palette.BON, false, 2.0)
	var police := Palette.police()
	draw_string(police, SORTIE.position + Vector2(24, -14), "SORTIE — tous ensemble",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.BON)

	for mur in _murs():
		draw_rect(mur, Palette.SURFACE, true)
		draw_rect(mur, Color(1, 1, 1, 0.10), false, 1.0)

	for porte in _portes:
		var rect := _rect_porte()
		if porte["ouverte"]:
			draw_rect(rect, Color(Palette.BON, 0.12), true)
			draw_rect(rect, Color(Palette.BON, 0.55), false, 2.0)
		else:
			draw_rect(rect, Palette.SERIEUX.darkened(0.45), true)
			draw_rect(rect, Palette.SERIEUX, false, 2.0)
			for i in 5:
				var yy := rect.position.y + 24 + i * 52
				draw_line(Vector2(rect.position.x + 4, yy), Vector2(rect.end.x - 4, yy), Color(Palette.SERIEUX, 0.7), 2.0)

	for dalle in _dalles:
		var centre: Vector2 = dalle["p"]
		var active := _pressees.has(int(dalle["id"]))
		var couleur := Palette.BON if active else Palette.AVERTISSEMENT
		draw_circle(centre, PORTEE_DALLE, Color(couleur, 0.10 if not active else 0.22))
		draw_arc(centre, PORTEE_DALLE, 0, TAU, 32, Color(couleur, 0.9), 3.0, true)
		draw_circle(centre, 8.0, couleur)

	for caisse in _caisses:
		var p: Vector2 = caisse["p"]
		draw_rect(Rect2(p - Vector2(DEMI_CAISSE, DEMI_CAISSE) + Vector2(0, 5), Vector2(DEMI_CAISSE, DEMI_CAISSE) * 2.0), Color(0, 0, 0, 0.35), true)
		draw_rect(Rect2(p - Vector2(DEMI_CAISSE, DEMI_CAISSE), Vector2(DEMI_CAISSE, DEMI_CAISSE) * 2.0), Palette.ENCRE_FAIBLE.darkened(0.25), true)
		draw_rect(Rect2(p - Vector2(DEMI_CAISSE, DEMI_CAISSE), Vector2(DEMI_CAISSE, DEMI_CAISSE) * 2.0), Palette.ENCRE_DOUCE, false, 2.0)
		draw_line(p - Vector2(DEMI_CAISSE, DEMI_CAISSE), p + Vector2(DEMI_CAISSE, DEMI_CAISSE), Color(1, 1, 1, 0.18), 2.0)

	for cle in _autres:
		_dessiner_marcheur(_autres[cle]["p"],
			Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))),
			String(joueurs.get(cle, {}).get("pseudo", "")))
	_dessiner_marcheur(_position, Palette.couleur_joueur(ma_place()), Session.pseudo)

	if _message != "":
		draw_string(police, Vector2(40, MONDE.size.y + 46), _message.replace("\n", "   —   "),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.ENCRE_DOUCE)

func _dessiner_marcheur(position: Vector2, couleur: Color, pseudo: String) -> void:
	draw_circle(position + Vector2(0, 6), RAYON * 0.9, Color(0, 0, 0, 0.35))
	draw_circle(position, RAYON, couleur)
	draw_arc(position, RAYON + 3.0, 0, TAU, 28, Palette.FOND, 3.0, true)
	if pseudo != "":
		var police := Palette.police()
		var largeur := police.get_string_size(pseudo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(police, position + Vector2(-largeur * 0.5, -RAYON - 10), pseudo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.ENCRE_DOUCE)
