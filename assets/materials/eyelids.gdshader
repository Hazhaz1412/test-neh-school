shader_type canvas_item;
// Eyelids over the screen: `open` 1 is wide open, 0 shut. The opening is an almond, soft-edged,
// so a blink reads as eyes and not as a fade.
uniform float open : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float across = clamp(abs(c.x) * 2.0, 0.0, 1.0);
	float half_height = open * 0.62 * (1.0 - 0.45 * across * across);
	float edge = abs(c.y) - half_height;
	float shut = smoothstep(-0.06, 0.04, edge);
	if (open <= 0.001) shut = 1.0;
	COLOR = vec4(0.0, 0.0, 0.01, shut);
}
