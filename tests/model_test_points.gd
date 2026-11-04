extends RefCounted
## Input tests use the rendered mesh coordinates, independent of camera zoom.

static func _resident(view: Control, member: Dictionary) -> Node3D:
	var resident := view.projection.scene.resident_nodes.get(str(member.id)) as Node3D
	assert(resident!=null,"The resident has an instantiated 3D model")
	return resident

static func _uncovered(view: Control, point: Vector2, id: String) -> bool:
	# Require an actual mesh hit as well as the UI's input result. A nameplate or
	# thought cue must never make a fully occluded model pass the selection test.
	return view.projection.hit(point).get("id")==id and view.hit_target(point).get("id")==id and not view.overlay_rects.any(func(rect: Rect2): return rect.has_point(point))

static func _mesh_points(view: Control, node: Node3D, id: String) -> Array[Vector2]:
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh!=null:
		var faces: PackedVector3Array=node.mesh.get_faces()
		for index in range(0,faces.size(),3):
			var center := (faces[index]+faces[index+1]+faces[index+2])/3.0
			var point: Vector2=view.projection.project(node.global_transform*center)
			if _uncovered(view,point,id): return [point]
	for child: Node in node.get_children():
		if child is Node3D and child.is_visible_in_tree():
			var points := _mesh_points(view,child,id)
			if not points.is_empty(): return points
	return []

static func resident_part(view: Control, member: Dictionary, part: String) -> Vector2:
	var resident := _resident(view,member)
	var node := resident.find_child(part,true,false) as Node3D
	assert(node!=null,"The resident model exposes its "+part+" geometry")
	var bounds: AABB=view.projection.scene.bounds(node)
	assert(not bounds.size.is_zero_approx(),"The selected body part contains real meshes")
	var point: Vector2=view.projection.project(bounds.get_center())
	if _uncovered(view,point,str(member.id)): return point
	var points := _mesh_points(view,node,str(member.id))
	assert(not points.is_empty(),"The resident's "+part+" has a visible selectable model surface")
	return points[0]

static func resident_surface(view: Control, member: Dictionary) -> Vector2:
	var resident := _resident(view,member)
	# Sleeping heads can be correctly occluded by adjacent bed headboards after
	# rotation. Find an exposed triangle on the body, excluding the selection ring.
	var points := _mesh_points(view,resident.get_node("Body"),str(member.id))
	assert(not points.is_empty(),"The resident has an exposed selectable body surface")
	return points[0]

static func object_surface(view: Control, object: Dictionary) -> Vector2:
	var node := view.projection.scene.object_nodes.get(str(object.id)) as Node3D
	assert(node!=null,"The furnishing has an instantiated 3D model")
	var points := _mesh_points(view,node,str(object.id))
	assert(not points.is_empty(),"The furnishing has an exposed selectable model surface: "+str(object.kind))
	return points[0]

static func wall_face(view: Control, x: int, y: int, along_x: bool) -> Vector2:
	var wall := view.projection.scene.architecture.get_node("Wall_%d_%d" % [x,y]) as Node3D
	var bounds: AABB=wall.get_meta("pick_aabb")
	var local := bounds.get_center()
	# The positive X/Z face faces the camera. The test deliberately clicks above
	# the ground to distinguish picking the wall from selecting its floor tile.
	if along_x: local.z=bounds.end.z
	else: local.x=bounds.end.x
	return view.projection.project(wall.global_transform*local)
