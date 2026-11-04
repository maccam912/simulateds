extends SceneTree
## Real Iroh processes: independent commissions, reconnect, and exactly one delivery payment.
var session: Node
var ticket_path := ""
var use_codes := false
var rooms: Node
var command_results: Array=[]
var readiness=preload("res://game/commission_feedback.gd").new()
var notices: Array[Dictionary]=[]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = root.get_node("Session")
	session.world_changed.connect(_observe)
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
			_observe()
			return
	assert(false, "Host snapshot did not arrive")

func _observe() -> void:
	var availability: Dictionary=preload("res://game/art_commissions.gd").availability(session.state,session.profile_id)
	var notice: Dictionary=readiness.sample(availability,str(session.profile_id)+":"+str(session.world_generation),int(session.state.get("tick",0)),Time.get_ticks_msec(),session.role=="client")
	if not notice.is_empty(): notices.append(notice)

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
			var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(session.save_path))
			assert(saved is Dictionary)
			var replica:=preload("res://game/world.gd").new(); assert(replica.restore(saved))
			for owner: String in session.state.families:
				if owner==session.profile_id: continue
				assert(saved.families[owner].commissions.completed==1 and saved.lots[saved.families[owner].home_lot].funds==11960,"The host durably stores each accepted delivery")
			print("HOST_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit(); return
		await create_timer(0.1).timeout
	assert(false,"Both commissioned households must finish")

func _easel(home: String,id: String) -> Dictionary: return session.world._object(session.state.lots[home],id)

func _construction(home: String,building: bool) -> void:
	await _command({"type":"build_begin" if building else "build_end","lot_id":home})
	for attempt in range(60):
		if bool(session.state.lots[home].building)==building: return
		await create_timer(0.1).timeout
	assert(false,"The accepted construction mode must reach the client")

func _flag(name: String) -> void:
	var file:=FileAccess.open(ticket_path+name,FileAccess.WRITE); file.store_string("ready"); file.close()

func _wait_flag(name: String) -> void:
	for attempt in range(250):
		if FileAccess.file_exists(ticket_path+name): return
		await create_timer(0.1).timeout
	assert(false,"The other painting household must reach commission delivery")

func _board() -> Dictionary: return session.state.families[session.profile_id].commissions
func _intent(type: String) -> Dictionary:
	return {"type":type,"commission_revision":_board().revision,"offer":preload("res://game/art_commissions.gd").offer(session.profile_id,_board()).id}
func _revision(previous: int) -> void:
	for attempt in range(60):
		if int(_board().revision)>previous: return
		await create_timer(0.1).timeout
	assert(false,"Accepted commission state must reach the household")
func _client(index: String) -> void:
	await _connect()
	var identity: String=session.profile_id; var home: String=session.home_lot()
	var member: String=session.state.families[identity].members[0].id
	for resident: Dictionary in session.state.families[identity].members:
		await _command({"type":"autonomy","member_id":resident.id,"enabled":false})
		await _command({"type":"cancel","member_id":resident.id})
	var accept:=_intent("commission_accept")
	var foreign:=accept.duplicate(true); foreign.lot_id="lot_1"; await _command(foreign,false)
	await _command(accept); await _command(accept,false); await _revision(0)
	var accepted: Dictionary=_board().duplicate(true)
	await _construction(home,true); await _command({"type":"place","lot_id":home,"kind":"easel","x":9,"y":9})
	var id: String=""
	for attempt in range(60):
		for object: Dictionary in session.state.lots[home].objects:
			if object.kind=="easel": id=str(object.id)
		if not id.is_empty(): break
		await create_timer(0.1).timeout
	assert(not id.is_empty()); await _construction(home,false)
	session.leave(); await create_timer(0.4).timeout; await _connect()
	assert(_board()==accepted,"Accepting and reconnecting keeps exactly the same request")
	var terms: Dictionary=preload("res://game/art_commissions.gd").offer(identity,_board())
	await _command({"type":"painting","lot_id":home,"member_id":member,"target_id":id,"action":"start","subject":terms.subject,"revision":0})
	for attempt in range(360):
		if preload("res://game/paintings.gd").finished(_easel(home,id).painting): break
		await create_timer(0.1).timeout
	assert(preload("res://game/paintings.gd").finished(_easel(home,id).painting))
	for attempt in range(60):
		if not notices.is_empty(): break
		await create_timer(0.1).timeout
	assert(notices.size()==1 and notices[0].offer==terms.id and notices[0].revision==_board().revision and notices[0].message.contains(terms.client.to_lower()),"Actual client snapshots announce only their own newly ready request once")
	session.leave(); await create_timer(0.4).timeout; await _connect(); await create_timer(0.8).timeout
	assert(notices.size()==1 and preload("res://game/art_commissions.gd").availability(session.state,identity).ready.size()==1,"Reconnecting to a ready original keeps it discoverable without replaying the notice")
	_flag(".painted"+index); await _wait_flag(".painted"+("2" if index=="1" else "1"))
	var choices: Array=preload("res://game/art_commissions.gd").candidates(session.state,identity)
	assert(choices.size()==1 and choices[0].available)
	var delivery: Dictionary=choices[0].intent.duplicate(true)
	# A cancelled/reaccepted request invalidates its old delivery review.
	await _command(_intent("commission_cancel")); await _revision(1)
	await _command(_intent("commission_accept")); await _revision(2)
	await _command(delivery,false)
	delivery=preload("res://game/art_commissions.gd").candidates(session.state,identity)[0].intent
	foreign=delivery.duplicate(true); foreign.lot_id="lot_1"; await _command(foreign,false)
	var picture: Dictionary=_easel(home,id).painting.duplicate(true)
	var funds: int=session.state.lots[home].funds
	await _command(delivery); await _command(delivery,false); await _revision(3)
	assert(_board().completed==1 and _board().active.is_empty() and _easel(home,id).painting.subject=="" and session.state.lots[home].funds==funds+180)
	assert(_board().history[0].credit==preload("res://game/paintings.gd").credit(picture))
	var receipt: Dictionary=_board().duplicate(true)
	var noticed: int=notices.size()
	session.leave(); await create_timer(0.4).timeout; await _connect()
	assert(_board()==receipt and session.state.lots[home].funds==funds+180 and _easel(home,id).painting.subject=="")
	assert(notices.size()==noticed and preload("res://game/art_commissions.gd").availability(session.state,identity).is_empty())
	await _command(delivery,false); await _command(_intent("commission_accept"),false)
	_flag(".done"+index); print("CLIENT_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit()
