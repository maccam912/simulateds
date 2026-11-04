extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _hover(cell: Vector2i) -> void:
	var event := InputEventMouseMotion.new()
	event.position=game.lot_view.grid_point(cell.x+0.5,cell.y+0.5)
	root.push_input(event,true)
	await process_frame

func _click(cell: Vector2i) -> void:
	await _hover(cell)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=game.lot_view.grid_point(cell.x+0.5,cell.y+0.5)
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/room-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact:
		suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://build")
	game._toggle_build(); game._select_build_tool("room")
	await process_frame
	assert(game.tools_box.get_parent().size.y>=80,"Room tool keeps the catalog scrollable")
	await _click(Vector2i(0,4)); await _hover(Vector2i(3,8))
	await _capture("preview")
	assert(game.lot_view.preview_result.get("ok",false))
	var rotate := InputEventKey.new(); rotate.keycode=KEY_R; rotate.physical_keycode=KEY_R; rotate.pressed=true
	root.push_input(rotate,true)
	await _capture("door-side")
	assert(game.lot_view.preview_result.get("entrance")==Vector2i(3,6))
	assert(int(game.lot_view.preview_result.cost)==505)
	await _click(Vector2i(3,8))
	assert(game._room_anchor.x<0 and session.state.lots.lot_1.doors.has([3,6]))
	await _capture("built")
	game._build_history(false)
	assert(not session.state.lots.lot_1.floors.has([1,5]) and session.state.lots.lot_1.funds==12000)
	game._build_history(true)
	var bed_id: String=session.state.lots.lot_1.objects[0].id
	game._send({"type":"move_object","lot_id":"lot_1","object_id":bed_id,"x":1,"y":5,"rotation":0})
	assert(session.last_action_ok,"Existing furniture can be moved into the new room")
	game._toggle_build()
	assert(not session.state.lots.lot_1.building,"Room extension remains accessible")
	await _capture("living")
	var member: Dictionary=game._member()
	member.autonomy=false; member.needs.energy=20
	game._interact(bed_id)
	for index in range(250):
		session.world.step(0.1)
		if float(member.task.get("elapsed",0))>0.2: break
	assert(member.task.get("target_id")==bed_id and float(member.task.get("elapsed",0))>0.2,"Resident walks through the new doorway and uses the moved bed")
	game._refresh()
	await _capture("bedroom")
	game._toggle_build(); game._select_build_tool("room")
	await _click(Vector2i(4,4)); await _hover(Vector2i(8,8))
	await _capture("blocked")
	assert(not game.lot_view.preview_result.get("ok",true),"Obstructed edges show a red preview")
	print("ROOM_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
