extends SceneTree
const Windows = preload("res://game/windows.gd")
const BuildCatalog = preload("res://game/build_catalog.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2,click: bool=false) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame

func _button(button: Button) -> void:
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(button.get_global_rect()),"Window controls fit the viewport")
	var pressed := [false]; button.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center(),true)
	assert(pressed[0])

func _key(code: Key,control: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.ctrl_pressed=control
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _wall(x: int,y: int,click: bool=true) -> void:
	# Sample the actual projected wall face, above its floor tile. This catches
	# selecting the underlying tile when a raised wall owns the visible pixel.
	var lot: Dictionary=session.state.lots.lot_1
	var s: float=game.lot_view._cell.x/48.0
	var point: Vector2=game.lot_view._window_face(x,y,Windows.along_x(lot,x,y),0.5,22*s)
	var hit: Dictionary=game.lot_view.hit_target(point)
	assert(hit.get("type")=="wall" and hit.x==x and hit.y==y,"Visible wall face must pick its actual tile: "+str(hit))
	await _mouse(point,click)

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/windows-"+name+suffix+".png")==OK)

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
	await process_frame; await process_frame; await _capture("starter")
	var lot: Dictionary=session.state.lots.lot_1
	assert(game.lot_view.window_regions.size()==3 and not game.lot_view.window_regions["5,3"].cutaway)
	assert(BuildCatalog.results("structure","shutters")==["window"])
	await _button(game.mode_button); await _button(game.catalog_buttons.window)
	await _capture("palette")
	assert(not game.catalog_filters.visible and game.window_buttons.size()==4)
	await _key(KEY_F,true)
	assert(game.catalog_filters.visible and game.catalog_search.has_focus(),"Catalog search can be opened from the window palette")
	await _button(game.catalog_buttons.window); await _capture("palette-return")
	var region: Rect2=game.tools_box.get_parent().get_global_rect()
	for button: Button in game.window_buttons.values(): assert(region.encloses(button.get_global_rect()),"All three styles and removal fit together")
	var before: Dictionary=session.world.snapshot(); var budget: int=lot.funds
	await _wall(7,3,false); await _capture("cottage-preview")
	assert(game.lot_view.preview_result.ok and game.lot_view.preview_result.cost==60 and game.lot_view.window_regions["7,3"].preview and session.world.snapshot()==before)
	await _wall(7,3)
	assert(Windows.at(lot,7,3)=="cottage" and lot.funds==budget-60 and game._window_request.is_empty())
	before=session.world.snapshot(); await _wall(7,3)
	assert(session.world.snapshot()==before,"Repeated placements do not charge or add history")
	game.window_buttons.picture.grab_focus(); await _key(KEY_ENTER)
	assert(game.window_style=="picture" and game.window_buttons.picture.has_focus())
	await _wall(7,3,false); await _capture("trade-in")
	assert(game.lot_view.preview_result.cost==44 and game.lot_view.preview_result.refund==36)
	assert(game.lot_view.preview_label_rect.has_area())
	for occupied: Rect2 in game.lot_view.overlay_rects: assert(not occupied.intersects(game.lot_view.preview_label_rect),"The whole replacement price remains visible beside the catalog")
	await _wall(7,3); assert(Windows.at(lot,7,3)=="picture" and lot.funds==budget-104)
	await _button(game.undo_button); assert(Windows.at(lot,7,3)=="cottage" and lot.funds==budget-60)
	await _button(game.redo_button); assert(Windows.at(lot,7,3)=="picture" and lot.funds==budget-104)
	await _button(game.window_buttons.shutters)
	await _wall(3,9,false); await _capture("shutters-preview"); await _wall(3,9)
	assert(Windows.at(lot,3,9)=="shutters" and not game.lot_view.window_regions["3,9"].along_x)
	# Near walls rise only while choosing windows, then keep their cutaway sill.
	await _wall(10,11,false); await _capture("near-preview"); await _wall(10,11)
	assert(Windows.at(lot,10,11)=="shutters" and not game.lot_view.window_regions["10,11"].cutaway)
	await _button(game.window_buttons[""]); await _wall(7,3,false); await _capture("remove")
	assert(game.lot_view.preview_result.refund==48)
	await _wall(7,3); assert(Windows.at(lot,7,3).is_empty() and lot.walls.has([7,3]))
	await _button(game.undo_button); assert(Windows.at(lot,7,3)=="picture")
	await _button(game.window_buttons.cottage)
	await _mouse(game.lot_view.grid_point(0.5,13.5),false); await _capture("needs-wall")
	assert(not game.lot_view.preview_result.ok)
	before=session.world.snapshot(); await _mouse(game.lot_view.grid_point(0.5,13.5),true); assert(session.world.snapshot()==before)
	var funds: int=lot.funds; lot.funds=1; game._refresh()
	await _wall(8,3,false); await _capture("over-budget")
	assert(not game.lot_view.preview_result.ok and game.lot_view.preview_result.cost==60)
	before=session.world.snapshot(); await _wall(8,3); assert(session.world.snapshot()==before)
	lot.funds=funds; game._refresh()
	var intent := {"type":"set_window","lot_id":"lot_1","x":8,"y":3,"style":"cottage","revision":lot.revision}
	game._window_request={"intent":intent.duplicate(true),"plan":Windows.inspect(lot,intent)}; game._refresh()
	assert(game.window_buttons.cottage.disabled)
	session.command_completed.emit({"type":"cancel"},false,"Unrelated")
	assert(not game._window_request.is_empty())
	session.command_completed.emit(intent,false,"The draft changed")
	assert(game._window_request.is_empty() and not game.window_buttons.cottage.disabled)
	game._window_request={"intent":intent.duplicate(true),"plan":Windows.inspect(lot,intent)}; game._refresh()
	session.command_completed.emit(intent,true,"Window fitted")
	assert(not game._window_request.is_empty(),"A reply alone does not invent a fitted window")
	assert(session.world.apply_command(session.profile_id,intent).ok); game._refresh()
	assert(game._window_request.is_empty() and Windows.at(lot,8,3)=="cottage")
	await _button(game.access_button); await _capture("access")
	assert(game.lot_view.window_regions["10,11"].cutaway and game._access_report.ok)
	await _button(game.access_button); await _capture("returned")
	assert(not game.lot_view.window_regions["10,11"].cutaway)
	await _button(game.mode_button); await _capture("live")
	assert(game.lot_view.window_regions["10,11"].cutaway and not game.lot_view.window_regions["7,3"].cutaway)
	session.state.day_minutes=1320; game._refresh(); await _capture("night")
	# A replacement client snapshot retains the visible architectural details.
	var saved: Dictionary=session.world.snapshot(); session.world.state=saved; game._refresh(); await _capture("snapshot")
	assert(game.lot_view.window_regions["7,3"].style=="picture" and game.lot_view.window_regions["3,9"].style=="shutters")
	print("WINDOWS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
