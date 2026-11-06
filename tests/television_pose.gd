extends SceneTree
const Character = preload("res://game/character_profile.gd")
const TV = preload("res://game/television.gd")
const ModelPoints = preload("res://tests/model_test_points.gd")
var session: Node
var game: Control
var view: Control
var family: Dictionary
var lot: Dictionary
var tv: Dictionary
var seat: Dictionary
var native := false
var capture_prefix := "tv-"

func _initialize() -> void: call_deferred("_run")
func _settle() -> void:
	game._refresh()
	for frame in range(4): await process_frame
func _capture(label: String) -> void:
	if not native: return
	await _settle(); await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/"+capture_prefix+label+".png")==OK)
func _watch(member: Dictionary) -> void:
	var result: Dictionary=session.world.apply_command(session.profile_id,{"type":"interact","member_id":member.id,"lot_id":lot.id,"target_id":tv.id})
	assert(result.ok,str(result.message))
	for tick in range(100):
		session.world.step(0.1)
		if member.task.get("elapsed",0)>0: break
	assert(member.task.get("elapsed",0)>0)
	view.motion.tracks.clear(); await _settle()

func _run() -> void:
	native=DisplayServer.get_name()!="headless"; root.size=Vector2i(1440,900)
	root.get_node("Preferences").reset_defaults()
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	if "--legacy-starter" in OS.get_cmdline_user_args():
		capture_prefix="tv-legacy-"
		var saved: Dictionary=session.world.snapshot_for_save()
		for home: Dictionary in saved.lots.values():
			home.objects=home.objects.filter(func(item): return item.kind!="floor_lamp")
			for item: Dictionary in home.objects:
				if item.kind=="tv": item.rotation=0
		assert(session.world.restore_saved(JSON.parse_string(JSON.stringify(saved))))
		assert(session.world.prepare_continuation(session.profile_id).interrupted==0)
	family=session.state.families[session.profile_id]; lot=session.state.lots[family.home_lot]
	for item: Dictionary in lot.objects:
		if item.kind=="tv": tv=item
		if item.kind=="sofa": seat=item
	for member: Dictionary in family.members: member.autonomy=false; member.needs.fun=0.0
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _settle()
	var first: Dictionary=family.members[0]; var second: Dictionary=family.members[1]
	await _watch(first); await _capture("starter-seated")
	await _watch(second)
	assert(first.task.tv_seat==seat.id and second.task.tv_seat=="")
	await _capture("starter-day")
	session.state.day_minutes=0; await _capture("starter-night")
	root.size=Vector2i(1280,720); root.get_node("Preferences").set_value("ui_scale",1.25)
	await _capture("compact-night"); session.state.day_minutes=720; await _capture("compact-day")
	root.size=Vector2i(1440,900); root.get_node("Preferences").set_value("ui_scale",1.0)
	# Isolated review layout uses real catalog models and actual gameplay camera.
	lot.objects=[tv,seat]; lot.walls=[]; lot.doors=[]; lot.windows={}; lot.revision+=1
	for kind: String in TV.SEATS:
		for review in range(5):
			var turn := review%4
			for member: Dictionary in family.members: session.world._clear_member(member); member.x=3; member.y=5; member.needs.fun=0.0
			second.x=12; second.y=12
			first.character=Character.of(first).duplicate(true)
			first.character.age=2 if review in [1,4] else 6 if turn==2 else 5
			first.character.height=0 if turn==2 else 100 if turn==3 else 50
			first.character.build=100 if turn==3 else 50
			seat.kind=kind; seat.x=7; seat.y=7; seat.rotation=turn; tv.rotation=(turn+2)%4
			var at := TV.center(seat)+TV.front(seat)*3
			tv.x=floori(at.x); tv.y=floori(at.y); lot.revision+=1
			await _watch(first)
			assert(first.task.tv_seat==seat.id)
			var before: Dictionary=session.world.snapshot()
			var node: Node3D=view.projection.scene.resident_nodes[first.id]
			var furniture: Node3D=view.projection.scene.object_nodes[seat.id]
			var body: Node3D=node.get_node("Body")
			assert(node.basis.z.dot(furniture.basis.z)>0.999)
			assert(node.position.distance_to(furniture.position)<0.2)
			assert(is_equal_approx(body.get_node("Leg_L/Knee_L").rotation.x,PI/2))
			assert(view.resident_anchor(first).distance_to(view.projection.project(node.global_position))<0.01)
			if native: ModelPoints.resident_surface(view,first)
			view.zoom=1.8; view._layout(); await _capture(kind+("-child-front" if review==4 else "-turn-%d" % turn))
			assert(session.world.snapshot()==before,"Rendering and mesh picking leave paths, reservations, needs and rewards unchanged")
	root.get_node("Preferences").set_value("reduced_motion",true)
	await _settle()
	var node: Node3D=view.projection.scene.resident_nodes[first.id]
	var pose: Transform3D=node.get_node("Body/Arm_R").transform
	view._time+=2; view.projection.sync(2)
	assert(node.get_node("Body/Arm_R").transform==pose)
	seat.x+=5; lot.revision+=1; await _settle()
	assert(view._activity_pose(first).is_empty(),"Stale moved seating cannot retain a seated pose")
	seat.x-=5; lot.revision+=1; await _settle()
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	await _settle()
	assert(node.get_node("Body/Leg_L/Knee_L").rotation==Vector3.ZERO)
	assert(node.position.x==first.x+0.5 and node.position.z==first.y+0.5)
	print("TELEVISION_POSE_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
