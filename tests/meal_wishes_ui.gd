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
	assert(root.get_texture().get_image().save_png("res://build/meal-wishes-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame; await process_frame

func _board() -> Dictionary:
	return {"day":1,"round":1,"wishes":[{"id":"homemade","done":false},{"id":"meal_together","done":false},{"id":"story","done":false}],"journal":[]}
func _done(member: Dictionary,id: String) -> bool:
	for wish: Dictionary in member.wishes.wishes:
		if wish.id==id: return bool(wish.done)
	return false
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
		for resident: Dictionary in session.state.families[owner].members:
			resident.autonomy=false; resident.wishes=_board()
			for need: String in resident.needs: resident.needs[need]=100.0
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	var housemate: Dictionary=session.state.families[session.profile_id].members[1]
	assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":housemate.id,"lot_id":"lot_1","x":8,"y":14}).ok)
	for tick in range(40): session.world.step(0.1)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var lot: Dictionary=session.state.lots.lot_1; var funds: int=lot.funds
	game._select_lot("lot_2"); await _button(game.wishes_button); await _capture("find-table")
	assert(game.wish_buttons.homemade.text.contains("Build table") and game.wish_buttons.homemade.tooltip_text.contains("§280"))
	await _button(game.wish_buttons.homemade); await _capture("catalog")
	assert(game.viewed_lot=="lot_1" and lot.building and game.selected_tool=="dining_table" and game.catalog_buttons.keys()==["dining_table"] and lot.funds==funds)
	await _tile(8,6,true); var table: Dictionary=lot.objects[-1]; var id: String=table.id
	assert(table.kind=="dining_table" and lot.funds==funds-280)
	await _button(game.mode_button); await _button(game.wishes_button); await _capture("choose-recipe")
	var before: Dictionary=session.world.snapshot()
	await _button(game.wish_buttons.homemade); await _capture("recipe")
	assert(game._context_page=="meal" and game._selected_object==id and session.world.snapshot()==before,"The wish opens a choice without spending ingredients")
	await _button(game.meal_panel.buttons.salad); await _advance(3)
	assert(not _done(member,"homemade") and lot.funds==funds-280)
	await _button(game.wishes_button); assert(game.wish_buttons.homemade.text.contains("See your table") and not game.wish_buttons.homemade.disabled)
	await _button(game.wish_buttons.homemade); await _advance(17)
	assert(_done(member,"homemade") and table.meal.servings==4 and lot.funds==funds-280-12+40)
	await _button(game.wishes_button); await _capture("cooked")
	assert(game.wish_buttons.homemade.disabled and game.wishes_button.text=="1/3")
	await _button(game.wish_buttons.meal_together); before=session.world.snapshot()
	assert(game._context_page=="meal" and game.meal_panel.buttons.eat.visible and game.meal_panel.note.text.contains("12 min"))
	await _capture("share-rule")
	assert(game.tools_box.get_parent().get_global_rect().encloses(game.meal_panel.note.get_global_rect()),"The shared-wish rule stays visible alongside its meal controls")
	await _button(game.meal_panel.buttons.eat)
	assert(session.state.families.violet.members[0].task.is_empty())
	await _button(game.family_box.get_child(1)); await _button(game.wishes_button); await _button(game.wish_buttons.meal_together)
	await _button(game.meal_panel.buttons.eat); await _advance(6)
	assert(_done(member,"meal_together") and _done(housemate,"meal_together") and lot.funds==funds-280-12+120)
	await _button(game.wishes_button); await _capture("shared")
	assert(game.wish_buttons.meal_together.disabled and game.wishes_button.text=="1/3")
	await _button(game.family_box.get_child(0)); await _button(game.wish_buttons.story); await _advance(25)
	assert(preload("res://game/wishes.gd").completed(member.wishes)==3 and lot.funds==funds-280-12+240)
	await _button(game.wishes_button); await _capture("set-complete")
	assert(game.wishes_button.text=="3/3" and game.wish_buttons.values().all(func(button): return button.disabled))
	var restored: Dictionary=session.world.snapshot(); assert(session.world.restore(JSON.parse_string(JSON.stringify(restored)),true)); game._refresh()
	assert(game.wishes_button.text=="3/3" and session.state.lots.lot_1.funds==funds-280-12+240)
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait()
	print("MEAL_WISHES_UI_PASS"); quit()
