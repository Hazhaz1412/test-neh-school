shader_type spatial;
// The meadow floor under the blades: Poly Haven's leafy_grass photo, pulled towards the green of
// the blades and broken up at two scales so it never shows its tiling, even far out on the hills.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 green : source_color = vec3(0.13, 0.27, 0.06);
uniform vec3 far_green : source_color = vec3(0.24, 0.44, 0.1);
// Night: only the box's floor is kept of the meadow (world z from keep_z.x to keep_z.y).
uniform vec2 keep_z = vec2(-1e9, 1e9);
// The fold's own ground: its UV is (x, s) along the fold; laid out to carry on the meadow's (x, z).
uniform bool fold_uv = false;
uniform float fold_bend_z = -8.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	if (fold_uv) {
		p = vec2(UV.x, fold_bend_z - UV.y);
	} else if (p.y < keep_z.x || p.y > keep_z.y) {
		discard;
	}
	vec3 photo = texture(albedo_tex, p / 3.0).rgb;
	float big = noise(p * 0.02) * 0.6 + noise(p * 0.11) * 0.4;
	vec3 tint = mix(green, far_green, big);
	float dist = length(CAMERA_POSITION_WORLD - world_pos);
	// Under the blades the ground is mostly their own green; the photo only adds grain.
	vec3 near = mix(tint, photo * tint * 2.4, 0.45);
	ALBEDO = mix(near, tint * mix(0.85, 1.15, big), smoothstep(30.0, 140.0, dist));
	NORMAL_MAP = texture(normal_tex, p / 3.0).rgb;
	NORMAL_MAP_DEPTH = 1.0 - smoothstep(20.0, 60.0, dist);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
