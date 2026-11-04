extends SceneTree
## Real Iroh processes: two independent builders, visitor recall and reconnect.
const WalkFeedback = preload("res://game/walk_feedback.gd")
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
	for resident: Dictionary in session.state.families[session.profile_id].members:
		await _command({"type":"autonomy","member_id":resident.id,"enabled":false})
	await _command({"type":"build_begin","lot_id":session.home_lot()})
	await _command({"type":"place","lot_id":session.home_lot(),"kind":"game_table","x":8,"y":5})
	await _command({"type":"build_end","lot_id":session.home_lot()})
	await create_timer(2.0).timeout
	var file := FileAccess.open(ticket_path, FileAccess.WRITE)
	file.store_string(rooms.code if use_codes else session.ticket())
	file.close()
	var home: String = session.home_lot()
	var recalled := false
	var game_ready := false
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
		if visitors == 2 and not recalled and FileAccess.file_exists(ticket_path+".1.played") and FileAccess.file_exists(ticket_path+".2.played"):
			await _command({"type": "build_begin", "lot_id": home})
			recalled = true
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
	var moved_id := ""
	for object: Dictionary in session.state.lots[home].objects:
		if object.kind=="fridge": moved_id=str(object.id)
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
	await _command({"type":"place","lot_id":home,"kind":"wall","x":8,"y":11})
	for _attempt in range(50):
		if not session.world.build_access(session.state.lots[home]).ok: break
		await create_timer(0.1).timeout
	var access: Dictionary=session.world.build_access(session.state.lots[home])
	assert(not access.ok and not access.issues.is_empty(),"A client derives blocked access from its accepted draft snapshot")
	await _command({"type":"build_end","lot_id":home},false)
	assert(session.last_action_message==access.message,"The client's access explanation matches the actual host rejection")
	await _command({"type":"place","lot_id":home,"kind":"door","x":8,"y":11})
	for _attempt in range(50):
		if session.world.build_access(session.state.lots[home]).ok: break
		await create_timer(0.1).timeout
	assert(session.world.build_access(session.state.lots[home]).ok,"Repairing the doorway clears access in the replicated draft")
	await _command({"type": "build_end", "lot_id": home})
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
	await _command(reorder,false)
	var foreign := reorder.duplicate(); foreign.member_id=session.state.families[str(session.state.lots[host_home].owner)].members[0].id
	await _command(foreign,false)
	await _command({"type":"remove_action","member_id":member_id,"action_id":queued_id})
	await _command({"type":"remove_action","member_id":member_id,"action_id":queued_id},false)
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
		if players.size()==2 and guest.action=="Playing together" and guest.needs.social>22.0:
			assert(preload("res://game/tabletop.gd").place(players[0])!=preload("res://game/tabletop.gd").place(players[1]))
			shared=true; break
		await create_timer(0.1).timeout
	assert(shared,"Both actual clients must observe shared play, social restoration, and separate places")
	var played := FileAccess.open(ticket_path+"."+index+".played",FileAccess.WRITE); played.store_string("shared"); played.close()
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
	assert(int(preload("res://game/friendships.gd").bond(session.state,member_id,companion_id).get("score",0))==32,"Reconnect lost the friendship")
	assert(session.state.families[identity].name=="Gardeners "+index and session.state.families[identity].members[1].appearance.style==1,"Reconnect lost household identity")
	assert(session.state.families[identity].members[0].favorite=="reading" and session.state.families[identity].members[1].favorite=="gardening","Reconnect lost favorite pastimes")
	assert([14,1] in session.state.lots[home].floors and [14,2] in session.state.lots[home].doors,"Reconnect lost the new room")
	assert(session.state.lots[home].finishes.floor.get("14,1")=="sage_tile","Reconnect lost the floor finish")
	assert(session.state.lots[home].finishes.floor.get("7,7")=="walnut" and not session.state.lots[home].finishes.floor.has("8,11"),"Reconnect retains the room fill and its doorway boundary")
	assert(int(session.world._object(session.state.lots[home],moved_id).x)==9, "Reconnect lost furnishing move")
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
