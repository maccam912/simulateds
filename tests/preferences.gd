extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var prefs: Node=root.get_node("Preferences")
	var original_path: String=prefs.settings_path
	prefs.settings_path=original_path+".test"
	assert(prefs.reset_defaults())
	assert(prefs.set_value("master_volume",0.0))
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	assert(prefs.set_value("music_volume",0.25))
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),linear_to_db(0.25)))
	assert(not prefs.set_value("music_volume",2.0))
	assert(not prefs.set_value("music_volume",NAN))
	assert(not prefs.set_value("fps_limit",999))
	assert(not prefs.set_value("ui_scale",0.01))
	assert(prefs.set_value("reduced_motion",true))
	assert(prefs.set_value("quality","low"))
	assert(prefs.bind_action("rotate",KEY_T).ok)
	assert(not prefs.bind_action("build",KEY_T).ok)
	assert(not prefs.bind_action("build",KEY_F1).ok)
	assert(not prefs.bind_action("build",KEY_ESCAPE).ok)
	assert(not prefs.bind_action("rotate",KEY_SHIFT).ok)
	assert(prefs.bind_action("console",KEY_F2).ok)
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_F1
	assert(InputMap.event_is_action(event,"console"),"F1 console safety binding disappeared")
	prefs.values={}
	prefs.load_and_apply()
	assert(prefs.values.reduced_motion and prefs.values.quality=="low")
	assert(is_equal_approx(prefs.values.music_volume,0.25))
	assert(int(prefs.values.bindings.rotate)==KEY_T)
	assert(prefs.action_label("rotate")=="T")
	# An old complete map has no camera action. Keep custom keys and swaps,
	# including a preexisting F, and persist the collision-free migrated binding.
	var legacy: Dictionary=prefs.values.duplicate(true)
	legacy.bindings.erase("focus_resident")
	legacy.bindings.rotate=KEY_F; legacy.bindings.build=KEY_C
	legacy.bindings.home=KEY_N; legacy.bindings.neighborhood=KEY_H
	assert(prefs.Persistence.write_json(prefs.settings_path,legacy))
	prefs.load_and_apply()
	for action: String in legacy.bindings: assert(int(prefs.values.bindings[action])==int(legacy.bindings[action]))
	assert(prefs.values.bindings.focus_resident==KEY_G and prefs.action_label("focus_resident")=="G")
	assert(prefs.save()); prefs.load_and_apply()
	assert(prefs.values.bindings.focus_resident==KEY_G and prefs.values.bindings.rotate==KEY_F)
	legacy.bindings.rotate=KEY_C
	assert(prefs.Persistence.write_json(prefs.settings_path,legacy)); prefs.load_and_apply()
	assert(prefs.values.bindings==prefs.DEFAULTS.bindings,"An invalid duplicate map still falls back as a whole")
	assert(prefs.reset_defaults())
	assert(int(prefs.values.bindings.rotate)==KEY_R)
	var sound: Node=root.get_node("Soundscape")
	assert(not sound.enabled,"Headless test should not play audio")
	sound.set_context("menu")
	sound.play_ui("confirm")
	assert(sound.context=="menu")
	print("PREFERENCES_PASS")
	quit()
