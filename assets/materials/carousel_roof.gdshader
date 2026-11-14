shader_type spatial;
// The carousel's cone of a roof: red and cream stripes running up to the point, with a scalloped
// lighter band round the eaves.
uniform vec3 red : source_color = vec3(0.78, 0.12, 0.16);
uniform vec3 cream : source_color = vec3(0.97, 0.92, 0.82);
uniform float stripes = 16.0;

void fragment() {
	float band = step(0.5, fract(UV.x * stripes));
	vec3 colour = mix(red, cream, band);
	float eave = smoothstep(0.86, 0.9, UV.y) * (0.6 + 0.4 * sin(UV.x * stripes * 6.2831));
	colour = mix(colour, vec3(0.98, 0.85, 0.5), eave * 0.7);
	ALBEDO = colour;
	ROUGHNESS = 0.55;
}
