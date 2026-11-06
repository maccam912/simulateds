extends SceneTree
const World = preload("res://game/world.gd")
const Gardens = preload("res://game/gardens.gd")
const Rules = preload("res://game/build_rules.gd")
const Status = preload("res://game/activity_status.gd")
var world: RefCounted
var lot: Dictionary
var bed: Dictionary
var member: Dictionary

func _initialize() -> void: call_deferred("_run")

func _setup() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=100.0
			for wish: Dictionary in resident.wishes.wishes: wish.done=true
	lot=world.state.lots.lot_1; member=world.state.families.a.members[0]
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	var placement := {"type":"place","kind":"garden_bed","lot_id":"lot_1","x":5,"y":13}
	assert(Rules.inspect(lot,placement,[]).ok and world.apply_command("a",placement).ok)
	bed=lot.objects[-1]; assert(not lot.floors.has([5,13]) and lot.funds==11820)
	assert(world.apply_command("a",{"type":"build_end","lot_id":"lot_1"}).ok)

func _intent(action: String,crop: String="",resident: Dictionary={}) -> Dictionary:
	return {"type":"garden","member_id":resident.get("id",member.id),"lot_id":"lot_1","target_id":bed.id,"action":action,"crop":crop,"revision":bed.garden.revision}

func _reject(intent: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	var result: Dictionary=world.apply_command(owner,intent)
	assert(not result.ok,"Unexpectedly accepted: "+str(intent))
	assert(world.snapshot()==before,"Rejected gardening cannot change needs, funds, plans, or crops")

func _finish(resident: Dictionary={}) -> void:
	var actor: Dictionary=member if resident.is_empty() else resident
	for tick in range(1000):
		world.step(0.1)
		if actor.task.is_empty() and actor.queue.is_empty(): return
	assert(false,"Gardening did not finish: "+str(actor.task))

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): world.step(0.1)

func _run() -> void:
	_setup()
	var preview_bed := {"crop":"tomato","growth":0.0,"water":45.0}
	assert(Gardens.readiness(preview_bed,World.MINUTES_PER_SECOND).contains("9 game h 00 min if kept watered"))
	Gardens.grow(preview_bed,45)
	assert(Gardens.readiness(preview_bed,World.MINUTES_PER_SECOND).contains("Needs water"))
	assert(Gardens.readiness(preview_bed,World.MINUTES_PER_SECOND).contains("6 game h 45 min"))
	preview_bed.water=120.0; preview_bed.growth=100.0
	assert(Gardens.readiness(preview_bed,World.MINUTES_PER_SECOND).contains("Enough water"))
	Gardens.grow(preview_bed,80)
	assert(Gardens.readiness(preview_bed,World.MINUTES_PER_SECOND).begins_with("Ready to harvest"))
	var original: Dictionary=world.snapshot()
	var preview: Dictionary=world.garden_option("a",member.id,"lot_1",bed.id,"plant","radish")
	assert(preview.ok and preview.cost==10 and preview.duration==8 and world.snapshot()==original)
	for key: String in ["action","crop","target_id","revision"]:
		for value: Variant in [null,{},[],true,NAN,INF,-1,0.5,"unknown"]:
			var invalid := _intent("plant","radish"); invalid[key]=value; _reject(invalid)
	_reject(_intent("water")); _reject(_intent("harvest"))
	_reject({"type":"interact","member_id":member.id,"lot_id":"lot_1","target_id":bed.id})
	var other: Dictionary=world.state.families.a.members[1]
	var plant := _intent("plant","radish")
	assert(world.apply_command("a",plant).ok)
	_reject(plant); _reject(_intent("plant","tomato",other))
	assert(lot.funds==11820 and bed.garden.crop=="","Queueing does not spend seeds or plant instantly")
	while not member.task.path.is_empty(): world.step(0.1)
	world.step(0.1)
	assert(Status.sample(member,lot).remaining>7.0,"Full needs cannot shorten gardening work")
	_advance(2); assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	assert(lot.funds==11820 and bed.garden==Gardens.create())
	assert(member.hobbies.gardening.sessions==0,"Canceled work cannot award practice")
	assert(world.apply_command("a",plant).ok); _finish()
	assert(lot.funds==11810 and bed.garden.crop=="radish" and bed.garden.revision==1)
	assert(member.activity_log[0].outcome=="done" and member.activity_log[0].reason=="Seeds planted.")
	assert(member.hobbies.gardening.sessions==1)
	_reject(plant)
	assert(world.apply_command("a",_intent("water")).ok); _finish()
	assert(bed.garden.water==Gardens.WATER_CAP and member.hobbies.gardening.sessions==2)
	_reject(_intent("water"))
	_advance(100); assert(Gardens.ripe(bed.garden))
	var ripe: Dictionary=bed.garden.duplicate(true); _advance(10); assert(bed.garden==ripe)
	var harvest := _intent("harvest")
	assert(world.apply_command("a",harvest).ok); _finish()
	assert(lot.funds==11855 and bed.garden.crop=="" and bed.garden.harvests==1 and member.hobbies.gardening.sessions==2)
	assert(member.activity_log[0].reason=="Harvest sold for §45." and member.activity_log[0].title.contains("radish"))
	_reject(harvest)
	# A longer crop needs more water, with safe dry/ripe waits and visitor help.
	assert(world.apply_command("a",_intent("plant","tomato")).ok); _finish()
	_advance(50); assert(is_equal_approx(bed.garden.growth,45) and is_zero_approx(bed.garden.water))
	var dry: Dictionary=bed.garden.duplicate(true)
	world.set_online("a",false); _advance(50); assert(bed.garden==dry and not Gardens.ripe(bed.garden))
	world.set_online("a",true)
	var visitor: Dictionary=world.state.families.b.members[0]
	_reject(_intent("water","",visitor),"b")
	assert(world.apply_command("b",{"type":"visit","member_id":visitor.id,"lot_id":"lot_1"}).ok)
	_reject(_intent("plant","radish",visitor),"b"); _reject(_intent("harvest","",visitor),"b")
	var visitor_funds: int=world.state.lots.lot_2.funds
	assert(world.apply_command("b",_intent("water","",visitor)).ok); _finish(visitor)
	assert(bed.garden.water==Gardens.WATER_CAP and world.state.lots.lot_2.funds==visitor_funds and visitor.hobbies.gardening.sessions==1)
	world.set_online("a",false); _advance(125)
	assert(is_equal_approx(bed.garden.growth,165) and is_zero_approx(bed.garden.water))
	assert(world.apply_command("b",_intent("water","",visitor)).ok); _finish(visitor); _advance(20)
	assert(Gardens.ripe(bed.garden) and bed.garden.crop=="tomato")
	_reject(_intent("harvest","",visitor),"b")
	world.set_online("a",true)
	# The crop, including earned harvest count, travels with its furnishing/history.
	var crop: Dictionary=bed.garden.duplicate(true)
	var restored := World.new(); assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	var saved_crop: Dictionary=restored.state.lots.lot_1.objects[-1].garden
	assert(saved_crop.crop==crop.crop and saved_crop.revision==crop.revision and saved_crop.harvests==crop.harvests and is_equal_approx(saved_crop.growth,crop.growth) and is_equal_approx(saved_crop.water,crop.water))
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	_advance(5); assert(bed.garden==crop and visitor.lot_id=="lot_2")
	assert(world.apply_command("a",{"type":"move_object","lot_id":"lot_1","object_id":bed.id,"x":13,"y":12,"rotation":1}).ok)
	assert(bed.garden==crop)
	assert(world.apply_command("a",{"type":"erase","lot_id":"lot_1","x":13,"y":12}).ok)
	assert(world.apply_command("a",{"type":"build_undo","lot_id":"lot_1","revision":lot.revision}).ok)
	bed=lot.objects[-1]; assert(bed.garden==crop and bed.x==13)
	var committed: Dictionary=world.snapshot_for_save().lots.lot_1.objects[-1]
	assert(committed.garden==crop and committed.x==5)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":"lot_1"}).ok)
	bed=lot.objects[-1]; assert(bed.garden==crop and bed.x==5)
	# Every malformed persistent crop rejects the entire restore atomically.
	for key: String in ["crop","growth","water","revision","harvests"]:
		for value: Variant in [null,{},[],true,NAN,INF,-1,"invalid",1000000001]:
			var invalid: Dictionary=world.snapshot(); invalid.lots.lot_1.objects[-1].garden[key]=value
			var before: Dictionary=restored.snapshot(); assert(not restored.restore(invalid,true) and restored.snapshot()==before)
	var invalid: Dictionary=world.snapshot(); invalid.lots.lot_1.objects[-1].erase("garden"); assert(not restored.restore(invalid))
	invalid=world.snapshot(); invalid.lots.lot_1.objects[0].garden=Gardens.create(); assert(not restored.restore(invalid))
	var legacy := World.new(); legacy.initialize(); legacy.ensure_family("old","Old")
	assert(restored.restore(JSON.parse_string(JSON.stringify(legacy.snapshot()))),"Worlds predating garden beds still load")
	# Budgets are checked again at completion; no crop/seed debit on cancellation.
	_setup(); assert(world.apply_command("a",_intent("plant","radish")).ok)
	lot.funds=0; _finish(); assert(lot.funds==0 and bed.garden==Gardens.create())
	lot.funds=11820; assert(world.apply_command("a",_intent("plant","radish")).ok)
	var runtime: Dictionary=world.snapshot(); assert(restored.restore(JSON.parse_string(JSON.stringify(runtime)),true))
	assert(restored.state.families.a.members[0].task.garden_action=="plant")
	for key: String in ["garden_action","garden_revision","crop"]:
		invalid=runtime.duplicate(true); invalid.families.a.members[0].task.erase(key); assert(not restored.restore(invalid,true))
	assert(restored.restore(runtime)); assert(restored.state.families.a.members[0].task.is_empty() and restored.state.lots.lot_1.objects[-1].garden.crop=="")
	_finish(); assert(world.apply_command("a",_intent("water")).ok); _finish(); _advance(100)
	lot.funds=1000000000; _reject(_intent("harvest")); assert(Gardens.ripe(bed.garden))
	_setup(); lot.objects=[bed]; member.autonomy=true; member.needs.comfort=0.0
	var budget: int=lot.funds; _advance(10)
	assert(member.task.is_empty() and member.queue.is_empty() and bed.garden==Gardens.create() and lot.funds==budget,"Autonomy never spends seeds or farms harvests")
	# A cancelled/reordered queue does not reserve a bed forever, and a saved
	# stale revision cannot plant the next crop by accident.
	member.autonomy=false; member.x=0; member.y=0
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":0,"y":10}).ok)
	assert(world.apply_command("a",_intent("plant","radish")).ok)
	assert(member.queue.size()==1)
	var action_id: String=member.queue[0].id
	assert(world.apply_command("a",{"type":"remove_action","member_id":member.id,"action_id":action_id}).ok)
	assert(world.garden_option("a",other.id,"lot_1",bed.id,"plant","tomato").ok)
	assert(world.apply_command("a",_intent("plant","tomato")).ok)
	bed.garden.revision+=1; _finish()
	assert(bed.garden.crop=="" and lot.funds==budget)
	print("GARDENS_PASS"); quit()
