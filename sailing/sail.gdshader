shader_type spatial;
render_mode cull_disabled;
// Vela: plano de lona que se infla hacia sotavento. `billow` (m, con signo) lo
// fija ShipPartsView por vela: 0 = plana, el signo dice hacia qué banda.

uniform sampler2D canvas : source_color, filter_linear_mipmap, repeat_disable;
instance uniform float billow = 0.0;

void vertex() {
	// Máximo al centro, cero en los bordes (relinga atada a la verga y al mástil).
	VERTEX += NORMAL * billow * sin(PI * UV.x) * sin(PI * UV.y);
}

void fragment() {
	ALBEDO = texture(canvas, UV).rgb;
	ROUGHNESS = 0.95;
}
