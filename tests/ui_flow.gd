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
	await _click(game.queue_label.get_global_rect().get_center())
	_check(game.plan_panel.visible,"Plan opens over the world")
	await _click(game.autonomy_button.get_global_rect().get_center())
	_check(not game._member().autonomy,"Plan autonomy control reaches authoritative resident")
	game._send({"type":"move","member_id":game.selected_member,"lot_id":"lot_1","x":1,"y":1})
	game._send({"type":"move","member_id":game.selected_member,"lot_id":"lot_1","x":2,"y":2})
	await process_frame
	_check(game.plan_box.get_child_count()==2,"Plan displays current and queued actions")
	var remaining_id: String=game._member().task.id
	var remove: Button=game.plan_box.get_child(1).get_child(1)
	await _click(remove.get_global_rect().get_center())
	_check(game._member().queue.is_empty() and game._member().task.id==remaining_id,"Queue row removes only its own action")
	game._toggle_build()
	_check(not game.plan_panel.visible,"Building hides family plan")
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
	await process_frame
	await _click(game.undo_button.get_global_rect().get_center())
	_check(session.world._object(session.state.lots.lot_1,object_id).is_empty(),"Undo button restores prior layout")
	await _click(game.redo_button.get_global_rect().get_center())
	_check(not session.world._object(session.state.lots.lot_1,object_id).is_empty(),"Redo button restores exact purchase")
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
	# Hit the elevated fridge face, not the ground cell behind it.
	session.menu_paused=true
	for resident: Dictionary in game._family().members:
		session.command({"type":"cancel","member_id":resident.id})
	var fridge: Dictionary={}
	for object: Dictionary in session.state.lots.lot_1.objects:
		if object.kind=="fridge": fridge=object
	await process_frame
	await process_frame
	var face: Vector2=game.lot_view.grid_point(float(fridge.x)+0.5,float(fridge.y)+0.5)+Vector2(0,-28)*game.lot_view._cell.x/48.0
	_check(game.lot_view.hit_target(face).get("id")==fridge.id,"Elevated furniture face resolves to visible object")
	await _click(face)
	_check(game._member().task.get("target_id")==fridge.id,"Click on tall furniture queues the visible object")
	var companion: Dictionary=game._family().members[1]
	var body: Vector2=game.lot_view.grid_point(float(companion.x)+0.5,float(companion.y)+0.5)+Vector2(0,-24)*game.lot_view._cell.x/48.0
	await _click(body)
	_check(game.selected_member==companion.id,"Resident body click selects that household member")
	game._toggle_build(); game.selected_tool="erase"; game._refresh()
	await process_frame
	await _click(face)
	_check(session.world._object(session.state.lots.lot_1,str(fridge.id)).is_empty(),"Demolish picks tall furnishing instead of tile behind it")
	game._send({"type":"build_cancel","lot_id":"lot_1"})
	game._toggle_build(); game.selected_tool="move"; game._refresh()
	await process_frame
	await _click(face)
	_check(game._moving_object==fridge.id,"Move tool selects elevated furnishing")
	game._tile_clicked(Vector2i(9,4))
	_check(int(session.world._object(session.state.lots.lot_1,str(fridge.id)).x)==9,"Move click submits free rearrangement")
	_check(game._moving_object.is_empty(),"Accepted move releases selection for another furnishing")
	game._build_history(false)
	_check(int(session.world._object(session.state.lots.lot_1,str(fridge.id)).x)==10,"Move participates in undo")
	game._send({"type":"build_cancel","lot_id":"lot_1"})
	await _click(game.wishes_button.get_global_rect().get_center())
	_check(game.context_panel.visible and game._context_page=="wishes","Wishes opens its overlay")
	for resident: Dictionary in game._family().members: resident.autonomy=false
	var wish_funds: int=session.state.lots.lot_1.funds
	var wish_button: Button=game.tools_box.get_child(0)
	await _click(wish_button.get_global_rect().get_center())
	_check(session.last_action_ok,"Wish card starts a real reachable activity")
	for index in range(350):
		session.world.step(0.1)
		if game._member().task.is_empty() and game._member().queue.is_empty(): break
	game._refresh()
	_check(game.wishes_button.text=="Wishes · 1/3","HUD shows completed wish count")
	_check(session.state.lots.lot_1.funds==wish_funds+40,"Wish UI leads to authoritative reward")
	_check(game.tools_box.get_child(0).disabled,"Completed wish card cannot be repeated")
	game._toggle_build()
	await process_frame
	var room_button: Button=game.tools_box.get_child(1)
	_check("Room" in room_button.text,"Room tool appears in the structure catalog")
	await _click(room_button.get_global_rect().get_center())
	var room_funds: int=session.state.lots.lot_1.funds
	await _click(game.lot_view.grid_point(0.5,0.5))
	_check(game._room_anchor==Vector2i(0,0) and session.state.lots.lot_1.funds==room_funds,"First corner only starts a preview")
	var cancel_room := InputEventKey.new(); cancel_room.keycode=KEY_ESCAPE; cancel_room.pressed=true
	root.push_input(cancel_room,true)
	await process_frame
	_check(game._room_anchor.x<0 and game.context_panel.visible,"Escape cancels the room before closing its catalog")
	await _click(game.lot_view.grid_point(0.5,0.5))
	await _click(game.lot_view.grid_point(2.5,2.5))
	_check(session.state.lots.lot_1.floors.has([1,1]) and session.state.lots.lot_1.doors.has([1,2]),"Second corner builds a room through real canvas input")
	_check(session.state.lots.lot_1.funds==room_funds-373 and game._room_anchor.x<0 and game._room_request.is_empty(),"Accepted room charges once and releases selection")
	await _click(game.undo_button.get_global_rect().get_center())
	_check(not session.state.lots.lot_1.floors.has([1,1]) and session.state.lots.lot_1.funds==room_funds,"One HUD undo reverses the room")
	game._send({"type":"build_cancel","lot_id":"lot_1"})
	game.context_panel.hide()
	await _click(game.people_button.get_global_rect().get_center())
	_check(game.context_panel.visible and game._context_page=="people","People opens the social overlay")
	var neighbor: Dictionary=session.state.families[neighbor_id].members[0]
	game.tools_box.get_parent().ensure_control_visible(game.social_buttons[neighbor.id])
	await process_frame
	await _click(game.social_buttons[neighbor.id].get_global_rect().get_center())
	_check(game._member().lot_id==neighbor.lot_id,"Social card visits the actual resident's lot")
	game.tools_box.get_parent().ensure_control_visible(game.social_buttons[neighbor.id])
	await process_frame
	await _click(game.social_buttons[neighbor.id].get_global_rect().get_center())
	_check(not session.world.chat_status(game._member(),str(neighbor.id)).is_empty(),"Social card directs a real conversation")
	_check(game.social_buttons[neighbor.id].disabled,"A conversation already in the plan cannot be queued again")
	game._go_home(); game.context_panel.hide()
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
