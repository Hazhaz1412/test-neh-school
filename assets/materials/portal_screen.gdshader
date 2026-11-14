shader_type spatial;
// The far side of a doorway (portal.gd): what the portal's own camera sees, laid over the screen
// exactly where it would be seen. The mesh is a box behind the doorway drawn inside out, so it
// still fills the view while the eye is passing through. The picture arrives as linear light,
// not yet tone-mapped, so the eye's own environment grades it once like everything else.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform sampler2D view : filter_linear, repeat_disable;
// Fades the doorway in as the door swings open (black until then: the dark inside a house).
uniform float open = 1.0;

void fragment() {
	ALBEDO = texture(view, SCREEN_UV).rgb * open;
}
