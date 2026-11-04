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
	assert(root.get_texture().get_image().save_png("res://build/garden-overview-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame; await process_frame

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
			resident.autonomy=false
			for wish: Dictionary in resident.wishes.wishes: wish.done=true
	var family: Dictionary=session.state.families[session.profile_id]; var home: Dictionary=session.state.lots[family.home_lot]
	var member: Dictionary=family.members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var before: Dictionary=session.world.snapshot()
	await _button(game.palette_button); await _button(_named(game.tools_box,"Your kitchen garden")); await _capture("empty")
	assert(session.world.snapshot()==before and game.garden_overview_panel.bed_buttons.is_empty())
	await _button(game.garden_overview_panel.meals_button)
	assert(home.building and game.selected_tool=="dining_table")
	await _button(game.space_button); await _tile(8,6,true)
	var table: Dictionary=home.objects[-1]; assert(table.kind=="dining_table")
	await _button(game.mode_button); await _mouse(_point(table.id),true)
	before=session.world.snapshot(); await _button(game.meal_panel.overview_button)
	assert(session.world.snapshot()==before and game._context_page=="garden_overview")
	await _button(game.garden_overview_panel.build_button)
	assert(home.building and game.selected_tool=="garden_bed" and game.catalog_search.text=="garden bed")
	await _tile(5,13,true); var radishes: Dictionary=home.objects[-1]
	await _tile(10,13,true); var tomatoes: Dictionary=home.objects[-1]
	assert(radishes.kind=="garden_bed" and tomatoes.kind=="garden_bed")
	await _button(game.mode_button); await _mouse(_point(table.id),true); await _button(game.meal_panel.overview_button)
	# Snapshot fixtures exercise the overview's crop states; the pantry playtest grows from seeds.
	radishes.garden={"crop":"radish","growth":90.0,"water":0.0,"revision":1,"harvests":0}
	tomatoes.garden={"crop":"tomato","growth":80.0,"water":0.0,"revision":1,"harvests":0}
	family.pantry.radish=8; game._refresh(); await _capture("beds")
	var panel: VBoxContainer=game.garden_overview_panel
	assert(panel.bed_buttons.size()==2 and panel.bed_buttons[radishes.id].text.contains("Ready") and panel.bed_buttons[tomatoes.id].text.contains("Needs water"))
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.bed_buttons[radishes.id].get_global_rect()),"The first actionable bed fits without scrolling")
	before=session.world.snapshot(); await _button(panel.bed_buttons[tomatoes.id]); await _capture("dry-bed")
	assert(session.world.snapshot()==before and game._selected_object==tomatoes.id and game._context_page=="garden")
	await _button(game.garden_panel.buttons.water); await _button(game.garden_panel.overview_button); await _capture("planned")
	panel=game.garden_overview_panel; assert(panel.bed_buttons[tomatoes.id].text.contains("Planned"))
	var button: Button=panel.bed_buttons[tomatoes.id]; button.grab_focus()
	await _advance(12)
	assert(panel.bed_buttons[tomatoes.id]==button and button.has_focus() and button.text.contains("Growing"),"Live progress preserves keyboard focus")
	await _advance(100); assert(button.text.contains("Ready"))
	await _button(panel.bed_buttons[radishes.id]); await _button(game.garden_panel.buttons.keep); await _button(game.garden_panel.overview_button)
	assert(game.garden_overview_panel.bed_buttons[radishes.id].text.contains("Planned"))
	await _advance(14)
	assert(family.pantry.radish==12 and game.garden_overview_panel.bed_buttons[radishes.id].text.contains("Choose seeds"))
	await _button(game.garden_overview_panel.bed_buttons[tomatoes.id]); await _button(game.garden_panel.buttons.keep); await _advance(14)
	await _button(game.garden_panel.overview_button); await _capture("pantry")
	assert(game.tools_box.get_parent().get_global_rect().encloses(game.garden_overview_panel.bed_buttons[tomatoes.id].get_global_rect()),"Both starter beds remain visible when the pantry can make a meal")
	assert(family.pantry.tomato==4 and game.garden_overview_panel.recipe_label.text.contains("2 bowls possible"))
	before=session.world.snapshot(); await _button(game.garden_overview_panel.meals_button)
	assert(session.world.snapshot()==before and game._context_page=="meal" and game.meal_panel.preview.recipe=="homegrown")
	await _button(game.meal_panel.buttons.homegrown); await _button(game.meal_panel.overview_button); await _capture("reserved")
	assert(game.garden_overview_panel.recipe_label.text.contains("1 bowl possible") and game.garden_overview_panel.stock_label.tooltip_text.contains("2 reserved"))
	await _button(game.queue_label); await _button(game.plan_controls[member.task.id].cancel); game.plan_panel.hide()
	assert(game.garden_overview_panel.recipe_label.text.contains("2 bowls possible"))
	# Inspecting home from a visit neither recalls the selected resident nor alters a plan.
	assert(session.world.apply_command(session.profile_id,{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)
	assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":member.id,"lot_id":"lot_2","x":7,"y":14}).ok)
	game._select_lot("lot_2"); await _button(game.palette_button); await _button(_named(game.tools_box,"Your kitchen garden"))
	before=session.world.snapshot(); var selected: String=game.selected_member
	await _button(game.garden_overview_panel.bed_buttons[radishes.id]); await _capture("visiting")
	assert(session.world.snapshot()==before and member.lot_id=="lot_2" and game.viewed_lot==home.id and game.selected_member==selected)
	assert(game.garden_panel.buttons.radish.disabled)
	await _button(game.garden_panel.overview_button)
	panel=game.garden_overview_panel; button=panel.bed_buttons[radishes.id]; button.grab_focus()
	home.objects.erase(radishes); game._refresh(); await process_frame; await process_frame
	assert(not panel.bed_buttons.has(radishes.id) and panel.back_button.has_focus(),"A removed focused bed leaves keyboard focus on a usable control")
	before=session.world.snapshot(); game._open_garden_bed(radishes.id)
	assert(session.world.snapshot()==before and game._context_page=="garden_overview")
	var saved: Dictionary=session.world.snapshot_for_save(); assert(session.world.restore(JSON.parse_string(JSON.stringify(saved)),true))
	session.world_generation+=1; game._refresh(); await _capture("restored")
	assert(game.garden_overview_panel.bed_buttons.size()==1 and game.garden_overview_panel.recipe_label.text.contains("2 bowls possible"))
	print("GARDEN_OVERVIEW_UI_PASS"); await root.get_node("Soundscape").shutdown_and_wait(); quit()
