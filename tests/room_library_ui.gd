extends SceneTree
const Copy = preload("res://game/room_copy.gd")
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
	assert(root.get_texture().get_image().save_png("res://build/room-library-"+name+suffix+".png")==OK)

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
	assert(game.save_room_button.disabled)
	await _tile(2,2); await _button(game.save_room_button)
	var panel: VBoxContainer=game.library_panel
	assert(panel.form.visible and panel.submit.disabled and not game.catalog_filters.visible)
	panel.name_input.grab_focus(); panel.name_input.text="Morning room"; panel.name_input.text_changed.emit(panel.name_input.text)
	game._refresh(); await create_timer(0.3).timeout
	assert(game.library_panel==panel and panel.name_input.text=="Morning room" and panel.name_input.has_focus())
	var before: Dictionary=lot.duplicate(true)
	await _button(panel.submit); await _capture("saved")
	assert(session.state.families[session.profile_id].room_library.entries.size()==1 and lot==before)
	assert(panel.pending.is_empty() and panel.submit.disabled and panel.submit.text=="Saved")
	await _button(panel.buttons.room_1.rename)
	panel.name_input.text="Blue morning"; panel.name_input.text_changed.emit(panel.name_input.text)
	await _button(panel.submit)
	assert(session.state.families[session.profile_id].room_library.entries[0].name=="Blue morning")
	# Remove is reviewable; cancel keeps the design.
	await _button(panel.buttons.room_1.remove); assert(panel.submit.text=="Remove design" and panel.form_title.text.contains("Blue morning"))
	await _button(panel.cancel); assert(session.state.families[session.profile_id].room_library.entries.size()==1)
	# The room source can be discarded entirely, then rebuilt from its library recipe.
	_command({"type":"build_cancel"}); _command({"type":"build_begin"}); game._refresh()
	assert(lot.objects.is_empty())
	game._select_build_tool("saved_rooms"); await process_frame; panel=game.library_panel
	await _button(panel.buttons.room_1.place)
	assert(game._blueprint_id=="room_1" and game._copy_source.x<0)
	await _tile(9,6,false); await _capture("preview")
	var plan: Dictionary=game.lot_view.copy_preview.duplicate(true)
	assert(plan.ok and plan.cost==1333,str(plan))
	await _key(KEY_R); await _capture("rotated"); assert(game.build_rotation==1 and game.lot_view.copy_preview.ok)
	await _key(KEY_ESCAPE); assert(game._blueprint_id.is_empty() and game.context_panel.visible)
	await _button(panel.buttons.room_1.place); await _tile(9,6)
	assert(Copy.is_applied(lot,plan) and game._copy_request.is_empty() and game._blueprint_id.is_empty())
	await _button(game.undo_button); assert(lot.objects.is_empty())
	await _button(game.redo_button); assert(Copy.is_applied(lot,plan))
	await _capture("placed")
	# Removing a recipe cannot remove the built copy.
	await _button(panel.buttons.room_1.remove); await _button(panel.submit)
	assert(session.state.families[session.profile_id].room_library.entries.is_empty() and Copy.is_applied(lot,plan))
	await _capture("empty")
	# A foreign completion cannot release a pending library request.
	var intent: Dictionary={"type":"blueprint_save","lot_id":lot.id,"source_x":10,"source_y":8,"revision":lot.revision,"name":"Again","library_revision":3}
	panel.pending=intent.duplicate(true)
	var unrelated:=intent.duplicate(true); unrelated.name="Unrelated"
	panel._completed(unrelated,false,""); assert(not panel.pending.is_empty())
	panel._completed(intent,true,""); assert(not panel.pending.is_empty())
	panel._completed(intent,false,"Rejected"); assert(panel.pending.is_empty())
	panel._cancel_edit()
	# Four long names remain usable in the scroll tray; removing one reveals room capacity.
	for index in range(4):
		_command({"type":"blueprint_save","source_x":10,"source_y":8,"name":"A very comfortable morning room"+str(index),"library_revision":session.state.families[session.profile_id].room_library.revision})
	game._refresh(); await _capture("full")
	assert(panel.buttons.size()==4)
	await _button(panel.buttons.room_5.rename)
	panel.name_input.text="Unsaved name"; panel.name_input.text_changed.emit(panel.name_input.text)
	_command({"type":"blueprint_rename","blueprint_id":"room_2","name":"Changed elsewhere","library_revision":session.state.families[session.profile_id].room_library.revision})
	game._refresh(); assert(panel.name_input.text=="Unsaved name" and panel.submit.disabled and panel.feedback.text.contains("library changed"))
	await _button(panel.cancel); await _button(panel.buttons.room_5.rename)
	panel.name_input.text="Compact room"; panel.name_input.text_changed.emit(panel.name_input.text)
	await _button(panel.submit)
	assert(session.state.families[session.profile_id].room_library.entries[-1].name=="Compact room")
	await _button(panel.buttons.room_5.remove); await _button(panel.submit)
	assert(panel.buttons.size()==3)
	await _button(game.mode_button); assert(not lot.building)
	await _capture("live")
	print("ROOM_LIBRARY_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
