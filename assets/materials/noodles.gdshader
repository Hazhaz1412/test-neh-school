shader_type spatial;
// Instant noodles: two crossing sets of wavy strands with shadow between them, laid out in
// object space (metres) so the brick and the bowl share one strand size.
// soft: 0 is the dry brick (pale, tight waves), 1 is cooked. glaze: the seasoning oil mixed in.
// swirl turns the pattern while the noodles are stirred.
uniform vec3 noodle : source_color = vec3(0.96, 0.82, 0.48);
uniform vec3 glaze_tint : source_color = vec3(0.93, 0.5, 0.18);
uniform float soft : hint_range(0.0, 1.0) = 1.0;
uniform float glaze : hint_range(0.0, 1.0) = 0.0;
uniform float swirl = 0.0;
uniform float scale = 260.0;
varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float c = cos(swirl);
	float s = sin(swirl);
	vec2 q = vec2(c * local.x - s * local.z, s * local.x + c * local.z) * scale;
	q += vec2(local.y * scale * 0.7);
	float wave = mix(3.0, 1.4, soft);
	float a = sin(q.x + wave * sin(q.y * 0.45) + 0.5 * sin(q.y * 1.6));
	float b = sin(q.y * 0.95 + wave * sin(q.x * 0.5 + 1.3) + 0.4 * sin(q.x * 1.9));
	float strand = max(smoothstep(0.5, 0.92, abs(a)), smoothstep(0.5, 0.92, abs(b)) * 0.85);
	vec3 base = mix(noodle * 0.86, noodle, soft);
	base = mix(base, glaze_tint, glaze * 0.6);
	ALBEDO = mix(base * 0.42, base, strand);
	ROUGHNESS = mix(0.85, mix(0.5, 0.22, glaze), soft);
	SPECULAR = 0.5;
}
