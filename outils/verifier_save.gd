extends SceneTree
## ⭐⭐ LE CONTRAT D'ENREGISTREMENT D'UNE FENÊTRE DU PAYS, DE BOUT EN BOUT.
##
##     godot --headless --path . --script res://outils/verifier_save.gd
##
## ⚠ POURQUOI UN BANC POUR QUELQUE CHOSE D'AUSSI SIMPLE. « Mes modifications
## disparaissent » est le défaut le plus coûteux de tout l'éditeur : il ne se
## voit pas au moment où il se produit, seulement une heure de travail plus
## tard, et il se rattrape rarement. La chaîne compte cinq maillons, chacun
## dans un fichier différent — le nom de la carte, l'écriture, la question
## « cette carte est-elle modifiée ? », la relecture, et l'effacement. Il suffit
## qu'un seul réponde autrement que les autres pour que le travail parte.
##
## Ce banc les interroge tous les cinq, dans l'ordre où l'éditeur les appelle.
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")

func _init() -> void:
	var plan := PLAN.charger()
	if plan.is_empty():
		print("plan absent : " + PLAN.PLAN_CUIT)
		quit()
		return
	var ctx := PLAN.contexte(plan)
	var c := Vector2i(480, 480)
	var cote := 60
	## ⚠ LE NOM PORTE LE CENTRE *ET* LE CÔTÉ. Deux fenêtres centrées au même
	## endroit mais larges de 60 et de 200 cases ne sont pas la même carte.
	var nom := "pays-%d-%d-%d" % [c.x, c.y, cote]
	var chemin := "res://cartes/%s.json" % nom
	var fautes := 0

	Ville2.oublier_les_modifications(chemin)
	fautes += _dire("1. au départ, rien d'enregistré",
		not Ville2.carte_modifiee(chemin))

	var f := Rect2i(c - Vector2i(cote, cote) / 2, Vector2i(cote, cote))
	var v: Ville2 = PAYS.fenetre(plan, ctx, f, {"nom": "contrôle"})
	var avant := v.objets.size()
	v.ajouter_objet("pxl/abribus", 100.0, 100.0, 0.0, 0.0, "")
	## ⚠ ON ÉCRIT EN `user://`, PAS LÀ OÙ LE BUREAU ÉCRIRAIT. `chemin_d_ecriture`
	## rend le `res://` au bureau et le `user://` au navigateur ; c'est le second
	## qui compte, parce que c'est le seul où le client travaille.
	fautes += _dire("2. l'écriture réussit",
		v.enregistrer("user://cartes/%s.json" % nom))

	fautes += _dire("3. la carte est vue comme modifiée",
		Ville2.carte_modifiee(chemin))

	## Le maillon qui casse le plus souvent : relire par le nom LIVRÉ doit rendre
	## la version personnelle, sans que l'appelant ait à le savoir.
	var r := Ville2.charger(chemin)
	fautes += _dire("4. relue par son nom livré, c'est la version retouchée (%d objets)"
		% r.objets.size(), r.objets.size() == avant + 1)

	Ville2.oublier_les_modifications(chemin)
	fautes += _dire("5. rétablir efface la version personnelle",
		not Ville2.carte_modifiee(chemin))

	print("")
	print("ENREGISTREMENT : %s" % ("OK" if fautes == 0 else "%d MAILLON(S) CASSÉ(S)" % fautes))
	quit()

func _dire(quoi: String, bon: bool) -> int:
	print("%s %s" % ["  ok  " if bon else " FAUTE", quoi])
	return 0 if bon else 1
