extends RefCounted
# The game's lettering: Grenze for reading (the project theme), a rough brush for what should
# frighten, scrawl for what was written on the walls. The phone keeps a plain font on purpose.
const TITLE := preload("res://assets/fonts/ProtestRevolution-Regular.ttf")
const WALL := preload("res://assets/fonts/SedgwickAveDisplay-Regular.ttf")
const BODY := preload("res://assets/fonts/grenze_body.tres")
const LINE_GAP := 16
static var shiver: ShaderMaterial

# Arrows and block glyphs are missing from these faces.
static func prepare() -> void:
	for font: Font in [TITLE, WALL, BODY]:
		font.fallbacks = [ThemeDB.fallback_font]

static func title(label: Control) -> void:
	label.add_theme_font_override("font", TITLE)
	# Stacked Vietnamese marks run into the line above at the font's own spacing.
	label.add_theme_constant_override("line_spacing", LINE_GAP)
	if shiver == null:
		shiver = ShaderMaterial.new()
		shiver.shader = preload("res://assets/materials/haunted_text.gdshader")
	label.material = shiver
