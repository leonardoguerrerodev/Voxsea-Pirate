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

// Color del agua profunda (luz que el agua dispersa hacia la cámara).
uniform vec3 water_color : source_color = vec3(0.04, 0.22, 0.27);
// Absorción por metro recorrido bajo el agua, por canal (Beer-Lambert): el rojo se
// pierde primero, así lo bajo se ve turquesa y lo hondo azul.
uniform vec3 absorption = vec3(0.45, 0.11, 0.08);
// Cuánto desvía la refracción lo que se ve bajo el agua.
uniform float refraction : hint_range(0.0, 0.2) = 0.04;
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.95);
// Compresión de la superficie (Jacobiano) bajo la cual aparece espuma: 1 = plana,
// menor = la ola se está apretando, como antes de romper.
uniform float jacobian_foam : hint_range(0.0, 1.0) = 0.9;
// Ancho de la franja de espuma donde el agua toca un objeto.
uniform float contact_foam : hint_range(0.0, 2.0) = 0.7;
// Falda del horizonte: descarta este radio alrededor de la cámara, donde ya dibuja
// la malla de detalle. 0 = no descarta (la malla de detalle).
uniform float inner_radius = 0.0;

// Aire seco dentro del barco (WaterMask): ahí el mar no se dibuja.
// ponytail: un barco por océano; varios → arreglo de transformaciones + atlas 3D.
uniform sampler3D ship_dry_air : filter_nearest; // VoxelTexture: ejes (y, x, z)
uniform mat4 ship_inverse = mat4(1.0); // mundo → coordenadas de voxel del barco
uniform ivec3 ship_size = ivec3(0); // 0 = sin barco

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

varying float jacobian;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ruido de valor 2D, para romper la espuma en manchas.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

// Profundidad (z de vista, negativa) de lo opaco que hay detrás del píxel.
float opaque_z(vec2 uv, mat4 inv_projection) {
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, texture(depth_texture, uv).r, 1.0);
	return view.z / view.w;
}

void vertex() {
	vec2 p = VERTEX.xz;
	vec3 offset = vec3(0.0);
	// Derivadas parciales de la superficie respecto de x y z, para la normal.
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
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
	}
	VERTEX += offset;
	NORMAL = normalize(cross(binormal, tangent));
	// Jacobiano del desplazamiento horizontal: cuánto se estira (>1) o aprieta (<1)
	// la superficie. Sale de las mismas derivadas que la normal.
	jacobian = tangent.x * binormal.z - binormal.x * tangent.z;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (inner_radius > 0.0 && distance(world.xz, CAMERA_POSITION_WORLD.xz) < inner_radius) {
		discard;
	}
	if (ship_size.x > 0) {
		ivec3 voxel = ivec3(floor((ship_inverse * vec4(world, 1.0)).xyz));
		if (all(greaterThanEqual(voxel, ivec3(0))) && all(lessThan(voxel, ship_size)) && texelFetch(ship_dry_air, voxel.yxz, 0).r > 0.0) {
			discard;
		}
	}
	// Refracción: lo de abajo se ve desviado por la normal. Si el punto desviado
	// queda delante del agua (un objeto sobre ella), se usa el sin desviar.
	float fade = clamp(8.0 / -VERTEX.z, 0.0, 1.0);
	vec2 uv = SCREEN_UV + NORMAL.xy * refraction * fade;
	float behind = opaque_z(uv, INV_PROJECTION_MATRIX);
	if (behind > VERTEX.z) {
		uv = SCREEN_UV;
		behind = opaque_z(uv, INV_PROJECTION_MATRIX);
	}
	// Metros recorridos bajo el agua hasta lo opaco (el cielo cuenta como infinito).
	float water_depth = max(VERTEX.z - behind, 0.0);
	vec3 transmittance = exp(-absorption * water_depth);

	// Espuma de compresión, en manchas que derivan con el mar.
	vec2 drift = vec2(ocean_time * 0.05);
	float patches = value_noise(world.xz * 0.35 + drift) * value_noise(world.xz * 1.7 - drift);
	float crest = (1.0 - smoothstep(jacobian_foam - 0.3, jacobian_foam, jacobian)) * smoothstep(0.1, 0.45, patches);

	// Franja de espuma en el contacto con objetos: aparece, se ensancha y se corta.
	float contact_depth = VERTEX.z - opaque_z(SCREEN_UV, INV_PROJECTION_MATRIX);
	float width = contact_foam * (0.75 + 0.25 * sin(ocean_time * 0.8) + 0.4 * value_noise(world.xz * 3.0 + drift * 4.0));
	float contact = smoothstep(0.0, 0.1 * width, contact_depth) * (1.0 - smoothstep(0.6 * width, width, contact_depth));

	float foam = clamp(crest + contact, 0.0, 1.0);
	// Lo que se ve a través del agua (atenuado) + la luz que el agua dispersa.
	ALBEDO = mix(water_color * (1.0 - transmittance), foam_color, foam);
	EMISSION = texture(screen_texture, uv).rgb * transmittance * (1.0 - foam);
	// Rugosidad baja: el reflejo del cielo sale del Environment con Fresnel.
	ROUGHNESS = mix(0.04, 0.8, foam);
	SPECULAR = 0.5;
}
