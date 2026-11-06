extends SceneTree
const Character = preload("res://game/character_profile.gd")
const Art = preload("res://game/paintings.gd")
const Pose = preload("res://game/painting_pose.gd")
const ModelPoints = preload("res://tests/model_test_points.gd")
var session: Node
var game: Control
var view: Control
var family: Dictionary
var lot: Dictionary
var easels: Array[Dictionary]=[]
var native := false

func _initialize() -> void: call_deferred("_run")
func _settle() -> void:
	game._refresh()
	for frame in range(4): await process_frame
func _capture(label: String) -> void:
	if not native: return
	await _settle()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/painting-"+label+".png")==OK)
func _order(index: int, action: String="start") -> void:
	var member: Dictionary=family.members[index]
	var easel := easels[index]
	var result: Dictionary=session.world.apply_command(session.profile_id,{"type":"painting","member_id":member.id,"lot_id":lot.id,"target_id":easel.id,"action":action,"subject":"meadow" if action=="start" else "","revision":easel.painting.revision})
	assert(result.ok,str(result.message))
func _arrive() -> void:
	for tick in range(100):
		session.world.step(0.1)
		if family.members.all(func(member): return member.task.get("elapsed",0)>0): break
	for member: Dictionary in family.members: assert(member.task.get("elapsed",0)>0)
	view.motion.tracks.clear()
	await _settle()

func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("res://build")
	root.size=Vector2i(1440,900)
	root.get_node("Preferences").reset_defaults()
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]; lot=session.state.lots[family.home_lot]
	var starter: Array=lot.objects.duplicate(true)
	# A review room in the actual house/camera, with room to inspect each side.
	lot.objects=[]
	for index in range(4):
		if index>=family.members.size():
			var extra: Dictionary=family.members[0].duplicate(true); extra.id="painter_%d" % index; family.members.append(extra)
		var member: Dictionary=family.members[index]
		member.name=["June","Alex","Morgan","Kit"][index]; member.autonomy=false
		member.character=Character.of(member).duplicate(true)
		member.character.age=[2,5,6,1][index]
		member.character.height=[0,0,100,0][index]; member.character.build=100 if index==2 else 50
		member.x=4+index; member.y=11
	assert(session.world.apply_command(session.profile_id,{"type":"build_begin","lot_id":lot.id}).ok)
	for index in range(4):
		assert(session.world.apply_command(session.profile_id,{"type":"place","lot_id":lot.id,"kind":"easel","x":6+(index%2)*3,"y":6+(index/2)*3}).ok)
		easels.append(lot.objects[-1])
	assert(session.world.apply_command(session.profile_id,{"type":"build_end","lot_id":lot.id}).ok)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _settle()
	_order(0); await _settle()
	var first: Dictionary=family.members[0]
	assert(view._activity_pose(first).is_empty())
	assert(not view.projection.scene.resident_nodes[first.id].has_node("PaintingTools"),"Walking cannot display a brush or step")
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	for turn in range(4):
		for index in range(4):
			var member: Dictionary=family.members[index]
			session.world._clear_member(member)
			easels[index].rotation=turn; easels[index].painting=Art.create(); lot.revision+=1
			_order(index)
		await _arrive()
		var before: Dictionary=session.world.snapshot()
		for index in range(4):
			var member: Dictionary=family.members[index]
			var node: Node3D=view.projection.scene.resident_nodes[member.id]
			var body: Node3D=node.get_node("Body")
			var props: Node3D=node.get_node("PaintingTools")
			var furnishing: Node3D=view.projection.scene.object_nodes[easels[index].id]
			assert(props.visible and node.basis.z.dot(-furnishing.basis.z)>0.999)
			var tip: Node3D=props.get_node("Brush/Tip")
			var contact := furnishing.to_local(tip.global_position)
			assert(absf(contact.x)<0.30 and contact.y>0.85 and contact.y<1.40 and absf(contact.z-0.134)<0.002,"Brush reaches the actual canvas face in every rotation/body size")
			assert(props.get_node("Brush").global_position.distance_to(body.get_node("Arm_R").to_global(Pose.HAND))<0.001,"Brush remains held")
			assert(view.projection.scene._meshes(props).size()<=5,"Step and brush use bounded batched geometry")
			assert(view.resident_anchor(member).distance_to(view.projection.project(node.global_position))<0.01)
			if body.position.y>0.001:
				var step_bounds: AABB=view.projection.scene.bounds(props.get_node("Step"))
				assert(absf(step_bounds.end.y-(node.position.y+body.position.y))<0.001,"Feet rest on the solid step")
			if native:
				ModelPoints.resident_surface(view,member)
				ModelPoints.object_surface(view,easels[index])
		await _capture("day-turn-%d" % turn)
		assert(session.world.snapshot()==before,"Rendering and picking cannot change canvases, paths, reservations, funds, needs or saves")
	var node: Node3D=view.projection.scene.resident_nodes[first.id]
	var props: Node3D=node.get_node("PaintingTools")
	var arm: Node3D=node.get_node("Body/Arm_R")
	var held := arm.transform
	var standing := node.transform
	await create_timer(0.12).timeout; assert(held==arm.transform,"Paused strokes stay still")
	view._time+=0.4; view.projection.sync(0.4); assert(held!=arm.transform)
	assert(node.transform==standing,"Brush strokes cannot slide the resident or support step")
	root.get_node("Preferences").set_value("reduced_motion",true); await _settle()
	held=arm.transform; view._time+=1; view.projection.sync(1); assert(held==arm.transform)
	view.zoom=1.8; view._layout(); await _capture("close")
	view.center_lot(); session.state.day_minutes=0; await _capture("night")
	root.size=Vector2i(1280,720); root.get_node("Preferences").set_value("ui_scale",1.25)
	await _capture("compact-night")
	session.state.day_minutes=720; root.get_node("Preferences").set_value("quality","low"); await _capture("compact-day-low")
	# Endpoints of every playable age's height range retain contact; tiny height
	# differences must not create a stool sunk into the floor.
	for age in range(1,7):
		for height in [0,100]:
			first.character.age=age; first.character.height=height
			await _settle()
			node=view.projection.scene.resident_nodes[first.id]; props=node.get_node("PaintingTools")
			var furnishing: Node3D=view.projection.scene.object_nodes[easels[0].id]
			var tip: Node3D=props.get_node("Brush/Tip")
			var contact := furnishing.to_local(tip.global_position)
			assert(absf(contact.z-0.134)<0.002 and contact.y>0.85 and contact.y<1.40)
			var step := props.get_node("Step") as Node3D
			if step.get_child_count()>0: assert(view.projection.scene.bounds(step).position.y>=node.position.y-0.001)
			if native: ModelPoints.resident_surface(view,first)
	first.character.age=2; first.character.height=0; await _settle()
	node=view.projection.scene.resident_nodes[first.id]; props=node.get_node("PaintingTools")
	var before: Dictionary=session.world.snapshot()
	easels[0].painting.revision+=1; await _settle(); assert(not props.visible); easels[0].painting.revision-=1
	lot.building=true; await _settle(); assert(not props.visible); lot.building=false
	easels[0].x+=4; lot.revision+=1; await _settle(); assert(not props.visible,"A stale target cannot drag the body across the room")
	easels[0].x-=4; lot.revision-=1; await _settle(); assert(props.visible)
	assert(session.world.snapshot()==before)
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	await _settle(); assert(not props.visible and node.get_node("Body").position.y==0)
	for mesh: MeshInstance3D in view.projection.scene._meshes(props): assert(not mesh.visible)
	_order(0,"resume"); session.world.step(0.1); view.motion.tracks.clear(); await _settle(); assert(props.visible)
	for tick in range(260): session.world.step(0.1)
	await _settle(); assert(first.task.is_empty() and not props.visible)
	_order(0,"sell"); session.world.step(0.1); await _settle(); assert(not props.visible,"Packing a finished painting has no painting brush")
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	easels[0].painting=Art.create(); _order(0); session.world.step(0.1); await _settle(); assert(props.visible)
	lot.objects.erase(easels[0]); lot.revision+=1; await _settle(); assert(not props.visible)
	# Review the small painter among the actual starter furnishings as well.
	for index in range(4):
		var member: Dictionary=family.members[index]
		session.world._clear_member(member); member.x=5+index; member.y=11
	lot.objects=starter; easels.clear(); lot.revision+=1
	assert(session.world.apply_command(session.profile_id,{"type":"build_begin","lot_id":lot.id}).ok)
	assert(session.world.apply_command(session.profile_id,{"type":"place","lot_id":lot.id,"kind":"easel","x":6,"y":9,"rotation":3}).ok)
	easels.append(lot.objects[-1])
	assert(session.world.apply_command(session.profile_id,{"type":"build_end","lot_id":lot.id}).ok)
	_order(0)
	for tick in range(100):
		session.world.step(0.1)
		if first.task.get("elapsed",0)>0: break
	assert(first.task.get("elapsed",0)>0)
	view.motion.tracks.clear(); view.zoom=1.5; view._layout(); await _settle()
	if native: ModelPoints.resident_surface(view,first)
	await _capture("furnished-day")
	session.state.day_minutes=0; await _capture("furnished-night")
	print("PAINTING_POSE_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
