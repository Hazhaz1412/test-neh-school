shader_type canvas_item;
// Rushing streaks at the edges of the view while riding the roller coaster fast: thin bright
// lines flying outwards from the middle, more and brighter with `amount`; a tint for the region.
uniform float amount = 0.0;
uniform vec3 tint : source_color = vec3(0.85, 0.9, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	c.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(c);
	float a = atan(c.y, c.x);
	float lane = floor(a * 90.0 / 6.2831853);
	float seed = hash(lane);
	float speed = 1.2 + seed * 2.0;
	float head = fract(TIME * speed + seed * 7.0);
	float pos = 0.25 + head * 0.6;
	float streak = smoothstep(0.12, 0.0, abs(r - pos)) * step(0.55, seed);
	float thin = smoothstep(0.5, 0.0, abs(fract(a * 90.0 / 6.2831853) - 0.5) * 2.0 - 0.3);
	float edge = smoothstep(0.18, 0.5, r);
	float alpha = streak * thin * edge * amount;
	COLOR = vec4(tint, alpha * 0.55);
}
