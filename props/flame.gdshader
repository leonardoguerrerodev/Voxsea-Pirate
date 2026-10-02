shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Llama de vela: un quad que siempre mira a la cámara, con una gota que se mece y
// parpadea. Aditiva: solo suma luz.

uniform vec3 core : source_color = vec3(1.0, 0.92, 0.6);
uniform vec3 edge : source_color = vec3(1.0, 0.45, 0.08);
uniform float strength = 2.5;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;  // x: -1..1, y: -1 (arriba)..1 (abajo)
	float height = 1.0 - (p.y + 1.0) * 0.5;  // 0 abajo, 1 arriba
	// Se mece más arriba que en la mecha.
	p.x += sin(TIME * 7.0 + height * 3.0) * 0.12 * height;
	// Gota: ancha abajo, en punta arriba.
	float width = mix(0.55, 0.05, pow(height, 0.8));
	float shape = 1.0 - smoothstep(0.0, width, abs(p.x)) ;
	shape *= smoothstep(1.0, 0.6, p.y) * smoothstep(-1.0, -0.7, p.y);
	float flicker = 0.85 + 0.1 * sin(TIME * 23.0) + 0.05 * sin(TIME * 41.0 + 1.3);
	ALBEDO = mix(edge, core, shape) * strength * flicker;
	ALPHA = shape;
}
