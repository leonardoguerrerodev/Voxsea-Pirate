shader_type spatial;
// Gerstner idéntico a WaveSettings.get_displacement (regla 1): si cambias uno, cambia el otro.
// depth_draw_always: sin esto, las olas lejanas se pintan encima de las cercanas.
render_mode world_vertex_coords, depth_draw_always;

const int MAX_WAVES = 8;
const float GRAVITY = 9.81;

// Los llena OceanSurface desde WaveSettings y Game.ocean_time.
uniform vec4 waves[MAX_WAVES]; // (dirección en radianes, amplitud, longitud, empinamiento)
uniform int wave_count = 0;
uniform float ocean_time = 0.0;

uniform vec3 shallow_color : source_color = vec3(0.08, 0.5, 0.5);
uniform vec3 deep_color : source_color = vec3(0.02, 0.1, 0.2);
uniform float depth_fade : hint_range(0.1, 20.0) = 4.0;
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.95);
// Fracción de la amplitud total desde la que aparece espuma en la cresta.
uniform float crest_foam : hint_range(0.0, 1.0) = 0.45;
// Ancho de la espuma donde el agua toca un objeto.
uniform float contact_foam : hint_range(0.0, 2.0) = 0.3;
// Falda del horizonte: descarta este radio alrededor de la cámara, donde ya dibuja
// la malla de detalle. 0 = no descarta (la malla de detalle).
uniform float inner_radius = 0.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying float wave_height;
varying float total_amplitude;

void vertex() {
	vec2 p = VERTEX.xz;
	vec3 offset = vec3(0.0);
	// Derivadas parciales de la superficie respecto de x y z, para la normal.
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	total_amplitude = 0.0;
	for (int i = 0; i < wave_count; i++) {
		vec4 w = waves[i];
		vec2 dir = vec2(cos(w.x), sin(w.x));
		float k = TAU / w.z;
		float speed = sqrt(GRAVITY / k);
		float phase = k * (dot(dir, p) - speed * ocean_time);
		float horizontal = w.w / (k * float(wave_count));
		float c = cos(phase);
		float s = sin(phase);
		offset += vec3(dir.x * horizontal * c, w.y * s, dir.y * horizontal * c);
		tangent += vec3(-dir.x * dir.x * horizontal * k * s, dir.x * w.y * k * c, -dir.x * dir.y * horizontal * k * s);
		binormal += vec3(-dir.x * dir.y * horizontal * k * s, dir.y * w.y * k * c, -dir.y * dir.y * horizontal * k * s);
		total_amplitude += w.y;
	}
	VERTEX += offset;
	NORMAL = normalize(cross(binormal, tangent));
	wave_height = offset.y;
}

void fragment() {
	if (inner_radius > 0.0) {
		vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if (distance(world.xz, CAMERA_POSITION_WORLD.xz) < inner_radius) {
			discard;
		}
	}
	// Profundidad del agua a lo largo de la vista: superficie vs. lo opaco que hay detrás.
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = VERTEX.z - behind.z;
	float depth_mix = clamp(water_depth / depth_fade, 0.0, 1.0);

	float crest = smoothstep(crest_foam, 1.0, wave_height / max(total_amplitude, 0.001));
	float contact = 1.0 - smoothstep(0.0, contact_foam, water_depth);
	float foam = clamp(crest + contact, 0.0, 1.0);

	ALBEDO = mix(mix(shallow_color, deep_color, depth_mix), foam_color, foam);
	ALPHA = mix(mix(0.6, 1.0, depth_mix), 1.0, foam);
	// Rugosidad baja: el reflejo del cielo sale del Environment con Fresnel.
	ROUGHNESS = mix(0.04, 0.8, foam);
	SPECULAR = 0.5;
}
