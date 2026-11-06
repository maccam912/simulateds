extends SceneTree
## Desktop companion for a real Android APK; intentionally outside check.py.
## Use isolated --save-path, --profile-path and --settings-path (see ANDROID_QA).
var session: Node
var rooms: Node
var join_code := ""
var host_code_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = root.get_node("Session")
	rooms = root.get_node("Rooms")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--join-code="): join_code = argument.trim_prefix("--join-code=")
		if argument.begins_with("--host-code-path="): host_code_path = argument.trim_prefix("--host-code-path=")
	assert(session.save_path != "user://neighborhood.json" and session.profile_path != "user://profile.json")
	create_timer(240).timeout.connect(func(): push_error("Android peer check timed out"); quit(1))
	session.status_changed.connect(func(message: String): print(message))
	if not host_code_path.is_empty():
		await _host()
	else:
		assert(not join_code.is_empty(), "Provide --join-code or --host-code-path")
		await _client()
	session.leave()
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()

func _wait_for(predicate: Callable, reason: String) -> void:
	for attempt in range(200):
		if predicate.call(): return
		await create_timer(0.1).timeout
	assert(false, reason + ": " + session.status)

func _command(intent: Dictionary) -> void:
	var before: int = session.actions_received
	session.command(intent)
	await _wait_for(func(): return session.actions_received > before, "Missing acknowledgement")
	assert(session.last_action_ok, session.last_action_message)
	print("ACK ", intent.type, ": ", session.last_action_message)

func _client() -> void:
	var home := ""
	var members: Array = []
	var families := 0
	for round_index in range(3):
		var started := Time.get_ticks_msec()
		assert(await rooms.join(join_code))
		await _wait_for(func(): return session.snapshots_received > 0 and session.state.families.has(session.profile_id), "No accepted host snapshot")
		var family: Dictionary = session.state.families[session.profile_id]
		if round_index == 0:
			home = family.home_lot
			members = family.members.map(func(member): return member.id)
			families = session.state.families.size()
		assert(family.home_lot == home and family.members.map(func(member): return member.id) == members)
		assert(session.state.families.size() == families, "Reconnect allocated another family")
		print("SNAPSHOT round=", round_index + 1, " after_ms=", Time.get_ticks_msec() - started)
		await _command({"type":"autonomy", "member_id":members[0], "enabled":false})
		await _wait_for(func(): return not session.state.families[session.profile_id].members[0].autonomy, "Command did not replicate")
		await _command({"type":"build_begin", "lot_id":home})
		await _wait_for(func(): return session.state.lots[home].building, "Construction did not replicate")
		var revision: int = session.state.lots[home].revision
		assert(not session.state.lots[home].floors.has([0, 0]), "Use a test household with clear tile 0,0")
		await _command({"type":"place", "lot_id":home, "kind":"floor", "x":0, "y":0})
		await _wait_for(func(): return session.state.lots[home].revision > revision, "Purchase did not replicate")
		assert(session.state.lots[home].floors.has([0, 0]))
		revision = session.state.lots[home].revision
		await _command({"type":"build_undo", "lot_id":home, "revision":revision})
		await _wait_for(func(): return session.state.lots[home].revision > revision, "Undo did not replicate")
		assert(not session.state.lots[home].floors.has([0, 0]))
		await _command({"type":"build_end", "lot_id":home})
		await _wait_for(func(): return not session.state.lots[home].building, "Finish did not replicate")
		assert(session.snapshots_received >= 4)
		print("ANDROID_HOST_ROUND_PASS ", round_index + 1, " snapshots=", session.snapshots_received)
		session.leave()
		await create_timer(2).timeout
	print("ANDROID_HOST_DESKTOP_CLIENT_PASS")

func _host() -> void:
	assert(await rooms.host())
	var output := FileAccess.open(host_code_path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(rooms.code); output.close()
	print("DESKTOP_HOST_READY code=", rooms.code)
	var identity := ""
	var home := ""
	var joins := 0
	var active_peer := 0
	var accepted := 0
	var seen: Dictionary = {}
	while joins < 2 or active_peer != 0:
		for peer_id: int in session.players:
			if peer_id == 1: continue
			if active_peer == 0:
				active_peer = peer_id; joins += 1; accepted = 0; seen.clear()
				var current: String = session.players[peer_id]
				if identity.is_empty():
					identity = current; home = session.state.families[current].home_lot
				assert(current == identity and session.state.families[current].home_lot == home)
				print("ANDROID_JOIN ", joins, " home=", home)
			for request_id: int in session._responses.get(peer_id, {}):
				if seen.has(request_id): continue
				seen[request_id] = true
				var reply: Dictionary = session._responses[peer_id][request_id]
				print("ANDROID_COMMAND ", reply.ok, " ", reply.message)
				if reply.ok: accepted += 1
		if active_peer != 0 and not session.players.has(active_peer):
			assert(accepted >= 2, "Perform at least two accepted commands before leaving")
			assert(not session.state.families[identity].online)
			assert(session.state.families.size() == 2, "Use a fresh isolated desktop host")
			active_peer = 0
			print("ANDROID_LEAVE ", joins)
		await create_timer(0.1).timeout
	print("DESKTOP_HOST_ANDROID_CLIENT_PASS")
