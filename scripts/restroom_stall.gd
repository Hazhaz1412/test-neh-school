extends Node3D

# The latch side of a restroom stall door; the player's E ray lands on its Area3D.
var scene: Node3D
var index := 0

func interaction_text() -> String:
	return "E · Đóng cửa buồng" if scene.stall_open(index) else "E · Mở cửa buồng"

func interact(actor: CharacterBody3D) -> bool:
	if actor != scene.world.player or not scene.world.simulation_active() or actor.get_interaction_target() != self:
		return false
	scene.toggle_stall(index)
	return true
