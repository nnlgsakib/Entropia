shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float time_scale : hint_range(0.0, 2.0) = 0.3;
uniform int pattern_type : hint_range(0, 10) = 0;
uniform float warp_strength : hint_range(0.0, 5.0) = 1.5;
uniform float color_shift : hint_range(0.0, 2.0) = 0.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform int seed_val : hint_range(0, 99999) = 42;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

uint chash(uint x, uint y, uint s) {
	uint h = x * 0x1E35A7BDu ^ y * 0x94D049BBu ^ s * 0x369DEA0Fu;
	h ^= h >> 16u; h *= 0x7FEB352Du; h ^= h >> 15u; h *= 0x846CA68Bu; h ^= h >> 16u;
	return h;
}

float chash2f(uint x, uint y, uint s) {
	return float(chash(x, y, s) >> 8u) / 16777216.0;
}

float csmoothstep(float t) {
	return t * t * (3.0 - 2.0 * t);
}

float value_noise(vec2 p, uint s) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	float sx = csmoothstep(f.x);
	float sy = csmoothstep(f.y);
	float v00 = chash2f(uint(i.x), uint(i.y), s);
	float v10 = chash2f(uint(i.x) + 1u, uint(i.y), s);
	float v01 = chash2f(uint(i.x), uint(i.y) + 1u, s);
	float v11 = chash2f(uint(i.x) + 1u, uint(i.y) + 1u, s);
	return mix(mix(v00, v10, sx), mix(v01, v11, sx), sy);
}

float cfractal_noise(vec2 p, uint s, int octaves) {
	float sum = 0.0;
	float amp = 1.0;
	float freq = 1.0;
	float maxv = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += amp * (value_noise(p * freq, s + uint(i) * 997u) * 2.0 - 1.0);
		maxv += amp;
		amp *= 0.5;
		freq *= 2.0;
	}
	return sum / maxv;
}

vec3 palette_chaos(float t, uint s) {
	t = clamp(t, 0.0, 1.0);
	uint h = uint(int(t * 99999.0)) ^ s;
	float r = clamp(0.5 + 1.5 * t + float(h & 0x3FFu) / 1023.0 * 0.5, 0.0, 1.0);
	float g = clamp(0.1 + 2.0 * float((h >> 10u) & 0x3FFu) / 1023.0, 0.0, 1.0);
	float b = clamp(0.0 + 3.0 * (1.0 - t) * float((h >> 20u) & 0x3FFu) / 1023.0, 0.0, 1.0);
	return vec3(r, g, b);
}

void fragment() {
	float t = TIME * time_scale;
	vec2 uv = UV;
	uint s = uint(seed_val);

	vec2 p = uv * 4.0;
	float n1 = cfractal_noise(p, s, 6);
	float n2 = cfractal_noise(p * 1.7 + vec2(t * 0.5), s ^ 0x111u, 5);
	float n3 = cfractal_noise(p * 2.5 + vec2(0.0, t * 0.3), s ^ 0x222u, 4);

	float warp_x = n1 * warp_strength * 0.3;
	float warp_y = n2 * warp_strength * 0.3;
	vec2 wp = p + vec2(warp_x, warp_y);

	float val = cfractal_noise(wp * 2.0, s ^ 0x444u, 5);
	val = val * 0.5 + 0.5;

	float ct = val + color_shift + t * 0.1;
	vec3 col = palette_chaos(ct, s);

	col *= brightness;
	col *= intensity;

	ALBEDO = col;
	METALLIC = 0.1;
	ROUGHNESS = 0.6;
	EMISSION = col * 0.5;
}
