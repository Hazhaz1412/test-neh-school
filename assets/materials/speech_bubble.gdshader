shader_type spatial;
// A speech bubble over a figure at the fair (fair_crowd.gd): a pale rounded box with a little tail
// pointing down, always facing the eye. `size` is the box in metres; the quad is a bit taller
// for the tail. Cut out rather than blended, so it has a depth and the far blur leaves it alone.
render_mode unshaded, depth_draw_opaque, cull_disabled, shadows_disabled;

uniform vec2 size = vec2(2.0, 0.6);
uniform float shown = 1.0;
uniform vec3 paper : source_color = vec3(0.6, 0.58, 0.55);
uniform vec3 line : source_color = vec3(0.12, 0.1, 0.16);

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 facing = mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	// A hand's width behind the words, so they always draw over it.
	VERTEX.z -= 0.04 / max(scale.z, 0.001);
}

float box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	float tail_h = 0.25;
	vec2 full = vec2(size.x, size.y + tail_h);
	vec2 p = (UV - 0.5) * full * vec2(1.0, -1.0);
	vec2 c = p - vec2(0.0, tail_h * 0.5);
	float d = box(c, size * 0.5, 0.18);
	// The tail: a triangle under the box, a little left of the middle.
	vec2 t = p - vec2(-size.x * 0.12, -size.y * 0.5 + tail_h * 0.5 + 0.02);
	float tail = max(abs(t.x) * 1.6 + t.y * 0.9 - 0.12, -t.y - tail_h * 0.6);
	d = min(d, tail);
	float aa = fwidth(d) * 1.2;
	float body = 1.0 - smoothstep(-aa, aa, d);
	float rim = 1.0 - smoothstep(-aa, aa, abs(d + 0.02) - 0.02);
	ALBEDO = mix(paper, line, rim);
	ALPHA = max(body, rim) * shown;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
