shader_type spatial;
// The walls of the giant room: old yellowed wallpaper, broad stripes with a damask diamond in
// every other one, darker towards the floor and the ceiling, faint water stains. Laid out from
// the room's own coordinates (the mesh is built in them), so the room and its huge copy round
// the little planet (house_inside.gd) carry the same paper.
render_mode diffuse_lambert_wrap;

uniform vec3 paper : source_color = vec3(0.78, 0.68, 0.44);
uniform vec3 ink : source_color = vec3(0.6, 0.5, 0.3);
uniform float stripe = 3.2;
uniform float height = 42.0;
uniform sampler2D stains : filter_linear_mipmap, repeat_enable;

varying vec3 local;
varying vec3 normal_local;

void vertex() {
	local = VERTEX;
	normal_local = NORMAL;
}

void fragment() {
	float across = abs(normal_local.x) > 0.5 ? local.z : local.x;
	vec2 p = vec2(across / stripe, local.y / (stripe * 1.6));
	float band = mod(floor(p.x), 2.0);
	vec2 cell = fract(p) - 0.5;
	// Diamond with a smaller one inside it, and a dot at its heart.
	float d = abs(cell.x) * 1.6 + abs(cell.y);
	float motif = smoothstep(0.42, 0.4, d) * (1.0 - smoothstep(0.3, 0.28, d) * (1.0 - smoothstep(0.12, 0.1, d)));
	float pin = smoothstep(0.03, 0.0, abs(fract(p.x) - 0.5) - 0.47);
	vec3 colour = mix(paper, ink, (band * motif * 0.55) + pin * 0.35);
	float s = texture(stains, vec2(across, local.y) * 0.006).r;
	colour *= mix(1.0, 0.82, smoothstep(0.55, 0.8, s));
	colour *= mix(0.72, 1.0, smoothstep(0.0, 8.0, local.y)) * mix(0.8, 1.0, smoothstep(height, height - 10.0, local.y));
	ALBEDO = colour;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
