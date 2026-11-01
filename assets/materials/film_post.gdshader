shader_type canvas_item;
// Camera-like finish over the 3D view: slight lens split, grain and dark corners.
uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain = 0.045;
uniform float split = 0.0016;
uniform float corners = 0.62;
float noise(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 centre = SCREEN_UV - 0.5;
	float edge = dot(centre, centre);
	vec2 offset = centre * (split + edge * split * 1.6);
	vec3 color = vec3(texture(screen, SCREEN_UV + offset).r, texture(screen, SCREEN_UV).g, texture(screen, SCREEN_UV - offset).b);
	color *= 1.0 - smoothstep(0.12, 0.62, edge) * corners;
	float speck = noise(FRAGCOORD.xy + fract(TIME) * 91.0) - 0.5;
	color += speck * grain * (1.0 - color * 0.6);
	COLOR = vec4(color, 1.0);
}
