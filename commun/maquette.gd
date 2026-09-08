class_name Maquette
extends CanvasLayer
## L'effet « maquette » (tilt-shift) : l'image est nette sur une bande à
## hauteur du joueur et se trouble vers le haut et le bas de l'écran, comme
## une photo de miniature prise à la lentille à bascule. Le village en
## voxels y gagne ce qu'il est : un petit monde qu'on regarde de haut.
##
## C'est un plein écran posé ENTRE le monde 3D et l'interface (couche 0 :
## l'interface est en couche 1) qui relit l'image rendue. Le flou est un
## disque de douze prélèvements dont le rayon grandit avec la distance à la
## ligne de netteté, plus un cran de mipmap quand le moteur en fournit ; on
## y ajoute un peu de saturation et de contraste — la signature des photos
## de maquettes — et un vignettage discret.

const CODE := """
shader_type canvas_item;
uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform float centre = 0.6;        // la ligne nette, en fraction de la hauteur
uniform float nettete = 0.14;      // demi-largeur de la bande nette
uniform float fondu = 0.36;        // sur quelle hauteur le flou monte
uniform float force = 6.0;         // rayon du flou au bord, en pixels
uniform float saturation = 1.18;
uniform float contraste = 1.06;
uniform float vignette = 0.28;

const vec2 DISQUE[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	vec2 uv = SCREEN_UV;
	float ecart = abs(uv.y - centre);
	float flou = smoothstep(nettete, nettete + fondu, ecart);
	float rayon = flou * force;
	vec2 pas = SCREEN_PIXEL_SIZE * rayon;
	float niveau = flou * 1.0;
	vec4 couleur = textureLod(ecran, uv, niveau) * 2.0;
	for (int i = 0; i < 12; i++) {
		couleur += textureLod(ecran, uv + DISQUE[i] * pas, niveau);
	}
	couleur /= 14.0;
	float gris = dot(couleur.rgb, vec3(0.299, 0.587, 0.114));
	couleur.rgb = mix(vec3(gris), couleur.rgb, saturation);
	couleur.rgb = (couleur.rgb - 0.5) * contraste + 0.5;
	float bord = distance(uv, vec2(0.5, 0.5));
	couleur.rgb *= 1.0 - vignette * smoothstep(0.42, 0.95, bord);
	COLOR = vec4(couleur.rgb, 1.0);
}
"""

static var _shader: Shader

var _voile: ColorRect

## Pose l'effet sur un écran. `centre` : la hauteur de la ligne nette (0 en
## haut, 1 en bas) — celle où se tient le joueur.
static func poser(ecran: Node, centre: float = 0.6, force: float = 6.0) -> Maquette:
	var m := Maquette.new()
	m.layer = 0
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var matiere := ShaderMaterial.new()
	matiere.shader = _shader
	matiere.set_shader_parameter("centre", centre)
	matiere.set_shader_parameter("force", force)
	m._voile = ColorRect.new()
	m._voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	m._voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m._voile.material = matiere
	m.add_child(m._voile)
	ecran.add_child(m)
	return m

func regler(nom: String, valeur: float) -> void:
	(_voile.material as ShaderMaterial).set_shader_parameter(nom, valeur)
