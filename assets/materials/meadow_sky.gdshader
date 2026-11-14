shader_type sky;
// The meadow's sky, two photographed skies blended by `bright`: a dark, heavy sky (the field at
// night, before the player reaches the light) and a clear blue one with fair-weather clouds.
// While it is dark a hole in the cloud glows above the one bright place, rimmed with a faint
// rainbow, which is where the shafts of light come down from.
uniform sampler2D dark_sky : source_color, filter_linear;
uniform sampler2D clear_sky : source_color, filter_linear;
uniform sampler2D night_sky : source_color, filter_linear;
// After the bed: the same meadow under a night full of stars.
uniform float night : hint_range(0.0, 1.0) = 0.0;
// The photographed night is exposed like a day (mean about 0.7); bring it down to a night.
uniform float night_energy = 0.03;
uniform vec3 night_tint : source_color = vec3(0.55, 0.68, 1.0);
uniform float bright : hint_range(0.0, 1.0) = 0.0;
uniform float dark_energy = 0.22;
uniform vec3 dark_tint : source_color = vec3(0.55, 0.68, 1.0);
uniform float clear_energy = 0.8;
uniform float clear_turn = 0.0;
uniform vec3 hole_dir = vec3(0.0, 0.85, -0.53);

vec2 panorama(vec3 dir, float turn) {
	float a = atan(dir.x, -dir.z) + turn;
	return vec2(a / TAU + 0.5, acos(clamp(dir.y, -1.0, 1.0)) / PI);
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Sharp little stars on a grid wrapped round the sky, a few bright ones, all twinkling slowly.
vec3 stars(vec3 dir) {
	vec3 total = vec3(0.0);
	for (int layer = 0; layer < 2; layer++) {
		float scale = layer == 0 ? 180.0 : 420.0;
		vec3 p = dir * scale;
		vec3 cell = floor(p);
		float h = hash3(cell + float(layer) * 31.7);
		float keep = layer == 0 ? 0.992 : 0.975;
		if (h > keep) {
			vec3 spot = cell + 0.5 + (vec3(hash3(cell + 3.1), hash3(cell + 7.3), hash3(cell + 11.9)) - 0.5) * 0.6;
			float d = length(p - spot);
			float size = layer == 0 ? 0.22 : 0.14;
			float twinkle = 0.65 + 0.35 * sin(TIME * (1.0 + h * 3.0) + h * 80.0);
			float b = smoothstep(size, 0.0, d) * twinkle * (layer == 0 ? 6.0 : 2.0);
			vec3 tint = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.88, 0.72), fract(h * 37.0));
			total += tint * b;
		}
	}
	return total;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 dark = min(texture(dark_sky, panorama(dir, 0.0)).rgb, vec3(6.0)) * dark_energy * dark_tint;
	// Below the horizon the photos show ground; the meadow covers it, but keep it calm anyway.
	dark = mix(dark, vec3(0.02, 0.03, 0.05), smoothstep(0.0, -0.2, dir.y));
	float d = dot(dir, normalize(hole_dir));
	float glow = smoothstep(0.93, 0.995, d);
	float rim = smoothstep(0.9, 0.95, d) * (1.0 - smoothstep(0.95, 0.985, d));
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (d * 30.0 + vec3(0.0, 0.33, 0.67)));
	dark += vec3(0.75, 0.88, 1.0) * glow * 1.6 + rainbow * rim * 0.18;
	// The photographed sun is tens of thousands of times brighter than the sky round it; left in,
	// it floods the reflections and the ambient light. The DirectionalLight is the sun instead.
	vec3 clear = min(texture(clear_sky, panorama(dir, clear_turn)).rgb, vec3(6.0)) * clear_energy;
	clear = mix(clear, vec3(0.3, 0.42, 0.25), smoothstep(0.0, -0.2, dir.y));
	vec3 day = mix(dark, clear, bright);
	vec3 sky_night = min(texture(night_sky, panorama(dir, 0.0)).rgb, vec3(6.0)) * night_energy * night_tint;
	sky_night = mix(sky_night, vec3(0.01, 0.015, 0.03), smoothstep(0.0, -0.2, dir.y));
	sky_night += stars(dir) * smoothstep(-0.02, 0.15, dir.y);
	COLOR = mix(day, sky_night, night);
}
