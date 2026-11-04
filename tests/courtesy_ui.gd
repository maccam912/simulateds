extends SceneTree
const Leisure = preload("res://game/shared_leisure.gd")
var game: Control
var session: Node
var sound: Node
var view: Control
var stereo: Dictionary
var first: Dictionary
var second: Dictionary
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
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(not button.disabled and root.get_visible_rect().encloses(button.get_global_rect()))
	var pressed := [false]; button.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(pressed[0])

func _point() -> Vector2:
	var cell: Vector2=view.object_point(stereo,Vector2(0.5,0.5))
	var center: Vector2=view.grid_point(cell.x,cell.y)
	for y in range(-32,1,2):
		for x in range(-18,19,2):
			var point := center+Vector2(x,y)
			if view.hit_target(point).get("id")==stereo.id: return point
	assert(false,"Stereo must have a visible click surface"); return center

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.3).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/courtesy-"+name+suffix+".png")==OK)

func _arrive(count: int) -> void:
	for tick in range(120):
		session.world.step(0.1); await process_frame
		if Leisure.players(session.state,"lot_1",stereo.id).size()==count:
			session.world.step(0.1); game._refresh(); await create_timer(0.35).timeout; return
	assert(false,str([first,second]))

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
	await _button(game.catalog_buttons.stereo); await _mouse(view.grid_point(7.5,6.5))
	stereo=session.state.lots.lot_1.objects[-1]
	await _button(game.mode_button); assert(not session.state.lots.lot_1.building); game.context_panel.hide()
	await _mouse(_point()); await _button(game.recreation_panel.single_button); await _arrive(1)
	await _button(game.family_box.get_child(1)); await _button(game.people_button)
	assert(game.leisure_buttons[first.id].text=="Queue dance")
	await _button(game.leisure_buttons[first.id]); var waiting: String=second.queue[0].id
	await _capture("waiting")
	await _button(game.family_box.get_child(0)); await _button(game.queue_label)
	# Let the real activity fulfill fun and finish, without shortening its timer.
	for tick in range(200):
		session.world.step(0.1); await process_frame
		if first.task.get("courtesy",false): break
	assert(first.task.get("courtesy",false) and second.queue[0].id==waiting)
	assert(first.needs.fun>=99.0 and first.activity_log[0].outcome=="done")
	var departure := Vector2i(first.x,first.y); var destination := Vector2i(first.task.x,first.task.y)
	var courtesy_id: String=first.task.id
	await _capture("making-room")
	assert(game.plan_titles[courtesy_id].text.contains("Making room for Robin") and game.plan_titles[courtesy_id].text.contains("courtesy"))
	assert(game._plan_detail.text.contains("short step aside") and game.plan_controls[courtesy_id].cancel.visible)
	# A visible, accepted walk hands the same pending plan its place.
	for tick in range(20):
		session.world.step(0.1); game._refresh(); await process_frame
		if second.task.get("id")==waiting and second.task.path.is_empty() and second.task.get("elapsed",0.0)>0.0: break
	await _capture("handoff")
	assert(first.task.is_empty() and Vector2i(first.x,first.y)==destination and departure.distance_to(destination)==1)
	assert(second.task.id==waiting and second.action=="Dancing" and second.task.path.is_empty())
	assert(first.activity_log.size()==1 and first.activity_log[0].title=="Little hi-fi")
	await _button(game.family_box.get_child(1)); await _capture("next-dancer")
	assert(game._plan_detail.text.contains("Dancing"))
	# Reduced motion still uses the accepted position, with no extra local movement.
	prefs.set_value("reduced_motion",true); await process_frame; await process_frame
	assert(view.motion.position(first)==Vector2(destination)); await _capture("reduced-motion")
	print("COURTESY_UI_PASS")
	await sound.shutdown_and_wait(); quit()
