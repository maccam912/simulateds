extends SceneTree
const Copy = preload("res://game/room_copy.gd")
const Finishes = preload("res://game/finishes.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
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
	assert(root.get_texture().get_image().save_png("res://build/room-copy-"+name+suffix+".png")==OK)

func _command(intent: Dictionary) -> void:
	intent.lot_id="lot_1"; intent.revision=session.state.lots.lot_1.revision
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
	var lot: Dictionary=session.state.lots.lot_1
	lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.windows={}; lot.objects=[]; lot.finishes=Finishes.create()
	_command({"type":"build_begin"})
	_command({"type":"build_room","x":0,"y":0,"end_x":3,"end_y":4,"rotation":0})
	_command({"type":"place","kind":"bed","x":1,"y":1})
	_command({"type":"place","kind":"plant","x":2,"y":1})
	_command({"type":"paint","surface":"floor","selection":"room","finish":"blue_carpet","x":2,"y":2})
	_command({"type":"paint","surface":"wall","finish":"sky","x":0,"y":0,"end_x":3,"end_y":4})
	_command({"type":"set_window","style":"shutters","x":0,"y":2})
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _button(game.catalog_buttons.copy_room)
	var before: Dictionary=session.world.snapshot(); var funds: int=lot.funds
	await _tile(2,2,false); await _capture("source")
	assert(game.lot_view.copy_preview.ok and game.lot_view.copy_preview.objects.size()==2 and session.world.snapshot()==before)
	await _tile(2,2); assert(game._copy_source==Vector2i(2,2))
	await _tile(9,6,false)
	for rotation in range(4):
		await _capture("rotation-"+str(rotation))
		var plan: Dictionary=game.lot_view.copy_preview
		assert(plan.ok and plan.cost==1333 and game.build_rotation==rotation,str(plan))
		assert(plan.extent==(Vector2i(5,4) if rotation%2 else Vector2i(4,5)))
		assert(session.world.snapshot()==before,"Selecting and rotating a room cannot change the source or spend money")
		if rotation<3: await _key(KEY_R)
	await _tile(0,0,false); await _capture("occupied")
	assert(not game.lot_view.copy_preview.ok)
	await _tile(0,0); assert(session.world.snapshot()==before and game._copy_source==Vector2i(2,2))
	await _tile(14,11,false); await _capture("outside")
	assert(not game.lot_view.copy_preview.ok)
	await _tile(9,6,false); var placement: Dictionary=game.lot_view.copy_preview.duplicate(true)
	await _tile(9,6)
	assert(Copy.is_applied(lot,placement) and lot.funds==funds-1333 and lot.objects.size()==4)
	assert(game._copy_request.is_empty() and game._copy_source.x<0)
	await _capture("placed")
	await _button(game.undo_button)
	assert(lot.objects==before.lots.lot_1.objects and lot.funds==funds and lot.windows==before.lots.lot_1.windows)
	await _button(game.redo_button); assert(Copy.is_applied(lot,placement) and lot.funds==funds-1333)
	await _tile(2,2); await _key(KEY_ESCAPE)
	assert(game._copy_source.x<0 and game.context_panel.visible,"Escape cancels the selected room before closing the catalog")
	await _tile(2,2); assert(game._copy_source.x>=0)
	_command({"type":"paint","surface":"floor","selection":"room","finish":"walnut","x":2,"y":2})
	game._refresh(); await process_frame
	assert(game._copy_source.x<0,"A changed source must be selected again before copying")
	# An unrelated completion cannot clear a room placement awaiting its snapshot.
	var intent := {"type":"copy_room","lot_id":lot.id,"source_x":2,"source_y":2,"x":9,"y":6,"rotation":3,"revision":lot.revision}
	game._copy_request={"intent":intent.duplicate(),"plan":placement}
	var unrelated := intent.duplicate(); unrelated.x=10
	game._copy_completed(unrelated,false,""); assert(not game._copy_request.is_empty())
	session.last_action_ok=false; game._notice("An unrelated command failed.")
	assert(not game._copy_request.is_empty(),"Only this placement's completion may reject its pending preview")
	session.last_action_ok=true
	game._copy_completed(intent,true,""); assert(not game._copy_request.is_empty(),"Acceptance waits for a newer matching snapshot")
	game._copy_completed(intent,false,""); assert(game._copy_request.is_empty())
	await _button(game.mode_button)
	assert(not lot.building and Copy.is_applied(lot,placement))
	await _capture("live")
	print("ROOM_COPY_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
