extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _click(control: Control, scroll: bool = false) -> void:
	if scroll:
		game.tools_box.get_parent().ensure_control_visible(control)
		await process_frame
	await process_frame
	var rect := control.get_global_rect()
	assert(root.get_visible_rect().encloses(rect),"Hobby control must be fully on screen")
	if scroll: assert(game.tools_box.get_parent().get_global_rect().encloses(rect),"Practice button must be visible within the scrolling tray")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=rect.get_center()
		root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	game._refresh()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/hobbies-"+name+suffix+".png")==OK)

func _finish(member: Dictionary) -> void:
	for index in range(500):
		session.world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): break
	assert(member.task.is_empty() and member.queue.is_empty())
	game._refresh()
	await process_frame

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact: suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for resident: Dictionary in session.state.families[session.profile_id].members: resident.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	var member: Dictionary=game._member()
	var ground_clicks: Array=[]
	game.lot_view.tile_clicked.connect(func(cell): ground_clicks.append(cell))
	await _click(game.hobbies_button)
	await _capture("first")
	assert(game.context_panel.visible and game.hobby_buttons.size()==3)
	await _click(game.hobby_buttons.reading,true)
	assert(ground_clicks.is_empty() and session.world.task_activity(member.task,"lot_1")=="bookshelf")
	assert(game.hobby_buttons.reading.disabled)
	await _finish(member)
	await _capture("practice")
	assert(member.hobbies.reading.sessions==1)
	await _click(game.hobby_buttons.reading,true); await _finish(member)
	await _capture("rank")
	assert("page turner" in game.notice_label.text and member.hobbies.reading.sessions==2)
	assert(not game.hobby_buttons.reading.disabled,"A daily practice cap does not disable reading for pleasure")
	await _click(game.hobby_buttons.gardening,true); await _finish(member)
	await _click(game.hobby_buttons.cooking,true); await _finish(member)
	await _capture("cooking")
	assert(member.hobbies.gardening.sessions==1 and member.hobbies.cooking.sessions==1)
	await _click(game.family_box.get_child(1))
	await _capture("robin")
	assert(game._member().hobbies.reading.sessions==0 and "Robin" in game.activity_label.text)
	# Every entry still names the needed furniture when an activity is missing.
	for object: Dictionary in session.state.lots.lot_1.objects.duplicate():
		if object.kind=="bookshelf": session.state.lots.lot_1.objects.erase(object)
	game.tools_box.get_parent().scroll_vertical=0
	await _capture("missing")
	assert(game.hobby_buttons.reading.disabled and "story shelf" in game.hobby_buttons.reading.tooltip_text.to_lower())
	var escape := InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; root.push_input(escape,true)
	await process_frame
	assert(not game.context_panel.visible,"Escape closes the hobby tray")
	game._toggle_build(); game._refresh()
	assert(game.hobbies_button.disabled)
	print("HOBBIES_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
