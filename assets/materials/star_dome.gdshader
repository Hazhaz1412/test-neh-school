shader_type spatial;
// The night sky that opens over the top of the Ferris wheel (ferris_wheel.gd): a sphere round the
// wheel's hub, seen from inside. Deep blue going violet at the horizon, three layers of stars,
// the Milky Way with dark dust across it, a pale moon. Only the half above the wall's horizon
// (local +Y) is drawn, so the fair and the meadow below stay in view. `appear` brings it in.
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform float appear = 0.0;
uniform vec3 deep : source_color = vec3(0.01, 0.015, 0.05);
uniform vec3 horizon : source_color = vec3(0.12, 0.08, 0.22);
uniform vec3 moon_dir = vec3(0.3, 0.55, -0.8);

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// One layer of stars: a point somewhere in each cell of a grid laid through the sky, lit in
// only some cells, twinkling slowly.
vec3 stars(vec3 d, float scale, float keep, float size) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h > keep) {
		return vec3(0.0);
	}
	vec3 at = cell + vec3(hash(cell + 3.1), hash(cell + 7.7), hash(cell + 11.3));
	float dist = length(p - at);
	float glow = smoothstep(size, 0.0, dist);
	float twinkle = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	vec3 tint = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.85, 0.7), hash(cell + 5.0));
	return tint * glow * twinkle * (0.6 + 2.4 * hash(cell + 9.0));
}

void fragment() {
	vec3 d = normalize(dir);
	float up = d.y;
	vec3 colour = mix(horizon, deep, smoothstep(0.0, 0.6, up));
	// The Milky Way: a band across the sky, bright in its middle, with clouds of dark dust.
	vec3 band = normalize(vec3(0.35, 0.45, 0.82));
	float across = dot(d, band);
	float milky = exp(-across * across / 0.03);
	float clouds = fbm(d * 5.0 + 3.0);
	float dust = smoothstep(0.45, 0.75, fbm(d * 9.0 + 11.0));
	colour += vec3(0.45, 0.4, 0.62) * milky * clouds * (1.0 - dust * 0.8) * 0.9;
	colour += stars(d, 60.0, 0.5, 0.18) * 1.6;
	colour += stars(d, 140.0, 0.35 + milky * 0.4, 0.14);
	colour += stars(d, 320.0, 0.25 + milky * 0.6, 0.12) * 0.6;
	// A big pale moon: grey seas across its face, a rim of light, and a wide soft halo.
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	float disc = smoothstep(0.9955, 0.9962, m);
	vec3 face = d - md * m;
	float seas = smoothstep(0.35, 0.7, fbm(face * 90.0 + 4.0));
	float craters = smoothstep(0.55, 0.8, noise(face * 420.0));
	vec3 moon = vec3(1.0, 0.96, 0.86) * (1.0 - seas * 0.4 - craters * 0.15) * 1.5;
	colour = mix(colour, moon, disc);
	colour += vec3(0.55, 0.6, 0.8) * pow(max(m, 0.0), 180.0) * 0.9 * (1.0 - disc);
	colour += vec3(0.3, 0.32, 0.45) * pow(max(m, 0.0), 18.0) * 0.25 * (1.0 - disc);
	ALBEDO = colour;
	ALPHA = smoothstep(-0.03, 0.28, up) * appear;
}
