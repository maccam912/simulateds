extends SceneTree
const World=preload("res://game/world.gd")
const Meals=preload("res://game/meals.gd")
const Leisure=preload("res://game/shared_leisure.gd")
var world: RefCounted
var lot: Dictionary
var table: Dictionary
var member: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b","c"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members: resident.autonomy=false
	lot=world.state.lots.lot_1; member=world.state.families.a.members[0]
	assert(world.apply_command("a",{"type":"move","member_id":world.state.families.a.members[1].id,"lot_id":lot.id,"x":8,"y":14}).ok); _finish(world.state.families.a.members[1])
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"dining_table","x":8,"y":6}).ok)
	table=lot.objects[-1]
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
func _intent(resident: Dictionary,action: String,recipe: String="") -> Dictionary: return {"type":"meal","member_id":resident.id,"lot_id":lot.id,"target_id":table.id,"action":action,"recipe":recipe,"batch":table.meal.batch}
func _command(owner: String,resident: Dictionary,action: String,recipe: String="") -> void:
	var result: Dictionary=world.apply_command(owner,_intent(resident,action,recipe)); assert(result.ok,str(result.message))
func _finish(resident: Dictionary) -> void:
	for tick in range(500):
		world.step(0.1)
		if resident.task.is_empty() and resident.queue.is_empty(): return
	assert(false,"The meal plan must finish")
func _reject(owner: String,intent: Dictionary) -> void:
	var before: Dictionary=world.snapshot(); assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Invalid meal orders are atomic")
func _visit(owner: String,resident: Dictionary) -> void: assert(world.apply_command(owner,{"type":"visit","member_id":resident.id,"lot_id":lot.id}).ok)
func _run() -> void:
	_fresh(); assert(table.meal==Meals.create())
	for change: Dictionary in [{"recipe":"bad"},{"recipe":[]},{"target_id":[]},{"action":[]},{"batch":-1},{"batch":0.5},{"member_id":"other"}]:
		var bad:=_intent(member,"prepare","salad"); bad.merge(change,true); _reject("a",bad)
	_reject("a",_intent(member,"eat")); _reject("a",{"type":"interact","member_id":member.id,"lot_id":lot.id,"target_id":table.id})
	var visitor: Dictionary=world.state.families.b.members[0]; _visit("b",visitor); _reject("b",_intent(visitor,"prepare","salad"))
	var funds: int=lot.funds; var cooking: int=member.hobbies.cooking.sessions
	_command("a",member,"prepare","salad"); _reject("a",_intent(member,"prepare","salad"))
	var initial: Dictionary=world.snapshot(); var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(initial)),true))
	for tick in range(35): world.step(0.1)
	assert(lot.funds==funds and table.meal.servings==0)
	assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok); assert(lot.funds==funds and table.meal.servings==0 and member.hobbies.cooking.sessions==cooking)
	_command("a",member,"prepare","sandwiches")
	for tick in range(200):
		world.step(0.1)
		if member.task.get("meal_phase")=="serve": break
	assert(member.task.get("meal_phase")=="serve" and table.meal.servings==0 and lot.funds==funds,"Food is carried to the table before charging")
	var carried: Dictionary=world.snapshot(); assert(replica.restore(JSON.parse_string(JSON.stringify(carried)),true))
	for tick in range(100): replica.step(0.1)
	assert(replica.state.lots.lot_1.objects[-1].meal.servings==4 and replica.state.lots.lot_1.funds==funds-20)
	_finish(member); assert(table.meal.servings==4 and table.meal.recipe=="sandwiches" and table.meal.cook==member.id and lot.funds==funds-20 and member.hobbies.cooking.sessions==cooking+1)
	var served: Dictionary=world.snapshot(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.lots.lot_1.objects[-1].meal==table.meal)
	for bad: Variant in [null,{},[],{"recipe":"salad"}]:
		var corrupt: Dictionary=served.duplicate(true); corrupt.lots.lot_1.objects[-1].meal=bad; var before:=replica.snapshot(); assert(not replica.restore(corrupt) and replica.snapshot()==before)
	for field: Dictionary in [{"servings":5},{"servings":1.2},{"recipe":"bad"},{"batch":-1},{"day":100},{"cook_name":"\n"}]:
		var corrupt: Dictionary=served.duplicate(true); corrupt.lots.lot_1.objects[-1].meal.merge(field,true); assert(not replica.restore(corrupt))
	_reject("a",_intent(member,"prepare","salad")); _reject("b",_intent(visitor,"clear"))
	# Four plans reserve the four portions before any resident takes one.
	var eaters: Array=[]
	for owner: String in ["a","b"]:
		for resident: Dictionary in world.state.families[owner].members:
			if resident.lot_id!=lot.id: _visit(owner,resident)
			resident.needs.hunger=20; resident.needs.comfort=20; resident.needs.social=20
			_command(owner,resident,"eat"); eaters.append(resident)
	assert(Meals.available(world.state,lot,table)==0 and table.meal.servings==4)
	var fifth: Dictionary=world.state.families.c.members[0]; _visit("c",fifth); _reject("c",_intent(fifth,"eat")); _reject("a",_intent(member,"clear"))
	assert(world.apply_command("b",{"type":"cancel","member_id":visitor.id}).ok); assert(Meals.available(world.state,lot,table)==1 and table.meal.servings==4)
	_command("b",visitor,"eat")
	var snapshot: Dictionary=world.snapshot(); assert(replica.restore(JSON.parse_string(JSON.stringify(snapshot)),true))
	for tick in range(40): world.step(0.1)
	assert(table.meal.servings==0 and Leisure.players(world.state,lot.id,table.id).size()==4)
	var places := {}; var boards := {}
	for resident: Dictionary in eaters:
		assert(not places.has(Leisure.place(resident))); places[Leisure.place(resident)]=true
		assert(world.care_status(resident,"hunger")=="In progress" and world.care_status(resident,"comfort")=="In progress")
		boards[resident.id]=resident.hobbies.duplicate(true)
	_finish(member)
	for resident: Dictionary in eaters:
		_finish(resident); assert(resident.needs.hunger>94 and resident.needs.social>45 and resident.activity_log[0].outcome=="done" and resident.hobbies==boards[resident.id])
	assert(table.meal.servings==0 and lot.funds==funds-20)
	var bond: Dictionary=preload("res://game/friendships.gd").bond(world.state,member.id,visitor.id)
	assert(bond.score==12 and bond.last_activity=="dining_table" and preload("res://game/friendships.gd").recent(bond,world.state.day).contains("Shared a meal"))
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot()))))
	_reject("a",_intent(member,"eat"))
	# Leftovers keep across absence; clearing is explicit, stale batches cannot eat replacements.
	_command("a",member,"prepare","salad"); _finish(member); var old:=_intent(visitor,"eat")
	world.set_online("a",false)
	for tick in range(100): world.step(1.0)
	assert(table.meal.servings==4); world.set_online("a",true)
	_command("a",member,"clear"); assert(table.meal.recipe=="" and table.meal.servings==0)
	_command("a",member,"prepare","sandwiches"); _finish(member); _reject("b",old)
	# Construction stops preparation without charging, and recalls visiting eaters.
	_command("b",visitor,"eat"); world.step(0.1)
	var remaining_before_build: int=table.meal.servings
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(visitor.task.is_empty() and visitor.lot_id=="lot_2" and table.meal.servings==remaining_before_build)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	var original: Dictionary=table.meal.duplicate(true)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"erase","lot_id":lot.id,"x":8,"y":6}).ok)
	assert(world.apply_command("a",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok)
	table=world._object(lot,str(table.id)); assert(table.meal==original)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	# Future budgets and paths are rechecked before anything is served.
	_command("a",member,"clear"); _command("a",member,"prepare","salad"); lot.funds=0; _finish(member)
	assert(table.meal.servings==0 and member.activity_log[0].outcome=="failed")
	# Hunger care can reserve ready food, without claiming cooking practice for eating.
	_fresh(); _command("a",member,"prepare","salad"); _finish(member)
	member.x=8; member.y=5; member.needs.hunger=10
	var care: Dictionary=world.care_option(member,"hunger"); assert(care.get("meal_batch")==table.meal.batch)
	assert(world.apply_command("a",{"type":"care","member_id":member.id,"need":"hunger"}).ok)
	assert(member.task.meal_action=="eat")
	world.step(0.1); var eating: Dictionary=world.snapshot()
	for fields: Dictionary in [{"id":""},{"id":"a_1:999999"},{"id":"b_1:1"},{"elapsed":50},{"remaining":50},{"meal_taken":[]},{"meal_phase":"prepare"},{"meal_recipe":"bad"},{"meal_table":[]}]:
		var corrupt:=eating.duplicate(true); corrupt.families.a.members[0].task.merge(fields,true); assert(not replica.restore(corrupt))
	assert(replica.restore(JSON.parse_string(JSON.stringify(eating)),true))
	for tick in range(120): replica.step(0.1)
	assert(replica.state.lots.lot_1.objects[-1].meal.servings==3)
	var overbooked:=eating.duplicate(true); overbooked.lots.lot_1.objects[-1].meal.servings=4
	assert(not Meals.valid_reservations(overbooked) and not replica.restore(overbooked),"An active consumed portion must be reflected in the serving count")
	_finish(member)
	var home_food: Dictionary=table.meal.duplicate(true); world.set_online("a",false)
	for tick in range(100): world.step(1)
	assert(table.meal==home_food,"Caretakers leave prepared portions for the player")
	# Actual room copying creates a fresh table, never extra portions or cook credit.
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); lot=world.state.lots.lot_1
	lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.windows={}; lot.objects=[]; lot.finishes=preload("res://game/finishes.gd").create()
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"build_room","lot_id":lot.id,"x":0,"y":0,"end_x":4,"end_y":4,"rotation":0,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"dining_table","x":1,"y":1}).ok)
	table=lot.objects[-1]; table.meal=home_food.duplicate(true)
	var copy := {"type":"copy_room","lot_id":lot.id,"source_x":3,"source_y":3,"x":10,"y":0,"rotation":1,"revision":lot.revision}
	var plan: Dictionary=preload("res://game/room_copy.gd").inspect(lot,copy,[]); assert(plan.ok and plan.food)
	assert(world.apply_command("a",copy).ok)
	assert(lot.objects[-1].meal==Meals.create() and lot.objects[0].meal==home_food)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	print("MEALS_PASS"); quit()
