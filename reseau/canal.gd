class_name CanalTempsReel
extends RefCounted
## Un canal Supabase Realtime : une salle, un hub, une file d'attente.
##
## L'objet ne parle pas au socket lui-même ; il passe par l'autoload `Reseau`,
## qui n'ouvre qu'une seule connexion pour tout le jeu. Ouvrir un socket par
## canal marchait aussi, mais multipliait les reconnexions à chaque changement
## d'écran — et donc les trous de présence de plusieurs secondes.

signal rejoint()
signal diffusion(evenement: String, charge: Dictionary)
signal presences_changees(presences: Dictionary)
signal perdu()

var nom: String = ""          ## nom court, sans le préfixe "realtime:"
var topic: String = ""        ## topic Phoenix complet
var cle: String = ""          ## clé de présence (identifiant du joueur)
var meta: Dictionary = {}     ## ce que les autres voient de nous
var presences: Dictionary = {}  ## cle -> meta (la nôtre comprise)
var est_rejoint: bool = false
var ref_jonction: String = ""

func envoyer(evenement: String, charge: Dictionary) -> void:
	Reseau.diffuser(self, evenement, charge)

## Met à jour ce que les autres voient de nous. À n'appeler que sur changement
## réel : chaque appel est un message pour tout le monde dans le canal.
func suivre(nouvelle_meta: Dictionary) -> void:
	meta = nouvelle_meta
	Reseau.suivre_presence(self)

func quitter() -> void:
	Reseau.quitter(nom)

## Les présences triées par clé : donne à tous les clients le même ordre, donc
## les mêmes couleurs et le même hôte, sans avoir à se mettre d'accord.
func cles_triees() -> Array:
	var cles := presences.keys()
	cles.sort()
	return cles

## L'hôte est le joueur dont la clé vient en premier. Règle bête et suffisante :
## elle donne le même résultat chez tout le monde, et la réélection après un
## départ est immédiate et sans échange de messages.
func hote() -> String:
	var cles := cles_triees()
	return "" if cles.is_empty() else String(cles[0])

func je_suis_hote() -> bool:
	return hote() == cle

func place(cle_joueur: String) -> int:
	return cles_triees().find(cle_joueur)
