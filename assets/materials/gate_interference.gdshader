shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float noise = fract(sin(dot(UV * vec2(700.0, 450.0) + TIME * 91.0, vec2(12.9898, 78.233))) * 43758.5453);
	float bands = step(0.8, sin(UV.y * 190.0 + TIME * 35.0));
	COLOR = vec4(vec3(noise * 0.65 + bands * 0.12), strength * (0.36 + bands * 0.3));
}
