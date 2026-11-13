shader_type spatial;
// The dream floor: a school tile floor under a few centimetres of perfectly still water.
// One opaque surface does both jobs. It is glossy enough that SSR and the sky mirror the whole
// world in it. The tiles are drawn as if they lay `depth` metres below it: each pixel follows the
// view ray down through the water (a parallax trick), so the floor slides under the surface as the
// head moves and the water reads as having real thickness.
// Footsteps and drops push rings outwards (`ripples`); their slope bends both the mirror and the
// tiles seen through it.
render_mode cull_back;

uniform sampler2D tile_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 2.4;
uniform float depth = 0.12;
uniform vec3 deep_tint : source_color = vec3(0.32, 0.36, 0.46);
uniform float clarity = 0.55;
uniform vec3 mirror_tint : source_color = vec3(0.86, 0.84, 0.92);
uniform float clock = 0.0;
// xy: centre on the floor (world x, z); z: time it began on `clock`; w: strength (0 = unused).
uniform vec4 ripples[12];
// The rift: between rift_far and rift_near (world z) the floor is gone once `clock` passes
// rift_open; the hole runs outwards from x = 0 so the falling slabs can cover it as they go.
uniform float rift_near = -30.0;
uniform float rift_far = -66.0;
uniform float rift_open = 1e9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float rings(vec2 p) {
	float h = 0.0;
	for (int i = 0; i < 12; i++) {
		vec4 r = ripples[i];
		if (r.w <= 0.0) continue;
		float age = clock - r.z;
		if (age < 0.0 || age > 4.0) continue;
		float radius = age * 0.9;
		float d = length(p - r.xy) - radius;
		float band = exp(-d * d * 30.0);
		h += sin(d * 34.0) * band * r.w * exp(-age * 1.1) / (1.0 + radius * 2.0);
	}
	return h;
}

// Almost no wind: a long slow swell, so the mirror is alive but never breaks up.
float height(vec2 p) {
	float swell = sin(p.x * 0.35 + clock * 0.4) * 0.5 + sin(p.y * 0.27 - clock * 0.33 + p.x * 0.1) * 0.5;
	return swell * 0.004 + rings(p) * 0.02;
}

float jag(float x, float seed) {
	return 0.35 + 0.25 * sin(x * 0.9 + seed) + 0.15 * sin(x * 2.3 + seed * 3.1);
}

void fragment() {
	vec2 p = world_pos.xz;
	if (world_pos.y > -0.05 && clock > rift_open + abs(p.x) * 0.025 + 0.15
			&& p.y < rift_near + jag(p.x, 1.0) && p.y > rift_far - jag(p.x, 4.0)) {
		discard;
	}
	float e = 0.03;
	float hx = height(p + vec2(e, 0.0)) - height(p - vec2(e, 0.0));
	float hz = height(p + vec2(0.0, e)) - height(p - vec2(0.0, e));
	vec3 n = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	vec3 to_eye = CAMERA_POSITION_WORLD - world_pos;
	float dist = length(to_eye);
	vec3 ray = -to_eye / dist;
	// Follow the ray down to the tiles, bent a little by the slope of the water.
	vec3 bent = normalize(ray + vec3(n.x, 0.0, n.z) * 0.6);
	float down = max(-bent.y, 0.08);
	vec2 floor_at = p + bent.xz / down * depth;
	vec3 tiles = texture(tile_albedo, floor_at / tile_size).rgb;

	// Grazing angles see sky, not floor; far away the tiles would only shimmer, so let them go.
	float facing = clamp(-ray.y, 0.0, 1.0);
	float see_floor = clarity * smoothstep(0.05, 0.6, facing) * (1.0 - smoothstep(12.0, 70.0, dist));
	vec3 under = mix(deep_tint, tiles * deep_tint * 2.2, see_floor);
	// A still sheet of water at dusk is nearly a mirror; only right underfoot does the floor win.
	float mirror = mix(0.92, 0.35, see_floor / max(clarity, 0.001));
	ALBEDO = mix(mirror_tint, under, 1.0 - mirror);
	METALLIC = mirror;
	ROUGHNESS = 0.03;
	SPECULAR = 0.6;
}
