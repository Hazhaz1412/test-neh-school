shader_type spatial;
// The grass of the little planet inside the glass ball (house_inside.gd): the meadow's blades
// and colours, but each blade stood where its MultiMesh transform puts it (on the sphere, y up
// along the ground's up), so it works the same on the real planet and on its tiny copy.
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform float blade_height = 0.45;
uniform float blade_width = 0.05;
uniform vec3 root_color : source_color = vec3(0.1, 0.28, 0.05);
uniform vec3 tip_color : source_color = vec3(0.5, 0.8, 0.2);
uniform vec3 dry_color : source_color = vec3(0.62, 0.66, 0.25);
uniform float wind = 0.22;

varying float tip;
varying float shade;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	vec2 seed = vec2(id * 0.0137, id * 0.0291);
	float r1 = hash(seed + 3.7);
	float r2 = hash(seed + 11.9);
	float size = blade_height * mix(0.55, 1.35, r1 * r1);
	float turn = r2 * 6.2831;
	vec3 v = VERTEX;
	tip = UV.y;
	v.x *= blade_width * mix(0.7, 1.3, r2);
	v.y *= size;
	vec2 c = vec2(cos(turn), sin(turn));
	v = vec3(v.x * c.x - v.z * c.y, v.y, v.x * c.y + v.z * c.x);
	float gust = sin(TIME * 1.3 + id * 0.0007) * 0.6 + sin(TIME * 2.7 + id * 0.0031) * 0.25;
	float bend = tip * tip;
	v.xz += (vec2(0.7, 0.35) * (gust + 0.6) * wind + c * (r1 - 0.5) * 0.25) * bend * size;
	v.y -= bend * size * 0.12 * abs(gust);
	VERTEX = v;
	NORMAL = normalize(mix(vec3(c.y, 0.0, -c.x), vec3(0.0, 1.0, 0.0), 0.7));
	shade = hash(seed + 21.3);
}

void fragment() {
	vec3 colour = mix(root_color, tip_color, smoothstep(0.0, 1.0, tip));
	colour = mix(colour, dry_color, smoothstep(0.75, 1.0, shade) * tip * 0.6);
	colour *= mix(0.8, 1.1, shade);
	ALBEDO = colour;
	ROUGHNESS = 0.85;
	SPECULAR = 0.0;
	BACKLIGHT = vec3(0.35, 0.5, 0.15) * tip;
	AO = mix(0.35, 1.0, tip);
	AO_LIGHT_AFFECT = 0.6;
}
