extends SceneTree
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
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	if game.tools_box.is_ancestor_of(control): assert(game.tools_box.get_parent().get_global_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true)
	assert(pressed[0],"The palette receives actual mouse input")

func _tile(x: int,y: int,click: bool=true) -> void:
	await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _named(title: String) -> Button:
	for button: Button in game.tools_box.find_children("*","Button",true,false):
		if button.text==title: return button
	assert(false,"Missing finish control "+title); return null

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.25).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/room-finish-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.room)
	game.build_rotation=2; game._refresh(); await process_frame
	await _tile(3,11); await _tile(7,15)
	var lot: Dictionary=session.state.lots.lot_1
	assert(lot.doors.has([5,11]) and lot.floors.has([5,13]))
	var objects: Array=lot.objects.duplicate(true); var budget: int=lot.funds
	await _button(game.catalog_buttons.finish_floor)
	assert(game._paint_selection()=="area","The established two-corner workflow stays the default")
	game.finish_buttons.slate.grab_focus(); await _key(KEY_SPACE)
	assert(game.finish_buttons.slate.has_focus() and game.finish_choice.floor=="slate","Keyboard focus follows the chosen swatch")
	game.finish_mode_buttons.room.grab_focus(); await _key(KEY_ENTER)
	assert(game.finish_mode_buttons.room.has_focus() and game._paint_selection()=="room","Keyboard focus follows the selected paint mode")
	var before: Dictionary=session.world.snapshot()
	await _tile(7,7,false); await _capture("preview")
	assert(game.lot_view.preview_result.ok and game.lot_view.preview_result.area.size()==56 and game.lot_view.preview_result.cost==224 and session.world.snapshot()==before)
	var viewport: Rect2=game.tools_box.get_parent().get_global_rect()
	for button: Button in game.finish_buttons.values(): assert(viewport.encloses(button.get_global_rect()),"All six floor finishes fit alongside the selection controls")
	assert("Click to finish a room" in game.help_label.text)
	await _tile(7,7)
	assert(lot.funds==budget-224 and lot.finishes.floor.size()==56 and game._paint_anchor.x<0 and game._paint_request.is_empty())
	before=session.world.snapshot(); await _tile(7,7,false); await _capture("finished")
	assert(game.lot_view.preview_result.reason=="unchanged")
	await _tile(7,7); assert(session.world.snapshot()==before,"A repeated room click neither spends money nor creates an undo step")
	await _button(game.undo_button); assert(lot.finishes.floor.is_empty() and lot.funds==budget)
	await _button(game.redo_button); assert(lot.finishes.floor.size()==56 and lot.funds==budget-224)
	await _button(game.finish_buttons.rose_carpet); await _tile(5,13,false); await _capture("extension-preview")
	assert(game.lot_view.preview_result.area.size()==9 and game.lot_view.preview_result.cost==36)
	await _tile(5,13)
	assert(Finishes.at(lot,"floor",5,13)=="rose_carpet" and Finishes.at(lot,"floor",7,7)=="slate" and Finishes.at(lot,"floor",5,11)=="oak" and lot.objects==objects)
	# Switching modes cancels an unfinished rectangle, and walls remain area-only.
	await _button(game.finish_mode_buttons.area); await _tile(4,12)
	assert(game._paint_anchor==Vector2i(4,12))
	await _button(game.finish_mode_buttons.room); assert(game._paint_anchor.x<0)
	await _button(_named("Walls")); assert(game._paint_selection()=="area" and game.finish_mode_buttons.is_empty())
	await _button(_named("Floors")); assert(game._paint_selection()=="room")
	await _button(game.access_button); await _capture("access")
	assert(game.lot_view._paint_cells.is_empty() and "Choose Door" in game.help_label.text,"Access inspection shows the actual floor and its own instructions")
	await _button(game.access_button)
	await _button(game.finish_buttons.walnut)
	var funds: int=lot.funds; lot.funds=1; game._refresh()
	await _tile(7,7,false); await _capture("over-budget")
	assert(not game.lot_view.preview_result.ok and game.lot_view.preview_result.cost==224 and game.lot_view.preview_result.area.size()==56 and game.lot_view._paint_cells.is_empty())
	before=session.world.snapshot(); await _tile(7,7)
	assert(session.world.snapshot()==before,"The unaffordable room preview cannot partially decorate or spend funds")
	lot.funds=funds; game._refresh()
	await _button(game.mode_button)
	assert(not lot.building and lot.objects==objects)
	await _capture("live")
	print("ROOM_FINISHES_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
