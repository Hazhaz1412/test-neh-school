shader_type canvas_item;
// Behind the phone while it is held up: the room goes soft and dim, like eyes focused on a screen.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color = textureLod(screen_texture, uv, amount * 3.2).rgb;
	float edge = smoothstep(0.25, 0.85, length(uv - vec2(0.5)));
	color = mix(color, color * (0.55 - edge * 0.25), amount);
	COLOR = vec4(color, 1.0);
}
