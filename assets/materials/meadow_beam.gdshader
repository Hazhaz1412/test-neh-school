shader_type spatial;
// A shaft of light down through the hole in the cloud: an open cylinder drawn additively, bright
// at its core, fading at the edges and towards the top, with a faint prism of colour drifting
// through it like the rainbow in a crack of cloud.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(0.85, 0.93, 1.0);
uniform float strength = 0.12;
uniform float prism = 0.6;
uniform float phase = 0.0;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float edge = abs(dot(NORMAL, VIEW));
	float core = pow(edge, 1.6);
	float height = clamp(local_pos.y / 150.0 + 0.5, 0.0, 1.0);
	float fade = smoothstep(0.0, 0.06, height) * (1.0 - smoothstep(0.55, 1.0, height));
	float band = UV.x * 3.0 + local_pos.y * 0.004 + TIME * 0.01 + phase;
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (band + vec3(0.0, 0.33, 0.67)));
	vec3 tint = mix(colour, rainbow, prism * smoothstep(0.2, 0.8, edge) * 0.6);
	// Separate rays inside the shaft, drifting very slowly round it.
	float streak = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(UV.x * 6.2831 * 9.0 + TIME * 0.04 + phase * 10.0), 3.0)
		* (0.6 + 0.4 * sin(UV.x * 6.2831 * 4.0 - TIME * 0.03 - phase * 5.0));
	// From far off every shaft lines up behind the others; thin them out with distance so the
	// light stays a fan of rays instead of one solid column.
	float far_off = mix(1.0, 0.35, smoothstep(25.0, 90.0, length(VERTEX)));
	ALBEDO = tint * core * fade * strength * streak * far_off;
}
