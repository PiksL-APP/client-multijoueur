extends SceneTree
## ⭐ LES TUILES PUBLIÉES, VÉRIFIÉES AVANT L'EXPORT.
##
## `cartes/pays-<kx>-<ky>.json` sont les tuiles que l'éditeur a poussées dans
## le dépôt ; le jeu les relit telles quelles. Ce banc les passe au même
## contrôle que le bouton Publier (`commun/ville2/controle_tuile.gd`), plus ce
## que seul le dépôt peut vérifier : que le fichier se lit, et que sa taille
## est celle de sa tuile. Une faute → « TUILES FAUTIVES » et le workflow
## d'export abandonne, comme pour le plan.
##
##     godot --headless --path . --script res://outils/verifier_tuiles.gd
##     godot --headless --path . --script res://outils/verifier_tuiles.gd -- --engendrer=2,2
##
## `--engendrer=kx,ky` contrôle une tuile ENGENDRÉE (pas un fichier) : c'est
## ce qui dit si le générateur lui-même passe le contrôle — s'il ne le passe
## pas, le contrôle refuserait toute tuile retouchée, et ce serait le contrôle
## qu'il faudrait corriger.
const CONTROLE := preload("res://commun/ville2/controle_tuile.gd")
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")
const FENETRES := preload("res://commun/ville2/fenetres_pays.gd")

func _init() -> void:
	var fautives := 0
	var vues := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--engendrer="):
			var m := a.trim_prefix("--engendrer=").split(",")
			var cle := Vector2i(int(m[0]), int(m[1]))
			var plan := PLAN.charger()
			var coin := cle * FENETRES.COTE
			var f := Rect2i(coin, Vector2i(FENETRES.COTE, FENETRES.COTE))
			var v: Ville2 = PAYS.fenetre(plan, PLAN.contexte(plan), f, {"nom": "contrôle"})
			vues += 1
			fautives += _controler("engendrée %d,%d" % [cle.x, cle.y], v, f.size)
	var d := DirAccess.open("res://cartes")
	if d != null:
		var noms: Array = []
		for fichier in d.get_files():
			if fichier.begins_with("pays-") and fichier.ends_with(".json"): noms.append(fichier)
		noms.sort()
		for fichier2 in noms:
			var nom := String(fichier2).get_basename()
			var m2 := nom.trim_prefix("pays-").split("-")
			var attendu := Vector2i.ZERO
			if m2.size() == 2:
				var cle2 := Vector2i(int(m2[0]), int(m2[1]))
				var coin2 := cle2 * FENETRES.COTE
				attendu = Vector2i(mini(FENETRES.COTE, PLAN.TAILLE.x - coin2.x),
					mini(FENETRES.COTE, PLAN.TAILLE.y - coin2.y))
			var v2 := Ville2.charger("res://cartes/" + String(fichier2))
			vues += 1
			fautives += _controler(nom, v2, attendu)
	print("%d tuile(s) vue(s), %d fautive(s)" % [vues, fautives])
	print("TUILES FAUTIVES" if fautives > 0 else "TUILES PROPRES")
	quit(1 if fautives > 0 else 0)

func _controler(nom: String, v: Ville2, attendu: Vector2i) -> int:
	var fautes: Array[String] = []
	if attendu == Vector2i.ZERO:
		fautes.append("nom sans clé de tuile (attendu pays-<kx>-<ky>)")
	elif v.taille != attendu:
		fautes.append("taille %s au lieu de %s — le jeu l'ignorerait" % [v.taille, attendu])
	if v.lots.is_empty() and v.routes.is_empty():
		fautes.append("tuile vide ou illisible")
	fautes.append_array(CONTROLE.fautes(v))
	print("%s : %d lots, %d objets, %d routes — %s" % [nom, v.lots.size(), v.objets.size(),
		v.routes.size(), "OK" if fautes.is_empty() else "%d faute(s)" % fautes.size()])
	for f in fautes:
		print("     " + f)
	return 1 if not fautes.is_empty() else 0
