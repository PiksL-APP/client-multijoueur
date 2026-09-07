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
}
const MUR_BAS := "res://modeles/creatures/wall-low.glb"
const MUR_HAUT := "res://modeles/creatures/wall-high.glb"

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

## Un anneau posé à plat. Répété six fois dans ce fichier avant d'être extrait :
## la rotation de 90° s'oublie une fois sur deux et l'anneau part debout.
static func racine_anneau(rayon: float, couleur: Color, epaisseur: float) -> MeshInstance3D:
	var anneau := Decor.anneau(rayon, epaisseur, couleur, 1.0)
	anneau.rotation_degrees = Vector3(90, 0, 0)
	anneau.position = Vector3(0, 0.05, 0)
	return anneau
