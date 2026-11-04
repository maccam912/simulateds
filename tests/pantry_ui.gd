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
	assert(control.is_visible_in_tree(),"Open the tray before clicking "+control.text)
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(pressed[0])

func _named(node: Node,title: String) -> Button:
	if node is Button and node.text==title: return node
	for child in node.get_children():
		var found := _named(child,title)
		if found!=null: return found
	return null

func _point(id: String) -> Vector2:
	for region: Dictionary in game.lot_view._hit_regions:
		if region.target.get("type")!="object" or region.target.get("id")!=id: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		if game.lot_view.hit_target(point).get("id")==id and not game.lot_view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"Furnishing must have a visible click surface"); return Vector2.ZERO

func _tile(x: int,y: int,click: bool=false) -> void: await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/pantry-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame; await process_frame

func _crop(crop: String,bed: Dictionary) -> void:
	await _button(game.garden_panel.buttons[crop]); await _advance(14)
	for turn in range(12):
		if preload("res://game/gardens.gd").ripe(bed.garden): return
		if float(bed.garden.water)<0.1:
			await _button(game.garden_panel.buttons.water); await _advance(9)
		else: await _advance(minf(float(bed.garden.water)+1,60))
	assert(false,"Chosen seeds must grow with watering")

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]; var home: Dictionary=session.state.lots[family.home_lot]
	for resident: Dictionary in family.members:
		resident.autonomy=false
		for wish: Dictionary in resident.wishes.wishes: wish.done=true
	var member: Dictionary=family.members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.garden_bed); await _tile(5,13,true)
	var bed: Dictionary=home.objects[-1]; assert(bed.kind=="garden_bed")
	await _button(game.mode_button); await _mouse(_point(bed.id),true); await _capture("empty")
	assert(game.garden_panel.meals_button.text.begins_with("Build a dining table"))
	await _button(game.garden_panel.meals_button)
	assert(home.building and game.selected_tool=="dining_table" and game.catalog_search.text=="dining")
	await _button(game.space_button); await _tile(8,6,true)
	var table: Dictionary=home.objects[-1]; assert(table.kind=="dining_table")
	await _button(game.mode_button); await _mouse(_point(bed.id),true)
	await _button(game.garden_panel.meals_button); await _capture("empty-pantry")
	assert(game.meal_panel.buttons.homegrown.disabled and game.meal_panel.note.text.contains("keep ripe garden crops"))
	assert(game.tools_box.get_parent().get_global_rect().encloses(game.meal_panel.note.get_global_rect()) and not game.meal_panel.feedback.visible,"The empty-pantry explanation stays beside the recipes")
	var wishes: Dictionary=member.wishes.duplicate(true)
	member.wishes.wishes=[{"id":"homemade","done":false},{"id":"story","done":true},{"id":"rest","done":true}]
	game._refresh(); await process_frame; await process_frame
	assert(game.meal_panel.note.text.contains("Reward") and game.tools_box.get_parent().get_global_rect().encloses(game.meal_panel.note.get_global_rect()),"The garden hint preserves the cooking wish")
	member.wishes=wishes; game._refresh()
	await _mouse(_point(bed.id),true)
	await _crop("radish",bed); await _capture("harvest-choice")
	var tray: Rect2=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.garden_panel.buttons.harvest.get_global_rect()) and tray.encloses(game.garden_panel.buttons.keep.get_global_rect()),"Both harvest choices stay visible")
	assert(game.garden_panel.buttons.harvest.visible and game.garden_panel.buttons.keep.visible)
	var funds: int=home.funds
	await _button(game.garden_panel.buttons.keep); await _advance(10)
	assert(family.pantry.radish==4 and home.funds==funds)
	await _crop("tomato",bed); funds=home.funds
	await _button(game.garden_panel.buttons.keep); await _advance(10)
	assert(family.pantry=={"radish":4,"tomato":4} and home.funds==funds)
	session.state.day_minutes=480.0
	var before: Dictionary=session.world.snapshot()
	await _button(game.garden_panel.meals_button); await _capture("recipe")
	assert(session.world.snapshot()==before and game._context_page=="meal" and game.meal_panel.preview.recipe=="homegrown","Pantry navigation only opens the recipe list")
	tray=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.meal_panel.buttons.homegrown.get_global_rect()) and tray.encloses(game.meal_panel.note.get_global_rect()),"Every recipe and ingredient explanation stays visible")
	await _button(game.meal_panel.buttons.homegrown)
	assert(family.pantry.radish==4 and game.meal_panel.pantry_label.text.contains("2 radishes"))
	await _button(game.queue_label)
	await _button(game.plan_controls[member.task.id].cancel)
	assert(family.pantry.radish==4 and preload("res://game/pantry.gd").stock(session.state,session.profile_id).radish.reserved==0)
	game.plan_panel.hide(); await _button(game.meal_panel.buttons.homegrown)
	for tick in range(250):
		await _advance(0.1)
		if member.task.get("meal_phase")=="serve": break
	assert(member.task.get("meal_phase")=="serve" and family.pantry.radish==4)
	await _capture("carrying"); await _advance(10)
	assert(table.meal.servings==4 and family.pantry=={"radish":2,"tomato":2} and home.funds==funds)
	await _capture("served")
	for resident: Dictionary in family.members: resident.needs.hunger=20; resident.needs.social=20
	await _button(game.meal_panel.buttons.call); await _advance(4); await _capture("family-meal")
	assert(family.members.all(func(resident): return resident.action=="Eating together"))
	await _advance(15)
	assert(table.meal.servings==2 and family.members.all(func(resident): return resident.needs.hunger>90) and family.pantry=={"radish":2,"tomato":2})
	var saved: Dictionary=session.world.snapshot_for_save(); assert(session.world.restore(JSON.parse_string(JSON.stringify(saved))))
	game._refresh(); await _capture("leftovers")
	assert(session.state.families[session.profile_id].pantry==family.pantry)
	print("PANTRY_UI_PASS"); await root.get_node("Soundscape").shutdown_and_wait(); quit()
