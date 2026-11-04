extends SceneTree
const World=preload("res://game/world.gd")
const Meals=preload("res://game/meals.gd")
const Bonds=preload("res://game/friendships.gd")
var world: RefCounted
var lot: Dictionary
var table: Dictionary
var first: Dictionary
var second: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=owner=="a"; resident.idle_clock=2
			for need: String in resident.needs: resident.needs[need]=100.0
	lot=world.state.lots.lot_1; first=world.state.families.a.members[0]; second=world.state.families.a.members[1]
	first.x=7; first.y=6; second.x=8; second.y=5
	first.needs.hunger=20; second.needs.hunger=20
	table=world._new_object("dining_table",8,6,0); lot.objects.append(table)
	table.meal={"recipe":"salad","servings":2,"batch":1,"cook":first.id,"cook_name":first.name,"day":1}
func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): world.step(0.1)
func _intent(resident: Dictionary) -> Dictionary:
	return {"type":"meal","member_id":resident.id,"lot_id":lot.id,"target_id":table.id,"action":"choose","recipe":"","batch":1,"activity_id":resident.task.id}
func _reject(intent: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Rejected choices are atomic")
func _score() -> int: return int(Bonds.bond(world.state,first.id,second.id).score)
func _run() -> void:
	_fresh(); _advance(3)
	assert(table.meal.servings==0 and first.task.automatic and second.task.automatic and _score()==20)
	var before: Dictionary=first.task.duplicate(true); var next: int=first.next_action; var meal: Dictionary=table.meal.duplicate(true)
	var original:=_intent(first); var second_before: Dictionary=second.duplicate(true)
	for change: Dictionary in [{"activity_id":"old"},{"activity_id":[]},{"batch":0},{"recipe":"salad"},{"member_id":second.id},{"action":"invalid"}]:
		var bad:=original.duplicate(true); bad.merge(change,true); _reject(bad)
	_reject(original,"b")
	assert(world.meal_option("a",first.id,lot.id,table.id,"choose").ok)
	assert(world.apply_command("a",original).ok)
	assert(first.next_action==next+1 and first.task.id!=before.id and not first.task.get("automatic",false))
	for key: String in ["path","elapsed","remaining","meal_taken","meal_batch","meal_recipe"]: assert(first.task[key]==before[key],"Choosing preserves the current meal")
	assert(first.task.meal_chosen_at==before.elapsed and Meals.chosen_time(first.task)==0 and table.meal==meal and second==second_before)
	_reject(original); _reject(_intent(first))
	var chosen_snapshot: Dictionary=world.snapshot(); var replica:=World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(chosen_snapshot)),true))
	var saved:=World.new(); assert(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(saved.state.lots.lot_1.objects[-1].meal.servings==0 and saved.state.families.a.members[0].task.is_empty())
	for value: Variant in [-1,11,"3",null,{},true,INF,NAN]:
		var corrupt:=chosen_snapshot.duplicate(true); corrupt.families.a.members[0].task.meal_chosen_at=value
		var previous: Dictionary=replica.snapshot(); assert(not replica.restore(corrupt,true) and replica.snapshot()==previous)
	var corrupt:=chosen_snapshot.duplicate(true); corrupt.families.a.members[0].task.automatic=true; assert(not replica.restore(corrupt,true))
	corrupt=chosen_snapshot.duplicate(true); corrupt.families.a.members[0].queue=[{"type":"move","x":0,"y":0,"meal_chosen_at":0}]; assert(not replica.restore(corrupt,true))
	_advance(1); assert(_score()==20,"Choosing one diner cannot convert the other resident's automatic time")
	var option: Dictionary=world.leisure_option(second,first.id,"dining_table")
	assert(option.available and option.own_activity_id==second.task.id)
	var join: Dictionary={"type":"join_meal","member_id":second.id,"lot_id":lot.id,"companion_id":first.id,"activity_id":first.task.id,"own_activity_id":second.task.id}
	var stale:=join.duplicate(true); stale.own_activity_id="old"; _reject(stale)
	stale=join.duplicate(true); stale.erase("own_activity_id"); _reject(stale)
	stale=join.duplicate(true); stale.own_activity_id=[]; _reject(stale)
	assert(world.apply_command("a",join).ok and not second.task.get("automatic",false) and table.meal==meal)
	_reject(join)
	var social_snapshot: Dictionary=world.snapshot(); assert(replica.restore(JSON.parse_string(JSON.stringify(social_snapshot)),true))
	_advance(3.9); assert(_score()==20,"Automatic dining before the choice is not friendship time")
	world.step(0.1); assert(_score()==32,"Twelve game minutes of newly chosen shared time earns one catch-up")
	for tick in range(40): replica.step(0.1)
	assert(Bonds.bond(replica.state,first.id,second.id).score==32 and replica.state.lots.lot_1.objects[-1].meal.servings==0)
	_advance(8); assert(_score()==32 and table.meal.servings==0 and first.activity_log[0].outcome=="done" and second.activity_log[0].outcome=="done")
	assert(first.hobbies.cooking.sessions==0 and second.hobbies.cooking.sessions==0)
	# A late choice never extends the meal just to obtain a catch-up.
	_fresh(); _advance(7); var remaining: float=first.task.remaining
	assert(world.apply_command("a",_intent(first)).ok); assert(world.apply_command("a",_intent(second)).ok)
	assert(first.task.remaining==remaining); _advance(4)
	assert(_score()==20 and table.meal.servings==0 and first.task.is_empty() and second.task.is_empty())
	# Choosing while walking preserves the reservation, route, and progress.
	_fresh(); first.x=8; first.y=14; second.autonomy=false; second.needs.hunger=100
	world.step(0.1); assert(not first.task.path.is_empty() and table.meal.servings==2)
	before=first.task.duplicate(true); var walk: float=first.walk_clock; original=_intent(first)
	for index in range(World.MAX_QUEUE): world._queue_action(first,{"type":"move","x":0,"y":14})
	var queue: Array=first.queue.duplicate(true)
	assert(world.apply_command("a",original).ok and first.queue==queue and first.task.path==before.path and first.walk_clock==walk)
	assert(table.meal.servings==2 and Meals.available(world.state,lot,table)==1)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(world.apply_command("a",{"type":"cancel","member_id":first.id}).ok)
	assert(Meals.available(world.state,lot,table)==2); _reject(original)
	# A stale choice cannot target a later automatic meal from the same platter.
	world.step(0.1); world.step(1); world.step(1)
	assert(first.task.get("automatic",false) and first.task.id!=original.activity_id); _reject(original)
	print("MEAL_CHOICE_PASS"); quit()
