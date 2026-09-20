shader_type spatial;
render_mode cull_disabled, unshaded;

// Rippling interference surface used by the math_structure experiment.
// Three interfering waves displace the vertices; the fragment pass draws a grid
// tinted by how far the surface moved.

uniform float amplitude : hint_range(0.0, 2.0) = 0.35;
uniform float frequency : hint_range(0.0, 4.0) = 1.0;
uniform float speed : hint_range(0.0, 4.0) = 0.6;
uniform float drift : hint_range(0.0, 100.0) = 0.0;
uniform float grid_density : hint_range(1.0, 40.0) = 8.0;
uniform vec4 color_low : source_color = vec4(0.02, 0.05, 0.12, 1.0);
uniform vec4 color_high : source_color = vec4(0.20, 0.90, 1.00, 1.0);

varying float wave_height;

void vertex() {
	float phase = TIME * speed;

	// Three interfering waves: two axis-aligned, one radial from the drift point.
	float w = sin((VERTEX.x + drift) * frequency + phase) * 0.6;
	w += sin((VERTEX.z - drift * 0.5) * frequency * 1.7 - phase * 1.3) * 0.4;
	w += sin(length(VERTEX.xz - vec2(drift, drift)) * frequency * 0.6 - phase * 0.8) * 0.3;

	wave_height = w * amplitude;
	VERTEX.y += wave_height;
}

void fragment() {
	vec2 uv = UV * grid_density;
	vec2 cell = abs(fract(uv) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.06, min(cell.x, cell.y));

	float height = clamp(wave_height / max(amplitude, 0.001) * 0.5 + 0.5, 0.0, 1.0);
	vec3 base = mix(color_low.rgb, color_high.rgb, height);
	vec3 grid = mix(base, color_high.rgb * 1.5, line * 0.7);

	ALBEDO = grid;
}
