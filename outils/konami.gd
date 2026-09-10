extends Node
## LE BANC DU CODE KONAMI. ↑ ↑ ↓ ↓ ← → ← → B A ouvre le menu de triche, et
## c'est exactement le genre de suite où l'on se trompe d'un cran sans jamais
## s'en apercevoir — parce qu'en jouant, quand ça ne s'ouvre pas, on croit
## avoir mal tapé.
##
## On pousse de VRAIS évènements clavier dans `Input` : c'est la seule façon
## d'éprouver `Commandes.konami`, qui lit l'état réel des touches.
##
## ⚠ C'est un banc de SCÈNE et non un `-s` : `Commandes` parle à `Tactile`,
## qui est un autoload — hors scène, le fichier ne compile même pas.
##
##   godot --headless --path . res://outils/konami.tscn

var _fautes := 0

func _ready() -> void:
	print("── code Konami")
	_exact()
	_faux_pas()
	_bafouille()
	_oubli()
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	get_tree().quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

## Une frappe : on enfonce, on lit, on relâche, on relit. `konami` se lit au
## FRONT — sans le relâchement, deux « ↑ » de suite ne font qu'un.
func _taper(code: int) -> bool:
	var trouve := false
	if _pousser(code, true):
		trouve = true
	if _pousser(code, false):
		trouve = true
	return trouve

func _pousser(code: int, enfoncee: bool) -> bool:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = enfoncee
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	return Commandes.konami(0.016)

func _suite() -> Array:
	return [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]

func _remettre() -> void:
	Commandes._konami_pas = 0
	Commandes._konami_tenue = 0
	Commandes._konami_reste = 0.0

func _exact() -> void:
	print("\n1. LA SUITE EXACTE")
	_remettre()
	var ouvertures := 0
	for code in _suite():
		if _taper(code):
			ouvertures += 1
	_dire(ouvertures == 1, "le code ouvre le menu (%d fois)" % ouvertures)
	# Et il ne se rouvre pas tout seul à la touche suivante.
	_dire(not _taper(KEY_A), "une touche de plus ne le rouvre pas")

func _faux_pas() -> void:
	print("\n2. UN FAUX PAS ANNULE")
	_remettre()
	var suite := _suite()
	var ouvert := false
	for i in suite.size():
		if i == 5:
			_taper(KEY_DOWN)          # une flèche de travers au milieu
		if _taper(int(suite[i])):
			ouvert = true
	_dire(not ouvert, "avec une touche de travers, rien ne s'ouvre")

## ⚠ LE CAS QUI CASSE TOUT NAÏVEMENT : « ↑ ↑ ↑ ↑ ↓ ↓ … ». Celui qui bafouille
## au début doit pouvoir enchaîner — sinon il faut relâcher, attendre, et
## personne ne comprend pourquoi le code ne marche jamais.
func _bafouille() -> void:
	print("\n3. ON PEUT BAFOUILLER SUR LA PREMIÈRE TOUCHE")
	_remettre()
	var ouvert := false
	for code in [KEY_UP, KEY_UP, KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
			KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]:
		if _taper(code):
			ouvert = true
	_dire(ouvert, "quatre flèches hautes puis la suite : ça ouvre quand même")

func _oubli() -> void:
	print("\n4. LE CODE S'OUBLIE")
	_remettre()
	for code in [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN]:
		_taper(code)
	# Trois secondes sans rien faire.
	Commandes.konami(Commandes.KONAMI_DELAI + 0.5)
	var ouvert := false
	for code in [KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]:
		if _taper(code):
			ouvert = true
	_dire(not ouvert, "après %.1f s d'arrêt, la suite est oubliée" % Commandes.KONAMI_DELAI)
