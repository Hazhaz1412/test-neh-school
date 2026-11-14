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
// At night only the strip of meadow inside the box is kept (world z from keep_z.x to keep_z.y).
uniform vec2 keep_z = vec2(-1e9, 1e9);
// The box the night meadow turns into (land_fold.gd): seen along x it is a square of side
// box_size with rounded corners of box_radius; the meadow is its floor, from box_z0 + radius to
// box_z0 + size - radius. Its other faces (the wall with the fairground, the ceiling with the
// house, the far wall) are walked like ground. The meadow is flattened along both edges of the
// floor (band) so the box's corners leave it without a step.
uniform float box_radius = 16.0;
uniform float box_y0 = 0.0;
uniform float box_z0 = -24.0;
uniform float box_size = 96.0;
// On a face of the box every blade is placed in box space (u along x, s round the box from the
// floor's near edge) round its chunk's centre `fold_chunk`, and stands on the box's own up.
uniform bool on_fold = false;
uniform float fold_half = 64.0;
// Paved circles (u, s, radius) where no grass grows, and the path (half width, s from, s to).
uniform vec3 fold_clear = vec3(0.0);
uniform vec3 fold_clear2 = vec3(0.0);
uniform vec3 fold_path = vec3(0.0);
instance uniform vec2 fold_chunk = vec2(0.0);

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
	// Flat along both edges of the box's floor, and no hills inside it.
	float near_edge = box_z0 + box_radius;
	float far_edge = box_z0 + box_size - box_radius;
	roll *= smoothstep(0.0, 20.0, min(abs(p.y - near_edge), abs(p.y - far_edge)));
	float outside = max(near_edge - p.y, p.y - far_edge);
	float a = atan(p.y, p.x);
	float hills = smoothstep(140.0, 520.0, d) * smoothstep(10.0, 60.0, outside);
	hills = hills * hills * (34.0 + 16.0 * sin(a * 3.0 + 0.7) + 8.0 * sin(a * 7.0 + 2.1));
	return roll + hills;
}

// The box at distance s round it: (y, z) of the ground there and (y, z) of its up. Must match
// LandFold.tube() in land_fold.gd.
vec4 tube(float s) {
	float R = box_radius;
	float a = R * 1.5707963;
	float W = box_size - 2.0 * R;
	float y0 = box_y0;
	float y1 = box_y0 + box_size;
	float z0 = box_z0;
	float z1 = box_z0 + box_size;
	if (s < a) { float t = s / R; return vec4(y0 + R - R * cos(t), z0 + R - R * sin(t), cos(t), sin(t)); }
	s -= a;
	if (s < W) return vec4(y0 + R + s, z0, 0.0, 1.0);
	s -= W;
	if (s < a) { float t = s / R; return vec4(y1 - R + R * sin(t), z0 + R - R * cos(t), -sin(t), cos(t)); }
	s -= a;
	if (s < W) return vec4(y1, z0 + R + s, -1.0, 0.0);
	s -= W;
	if (s < a) { float t = s / R; return vec4(y1 - R + R * cos(t), z1 - R + R * sin(t), -cos(t), -sin(t)); }
	s -= a;
	if (s < W) return vec4(y1 - R - s, z1, 0.0, -1.0);
	s -= W;
	float t = clamp(s / R, 0.0, 1.5707963);
	return vec4(y0 + R - R * sin(t), z1 - R + R * cos(t), sin(t), -cos(t));
}

float tube_length() {
	return box_radius * 1.5707963 * 4.0 + (box_size - 2.0 * box_radius) * 3.0;
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
	if (!on_fold && (at.y < keep_z.x || at.y > keep_z.y)) clear = 0.0;
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
	if (on_fold) {
		vec2 us = fold_chunk + (vec2(hash(seed), hash(seed + 7.13)) - 0.5) * chunk;
		bool inside = abs(us.x) < fold_half && us.y > 0.0 && us.y < tube_length();
		if (fold_clear.z > 0.0 && length(us - fold_clear.xy) < fold_clear.z) inside = false;
		if (fold_clear2.z > 0.0 && length(us - fold_clear2.xy) < fold_clear2.z) inside = false;
		if (fold_path.x > 0.0 && abs(us.x) < fold_path.x && us.y > fold_path.y && us.y < fold_path.z) inside = false;
		vec4 g = tube(us.y);
		vec3 up = vec3(0.0, g.z, g.w);
		vec3 along = normalize(cross(vec3(1.0, 0.0, 0.0), up));
		// v is (across, up, along) in the blade's own little frame; stand it on the box.
		vec3 foot = vec3(us.x, g.x, g.y);
		world = foot + vec3(v.x, 0.0, 0.0) + up * v.y - along * v.z;
		if (!inside) world = foot;
	}
	VERTEX = world - origin;
	// Light the blades as one soft surface, a little more from above than from the side.
	vec3 ground_up = vec3(0.0, 1.0, 0.0);
	if (on_fold) {
		vec4 g0 = tube(fold_chunk.y);
		ground_up = vec3(0.0, g0.z, g0.w);
	}
	NORMAL = normalize(mix(vec3(c.y, 0.0, -c.x), ground_up, 0.7));
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
