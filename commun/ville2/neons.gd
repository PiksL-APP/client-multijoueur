extends RefCounted
## LES ENSEIGNES AU NÉON — ce qui fait qu'un quartier chaud existe la nuit.
##
## ⚠ UN NÉON N'EST PAS UNE AFFICHE DE PLUS. Le client a demandé, le même jour,
## MOINS de pub et PLUS de néon dans le quartier chaud : les deux ne sont pas
## la même chose et ne se posent pas au même endroit. Une pub est une image
## mate, grande, espacée, qu'on regarde depuis la voiture ; un néon est une
## source de couleur, petite, RÉPÉTÉE sur chaque façade, qu'on voit à hauteur
## de trottoir. Une rue chaude a trois panneaux et quarante enseignes.
##
## On les pose donc là où la pub ne va pas : sur la façade de CHAQUE bâtiment
## qui donne sur la rue, au-dessus de la porte, sans écart minimal.

const CASE := Ville2.CASE

## ⚠ DES COULEURS SATURÉES ET PEU NOMBREUSES. Une rue dont chaque enseigne a
## sa propre teinte fait un arc-en-ciel et ne se lit plus ; six couleurs
## reviennent assez souvent pour que la rue ait une gamme.
const COULEURS := ["#ff2f6e", "#ff7a1a", "#28e0d0", "#c04cff", "#ffd21a", "#2f8cff"]

## La hauteur du bas de l'enseigne, au-dessus du trottoir.
const HAUTEUR := 7.0

## Pose une enseigne sur la façade de chaque lot des genres demandés qui donne
## sur une case de chaussée. Rend le nombre posé.
static func semer(v: Ville2, alea: RandomNumberGenerator, genres: Array = [],
		densite := 0.75) -> int:
	var poses := 0
	for l in v.lots:
		if not genres.is_empty() and not genres.has(String(l.get("genre", ""))): continue
		if alea.randf() > densite: continue
		var m := String(l["m"])
		var t := KitVille2.taille(m)
		var q := int(l["q"])
		var centre := v.centre_du_lot(l)
		var ici := Vector2i(floori(centre.x / CASE), floori(centre.z / CASE))
		# La façade d'un modèle est son −Z ; `q` quarts de tour plus loin :
		var facade := Vector2i(0, -1)
		for _k in q: facade = Vector2i(facade.y, -facade.x)
		if v.carte == null or not v.carte.route(ici + facade): continue
		# Le mur qui porte l'enseigne, et la demi-profondeur qui la met dehors.
		var mur := (t.x if q % 2 == 0 else t.z) * CASE
		var demi := (t.z if q % 2 == 0 else t.x) * CASE * 0.5
		var large := clampf(mur * 0.55, 3.0, 11.0)
		# ⚠ JAMAIS PLUS HAUT QUE LE BÂTIMENT. Une enseigne posée à sept mètres
		# sur une remise de quatre flotte au-dessus du toit — c'est le défaut
		# « j'ai des pubs qui volent », et il se reproduirait ici.
		var haut_bati := t.y * CASE
		var y := minf(HAUTEUR, maxf(2.2, haut_bati - 2.2))
		if haut_bati < 4.0: continue
		v.objets.append({"m": "neon",
			"x": centre.x + float(facade.x) * (demi + 0.5),
			"z": centre.z + float(facade.y) * (demi + 0.5),
			"r": atan2(float(facade.x), float(facade.y)),
			"h": 0.0, "y": y, "w": large, "hh": clampf(large * 0.26, 1.0, 2.4),
			"c": COULEURS[alea.randi() % COULEURS.size()],
			# ⚠ Une enseigne est en FAÇADE, au-dessus du trottoir : la passe de
			# propreté la retirerait comme « objet sur la chaussée ». Elle est
			# du mobilier de voirie, comme un lampadaire.
			"voirie": true})
		poses += 1
	return poses
