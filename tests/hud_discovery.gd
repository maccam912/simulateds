extends SceneTree
## Issue #2: discoverable navigation, stable targets and read-only need inspection.
var app: Control
var game: Control
var session: Node
var suffix := ""
var commands: Array=[]

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): push_error("HUD review timed out"); quit(1))
	call_deferred("_run")
func _settle() -> void:
	for frame in range(5): await process_frame

func _click(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await _settle()

func _press(button: Button) -> void:
	assert(root.get_visible_rect().encloses(button.get_global_rect()),button.accessibility_name+" fits on screen")
	await _click(button.get_global_rect().get_center())

func _key(code: int) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await _settle()

func _capture(label: String) -> void:
	await _settle()
	print("HUD capture: "+label)
	if DisplayServer.get_name()=="headless": return
	for control: CanvasItem in app.find_children("*","CanvasItem",true,false): control.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/hud-"+label+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	suffix="-compact" if compact else ""
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.set_physics_process(false); session.saving_enabled=true
	# An actual missing autosave is distinguished from a damaged or returning one.
	assert(session.started_fresh,"Runner must supply a fresh isolated save path")
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout; game=app.game
	assert(root.gui_get_focus_owner().accessibility_name=="Play starter household")
	var before: Dictionary=session.world.snapshot()
	await _capture("first-entry")
	app.open_household(); await _settle()
	assert(app.household_editor.title_label.text=="Customize household" and not app.household_editor.is_dirty())
	app._back(); await _settle()
	assert(session.world.snapshot()==before and session.started_fresh,"Customization can be cancelled without replacing the starter world")
	app.show_game(); app.show_main(); await _settle()
	assert(root.gui_get_focus_owner().accessibility_name=="Continue")
	await _capture("returning")
	app.show_game(); session.saving_enabled=false; await _settle()
	session.command_completed.connect(func(command,_ok,_message): commands.append(command.duplicate(true)))
	var plan_rect: Rect2=game.queue_label.get_global_rect()
	var needs_rect: Rect2=game.needs_toggle.get_global_rect()
	await _press(game.needs_toggle)
	print("HUD: expanded needs")
	assert(game.queue_label.get_global_rect()==plan_rect and game.needs_toggle.get_global_rect()==needs_rect)
	await _click(plan_rect.get_center())
	print("HUD: old plan target")
	assert(game.plan_panel.visible and commands.is_empty() and session.world.snapshot()==before,"Old Plan position remains Plan, never care")
	game.plan_panel.hide(); game.needs_toggle.grab_focus(); await _key(KEY_SPACE)
	print("HUD: keyboard needs")
	assert(game.needs_toggle.has_focus() and game.queue_label.get_global_rect()==plan_rect)
	await _capture("needs")
	await _press(game.need_buttons.hunger)
	assert(commands.is_empty() and session.world.snapshot()==before and game.context_panel.visible)
	assert(game.care_buttons.hunger.has_focus() and "Alex" in game.tools_box.get_child(0).text)
	await _capture("care-review")
	await _press(game.care_buttons.hunger)
	assert(commands.size()==1 and commands[0].type=="care" and commands[0].member_id==game.selected_member)
	assert(session.last_action_ok)
	game.context_panel.hide(); commands.clear()
	var family: Dictionary=game._family()
	for count: int in [2,3,4,8]:
		while family.members.size()<count:
			var resident: Dictionary=family.members[1].duplicate(true)
			resident.id="hud_resident_%d" % family.members.size(); resident.name="Alexandria Longsurname %d" % family.members.size()
			family.members.append(resident)
		family.members[-1].needs.hunger=10.0
		game._refresh(); await _settle()
		assert(root.get_visible_rect().encloses(game.family_panel.get_global_rect()))
		for index in range(mini(4,count)):
			assert(game.family_scroll.get_global_rect().encloses(game.family_box.get_child(index).get_global_rect()),"Four complete roster rows, never a clipped third")
		if count>4: assert("Scroll" in game.family_count.text)
		var last: Button=game.family_box.get_child(count-1)
		game.family_scroll.ensure_control_visible(last); await _settle(); await _press(last)
		assert(game.selected_member==family.members[-1].id and "Very hungry" in last.text)
		last.grab_focus(); game._refresh(); await _settle()
		assert(last.has_focus(),"Snapshot and selection refresh preserve roster focus")
		await _capture("roster-%d" % count)
		game.family_scroll.scroll_vertical=0; await _settle()
	# Reordering rows must retain ID-based selection, including following snapshots.
	family.members.reverse(); game._refresh(); await _settle()
	await _press(game.family_box.get_child(1)); assert(game.selected_member==family.members[1].id)
	await _press(game.more_button)
	assert(game.more_panel.get_global_rect().end.y<game.more_button.get_global_rect().position.y)
	for button: Button in [game.household_button,game.hobbies_button,game.together_button,game.visit_button]:
		assert(not button.text.is_empty() and game.more_panel.get_global_rect().encloses(button.get_global_rect()))
	assert(not game.notice_panel.get_global_rect().intersects(game.more_panel.get_global_rect()))
	await _capture("more")
	prefs.set_value("navigation_labels",false); game._refresh(); await _settle()
	assert(game.household_button.text.is_empty() and game.needs_toggle.text.is_empty() and not game.household_button.accessibility_name.is_empty())
	await _capture("compact-icons")
	prefs.set_value("navigation_labels",true); game._refresh(); game.more_panel.hide()
	for speed: int in [0,1,2,4]:
		session.set_play_speed(speed); game._refresh()
		assert(("Paused" if speed==0 else "%d×" % speed) in game.clock_state.text)
	for role: String in ["host","client","joining"]:
		session.role=role; game._refresh()
		assert("Shared time" in game.clock_state.text and game.time_buttons.values().all(func(button): return button.disabled))
	session.role="offline"; session.state.lots.lot_1.building=true; game._refresh()
	assert("Lot sheltered" in game.clock_state.text)
	session.state.lots.lot_1.building=false; session.state.day_minutes=1320.0; game._refresh(); game.context_panel.hide()
	await _capture("night")
	app.open_pause(); await _settle()
	assert(root.get_visible_rect().encloses(app.menu_panel.get_global_rect()),"Pause menu fits enlarged UI")
	await _capture("pause")
	print("HUD_DISCOVERY_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
