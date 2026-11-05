extends SceneTree
const ModelPoints = preload("res://tests/model_test_points.gd")
var game: Control
var session: Node
var family: Dictionary
var lot: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _object(kind: String) -> Dictionary:
	for object: Dictionary in lot.objects:
		if object.kind==kind: return object
	return {}

func _pose(index: int, kind: String) -> void:
	var member: Dictionary=family.members[index]
	session.world._clear_member(member)
	member.autonomy=false
	for need: String in member.needs: member.needs[need]=10.0
	var object := _object(kind)
	var adjacent: Vector2i=session.world._interaction_cells(lot,object)[0]
	member.x=adjacent.x; member.y=adjacent.y
	# Fixture relocation is not an accepted walk. A paused review cannot finish
	# interpolating a fictitious route from the previous activity's location.
	game.lot_view.motion.tracks.clear()
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":member.id,"lot_id":lot.id,"target_id":object.id}).ok)
	session.world.step(0.1)

func _capture(name: String) -> void:
	game._refresh()
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/activities-"+name+".png")==OK)

func _run() -> void:
	root.size=Vector2i(1440,900)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]; lot=session.state.lots[family.home_lot]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://build")
	for rotation in range(4):
		_object("bed").rotation=rotation; lot.revision+=1
		_pose(0,"bed"); _pose(1,"sofa")
		await _capture("resting-"+str(rotation))
		var head := ModelPoints.resident_surface(game.lot_view,family.members[0])
		assert(game.lot_view.hit_target(head).get("id")==family.members[0].id,"Sleeping resident remains selectable in every rotation")
	_pose(0,"bookshelf"); _pose(1,"table"); await _capture("reading-tea")
	_pose(0,"shower"); _pose(1,"plant"); await _capture("shower-garden")
	_pose(0,"tv"); _pose(1,"fridge"); await _capture("tv-meal")
	for index in range(2):
		var member: Dictionary=family.members[index]
		session.world._clear_member(member); member.x=7+index; member.y=7
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":family.members[0].id,"lot_id":lot.id,"target_id":family.members[1].id}).ok)
	session.world.step(0.1)
	# These fixture positions were assigned directly, without an accepted route.
	game.lot_view.motion.tracks.clear()
	await _capture("conversation")
	assert(game.lot_view._activity_pose(family.members[0]).get("kind")=="chat")
	root.get_node("Preferences").set_value("reduced_motion",true)
	await _capture("reduced-motion")
	print("ACTIVITY_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
