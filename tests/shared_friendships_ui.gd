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
	await preload("res://tests/hud_navigation.gd").reveal(button)
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
	assert(root.get_texture().get_image().save_png("res://build/shared-friendships-"+name+suffix+".png")==OK)

func _arrive(count: int) -> void:
	for tick in range(120):
		session.world.step(0.1); await process_frame
		if Leisure.players(session.state,"lot_1",stereo.id).size()==count:
			session.world.step(0.1); game._refresh(); await create_timer(0.35).timeout; return
	assert(false,str([first,second]))

const Bonds = preload("res://game/friendships.gd")

func _text(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label else ""
	for child: Node in node.get_children(): result+=_text(child)
	return result

func _bond() -> Dictionary: return Bonds.bond(session.state,str(first.id),str(second.id))

func _catch_up(count: int) -> void:
	for tick in range(60):
		session.world.step(0.1); await process_frame
		if int(_bond().today)==count: game._refresh(); await process_frame; return
	assert(false,"Shared play did not build friendship")

func _notice_contains(value: String) -> void:
	for attempt in range(45):
		if game.notice_label.text.contains(value): return
		await create_timer(0.1).timeout
	assert(false,"Accepted friendship progress must reach its quiet notice")

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
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.stereo); await _mouse(view.grid_point(8.5,5.5))
	stereo=session.state.lots.lot_1.objects[-1]
	await _button(game.mode_button); game.context_panel.hide()
	await _mouse(_point()); await _button(game.recreation_panel.single_button); await _arrive(1)
	# Seed Robin's accepted autonomous choice, then choose deliberate participation through People.
	session.world._queue_action(second,{"type":"interact","target_id":stereo.id,"automatic":true})
	session.world._start_next(second,session.state.lots.lot_1); await _arrive(2)
	for tick in range(40): session.world.step(0.1)
	assert(_bond().score==20 and _bond().today==0)
	await _button(game.family_box.get_child(1)); await _button(game.people_button)
	assert(game.leisure_buttons[first.id].text=="Join dance" and not game.leisure_buttons[first.id].disabled)
	await _capture("choose-together"); await _button(game.leisure_buttons[first.id])
	assert(not second.task.get("automatic",false))
	await _catch_up(1); await _notice_contains("caught up while dancing"); await _capture("first-catch-up")
	assert(_bond().score==32 and _bond().last_activity=="stereo")
	assert(_text(game.tools_box).contains("Danced together · Day 1") and _text(game.tools_box).contains("1 catch-up left today"))
	# A second chosen encounter reaches the shared Friends milestone and daily limit.
	await _button(game.queue_label); await _button(game.plan_controls[second.task.id].cancel)
	await _button(game.people_button); await _button(game.leisure_buttons[first.id])
	await _catch_up(2); await _notice_contains("now friends"); await _capture("friends")
	assert(_bond().score==44 and Bonds.title(_bond())=="Friends")
	assert(_text(game.tools_box).contains("Caught up today") and _text(game.tools_box).contains("Friends"))
	assert(game.notice_label.text.contains("now friends") and first.wishes.journal[0].text.contains("friends") and second.wishes.journal[0].text.contains("friends"))
	var loaded := preload("res://game/world.gd").new(); assert(loaded.restore(JSON.parse_string(JSON.stringify(session.world.snapshot_for_save()))))
	assert(Bonds.bond(loaded.state,str(first.id),str(second.id)).score==44 and Bonds.bond(loaded.state,str(first.id),str(second.id)).last_activity=="stereo")
	print("SHARED_FRIENDSHIPS_UI_PASS")
	await sound.shutdown_and_wait(); quit()
