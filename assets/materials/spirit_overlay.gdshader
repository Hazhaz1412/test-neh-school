shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float hit : hint_range(0.0, 1.0) = 0.0;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float alarm : hint_range(0.0, 1.0) = 0.0;
uniform float panic : hint_range(0.0, 1.0) = 0.0;
uniform float photo_flash : hint_range(0.0, 1.0) = 0.0;
uniform float adrenaline : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float edge = smoothstep(0.20, 0.75, length(uv - vec2(0.5)));
	vec2 wobble = vec2(sin(uv.y * 34.0 + TIME * 1.4), cos(uv.x * 21.0 - TIME)) * (0.0015 * strength + alarm * 0.002) * edge;
	vec3 color = texture(screen_texture, uv + wobble).rgb;
	float grain = fract(sin(dot(uv * 1800.0 + floor(TIME * 12.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 spirit = mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, 0.55);
	spirit *= vec3(1.04, 0.80, 0.98);
	spirit *= 1.0 - edge * 0.30;
	spirit *= 1.0 - edge * danger * (0.06 + 0.06 * sin(TIME * 7.0));
	spirit *= 1.0 - edge * panic * 0.13;
	spirit += (grain - 0.5) * 0.012;
	color = mix(color, spirit, strength);
	color = mix(color, vec3(0.45, 0.025, 0.045), hit * edge * 0.60);
	color = mix(color, vec3(0.16, 0.025, 0.025), alarm * edge * 0.20);
	color = mix(color, vec3(0.92, 0.97, 1.0), photo_flash * 0.28);
	color += vec3(0.07, 0.038, 0.01) * edge * adrenaline * (0.55 + 0.45 * sin(TIME * 9.0));
	COLOR = vec4(color, 1.0);
}
