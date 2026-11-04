extends SceneTree
## Real Iroh processes: independent pantries, kept crops, cancelled cooking, and durable servings.
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
	var file:=FileAccess.open(ticket_path+name,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
func _wait_flag(name: String) -> Dictionary:
	for attempt in range(250):
		if FileAccess.file_exists(ticket_path+name): return JSON.parse_string(FileAccess.get_file_as_string(ticket_path+name))
		await create_timer(0.1).timeout
	assert(false,"Pantry peer must reach "+name); return {}
func _host() -> void:
	assert(await rooms.host() if use_codes else session.host())
	var file:=FileAccess.open(ticket_path,FileAccess.WRITE); file.store_string(rooms.code if use_codes else session.ticket()); file.close()
	for attempt in range(850):
		for index: String in ["1","2"]:
			if not FileAccess.file_exists(ticket_path+".setup"+index) or FileAccess.file_exists(ticket_path+".ready"+index): continue
			var request: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ticket_path+".setup"+index))
			var family: Dictionary=session.state.families[request.owner]; var home: Dictionary=session.state.lots[family.home_lot]
			# Mature-crop fixtures keep transport checks short; model/native tests grow from seeds.
			family.members[1].x=8; family.members[1].y=14
			for resident: Dictionary in family.members:
				for wish: Dictionary in resident.wishes.wishes: wish.done=true
			var table: Dictionary=session.world._new_object("dining_table",8,6,0); home.objects.append(table)
			var beds: Dictionary={}
			for crop: String in ["radish","tomato"]:
				var bed: Dictionary=session.world._new_object("garden_bed",5 if crop=="radish" else 10,13,0)
				bed.garden={"crop":crop,"growth":preload("res://game/gardens.gd").CROPS[crop].seconds,"water":0.0,"revision":1,"harvests":0}
				home.objects.append(bed); beds[crop]=bed.id
			_flag(".ready"+index,{"table":table.id,"beds":beds,"home":home.id,"owner":request.owner})
		if FileAccess.file_exists(ticket_path+".done1") and FileAccess.file_exists(ticket_path+".done2"):
			assert(session.save_world())
			var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.save_path))
			var replica:=preload("res://game/world.gd").new(); assert(replica.restore(saved))
			saved=replica.state
			for owner: String in saved.families:
				if owner==session.profile_id: continue
				assert(saved.families[owner].pantry=={"radish":2,"tomato":2})
				var home: Dictionary=saved.lots[saved.families[owner].home_lot]
				assert(home.funds==12000)
				assert(home.objects.filter(func(object): return object.kind=="dining_table")[0].meal.servings==4)
			print("HOST_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit(); return
		await create_timer(0.1).timeout
	assert(false,"Both pantry households must finish")
func _stock() -> Dictionary: return session.state.families[session.profile_id].pantry
func _object(home: String,id: String) -> Dictionary: return session.world._object(session.state.lots[home],id)
func _wait_stock(amount: int) -> void:
	for attempt in range(240):
		if _stock()=={"radish":amount,"tomato":amount}: return
		await create_timer(0.1).timeout
	assert(false,"Expected pantry stock must reach the client")
func _client(index: String) -> void:
	await _connect()
	var identity: String=session.profile_id; var home: String=session.home_lot(); var member: String=session.state.families[identity].members[0].id
	for resident: Dictionary in session.state.families[identity].members:
		await _command({"type":"autonomy","member_id":resident.id,"enabled":false}); await _command({"type":"cancel","member_id":resident.id})
	_flag(".setup"+index,{"owner":identity}); var setup: Dictionary=await _wait_flag(".ready"+index)
	for attempt in range(60):
		if not _object(home,setup.table).is_empty(): break
		await create_timer(0.1).timeout
	for crop: String in ["radish","tomato"]:
		var keep: Dictionary={"type":"garden","lot_id":home,"member_id":member,"target_id":setup.beds[crop],"action":"keep","crop":"","revision":1}
		await _command(keep); await _command(keep,false)
		for attempt in range(180):
			if int(_stock()[crop])==4: break
			await create_timer(0.1).timeout
		assert(int(_stock()[crop])==4 and _object(home,setup.beds[crop]).garden.crop=="")
		await _command(keep,false)
	assert(session.state.lots[home].funds==12000)
	session.leave(); await create_timer(0.4).timeout; await _connect(); await _wait_stock(4)
	var meal: Dictionary={"type":"meal","lot_id":home,"member_id":member,"target_id":setup.table,"action":"prepare","recipe":"homegrown","batch":0}
	await _command(meal); await _command(meal,false)
	await _command({"type":"cancel","member_id":member}); await _wait_stock(4)
	await _command(meal); await _command({"type":"build_begin","lot_id":home}); await _wait_stock(4)
	await _command(meal,false); await _command({"type":"build_cancel","lot_id":home})
	await _command(meal); await _wait_stock(2)
	assert(_object(home,setup.table).meal.servings==4 and session.state.lots[home].funds==12000)
	await _command(meal,false)
	_flag(".cooked"+index); await _wait_flag(".cooked"+("2" if index=="1" else "1"))
	var neighbor: Dictionary=await _wait_flag(".ready"+("2" if index=="1" else "1"))
	await _command({"type":"visit","member_id":member,"lot_id":neighbor.home})
	await _command({"type":"meal","lot_id":neighbor.home,"member_id":member,"target_id":neighbor.table,"action":"prepare","recipe":"homegrown","batch":1},false)
	assert(_stock()=={"radish":2,"tomato":2} and session.state.families[neighbor.owner].pantry==_stock())
	session.leave(); await create_timer(0.4).timeout; await _connect(); await _wait_stock(2)
	assert(_object(home,setup.table).meal.recipe=="homegrown" and _object(home,setup.table).meal.servings==4)
	_flag(".done"+index); print("CLIENT_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit()
