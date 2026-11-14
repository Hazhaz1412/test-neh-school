shader_type spatial;
// One of the giant books in the stairs up to the table (house_inside.gd): a unit box per book,
// sized by its MultiMesh transform. Cloth cover on top, bottom and spine (-X); cream page edges
// on the other three sides, a cover's thickness in from top and bottom. INSTANCE_CUSTOM.rgb is
// the cover's colour.
render_mode cull_back;

varying vec3 local;
varying vec3 normal_local;
varying vec3 cover;
varying float size_y;

void vertex() {
	local = VERTEX;
	normal_local = NORMAL;
	cover = INSTANCE_CUSTOM.rgb;
	size_y = length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	bool side = abs(normal_local.y) < 0.5 && normal_local.x > -0.5;
	float edge = 0.5 - abs(local.y);
	// The cover's board is about 4% of the giant book's thickness... a hand's width here.
	bool pages = side && edge > 0.09;
	vec3 paper = vec3(0.86, 0.8, 0.66) * (0.92 + 0.08 * sin(local.y * size_y * 140.0));
	vec3 cloth = cover * (0.9 + 0.1 * sin(local.x * 40.0 + local.z * 30.0));
	ALBEDO = pages ? paper : cloth;
	ROUGHNESS = pages ? 0.95 : 0.7;
	SPECULAR = 0.3;
}
