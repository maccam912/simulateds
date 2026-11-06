extends SceneTree
## Legacy starter content repair must never rearrange a player's edited home.
const World = preload("res://game/world.gd")

func _initialize() -> void: call_deferred("_run")

func _tv(lot: Dictionary) -> Dictionary:
	return lot.objects.filter(func(item): return item.kind=="tv")[0]

func _legacy() -> Dictionary:
	var world := World.new(); world.initialize(); world.ensure_family("a","Alex")
	world.set_online("a",true)
	for member: Dictionary in world.state.families.a.members:
		member.autonomy=false; member.needs.fun=0.0
	var saved: Dictionary=world.snapshot_for_save()
	for lot: Dictionary in saved.lots.values():
		lot.objects=lot.objects.filter(func(item): return item.kind!="floor_lamp")
		_tv(lot).rotation=0
	return saved

func _order(world: RefCounted, member: Dictionary) -> Dictionary:
	return world.apply_command("a",{"type":"interact","member_id":member.id,"lot_id":"lot_1","target_id":_tv(world.state.lots.lot_1).id})

func _run() -> void:
	var legacy := _legacy(); var original := legacy.duplicate(true)
	var json: Dictionary=JSON.parse_string(JSON.stringify(legacy))
	var original_json := json.duplicate(true)
	var world := World.new()
	assert(world.restore(legacy,true))
	assert(_tv(world.state.lots.lot_1).rotation==0,"Network snapshots never repair host content on a client")
	assert(not _order(world,world.state.families.a.members[0]).ok,"Reproduce the old starter TV facing directly into the wall")
	var expected_state: Dictionary=world.snapshot()
	assert(world.restore_saved(json))
	assert(_tv(world.state.lots.lot_1).rotation==2,"Loading an untouched legacy starter must face the TV toward its sofa")
	assert(legacy==original and json==original_json,"Loading never edits the caller's save or disk bytes")
	for id: String in legacy.lots:
		var expected: Dictionary=legacy.lots[id].duplicate(true)
		_tv(expected).rotation=2; expected.revision=1
		assert(world.state.lots[id]==expected,"Only TV facing and lot revision change, including vacant starter homes")
		expected_state.lots[id]=expected
	assert(JSON.parse_string(JSON.stringify(world.snapshot()))==JSON.parse_string(JSON.stringify(expected_state)),"Preserve residents, plans, funds and all unrelated world data")
	assert(world.prepare_continuation("a").interrupted==0)
	var first: Dictionary=world.state.families.a.members[0]
	var second: Dictionary=world.state.families.a.members[1]
	assert(_order(world,first).ok and not str(first.task.tv_seat).is_empty())
	assert(_order(world,second).ok and str(second.task.tv_seat).is_empty())
	for tick in range(80):
		world.step(0.1)
		if first.task.get("elapsed",0)>0 and second.task.get("elapsed",0)>0: break
	assert(first.needs.fun>0 and second.needs.fun>0,"Both residents reach distinct places and actually watch")
	var saved: Dictionary=world.snapshot_for_save()
	var again := World.new(); assert(again.restore_saved(JSON.parse_string(JSON.stringify(saved))))
	assert(again.state.lots==world.state.lots,"Repair is idempotent")
	assert(again.prepare_continuation("a").interrupted==0,"New viewing reservations survive another save/load")
	assert(again.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true),"Host-repaired layouts and reservations replicate normally")
	# Any edit history protects the layout, even if the TV is in its old position.
	for change: String in ["revision","moved_tv","turned_sofa","missing_object","floor","wall","door","terrain","storey","building"]:
		var edited := _legacy(); var lot: Dictionary=edited.lots.lot_1
		match change:
			"revision": lot.revision=2
			"moved_tv": _tv(lot).x=6
			"turned_sofa": lot.objects.filter(func(item): return item.kind=="sofa")[0].rotation=2
			"missing_object": lot.objects.pop_back()
			"floor": lot.floors.erase([7,7])
			"wall": lot.walls.erase([4,11])
			"door": lot.doors.append([4,11]); lot.walls.erase([4,11])
			"terrain": lot.landscape.paints["1,1"]="sand"
			"storey": lot.storeys["1"]=preload("res://game/storeys.gd").empty()
			"building": lot.building=true
		assert(again.restore_saved(edited),change)
		assert(again.state.lots.lot_1==lot,"Preserve edited home: "+change)
	# Edited homes can explicitly repair the facing with ordinary Build commands.
	var edited := _legacy(); edited.lots.lot_1.revision=2
	assert(again.restore_saved(edited))
	var resident: Dictionary=again.state.families.a.members[0]
	var rejected := _order(again,resident)
	assert(not rejected.ok and "turn the television" in rejected.message)
	var home: Dictionary=again.state.lots.lot_1
	assert(again.apply_command("a",{"type":"build_begin","lot_id":home.id}).ok)
	assert(again.apply_command("a",{"type":"move_object","lot_id":home.id,"revision":home.revision,"object_id":_tv(home).id,"x":4,"y":10,"rotation":2}).ok)
	assert(again.apply_command("a",{"type":"build_end","lot_id":home.id}).ok)
	assert(_order(again,resident).ok,"Explicitly turning an edited home's TV restores viewing")
	# Earlier schema migrations must also reach the content repair.
	for schema in [1,2]:
		var older := _legacy(); older.schema=schema
		for lot: Dictionary in older.lots.values(): lot.erase("storeys")
		assert(again.restore_saved(older) and _tv(again.state.lots.lot_1).rotation==2)
	var current := World.new(); current.initialize()
	assert(again.restore_saved(current.snapshot_for_save()) and again.state.lots==current.state.lots,"New starters are unchanged")
	var held: Dictionary=again.snapshot(); var corrupt := _legacy(); corrupt.lots.lot_1.objects[0].kind="unknown"
	assert(not again.restore_saved(corrupt) and again.snapshot()==held,"Validate corrupt saves atomically before repairing content")
	print("STARTER_TELEVISION_PASS"); quit()
