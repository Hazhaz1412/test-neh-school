shader_type spatial;
// The sky of the roller coaster's dream flight (coaster_dream.gd): a sphere round the eye, seen
// from inside, never fogged. Its colours, stars, nebula, sun and moon are blended per region by
// the script (night sea, sunset clouds, deep space); `veil` washes it into the water's colour
// while the train is under the sea.
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 top : source_color = vec3(0.02, 0.03, 0.09);
uniform vec3 horizon : source_color = vec3(0.12, 0.15, 0.3);
uniform vec3 low : source_color = vec3(0.03, 0.04, 0.08);
uniform float stars = 1.0;
uniform float nebula = 0.0;
uniform vec3 sun_dir = vec3(0.0, 0.2, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.6, 0.4);
uniform float sun = 0.0;
uniform float moon = 1.0;
uniform vec3 moon_dir = vec3(0.3, 0.45, -0.8);
uniform vec3 veil_color : source_color = vec3(0.02, 0.12, 0.18);
uniform float veil = 0.0;

varying vec3 dir;

void vertex() {
	dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
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

vec3 star_layer(vec3 d, float scale, float keep) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h > keep) {
		return vec3(0.0);
	}
	vec3 at = cell + vec3(hash(cell + 3.1), hash(cell + 7.7), hash(cell + 11.3));
	float glow = smoothstep(0.16, 0.0, length(p - at));
	vec3 tint = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.85, 0.7), hash(cell + 5.0));
	return tint * glow * (0.5 + 2.5 * hash(cell + 9.0)) * (0.75 + 0.25 * sin(TIME * 2.0 + h * 50.0));
}

void fragment() {
	vec3 d = normalize(dir);
	float up = d.y;
	vec3 colour = mix(horizon, top, smoothstep(0.0, 0.7, up));
	colour = mix(colour, low, smoothstep(0.0, -0.4, up));
	float above = smoothstep(-0.1, 0.1, up);
	colour += (star_layer(d, 70.0, 0.45) * 1.4 + star_layer(d, 170.0, 0.4) + star_layer(d, 380.0, 0.3) * 0.6) * stars * mix(above, 1.0, nebula);
	// Nebula: veils of violet, teal and rose with dark lanes through them.
	float n1 = fbm(d * 3.0 + vec3(2.0, 0.0, 5.0));
	float n2 = fbm(d * 6.0 - vec3(4.0, 1.0, 0.0));
	vec3 cloud = mix(vec3(0.45, 0.15, 0.6), vec3(0.1, 0.5, 0.6), n2) + vec3(0.6, 0.2, 0.35) * smoothstep(0.55, 0.8, n1);
	colour += cloud * smoothstep(0.35, 0.75, n1) * (1.0 - smoothstep(0.5, 0.8, n2) * 0.6) * nebula * 0.8;
	// Sun low on the horizon, with a wide glow.
	float s = max(dot(d, normalize(sun_dir)), 0.0);
	colour += sun_color * (smoothstep(0.9985, 0.999, s) * 2.2 + pow(s, 24.0) * 0.35 + pow(s, 4.0) * 0.12) * sun;
	// Moon.
	float m = dot(d, normalize(moon_dir));
	colour += vec3(1.0, 0.96, 0.88) * smoothstep(0.9965, 0.997, m) * 2.0 * moon;
	colour += vec3(0.5, 0.55, 0.75) * pow(max(m, 0.0), 120.0) * 0.6 * moon;
	ALBEDO = mix(colour, veil_color, veil);
}
