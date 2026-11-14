shader_type spatial;
// One soft puff of cloud, always facing the eye. Drawn many times from a MultiMesh
// (lucid_sky.gd); INSTANCE_CUSTOM.x shifts the noise so no two puffs look alike.
// Lit by hand from the dusk: warm on top, lilac in the shade underneath.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 lit : source_color = vec3(0.93, 0.8, 0.76);
uniform vec3 shade : source_color = vec3(0.5, 0.45, 0.6);
uniform float opacity = 0.62;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 facing = mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float n = texture(noise, UV * 0.6 + vec2(seed, seed * 1.7) + vec2(TIME * 0.003, 0.0)).r;
	float edge = length(c * vec2(1.0, 1.25)) + (n - 0.5) * 0.7;
	// The noise frays the outline; the plain circle under it keeps the quad's edge out of sight.
	float a = smoothstep(1.0, 0.2, edge) * smoothstep(1.0, 0.75, length(c));
	// Fade puffs that sit right on the eye, so walking through a cloud is a haze, not a wall.
	float near = smoothstep(0.6, 3.5, -VERTEX.z);
	ALBEDO = mix(shade, lit, clamp(1.0 - UV.y * 0.9 + (n - 0.5) * 0.4, 0.0, 1.0));
	ALPHA = a * opacity * near;
}
