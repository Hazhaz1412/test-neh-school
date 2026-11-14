shader_type spatial;
// Grass blades, every one placed by this shader. Each MultiMeshInstance3D is one square chunk
// of meadow (its origin is the chunk's centre); the MultiMesh behind it carries no positions,
// only a count. A blade's place, turn, height and shade come from hashing its INSTANCE_ID with
// the chunk's position, and it stands on ground_height(), the same rolling ground as the
// collider in dream_meadow.gd. The wind is a slow wave rolling across the field.
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform float chunk = 12.0;
uniform float blade_height = 0.55;
uniform float blade_width = 0.06;
uniform vec3 root_color : source_color = vec3(0.1, 0.28, 0.05);
uniform vec3 tip_color : source_color = vec3(0.5, 0.8, 0.2);
uniform vec3 dry_color : source_color = vec3(0.62, 0.66, 0.25);
uniform float wind = 0.22;
// Keep blades out of the tree's trunk and from under the bed.
uniform vec4 clear_a = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 clear_b = vec4(0.0, 0.0, 0.0, 0.0);

varying float shade;
varying float tip;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ground_height(vec2 p) {
	float d = length(p);
	float roll = 3.2 * sin(p.x * 0.026 + 0.3) * cos(p.y * 0.021) + 1.8 * sin(p.x * 0.047 - p.y * 0.033 + 1.0)
		+ 0.35 * sin(p.x * 0.11 + 1.3) * sin(p.y * 0.09 + 0.4);
	roll *= smoothstep(12.0, 55.0, d);
	float a = atan(p.y, p.x);
	float hills = smoothstep(140.0, 520.0, d);
	hills = hills * hills * (34.0 + 16.0 * sin(a * 3.0 + 0.7) + 8.0 * sin(a * 7.0 + 2.1));
	return roll + hills;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float id = float(INSTANCE_ID);
	vec2 seed = vec2(id * 0.0137 + origin.x * 0.731, id * 0.0291 + origin.z * 0.517);
	vec2 at = origin.xz + (vec2(hash(seed), hash(seed + 7.13)) - 0.5) * chunk;
	float r1 = hash(seed + 3.7);
	float r2 = hash(seed + 11.9);
	float size = blade_height * mix(0.55, 1.35, r1 * r1);
	float clear = 1.0;
	if (clear_a.w > 0.0) clear *= smoothstep(clear_a.w, clear_a.w + 0.3, length(at - clear_a.xz));
	if (clear_b.w > 0.0) clear *= smoothstep(clear_b.w, clear_b.w + 0.3, length(at - clear_b.xz));
	size *= clear;
	float turn = r2 * 6.2831;
	vec3 v = VERTEX;
	tip = UV.y;
	v.x *= blade_width * mix(0.7, 1.3, r2);
	v.y *= size;
	vec2 c = vec2(cos(turn), sin(turn));
	v = vec3(v.x * c.x - v.z * c.y, v.y, v.x * c.y + v.z * c.x);
	// A curve of its own, and the wind on top, both growing towards the tip.
	float gust = sin(TIME * 1.3 + at.x * 0.18 + at.y * 0.11) * 0.6 + sin(TIME * 2.7 + at.x * 0.5 - at.y * 0.4) * 0.25;
	float bend = tip * tip;
	v.xz += (vec2(0.7, 0.35) * (gust + 0.6) * wind + c * (r1 - 0.5) * 0.25) * bend * size;
	v.y -= bend * size * 0.12 * abs(gust);
	vec3 world = vec3(at.x, ground_height(at), at.y) + v;
	VERTEX = world - origin;
	// Light the blades as one soft surface, a little more from above than from the side.
	NORMAL = normalize(mix(vec3(c.y, 0.0, -c.x), vec3(0.0, 1.0, 0.0), 0.7));
	shade = hash(seed + 21.3);
}

void fragment() {
	vec3 colour = mix(root_color, tip_color, smoothstep(0.0, 1.0, tip));
	colour = mix(colour, dry_color, smoothstep(0.75, 1.0, shade) * tip * 0.6);
	colour *= mix(0.8, 1.1, shade);
	ALBEDO = colour;
	ROUGHNESS = 0.85;
	// No sky reflections: at grazing angles they turned the blades a glassy white.
	SPECULAR = 0.0;
	BACKLIGHT = vec3(0.35, 0.5, 0.15) * tip;
	AO = mix(0.35, 1.0, tip);
	AO_LIGHT_AFFECT = 0.6;
}
