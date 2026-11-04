extends SceneTree
const Routines = preload("res://game/routines.gd")
var game: Control
var panel: Control
var session: Node
var family: Dictionary
var member: Dictionary
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true); await process_frame

func _button(button: Button) -> void:
	if panel.body.is_ancestor_of(button): panel.scroll.ensure_control_visible(button)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(button.get_global_rect()),"Routine control fits the viewport")
	await _click(button.get_global_rect().get_center())

func _key(code: Key,unicode: int=0,target: Viewport=null) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.unicode=unicode if pressed else 0; event.pressed=pressed
		if target is PopupMenu:
			# Native menus handle keys at the window boundary, before viewport input.
			event.window_id=target.get_window_id()
			Input.parse_input_event(event)
		else: root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.15).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/routines-"+name+suffix+".png")==OK)

func _open() -> void:
	await _button(game.queue_label); await _button(game.routines_button); await _capture("library")
	assert(game.routine_panel.visible and not game.plan_panel.visible)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]; member=family.members[0]
	for resident: Dictionary in family.members:
		resident.autonomy=false
		for need: String in resident.needs: resident.needs[need]=30.0
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); panel=game.routine_editor
	DirAccess.make_dir_recursive_absolute("res://build")
	await process_frame; await process_frame
	await _open()
	assert(panel.run_buttons.size()==2 and not panel.run_buttons.routine_1.disabled)
	var before: Dictionary=session.world.snapshot()
	await _click(game.lot_view.grid_point(0.5,14.5)); assert(session.world.snapshot()==before,"Editing routines cannot issue an accidental world order")
	await _button(panel.edit_buttons.routine_1)
	assert(panel.name_field.has_focus())
	panel.name_field.select_all()
	for character: String in "A calmer morning": await _key(KEY_A,character.unicode_at(0))
	assert(panel.draft.name=="A calmer morning" and session.world.snapshot()==before,"Typing edits a local draft, not gameplay shortcuts or saved state")
	await _button(panel.step_buttons[0].down)
	assert(panel.draft.steps==["shower","toilet","fridge"])
	await _button(panel.add_button)
	assert(panel.step_controls.size()==4 and panel.step_controls[3].has_focus())
	# Change the added activity through the real OptionButton keyboard popup.
	await _key(KEY_SPACE)
	var popup: PopupMenu=panel.step_controls[3].get_popup()
	assert(popup.visible)
	for index in range(3): await _key(KEY_UP,0,popup)
	await _key(KEY_ENTER,0,popup)
	assert(panel.draft.steps[3]=="toilet","Popup focused %s; draft %s" % [popup.get_focused_item(),panel.draft.steps])
	await _button(panel.step_buttons[3].remove)
	await _capture("editor")
	await _button(panel.save_button); await _capture("saved")
	assert(panel.draft.is_empty() and panel.pending.is_empty() and family.routines.entries[0].name=="A calmer morning")
	assert(family.routines.entries[0].steps==["shower","toilet","fridge"])
	await _button(panel.run_buttons.routine_1); await _capture("planned")
	assert(member.task.get("routine_id")=="routine_1" and member.queue.size()==2 and panel.run_buttons.routine_1.disabled)
	var count: int=session.actions_received
	await _button(panel.run_buttons.routine_1)
	assert(session.actions_received==count,"In-plan routines do not submit duplicates")
	await _key(KEY_ESCAPE); assert(not game.routine_panel.visible and game.plan_panel.visible and game.routines_button.has_focus())
	await _capture("plan")
	# The editor exposes all six steps with scrollable, keyboard-reachable controls.
	await _button(game.routines_button); await _button(panel.new_button)
	for index in range(5): await _button(panel.add_button)
	assert(panel.step_controls.size()==6 and panel.add_button.disabled)
	await _capture("six-steps")
	await _button(game.queue_label)
	assert(not game.routine_panel.visible and game.plan_panel.visible and panel.draft.steps.size()==6)
	await _button(game.routines_button)
	assert(game.routine_panel.visible and panel.draft.steps.size()==6 and panel.name_field.has_focus(),"Opening another tray preserves the draft for later")
	panel.name_field.grab_focus(); await _key(KEY_ESCAPE)
	assert(panel.draft.is_empty() and game.routine_panel.visible,"Escape from a name field returns to the library without saving")
	assert(family.routines.entries.size()==2)
	# A missing activity explains the whole recipe failure; a recipe can be
	# edited into something useful on the current lot without changing the plan.
	await _button(panel.new_button)
	panel.name_field.text="Games later"; panel.name_field.text_changed.emit("Games later")
	panel.draft.steps=["game_table"]; panel._editor()
	await _button(panel.save_button); await _capture("missing")
	assert(panel.run_buttons.routine_3.disabled and "No reachable" in panel._options.routine_3.detail)
	var active: Dictionary=member.task.duplicate(true); var queued: Array=member.queue.duplicate(true)
	await _button(panel.edit_buttons.routine_3)
	panel.draft.steps=["bookshelf","table"]; panel._editor()
	await _button(panel.save_button); await _button(panel.run_buttons.routine_3); await _capture("appended")
	assert(member.task==active and member.queue.slice(0,2)==queued and member.queue.size()==4)
	await _button(panel.delete_buttons.routine_3); await _capture("removed")
	assert(Routines.find(family.routines,"routine_3").is_empty() and member.queue.size()==4,"Removing a saved recipe leaves its accepted activities in place")
	# Replace the world as a client snapshot would, keeping focused card identity.
	panel.edit_buttons.routine_2.grab_focus()
	session.world.state=session.world.snapshot(); game._refresh(); await _capture("snapshot")
	family=session.state.families[session.profile_id]; member=family.members[0]
	assert(panel.edit_buttons.routine_2.has_focus())
	# A late result for another command must not unlock or discard a pending edit.
	await _button(panel.edit_buttons.routine_2)
	panel.command_requested.disconnect(game._send)
	panel.draft.name="A little evening"; panel.name_field.text=panel.draft.name
	await _button(panel.save_button)
	var intent: Dictionary=panel.pending.duplicate(true)
	assert(not intent.is_empty() and panel.save_button.disabled)
	session.command_completed.emit({"type":"cancel","member_id":member.id},false,"Unrelated result")
	assert(panel.pending==intent and panel.draft.name=="A little evening")
	session.command_completed.emit(intent,false,"The library changed; please review it.")
	assert(panel.pending.is_empty() and not panel.save_button.disabled and panel.draft.name=="A little evening")
	panel.command_requested.connect(game._send)
	await _button(panel.save_button); await _capture("retried")
	assert(Routines.find(family.routines,"routine_2").name=="A little evening")
	# An acknowledgement can arrive before the matching state snapshot. Keep
	# the editor locked until the accepted library is actually available.
	await _button(panel.edit_buttons.routine_2)
	panel.command_requested.disconnect(game._send)
	panel.draft.name="At dusk"; panel.name_field.text=panel.draft.name
	await _button(panel.save_button); intent=panel.pending.duplicate(true)
	session.command_completed.emit(intent,true,"Household routine saved.")
	assert(panel.pending==intent and panel.save_button.disabled and panel.draft.name=="At dusk")
	assert(session.world.apply_command(session.profile_id,intent).ok)
	game._refresh(); await process_frame
	assert(panel.pending.is_empty() and panel.draft.is_empty() and family.routines.entries[1].name=="At dusk")
	panel.command_requested.connect(game._send)
	# A stale edit retains its draft and offers an ordinary Back path to refresh.
	await _button(panel.edit_buttons.routine_2)
	session.command({"type":"routine_save","routine_id":"routine_1","revision":family.routines.revision,"name":"Latest morning","steps":["toilet","fridge"]})
	await _button(panel.save_button); await _capture("stale")
	assert(not panel.draft.is_empty() and panel.pending.is_empty() and "changed" in panel.status.text)
	await _button(panel.back_button); assert(panel.draft.is_empty())
	await _key(KEY_ESCAPE)
	# Running the accepted sequence uses ordinary simulation and completes it.
	for tick in range(1400):
		session.world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): break
	assert(member.task.is_empty() and member.queue.is_empty())
	await _button(game.routines_button); await _capture("available-again")
	assert(not panel.run_buttons.routine_1.disabled)
	print("ROUTINES_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
