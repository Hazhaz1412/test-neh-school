extends RefCounted
# Where a walker on a NavigationAgent3D should head. Normally the agent's own next corner (it
# climbs stairs well). But the agent only moves on when it is close in 3D, and the walkable map
# can float a little above the feet: standing right under a corner it still points at it and the
# walker freezes. Only then does this look further along the path for the first corner that is
# really ahead on the walker's own level.
# Close enough on the ground to count a corner as passed (the agent itself wants 0.2 m in 3D,
# which a walker on a stair step above or below the corner never gets).
const REACHED := 0.5
# A corner more than this above or below the feet is on another level (a stair flight).
const LEVEL := 0.9

static func point(agent: NavigationAgent3D, feet: Vector3) -> Vector3:
	var next := agent.get_next_path_position()
	if Vector2(next.x - feet.x, next.z - feet.z).length() >= REACHED or absf(next.y - feet.y) >= LEVEL:
		return next
	var path := agent.get_current_navigation_path()
	if path.is_empty():
		return next
	# The raw path floats path_height_offset above the floor (get_next_path_position takes it off).
	var lift := Vector3.UP * agent.path_height_offset
	var index := clampi(agent.get_current_navigation_path_index(), 0, path.size() - 1)
	while index < path.size() - 1 and Vector2(path[index].x - feet.x, path[index].z - feet.z).length() < REACHED and absf(path[index].y - lift.y - feet.y) < LEVEL:
		index += 1
	return path[index] - lift

# A real step-up: just ahead of the feet, is there a tread no higher than the walkable map's
# climb (0.5 m, plus its voxel slop) and flat enough to stand on? Then lift onto it. Desks (0.75 m),
# sills (0.9 m), rails and walls stay out of reach, and nothing lifts a walker merely heading for
# a higher corner further on.
const STEP_MAX := 0.65
const PROBE := 0.45
static func step_up(body: CharacterBody3D, direction: Vector3) -> float:
	if direction == Vector3.ZERO:
		return 0.0
	var feet := body.global_position
	var ahead := feet + direction.normalized() * PROBE
	var ray := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * (STEP_MAX + 0.1), ahead + Vector3.DOWN * 0.1, 1)
	ray.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.7:
		return 0.0
	var rise: float = hit.position.y - feet.y
	if rise < 0.04 or rise > STEP_MAX:
		return 0.0
	return clampf(rise * 14.0, 1.6, 4.5)

# A side step that keeps the feet on this level: off the edge of a stair flight is no escape.
# Returns the safer of the two sides, or ZERO when both drop away.
static func safe_side(body: CharacterBody3D, direction: Vector3, prefer: float) -> Vector3:
	var space := body.get_world_3d().direct_space_state
	for sign in [prefer, -prefer]:
		var side: Vector3 = (direction.cross(Vector3.UP) * sign - direction * 0.6).normalized()
		var probe: Vector3 = body.global_position + side * 0.6
		var ray := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.5, probe + Vector3.DOWN * 0.6, 1)
		ray.exclude = [body.get_rid()]
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and hit.position.y > body.global_position.y - 0.25:
			return side
	return Vector3.ZERO

# Standing right under (or over) the corner it is heading for, on another level: the path is
# stale or it has strayed onto the wrong level.
static func lost_level(agent: NavigationAgent3D, feet: Vector3) -> bool:
	var next := agent.get_next_path_position()
	return Vector2(next.x - feet.x, next.z - feet.z).length() < REACHED and absf(next.y - feet.y) >= LEVEL

# After a body is moved by hand (a climb, a slide under boards), the agent's place along its old
# path is wrong: ask for a fresh path from where it now stands.
static func repath(agent: NavigationAgent3D) -> void:
	var goal := agent.target_position
	agent.target_position = goal + Vector3(0.001, 0, 0)
	agent.target_position = goal
