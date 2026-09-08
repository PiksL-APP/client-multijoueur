extends Ecran
## LA FERME — prototype du jalon J0 de la nouvelle ÉNIGME.
##
## On laboure, on sème, on arrose, on dort, ça pousse. Rien d'autre pour
## l'instant : ni réseau, ni persistance, ni chambres de test. Cette étape
## répond à une seule question, celle qu'aucun document ne tranche — est-ce que
## cette boucle est agréable à la manette ? Y brancher Supabase avant de le
## savoir, ce serait payer la persistance d'un jeu qu'on jetterait.
##
## ⚠ RIEN NE POUSSE PENDANT LA JOURNÉE. Un plant n'avance que dans la nuit,
## et seulement si sa terre était arrosée le soir. C'est ce qui donne son
## rythme au genre : la journée est un budget qu'on dépense, la nuit est
## l'arbitre. Une pousse au chronomètre ferait de l'arrosoir une décoration.
##
## Tout le décor sort du pack du village, et le sol de couleurs relevées dans
## ses fichiers (`commun/terrain.gd`) : on passe du village à la ferme par une
## porte, les deux doivent se ressembler.

const MONDE := Vector2(768, 544)
const CASE := 32
const CHAMP := Rect2i(9, 6, 12, 7)        ## la zone cultivable, en cases — à droite de la grange
const VITESSE := 96.0
const RAYON := 6.0
const ZOOM := 3
const IMAGES := "res://modeles/village/"
const PIEDS := Vector2(0, -32)
const GRAINE := 20260907

## La journée. `--jour=<secondes>` la raccourcit au banc, sur le modèle de
## `--manche=`. Attendre trois minutes pour vérifier une couleur de crépuscule,
## personne ne le fait deux fois.
const JOUR_S := 180.0
const LEVER := 0.22
const COUCHER := 0.78

const NUIT := Color(0.42, 0.48, 0.78)
const AUBE := Color(0.92, 0.72, 0.62)
const PLEIN_JOUR := Color(1.0, 1.0, 1.0)
const CREPUSCULE := Color(1.0, 0.72, 0.52)

## L'énergie : le vrai frein du genre. Sans elle on laboure le champ entier le
## premier jour et il ne reste plus rien à faire. Les coûts sont réglés pour
## qu'une journée pleine tienne en une trentaine de gestes.
const ENERGIE_MAX := 100
const COUT := {"labour": 6, "semis": 2, "arrosage": 3, "recolte": 2}

## La grange : on y dort. Le seuil est DEVANT la porte, pas dans le bâtiment —
## le sprite est un bloc plein, et se tenir « dedans » consisterait à marcher
## sur ses murs.
const GRANGE := Vector2(112, 240)
const LIT := Rect2(70, 242, 84, 26)

enum { FRICHE, LABOUREE, SEMEE }
enum { HOUE, GRAINES, ARROSOIR }
const OUTILS := ["Houe", "Graines", "Arrosoir"]

var _position := Vector2(420, 300)
var _corps: AnimatedSprite2D
var _camera: Camera2D
var _teinte: CanvasModulate
var _curseur: Sprite2D
var _outil := HOUE
var _culture := 0
var _obstacles: Array[Rect2] = []
var _parcelles: Dictionary = {}
var _recoltes := 0
var _brins: Dictionary = {}               ## case -> brins d'herbe posés dessus
var _cageots: int = 0                     ## cageots posés devant la grange
var _cageots_noeuds: Array = []
var _a_vendre: int = 0                    ## valeur des cageots en attente
var _pieces := PIECES_DEPART
var _voile: ColorRect                     ## le noir du sommeil
var _lumiere_feu: PointLight2D
var _lanterne: PointLight2D
var _scintille := 0.0
var _voile_texte: Label
var _endormi := false

## Les couleurs des éclats de chaque geste, prises dans le pack : terre du
## bois, eau de la mare du village, or des récoltes.
const ECLAT := {
	"labour": [Color8(0x7d, 0x4c, 0x28), Color8(0x5a, 0x36, 0x1e)],
	"semis": [Color8(0x95, 0xc5, 0x14), Color8(0x49, 0x82, 0x11)],
	"arrosage": [Color8(0x5a, 0xa8, 0xe0), Color8(0xbf, 0xe6, 0xff)],
	"recolte": [Color8(0xfa, 0xb2, 0x19), Color8(0xff, 0xf3, 0xc0)],
}
## Les cultures. `nuits` : combien de nuits arrosées pour arriver à maturité ;
## `graine` : le prix du sachet ; `prix` : ce que rapporte le cageot.
##
## Les écarts font le jeu. Le radis est rapide et rapporte peu, le chou est
## lent et rapporte beaucoup : semer l'un ou l'autre est un choix, et un champ
## de radis n'est pas un champ de choux. Sans ça, changer de graine est une
## question de couleur.
const FICHES := {
	"radis":    {"nuits": 2, "graine": 2, "prix": 5},
	"carottes": {"nuits": 3, "graine": 3, "prix": 9},
	"laitues":  {"nuits": 3, "graine": 3, "prix": 8},
	"choux":    {"nuits": 4, "graine": 5, "prix": 15},
}
const PIECES_DEPART := 20

## Où s'empilent les cageots : à droite de la grange, quatre par rangée.
const CAGEOTS := Vector2(184, 236)
const CAGEOTS_PAR_RANG := 4
const CAGEOTS_MAX := 12
var _marche := false
var _energie := ENERGIE_MAX
var _heure := 0.26
var _duree_jour := JOUR_S
var _jour := 1
var _message := ""
var _depuis_message := 0.0

var _hud_outil: Label
var _hud_compte: Label
var _hud_heure: Label
var _hud_energie: Label
var _hud_pieces: Label
var _hud_jauge: ColorRect
var _hud_aide: Label
var _hud_message: Label

func demarrer() -> void:
	# Réglages de banc, sur le modèle de `--lieu=` : `--jour=<s>` raccourcit la
	# journée, `--heure=<0..1>` la commence où l'on veut, `--depart=x,y` pose le
	# personnage. Photographier le feu à minuit sans ces trois-là demanderait
	# d'attendre et de marcher, et personne ne le fait avant chaque livraison.
	for a in OS.get_cmdline_args():
		if a.begins_with("--jour="):
			_duree_jour = maxf(4.0, float(a.substr(7)))
		elif a.begins_with("--heure="):
			_heure = clampf(float(a.substr(8)), 0.0, 0.999)
		elif a.begins_with("--depart="):
			var xy := a.substr(9).split(",")
			if xy.size() == 2:
				_position = Vector2(float(xy[0]), float(xy[1]))

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

	# La teinte du jour s'applique au PLAN, pas à l'écran : l'interface vit
	# dans une CanvasLayer et doit rester lisible à minuit comme à midi.
	_teinte = CanvasModulate.new()
	plan().add_child(_teinte)

	var sol := Terrain.nappe(int(MONDE.x), int(MONDE.y), Terrain.HERBE, GRAINE)
	sol.z_index = -100
	sol.y_sort_enabled = false
	plan().add_child(sol)

	_curseur = Terrain.curseur(CASE)
	_curseur.z_index = -40
	_curseur.y_sort_enabled = false
	plan().add_child(_curseur)

	_batir_la_ferme()
	_semer_les_premiers_rangs()

	_corps = AnimatedSprite2D.new()
	_corps.sprite_frames = Pixels.heros(Pixels.heros_de(Session.id))
	_corps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_corps.offset = PIEDS
	_corps.add_child(Terrain.ombre())
	_corps.play("repos")
	plan().add_child(_corps)
	# Une lanterne sur le joueur, pour qu'on voie ce qu'on fait après le
	# coucher du soleil — sans elle, la nuit est jouable mais on n'y voit plus
	# la différence entre une terre arrosée et une terre sèche.
	_lanterne = _lumiere(Color8(0xf4, 0xea, 0xd2), 64.0)
	_lanterne.position = Vector2(0, -14)
	_corps.add_child(_lanterne)

	Tactile.mode = Tactile.MARCHE
	Tactile.action.connect(_agir)
	_construire_hud()
	_camera.position = _position
	_camera.reset_smoothing()
	if "--demo" in OS.get_cmdline_args():
		_jouer_la_demo()

## Une journée jouée toute seule, pour le banc : `--ecran=ferme --demo
## --photo=<dossier>`. Elle laboure, sème, arrose, récolte, puis va dormir.
## C'est le seul moyen de voir les éclats, la pile de cageots et le voile de
## nuit sans tenir la manette — et donc le seul moyen de les vérifier avant
## une livraison. Le personnage est TÉLÉPORTÉ d'une étape à l'autre : on
## vérifie les gestes, pas la marche, qui l'est déjà par le hub.
func _jouer_la_demo() -> void:
	Commandes.pilote_automatique = true
	var libre := Vector2i(CHAMP.position.x + 2, CHAMP.position.y + 4)
	await _teleporter(libre)
	_changer_outil(HOUE)
	_agir()
	await get_tree().create_timer(1.4).timeout
	_changer_outil(GRAINES)
	_agir()
	await get_tree().create_timer(1.4).timeout
	_changer_outil(ARROSOIR)
	_agir()
	await get_tree().create_timer(1.6).timeout
	for case in _parcelles.keys():
		var fiche: Dictionary = _parcelles[case]
		if int(fiche["etat"]) == SEMEE and int(fiche["stade"]) >= Terrain.dernier_stade():
			await _teleporter(case)
			_agir()
			await get_tree().create_timer(1.1).timeout
	await get_tree().create_timer(1.0).timeout
	_position = LIT.get_center()
	await get_tree().create_timer(0.8).timeout
	_agir()

func _teleporter(case: Vector2i) -> void:
	_position = Vector2(case) * CASE + Vector2(CASE * 0.5, CASE * 0.75)
	await get_tree().create_timer(0.7).timeout

func _exit_tree() -> void:
	if Tactile.action.is_connected(_agir):
		Tactile.action.disconnect(_agir)

# ----------------------------------------------------------------- le décor

func _batir_la_ferme() -> void:
	var tirage := RandomNumberGenerator.new()
	tirage.seed = GRAINE
	var champ := Rect2(Vector2(CHAMP.position) * CASE, Vector2(CHAMP.size) * CASE)

	_poser("maison_grange.png", GRANGE, Rect2(-52, -26, 104, 26))
	# Un feu devant la grange : la seule chose qui bouge quand le joueur ne
	# bouge pas. Un monde immobile paraît en pause.
	var foyer := Pixels.image(IMAGES + "foyer.png")
	Pixels.poser(foyer, GRANGE + Vector2(44, 54))
	plan().add_child(foyer)
	_obstacles.append(Rect2(GRANGE + Vector2(34, 44), Vector2(20, 10)))
	var feu := AnimatedSprite2D.new()
	feu.sprite_frames = Pixels.animation("feu", IMAGES + "feu.png", 10.0, 32)
	feu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	feu.offset = Vector2(0, -24)
	feu.play("feu")
	Pixels.poser(feu, GRANGE + Vector2(44, 55))
	plan().add_child(feu)
	# Le feu ÉCLAIRE. La nuit du prototype était une teinte bleue uniforme, et
	# une nuit sans une seule source chaude est un filtre, pas une nuit. La
	# lumière se règle à zéro le jour : allumée en plein soleil, elle blanchit
	# le sol autour du foyer.
	_lumiere_feu = _lumiere(Color8(0xff, 0xc8, 0x8a), 120.0)
	_lumiere_feu.position = GRANGE + Vector2(44, 40)
	plan().add_child(_lumiere_feu)

	_poser("epouvantail.png", champ.position + Vector2(champ.size.x + 22, 18), Rect2())

	# La clôture court sur les quatre côtés du champ, avec une ouverture au
	# milieu du bas : sans passage, on saute la barrière sans s'en apercevoir
	# et la clôture ne veut plus rien dire.
	var gauche := int(champ.position.x) - 8
	var droite := int(champ.end.x) + 8
	var haut := int(champ.position.y) - 8
	var bas := int(champ.end.y) + 8
	var passage := int(champ.get_center().x)
	for x in range(gauche, droite + 1, 16):
		_poser("cloture_h.png", Vector2(x, haut), Rect2(-8, -4, 16, 5))
		if absi(x - passage) > 24:
			_poser("cloture_h.png", Vector2(x, bas), Rect2(-8, -4, 16, 5))
	# ⚠ Les montants gauche et droit sont bâtis avec `cloture_h`, pas avec
	# `cloture_v`. Ce dernier est la clôture vue par la TRANCHE : un trait noir
	# de deux pixels, juste, mais à l'écran on croit à un défaut de rendu. Comme
	# la plupart des jeux vus de dessus, on présente toutes les clôtures de
	# face — on perd la rigueur de la perspective, on gagne une clôture qu'on
	# reconnaît.
	for y in range(haut, bas + 1, 16):
		_poser("cloture_h.png", Vector2(gauche, y), Rect2(-8, -4, 16, 5))
		_poser("cloture_h.png", Vector2(droite, y), Rect2(-8, -4, 16, 5))

	# Les brins d'herbe et les fleurs du pack, semés partout sauf dans le champ :
	# une prairie fabriquée est sinon une surface unie où l'œil n'a rien où se
	# poser, et c'est ce qui trahissait le plus le sol fait à la main.
	# Ils sont posés PARTOUT, y compris dans le champ : une friche est de
	# l'herbe, elle a le droit d'avoir des fleurs. Chaque brin est retenu par
	# sa case, et le coup de houe l'arrache — sinon il flotterait sur la terre
	# retournée.
	# Semés en TOUFFES, pas un par un : une fleur tous les vingt pixels, à
	# intervalle régulier, se lit comme un motif de papier peint. Trois ou
	# quatre autour d'un même point, et c'est un pré.
	for i in 46:
		var centre := Vector2(tirage.randf_range(20, MONDE.x - 20),
			tirage.randf_range(60, MONDE.y - 20))
		var espece := tirage.randi_range(0, Terrain.DETAILS.size() - 1)
		for k in tirage.randi_range(1, 4):
			var d := centre + Vector2(tirage.randf_range(-22, 22), tirage.randf_range(-16, 16))
			if LIT.grow(16.0).has_point(d) or not Rect2(Vector2(8, 56),
					MONDE - Vector2(16, 68)).has_point(d):
				continue
			var brin := Terrain.detail(espece if tirage.randf() < 0.7 else
				tirage.randi_range(0, Terrain.DETAILS.size() - 1))
			Pixels.poser(brin, d)
			plan().add_child(brin)
			var case := Vector2i(int(floor(d.x / CASE)), int(floor(d.y / CASE)))
			if not _brins.has(case):
				_brins[case] = []
			(_brins[case] as Array).append(brin)

	# Une lisière d'arbres ferme la ferme. Comme au village : un mur invisible
	# arrête sans expliquer, une rangée d'arbres se comprend.
	var interdit := champ.grow(40.0)
	for i in 160:
		var p := Vector2(tirage.randf_range(8, MONDE.x - 8), tirage.randf_range(52, MONDE.y - 8))
		if interdit.has_point(p) or LIT.grow(40.0).has_point(p):
			continue
		if not (p.x < 96.0 or p.x > MONDE.x - 80.0 or p.y < 108.0 or p.y > MONDE.y - 56.0):
			continue
		var tir := tirage.randf()
		if tir < 0.34:
			_poser("arbre_%d.png" % tirage.randi_range(0, 2), p, Rect2(-8, -6, 16, 8))
		elif tir < 0.58:
			_poser("pin_%d.png" % tirage.randi_range(0, 2), p, Rect2(-8, -6, 16, 8))
		elif tir < 0.78:
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

## La ferme n'est pas vierge : deux rangs sont déjà en terre. Un champ nu
## n'apprend rien de la boucle à qui arrive, et ne montre pas à quoi ressemble
## une parcelle qui a soif.
func _semer_les_premiers_rangs() -> void:
	for x in range(CHAMP.position.x, CHAMP.position.x + 8):
		for y in range(CHAMP.position.y, CHAMP.position.y + 2):
			var case := Vector2i(x, y)
			_etat_de(case)["etat"] = LABOUREE
			if x % 4 != 3:
				var fiche := _etat_de(case)
				fiche["etat"] = SEMEE
				fiche["culture"] = (x / 4) % Terrain.CULTURES.size()
				fiche["stade"] = mini((x + y) % 4, Terrain.dernier_stade())
				fiche["nuits"] = int(fiche["stade"]) * int(_fiche(int(fiche["culture"]))["nuits"]) / Terrain.dernier_stade()
				fiche["arrosee"] = y == CHAMP.position.y
			_redessiner(case)

# --------------------------------------------------------------- les gestes

func _case_sous_les_pieds() -> Vector2i:
	return Vector2i(int(floor(_position.x / CASE)), int(floor(_position.y / CASE)))

func _etat_de(case: Vector2i) -> Dictionary:
	if not _parcelles.has(case):
		_parcelles[case] = {"etat": FRICHE, "arrosee": false, "stade": 0, "culture": 0,
			"nuits": 0, "sol": null, "plante": null}
	return _parcelles[case]

func _agir() -> void:
	if LIT.has_point(_position):
		_dormir()
		return
	var case := _case_sous_les_pieds()
	if not CHAMP.has_point(case):
		_dire("Rien à faire ici. Le champ est derrière la clôture.")
		return
	var fiche := _etat_de(case)
	var etat: int = int(fiche["etat"])

	# Récolter passe avant l'outil en main : un plant mûr se cueille, on ne
	# demande pas au joueur de reposer son arrosoir d'abord.
	if etat == SEMEE and int(fiche["stade"]) >= Terrain.dernier_stade():
		if _depenser("recolte"):
			fiche["etat"] = LABOUREE
			fiche["arrosee"] = false
			_recoltes += 1
			var prix: int = int(_fiche(int(fiche["culture"]))["prix"])
			_a_vendre += prix
			Sons.jouer("depart", 1.3, -14.0)
			_dire("%s récolté — %d pièces au matin." % [
				Terrain.nom_culture(int(fiche["culture"])).capitalize(), prix])
			_redessiner(case)
			_eclater(case, "recolte")
			_empiler(int(fiche["culture"]))
		return

	match _outil:
		HOUE:
			if etat != FRICHE:
				_dire("Déjà retourné.")
			elif _depenser("labour"):
				fiche["etat"] = LABOUREE
				Sons.jouer("clic", 0.8, -14.0)
				_redessiner(case)
				_eclater(case, "labour")
		GRAINES:
			var sachet: int = int(_fiche(_culture)["graine"])
			if etat != LABOUREE:
				_dire("Il faut d'abord passer la houe.")
			elif _pieces < sachet:
				_dire("Pas assez de pièces pour un sachet de %s (%d)." % [Terrain.nom_culture(_culture), sachet])
			elif _depenser("semis"):
				_pieces -= sachet
				fiche["etat"] = SEMEE
				fiche["stade"] = 0
				fiche["nuits"] = 0
				fiche["culture"] = _culture
				Sons.jouer("clic", 1.4, -16.0)
				_dire("%s semé." % Terrain.nom_culture(_culture).capitalize())
				_redessiner(case)
				_eclater(case, "semis")
		ARROSOIR:
			if etat == FRICHE:
				_dire("Rien à arroser sur une friche.")
			elif bool(fiche["arrosee"]):
				_dire("Déjà arrosé.")
			elif _depenser("arrosage"):
				fiche["arrosee"] = true
				Sons.jouer("bip", 0.7, -18.0)
				_redessiner(case)
				_eclater(case, "arrosage")
	_rafraichir_hud()

func _depenser(geste: String) -> bool:
	var cout: int = int(COUT[geste])
	if _energie < cout:
		_dire("Plus d'énergie. Il faut dormir.")
		return false
	_energie -= cout
	return true

## Dormir : l'arbitre de la journée. C'est ici, et nulle part ailleurs, que
## les plants avancent — et seulement ceux dont la terre était arrosée. La
## terre sèche au passage : l'arrosage se refait chaque jour.
func _dormir() -> void:
	if _endormi:
		return
	_endormi = true
	# Le noir tombe AVANT que l'état change, et se relève après : un jour qui
	# passe en un seul cadre, sans transition, se lit comme un bug d'affichage.
	var tombe := create_tween()
	tombe.tween_property(_voile, "modulate:a", 1.0, 0.45)
	await tombe.finished
	var pousses := 0
	for case in _parcelles:
		var fiche: Dictionary = _parcelles[case]
		if int(fiche["etat"]) == SEMEE and bool(fiche["arrosee"]) \
				and int(fiche["stade"]) < Terrain.dernier_stade():
			# Le stade se DÉDUIT des nuits arrosées : un chou met quatre nuits
			# là où un radis en met deux, avec les mêmes quatre images.
			fiche["nuits"] = int(fiche["nuits"]) + 1
			var necessaires: int = int(_fiche(int(fiche["culture"]))["nuits"])
			fiche["stade"] = mini(Terrain.dernier_stade(),
				int(floor(float(Terrain.dernier_stade()) * float(fiche["nuits"]) / float(necessaires))))
			pousses += 1
		fiche["arrosee"] = false
		_redessiner(case)
	# Les cageots partent dans la nuit et reviennent en pièces : c'est la
	# caisse d'expédition, le seul endroit où la ferme rapporte.
	var vendu := _a_vendre
	_pieces += vendu
	_a_vendre = 0
	for noeud in _cageots_noeuds:
		(noeud as Node).queue_free()
	_cageots_noeuds.clear()
	_cageots = 0
	_jour += 1
	_heure = LEVER
	_energie = ENERGIE_MAX
	Sons.jouer("portail", 0.7, -12.0)
	_voile_texte.text = "Jour %d" % _jour + ("\n+ %d pièces" % vendu if vendu > 0 else "")
	_dire("Jour %d. %d plants ont poussé, %d pièces encaissées." % [_jour, pousses, vendu])
	_rafraichir_hud()
	await get_tree().create_timer(0.9).timeout
	var leve := create_tween()
	leve.tween_property(_voile, "modulate:a", 0.0, 0.6)
	await leve.finished
	_voile_texte.text = ""
	_endormi = false

## Un petit éclat de matière à l'endroit du geste, et le personnage qui
## marque le coup. Sans ça, une case qui change d'état d'un cadre à l'autre
## ne se ressent pas — on ne sait pas si on a agi ou si le jeu a hoqueté.
func _eclater(case: Vector2i, geste: String) -> void:
	var eclats := CPUParticles2D.new()
	eclats.one_shot = true
	eclats.emitting = true
	eclats.amount = 10
	eclats.lifetime = 0.45
	eclats.explosiveness = 1.0
	eclats.direction = Vector2(0, -1)
	eclats.spread = 70.0
	eclats.initial_velocity_min = 28.0
	eclats.initial_velocity_max = 60.0
	eclats.gravity = Vector2(0, 140)
	eclats.scale_amount_min = 1.0
	eclats.scale_amount_max = 2.0
	var teintes: Array = ECLAT[geste]
	eclats.color = teintes[0]
	var degrade := Gradient.new()
	degrade.set_color(0, teintes[0])
	degrade.set_color(1, teintes[1])
	eclats.color_ramp = degrade
	eclats.position = Vector2(case) * CASE + Vector2(CASE * 0.5, CASE * 0.6)
	eclats.z_index = 20
	plan().add_child(eclats)
	get_tree().create_timer(1.2).timeout.connect(eclats.queue_free)

	var saut := create_tween()
	saut.tween_property(_corps, "offset:y", PIEDS.y - 5.0, 0.07)
	saut.tween_property(_corps, "offset:y", PIEDS.y, 0.1)

## La récolte va quelque part : un cageot de plus devant la grange. C'est la
## seule progression qui se VOIT depuis le champ — un compteur en haut de
## l'écran ne fait pas une ferme qui prospère.
func _empiler(culture: int) -> void:
	if _cageots >= CAGEOTS_MAX:
		return
	var cageot := Terrain.cageot(culture)
	var colonne := _cageots % CAGEOTS_PAR_RANG
	var rang := _cageots / CAGEOTS_PAR_RANG
	Pixels.poser(cageot, CAGEOTS + Vector2(colonne * 18, rang * 12))
	plan().add_child(cageot)
	_cageots_noeuds.append(cageot)
	_cageots += 1

func _fiche(culture: int) -> Dictionary:
	return FICHES[Terrain.nom_culture(culture)]

func _dire(texte: String) -> void:
	_message = texte
	_depuis_message = 0.0

# ----------------------------------------------------------------- le rendu

## `avec_voisines` évite la récursion : quand une case change d'état, les
## quatre voisines doivent refaire leur cerne — celui-ci ne dépend pas que
## d'elles — mais elles n'ont pas à propager plus loin.
func _redessiner(case: Vector2i, avec_voisines: bool = true) -> void:
	var fiche := _etat_de(case)
	var coin := Vector2(case) * CASE
	var sol = fiche.get("sol")
	if sol:
		(sol as Node).queue_free()
		fiche["sol"] = null
	if int(fiche["etat"]) != FRICHE:
		_arracher(case)
		var terre := Terrain.parcelle(CASE, GRAINE + case.x * 31 + case.y * 17,
			bool(fiche["arrosee"]), _voisines(case))
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
		var pousse := Terrain.plant(int(fiche["culture"]), int(fiche["stade"]))
		# Ancré au bas de la case : le plant est trié en profondeur comme un
		# personnage, donc on passe devant les rangs du bas et derrière ceux
		# du haut.
		Pixels.poser(pousse, coin + Vector2(CASE * 0.5, CASE - 4))
		plan().add_child(pousse)
		fiche["plante"] = pousse
	if avec_voisines:
		for pas in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if _parcelles.has(case + pas):
				_redessiner(case + pas, false)

## La houe arrache ce qui poussait là. Les brins sont libérés pour de bon : une
## parcelle ne redevient jamais friche dans cette version, et les garder
## coûterait un suivi d'état pour rien.
func _arracher(case: Vector2i) -> void:
	for brin in _brins.get(case, []):
		(brin as Node).queue_free()
	_brins.erase(case)

## Le masque des voisines déjà retournées : 1 haut, 2 bas, 4 gauche, 8 droite.
func _voisines(case: Vector2i) -> int:
	var masque := 0
	for entree in [[Vector2i(0, -1), 1], [Vector2i(0, 1), 2],
			[Vector2i(-1, 0), 4], [Vector2i(1, 0), 8]]:
		var voisine: Vector2i = case + (entree[0] as Vector2i)
		if _parcelles.has(voisine) and int(_parcelles[voisine]["etat"]) != FRICHE:
			masque |= int(entree[1])
	return masque

func _process(delta: float) -> void:
	if Commandes.action_declenchee():
		_agir()
	var direction := Commandes.direction()
	if direction != Vector2.ZERO:
		var avant := _position
		_position.x += direction.x * VITESSE * delta
		_degager(avant)
		avant = _position
		_position.y += direction.y * VITESSE * delta
		_degager(avant)
		_position.x = clampf(_position.x, 16.0, MONDE.x - 16.0)
		_position.y = clampf(_position.y, 52.0, MONDE.y - 16.0)
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
	_placer_curseur()
	_avancer_l_heure(delta)
	_depuis_message += delta
	_rafraichir_hud()

## Le cadre suit la case sous les pieds et s'éteint hors du champ. Il porte
## aussi l'information « ce geste est possible » : vert si l'outil en main a
## quelque chose à faire ici, blanc sinon. La couleur ne dit jamais rien
## toute seule — le bandeau du bas écrit ce qui manque.
func _placer_curseur() -> void:
	var case := _case_sous_les_pieds()
	if not CHAMP.has_point(case):
		_curseur.visible = false
		return
	_curseur.visible = true
	_curseur.position = Vector2(case) * CASE
	var fiche := _etat_de(case)
	var etat: int = int(fiche["etat"])
	var possible := false
	if etat == SEMEE and int(fiche["stade"]) >= Terrain.dernier_stade():
		possible = true
	else:
		match _outil:
			HOUE: possible = etat == FRICHE
			GRAINES: possible = etat == LABOUREE
			ARROSOIR: possible = etat != FRICHE and not bool(fiche["arrosee"])
	_curseur.modulate = Palette.BON.lerp(Color.WHITE, 0.3) if possible else Color(1, 1, 1, 0.45)

## Une source de lumière ronde, fabriquée : un dégradé radial du moteur, sans
## fichier.
##
## ⚠ Additif, mais DOUX. Deux essais vus à l'image : en additif à pleine
## puissance, le personnage sous sa lanterne devenait rose et saturé, comme
## surexposé ; en mode mélange, la lampe ne perce pas la teinte de nuit du
## `CanvasModulate` — celle-ci s'applique après, et la flaque de lumière
## disparaissait presque. Reste l'additif à mi-puissance : la flaque se voit,
## le sprite s'éclaire sans brûler. Le jour, à zéro, la lampe n'existe pas.
func _lumiere(couleur: Color, rayon: float) -> PointLight2D:
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = degrade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 128
	texture.height = 128
	var lampe := PointLight2D.new()
	lampe.texture = texture
	lampe.texture_scale = rayon / 64.0
	lampe.color = couleur
	lampe.energy = 0.0
	lampe.blend_mode = Light2D.BLEND_MODE_ADD
	return lampe

## Le temps passe, la lumière tourne. Quatre teintes suffisent : la nuit,
## l'aube, le plein jour, le crépuscule — interpolées, elles donnent une
## journée entière sans qu'on ait à écrire une courbe.
func _avancer_l_heure(delta: float) -> void:
	_heure += delta / _duree_jour
	while _heure >= 1.0:
		_heure -= 1.0
		_jour += 1
	_teinte.color = _teinte_du_jour(_heure)
	# Force de la nuit : 0 en plein jour, 1 au plus sombre. Les lampes suivent,
	# et le feu vacille un peu — un feu fixe se lit comme une image collée.
	var nuit := clampf((1.0 - _teinte.color.get_luminance()) / 0.5, 0.0, 1.0)
	_scintille += delta * 9.0
	_lumiere_feu.energy = nuit * (0.62 + 0.07 * sin(_scintille) + 0.04 * sin(_scintille * 2.7))
	_lanterne.energy = nuit * 0.38

func _teinte_du_jour(heure: float) -> Color:
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
		KEY_TAB: _changer_outil((_outil + 1) % OUTILS.size())
		KEY_1: _changer_outil(HOUE)
		KEY_2: _changer_outil(GRAINES)
		KEY_3: _changer_outil(ARROSOIR)
		KEY_A: _changer_culture()
		KEY_ESCAPE: demande_ecran.emit("menu", {})

func _changer_outil(outil: int) -> void:
	# Reprendre le semoir alors qu'on l'a déjà en main fait tourner la graine :
	# une touche de moins à apprendre, et on change de culture là où on y pense.
	if outil == GRAINES and _outil == GRAINES:
		_changer_culture()
		return
	_outil = outil
	Sons.jouer("clic", 1.0, -20.0)
	_rafraichir_hud()

func _changer_culture() -> void:
	_culture = (_culture + 1) % Terrain.CULTURES.size()
	_outil = GRAINES
	Sons.jouer("clic", 1.2, -20.0)
	_dire("Sachet de %s." % Terrain.nom_culture(_culture))
	_rafraichir_hud()

func _construire_hud() -> void:
	var couche := interface()
	# L'interface est POSÉE SUR DES PANNEAUX, pas écrite à même le monde : du
	# texte clair sur une prairie claire se lit une fois sur deux, et la ligne
	# d'aide tombait pile sur la clôture. C'est la même boîte que le hub.
	var cadre_haut := UI.panneau()
	cadre_haut.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cadre_haut.position = Vector2(18, 14)
	couche.add_child(cadre_haut)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 20)
	cadre_haut.add_child(haut)
	_hud_outil = UI.titre("", 20)
	haut.add_child(_hud_outil)
	_hud_pieces = UI.texte("", 15, Palette.AVERTISSEMENT)
	haut.add_child(_hud_pieces)
	_hud_energie = UI.texte("", 15, Palette.ENCRE_DOUCE)
	haut.add_child(_hud_energie)
	var fond := ColorRect.new()
	fond.color = Palette.FILET
	fond.custom_minimum_size = Vector2(120, 10)
	fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(fond)
	_hud_jauge = ColorRect.new()
	_hud_jauge.color = Palette.BON
	_hud_jauge.position = Vector2.ZERO
	_hud_jauge.size = Vector2(120, 10)
	fond.add_child(_hud_jauge)
	_hud_compte = UI.texte("", 15, Palette.ENCRE_DOUCE)
	haut.add_child(_hud_compte)
	_hud_heure = UI.texte("", 15, Palette.ENCRE)
	haut.add_child(_hud_heure)

	var cadre_bas := UI.panneau()
	cadre_bas.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cadre_bas.position = Vector2(18, -18)
	cadre_bas.grow_vertical = Control.GROW_DIRECTION_BEGIN
	couche.add_child(cadre_bas)
	var bas := VBoxContainer.new()
	bas.add_theme_constant_override("separation", 4)
	cadre_bas.add_child(bas)
	_hud_message = UI.texte("", 16, Palette.SERIE)
	bas.add_child(_hud_message)
	_hud_aide = UI.texte("", 14, Palette.ENCRE_FAIBLE)
	bas.add_child(_hud_aide)

	# Le voile du sommeil est ajouté EN DERNIER : dans une CanvasLayer, l'ordre
	# des enfants est l'ordre de dessin, et un voile ajouté avant les panneaux
	# passerait dessous — on verrait l'interface flotter sur le noir.
	_voile = ColorRect.new()
	_voile.color = Palette.FOND
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.modulate.a = 0.0
	couche.add_child(_voile)
	_voile_texte = UI.titre("", 40)
	_voile_texte.set_anchors_preset(Control.PRESET_CENTER)
	_voile_texte.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_voile_texte.grow_vertical = Control.GROW_DIRECTION_BOTH
	_voile.add_child(_voile_texte)
	_rafraichir_hud()

func _rafraichir_hud() -> void:
	if _hud_outil == null:
		return
	_hud_outil.text = "En main : " + (("Graines de %s (%d p., %d nuits)" % [
		Terrain.nom_culture(_culture), int(_fiche(_culture)["graine"]), int(_fiche(_culture)["nuits"])])
		if _outil == GRAINES else String(OUTILS[_outil]))
	_hud_pieces.text = "%d pièces" % _pieces + ("  (+%d au matin)" % _a_vendre if _a_vendre > 0 else "")
	_hud_energie.text = "Énergie %d" % _energie
	_hud_jauge.size = Vector2(120.0 * float(_energie) / float(ENERGIE_MAX), 10)
	# La couleur ne porte jamais seule le sens : le chiffre est écrit à côté.
	_hud_jauge.color = Palette.BON if _energie > 30 else (
		Palette.AVERTISSEMENT if _energie > 10 else Palette.CRITIQUE)

	var semees := 0
	var seches := 0
	var mures := 0
	for case in _parcelles:
		var fiche: Dictionary = _parcelles[case]
		if int(fiche["etat"]) != SEMEE:
			continue
		semees += 1
		if int(fiche["stade"]) >= Terrain.dernier_stade():
			mures += 1
		elif not bool(fiche["arrosee"]):
			seches += 1
	_hud_compte.text = "%d plants · %d à arroser · %d mûrs · %d récoltés" % [
		semees, seches, mures, _recoltes]

	var minutes := int(_heure * 1440.0)
	_hud_heure.text = "Jour %d · %02dh%02d" % [_jour, (minutes / 60) % 24, minutes % 60]
	_hud_message.text = _message if _depuis_message < 3.5 else ""
	_hud_aide.text = "Z Q S D marcher · 1 houe, 2 graines (A change la culture), 3 arrosoir · E agit sur la case encadrée · E devant la grange pour dormir · Échap revient au village."
