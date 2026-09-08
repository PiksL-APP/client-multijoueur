extends Partie
## BOUSCULADE — une île qui flotte, des joueurs qui se poussent, et le vide
## autour. Le dernier debout n'existe pas vraiment : on tombe, on est repêché
## au centre trois secondes plus tard, et celui qui vous a poussé a marqué.
##
## Règles : Z Q S D pour courir, ESPACE pour charger — un coup de boule qui
## envoie l'autre valser. L'île s'effrite par le bord, anneau après anneau :
## à la fin il reste un disque de quatre unités, et plus personne ne peut se
## cacher. Cent points par joueur envoyé dans le vide, deux points par
## seconde passée debout.
##
## Autorité : chacun simule SON personnage — ses pas, la charge, la poussée
## qu'il reçoit d'un autre, sa chute. L'hôte ne fait que compter les points
## et faire tomber les anneaux (par l'horloge de la manche, la même pour
## tous). Une poussée est donc vue deux fois — une fois par celui qui la
## donne, une fois par celui qui la reçoit — mais chacun ne déplace que soi.

const DUREE := 90.0
const RAYON_ILE := 8.0             ## unités ; l'île du départ
const RAYON_FINAL := 3.0
const DEBUT_EFFRITEMENT := 10.0    ## secondes de répit avant le premier anneau
const PAS_EFFRITEMENT := 9.0       ## secondes entre deux anneaux
const RAYON := 0.45                ## demi-largeur d'un pantin
const VITESSE := 5.5
const ACCEL := 40.0
const FROTTEMENT := 7.0
const CHARGE_VITESSE := 15.0
const CHARGE_DUREE := 0.22
const CHARGE_RECHARGE := 1.3
const POUSSEE_CHARGE := 13.0
const POUSSEE_CONTACT := 3.0
const REPECHAGE := 3.0
const CADENCE_ENVOI := 1.0 / 12.0
const INCLINAISON := 56.0
const DISTANCE := 23.0

var _p := Vector2.ZERO             ## ma position, en unités, l'île centrée en 0
var _v := Vector2.ZERO             ## ma vitesse (poussées comprises)
var _regard := Vector2(0, 1)
var _charge := 0.0                 ## secondes de charge restantes
var _recharge := 0.0
var _vivant := true
var _repechage := 0.0
var _dernier_coup := {"cle": "", "t": -99.0}
var _tir_avant := false
var _autres: Dictionary = {}       ## cle -> {p, cible, charge, vivant, noeud, halo}
var _depuis_envoi := 0.0
var _survie := 0.0
var _corps: Pantin
var _halo: MeshInstance3D
var _anneaux: Array[MeshInstance3D] = []
var _anneaux_tombes := 0
var _camera: Camera3D
var _poussiere: CPUParticles3D
var _maquette: Maquette
var _chutes := 0
var _victimes := 0

func duree_manche() -> float:
	return DUREE

func aide() -> String:
	return "Z Q S D · ESPACE : charger · 100 points par joueur poussé dans le vide, 2 par seconde debout."

func etat_joueur() -> String:
	if not _vivant:
		return "Dans le vide… repêchage dans %d s" % int(ceil(_repechage))
	if _recharge > 0.0:
		return "Charge dans %.1f s · %d chute%s · %d poussé%s" % [_recharge, _chutes, "s" if _chutes > 1 else "", _victimes, "s" if _victimes > 1 else ""]
	return "Charge prête (ESPACE) · %d chute%s · %d poussé%s" % [_chutes, "s" if _chutes > 1 else "", _victimes, "s" if _victimes > 1 else ""]

# ------------------------------------------------------- la scène

func preparer() -> void:
	Tactile.mode = Tactile.MARCHE
	_maquette = Maquette.poser(self, 0.52, 5.0)
	_eclairer()
	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.near = 0.5
	_camera.far = 300.0
	var incl := deg_to_rad(INCLINAISON)
	_camera.position = Vector3(0, sin(incl) * DISTANCE, cos(incl) * DISTANCE + 1.0)
	_camera.rotation_degrees = Vector3(-INCLINAISON, 0, 0)
	monde().add_child(_camera)
	_camera.make_current()

	# L'île : onze anneaux qui tomberont un à un, et le pavage du centre.
	for i in int(RAYON_ILE):
		var anneau := MeshInstance3D.new()
		anneau.mesh = Decor.maillage(Pantin.MODELES + "arene_%d.glb" % i)
		monde().add_child(anneau)
		_anneaux.append(anneau)
	var centre := MeshInstance3D.new()
	centre.mesh = Decor.maillage(Pantin.MODELES + "arene_centre.glb")
	centre.position.y = 0.01
	monde().add_child(centre)
	# Quelques îlots au loin, pour que le vide ait une profondeur.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	for i in 10:
		var ilot := MeshInstance3D.new()
		ilot.mesh = Decor.maillage(Pantin.MODELES + "ilot_%d.glb" % (i % 3))
		var angle := hasard.randf_range(0.0, TAU)
		var loin := hasard.randf_range(19.0, 36.0)
		ilot.position = Vector3(cos(angle) * loin, hasard.randf_range(-20.0, -8.0), sin(angle) * loin * 0.7 - 5.0)
		ilot.scale = Vector3.ONE * hasard.randf_range(0.5, 0.9)
		monde().add_child(ilot)
		var arbre := MeshInstance3D.new()
		arbre.mesh = Decor.maillage(Pantin.MODELES + ["arbre_0", "pin_1", "arbre_2", "grand_pin_0"][i % 4] + ".glb")
		arbre.position = ilot.position + Vector3(hasard.randf_range(-0.8, 0.8), 0, hasard.randf_range(-0.8, 0.8))
		arbre.scale = ilot.scale
		monde().add_child(arbre)

	_corps = _batir_pantin(Session.cle)
	_corps.position = Vector3.ZERO
	monde().add_child(_corps)
	_halo = _halo_pour(Session.cle)
	_poussiere = _faire_poussiere()
	monde().add_child(_poussiere)
	_p = _depart(ma_place())

## Chacun part sur son rayon, à mi-chemin du bord, face au centre.
func _depart(place: int) -> Vector2:
	var angle := place * TAU / 4.0 + PI / 4.0
	return Vector2(cos(angle), sin(angle)) * 4.5

func _eclairer() -> void:
	var environnement := Environment.new()
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#2a66c6")
	ciel.sky_horizon_color = Color("#a9c8e8")
	ciel.ground_bottom_color = Color("#4f7aa6")
	ciel.ground_horizon_color = Color("#8fb4d8")
	var voute := Sky.new()
	voute.sky_material = ciel
	environnement.background_mode = Environment.BG_SKY
	environnement.sky = voute
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environnement.ambient_light_energy = 0.45
	environnement.fog_enabled = true
	environnement.fog_light_color = Color("#d5e6f5")
	environnement.fog_density = 0.0008
	environnement.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environnement.tonemap_white = 4.0
	environnement.glow_enabled = true
	environnement.glow_intensity = 0.3
	var noeud := WorldEnvironment.new()
	noeud.environment = environnement
	monde().add_child(noeud)
	var soleil := DirectionalLight3D.new()
	soleil.light_color = Color("#fff3df")
	soleil.light_energy = 1.5
	soleil.rotation_degrees = Vector3(-58, -34, 0)
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 48.0
	soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	soleil.shadow_bias = 0.8
	soleil.shadow_normal_bias = 6.0
	soleil.shadow_blur = 1.6
	monde().add_child(soleil)
	var contre := DirectionalLight3D.new()
	contre.light_color = Color("#9fb8e0")
	contre.light_energy = 0.35
	contre.rotation_degrees = Vector3(-30, 140, 0)
	monde().add_child(contre)

## Le pantin d'un joueur : son héros, son nom, et un anneau à sa couleur
## sous les pieds — c'est l'anneau qu'on suit dans la mêlée.
func _batir_pantin(cle: String) -> Pantin:
	var fiche: Dictionary = joueurs.get(cle, {})
	var heros := String(fiche.get("heros", ""))
	if heros == "" and cle == Session.cle:
		heros = Session.heros_affiche()
	if not heros in ["knight", "rogue", "wizzard"]:
		heros = Pixels.heros_de(String(fiche.get("id", cle)))
	var pantin := Pantin.depuis(Pantin.MODELES + "heros_%s.glb" % heros)
	var couleur := Palette.couleur_joueur(int(fiche.get("place", 0)))
	var nom := Label3D.new()
	nom.name = "nom"
	nom.text = String(fiche.get("pseudo", Session.pseudo if cle == Session.cle else "?"))
	nom.font = UI.TITRE_POLICE
	nom.font_size = 32
	nom.pixel_size = 0.22 / 32.0
	nom.modulate = couleur.lightened(0.4)
	nom.outline_modulate = Color(0, 0, 0, 0.9)
	nom.outline_size = 8
	nom.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nom.no_depth_test = true
	nom.position = Vector3(0, 2.8, 0)
	pantin.add_child(nom)
	return pantin

## L'anneau de couleur sous les pieds : à part du pantin, qui se penche.
func _halo_pour(cle: String) -> MeshInstance3D:
	var couleur := Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 0)))
	var halo := Decor.anneau(RAYON * 1.6, 0.12, couleur, 1.1)
	halo.rotation_degrees = Vector3(90, 0, 0)
	monde().add_child(halo)
	return halo

func _faire_poussiere() -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 24
	f.lifetime = 0.5
	f.one_shot = false
	f.emitting = false
	f.explosiveness = 0.9
	f.direction = Vector3.UP
	f.spread = 70.0
	f.gravity = Vector3(0, -3.0, 0)
	f.initial_velocity_min = 1.5
	f.initial_velocity_max = 3.5
	f.scale_amount_min = 0.6
	f.scale_amount_max = 1.2
	var cube := BoxMesh.new()
	cube.size = Vector3(0.18, 0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.78, 0.6)
	cube.material = m
	f.mesh = cube
	return f

# ------------------------------------------------------- simulation

## Le rayon de l'île à un instant de la manche, le même chez tous.
func _rayon_ile(t: float) -> float:
	if t < DEBUT_EFFRITEMENT:
		return RAYON_ILE
	var tombes: float = floor((t - DEBUT_EFFRITEMENT) / PAS_EFFRITEMENT) + 1.0
	return maxf(RAYON_FINAL, RAYON_ILE - tombes)

func simuler_local(delta: float) -> void:
	_recharge = maxf(0.0, _recharge - delta)
	if _vivant:
		var direction := Commandes.direction()
		if direction != Vector2.ZERO:
			_regard = direction.normalized()
		var tir := Commandes.tir()
		if tir and not _tir_avant and _recharge <= 0.0 and _charge <= 0.0:
			_charge = CHARGE_DUREE
			_recharge = CHARGE_RECHARGE
			_v = _regard * CHARGE_VITESSE
			Sons.jouer("voix_grognement", 1.0, -9.0)
		_tir_avant = tir
		if _charge > 0.0:
			_charge -= delta
		else:
			var voulue := direction * VITESSE
			_v = _v.move_toward(voulue, ACCEL * delta) if direction != Vector2.ZERO else _v.move_toward(Vector2.ZERO, FROTTEMENT * delta)
		_bousculer()
		_p += _v * delta
		if _p.length() > _rayon_ile(temps) + 0.35:
			_tomber()
	else:
		_repechage -= delta
		if _repechage <= 0.0:
			_vivant = true
			_p = Vector2.ZERO
			_v = Vector2.ZERO
			_charge = 0.0
			Sons.jouer("bip", 1.4, -12.0)

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["p"] = (a["p"] as Vector2).lerp(a["cible"], clampf(delta * 14.0, 0.0, 1.0))

	_depuis_envoi += delta
	if _depuis_envoi >= CADENCE_ENVOI:
		_depuis_envoi = 0.0
		canal.envoyer("p", {"x": int(round(_p.x * 100.0)), "y": int(round(_p.y * 100.0)),
			"c": 1 if _charge > 0.0 else 0, "v": 1 if _vivant else 0})

## Les contacts avec les autres : on se sépare, et on encaisse la poussée.
## Une charge adverse pousse fort ; un simple contact, un peu ; sa propre
## charge recule d'un cran.
func _bousculer() -> void:
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		if not bool(a["vivant"]):
			continue
		var q: Vector2 = a["p"]
		var ecart := _p - q
		var d := ecart.length()
		if d >= RAYON * 2.0 or d == 0.0:
			continue
		var n := ecart / d
		_p += n * (RAYON * 2.0 - d) * 0.5
		if bool(a["charge"]):
			_v += n * POUSSEE_CHARGE
			_dernier_coup = {"cle": cle, "t": temps}
			Sons.jouer("coup_poing", randf_range(0.9, 1.15), -5.0)
			_poussiere.position = Vector3(_p.x, 0.2, _p.y)
			_poussiere.restart()
		elif _charge > 0.0:
			_v -= n * 2.0
		else:
			_v += n * POUSSEE_CONTACT

func _tomber() -> void:
	_vivant = false
	_repechage = REPECHAGE
	_chutes += 1
	Sons.jouer("voix_cri", randf_range(0.9, 1.1), -6.0)
	var par := String(_dernier_coup["cle"]) if temps - float(_dernier_coup["t"]) < 2.5 else ""
	_dernier_coup = {"cle": "", "t": -99.0}
	canal.envoyer("chute", {"par": par})
	if est_hote():
		_crediter(Session.cle, par)

## L'hôte compte : cent points à qui a poussé.
func _crediter(victime: String, par: String) -> void:
	if par != "" and par != victime and joueurs.has(par):
		ajouter_score(par, 100)
		if par == Session.cle:
			_victimes += 1
		canal.envoyer("bravo", {"j": par, "v": victime})

func simuler_hote(delta: float) -> void:
	# Deux points par seconde debout, pour tous ceux qui sont sur l'île.
	_survie += delta
	if _survie >= 1.0:
		_survie -= 1.0
		if _vivant:
			ajouter_score(Session.cle, 2)
		for cle in _autres:
			if bool(_autres[cle]["vivant"]):
				ajouter_score(cle, 2)

func recevoir(evenement: String, charge: Dictionary) -> void:
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.cle:
		return
	match evenement:
		"p":
			var cible := Vector2(float(charge.get("x", 0)) / 100.0, float(charge.get("y", 0)) / 100.0)
			if not _autres.has(cle):
				_autres[cle] = {"p": cible, "cible": cible, "charge": false, "vivant": true, "noeud": null}
			var a: Dictionary = _autres[cle]
			a["cible"] = cible
			a["charge"] = int(charge.get("c", 0)) == 1
			var vivant := int(charge.get("v", 1)) == 1
			if vivant and not bool(a["vivant"]):
				a["p"] = cible
			a["vivant"] = vivant
		"chute":
			if est_hote():
				_crediter(cle, String(charge.get("par", "")))
		"bravo":
			if String(charge.get("j", "")) == Session.cle:
				_victimes += 1
				Sons.jouer("clic", 1.5, -8.0)

# ------------------------------------------------------- rendu

func rafraichir_scene(delta: float) -> void:
	_corps.position = Vector3(_p.x, 0.0 if _vivant else -14.0 * (1.0 - _repechage / REPECHAGE), _p.y)
	_corps.visible = _vivant or _repechage > REPECHAGE * 0.5
	_corps.marche = _vivant and _v.length() > 0.8
	_corps.regarder(_regard if _vivant else Vector2.ZERO)
	_corps.penche = 0.55 if _charge > 0.0 else 0.0
	_halo.visible = _vivant
	_halo.position = Vector3(_p.x, 0.04, _p.y)
	# La netteté suit le joueur, mais au SOL : tombé dans le vide, il
	# entraînerait la mise au point avec lui jusqu'en bas de l'écran.
	if _maquette:
		var haut := get_viewport().get_visible_rect().size.y
		if haut > 1.0:
			_maquette.viser(_camera.unproject_position(Vector3(_p.x, 0.9, _p.y)).y / haut)

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var noeud = a.get("noeud")
		if noeud == null:
			noeud = _batir_pantin(cle)
			monde().add_child(noeud)
			a["noeud"] = noeud
			a["avant"] = a["p"]
			a["halo"] = _halo_pour(cle)
		var pantin := noeud as Pantin
		var q: Vector2 = a["p"]
		var pas: Vector2 = q - (a["avant"] as Vector2)
		a["avant"] = q
		pantin.position = Vector3(q.x, 0.0 if bool(a["vivant"]) else -6.0, q.y)
		pantin.visible = bool(a["vivant"])
		(a["halo"] as Node3D).visible = bool(a["vivant"])
		(a["halo"] as Node3D).position = Vector3(q.x, 0.04, q.y)
		pantin.marche = pas.length() > 0.02
		if pas.length() > 0.02:
			pantin.regarder(pas)
		pantin.penche = 0.55 if bool(a["charge"]) else 0.0

	# Les anneaux tombent par l'horloge de la manche : au même instant partout.
	var rayon := _rayon_ile(temps) if phase == JEU else RAYON_ILE
	var a_tomber := int(RAYON_ILE - rayon)
	while _anneaux_tombes < a_tomber and _anneaux_tombes < _anneaux.size():
		var anneau := _anneaux[_anneaux.size() - 1 - _anneaux_tombes]
		_anneaux_tombes += 1
		Sons.jouer("bip", 0.4, -10.0)
		var tween := create_tween()
		tween.tween_property(anneau, "position:y", -0.6, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(anneau, "position:y", -60.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(anneau.queue_free)
	# Le prochain anneau à tomber tremble deux secondes avant.
	if phase == JEU and _anneaux_tombes < _anneaux.size() and rayon > RAYON_FINAL:
		var prochain := _anneaux[_anneaux.size() - 1 - _anneaux_tombes]
		var reste := DEBUT_EFFRITEMENT + _anneaux_tombes * PAS_EFFRITEMENT - temps
		prochain.position.x = sin(Time.get_ticks_msec() * 0.05) * 0.06 if reste < 2.0 else 0.0
