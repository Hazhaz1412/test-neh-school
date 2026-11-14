shader_type spatial;
// The fair's bunting (land_fold.gd): a little triangle per flag, coloured per instance, fluttering
// from its string a little more at the tip.
render_mode cull_disabled, diffuse_lambert_wrap;

void vertex() {
	float tip = clamp(-VERTEX.y / 0.5, 0.0, 1.0);
	float phase = float(INSTANCE_ID) * 1.37;
	VERTEX.z += sin(TIME * 3.0 + phase) * 0.08 * tip;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	BACKLIGHT = COLOR.rgb * 0.4;
}
