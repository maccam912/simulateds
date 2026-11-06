extends SceneTree
## Shadow coverage, doorway cutaways, read-only presentation and native comparison.
var session: Node
var game: Control
var view: Control
var tag := "after"
var compact := false
var baseline := false

func _initialize() -> void: call_deferred("_run")
func _settle() -> void:
	for i in 8: await process_frame
func _capture(label: String) -> void:
	await _settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/world-polish-"+tag+"-"+label+("-compact" if compact else "")+".png")==OK)
func _visible_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in view.projection.scene._meshes(node):
		if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var box: AABB=mesh.global_transform*mesh.get_aabb()
		result=box if first else result.merge(box); first=false
	return result
func _coverage() -> void:
	var camera: Camera3D=view.projection.camera
	var terrain_y := -0.75-float(game.view_level)*preload("res://game/storeys.gd").HEIGHT
	for corner: Vector2 in [Vector2.ZERO,Vector2(view.size.x,0),view.size,Vector2(0,view.size.y)]:
		var ray := camera.project_ray_origin(corner)
		var direction := camera.project_ray_normal(corner)
		var terrain := ray+direction*((terrain_y-ray.y)/direction.y)
		assert(-camera.to_local(terrain).z<camera.far-1,"Even low terrain at the viewport edge stays within the far plane")
	for tile: Vector2 in [Vector2(0.5,0.5),Vector2(8.5,7.5),Vector2(15.5,15.5)]:
		assert(view.projection.ground_at(view.grid_point(tile.x,tile.y)).distance_to(tile)<0.001,"Shadow coverage cannot change picking")
func _benchmark(label: String) -> void:
	if DisplayServer.get_name()=="headless" or "--benchmark" not in OS.get_cmdline_user_args(): return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	for i in 60: await process_frame
	var times: Array[float]=[]
	for i in 180:
		var started := Time.get_ticks_usec()
		await process_frame
		times.append((Time.get_ticks_usec()-started)/1000.0)
	times.sort()
	print("WORLD_POLISH_BENCH ",tag," ",label," median_ms=",times[90]," p95_ms=",times[171]," static_memory=",OS.get_static_memory_usage()," video_memory=",Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func _run() -> void:
	compact="--compact" in OS.get_cmdline_user_args(); baseline="--baseline" in OS.get_cmdline_user_args()
	if baseline: tag="before"
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	var prefs := root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _settle()
	var scene: Node3D=view.projection.scene
	var lot: Dictionary=session.state.lots.lot_1
	for sample: Array in [[720,"day"],[1080,"dusk"],[0,"night"]]:
		session.state.day_minutes=sample[0]; game._refresh()
		var before: Dictionary=session.world.snapshot()
		await _capture(sample[1]); await _benchmark(sample[1])
		assert(session.world.snapshot()==before,"Rendering cannot change clock, commands, paths, funds or saves")
	if not baseline:
		assert(scene.sun.directional_shadow_mode==DirectionalLight3D.SHADOW_ORTHOGONAL)
		assert(view.projection.camera.far<100,"Ordinary home framing avoids the wasteful 180m shadow volume")
		var door: Node3D=scene.architecture.get_node("Door_8_11")
		assert(door.get_meta("cutaway") and _visible_bounds(door).end.y<0.4,"Near doorway meets low walls without a floating lintel")
		assert(scene._meshes(door).any(func(mesh): return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY),"The hidden door still casts its real shadow")
		assert(not _visible_bounds(door).has_point(Vector3(8.5,1,11.5)),"No scaled lintel crosses the open walking passage")
	# Broad camera positions exercise the far-plane calculation without mutating the lot.
	var before: Dictionary=session.world.snapshot()
	for level in [0,1,2]:
		game._set_view_level(level)
		for zoom: float in [0.55,1.0,1.8,2.2]:
			for pan: Vector2 in [Vector2.ZERO,Vector2(240,160),Vector2(-240,-350)]:
				view.zoom=zoom; view.pan=pan; view._layout(); _coverage()
	assert(before==session.world.snapshot())
	view.zoom=0.55; view.pan=Vector2.ZERO; view._layout(); await _capture("upper-wide")
	game._set_view_level(0)
	view.zoom=0.55; view.pan=Vector2.ZERO; view._layout(); await _capture("wide")
	game._home_overview(); prefs.set_value("quality","low"); await _capture("night-low")
	await _benchmark("night-low")
	prefs.set_value("quality","high")
	# Reversible host commands show raised doorway tools and cutaway access view.
	game._toggle_build(); game._select_build_tool("door"); await _capture("raised-door")
	if not baseline:
		var door: Node3D=scene.architecture.get_node("Door_8_11")
		assert(not door.get_meta("cutaway") and _visible_bounds(door).end.y>2)
	game._select_build_tool("move"); await _capture("cutaway-build")
	# Fixture covers rear, side, interior and diagonal door orientations, plus
	# actual windows/art picking in the existing renderer/windows suites.
	lot.walls.erase([6,3]); lot.doors.append([6,3])
	lot.walls.erase([12,7]); lot.doors.append([12,7])
	lot.doors.append([8,7]); lot.diagonal_walls["8,7"]=1
	game._refresh(); await _settle()
	if not baseline:
		assert(not scene.architecture.get_node("Door_6_3").get_meta("cutaway"),"Rear doorway stays architecturally complete")
		for key: String in ["Door_12_7","Door_8_7"]:
			var door: Node3D=scene.architecture.get_node(key)
			assert(door.get_meta("cutaway") and _visible_bounds(door).end.y<0.4)
		assert(is_equal_approx(scene.architecture.get_node("Door_12_7").rotation.y,PI/2))
		assert(is_equal_approx(scene.architecture.get_node("Door_8_7").rotation.y,-PI/4))
	await _capture("door-orientations")
	print("WORLD_POLISH_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
