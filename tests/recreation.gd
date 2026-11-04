extends SceneTree
const World=preload("res://game/world.gd")
const Leisure=preload("res://game/shared_leisure.gd")
const Bonds=preload("res://game/friendships.gd")
var world: RefCounted
var lot: Dictionary
var object: Dictionary
var first: Dictionary
var second: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh(kind: String="game_table") -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=70.0
			resident.needs.fun=0.0; resident.needs.social=0.0
	lot=world.state.lots.lot_1; first=world.state.families.a.members[0]; second=world.state.families.a.members[1]
	first.x=7; first.y=5; second.x=8; second.y=7
	object=world._new_object(kind,8,5,0); lot.objects.append(object)
func _option(household: bool=true,owner: String="a",selected: String="a_1") -> Dictionary: return world.recreation_option(owner,selected,lot.id,object.id,household)
func _intent(household: bool=true,owner: String="a",selected: String="a_1") -> Dictionary:
	var option:=_option(household,owner,selected)
	return {"type":"recreation","member_id":selected,"lot_id":lot.id,"target_id":object.id,"household":household,"revision":lot.revision,"orders":option.orders.duplicate(true)}
func _reject(command: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); var result: Dictionary=world.apply_command(owner,command)
	assert(not result.ok and world.snapshot()==before,"Rejected recreation must leave the whole neighborhood unchanged")
func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): world.step(0.1)
func _arrive() -> void:
	for tick in range(100):
		world.step(0.1)
		if Leisure.players(world.state,lot.id,object.id).size()==2: return
	assert(false,"Both housemates should reach separate places")
func _run() -> void:
	for kind: String in ["game_table","stereo"]:
		_fresh(kind); var before: Dictionary=world.snapshot(); var option:=_option()
		assert(option.ok and option.orders.size()==2 and world.snapshot()==before)
		var command:=_intent()
		for change: Dictionary in [{"orders":[]},{"orders":{}},{"revision":-1},{"revision":0.5},{"target_id":null},{"target_id":"missing"},{"member_id":"b_1"},{"household":1},{"lot_id":null}]:
			var bad:=command.duplicate(true); bad.merge(change,true); _reject(bad)
		for change: Dictionary in [{"action":"buy"},{"member_id":"b_1"},{"lot_id":"lot_2"},{"next_action":INF},{"next_action":1.5},{"queue":["old"]},{"activity_id":false},{"extra":true}]:
			var bad:=command.duplicate(true); bad.orders[0].merge(change,true); _reject(bad)
		_reject(command,"b"); _reject(command,"unknown")
		assert(world.apply_command("a",JSON.parse_string(JSON.stringify(command))).ok); _reject(command)
		assert(world.state.lots==before.lots and world.state.families.b==before.families.b and world.state.next_object==before.next_object)
		assert(first.task.target_id==object.id and second.task.target_id==object.id and not _option().ok)
		_arrive(); assert(Leisure.place(first)!=Leisure.place(second)); _advance(4)
		assert(Bonds.bond(world.state,first.id,second.id).today==1 and first.needs.social>0 and second.needs.social>0)
		var visitor_task: Dictionary=second.task.duplicate(true)
		assert(world.apply_command("a",{"type":"remove_action","member_id":first.id,"action_id":first.task.id}).ok and second.task==visitor_task)
		# Existing deliberate work retains its exact order; the group call appends.
		_fresh(kind); var bookshelf: Dictionary=world._object_at(lot,Vector2i(10,10))
		assert(world.apply_command("a",{"type":"interact","member_id":first.id,"target_id":bookshelf.id}).ok)
		assert(world.apply_command("a",{"type":"move","member_id":first.id,"x":7,"y":6}).ok)
		var task: Dictionary=first.task.duplicate(true); var queue: Array=first.queue.duplicate(true)
		assert(_option().rows[0].detail.begins_with("After their plan")); assert(world.apply_command("a",_intent()).ok)
		assert(first.task==task and first.queue.size()==2 and first.queue[0]==queue[0] and first.queue[1].target_id==object.id)
		# A stale resident plan rejects before either housemate is changed.
		_fresh(kind); command=_intent(); assert(world.apply_command("a",{"type":"move","member_id":second.id,"x":0,"y":14}).ok); _reject(command)
		_fresh(kind); command=_intent(); command.orders[1]=command.orders[0].duplicate(true); _reject(command)
		_fresh(kind); assert(world.apply_command("a",_intent(false)).ok); task=first.task.duplicate(true)
		assert(_option().orders.size()==1 and world.apply_command("a",_intent()).ok and first.task==task)
		# Current automatic play is chosen in place without restarting its timer.
		_fresh(kind)
		for resident: Dictionary in [first,second]:
			world._queue_action(resident,{"type":"interact","target_id":object.id,"automatic":true}); world._start_next(resident,lot)
		_arrive(); _advance(4); assert(Bonds.bond(world.state,first.id,second.id).today==0)
		var old_first: Dictionary=first.task.duplicate(true); var old_second: Dictionary=second.task.duplicate(true)
		command=_intent(); assert(command.orders.all(func(row): return row.action=="choose")); assert(world.apply_command("a",command).ok); _reject(command)
		assert(first.task.remaining==old_first.remaining and second.task.remaining==old_second.remaining and first.task.elapsed==old_first.elapsed)
		assert(first.task.path==old_first.path and not first.task.get("automatic",false) and not first.task.has("social_started") and Leisure.chosen_time(first.task)==0)
		assert(not second.task.get("automatic",false) and Leisure.chosen_time(second.task)==0)
		var restored:=World.new(); var snapshot: Dictionary=JSON.parse_string(JSON.stringify(world.snapshot()))
		assert(restored.restore(snapshot,true) and is_equal_approx(float(restored.state.families.a.members[0].task.leisure_chosen_at),float(first.task.leisure_chosen_at)))
		for bad_value: Variant in [-1,INF,float(first.task.elapsed)+1,"now"]:
			var bad:=snapshot.duplicate(true); bad.families.a.members[0].task.leisure_chosen_at=bad_value; assert(not restored.restore(bad,true))
		var bad:=snapshot.duplicate(true); bad.families.a.members[0].task.automatic=true; assert(not restored.restore(bad,true))
		bad=snapshot.duplicate(true); bad.families.a.members[0].task.target_id=world._object_at(lot,Vector2i(10,10)).id; assert(not restored.restore(bad,true))
		_advance(3.9); assert(Bonds.bond(world.state,first.id,second.id).today==0,"Earlier automatic play cannot earn instant friendship")
		_advance(0.2); assert(Bonds.bond(world.state,first.id,second.id).today==1)
		# Near-complete activities end naturally instead of extending to farm credit.
		_fresh(kind)
		for resident: Dictionary in [first,second]:
			world._queue_action(resident,{"type":"interact","target_id":object.id,"automatic":true}); world._start_next(resident,lot)
		_arrive()
		for resident: Dictionary in [first,second]: resident.task.elapsed=13.5; resident.task.remaining=0.5
		assert(world.apply_command("a",_intent()).ok); _advance(0.7)
		assert(first.task.is_empty() and second.task.is_empty() and Bonds.bond(world.state,first.id,second.id).today==0)
		# Away, full, and unreachable residents are explained and left alone.
		_fresh(kind); assert(world.apply_command("a",{"type":"visit","member_id":first.id,"lot_id":"lot_2"}).ok)
		var away:=first.duplicate(true); assert(_option().orders.size()==1 and _option().rows[0].detail.begins_with("Away"))
		assert(world.apply_command("a",_intent()).ok and first==away and second.task.target_id==object.id)
		_fresh(kind)
		for index in range(World.MAX_QUEUE): world._queue_action(first,{"type":"move","x":0,"y":14})
		queue=first.queue.duplicate(true); assert(_option().orders.size()==1 and _option().rows[0].detail.begins_with("Plan full"))
		assert(world.apply_command("a",_intent()).ok and first.queue==queue and first.task.is_empty())
		_fresh(kind); first.x=0; first.y=0; lot.walls.append_array([[1,0],[0,1]])
		assert(_option().orders.size()==1 and _option().rows[0].detail.begins_with("No path")); assert(world.apply_command("a",_intent()).ok and first.task.is_empty())
		# The caller may be a visitor; no host family or other player is controlled.
		_fresh(kind); var original: Dictionary=world.state.families.a.duplicate(true)
		for resident: Dictionary in world.state.families.b.members: assert(world.apply_command("b",{"type":"visit","member_id":resident.id,"lot_id":lot.id}).ok)
		assert(world.apply_command("b",_intent(true,"b","b_1")).ok and world.state.families.a==original)
		_fresh(kind); command=_intent(); assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok); _reject(command)
		_fresh(kind); first.next_action=9007199254740000; assert(_option().orders.size()==1); assert(world.apply_command("a",_intent()).ok and first.task.is_empty())
		_fresh(kind); command=_intent(); command.erase("lot_id"); assert(world.apply_command("a",command).ok)
	# Temporary capacity waits are ordinary plans; they do not steal a place.
	_fresh("stereo"); first.x=7; first.y=6; lot.walls.append_array([[7,5],[8,4],[9,5]])
	assert(world.apply_command("a",_intent()).ok and second.task.is_empty() and second.queue.size()==1)
	assert(world._member(world.state.families.a,first.id).task.target_id==object.id)
	print("RECREATION_PASS"); quit()
