shader_type spatial;
// The figures at the fair (fair_crowd.gd): people made of shadow. Near black, with a faint violet
// edge where they turn away from the eye that flickers slowly, like smoke holding a shape.
render_mode unshaded, cull_back;

uniform vec3 core : source_color = vec3(0.006, 0.005, 0.01);
uniform vec3 edge : source_color = vec3(0.22, 0.16, 0.38);
uniform float seed = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float flicker = 0.75 + 0.25 * sin(TIME * 1.7 + seed * 6.0 + FRAGCOORD.y * 0.02);
	ALBEDO = core + edge * rim * flicker;
}
