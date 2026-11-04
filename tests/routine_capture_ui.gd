extends SceneTree
const Routines = preload("res://game/routines.gd")
var game: Control
var panel: Control
var session: Node
var member: Dictionary
var family: Dictionary
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true); await process_frame

func _button(button: Button) -> void:
	await process_frame; await process_frame
	if panel.body.is_ancestor_of(button): panel.scroll.ensure_control_visible(button)
	await process_frame; await process_frame
	assert(not button.disabled and root.get_visible_rect().encloses(button.get_global_rect()))
	var received := [false]; button.pressed.connect(func(): received[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(received[0])

func _key(code: Key,unicode: int=0) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.unicode=unicode if pressed else 0; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _object(kind: String) -> Dictionary:
	for object: Dictionary in session.state.lots.lot_1.objects:
		if object.kind==kind: return object
	return {}

func _furnishing(kind: String) -> void:
	var object := _object(kind)
	var cell: Vector2=game.lot_view.object_point(object,Vector2(0.5,0.5))
	var center: Vector2=game.lot_view.grid_point(cell.x,cell.y)
	for y in range(-55,16,3):
		for x in range(-25,26,3):
			var point := center+Vector2(x,y)
			if game.lot_view.hit_target(point).get("id")==object.id:
				await _mouse(point); assert(session.last_action_ok); return
	assert(false,"No visible point on "+kind)

func _capture(name: String) -> void:
	game._refresh(); await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(game.routine_panel.get_global_rect()))
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/routine-capture-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]; member=family.members[0]
	for resident: Dictionary in family.members:
		resident.autonomy=false
		for need: String in resident.needs: resident.needs[need]=25.0
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); panel=game.routine_editor
	await process_frame; await process_frame
	await _button(game.queue_label); await _button(game.routines_button)
	assert(panel.from_plan_button.disabled and panel.capture_hint.text.contains("Plan some care"))
	await _capture("empty")
	await _key(KEY_ESCAPE); await _button(game.queue_label)
	# Build the plan through visible furnishings, then copy that same order.
	for kind: String in ["fridge","shower","bookshelf"]: await _furnishing(kind)
	assert(member.task.target_id==_object("fridge").id and member.queue.size()==2)
	await _button(game.queue_label); await _button(game.routines_button)
	assert(not panel.from_plan_button.disabled and panel.capture_hint.text.contains("3 activities"))
	await _capture("ready")
	var before: Dictionary=session.world.snapshot()
	await _button(panel.from_plan_button)
	assert(panel.draft.steps==["fridge","shower","bookshelf"] and panel.name_field.has_focus() and session.world.snapshot()==before)
	assert(panel.draft_source.resident=="Alex" and panel.source_note.text.contains("keep running"))
	for character: String in "My morning": await _key(KEY_A,character.unicode_at(0))
	for tick in range(20): session.world.step(0.1)
	game._refresh(); await process_frame
	assert(panel.draft.steps==["fridge","shower","bookshelf"] and panel.draft.name=="My morning")
	await _button(panel.step_buttons[1].up)
	assert(panel.draft.steps==["shower","fridge","bookshelf"])
	var current: Dictionary=member.duplicate(true)
	await _capture("review"); await _button(panel.save_button)
	assert(member==current and family.routines.entries[2].name=="My morning" and family.routines.entries[2].steps==["shower","fridge","bookshelf"])
	assert(panel.draft.is_empty() and panel.draft_source.is_empty())
	# Mixed orders are copied with explicit omissions, never silently converted.
	session.command({"type":"cancel","member_id":member.id})
	session.command({"type":"move","member_id":member.id,"x":0,"y":0})
	session.command({"type":"interact","member_id":member.id,"target_id":family.members[1].id})
	session.command({"type":"interact","member_id":member.id,"target_id":_object("bookshelf").id})
	game._refresh(); await _button(panel.from_plan_button)
	assert(panel.draft.steps==["bookshelf"] and panel.draft_source.omitted.size()==2)
	panel.scroll.scroll_vertical=1000; await _capture("omitted")
	# Closing/reopening and selecting another resident never rewrites the draft.
	await _button(game.queue_label); await _button(game.family_box.get_child(1)); await _button(game.routines_button)
	assert(panel.draft_source.resident=="Alex" and panel.draft.steps==["bookshelf"] and panel.subtitle.text.contains("Robin"))
	await _button(panel.back_button)
	assert(panel.from_plan_button.disabled and panel.capture_hint.text.contains("Robin"))
	await _key(KEY_ESCAPE); await _button(game.family_box.get_child(0)); await _button(game.routines_button)
	# A nine-activity plan remains editable; choose which three to remove.
	session.command({"type":"cancel","member_id":member.id})
	for index in range(9): session.command({"type":"interact","member_id":member.id,"target_id":_object("table" if index%2==0 else "bookshelf").id})
	game._refresh(); await _button(panel.from_plan_button)
	assert(panel.draft.steps.size()==9 and panel.save_button.disabled)
	panel.scroll.scroll_vertical=1000; await _capture("too-long")
	for index in [0,3,6]: await _button(panel.step_buttons[index].remove)
	assert(panel.draft.steps.size()==6 and not panel.save_button.disabled)
	panel.scroll.ensure_control_visible(panel.name_field); await process_frame; panel.name_field.grab_focus()
	for character: String in "Leisure day": await _key(KEY_A,character.unicode_at(0))
	await _button(panel.save_button)
	assert(family.routines.entries.size()==4 and panel.from_plan_button.disabled and panel.capture_hint.text.contains("All four slots"))
	await _capture("full-library")
	# A real stale response retains the copied draft for review/back navigation.
	await _button(panel.delete_buttons.routine_4); await _button(panel.from_plan_button)
	assert(panel.draft.steps.size()==9)
	for index in [0,0,0]: await _button(panel.step_buttons[index].remove)
	panel.name_field.text="Keep my copy"; panel.name_field.text_changed.emit("Keep my copy")
	session.command({"type":"routine_save","routine_id":"routine_1","revision":family.routines.revision,"name":"Changed elsewhere","steps":["fridge"]})
	var source: Dictionary=panel.draft_source.duplicate(true)
	await _button(panel.save_button)
	assert(panel.draft.name=="Keep my copy" and panel.draft_source==source and panel.pending.is_empty() and panel.status.text.contains("changed"))
	await _capture("stale")
	await _button(panel.back_button)
	assert(panel.draft.is_empty() and panel.draft_source.is_empty())
	print("ROUTINE_CAPTURE_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
