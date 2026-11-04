extends SceneTree
var app: Control
var session: Node
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/household-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact:
		suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout
	DirAccess.make_dir_recursive_absolute("res://build")
	app.show_game(); session.menu_paused=true
	await process_frame
	await _click(app.game.household_button.get_global_rect().get_center())
	assert(app.page=="household")
	await _capture("editor")
	var editor: Control=app.household_editor
	editor.family_name.text="The Gardeners"; editor.member_names[0].text="Matt"; editor.member_names[1].text="Violet"
	for entry: Dictionary in editor.swatches:
		if (entry.member==0 and ((entry.key=="skin" and entry.choice==4) or (entry.key=="shirt" and entry.choice==6))) or (entry.member==1 and entry.key=="shirt" and entry.choice==3):
			await _click(entry.button.get_global_rect().get_center())
	editor._choose(0,"style",2); editor._choose(1,"style",1)
	assert(editor.hair_controls[0].selected==2 and editor.hair_controls[1].selected==1)
	await _capture("preview")
	assert(app.household_apply.get_global_rect().end.y<=root.size.y-8,"Apply remains on screen")
	for entry: Dictionary in editor.swatches:
		assert(app.menu_panel.get_global_rect().encloses(entry.button.get_global_rect()),"Every palette choice fits the editor")
	await _click(app.household_apply.get_global_rect().get_center())
	assert(app.page=="game" and session.state.families[session.profile_id].members[0].appearance.skin==4)
	session.menu_paused=true
	await _capture("world")
	app.open_pause(); await _capture("pause")
	print("HOUSEHOLD_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
