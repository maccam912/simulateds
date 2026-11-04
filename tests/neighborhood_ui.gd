extends SceneTree
var game: Control
var session: Node
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func _mouse(point: Vector2,click: bool=true) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion:=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; root.push_input(event,true); await process_frame
	await process_frame; await process_frame
func _button(button: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(button)
	await process_frame; await process_frame
	assert(not button.disabled and root.get_visible_rect().encloses(button.get_global_rect()))
	var pressed: Array=[false]; button.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(pressed[0])
func _key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; root.push_input(event,true); await process_frame
	await process_frame; await process_frame
func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/neighborhood-"+name+suffix+".png")==OK)
func _run() -> void:
	var compact:= "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=false
	session.world.initialize()
	for owner: String in [session.profile_id,"violet","cedar"]:
		session.world.ensure_family(owner,"Alex" if owner==session.profile_id else "Violet" if owner=="violet" else "Cedar")
		if owner!="cedar": session.world.set_online(owner,true)
		for resident: Dictionary in session.state.families[owner].members: resident.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var clicks: Array=[]; game.lot_view.tile_clicked.connect(func(cell): clicks.append(cell))
	var before: Dictionary=session.world.snapshot()
	await _button(game.neighborhood_button); await _capture("overview")
	assert(game.neighborhood_panel.visible and game.lot_buttons.size()==4 and session.world.snapshot()==before and clicks.is_empty())
	for card: Control in game.lot_buttons.values():
		assert(game.neighborhood_panel.get_global_rect().encloses(card.get_global_rect()) and root.get_visible_rect().encloses(card.get_global_rect()),"All four homes must fit the open tray")
	assert(game.neighborhood_panel.get_global_rect().end.y<=game.family_box.get_parent().get_global_rect().position.y,"Presence cards must not cover household selection")
	assert(game.lot_buttons.lot_2.status.text=="Owner playing" and game.lot_buttons.lot_3.status.text.contains("Caretaker"))
	assert(game.lot_buttons.lot_4.roster.text=="No household yet")
	var violet: Dictionary=session.state.families.violet.members[0]
	var robin: Dictionary=session.state.families.violet.members[1]
	var card: Control=game.lot_buttons.lot_2; card.grab_focus()
	assert(session.world.apply_command("violet",{"type":"visit","member_id":violet.id,"lot_id":"lot_3"}).ok)
	game._refresh(); await process_frame
	assert(game.lot_buttons.lot_2==card and card.has_focus() and card.roster.text=="1 here · Robin" and card.tooltip_text.contains("Violet · Juniper Place"))
	assert(session.world.apply_command("violet",{"type":"visit","member_id":robin.id,"lot_id":"lot_3"}).ok)
	game._refresh(); await _capture("away-visiting")
	assert(card.has_focus() and card.roster.text=="Nobody here" and card.status.text=="Owner playing")
	assert(game.lot_buttons.lot_3.roster.text.begins_with("4 here") and game.lot_buttons.lot_3.status.text=="Owner away · Guests playing")
	# Keyboard activation only changes the view; it cannot send a resident to a lot.
	before=session.world.snapshot(); await _key(KEY_ENTER)
	assert(game.viewed_lot=="lot_2" and not game.neighborhood_panel.visible and session.world.snapshot()==before and clicks.is_empty())
	session.world.set_online("violet",false); game._refresh(); await _button(game.neighborhood_button); await _capture("caretaker")
	assert(card.roster.text=="2 here · Violet, Robin" and card.status.text.contains("Owner away"))
	session.world.set_online("violet",true)
	# Actual household travel updates both lots from accepted state.
	await _button(game.lot_buttons.lot_2); await _button(game.together_button); await _button(game.travel_panel.confirm)
	game.context_panel.hide(); await _button(game.neighborhood_button); await _capture("visiting")
	assert(game.lot_buttons.lot_1.roster.text=="Nobody here" and card.roster.text=="4 here · Violet, Robin, Alex, Robin")
	assert(card.tooltip_text.contains("Alex household · Visiting"))
	assert(session.world.apply_command("violet",{"type":"build_begin","lot_id":"lot_2"}).ok)
	game._refresh(); await _capture("construction")
	assert(card.status.text=="Under construction · Closed" and card.roster.text.begins_with("2 here") and game.lot_buttons.lot_1.roster.text.begins_with("2 here"))
	before=session.world.snapshot(); await _button(card)
	assert(game.viewed_lot=="lot_2" and game.visit_button.disabled and session.world.snapshot()==before)
	assert(session.world.apply_command("violet",{"type":"build_cancel","lot_id":"lot_2"}).ok)
	session.state.families.violet.name="A household with a very long name"
	violet.name="Violet Longsurname And More"; session.state.lots.lot_2.name="A very long name for Willow House"
	game._refresh(); await _button(game.neighborhood_button); await _capture("long-names")
	assert(card.tooltip_text.contains(violet.name) and card.tooltip_text.contains(session.state.families.violet.name))
	for label: Label in [card.title,card.status,card.roster]: assert(card.get_global_rect().encloses(label.get_global_rect()))
	before=session.world.snapshot(); await _button(game.lot_buttons.lot_4)
	assert(game.viewed_lot=="lot_4" and game.visit_button.disabled and session.world.snapshot()==before)
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait(); print("NEIGHBORHOOD_UI_PASS"); quit()
