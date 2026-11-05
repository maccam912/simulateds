extends SceneTree
const Space = preload("res://game/construction_space.gd")
const Finishes = preload("res://game/finishes.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame

func _button(control: Button) -> void:
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(pressed[0])

func _tile(x: int,y: int,click: bool=true) -> void:
	await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/construction-space-"+name+suffix+".png")==OK)

func _command(intent: Dictionary) -> void:
	intent.lot_id=intent.get("lot_id","lot_1"); intent.revision=session.state.lots.lot_1.revision
	var result: Dictionary=session.world.apply_command(session.profile_id,intent)
	assert(result.ok,result.message)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	session.world.ensure_family("neighbor","Violet")
	var lot: Dictionary=session.state.lots.lot_1
	_command({"type":"build_begin"})
	_command({"type":"place","kind":"floor","x":8,"y":14})
	_command({"type":"place","kind":"plant","x":8,"y":14})
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _button(game.catalog_buttons.plant)
	var before: Dictionary=session.world.snapshot()
	await _button(game.space_button)
	assert(not session.last_action_ok and game._space_request.is_empty() and session.world.snapshot()==before,"A blocked entrance cannot move part of the household")
	await _button(game.undo_button)
	await _tile(7,7,false); await _capture("blocked-placement")
	assert(game.lot_view.preview_result.ok,"Residents do not block a build preview")
	before=session.world.snapshot(); var control: Button=game.space_button
	await _button(control)
	assert(game.space_button==control and game._space_request.is_empty() and control.has_focus(),"Moving aside preserves the control, focus, and selected tool")
	assert(session.world.snapshot().lots==before.lots and session.world.snapshot().families.neighbor==before.families.neighbor)
	var positions: Array=[]
	for resident: Dictionary in session.state.families[session.profile_id].members:
		assert(resident.y>=12 and Vector2i(resident.x,resident.y)!=Vector2i(8,14),"Undo can restore the old entrance furnishing, so that tile stays reserved")
		positions.append([resident.x,resident.y])
	await _tile(7,7,false); await _capture("space-made")
	assert(game.selected_tool=="plant" and game.lot_view.preview_result.ok)
	await _tile(7,7); assert(lot.funds==int(before.lots.lot_1.funds)-45)
	await _button(game.undo_button)
	assert(positions==session.state.families[session.profile_id].members.map(func(resident): return [resident.x,resident.y]))
	assert(lot.funds==before.lots.lot_1.funds)
	# Copy-room selection survives because moving people does not change the draft revision.
	await _button(game.catalog_buttons.copy_room); await _tile(7,7)
	assert(game._copy_source==Vector2i(7,7))
	await _button(game.space_button); assert(game._copy_source==Vector2i(7,7))
	_command({"type":"blueprint_save","source_x":7,"source_y":7,"library_revision":0,"name":"Starter home"})
	game._select_build_tool("saved_rooms"); await process_frame
	await _button(game.library_panel.buttons.room_1.place)
	await _button(game.space_button); await _capture("library")
	assert(game._blueprint_id=="room_1" and game._space_request.is_empty())
	# Correlation and snapshot arrival both matter for the pending button.
	var intent: Dictionary={"type":"construction_space","lot_id":lot.id,"revision":lot.revision,"orders":Space.request(session.state,session.profile_id,lot.id).orders}
	game._space_request=intent.duplicate(true); game._space_ack=false; game._refresh(); assert(game.space_button.disabled)
	var unrelated:=intent.duplicate(true); unrelated.revision-=1
	game._space_completed(unrelated,false,""); assert(not game._space_request.is_empty())
	game._space_completed(intent,true,""); assert(not game._space_request.is_empty())
	game._space_completed(intent,false,""); assert(game._space_request.is_empty() and not game.space_button.disabled)
	await _key(KEY_ESCAPE); game._select_build_tool("floor")
	await _button(game.mode_button)
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	_command({"type":"visit","lot_id":"lot_2","member_id":member.id})
	await _button(game.mode_button)
	var visitor: Dictionary=member.duplicate(true)
	assert(not game.space_button.disabled and game.space_button.tooltip_text.contains("Robin"))
	await _button(game.space_button); assert(member==visitor,"A visiting relative is never recalled by Move family")
	await _button(game.mode_button)
	var housemate: Dictionary=session.state.families[session.profile_id].members[1]
	_command({"type":"visit","lot_id":"lot_2","member_id":housemate.id})
	await _button(game.mode_button); assert(game.space_button.disabled and game.space_button.tooltip_text.contains("Nobody"))
	await _capture("family-away")
	await _button(game.mode_button)
	print("CONSTRUCTION_SPACE_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
