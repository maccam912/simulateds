extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _ids(queue: Array) -> Array:
	var ids: Array=[]
	for action: Dictionary in queue: ids.append(action.id)
	return ids

func _click(control: Button) -> void:
	if game.plan_box.is_ancestor_of(control): game.plan_scroll.ensure_control_visible(control)
	await process_frame; await process_frame
	var point := control.get_global_rect().get_center()
	assert(root.get_visible_rect().has_point(point))
	if game.plan_box.is_ancestor_of(control): assert(game.plan_scroll.get_global_rect().has_point(point))
	var motion := InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true); await process_frame
	var received := [false]; control.pressed.connect(func(): received[0]=true,CONNECT_ONE_SHOT)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.pressed=pressed; event.button_index=MOUSE_BUTTON_LEFT
		root.push_input(event,true); await process_frame
	assert(received[0],"A plan control must receive actual mouse input")
	await process_frame

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame

func _capture(name: String) -> void:
	game._refresh(); await process_frame; await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/plan-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]
	for resident: Dictionary in family.members: resident.autonomy=false
	var first: Dictionary=family.members[0]; var second: Dictionary=family.members[1]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	for index in range(9): session.command({"type":"move","member_id":first.id,"x":index,"y":0})
	game._refresh(); await _click(game.queue_label)
	var active: Dictionary=first.task.duplicate(true)
	var before := _ids(first.queue); var last: String=before[-1]
	assert(game.plan_controls[active.id].size()==1,"The active activity offers cancellation, never reordering")
	assert(game.plan_controls[before[0]].earlier.disabled and game.plan_controls[last].later.disabled)
	await _click(game.plan_controls[last].earlier)
	assert(first.queue[6].id==last and first.task==active)
	assert(game.plan_controls[last].earlier.has_focus() and game.plan_scroll.scroll_vertical>0,"Focus and a useful scroll position follow the edited action")
	await _capture("full-queue")
	assert(not game.notice_panel.get_global_rect().intersects(game.plan_panel.get_global_rect()),"Confirmation must not cover the plan being edited")
	assert(game.notice_panel.get_rect().end.y<=game.needs_panel.get_rect().position.y-12.0+0.1,"Notices remain above the household controls")
	game._notice("The plan changed while this request was travelling. Choose an upcoming action from the current plan and try again.")
	await _capture("wrapped-notice")
	assert(not game.notice_panel.get_global_rect().intersects(game.plan_panel.get_global_rect()) and game.notice_panel.get_rect().end.y<=game.needs_panel.get_rect().position.y-12.0+0.1,"Long confirmations grow upward into free space")
	await _key(KEY_SPACE)
	assert(first.queue[5].id==last and first.task==active,"Keyboard focus remains on this action after rebuilding the rows")
	var snapshot: Dictionary=session.world.snapshot()
	session.command({"type":"reorder_action","member_id":first.id,"first_id":before[6],"second_id":last})
	assert(not session.last_action_ok and session.world.snapshot()==snapshot)
	# At the first/last boundary, focus falls back to the available reverse arrow.
	var promote: String=first.queue[1].id
	await _click(game.plan_controls[promote].earlier)
	assert(first.queue[0].id==promote and game.plan_controls[promote].earlier.disabled and game.plan_controls[promote].later.has_focus())
	await _key(KEY_SPACE)
	assert(first.queue[1].id==promote)
	await _click(game.plan_controls[last].cancel)
	assert(not last in _ids(first.queue) and first.task==active,"Cancellation still addresses the intended action after several moves")
	# A two-resident morning: one prepares food while the other can move reading
	# ahead of the occupied fridge. Bring the bathroom earlier in the first plan.
	for resident: Dictionary in family.members:
		session.command({"type":"cancel","member_id":resident.id})
		resident.needs.hunger=15.0; resident.needs.hygiene=15.0; resident.needs.bladder=12.0; resident.needs.fun=15.0
	var objects := {}
	for object: Dictionary in session.state.lots.lot_1.objects: objects[object.kind]=object
	for kind: String in ["fridge","shower","bookshelf","toilet","table"]:
		session.command({"type":"interact","member_id":first.id,"target_id":objects[kind].id}); assert(session.last_action_ok)
	for kind: String in ["fridge","bookshelf"]:
		session.command({"type":"interact","member_id":second.id,"target_id":objects[kind].id}); assert(session.last_action_ok)
	var meal: String=first.task.id; var bathroom: String=first.queue[2].id
	game._refresh()
	await _click(game.plan_controls[bathroom].earlier)
	await _click(game.plan_controls[bathroom].earlier)
	assert(first.task.id==meal and first.queue[0].id==bathroom)
	var expected_order: Array=[meal]+_ids(first.queue)
	await _capture("morning")
	await _click(game.family_box.get_child(1))
	var waiting: String=second.queue[0].id; var reading: String=second.queue[1].id
	assert(second.task.is_empty() and str(second.action).begins_with("Waiting"))
	await _click(game.plan_controls[reading].earlier)
	session.world.step(0.1)
	assert(second.task.id==reading and second.queue[0].id==waiting and first.task.id==meal)
	await _capture("busy-fridge")
	var seen: Array=[meal]
	var first_meal_hunger := 0.0; var second_reading_fun := 0.0
	for tick in range(1000):
		session.world.step(0.1)
		if not first.task.is_empty() and seen[-1]!=first.task.id: seen.append(first.task.id)
		if first.task.get("id","")!=meal and first_meal_hunger==0: first_meal_hunger=first.needs.hunger
		if second.task.get("id","")!=reading and second_reading_fun==0: second_reading_fun=second.needs.fun
		if tick%20==0: game._refresh(); await process_frame
		if first.task.is_empty() and first.queue.is_empty() and second.task.is_empty() and second.queue.is_empty(): break
	assert(seen==expected_order and first.task.is_empty() and first.queue.is_empty() and second.task.is_empty() and second.queue.is_empty())
	assert(first_meal_hunger>65 and second_reading_fun>65 and first.needs.bladder>65 and first.needs.hygiene>65,"Revised plans complete useful care and recreation for both residents")
	await _capture("morning-done")
	print("PLAN_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
