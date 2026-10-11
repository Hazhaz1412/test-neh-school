shader_type canvas_item;
uniform float pressure : hint_range(0.0,1.0) = 0.0;
uniform float clock = 0.0;
void fragment() {
	vec2 at = UV-vec2(0.5);
	float edge = smoothstep(0.18,0.67,length(at));
	float tendrils = sin(UV.x*37.0+sin(UV.y*19.0+clock)*2.0+clock*0.8)*0.5+0.5;
	float pulse = 0.78+0.22*sin(clock*7.0);
	float darkness = edge*pressure*(0.43+tendrils*0.3)*pulse;
	COLOR = vec4(mix(vec3(0.005,0.001,0.009),vec3(0.27,0.008,0.008),pressure*0.55),darkness);
}
