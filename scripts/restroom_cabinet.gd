extends Node3D

# The handle of the restroom cleaning cabinet; the player's E ray lands on its Area3D.
var scene: Node3D

func interaction_text() -> String:
	return scene.cabinet_text()

func interact(actor: CharacterBody3D) -> bool:
	if actor != scene.world.player or not scene.world.simulation_active() or actor.get_interaction_target() != self:
		return false
	return scene.story.open_cabinet()
