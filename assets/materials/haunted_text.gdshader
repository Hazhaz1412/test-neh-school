shader_type canvas_item;
// Letters twitch a few times a second and the whole line gutters like a failing lamp.
uniform float twitch = 1.1;
uniform float rate = 11.0;

float noise(float seed) {
	return fract(sin(seed * 91.17) * 43758.5453);
}

void vertex() {
	float beat = floor(TIME * rate);
	float glyph = floor(VERTEX.x / 18.0);
	VERTEX.x += (noise(glyph + beat) - 0.5) * twitch;
	VERTEX.y += (noise(glyph * 1.7 + beat) - 0.5) * twitch * 1.6;
}

void fragment() {
	float beat = floor(TIME * rate * 0.7);
	COLOR.a *= 0.86 + noise(beat) * 0.14;
}
