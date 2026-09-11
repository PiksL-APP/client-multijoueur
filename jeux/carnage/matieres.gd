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
static var _eau: ShaderMaterial
static var _facade: ShaderMaterial
static var _flaque: ShaderMaterial
static var _lumineux: ShaderMaterial
static var _voxel: ShaderMaterial

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
// La voie ferrée : ax + bz = c en unités monde (PlanVille.rail()).
uniform vec3 rail = vec3(0.0, 1.0, -100000.0);
// Les voies libres (PlanVille) : trois lignes (normale, offset, demi-longueur)
// qui passent par la place en étoile, l'ellipse du boulevard circulaire
// (centre, rayons) et la place (centre, rayon, rayon de l'îlot).
uniform vec4 lignes[7];      // (nx, ny, c, -) : n·p = c
uniform vec4 origines[7];    // (ox, oy, longueur vers +d, longueur vers -d)
uniform vec4 anneaux[2];     // (cx, cy, rx, ry)
uniform vec4 etoiles[3];     // (cx, cy, rayon, rayon de l'îlot)
uniform float nuit : hint_range(0.0, 1.0) = 0.5;
// LA MÉTÉO (MeteoCarnage) : `mouille` = la pluie qui tombe ou vient de tomber,
// `couvert` = la chape de nuages. Le sol mouillé était réservé à la nuit ;
// il l'est maintenant aussi sous l'averse, en plein jour.
uniform float mouille : hint_range(0.0, 1.0) = 0.0;
uniform float couvert : hint_range(0.0, 1.0) = 0.0;

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
	// Des dalles : une par cellule, un joint sombre entre elles.
	vec2 j = abs(fract(uv * 5.0) - 0.5);
	float joint = step(0.44, max(j.x, j.y));
	return mix(base, base * 0.82, joint);
}

// Le sol est en VOXELS aussi : cinq cellules par tuile (deux unités), et
// tout ce qu'on dessine — bandes, passages, dalles, herbe — se décide par
// cellule, jamais entre deux. C'est ce qui accorde le sol aux cubes posés
// dessus.
const float CELLULES = 5.0;
// Le dessin (bandes, trottoirs, passages) se décide par cellule de deux
// unités ; le GRAIN et les joints, par sous-cellule d'une unité — les mêmes
// sous-cubes que sur les murs.
const float FINES = 10.0;

// L'ombre des nuages : un bruit large qui glisse sur la ville. Ce n'est pas
// une vraie ombre (rien ne la projette), mais c'est ce qui fait qu'une rue
// n'est jamais éclairée pareil d'un bout à l'autre — et qu'elle bouge.
float nuages(vec2 p) {
	vec2 q = p / 110.0 + vec2(TIME * 0.011, TIME * 0.006);
	float n = bruit(q) * 0.65 + bruit(q * 2.3 + vec2(5.0)) * 0.35;
	// Sous une chape uniforme, plus une ombre de nuage ne se détache : elle
	// s'efface avec `couvert`, sinon le sol tachait sous un ciel sans soleil.
	return 1.0 - 0.16 * smoothstep(0.48, 0.78, n) * (1.0 - 0.7 * nuit) * (1.0 - 0.85 * couvert);
}

// La distance d'une cellule à l'axe d'une avenue en diagonale : infinie hors
// du segment, pour qu'une avenue ne marque pas le boulevard qu'elle
// prolongerait en pointillé de l'autre côté de la ville.
float d_ligne(vec4 l, vec4 o, vec2 p) {
	vec2 dir = vec2(l.y, -l.x);
	float le_long = dot(p - o.xy, dir);
	if (le_long > o.z || le_long < -o.w) return 1e9;
	return abs(l.x * p.x + l.y * p.y - l.z);
}

float d_anneau(vec4 a, vec2 p) {
	vec2 q = (p - a.xy) / a.zw;
	return abs((length(q) - 1.0) * (a.z + a.w) * 0.5);
}

void fragment() {
	int k = int(sol + 0.5);
	vec2 cel = floor(uvl * CELLULES);
	vec2 uvq = (cel + 0.5) / CELLULES;
	vec2 celm = floor(posm.xz);
	vec3 asphalte = vec3(0.12, 0.13, 0.16);
	vec3 trottoir = vec3(0.47, 0.44, 0.39);
	vec3 bordure = vec3(0.30, 0.29, 0.27);
	vec3 blanc = vec3(0.85, 0.85, 0.80);
	vec3 jaune = vec3(0.86, 0.68, 0.24);
	vec3 col = trottoir;
	float rug = 0.85;
	float spec = 0.15;
	// Le grain se tire par cellule : deux tons de bitume, jamais un dégradé.
	float grain = (hache(celm) - 0.5) * 0.10;
	vec3 emission = vec3(0.0);
	// Le joint entre deux cellules, un peu plus sombre : c'est lui qui fait
	// lire le sol comme un carrelage de cubes.
	vec2 jc = abs(fract(uvl * FINES) - 0.5);
	float joint = step(0.42, max(jc.x, jc.y)) * 0.06;

	if (k <= 2) {
		// ROUTE / PASSAGE_A / PASSAGE_B : trottoir à gauche (une cellule), axe à droite.
		if (cel.x < 0.5) {
			col = trottoir;
			if (fract(uvl.x * CELLULES) > 0.8) col = bordure;
		} else {
			col = asphalte;
			rug = 0.55;
			spec = 0.35;
			// L'axe : une cellule jaune sur deux, une moitié sur chaque tuile ;
			// sur une avenue (graine ≥ 0,5), une bande continue plus claire.
			bool axe = uvl.x > 0.94;
			if (graine >= 0.5) {
				if (axe) col = jaune;
				col *= 1.06;
			} else if (axe && mod(cel.y, 2.0) < 0.5) col = jaune;
			// Le passage piéton : la première (ou dernière) rangée de cellules,
			// une cellule sur deux.
			bool zebra = (k == 1 && cel.y < 0.5) || (k == 2 && cel.y > CELLULES - 1.5);
			if (zebra && mod(cel.x, 2.0) < 0.5) col = mix(col, blanc, 0.6);
			// Usure : la voie de roulement (cellules 3 et 4) un peu plus sombre.
			if (cel.x > 2.5) col *= 0.9;
		}
	} else if (k == 3) {
		// CARREFOUR : la cellule d'angle est du trottoir.
		col = asphalte;
		rug = 0.55;
		spec = 0.35;
		if (cel.x < 0.5 && cel.y < 0.5) {
			col = trottoir;
			if (fract(uvl.x * CELLULES) > 0.8 || fract(uvl.y * CELLULES) > 0.8) col = bordure;
		}
	} else if (k == 4) {
		col = trottoir;
	} else if (k == 5) {
		// PAVÉS : deux tons chauds par cellule.
		float ton = hache(celm + vec2(3.0));
		col = mix(vec3(0.50, 0.44, 0.38), vec3(0.60, 0.54, 0.46), step(0.5, ton));
	} else if (k == 6 || k == 7 || k == 8 || k == 9) {
		// HERBE, et les allées d'un parc : une bande de sable d'une cellule.
		float h = hache(celm + vec2(7.0));
		// Un vert d'herbe, pas de citron : sous le soleil à pic le ton clair
		// d'avant tirait au fluo.
		col = mix(vec3(0.17, 0.32, 0.13), vec3(0.24, 0.40, 0.16), step(0.5, h));
		rug = 0.95;
		spec = 0.05;
		bool allee = (k == 7 && abs(cel.x - 2.0) < 0.5) || (k == 8 && abs(cel.y - 2.0) < 0.5)
			|| (k == 9 && (abs(cel.x - 2.0) < 0.5 || abs(cel.y - 2.0) < 0.5));
		if (allee) {
			col = mix(vec3(0.55, 0.48, 0.36), vec3(0.62, 0.55, 0.42), step(0.5, h));
			rug = 0.8;
		}
	} else if (k == 10) {
		// BÉTON : des dalles claires, une tache par-ci par-là.
		col = vec3(0.46, 0.45, 0.42) * (0.9 + 0.2 * hache(celm + vec2(11.0)));
		if (hache(celm + vec2(13.0)) > 0.9) col *= 0.6;
	} else if (k == 11) {
		// PARKING : du bitume et des places peintes en travers (une cellule sur deux).
		col = asphalte * 1.15;
		rug = 0.6;
		spec = 0.3;
		if (mod(cel.x, 2.0) < 0.5 && cel.y > 0.5 && fract(uvl.x * CELLULES) < 0.2) col = mix(col, blanc, 0.6);
		if (cel.y < 0.5 && fract(uvl.y * CELLULES) > 0.8) col = mix(col, blanc, 0.6);
	} else if (k == 12) {
		// LE FOND DE L'EAU : de la vase sombre, mate, sans un reflet. L'eau
		// vive n'est plus peinte ici : c'est une nappe à part, posée un mètre
		// plus haut avec le shader EAU, qui lève ses sommets et fait facettes.
		float v = hache(celm + vec2(29.0));
		col = mix(vec3(0.02, 0.05, 0.08), vec3(0.04, 0.09, 0.12), step(0.5, v));
		rug = 0.9;
		spec = 0.05;
		grain = 0.0;
	} else if (k == 14) {
		// RAIL : du ballast, des traverses en travers de la ligne, deux rails.
		col = mix(vec3(0.24, 0.22, 0.20), vec3(0.32, 0.30, 0.27), hache(celm + vec2(17.0)));
		rug = 0.95;
		float d = rail.x * posm.x + rail.y * posm.z - rail.z;       // distance signée à l'axe
		float le_long = -rail.y * posm.x + rail.x * posm.z;         // abscisse le long de la voie
		if (abs(d) < 1.5 && fract(le_long / 1.1) < 0.35) col = vec3(0.30, 0.22, 0.16);   // traverses
		if (abs(abs(d) - 0.75) < 0.07) { col = vec3(0.55, 0.55, 0.58); rug = 0.3; spec = 0.6; }
	} else if (k == 15) {
		// BOULEVARD : la chaussée d'une voie libre, tracée en espace monde par
		// cellule de deux unités — l'axe jaune continu, la file, le trottoir
		// dallé et sa bordure au bord de la voie.
		vec2 pq = (celm + 0.5) * 2.0;
		float d = 1e9;
		for (int i = 0; i < 7; i++) d = min(d, d_ligne(lignes[i], origines[i], pq));
		d = min(d, min(d_anneau(anneaux[0], pq), d_anneau(anneaux[1], pq)));
		float demi = 15.0;          // LARGEUR_BOULEVARD / 2, en unités
		float trottoir_l = 6.0;     // TROTTOIR_BOULEVARD, en unités
		col = asphalte;
		rug = 0.55;
		spec = 0.35;
		if (d < 1.0) col = jaune;

		if (d > demi - trottoir_l) {
			col = trottoir;
			if (d < demi - trottoir_l + 1.0) col = bordure;
			rug = 0.85;
			spec = 0.15;
		}
	} else if (k == 16) {
		// PLACE : un anneau de chaussée autour d'un îlot pavé, le trottoir au
		// bord, la bordure de l'îlot en pierre claire.
		vec2 pq = (celm + 0.5) * 2.0;
		// La place la plus proche : c'est la nôtre.
		vec4 etoile = etoiles[0];
		float r = length(pq - etoile.xy);
		for (int i = 1; i < 3; i++) {
			float ri = length(pq - etoiles[i].xy);
			if (ri < r) { r = ri; etoile = etoiles[i]; }
		}
		col = asphalte;
		rug = 0.55;
		spec = 0.35;
		if (r < etoile.w) {
			float ton = hache(celm + vec2(3.0));
			col = mix(vec3(0.30, 0.28, 0.26), vec3(0.38, 0.36, 0.33), step(0.5, ton));
			rug = 0.8;
			spec = 0.15;
			if (r > etoile.w - 1.5) col = blanc * 0.8;
		} else if (r > etoile.z - 6.0) {
			col = trottoir;
			if (r < etoile.z - 5.0) col = bordure;
			rug = 0.85;
			spec = 0.15;
		} else if (r < etoile.w + 1.0) {
			col = bordure;
		}
	} else if (k == 17) {
		// ESPLANADE : le parvis d'une place, en pavés qui rayonnent — des
		// anneaux de deux tons autour de la place la plus proche.
		vec2 pq = celm + 0.5;
		float r = length(pq - etoiles[0].xy);
		for (int i = 1; i < 3; i++) r = min(r, length(pq - etoiles[i].xy));
		float anneau_p = mod(floor(r / 4.0), 2.0);
		float ton = hache(celm + vec2(23.0));
		// ⚠ Sombre à dessein : sous le soleil à pic, un pavé à 0,5 sortait blanc
		// et le parvis n'était qu'une nappe crème sans dessin.
		col = mix(mix(vec3(0.27, 0.25, 0.23), vec3(0.33, 0.30, 0.27), step(0.5, ton)),
			mix(vec3(0.36, 0.32, 0.27), vec3(0.42, 0.37, 0.31), step(0.5, ton)), anneau_p);
		// Le joint entre deux pavés, un trait sombre sur la grille fine.
		vec2 jf = abs(fract(uvl * FINES) - 0.5) * 2.0;
		col *= 1.0 - 0.18 * smoothstep(0.8, 0.97, max(jf.x, jf.y));
		rug = 0.8;
		spec = 0.15;
	} else {
		// TERRE
		col = mix(vec3(0.30, 0.24, 0.17), vec3(0.38, 0.31, 0.22), hache(celm + vec2(19.0)));
		rug = 0.95;
	}

	// Le bitume vécu : des plaques plus sombres (rustines), un regard d'égout
	// par-ci par-là, et une usure claire sur la voie de roulement.
	bool bitume_nu = (k <= 3 || k == 15 || k == 16) && spec > 0.3;
	if (bitume_nu) {
		float plaque = bruit(posm.xz / 6.0 + vec2(11.0, 7.0));
		if (plaque > 0.72) col *= 0.82;
		vec2 gros = floor(posm.xz / 7.0);
		if (hache(gros + vec2(31.0)) > 0.93) {
			vec2 centre_g = (gros + 0.5) * 7.0;
			float dr = length(posm.xz - centre_g);
			if (dr < 1.0) col = vec3(0.10, 0.10, 0.11);
			if (dr < 0.75 && mod(floor(dr * 4.0), 2.0) < 1.0) col = vec3(0.18, 0.17, 0.16);
		}
	}
	// La nuit — et sous la pluie — le bitume est mouillé : des flaques par
	// plaques, où la rue devient un miroir sombre qui rend le ciel et les
	// enseignes. La pluie mouille plus large que la rosée de la nuit : les
	// flaques gagnent du terrain avec `mouille`.
	bool bitume = (k <= 3 || k == 11 || k == 15 || k == 16) && spec > 0.3;
	float eau = max(nuit, mouille);
	if (bitume && eau > 0.05) {
		float fl = smoothstep(0.52 - 0.14 * mouille, 0.66, bruit(posm.xz / 9.0 + vec2(3.7, 1.3)));
		float humide = eau * (0.35 + 0.65 * fl);
		col *= 1.0 - 0.38 * humide;
		// Pas un miroir parfait : la lune y ferait une tache blanche qui suit
		// la caméra sur trois pâtés.
		rug = mix(rug, 0.28, humide);
		spec = mix(spec, 0.6, humide);
		emission += vec3(0.05, 0.07, 0.12) * fl * nuit;
		// LES IMPACTS : sous l'averse, une cellule sur cent s'allume un
		// dixième de seconde — c'est ce qui dit que la pluie TOMBE, quand les
		// traits à l'écran ne disent que qu'elle passe. De jour comme de nuit.
		if (mouille > 0.05) {
			float imp = step(0.982 - 0.01 * mouille, hache(floor(posm.xz) + floor(TIME * 9.0) * vec2(1.0, 3.0)));
			emission += vec3(0.7, 0.75, 0.85) * imp * mouille * (0.6 + 0.4 * fl);
		}
	} else if (mouille > 0.05 && k != 12) {
		// L'herbe, la terre et les dalles foncent sous la pluie sans luire.
		col *= 1.0 - 0.22 * mouille;
		rug = mix(rug, rug * 0.7, mouille);
	}
	if (k != 4 && k != 5 && k != 10 && k != 17) joint = 0.0;
	ALBEDO = col * teinte * (1.0 + grain - joint) * nuages(posm.xz);
	ROUGHNESS = rug;
	SPECULAR = spec;
	EMISSION = emission;
}
"""

# ------------------------------------------------------------ l'eau

## L'EAU, en LOW POLY : une nappe de facettes qui ondulent.
##
## D'après le « Low Poly Water » de godotshaders.com : chaque sommet est levé
## par une fonction de sa propre position, la normale est reprise à la dérivée
## de la face — d'où un plat par triangle, jamais un dégradé, et cet air de
## papier plié qui va avec les voxels.
##
## DEUX ÉCARTS avec l'original, tous deux pour la ville :
##  • le déplacement est VERTICAL seulement. L'original pousse aussi le sommet
##    en x et en z ; sur une mer découpée en tuiles, ça décollerait le bord de
##    l'eau du quai et ouvrirait une fente à chaque rive.
##  • pas de `beer_factor` : lire DEPTH_TEXTURE n'est pas sûr en mode
##    compatibilité (WebGL 2), et la ville s'y joue. La transparence est celle
##    de la teinte, et le fond de vase se lit au travers.
const EAU := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

uniform vec4 teinte : source_color = vec4(0.05, 0.26, 0.38, 0.86);
uniform vec4 ecume : source_color = vec4(0.60, 0.82, 0.88, 1.0);
uniform float amplitude : hint_range(0.2, 5.0, 0.1) = 0.9;   // hauteur des vagues
uniform float vitesse : hint_range(0.1, 5.0, 0.1) = 1.0;
uniform float metal : hint_range(0.0, 1.0) = 0.35;
uniform float speculaire : hint_range(0.0, 1.0) = 0.6;
uniform float rugosite : hint_range(0.0, 1.0) = 0.12;
uniform float nuit : hint_range(0.0, 1.0) = 0.5;
uniform float mouille : hint_range(0.0, 1.0) = 0.0;   // la pluie (météo)

// La hauteur du sommet, ramenée entre -1 et 1 : elle sert à blanchir la crête.
varying float crete;
varying vec3 posm;

float hache_eau(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float decalage(float x, float z, float v1, float v2, float t) {
	float rx = ((mod(x + z * x * v1, amplitude) / amplitude)
		+ (t * vitesse) * mod(x * 0.8 + z, 1.5)) * 2.0 * PI;
	float rz = ((mod(v2 * (z * x + x * z), amplitude) / amplitude)
		+ (t * vitesse) * 2.0 * mod(x, 2.0)) * 2.0 * PI;
	return amplitude * 0.5 * (sin(rz) * cos(rx));
}

void vertex() {
	// La position est celle du monde (le maillage est bâti en coordonnées
	// absolues) : deux morceaux voisins lèvent leur bord au même endroit.
	float d = decalage(VERTEX.x, VERTEX.z, 0.1, 0.3, TIME * 0.1);
	// SOUS LA PLUIE, la surface se hache : un clapot court et rapide par-dessus
	// la houle, et la nappe perd son calme — c'est ce qui la distingue d'un
	// lac sous un ciel simplement gris.
	d += mouille * 0.18 * sin(VERTEX.x * 2.7 + TIME * 5.0) * cos(VERTEX.z * 3.1 - TIME * 4.3);
	VERTEX.y += d;
	crete = d / max(amplitude * 0.5, 0.001);
	posm = VERTEX;
}

void fragment() {
	// La normale de la FACE, pas du sommet : c'est tout le low poly.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = faceforward(n, VERTEX, n);
	METALLIC = metal;
	SPECULAR = speculaire;
	ROUGHNESS = rugosite;
	vec3 col = teinte.rgb;
	// La crête d'une vague écume un peu, le creux s'assombrit : sans ça les
	// facettes ne se lisent que par la lumière rasante, et à midi la nappe
	// redevient un aplat.
	col = mix(col * 0.72, col, smoothstep(-1.0, 0.2, crete));
	col = mix(col, ecume.rgb, smoothstep(0.55, 1.0, crete) * 0.35);
	// La nuit, l'eau se referme et ne garde que la lueur des quais.
	col *= mix(1.0, 0.34, nuit);
	// La pluie la grise et la dépolit ; ses impacts y scintillent comme au sol.
	col = mix(col, col * vec3(0.8, 0.85, 0.88), mouille * 0.5);
	ROUGHNESS = mix(rugosite, 0.45, mouille);
	float imp = step(0.975, hache_eau(floor(posm.xz * 1.5) + floor(TIME * 8.0) * vec2(1.0, 3.0))) * mouille;
	ALBEDO = col;
	EMISSION = ecume.rgb * smoothstep(0.7, 1.0, crete) * 0.08 * nuit + ecume.rgb * imp * 0.35;
	ALPHA = teinte.a;
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
		// Un volume PLEIN (toit de maison, auvent, grue) montre sa teinte telle
		// quelle : c'est elle qui fait la tuile d'une maison.
		if (style == 6) toit = teinte * (0.9 + 0.2 * hache(floor(posm.xz * 3.0)));
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

# ------------------------------------------------------------ les voxels

## Le cube. Tout ce qui est bâti ou posé passe par ce shader : la nappe
## d'instances d'un morceau (couleur d'instance) comme les maillages à couleurs
## de sommet (voitures, personnages). L'alpha de la couleur dit la matière :
## 1 = mur, 0,5 = lumière (émissif, plus fort la nuit), 0,1 = vitre éteinte.
## Le BISEAU : les arêtes du cube sont assombries d'après les UV de la face,
## c'est ce qui fait lire chaque cube comme un cube et non une surface plate.
const VOXEL := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform float nuit : hint_range(0.0, 1.0) = 0.5;
// La peinture d'un maillage à couleurs de sommet (une voiture) : elle
// multiplie les cubes de mur, pas les lumières ni les vitres.
uniform vec4 teinte : source_color = vec4(1.0);
// 1.0 pour un MAILLAGE FUSIONNÉ (un pâté d'immeubles en un seul maillage de
// cubes d'une unité) : les UV y portent la position en cellules, pas 0..1.
uniform float fusionne = 0.0;
uniform float couvert : hint_range(0.0, 1.0) = 0.0;   // la chape de nuages (météo)

varying vec4 c;
varying vec2 uvl;
varying vec3 posm;
varying vec3 nrm;
varying float grand;

void vertex() {
	c = COLOR;
	uvl = UV;
	posm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	// La taille du cube : la longueur du premier axe de sa transformation.
	// Au-dessus d'une unité et demie, la face se découpe en sous-cubes.
	grand = max(step(1.5, length(MODEL_MATRIX[0].xyz)), fusionne);
}

// Le SOUS-CUBE : les gros cubes (immeubles, deux unités) se lisent comme
// deux sur deux sur deux cubes d'une unité, chacun avec son arête et son
// grain. C'est ce qui donne « beaucoup de cubes » sans multiplier les
// instances par huit : la géométrie reste grosse, la matière est fine.
const float SOUS = 1.0;

float hache(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hache(i), hache(i + vec2(1.0, 0.0)), f.x), mix(hache(i + vec2(0.0, 1.0)), hache(i + vec2(1.0, 1.0)), f.x), f.y);
}

// La même ombre de nuages que le sol : un immeuble et sa rue s'assombrissent
// ensemble, sinon l'un flotte au-dessus de l'autre.
float nuages(vec2 p) {
	vec2 q = p / 110.0 + vec2(TIME * 0.011, TIME * 0.006);
	float n = bruit(q) * 0.65 + bruit(q * 2.3 + vec2(5.0)) * 0.35;
	// Sous une chape uniforme, plus une ombre de nuage ne se détache : elle
	// s'efface avec `couvert`, sinon le sol tachait sous un ciel sans soleil.
	return 1.0 - 0.16 * smoothstep(0.48, 0.78, n) * (1.0 - 0.7 * nuit) * (1.0 - 0.85 * couvert);
}

void fragment() {
	vec2 d = abs(uvl - vec2(0.5)) * 2.0;
	float bord = smoothstep(0.86, 0.99, max(d.x, d.y));
	float lumiere = step(0.25, c.a) * step(c.a, 0.75);
	float vitre = step(c.a, 0.25);
	// L'appui d'une fenêtre allumée : un mur le jour, qui luit la nuit.
	float eclaire = step(0.8, c.a) * step(c.a, 0.9);
	// Seule la tôle (alpha 1) prend la peinture d'instance : pneus, chrome,
	// feux, vitres, lumières gardent leur couleur (alpha < 0,97).
	vec3 col = c.rgb * mix(vec3(1.0), teinte.rgb, step(0.97, c.a));
	// Une fenêtre « allumée » n'est qu'une vitre de jour : sa couleur chaude
	// n'apparaît qu'avec la nuit, sinon les tours sont des damiers crème.
	vec3 verre = vec3(0.13, 0.17, 0.24);
	col = mix(col, verre, lumiere * (1.0 - smoothstep(0.35, 0.8, nuit)));
	if (grand > 0.5) {
		// Les deux axes de la face : ceux que la normale ne porte pas. Sur un
		// maillage fusionné, les UV sont déjà la position en cellules.
		vec3 an = abs(nrm);
		vec2 pf = (fusionne > 0.5) ? uvl : ((an.y > 0.5) ? posm.xz : ((an.x > 0.5) ? posm.zy : posm.xy));
		bord *= 1.0 - fusionne;
		vec2 cel = floor(pf / SOUS);
		vec2 f = abs(fract(pf / SOUS) - vec2(0.5)) * 2.0;
		float arete = smoothstep(0.74, 0.98, max(f.x, f.y));
		// Un grain par sous-cube : deux briques voisines ne sont jamais tout à
		// fait de la même teinte. Les vitres restent lisses.
		float g = (fract(sin(dot(cel + floor(posm.xz * 0.01), vec2(127.1, 311.7))) * 43758.5453) - 0.5) * 0.06;
		// L'arête du HAUT de chaque sous-cube prend la lumière, celle du bas la
		// perd : c'est ce qui fait lire un relief et non un carrelage.
		float fy = fract(pf.y / SOUS);
		float haut_c = (an.y > 0.5) ? 0.0 : smoothstep(0.86, 0.98, fy) * 0.06;
		// Des arêtes DISCRÈTES : le voxel se lit à la forme (chaque cube fait
		// son relief à la lumière), pas à un quadrillage dessiné. Sur un toit
		// (face horizontale) presque rien, un grain de gravier.
		float toit = step(0.5, an.y);
		float f_arete = mix(0.06, 0.02, toit);
		g *= 1.0 + 0.8 * toit;
		col *= (1.0 + g * (1.0 - vitre)) * (1.0 - f_arete * arete * (1.0 - lumiere) * (1.0 - vitre)) * (1.0 + haut_c * (1.0 - vitre));
		col *= 1.0 - 0.10 * bord * (1.0 - lumiere);
	} else {
		col *= 1.0 - 0.20 * bord * (1.0 - lumiere);
	}
	col *= mix(nuages(posm.xz), 1.0, lumiere);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.2, vitre);
	SPECULAR = mix(0.15, 0.7, vitre);
	EMISSION = c.rgb * (lumiere * 1.4 + eclaire * 1.1) * smoothstep(0.3, 0.85, nuit);
}
"""

## LES KITS KENNEY : un atlas, la couleur d'instance en teinte, et — c'est tout
## l'enjeu de nuit — les FENÊTRES qui s'allument. Un bâtiment glTF est une
## boîte texturée : sans ça, la ville s'éteignait d'un bloc à la tombée du jour
## alors que nos immeubles voxel avaient leurs carreaux jaunes. On repère les
## carreaux à leur couleur dans l'atlas (le bleu franc du kit), et on en allume
## une partie, tirée par bâtiment et par étage.
const KENNEY := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_nearest;
uniform float nuit : hint_range(0.0, 1.0) = 0.5;
uniform float fenetres : hint_range(0.0, 1.0) = 0.0;
uniform vec4 teinte : source_color = vec4(1.0);
// LA PEINTURE DU GARAGE (§1.3) : à 1.0, `teinte` ne recouvre que la TÔLE.
uniform float peinture : hint_range(0.0, 1.0) = 0.0;
// La pluie (météo) : une carrosserie mouillée luit.
uniform float mouille : hint_range(0.0, 1.0) = 0.0;

varying vec4 c;
varying vec3 posm;

void vertex() {
	c = COLOR;
	posm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hache(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(atlas, UV);
	// LA TÔLE ET LE RESTE. Dans l'atlas du Car Kit, la carrosserie est la seule
	// matière SATURÉE : vitres, pneus, jantes, chromes et phares sont des gris
	// (saturation 0,05 à 0,21) quand la moindre peinture dépasse 0,5. C'est ce
	// qui permet de repeindre une voiture sans repeindre ses vitres.
	// ⚠ L'ancienne méthode MULTIPLIAIT tout le modèle par la teinte : une
	// voiture bleue avait les jantes bleues et les vitres bleues, et la
	// peinture sombre du garage noircissait le pare-brise. Le seuil est au-
	// dessus du vitrage (0,21) et bien sous la moins vive des tôles (0,53).
	// La couleur d'instance (`COLOR`, celle des nappes de voitures dormantes)
	// est une peinture comme la teinte : le même blanc dit « couleur d'usine ».
	vec3 tinte = teinte.rgb * c.rgb;
	float usine = step(2.997, tinte.r + tinte.g + tinte.b);
	float maxi = max(t.r, max(t.g, t.b));
	float mini = min(t.r, min(t.g, t.b));
	float sat = (maxi - mini) / max(maxi, 0.001);
	float tole = smoothstep(0.30, 0.45, sat) * peinture * (1.0 - usine);
	// Le dégradé de l'atlas (clair en haut, foncé en bas de chaque case) donne
	// aux modèles leur relief : on le garde en faisant varier la peinture avec
	// la luminance d'origine plutôt qu'en posant un aplat.
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 brut = mix(t.rgb * tinte, t.rgb, peinture);
	vec3 col = mix(brut, tinte * mix(0.72, 1.18, lum), tole);
	// Le carreau : un bleu FRANC dans l'atlas, et seulement sur une face
	// VERTICALE. ⚠ Sans le test de normale, le gris-bleu des toitures passait
	// pour du vitrage et les toits luisaient la nuit.
	float debout = step(0.5, 1.0 - abs(NORMAL.y));
	float vitre = step(0.62, t.b) * step(t.r + 0.16, t.b) * fenetres * debout;
	// Une fenêtre sur deux allumée, par bâtiment (sa position) et par étage.
	float allume = step(0.32, hache(floor(posm.xz * 0.6) + vec2(floor(posm.y * 1.1) * 7.0)));
	float nuitf = smoothstep(0.28, 0.85, nuit);
	ALBEDO = mix(col, col * 1.25, vitre * allume * nuitf);
	EMISSION = vec3(1.0, 0.86, 0.6) * vitre * allume * nuitf * 2.1;
	// UNE VOITURE LUIT, UN MUR NON. Les véhicules (`peinture` à 1) sont
	// glacés : la tôle accroche le soleil, le vitrage et les chromes — les
	// gris BLEUTÉS de l'atlas, que ni la tôle ni les pneus n'ont — encore
	// plus. Avant, tout le kit avait la rugosité d'un crépi, et vu de haut
	// une voiture était un aplat sans le moindre reflet. Sous la pluie, tout
	// le monde luit un peu plus.
	float vitre_auto = step(0.12, t.b - t.r) * step(0.35, t.b) * peinture;
	float rug_auto = mix(0.5, 0.2, vitre_auto);
	float rug = mix(mix(0.86, 0.32, vitre), rug_auto, peinture);
	ROUGHNESS = rug * (1.0 - 0.35 * mouille);
	SPECULAR = mix(mix(0.18, 0.6, vitre), mix(0.35, 0.65, vitre_auto), peinture) + 0.15 * mouille;
}
"""

## Une matière de kit par atlas (et par usage) : les shaders coûtent, les
## matières se partagent.
static var _kenneys: Dictionary = {}
## Les duplicata peints (`FormesCarnage.matiere_peinte`) : ils partent du
## même shader et doivent recevoir la nuit et la pluie comme l'original —
## sans ce registre, une voiture repeinte restait sèche sous l'averse.
static var _kenneys_derives: Array = []

static func suivre_kenney(m: Material) -> void:
	_kenneys_derives.append(m)

static func kenney(atlas: Texture2D, fenetres: bool, peinture: bool = false) -> ShaderMaterial:
	var cle := "%s|%s|%s" % [atlas.resource_path if atlas != null else "vide", fenetres, peinture]
	if _kenneys.has(cle):
		return _kenneys[cle]
	var m := _materiau(KENNEY)
	m.set_shader_parameter("atlas", atlas)
	m.set_shader_parameter("fenetres", 1.0 if fenetres else 0.0)
	# Les véhicules se REPEIGNENT (tôle seule) ; les bâtiments et les props se
	# teintent en bloc, comme avant — leur couleur d'instance est un ton.
	m.set_shader_parameter("peinture", 1.0 if peinture else 0.0)
	m.set_shader_parameter("nuit", _nuit_courante)
	_kenneys[cle] = m
	return m

# ------------------------------------------------------------ les lumières

## Une flaque de lumière au sol : un quadrilatère additif à dégradé radial. La
## couleur vient du sommet, la force de son alpha. C'est ce qui fait la nuit
## sous les lampadaires et devant les phares, sans une seule vraie lumière —
## le mode compatibilité n'en supporte que huit par objet.
const FLAQUE := """
shader_type spatial;
// ⚠ `fog_disabled` : le brouillard se MÉLANGE au fragment après le shader ;
// sur un quadrilatère additif, il peignait un carré violet là où la flaque
// devait être transparente. On l'a vu sur l'eau avant de comprendre.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float nuit : hint_range(0.0, 1.0) = 0.5;
uniform float mouille : hint_range(0.0, 1.0) = 0.0;   // la pluie (météo)

varying vec4 c;
varying vec2 uvl;

void vertex() {
	c = COLOR;
	uvl = UV;
}

void fragment() {
	float d = length(uvl - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.7) * c.a;
	// LE REFLET DANS LE MOUILLÉ. Une rue mouillée rend chaque lumière en un
	// trait allongé dans l'axe du regard — ici l'axe z du monde, la caméra
	// regardant toujours vers -z. Le trait est étroit, plus vif que la flaque,
	// et il n'existe que quand le sol est mouillé : la rosée de la nuit en fait
	// la moitié, l'averse le reste. C'est ce qui manquait pour que « la rue
	// rend les enseignes » soit vrai des lampadaires et des phares aussi.
	float eau = max(nuit * 0.5, mouille);
	float trait = pow(clamp(1.0 - abs(uvl.x - 0.5) * 2.0 / 0.16, 0.0, 1.0), 2.0)
		* (1.0 - smoothstep(0.1, 1.0, abs(uvl.y - 0.5) * 2.0));
	// Le reflet tremble : l'eau n'est jamais tout à fait plane.
	trait *= 0.8 + 0.2 * sin(uvl.y * 40.0 + TIME * 3.0);
	a += trait * c.a * eau * 0.9;
	// En plein jour, une flaque de lampadaire ne se voit pas ; les phares un peu.
	ALBEDO = c.rgb * a * (0.15 + 0.85 * nuit);
	ALPHA = 1.0;
}
"""

## LE VÉGÉTAL : les arbres et les buissons du Nature Kit (pas d'atlas, la
## couleur au sommet) — et ils PLIENT AU VENT. Le sommet se déplace en
## proportion de sa hauteur (le pied ne bouge pas), à une phase tirée de la
## position dans le monde pour que deux arbres voisins ne balancent pas
## ensemble. `vent` vient de la météo : une brise par temps clair, une
## bourrasque sous l'orage. C'est le seul mouvement de la ville qui ne soit
## pas une voiture ou un passant, et c'est ce qui fait qu'un parc a l'air
## vivant même vide.
const VEGETAL := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform float vent : hint_range(0.0, 1.0) = 0.15;
uniform float mouille : hint_range(0.0, 1.0) = 0.0;

varying vec3 c;

void vertex() {
	c = COLOR.rgb;
	vec3 posm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Le balancement croît avec la hauteur, au carré : le tronc tient, la
	// cime va. Deux sinus de fréquences différentes, sinon toute la rangée
	// ondule comme une seule vague.
	float h = max(VERTEX.y, 0.0);
	float ampl = vent * 0.012 * h * h;
	float phase = posm.x * 0.35 + posm.z * 0.21;
	VERTEX.x += sin(TIME * (1.3 + 0.9 * vent) + phase) * ampl;
	VERTEX.z += cos(TIME * (0.9 + 0.7 * vent) + phase * 1.7) * ampl * 0.6;
}

void fragment() {
	// Mouillé, le feuillage fonce et luit un peu.
	ALBEDO = c * (1.0 - 0.18 * mouille);
	ROUGHNESS = 0.9 - 0.3 * mouille;
	SPECULAR = 0.15 + 0.2 * mouille;
}
"""

static var _vegetal: ShaderMaterial

static func vegetal() -> ShaderMaterial:
	if _vegetal == null:
		_vegetal = _materiau(VEGETAL)
	return _vegetal

## LE FAISCEAU DES PHARES : un coin de lumière additif devant la voiture, qui
## n'existe vraiment que quand l'air a quelque chose à éclairer — la brume, la
## pluie. Par temps clair il reste une lueur ; dans le brouillard, c'est le
## faisceau qu'on voit avant la voiture. Vu de dessus, un vrai projecteur ne
## se lit que par la tache au sol ; le coin, lui, dit la DIRECTION.
## UV.x en travers (0,5 au centre), UV.y le long (0 au phare, 1 au bout).
const FAISCEAU := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float nuit : hint_range(0.0, 1.0) = 0.5;
uniform float air : hint_range(0.0, 1.0) = 0.0;   // brume + pluie (météo)

varying vec4 c;
varying vec2 uvl;

void vertex() {
	c = COLOR;
	uvl = UV;
}

void fragment() {
	float travers = 1.0 - smoothstep(0.45, 1.0, abs(uvl.x - 0.5) * 2.0);
	float le_long = pow(clamp(1.0 - uvl.y, 0.0, 1.0), 1.6);
	// Le même seuil d'allumage que les projecteurs : les phares s'allument
	// ensemble ou pas du tout.
	float allume = clamp((nuit - 0.15) / 0.5, 0.0, 1.0);
	float a = travers * le_long * c.a * allume * (0.16 + 0.84 * air);
	ALBEDO = c.rgb * a;
	ALPHA = 1.0;
}
"""

static var _faisceau: ShaderMaterial

static func faisceau() -> ShaderMaterial:
	if _faisceau == null:
		_faisceau = _materiau(FAISCEAU)
	return _faisceau

## L'ombre de contact au pied d'un immeuble : un rectangle MULTIPLICATIF, un
## peu plus grand que l'emprise, qui s'assombrit vers le mur. Le mode
## compatibilité n'a pas d'occlusion ambiante ; sans elle, les immeubles
## flottent sur le trottoir. La couleur porte la demi-emprise (r, g : en
## centaines d'unités) pour que le shader retrouve où est le mur.
const OMBRE := """
shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float nuit : hint_range(0.0, 1.0) = 0.5;

varying vec4 c;
varying vec2 uvl;

void vertex() {
	c = COLOR;
	uvl = UV;
}

void fragment() {
	vec2 demi = c.rg * 100.0;
	// Une ombre de contact DISCRETE : le soleil projette deja la vraie ombre ;
	// celle-ci ne fait que sceller le pied du mur au sol. Plus large et plus
	// sombre, elle dessinait un cadre noir autour de chaque immeuble.
	vec2 p = (uvl - vec2(0.5)) * 2.0 * (demi + vec2(3.0));
	vec2 dd = abs(p) - demi;
	float d = max(dd.x, dd.y);
	float a = (1.0 - smoothstep(-0.5, 1.6, d)) * (0.16 - 0.06 * nuit);
	ALBEDO = vec3(1.0 - a);
}
"""

## Les traces de pneus : des rectangles multiplicatifs posés au sol par le
## joueur qui freine ou dérape, qui pâlissent avec le temps (l'alpha).
const TRACE := """
shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

varying vec4 c;
varying vec2 uvl;

void vertex() {
	c = COLOR;
	uvl = UV;
}

void fragment() {
	// Une trace de pneu est une ombre de gomme, pas une tuile noire : au plus
	// un quart de la lumière en moins, et des bords fondus.
	float bord = 1.0 - smoothstep(0.12, 0.5, abs(uvl.y - 0.5));
	ALBEDO = vec3(1.0 - 0.26 * c.a * bord);
}
"""

static var _ombre: ShaderMaterial
static var _trace: ShaderMaterial

static func ombre() -> ShaderMaterial:
	if _ombre == null:
		_ombre = _materiau(OMBRE)
	return _ombre

static func trace() -> ShaderMaterial:
	if _trace == null:
		_trace = _materiau(TRACE)
	return _trace

## Les enseignes et balises : de la couleur pure, sans éclairage, qui passe
## le seuil du halo.
const LUMINEUX := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float nuit : hint_range(0.0, 1.0) = 0.5;

varying vec4 c;

void vertex() {
	c = COLOR;
}

void fragment() {
	ALBEDO = c.rgb * (0.7 + 0.3 * nuit);
	EMISSION = c.rgb * 0.6 * nuit;
}
"""

## Le post-traitement, en un rectangle sur l'écran : une vignette qui ferme
## les angles et un grain léger qui bouge — c'est ce qui fait « film » plutôt
## que « rendu ». Le mode compatibilité n'a pas de post-traitement natif à part
## le halo ; on relit l'écran dans un shader de canevas.
const POST := """
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D ecran : hint_screen_texture, filter_linear;
uniform float nuit : hint_range(0.0, 1.0) = 0.5;
uniform float secousse : hint_range(0.0, 1.0) = 0.0;
// LA MÉTÉO : la pluie en traits sur l'écran, l'éclair qui blanchit tout.
uniform float pluie : hint_range(0.0, 1.0) = 0.0;
uniform float eclair : hint_range(0.0, 1.0) = 0.0;

float hache(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// UN CALQUE DE PLUIE : l'écran découpé en colonnes fines et hautes, chaque
// colonne tirée avec son décalage et sa vitesse ; dans une case sur trois, un
// trait fin qui file vers le bas, un peu penché. Deux calques d'échelles
// différentes donnent la profondeur — les gros traits près de l'objectif, les
// fins au loin. ⚠ Des points plutôt que des traits (essayé) : on croyait à de
// la neige, ou à du bruit de compression.
float calque_de_pluie(vec2 uv, float colonnes, float vitesse, float graine, float rapport) {
	vec2 p = uv * vec2(colonnes, colonnes / rapport);
	p.x += uv.y * colonnes * 0.06;   // la pluie penche
	float colonne = floor(p.x);
	float dec = hache(vec2(colonne, graine));
	p.y += TIME * vitesse * (0.75 + 0.5 * dec) + dec * 13.0;
	vec2 f = fract(p);
	float id = hache(floor(p) + vec2(graine, 0.0));
	float trait = smoothstep(0.30, 0.42, f.x) * smoothstep(0.62, 0.50, f.x);
	float longueur = smoothstep(0.02, 0.12, f.y) * smoothstep(0.75, 0.35, f.y);
	return trait * longueur * step(0.68, id);
}

void fragment() {
	vec2 d = SCREEN_UV - vec2(0.5);
	vec3 c = texture(ecran, SCREEN_UV).rgb;
	if (pluie > 0.003) {
		// Sous la pluie, l'image se refroidit et perd un peu de contraste :
		// c'est l'air chargé d'eau entre la caméra et la rue.
		c = mix(c, c * vec3(0.90, 0.95, 1.06) + vec3(0.03), pluie * 0.35);
		float traits = calque_de_pluie(SCREEN_UV, 160.0, 2.6, 1.0, 9.0) * 0.55
			+ calque_de_pluie(SCREEN_UV, 90.0, 1.9, 2.0, 7.0) * 0.45;
		c += vec3(0.62, 0.68, 0.78) * traits * pluie * (0.55 + 0.45 * nuit);
	}
	// L'éclair : tout blanchit d'un coup, puis retombe en un dixième de seconde.
	c = mix(c, vec3(0.96, 0.97, 1.0), eclair * 0.45);
	// Un choc rougit les bords, le temps d'une image ou deux.
	float v = smoothstep(0.30, 0.95, length(d) * 1.3);
	c = mix(c, vec3(0.0), v * (0.34 + 0.14 * nuit));
	c = mix(c, vec3(0.6, 0.05, 0.02), v * secousse * 0.35);
	float g = hache(floor(SCREEN_UV * 480.0) + vec2(fract(TIME * 7.0) * 100.0)) - 0.5;
	c += g * (0.025 + 0.03 * nuit);
	COLOR = vec4(c, 1.0);
}
"""

static var _post: ShaderMaterial

static func post() -> ShaderMaterial:
	if _post == null:
		_post = _materiau(POST)
	return _post

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

static func eau() -> ShaderMaterial:
	if _eau == null:
		_eau = _materiau(EAU)
	return _eau

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

static func voxel() -> ShaderMaterial:
	if _voxel == null:
		_voxel = _materiau(VOXEL)
	return _voxel

## La matière des MAILLAGES FUSIONNÉS : un pâté d'immeubles en cubes d'une
## unité, cousus en un seul maillage. Même shader, mais les arêtes et le grain
## se lisent dans les UV (position en cellules) et non dans la transformation.
static var _voxel_fusionne: ShaderMaterial

static func voxel_fusionne() -> ShaderMaterial:
	if _voxel_fusionne == null:
		_voxel_fusionne = _materiau(VOXEL)
		_voxel_fusionne.set_shader_parameter("fusionne", 1.0)
		_voxel_fusionne.set_shader_parameter("nuit", _nuit_courante)
	return _voxel_fusionne

## La matière voxel peinte d'une couleur, une par couleur (mise en cache : les
## peintures sont peu nombreuses, et chaque matière doit recevoir la nuit).
static var _voxels_teintes: Dictionary = {}

static func voxel_teinte(couleur: Color) -> ShaderMaterial:
	var cle := couleur.to_html(false)
	if not _voxels_teintes.has(cle):
		var m := _materiau(VOXEL)
		m.set_shader_parameter("teinte", couleur)
		m.set_shader_parameter("nuit", _nuit_courante)
		_voxels_teintes[cle] = m
	return _voxels_teintes[cle]

## La nuit, de 0 à 1, poussée à tous les shaders : fenêtres, lampes, flaques,
## enseignes s'allument avec elle.
static var _nuit_courante := 0.5

## LA MÉTÉO pousse ses jauges aux shaders qui la dessinent : le sol (mouillé,
## chape), les voxels (chape) et le calque d'écran (traits, éclair). Les
## façades du kit et les voitures n'en savent rien : c'est la lumière
## (`MeteoCarnage.appliquer`) qui les grise, pas leur matière.
static func regler_meteo(pluie: float, nuages: float, brume: float, eclair: float,
		orage_courant: float = 0.0) -> void:
	var chape := maxf(nuages, brume)
	var s := sol()
	s.set_shader_parameter("mouille", pluie)
	s.set_shader_parameter("couvert", chape)
	eau().set_shader_parameter("mouille", pluie)
	flaque().set_shader_parameter("mouille", pluie)
	faisceau().set_shader_parameter("air", clampf(brume + 0.5 * pluie, 0.0, 1.0))
	# Le vent : une brise par beau temps, plus sous la pluie, une bourrasque
	# sous l'orage. `orage` est la seule jauge qui vaille 1 seulement à l'orage.
	var vent := clampf(0.15 + 0.3 * pluie + 0.55 * orage_courant, 0.0, 1.0)
	vegetal().set_shader_parameter("vent", vent)
	vegetal().set_shader_parameter("mouille", pluie)
	for m in [voxel(), voxel_fusionne()]:
		m.set_shader_parameter("couvert", chape)
	for cle in _voxels_teintes:
		(_voxels_teintes[cle] as ShaderMaterial).set_shader_parameter("couvert", chape)
	var p := post()
	p.set_shader_parameter("pluie", pluie)
	p.set_shader_parameter("eclair", eclair)
	for cle in _kenneys:
		(_kenneys[cle] as ShaderMaterial).set_shader_parameter("mouille", pluie)
	for m in _kenneys_derives:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("mouille", pluie)

static func regler_nuit(valeur: float) -> void:
	_nuit_courante = valeur
	for m in [sol(), eau(), facade(), flaque(), faisceau(), lumineux(), voxel(), voxel_fusionne(), post(), ombre()]:
		m.set_shader_parameter("nuit", valeur)
	for cle in _voxels_teintes:
		(_voxels_teintes[cle] as ShaderMaterial).set_shader_parameter("nuit", valeur)
	for cle in _kenneys:
		(_kenneys[cle] as ShaderMaterial).set_shader_parameter("nuit", valeur)
	for m in _kenneys_derives:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("nuit", valeur)

# ------------------------------------------------------------ l'ambiance

## L'heure de la ville est celle du VILLAGE : un cycle de quinze minutes calé
## sur l'heure universelle (quinze minutes de cycle), neuf minutes de jour, une
## de crépuscule, quatre de nuit, une d'aube. On entre en ville à l'heure qu'il
## est au village, et tous les joueurs voient la même. `nuit_forcee` sert au
## banc (`--nuit=0.5` photographie le crépuscule).
const CYCLE := 900.0
static var nuit_forcee := -1.0

## De 0 (plein jour) à 1 (pleine nuit), continue.
## L'heure du fond des MENUS : le couchant, sauf si `--nuit=` en décide
## autrement. C'est ainsi qu'on règle une capture sans recompiler.
##
## ⚠ Elle aussi vivait dans `scenes/menu.gd` : elle est descendue ici avec la
## ville de vitrine quand le hub a été retiré.
const CREPUSCULE := 0.50            ## 0 plein jour, 1 nuit noire

static func heure_de_vitrine() -> float:
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--nuit="):
			return clampf(float(String(argument).substr(7)), 0.0, 1.0)
	return CREPUSCULE

static func nuit() -> float:
	if nuit_forcee >= 0.0:
		return nuit_forcee
	var t := fmod(Time.get_unix_time_from_system(), CYCLE)
	if t < 540.0:
		return 0.0
	if t < 600.0:
		return (t - 540.0) / 60.0
	if t < 840.0:
		return 1.0
	return 1.0 - (t - 840.0) / 60.0

## Les trois heures de référence — jour, heure bleue, nuit — entre lesquelles
## tout s'interpole : ciel, soleil, ambiante, brouillard, halo.
const HEURES := [
	{"haut": Color("#3b7bd8"), "horizon": Color("#cfe2f5"), "sol_h": Color("#8fa0b0"), "sol_b": Color("#3a4450"),
		"soleil_x": -52.0, "soleil_y": -38.0, "soleil_c": Color("#fff0d0"), "soleil_e": 1.45,
		"ambiante": Color("#7f97c8"), "ambiante_e": 0.62, "brume": Color("#7f93ab"), "brume_d": 0.0005,
		"halo": 0.4, "seuil": 0.95, "lune": 0.1},
	{"haut": Color("#0a1030"), "horizon": Color("#c85a3a"), "sol_h": Color("#3a2430"), "sol_b": Color("#06070c"),
		"soleil_x": -42.0, "soleil_y": -52.0, "soleil_c": Color("#ffb27a"), "soleil_e": 1.25,
		"ambiante": Color("#3c4a7a"), "ambiante_e": 1.05, "brume": Color("#1c2036"), "brume_d": 0.0022,
		"halo": 0.9, "seuil": 0.72, "lune": 0.42},
	{"haut": Color("#03050e"), "horizon": Color("#101a30"), "sol_h": Color("#0b1020"), "sol_b": Color("#030408"),
		"soleil_x": -36.0, "soleil_y": -70.0, "soleil_c": Color("#5a6cc0"), "soleil_e": 0.28,
		"ambiante": Color("#1a2340"), "ambiante_e": 0.8, "brume": Color("#0a0e1c"), "brume_d": 0.0026,
		"halo": 1.0, "seuil": 0.6, "lune": 0.25},
]

static func _valeur(cle: String, n: float):
	var a: Dictionary
	var b: Dictionary
	var t: float
	if n < 0.5:
		a = HEURES[0]
		b = HEURES[1]
		t = n * 2.0
	else:
		a = HEURES[1]
		b = HEURES[2]
		t = (n - 0.5) * 2.0
	var va = a[cle]
	var vb = b[cle]
	if va is Color:
		return (va as Color).lerp(vb, t)
	return lerpf(float(va), float(vb), t)

## Le ciel, le soleil et son contre-jour, prêts à être réglés à l'heure. Il n'y
## a pas une seule vraie lumière dans la ville en dehors de ces deux-là : le
## mode compatibilité n'en supporte que huit par objet, et une flaque additive
## au sol fait le même effet pour rien.
## Un réglage du hub, lu SANS dépendre de l'autoload. ⚠ `Reglages` n'existe
## que dans le jeu : les ateliers et les bancs lancés en `-s script.gd` n'ont
## pas d'autoload, et une référence directe les ferait tous tomber en panne de
## compilation. On va donc le chercher dans l'arbre, et on retombe sur la
## valeur d'usine s'il n'y est pas.
static func _reglage(nom: String, defaut: bool) -> bool:
	var boucle := Engine.get_main_loop()
	if boucle == null or not (boucle is SceneTree):
		return defaut
	var noeud := (boucle as SceneTree).root.get_node_or_null("/root/Reglages")
	return bool(noeud.get(nom)) if noeud != null else defaut

static func ambiance() -> Array:
	var environnement := Environment.new()
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_curve = 0.10
	ciel.sun_angle_max = 30.0
	ciel.sun_curve = 0.12
	var voute := Sky.new()
	voute.sky_material = ciel
	environnement.background_mode = Environment.BG_SKY
	environnement.sky = voute
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environnement.fog_enabled = true
	environnement.fog_sky_affect = 0.35
	# Le halo et les ombres portées sont les deux réglages d'image des
	# options : ils valent pour la VILLE comme pour le menu, sinon « couper
	# les effets » ne changerait rien là où le jeu rame vraiment.
	environnement.glow_enabled = _reglage("effets", true)
	environnement.glow_strength = 1.0
	environnement.glow_bloom = 0.12
	environnement.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environnement.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environnement.tonemap_exposure = 1.12
	environnement.tonemap_white = 4.0
	var monde := WorldEnvironment.new()
	monde.environment = environnement

	var soleil := DirectionalLight3D.new()
	soleil.shadow_enabled = _reglage("ombres", true)
	soleil.directional_shadow_max_distance = 220.0
	soleil.shadow_bias = 0.05
	soleil.shadow_normal_bias = 1.5

	var lune := DirectionalLight3D.new()
	lune.light_color = Color("#5a72c8")
	lune.rotation_degrees = Vector3(-50, 135, 0)
	lune.shadow_enabled = false
	regler_heure(monde, soleil, lune, nuit())
	return [monde, soleil, lune]

## Règle le ciel et les lumières à l'heure `n` (0 jour, 1 nuit), et pousse la
## nuit aux shaders. À appeler à chaque image : c'est une poignée de nombres.
static func regler_heure(monde: WorldEnvironment, soleil: DirectionalLight3D, lune: DirectionalLight3D, n: float) -> void:
	var env := monde.environment
	var ciel := (env.sky.sky_material as ProceduralSkyMaterial)
	ciel.sky_top_color = _valeur("haut", n)
	ciel.sky_horizon_color = _valeur("horizon", n)
	ciel.ground_horizon_color = _valeur("sol_h", n)
	ciel.ground_bottom_color = _valeur("sol_b", n)
	env.ambient_light_color = _valeur("ambiante", n)
	env.ambient_light_energy = _valeur("ambiante_e", n)
	env.fog_light_color = _valeur("brume", n)
	env.fog_density = _valeur("brume_d", n)
	env.glow_intensity = _valeur("halo", n)
	env.glow_hdr_threshold = _valeur("seuil", n)
	soleil.light_color = _valeur("soleil_c", n)
	soleil.light_energy = _valeur("soleil_e", n)
	# Bas mais pas rasant : à vingt degrés, une tour projette une ombre de
	# trois pâtés et le joueur y disparaît.
	soleil.rotation_degrees = Vector3(_valeur("soleil_x", n), _valeur("soleil_y", n), 0)
	lune.light_energy = _valeur("lune", n)
	regler_nuit(n)
