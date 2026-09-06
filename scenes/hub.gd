extends Ecran
## Le hub : un monde partagé où l'on se croise, et des portails qui lancent
## chacun un jeu.
##
## Choix de synchronisation : l'identité passe par la présence (rare, fiable),
## la position par la diffusion (fréquente, jetable). Faire passer la position
## par la présence marcherait aussi, mais chaque pas coûterait un message à
## tout le monde ET une écriture d'état côté serveur.

const CANAL := "mj-hub"
const MONDE := Rect2(0, 0, 2600, 1600)
const VITESSE := 340.0
const CADENCE_ENVOI := 1.0 / 8.0
const RAPPEL := 1.5           ## on redit sa position même à l'arrêt
const RAYON := 18.0

const PORTAILS := [
	{
		"jeu": "carnage",
		"titre": "CARNAGE",
		"sous_titre": "Voitures contre monstres",
		"detail": "2 à 4 joueurs · 2 minutes · écraser rapporte",
		"position": Vector2(700, 500),
		"couleur": Palette.CRITIQUE,
		"ouvert": true,
	},
	{
		"jeu": "enigme",
		"titre": "ÉNIGME",
		"sous_titre": "Puzzle coopératif",
		"detail": "2 à 4 joueurs · trois chambres · personne ne finit seul",
		"position": Vector2(1900, 500),
		"couleur": Palette.SERIE,
		"ouvert": true,
	},
	{
		"jeu": "arene",
		"titre": "ARÈNE",
		"sous_titre": "À venir",
		"detail": "Le portail est éteint.",
		"position": Vector2(700, 1150),
		"couleur": Palette.ENCRE_FAIBLE,
		"ouvert": false,
	},
	{
		"jeu": "atelier",
		"titre": "ATELIER",
		"sous_titre": "À venir",
		"detail": "Le portail est éteint.",
		"position": Vector2(1900, 1150),
		"couleur": Palette.ENCRE_FAIBLE,
		"ouvert": false,
	},
]

var _canal: CanalTempsReel
var _camera: Camera2D
var _position := Vector2(1300, 820)
var _autres: Dictionary = {}       # cle -> {cible, affichee, pseudo, place}
var _depuis_envoi := 0.0
var _depuis_rappel := 0.0
var _t := 0.0
var _portail_proche: int = -1

var _hud_titre: Label
var _hud_detail: Label
var _hud_invite: Label
var _hud_presents: Label
var _hud_etat: HBoxContainer
var _hud_classement: Label
var _classements: Dictionary = {}

func demarrer() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.9, 0.9)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	add_child(_camera)
	_camera.make_current()

	_construire_hud()

	_canal = Reseau.rejoindre(CANAL, {"pseudo": Session.pseudo})
	_canal.diffusion.connect(_sur_diffusion)
	_canal.presences_changees.connect(_sur_presences)
	if _canal.est_rejoint:
		_canal.suivre({"pseudo": Session.pseudo})

	Scores.classement_recu.connect(_sur_classement)
	Scores.demander_classement("carnage", 3)
	Scores.demander_classement("enigme", 3)

func _exit_tree() -> void:
	if _canal:
		_canal.quitter()

# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	_t += delta
	var direction := _lire_direction()
	if direction != Vector2.ZERO:
		_position += direction * VITESSE * delta
		_position.x = clamp(_position.x, MONDE.position.x + RAYON, MONDE.end.x - RAYON)
		_position.y = clamp(_position.y, MONDE.position.y + RAYON, MONDE.end.y - RAYON)
	_camera.position = _position

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["affichee"] = (a["affichee"] as Vector2).lerp(a["cible"], clamp(delta * 12.0, 0, 1))

	_depuis_envoi += delta
	_depuis_rappel += delta
	if _depuis_envoi >= CADENCE_ENVOI and (direction != Vector2.ZERO or _depuis_rappel >= RAPPEL):
		_depuis_envoi = 0.0
		_depuis_rappel = 0.0
		_canal.envoyer("p", {"x": int(_position.x), "y": int(_position.y)})

	_chercher_portail()
	queue_redraw()

func _lire_direction() -> Vector2:
	# Codes physiques : sur un clavier AZERTY, W Q S D tombent sur Z Q S D.
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1
	return d.normalized()

func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventKey and evenement.pressed and not evenement.echo:
		if evenement.keycode == KEY_E and _portail_proche >= 0:
			var portail: Dictionary = PORTAILS[_portail_proche]
			if portail["ouvert"]:
				demande_ecran.emit("salon", {"jeu": portail["jeu"], "titre": portail["titre"]})

func _chercher_portail() -> void:
	_portail_proche = -1
	for i in PORTAILS.size():
		if _position.distance_to(PORTAILS[i]["position"]) < 130.0:
			_portail_proche = i
			break
	_rafraichir_hud()

# ---------------------------------------------------------------- réseau

func _sur_diffusion(evenement: String, charge: Dictionary) -> void:
	if evenement != "p":
		return
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.id:
		return
	var cible := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
	if _autres.has(cle):
		_autres[cle]["cible"] = cible
	else:
		_autres[cle] = {"cible": cible, "affichee": cible, "pseudo": "…", "place": 0}
		_sur_presences(_canal.presences)

func _sur_presences(presences: Dictionary) -> void:
	var cles := _canal.cles_triees()
	for cle in _autres.keys():
		if not presences.has(cle):
			_autres.erase(cle)
	for cle in presences:
		if cle == Session.id:
			continue
		var meta: Dictionary = presences[cle]
		if not _autres.has(cle):
			_autres[cle] = {"cible": _position, "affichee": _position, "pseudo": "", "place": 0}
		_autres[cle]["pseudo"] = String(meta.get("pseudo", "?"))
		_autres[cle]["place"] = cles.find(cle)
	_rafraichir_hud()

func _sur_classement(jeu: String, lignes: Array) -> void:
	_classements[jeu] = lignes
	_rafraichir_hud()

# ---------------------------------------------------------------- rendu

func _draw() -> void:
	_dessiner_sol()
	for i in PORTAILS.size():
		_dessiner_portail(PORTAILS[i], i == _portail_proche)
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		_dessiner_avatar(a["affichee"], Palette.couleur_joueur(int(a["place"]) + 1), String(a["pseudo"]), false)
	_dessiner_avatar(_position, Palette.couleur_joueur(0), Session.pseudo, true)

func _dessiner_sol() -> void:
	draw_rect(MONDE, Palette.FOND, true)
	# Trame de points : le dotwork de la maison, et un repère de vitesse quand
	# on se déplace — sans lui, un fond uni donne l'impression de ne pas avancer.
	var pas := 64
	var x := int(MONDE.position.x)
	while x <= int(MONDE.end.x):
		var y := int(MONDE.position.y)
		while y <= int(MONDE.end.y):
			draw_circle(Vector2(x, y), 1.5, Color(1, 1, 1, 0.055))
			y += pas
		x += pas
	draw_rect(MONDE, Color(1, 1, 1, 0.10), false, 2.0)

func _dessiner_portail(portail: Dictionary, proche: bool) -> void:
	var centre: Vector2 = portail["position"]
	var couleur: Color = portail["couleur"]
	var ouvert: bool = portail["ouvert"]
	var intensite := 1.0 if ouvert else 0.35

	draw_circle(centre, 108.0, Color(couleur, 0.06 * intensite))
	for i in 3:
		var rayon := 58.0 + i * 20.0
		var vitesse := (0.5 + i * 0.3) * (1.0 if ouvert else 0.15)
		var debut := _t * vitesse + i * 1.7
		draw_arc(centre, rayon, debut, debut + TAU * 0.66, 40,
			Color(couleur, (0.75 - i * 0.16) * intensite), 3.0, true)
	draw_circle(centre, 40.0, Color(couleur, 0.16 * intensite))

	if proche and ouvert:
		draw_arc(centre, 126.0, 0, TAU, 64, Color(Palette.ENCRE, 0.5), 2.0, true)

	var police := Palette.police()
	var titre: String = portail["titre"]
	var largeur := police.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(police, centre + Vector2(-largeur * 0.5, 152), titre,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Palette.ENCRE, intensite))
	var sous: String = portail["sous_titre"]
	var largeur2 := police.get_string_size(sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(police, centre + Vector2(-largeur2 * 0.5, 174), sous,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Palette.ENCRE_FAIBLE, intensite))

func _dessiner_avatar(position: Vector2, couleur: Color, pseudo: String, moi: bool) -> void:
	draw_circle(position + Vector2(0, 6), RAYON * 0.9, Color(0, 0, 0, 0.35))
	draw_circle(position, RAYON, couleur)
	draw_arc(position, RAYON + 3.0, 0, TAU, 32, Color(Palette.FOND, 0.9), 3.0, true)
	if moi:
		draw_arc(position, RAYON + 7.0, _t * 2.0, _t * 2.0 + TAU * 0.7, 24, Color(couleur, 0.6), 2.0, true)
	var police := Palette.police()
	var largeur := police.get_string_size(pseudo, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(police, position + Vector2(-largeur * 0.5, -RAYON - 10), pseudo,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.ENCRE_DOUCE)

# ---------------------------------------------------------------- interface

func _construire_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)

	var haut := HBoxContainer.new()
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 20
	haut.offset_right = -20
	haut.offset_top = 16
	haut.add_theme_constant_override("separation", 18)
	couche.add_child(haut)

	_hud_presents = UI.texte("", 14, Palette.ENCRE_DOUCE)
	haut.add_child(_hud_presents)
	var pousse := Control.new()
	pousse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(pousse)
	_hud_etat = UI.etat_reseau()
	haut.add_child(_hud_etat)

	var bas := VBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bas.offset_left = 20
	bas.offset_top = -140
	bas.offset_bottom = -20
	bas.add_theme_constant_override("separation", 4)
	couche.add_child(bas)
	_hud_titre = UI.titre("", 22)
	_hud_detail = UI.texte("", 14, Palette.ENCRE_FAIBLE)
	_hud_classement = UI.texte("", 13, Palette.ENCRE_FAIBLE)
	_hud_invite = UI.texte("", 15, Palette.SERIE)
	bas.add_child(_hud_titre)
	bas.add_child(_hud_detail)
	bas.add_child(_hud_classement)
	bas.add_child(_hud_invite)

func _rafraichir_hud() -> void:
	if _hud_etat == null:
		return
	UI.rafraichir_etat_reseau(_hud_etat)
	var noms: Array = [Session.pseudo]
	for cle in _autres:
		noms.append(String(_autres[cle]["pseudo"]))
	_hud_presents.text = "Dans le hub (%d) : %s" % [noms.size(), ", ".join(noms)]

	if _portail_proche < 0:
		_hud_titre.text = "Hub"
		_hud_detail.text = "Z Q S D ou les flèches pour marcher. Approchez un portail."
		_hud_classement.text = ""
		_hud_invite.text = ""
		return

	var portail: Dictionary = PORTAILS[_portail_proche]
	_hud_titre.text = String(portail["titre"]) + " — " + String(portail["sous_titre"])
	_hud_detail.text = String(portail["detail"])
	_hud_invite.text = "E — franchir le portail" if portail["ouvert"] else "Portail éteint"
	_hud_classement.text = _resumer_classement(String(portail["jeu"]))

## Utilisé par le banc d'essai : combien de joueurs ce client voit-il ?
func nombre_de_joueurs() -> int:
	return _autres.size() + 1

func _resumer_classement(jeu: String) -> String:
	var lignes = _classements.get(jeu, null)
	if lignes == null:
		return ""
	if (lignes as Array).is_empty():
		return "Aucun score déposé pour l'instant."
	var morceaux: Array = []
	var rang := 1
	for ligne in lignes:
		morceaux.append("%d. %s %d" % [rang, String(ligne.get("pseudo", "?")), int(ligne.get("score", 0))])
		rang += 1
	return "Meilleurs scores — " + "   ".join(morceaux)
