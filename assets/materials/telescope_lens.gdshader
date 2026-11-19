shader_type canvas_item;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 lens_center = vec2(450.0, 360.0);
uniform float lens_radius = 296.0;
uniform float locked = 0.0;
uniform float lock_pulse = 0.0;

void fragment() {
	vec2 px = UV * viewport_size;
	vec2 d = px - lens_center;
	float r = length(d);
	float angle = atan(d.y, d.x);

	float inner = lens_radius - 6.0;
	float outer = lens_radius + 18.0;

	if (r < inner) {
		// Subtle optical convex lens edge vignette inside the green telescope aperture (FOV = 30 deg).
		float rim = smoothstep(inner - 58.0, inner, r);
		vec3 glass_tint = mix(vec3(0.06, 0.28, 0.16), vec3(0.16, 0.72, 0.42), locked);
		COLOR = vec4(glass_tint, rim * 0.30);
	} else if (r <= outer) {
		// Green optical eyepiece ring ("Khung tròn xanh lá") with azimuth/elevation degree graduations.
		float t = (r - inner) / max(outer - inner, 0.001);
		float ridge = sin(t * 3.14159265);
		float tick72 = smoothstep(0.92, 0.99, abs(cos(angle * 36.0)));
		float tick12 = smoothstep(0.97, 0.998, abs(cos(angle * 6.0)));
		vec3 green_base = mix(vec3(0.06, 0.24, 0.14), vec3(0.22, 0.78, 0.44), ridge);
		vec3 lock_glow = vec3(0.38, 0.98, 0.62) * (0.55 + 0.35 * sin(lock_pulse * 4.5));
		vec3 bezel_col = mix(green_base, lock_glow, locked * 0.65);
		bezel_col += vec3(0.18, 0.42, 0.24) * tick72 * (1.0 - abs(t - 0.5) * 1.6);
		bezel_col += vec3(0.35, 0.85, 0.52) * tick12;
		COLOR = vec4(bezel_col, 0.98);
	} else {
		// Darkened housing around the circular telescope aperture ("bo góc theo kính thiên văn").
		float shadow_ring = smoothstep(outer, outer + 28.0, r);
		vec3 housing = mix(vec3(0.03, 0.045, 0.038), vec3(0.01, 0.015, 0.02), shadow_ring);
		COLOR = vec4(housing, 0.95);
	}
}
