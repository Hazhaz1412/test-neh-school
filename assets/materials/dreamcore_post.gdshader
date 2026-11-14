shader_type canvas_item;
// The meadow seen the way a dream is remembered: soft at the edges, glowing in the light,
// colour bleeding apart towards the corners, shadows lifted to a pale lilac, a little grain,
// like an old digital photo of a place that should not be empty.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float aberration = 0.004;
uniform float soft_edges = 0.55;
uniform float halo = 0.35;
uniform float lift = 0.07;
uniform vec3 lift_tint : source_color = vec3(0.62, 0.58, 0.82);
uniform vec3 gain_tint : source_color = vec3(1.0, 0.97, 0.94);
uniform float saturation = 1.0;
uniform float vignette = 0.32;
uniform float grain = 0.045;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.6, 1.0));
	vec2 split = c * aberration * (0.4 + r * 2.0);
	vec3 col = vec3(texture(screen, uv + split).r, texture(screen, uv).g, texture(screen, uv - split).b);
	// Soft focus away from the middle of the view, and a halo round everything bright.
	vec3 blur = textureLod(screen, uv, 2.5).rgb * 0.5 + textureLod(screen, uv, 4.0).rgb * 0.5;
	col = mix(col, blur, soft_edges * smoothstep(0.18, 0.75, r));
	col += max(textureLod(screen, uv, 4.5).rgb - 0.55, vec3(0.0)) * halo;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = col * (1.0 - lift) + lift * lift_tint;
	col *= gain_tint;
	col *= 1.0 - vignette * smoothstep(0.35, 1.0, r);
	col += (hash(uv * 1000.0 + fract(TIME * 7.3)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
