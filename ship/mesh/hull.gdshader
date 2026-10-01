shader_type spatial;
// Casco del barco: color por material (vértice, sRGB) y bordes biselados solo
// donde de verdad hay una arista. Mira los vecinos en la grilla (VoxelTexture),
// así una pared plana de muchos voxels no se llena de líneas.

uniform sampler3D solids : filter_nearest; // VoxelTexture: ejes (y, x, z)
uniform ivec3 grid_size = ivec3(0);
// Ancho del bisel, en fracción de voxel.
uniform float bevel : hint_range(0.0, 0.5) = 0.18;
// Cuánto oscurecen las aristas y los rincones.
uniform float edge_shade : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

// Esquina del chunk en voxels; la pone ShipMesh por instancia.
instance uniform vec3 chunk_origin;

varying vec3 voxel_pos;
varying vec3 face;

bool solid(ivec3 cell) {
	if (any(lessThan(cell, ivec3(0))) || any(greaterThanEqual(cell, grid_size))) {
		return false;
	}
	return texelFetch(solids, cell.yxz, 0).r > 0.0;
}

// Bisel hacia los dos lados del eje tangente t.
void edge(ivec3 cell, ivec3 normal, vec3 t, float f, inout vec3 bent, inout float shade) {
	for (int side = -1; side <= 1; side += 2) {
		float d = side < 0 ? f : 1.0 - f;
		if (d >= bevel) {
			continue;
		}
		ivec3 step = ivec3(t) * side;
		float k = 1.0 - d / bevel; // 0 donde empieza el bisel, 1 en la arista
		if (!solid(cell + step)) {
			// Arista convexa: la cara dobla hacia afuera.
			bent += vec3(step) * k * 0.8;
			shade = max(shade, k * edge_shade * 0.6);
		} else if (solid(cell + step + normal)) {
			// Rincón (arista cóncava): sombra suave.
			shade = max(shade, k * edge_shade);
		}
	}
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	voxel_pos = VERTEX + chunk_origin;
	face = NORMAL;
}

void fragment() {
	vec3 n = normalize(face);
	ivec3 ni = ivec3(round(n));
	// El voxel sólido al que pertenece esta cara y la posición dentro de él (0..1).
	ivec3 cell = ivec3(floor(voxel_pos - n * 0.5));
	vec3 f = voxel_pos - vec3(cell);
	vec3 t1 = abs(n.x) > 0.5 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t2 = vec3(1.0) - abs(n) - t1;
	vec3 bent = n;
	float shade = 0.0;
	edge(cell, ni, t1, dot(f, t1), bent, shade);
	edge(cell, ni, t2, dot(f, t2), bent, shade);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(normalize(bent), 0.0)).xyz);
	ALBEDO = srgb_to_linear(COLOR.rgb) * (1.0 - shade);
	ROUGHNESS = roughness;
}
