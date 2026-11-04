extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _click(control: Control) -> void:
	await process_frame
	var rect := control.get_global_rect()
	assert(root.get_visible_rect().encloses(rect),"Care control must be fully on screen")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=rect.get_center()
		root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	game._refresh()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/care-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact: suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	var member: Dictionary=game._member()
	member.needs.hunger=12.0; member.needs.energy=23.0; member.needs.hygiene=35.0
	await _capture("low")
	assert("Very hungry" in game.mood_button.text)
	var ground_clicks: Array=[]
	game.lot_view.tile_clicked.connect(func(cell): ground_clicks.append(cell))
	await _click(game.need_buttons.hunger)
	assert(ground_clicks.is_empty() and session.world.task_activity(member.task,"lot_1")=="fridge","Need click queues food without clicking through into the world")
	await _click(game.need_buttons.energy)
	await _click(game.need_buttons.hygiene)
	assert(member.queue.size()==2,"Each need adds to the existing care plan")
	await _click(game.mood_button)
	await _capture("plan")
	assert(game.context_panel.visible and game.care_buttons.hunger.disabled and game.care_buttons.energy.disabled)
	assert(game.care_buttons.energy.text=="In your plan")
	for index in range(1800):
		session.world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): break
	assert(member.task.is_empty() and member.queue.is_empty())
	assert(member.needs.hunger>80 and member.needs.energy>80 and member.needs.hygiene>80)
	await _capture("settled")
	assert("Very hungry" not in game.mood_button.text)
	# A missing object gives a readable suggestion rather than an invisible failed click.
	for object: Dictionary in session.state.lots.lot_1.objects.duplicate():
		if object.kind=="fridge": session.state.lots.lot_1.objects.erase(object)
	await _click(game.need_buttons.hunger)
	await _capture("missing")
	assert("fridge" in game.notice_label.text and game.care_buttons.hunger.disabled)
	game._toggle_build()
	await _capture("building")
	assert(game.need_buttons.hunger.disabled and game.mood_button.disabled)
	print("CARE_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
