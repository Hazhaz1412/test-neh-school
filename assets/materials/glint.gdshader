shader_type spatial;
// A small camera-facing sparkle: soft core plus a four-point star that twinkles.
// Additive and unshaded, so it reads as light catching glass or metal.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float intensity = 1.0;
uniform float twinkle_speed = 2.3;
uniform float phase = 0.0;
uniform float rays = 1.0;

void vertex() {
	// Billboard while keeping the node's scale.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(scale.x, 0, 0, 0), vec4(0, scale.y, 0, 0), vec4(0, 0, scale.z, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = TIME * twinkle_speed + phase;
	float twinkle = 0.55 + 0.45 * pow(abs(sin(t)), 6.0) + 0.15 * sin(t * 3.7);
	float core = exp(-r * r * 30.0);
	float halo = exp(-r * r * 5.0) * 0.25;
	float a = 0.6 + 0.2 * sin(t * 0.37);
	vec2 q = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p;
	float star = (exp(-abs(q.x) * 60.0) * exp(-abs(q.y) * 2.6) + exp(-abs(q.y) * 60.0) * exp(-abs(q.x) * 2.6)) * rays;
	float glow = (core + halo + star * twinkle) * intensity * twinkle;
	ALBEDO = tint.rgb * glow;
	ALPHA = clamp(glow, 0.0, 1.0);
}
