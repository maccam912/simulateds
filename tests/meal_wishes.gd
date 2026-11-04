extends SceneTree
const World=preload("res://game/world.gd")
const Wishes=preload("res://game/wishes.gd")
const Bonds=preload("res://game/friendships.gd")
var world: RefCounted
var lot: Dictionary
var table: Dictionary
var cook: Dictionary
var diner: Dictionary
func _initialize() -> void: call_deferred("_run")
func _board() -> Dictionary:
	return {"day":1,"round":1,"wishes":[{"id":"homemade","done":false},{"id":"meal_together","done":false},{"id":"story","done":false}],"journal":[]}
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false; resident.wishes=_board()
			for need: String in resident.needs: resident.needs[need]=100.0
	lot=world.state.lots.lot_1; cook=world.state.families.a.members[0]; diner=world.state.families.a.members[1]
	cook.x=7; cook.y=6; diner.x=8; diner.y=5
	table=world._new_object("dining_table",8,6,0); lot.objects.append(table)
func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): world.step(0.1)
func _command(owner: String,resident: Dictionary,action: String,recipe: String="") -> void:
	var intent := {"type":"meal","member_id":resident.id,"lot_id":lot.id,"target_id":table.id,"action":action,"recipe":recipe,"batch":table.meal.batch}
	if action=="choose": intent.activity_id=resident.task.id
	var result: Dictionary=world.apply_command(owner,intent); assert(result.ok,str(result.message))
func _done(resident: Dictionary,id: String) -> bool:
	for wish: Dictionary in resident.wishes.wishes:
		if wish.id==id: return bool(wish.done)
	return false
func _serve() -> void: _command("a",cook,"prepare","salad"); _advance(18); assert(table.meal.servings==4)
func _run() -> void:
	# First sets remain affordable starter activities; later sets include both additions.
	var seen := {}
	for index in range(30):
		for wish: Dictionary in Wishes.create("resident"+str(index),1).wishes: assert(not wish.id in Wishes.MEALS)
		for wish: Dictionary in Wishes.create("resident"+str(index),2,1).wishes: seen[wish.id]=true
	assert(seen.has("homemade") and seen.has("meal_together"))
	_fresh(); var funds: int=lot.funds; var before: Dictionary=world.snapshot()
	var option: Dictionary=world.meal_wish_option("a",cook.id,"homemade")
	assert(option.available and option.action=="inspect" and option.target_id==table.id and world.snapshot()==before)
	assert(not world.apply_command("a",{"type":"pursue_wish","member_id":cook.id,"wish_id":"homemade"}).ok and world.snapshot()==before,"Opening choices cannot spend ingredients")
	assert(not world.meal_wish_option("b",cook.id,"homemade").available)
	_command("a",cook,"prepare","salad"); _advance(3)
	assert(not _done(cook,"homemade") and lot.funds==funds and world.wish_status(cook,"meal_prepare")=="In progress")
	assert(world.apply_command("a",{"type":"cancel","member_id":cook.id}).ok)
	assert(not _done(cook,"homemade") and lot.funds==funds)
	_serve(); assert(_done(cook,"homemade") and lot.funds==funds-12+40 and not _done(diner,"homemade"))
	assert(cook.wishes.journal.size()==1 and cook.wishes.journal[0].text.contains("Something homemade"))
	assert(not world.meal_wish_option("a",cook.id,"homemade").available)
	var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	for tick in range(30): replica.step(0.1)
	assert(replica.state.lots.lot_1.funds==lot.funds)
	# Solo meals and one automatic participant earn no shared wish.
	_command("a",cook,"eat"); _advance(12); assert(not _done(cook,"meal_together"))
	cook.autonomy=true; cook.idle_clock=2; cook.needs.hunger=10
	_command("a",diner,"eat"); _advance(5)
	assert(cook.task.get("automatic",false) and not _done(cook,"meal_together") and not _done(diner,"meal_together"))
	# Choosing the automatic diner starts a new overlap clock, without another portion.
	var portions: int=table.meal.servings; _command("a",cook,"choose"); var social_funds: int=lot.funds
	_advance(3.9); assert(not _done(cook,"meal_together") and not _done(diner,"meal_together"))
	world.step(0.1); assert(_done(cook,"meal_together") and _done(diner,"meal_together") and table.meal.servings==portions and lot.funds==social_funds+80)
	var rewarded: Dictionary=world.snapshot(); assert(replica.restore(JSON.parse_string(JSON.stringify(rewarded)),true))
	_advance(12); assert(lot.funds==social_funds+80,"Continuing chosen company never repeats the reward")
	for tick in range(120): replica.step(0.1)
	assert(replica.state.lots.lot_1.funds==lot.funds)
	assert(world.apply_command("a",{"type":"pursue_wish","member_id":cook.id,"wish_id":"story"}).ok)
	cook.autonomy=false; _advance(25)
	assert(Wishes.completed(cook.wishes)==3 and lot.funds==social_funds+200,"Existing three-wish set bonus still applies once")
	assert(not world.apply_command("a",{"type":"renew_wishes","member_id":cook.id}).ok)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.lots.lot_1.funds==lot.funds and Wishes.completed(replica.state.families.a.members[0].wishes)==3)
	# Visitors earn their own reward; today's friendship cap does not block a wish.
	_fresh(); _serve(); var guest: Dictionary=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":lot.id}).ok)
	cook.x=7; cook.y=6; guest.x=8; guest.y=5; diner.x=8; diner.y=14
	Bonds.record(world.state,cook.id,guest.id,world.state.tick,"chat"); world.state.tick+=1
	Bonds.record(world.state,cook.id,guest.id,world.state.tick,"chat"); world.state.tick+=1
	var score: int=Bonds.bond(world.state,cook.id,guest.id).score
	var home_funds: int=lot.funds; var guest_funds: int=world.state.lots.lot_2.funds
	_command("a",cook,"eat"); _command("b",guest,"eat"); _advance(4)
	assert(_done(cook,"meal_together") and _done(guest,"meal_together") and not _done(diner,"meal_together"))
	assert(lot.funds==home_funds+40 and world.state.lots.lot_2.funds==guest_funds+40 and Bonds.bond(world.state,cook.id,guest.id).score==score)
	assert(world.meal_wish_option("b",guest.id,"homemade").lot_id=="lot_2","Cooking always points home")
	# A final qualifying tick still counts when adoption leaves exactly four seconds.
	_fresh(); _serve(); cook.autonomy=true; diner.autonomy=true
	cook.needs.hunger=10; diner.needs.hunger=10; cook.idle_clock=2; diner.idle_clock=2; cook.x=7; cook.y=6; diner.x=8; diner.y=5
	_advance(6); _command("a",cook,"choose"); _command("a",diner,"choose"); _advance(4)
	assert(_done(cook,"meal_together") and _done(diner,"meal_together"))
	# Absence, cancellation, and failed serving cannot finish a meal wish.
	_fresh(); _command("a",cook,"prepare","sandwiches"); lot.funds=0; _advance(20)
	assert(not _done(cook,"homemade") and lot.funds==0 and table.meal.servings==0)
	_fresh(); world.set_online("a",false); cook.autonomy=true; diner.autonomy=true; _advance(40)
	assert(Wishes.completed(cook.wishes)==0 and Wishes.completed(diner.wishes)==0)
	# Read-only guidance covers missing equipment, visits, and construction.
	_fresh(); lot.objects.erase(table); before=world.snapshot(); option=world.meal_wish_option("a",cook.id,"homemade")
	assert(option.action=="build" and option.lot_id==lot.id and option.detail.contains("§280") and world.snapshot()==before)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(not world.meal_wish_option("a",cook.id,"meal_together").available)
	# Existing wish sets remain byte-for-byte data through restoration.
	var old:=World.new(); old.initialize(); old.ensure_family("old","Original"); var legacy: Dictionary=old.snapshot()
	var old_board: Dictionary=legacy.families.old.members[0].wishes.duplicate(true)
	assert(replica.restore(JSON.parse_string(JSON.stringify(legacy)),true) and replica.state.families.old.members[0].wishes==old_board)
	print("MEAL_WISHES_PASS"); quit()
