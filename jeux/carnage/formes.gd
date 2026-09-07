class_name FormesCarnage
extends RefCounted
## Les volumes de CARNAGE. Rien n'est importé : tout se monte à partir de
## `commun/decor.gd`, sauf la carrosserie et le kit de ville, qui sont les deux
## seules ressources binaires que ce dépôt s'autorise.
##
## Pourquoi un fichier à part : depuis que le jeu compte des piétons, des
## gangs, des flics, des voitures de patrouille, des barrages, des cabines et
## des garages, la fabrique pesait plus lourd que la partie. Séparée, elle se
## relit sans traverser la simulation.

const MODELES_ARMES := {
	"pistolet": "res://modeles/creatures/blaster.glb",
	"mitraillette": "res://modeles/creatures/blaster-repeater.glb",
	"roquette": "res://modeles/creatures/blaster.glb",
	"eperon": "res://modeles/personnages/coin.glb",
	"vie": "res://modeles/personnages/coin.glb",
	"argent": "res://modeles/personnages/coin.glb",
}
const MUR_BAS := "res://modeles/creatures/wall-low.glb"
const MUR_HAUT := "res://modeles/creatures/wall-high.glb"

## Le parc automobile : le kit de voitures de Kenney (CC0). L'indice est ce qui
## circule sur le réseau — un joueur qui vole un taxi doit être vu dans un
## taxi par les trois autres, pas dans une berline générique.
const VOITURES := "res://modeles/voitures/"
const MODELES_VOITURES := ["sedan", "sedan-sports", "hatchback-sports", "suv", "suv-luxury",
	"taxi", "van", "delivery", "truck", "police"]
const MODELE_POLICE := 9
## Ce que chaque quartier gare et fait rouler. Le centre roule en taxi, la zone
## industrielle en fourgon, la banlieue en break : c'est ce qui fait qu'on sait
## où l'on est en regardant ce qui passe.
const VOITURES_PAR_QUARTIER := {
	PlanVille.CENTRE: [0, 1, 4, 5, 5, 5, 1],
	PlanVille.AFFAIRES: [0, 1, 4, 4, 5, 1, 0],
	PlanVille.COMMERCE: [0, 0, 1, 4, 5, 6, 2],
	PlanVille.VIEUX: [0, 2, 2, 0, 5, 3, 6],
	PlanVille.RESIDENCES: [0, 0, 2, 3, 6, 0, 2],
	PlanVille.INDUSTRIE: [6, 6, 7, 7, 8, 8, 3],
	PlanVille.PORT: [7, 8, 8, 6, 3, 7, 6],
	PlanVille.BANLIEUE: [0, 0, 3, 3, 2, 6, 4],
	PlanVille.PARC: [0, 2, 3],
	PlanVille.EAU: [0],
}

## Les carrosseries FUSIONNÉES : le kit livre chaque voiture en cinq maillages
## (la caisse et quatre roues). Une nappe ne prend qu'un maillage par
## instance ; on recolle donc les cinq en un seul, une fois, par modèle. C'est
## ce qui permet de peindre cent cinquante voitures dormantes d'un morceau en
## dix appels de dessin au lieu de sept cent cinquante.
static var _fusionnees: Dictionary = {}
static var _matieres_teintees: Dictionary = {}

static func maillage_voiture(indice: int) -> Mesh:
	var nom := String(MODELES_VOITURES[clamp(indice, 0, MODELES_VOITURES.size() - 1)])
	return maillage_fusionne(VOITURES + nom + ".glb")

## Un glTF entier CUIT en un seul maillage, transformations de nœuds comprises.
## ⚠ `Decor.maillage` ne prend que le premier maillage et ignore l'échelle de
## son nœud : le conteneur du kit industriel est modélisé trois fois trop grand
## et ramené par son nœud à 0,27 — pris brut, il faisait vingt-cinq mètres.
static func maillage_fusionne(chemin: String) -> Mesh:
	if _fusionnees.has(chemin):
		return _fusionnees[chemin]
	var scene := (load(chemin) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var matiere: Material = null
	var pile: Array = [[scene, Transform3D()]]
	while not pile.is_empty():
		var entree: Array = pile.pop_back()
		var noeud: Node = entree[0]
		var t: Transform3D = entree[1]
		if noeud is Node3D:
			t = t * (noeud as Node3D).transform
		if noeud is MeshInstance3D:
			var m := (noeud as MeshInstance3D).mesh
			for s in m.get_surface_count():
				st.append_from(m, s, t)
				if matiere == null:
					matiere = m.surface_get_material(s)
		for enfant in noeud.get_children():
			pile.append([enfant, t])
	var fusion := st.commit()
	if matiere != null and fusion.get_surface_count() > 0:
		fusion.surface_set_material(0, matiere)
	scene.free()
	_fusionnees[chemin] = fusion
	return fusion

## La matière du kit, qui accepte la couleur d'instance : c'est elle qui fait
## qu'une voiture de gang dans une nappe porte ses couleurs.
static func matiere_voiture_teintee(indice: int) -> Material:
	var nom := String(MODELES_VOITURES[clamp(indice, 0, MODELES_VOITURES.size() - 1)])
	if _matieres_teintees.has(nom):
		return _matieres_teintees[nom]
	var origine := maillage_voiture(indice).surface_get_material(0)
	var copie: BaseMaterial3D = (origine as BaseMaterial3D).duplicate() if origine is BaseMaterial3D else StandardMaterial3D.new()
	copie.vertex_color_use_as_albedo = true
	copie.roughness = 0.55
	_matieres_teintees[nom] = copie
	return copie

## Les phares d'une voiture conduite : deux flaques chaudes devant, une lueur
## rouge derrière. Au crépuscule, c'est ce qui dit dans quel sens on roule et
## ce qu'on va percuter — bien avant la silhouette.
static func phares(racine: Node3D, avant: float, arriere: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flaque(st, Vector3(avant + 4.6, 0.05, 0.0), Vector3(6.0, 0, 0), Vector3(0, 0, 4.4), Color(1.0, 0.82, 0.55, 0.55))
	_flaque(st, Vector3(arriere - 1.2, 0.05, 0.0), Vector3(1.8, 0, 0), Vector3(0, 0, 1.9), Color(1.0, 0.15, 0.1, 0.35))
	var noeud := MeshInstance3D.new()
	noeud.mesh = st.commit()
	noeud.material_override = MatieresCarnage.flaque()
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	noeud.name = "Phares"
	racine.add_child(noeud)
	# Les optiques elles-mêmes : deux points chauds à l'avant, deux rouges à l'arrière.
	var lum := SurfaceTool.new()
	lum.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cote in [-0.75, 0.75]:
		_flaque(lum, Vector3(avant, 0.95, cote), Vector3(0.2, 0, 0), Vector3(0, 0, 0.3), Color(1.0, 0.95, 0.8, 1.0))
		_flaque(lum, Vector3(arriere, 0.9, cote), Vector3(0.15, 0, 0), Vector3(0, 0, 0.28), Color(1.0, 0.2, 0.15, 1.0))
	var optiques := MeshInstance3D.new()
	optiques.mesh = lum.commit()
	optiques.material_override = MatieresCarnage.lumineux()
	optiques.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	optiques.name = "Optiques"
	racine.add_child(optiques)

static func _flaque(st: SurfaceTool, centre: Vector3, dx: Vector3, dz: Vector3, couleur: Color) -> void:
	var p := [centre - dx - dz, centre + dx - dz, centre + dx + dz, centre - dx + dz]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(couleur)
		st.set_uv(uvs[k])
		st.set_normal(Vector3.UP)
		st.add_vertex(p[k])
## Le kit de Kenney fait ses berlines en 2,55 unités de long ; la Volvo du
## joueur en fait 4,5. Sans cette mise à l'échelle, on volerait des voitures
## deux fois plus petites que la sienne.
const ECHELLE_VOITURE := 1.75
## ⚠ Le kit regarde vers +Z ; le jeu roule vers +X. Un pivot intermédiaire
## porte la correction, et lui seul : la corriger sur la racine casserait le
## halo et la jauge, qui ne doivent pas tourner avec.
const ROTATION_KIT := PI * 0.5

## Une nappe d'instances d'un même modèle, avec UNE COULEUR PAR INSTANCE.
##
## `Decor.nappe` teinte toute la nappe d'un bloc. Ici il faut que chaque tuile
## porte la pointe de couleur de son territoire — c'est ce qui rend une
## frontière de gang lisible au sol sans planter un panneau. Le multi-maillage
## passe la couleur d'instance au shader, et `vertex_color_use_as_albedo` la
## MULTIPLIE avec l'atlas du kit. Sans ce drapeau, la couleur est simplement
## ignorée, sans message.
static func nappe(chemin: String, transformations: Array, couleurs: Array,
		ombre: bool, teinte: Color = Color.WHITE) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = Decor.maillage(chemin)
	multi.instance_count = transformations.size()
	for i in transformations.size():
		multi.set_instance_transform(i, transformations[i])
		multi.set_instance_color(i, couleurs[i] if i < couleurs.size() else Color.WHITE)
	var noeud := MultiMeshInstance3D.new()
	noeud.multimesh = multi
	var origine := multi.mesh.surface_get_material(0)
	if origine is BaseMaterial3D:
		var copie := (origine as BaseMaterial3D).duplicate() as BaseMaterial3D
		copie.albedo_color = teinte
		copie.roughness = 0.85
		copie.vertex_color_use_as_albedo = true
		noeud.material_override = copie
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

# ------------------------------------------------------------ véhicules

## Une voiture. `halo` marque celles que quelqu'un conduit — sans lui, dans
## l'ombre d'un immeuble la carrosserie devient noire et on ne se retrouve
## plus. `gyrophare` ajoute la rampe des voitures de police, qui doit se voir
## AVANT d'entendre la sirène.
static func voiture(couleur: Color, pseudo: String = "", halo: bool = true,
		gyrophare: bool = false) -> Node3D:
	var racine := Node3D.new()

	if halo:
		var anneau := Decor.anneau(2.7, 0.22, couleur, 0.95)
		anneau.rotation_degrees = Vector3(90, 0, 0)
		anneau.position = Vector3(0, 0.04, 0)
		anneau.name = "Halo"
		racine.add_child(anneau)

	var carrosserie := Decor.carrosserie(couleur)
	# La coque de modélisme n'a pas de garde au sol : on la soulève de la
	# hauteur des roues, sinon la voiture rase le bitume et les roues
	# dépassent par-dessus les ailes.
	carrosserie.position = Vector3(0, 0.42, 0)
	carrosserie.name = "Coque"
	racine.add_child(carrosserie)

	# La coque est creuse et ses vitres sont ouvertes : vu de dessus, on
	# voyait la route à travers l'habitacle. Un bloc sombre glissé dedans
	# referme la voiture sans coûter de géométrie.
	var habitacle := Decor.boite(Vector3(4.2, 0.55, 1.7), Palette.FOND.lightened(0.06))
	habitacle.position = Vector3(-0.15, 0.78, 0)
	habitacle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(habitacle)

	for cote in [-1.0, 1.0]:
		for avant in [-1.0, 1.0]:
			var roue := Decor.cylindre(0.62, 0.42, Color("#0b0b0b"))
			roue.rotation_degrees = Vector3(90, 0, 0)
			roue.position = Vector3(avant * 1.95, 0.62, cote * 1.02)
			racine.add_child(roue)
			var jante := Decor.cylindre(0.34, 0.46, Palette.ENCRE_FAIBLE)
			jante.rotation_degrees = Vector3(90, 0, 0)
			jante.position = Vector3(avant * 1.95, 0.62, cote * 1.02)
			racine.add_child(jante)

	# Deux phares : ils disent dans quel sens la voiture regarde, ce qu'une
	# silhouette vue de haut ne montre pas.
	for cote in [-1.0, 1.0]:
		var phare := Decor.sphere(0.22, Palette.AVERTISSEMENT)
		phare.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 1.2)
		phare.position = Vector3(2.85, 1.0, cote * 0.72)
		racine.add_child(phare)

	if gyrophare:
		var rampe := Node3D.new()
		rampe.name = "Gyrophare"
		for cote in [-1.0, 1.0]:
			var feu := Decor.boite(Vector3(0.5, 0.3, 0.55), Palette.SERIE, false)
			feu.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.5)
			feu.position = Vector3(-0.2, 1.35, cote * 0.42)
			rampe.add_child(feu)
		racine.add_child(rampe)

	# Le pare-buffle n'apparaît qu'avec l'éperon : il devient ainsi le signe
	# visible du bonus, au lieu d'un accessoire permanent qui alourdit la
	# silhouette d'une berline.
	var pare_buffle := Decor.boite(Vector3(0.3, 0.85, 2.2), Palette.SERIE)
	pare_buffle.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.1)
	pare_buffle.position = Vector3(3.05, 0.75, 0)
	pare_buffle.name = "Buffle"
	pare_buffle.visible = false
	racine.add_child(pare_buffle)

	phares(racine, 2.85, -2.3)

	var jauge := Decor.barre(3.4)
	jauge.name = "Vie"
	jauge.position = Vector3(0, 2.9, 0)
	racine.add_child(jauge)

	if pseudo != "":
		var nom := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 32)
		nom.name = "Nom"
		nom.position = Vector3(0, 4.2, 0)
		racine.add_child(nom)
	return racine

## Une voiture du kit de Kenney. `halo` et `pseudo` la marquent comme conduite
## par un joueur ; `couleur` à blanc garde la peinture d'usine (un taxi reste
## jaune), sinon la teinte descend sur toute la carrosserie — c'est ainsi que
## les voitures d'un gang portent ses couleurs.
static func voiture_kit(indice: int, couleur: Color = Color.WHITE, halo_couleur: Color = Color.WHITE,
		pseudo: String = "", halo: bool = false) -> Node3D:
	var racine := Node3D.new()
	var nom := String(MODELES_VOITURES[clamp(indice, 0, MODELES_VOITURES.size() - 1)])

	if halo:
		var anneau := Decor.anneau(2.7, 0.22, halo_couleur, 0.95)
		anneau.rotation_degrees = Vector3(90, 0, 0)
		anneau.position = Vector3(0, 0.04, 0)
		anneau.name = "Halo"
		racine.add_child(anneau)

	var pivot := Node3D.new()
	pivot.name = "Coque"
	pivot.rotation.y = ROTATION_KIT
	var corps := Decor.instance(VOITURES + nom + ".glb", couleur, 0.45)
	corps.scale = Vector3.ONE * ECHELLE_VOITURE
	pivot.add_child(corps)
	racine.add_child(pivot)

	if indice == MODELE_POLICE:
		var rampe := Node3D.new()
		rampe.name = "Gyrophare"
		for cote in [-1.0, 1.0]:
			var feu := Decor.boite(Vector3(0.5, 0.3, 0.55), Palette.SERIE, false)
			feu.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.5)
			feu.position = Vector3(-0.2, 2.6, cote * 0.5)
			rampe.add_child(feu)
		racine.add_child(rampe)

	var pare_buffle := Decor.boite(Vector3(0.3, 0.85, 2.2), Palette.SERIE)
	pare_buffle.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.1)
	pare_buffle.position = Vector3(2.6, 0.75, 0)
	pare_buffle.name = "Buffle"
	pare_buffle.visible = false
	racine.add_child(pare_buffle)

	phares(racine, 2.25, -2.2)

	var jauge := Decor.barre(3.4)
	jauge.name = "Vie"
	jauge.position = Vector3(0, 3.1, 0)
	racine.add_child(jauge)

	if pseudo != "":
		var nom_j := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 32)
		nom_j.name = "Nom"
		nom_j.position = Vector3(0, 4.4, 0)
		racine.add_child(nom_j)
	return racine

## Le tag d'un repaire : la couleur du gang peinte au sol, son initiale, et une
## couronne. C'est le repère qu'on voit de loin — et ce qu'on vise quand on
## vient nettoyer.
static func tag_de_gang(couleur: Color, nom: String) -> Node3D:
	var racine := Node3D.new()
	var dalle := Decor.cylindre(PlanVille.RAYON_REPAIRE * Decor.ECHELLE * 0.5, 0.08, couleur, false)
	dalle.material_override = Decor.matiere_lumineuse(couleur, 0.55, 0.35)
	dalle.position = Vector3(0, 0.06, 0)
	racine.add_child(dalle)
	racine.add_child(racine_anneau(PlanVille.RAYON_REPAIRE * Decor.ECHELLE, couleur, 0.14))
	var initiale := Decor.etiquette(nom.substr(0, 1).to_upper() if nom.length() > 0 else "?", couleur, 96)
	initiale.rotation_degrees = Vector3(-90, 0, 0)
	initiale.position = Vector3(0, 0.12, 0)
	racine.add_child(initiale)
	var mot := Decor.etiquette("REPAIRE — " + nom.to_upper(), couleur, 30)
	mot.position = Vector3(0, 3.6, 0)
	racine.add_child(mot)
	return racine

## Une épave : la même coque, éteinte, penchée, avec de la fumée. Elle reste au
## sol quelques secondes — une voiture qui disparaît d'un coup laisse croire à
## un défaut d'affichage.
static func epave() -> Node3D:
	var racine := Node3D.new()
	var coque := Decor.carrosserie(Color("#141414"))
	coque.position = Vector3(0, 0.35, 0)
	coque.rotation_degrees = Vector3(0, 0, 6)
	racine.add_child(coque)
	var braise := Decor.sphere(0.9, Palette.SERIEUX, false)
	braise.material_override = Decor.matiere_lumineuse(Palette.SERIEUX, 1.4)
	braise.position = Vector3(0, 0.9, 0)
	braise.name = "Braise"
	racine.add_child(braise)
	return racine

# ------------------------------------------------------------ personnages

## Un piéton, un membre de gang, un flic ou un joueur à pied. Le fanion est ce
## qui distingue un membre de gang d'un passant : la couleur seule ne suffit
## pas, une silhouette de trois pixels dans une rue sombre ne se lit pas.
static func pieton(couleur: Color, fanion: bool = false, pseudo: String = "",
		halo: bool = false) -> Node3D:
	var racine := Node3D.new()
	var corps := Decor.personnage(couleur, 2.6)
	corps.name = "Silhouette"
	racine.add_child(corps)

	if halo:
		var anneau := Decor.anneau(1.5, 0.16, couleur, 0.95)
		anneau.rotation_degrees = Vector3(90, 0, 0)
		anneau.position = Vector3(0, 0.05, 0)
		anneau.name = "Halo"
		racine.add_child(anneau)

	if fanion:
		var hampe := Decor.boite(Vector3(0.1, 1.1, 0.1), Palette.ENCRE_FAIBLE, false)
		hampe.position = Vector3(-0.5, 2.6, 0)
		racine.add_child(hampe)
		var etoffe := Decor.boite(Vector3(0.08, 0.5, 0.7), couleur, false)
		etoffe.material_override = Decor.matiere_lumineuse(couleur, 1.0)
		etoffe.position = Vector3(-0.5, 2.9, 0.35)
		racine.add_child(etoffe)

	var jauge := Decor.barre(1.6)
	jauge.name = "Vie"
	jauge.position = Vector3(0, 3.4, 0)
	racine.add_child(jauge)

	if pseudo != "":
		var nom := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 28)
		nom.name = "Nom"
		nom.position = Vector3(0, 4.4, 0)
		racine.add_child(nom)
	return racine

# ------------------------------------------------------------ les lieux

## Le sol d'un garage de peinture : une dalle lumineuse sous la façade. Sans
## marque au sol, une porte de garage dans laquelle on peut entrer ressemble à
## un mur — et on ne l'essaie jamais.
static func dalle_garage() -> Node3D:
	var racine := Node3D.new()
	var dalle := Decor.cylindre(PlanVille.RAYON_GARAGE * Decor.ECHELLE, 0.1, Palette.SERIE, false)
	dalle.material_override = Decor.matiere_lumineuse(Palette.SERIE, 0.5, 0.42)
	dalle.position = Vector3(0, 0.06, 0)
	racine.add_child(racine_anneau(PlanVille.RAYON_GARAGE * Decor.ECHELLE, Palette.SERIE, 0.16))
	racine.add_child(dalle)
	var enseigne := Decor.etiquette("PEINTURE", Palette.SERIE, 30)
	enseigne.position = Vector3(0, 3.2, 0)
	racine.add_child(enseigne)
	return racine

## L'enceinte d'une arène : un anneau au sol, quatre bornes, et le mot. Le tir
## ami s'y allume — il faut donc qu'on sache qu'on y entre AVANT d'y être.
static func cercle_arene(numero: int) -> Node3D:
	var racine := Node3D.new()
	var rayon := PlanVille.RAYON_ARENE * Decor.ECHELLE
	racine.add_child(racine_anneau(rayon, Palette.CRITIQUE, 0.34))
	racine.add_child(racine_anneau(rayon * 0.62, Palette.CRITIQUE, 0.14))
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var borne := Decor.instance(MUR_BAS, Palette.CRITIQUE, 0.5)
		borne.scale = Vector3.ONE * 2.4
		borne.position = Vector3(cos(angle) * rayon, 0.0, sin(angle) * rayon)
		borne.rotation.y = -angle
		racine.add_child(borne)
	var mot := Decor.etiquette("ARÈNE %d — TIR AMI" % (numero + 1), Palette.CRITIQUE, 34)
	mot.position = Vector3(0, 4.0, 0)
	racine.add_child(mot)
	return racine

## Une cabine : un caisson, une antenne, un halo. Elle sonne quand un contrat
## attend — c'est le halo qui clignote, pas la cabine qui bouge : un objet qui
## se déplace en ville se prend pour une cible.
static func cabine(numero: int) -> Node3D:
	var racine := Node3D.new()
	var caisson := Decor.boite(Vector3(1.1, 2.4, 1.1), Palette.SURFACE.lightened(0.1))
	caisson.position = Vector3(0, 1.2, 0)
	racine.add_child(caisson)
	var vitre := Decor.boite(Vector3(0.9, 1.1, 0.9), Palette.SERIE, false)
	vitre.material_override = Decor.matiere_voile(Palette.SERIE, 0.4)
	vitre.position = Vector3(0, 1.7, 0)
	racine.add_child(vitre)
	var halo := Decor.anneau(PlanVille.RAYON_CABINE * Decor.ECHELLE, 0.14, Palette.AVERTISSEMENT, 1.0)
	halo.rotation_degrees = Vector3(90, 0, 0)
	halo.position = Vector3(0, 0.06, 0)
	halo.name = "Halo"
	racine.add_child(halo)
	var mot := Decor.etiquette("CONTRAT %d" % (numero + 1), Palette.AVERTISSEMENT, 26)
	mot.name = "Mot"
	mot.position = Vector3(0, 3.4, 0)
	racine.add_child(mot)
	return racine

## Un barrage de police : deux blocs en travers de la rue. Ils bloquent pour de
## vrai — c'est le seul obstacle du jeu que la police ajoute, et il doit se
## contourner, pas se traverser.
static func barrage() -> Node3D:
	var racine := Node3D.new()
	for cote in [-1.0, 1.0]:
		var bloc := Decor.instance(MUR_HAUT, Palette.SERIE, 0.55)
		bloc.scale = Vector3.ONE * 3.0
		bloc.position = Vector3(0, 0, cote * 2.6)
		racine.add_child(bloc)
	var gyro := Decor.sphere(0.4, Palette.SERIE, false)
	gyro.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.6)
	gyro.position = Vector3(0, 2.4, 0)
	gyro.name = "Gyro"
	racine.add_child(gyro)
	return racine

## L'hélicoptère de la police : une cellule, une queue, un rotor qui tourne et un
## projecteur au sol. Le projecteur est ce qui compte : c'est lui qu'on voit
## arriver de loin sur la chaussée, avant même d'entendre les pales.
static func helico() -> Node3D:
	var racine := Node3D.new()
	var corps := Node3D.new()
	corps.name = "Cellule"
	corps.position = Vector3(0, 26.0, 0)
	var cellule := Decor.boite(Vector3(3.6, 1.6, 1.8), Palette.SERIE.darkened(0.55))
	cellule.position = Vector3(0, 0, 0)
	corps.add_child(cellule)
	var queue := Decor.boite(Vector3(3.4, 0.5, 0.5), Palette.SERIE.darkened(0.55))
	queue.position = Vector3(-3.2, 0.3, 0)
	corps.add_child(queue)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, 1.1, 0)
	for i in 2:
		var pale := Decor.boite(Vector3(7.0, 0.08, 0.4), Palette.ENCRE_FAIBLE, false)
		pale.rotation.y = PI * 0.5 * float(i)
		rotor.add_child(pale)
	corps.add_child(rotor)
	var feu := Decor.sphere(0.35, Palette.SERIE, false)
	feu.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.6)
	feu.position = Vector3(0, -0.9, 0)
	feu.name = "Feu"
	corps.add_child(feu)
	racine.add_child(corps)

	# Le faisceau : un cône de voile du ciel au sol, et une flaque de lumière.
	var faisceau := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 7.0
	cone.height = 26.0
	faisceau.mesh = cone
	faisceau.material_override = Decor.matiere_voile(Palette.ENCRE, 0.09)
	faisceau.position = Vector3(0, 13.0, 0)
	faisceau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(faisceau)
	var flaque := Decor.cylindre(7.0, 0.06, Palette.ENCRE, false)
	flaque.material_override = Decor.matiere_lumineuse(Palette.ENCRE, 0.5, 0.35)
	flaque.position = Vector3(0, 0.08, 0)
	racine.add_child(flaque)
	return racine

## Une caisse d'arme : un socle lumineux au sol, l'objet qui flotte au-dessus.
## C'est la grammaire habituelle du ramassage, et elle se repère de loin dans
## une rue encombrée là où une caisse posée se confond avec le mobilier.
static func caisse(arme: String, couleur: Color) -> Node3D:
	var racine := Node3D.new()
	var socle := Decor.cylindre(1.9, 0.12, couleur, false)
	socle.material_override = Decor.matiere_lumineuse(couleur, 0.75, 0.5)
	socle.position = Vector3(0, 0.08, 0)
	racine.add_child(socle)
	racine.add_child(racine_anneau(2.1, couleur, 0.16))

	var objet := Decor.instance(String(MODELES_ARMES.get(arme, MODELES_ARMES["pistolet"])), couleur, 0.5)
	objet.scale = Vector3.ONE * (4.2 if arme == "eperon" else 2.0)
	objet.name = "Objet"
	objet.position = Vector3(0, 1.6, 0)
	racine.add_child(objet)
	return racine

## La fumée d'un pot d'échappement, ou d'un moteur qui souffre : un émetteur
## de particules processeur, ce que le mode compatibilité fait de mieux. Il ne
## tourne que quand on accélère — un panache permanent cache la voiture.
static func echappement(arriere: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Fumee"
	p.amount = 22
	p.lifetime = 0.9
	p.emitting = false
	p.local_coords = false
	var grain := SphereMesh.new()
	grain.radius = 0.22
	grain.height = 0.44
	grain.radial_segments = 6
	grain.rings = 3
	p.mesh = grain
	p.direction = Vector3(-1.0, 0.5, 0.0)
	p.spread = 22.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, 1.4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.8, 0.8, 0.82, 0.45))
	teinte.set_color(1, Color(0.6, 0.6, 0.64, 0.0))
	p.color_ramp = teinte
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(arriere, 0.45, 0.6)
	return p

## Une explosion : une bouffée de feu qui vire au noir, tirée d'un coup. Le
## nœud se détruit tout seul à la fin de sa vie.
static func explosion() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 46
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	p.local_coords = false
	var grain := SphereMesh.new()
	grain.radius = 0.5
	grain.height = 1.0
	grain.radial_segments = 6
	grain.rings = 3
	p.mesh = grain
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0, -5.0, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	var teinte := Gradient.new()
	teinte.add_point(0.0, Color(1.0, 0.85, 0.5, 1.0))
	teinte.set_color(1, Color(1.0, 0.45, 0.15, 0.95))
	teinte.add_point(0.45, Color(0.25, 0.22, 0.2, 0.8))
	teinte.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0))
	p.color_ramp = teinte
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Un anneau posé à plat. Répété six fois dans ce fichier avant d'être extrait :
## la rotation de 90° s'oublie une fois sur deux et l'anneau part debout.
static func racine_anneau(rayon: float, couleur: Color, epaisseur: float) -> MeshInstance3D:
	var anneau := Decor.anneau(rayon, epaisseur, couleur, 1.0)
	anneau.rotation_degrees = Vector3(90, 0, 0)
	anneau.position = Vector3(0, 0.05, 0)
	return anneau
