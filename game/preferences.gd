extends Node
## User-owned presentation/input preferences. Never stored in a world save.
signal changed

const Persistence = preload("res://game/persistence.gd")
const ACTION_NAMES := {
	"pause":"Pause / game menu", "console":"Developer console", "rotate":"Rotate furnishing",
	"quick_save":"Quick save", "fullscreen":"Toggle fullscreen", "neighborhood":"Neighborhood",
	"build":"Build / live mode", "home":"Go home", "cancel":"Cancel resident actions",
	"focus_resident":"Find selected resident", "play_pause":"Pause / resume solo time",
	"speed_normal":"Normal time (1×)", "speed_fast":"Fast time (2×)", "speed_faster":"Faster time (4×)"
}
const DEFAULTS := {
	"master_volume":0.8, "music_volume":0.35, "effects_volume":0.7, "ambience_volume":0.35,
	"fullscreen":false, "vsync":true, "fps_limit":60, "ui_scale":1.0,
	"reduced_motion":false, "quality":"high", "first_day_guide":true,
	"bindings":{"pause":KEY_ESCAPE,"console":KEY_QUOTELEFT,"rotate":KEY_R,
		"quick_save":KEY_F5,"fullscreen":KEY_F11,"neighborhood":KEY_N,"build":KEY_B,"home":KEY_H,"cancel":KEY_X,"focus_resident":KEY_F,"play_pause":KEY_P,"speed_normal":KEY_1,"speed_fast":KEY_2,"speed_faster":KEY_3}
}
const VOLUMES := {"master_volume":"Master","music_volume":"Music","effects_volume":"Effects","ambience_volume":"Ambience"}
var values: Dictionary = DEFAULTS.duplicate(true)
var settings_path := "user://settings.json"
var last_error := ""
var _loading := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--settings-path="):
			settings_path=argument.trim_prefix("--settings-path=")
	# Checks with isolated profiles also receive isolated settings unless overridden.
	if settings_path == "user://settings.json":
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--profile-path="):
				settings_path=argument.trim_prefix("--profile-path=")+".settings.json"
	load_and_apply()

func load_and_apply() -> void:
	last_error=""
	_loading=true
	values=DEFAULTS.duplicate(true)
	var reply: Dictionary=Persistence.read_json(settings_path)
	if reply.get("ok",false):
		var data: Dictionary=reply.data
		for key in DEFAULTS:
			if key != "bindings" and data.has(key) and _valid_value(key,data[key]):
				values[key]=data[key]
		# Validate the complete key map before replacing any binding, so saved swaps work.
		if data.get("bindings") is Dictionary:
			var bindings := _upgraded_bindings(data.bindings)
			if _valid_bindings(bindings):
				for action in DEFAULTS.bindings:
					values.bindings[action]=int(bindings[action])
	elif reply.get("exists",false):
		last_error="Settings could not be read; defaults are active."
	_loading=false
	apply()
	changed.emit()

func set_value(key: String,value: Variant) -> bool:
	if key=="bindings" or not _valid_value(key,value):
		last_error="Invalid setting: "+key
		return false
	var previous: Variant=values[key]
	values[key]=value
	if not save():
		values[key]=previous
		return false
	apply()
	changed.emit()
	return true

func bind_action(action: String,keycode: int) -> Dictionary:
	if not DEFAULTS.bindings.has(action):
		return {"ok":false,"message":"Unknown action."}
	if keycode<=0 or keycode>KEY_UNKNOWN or keycode in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:
		return {"ok":false,"message":"Choose a regular key, not a modifier."}
	if (keycode==KEY_ESCAPE and action!="pause") or (keycode==KEY_F1 and action!="console"):
		return {"ok":false,"message":"Escape is reserved for menus; F1 always opens the console."}
	for other in values.bindings:
		if other!=action and int(values.bindings[other])==keycode:
			return {"ok":false,"message":"Already used by "+str(ACTION_NAMES[other])+". Rebind that action first."}
	var previous: int=int(values.bindings[action])
	values.bindings[action]=keycode
	if not save():
		values.bindings[action]=previous
		return {"ok":false,"message":last_error}
	_apply_bindings()
	changed.emit()
	return {"ok":true,"message":str(ACTION_NAMES[action])+" bound to "+OS.get_keycode_string(keycode)+"."}

func reset_defaults() -> bool:
	var previous:=values.duplicate(true)
	values=DEFAULTS.duplicate(true)
	if not save():
		values=previous
		return false
	apply()
	changed.emit()
	return true

func action_label(action: String) -> String:
	var key := int(values.bindings.get(action,0))
	return "` (backtick)" if key==KEY_QUOTELEFT else OS.get_keycode_string(key)

func save() -> bool:
	if not Persistence.write_json(settings_path,values):
		last_error="Could not save settings. Check folder permissions and free disk space."
		return false
	last_error=""
	return true

func apply() -> void:
	_ensure_audio_buses()
	for key in VOLUMES:
		var index:=AudioServer.get_bus_index(VOLUMES[key])
		var volume:=float(values[key])
		AudioServer.set_bus_mute(index,volume<=0.001)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volume,0.0001)))
	_apply_bindings()
	Engine.max_fps=int(values.fps_limit)
	if DisplayServer.get_name()!="headless":
		var desired_vsync:=DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode()!=desired_vsync:
			DisplayServer.window_set_vsync_mode(desired_vsync)
		var window:=get_window()
		var desired_mode:=Window.MODE_FULLSCREEN if values.fullscreen else Window.MODE_WINDOWED
		if window.mode!=desired_mode:
			window.mode=desired_mode
		if not is_equal_approx(window.content_scale_factor,float(values.ui_scale)):
			window.content_scale_factor=float(values.ui_scale)

func _ensure_audio_buses() -> void:
	for bus_name in ["Music","Effects","Ambience"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			var index:=AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus_name)
			AudioServer.set_bus_send(index,"Master")

func _apply_bindings() -> void:
	for action in DEFAULTS.bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event:=InputEventKey.new()
		event.physical_keycode=int(values.bindings[action])
		InputMap.action_add_event(action,event)
		var fallback: int=KEY_ESCAPE if action=="pause" else KEY_F1 if action=="console" else 0
		if fallback>0 and fallback!=int(values.bindings[action]):
			var rescue:=InputEventKey.new()
			rescue.physical_keycode=fallback
			InputMap.action_add_event(action,rescue)

func _valid_value(key: String,value: Variant) -> bool:
	if VOLUMES.has(key):
		return _finite_number(value) and float(value)>=0.0 and float(value)<=1.0
	match key:
		"fullscreen","vsync","reduced_motion","first_day_guide": return value is bool
		"fps_limit": return _finite_number(value) and value in [0,30,60,120]
		"ui_scale": return _finite_number(value) and float(value) in [0.9,1.0,1.1,1.25]
		"quality": return value is String and value in ["low","high"]
	return false

func _upgraded_bindings(saved: Dictionary) -> Dictionary:
	var bindings := {}
	for action: String in DEFAULTS.bindings:
		if saved.has(action):
			if not _finite_number(saved[action]) or float(saved[action])!=floorf(float(saved[action])): return {}
			bindings[action]=int(saved[action])
	# Reserve every saved key before upgrading older complete maps. New actions
	# receive an unused key; a missing original action still fails validation.
	var introduced := {"focus_resident":[KEY_F,KEY_C,KEY_G],"play_pause":[KEY_P,KEY_0],"speed_normal":[KEY_1,KEY_F6],"speed_fast":[KEY_2,KEY_F7],"speed_faster":[KEY_3,KEY_F8]}
	for action: String in introduced:
		if bindings.has(action): continue
		var candidates: Array=introduced[action].duplicate()
		for key in range(KEY_A,KEY_Z+1): candidates.append(key)
		for key: int in candidates:
			if not key in bindings.values(): bindings[action]=key; break
	return bindings

func _valid_bindings(bindings: Dictionary) -> bool:
	var seen: Array=[]
	for action in DEFAULTS.bindings:
		var value: Variant=bindings.get(action)
		if not _finite_number(value) or float(value)!=floorf(float(value)):
			return false
		var key:=int(value)
		if key<=0 or key>KEY_UNKNOWN or key in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META] or seen.has(key): return false
		if (key==KEY_ESCAPE and action!="pause") or (key==KEY_F1 and action!="console"): return false
		seen.append(key)
	return true

func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
