extends SceneTree
const World = preload("res://game/world.gd")
const Routines = preload("res://game/routines.gd")
var world: RefCounted
var family: Dictionary
var member: Dictionary

func _initialize() -> void: call_deferred("_run")

func _save(id: String,name: String,steps: Array) -> Dictionary:
	return world.apply_command("a",{"type":"routine_save","routine_id":id,"revision":family.routines.revision,"name":name,"steps":steps})

func _start(id: String,who: String="") -> Dictionary:
	return world.apply_command("a",{"type":"run_routine","member_id":member.id if who.is_empty() else who,"routine_id":id,"revision":family.routines.revision})

func _reject(command: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,command).ok)
	assert(world.snapshot()==before,"Rejected routine operations are atomic, including action counters")

func _run() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet"); world.set_online("a",true)
	family=world.state.families.a; member=family.members[0]
	for household: Dictionary in world.state.families.values():
		for resident: Dictionary in household.members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=30.0
	assert(Routines.valid(family.routines) and family.routines.entries.size()==2)
	var before: Dictionary=world.snapshot()
	var option: Dictionary=world.routine_option("a",member.id,"routine_1")
	assert(option.available and option.actions.size()==3 and world.snapshot()==before)
	option.actions[0].target_id="changed"
	assert(world.snapshot()==before,"Preview actions never alias world state")
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":9,"y":9}).ok)
	var active: Dictionary=member.task.duplicate(true)
	assert(_start("routine_1").ok)
	assert(member.task==active and member.queue.size()==3,"A routine appends after existing manual work")
	var sequence: Array=[]
	for task: Dictionary in member.queue:
		assert(task.routine_id=="routine_1" and task.routine_name=="Morning care")
		sequence.append(task.id)
	_reject({"type":"run_routine","member_id":member.id,"routine_id":"routine_1","revision":family.routines.revision})
	assert(_start("routine_1",family.members[1].id).ok,"Both residents can use the same library independently")
	var observed: Array=[]
	for tick in range(1000):
		world.step(0.1)
		if member.task.get("routine_id")=="routine_1" and (observed.is_empty() or observed[-1]!=member.task.id): observed.append(member.task.id)
		if member.task.is_empty() and member.queue.is_empty() and family.members[1].task.is_empty() and family.members[1].queue.is_empty(): break
	assert(observed==sequence and member.task.is_empty() and member.queue.is_empty(),"Routine steps run in their exact order while sharing private furnishings")
	assert(member.needs.hunger>50 and member.needs.hygiene>50 and member.needs.bladder>50)
	# Names and ordered steps survive both network snapshots and saved reloads.
	assert(_save("","A quiet afternoon",["bookshelf","table","plant"]).ok)
	var id := "routine_3"
	assert(_start(id).ok)
	var runtime := World.new(); assert(runtime.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(runtime.state.families.a.routines==family.routines and runtime.state.families.a.members[0].task.routine_id==id)
	var saved := World.new(); assert(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(saved.state.families.a.routines==family.routines and saved.state.families.a.members[0].task.is_empty())
	# Editing/removing a recipe does not change actions already accepted from it.
	active=member.task.duplicate(true); var queue: Array=member.queue.duplicate(true)
	assert(_save(id,"A different afternoon",["tv","sofa"]).ok)
	assert(member.task==active and member.queue==queue)
	assert(world.apply_command("a",{"type":"routine_delete","routine_id":id,"revision":family.routines.revision}).ok)
	assert(member.task==active and member.queue==queue)
	assert(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true),"Deleted recipe tags remain valid on accepted actions")
	world._clear_member(member)
	assert(_save("","A game",["game_table"]).ok)
	before=world.snapshot()
	assert(not _start("routine_4").ok and world.snapshot()==before,"A missing furnishing cannot partially fill the plan")
	assert(_save("routine_4","Food then games",["fridge","game_table"]).ok)
	before=world.snapshot(); assert(not _start("routine_4").ok and world.snapshot()==before)
	# Presets resolve the current lot, not object IDs saved in their recipe.
	assert(world.apply_command("a",{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)
	option=world.routine_option("a",member.id,"routine_1")
	assert(option.available)
	for action: Dictionary in option.actions: assert(not world._object(world.state.lots.lot_2,action.target_id).is_empty())
	assert(_start("routine_1").ok and member.lot_id=="lot_2")
	world._clear_member(member)
	for index in range(7): assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":"lot_2","x":index,"y":0}).ok)
	before=world.snapshot(); assert(not _start("routine_1").ok and world.snapshot()==before,"Queue capacity is checked for the entire sequence")
	world._clear_member(member)
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":"lot_2","x":0,"y":0}).ok)
	member.task.automatic=true
	assert(_start("routine_1").ok and member.task.routine_id=="routine_1" and member.queue.size()==2,"Deliberate routine use replaces autonomous work like other direct orders")
	# Ownership, malformed edits, stale revisions and capacity cannot mutate state.
	var revision: int=family.routines.revision
	_reject({"type":"routine_save","routine_id":"routine_1","revision":revision-1,"name":"Stale","steps":["bed"]})
	_reject({"type":"run_routine","member_id":world.state.families.b.members[0].id,"routine_id":"routine_1","revision":revision})
	for invalid: Variant in [null,3,{},[],["chat"],["move"],["unknown"],["bed","bed","bed","bed","bed","bed","bed"]]:
		_reject({"type":"routine_save","routine_id":"routine_1","revision":revision,"name":"Invalid","steps":invalid})
	for invalid: Variant in [null,3,"","bad\nname","x".repeat(33)]:
		_reject({"type":"routine_save","routine_id":"routine_1","revision":revision,"name":invalid,"steps":["bed"]})
	assert(_save("","Final slot",["bed"]).ok)
	_reject({"type":"routine_save","routine_id":"","revision":family.routines.revision,"name":"Too many","steps":["bed"]})
	_reject({"type":"routine_delete","routine_id":"routine_999","revision":family.routines.revision})
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	before=world.snapshot(); assert(not _start("routine_1").ok and world.snapshot()==before)
	# Legacy saves gain presets; malformed saved libraries/tags fail atomically.
	var legacy: Dictionary=world.snapshot_for_save()
	for household: Dictionary in legacy.families.values(): household.erase("routines")
	assert(saved.restore(legacy) and saved.state.families.a.routines==Routines.create())
	for corrupt: Variant in [null,{},[],{"revision":0,"next_id":1,"entries":[{"id":"routine_1","name":"Bad","steps":["bed"]}]}]:
		var data: Dictionary=world.snapshot_for_save(); data.families.a.routines=corrupt
		var previous: Dictionary=saved.snapshot(); assert(not saved.restore(data) and saved.snapshot()==previous)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":"lot_1"}).ok)
	world._clear_member(member)
	assert(_start("routine_1").ok)
	var bad_tag: Dictionary=world.snapshot(); bad_tag.families.a.members[0].task.routine_name=[]
	before=saved.snapshot(); assert(not saved.restore(bad_tag,true) and saved.snapshot()==before)
	print("ROUTINES_PASS")
	quit()
