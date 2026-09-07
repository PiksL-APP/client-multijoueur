extends Node
## Client Supabase Realtime écrit directement sur WebSocketPeer.
##
## Pourquoi pas le SDK JavaScript par JavaScriptBridge : il n'existerait que
## dans l'export web. Le même code doit tourner dans l'éditeur, sinon plus rien
## n'est testable sans déployer. Le protocole (Phoenix v1) tient en quatre
## messages : phx_join, heartbeat, broadcast, presence.

signal etat_change(nouvel_etat: int)

enum { HORS_LIGNE, CONNEXION, EN_LIGNE }

## Le serveur n'envoie PAS l'état de présence à celui qui arrive : il ne
## diffuse que les différences qui SUIVENT la jonction. Vérifié au fil : un
## second client rejoint un canal peuplé et reçoit son propre `presence_diff`,
## rien d'autre — il se croit seul, et les autres le voient sans qu'il les
## voie. On règle ça par une salutation : en arrivant on se signale, et
## quiconque ne nous connaissait pas encore répond une fois. Trois messages,
## et tout le monde a la même liste.
const EVENEMENT_ICI := "__ici"

const DELAI_BATTEMENT := 25.0          ## le serveur coupe à 60 s de silence
const DELAIS_RECONNEXION := [1.0, 2.0, 4.0, 8.0, 15.0]

var etat: int = HORS_LIGNE

var _ws: WebSocketPeer = null
var _compteur_ref: int = 0
var _battement: float = 0.0
var _essais: int = 0
var _attente: float = 0.0
var _canaux: Dictionary = {}   # topic -> CanalTempsReel

func _ready() -> void:
	set_process(true)

func connecter() -> void:
	if _ws != null or not Config.est_configure():
		return
	_ouvrir()

func _ouvrir() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	var erreur := _ws.connect_to_url(Config.url_temps_reel())
	if erreur != OK:
		push_warning("Connexion temps réel impossible (%d)" % erreur)
		_ws = null
		_replanifier()
		return
	_battement = DELAI_BATTEMENT
	_passer(CONNEXION)

func _process(delta: float) -> void:
	if _ws == null:
		if _attente > 0.0:
			_attente -= delta
			if _attente <= 0.0:
				_ouvrir()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if etat != EN_LIGNE:
				_essais = 0
				_passer(EN_LIGNE)
				# Une reconnexion ne recrée pas les canaux : elle les rejoint.
				for canal in _canaux.values():
					canal.est_rejoint = false
					_envoyer_jonction(canal)
			_battement -= delta
			if _battement <= 0.0:
				_battement = DELAI_BATTEMENT
				_envoyer({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _ref()})
			while _ws.get_available_packet_count() > 0:
				_recevoir(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED, WebSocketPeer.STATE_CLOSING:
			_perdre()

# ---------------------------------------------------------------- canaux

## Rejoint un canal, ou rend celui déjà ouvert. Le nom est court ; le préfixe
## "realtime:" est ajouté ici pour qu'aucun appelant n'ait à le connaître.
func rejoindre(nom: String, meta: Dictionary = {}) -> CanalTempsReel:
	var topic := "realtime:" + nom
	if _canaux.has(topic):
		var existant: CanalTempsReel = _canaux[topic]
		if not meta.is_empty():
			existant.suivre(meta)
		return existant

	var canal := CanalTempsReel.new()
	canal.nom = nom
	canal.topic = topic
	canal.cle = Session.cle
	canal.meta = meta
	_canaux[topic] = canal

	if etat == EN_LIGNE:
		_envoyer_jonction(canal)
	else:
		connecter()
	return canal

func quitter(nom: String) -> void:
	var topic := "realtime:" + nom
	if not _canaux.has(topic):
		return
	var canal: CanalTempsReel = _canaux[topic]
	if etat == EN_LIGNE:
		_envoyer({"topic": topic, "event": "phx_leave", "payload": {}, "ref": _ref()})
	_canaux.erase(topic)
	canal.est_rejoint = false
	canal.presences.clear()

## Le serveur ne dit pas qui a envoyé quoi : la signature est ajoutée ici, une
## fois pour toutes. L'oublier dans un seul appelant donne des messages
## fantômes qu'on met une soirée à attribuer.
func diffuser(canal: CanalTempsReel, evenement: String, charge: Dictionary) -> void:
	if etat != EN_LIGNE or not canal.est_rejoint:
		return
	charge = charge.duplicate()
	charge["cle"] = canal.cle
	_envoyer({
		"topic": canal.topic,
		"event": "broadcast",
		"payload": {"type": "broadcast", "event": evenement, "payload": charge},
		"ref": _ref(),
	})

## Se signaler aux autres. La présence côté serveur reste la source de vérité
## pour les DÉPARTS (elle seule voit une connexion tomber) ; la salutation ne
## sert qu'aux arrivées.
func _saluer(canal: CanalTempsReel) -> void:
	diffuser(canal, EVENEMENT_ICI, canal.meta)

func _accueillir(canal: CanalTempsReel, meta: Dictionary) -> void:
	var cle := String(meta.get("cle", ""))
	if cle == "" or cle == canal.cle:
		return
	var inconnu := not canal.presences.has(cle)
	canal.presences[cle] = meta.duplicate()
	canal.presences_changees.emit(canal.presences)
	# On ne répond qu'à qui ne nous connaissait pas : sans ce test, deux
	# clients se saluent en boucle jusqu'à saturer le canal.
	if inconnu:
		_saluer(canal)

func suivre_presence(canal: CanalTempsReel) -> void:
	if etat != EN_LIGNE or not canal.est_rejoint:
		return
	_saluer(canal)
	_envoyer({
		"topic": canal.topic,
		"event": "presence",
		"payload": {"type": "presence", "event": "track", "payload": canal.meta},
		"ref": _ref(),
	})

# ---------------------------------------------------------------- protocole

func _envoyer_jonction(canal: CanalTempsReel) -> void:
	canal.ref_jonction = _ref()
	_envoyer({
		"topic": canal.topic,
		"event": "phx_join",
		"payload": {
			"config": {
				# `self: false` — on ne se fait pas renvoyer ses propres messages.
				# À 12 envois par seconde et par joueur, l'écho double la facture
				# de messages pour un état qu'on connaît déjà.
				"broadcast": {"self": false, "ack": false},
				"presence": {"key": canal.cle},
				"private": false,
			},
			"access_token": Config.cle_publique,
		},
		"ref": canal.ref_jonction,
		"join_ref": canal.ref_jonction,
	})

func _recevoir(texte: String) -> void:
	var message = JSON.parse_string(texte)
	if typeof(message) != TYPE_DICTIONARY:
		return
	var topic := String(message.get("topic", ""))
	var evenement := String(message.get("event", ""))
	var charge = message.get("payload", {})
	if typeof(charge) != TYPE_DICTIONARY:
		charge = {}

	if topic == "phoenix":
		return
	if not _canaux.has(topic):
		return
	var canal: CanalTempsReel = _canaux[topic]

	match evenement:
		"phx_reply":
			if String(message.get("ref", "")) == canal.ref_jonction:
				if String(charge.get("status", "")) == "ok":
					canal.est_rejoint = true
					canal.rejoint.emit()
					if not canal.meta.is_empty():
						suivre_presence(canal)
						_saluer(canal)
				else:
					push_warning("Jonction refusée sur %s : %s" % [topic, JSON.stringify(charge)])
		"broadcast":
			var interne = charge.get("payload", {})
			if typeof(interne) != TYPE_DICTIONARY:
				interne = {}
			var nom_evenement := String(charge.get("event", ""))
			if nom_evenement == EVENEMENT_ICI:
				_accueillir(canal, interne)
			else:
				canal.diffusion.emit(nom_evenement, interne)
		"presence_state":
			canal.presences.clear()
			for cle in charge.keys():
				_poser_presence(canal, String(cle), charge[cle])
			canal.presences_changees.emit(canal.presences)
		"presence_diff":
			var arrivees = charge.get("joins", {})
			var departs = charge.get("leaves", {})
			if typeof(arrivees) == TYPE_DICTIONARY:
				for cle in arrivees.keys():
					_poser_presence(canal, String(cle), arrivees[cle])
			if typeof(departs) == TYPE_DICTIONARY:
				for cle in departs.keys():
					# Un départ suivi d'une arrivée dans le même diff est un
					# changement de méta, pas une sortie : ne pas effacer.
					if not (typeof(arrivees) == TYPE_DICTIONARY and arrivees.has(cle)):
						canal.presences.erase(String(cle))
			canal.presences_changees.emit(canal.presences)
		"phx_close", "phx_error":
			canal.est_rejoint = false
			canal.perdu.emit()

func _poser_presence(canal: CanalTempsReel, cle: String, brut) -> void:
	if typeof(brut) != TYPE_DICTIONARY:
		return
	var metas = brut.get("metas", [])
	if typeof(metas) != TYPE_ARRAY or metas.is_empty():
		return
	# Un même joueur peut avoir plusieurs métas (deux onglets) : la dernière
	# annoncée fait foi.
	var meta = metas[metas.size() - 1]
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var copie: Dictionary = meta.duplicate()
	copie["cle"] = cle
	canal.presences[cle] = copie

func _envoyer(message: Dictionary) -> void:
	if _ws == null:
		return
	_ws.send_text(JSON.stringify(message))

func _ref() -> String:
	_compteur_ref += 1
	return str(_compteur_ref)

func _perdre() -> void:
	_ws = null
	for canal in _canaux.values():
		canal.est_rejoint = false
		canal.presences.clear()
		canal.perdu.emit()
	_replanifier()
	_passer(HORS_LIGNE)

func _replanifier() -> void:
	var indice: int = min(_essais, DELAIS_RECONNEXION.size() - 1)
	_attente = DELAIS_RECONNEXION[indice]
	_essais += 1

func _passer(nouvel_etat: int) -> void:
	if etat == nouvel_etat:
		return
	etat = nouvel_etat
	etat_change.emit(etat)

func libelle_etat() -> String:
	match etat:
		EN_LIGNE: return "en ligne"
		CONNEXION: return "connexion…"
		_: return "hors ligne"
