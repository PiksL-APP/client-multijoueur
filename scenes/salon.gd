extends Ecran
## Salon d'attente d'un jeu : on s'y répartit en tables de quatre, l'hôte lance.
##
## Il n'y a pas de service d'appariement : la répartition se lit dans la
## présence du canal. Chacun calcule la même chose à partir des mêmes métas,
## donc personne n'a besoin d'arbitrer. La table est un simple entier annoncé
## dans sa méta.

const PAR_TABLE := 4

var _jeu: String
var _titre: String
var _canal: CanalTempsReel
var _table: int = 0
var _liste: VBoxContainer
var _bouton_lancer: Button
var _bouton_changer: Button
var _info: Label
var _etat: HBoxContainer

func demarrer() -> void:
	_jeu = String(donnees.get("jeu", "carnage"))
	_titre = String(donnees.get("titre", _jeu.to_upper()))
	UI.fond(interface())
	_construire()

	# ⚠ Le banc d'essai fait la queue dans une file À PART. Sans ce suffixe, un
	# pilote automatique lancé pendant qu'un vrai joueur attend au salon
	# s'assied à sa table — et le joueur voit débarquer « Banc-0eau », qui lui
	# vole ses voitures et lui impose son hôte. C'est arrivé.
	var file := "mj-file-" + _jeu + ("-banc" if Commandes.pilote_automatique else "")
	_canal = Reseau.rejoindre(file, {"pseudo": Session.pseudo, "id": Session.id, "table": 0})
	_canal.presences_changees.connect(_sur_presences)
	_canal.diffusion.connect(_sur_diffusion)
	if _canal.est_rejoint:
		_sur_presences(_canal.presences)

func _exit_tree() -> void:
	if _canal:
		_canal.quitter()

# ---------------------------------------------------------------- tables

func _tables() -> Dictionary:
	var groupes: Dictionary = {}
	for cle in _canal.cles_triees():
		var meta: Dictionary = _canal.presences[cle]
		var t := int(meta.get("table", 0))
		if t <= 0:
			continue
		if not groupes.has(t):
			groupes[t] = []
		groupes[t].append(meta)
	return groupes

## Première table qui a de la place, sinon une nouvelle. Le tri par numéro
## regroupe les joueurs plutôt que de les éparpiller : à deux ou trois
## connectés, tout le monde se retrouve dans la même partie sans rien faire.
func _table_libre(sauf: int = -1) -> int:
	var groupes := _tables()
	var numeros := groupes.keys()
	numeros.sort()
	for t in numeros:
		if t == sauf:
			continue
		if (groupes[t] as Array).size() < PAR_TABLE:
			return int(t)
	var maximum := 0
	for t in numeros:
		maximum = max(maximum, int(t))
	return maximum + 1

func _rejoindre_table(t: int) -> void:
	_table = t
	_canal.suivre({"pseudo": Session.pseudo, "id": Session.id, "table": t})
	_rafraichir()

func _ma_table() -> Array:
	var groupes := _tables()
	return groupes.get(_table, [])

func _je_suis_hote() -> bool:
	var membres := _ma_table()
	return not membres.is_empty() and String(membres[0].get("cle", "")) == Session.cle

# ---------------------------------------------------------------- réseau

func _sur_presences(_presences: Dictionary) -> void:
	if _table == 0:
		_rejoindre_table(_table_libre())
		return
	_rafraichir()

func _sur_diffusion(evenement: String, charge: Dictionary) -> void:
	if evenement != "go":
		return
	if int(charge.get("table", -1)) != _table:
		return
	_partir(String(charge.get("code", "")))

func _lancer() -> void:
	if not _je_suis_hote():
		return
	var code := "%s%d-%d" % ["banc" if Commandes.pilote_automatique else "", _table, Time.get_ticks_msec() % 100000]
	_canal.envoyer("go", {"table": _table, "code": code})
	_partir(code)

## Le pilote automatique lance lui-même la manche, ici, six secondes après
## être devenu hôte d'une table. La boucle de `racine.gd` le fait aussi en
## natif ; dans le navigateur, elle ne repart pas toujours de son `await`, et
## la manche n'était jamais lancée — on cliquait à la main pour observer.
var _attente_pilote := 0.0
var _parti := false

func _process(delta: float) -> void:
	if not Commandes.pilote_automatique or _parti:
		return
	if not _je_suis_hote():
		_attente_pilote = 0.0
		return
	_attente_pilote += delta
	if _attente_pilote > 6.0:
		_parti = true
		print("[banc] manche lancée depuis le salon")
		_lancer()

## Point d'entrée du banc d'essai : lance si et seulement si on est hôte.
func lancer_pour_banc() -> bool:
	if _parti:
		return true
	if not _je_suis_hote():
		return false
	_parti = true
	_lancer()
	return true

func _partir(code: String) -> void:
	if code == "":
		return
	var equipe: Array = []
	for meta in _ma_table():
		equipe.append({
			"cle": String(meta.get("cle", "")),
			"id": String(meta.get("id", "")),
			"pseudo": String(meta.get("pseudo", "?")),
		})
	demande_ecran.emit(_jeu, {
		"jeu": _jeu,
		"titre": _titre,
		"code": code,
		"equipe": equipe,
	})

# ---------------------------------------------------------------- interface

func _construire() -> void:
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	marge.add_theme_constant_override("margin_left", 60)
	marge.add_theme_constant_override("margin_right", 60)
	marge.add_theme_constant_override("margin_top", 40)
	marge.add_theme_constant_override("margin_bottom", 40)
	interface().add_child(marge)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 16)
	marge.add_child(colonne)

	var ligne_titre := HBoxContainer.new()
	ligne_titre.add_theme_constant_override("separation", 16)
	colonne.add_child(ligne_titre)
	var entete := UI.entete("Salon  " + _titre, "")
	entete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne_titre.add_child(entete)
	_etat = UI.etat_reseau()
	ligne_titre.add_child(_etat)

	_info = UI.texte("", 15, Palette.ENCRE_DOUCE, true)
	colonne.add_child(_info)

	var panneau := UI.panneau()
	panneau.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(panneau)
	var defilement := ScrollContainer.new()
	panneau.add_child(defilement)
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 10)
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(_liste)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	colonne.add_child(actions)

	_bouton_lancer = UI.bouton("Lancer la manche", true)
	_bouton_lancer.pressed.connect(_lancer)
	actions.add_child(_bouton_lancer)

	_bouton_changer = UI.bouton("Changer de table")
	_bouton_changer.pressed.connect(func(): _rejoindre_table(_table_libre(_table)))
	actions.add_child(_bouton_changer)

	var retour := UI.bouton("Retour au hub")
	retour.pressed.connect(func(): demande_ecran.emit("hub", {}))
	actions.add_child(retour)

func _rafraichir() -> void:
	UI.rafraichir_etat_reseau(_etat)
	for enfant in _liste.get_children():
		enfant.queue_free()

	var groupes := _tables()
	var numeros := groupes.keys()
	numeros.sort()
	for t in numeros:
		var membres: Array = groupes[t]
		var boite := VBoxContainer.new()
		boite.add_theme_constant_override("separation", 2)
		var entete := UI.titre("TABLE %d   %d/%d" % [t, membres.size(), PAR_TABLE], 16)
		entete.add_theme_color_override("font_color", Palette.ENCRE if t == _table else Palette.ENCRE_FAIBLE)
		boite.add_child(entete)
		if t == _table:
			boite.add_child(UI.texte("votre table", 13, Palette.SERIE))
		var place := 0
		for meta in membres:
			var ligne := HBoxContainer.new()
			ligne.add_theme_constant_override("separation", 10)
			# Le carré de couleur est celui que le joueur portera dans la manche :
			# on sait avant de partir qui est qui.
			var carre := ColorRect.new()
			carre.color = Palette.couleur_joueur(place)
			carre.custom_minimum_size = Vector2(14, 14)
			carre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ligne.add_child(carre)
			ligne.add_child(UI.texte(String(meta.get("pseudo", "?")), 22, Palette.ENCRE if t == _table else Palette.ENCRE_DOUCE))
			if place == 0:
				ligne.add_child(UI.texte("hôte", 13, Palette.AVERTISSEMENT))
			boite.add_child(ligne)
			place += 1
		_liste.add_child(boite)

	var membres_ma_table := _ma_table()
	var nombre := membres_ma_table.size()
	if _je_suis_hote():
		_bouton_lancer.disabled = nombre < 1
		_bouton_lancer.text = "Lancer la manche (%d joueur%s)" % [nombre, "s" if nombre > 1 else ""]
		if nombre < 2:
			_info.text = "Vous êtes hôte de la table %d. À deux, la manche prend tout son sens ; seul, elle sert d'entraînement." % _table
		else:
			_info.text = "Vous êtes hôte de la table %d. Lancez quand tout le monde est là." % _table
	else:
		_bouton_lancer.disabled = true
		_bouton_lancer.text = "En attente de l'hôte"
		_info.text = "Table %d. L'hôte lance la manche." % _table
