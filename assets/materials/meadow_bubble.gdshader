shader_type spatial;
// Soap bubbles drifting up through the clear sky, all from one MultiMesh of spheres. As with the
// grass, each bubble's path comes from its INSTANCE_ID: where it starts, how fast it rises, how it
// wobbles. A thin film: almost clear in the middle, rainbow and bright at the rim.
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
uniform float appear : hint_range(0.0, 1.0) = 0.0;
uniform float spread = 24.0;
uniform float ceiling = 22.0;
uniform vec3 centre = vec3(0.0);
varying float rim_seed;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void vertex() {
	float id = float(INSTANCE_ID);
	float size = mix(0.12, 0.5, pow(hash(id + 1.0), 2.0));
	float speed = mix(0.25, 0.7, hash(id + 2.0));
	float angle = hash(id + 3.0) * 6.2831;
	float radius = sqrt(hash(id + 4.0)) * spread;
	float rise = mod(TIME * speed + hash(id + 5.0) * ceiling, ceiling);
	vec3 at = centre + vec3(cos(angle) * radius, 0.4 + rise, sin(angle) * radius);
	at.x += sin(TIME * 0.6 + id) * 0.6;
	at.z += cos(TIME * 0.5 + id * 1.7) * 0.6;
	// Born small at the bottom, gone at the top.
	float life = smoothstep(0.0, 1.0, rise) * (1.0 - smoothstep(ceiling - 3.0, ceiling, rise));
	VERTEX = VERTEX * size * life * appear + at - MODEL_MATRIX[3].xyz;
	rim_seed = hash(id + 6.0);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	vec3 film = 0.5 + 0.5 * cos(6.2831 * (facing * 1.6 + rim_seed + vec3(0.0, 0.33, 0.67)));
	ALBEDO = mix(vec3(1.0), film, 0.8);
	EMISSION = film * rim * 0.25;
	ROUGHNESS = 0.02;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	ALPHA = 0.04 + rim * 0.55;
}
