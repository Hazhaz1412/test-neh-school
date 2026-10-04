extends Node3D

# A real maintenance doorway in the perimeter, opened by the story sequence.
func set_open_amount(amount: float) -> void:
	$Hinge/Leaf.rotation.y = -PI / 2 * smoothstep(0, 1, clampf(amount, 0, 1))
	$Hinge/Leaf/Padlock.visible = amount <= 0.02

func interaction_text() -> String:
	return "Cửa bảo trì bị phong kín · không thể rời trường trước bình minh"

func interact(_actor: CharacterBody3D) -> bool:
	get_parent().get_parent().notify("Cánh cửa đã kẹt cứng sau khi cả nhóm đi vào.")
	return false
