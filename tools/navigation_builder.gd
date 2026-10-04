extends RefCounted

static func bake(school: Node3D) -> NavigationRegion3D:
	if school.has_node("Navigation"):
		school.get_node("Navigation").free()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_height = 1.75
	mesh.agent_radius = 0.50
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 35.0
	mesh.region_min_size = 2.0
	mesh.filter_baking_aabb = AABB(Vector3(-59, -1, -83), Vector3(118, 17, 162))
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, geometry, school)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	assert(mesh.get_polygon_count() > 0, "Navigation bake produced no polygons")
	assert(ResourceSaver.save(mesh, "res://scenes/campus_navigation.tres", ResourceSaver.FLAG_CHANGE_PATH) == OK)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = mesh
	school.add_child(region)
	region.owner = school
	print("Baked navigation polygons: ", mesh.get_polygon_count())
	return region
