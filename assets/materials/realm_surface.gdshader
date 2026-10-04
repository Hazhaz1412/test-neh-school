shader_type spatial;
uniform vec4 tint : source_color = vec4(0.45, 0.39, 0.30, 1.0);
uniform float category = 1.0;
uniform sampler2D decay_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 a = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(a), hash(a + vec3(1,0,0)), f.x), mix(hash(a + vec3(0,1,0)), hash(a + vec3(1,1,0)), f.x), f.y), mix(mix(hash(a + vec3(0,0,1)), hash(a + vec3(1,0,1)), f.x), mix(hash(a + vec3(0,1,1)), hash(a + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	if (category > 2.5 && category < 3.5) {
		VERTEX.x += sin(TIME * 0.6 + world_pos.y * 2.0 + world_pos.z) * 0.12;
	}
}
void fragment() {
	float grime = noise(world_pos * 2.1) * 0.7 + noise(world_pos * 8.0) * 0.3;
	float vein = 1.0 - smoothstep(0.015, 0.060, abs(sin(world_pos.x * 3.5 + world_pos.z * 2.7 + world_pos.y * 2.0 + noise(world_pos * 0.8) * 9.0)));
	vec3 axis = abs(world_normal);
	vec2 projected = world_pos.xz;
	if (axis.x > axis.y && axis.x > axis.z) projected = world_pos.zy;
	else if (axis.z > axis.y) projected = world_pos.xy;
	vec3 decay = texture(decay_texture, projected / (category < 0.5 ? 2.0 : 3.0)).rgb;
	vec3 original = tint.rgb * 0.85;
	vec3 rot = mix(original, decay * vec3(0.65, 0.48, 0.33), category < 1.5 ? 0.80 : 0.30);
	rot = mix(rot, vec3(0.20, 0.07, 0.035), smoothstep(0.44, 0.78, grime) * 0.35);
	rot *= mix(0.35, 1.0, smoothstep(0.13, 0.34, grime));
	if (category > 2.5 && category < 3.5) rot = mix(vec3(0.035,0.038,0.03), vec3(0.22,0.065,0.045), grime);
	ALBEDO = mix(rot, vec3(0.16, 0.008, 0.012), vein * 0.65);
	ROUGHNESS = category < 0.5 ? 0.35 : 0.86;
	EMISSION = vec3(0.18, 0.006, 0.01) * vein * (0.20 + 0.08 * sin(TIME * 1.6 + world_pos.z));
}
