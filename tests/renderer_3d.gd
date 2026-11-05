extends SceneTree
## Integration coverage of the real model renderer, camera, picking and save isolation.
const Catalog = preload("res://game/catalog.gd")
var game: Control
var view: Control
var session: Node

func _initialize() -> void: call_deferred("_run")

func _settle() -> void:
	for index in range(4): await process_frame

func _capture(name: String) -> void:
	await _settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/3d-"+name+".png")==OK)

func _model_meshes(node: Node) -> int:
	assert(not node is Sprite3D,"The world uses mesh models, never billboard substitutes")
	var count := 1 if node is MeshInstance3D and node.mesh!=null else 0
	for child in node.get_children(): count+=_model_meshes(child)
	return count

func _visible_point(id: String) -> Vector2:
	for region: Dictionary in view._hit_regions:
		if region.target.get("id")!=id: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		if view.hit_target(point).get("id")==id and not view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"No selectable projected model surface: "+id)
	return Vector2.ZERO

func _wall_parts(at: Vector2i) -> Array[AABB]:
	var wall: Node3D=view.projection.scene.architecture.get_node("Wall_%d_%d" % [at.x,at.y])
	return wall.get_meta("pick_parts")

func _check_corners() -> void:
	var corners := {
		Vector2i(3,3):[Vector2i.RIGHT,Vector2i.DOWN],
		Vector2i(12,3):[Vector2i.LEFT,Vector2i.DOWN],
		Vector2i(3,11):[Vector2i.RIGHT,Vector2i.UP],
		Vector2i(12,11):[Vector2i.LEFT,Vector2i.UP],
	}
	for corner: Vector2i in corners:
		var parts := _wall_parts(corner)
		assert(parts.size()==2,"A corner uses two joined perpendicular wall pieces.")
		assert(parts.any(func(box: AABB): return box.has_point(Vector3(0,0.15,0))))
		for direction: Vector2i in corners[corner]:
			var edge := Vector3(direction.x*0.499,0.15,direction.y*0.499)
			assert(parts.any(func(box: AABB): return box.has_point(edge)),"Corner geometry reaches the shared tile edge.")
			assert(_wall_parts(corner+direction).any(func(box: AABB): return box.has_point(Vector3(-edge.x,edge.y,-edge.z))),"The adjoining wall reaches the corner.")
			assert(not parts.any(func(box: AABB): return box.has_point(Vector3(-edge.x,edge.y,-edge.z))),"There is no stray wall stub beyond the corner.")

func _run() -> void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute("res://build")
	root.get_node("Preferences").reset_defaults()
	root.get_node("Preferences").set_value("reduced_motion",true)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _settle()
	var before: Dictionary=session.world.snapshot()
	assert(view.projection.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
	assert(view.projection.viewport.own_world_3d)
	for kind: String in Catalog.ITEMS:
		if kind in ["floor","wall","door"]: continue
		var asset := load("res://assets/models/"+kind+".glb") as PackedScene
		assert(asset!=null,"Every catalog furnishing has an imported model: "+kind)
		var model := asset.instantiate()
		assert(_model_meshes(model)>0)
		model.free()
	assert(view.projection.scene.object_nodes.size()==session.state.lots.lot_1.objects.size())
	assert(view.projection.scene.resident_nodes.size()==2)
	for resident: Node3D in view.projection.scene.resident_nodes.values():
		assert(resident.has_node("Body/Head/Eye_L"),"Existing residents use the same character geometry as the creator")
	assert(_model_meshes(view.projection.scene)>20)
	for pan: Vector2 in [Vector2.ZERO,Vector2(120,-55)]:
		view.pan=pan
		for zoom in [0.65,1.0,1.8]:
			view.zoom=zoom; view._layout()
			for tile: Vector2 in [Vector2(0.5,0.5),Vector2(8.5,7.5),Vector2(15.5,15.5)]:
				var point: Vector2=view.grid_point(tile.x,tile.y)
				assert(point.distance_to(view.projection.project(Vector3(tile.x,0,tile.y)))<0.1,"Camera and build grid agree")
				assert(view.projection.ground_at(point).distance_to(tile)<0.001)
	view.center_lot(); await _capture("day")
	_check_corners()
	for object: Dictionary in session.state.lots.lot_1.objects: _visible_point(str(object.id))
	for member: Dictionary in session.state.families[session.profile_id].members: _visible_point(str(member.id))
	assert(session.world.snapshot()==before,"Projection, meshes, picking and camera cannot mutate the saved world")
	# Actual input through a raised model selects that furnishing in the existing HUD.
	var bed: Dictionary=session.state.lots.lot_1.objects[0]
	var point := _visible_point(str(bed.id))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=pressed
		root.push_input(event,true); await process_frame
	assert(not session.state.families[session.profile_id].members[0].task.is_empty(),"Model click issues an existing activity command")
	game._toggle_build(); await _capture("build")
	game.selected_tool="sofa"; game.build_rotation=1; game._refresh()
	var cursor := InputEventMouseMotion.new(); cursor.position=view.grid_point(9.5,7.5); root.push_input(cursor,true)
	await _capture("placement")
	assert(not view.preview_result.is_empty(),"3D build view retains placement validation")
	session.state.day_minutes=0; game._refresh(); await _capture("night")
	root.size=Vector2i(1280,720); root.get_node("Preferences").set_value("ui_scale",1.25)
	await _capture("compact")
	_check_corners()
	game._select_build_tool("window")
	await _capture("joined-full")
	_check_corners()
	assert(view.projection.viewport.size==Vector2i(view.size))
	print("RENDERER_3D_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
