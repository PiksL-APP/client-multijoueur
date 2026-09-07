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

const TUILE := 64.0                          ## pas de la trame, en pixels de jeu
const PAVE := "res://modeles/ville/pavement.glb"
const MUR := "res://modeles/creatures/wall-high.glb"
const TEINTE_SOL := Color(0.55, 0.60, 0.72)
const TEINTE_MUR := Color(0.62, 0.66, 0.78)

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
var _camera: Camera3D
var _corps: Node3D
var _decor_chambre: Node3D
var _noeuds_dalles: Dictionary = {}
var _noeuds_caisses: Dictionary = {}
var _noeud_porte: Node3D

func duree_manche() -> float:
	return DUREE

func etat_joueur() -> String:
	return _message

func aide() -> String:
	return "Z Q S D ou les flèches · marcher dans une caisse la pousse · une dalle ne compte que si quelque chose pèse dessus · la sortie n'accepte l'équipe qu'au complet."

const INCLINAISON := 55.0
const DISTANCE := 124.0

func preparer() -> void:
	Tactile.mode = Tactile.MARCHE
	poser_ambiance(true, 1.0)
	_camera = Decor.camera(INCLINAISON, DISTANCE, 50.0)
	_camera.position = Decor.viser(_camera, MONDE.get_center() + Vector2(0, 40), INCLINAISON, DISTANCE)
	monde().add_child(_camera)
	_camera.make_current()

	_corps = _batir_marcheur(Palette.couleur_joueur(ma_place()), Session.pseudo)
	monde().add_child(_corps)

	_charger_chambre(0)

func _batir_marcheur(couleur: Color, pseudo: String) -> Node3D:
	var racine := Node3D.new()
	var halo := Decor.anneau(RAYON * Decor.ECHELLE * 1.5, 0.18, couleur, 0.95)
	halo.rotation_degrees = Vector3(90, 0, 0)
	halo.position = Vector3(0, 0.06, 0)
	racine.add_child(halo)

	var corps := Decor.personnage(couleur, 3.2)
	corps.name = "Silhouette"
	racine.add_child(corps)

	if pseudo != "":
		var nom := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 30)
		nom.name = "Nom"
		nom.position = Vector3(0, 5.2, 0)
		racine.add_child(nom)
	return racine

## La démarche suit le déplacement réel, pas la touche : c'est ce qui fait
## qu'un joueur bloqué contre un mur cesse de mouliner des jambes.
func _animer(porteur: Node3D, pas: Vector2, delta: float) -> void:
	var silhouette := porteur.get_node_or_null("Silhouette") as Node3D
	if silhouette == null:
		return
	if pas.length() > 6.0:
		silhouette.rotation.y = lerp_angle(silhouette.rotation.y,
			atan2(pas.x, pas.y), clamp(delta * 12.0, 0, 1))
		Decor.demarche(silhouette, "walk")
	else:
		Decor.demarche(silhouette, "idle")

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

func _murs() -> Array[Rect2]:
	var liste: Array[Rect2] = [
		Rect2(0, 0, MONDE.size.x, 32),
		Rect2(0, MONDE.size.y - 32, MONDE.size.x, 32),
		Rect2(0, 0, 32, MONDE.size.y),
		Rect2(MONDE.size.x - 32, 0, 32, MONDE.size.y),
		Rect2(832, 32, 32, 288),
		Rect2(832, 576, 32, 288),
	]
	return liste

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
	_message = "Chambre %d — %s   ·   %s" % [indice + 1, String(plan["nom"]), String(plan["consigne"])]
	_batir_chambre()
	# Les joueurs repartent en colonne à gauche : personne ne se réveille de
	# l'autre côté d'une porte qu'il n'a pas ouverte.
	_position = Vector2(120, 340 + ma_place() * 72)
	for cle in _autres:
		_autres[cle]["p"] = Vector2(120, 340)
		_autres[cle]["cible"] = _autres[cle]["p"]

## Le décor d'une chambre est reconstruit d'un bloc. Recycler les maillages
## d'une chambre à l'autre économiserait quelques allocations et coûterait un
## suivi d'état à chaque élément — pour trois chambres, ça ne vaut pas le
## risque d'en laisser un dans l'état de la précédente.
func _batir_chambre() -> void:
	if _decor_chambre:
		_decor_chambre.queue_free()
	_noeuds_dalles.clear()
	_noeuds_caisses.clear()
	_decor_chambre = Node3D.new()
	monde().add_child(_decor_chambre)

	# Un dallage plutôt qu'un plan nu : la chambre a une trame, donc une
	# échelle, et on voit qu'on avance. Le plan uni ne le donnait pas.
	var dalles: Array = []
	var cote := TUILE * Decor.ECHELLE
	var colonnes := int(MONDE.size.x / TUILE)
	var rangees := int(MONDE.size.y / TUILE)
	for c in colonnes:
		for r in rangees:
			var centre := Vector2(c + 0.5, r + 0.5) * TUILE
			dalles.append(Transform3D(Basis().scaled(Vector3.ONE * cote), Decor.vers3d(centre)))
	_decor_chambre.add_child(Decor.nappe(PAVE, dalles, false, TEINTE_SOL))

	# Les murs sont pavés du même kit : un parallélépipède gris n'a ni
	# épaisseur lisible ni ombre franche, et la chambre paraissait plate.
	var pans: Array = []
	for mur: Rect2 in _murs():
		var longueur: float = max(mur.size.x, mur.size.y)
		var horizontal: bool = mur.size.x >= mur.size.y
		var nombre: int = max(1, int(round(longueur / TUILE)))
		for i in nombre:
			var glissement := (float(i) + 0.5) / float(nombre)
			var centre: Vector2 = mur.position + (Vector2(mur.size.x, 0) if horizontal else Vector2(0, mur.size.y)) * glissement
			centre += Vector2(0, mur.size.y * 0.5) if horizontal else Vector2(mur.size.x * 0.5, 0)
			var base := Basis(Vector3.UP, 0.0 if horizontal else PI * 0.5)
			# Le pan fait 1,5 de large pour 1,7 de haut : on l'étire sur le
			# pas de la trame et on garde la hauteur du kit.
			base = base.scaled(Vector3(cote / 1.5, 3.4, cote / 1.5))
			pans.append(Transform3D(base, Decor.vers3d(centre)))
	_decor_chambre.add_child(Decor.nappe(MUR, pans, true, TEINTE_MUR))

	var rect := _rect_porte()
	_noeud_porte = Decor.boite(
		Vector3(rect.size.x * Decor.ECHELLE, 5.6, rect.size.y * Decor.ECHELLE),
		Palette.SERIEUX.darkened(0.2))
	_noeud_porte.material_override = Decor.matiere_lumineuse(Palette.SERIEUX, 0.75)
	_noeud_porte.position = Decor.vers3d(rect.get_center(), 2.8)
	_decor_chambre.add_child(_noeud_porte)

	for dalle in _dalles:
		var support := Node3D.new()
		support.position = Decor.vers3d(dalle["p"])
		var disque := Decor.cylindre(PORTEE_DALLE * Decor.ECHELLE, 0.35, Palette.AVERTISSEMENT.darkened(0.5), false)
		disque.position = Vector3(0, 0.18, 0)
		disque.name = "Disque"
		support.add_child(disque)
		var cercle := Decor.anneau(PORTEE_DALLE * Decor.ECHELLE, 0.22, Palette.AVERTISSEMENT, 0.9)
		cercle.rotation_degrees = Vector3(90, 0, 0)
		cercle.position = Vector3(0, 0.4, 0)
		cercle.name = "Cercle"
		support.add_child(cercle)
		_decor_chambre.add_child(support)
		_noeuds_dalles[int(dalle["id"])] = support

	for caisse in _caisses:
		var cote_caisse := DEMI_CAISSE * 2.0 * Decor.ECHELLE
		var boite := Decor.boite(Vector3(cote_caisse, cote_caisse, cote_caisse), Color("#8a6a41"))
		boite.position = Decor.vers3d(caisse["p"], cote_caisse * 0.5)
		_decor_chambre.add_child(boite)
		var cerclage := Decor.boite(Vector3(cote_caisse * 1.06, cote_caisse * 0.16, cote_caisse * 1.06), Color("#c9a266"))
		cerclage.position = Vector3(0, 0, 0)
		boite.add_child(cerclage)
		_noeuds_caisses[int(caisse["id"])] = boite

	var sortie := Decor.boite(
		Vector3(SORTIE.size.x * Decor.ECHELLE, 0.2, SORTIE.size.y * Decor.ECHELLE), Palette.BON)
	sortie.material_override = Decor.matiere_lumineuse(Palette.BON, 0.6, 0.4)
	sortie.position = Decor.vers3d(SORTIE.get_center(), 0.12)
	_decor_chambre.add_child(sortie)
	var mention := Decor.etiquette("SORTIE — tous ensemble", Palette.BON, 52)
	mention.position = Decor.vers3d(SORTIE.get_center(), 5.5)
	_decor_chambre.add_child(mention)

# ------------------------------------------------------- simulation locale

func simuler_local(delta: float) -> void:
	var direction := Commandes.direction()
	if direction != Vector2.ZERO:
		_position += direction * VITESSE * delta
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
		terminer("Les trois chambres, à %d secondes de la fin." % int(duree_reelle() - temps))
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
	return _chambres_faites * 300 + int(max(0.0, duree_reelle() - temps) * 4.0)

# ------------------------------------------------------- réception

func recevoir(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"p":
			var cle := String(charge.get("cle", ""))
			if cle == "" or cle == Session.cle:
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

func rafraichir_scene(delta: float) -> void:
	var pas_local := _position - Vector2(_corps.position.x, _corps.position.z) / Decor.ECHELLE
	_corps.position = Decor.vers3d(_position)
	_animer(_corps, pas_local / max(delta, 0.001) * 0.016, delta)
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var noeud = a.get("noeud")
		if noeud == null:
			noeud = _batir_marcheur(
				Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))),
				String(joueurs.get(cle, {}).get("pseudo", "")))
			monde().add_child(noeud)
			a["noeud"] = noeud
		var avant := Vector2((noeud as Node3D).position.x, (noeud as Node3D).position.z) / Decor.ECHELLE
		(noeud as Node3D).position = Decor.vers3d(a["p"])
		_animer(noeud as Node3D, ((a["p"] as Vector2) - avant) / max(delta, 0.001) * 0.016, delta)

	for caisse in _caisses:
		var boite = _noeuds_caisses.get(int(caisse["id"]))
		if boite:
			var cote := DEMI_CAISSE * 2.0 * Decor.ECHELLE
			(boite as Node3D).position = Decor.vers3d(caisse["p"], cote * 0.5)

	# Une dalle enfoncée s'enfonce vraiment, et s'allume : la couleur seule ne
	# suffirait pas à distinguer les deux états d'un coup d'œil en perspective.
	for dalle in _dalles:
		var id := int(dalle["id"])
		var support = _noeuds_dalles.get(id)
		if support == null:
			continue
		var active := _pressees.has(id)
		var disque := (support as Node3D).get_node_or_null("Disque") as MeshInstance3D
		var cercle := (support as Node3D).get_node_or_null("Cercle") as MeshInstance3D
		if disque:
			disque.position.y = lerp(disque.position.y, 0.06 if active else 0.18, clamp(delta * 10.0, 0, 1))
			disque.material_override = Decor.matiere(
				(Palette.BON if active else Palette.AVERTISSEMENT).darkened(0.45))
		if cercle:
			cercle.material_override = Decor.matiere_lumineuse(
				Palette.BON if active else Palette.AVERTISSEMENT, 1.25 if active else 0.7)

	if _noeud_porte:
		var ouverte := false
		for porte in _portes:
			if porte["ouverte"]:
				ouverte = true
		var hauteur: float = 2.8 if not ouverte else -3.2
		_noeud_porte.position.y = lerp(_noeud_porte.position.y, hauteur, clamp(delta * 4.0, 0, 1))
		_noeud_porte.visible = _noeud_porte.position.y > -3.0
