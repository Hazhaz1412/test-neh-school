shader_type spatial;
// The flooded reservoir at the end of the tunnels: swells in the vertices, ripples in the
// normals, fresnel between see-through dark water and a mirror at a glance. Seen from below
// it is reservoir_underside.gdshader instead.
render_mode blend_mix, cull_back, depth_draw_always;

uniform vec4 deep_color : source_color = vec4(0.01, 0.035, 0.04, 0.985);
uniform vec4 sheen_color : source_color = vec4(0.14, 0.19, 0.21, 1.0);
uniform float swell = 0.07;

varying vec3 world_pos;

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(p.x * 0.55 + TIME * 1.3) * swell + cos(p.z * 0.47 + TIME * 1.05) * swell * 0.8;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME;
	vec3 n = normalize(vec3(
		sin(p.x * 1.9 + t * 1.6) * 0.12 + sin((p.x + p.y) * 3.7 - t * 2.1) * 0.06,
		1.0,
		cos(p.y * 2.1 + t * 1.3) * 0.12 + cos((p.x - p.y) * 3.3 + t * 1.7) * 0.06));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color.rgb, sheen_color.rgb, fresnel);
	ALPHA = deep_color.a;
	ROUGHNESS = 0.04;
	METALLIC = 0.1;
	SPECULAR = 0.9;
}
