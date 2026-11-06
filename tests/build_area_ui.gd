extends SceneTree

const Finishes = preload("res://game/finishes.gd")
var game: Control
var session: Node
var lot: Dictionary
var compact := false

func _initialize() -> void: call_deferred("_run")

func _move(point: Vector2, touch: bool=false) -> void:
	if touch:
		var drag := InputEventScreenDrag.new()
		drag.position=point
		root.push_input(drag,true)
	else:
		if DisplayServer.get_name()!="headless":
			Input.warp_mouse(point)
			await process_frame
		var motion := InputEventMouseMotion.new()
		motion.position=point
		root.push_input(motion,true)
	await process_frame; await process_frame

func _button(point: Vector2, pressed: bool, touch: bool=false) -> void:
	if touch:
		var event := InputEventScreenTouch.new()
		event.position=point; event.pressed=pressed
		root.push_input(event,true)
	else:
		var event := InputEventMouseButton.new()
		event.position=point; event.pressed=pressed; event.button_index=MOUSE_BUTTON_LEFT
		root.push_input(event,true)
	await process_frame; await process_frame

func _cell(x: int,y: int) -> Vector2:
	return game.lot_view.grid_point(x+0.5,y+0.5)

func _begin(first: Vector2,last: Vector2,touch: bool=false) -> void:
	await _move(first)
	await _button(first,true,touch)
	await _move(last,touch)

func _capture(label: String) -> void:
	game._notice_time=0.0
	game._refresh()
	await process_frame
	var view: Control=game.lot_view
	assert(view.preview_label_rect.has_area())
	for rect: Rect2 in view.overlay_rects:
		assert(not rect.intersects(view.preview_label_rect))
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var suffix := "-compact" if compact else ""
	assert(root.get_texture().get_image().save_png("res://build/area-"+label+suffix+".png")==OK)

func _command(type: String,fields: Dictionary={}) -> Dictionary:
	var intent := {"type":type,"lot_id":lot.id,"revision":lot.revision}
	intent.merge(fields,true)
	return session.world.apply_command(session.profile_id,intent)

func _run() -> void:
	compact="--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if DisplayServer.get_name()!="headless": root.grab_focus()
	var prefs := root.get_node("Preferences")
	prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	lot=session.state.lots.lot_1
	assert(_command("build_begin").ok)
	game=load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame; await process_frame
	var view: Control=game.lot_view
	# Pan the right-hand work area clear of the wider catalog before dragging.
	view.center_lot()
	view.pan.x-=120; view._layout()
	await process_frame; await process_frame
	var first := _cell(7,2)
	var last := _cell(10,0)
	var before: Dictionary=session.world.snapshot()
	await _begin(first,last)
	assert(view._area_plan.ok and view._area_plan.cells.size()==12 and view._area_plan.cost==144)
	assert(session.world.snapshot()==before,"Drag preview is read-only.")
	await _button(last,false)
	assert(lot.floors.size()==before.lots.lot_1.floors.size()+12 and lot.funds==before.lots.lot_1.funds-144)
	assert(lot.build_undo==1 and not view.area_pending)
	assert(_command("build_undo").ok and lot.floors==before.lots.lot_1.floors and lot.funds==before.lots.lot_1.funds)
	assert(_command("build_redo").ok and [10,0] in lot.floors)
	game._refresh()
	var front_first := _cell(2,9)
	var front_last := _cell(0,13)
	await _begin(front_first,front_last)
	await _capture("floor")
	await _button(game.mode_button.get_global_rect().get_center(),false)
	# Existing tiles are skipped, and one new click still places one tile.
	await _begin(_cell(8,0),_cell(11,2))
	assert(view._area_plan.cells.size()==3 and view._area_plan.cost==36)
	await _button(_cell(11,2),false)
	await _move(_cell(12,1)); await _button(_cell(12,1),true); await _button(_cell(12,1),false)
	assert([12,1] in lot.floors)
	# Wall outline uses unique perimeter cells. A touch drag follows the same tool.
	assert(_command("place",{"kind":"door","x":8,"y":2}).ok)
	game._select_build_tool("wall")
	session.state.day_minutes=60
	before=session.world.snapshot()
	var touch := DisplayServer.get_name()=="headless"
	await _begin(first,last,touch)
	assert(view._area_plan.ok and view._area_plan.cells.size()==9 and [8,2] not in view._area_plan.cells)
	await _capture("wall-night")
	await _button(last,false,touch)
	assert([8,2] in lot.doors and [8,1] not in lot.walls and [9,1] not in lot.walls)
	assert(lot.walls.size()==before.lots.lot_1.walls.size()+9 and lot.funds==before.lots.lot_1.funds-270)
	# A window on a selected wall and a furnishing partly inside are each sold once.
	var window_cell := [7,2]
	assert(_command("set_window",{"style":"cottage","x":window_cell[0],"y":window_cell[1]}).ok)
	assert(_command("place",{"kind":"garden_bed","x":10,"y":1,"rotation":0}).ok == false,"Wall occupies the proposed bed.")
	assert(_command("place",{"kind":"garden_bed","x":8,"y":1,"rotation":0}).ok)
	var bed: Dictionary=lot.objects[-1]
	game._select_build_tool("erase")
	session.state.day_minutes=480
	var clear_first := _cell(7,1)
	var clear_last := _cell(8,2)
	before=session.world.snapshot()
	await _begin(clear_first,clear_last)
	var refund: int=view._area_plan.refund
	assert(view._area_plan.ok and view._area_plan.furnishings==1 and view._area_plan.windows==1)
	await _button(clear_last,false)
	assert(lot.funds==before.lots.lot_1.funds+refund and [8,2] not in lot.doors and [7,2] not in lot.walls)
	assert(not lot.windows.has("7,2") and lot.windows.has("5,3"))
	assert(session.world._object(lot,bed.id).is_empty() and [9,1] in lot.floors)
	assert(_command("build_undo").ok and lot.objects==before.lots.lot_1.objects and lot.windows==before.lots.lot_1.windows and lot.funds==before.lots.lot_1.funds)
	game._refresh()
	# Escape, a HUD release and a replaced world cancel without a fallback sale.
	before=session.world.snapshot()
	await _begin(_cell(4,8),_cell(6,10))
	await _capture("sell")
	await _button(game.mode_button.get_global_rect().get_center(),false)
	await _begin(clear_first,clear_last)
	var escape := InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape,true)
	await _button(clear_last,false)
	assert(session.world.snapshot()==before,"Escape cancels the drag.")
	await _begin(clear_first,clear_last)
	await _button(game.mode_button.get_global_rect().get_center(),false)
	assert(session.world.snapshot()==before,"Releasing over the HUD cancels the drag.")
	await _begin(clear_first,clear_last)
	session.world_generation+=1
	await _button(clear_last,false)
	assert(session.world.snapshot()==before)
	# Direct commands cannot bypass lot ownership, revision, bounds or budget.
	var floor_area := {"kind":"floor","x":13,"y":0,"end_x":15,"end_y":2}
	session.world.ensure_family("neighbor","Neighbor")
	var foreign := floor_area.duplicate(); foreign.merge({"type":"place_area","lot_id":lot.id,"revision":lot.revision})
	assert(not session.world.apply_command("neighbor",foreign).ok)
	assert(not _command("place_area",{"kind":"floor","x":13,"y":0,"end_x":16,"end_y":2}).ok)
	var funds: int=lot.funds
	lot.funds=1
	before=session.world.snapshot()
	assert(not _command("place_area",floor_area).ok and session.world.snapshot()==before)
	lot.funds=funds
	before=session.world.snapshot()
	assert(not _command("place_area",{"kind":"wall","x":6,"y":1,"end_x":9,"end_y":1}).ok and session.world.snapshot()==before)
	assert(not _command("place_area",{"kind":"floor","x":13,"y":0,"end_x":15,"end_y":2,"revision":lot.revision-1}).ok)
	assert(not _command("erase_area",{"x":7,"y":1,"end_x":8,"end_y":2,"refund":refund+1}).ok and session.world.snapshot()==before)
	# Room and finish tools share the gesture while keeping their existing plans.
	game._select_build_tool("room")
	# The simulated world replacement above applies fresh-world framing.
	view.center_lot(); view.pan.x-=120; view._layout()
	first=_cell(13,3); last=_cell(15,5)
	await _begin(first,last)
	assert(view.preview_result.ok and view.preview_result.width==3)
	await _button(last,false)
	assert([14,5] in lot.doors and [14,4] in lot.floors)
	game._select_build_tool("finish_floor")
	game._select_finish("floor","slate")
	first=_cell(13,4); last=_cell(15,4)
	await _begin(first,last)
	assert(view.preview_result.ok and view.preview_result.cells.size()==3)
	await _button(last,false)
	assert(Finishes.at(lot,"floor",14,4)=="slate")
	print("BUILD_AREA_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
