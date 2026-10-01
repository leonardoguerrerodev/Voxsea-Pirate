shader_type spatial;
// Gerstner idéntico a WaveSettings.get_displacement (regla 1): si cambias uno, cambia el otro.
// El detalle fino (mapas de normales) y la iluminación solo cambian el aspecto, no la altura.
// Iluminación (light()) adaptada de 2Retr0/GodotOceanWaves (MIT, © 2024 Ethan Truong), que sigue
// la charla de GDC 2019 "Wakes, Explosions and Lighting: Interactive Water Simulation in Atlas".
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
// Claridad: divide la absorción. Más alto = se ve más hondo (agua más translúcida).
uniform float clarity : hint_range(0.25, 6.0) = 2.5;
// Color del agua poco profunda o a contraluz (luz que vuelve dispersada cerca de la superficie).
uniform vec3 shallow_color : source_color = vec3(0.05, 0.42, 0.42);
// Cuánta luz difusa "pinta" el agua: el agua real casi no tiene difusa, su color es dispersión.
uniform float diffuse_amount : hint_range(0.0, 1.0) = 0.15;
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

// Detalle fino: dos mapas de normales (OceanSurface los genera con ruido) que se
// desplazan en direcciones distintas. Escala en metros por repetición.
uniform sampler2D detail_normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 2.0) = 0.6;
uniform float detail_scale_a = 7.0;
uniform float detail_scale_b = 2.5;
uniform float detail_speed = 0.5;
// Distancia (m) a la que el detalle cae a un tercio: lejos solo aliasa.
uniform float detail_fade = 60.0;
// Brillo del sol: rugosidad de la reflexión directa (baja = destellos nítidos).
uniform float sun_roughness : hint_range(0.02, 1.0) = 0.25;
// Luz que atraviesa las crestas de cara al sol (verde turquesa).
uniform float scattering : hint_range(0.0, 3.0) = 1.0;

// Bodega del barco (WaterMask): ahí el mar no se dibuja.
// ponytail: un barco por océano; varios → arreglo de transformaciones + atlas 3D.
uniform sampler3D ship_dry_air : filter_nearest; // aire interior del casco (WaterMask): ejes (y, x, z)
uniform mat4 ship_inverse = mat4(1.0); // mundo → coordenadas de voxel del barco
uniform ivec3 ship_size = ivec3(0); // 0 = sin barco

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

varying float jacobian;
varying float wave_height;
varying float fresnel;
varying float foam_amount;

// Reflectancia del agua con incidencia normal (eta = 1,33).
const float REFLECTANCE = 0.02;

// Hash sin sin(): con sin() de números grandes la GPU pierde precisión y la
// espuma sale en cuadros (Dave Hoskins, "Hash without Sine").
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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
	wave_height = offset.y;
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
	// Detalle fino sobre la normal de las olas, en espacio mundo.
	float dist = distance(world.xz, CAMERA_POSITION_WORLD.xz);
	vec2 flow = vec2(ocean_time * detail_speed);
	vec2 da = texture(detail_normal_a, world.xz / detail_scale_a + flow * vec2(0.08, 0.05)).rg * 2.0 - 1.0;
	vec2 db = texture(detail_normal_b, world.xz / detail_scale_b - flow * vec2(0.03, 0.11)).rg * 2.0 - 1.0;
	vec3 geometric = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec2 slope = (da + db) * detail_strength * exp(-dist / detail_fade);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(geometric + vec3(slope.x, 0.0, slope.y)), 0.0)).xyz);

	// Refracción: lo de abajo se ve desviado por la normal. Si el punto desviado
	// queda delante del agua (un objeto sobre ella), se usa el sin desviar.
	float fade = clamp(8.0 / -VERTEX.z, 0.0, 1.0);
	// Sin limitar, cerca del borde la coordenada da la vuelta y muestra el otro lado de la pantalla.
	vec2 uv = clamp(SCREEN_UV + NORMAL.xy * refraction * fade, vec2(0.001), vec2(0.999));
	float behind = opaque_z(uv, INV_PROJECTION_MATRIX);
	if (behind > VERTEX.z) {
		uv = SCREEN_UV;
		behind = opaque_z(uv, INV_PROJECTION_MATRIX);
	}
	// Metros recorridos bajo el agua hasta lo opaco (el cielo cuenta como infinito).
	float water_depth = max(VERTEX.z - behind, 0.0);
	vec3 transmittance = exp(-absorption * water_depth / clarity);

	// Espuma de compresión, en manchas que derivan con el mar.
	vec2 drift = vec2(ocean_time * 0.05);
	float patches = value_noise(world.xz * 0.35 + drift) * value_noise(world.xz * 1.7 - drift);
	float crest = (1.0 - smoothstep(jacobian_foam - 0.3, jacobian_foam, jacobian)) * smoothstep(0.1, 0.45, patches);

	// Franja de espuma en el contacto con objetos: aparece, se ensancha y se corta.
	float contact_depth = VERTEX.z - opaque_z(SCREEN_UV, INV_PROJECTION_MATRIX);
	float width = contact_foam * (0.75 + 0.25 * sin(ocean_time * 0.8) + 0.4 * value_noise(world.xz * 3.0 + drift * 4.0));
	float contact = smoothstep(0.0, 0.1 * width, contact_depth) * (1.0 - smoothstep(0.6 * width, width, contact_depth));

	float foam = clamp(crest + contact, 0.0, 1.0);
	foam_amount = foam;
	// Lo que se ve a través del agua (atenuado) + la luz que el agua dispersa.
	// La cara de la ola que mira a la cámara y sube deja pasar más luz: turquesa.
	float thin = clamp(wave_height * 0.5 + 0.5, 0.0, 1.0) * (1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0));
	vec3 body = mix(water_color, shallow_color, thin * 0.6);
	ALBEDO = mix(body * (1.0 - transmittance), foam_color, foam);
	EMISSION = texture(screen_texture, uv).rgb * transmittance * (1.0 - foam);
	// Rugosidad baja: el reflejo del cielo sale del Environment con Fresnel.
	ROUGHNESS = mix(0.04, 0.8, foam);
	SPECULAR = 0.5;
	// Fresnel aproximado con rugosidad (Atlas): de frente casi no refleja, rasante sí.
	fresnel = mix(pow(1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0), 5.0 * exp(-2.69 * sun_roughness)) / (1.0 + 22.7 * pow(sun_roughness, 1.5)), 1.0, REFLECTANCE);
}

float smith_masking(float cos_theta, float alpha) {
	float a = cos_theta / (alpha * sqrt(max(1.0 - cos_theta * cos_theta, 1e-5)));
	return a < 1.6 ? (1.0 - 1.259 * a + 0.396 * a * a) / (3.535 * a + 2.181 * a * a) : 0.0;
}

float ggx(float cos_theta, float alpha) {
	float a2 = alpha * alpha;
	float d = 1.0 + (a2 - 1.0) * cos_theta * cos_theta;
	return a2 / (PI * d * d);
}

void light() {
	vec3 halfway = normalize(LIGHT + VIEW);
	float dot_nl = max(dot(NORMAL, LIGHT), 2e-5);
	float dot_nv = max(dot(NORMAL, VIEW), 2e-5);
	// Especular GGX con Fresnel: los destellos del sol.
	float light_mask = smith_masking(dot_nv, sun_roughness);
	float view_mask = smith_masking(dot_nl, sun_roughness);
	float attenuation = 1.0 / (1.0 + light_mask + view_mask);
	SPECULAR_LIGHT += fresnel * ggx(dot(NORMAL, halfway), sun_roughness) * attenuation / (4.0 * dot_nv + 0.1) * ATTENUATION * LIGHT_COLOR * (1.0 - foam_amount);
	// Difusa: luz que atraviesa las crestas a contraluz (más verde) + lambert suave.
	const vec3 sss_tint = vec3(0.9, 1.15, 0.85);
	float sss_crest = max(0.0, wave_height + 1.0) * pow(max(dot(LIGHT, -VIEW), 0.0), 4.0) * pow(0.5 - 0.5 * dot(LIGHT, NORMAL), 3.0);
	float sss_near = 0.5 * dot_nv * dot_nv;
	vec3 diffuse = (sss_crest + sss_near) * scattering * sss_tint / (1.0 + light_mask) + vec3(diffuse_amount * dot_nl);
	DIFFUSE_LIGHT += mix(diffuse * (1.0 - fresnel), vec3(dot_nl), foam_amount) * ATTENUATION * LIGHT_COLOR;
}
