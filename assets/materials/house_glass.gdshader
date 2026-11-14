shader_type spatial;
// The glass ball on the table: clear in the middle, thicker towards its rim, a bright edge of
// lamplight on it. Seen from the planet inside, the same glass is a sky-wide dome.
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.86, 0.93, 1.0);

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - facing, 3.0);
	ALBEDO = tint * 0.3;
	METALLIC = 0.0;
	ROUGHNESS = 0.04;
	SPECULAR = 1.0;
	ALPHA = 0.05 + rim * 0.55;
}
