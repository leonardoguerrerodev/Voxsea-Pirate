shader_type spatial;
render_mode cull_disabled;
// Vela: plano de lona que se infla hacia sotavento. `billow` (m, con signo) lo
// fija ShipPartsView por vela: 0 = plana, el signo dice hacia qué banda.

uniform sampler2D canvas : source_color, filter_linear_mipmap, repeat_disable;
instance uniform float billow = 0.0;
// Viento sobre la vela (0 = calma, ~1 = fresco): amplitud del flameo.
instance uniform float wind = 0.0;

void vertex() {
	// Máximo al centro, cero en los bordes (relinga atada a la verga y a las escotas).
	float belly = sin(PI * UV.x) * sin(PI * UV.y);
	// Flameo: ondas que corren por la tela, sobre el inflado.
	float ripple = sin(TIME * 3.1 + UV.x * 7.0 + UV.y * 3.0) * 0.6 + sin(TIME * 5.3 + UV.y * 9.0) * 0.4;
	VERTEX += NORMAL * (billow * belly * (1.0 + 0.06 * sin(TIME * 1.7)) + wind * 0.12 * ripple * belly);
}

void fragment() {
	ALBEDO = texture(canvas, UV).rgb;
	ROUGHNESS = 0.95;
}
