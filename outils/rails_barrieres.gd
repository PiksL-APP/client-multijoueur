extends SceneTree
## ⭐ LE BANC QUI DIT DE QUEL CÔTÉ SONT LES RAILS D'UNE GLISSIÈRE.
##
##     godot --headless --path . --script res://outils/rails_barrieres.gd
##
## ⚠ POURQUOI UN BANC PLUTÔT QU'UN COUP D'ŒIL. « Les barrières ne sont pas du
## bon côté, elles ne doivent pas couper la route » (client, 16/09). J'avais
## posé la glissière au même quart de tour que sa chaussée, en supposant que les
## deux pièces partagent une orientation. Elles ne la partagent pas, et l'écart
## n'est même pas le même d'une pièce à l'autre : `road-straight` non tourné va
## selon X, mais les rails de `road-straight-barrier` sont à x = ±0,485 et
## courent donc selon Z — un quart de tour d'écart. `road-intersection`, lui, en
## a deux. Deviner à l'œil coûte une ville entière de rambardes en travers.
##
## COMMENT ON LIT UN RAIL. Un rail est une barre MINCE sur un axe et LONGUE sur
## l'autre : `road-straight-barrier` n'a que deux valeurs de z (−0,5 et +0,5,
## toute la tuile) et quatre de x (−0,50, −0,47, +0,47, +0,50 : deux bandes de
## trois centièmes). L'axe des bandes minces porte les rails ; l'autre est celui
## de la route. Le masque rendu est celui des CÔTÉS OCCUPÉS : N=1, E=2, S=4, O=8.
const BANDE := 0.10          ## au-delà, ce n'est plus une bande mince
const BORD := 0.40           ## en deçà du bord, on ne parle plus d'un rail

## ⚠⚠ CE BANC NE SAIT LIRE QUE LES RAILS DROITS, ET C'EST VOULU.
##
## Il rend 15 pour les pièces FAÇONNÉES — le virage, le carrefour, le T, le
## cul-de-sac — dont les rails épousent la forme de la tuile au lieu de longer un
## côté. J'ai essayé deux fois de les lire plus finement, et les deux fois la
## mesure était pire que le silence :
##
##  1. « De la matière près du bord = un rail » comptait les quatre POTEAUX
##     D'ANGLE d'un carrefour pour quatre rails.
##  2. « L'étendue de la matière le long du côté » comptait les DEUX BOUTS des
##     rails est et ouest d'une glissière droite comme un rail au nord — ils
##     couvrent toute la largeur, alors qu'il n'y a rien entre eux.
##  3. Retirer le plus grand trou tombait à zéro partout : une glissière Kenney
##     est faite de poteaux et de panneaux, donc TROUÉE par construction.
##
## Et un contrôle bâti sur la mesure fautive m'a fait annoncer « 801 glissières
## en travers d'une chaussée » qui n'existaient pas.
##
## 15 n'est donc pas un échec, c'est la bonne réponse pour ces pièces : elles
## sont dessinées POUR leur tuile, et `quarts_de_barriere` le lit comme « suis le
## quart de tour de ta chaussée ». Seules les pièces à rails droits ont besoin
## d'être orientées, et celles-là, ce banc les lit juste.

func _init() -> void:
	var noms: Array = []
	for cle in CarteVille.BARRIERES:
		var b := String(CarteVille.BARRIERES[cle])
		if not noms.has(b): noms.append(b)
	noms.sort()
	print("## Mesuré par outils/rails_barrieres.gd — ne pas écrire à la main.")
	print("const RAILS := {")
	for n in noms:
		var c := "res://modeles/kenney/routes/%s.glb" % n
		if not ResourceLoader.exists(c):
			print('\t"%s": 0,  ## ABSENT' % n)
			continue
		var r := (load(c) as PackedScene).instantiate()
		var xs := {}
		var zs := {}
		var pile: Array = [r]
		while not pile.is_empty():
			var no: Node = pile.pop_back()
			for e in no.get_children(): pile.append(e)
			var mi := no as MeshInstance3D
			if mi == null or mi.mesh == null: continue
			for s in mi.mesh.get_surface_count():
				for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					if v.y < 0.03: continue
					xs[snappedf(v.x, 0.01)] = true
					zs[snappedf(v.z, 0.01)] = true
		r.free()
		var m := 0
		if _bande_au_bord(xs, 1.0): m |= 2       ## est
		if _bande_au_bord(xs, -1.0): m |= 8      ## ouest
		if _bande_au_bord(zs, -1.0): m |= 1      ## nord
		if _bande_au_bord(zs, 1.0): m |= 4       ## sud
		print('\t"%s": %d,  ## x=%s z=%s' % [n, m, _tri(xs), _tri(zs)])
	print("}")
	quit()

## Y a-t-il, de ce côté-ci de la tuile, une BANDE MINCE de matière ? On regarde
## les valeurs de la coordonnée au-delà de `BORD` du bon signe : deux valeurs
## séparées de moins de `BANDE`, c'est un rail vu par la tranche.
func _bande_au_bord(vals: Dictionary, sens: float) -> bool:
	var pris: Array = []
	for v in vals.keys():
		var f := float(v)
		if f * sens > BORD: pris.append(f)
	if pris.size() < 2: return false
	pris.sort()
	return absf(float(pris[pris.size() - 1]) - float(pris[0])) <= BANDE

func _tri(d: Dictionary) -> Array:
	var a: Array = d.keys()
	a.sort()
	return a
