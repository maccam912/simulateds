extends SceneTree
## Cross-system acceptance checks for the neighborhood contract, without a network.
const Model = preload("res://game/world.gd")
const Catalog = preload("res://game/catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TEST FAIL: " + message)

func _run() -> void:
	var world = Model.new()
	world.initialize()
	var first: String = world.ensure_family("alpha", "Alex")
	var second: String = world.ensure_family("beta", "Violet")
	_expect(not first.is_empty() and not second.is_empty() and first != second, "Different profiles get different lots")
	_expect(world.ensure_family("alpha", "Renamed") == first and world.state.families.size() == 2, "Returning identity keeps its original household")
	world.set_online("alpha", true)
	world.set_online("beta", true)
	var a: Dictionary = world.state.families.alpha.members[0]
	var b: Dictionary = world.state.families.beta.members[0]
	var before: Dictionary = world.snapshot()
	_expect(not world.apply_command("alpha", {"type":"build_begin", "lot_id":second}).ok, "Neighbor cannot take construction ownership")
	_expect(not world.apply_command("alpha", {"type":"move", "lot_id":second, "member_id":b.id, "x":8, "y":14}).ok, "Neighbor cannot direct another family's resident")
	_expect(world.state == before, "Rejected ownership commands leave the world unchanged")
	_expect(world.apply_command("alpha", {"type":"visit", "member_id":a.id, "lot_id":second}).ok and a.lot_id == second, "Resident visits another open household")
	_expect(world.apply_command("beta", {"type":"build_begin", "lot_id":second}).ok, "Owner can begin construction while a visitor is present")
	_expect(a.lot_id == first and world.state.lots[second].building, "Construction returns visitors home and marks lot closed")
	_expect(not world.apply_command("alpha", {"type":"visit", "member_id":a.id, "lot_id":second}).ok, "Construction rejects new visitors")
	var replicated = Model.new()
	_expect(replicated.restore(JSON.parse_string(JSON.stringify(world.snapshot())), true), "Network snapshot restores live runtime state")
	_expect(replicated.state.lots[second].building and replicated.state.families.beta.online, "Network snapshot preserves construction and presence")
	var frozen: Dictionary = b.needs.duplicate(true)
	var neighbor_energy: float = a.needs.energy
	for index in range(8):
		world.step(0.25)
	_expect(b.needs == frozen, "Construction pauses the owner's needs")
	_expect(float(a.needs.energy) < neighbor_energy, "Another lot's residents keep living during construction")
	var funds: int = world.state.lots[second].funds
	_expect(world.apply_command("beta", {"type":"place", "lot_id":second, "kind":"floor", "x":14, "y":14}).ok, "Building adds a valid floor tile")
	_expect(world.state.lots[second].funds == funds - Catalog.ITEMS.floor.cost, "Purchase spends only the owning household's funds")
	_expect(world.apply_command("beta", {"type":"place", "lot_id":second, "kind":"plant", "x":14, "y":14}).ok, "Furniture can be purchased on the new floor")
	var count: int = world.state.lots[second].objects.size()
	_expect(not world.apply_command("beta", {"type":"place", "lot_id":second, "kind":"bed", "x":14, "y":14}).ok, "Overlapping furniture is rejected")
	_expect(world.state.lots[second].objects.size() == count, "Rejected placement does not add an object")
	_expect(world.apply_command("beta", {"type":"build_end", "lot_id":second}).ok, "Reachable new furnishing permits reopening")
	_expect(world.apply_command("alpha", {"type":"visit", "member_id":a.id, "lot_id":second}).ok, "Visitors can return after construction")
	_expect(world.apply_command("alpha", {"type":"go_home", "member_id":a.id}).ok and a.lot_id == first, "Go home restores the selected resident's home lot")
	world.set_online("alpha", false)
	_expect(not world.state.families.alpha.online and a.lot_id == first, "Disconnect retains the family and recalls its residents")
	var committed: Dictionary = world.state.lots[second].duplicate(true)
	_expect(world.apply_command("beta", {"type":"build_begin", "lot_id":second}).ok, "Second construction can begin")
	_expect(world.apply_command("beta", {"type":"erase", "lot_id":second, "x":14, "y":14}).ok, "Construction can sell a furnishing")
	world.set_online("beta", false)
	_expect(not world.state.lots[second].building, "Disconnect releases a construction lot")
	_expect(world.state.lots[second].objects == committed.objects and world.state.lots[second].funds == committed.funds, "Unfinished construction rolls back its objects and money on disconnect")
	world.set_online("beta", true)
	_expect(world.apply_command("beta", {"type":"build_begin", "lot_id":second}).ok, "Unsafe layout test begins construction")
	_expect(world.apply_command("beta", {"type":"place", "lot_id":second, "kind":"wall", "x":8, "y":11}).ok, "A doorway can be replaced during a draft")
	_expect(not world.apply_command("beta", {"type":"build_end", "lot_id":second}).ok and world.state.lots[second].building, "A draft that cuts off the furniture cannot reopen")
	var disk_candidate: Dictionary = world.snapshot_for_save()
	_expect(not disk_candidate.lots[second].building and disk_candidate.lots[second].doors == committed.doors, "Saving an unsafe construction draft retains the committed doorway")
	_expect(world.apply_command("beta", {"type":"build_cancel", "lot_id":second}).ok, "Owner can discard an unsafe draft")
	_expect(world.state.lots[second].doors == committed.doors and world.state.lots[second].funds == committed.funds, "Discard restores both layout and money")
	world.set_online("beta", false)
	for index in range(2400):
		world.step(0.25)
	for family: Dictionary in world.state.families.values():
		for member: Dictionary in family.members:
			for value in member.needs.values():
				_expect(is_finite(float(value)) and float(value) >= 55.0 and float(value) <= 100.0, "Caretaker needs remain finite and protected over a full simulated day")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.snapshot()))
	var loaded = Model.new()
	_expect(loaded.restore(saved), "JSON serialization round-trip restores a real simulated neighborhood")
	_expect(loaded.ensure_family("alpha", "Alex") == first and loaded.state.families.size() == 2, "Reloaded profile reclaims its existing household")
	_expect(JSON.stringify(loaded.state.lots[second].objects) == JSON.stringify(world.state.lots[second].objects), "Furniture survives save reload")
	_expect(loaded.state.lots[second].funds == world.state.lots[second].funds, "Household funds survive save reload")
	var loaded_member: Dictionary = loaded.state.families.alpha.members[0]
	_expect(not loaded.apply_command("alpha", {"type":"move", "member_id":loaded_member.id, "lot_id":first, "x":3, "y":3}).ok, "JSON-restored wall tiles still block movement")
	var protected: Dictionary = loaded.snapshot()
	for invalid in [{}, {"schema":99}, {"schema":1, "lots":[], "families":{}}]:
		_expect(not loaded.restore(invalid), "Malformed/future save rejected")
		_expect(loaded.state == protected, "Rejected save does not partially overwrite live state")
	var invalid_needs: Dictionary = saved.duplicate(true)
	invalid_needs.families.alpha.members[0].needs.hunger = "broken"
	_expect(not loaded.restore(invalid_needs) and loaded.state == protected, "Non-numeric need rejects save atomically")
	world.ensure_family("gamma", "Sam")
	world.ensure_family("delta", "Jamie")
	_expect(world.ensure_family("epsilon", "Extra").is_empty() and world.state.families.size() == 4, "A full neighborhood does not steal another household's lot")
	if failures.is_empty():
		print("INTEGRATION_WORLD_PASS")
	quit(0 if failures.is_empty() else 1)
