extends SceneTree
const World=preload("res://game/world.gd")
const Meals=preload("res://game/meals.gd")
var world: RefCounted
var lot: Dictionary
var table: Dictionary
var member: Dictionary
var second: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh(portions: int=4) -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b","c"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=100.0
	lot=world.state.lots.lot_1; member=world.state.families.a.members[0]; second=world.state.families.a.members[1]
	member.x=7; member.y=7; second.x=8; second.y=14
	table=world._new_object("dining_table",8,6,0); lot.objects.append(table)
	table.meal={"recipe":"salad","servings":portions,"batch":1,"cook":member.id,"cook_name":member.name,"day":1}
	member.autonomy=true; member.idle_clock=2.0; member.needs.hunger=20.0
func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): world.step(0.1)
func _eat(owner: String,resident: Dictionary) -> void:
	assert(world.apply_command(owner,{"type":"meal","member_id":resident.id,"lot_id":lot.id,"target_id":table.id,"action":"eat","recipe":"","batch":1}).ok)
func _activity(resident: Dictionary) -> String: return world.task_activity(resident.task,str(resident.lot_id))
func _copy() -> RefCounted:
	var result:=World.new(); assert(result.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true)); return result
func _run() -> void:
	_fresh(); member.x=10; member.y=5 # The fridge is closer, but prepared food is ready.
	var funds: int=lot.funds; var wishes: Dictionary=member.wishes.duplicate(true); var hobbies: Dictionary=member.hobbies.duplicate(true)
	world.step(0.1)
	assert(_activity(member)=="dining_table" and member.task.automatic and member.task.meal_action=="eat")
	assert(table.meal.servings==4 and Meals.available(world.state,lot,table)==3,"Walking reserves one portion without taking it")
	var restored:=_copy(); _advance(16)
	assert(table.meal.servings==3 and member.needs.hunger>85 and member.task.is_empty())
	assert(lot.funds==funds and member.hobbies==hobbies and member.wishes==wishes,"Automatic food restores needs without spending or earning rewards")
	for tick in range(160): restored.step(0.1)
	assert(restored.state.lots.lot_1.objects[-1].meal.servings==3,"A walking reservation survives the network snapshot")
	# Two spontaneous diners get company, but no friendship progress or practice.
	_fresh(); second.autonomy=true; second.idle_clock=2; second.needs.hunger=20; second.needs.social=40; member.needs.social=40
	var friendships: Dictionary=world.state.friendships.duplicate(true)
	_advance(4); assert(member.action=="Eating together" and second.action=="Eating together" and table.meal.servings==2)
	assert(not world.leisure_option(member,str(second.id),"dining_table").available,"People does not offer another portion to an automatic diner already here")
	var eating:=_copy(); var saved:=World.new(); assert(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(saved.state.lots.lot_1.objects[-1].meal.servings==2 and saved.state.families.a.members[0].task.is_empty())
	_advance(12); assert(world.state.friendships==friendships and member.needs.social>60 and second.needs.social>60)
	for tick in range(120): eating.step(0.1)
	assert(eating.state.lots.lot_1.objects[-1].meal.servings==2,"An already taken serving is not consumed again after a snapshot")
	# Invalid autonomous preparation, guests, and absent caretakers reject atomically.
	_fresh(); world.step(0.1); var snapshot: Dictionary=world.snapshot()
	for mode: String in ["away","disabled","foreign"]:
		var bad: Dictionary=snapshot.duplicate(true)
		if mode=="away": bad.families.a.online=false
		elif mode=="disabled": bad.families.a.members[0].autonomy=false
		else:
			var guest: Dictionary=bad.families.b.members[0]; guest.lot_id=lot.id; guest.autonomy=true; guest.next_action=2
			guest.task=bad.families.a.members[0].task; guest.task.id=guest.id+":1"; bad.families.a.members[0].task={}
		var before: Dictionary=restored.snapshot(); assert(not restored.restore(bad,true) and restored.snapshot()==before)
	_fresh(0); member.autonomy=false
	assert(world.apply_command("a",{"type":"meal","member_id":member.id,"lot_id":lot.id,"target_id":table.id,"action":"prepare","recipe":"salad","batch":1}).ok)
	var preparation: Dictionary=world.snapshot(); assert(restored.restore(preparation,true))
	preparation.families.a.members[0].autonomy=true; preparation.families.a.members[0].task.automatic=true
	assert(not restored.restore(preparation,true),"A valid deliberate preparation cannot be relabeled as autonomous")
	# Orders, autonomy off, construction, and disconnection release walking reservations.
	for interruption: String in ["move","off","build","away"]:
		_fresh(); member.x=8; member.y=14; second.x=0; second.y=0; world.step(0.1)
		assert(not member.task.path.is_empty() and Meals.available(world.state,lot,table)==3)
		if interruption=="move": assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":lot.id,"x":7,"y":14}).ok)
		elif interruption=="off": assert(world.apply_command("a",{"type":"autonomy","member_id":member.id,"enabled":false}).ok)
		elif interruption=="build": assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
		else: world.set_online("a",false)
		assert(table.meal.servings==4 and Meals.available(world.state,lot,table)==4 and not member.task.has("meal_action"))
	_fresh(); _advance(3); assert(table.meal.servings==3)
	assert(world.apply_command("a",{"type":"autonomy","member_id":member.id,"enabled":false}).ok)
	_advance(15); assert(table.meal.servings==3,"Stopping after the first bite does not return food")
	# Existing deliberate reservations win the last serving, even before arrival.
	_fresh(1); second.needs.hunger=20; _eat("a",second); world.step(0.1)
	assert(_activity(member)=="fridge" and table.meal.servings==1 and Meals.available(world.state,lot,table)==0)
	# Inaccessible/full tables fall back to a snack without locking a portion.
	_fresh()
	for cell in [[7,6],[7,7],[8,5],[9,5],[10,7],[8,8],[9,8]]: lot.walls.append(cell)
	member.x=11; member.y=5; world.step(0.1); assert(_activity(member)=="fridge" and Meals.available(world.state,lot,table)==4)
	_fresh()
	for cell in [[7,6],[7,7],[9,5],[10,7],[8,8],[9,8]]: lot.walls.append(cell)
	second.x=8; second.y=5; member.x=11; member.y=5; world.step(0.1)
	assert(_activity(member)=="fridge" and Meals.available(world.state,lot,table)==4,"A table with no free place cannot trap an autonomous resident")
	_fresh(); member.needs.bladder=5; world.step(0.1); assert(_activity(member)=="toilet" and Meals.available(world.state,lot,table)==4)
	_fresh(); member.needs.hunger=100; world.step(0.1); assert(member.task.is_empty() and table.meal.servings==4)
	_fresh(); member.autonomy=false; _advance(4); assert(member.task.is_empty() and table.meal.servings==4)
	_fresh(0); funds=int(lot.funds); world.step(0.1); assert(_activity(member)=="fridge" and table.meal.servings==0 and lot.funds==funds,"No automatic preparation or ingredient spending")
	# Guests can explicitly share, but never help themselves. Away care uses snacks.
	_fresh(); member.autonomy=false
	var guest: Dictionary=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":lot.id}).ok)
	guest.autonomy=true; guest.needs.hunger=20; guest.idle_clock=2; world.step(0.1)
	assert(_activity(guest)=="fridge" and table.meal.servings==4)
	_eat("b",guest); assert(not guest.task.get("automatic",false) and guest.task.meal_action=="eat")
	_fresh(); world.set_online("a",false); member.needs.hunger=55; _advance(35)
	assert(table.meal.servings==4 and member.needs.hunger>80,"Absent caretakers eat without consuming stored household food")
	print("MEALS_AUTONOMY_PASS"); quit()
