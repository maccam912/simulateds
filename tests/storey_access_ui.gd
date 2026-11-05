extends SceneTree
var game: Control
var session: Node
var lot: Dictionary
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for frame in range(8): await process_frame
func click(button: Button) -> void:
	await settle()
	assert(button.is_visible_in_tree() and not button.disabled and root.get_visible_rect().encloses(button.get_global_rect()))
	var title := button.text
	var point := button.get_global_rect().get_center()
	root.warp_mouse(point)
	var activated := [false]; button.pressed.connect(func(): activated[0]=true,CONNECT_ONE_SHOT)
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await settle()
	assert(activated[0],"Pointer activates "+title)
func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/storey-"+name+suffix+".png")==OK)
func edit(command: Dictionary) -> void:
	command.lot_id=lot.id; command.revision=lot.revision
	session.command(command); assert(session.last_action_ok); game._refresh()
func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	lot=session.state.lots.lot_1
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await settle()
	for level in [1,2]:
		await click(game.mode_button)
		var before: Dictionary=session.world.snapshot()
		for step in range(level): await click(game.floor_up)
		assert(session.world.snapshot()==before and game.view_level==level and not game.stair_controls.visible,str([level,game.view_level,session.world.snapshot()==before,game.stair_controls.visible]))
		await click(game.access_button)
		assert(game._access_report.ok and game._access_report.unbuilt and game.access_buttons.is_empty())
		await capture("empty-%d" % level)
		await click(game.mode_button)
		assert(not lot.building and game.view_level==0 and game.lot_title.text.begins_with("Floor 1"))
		assert(not game.lot_view.world.families[session.profile_id].members.is_empty())
	await click(game.mode_button)
	edit({"type":"place_area","kind":"floor","level":1,"x":4,"y":3,"end_x":10,"end_y":9})
	await click(game.mode_button)
	assert(lot.building and game._context_page=="access" and not game._access_report.ok)
	var issue: Dictionary=game._access_report.issues[0]
	await click(game.access_buttons[issue.key])
	assert(game.view_level==1 and game._context_page=="access" and game.lot_view.access_focus==issue.key)
	await capture("missing-stairs")
	edit({"type":"place","kind":"stairs","x":8,"y":4})
	assert(game._access_report.ok)
	# Finish from a built upper floor; then view and order travel separately.
	await click(game.mode_button); assert(game.view_level==0)
	await click(game.palette_button)
	var before: Dictionary=session.world.snapshot()
	await click(game.floor_up)
	assert(game.view_level==1 and session.world.snapshot()==before)
	assert(game.stair_controls.visible and not game.stair_up.disabled and game.stair_down.disabled)
	assert("Floor 1" in game.stair_caption.text and "Floor 2" in game.floor_caption.text)
	session.state.day_minutes=720; game._refresh(); await capture("view-day")
	session.state.day_minutes=0; game._refresh(); await capture("view-night")
	await click(game.stair_up)
	assert(session.last_action_ok and session.world.snapshot()!=before)
	for step in range(160): session.world.step(0.22)
	game._refresh(); assert(game._member().level==1)
	await click(game.mode_button); game._set_view_level(2)
	edit({"type":"build_cancel"})
	assert(game.view_level==1 and not lot.building,"Discard restores the selected resident’s upstairs view")
	game._set_view_level(2); game._find_resident(); await settle()
	assert(game.view_level==1 and game.lot_title.text.begins_with("Floor 2"))
	game._select_lot("lot_2"); game._set_view_level(1); game._show_tray(game.context_panel,true); await settle()
	assert(game.stair_up.disabled and game.stair_down.disabled and "visit" in game.stair_up.tooltip_text)
	# A replacement save owns its camera context even if the old world was building.
	game._last_build_mode=true; game._applied_solo_view=-1
	session.solo_view={"member":game.selected_member,"lot":"lot_2","level":0}
	session.solo_view_generation=session.world_generation
	game._refresh()
	assert(game.viewed_lot=="lot_2" and game.view_level==0,"Loading preserves saved view instead of invoking Finish camera return")
	# Help is a read-only optional checklist, with no purchase actions.
	var guide: Control=load("res://game/guide_panel.gd").new(); root.add_child(guide)
	before=session.world.snapshot(); guide.tabs.current_tab=1; await settle()
	assert(session.world.snapshot()==before)
	guide.queue_free()
	print("STOREY_ACCESS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
