extends SceneTree
const Browse = preload("res://game/build_catalog.gd")
const Catalog = preload("res://game/catalog.gd")
var game: Control
var session: Node
var view: Control
var lot: Dictionary
var suffix := ""

func _initialize() -> void: call_deferred("_run")
func settle(frames: int=5) -> void:
	for frame in range(frames): await process_frame
func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/build-feedback-"+name+suffix+".png")==OK)
func point(cell: Vector2i) -> void:
	var at: Vector2=view.grid_point(cell.x+0.5,cell.y+0.5)
	root.warp_mouse(at)
	var event := InputEventMouseMotion.new(); event.position=at; event.global_position=at
	root.push_input(event,true); await settle()
func click() -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=view._pointer; event.global_position=event.position; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await settle()
func intent(cell: Vector2i) -> Dictionary:
	return {"type":"place","lot_id":"lot_1","level":0,"kind":game.selected_tool,"x":cell.x,"y":cell.y,"rotation":game.build_rotation}

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	var preferences := root.get_node("Preferences")
	preferences.reset_defaults(); preferences.set_value("reduced_motion",true)
	if compact: suffix="-compact"; preferences.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	lot=session.state.lots.lot_1
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await settle(); game._toggle_build(); await settle(100)
	print("BUILD_REVIEW_VIEWPORT ",root.size," logical ",root.get_visible_rect().size," scale ",root.content_scale_factor)
	var scroller: ScrollContainer=game.tools_box.get_parent()
	var visible := 0
	for button: Button in game.catalog_buttons.values():
		if scroller.get_global_rect().encloses(button.get_global_rect()): visible+=1
	assert(visible>=4,"Compact browsing must show at least four complete choices: %d" % visible)
	assert(root.get_visible_rect().encloses(game.undo_button.get_global_rect()))
	assert(game.context_panel.get_global_rect().position.y>=game.clock_panel.get_global_rect().end.y)
	await capture("catalog")
	assert(Browse.results("all","table").slice(0,3)==["table","dining_table","game_table"])
	assert(Browse.results("all","floor")[0]=="floor")
	assert("garden_bed" in Browse.results("all","table"))
	assert(not Browse.match_hint("garden_bed","table").is_empty())
	assert("bookshelf" in Browse.results("all","read"))
	assert(Browse.results("kitchen","read").is_empty())
	var before: Dictionary=session.world.snapshot()
	game._select_build_tool("dining_table"); game.catalog_search.text="floor"; game.catalog_search.text_changed.emit("floor"); await settle()
	assert(game.selected_tool=="dining_table" and "Using:" in game.catalog_detail.text and "table" in game.catalog_detail.text)
	assert("Floor beneath entire footprint" in game.context_box.get_child(1).text)
	assert(session.world.snapshot()==before,"Search and selection cannot order construction")
	await capture("active-search")
	game._clear_catalog_filters(); game.context_panel.hide()
	# Fixture opens clear workspace on the left, leaving the actual starter home visible.
	for y in range(3,12):
		for x in range(0,3):
			if [x,y] not in lot.floors: lot.floors.append([x,y])
	lot.revision+=1; game._refresh(); await settle()
	for entry: Array in [["dining_table",Vector2i(0,4)],["easel",Vector2i(0,7)],["garden_bed",Vector2i(0,10)]]:
		game._select_build_tool(entry[0]); game.context_panel.hide(); await point(entry[1])
		var funds: int=lot.funds; var objects: int=lot.objects.size()
		await click()
		assert(lot.objects.size()==objects+1 and lot.funds==funds-int(Catalog.ITEMS[entry[0]].cost))
		assert(view.placement_confirmed(),"Accepted stationary purchase stays successful")
		assert(view.projection.scene.ghost==null,"No obstruction ghost over accepted purchase")
		view._update_preview(game._view_lot())
		assert(not view.preview_result.ok,"Success presentation never bypasses real occupancy")
		await capture(entry[0]+"-placed")
		await click()
		assert(lot.objects.size()==objects+1 and lot.funds==funds-int(Catalog.ITEMS[entry[0]].cost),"Duplicate click cannot double-charge")
		assert(not view.placement_confirmed() and not session.last_action_ok)
		game._build_history(false); await settle()
		assert(lot.objects.size()==objects and lot.funds==funds)
		await point(entry[1]); await click(); assert(view.placement_confirmed())
		await point(Vector2i(entry[1].x+1,entry[1].y+1))
		assert(not view.placement_confirmed(),"Next pointer destination resumes validation")
		var next_cell := Vector2i(0,8) if entry[0]=="dining_table" else Vector2i(0,9) if entry[0]=="easel" else Vector2i(0,3)
		await point(next_cell); await click()
		assert(view.placement_confirmed() and lot.objects.size()==objects+2)
		assert(lot.funds==funds-2*int(Catalog.ITEMS[entry[0]].cost),"Repeat placement pays exactly once for each accepted destination")
		game._build_history(false); await settle()
		game._build_history(false); await settle()
	# Delayed client acknowledgements cannot paint success at a different target/session.
	game._select_build_tool("easel"); game.context_panel.hide(); await point(Vector2i(0,7))
	var request := intent(Vector2i(0,7))
	view.placement_started(request); await point(Vector2i(1,7)); await point(Vector2i(0,7)); view.placement_completed(request,true)
	assert(not view.placement_confirmed())
	await point(Vector2i(0,7)); view.placement_started(request); view.placement_completed(request,false)
	assert(not view.placement_confirmed())
	view.placement_started(request); session.world_generation+=1; view.placement_completed(request,true)
	assert(not view.placement_confirmed())
	view.placement_started(request); view.placement_completed(request,true)
	assert(view.placement_confirmed(),"Accepted reply can precede its snapshot")
	lot.revision+=1; assert(view.placement_confirmed())
	lot.revision+=1; assert(not view.placement_confirmed(),"A later edit invalidates the old acknowledgement")
	view.placement_started(request); view.placement_completed(request,true)
	game._rotate(); assert(not view.placement_confirmed())
	# Preview real night, then the optional daylight view without advancing state.
	session.state.day_minutes=0; game._refresh(); game._show_tray(game.context_panel,true)
	await point(Vector2i(0,7)); await capture("night")
	before=session.world.snapshot()
	game.build_light_button.button_pressed=true; await settle()
	assert(view.presentation_minutes()==720 and view.projection.scene.sun.light_energy>0.6)
	assert(session.world.snapshot()==before,"Daylight is presentation only")
	await capture("daylight")
	game.build_light_button.button_pressed=false; await settle()
	assert(view.presentation_minutes()==0 and view.projection.scene.sun.light_energy<0.2)
	assert(session.world.snapshot()==before)
	game.build_light_button.button_pressed=true; game._send({"type":"build_cancel","lot_id":"lot_1"}); await settle()
	assert(not view.build_daylight and view.presentation_minutes()==0,"Leaving construction resets preview")
	print("BUILD_FEEDBACK_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
