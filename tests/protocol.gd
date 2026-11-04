extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node("Session")
	var completions: Array=[]
	session.command_completed.connect(func(intent: Dictionary,ok: bool,message: String): completions.append({"intent":intent,"ok":ok,"message":message}))
	session.set_physics_process(false)
	session.world.initialize()
	session.world.ensure_family(session.profile_id, "Test family")
	var home: String = session.home_lot()
	session.role = "host"
	session.players = {1: session.profile_id, 2: session.profile_id}
	var original: String = JSON.stringify(session.state)
	session._accept_hello(3,{"version":1,"credential":"a".repeat(64),"name":"Old client"})
	assert(JSON.stringify(session.state)==original and not session.players.has(3),"Old clients cannot join a neighborhood with unknown game-table content")
	session._receive(999, {"type": "command", "id": 1, "intent": {"type": "build_begin", "lot_id": home}})
	assert(JSON.stringify(session.state) == original, "Unknown sender changed the world")
	session._receive(2, {"type": "command", "id": 1, "intent": {"type": "build_begin", "lot_id": home}})
	assert(session.state.lots[home].building, "Valid command was not applied")
	session._receive(2, {"type": "command", "id": 2, "intent": {"type": "place", "lot_id": home, "kind": "floor", "x": 0, "y": 0}})
	var funds: float = session.state.lots[home].funds
	var after_place: String = JSON.stringify(session.state)
	session._receive(2, {"type": "command", "id": 2, "intent": {"type": "place", "lot_id": home, "kind": "floor", "x": 1, "y": 0}})
	assert(JSON.stringify(session.state) == after_place, "Duplicate ID executed again")
	for i in range(3, 70):
		session._receive(2, {"type": "command", "id": i, "intent": {"type": "invalid"}})
	session._receive(2, {"type": "command", "id": 2, "intent": {"type": "place", "lot_id": home, "kind": "floor", "x": 1, "y": 0}})
	assert(session.state.lots[home].funds == funds, "Evicted duplicate spent money")
	assert(not session._integer(NAN, 0, 100), "NaN admitted")
	assert(not session._integer(1.5, 0, 100), "Fractional ID admitted")
	assert(not session._valid_credential("profile-id"), "Arbitrary identity admitted")
	assert(session._valid_credential("a".repeat(64)), "Valid opaque credential rejected")
	# Snapshot chunks must be bounded, host-only and applied atomically.
	session._queue_snapshots()
	assert(session._outgoing.has(2), "No snapshot queued")
	var item: Dictionary = session._outgoing[2].duplicate(true)
	var bytes: PackedByteArray = item.raw
	var state_before: String = JSON.stringify(session.state)
	session.role = "client"
	session._welcomed = true
	for index in range(item.count):
		var offset: int = index * session.CHUNK_BYTES
		var packet := {"type": "chunk", "id": item.id, "index": index, "count": item.count, "size": item.size, "data": Marshalls.raw_to_base64(bytes.slice(offset, mini(offset + session.CHUNK_BYTES, bytes.size())))}
		assert(JSON.stringify(packet).to_utf8_buffer().size() <= session.MAX_PACKET, "Oversized wire packet")
		session._receive(777, packet)
		assert(session.snapshots_received == 0, "Accepted non-host snapshot")
		session._receive(1, packet)
		if index + 1 < item.count:
			assert(JSON.stringify(session.state) == state_before, "Partial snapshot leaked into state")
	assert(session.snapshots_received == 1, "Snapshot not assembled")
	assert(session.state.lots[home].building, "Replication hid active construction")
	var replicated: String = JSON.stringify(session.state)
	session._receive(1, {"type": "chunk", "id": 999, "index": 0, "count": 100000, "size": 100000000, "data": "bad"})
	assert(JSON.stringify(session.state) == replicated, "Malformed snapshot mutated state")
	# A completion identifies the original submitted command, never another
	# request or mutable editor draft. Bad/duplicate/non-host replies are ignored.
	var submitted := {"type":"routine_save","routine_id":"routine_1","revision":0,"name":"Morning","steps":["toilet","fridge"]}
	var original_intent: Dictionary=submitted.duplicate(true)
	session.command(submitted)
	var request_id: int=session._request_id
	submitted.name="A different draft"; submitted.steps.append("bed")
	assert(session._requests[request_id].packet.intent==original_intent)
	for reply: Dictionary in [{"type":"ack","id":request_id,"ok":"yes","message":"bad"},{"type":"ack","id":request_id,"ok":true,"message":42},{"type":"ack","id":request_id+1,"ok":true,"message":"unknown"}]:
		session._receive(1,reply)
	var ack := {"type":"ack","id":request_id,"ok":true,"message":"saved"}
	session._receive(777,ack)
	assert(completions.is_empty() and session._requests.has(request_id))
	session._receive(1,ack); session._receive(1,ack)
	assert(completions.size()==1 and completions[0].intent==original_intent and completions[0].ok and not session._requests.has(request_id))
	completions.clear()
	for index in range(16): session._requests[index]={}
	session.command(original_intent)
	assert(completions.size()==1 and not completions[0].ok and completions[0].intent==original_intent,"Backpressure also completes the correct editor command")
	session._requests.clear(); completions.clear()
	session.command({"type":"routine_save","name":"x".repeat(1500)})
	assert(completions.size()==1 and not completions[0].ok and session._requests.is_empty())
	session.role="joining"; completions.clear(); session.command(original_intent)
	assert(completions.size()==1 and not completions[0].ok and completions[0].intent==original_intent)
	session.role = "offline"
	completions.clear(); session.command(original_intent)
	assert(completions.size()==1 and completions[0].ok and completions[0].intent==original_intent,"Local commands report the same intent-scoped result")
	session.command(original_intent)
	assert(completions.size()==2 and not completions[1].ok,"Local stale edits report failure")
	session.players = {1: session.profile_id}
	assert(session.save_world(), "Save failed")
	var persisted: Dictionary = preload("res://game/persistence.gd").read_json(session.save_path)
	assert(persisted.ok, "Saved JSON could not be read")
	var restored = preload("res://game/world.gd").new()
	assert(restored.restore(persisted.data), "Save could not be restored")
	print("PROTOCOL_PASS")
	quit()
