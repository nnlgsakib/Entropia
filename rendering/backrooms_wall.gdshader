shader_type spatial;
render_mode cull_back;

uniform int seed_val : hint_range(0, 99999) = 0;
uniform int pattern_type : hint_range(0, 10) = 0;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.8;
uniform float time_speed : hint_range(0.0, 2.0) = 0.5;
uniform float color_intensity : hint_range(0.5, 3.0) = 1.2;

uint chash(uint x, uint y, uint s) {
	uint h = x * 0x1E35A7BDu ^ y * 0x94D049BBu ^ s * 0x369DEA0Fu;
	h ^= h >> 16u; h *= 0x7FEB352Du; h ^= h >> 15u; h *= 0x846CA68Bu; h ^= h >> 16u;
	return h;
}

float chash2f(uint x, uint y, uint s) {
	return float(chash(x, y, s) >> 8u) / 16777216.0;
}

float csmooth(float t) {
	return t * t * (3.0 - 2.0 * t);
}

float vnoise(vec2 p, uint s) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	float sx = csmooth(f.x);
	float sy = csmooth(f.y);
	return mix(
		mix(chash2f(uint(i.x), uint(i.y), s), chash2f(uint(i.x) + 1u, uint(i.y), s), sx),
		mix(chash2f(uint(i.x), uint(i.y) + 1u, s), chash2f(uint(i.x) + 1u, uint(i.y) + 1u, s), sx),
		sy
	);
}

float fbm(vec2 p, uint s, int oct) {
	float v = 0.0, a = 1.0, f = 1.0, mx = 0.0;
	for (int i = 0; i < oct; i++) {
		v += a * (vnoise(p * f, s + uint(i) * 997u) * 2.0 - 1.0);
		mx += a; a *= 0.5; f *= 2.0;
	}
	return v / mx;
}

vec3 palette(float t, uint s) {
	t = clamp(t, 0.0, 1.0);
	uint h = uint(int(t * 77777.0)) ^ s;
	// Dark moody palette — not white
	float r = 0.02 + 0.6 * t * float(h & 0xFFu) / 255.0;
	float g = 0.01 + 0.3 * t * float((h >> 8u) & 0xFFu) / 255.0;
	float b = 0.05 + 0.8 * (1.0 - t) * float((h >> 16u) & 0xFFu) / 255.0;
	return vec3(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0));
}

void fragment() {
	float t = TIME * time_speed;
	vec2 uv = UV * 3.0;
	uint s = uint(seed_val);

	float n1 = fbm(uv, s, 6);
	float n2 = fbm(uv * 2.3 + vec2(t * 0.7, t * 0.3), s ^ 0x111u, 5);
	float n3 = fbm(uv * 4.1 + vec2(n1 * 1.5, n2 * 1.5), s ^ 0x222u, 4);

	float val = 0.0;
	vec3 col = vec3(0.0);

	if (pattern_type == 0) {
		// Vortex — swirling dark spirals
		float angle = atan(uv.y - 1.5, uv.x - 1.5);
		float rad = length(uv - 1.5);
		val = sin(angle * 6.0 + rad * 8.0 - t * 3.0) * 0.5 + 0.5;
		val *= 1.0 / (1.0 + rad * 0.4);
		col = palette(val, s);
	} else if (pattern_type == 1) {
		// Liquid — flowing dark waves
		val = sin(n2 * 4.0 + t * 2.0) * 0.5 + 0.5;
		val *= n1 * 0.5 + 0.5;
		col = palette(val, s ^ 0x333u);
	} else if (pattern_type == 2) {
		// Noise warp — distorted dark fields
		float warp = fbm(uv + vec2(n1, n2) * 1.2, s ^ 0x444u, 5);
		val = warp * 0.5 + 0.5;
		col = palette(val * 0.8, s ^ 0x555u);
	} else if (pattern_type == 3) {
		// Grain — noisy dark texture
		val = vnoise(uv * 8.0 + vec2(t * 0.5), s ^ 0x666u);
		col = palette(val, s ^ 0x666u);
	} else if (pattern_type == 4) {
		// Tendrils — dark organic shapes
		val = fbm(uv * 2.0 + vec2(sin(t * 0.5) * 0.5, cos(t * 0.3) * 0.5), s ^ 0x777u, 6);
		val = pow(abs(val), 0.4);
		col = palette(val, s ^ 0x777u);
	} else if (pattern_type == 5) {
		// Void — mostly black with faint pulses
		val = fbm(uv * 1.5 + vec2(t * 0.2), s ^ 0x888u, 4);
		val = pow(abs(val), 2.0) * 0.3;
		col = palette(val, s ^ 0x888u);
	} else if (pattern_type == 6) {
		// Abyss — deep dark ripples
		float d = length(uv - 1.5);
		val = sin(d * 6.0 - t * 2.0) * 0.5 + 0.5;
		val *= exp(-d * 0.5) * 0.5;
		col = palette(val, s ^ 0x999u);
	} else if (pattern_type == 7) {
		// Chaos burst — sharp dark/light contrasts
		val = fbm(uv * 3.0 + vec2(n1 * 2.0), s ^ 0xAAAu, 4);
		val = step(0.2, val) * 0.8 + 0.1;
		col = palette(val + t * 0.05, s ^ 0xAAAu);
	} else if (pattern_type == 8) {
		// Glitch wave — digital distortion
		float gx = fbm(uv + vec2(0.02, 0.0), s, 3) - fbm(uv - vec2(0.02, 0.0), s, 3);
		float gy = fbm(uv + vec2(0.0, 0.02), s, 3) - fbm(uv - vec2(0.0, 0.02), s, 3);
		val = length(vec2(gx, gy)) * 2.0;
		val = clamp(val, 0.0, 0.8);
		col = palette(val, s ^ 0xBBBu);
	} else if (pattern_type == 9) {
		// Neo hell — dark with red/purple tones
		val = fbm(uv * 2.0 + vec2(t * 0.3, 0.0), s ^ 0xCCCcu, 5);
		val = val * 0.5 + 0.5;
		col = vec3(val * 0.4, 0.0, val * 0.6);
	} else {
		// Random mix — blend of chaos
		val = n1 * n2 + n3 * 0.5;
		val = val * 0.5 + 0.5;
		col = palette(val * 0.6, s ^ 0xEEEu);
	}

	col = max(col, vec3(0.01));
	col *= color_intensity;

	ALBEDO = col;
	EMISSION = col * emission_strength;
	ROUGHNESS = 0.7;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
