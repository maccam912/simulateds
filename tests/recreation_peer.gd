extends SceneTree
## Real Iroh processes: independent household recreation and voluntary adoption.
var session: Node
var ticket_path := ""
var use_codes := false
var rooms: Node
var command_results: Array=[]
var feedback = preload("res://game/friendship_feedback.gd").new()
var feedbacks: Array=[]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = root.get_node("Session")
	session.world_changed.connect(_observe_feedback)
	session.command_completed.connect(func(intent: Dictionary,ok: bool,_message: String): command_results.append({"intent":intent,"ok":ok}))
	rooms = root.get_node("Rooms")
	var args := OS.get_cmdline_user_args()
	ticket_path = args[1]
	use_codes = "--codes" in args
	if args[0] == "host":
		await _host()
	else:
		await _client(args[2])

func _observe_feedback() -> void:
	if session.role!="client" or session.snapshots_received==0: return
	var notice: Dictionary=feedback.sample(session.state,session.profile_id,session.world_generation,Time.get_ticks_msec())
	if not notice.is_empty(): feedbacks.append(notice)

func _await_feedback(count: int) -> void:
	for attempt in range(50):
		if feedbacks.size()==count: return
		await create_timer(0.1).timeout
	assert(false,"Accepted client snapshots must yield exactly one local notice per encounter")

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
	var file:=FileAccess.open(ticket_path+name,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
func _wait_flag(name: String) -> Dictionary:
	for attempt in range(350):
		if FileAccess.file_exists(ticket_path+name): return JSON.parse_string(FileAccess.get_file_as_string(ticket_path+name))
		await create_timer(0.1).timeout
	assert(false,"Recreation peer did not reach "+name); return {}
func _host() -> void:
	assert(await rooms.host() if use_codes else session.host())
	var file:=FileAccess.open(ticket_path,FileAccess.WRITE); file.store_string(rooms.code if use_codes else session.ticket()); file.close()
	for attempt in range(900):
		for index: String in ["1","2"]:
			if FileAccess.file_exists(ticket_path+".prime"+index) and not FileAccess.file_exists(ticket_path+".primed"+index):
				var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ticket_path+".prime"+index))
				for resident: Dictionary in session.state.families[info.owner].members: resident.needs.fun=95; resident.needs.social=30
				_flag(".primed"+index)
		if FileAccess.file_exists(ticket_path+".automatic") and not FileAccess.file_exists(ticket_path+".automatic-started"):
			var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ticket_path+".automatic"))
			for resident: Dictionary in session.state.families[info.owner].members:
				session.world._clear_member(resident); resident.needs.fun=0; resident.needs.social=0
				session.world._queue_action(resident,{"type":"interact","target_id":info.stereo,"automatic":true})
				session.world._start_next(resident,session.state.lots[info.home])
			_flag(".automatic-started")
		if FileAccess.file_exists(ticket_path+".done1") and FileAccess.file_exists(ticket_path+".done2"):
			assert(session.state.families.size()==3); print("HOST_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit(); return
		await create_timer(0.1).timeout
	assert(false,"Both recreation clients must finish")
func _call(home: String,target: String) -> void:
	var selected: String=session.state.families[session.profile_id].members[0].id
	var option: Dictionary=session.world.recreation_option(session.profile_id,selected,home,target,true)
	assert(option.ok and option.orders.size()==2)
	var intent := {"type":"recreation","member_id":selected,"lot_id":home,"target_id":target,"household":true,"revision":option.revision,"orders":option.orders.duplicate(true)}
	var bad:=intent.duplicate(true); bad.orders[0].next_action+=1; await _command(bad,false)
	await _command(intent); await _command(intent,false)
func _cancel_own() -> void:
	for resident: Dictionary in session.state.families[session.profile_id].members: await _command({"type":"cancel","member_id":resident.id})
func _shared(home: String,target: String,owner: String,catchups: int) -> void:
	var saw_distinct_places:=false
	for attempt in range(140):
		var residents: Array=session.state.families[owner].members
		var players: Array=preload("res://game/shared_leisure.gd").players(session.state,home,target)
		var bond: Dictionary=preload("res://game/friendships.gd").bond(session.state,str(residents[0].id),str(residents[1].id))
		if players.size()==2:
			assert(players.all(func(resident): return resident.id in [residents[0].id,residents[1].id]))
			assert(preload("res://game/shared_leisure.gd").place(players[0])!=preload("res://game/shared_leisure.gd").place(players[1])); saw_distinct_places=true
		if saw_distinct_places and bond.today==catchups: return
		await create_timer(0.1).timeout
	assert(false,"The accepted household must share distinct places and chosen friendship")
func _client(index: String) -> void:
	await _connect()
	var identity: String=session.profile_id; var home: String=session.home_lot()
	for resident: Dictionary in session.state.families[identity].members:
		await _command({"type":"autonomy","member_id":resident.id,"enabled":false}); await _command({"type":"cancel","member_id":resident.id})
	await _command({"type":"build_begin","lot_id":home})
	await _command({"type":"place","lot_id":home,"kind":"game_table","x":8,"y":5})
	await _command({"type":"place","lot_id":home,"kind":"stereo","x":8,"y":9})
	await _command({"type":"build_end","lot_id":home})
	var table := ""; var stereo := ""
	for attempt in range(60):
		for object: Dictionary in session.state.lots[home].objects:
			if object.kind=="game_table": table=str(object.id)
			if object.kind=="stereo": stereo=str(object.id)
		if not table.is_empty() and not stereo.is_empty() and not session.state.lots[home].building: break
		await create_timer(0.1).timeout
	assert(not table.is_empty() and not stereo.is_empty())
	_flag(".prime"+index,{"owner":identity}); await _wait_flag(".primed"+index)
	await _call(home,table); await _shared(home,table,identity,1); await _cancel_own()
	await _await_feedback(1); assert(feedbacks[0].message.contains("caught up over a game"))
	_flag(".home"+index,{"owner":identity,"home":home,"table":table,"stereo":stereo})
	var neighbor: Dictionary=await _wait_flag(".home"+("2" if index=="1" else "1"))
	if index=="2":
		for resident: Dictionary in session.state.families[identity].members: await _command({"type":"visit","member_id":resident.id,"lot_id":neighbor.home})
		for attempt in range(60):
			if session.state.families[identity].members.all(func(resident): return resident.lot_id==neighbor.home): break
			await create_timer(0.1).timeout
		var foreign: Dictionary={"type":"recreation","member_id":session.state.families[neighbor.owner].members[0].id,"lot_id":neighbor.home,"target_id":neighbor.table,"household":true,"revision":session.state.lots[neighbor.home].revision,"orders":[]}
		await _command(foreign,false)
		await _call(neighbor.home,neighbor.table); _flag(".visiting-call")
		await _wait_flag(".visiting-observed"); await _cancel_own()
		for resident: Dictionary in session.state.families[identity].members: await _command({"type":"go_home","member_id":resident.id})
		_flag(".visiting-done")
		await _await_feedback(2); assert(feedbacks[1].message.contains("now friends"))
	else:
		await _wait_flag(".visiting-call")
		await _shared(home,table,neighbor.owner,2)
		assert(session.state.families[identity].members.all(func(resident): return resident.task.is_empty() and resident.queue.is_empty()),"A visiting player controls only their own household")
		_flag(".visiting-observed"); await _wait_flag(".visiting-done")
		assert(feedbacks.size()==1,"Another player's visiting household earns no local toast")
		_flag(".automatic",{"owner":identity,"home":home,"stereo":stereo})
	if index=="1":
		await _wait_flag(".automatic-started")
		for attempt in range(100):
			if session.state.families[identity].members.all(func(resident): return resident.task.get("automatic",false) and resident.task.get("elapsed",0)>2): break
			await create_timer(0.1).timeout
		_flag(".automatic-ready"); await _wait_flag(".automatic-observed")
		var old: Array=session.state.families[identity].members.map(func(resident): return resident.task.duplicate(true))
		await _call(home,stereo)
		for attempt in range(50):
			if session.state.families[identity].members.all(func(resident): return resident.task.has("leisure_chosen_at")): break
			await create_timer(0.1).timeout
		for member_index in range(2):
			var task: Dictionary=session.state.families[identity].members[member_index].task
			assert(task.id!=old[member_index].id and not task.get("automatic",false) and task.remaining<=old[member_index].remaining and task.leisure_chosen_at>=old[member_index].elapsed)
		_flag(".chosen"); await _wait_flag(".choice-observed")
		await _shared(home,stereo,identity,2); await _cancel_own()
		await _await_feedback(2); assert(feedbacks[1].message.contains("now friends"))
		var bond: Dictionary=preload("res://game/friendships.gd").bond(session.state,str(session.state.families[identity].members[0].id),str(session.state.families[identity].members[1].id)).duplicate(true)
		session.leave(); await create_timer(0.3).timeout; await _connect()
		assert(session.home_lot()==home and session.state.lots[home].funds==11400)
		assert(preload("res://game/friendships.gd").bond(session.state,str(session.state.families[identity].members[0].id),str(session.state.families[identity].members[1].id))==bond)
		await create_timer(1.5).timeout
		assert(feedbacks.size()==2,"Reconnecting establishes a quiet baseline instead of replaying earned friendship")
		_flag(".reconnected")
	else:
		await _wait_flag(".automatic-ready")
		for attempt in range(60):
			if session.state.families[neighbor.owner].members.all(func(resident): return resident.task.get("automatic",false) and resident.task.get("target_id")==neighbor.stereo): break
			await create_timer(0.1).timeout
		assert(session.state.families[neighbor.owner].members.all(func(resident): return resident.task.get("automatic",false)))
		_flag(".automatic-observed"); await _wait_flag(".chosen")
		for attempt in range(60):
			if session.state.families[neighbor.owner].members.all(func(resident): return resident.task.has("leisure_chosen_at") and not resident.task.get("automatic",false)): break
			await create_timer(0.1).timeout
		assert(session.state.families[neighbor.owner].members.all(func(resident): return resident.task.has("leisure_chosen_at") and not resident.task.get("automatic",false)))
		_flag(".choice-observed"); await _wait_flag(".reconnected")
	_flag(".done"+index); print("CLIENT_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit()
