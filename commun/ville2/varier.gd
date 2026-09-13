class_name VarierVille2
extends RefCounted
## LE TIRAGE QUI ÉPUISE LE CATALOGUE AVANT DE SE RÉPÉTER.
##
## ⚠ POURQUOI `randi() % taille` NE SUFFIT PAS. Un tirage uniforme indépendant
## répète : sur vingt maisons tirées parmi seize modèles, le calcul dit qu'il y
## en aura en moyenne SEPT en double et que cinq modèles ne sortiront jamais.
## À l'œil, ça donne exactement ce que le client a vu — « tu as l'air de
## toujours utiliser les mêmes maisons avec les mêmes variantes alors qu'on
## avait dit d'alterner et d'utiliser les mille objets en notre possession »
## (12/09).
##
## Ce n'est pas une impression : c'est la loi des tirages avec remise. La
## correction est un SAC, pas un dé — on tire SANS remise jusqu'à vider le sac,
## puis on le remplit et on rebat. Sur seize modèles, les seize sortent avant
## qu'aucun ne revienne. Le hasard reste (l'ordre change à chaque partie), la
## répétition disparaît.
##
##     var sac := VarierVille2.new(MAISONS, alea)
##     var m := sac.tirer()
##
## Le sac garde en plus le DERNIER tiré du tour précédent en mémoire : sans ça,
## le dernier d'un tour et le premier du suivant peuvent être le même modèle, et
## deux maisons identiques côte à côte se voient tout de suite.

var _choix: Array = []
var _sac: Array = []
var _alea: RandomNumberGenerator
var _dernier := ""

func _init(choix: Array, alea: RandomNumberGenerator) -> void:
	_choix = choix.duplicate()
	_alea = alea
	_remplir()

func _remplir() -> void:
	_sac = _choix.duplicate()
	# Mélange de Fisher-Yates : `Array.shuffle()` utilise le hasard GLOBAL du
	# moteur, pas notre graine — une ville ne serait plus reproductible.
	for k in range(_sac.size() - 1, 0, -1):
		var j := _alea.randi() % (k + 1)
		var t: Variant = _sac[k]
		_sac[k] = _sac[j]
		_sac[j] = t
	# Jamais deux fois de suite le même modèle au passage d'un tour à l'autre.
	if _sac.size() > 1 and String(_sac[_sac.size() - 1]) == _dernier:
		var t2: Variant = _sac[_sac.size() - 1]
		_sac[_sac.size() - 1] = _sac[0]
		_sac[0] = t2

func tirer() -> String:
	if _sac.is_empty(): _remplir()
	if _sac.is_empty(): return ""
	_dernier = String(_sac.pop_back())
	return _dernier

## Un tirage qui respecte une contrainte (par exemple « qui tient dans cette
## largeur ») : on parcourt le sac jusqu'à trouver, sans casser l'ordre du
## reste. Rend "" si rien ne convient.
func tirer_si(convient: Callable) -> String:
	if _sac.is_empty(): _remplir()
	for k in range(_sac.size() - 1, -1, -1):
		if convient.call(String(_sac[k])):
			_dernier = String(_sac[k])
			_sac.remove_at(k)
			return _dernier
	# Rien dans ce sac : on regarde le catalogue entier avant d'abandonner.
	for m in _choix:
		if convient.call(String(m)): return String(m)
	return ""

## Combien il reste avant de rebattre — utile pour les essais.
func reste() -> int:
	return _sac.size()
