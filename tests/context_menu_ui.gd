extends SceneTree
## Real viewport gestures exercise the quiet HUD and contextual command boundary.
var game: Control
var session: Node
var commands: Array[Dictionary]=[]
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, button: int=MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true); await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=button; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _key(code: int, shift: bool=false) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.shift_pressed=shift
		root.push_input(event,true); await process_frame

func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new(); event.index=0; event.position=point; event.pressed=pressed
	root.push_input(event,true); await process_frame

func _click(button: Button) -> void:
	await process_frame
	assert(button.is_visible_in_tree() and not button.disabled,"Control must be available: "+button.text)
	assert(root.get_visible_rect().encloses(button.get_global_rect()),"Control must fit: "+button.text)
	await _mouse(button.get_global_rect().get_center())

func _point(id: String) -> Vector2:
	# Pick a visible portion of the real model, not a guessed floor cell.
	game.lot_view.projection.register_targets()
	for pick: Dictionary in game.lot_view.projection.picks:
		if pick.target.get("id")!=id: continue
		var bounds := Rect2(pick.polygon[0],Vector2.ZERO)
		for point: Vector2 in pick.polygon: bounds=bounds.expand(point)
		for x in range(1,10):
			for y in range(1,10):
				var point := bounds.position+bounds.size*Vector2(float(x)/10.0,float(y)/10.0)
				if game.lot_view.hit_target(point).get("id")==id and game.lot_view._point_available(point): return point
	assert(false,"No exposed model surface for "+id)
	return Vector2.ZERO

func _capture(name: String) -> void:
	game._notice_time=0; game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/context-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	session.command_completed.connect(func(command,ok,_message):
		if ok: commands.append(command.duplicate(true)))
	var family: Dictionary=session.state.families[session.profile_id]
	var member: Dictionary=family.members[0]
	var housemate: Dictionary=family.members[1]
	var lot: Dictionary=session.state.lots[family.home_lot]
	var object: Dictionary={}
	for candidate: Dictionary in lot.objects:
		if candidate.kind=="fridge": object=candidate; break
	assert(not object.is_empty())
	assert(not game.more_panel.visible and not game.needs_details.visible and not game.context_panel.visible,"Ordinary play starts with secondary controls tucked away")
	var before: Dictionary=session.world.snapshot()
	await _capture("quiet-day")
	await _click(game.more_button)
	for control: Control in [game.household_button,game.mail_button,game.palette_button,game.people_button,game.wishes_button,game.hobbies_button]:
		assert(control.is_visible_in_tree() and root.get_visible_rect().encloses(control.get_global_rect()),"More preserves access to "+control.text)
	await _capture("more")
	await _key(KEY_ESCAPE)
	await _click(game.needs_toggle); assert(game.needs_details.visible)
	await _click(game.needs_toggle); assert(not game.needs_details.visible)
	assert(session.world.snapshot()==before and commands.is_empty(),"Inspecting the HUD issues no command")
	await _mouse(_point(str(object.id)),MOUSE_BUTTON_RIGHT)
	assert(game.radial_menu.visible and game.radial_menu.entry_buttons.has("use"))
	assert(session.world.snapshot()==before and commands.is_empty(),"Opening furniture actions is read-only")
	await _capture("furniture-day")
	var pause_requests := [0]; game.pause_requested.connect(func(): pause_requests[0]+=1)
	await _key(KEY_B); assert(not lot.building and game.radial_menu.visible,"Gameplay shortcuts stay inside the open menu")
	await _key(KEY_ESCAPE)
	assert(not game.radial_menu.visible and pause_requests[0]==0,"Escape dismisses only the radial menu")
	await _mouse(_point(str(object.id)),MOUSE_BUTTON_RIGHT)
	await _mouse(game.lot_view.grid_point(8.5,14.5))
	assert(not game.radial_menu.visible and commands.is_empty(),"Outside dismissal cannot walk through the menu")
	await _mouse(_point(str(object.id)),MOUSE_BUTTON_RIGHT)
	await _click(game.radial_menu.entry_buttons.use)
	assert(commands.size()==1 and commands[0].target_id==object.id and member.task.target_id==object.id,"Choosing a furniture action issues exactly one existing command")
	assert(not game.radial_menu.visible)
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":member.id}).ok)
	commands.clear(); game._refresh(); await process_frame
	before=session.world.snapshot()
	# A stale choice is checked again instead of issuing its old order.
	var furnishing_point := _point(str(object.id))
	await _mouse(furnishing_point,MOUSE_BUTTON_RIGHT)
	member.lot_id="lot_2"
	before=session.world.snapshot()
	await _click(game.radial_menu.entry_buttons.use)
	assert(commands.is_empty() and session.world.snapshot()==before and not game.notice_label.text.is_empty(),"Changed eligibility cannot send the reviewed command")
	await _mouse(furnishing_point,MOUSE_BUTTON_RIGHT)
	assert(game.radial_menu.entry_buttons.use.disabled)
	var unavailable_point: Vector2=game.radial_menu.entry_buttons.use.get_global_rect().get_center()
	await _touch(unavailable_point,true); await _touch(unavailable_point,false)
	assert(game.radial_menu.visible and "Visit" in game.radial_menu.subtitle_label.text and commands.is_empty(),"Unavailable touch actions explain why without closing or ordering")
	await _key(KEY_ESCAPE)
	member.lot_id=family.home_lot; game._refresh(); await process_frame
	await _mouse(_point(str(housemate.id)),MOUSE_BUTTON_RIGHT)
	assert(game.radial_menu.entry_buttons.has("chat") and game.radial_menu.entry_buttons.has("select"))
	await _capture("resident-day")
	await _click(game.radial_menu.entry_buttons.__next)
	assert(game.radial_menu.entry_buttons.has("plan") and game.radial_menu.entry_buttons.has("hobbies") and commands.is_empty(),"More keeps every resident option accessible without ordering")
	await _click(game.radial_menu.entry_buttons.__previous)
	await _click(game.radial_menu.entry_buttons.chat)
	assert(commands.size()==1 and commands[0].target_id==housemate.id and member.task.target_id==housemate.id)
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":member.id}).ok)
	commands.clear(); game._refresh(); await process_frame
	before=session.world.snapshot()
	await _mouse(_point(str(housemate.id)),MOUSE_BUTTON_RIGHT)
	await _click(game.radial_menu.entry_buttons.select)
	assert(game.selected_member==housemate.id and session.world.snapshot()==before and commands.is_empty(),"Selection is presentation only")
	await _key(KEY_F10,true)
	assert(game.radial_menu.visible and game.radial_menu.title_label.text==housemate.name,"Shift+F10 offers the selected resident's actions")
	await _key(KEY_F1)
	assert(not game.radial_menu.visible,"The console rescue key remains available")
	await _key(KEY_F10,true)
	await _key(KEY_ESCAPE)
	game.selected_member=str(member.id); game._refresh(); await process_frame
	var touch_point := _point(str(object.id))
	await _touch(touch_point,true)
	await create_timer(0.6).timeout
	assert(game.radial_menu.visible and commands.is_empty(),"A real held touch opens actions without an early order")
	await _touch(touch_point,false)
	assert(game.radial_menu.visible and commands.is_empty(),"Releasing the hold cannot select an action")
	var action_point: Vector2=game.radial_menu.entry_buttons.use.get_global_rect().get_center()
	await _touch(action_point,true); await _touch(action_point,false)
	assert(commands.size()==1 and commands[0].target_id==object.id and not game.radial_menu.visible,"A fresh tap chooses once")
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":member.id}).ok)
	commands.clear(); game._refresh(); await process_frame
	await _touch(touch_point,true); await create_timer(0.6).timeout; await _touch(touch_point,false)
	assert(game.radial_menu.visible and commands.is_empty(),"A second hold works after the first menu closes")
	await _key(KEY_ESCAPE)
	# Loading/reconnecting may reuse IDs. An old wheel must not act on that world.
	await _mouse(_point(str(object.id)),MOUSE_BUTTON_RIGHT)
	before=session.world.snapshot()
	session.world_generation+=1
	game._choose_context_action("use")
	assert(not game.radial_menu.visible and session.world.snapshot()==before and commands.is_empty(),"A replacement world invalidates the reviewed command before the next frame")
	await process_frame
	await _mouse(_point(str(object.id)),MOUSE_BUTTON_RIGHT)
	session.world_generation+=1
	await process_frame; await process_frame
	assert(not game.radial_menu.visible,"World replacement also dismisses idle menus")
	session.state.day_minutes=1320; game._refresh(); await process_frame
	await _capture("quiet-night")
	await _mouse(_point(str(object.id)),MOUSE_BUTTON_RIGHT)
	await _capture("furniture-night")
	for control: Control in game.radial_menu.entry_buttons.values():
		assert(root.get_visible_rect().encloses(control.get_global_rect()),"Every radial choice fits inside the compact view")
	assert(commands.is_empty())
	print("CONTEXT_MENU_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
