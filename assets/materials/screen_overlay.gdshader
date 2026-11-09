shader_type canvas_item;
// Full-screen feedback: a hit, the guard on your heels, panic, an alarm and the camera flash.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float hit : hint_range(0.0, 1.0) = 0.0;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float alarm : hint_range(0.0, 1.0) = 0.0;
uniform float panic : hint_range(0.0, 1.0) = 0.0;
uniform float photo_flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float edge = smoothstep(0.20, 0.75, length(uv - vec2(0.5)));
	vec3 color = texture(screen_texture, uv).rgb;
	color *= 1.0 - edge * danger * (0.06 + 0.06 * sin(TIME * 7.0));
	color *= 1.0 - edge * panic * 0.13;
	color = mix(color, vec3(0.30, 0.04, 0.04), hit * edge * 0.45);
	color = mix(color, vec3(0.16, 0.025, 0.025), alarm * edge * 0.20);
	color = mix(color, vec3(0.92, 0.97, 1.0), photo_flash * 0.28);
	COLOR = vec4(color, 1.0);
}
