extends SceneTree
var app: Control
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _key(code: Key,control: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.ctrl_pressed=control
		root.push_input(event,true); await process_frame
	await process_frame

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.pressed=pressed; event.button_index=MOUSE_BUTTON_LEFT
		root.push_input(event,true); await process_frame
	await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.15).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/clock-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("first_day_guide",false)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.set_physics_process(false); session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for resident: Dictionary in session.state.families[session.profile_id].members: resident.autonomy=false
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout; app.show_game(); game=app.game
	await _capture("normal")
	for button: Button in game.time_buttons.values():
		assert(root.get_visible_rect().encloses(button.get_global_rect()) and game.clock_panel.get_global_rect().encloses(button.get_global_rect()))
	assert(session.debug_speed==1 and "1×" in game.connection_label.text)
	# Exercise the real physics scheduler as well as the deterministic model test.
	session.set_physics_process(true)
	for rate: int in [1,2,4,0]:
		assert(session.set_play_speed(rate).ok)
		var tick: int=session.state.tick
		var start: int=Time.get_ticks_msec()
		await create_timer(0.6).timeout
		var expected: float=(Time.get_ticks_msec()-start)*0.001*10*rate
		assert(absf(float(session.state.tick-tick)-expected)<3,"Real physics advances at the selected pace")
	session.set_physics_process(false); session.set_clock_rate(1)
	await _click(game.time_buttons[4].get_global_rect().get_center()); assert(session.debug_speed==4)
	await _capture("active-hover")
	await _key(KEY_P); assert(session.debug_speed==0 and "Paused" in game.clock_label.tooltip_text)
	var before: Dictionary=session.world.snapshot(); session._advance_simulation(1); assert(session.world.snapshot()==before)
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	# Plan through a real world click while paused, with no need or movement tick.
	var destination: Vector2=game.lot_view.grid_point(8.5,14.5)
	await _click(destination); await _capture("paused-plan")
	assert(member.task.get("type")=="move" and game.lot_view.walking.markers.size()==1)
	before=session.world.snapshot(); await create_timer(0.15).timeout; assert(session.world.snapshot()==before)
	await _key(KEY_ESCAPE); assert(app.page=="pause" and session.debug_speed==0)
	await _key(KEY_ESCAPE); assert(app.page=="game" and session.debug_speed==0 and session.effective_speed()==0)
	await _key(KEY_P); assert(session.debug_speed==4)
	await _key(KEY_2); assert(session.debug_speed==2)
	await _key(KEY_1); assert(session.debug_speed==1)
	await _key(KEY_3); assert(session.debug_speed==4)
	await _capture("fast")
	await _key(KEY_ESCAPE); assert(app.page=="pause" and session.effective_speed()==0 and session.debug_speed==4)
	await _key(KEY_1); assert(session.debug_speed==4,"Gameplay shortcuts cannot leak through menus")
	await _key(KEY_ESCAPE); assert(app.page=="game" and session.effective_speed()==4)
	# Interpolation and activity clocks freeze mid-step, then resume at chosen pace.
	session.world.step(0.3); await process_frame
	await _key(KEY_P)
	var position: Vector2=game.lot_view.motion.position(member)
	var heading: Vector2=game.lot_view.motion.direction(member)
	var activity_time: float=game.lot_view._time
	await create_timer(0.25).timeout
	assert(game.lot_view.motion.position(member)==position and game.lot_view.motion.direction(member)==heading and game.lot_view._time==activity_time)
	var sound: Node=root.get_node("Soundscape")
	assert(not sound._world_active and sound._world_effects.all(func(player): return not player.playing),"A paused world stops household audio without stopping interface feedback")
	await _key(KEY_P); await create_timer(0.25).timeout
	assert(game.lot_view.motion.position(member)==Vector2(member.x,member.y) and game.lot_view._time>activity_time)
	# Native focus activation stays available; time shortcuts avoid text fields.
	game.time_buttons[2].grab_focus(); await _key(KEY_SPACE); assert(session.debug_speed==2)
	await _click(game.mode_button.get_global_rect().get_center()); await _key(KEY_F,true)
	assert(game.catalog_search.has_focus())
	await _key(KEY_P); await _key(KEY_3); assert(session.debug_speed==2)
	game.catalog_search.release_focus(); session.command({"type":"build_cancel","lot_id":"lot_1"}); game.context_panel.hide(); game._refresh()
	# The new bindings are reachable in the scrolling settings pane and apply live.
	app.open_settings("Controls"); await process_frame; await process_frame
	var binding: Button=app.binding_buttons.play_pause
	var scroll: Node=binding.get_parent()
	while not scroll is ScrollContainer: scroll=scroll.get_parent()
	scroll.ensure_control_visible(binding); await process_frame; await process_frame
	assert(scroll.get_global_rect().encloses(binding.get_global_rect()))
	await _click(binding.get_global_rect().get_center()); assert(app.binding_action=="play_pause")
	await _key(KEY_T); assert(prefs.action_label("play_pause")=="T")
	await _capture("bindings")
	app.show_game(); await process_frame
	await _key(KEY_P); assert(session.debug_speed==2)
	await _key(KEY_T); assert(session.debug_speed==0 and "T resumes" in game.connection_label.text and "T" in game.time_buttons[0].tooltip_text)
	# Shared worlds lock all ordinary controls without manufacturing a request.
	for role: String in ["host","joining","client"]:
		session.role=role; session.set_clock_rate(1); game._refresh(); await process_frame
		for button: Button in game.time_buttons.values(): assert(button.disabled and "Shared" in button.tooltip_text)
		before=session.world.snapshot(); await _key(KEY_T); await _key(KEY_3)
		assert(session.debug_speed==1 and session.world.snapshot()==before and session._requests.is_empty())
		await _capture(role)
	session.role="offline"; game._refresh(); await _key(KEY_T); assert(session.debug_speed==0)
	await _capture("returned-solo")
	print("PLAY_CLOCK_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
