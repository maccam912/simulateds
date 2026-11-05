extends "res://tests/creator_peer.gd"
## Real Iroh: independent upstairs builds, maximum brush packet, saves/reconnect.
const Storeys = preload("res://game/storeys.gd")
const Landscape = preload("res://game/landscaping.gd")

func _host() -> void:
	assert(await rooms.host() if use_codes else session.host())
	preload("res://tests/peer_signal.gd").publish(ticket_path,rooms.code if use_codes else session.ticket())
	for attempt in range(850):
		if FileAccess.file_exists(ticket_path+".done1") and FileAccess.file_exists(ticket_path+".done2"):
			assert(session.save_world())
			var replica := preload("res://game/world.gd").new()
			assert(replica.restore(JSON.parse_string(FileAccess.get_file_as_string(session.save_path))))
			for family: Dictionary in replica.state.families.values():
				if family.id!=session.profile_id: _check_lot(replica.state.lots[family.home_lot])
			print("HOST_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit(); return
		await create_timer(0.1).timeout
	assert(false,"Both builders must finish and reconnect")

func _edit(intent: Dictionary) -> void:
	var home: String=session.home_lot()
	var revision: int=session.state.lots[home].revision
	intent.lot_id=home; intent.revision=revision
	await _command(intent)
	for attempt in range(100):
		if session.state.lots[home].revision>revision: return
		await create_timer(0.1).timeout
	assert(false,"Accepted construction must reach the client snapshot")

func _check_lot(lot: Dictionary) -> void:
	assert(not lot.building and lot.landscape.pools.size()==4 and not lot.landscape.paints.is_empty())
	assert(Storeys.stairs(lot,0).size()==1 and Storeys.view(lot,1).objects.size()==2)

func _client(index: String) -> void:
	await _connect()
	var home: String=session.home_lot()
	var member_id: String=session.state.families[session.profile_id].members[0].id
	await _command({"type":"autonomy","member_id":member_id,"enabled":false})
	await _edit({"type":"build_begin"})
	await _edit({"type":"landscape","kind":"pool","x":0,"y":10,"end_x":1,"end_y":11})
	var points: Array=[]
	for y in range(16):
		for x in range(16): points.append([x,y])
	await _edit({"type":"landscape","kind":"terrain_sand","x":0,"y":0,"end_x":15,"end_y":15,"radius":1,"stroke":Landscape.encode_stroke(points)})
	await _edit({"type":"place","kind":"stairs","x":6,"y":6,"rotation":1})
	await _edit({"type":"place_area","kind":"floor","level":1,"x":8,"y":2,"end_x":11,"end_y":8})
	await _edit({"type":"place","kind":"loveseat","level":1,"x":8,"y":8})
	await _edit({"type":"place","kind":"floor_lamp","level":1,"x":11,"y":6})
	var funds: int=session.state.lots[home].funds
	assert("Linen floor lamp" in session.state.lots[home].build_undo_hint and "Refund §95" in session.state.lots[home].build_undo_hint)
	await _edit({"type":"build_undo"})
	assert(session.state.lots[home].funds==funds+95 and "Cost §95" in session.state.lots[home].build_redo_hint)
	await _edit({"type":"build_redo"})
	assert(session.state.lots[home].funds==funds and "Refund §95" in session.state.lots[home].build_undo_hint)
	await _edit({"type":"build_end"})
	_check_lot(session.state.lots[home])
	await _command({"type":"use_stairs","lot_id":home,"member_id":member_id,"direction":1})
	for attempt in range(150):
		if session.world._find_member(member_id).get("level",0)==1: break
		await create_timer(0.1).timeout
	assert(session.world._find_member(member_id).level==1,"Stair travel replicates the resident's floor")
	session.leave(); await create_timer(0.4).timeout; await _connect()
	_check_lot(session.state.lots[home])
	_flag(".done"+index); print("CLIENT_PASS"); session.leave(); await root.get_node("Soundscape").shutdown_and_wait(); quit()
