shader_type spatial;
// Pieces of the broken path, scattered in the air and down in the rift. Nothing on them is drawn
// in their own UVs: every pixel is projected from one eye point (`eye`). The ray from the eye
// through the pixel is followed down to the plane the path used to lie in (y = 0), and the pixel
// shows what was painted there: the floor tiles and a chalk hopscotch path leading across.
// Seen from the eye every piece shows exactly its own part of that picture, so they join into one
// whole path. From anywhere else the picture is sheared apart across the pieces.
// The pieces themselves are each moved along a ray from the same eye (anamorphic_bridge.gd), so
// from there their outlines join too.

uniform sampler2D tile_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 2.4;
uniform vec3 eye = vec3(0.0, 1.6, 0.0);
uniform vec3 origin = vec3(0.0);        // start of the path, middle of its width, on y = 0
uniform vec2 along = vec2(0.0, -1.0);   // direction of the path on the floor (x, z)
uniform float width = 2.4;
uniform float glow = 0.0;               // how well the player's eye matches `eye`, 0..1
uniform float clock = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.6, w, abs(d));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The chalk drawing in path space: u across (metres from the centre line), v along (metres).
float chalk(float u, float v) {
	float w = 0.05;
	float ink = 0.0;
	// Border lines down both sides.
	ink = max(ink, line(abs(u) - width * 0.5 + 0.18, w));
	// Hopscotch: boxes every 1.6 m, singles and doubles in turn.
	float row = floor(v / 1.6);
	bool pair = mod(row, 2.0) > 0.5;
	ink = max(ink, line(mod(v, 1.6) - 0.0, w) * step(abs(u), pair ? 1.0 : 0.5));
	ink = max(ink, line(abs(u) - (pair ? 1.0 : 0.5), w) * step(0.0, v));
	ink = max(ink, line(u, w) * (pair ? 1.0 : 0.0));
	// Arrow heads pointing across, every 6.4 m.
	float a = mod(v, 6.4) - 3.2;
	ink = max(ink, line(abs(u) * 0.8 + a, w) * step(abs(u), 0.6) * step(-0.6, a) * step(a, 0.2));
	// Chalk is never solid: break it up with grain.
	float grain = hash(floor(vec2(u, v) * 90.0));
	return ink * (0.55 + 0.45 * grain);
}

void fragment() {
	// Follow the ray from the eye through this pixel to the old floor.
	vec3 ray = world_pos - eye;
	float t = ray.y < -0.0001 ? -eye.y / ray.y : 1.0;
	vec3 floor_at = eye + ray * t;
	vec2 rel = floor_at.xz - origin.xz;
	vec2 right = vec2(-along.y, along.x);
	float u = dot(rel, right);
	float v = dot(rel, along);
	vec3 tiles = texture(tile_albedo, floor_at.xz / tile_size).rgb;
	float ink = chalk(u, v);
	vec3 base = tiles * vec3(0.78, 0.76, 0.84);
	ALBEDO = mix(base, vec3(0.95, 0.93, 0.88), ink);
	ROUGHNESS = mix(0.7, 0.95, ink);
	// When the eye is nearly right the chalk starts to shine, a hint that this is the place.
	float pulse = 0.75 + 0.25 * sin(clock * 3.0);
	EMISSION = vec3(1.0, 0.82, 0.62) * ink * glow * glow * 1.6 * pulse;
}
