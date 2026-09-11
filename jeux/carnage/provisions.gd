class_name Provisions
extends RefCounted
## CE QU'ON MANGE ET CE QU'ON BOIT.
##
## Le catalogue vit ici, dans un fichier à lui, et pas dans `FormesCarnage`
## (qui fabrique des volumes) ni dans `carnage.gd` (qui est déjà le plus gros
## fichier du jeu) : trois lecteurs s'en servent — la supérette qui vend, le
## tableau de bord qui affiche l'inventaire, et le banc qui vérifie les
## chiffres. Une seule liste, sinon le banc contrôle des prix que la boutique
## n'affiche pas.
##
## Ce que chaque ligne dit : le prix, ce que ça remonte de FAIM, de SOIF et de
## VIE. Les trois peuvent être négatifs — une barre chocolatée donne soif, et
## c'est ce qui empêche de tenir la manche entière sur un seul article.
##
## ⚠ LES PRIX SONT CEUX DE LA RUE, pas ceux d'un magasin. Un sandwich à 95 $
## dans un jeu où un passant lâche un billet de 60 et un contrat en paie 620 :
## manger coûte une minute de travail, pas une soirée. Trop cher, on préfère
## mourir de faim ; trop bon marché, on achète huit burgers au début de la
## manche et les deux jauges ne servent plus à rien.

const CATALOGUE := [
	## ⚠ LES COULEURS SONT CELLES D'UNE LISTE, pas celles de l'aliment. Le café
	## et la barre chocolatée étaient peints de leur vraie teinte (#7a5a3a,
	## #8a5a2a) : sur le fond sombre du menu ils sortaient AUSSI ÉTEINTS que
	## les articles trop chers, qu'on grise exprès. Deux bruns assombris, et le
	## seul signal de la boutique ne voulait plus rien dire.
	{"cle": "eau", "nom": "BOUTEILLE D'EAU", "prix": 40,
		"faim": 0.0, "soif": 55.0, "vie": 0.0, "couleur": Color("#4aa8e0")},
	{"cle": "barre", "nom": "BARRE CHOCOLATÉE", "prix": 45,
		"faim": 22.0, "soif": -8.0, "vie": 0.0, "couleur": Color("#c08a44")},
	{"cle": "cafe", "nom": "CAFÉ", "prix": 55,
		"faim": 4.0, "soif": 26.0, "vie": 0.0, "couleur": Color("#b08a62")},
	{"cle": "soda", "nom": "SODA", "prix": 65,
		"faim": 8.0, "soif": 42.0, "vie": 0.0, "couleur": Color("#d0402c")},
	{"cle": "sandwich", "nom": "SANDWICH", "prix": 95,
		"faim": 45.0, "soif": 0.0, "vie": 0.0, "couleur": Color("#d8b46a")},
	{"cle": "salade", "nom": "SALADE", "prix": 120,
		"faim": 38.0, "soif": 12.0, "vie": 10.0, "couleur": Color("#4cc25a")},
	{"cle": "burger", "nom": "BURGER", "prix": 150,
		"faim": 68.0, "soif": -10.0, "vie": 6.0, "couleur": Color("#c07030")},
	{"cle": "trousse", "nom": "TROUSSE DE SECOURS", "prix": 320,
		"faim": 0.0, "soif": 0.0, "vie": 45.0, "couleur": Color("#f0f4f8")},
]

## Ce qu'on peut porter SUR SOI, tous articles confondus. Six : de quoi tenir
## une longue sortie sans que l'inventaire devienne une réserve ambulante — la
## réserve, c'est le frigo de la planque, et c'est ce qui donne une raison de
## plus de rentrer chez soi.
const POCHES := 6
## Ce que le frigo de la planque garde. Large, mais pas infini : un garde-manger
## sans fond, c'est une course au supermarché en début de manche et plus jamais
## ensuite.
const FRIGO := 30

static func fiche(cle: String) -> Dictionary:
	for a in CATALOGUE:
		if String(a["cle"]) == cle:
			return a
	return {}

static func nom(cle: String) -> String:
	return String(fiche(cle).get("nom", cle))

static func prix(cle: String) -> int:
	return int(fiche(cle).get("prix", 0))

## Ce que l'article dit qu'il fait, en une ligne courte pour la boutique et le
## tableau de bord : « +45 faim », « +55 soif », « +45 vie ».
static func effet(cle: String) -> String:
	var a := fiche(cle)
	var morceaux: Array = []
	for champ in [["faim", "faim"], ["soif", "soif"], ["vie", "vie"]]:
		var v := float(a.get(String(champ[0]), 0.0))
		if absf(v) >= 0.5:
			morceaux.append("%+d %s" % [int(round(v)), String(champ[1])])
	return " · ".join(morceaux)

## Combien d'articles en tout dans un sac ({cle: nombre}). Le sac est un
## dictionnaire et pas une liste : on empile trois sandwichs sur une ligne au
## lieu d'en aligner trois, et le tableau de bord tient dans son coin.
static func compte(sac: Dictionary) -> int:
	var total := 0
	for cle in sac:
		total += int(sac[cle])
	return total

static func ajouter(sac: Dictionary, cle: String, combien: int = 1) -> void:
	sac[cle] = int(sac.get(cle, 0)) + combien

## Retirer un article. Rend `false` s'il n'y en avait pas — c'est ce qui évite
## les comptes négatifs, et donc un inventaire qui doit des sandwichs.
static func retirer(sac: Dictionary, cle: String) -> bool:
	var reste := int(sac.get(cle, 0))
	if reste <= 0:
		return false
	if reste == 1:
		sac.erase(cle)
	else:
		sac[cle] = reste - 1
	return true

## CE QU'IL FAUT MANGER MAINTENANT. La touche de consommation n'ouvre pas de
## menu : elle prend dans le sac ce qui répond au besoin le plus pressant.
## Trois touches pour choisir entre un sandwich et une bouteille d'eau quand on
## se fait tirer dessus, personne ne le fait deux fois.
##
## Le score d'un article, c'est ce qu'il COMBLE vraiment : ce qu'il remonte,
## plafonné par ce qui manque. Un burger à 68 devant une jauge de faim à 95 ne
## vaut que 5 — et la bouteille d'eau passe devant, ce qui est exactement ce
## qu'on voulait.
static func le_mieux(sac: Dictionary, faim: float, soif: float, vie: float,
		maximum: float) -> String:
	var meilleur := ""
	var note := 0.0
	for cle in sac:
		var a := fiche(String(cle))
		if a.is_empty():
			continue
		var n := minf(float(a["faim"]), maximum - faim) \
			+ minf(float(a["soif"]), maximum - soif) \
			+ minf(float(a["vie"]), maximum - vie)
		if n > note:
			note = n
			meilleur = String(cle)
	return meilleur
