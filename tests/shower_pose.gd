extends SceneTree
## Real commands drive the pose; rendering never owns the approach/reservation.
const Character = preload("res://game/character_profile.gd")
const ModelPoints = preload("res://tests/model_test_points.gd")
var session: Node
var game: Control
var view: Control
var family: Dictionary
var lot: Dictionary
var native := false

func _initialize() -> void: call_deferred("_run")

func _settle() -> void:
	game._refresh()
	for frame in range(4): await process_frame

func _capture(label: String) -> void:
	if not native: return
	await _settle()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/shower-"+label+".png")==OK)

func _start(member: Dictionary, shower: Dictionary) -> void:
	session.world._clear_member(member)
	member.needs.hygiene=10.0
	var cell: Vector2i=session.world._interaction_cells(lot,shower)[0]
	member.x=cell.x; member.y=cell.y
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":member.id,"lot_id":lot.id,"target_id":shower.id}).ok)
	session.world.step(0.1)
	assert(member.task.target_id==shower.id and member.task.elapsed>0)

func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("res://build")
	root.size=Vector2i(1440,900)
	root.get_node("Preferences").reset_defaults()
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]; lot=session.state.lots[family.home_lot]
	# Four separated, rotated showers allow native review of every open/back side.
	lot.objects=[]
	for index in range(4):
		lot.objects.append({"id":"shower_%d" % index,"kind":"shower","x":5+(index%2)*4,"y":5+(index/2)*3,"rotation":index})
		if index>=family.members.size():
			var extra: Dictionary=family.members[0].duplicate(true)
			extra.id="shower_resident_%d" % index
			family.members.append(extra)
		var member: Dictionary=family.members[index]
		member.name=["Alex","Robin","June","Morgan"][index]
		member.autonomy=false
		member.character=Character.of(member).duplicate(true)
		member.character.age=2 if index==2 else 5
		member.character.height=[50,0,50,100][index]
		member.character.build=100 if index==3 else 50
		member.x=5+index; member.y=10
	lot.revision+=1
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _settle()
	var first: Dictionary=family.members[0]
	var shower: Dictionary=lot.objects[0]
	# A walk toward the shower and a not-yet-started order do not occupy it.
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":first.id,"lot_id":lot.id,"target_id":shower.id}).ok)
	await _settle()
	assert(view._activity_pose(first).is_empty())
	assert(not view.projection.scene.object_nodes[shower.id].has_node("RunningWater"))
	_start(first,shower)
	var second: Dictionary=family.members[1]
	second.needs.hygiene=10.0
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":second.id,"lot_id":lot.id,"target_id":shower.id}).ok)
	session.world.step(0.1)
	await _settle()
	assert(view._activity_pose(first).get("kind")=="shower")
	assert(view._activity_pose(second).is_empty(),"A queued resident does not share the occupied enclosure")
	assert(not second.queue.is_empty(),"The existing exclusive reservation remains authoritative")
	for index in range(4): _start(family.members[index],lot.objects[index])
	view.motion.tracks.clear()
	await _settle()
	for turn in range(4):
		# Each body size uses each rotation, without regenerating any mesh asset.
		for index in range(4): lot.objects[index].rotation=(index+turn)%4
		lot.revision+=1
		await _settle()
		var before: Dictionary=session.world.snapshot()
		for index in range(4):
			var member: Dictionary=family.members[index]
			var node: Node3D=view.projection.scene.resident_nodes[member.id]
			var object: Node3D=view.projection.scene.object_nodes[lot.objects[index].id]
			assert(node.position.is_equal_approx(object.position+Vector3(0,0.175,0)),"Feet rest in the tray, not on the reserved approach cell")
			assert(node.basis.z.dot(object.basis.z)<-0.999,"The resident faces the mixer in every rotation")
			assert(view.resident_anchor(member).distance_to(view.projection.project(node.global_position))<0.01,"Labels follow the rendered occupant")
			assert(object.get_node("RunningWater").visible)
			if native: ModelPoints.resident_surface(view,member)
		await _capture("day-turn-%d" % turn)
		assert(session.world.snapshot()==before,"Mesh, water, picking and camera leave world/saves/reservations unchanged")
	if native:
		view.zoom=1.8; view._layout()
		await _capture("close")
		view.center_lot()
	# Paused simulation freezes presentation time, including water and washing.
	var water: Node3D=view.projection.scene.object_nodes[shower.id].get_node("RunningWater")
	var drop_before: Transform3D=water.get_child(0).transform
	await create_timer(0.12).timeout
	assert(water.get_child(0).transform==drop_before)
	root.get_node("Preferences").set_value("reduced_motion",true)
	await _settle()
	drop_before=water.get_child(0).transform
	view._time+=1.0; view.projection.sync(1.0)
	assert(water.get_child(0).transform==drop_before,"Reduced motion uses a steady water cue")
	await _capture("reduced")
	session.state.day_minutes=0
	await _capture("night")
	root.size=Vector2i(1280,720)
	root.get_node("Preferences").set_value("ui_scale",1.25)
	await _capture("compact-night")
	session.state.day_minutes=720
	await _capture("compact-day")
	# Cancellation immediately clears the body pose and restores the full enclosure.
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	await _settle()
	var node: Node3D=view.projection.scene.resident_nodes[first.id]
	assert(node.position.x==first.x+0.5 and node.position.z==first.y+0.5)
	assert(not water.visible)
	for mesh: MeshInstance3D in view.projection.scene._meshes(view.projection.scene.object_nodes[shower.id]):
		if mesh.has_meta("shower_rest_transform"): assert(mesh.transform==mesh.get_meta("shower_rest_transform"))
	for drop: Node3D in water.get_children(): assert(not drop.visible,"Inactive water cannot intercept a pick")
	await _capture("cancelled")
	# Completion uses the ordinary simulation outcome, including need restoration.
	_start(first,shower)
	for tick in range(40): session.world.step(0.25)
	await _settle()
	assert(first.task.is_empty() and not water.visible and first.needs.hygiene>90.0)
	assert(node.position.x==first.x+0.5 and node.position.z==first.y+0.5)
	# A changed/missing target or construction must never leave water/poses behind.
	_start(first,shower); await _settle()
	lot.building=true; await _settle()
	assert(not water.visible and view._activity_pose(first).is_empty())
	lot.building=false; await _settle()
	lot.objects.erase(shower); lot.revision+=1; await _settle()
	assert(view._activity_pose(first).is_empty())
	assert(not view.projection.scene.object_nodes.has(shower.id))
	assert(node.position.x==first.x+0.5 and node.position.z==first.y+0.5)
	print("SHOWER_POSE_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
