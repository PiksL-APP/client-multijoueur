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
const INCLINAISON := 50.0
const DISTANCE := 66.0

const PORTAILS := [
	{
		"jeu": "carnage", "titre": "CARNAGE", "sous_titre": "Voitures contre monstres",
		"detail": "2 à 4 joueurs · 2 minutes · écraser rapporte",
		"position": Vector2(700, 520), "couleur": Palette.CRITIQUE, "ouvert": true,
	},
	{
		"jeu": "enigme", "titre": "ÉNIGME", "sous_titre": "Puzzle coopératif",
		"detail": "2 à 4 joueurs · trois chambres · personne ne finit seul",
		"position": Vector2(1900, 520), "couleur": Palette.SERIE, "ouvert": true,
	},
	{
		"jeu": "arene", "titre": "ARÈNE", "sous_titre": "À venir",
		"detail": "Le portail est éteint.",
		"position": Vector2(700, 1120), "couleur": Palette.ENCRE_FAIBLE, "ouvert": false,
	},
	{
		"jeu": "atelier", "titre": "ATELIER", "sous_titre": "À venir",
		"detail": "Le portail est éteint.",
		"position": Vector2(1900, 1120), "couleur": Palette.ENCRE_FAIBLE, "ouvert": false,
	},
]

var _canal: CanalTempsReel
var _camera: Camera3D
var _position := Vector2(1300, 830)
var _autres: Dictionary = {}       # cle -> {cible, affichee, pseudo, place, noeud}
var _corps: Node3D
var _depuis_envoi := 0.0
var _depuis_rappel := 0.0
var _t := 0.0
var _portail_proche: int = -1
var _anneaux: Array = []           # [{support, base}]

var _hud_titre: Label
var _hud_detail: Label
var _hud_invite: Label
var _hud_presents: Label
var _hud_etat: HBoxContainer
var _hud_classement: Label
var _classements: Dictionary = {}

func demarrer() -> void:
	_batir_monde()
	_construire_hud()

	_canal = Reseau.rejoindre(CANAL, {"pseudo": Session.pseudo, "id": Session.id})
	_canal.diffusion.connect(_sur_diffusion)
	_canal.presences_changees.connect(_sur_presences)
	if _canal.est_rejoint:
		_canal.suivre({"pseudo": Session.pseudo, "id": Session.id})

	Scores.classement_recu.connect(_sur_classement)
	Scores.demander_classement("carnage", 3)
	Scores.demander_classement("enigme", 3)

func _exit_tree() -> void:
	if _canal:
		_canal.quitter()

# ---------------------------------------------------------------- décor

func _batir_monde() -> void:
	poser_ambiance()

	var sol := Decor.sol(MONDE.size, 100.0)
	sol.position = Decor.vers3d(MONDE.get_center())
	monde().add_child(sol)

	# Murs d'enceinte : ils cadrent le terrain et, surtout, portent une ombre
	# qui donne son épaisseur au sol.
	var e := 20.0
	var m := MONDE.size
	_mur(Vector2(m.x * 0.5, -e * 0.5), Vector2(m.x + e * 2.0, e))
	_mur(Vector2(m.x * 0.5, m.y + e * 0.5), Vector2(m.x + e * 2.0, e))
	_mur(Vector2(-e * 0.5, m.y * 0.5), Vector2(e, m.y))
	_mur(Vector2(m.x + e * 0.5, m.y * 0.5), Vector2(e, m.y))

	for portail in PORTAILS:
		_batir_portail(portail)

	_corps = _batir_avatar(Palette.couleur_joueur(0), Session.pseudo)
	monde().add_child(_corps)

	_camera = Decor.camera(INCLINAISON, DISTANCE, 50.0)
	monde().add_child(_camera)
	_camera.make_current()

func _mur(centre: Vector2, taille: Vector2) -> void:
	var hauteur := 5.0
	var boite := Decor.boite(
		Vector3(taille.x * Decor.ECHELLE, hauteur, taille.y * Decor.ECHELLE),
		Palette.SURFACE.lightened(0.06))
	boite.position = Decor.vers3d(centre, hauteur * 0.5)
	monde().add_child(boite)

func _batir_portail(portail: Dictionary) -> void:
	var couleur: Color = portail["couleur"]
	var ouvert: bool = portail["ouvert"]
	var force := 1.15 if ouvert else 0.18

	var support := Node3D.new()
	support.position = Decor.vers3d(portail["position"])
	monde().add_child(support)

	# Socle au sol : c'est lui qui dit où se placer pour entrer.
	var socle := Decor.cylindre(11.5, 0.5, couleur.darkened(0.55), false)
	socle.position = Vector3(0, 0.26, 0)
	support.add_child(socle)
	var liseré := Decor.anneau(11.5, 0.4, couleur, force * 0.6)
	liseré.rotation_degrees = Vector3(90, 0, 0)
	liseré.position = Vector3(0, 0.4, 0)
	support.add_child(liseré)

	# Les anneaux se redressent face à la caméra et tournent : un portail
	## posé à plat se confondrait avec une simple marque au sol.
	for i in 3:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 6.0 + i * 0.8, 0)
		pivot.rotation_degrees = Vector3(90.0 - INCLINAISON, 0, 0)
		var a := Decor.anneau(5.4 + i * 2.2, 0.32, couleur, force - i * 0.4)
		pivot.add_child(a)
		support.add_child(pivot)
		_anneaux.append({"pivot": pivot, "rang": i, "ouvert": ouvert})

	var noyau := Decor.sphere(3.4, couleur)
	noyau.material_override = Decor.matiere_lumineuse(couleur, force * 0.5, 0.55)
	noyau.position = Vector3(0, 6.4, 0)
	support.add_child(noyau)

	var titre := Decor.etiquette(String(portail["titre"]), Color(Palette.ENCRE, 1.0 if ouvert else 0.4), 72)
	titre.position = Vector3(0, 17.0, 0)
	support.add_child(titre)
	var sous := Decor.etiquette(String(portail["sous_titre"]), Color(Palette.ENCRE_FAIBLE, 1.0 if ouvert else 0.45), 34)
	sous.position = Vector3(0, 14.2, 0)
	support.add_child(sous)

func _batir_avatar(couleur: Color, pseudo: String) -> Node3D:
	var racine := Node3D.new()
	var jambes := Decor.cylindre(RAYON * Decor.ECHELLE * 1.5, 2.4, couleur.darkened(0.35))
	jambes.position = Vector3(0, 1.2, 0)
	racine.add_child(jambes)
	var buste := Decor.cylindre(RAYON * Decor.ECHELLE * 1.3, 2.7, couleur)
	buste.position = Vector3(0, 3.8, 0)
	racine.add_child(buste)
	var tete := Decor.sphere(RAYON * Decor.ECHELLE * 1.1, couleur.lightened(0.25))
	tete.position = Vector3(0, 6.2, 0)
	racine.add_child(tete)
	var nom := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 34)
	nom.position = Vector3(0, 8.6, 0)
	nom.name = "Nom"
	racine.add_child(nom)
	return racine

# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	_t += delta
	var direction := Commandes.direction()
	if direction != Vector2.ZERO:
		_position += direction * VITESSE * delta
		_position.x = clamp(_position.x, MONDE.position.x + RAYON, MONDE.end.x - RAYON)
		_position.y = clamp(_position.y, MONDE.position.y + RAYON, MONDE.end.y - RAYON)

	_corps.position = Decor.vers3d(_position)
	# Un pas se voit : le corps se penche dans le sens de la marche et
	# rebondit légèrement. Sans ça, un cylindre qui glisse ne marche pas.
	if direction != Vector2.ZERO:
		_corps.rotation.y = atan2(-direction.x, -direction.y)
		_corps.position.y = abs(sin(_t * 11.0)) * 0.5
		_corps.rotation.x = deg_to_rad(6.0)
	else:
		_corps.rotation.x = lerp(_corps.rotation.x, 0.0, delta * 8.0)

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["affichee"] = (a["affichee"] as Vector2).lerp(a["cible"], clamp(delta * 12.0, 0, 1))
		var noeud: Node3D = a["noeud"]
		var avant: Vector2 = a["affichee"]
		noeud.position = Decor.vers3d(avant)

	for anneau in _anneaux:
		var pivot: Node3D = anneau["pivot"]
		var vitesse: float = (0.5 + int(anneau["rang"]) * 0.35) * (1.0 if anneau["ouvert"] else 0.12)
		pivot.rotation.z = _t * vitesse

	_placer_camera(delta)

	_depuis_envoi += delta
	_depuis_rappel += delta
	if _depuis_envoi >= CADENCE_ENVOI and (direction != Vector2.ZERO or _depuis_rappel >= RAPPEL):
		_depuis_envoi = 0.0
		_depuis_rappel = 0.0
		_canal.envoyer("p", {"x": int(_position.x), "y": int(_position.y)})

	_chercher_portail()

func _placer_camera(delta: float) -> void:
	var vise := Decor.viser(_camera, _position, INCLINAISON, DISTANCE)
	_camera.position = _camera.position.lerp(vise, clamp(delta * 6.0, 0, 1))

func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventKey and evenement.pressed and not evenement.echo:
		if evenement.keycode == KEY_E and _portail_proche >= 0:
			var portail: Dictionary = PORTAILS[_portail_proche]
			if portail["ouvert"]:
				demande_ecran.emit("salon", {"jeu": portail["jeu"], "titre": portail["titre"]})

func _chercher_portail() -> void:
	var avant := _portail_proche
	_portail_proche = -1
	for i in PORTAILS.size():
		if _position.distance_to(PORTAILS[i]["position"]) < 140.0:
			_portail_proche = i
			break
	if avant != _portail_proche:
		_rafraichir_hud()

# ---------------------------------------------------------------- réseau

func _sur_diffusion(evenement: String, charge: Dictionary) -> void:
	if evenement != "p":
		return
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.cle:
		return
	var cible := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
	if not _autres.has(cle):
		_ajouter_joueur(cle, "…", cible)
	_autres[cle]["cible"] = cible

func _ajouter_joueur(cle: String, pseudo: String, position: Vector2) -> void:
	var noeud := _batir_avatar(Palette.couleur_joueur(1), pseudo)
	noeud.position = Decor.vers3d(position)
	monde().add_child(noeud)
	_autres[cle] = {"cible": position, "affichee": position, "pseudo": pseudo, "place": 1, "noeud": noeud}

func _sur_presences(presences: Dictionary) -> void:
	var cles := _canal.cles_triees()
	for cle in _autres.keys():
		if not presences.has(cle):
			(_autres[cle]["noeud"] as Node3D).queue_free()
			_autres.erase(cle)
	for cle in presences:
		if cle == Session.cle:
			continue
		var meta: Dictionary = presences[cle]
		if not _autres.has(cle):
			_ajouter_joueur(cle, String(meta.get("pseudo", "?")), _position)
		var joueur: Dictionary = _autres[cle]
		joueur["pseudo"] = String(meta.get("pseudo", "?"))
		joueur["place"] = max(1, cles.find(cle))
		var noeud: Node3D = joueur["noeud"]
		var nom := noeud.get_node_or_null("Nom") as Label3D
		if nom:
			nom.text = joueur["pseudo"]
	_rafraichir_hud()

func _sur_classement(jeu: String, lignes: Array) -> void:
	_classements[jeu] = lignes
	_rafraichir_hud()

# ---------------------------------------------------------------- interface

func _construire_hud() -> void:
	var couche := interface()

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
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = 20
	bas.offset_right = -20
	bas.offset_top = -136
	bas.offset_bottom = -18
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
	_rafraichir_hud()

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
