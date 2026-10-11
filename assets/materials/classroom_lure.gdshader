shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float brightness = 1.0;

void fragment() {
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(0.0, 0.18, 1.0 - UV.x);
	vec3 glow = mix(vec3(0.60, 0.25, 0.045), vec3(1.0, 0.79, 0.36), edge);
	ALBEDO = glow * brightness;
}
