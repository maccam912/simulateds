extends SceneTree
## Real Iroh processes: two independent builders, visitor recall and reconnect.
const Bonds = preload("res://game/friendships.gd")
const Leisure = preload("res://game/shared_leisure.gd")
const WalkFeedback = preload("res://game/walk_feedback.gd")
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
	assert(session.set_play_speed(4).ok)
	if use_codes:
		assert(await rooms.host(), "Could not create code")
	else:
		assert(session.host(), "Could not host")
	assert(session.debug_speed==1 and not session.can_control_time())
	assert(not session.set_play_speed(4).ok and not session.toggle_play_pause().ok)
	session.menu_paused=true
	var menu_tick: int=session.state.tick
	await create_timer(0.3).timeout
	assert(session.state.tick>menu_tick,"Hosting keeps the shared clock running through menus")
	session.menu_paused=false
	for resident: Dictionary in session.state.families[session.profile_id].members:
		await _command({"type":"autonomy","member_id":resident.id,"enabled":false})
	await _command({"type":"build_begin","lot_id":session.home_lot()})
	await _command({"type":"place","lot_id":session.home_lot(),"kind":"game_table","x":8,"y":5})
	await _command({"type":"place","lot_id":session.home_lot(),"kind":"stereo","x":8,"y":9})
	await _command({"type":"build_end","lot_id":session.home_lot()})
	await create_timer(2.0).timeout
	var file := FileAccess.open(ticket_path, FileAccess.WRITE)
	file.store_string(rooms.code if use_codes else session.ticket())
	file.close()
	var home: String = session.home_lot()
	var recalled := false
	var game_ready := false
	var courtesy: Dictionary={}
	var courtesy_written := false
	var delivered: Dictionary={}
	for _index in range(850):
		await create_timer(0.1).timeout
		var visitors := 0
		for family_id in session.state.families:
			if family_id == session.profile_id:
				continue
			var family: Dictionary = session.state.families[family_id]
			if recalled and not family.online and not delivered.has(family_id):
				await _command({"type":"mail_send","recipient":family_id,"sequence":session.state.families[session.profile_id].mailbox.next_sent,"note":"A postcard left while you were away.","gift":0})
				delivered[family_id]=true
			if family.online and family.members[0].lot_id == home:
				visitors += 1
		if visitors==2 and not game_ready:
			game_ready=true
			for family_id: String in session.state.families:
				if family_id!=session.profile_id:
					var guest: Dictionary=session.state.families[family_id].members[0]
					guest.needs.fun=20.0; guest.needs.social=20.0
		if visitors==2 and not recalled and FileAccess.file_exists(ticket_path+".1.played") and FileAccess.file_exists(ticket_path+".2.played"):
			if courtesy.is_empty():
				var host_family: Dictionary=session.state.families[session.profile_id]
				var finisher: Dictionary=host_family.members[0]; var waiter: Dictionary=host_family.members[1]
				var speaker := ""
				for object: Dictionary in session.state.lots[home].objects:
					if object.kind=="stereo": speaker=str(object.id)
				for family: Dictionary in session.state.families.values():
					if family.id!=session.profile_id: family.members[0].needs.fun=0.0
				finisher.needs.fun=98.0
				await _command({"type":"interact","member_id":finisher.id,"lot_id":home,"target_id":speaker})
				await _command({"type":"interact","member_id":waiter.id,"lot_id":home,"target_id":speaker})
				assert(waiter.task.is_empty() and waiter.queue.size()==1,"A fourth dancer waits for this room's three places")
				var place := Leisure.place(finisher)
				courtesy={"finisher":finisher.id,"waiter":waiter.id,"action":waiter.queue[0].id,"speaker":speaker,"from":[place.x,place.y]}
			if not courtesy_written:
				var host_family: Dictionary=session.state.families[session.profile_id]
				var finisher: Dictionary=host_family.members[0]; var waiter: Dictionary=host_family.members[1]
				if waiter.task.get("id")==courtesy.action and waiter.task.path.is_empty() and waiter.task.get("elapsed",0.0)>0.0:
					assert(Vector2(finisher.x,finisher.y).distance_to(Vector2(courtesy.from[0],courtesy.from[1]))==1.0)
					assert(finisher.task.is_empty() and finisher.activity_log[0].outcome=="done")
					courtesy.to=[finisher.x,finisher.y]
					var handoff := FileAccess.open(ticket_path+".courtesy",FileAccess.WRITE); handoff.store_string(JSON.stringify(courtesy)); handoff.close()
					courtesy_written=true
			if courtesy_written and FileAccess.file_exists(ticket_path+".1.handoff") and FileAccess.file_exists(ticket_path+".2.handoff"):
				await _command({"type": "build_begin", "lot_id": home})
				recalled=true
		for postcard: Dictionary in session.state.families[session.profile_id].mailbox.items:
			if not postcard.claimed:
				await _command({"type":"mail_read","id":postcard.id})
				await _command({"type":"mail_claim","id":postcard.id})
		if recalled and FileAccess.file_exists(ticket_path + ".1.done") and FileAccess.file_exists(ticket_path + ".2.done") and session.players.size() == 1:
			assert(session.state.families.size() == 3, "Reconnect created duplicate families")
			assert(delivered.size()==2 and session.state.families[session.profile_id].mailbox.items.size()==2,"Offline delivery and client gift postcards both reached the host")
			for family_id in session.state.families:
				if family_id != session.profile_id:
					assert(not session.state.families[family_id].online, "Disconnect did not enable caretaker")
					assert(not session.state.families[family_id].home_news.report.pending,"Client recap acknowledgement did not survive disconnect")
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
	var identity_members: Array=[]
	for resident: Dictionary in session.state.families[identity].members:
		identity_members.append({"id":resident.id,"name":"Resident "+index+" "+str(identity_members.size()+1),"appearance":{"skin":4,"hair":2,"shirt":3,"style":1},"favorite":"reading" if identity_members.is_empty() else "gardening"})
	var identity_command := {"type":"household_edit","name":"Gardeners "+index,"revision":session.state.families[identity].get("identity_revision",0),"members":identity_members}
	await _command(identity_command)
	for _attempt in range(50):
		if session.state.families[identity].name=="Gardeners "+index: break
		await create_timer(0.1).timeout
	assert(session.state.families[identity].members[1].appearance.shirt==3,"Appearance was not replicated")
	assert(session.state.families[identity].members[0].favorite=="reading" and session.state.families[identity].members[1].favorite=="gardening","Favorite pastimes were not replicated")
	await _command(identity_command,false)
	var routine_command := {"type":"routine_save","routine_id":"","revision":session.state.families[identity].routines.revision,"name":"Quiet time "+index,"steps":["bookshelf","table"]}
	await _command(routine_command)
	for _attempt in range(50):
		if session.state.families[identity].routines.entries.size()==3: break
		await create_timer(0.1).timeout
	assert(session.state.families[identity].routines.entries[2].name=="Quiet time "+index,"Independent libraries replicate the owning family's recipe")
	await _command(routine_command,false)
	# Ownership is enforced on the host, even for syntactically valid commands.
	await _command({"type": "build_begin", "lot_id": host_home}, false)
	await _command({"type": "build_begin", "lot_id": home})
	for _attempt in range(50):
		if session.state.lots[home].building: break
		await create_timer(0.1).timeout
	var window_intent := {"type":"set_window","lot_id":home,"x":7,"y":3,"style":"picture" if index=="1" else "shutters","revision":session.state.lots[home].revision}
	var window_price: int=preload("res://game/windows.gd").inspect(session.state.lots[home],window_intent).cost
	var window_funds: int=session.state.lots[home].funds
	await _command(window_intent); await _command(window_intent,false)
	for _attempt in range(50):
		if session.state.lots[home].windows.get("7,3")==window_intent.style: break
		await create_timer(0.1).timeout
	assert(session.state.lots[home].windows.get("7,3")==window_intent.style and session.state.lots[home].funds==window_funds-window_price,"Own window style and exact preview price replicate")
	assert(session.state.lots[home].walls.has([7,3]) and not session.world._walkable(session.state.lots[home],Vector2i(7,3)))
	var foreign_window: Dictionary=window_intent.duplicate(); foreign_window.lot_id=host_home; foreign_window.revision=session.state.lots[host_home].revision
	await _command(foreign_window,false)
	await _command({"type":"build_undo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if not session.state.lots[home].windows.has("7,3"): break
		await create_timer(0.1).timeout
	assert(not session.state.lots[home].windows.has("7,3") and session.state.lots[home].funds==window_funds)
	await _command({"type":"build_redo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if session.state.lots[home].windows.get("7,3")==window_intent.style: break
		await create_timer(0.1).timeout
	assert(session.state.lots[home].windows.get("7,3")==window_intent.style)
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
	for _attempt in range(50):
		if [0,0] in session.state.lots[home].floors: break
		await create_timer(0.1).timeout
	assert([0,0] in session.state.lots[home].floors,"Wait for the accepted revision before recoloring")
	var moved_id := ""
	for object: Dictionary in session.state.lots[home].objects:
		if object.kind=="fridge": moved_id=str(object.id)
	await _command({"type":"recolor","lot_id":home,"object_id":moved_id,"style":"ink","revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if session.world._object(session.state.lots[home],moved_id).get("color_style")=="ink": break
		await create_timer(0.1).timeout
	await _command({"type":"move_object","lot_id":home,"object_id":moved_id,"x":9,"y":4,"rotation":0})
	for _attempt in range(50):
		if int(session.world._object(session.state.lots[home],moved_id).x)==9: break
		await create_timer(0.1).timeout
	var room_command := {"type":"build_room","lot_id":home,"x":13,"y":0,"end_x":15,"end_y":2,"rotation":0,"revision":session.state.lots[home].revision}
	await _command(room_command)
	for _attempt in range(50):
		if [14,1] in session.state.lots[home].floors: break
		await create_timer(0.1).timeout
	assert([14,2] in session.state.lots[home].doors,"Room doorway was not replicated")
	await _command(room_command,false)
	await _command({"type":"build_undo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if not [14,1] in session.state.lots[home].floors: break
		await create_timer(0.1).timeout
	assert(not [14,2] in session.state.lots[home].doors,"Single undo did not remove the whole room")
	await _command({"type":"build_redo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if [14,1] in session.state.lots[home].floors: break
		await create_timer(0.1).timeout
	var paint := {"type":"paint","lot_id":home,"surface":"floor","finish":"sage_tile","x":14,"y":1,"end_x":14,"end_y":1,"revision":session.state.lots[home].revision}
	await _command(paint)
	await _command(paint,false)
	for _attempt in range(50):
		if session.state.lots[home].finishes.floor.get("14,1")=="sage_tile": break
		await create_timer(0.1).timeout
	assert(session.state.lots[home].finishes.floor.get("14,1")=="sage_tile","Painted floors did not replicate")
	await _command({"type":"place","lot_id":home,"kind":"plant","x":14,"y":1})
	for _attempt in range(50):
		if not session.world._object_at(session.state.lots[home],Vector2i(14,1)).is_empty(): break
		await create_timer(0.1).timeout
	var source_plant: String=session.world._object_at(session.state.lots[home],Vector2i(14,1)).id
	var pot_style := "rose" if index=="1" else "sage"
	var color_intent := {"type":"recolor","lot_id":home,"object_id":source_plant,"style":pot_style,"revision":session.state.lots[home].revision}
	var color_funds: int=session.state.lots[home].funds
	await _command(color_intent); await _command(color_intent,false)
	for _attempt in range(50):
		if session.world._object(session.state.lots[home],source_plant).get("color_style")==pot_style: break
		await create_timer(0.1).timeout
	assert(session.world._object(session.state.lots[home],source_plant).get("color_style")==pot_style and session.state.lots[home].funds==color_funds)
	await _command({"type":"build_undo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if not session.world._object(session.state.lots[home],source_plant).has("color_style"): break
		await create_timer(0.1).timeout
	assert(not session.world._object(session.state.lots[home],source_plant).has("color_style"))
	await _command({"type":"build_redo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if session.world._object(session.state.lots[home],source_plant).get("color_style")==pot_style: break
		await create_timer(0.1).timeout
	assert(session.world._object(session.state.lots[home],source_plant).get("color_style")==pot_style and session.state.lots[home].funds==color_funds)
	await _command({"type":"set_window","lot_id":home,"style":"cottage","x":13,"y":1,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if session.state.lots[home].windows.get("13,1")=="cottage": break
		await create_timer(0.1).timeout
	# Capture the host’s room recipe, then place from the saved library over Iroh.
	var save_room := {"type":"blueprint_save","lot_id":home,"source_x":14,"source_y":1,"name":"Garden nook "+index,"revision":session.state.lots[home].revision,"library_revision":session.state.families[identity].room_library.revision}
	var save_funds: int=session.state.lots[home].funds
	await _command(save_room); await _command(save_room,false)
	for _attempt in range(50):
		if session.state.families[identity].room_library.entries.size()==1: break
		await create_timer(0.1).timeout
	var saved_room: Dictionary=session.state.families[identity].room_library.entries[0].duplicate(true)
	assert(saved_room.name=="Garden nook "+index and saved_room.layout.objects[0].color_style==pot_style and session.state.lots[home].funds==save_funds)
	var foreign_save:=save_room.duplicate(true); foreign_save.lot_id=host_home
	await _command(foreign_save,false)
	var copy_intent := {"type":"place_blueprint","lot_id":home,"blueprint_id":saved_room.id,"library_revision":session.state.families[identity].room_library.revision,"x":4,"y":0,"rotation":1,"revision":session.state.lots[home].revision}
	var copy_plan: Dictionary=preload("res://game/room_copy.gd").inspect_source(session.state.lots[home],copy_intent,[],preload("res://game/room_library.gd").source(saved_room.layout))
	assert(copy_plan.ok and copy_plan.cost==482,str(copy_plan))
	var before_copy: int=session.state.lots[home].funds
	await _command(copy_intent); await _command(copy_intent,false)
	for _attempt in range(50):
		if preload("res://game/room_copy.gd").is_applied(session.state.lots[home],copy_plan): break
		await create_timer(0.1).timeout
	assert(preload("res://game/room_copy.gd").is_applied(session.state.lots[home],copy_plan) and session.state.lots[home].funds==before_copy-482)
	var copied_plant: String=session.world._object_at(session.state.lots[home],Vector2i(5,1)).id
	assert(copied_plant!=source_plant,"The host allocates a new object instead of copying the source identity")
	assert(session.world._object(session.state.lots[home],copied_plant).get("color_style")==pot_style,"Room duplication preserves the chosen pot color")
	await _command({"type":"build_undo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if not [5,1] in session.state.lots[home].floors: break
		await create_timer(0.1).timeout
	assert(session.state.lots[home].funds==before_copy and not session.state.lots[home].windows.has("5,0") and session.world._object(session.state.lots[home],copied_plant).is_empty())
	await _command({"type":"build_redo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if preload("res://game/room_copy.gd").is_applied(session.state.lots[home],copy_plan): break
		await create_timer(0.1).timeout
	assert(preload("res://game/room_copy.gd").is_applied(session.state.lots[home],copy_plan) and not session.world._object(session.state.lots[home],copied_plant).is_empty())
	# A reviewed whole-lot edit is priced once; Undo restores the entire accepted house.
	var before_clear: Dictionary=session.state.lots[home].duplicate(true)
	var clear_plan: Dictionary=preload("res://game/clear_lot.gd").inspect(before_clear); assert(clear_plan.ok)
	var clear_intent := {"type":"clear_lot","lot_id":home,"revision":before_clear.revision,"refund":clear_plan.refund}
	var foreign_clear:=clear_intent.duplicate(); foreign_clear.lot_id=host_home
	await _command(foreign_clear,false); await _command(clear_intent); await _command(clear_intent,false)
	for attempt in range(60):
		if preload("res://game/clear_lot.gd").empty(session.state.lots[home]): break
		await create_timer(0.1).timeout
	assert(preload("res://game/clear_lot.gd").empty(session.state.lots[home]) and session.state.lots[home].funds==int(before_clear.funds)+int(clear_plan.refund))
	assert(session.state.families[identity].room_library.entries==[saved_room],"Clearing the lot preserves its saved designs")
	await _command({"type":"build_undo","lot_id":home,"revision":session.state.lots[home].revision})
	for attempt in range(60):
		if session.state.lots[home].objects.size()==before_clear.objects.size(): break
		await create_timer(0.1).timeout
	for field: String in preload("res://game/world.gd").BUILD_FIELDS: assert(session.state.lots[home][field]==before_clear[field],"Whole-lot undo restores "+field)
	var fill := {"type":"paint","lot_id":home,"surface":"floor","selection":"room","finish":"walnut","x":7,"y":7,"revision":session.state.lots[home].revision}
	var fill_plan: Dictionary=preload("res://game/finishes.gd").inspect(session.state.lots[home],fill)
	assert(fill_plan.ok and fill_plan.area.size()==56 and fill_plan.cost==224)
	var before_fill: int=session.state.lots[home].funds
	await _command(fill); await _command(fill,false)
	for _attempt in range(50):
		if session.state.lots[home].finishes.floor.get("7,7")=="walnut": break
		await create_timer(0.1).timeout
	assert(session.state.lots[home].funds==before_fill-224 and not session.state.lots[home].finishes.floor.has("8,11"),"Actual room fill charges the preview price and stops at the door")
	await _command({"type":"build_undo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if not session.state.lots[home].finishes.floor.has("7,7"): break
		await create_timer(0.1).timeout
	assert(session.state.lots[home].funds==before_fill and session.state.lots[home].finishes.floor.get("14,1")=="sage_tile","One network undo restores the whole room while preserving earlier decoration")
	await _command({"type":"build_redo","lot_id":home,"revision":session.state.lots[home].revision})
	for _attempt in range(50):
		if session.state.lots[home].finishes.floor.get("7,7")=="walnut": break
		await create_timer(0.1).timeout
	assert(session.state.lots[home].finishes.floor.get("7,7")=="walnut")
	var people: Array=session.state.families[identity].members
	var positions: Array=[]
	for member: Dictionary in people: positions.append(Vector2i(int(member.x),int(member.y)))
	var closing := {"type":"place","lot_id":home,"kind":"wall","x":8,"y":11}
	var before_preview: Dictionary=session.world.snapshot()
	var closing_plan: Dictionary=preload("res://game/build_rules.gd").inspect(session.state.lots[home],closing,positions)
	var closing_impact: Dictionary=preload("res://game/build_impact.gd").inspect(session.state.lots[home],closing,closing_plan,people)
	assert(closing_plan.ok and closing_impact.warning and not closing_impact.introduced.is_empty() and session.world.snapshot()==before_preview,"A remote builder sees access consequences without making a speculative edit")
	await _command(closing)
	for _attempt in range(50):
		if not session.world.build_access(session.state.lots[home]).ok: break
		await create_timer(0.1).timeout
	var access: Dictionary=session.world.build_access(session.state.lots[home])
	assert(not access.ok and not access.issues.is_empty(),"A client derives blocked access from its accepted draft snapshot")
	assert(access==closing_impact.after,"The accepted host layout has exactly the previewed access consequence")
	await _command({"type":"build_end","lot_id":home},false)
	assert(session.last_action_message==access.message,"The client's access explanation matches the actual host rejection")
	var repair := {"type":"place","lot_id":home,"kind":"door","x":8,"y":11}
	var repair_plan: Dictionary=preload("res://game/build_rules.gd").inspect(session.state.lots[home],repair,positions)
	var repair_impact: Dictionary=preload("res://game/build_impact.gd").inspect(session.state.lots[home],repair,repair_plan,people)
	assert(repair_impact.ok and repair_impact.resolved.size()==access.issues.size())
	await _command(repair)
	for _attempt in range(50):
		if session.world.build_access(session.state.lots[home]).ok: break
		await create_timer(0.1).timeout
	assert(session.world.build_access(session.state.lots[home]).ok,"Repairing the doorway clears access in the replicated draft")
	assert(session.world.build_access(session.state.lots[home])==repair_impact.after)
	await _command({"type":"place","lot_id":home,"kind":"garden_bed","x":6,"y":13})
	var garden_id := ""
	for _attempt in range(50):
		for object: Dictionary in session.state.lots[home].objects:
			if object.kind=="garden_bed": garden_id=str(object.id)
		if not garden_id.is_empty(): break
		await create_timer(0.1).timeout
	assert(not garden_id.is_empty() and not session.state.lots[home].floors.has([6,13]),"A lawn garden replicates without inventing a floor")
	await _command({"type": "build_end", "lot_id": home})
	var gardener: String=session.state.families[identity].members[1].id
	await _command({"type":"autonomy","member_id":gardener,"enabled":false})
	await _command({"type":"cancel","member_id":gardener})
	var garden_crop := "radish" if index=="1" else "tomato"
	var plant := {"type":"garden","member_id":gardener,"lot_id":home,"target_id":garden_id,"action":"plant","crop":garden_crop,"revision":0}
	await _command(plant); await _command(plant,false)
	await _command({"type":"autonomy","member_id":member_id,"enabled":false})
	await _command({"type":"cancel","member_id":member_id})
	await _command({"type":"care","member_id":member_id,"need":"hunger"})
	for _attempt in range(50):
		if session.world.task_activity(session.state.families[identity].members[0].task,home)=="fridge": break
		await create_timer(0.1).timeout
	assert(session.world.task_activity(session.state.families[identity].members[0].task,home)=="fridge","Host-chosen care target was not replicated")
	await _command({"type":"care","member_id":member_id,"need":"hunger"},false)
	await _command({"type":"cancel","member_id":member_id})
	for _attempt in range(30):
		if session.state.families[identity].members[0].task.is_empty(): break
		await create_timer(0.1).timeout
	var walk_feedback := WalkFeedback.new()
	walk_feedback.update(session.state,identity,member_id,home,Vector2i.ZERO,true,false,0)
	assert(walk_feedback.preview.ok and walk_feedback.preview.ahead==0 and walk_feedback.markers.is_empty(),"Client's pure preview must not create accepted markers")
	await _command({"type":"move","member_id":member_id,"lot_id":home,"x":3,"y":3},false)
	walk_feedback.update(session.state,identity,member_id,home,Vector2i.ZERO,true,false,0)
	assert(walk_feedback.markers.is_empty(),"Host rejection cannot create a walk marker")
	await _command({"type":"move","member_id":member_id,"lot_id":home,"x":0,"y":0})
	await _command({"type":"move","member_id":member_id,"lot_id":home,"x":15,"y":15})
	await _command({"type":"move","member_id":member_id,"lot_id":home,"x":15,"y":14})
	var queued_id := ""
	var later_id := ""
	var active_id := ""
	for _attempt in range(30):
		var resident: Dictionary = session.state.families[identity].members[0]
		if resident.queue.size()==2 and not resident.task.is_empty():
			queued_id = str(resident.queue[0].id)
			later_id = str(resident.queue[1].id); active_id=str(resident.task.id)
			break
		await create_timer(0.1).timeout
	assert(not queued_id.is_empty(), "Replicated plan did not expose stable action ID")
	walk_feedback.update(session.state,identity,member_id,home,Vector2i(1,14),true,true,0)
	assert(walk_feedback.markers.size()==3 and walk_feedback.markers[0].id==active_id and walk_feedback.markers[1].id==queued_id and walk_feedback.markers[2].id==later_id)
	assert(walk_feedback.preview.ahead==3 and walk_feedback.markers[1].cell==Vector2i(15,15) and walk_feedback.markers[2].cell==Vector2i(15,14),"Client markers match host-accepted destinations and order")
	var reorder := {"type":"reorder_action","member_id":member_id,"first_id":queued_id,"second_id":later_id}
	await _command(reorder)
	for _attempt in range(30):
		var resident: Dictionary=session.state.families[identity].members[0]
		if resident.queue.size()==2 and resident.queue[0].id==later_id: break
		await create_timer(0.1).timeout
	var planned: Dictionary=session.state.families[identity].members[0]
	assert(planned.queue.size()==2 and planned.queue[0].id==later_id and planned.queue[1].id==queued_id and planned.task.id==active_id,"Edited order must replicate without interrupting the current activity")
	walk_feedback.update(session.state,identity,member_id,home,Vector2i.ZERO,false,true,0)
	assert(walk_feedback.markers[1].id==later_id and walk_feedback.markers[1].order==2 and walk_feedback.markers[2].id==queued_id,"Destination numbers follow the host's reordered plan")
	var run_routine := {"type":"run_routine","member_id":member_id,"routine_id":"routine_3","revision":session.state.families[identity].routines.revision}
	await _command(run_routine)
	await _command(run_routine,false)
	for _attempt in range(30):
		if session.state.families[identity].members[0].queue.size()==4: break
		await create_timer(0.1).timeout
	var routine_plan: Dictionary=session.state.families[identity].members[0]
	assert(routine_plan.queue.size()==4 and routine_plan.task.id==active_id and routine_plan.queue[0].id==later_id and routine_plan.queue[1].id==queued_id,"Adding a routine preserves accepted manual work")
	for step in range(2):
		assert(routine_plan.queue[step+2].routine_name=="Quiet time "+index and routine_plan.queue[step+2].routine_id=="routine_3")
		assert(session.world.task_activity(routine_plan.queue[step+2],home)==["bookshelf","table"][step],"Host resolves each activity to a reachable local furnishing in order")
	var captured_plan := preload("res://game/routines.gd").capture_plan(routine_plan,session.state.lots[home])
	assert(captured_plan.steps==["bookshelf","table"] and captured_plan.omitted.size()==3,"Client copies accepted reusable activities while explaining its three walking orders")
	var save_copy := {"type":"routine_save","routine_id":"","revision":session.state.families[identity].routines.revision,"name":"Copied plan "+index,"steps":captured_plan.steps}
	await _command(save_copy)
	await _command(save_copy,false)
	for _attempt in range(30):
		if session.state.families[identity].routines.entries.size()==4: break
		await create_timer(0.1).timeout
	assert(session.state.families[identity].routines.entries[3].steps==captured_plan.steps,"Reviewed copied steps save through the normal host authority command")
	var foreign_routine: Dictionary=run_routine.duplicate(); foreign_routine.member_id=session.state.families[str(session.state.lots[host_home].owner)].members[0].id
	await _command(foreign_routine,false)
	await _command(reorder,false)
	var foreign := reorder.duplicate(); foreign.member_id=session.state.families[str(session.state.lots[host_home].owner)].members[0].id
	await _command(foreign,false)
	await _command({"type":"remove_action","member_id":member_id,"action_id":queued_id})
	await _command({"type":"remove_action","member_id":member_id,"action_id":queued_id},false)
	var cancelled_result := false
	for _attempt in range(50):
		var matches := 0
		for entry: Dictionary in session.state.families[identity].members[0].activity_log:
			if entry.id==queued_id:
				matches+=1; assert(entry.outcome=="cancelled" and entry.reason=="Cancelled from Plan.")
		if matches==1: cancelled_result=true; break
		await create_timer(0.1).timeout
	assert(cancelled_result,"The exact cancelled task replicates once despite a repeated rejected packet")
	await _command({"type":"cancel","member_id":member_id})
	var wished_id := ""
	for wish: Dictionary in session.state.families[identity].members[0].wishes.wishes:
		if wish.id!="company": wished_id=str(wish.id); break
	await _command({"type":"pursue_wish","member_id":member_id,"wish_id":wished_id})
	var fulfilled := false
	for _attempt in range(350):
		for wish: Dictionary in session.state.families[identity].members[0].wishes.wishes:
			if wish.id==wished_id and wish.done: fulfilled=true
		if fulfilled: break
		await create_timer(0.1).timeout
	assert(fulfilled,"Host did not fulfill and replicate the client's wish")
	await _command({"type":"pursue_wish","member_id":member_id,"wish_id":wished_id},false)
	var practices_before := int(session.state.families[identity].members[0].hobbies.reading.sessions)
	await _command({"type":"practice_hobby","member_id":member_id,"hobby":"reading"})
	await _command({"type":"practice_hobby","member_id":member_id,"hobby":"reading"},false)
	for _attempt in range(200):
		if int(session.state.families[identity].members[0].hobbies.reading.sessions)==practices_before+1: break
		await create_timer(0.1).timeout
	assert(int(session.state.families[identity].members[0].hobbies.reading.sessions)==practices_before+1,"Completed reading did not replicate hobby progress")
	var companion_id: String=session.state.families[identity].members[1].id
	var garden: Dictionary=session.world._object(session.state.lots[home],garden_id).garden
	assert(garden.crop==garden_crop and garden.revision==1 and garden.growth>0,"A second resident's completed planting and continued growth replicate while the first follows their own plan")
	assert(session.state.families[identity].members[1].activity_log[0].reason=="Seeds planted.","Finished garden work replicates to the resident's history")
	await _command(plant,false)
	await _command({"type":"autonomy","member_id":companion_id,"enabled":false})
	await _command({"type":"cancel","member_id":companion_id})
	await _command({"type":"interact","member_id":member_id,"lot_id":home,"target_id":companion_id})
	for _attempt in range(200):
		if int(preload("res://game/friendships.gd").bond(session.state,member_id,companion_id).get("score",0))==32: break
		await create_timer(0.1).timeout
	assert(int(preload("res://game/friendships.gd").bond(session.state,member_id,companion_id).get("score",0))==32,"Completed chat did not replicate friendship progress")
	var postcard := {"type":"mail_send","recipient":session.state.lots[host_home].owner,"note":"Thanks for hosting the neighborhood!","gift":100,"sequence":1}
	await _command(postcard)
	await _command(postcard,false)
	for _attempt in range(50):
		if int(session.state.families[identity].mailbox.next_sent)==2: break
		await create_timer(0.1).timeout
	assert(int(session.state.families[identity].mailbox.next_sent)==2,"Postcard delivery did not replicate")
	await _command({"type": "visit", "lot_id": host_home, "member_id": member_id})
	for _attempt in range(200):
		var visitors := 0
		for family: Dictionary in session.state.families.values():
			if family.home_lot!=host_home and family.members[0].lot_id==host_home: visitors+=1
		if visitors==2: break
		await create_timer(0.1).timeout
	var game_table_id := ""
	for object: Dictionary in session.state.lots[host_home].objects:
		if object.kind=="game_table": game_table_id=str(object.id)
	assert(not game_table_id.is_empty())
	if index=="1":
		await _command({"type":"interact","member_id":member_id,"lot_id":host_home,"target_id":game_table_id})
	else:
		var join_intent: Dictionary={}
		for _attempt in range(100):
			for family: Dictionary in session.state.families.values():
				if family.id==identity or family.home_lot==host_home: continue
				var companion: Dictionary=family.members[0]
				var option: Dictionary=session.world.tabletop_option(session.state.families[identity].members[0],str(companion.id))
				if not option.is_empty() and option.available:
					join_intent={"type":"join_game","member_id":member_id,"lot_id":host_home,"companion_id":companion.id,"activity_id":option.activity_id}
			if not join_intent.is_empty(): break
			await create_timer(0.1).timeout
		assert(not join_intent.is_empty(),"The replicated People option discovers an actual client's game")
		var stale: Dictionary=join_intent.duplicate(); stale.activity_id="finished-activity"
		await _command(stale,false)
		await _command(join_intent)
		await _command(join_intent,false)
	var shared := false
	for _attempt in range(150):
		var guest: Dictionary=session.state.families[identity].members[0]
		var players: Array=preload("res://game/tabletop.gd").players(session.state,host_home,game_table_id)
		if players.size()==2 and guest.action=="Playing together" and guest.needs.social>22.0 and int(Bonds.bond(session.state,str(players[0].id),str(players[1].id)).get("score",0))==12:
			assert(preload("res://game/tabletop.gd").place(players[0])!=preload("res://game/tabletop.gd").place(players[1]))
			shared=true; break
		await create_timer(0.1).timeout
	assert(shared,"Both actual clients must observe shared play, social restoration, and separate places")
	var tabled := FileAccess.open(ticket_path+"."+index+".tabled",FileAccess.WRITE); tabled.store_string("observed"); tabled.close()
	for _attempt in range(50):
		if FileAccess.file_exists(ticket_path+".1.tabled") and FileAccess.file_exists(ticket_path+".2.tabled"): break
		await create_timer(0.1).timeout
	assert(FileAccess.file_exists(ticket_path+".1.tabled") and FileAccess.file_exists(ticket_path+".2.tabled"))
	await _command({"type":"cancel","member_id":member_id})
	var stereo_id := ""
	for object: Dictionary in session.state.lots[host_home].objects:
		if object.kind=="stereo": stereo_id=str(object.id)
	assert(not stereo_id.is_empty())
	var dance_social: float=session.state.families[identity].members[0].needs.social
	if index=="1":
		await _command({"type":"interact","member_id":member_id,"lot_id":host_home,"target_id":stereo_id})
	else:
		var dance_intent: Dictionary={}
		for _attempt in range(100):
			for family: Dictionary in session.state.families.values():
				if family.id==identity or family.home_lot==host_home: continue
				var companion: Dictionary=family.members[0]
				var option: Dictionary=session.world.leisure_option(session.state.families[identity].members[0],str(companion.id),"stereo")
				if not option.is_empty() and option.available:
					dance_intent={"type":"join_dance","member_id":member_id,"lot_id":host_home,"companion_id":companion.id,"activity_id":option.activity_id}
			if not dance_intent.is_empty(): break
			await create_timer(0.1).timeout
		assert(not dance_intent.is_empty(),"People discovers the other actual client's dance")
		var stale_dance := dance_intent.duplicate(); stale_dance.activity_id="finished-dance"; await _command(stale_dance,false)
		await _command(dance_intent); await _command(dance_intent,false)
	var danced := false
	for _attempt in range(100):
		var guest: Dictionary=session.state.families[identity].members[0]
		var dancers: Array=preload("res://game/shared_leisure.gd").players(session.state,host_home,stereo_id)
		if dancers.size()==2 and guest.action=="Dancing together" and guest.needs.social>dance_social+1.0 and int(Bonds.bond(session.state,str(dancers[0].id),str(dancers[1].id)).get("score",0))==24:
			assert(preload("res://game/shared_leisure.gd").place(dancers[0])!=preload("res://game/shared_leisure.gd").place(dancers[1]))
			var stereo: Dictionary={}
			for object: Dictionary in session.state.lots[host_home].objects:
				if object.id==stereo_id: stereo=object; break
			var places := Leisure.spaces(session.state,session.state.lots[host_home],stereo,guest)
			assert(places.capacity==3 and places.reserved==2,"Real clients derive the three-place room, not the catalog maximum")
			assert(places.cells.filter(func(cell): return cell.status=="reserved").size()==2)
			var bond := Bonds.bond(session.state,str(dancers[0].id),str(dancers[1].id))
			assert(bond.today==2 and bond.last_activity=="stereo","Real clients share the chat/game/dance friendship budget")
			danced=true; break
		await create_timer(0.1).timeout
	assert(danced,"Both clients observe separate dance spots and shared social restoration")
	var played := FileAccess.open(ticket_path+"."+index+".played",FileAccess.WRITE); played.store_string("shared"); played.close()
	var handoff_seen := false
	for _attempt in range(150):
		if FileAccess.file_exists(ticket_path+".courtesy"):
			var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ticket_path+".courtesy"))
			var finisher: Dictionary=session.world._find_member(str(expected.finisher))
			var waiter: Dictionary=session.world._find_member(str(expected.waiter))
			if Vector2i(finisher.x,finisher.y)==Vector2i(int(expected.to[0]),int(expected.to[1])) and waiter.task.get("id")==expected.action and waiter.task.path.is_empty():
				assert(finisher.activity_log[0].outcome=="done" and waiter.task.target_id==expected.speaker)
				handoff_seen=true; break
		await create_timer(0.1).timeout
	assert(handoff_seen,"Both actual clients observe a one-step departure and the same waiting plan taking its place")
	var handoff := FileAccess.open(ticket_path+"."+index+".handoff",FileAccess.WRITE); handoff.store_string("observed"); handoff.close()
	var recalled := false
	for _attempt in range(300):
		await create_timer(0.1).timeout
		if session.state.lots[host_home].building and session.state.families[identity].members[0].lot_id == home:
			recalled = true
			break
	assert(recalled, "Host construction did not recall visitor in replicated state")
	assert([0, 0] in session.state.lots[home].floors, "Accepted construction was not replicated")
	var hobbies_before: Dictionary=session.state.families[identity].members[0].hobbies.duplicate(true)
	var journal_before: Array=session.state.families[identity].members[0].wishes.journal.duplicate(true)
	var funds: float = session.state.lots[home].funds
	var garden_before: Dictionary=session.world._object(session.state.lots[home],garden_id).garden.duplicate(true)
	var garden_history: Array=session.state.families[identity].members[1].activity_log.duplicate(true)
	var bonds_before := {}
	for id: String in session.state.friendships:
		var bond: Dictionary=session.state.friendships[id]
		if member_id in [bond.a,bond.b]: bonds_before[id]=bond.duplicate(true)
	assert(bonds_before.values().any(func(bond): return bond.score==24 and bond.today==2 and bond.last_activity=="stereo"))
	session.leave()
	await create_timer(0.7).timeout
	await _connect()
	assert(session.state.families[identity].mailbox.items.size()==1 and not session.state.families[identity].mailbox.items[0].read,"A postcard delivered while disconnected is waiting on reconnect")
	var recap: Dictionary=session.state.families[identity].home_news.report
	assert(recap.pending and recap.postcards==1 and recap.gifts==0 and recap.allowance==0,"The host's absence recap did not replicate the actual offline postcard")
	await _command({"type":"news_read","revision":recap.id})
	for _attempt in range(50):
		if not session.state.families[identity].home_news.report.pending: break
		await create_timer(0.1).timeout
	assert(not session.state.families[identity].home_news.report.pending,"Acknowledged recap did not replicate")
	await _command(postcard,false)
	assert(session.home_lot() == home, "Reconnect changed lot ownership")
	for id: String in bonds_before: assert(session.state.friendships.get(id)==bonds_before[id],"Reconnect retains friendship gains, daily limits, and the last shared encounter")
	assert(session.state.families[identity].members[1].activity_log==garden_history,"Reconnect retains completed outcomes without inventing new entries")
	garden=session.world._object(session.state.lots[home],garden_id).garden
	assert(garden.crop==garden_before.crop and garden.revision==garden_before.revision and garden.growth>=garden_before.growth and garden.growth<=45.000001,"Reconnect retains crops; unattended growth stops safely when the planted water runs out")
	assert(session.state.lots[home].windows.get("7,3")==window_intent.style and session.state.lots[home].walls.has([7,3]),"Reconnect retains the mounted window without opening the wall")
	assert(session.state.families[identity].routines.entries[3].name=="Copied plan "+index and session.state.families[identity].routines.entries[3].steps==["bookshelf","table"],"Reconnect retains the reviewed copied routine")
	assert(session.state.families[identity].routines.entries[2].name=="Quiet time "+index and session.state.families[identity].routines.entries[2].steps==["bookshelf","table"],"Reconnect retains the independent routine library")
	assert(int(preload("res://game/friendships.gd").bond(session.state,member_id,companion_id).get("score",0))==32,"Reconnect lost the friendship")
	assert(session.state.families[identity].name=="Gardeners "+index and session.state.families[identity].members[1].appearance.style==1,"Reconnect lost household identity")
	assert(session.state.families[identity].members[0].favorite=="reading" and session.state.families[identity].members[1].favorite=="gardening","Reconnect lost favorite pastimes")
	assert([14,1] in session.state.lots[home].floors and [14,2] in session.state.lots[home].doors,"Reconnect lost the new room")
	assert(preload("res://game/room_copy.gd").is_applied(session.state.lots[home],copy_plan) and not session.world._object(session.state.lots[home],copied_plant).is_empty(),"Reconnect retains the copied design and its new object identities")
	assert(session.state.lots[home].finishes.floor.get("14,1")=="sage_tile","Reconnect lost the floor finish")
	assert(session.state.lots[home].finishes.floor.get("7,7")=="walnut" and not session.state.lots[home].finishes.floor.has("8,11"),"Reconnect retains the room fill and its doorway boundary")
	assert(int(session.world._object(session.state.lots[home],moved_id).x)==9, "Reconnect lost furnishing move")
	assert(session.world._object(session.state.lots[home],moved_id).get("color_style")=="ink" and session.world._object(session.state.lots[home],source_plant).get("color_style")==pot_style,"Recoloring survives moves, room copies, and reconnect")
	assert(session.state.families[identity].room_library.entries==[saved_room],"Saved room recipe, name and colors survive reconnect")
	assert(session.state.families[identity].members[0].hobbies==hobbies_before,"Reconnect lost personal hobbies")
	assert(session.state.families[identity].members[0].wishes.journal==journal_before,"Reconnect lost the activity journal")
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
