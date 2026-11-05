extends Node
## Persistent neighborhood authority over the template's explicit Iroh packets.
## Clients send intentions; only the host advances or changes the world.

signal status_changed(message: String)
signal chat_received(message: String)
signal session_closed
signal world_changed
signal action_result(message: String)
signal command_completed(intent: Dictionary,ok: bool,message: String)

const WorldModel = preload("res://game/world.gd")
const Persistence = preload("res://game/persistence.gd")
const SaveLibrary = preload("res://game/save_library.gd")
const DebugCommands = preload("res://game/debug_commands.gd")
const PROTOCOL := 4 # Storeys, terrain and expanded construction require a matching reader.
const HouseholdTransfer = preload("res://network/household_transfer.gd")
var _household_transfer = HouseholdTransfer.new()
const MAX_PLAYERS := 4
const CONNECT_TIMEOUT_MS := 18000
const MAX_PACKET := 1024
const CHUNK_BYTES := 600
const MAX_SNAPSHOT_BYTES := 524288
const MAX_COMPRESSED_BYTES := 76800
const MAX_CHUNKS := 128
const SNAPSHOT_INTERVAL := 0.5
const SIMULATION_STEP := 0.1
const PLAY_SPEEDS := [0.0,1.0,2.0,4.0]

var world = WorldModel.new()
var state: Dictionary:
	get:
		return world.state
var peer: MultiplayerPeer
var role := "offline"
var status := "Your neighborhood · saved locally"
var profile_id := ""
var display_name := "Alex"
var local_id := 1
var players: Dictionary = {}
var pending: Dictionary = {}
var snapshots_received := 0
## Local presentation baseline; never serialized or advanced for ordinary snapshots.
var world_generation := 0
## Save-local presentation metadata, never part of the authoritative snapshot.
var solo_view: Dictionary = {}
var solo_view_generation := 0
var capture_solo_view: Callable
var startup_continuation: Dictionary = {}
var last_action_ok := true
var last_action_message := ""
var actions_received := 0
var save_path := "user://neighborhood.json"
var profile_path := "user://profile.json"
var saving_enabled := true
var slots_path := ""
var menu_paused := false
var debug_speed := 1.0
var _resume_speed := 1.0
var _credential := ""
var _offline_state: Dictionary = {}
var _previous_saved: Dictionary = {}
var _welcomed := false
var _started_at := 0
var _simulation_clock := 0.0
var _snapshot_clock := 0.0
var _save_clock := 0.0
var _ui_clock := 0.0
var _snapshot_id := 0
var _outgoing: Dictionary = {}
var _assembly: Dictionary = {}
var _last_snapshot_id := -1
var _last_snapshot_at := 0
var _request_id := 0
var _requests: Dictionary = {}
var _responses: Dictionary = {}
var _highest_request: Dictionary = {}
var _rate: Dictionary = {}
var _last_chat: Dictionary = {}
var _quitting := false
var _dedicated := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path="):
			save_path = argument.trim_prefix("--save-path=")
		elif argument.begins_with("--profile-path="):
			profile_path = argument.trim_prefix("--profile-path=")
		elif argument.begins_with("--slots-path="):
			slots_path = argument.trim_prefix("--slots-path=")
		elif argument.begins_with("--family-name="):
			display_name = argument.trim_prefix("--family-name=").left(32)
	if slots_path.is_empty():
		slots_path = "user://saves" if save_path == "user://neighborhood.json" else save_path.get_basename() + "-slots"
	_dedicated = "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server")
	_load_profile()
	_load_world()
	if world.ensure_family(profile_id, display_name).is_empty():
		_set_status("This neighborhood has no free lot for this profile.")
	else:
		world.set_online(profile_id, not _dedicated)
	players = {1: profile_id}
	if _dedicated:
		call_deferred("_start_server")

func _start_server() -> void:
	if host():
		print("SIMULATEDS_SERVER_READY ticket=" + ticket())
	else:
		push_error(status)
		get_tree().quit(1)

func _load_profile() -> void:
	var result: Dictionary = Persistence.read_json(profile_path)
	if result.get("exists", false) and (not result.ok or not _valid_credential(result.data.get("credential"))):
		profile_path += ".recovered"
		result = Persistence.read_json(profile_path)
	if result.ok and _valid_credential(result.data.get("credential")):
		_credential = result.data.credential
		if display_name == "Alex":
			display_name = str(result.data.get("name", display_name)).left(32)
	else:
		_credential = Crypto.new().generate_random_bytes(32).hex_encode()
		if result.get("exists", false):
			# Preserve malformed credentials for manual recovery; do not silently rotate them.
			profile_path += ".recovered"
		if not Persistence.write_json(profile_path, {"credential": _credential, "name": display_name}):
			_set_status("Profile could not be saved; reconnect identity will not survive restart.")
	profile_id = _credential.sha256_text()

func _load_world() -> void:
	world.initialize()
	solo_view={}
	startup_continuation={}
	var saved := _read_autosave()
	if saved.ok and world.restore_saved(saved.world):
		_previous_saved=saved.data
		if _dedicated:
			for family_id: String in state.families: world.set_online(family_id,false)
		else:
			startup_continuation=world.prepare_continuation(profile_id)
			solo_view=_validated_solo_view(saved.view)
			_set_loaded_clock(true)
			if saved.recovered: startup_continuation.message="Recovered neighborhood from its last valid backup."
		if saved.recovered: _set_status("Recovered neighborhood from its last valid backup.")
	elif FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak"):
		saving_enabled=false
		_set_status("Save could not be read. Started a temporary world; existing save is protected.")

func available() -> bool:
	if not ClassDB.class_exists("IrohServer") or not ClassDB.class_exists("IrohClient"):
		return false
	if OS.has_feature("android"):
		return Engine.has_singleton("IrohAndroid") and bool(Engine.get_singleton("IrohAndroid").call("initializeIroh"))
	return true

func is_authority() -> bool:
	return role in ["offline", "host"]

func set_display_name(value: String) -> void:
	value = value.strip_edges().left(24)
	if value.is_empty():
		_emit_action(false, "Choose a name for your resident.")
		return
	if not Persistence.write_json(profile_path, {"credential": _credential, "name": value}):
		_emit_action(false, "Could not save your profile name.")
		return
	display_name = value
	if state.get("families", {}).has(profile_id):
		command({"type": "rename_family", "name": value})

func home_lot() -> String:
	return str(state.get("families", {}).get(profile_id, {}).get("home_lot", ""))

func host() -> bool:
	leave()
	if not available():
		_set_status("Multiplayer needs the native extension: python3 tools/build_native.py --host-only")
		return false
	peer = ClassDB.class_call_static("IrohServer", "start_configured", "--relay-only" in OS.get_cmdline_user_args())
	if peer == null:
		_set_status("Could not start Iroh. Check network access.")
		return false
	role = "host"
	peer.peer_connected.connect(_peer_connected)
	peer.peer_disconnected.connect(_peer_disconnected)
	world.set_online(profile_id, not _dedicated)
	_set_status("Sharing neighborhood · invite someone with a code or ticket")
	return true

func join(value: String) -> bool:
	leave()
	if not available():
		_set_status("Iroh extension unavailable on this build.")
		return false
	value = value.strip_edges()
	if (not value.begins_with("git1_") and value.length() != 43) or value.length() > 8192:
		_set_status("Enter a four-character code or complete host ticket.")
		return false
	_offline_state = world.snapshot()
	peer = ClassDB.class_call_static("IrohClient", "connect_configured", value, "--relay-only" in OS.get_cmdline_user_args())
	if peer == null:
		_set_status("Could not connect to Iroh.")
		return false
	role = "joining"
	players.clear()
	local_id = 0
	_started_at = Time.get_ticks_msec()
	_last_snapshot_at = _started_at
	_set_status("Connecting to neighborhood…")
	return true

func ticket() -> String:
	return str(peer.call("connection_string")) if role == "host" and peer != null else ""

func leave() -> void:
	world_generation+=1
	var was_client := role in ["joining", "client"]
	if is_authority() and not profile_id.is_empty():
		if role=="host":
			for family_id in players.values():
				world.set_online(str(family_id), false)
		save_world()
	session_closed.emit()
	if peer != null:
		peer.close()
		peer = null
	if was_client and not _offline_state.is_empty():
		world.restore(_offline_state, true)
	_offline_state.clear()
	role = "offline"
	debug_speed = 1.0; _resume_speed=1.0; _simulation_clock=0.0
	local_id = 1
	players = {1: profile_id}
	pending.clear()
	_outgoing.clear()
	_assembly.clear()
	_requests.clear()
	_household_transfer.assemblies.clear()
	_responses.clear()
	_highest_request.clear()
	_rate.clear()
	_last_chat.clear()
	_welcomed = false
	_snapshot_clock = 0.0
	_last_snapshot_id = -1
	snapshots_received = 0
	if not profile_id.is_empty():
		world.set_online(profile_id, not _dedicated)
	_set_status("Your neighborhood · saved locally" if saving_enabled else "Temporary neighborhood · damaged save protected")
	world_changed.emit()

func save_world() -> bool:
	if not is_authority() or not saving_enabled or profile_id.is_empty():
		return false
	var data: Dictionary = world.snapshot_for_save()
	var view := _current_solo_view()
	if not view.is_empty(): data.solo_view=view
	if not Persistence.write_json(save_path, data, _previous_saved):
		_set_status("Could not save neighborhood. Check available disk space and folder permissions.")
		return false
	_previous_saved = data
	return true

func list_saves() -> Array:
	var entries: Array = SaveLibrary.list_slots(slots_path,profile_id)
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak"):
		var saved := _read_autosave()
		var summary := {"id":"autosave", "name":"Current neighborhood (autosave)", "day":0, "minutes":0.0, "modified":FileAccess.get_modified_time(save_path), "valid":bool(saved.ok), "message":str(saved.message)}
		if saved.ok:
			summary.day=int(saved.world.day)
			summary.minutes=float(saved.world.day_minutes)
			summary.modified=FileAccess.get_modified_time(saved.path)
			summary.merge(SaveLibrary.identity(saved.world,profile_id))
		entries.push_front(summary)
	return entries

func _read_autosave() -> Dictionary:
	for path: String in [save_path,save_path + ".bak"]:
		var saved: Dictionary = Persistence.read_json(path)
		if saved.ok:
			var candidate = WorldModel.new()
			if candidate.restore_saved(saved.data):
				var recovered := path.ends_with(".bak")
				return {"ok":true, "world":candidate.state, "data":saved.data, "view":saved.data.get("solo_view",{}), "name":"Current neighborhood (autosave)", "path":path, "recovered":recovered, "message":"Recovered autosave backup." if recovered else "Autosave is ready."}
	return {"ok":false, "message":"Autosave and backup are missing, damaged, or unsupported."}

func save_slot(name: String, id: String = "") -> Dictionary:
	if not is_authority():
		return {"ok":false, "message":"Only the host can save the shared neighborhood."}
	var result: Dictionary = SaveLibrary.write_slot(slots_path,name,world.snapshot_for_save(),id,_current_solo_view())
	if result.ok:
		_set_status(str(result.message))
	return result

func load_slot(id: String) -> Dictionary:
	if role != "offline":
		return {"ok":false, "message":"Disconnect the multiplayer session before loading a different neighborhood."}
	var saved: Dictionary = _read_autosave() if id == "autosave" else SaveLibrary.read_slot(slots_path,id)
	if not saved.ok:
		return saved
	var candidate = WorldModel.new()
	if not candidate.restore_saved(saved.world) or candidate.ensure_family(profile_id,display_name).is_empty():
		return {"ok":false, "message":"This save is invalid or has no free lot for your profile."}
	var name: String=saved.name
	var preserved := _preserve_current("Before loading " + (name.left(32).strip_edges()+"…" if name.length()>33 else name))
	if not preserved.ok:
		return preserved
	var result := _activate_world(candidate,saved.get("view",{}),true)
	if result.ok:
		result.message = "Loaded “%s”." % str(saved.name)
		if saved.get("recovered",false): result.message+=" Used its backup."
		result.id = id
		result.recovery_id = preserved.id
		result.recovery_name = preserved.name
		_set_status(str(result.message))
	return result

func new_world(name: String = "Linden Grove") -> Dictionary:
	if role != "offline":
		return {"ok":false, "message":"Disconnect the multiplayer session before starting a new neighborhood."}
	name=name.strip_edges()
	if name.is_empty() or name.length()>48:
		return {"ok":false, "message":"Choose a neighborhood name between 1 and 48 characters."}
	var candidate = WorldModel.new()
	candidate.initialize()
	candidate.ensure_family(profile_id,display_name)
	candidate.state["neighborhood_name"] = name
	var preserved := _preserve_current("Before new neighborhood")
	if not preserved.ok:
		return preserved
	var result := _activate_world(candidate,{},false)
	if result.ok:
		result.message = "Started “%s”." % name
		result.recovery_id = preserved.id
		result.recovery_name = preserved.name
		_set_status(str(result.message))
	return result

func _preserve_current(label: String) -> Dictionary:
	if not saving_enabled:
		return {"ok":false, "message":"The current autosave is protected after a load error. Save a named copy, then restart with a new --save-path before switching worlds."}
	if not save_world():
		return {"ok":false, "message":"Could not preserve the current neighborhood; no world was replaced."}
	return save_slot(label)

func _activate_world(candidate, saved_view: Variant, continuing: bool) -> Dictionary:
	var report: Dictionary = candidate.prepare_continuation(profile_id)
	candidate.set_online(profile_id,true)
	# Disk write succeeds before replacing the live model; failed loads are atomic.
	var data: Dictionary = candidate.snapshot_for_save()
	var view := _validated_solo_view(saved_view)
	if not view.is_empty(): data.solo_view=view
	if not Persistence.write_json(save_path,data,_previous_saved):
		return {"ok":false, "message":"Could not write the active autosave. The current world remains open."}
	_previous_saved=data
	world=candidate
	solo_view=view
	startup_continuation={}
	world_generation+=1
	solo_view_generation=world_generation
	players={1:profile_id}
	_save_clock=0.0
	_set_loaded_clock(continuing)
	world_changed.emit()
	return {"ok":true, "report":report}

func _current_solo_view() -> Dictionary:
	if not can_control_time(): return {}
	var view: Dictionary=capture_solo_view.call() if capture_solo_view.is_valid() else solo_view.duplicate()
	view.profile=profile_id
	view.speed=_resume_speed
	return _validated_solo_view(view)

func _validated_solo_view(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("profile")!=profile_id: return {}
	var result := {"profile":profile_id,"speed":1.0}
	var speed: Variant=value.get("speed")
	if (speed is int or speed is float) and float(speed) in [1.0,2.0,4.0]: result.speed=float(speed)
	for key: String in ["member","lot"]:
		if value.get(key) is String and str(value[key]).length()<=160: result[key]=value[key]
	if _integer(value.get("level"),0,2): result.level=int(value.level)
	for key: String in ["zoom","pan_x","pan_y"]:
		var number: Variant=value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)): continue
		if key=="zoom" and float(number)>=0.65 and float(number)<=1.8: result[key]=float(number)
		if key!="zoom" and absf(float(number))<=64.0: result[key]=float(number)
	return result

func _set_loaded_clock(continuing: bool) -> void:
	_simulation_clock=0.0
	debug_speed=0.0 if continuing else 1.0
	_resume_speed=float(solo_view.get("speed",1.0))

func can_control_time() -> bool:
	return role=="offline" and not _dedicated

func set_play_speed(value: Variant) -> Dictionary:
	if not can_control_time(): return {"ok":false,"message":"Shared neighborhoods follow the host's clock. Solo time controls are unavailable here."}
	if not (value is int or value is float) or not is_finite(float(value)) or not float(value) in PLAY_SPEEDS:
		return {"ok":false,"message":"Choose Pause, 1×, 2×, or 4×."}
	set_clock_rate(float(value))
	return {"ok":true,"message":"Time paused. You can still plan your residents' activities." if debug_speed==0.0 else "Playing at "+speed_label()+"."}

func toggle_play_pause() -> Dictionary:
	return set_play_speed(_resume_speed if debug_speed==0.0 and _resume_speed in PLAY_SPEEDS else 1.0 if debug_speed==0.0 else 0.0)

func set_clock_rate(value: float) -> void:
	# Called by validated solo controls or the authority-only developer console.
	debug_speed=value
	if value>0.0: _resume_speed=value
	_simulation_clock=0.0
	world_changed.emit()

func effective_speed() -> float:
	if not is_authority(): return 1.0 # Client presentation follows received state.
	if role=="offline" and menu_paused: return 0.0
	return debug_speed

func speed_label() -> String:
	return ("%.2f" % debug_speed).trim_suffix("0").trim_suffix("0").trim_suffix(".")+"×"

func _advance_simulation(delta: float) -> void:
	if not is_authority() or not is_finite(delta) or delta<=0.0: return
	var rate := effective_speed()
	if rate<=0.0: _simulation_clock=0.0; return
	# Retain sub-tick time at every frame rate. A stall contributes at most a
	# quarter second, and even debug 8× has at most twenty small steps per frame.
	_simulation_clock+=minf(delta,0.25)*rate
	var steps := 0
	while _simulation_clock+0.00000001>=SIMULATION_STEP and steps<20:
		world.step(SIMULATION_STEP)
		_simulation_clock=maxf(0.0,_simulation_clock-SIMULATION_STEP); steps+=1

func execute_debug(line: String, member_id: String = "") -> Dictionary:
	return DebugCommands.execute(self,line,member_id)

func _set_status(message: String) -> void:
	status = message
	status_changed.emit(message)

func _peer_connected(id: int) -> void:
	pending[id] = Time.get_ticks_msec()

func _peer_disconnected(id: int) -> void:
	if players.has(id):
		world.set_online(str(players[id]), false)
		players.erase(id)
		save_world()
		world_changed.emit()
	pending.erase(id)
	_outgoing.erase(id)
	_responses.erase(id)
	_household_transfer.assemblies.erase(id)
	_highest_request.erase(id)
	_rate.erase(id)
	_last_chat.erase(id)

func _physics_process(delta: float) -> void:
	if profile_id.is_empty():
		return
	if peer != null:
		peer.poll()
		var connection := peer.get_connection_status()
		if connection == MultiplayerPeer.CONNECTION_DISCONNECTED:
			var reason := str(peer.call("connection_error")) if peer.has_method("connection_error") else ""
			leave()
			_set_status("Disconnected. Your local neighborhood is open. " + reason)
			return
		if role == "joining" and connection == MultiplayerPeer.CONNECTION_CONNECTED:
			local_id = peer.get_unique_id()
			role = "client"
			_send(1, {"type": "hello", "version": PROTOCOL, "credential": _credential, "name": display_name})
		if role in ["joining", "client"] and not _welcomed and Time.get_ticks_msec() - _started_at > CONNECT_TIMEOUT_MS:
			leave()
			_set_status("Connection timed out. Ask the host for a fresh ticket.")
			return
		for _index in range(mini(peer.get_available_packet_count(), 128)):
			var sender := peer.get_packet_peer()
			var packet := peer.get_packet()
			if packet.size() > MAX_PACKET:
				continue
			var parser := JSON.new()
			if parser.parse(packet.get_string_from_utf8()) == OK and parser.data is Dictionary:
				_receive(sender, parser.data)
			if peer == null:
				return
	if is_authority():
		_advance_simulation(delta)
		_save_clock += delta
		if _save_clock >= 10.0:
			_save_clock = 0.0
			save_world()
		_ui_clock += delta
		if _ui_clock >= 0.2:
			_ui_clock = 0.0
			world_changed.emit()
	if role == "host":
		_snapshot_clock += delta
		if _snapshot_clock >= SNAPSHOT_INTERVAL:
			_snapshot_clock = 0.0
			_queue_snapshots()
		_drain_snapshots()
		for id: int in pending.keys():
			if Time.get_ticks_msec() - int(pending[id]) > 5000:
				peer.disconnect_peer(id, true)
				_peer_disconnected(id)
	elif role == "client" and _welcomed:
		if Time.get_ticks_msec() - _last_snapshot_at > 20000:
			leave()
			_set_status("Connection stopped updating. Rejoin to resume your family.")
			return
		for request in _requests.values():
			if Time.get_ticks_msec() - int(request.sent) > 1500:
				if int(request.tries) >= 4:
					leave()
					_set_status("Host did not acknowledge an action. Rejoin to see the accepted state.")
					return
				request.sent = Time.get_ticks_msec()
				request.tries += 1
				for packet: Dictionary in request.get("packets",[request.packet]): _send(1,packet)

func _receive(sender: int, message: Dictionary) -> void:
	var kind = message.get("type")
	if role == "host":
		if kind == "hello" and pending.has(sender):
			_accept_hello(sender, message)
		elif players.has(sender):
			if kind == "command":
				_accept_command(sender, message)
			elif kind == "household_part":
				var assembled: Dictionary=_household_transfer.receive(sender,message,Time.get_ticks_msec())
				if not assembled.is_empty(): _accept_command(sender,assembled)
			elif kind == "chat":
				_accept_chat(sender, message.get("text"))
	elif role == "client" and sender == 1:
		if kind == "welcome" and message.get("version") == PROTOCOL and message.get("profile") == profile_id:
			_welcomed = true
			_set_status("Connected · your family is ready")
		elif kind == "reject":
			var reason := str(message.get("message", "Could not join neighborhood.")).left(200)
			leave()
			_set_status(reason)
		elif kind == "chunk" and _welcomed:
			_receive_chunk(message)
		elif kind == "ack" and _welcomed and _integer(message.get("id"), 1, 2147483647):
			var request_id := int(message.id)
			if _requests.has(request_id) and message.get("ok") is bool and message.get("message") is String:
				var intent: Dictionary=_requests[request_id].packet.intent.duplicate(true)
				_requests.erase(request_id)
				_emit_action(bool(message.ok), str(message.message).left(200))
				command_completed.emit(intent,bool(message.ok),str(message.message).left(200))
		elif kind == "chat" and _welcomed and message.get("text") is String:
			chat_received.emit(str(message.text).left(200))

func _accept_hello(sender: int, message: Dictionary) -> void:
	if message.get("version") != PROTOCOL or not _valid_credential(message.get("credential")) or players.size() >= MAX_PLAYERS:
		_reject(sender, "Incompatible game or neighborhood is full.")
		return
	var identity: String = str(message.credential).sha256_text()
	if identity in players.values():
		_reject(sender, "This family is already connected on another device.")
		return
	var name_value = message.get("name", "New family")
	if not name_value is String or name_value.length() > 32:
		_reject(sender, "Invalid family name.")
		return
	if world.ensure_family(identity, name_value).is_empty():
		_reject(sender, "All four lots belong to families already.")
		return
	pending.erase(sender)
	players[sender] = identity
	world.set_online(identity, true)
	_send(sender, {"type": "welcome", "version": PROTOCOL, "profile": identity})
	_queue_snapshots()
	save_world()
	world_changed.emit()

func _reject(sender: int, message: String) -> void:
	_send(sender, {"type": "reject", "message": message})
	# Let the reliable rejection arrive; unintroduced peer timeout closes it.

func command(intent: Dictionary) -> void:
	if is_authority():
		var result: Dictionary = world.apply_command(profile_id, intent)
		_emit_action(bool(result.get("ok", false)), str(result.get("message", "")))
		command_completed.emit(intent.duplicate(true),bool(result.get("ok",false)),str(result.get("message","")))
		if result.get("ok", false):
			world_changed.emit()
			if intent.get("type") in ["build_begin", "build_end", "build_cancel", "place", "erase", "rename_family", "household_edit", "routine_save", "routine_delete", "set_window", "mail_send", "mail_read", "mail_claim", "mail_archive", "news_read", "commission_accept", "commission_cancel", "commission_deliver"]:
				save_world()
	elif role == "client" and _welcomed:
		if _requests.size() >= 16:
			_emit_action(false, "Waiting for the host to finish your recent actions.")
			command_completed.emit(intent.duplicate(true),false,"Waiting for the host to finish your recent actions.")
			return
		_request_id += 1
		var packet := {"type": "command", "id": _request_id, "intent": intent.duplicate(true)}
		var packets: Array=[packet]
		if JSON.stringify(packet).to_utf8_buffer().size() > MAX_PACKET:
			packets=HouseholdTransfer.packets(_request_id,intent)
			if packets.is_empty():
				_emit_action(false, "That action is too large.")
				command_completed.emit(intent.duplicate(true),false,"That action is too large.")
				return
		_requests[_request_id] = {"packet": packet, "packets":packets,"sent": Time.get_ticks_msec(), "tries": 1}
		for part: Dictionary in packets: _send(1,part)
	else:
		_emit_action(false, "Wait until the neighborhood is connected.")
		command_completed.emit(intent.duplicate(true),false,"Wait until the neighborhood is connected.")

func _accept_command(sender: int, message: Dictionary) -> void:
	if not _integer(message.get("id"), 1, 2147483647) or not message.get("intent") is Dictionary:
		return
	var request_id := int(message.id)
	if not _responses.has(sender):
		_responses[sender] = {}
	var responses: Dictionary = _responses[sender]
	if responses.has(request_id):
		_send(sender, responses[request_id])
		return
	if request_id <= int(_highest_request.get(sender, 0)):
		_send(sender, {"type": "ack", "id": request_id, "ok": false, "message": "This action is older than the replay window."})
		return
	_highest_request[sender] = request_id
	var now := Time.get_ticks_msec()
	var bucket: Dictionary = _rate.get(sender, {"at": now, "count": 0})
	if now - int(bucket.at) >= 1000:
		bucket = {"at": now, "count": 0}
	bucket.count += 1
	_rate[sender] = bucket
	var result: Dictionary
	if int(bucket.count) > 30:
		result = {"ok": false, "message": "Slow down a moment."}
	else:
		result = world.apply_command(str(players[sender]), message.intent)
	var response := {"type": "ack", "id": request_id, "ok": bool(result.get("ok", false)), "message": str(result.get("message", "")).left(200)}
	responses[request_id] = response
	if responses.size() > 64:
		responses.erase(responses.keys()[0])
	_send(sender, response)
	if result.get("ok", false):
		world_changed.emit()
		if message.intent.get("type") in ["build_begin", "build_end", "build_cancel", "place", "erase", "rename_family", "household_edit", "routine_save", "routine_delete", "set_window", "mail_send", "mail_read", "mail_claim", "mail_archive", "news_read", "commission_accept", "commission_cancel", "commission_deliver"]:
			save_world()

func _emit_action(ok: bool, message: String) -> void:
	last_action_ok = ok
	last_action_message = message
	actions_received += 1
	action_result.emit(message)

func _queue_snapshots() -> void:
	var targets: Array = []
	for id: int in players:
		if id != 1 and not _outgoing.has(id):
			targets.append(id)
	if targets.is_empty():
		return
	var raw := JSON.stringify(world.snapshot()).to_utf8_buffer()
	if raw.size() > MAX_SNAPSHOT_BYTES:
		_set_status("Neighborhood exceeds the prototype replication limit.")
		return
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.size() > MAX_COMPRESSED_BYTES:
		_set_status("Neighborhood exceeds the prototype replication limit.")
		return
	_snapshot_id += 1
	for id: int in targets:
		_outgoing[id] = {"id": _snapshot_id, "raw": compressed, "size": raw.size(), "index": 0, "count": ceili(float(compressed.size()) / CHUNK_BYTES)}

func _drain_snapshots() -> void:
	# Eight bounded packets/frame total, round robin across peers.
	var budget := 8
	while budget > 0 and not _outgoing.is_empty():
		for id: int in _outgoing.keys():
			if budget <= 0:
				break
			var item: Dictionary = _outgoing[id]
			var offset := int(item.index) * CHUNK_BYTES
			var bytes: PackedByteArray = item.raw
			var packet := {"type": "chunk", "id": item.id, "index": item.index, "count": item.count, "size": item.size, "data": Marshalls.raw_to_base64(bytes.slice(offset, mini(offset + CHUNK_BYTES, bytes.size())))}
			if not _send(id, packet):
				return
			item.index += 1
			budget -= 1
			if int(item.index) >= int(item.count):
				_outgoing.erase(id)

func _receive_chunk(message: Dictionary) -> void:
	if not _integer(message.get("id"), 1, 2147483647) or not _integer(message.get("count"), 1, MAX_CHUNKS) or not _integer(message.get("index"), 0, MAX_CHUNKS - 1) or not _integer(message.get("size"), 1, MAX_SNAPSHOT_BYTES) or not message.get("data") is String or message.data.length() > 800:
		return
	var id := int(message.id)
	var index := int(message.index)
	if id <= _last_snapshot_id or index >= int(message.count):
		return
	if index == 0:
		_assembly = {"id": id, "count": int(message.count), "size": int(message.size), "next": 0, "data": PackedByteArray()}
	if _assembly.get("id") != id or _assembly.get("next") != index or _assembly.get("count") != int(message.count) or _assembly.get("size") != int(message.size):
		return
	var bytes := Marshalls.base64_to_raw(message.data)
	if bytes.size() > CHUNK_BYTES or bytes.is_empty():
		_assembly.clear()
		return
	var accumulated: PackedByteArray = _assembly.data
	accumulated.append_array(bytes)
	_assembly.data = accumulated
	_assembly.next += 1
	if int(_assembly.next) != int(_assembly.count):
		return
	var raw := accumulated.decompress(int(_assembly.size), FileAccess.COMPRESSION_DEFLATE)
	_assembly.clear()
	if raw.size() != int(message.size):
		return
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return
	var candidate = WorldModel.new()
	if not candidate.restore(parser.data, true) or not candidate.state.get("families", {}).has(profile_id):
		return
	world = candidate
	if snapshots_received==0: world_generation+=1
	_last_snapshot_id = id
	_last_snapshot_at = Time.get_ticks_msec()
	snapshots_received += 1
	world_changed.emit()

func send_chat(value: String) -> void:
	value = value.strip_edges().left(160)
	if value.is_empty():
		return
	if is_authority():
		_accept_chat(1, value)
	elif role == "client" and _welcomed:
		_send(1, {"type": "chat", "text": value})

func _accept_chat(sender: int, value: Variant) -> void:
	if not value is String or value.length() > 160 or value.strip_edges().is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_chat.get(sender, -1000)) < 750:
		return
	_last_chat[sender] = now
	var family: Dictionary = state.get("families", {}).get(players.get(sender, profile_id), {})
	var message := "%s: %s" % [family.get("name", "Neighbor"), value.strip_edges()]
	chat_received.emit(message)
	if role == "host":
		for id: int in players:
			if id != 1:
				_send(id, {"type": "chat", "text": message})

func _send(target: int, message: Dictionary) -> bool:
	if peer == null:
		return false
	var packet := JSON.stringify(message).to_utf8_buffer()
	if packet.size() > MAX_PACKET:
		return false
	peer.set_target_peer(target)
	peer.transfer_channel = 0
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return peer.put_packet(packet) == OK

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

func _valid_credential(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true

func quit_application(already_saved: bool = false) -> void:
	if _quitting: return
	_quitting = true
	if role=="offline":
		if not already_saved: save_world()
	else:
		leave()
	await Soundscape.shutdown_and_wait()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_application()
	elif what == NOTIFICATION_APPLICATION_PAUSED and OS.has_feature("mobile") and role != "offline":
		leave()
		_set_status("Session closed in the background. Rejoin to resume your family.")

func _exit_tree() -> void:
	if not _quitting and is_authority() and not profile_id.is_empty():
		if role=="host":
			for family_id in players.values():
				world.set_online(str(family_id), false)
		save_world()
	if peer != null:
		peer.close()
