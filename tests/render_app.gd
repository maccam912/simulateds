extends SceneTree
var suffix := ""
func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/"+name+suffix+".png")==OK)

func _run() -> void:
	root.size=Vector2i(1280,720) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1440,900)
	if "--large-ui" in OS.get_cmdline_user_args():
		suffix="-large-ui"
		root.get_node("Preferences").set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	var app=load("res://game/app.tscn").instantiate()
	root.add_child(app)
	await _capture("startup")
	await create_timer(0.9).timeout
	await _capture("main-menu")
	app.show_game()
	app.open_pause()
	await _capture("pause-menu")
	app.open_settings()
	await _capture("settings-menu")
	for child in app.menu_content.get_children():
		if child is TabContainer:
			child.current_tab=1
			await _capture("display-settings")
			child.current_tab=3
			await _capture("key-bindings")
	app.open_saves("save")
	app.slot_name.text="Evening at Clover Cottage"
	app._perform_save("")
	await _capture("save-menu")
	app.open_saves("load")
	await _capture("load-menu")
	app.show_game()
	app._open_console()
	app.console.submit_command("help")
	app.console.submit_command("rosebud")
	await _capture("debug-console")
	print("APP_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
