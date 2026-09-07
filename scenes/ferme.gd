extends Ecran
## LA FERME — prototype du jalon J0 de la nouvelle ÉNIGME.
##
## On laboure, on sème, on arrose, ça pousse. Rien d'autre pour l'instant : ni
## réseau, ni persistance, ni chambres de test. Cette étape répond à une seule
## question, celle qu'aucun document ne tranche — est-ce que cette boucle est
## agréable à la manette ? Y brancher Supabase avant de le savoir, ce serait
## payer la persistance d'un jeu qu'on jetterait.
##
## Tout le décor sort du pack du village et le sol de couleurs relevées dans
## ses fichiers (`commun/terrain.gd`) : la ferme et le hub doivent se
## ressembler, on passe de l'un à l'autre par une porte.

const MONDE := Vector2(768, 544)
const CASE := 32                          ## côté d'une parcelle, en pixels
const CHAMP := Rect2i(5, 5, 14, 7)        ## la zone cultivable, en cases
const VITESSE := 96.0
const RAYON := 6.0
const ZOOM := 3                           ## entier, comme au hub
const IMAGES := "res://modeles/village/"
const PIEDS := Vector2(0, -32)
const GRAINE := 20260907

## Combien de secondes pour passer d'un stade au suivant. Court, parce qu'on
## teste une sensation, pas un calendrier : le vrai rythme sera en jours et se
## réglera quand la persistance existera.
const POUSSE_S := 10.0

## La journée. Trois minutes par jour au prototype ; `--jour=<secondes>` la
## raccourcit au banc, sur le modèle de `--manche=` pour les manches. Attendre
## trois minutes pour vérifier une couleur de crépuscule, personne ne le fait
## deux fois.
const JOUR_S := 180.0
const LEVER := 0.22       ## fraction de la journée où le soleil se lève
const COUCHER := 0.78

## Les teintes de la journée, du plus sombre au plus clair. Le fond n'est
## jamais noir : une nuit noire dans un jeu vu de dessus, c'est un écran vide
## et un joueur qui arrête de jouer. On descend à un bleu sourd, assez pour
## que la nuit se sente, assez clair pour qu'on voie encore ses rangs.
const NUIT := Color(0.42, 0.48, 0.78)
const AUBE := Color(0.92, 0.72, 0.62)
const PLEIN_JOUR := Color(1.0, 1.0, 1.0)
const CREPUSCULE := Color(1.0, 0.72, 0.52)

enum { FRICHE, LABOUREE, SEMEE }
enum { HOUE, GRAINES, ARROSOIR }
const OUTILS := ["Houe", "Graines", "Arrosoir"]

var _position := Vector2(304, 300)
var _corps: AnimatedSprite2D
var _camera: Camera2D
var _outil := HOUE
var _obstacles: Array[Rect2] = []
var _parcelles: Dictionary = {}
var _recoltes := 0
var _marche := false
var _heure := 0.30                        ## position dans la journée, de 0 à 1
var _duree_jour := JOUR_S
var _teinte: CanvasModulate
var _jour := 1

var _hud_outil: Label
var _hud_compte: Label
var _hud_heure: Label
var _hud_aide: Label

func demarrer() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 9.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(MONDE.x)
	_camera.limit_bottom = int(MONDE.y)
	add_child(_camera)
	_camera.make_current()

	for a in OS.get_cmdline_args():
		if a.begins_with("--jour="):
			_duree_jour = maxf(4.0, float(a.substr(7)))

	# La teinte du jour s'applique au PLAN, pas à l'écran : l'interface vit
	# dans une CanvasLayer et doit rester lisible à minuit comme à midi.
	_teinte = CanvasModulate.new()
	plan().add_child(_teinte)

	var sol := Terrain.nappe(int(MONDE.x), int(MONDE.y), Terrain.HERBE, GRAINE)
	sol.z_index = -100
	sol.y_sort_enabled = false
	plan().add_child(sol)

	_planter_le_tour()
	_semer_les_premiers_rangs()

	_corps = AnimatedSprite2D.new()
	_corps.sprite_frames = Pixels.heros(Pixels.heros_de(Session.id))
	_corps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_corps.offset = PIEDS
	_corps.add_child(Terrain.ombre())
	_corps.play("repos")
	plan().add_child(_corps)

	Tactile.mode = Tactile.MARCHE
	Tactile.action.connect(_agir)
	_construire_hud()
	_camera.position = _position
	_camera.reset_smoothing()

func _exit_tree() -> void:
	if Tactile.action.is_connected(_agir):
		Tactile.action.disconnect(_agir)

# ----------------------------------------------------------------- le décor

## Une lisière d'arbres et de rochers ferme la ferme. Comme au village : un mur
## invisible arrête sans expliquer, une rangée d'arbres se comprend.
func _planter_le_tour() -> void:
	var tirage := RandomNumberGenerator.new()
	tirage.seed = GRAINE
	var champ := Rect2(Vector2(CHAMP.position) * CASE, Vector2(CHAMP.size) * CASE).grow(24.0)
	for i in 150:
		var p := Vector2(tirage.randf_range(8, MONDE.x - 8), tirage.randf_range(48, MONDE.y - 8))
		var au_bord := p.x < 90.0 or p.x > MONDE.x - 90.0 or p.y < 110.0 or p.y > MONDE.y - 60.0
		if champ.has_point(p) or not au_bord:
			continue
		var tir := tirage.randf()
		if tir < 0.40:
			_poser("arbre_%d.png" % tirage.randi_range(0, 2), p, Rect2(-8, -6, 16, 8))
		elif tir < 0.62:
			_poser("pin_%d.png" % tirage.randi_range(0, 2), p, Rect2(-8, -6, 16, 8))
		elif tir < 0.80:
			_poser("buisson_%d.png" % tirage.randi_range(0, 3), p, Rect2())
		elif tir < 0.90:
			_poser("buisson_petit_%d.png" % tirage.randi_range(0, 3), p, Rect2())
		elif tir < 0.96:
			_poser("rocher_moyen_%d.png" % tirage.randi_range(0, 1), p, Rect2(-8, -5, 16, 7))
		else:
			_poser("rocher_petit_%d.png" % tirage.randi_range(0, 1), p, Rect2())

func _poser(image: String, position: Vector2, blocage: Rect2) -> void:
	var sprite := Pixels.image(IMAGES + image)
	Pixels.poser(sprite, position)
	plan().add_child(sprite)
	if blocage.size != Vector2.ZERO:
		_obstacles.append(Rect2(position.round() + blocage.position, blocage.size))

## La ferme n'est pas vierge : trois rangs sont déjà en terre. Un champ nu ne
## montre rien de la boucle à qui arrive, et n'apprend pas à quoi ressemble
## une parcelle qui a soif.
func _semer_les_premiers_rangs() -> void:
	for x in range(CHAMP.position.x, CHAMP.position.x + 9):
		for y in range(CHAMP.position.y, CHAMP.position.y + 3):
			var case := Vector2i(x, y)
			_travailler(case, LABOUREE)
			if x % 3 != 2:
				_semer(case)
				_parcelles[case]["stade"] = (x + y) % 3
				_parcelles[case]["arrosee"] = y != CHAMP.position.y + 1
				_redessiner(case)

# --------------------------------------------------------------- les gestes

func _case_sous_les_pieds() -> Vector2i:
	return Vector2i(int(floor(_position.x / CASE)), int(floor(_position.y / CASE)))

func _agir() -> void:
	var case := _case_sous_les_pieds()
	if not CHAMP.has_point(case):
		return
	var fiche: Dictionary = _parcelles.get(case, {})
	var etat: int = int(fiche.get("etat", FRICHE))
	match _outil:
		HOUE:
			if etat == FRICHE:
				_travailler(case, LABOUREE)
				Sons.jouer("clic", 0.8, -14.0)
			elif etat == SEMEE and int(fiche.get("stade", 0)) >= 2:
				_recolter(case)
		GRAINES:
			if etat == LABOUREE:
				_semer(case)
				Sons.jouer("clic", 1.4, -16.0)
		ARROSOIR:
			if etat != FRICHE and not bool(fiche.get("arrosee", false)):
				fiche["arrosee"] = true
				_redessiner(case)
				Sons.jouer("bip", 0.7, -18.0)
	_rafraichir_hud()

func _travailler(case: Vector2i, etat: int) -> void:
	if not _parcelles.has(case):
		_parcelles[case] = {"etat": FRICHE, "arrosee": false, "stade": 0, "seve": 0.0,
			"sol": null, "plante": null}
	_parcelles[case]["etat"] = etat
	_redessiner(case)

func _semer(case: Vector2i) -> void:
	var fiche: Dictionary = _parcelles[case]
	fiche["etat"] = SEMEE
	fiche["stade"] = 0
	fiche["seve"] = 0.0
	_redessiner(case)

## Récolter rend la parcelle labourée, pas en friche : on ne repasse pas la
## houe entre deux saisons, et enchaîner deux récoltes doit rester fluide.
func _recolter(case: Vector2i) -> void:
	var fiche: Dictionary = _parcelles[case]
	fiche["etat"] = LABOUREE
	fiche["arrosee"] = false
	_recoltes += 1
	Sons.jouer("depart", 1.3, -14.0)
	_redessiner(case)

## Un plant n'avance que sur une terre arrosée, et boit son eau en poussant.
## C'est ce qui fait revenir le joueur sur ses rangs au lieu de semer partout
## et d'attendre.
func _faire_pousser(delta: float) -> void:
	for case in _parcelles:
		var fiche: Dictionary = _parcelles[case]
		if int(fiche["etat"]) != SEMEE or not bool(fiche["arrosee"]):
			continue
		if int(fiche["stade"]) >= 2:
			continue
		fiche["seve"] = float(fiche["seve"]) + delta
		if float(fiche["seve"]) >= POUSSE_S:
			fiche["seve"] = 0.0
			fiche["stade"] = int(fiche["stade"]) + 1
			fiche["arrosee"] = false
			_redessiner(case)

# ----------------------------------------------------------------- le rendu

func _redessiner(case: Vector2i) -> void:
	var fiche: Dictionary = _parcelles[case]
	var coin := Vector2(case) * CASE
	var sol = fiche.get("sol")
	if sol:
		(sol as Node).queue_free()
		fiche["sol"] = null
	if int(fiche["etat"]) != FRICHE:
		var terre := Terrain.parcelle(CASE, GRAINE + case.x * 31 + case.y * 17,
			bool(fiche["arrosee"]))
		terre.position = coin
		# Le sol reste sous tout le monde : à plat, il n'a pas à entrer dans le
		# tri par profondeur, sinon il passe devant un joueur situé plus haut.
		terre.z_index = -50
		terre.y_sort_enabled = false
		plan().add_child(terre)
		fiche["sol"] = terre
	var plante = fiche.get("plante")
	if plante:
		(plante as Node).queue_free()
		fiche["plante"] = null
	if int(fiche["etat"]) == SEMEE:
		var pousse := Terrain.plant(int(fiche["stade"]))
		# Ancré au bas de la case : le plant est trié en profondeur comme un
		# personnage, donc on passe devant les rangs du bas et derrière ceux
		# du haut.
		Pixels.poser(pousse, coin + Vector2(CASE * 0.5, CASE - 2))
		plan().add_child(pousse)
		fiche["plante"] = pousse

func _process(delta: float) -> void:
	var direction := Commandes.direction()
	if direction != Vector2.ZERO:
		var avant := _position
		_position.x += direction.x * VITESSE * delta
		_degager(avant)
		avant = _position
		_position.y += direction.y * VITESSE * delta
		_degager(avant)
		_position.x = clampf(_position.x, 16.0, MONDE.x - 16.0)
		_position.y = clampf(_position.y, 48.0, MONDE.y - 16.0)
		# Les héros du pack sont dessinés de profil : on ne retourne le sprite
		# que sur un pas horizontal.
		if direction.x != 0.0:
			_corps.flip_h = direction.x < 0.0
		_marche = true
	else:
		_marche = false

	var animation := "marche" if _marche else "repos"
	if _corps.animation != animation:
		_corps.play(animation)
	Pixels.poser(_corps, _position)
	_camera.position = _position
	_faire_pousser(delta)
	_avancer_l_heure(delta)
	_rafraichir_hud()

## Le temps passe, la lumière tourne. Quatre teintes suffisent : la nuit,
## l'aube, le plein jour, le crépuscule — interpolées, elles donnent une
## journée entière sans qu'on ait à écrire une courbe.
func _avancer_l_heure(delta: float) -> void:
	_heure += delta / _duree_jour
	while _heure >= 1.0:
		_heure -= 1.0
		_jour += 1
	_teinte.color = _lumiere(_heure)

func _lumiere(heure: float) -> Color:
	if heure < LEVER - 0.06:
		return NUIT
	if heure < LEVER + 0.06:
		var t := (heure - (LEVER - 0.06)) / 0.12
		return NUIT.lerp(AUBE, t) if t < 0.5 else AUBE.lerp(PLEIN_JOUR, (t - 0.5) * 2.0)
	if heure < COUCHER - 0.08:
		return PLEIN_JOUR
	if heure < COUCHER + 0.08:
		var t := (heure - (COUCHER - 0.08)) / 0.16
		return PLEIN_JOUR.lerp(CREPUSCULE, t) if t < 0.5 else CREPUSCULE.lerp(NUIT, (t - 0.5) * 2.0)
	return NUIT

func _degager(avant: Vector2) -> void:
	var pieds := Rect2(_position - Vector2(RAYON, 5), Vector2(RAYON * 2.0, 8))
	for obstacle in _obstacles:
		if obstacle.intersects(pieds):
			_position = avant
			return

# ------------------------------------------------------------- les commandes

func _unhandled_input(evenement: InputEvent) -> void:
	if not (evenement is InputEventKey and evenement.pressed and not evenement.echo):
		return
	match (evenement as InputEventKey).keycode:
		KEY_E: _agir()
		KEY_TAB: _changer_outil((_outil + 1) % OUTILS.size())
		KEY_1: _changer_outil(HOUE)
		KEY_2: _changer_outil(GRAINES)
		KEY_3: _changer_outil(ARROSOIR)
		KEY_ESCAPE: demande_ecran.emit("hub", {})

func _changer_outil(outil: int) -> void:
	_outil = outil
	Sons.jouer("clic", 1.0, -20.0)
	_rafraichir_hud()

func _construire_hud() -> void:
	var couche := interface()
	var haut := HBoxContainer.new()
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 20
	haut.offset_right = -20
	haut.offset_top = 16
	haut.add_theme_constant_override("separation", 24)
	couche.add_child(haut)
	_hud_outil = UI.titre("", 20)
	haut.add_child(_hud_outil)
	_hud_compte = UI.texte("", 15, Palette.ENCRE_DOUCE)
	_hud_compte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(_hud_compte)
	_hud_heure = UI.texte("", 15, Palette.ENCRE)
	haut.add_child(_hud_heure)

	var bas := VBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = 20
	bas.offset_right = -20
	bas.offset_top = -56
	bas.offset_bottom = -18
	couche.add_child(bas)
	_hud_aide = UI.texte("", 14, Palette.ENCRE_FAIBLE)
	bas.add_child(_hud_aide)
	_rafraichir_hud()

func _rafraichir_hud() -> void:
	if _hud_outil == null:
		return
	_hud_outil.text = "En main : " + String(OUTILS[_outil])
	var semees := 0
	var seches := 0
	var mures := 0
	for case in _parcelles:
		var fiche: Dictionary = _parcelles[case]
		if int(fiche["etat"]) != SEMEE:
			continue
		semees += 1
		if int(fiche["stade"]) >= 2:
			mures += 1
		elif not bool(fiche["arrosee"]):
			seches += 1
	# La couleur ne porte jamais seule le sens : on écrit le compte.
	_hud_compte.text = "%d plants  ·  %d à arroser  ·  %d mûrs  ·  %d récoltés" % [
		semees, seches, mures, _recoltes]
	# L'heure du jeu, pas celle de la machine : minuit est au tiers de la
	# journée, et le lever à 6 h par convention.
	var minutes := int(_heure * 1440.0)
	_hud_heure.text = "Jour %d  ·  %02dh%02d" % [_jour, (minutes / 60) % 24, minutes % 60]
	_hud_aide.text = "Z Q S D pour marcher · 1 houe, 2 graines, 3 arrosoir (ou Tab) · E agit sur la case sous vos pieds · Échap revient au village."
