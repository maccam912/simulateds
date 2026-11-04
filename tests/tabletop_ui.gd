extends SceneTree
const Tabletop = preload("res://game/tabletop.gd")
var game: Control
var session: Node
var view: Control
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _button(button: Button) -> void:
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(button.get_global_rect()))
	await _click(button.get_global_rect().get_center())

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.3).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/tabletop-"+name+suffix+".png")==OK)

func _table() -> Dictionary:
	for object: Dictionary in session.state.lots.lot_1.objects:
		if object.kind=="game_table": return object
	return {}

func _board_point() -> Vector2:
	view._layout()
	return view.grid_point(9,6)+Vector2(0,-22.5*view._cell.x/48.0)

func _visible_board_point(object_id: String) -> Vector2:
	view._layout()
	for x: float in [0.43,0.81,1.19,1.57]:
		for y: float in [0.43,0.81,1.19,1.57]:
			var point: Vector2=view.grid_point(8+x,5+y)+Vector2(0,-22.5*view._cell.x/48.0)
			var target: Dictionary=view.hit_target(point)
			if target.get("type")=="object" and target.get("id")==object_id: return point
	assert(false,"The tabletop must have an uncovered visible click target")
	return Vector2.ZERO

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true); session.world.set_online("neighbor",true)
	for family: Dictionary in session.state.families.values():
		for resident: Dictionary in family.members: resident.autonomy=false; resident.needs.fun=10.0; resident.needs.social=10.0
	var first: Dictionary=session.state.families[session.profile_id].members[0]
	var visitor: Dictionary=session.state.families.neighbor.members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await process_frame; await process_frame
	await _button(game.mode_button)
	assert(game.catalog_buttons.has("game_table"))
	await _button(game.catalog_buttons.game_table)
	view._layout(); await _click(view.grid_point(8.5,5.5))
	assert(not _table().is_empty() and session.state.lots.lot_1.funds==11660,"The catalog and ground click buy the new furnishing")
	var table: Dictionary=_table(); var object_id: String=table.id
	await _button(game.undo_button); assert(_table().is_empty() and session.state.lots.lot_1.funds==12000)
	await _button(game.redo_button); table=_table(); assert(table.id==object_id and session.state.lots.lot_1.funds==11660)
	for rotation in range(4):
		if rotation>0:
			session.command({"type":"move_object","lot_id":"lot_1","object_id":object_id,"x":8,"y":5,"rotation":rotation}); assert(session.last_action_ok)
		await _capture("rotation-%d" % rotation)
		assert(view.hit_target(_board_point()).get("id")==object_id,"The whole rotated tabletop remains a visible click target")
	await _button(game.mode_button)
	game.context_panel.hide(); await _capture("ready")
	await _click(_visible_board_point(object_id))
	assert(first.task.get("target_id")==object_id,"Clicking the uncovered board queues a game for the selected resident")
	await _button(game.queue_label)
	for tick in range(100):
		session.world.step(0.1)
		if first.task.get("elapsed",0)>0.5: break
	await _capture("solo")
	assert(first.action=="Playing a tabletop puzzle" and game._plan_progress.visible)
	assert(session.world.apply_command("neighbor",{"type":"visit","member_id":visitor.id,"lot_id":"lot_1"}).ok)
	assert(session.world.apply_command("neighbor",{"type":"interact","member_id":visitor.id,"lot_id":"lot_1","target_id":object_id}).ok)
	for tick in range(100):
		session.world.step(0.1)
		if Tabletop.players(session.state,"lot_1",object_id).size()==2: break
	session.world.step(0.1); game._refresh()
	var point := _board_point(); var motion := InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true)
	await _capture("together")
	assert(first.action=="Playing together" and visitor.action=="Playing together" and "Fun + social" in game._plan_detail.text)
	assert(Tabletop.place(first)!=Tabletop.place(visitor))
	# Exercise the actual positional voice with the new original texture.
	if DisplayServer.get_name()!="headless":
		prefs.set_value("music_volume",0.0); prefs.set_value("ambience_volume",0.0)
		var sound: Node=root.get_node("Soundscape"); var heard := [false]
		sound.world_sound_started.connect(func(name: String,_point: Vector2):
			if name=="game_piece": heard[0]=true)
		var recorder := AudioEffectRecord.new(); recorder.format=AudioStreamWAV.FORMAT_16_BITS
		var bus := AudioServer.get_bus_index("Master"); var effect := AudioServer.get_bus_effect_count(bus)
		AudioServer.add_bus_effect(bus,recorder); recorder.set_recording_active(true)
		session.menu_paused=false
		for attempt in range(60):
			await create_timer(0.1).timeout
			if heard[0]: break
		assert(heard[0],"Actual gameplay must produce its new positional piece sound")
		await create_timer(0.3).timeout
		session.menu_paused=true; recorder.set_recording_active(false)
		var recording := recorder.get_recording(); var peak := 0.0
		for sample_index in range(0,recording.data.size()-1,2): peak=maxf(peak,absf(float(recording.data.decode_s16(sample_index))/32768.0))
		assert(peak>0.0001 and peak<0.99,"The actual mixer captures an audible, unclipped household cue")
		assert(recording.save_to_wav("res://build/tabletop-mix"+suffix+".wav")==OK)
		AudioServer.remove_bus_effect(bus,effect)
	var visitor_task: String=visitor.task.id
	await _button(game.plan_controls[first.task.id].cancel)
	session.world.step(0.2)
	assert(visitor.task.id==visitor_task and visitor.action=="Playing a tabletop puzzle","A host can leave the game without interrupting a visitor")
	await _capture("visitor-continues")
	await _button(game.mode_button)
	assert(visitor.lot_id=="lot_2" and visitor.task.is_empty())
	await _capture("construction")
	print("TABLETOP_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
