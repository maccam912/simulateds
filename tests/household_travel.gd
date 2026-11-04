extends SceneTree
const World=preload("res://game/world.gd")
var world: RefCounted
var first: Dictionary
var second: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b","c"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for member: Dictionary in world.state.families[owner].members: member.autonomy=false
	first=world.state.families.a.members[0]; second=world.state.families.a.members[1]
func _intent(destination: String="lot_2",ids: Array=[]) -> Dictionary:
	if ids.is_empty(): ids=[first.id,second.id]
	var option: Dictionary=world.travel_option("a",destination,ids)
	return {"type":"travel_household","member_id":first.id,"lot_id":destination,"travelers":ids.duplicate(),"orders":option.orders.duplicate(true)}
func _reject(command: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); var result: Dictionary=world.apply_command(owner,command)
	assert(not result.ok and before==world.snapshot(),str(result))
func _position(member: Dictionary) -> Vector2i: return Vector2i(member.x,member.y)
func _run() -> void:
	_fresh(); var before: Dictionary=world.snapshot(); var command:=_intent()
	assert(world.snapshot()==before and command.orders.size()==2)
	for change: Dictionary in [{"travelers":[]},{"travelers":{}},{"travelers":[first.id,first.id]},{"travelers":[first.id,"b_1"]},{"travelers":[[]]},{"orders":[]},{"lot_id":[]},{"lot_id":"lot_4"},{"member_id":"b_1"}]:
		var bad:=command.duplicate(true); bad.merge(change,true); _reject(bad)
	for change: Dictionary in [{"next_action":1.5},{"next_action":INF},{"lot_id":"lot_3"},{"activity_id":[]},{"queue":["stale"]},{"extra":true}]:
		var bad:=command.duplicate(true); bad.orders[0].merge(change,true); _reject(bad)
	var missing_destination:=command.duplicate(true); missing_destination.erase("lot_id"); _reject(missing_destination)
	_reject(command,"b")
	assert(world.apply_command("a",JSON.parse_string(JSON.stringify(command))).ok)
	assert(first.lot_id=="lot_2" and second.lot_id=="lot_2" and _position(first)!=_position(second))
	assert(world.state.families.b==before.families.b and world.state.families.c==before.families.c and world.state.lots==before.lots)
	_reject(command)
	before=world.snapshot(); assert(world.apply_command("a",{"type":"visit","member_id":first.id,"lot_id":"lot_2"}).ok and world.snapshot()==before)
	var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(world.apply_command("a",_intent("lot_1")).ok and first.lot_id=="lot_1" and second.lot_id=="lot_1" and _position(first)!=_position(second))
	_reject(command) # Returning to the same origin does not revive an old travel choice.
	# A travelling subset cancels only its own accepted work, with visible history.
	_fresh()
	for member: Dictionary in [first,second]:
		assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":"lot_1","x":0,"y":0}).ok)
		assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":"lot_1","x":1,"y":0}).ok)
	var untouched: Dictionary=second.duplicate(true)
	assert(world.apply_command("a",_intent("lot_2",[first.id])).ok and second==untouched)
	assert(first.task.is_empty() and first.queue.is_empty() and first.activity_log.size()==2 and first.activity_log.all(func(row): return row.outcome=="cancelled" and row.reason.contains("Travelled to Willow")))
	# Changed/finished plans or locations reject both moves before cancellation.
	_fresh(); command=_intent(); assert(world.apply_command("a",{"type":"move","member_id":second.id,"lot_id":"lot_1","x":0,"y":0}).ok); _reject(command)
	_fresh(); command=_intent(); assert(world.apply_command("a",{"type":"visit","member_id":second.id,"lot_id":"lot_3"}).ok); _reject(command)
	assert(world.apply_command("a",{"type":"go_home","member_id":second.id}).ok); _reject(command)
	for home: String in ["lot_1","lot_2"]:
		_fresh(); command=_intent(); assert(world.apply_command("a" if home=="lot_1" else "b",{"type":"build_begin","lot_id":home}).ok); _reject(command)
	# Arrivals avoid residents and only use places reachable from the entrance.
	_fresh(); var host: Dictionary=world.state.families.b.members[0]; host.x=8; host.y=14
	assert(world.apply_command("a",_intent()).ok)
	assert(_position(first)!=_position(second) and _position(first)!=_position(host) and _position(second)!=_position(host))
	assert(world.apply_command("b",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(first.lot_id=="lot_1" and second.lot_id=="lot_1" and _position(first)!=_position(second))
	assert(first.activity_log.is_empty() and second.activity_log.is_empty())
	_fresh(); var lot: Dictionary=world.state.lots.lot_2
	lot.walls.append_array([[9,14],[8,15],[7,14],[8,13]])
	command=_intent(); _reject(command)
	assert(world.travel_option("a","lot_2",[first.id]).ok,"One person fits at the isolated entrance; a pair must not partly arrive")
	_fresh(); lot=world.state.lots.lot_2; lot.walls.append([8,14]); assert(not world.travel_option("a","lot_2",[first.id]).ok)
	# Ordinary visitors and a later forced return also get separate places.
	_fresh()
	for member: Dictionary in [first,second]: assert(world.apply_command("a",{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)
	assert(_position(first)!=_position(second)); world.set_online("a",false)
	assert(first.lot_id=="lot_1" and second.lot_id=="lot_1" and _position(first)!=_position(second))
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	print("HOUSEHOLD_TRAVEL_PASS"); quit()
