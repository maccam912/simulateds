extends SceneTree
const Tabletop = preload("res://game/tabletop.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _click(control: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(control)
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	var point := control.get_global_rect().get_center()
	assert(root.get_visible_rect().has_point(point))
	if game.tools_box.is_ancestor_of(control): assert(game.tools_box.get_parent().get_global_rect().has_point(point))
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	await process_frame
	var received := [false]; control.pressed.connect(func(): received[0]=true,CONNECT_ONE_SHOT)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	assert(received[0],"The visible People control must receive the click")
	await process_frame

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.25).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/join-game-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	for family: Dictionary in session.state.families.values():
		session.world.set_online(str(family.id),true)
		for resident: Dictionary in family.members: resident.autonomy=false; resident.needs.fun=0.0; resident.needs.social=10.0
	var neighbor: Dictionary=session.state.families.neighbor.members[0]
	var first: Dictionary=session.state.families[session.profile_id].members[0]
	session.world.apply_command("neighbor",{"type":"build_begin","lot_id":"lot_2"})
	assert(session.world.apply_command("neighbor",{"type":"place","lot_id":"lot_2","kind":"game_table","x":8,"y":5}).ok)
	session.world.apply_command("neighbor",{"type":"build_end","lot_id":"lot_2"})
	var table_id := ""
	for object: Dictionary in session.state.lots.lot_2.objects:
		if object.kind=="game_table": table_id=str(object.id)
	assert(session.world.apply_command("neighbor",{"type":"interact","member_id":neighbor.id,"lot_id":"lot_2","target_id":table_id}).ok)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _click(game.people_button)
	game.tools_box.get_parent().ensure_control_visible(game.social_buttons[neighbor.id])
	await _capture("discover")
	assert("1 of 4" in game._leisure_options[neighbor.id].summary and not game.leisure_buttons.has(neighbor.id))
	await _click(game.social_buttons[neighbor.id])
	assert(first.lot_id=="lot_2" and game.viewed_lot=="lot_2" and game.leisure_buttons[neighbor.id].text=="Join game")
	# Keyboard focus survives a replacement snapshot and changing activity status.
	game.leisure_buttons[neighbor.id].grab_focus()
	session.world.step(0.1)
	assert(session.world.restore(JSON.parse_string(JSON.stringify(session.world.snapshot())),true))
	first=session.state.families[session.profile_id].members[0]; neighbor=session.state.families.neighbor.members[0]
	game._refresh(); await process_frame; await process_frame; await process_frame
	assert(game.leisure_buttons[neighbor.id].has_focus())
	await _capture("join")
	# Existing player-directed work remains ahead of the newly joined game.
	session.command({"type":"move","member_id":first.id,"lot_id":"lot_2","x":1,"y":14})
	game._refresh(); await process_frame; await process_frame
	var current: Dictionary=first.task.duplicate(true); var companion: Dictionary=neighbor.duplicate(true)
	game.leisure_buttons[neighbor.id].grab_focus(); await _key(KEY_ENTER)
	assert(first.task==current and first.queue.size()==1 and first.queue[0].target_id==table_id and neighbor==companion)
	assert(game.leisure_buttons[neighbor.id].disabled and game.leisure_buttons[neighbor.id].text=="In your plan")
	assert(game.social_buttons[neighbor.id].has_focus(),"A completed join leaves keyboard focus on the same person's available action")
	await _capture("planned")
	for tick in range(130):
		session.world.step(0.1)
		if first.action=="Playing together": break
	assert(Tabletop.is_shared(session.state,first))
	await _capture("together")
	assert(game.leisure_buttons[neighbor.id].text=="Playing here")
	# A stale rendered card never joins a replacement or vanished game.
	session.command({"type":"cancel","member_id":first.id}); game._refresh()
	var old_activity: String=neighbor.task.id
	session.world.apply_command("neighbor",{"type":"cancel","member_id":neighbor.id})
	game._join_leisure(str(neighbor.id),old_activity,"game_table")
	assert(not session.last_action_ok and first.task.is_empty() and first.queue.is_empty() and not game.leisure_buttons.has(neighbor.id))
	await _capture("finished")
	# A full table offers a deliberate waiting order with a clear label.
	session.world.ensure_family("third","Morgan"); session.world.set_online("third",true)
	for owner: String in ["neighbor","third"]:
		for resident: Dictionary in session.state.families[owner].members:
			resident.autonomy=false; resident.needs.fun=0.0
			if resident.lot_id!="lot_2": session.world.apply_command(owner,{"type":"visit","member_id":resident.id,"lot_id":"lot_2"})
			assert(session.world.apply_command(owner,{"type":"interact","member_id":resident.id,"lot_id":"lot_2","target_id":table_id}).ok)
	game._refresh()
	assert(game.leisure_buttons[neighbor.id].text=="Queue game" and "4 of 4" in game._leisure_options[neighbor.id].summary)
	await _capture("full")
	var card: Control=game.social_buttons[neighbor.id].get_parent().get_parent()
	assert(game.tools_box.get_parent().get_global_rect().grow(1.0).encloses(card.get_global_rect()),"The focused person's name and actions remain visible when their card fits")
	await _click(game.leisure_buttons[neighbor.id])
	assert(first.task.is_empty() and first.queue.size()==1 and first.action.begins_with("Waiting for a place"))
	var pending: String=first.queue[0].id
	session.world.apply_command("third",{"type":"cancel","member_id":session.state.families.third.members[0].id})
	session.world.step(0.1); assert(first.task.id==pending)
	session.world.apply_command("neighbor",{"type":"build_begin","lot_id":"lot_2"}); game._refresh()
	assert(first.lot_id=="lot_1" and game.social_buttons[neighbor.id].disabled)
	await _capture("construction")
	print("JOIN_GAME_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
