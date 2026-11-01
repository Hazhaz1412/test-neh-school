shader_type canvas_item;
// Rotating gate behind the calibration markers. All motion stays inside the centre circle,
// so the corner markers keep a still, high-contrast background for the phone.
uniform float progress = 0.0;
uniform float finish = 0.0;
uniform float aspect = 1.78;
uniform vec3 ink = vec3(0.45, 0.95, 0.82);
uniform vec3 blood = vec3(0.95, 0.12, 0.16);

float hash(float n) { return fract(sin(n * 91.3) * 47453.5); }

float band(float radius, float at, float width) {
	return smoothstep(width, width * 0.35, abs(radius - at));
}

// A ring cut into glyph-like dashes that turn at their own speed.
float glyphs(float angle, float radius, float at, float width, float count, float speed, float seed) {
	float turned = fract((angle + TIME * speed) / TAU) * count;
	float cell = floor(turned);
	float inside = fract(turned);
	float lit = step(0.32, hash(cell + seed));
	float notch = step(0.14, inside) * step(inside, 0.14 + 0.72 * hash(cell * 1.7 + seed));
	float height = 0.45 + 0.55 * hash(cell * 2.3 + seed);
	return band(radius, at, width * height) * lit * notch;
}

float ticks(float angle, float radius, float at, float width, float count, float speed) {
	float turned = fract((angle + TIME * speed) / TAU) * count;
	return band(radius, at, width) * step(fract(turned), 0.28);
}

float spokes(float angle, float radius, float inner, float outer, float count, float speed) {
	float a = sin((angle + TIME * speed) * count);
	return smoothstep(0.985, 1.0, a) * smoothstep(inner, inner + 0.01, radius) * smoothstep(outer, outer - 0.04, radius);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float grow = 1.0 + finish * finish * 3.2;
	p /= grow;
	float jolt = finish * step(0.72, hash(floor(TIME * 34.0) + floor(p.y * 26.0))) * 0.07;
	p.x += jolt;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float pulse = 0.5 + 0.5 * sin(TIME * 2.6);

	float rings = 0.0;
	rings += glyphs(angle, radius, 0.35, 0.020, 34.0, 0.55, 3.0);
	rings += glyphs(angle, radius, 0.285, 0.015, 22.0, -0.95, 8.0);
	rings += ticks(angle, radius, 0.385, 0.009, 90.0, -0.22);
	rings += ticks(angle, radius, 0.235, 0.012, 16.0, 1.6) * 0.8;
	rings += band(radius, 0.405, 0.0022) + band(radius, 0.215, 0.0022);
	rings += spokes(angle, radius, 0.215, 0.405, 3.0, 0.8) * 0.8;

	// The gate charges along its rim as the sweep advances.
	float sweep = fract(angle / TAU + 0.25);
	float charged = step(sweep, progress) * band(radius, 0.42, 0.0085);
	float eye = smoothstep(0.205, 0.0, radius);
	float core = eye * (0.11 + 0.05 * pulse + progress * 0.22);
	float scan = smoothstep(0.08, 0.0, abs(fract(TIME * 0.33 + radius * 2.2) - 0.5)) * smoothstep(0.42, 0.2, radius) * 0.14;

	vec3 tone = mix(ink, blood, smoothstep(0.55, 1.0, progress));
	vec3 color = vec3(0.005, 0.01, 0.012);
	color += tone * rings * (0.75 + 0.25 * pulse);
	color += mix(ink, vec3(1.0), 0.45) * charged * 1.4;
	color += tone * (core + scan);
	color += tone * 0.09 * smoothstep(0.62, 0.1, radius);
	color += vec3(1.0, 0.9, 0.85) * finish * finish * smoothstep(1.2, 0.0, radius);
	float reveal = 1.0 - smoothstep(0.55, 1.0, finish);
	COLOR = vec4(color, reveal);
}
