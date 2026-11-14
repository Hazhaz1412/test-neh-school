shader_type spatial;
// A big old patterned rug under the coffee table: borders in bands, a field of small lozenges and
// a medallion in the middle, worn paler towards the centre. Drawn from its UV, so it is the same
// rug at any size.
uniform vec3 field : source_color = vec3(0.42, 0.09, 0.08);
uniform vec3 border : source_color = vec3(0.1, 0.12, 0.26);
uniform vec3 cream : source_color = vec3(0.85, 0.74, 0.55);
uniform vec2 aspect = vec2(1.4, 1.0);
uniform sampler2D wear : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 c = (UV - 0.5) * aspect;
	vec2 e = 0.5 * aspect - abs(c);
	float edge = min(e.x, e.y);
	vec3 colour = field;
	vec2 l = fract(c * 9.0) - 0.5;
	colour = mix(colour, cream * 0.8, smoothstep(0.32, 0.28, abs(l.x) + abs(l.y)) * 0.35);
	float m = length(c * vec2(1.0, 1.3));
	colour = mix(colour, border, smoothstep(0.22, 0.2, m));
	colour = mix(colour, cream, smoothstep(0.012, 0.0, abs(m - 0.2)) + smoothstep(0.08, 0.06, m) * 0.6);
	colour = mix(colour, border, step(edge, 0.09));
	colour = mix(colour, cream, smoothstep(0.008, 0.0, abs(edge - 0.07)) + smoothstep(0.008, 0.0, abs(edge - 0.1)));
	colour = mix(colour, cream * 0.9, step(edge, 0.02));
	float w = texture(wear, UV * 3.0).r;
	colour = mix(colour, colour * 1.25 + 0.04, smoothstep(0.45, 0.0, m) * w * 0.5);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
