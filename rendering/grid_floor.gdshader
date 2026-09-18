shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.08, 0.08, 0.12, 1.0);
uniform vec4 line_color : source_color = vec4(0.15, 0.15, 0.3, 1.0);
uniform float grid_size : hint_range(0.1, 10.0) = 1.0;
uniform float line_width : hint_range(0.001, 0.1) = 0.02;
uniform float metallic : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    vec2 uv = UV * 400.0 / grid_size;
    vec2 grid = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
    float line = min(grid.x, grid.y);
    float grid_factor = 1.0 - min(line, 1.0);
    
    ALBEDO = mix(base_color.rgb, line_color.rgb, grid_factor * 0.6);
    METALLIC = metallic;
    ROUGHNESS = roughness;
}
