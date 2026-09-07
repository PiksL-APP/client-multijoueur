extends Node
## Identité locale du joueur.
##
## Pas de compte, pas de mot de passe : un identifiant tiré au sort à la
## première visite et gardé dans le stockage du navigateur. C'est assez pour
## rattacher des scores à quelqu'un, et ça n'engage aucune donnée personnelle.

const FICHIER := "user://identite.cfg"
const PSEUDO_MAX := 16

var id: String = ""      ## stable, gardé d'une visite à l'autre : sert aux scores
var cle: String = ""     ## propre à cet onglet : sert au réseau
var pseudo: String = ""
var heros: String = ""   ## knight, rogue ou wizzard ; vide = tiré de l'identifiant

func _ready() -> void:
	var fichier := ConfigFile.new()
	if fichier.load(FICHIER) == OK:
		id = String(fichier.get_value("joueur", "id", ""))
		pseudo = String(fichier.get_value("joueur", "pseudo", ""))
		heros = String(fichier.get_value("joueur", "heros", ""))
	if id.length() < 8:
		id = _tirer_identifiant()
		_ecrire()
	# Deux onglets du même navigateur partagent `user://` — donc le même
	# identifiant. Sans suffixe propre à l'onglet, le second écraserait la
	# présence du premier et on ne pourrait pas se tester à deux sur une seule
	# machine. Le score, lui, reste rattaché à `id`.
	cle = id + "-" + _tirer_identifiant().substr(0, 4)

func definir_pseudo(nouveau: String) -> void:
	pseudo = nettoyer_pseudo(nouveau)
	_ecrire()

func definir_heros(nom: String) -> void:
	heros = nom
	_ecrire()

## Le héros affiché : celui qu'on a choisi, sinon celui que l'identifiant
## désigne — le même calcul chez tous les clients.
func heros_affiche() -> String:
	return heros if heros in Pixels.HEROS else Pixels.heros_de(id)

static func nettoyer_pseudo(brut: String) -> String:
	var propre := ""
	for c in brut.strip_edges():
		# On garde lettres, chiffres, espace et tiret. Le reste ouvre la porte
		# aux pseudos qui cassent l'affichage ou miment un autre joueur.
		if c.is_valid_identifier() or c.is_valid_int() or c == " " or c == "-" or c == "_":
			propre += c
		elif c.to_upper() != c.to_lower():
			propre += c
	propre = propre.strip_edges()
	if propre.length() > PSEUDO_MAX:
		propre = propre.substr(0, PSEUDO_MAX)
	return propre

func _tirer_identifiant() -> String:
	var alphabet := "abcdefghijklmnopqrstuvwxyz0123456789"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := ""
	for i in 16:
		s += alphabet[rng.randi_range(0, alphabet.length() - 1)]
	return s

func _ecrire() -> void:
	var fichier := ConfigFile.new()
	fichier.set_value("joueur", "id", id)
	fichier.set_value("joueur", "pseudo", pseudo)
	fichier.set_value("joueur", "heros", heros)
	fichier.save(FICHIER)
