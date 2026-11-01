shader_type spatial;
render_mode cull_disabled;
uniform vec3 shallow = vec3(0.20, 0.19, 0.12);
uniform vec3 deep = vec3(0.13, 0.15, 0.10);
varying vec3 ground;

float ripple(vec2 p, float t) {
	return sin(p.x * 1.3 + t * 0.9 + sin(p.y * 0.7 + t * 0.4) * 1.5) * 0.5 + sin(p.y * 2.1 - t * 1.2 + p.x * 0.6) * 0.3 + sin((p.x + p.y) * 4.3 + t * 1.7) * 0.2;
}

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = ground.xz * 0.7;
	float t = TIME;
	float e = 0.08;
	vec3 tilt = normalize(vec3(ripple(p + vec2(e, 0.0), t) - ripple(p - vec2(e, 0.0), t), 4.0, ripple(p + vec2(0.0, e), t) - ripple(p - vec2(0.0, e), t)));
	NORMAL = normalize((VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ALBEDO = mix(shallow, deep, smoothstep(-0.6, 0.6, sin(ground.x * 0.08 + ground.z * 0.02)));
	ROUGHNESS = 0.3;
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
