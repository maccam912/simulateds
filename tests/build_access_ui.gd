extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame

func _button(control: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(control)
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _click(control.get_global_rect().get_center())
	assert(pressed[0],"The visible access control receives actual input")

func _named(node: Node, title: String) -> Button:
	if node is Button and (node.text==title or node.accessibility_name==title): return node
	for child in node.get_children():
		var found := _named(child,title)
		if found!=null: return found
	return null

func _key(code: int, ctrl: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.ctrl_pressed=ctrl; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.25).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/access-"+name+suffix+".png")==OK)

func _wall_point() -> Dictionary:
	var view: Control=game.lot_view; view._layout()
	for cell: Vector2i in [Vector2i(5,5),Vector2i(4,6)]:
		for x: float in [0.25,0.5,0.75]:
			for y: float in [0.25,0.5,0.75]:
				var point: Vector2=view.grid_point(cell.x+x,cell.y+y)+Vector2(0,-6*view._cell.x/48.0)
				var target: Dictionary=view.hit_target(point)
				if target.get("type")=="wall" and target.x==cell.x and target.y==cell.y: return {"cell":cell,"point":point}
	assert(false,"At least one repair wall has a visible upper surface")
	return {}

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _button(game.mode_button)
	assert(game.access_button.text=="✓")
	await _button(game.access_button)
	await _key(KEY_ESCAPE)
	assert(not game.context_panel.visible and not game.lot_view.access_visible and not game.lot_view.access_inspecting,"Escape leaves access inspection and restores ordinary building input")
	await _button(game.palette_button); await _button(game.access_button)
	assert(game._context_page=="access" and game.lot_view.access_inspecting and not game.catalog_filters.visible)
	var before: Dictionary=session.world.snapshot()
	await _click(game.lot_view.grid_point(7.5,7.5))
	assert(session.world.snapshot()==before,"Inspecting the home never accidentally places the previously selected furnishing")
	await _capture("clear")
	await _key(KEY_F,true)
	assert(game.catalog_search.has_focus() and game.catalog_filters.visible and game._access_visible,"Catalog search returns to editing while keeping access visible")
	await _button(game.access_button)
	var lot: Dictionary=session.state.lots.lot_1; var bed: Dictionary=lot.objects[0]
	for cell: Vector2i in [Vector2i(5,4),Vector2i(5,5),Vector2i(4,6)]:
		session.command({"type":"place","lot_id":lot.id,"kind":"wall","x":cell.x,"y":cell.y}); assert(session.last_action_ok)
	game._refresh(); await _button(game.access_button)
	assert(not game._access_visible)
	before=session.world.snapshot()
	await _button(game.mode_button)
	assert(not session.last_action_ok and session.world.snapshot()==before and game._context_page=="access" and game.context_panel.visible,"A rejected finish opens the actual access explanation")
	assert(game.access_buttons.size()==1 and game.access_buttons.has("object:"+str(bed.id)))
	await _capture("blocked")
	var selected: String=game.selected_member
	await _button(game.access_buttons["object:"+str(bed.id)])
	assert(game.lot_view.pan!=Vector2.ZERO and game.selected_member==selected)
	await _capture("found")
	var issue: Dictionary=game._access_report.issues[0]
	var badge: Vector2=game.lot_view.grid_point(issue.center.x,issue.center.y)+Vector2(0,-43*game.lot_view._cell.x/48.0)
	assert(game.lot_view.hit_target(badge).get("type")=="access")
	await _click(badge); assert(session.world.snapshot()==before)
	await _button(_named(game.context_box,"Door"))
	assert(game.selected_tool=="door" and game._access_visible and not game.lot_view.access_inspecting)
	await _capture("repair-tool")
	var wall := _wall_point()
	await _click(wall.point)
	assert(session.last_action_ok and lot.doors.has([wall.cell.x,wall.cell.y]) and game._access_report.ok,"Clicking the visible wall opens a doorway and clears the report")
	await _capture("repaired")
	await _button(game.undo_button); assert(not game._access_report.ok)
	await _button(game.redo_button); assert(game._access_report.ok)
	await _button(game.access_button); await _capture("ready")
	await _button(game.mode_button)
	assert(not lot.building and not game.lot_view.access_visible and not game.context_panel.visible)
	# The whole house closing yields locatable resident and furnishing problems.
	await _button(game.mode_button); game.lot_view.center_lot()
	session.command({"type":"place","lot_id":lot.id,"kind":"wall","x":8,"y":11}); assert(session.last_action_ok)
	game._refresh(); await _button(game.mode_button)
	assert(game._access_report.issues.size()==10)
	await _capture("closed-entrance")
	if DisplayServer.get_name()!="headless":
		var markers: Array=game.lot_view.access_markers.values()
		assert(markers.size()==10)
		for first in range(markers.size()):
			for second in range(first+1,markers.size()): assert(not markers[first].intersects(markers[second]),"Numbered problems remain distinct in a crowded closed home")
	await _button(game.undo_button); assert(game._access_report.ok)
	await _button(game.mode_button); assert(not lot.building)
	print("BUILD_ACCESS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
