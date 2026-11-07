@tool
extends Node3D
# The town as edited in the scene: Roads and Places are read by the game through town_plan,
# and while the scene is open in the editor they are rebuilt into a preview that is never saved.
const Plan := preload("res://scripts/town/town_plan.gd")
const Builder := preload("res://scripts/town/town_builder.gd")
const CHECK_SECONDS := 0.5
# The traffic loops, walkers and river are written against these; story and shops need the places.
const NEEDED_ROADS := ["Đường Cổ Đằng", "Cầu Mây", "Đường Đồng Muối", "Phố Chợ", "Đường Bến Trầu", "Phố Lò Than", "Phố Hàng Cau", "Đường Gò Sậy", "Hẻm 31", "Hẻm 27"]
const NEEDED_PLACES := ["home", "shop", "post", "pho", "cafe", "stall", "curio", "chess", "market"]
@export_tool_button("Dựng lại map") var rebuild_button := rebuild
@export_tool_button("Thêm đường") var add_road_button := add_road
@export_tool_button("Thêm địa điểm") var add_place_button := add_place
@export var live_preview := true
var preview: Node3D
var clock := 0.0
var built := ""
var pending := ""

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func definitions() -> Dictionary:
	var roads: Array = []
	for road in $Roads.get_children():
		var definition: Dictionary = road.definition()
		if definition.points.size() >= 2:
			roads.append(definition)
	var places: Array = []
	for place in $Places.get_children():
		places.append(place.definition())
	return {"roads": roads, "places": places}

func problems() -> PackedStringArray:
	var result := PackedStringArray()
	var layout := definitions()
	var titles: Array = layout.roads.map(func(road): return road.name)
	var ids: Array = layout.places.map(func(place): return place.id)
	for title in NEEDED_ROADS:
		if title not in titles:
			result.append("Thiếu đường \"%s\": giao thông hoặc sông cần nó, hãy đặt lại đúng tên." % title)
	for id in NEEDED_PLACES:
		if id not in ids:
			result.append("Thiếu địa điểm id \"%s\": cốt truyện hoặc cửa hàng cần nó." % id)
	for place in layout.places:
		if ids.count(place.id) > 1:
			result.append("Trùng id địa điểm \"%s\"." % place.id)
		if place.road != "" and place.road not in titles:
			result.append("Địa điểm \"%s\" gắn vào đường không tồn tại: %s." % [place.id, place.road])
	return result

func _get_configuration_warnings() -> PackedStringArray:
	return problems()

func _process(delta: float) -> void:
	clock += delta
	if clock < CHECK_SECONDS or not live_preview or owner != get_tree().edited_scene_root:
		return
	clock = 0.0
	_separate_curves()
	var state := str(definitions())
	# Wait for the edit to settle: a rebuild takes seconds and must not run under a drag.
	if state == built or state != pending:
		pending = state
		return
	update_configuration_warnings()
	rebuild()

# Ctrl+D shares the curve between both roads, which would drag them together.
func _separate_curves() -> void:
	var seen := []
	for road in $Roads.get_children():
		if road.curve in seen:
			road.curve = road.curve.duplicate()
		seen.append(road.curve)

func rebuild() -> void:
	built = str(definitions())
	if not problems().is_empty():
		push_warning("Town preview skipped: " + "; ".join(problems()))
		return
	if preview:
		remove_child(preview)
		preview.free()
	preview = Node3D.new()
	preview.name = "Preview"
	add_child(preview, false, Node.INTERNAL_MODE_BACK)
	Builder.new().build(preview, Plan.new(definitions()))

func add_road() -> void:
	var road := preload("res://scripts/town/town_road.gd").new()
	road.name = "Đường mới"
	road.curve = Curve3D.new()
	road.curve.add_point(Vector3(-20, 0, 130))
	road.curve.add_point(Vector3(20, 0, 130))
	_add_to($Roads, road)

func add_place() -> void:
	var place := preload("res://scripts/town/town_place.gd").new()
	place.name = "Địa điểm mới"
	place.gizmo_extents = 4.0
	place.position = Vector3(-60, 0, -40)
	_add_to($Places, place)

func _add_to(group: Node, node: Node3D) -> void:
	group.add_child(node, true)
	node.owner = get_tree().edited_scene_root
	EditorInterface.edit_node(node)
