@tool
extends Marker3D
# One named building. Drag the marker: the building snaps to the side of its road nearest the marker.
const STYLES := "open,home,civic,stall,market,curio"
@export var id := ""
@export var label := ""
# The road the building fronts; pick from the list, or leave empty for the nearest road.
@export var road := ""
@export var width := 6.0
@export var depth := 10.0
@export_range(1, 8) var floors := 2
@export_enum("open", "home", "civic", "stall", "market", "curio") var style := "open"
@export var use_tint := true
@export var tint := Color(0.8, 0.8, 0.7)
@export var use_sign := false
@export var sign_color := Color(0.73, 0.14, 0.12)
@export var hide_on_map := false

func _validate_property(property: Dictionary) -> void:
	if property.name == "road" and get_node_or_null("../../Roads"):
		var names := PackedStringArray()
		for child in get_node("../../Roads").get_children():
			names.append(child.name)
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(names)

func definition() -> Dictionary:
	var result := {"id": id if id != "" else String(name), "label": label, "road": road, "on": Vector2(position.x, position.z), "width": width, "depth": depth, "floors": floors, "style": style, "hidden": hide_on_map}
	if use_tint:
		result.tint = tint
	if use_sign:
		result.sign = sign_color
	return result
