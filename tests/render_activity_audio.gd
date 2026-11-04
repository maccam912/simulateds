extends SceneTree
var session: Node
var sound: Node
var app: Control
var view: Control
var recorder := AudioEffectRecord.new()
var heard: Array[String]=[]
var member: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _record() -> void:
	recorder.set_recording_active(true)

func _save_recording(name: String) -> AudioStreamWAV:
	recorder.set_recording_active(false)
	var stream := recorder.get_recording()
	assert(stream!=null and stream.stereo and stream.data.size()>0)
	assert(stream.save_to_wav("res://build/activity-audio-"+name+".wav")==OK)
	return stream

func _levels(stream: AudioStreamWAV) -> Vector2:
	var energy := Vector2.ZERO
	var bytes := stream.data
	for index in range(0,bytes.size()-3,4):
		var left := float(bytes.decode_s16(index))/32768.0
		var right := float(bytes.decode_s16(index+2))/32768.0
		assert(absf(left)<0.999 and absf(right)<0.999,"Recorded mix must not clip")
		energy+=Vector2(left*left,right*right)
	return energy/float(bytes.size()/4)

func _cue(name: String, point: Vector2) -> bool:
	return sound.play_world({"sound":name,"member":"probe","task":"probe","position":point,"pitch":1.0})

func _wait_for(name: String, seconds: float=12.0) -> void:
	for index in range(int(seconds*10)):
		if heard.has(name): return
		await create_timer(0.1).timeout
	assert(false,"Actual gameplay did not produce "+name)

func _activity(kind: String) -> void:
	session.command({"type":"cancel","member_id":member.id})
	heard.clear()
	for object: Dictionary in session.state.lots[member.lot_id].objects:
		if object.kind==kind:
			session.command({"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":object.id})
			assert(session.last_action_ok); return
	assert(false,"Fixture furnishing missing")

func _run() -> void:
	assert(DisplayServer.get_name()!="headless","This check measures the real graphical audio mixer")
	root.size=Vector2i(1440,900); DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); sound=root.get_node("Soundscape")
	var prefs: Node=root.get_node("Preferences")
	prefs.reset_defaults(); prefs.set_value("music_volume",0.0); prefs.set_value("ambience_volume",0.0)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for resident: Dictionary in session.state.families[session.profile_id].members: resident.autonomy=false
	member=session.state.families[session.profile_id].members[0]
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout
	app.show_game(); session.menu_paused=true
	view=app.game.lot_view; view.set_process(false)
	assert(sound.enabled and sound._world_effects.size()==4)
	for player: AudioStreamPlayer2D in sound._world_effects: assert(player.bus=="Effects")
	sound.world_sound_started.connect(func(name: String,_point: Vector2): heard.append(name))
	recorder.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"),recorder)
	await create_timer(0.3).timeout
	sound.sync_world(true,"probe"); _record(); assert(_cue("page",Vector2(144,450)))
	await create_timer(0.7).timeout
	var left := _levels(_save_recording("left"))
	_record(); assert(_cue("page",Vector2(1296,450)))
	await create_timer(0.7).timeout
	var right := _levels(_save_recording("right"))
	assert(left.x>left.y*1.2 and right.y>right.x*1.2 and left.x>0.0000001,"The real mixer pans sounds toward their visible sources")
	prefs.set_value("effects_volume",0.0); await create_timer(0.2).timeout
	_record(); assert(not _cue("page",Vector2(720,450))); sound.play_ui("click")
	await create_timer(0.3).timeout
	assert(_levels(_save_recording("muted")).length()<0.00000001,"Effects mute silences both world and UI sounds")
	prefs.set_value("effects_volume",0.7); sound.sync_world(true,"probe")
	_record()
	for index in range(4): assert(_cue("shower",Vector2(400+index*150,450)))
	assert(not _cue("shower",Vector2(720,450)),"The fifth household voice is dropped without cutting another voice")
	sound.play_ui("confirm")
	assert(sound._effects.any(func(player): return player.playing),"Interface sounds retain their own voices")
	await create_timer(1.0).timeout
	_levels(_save_recording("busy"))
	sound.stop_world(); assert(sound._world_effects.all(func(player): return not player.playing))
	sound.sync_world(true,"probe"); assert(_cue("page",Vector2(720,450)))
	sound.update_world_sources({"probe":{"task":"changed","position":Vector2(720,450)}})
	assert(sound._world_effects.all(func(player): return not player.playing),"Canceling or replacing a task stops its texture")
	assert(_cue("page",Vector2(720,450)))
	prefs.set_value("master_volume",0.0)
	assert(sound._world_effects.all(func(player): return not player.playing) and not _cue("page",Vector2(720,450)),"Master mute stops household voices too")
	prefs.set_value("master_volume",0.8)
	# Ordinary accepted walking and recreation, with the normal musical mix.
	view.set_process(true); session.menu_paused=false
	prefs.set_value("music_volume",0.35); prefs.set_value("ambience_volume",0.35)
	heard.clear(); _record()
	session.command({"type":"move","member_id":member.id,"lot_id":member.lot_id,"x":0,"y":0})
	await _wait_for("step_wood")
	await _wait_for("step_grass")
	_activity("bookshelf"); await _wait_for("page",20.0)
	_activity("plant"); await _wait_for("water")
	_activity("table"); await _wait_for("tea")
	await create_timer(0.7).timeout
	_save_recording("playtest")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/activity-audio-playtest.png")==OK)
	# Host simulation keeps running behind menus, but household sounds stop.
	session.role="host"; app.open_pause()
	var count: int=sound.world_sounds_started
	var tick: int=session.state.tick
	await create_timer(0.6).timeout
	assert(session.state.tick>tick and sound.world_sounds_started==count and sound._world_effects.all(func(player): return not player.playing))
	app.show_game(); session.role="offline"
	_activity("bookshelf"); await _wait_for("page")
	view.pan=Vector2(10000,10000); await create_timer(0.1).timeout
	count=sound.world_sounds_started
	assert(sound._world_effects.all(func(player): return not player.playing),"Panning a source offscreen also stops its current texture")
	await create_timer(0.6).timeout; assert(sound.world_sounds_started==count)
	view.pan=Vector2.ZERO; await process_frame
	session.debug_speed=0.0; await process_frame; count=sound.world_sounds_started
	await create_timer(0.4).timeout
	assert(sound.world_sounds_started==count and sound._world_effects.all(func(player): return not player.playing),"A stopped simulation is quiet")
	session.debug_speed=1.0; prefs.set_value("reduced_motion",true)
	session.command({"type":"cancel","member_id":member.id}); heard.clear()
	session.command({"type":"move","member_id":member.id,"lot_id":member.lot_id,"x":0,"y":0})
	await _wait_for("step_wood")
	assert(session.world.apply_command(session.profile_id,{"type":"build_begin","lot_id":member.lot_id}).ok)
	app.game._refresh(); await process_frame
	assert(sound._world_effects.all(func(player): return not player.playing),"Construction stops household activity sound")
	AudioServer.remove_bus_effect(AudioServer.get_bus_index("Master"),0)
	print("ACTIVITY_AUDIO_RENDER_PASS · left/right="+str(left)+" / "+str(right))
	await sound.shutdown_and_wait()
	quit()
