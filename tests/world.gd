extends SceneTree
const World = preload("res://game/world.gd")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TEST FAIL: " + message)

func _run() -> void:
	var world := World.new()
	world.initialize()
	check(world.state.lots.size() == 4, "four lots")
	check(world.ensure_family("alice", "Alice") == "lot_1", "first family ownership")
	check(world.ensure_family("violet", "Violet") == "lot_2", "second family ownership")
	world.set_online("alice", true)
	world.set_online("violet", true)
	var alice: Dictionary = world.state.families.alice.members[0]
	var violet: Dictionary = world.state.families.violet.members[0]
	var lot: Dictionary = world.state.lots.lot_1
	check(world._layout_issue(lot).is_empty(), "starter layout accessible")
	check(not world.apply_command("violet", {"type":"build_begin", "lot_id":"lot_1"}).ok, "foreign building rejected")
	check(not world.apply_command("violet", {"type":"move", "member_id":alice.id, "lot_id":"lot_1", "x":7,"y":8}).ok, "foreign control rejected")
	check(world.apply_command("violet", {"type":"visit", "member_id":violet.id, "lot_id":"lot_1"}).ok, "visit owner lot")
	check(violet.lot_id == "lot_1", "visitor present")
	check(world.apply_command("alice", {"type":"build_begin", "lot_id":"lot_1"}).ok, "construction begins")
	check(violet.lot_id == "lot_2", "construction evicts visitor")
	check(not world.apply_command("violet", {"type":"visit", "member_id":violet.id, "lot_id":"lot_1"}).ok, "construction rejects visit")
	var previous_needs: Dictionary = alice.needs.duplicate()
	world.step(1.0)
	check(alice.needs == previous_needs, "construction freezes resident needs")
	var old_funds: int = lot.funds
	check(world.apply_command("alice", {"type":"place", "lot_id":"lot_1", "kind":"floor", "x":2, "y":2}).ok, "place floor")
	check(lot.funds == old_funds - 12, "debit price")
	check(world.apply_command("alice", {"type":"place", "lot_id":"lot_1", "kind":"plant", "x":2, "y":2}).ok, "place furniture")
	check(not world.apply_command("alice", {"type":"place", "lot_id":"lot_1", "kind":"wall", "x":2, "y":2}).ok, "no wall over furniture")
	check(world.apply_command("alice", {"type":"erase", "lot_id":"lot_1", "x":2, "y":2}).ok, "sell furniture")
	check(lot.funds == old_funds - 12 - 45 + 27, "refund sixty percent")
	check(world.apply_command("alice", {"type":"build_end", "lot_id":"lot_1"}).ok, "construction publishes")
	var fridge: Dictionary = {}
	for object: Dictionary in lot.objects:
		if object.kind == "fridge": fridge = object
	alice.needs.hunger = 10.0
	check(world.apply_command("alice", {"type":"interact", "lot_id":"lot_1", "member_id":alice.id, "target_id":fridge.id}).ok, "fridge queued")
	for index in range(150): world.step(0.1)
	check(alice.needs.hunger > 70.0, "reachable fridge restores hunger")
	# Social interaction affects both residents without commandeering the target.
	world.apply_command("alice", {"type":"cancel", "member_id":alice.id})
	var companion: Dictionary = world.state.families.alice.members[1]
	world._clear_member(companion)
	alice.x = 7
	alice.y = 7
	companion.x = 8
	companion.y = 7
	alice.needs.social = 20.0
	companion.needs.social = 30.0
	check(world.apply_command("alice", {"type":"interact", "lot_id":"lot_1", "member_id":alice.id, "target_id":companion.id}).ok, "chat with resident")
	world.step(0.5)
	check(alice.needs.social > 20.0 and companion.needs.social > 30.0, "conversation restores both social needs")
	check(companion.task.is_empty(), "chat does not take over target task")
	var valid_state: Dictionary = world.snapshot()
	var restored := World.new()
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(valid_state))
	check(restored.restore(decoded), "JSON save roundtrip")
	check(restored.state.lots.lot_1.funds == world.state.lots.lot_1.funds, "funds survive")
	check(not restored.state.families.alice.online, "presence not persisted")
	var malformed: Dictionary = valid_state.duplicate(true)
	malformed.lots.lot_1.objects[0].kind = "bogus"
	check(not restored.restore(malformed), "unknown furniture save rejected atomically")
	check(restored._layout_issue(restored.state.lots.lot_1).is_empty(), "integer tile paths survive JSON reload")
	var before_cancel: Dictionary = lot.duplicate(true)
	check(world.apply_command("alice", {"type":"build_begin", "lot_id":"lot_1"}).ok, "begin cancellable construction")
	check(world.apply_command("alice", {"type":"place", "lot_id":"lot_1", "kind":"plant", "x":2,"y":2}).ok, "draft purchase")
	var replica := World.new()
	check(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())), true), "live snapshot imports")
	check(replica.state.lots.lot_1.building and replica.state.families.alice.online, "live import preserves construction and presence")
	var restart := World.new()
	check(restart.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))), "committed snapshot imports")
	check(not restart.state.lots.lot_1.building and restart.state.lots.lot_1.objects == before_cancel.objects, "restart discards unfinished construction")
	check(world.apply_command("alice", {"type":"build_cancel", "lot_id":"lot_1"}).ok, "construction cancel")
	check(lot.objects == before_cancel.objects and lot.funds == before_cancel.funds and not lot.building, "cancel restores funds and layout")
	var prior_count: int = world.state.lots.lot_1.objects.size()
	check(world.apply_command("alice", {"type":"build_begin", "lot_id":"lot_1"}).ok, "second construction")
	check(world.apply_command("alice", {"type":"place", "lot_id":"lot_1", "kind":"plant", "x":2,"y":2}).ok, "second furnishing")
	world.set_online("alice", false)
	check(not lot.building and lot.objects.size() == prior_count, "disconnect rolls construction back")
	for member: Dictionary in world.state.families.alice.members:
		for key: String in member.needs: member.needs[key] = 56.0
	for index in range(200): world.step(1.0)
	for member: Dictionary in world.state.families.alice.members:
		for key: String in member.needs: check(float(member.needs[key]) >= 55.0, "caretaker protects " + key)
	check(not world.apply_command("alice", {"type":"move", "lot_id":"lot_1", "member_id":alice.id, "x":NAN,"y":2}).ok, "non-finite rejected")
	check(not world.apply_command("alice", {"type":"move", "lot_id":"lot_1", "member_id":alice.id, "x":2.5,"y":2}).ok, "fractional tile rejected")
	var sparse := World.new()
	sparse.initialize()
	sparse.ensure_family("sparse", "Sam")
	sparse.set_online("sparse", true)
	var sparse_member: Dictionary = sparse.state.families.sparse.members[0]
	for need: String in sparse_member.needs: sparse_member.needs[need] = 100.0
	sparse_member.needs.hunger = 0.0
	sparse_member.needs.energy = 20.0
	for object: Dictionary in sparse.state.lots.lot_1.objects.duplicate():
		if object.kind == "fridge": sparse.state.lots.lot_1.objects.erase(object)
	for index in range(80): sparse.step(0.25)
	check(sparse_member.needs.energy > 60.0, "missing hunger object does not block autonomous sleep")
	check(world.apply_command("alice", {"type":"rename_family", "name":"Alex"}).ok, "rename own family")
	check(world.state.families.alice.name == "Alex household" and alice.name == "Alex", "name changes preserve family identity")
	# Stable queue IDs make delayed cancellation safe across simulation ticks.
	var planner := World.new()
	planner.initialize(); planner.ensure_family("plan", "Pat"); planner.set_online("plan", true)
	var pat: Dictionary = planner.state.families.plan.members[0]
	check(planner.apply_command("plan", {"type":"autonomy","member_id":pat.id,"enabled":false}).ok, "disable autonomy")
	for index in range(90): planner.step(1.0)
	check(pat.task.is_empty() and pat.queue.is_empty(), "autonomy off leaves resident idle")
	check(planner.restore(planner.snapshot(),true), "long idle remains valid snapshot")
	pat=planner.state.families.plan.members[0]
	for target in [[1,1],[2,1],[2,2]]:
		check(planner.apply_command("plan", {"type":"move","member_id":pat.id,"lot_id":"lot_1","x":target[0],"y":target[1]}).ok, "queue ordered walk")
	var first_id: String=pat.task.id
	var second_id: String=pat.queue[0].id
	var third_id: String=pat.queue[1].id
	check(planner.apply_command("plan", {"type":"remove_action","member_id":pat.id,"action_id":second_id}).ok, "remove middle queued action")
	check(pat.task.id==first_id and pat.queue.size()==1 and pat.queue[0].id==third_id, "individual removal preserves remaining order")
	check(not planner.apply_command("plan", {"type":"remove_action","member_id":pat.id,"action_id":second_id}).ok, "stale cancellation rejected")
	check(planner.apply_command("plan", {"type":"remove_action","member_id":pat.id,"action_id":first_id}).ok, "cancel current action")
	check(pat.task.id==third_id, "next player order starts after current cancellation")
	planner.ensure_family("intruder","Other")
	check(not planner.apply_command("intruder", {"type":"autonomy","member_id":pat.id,"enabled":true}).ok, "foreign autonomy rejected")
	check(not planner.apply_command("intruder", {"type":"remove_action","member_id":pat.id,"action_id":third_id}).ok, "foreign queue cancellation rejected")
	var legacy: Dictionary=planner.snapshot()
	for family: Dictionary in legacy.families.values():
		for resident: Dictionary in family.members:
			resident.erase("autonomy"); resident.erase("next_action")
			resident.task.erase("id")
			for task: Dictionary in resident.queue: task.erase("id")
	check(planner.restore(legacy,true), "old saves gain queue IDs and autonomy defaults")
	check(planner.state.families.plan.members[0].autonomy and planner.state.families.plan.members[0].task.has("id"), "old runtime gets defaults")
	if failures == 0: print("WORLD_PASS")
	quit(1 if failures else 0)
