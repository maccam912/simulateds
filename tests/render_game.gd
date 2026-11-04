extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720) if compact else Vector2i(1440,900)
	var suffix := "-compact" if compact else ""
	var scene := load("res://game/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build")
	assert(root.get_texture().get_image().save_png("res://build/neighborhood" + suffix + ".png") == OK)
	game._toggle_build()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/construction" + suffix + ".png") == OK)
	game._toggle_build()
	print("GAME_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
