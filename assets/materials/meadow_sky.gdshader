shader_type sky;
// The meadow's sky, two photographed skies blended by `bright`: a dark, heavy sky (the field at
// night, before the player reaches the light) and a clear blue one with fair-weather clouds.
// While it is dark a hole in the cloud glows above the one bright place, rimmed with a faint
// rainbow, which is where the shafts of light come down from.
uniform sampler2D dark_sky : source_color, filter_linear;
uniform sampler2D clear_sky : source_color, filter_linear;
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
	COLOR = mix(dark, clear, bright);
}
