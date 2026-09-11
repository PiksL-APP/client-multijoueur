extends Partie
## CARNAGE — une ville ouverte vue de dessus, deux minutes de trop-plein.
##
## L'ancien Carnage était un jeu de voiture : on écrasait, on ne descendait
## jamais. Celui-ci se joue comme un GTA 2 : on sort de la berline, on court,
## on tire, on pique la voiture d'un autre, on ramasse cinq étoiles et on va
## se faire repeindre au garage. Trois gangs tiennent leurs rues et se
## souviennent de qui les a saignés. Deux esplanades marquées au sol allument
## le tir ami : partout ailleurs, on joue la ville ensemble.
##
## Répartition du travail, inchangée dans son principe : chaque client simule
## SON personnage — la commande répond à l'image, pas au réseau — et l'HÔTE
## simule tout ce qui est partagé, dans `jeux/carnage/vivant.gd`. Laisser le
## tireur déclarer ses victimes serait plus nerveux et complètement indéfendable :
## deux joueurs revendiqueraient le même passant à cent millisecondes près.
##
## Le plan de la ville ne circule pas : il se déduit du CODE de la manche
## (`jeux/carnage/plan.gd`). Même code, même ville, chez tout le monde, y
## compris pour qui rejoint en retard.

const DUREE := 240.0

# ------------------------------------------------------- conduite
# Des valeurs d'arcade, pas de simulation. On veut qu'une voiture reparte vite
# après un choc, sinon le jeu punit la maladresse trop longtemps.
const ACCELERATION := 940.0
const FREIN := 1550.0
const VITESSE_MAX := 760.0
const VITESSE_ARRIERE := -270.0
const FROTTEMENT := 1.6
const BRAQUAGE := 2.9              ## rad/s au braquage plein ; 3,6 rendait la voiture nerveuse comme un kart
## La voiture a du POIDS : sa trajectoire suit son cap avec un retard qui
## grandit avec la vitesse — à fond, elle dérive dans les virages ; au pas,
## elle tourne sur place. C'est l'inertie qui manquait pour que la conduite
## se sente, sans rien enlever du contrôle.
const ADHERENCE_LENTE := 11.0
const ADHERENCE_RAPIDE := 3.4
## La collision de la voiture est une CAPSULE — deux cercles à l'avant et à
## l'arrière — et non un cercle de sa demi-longueur : celui-ci cognait un mur
## situé à dix pixels du flanc, et toute la conduite en rue étroite s'en
## sentait.
const RAYON_CAPSULE := 13.0
const DEMI_EMPATTEMENT := 15.0
const PRISE_PLEINE := 165.0        ## vitesse à partir de laquelle on braque à fond
const RAYON_VOITURE := 26.0
const PV_VOITURE := 100.0

# ------------------------------------------------------- à pied
const VITESSE_A_PIED := 215.0
const RAYON_A_PIED := 16.0
const PORTEE_ENTREE := 110.0       ## distance à laquelle on peut ouvrir une portière
## À quelle distance d'une berge on peut débarquer d'un bateau. Une tuile et
## demie : de quoi accoster sans avoir à coller la coque au quai au centimètre.
const PORTEE_QUAI := 150.0
const DELAI_PORTIERE := 0.45       ## on ne ressort pas dans la même seconde

const VIE_MAX := 100.0
const REGEN := 6.0                 ## points de vie par seconde, après une accalmie
const ACCALMIE := 6.0              ## secondes sans coup avant que ça reparte
const HORS_SERVICE := 4.0

## À pied, on encaisse deux fois plus : c'est ce qui fait qu'on remonte en
## voiture au lieu de traverser la ville à découvert.
const FRAGILITE_A_PIED := 2.0

const CADENCE_JOUEUR := 1.0 / 12.0
const CADENCE_INSTANTANE := 1.0 / 8.0

# Caméra presque à la verticale : en ville, une inclinaison basse met un
# immeuble entre l'œil et la voiture toutes les trois secondes. À pied on se
# rapproche, sinon le personnage fait quatre pixels.
## ⚠ 79°, pas 70 : avec les tours du centre, à 70° une tour au sud du joueur le
## cachait entièrement. À 76° et des tours de trente unités, la façade d'une
## tour en bas d'écran couvrait encore un quart de l'image. GTA 2 se joue de
## dessus ; on recule un peu pour garder la rue entière.
const INCLINAISON := 72.0
const DISTANCE_AUTO := 64.0
const DISTANCE_PIED := 40.0

const RETOUR := 260.0              ## rappel vers le centre au-delà de la friche

## Ce qu'on DESSINE est plus étroit que ce que l'hôte diffuse : l'écran couvre
## treize cents pixels de large, et chaque voiture garée vaut cinq appels de
## dessin, chaque passant sept. À seize cents pixels, on en dessinait trois
## cents pour en voir quarante — et un navigateur en mode compatibilité tombe
## à dix images par seconde.
const PORTEE_RENDU := 1050.0
## Et on ne bâtit pas plus de quelques maillages par image : soixante voitures
## instanciées d'un coup à l'entrée d'un quartier font une saccade d'une
## demi-seconde qu'on prend pour un plantage.
const BATISSES_PAR_IMAGE := 6
## Les MORCEAUX de ville : bâtis quand leur bord passe à moins de
## PORTEE_MORCEAU du joueur, un par image au plus, libérés au-delà de
## LIBERATION. Neuf morceaux suffisent à couvrir l'écran et sa marge.
const PORTEE_MORCEAU := 1500.0
const LIBERATION := 3400.0
## La caméra recule avec la vitesse : à fond, on voit venir le carrefour.
const RECUL_VITESSE := 16.0

## Les armes. Le pistolet ne s'épuise jamais : sans lui, un joueur à pied et à
## court de munitions n'a plus qu'à attendre la fin de la manche.
const ARMES := {
	"pistolet": {
		"nom": "Pistolet", "munitions": -1, "cadence": 0.32, "portee": 720.0,
		"vitesse": 1250.0, "souffle": 0.0, "degat": 16.0, "couleur": Palette.ENCRE_DOUCE,
	},
	"mitraillette": {
		"nom": "Mitraillette", "munitions": 60, "cadence": 0.10, "portee": 950.0,
		"vitesse": 1500.0, "souffle": 0.0, "degat": 14.0, "couleur": Palette.AVERTISSEMENT,
	},
	"roquette": {
		"nom": "Roquettes", "munitions": 6, "cadence": 0.85, "portee": 1200.0,
		"vitesse": 900.0, "souffle": 170.0, "degat": 90.0, "couleur": Palette.SERIEUX,
	},
	"eperon": {
		"nom": "Éperon", "munitions": 0, "cadence": 0.0, "portee": 0.0,
		"vitesse": 0.0, "souffle": 0.0, "degat": 0.0, "couleur": Palette.SERIE,
	},
	# LA MITRAILLEUSE DE BORD (atelier). Elle n'entre jamais dans `_arme` : on
	# la prend à la place de son arme TANT QU'ON EST AU VOLANT, et on retrouve
	# la sienne en descendant. Sinon l'achat coûtait au joueur le fusil qu'il
	# venait de ramasser.
	"canon": {
		"nom": "Mitrailleuse de bord", "munitions": -1, "cadence": 0.13, "portee": 880.0,
		"vitesse": 1450.0, "souffle": 0.0, "degat": 12.0, "couleur": Color("#f2c53d"),
	},
}
const DUREE_EPERON := 16.0

## Toutes les voitures ne se conduisent pas pareil : la sportive file, le
## camion pèse et encaisse, la police pousse. Sans ça, voler une voiture ne
## change que la peinture — et on ne vole plus rien.
## v : vitesse de pointe, a : accélération, t : solidité de la tôle.
const CARACTERES := {
	-1: {"v": 1.0, "a": 1.0, "t": 1.0},     # la Volvo
	0: {"v": 1.0, "a": 1.0, "t": 1.0},      # berline
	1: {"v": 1.2, "a": 1.18, "t": 0.75},    # berline sport
	2: {"v": 1.14, "a": 1.22, "t": 0.7},    # compacte sport
	3: {"v": 0.96, "a": 0.95, "t": 1.25},   # 4x4
	4: {"v": 1.05, "a": 1.0, "t": 1.15},    # 4x4 de luxe
	5: {"v": 1.0, "a": 1.05, "t": 0.9},     # taxi
	6: {"v": 0.9, "a": 0.85, "t": 1.3},     # fourgon
	7: {"v": 0.82, "a": 0.72, "t": 1.6},    # camion de livraison
	8: {"v": 0.78, "a": 0.68, "t": 1.8},    # camion
	9: {"v": 1.12, "a": 1.1, "t": 1.0},     # police
	10: {"v": 1.22, "a": 1.2, "t": 0.7},    # coupé
	11: {"v": 0.98, "a": 0.95, "t": 1.1},   # break
	12: {"v": 0.95, "a": 0.9, "t": 1.3},    # pick-up
	13: {"v": 0.72, "a": 0.6, "t": 2.2},    # bus
	14: {"v": 0.95, "a": 0.8, "t": 1.4},    # limousine
	15: {"v": 1.0, "a": 0.95, "t": 1.3},    # ambulance
	16: {"v": 1.24, "a": 1.45, "t": 0.35},  # moto : file et tourne, mais rien autour de soi
	17: {"v": 1.34, "a": 1.55, "t": 0.3},   # moto de course
	18: {"v": 0.86, "a": 0.74, "t": 2.0},   # camion de pompiers
	# La course et le tracteur sont les deux BOUTS de l'échelle, et c'est fait
	# exprès : trouver l'une ou l'autre doit changer la minute qui suit.
	19: {"v": 1.45, "a": 1.55, "t": 0.4},   # voiture de course : la plus rapide, en papier
	20: {"v": 0.52, "a": 0.5, "t": 2.6},    # tracteur : increvable, et on le voit venir
	21: {"v": 0.7, "a": 0.6, "t": 2.1},     # benne à ordures
	22: {"v": 0.86, "a": 0.76, "t": 1.5},   # plateau de livraison
	# LA FLOTTE. Un bateau n'a pas de freins : sa décélération vient du
	# frottement de l'eau, réglé plus bas (`FROTTEMENT_EAU`). Ce qu'on met ici,
	# c'est ce qu'il file et ce qu'il encaisse.
	23: {"v": 0.55, "a": 0.5, "t": 0.9},    # chaloupe
	24: {"v": 1.05, "a": 0.9, "t": 0.8},    # vedette
	25: {"v": 1.18, "a": 1.0, "t": 0.7},    # vedette rapide
	26: {"v": 0.7, "a": 0.6, "t": 1.2},     # barque de pêche
	27: {"v": 0.62, "a": 0.45, "t": 2.4},   # remorqueur
}

## Le butin qui n'est pas une arme : une trousse rend cinquante points de vie,
## un billet vaut cent vingt dollars — comptés par l'hôte, comme tout le reste.
const COULEURS_BUTIN := {"vie": Palette.BON, "argent": Palette.AVERTISSEMENT}
const SOIN_TROUSSE := 50.0
const KLAXON_DELAI := 0.9

## Chaque arme a sa détonation. Un pistolet et une mitraillette qui claquent
## pareil, ce sont deux armes qu'on ne distingue qu'à l'écran — et l'oreille
## va plus vite que l'œil quand on est trois à tirer dans la même rue.
const SONS_ARMES := {
	"pistolet": "tir_pistolet", "mitraillette": "tir_mitraillette",
	"roquette": "tir_roquette", "eperon": "choc_metal", "canon": "tir_mitraillette",
}

## Le grain du moteur suit le châssis : la sportive siffle, le camion gronde.
## Les modèles absents roulent au moteur standard.
const MOTEURS_VEHICULE := {
	1: "sport", 2: "sport", 9: "sport", 10: "super", 14: "super",
	16: "compact", 17: "sport",
	3: "van", 4: "van", 6: "van", 12: "van", 15: "van",
	7: "camion", 8: "camion", 13: "camion", 18: "camion",
	19: "super", 20: "camion", 21: "camion", 22: "camion",
	# ⚠ Pas de moteur de bateau dans la banque de sons : le hors-bord prend le
	# grain « compact » et le remorqueur celui du camion. Inventer un son de
	# diesel marin demanderait une prise, pas une ligne de table.
	23: "compact", 24: "compact", 25: "sport", 26: "compact", 27: "camion",
}

## Identifiant de la voiture de départ. Elle n'appartient à personne dans la
## liste de l'hôte tant qu'on ne l'a pas quittée : le premier `sortir` la lui
## fait découvrir. Le nombre est haut pour ne jamais croiser un identifiant
## engendré pendant la manche.
const ID_VOITURE_DEPART := 10000
## Le véhicule qu'on ressort du garage. Un identifiant à lui, jamais celui du
## véhicule de départ ni d'une dormante : deux voitures qui portent le même
## numéro, et l'une efface l'autre de la nappe chez les autres joueurs.
const ID_VOITURE_GARAGE := 11000

var carte: PlanVille
var ville: VilleVivante
var _ambiance: Array = []            ## [WorldEnvironment, soleil, lune], réglés à l'heure du village
var _meteo: MeteoCarnage = null      ## le temps qu'il fait, lu sur l'horloge universelle comme l'heure
var _morceaux: Dictionary = {}       ## Vector2i -> MorceauVille, les morceaux bâtis ou en chantier
var _chantier: MorceauVille = null   ## le morceau en cours de construction, une étape par image
var _cachees: Dictionary = {}        ## id dormante -> vrai : déjà effacée de sa nappe

# ------------------------------------------------------- le joueur local
var _position := Vector2.ZERO
var _angle := 0.0
var _vitesse := 0.0
var _glisse := Vector2.RIGHT          ## la direction réelle du mouvement (l'inertie)
# ------------------------------------------------------- l'argent et la planque
#
# Les points sont des DOLLARS. Ce qu'on a sur soi (`_argent`) se perd quand on
# tombe : la police ramasse. Ce qu'on a déposé à la planque (`_banque`) est à
# l'abri, et c'est lui qui donne une raison de rentrer chez soi vivant plutôt
# que de foncer jusqu'à la mort. Le score du classement reste la FORTUNE
# totale (sur soi + en banque) : le tableau ne change pas de sens.
var _argent := 0
var _banque := 0
var _planque := -1                 ## l'identifiant de la planque possédée, ou -1
var _ameliorations: Dictionary = {"coffre": false, "arsenal": false, "garage": false}
var _garage_perso := -1            ## le modèle de véhicule rangé à la planque, ou -1
var _planque_en_cours := -1        ## la planque dans laquelle on se tient

# ------------------------------------------------------- chez soi, à l'intérieur

## ENTRER CHEZ SOI. La planque n'était qu'un disque peint au sol : on s'arrêtait
## dessus, on appuyait sur F, l'argent partait « à l'abri » et rien ne le
## montrait. Les huit appartements de `Interieurs` existaient depuis longtemps
## et ne se voyaient qu'au banc photo — c'est là qu'ils entrent dans le jeu.
##
## ⚠ L'INTÉRIEUR EST BÂTI LOIN SOUS LA VILLE (`Interieurs.SOUS_SOL`), pas à sa
## place — et la constante vit là-bas pour que le banc de photo cadre au même
## endroit que le jeu.
## En tuiles. Une tuile fait deux mètres : on ouvre son coffre à un mètre
## quatre-vingts, et la porte à un mètre quatre-vingts aussi.
const PORTEE_COFFRE := 0.9
const PORTEE_PORTE := 0.9
## Le pas à l'intérieur, en tuiles par seconde. Dehors on marche à 215 px/s,
## soit 2,15 tuiles de ville ; un appartement fait six tuiles de large, et à
## cette allure on le traverse en une seconde et demie — c'est trop, on se
## cogne partout. Deux tuiles par seconde (quatre mètres) se pilote.
const PAS_DEDANS := 2.0

# ------------------------------------------------------- la faim et la soif
#
## DEUX JAUGES QUI DESCENDENT, et une ville où l'on peut rester indéfiniment.
## C'est ce qui manquait à une manche sans chrono : sans horloge, rien
## n'oblige plus à sortir de la voiture — on tourne, on tire, on ne rentre
## jamais. La faim et la soif remettent une PENDULE, mais une pendule qu'on
## peut remonter, ce qui n'est pas du tout la même chose qu'un compte à rebours.
##
## ⚠ ELLES VIVENT CHEZ LE CLIENT. C'est un état personnel : personne d'autre
## n'a besoin de savoir que vous avez faim, et la vie — qui, elle, voyage déjà
## — suffit à raconter ce qui vous arrive aux trois autres joueurs. Les faire
## passer par l'hôte, ce serait deux nombres de plus à quinze paquets par
## seconde pour une information que personne ne lit.
##
## LA SOIF DESCEND PLUS VITE QUE LA FAIM, et c'est voulu : l'eau est l'article
## le moins cher de la supérette. On a donc un besoin fréquent et bon marché
## (qui apprend le geste) et un besoin lent et coûteux (qui fait faire des
## courses). Deux jauges à la même vitesse, ce serait une seule jauge dessinée
## deux fois.
const FAIM_MAX := 100.0
const DUREE_FAIM := 260.0          ## s pour passer de plein à vide
const DUREE_SOIF := 200.0
## À pied on se dépense : on a faim plus vite qu'au volant. Le facteur est
## petit (un tiers) — assez pour qu'un long trajet à pied se paie, pas assez
## pour punir qui descend de voiture, ce que le jeu passe son temps à demander.
const EFFORT_A_PIED := 1.35
## Ce que coûte le ventre vide, par seconde. À deux points, on tient cinquante
## secondes à pleine vie : de quoi comprendre, trouver une supérette et y
## arriver. À cinq, on mourait avant d'avoir lu le message.
const DEGAT_JEUNE := 2.0
## En dessous, la jauge passe au rouge et le tableau de bord le dit. Vingt
## pour cent : le même seuil que la réserve d'une voiture, et pour la même
## raison — il faut prévenir AVANT la panne, pas pendant.
const SEUIL_CREUX := 20.0

var _faim := FAIM_MAX
var _soif := FAIM_MAX
var _creux_dit := 0.0              ## anti-répétition de l'annonce
var _provisions: Dictionary = {}   ## cle d'article -> nombre, SUR SOI
var _frigo: Dictionary = {}        ## le même, dans le frigo de la planque
## LA SORTIE D'UNE MANCHE. Carnage n'a pas de chrono, et depuis que le hub et
## l'écran de résultats ont disparu, `Partie.terminer()` n'était plus appelé de
## nulle part : une manche ne finissait JAMAIS — ni retour au salon, ni
## classement, ni dépôt en base. ÉCHAP est la sortie.
var _depuis_raid := 0.0            ## cadence de l'annonce « je tiens le terrain »
var _pause_ouverte := false
var _pause_vue: Control
var _superette_en_cours := -1
var _superette_ouverte := false
var _superette_vue: Control

# ------------------------------------------------------------ le train
#
## LE TRAIN (§1.3), côté joueur. La simulation vit chez l'hôte
## (`VilleVivante._animer_les_trains`) ; ici on pose les rames, les quais, et
## on gère le seul geste qu'il demande : `E` à quai.
##
## ⚠ Un passager reste À PIED. Il n'est pas « au volant » d'un train : il ne le
## conduit pas, ne le tire pas, ne le rend pas. `_pied` reste vrai et c'est
## `_train` qui dit qu'on voyage — ce qui évite d'apprendre à toute la
## conduite, au klaxon, à la radio et au réseau ce qu'est une locomotive.
var _train := -1                   ## l'identifiant de la rame où l'on voyage, ou -1
var _place_train := 0.0            ## où l'on se tient dans la rame, en px depuis la tête
var _quai_dit := 0.0               ## anti-répétition de l'annonce « train à quai »
var _quais_poses := false
var _compacteurs: Array = []       ## les casses posées le long de la voie
var _depuis_roulement := 0.0
var _depuis_corne := 4.0
var _depuis_chenilles := 0.0       ## cadence du roulement entendu quand une rame passe
const PORTEE_TRAIN := 130.0        ## px : d'où l'on peut sauter dedans, à quai

var _dedans := ""                  ## l'identifiant de l'appartement où l'on est, ou ""
var _dedans_p := Vector2.ZERO      ## où l'on s'y tient, EN TUILES
var _dedans_noeud: Node3D
var _hopital_en_cours := -1
var _affaire := ""                 ## ce que F ferait ici, pour la ligne du HUD
var _mot_affaire := ""             ## le dernier message d'affaire, affiché deux secondes
var _mot_affaire_reste := 0.0

## Le tarif de l'hôpital : on ressort debout, la note est salée.
const SOIN := 400
## Ce que la police ramasse quand on tombe : TOUT ce qu'on a sur soi quand on
## a une planque où l'on aurait pu le mettre à l'abri — la moitié seulement
## tant qu'on n'en a pas, sinon le premier achat est hors de portée et la
## mécanique ne démarre jamais.
const SAISIE := 1.0
const SAISIE_SANS_PLANQUE := 0.5

var _pied := false
var _vehicule := 0
var _genre_vehicule: int = VilleVivante.CIVILE
var _modele_vehicule := -1        ## -1 : la Volvo de départ ; sinon un indice du kit
var _pv_vehicule := PV_VOITURE
var _vie := VIE_MAX
var _sonne := 0.0
var _hors_service := 0.0
var _depuis_coup := 99.0
var _depuis_portiere := 0.0
var _arme := "pistolet"
var _munitions := -1
var _eperon := 0.0
var _recharge := 0.0
var _dernier_agresseur := ""
var _hors_ville := 0.0
var _garage_en_cours := -1
## LA PEINTURE de la voiture qu'on conduit. `Color.WHITE` = la teinte d'origine
## du modèle. Elle voyage avec la position (`tc`) et suit la carrosserie quand
## on descend — une voiture repeinte qu'on retrouve rouge en revenant, c'est
## un garage qui ment.
var _teinte := Color.WHITE
var _etoiles_vues := 0             ## pour n'annoncer une escalade qu'en MONTANT
## L'AUTORADIO (guide, phase 10). Six stations, et CHAQUE CARROSSERIE a la
## sienne par défaut : on monte dans un taxi, on tombe sur les infos ; dans une
## sportive, sur la synthé. C'est le détail de GTA 2 qui donne une personnalité
## à une voiture volée — sans lui, changer de véhicule ne change que la tôle.
##
## ⚠ Les morceaux sont ceux du dépôt (CC0, `sons/*.ogg`) : le jeu ne fabrique
## pas de musique, et personne ici n'a de licence à distribuer. « Police » n'a
## pas de morceau — c'est la fréquence de la police, qui ne joue que des voix.
const RADIO_DB := -11.0            ## plus bas que le thème : les sirènes passent devant
var _station := Sons.STATION_SILENCE
var _station_dite := 0.0           ## secondes pendant lesquelles on affiche le nom
var _roue_vue: Control             ## la roue des stations (ui/roue.gd)
var _roue := false                 ## tenue ouverte tant que R est enfoncée
var _roue_choix := 0

## LA TRICHE (code Konami). Voir `ui/triche.gd` : elle coûte le classement.
var _triche_vue: Control
var _triche_ouverte := false
var _invincible := false
var _triche_avant := {}            ## fronts des touches du menu
var _colis := 0                    ## colis trouvés, et sur combien
var _colis_sur := 0
var _frenzy: Dictionary = {}       ## le défi en cours : {a, n, f, r}

## LE TAXI (guide §4.3). Un métier attaché à une CARROSSERIE : on devient
## chauffeur en volant un taxi, on cesse de l'être en le laissant. Pas de
## menu, pas de bouton « prendre le service » — la voiture est le contrat.
const PRIX_COURSE := 32            ## dollars par pâté (100 px) à vol d'oiseau
const PRIME_COURSE_MIN := 140
const PORTEE_CLIENT := 110.0       ## à quelle distance un piéton hèle
const PORTEE_DEPOT := 110.0
var _course: Dictionary = {}       ## {} ou {"p": destination, "depart": Vector2}

## LES CASCADES, version sans axe vertical.
##
## ⚠ Le guide (§4.3) parle de SAUTS — « Insane Stunt ». Notre ville est plate
## et la voiture n'a pas d'altitude : un tremplin ne peut rien décoller. La
## cascade est donc le FRÔLEMENT : passer à pleine vitesse au ras d'une
## voiture qui roule, sans la toucher. Même geste, même risque, même récompense
## — et c'est vérifiable, ce qu'un saut simulé ne serait pas.
const VITESSE_FROLEMENT := 240.0
const RAYON_FROLEMENT := 54.0      ## au-delà, ce n'est plus un frôlement
const FENETRE_CASCADE := 3.0       ## secondes pour enchaîner
const PRIME_FROLEMENT := 90
const CASCADE_MAX := 5
var _froles: Dictionary = {}       ## id d'auto -> temps du dernier frôlement
var _cascade := 0
var _cascade_reste := 0.0
## L'ATELIER. Les modifications tiennent au VÉHICULE qu'on conduit, pas au
## joueur : on descend, on les laisse avec la voiture. Sauf les plaques, qui
## sont une affaire de police et suivent le joueur, et la bombe, qui reste sur
## la carrosserie — c'est tout son intérêt.
var _mods: Dictionary = {}         ## "mitrailleuse" -> true, "mines"/"huile" -> stock
var _plaques := 0.0                ## secondes de plaques maquillées restantes
var _largage := 0.0                ## délai entre deux pièges
var _atelier_en_cours := -1
const MUNITIONS_PIEGE := 4         ## ce qu'un achat met dans le coffre
const DELAI_LARGAGE := 0.9
const DUREE_PLAQUES := 45.0
var _cabine_en_cours := -1
var _contrat: Dictionary = {}
var _depuis_sirene := 0.0
var _depuis_klaxon := 0.0
var _depuis_battement := 0.0
var _depuis_derapage := 0.0
var _depuis_pas := 0.0
var _depuis_radio := 0.0
var _cible_contrat: Dictionary = {}
var _contrat_duree := 0.0            ## durée initiale du contrat en main, pour le sablier du HUD
var _radar: Control
var _plan_image: Image                ## la carte entière, un pixel par tuile, peinte par lots
var _plan_texture: ImageTexture
var _plan_pate := 0                   ## prochain pâté à peindre
var _plan_secteur := 0                ## prochain secteur dont peindre les lieux
var _plan_vue: Control                ## l'incrustation, TAB tenu
var _hud_banniere: Label
var _banniere_reste := 0.0
var _territoire_vu := -99
var _quartier_vu := -99

var _traces: MultiMesh                ## les traces de pneus, en anneau
var _trace_suivante := 0
var _depuis_trace := 0.0
const TRACES_MAX := 320
var _autres: Dictionary = {}       ## cle -> état distant + nœuds 3D
var _projectiles: Array = []
var _eclats: Array = []
var _taches: Array = []

var _corps_auto: Node3D
var _corps_pied: Node3D
var _camera: Camera3D
var _secousse := 0.0
var _rng := RandomNumberGenerator.new()

var _place := 0
var _depuis_envoi := 0.0
var _depuis_instantane := 0.0
var _sortie_de_banc := false
var _rentre_de_banc := false
var _pulsation := false

func duree_manche() -> float:
	return DUREE

func aide() -> String:
	return "Z/S : avancer et freiner · Q/D : tourner · ESPACE : tirer · E : monter ou descendre · F : affaires (planque, hôpital) · G : manger ou boire · V : vue subjective · H : klaxon · TAB : carte · ÉCHAP : pause et sortie de la ville · caisse = arme, trousse ou billet · colis doré = à ramasser · crâne rouge = Kill Frenzy · au volant d'un taxi, F prend et dépose un client · garage bleu = étoiles effacées, et un sur deux est un ATELIER (F sur une pastille) · cabine verte/jaune/rouge = contrat (la couleur dit ce qu'il faut de respect) · tag de gang au sol = son repaire, il ouvre à 80 de respect (armurerie) · maison violette = planque à acheter · croix blanche = hôpital · dalle verte SUPÉRETTE = à manger et à boire (le frigo de la planque les garde) · quai GARE = le train, E pour monter quand il est à l'arrêt · dalle CASSE au bord de la voie = F broie la voiture contre de l'argent et une arme"

# ------------------------------------------------------- mise en place

func preparer() -> void:
	var chrono := Time.get_ticks_msec()
	# Carnage n'a plus de chrono : on reste en ville tant qu'on veut, on rentre
	# déposer son argent, et on sort par le hub. Le banc garde une fin
	# (`duree_forcee`), sinon il ne rendrait jamais la main.
	sans_limite = Partie.duree_forcee <= 0.0
	_rng.randomize()
	carte = PlanVille.new(code)
	ville = VilleVivante.new(carte, _rng)

	_planter_decor()

	# Le départ ne se tire pas au hasard : il se déduit de la place à la table,
	# donc du même calcul chez tout le monde. Deux clients qui tireraient
	# séparément mettraient deux joueurs au même carrefour une fois sur trois.
	var graine := RandomNumberGenerator.new()
	graine.seed = hash(code) + 977
	var place := 0
	for membre in donnees.get("equipe", []):
		if String(membre.get("cle", "")) == Session.cle:
			break
		place += 1
	_place = place
	var pose := carte.depart(place, graine)
	_position = pose["p"]
	_angle = float(pose["a"])
	# `--banc-position=colonne,ligne` (en tuiles) : partir ailleurs qu'au
	# centre. La ville fait six cent quatre-vingts tuiles ; sans ça, le banc ne
	# photographierait jamais le port ni la banlieue.
	if Commandes.pilote_automatique:
		for argument in OS.get_cmdline_args():
			if String(argument).begins_with("--banc-position="):
				var xy := String(argument).substr(16).split(",")
				if xy.size() == 2:
					_position = carte.point_de_rue(_rng,
						Vector2(float(xy[0]), float(xy[1])) * PlanVille.PAS, 0.0, 160.0)
				elif String(argument).ends_with("etoile"):
					# `--banc-position=etoile` : partir près de la grande place, dont
					# la position dépend du code de la manche.
					_position = carte.point_de_rue(_rng, carte.place_etoile(), 320.0, 480.0)
				elif String(argument).ends_with("pont"):
					# `--banc-position=pont` : sur un tablier, l'eau des deux côtés.
					_position = carte.un_pont()
				elif String(argument).ends_with("superette"):
					# `--banc-position=superette` : devant une boutique. Les
					# supérettes se tirent par secteur, on ne peut donc pas
					# écrire leur tuile à la main — et sans cette option, un
					# pilote au hasard n'en croise pas une en une minute.
					var pres: Array = carte.lieux_autour(_position, PlanVille.SECTEUR * PlanVille.PAS * 2.0)["superettes"]
					if not pres.is_empty():
						_position = Vector2(pres[0]["p"])
				elif String(argument).ends_with("garage"):
					# `--banc-position=garage` : sous le portail d'un garage de
					# peinture. La voiture ressort repeinte à la première image :
					# c'est la seule façon de photographier une peinture du
					# garage dans la ville, avec sa lumière et ses ombres, et pas
					# sur l'herbe de la visionneuse.
					var garages: Array = carte.lieux_autour(_position, PlanVille.SECTEUR * PlanVille.PAS * 2.0)["garages"]
					if not garages.is_empty():
						_position = Vector2(garages[0]["p"])
				elif String(argument).ends_with("rail"):
					# `--banc-position=rail` : au quai le plus central. La voie
					# dépend du code de la manche, qui est tiré au lancement —
					# on ne peut donc PAS écrire la tuile d'une gare à la main,
					# et sans cette option le train ne serait jamais photographié
					# autrement que dans un banc de formes.
					var milieu := Vector2(float(PlanVille.COLONNES) * PlanVille.PAS * 0.5,
						float(PlanVille.LIGNES) * PlanVille.PAS * 0.5)
					var court := 1.0e12
					for g in ville.gares():
						var p := ville.point_de_voie(float(g))
						if p.distance_to(milieu) < court:
							court = p.distance_to(milieu)
							_position = p
	# ⚠ LE PILOTE DU BANC PART AVEC DE QUOI PAYER. Il commence à zéro comme
	# tout le monde et ramasse des billets au hasard de ce qu'il renverse : en
	# une minute de banc il n'avait jamais les quarante dollars d'une bouteille
	# d'eau, et la supérette — la caisse, le refus, les poches pleines — ne
	# passait donc JAMAIS par une manche. Un joueur, lui, part bien à zéro.
	if Commandes.pilote_automatique:
		_argent = 900
		# `--banc-subjectif` : la manche commence à hauteur d'homme. C'est la
		# seule façon de PHOTOGRAPHIER la vue subjective — les touches
		# synthétiques n'atteignent pas le clavier physique, et une vue qu'on
		# ne peut pas photographier est une vue qu'on ne juge pas.
		if "--banc-subjectif" in OS.get_cmdline_args():
			_subjectif = true
	_vehicule = ID_VOITURE_DEPART + place
	_pied = false
	# La manche commence AU VOLANT : la radio s'allume avec elle, sur la
	# station de la Volvo de départ. C'est aussi ce qui remet le thème du hub
	# en marche — `Partie.demarrer` vient de le couper.
	_allumer_la_radio(_modele_vehicule)

	_corps_auto = FormesCarnage.voiture(_ma_couleur(), Session.pseudo)
	_corps_auto.add_child(FormesCarnage.echappement(-2.4))
	FormesCarnage.projecteurs(_corps_auto, 2.2)
	monde().add_child(_corps_auto)

	# Le post-traitement (vignette, grain) : premier enfant de la couche, donc
	# SOUS l'interface — le HUD ne doit pas prendre le grain. ⚠ Il obéit au
	# réglage « effets » du hub : c'est une passe plein écran qui relit l'image,
	# donc la première chose à couper sur une machine lente — et le joueur qui
	# la coupe dans les options doit la voir disparaître ici aussi.
	if Reglages.effets and not ("--sans-effets" in OS.get_cmdline_args()):
		var post := ColorRect.new()
		post.name = "Post"
		post.set_anchors_preset(Control.PRESET_FULL_RECT)
		post.mouse_filter = Control.MOUSE_FILTER_IGNORE
		post.material = MatieresCarnage.post()
		interface().add_child(post)
		interface().move_child(post, 0)

	# Les traces de pneus : une nappe d'instances qu'on réutilise en anneau.
	# Un rectangle par roue et par pas de temps, qui pâlit avec l'âge.
	_traces = MultiMesh.new()
	_traces.transform_format = MultiMesh.TRANSFORM_3D
	_traces.use_colors = true
	var dalle := QuadMesh.new()
	dalle.size = Vector2(1.0, 1.0)
	dalle.orientation = PlaneMesh.FACE_Y
	_traces.mesh = dalle
	_traces.instance_count = TRACES_MAX
	for i in TRACES_MAX:
		_traces.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0)))
		_traces.set_instance_color(i, Color(0, 0, 0, 0))
	var noeud_t := MultiMeshInstance3D.new()
	noeud_t.multimesh = _traces
	noeud_t.material_override = MatieresCarnage.trace()
	noeud_t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde().add_child(noeud_t)
	# À pied, on est le personnage choisi à la création : c'est le même casting
	# dans le menu et dans la rue.
	_corps_pied = FormesCarnage.pieton(_ma_couleur(), false, Session.pseudo, true,
		Session.personnage_affiche())
	_corps_pied.visible = false
	monde().add_child(_corps_pied)

	# La bannière : le nom du quartier et de qui le tient, quand on y entre.
	# Le sol change de teinte, mais une teinte ne se nomme pas toute seule.
	# Elle se pose sous les étoiles du HUD, qui occupent le haut du milieu.
	_hud_banniere = UI.titre("", 16)
	_hud_banniere.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_banniere.offset_top = 64
	_hud_banniere.offset_bottom = 90
	_hud_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interface().add_child(_hud_banniere)

	# Le plan, en haut à droite : sous le bandeau du socle, et à l'opposé des
	# boutons tactiles, qui vivent en bas à droite.
	_radar = Control.new()
	_radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_radar.offset_left = -200.0
	_radar.offset_right = -6.0
	_radar.offset_top = 56.0
	_radar.offset_bottom = 268.0
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.set_script(load("res://ui/radar.gd"))
	_radar.carte = carte
	interface().add_child(_radar)

	_camera = Decor.camera(INCLINAISON, DISTANCE_AUTO, 54.0)
	monde().add_child(_camera)
	_camera.make_current()
	Tactile.mode = Tactile.CONDUITE

	# La carte de la ville (TAB) : une image d'un pixel par tuile, peinte par
	# lots pendant la manche, incrustée au milieu de l'écran tant qu'on tient la
	# touche. C'est la carte de GTA 2 : l'île, la rivière, la voie ferrée, les
	# quartiers, et où l'on est.
	_plan_image = Image.create(PlanVille.COLONNES, PlanVille.LIGNES, false, Image.FORMAT_RGB8)
	_plan_image.fill(PlanVille.CARTE_EAU)
	_plan_texture = ImageTexture.create_from_image(_plan_image)
	_plan_vue = Control.new()
	_plan_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plan_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan_vue.visible = false
	_plan_vue.draw.connect(_dessiner_le_plan)
	interface().add_child(_plan_vue)

	# LA ROUE DES STATIONS, repliée. Elle ne s'ouvre que `R` tenue, au volant.
	_roue_vue = Control.new()
	_roue_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_roue_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roue_vue.set_script(load("res://ui/roue.gd"))
	_roue_vue.visible = false
	_roue_vue.stations = Sons.STATIONS
	interface().add_child(_roue_vue)

	# LE MENU DE TRICHE, replié. Il ne se montre qu'au code Konami.
	_triche_vue = Control.new()
	_triche_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_triche_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_triche_vue.set_script(load("res://ui/triche.gd"))
	_triche_vue.visible = false
	_triche_vue.codes = _codes_de_triche()
	interface().add_child(_triche_vue)

	# Les quatre morceaux les plus proches du départ, tout de suite ; les autres
	# suivent à un par image pendant le décompte. Bâtir les neuf d'un coup
	# bloquait le fil principal une seconde et demie dans le navigateur.
	_diffuser_la_ville(4)

	# Le temps de mise en place, toujours : dans le navigateur, une préparation
	# qui bloque le fil principal plusieurs secondes fait tomber le socket.
	print("[carnage] ville prête en %d ms — %d morceaux, %d fiches en cache" % [
		Time.get_ticks_msec() - chrono, _morceaux.size(), carte.fiches_en_cache()])

	# `--banc-feu=N` : allumer N foyers autour du départ. Un incendie ne se
	# commande pas au pilote automatique, et c'est ce qu'il faut photographier.
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--banc-feu="):
			_feux_de_banc = int(String(argument).substr(11))

	# `--banc-dedans` : entrer chez soi au coup d'envoi. Une planque s'achète
	# après plusieurs minutes de jeu et l'intérieur ne se voit qu'une fois
	# dedans : sans ce raccourci, il ne serait jamais photographié avant
	# livraison — c'est exactement le trou par lequel les huit appartements
	# sont restés invisibles pendant des semaines.
	if "--banc-dedans" in OS.get_cmdline_args():
		_planque = 0
		_pied = true
		_entrer_chez_soi(0)

	# `--banc-etoiles=N` : partir déjà recherché. Attendre qu'un pilote au hasard
	# gagne cinq étoiles pour voir l'hélicoptère, c'est attendre une manche sur
	# quatre — la police et l'hélicoptère se vérifient en trente secondes avec ça.
	if Commandes.pilote_automatique:
		for argument in OS.get_cmdline_args():
			if String(argument).begins_with("--banc-etoiles="):
				var niveau := int(String(argument).substr(15))
				if niveau > 0:
					ville.chaleur[Session.cle] = float(VilleVivante.PALIERS[
						min(niveau, VilleVivante.PALIERS.size()) - 1]) + 40.0
					ville._depuis_crime[Session.cle] = 0.0

## La carrosserie qu'on conduit : la Volvo au départ, puis ce qu'on a volé. On
## reconstruit le nœud plutôt que d'en garder dix cachés — une voiture volée
## par manche, ça se compte sur les doigts.
func _rebatir_ma_voiture() -> void:
	if _corps_auto != null:
		_corps_auto.queue_free()
	_corps_auto = _batir_voiture_de(_modele_vehicule, _ma_couleur(), Session.pseudo, _teinte)
	FormesCarnage.armer_la_voiture(_corps_auto, bool(_mods.get("mitrailleuse", false)))
	FormesCarnage.projecteurs(_corps_auto, 2.2)
	_corps_auto.add_child(FormesCarnage.echappement(-2.4 if _modele_vehicule < 0 else -2.2))
	monde().add_child(_corps_auto)

func _batir_voiture_de(modele: int, couleur: Color, pseudo: String,
		peinture: Color = Color.WHITE) -> Node3D:
	if modele < 0:
		# La voiture de départ : sa tôle est la couleur du joueur, sauf si le
		# garage l'a repeinte. ⚠ Le HALO garde la couleur du joueur dans les
		# deux cas — `voiture(peinture)` le repeignait aussi, et un halo violet
		# sous un joueur bleu, c'est un joueur qu'on ne retrouve plus.
		if peinture != Color.WHITE:
			return FormesCarnage.voiture_kit(0, peinture, couleur, pseudo, true)
		return FormesCarnage.voiture(couleur, pseudo)
	# Une voiture volée garde sa peinture ; c'est le halo qui dit à qui elle
	# est. Une voiture de gang volée, elle, garde les couleurs du gang — sauf
	# passage au garage, qui repeint tout.
	return FormesCarnage.voiture_kit(modele, peinture, couleur, pseudo, true)

## La couleur vient de la place à la TABLE, pas de la place dans la présence :
## celle-ci n'arrive qu'après le premier échange, et la voiture serait bleue
## pendant deux secondes chez tout le monde.
func _ma_couleur() -> Color:
	return Palette.couleur_joueur(_place)

## L'heure bleue, et rien d'autre : la ville elle-même arrive par morceaux,
## autour du joueur, dans `_diffuser_la_ville`. Les lieux (repaires, garages,
## cabines, arènes) vivent dans le morceau qui porte leur pâté.
func _planter_decor() -> void:
	# `--nuit=0.8` (ou `?nuit=0.8` dans l'adresse) : photographier la nuit sans
	# attendre que le village y passe.
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--nuit="):
			MatieresCarnage.nuit_forcee = clamp(float(String(argument).substr(7)), 0.0, 1.0)
	_ambiance = MatieresCarnage.ambiance()
	for noeud in _ambiance:
		monde().add_child(noeud)
	# LA MÉTÉO. `--meteo=pluie` (ou le code MÉTÉO) fige un temps ; sinon
	# c'est l'horloge universelle qui décide, la même pour tous.
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--meteo="):
			MeteoCarnage.meteo_forcee = MeteoCarnage.indice_du_temps(String(argument).substr(8))
	_meteo = MeteoCarnage.new()
	_meteo.name = "Meteo"
	_meteo.brancher_le_tonnerre(_tonnerre)
	monde().add_child(_meteo)
	# La voie ferrée est une droite de la ville : le shader du sol la trace en
	# espace monde, il lui faut ses paramètres.
	MatieresCarnage.sol().set_shader_parameter("rail", carte.rail())
	# Les voies libres : le shader du sol trace leurs chaussées en espace monde.
	MatieresCarnage.sol().set_shader_parameter("lignes", carte.lignes_libres())
	MatieresCarnage.sol().set_shader_parameter("origines", carte.origines_libres())
	MatieresCarnage.sol().set_shader_parameter("anneaux", carte.anneaux_libres())
	MatieresCarnage.sol().set_shader_parameter("etoiles", carte.etoiles_libres())

## Les morceaux dont le bord passe à portée du joueur sont bâtis, du plus proche
## au plus loin, une ÉTAPE de chantier par image ; ceux qui sont partis loin
## sont libérés. `entiers` > 0 : autant de morceaux bâtis d'un coup, pour le
## départ. Un morceau complet coûte quelques dizaines de millisecondes : en
## bâtir un d'un bloc en pleine course ferait une saccade au passage de chaque
## rue.
func _diffuser_la_ville(entiers: int = 0) -> void:
	# Un pâté sali par une casse se remaille : UN par image, tous morceaux
	# confondus, pour qu'une roquette ne coûte jamais plus qu'un maillage.
	if _chantier == null:
		for cle in _morceaux:
			if (_morceaux[cle] as MorceauVille).rafraichir():
				break
	if _chantier != null and entiers == 0:
		if _chantier.avancer():
			_chantier = null
		return
	var cote := PlanVille.MORCEAU * PlanVille.PAS
	var m0 := Vector2i(int(floor((_position.x - PORTEE_MORCEAU) / cote)), int(floor((_position.y - PORTEE_MORCEAU) / cote)))
	var m1 := Vector2i(int(floor((_position.x + PORTEE_MORCEAU) / cote)), int(floor((_position.y + PORTEE_MORCEAU) / cote)))
	var manquants: Array = []
	for my in range(m0.y, m1.y + 1):
		for mx in range(m0.x, m1.x + 1):
			var cle := Vector2i(mx, my)
			if _morceaux.has(cle):
				continue
			var rect := Rect2(Vector2(mx, my) * cote, Vector2(cote, cote))
			var plus_proche := Vector2(clamp(_position.x, rect.position.x, rect.end.x),
				clamp(_position.y, rect.position.y, rect.end.y))
			if plus_proche.distance_to(_position) <= PORTEE_MORCEAU:
				manquants.append([plus_proche.distance_squared_to(_position), cle])
	manquants.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for i in min(max(entiers, 1), manquants.size()):
		var cle: Vector2i = manquants[i][1]
		var morceau := MorceauVille.new()
		monde().add_child(morceau)
		_morceaux[cle] = morceau
		if entiers > 0:
			morceau.batir(carte, cle, ville.reveillees, ville.detruits)
		else:
			morceau.commencer(carte, cle, ville.reveillees, ville.detruits)
			_chantier = morceau
	# On ne libère qu'un morceau par image aussi : libérer neuf nœuds de mille
	# instances d'un coup se sent autant que les bâtir.
	for cle in _morceaux.keys():
		var rect := Rect2(Vector2(cle) * cote, Vector2(cote, cote))
		var plus_proche := Vector2(clamp(_position.x, rect.position.x, rect.end.x),
			clamp(_position.y, rect.position.y, rect.end.y))
		if plus_proche.distance_to(_position) > LIBERATION:
			if _morceaux[cle] == _chantier:
				_chantier = null
			(_morceaux[cle] as Node3D).queue_free()
			_morceaux.erase(cle)
			break

## Un lot de pâtés de la carte par image, puis les lieux secteur par secteur.
## Cent vingt pâtés, c'est trois mille pixels et autant de tests d'eau : une
## milliseconde native, quatre dans le navigateur. La carte est complète en
## deux secondes de jeu sans qu'on l'ait sentie.
const PATES_PAR_IMAGE := 120

func _peindre_le_plan() -> void:
	var total := PlanVille.pates_x() * PlanVille.pates_y()
	var secteurs := (PlanVille.COLONNES / PlanVille.SECTEUR) * (PlanVille.LIGNES / PlanVille.SECTEUR)
	if _plan_pate < total:
		for i in PATES_PAR_IMAGE:
			if _plan_pate >= total:
				break
			carte.peindre_pate(_plan_image, _plan_pate)
			_plan_pate += 1
		if _plan_pate >= total or _plan_pate % (PATES_PAR_IMAGE * 10) == 0:
			_plan_texture.update(_plan_image)
	elif _plan_secteur < secteurs:
		for i in 3:
			if _plan_secteur >= secteurs:
				break
			var par_ligne := PlanVille.COLONNES / PlanVille.SECTEUR
			carte.peindre_secteur(_plan_image, Vector2i(posmod(_plan_secteur, par_ligne), _plan_secteur / par_ligne))
			_plan_secteur += 1
		if _plan_secteur >= secteurs:
			_plan_texture.update(_plan_image)
	_plan_vue.visible = Commandes.carte()
	if _plan_vue.visible:
		_plan_vue.queue_redraw()

func _dessiner_le_plan() -> void:
	var taille := _plan_vue.size
	var hauteur: float = taille.y * 0.68
	var largeur: float = hauteur * float(PlanVille.COLONNES) / float(PlanVille.LIGNES)
	# Un peu au-dessus du milieu : la légende passe sous la carte sans mordre
	# sur la ligne d'état du bas.
	var cadre := Rect2((taille - Vector2(largeur, hauteur)) * 0.5 - Vector2(0.0, taille.y * 0.05), Vector2(largeur, hauteur))
	_plan_vue.draw_rect(cadre.grow(6.0), Color(Palette.FOND, 0.9), true)
	_plan_vue.draw_texture_rect(_plan_texture, cadre, false)
	_plan_vue.draw_rect(cadre.grow(6.0), Palette.FILET, false, 1.0)
	var echelle := Vector2(largeur, hauteur) / carte.etendue()
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		_plan_vue.draw_circle(cadre.position + Vector2(a["p"]) * echelle, 5.0,
			Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))))
	var moi := cadre.position + _position * echelle
	var avant := Vector2.RIGHT.rotated(_angle)
	var cote := Vector2(-avant.y, avant.x)
	_plan_vue.draw_colored_polygon(PackedVector2Array([moi + avant * 10.0, moi - avant * 6.0 + cote * 6.0,
		moi - avant * 6.0 - cote * 6.0]), _ma_couleur())
	_plan_vue.draw_arc(moi, 14.0, 0, TAU, 24, _ma_couleur(), 2.0)
	# La légende, dans la police de la charte (la police de secours ne se
	# dessinait plus une fois le post-traitement posé dans la même couche).
	var police: Font = UI.TEXTE_POLICE
	var x := cadre.position.x
	var y := cadre.end.y + 24.0
	for entree in [["garage", Palette.SERIE], ["cabine", Palette.AVERTISSEMENT], ["arène", Palette.CRITIQUE],
			["planque", Color("#b070d0")], ["hôpital", Color("#f0f4f8")],
			["repaire", Palette.ENCRE], ["parc", Color("#50a050")], ["eau", Color("#3a6a9c")], ["voie ferrée", Color("#404040")],
			["boulevard", Color("#8a8a90")]]:
		_plan_vue.draw_rect(Rect2(Vector2(x - 4.0, y - 9.0), Vector2(8, 8)), entree[1], true)
		_plan_vue.draw_string(police, Vector2(x + 9.0, y), String(entree[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_DOUCE)
		x += 12.0 + police.get_string_size(String(entree[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0
	_dessiner_la_boutique(cadre, y + 22.0, police)

## LA BOUTIQUE DES PLANQUES, sous la carte, tant qu'on n'en a pas.
##
## L'appartement se déduit du QUARTIER : le joueur ne se demande pas « qu'est-ce
## qu'on trouve ici », il se demande « où vais-je pour avoir le penthouse ».
## Sans ce tableau on achetait la première planque croisée, sans savoir qu'une
## autre rue donnait mieux — et les huit noms du catalogue ne servaient à rien.
##
## ⚠ Il DISPARAÎT une fois qu'on a sa planque : à ce moment-là c'est du bruit
## sur une carte qu'on ouvre pour se repérer, pas pour faire des courses.
func _dessiner_la_boutique(cadre: Rect2, haut: float, police: Font) -> void:
	if _planque >= 0:
		return
	_plan_vue.draw_string(police, Vector2(cadre.position.x, haut),
		"OÙ LOGER — le quartier décide de l'appartement", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 11, Palette.ENCRE_FAIBLE)
	var table := Interieurs.logements()
	var colonne := cadre.size.x * 0.5
	for i in table.size():
		var f: Dictionary = table[i]
		var quartier := String(PlanVille.NOMS_QUARTIERS[int(f["quartier"])])
		_plan_vue.draw_string(police,
			Vector2(cadre.position.x + float(i % 2) * colonne, haut + 16.0 + float(i / 2) * 14.0),
			"%s — %s" % [String(f["nom"]), quartier],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_DOUCE)

## Un IMPACT sur une façade. ⚠ Plus rien ne part du décor depuis la v12 : le
## morceau rend seulement la couleur et le point touchés, et on en tire les
## éclats, la poussière et le choc. Le mur, lui, tient.
func _casser_dans_le_decor(id: int, locale: int) -> void:
	var tuile := MorceauVille.tuile_d_immeuble(id)
	var cle_morceau := Vector2i(tuile.x / PlanVille.MORCEAU, tuile.y / PlanVille.MORCEAU)
	if not _morceaux.has(cle_morceau):
		return
	var morceau: MorceauVille = _morceaux[cle_morceau]
	var parti := morceau.casser(id, locale)
	if parti.is_empty():
		return
	if (parti["p"] as Vector3).distance_to(Decor.vers3d(_position)) > 120.0:
		return
	var couleur: Color = parti["c"]
	for i in 5:
		var debris := FormesCarnage.cubes([[Vector3.ZERO, float(parti["taille"]) * _rng.randf_range(0.2, 0.45), Color(couleur.r, couleur.g, couleur.b, 1.0)]])
		debris.position = parti["p"]
		monde().add_child(debris)
		var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.6), _rng.randf_range(-1, 1)) * _rng.randf_range(5, 11)
		_eclats.append({"noeud": debris, "v": v, "t": 1.4, "t0": 1.4,
			"tourne": Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))})
	var poussiere := FormesCarnage.poussiere(couleur)
	poussiere.position = parti["p"]
	monde().add_child(poussiere)
	_eclats.append({"noeud": poussiere, "v": Vector3.ZERO, "t": 1.2, "t0": 1.2, "lumiere": true})
	Sons.jouer("choc", _rng.randf_range(0.6, 0.9), -14.0)

## Une voiture dormante s'est réveillée : on l'efface de la nappe du morceau
## qui la porte. Le nœud ordinaire de `_placer_les_autos` prend le relais.
func _effacer_la_dormante(id: int) -> void:
	if _cachees.has(id):
		return
	_cachees[id] = true
	for cle in _morceaux:
		(_morceaux[cle] as MorceauVille).cacher_voiture(id)

# ------------------------------------------------------- simulation locale

func simuler_local(delta: float) -> void:
	if Commandes.pilote_automatique:
		_piloter_pour_le_banc()

	# ⚠ LE CODE KONAMI SE LIT EN PREMIER, et le menu attrape les touches avant
	# tout le reste : ouvert, il rend la main tout de suite. La manche, elle,
	# continue de tourner derrière — c'est du multijoueur, on ne met pas trois
	# autres joueurs en pause pour lire un menu.
	if Commandes.konami(delta):
		_basculer_la_triche()
	# ⚠ ÉCHAP A UNE PRÉCÉDENCE, et elle ne se devine pas : il FERME d'abord ce
	# qui est ouvert (la triche, la boutique) et n'ouvre la pause que s'il n'y
	# avait rien. Sans cet ordre, ÉCHAP devant la caisse d'une supérette
	# proposait de quitter la ville.
	if _front_de_pause(KEY_ESCAPE):
		if _triche_ouverte:
			_basculer_la_triche()
		elif _superette_ouverte:
			_basculer_la_superette()
		else:
			_basculer_la_pause()
	if _pause_ouverte:
		_naviguer_dans_la_pause()
	# ⚠ On NE SORT PAS de la boucle : la ville continue de vivre derrière le
	# menu (c'est du multijoueur, et un monde figé qui reprend d'un coup à la
	# fermeture saute de trois rues). Le joueur, lui, ne bouge plus : c'est
	# `Commandes.saisie` qui ferme ses touches, comme pour le tchat du village.
	if _triche_ouverte:
		_naviguer_dans_la_triche()
	# LA SUPÉRETTE, même règle : la ville tourne derrière, le joueur est figé.
	if _superette_ouverte:
		_naviguer_dans_la_superette()

	_depuis_portiere = max(0.0, _depuis_portiere - delta)
	# ⚠ Le délai se teste AVANT de lire la touche : `action_declenchee` consomme
	# le front. Interrogée pendant le délai, elle avalait l'appui de celui qui
	# venait de descendre et il restait planté à côté de sa portière.
	if _depuis_portiere <= 0.0 and _hors_service <= 0.0 and Commandes.action_declenchee():
		_basculer_portiere()

	# ⚠ Dedans, on SORT de la boucle : ni tir, ni portière, ni police, ni
	# heurts. Laisser tourner le reste voulait dire prendre une balle à travers
	# un mur qui n'existe pas dans la simulation extérieure, et le joueur ne
	# voyait même pas d'où elle venait. Chez soi, on est chez soi.
	if _dedans != "":
		_marcher_dedans(delta)
		_affaires_dedans()
		return

	if _train >= 0:
		# ⚠ NI MARCHE NI TIR EN VOYAGE. Un passager qui tire depuis une rame
		# lancée viderait un quartier sans jamais être touché ; et la marche
		# le ferait descendre du train sans ouvrir la portière.
		_voyager(delta)
	elif _pied:
		_marcher(delta)
		_tirer(delta)
	else:
		_conduire(delta)
		_klaxonner(delta)
		_tirer(delta)
	_surveiller_les_lieux(delta)

	if _eperon > 0.0:
		_eperon -= delta

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["p"] = (a["p"] as Vector2).lerp(a["cible"], clamp(delta * 14.0, 0, 1))
		a["a"] = lerp_angle(float(a["a"]), float(a["angle_cible"]), clamp(delta * 14.0, 0, 1))

	_depuis_envoi += delta
	if _depuis_envoi >= CADENCE_JOUEUR:
		_depuis_envoi = 0.0
		canal.envoyer("j", {
			"x": int(_position.x), "y": int(_position.y),
			"a": snapped(_angle, 0.01), "s": int(_vitesse), "h": int(_vie),
			"e": 2 if _hors_service > 0.0 else (0 if _pied else 1),
			"w": _vehicule, "vg": _genre_vehicule, "vm": _modele_vehicule,
			"ep": 1 if _eperon > 0.0 else 0,
			"tr": 1 if _train >= 0 else 0,
			"mg": 1 if bool(_mods.get("mitrailleuse", false)) else 0,
			"tc": 0 if _teinte == Color.WHITE else _teinte.to_rgba32(),
		})

	if not est_hote():
		# Les objets de l'hôte ne se déplacent pas d'un bond toutes les huit
		# images : on glisse vers la dernière position connue.
		for objet in ville.gens:
			objet["p"] = (objet["p"] as Vector2).lerp(objet.get("cible", objet["p"]), clamp(delta * 11.0, 0, 1))
		for auto in ville.autos:
			auto["p"] = (auto["p"] as Vector2).lerp(auto.get("cible_p", auto["p"]), clamp(delta * 11.0, 0, 1))

	_avancer_projectiles(delta)
	_ramasser_caisses()
	_ramasser_les_a_cotes()
	_compter_les_frolements()

## Pilote automatique du banc d'essai. Il ne joue pas bien, il joue TOUT :
## sans une sortie de véhicule programmée, la moitié du jeu — la marche, le
## vol de voiture, le tir à pied — ne serait jamais exercée avant livraison.
var _depuis_rapport := 0.0

func _piloter_pour_le_banc() -> void:
	# Toutes les cinq secondes, le pilote dit à quelle cadence il tourne et ce
	# qu'il voit : dans le navigateur, c'est la seule mesure de performance
	# qu'on ait — et c'est celle qui compte.
	_depuis_rapport += get_process_delta_time()
	if _depuis_rapport >= 5.0:
		_depuis_rapport = 0.0
		var cubes := 0
		for cle in _morceaux:
			cubes += (_morceaux[cle] as MorceauVille).cubes_poses()
		print("[banc] $%d sur soi, $%d au coffre, planque %d" % [_argent, _banque, _planque])
		var secours := 0
		for a in ville.autos:
			if int(a["genre"]) in [VilleVivante.POMPIER, VilleVivante.AMBULANCE]:
				secours += 1
		# LE TRAIN dans la ligne de diagnostic : la distance de la rame la plus
		# proche. C'est la seule façon de savoir, en relisant un journal de
		# banc, si le train a vraiment circulé pendant la manche ou s'il est
		# resté à l'autre bout de la ligne — une rame invisible et une rame
		# absente rendent exactement la même photo.
		var train_le_plus_proche := -1
		for t in ville.trains:
			var d := int(ville.point_de_voie(float(t["s"])).distance_to(_position))
			if train_le_plus_proche < 0 or d < train_le_plus_proche:
				train_le_plus_proche = d
		print("[banc] faim %d · soif %d · %d provision(s) en poche, %d au frigo"
			% [int(_faim), int(_soif), Provisions.compte(_provisions), Provisions.compte(_frigo)])
		print("[banc] t=%ds fps=%d gens=%d autos=%d feux=%d secours=%d morceaux=%d cubes=%d quads=%d maillage_max=%.1fms fiches=%d noeuds=%d trains=%d/%dpx %s meteo=%s(pluie %.2f nuages %.2f brume %.2f)" % [int(temps),
			Engine.get_frames_per_second(), ville.gens.size(), ville.autos.size(), ville.feux.size(), secours,
			_morceaux.size(), cubes, MorceauVille.quads_total, MorceauVille.maillage_max_ms,
			carte.fiches_en_cache(), get_tree().get_node_count(),
			ville.trains.size(), train_le_plus_proche, "hôte" if est_hote() else "client",
			MeteoCarnage.nom_du_temps(_meteo.temps_courant()) if _meteo != null else "-",
			_meteo.pluie if _meteo != null else 0.0, _meteo.nuages if _meteo != null else 0.0,
			_meteo.brume if _meteo != null else 0.0])
	# ⚠ L'action se PULSE. Maintenue, elle ne produit qu'un seul front : le
	# pilote descendait de voiture et ne remontait jamais, et la moitié du jeu
	# passait le banc sans être exercée.
	_pulsation = not _pulsation
	Commandes.action_simulee = false
	# ⚠ LE PILOTE RENTRE PAR LA VRAIE PORTE. Le banc s'arrêtait sur le chrono
	# de `duree_forcee` — donc `Partie._process` appelait `terminer()` tout
	# seul, et la sortie du joueur (le menu de pause, la demande à l'hôte, le
	# retour au salon) n'était JAMAIS exercée par une manche. Elle l'est
	# maintenant à neuf dixièmes du temps ; le chrono reste le filet si le
	# menu se coince.
	if not _rentre_de_banc and temps > duree_reelle() * 0.9:
		_rentre_de_banc = true
		print("[banc] quitte la ville par le menu de pause")
		_quitter_la_ville()
		return
	if not _sortie_de_banc and not _pied and temps > duree_reelle() * 0.4:
		_sortie_de_banc = true
		Commandes.action_simulee = true
		Commandes.direction_simulee = Vector2.ZERO
		return

	if _pied:
		var auto := ville.vehicule_proche(_position, 1400.0)
		if auto.is_empty():
			Commandes.direction_simulee = Vector2.RIGHT.rotated(temps)
			Commandes.tir_simule = true
			return
		var vers: Vector2 = Vector2(auto["p"]) - _position
		if vers.length() <= PORTEE_ENTREE:
			Commandes.action_simulee = _pulsation
			Commandes.direction_simulee = Vector2.ZERO
		else:
			Commandes.direction_simulee = vers.normalized()
		Commandes.tir_simule = true
		return

	Commandes.direction_simulee = _viser(_but_du_banc())
	Commandes.tir_simule = true
	Commandes.klaxon_simule = fmod(temps, 9.0) < 0.3
	# Le pilote traite ses affaires : devant une planque ou un hôpital, il
	# appuie sur F. Sans ça, l'achat, le dépôt et le soin ne seraient jamais
	# exercés avant livraison.
	Commandes.affaire_simulee = _affaire != "" and _pulsation
	# Le pilote MANGE quand il a faim : sans ça, la touche, le choix de
	# l'article et la consommation ne seraient jamais exercés par une manche —
	# et c'est précisément le genre de code qui casse en silence.
	Commandes.manger_simulee = (_faim < 70.0 or _soif < 70.0) and _pulsation
	# La carte pendant trois secondes : c'est ainsi qu'on la photographie.
	Commandes.carte_simulee = temps > 8.0 and temps < 11.0

## Ce que vise le pilote du banc. Tant qu'il n'a pas de contrat, il va
## décrocher : sans ce détour, une cabine sur vingt-six par vingt tuiles n'est
## jamais croisée par hasard, et toute la chaîne des contrats — proposition,
## avancement, prime, respect — passe la livraison sans avoir tourné une fois.
func _but_du_banc() -> Vector2:
	if _contrat.is_empty():
		var proche := Vector2.INF
		var ecart := INF
		for c in carte.lieux_autour(_position, PlanVille.SECTEUR * PlanVille.PAS * 1.5)["cabines"]:
			var d: float = _position.distance_squared_to(c["p"])
			if d < ecart:
				ecart = d
				proche = c["p"]
		if proche != Vector2.INF:
			return proche
	var cible := Vector2.INF
	var distance := INF
	for personne in ville.gens:
		var d2: float = _position.distance_squared_to(personne["p"])
		if d2 < distance:
			distance = d2
			cible = personne["p"]
	return cible if cible != Vector2.INF else carte.centre()

func _viser(cible: Vector2) -> Vector2:
	var ecart := wrapf((cible - _position).angle() - _angle, -PI, PI)
	return Vector2(clamp(ecart * 2.0, -1.0, 1.0), 1.0)

# ------------------------------------------------------- portières

## Monter, descendre. C'est le geste qui sépare un jeu de voiture d'un GTA :
## tant qu'on ne peut pas sortir, la ville n'est qu'un circuit.
func _basculer_portiere() -> void:
	_depuis_portiere = DELAI_PORTIERE
	# LE TRAIN PASSE AVANT LA PORTIÈRE. Un quai est presque toujours au bord
	# d'une rue : testée après, la voiture garée à dix mètres gagnait à tous
	# les coups et l'on ne montait jamais dans le train.
	if _train >= 0:
		_descendre_du_train()
		return
	if _pied and _monter_dans_le_train():
		return
	if _pied:
		var auto := ville.vehicule_proche(_position, PORTEE_ENTREE)
		if auto.is_empty():
			return
		var id := int(auto["id"])
		if est_hote():
			ville.accorder_vehicule(Session.cle, id, _position)
			_vider_les_evenements()
		else:
			# L'hôte tranche : deux joueurs arrivés à cent millisecondes
			# d'intervalle ne repartent pas avec la même berline.
			canal.envoyer("monte", {"id": id, "x": int(_position.x), "y": int(_position.y)})
		return

	# ⚠ ON NE DÉBARQUE PAS AU MILIEU DU BASSIN. Sauter d'un bateau à cent
	# mètres du quai serait une noyade, et le jeu n'a pas de noyade : on
	# resterait à marcher sur l'eau. Tant qu'il n'y a pas de terre à portée,
	# la portière ne s'ouvre pas — et la ligne du HUD le dit.
	if FormesCarnage.est_bateau(_modele_vehicule) \
			and not carte.terre_proche(_position, PORTEE_QUAI):
		_dire_affaire("accostez d'abord")
		return

	# On descend : la voiture retourne au monde, là où on l'a laissée.
	if Commandes.pilote_automatique:
		print("[banc] descend du véhicule %d" % _vehicule)
	var descente := _position + Vector2.UP.rotated(_angle) * 46.0
	descente = carte.degager(descente, RAYON_A_PIED)[0]
	var id_rendu := _vehicule
	var pv := _pv_vehicule
	_pied = true
	_vitesse = 0.0
	_vehicule = 0
	Tactile.mode = Tactile.MARCHE
	Sons.arreter_moteur()
	Sons.jouer("portiere_ferme", 1.0, -11.0)
	var angle_rendu := _angle
	var modele_rendu := _modele_vehicule
	var genre_rendu := _genre_vehicule
	var teinte_rendue := 0 if _teinte == Color.WHITE else _teinte.to_rgba32()
	# LA VOITURE DE DÉPART GARDE LA COULEUR DU JOUEUR. Sa tôle n'a pas de
	# peinture propre : c'est `_ma_couleur()` qui la peint. Rendue sans teinte,
	# elle retombait sur la couleur tirée de son identifiant — grise — et le
	# joueur remontait dans une voiture qui n'était plus la sienne.
	if teinte_rendue == 0 and _modele_vehicule < 0:
		teinte_rendue = _ma_couleur().to_rgba32()
	canal.envoyer("sort", {"id": id_rendu, "x": int(_position.x), "y": int(_position.y),
		"a": snapped(angle_rendu, 0.01), "pv": int(pv), "g": genre_rendu, "m": modele_rendu,
		"t": teinte_rendue})
	if est_hote():
		ville.rendre_vehicule(Session.cle, id_rendu, _position, angle_rendu, pv, modele_rendu,
			genre_rendu, teinte_rendue)
		_vider_les_evenements()
	# La peinture reste sur la carrosserie, pas sur le joueur.
	_teinte = Color.WHITE
	# LA BOMBE part avec la voiture qu'on laisse : c'est le seul moment où elle
	# s'arme, et c'est ce qui en fait un piège et pas une arme.
	if bool(_mods.get("bombe", false)):
		canal.envoyer("bombe", {"id": id_rendu})
		if est_hote():
			ville.armer_bombe(Session.cle, id_rendu)
			_vider_les_evenements()
		_dire_affaire("bombe amorcée — éloignez-vous")
	# Le reste du matériel reste avec la carrosserie : on descend les mains
	# vides, comme on est monté.
	_mods = {}
	_eteindre_la_radio()
	# Et la course s'arrête avec le taxi : le client ne suit pas à pied.
	if not _course.is_empty():
		_course = {}
		_cible_contrat = {}
		_dire_affaire("course abandonnée")
	_position = descente
	_modele_vehicule = -1

## Livrer sa voiture à la casse. On en descend d'abord — mais SANS la rendre à
## la ville : `_basculer_portiere` la remet en circulation, et une voiture
## rendue puis broyée réapparaissait une seconde plus tard chez les autres
## joueurs, garée sur la dalle, intouchable.
func _broyer_ma_voiture() -> void:
	var id := _vehicule
	var ou := _position
	canal.envoyer("broyer", {"id": id, "x": int(ou.x), "y": int(ou.y)})
	if est_hote():
		ville.broyer(Session.cle, id, ou)
		_vider_les_evenements()
	# À pied, à côté de la fosse. Les modifications payées partent avec la
	# carrosserie, comme quand on descend : on ne récupère pas sa mitrailleuse
	# en revendant le camion qui la porte.
	_pied = true
	_vitesse = 0.0
	_vehicule = 0
	_modele_vehicule = -1
	_mods = {}
	Tactile.mode = Tactile.MARCHE
	Sons.arreter_moteur()
	_eteindre_la_radio()
	if not _course.is_empty():
		_course = {}
		_cible_contrat = {}
	_position = carte.degager(ou + Vector2.RIGHT.rotated(ville.cap_de_voie()) \
		* (VilleVivante.RAYON_CASSE + 30.0), RAYON_A_PIED)[0]

func _prendre_le_volant(id: int, genre: int, position: Vector2, angle: float, pv: float,
		modele: int = -1) -> void:
	if PlanVille.est_dormante(id):
		ville.reveillees[id] = true
		_effacer_la_dormante(id)
	_modele_vehicule = modele
	# ⚠ AVANT `_rebatir_ma_voiture`, qui montre ou cache la mitrailleuse selon
	# `_mods` : réglé après, on remontait dans une voiture de gang désarmée à
	# l'écran et armée dans les faits.
	#
	# UNE VOITURE DE GANG VIENT AVEC SON ARME (§1.3). C'est ce qui en fait une
	# prise et pas une berline de couleur : neuf cent cinquante dollars
	# d'atelier, gratuits, en échange du respect qu'on perd à la voler (voir
	# `VilleVivante.accorder_vehicule`). Elle repart avec la carrosserie quand
	# on descend, comme tout le reste du matériel.
	if genre == VilleVivante.VOITURE_GANG:
		_mods["mitrailleuse"] = true
	_rebatir_ma_voiture()
	# Le banc raconte ce qu'il fait : sans cette ligne, un pilote qui ne
	# remonterait jamais en voiture rendrait exactement le même journal qu'un
	# pilote qui joue toute la manche au volant.
	if Commandes.pilote_automatique:
		print("[banc] prend le volant du véhicule %d" % id)
	_pied = false
	_allumer_la_radio(modele)
	_vehicule = id
	_genre_vehicule = genre
	_pv_vehicule = pv
	_position = position
	_angle = angle
	_vitesse = 0.0
	_depuis_portiere = DELAI_PORTIERE
	Tactile.mode = Tactile.CONDUITE
	Sons.demarrer_moteur(_type_moteur())
	Sons.jouer("portiere_ouvre", 1.0, -10.0)
	Sons.jouer("demarreur", _rng.randf_range(0.94, 1.08), -13.0)

## Le grain de moteur du véhicule qu'on pilote.
func _type_moteur() -> String:
	return String(MOTEURS_VEHICULE.get(_modele_vehicule, "standard"))

# ------------------------------------------------------- déplacement

func _marcher(delta: float) -> void:
	if _hors_service > 0.0:
		_hors_service -= delta
		if _hors_service <= 0.0:
			_relever()
		return
	_regenerer(delta)
	if _sonne > 0.0:
		_sonne -= delta
		return

	var commande := Commandes.direction()
	if commande.length() > 0.1:
		# À pied, la direction du regard suit la marche : on tire là où on va,
		# ce qui évite un second axe de visée sur un jeu qui se joue à quatre
		# touches.
		_angle = commande.angle()
		_vitesse = VITESSE_A_PIED
		# Un pas toutes les 0,34 s. À pied, c'est le seul retour qui dit qu'on
		# avance : la ville défile trop lentement pour le montrer.
		_depuis_pas -= delta
		if _depuis_pas <= 0.0:
			_depuis_pas = 0.34
			Sons.jouer(_pas_du_sol(), _rng.randf_range(0.94, 1.08), -20.0)
		var suivant := _position + commande.normalized() * VITESSE_A_PIED * delta
		_position = carte.degager(suivant, RAYON_A_PIED)[0]
		# À pied non plus, on ne traverse pas une voiture garée : on la contourne.
		for p: Vector2 in _voitures_autour(60.0):
			var vers := _position - p
			var minimum := RAYON_A_PIED + 22.0
			if vers.length() < minimum and vers.length() > 0.01:
				_position = p + vers.normalized() * minimum
	else:
		_vitesse = 0.0
		_depuis_pas = 0.0
	_surveiller_la_friche(delta)

## Le sol sous les pieds, dit par le quartier plutôt que par la tuile : c'est
## l'information que le joueur entend vraiment — on marche dans l'herbe au
## parc, sur des planches au port, sur de la ferraille à l'usine. Lire la
## tuile exacte donnerait un pas qui change trois fois par seconde en
## traversant un passage clouté.
func _pas_du_sol() -> String:
	match carte.quartier(_position):
		8, 9:                     # parc, plan d'eau
			return "pas_herbe"
		7:                        # le port : les pontons
			return "pas_bois"
		6:                        # zone industrielle : caillebotis et ferraille
			return "pas_metal"
		_:
			return "pas_beton"

## L'AMBIANCE DU QUARTIER : une boucle par secteur, dont le volume ne bouge
## pas — c'est un fond, pas un événement. Elle se tait en voiture : l'habitacle
## a l'autoradio, et empiler les deux ne fait qu'une soupe.
##
## Dix quartiers, dix fonds. C'est le seul endroit du jeu où l'on entend qu'on
## a changé de secteur sans regarder le radar.
const FONDS_QUARTIER := ["lieu_horloge", "lieu_transfo", "lieu_radiocassette",
	"lieu_eglise", "lieu_hiphop", "lieu_country", "lieu_usine", "lieu_bar",
	"grillon", "riviere"]

func _sentir_le_quartier() -> void:
	if not _pied or _train >= 0 or _dedans != "":
		Sons.lieu("")
		return
	var q := carte.quartier(_position)
	if q < 0 or q >= FONDS_QUARTIER.size():
		Sons.lieu("")
		return
	Sons.lieu(String(FONDS_QUARTIER[q]), -24.0)

func _conduire(delta: float) -> void:
	if _hors_service > 0.0:
		_hors_service -= delta
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta)
		_position += Vector2.RIGHT.rotated(_angle) * _vitesse * delta
		if _hors_service <= 0.0:
			_relever()
		return

	_regenerer(delta)

	if _sonne > 0.0:
		_sonne -= delta
		_angle += delta * 4.0
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta * 0.5)
	else:
		var commande := Commandes.conduite()
		var fiche: Dictionary = CARACTERES.get(_modele_vehicule, CARACTERES[-1])
		if commande.y > 0.1:
			_vitesse = min(_vitesse + ACCELERATION * float(fiche["a"]) * delta, VITESSE_MAX * float(fiche["v"]))
		elif commande.y < -0.1:
			_vitesse = max(_vitesse - FREIN * delta, VITESSE_ARRIERE)
		else:
			_vitesse = move_toward(_vitesse, 0.0, FROTTEMENT * abs(_vitesse) * delta + 40.0 * delta)

		# Le braquage atteint son plein dès 165 px/s — avant, la voiture ne
		# tournait qu'à pleine vitesse, ce qui la rendait inconduisible dans
		# des rues de cent quarante pixels. Il se resserre ensuite un peu à
		# haute vitesse, ce qui donne le poids sans enlever le contrôle.
		var prise: float = clamp(abs(_vitesse) / PRISE_PLEINE, 0.0, 1.0) * signf(_vitesse)
		var tenue: float = lerp(1.0, 0.62, clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))
		# Une moto tourne court et ne dérive presque pas : c'est tout son
		# intérêt dans des rues de deux tuiles.
		var vif := 1.45 if FormesCarnage.est_moto(_modele_vehicule) else 1.0
		_angle += commande.x * BRAQUAGE * vif * delta * prise * tenue

	var cap := Vector2.RIGHT.rotated(_angle)
	if abs(_vitesse) < 40.0:
		_glisse = cap
	else:
		var adherence: float = lerp(ADHERENCE_LENTE, ADHERENCE_RAPIDE, clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))
		if FormesCarnage.est_moto(_modele_vehicule):
			adherence *= 1.8
		# SOUS LA PLUIE, ÇA GLISSE : dix-huit pour cent d'adhérence en moins à
		# pleine averse. Assez pour rater un virage qu'on prenait les yeux
		# fermés, pas assez pour que la voiture parte seule — l'huile de
		# l'atelier reste le vrai piège.
		if _meteo != null:
			adherence *= 1.0 - 0.18 * _meteo.pluie
		_glisse = _glisse.slerp(cap, clamp(delta * adherence, 0.0, 1.0)).normalized()
	_position += _glisse * _vitesse * delta
	_crisser(delta, cap)
	_marquer_le_bitume(delta)
	_heurter_les_murs()
	_heurter_les_voitures()
	_surveiller_la_friche(delta)
	Sons.regime(clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))

## Le klaxon fait fuir les passants — c'est son seul effet, et c'est déjà
## beaucoup : c'est le moyen de traverser une foule sans l'écraser, ou de la
## rabattre vers un coéquipier.
## Les traces de pneus : quand on freine fort ou qu'on braque à pleine vitesse,
## chaque roue arrière laisse un rectangle sombre sur le bitume. Elles vieillissent
## toutes d'un cran à chaque nouvelle : au bout de l'anneau, la plus vieille
## s'efface.
func _marquer_le_bitume(delta: float) -> void:
	_depuis_trace -= delta
	if _traces == null or _depuis_trace > 0.0 or abs(_vitesse) < 200.0:
		return
	var commande := Commandes.conduite()
	var derape: bool = (commande.y < -0.1 and _vitesse > 260.0) or (abs(commande.x) > 0.6 and abs(_vitesse) > 420.0) or _sonne > 0.0
	if not derape or not carte.sur_une_rue(_position, 20.0):
		return
	_depuis_trace = 0.04
	var direction := Vector2.RIGHT.rotated(_angle)
	var cote := Vector2(-direction.y, direction.x)
	for signe in [-1.0, 1.0]:
		var roue: Vector2 = _position - direction * 16.0 + cote * signe * 12.0
		var ou := Decor.vers3d(roue, 0.02)
		var base := Basis(Vector3.UP, -_angle).scaled(Vector3(abs(_vitesse) * 0.045 * Decor.ECHELLE + 0.3, 1.0, 0.55))
		_traces.set_instance_transform(_trace_suivante, Transform3D(base, ou))
		_traces.set_instance_color(_trace_suivante, Color(0, 0, 0, 0.85))
		_trace_suivante = (_trace_suivante + 1) % TRACES_MAX
	# Les autres pâlissent : une trace a une demi-vie d'une centaine de coups.
	if _trace_suivante % 8 == 0:
		for i in TRACES_MAX:
			var c := _traces.get_instance_color(i)
			if c.a > 0.0:
				_traces.set_instance_color(i, Color(0, 0, 0, maxf(0.0, c.a - 0.02)))

## Le crissement : il ne se déclenche pas sur la vitesse mais sur l'ÉCART
## entre le cap de la voiture et sa trajectoire réelle. C'est ce qui fait
## qu'un virage négocié reste muet et qu'un tête-à-queue s'entend.
func _crisser(delta: float, cap: Vector2) -> void:
	_depuis_derapage -= delta
	if _depuis_derapage > 0.0 or abs(_vitesse) < 260.0:
		return
	var ecart: float = abs(_glisse.angle_to(cap))
	if ecart < 0.22:
		return
	_depuis_derapage = 0.55
	Sons.jouer("derapage", _rng.randf_range(0.92, 1.1),
		-22.0 + min(10.0, ecart * 22.0))

func _klaxonner(delta: float) -> void:
	_depuis_klaxon -= delta
	if _hors_service > 0.0 or not Commandes.klaxon() or _depuis_klaxon > 0.0:
		return
	_depuis_klaxon = KLAXON_DELAI
	Sons.jouer("klaxon", _rng.randf_range(0.96, 1.04), -9.0)
	# Klaxonner dans une rue pleine, ça se fait répondre.
	if _rng.randf() < 0.4:
		Sons.voix("voix_attention", -13.0)
	canal.envoyer("klx", {"x": int(_position.x), "y": int(_position.y)})
	if est_hote():
		ville.paniquer(_position, 280.0, 1.8)

## Un mur ne stoppe pas : il fait GLISSER. On ne perd que la part de vitesse
## qu'on a mise dedans, et la voiture se réaligne sur la façade quand on la
## frôle. Avant, le moindre angle de trottoir coupait les deux tiers de la
## vitesse et clouait la voiture — dans une ville, c'est toutes les trois
## secondes.
## ⚠ POUR UN BATEAU, C'EST LA TERRE QUI ARRÊTE. La même fonction ne peut pas
## servir aux deux : une coque est bloquée par exactement ce qui porte une
## carrosserie. `PlanVille.degager_bateau` est le miroir de `degager`.
func _degager_vehicule(point: Vector2, rayon: float) -> Array:
	if FormesCarnage.est_bateau(_modele_vehicule):
		return carte.degager_bateau(point, rayon)
	return carte.degager(point, rayon)

func _heurter_les_murs() -> void:
	var direction0 := Vector2.RIGHT.rotated(_angle)
	var correction := Vector2.ZERO
	var touche := false
	var moto := FormesCarnage.est_moto(_modele_vehicule)
	var rayon_c := RAYON_CAPSULE * (0.6 if moto else 1.0)
	var empattement := DEMI_EMPATTEMENT * (0.7 if moto else 1.0)
	for signe in [1.0, -1.0]:
		var bout: Vector2 = _position + direction0 * empattement * signe
		var resultat := _degager_vehicule(bout, rayon_c)
		if bool(resultat[1]):
			var c: Vector2 = (resultat[0] as Vector2) - bout
			_position += c
			correction += c
			touche = true
	if not touche:
		return
	var normale := correction.normalized()
	if normale == Vector2.ZERO:
		return
	var direction := Vector2.RIGHT.rotated(_angle)
	var frontal: float = abs(direction.dot(normale))

	if frontal > 0.62 and abs(_vitesse) > 330.0:
		# Le choc a trois forces : de la tôle froissée au mur pris à pleine
		# vitesse. Un seul bruit de collision, et un accrochage sonne comme
		# une sortie de route.
		Sons.jouer("choc_dur" if abs(_vitesse) > 620.0 else "choc_moyen",
			_rng.randf_range(0.94, 1.06), -8.0)
		_secousse = max(_secousse, 0.28)
		# Une façade prise de face à cette vitesse perd des cubes : l'hôte
		# tranche lesquels, comme pour les balles.
		var impact := _position + direction * RAYON_VOITURE
		var gerbe := FormesCarnage.etincelles()
		gerbe.position = Decor.vers3d(impact, 1.0)
		monde().add_child(gerbe)
		_eclats.append({"noeud": gerbe, "v": Vector3.ZERO, "t": 0.8, "t0": 0.8, "lumiere": true})
		if est_hote():
			ville.choquer(impact, direction, abs(_vitesse))
			_vider_les_evenements()
		else:
			canal.envoyer("choc", {"x": int(impact.x), "y": int(impact.y), "a": snapped(direction.angle(), 0.01), "v": int(abs(_vitesse))})
		# La tôle s'abîme : une voiture qu'on maltraite finit par exploser,
		# et c'est ce qui donne un sens au garage.
		_pv_vehicule = max(0.0, _pv_vehicule - abs(_vitesse) * 0.012 / _solidite())
		if _pv_vehicule <= 0.0:
			_vehicule_detruit()
	_vitesse *= lerp(0.95, 0.28, frontal)

	var tangente := Vector2(-normale.y, normale.x)
	if tangente.dot(direction) < 0.0:
		tangente = -tangente
	_angle = lerp_angle(_angle, tangente.angle(), (1.0 - frontal) * 0.22)
	_glisse = Vector2.RIGHT.rotated(_angle)

## Une voiture garée n'est pas un mur, mais on ne la traverse pas non plus :
## on est repoussé hors de sa silhouette et on perd la part de vitesse qu'on a
## mise dedans. Les dégâts et la poussée de l'autre, c'est l'hôte qui les dit —
## ici on ne fait que rendre le choc IMMÉDIAT sous les doigts.
func _voitures_autour(rayon: float) -> Array:
	var obstacles: Array = []
	for auto in ville.autos:
		if String(auto.get("pilote", "")) != "" or int(auto["genre"]) == VilleVivante.EPAVE:
			continue
		if (auto["p"] as Vector2).distance_to(_position) < rayon:
			obstacles.append(auto["p"])
	for d in ville.dormantes_endormies(_position, rayon):
		obstacles.append(d["p"])
	return obstacles

func _heurter_les_voitures() -> void:
	var direction := Vector2.RIGHT.rotated(_angle)
	for p: Vector2 in _voitures_autour(90.0):
		var vers := _position - p
		var ecart := vers.length()
		var minimum := VilleVivante.CHOC_AUTO
		if ecart >= minimum or ecart < 0.01:
			continue
		var normale := vers / ecart
		_position = p + normale * minimum
		var frontal: float = abs(direction.dot(normale))
		if frontal > 0.5 and abs(_vitesse) > 260.0:
			Sons.jouer("choc_moyen" if abs(_vitesse) > 500.0 else "choc_doux",
				_rng.randf_range(0.94, 1.06), -10.0)
			_secousse = max(_secousse, 0.2)
			# Une carrosserie tapée déclenche son alarme : c'est ce qui fait
			# qu'un accrochage réveille la rue plutôt que de passer inaperçu.
			if _rng.randf() < 0.35:
				Sons.jouer("alarme_vehicule", 1.0, -20.0)
		_vitesse *= lerp(0.96, 0.45, frontal)

func _solidite() -> float:
	return float(CARACTERES.get(_modele_vehicule, CARACTERES[-1])["t"])

func _regenerer(delta: float) -> void:
	_depuis_coup += delta
	if _depuis_coup > ACCALMIE:
		_vie = min(VIE_MAX, _vie + REGEN * delta)

## Il n'y a pas de mur : au-delà de la friche on est ramené, doucement d'abord.
## Un mur invisible qui arrête net donne l'impression d'un défaut ; une
## inertie qui ramène se comprend sans explication.
func _surveiller_la_friche(delta: float) -> void:
	var limite := Rect2(-carte.banlieue(), -carte.banlieue(),
		carte.etendue().x + carte.banlieue() * 2.0, carte.etendue().y + carte.banlieue() * 2.0)
	if limite.has_point(_position):
		_hors_ville = max(0.0, _hors_ville - delta * 2.0)
		return
	_hors_ville += delta
	# ⚠ Vers le CŒUR, pas vers le centre géométrique : depuis que la ville est
	# un archipel, le milieu de la carte peut être en pleine eau, et on y
	# poussait le joueur perdu jusqu'à ce qu'il y reste planté.
	var vers_centre := (carte.coeur() - _position).normalized()
	_position += vers_centre * RETOUR * delta * min(_hors_ville, 3.0)

## Les lieux qui font quelque chose quand on s'y arrête : le garage de
## peinture. Il ne se déclenche qu'en voiture — repeindre un piéton n'a
## jamais effacé un casier.
func _surveiller_les_lieux(delta: float) -> void:
	_mot_affaire_reste = max(0.0, _mot_affaire_reste - delta)
	_largage = max(0.0, _largage - delta)
	_cascade_reste = max(0.0, _cascade_reste - delta)
	_station_dite = max(0.0, _station_dite - delta)
	_tenir_la_roue()
	# LA FRÉQUENCE DE LA POLICE n'a pas de morceau : elle DIT des choses. On
	# emprunte les voix de la radio de bord (celles qui parlent déjà quand on
	# est recherché), avec un niveau minimum pour qu'elle grésille même quand
	# on n'a rien fait — c'est une radio qu'on écoute, pas une alarme.
	if not _pied and _station == Sons.STATION_POLICE:
		Sons.radio_police(max(1, ville.etoiles(Session.cle)))
	if _cascade_reste == 0.0:
		_cascade = 0
	if _plaques > 0.0:
		_plaques = max(0.0, _plaques - delta)
		if _plaques == 0.0:
			_dire_affaire("plaques repérées")
	_avoir_faim(delta)
	# MANGER : une touche, pas de menu. Elle vient AVANT les affaires : à la
	# caisse d'une supérette, `F` achète et `G` mange, et les deux doivent
	# pouvoir se suivre sans fermer quoi que ce soit.
	if Commandes.manger_declenchee():
		_consommer()
	if Commandes.vue_declenchee():
		_basculer_la_vue()
	_surveiller_les_affaires(delta)
	# LA SUPÉRETTE s'ouvre quand on entre sur son pas de porte, et se ferme
	# quand on s'en va. Pas de `F` : le menu EST l'interaction, et une boutique
	# où il faut appuyer sur une touche pour voir qu'il y a une boutique, c'est
	# une boutique que personne ne trouve.
	#
	# ⚠ On ne la rouvre pas tant qu'on n'en est pas SORTI (`_superette_en_cours`).
	# Sans ce garde, refermer le menu d'un coup d'ÉCHAP le rouvrait à l'image
	# suivante, puisqu'on n'avait pas bougé d'un pixel.
	var boutique := carte.superette_de(_position)
	if boutique != _superette_en_cours:
		if _superette_ouverte and boutique < 0:
			_basculer_la_superette()
		_superette_en_cours = boutique
		if boutique >= 0 and not _superette_ouverte and _hors_service <= 0.0:
			_basculer_la_superette()
	# Une cabine se décroche à pied comme au volant : obliger à descendre au
	# milieu d'une avenue pour prendre un contrat, c'est se faire faucher.
	var cabine := carte.cabine_de(_position)
	if cabine != _cabine_en_cours:
		_cabine_en_cours = cabine
		if cabine >= 0 and _contrat.is_empty():
			canal.envoyer("cabine", {"i": cabine, "x": int(_position.x), "y": int(_position.y)})
			if est_hote():
				ville.proposer_contrat(Session.cle, cabine, _position)
				_vider_les_evenements()

	if _pied:
		_garage_en_cours = -1
		return
	var garage := carte.garage_de(_position)
	if garage == _garage_en_cours:
		return
	_garage_en_cours = garage
	if garage < 0:
		return
	_pv_vehicule = PV_VOITURE
	# ON REPEINT POUR DE VRAI (§1.3). La couleur change, la voiture se rebâtit
	# sous le joueur, et les autres la reçoivent avec la position. C'est ce
	# qui manquait pour que « la police ne vous reconnaît plus » se VOIE.
	_teinte = FormesCarnage.peinture_au_hasard(_rng, _teinte)
	_rebatir_ma_voiture()
	_dire_affaire("repeinte — le casier est vierge")
	if Commandes.pilote_automatique:
		print("[banc] repeinte en #%s au garage %d" % [_teinte.to_html(false), garage])
	Sons.jouer("portail", 1.0, -8.0)
	canal.envoyer("garage", {"i": garage})
	if est_hote():
		ville.repeindre(Session.cle)
		_vider_les_evenements()

# ------------------------------------------------------- l'argent

## Ce qu'on peut TRAITER là où l'on est : acheter la planque, y déposer son
## argent, l'améliorer, se faire recoudre. Une seule touche (F), et la ligne du
## HUD dit toujours ce qu'elle ferait — un menu, à cette échelle, se lirait
## moins vite qu'on ne se fait tirer dessus.
func _surveiller_les_affaires(_delta: float) -> void:
	_affaire = ""
	var planque := carte.planque_de(_position)
	var hopital := carte.hopital_de(_position)
	if planque >= 0:
		var fiche := carte.planque_par_id(_position, planque)
		var prix := int(fiche.get("prix", 0))
		if _planque < 0:
			# LE CATALOGUE ARRIVE ENFIN AU JOUEUR. Les huit appartements ont un
			# nom et un résumé depuis le premier jour, et personne ne les avait
			# jamais lus : on achetait « une planque » à un prix, sans savoir
			# qu'on achetait Le Penthouse ou Le Taudis.
			# ⚠ Le prix reste celui de `PlanVille`, pas celui du catalogue :
			# c'est lui qui est équilibré avec l'argent qu'on ramasse en ville.
			# Afficher deux prix pour la même porte ne se comprendrait pas.
			_affaire = "F : acheter %s — $%d" % [_nom_du_logement(), prix]
			if Commandes.affaire_declenchee():
				_acheter_la_planque(planque, prix)
		elif planque == _planque:
			# À PIED, F ouvre la porte ; l'argent se dépose maintenant DANS le
			# coffre, à l'intérieur. Déposer depuis le trottoir marchait, mais
			# ça ne racontait rien : on n'avait aucune raison d'avoir un
			# appartement. Au volant, F dépose toujours — on ne descend pas de
			# voiture juste pour porter une liasse.
			if _pied:
				_affaire = "F : entrer chez vous"
				if Commandes.affaire_declenchee():
					_entrer_chez_soi(planque)
			else:
				var suivante := _amelioration_suivante()
				if _argent > 0:
					_affaire = "F : déposer $%d" % _argent
				elif suivante != "":
					_affaire = "F : %s — $%d" % [_libelle_amelioration(suivante), int(PlanVille.PRIX_AMELIORATION[suivante])]
				else:
					_affaire = "chez vous — $%d à l'abri" % _banque
				if Commandes.affaire_declenchee():
					_traiter_chez_soi(suivante)
		else:
			_affaire = "planque d'un autre"
		if planque != _planque_en_cours:
			_planque_en_cours = planque
			if planque == _planque:
				_ranger_le_vehicule()
			elif _planque < 0:
				# Le résumé à l'arrivée, deux secondes : c'est la vitrine de
				# l'agence. La ligne d'action, elle, n'a la place que du nom.
				_dire_affaire(_resume_du_logement())
	elif not _pied and _modele_vehicule == FormesCarnage.MODELE_TAXI and _taxi_en_service():
		pass
	elif not _pied and ville.casse_de(_position) >= 0:
		# LA CASSE (§1.3). On est au volant, sur la dalle : `F` broie. C'est le
		# seul endroit du jeu où une voiture DISPARAÎT — et le seul revenu qui
		# ne coûte pas une étoile, ce qui en fait la sortie propre d'un vol.
		_affaire = "F : broyer la voiture — $%d" % ville.prix_de_la_casse(_modele_vehicule)
		if Commandes.affaire_declenchee():
			_broyer_ma_voiture()
	elif not _pied and _atelier_ici() >= 0:
		# L'ATELIER. On est au volant, sur un garage qui vend : la baie sous les
		# roues décide de la marchandise, `F` l'achète.
		var baie := _baie_sous_les_roues()
		var article: Dictionary = FormesCarnage.ATELIER[baie]
		var prix := int(article["prix"])
		_affaire = "F : %s — $%d" % [String(article["nom"]).to_lower(), prix]
		if Commandes.affaire_declenchee():
			_acheter_a_l_atelier(baie, prix)
	elif _pied and not carte.repaire_de(_position).is_empty():
		# LE REPAIRE DU GANG (§3). Jusqu'ici c'était du décor : un tag au sol,
		# des hommes autour, et rien à y faire. On y entre maintenant — mais
		# seulement si le gang vous COUVRE, c'est-à-dire au palier allié.
		# C'est la seule chose que le respect ouvre et qu'on ne peut pas
		# obtenir autrement : le reste (les contrats, les alliés en combat)
		# vient à vous, le repaire, il faut y aller.
		var repaire: Dictionary = carte.repaire_de(_position)
		var chez := int(repaire.get("gang", -1))
		var du_gang := ville.respect_pour(Session.cle, chez)
		var a_nous := ville.repaire_pris_par(int(repaire.get("id", -1))) == Session.cle
		# ⚠ UN REPAIRE PRIS EST À SON PRENEUR, quel que soit le respect. C'est
		# tout le prix du raid : on l'a payé en munitions, on n'a pas à
		# remonter ensuite une jauge chez des gens qu'on vient de chasser.
		if du_gang >= VilleVivante.SEUIL_ALLIE or a_nous:
			_affaire = "F : entrer %s" % ("chez vous" if a_nous else "chez %s" % carte.nom_du_gang(chez))
			if Commandes.affaire_declenchee():
				_entrer_dans_le_repaire(chez)
		elif ville.humeur(Session.cle, chez) == VilleVivante.H_VUE:
			# LE RAID (§3). Se tenir là SUFFIT : ils tirent déjà, le compteur
			# descend à chaque homme tombé, et il n'y a aucune touche à
			# apprendre. Le tableau de bord dit ce qui reste.
			_tenir_le_terrain(int(repaire.get("id", -1)), Vector2(repaire.get("p", _position)), chez)
			var raid := ville.raid_de(Session.cle)
			if raid.is_empty():
				_affaire = "%s vous chasse — tenez le terrain" % carte.nom_du_gang(chez)
			else:
				_affaire = "RAID — encore %d homme(s) de %s" % [int(raid["restants"]),
					carte.nom_du_gang(chez)]
		else:
			# ⚠ LE REFUS DIT LE CHIFFRE. C'est la leçon des cabines : sans lui,
			# une porte qui ne s'ouvre pas se lit comme une porte cassée, et
			# le joueur n'y revient jamais.
			_affaire = "%s n'ouvre qu'à %d de respect (vous : %d)" % [
				carte.nom_du_gang(chez), int(VilleVivante.SEUIL_ALLIE), int(du_gang)]
	elif hopital >= 0:
		if _vie < VIE_MAX:
			_affaire = "F : se faire recoudre — $%d" % SOIN
			if Commandes.affaire_declenchee():
				_se_faire_soigner()
		else:
			_affaire = "hôpital"
	else:
		_planque_en_cours = -1
		# Loin de tout lieu, au volant, `F` LARGUE. La même touche qu'ailleurs :
		# elle fait toujours « l'affaire de l'endroit où l'on est », et en pleine
		# rue l'affaire c'est ce qu'on traîne dans le coffre.
		if not _pied and _stock_de_piege() != "":
			var quoi := _stock_de_piege()
			_affaire = "F : %s (%d)" % ["mine" if quoi == "mines" else "huile", int(_mods[quoi])]
			if Commandes.affaire_declenchee():
				_larguer(quoi)
	_hopital_en_cours = hopital

## Le garage sous les roues, s'il vend des modifications. On redemande la
## FICHE et pas seulement l'identifiant : il faut son centre pour savoir sur
## quelle baie on s'est garé.
## LE SERVICE DE TAXI. Renvoie vrai s'il a rempli `_affaire` — la chaîne des
## affaires enchaîne alors sans regarder les autres lieux.
##
## Deux moments, une seule touche : prendre le client qui hèle, puis le
## déposer. Entre les deux, le radar pointe la destination — sans elle, une
## course est une adresse qu'on cherche à l'aveugle pendant que le compteur
## tourne.
func _taxi_en_service() -> bool:
	if _course.is_empty():
		var client := _client_qui_hele()
		if client.is_empty():
			return false
		_affaire = "F : prendre le client"
		if Commandes.affaire_declenchee():
			_prendre_le_client(client)
		return true
	var reste: float = (_course["p"] as Vector2).distance_to(_position)
	if reste > PORTEE_DEPOT:
		_affaire = "course : %d pâtés" % int(reste / PlanVille.PAS)
		return true
	_affaire = "F : déposer — $%d" % _prix_de_la_course()
	if Commandes.affaire_declenchee():
		_deposer_le_client()
	return true

## Qui hèle : un PIÉTON, à portée, et seulement si l'on roule au pas. Un client
## cueilli à trois cents à l'heure serait un piéton écrasé.
func _client_qui_hele() -> Dictionary:
	if abs(_vitesse) > 90.0:
		return {}
	for personne in ville.gens:
		if int(personne["genre"]) != VilleVivante.PIETON:
			continue
		if (personne["p"] as Vector2).distance_to(_position) <= PORTEE_CLIENT:
			return personne
	return {}

func _prendre_le_client(client: Dictionary) -> void:
	# La destination est TIRÉE DANS LA RUE, loin mais pas à l'autre bout de la
	# ville : à quatre mille pixels, la course dure plus longtemps que la
	# manche.
	var ou := carte.point_de_rue(_rng, _position, 900.0, 2600.0)
	_course = {"p": ou, "depart": _position}
	_cible_contrat = {"k": "course", "p": ou}
	canal.envoyer("client", {"id": int(client["id"])})
	if est_hote():
		ville.embarquer_client(int(client["id"]))
		_vider_les_evenements()
	_dire_affaire("en course — %d pâtés" % int(_position.distance_to(ou) / PlanVille.PAS))
	Sons.jouer("portiere_ferme", 1.0, -10.0)

func _prix_de_la_course() -> int:
	if _course.is_empty():
		return 0
	var trajet: float = (_course["depart"] as Vector2).distance_to(_course["p"])
	return max(PRIME_COURSE_MIN, int(trajet / PlanVille.PAS * float(PRIX_COURSE)))

func _deposer_le_client() -> void:
	var prime := _prix_de_la_course()
	canal.envoyer("payer", {"m": prime, "q": "course",
		"x": int(_position.x), "y": int(_position.y)})
	if est_hote():
		ville.payer(Session.cle, _position, prime, "course")
		_vider_les_evenements()
	_course = {}
	_cible_contrat = {}
	_annoncer("COURSE PAYÉE — $%d" % prime, Color("#f2c53d"), 2.6)
	Sons.jouer("fin", 1.2, -8.0)

func _fiche_garage_ici() -> Dictionary:
	for g in carte.lieux_autour(_position, PlanVille.RAYON_GARAGE)["garages"]:
		return g
	return {}

func _atelier_ici() -> int:
	var g := _fiche_garage_ici()
	if g.is_empty() or not FormesCarnage.est_atelier(int(g["id"])):
		return -1
	return int(g["id"])

func _baie_sous_les_roues() -> int:
	var g := _fiche_garage_ici()
	if g.is_empty():
		return 0
	return FormesCarnage.baie_sous(_position, Vector2(g["p"]))

## Ce qu'on peut larguer : les mines d'abord, l'huile ensuite. L'ordre est
## celui du danger — quand on sème quelque chose derrière soi en fuyant, on
## veut la mine tant qu'il en reste.
func _stock_de_piege() -> String:
	for quoi in ["mines", "huile"]:
		if int(_mods.get(quoi, 0)) > 0:
			return quoi
	return ""

func _acheter_a_l_atelier(baie: int, prix: int) -> void:
	var article: Dictionary = FormesCarnage.ATELIER[baie]
	var quoi := String(article["cle"])
	if _argent < prix:
		_dire_affaire("il manque $%d" % (prix - _argent))
		Sons.jouer("choc", 0.6, -14.0)
		return
	_encaisser_argent(-prix)
	match quoi:
		"plaques":
			_plaques = DUREE_PLAQUES
			canal.envoyer("mod", {"m": "plaques", "d": DUREE_PLAQUES})
			if est_hote():
				ville.plaques[Session.cle] = DUREE_PLAQUES
				_vider_les_evenements()
		"mines", "huile":
			_mods[quoi] = int(_mods.get(quoi, 0)) + MUNITIONS_PIEGE
		_:
			_mods[quoi] = true
	# L'achat se VOIT tout de suite : une mitrailleuse payée qui n'apparaît
	# qu'au prochain véhicule, c'est un achat dont on doute.
	FormesCarnage.armer_la_voiture(_corps_auto, bool(_mods.get("mitrailleuse", false)))
	_dire_affaire("%s — %s" % [String(article["nom"]).to_lower(), String(article["mot"])])
	Sons.jouer("portail", 1.2, -7.0)

## Larguer un piège DERRIÈRE soi, pas dessous : posé sous la voiture, on
## roulait dessus à l'arrêt et on s'asseyait sur sa propre mine.
func _larguer(quoi: String) -> void:
	if _largage > 0.0:
		return
	_largage = DELAI_LARGAGE
	_mods[quoi] = int(_mods[quoi]) - 1
	var ou := _position - Vector2.RIGHT.rotated(_angle) * 56.0
	var genre := VilleVivante.MINE if quoi == "mines" else VilleVivante.HUILE
	canal.envoyer("piege", {"x": int(ou.x), "y": int(ou.y), "g": genre})
	if est_hote():
		ville.poser_piege(Session.cle, ou, genre)
		_vider_les_evenements()
	Sons.jouer("portiere_ferme", 0.7, -12.0)

## Ouvrir sa porte. L'appartement se déduit du QUARTIER de la planque
## (`Interieurs.pour_quartier`) : même planque, même appartement chez tout le
## monde, sans qu'un octet passe par le réseau.
func _entrer_chez_soi(planque: int) -> void:
	_dedans = _logement_ici()
	_dedans_p = Interieurs.entree(_dedans)
	# Un pas vers l'intérieur : posé pile sur le seuil, on ressort au premier
	# appui sur F, et la porte devient une porte à tambour.
	_dedans_p = Interieurs.degager(_dedans, _dedans_p)
	_dedans_noeud = Interieurs.batir(_dedans)
	_dedans_noeud.position = Interieurs.SOUS_SOL
	# ⚠ SANS CECI ON ENTRE CHEZ SOI ET ON REGARDE UN MUR. Un appartement bâti
	# tel quel est une boîte fermée ; la caméra du jeu est fixe et regarde
	# depuis le sud, donc les façades sud et est sont entre l'œil et la pièce.
	# Le banc de photo escamotait ces deux murs depuis toujours, dans son coin —
	# c'est pour ça que les vitrines étaient lisibles et que personne n'avait vu
	# le problème.
	Interieurs.degager_la_vue(_dedans_noeud, Vector2(0.0, 1.0))
	# Un disque de couleur par chose à faire : c'est le geste de GTA 2, et sans
	# lui le coffre a la même silhouette qu'un placard vu de dessus.
	Interieurs.poser_marques(_dedans_noeud, _dedans)
	monde().add_child(_dedans_noeud)
	_pied = true
	_vitesse = 0.0
	_dire_affaire("chez vous — %s" % String(Interieurs.CATALOGUE[_dedans]["nom"]))
	Sons.jouer("portail", 1.0, -8.0)
	print("[carnage] entré chez soi : %s (planque %d)" % [_dedans, planque])

## REPEINDRE LE TAG D'UN REPAIRE PRIS, dans tous les morceaux chargés. Le
## repaire peut être à cheval sur deux morceaux voisins : on parcourt, on ne
## suppose pas.
## ⚠ UN MORCEAU BÂTI APRÈS LA PRISE porte un tag NEUF, aux couleurs du gang
## chassé : le repaint de l'événement n'a repeint que les morceaux chargés à ce
## moment-là. On s'éloigne, on revient, et le repaire est redevenu à eux —
## alors que la ville, elle, sait qu'il est pris. Une passe par image, sur une
## poignée d'entrées, remet les tags d'accord avec la simulation.
func _rafraichir_les_repaires() -> void:
	if ville.repaires_pris.is_empty():
		return
	for cle in _morceaux:
		for entree in (_morceaux[cle] as MorceauVille).repaires:
			var id := int(entree["id"])
			if not ville.repaires_pris.has(id) or bool(entree.get("repeint", false)):
				continue
			entree["repeint"] = true
			var qui := String(ville.repaires_pris[id]["j"])
			var place := int(joueurs.get(qui, {}).get("place", 0))
			FormesCarnage.repeindre_le_tag(entree["n"] as Node3D, Palette.couleur_joueur(place),
				String(joueurs.get(qui, {}).get("pseudo", "?")))

func _reprendre_le_tag(id: int, qui: String) -> void:
	var place := int(joueurs.get(qui, {}).get("place", 0))
	var couleur := Palette.couleur_joueur(place)
	var nom := String(joueurs.get(qui, {}).get("pseudo", "?"))
	for cle in _morceaux:
		for entree in (_morceaux[cle] as MorceauVille).repaires:
			if int(entree["id"]) == id:
				entree["repeint"] = true
				FormesCarnage.repeindre_le_tag(entree["n"] as Node3D, couleur, nom)

## TENIR LE TERRAIN. Le client dit « je suis sur ce tag » ; c'est l'hôte qui
## décide si ça ouvre un raid (il est le seul à connaître le respect de tout le
## monde et l'état des autres raids). On n'annonce qu'une fois par seconde : le
## raid se rafraîchit, il ne se rouvre pas, et quinze paquets par seconde pour
## dire qu'on n'a pas bougé, c'est quinze de trop.
func _tenir_le_terrain(id: int, ou: Vector2, gang: int) -> void:
	_depuis_raid -= get_process_delta_time()
	if _depuis_raid > 0.0:
		return
	_depuis_raid = 1.0
	canal.envoyer("terrain", {"i": id, "x": int(ou.x), "y": int(ou.y), "g": gang})
	if est_hote():
		ville.tenir_le_terrain(Session.cle, id, ou, gang)
		_vider_les_evenements()

## ENTRER DANS UN REPAIRE. Même mécanique que chez soi — l'intérieur est bâti
## loin sous la ville, les deux façades côté caméra sont escamotées, les marques
## au sol disent où `F` répond — avec un seul intérieur pour les sept gangs,
## repeint à leur teinte (`Interieurs._repaire_du_gang`).
##
## ⚠ On ne diffuse RIEN. Les autres joueurs voient quelqu'un d'immobile sur le
## tag, ce qui est exactement ce qui se passe : `_position` ne bouge pas de tout
## le séjour. C'est la règle de la planque, et elle vaut ici pour la même
## raison — un intérieur partagé demanderait de synchroniser une pièce que
## personne d'autre ne regarde.
func _entrer_dans_le_repaire(gang: int) -> void:
	_dedans = Interieurs.repaire_de(gang)
	_dedans_p = Interieurs.degager(_dedans, Interieurs.entree(_dedans))
	_dedans_noeud = Interieurs.batir(_dedans)
	_dedans_noeud.position = Interieurs.SOUS_SOL
	Interieurs.degager_la_vue(_dedans_noeud, Vector2(0.0, 1.0))
	Interieurs.poser_marques(_dedans_noeud, _dedans)
	monde().add_child(_dedans_noeud)
	_pied = true
	_vitesse = 0.0
	_dire_affaire("chez %s" % carte.nom_du_gang(gang))
	Sons.jouer("portail", 0.9, -8.0)
	print("[carnage] entré au repaire %s" % carte.nom_du_gang(gang))

## L'ARMURERIE. Le seul comptoir d'armes du jeu : ailleurs, une arme se ramasse
## sur un corps ou dans une caisse, donc au hasard. Ici on la choisit — à
## condition d'avoir mérité la porte.
func _acheter_a_l_armurerie(gang: int) -> void:
	var etal := FormesCarnage.armurerie_du_gang(gang)
	var prix := int(etal["prix"])
	if _argent < prix:
		_dire_affaire("il manque $%d" % (prix - _argent))
		Sons.jouer("choc", 0.6, -14.0)
		return
	_encaisser_argent(-prix)
	var quoi := String(etal["arme"])
	# ⚠ ON RECHARGE si c'est déjà l'arme en main, on ne la remplace pas : payer
	# sept cents pour repartir avec le même chargeur à moitié vide serait la
	# meilleure façon de ne jamais revenir.
	if _arme == quoi:
		_munitions += int(ARMES[quoi]["munitions"])
	else:
		_arme = quoi
		_munitions = int(ARMES[quoi]["munitions"])
	_dire_affaire("%s — %s" % [String(ARMES[quoi]["nom"]).to_lower(), String(etal["mot"])])
	Sons.jouer("depart", 0.9, -8.0)

func _sortir_de_chez_soi() -> void:
	# ⚠ ON NE SORT PAS SA VOITURE DU GARAGE D'UN AUTRE. La même fonction sert
	# maintenant aux repaires de gang : sans ce drapeau, quitter le repaire des
	# Braises faisait apparaître sous soi la voiture rangée chez soi, à l'autre
	# bout de la ville.
	var chez_un_gang := Interieurs.est_repaire(_dedans)
	if _dedans_noeud != null:
		_dedans_noeud.queue_free()
		_dedans_noeud = null
	_dedans = ""
	# On ressort là où l'on est entré : `_position` n'a pas bougé pendant tout
	# le séjour, et c'est voulu — les autres joueurs voient quelqu'un d'immobile
	# sur sa planque, ce qui est exactement ce qui se passe.
	Sons.jouer("portail", 0.85, -8.0)
	if not chez_un_gang:
		_sortir_du_garage(_position, _angle)

## LE GARAGE. `_ranger_le_vehicule` gardait déjà ce qu'on ramène chez soi ; il
## manquait de le RESSORTIR. Se relever après une mort annonçait « votre
## véhicule vous attend » et il n'y avait rien devant la porte : un message qui
## ment est pire qu'un garage qui n'existe pas.
##
## On ne pose pas une voiture dans le décor pour aller l'ouvrir ensuite : on met
## le joueur AU VOLANT directement. Le garage est une amélioration payée, pas
## une chasse au trésor devant sa porte.
func _sortir_du_garage(ou: Vector2, angle: float) -> bool:
	if not bool(_ameliorations["garage"]) or _garage_perso < 0 or _dedans != "":
		return false
	_prendre_le_volant(ID_VOITURE_GARAGE + _place, VilleVivante.CIVILE,
		carte.degager(ou, RAYON_VOITURE)[0], angle, PV_VOITURE, _garage_perso)
	_dire_affaire("sorti du garage")
	return true

## La marche à l'intérieur. Les murs et les meubles viennent de
## `Interieurs.degager` — donc du DESSIN, le même que celui qu'on regarde.
func _marcher_dedans(delta: float) -> void:
	var commande := Commandes.direction()
	if commande.length() > 0.1:
		_angle = commande.angle()
		_vitesse = VITESSE_A_PIED
		_depuis_pas -= delta
		if _depuis_pas <= 0.0:
			_depuis_pas = 0.34
			Sons.jouer("pas_beton", _rng.randf_range(0.94, 1.08), -22.0)
		var vise := _dedans_p + commande.normalized() * PAS_DEDANS * delta
		_dedans_p = Interieurs.degager(_dedans, vise)
	else:
		_vitesse = 0.0
		_depuis_pas = 0.0
	_regenerer(delta)

## Ce que F fait chez soi : le coffre, la garde-robe, ou la porte. Trois
## endroits, trois gestes, et la ligne du HUD dit toujours lequel — c'est la
## règle de tout le jeu, et à cette échelle un menu se lirait moins vite qu'on
## ne se fait tirer dessus dehors.
##
## Au coffre, E RETIRE. Il fallait une seconde touche : F y sert déjà à déposer
## puis à payer les travaux, et empiler un troisième sens dessus rendait le
## geste imprévisible — on venait chercher de l'argent et on repartait avec un
## arsenal. E ne fait rien d'autre à l'intérieur (pas de portière chez soi).
func _affaires_dedans() -> void:
	_affaire = ""
	# ⚠ UN REPAIRE N'EST PAS UN APPARTEMENT. Il n'a ni coffre ni penderie, et
	# la suite de `elif` ci-dessous serait tombée dans la branche « chez vous —
	# le coffre est au fond » : une ligne de tableau de bord qui parle d'un
	# meuble qui n'existe pas, dans une pièce qui ne vous appartient pas.
	if Interieurs.est_repaire(_dedans):
		_affaires_au_repaire()
		return
	# ⚠ On mesure la distance au POINT DE POSTE, pas au meuble : c'est le point
	# que la marque au sol montre. Mesuré depuis le centre du meuble, le coffre
	# répondait à travers le lit, et la marque était ailleurs que le bouton.
	var au_coffre := Interieurs.point_de_poste(_dedans, "coffre")
	var a_la_penderie := Interieurs.point_de_poste(_dedans, "garde-robe")
	var au_frigo := Interieurs.point_de_poste(_dedans, "frigo")
	var pres_du_coffre: bool = au_coffre != Vector2.ZERO and _dedans_p.distance_to(au_coffre) < PORTEE_COFFRE
	var pres_de_la_penderie: bool = a_la_penderie != Vector2.ZERO \
		and _dedans_p.distance_to(a_la_penderie) < PORTEE_COFFRE
	var pres_du_frigo: bool = au_frigo != Vector2.ZERO \
		and _dedans_p.distance_to(au_frigo) < PORTEE_COFFRE
	var pres_de_la_porte := _dedans_p.distance_to(Interieurs.entree(_dedans)) < PORTEE_PORTE
	if pres_du_coffre:
		var suivante := _amelioration_suivante()
		if _argent > 0:
			_affaire = "F : déposer $%d au coffre" % _argent
		elif suivante != "":
			_affaire = "F : %s — $%d" % [_libelle_amelioration(suivante), int(PlanVille.PRIX_AMELIORATION[suivante])]
		else:
			_affaire = "$%d à l'abri" % _banque
		if _banque > 0:
			_affaire += "   ·   E : retirer $%d" % _banque
		if Commandes.affaire_declenchee():
			_traiter_chez_soi(suivante)
		elif _banque > 0 and Commandes.action_declenchee():
			_retirer_du_coffre()
	elif pres_de_la_porte:
		# ⚠ LA PORTE PASSE AVANT LA PENDERIE. Dans le Taudis le portemanteau est
		# à quarante centimètres du paillasson : dans l'autre ordre, on se
		# changeait au lieu de sortir et on ne pouvait plus quitter le studio.
		# On se change d'un pas en arrière.
		# Le HUD dit ce qui va se passer : sortir au volant quand on a payé le
		# garage n'a rien d'évident, et une voiture qui apparaît sous soi sans
		# prévenir se lit comme un défaut.
		var au_volant: bool = bool(_ameliorations["garage"]) and _garage_perso >= 0
		_affaire = "F : ressortir au volant" if au_volant else "F : ressortir"
		if Commandes.affaire_declenchee():
			_sortir_de_chez_soi()
	elif pres_du_frigo:
		# LE GARDE-MANGER. Même geste que le coffre, et c'est voulu : F range,
		# E reprend. Deux réserves dans la même pièce qui s'ouvriraient de deux
		# façons différentes, c'est une touche qu'on cherche à chaque fois.
		var dans_les_poches := Provisions.compte(_provisions)
		var au_frais := Provisions.compte(_frigo)
		if dans_les_poches > 0:
			_affaire = "F : ranger %d provision(s)" % dans_les_poches
		else:
			_affaire = "frigo — %d/%d au frais" % [au_frais, Provisions.FRIGO]
		if au_frais > 0:
			_affaire += "   ·   E : remplir les poches"
		if Commandes.affaire_declenchee():
			_ranger_au_frigo()
		elif au_frais > 0 and Commandes.action_declenchee():
			_prendre_au_frigo()
	elif pres_de_la_penderie:
		_affaire = "F : se changer — %s" % Personnages.nom(Session.personnage_affiche())
		if Commandes.affaire_declenchee():
			_changer_de_tenue()
	else:
		_affaire = "chez vous — le coffre est au fond"

## Ce que `F` fait dans un repaire : le râtelier, ou la porte. Deux gestes, et
## la ligne du HUD dit toujours lequel — c'est la règle de tout le jeu.
func _affaires_au_repaire() -> void:
	var gang := Interieurs.gang_du_repaire(_dedans)
	var au_ratelier := Interieurs.point_de_poste(_dedans, "armurerie")
	var pres_du_ratelier: bool = au_ratelier != Vector2.ZERO \
		and _dedans_p.distance_to(au_ratelier) < PORTEE_COFFRE
	var pres_de_la_porte := _dedans_p.distance_to(Interieurs.entree(_dedans)) < PORTEE_PORTE
	if pres_de_la_porte:
		# LA PORTE PASSE AVANT LE RÂTELIER, comme chez soi : dans une pièce de
		# six tuiles, un poste qu'on ne peut pas quitter est un piège.
		_affaire = "F : ressortir"
		if Commandes.affaire_declenchee():
			_sortir_de_chez_soi()
	elif pres_du_ratelier:
		var etal := FormesCarnage.armurerie_du_gang(gang)
		_affaire = "F : %s — $%d" % [String(ARMES[etal["arme"]]["nom"]).to_lower(),
			int(etal["prix"])]
		if Commandes.affaire_declenchee():
			_acheter_a_l_armurerie(gang)
	else:
		_affaire = "chez %s — le râtelier est au fond" % carte.nom_du_gang(gang)

## RANGER AU FRIGO : tout ce qu'on porte, d'un coup. Un menu de quantités dans
## un jeu qui se joue à quatre touches ne se lit pas — et on ne vient pas chez
## soi pour faire l'inventaire, on vient vider ses poches.
##
## ⚠ Le frigo a un PLAFOND. Ce qui ne rentre pas reste sur soi, et le message
## le dit : un rangement qui fait disparaître ce qui dépasse, c'est trois
## burgers perdus qu'on cherchera toute la manche.
func _ranger_au_frigo() -> void:
	var range := 0
	for cle in _provisions.keys():
		while int(_provisions.get(cle, 0)) > 0 and Provisions.compte(_frigo) < Provisions.FRIGO:
			Provisions.retirer(_provisions, String(cle))
			Provisions.ajouter(_frigo, String(cle))
			range += 1
	if range == 0:
		_dire_affaire("le frigo est plein" if not _provisions.is_empty() else "rien à ranger")
		return
	var reste := Provisions.compte(_provisions)
	_dire_affaire("%d au frais%s" % [range, " — %d ne rentrent pas" % reste if reste > 0 else ""])
	Sons.jouer("porte", 1.1, -13.0)

## REPRENDRE : on remplit les poches avec ce qui comble le plus, en commençant
## par le plus utile (`Provisions.le_mieux` appliqué au frigo). Prendre « le
## premier de la liste » remplissait le sac de bouteilles d'eau parce qu'elles
## sont en tête du catalogue.
func _prendre_au_frigo() -> void:
	var pris := 0
	while Provisions.compte(_provisions) < Provisions.POCHES and not _frigo.is_empty():
		var cle := Provisions.le_mieux(_frigo, _faim, _soif, _vie, FAIM_MAX)
		# Plus rien d'utile au regard de l'état actuel : on prend quand même ce
		# qui reste, parce qu'on part pour une sortie, pas pour un repas.
		if cle == "":
			cle = String(_frigo.keys()[0])
		Provisions.retirer(_frigo, cle)
		Provisions.ajouter(_provisions, cle)
		pris += 1
	_dire_affaire("%d provision(s) en poche" % pris if pris > 0 else "les poches sont pleines")
	Sons.jouer("porte", 0.9, -13.0)

## RETIRER. Sans ça, le coffre était un puits : l'argent y entrait et n'en
## sortait plus, et on ne pouvait pas ressortir avec de quoi payer un hôpital
## ou une planque. On retire TOUT — le joueur choisit son risque, et un menu de
## montants dans un jeu qui se joue à quatre touches ne se lit pas.
func _retirer_du_coffre() -> void:
	if _banque <= 0:
		return
	var sorti := _banque
	_argent += sorti
	_banque = 0
	_dire_affaire("$%d repris — ne vous faites pas descendre" % sorti)
	Sons.jouer("depart", 1.1, -8.0)

## SE CHANGER. C'est le geste de GTA : on rentre chez soi et on ressort avec
## une autre tête. Le choix est gardé (`Session`), donc il vaut aussi pour les
## manches suivantes et pour le hub.
##
## ⚠ Le changement PART SUR LE RÉSEAU une fois, à l'instant du changement, et
## pas dans le message de position : celui-là part douze fois par seconde, et y
## glisser une clé de personnage coûterait cent fois le prix de l'information.
func _changer_de_tenue() -> void:
	var liste := Personnages.LISTE
	var actuel := Session.personnage_affiche()
	var rang := 0
	for k in liste.size():
		if String(liste[k]["cle"]) == actuel:
			rang = k
	var suivant := String(liste[(rang + 1) % liste.size()]["cle"])
	Session.definir_personnage(suivant)
	_habiller(_corps_pied, suivant)
	_dire_affaire(String(liste[(rang + 1) % liste.size()]["nom"]))
	Sons.jouer("portail", 1.3, -10.0)
	canal.envoyer("tenue", {"j": Session.cle, "p": suivant})

## La peau se change SUR LE PANTIN DÉJÀ POSÉ : le rebâtir couperait la
## démarche en cours et rechargerait le squelette pour rien.
func _habiller(porteur: Node3D, cle: String) -> void:
	if porteur == null:
		return
	var silhouette := porteur.get_node_or_null("Silhouette") as Node3D
	if silhouette != null:
		Personnages.habiller(silhouette, cle)

## L'appartement qu'on trouve ICI : c'est le QUARTIER qui décide
## (`Interieurs.pour_quartier`), donc la réponse est la même chez tout le monde
## et rien ne circule sur le réseau.
func _logement_ici() -> String:
	var pate := PlanVille.pate_de(int(_position.x / PlanVille.PAS), int(_position.y / PlanVille.PAS))
	return Interieurs.pour_quartier(carte.quartier_du_pate(pate))

func _nom_du_logement() -> String:
	return String(Interieurs.CATALOGUE[_logement_ici()]["nom"])

func _resume_du_logement() -> String:
	return String(Interieurs.CATALOGUE[_logement_ici()]["resume"])

func _acheter_la_planque(id: int, prix: int) -> void:
	if _argent < prix:
		_dire_affaire("il vous manque $%d" % (prix - _argent))
		return
	_argent -= prix
	_planque = id
	_dire_affaire("planque achetée — rentrez y mettre votre argent")
	Sons.jouer("portail", 1.0, -6.0)
	canal.envoyer("planque", {"j": Session.cle, "i": id})

func _traiter_chez_soi(suivante: String) -> void:
	if _argent > 0:
		var depose := _argent
		_banque += depose
		_argent = 0
		_dire_affaire("$%d à l'abri" % depose)
		Sons.jouer("depart", 1.4, -8.0)
		return
	if suivante == "":
		_dire_affaire("rien à améliorer ici")
		return
	var prix := int(PlanVille.PRIX_AMELIORATION[suivante])
	if _banque < prix:
		_dire_affaire("il manque $%d au coffre" % (prix - _banque))
		return
	_banque -= prix
	_ameliorations[suivante] = true
	_dire_affaire("%s installé" % _libelle_amelioration(suivante))
	Sons.jouer("portail", 1.2, -6.0)

## L'ordre des travaux : le coffre d'abord (il double ce qu'on garde), puis
## l'arsenal (on ne perd plus son arme), puis le garage (on garde sa voiture).
func _amelioration_suivante() -> String:
	for cle in ["coffre", "arsenal", "garage"]:
		if not bool(_ameliorations[cle]):
			return cle
	return ""

func _libelle_amelioration(cle: String) -> String:
	match cle:
		"coffre": return "coffre"
		"arsenal": return "arsenal"
		"garage": return "garage"
	return cle

func _se_faire_soigner() -> void:
	if _argent < SOIN:
		_dire_affaire("il vous manque $%d" % (SOIN - _argent))
		return
	_argent -= SOIN
	_vie = VIE_MAX
	_dire_affaire("recousu")
	Sons.jouer("depart", 1.2, -8.0)

## Le véhicule qu'on ramène chez soi est rangé au garage : après la mort, on
## repart avec — c'est ce qui donne envie de garder la même voiture.
func _ranger_le_vehicule() -> void:
	if not bool(_ameliorations["garage"]) or _pied or _modele_vehicule < 0:
		return
	if _garage_perso != _modele_vehicule:
		_garage_perso = _modele_vehicule
		_dire_affaire("véhicule rangé au garage")

func _dire_affaire(texte: String) -> void:
	_mot_affaire = texte
	_mot_affaire_reste = 2.6

## Un gain d'argent : ce qui compte au classement reste la fortune, mais
## l'argent frais est SUR SOI — donc perdable.
func _encaisser_argent(montant: int) -> void:
	_argent = max(0, _argent + montant)

# ------------------------------------------------------- armes

func _tirer(delta: float) -> void:
	_recharge = max(0.0, _recharge - delta)
	# Au volant, la mitrailleuse de bord passe DEVANT l'arme de poing : elle a
	# ses propres munitions (infinies) et sa propre cadence.
	var montee := not _pied and bool(_mods.get("mitrailleuse", false))
	var arme := "canon" if montee else _arme
	if _hors_service > 0.0 or arme == "" or arme == "eperon" or (not montee and _munitions == 0) or _recharge > 0.0:
		return
	if not Commandes.tir():
		return
	var fiche: Dictionary = ARMES[arme]
	_recharge = float(fiche["cadence"])
	if _munitions > 0 and not montee:
		_munitions -= 1
	var depart := _position + Vector2.RIGHT.rotated(_angle) * (40.0 if not _pied else 24.0)
	canal.envoyer("tir", {"x": int(depart.x), "y": int(depart.y),
		"a": snapped(_angle, 0.01), "arme": arme})
	_creer_projectile(depart, _angle, arme, Session.cle)
	Sons.jouer(String(SONS_ARMES.get(arme, "tir_pistolet")),
		_rng.randf_range(0.97, 1.05), -10.0)
	# Tirer en ville, ça s'entend. La police n'a pas besoin de voir le corps.
	if est_hote():
		ville.crime(Session.cle, "coup_de_feu")
		ville.paniquer(_position, 320.0, 2.2)
		_vider_les_evenements()
	if _munitions == 0 and not montee:
		_reprendre_le_pistolet()

func _reprendre_le_pistolet() -> void:
	_arme = "pistolet"
	_munitions = -1

func _creer_projectile(depart: Vector2, angle: float, arme: String, par: String) -> void:
	var fiche: Dictionary = ARMES.get(arme, ARMES["pistolet"])
	var couleur: Color = fiche["couleur"]
	var noeud := Decor.sphere(0.5 if arme != "roquette" else 0.9, couleur, false)
	noeud.material_override = Decor.matiere_lumineuse(couleur, 1.25)
	noeud.position = Decor.vers3d(depart, 1.4)
	monde().add_child(noeud)
	_projectiles.append({
		"p": depart, "v": Vector2.RIGHT.rotated(angle) * float(fiche["vitesse"]),
		"restant": float(fiche["portee"]), "par": par, "arme": arme, "noeud": noeud,
	})

func _avancer_projectiles(delta: float) -> void:
	var restants: Array = []
	for tir in _projectiles:
		var pas: Vector2 = (tir["v"] as Vector2) * delta
		tir["p"] = (tir["p"] as Vector2) + pas
		tir["restant"] = float(tir["restant"]) - pas.length()
		var dans_un_mur := carte.dans_un_batiment(tir["p"])
		var mort: bool = float(tir["restant"]) <= 0.0 or dans_un_mur
		# La balle qui mord la pierre s'entend même chez celui qui ne l'a pas
		# tirée : c'est ce qui dit d'où ça vient quand on ne voit rien.
		if dans_un_mur and String(tir["arme"]) != "roquette":
			var loin: float = (tir["p"] as Vector2).distance_to(_position)
			if loin < 900.0:
				Sons.jouer("balle_mur", _rng.randf_range(0.9, 1.15), -14.0 - loin * 0.012)
		if est_hote() and dans_un_mur:
			# La balle écaille le mur, la roquette le creuse : l'hôte décide
			# quels cubes partent, et le dit à tous.
			ville.impacter(tir["p"], String(tir["arme"]))
			_vider_les_evenements()
		if est_hote() and not mort:
			mort = _resoudre_impact(tir)
		if mort:
			if String(tir["arme"]) == "roquette":
				_effet_explosion(tir["p"])
			(tir["noeud"] as Node3D).queue_free()
			continue
		(tir["noeud"] as Node3D).position = Decor.vers3d(tir["p"], 1.4)
		restants.append(tir)
	_projectiles = restants

## Seul l'hôte tranche : lui seul voit toute la ville à la même date.
func _resoudre_impact(tir: Dictionary) -> bool:
	var point: Vector2 = tir["p"]
	var par := String(tir["par"])
	var fiche: Dictionary = ARMES.get(String(tir["arme"]), ARMES["pistolet"])
	var souffle := float(fiche["souffle"])

	for personne in ville.gens:
		if (personne["p"] as Vector2).distance_to(point) <= VilleVivante.RAYON_PIETON + 12.0:
			ville.abattre_par_id(int(personne["id"]), par, souffle)
			_vider_les_evenements()
			return true

	for auto in ville.autos:
		if int(auto["genre"]) == VilleVivante.EPAVE or String(auto["pilote"]) != "":
			continue
		if (auto["p"] as Vector2).distance_to(point) > VilleVivante.RAYON_AUTO + 12.0:
			continue
		auto["pv"] = float(auto["pv"]) - float(fiche["degat"])
		if float(auto["pv"]) <= 0.0:
			ville.detruire_auto(auto, par)
		_vider_les_evenements()
		return true
	# Une voiture dormante touchée se réveille cabossée : à partir de là, elle
	# est diffusée comme les autres et finira en épave si on insiste.
	for d in ville.dormantes_endormies(point, VilleVivante.RAYON_AUTO + 12.0):
		var reveillee := ville.reveiller(int(d["id"]))
		if reveillee.is_empty():
			continue
		reveillee["pv"] = float(reveillee["pv"]) - float(fiche["degat"])
		if float(reveillee["pv"]) <= 0.0:
			ville.detruire_auto(reveillee, par)
		_vider_les_evenements()
		return true

	# Le tir ami n'existe QUE dans une arène, et seulement si le coup PART
	# d'une arène et arrive dans la même. Sans cette condition, un tireur
	# posté dehors nettoierait l'esplanade sans jamais y entrer.
	var arene := carte.arene_de(point)
	if arene >= 0:
		var etats := _etats_des_joueurs()
		for cle in etats:
			if String(cle) == par:
				continue
			var etat: Dictionary = etats[cle]
			if int(etat.get("arene", -1)) != arene:
				continue
			if Vector2(etat["p"]).distance_to(point) > RAYON_VOITURE + 12.0:
				continue
			ville.emettre("deg", {"j": cle, "d": int(fiche["degat"]),
				"k": "joueur", "par": par})
			_vider_les_evenements()
			return true
	return false

func _ramasser_caisses() -> void:
	for caisse in ville.caisses:
		if (caisse["p"] as Vector2).distance_to(_position) > 52.0:
			continue
		canal.envoyer("ramasse", {"id": int(caisse["id"])})
		if est_hote():
			var arme := ville.retirer_caisse(int(caisse["id"]), Session.cle)
			if arme != "":
				_accorder(Session.cle, arme)
			_vider_les_evenements()
		return

## LES À-CÔTÉS se ramassent PLUS LARGE qu'une caisse (52 px) : on les prend en
## voiture, souvent à pleine vitesse, et un rayon de cinquante pixels se
## traverse entre deux images à trois cents pixels par seconde.
const PORTEE_A_COTE := 78.0

func _ramasser_les_a_cotes() -> void:
	for r in ville.ramassages:
		if (r["p"] as Vector2).distance_to(_position) > PORTEE_A_COTE:
			continue
		canal.envoyer("acote", {"id": int(r["id"]), "x": int(_position.x), "y": int(_position.y)})
		if est_hote():
			ville.ramasser_a_cote(int(r["id"]), Session.cle, _position)
			_vider_les_evenements()
		return

## UN FRÔLEMENT : à pleine vitesse, au ras d'une voiture QUI ROULE, sans la
## toucher. La fenêtre est étroite par construction — entre le rayon de choc
## (38 px, au-delà on s'est percutés) et 54.
##
## ⚠ Chaque voiture ne compte qu'UNE FOIS par passage : sans la mémoire des
## identifiants, longer une file de voitures à l'arrêt rapportait quinze
## primes par seconde.
func _compter_les_frolements() -> void:
	if _pied or _hors_service > 0.0 or abs(_vitesse) < VITESSE_FROLEMENT:
		return
	for auto in ville.autos:
		if String(auto.get("pilote", "")) != "" or int(auto["genre"]) == VilleVivante.EPAVE:
			continue
		if bool(auto.get("garee", false)) or abs(float(auto.get("vitesse", 0.0))) < 60.0:
			continue
		var id := int(auto["id"])
		if temps - float(_froles.get(id, -99.0)) < 2.5:
			continue
		var loin: float = (auto["p"] as Vector2).distance_to(_position)
		if loin > RAYON_FROLEMENT or loin <= VilleVivante.CHOC_AUTO:
			continue
		_froles[id] = temps
		_cascade = min(_cascade + 1, CASCADE_MAX) if _cascade_reste > 0.0 else 1
		_cascade_reste = FENETRE_CASCADE
		var prime := PRIME_FROLEMENT * _cascade
		canal.envoyer("payer", {"m": prime, "q": "cascade",
			"x": int(_position.x), "y": int(_position.y)})
		if est_hote():
			ville.payer(Session.cle, _position, prime, "cascade")
			_vider_les_evenements()
		_dire_affaire("frôlement ×%d" % _cascade if _cascade > 1 else "frôlement")
		Sons.jouer("derapage", 1.2, -13.0)
		return

# ------------------------------------------------------- la triche
#
## LES CODES. Chacun est une ligne du menu : un nom, ce qu'il fait, et s'il
## s'agit d'un interrupteur (blindage, nuit) ou d'un coup unique (le magot).
##
## ⚠ Ils passent par les MÊMES fonctions que le jeu : le magot appelle
## `_encaisser_argent`, l'arsenal appelle `_equiper`, le char appelle
## `_naitre_auto`. Un code qui écrirait directement dans les variables
## finirait par mentir — c'est ainsi qu'on se retrouve avec de l'argent que la
## planque ne peut pas ranger.
func _codes_de_triche() -> Array:
	return load("res://ui/triche.gd").codes_neufs()

## `saisie` est le drapeau du tchat du village : il coupe les commandes de jeu
## sans toucher au reste. Un menu ouvert ne doit pas conduire.
##
## ⚠ IL Y A MAINTENANT TROIS MENUS (la pause, la triche, la supérette) et ils
## peuvent se superposer. Chacun écrivait `saisie = <le mien>` : en fermer un
## rendait les commandes alors qu'un autre était encore ouvert, et l'on
## conduisait à travers l'écran. Un seul endroit fait la somme.
func _regler_la_saisie() -> void:
	Commandes.saisie = _pause_ouverte or _triche_ouverte or _superette_ouverte

func _basculer_la_triche() -> void:
	_triche_ouverte = not _triche_ouverte
	if _triche_vue:
		_triche_vue.visible = _triche_ouverte
		_triche_vue.queue_redraw()
	_regler_la_saisie()
	if _triche_ouverte:
		Sons.jouer("portail", 0.6, -6.0)
	else:
		_triche_avant = {}

## Les touches du menu, lues au FRONT — une flèche tenue ne doit pas défiler
## dix lignes par seconde.
func _naviguer_dans_la_triche() -> void:
	if _triche_vue == null:
		return
	var codes: Array = _triche_vue.codes
	if _front_de_triche(KEY_UP):
		_triche_vue.choix = posmod(int(_triche_vue.choix) - 1, codes.size())
	if _front_de_triche(KEY_DOWN):
		_triche_vue.choix = posmod(int(_triche_vue.choix) + 1, codes.size())
	if _front_de_triche(KEY_ENTER) or _front_de_triche(KEY_KP_ENTER) or _front_de_triche(KEY_SPACE):
		_activer_le_code(int(_triche_vue.choix))
	if _front_de_triche(KEY_ESCAPE):
		_basculer_la_triche()
	_triche_vue.queue_redraw()

## ⚠ UN SECOND JEU DE FRONTS, et c'est indispensable. `_front_de_triche`
## mémorise l'état précédent de chaque touche dans `_triche_avant` ; la boucle
## la consulte pour ÉCHAP AVANT que les menus ne la consultent pour se fermer.
## Un seul jeu, et le premier lecteur avalait le front : la pause s'ouvrait, le
## menu de triche ne se fermait plus, ou l'inverse selon l'ordre des lignes.
var _pause_avant: Dictionary = {}

func _front_de_pause(code: int) -> bool:
	var maintenant := Input.is_key_pressed(code)
	var front: bool = maintenant and not bool(_pause_avant.get(code, false))
	_pause_avant[code] = maintenant
	return front

func _front_de_triche(code: int) -> bool:
	var maintenant := Input.is_key_pressed(code)
	var front: bool = maintenant and not bool(_triche_avant.get(code, false))
	_triche_avant[code] = maintenant
	return front

func _activer_le_code(indice: int) -> void:
	var codes: Array = _triche_vue.codes
	var code: Dictionary = codes[indice]
	var quoi := String(code["cle"])
	if bool(code["unique"]) and bool(code["actif"]) and quoi in ["char"]:
		pass    # le char se rappelle autant de fois qu'on veut
	code["actif"] = true if bool(code["unique"]) else not bool(code["actif"])
	_signaler_la_triche()
	match quoi:
		"blindage":
			_invincible = bool(code["actif"])
		"arsenal":
			_equiper("roquette")
		"magot":
			_encaisser_argent(50000)
		"casier":
			canal.envoyer("garage", {"i": -1})
			if est_hote():
				ville.repeindre(Session.cle)
				_vider_les_evenements()
		"traque":
			if est_hote():
				ville.chaleur[Session.cle] = ville.chaleur_pour(VilleVivante.PALIERS.size())
				ville.crime(Session.cle, "coup_de_feu")
				_vider_les_evenements()
			else:
				_dire_affaire("il faut être l'hôte pour ça")
		"atelier":
			_mods = {"mitrailleuse": true, "mines": 9, "huile": 9, "bombe": true}
			_plaques = DUREE_PLAQUES
			canal.envoyer("mod", {"m": "plaques", "d": DUREE_PLAQUES})
			if est_hote():
				ville.plaques[Session.cle] = DUREE_PLAQUES
				_vider_les_evenements()
		"ami", "ennemi":
			if est_hote():
				var valeur := 100.0 if quoi == "ami" else 0.0
				var jauge: Array = []
				for _g in PlanVille.GANGS.size():
					jauge.append(valeur)
				ville.respect[Session.cle] = jauge
				ville._diffuser_respect(Session.cle)
				_vider_les_evenements()
			else:
				_dire_affaire("il faut être l'hôte pour ça")
		"char":
			if est_hote():
				ville._naitre_auto(_etats_des_joueurs(), VilleVivante.PATROUILLE,
					Session.cle, VilleVivante.CORPS_ARMEE, true)
				_vider_les_evenements()
			else:
				_dire_affaire("il faut être l'hôte pour ça")
		"nuit":
			# `nuit_forcee` est le réglage du banc de photo : on s'en sert ici
			# pour arrêter l'horloge, et `-1` la rend au cycle.
			MatieresCarnage.nuit_forcee = 0.9 if bool(code["actif"]) else -1.0
		"meteo":
			# Chaque allumage passe au temps SUIVANT (clair, couvert, pluie,
			# orage, brouillard) et l'annonce ; éteint, le ciel revient à
			# l'horloge. Cinq codes pour cinq temps auraient noyé la liste.
			if bool(code["actif"]):
				MeteoCarnage.meteo_forcee = posmod(MeteoCarnage.meteo_forcee + 1, MeteoCarnage.NOMS.size())
				_annoncer(MeteoCarnage.nom_du_temps(MeteoCarnage.meteo_forcee).to_upper(), Palette.SERIE, 2.0)
			else:
				MeteoCarnage.meteo_forcee = -1
		"garde_manger":
			# Un de chaque dans les poches, le reste au frigo : c'est la façon
			# la plus rapide de voir l'inventaire, la touche `G` et le choix de
			# `Provisions.le_mieux` sans faire trois fois le tour de la ville.
			_provisions = {}
			_frigo = {}
			for a in Provisions.CATALOGUE:
				if Provisions.compte(_provisions) < Provisions.POCHES:
					Provisions.ajouter(_provisions, String(a["cle"]))
				Provisions.ajouter(_frigo, String(a["cle"]), 3)
		"festin":
			_faim = FAIM_MAX
			_soif = FAIM_MAX
			_vie = VIE_MAX
		"flotte":
			# Une voiture de gang, donc ARMÉE (§1.3) : on se retrouve au volant
			# avec la mitrailleuse de toit, ce qui demande sinon de trouver un
			# repaire et d'en voler une.
			_prendre_le_volant(ID_VOITURE_GARAGE + _place, VilleVivante.VOITURE_GANG,
				carte.degager(_position, RAYON_VOITURE)[0], _angle, PV_VOITURE,
				FormesCarnage.MODELE_POLICE)
		"clefs":
			# TOUS les repaires du secteur passent à vous. C'est le seul moyen
			# de voir un tag changer de camp sans mener cinq raids — et c'est
			# exactement ce pour quoi un menu de triche existe.
			if est_hote():
				var pris := 0
				for r in carte.lieux_autour(_position, PlanVille.SECTEUR * PlanVille.PAS * 1.5)["repaires"]:
					if int(r["gang"]) < 0 or ville.repaires_pris.has(int(r["id"])):
						continue
					ville.repaires_pris[int(r["id"])] = {"j": Session.cle, "gang": int(r["gang"])}
					pris += 1
				_vider_les_evenements()
				_dire_affaire("%d repaire(s) à vous" % pris)
			else:
				_dire_affaire("il faut être l'hôte pour ça")
		"express":
			# La rame la plus proche se gare ici. Un train passe toutes les
			# vingt secondes quelque part sur une ligne de soixante-dix mille
			# pixels : l'attendre au bon endroit, c'est un quart d'heure.
			if est_hote():
				var court := 1.0e12
				var rame := {}
				for t in ville.trains:
					var d: float = ville.point_de_voie(float(t["s"])).distance_to(_position)
					if d < court:
						court = d
						rame = t
				if not rame.is_empty():
					var v := ville.voie()
					rame["s"] = (_position - Vector2(v["o"])).dot(Vector2(v["d"]))
					rame["v"] = 0.0
					rame["arret"] = VilleVivante.ARRET_EN_GARE * 3.0
					_vider_les_evenements()
			else:
				_dire_affaire("il faut être l'hôte pour ça")
		"immobilier":
			# La planque la plus proche, offerte, avec ses trois améliorations :
			# le coffre, l'arsenal et le garage demandent sinon deux cent mille
			# dollars, c'est-à-dire une manche entière.
			var pl := carte.planque_de(_position)
			if pl >= 0:
				_planque = pl
				canal.envoyer("planque", {"j": Session.cle, "i": pl})
			for amelioration in _ameliorations:
				_ameliorations[amelioration] = true
			_dire_affaire("planque et améliorations" if pl >= 0 else "améliorations — il manque la planque")
		"fantome":
			# ⚠ CE N'EST PAS LE CASIER VIERGE : celui-là efface les étoiles une
			# fois, celui-ci les EMPÊCHE de monter, comme les plaques de
			# l'atelier mais sans fin. C'est ce qu'il faut pour visiter la
			# ville sans être interrompu toutes les trente secondes.
			if est_hote():
				ville.plaques[Session.cle] = 1.0e9 if bool(code["actif"]) else 0.0
				ville.chaleur[Session.cle] = 0.0
				_vider_les_evenements()
			else:
				canal.envoyer("mod", {"m": "plaques", "d": 1.0e9 if bool(code["actif"]) else 0.0})
	_annoncer(String(code["nom"]).split(" — ")[0], Palette.CRITIQUE, 2.0)
	Sons.jouer("bonus", 0.8, -8.0)

## Le prix de la triche : la manche ne compte plus POUR SOI. On le dit une
## fois, à l'écran, et on l'envoie à l'hôte — c'est lui qui dépose les scores.
func _signaler_la_triche() -> void:
	if tricheurs.has(Session.cle):
		return
	tricheurs[Session.cle] = true
	canal.envoyer("triche", {"j": Session.cle})
	_dire_affaire("triche activée — la manche ne comptera pas")

# ------------------------------------------------------- l'autoradio

## LA ROUE. Tenue, elle vise ; relâchée, elle change de station. Elle ne
## s'ouvre qu'au volant : à pied, l'autoradio est éteint et il n'y a rien à
## choisir.
func _tenir_la_roue() -> void:
	# ⚠ AUCUN MENU OUVERT. La roue se TIENT (elle n'a pas de front) : ouverte
	# par-dessus la pause, elle rendait les commandes en se refermant.
	var voulue := not _pied and _hors_service <= 0.0 and not _triche_ouverte \
		and not _pause_ouverte and not _superette_ouverte and Commandes.radio_tenue()
	if voulue and not _roue:
		_roue = true
		_roue_choix = _station
		Commandes.saisie = true      # la voiture roule, mais ne braque plus
		Sons.jouer("bonus", 1.9, -20.0)
	elif not voulue and _roue:
		_roue = false
		# ⚠ On ne REND pas les commandes, on recalcule : un menu peut être
		# ouvert par-dessus, et `saisie = false` en sortant de la roue faisait
		# conduire à travers le menu de pause.
		_regler_la_saisie()
		_changer_de_station(_roue_choix)
	if _roue:
		_viser_dans_la_roue()
	if _roue_vue:
		_roue_vue.visible = _roue
		if _roue:
			_roue_vue.choix = _roue_choix
			_roue_vue.actuelle = _station
			_roue_vue.queue_redraw()

## Le secteur visé, tiré de la direction poussée. ⚠ On lit les touches
## DIRECTEMENT : `Commandes.direction` est coupée par `saisie`, que la roue
## vient justement de lever pour empêcher la voiture de braquer.
func _viser_dans_la_roue() -> void:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Reglages.enfoncee("avancer"): d.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Reglages.enfoncee("reculer"): d.y += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Reglages.enfoncee("gauche"): d.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Reglages.enfoncee("droite"): d.x += 1.0
	if d.length() < 0.4:
		return                        # rien de poussé : on garde ce qu'on vise
	# Zéro EN HAUT, puis dans le sens des aiguilles : c'est l'ordre de la table
	# des stations, donc celui que le joueur finit par connaître par cœur.
	var angle := atan2(d.x, -d.y)
	var pas := TAU / float(Sons.STATIONS.size())
	_roue_choix = posmod(int(round(angle / pas)), Sons.STATIONS.size())

## On monte : la radio s'allume sur la station de la carrosserie. On descend :
## elle s'éteint — un autoradio qui continue de jouer pendant qu'on court dans
## la rue, c'est une bande-son, pas une radio.
func _allumer_la_radio(modele: int) -> void:
	_changer_de_station(Sons.station_du_modele(modele), true)

func _eteindre_la_radio() -> void:
	_station = Sons.STATION_SILENCE
	_station_dite = 0.0
	Sons.musique("")

func _changer_de_station(indice: int, discret: bool = false) -> void:
	_station = posmod(indice, Sons.STATIONS.size())
	var station: Dictionary = Sons.STATIONS[_station]
	Sons.musique(String(station["piste"]), RADIO_DB)
	# Trois secondes de nom à l'écran : c'est une radio, on veut savoir sur
	# quoi on est tombé, et ensuite on l'oublie.
	_station_dite = 3.0
	if not discret:
		Sons.jouer("bonus", 1.6, -18.0)

func _accorder(cle: String, arme: String) -> void:
	canal.envoyer("arme", {"j": cle, "arme": arme})
	if cle == Session.cle:
		_equiper(arme)

func _equiper(arme: String) -> void:
	if arme == "eperon":
		_eperon = DUREE_EPERON
	elif arme == "vie":
		_vie = min(VIE_MAX, _vie + SOIN_TROUSSE)
	elif arme == "argent":
		pass    # compté par l'hôte, arrive par « k »
	else:
		_arme = arme
		_munitions = int(ARMES[arme]["munitions"])
	Sons.jouer("depart", 1.0, -8.0)

func seuil_ecrasement() -> float:
	return VilleVivante.SEUIL_EPERON if _eperon > 0.0 else VilleVivante.SEUIL_ECRASEMENT

# ------------------------------------------------------- simulation hôte

func simuler_hote(delta: float) -> void:
	ville.reprendre_la_main()
	var etats := _etats_des_joueurs()
	ville.simuler(delta, temps, etats)
	_vider_les_evenements()

	_depuis_instantane += delta
	if _depuis_instantane >= CADENCE_INSTANTANE:
		_depuis_instantane = 0.0
		# L'instantané se cadre sur TOUS les joueurs, morts compris : `etats`
		# exclut ceux qui sont à terre (pour qu'on ne les touche pas), et quand
		# tout le monde était à terre en même temps, l'instantané partait vide
		# et la ville disparaissait chez les clients le temps de se relever.
		var regards := etats.duplicate()
		if not regards.has(Session.cle):
			regards[Session.cle] = {"p": _position}
		for cle in _autres:
			if not regards.has(cle):
				regards[cle] = {"p": _autres[cle]["p"]}
		canal.envoyer("n", ville.instantane(regards))

## Ce que l'hôte sait de chacun. Il ne le déduit jamais : chaque client annonce
## sa position, et l'hôte s'en contente. Le contraire — un hôte qui replacerait
## les autres — ferait cahoter la voiture de tout le monde sauf la sienne.
func _etats_des_joueurs() -> Dictionary:
	var etats: Dictionary = {}
	if _hors_service <= 0.0:
		etats[Session.cle] = {
			"p": _position, "a": _angle, "v": _vitesse, "vie": _vie,
			"pied": _pied, "seuil": seuil_ecrasement(),
			# ⚠ Sans ce drapeau, la rame FAUCHE SON PROPRE PASSAGER : il est
			# pile sous elle, c'est la définition d'un voyage.
			"train": _train >= 0,
			"arene": carte.arene_de(_position), "d": Vector2.RIGHT.rotated(_angle),
		}
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		if int(a.get("etat", 1)) == 2 or float(a.get("vie", VIE_MAX)) <= 0.0:
			continue
		etats[cle] = {
			"p": a["p"], "a": float(a["a"]), "v": float(a.get("v", 0.0)),
			"vie": float(a.get("vie", VIE_MAX)), "pied": bool(a.get("pied", false)),
			"train": bool(a.get("train", false)),
			"seuil": VilleVivante.SEUIL_EPERON if bool(a.get("eperon", false)) \
				else VilleVivante.SEUIL_ECRASEMENT,
			"arene": carte.arene_de(a["p"]),
			"d": Vector2.RIGHT.rotated(float(a["a"])),
		}
	return etats

## Les décisions de l'hôte partent sur le réseau ET s'appliquent chez lui :
## `broadcast.self` est à faux, il ne recevra pas ses propres messages.
## ⚠ Les événements d'une même image partent en UN seul message (`lot`). Le
## serveur temps réel limite le nombre de messages par seconde sur un canal ;
## à trois étoiles, chaque coup de feu de flic (`tn`), chaque dégât, chaque
## point faisaient un message, et l'hôte dépassait la limite : le serveur
## fermait le socket (code 1000), l'écran passait « hors ligne » et la ville
## se figeait chez les autres. Vu dans le navigateur, jamais au banc natif.
func _vider_les_evenements() -> void:
	if ville.sortants.is_empty():
		return
	var lot: Array = ville.sortants.duplicate()
	ville.sortants.clear()
	if lot.size() == 1:
		canal.envoyer(String(lot[0]["e"]), lot[0]["c"])
	else:
		var paquet: Array = []
		for evenement in lot:
			paquet.append([String(evenement["e"]), evenement["c"]])
		canal.envoyer("lot", {"l": paquet})
	for evenement in lot:
		_appliquer(String(evenement["e"]), evenement["c"])

# ------------------------------------------------------- réception

func recevoir(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"j":
			_recevoir_joueur(charge)
		"tenue":
			# Quelqu'un s'est changé chez lui. On ne rebâtit pas son pantin :
			# on lui change la peau là où il est.
			var qui := String(charge.get("j", ""))
			if qui != Session.cle and _autres.has(qui):
				_habiller(_autres[qui]["pieton"] as Node3D, String(charge.get("p", "")))
		"n":
			if not est_hote():
				ville.appliquer_instantane(charge)
		"tir":
			if String(charge.get("cle", "")) == Session.cle:
				return
			if est_hote():
				ville.crime(String(charge.get("cle", "")), "coup_de_feu")
				ville.paniquer(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))), 320.0, 2.2)
				_vider_les_evenements()
			_creer_projectile(
				Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				float(charge.get("a", 0.0)), String(charge.get("arme", "pistolet")),
				String(charge.get("cle", "")))
		"monte":
			if est_hote():
				ville.accorder_vehicule(String(charge.get("cle", "")), int(charge.get("id", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))))
				_vider_les_evenements()
		"sort":
			if est_hote():
				ville.rendre_vehicule(String(charge.get("cle", "")), int(charge.get("id", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					float(charge.get("a", 0.0)), float(charge.get("pv", PV_VOITURE)),
					int(charge.get("m", -1)), int(charge.get("g", VilleVivante.CIVILE)),
					int(charge.get("t", 0)))
				_vider_les_evenements()
		"terrain":
			if est_hote():
				ville.tenir_le_terrain(String(charge.get("cle", "")), int(charge.get("i", -1)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					int(charge.get("g", -1)))
				_vider_les_evenements()
		"raid":
			var qui := String(charge.get("j", ""))
			var gang_r := int(charge.get("g", -1))
			match String(charge.get("e", "")):
				"ouvre":
					if qui == Session.cle:
						_annoncer("RAID SUR %s — %d hommes" % [
							carte.nom_du_gang(gang_r).to_upper(), int(charge.get("n", 0))],
							Palette.CRITIQUE, 3.0)
						Sons.jouer("bip", 0.7, -8.0)
				"avance":
					if qui == Session.cle and int(charge.get("n", 0)) <= 2:
						_annoncer("encore %d" % int(charge.get("n", 0)), Palette.SERIEUX, 1.6)
				"perdu":
					if qui == Session.cle:
						_annoncer("raid abandonné", Palette.ENCRE_FAIBLE, 2.0)
				"pris":
					# LE REPAIRE TOMBE. On repeint le tag chez TOUT LE MONDE —
					# c'est le seul endroit de la ville qui change de main, et
					# un quartier qui change de camp sans que ça se voie, ça
					# n'est jamais arrivé.
					_reprendre_le_tag(int(charge.get("i", -1)), qui)
					if qui == Session.cle:
						_annoncer("REPAIRE PRIS — %s est chassé" % carte.nom_du_gang(gang_r).to_upper(),
							Palette.BON, 4.0)
						Sons.jouer("fin", 1.0, -6.0)
					else:
						_annoncer("%s a pris le repaire %s" % [String(joueurs.get(qui, {}).get("pseudo", "un joueur")),
							carte.du_gang(gang_r)], Palette.AVERTISSEMENT, 3.0)
		"rentrer":
			# Un joueur demande la fin. Seul l'hôte peut conclure (voir
			# `_quitter_la_ville`) — il diffusera le « fin » que tout le monde
			# reçoit, classement compris.
			if est_hote():
				terminer("%s rentre" % String(charge.get("p", "un joueur")))
		"broyer":
			# LA CASSE. Le client dit « je broie celle-ci », l'hôte tranche : la
			# voiture quitte la ville, la somme et le butin repartent dans un
			# « broye ». On ne laisse PAS le client se payer tout seul, c'est la
			# règle de tout le reste (les contrats, les caisses, les primes).
			if est_hote():
				ville.broyer(String(charge.get("cle", "")), int(charge.get("id", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))))
				_vider_les_evenements()
		"broye":
			var ou_casse := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			_effet_broyage(ou_casse)
			if String(charge.get("j", "")) == Session.cle:
				_argent += int(charge.get("m", 0))
				_dire_affaire("broyée — $%d, et de quoi se servir par terre" % int(charge.get("m", 0)))
				if Commandes.pilote_automatique:
					print("[banc] broyage : $%d, butin %s" % [int(charge.get("m", 0)),
						String(charge.get("b", ""))])
		"cabine":
			if est_hote():
				ville.proposer_contrat(String(charge.get("cle", "")), int(charge.get("i", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))))
				_vider_les_evenements()
		"garage":
			if est_hote():
				ville.repeindre(String(charge.get("cle", "")))
				_vider_les_evenements()
		"piege":
			if est_hote():
				ville.poser_piege(String(charge.get("cle", "")),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					int(charge.get("g", 0)))
				_vider_les_evenements()
		"bombe":
			if est_hote():
				ville.armer_bombe(String(charge.get("cle", "")), int(charge.get("id", 0)))
				_vider_les_evenements()
		"mod":
			if est_hote() and String(charge.get("m", "")) == "plaques":
				ville.plaques[String(charge.get("cle", ""))] = float(charge.get("d", 0.0))
				_vider_les_evenements()
		"triche":
			tricheurs[String(charge.get("j", ""))] = true
		"payer":
			if est_hote():
				ville.payer(String(charge.get("cle", "")),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					int(charge.get("m", 0)), String(charge.get("q", "prime")))
				_vider_les_evenements()
		"client":
			if est_hote():
				ville.embarquer_client(int(charge.get("id", -1)))
				_vider_les_evenements()
		"acote":
			if est_hote():
				ville.ramasser_a_cote(int(charge.get("id", -1)), String(charge.get("cle", "")),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))))
				_vider_les_evenements()
		"ramasse":
			if est_hote():
				var arme := ville.retirer_caisse(int(charge.get("id", -1)), String(charge.get("cle", "")))
				if arme != "":
					_accorder(String(charge.get("cle", "")), arme)
				_vider_les_evenements()
		"choc":
			if est_hote():
				ville.choquer(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					Vector2.RIGHT.rotated(float(charge.get("a", 0.0))), float(charge.get("v", 0)))
				_vider_les_evenements()
		"lot":
			for entree in charge.get("l", []):
				if typeof(entree) == TYPE_ARRAY and (entree as Array).size() == 2 and typeof(entree[1]) == TYPE_DICTIONARY:
					_appliquer(String(entree[0]), entree[1])
		_:
			_appliquer(evenement, charge)

func _appliquer(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"pris":
			var qui := String(charge.get("j", ""))
			# Une dormante prise par N'IMPORTE QUI sort de sa nappe : l'instantané
			# ne liste pas les voitures conduites, on ne l'apprendrait jamais
			# autrement — et on verrait un joueur rouler dans la copie d'une
			# voiture restée garée.
			var id_pris := int(charge.get("id", 0))
			if PlanVille.est_dormante(id_pris):
				ville.reveillees[id_pris] = true
				_effacer_la_dormante(id_pris)
			if qui == Session.cle:
				# LA VOITURE GARDE SA COULEUR quand on monte dedans : la peinture
				# du garage si elle en a une, la bannière du gang, sinon celle que
				# la nappe lui avait donnée. ⚠ Avant, une voiture volée
				# redevenait orange d'usine à l'instant où on ouvrait la porte.
				var g := int(charge.get("g", 0))
				_teinte = FormesCarnage.couleur_de_l_auto(carte, int(charge.get("m", 0)), id_pris,
					g == VilleVivante.VOITURE_GANG, int(charge.get("gg", 0)), int(charge.get("t", 0)))
				_prendre_le_volant(int(charge.get("id", 0)), int(charge.get("g", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					float(charge.get("a", 0.0)), float(charge.get("pv", PV_VOITURE)),
					int(charge.get("m", 0)))
		"arme":
			var beneficiaire := String(charge.get("j", ""))
			if beneficiaire == Session.cle:
				_equiper(String(charge.get("arme", "")))
			elif _autres.has(beneficiaire):
				_autres[beneficiaire]["eperon"] = String(charge.get("arme", "")) == "eperon"
		"deg":
			if String(charge.get("j", "")) == Session.cle:
				_encaisser(float(charge.get("d", 0)), String(charge.get("k", "")),
					String(charge.get("par", "")))
		"k":
			var tueur := String(charge.get("j", ""))
			if est_hote():
				ajouter_score(tueur, int(charge.get("p", 0)))
			if tueur == Session.cle:
				_encaisser_argent(int(charge.get("p", 0)))
			_effet_gain(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				int(charge.get("p", 0)), int(charge.get("f", 1)), tueur,
				String(charge.get("q", "")))
		"saisie":
			# Un joueur s'est fait ramasser : sa fortune baisse d'autant.
			if est_hote():
				ajouter_score(String(charge.get("j", "")), -int(charge.get("m", 0)))
		"feu":
			# L'hôte a allumé un foyer : chez le client, il ne s'agit que de le
			# dessiner — la vie du feu (propagation, dégâts) reste chez l'hôte.
			if not est_hote():
				ville.feux.append({"id": ville.prochain_id(), "f": float(charge.get("f", 100)) / 100.0,
					"p": Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					"force": float(charge.get("f", 100)) / 100.0, "t": 0.0,
					"propage": 99.0, "ronge": 99.0})
			Sons.jouer("choc", 0.55, -8.0)
		"eteint":
			if not est_hote():
				var ou_eteint := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
				var gardes: Array = []
				for f in ville.feux:
					if Vector2(f["p"]).distance_to(ou_eteint) > 40.0:
						gardes.append(f)
				ville.feux = gardes
		"secours":
			# Le Medicar est arrivé : on se relève tout de suite, à moitié
			# soigné. C'est ce qui rend l'ambulance utile plutôt que jolie.
			if String(charge.get("j", "")) == Session.cle and _hors_service > 0.0:
				_hors_service = min(_hors_service, 0.6)
				_vie = max(_vie, VIE_MAX * 0.5)
				_dire_affaire("le Medicar vous relève")
		"obus":
			# L'OBUS DU CHAR. Il n'a pas volé : l'hôte a déjà décidé où il
			# tombe et qui il abîme. Ici on ne fait que le montrer — et on le
			# montre GROS, parce qu'un souffle de cent vingt pixels qu'on ne
			# voit pas passe pour un bogue.
			var ou_obus := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			_effet_explosion(ou_obus)
			_effet_depart_de_coup(Vector2(float(charge.get("dx", 0)), float(charge.get("dy", 0))),
				(ou_obus - Vector2(float(charge.get("dx", 0)), float(charge.get("dy", 0)))).angle())
			# L'explosion est déjà sonnée par `_effet_explosion` : une seconde
			# détonation par-dessus s'entendait comme un écho de studio.
		"swat":
			if String(charge.get("j", "")) == Session.cle:
				_annoncer("ILS DESCENDENT DU FOURGON", Palette.CRITIQUE, 2.6)
				Sons.jouer("portiere_ferme", 0.8, -8.0)
		"boum":
			var ou_boum := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			_effet_explosion(ou_boum)
			if est_hote():
				ville.exploser(ou_boum)
				ville.allumer(ou_boum, 1.0)
				_vider_les_evenements()
		"casse":
			# Des cubes d'immeuble s'en vont : chez tout le monde, dans le décor
			# et dans la mémoire de la manche (un morceau rebâti plus tard doit
			# montrer la même ruine).
			var touches: Dictionary = {}
			for entree in charge.get("v", []):
				if typeof(entree) != TYPE_ARRAY or (entree as Array).size() != 2:
					continue
				var id := int(entree[0])
				touches[id] = true
				_casser_dans_le_decor(id, int(entree[1]))
			if Commandes.pilote_automatique:
				print("[banc] casse : %d cube(s) dans %d immeuble(s)" % [(charge.get("v", []) as Array).size(), touches.size()])
		"etoiles":
			ville.chaleur[String(charge.get("j", ""))] = ville.chaleur_pour(int(charge.get("r", 0)))
			if Commandes.pilote_automatique and String(charge.get("j", "")) == Session.cle:
				print("[banc] recherche : %d étoile(s)" % int(charge.get("r", 0)))
			# L'ESCALADE S'ANNONCE. Trois crans du guide changent la nature de
			# ce qui arrive, pas seulement le nombre : il faut le dire, sinon
			# le joueur découvre le char en le percutant.
			if String(charge.get("j", "")) == Session.cle:
				var cran := int(charge.get("r", 0))
				if cran > _etoiles_vues:
					match cran:
						VilleVivante.NIVEAU_SWAT:
							_annoncer("LE SWAT ARRIVE", Palette.CRITIQUE, 3.2)
						VilleVivante.NIVEAU_AGENTS:
							_annoncer("AGENTS SPÉCIAUX", Palette.CRITIQUE, 3.4)
						VilleVivante.NIVEAU_ARMEE:
							_annoncer("L'ARMÉE — UN CHAR VOUS CHERCHE", Palette.CRITIQUE, 4.5)
				_etoiles_vues = cran
		"resp":
			var valeurs = charge.get("v", [])
			if typeof(valeurs) == TYPE_ARRAY and (valeurs as Array).size() >= PlanVille.GANGS.size():
				var jauge: Array = []
				for v in valeurs:
					jauge.append(float(v))
				ville.respect[String(charge.get("j", ""))] = jauge
		"ctr":
			if String(charge.get("j", "")) != Session.cle:
				return
			var etat := String(charge.get("e", ""))
			if Commandes.pilote_automatique:
				print("[banc] contrat %s : %s" % [etat, String(charge.get("t", ""))])
			if etat == "gagne":
				_contrat = {}
				_cible_contrat = {}
				Sons.jouer("fin", 1.15, -5.0)
			elif etat == "perdu":
				_contrat = {}
				_cible_contrat = {}
				Sons.jouer("choc", 0.55, -12.0)
			elif etat == "refuse":
				# Le gang décroche et raccroche : sous quarante de respect, il
				# n'a rien à confier. Ce n'est pas une erreur, c'est la
				# réponse — et elle doit s'entendre, sinon on croit la cabine
				# cassée et on la rappelle dix fois.
				_annoncer(String(charge.get("t", "")), Palette.CRITIQUE, 2.6)
				Sons.jouer("choc", 0.75, -14.0)
			else:
				_contrat = {"t": String(charge.get("t", "")), "n": int(charge.get("n", 0)),
					"a": int(charge.get("a", 0)), "r": float(charge.get("r", 0))}
				_contrat_duree = max(_contrat_duree if int(charge.get("a", 0)) > 0 else 0.0, float(charge.get("r", 0)))
				_cible_contrat = {"k": String(charge.get("k", "")), "g": int(charge.get("g", -1))}
				if etat == "pris":
					Sons.jouer("portail", 1.3, -9.0)
		"klx":
			var ou := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			var loin: float = ou.distance_to(_position)
			if loin < 1300.0:
				Sons.jouer("klaxon", _rng.randf_range(0.9, 1.1), -12.0 - loin * 0.012)
			if est_hote():
				ville.paniquer(ou, 260.0, 1.6)
		"seme":
			if String(charge.get("j", "")) == Session.cle and ville.etoiles(Session.cle) >= 0:
				_annoncer("ils cherchent l'autre voiture", Palette.SERIE, 2.0)
		"helico":
			if Commandes.pilote_automatique:
				print("[banc] hélicoptère lancé sur %s" % String(charge.get("j", "")))
			if String(charge.get("j", "")) == Session.cle:
				_annoncer("HÉLICOPTÈRE — filez au garage", Palette.CRITIQUE, 4.0)
				Sons.jouer("sirene", 0.7, -6.0)
		"aide":
			# Un allié vient d'ouvrir le feu POUR vous. On l'annonce une fois
			# par salve (l'hôte espace les annonces) : sans le mot, on croit
			# à une fusillade entre PNJ et le respect ne se voit toujours pas.
			if String(charge.get("j", "")) == Session.cle:
				var gang_aide := int(charge.get("g", 0))
				_annoncer("%s vous prête main-forte" % carte.nom_du_gang(gang_aide),
					carte.couleur_du_gang(gang_aide), 2.4)
				Sons.jouer("portail", 1.5, -12.0)
		"glisse":
			# L'HUILE. On réutilise l'état « sonné » du choc : la voiture part
			# en toupie et ne répond plus une seconde. C'est exactement ce que
			# fait une flaque d'huile, et le joueur connaît déjà la sensation.
			if String(charge.get("j", "")) == Session.cle and not _pied and _sonne <= 0.0:
				_sonne = 1.0
				_dire_affaire("ça glisse !")
				Sons.jouer("choc", 0.5, -13.0)
		"colis":
			if String(charge.get("j", "")) == Session.cle:
				_colis = int(charge.get("n", 0))
				_colis_sur = int(charge.get("sur", 0))
				if bool(charge.get("fini", false)):
					_annoncer("LES %d COLIS — PRIME" % _colis_sur, Color("#f0c04a"), 4.0)
					Sons.jouer("fin", 1.3, -4.0)
				else:
					_dire_affaire("colis %d/%d" % [_colis, _colis_sur])
					Sons.jouer("bonus_pieton", 1.25, -8.0)
		"frenzy":
			if String(charge.get("j", "")) != Session.cle:
				return
			var etat_f := String(charge.get("e", ""))
			_frenzy = {} if etat_f in ["gagne", "perdu"] else {
				"a": String(charge.get("a", "")), "n": int(charge.get("n", 0)),
				"f": int(charge.get("f", 0)), "r": float(charge.get("r", 0))}
			match etat_f:
				"debut":
					# L'ARME VIENT AVEC LE DÉFI. Sans elle, le Frenzy consiste à
					# courir chercher une caisse et le chrono est fini avant de
					# commencer.
					_equiper(String(charge.get("a", "")))
					_annoncer("KILL FRENZY — %d en %d s" % [int(charge.get("n", 0)),
						int(charge.get("r", 0))], Palette.CRITIQUE, 3.0)
					Sons.jouer("portail", 0.7, -4.0)
				"gagne":
					_annoncer("FRENZY RÉUSSI", Palette.BON, 3.4)
					Sons.jouer("fin", 1.35, -4.0)
				"perdu":
					_annoncer("frenzy manqué — %d sur %d" % [int(charge.get("f", 0)),
						int(charge.get("n", 0))], Palette.ENCRE_FAIBLE, 2.6)
		"peint":
			if String(charge.get("j", "")) == Session.cle:
				Sons.jouer("fin", 1.2, -10.0)
		"tn":
			# Le coup de feu d'un PNJ : on le VOIT partir, mais il ne vole
			# pas. Quatre-vingts projectiles de plus à diffuser pour un
			# résultat que personne ne suit à l'œil, ça ne valait pas le prix.
			_effet_depart_de_coup(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				float(charge.get("a", 0.0)))
		"mort":
			# Une élimination ne compte que si elle a eu lieu dans une arène :
			# ailleurs, les joueurs ne peuvent pas se blesser, et une mort est
			# le fait de la ville — personne ne la porte à son tableau.
			if not est_hote():
				return
			var par := String(charge.get("par", ""))
			var victime := String(charge.get("j", ""))
			var ou := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			if par == "" or par == victime or carte.arene_de(ou) < 0:
				return
			ville.compter_frag(par, ou)
			_vider_les_evenements()

func _recevoir_joueur(charge: Dictionary) -> void:
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.cle:
		return
	var cible := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
	if not _autres.has(cle):
		var place := int(joueurs.get(cle, {}).get("place", 1))
		var pseudo := String(joueurs.get(cle, {}).get("pseudo", ""))
		var couleur := Palette.couleur_joueur(place)
		var auto := FormesCarnage.voiture(couleur, pseudo)
		auto.position = Decor.vers3d(cible)
		monde().add_child(auto)
		# Le personnage d'un autre joueur : celui que le salon annonce, sinon
		# celui que son identifiant désigne — le calcul est le même chez tous,
		# donc on le voit pareil des quatre côtés de la table.
		var perso := String(joueurs.get(cle, {}).get("personnage", ""))
		if not Personnages.existe(perso):
			perso = Personnages.par_defaut(cle)
		var pieton := FormesCarnage.pieton(couleur, false, pseudo, true, perso)
		pieton.visible = false
		monde().add_child(pieton)
		_autres[cle] = {"p": cible, "a": 0.0, "v": 0.0, "vie": VIE_MAX, "cible": cible,
			"angle_cible": 0.0, "pied": false, "etat": 1, "eperon": false, "modele": -1,
			"genre": VilleVivante.CIVILE, "auto": auto, "pieton": pieton}
	var a: Dictionary = _autres[cle]
	a["cible"] = cible
	a["angle_cible"] = float(charge.get("a", 0.0))
	a["v"] = float(charge.get("s", 0))
	a["vie"] = float(charge.get("h", VIE_MAX))
	a["etat"] = int(charge.get("e", 1))
	a["pied"] = int(charge.get("e", 1)) == 0
	a["genre"] = int(charge.get("vg", VilleVivante.CIVILE))
	a["eperon"] = int(charge.get("ep", 0)) == 1
	a["train"] = int(charge.get("tr", 0)) == 1
	a["mitrailleuse"] = int(charge.get("mg", 0)) == 1
	# Arrivé en retard, on n'a pas vu le « pris » : la voiture qu'il conduit
	# sort quand même de sa nappe.
	var w := int(charge.get("w", 0))
	if PlanVille.est_dormante(w) and not ville.reveillees.has(w):
		ville.reveillees[w] = true
		_effacer_la_dormante(w)
	var modele := int(charge.get("vm", -1))
	var teinte_recue := int(charge.get("tc", 0))
	if modele != int(a.get("modele", -1)) or teinte_recue != int(a.get("teinte", 0)):
		# Il a changé de voiture — ou de PEINTURE : on rebâtit la sienne. Le
		# nœud d'avant part.
		a["modele"] = modele
		a["teinte"] = teinte_recue
		(a["auto"] as Node3D).queue_free()
		var neuf := _batir_voiture_de(modele,
			Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))),
			String(joueurs.get(cle, {}).get("pseudo", "")),
			Color.hex(teinte_recue) if teinte_recue != 0 else Color.WHITE)
		neuf.position = Decor.vers3d(cible)
		monde().add_child(neuf)
		a["auto"] = neuf

# ------------------------------------------------------- dégâts

func _encaisser(degats: float, cause: String, par: String) -> void:
	if _hors_service > 0.0:
		return
	# BLINDAGE (triche). On sort ici et pas plus bas : la secousse, le bruit
	# et le ralentissement partent aussi. Un invincible qui se fait quand même
	# secouer l'écran à chaque balle ne se croit pas invincible.
	if _invincible:
		return
	_depuis_coup = 0.0
	if par != "":
		_dernier_agresseur = par
	_vie -= max(1.0, degats) * (FRAGILITE_A_PIED if _pied else 1.0)
	if not _pied:
		_vitesse *= 0.35
		_pv_vehicule = max(0.0, _pv_vehicule - degats * 0.6 / _solidite())
	_secousse = max(_secousse, 0.5)
	if _vie <= 0.0:
		_tomber()
	elif cause != "balle":
		_sonne = 0.35
		Sons.jouer("choc", 1.0, -6.0)

func _tomber() -> void:
	_vie = 0.0
	_hors_service = HORS_SERVICE
	# ⚠ ON FERME LA BOUTIQUE. Se faire descendre devant la caisse laissait le
	# menu ouvert ET `saisie` posée : plus moyen de bouger, et ÉCHAP fermait
	# un menu de supérette pendant qu'on se relevait dans la rue.
	if _superette_ouverte:
		_basculer_la_superette()
	if _pause_ouverte:
		_basculer_la_pause()
	# La police ramasse ce qu'on avait sur soi — et l'arme, sauf si on a un
	# arsenal à la planque. C'est ce qui fait qu'on rentre déposer son argent
	# au lieu de rouler jusqu'à la mort.
	if _argent > 0:
		var saisi := int(round(float(_argent) * (SAISIE if _planque >= 0 else SAISIE_SANS_PLANQUE)))
		_argent -= saisi
		if est_hote():
			ajouter_score(Session.cle, -saisi)
		else:
			canal.envoyer("saisie", {"j": Session.cle, "m": saisi})
		_dire_affaire("la police vous prend $%d" % saisi)
	if not bool(_ameliorations["arsenal"]):
		_reprendre_le_pistolet()
	Sons.jouer("voix_cri", _rng.randf_range(0.9, 1.1), -4.0)
	Sons.jouer("chute_mortelle", 1.0, -8.0)
	Sons.arreter_moteur()
	Sons.sirene(0)
	canal.envoyer("mort", {"j": Session.cle, "par": _dernier_agresseur,
		"x": int(_position.x), "y": int(_position.y)})
	if est_hote() and _dernier_agresseur != "" and carte.arene_de(_position) >= 0:
		ville.compter_frag(_dernier_agresseur, _position)
		_vider_les_evenements()
	_dernier_agresseur = ""

func _vehicule_detruit() -> void:
	_effet_explosion(_position)
	canal.envoyer("boum", {"x": int(_position.x), "y": int(_position.y)})
	# On la rend à l'hôte en morceaux. Sans ce message, il continuerait de la
	# croire conduite : elle ne serait plus simulée, plus diffusée, et
	# resterait invisible au milieu de la rue jusqu'à la fin de la manche.
	if _vehicule != 0:
		canal.envoyer("sort", {"id": _vehicule, "x": int(_position.x), "y": int(_position.y),
			"a": snapped(_angle, 0.01), "pv": 0, "g": _genre_vehicule, "m": _modele_vehicule})
		if est_hote():
			ville.rendre_vehicule(Session.cle, _vehicule, _position, _angle, 0.0, _modele_vehicule, _genre_vehicule)
			_vider_les_evenements()
	_encaisser(35.0, "boum", "")
	if _hors_service <= 0.0:
		# On est éjecté : la carcasse reste, le joueur repart à pied.
		_pied = true
		_vitesse = 0.0
		_vehicule = 0
		_modele_vehicule = -1
		_pv_vehicule = PV_VOITURE
		Tactile.mode = Tactile.MARCHE
		Sons.arreter_moteur()

## On se relève à pied, loin de là où on est tombé, et la police a un peu
## oublié. Réapparaître au volant serait plus confortable et retirerait tout
## poids à la mort.
func _relever() -> void:
	_vie = VIE_MAX
	_hors_service = 0.0
	_sonne = 0.0
	_vitesse = 0.0
	_pied = true
	_vehicule = 0
	_modele_vehicule = -1
	_pv_vehicule = PV_VOITURE
	_reprendre_le_pistolet()
	_eperon = 0.0
	Tactile.mode = Tactile.MARCHE
	# On rouvre les yeux à l'HÔPITAL le plus proche — et devant chez soi si on a
	# une planque : c'est ce qui donne un point d'ancrage dans une ville de
	# soixante-huit mille pixels. À défaut, trois à sept rues plus loin.
	var reveil := {}
	if _planque >= 0:
		reveil = carte.planque_par_id(_position, _planque)
	if reveil.is_empty():
		reveil = carte.hopital_le_plus_proche(_position)
	if not reveil.is_empty():
		_position = carte.degager(Vector2(reveil["p"]) + Vector2(0.0, PlanVille.PAS * 0.9), RAYON_A_PIED)[0]
	else:
		_position = carte.point_de_rue(_rng, _position, 300.0, 700.0)
	# Le véhicule rangé au garage nous attend devant la porte — et cette fois
	# on y monte vraiment.
	if _planque >= 0 and not reveil.is_empty():
		_sortir_du_garage(_position, _angle)
	Sons.jouer("depart", 0.8, -8.0)

# ------------------------------------------------------- effets

func _effet_gain(position: Vector2, points: int, facteur: int, cle: String, quoi: String) -> void:
	var couleur := Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 0)))
	# Ce qui se GAGNE sonne comme une prime, pas comme un choc : les à-côtés
	# de la phase 9 (colis, collection, frenzy, course, cascade) rejoignent la
	# liste — sans ça, ramasser un colis faisait le bruit d'une tôle froissée.
	if quoi in ["argent", "contrat", "colis", "collection", "frenzy", "course", "cascade"]:
		Sons.jouer("bonus", 1.0, -10.0)
	elif quoi == "pieton" and not _pied:
		Sons.jouer("ecrase_pieton", _rng.randf_range(0.9, 1.1), -6.0)
	else:
		Sons.jouer("choc_moyen", _rng.randf_range(0.85, 1.2), -8.0)
	if quoi == "pieton" or quoi == "gang":
		Sons.voix("voix_cri", -9.0)
		# Les témoins commentent. Sans eux, une rue qui vient de perdre
		# quelqu'un sonne exactement comme une rue vide.
		if _rng.randf() < 0.45:
			Sons.voix("voix_surprise", -15.0)
	elif quoi == "flic":
		Sons.voix("flic_arme", -11.0)

	if quoi == "pieton" or quoi == "gang" or quoi == "flic":
		# Une flaque au sol, bien plus sombre que la foule : à la même teinte,
		# elle se lit comme une cible et on fonce dessus pour rien. Leur
		# nombre est borné — sans plafond, une manche pleine empile des
		# centaines de maillages.
		var flaque := Decor.cylindre(_rng.randf_range(1.1, 1.9), 0.08,
			Palette.CRITIQUE.darkened(0.72), false)
		flaque.position = Decor.vers3d(position, 0.05)
		flaque.rotation.y = _rng.randf() * TAU
		monde().add_child(flaque)
		_taches.append(flaque)
		if _taches.size() > 80:
			(_taches.pop_front() as Node3D).queue_free()

	for i in 10:
		var eclat := Decor.sphere(_rng.randf_range(0.18, 0.42), Palette.CRITIQUE, false)
		eclat.position = Decor.vers3d(position, 1.0)
		monde().add_child(eclat)
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(1.4, 3.2), _rng.randf_range(-1, 1))
		_eclats.append({"noeud": eclat, "v": direction * _rng.randf_range(6, 14), "t": 1.0, "t0": 1.0})

	var mention := Decor.etiquette("+%d%s" % [points, ("  x%d" % facteur) if facteur > 1 else ""],
		couleur, 44)
	mention.position = Decor.vers3d(position, 3.0)
	monde().add_child(mention)
	_eclats.append({"noeud": mention, "v": Vector3(0, 7.0, 0), "t": 1.1, "t0": 1.1, "texte": true})

## LE BROYAGE, à l'écran : les deux mâchoires se referment, un coup sourd, une
## secousse. Sans les mâchoires qui bougent, une voiture qui disparaît d'un coup
## au milieu d'une dalle rouillée ressemble à un défaut d'affichage — et c'est
## ce que le joueur croira, parce que c'est ce que ça a l'air d'être.
func _effet_broyage(position: Vector2) -> void:
	# Le moteur du compacteur, puis la tôle qui cède. Deux temps : une casse
	# qui ne fait qu'un bruit d'impact ressemble à un accrochage de plus.
	Sons.jouer("broyeur", 0.9, -8.0)
	Sons.jouer("vehicule_broye", _rng.randf_range(0.9, 1.05), -4.0)
	Sons.jouer("choc_dur", 0.7, -9.0)
	_secousse = max(_secousse, 0.32)
	for noeud in _compacteurs:
		var machine: Node3D = noeud
		if Decor.vers3d(position).distance_to(machine.position) > 40.0:
			continue
		for k in 2:
			var machoire := machine.get_node_or_null("Machoire%d" % k) as Node3D
			if machoire == null:
				continue
			var depart := machoire.position.x
			var vers := depart * 0.18
			var anim := create_tween()
			anim.tween_property(machoire, "position:x", vers, 0.35)
			anim.tween_interval(0.5)
			anim.tween_property(machoire, "position:x", depart, 0.7)

## LE TONNERRE. Pas de fichier de tonnerre dans le dossier des sons : c'est la
## grande explosion, ralentie de moitié — plus grave, plus longue, elle roule
## comme il faut. `force` suit la distance de l'éclair (voir `MeteoCarnage`).
func _tonnerre(force: float) -> void:
	Sons.jouer("explosion_grande", lerpf(0.36, 0.5, force), lerpf(-20.0, -9.0, force))
	_secousse = max(_secousse, 0.12 * force)

## `ampleur` de 0 à 1 : une caisse qui saute et le char qui canonne ne sont
## pas le même événement, et jusqu'ici ils faisaient le même bruit.
func _effet_explosion(position: Vector2, ampleur: float = 1.0) -> void:
	var quelle := "explosion_grande"
	if ampleur < 0.4:
		quelle = "explosion_petite"
	elif ampleur < 0.75:
		quelle = "explosion_moyenne"
	Sons.jouer(quelle, _rng.randf_range(0.92, 1.06), -4.0)
	_secousse = max(_secousse, 0.4)
	# La bouffée de feu, et un éclair orange sur les façades autour : au
	# crépuscule, une explosion doit ÉCLAIRER, pas seulement projeter des éclats.
	var bouffee := FormesCarnage.explosion()
	bouffee.position = Decor.vers3d(position, 1.0)
	monde().add_child(bouffee)
	bouffee.finished.connect(bouffee.queue_free)
	var eclair := OmniLight3D.new()
	eclair.light_color = Color(1.0, 0.6, 0.25)
	eclair.light_energy = 4.0
	eclair.omni_range = 30.0
	eclair.shadow_enabled = false
	eclair.position = Decor.vers3d(position, 3.0)
	monde().add_child(eclair)
	_eclats.append({"noeud": eclair, "v": Vector3.ZERO, "t": 0.5, "t0": 0.5, "lumiere": true})
	for i in 18:
		var eclat := Decor.sphere(_rng.randf_range(0.3, 0.7), Palette.SERIEUX, false)
		eclat.material_override = Decor.matiere_lumineuse(Palette.SERIEUX, 1.2)
		eclat.position = Decor.vers3d(position, 1.2)
		monde().add_child(eclat)
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.6, 2.4), _rng.randf_range(-1, 1))
		_eclats.append({"noeud": eclat, "v": direction * _rng.randf_range(14, 26), "t": 0.7, "t0": 0.7})

func _effet_depart_de_coup(position: Vector2, angle: float) -> void:
	# ⚠ Ne pas appeler cette variable `trait` : le mot est réservé par GDScript
	# et l'erreur qui en sort ne parle que d'un « nom de variable attendu ».
	var lueur := Decor.sphere(0.3, Palette.AVERTISSEMENT, false)
	lueur.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 1.4)
	lueur.position = Decor.vers3d(position + Vector2.RIGHT.rotated(angle) * 22.0, 1.4)
	monde().add_child(lueur)
	var vers := Vector2.RIGHT.rotated(angle)
	_eclats.append({"noeud": lueur, "v": Vector3(vers.x, 0.0, vers.y) * 34.0, "t": 0.22, "t0": 0.22})

func _animer_effets(delta: float) -> void:
	var restants: Array = []
	for e in _eclats:
		e["t"] = float(e["t"]) - delta
		var noeud: Node3D = e["noeud"]
		if float(e["t"]) <= 0.0:
			noeud.queue_free()
			continue
		var v: Vector3 = e["v"]
		noeud.position += v * delta
		if e.has("tourne"):
			# Un débris tourne sur lui-même en vol, et s'arrête au sol.
			var w: Vector3 = e["tourne"]
			noeud.rotation += w * delta
			if noeud.position.y <= 0.13:
				e["tourne"] = w * 0.6
		if not e.has("texte") and not e.has("lumiere"):
			v.y -= 26.0 * delta          # les éclats retombent
			e["v"] = v
			if noeud.position.y < 0.12:
				noeud.position.y = 0.12
				e["v"] = Vector3(v.x * 0.4, -v.y * 0.35, v.z * 0.4)
		var reste: float = clamp(float(e["t"]) / float(e["t0"]), 0.0, 1.0)
		if noeud is Label3D:
			(noeud as Label3D).modulate.a = reste
		elif noeud is OmniLight3D:
			(noeud as OmniLight3D).light_energy = 4.0 * reste
		elif noeud is CPUParticles3D:
			pass
		else:
			noeud.scale = Vector3.ONE * max(0.05, reste)
		restants.append(e)
	_eclats = restants

# ------------------------------------------------------- rendu

var _batisses := 0

func rafraichir_scene(delta: float) -> void:
	_batisses = 0
	_diffuser_la_ville()
	_peindre_le_plan()
	# L'heure du village, à chaque image : le jour tombe pendant la manche.
	if _ambiance.size() == 3:
		MatieresCarnage.regler_heure(_ambiance[0], _ambiance[1], _ambiance[2], MatieresCarnage.nuit())
		# Le temps qu'il fait retouche l'heure : après elle, jamais avant.
		if _meteo != null:
			_meteo.appliquer(delta, _ambiance[0], _ambiance[1], MatieresCarnage.nuit())
	# Les vrais phares ne s'allument que la nuit, et les bords de l'écran
	# rougissent le temps d'une secousse.
	if _corps_auto != null:
		FormesCarnage.regler_projecteurs(_corps_auto, MatieresCarnage.nuit())
	MatieresCarnage.post().set_shader_parameter("secousse", clampf(_secousse, 0.0, 1.0))
	_placer_le_joueur(delta)
	_placer_les_autres()
	_placer_la_foule()
	_placer_les_autos()
	_placer_les_objets()
	_placer_les_helicos(delta)
	_placer_les_trains(delta)
	_animer_effets(delta)
	_placer_camera(delta)
	_animer_les_feux(delta)
	_animer_les_cabines()
	_rafraichir_les_repaires()
	_faire_hurler_la_police(delta)
	_sentir_le_quartier()
	_rafraichir_contrat(delta)
	_rafraichir_radar()
	_rafraichir_banniere(delta)

## Le nom du quartier quand on en change. Trois secondes, puis plus rien : une
## bannière permanente serait un panneau de plus dans un écran déjà chargé.
func _annoncer(texte: String, couleur: Color, duree: float) -> void:
	if _hud_banniere == null:
		return
	_hud_banniere.text = texte
	_hud_banniere.add_theme_color_override("font_color", couleur)
	_banniere_reste = duree

func _rafraichir_banniere(delta: float) -> void:
	if _hud_banniere == null:
		return
	var territoire := carte.territoire(_position)
	var quartier := carte.quartier(_position)
	if territoire != _territoire_vu or quartier != _quartier_vu:
		_territoire_vu = territoire
		_quartier_vu = quartier
		# Une annonce plus pressante (l'hélicoptère) ne se fait pas couvrir par
		# le nom d'un quartier.
		if _banniere_reste < 1.0:
			var texte := carte.nom_du_quartier(_position).capitalize()
			var couleur := Palette.ENCRE_DOUCE
			if territoire >= 0:
				texte += " — chez %s" % carte.nom_du_gang(territoire)
				couleur = carte.couleur_du_gang(territoire)
			_annoncer(texte, couleur, 3.2)
	_banniere_reste -= delta
	_hud_banniere.modulate.a = clamp(_banniere_reste / 0.8, 0.0, 1.0)

## Le plan ne se redessine qu'avec ce qu'il montre : positions des joueurs,
## patrouilles lancées, étoiles. Lui passer la ville entière image par image
## coûterait plus cher que la partie.
func _rafraichir_radar() -> void:
	if _radar == null:
		return
	_radar.moi = _position
	_radar.mon_angle = _angle
	_radar.ma_couleur = _ma_couleur()
	_radar.etoiles = ville.etoiles(Session.cle)
	var voisins: Array = []
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		voisins.append({"p": a["p"],
			"couleur": Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1)))})
	_radar.autres = voisins
	var bleus: Array = []
	for auto in ville.autos:
		if int(auto["genre"]) == VilleVivante.PATROUILLE:
			bleus.append(auto["p"])
	_radar.patrouilles = bleus
	_radar.cible = _cible_contrat
	_radar.queue_redraw()

## Le halo d'une cabine clignote tant qu'on n'a pas de contrat en main. Une
## cabine qui appelle alors qu'on est déjà pris ferait faire un détour pour rien.
## Les brasiers : un nœud par foyer, apparu et retiré au fil de ce que dit
## l'hôte. Les dégâts du feu, eux, sont locaux — chacun s'inflige la brûlure
## qu'il traverse, comme pour les balles : attendre l'aller-retour de l'hôte
## rendrait le feu inoffensif à haute vitesse.
var _brasiers: Dictionary = {}        ## id du feu -> Node3D
var _feux_de_banc := 0                ## `--banc-feu=N` : foyers à rallumer autour du pilote
var _depuis_feu_banc := 0.0
var _depuis_brulure := 0.0

func _animer_les_feux(delta: float) -> void:
	# `--banc-feu=N` : N foyers autour de soi, RENOUVELÉS toutes les huit
	# secondes — un incendie s'éteint (ou les pompiers l'éteignent) avant la
	# photo suivante, et on ne photographierait jamais la ville qui brûle.
	if _feux_de_banc > 0 and est_hote() and temps > 3.0:
		_depuis_feu_banc -= delta
		if _depuis_feu_banc <= 0.0:
			_depuis_feu_banc = 5.0
			for i in _feux_de_banc:
				var loin := _position + Vector2.RIGHT.rotated(TAU * float(i) / float(_feux_de_banc) + temps) * _rng.randf_range(40.0, 120.0)
				ville.allumer(carte.degager(loin, 20.0)[0], 1.0)

	var vus: Dictionary = {}
	for f in ville.feux:
		var id := int(f["id"])
		vus[id] = true
		var ou: Vector2 = f["p"]
		if ou.distance_to(_position) > 2200.0:
			continue
		var noeud: Node3D = _brasiers.get(id)
		if noeud == null:
			noeud = FormesCarnage.brasier()
			noeud.position = Decor.vers3d(ou, 0.6)
			monde().add_child(noeud)
			_brasiers[id] = noeud
		FormesCarnage.regler_brasier(noeud, float(f["force"]), temps + float(id))
	for id in _brasiers.keys():
		if not vus.has(id):
			(_brasiers[id] as Node3D).queue_free()
			_brasiers.erase(id)

	# Rester dans les flammes coûte cher : on brûle une fois par demi-seconde.
	_depuis_brulure -= delta
	if _depuis_brulure > 0.0 or _hors_service > 0.0:
		return
	for f in ville.feux:
		var d: float = Vector2(f["p"]).distance_to(_position)
		var portee: float = VilleVivante.RAYON_FEU * (0.55 + 0.45 * float(f["force"]))
		if d < portee:
			_depuis_brulure = 0.5
			_encaisser(VilleVivante.DEGAT_FEU * 0.5 * float(f["force"]), "feu", "")
			_secousse = max(_secousse, 0.18)
			break

## La cabine a DEUX choses à dire et une seule enseigne pour les dire.
##
## Sa couleur — verte, jaune, rouge — est celle du téléphone lui-même : la
## difficulté du travail qu'on y trouve. Elle est peinte une fois pour toutes
## dans `FormesCarnage.cabine()` et ne bouge plus : c'est ce qui permet de
## repérer un téléphone rouge en passant et de revenir plus tard.
##
## ⚠ Cette enseigne repeignait l'humeur du gang, image par image. Deux
## défauts : elle disait la même chose que l'anneau sous ses hommes et que la
## ligne du tableau de bord, et surtout elle écrasait la couleur du palier —
## on ne pouvait plus reconnaître un téléphone d'un autre. Ne reste donc ici
## que l'ÉCLAT : allumé quand on peut décrocher, éteint sinon.
func _animer_les_cabines() -> void:
	var libre := _contrat.is_empty()
	for cle in _morceaux:
		for entree in (_morceaux[cle] as MorceauVille).cabines:
			var poste: Node3D = entree["n"]
			var rang := FormesCarnage.niveau_de_cabine(int(entree.get("id", 0)))
			# Ouverte = ce gang-ci vous en confie assez pour ce téléphone-là.
			# Même calcul que `VilleVivante.proposer_contrat`, sinon l'enseigne
			# inviterait à décrocher pour se faire raccrocher au nez.
			# `employeur` est figé à la pose du morceau (voir `morceau.gd`) :
			# c'est le gang qui décrochera vraiment, terrain neutre compris.
			var gang := int(entree.get("employeur", 0))
			var ouverte := ville.respect_pour(Session.cle, gang) \
				>= float(FormesCarnage.CABINES[rang]["respect"])
			var halo := poste.get_node_or_null("Halo") as Node3D
			if halo:
				halo.visible = libre and ouverte and fmod(temps, 1.0) > 0.42
			var mot := poste.get_node_or_null("Mot") as Node3D
			if mot:
				mot.visible = libre
			var enseigne := poste.get_node_or_null("Enseigne") as MeshInstance3D
			if enseigne == null:
				continue
			var eclat: float = FormesCarnage.CABINE_ALLUMEE if (libre and ouverte) \
				else FormesCarnage.CABINE_ETEINTE
			if entree.get("eclat") != eclat:
				entree["eclat"] = eclat
				var teinte: Color = FormesCarnage.CABINES[rang]["couleur"]
				enseigne.material_override = Decor.matiere_lumineuse(teinte, eclat)

## Une poursuite s'entend avant de se voir : c'est la sirène qui dit qu'il faut
## tourner tout de suite, pas la voiture aperçue trois rues plus loin.
func _faire_hurler_la_police(delta: float) -> void:
	var niveau := ville.etoiles(Session.cle)
	if niveau <= 0:
		_depuis_sirene = 0.0
		_depuis_radio = 0.0
		Sons.sirene(0)
		return
	# La sirène tourne en continu tant qu'on est recherché : une poursuite est
	# un état. Elle enfle avec les étoiles, passe au régime rapide à trois —
	# et son volume suit la patrouille la plus proche. À volume fixe, on ne
	# savait pas si on les avait semés : la jauge d'étoiles reste allumée
	# plusieurs secondes après qu'ils ont perdu la trace.
	var proche := 1e9
	var char_proche := 1e9
	for auto in ville.autos:
		if int(auto["genre"]) != VilleVivante.PATROUILLE:
			continue
		var d: float = (auto["p"] as Vector2).distance_to(_position)
		proche = min(proche, d)
		if int(auto.get("corps", 0)) == VilleVivante.CORPS_ARMEE:
			char_proche = min(char_proche, d)
	Sons.sirene(niveau, -14.0 - 16.0 * clamp(proche / 1600.0, 0.0, 1.0))
	# LE CHAR s'entend avant de se voir, et c'est tout l'intérêt : on ne
	# tourne pas dans sa rue par hasard deux fois.
	if char_proche < 1100.0:
		_depuis_chenilles -= delta
		if _depuis_chenilles <= 0.0:
			_depuis_chenilles = 0.9
			Sons.jouer("chenilles", _rng.randf_range(0.94, 1.04),
				-12.0 - 14.0 * (char_proche / 1100.0))
	# Le dispatch, lui, parle par intervalles — assez pour raconter la chasse,
	# assez peu pour qu'on entende encore le moteur.
	_depuis_radio -= delta
	if _depuis_radio <= 0.0:
		_depuis_radio = _rng.randf_range(9.0, 16.0)
		Sons.radio_police(niveau, 0, _cap_parle())
	_depuis_sirene -= delta
	if _depuis_sirene > 0.0:
		return
	_depuis_sirene = max(0.7, 1.6 - 0.18 * float(niveau))

## Le point cardinal vers lequel on file, dit comme la radio le dirait.
func _cap_parle() -> String:
	var d := _glisse if not _pied else Vector2.RIGHT.rotated(_angle)
	if abs(d.x) > abs(d.y):
		return "east" if d.x > 0.0 else "west"
	return "south" if d.y > 0.0 else "north"

## Le sablier du contrat descend chez chacun entre deux nouvelles de l'hôte ;
## l'affichage lui-même est dans la fiche (`fiche_joueur`).
func _rafraichir_contrat(delta: float) -> void:
	if _contrat.is_empty():
		return
	_contrat["r"] = max(0.0, float(_contrat["r"]) - delta)

func _alerte_contrat() -> Dictionary:
	if _contrat.is_empty():
		return {}
	var avance := ""
	if int(_contrat["n"]) > 1:
		avance = "  %d/%d" % [int(_contrat["a"]), int(_contrat["n"])]
	var restant := float(_contrat["r"])
	return {
		"texte": "CONTRAT  %s%s   %ds" % [String(_contrat["t"]).to_upper(), avance, int(ceil(restant))],
		"couleur": Palette.CRITIQUE if restant <= 8.0 else Palette.AVERTISSEMENT,
		"part": restant / _contrat_duree if _contrat_duree > 0.0 else -1.0,
	}

func _placer_le_joueur(delta: float) -> void:
	# ⚠ SON PROPRE CORPS DISPARAÎT EN VUE SUBJECTIVE : l'œil est posé dans la
	# tête du pantin, et sans ça l'écran devient une texture de peau. Les
	# AUTRES joueurs, eux, restent visibles — c'est même tout l'intérêt.
	_corps_auto.visible = not _pied and _hors_service <= 0.0 and not _subjectif
	_corps_pied.visible = _pied and not _subjectif \
		and (_hors_service <= 0.0 or fmod(_hors_service, 0.3) > 0.15)

	if _corps_auto.visible:
		_corps_auto.position = Decor.vers3d(_position, 0.0)
		_corps_auto.rotation.y = -_angle
		# Assiette : la voiture pique du nez au freinage et se cabre à
		# l'accélération. Trois degrés suffisent à faire sentir la masse.
		var assiette: float = clamp(_vitesse / VITESSE_MAX, -1.0, 1.0)
		_corps_auto.rotation.z = lerp(_corps_auto.rotation.z, deg_to_rad(-assiette * 3.0),
			clamp(delta * 6.0, 0, 1))
		if _sonne > 0.0:
			_corps_auto.rotation.z = sin(_sonne * 40.0) * 0.25
		var buffle := _corps_auto.get_node_or_null("Buffle") as MeshInstance3D
		if buffle:
			buffle.visible = _eperon > 0.0
		# Au volant d'une voiture de police volée, le gyrophare tourne aussi :
		# c'est ce qui la rend reconnaissable — et voyante.
		if _genre_vehicule == VilleVivante.PATROUILLE:
			FormesCarnage.clignoter_gyrophare(_corps_auto, Time.get_ticks_msec() / 1000.0, true)
		# La fumée : un filet à l'accélération, un panache noir quand la tôle
		# est à bout. C'est ce qui dit qu'il est temps de changer de voiture.
		var fumee := _corps_auto.get_node_or_null("Fumee") as CPUParticles3D
		if fumee:
			var abime := _pv_vehicule < PV_VOITURE * 0.35
			fumee.emitting = abime or (Commandes.conduite().y > 0.1 and _hors_service <= 0.0)
			fumee.amount = 40 if abime else 22
			if fumee.color_ramp:
				(fumee.color_ramp as Gradient).set_color(0, Color(0.15, 0.15, 0.15, 0.7) if abime else Color(0.8, 0.8, 0.82, 0.45))
		_regler_jauge(_corps_auto, _pv_vehicule / PV_VOITURE)

	if _corps_pied.visible:
		if _dedans != "":
			# ⚠ Le pantin est taillé pour la VILLE ; un intérieur est à
			# l'échelle du mètre. Posé tel quel, il dépassait le plafond — la
			# première photo montrait un géant dans sa cuisine.
			Interieurs.poser_pantin(_corps_pied, _dedans_p, "joueur", Interieurs.SOUS_SOL)
		else:
			_corps_pied.scale = Vector3.ONE
			_corps_pied.position = Decor.vers3d(_position, 0.0)
		_corps_pied.rotation.y = -_angle
		_demarche(_corps_pied, "walk" if abs(_vitesse) > 1.0 else "idle")
		_regler_jauge(_corps_pied, _vie / VIE_MAX)

func _placer_les_autres() -> void:
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var au_volant: bool = not bool(a["pied"]) and int(a.get("etat", 1)) != 2
		var a_pied: bool = bool(a["pied"]) and int(a.get("etat", 1)) != 2
		var auto: Node3D = a["auto"]
		var pieton: Node3D = a["pieton"]
		auto.visible = au_volant
		pieton.visible = a_pied
		if au_volant:
			auto.position = Decor.vers3d(a["p"])
			auto.rotation.y = -float(a["a"])
			var gyro := auto.get_node_or_null("Gyrophare")
			if gyro:
				gyro.visible = int(a.get("genre", 0)) == VilleVivante.PATROUILLE
				FormesCarnage.clignoter_gyrophare(auto, Time.get_ticks_msec() / 1000.0, true)
			var buffle := auto.get_node_or_null("Buffle") as MeshInstance3D
			if buffle:
				buffle.visible = bool(a.get("eperon", false))
			# ⚠ La mitrailleuse d'un AUTRE joueur voyage dans son paquet (`mg`).
			# Sans elle, on voyait une voiture de gang volée repasser désarmée
			# — et l'on apprenait à se fier à une silhouette qui ment.
			FormesCarnage.armer_la_voiture(auto, bool(a.get("mitrailleuse", false)))
			_regler_jauge(auto, float(a["vie"]) / VIE_MAX)
		if a_pied:
			pieton.position = Decor.vers3d(a["p"])
			pieton.rotation.y = -float(a["a"])
			_demarche(pieton, "walk" if abs(float(a.get("v", 0.0))) > 1.0 else "idle")
			_regler_jauge(pieton, float(a["vie"]) / VIE_MAX)

func _placer_la_foule() -> void:
	for personne in ville.gens:
		var noeud = personne.get("noeud")
		if noeud == null:
			if (personne["p"] as Vector2).distance_to(_position) > PORTEE_RENDU or _batisses >= BATISSES_PAR_IMAGE:
				continue
			_batisses += 1
			# Un uniforme se bâtit par `FormesCarnage.uniforme` — le gilet de
			# son corps compris. Le banc d'image appelle la même fonction ;
			# c'est la seule façon d'être sûr que ce qu'on photographie est ce
			# que la rue montre.
			if int(personne["genre"]) == VilleVivante.FLIC:
				noeud = FormesCarnage.uniforme(int(personne.get("corps", 0)))
			else:
				noeud = FormesCarnage.pieton(_couleur_de(personne),
					int(personne["genre"]) == VilleVivante.GANG, "", false, _peau_de(personne))
			monde().add_child(noeud)
			personne["noeud"] = noeud
		var corps: Node3D = noeud
		corps.visible = (personne["p"] as Vector2).distance_to(_position) <= PORTEE_RENDU
		if not corps.visible:
			continue
		corps.position = Decor.vers3d(personne["p"])
		# Le personnage en cubes regarde +X, comme les voitures.
		corps.rotation.y = -float(personne.get("a", 0.0))
		_demarche(corps, "walk")
		_regler_jauge(corps, float(int(personne["pv"])) / float(_pv_max_de(personne)))
		_regler_humeur(personne, corps)

## La tête d'un habitant : les hommes de main ont les leurs, les flics la
## leur, les passants huit visages tirés de leur identifiant. Tirer sur
## l'identifiant et non au hasard, c'est ce qui fait qu'un piéton ne change pas
## de tête entre deux images.
func _peau_de(personne: Dictionary) -> String:
	var graine := int(personne.get("id", 0))
	match int(personne["genre"]):
		VilleVivante.GANG:
			return FormesCarnage.PEAUX_GANG[posmod(graine, FormesCarnage.PEAUX_GANG.size())]
		VilleVivante.FLIC:
			return FormesCarnage.PEAU_FLIC
	return FormesCarnage.peau_civile(graine)

func _couleur_de(personne: Dictionary) -> Color:
	match int(personne["genre"]):
		VilleVivante.GANG:
			return carte.couleur_du_gang(int(personne["gang"]))
		VilleVivante.FLIC:
			return FormesCarnage.TENUES_CORPS[clamp(int(personne.get("corps", 0)), 0,
				FormesCarnage.TENUES_CORPS.size() - 1)]
	return Palette.ENCRE_DOUCE

func _pv_max_de(personne: Dictionary) -> int:
	if int(personne["genre"]) == VilleVivante.FLIC:
		return int(VilleVivante.CORPS[clamp(int(personne.get("corps", 0)), 0,
			VilleVivante.CORPS.size() - 1)]["pv"])
	match int(personne["genre"]):
		VilleVivante.GANG:
			return VilleVivante.PV_GANG
		VilleVivante.FLIC:
			return VilleVivante.PV_FLIC
	return VilleVivante.PV_PIETON

func _placer_les_autos() -> void:
	for auto in ville.autos:
		if PlanVille.est_dormante(int(auto["id"])):
			_effacer_la_dormante(int(auto["id"]))
		if String(auto.get("pilote", "")) != "":
			var conduit = auto.get("noeud")
			if conduit != null:
				(conduit as Node3D).visible = false
			continue
		var noeud = auto.get("noeud")
		var genre := int(auto["genre"])
		# Ce qui est à plus d'un écran et demi n'est pas dessiné : l'hôte a
		# trois cents voitures dans sa liste, et un navigateur en mode
		# compatibilité n'en dessine pas trois cents.
		var proche: bool = (auto["p"] as Vector2).distance_to(_position) <= PORTEE_RENDU
		if noeud == null:
			if not proche or _batisses >= BATISSES_PAR_IMAGE:
				continue
			_batisses += 1
			if genre == VilleVivante.EPAVE:
				noeud = FormesCarnage.epave()
			elif bool(auto.get("canon", false)):
				noeud = FormesCarnage.char_arme()
			else:
				# Une carrosserie repeinte au garage garde sa peinture une fois
				# garée ; une dormante réveillée garde celle de la nappe : c'est
				# la même fonction qui décide pour toutes.
				var couleur := FormesCarnage.couleur_de_l_auto(carte, int(auto.get("modele", 0)),
					int(auto["id"]), genre == VilleVivante.VOITURE_GANG, int(auto.get("gang", 0)),
					int(auto.get("teinte", 0)))
				noeud = FormesCarnage.voiture_kit(int(auto.get("modele", 0)), couleur)
			monde().add_child(noeud)
			auto["noeud"] = noeud
		elif genre == VilleVivante.EPAVE and not auto.get("epave_vue", false):
			# Elle vient de brûler : la coque saine part, la carcasse la remplace.
			(noeud as Node3D).queue_free()
			noeud = FormesCarnage.epave()
			monde().add_child(noeud)
			auto["noeud"] = noeud
		auto["epave_vue"] = genre == VilleVivante.EPAVE
		var corps: Node3D = noeud
		corps.visible = proche
		corps.position = Decor.vers3d(auto["p"])
		corps.rotation.y = -float(auto["a"])
		# Une voiture à l'arrêt a ses phares éteints : allumés, on la prend
		# pour une voiture qui arrive.
		# LES VOITURES DE GANG SONT ARMÉES (§1.3). Le guide le demandait et nos
		# voitures de gang ne portaient que la couleur du gang : on les
		# reconnaissait, elles ne valaient rien de plus qu'une berline. Celle-ci
		# se voit de loin, et c'est ce qui en fait une PRISE.
		FormesCarnage.armer_la_voiture(corps, genre == VilleVivante.VOITURE_GANG)
		var phares := corps.get_node_or_null("Phares") as Node3D
		if phares:
			phares.visible = not bool(auto.get("garee", false))
		if genre == VilleVivante.PATROUILLE:
			FormesCarnage.clignoter_gyrophare(corps, Time.get_ticks_msec() / 1000.0,
				not bool(auto.get("garee", false)))
		_regler_jauge(corps, float(auto["pv"]) / PV_VOITURE)

func _placer_les_objets() -> void:
	for caisse in ville.caisses:
		var noeud = caisse.get("noeud")
		if noeud == null:
			var arme := String(caisse["arme"])
			noeud = FormesCarnage.caisse(arme, COULEURS_BUTIN[arme] if COULEURS_BUTIN.has(arme)
				else ARMES.get(arme, ARMES["pistolet"])["couleur"])
			monde().add_child(noeud)
			caisse["noeud"] = noeud
		(noeud as Node3D).position = Decor.vers3d(caisse["p"])
		var objet := (noeud as Node3D).get_node_or_null("Objet") as Node3D
		if objet:
			objet.rotation.y = temps * 1.3
			objet.position.y = 1.6 + sin(temps * 2.2 + float(int(caisse["id"]))) * 0.28

	# LES À-CÔTÉS : le colis tourne comme une caisse (c'est le vocabulaire de
	# « ramasse-moi »), le crâne du Frenzy aussi mais plus vite — il n'attend
	# pas, il défie.
	for r in ville.ramassages:
		var noeud_r = r.get("noeud")
		if noeud_r == null:
			noeud_r = FormesCarnage.colis() if int(r["genre"]) == VilleVivante.R_COLIS \
				else FormesCarnage.icone_frenzy()
			monde().add_child(noeud_r)
			r["noeud"] = noeud_r
		(noeud_r as Node3D).position = Decor.vers3d(r["p"])
		var tourne := (noeud_r as Node3D).get_node_or_null("Objet") as Node3D
		if tourne:
			var vite := 1.2 if int(r["genre"]) == VilleVivante.R_COLIS else 2.6
			tourne.rotation.y = temps * vite
			tourne.position.y = (1.5 if int(r["genre"]) == VilleVivante.R_COLIS else 1.8) \
				+ sin(temps * 2.0 + float(int(r["id"]))) * 0.24

	# LES PIÈGES. La mine clignote — un objet qui blesse doit se signaler, même
	# à celui qui l'a posée ; la flaque, elle, reste sourde : elle ne fait
	# perdre que le cap.
	for piege in ville.pieges:
		var noeud_p = piege.get("noeud")
		if noeud_p == null:
			noeud_p = FormesCarnage.mine() if int(piege["genre"]) == VilleVivante.MINE \
				else FormesCarnage.flaque_huile()
			monde().add_child(noeud_p)
			piege["noeud"] = noeud_p
		(noeud_p as Node3D).position = Decor.vers3d(piege["p"])
		var oeil := (noeud_p as Node3D).get_node_or_null("Oeil") as Node3D
		if oeil:
			oeil.visible = fmod(temps, 0.6) > 0.3

	for b in ville.barrages:
		var noeud = b.get("noeud")
		if noeud == null:
			noeud = FormesCarnage.barrage()
			monde().add_child(noeud)
			b["noeud"] = noeud
		(noeud as Node3D).position = Decor.vers3d(b["p"])
		var gyro := (noeud as Node3D).get_node_or_null("Gyro") as Node3D
		if gyro:
			gyro.visible = fmod(temps, 0.7) > 0.35

## La démarche d'un habitant : le lecteur d'animations du casting joue
## « course » ou « repos ». On ne lui parle que quand l'animation change —
## rappeler `play` sur celle qui tourne la relance à zéro, et toute la rue
## piétinerait sur place, un pas commencé et jamais fini.
func _demarche(porteur: Node3D, nom: String) -> void:
	var silhouette := porteur.get_node_or_null("Silhouette") as Node3D
	if silhouette:
		FormesCarnage.animer_kenney(silhouette, nom == "walk")

## L'hélicoptère : il glisse vers sa dernière position connue, son rotor tourne,
## et on entend ses pales quand il est proche — c'est ce qui dit qu'il est là
## avant qu'on lève les yeux, ce que la caméra ne permet pas.
func _placer_les_helicos(delta: float) -> void:
	var proche_de_moi := false
	for h in ville.helicos:
		var noeud = h.get("noeud")
		if noeud == null:
			noeud = FormesCarnage.helico()
			monde().add_child(noeud)
			h["noeud"] = noeud
		if not est_hote():
			h["p"] = (h["p"] as Vector2).lerp(h.get("cible", h["p"]) if h.get("cible", "") is Vector2 else h["p"], clamp(delta * 8.0, 0, 1))
		var corps: Node3D = noeud
		corps.position = Decor.vers3d(h["p"])
		var cellule := corps.get_node_or_null("Cellule") as Node3D
		if cellule:
			cellule.rotation.y = -float(h.get("cap", 0.0))
			var rotor := cellule.get_node_or_null("Rotor") as Node3D
			if rotor:
				rotor.rotation.y += delta * 28.0
			var feu := cellule.get_node_or_null("Feu") as Node3D
			if feu:
				feu.visible = fmod(temps, 0.5) > 0.25
		if (h["p"] as Vector2).distance_to(_position) < 900.0:
			proche_de_moi = true
	if proche_de_moi:
		_depuis_battement -= delta
		if _depuis_battement <= 0.0:
			_depuis_battement = 0.36
			Sons.jouer("battement", 1.0, -14.0)

## LA FAIM ET LA SOIF, une image après l'autre. Appelée depuis
## `_surveiller_les_lieux`, donc à pied, au volant et dans le train — mais pas
## chez soi ni dans un repaire : à l'intérieur, le temps du ventre s'arrête.
## Ce n'est pas du réalisme, c'est du confort : on entre chez soi pour ranger
## de l'argent, pas pour se faire surprendre par une jauge qu'on ne voit plus.
func _avoir_faim(delta: float) -> void:
	var effort := EFFORT_A_PIED if _pied else 1.0
	_faim = maxf(0.0, _faim - FAIM_MAX / DUREE_FAIM * effort * delta)
	_soif = maxf(0.0, _soif - FAIM_MAX / DUREE_SOIF * effort * delta)
	_creux_dit = maxf(0.0, _creux_dit - delta)
	# L'AVERTISSEMENT arrive au seuil, une fois, puis se rappelle toutes les
	# vingt secondes. Une annonce à chaque image serait un mur de texte ; une
	# seule annonce et l'on meurt en ayant oublié.
	if _creux_dit <= 0.0 and (_faim <= SEUIL_CREUX or _soif <= SEUIL_CREUX):
		_creux_dit = 20.0
		if _faim <= 0.0 or _soif <= 0.0:
			_annoncer("VOUS DÉPÉRISSEZ — trouvez une supérette", Palette.CRITIQUE, 3.0)
		elif _faim <= _soif:
			_annoncer("vous avez faim", Palette.AVERTISSEMENT, 2.4)
		else:
			_annoncer("vous avez soif", Palette.AVERTISSEMENT, 2.4)
	# LE VENTRE VIDE RONGE. On ne passe PAS par `_encaisser` : elle secoue
	# l'écran, joue un choc et retient un agresseur. Mourir de faim n'a ni
	# coupable ni impact — c'est une usure, et une secousse par seconde pendant
	# cinquante secondes rendrait le jeu injouable bien avant la mort.
	if (_faim > 0.0 and _soif > 0.0) or _hors_service > 0.0 or _invincible:
		return
	var creux := (1.0 if _faim <= 0.0 else 0.0) + (1.0 if _soif <= 0.0 else 0.0)
	_vie -= DEGAT_JEUNE * creux * delta
	if _vie <= 0.0:
		_tomber()

## MANGER. La touche n'ouvre pas de menu : elle prend dans les poches ce qui
## répond au besoin le plus pressant (`Provisions.le_mieux`). Trois touches
## pour choisir entre un sandwich et une bouteille d'eau pendant qu'on se fait
## tirer dessus, personne ne le fait deux fois.
func _consommer() -> void:
	var cle := Provisions.le_mieux(_provisions, _faim, _soif, _vie, FAIM_MAX)
	if cle == "":
		# ⚠ On distingue « rien sur soi » de « rien d'utile » : un joueur à
		# quatre-vingt-dix-huit de faim avec trois sandwichs n'a pas un
		# inventaire vide, il n'a simplement pas besoin de manger.
		_dire_affaire("rien à consommer" if _provisions.is_empty() else "pas besoin pour l'instant")
		return
	Provisions.retirer(_provisions, cle)
	var a := Provisions.fiche(cle)
	_faim = clampf(_faim + float(a["faim"]), 0.0, FAIM_MAX)
	_soif = clampf(_soif + float(a["soif"]), 0.0, FAIM_MAX)
	_vie = clampf(_vie + float(a["vie"]), 1.0, VIE_MAX)
	_dire_affaire("%s — %s" % [String(a["nom"]).to_lower(), Provisions.effet(cle)])
	Sons.jouer("dalle", _rng.randf_range(0.9, 1.1), -14.0)

# ------------------------------------------------------------- la pause

func _basculer_la_pause() -> void:
	_pause_ouverte = not _pause_ouverte
	_regler_la_saisie()
	if _pause_ouverte:
		if _pause_vue == null:
			_pause_vue = Control.new()
			_pause_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
			_pause_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pause_vue.set_script(load("res://ui/pause.gd"))
			interface().add_child(_pause_vue)
		_pause_vue.choix = 0
		Sons.jouer("clic", 0.8, -12.0)
	elif _pause_vue != null:
		_pause_vue.queue_free()
		_pause_vue = null

func _naviguer_dans_la_pause() -> void:
	if _pause_vue == null:
		return
	# Le sous-titre dit ce qu'on emporte : l'argent DÉPOSÉ compte, celui qu'on
	# a sur soi aussi. C'est la dernière chose qu'on veut vérifier avant de
	# rentrer, et aller la lire ailleurs qu'ici, personne ne le fait.
	_pause_vue.sous_titre = "$%d sur soi · $%d au coffre" % [_argent, _banque]
	_pause_vue.lignes = [
		{"texte": "REPRENDRE", "detail": "", "couleur": Palette.BON},
		{"texte": "QUITTER LA VILLE", "detail": "la manche s'arrête pour la table",
			"couleur": Palette.SERIEUX},
	]
	if _front_de_triche(KEY_UP):
		_pause_vue.choix = posmod(int(_pause_vue.choix) - 1, 2)
	if _front_de_triche(KEY_DOWN):
		_pause_vue.choix = posmod(int(_pause_vue.choix) + 1, 2)
	if _front_de_triche(KEY_ENTER) or _front_de_triche(KEY_KP_ENTER) or _front_de_triche(KEY_SPACE):
		if int(_pause_vue.choix) == 0:
			_basculer_la_pause()
		else:
			_quitter_la_ville()
	_pause_vue.queue_redraw()

## RENTRER. C'est ici que la manche se termine, et c'est le seul endroit.
##
## ⚠ SEUL L'HÔTE PEUT CONCLURE. `Partie.terminer()` diffuse le classement ET le
## dépose en base, une fois : quatre clients qui déposent, c'est quatre parties
## en base pour une seule jouée. Un joueur ordinaire demande donc à l'hôte de
## conclure, et l'hôte lui répond par le « fin » que tout le monde reçoit.
##
## La manche s'arrête POUR LA TABLE, et le menu le dit avant qu'on appuie. On
## aurait pu ne faire sortir que le partant — mais son score resterait alors
## dans un classement que personne ne dépose, et il faudrait décider quoi faire
## du dernier joueur resté seul en ville. Une manche est une manche : elle
## commence ensemble et elle finit ensemble.
func _quitter_la_ville() -> void:
	_basculer_la_pause()
	if est_hote():
		terminer("%s rentre" % Session.pseudo)
	else:
		canal.envoyer("rentrer", {"j": Session.cle, "p": Session.pseudo})

# -------------------------------------------------------- la supérette

## Ouvrir et fermer la boutique. Même mécanique que le menu de triche : la
## ville continue de tourner derrière, le joueur seul est figé.
func _basculer_la_superette() -> void:
	_superette_ouverte = not _superette_ouverte
	_regler_la_saisie()
	if _superette_ouverte:
		if _superette_vue == null:
			_superette_vue = Control.new()
			_superette_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
			_superette_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_superette_vue.set_script(load("res://ui/superette.gd"))
			interface().add_child(_superette_vue)
		_superette_vue.choix = 0
		_superette_vue.message = ""
		Sons.jouer("porte", 1.0, -10.0)
	elif _superette_vue != null:
		_superette_vue.queue_free()
		_superette_vue = null
		Sons.jouer("porte", 0.8, -12.0)

func _naviguer_dans_la_superette() -> void:
	if _superette_vue == null:
		return
	# Le catalogue se recopie à chaque image avec ce qu'on possède et ce qu'on
	# peut payer : acheter change les deux, et un menu qui ne se met à jour
	# qu'à la fermeture ment pendant tout l'achat.
	var liste: Array = []
	for a in Provisions.CATALOGUE:
		liste.append({"cle": String(a["cle"]), "nom": String(a["nom"]), "prix": int(a["prix"]),
			"effet": Provisions.effet(String(a["cle"])), "couleur": a["couleur"],
			"possede": int(_provisions.get(String(a["cle"]), 0))})
	_superette_vue.articles = liste
	_superette_vue.argent = _argent
	_superette_vue.poches = Provisions.compte(_provisions)
	_superette_vue.poches_max = Provisions.POCHES
	# LE PILOTE DU BANC FAIT SES COURSES. Il ne peut pas appuyer sur les
	# flèches — `_front_de_triche` lit le clavier physique — donc il achèterait
	# zéro article et la caisse, les poches pleines et le refus faute d'argent
	# ne seraient jamais exercés par une manche.
	if Commandes.pilote_automatique:
		for a in liste:
			if _argent >= int(a["prix"]) and Provisions.compte(_provisions) < Provisions.POCHES:
				_acheter_a_la_superette(String(a["cle"]))
				break
		_basculer_la_superette()
		return
	if _front_de_triche(KEY_UP):
		_superette_vue.choix = posmod(int(_superette_vue.choix) - 1, liste.size())
	if _front_de_triche(KEY_DOWN):
		_superette_vue.choix = posmod(int(_superette_vue.choix) + 1, liste.size())
	if _front_de_triche(KEY_ENTER) or _front_de_triche(KEY_KP_ENTER) or _front_de_triche(KEY_SPACE):
		_acheter_a_la_superette(String(liste[int(_superette_vue.choix)]["cle"]))
	if _front_de_triche(KEY_ESCAPE):
		_basculer_la_superette()
	_superette_vue.queue_redraw()

func _acheter_a_la_superette(cle: String) -> void:
	var prix := Provisions.prix(cle)
	if Provisions.compte(_provisions) >= Provisions.POCHES:
		_superette_vue.message = "vos poches sont pleines — rangez au frigo, chez vous"
		_superette_vue.message_couleur = Palette.AVERTISSEMENT
		Sons.jouer("choc", 0.6, -16.0)
		return
	if _argent < prix:
		_superette_vue.message = "il manque $%d" % (prix - _argent)
		_superette_vue.message_couleur = Palette.CRITIQUE
		Sons.jouer("choc", 0.6, -16.0)
		return
	_encaisser_argent(-prix)
	Provisions.ajouter(_provisions, cle)
	_superette_vue.message = "%s dans le sac" % Provisions.nom(cle).to_lower()
	_superette_vue.message_couleur = PlanVille.COULEUR_SUPERETTE
	Sons.jouer("bip", 1.2, -14.0)

## LES RAMES ET LES QUAIS. Les quais ne sont posés QU'UNE FOIS : leur place
## vient de `VilleVivante.gares()`, qui ne dépend que du code de la manche.
## Les rames, elles, bougent à chaque image.
##
## ⚠ Le client EXTRAPOLE la position de la rame entre deux instantanés. À neuf
## cents pixels par seconde et huit instantanés par seconde, une rame recopiée
## telle quelle avançait par bonds de cent vingt pixels — un train qui clignote
## d'une rue à l'autre. Un train est le seul objet de la ville dont on sait
## exactement où il sera dans un dixième de seconde : autant s'en servir.
func _placer_les_trains(delta: float) -> void:
	if not _quais_poses:
		_quais_poses = true
		for abscisse in ville.gares():
			var quai := FormesCarnage.quai()
			quai.position = Decor.vers3d(ville.point_de_voie(float(abscisse)))
			quai.rotation.y = -ville.cap_de_voie()
			monde().add_child(quai)
		# LES CASSES vivent au bord de la même voie : c'est la seule bande de
		# la ville que personne n'habite, et c'est là qu'on entasse des
		# carcasses. Elles se posent avec les quais parce qu'elles se calculent
		# comme eux — une fois, à partir du code de la manche.
		for c in ville.casses():
			var machine := FormesCarnage.compacteur()
			machine.position = Decor.vers3d(Vector2(c["p"]))
			machine.rotation.y = -ville.cap_de_voie()
			monde().add_child(machine)
			_compacteurs.append(machine)
	var cap := ville.cap_de_voie()
	for t in ville.trains:
		var noeud = t.get("noeud")
		if noeud == null:
			noeud = FormesCarnage.rame_de_train(VilleVivante.WAGONS)
			monde().add_child(noeud)
			t["noeud"] = noeud
		t["age"] = float(t.get("age", 0.0)) + delta
		var s_vue := float(t["s"]) + float(t["sens"]) * float(t["v"]) * float(t["age"])
		var tete := ville.point_de_voie(s_vue)
		var rame: Node3D = noeud
		rame.position = Decor.vers3d(tete)
		# La rame est bâtie vers -X depuis sa tête : tournée du cap de la voie
		# elle recule, tournée du cap opposé elle avance. C'est `sens` qui
		# tranche — et sans lui la motrice poussait le convoi une fois sur deux.
		rame.rotation.y = -(cap if float(t["sens"]) > 0.0 else cap + PI)
	_sentir_le_train(delta)

## Ce que le joueur entend et lit du train : le roulement quand il passe, et
## l'annonce quand une rame s'arrête à portée. Sans l'annonce, un train à quai
## ressemble exactement à un train en panne — on ne devine pas qu'`E` y fait
## quelque chose.
func _sentir_le_train(delta: float) -> void:
	_quai_dit = max(0.0, _quai_dit - delta)
	if _train >= 0:
		return
	for t in ville.trains:
		var ou: Vector2 = ville.point_de_voie(float(t["s"]))
		var d := ou.distance_to(_position)
		if float(t["v"]) > 300.0 and d < 900.0:
			_depuis_roulement -= delta
			if _depuis_roulement <= 0.0:
				_depuis_roulement = 0.42
				Sons.jouer("roulement", _rng.randf_range(0.93, 1.07), -16.0 - 12.0 * (d / 900.0))
			# Le klaxon, rare et fort : c'est lui qui fait lever la tête quand
			# on roule vers la voie sans avoir vu la rame arriver. Le
			# roulement seul ne se distingue pas d'un moteur de camion.
			_depuis_corne -= delta
			if _depuis_corne <= 0.0 and d < 620.0:
				_depuis_corne = _rng.randf_range(7.0, 13.0)
				Sons.jouer("train_klaxon", _rng.randf_range(0.95, 1.05), -12.0 - 8.0 * (d / 620.0))
		elif float(t["v"]) <= 300.0 and d < 400.0:
			# À l'approche d'un quai, le freinage. Un train qui s'arrête en
			# silence ressemble à un train en panne.
			_depuis_roulement -= delta
			if _depuis_roulement <= 0.0:
				_depuis_roulement = 2.2
				Sons.jouer("train_arrive" if float(t["arret"]) <= 0.0 else "train_part",
					1.0, -15.0 - 8.0 * (d / 400.0))
	if not _pied or _quai_dit > 0.0:
		return
	var quai := ville.rame_a_quai(_position)
	if not quai.is_empty() and ville.point_de_voie(float(quai["s"])).distance_to(_position) \
			< PORTEE_TRAIN + VilleVivante.longueur_de_rame():
		_quai_dit = 4.0
		_annoncer("train à quai — E pour monter", Palette.AVERTISSEMENT, 2.6)

## VOYAGER. Le passager n'a rien à piloter : il se tient dans la rame et
## regarde la ville défiler. `E` le fait descendre — mais seulement à l'arrêt,
## sinon on saute d'un train lancé à neuf cents pixels par seconde, ce qui
## dans ce jeu veut dire « on apparaît dans un mur ».
func _voyager(delta: float) -> void:
	var t := ville.train_par_id(_train)
	if t.is_empty():
		# La rame a disparu (changement d'hôte, instantané perdu) : on remet le
		# joueur sur ses pieds là où il est plutôt que de le laisser voyager
		# dans un train qui n'existe plus.
		_train = -1
		return
	var s_vue := float(t["s"]) + float(t["sens"]) * float(t["v"]) * float(t.get("age", 0.0))
	_position = ville.point_de_voie(s_vue - float(t["sens"]) * _place_train)
	_angle = ville.cap_de_voie() if float(t["sens"]) > 0.0 else ville.cap_de_voie() + PI
	_vitesse = float(t["v"])
	_regenerer(delta)
	if float(t["arret"]) > 0.0:
		_affaire = ""
		if _quai_dit <= 0.0:
			_quai_dit = 3.0
			_annoncer("à quai — E pour descendre", Palette.AVERTISSEMENT, 2.4)

func _monter_dans_le_train() -> bool:
	var t := ville.rame_a_quai(_position)
	if t.is_empty():
		return false
	if ville.point_de_voie(float(t["s"])).distance_to(_position) \
			> PORTEE_TRAIN + VilleVivante.longueur_de_rame():
		return false
	_train = int(t["id"])
	# On se tient au milieu de la rame : monté en tête, on dépassait de la
	# motrice dès le premier virage de caméra.
	_place_train = VilleVivante.longueur_de_rame() * 0.5
	_vitesse = 0.0
	_eteindre_la_radio()
	Sons.jouer("porte_glissante", 1.0, -8.0)
	Sons.jouer("train_part", 0.95, -13.0)
	_annoncer("en route", Palette.BON, 2.0)
	return true

func _descendre_du_train() -> void:
	var t := ville.train_par_id(_train)
	if not t.is_empty() and float(t["arret"]) <= 0.0:
		_annoncer("attendez le prochain quai", Palette.SERIEUX, 2.0)
		return
	_train = -1
	# On descend DU CÔTÉ DU QUAI. La dalle est posée à +Z du repère de la voie
	# (voir `FormesCarnage.quai`) : descendre de l'autre côté, c'est atterrir
	# sur le ballast, hors de portée de tout.
	var cote := Vector2.RIGHT.rotated(ville.cap_de_voie() + PI * 0.5) * 34.0
	_position = carte.degager(_position + cote, RAYON_A_PIED)[0]
	Sons.jouer("porte_glissante", 0.9, -8.0)

## La jauge est fille de son porteur : sans compenser la rotation, elle
## tournerait avec lui et deviendrait illisible dès le premier virage.
## L'ANNEAU D'HUMEUR sous un homme de gang : rouge il vous tire dessus, vert
## il se battra à côté de vous. C'est l'idée du guide (§3.4) — « changer la
## couleur des piétons selon le respect » — mais l'anneau plutôt que le
## personnage : sa couleur À LUI dit de quel gang il est, et sept gangs qui
## changeraient tous de teinte selon l'humeur, on ne saurait plus qui l'on
## abat. Rien sous les pieds d'un neutre : un anneau permanent sous chaque
## passant en couleurs, c'est une guirlande, plus une information.
##
## La teinte n'est refaite que lorsque l'humeur CHANGE : une matière neuve par
## image et par passant, c'est quatre-vingts matières par image à la poubelle.
func _regler_humeur(personne: Dictionary, corps: Node3D) -> void:
	if int(personne["genre"]) != VilleVivante.GANG:
		return
	var etat := ville.humeur(Session.cle, int(personne["gang"]))
	var anneau := corps.get_node_or_null("Humeur") as MeshInstance3D
	if etat == VilleVivante.H_NEUTRE:
		if anneau != null:
			anneau.visible = false
		return
	if anneau == null:
		anneau = FormesCarnage.anneau_humeur(Palette.ENCRE_DOUCE)
		corps.add_child(anneau)
		personne["humeur_vue"] = -1
	anneau.visible = true
	if int(personne.get("humeur_vue", -1)) == etat:
		return
	personne["humeur_vue"] = etat
	anneau.material_override = Decor.matiere_lumineuse(FormesCarnage.COULEURS_HUMEUR[etat], 1.5)

func _regler_jauge(porteur: Node3D, part: float) -> void:
	var jauge := porteur.get_node_or_null("Vie") as Node3D
	if jauge == null:
		return
	jauge.rotation.y = -porteur.rotation.y
	jauge.visible = part < 0.999
	if jauge.visible:
		Decor.remplir(jauge, clamp(part, 0.0, 1.0))

## Une position d'intérieur (en TUILES) dans le monde 3D. Un seul endroit où le
## facteur passe : `Interieurs.ECHELLE`. La faute qui coûte cher ici est de
## mélanger tuiles et pixels de jeu — elle ne se voit pas, elle donne juste un
## personnage dix fois trop loin.
func _dedans3d(p: Vector2, hauteur: float = 0.0) -> Vector3:
	return Interieurs.SOUS_SOL + Vector3(p.x * Interieurs.ECHELLE, hauteur, p.y * Interieurs.ECHELLE)

# ------------------------------------------------------ la vue subjective
#
## LA PREMIÈRE PERSONNE. Carnage se joue de haut, à soixante-douze degrés : on
## voit la rue, les voitures qui arrivent, le tag au coin. C'est la vue de
## GTA 2 et ce n'est pas négociable pour jouer — mais c'est aussi une vue qui
## ne montre jamais une FAÇADE. Deux cent trente-neuf modèles de kit, des
## néons, des vitrines, des enseignes : personne ne les a jamais vus autrement
## qu'en plan.
##
## ⚠ ELLE NE REMPLACE PAS LA VUE DU JEU, elle s'y ajoute — `V` bascule. Une
## partie entière en vue subjective serait injouable : on ne voit pas la
## voiture qui arrive par la droite, et tout l'équilibre du jeu (les portées,
## le rayon des lieux, le radar) est réglé pour une caméra haute.
##
## ⚠ ON NE MONTRE PAS SON PROPRE PANTIN. En vue subjective, la tête du
## personnage est exactement là où est l'œil : on regarde l'intérieur de son
## crâne, et l'écran devient une texture de peau. Le corps se cache tant que la
## vue dure — c'est ce que fait n'importe quel jeu à la première personne, et
## ça ne se devine qu'en l'essayant.
const HAUTEUR_OEIL_PIED := 3.0      ## unités 3D : la tête du pantin
const HAUTEUR_OEIL_AUTO := 2.2      ## assis, un peu plus bas
const AVANCE_OEIL := 1.1            ## devant le nez, pour ne pas voir sa propre nuque
const FOV_SUBJECTIF := 78.0         ## large : de près, 54° donne un tunnel

var _subjectif := false

func _basculer_la_vue() -> void:
	_subjectif = not _subjectif
	if _camera != null:
		_camera.fov = FOV_SUBJECTIF if _subjectif else 54.0
	# La caméra saute d'un coup : interpolée depuis quarante unités de haut,
	# elle traverse les immeubles pendant une seconde et demie.
	_placer_camera(1000.0)
	_annoncer("vue subjective" if _subjectif else "vue de dessus", Palette.SERIE, 1.6)
	Sons.jouer("clic", 1.2, -14.0)

## Où est l'œil, et vers quoi il regarde. Séparé du placement pour que le banc
## d'image puisse le demander sans faire tourner une manche.
func oeil() -> Array:
	var haut := HAUTEUR_OEIL_PIED if _pied else HAUTEUR_OEIL_AUTO
	var devant := Vector2.RIGHT.rotated(_angle)
	var ou := Decor.vers3d(_position + devant * AVANCE_OEIL, haut)
	return [ou, ou + Decor.vers3d(devant * 40.0, -1.5)]

func _placer_camera(delta: float) -> void:
	if _camera == null:
		return
	# LA VUE SUBJECTIVE passe avant tout le reste — sauf chez soi, où elle n'a
	# rien à montrer qu'on ne voie déjà : un appartement se regarde en entier.
	if _subjectif and _dedans == "":
		var vu := oeil()
		_camera.position = (_camera.position as Vector3).lerp(vu[0], clamp(delta * 14.0, 0, 1))
		# ⚠ `look_at` refuse deux points confondus, et ça arrive : à l'arrêt,
		# à la première image, la caméra n'a pas encore bougé vers l'œil.
		if _camera.position.distance_to(vu[1]) > 0.05:
			_camera.look_at(vu[1], Vector3.UP)
		if _secousse > 0.0:
			_secousse = max(0.0, _secousse - delta * 2.0)
			_camera.rotation.z = _rng.randf_range(-1.0, 1.0) * _secousse * 0.06
		return
	if _dedans != "":
		# Chez soi, la caméra ne suit pas : elle cadre l'appartement entier
		# (`Interieurs.cadre`, la MÊME que le banc de photo).
		var ecran := Vector2(get_viewport().get_visible_rect().size)
		var c: Dictionary = Interieurs.cadre(_dedans, ecran.x / maxf(ecran.y, 1.0),
			_camera.fov, INCLINAISON)
		var recul: float = c["recul"]
		var vu: Vector3 = (c["centre"] as Vector3) + Vector3(0.0,
			sin(deg_to_rad(INCLINAISON)) * recul, cos(deg_to_rad(INCLINAISON)) * recul)
		_camera.position = _camera.position.lerp(vu, clamp(delta * 7.0, 0, 1))
		return
	var distance: float = DISTANCE_PIED if _pied else DISTANCE_AUTO + RECUL_VITESSE * clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0)
	# Un peu d'avance dans le sens de la marche : on regarde où l'on va.
	var avance := Vector2.RIGHT.rotated(_angle) * _vitesse * 0.22 if not _pied else Vector2.ZERO
	var vise := Decor.viser(_camera, _position + avance, INCLINAISON, distance)
	if _secousse > 0.0:
		_secousse = max(0.0, _secousse - delta * 2.0)
		vise += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _secousse * 2.5
	_camera.position = _camera.position.lerp(vise, clamp(delta * 7.0, 0, 1))

# ------------------------------------------------------- état affiché

## La fiche du HUD : les étoiles d'abord — c'est ce qui décide de la minute qui
## vient — puis les jauges, l'arme, et l'humeur du quartier en puces. La ligne
## de texte d'autrefois mettait sept mentions bout à bout ; on ne lisait rien
## en conduisant.
## La fortune : ce qui compte au classement. L'argent sur soi et celui de la
## planque, plus la valeur de la planque elle-même.
func fortune() -> int:
	var valeur := 0
	if _planque >= 0:
		var pl := carte.planque_par_id(_position, _planque)
		valeur = int(pl.get("prix", 0)) if not pl.is_empty() else 0
		for cle in _ameliorations:
			if bool(_ameliorations[cle]):
				valeur += int(PlanVille.PRIX_AMELIORATION[cle])
	return _argent + _banque + valeur

func fiche_joueur() -> Dictionary:
	var fiche := {"etoiles": ville.etoiles(Session.cle)}
	var jauges: Array = []
	jauges.append({"nom": "VIE", "part": _vie / 100.0, "couleur": Palette.BON, "valeur": "%d" % int(_vie)})
	if not _pied:
		jauges.append({"nom": "TÔLE", "part": _pv_vehicule / PV_VOITURE,
			"couleur": Palette.SERIE, "valeur": "%d" % int(_pv_vehicule)})
	# LA FAIM ET LA SOIF, sous la vie et la tôle. Elles passent au rouge sous
	# le seuil du creux : la couleur change AVANT le chiffre, parce qu'on lit
	# une barre du coin de l'œil et un nombre seulement quand on le cherche.
	jauges.append({"nom": "FAIM", "part": _faim / FAIM_MAX,
		"couleur": Palette.SERIEUX if _faim > SEUIL_CREUX else Palette.CRITIQUE,
		"valeur": "%d" % int(_faim)})
	jauges.append({"nom": "SOIF", "part": _soif / FAIM_MAX,
		"couleur": Color("#4aa8e0") if _soif > SEUIL_CREUX else Palette.CRITIQUE,
		"valeur": "%d" % int(_soif)})
	fiche["jauges"] = jauges
	fiche["arme"] = {"nom": String(ARMES[_arme]["nom"]), "munitions": "" if _munitions < 0 else "%d" % _munitions}
	fiche["argent"] = {"sur_soi": _argent, "banque": _banque, "planque": _planque >= 0}

	var puces: Array = []
	if _mot_affaire_reste > 0.0:
		puces.append({"texte": _mot_affaire, "couleur": Palette.AVERTISSEMENT})
	elif _affaire != "":
		puces.append({"texte": _affaire, "couleur": Palette.SERIE})
	if _hors_service > 0.0:
		puces.append({"texte": "à terre — %d s" % int(ceil(_hors_service)), "couleur": Palette.CRITIQUE})
	if _eperon > 0.0:
		puces.append({"texte": "éperon %ds" % int(ceil(_eperon)), "couleur": Palette.SERIEUX})
	var territoire := carte.territoire(_position)
	if territoire >= 0:
		puces.append(ville.puce_de_gang(Session.cle, territoire))
	else:
		puces.append({"texte": "terrain neutre", "couleur": Palette.ENCRE_FAIBLE})
	# Les trois gangs DU DISTRICT, dans l'ordre du trio : deux locaux, puis le
	# Consortium qui est partout. C'est la lecture qui manquait pour choisir
	# son camp — on voyait ce qu'un gang pensait de soi, jamais ce qu'on avait
	# à y gagner ailleurs.
	fiche["respect"] = ville.barres_de_respect(Session.cle, _position)
	if carte.arene_de(_position) >= 0:
		puces.append({"texte": "ARÈNE — tir ami", "couleur": Palette.CRITIQUE})
	if carte.garage_de(_position) >= 0:
		puces.append({"texte": "atelier" if _atelier_ici() >= 0 else "garage",
			"couleur": Palette.SERIE})
	if _plaques > 0.0:
		puces.append({"texte": "plaques %ds" % int(ceil(_plaques)), "couleur": Color("#5aa0e0")})
	if not _frenzy.is_empty():
		puces.append({"texte": "FRENZY %d/%d" % [int(_frenzy["f"]), int(_frenzy["n"])],
			"couleur": Palette.CRITIQUE})
	if _colis_sur > 0:
		puces.append({"texte": "colis %d/%d" % [_colis, _colis_sur], "couleur": Color("#f0c04a")})
	if _cascade > 1:
		puces.append({"texte": "cascade ×%d" % _cascade, "couleur": Palette.SERIE})
	if not _pied and _station != Sons.STATION_SILENCE and _station_dite > 0.0:
		var station: Dictionary = Sons.STATIONS[_station]
		puces.append({"texte": "♪ %s" % String(station["nom"]), "couleur": station["couleur"]})
	# L'INVENTAIRE, une puce par sorte d'article avec son compte. Il ne
	# s'affiche que s'il y a quelque chose : une ligne « 0 provision » sur un
	# tableau de bord déjà chargé, c'est du bruit permanent pour une
	# information qu'on connaît.
	for cle in _provisions:
		var article := Provisions.fiche(String(cle))
		puces.append({"texte": "%s ×%d" % [String(article.get("nom", cle)).to_lower(),
			int(_provisions[cle])], "couleur": article.get("couleur", Palette.ENCRE_DOUCE)})
	if bool(_mods.get("mitrailleuse", false)):
		puces.append({"texte": "mitrailleuse", "couleur": Color("#f2c53d")})
	for quoi in ["mines", "huile"]:
		if int(_mods.get(quoi, 0)) > 0:
			puces.append({"texte": "%s ×%d" % [quoi, int(_mods[quoi])],
				"couleur": Color("#d0402c") if quoi == "mines" else Color("#6a5a7a")})
	if bool(_mods.get("bombe", false)):
		puces.append({"texte": "bombe armée", "couleur": Color("#e07a3c")})
	if _pied:
		var auto := ville.vehicule_proche(_position, PORTEE_ENTREE)
		puces.append({"texte": "E : monter" if not auto.is_empty() else "à pied", "couleur": Palette.AVERTISSEMENT if not auto.is_empty() else Palette.ENCRE_DOUCE})
	if _hors_ville > 0.2:
		puces.append({"texte": "VOUS QUITTEZ LA VILLE", "couleur": Palette.CRITIQUE})
	fiche["puces"] = puces
	fiche["accent"] = _ma_couleur()
	var alerte := _alerte_contrat()
	if not alerte.is_empty():
		fiche["alerte"] = alerte
	return fiche

## Les cabochons d'aide, en bas de l'écran. ⚠ Ils sont LUS dans les réglages,
## jamais écrits en dur : un joueur qui a remis « avancer » sur la flèche haut
## dans les options du hub lisait quand même « Z S » ici, et cherchait la
## panne dans le jeu. `Reglages.nom_de_touche` rend le nom GRAVÉ sur son
## clavier — « Z » sur un AZERTY là où le moteur dit « W ».
func aide_touches() -> Array:
	var t := func(action: String) -> String: return Reglages.nom_de_touche(action)
	return [
		["%s %s" % [t.call("avancer"), t.call("reculer")], "avancer, freiner"],
		["%s %s" % [t.call("gauche"), t.call("droite")], "tourner"],
		[t.call("tir"), "tirer"],
		[t.call("action"), "monter, descendre"],
		[t.call("klaxon"), "klaxon"],
		[t.call("carte"), "carte"],
	]
