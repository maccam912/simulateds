extends SceneTree
const World = preload("res://game/world.gd")
const Access = preload("res://game/build_access.gd")
var world: RefCounted
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)

func _keys(report: Dictionary) -> Array:
	var result: Array=[]
	for issue: Dictionary in report.issues: result.append(issue.key)
	return result

func _legacy_message() -> String:
	var gate := Access.GATE
	if not world._walkable(lot,gate): return "Keep the lot entrance clear."
	for family: Dictionary in world.state.families.values():
		for member: Dictionary in family.members:
			var position := Vector2i(int(member.x),int(member.y))
			if member.lot_id==lot.id and position!=gate and world._path(lot,position,[gate]).is_empty(): return "A resident cannot reach the entrance. Add a door or clear a path."
	for object: Dictionary in lot.objects:
		if not world._can_reach_object(lot,gate,object): return "Leave a clear path to the "+str(World.Catalog.ITEMS[object.kind].name)+"."
	return ""

func _run() -> void:
	_fresh()
	var before: Dictionary=world.snapshot()
	var report: Dictionary=world.build_access(lot)
	assert(report.ok and report.reachable.has(Access.GATE) and world.snapshot()==before,"Opening the diagnostic leaves the entire draft unchanged")
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"wall","x":8,"y":11}).ok)
	report=world.build_access(lot)
	assert(not report.ok and report.issues.size()==12 and report.unreachable.has(Vector2i(7,7)),"Closing the front door identifies both residents and every unreachable furnishing")
	before=world.snapshot()
	var result: Dictionary=world.apply_command("a",{"type":"build_end","lot_id":lot.id})
	assert(not result.ok and result.message==report.message and world.snapshot()==before,"Finish building uses the same explanation without committing a bad draft")
	assert(world.apply_command("a",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok and world.build_access(lot).ok)
	assert(world.apply_command("a",{"type":"build_redo","lot_id":lot.id,"revision":lot.revision}).ok and not world.build_access(lot).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"door","x":8,"y":11}).ok and world.build_access(lot).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	_fresh()
	var bed: Dictionary=lot.objects[0]
	for cell: Vector2i in [Vector2i(5,4),Vector2i(5,5),Vector2i(4,6)]:
		assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"wall","x":cell.x,"y":cell.y}).ok)
	report=world.build_access(lot)
	assert(_keys(report)==["object:"+str(bed.id)] and report.issues[0].footprint==Vector2i(1,2),"A blocked bed has its own stable identifier and rotated footprint")
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"door","x":5,"y":5}).ok and world.build_access(lot).ok)
	var reload := World.new()
	assert(reload.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(reload.build_access(reload.state.lots.lot_1)==world.build_access(lot),"Replacement snapshots derive the same access without saved UI fields")
	# Compare the flood result against the independent ordinary pathfinder,
	# including rotations, legacy occupied starts, isolated rooms, and bad gates.
	var rng := RandomNumberGenerator.new(); rng.seed=6138
	for layout in range(180):
		_fresh(); lot.walls.clear(); lot.windows.clear()
		for y in range(16):
			for x in range(16):
				if rng.randf()<0.25: lot.walls.append([x,y])
		for object: Dictionary in lot.objects: object.rotation=rng.randi_range(0,3)
		for member: Dictionary in world.state.families.a.members:
			member.x=rng.randi_range(0,15); member.y=rng.randi_range(0,15)
		before=world.snapshot(); report=world.build_access(lot)
		assert(report.message==_legacy_message() and report.ok==report.message.is_empty() and world.snapshot()==before,"The shared report must preserve the host's actual reachability decision")
		if not world._walkable(lot,Access.GATE): continue
		var keys := _keys(report)
		for object: Dictionary in lot.objects:
			assert(keys.has("object:"+str(object.id))==not world._can_reach_object(lot,Access.GATE,object))
	print("BUILD_ACCESS_PASS")
	quit()
