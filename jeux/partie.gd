class_name Partie
extends Ecran
## Socle commun aux mini-jeux : canal de la manche, rôles, décompte, chrono,
## fin de manche et dépôt du score.
##
## Modèle retenu : un hôte parmi les joueurs, désigné par la clé la plus petite.
## Il simule tout ce qui est partagé (monstres, caisses, portes, score) et le
## diffuse ; chacun ne simule chez lui que son propre personnage, pour que la
## commande réponde à l'image et non au réseau. C'est le compromis habituel
## quand il n'y a pas de serveur : on accepte qu'un hôte malveillant puisse
## mentir, on refuse qu'un joueur honnête subisse 80 ms de latence sur ses
## propres touches.

enum { ATTENTE, DECOMPTE, JEU, FIN }

const DECOMPTE_S := 3.0
const ATTENTE_MAX := 8.0

## Raccourci de manche, réservé au banc d'essai (`--manche=<secondes>`).
## Attendre deux minutes par vérification, personne ne le fait deux fois.
static var duree_forcee := 0.0

var jeu: String = ""
var titre: String = ""
var code: String = ""
var canal: CanalTempsReel
var joueurs: Dictionary = {}       ## cle -> {pseudo, place, score}
var phase: int = ATTENTE
var temps: float = 0.0             ## secondes de jeu écoulées
var _attente: float = 0.0
var _decompte: float = DECOMPTE_S
var _attendus: int = 1

var _hud_chrono: Label
var _hud_scores: Label
var _hud_message: Label
var _hud_aide: Label
var _hud_etat: HBoxContainer

# ------------------------------------------------------- à redéfinir

func duree_manche() -> float:
	return 120.0

func aide() -> String:
	return ""

func preparer() -> void:
	pass

func simuler_local(_delta: float) -> void:
	pass

func simuler_hote(_delta: float) -> void:
	pass

func recevoir(_evenement: String, _charge: Dictionary) -> void:
	pass

## Appelée chaque image : les écrans de jeu y replacent leurs objets 3D. Le
## rendu est séparé de la simulation pour que l'interpolation d'affichage
## n'aille jamais polluer l'état partagé.
func rafraichir_scene(_delta: float) -> void:
	pass

func classement_final() -> Array:
	var lignes: Array = []
	for cle in joueurs:
		var j: Dictionary = joueurs[cle]
		lignes.append({
			# Le score se rattache à l'identité stable, pas à la clé d'onglet.
			"joueur_id": String(j.get("id", cle)),
			"pseudo": String(j.get("pseudo", "?")),
			"score": int(j.get("score", 0)),
			"place": int(j.get("place", 0)),
		})
	lignes.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	return lignes

# ------------------------------------------------------- cycle

func demarrer() -> void:
	jeu = String(donnees.get("jeu", "carnage"))
	titre = String(donnees.get("titre", jeu.to_upper()))
	code = String(donnees.get("code", "0"))
	var equipe: Array = donnees.get("equipe", [])
	_attendus = max(1, equipe.size())
	for membre in equipe:
		var cle := String(membre.get("cle", ""))
		if cle != "":
			joueurs[cle] = {
				"pseudo": String(membre.get("pseudo", "?")),
				"id": String(membre.get("id", cle)),
				"place": 0, "score": 0,
			}

	_construire_hud()
	preparer()

	canal = Reseau.rejoindre("mj-jeu-%s-%s" % [jeu, code], {"pseudo": Session.pseudo, "id": Session.id})
	canal.presences_changees.connect(_sur_presences)
	canal.diffusion.connect(_sur_diffusion)

func _exit_tree() -> void:
	if canal:
		canal.quitter()

func duree_reelle() -> float:
	return duree_forcee if duree_forcee > 0.0 else duree_manche()

func est_hote() -> bool:
	return canal != null and canal.je_suis_hote()

func ma_place() -> int:
	return int(joueurs.get(Session.cle, {}).get("place", 0))

func _sur_presences(presences: Dictionary) -> void:
	var cles := canal.cles_triees()
	# On garde les joueurs partis : leur score reste au tableau. Les effacer
	# ferait disparaître du classement quelqu'un qui a perdu sa connexion à
	# dix secondes de la fin.
	for cle in presences:
		if not joueurs.has(cle):
			joueurs[cle] = {"pseudo": "?", "id": cle, "place": 0, "score": 0}
		joueurs[cle]["pseudo"] = String(presences[cle].get("pseudo", "?"))
		joueurs[cle]["id"] = String(presences[cle].get("id", joueurs[cle].get("id", cle)))
	for cle in joueurs:
		var place := cles.find(cle)
		if place >= 0:
			joueurs[cle]["place"] = place
	_rafraichir_hud()

func _sur_diffusion(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"debut":
			if phase == ATTENTE:
				phase = DECOMPTE
				_decompte = DECOMPTE_S
		"score":
			var cle := String(charge.get("j", ""))
			if joueurs.has(cle):
				joueurs[cle]["score"] = int(charge.get("s", 0))
			_rafraichir_hud()
		"fin":
			if phase != FIN:
				phase = FIN
				_afficher_resultats(charge.get("classement", []), String(charge.get("note", "")))
		_:
			recevoir(evenement, charge)

func _process(delta: float) -> void:
	match phase:
		ATTENTE:
			_attente += delta
			var presents := canal.presences.size() if canal else 0
			if est_hote() and (presents >= _attendus or _attente > ATTENTE_MAX):
				canal.envoyer("debut", {})
				phase = DECOMPTE
				_decompte = DECOMPTE_S
		DECOMPTE:
			_decompte -= delta
			if _decompte <= 0.0:
				phase = JEU
				temps = 0.0
		JEU:
			temps += delta
			simuler_local(delta)
			if est_hote():
				simuler_hote(delta)
				if temps >= duree_reelle():
					terminer("Temps écoulé.")
	_rafraichir_hud()
	rafraichir_scene(delta)

## Fin de manche : seul l'hôte l'appelle. Il diffuse le classement ET le dépose,
## une fois. Quatre clients qui déposent, c'est quatre parties en base pour une
## seule jouée.
func terminer(note: String) -> void:
	if phase == FIN or not est_hote():
		return
	phase = FIN
	var lignes := classement_final()
	canal.envoyer("fin", {"classement": lignes, "note": note})
	var resultats: Array = []
	for ligne in lignes:
		resultats.append({
			"joueur_id": ligne["joueur_id"],
			"pseudo": ligne["pseudo"],
			"score": ligne["score"],
		})
	Scores.deposer(jeu, code, int(max(5.0, min(temps, duree_manche()))), resultats)
	_afficher_resultats(lignes, note)

func _afficher_resultats(lignes, note: String) -> void:
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	demande_ecran.emit("resultats", {
		"titre": titre + " — manche terminée",
		"jeu": jeu,
		"note": note,
		"classement": lignes,
	})

func ajouter_score(cle: String, points: int) -> void:
	if not joueurs.has(cle):
		return
	joueurs[cle]["score"] = max(0, int(joueurs[cle]["score"]) + points)
	canal.envoyer("score", {"j": cle, "s": int(joueurs[cle]["score"])})
	_rafraichir_hud()

# ------------------------------------------------------- interface

func _construire_hud() -> void:
	var couche := interface()

	var haut := HBoxContainer.new()
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 20
	haut.offset_right = -20
	haut.offset_top = 14
	haut.add_theme_constant_override("separation", 24)
	couche.add_child(haut)

	_hud_chrono = UI.titre("", 26)
	haut.add_child(_hud_chrono)
	_hud_scores = UI.texte("", 16, Palette.ENCRE_DOUCE)
	_hud_scores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(_hud_scores)
	_hud_etat = UI.etat_reseau()
	haut.add_child(_hud_etat)

	var bas := VBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = 20
	bas.offset_right = -20
	bas.offset_top = -70
	bas.offset_bottom = -18
	couche.add_child(bas)
	_hud_aide = UI.texte(aide(), 14, Palette.ENCRE_FAIBLE)
	bas.add_child(_hud_aide)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(centre)
	_hud_message = UI.titre("", 58)
	_hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_hud_message)

func _rafraichir_hud() -> void:
	if _hud_chrono == null:
		return
	UI.rafraichir_etat_reseau(_hud_etat)
	var restant: float = max(0.0, duree_reelle() - temps)
	_hud_chrono.text = "%d:%02d" % [int(restant) / 60, int(restant) % 60]
	_hud_chrono.add_theme_color_override("font_color",
		Palette.CRITIQUE if restant <= 15.0 and phase == JEU else Palette.ENCRE)

	var morceaux: Array = []
	var cles := joueurs.keys()
	cles.sort_custom(func(a, b): return int(joueurs[a]["place"]) < int(joueurs[b]["place"]))
	for cle in cles:
		var j: Dictionary = joueurs[cle]
		var marque := "▸ " if cle == Session.cle else ""
		morceaux.append("%s%s %d" % [marque, String(j["pseudo"]), int(j["score"])])
	_hud_scores.text = "     ".join(morceaux)

	match phase:
		ATTENTE:
			_hud_message.text = "En attente des joueurs…"
		DECOMPTE:
			_hud_message.text = str(int(ceil(_decompte)))
		FIN:
			_hud_message.text = "Terminé"
		_:
			_hud_message.text = ""
