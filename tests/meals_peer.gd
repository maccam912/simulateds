extends SceneTree
## Real Iroh processes: shared servings, distinct places, and absent-host leftovers.
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
		if FileAccess.file_exists(ticket_path+".autonomy-requested") and not FileAccess.file_exists(ticket_path+".autonomy-primed"):
			# Set appetite on the authoritative host; the clients still use real controls.
			var request: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ticket_path+".autonomy-requested"))
			for resident: Dictionary in session.state.families[request.owner].members:
				for need: String in resident.needs: resident.needs[need]=100.0
				resident.needs.hunger=20; resident.idle_clock=2
				resident.wishes={"day":int(session.state.day),"round":1,"wishes":[{"id":"meal_together","done":false},{"id":"story","done":false},{"id":"rest","done":false}],"journal":[]}
			_flag(".autonomy-primed")
		if FileAccess.file_exists(ticket_path+".done1") and FileAccess.file_exists(ticket_path+".done2"):
			assert(session.state.families.size()==3)
			print("HOST_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit(); return
		await create_timer(0.1).timeout
	assert(false,"Both dining households must finish")

func _flag(name: String,data: Dictionary={}) -> void:
	var file:=FileAccess.open(ticket_path+name,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
func _wait_flag(name: String) -> Dictionary:
	for attempt in range(350):
		if FileAccess.file_exists(ticket_path+name): return JSON.parse_string(FileAccess.get_file_as_string(ticket_path+name))
		await create_timer(0.1).timeout
	assert(false,"The dining neighbor must reach "+name); return {}
func _table(home: String,id: String) -> Dictionary: return session.world._object(session.state.lots[home],id)
func _wait_servings(home: String,id: String,count: int) -> void:
	for attempt in range(250):
		if not _table(home,id).is_empty() and int(_table(home,id).meal.servings)==count: return
		await create_timer(0.1).timeout
	assert(false,"Expected accepted portion count")
func _meal(home: String,id: String,resident: String,action: String,recipe: String="",accepted: bool=true) -> void:
	await _command({"type":"meal","lot_id":home,"target_id":id,"member_id":resident,"action":action,"recipe":recipe,"batch":int(_table(home,id).meal.batch)},accepted)
func _call_household(home: String,id: String,preferred: String) -> void:
	var option: Dictionary=session.world.meal_call_option(session.profile_id,preferred,home,id)
	assert(option.ok and option.orders.size()==2)
	var intent := {"type":"meal_call","member_id":preferred,"lot_id":home,"target_id":id,"batch":int(option.batch),"orders":option.orders.duplicate(true)}
	await _command(intent); await _command(intent,false)

func _client(index: String) -> void:
	await _connect()
	var identity: String=session.profile_id; var own_home: String=session.home_lot()
	var member: String=session.state.families[identity].members[0].id
	var housemate: String=session.state.families[identity].members[1].id
	for resident: Dictionary in session.state.families[identity].members:
		await _command({"type":"autonomy","member_id":resident.id,"enabled":false}); await _command({"type":"cancel","member_id":resident.id})
	var home := own_home; var id := ""
	if index=="1":
		await _command({"type":"move","lot_id":home,"member_id":housemate,"x":8,"y":14})
		for attempt in range(60):
			if session.state.families[identity].members[1].y==14: break
			await create_timer(0.1).timeout
		await _command({"type":"build_begin","lot_id":home})
		await _command({"type":"place","lot_id":home,"kind":"dining_table","x":8,"y":6})
		for attempt in range(60):
			for object: Dictionary in session.state.lots[home].objects:
				if object.kind=="dining_table": id=str(object.id)
			if not id.is_empty(): break
			await create_timer(0.1).timeout
		await _command({"type":"build_end","lot_id":home})
		await _meal(home,id,member,"prepare","salad"); await _meal(home,id,member,"prepare","salad",false)
		await _wait_servings(home,id,4)
		_flag(".meal-ready",{"home":home,"table":id,"owner":identity,"funds":session.state.lots[home].funds})
	else:
		var info: Dictionary=await _wait_flag(".meal-ready"); home=str(info.home); id=str(info.table)
		await _wait_servings(home,id,4)
		for resident: String in [member,housemate]: await _command({"type":"visit","lot_id":home,"member_id":resident})
		await _meal(home,id,member,"prepare","sandwiches",false)
		await _meal(home,id,member,"clear","",false)
		_flag(".guests-arrived")
	await _wait_flag(".guests-arrived")
	await _call_household(home,id,member)
	await _wait_servings(home,id,0)
	var places := {}
	var diners: Array=preload("res://game/shared_leisure.gd").players(session.state,home,id,false)
	assert(diners.size()==4)
	for resident: Dictionary in diners:
		var place: Vector2i=preload("res://game/shared_leisure.gd").place(resident)
		assert(not places.has(place)); places[place]=true
	for attempt in range(160):
		var finished := true
		for resident: Dictionary in session.state.families[identity].members:
			finished=finished and resident.task.is_empty() and resident.activity_log[0].outcome=="done" and str(resident.activity_log[0].title).begins_with("Eat ")
		if finished: break
		await create_timer(0.1).timeout
	for resident: Dictionary in session.state.families[identity].members: assert(resident.activity_log[0].outcome=="done" and str(resident.activity_log[0].title).begins_with("Eat "))
	_flag(".eaten"+index); await _wait_flag(".eaten"+("2" if index=="1" else "1"))
	if index=="1":
		await _meal(home,id,member,"prepare","sandwiches"); await _wait_servings(home,id,4)
		var original: Dictionary=_table(home,id).meal.duplicate(true)
		session.leave(); _flag(".host-away",{"meal":original})
		await _wait_flag(".guest-leftover"); await _connect(); await _wait_servings(home,id,3)
		assert(_table(home,id).meal.cook==member and _table(home,id).meal.recipe=="sandwiches")
		_flag(".reconnected")
	else:
		await _wait_flag(".host-away"); await _wait_servings(home,id,4)
		var owner: String=session.state.lots[home].owner
		for attempt in range(60):
			if not session.state.families[owner].online: break
			await create_timer(0.1).timeout
		assert(not session.state.families[owner].online)
		await _meal(home,id,member,"eat"); await _wait_servings(home,id,3)
		await _command({"type":"cancel","member_id":member})
		assert(_table(home,id).meal.servings==3,"A started portion is consumed once even if eating stops")
		_flag(".guest-leftover"); await _wait_flag(".reconnected")
	# Accepted autonomous reservations and consumed servings reach both clients.
	if index=="1":
		_flag(".autonomy-requested",{"owner":identity}); await _wait_flag(".autonomy-primed")
		var funds_before: int=session.state.lots[home].funds
		for resident: String in [member,housemate]: await _command({"type":"autonomy","member_id":resident,"enabled":true})
		await _wait_servings(home,id,1); await _wait_flag(".autonomy-observed")
		await _call_household(home,id,member)
		_flag(".meal-chosen"); await _wait_flag(".choice-observed")
		for resident: String in [member,housemate]: await _command({"type":"autonomy","member_id":resident,"enabled":false})
		for attempt in range(100):
			if session.state.families[identity].members.all(func(resident): return resident.wishes.wishes[0].done): break
			await create_timer(0.1).timeout
		assert(session.state.families[identity].members.all(func(resident): return resident.wishes.wishes[0].done))
		assert(session.state.lots[home].funds==funds_before+80 and _table(home,id).meal.servings==1,"Each diner earns one shared-meal wish, keeping the same servings")
		_flag(".autonomy-finished")
	else:
		await _wait_flag(".autonomy-primed"); await _wait_servings(home,id,1)
		var owner: String=session.state.lots[home].owner
		for resident: Dictionary in session.state.families[owner].members:
			assert(resident.task.get("automatic",false) and resident.task.get("meal_action")=="eat" and resident.task.get("meal_taken",false))
		_flag(".autonomy-observed"); await _wait_flag(".meal-chosen")
		for attempt in range(50):
			var chosen := true
			for resident: Dictionary in session.state.families[owner].members: chosen=chosen and resident.task.has("meal_chosen_at") and not resident.task.get("automatic",false)
			if chosen: break
			await create_timer(0.1).timeout
		for resident: Dictionary in session.state.families[owner].members:
			assert(resident.task.has("meal_chosen_at") and not resident.task.get("automatic",false) and resident.task.get("meal_taken",false))
		assert(_table(home,id).meal.servings==1)
		_flag(".choice-observed"); await _wait_flag(".autonomy-finished")
		for attempt in range(60):
			if session.state.families[owner].members.all(func(resident): return resident.wishes.wishes[0].done): break
			await create_timer(0.1).timeout
		assert(session.state.families[owner].members.all(func(resident): return resident.wishes.wishes[0].done) and _table(home,id).meal.servings==1)
	_flag(".done"+index); print("CLIENT_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit()
