extends RefCounted

# `cell` and `radius` default to the school-wide map; Night 1 bakes finer so corners keep their
# clearance (at 0.25 m cells a wall end can be left only a few centimetres).
static func bake(school: Node3D, path := "res://scenes/campus_navigation.tres", cell := 0.25, radius := 0.25, cell_height := 0.25, climb := 0.5) -> NavigationRegion3D:
	if school.has_node("Navigation"):
		school.get_node("Navigation").free()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = cell
	mesh.cell_height = cell_height
	mesh.agent_height = 1.75
	# Rounded up to whole cells: 0.5 m (two cells) seals every 1.3 m classroom doorway.
	mesh.agent_radius = radius
	# Two voxels at 0.25 m: at one, a 26 degree stair flight bakes as a row of ledges. Finer maps
	# use finer voxels and a lower climb, so a stair is only joined at its foot, not at its sides.
	mesh.agent_max_climb = climb
	mesh.agent_max_slope = 35.0
	mesh.region_min_size = 2.0
	# Half-turn stairs are one helix to the default partition, which then drops or mangles them.
	mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_LAYERS
	mesh.filter_baking_aabb = AABB(Vector3(-59, -1, -83), Vector3(118, 17, 162))
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, geometry, school)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	assert(mesh.get_polygon_count() > 0, "Navigation bake produced no polygons")
	assert(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = mesh
	school.add_child(region)
	region.owner = school
	print("Baked navigation polygons: ", mesh.get_polygon_count())
	return region
