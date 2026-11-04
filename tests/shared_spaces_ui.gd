extends SceneTree
const Leisure = preload("res://game/shared_leisure.gd")
const ModelPoints = preload("res://tests/model_test_points.gd")
var game: Control
var session: Node
var sound: Node
var view: Control
var stereo: Dictionary
var first: Dictionary
var second: Dictionary
var visitor: Dictionary
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=true) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if not click: return
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true); await process_frame

func _button(button: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(button)
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(not button.disabled and root.get_visible_rect().encloses(button.get_global_rect()))
	var pressed := [false]; button.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(pressed[0])

func _point() -> Vector2:
	return ModelPoints.object_surface(view,stereo)

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.3).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/shared-spaces-"+name+suffix+".png")==OK)

func _arrive(count: int) -> void:
	for tick in range(120):
		session.world.step(0.1); await process_frame
		if Leisure.players(session.state,"lot_1",stereo.id).size()==count:
			session.world.step(0.1); game._refresh(); await create_timer(0.35).timeout; return
	assert(false,str([first,second]))

func _find_button(node: Node, title: String) -> Button:
	if node is Button and node.text==title: return node
	for child: Node in node.get_children():
		var found := _find_button(child,title)
		if found!=null: return found
	return null

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); sound=root.get_node("Soundscape")
	session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]
	for member: Dictionary in [first,second]: member.autonomy=false; member.needs.fun=0.0
	session.command({"type":"build_begin","lot_id":"lot_1"}); assert(session.last_action_ok)
	for cell: Vector2i in [Vector2i(6,6),Vector2i(7,5),Vector2i(8,6)]:
		session.command({"type":"place","lot_id":"lot_1","kind":"wall","x":cell.x,"y":cell.y}); assert(session.last_action_ok)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await process_frame; await process_frame
	await _button(game.catalog_buttons.stereo)
	var before: Dictionary=session.world.snapshot()
	await _mouse(view.grid_point(7.5,6.5),false); await _capture("solo-preview")
	assert(view.preview_result.ok and view.leisure_report.capacity==1 and view.leisure_markers.size()==4)
	assert(session.world.snapshot()==before and view.preview_label_rect.has_area())
	for occupied: Rect2 in view.overlay_rects: assert(not occupied.intersects(view.preview_label_rect))
	await _mouse(view.grid_point(7.5,6.5)); stereo=session.state.lots.lot_1.objects[-1]; assert(stereo.kind=="stereo")
	await _button(game.mode_button); assert(not session.state.lots.lot_1.building,str(session.world.build_access(session.state.lots.lot_1))); game.context_panel.hide()
	await _mouse(_point()); await _button(game.recreation_panel.single_button); assert(not first.task.is_empty() or not second.task.is_empty(),str([session.last_action_ok,first.action,second.action])); await _arrive(1)
	await _button(game.family_box.get_child(1)); await _button(game.people_button)
	assert(game.leisure_buttons[first.id].text=="Queue dance" and game.leisure_buttons[first.id].tooltip_text.contains("Only one usable place"))
	await _button(game.leisure_buttons[first.id]); await _capture("waiting")
	assert(second.task.is_empty() and second.queue.size()==1 and second.action.contains("Only one usable place"))
	await _button(game.people_button)
	await _mouse(_point(),false); await _capture("reserved")
	assert(view.leisure_report.reserved==1 and view.leisure_report.capacity==1 and view.leisure_report.available.is_empty())
	assert(view.leisure_markers.filter(func(mark): return mark.status=="reserved").size()==1)
	# Moving furniture previews a copied layout, then accepts the same four places.
	await _button(game.mode_button)
	await _button(_find_button(game.context_box,"Move"))
	await _mouse(_point()); assert(game._moving_object==stereo.id)
	before=session.world.snapshot()
	# This clear four-place location stays visible beside the sofa. The old
	# (9,9) fixture is fully occluded by the real 3D bookshelf at (10,10).
	await _mouse(view.grid_point(6.5,9.5),false); await _capture("move-preview")
	assert(view.preview_result.ok and view.leisure_report.capacity==4 and session.world.snapshot()==before,str([view.preview_result,view.leisure_report,view.hover_cell,session.world.snapshot()==before]))
	await _mouse(view.grid_point(6.5,9.5)); assert(stereo.x==6 and stereo.y==9)
	await _button(game.mode_button); game.context_panel.hide()
	await _mouse(_point()); await _button(game.recreation_panel.single_button); await _arrive(1)
	await _button(game.family_box.get_child(0)); await _button(game.people_button)
	assert(game.leisure_buttons[second.id].text=="Join dance")
	await _button(game.leisure_buttons[second.id]); await _arrive(2)
	await _button(game.people_button); await _mouse(_point(),false); await _capture("together")
	assert(view.leisure_report.capacity==4 and view.leisure_report.reserved==2)
	assert(view.leisure_markers.filter(func(mark): return mark.status=="reserved").size()==2)
	assert(first.action=="Dancing together" and second.action=="Dancing together")
	# A paused cancellation changes reservations without advancing the simulation tick.
	var tick: int=session.state.tick
	session.command({"type":"cancel","member_id":second.id}); game._refresh()
	await _mouse(_point(),false); await _capture("released")
	assert(session.state.tick==tick and view.leisure_report.reserved==1)
	assert(view.leisure_markers.filter(func(mark): return mark.status=="occupied").size()==1)
	# Moving the cursor away removes the inspection overlay without touching plans.
	before=session.world.snapshot(); await _mouse(Vector2(5,300),false); await process_frame
	assert(view.leisure_markers.is_empty() and session.world.snapshot()==before)
	print("SHARED_SPACES_UI_PASS")
	await sound.shutdown_and_wait(); quit()
