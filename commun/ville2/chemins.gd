extends RefCounted
## LES CHEMINS DE TERRE DU KIT NATURE — et la façon de les raccorder.
##
## ⚠ CE FICHIER EXISTE PARCE QU'ON S'EST TROMPÉ UNE FOIS, ET CHÈREMENT. Au
## premier essai d'allée de parc, les tuiles étaient posées avec une rotation
## DEVINÉE : « aucune flèche ne se suit, donc les routes sont nulles » (client,
## 12/09). L'erreur n'était pas dans le choix des tuiles mais dans le fait de
## n'avoir jamais REGARDÉ dans quel sens elles couraient. Et elle n'était pas
## rattrapable à l'œil : une tuile de sol vue de biais ne dit pas son axe.
##
## Les orientations ci-dessous sont donc MESURÉES, pas supposées — rendues à la
## verticale, en orthographique, par `outils/echelle.sh --dessus=1` :
##
##   ground_pathStraight   une bande qui court NORD-SUD
##   ground_pathBend       un coude qui relie l'EST au SUD
##   ground_pathSplit      un T : OUEST, EST et SUD (fermé au nord)
##   ground_pathCross      les quatre
##   ground_pathEnd        un cul-de-sac ouvert au SUD
##   ground_pathRocks      comme Straight, avec des cailloux
##
## ⚠ ET LA ROTATION VA DANS L'AUTRE SENS QUE L'INTUITION. Sous `Basis(UP, +90°)`
## un modèle tourné voit sa sortie EST devenir NORD (et nord → ouest). Un quart
## de tour positif fait donc tourner les raccords dans le sens
## EST → NORD → OUEST → SUD. C'est exactement l'inverse de ce qu'on écrit
## spontanément, et c'est ce qui décalait tout d'un quart de tour.
##
## ⚠⚠ LA TUILE APPORTE SON HERBE, ET LA TEINTE NE SUFFIT PAS À LA LUI RETIRER.
##
## Chaque tuile est un carré VERT dans lequel le chemin est creusé : posée sur
## la terre battue d'un bidonville, elle fait un rectangle vert par case.
##
## Premier essai — la TEINTE, qui multiplie tout le modèle. Ça n'y peut rien :
## pour faire brunir l'herbe (0,45 · 0,78 · 0,42) il faut écraser la composante
## verte, ce qui écrase du même coup le beige du chemin (0,93 · 0,88 · 0,78) et
## le vire au rose. Un seul facteur ne peut pas transformer un vert en brun ET
## laisser un neutre neutre. C'est arithmétique, pas un réglage à trouver.
##
## Deuxième essai — de l'HERBE SOUS LA TUILE, puis débordant d'une case. Le
## raccord disparaissait, mais la bande d'herbe vive devenait le sujet : dans
## un bidonville, ça ressemblait à des pelouses (« pourquoi il y a de l'herbe
## en dessous ? », client, 13/09).
##
## Retenu — on repeint LES SOMMETS VERTS DU MAILLAGE (`sol`, voir
## `atlas.sans_verdure`). C'est le strict équivalent de la repeinture des
## toitures, mais pour un kit qui porte sa couleur au sommet au lieu d'un
## atlas. L'herbe devient de la terre sèche, le chemin garde son ornière et son
## clair-obscur, et la tuile se pose sur n'importe quel sol.

const CASE := Ville2.CASE

const N := 1
const E := 2
const S := 4
const O := 8

## Les tuiles et le jeu de raccords de chacune, sans rotation.
const DROIT := "nature/ground_pathStraight"
const CAILLOUX := "nature/ground_pathRocks"
const COUDE := "nature/ground_pathBend"
const TE := "nature/ground_pathSplit"
const CROIX := "nature/ground_pathCross"
const BOUT := "nature/ground_pathEnd"

const MASQUES := {
	DROIT: N | S,
	CAILLOUX: N | S,
	COUDE: E | S,
	TE: O | E | S,
	CROIX: N | E | S | O,
	BOUT: S,
}

## Un quart de tour positif : chaque raccord recule d'un cran dans l'ordre
## N, E, S, O — c'est-à-dire que le bit tourne vers la droite.
static func _tourner(masque: int, quarts: int) -> int:
	var m := masque
	for _k in posmod(quarts, 4):
		m = ((m >> 1) | (m << 3)) & 15
	return m

## Le voisinage d'une case dans l'ensemble.
static func masque_de(cases: Dictionary, c: Vector2i) -> int:
	var m := 0
	if cases.has(c + Vector2i(0, -1)): m |= N
	if cases.has(c + Vector2i(1, 0)): m |= E
	if cases.has(c + Vector2i(0, 1)): m |= S
	if cases.has(c + Vector2i(-1, 0)): m |= O
	return m

## La tuile et le quart de tour qui portent exactement ce masque.
## Rend [modèle, quarts] — ou ["", 0] s'il n'y a rien (case isolée).
static func tuile_pour(masque: int, alea: RandomNumberGenerator) -> Array:
	if masque == 0: return ["", 0]
	var candidats: Array = [CROIX, TE, COUDE, DROIT, BOUT]
	for m in candidats:
		for q in 4:
			if _tourner(int(MASQUES[m]), q) != masque: continue
			# Le droit se remplace parfois par sa variante à cailloux : c'est
			# la même tuile, et deux cents mètres de chemin identique se voient.
			if m == DROIT and alea.randf() < 0.18: return [CAILLOUX, q]
			return [m, q]
	return ["", 0]

## Pose le réseau. `cases` : l'ensemble des cases de chemin (Dictionary utilisé
## comme ensemble).
## `teinte` : la couleur qui MULTIPLIE toute la tuile — à laisser vide presque
## toujours.
## `sol` : la couleur qui REMPLACE l'herbe de la tuile, sommet par sommet — à
## passer dès que le chemin ne traverse pas une prairie.
## Rend le nombre de tuiles posées.
## ⚠ L'ÉCRASEMENT PAR DÉFAUT. Une tuile `ground_path*` est dessinée pour être
## ENFONCÉE dans le sol (sa boîte va de −0,10 à −0,05 unité Kenney, soit 1 à 2 m
## SOUS le niveau zéro). Le chargeur la repose base à zéro, donc elle ressort
## d'un mètre entier. Comme le terrain n'a pas de trou dessous, on ne peut pas
## la redescendre : on l'écrase. Quinze pour cent, c'est quinze centimètres de
## relief — assez pour que l'ornière porte son ombre, assez peu pour que le
## chemin soit DANS la terre et non dessus.
const APLAT := 0.15

static func poser(v: Ville2, alea: RandomNumberGenerator, cases: Dictionary,
		teinte := "", sol := "", aplat := APLAT) -> int:
	var poses := 0
	for c in cases:
		var ci: Vector2i = c
		if not v.dedans(ci) or not v.terre(ci): continue
		if v.carte != null and (v.carte.route(ci) or v.carte.case_prise(ci)): continue
		if v.lot_sur(ci) >= 0: continue
		var choix := tuile_pour(masque_de(cases, ci), alea)
		var m := String(choix[0])
		if m == "": continue
		# ⚠ AU CENTRE DE LA CASE. Ces tuiles sont centrées sur leur origine
		# (mesuré : min = −0,5, max = +0,5) : posées au COIN, elles seraient
		# décalées d'une demi-case et aucun raccord ne tomberait juste.
		v.ajouter_objet(m, (float(ci.x) + 0.5) * CASE, (float(ci.y) + 0.5) * CASE,
			PI * 0.5 * float(int(choix[1])), 0.0, teinte)
		# Une tuile de chemin EST le sol : la passe de propreté ne doit pas la
		# balayer si elle longe une route.
		v.objets[v.objets.size() - 1]["voirie"] = true
		if sol != "": v.objets[v.objets.size() - 1]["sol"] = sol
		if aplat != 1.0: v.objets[v.objets.size() - 1]["aplat"] = aplat
		poses += 1
	return poses

## La couleur d'un chemin de terre battue, posé sur de la terre : elle éteint
## le vert de la tuile et laisse le tracé clair.
const TERRE_BATTUE := "#b9a184"
