shader_type sky;

uniform float spirit_amount = 0.0;
uniform float dawn_amount = 0.0;
uniform vec3 moon_direction = vec3(0.58, 0.40, -0.71);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 color = mix(vec3(0.055, 0.086, 0.14), vec3(0.009, 0.017, 0.045), smoothstep(0.0, 0.7, d.y));
	vec3 moon = normalize(moon_direction);
	float separation = length(d - moon);
	float disc = 1.0 - smoothstep(0.021, 0.023, separation);
	float halo = exp(-separation * 18.0) * 0.11;
	float craters = noise(d.xz * 440.0) * 0.18 + noise(d.xy * 190.0) * 0.10;
	color += vec3(0.43, 0.56, 0.8) * halo;
	color = mix(color, vec3(0.94, 0.91, 0.80) * (0.95 - craters), disc);
	vec2 uv = SKY_COORDS * vec2(900.0, 450.0);
	vec2 cell = floor(uv);
	float star = smoothstep(0.997, 1.0, hash(cell)) * pow(max(0.0, 1.0 - length(fract(uv) - 0.5) * 2.0), 6.0);
	color += vec3(0.5, 0.65, 0.88) * star * smoothstep(0.05, 0.45, d.y) * (1.0 - disc);
	vec2 cloud_uv = d.xz / max(0.15, d.y + 0.3) * 2.8;
	float clouds = noise(cloud_uv) * 0.65 + noise(cloud_uv * 2.0) * 0.25;
	color = mix(color, vec3(0.05, 0.07, 0.11), smoothstep(0.6, 0.82, clouds) * 0.40 * (1.0 - disc));
	vec3 cursed = color * vec3(1.1, 0.45, 0.68) + vec3(0.027, 0.004, 0.018);
	cursed = mix(cursed, vec3(0.69, 0.15, 0.12), disc * 0.85);
	vec3 realm_color = mix(color, cursed, spirit_amount);
	vec3 dawn = mix(vec3(0.38, 0.27, 0.26), vec3(0.16, 0.26, 0.38), smoothstep(0.0, 0.7, d.y));
	COLOR = mix(realm_color, dawn, dawn_amount);
}
