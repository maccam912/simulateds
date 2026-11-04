extends SceneTree
const World = preload("res://game/world.gd")
const Bonds = preload("res://game/friendships.gd")
var world: RefCounted
var lot: Dictionary
var first: Dictionary
var second: Dictionary
var object: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh(kind: String="stereo", full: bool=false) -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for member: Dictionary in world.state.families[owner].members:
			member.autonomy=false; member.needs.fun=100.0 if full else 0.0
	lot=world.state.lots.lot_1; lot.objects=[]; lot.walls=[]; lot.doors=[]; lot.windows={}
	object=world._new_object(kind,8,5,0); lot.objects.append(object)
	first=world.state.families.a.members[0]; second=world.state.families.b.members[0]
	world.state.families.a.members[1].x=1; world.state.families.a.members[1].y=13
	assert(world.apply_command("b",{"type":"visit","member_id":second.id,"lot_id":lot.id}).ok)
	first.x=8; first.y=7 if kind=="game_table" else 6
	second.x=9; second.y=7 if kind=="game_table" else 5

func _play(owner: String,member: Dictionary) -> void:
	assert(world.apply_command(owner,{"type":"interact","member_id":member.id,"lot_id":lot.id,"target_id":object.id}).ok)

func _advance(ticks: int) -> void:
	for tick in range(ticks): world.step(0.1)

func _bond() -> Dictionary: return Bonds.bond(world.state,str(first.id),str(second.id))

func _restart() -> void:
	assert(world.apply_command("a",{"type":"cancel","member_id":first.id}).ok)
	assert(world.apply_command("b",{"type":"cancel","member_id":second.id}).ok)
	first.needs.fun=0.0; second.needs.fun=0.0; _play("a",first); _play("b",second)

func _run() -> void:
	for kind: String in ["stereo","game_table"]:
		_fresh(kind); _play("a",first); _play("b",second)
		_advance(39); assert(_bond().is_empty(),"Less than 12 game minutes together earns nothing")
		world.step(0.1); assert(_bond().score==12 and _bond().today==1 and _bond().last_activity==kind and _bond().last_social_day==1)
		assert(_bond().last_chat_day==0 and first.wishes.journal.size()==1 and second.wishes.journal.size()==1)
		assert(Bonds.recent(_bond(),1).contains("1 catch-up left"))
		var saved: Dictionary=world.snapshot(); var replica := World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(saved)),true))
		for tick in range(20): replica.step(0.1)
		assert(Bonds.bond(replica.state,str(first.id),str(second.id)).score==12,"Runtime replacement cannot award the same shared encounter again")
		assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
		assert(Bonds.bond(replica.state,str(first.id),str(second.id)).last_activity==kind and replica.state.families.a.members[0].task.is_empty())
		for bad_value: Variant in ["unknown",null,{},42]:
			var bad := saved.duplicate(true); bad.friendships[Bonds.key(str(first.id),str(second.id))].last_activity=bad_value
			assert(not replica.restore(bad,true))
		var bad := saved.duplicate(true); bad.friendships[Bonds.key(str(first.id),str(second.id))].last_social_day=2
		assert(not replica.restore(bad,true))
		_advance(20); assert(_bond().score==12 and _bond().today==1)
		_restart(); _advance(40); assert(_bond().score==24 and _bond().today==2)
		_restart(); _advance(40); assert(_bond().score==24 and _bond().today==2,"Repeated deliberate play shares the daily limit")
		world.state.day=2; world.state.day_minutes=0
		_advance(10); assert(_bond().score==24,"Continuing the same activity across midnight is not a new encounter")
		_restart(); _advance(40); assert(_bond().score==36 and _bond().today==1 and _bond().last_social_day==2)
	# Completion on exactly the qualifying step counts, independent of family iteration order.
	for reverse in [false,true]:
		_fresh("stereo",true)
		if reverse: world.state.families={"b":world.state.families.b,"a":world.state.families.a}
		_play("a",first); _play("b",second); _advance(40)
		assert(first.task.is_empty() and second.task.is_empty() and _bond().score==12)
	# Solo time before a late arrival never contributes to time actually together.
	_fresh(); _play("a",first); _advance(150); _play("b",second); _advance(35)
	assert(_bond().is_empty())
	_fresh(); _play("a",first); _play("b",second); _advance(39)
	assert(world.apply_command("b",{"type":"cancel","member_id":second.id}).ok); _advance(15); assert(_bond().is_empty())
	for condition: String in ["automatic","away","other_object"]:
		_fresh(); _play("a",first)
		if condition=="other_object": object=world._new_object("stereo",10,7,0); lot.objects.append(object); second.x=10; second.y=8
		_play("b",second)
		if condition=="automatic": second.task.automatic=true
		elif condition=="away": world.state.families.b.online=false
		_advance(60); assert(_bond().is_empty(),"No progress from autonomous/absent participants or separate activities")
	# Choosing to join replaces an automatic activity with a deliberate plan.
	_fresh(); _play("a",first); _play("b",second); first.task.automatic=true; _advance(20)
	assert(world.leisure_option(first,str(second.id)).available)
	assert(world.apply_command("a",{"type":"join_dance","member_id":first.id,"lot_id":lot.id,"companion_id":second.id,"activity_id":second.task.id}).ok)
	assert(not first.task.get("automatic",false)); _advance(39); assert(_bond().is_empty()); world.step(0.1); assert(_bond().score==12)
	# A completed chat and a shared dance use the same pair/day budget.
	_fresh(); second.x=8; second.y=7
	assert(world.apply_command("a",{"type":"interact","member_id":first.id,"lot_id":lot.id,"target_id":second.id}).ok)
	_advance(105); assert(_bond().score==12 and _bond().last_activity=="chat")
	var chat_day: int=_bond().last_chat_day
	first.x=8; first.y=6; second.x=9; second.y=5; _restart(); _advance(40)
	assert(_bond().score==24 and _bond().today==2 and _bond().last_activity=="stereo" and _bond().last_chat_day==chat_day)
	_restart(); _advance(40); assert(_bond().score==24)
	# Old saves keep real chat history, without inventing a shared-game memory.
	var legacy: Dictionary=world.snapshot_for_save()
	for bond: Dictionary in legacy.friendships.values(): bond.erase("last_social_day"); bond.erase("last_activity")
	var loaded := World.new(); assert(loaded.restore(JSON.parse_string(JSON.stringify(legacy))))
	assert(Bonds.bond(loaded.state,str(first.id),str(second.id)).last_activity=="chat")
	# Every pair in a deliberate three-person game earns one encounter, not three.
	_fresh("game_table"); var third: Dictionary=world.state.families.a.members[1]; third.x=7; third.y=5
	_play("a",first); _play("b",second); _play("a",third); _advance(40)
	assert(_bond().score==12 and Bonds.bond(world.state,str(first.id),str(third.id)).score==32 and Bonds.bond(world.state,str(second.id),str(third.id)).score==12)
	_advance(40); assert(_bond().score==12)
	print("SHARED_FRIENDSHIPS_PASS"); quit()
