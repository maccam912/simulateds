extends SceneTree
## Exercise real HUD callbacks against a local authoritative session.
var game: Control
var session: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		quit(1)

func _run() -> void:
	root.size = Vector2i(1440,900)
	session = root.get_node("Session")
	session.saving_enabled = false
	session.world.initialize()
	session.world.ensure_family(session.profile_id,"Alex")
	session.world.set_online(session.profile_id,true)
	var neighbor_id := "test_neighbor"
	session.world.ensure_family(neighbor_id,"Violet")
	session.world.set_online(neighbor_id,true)
	game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.lot_view.get_global_rect() == Rect2(Vector2.ZERO,Vector2(root.size)),"World fills the viewport behind HUD")
	_check(not game.context_panel.visible and not game.neighborhood_panel.visible,"Live play keeps optional panels closed")
	var world_clicks: Array = []
	game.lot_view.tile_clicked.connect(func(cell): world_clicks.append(cell))
	game.lot_view._layout()
	await _click(game.lot_view.grid_point(8.5,12.5))
	_check(world_clicks.size()==1,"Uncovered world receives mouse input through overlay root")
	await _click(game.mode_button.get_global_rect().get_center())
	_check(world_clicks.size()==1,"HUD button does not send a click into the world")
	_check(session.state.lots.lot_1.building and game.context_panel.visible,"Build button opens overlay catalog")
	game._toggle_build()
	_check(not game.context_panel.visible,"Finishing build closes catalog")
	_check(game.viewed_lot == "lot_1","HUD opens own lot")
	_check(not game.selected_member.is_empty(),"HUD selects a resident")
	game._toggle_build()
	_check(session.state.lots.lot_1.building,"Build button starts construction")
	game.selected_tool = "floor"
	game._tile_clicked(Vector2i(2,6))
	_check(session.state.lots.lot_1.floors.has([2,6]),"Canvas click builds floor")
	game.selected_tool = "plant"
	game._tile_clicked(Vector2i(2,6))
	var object_id := ""
	for item in session.state.lots.lot_1.objects:
		if item.x==2 and item.y==6: object_id=str(item.id)
	_check(not object_id.is_empty(),"Canvas click places furniture")
	game._toggle_build()
	_check(not session.state.lots.lot_1.building,"Finish button commits safe layout")
	game._tile_clicked(Vector2i(2,6))
	_check(session.last_action_ok,"Canvas click queues furniture use")
	game._send({"type":"cancel","member_id":game.selected_member})
	game._chat_with_family()
	_check(session.last_action_ok,"Chat button targets an actual resident")
	game._select_lot("lot_2")
	game._visit()
	_check(game._member().lot_id == "lot_2","Visit button travels with selected member")
	_check(not game.home_button.disabled,"Home button enabled on visit")
	game._go_home()
	_check(game._member().lot_id == "lot_1","Home button returns selected member")
	_check(game.viewed_lot == "lot_1","Home action changes view")
	game._toggle_build()
	game.selected_tool="floor"
	game._tile_clicked(Vector2i(2,7))
	game._send({"type":"build_cancel","lot_id":"lot_1"})
	_check(not session.state.lots.lot_1.floors.has([2,7]),"Discard button rolls draft back")
	session.set_display_name("Alexandra")
	game._refresh()
	_check(game._member().name=="Alexandra","Name field can rename existing household")
	game._open_connection()
	_check(game.connection_dialog.visible,"Multiplayer dialog opens")
	game.connection_dialog.hide()
	game._save()
	_check(game.notice_label.text.begins_with("Could not save"),"HUD never falsely claims save success")
	print("UI_FLOW_PASS")
	quit()

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = point
		button.pressed = pressed
		root.push_input(button,true)
		await process_frame
