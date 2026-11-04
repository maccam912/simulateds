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
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(pressed[0])

func _point(id: String) -> Vector2:
	for region: Dictionary in game.lot_view._hit_regions:
		if region.target.get("type")!="object" or region.target.get("id")!=id: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		if game.lot_view.hit_target(point).get("id")==id and not game.lot_view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"Furnishing must have a visible click surface"); return Vector2.ZERO

func _tile(x: int,y: int,click: bool=false) -> void: await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/meals-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame; await process_frame

func _setup_neighbor() -> String:
	var family: Dictionary=session.state.families.violet; var lot: Dictionary=session.state.lots[family.home_lot]
	assert(session.world.apply_command("violet",{"type":"move","lot_id":lot.id,"member_id":family.members[1].id,"x":8,"y":14}).ok)
	for tick in range(40): session.world.step(0.1)
	assert(session.world.apply_command("violet",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(session.world.apply_command("violet",{"type":"place","lot_id":lot.id,"kind":"dining_table","x":8,"y":6}).ok)
	var table: Dictionary=lot.objects[-1]
	assert(session.world.apply_command("violet",{"type":"build_end","lot_id":lot.id}).ok)
	assert(session.world.apply_command("violet",{"type":"meal","lot_id":lot.id,"member_id":family.members[0].id,"target_id":table.id,"action":"prepare","recipe":"sandwiches","batch":0}).ok)
	for tick in range(220): session.world.step(0.1)
	assert(table.meal.servings==4); return str(table.id)
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
	var neighbor_id := _setup_neighbor()
	for resident: Dictionary in [member,housemate]: resident.needs.hunger=20; resident.needs.social=20
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.dining_table); await _tile(8,6,true)
	var lot: Dictionary=session.state.lots.lot_1; var table: Dictionary=lot.objects[-1]; var id: String=table.id
	assert(table.kind=="dining_table"); await _capture("building")
	await _button(game.mode_button); await _mouse(_point(id),true); await _capture("choose")
	assert(game._context_page=="meal" and game.meal_panel.buttons.salad.visible and not game.meal_panel.buttons.salad.disabled)
	var tray: Rect2=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.meal_panel.buttons.sandwiches.get_global_rect()) and tray.encloses(game.meal_panel.note.get_global_rect()),"Recipes and payment explanation stay visible")
	await _mouse(game.meal_panel.buttons.sandwiches.get_global_rect().get_center())
	assert(game.meal_panel.preview.recipe=="sandwiches")
	var panel: Control=game.meal_panel
	var intent := {"type":"meal","lot_id":"lot_1","member_id":member.id,"target_id":id,"action":"prepare","recipe":"salad","batch":0}
	panel.pending=intent.duplicate(true); panel._next=int(member.next_action); game._refresh()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated"); assert(not panel.pending.is_empty())
	session.command_completed.emit(intent,true,"Accepted early"); assert(not panel.pending.is_empty() and table.meal.servings==0)
	session.command_completed.emit(intent,false,"The meal changed"); assert(panel.pending.is_empty() and panel.feedback.text=="The meal changed")
	var funds: int=lot.funds
	await _button(panel.buttons.salad); await _button(game.queue_label); await _advance(4); await _capture("preparing")
	assert(member.task.meal_action=="prepare" and lot.funds==funds and game.meal_panel.summary.text=="Preparing garden salad" and game.meal_panel.preview.recipe=="salad" and game.plan_titles[member.task.id].text.contains("salad"))
	await _advance(14); await _capture("served")
	assert(table.meal.servings==4 and lot.funds==funds-12 and game.meal_panel.preview.portions==4)
	tray=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.meal_panel.buttons.eat.get_global_rect()) and tray.encloses(game.meal_panel.buttons.clear.get_global_rect()))
	await _button(game.meal_panel.buttons.eat); await _advance(1)
	await _button(game.family_box.get_child(1)); await _button(game.people_button)
	assert(game.leisure_buttons.has(member.id) and not game.leisure_buttons[member.id].disabled and game.leisure_buttons[member.id].text=="Join meal")
	await _button(game.leisure_buttons[member.id]); await _advance(5); await _capture("together")
	assert(member.action=="Eating together" and housemate.action=="Eating together" and (member.x!=housemate.x or member.y!=housemate.y))
	await _advance(12); assert(table.meal.servings==2 and member.needs.hunger>85 and housemate.needs.hunger>85)
	game.plan_panel.hide(); await _mouse(_point(id),true); await _button(game.meal_panel.buttons.clear); await _capture("cleared")
	assert(table.meal.servings==0 and table.meal.recipe=="" and game.meal_panel.pending.is_empty())
	game._select_lot("lot_2"); await process_frame; await process_frame
	await _mouse(_point(neighbor_id),true); await _capture("visit-first")
	assert(game.meal_panel.buttons.eat.disabled and game.meal_panel.feedback.text.contains("Visit") and not game.meal_panel.buttons.clear.visible)
	await _button(game.visit_button); await _mouse(_point(neighbor_id),true)
	await _button(game.meal_panel.buttons.eat); await _advance(4); await _capture("visiting")
	assert(housemate.task.get("meal_action")=="eat")
	assert(session.world.apply_command("violet",{"type":"build_begin","lot_id":"lot_2"}).ok)
	game._refresh(); await _capture("construction")
	assert(housemate.lot_id=="lot_1" and housemate.task.is_empty())
	# Turn on ordinary household autonomy through Plan and watch served food get used.
	game._select_lot("lot_1"); await process_frame; await process_frame
	await _mouse(_point(id),true); await _button(game.meal_panel.buttons.salad); await _advance(20)
	assert(table.meal.servings==4)
	for resident: Dictionary in [member,housemate]:
		for need: String in resident.needs: resident.needs[need]=100.0
		resident.needs.hunger=20; resident.needs.social=40; resident.idle_clock=2
	await _button(game.queue_label); await _button(game.autonomy_button)
	await _button(game.family_box.get_child(0)); await _button(game.autonomy_button)
	assert(member.autonomy and housemate.autonomy)
	await _advance(4); await _mouse(_point(id),true); await _capture("autonomy")
	assert(member.task.get("automatic",false) and housemate.task.get("automatic",false) and table.meal.servings==2)
	assert(game.meal_panel.note.text.contains("hungry housemates") and game.meal_panel.note.get_global_rect().end.y<=game.tools_box.get_parent().get_global_rect().end.y)
	await _button(game.autonomy_button); assert(not member.autonomy and member.task.is_empty() and table.meal.servings==2)
	await _advance(12); assert(not housemate.task.has("meal_action") and housemate.needs.hunger>85 and table.meal.servings==2)
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait()
	print("MEALS_UI_PASS"); quit()
