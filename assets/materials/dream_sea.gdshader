shader_type spatial;
// The night sea of the roller coaster's dream flight (coaster_dream.gd): a big sheet that follows
// the eye, rolling waves, a deep blue body with the sky's horizon caught at grazing angles, white
// crests and sparks of blue-green glow in the water. Seen from below it is the bright, rippling
// underside of the surface.
render_mode cull_disabled, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.01, 0.04, 0.1);
uniform vec3 shine : source_color = vec3(0.25, 0.32, 0.55);
uniform vec3 glow : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 under : source_color = vec3(0.3, 0.7, 0.75);
uniform float wave = 1.0;

varying vec3 world;
varying float crest;

float waves(vec2 p) {
	float h = 0.0;
	h += sin(dot(p, vec2(0.08, 0.03)) + TIME * 1.1) * 0.9;
	h += sin(dot(p, vec2(-0.05, 0.11)) + TIME * 1.4) * 0.6;
	h += sin(dot(p, vec2(0.17, -0.12)) + TIME * 2.0) * 0.25;
	return h * wave;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = waves(w.xz);
	VERTEX.y += h;
	crest = smoothstep(0.9, 1.5, h);
	float e = 0.5;
	float hx = waves(w.xz + vec2(e, 0.0)) - h;
	float hz = waves(w.xz + vec2(0.0, e)) - h;
	NORMAL = normalize(vec3(-hx / e, 1.0, -hz / e));
	world = w;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	vec2 cell = floor(world.xz * 0.6);
	float spark = step(0.985, hash(cell)) * (0.5 + 0.5 * sin(TIME * 3.0 + hash(cell + 1.0) * 30.0));
	vec3 colour = mix(deep, shine, fresnel) + vec3(0.9) * crest * 0.35;
	vec3 lit = glow * spark * 2.5;
	if (!FRONT_FACING) {
		colour = under * (0.6 + 0.4 * sin(world.x * 0.2 + TIME) * sin(world.z * 0.23 - TIME * 1.3));
		lit = under * 0.6;
	}
	ALBEDO = colour;
	EMISSION = lit;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
