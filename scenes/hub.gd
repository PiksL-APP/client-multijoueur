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
## Une seule échelle : celle du pack. Une case de sol fait 16 pixels, un
## personnage 30, une porte 41 ; aucun sprite n'est agrandi ni réduit, et la
## caméra zoome d'un facteur ENTIER. C'est la condition pour que rien ne
## bave et que tout paraisse de la même taille.
##
## Choix de synchronisation : l'identité et le LIEU passent par la présence
## (rares, fiables) ; la position par la diffusion (fréquente, jetable). On ne
## dessine que les joueurs qui sont dans la même pièce que soi.

const CANAL := "mj-hub"
const VITESSE := 96.0
const RAYON := 6.0                 ## demi-largeur des pieds, pour les collisions
const ZOOM := 3                    ## entier, sinon les pixels ne tombent pas juste
const CADENCE_ENVOI := 1.0 / 8.0
const RAPPEL := 1.5
const IMAGES := "res://modeles/village/"
## Toutes les planches de personnages sont au même gabarit (cases de 64,
## pieds sur le bord bas) : le pivot est au centre, les pieds 32 plus bas.
const PIEDS := Vector2(0, -32)

## Les lieux du hub. Le village est dehors ; les trois autres sont des pièces
## entières de la maquette du pack, chacune avec sa zone de marche, ses
## meubles, sa sortie, son habitant, et — pour deux d'entre elles — le
## classement au mur et le portail qui lance le jeu. Toutes les coordonnées
## sont en pixels de l'image du lieu.
const LIEUX := {
	"village": {
		"nom": "Village", "fond": "sol_village.png",
		"taille": Vector2(768, 544),
		"depart": Vector2(384, 400),
		"pnj": [{"nom": "paysanne", "position": Vector2(436, 370), "phrases": [
			"Bienvenue. Trois maisons, trois portes : entre, on ne mord pas.",
			"La taverne mène au Carnage, l'armurerie à l'Énigme. L'auberge… on y dort.",
			"On se retrouve ici entre deux parties. Le feu ne s'éteint jamais.",
		]}],
	},
	"taverne": {
		"nom": "Taverne", "fond": "interieur_taverne.png",
		"taille": Vector2(456, 337),
		"marche": [Rect2(8, 142, 432, 184)],
		"meubles": [
			Rect2(80, 136, 80, 80),      # le comptoir et ses étagères
			Rect2(200, 144, 72, 48),     # la table rouge du haut
			Rect2(208, 212, 64, 40),     # la table du milieu
			Rect2(324, 168, 60, 124),    # la grande table bleue
			Rect2(88, 277, 80, 40),      # la table rouge du bas
			Rect2(208, 277, 64, 40),     # la table bleue du bas
			Rect2(64, 152, 16, 40), Rect2(176, 152, 16, 40), Rect2(288, 152, 16, 40), Rect2(400, 152, 16, 40),
			Rect2(64, 240, 16, 40), Rect2(176, 240, 16, 40), Rect2(288, 240, 16, 40), Rect2(400, 240, 16, 40),
		],
		"depart": Vector2(30, 315),
		"sortie": Rect2(8, 314, 44, 12),
		"portail": Rect2(168, 142, 32, 16),
		"lueur": {"centre": Vector2(184, 125), "taille": Vector2(28, 36)},
		"tableau": Rect2(204, 94, 60, 42),
		"jeu": "carnage",
		"titre": "CARNAGE",
		"pnj": [{"nom": "taverniere", "position": Vector2(125, 235), "phrases": [
			"Tu tombes bien. Dehors, la ville grouille de ces choses vertes.",
			"Prends une voiture et écrase-les — mais lancé : au pas, c'est toi qui prends.",
			"Les caisses au sol donnent une arme. L'éperon fait écraser presque à l'arrêt.",
			"Le portail, c'est la porte du fond. On y va à deux, à trois, à quatre.",
		]}],
	},
	"armurerie": {
		"nom": "Armurerie", "fond": "interieur_armurerie.png",
		"taille": Vector2(640, 84),
		"marche": [Rect2(20, 40, 600, 30)],
		"meubles": [Rect2(328, 30, 32, 20), Rect2(456, 30, 32, 20)],
		"depart": Vector2(200, 56),
		"sortie": Rect2(178, 40, 44, 10),
		"portail": Rect2(580, 42, 32, 26),
		"lueur": {"centre": Vector2(596, 55), "taille": Vector2(24, 22)},
		"tableau": Rect2(64, 6, 64, 40),
		"jeu": "enigme",
		"titre": "ÉNIGME",
		"pnj": [{"nom": "squelette", "position": Vector2(430, 60), "phrases": [
			"Trois chambres. Aucune ne s'ouvre à un seul.",
			"Une dalle ne reste enfoncée que si quelque chose pèse dessus — quelqu'un, ou une caisse.",
			"Et la sortie n'accepte l'équipe qu'au complet. Personne ne finit seul.",
			"Le portail est au bout du couloir, à droite.",
		]}],
	},
	"auberge": {
		"nom": "Auberge", "fond": "interieur_auberge.png",
		"taille": Vector2(142, 161),
		"marche": [Rect2(10, 40, 124, 118)],
		"meubles": [Rect2(8, 44, 30, 68), Rect2(88, 92, 48, 62), Rect2(12, 122, 24, 26)],
		"depart": Vector2(71, 146),
		"sortie": Rect2(56, 148, 30, 10),
		"pnj": [{"nom": "aubergiste", "position": Vector2(112, 62), "phrases": [
			"Chut, il y a des gens qui dorment. Ici on se repose entre deux parties.",
			"Le troisième jeu se prépare. Repasse.",
		]}],
	},
}

## Les maisons du village : leur image, la place de leur pied, et le lieu où
## mène leur porte. La porte fait 32 pixels au milieu de la façade.
const MAISONS := [
	{"lieu": "taverne", "image": "maison_taverne.png", "position": Vector2(224, 216), "nom": "TAVERNE"},
	{"lieu": "armurerie", "image": "maison_armurerie.png", "position": Vector2(384, 216), "nom": "ARMURERIE"},
	{"lieu": "auberge", "image": "maison_auberge.png", "position": Vector2(544, 216), "nom": "AUBERGE"},
]
const PLACE := Rect2(192, 224, 384, 192)   # la place pavée du village

var _canal: CanalTempsReel
var _camera: Camera2D
var _lieu := "village"
var _position := Vector2.ZERO
var _marche := false
var _autres: Dictionary = {}       # cle -> {cible, affichee, pseudo, noeud}
var _corps: AnimatedSprite2D
var _obstacles: Array[Rect2] = []
var _marche_dans: Array[Rect2] = []
var _portes: Array = []            # {rect, lieu, nom}
var _sortie := Rect2()
var _portail := Rect2()
var _jeu_du_lieu := ""
var _titre_du_lieu := ""
var _pnj: Array = []               # {position, phrases}
var _pnj_proche := -1
var _phrase := -1
var _depuis_envoi := 0.0
var _depuis_rappel := 0.0
var _invite := ""

var _hud_presents: Label
var _hud_etat: HBoxContainer
var _hud_titre: Label
var _hud_invite: Label
var _hud_dialogue: Label
var _panneau_dialogue: PanelContainer
var _tableau: Label
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
	var depart := Vector2.ZERO
	for a in OS.get_cmdline_args():
		if a.begins_with("--lieu="):
			demande = a.substr(7)
		elif a.begins_with("--depart="):
			var xy := a.substr(9).split(",")
			if xy.size() == 2:
				depart = Vector2(float(xy[0]), float(xy[1]))
	_entrer_dans(demande if LIEUX.has(demande) else "village", depart)

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
	_pnj_proche = -1
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
	_marche_dans.clear()
	_portes.clear()
	_sortie = Rect2()
	_portail = Rect2()
	_jeu_du_lieu = ""
	_titre_du_lieu = ""
	_pnj = []
	_tableau = null

	if lieu == "village":
		_batir_village()
	else:
		_batir_interieur(fiche)
	for pnj in fiche.get("pnj", []):
		_poser_pnj(pnj)

	_position = arrivee if arrivee != Vector2.ZERO else (fiche["depart"] as Vector2)
	_corps = _sprite_de_heros(Session.id)
	plan().add_child(_corps)

	# Une pièce plus petite que l'écran se centre ; une plus grande fait
	# glisser la caméra sans jamais montrer au-delà de ses murs.
	var visible := _vue()
	_camera.limit_left = 0 if taille.x > visible.x else -100000
	_camera.limit_right = int(taille.x) if taille.x > visible.x else 100000
	_camera.limit_top = 0 if taille.y > visible.y else -100000
	_camera.limit_bottom = int(taille.y) if taille.y > visible.y else 100000
	_camera.position = _position_camera()
	_camera.reset_smoothing()

	if _canal and _canal.est_rejoint:
		_canal.suivre({"pseudo": Session.pseudo, "id": Session.id, "lieu": _lieu})
	_rafraichir_hud()

func _vue() -> Vector2:
	return get_viewport().get_visible_rect().size / float(ZOOM)

func _position_camera() -> Vector2:
	var taille: Vector2 = LIEUX[_lieu]["taille"]
	var visible := _vue()
	return Vector2(
		_position.x if taille.x > visible.x else taille.x * 0.5,
		_position.y if taille.y > visible.y else taille.y * 0.5)

func _sprite_de_heros(id: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = Pixels.heros(Pixels.heros_de(id))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset = PIEDS
	s.play("repos")
	return s

func _batir_village() -> void:
	var graine := RandomNumberGenerator.new()
	graine.seed = 20260907
	var taille: Vector2 = LIEUX["village"]["taille"]
	# Personne ne pousse sur la place, ni juste dessous : une cime de 96
	# pixels recouvrirait le pavé.
	var reserves: Array[Rect2] = [Rect2(PLACE.position - Vector2(28, 28), PLACE.size + Vector2(56, 130))]

	for maison in MAISONS:
		var pied: Vector2 = maison["position"]
		var sprite := Pixels.image(IMAGES + String(maison["image"]))
		Pixels.poser(sprite, pied)
		plan().add_child(sprite)
		# Le mur fait 96 de large sous un toit de 128 : on bloque le mur, et
		# le joueur passe derrière la maison, caché par le toit.
		_obstacles.append(Rect2(pied + Vector2(-48, -56), Vector2(96, 56)))
		reserves.append(Rect2(pied + Vector2(-80, -150), Vector2(160, 190)))
		_portes.append({
			"rect": Rect2(pied + Vector2(-18, 0), Vector2(36, 22)),
			"lieu": String(maison["lieu"]),
			"nom": String(maison["nom"]),
		})
		var enseigne := _ecriteau(String(maison["nom"]), 7)
		enseigne.position = pied + Vector2(-60, -140)
		enseigne.size = Vector2(120, 10)
		plan().add_child(enseigne)

	# Le feu de camp au milieu de la place, deux bancs, des caisses devant la
	# taverne : c'est là qu'on se retrouve.
	var foyer := Pixels.image(IMAGES + "foyer.png")
	Pixels.poser(foyer, Vector2(384, 336))
	plan().add_child(foyer)
	var feu := AnimatedSprite2D.new()
	feu.sprite_frames = Pixels.animation("feu", IMAGES + "feu.png", 10.0, 32)
	feu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# La flamme (contenu jusqu'à la ligne 33 de sa case de 48) doit reposer
	# au milieu du foyer, et se dessiner APRÈS lui : d'où ce pivot un pixel
	# plus bas que le foyer.
	feu.offset = Vector2(2, -14)
	Pixels.poser(feu, Vector2(384, 337))
	feu.play("feu")
	plan().add_child(feu)
	_obstacles.append(Rect2(366, 312, 36, 26))
	for x in [304, 464]:
		var banc := Pixels.image(IMAGES + "banc.png")
		Pixels.poser(banc, Vector2(x, 346))
		plan().add_child(banc)
		_obstacles.append(Rect2(x - 30, 324, 60, 20))
	var caisses := Pixels.image(IMAGES + "caisses.png")
	Pixels.poser(caisses, Vector2(210, 254))
	plan().add_child(caisses)
	_obstacles.append(Rect2(196, 232, 28, 20))

	# Une lisière dense d'arbres ferme le village ; quelques-uns, des
	# buissons et des rochers habitent l'intérieur. Chaque sprite est posé
	# entier, à sa taille, sans jamais en chevaucher un autre.
	# La lisière est infranchissable : on y verrait le joueur disparaître
	# sous les cimes. Quatre bandes d'obstacles ferment la clairière.
	_obstacles.append(Rect2(0, 0, taille.x, 150))
	_obstacles.append(Rect2(0, taille.y - 108, taille.x, 108))
	_obstacles.append(Rect2(0, 0, 100, taille.y))
	_obstacles.append(Rect2(taille.x - 100, 0, 100, taille.y))
	var poses: Array[Vector2] = []
	var essais := 0
	while poses.size() < 56 and essais < 4000:
		essais += 1
		var p := Vector2(graine.randf_range(24, taille.x - 24), graine.randf_range(100, taille.y - 4))
		# En bas, les arbres ont les pieds tout au bord : leur cime monte de
		# 96 pixels et ne doit pas couvrir la clairière.
		var au_bord := p.x < 100 or p.x > taille.x - 100 or p.y < 140 or p.y > taille.y - 26
		if not au_bord:
			continue
		if _libre(p, poses, reserves, 40.0):
			poses.append(p)
			_planter(_arbre(graine), p, Rect2(-8, -8, 16, 8))
	essais = 0
	var interieurs := 0
	while interieurs < 12 and essais < 3000:
		essais += 1
		var p2 := Vector2(graine.randf_range(110, taille.x - 110), graine.randf_range(150, taille.y - 90))
		if not _libre(p2, poses, reserves, 48.0):
			continue
		poses.append(p2)
		interieurs += 1
		# Pas d'arbre dans la clairière : une cime cacherait le joueur qui
		# passe derrière. Buissons et rochers, eux, ne cachent personne.
		match graine.randi_range(0, 3):
			0, 1: _planter("buisson_%d.png" % graine.randi_range(0, 1), p2, Rect2(-16, -10, 32, 10))
			2: _planter("rocher_grand_%d.png" % graine.randi_range(0, 1), p2, Rect2(-12, -10, 24, 10))
			_: _planter("rocher_moyen_%d.png" % graine.randi_range(0, 1), p2, Rect2(-10, -8, 20, 8))
	essais = 0
	var petits := 0
	while petits < 18 and essais < 3000:
		essais += 1
		var p3 := Vector2(graine.randf_range(50, taille.x - 50), graine.randf_range(120, taille.y - 50))
		if not _libre(p3, poses, reserves, 30.0):
			continue
		poses.append(p3)
		petits += 1
		if graine.randf() < 0.6:
			_planter("buisson_petit_%d.png" % graine.randi_range(0, 1), p3, Rect2(-10, -8, 20, 8))
		else:
			_planter("rocher_petit_%d.png" % graine.randi_range(0, 1), p3, Rect2())

func _arbre(graine: RandomNumberGenerator) -> String:
	return ("arbre_%d.png" if graine.randf() < 0.65 else "pin_%d.png") % graine.randi_range(0, 2)

func _libre(p: Vector2, poses: Array[Vector2], reserves: Array[Rect2], ecart: float) -> bool:
	for r in reserves:
		if r.has_point(p):
			return false
	for q in poses:
		if q.distance_to(p) < ecart:
			return false
	return true

func _planter(image: String, position: Vector2, blocage: Rect2) -> void:
	var sprite := Pixels.image(IMAGES + image)
	Pixels.poser(sprite, position)
	plan().add_child(sprite)
	if blocage.size != Vector2.ZERO:
		_obstacles.append(Rect2(position.round() + blocage.position, blocage.size))

func _batir_interieur(fiche: Dictionary) -> void:
	# On ne modélise pas les murs : la pièce est une image, et l'on borne la
	# zone où l'on marche, moins les meubles.
	for r in fiche.get("marche", []):
		_marche_dans.append(r)
	for r in fiche.get("meubles", []):
		_obstacles.append(r)

	_sortie = fiche.get("sortie", Rect2())
	_portail = fiche.get("portail", Rect2())
	_jeu_du_lieu = String(fiche.get("jeu", ""))
	_titre_du_lieu = String(fiche.get("titre", ""))

	if fiche.has("lueur"):
		var lueur := Node2D.new()
		lueur.set_script(preload("res://scenes/lueur_portail.gd"))
		lueur.position = fiche["lueur"]["centre"]
		lueur.set("taille", fiche["lueur"]["taille"])
		lueur.z_index = 5
		plan().add_child(lueur)

	if fiche.has("tableau"):
		_tableau = _tableau_mural(fiche["tableau"])
		plan().add_child(_tableau)
		_rafraichir_tableau()

func _poser_pnj(pnj: Dictionary) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Pixels.personnage_non_joueur(String(pnj["nom"]))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = PIEDS
	Pixels.poser(sprite, pnj["position"])
	sprite.play("repos")
	plan().add_child(sprite)
	_pnj.append({"position": (pnj["position"] as Vector2).round(), "phrases": pnj["phrases"]})
	_obstacles.append(Rect2((pnj["position"] as Vector2).round() + Vector2(-8, -8), Vector2(16, 10)))

## Le classement affiché SUR le mur de la pièce, comme une ardoise de
## taverne : un cadre sombre à la taille de la niche, et le texte dedans.
func _tableau_mural(cadre: Rect2) -> Label:
	var ardoise := Label.new()
	ardoise.position = cadre.position
	ardoise.size = cadre.size
	ardoise.z_index = 4
	ardoise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ardoise.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ardoise.add_theme_font_size_override("font_size", 6)
	ardoise.add_theme_constant_override("line_spacing", -2)
	ardoise.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.19, 0.12, 0.07)
	style.border_color = Color(0.45, 0.30, 0.16)
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	ardoise.add_theme_stylebox_override("normal", style)
	return ardoise

func _rafraichir_tableau() -> void:
	if _tableau == null or _jeu_du_lieu == "":
		return
	var lignes = _classements.get(_jeu_du_lieu, null)
	var texte := _titre_du_lieu + "\n"
	if lignes == null:
		texte += "…"
	elif (lignes as Array).is_empty():
		texte += "aucun score"
	else:
		var rang := 1
		for ligne in lignes:
			texte += "%d. %s  %d\n" % [rang, String(ligne.get("pseudo", "?")).left(9), int(ligne.get("score", 0))]
			rang += 1
	_tableau.text = texte.strip_edges()

## « la taverne », « l'armurerie » : le nom du lieu avec son article.
static func _article(lieu: String) -> String:
	var nom := String(LIEUX[lieu]["nom"]).to_lower()
	return ("l'" if nom[0] in "aeiouy" else "la ") + nom

func _ecriteau(texte: String, taille_police: int) -> Label:
	var e := Label.new()
	e.text = texte
	e.add_theme_font_size_override("font_size", taille_police)
	e.add_theme_color_override("font_color", Palette.ENCRE)
	e.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	e.add_theme_constant_override("outline_size", 3)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.z_index = 50
	return e

# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	var direction := Commandes.direction()
	if direction != Vector2.ZERO:
		var avant := _position
		_position.x += direction.x * VITESSE * delta
		_degager(avant)
		avant = _position
		_position.y += direction.y * VITESSE * delta
		_degager(avant)
		_borner()
		# Les héros sont dessinés de profil : on ne retourne le sprite que
		# sur un pas horizontal, et il garde son côté quand on monte ou descend.
		if direction.x != 0.0:
			_corps.flip_h = direction.x < 0.0
		_marche = true
	else:
		_marche = false

	var animation := "marche" if _marche else "repos"
	if _corps.animation != animation:
		_corps.play(animation)
	Pixels.poser(_corps, _position)

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var vers: Vector2 = (a["cible"] as Vector2) - (a["affichee"] as Vector2)
		a["affichee"] = (a["affichee"] as Vector2).lerp(a["cible"], clamp(delta * 12.0, 0, 1))
		var noeud: AnimatedSprite2D = a["noeud"]
		Pixels.poser(noeud, a["affichee"])
		var bouge := vers.length() > 2.0
		var anim := "marche" if bouge else "repos"
		if noeud.animation != anim:
			noeud.play(anim)
		if bouge and absf(vers.x) > 0.5:
			noeud.flip_h = vers.x < 0.0

	_camera.position = _position_camera()
	_chercher_quoi_faire()

	_depuis_envoi += delta
	_depuis_rappel += delta
	if _depuis_envoi >= CADENCE_ENVOI and (_marche or _depuis_rappel >= RAPPEL):
		_depuis_envoi = 0.0
		_depuis_rappel = 0.0
		_canal.envoyer("p", {"x": int(_position.x), "y": int(_position.y)})

## Annule le dernier pas s'il mène dans un meuble ou hors de la zone de
## marche. On corrige UN axe à la fois : le joueur glisse le long d'un mur au
## lieu de s'y coller.
func _degager(avant: Vector2) -> void:
	var pieds := Rect2(_position - Vector2(RAYON, 5), Vector2(RAYON * 2.0, 8))
	for obstacle in _obstacles:
		if obstacle.intersects(pieds):
			_position = avant
			return
	if _marche_dans.is_empty():
		return
	for zone in _marche_dans:
		if zone.encloses(pieds):
			return
	_position = avant

func _borner() -> void:
	var taille: Vector2 = LIEUX[_lieu]["taille"]
	_position.x = clamp(_position.x, 12.0, taille.x - 12.0)
	_position.y = clamp(_position.y, 24.0, taille.y - 8.0)

func _chercher_quoi_faire() -> void:
	var avant := _invite
	_invite = ""
	_pnj_proche = -1
	if _portail != Rect2() and _portail.grow(6.0).has_point(_position):
		_invite = "portail"
	elif _sortie != Rect2() and _sortie.grow(6.0).has_point(_position):
		_invite = "sortir"
	else:
		for porte in _portes:
			if (porte["rect"] as Rect2).has_point(_position):
				_invite = "entrer:" + String(porte["lieu"])
				break
	if _invite == "":
		for i in _pnj.size():
			if _position.distance_to(_pnj[i]["position"]) < 34.0:
				_invite = "parler"
				_pnj_proche = i
				break
	if avant != _invite:
		if _invite != "parler":
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
		var retour: Vector2 = LIEUX["village"]["depart"]
		for maison in MAISONS:
			if String(maison["lieu"]) == _lieu:
				retour = (maison["position"] as Vector2) + Vector2(0, 30)
		_entrer_dans("village", retour)
	elif _invite == "portail" and _jeu_du_lieu != "":
		Sons.jouer("portail", 1.0, -8.0)
		demande_ecran.emit("salon", {"jeu": _jeu_du_lieu, "titre": _titre_du_lieu})
	elif _invite == "parler" and _pnj_proche >= 0:
		var phrases: Array = _pnj[_pnj_proche]["phrases"]
		_phrase = (_phrase + 1) % (phrases.size() + 1)
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
			var sprite := _sprite_de_heros(String(meta.get("id", cle)))
			Pixels.poser(sprite, _position)
			plan().add_child(sprite)
			var nom := _ecriteau(String(meta.get("pseudo", "?")), 6)
			nom.position = Vector2(-40, -44)
			nom.size = Vector2(80, 8)
			sprite.add_child(nom)
			_autres[cle] = {"cible": _position, "affichee": _position,
				"pseudo": String(meta.get("pseudo", "?")), "noeud": sprite}
	_rafraichir_hud()

func _sur_classement(jeu: String, lignes: Array) -> void:
	_classements[jeu] = lignes
	_rafraichir_tableau()

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
	bas.offset_top = -100
	bas.offset_bottom = -18
	bas.add_theme_constant_override("separation", 4)
	couche.add_child(bas)
	_hud_titre = UI.titre("", 22)
	_hud_invite = UI.texte("", 15, Palette.SERIE)
	bas.add_child(_hud_titre)
	bas.add_child(_hud_invite)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	centre.offset_top = -210
	centre.offset_bottom = -120
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
	_hud_titre.text = "Village de Piks-l" if _lieu == "village" else ou

	match _invite.split(":")[0]:
		"entrer": _hud_invite.text = "E — entrer dans " + _article(_invite.substr(7))
		"sortir": _hud_invite.text = "E — ressortir"
		"portail": _hud_invite.text = "E — franchir le portail"
		"parler": _hud_invite.text = "E — parler"
		_: _hud_invite.text = "Z Q S D ou les flèches pour marcher."

	var parle := _invite == "parler" and _pnj_proche >= 0 and _phrase >= 0 \
		and _phrase < (_pnj[_pnj_proche]["phrases"] as Array).size()
	_panneau_dialogue.visible = parle
	if parle:
		_hud_dialogue.text = String(_pnj[_pnj_proche]["phrases"][_phrase])
