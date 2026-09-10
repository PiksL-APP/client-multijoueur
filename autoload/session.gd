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
## Le personnage du casting Kenney, celui qu'on incarne en ville.
##
## ⚠ Il y avait ici un second champ, `heros` : le trio de pantins EN PIXELS du
## village (knight, rogue, wizzard). Il est parti avec les jeux 2D. Un fichier
## de réglages écrit par une version précédente en porte encore la clé — elle
## est simplement ignorée, ce qui est le comportement voulu : un joueur déjà
## installé ne doit rien perdre parce qu'on a retiré un jeu.
var personnage: String = ""

func _ready() -> void:
	var fichier := ConfigFile.new()
	if fichier.load(FICHIER) == OK:
		id = String(fichier.get_value("joueur", "id", ""))
		pseudo = String(fichier.get_value("joueur", "pseudo", ""))
		personnage = String(fichier.get_value("joueur", "personnage", ""))
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

func definir_personnage(cle: String) -> void:
	personnage = cle
	_ecrire()

## Le personnage affiché : celui qu'on a choisi, sinon celui que l'identifiant
## désigne — le même calcul chez tous les clients, donc chacun voit l'autre
## sous le même trait sans qu'on ait rien à diffuser.
func personnage_affiche() -> String:
	return personnage if Personnages.existe(personnage) else Personnages.par_defaut(id)

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
	fichier.set_value("joueur", "personnage", personnage)
	fichier.save(FICHIER)
