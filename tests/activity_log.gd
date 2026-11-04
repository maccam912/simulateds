extends SceneTree
const World = preload("res://game/world.gd")
const Log = preload("res://game/activity_log.gd")
var world: RefCounted
var member: Dictionary
var other: Dictionary
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _setup() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,"Alex" if owner=="a" else "Violet"); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members: resident.autonomy=false
	member=world.state.families.a.members[0]; other=world.state.families.b.members[0]; lot=world.state.lots.lot_1

func _command(type: String, extra: Dictionary={}, actor: Dictionary={}) -> void:
	var resident: Dictionary=member if actor.is_empty() else actor
	var intent := {"type":type,"member_id":resident.id,"lot_id":resident.lot_id}; intent.merge(extra,true)
	assert(world.apply_command("a" if resident.id==member.id else "b",intent).ok,str(intent))

func _finish() -> void:
	for tick in range(1500):
		world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false,"Plan did not finish")

func _object(kind: String) -> Dictionary:
	for object: Dictionary in lot.objects:
		if object.kind==kind: return object
	return {}

func _run() -> void:
	_setup()
	_command("move",{"x":7,"y":7})
	var first_id: String=member.task.id
	_finish()
	assert(member.activity_log.size()==1 and member.activity_log[0].id==first_id and member.activity_log[0].outcome=="done" and member.activity_log[0].reason=="Arrived.")
	assert(member.activity_log[0].title=="Walk to 7, 7" and Log.timestamp(member.activity_log[0]).begins_with("Day 1 · 08:"))
	member.needs.fun=100.0
	_command("interact",{"target_id":_object("bookshelf").id}); _finish()
	assert(member.activity_log[0].outcome=="done" and member.activity_log[0].reason=="Fun fulfilled.","A full need may finish ordinary leisure early and says why")
	var completed: Array=member.activity_log.duplicate(true)
	world._record_activity(member,{"id":completed[0].id,"type":"move","x":0,"y":0},"done","Repeated")
	assert(member.activity_log==completed,"Repeated completion cannot duplicate a result")
	_command("move",{"x":0,"y":0}); _command("move",{"x":1,"y":0})
	var active: String=member.task.id; var queued: String=member.queue[0].id
	_command("remove_action",{"action_id":queued})
	assert(member.activity_log[0].id==queued and member.activity_log[0].outcome=="cancelled" and member.task.id==active)
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command("a",{"type":"remove_action","member_id":member.id,"action_id":queued}).ok and world.snapshot()==before)
	assert(not world.apply_command("b",{"type":"cancel","member_id":member.id}).ok and world.snapshot()==before)
	_command("remove_action",{"action_id":active})
	assert(member.activity_log[0].id==active and member.activity_log[0].reason=="Cancelled from Plan.")
	# Batch clearing shows the current action followed by its upcoming steps.
	for x in range(9): _command("move",{"x":x,"y":0})
	var ordered: Array=[member.task.id]
	for task: Dictionary in member.queue: ordered.append(task.id)
	_command("cancel")
	assert(member.activity_log.size()==Log.LIMIT)
	for index in range(Log.LIMIT): assert(member.activity_log[index].id==ordered[index] and member.activity_log[index].outcome=="cancelled")
	# Autonomous care, including interruption by a manual order, stays quiet.
	completed=member.activity_log.duplicate(true)
	world._queue_action(member,{"type":"move","x":member.x,"y":member.y,"automatic":true}); _finish()
	assert(member.activity_log==completed)
	world._queue_action(member,{"type":"move","x":0,"y":0,"automatic":true}); world._start_next(member,lot)
	_command("move",{"x":1,"y":0})
	assert(member.activity_log==completed)
	_command("cancel")
	# Stored titles survive missing furnishings and neighbor renames/departures.
	_setup()
	var shelf := _object("bookshelf"); var shelf_name: String=World.Catalog.ITEMS.bookshelf.name
	_command("move",{"x":8,"y":7}); _command("interact",{"target_id":shelf.id})
	lot.objects.erase(shelf); _finish()
	assert(member.activity_log[0].title==shelf_name and member.activity_log[0].outcome=="failed" and member.activity_log[0].reason.contains("no longer here"))
	_setup()
	_command("interact",{"target_id":_object("bookshelf").id})
	while not member.task.path.is_empty(): world.step(0.1)
	lot.objects.erase(_object("bookshelf")); world.step(0.1)
	assert(member.activity_log[0].outcome=="failed")
	_setup()
	_command("move",{"x":0,"y":0}); _command("move",{"x":1,"y":0})
	var blocked: Array=member.task.path[0].duplicate(); lot.walls.append(blocked)
	world.step(0.3)
	assert(member.task.is_empty() and member.queue.is_empty() and member.activity_log[0].outcome=="failed" and member.activity_log[1].outcome=="cancelled")
	_setup()
	_command("move",{"x":7,"y":7}); _command("move",{"x":0,"y":0})
	lot.walls.append([0,0]); _finish()
	assert(member.activity_log[0].outcome=="failed" and member.activity_log[0].reason.contains("no path"))
	_setup()
	_command("visit",{"lot_id":"lot_1"},other); other.x=8; other.y=7
	_command("interact",{"target_id":other.id}); world.step(0.1)
	other.name="Changed name"; _command("go_home",{},other); world.step(0.1)
	assert(member.activity_log[0].title=="Chat with Violet" and member.activity_log[0].outcome=="failed")
	_setup()
	_command("visit",{"lot_id":"lot_1"},other); other.x=8; other.y=7
	_command("interact",{"target_id":other.id}); _finish()
	assert(member.activity_log[0].outcome=="done" and member.activity_log[0].reason=="Conversation finished.")
	# Travel, building, and absence explain why unfinished plans were cancelled.
	_setup(); _command("move",{"x":0,"y":0}); _command("visit",{"lot_id":"lot_2"})
	assert(member.activity_log[0].reason=="Travelled to Willow House.")
	_command("move",{"x":0,"y":0}); _command("build_begin",{"lot_id":"lot_2"},other)
	assert(member.lot_id=="lot_1" and member.activity_log[0].reason.contains("construction; returned home"))
	_command("move",{"x":0,"y":0}); _command("build_begin",{"lot_id":"lot_1"})
	assert(member.activity_log[0].reason=="Construction started.")
	_command("build_cancel",{"lot_id":"lot_1"}); _command("move",{"x":0,"y":0}); world.set_online("a",false)
	assert(member.activity_log[0].reason=="Household went away; returned home.")
	# Runtime snapshots preserve pending work; disk load explicitly clears it once.
	_setup(); _command("move",{"x":7,"y":7}); _finish()
	_command("run_routine",{"routine_id":"routine_1","revision":0})
	var saved: Dictionary=JSON.parse_string(JSON.stringify(world.snapshot_for_save()))
	var replica := World.new(); assert(replica.restore(saved,true))
	assert(replica.state.families.a.members[0].activity_log==member.activity_log and not replica.state.families.a.members[0].task.is_empty())
	assert(replica.restore(saved))
	var loaded: Dictionary=replica.state.families.a.members[0]
	assert(loaded.task.is_empty() and loaded.queue.is_empty() and loaded.activity_log[0].outcome=="cancelled" and loaded.activity_log[0].reason.contains("Neighborhood loaded"))
	assert(not loaded.activity_log[0].routine.is_empty(),"Routine provenance survives its later editing/deletion")
	var history: Array=loaded.activity_log.duplicate(true)
	assert(replica.restore(JSON.parse_string(JSON.stringify(replica.snapshot_for_save()))))
	assert(replica.state.families.a.members[0].activity_log==history,"Repeated loading an already-cleared plan creates no extra results")
	var legacy: Dictionary=world.snapshot()
	for family: Dictionary in legacy.families.values():
		for resident: Dictionary in family.members:
			resident.erase("activity_log")
			for task: Dictionary in resident.queue: task.erase("title")
			resident.task.erase("title")
	assert(replica.restore(legacy,true) and replica.state.families.a.members[0].activity_log.is_empty())
	assert(replica.state.families.a.members[0].task.has("title"))
	# Bounded strict validation rejects corrupt history atomically, including JSON floats.
	var valid: Dictionary=world.snapshot()
	for key: String in Log.FIELDS:
		for invalid: Variant in [null,{},[],true,NAN,INF,-1,"",String.chr(10),"x".repeat(181)]:
			if key=="routine" and invalid is String and invalid=="": continue
			var broken: Dictionary=valid.duplicate(true); broken.families.a.members[0].activity_log[0][key]=invalid
			if key=="id" and invalid is String and invalid==String.chr(10): continue # Legacy task IDs are opaque.
			before=replica.snapshot(); assert(not replica.restore(broken,true) and replica.snapshot()==before,"Bad log field: "+key+" "+str(invalid))
	for mutation in range(7):
		var broken: Dictionary=valid.duplicate(true); var entries: Array=broken.families.a.members[0].activity_log
		match mutation:
			0: entries[0].day=int(valid.day)+1
			1: entries[0].minute=1440
			2: entries[0].tick=int(valid.tick)+1
			3: entries[0].extra=true
			4: entries.append(entries[0].duplicate(true))
			5: entries[0].erase("reason")
			6: entries[0].outcome="pending"
		before=replica.snapshot(); assert(not replica.restore(broken,true) and replica.snapshot()==before)
	assert(Log.valid(history,int(replica.state.day),int(replica.state.tick)))
	var oversized := history.duplicate(true)
	while oversized.size()<=Log.LIMIT: oversized.append(history[0].duplicate(true))
	assert(not Log.valid(oversized,int(world.state.day),int(world.state.tick)))
	var backwards := history.duplicate(true); backwards[0].tick=0
	assert(not Log.valid(backwards,int(world.state.day),int(world.state.tick)),"History cannot claim older entries happened after newer entries")
	var fractional := history.duplicate(true); fractional[0].minute=480.5
	assert(not Log.valid(fractional,int(world.state.day),int(world.state.tick)))
	# Old saves may have an empty display label on an already-missing target.
	legacy.families.a.members[0].task.target_id="missing"; legacy.families.a.members[0].task.label=" "; legacy.families.a.members[0].task.erase("title")
	assert(replica.restore(legacy) and replica._valid_state(replica.snapshot()),"Migration always produces valid fallback titles")
	print("ACTIVITY_LOG_PASS")
	quit()
