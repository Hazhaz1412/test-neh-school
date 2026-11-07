shader_type spatial;
// Mirror glass with a spider-web fracture. Radial cracks and broken rings around an impact
// point; the innermost shards are missing, showing the dark backing board.
render_mode cull_back;

uniform vec2 impact = vec2(0.5, 0.5);
uniform float broken = 1.0;
uniform float hole = 0.12;
uniform float aspect = 1.0;
uniform vec4 backing : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform vec4 glass : source_color = vec4(0.62, 0.66, 0.68, 1.0);

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 d = (UV - impact) * vec2(aspect, 1.0);
	float r = length(d);
	float ang = atan(d.y, d.x);
	float spokes = 13.0;
	float cell = floor((ang / TAU + 0.5) * spokes);
	float jitter = (hash(cell * 7.1) - 0.5) * 0.9;
	float local = fract((ang / TAU + 0.5) * spokes + jitter * 0.15 * sin(r * 22.0));
	float radial = smoothstep(0.035, 0.0, min(local, 1.0 - local) * (0.4 + r * 3.0));
	float ring_index = floor(r * 9.0 + hash(cell) * 0.8);
	float ring_pos = fract(r * 9.0 + hash(cell) * 0.8);
	float rings = smoothstep(0.06, 0.0, min(ring_pos, 1.0 - ring_pos)) * step(r, 0.62);
	float crack = clamp(radial * step(r, 0.95) + rings, 0.0, 1.0) * broken;
	crack *= smoothstep(0.98, 0.5, r);
	// Each shard tilts a little, so it reflects a slightly different part of the room.
	float tilt = hash(cell * 3.3 + ring_index * 11.7) - 0.5;
	float missing = step(r, hole * (0.75 + hash(cell * 1.7) * 0.6)) * broken;
	vec3 colour = mix(glass.rgb * (0.85 + tilt * 0.35 * broken), vec3(0.9), crack * 0.55);
	ALBEDO = mix(colour, backing.rgb, missing);
	METALLIC = mix(0.95, 0.0, missing);
	ROUGHNESS = mix(0.04 + crack * 0.35, 0.9, missing);
	SPECULAR = 0.9;
	NORMAL_MAP = normalize(vec3(0.5 + tilt * 0.3 * broken, 0.5 - tilt * 0.2 * broken, 1.0));
}
