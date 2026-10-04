shader_type spatial;
uniform vec4 porcelain : source_color = vec4(0.68, 0.71, 0.64, 1.0);
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	float mottling = sin(local_pos.x * 4.0 + sin(local_pos.y * 6.0)) * sin(local_pos.z * 7.0 + local_pos.y * 3.0);
	float seam = 1.0 - smoothstep(0.015, 0.09, abs(local_pos.x + sin(local_pos.y * 1.7) * 0.12));
	float stain = (1.0 - smoothstep(0.0, 1.9, local_pos.y)) * 0.45;
	ALBEDO = mix(porcelain.rgb * (0.80 + mottling * 0.12), vec3(0.12,0.025,0.02), stain + seam * 0.38);
	ROUGHNESS = 0.95;
	EMISSION = porcelain.rgb * 0.075;
}
