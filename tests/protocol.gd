extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node("Session")
	session.set_physics_process(false)
	session.world.initialize()
	session.world.ensure_family(session.profile_id, "Test family")
	var home: String = session.home_lot()
	session.role = "host"
	session.players = {1: session.profile_id, 2: session.profile_id}
	var original: String = JSON.stringify(session.state)
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
	session.role = "offline"
	session.players = {1: session.profile_id}
	assert(session.save_world(), "Save failed")
	var persisted: Dictionary = preload("res://game/persistence.gd").read_json(session.save_path)
	assert(persisted.ok, "Saved JSON could not be read")
	var restored = preload("res://game/world.gd").new()
	assert(restored.restore(persisted.data), "Save could not be restored")
	print("PROTOCOL_PASS")
	quit()
