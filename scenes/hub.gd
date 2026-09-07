extends Ecran
## Le hub : un village en pixel art, vu de dessus, où l'on entre dans les
## maisons.
##
## Pourquoi le hub est en deux dimensions alors que les jeux sont en 3D : le
## pack de décor est dessiné en vue de dessus, murs et toits compris. Dressé
## en panneaux dans une scène en perspective, il se tordrait. Le contraste
## assumé — un village pixel, des jeux en volume — vaut mieux qu'un mélange
## qui trahirait les deux.
##
## Choix de synchronisation : l'identité et le LIEU passent par la présence
## (rares, fiables) ; la position par la diffusion (fréquente, jetable). On ne
## dessine que les joueurs qui sont dans la même pièce que soi.

const CANAL := "mj-hub"
const VITESSE := 108.0
const RAYON := 7.0                 ## demi-largeur des pieds, pour les collisions
const ZOOM := 2.0
const CADENCE_ENVOI := 1.0 / 8.0
const RAPPEL := 1.5
const IMAGES := "res://modeles/village/"

## Les lieux du hub. Le village est dehors ; les trois autres sont des
## intérieurs, chacun avec sa porte de sortie, son classement au mur, son
## habitant et — pour deux d'entre eux — le portail qui lance le jeu.
const LIEUX := {
	"village": {
		"nom": "Village", "fond": "sol_village.png",
		"taille": Vector2(1600, 1120),
		"depart": Vector2(800, 530),
	},
	"taverne": {
		"nom": "Taverne", "fond": "interieur_taverne.png",
		"taille": Vector2(768, 406),
		"marche": Rect2(40, 150, 690, 236),
		"depart": Vector2(390, 372),
		"sortie": Rect2(340, 368, 100, 26),
		"portail": Rect2(620, 168, 84, 60),
		"jeu": "carnage",
		"titre": "CARNAGE",
		"pnj": {"nom": "knight", "position": Vector2(180, 300), "phrases": [
			"Tu tombes bien. Dehors, la ville grouille de ces choses vertes.",
			"Prends une voiture et écrase-les — mais lancé : au pas, c'est toi qui prends.",
			"Les caisses au sol donnent une arme. L'éperon fait écraser presque à l'arrêt.",
			"Le portail est au fond. On y va à deux, à trois, à quatre.",
		]},
	},
	"armurerie": {
		"nom": "Armurerie", "fond": "interieur_armurerie.png",
		"taille": Vector2(680, 188),
		"marche": Rect2(30, 124, 620, 54),
		"depart": Vector2(330, 168),
		"sortie": Rect2(290, 166, 90, 20),
		"portail": Rect2(560, 128, 76, 46),
		"jeu": "enigme",
		"titre": "ÉNIGME",
		"pnj": {"nom": "wizzard", "position": Vector2(120, 156), "phrases": [
			"Trois chambres. Aucune ne s'ouvre à un seul.",
			"Une dalle ne reste enfoncée que si quelque chose pèse dessus — quelqu'un, ou une caisse.",
			"Et la sortie n'accepte l'équipe qu'au complet. Personne ne finit seul.",
		]},
	},
	"atelier": {
		"nom": "Atelier", "fond": "interieur_atelier.png",
		"taille": Vector2(304, 400),
		"marche": Rect2(40, 150, 220, 220),
		"depart": Vector2(150, 356),
		"sortie": Rect2(110, 352, 80, 24),
		"pnj": {"nom": "rogue", "position": Vector2(200, 220), "phrases": [
			"L'atelier ? Rien à visiter pour l'instant.",
			"Le troisième jeu se prépare. Repasse.",
		]},
	},
}

## Les maisons du village : leur image, leur place, et la porte devant
## laquelle il faut se tenir pour entrer.
const MAISONS := [
	{"lieu": "taverne", "image": "maison_taverne.png", "position": Vector2(360, 430), "nom": "TAVERNE"},
	{"lieu": "armurerie", "image": "maison_armurerie.png", "position": Vector2(800, 410), "nom": "ARMURERIE"},
	{"lieu": "atelier", "image": "maison_atelier.png", "position": Vector2(1240, 430), "nom": "ATELIER"},
]

var _canal: CanalTempsReel
var _camera: Camera2D
var _lieu := "village"
var _position := Vector2.ZERO
var _regard := "down"
var _marche := false
var _autres: Dictionary = {}       # cle -> {cible, affichee, pseudo, lieu, noeud}
var _corps: AnimatedSprite2D
var _obstacles: Array[Rect2] = []
var _portes: Array = []            # {rect, lieu, nom}
var _sortie := Rect2()
var _portail := Rect2()
var _jeu_du_lieu := ""
var _titre_du_lieu := ""
var _pnj_position := Vector2.ZERO
var _pnj_phrases: Array = []
var _phrase := -1
var _depuis_envoi := 0.0
var _depuis_rappel := 0.0
var _invite := ""

var _hud_presents: Label
var _hud_etat: HBoxContainer
var _hud_titre: Label
var _hud_invite: Label
var _hud_classement: Label
var _hud_dialogue: Label
var _panneau_dialogue: PanelContainer
var _classements: Dictionary = {}

func demarrer() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 9.0
	add_child(_camera)
	_camera.make_current()

	_construire_hud()
	# `--lieu=taverne` ouvre directement une pièce : c'est ce qui permet de
	# photographier un intérieur au banc, sans avoir à y marcher.
	var demande := ""
	for a in OS.get_cmdline_args():
		if a.begins_with("--lieu="):
			demande = a.substr(7)
	_entrer_dans(demande if LIEUX.has(demande) else "village", Vector2.ZERO)

	Tactile.mode = Tactile.MARCHE
	Tactile.action.connect(_agir)

	_canal = Reseau.rejoindre(CANAL, {"pseudo": Session.pseudo, "id": Session.id, "lieu": _lieu})
	_canal.diffusion.connect(_sur_diffusion)
	_canal.presences_changees.connect(_sur_presences)

	Scores.classement_recu.connect(_sur_classement)
	Scores.demander_classement("carnage", 5)
	Scores.demander_classement("enigme", 5)

func _exit_tree() -> void:
	if Tactile.action.is_connected(_agir):
		Tactile.action.disconnect(_agir)
	if _canal:
		_canal.quitter()

# ---------------------------------------------------------------- les lieux

func _entrer_dans(lieu: String, arrivee: Vector2) -> void:
	_lieu = lieu
	_phrase = -1
	var fiche: Dictionary = LIEUX[lieu]
	var taille: Vector2 = fiche["taille"]

	for enfant in plan().get_children():
		enfant.queue_free()
	_autres.clear()

	var fond := Pixels.image(IMAGES + String(fiche["fond"]), false)
	fond.z_index = -100
	fond.y_sort_enabled = false
	plan().add_child(fond)

	_obstacles.clear()
	_portes.clear()
	_sortie = Rect2()
	_portail = Rect2()
	_jeu_du_lieu = ""
	_pnj_phrases = []

	if lieu == "village":
		_batir_village()
	else:
		_batir_interieur(fiche)

	_position = arrivee if arrivee != Vector2.ZERO else (fiche["depart"] as Vector2)
	_corps = AnimatedSprite2D.new()
	_corps.sprite_frames = Pixels.heros()
	_corps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Le pivot du sprite est au centre de sa case ; les pieds sont vingt
	# pixels plus bas. Sans ce décalage, le personnage flotte au-dessus du
	# sol et le tri par profondeur se trompe d'une demi-case.
	_corps.offset = Vector2(0, -20)
	_corps.play("repos_down")
	plan().add_child(_corps)

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(taille.x)
	_camera.limit_bottom = int(taille.y)
	_camera.position = _position
	_camera.reset_smoothing()

	if _canal and _canal.est_rejoint:
		_canal.suivre({"pseudo": Session.pseudo, "id": Session.id, "lieu": _lieu})
	_rafraichir_hud()

func _batir_village() -> void:
	var graine := RandomNumberGenerator.new()
	graine.seed = 20260907
	var taille: Vector2 = LIEUX["village"]["taille"]

	for maison in MAISONS:
		var sprite := Pixels.image(IMAGES + String(maison["image"]))
		Pixels.poser(sprite, maison["position"])
		plan().add_child(sprite)
		var largeur := float(sprite.texture.get_width())
		var hauteur := float(sprite.texture.get_height())
		var coin: Vector2 = (maison["position"] as Vector2) - Vector2(largeur * 0.5, hauteur)
		# On ne bloque que le bas du bâtiment : le haut du toit se chevauche
		# volontiers avec un joueur qui passe derrière.
		_obstacles.append(Rect2(coin + Vector2(6, hauteur - 42), Vector2(largeur - 12, 40)))
		_portes.append({
			"rect": Rect2((maison["position"] as Vector2) + Vector2(-22, 0), Vector2(44, 26)),
			"lieu": String(maison["lieu"]),
			"nom": String(maison["nom"]),
		})
		# L'enseigne au-dessus de la porte : sans elle, trois maisons se
		# ressemblent et on entre au hasard.
		var enseigne := Label.new()
		enseigne.text = String(maison["nom"])
		enseigne.add_theme_font_size_override("font_size", 11)
		enseigne.add_theme_color_override("font_color", Palette.ENCRE)
		enseigne.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		enseigne.add_theme_constant_override("outline_size", 5)
		enseigne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enseigne.size = Vector2(120, 14)
		enseigne.position = (maison["position"] as Vector2) + Vector2(-60, 12)
		enseigne.z_index = 50
		plan().add_child(enseigne)

	# Une lisière d'arbres et quelques bosquets : ils ferment le village sans
	# qu'on ait à poser un mur, et donnent l'échelle du personnage.
	for i in 90:
		var bord := graine.randi_range(0, 3)
		var p := Vector2.ZERO
		match bord:
			0: p = Vector2(graine.randf_range(0, taille.x), graine.randf_range(0, 120))
			1: p = Vector2(graine.randf_range(0, taille.x), graine.randf_range(taille.y - 150, taille.y))
			2: p = Vector2(graine.randf_range(0, 150), graine.randf_range(0, taille.y))
			_: p = Vector2(graine.randf_range(taille.x - 150, taille.x), graine.randf_range(0, taille.y))
		_planter(IMAGES + "arbre_%d.png" % graine.randi_range(0, 3), p, 18.0)
	for i in 30:
		var p2 := Vector2(graine.randf_range(180, taille.x - 180), graine.randf_range(180, taille.y - 180))
		if p2.distance_to(Vector2(800, 560)) < 300.0:
			continue
		if graine.randf() < 0.45:
			_planter(IMAGES + "arbre_%d.png" % graine.randi_range(0, 3), p2, 18.0)
		else:
			_planter(IMAGES + "buisson_%d.png" % graine.randi_range(0, 3), p2, 0.0)
	for i in 18:
		var p3 := Vector2(graine.randf_range(150, taille.x - 150), graine.randf_range(150, taille.y - 150))
		_planter(IMAGES + "rocher_%d.png" % graine.randi_range(0, 2), p3, 10.0)

func _planter(chemin: String, position: Vector2, blocage: float) -> void:
	var sprite := Pixels.image(chemin)
	Pixels.poser(sprite, position)
	plan().add_child(sprite)
	if blocage > 0.0:
		_obstacles.append(Rect2(position - Vector2(blocage, blocage * 0.5), Vector2(blocage * 2.0, blocage)))

func _batir_interieur(fiche: Dictionary) -> void:
	var marche: Rect2 = fiche["marche"]
	# On ne modélise pas les murs : on borne la zone où l'on marche. Une
	# pièce dessinée n'a pas de géométrie, et lister ses murs à la main
	# reviendrait à la redessiner une seconde fois, en moins fiable.
	_obstacles.append(Rect2(marche.position - Vector2(400, 400), Vector2(400, 1200)))
	_obstacles.append(Rect2(Vector2(marche.end.x, marche.position.y - 400), Vector2(400, 1200)))
	_obstacles.append(Rect2(marche.position - Vector2(400, 400), Vector2(1600, 400)))
	_obstacles.append(Rect2(Vector2(marche.position.x - 400, marche.end.y), Vector2(1600, 400)))

	_sortie = fiche.get("sortie", Rect2())
	_portail = fiche.get("portail", Rect2())
	_jeu_du_lieu = String(fiche.get("jeu", ""))
	_titre_du_lieu = String(fiche.get("titre", ""))

	if _portail != Rect2():
		var lueur := Node2D.new()
		lueur.set_script(preload("res://scenes/lueur_portail.gd"))
		lueur.position = _portail.get_center()
		lueur.set("taille", _portail.size)
		plan().add_child(lueur)

	var pnj: Dictionary = fiche.get("pnj", {})
	if not pnj.is_empty():
		_pnj_position = pnj["position"]
		_pnj_phrases = pnj["phrases"]
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = Pixels.personnage_non_joueur(String(pnj["nom"]))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.offset = Vector2(0, -10)
		sprite.scale = Vector2(2, 2)
		Pixels.poser(sprite, _pnj_position)
		sprite.play("repos")
		plan().add_child(sprite)

# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	var direction := Commandes.direction()
	if direction != Vector2.ZERO:
		var avant := _position
		_position.x += direction.x * VITESSE * delta
		_degager(Vector2(1, 0), avant)
		avant = _position
		_position.y += direction.y * VITESSE * delta
		_degager(Vector2(0, 1), avant)
		_borner()
		_regard = ("side" if absf(direction.x) > absf(direction.y) else ("down" if direction.y > 0 else "up"))
		_corps.flip_h = direction.x < 0.0 and _regard == "side"
		_marche = true
	else:
		_marche = false

	var animation := ("marche_" if _marche else "repos_") + _regard
	if _corps.animation != animation:
		_corps.play(animation)
	Pixels.poser(_corps, _position)
	_corps.z_index = 0

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var vers: Vector2 = (a["cible"] as Vector2) - (a["affichee"] as Vector2)
		a["affichee"] = (a["affichee"] as Vector2).lerp(a["cible"], clamp(delta * 12.0, 0, 1))
		var noeud: AnimatedSprite2D = a["noeud"]
		Pixels.poser(noeud, a["affichee"])
		var bouge := vers.length() > 2.0
		var sens := "side" if absf(vers.x) > absf(vers.y) else ("down" if vers.y > 0 else "up")
		var anim := ("marche_" if bouge else "repos_") + sens
		if noeud.animation != anim:
			noeud.play(anim)
		if bouge and sens == "side":
			noeud.flip_h = vers.x < 0.0

	_camera.position = _position
	_chercher_quoi_faire()

	_depuis_envoi += delta
	_depuis_rappel += delta
	if _depuis_envoi >= CADENCE_ENVOI and (_marche or _depuis_rappel >= RAPPEL):
		_depuis_envoi = 0.0
		_depuis_rappel = 0.0
		_canal.envoyer("p", {"x": int(_position.x), "y": int(_position.y)})

## Repousse le personnage hors d'un obstacle sur UN seul axe à la fois. En
## corrigeant les deux ensemble, on reste accroché aux angles : le joueur
## glisse le long d'un mur au lieu de s'y coller.
func _degager(axe: Vector2, avant: Vector2) -> void:
	var pieds := Rect2(_position - Vector2(RAYON, 6), Vector2(RAYON * 2.0, 10))
	for obstacle in _obstacles:
		if obstacle.intersects(pieds):
			_position = avant
			return

func _borner() -> void:
	var taille: Vector2 = LIEUX[_lieu]["taille"]
	_position.x = clamp(_position.x, 12.0, taille.x - 12.0)
	_position.y = clamp(_position.y, 24.0, taille.y - 8.0)

func _chercher_quoi_faire() -> void:
	var avant := _invite
	_invite = ""
	if _lieu == "village":
		for porte in _portes:
			if (porte["rect"] as Rect2).has_point(_position):
				_invite = "entrer:" + String(porte["lieu"])
				break
	else:
		if _portail != Rect2() and _portail.grow(14.0).has_point(_position):
			_invite = "portail"
		elif _sortie.grow(8.0).has_point(_position):
			_invite = "sortir"
		elif not _pnj_phrases.is_empty() and _position.distance_to(_pnj_position) < 44.0:
			_invite = "parler"
	if avant != _invite:
		if not _invite.begins_with("parler"):
			_phrase = -1
		_rafraichir_hud()

func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventKey and evenement.pressed and not evenement.echo and evenement.keycode == KEY_E:
		_agir()

func _agir() -> void:
	if not is_inside_tree():
		return
	if _invite.begins_with("entrer:"):
		Sons.jouer("porte", 1.0, -10.0)
		_entrer_dans(_invite.substr(7), Vector2.ZERO)
	elif _invite == "sortir":
		Sons.jouer("porte", 0.8, -10.0)
		var retour := Vector2(800, 560)
		for maison in MAISONS:
			if String(maison["lieu"]) == _lieu:
				retour = (maison["position"] as Vector2) + Vector2(0, 34)
		_entrer_dans("village", retour)
	elif _invite == "portail" and _jeu_du_lieu != "":
		Sons.jouer("portail", 1.0, -8.0)
		demande_ecran.emit("salon", {"jeu": _jeu_du_lieu, "titre": _titre_du_lieu})
	elif _invite == "parler":
		_phrase = (_phrase + 1) % (_pnj_phrases.size() + 1)
		Sons.jouer("clic", 1.2, -16.0)
		_rafraichir_hud()

# ---------------------------------------------------------------- réseau

func _sur_diffusion(evenement: String, charge: Dictionary) -> void:
	if evenement != "p":
		return
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.cle or not _autres.has(cle):
		return
	_autres[cle]["cible"] = Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))

func _sur_presences(presences: Dictionary) -> void:
	for cle in _autres.keys():
		var toujours_la: bool = presences.has(cle) and String(presences[cle].get("lieu", "village")) == _lieu
		if not toujours_la:
			(_autres[cle]["noeud"] as Node2D).queue_free()
			_autres.erase(cle)
	for cle in presences:
		if cle == Session.cle:
			continue
		var meta: Dictionary = presences[cle]
		if String(meta.get("lieu", "village")) != _lieu:
			continue
		if not _autres.has(cle):
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = Pixels.heros()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.offset = Vector2(0, -20)
			sprite.modulate = Palette.couleur_joueur(1).lerp(Color.WHITE, 0.55)
			sprite.play("repos_down")
			Pixels.poser(sprite, _position)
			plan().add_child(sprite)
			var nom := Label.new()
			nom.text = String(meta.get("pseudo", "?"))
			nom.add_theme_font_size_override("font_size", 9)
			nom.add_theme_color_override("font_color", Palette.ENCRE)
			nom.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			nom.add_theme_constant_override("outline_size", 4)
			nom.position = Vector2(-30, -46)
			nom.size = Vector2(60, 12)
			nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sprite.add_child(nom)
			_autres[cle] = {"cible": _position, "affichee": _position,
				"pseudo": String(meta.get("pseudo", "?")), "noeud": sprite}
	_rafraichir_hud()

func _sur_classement(jeu: String, lignes: Array) -> void:
	_classements[jeu] = lignes
	_rafraichir_hud()

## Utilisé par le banc d'essai : combien de joueurs ce client voit-il ?
func nombre_de_joueurs() -> int:
	return _autres.size() + 1

func presences_vues() -> Array:
	return _canal.presences.keys() if _canal else []

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
	bas.offset_top = -128
	bas.offset_bottom = -18
	bas.add_theme_constant_override("separation", 4)
	couche.add_child(bas)
	_hud_titre = UI.titre("", 22)
	_hud_classement = UI.texte("", 13, Palette.ENCRE_FAIBLE)
	_hud_invite = UI.texte("", 15, Palette.SERIE)
	bas.add_child(_hud_titre)
	bas.add_child(_hud_classement)
	bas.add_child(_hud_invite)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	centre.offset_top = -230
	centre.offset_bottom = -150
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(centre)
	_panneau_dialogue = UI.panneau()
	_panneau_dialogue.visible = false
	centre.add_child(_panneau_dialogue)
	_hud_dialogue = UI.texte("", 16, Palette.ENCRE, true)
	_hud_dialogue.custom_minimum_size = Vector2(620, 0)
	_panneau_dialogue.add_child(_hud_dialogue)

func _rafraichir_hud() -> void:
	if _hud_etat == null:
		return
	UI.rafraichir_etat_reseau(_hud_etat)
	var noms: Array = [Session.pseudo]
	for cle in _autres:
		noms.append(String(_autres[cle]["pseudo"]))
	var ou := String(LIEUX[_lieu].get("nom", _lieu.capitalize()))
	_hud_presents.text = "%s (%d) : %s" % [ou, noms.size(), ", ".join(noms)]

	_hud_titre.text = "Village de Piks-l" if _lieu == "village" else String(LIEUX[_lieu].get("nom", _lieu))
	_hud_classement.text = ""
	if _lieu != "village" and _jeu_du_lieu != "":
		_hud_classement.text = _resumer_classement(_jeu_du_lieu)

	match _invite.split(":")[0]:
		"entrer": _hud_invite.text = "E — entrer"
		"sortir": _hud_invite.text = "E — ressortir"
		"portail": _hud_invite.text = "E — franchir le portail"
		"parler": _hud_invite.text = "E — parler"
		_: _hud_invite.text = "Z Q S D ou les flèches pour marcher."

	var parle := _invite == "parler" and _phrase >= 0 and _phrase < _pnj_phrases.size()
	_panneau_dialogue.visible = parle
	if parle:
		_hud_dialogue.text = String(_pnj_phrases[_phrase])

func _resumer_classement(jeu: String) -> String:
	var lignes = _classements.get(jeu, null)
	if lignes == null:
		return ""
	if (lignes as Array).is_empty():
		return "Au mur : aucun score déposé pour l'instant."
	var morceaux: Array = []
	var rang := 1
	for ligne in lignes:
		morceaux.append("%d. %s %d" % [rang, String(ligne.get("pseudo", "?")), int(ligne.get("score", 0))])
		rang += 1
	return "Au mur — " + "   ".join(morceaux)
