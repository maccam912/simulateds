extends SceneTree
const World = preload("res://game/world.gd")
const Pastimes = preload("res://game/pastimes.gd")
var world: RefCounted
var member: Dictionary
var lot: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	member=world.state.families.a.members[0]; lot=world.state.lots.lot_1
	for resident: Dictionary in world.state.families.a.members: resident.autonomy=false
	for need: String in member.needs: member.needs[need]=100.0

func _chosen() -> String:
	world._choose_autonomy(member,lot)
	return world.task_activity(member.task,str(lot.id))

func _run() -> void:
	_fresh()
	assert(Pastimes.valid(member.favorite) and member.favorite!=world.state.families.a.members[1].favorite,"New housemates start with distinct interests")
	var saved: Dictionary=world.snapshot()
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(saved)),true))
	assert(replica.state.families.a.members[0].favorite==member.favorite,"Preferences survive snapshots and saves")
	for bad: Variant in ["unknown","",null,7,[],{}]:
		var malformed: Dictionary=saved.duplicate(true); malformed.families.a.members[1].favorite=bad
		var before: Dictionary=replica.snapshot()
		assert(not replica.restore(malformed) and replica.snapshot()==before,"Malformed preferences cannot partly replace a world")
	for resident: Dictionary in saved.families.a.members: resident.erase("favorite")
	assert(replica.restore(saved))
	assert(replica.state.families.a.members[0].favorite=="variety","Older saves keep neutral choices")
	for favorite: String in Pastimes.ACTIVITIES:
		_fresh(); member.favorite=favorite
		if favorite=="games": lot.objects.append(world._new_object("game_table",8,5,0))
		for need: String in member.needs: member.needs[need]=60.0
		assert(_chosen()==Pastimes.ACTIVITIES[favorite],"Each preference changes a real near-tie choice")
	_fresh(); member.favorite="games"; member.needs.fun=60.0
	assert(_chosen()=="tv","A missing game table falls back to available recreation")
	_fresh(); member.favorite="variety"; member.needs.fun=60.0
	assert(_chosen()=="tv","Neutral preference retains the ordinary need/distance choice")
	_fresh(); member.favorite="reading"; member.needs.hunger=29.0; member.needs.fun=30.0
	assert(_chosen()=="fridge","Urgent care disables leisure preference, including when both needs are urgent")
	_fresh(); member.favorite="reading"; member.needs.hunger=30.0; member.needs.fun=31.0
	assert(_chosen()=="fridge","A slightly higher leisure need cannot displace urgent care")
	_fresh(); member.favorite="reading"; member.needs.energy=31.0; member.needs.fun=42.0
	assert(_chosen()=="bed","The preference is bounded; a substantially lower need still wins")
	_fresh(); member.favorite="reading"
	assert(_chosen().is_empty() and member.task.is_empty(),"A favorite does not generate pointless busywork when needs are full")
	_fresh(); member.favorite="reading"; member.needs.fun=60.0
	for tile in [[9,10],[11,10],[10,9]]: lot.walls.append(tile)
	assert(_chosen()=="tv","An unreachable favorite falls back to useful available recreation")
	_fresh(); member.favorite="reading"; member.needs.hunger=0.0; member.needs.fun=60.0
	for object: Dictionary in lot.objects.duplicate():
		if object.kind=="fridge": lot.objects.erase(object)
	assert(_chosen()=="bookshelf","An unavailable urgent affordance cannot prevent all other care")
	_fresh(); member.favorite="reading"; member.needs.fun=60.0; member.idle_clock=2.0
	world.step(0.1); assert(member.task.is_empty(),"Autonomy off still means no autonomous choices")
	member.autonomy=true
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":lot.id,"x":0,"y":0}).ok)
	world.step(0.1); assert(member.task.type=="move","Manual orders retain priority")
	world._clear_member(member); member.idle_clock=2.0
	world.step(0.1); assert(world.task_activity(member.task,str(lot.id))=="bookshelf","The normal idle simulation uses the preference")
	var wishes: Dictionary=member.wishes.duplicate(true)
	var hobbies: Dictionary=member.hobbies.duplicate(true)
	var funds: int=lot.funds
	for tick in range(200): world.step(0.1)
	assert(member.needs.fun>80.0 and member.hobbies==hobbies and member.wishes==wishes and lot.funds==funds,"Autonomous favorites restore needs without earning practice, wishes, or funds")
	world.set_online("a",false); member.needs.fun=60.0; member.idle_clock=2.0
	for tick in range(200): world.step(0.1)
	assert(member.needs.fun>80.0 and member.hobbies==hobbies and member.wishes==wishes and lot.funds==funds,"Caretaker preferences do not farm progress while the player is away")
	print("PASTIMES_PASS")
	quit()
