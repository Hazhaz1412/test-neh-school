extends "res://scripts/hiding_spot.gd"

var story: Node3D
var returning := false

func interact(actor: CharacterBody3D) -> bool:
	if returning or story.stage != story.Stage.TABLE_ESCAPE: return false
	if not super.interact(actor): return false
	story.begin_table_crossing()
	return true

func release() -> void:
	super.release()
	if returning and story.portal_arrived and story.stage == story.Stage.UNDER_TABLE:
		story.finish_table_crossing()

func set_available(value: bool) -> void:
	visible = value
	for body in find_children("*", "StaticBody3D", true, false): body.collision_layer = 1 if value else 0
	$Interaction.collision_layer = 16 if value else 0
