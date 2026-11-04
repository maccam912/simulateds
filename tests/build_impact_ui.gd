extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
	# Keep native enter/exit events aligned with the injected viewport input.
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
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

func _named(node: Node,title: String) -> Button:
	if node is Button and node.text==title: return node
	for child in node.get_children():
		var found := _named(child,title)
		if found!=null: return found
	return null

func _point(id: String) -> Vector2:
	for region: Dictionary in game.lot_view._hit_regions:
		if region.target.get("type")!="object" or region.target.get("id")!=id: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		if game.lot_view.hit_target(point).get("id")==id and not game.lot_view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"Furnishing must have a visible click surface"); return Vector2.ZERO

func _tile(x: int,y: int,click: bool=false) -> void: await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/build-impact-"+name+suffix+".png")==OK)

func _readable() -> void:
	var view: Control=game.lot_view
	assert(view.preview_label_rect.has_area() and root.get_visible_rect().encloses(view.preview_label_rect))
	for rect: Rect2 in view.overlay_rects:
		assert(not rect.intersects(view.preview_label_rect),"The explanation must stay clear of HUD controls")
		for marker: Rect2 in view.impact_markers.values(): assert(not marker.intersects(rect),"The warning badges must stay clear of HUD controls")
	for marker: Rect2 in view.impact_markers.values(): assert(not marker.intersects(view.preview_label_rect),"The explanation must not hide its warning badges")

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	var lot: Dictionary=session.state.lots.lot_1; var view: Control=game.lot_view
	await _button(game.mode_button); await _button(game.catalog_buttons.game_table)
	var before: Dictionary=session.world.snapshot(); var funds: int=lot.funds
	await _tile(8,4); await _capture("fridge-warning"); _readable()
	assert(view.preview_result.ok and view.placement_impact.introduced.size()==1 and view.placement_impact.introduced[0].name=="Kitchen fridge")
	assert(view.impact_markers.size()==1 and view.placement_impact.lost_floor.has(Vector2i(10,5)) and session.world.snapshot()==before)
	var predicted: Dictionary=view.placement_impact.after.duplicate(true)
	await _tile(9,8); await _capture("clear")
	assert(view.preview_result.ok and view.placement_impact.ok and view.impact_markers.is_empty() and session.world.snapshot()==before)
	await _tile(10,4); await _capture("occupied")
	assert(not view.preview_result.ok and view.placement_impact.is_empty() and view.impact_markers.is_empty())
	await _tile(8,4,true)
	assert(lot.funds==funds-340 and session.world.build_access(lot)==predicted,"The accepted draft has exactly the warned-about access consequence")
	var table: String=lot.objects[-1].id
	await _button(game.mode_button)
	assert(lot.building and game._context_page=="access" and game.access_buttons.size()==1)
	await _button(_named(game.context_box,"Move")); await _mouse(_point(table),true)
	assert(game._moving_object==table)
	before=session.world.snapshot(); await _tile(9,8); await _capture("repair-preview"); _readable()
	assert(view.placement_impact.ok and view.placement_impact.resolved.size()==1 and view.placement_impact.message=="Restores access · Ready to finish" and session.world.snapshot()==before)
	await _tile(9,8,true); assert(session.world.build_access(lot).ok and lot.funds==funds-340)
	await _button(game.undo_button); assert(not session.world.build_access(lot).ok)
	await _button(game.redo_button); assert(session.world.build_access(lot).ok)
	await _button(game.catalog_buttons.wall)
	before=session.world.snapshot(); await _tile(8,11); await _capture("entrance-warning"); _readable()
	assert(view.preview_result.ok and view.placement_impact.introduced.size()==13 and view.impact_markers.size()==6 and session.world.snapshot()==before)
	await _tile(8,11,true); assert(not session.world.build_access(lot).ok)
	await _button(game.catalog_buttons.door); await _tile(8,11); await _capture("door-repair"); _readable()
	assert(view.preview_result.ok and view.placement_impact.ok and view.placement_impact.resolved.size()==13)
	await _tile(8,11,true); assert(session.world.build_access(lot).ok)
	await _button(_named(game.context_box,"Sell")); await _mouse(_point(table),true)
	assert(session.world._object(lot,table).is_empty(),"Remove the extra table before planning a kitchen divider")
	await _button(game.mode_button); assert(not lot.building)
	# Move the residents clear of the proposed kitchen divider through ordinary
	# accepted walking plans before returning to construction.
	var members: Array=session.state.families[session.profile_id].members
	for index in range(2):
		var destination: Vector2i=[Vector2i(5,9),Vector2i(8,10)][index]
		session.command({"type":"move","member_id":members[index].id,"lot_id":lot.id,"x":destination.x,"y":destination.y}); assert(session.last_action_ok)
	for step in range(160):
		session.world.step(0.1)
		if members.all(func(member): return member.task.is_empty() and member.queue.is_empty()): break
	game._refresh(); await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.room)
	for turn in range(3): await _key(KEY_R)
	assert(game.build_rotation==3)
	before=session.world.snapshot(); await _tile(7,3,true); await _tile(12,7); await _capture("room-warning"); _readable()
	assert(view.preview_result.ok and view.placement_impact.warning and view.placement_impact.introduced.size()==3 and session.world.snapshot()==before)
	await _key(KEY_R); await _capture("room-clear")
	assert(view.preview_result.ok and view.placement_impact.ok and view.impact_markers.is_empty() and session.world.snapshot()==before)
	await _key(KEY_ESCAPE); assert(game._room_anchor.x<0)
	await _button(game.mode_button); assert(not lot.building)
	await _capture("live")
	# A loaded neighborhood can have the same lot ID, revision, funds, and
	# resident positions. Its forecast must not reuse the previous world's cache.
	await _button(game.mode_button); await _button(game.catalog_buttons.game_table)
	await _tile(8,4); assert(view.placement_impact.warning)
	var replacement = preload("res://game/world.gd").new()
	assert(replacement.restore(session.world.snapshot(),true))
	for object: Dictionary in replacement.state.lots.lot_1.objects:
		if object.kind=="fridge": object.x=14; object.y=4
	session.world=replacement; game._refresh(); await process_frame; await process_frame
	assert(view.preview_result.ok and view.placement_impact.ok and view.impact_markers.is_empty(),"World replacement invalidates access forecasts even at the same lot revision")
	print("BUILD_IMPACT_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
