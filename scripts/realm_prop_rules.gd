extends RefCounted

# Share the same rigid transformation between mesh instances and their shapes.
# Suspended furniture clears the capsule and never moves into a corridor.
static func change_for(node: Node3D, school: Node3D) -> Transform3D:
	var pivot := node
	while pivot.get_parent() != null and pivot.get_parent() != school.get_node("Furniture"):
		pivot = pivot.get_parent() as Node3D
		if pivot == null or pivot == school:
			return Transform3D.IDENTITY
	if pivot.get_parent() != school.get_node("Furniture"):
		return Transform3D.IDENTITY
	var pos := pivot.global_position
	if pos.x < -38 and pos.z < -45:
		return Transform3D.IDENTITY # Warehouse shelves and the key desk stay usable.
	var label := String(pivot.name)
	var seed_value := absi(label.hash())
	var target := pivot.global_transform
	if label.begins_with("chair") and seed_value % 3 != 0:
		target.basis = Basis(Vector3.FORWARD, PI) * target.basis
		target.origin.y += 3.3
	elif label.begins_with("desk") and seed_value % 4 == 0:
		target.basis = Basis(Vector3.FORWARD, PI) * target.basis
		target.origin.y += 3.4
	elif label.begins_with("books"):
		target.basis = Basis(Vector3.FORWARD, 0.35 if seed_value % 2 == 0 else -0.35) * target.basis
		target.origin.y += 0.65
	else:
		return Transform3D.IDENTITY
	return target * pivot.global_transform.affine_inverse()

static func category_for(node: Node, school: Node) -> int:
	var path := String(school.get_path_to(node))
	if path.begins_with("Landscape/"):
		return 3
	if path.begins_with("Furniture/fountain/"):
		return 4
	if path.begins_with("Furniture/"):
		return 2
	if path.begins_with("HidingSpots/"):
		return 2 # Fixed covers can share instancing and curse materials with props.
	if path.begins_with("Atmosphere/"):
		return -1 # Fixture emission should remain legible.
	if path.contains("TransparentWindow"):
		return -1
	return 1
