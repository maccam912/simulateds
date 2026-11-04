extends SceneTree
## Real Iroh processes: independent canvases, display, reconnect, and sales.
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

func _host() -> void:
	assert(await rooms.host() if use_codes else session.host())
	var file := FileAccess.open(ticket_path,FileAccess.WRITE)
	file.store_string(rooms.code if use_codes else session.ticket()); file.close()
	for attempt in range(850):
		if FileAccess.file_exists(ticket_path+".done1") and FileAccess.file_exists(ticket_path+".done2"):
			assert(session.state.families.size()==3)
			print("HOST_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit(); return
		await create_timer(0.1).timeout
	assert(false,"Both painting households must finish")

func _easel(home: String,id: String) -> Dictionary: return session.world._object(session.state.lots[home],id)

func _art_edit(home: String,command: Dictionary) -> void:
	# Replies may precede snapshots; subsequent commands need the actual draft.
	command.lot_id=home; command.revision=int(session.state.lots[home].revision)
	await _command(command)
	for attempt in range(60):
		if int(session.state.lots[home].revision)>int(command.revision): return
		await create_timer(0.1).timeout
	assert(false,"The accepted art edit must reach the client")

func _construction(home: String,building: bool) -> void:
	await _command({"type":"build_begin" if building else "build_end","lot_id":home})
	for attempt in range(60):
		if bool(session.state.lots[home].building)==building: return
		await create_timer(0.1).timeout
	assert(false,"The accepted construction mode must reach the client")

func _client(index: String) -> void:
	await _connect()
	var identity: String=session.profile_id; var home: String=session.home_lot()
	var member: String=session.state.families[identity].members[0].id
	var housemate: String=session.state.families[identity].members[1].id
	for resident: Dictionary in session.state.families[identity].members:
		await _command({"type":"autonomy","member_id":resident.id,"enabled":false})
		await _command({"type":"cancel","member_id":resident.id})
	await _command({"type":"build_begin","lot_id":home})
	await _command({"type":"place","lot_id":home,"kind":"easel","x":9,"y":9})
	var id := ""
	for attempt in range(40):
		for object: Dictionary in session.state.lots[home].objects:
			if object.kind=="easel": id=str(object.id)
		if not id.is_empty(): break
		await create_timer(0.1).timeout
	assert(not id.is_empty())
	await _command({"type":"build_end","lot_id":home})
	var subject := "meadow" if index=="1" else "harbor"
	var start := {"type":"painting","lot_id":home,"target_id":id,"member_id":member,"action":"start","subject":subject,"revision":0}
	await _command(start); await _command(start,false)
	for attempt in range(100):
		if float(_easel(home,id).painting.progress)>=4.2: break
		await create_timer(0.1).timeout
	assert(float(_easel(home,id).painting.progress)>=4.2)
	await _command({"type":"cancel","member_id":member})
	for attempt in range(40):
		if session.state.families[identity].members[0].task.is_empty(): break
		await create_timer(0.1).timeout
	var partial: Dictionary=_easel(home,id).painting.duplicate(true)
	assert(partial.subject==subject and float(partial.progress)<24)
	session.leave(); await create_timer(1.0).timeout; await _connect()
	assert(_easel(home,id).painting==partial,"Unfinished artwork survives disconnect without advancing while absent")
	assert(session.state.families[identity].members[0].hobbies.painting.sessions==0 and preload("res://game/paintings.gd").work_by(partial,member)>=4.0)
	await _command({"type":"painting","lot_id":home,"target_id":id,"member_id":member,"action":"resume","revision":0},false)
	await _command({"type":"painting","lot_id":home,"target_id":id,"member_id":housemate,"action":"resume","revision":partial.revision})
	for attempt in range(360):
		if preload("res://game/paintings.gd").finished(_easel(home,id).painting): break
		await create_timer(0.1).timeout
	var completed: Dictionary=_easel(home,id).painting.duplicate(true)
	assert(preload("res://game/paintings.gd").finished(completed) and completed.artists[0].id==member)
	assert(session.state.families[identity].members[1].wishes.journal.any(func(entry): return entry.text.contains(preload("res://game/paintings.gd").SUBJECTS[subject])))
	for resident: Dictionary in session.state.families[identity].members: assert(resident.hobbies.painting.sessions==1,"Both qualifying painters receive host-authoritative practice")
	# Persist a finished work through a second reconnect before selling it once.
	session.leave(); await create_timer(1.0).timeout; await _connect()
	assert(_easel(home,id).painting==completed)
	for resident: Dictionary in session.state.families[identity].members: assert(resident.hobbies.painting.sessions==1)
	await _construction(home,true)
	var art_id := "art_"+id+"_"+str(int(completed.revision))
	await _art_edit(home,{"type":"art_hang","source":"easel:"+id,"x":8,"y":3})
	assert(session.state.lots[home].artworks[art_id].picture==completed and _easel(home,id).painting.subject=="")
	await _art_edit(home,{"type":"build_undo"})
	assert(session.state.lots[home].artworks.is_empty() and _easel(home,id).painting==completed)
	await _art_edit(home,{"type":"build_redo"})
	await _art_edit(home,{"type":"art_store","source":"art:"+art_id})
	assert(session.state.lots[home].artworks[art_id].x==-1)
	await _art_edit(home,{"type":"art_hang","source":"art:"+art_id,"x":3,"y":8})
	await _construction(home,false)
	session.leave(); await create_timer(1.0).timeout; await _connect()
	assert(session.state.lots[home].artworks[art_id]=={"picture":completed,"x":3,"y":8} and _easel(home,id).painting.subject=="","Mounted artwork and its empty easel survive reconnect together")
	await _construction(home,true)
	await _art_edit(home,{"type":"art_return","source":"art:"+art_id,"target_id":id})
	assert(session.state.lots[home].artworks.is_empty() and _easel(home,id).painting.artists==completed.artists)
	completed=_easel(home,id).painting.duplicate(true)
	await _construction(home,false)
	var funds: int=session.state.lots[home].funds
	var sale := {"type":"painting","lot_id":home,"target_id":id,"member_id":member,"action":"sell","revision":completed.revision}
	await _command(sale); await _command(sale,false)
	for attempt in range(120):
		if _easel(home,id).painting.subject=="": break
		await create_timer(0.1).timeout
	assert(_easel(home,id).painting.subject=="" and session.state.lots[home].funds==funds+60)
	for resident: Dictionary in session.state.families[identity].members: assert(resident.hobbies.painting.sessions==1,"Arranging and selling cannot earn practice again")
	await _command(sale,false)
	var done := FileAccess.open(ticket_path+".done"+index,FileAccess.WRITE); done.store_string("done"); done.close()
	print("CLIENT_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit()

