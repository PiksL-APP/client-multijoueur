class_name MeteoCarnage
extends Node
## LA MÉTÉO DE LA VILLE : clair, couvert, pluie, orage, brouillard.
##
## Jusqu'ici la ville n'avait qu'une HEURE (`MatieresCarnage.nuit`) : le même
## ciel bleu à chaque manche, la même lumière rasante au même moment. Le temps
## qu'il fait est la seconde chose qui change une rue sans toucher à un cube —
## et la seule qui change d'une manche à l'autre. Il se lit comme l'heure : sur
## l'horloge universelle, pour que quatre joueurs voient la même averse.
##
## Un temps dure dix minutes ; le passage de l'un à l'autre se fond sur
## quarante-cinq secondes. Le tirage est FIXE pour un créneau donné
## (`hache(créneau)`), donc identique chez tout le monde sans un octet sur le
## réseau — c'est le même principe que le cycle du jour, et c'est pour ça que
## la météo ne passe pas par l'instantané de l'hôte.
##
## Ce que le temps fait :
##  • couvert : le soleil baisse et grise, l'ombre s'estompe (`shadow_opacity`),
##    le ciel vire au gris, l'ombre des nuages au sol disparaît (elle n'a plus
##    de sens sous une chape uniforme) ;
##  • pluie : tout ça, plus le bitume mouillé de JOUR (flaques, reflets, éclats
##    d'impacts au sol), des traînées de pluie à l'écran, un bruit de pluie
##    synthétisé, et 18 % d'adhérence en moins au volant ;
##  • orage : la pluie, plus des éclairs — le ciel blanchit un dixième de
##    seconde, le tonnerre arrive avec le retard de la distance ;
##  • brouillard : la brume monte jusqu'à manger l'horizon, le soleil est
##    voilé, le ciel se confond avec le sol.
##
## ⚠ PAS UNE SEULE PARTICULE. Le mode compatibilité (WebGL 2) dessine mal les
## GPUParticles et les CPUParticles coûtent ce qu'elles coûtent : la pluie est
## un calque d'écran (`MatieresCarnage.POST`) et les impacts un scintillement
## par cellule dans le shader du sol. C'est ce que GTA 2 faisait — des traits
## par-dessus l'image — et vu de haut, c'est ce qui se lit le mieux.

const CYCLE := 600.0          ## un temps dure dix minutes
const TRANSITION := 45.0      ## et met quarante-cinq secondes à s'installer

enum {CLAIR, COUVERT, PLUIE, ORAGE, BROUILLARD, NEIGE}
const NOMS := ["clair", "couvert", "pluie", "orage", "brouillard", "neige"]

## Les quatre jauges d'un temps. Tout le reste s'interpole entre elles.
const TEMPS := [
	{"nuages": 0.0, "pluie": 0.0, "brume": 0.0, "orage": 0.0},
	{"nuages": 0.85, "pluie": 0.0, "brume": 0.15, "orage": 0.0},
	{"nuages": 0.95, "pluie": 0.8, "brume": 0.35, "orage": 0.0},
	{"nuages": 1.0, "pluie": 1.0, "brume": 0.45, "orage": 1.0},
	{"nuages": 0.6, "pluie": 0.0, "brume": 1.0, "orage": 0.0},
	# LA NEIGE : une chape claire, l'air un peu voilé, et la jauge `neige`
	# qui blanchit les toits, les trottoirs et les arbres. Rare — c'est ce qui
	# fait qu'on s'en souvient.
	{"nuages": 0.75, "pluie": 0.0, "brume": 0.25, "orage": 0.0, "neige": 1.0},
]
## Les poids du tirage : quatre créneaux sur dix au beau, l'orage et le
## brouillard rares — un temps rare se remarque, un temps fréquent s'oublie.
const TIRAGE := [CLAIR, CLAIR, CLAIR, CLAIR, COUVERT, COUVERT, PLUIE, PLUIE, ORAGE, BROUILLARD,
	CLAIR, NEIGE]

## Le banc et les codes : `--meteo=pluie` ou le code MÉTÉO figent un temps.
static var meteo_forcee := -1

## L'état courant, lu par le jeu (adhérence) et les bancs.
var nuages := 0.0
var pluie := 0.0
var brume := 0.0
var orage := 0.0
var neige := 0.0
var eclair := 0.0             ## l'éclair en cours, de 1 à 0 en un dixième de seconde

var _prochain_eclair := 6.0
var _tonnerre_dans := -1.0
var _rng := RandomNumberGenerator.new()
var _pluie_son: AudioStreamPlayer
var _nappe: MeshInstance3D = null      ## la nappe de brume au ras du sol
var _tonnerre: Callable = Callable()   ## (retard, force) -> void, posé par le jeu

func _init() -> void:
	_rng.seed = 7

## Le temps au créneau `k` de l'horloge : le même pour tous.
static func temps_au_creneau(k: int) -> int:
	if meteo_forcee >= 0:
		return meteo_forcee
	# Un hachage entier, pas `randi` : deux machines doivent tomber pareil.
	var h := int(posmod(k * 2654435761, 4294967296))
	return TIRAGE[posmod(h >> 7, TIRAGE.size())]

static func nom_du_temps(indice: int) -> String:
	return NOMS[clampi(indice, 0, NOMS.size() - 1)]

static func indice_du_temps(nom: String) -> int:
	return NOMS.find(nom)

## Les quatre jauges à l'instant `t` (secondes universelles) : le créneau en
## cours, fondu depuis le précédent pendant la transition.
static func jauges(t: float) -> Dictionary:
	var k := int(floor(t / CYCLE))
	var f := clampf(fmod(t, CYCLE) / TRANSITION, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var a: Dictionary = TEMPS[temps_au_creneau(k - 1)]
	var b: Dictionary = TEMPS[temps_au_creneau(k)]
	var r := {}
	for cle in ["nuages", "pluie", "brume", "orage", "neige"]:
		r[cle] = lerpf(float(a.get(cle, 0.0)), float(b.get(cle, 0.0)), f)
	return r

func temps_courant() -> int:
	return temps_au_creneau(int(floor(Time.get_unix_time_from_system() / CYCLE)))

## Ce que le jeu appelle pour le tonnerre : (retard en secondes, force 0-1).
func brancher_le_tonnerre(quoi: Callable) -> void:
	_tonnerre = quoi

## À appeler à chaque image, APRÈS `MatieresCarnage.regler_heure` : on
## retouche ce qu'il a réglé, on ne le remplace pas.
func appliquer(delta: float, monde: WorldEnvironment, soleil: DirectionalLight3D, n: float,
		centre: Vector3 = Vector3.ZERO) -> void:
	var j := jauges(Time.get_unix_time_from_system())
	nuages = float(j["nuages"])
	pluie = float(j["pluie"])
	brume = float(j["brume"])
	orage = float(j["orage"])
	neige = float(j["neige"])
	_animer_les_eclairs(delta)

	var env := monde.environment
	var ciel := env.sky.sky_material as ProceduralSkyMaterial
	# LE GRIS DU CIEL suit l'heure : une chape claire le jour, un plafond
	# d'encre la nuit — un gris de jour sur une nuit noire ferait une aube.
	var gris_haut := Color("#5f6a78").lerp(Color("#0a0d14"), n)
	var gris_bas := Color("#9aa3ad").lerp(Color("#161a22"), n)
	var voile := maxf(nuages * 0.85, brume * 0.95)
	ciel.sky_top_color = ciel.sky_top_color.lerp(gris_haut, voile)
	ciel.sky_horizon_color = ciel.sky_horizon_color.lerp(gris_bas, voile)
	ciel.ground_horizon_color = ciel.ground_horizon_color.lerp(gris_bas * 0.8, voile)
	# Le soleil sous les nuages : plus faible, plus blanc, et une ombre qui
	# s'adoucit — sous une chape, rien ne dessine une ombre nette au sol.
	# ⚠ PAS PLUS BAS QUE LA MOITIÉ, et l'ombre reste : la première version
	# coupait le soleil de moitié, montait l'ambiante de trente pour cent et
	# effaçait l'ombre aux trois quarts — il ne restait qu'une bouillie
	# grise sans relief. Un jour de pluie a des ombres, douces.
	# ⚠ Moins fort la nuit : la « lumière du soleil » y est déjà la lueur bleue
	# de 0,28, et lui retirer encore la moitié faisait une ville où l'on ne
	# distinguait plus la rue du trottoir.
	soleil.light_energy *= 1.0 - (0.4 * nuages + 0.2 * brume) * (1.0 - 0.6 * n)
	soleil.light_color = soleil.light_color.lerp(Color("#dfe3e8"), nuages * 0.6)
	soleil.shadow_opacity = 1.0 - 0.45 * maxf(nuages, brume)
	env.ambient_light_energy *= 1.0 + 0.12 * nuages
	# La neige RENVOIE la lumière : l'ambiante monte franchement, et bleuit.
	env.ambient_light_energy *= 1.0 + 0.2 * neige
	env.ambient_light_color = env.ambient_light_color.lerp(Color("#b8c4d8"), neige * 0.5 * (1.0 - n))
	env.ambient_light_color = env.ambient_light_color.lerp(Color("#9aa0a8").lerp(Color("#232a38"), n), voile * 0.5)
	# Le brouillard d'ambiance ne fait qu'un peu : vu de dessus, c'est un
	# voile uniforme. La brume qui se voit est la NAPPE au ras du sol (voir
	# `MatieresCarnage.BRUME`).
	env.fog_density += 0.0016 * brume + 0.0005 * pluie
	env.fog_light_color = env.fog_light_color.lerp(Color("#a9b0b8").lerp(Color("#1a1e26"), n), maxf(brume, nuages * 0.5))
	env.fog_sky_affect = 0.35 + 0.5 * brume
	_poser_la_nappe(centre, n)
	# L'air chargé d'eau fait baver les lumières : le halo monte un peu sous
	# l'averse — les enseignes et les phares s'auréolent, la rue « brille ».
	env.glow_intensity += 0.3 * pluie
	# L'ÉCLAIR : tout blanchit, ciel, ambiante et écran, le temps d'une image
	# ou deux. C'est l'ambiante qui fait « voir » l'éclair sur les façades.
	if eclair > 0.0:
		env.ambient_light_energy += 2.6 * eclair
		env.ambient_light_color = env.ambient_light_color.lerp(Color("#eef2ff"), eclair)
		ciel.sky_top_color = ciel.sky_top_color.lerp(Color("#e6ecff"), eclair * 0.7)
		ciel.sky_horizon_color = ciel.sky_horizon_color.lerp(Color("#f4f6ff"), eclair * 0.7)
	MatieresCarnage.regler_meteo(pluie, nuages, brume, eclair, orage, neige)
	_regler_le_bruit_de_pluie()

## La nappe de brume suit le joueur, à hauteur d'homme : les toits la
## percent, les rues baignent dedans. Sa couleur suit l'heure — une brume
## claire sur une nuit noire ferait une aube.
func _poser_la_nappe(centre: Vector3, n: float) -> void:
	if _nappe == null:
		_nappe = MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = Vector2(700.0, 700.0)
		_nappe.mesh = plan
		_nappe.material_override = MatieresCarnage.brume()
		_nappe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_nappe.name = "Brume"
		add_child(_nappe)
	_nappe.visible = brume > 0.01 or pluie > 0.01
	_nappe.position = Vector3(centre.x, 1.7, centre.z)
	MatieresCarnage.brume().set_shader_parameter("couleur",
		Color("#c9ced4").lerp(Color("#1c2029"), n))

## Un éclair toutes les cinq à seize secondes d'orage, jamais réglé comme une
## horloge ; le tonnerre suit avec le retard de la distance.
func _animer_les_eclairs(delta: float) -> void:
	eclair = maxf(0.0, eclair - delta * 7.0)
	# `--banc-eclair` : l'éclair tenu allumé, pour le photographier — un
	# dixième de seconde ne se prend pas au vol sous xvfb.
	if "--banc-eclair" in OS.get_cmdline_args():
		eclair = 1.0
	if _tonnerre_dans > 0.0:
		_tonnerre_dans -= delta
		if _tonnerre_dans <= 0.0 and _tonnerre.is_valid():
			_tonnerre.call(_rng.randf_range(0.55, 1.0))
	if orage < 0.5:
		return
	_prochain_eclair -= delta
	if _prochain_eclair <= 0.0:
		eclair = 1.0
		_prochain_eclair = _rng.randf_range(5.0, 16.0)
		_tonnerre_dans = _rng.randf_range(0.5, 2.6)

## LE BRUIT DE LA PLUIE, synthétisé : aucun fichier de pluie dans le dossier
## des sons, et une averse muette est une averse qu'on ne croit pas. Quatre
## secondes de bruit filtré (un souffle grave, des gouttes par-dessus), en
## boucle, dont le volume suit la jauge. Fabriqué à la première averse
## seulement : cent soixante-seize mille échantillons, ça ne se calcule pas
## au démarrage pour un temps qui ne viendra peut-être pas.
const TAUX := 22050
func _regler_le_bruit_de_pluie() -> void:
	if pluie <= 0.01:
		if _pluie_son != null and _pluie_son.playing:
			_pluie_son.stop()
		return
	if _pluie_son == null:
		_pluie_son = AudioStreamPlayer.new()
		_pluie_son.stream = _bruit_de_pluie()
		_pluie_son.bus = "Effets" if AudioServer.get_bus_index("Effets") >= 0 else "Master"
		add_child(_pluie_son)
	if not _pluie_son.playing:
		_pluie_son.play()
	_pluie_son.volume_db = lerpf(-30.0, -13.0, pluie)

func _bruit_de_pluie() -> AudioStreamWAV:
	var n := TAUX * 4
	var octets := PackedByteArray()
	octets.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var grave := 0.0
	var goutte := 0.0
	for i in n:
		var blanc := rng.randf_range(-1.0, 1.0)
		# Un passe-bas très doux : le souffle de fond.
		grave += (blanc - grave) * 0.08
		# Des gouttes : une impulsion brève, une fois sur trois cents.
		if rng.randf() < 0.0035:
			goutte = rng.randf_range(0.3, 0.9)
		goutte *= 0.86
		var v := clampf(grave * 1.6 + blanc * 0.12 + goutte * 0.5, -1.0, 1.0)
		var e := int(v * 30000.0)
		octets.encode_s16(i * 2, e)
	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = TAUX
	flux.stereo = false
	flux.data = octets
	flux.loop_mode = AudioStreamWAV.LOOP_FORWARD
	flux.loop_begin = 0
	flux.loop_end = n
	return flux
