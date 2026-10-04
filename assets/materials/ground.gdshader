shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.35, 0.39, 0.36, 1.0);
uniform float paving = 0.0;
uniform float tile_size = 1.0;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	float grit = hash(floor(world_pos.xz * 95.0));
	float mottling = hash(floor(world_pos.xz * 2.0));
	vec3 color = tint.rgb * (0.90 + 0.14 * grit + 0.07 * mottling);
	vec2 edge = abs(fract(uv) - 0.5);
	float seam = smoothstep(0.475, 0.497, max(edge.x, edge.y));
	color *= mix(1.0, 0.52, seam * paving);
	ALBEDO = color;
	ROUGHNESS = 0.94;
}
