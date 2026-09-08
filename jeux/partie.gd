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

var _hud: Control                  ## `ui/hud.gd` : tout l'affichage tête haute
var _dernier_bip := 99

# ------------------------------------------------------- à redéfinir

func duree_manche() -> float:
	return 120.0

func aide() -> String:
	return ""

## Une ligne d'état propre au jeu : arme en main, chambre en cours… Affichée
## au-dessus de l'aide, elle change souvent alors que l'aide ne change jamais.
## Les jeux qui ont plus à dire qu'une phrase renvoient une fiche à la place.
func etat_joueur() -> String:
	return ""

## La fiche structurée du joueur, pour le HUD : `{etoiles: int, jauges:
## [{nom, part, couleur, valeur}], arme: {nom, munitions}, puces: [{texte,
## couleur}], alerte: {texte, couleur, part}, accent: Color}`. Toutes les
## rubriques sont facultatives ; une fiche vide laisse la place à `etat_joueur`.
func fiche_joueur() -> Dictionary:
	return {}

## Les touches, en paires `[touche, action]`, pour la ligne de cabochons. Par
## défaut on découpe `aide()` — « Z/S : avancer · Q/D : tourner » — ce qui
## suffit aux jeux qui n'ont pas encore de liste propre.
func aide_touches() -> Array:
	var paires: Array = []
	for morceau in aide().split("·"):
		var parties := String(morceau).strip_edges().split(":", true, 1)
		if parties.size() == 2:
			paires.append([parties[0].strip_edges(), parties[1].strip_edges()])
	return paires

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
	# Le thème s'arrête ici : en ville, ce sont les moteurs, les klaxons et
	# les sirènes qui font la bande-son. Il reprend à l'écran des résultats.
	Sons.musique("")
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

## Une manche SANS LIMITE : elle ne s'arrête pas au chrono. C'est le mode de
## Carnage — une ville où l'on reste tant qu'on veut, où l'on rentre chez soi
## déposer son argent, et d'où l'on sort par le hub quand on a fini. Le banc
## (`duree_forcee`) garde une fin, sinon il ne rendrait jamais la main.
var sans_limite := false

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
			var seconde := int(ceil(_decompte))
			if seconde != _dernier_bip:
				_dernier_bip = seconde
				Sons.jouer("bip", 1.0, -10.0)
			if _decompte <= 0.0:
				phase = JEU
				temps = 0.0
				Sons.jouer("depart", 1.0, -6.0)
				Sons.demarrer_moteur()
		JEU:
			temps += delta
			simuler_local(delta)
			if est_hote():
				simuler_hote(delta)
				if not sans_limite and temps >= duree_reelle():
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
	Sons.arreter_moteur()
	Sons.jouer("fin", 1.0, -6.0)
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

func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventKey and evenement.pressed and not evenement.echo and evenement.keycode == KEY_M:
		Sons.basculer()
		_rafraichir_hud()

func _construire_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_script(load("res://ui/hud.gd"))
	_hud.aide = aide_touches()
	interface().add_child(_hud)

func _rafraichir_hud() -> void:
	if _hud == null:
		return
	var couleur_reseau := Palette.ENCRE_FAIBLE
	match Reseau.etat:
		Reseau.EN_LIGNE: couleur_reseau = Palette.BON
		Reseau.CONNEXION: couleur_reseau = Palette.AVERTISSEMENT
		_: couleur_reseau = Palette.CRITIQUE
	_hud.reseau_libelle = Reseau.libelle_etat()
	_hud.reseau_couleur = couleur_reseau
	_hud.son_actif = Sons.actif
	var restant: float = max(0.0, duree_reelle() - temps)
	_hud.sans_limite = sans_limite
	_hud.chrono = temps if sans_limite else restant
	_hud.chrono_critique = not sans_limite and restant <= 15.0 and phase == JEU
	_hud.temps = Time.get_ticks_msec() / 1000.0

	var lignes: Array = []
	var cles := joueurs.keys()
	cles.sort_custom(func(a, b): return int(joueurs[a]["place"]) < int(joueurs[b]["place"]))
	for cle in cles:
		var j: Dictionary = joueurs[cle]
		lignes.append({"pseudo": String(j["pseudo"]), "score": int(j["score"]),
			"couleur": Palette.couleur_joueur(int(j["place"])), "moi": cle == Session.cle})
	_hud.scores = lignes

	_hud.fiche = fiche_joueur()
	_hud.etat_texte = etat_joueur()
	# Les touches s'estompent quinze secondes après le départ : on les a lues
	# pendant le décompte, elles n'ont plus qu'à rester trouvables.
	_hud.aide_visible = 1.0 if phase != JEU or temps < 15.0 else clampf(1.0 - (temps - 15.0) / 3.0, 0.45, 1.0)

	match phase:
		ATTENTE:
			_hud.message = "EN ATTENTE DES JOUEURS"
		DECOMPTE:
			_hud.message = str(int(ceil(_decompte)))
		FIN:
			_hud.message = "TERMINE"
		_:
			_hud.message = ""
	_hud.queue_redraw()
