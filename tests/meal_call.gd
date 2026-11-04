extends SceneTree
const World=preload("res://game/world.gd")
const Meals=preload("res://game/meals.gd")
var world: RefCounted
var lot: Dictionary
var table: Dictionary
var first: Dictionary
var second: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh(portions: int=4) -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=100.0
	lot=world.state.lots.lot_1; first=world.state.families.a.members[0]; second=world.state.families.a.members[1]
	first.x=7; first.y=6; second.x=8; second.y=5
	table=world._new_object("dining_table",8,6,0); lot.objects.append(table)
	table.meal={"recipe":"salad","servings":portions,"batch":1,"cook":first.id,"cook_name":first.name,"day":1}
func _option(member: Dictionary={}) -> Dictionary: return world.meal_call_option("a",str(member.get("id",first.id)),str(lot.id),str(table.id))
func _intent(member: Dictionary={}) -> Dictionary:
	var option:=_option(member)
	return {"type":"meal_call","member_id":str(member.get("id",first.id)),"lot_id":lot.id,"target_id":table.id,"batch":option.batch,"orders":option.orders.duplicate(true)}
func _reject(intent: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); var result: Dictionary=world.apply_command(owner,intent)
	assert(not result.ok and world.snapshot()==before,"A rejected household call must be atomic")
func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): world.step(0.1)
func _run() -> void:
	_fresh(); var before: Dictionary=world.snapshot(); var option:=_option()
	assert(option.ok and option.orders.size()==2 and option.rows[0].detail.begins_with("Join now") and world.snapshot()==before)
	var call:=_intent(); var foreign: Dictionary=world.state.families.b.duplicate(true); var funds: int=lot.funds
	for change: Dictionary in [{"orders":[]},{"orders":{}},{"batch":0},{"batch":1.2},{"target_id":[]},{"member_id":"b_1"}]:
		var bad:=call.duplicate(true); bad.merge(change,true); _reject(bad)
	for change: Dictionary in [{"member_id":"b_1"},{"action":"prepare"},{"next_action":1.1},{"next_action":INF},{"activity_id":[]},{"queue":["old"]},{"extra":true}]:
		var bad:=call.duplicate(true); bad.orders[0].merge(change,true); _reject(bad)
	_reject(call,"b")
	assert(world.apply_command("a",JSON.parse_string(JSON.stringify(call))).ok,"JSON numeric normalization preserves the previewed group")
	assert(first.task.meal_action=="eat" and second.task.meal_action=="eat" and first.task.id!=second.task.id and table.meal.servings==4)
	assert(Meals.available(world.state,lot,table)==2 and world.state.families.b==foreign and lot.funds==funds)
	_reject(call); assert(not _option().ok)
	var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	_advance(4); assert(first.action=="Eating together" and second.action=="Eating together" and table.meal.servings==2)
	for tick in range(40): replica.step(0.1)
	assert(replica.state.lots.lot_1.objects[-1].meal.servings==2)
	# Existing deliberate plans keep running, and their queue order stays intact.
	_fresh(); var bookshelf: Dictionary=world._object_at(lot,Vector2i(10,10))
	assert(world.apply_command("a",{"type":"interact","member_id":first.id,"lot_id":lot.id,"target_id":bookshelf.id}).ok)
	assert(world.apply_command("a",{"type":"move","member_id":first.id,"lot_id":lot.id,"x":7,"y":6}).ok)
	var task: Dictionary=first.task.duplicate(true); var queue: Array=first.queue.duplicate(true)
	assert(_option().rows[0].detail.begins_with("After their plan")); assert(world.apply_command("a",_intent()).ok)
	assert(first.task==task and first.queue.size()==queue.size()+1 and first.queue[0]==queue[0] and first.queue[-1].meal_action=="eat")
	# Changed plans or newly claimed food reject before touching either resident.
	_fresh(); call=_intent(); assert(world.apply_command("a",{"type":"move","member_id":second.id,"lot_id":lot.id,"x":0,"y":14}).ok); _reject(call)
	_fresh(2); call=_intent(); var guest: Dictionary=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":lot.id}).ok)
	assert(world.apply_command("b",{"type":"meal","member_id":guest.id,"lot_id":lot.id,"target_id":table.id,"action":"eat","recipe":"","batch":1}).ok)
	_reject(call); assert(first.task.is_empty() and second.task.is_empty())
	# A single remaining serving follows the preview's selected-resident priority.
	_fresh(1); option=_option(second); assert(option.orders.size()==1 and option.orders[0].member_id==second.id)
	assert(option.rows[1].detail.contains("No unreserved portion")); assert(world.apply_command("a",_intent(second)).ok)
	assert(first.task.is_empty() and second.task.meal_action=="eat")
	# Current automatic diners are chosen without consuming another portion or timer.
	_fresh(2)
	for member: Dictionary in [first,second]: member.autonomy=true; member.idle_clock=2; member.needs.hunger=10
	_advance(3); assert(table.meal.servings==0)
	var first_time: float=first.task.remaining; var second_time: float=second.task.remaining
	call=_intent(); assert(call.orders.all(func(order): return order.action=="choose")); assert(world.apply_command("a",call).ok)
	assert(not first.task.get("automatic",false) and not second.task.get("automatic",false) and first.task.remaining==first_time and second.task.remaining==second_time and table.meal.servings==0)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true)); _reject(call)
	# Already chosen diners stay untouched; only the unplanned housemate joins.
	_fresh(); assert(world.apply_command("a",{"type":"meal","member_id":first.id,"lot_id":lot.id,"target_id":table.id,"action":"eat","recipe":"","batch":1}).ok)
	task=first.task.duplicate(true); option=_option(); assert(option.orders.size()==1 and option.orders[0].member_id==second.id)
	assert(world.apply_command("a",_intent()).ok and first.task==task)
	# Away or full-plan residents are shown but not called, even when selected.
	_fresh(); assert(world.apply_command("a",{"type":"visit","member_id":first.id,"lot_id":"lot_2"}).ok)
	option=_option(); assert(option.orders.size()==1 and option.rows[0].detail.begins_with("Away"))
	var away: Dictionary=first.duplicate(true); assert(world.apply_command("a",_intent()).ok and first==away and second.task.meal_action=="eat")
	_fresh(); first.queue.clear()
	for index in range(World.MAX_QUEUE): world._queue_action(first,{"type":"move","x":0,"y":14})
	queue=first.queue.duplicate(true); option=_option(); assert(option.orders.size()==1 and option.orders[0].member_id==second.id)
	assert(world.apply_command("a",_intent()).ok and first.queue==queue and first.task.is_empty())
	# Visits can call one's own household at the host's table, never the host.
	_fresh(); var original_household: Dictionary=world.state.families.a.duplicate(true)
	for member: Dictionary in world.state.families.b.members: assert(world.apply_command("b",{"type":"visit","member_id":member.id,"lot_id":lot.id}).ok)
	var preferred: String=world.state.families.b.members[0].id
	option=world.meal_call_option("b",preferred,lot.id,table.id)
	assert(world.apply_command("b",{"type":"meal_call","member_id":preferred,"lot_id":lot.id,"target_id":table.id,"batch":1,"orders":option.orders}).ok)
	assert(world.state.families.a==original_household and Meals.available(world.state,lot,table)==2)
	_fresh(); call=_intent(); assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok); _reject(call)
	assert(not _option().ok)
	_fresh(0); assert(not _option().ok); _reject(_intent())
	print("MEAL_CALL_PASS"); quit()
