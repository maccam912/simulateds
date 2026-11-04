extends SceneTree
const Colors = preload("res://game/furniture_colors.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _button(control: Button) -> void:
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(pressed[0])

func _point(id: String) -> Vector2:
	for region: Dictionary in game.lot_view._hit_regions:
		if region.target.get("type")!="object" or region.target.get("id")!=id: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		if game.lot_view.hit_target(point).get("id")==id and not game.lot_view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"Furnishing must have a visible click surface: "+id); return Vector2.ZERO

func _key(code: int,control: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.ctrl_pressed=control
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.18).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/furniture-colors-"+name+suffix+".png")==OK)

func _object(id: String) -> Dictionary: return session.world._object(session.state.lots.lot_1,id)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	session.command({"type":"build_begin","lot_id":"lot_1"}); assert(session.last_action_ok)
	for furnishing: Array in [["stereo",7,5],["game_table",9,8],["garden_bed",6,13]]:
		session.command({"type":"place","lot_id":"lot_1","kind":furnishing[0],"x":furnishing[1],"y":furnishing[2]}); assert(session.last_action_ok,session.last_action_message)
	assert(session.world.build_access(session.state.lots.lot_1).ok,str(session.world.build_access(session.state.lots.lot_1).message))
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	var lot: Dictionary=session.state.lots.lot_1; var bed: String=lot.objects[0].id; var funds: int=lot.funds
	await _button(game.catalog_buttons.furniture_color); await _capture("palette")
	var viewport: Rect2=game.tools_box.get_parent().get_global_rect()
	assert(not game.catalog_filters.visible and game.color_buttons.size()==6)
	for button: Button in game.color_buttons.values(): assert(viewport.encloses(button.get_global_rect()),"All six material swatches fit together")
	game.color_buttons.sky.grab_focus(); await _key(KEY_SPACE)
	assert(game.color_buttons.sky.has_focus() and game.furniture_color=="sky")
	var before: Dictionary=session.world.snapshot()
	await _mouse(_point(bed)); await _capture("sky-preview")
	assert(game.lot_view.color_preview.ok and game.lot_view.color_preview.object_id==bed and session.world.snapshot()==before)
	assert(game.lot_view.preview_label_rect.has_area())
	for rect: Rect2 in game.lot_view.overlay_rects: assert(not rect.intersects(game.lot_view.preview_label_rect))
	await _mouse(_point(bed),true)
	assert(Colors.at(_object(bed))=="sky" and lot.funds==funds and game._color_request.is_empty())
	await _capture("applied")
	before=session.world.snapshot(); await _mouse(_point(bed),true)
	assert(session.world.snapshot()==before and game.lot_view.color_preview.get("reason")=="unchanged")
	await _button(game.undo_button); assert(Colors.at(_object(bed))=="original")
	await _button(game.redo_button); assert(Colors.at(_object(bed))=="sky")
	await _button(game.color_buttons.original); await _mouse(_point(bed),true)
	assert(not _object(bed).has("color_style"))
	await _key(KEY_F,true)
	assert(game.catalog_filters.visible and game.catalog_search.has_focus(),"Search returns from colors to the catalog")
	await _button(game.catalog_buttons.furniture_color)
	var index := 0
	for object: Dictionary in lot.objects:
		var style: String=["sky","rose","honey","sage","ink"][index%5]; index+=1
		await _button(game.color_buttons[style]); await _mouse(_point(str(object.id)),false)
		assert(game.lot_view.color_preview.ok)
		await _mouse(_point(str(object.id)),true); assert(Colors.at(object)==style)
	assert(lot.funds==funds)
	await _capture("house")
	before=session.world.snapshot()
	await _mouse(game.lot_view.grid_point(1.5,10.5),true)
	assert(session.world.snapshot()==before,"Clicking empty ground cannot recolor or purchase anything")
	await _button(game.access_button); assert(game.lot_view.color_preview.is_empty())
	await _capture("access"); await _button(game.access_button)
	# A rejected unrelated request cannot dismiss a pending recolor.
	var intent := {"type":"recolor","lot_id":lot.id,"object_id":bed,"style":"ink","revision":lot.revision}
	game._color_request=intent.duplicate(); game._refresh()
	await process_frame
	assert(game.color_buttons.values().all(func(button): return button.disabled))
	var unrelated := intent.duplicate(); unrelated.object_id=lot.objects[1].id
	game._color_completed(unrelated,false,""); assert(not game._color_request.is_empty())
	session.last_action_ok=false; game._notice("Unrelated failure"); assert(not game._color_request.is_empty()); session.last_action_ok=true
	game._color_completed(intent,true,""); assert(not game._color_request.is_empty())
	game._color_completed(intent,false,""); assert(game._color_request.is_empty())
	await _button(game.mode_button); assert(not lot.building)
	await _capture("live")
	# Sleeping uses the chosen bedding as well as the unoccupied bed renderer.
	var resident: Dictionary=session.state.families[session.profile_id].members[0]
	resident.needs.energy=0.0
	session.command({"type":"interact","member_id":resident.id,"lot_id":lot.id,"target_id":bed}); assert(session.last_action_ok)
	for step in range(120):
		session.world.step(0.1)
		if resident.task.get("path",[]).is_empty() and float(resident.task.get("elapsed",0))>0: break
	assert(not resident.task.is_empty() and session.world.task_activity(resident.task,lot.id)=="bed")
	game._refresh(); await _capture("sleeping")
	print("FURNITURE_COLORS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
