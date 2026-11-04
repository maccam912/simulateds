extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
	# Keep native enter/exit events aligned with the injected viewport input.
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _button(control: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(control)
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(pressed[0])

func _tile(x: int,y: int,click: bool=false) -> void: await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/meal-call-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame; await process_frame

func _point(id: String) -> Vector2:
	for region: Dictionary in game.lot_view._hit_regions:
		if region.target.get("type")!="object" or region.target.get("id")!=id: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		if game.lot_view.hit_target(point).get("id")==id and not game.lot_view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"Furnishing must have a visible click surface"); return Vector2.ZERO

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=false; session.set_physics_process(false)
	session.world.initialize()
	for owner: String in [session.profile_id,"violet"]:
		session.world.ensure_family(owner,"Alex" if owner==session.profile_id else "Violet"); session.world.set_online(owner,true)
		for resident: Dictionary in session.state.families[owner].members: resident.autonomy=false
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	var housemate: Dictionary=session.state.families[session.profile_id].members[1]
	assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":housemate.id,"lot_id":"lot_1","x":8,"y":14}).ok)
	for tick in range(40): session.world.step(0.1)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.dining_table); await _tile(8,6,true)
	var lot: Dictionary=session.state.lots.lot_1; var table: Dictionary=lot.objects[-1]; var id: String=table.id
	await _button(game.mode_button); await _mouse(_point(id),true); await _button(game.meal_panel.buttons.salad); await _advance(20)
	assert(table.meal.servings==4)
	for resident: Dictionary in [member,housemate]:
		for need: String in resident.needs: resident.needs[need]=100.0
		resident.needs.hunger=20; resident.needs.social=40
	var panel: Control=game.meal_panel
	assert(panel.buttons.call.visible and panel.buttons.call.text=="Call household · 2")
	if DisplayServer.get_name()=="headless": panel.buttons.call.grab_focus()
	await _mouse(panel.buttons.call.get_global_rect().get_center()); await _capture("preview")
	assert(panel.note.text.contains("Alex:") and panel.note.text.contains("Robin:") and panel.note.text.contains("Join now"))
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.note.get_global_rect()),"The household preview stays visible")
	var names: Array=[member.name,housemate.name]
	member.name="Alexandria Longsurname"; housemate.name="Robin Longsurname"
	game._refresh(); await process_frame; await process_frame
	assert(panel.buttons.call.tooltip_text.contains(member.name) and panel.note.text.contains("…"))
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.note.get_global_rect()),"Long names keep the roster inside the compact tray")
	member.name=names[0]; housemate.name=names[1]; game._refresh()
	var foreign: Dictionary=session.state.families.violet.duplicate(true)
	await _button(panel.buttons.call)
	assert(member.task.meal_action=="eat" and housemate.task.meal_action=="eat" and panel.pending.is_empty() and table.meal.servings==4 and session.state.families.violet==foreign)
	await _advance(6); await _capture("together"); assert(member.action=="Eating together" and housemate.action=="Eating together" and table.meal.servings==2)
	await _advance(12)
	# Both automatic diners can be chosen with one call after the last portions are taken.
	for resident: Dictionary in [member,housemate]: resident.autonomy=true; resident.needs.hunger=10; resident.idle_clock=2
	await _advance(3); assert(table.meal.servings==0 and member.task.get("automatic",false) and housemate.task.get("automatic",false))
	await _mouse(_point(id),true); panel=game.meal_panel
	if DisplayServer.get_name()=="headless": panel.buttons.call.grab_focus()
	await _mouse(panel.buttons.call.get_global_rect().get_center()); await _capture("choose-both")
	assert(panel.note.text.contains("Keep current portion"),str([panel.note.text,panel._call_hover,panel.buttons.call.get_global_rect(),panel.get_global_mouse_position()]))
	var option: Dictionary=session.world.meal_call_option(session.profile_id,member.id,lot.id,id)
	var intent := {"type":"meal_call","action":"call","member_id":member.id,"lot_id":lot.id,"target_id":id,"batch":table.meal.batch,"orders":option.orders.duplicate(true)}
	panel.pending=intent.duplicate(true); game._refresh()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated"); assert(not panel.pending.is_empty())
	session.command_completed.emit(intent,true,"Accepted early"); assert(not panel.pending.is_empty())
	member.next_action+=1; game._refresh(); assert(not panel.pending.is_empty(),"A group waits for every participating resident's accepted state")
	member.next_action-=1
	session.command_completed.emit(intent,false,"The plans changed"); assert(panel.pending.is_empty() and panel.feedback.text=="The plans changed")
	var remaining: Array=[member.task.remaining,housemate.task.remaining]
	await _button(panel.buttons.call); assert(not member.task.get("automatic",false) and not housemate.task.get("automatic",false) and [member.task.remaining,housemate.task.remaining]==remaining and table.meal.servings==0 and panel.pending.is_empty())
	for resident: Dictionary in [member,housemate]: resident.autonomy=false
	await _advance(12)
	# An away selection does not stop calling the housemate who is actually at home.
	await _mouse(_point(id),true); await _button(game.meal_panel.buttons.sandwiches); await _advance(22)
	game._select_lot("lot_2"); await process_frame; await process_frame; await _button(game.visit_button)
	game._select_lot("lot_1"); await process_frame; await process_frame; await _mouse(_point(id),true); panel=game.meal_panel
	assert(member.lot_id=="lot_2" and panel.buttons.eat.disabled and panel.buttons.call.text=="Call household · 1")
	if DisplayServer.get_name()=="headless": panel.buttons.call.grab_focus()
	await _mouse(panel.buttons.call.get_global_rect().get_center()); await _capture("away")
	assert(panel.note.text.contains("Away") and panel.note.text.contains("Robin"))
	var away: Dictionary=member.duplicate(true); foreign=session.state.families.violet.duplicate(true)
	await _button(panel.buttons.call)
	assert(member==away and housemate.task.meal_action=="eat" and panel.pending.is_empty() and session.state.families.violet==foreign)
	await _advance(4); assert(table.meal.servings==3)
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait()
	print("MEAL_CALL_UI_PASS"); quit()
