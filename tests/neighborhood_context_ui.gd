extends SceneTree
var game: Control
var session: Node
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for frame in range(4): await process_frame
func click(button: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(button); await settle()
	assert(button.is_visible_in_tree() and not button.disabled and root.get_visible_rect().encloses(button.get_global_rect()))
	var point := button.get_global_rect().get_center()
	if DisplayServer.get_name()!="headless": root.grab_focus(); Input.warp_mouse(point); await settle()
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	var pressed := [false]; button.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; root.push_input(event,true); await process_frame
	await settle(); assert(pressed[0])
func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/neighbor-context-"+name+suffix+".png")==OK)
func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members:
		member.autonomy=false
		assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":member.id,"lot_id":"lot_1","x":0,"y":0}).ok)
		assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":member.id,"lot_id":"lot_1","x":1,"y":0}).ok)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await settle()
	var before: Dictionary=session.world.snapshot()
	await click(game.neighborhood_button); await click(game.lot_buttons.lot_2)
	assert(session.world.snapshot()==before and game.location_find_button.visible and game.location_find_button.text.contains("Find resident"))
	assert(game.needs_title.text=="Alex is at Clover Cottage" and game.activity_timing.text.contains(game._member().action))
	assert(game.visit_button.disabled and game.visit_button.tooltip_text.contains("Nobody lives"))
	var toilet: Dictionary=session.state.lots.lot_2.objects.filter(func(object): return object.kind=="toilet")[0]
	game._entity_clicked({"type":"object","id":toilet.id}); await settle()
	assert(not session.last_action_ok and session.last_action_message.contains("Nobody lives"))
	await capture("vacant-day")
	await click(game.together_button)
	assert(game.travel_panel.confirm.disabled and game.travel_panel.feedback.text==game.visit_button.tooltip_text)
	await capture("travel")
	game.context_panel.hide(); game.more_panel.hide(); await click(game.location_find_button)
	assert(game.viewed_lot=="lot_1" and not game.location_find_button.visible and session.world.snapshot()==before)
	game._select_lot("lot_2"); session.state.day_minutes=0; game._refresh(); await capture("vacant-night")
	assert(game.needs_panel.get_global_rect().encloses(game.location_find_button.get_global_rect()))
	assert(not game.location_find_button.get_global_rect().intersects(game.mood_button.get_global_rect()))
	before=session.world.snapshot(); game.location_find_button.grab_focus()
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode=KEY_SPACE; event.physical_keycode=KEY_SPACE; event.pressed=down; root.push_input(event,true); await process_frame
	await settle(); assert(game.viewed_lot=="lot_1" and session.world.snapshot()==before)
	# The selected resident can be visiting; recovery follows their real lot and floor.
	session.world.ensure_family("neighbor","Violet"); session.world.set_online("neighbor",true)
	assert(session.world.apply_command(session.profile_id,{"type":"visit","member_id":game.selected_member,"lot_id":"lot_2"}).ok)
	game._select_lot("lot_1"); await settle()
	assert(game.needs_title.text=="Alex is at Willow House" and not game.visit_button.disabled,"Visit also works when viewing home from elsewhere")
	before=session.world.snapshot(); await click(game.location_find_button)
	assert(game.viewed_lot=="lot_2" and session.world.snapshot()==before)
	game._select_lot("lot_3"); session.state.lots.lot_2.name="Willow House with a very long saved name"; game._member().name="Alex with a very long resident name"; game._refresh()
	await capture("long-names")
	assert(game.needs_title.tooltip_text.contains(session.state.lots.lot_2.name) and game.location_find_button.tooltip_text.contains(game._member().name))
	assert(root.get_visible_rect().encloses(game.location_find_button.get_global_rect()))
	print("NEIGHBORHOOD_CONTEXT_UI_PASS")
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait(); quit()
