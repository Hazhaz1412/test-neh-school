extends SceneTree
# Mười Gió on Hẻm 8: a stranger until someone sends the player, then a seller of the lockpick and
# rope that finish his task without taking a bag slot.
# godot --headless --path . --script tools/validate_muoi_gio.gd
const Gear := preload("res://scripts/night_gear.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func choices(view: Control) -> Array:
	return view.choices.get_children().map(func(b): return b.text)

func run() -> void:
	var backup := FileAccess.get_file_as_bytes(Gear.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	var town: Node3D = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	await create_timer(3.6).timeout
	var story: Node = town.story
	var seller: Node = story.muoi_gio
	# His porch keeps no gate: from the alley, nothing stands between the player and his seat.
	# Looked at from the alley straight outside his house, wherever on Hẻm 8 that turns out to be.
	var road: Dictionary = town.plan.road_named(seller.ROAD)
	var alley: Vector2 = road.path[town.plan._closest_index(road, seller.lot.front)]
	var space := town.get_world_3d().direct_space_state
	var seat: Vector3 = town.builder._frame(seller.lot) * Vector3(0, 1.0, seller.SEAT_DEPTH)
	var seen: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(alley.x, seat.y, alley.y), seat))
	check(seller.lot.get("kiosk", false) and seen.is_empty(), "he sits in an open porch with no gate in the way")
	check(not seller.known() and seller.touch.label == "Người ngồi trong hiên nhà", "at first he is just someone sitting in a porch")
	seller.talk()
	await process_frame
	check(story.view != null and story.talking == "muoigio", "talking to him opens a dialogue with his portrait")
	story.close()
	check(not seller.known(), "nobody has sent the player yet")

	# Through Sợi Chỉ: the hub's contact reaches the town while the player is there.
	town.on_hub_message({"type": "contact", "id": "muoigio"})
	check(seller.known() and seller.touch.label.begins_with("Mua đồ"), "his reply on Sợi Chỉ makes him a seller")
	check(Gear.read().muoi_gio_known, "the town remembers him")
	story.gear.muoi_gio_known = false
	seller.touch.label = seller._label()
	# Through Bảy Rô: any finished caro game ends with a word about him.
	story.caro_finished()
	check(seller.known(), "Bảy Rô sends the player to him after caro")

	story.gear.caro_won = true
	check(story.objective().text.contains("Mười Gió"), "after Bảy Rô, the objective points to Mười Gió")
	var money: int = story.gear.money
	var bag: Array = story.gear.bag.duplicate()
	seller.talk()
	await process_frame
	check(choices(story.view).any(func(t): return t.contains("Bộ bẻ khóa · 90$")) and choices(story.view).any(func(t): return t.contains("Dây thừng · 60$")), "he offers the lockpick for 90$ and the rope for 60$")
	seller.buy("lockpick")
	check(story.gear.lockpick and story.gear.money == money - 90, "the lockpick costs 90$")
	check(not choices(story.view).any(func(t): return t.contains("bẻ khóa")), "what is bought leaves his list")
	seller.buy("rope")
	check(story.gear.rope and story.gear.money == money - 150, "the rope costs 60$")
	check(story.gear.bag == bag, "neither takes a bag slot")
	check(seller.done() and not story.objective().text.contains("Mười Gió"), "with both bought, the task is done")
	var saved := Gear.read()
	check(saved.lockpick and saved.rope, "the purchases are saved")
	story.close()

	story.gear.rope = false
	story.gear.money = 10
	check(Gear.buy_black(story.gear, "rope").contains("Không đủ tiền") and not story.gear.rope, "without the money there is no sale")

	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	else:
		FileAccess.open(Gear.PATH, FileAccess.WRITE).store_buffer(backup)
	print("failures ", failures)
	quit(failures)
