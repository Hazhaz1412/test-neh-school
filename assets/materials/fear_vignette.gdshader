shader_type canvas_item;
uniform float red : hint_range(0.0,1.0) = 0.0;
uniform float darkness : hint_range(0.0,1.0) = 0.0;
uniform float fade : hint_range(0.0,1.0) = 0.0;
uniform float pulse : hint_range(0.0,1.0) = 0.0;
void fragment() {
	// Each heartbeat squeezes the clear centre of the screen inward.
	float inner = mix(0.44,0.17,pulse);
	float edge = smoothstep(inner,inner+0.40,length(UV-vec2(0.5)));
	float wash = red*(0.46+0.54*edge);
	float shade = darkness*(0.30+0.70*edge);
	vec3 tint = vec3(0.46,0.012,0.010)*(1.0-clamp(shade,0.0,1.0));
	COLOR = vec4(mix(tint,vec3(0.0),fade),clamp(1.0-(1.0-wash)*(1.0-shade)*(1.0-fade),0.0,1.0));
}
