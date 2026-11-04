extends SceneTree
var game: Control
var session: Node
var view: Control
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	game._refresh()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/resident-cues-"+name+suffix+".png")==OK)

func _click(point: Vector2, double: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point
		event.pressed=pressed; event.double_click=double and pressed
		root.push_input(event,true); await process_frame

func _point(id: String) -> Vector2:
	return view.get_global_transform_with_canvas()*view.resident_labels[id].rect.get_center()

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact: suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true)
	for family: Dictionary in session.state.families.values():
		for resident: Dictionary in family.members: resident.autonomy=false
	var first: Dictionary=session.state.families[session.profile_id].members[0]
	var second: Dictionary=session.state.families[session.profile_id].members[1]
	for resident: Dictionary in [first,second]:
		resident.x=9; resident.y=9
		for need: String in resident.needs: resident.needs[need]=100.0
	first.needs.hunger=14.0; second.needs.energy=16.0
	var neighbor: Dictionary=session.state.families.neighbor.members[0]
	neighbor.lot_id="lot_1"; neighbor.x=8; neighbor.y=9; neighbor.needs.fun=10.0
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _capture("clustered")
	assert(view.resident_labels.size()==2 and not view.resident_labels.has(neighbor.id),"Only your household carries actionable need cues")
	var first_box: Rect2=view.resident_labels[first.id].rect
	var second_box: Rect2=view.resident_labels[second.id].rect
	assert(not first_box.intersects(second_box))
	assert(view.hit_target(second_box.get_center()).type=="care","The cue is picked above furniture and bodies")
	var point := _point(str(second.id))
	await _click(point)
	assert(game.selected_member==second.id and session.world.task_activity(second.task,"lot_1")=="bed" and first.task.is_empty())
	var count: int=session.actions_received
	await _click(point,true)
	assert(session.actions_received==count and second.queue.is_empty(),"A double click cannot fall through a disappearing cue into another order")
	await _capture("planned")
	assert(view.resident_labels[second.id].need=="" and view.resident_labels[first.id].need=="hunger","Covered needs stop asking while other residents remain visible")
	await _click(_point(str(first.id)))
	assert(session.world.task_activity(first.task,"lot_1")=="fridge")
	for tick in range(50): session.world.step(0.1)
	game.selected_member=str(second.id); game._refresh()
	await _capture("sleeping")
	assert(view._activity_pose(second).get("kind")=="bed")
	assert(view.hit_target(view.resident_labels[second.id].rect.get_center()).id==second.id,"Sleeping residents keep a selectable name above the furnishing layer")
	for tick in range(200): session.world.step(0.1)
	await _capture("settled")
	assert(view.resident_labels.size()==1 and view.resident_labels[second.id].need=="","Content residents keep the world quiet")
	# Long names, night contrast, and a cluster at the left edge.
	first.name="A very long household member name".left(32); second.name="Another long resident name here".left(32)
	session.state.families[session.profile_id].identity_revision+=1
	for resident: Dictionary in [first,second]:
		session.world._clear_member(resident); resident.x=9; resident.y=9
	first.needs.fun=12.0; second.needs.social=14.0
	session.state.day_minutes=0; root.get_node("Preferences").set_value("reduced_motion",true)
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	assert(view.motion.position(first)==Vector2(9,9),"Wait for the displayed fixture position before framing the edge case")
	view.pan+=Vector2(16,350)-view.resident_anchor(first)
	await _capture("night-edge")
	var boxes: Array[Rect2]=[]
	for entry: Dictionary in view.resident_labels.values():
		assert(Rect2(Vector2.ZERO,view.size).encloses(entry.rect) and entry.rect.size.x<=276)
		assert("…" in entry.text)
		for other: Rect2 in boxes: assert(not other.intersects(entry.rect))
		boxes.append(entry.rect)
	assert(boxes.size()==2)
	view.pan=Vector2.ZERO
	for resident: Dictionary in [first,second]:
		for need: String in resident.needs: resident.needs[need]=100.0
	first.needs.hunger=12.0
	for object: Dictionary in session.state.lots.lot_1.objects.duplicate():
		if object.kind=="fridge": session.state.lots.lot_1.objects.erase(object)
	await _capture("missing-before")
	await _click(_point(str(first.id)))
	assert(first.task.is_empty() and game.context_panel.visible and "fridge" in game.notice_label.text,"Unavailable care gets the existing useful explanation")
	await _capture("missing")
	game.context_panel.hide(); game._toggle_build(); await _capture("building")
	assert(view.resident_labels.is_empty(),"Construction does not display unavailable resident controls")
	game._toggle_build(); game.hud.hide(); await process_frame; await process_frame
	assert(view.resident_labels.is_empty(),"Menu backgrounds do not retain interactive labels")
	game.hud.show(); view.pan=Vector2(10000,10000); await _capture("offscreen")
	assert(view.resident_labels.is_empty(),"Offscreen actors do not leave floating controls")
	print("RESIDENT_CUES_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
