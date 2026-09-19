shader_type canvas_item;
render_mode unshaded;

// Animated procedural background for menus. Cheap full-screen FBM, no lighting.

uniform float speed : hint_range(0.0, 0.5) = 0.05;
uniform float brightness : hint_range(0.0, 2.0) = 0.6;
uniform float pattern_scale : hint_range(0.5, 12.0) = 3.0;
uniform vec4 deep_color : source_color = vec4(0.02, 0.01, 0.05, 1.0);
uniform vec4 accent_color : source_color = vec4(0.0, 0.35, 0.45, 1.0);
uniform vec4 hot_color : source_color = vec4(0.45, 0.03, 0.22, 1.0);

uint chash(uint x, uint y, uint s) {
	uint h = x * 0x1E35A7BDu ^ y * 0x94D049BBu ^ s * 0x369DEA0Fu;
	h ^= h >> 16u; h *= 0x7FEB352Du; h ^= h >> 15u; h *= 0x846CA68Bu; h ^= h >> 16u;
	return h;
}

float chash2f(uint x, uint y, uint s) {
	return float(chash(x, y, s) >> 8u) / 16777216.0;
}

float vnoise(vec2 p, uint s) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(chash2f(uint(i.x), uint(i.y), s), chash2f(uint(i.x) + 1u, uint(i.y), s), u.x),
		mix(chash2f(uint(i.x), uint(i.y) + 1u, s), chash2f(uint(i.x) + 1u, uint(i.y) + 1u, s), u.x),
		u.y
	);
}

float fbm(vec2 p, uint s, int octaves) {
	float sum = 0.0;
	float amp = 1.0;
	float freq = 1.0;
	float maxv = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += amp * (vnoise(p * freq, s + uint(i) * 131u) * 2.0 - 1.0);
		maxv += amp;
		amp *= 0.5;
		freq *= 2.0;
	}
	return sum / maxv;
}

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.0, 0.56);	// keep features round on 16:9
	float t = TIME * speed;

	float n1 = fbm(uv * pattern_scale + vec2(t * 0.7, t * 0.25), 1337u, 4);
	float n2 = fbm(uv * pattern_scale * 2.1 + vec2(n1, -t * 0.4), 7919u, 3);

	float veins = pow(clamp(abs(n2) * 1.8, 0.0, 1.0), 2.0);
	float glow = smoothstep(0.15, 0.85, n1 * 0.5 + 0.5);

	vec3 col = deep_color.rgb;
	col = mix(col, accent_color.rgb, glow * 0.5);
	col = mix(col, hot_color.rgb, veins * 0.35);

	// Vignette keeps the middle of the screen readable for menu text.
	float vignette = smoothstep(1.25, 0.25, length(UV - 0.5) * 1.6);
	col *= brightness * (0.35 + 0.65 * vignette);

	COLOR = vec4(col, 1.0);
}
