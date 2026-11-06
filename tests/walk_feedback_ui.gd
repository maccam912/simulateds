extends SceneTree
var game: Control
var view: Control
var session: Node
var member: Dictionary
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new(); event.position=point
	root.push_input(event,true); await process_frame; await process_frame

func _click(point: Vector2) -> void:
	await _hover(point)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.12).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/walking-"+name+suffix+".png")==OK)

func _ground(cell: Vector2i) -> Vector2:
	for x: float in [0.5,0.1,0.9]:
		for y: float in [0.5,0.1,0.9]:
			var point: Vector2=view.grid_point(cell.x+x,cell.y+y)
			if view.hit_target(point).is_empty(): return point
	assert(false,"Need exposed ground")
	return Vector2.ZERO

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true)
	for family: Dictionary in session.state.families.values():
		for resident: Dictionary in family.members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=100.0
	member=session.state.families[session.profile_id].members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	# This route fixture uses lawn destinations at the far lot edge.
	view.center_lot()
	DirAccess.make_dir_recursive_absolute("res://build")
	await _capture("idle")
	var goal := Vector2i(8,14)
	await _hover(_ground(goal)); await _capture("preview")
	assert(view.walking.preview.ok and view.walking.preview.ahead==0 and view.walking.preview.path.size()>0)
	var route: Array=view.walking.preview.path.duplicate(true)
	var before: Dictionary=session.world.snapshot()
	await _capture("pure-preview"); assert(session.world.snapshot()==before and view.walking.markers.is_empty())
	await _click(_ground(goal)); await _capture("accepted")
	assert(member.task.type=="move" and member.task.path==route and view.walking.markers.size()==1)
	var active_id: String=member.task.id
	assert(view.walking.markers[0].id==active_id and view.walking.markers[0].active)
	var next := Vector2i(13,14)
	await _hover(_ground(next)); await _capture("queued-preview")
	assert(view.walking.preview.ok and view.walking.preview.ahead==1 and "Queue walk" in view.walking.preview.message)
	await _click(_ground(next)); await _capture("queued")
	assert(member.queue.size()==1 and view.walking.markers.size()==2 and view.walking.markers[1].order==2)
	var queued_id: String=member.queue[0].id
	# Hovering a name accurately offers selection, with no ground-walk promise.
	await _hover(view.resident_labels[str(member.id)].rect.get_center()); await _capture("nameplate")
	assert(view.hover_target.get("id")==member.id and view.walking.preview.is_empty())
	await _click(game.queue_label.get_global_rect().get_center()); await _capture("plan")
	assert(view.show_plan_routes and view.walking.markers.size()==2 and view.walking.route==member.task.path)
	assert(game.plan_titles[queued_id].text.begins_with("NEXT 2 ·"),"World destination numbers match visible Plan rows")
	await _click(game.plan_controls[queued_id].cancel.get_global_rect().get_center()); await _capture("canceled")
	assert(member.queue.is_empty() and view.walking.markers.size()==1)
	session.command({"type":"move","member_id":member.id,"x":13,"y":14})
	session.command({"type":"move","member_id":member.id,"x":13,"y":14})
	await _capture("repeated-destination")
	assert(view.walking.markers.size()==3 and view.walking.markers[1].cell==view.walking.markers[2].cell)
	# Hiding the HUD removes overlays, even if the pointer still covers ground.
	game.hud.hide(); await _hover(_ground(goal)); await _capture("menu")
	assert(view.walking.preview.is_empty() and view.walking.markers.is_empty())
	game.hud.show(); game.plan_panel.hide(); game._refresh(); await process_frame
	# A sealed threshold gives the same rejection before and after clicking.
	session.command({"type":"cancel","member_id":member.id})
	var lot: Dictionary=session.state.lots.lot_1
	lot.walls.append([8,11]); lot.doors.erase([8,11]); lot.revision+=1
	await _hover(_ground(goal)); await _capture("blocked")
	assert(not view.walking.preview.ok and "no path" in view.walking.preview.message)
	before=session.world.snapshot()
	await _click(_ground(goal)); assert(not session.last_action_ok and session.world.snapshot()==before)
	assert(view.walking.markers.is_empty())
	lot.walls.erase([8,11]); lot.doors.append([8,11]); lot.revision+=1
	await _hover(_ground(goal)); await _capture("repaired")
	assert(view.walking.preview.ok)
	# A replaced snapshot keeps accepted markers but never invents them locally.
	await _click(_ground(goal)); var accepted: Dictionary=session.world.snapshot()
	session.world.state=accepted.duplicate(true); member=session.state.families[session.profile_id].members[0]
	game._refresh(); await _capture("snapshot")
	assert(view.walking.markers[0].id==member.task.id and session.world.snapshot()==accepted)
	# While the resident actually walks, the accepted path shrinks and the drawn
	# route joins any still-interpolating accepted step before its next corner.
	for index in range(3):
		session.world.step(0.23); await process_frame
		await _capture("walking-"+str(index))
		assert(view.walking.route==member.task.path and view.walking.markers[0].cell==goal)
	# Reduced motion keeps meaningful static route/destination information.
	prefs.set_value("reduced_motion",true)
	await _hover(_ground(Vector2i(13,14))); await _capture("reduced")
	assert(view.walking.preview.ahead==1 and view.walking.markers.size()==1)
	await _click(game.mode_button.get_global_rect().get_center()); await _capture("construction")
	assert(view.building and view.walking.preview.is_empty() and view.walking.markers.is_empty())
	session.command({"type":"build_cancel","lot_id":"lot_1"}); game._refresh(); await process_frame
	game._select_lot("lot_2"); game.neighborhood_panel.hide(); game.context_panel.hide(); await _capture("neighbor")
	await _hover(_ground(Vector2i(8,14))); await _capture("visit-first")
	assert(not view.walking.preview.ok and "Visit" in view.walking.preview.message)
	# Travel clears the previous lot's route and renders only the new view.
	session.command({"type":"visit","member_id":member.id,"lot_id":"lot_2"}); game._refresh(); await _capture("visiting")
	await _hover(_ground(Vector2i(9,14))); await _capture("visitor-preview")
	assert(view.walking.preview.ok and view.walking.markers.is_empty())
	print("WALK_FEEDBACK_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
