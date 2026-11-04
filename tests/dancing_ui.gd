extends SceneTree
const Leisure = preload("res://game/shared_leisure.gd")
var game: Control
var session: Node
var sound: Node
var view: Control
var stereo: Dictionary
var first: Dictionary
var second: Dictionary
var visitor: Dictionary
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true); await process_frame

func _button(button: Button) -> void:
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
	assert(root.get_texture().get_image().save_png("res://build/dancing-"+name+suffix+".png")==OK)

func _arrive(count: int) -> void:
	for tick in range(120):
		session.world.step(0.1); await process_frame
		if Leisure.players(session.state,"lot_1",stereo.id).size()==count:
			session.world.step(0.1); game._refresh(); await create_timer(0.35).timeout; return
	assert(false,"Dancers did not reach their spots")

func _record(name: String, seconds: float) -> float:
	var recorder := AudioEffectRecord.new(); recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var bus := AudioServer.get_bus_index("Master"); var index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus,recorder); recorder.set_recording_active(true)
	await create_timer(seconds).timeout
	recorder.set_recording_active(false)
	var stream := recorder.get_recording(); AudioServer.remove_bus_effect(bus,index)
	assert(stream!=null and stream.stereo and not stream.data.is_empty())
	assert(stream.save_to_wav("res://build/dancing-"+name+suffix+".wav")==OK)
	var energy := 0.0
	for byte in range(0,stream.data.size()-1,2):
		var sample := float(stream.data.decode_s16(byte))/32768.0
		assert(absf(sample)<0.999,"Music output must not clip"); energy+=sample*sample
	return energy/float(stream.data.size()/2)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); sound=root.get_node("Soundscape")
	session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("violet","Violet")
	for family: Dictionary in session.state.families.values():
		session.world.set_online(family.id,true)
		for resident: Dictionary in family.members:
			resident.autonomy=false; resident.needs.fun=5.0; resident.needs.social=10.0
	first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]; visitor=session.state.families.violet.members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.stereo)
	await _mouse(view.grid_point(8.5,5.5))
	stereo=session.state.lots.lot_1.objects[-1]
	assert(stereo.kind=="stereo" and session.state.lots.lot_1.funds==11740)
	for rotation in range(4):
		if rotation>0:
			session.command({"type":"move_object","lot_id":"lot_1","object_id":stereo.id,"x":8,"y":5,"rotation":rotation}); assert(session.last_action_ok)
		await _capture("rotation-%d" % rotation); assert(view.hit_target(_point()).id==stereo.id)
	await _button(game.mode_button); game.context_panel.hide()
	await _mouse(_point()); assert(first.task.is_empty()); await _button(game.recreation_panel.single_button); assert(first.task.target_id==stereo.id)
	await _arrive(1); await _capture("solo")
	assert(first.action=="Dancing" and view._activity_pose(first).kind=="stereo")
	if sound.enabled: assert(sound._dance_music.playing and sound._dance_music.bus=="Music")
	# A visiting family chooses to participate; Robin joins through the People UI.
	assert(session.world.apply_command("violet",{"type":"visit","member_id":visitor.id,"lot_id":"lot_1"}).ok)
	assert(session.world.apply_command("violet",{"type":"interact","member_id":visitor.id,"lot_id":"lot_1","target_id":stereo.id}).ok)
	await _arrive(2)
	await _button(game.family_box.get_child(1)); await _button(game.people_button)
	assert(game.leisure_buttons[visitor.id].text=="Join dance")
	await _button(game.leisure_buttons[visitor.id]); await _arrive(3)
	assert(second.task.target_id==stereo.id and first.action=="Dancing together" and visitor.action=="Dancing together")
	assert(game.leisure_buttons[visitor.id].text=="Dancing here" and game.leisure_buttons[visitor.id].disabled)
	assert(Leisure.place(first)!=Leisure.place(second) and Leisure.place(second)!=Leisure.place(visitor))
	await _capture("company")
	await _button(game.people_button); await _button(game.queue_label)
	assert(game._plan_detail.text.contains("Dancing together") and game._plan_detail.text.contains("Fun + social"))
	await _capture("plan")
	prefs.set_value("reduced_motion",true); await _capture("reduced-motion")
	assert(view._activity_pose(second).kind=="stereo")
	prefs.set_value("reduced_motion",false)
	if sound.enabled:
		await create_timer(0.3).timeout
		assert(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Score"))<=-17.0,"Background score makes room for the stereo")
		var starts: int=sound.dance_tracks_started
		for update in range(5):
			session.world.state=session.world.snapshot(); game._refresh(); await process_frame
		assert(sound.dance_tracks_started==starts,"Repeated snapshots and multiple dancers cannot restart or stack the music")
		# Isolate the actual speaker from the background score and ambient bed.
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Score"),true)
		prefs.set_value("effects_volume",0.0); prefs.set_value("ambience_volume",0.0)
		await create_timer(0.15).timeout
		assert(sound._dance_music.playing and await _record("music",0.5)>0.000001,"Effects mute leaves music audible on its own bus")
		prefs.set_value("music_volume",0.0); await create_timer(0.15).timeout
		assert(not sound._dance_music.playing and await _record("muted",0.3)<0.00000001)
		prefs.set_value("music_volume",0.35); await create_timer(0.3).timeout
		assert(sound._dance_music.playing)
		await _button(game.time_buttons[0]); await create_timer(0.1).timeout
		assert(not sound._dance_music.playing,"Pausing solo simulation stops the stereo")
		await _button(game.time_buttons[1]); await create_timer(0.3).timeout
		assert(sound._dance_music.playing)
		session.menu_paused=true; await create_timer(0.1).timeout; assert(not sound._dance_music.playing)
		session.menu_paused=false; await create_timer(0.2).timeout
		var old_pan: Vector2=view.pan; view.pan=Vector2(5000,0); await create_timer(0.1).timeout
		assert(not sound._dance_music.playing,"Offscreen speakers stop")
		view.pan=old_pan; await create_timer(0.2).timeout; assert(sound._dance_music.playing)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Score"),false)
	# Cancelling one member keeps the others dancing; construction recalls visitors.
	first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]; visitor=session.state.families.violet.members[0]
	var first_task: String=first.task.id
	session.command({"type":"cancel","member_id":second.id}); game._refresh(); await process_frame
	assert(first.task.id==first_task and not visitor.task.is_empty())
	await _button(game.mode_button); await _capture("construction")
	assert(visitor.lot_id=="lot_2" and first.task.is_empty() and second.task.is_empty())
	if sound.enabled: assert(not sound._dance_music.playing)
	await _button(game.mode_button)
	print("DANCING_UI_PASS")
	await sound.shutdown_and_wait(); quit()
