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
## Les émotes : touches 1 à 4, une bulle au-dessus de la tête, visible de tous.
const EMOTES := ["!", "?", "<3", "zZ"]
## Le cycle du jour, calé sur l'heure universelle pour que tous les joueurs
## vivent la même heure : quinze minutes, dont quatre de nuit.
const CYCLE := 900.0

## Les lieux du hub. Le village est dehors ; les trois autres sont des pièces
## entières de la maquette du pack, chacune avec sa zone de marche, ses
## meubles, sa sortie, son habitant, et — pour deux d'entre elles — le
## classement au mur et le portail qui lance le jeu. Toutes les coordonnées
## sont en pixels de l'image du lieu.
const LIEUX := {
	"village": {
		"nom": "Village",
		"pnj": [{"nom": "paysanne", "position": Vector2(352, 416), "phrases": [
			"Salut {pseudo}. Trois portes ouvertes : la taverne, l'armurerie, l'auberge.",
			"La taverne mène au Carnage, l'armurerie à l'Énigme. À l'auberge, on dort.",
			"Le champion du Carnage, c'est {champion_carnage}. À l'Énigme, {champion_enigme}. Pour l'instant.",
			"Le tableau, là-bas au coin de la place, dit qui a joué en dernier.",
		]}],
	},
	"taverne": {
		"nom": "Taverne",
		"lueur": {"centre": Vector2(182, 112), "taille": Vector2(34, 44)},
		"tableau": Rect2(280, 6, 152, 54),
		"rangs": 5,
		"jeu": "carnage",
		"titre": "CARNAGE",
		"pnj": [{"nom": "serveuse", "position": Vector2(56, 328), "phrases": [
			"Une chope ? Non ? Alors pousse-toi, j'ai des tables.",
			"Le patron dit que les vainqueurs boivent gratis. Il ment.",
		]}, {"nom": "taverniere", "position": Vector2(56, 256), "phrases": [
			"Dehors, la ville est à prendre. Vole une voiture, et ne freine pas.",
			"Trois bandes tiennent les rues. Saigne-en une et sa rivale t'ouvrira sa porte.",
			"Cinq étoiles au compteur ? Le garage bleu te repeint, et la police t'oublie.",
			"Décroche à une cabine : ils paient pour ce qu'ils n'osent pas faire eux-mêmes.",
			"Descends de voiture quand il le faut — mais à pied, tout te fait mal deux fois.",
			"Les deux esplanades cerclées de rouge, c'est là qu'on règle ses comptes entre nous.",
			"Le portail, c'est la porte du fond. On y va à deux, à trois, à quatre.",
		]}],
	},
	"armurerie": {
		"nom": "Armurerie",
		"lueur": {"centre": Vector2(288, 160), "taille": Vector2(30, 30)},
		"tableau": Rect2(160, 6, 112, 42),
		"rangs": 3,
		"jeu": "enigme",
		"titre": "ÉNIGME",
		"pnj": [{"nom": "squelette", "position": Vector2(232, 104), "phrases": [
			"Trois chambres. Aucune ne s'ouvre à un seul.",
			"Une dalle ne reste enfoncée que si quelque chose pèse dessus — quelqu'un, ou une caisse.",
			"Et la sortie n'accepte l'équipe qu'au complet. Personne ne finit seul.",
			"Le portail est là, dans le coin, à droite.",
		]}],
	},
	"auberge": {
		"nom": "Auberge",
		"pnj": [{"nom": "aubergiste", "position": Vector2(200, 120), "phrases": [
			"Chut, il y a des gens qui dorment. Ici on se repose entre deux parties.",
			"Le troisième jeu se prépare. Repasse.",
		]}],
	},
	"maison": {"nom": "Maison", "ferme": "C'est fermé. Les habitants sont partis jouer au Carnage."},
	"grange": {"nom": "Grange", "ferme": "La grange donne sur la ferme. Elle ouvre bientôt : ça sent déjà le foin et les radis."},
}

## Le plan du village et des pièces — sol, objets, cases bloquées, portes,
## sorties et portails — est écrit par `outils/village.py` dans
## `plan.json`. Ce qu'on voit et ce qui arrête le joueur sortent du même
## fichier : c'est ce qui garantit qu'on ne traverse ni mur ni meuble.
static var _carte: Dictionary = {}

static func carte() -> Dictionary:
	if _carte.is_empty():
		var texte := FileAccess.get_file_as_string(IMAGES + "plan.json")
		_carte = JSON.parse_string(texte) as Dictionary
	return _carte

static func rect_de(valeur) -> Rect2:
	if valeur == null:
		return Rect2()
	var v: Array = valeur
	return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))

var _canal: CanalTempsReel
var _camera: Camera2D
var _lieu := "village"
var _position := Vector2.ZERO
var _marche := false
var _autres: Dictionary = {}       # cle -> {cible, affichee, pseudo, noeud}
var _corps: AnimatedSprite2D
var _bloque: PackedStringArray = []   # une ligne par rangée de cases, `#` = bloqué
var _bloque_aussi: Dictionary = {}    # cases prises à l'exécution (les PNJ)
var _case := 16
var _taille := Vector2.ZERO
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

var _modulation: CanvasModulate
var _lumieres: Array[PointLight2D] = []
var _lucioles: CPUParticles2D
var _voile: ColorRect
var _panneau_carnet: PanelContainer
var _hud_carnet: Label
var _carnet: Array = []
var _hud_presents: Label
var _hud_etat: HBoxContainer
var _hud_titre: Label
var _hud_invite: Label
var _hud_dialogue: Label
var _panneau_dialogue: PanelContainer
var _tableau: Label
var _affichage: Label
var _journal: Array = []
var _classements: Dictionary = {}
var _depuis_pas := 0.0

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
		elif a.begins_with("--nuit="):
			nuit_forcee = float(a.substr(7))
		elif a.begins_with("--emote="):
			var indice := int(a.substr(8))
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				_emote(indice)
				_panneau_carnet.visible = true)
	_entrer_dans(demande if LIEUX.has(demande) else "village", depart)

	Tactile.mode = Tactile.MARCHE
	Tactile.action.connect(_agir)

	_canal = Reseau.rejoindre(CANAL, {"pseudo": Session.pseudo, "id": Session.id, "lieu": _lieu, "heros": Session.heros_affiche()})
	_canal.diffusion.connect(_sur_diffusion)
	_canal.presences_changees.connect(_sur_presences)

	Scores.classement_recu.connect(_sur_classement)
	Scores.carnet_recu.connect(_sur_carnet)
	Scores.journal_recu.connect(_sur_journal)
	Scores.demander_classement("carnage", 5)
	Scores.demander_classement("enigme", 5)
	Scores.demander_carnet(Session.id)
	Scores.demander_journal(5)

func _exit_tree() -> void:
	Sons.musique("")
	Sons.ambiance("")
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
	var geometrie: Dictionary = carte()[lieu]
	_case = int(carte()["case"])
	_taille = Vector2(float(geometrie["taille"][0]), float(geometrie["taille"][1]))

	for enfant in plan().get_children():
		enfant.queue_free()
	_autres.clear()

	var fond := Pixels.image(IMAGES + ("sol_village.png" if lieu == "village" else "interieur_%s.png" % lieu), false)
	fond.z_index = -100
	fond.y_sort_enabled = false
	plan().add_child(fond)

	_modulation = null
	_lumieres.clear()
	_lucioles = null
	_bloque = PackedStringArray(geometrie["bloque"])
	_bloque_aussi.clear()
	_portes.clear()
	_sortie = rect_de(geometrie.get("sortie"))
	_portail = rect_de(geometrie.get("portail"))
	_jeu_du_lieu = String(fiche.get("jeu", ""))
	_titre_du_lieu = String(fiche.get("titre", ""))
	_pnj = []
	_tableau = null
	_affichage = null

	if lieu == "village":
		_batir_village(geometrie)
	else:
		_batir_interieur(fiche)
	for pnj in fiche.get("pnj", []):
		_poser_pnj(pnj)

	var depart := Vector2.ZERO
	if geometrie.has("depart"):
		depart = Vector2(float(geometrie["depart"][0]), float(geometrie["depart"][1]))
	else:
		# Dans une pièce, on arrive sur la sortie.
		depart = _sortie.get_center() + Vector2(0, 2)
	_position = arrivee if arrivee != Vector2.ZERO else depart
	_corps = _sprite_de_heros(Session.heros_affiche())
	plan().add_child(_corps)

	# Une pièce plus petite que l'écran se centre ; une plus grande fait
	# glisser la caméra sans jamais montrer au-delà de ses murs.
	var visible := _vue()
	_camera.limit_left = 0 if _taille.x > visible.x else -100000
	_camera.limit_right = int(_taille.x) if _taille.x > visible.x else 100000
	_camera.limit_top = 0 if _taille.y > visible.y else -100000
	_camera.limit_bottom = int(_taille.y) if _taille.y > visible.y else 100000
	_camera.position = _position_camera()
	_camera.reset_smoothing()

	if _canal and _canal.est_rejoint:
		_canal.suivre({"pseudo": Session.pseudo, "id": Session.id, "lieu": _lieu, "heros": Session.heros_affiche()})
	# Dehors, le thème du village sur un fond de forêt ; dans la taverne, son
	# propre air ; dans les autres pièces, le village continue, étouffé.
	Sons.musique("taverne" if lieu == "taverne" else "village")
	Sons.ambiance("foret" if lieu == "village" else "")
	_rafraichir_hud()

func _vue() -> Vector2:
	return get_viewport().get_visible_rect().size / float(ZOOM)

func _position_camera() -> Vector2:
	var visible := _vue()
	return Vector2(
		_position.x if _taille.x > visible.x else _taille.x * 0.5,
		_position.y if _taille.y > visible.y else _taille.y * 0.5)

func _sprite_de_heros(nom: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = Pixels.heros(nom if nom in Pixels.HEROS else "knight")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset = PIEDS
	s.play("repos")
	_ombrer(s)
	return s

## L'ombre au sol d'un personnage : l'ellipse du pack, sous les pieds, derrière.
func _ombrer(porteur: Node2D) -> void:
	var ombre := Pixels.image(IMAGES + "ombre_personnage.png", false)
	ombre.centered = true
	ombre.offset = Vector2.ZERO
	ombre.position = Vector2(0, -3)
	ombre.show_behind_parent = true
	porteur.add_child(ombre)

func _batir_village(geometrie: Dictionary) -> void:
	# Chaque objet du plan est une image entière, posée à sa case ; le
	# moteur les trie par le bas de leur image, donc par leur pied.
	for objet in geometrie["objets"]:
		var sprite := Pixels.image(IMAGES + String(objet["image"]))
		var largeur := float(sprite.texture.get_width())
		var hauteur := float(sprite.texture.get_height())
		Pixels.poser(sprite, Vector2(float(objet["x"]) + largeur * 0.5, float(objet["y"]) + hauteur))
		plan().add_child(sprite)
	for porte in geometrie["portes"]:
		var rect := Rect2(float(porte["x"]), float(porte["y"]), float(porte["l"]), float(porte["h"]))
		_portes.append({"rect": rect, "lieu": String(porte["lieu"]), "nom": String(porte["nom"])})
		var enseigne := _ecriteau(String(porte["nom"]), 8)
		enseigne.position = rect.get_center() + Vector2(-64, -8 * _case - 14)
		enseigne.size = Vector2(128, 10)
		plan().add_child(enseigne)
	# La flamme du feu de camp, animée, posée dans le foyer du plan.
	var feu := AnimatedSprite2D.new()
	feu.sprite_frames = Pixels.animation("feu", IMAGES + "feu.png", 10.0, 32)
	feu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Le contenu de la flamme descend jusqu'à la ligne 33 de sa case de 48 :
	# ce pivot la pose au milieu du foyer et la dessine juste après lui.
	feu.offset = Vector2(2, -14)
	Pixels.poser(feu, Vector2(float(geometrie["feu"][0]), float(geometrie["feu"][1]) + 1))
	feu.play("feu")
	plan().add_child(feu)
	# Les ateliers animés du plan : rôtissoire, scierie.
	for anime in geometrie.get("animes", []):
		var atelier := AnimatedSprite2D.new()
		var cote := int(anime["cote"])
		atelier.sprite_frames = Pixels.animation("marche", IMAGES + String(anime["image"]), float(anime["vitesse"]), cote)
		atelier.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		atelier.offset = Vector2(0, -32)
		Pixels.poser(atelier, Vector2(float(anime["x"]) + cote * 0.5, float(anime["y"]) + 64.0))
		atelier.play("marche")
		plan().add_child(atelier)
	_semer_les_feuilles()
	_eclairer_le_village(geometrie)
	# Le tableau d'affichage de la place : les dernières parties jouées.
	# Le panneau de bois est un objet du plan ; ici, seule l'inscription.
	_affichage = _tableau_mural(rect_de(geometrie["tableau"]))
	_affichage.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_affichage.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_affichage.z_index = 1
	plan().add_child(_affichage)
	_rafraichir_affichage()

func _sur_journal(lignes: Array) -> void:
	_journal = lignes
	_rafraichir_affichage()

func _rafraichir_affichage() -> void:
	if _affichage == null or not is_instance_valid(_affichage):
		return
	# Dix-neuf caractères de large, six lignes : la place du panneau.
	var texte := " DERNIERES PARTIES\n"
	if _journal.is_empty():
		texte += "\n  PERSONNE N'A JOUE"
	for ligne in _journal.slice(0, 5):
		var quand := _il_y_a(String(ligne.get("cree_le", "")))
		texte += "%-6s %-3s %4d %3s\n" % [String(ligne.get("pseudo", "?")).to_upper().left(6),
			String(ligne.get("jeu", "")).to_upper().left(3), mini(int(ligne.get("score", 0)), 9999), quand]
	_affichage.text = texte.trim_suffix("\n")

## « 3m », « 2h », « 5j » : l'âge d'une date ISO, en trois caractères au plus.
static func _il_y_a(iso: String) -> String:
	if iso.length() < 19:
		return ""
	var d := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	var ecart := int(Time.get_unix_time_from_system()) - int(d)
	if ecart < 3600:
		return "%dm" % maxi(1, int(ecart / 60))
	if ecart < 86400:
		return "%dh" % int(ecart / 3600)
	return "%dj" % mini(99, int(ecart / 86400))

## Les phrases des habitants parlent du monde : {pseudo}, {champion_carnage},
## {champion_enigme} sont remplis au moment de parler.
func _phrase_du_monde(texte: String) -> String:
	return texte.format({
		"pseudo": Session.pseudo,
		"champion_carnage": _champion("carnage"),
		"champion_enigme": _champion("enigme"),
	})

func _champion(jeu: String) -> String:
	var lignes: Array = _classements.get(jeu, [])
	if lignes.is_empty():
		return "personne encore"
	return String(lignes[0].get("pseudo", "?"))

## Des feuilles qui tombent de la lisière, en points de deux pixels : assez
## pour que le village respire, pas assez pour qu'on les remarque une à une.
func _semer_les_feuilles() -> void:
	var feuilles := CPUParticles2D.new()
	feuilles.amount = 36
	feuilles.lifetime = 7.0
	feuilles.preprocess = 7.0
	feuilles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	feuilles.emission_rect_extents = _taille * 0.5
	feuilles.position = _taille * 0.5
	feuilles.direction = Vector2(1, 1)
	feuilles.spread = 25.0
	feuilles.gravity = Vector2(6, 10)
	feuilles.initial_velocity_min = 6.0
	feuilles.initial_velocity_max = 14.0
	feuilles.scale_amount_min = 1.0
	feuilles.scale_amount_max = 2.0
	var teintes := Gradient.new()
	teintes.set_color(0, Color(0.45, 0.62, 0.20))
	teintes.set_color(1, Color(0.70, 0.48, 0.16))
	feuilles.color_ramp = teintes
	feuilles.z_index = 90
	plan().add_child(feuilles)

func _batir_interieur(fiche: Dictionary) -> void:
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
	var nom := String(pnj["nom"])
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Pixels.personnage_non_joueur(nom)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = PIEDS
	Pixels.poser(sprite, pnj["position"])
	sprite.play("repos")
	_ombrer(sprite)
	plan().add_child(sprite)
	var fiche := {"position": (pnj["position"] as Vector2).round(), "phrases": pnj["phrases"], "noeud": sprite}
	# Un habitant qui a une ronde dans le plan marche d'un point à l'autre ;
	# il s'arrête pour parler quand on s'approche. Il ne bloque rien : il
	# bouge. Les autres prennent la case sous leurs pieds.
	var rondes: Dictionary = carte()[_lieu].get("rondes", {})
	if rondes.has(nom):
		var chemin: Array[Vector2] = []
		for point in rondes[nom]:
			chemin.append(Vector2(float(point[0]), float(point[1])))
		fiche["chemin"] = chemin
		fiche["etape"] = 1 % chemin.size()
		fiche["pause"] = 0.0
	else:
		var pieds: Vector2 = (pnj["position"] as Vector2).round() + Vector2(0, -4)
		_bloque_aussi[Vector2i(int(pieds.x) / _case, int(pieds.y) / _case)] = true
	_pnj.append(fiche)

const PAS_DE_RONDE := 34.0

func _faire_les_rondes(delta: float) -> void:
	for i in _pnj.size():
		var pnj: Dictionary = _pnj[i]
		if not pnj.has("chemin"):
			continue
		var noeud: AnimatedSprite2D = pnj["noeud"]
		var position: Vector2 = pnj["position"]
		# Face au joueur qui vient parler, on ne bouge plus.
		if _position.distance_to(position) < 34.0:
			if noeud.animation != "repos":
				noeud.play("repos")
			noeud.flip_h = _position.x < position.x
			continue
		if float(pnj["pause"]) > 0.0:
			pnj["pause"] = float(pnj["pause"]) - delta
			if noeud.animation != "repos":
				noeud.play("repos")
			continue
		var chemin: Array = pnj["chemin"]
		var cible: Vector2 = chemin[int(pnj["etape"])]
		var vers := cible - position
		var pas := PAS_DE_RONDE * delta
		if vers.length() <= pas:
			position = cible
			pnj["etape"] = (int(pnj["etape"]) + 1) % chemin.size()
			pnj["pause"] = 1.5
		else:
			position += vers.normalized() * pas
			if absf(vers.x) > 0.5:
				noeud.flip_h = vers.x < 0.0
			if noeud.animation != "marche" and noeud.sprite_frames.has_animation("marche"):
				noeud.play("marche")
		pnj["position"] = position
		Pixels.poser(noeud, position)

## Le classement affiché SUR le mur de la pièce, comme une ardoise de
## taverne : un cadre sombre à la taille de la niche, et le texte dedans.
func _tableau_mural(cadre: Rect2) -> Label:
	var ardoise := Label.new()
	ardoise.position = cadre.position
	ardoise.size = cadre.size
	ardoise.z_index = 4
	ardoise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ardoise.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# La police des inscriptions du décor : 8 pixels, sa grille native.
	ardoise.add_theme_font_override("font", UI.TITRE_POLICE)
	ardoise.add_theme_font_size_override("font_size", 8)
	ardoise.add_theme_constant_override("line_spacing", 0)
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
		texte += "..."
	elif (lignes as Array).is_empty():
		texte += "AUCUN SCORE"
	else:
		var rang := 1
		var rangs := int(LIEUX[_lieu].get("rangs", 5))
		for ligne in lignes:
			if rang > rangs:
				break
			var pseudo := String(ligne.get("pseudo", "?")).to_upper().left(8)
			texte += "%d %-8s %5d\n" % [rang, pseudo, int(ligne.get("score", 0))]
			rang += 1
	_tableau.text = texte.strip_edges()

## « la taverne », « l'armurerie » : le nom du lieu avec son article.
static func _article(lieu: String) -> String:
	var nom := String(LIEUX[lieu]["nom"]).to_lower()
	return ("l'" if nom[0] in "aeiouy" else "la ") + nom

func _ecriteau(texte: String, taille_police: int) -> Label:
	var e := Label.new()
	e.text = texte
	e.add_theme_font_override("font", UI.TITRE_POLICE)
	e.add_theme_font_size_override("font_size", UI.taille_titre(taille_police))
	e.add_theme_color_override("font_color", Palette.ENCRE)
	e.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	e.add_theme_constant_override("outline_size", 3)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.z_index = 50
	return e

# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	_faire_les_rondes(delta)
	if _lieu == "village":
		_tomber_la_nuit()
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

	# Un pas toutes les 0,32 s en marchant ; plus sec et plus aigu dedans.
	if _marche:
		_depuis_pas += delta
		if _depuis_pas >= 0.32:
			_depuis_pas = 0.0
			Sons.jouer("pas", 1.0 if _lieu == "village" else 1.5, -22.0)
	else:
		_depuis_pas = 0.3
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
	if _bloquee(pieds):
		_position = avant

## Une case est bloquée si le plan le dit, ou si un PNJ s'y tient.
func _bloquee(pieds: Rect2) -> bool:
	var x0 := int(floor(pieds.position.x / _case))
	var y0 := int(floor(pieds.position.y / _case))
	var x1 := int(floor((pieds.end.x - 0.01) / _case))
	var y1 := int(floor((pieds.end.y - 0.01) / _case))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if y < 0 or y >= _bloque.size() or x < 0 or x >= _bloque[y].length():
				return true
			if _bloque[y][x] == "#" or _bloque_aussi.has(Vector2i(x, y)):
				return true
	return false

func _borner() -> void:
	_position.x = clamp(_position.x, 8.0, _taille.x - 8.0)
	_position.y = clamp(_position.y, 8.0, _taille.y - 4.0)

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
	if not (evenement is InputEventKey and evenement.pressed and not evenement.echo):
		return
	match evenement.keycode:
		KEY_E:
			_agir()
		KEY_K:
			_panneau_carnet.visible = not _panneau_carnet.visible
			if _panneau_carnet.visible:
				Scores.demander_carnet(Session.id)
		KEY_1, KEY_KP_1: _emote(0)
		KEY_2, KEY_KP_2: _emote(1)
		KEY_3, KEY_KP_3: _emote(2)
		KEY_4, KEY_KP_4: _emote(3)

func _agir() -> void:
	if not is_inside_tree():
		return
	if _invite.begins_with("entrer:"):
		var lieu := _invite.substr(7)
		if LIEUX[lieu].has("ferme"):
			# Une maison fermée répond comme un habitant : une phrase.
			Sons.jouer("clic", 0.8, -16.0)
			_phrase = 0 if _phrase < 0 else -1
			_rafraichir_hud()
			return
		Sons.jouer("porte", 1.0, -10.0)
		_invite = ""
		_fondu(Palette.FOND, 0.4, func() -> void: _entrer_dans(lieu, Vector2.ZERO))
	elif _invite == "sortir":
		Sons.jouer("porte", 0.8, -10.0)
		var retour := Vector2.ZERO
		for porte in carte()["village"]["portes"]:
			if String(porte["lieu"]) == _lieu:
				retour = Vector2(float(porte["x"]) + float(porte["l"]) * 0.5, float(porte["y"]) + float(porte["h"]) + 6.0)
		_invite = ""
		_fondu(Palette.FOND, 0.4, func() -> void: _entrer_dans("village", retour))
	elif _invite == "portail" and _jeu_du_lieu != "":
		Sons.jouer("portail", 1.0, -8.0)
		var jeu := _jeu_du_lieu
		var titre := _titre_du_lieu
		_invite = ""
		_fondu(Palette.SERIE.lightened(0.6), 0.7, func() -> void: demande_ecran.emit("salon", {"jeu": jeu, "titre": titre}))
	elif _invite == "parler" and _pnj_proche >= 0:
		var phrases: Array = _pnj[_pnj_proche]["phrases"]
		_phrase = (_phrase + 1) % (phrases.size() + 1)
		Sons.jouer("clic", 1.2, -16.0)
		_rafraichir_hud()

# ---------------------------------------------------------------- réseau

func _sur_diffusion(evenement: String, charge: Dictionary) -> void:
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.cle or not _autres.has(cle):
		return
	match evenement:
		"p":
			_autres[cle]["cible"] = Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
		"emo":
			var indice := int(charge.get("e", -1))
			if indice >= 0 and indice < EMOTES.size():
				_afficher_emote(_autres[cle]["noeud"], EMOTES[indice])

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
			var heros := String(meta.get("heros", ""))
			if heros == "":
				heros = Pixels.heros_de(String(meta.get("id", cle)))
			var sprite := _sprite_de_heros(heros)
			Pixels.poser(sprite, _position)
			plan().add_child(sprite)
			var nom := _ecriteau(_titre(String(meta.get("pseudo", "?"))), 8)
			nom.position = Vector2(-48, -46)
			nom.size = Vector2(96, 10)
			nom.name = "nom"
			sprite.add_child(nom)
			_autres[cle] = {"cible": _position, "affichee": _position,
				"pseudo": String(meta.get("pseudo", "?")), "noeud": sprite}
	_rafraichir_hud()

## Le premier d'un classement porte une étoile devant son nom : le village
## sait qui est le champion, sans qu'on ait à ouvrir un tableau.
func _titre(pseudo: String) -> String:
	for jeu in _classements:
		var lignes: Array = _classements[jeu]
		if not lignes.is_empty() and String(lignes[0].get("pseudo", "")) == pseudo:
			return "* " + pseudo
	return pseudo

# ---------------------------------------------------------------- émotes

func _emote(indice: int) -> void:
	if indice < 0 or indice >= EMOTES.size():
		return
	_afficher_emote(_corps, EMOTES[indice])
	Sons.jouer("clic", 1.6, -18.0)
	if _canal:
		_canal.envoyer("emo", {"e": indice})

func _afficher_emote(porteur: Node2D, texte: String) -> void:
	if porteur == null or not is_instance_valid(porteur):
		return
	var ancienne := porteur.get_node_or_null("emote")
	if ancienne:
		ancienne.queue_free()
	var bulle := Label.new()
	bulle.name = "emote"
	bulle.text = texte
	bulle.add_theme_font_override("font", UI.TITRE_POLICE)
	bulle.add_theme_font_size_override("font_size", 8)
	bulle.add_theme_color_override("font_color", Palette.FOND)
	bulle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bulle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.ENCRE
	style.set_corner_radius_all(3)
	style.set_content_margin_all(3)
	bulle.add_theme_stylebox_override("normal", style)
	bulle.position = Vector2(6, -62)
	bulle.z_index = 60
	porteur.add_child(bulle)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(bulle, "modulate:a", 0.0, 0.5)
	tween.tween_callback(bulle.queue_free)

# ---------------------------------------------------------------- le jour et la nuit

## Une phase de 0 (plein jour) à 1 (pleine nuit), continue.
static var nuit_forcee := -1.0     ## `--nuit=0.8` au banc, pour photographier la nuit

func _nuit() -> float:
	if nuit_forcee >= 0.0:
		return nuit_forcee
	var t := fmod(Time.get_unix_time_from_system(), CYCLE)
	if t < 540.0:
		return 0.0
	if t < 600.0:
		return (t - 540.0) / 60.0
	if t < 840.0:
		return 1.0
	return 1.0 - (t - 840.0) / 60.0

func _eclairer_le_village(geometrie: Dictionary) -> void:
	_modulation = CanvasModulate.new()
	plan().add_child(_modulation)
	_lumieres.clear()
	# Le feu de camp, le fourneau, et la porte de chaque maison : les seules
	# sources de lumière du village une fois la nuit tombée.
	var feu := Vector2(float(geometrie["feu"][0]), float(geometrie["feu"][1]) - 8.0)
	_lumieres.append(_lumiere(feu, Color(1.0, 0.72, 0.42), 1.4, 1.1))
	for porte in geometrie["portes"]:
		var p := Vector2(float(porte["x"]) + float(porte["l"]) * 0.5, float(porte["y"]) - 20.0)
		_lumieres.append(_lumiere(p, Color(1.0, 0.85, 0.55), 0.8, 0.55))
	for objet in geometrie["objets"]:
		if String(objet["image"]) == "fourneau.png":
			_lumieres.append(_lumiere(Vector2(float(objet["x"]) + 32.0, float(objet["y"]) + 52.0), Color(1.0, 0.6, 0.3), 0.7, 0.9))
	# Des lucioles au-dessus de l'herbe, la nuit seulement.
	_lucioles = CPUParticles2D.new()
	_lucioles.amount = 40
	_lucioles.lifetime = 4.0
	_lucioles.preprocess = 4.0
	_lucioles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_lucioles.emission_rect_extents = _taille * 0.5
	_lucioles.position = _taille * 0.5
	_lucioles.gravity = Vector2.ZERO
	_lucioles.initial_velocity_min = 3.0
	_lucioles.initial_velocity_max = 8.0
	_lucioles.spread = 180.0
	_lucioles.scale_amount_min = 1.0
	_lucioles.scale_amount_max = 1.0
	var lueur := Gradient.new()
	lueur.set_color(0, Color(1.0, 0.95, 0.5, 0.0))
	lueur.add_point(0.5, Color(1.0, 0.95, 0.5, 1.0))
	lueur.set_color(1, Color(1.0, 0.95, 0.5, 0.0))
	_lucioles.color_ramp = lueur
	_lucioles.z_index = 80
	_lucioles.emitting = false
	plan().add_child(_lucioles)

func _lumiere(position: Vector2, couleur: Color, portee: float, energie: float) -> PointLight2D:
	var l := PointLight2D.new()
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_color(1, Color(1, 1, 1, 0))
	texture.gradient = degrade
	texture.width = 128
	texture.height = 128
	l.texture = texture
	l.texture_scale = portee
	l.color = couleur
	l.energy = energie
	l.position = position
	l.blend_mode = Light2D.BLEND_MODE_ADD
	plan().add_child(l)
	return l

func _tomber_la_nuit() -> void:
	if _modulation == null or not is_instance_valid(_modulation):
		return
	var nuit := _nuit()
	# Le jour est blanc ; le soir vire à l'ambre, la nuit au bleu profond.
	var soir := Color(1.0, 0.78, 0.6)
	var noir := Color(0.36, 0.42, 0.70)
	var teinte := Color.WHITE
	if nuit < 0.5:
		teinte = Color.WHITE.lerp(soir, nuit * 2.0)
	else:
		teinte = soir.lerp(noir, (nuit - 0.5) * 2.0)
	_modulation.color = teinte
	var vacillement := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.011)
	for i in _lumieres.size():
		var l := _lumieres[i]
		l.enabled = nuit > 0.05
		l.energy = (1.1 if i == 0 else 0.7) * nuit * (vacillement if i == 0 else 1.0)
	if _lucioles:
		_lucioles.emitting = nuit > 0.6

# ---------------------------------------------------------------- le carnet

func _sur_carnet(lignes: Array) -> void:
	_carnet = lignes
	_rafraichir_carnet()

func _rafraichir_carnet() -> void:
	if _hud_carnet == null:
		return
	var meilleurs := {"carnage": 0, "enigme": 0}
	var parties := {"carnage": 0, "enigme": 0}
	for ligne in _carnet:
		var jeu := String(ligne.get("jeu", ""))
		if not meilleurs.has(jeu):
			continue
		parties[jeu] += 1
		meilleurs[jeu] = maxi(int(meilleurs[jeu]), int(ligne.get("score", 0)))
	var noms := {"knight": "chevalier", "rogue": "voleur", "wizzard": "mage"}
	var texte := "%s, %s\n\n" % [Session.pseudo, String(noms.get(Session.heros_affiche(), ""))]
	for jeu in ["carnage", "enigme"]:
		var rang := _rang_de(jeu, Session.pseudo)
		texte += "%s : %d partie%s, record %d%s\n" % [
			jeu.capitalize(), int(parties[jeu]), "s" if int(parties[jeu]) > 1 else "",
			int(meilleurs[jeu]), (" — %de au mur" % rang) if rang > 0 else ""]
	if _carnet.is_empty():
		texte += "\nPas encore de partie. Le portail de la taverne t'attend."
	_hud_carnet.text = texte.strip_edges()

func _rang_de(jeu: String, pseudo: String) -> int:
	var lignes: Array = _classements.get(jeu, [])
	for i in lignes.size():
		if String(lignes[i].get("pseudo", "")) == pseudo:
			return i + 1
	return 0

# ---------------------------------------------------------------- fondus

## Un voile qui se ferme puis se rouvre : le passage d'une porte ou d'un
## portail se sent, au lieu de couper net d'une image à l'autre.
func _fondu(couleur: Color, duree: float, au_milieu: Callable) -> void:
	if _voile == null:
		_voile = ColorRect.new()
		_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
		_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_voile.color = Color(couleur, 0.0)
		interface().add_child(_voile)
	_voile.color = Color(couleur, 0.0)
	var tween := create_tween()
	tween.tween_property(_voile, "color:a", 1.0, duree * 0.5)
	tween.tween_callback(au_milieu)
	tween.tween_property(_voile, "color:a", 0.0, duree * 0.5)

func _sur_classement(jeu: String, lignes: Array) -> void:
	_classements[jeu] = lignes
	_rafraichir_tableau()
	_rafraichir_carnet()
	for cle in _autres:
		var nom: Label = (_autres[cle]["noeud"] as Node).get_node_or_null("nom")
		if nom:
			nom.text = _titre(String(_autres[cle]["pseudo"]))

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

	# Le carnet (K) : qui je suis, mes records, ma place au mur.
	var coin := MarginContainer.new()
	coin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin.offset_left = -440
	coin.offset_right = -20
	coin.offset_top = 56
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(coin)
	_panneau_carnet = UI.panneau()
	_panneau_carnet.visible = false
	coin.add_child(_panneau_carnet)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	_panneau_carnet.add_child(colonne)
	colonne.add_child(UI.titre("Carnet", 16))
	_hud_carnet = UI.texte("", 16, Palette.ENCRE_DOUCE, true)
	_hud_carnet.custom_minimum_size = Vector2(380, 0)
	colonne.add_child(_hud_carnet)
	colonne.add_child(UI.texte("K pour refermer · 1 2 3 4 : émotes", 11, Palette.ENCRE_FAIBLE))

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
		"entrer": _hud_invite.text = ("E — frapper à " if LIEUX[_invite.substr(7)].has("ferme") else "E — entrer dans ") + _article(_invite.substr(7))
		"sortir": _hud_invite.text = "E — ressortir"
		"portail": _hud_invite.text = "E — franchir le portail"
		"parler": _hud_invite.text = "E — parler"
		_: _hud_invite.text = "Z Q S D pour marcher · K : carnet · 1-4 : émotes"

	var parle := _invite == "parler" and _pnj_proche >= 0 and _phrase >= 0 \
		and _phrase < (_pnj[_pnj_proche]["phrases"] as Array).size()
	var porte_fermee: bool = _invite.begins_with("entrer:") and _phrase == 0 and LIEUX[_invite.substr(7)].has("ferme")
	_panneau_dialogue.visible = parle or porte_fermee
	if parle:
		_hud_dialogue.text = _phrase_du_monde(String(_pnj[_pnj_proche]["phrases"][_phrase]))
	elif porte_fermee:
		_hud_dialogue.text = String(LIEUX[_invite.substr(7)]["ferme"])
