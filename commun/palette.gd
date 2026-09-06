class_name Palette
## Palette imposée des livrables Piks-l. Elle ne se redéfinit pas au cas par cas :
## un écran qui invente sa couleur casse la lecture d'un projet à l'autre.
extends RefCounted

const FOND := Color("#0d0d0d")
const SURFACE := Color("#1a1a19")
const ENCRE := Color("#ffffff")
const ENCRE_DOUCE := Color("#c3c2b7")
const ENCRE_FAIBLE := Color("#898781")
const FILET := Color(1, 1, 1, 0.10)

const BON := Color("#0ca30c")
const AVERTISSEMENT := Color("#fab219")
const SERIEUX := Color("#ec835a")
const CRITIQUE := Color("#d03b3b")
const SERIE := Color("#3987e5")

## Quatre joueurs, quatre couleurs franches. L'ordre est stable : l'indice vient
## de la place occupée dans la table, pas d'un tirage, sinon deux joueurs
## peuvent se retrouver de la même couleur d'une manche à l'autre.
const JOUEURS: Array[Color] = [SERIE, BON, AVERTISSEMENT, SERIEUX]

static func couleur_joueur(indice: int) -> Color:
	return JOUEURS[posmod(indice, JOUEURS.size())]

## Police par défaut du moteur : aucune ressource à embarquer, aucun risque
## qu'une police système manque dans le navigateur.
static func police() -> Font:
	return ThemeDB.fallback_font
