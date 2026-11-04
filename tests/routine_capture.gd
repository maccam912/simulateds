extends SceneTree
const World = preload("res://game/world.gd")
const Routines = preload("res://game/routines.gd")
var world: RefCounted
var member: Dictionary
var family: Dictionary

func _initialize() -> void: call_deferred("_run")

func _setup() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,"Alex" if owner=="a" else "Violet"); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=20.0
	family=world.state.families.a; member=family.members[0]

func _object(kind: String,lot_id: String="lot_1") -> Dictionary:
	for object: Dictionary in world.state.lots[lot_id].objects:
		if object.kind==kind: return object
	return {}

func _plan(kind: String) -> void:
	assert(world.apply_command("a",{"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":_object(kind,member.lot_id).id}).ok)

func _capture() -> Dictionary:
	var before: Dictionary=world.snapshot()
	var result := Routines.capture_plan(member,world.state.lots[member.lot_id])
	assert(world.snapshot()==before,"Capturing cannot change accepted work, needs, funds, counters, or history")
	return result

func _run() -> void:
	_setup()
	assert(_capture().steps.is_empty() and _capture().omitted.is_empty())
	for kind: String in ["fridge","shower","bookshelf","bookshelf"]: _plan(kind)
	var captured := _capture()
	assert(captured.resident=="Alex" and captured.steps==["fridge","shower","bookshelf","bookshelf"] and captured.omitted.is_empty(),"Includes the current action, preserves repeated activities and exact upcoming order")
	captured.steps[0]="bed"; captured.omitted.append({"title":"unrelated"})
	assert(_capture().steps[0]=="fridge" and _capture().omitted.is_empty(),"The draft never aliases live tasks")
	# Autonomous work is excluded even while deliberate orders remain queued.
	member.task.automatic=true
	captured=_capture()
	assert(captured.steps==["shower","bookshelf","bookshelf"] and captured.omitted.size()==1 and captured.omitted[0].reason.contains("autonomously"))
	# Movement, partner-specific conversations, and crop work cannot turn into
	# misleading reusable furnishings. Each omitted position is explained.
	_setup()
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":"lot_1","kind":"garden_bed","x":5,"y":13}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":0,"y":0}).ok)
	assert(world.apply_command("a",{"type":"interact","member_id":member.id,"target_id":family.members[1].id}).ok)
	assert(world.apply_command("a",{"type":"garden","member_id":member.id,"target_id":_object("garden_bed").id,"action":"plant","crop":"radish","revision":0}).ok)
	_plan("plant"); _plan("bookshelf")
	captured=_capture()
	assert(captured.steps==["plant","bookshelf"] and captured.omitted.size()==3,"A houseplant pastime stays reusable while crop work remains specific")
	for index in range(3): assert(captured.omitted[index].position==index+1 and not captured.omitted[index].title.is_empty())
	assert(captured.omitted[0].reason.contains("Walking") and captured.omitted[1].reason.contains("resident") and captured.omitted[2].reason.contains("crop"))
	var old: Dictionary=captured.duplicate(true)
	world.state.lots.lot_1.objects.erase(_object("bookshelf"))
	assert(_capture().steps==["plant"] and _capture().omitted[3].reason.contains("no longer available"))
	assert(captured==old,"A captured draft stays fixed while the live lot or plan changes")
	# Capturing nine supported orders must not silently choose which six to keep.
	_setup()
	for index in range(9): _plan("table" if index%2==0 else "bookshelf")
	captured=_capture()
	assert(captured.steps.size()==9 and captured.omitted.is_empty() and not Routines.valid_steps(captured.steps))
	var before: Dictionary=world.snapshot()
	var intent := {"type":"routine_save","routine_id":"","revision":family.routines.revision,"name":"Too long","steps":captured.steps}
	assert(not world.apply_command("a",intent).ok and world.snapshot()==before)
	# After review, the normal authority command saves a portable recipe without
	# interrupting the source plan. The second resident can run it independently.
	captured.steps.remove_at(0); captured.steps.remove_at(3); captured.steps.remove_at(6)
	intent.name="A little afternoon"; intent.steps=captured.steps
	var active: Dictionary=member.task.duplicate(true); var upcoming: Array=member.queue.duplicate(true)
	assert(world.apply_command("a",intent).ok and member.task==active and member.queue==upcoming)
	assert(family.routines.entries[2].steps==captured.steps)
	var second: Dictionary=family.members[1]
	assert(world.apply_command("a",{"type":"visit","member_id":second.id,"lot_id":"lot_2"}).ok)
	assert(world.apply_command("a",{"type":"run_routine","member_id":second.id,"routine_id":"routine_3","revision":family.routines.revision}).ok)
	assert(second.task.routine_id=="routine_3" and second.queue.size()==5)
	assert(not world._object(world.state.lots.lot_2,second.task.target_id).is_empty(),"The saved draft resolves new local furnishings, not original object IDs")
	assert(Routines.capture_plan(second,world.state.lots.lot_2).steps==captured.steps)
	var replica := World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(replica.state.families.a.routines==family.routines)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.families.a.routines==family.routines)
	print("ROUTINE_CAPTURE_PASS")
	quit()
