shader_type spatial;
// A memory shard on the roller coaster's dream flight (coaster_dream.gd): a crystal lit from
// inside, its colour shimmering across its faces and pulsing slowly. `taken` makes it flare white
// as it is caught.
render_mode unshaded, cull_back;

uniform vec3 tint : source_color = vec3(0.6, 0.85, 1.0);
uniform float taken = 0.0;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float shimmer = 0.5 + 0.5 * sin(TIME * 3.0 + dot(NORMAL, vec3(5.0, 3.0, 4.0)));
	vec3 colour = mix(tint * 1.6, vec3(1.0), pow(1.0 - facing, 2.0) * 0.6 + shimmer * 0.15);
	colour *= 1.8 + 0.6 * sin(TIME * 2.2);
	ALBEDO = mix(colour, vec3(6.0), taken);
}
