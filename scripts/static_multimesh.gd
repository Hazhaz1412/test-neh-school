@tool
extends MultiMesh

# The headless dummy renderer does not retain MultiMesh GPU buffers when saving.
# Persist placements on the resource itself so editor and game can restore them.
@export var placements: Array[Transform3D] = []:
	set(value):
		placements = value
		if transform_format != TRANSFORM_3D:
			instance_count = 0
			transform_format = TRANSFORM_3D
		instance_count = placements.size()
		for index in range(placements.size()):
			set_instance_transform(index, placements[index])
