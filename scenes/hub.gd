extends Ecran
## Le hub : un village en voxels, vu de trois quarts, où l'on entre dans les
## maisons.
##
## Tout ce qu'on voit sort de `outils/voxel.py` : le terrain, les maisons,
## les arbres, le mobilier, les habitants et les héros sont bâtis cube par
## cube, à une seule palette, et écrits en glTF dans `modeles/voxel/`. Le
## même script écrit `plan.json` : ce qui arrête le joueur et ce qu'il voit
## ont la même source.
##
## La simulation, elle, n'a pas changé : un plan de cases de 16 pixels, des
## positions en pixels, les mêmes messages réseau qu'avant. Une case fait UNE
## unité dans le monde ; un personnage en fait deux de haut.
##
## Choix de synchronisation : l'identité et le LIEU passent par la présence
## (rares, fiables) ; la position par la diffusion (fréquente, jetable). On ne
## dessine que les joueurs qui sont dans la même pièce que soi.

const CANAL := "mj-hub"
const VITESSE := 96.0              ## pixels par seconde
const RAYON := 6.0                 ## demi-largeur des pieds, pour les collisions
const CADENCE_ENVOI := 1.0 / 8.0
const RAPPEL := 1.5
const MODELES := "res://modeles/voxel/"
const UNITE := 16.0                ## pixels par unité du monde (une case)
## Les émotes : touches 1 à 4, une bulle au-dessus de la tête, visible de tous.
const EMOTES := ["!", "?", "<3", "zZ"]
## Le cycle du jour, calé sur l'heure universelle pour que tous les joueurs
## vivent la même heure : quinze minutes, dont quatre de nuit.
const CYCLE := 900.0
## La caméra : inclinée, de face, assez haute pour lire la place entière.
const INCLINAISON := 44.0
const DISTANCE := 27.0
const DISTANCE_PIECE := 18.0

## Les lieux du hub. Le village est dehors ; les trois autres sont des pièces
## bâties par le même outil, chacune avec sa zone de marche, ses meubles, sa
## sortie, son habitant, et — pour deux d'entre elles — le classement au mur
## et le portail qui lance le jeu. Les positions sont en pixels du lieu.
const LIEUX := {
	"village": {
		"nom": "Village",
		"pnj": [{"nom": "paysanne", "position": Vector2(352, 416), "phrases": [
			"Salut {pseudo}. Trois portes ouvertes : la taverne, l'armurerie, l'auberge.",
			"La taverne mène au Carnage, l'armurerie à l'Énigme, l'auberge à la Bousculade.",
			"Le champion du Carnage, c'est {champion_carnage}. À l'Énigme, {champion_enigme}. À la Bousculade, {champion_bousculade}.",
			"Les réverbères s'allument tout seuls le soir. Personne ne sait qui les entretient.",
			"Chaque arche donne sur un monde qui n'est pas fait de la même pâte que le nôtre.",
			"Le tableau, là-bas au coin de la place, dit qui a joué en dernier.",
		]}],
	},
	"taverne": {
		"nom": "Taverne",
		"rangs": 5,
		"jeu": "carnage",
		"titre": "CARNAGE",
		"monde": 0,
		"couleur": Color("#ff9a3c"),
		"pnj": [{"nom": "serveuse", "position": Vector2(48, 112), "phrases": [
			"Une chope ? Non ? Alors pousse-toi, j'ai des tables.",
			"Le patron dit que les vainqueurs boivent gratis. Il ment.",
		]}, {"nom": "taverniere", "position": Vector2(72, 40), "phrases": [
			"Dehors, la ville est à prendre. Vole une voiture, et ne freine pas.",
			"Trois bandes tiennent les rues. Saigne-en une et sa rivale t'ouvrira sa porte.",
			"Cinq étoiles au compteur ? Le garage bleu te repeint, et la police t'oublie.",
			"Décroche à une cabine : ils paient pour ce qu'ils n'osent pas faire eux-mêmes.",
			"Descends de voiture quand il le faut — mais à pied, tout te fait mal deux fois.",
			"Les deux esplanades cerclées de rouge, c'est là qu'on règle ses comptes entre nous.",
			"Regarde par l'arche du fond : là-bas rien n'est taillé au cube. C'est une autre matière.",
			"On y va à deux, à trois, à quatre. Personne n'en revient tout à fait pareil.",
		]}],
	},
	"armurerie": {
		"nom": "Armurerie",
		"rangs": 5,
		"jeu": "enigme",
		"titre": "ÉNIGME",
		"monde": 1,
		"couleur": Color("#7fe0d6"),
		"pnj": [{"nom": "squelette", "position": Vector2(72, 88), "phrases": [
			"Trois chambres. Aucune ne s'ouvre à un seul.",
			"Une dalle ne reste enfoncée que si quelque chose pèse dessus — quelqu'un, ou une caisse.",
			"Et la sortie n'accepte l'équipe qu'au complet. Personne ne finit seul.",
			"Le portail est là, au fond. Regarde dedans : la pierre y est lisse, et froide.",
		]}],
	},
	"auberge": {
		"nom": "Auberge",
		"rangs": 5,
		"jeu": "bousculade",
		"titre": "BOUSCULADE",
		"monde": 2,
		"couleur": Color("#8fd0ff"),
		"pnj": [{"nom": "aubergiste", "position": Vector2(168, 72), "phrases": [
			"Chut, il y a des gens qui dorment. Ici on se repose entre deux parties.",
			"Derrière l'arche, l'île flotte. On s'y bouscule : le dernier debout gagne.",
			"Espace pour charger. Une charge dans le dos, et l'autre part dans le vide.",
			"L'île s'effrite par le bord. Reste au milieu, ou pousse plus fort que les autres.",
			"Tombé ? On te repêche au centre trois secondes plus tard. Mais l'autre a marqué.",
			"Par l'arche, on voit l'île. Elle est du même bois que nous, celle-là.",
		]}],
	},
	"maison": {"nom": "Maison", "ferme": "C'est fermé. Les habitants sont partis jouer au Carnage."},
	"grange": {"nom": "Grange", "ferme": "La grange donne sur la ferme. Elle ouvre bientôt : ça sent déjà le foin et les radis."},
}

## Le portail n'est pas une lueur : c'est une FENÊTRE. Le hub est en voxels,
## les jeux ne le sont pas — plutôt que de cacher l'écart, l'arche le montre.
## On voit derrière elle un aperçu du monde où l'on va : la ville de nuit du
## Carnage et ses fenêtres allumées, la pierre froide et les dalles de
## l'Énigme, le ciel et l'île de la Bousculade. Le passage est alors un
## passage, et le contraste devient une intention.
const FENETRE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform int monde = 0;
uniform float battement = 1.0;

float hache(vec2 p) { return fract(sin(dot(p, vec2(41.31, 289.17))) * 43758.5453); }

void fragment() {
	// UV part du HAUT en Godot ; on remet le ciel en haut et le sol en bas.
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec3 c;
	if (monde == 0) {
		// CARNAGE : une ville de nuit, des tours, des fenêtres, des phares.
		// De GRANDES formes : à travers une arche, l'image ne fait que
		// soixante pixels de haut à l'écran — un détail fin n'y est que du bruit.
		c = mix(vec3(0.58, 0.34, 0.40), vec3(0.08, 0.09, 0.26), uv.y);
		c = mix(c, vec3(1.0, 0.95, 0.86),
			smoothstep(0.07, 0.045, distance(uv * vec2(1.0, 2.2), vec2(0.74, 1.72))));
		vec2 g = floor(vec2(uv.x * 5.0, uv.y * 8.0));
		float haut = hache(vec2(g.x, 1.0)) * 0.40 + 0.26;
		if (uv.y < haut) {
			c = vec3(0.06, 0.06, 0.14);
			float allumee = step(0.66, hache(g));
			float vacille = step(0.15, fract(hache(g) * 9.0 + TIME * 0.13));
			c = mix(c, vec3(1.0, 0.74, 0.32), allumee * vacille);
		}
		for (int i = 0; i < 2; i++) {
			float f = float(i);
			float x = fract(TIME * (0.22 + f * 0.13) + f * 0.5);
			c += vec3(1.0, 0.90, 0.60) * smoothstep(0.09, 0.0, distance(uv, vec2(x, 0.06 + f * 0.05)));
		}
	} else if (monde == 1) {
		// ÉNIGME : une salle de pierre froide, des dalles qui s'allument.
		c = mix(vec3(0.52, 0.58, 0.64), vec3(0.20, 0.26, 0.32), uv.y);
		vec2 g = floor(uv * vec2(4.0, 6.0));
		float joint = step(0.09, fract(uv.x * 4.0)) * step(0.09, fract(uv.y * 6.0));
		c *= 0.66 + 0.34 * joint;
		float pulse = 0.5 + 0.5 * sin(TIME * 1.4 + hache(g) * 6.28);
		float active = step(0.72, hache(g));
		c = mix(c, vec3(0.55, 1.0, 0.92), active * pulse);
	} else {
		// BOUSCULADE : le grand ciel, et l'île qui flotte dans le vide.
		c = mix(vec3(0.62, 0.80, 0.94), vec3(0.16, 0.42, 0.80), uv.y);
		for (int i = 0; i < 3; i++) {
			float f = float(i);
			vec2 p = vec2(fract(0.2 + f * 0.37 + TIME * (0.014 + f * 0.006)), 0.62 + f * 0.11);
			c = mix(c, vec3(1.0), smoothstep(0.13, 0.02, distance(uv * vec2(1.0, 1.9), p * vec2(1.0, 1.9))) * 0.85);
		}
		float d = distance(uv * vec2(1.0, 0.7), vec2(0.5, 0.24 + 0.012 * sin(TIME * 0.7)));
		c = mix(c, vec3(0.34, 0.60, 0.30), smoothstep(0.20, 0.17, d));
		c = mix(c, vec3(0.46, 0.36, 0.28), smoothstep(0.17, 0.13, d) * step(0.30, uv.y * -1.0 + 0.62));
	}
	// Le bord de l'arche se fond dans la pierre : une image nette au ras du
	// mur ressemblerait à une affiche collée, pas à une ouverture.
	float bord = min(min(uv.x, 1.0 - uv.x) * 3.4, min(uv.y, 1.0 - uv.y) * 3.4);
	c *= smoothstep(0.0, 0.14, bord);
	// Une fenêtre laisse passer la lumière : elle est plus claire que la
	// pièce, sinon l'arche n'est qu'un trou noir dans un mur.
	ALBEDO = c * (1.35 + 0.2 * battement);
}
"""
static var _fenetre: Shader

static var _carte: Dictionary = {}

static func carte() -> Dictionary:
	if _carte.is_empty():
		var texte := FileAccess.get_file_as_string(MODELES + "plan.json")
		_carte = JSON.parse_string(texte) as Dictionary
	return _carte

static func rect_de(valeur) -> Rect2:
	if valeur == null:
		return Rect2()
	var v: Array = valeur
	return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))

## Un point du plan (pixels) → le monde (unités), au sol.
static func au_sol(plan_px: Vector2, hauteur: float = 0.0) -> Vector3:
	return Vector3(plan_px.x / UNITE, hauteur, plan_px.y / UNITE)

var _canal: CanalTempsReel
var _camera: Camera3D
var _lieu := "village"
var _position := Vector2.ZERO
var _marche := false
var _autres: Dictionary = {}       # cle -> {cible, affichee, pseudo, noeud}
var _corps: Pantin
var _bloque: PackedStringArray = []   # une ligne par rangée de cases, `#` = bloqué
var _bloque_aussi: Dictionary = {}    # cases prises à l'exécution (les PNJ)
var _case := 16
var _taille := Vector2.ZERO
var _portes: Array = []            # {rect, lieu, nom}
var _sortie := Rect2()
var _portail := Rect2()
var _jeu_du_lieu := ""
var _titre_du_lieu := ""
var _pnj: Array = []               # {position, phrases, noeud}
var _pnj_proche := -1
var _phrase := -1
var _depuis_envoi := 0.0
var _depuis_rappel := 0.0
var _invite := ""
var _depuis_pas := 0.0

var _soleil: DirectionalLight3D
var _contre_jour: DirectionalLight3D
var _environnement: Environment
var _ciel: ProceduralSkyMaterial
var _lumieres: Array[OmniLight3D] = []
var _vitres: Array[MeshInstance3D] = []
var _lucioles: CPUParticles3D
var _eau: MeshInstance3D
var _portail_lueur: MeshInstance3D
var _feu_lumiere: OmniLight3D

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
var _tableau: Label3D
var _affichage: Label3D
var _journal: Array = []
var _classements: Dictionary = {}
var _tchat_lignes: VBoxContainer
var _tchat_champ: LineEdit
var _tchat_bouton: Button
var _depuis_message := 9.0

func demarrer() -> void:
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.5
	_camera.far = 400.0
	monde().add_child(_camera)
	_camera.make_current()

	_construire_hud()
	Maquette.poser(self, 0.6, 4.5)
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
		elif a.begins_with("--tchat="):
			var texte := a.substr(8).replace("_", " ")
			get_tree().create_timer(3.0).timeout.connect(func() -> void: _dire(texte))
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
	Scores.demander_classement("bousculade", 5)
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

	for enfant in monde().get_children():
		if enfant != _camera:
			enfant.queue_free()
	_autres.clear()
	_lumieres.clear()
	_vitres.clear()
	_lucioles = null
	_eau = null
	_portail_lueur = null
	_feu_lumiere = null
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

	_eclairer(lieu == "village")
	if lieu == "village":
		_batir_village(geometrie)
	else:
		_batir_piece(lieu, geometrie)
	for pnj in fiche.get("pnj", []):
		_poser_pnj(pnj)

	var depart := Vector2.ZERO
	if geometrie.has("depart"):
		depart = Vector2(float(geometrie["depart"][0]), float(geometrie["depart"][1]))
	else:
		# Dans une pièce, on arrive sur la sortie.
		depart = _sortie.get_center() + Vector2(0, 2)
	_position = arrivee if arrivee != Vector2.ZERO else depart
	_corps = Pantin.depuis(MODELES + "heros_%s.glb" % _heros_connu(Session.heros_affiche()))
	_corps.position = au_sol(_position)
	_corps.cap = PI if lieu == "village" else PI   # on entre en regardant vers le nord
	_corps.rotation.y = _corps.cap
	monde().add_child(_corps)

	_camera.position = _position_camera(true)
	_camera.rotation_degrees = Vector3(-INCLINAISON, 0, 0)

	if _canal and _canal.est_rejoint:
		_canal.suivre({"pseudo": Session.pseudo, "id": Session.id, "lieu": _lieu, "heros": Session.heros_affiche()})
	# Dehors, le thème du village sur un fond de forêt ; dans la taverne, son
	# propre air ; dans les autres pièces, le village continue, étouffé.
	Sons.musique("taverne" if lieu == "taverne" else "village")
	Sons.ambiance("foret" if lieu == "village" else "")
	_rafraichir_hud()

static func _heros_connu(nom: String) -> String:
	return nom if nom in ["knight", "rogue", "wizzard"] else "knight"

## Où la caméra doit être : au-dessus et devant le joueur, inclinée, sans
## jamais montrer au-delà du village ; une pièce se cadre en entier.
func _position_camera(immediat: bool = false) -> Vector3:
	var cible: Vector3
	var distance := DISTANCE
	if _lieu == "village":
		var marge := Vector2(13.0, 9.0)
		var p := _position / UNITE
		p.x = clamp(p.x, marge.x, _taille.x / UNITE - marge.x)
		p.y = clamp(p.y, marge.y + 2.0, _taille.y / UNITE - marge.y + 4.0)
		cible = Vector3(p.x, 0.0, p.y - 2.5)
	else:
		cible = Vector3(_taille.x / UNITE * 0.5, 0.0, _taille.y / UNITE * 0.5 + 0.6)
		distance = DISTANCE_PIECE
	var incl := deg_to_rad(INCLINAISON)
	return cible + Vector3(0, sin(incl) * distance, cos(incl) * distance)

# ---------------------------------------------------------------- le décor

## Ciel, soleil, contre-jour : le village a un vrai jour ; les pièces, une
## lumière constante et chaude.
func _eclairer(dehors: bool) -> void:
	_environnement = Environment.new()
	_ciel = ProceduralSkyMaterial.new()
	_ciel.sky_top_color = Color("#3d7fd6")
	_ciel.sky_horizon_color = Color("#bcd8f2")
	_ciel.ground_bottom_color = Color("#3a5a2e")
	_ciel.ground_horizon_color = Color("#8fb37a")
	_ciel.sun_angle_max = 20.0
	var voute := Sky.new()
	voute.sky_material = _ciel
	_environnement.background_mode = Environment.BG_SKY
	_environnement.sky = voute
	_environnement.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environnement.ambient_light_sky_contribution = 1.0
	_environnement.ambient_light_energy = 0.55
	_environnement.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environnement.tonemap_white = 4.0
	_environnement.tonemap_exposure = 1.05
	if dehors:
		_environnement.fog_enabled = true
		_environnement.fog_light_color = Color("#c9dcee")
		_environnement.fog_density = 0.0012
	_environnement.glow_enabled = true
	_environnement.glow_intensity = 0.35
	_environnement.glow_bloom = 0.05
	_environnement.glow_hdr_threshold = 1.1
	var noeud := WorldEnvironment.new()
	noeud.environment = _environnement
	monde().add_child(noeud)

	_soleil = DirectionalLight3D.new()
	_soleil.light_color = Color("#fff3df")
	_soleil.light_energy = 1.5
	_soleil.rotation_degrees = Vector3(-58, -34, 0)
	_soleil.shadow_enabled = not ("--sans-ombres" in OS.get_cmdline_args())
	_soleil.directional_shadow_max_distance = 48.0
	_soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_soleil.shadow_bias = 0.8
	_soleil.shadow_normal_bias = 6.0
	_soleil.shadow_blur = 1.6
	monde().add_child(_soleil)
	_contre_jour = DirectionalLight3D.new()
	_contre_jour.light_color = Color("#9fb8e0")
	_contre_jour.light_energy = 0.35
	_contre_jour.rotation_degrees = Vector3(-30, 140, 0)
	monde().add_child(_contre_jour)

## Un modèle du dépôt, mis en cache par `Decor.maillage`.
static func _modele(nom: String) -> Mesh:
	return Decor.maillage(MODELES + nom + ".glb")

func _batir_village(geometrie: Dictionary) -> void:
	var terrain := MeshInstance3D.new()
	terrain.mesh = _modele("terrain_village")
	monde().add_child(terrain)
	# Les objets du plan, regroupés par modèle : une nappe d'instances par
	# modèle (trois cents arbres, quatre appels de dessin).
	var par_modele: Dictionary = {}
	for objet in geometrie["objets"]:
		var nom := String(objet["modele"])
		if not par_modele.has(nom):
			par_modele[nom] = []
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(objet.get("rot", 0)))),
			Vector3(float(objet["x"]) / UNITE, float(objet.get("h", 0.0)), float(objet["y"]) / UNITE))
		par_modele[nom].append(t)
	for nom in par_modele:
		var transformations: Array = par_modele[nom]
		var nappe := Decor.nappe(MODELES + nom + ".glb", transformations, not nom.begins_with("fleur") and nom != "touffe")
		monde().add_child(nappe)
	# Les portes : une enseigne au-dessus de chacune.
	for porte in geometrie["portes"]:
		var rect := Rect2(float(porte["x"]), float(porte["y"]), float(porte["l"]), float(porte["h"]))
		_portes.append({"rect": rect, "lieu": String(porte["lieu"]), "nom": String(porte["nom"])})
		var enseigne := _ecriteau(String(porte["nom"]), 0.3)
		enseigne.position = au_sol(rect.get_center() + Vector2(0, -rect.size.y * 0.5), 3.3) + Vector3(0, 0, 0.15)
		monde().add_child(enseigne)
	# Le feu de camp : des flammes qui montent, une lumière qui vacille.
	var feu := au_sol(Vector2(float(geometrie["feu"][0]), float(geometrie["feu"][1])), 0.25)
	monde().add_child(_flammes(feu, 0.6))
	_feu_lumiere = _lampe(feu + Vector3(0, 1.2, 0), Color(1.0, 0.7, 0.4), 9.0, 2.0)
	# La mare : une nappe d'eau translucide, un peu sous la rive.
	_eau = _nappe_d_eau(geometrie["mare"])
	monde().add_child(_eau)
	# Les fenêtres et les cheminées des maisons.
	for vitre in geometrie.get("fenetres", []):
		var v := Vector3(float(vitre[0]), float(vitre[1]), float(vitre[2]))
		_vitres.append(_lueur_de_fenetre(v))
		_lumieres.append(_lampe(v + Vector3(0, 0, 0.6), Color(1.0, 0.8, 0.5), 4.0, 0.0))
	for cheminee in geometrie.get("fumees", []):
		monde().add_child(_fumee(Vector3(float(cheminee[0]), float(cheminee[1]), float(cheminee[2]))))
	for porte in geometrie["portes"]:
		var p := au_sol(Vector2(float(porte["x"]) + float(porte["l"]) * 0.5, float(porte["y"])), 1.6)
		_lumieres.append(_lampe(p, Color(1.0, 0.85, 0.6), 4.5, 0.0))
	# Les réverbères : une lueur dans la cage, une lumière chaude au sol.
	for lanterne in geometrie.get("lanternes", []):
		var l := Vector3(float(lanterne[0]), float(lanterne[1]), float(lanterne[2]))
		var lueur := Decor.boite(Vector3(0.3, 0.4, 0.3), Color(1.0, 0.86, 0.5), false)
		lueur.material_override = Decor.matiere_lumineuse(Color(1.0, 0.86, 0.5), 1.5)
		lueur.position = l
		lueur.visible = false
		monde().add_child(lueur)
		_vitres.append(lueur)
		_lumieres.append(_lampe(l + Vector3(0, -0.3, 0), Color(1.0, 0.8, 0.5), 6.5, 0.0))
	_semer_les_lucioles()
	_semer_les_feuilles()
	# Le tableau d'affichage de la place : les dernières parties jouées.
	var cadre: Array = geometrie["tableau"]
	_affichage = _inscription(Vector3(float(cadre[0]) - float(cadre[3]) * 0.5 + 0.4, float(cadre[1]), float(cadre[2])), 0.33, HORIZONTAL_ALIGNMENT_LEFT)
	monde().add_child(_affichage)
	_rafraichir_affichage()

func _batir_piece(lieu: String, geometrie: Dictionary) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = _modele("piece_" + lieu)
	monde().add_child(piece)
	# Une lumière chaude au plafond ; les fenêtres éclairent un peu.
	var centre := Vector3(_taille.x / UNITE * 0.5, 3.4, _taille.y / UNITE * 0.5)
	_lampe(centre, Color(1.0, 0.92, 0.8), 16.0, 1.1)
	for vitre in geometrie.get("fenetres", []):
		_lampe(Vector3(float(vitre[0]), float(vitre[1]), float(vitre[2]) + 0.8), Color(0.8, 0.9, 1.0), 4.0, 0.5)
	if _portail != Rect2():
		# L'arche s'ouvre sur l'autre monde : on voit ce qui attend derrière.
		var fiche: Dictionary = LIEUX[lieu]
		if _fenetre == null:
			_fenetre = Shader.new()
			_fenetre.code = FENETRE
		var vue := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.5, 2.5)
		vue.mesh = q
		var m := ShaderMaterial.new()
		m.shader = _fenetre
		m.set_shader_parameter("monde", int(fiche.get("monde", 0)))
		vue.material_override = m
		# Devant le fond noir de l'arche, pas dedans : la case de voxels du
		# fond occupe z ∈ [-1/8, 0], une nappe posée à -0,05 disparaît derrière.
		vue.position = Vector3(_portail.get_center().x / UNITE, 1.3, 0.06)
		monde().add_child(vue)
		_portail_lueur = vue
		# La lueur qui déborde de l'arche porte la couleur du monde d'en face.
		var couleur: Color = fiche.get("couleur", Palette.SERIE)
		_lampe(vue.position + Vector3(0, 0, 1.0), couleur, 7.0, 1.5)
		var enseigne := _ecriteau(String(fiche.get("titre", "")), 0.2)
		enseigne.modulate = couleur
		enseigne.position = vue.position + Vector3(0, 1.5, 0.1)
		monde().add_child(enseigne)
	if geometrie.has("tableau"):
		var cadre: Array = geometrie["tableau"]
		_tableau = _inscription(Vector3(float(cadre[0]), float(cadre[1]), float(cadre[2])), 0.3, HORIZONTAL_ALIGNMENT_CENTER)
		monde().add_child(_tableau)
		_rafraichir_tableau()

## Une lampe ponctuelle ; `energie` 0 = éteinte (allumée à la nuit).
func _lampe(position: Vector3, couleur: Color, portee: float, energie: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = position
	l.visible = energie > 0.0
	monde().add_child(l)
	return l

## La vitre allumée : un petit pavé émissif devant la fenêtre, éteint le jour.
func _lueur_de_fenetre(position: Vector3) -> MeshInstance3D:
	var v := Decor.boite(Vector3(0.62, 0.62, 0.06), Color(1.0, 0.82, 0.45), false)
	v.material_override = Decor.matiere_lumineuse(Color(1.0, 0.82, 0.45), 1.4)
	v.position = position + Vector3(0, 0, 0.02)
	v.visible = false
	monde().add_child(v)
	return v

func _flammes(position: Vector3, taille: float) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 28
	f.lifetime = 0.9
	f.preprocess = 1.0
	f.position = position
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = taille * 0.4
	f.direction = Vector3.UP
	f.spread = 12.0
	f.gravity = Vector3(0, 2.5, 0)
	f.initial_velocity_min = 0.8
	f.initial_velocity_max = 1.6
	f.scale_amount_min = taille * 0.5
	f.scale_amount_max = taille
	f.scale_amount_curve = _courbe([[0.0, 1.0], [1.0, 0.1]])
	var teinte := Gradient.new()
	teinte.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	teinte.add_point(0.4, Color(1.0, 0.5, 0.1, 1.0))
	teinte.set_color(1, Color(0.6, 0.1, 0.05, 0.0))
	f.color_ramp = teinte
	var cube := BoxMesh.new()
	cube.size = Vector3(0.25, 0.25, 0.25)
	f.mesh = cube
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.1)
	m.emission_energy_multiplier = 1.5
	cube.material = m
	return f

func _fumee(position: Vector3) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 12
	f.lifetime = 5.0
	f.preprocess = 5.0
	f.position = position
	f.direction = Vector3(0.3, 1.0, 0.0)
	f.spread = 10.0
	f.gravity = Vector3(0.35, 0.25, 0.0)
	f.initial_velocity_min = 0.3
	f.initial_velocity_max = 0.6
	f.scale_amount_min = 0.5
	f.scale_amount_max = 0.8
	f.scale_amount_curve = _courbe([[0.0, 0.4], [0.5, 1.0], [1.0, 1.7]])
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.9, 0.9, 0.92, 0.0))
	teinte.add_point(0.2, Color(0.9, 0.9, 0.92, 0.55))
	teinte.set_color(1, Color(0.9, 0.9, 0.92, 0.0))
	f.color_ramp = teinte
	var cube := BoxMesh.new()
	cube.size = Vector3(0.4, 0.4, 0.4)
	f.mesh = cube
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	cube.material = m
	return f

## L'eau de la mare : un carreau par case d'eau, un peu sous la rive,
## translucide et brillant ; il ondule doucement.
func _nappe_d_eau(mare: Dictionary) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := float(mare.get("niveau", -0.35))
	for c in mare["cases"]:
		var x0 := float(c[0])
		var z0 := float(c[1])
		var coins := [Vector3(x0, y, z0), Vector3(x0 + 1, y, z0), Vector3(x0 + 1, y, z0 + 1), Vector3(x0, y, z0 + 1)]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)       # avant CHAQUE sommet : l'attribut se pose, il ne se retient pas
			st.add_vertex(coins[i])
	var eau := MeshInstance3D.new()
	eau.mesh = st.commit()
	var m := StandardMaterial3D.new()
	# Une eau peu profonde : on voit le sable au fond, la surface ajoute sa
	# couleur plutôt qu'elle ne l'éteint. Sans un peu d'émission, une nappe
	# transparente sans réflexion tombe au noir dès qu'elle n'est pas au
	# soleil — et la mare devient un trou.
	# Une nappe d'eau SANS éclairage : le sable du fond transparaît, la
	# couleur reste la même au soleil comme sous les arbres. Éclairée, une
	# mare à l'ombre de la forêt tourne au gris de flaque — et c'était le cas.
	m.albedo_color = Color(0.36, 0.66, 0.80, 0.62)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	eau.material_override = m
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return eau

func _semer_les_lucioles() -> void:
	_lucioles = CPUParticles3D.new()
	_lucioles.amount = 60
	_lucioles.lifetime = 4.0
	_lucioles.preprocess = 4.0
	_lucioles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_lucioles.emission_box_extents = Vector3(_taille.x / UNITE * 0.5, 0.5, _taille.y / UNITE * 0.5)
	_lucioles.position = Vector3(_taille.x / UNITE * 0.5, 1.2, _taille.y / UNITE * 0.5)
	_lucioles.gravity = Vector3.ZERO
	_lucioles.initial_velocity_min = 0.2
	_lucioles.initial_velocity_max = 0.5
	_lucioles.spread = 180.0
	var lueur := Gradient.new()
	lueur.set_color(0, Color(1.0, 0.95, 0.5, 0.0))
	lueur.add_point(0.5, Color(1.0, 0.95, 0.5, 1.0))
	lueur.set_color(1, Color(1.0, 0.95, 0.5, 0.0))
	_lucioles.color_ramp = lueur
	var cube := BoxMesh.new()
	cube.size = Vector3(0.08, 0.08, 0.08)
	cube.material = Decor.matiere_lumineuse(Color(1.0, 0.95, 0.5), 1.6, 0.9)
	(cube.material as StandardMaterial3D).vertex_color_use_as_albedo = true
	_lucioles.mesh = cube
	_lucioles.emitting = false
	monde().add_child(_lucioles)

## Des feuilles qui tombent de la lisière : assez pour que le village
## respire, pas assez pour qu'on les remarque une à une.
func _semer_les_feuilles() -> void:
	var f := CPUParticles3D.new()
	f.amount = 40
	f.lifetime = 8.0
	f.preprocess = 8.0
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(_taille.x / UNITE * 0.5, 0.2, _taille.y / UNITE * 0.5)
	f.position = Vector3(_taille.x / UNITE * 0.5, 5.0, _taille.y / UNITE * 0.5)
	f.direction = Vector3(1, -1, 0.3)
	f.spread = 20.0
	f.gravity = Vector3(0.4, -0.6, 0.2)
	f.initial_velocity_min = 0.3
	f.initial_velocity_max = 0.8
	f.angular_velocity_min = -90.0
	f.angular_velocity_max = 90.0
	var teintes := Gradient.new()
	teintes.set_color(0, Color(0.45, 0.62, 0.20))
	teintes.set_color(1, Color(0.70, 0.48, 0.16))
	f.color_ramp = teintes
	var cube := BoxMesh.new()
	cube.size = Vector3(0.12, 0.03, 0.12)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	cube.material = m
	f.mesh = cube
	monde().add_child(f)

static func _courbe(points: Array) -> Curve:
	var courbe := Curve.new()
	for p in points:
		courbe.add_point(Vector2(float(p[0]), float(p[1])))
	return courbe

# ---------------------------------------------------------------- inscriptions

## Un texte posé dans le monde, en police pixel, face au sud.
func _inscription(position: Vector3, taille: float, alignement: HorizontalAlignment) -> Label3D:
	var e := Label3D.new()
	e.font = UI.TITRE_POLICE
	e.font_size = 32
	e.pixel_size = taille / 32.0
	e.modulate = Color(0.93, 0.88, 0.74)
	e.horizontal_alignment = alignement
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	e.position = position
	e.no_depth_test = false
	e.shaded = false
	e.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	e.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	return e

## Une enseigne ou un nom au-dessus d'une tête : blanc cerné de noir.
func _ecriteau(texte: String, taille: float) -> Label3D:
	var e := _inscription(Vector3.ZERO, taille, HORIZONTAL_ALIGNMENT_CENTER)
	e.text = texte
	e.modulate = Palette.ENCRE
	e.outline_modulate = Color(0, 0, 0, 0.9)
	e.outline_size = 8
	return e

func _etiquette_flottante(texte: String, taille: float) -> Label3D:
	var e := _ecriteau(texte, taille)
	e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	e.no_depth_test = true
	return e

func _sur_journal(lignes: Array) -> void:
	_journal = lignes
	_rafraichir_affichage()

func _rafraichir_affichage() -> void:
	if _affichage == null or not is_instance_valid(_affichage):
		return
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
		"champion_bousculade": _champion("bousculade"),
	})

func _champion(jeu: String) -> String:
	var lignes: Array = _classements.get(jeu, [])
	if lignes.is_empty():
		return "personne encore"
	return String(lignes[0].get("pseudo", "?"))

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

# ---------------------------------------------------------------- habitants

func _poser_pnj(pnj: Dictionary) -> void:
	var nom := String(pnj["nom"])
	var pantin := Pantin.depuis(MODELES + "pnj_%s.glb" % nom)
	var position: Vector2 = (pnj["position"] as Vector2).round()
	pantin.position = au_sol(position)
	monde().add_child(pantin)
	var fiche := {"position": position, "phrases": pnj["phrases"], "noeud": pantin}
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
		_bloque_aussi[Vector2i(int(position.x) / _case, int(position.y) / _case)] = true
	_pnj.append(fiche)

const PAS_DE_RONDE := 34.0

func _faire_les_rondes(delta: float) -> void:
	for i in _pnj.size():
		var pnj: Dictionary = _pnj[i]
		var noeud: Pantin = pnj["noeud"]
		var position: Vector2 = pnj["position"]
		# Face au joueur qui vient parler, on ne bouge plus.
		if _position.distance_to(position) < 34.0:
			noeud.marche = false
			noeud.regarder(_position - position)
			continue
		if not pnj.has("chemin"):
			continue
		if float(pnj["pause"]) > 0.0:
			pnj["pause"] = float(pnj["pause"]) - delta
			noeud.marche = false
			continue
		var chemin: Array = pnj["chemin"]
		var cible: Vector2 = chemin[int(pnj["etape"])]
		var vers := cible - position
		var pas := PAS_DE_RONDE * delta
		if vers.length() <= pas:
			position = cible
			pnj["etape"] = (int(pnj["etape"]) + 1) % chemin.size()
			pnj["pause"] = 1.5
			noeud.marche = false
		else:
			position += vers.normalized() * pas
			noeud.regarder(vers)
			noeud.marche = true
		pnj["position"] = position
		noeud.position = au_sol(position)

# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	_faire_les_rondes(delta)
	_tomber_la_nuit(delta)
	_depuis_message += delta
	Commandes.saisie = _tchat_champ != null and _tchat_champ.has_focus()
	var direction := Commandes.direction()
	if direction != Vector2.ZERO:
		var avant := _position
		_position.x += direction.x * VITESSE * delta
		_degager(avant)
		avant = _position
		_position.y += direction.y * VITESSE * delta
		_degager(avant)
		_borner()
		_corps.regarder(direction)
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
	_corps.marche = _marche
	_corps.position = au_sol(_position)

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var vers: Vector2 = (a["cible"] as Vector2) - (a["affichee"] as Vector2)
		a["affichee"] = (a["affichee"] as Vector2).lerp(a["cible"], clampf(delta * 12.0, 0.0, 1.0))
		var noeud: Pantin = a["noeud"]
		noeud.position = au_sol(a["affichee"])
		var bouge := vers.length() > 2.0
		noeud.marche = bouge
		if bouge:
			noeud.regarder(vers)

	_camera.position = _camera.position.lerp(_position_camera(), clampf(delta * 6.0, 0.0, 1.0))
	if _portail_lueur:
		var battement := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0024)
		(_portail_lueur.material_override as ShaderMaterial).set_shader_parameter("battement", battement)
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
		KEY_ENTER, KEY_KP_ENTER, KEY_T:
			_ouvrir_le_tchat()
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
		var teinte: Color = LIEUX[_lieu].get("couleur", Palette.SERIE)
		_fondu(teinte, 0.7, func() -> void: demande_ecran.emit("salon", {"jeu": jeu, "titre": titre}))
	elif _invite == "parler" and _pnj_proche >= 0:
		var phrases: Array = _pnj[_pnj_proche]["phrases"]
		_phrase = (_phrase + 1) % (phrases.size() + 1)
		Sons.jouer("clic", 1.2, -16.0)
		_rafraichir_hud()

# ---------------------------------------------------------------- réseau

func _sur_diffusion(evenement: String, charge: Dictionary) -> void:
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.cle:
		return
	if evenement == "chat":
		_recevoir_message(cle, charge)
		return
	if not _autres.has(cle):
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
			(_autres[cle]["noeud"] as Node3D).queue_free()
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
			var pantin := Pantin.depuis(MODELES + "heros_%s.glb" % _heros_connu(heros))
			pantin.position = au_sol(_position)
			monde().add_child(pantin)
			var nom := _etiquette_flottante(_titre(String(meta.get("pseudo", "?"))), 0.22)
			nom.position = Vector3(0, 2.75, 0)
			nom.name = "nom"
			pantin.add_child(nom)
			_autres[cle] = {"cible": _position, "affichee": _position,
				"pseudo": String(meta.get("pseudo", "?")), "noeud": pantin}
	_rafraichir_hud()

## Le premier d'un classement porte une étoile devant son nom : le village
## sait qui est le champion, sans qu'on ait à ouvrir un tableau.
func _titre(pseudo: String) -> String:
	for jeu in _classements:
		var lignes: Array = _classements[jeu]
		if not lignes.is_empty() and String(lignes[0].get("pseudo", "")) == pseudo:
			return "* " + pseudo
	return pseudo

# ---------------------------------------------------------------- le tchat

const TCHAT_MAX := 140
const TCHAT_LIGNES := 6

func _ouvrir_le_tchat() -> void:
	if _tchat_champ == null or _tchat_champ.has_focus():
		return
	_tchat_champ.visible = true
	_tchat_champ.grab_focus()
	_rafraichir_hud()

func _fermer_le_tchat() -> void:
	_tchat_champ.release_focus()
	_tchat_champ.visible = Tactile.actif()
	Commandes.saisie = false
	_rafraichir_hud()

## Ce qu'on tape part à tous ceux du hub, quelle que soit leur pièce.
func _dire(texte: String) -> void:
	var propre := texte.strip_edges().left(TCHAT_MAX)
	_tchat_champ.text = ""
	_fermer_le_tchat()
	if propre == "" or _depuis_message < 1.2:
		return
	_depuis_message = 0.0
	_ajouter_au_tchat(Session.pseudo, propre, "", true)
	_bulle(_corps, propre)
	Sons.jouer("clic", 1.3, -20.0)
	if _canal:
		_canal.envoyer("chat", {"t": propre, "l": _lieu})

func _recevoir_message(cle: String, charge: Dictionary) -> void:
	var texte := String(charge.get("t", "")).strip_edges().left(TCHAT_MAX)
	if texte == "":
		return
	var pseudo := "?"
	if _canal and _canal.presences.has(cle):
		pseudo = String(_canal.presences[cle].get("pseudo", "?"))
	elif _autres.has(cle):
		pseudo = String(_autres[cle]["pseudo"])
	var lieu := String(charge.get("l", ""))
	_ajouter_au_tchat(pseudo, texte, "" if lieu == _lieu else String(LIEUX.get(lieu, {}).get("nom", lieu)), false)
	if _autres.has(cle):
		_bulle(_autres[cle]["noeud"], texte)
	Sons.jouer("clic", 0.9, -22.0)

## Une ligne du fil : « pseudo — texte », l'origine entre crochets si elle
## parle d'une autre pièce ; la ligne s'efface d'elle-même au bout d'un moment.
func _ajouter_au_tchat(pseudo: String, texte: String, origine: String, moi: bool) -> void:
	if _tchat_lignes == null:
		return
	var ligne := RichTextLabel.new()
	ligne.bbcode_enabled = true
	ligne.fit_content = true
	ligne.scroll_active = false
	ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ligne.custom_minimum_size = Vector2(420, 0)
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_font_override("normal_font", UI.TEXTE_POLICE)
	ligne.add_theme_font_size_override("normal_font_size", UI.taille_texte(14))
	ligne.add_theme_font_override("bold_font", UI.TEXTE_POLICE)
	ligne.add_theme_font_size_override("bold_font_size", UI.taille_texte(14))
	var couleur := Palette.SERIE if moi else Palette.AVERTISSEMENT
	var prefixe := ("[color=#%s][%s][/color] " % [Palette.ENCRE_FAIBLE.to_html(false), origine]) if origine != "" else ""
	ligne.text = "%s[b][color=#%s]%s[/color][/b] [color=#%s]%s[/color]" % [
		prefixe, couleur.to_html(false), pseudo, Palette.ENCRE.to_html(false), texte.replace("[", "［")]
	_tchat_lignes.add_child(ligne)
	while _tchat_lignes.get_child_count() > TCHAT_LIGNES:
		_tchat_lignes.get_child(0).free()
	var tween := create_tween()
	tween.tween_interval(14.0)
	tween.tween_property(ligne, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(ligne):
			ligne.queue_free())

## La bulle au-dessus de la tête : le texte, coupé en lignes courtes.
func _bulle(porteur: Node3D, texte: String) -> void:
	if porteur == null or not is_instance_valid(porteur):
		return
	var ancienne := porteur.get_node_or_null("bulle")
	if ancienne:
		ancienne.queue_free()
	var mots := texte.split(" ")
	var lignes: Array[String] = [""]
	for mot in mots:
		if lignes[-1].length() + mot.length() > 18 and lignes[-1] != "":
			lignes.append("")
		lignes[-1] = (lignes[-1] + " " + mot).strip_edges()
	var bulle := _etiquette_flottante("\n".join(lignes), 0.34)
	bulle.name = "bulle"
	bulle.modulate = Color(1.0, 0.96, 0.8)
	bulle.outline_modulate = Color(0.06, 0.06, 0.08, 0.95)
	bulle.outline_size = 10
	bulle.position = Vector3(0, 3.0 + 0.4 * lignes.size(), 0)
	porteur.add_child(bulle)
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(bulle, "modulate:a", 0.0, 0.6)
	tween.tween_callback(bulle.queue_free)

# ---------------------------------------------------------------- émotes

func _emote(indice: int) -> void:
	if indice < 0 or indice >= EMOTES.size():
		return
	_afficher_emote(_corps, EMOTES[indice])
	Sons.jouer("clic", 1.6, -18.0)
	if _canal:
		_canal.envoyer("emo", {"e": indice})

func _afficher_emote(porteur: Node3D, texte: String) -> void:
	if porteur == null or not is_instance_valid(porteur):
		return
	var ancienne := porteur.get_node_or_null("emote")
	if ancienne:
		ancienne.queue_free()
	var bulle := _etiquette_flottante(texte, 0.4)
	bulle.name = "emote"
	bulle.modulate = Palette.ENCRE
	bulle.outline_modulate = Palette.SERIE
	bulle.position = Vector3(0.4, 3.3, 0)
	porteur.add_child(bulle)
	var tween := create_tween()
	tween.tween_property(bulle, "position:y", 3.7, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.6)
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

func _tomber_la_nuit(_delta: float) -> void:
	if _soleil == null or not is_instance_valid(_soleil):
		return
	var nuit := _nuit() if _lieu == "village" else 0.0
	# Le jour est blanc ; le soir vire à l'ambre, la nuit au bleu profond.
	var soir := Color(1.0, 0.72, 0.5)
	var noir := Color(0.30, 0.38, 0.65)
	var teinte := Color.WHITE
	if nuit < 0.5:
		teinte = Color.WHITE.lerp(soir, nuit * 2.0)
	else:
		teinte = soir.lerp(noir, (nuit - 0.5) * 2.0)
	_soleil.light_color = Color("#fff3df") * teinte
	_soleil.light_energy = lerp(1.5, 0.18, nuit)
	_contre_jour.light_energy = lerp(0.35, 0.15, nuit)
	_environnement.ambient_light_energy = lerp(0.55, 0.4, nuit)
	if _ciel:
		_ciel.sky_top_color = Color("#3d7fd6").lerp(Color("#0a1230"), nuit)
		_ciel.sky_horizon_color = Color("#bcd8f2").lerp(Color("#2a3a5a"), nuit)
		_ciel.ground_horizon_color = Color("#8fb37a").lerp(Color("#1a2a1e"), nuit)
		_ciel.ground_bottom_color = Color("#3a5a2e").lerp(Color("#0a120c"), nuit)
	_environnement.fog_light_color = Color("#c9dcee").lerp(Color("#1a2438"), nuit)
	var vacillement := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.011) + 0.05 * sin(Time.get_ticks_msec() * 0.037)
	if _feu_lumiere:
		_feu_lumiere.light_energy = (0.9 + 2.4 * nuit) * vacillement
	var allume := nuit > 0.25
	for l in _lumieres:
		l.visible = allume
		l.light_energy = clampf((nuit - 0.25) * 1.6, 0.0, 1.0) * 1.1
	for v in _vitres:
		v.visible = allume
	if _lucioles:
		_lucioles.emitting = nuit > 0.6

# ---------------------------------------------------------------- le carnet

func _sur_carnet(lignes: Array) -> void:
	_carnet = lignes
	_rafraichir_carnet()

func _rafraichir_carnet() -> void:
	if _hud_carnet == null:
		return
	var parties := {"carnage": 0, "enigme": 0, "bousculade": 0}
	var meilleurs := {"carnage": 0, "enigme": 0, "bousculade": 0}
	for ligne in _carnet:
		var jeu := String(ligne.get("jeu", ""))
		if not meilleurs.has(jeu):
			continue
		parties[jeu] += 1
		meilleurs[jeu] = maxi(int(meilleurs[jeu]), int(ligne.get("score", 0)))
	var noms := {"knight": "chevalier", "rogue": "voleur", "wizzard": "mage"}
	var texte := "%s, %s\n\n" % [Session.pseudo, String(noms.get(Session.heros_affiche(), ""))]
	for jeu in ["carnage", "enigme", "bousculade"]:
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
		var nom: Label3D = (_autres[cle]["noeud"] as Node).get_node_or_null("nom")
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

	# Le tchat : le fil des derniers messages au-dessus du titre, et le champ
	# de saisie, qui n'apparaît que quand on parle (Entrée ou T).
	var tchat := VBoxContainer.new()
	tchat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tchat.offset_left = 20
	tchat.offset_right = 480
	tchat.offset_top = -330
	tchat.offset_bottom = -104
	tchat.alignment = BoxContainer.ALIGNMENT_END
	tchat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tchat.add_theme_constant_override("separation", 2)
	couche.add_child(tchat)
	_tchat_lignes = VBoxContainer.new()
	_tchat_lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tchat_lignes.add_theme_constant_override("separation", 2)
	tchat.add_child(_tchat_lignes)
	_tchat_champ = UI.champ("Dire quelque chose… (Entrée pour envoyer, Échap pour fermer)")
	_tchat_champ.custom_minimum_size = Vector2(440, 38)
	_tchat_champ.add_theme_font_size_override("font_size", UI.taille_texte(15))
	_tchat_champ.max_length = TCHAT_MAX
	_tchat_champ.visible = Tactile.actif()
	_tchat_champ.text_submitted.connect(_dire)
	_tchat_champ.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_tchat_champ.text = ""
			_fermer_le_tchat()
			_tchat_champ.accept_event())
	tchat.add_child(_tchat_champ)

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
		_: _hud_invite.text = "Z Q S D pour marcher · Entrée : parler · K : carnet · 1-4 : émotes"

	var parle := _invite == "parler" and _pnj_proche >= 0 and _phrase >= 0 \
		and _phrase < (_pnj[_pnj_proche]["phrases"] as Array).size()
	var porte_fermee: bool = _invite.begins_with("entrer:") and _phrase == 0 and LIEUX[_invite.substr(7)].has("ferme")
	_panneau_dialogue.visible = parle or porte_fermee
	if parle:
		_hud_dialogue.text = _phrase_du_monde(String(_pnj[_pnj_proche]["phrases"][_phrase]))
	elif porte_fermee:
		_hud_dialogue.text = String(LIEUX[_invite.substr(7)]["ferme"])
