extends SceneTree
## Real Iroh processes: two independent builders, visitor recall and reconnect.
var session: Node
var ticket_path := ""
var use_codes := false
var rooms: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = root.get_node("Session")
	rooms = root.get_node("Rooms")
	var args := OS.get_cmdline_user_args()
	ticket_path = args[1]
	use_codes = "--codes" in args
	if args[0] == "host":
		await _host()
	else:
		await _client(args[2])

func _connect() -> void:
	if use_codes:
		assert(await rooms.join(FileAccess.get_file_as_string(ticket_path)), "Join-code request failed")
	else:
		assert(session.join(FileAccess.get_file_as_string(ticket_path)), "Ticket connection failed")
	for _index in range(300):
		await create_timer(0.1).timeout
		if session.snapshots_received > 0 and session.state.families.has(session.profile_id):
			return
	assert(false, "Host snapshot did not arrive")

func _command(intent: Dictionary, accepted := true) -> void:
	var count: int = session.actions_received
	session.command(intent)
	for _index in range(100):
		if session.actions_received > count:
			assert(session.last_action_ok == accepted, "Unexpected action result: " + session.last_action_message)
			return
		await create_timer(0.1).timeout
	assert(false, "Command was not acknowledged")

func _host() -> void:
	if use_codes:
		assert(await rooms.host(), "Could not create code")
	else:
		assert(session.host(), "Could not host")
	await create_timer(2.0).timeout
	var file := FileAccess.open(ticket_path, FileAccess.WRITE)
	file.store_string(rooms.code if use_codes else session.ticket())
	file.close()
	var home: String = session.home_lot()
	var recalled := false
	for _index in range(700):
		await create_timer(0.1).timeout
		var visitors := 0
		for family_id in session.state.families:
			if family_id == session.profile_id:
				continue
			var family: Dictionary = session.state.families[family_id]
			if family.online and family.members[0].lot_id == home:
				visitors += 1
		if visitors == 2 and not recalled:
			await _command({"type": "build_begin", "lot_id": home})
			recalled = true
		if recalled and FileAccess.file_exists(ticket_path + ".1.done") and FileAccess.file_exists(ticket_path + ".2.done") and session.players.size() == 1:
			assert(session.state.families.size() == 3, "Reconnect created duplicate families")
			for family_id in session.state.families:
				if family_id != session.profile_id:
					assert(not session.state.families[family_id].online, "Disconnect did not enable caretaker")
			assert(session.save_world(), "Host persistence failed")
			var old_code: String = rooms.code
			session.leave()
			await create_timer(1.0).timeout
			if use_codes:
				var reply: Dictionary = await rooms.service.resolve(old_code)
				assert(not reply.ok, "Code was not revoked")
			print("HOST_PASS")
			quit()
			return
	assert(false, "Host did not see two builders, visitor recall, reconnect and disconnect")

func _client(index: String) -> void:
	await _connect()
	for _attempt in range(200):
		if session.state.families.size() == 3:
			break
		await create_timer(0.1).timeout
	assert(session.state.families.size() == 3, "Both clients did not join")
	var home: String = session.home_lot()
	var identity: String = session.profile_id
	var member_id: String = session.state.families[identity].members[0].id
	var host_home := ""
	for family in session.state.families.values():
		if family.name == "Host family household":
			host_home = family.home_lot
	assert(not host_home.is_empty(), "Host family missing")
	# Ownership is enforced on the host, even for syntactically valid commands.
	await _command({"type": "build_begin", "lot_id": host_home}, false)
	await _command({"type": "build_begin", "lot_id": home})
	await _command({"type": "place", "lot_id": home, "kind": "floor", "x": 0, "y": 0})
	for _attempt in range(50):
		if [0,0] in session.state.lots[home].floors: break
		await create_timer(0.1).timeout
	await _command({"type":"build_undo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if not [0,0] in session.state.lots[home].floors: break
		await create_timer(0.1).timeout
	assert(not [0,0] in session.state.lots[home].floors,"Client undo did not restore layout")
	await _command({"type":"build_redo","lot_id":home,"revision":session.state.lots[home].revision})
	await _command({"type": "build_end", "lot_id": home})
	await _command({"type":"autonomy","member_id":member_id,"enabled":false})
	await _command({"type":"cancel","member_id":member_id})
	await _command({"type":"move","member_id":member_id,"lot_id":home,"x":0,"y":0})
	await _command({"type":"move","member_id":member_id,"lot_id":home,"x":15,"y":15})
	var queued_id := ""
	for _attempt in range(30):
		var resident: Dictionary = session.state.families[identity].members[0]
		if not resident.queue.is_empty():
			queued_id = str(resident.queue[0].id)
			break
		await create_timer(0.1).timeout
	assert(not queued_id.is_empty(), "Replicated plan did not expose stable action ID")
	await _command({"type":"remove_action","member_id":member_id,"action_id":queued_id})
	await _command({"type":"remove_action","member_id":member_id,"action_id":queued_id},false)
	await _command({"type": "visit", "lot_id": host_home, "member_id": member_id})
	var recalled := false
	for _attempt in range(300):
		await create_timer(0.1).timeout
		if session.state.lots[host_home].building and session.state.families[identity].members[0].lot_id == home:
			recalled = true
			break
	assert(recalled, "Host construction did not recall visitor in replicated state")
	assert([0, 0] in session.state.lots[home].floors, "Accepted construction was not replicated")
	var funds: float = session.state.lots[home].funds
	session.leave()
	await create_timer(0.7).timeout
	await _connect()
	assert(session.home_lot() == home, "Reconnect changed lot ownership")
	assert(not session.state.families[identity].members[0].autonomy, "Reconnect lost autonomy preference")
	assert(session.state.families.size() == 3, "Reconnect duplicated family")
	assert([0, 0] in session.state.lots[home].floors, "Reconnect lost construction")
	assert(session.state.lots[home].funds == funds, "Reconnect changed budget")
	assert(session.state.lots[host_home].building, "Construction lease was hidden by replication")
	session.leave()
	await create_timer(0.5).timeout
	var file := FileAccess.open(ticket_path + "." + index + ".done", FileAccess.WRITE)
	file.store_string("done")
	file.close()
	print("CLIENT_PASS")
	quit()
