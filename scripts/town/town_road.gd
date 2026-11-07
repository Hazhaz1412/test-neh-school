@tool
extends Path3D
# One road of the town. The node's name is the road's name; drag the curve's points in the viewport.
# Curve handles are ignored: the road always runs smoothly through the points themselves.
@export_enum("main", "bridge", "country", "street", "alley") var kind := "street"
@export var width := 7.0
@export var walk := 2.0

func definition() -> Dictionary:
	var points: Array = []
	for i in range(curve.point_count if curve else 0):
		var at: Vector3 = transform * curve.get_point_position(i)
		points.append(Vector2(at.x, at.z))
	return {"name": String(name), "kind": kind, "width": width, "walk": walk, "points": points}
