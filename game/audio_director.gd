extends Node
signal shutdown_finished
signal world_sound_started(sound: String, position: Vector2)
## Original generated music and UI sounds. Mix controls live on named audio buses.
const MUSIC_PATHS := {"menu":"res://assets/audio/menu.wav","live":"res://assets/audio/live.wav","build":"res://assets/audio/build.wav"}
const EFFECT_PATHS := {"hover":"res://assets/audio/hover.wav","click":"res://assets/audio/click.wav","confirm":"res://assets/audio/confirm.wav","company":"res://assets/audio/confirm.wav","error":"res://assets/audio/error.wav","save":"res://assets/audio/save.wav","build":"res://assets/audio/place.wav"}
const WORLD_SOUNDS := ["step_wood","step_grass","page","water","tea","meal","fabric","shower","chat","television","game_piece"]
var context := "silent"
var enabled := false
var _music: Array[AudioStreamPlayer]=[]
var _effects: Array[AudioStreamPlayer]=[]
var _ambience: AudioStreamPlayer
var _world_effects: Array[AudioStreamPlayer2D]=[]
var _dance_music: AudioStreamPlayer2D
var _dance_key := ""
var dance_tracks_started := 0
var _score_bus := -1
var _world_active := false
var _world_context := ""
var world_sounds_started := 0
var _streams: Dictionary={}
var _active_music:=0
var _effect_cursor:=0
var _last_hover:=0
var _fade: Tween
var _shutdown_pending := false
var _shutdown_complete := false

func _ready() -> void:
	enabled=DisplayServer.get_name()!="headless" and not OS.has_feature("dedicated_server") and not "--server" in OS.get_cmdline_user_args() and not "--native-smoke" in OS.get_cmdline_user_args()
	process_mode=Node.PROCESS_MODE_ALWAYS
	if not enabled: return
	_score_bus=AudioServer.get_bus_index("Score")
	if _score_bus<0:
		AudioServer.add_bus(); _score_bus=AudioServer.bus_count-1
		AudioServer.set_bus_name(_score_bus,"Score"); AudioServer.set_bus_send(_score_bus,"Music")
	AudioServer.set_bus_volume_db(_score_bus,0.0)
	_dance_music=AudioStreamPlayer2D.new(); _dance_music.bus="Music"; _dance_music.panning_strength=0.65
	_dance_music.volume_db=-60; add_child(_dance_music)
	for index in range(2):
		var player:=AudioStreamPlayer.new()
		player.bus="Score"
		player.volume_db=-60
		add_child(player)
		_music.append(player)
	for index in range(5):
		var player:=AudioStreamPlayer.new()
		player.bus="Effects"
		add_child(player)
		_effects.append(player)
	for index in range(4):
		var player := AudioStreamPlayer2D.new()
		player.bus="Effects"; player.panning_strength=0.65; player.attenuation=1.0
		add_child(player); _world_effects.append(player)
	Preferences.changed.connect(func():
		if float(Preferences.values.master_volume)<=0.0: stop_world()
		elif float(Preferences.values.effects_volume)<=0.0:
			for player: AudioStreamPlayer2D in _world_effects: player.stop()
		if float(Preferences.values.music_volume)<=0.0: _stop_dance())
	_ambience=AudioStreamPlayer.new()
	_ambience.bus="Ambience"
	_ambience.volume_db=-60
	_ambience.stream=_stream("res://assets/audio/garden.wav",true)
	add_child(_ambience)

func _process(delta: float) -> void:
	if not enabled or _score_bus<0: return
	var playing := is_instance_valid(_dance_music) and _dance_music.playing
	var target := -18.0 if playing else 0.0
	AudioServer.set_bus_volume_db(_score_bus,move_toward(AudioServer.get_bus_volume_db(_score_bus),target,delta*90.0))
	if playing: _dance_music.volume_db=move_toward(_dance_music.volume_db,-10.0,delta*200.0)

func sync_dance(key: String, position: Vector2) -> void:
	if not enabled or not _world_active or context!="live" or key.is_empty() or float(Preferences.values.master_volume)<=0.0 or float(Preferences.values.music_volume)<=0.0:
		_stop_dance(); return
	_dance_music.position=position
	_dance_music.max_distance=maxf(get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y)*1.2
	if key==_dance_key and _dance_music.playing: return
	_stop_dance(); _dance_key=key
	_dance_music.stream=_stream("res://assets/audio/dance.wav",true)
	_dance_music.volume_db=-60; _dance_music.play(); dance_tracks_started+=1

func _stop_dance() -> void:
	_dance_key=""
	if is_instance_valid(_dance_music): _dance_music.stop()

func _stream(path: String,looping: bool=false) -> AudioStream:
	if _streams.has(path): return _streams[path]
	var source:=load(path) as AudioStreamWAV
	if source==null: return null
	var stream:=source.duplicate() as AudioStreamWAV
	if looping:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=int(stream.get_length()*stream.mix_rate)
	_streams[path]=stream
	return stream

func set_context(next_context: String) -> void:
	if not next_context in ["menu","live","build","silent"] or next_context==context: return
	context=next_context
	if context!="live": stop_world()
	if not enabled: return
	if _fade!=null and _fade.is_valid(): _fade.kill()
	var duration:=0.15 if Preferences.values.reduced_motion else 1.1
	_fade=create_tween().set_parallel(true)
	if next_context=="silent":
		for player in _music:
			_fade.tween_property(player,"volume_db",-60.0,duration)
		_fade.tween_property(_ambience,"volume_db",-60.0,duration)
		_fade.finished.connect(_stop_silent)
		return
	var previous: AudioStreamPlayer=_music[_active_music]
	_active_music=1-_active_music
	var current: AudioStreamPlayer=_music[_active_music]
	current.stream=_stream(MUSIC_PATHS[next_context],true)
	current.volume_db=-60
	current.play()
	_fade.tween_property(previous,"volume_db",-60.0,duration)
	_fade.tween_property(current,"volume_db",-5.0,duration)
	if next_context in ["live","build"]:
		if not _ambience.playing: _ambience.play()
		_fade.tween_property(_ambience,"volume_db",-2.0,duration)
	else:
		_fade.tween_property(_ambience,"volume_db",-60.0,duration)

func _stop_silent() -> void:
	if context!="silent": return
	for player in _music: player.stop()
	_ambience.stop()

func play_ui(event: String) -> void:
	if not enabled or not EFFECT_PATHS.has(event): return
	if event=="hover":
		var now:=Time.get_ticks_msec()
		if now-_last_hover<100: return
		_last_hover=now
	var player: AudioStreamPlayer=_effects[_effect_cursor]
	_effect_cursor=(_effect_cursor+1)%_effects.size()
	player.stream=_stream(EFFECT_PATHS[event])
	player.volume_db=-8.0 if event in ["hover","company"] else -2.0
	player.play()

func attach_controls(root: Node) -> void:
	# Attach once, and observe newly generated catalog/menu controls as they arrive.
	if root==null or root.has_meta("simulateds_audio_hook"): return
	root.set_meta("simulateds_audio_hook",true)
	root.child_entered_tree.connect(attach_controls)
	if root is BaseButton:
		var button := root as BaseButton
		button.pressed.connect(func(): play_ui("click"))
		button.mouse_entered.connect(func():
			if is_instance_valid(button) and not button.disabled: play_ui("hover"))
		button.focus_entered.connect(func():
			if is_instance_valid(button) and not button.disabled: play_ui("hover"))
	for child in root.get_children(): attach_controls(child)

func sync_world(active: bool, key: String) -> void:
	if not active or key!=_world_context: stop_world()
	_world_context=key
	_world_active=active and enabled and context=="live"

func play_world(event: Dictionary) -> bool:
	if not enabled or not _world_active or context!="live" or not event.get("sound") in WORLD_SOUNDS: return false
	if float(Preferences.values.master_volume)<=0.0 or float(Preferences.values.effects_volume)<=0.0: return false
	# Never steal an active voice. Dropping a quiet texture is better than a click.
	for player: AudioStreamPlayer2D in _world_effects:
		if player.playing: continue
		var sound: String=event.sound
		player.position=event.position
		player.set_meta("member",str(event.get("member",""))); player.set_meta("task",str(event.get("task","")))
		player.max_distance=maxf(get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y)*1.2
		player.stream=_stream("res://assets/audio/"+sound+".wav")
		player.pitch_scale=clampf(float(event.get("pitch",1.0)),0.95,1.05)
		player.volume_db=-18.0 if sound.begins_with("step_") or sound=="chat" else -12.0
		player.play(); world_sounds_started+=1
		world_sound_started.emit(sound,player.position)
		return true
	return false

func update_world_sources(sources: Dictionary) -> void:
	for player: AudioStreamPlayer2D in _world_effects:
		if not player.playing: continue
		var source: Dictionary=sources.get(str(player.get_meta("member","")),{})
		if source.is_empty() or source.task!=str(player.get_meta("task","")): player.stop()
		else: player.position=source.position

func stop_world() -> void:
	_world_active=false
	_stop_dance()
	for player: AudioStreamPlayer2D in _world_effects: player.stop()

func shutdown() -> void:
	# Release playback references before SceneTree destroys the audio server.
	# Explicitly clearing streams also releases resources cached for UI effects.
	enabled=false
	context="silent"
	if _fade!=null and _fade.is_valid(): _fade.kill()
	_fade=null
	stop_world()
	if is_instance_valid(_dance_music): _dance_music.stream=null
	if _score_bus>=0: AudioServer.set_bus_volume_db(_score_bus,0.0)
	for player: AudioStreamPlayer2D in _world_effects: player.stream=null
	for player in _music+_effects:
		if is_instance_valid(player):
			player.stop()
			player.stream=null
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream=null
	_streams.clear()

func shutdown_and_wait() -> void:
	# AudioStreamPlayer.stop is consumed by the audio mixer asynchronously. Keep
	# the tree alive briefly so its final playback references are released before
	# Godot tears AudioServer down. Window close and Quit both await this boundary.
	if _shutdown_complete: return
	if _shutdown_pending:
		await shutdown_finished
		return
	_shutdown_pending=true
	var had_audio:=enabled
	shutdown()
	var tree:=get_tree()
	if tree!=null:
		await tree.process_frame
		if had_audio:
			await tree.create_timer(0.15,true,false,true).timeout
	_shutdown_complete=true
	_shutdown_pending=false
	shutdown_finished.emit()

func _exit_tree() -> void:
	shutdown()
	_music.clear()
	_effects.clear()
	_world_effects.clear()
	_ambience=null
	_dance_music=null
