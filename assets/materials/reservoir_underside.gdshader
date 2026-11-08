shader_type spatial;
// The reservoir's surface seen from under the water: a dim, wobbling ceiling with a faint net
// of light, unlit so the cavern lamps above cannot turn it into daylight.
render_mode unshaded, blend_mix, cull_front, depth_draw_always;

uniform vec4 murk : source_color = vec4(0.012, 0.05, 0.058, 0.94);
uniform vec4 glint : source_color = vec4(0.12, 0.26, 0.28, 1.0);
uniform float swell = 0.07;
uniform float light = 1.0;

varying vec3 world_pos;

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(p.x * 0.55 + TIME * 1.3) * swell + cos(p.z * 0.47 + TIME * 1.05) * swell * 0.8;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME;
	float net = abs(sin(p.x * 1.3 + sin(p.y * 0.9 + t) * 1.4 + t * 0.7)) * abs(sin(p.y * 1.1 + sin(p.x * 0.8 - t * 0.8) * 1.4 - t * 0.6));
	net = smoothstep(0.55, 1.0, net);
	ALBEDO = mix(murk.rgb, glint.rgb, net * light);
	ALPHA = murk.a;
}
