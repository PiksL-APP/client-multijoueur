extends SceneTree
## LA CARTE DES TERRITOIRES, telle que le jeu la peint.
##
## ⚠ On appelle `PlanVille.peindre_pate` — LA fonction que la carte du jeu
## (touche TAB) appelle pâté par pâté pendant le chargement. Un banc qui
## redessinerait la ville à sa façon, avec des couleurs franches et un
## quadrillage propre, prouverait seulement que le banc sait dessiner.
##
##   godot --headless -s outils/territoires.gd [-- --code=ESSAI --sortie=/tmp/t.png]

func _init() -> void:
	var code := "RESPECT"
	var sortie := "/tmp/carte/territoires.png"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
		if a.begins_with("--sortie="): sortie = a.trim_prefix("--sortie=")
	var carte := PlanVille.new(code)
	var image := Image.create(PlanVille.COLONNES, PlanVille.LIGNES, false, Image.FORMAT_RGB8)
	var total := PlanVille.pates_x() * PlanVille.pates_y()
	for indice in total:
		carte.peindre_pate(image, indice)
	for sx in PlanVille.pates_x() / PlanVille.SECTEUR + 1:
		for sy in PlanVille.pates_y() / PlanVille.SECTEUR + 1:
			carte.peindre_secteur(image, Vector2i(sx, sy))
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	image.save_png(sortie)
	print("carte %d × %d pâtés → %s" % [PlanVille.pates_x(), PlanVille.pates_y(), sortie])
	quit()
