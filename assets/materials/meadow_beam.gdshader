shader_type spatial;
// One shaft of light down through the hole in the cloud: a long quad that turns about its own
// length to face the eye, so it has no edges or corners to give it away. Across it the light
// falls off like a bell; along it, it fades out at the top and melts into the ground at the
// bottom (the depth buffer softens wherever it meets something), with slow drifting dust and a
// faint prism of colour at its sides.
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 colour : source_color = vec3(0.85, 0.93, 1.0);
uniform float strength = 0.12;
uniform float prism = 0.5;
uniform float phase = 0.0;
// How hard the bell is: higher is a narrower ray inside the same quad.
uniform float sharpness = 9.0;

varying float view_depth;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float height = length(axis);
	axis /= height;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = CAMERA_POSITION_WORLD - centre;
	vec3 side = cross(axis, to_eye);
	side = length(side) < 0.0001 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	vec3 world = centre + side * VERTEX.x * width + axis * VERTEX.y * height;
	vec4 view = VIEW_MATRIX * vec4(world, 1.0);
	view_depth = -view.z;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	float across = (UV.x - 0.5) * 2.0;
	float bell = exp(-across * across * sharpness);
	// UV.y is 0 at the top of the quad, 1 at the ground.
	float along = UV.y;
	float fade = smoothstep(0.0, 0.55, along) * (1.0 - smoothstep(0.93, 1.0, along));
	// Dust drifting down the ray, very faint.
	float dust = 0.85 + 0.15 * sin(along * 90.0 - TIME * 0.6 + phase * 7.0) * sin(across * 5.0 + phase * 3.0);
	// Soft where it meets the grass, the tree or the bed.
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	vec4 scene_view = INV_PROJECTION_MATRIX * ndc;
	float scene_depth = -scene_view.z / scene_view.w;
	float soft = smoothstep(0.0, 3.0, scene_depth - view_depth);
	// From far off the rays stack behind each other; thin them with distance.
	float far_off = mix(1.0, 0.45, smoothstep(25.0, 90.0, view_depth));
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (across * 0.6 + phase + vec3(0.0, 0.33, 0.67)));
	vec3 tint = mix(colour, rainbow, prism * smoothstep(0.25, 0.85, abs(across)));
	ALBEDO = tint * bell * fade * dust * soft * far_off * strength;
}
