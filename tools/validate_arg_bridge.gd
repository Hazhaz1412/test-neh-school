extends SceneTree
# Run through hub/test/game_link.js, which provides the web stack on the other end.
const WAIT_FRAMES := 600
var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, description: String) -> void:
	print("PASS / " if ok else "FAIL / ", description)
	if not ok: failures += 1

func wait_for(condition: Callable) -> bool:
	for i in range(WAIT_FRAMES):
		if condition.call(): return true
		await process_frame
	return false

func validate() -> void:
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	await process_frame
	var bridge: Node = school.get_node("ArgBridge")
	check(not bridge.is_processing(), "bridge stays off during validation runs")
	bridge.set_process(true)
	check(await wait_for(func(): return bridge.linked), "game links to the hub")
	school.progression.evidence["clip"] = true
	check(await wait_for(func(): return bridge.bang.playing), "web message makes the door bang in game")
	quit(1 if failures else 0)
