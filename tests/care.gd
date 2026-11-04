extends SceneTree
const World = preload("res://game/world.gd")
const Wellbeing = preload("res://game/wellbeing.gd")
var world: RefCounted
var first: Dictionary
var second: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	world.set_online("a",true); world.set_online("b",true)
	for family: Dictionary in world.state.families.values():
		for member: Dictionary in family.members: member.autonomy=false
	first=world.state.families.a.members[0]; second=world.state.families.a.members[1]

func _care(member: Dictionary, need: Variant) -> Dictionary:
	return world.apply_command("a",{"type":"care","member_id":member.id,"need":need})

func _finish(member: Dictionary) -> void:
	for index in range(1500):
		world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false,"Care plan did not complete")

func _run() -> void:
	_fresh()
	first.needs.hunger=15.0
	assert(Wellbeing.mood(first.needs).label=="Very hungry")
	var before: Dictionary=first.needs.duplicate()
	assert(_care(first,"hunger").ok and world.task_activity(first.task,"lot_1")=="fridge")
	assert(first.needs==before,"Care queues a real activity; it does not instantly change needs")
	var task_id: String=first.task.id
	assert(not _care(first,"hunger").ok and first.task.id==task_id and first.queue.is_empty(),"Double clicking cannot queue duplicate care")
	_finish(first)
	assert(first.needs.hunger>85 and Wellbeing.mood(first.needs).label!="Very hungry")
	for need: String in Wellbeing.ORDER:
		_fresh(); first.needs[need]=10.0
		assert(Wellbeing.mood(first.needs).need==need)
		assert(_care(first,need).ok); _finish(first)
		assert(first.needs[need]>65,"Each care shortcut reaches an activity that improves its need")
	_fresh()
	assert(world.apply_command("a",{"type":"move","member_id":first.id,"lot_id":"lot_1","x":0,"y":0}).ok)
	assert(world.apply_command("a",{"type":"move","member_id":first.id,"lot_id":"lot_1","x":1,"y":1}).ok)
	task_id=first.task.id
	var queued_id: String=first.queue[0].id
	assert(_care(first,"energy").ok and first.task.id==task_id and first.queue[0].id==queued_id and first.queue.size()==2,"Care preserves the existing manual plan")
	assert(not _care(first,"comfort").ok,"Planned sleep already provides comfort")
	var loaded := World.new()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true) and loaded.state.families.a.members[0].queue.size()==2)
	_finish(first); assert(first.needs.energy>85)
	_fresh()
	assert(_care(first,"energy").ok)
	var reserved: String=first.task.target_id
	assert(_care(second,"energy").ok and second.task.target_id!=reserved,"Care chooses the other free bed")
	_fresh()
	var beds: Array=[]
	for object: Dictionary in world.state.lots.lot_1.objects:
		if object.kind=="bed": beds.append(object)
	world.state.lots.lot_1.objects.erase(beds[1])
	assert(_care(first,"energy").ok and _care(second,"energy").ok)
	assert(second.task.is_empty() and second.queue.size()==1 and str(second.action).begins_with("Waiting"),"An occupied last bed queues an honest wait")
	_finish(first); _finish(second); assert(second.needs.energy>85)
	_fresh()
	assert(_care(first,"social").ok and first.task.target_id==second.id,"An idle nearby housemate is a useful social option")
	_fresh()
	assert(world.apply_command("a",{"type":"move","member_id":second.id,"lot_id":"lot_1","x":0,"y":0}).ok)
	assert(_care(first,"social").ok and world.task_activity(first.task,"lot_1")=="table","A busy housemate keeps their own plan; available tea is preferred")
	_fresh()
	world._queue_action(first,{"type":"interact","target_id":world.state.lots.lot_1.objects[2].id,"automatic":true})
	world._start_next(first,world.state.lots.lot_1)
	assert(not _care(first,"hunger").ok and first.queue.is_empty(),"An existing automatic activity also satisfies care")
	assert(_care(first,"energy").ok and world.task_activity(first.task,"lot_1")=="bed","A new manual care order preempts unrelated autonomy")
	_fresh()
	assert(world.apply_command("a",{"type":"visit","member_id":first.id,"lot_id":"lot_2"}).ok)
	assert(_care(first,"hunger").ok and not world._object(world.state.lots.lot_2,str(first.task.target_id)).is_empty(),"Care uses the resident's current lot, not the viewed or home lot")
	_fresh()
	for object: Dictionary in world.state.lots.lot_1.objects.duplicate():
		if object.kind=="fridge": world.state.lots.lot_1.objects.erase(object)
	before=world.snapshot()
	var rejected := _care(first,"hunger")
	assert(not rejected.ok and "fridge" in rejected.message and world.state==before,"Missing furniture is explained without changing the plan")
	for invalid: Variant in [null,123,[],"", "money"]:
		assert(not _care(first,invalid).ok and world.state==before)
	assert(not world.apply_command("b",{"type":"care","member_id":first.id,"need":"energy"}).ok)
	_fresh()
	for tile in [[9,4],[11,4],[10,5]]: world.state.lots.lot_1.walls.append(tile)
	before=world.snapshot()
	assert(not _care(first,"hunger").ok and world.state==before,"An existing but blocked fridge cannot be chosen")
	assert(_care(first,"energy").ok,"An unreachable need does not prevent other useful care")
	_fresh()
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	before=world.snapshot()
	assert(not _care(first,"hunger").ok and world.state==before,"Construction freezes care orders too")
	for need: String in Wellbeing.ORDER: first.needs[need]=90.0
	assert(Wellbeing.mood(first.needs).label=="Feeling great")
	print("CARE_PASS")
	quit()
