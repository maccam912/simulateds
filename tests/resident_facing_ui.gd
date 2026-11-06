extends SceneTree
const Facing = preload("res://game/resident_facing.gd")
const ModelPoints = preload("res://tests/model_test_points.gd")
var game: Control
var view: Control
var session: Node
var prefs: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.3).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/facing-"+name+suffix+".png")==OK)

func _click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true); await process_frame

func _ground_point(cell: Vector2i) -> Vector2:
	for x: float in [0.1,0.5,0.9]:
		for y: float in [0.1,0.5,0.9]:
			var point: Vector2=view.grid_point(cell.x+x,cell.y+y)
			if view.hit_target(point).is_empty(): return point
	assert(false,"A destination needs a visible ground point outside the resident's nameplate")
	return Vector2.ZERO

func _start(member: Dictionary,object: Dictionary) -> void:
	var lot: Dictionary=session.state.lots.lot_1
	session.world._clear_member(member)
	var cell: Vector2i=session.world._interaction_cells(lot,object)[0]
	member.x=cell.x; member.y=cell.y
	for need: String in member.needs: member.needs[need]=40.0
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":member.id,"lot_id":"lot_1","target_id":object.id}).ok)
	# TV viewing may use a seat/front place beyond the legacy adjacent fixture.
	for tick in range(100):
		session.world.step(0.1)
		if member.task.get("elapsed",0)>0: break
	assert(member.task.get("elapsed",0)>0,"The review must show an arrived activity")
	view.motion.tracks.clear()

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	prefs=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=false
	session.world.initialize()
	for id: String in [session.profile_id,"guest_1","guest_2","guest_3"]: session.world.ensure_family(id,"Alex" if id==session.profile_id else "Guest")
	session.world.set_online(session.profile_id,true)
	var residents: Array=[]
	for family: Dictionary in session.state.families.values():
		for member: Dictionary in family.members:
			member.lot_id="lot_1"; member.autonomy=false; member.name="Resident "+str(residents.size()+1)
			for need: String in member.needs: member.needs[need]=100.0
			residents.append(member)
	var first: Dictionary=residents[0]; var second: Dictionary=residents[1]
	var lot: Dictionary=session.state.lots.lot_1
	var original: Dictionary=lot.duplicate(true)
	lot.objects=[]; lot.walls=[]; lot.doors=[]; lot.windows={}
	var directions := [Vector2i(1,1),Vector2i.RIGHT,Vector2i(1,-1),Vector2i.UP,Vector2i(-1,-1),Vector2i.LEFT,Vector2i(-1,1),Vector2i.DOWN]
	for index in range(residents.size()):
		var member: Dictionary=residents[index]
		member.x=4+(index%4)*2; member.y=5+int(index/4)*3
		member.appearance={"skin":index%6,"hair":index%6,"shirt":index%8,"style":index%4}
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	DirAccess.make_dir_recursive_absolute("res://build")
	# A presentation pose sheet previews all eight facings and four hair styles.
	# Actual accepted movement/activities are exercised separately below and in the model suite.
	view.motion.update(session.state,"lot_1",0.0,false)
	for index in range(residents.size()):
		view.motion.tracks[residents[index].id].heading=Vector2(directions[index]).normalized()
		view.motion.tracks[residents[index].id].facing=Vector2(directions[index]).normalized()
	await _capture("eight-directions")
	view.zoom=1.8; view._layout(); view.pan+=view.camera_focus_point()-view.grid_point(7.5,7)
	await _capture("eight-directions-close")
	# Restore the real house, use normal commands, and keep automatic ticks disabled
	# between explicit steps so captures inspect exact accepted activity states.
	for index in range(residents.size()):
		session.world._clear_member(residents[index])
		if index>1: residents[index].lot_id="lot_2"
	lot.objects=original.objects; lot.walls=original.walls; lot.doors=original.doors; lot.windows=original.windows; lot.revision+=1
	view.center_lot()
	for rotation in range(4):
		var bed: Dictionary=lot.objects.filter(func(item: Dictionary): return item.kind=="bed")[0]
		var sofa: Dictionary=lot.objects.filter(func(item: Dictionary): return item.kind=="sofa")[0]
		bed.rotation=rotation; sofa.rotation=rotation; lot.revision+=1
		_start(first,bed); _start(second,sofa)
		await _capture("resting-"+str(rotation))
		assert(view.motion.direction(second).distance_to(Vector2.DOWN.rotated(rotation*PI*0.5))<0.001)
		var head := ModelPoints.resident_surface(view,first)
		assert(view.hit_target(head).get("id")==first.id,"The rotated sleeper remains selectable: rotation=%d, point=%s, hit=%s" % [rotation,head,view.hit_target(head)])
		var torso := ModelPoints.resident_part(view,second,"Torso")
		assert(view.hit_target(torso).get("id")==second.id)
		await _click(torso); assert(game.selected_member==second.id)
	for kind: String in ["bookshelf","table","plant","fridge","tv"]:
		var object: Dictionary=lot.objects.filter(func(item: Dictionary): return item.kind==kind)[0]
		_start(first,object)
		await _capture(kind)
		assert(view._activity_pose(first).get("kind")==kind)
	# Both sides of a real chat face each other, including a replaced client state.
	for member: Dictionary in [first,second]: session.world._clear_member(member); member.needs.social=40.0
	first.x=7; first.y=7; second.x=8; second.y=7
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":first.id,"lot_id":"lot_1","target_id":second.id}).ok)
	session.world.step(0.1); view.motion.tracks.clear()
	await _capture("conversation")
	assert(view.motion.direction(first).distance_to(Vector2.RIGHT)<0.001 and view.motion.direction(second).distance_to(Vector2.LEFT)<0.001)
	assert(view._activity_pose(second).get("kind")=="chat")
	var before: Dictionary=session.world.snapshot()
	session.world.state=session.world.snapshot(); game._refresh(); await _capture("snapshot")
	assert(session.world.snapshot()==before)
	first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]
	assert(view._activity_pose(first).get("kind")=="chat")
	prefs.set_value("reduced_motion",true); await _capture("reduced")
	assert(view.motion.direction(first).distance_to(Vector2.RIGHT)<0.001 and session.world.snapshot()==before)
	# A normal floor click takes over the partner's plan. The stale conversation
	# text on the other actor cannot keep either actor posed as chatting.
	game.selected_member=str(second.id); game._refresh(); await process_frame
	await _click(view.grid_point(8.5,9.5))
	assert(second.task.get("type")=="move")
	session.world.step(0.1); await _capture("departing")
	assert(view._activity_pose(first).is_empty() and view._activity_pose(second).is_empty())
	# Cue labels for two urgent residents cannot cover the other person's face.
	lot=session.state.lots.lot_1
	var bed: Dictionary=lot.objects.filter(func(item: Dictionary): return item.kind=="bed")[0]
	var sofa: Dictionary=lot.objects.filter(func(item: Dictionary): return item.kind=="sofa")[0]
	bed.rotation=2; sofa.rotation=0; lot.revision+=1
	_start(first,bed); _start(second,sofa)
	first.needs.bladder=10.0; second.needs.bladder=10.0
	await _capture("urgent-resting")
	var head := ModelPoints.resident_surface(view,first)
	assert(view.hit_target(head).get("id")==first.id and view.resident_labels.size()==2)
	await _click(head); assert(game.selected_member==first.id)
	# Actual floor clicks walk a small circuit, exercising turning, stride, and
	# selectable moving bodies with no direction fields in the simulation state.
	for member: Dictionary in [first,second]:
		session.world._clear_member(member)
		for need: String in member.needs: member.needs[need]=100.0
	first.x=12; first.y=12; second.x=14; second.y=14
	prefs.set_value("reduced_motion",false); view.motion.tracks.clear(); game._refresh()
	await process_frame
	var destinations := [Vector2i(13,12),Vector2i(13,13),Vector2i(12,13),Vector2i(12,12)]
	for destination: Vector2i in destinations:
		var previous := Vector2(float(first.x),float(first.y))
		await _click(_ground_point(destination))
		assert(first.task.get("type")=="move","Click at %s selected %s with task %s: %s" % [destination,game.selected_member,first.task,session.last_action_ok])
		session.world.step(0.23)
		var accepted: Dictionary=session.world.snapshot()
		await create_timer(0.12).timeout
		var direction := (Vector2(destination)-previous).normalized()
		assert(view.motion.direction(first).dot(direction)>0.4,"The native walk turns toward the accepted step")
		await _capture("walk-"+str(destination.x)+"-"+str(destination.y))
		assert(view.motion.position(first)==Vector2(destination) and view.motion.direction(first).distance_to(direction)<0.001)
		assert(session.world.snapshot()==accepted)
		var torso := ModelPoints.resident_part(view,first,"Torso")
		assert(view.hit_target(torso).get("id")==first.id)
		session.world.step(0.1)
	print("RESIDENT_FACING_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
