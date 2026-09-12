extends Control
## Le dessin du manche et des boutons. Séparé de la logique tactile : ici on
## ne fait que peindre ce que l'autoload a mesuré, aux places qu'il a fixées
## (`Tactile.boutons`) — le dessin et la prise partagent la même table.
##
## La charte est celle de l'affiche (`Charte`), comme tout l'en-jeu depuis le
## 12/09 : chaque bouton a SA couleur — le rose du tir, le cyan de l'action,
## l'orange de l'affaire (celui de l'argent dans le tableau de bord), le blanc
## du menu — et son nom en capitales espacées, cernées pour rester lisibles
## sur une rue claire.
##
## Au repos, trois ronds (TIR, ENTRER, ≡) — quatre quand une affaire est
## possible. Le menu ouvert, tout le reste s'efface et l'éventail se déplie
## sur un voile léger : on choisit, on referme.

var manche_visible := false
var centre := Vector2.ZERO
var pouce := Vector2.ZERO
var bouton_tenu := false
var libelle := "TIR"
var bouton_action_tenu := false
var libelle_action := "ENTRER"
var bouton_affaire_tenu := false
var affaire_possible := false
var tenus: Array = []            ## les noms des boutons sous un doigt
var volet := ""                  ## l'éventail : "", "menu", "sac"
var son_actif := true
var efface := true               ## hors de la ville, sous la carte, sous un menu

## Ce que chaque bouton de l'éventail montre : [libellé, couleur].
const VOLET := {
	"carte": ["CARTE", Color.WHITE],
	"sac": ["SAC", Charte.VERT],
	"radio": ["RADIO", Color("#b48cff")],
	"pause": ["PAUSE", Color.WHITE],
	"klaxon": ["KLAXON", Charte.ORANGE],
	"detonateur": ["BOUM", Charte.ROSE],
	"son": ["SON", Color.WHITE],
	"manger": ["MANGER", Charte.VERT],
	"boire": ["BOIRE", Charte.CYAN],
}

func _draw() -> void:
	# Effacé, le pavé ne laisse rien : la carte a ses boutons, un menu ses
	# lignes, le salon ses boutons à lui.
	if efface:
		return
	var taille := get_viewport_rect().size
	var b: Dictionary = Tactile.boutons(taille)
	var menu: Vector2 = b["menu"][0]
	var r_menu: float = b["menu"][1]

	if volet != "":
		# L'éventail : un voile sur la ville pour le détacher, le menu devenu
		# ✕, et ses boutons — l'un d'eux tenu s'allume.
		draw_rect(Rect2(Vector2.ZERO, taille), Color(Charte.NUIT, 0.35), true)
		for nom in VOLET:
			if not b.has(nom):
				continue
			var fiche: Array = VOLET[nom]
			var ou: Vector2 = b[nom][0]
			draw_line(menu, ou, Color(1, 1, 1, 0.18), 1.5, true)
			var libelle_ := String(fiche[0])
			var couleur: Color = fiche[1]
			if nom == "son" and not son_actif:
				libelle_ = "MUET"
				couleur = Charte.ORANGE
			_rond(ou, float(b[nom][1]), couleur, ("klaxon" if nom == "detonateur" else nom) in tenus, libelle_, 11)
		_rond_menu(menu, r_menu, true)
		return

	_rond(b["tir"][0], float(b["tir"][1]), Charte.ROSE, bouton_tenu, libelle, 18)
	_rond(b["action"][0], float(b["action"][1]), Charte.CYAN, bouton_action_tenu, libelle_action, 15)
	# AFFAIRE ne se montre que quand `F` ferait quelque chose ici : un bouton
	# qui surgit dit « il y a quelque chose à faire ».
	if affaire_possible:
		_rond(b["affaire"][0], float(b["affaire"][1]), Charte.ORANGE, bouton_affaire_tenu, "AFFAIRE", 12)
	_rond_menu(menu, r_menu, false)

	if manche_visible:
		draw_circle(centre, Tactile.RAYON_BASE, Color(1, 1, 1, 0.07))
		draw_arc(centre, Tactile.RAYON_BASE, 0, TAU, 48, Color(1, 1, 1, 0.22), 2.0, true)
		draw_circle(pouce, Tactile.RAYON_POUCE, Color(1, 1, 1, 0.35))
		draw_arc(pouce, Tactile.RAYON_POUCE, 0, TAU, 32, Color(1, 1, 1, 0.6), 1.5, true)
	else:
		# Une empreinte discrète en bas, à droite de la fiche du tableau de
		# bord : elle dit qu'il y a quelque chose à toucher, sans encombrer
		# l'écran tant qu'on n'y touche pas. Le manche se prend n'importe où
		# dans la moitié gauche ; l'empreinte n'est qu'une invitation.
		var repos := Vector2(maxf(taille.x * 0.30, 300.0 + Tactile.RAYON_BASE),
			taille.y - Tactile.MARGE - Tactile.RAYON_BASE - 16.0)
		draw_arc(repos, Tactile.RAYON_BASE, 0, TAU, 48, Color(1, 1, 1, 0.10), 2.0, true)
		draw_circle(repos, 22.0, Color(1, 1, 1, 0.08))

## Un bouton rond : un disque de la couleur, à peine teinté au repos et plein
## sous le doigt ; un anneau net ; le nom au milieu.
func _rond(ou: Vector2, rayon: float, couleur: Color, tenu: bool, nom: String, taille: int) -> void:
	draw_circle(ou, rayon, Color(couleur, 0.34 if tenu else 0.13))
	draw_circle(ou, rayon, Color(Charte.NUIT, 0.25))
	draw_arc(ou, rayon, 0, TAU, 48, Color(couleur, 0.95 if tenu else 0.8), 2.5, true)
	Charte.inscription(self, ou, nom, taille, Color.WHITE if tenu else Color(1, 1, 1, 0.92), 0.16)

## Le menu : trois barres fermé, une croix ouvert — les deux pictogrammes que
## tout le monde lit, et le rond est trop petit pour un mot.
func _rond_menu(ou: Vector2, rayon: float, ouvert: bool) -> void:
	draw_circle(ou, rayon, Color(Charte.NUIT, 0.55 if ouvert else 0.40))
	draw_arc(ou, rayon, 0, TAU, 48, Color(1, 1, 1, 0.9 if ouvert else 0.75), 2.5, true)
	var encre := Color(1, 1, 1, 0.95)
	if ouvert:
		draw_line(ou + Vector2(-8, -8), ou + Vector2(8, 8), encre, 3.0, true)
		draw_line(ou + Vector2(-8, 8), ou + Vector2(8, -8), encre, 3.0, true)
	else:
		for k in 3:
			var y := ou.y + float(k - 1) * 8.0
			draw_line(Vector2(ou.x - 11.0, y), Vector2(ou.x + 11.0, y), encre, 3.0, true)
