extends SceneTree
## Run headlessly for flow coverage and natively for window-manager regressions.
## The release export has a separate built-in smoke check; --script is editor-only.
var app: Control
var prefs: Node
var session: Node
var capture_dir := ""

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)

func _settle() -> void:
	await create_timer(0.8).timeout

func _capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(capture_dir+"/"+label+".png")==OK,"Save native capture")

func _create_neighborhood(guide: bool) -> void:
	app._new_game_menu()
	var create_button: Button
	for node: Node in app.menu_content.get_children():
		if node is CheckButton: node.button_pressed=guide
		if node is Button and node.text=="Create neighborhood": create_button=node
	_check(create_button!=null,"New neighborhood offers Create")
	create_button.pressed.emit()
	await _settle()
	_check(app.page==("guide" if guide else "game"),"Creation opens the chosen destination")
	_check(prefs.values.first_day_guide==guide,"Creation saves the guide choice")
	app.show_game()
	session.menu_paused=true

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir=argument.trim_prefix("--capture-dir=")
	prefs=root.get_node("Preferences"); session=root.get_node("Session")
	_check(prefs.reset_defaults(),"Reset isolated preferences")
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await _settle()
	var native := DisplayServer.get_name()!="headless"
	var modes := [Window.MODE_WINDOWED,Window.MODE_MAXIMIZED,Window.MODE_FULLSCREEN] if native else [Window.MODE_WINDOWED]
	for mode: int in modes:
		if native:
			root.mode=Window.MODE_WINDOWED
			await _settle()
			root.size=Vector2i(1280,720)
			root.mode=mode
			await _settle()
			_check(root.mode==mode,"Native window enters requested mode %d" % mode)
		var size_before := root.size
		var position_before := root.position
		for guide: bool in [false,true]:
			await _create_neighborhood(guide)
			if native: _check(root.mode==mode and root.size==size_before and root.position==position_before,"Creating a neighborhood preserves mode, size and position (%d)" % mode)
		var before: Dictionary=session.world.snapshot()
		for setting: Array in [["music_volume",0.2],["ui_scale",1.25],["navigation_labels",false],["reduced_motion",true],["quality","low"],["vsync",false]]:
			_check(prefs.set_value(setting[0],setting[1]),"Change "+setting[0])
			await process_frame
			if native: _check(root.mode==mode and root.size==size_before and root.position==position_before,"Unrelated setting preserves native window: "+setting[0])
		_check(session.world.snapshot()==before,"Presentation settings preserve the world")
		await _settle()
		await _capture("window-mode-%d" % mode)
		_check(prefs.set_value("navigation_labels",true),"Restore labels")
	# Explicit fullscreen choices must still enter and leave fullscreen.
	if native:
		root.mode=Window.MODE_WINDOWED
		await _settle()
		_check(prefs.set_value("fullscreen",true),"Choose fullscreen")
		await _settle()
		_check(root.mode==Window.MODE_FULLSCREEN,"Fullscreen setting enters fullscreen")
		_check(prefs.set_value("fullscreen",false),"Choose windowed")
		await _settle()
		_check(root.mode==Window.MODE_WINDOWED,"Fullscreen setting returns to windowed")
		root.size=Vector2i(1280,720)
		await _settle()
		for minute: float in [720.0,1320.0]:
			session.state.day_minutes=minute; app.game._refresh()
			await _settle()
			await _capture("compact-day" if minute==720.0 else "compact-night")
	print("WINDOW_PREFERENCES_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
