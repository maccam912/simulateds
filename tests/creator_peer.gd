extends SceneTree
## Real Iroh: complete eight-person creator drafts, atomic rejection and reconnect.
var session: Node
var ticket_path := ""
var use_codes := false
var rooms: Node
var command_results: Array=[]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = root.get_node("Session")
	session.command_completed.connect(func(intent: Dictionary,ok: bool,_message: String): command_results.append({"intent":intent,"ok":ok}))
	rooms = root.get_node("Rooms")
	var args := OS.get_cmdline_user_args()
	ticket_path = args[1]
	use_codes = "--codes" in args
	if args[0] == "host":
		await _host()
	else:
		await _client(args[2])

func _connect() -> void:
	assert(session.set_play_speed(0).ok)
	if use_codes:
		assert(await rooms.join(FileAccess.get_file_as_string(ticket_path)), "Join-code request failed")
	else:
		assert(session.join(FileAccess.get_file_as_string(ticket_path)), "Ticket connection failed")
	for _index in range(300):
		await create_timer(0.1).timeout
		if session.snapshots_received > 0 and session.state.families.has(session.profile_id):
			assert(session.debug_speed==1 and not session.can_control_time())
			assert(not session.toggle_play_pause().ok and not session.set_play_speed(4).ok and session._requests.is_empty(),"Joining resets private pace; local controls cannot send shared clock requests")
			return
	assert(false, "Host snapshot did not arrive")

func _command(intent: Dictionary, accepted := true) -> void:
	var count: int = session.actions_received
	var completed_before := command_results.size()
	session.command(intent)
	for _index in range(100):
		if session.actions_received > count:
			assert(session.last_action_ok == accepted, "Unexpected action result: " + session.last_action_message)
			assert(command_results.size()==completed_before+1 and command_results[-1].intent==intent and command_results[-1].ok==accepted,"Each command result correlates to the actual submitted intent")
			return
		await create_timer(0.1).timeout
	assert(false, "Command was not acknowledged")

func _flag(name: String,data: Dictionary={}) -> void:
	preload("res://tests/peer_signal.gd").publish(ticket_path+name,JSON.stringify(data))
func _wait_flag(name: String) -> Dictionary:
	for attempt in range(250):
		if FileAccess.file_exists(ticket_path+name): return JSON.parse_string(FileAccess.get_file_as_string(ticket_path+name))
		await create_timer(0.1).timeout
	assert(false,"Creator peer must reach "+name); return {}
func _host() -> void:
	assert(await rooms.host() if use_codes else session.host())
	preload("res://tests/peer_signal.gd").publish(ticket_path,rooms.code if use_codes else session.ticket())
	for attempt in range(850):
		if FileAccess.file_exists(ticket_path+".done1") and FileAccess.file_exists(ticket_path+".done2"):
			assert(session.save_world())
			var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.save_path))
			var replica := preload("res://game/world.gd").new(); assert(replica.restore(saved))
			for family: Dictionary in replica.state.families.values():
				if family.id==session.profile_id: continue
				assert(family.members.size()==8 and family.relations.size()==2)
				assert(family.members[2].character.age==0 and family.members[7].character.age==6)
			print("CREATOR_HOST_BYTES ",JSON.stringify(saved).to_utf8_buffer().size())
			print("HOST_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit(); return
		await create_timer(0.1).timeout
	assert(false,"Both creator households must finish")

func _client(index: String) -> void:
	await _connect()
	var profile = preload("res://game/character_profile.gd")
	var appearance = preload("res://game/appearance.gd")
	var family: Dictionary=session.state.families[session.profile_id].duplicate(true)
	var members: Array=[]
	for cursor in range(8):
		var member: Dictionary=family.members[cursor].duplicate(true) if cursor<2 else {"id":preload("res://game/household_profile.gd").new_id(family,cursor),"name":"Resident "+str(cursor),"appearance":appearance.defaults({}),"favorite":"variety"}
		var character: Dictionary=profile.defaults(member)
		character.age=[5,5,0,1,2,3,4,6][cursor]
		character.hairstyle=cursor; character.eyes=cursor; character.voice=cursor%4; character.pitch=cursor*12
		character.traits=["Creative","Gentle","Curious"]; character.likes=["Painting"]; character.dislikes=["Television"]
		for occasion: String in profile.OCCASIONS:
			character.outfits[occasion].top_color=(cursor+profile.OCCASIONS.find(occasion))%12
		members.append({"id":member.id,"name":member.name,"appearance":member.appearance,"favorite":member.favorite,"character":character})
	var command := {"type":"household_edit","name":"Creator family "+index,"revision":family.identity_revision,"members":members,"relations":[{"a":members[0].id,"b":members[1].id,"kind":2},{"a":members[0].id,"b":members[2].id,"kind":4}]}
	assert(JSON.stringify(command).to_utf8_buffer().size()>session.MAX_PACKET)
	await _command(command)
	for attempt in range(150):
		if session.state.families[session.profile_id].members.size()==8: break
		await create_timer(0.1).timeout
	assert(session.state.families[session.profile_id].members.size()==8)
	for cursor in range(8): assert(session.state.families[session.profile_id].members[cursor].character==members[cursor].character)
	await _command(command,false)
	var invalid := command.duplicate(true); invalid.revision=int(command.revision)+1; invalid.members[7].character.height=101; invalid.name="Must not apply"
	await _command(invalid,false)
	assert(session.state.families[session.profile_id].name==command.name and session.state.families[session.profile_id].members.size()==8)
	session.leave(); await create_timer(0.4).timeout; await _connect()
	assert(session.state.families[session.profile_id].members.size()==8 and session.state.families[session.profile_id].relations.size()==2)
	for cursor in range(8): assert(session.state.families[session.profile_id].members[cursor].character==members[cursor].character)
	_flag(".done"+index); print("CLIENT_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit()
