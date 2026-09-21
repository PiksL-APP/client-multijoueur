extends SceneTree
## ⭐⭐⭐ TOUTES LES TUILES DU PAYS, CUITES D'AVANCE POUR LE NAVIGATEUR.
##
## Le paquet web est SINGLE-THREADED (« Build configuration: Emscripten,
## single-threaded » dans la console). Dans un tel paquet, un fil n'en est pas
## un : `Thread.start` — comme `WorkerThreadPool.add_task` avant lui — exécute
## la fabrication SUR LE FIL PRINCIPAL, tout de suite. Le jeu, qui bâtit neuf
## fenêtres autour du joueur au démarrage, gelait donc la page pendant toute
## leur fabrication : mesuré chez le client le 19/09, « ville prête en
## 98 156 ms » — une minute et demie sans une image ni un clic, ce qui
## ressemble exactement à une page plantée.
##
## Engendrer dans le navigateur était de toute façon une erreur : le pays est
## déterministe, la même tuile sort du même plan à chaque fois. On la fabrique
## donc UNE FOIS, ici, à l'export (`.github/workflows/exporter-web.yml`, étape
## « Engendrer les tuiles »), dans `cartes/pays-<kx>-<ky>.json.gz` — que
## `FenetresPays._lire_ou_engendrer` relit avant d'engendrer. Une tuile
## publiée depuis l'éditeur (`.json`, en clair) est déjà là : on ne la touche
## pas, c'est la retouche du client qui gagne. Une tuile de pleine mer est
## écrite aussi, vide : la relire ne coûte rien, l'engendrer coûtait des
## secondes.
##
## ⚠ GZIPPÉES : une tuile fait trois mégaoctets de JSON, vingt-cinq tuiles en
## feraient soixante-quinze à télécharger — plus que tous les modèles. Gzippée,
## dix fois moins. `Ville2.charger` sait lire les deux.
##
##     godot --headless --path . --script res://outils/engendrer_tuiles.gd
##     godot --headless --path . --script res://outils/engendrer_tuiles.gd -- --seulement=2,2
##
## Les fichiers ne vont PAS dans le dépôt : ils naissent dans la copie de
## l'action et partent dans le paquet. Trente mégaoctets de JSON par export
## que Git n'a pas à porter.
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")
const FENETRES := preload("res://commun/ville2/fenetres_pays.gd")

func _init() -> void:
	var seulement := Vector2i(-1, -1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			var m := a.trim_prefix("--seulement=").split(",")
			if m.size() == 2: seulement = Vector2i(int(m[0]), int(m[1]))
	var plan := PLAN.charger()
	var ctx := PLAN.contexte(plan)
	var cote: int = FENETRES.COTE
	var nx := int(ceil(float(PLAN.TAILLE.x) / float(cote)))
	var ny := int(ceil(float(PLAN.TAILLE.y) / float(cote)))
	var faites := 0
	var gardees := 0
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute("res://cartes")
	for ky in ny:
		for kx in nx:
			var cle := Vector2i(kx, ky)
			if seulement.x >= 0 and cle != seulement: continue
			var chemin := "res://cartes/pays-%d-%d.json" % [kx, ky]
			if FileAccess.file_exists(chemin) or FileAccess.file_exists(chemin + ".gz"):
				gardees += 1
				continue
			var coin := cle * cote
			var f := Rect2i(coin, Vector2i(mini(cote, PLAN.TAILLE.x - coin.x),
				mini(cote, PLAN.TAILLE.y - coin.y)))
			var t1 := Time.get_ticks_msec()
			var v: Ville2 = PAYS.fenetre(plan, ctx, f, {"nom": "Aurones %d,%d" % [coin.x, coin.y]})
			if v == null or not v.enregistrer(chemin + ".gz"):
				push_error("tuile %d,%d : impossible d'écrire %s" % [kx, ky, chemin])
				quit(1)
				return
			faites += 1
			print("tuile %d,%d : %d lots, %d objets, %d routes — %d ms" % [kx, ky,
				v.lots.size(), v.objets.size(), v.routes.size(), Time.get_ticks_msec() - t1])
	print("TUILES CUITES : %d engendrée(s), %d gardée(s) (publiées) — %d s" % [
		faites, gardees, (Time.get_ticks_msec() - t0) / 1000])
	quit(0)
