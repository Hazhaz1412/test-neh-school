shader_type spatial;
// The giant room's window: the night sky outside, looked up from the eye's direction into the
// same night panorama the meadow uses, so it is a sky at the right distance from every angle,
// in the room and in its huge copy alike; a cold misty sheen over it.
render_mode unshaded, shadows_disabled;

uniform sampler2D sky : filter_linear, repeat_enable;
uniform float energy = 0.05;
uniform vec3 mist : source_color = vec3(0.16, 0.2, 0.32);

void fragment() {
	vec3 d = normalize(mat3(INV_VIEW_MATRIX) * normalize(VERTEX));
	vec2 uv = vec2(atan(d.x, -d.z) / 6.2831853 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	vec3 outside = texture(sky, uv).rgb * energy;
	ALBEDO = outside + mist * 0.35;
}
