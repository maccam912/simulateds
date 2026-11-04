extends SceneTree
const World=preload("res://game/world.gd")
const Pantry=preload("res://game/pantry.gd")
const Gardens=preload("res://game/gardens.gd")
var world: RefCounted
var family: Dictionary
var home: Dictionary
var member: Dictionary
var other: Dictionary
var bed: Dictionary
var table: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false
			for wish: Dictionary in resident.wishes.wishes: wish.done=true
	family=world.state.families.a; home=world.state.lots.lot_1; member=family.members[0]; other=family.members[1]
	other.x=8; other.y=14
	table=world._new_object("dining_table",8,6,0); home.objects.append(table)
	bed=world._new_object("garden_bed",5,13,0); home.objects.append(bed)
func _garden(action: String,crop: String="",actor: Dictionary={}) -> Dictionary:
	return {"type":"garden","lot_id":home.id,"member_id":actor.get("id",member.id),"target_id":bed.id,"action":action,"crop":crop,"revision":bed.garden.revision}
func _meal(actor: Dictionary={},target: Dictionary={}) -> Dictionary:
	return {"type":"meal","lot_id":home.id,"member_id":actor.get("id",member.id),"target_id":target.get("id",table.id),"action":"prepare","recipe":"homegrown","batch":target.get("meal",table.meal).batch}
func _finish(actor: Dictionary={}) -> void:
	var resident: Dictionary=member if actor.is_empty() else actor
	for tick in range(500):
		world.step(0.1)
		if resident.task.is_empty() and resident.queue.is_empty(): return
	assert(false,"The planned harvest/meal must finish")
func _crop(crop: String) -> void:
	assert(world.apply_command("a",_garden("plant",crop)).ok); _finish()
	for tick in range(250):
		if Gardens.ripe(bed.garden): return
		if float(bed.garden.water)<0.1: assert(world.apply_command("a",_garden("water")).ok); _finish()
		world.step(1.0)
	assert(false)
func _reject(intent: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); assert(not world.apply_command(owner,intent).ok and world.snapshot()==before)
func _cancel(actor: Dictionary={}) -> void: assert(world.apply_command("a",{"type":"cancel","member_id":actor.get("id",member.id)}).ok)
func _run() -> void:
	_fresh(); assert(family.pantry==Pantry.create())
	_reject(_meal()); _reject(_garden("keep")); _crop("radish")
	var funds: int=home.funds; var before: Dictionary=world.snapshot()
	var option: Dictionary=world.garden_option("a",member.id,home.id,bed.id,"keep")
	assert(option.ok and option.cost==0 and world.snapshot()==before)
	var keep:=_garden("keep"); assert(world.apply_command("a",keep).ok)
	assert(family.pantry.radish==0 and Pantry.stock(world.state,"a").radish.incoming==4)
	_reject(keep); world.step(0.5); _cancel()
	assert(family.pantry.radish==0 and Pantry.stock(world.state,"a").radish.incoming==0 and Gardens.ripe(bed.garden))
	assert(world.apply_command("a",keep).ok); _finish(); _reject(keep)
	assert(family.pantry.radish==4 and home.funds==funds and bed.garden.crop=="" and member.activity_log[0].reason.contains("Kept 4 radishes"))
	_crop("tomato"); funds=home.funds; assert(world.apply_command("a",_garden("keep")).ok); _finish()
	assert(family.pantry=={"radish":4,"tomato":4} and home.funds==funds)
	world.state.day_minutes=480.0 # Keep the daily allowance outside the ingredient-payment assertions.
	# Ingredients remain stored but reserved through preparing/carrying; cancellation frees them.
	var meal:=_meal(); assert(world.apply_command("a",meal).ok)
	assert(Pantry.stock(world.state,"a").radish=={"stored":4,"reserved":2,"incoming":0,"available":2,"space":8})
	for tick in range(200):
		world.step(0.1)
		if member.task.get("meal_phase")=="serve": break
	assert(member.task.get("meal_phase")=="serve" and family.pantry.radish==4 and home.funds==funds,str([member.task,family.pantry,home.funds,funds]))
	var carrying: Dictionary=world.snapshot(); var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(carrying)),true))
	_cancel(); assert(family.pantry.radish==4 and Pantry.stock(world.state,"a").radish.reserved==0 and table.meal.servings==0)
	assert(world.apply_command("a",meal).ok); _finish()
	assert(family.pantry=={"radish":2,"tomato":2} and table.meal.recipe=="homegrown" and table.meal.servings==4 and home.funds==funds)
	for tick in range(200): replica.step(0.1)
	assert(replica.state.families.a.pantry==family.pantry and replica.state.lots.lot_1.objects[-2].meal.servings==4,"A runtime snapshot consumes the reserved produce exactly once when served")
	# Normal loading clears plans, freeing reservations without charging ingredients.
	assert(replica.restore(JSON.parse_string(JSON.stringify(carrying))))
	assert(replica.state.families.a.pantry.radish==4 and Pantry.stock(replica.state,"a").radish.reserved==0)
	# Multiple tables cannot reserve the same stock; cancelling one plan makes it available.
	assert(world.apply_command("a",{"type":"meal","member_id":member.id,"target_id":table.id,"action":"clear","batch":table.meal.batch}).ok)
	var second_table: Dictionary=world._new_object("dining_table",4,6,0); home.objects.append(second_table)
	assert(world.apply_command("a",_meal()).ok); _reject(_meal(other,second_table))
	_cancel()
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":home.id,"x":7,"y":7}).ok); _finish()
	var second_result: Dictionary=world.apply_command("a",_meal(other,second_table)); assert(second_result.ok,str(second_result))
	assert(Pantry.stock(world.state,"a").tomato.available==0)
	var reserved: Dictionary=world.snapshot(); assert(replica.restore(JSON.parse_string(JSON.stringify(reserved)),true))
	var corrupt:=reserved.duplicate(true); corrupt.families.a.pantry.tomato=1; assert(not replica.restore(corrupt))
	_cancel(other)
	# Construction cancels reservations; Undo/Discard cannot refund produce already cooked.
	var stock: Dictionary=family.pantry.duplicate(true)
	assert(world.apply_command("a",_meal()).ok)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":home.id}).ok)
	assert(Pantry.stock(world.state,"a").radish.reserved==0 and family.pantry==stock)
	assert(world.apply_command("a",{"type":"erase","lot_id":home.id,"x":8,"y":6}).ok)
	assert(world.apply_command("a",{"type":"build_undo","lot_id":home.id,"revision":home.revision}).ok)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":home.id}).ok)
	table=world._object(home,str(table.id)); bed=world._object(home,str(bed.id))
	assert(family.pantry==stock)
	# Kept harvests reserve space too, and a full pantry leaves the ripe crop intact.
	family.pantry.radish=8; _crop("radish")
	var second_bed: Dictionary=world._new_object("garden_bed",10,13,0); second_bed.garden=bed.garden.duplicate(true); home.objects.append(second_bed)
	assert(world.apply_command("a",_garden("keep")).ok)
	var incoming: Dictionary=world.snapshot(); assert(replica.restore(JSON.parse_string(JSON.stringify(incoming)),true))
	for bad_id: Variant in [null,"","a_1:999999",other.id+":1"]:
		corrupt=incoming.duplicate(true)
		if bad_id==null: corrupt.families.a.members[0].task.erase("id")
		else: corrupt.families.a.members[0].task.id=bad_id
		assert(not replica.restore(corrupt),"A kept harvest needs its own stable reservation identity")
	corrupt=incoming.duplicate(true); corrupt.families.a.pantry.radish=9; assert(not replica.restore(corrupt),"Incoming kept harvests must fit before loading")
	var too_many:=_garden("keep","",other); too_many.target_id=second_bed.id
	_reject(too_many); _finish(); assert(family.pantry.radish==12)
	_reject(too_many); assert(Gardens.ripe(second_bed.garden))
	assert(world.apply_command("b",{"type":"visit","member_id":world.state.families.b.members[0].id,"lot_id":home.id}).ok)
	var stolen:=too_many.duplicate(true); stolen.member_id=world.state.families.b.members[0].id
	_reject(stolen,"b"); assert(world.state.families.b.pantry==Pantry.create())
	var sold:=too_many.duplicate(true); sold.action="harvest"; funds=home.funds
	assert(world.apply_command("a",sold).ok); _finish(other); assert(home.funds==funds+45 and family.pantry.radish==12)
	# Visitor restrictions and legacy migration preserve ownership and add no produce.
	var guest: Dictionary=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":home.id}).ok)
	_reject(_garden("keep","",guest),"b"); _reject(_meal(guest),"b")
	var saved: Dictionary=world.snapshot_for_save(); assert(replica.restore(JSON.parse_string(JSON.stringify(saved))))
	saved.families.a.erase("pantry"); saved.families.b.erase("pantry")
	assert(replica.restore(saved) and replica.state.families.a.pantry==Pantry.create())
	# Cooking with produce works even at the currency cap; a kept harvest pays nothing.
	_fresh(); home.funds=1000000000
	bed.garden={"crop":"radish","growth":90.0,"water":0.0,"revision":1,"harvests":0}
	_reject(_garden("harvest")); assert(world.apply_command("a",_garden("keep")).ok); _finish()
	assert(family.pantry.radish==4 and home.funds==1000000000)
	family.pantry.tomato=2
	assert(world.apply_command("a",_meal()).ok); _finish()
	assert(home.funds==1000000000 and family.pantry=={"radish":2,"tomato":0} and table.meal.servings==4)
	for invalid: Variant in [null,{},[],{"radish":-1,"tomato":0},{"radish":13,"tomato":0},{"radish":0.5,"tomato":0},{"radish":NAN,"tomato":0},{"radish":0,"tomato":0,"extra":1}]:
		corrupt=saved.duplicate(true); corrupt.families.a.pantry=invalid; assert(not replica.restore(corrupt))
	print("PANTRY_PASS"); quit()
