class_name MatieresCarnage
extends RefCounted
## Les matières de CARNAGE : trois shaders et une ambiance.
##
## Pourquoi des shaders plutôt qu'un atlas de textures : la ville fait trois
## cent cinquante mille tuiles et se génère à la demande. Une texture de sol
## peinte en GDScript coûterait une demi-seconde de `set_pixel` au démarrage
## dans le navigateur et pixelliserait dès qu'on s'approche ; un shader dessine
## trottoirs, bandes, passages piétons et pavés à toute distance, sans un octet
## de texture, et anime l'eau par-dessus le marché. Même raison pour les
## façades : un immeuble est une BOÎTE, le shader y pose les étages, les
## fenêtres, et allume celles qu'il faut — deux cent mille fenêtres pour zéro
## sommet supplémentaire. C'est ce qui permet une ville cent fois plus grande
## avec MOINS d'appels de dessin qu'avant.
##
## Tout ceci tient en mode compatibilité (GLES3 / WebGL 2) : pas d'instance
## custom data, pas de texture 3D, pas de SSAO. La couleur d'instance des
## nappes porte la teinte ET le style (dans l'alpha) — c'est le seul canal par
## instance dont on soit sûr dans ce moteur de rendu.

static var _sol: ShaderMaterial
static var _facade: ShaderMaterial
static var _flaque: ShaderMaterial
static var _lumineux: ShaderMaterial

# ------------------------------------------------------------ le sol

const SOL := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// UV : coordonnées locales de la tuile, déjà tournées côté maillage.
// UV2.x : le type de sol (PlanVille.S_*), UV2.y : une graine.
// COLOR : la teinte du territoire, qui multiplie le sol.
varying vec2 uvl;
varying float sol;
varying float graine;
varying vec3 teinte;
varying vec3 posm;

void vertex() {
	uvl = UV;
	sol = UV2.x;
	graine = UV2.y;
	teinte = COLOR.rgb;
	posm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hache(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Bruit de valeur : la salissure du bitume, les taches du béton, l'herbe.
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hache(i);
	float b = hache(i + vec2(1.0, 0.0));
	float c = hache(i + vec2(0.0, 1.0));
	float d = hache(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

const float T = 0.2; // le trottoir : vingt pixels sur cent

vec3 trottoir_dalle(vec2 uv, vec3 base) {
	// Des dalles : un joint tous les dixièmes.
	vec2 j = abs(fract(uv * 10.0) - 0.5);
	float joint = step(0.46, max(j.x, j.y));
	return mix(base, base * 0.86, joint);
}

void fragment() {
	int k = int(sol + 0.5);
	vec3 asphalte = vec3(0.13, 0.14, 0.16);
	vec3 trottoir = vec3(0.40, 0.39, 0.36);
	vec3 bordure = vec3(0.22, 0.22, 0.21);
	vec3 blanc = vec3(0.85, 0.85, 0.80);
	vec3 jaune = vec3(0.90, 0.72, 0.25);
	vec3 col = trottoir;
	float rug = 0.85;
	float spec = 0.15;
	float grain = (bruit(posm.xz * 2.3) - 0.5) * 0.18 + (bruit(posm.xz * 9.0) - 0.5) * 0.08;
	vec3 emission = vec3(0.0);

	if (k <= 2) {
		// ROUTE / PASSAGE_A / PASSAGE_B : trottoir à gauche (u < T), axe à droite.
		if (uvl.x < T) {
			col = trottoir_dalle(uvl, trottoir);
			if (uvl.x > T - 0.03) col = bordure;
		} else {
			col = asphalte;
			rug = 0.55;
			spec = 0.35;
			// L'axe : une bande jaune pointillée, une moitié sur chaque tuile.
			if (uvl.x > 0.975 && fract(uvl.y * 2.0 + 0.25) < 0.55) col = jaune;
			// Le passage piéton, au bout qui touche le carrefour.
			bool zebra = (k == 1 && uvl.y > 0.05 && uvl.y < 0.21) || (k == 2 && uvl.y > 0.79 && uvl.y < 0.95);
			if (zebra && fract((uvl.x - T) * 7.0) < 0.5) col = mix(col, blanc, 0.55);
			// Usure : deux traces de roues plus sombres sur la voie.
			col *= 1.0 - 0.10 * (1.0 - smoothstep(0.0, 0.06, abs(uvl.x - 0.62))) - 0.10 * (1.0 - smoothstep(0.0, 0.06, abs(uvl.x - 0.88)));
		}
	} else if (k == 3) {
		// CARREFOUR : un quart de trottoir dans l'angle (u < T, v < T).
		col = asphalte;
		rug = 0.55;
		spec = 0.35;
		if (uvl.x < T && uvl.y < T) {
			col = trottoir_dalle(uvl, trottoir);
			if (uvl.x > T - 0.03 || uvl.y > T - 0.03) col = bordure;
		}
	} else if (k == 4) {
		col = trottoir_dalle(uvl, trottoir);
	} else if (k == 5) {
		// PAVÉS : petits carreaux, joints clairs, deux tons.
		vec2 c = floor(uvl * 8.0);
		float ton = hache(c + floor(posm.xz / 10.0) * 7.0);
		col = mix(vec3(0.36, 0.34, 0.33), vec3(0.46, 0.43, 0.40), ton);
		vec2 j = abs(fract(uvl * 8.0) - 0.5);
		col = mix(col, vec3(0.27, 0.26, 0.25), step(0.44, max(j.x, j.y)));
	} else if (k == 6 || k == 7 || k == 8 || k == 9) {
		// HERBE, et les allées d'un parc : une bande de sable au milieu.
		float h = bruit(posm.xz * 4.0);
		col = mix(vec3(0.17, 0.33, 0.14), vec3(0.28, 0.45, 0.18), h);
		rug = 0.95;
		spec = 0.05;
		bool allee = (k == 7 && abs(uvl.x - 0.5) < 0.17) || (k == 8 && abs(uvl.y - 0.5) < 0.17)
			|| (k == 9 && (abs(uvl.x - 0.5) < 0.17 || abs(uvl.y - 0.5) < 0.17));
		if (allee) {
			col = mix(vec3(0.55, 0.48, 0.36), vec3(0.62, 0.55, 0.42), h);
			rug = 0.8;
		}
	} else if (k == 10) {
		// BÉTON : des dalles larges, tachées.
		col = vec3(0.33, 0.33, 0.32) * (0.85 + 0.3 * bruit(posm.xz * 0.7));
		vec2 j = abs(fract(uvl * 2.0) - 0.5);
		col = mix(col, col * 0.8, step(0.47, max(j.x, j.y)));
		// Une flaque d'huile de temps en temps.
		float tache = bruit(posm.xz * 1.3 + graine * 40.0);
		col = mix(col, col * 0.55, smoothstep(0.62, 0.75, tache));
	} else if (k == 11) {
		// PARKING : du bitume et des places peintes en travers.
		col = asphalte * 1.15;
		rug = 0.6;
		spec = 0.3;
		float trait = step(0.97, fract(uvl.x * 2.2 + 0.05)) + step(0.97, 1.0 - fract(uvl.x * 2.2 + 0.05));
		if (trait > 0.0 && uvl.y > 0.1 && uvl.y < 0.9) col = mix(col, blanc, 0.6);
		if (abs(uvl.y - 0.1) < 0.012 && fract(uvl.x * 2.2 + 0.05) > 0.03) col = mix(col, blanc, 0.6);
	} else if (k == 12) {
		// EAU : sombre, une houle lente, un reflet du ciel qui bouge.
		float t = TIME * 0.6;
		float v = bruit(posm.xz * 0.35 + vec2(t * 0.3, t * 0.2)) * 0.6 + bruit(posm.xz * 1.1 - vec2(t * 0.2, t * 0.35)) * 0.4;
		col = mix(vec3(0.03, 0.09, 0.14), vec3(0.08, 0.20, 0.26), v);
		emission = vec3(0.10, 0.22, 0.30) * smoothstep(0.55, 0.85, v) * 0.6;
		rug = 0.12;
		spec = 0.7;
		grain = 0.0;
	} else {
		// TERRE
		col = mix(vec3(0.30, 0.24, 0.17), vec3(0.38, 0.31, 0.22), bruit(posm.xz * 2.0));
		rug = 0.95;
	}

	ALBEDO = col * teinte * (1.0 + grain);
	ROUGHNESS = rug;
	SPECULAR = spec;
	EMISSION = emission;
}
"""

# ------------------------------------------------------------ les façades

const FACADE := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// COLOR (couleur d'instance) : rgb la teinte du mur, a le style de façade sur
// huit (PlanVille.F_*). L'immeuble est une boîte unitaire mise à l'échelle :
// on retrouve son pied et son toit depuis la matrice.
varying vec3 posm;
varying vec3 nrm;
varying vec4 inst;
varying vec3 origine;
varying float bas;
varying float haut;
varying vec2 taille;

void vertex() {
	posm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	inst = COLOR;
	origine = MODEL_MATRIX[3].xyz;
	bas = (MODEL_MATRIX * vec4(0.0, -0.5, 0.0, 1.0)).y;
	haut = (MODEL_MATRIX * vec4(0.0, 0.5, 0.0, 1.0)).y;
	taille = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
}

float hache(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	int style = clamp(int(inst.a * 8.0 + 0.5), 0, 7);
	vec3 teinte = inst.rgb;
	float graine = hache(floor(origine.xz * 3.0));
	vec3 col = teinte;
	float rug = 0.9;
	float spec = 0.2;
	vec3 emission = vec3(0.0);

	if (nrm.y > 0.7) {
		// Le toit. La caméra est presque à la verticale : les toits sont ce
		// qu'on voit le plus. Du bitume gris à peine teinté, une margelle
		// claire, des blocs de climatisation et des bouches d'aération tirés
		// par cellule — et une croix d'hélistation sur les grandes tours.
		vec3 toit = mix(teinte * 0.4, vec3(0.22, 0.22, 0.24), 0.55);
		toit *= 0.9 + 0.2 * hache(floor(posm.xz * 2.0));
		toit *= 0.95 + 0.1 * hache(floor(posm.xz * 6.0));
		vec2 loc = (posm.xz - origine.xz) / taille;
		vec2 bord_u = (vec2(0.5) - abs(loc)) * taille;
		float au_bord = min(bord_u.x, bord_u.y);
		vec2 cell = floor(posm.xz / 2.5);
		vec2 fc = fract(posm.xz / 2.5);
		float hc = hache(cell + graine * 5.0);
		if (au_bord < 0.5) {
			toit = teinte * 0.8;
		} else if (au_bord < 0.75) {
			toit *= 0.55;
		} else if (au_bord > 1.4 && hc < 0.13 && fc.x > 0.2 && fc.x < 0.8 && fc.y > 0.2 && fc.y < 0.8) {
			toit = vec3(0.56, 0.57, 0.6);
			if (fc.x > 0.7 || fc.y > 0.7) toit *= 0.55;
			if (fc.x > 0.3 && fc.x < 0.7 && fc.y > 0.3 && fc.y < 0.7) toit *= 0.7;
		} else if (hc > 0.94 && fc.x > 0.38 && fc.x < 0.62 && fc.y > 0.38 && fc.y < 0.62) {
			toit = vec3(0.09, 0.09, 0.1);
		}
		if (style == 7 && min(taille.x, taille.y) > 15.0) {
			float r = length(loc * taille);
			if (abs(r - 4.2) < 0.35 || (r < 3.0 && (abs(loc.x * taille.x) < 0.35 || abs(loc.y * taille.y) < 0.35))) toit = vec3(0.75, 0.75, 0.7);
		}
		ALBEDO = toit;
		ROUGHNESS = 0.95;
		SPECULAR = 0.1;
	} else if (nrm.y < -0.5) {
		ALBEDO = teinte * 0.3;
	} else {
		// Le long du mur : u suit la façade, v monte depuis le pied.
		float u = posm.x * nrm.z - posm.z * nrm.x;
		float v = posm.y - bas;
		float hauteur = haut - bas;
		float etage = 3.0;
		float pas = 2.6;
		if (style == 5) { etage = 2.4; pas = 2.2; }
		if (style == 3) { etage = 2.8; pas = 2.3; }
		if (style == 7) { etage = 3.2; pas = 1.9; }
		vec2 cellule = vec2(floor(u / pas), floor(v / etage));
		vec2 f = vec2(fract(u / pas), fract(v / etage));
		float dernier = floor((hauteur - 0.01) / etage);
		bool rez = cellule.y < 0.5;
		bool fenetre = false;
		float part = 0.5;
		if (style == 0) { fenetre = f.x > 0.14 && f.x < 0.86 && f.y > 0.28 && f.y < 0.82; part = 0.48; }
		else if (style == 1) { fenetre = f.x > 0.28 && f.x < 0.72 && f.y > 0.32 && f.y < 0.78; part = 0.52; }
		else if (style == 2) {
			if (rez) { fenetre = f.x > 0.05 && f.x < 0.95 && f.y > 0.12 && f.y < 0.78; part = 0.85; }
			else { fenetre = f.x > 0.26 && f.x < 0.74 && f.y > 0.32 && f.y < 0.78; part = 0.55; }
		}
		else if (style == 3) { fenetre = f.x > 0.32 && f.x < 0.68 && f.y > 0.34 && f.y < 0.80; part = 0.46; }
		else if (style == 4) { fenetre = v > hauteur * 0.55 && f.x > 0.08 && f.x < 0.92 && f.y > 0.35 && f.y < 0.65; part = 0.35; }
		else if (style == 5) { fenetre = f.x > 0.3 && f.x < 0.7 && f.y > 0.36 && f.y < 0.76; part = 0.6; }
		else if (style == 7) { fenetre = f.x > 0.07 && f.y > 0.10 && f.y < 0.92; part = 0.42; }
		// Le dernier étage entamé n'a pas de fenêtre : une fenêtre coupée par le
		// toit se lit comme un défaut.
		if (cellule.y > dernier - 0.5 && fract(hauteur / etage) < 0.6) fenetre = false;

		if (fenetre) {
			float a = hache(cellule + vec2(graine * 91.0, graine * 17.0));
			if (a < part) {
				vec3 chaud = vec3(1.0, 0.80, 0.52);
				vec3 froid = vec3(0.62, 0.82, 1.0);
				vec3 lum = mix(chaud, froid, step(0.72, hache(cellule * 3.1 + graine)));
				float force = 0.75 + 0.5 * hache(cellule * 1.7 + graine * 3.0);
				col = lum * 0.5;
				emission = lum * force * 1.1;
				rug = 0.35;
			} else {
				col = vec3(0.07, 0.09, 0.13);
				rug = 0.15;
				spec = 0.7;
			}
		} else {
			// Le mur : un liseré plus sombre à chaque plancher, un grain léger.
			col = teinte * (0.92 + 0.10 * hache(cellule + graine));
			if (style == 0 || style == 7) { if (f.y < 0.08) col *= 0.75; }
			if (style == 3 && f.y > 0.92) col *= 0.8;
			if (style == 4 && fract(u / 1.2) < 0.08) col *= 0.82;
			// Le store d'une boutique, au-dessus de la vitrine.
			if (style == 2 && rez && f.y >= 0.78 && f.y < 0.9) {
				float h = hache(vec2(cellule.x * 0.0 + graine * 7.0, 1.0));
				col = mix(vec3(0.7, 0.25, 0.2), vec3(0.2, 0.35, 0.6), step(0.5, h));
				if (h > 0.8) col = vec3(0.75, 0.6, 0.2);
			}
			// Une porte au rez-de-chaussée.
			if (rez && style != 4 && style != 7 && style != 2 && f.x > 0.42 && f.x < 0.58 && f.y < 0.62 && hache(cellule.xx + graine) < 0.35) col = teinte * 0.35;
		}
		ALBEDO = col;
		ROUGHNESS = rug;
		SPECULAR = spec;
		EMISSION = emission;
	}
}
"""

# ------------------------------------------------------------ les lumières

## Une flaque de lumière au sol : un quadrilatère additif à dégradé radial. La
## couleur vient du sommet, la force de son alpha. C'est ce qui fait la nuit
## sous les lampadaires et devant les phares, sans une seule vraie lumière —
## le mode compatibilité n'en supporte que huit par objet.
const FLAQUE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

varying vec4 c;
varying vec2 uvl;

void vertex() {
	c = COLOR;
	uvl = UV;
}

void fragment() {
	float d = length(uvl - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.7) * c.a;
	ALBEDO = c.rgb * a;
	ALPHA = 1.0;
}
"""

## Les enseignes et balises : de la couleur pure, sans éclairage, qui passe
## le seuil du halo.
const LUMINEUX := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

varying vec4 c;

void vertex() {
	c = COLOR;
}

void fragment() {
	ALBEDO = c.rgb;
	EMISSION = c.rgb * 0.6;
}
"""

static func _materiau(source: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = source
	var m := ShaderMaterial.new()
	m.shader = shader
	return m

static func sol() -> ShaderMaterial:
	if _sol == null:
		_sol = _materiau(SOL)
	return _sol

static func facade() -> ShaderMaterial:
	if _facade == null:
		_facade = _materiau(FACADE)
	return _facade

static func flaque() -> ShaderMaterial:
	if _flaque == null:
		_flaque = _materiau(FLAQUE)
	return _flaque

static func lumineux() -> ShaderMaterial:
	if _lumineux == null:
		_lumineux = _materiau(LUMINEUX)
	return _lumineux

# ------------------------------------------------------------ l'ambiance

## L'heure bleue. Un ciel qui vire du bleu profond à l'orange à l'horizon, un
## soleil bas et chaud qui allonge les ombres, une ambiante bleue qui garde
## les façades lisibles, et le halo qui fait rayonner fenêtres, enseignes et
## lampadaires. GTA 2 se jouait la nuit ; une ville s'impose au crépuscule,
## quand ses lumières s'allument et qu'on lit encore la rue.
static func crepuscule() -> Array:
	var environnement := Environment.new()
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#0a1030")
	ciel.sky_horizon_color = Color("#c85a3a")
	ciel.sky_curve = 0.10
	ciel.ground_bottom_color = Color("#06070c")
	ciel.ground_horizon_color = Color("#3a2430")
	ciel.sun_angle_max = 30.0
	ciel.sun_curve = 0.12
	var voute := Sky.new()
	voute.sky_material = ciel
	environnement.background_mode = Environment.BG_SKY
	environnement.sky = voute
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environnement.ambient_light_color = Color("#3c4a7a")
	environnement.ambient_light_energy = 1.05
	environnement.fog_enabled = true
	environnement.fog_light_color = Color("#2a2340")
	environnement.fog_density = 0.0028
	environnement.fog_sky_affect = 0.35
	environnement.glow_enabled = true
	environnement.glow_intensity = 0.9
	environnement.glow_strength = 1.0
	environnement.glow_bloom = 0.12
	environnement.glow_hdr_threshold = 0.72
	environnement.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environnement.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environnement.tonemap_exposure = 1.05
	environnement.tonemap_white = 4.0
	var monde := WorldEnvironment.new()
	monde.environment = environnement

	var soleil := DirectionalLight3D.new()
	soleil.light_color = Color("#ffb27a")
	soleil.light_energy = 1.25
	# Bas, mais pas rasant : à vingt degrés, une tour projette une ombre de
	# trois pâtés et le joueur y disparaît. À quarante-deux, l'ombre dit le
	# volume et la rue reste lisible.
	soleil.rotation_degrees = Vector3(-42, -52, 0)
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 220.0
	soleil.shadow_bias = 0.05
	soleil.shadow_normal_bias = 1.5

	var lune := DirectionalLight3D.new()
	lune.light_color = Color("#5a72c8")
	lune.light_energy = 0.42
	lune.rotation_degrees = Vector3(-50, 135, 0)
	lune.shadow_enabled = false
	return [monde, soleil, lune]
