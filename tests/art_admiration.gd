extends SceneTree
const World=preload("res://game/world.gd")
const Art=preload("res://game/art_admiration.gd")
const Status=preload("res://game/activity_status.gd")
const Facing=preload("res://game/resident_facing.gd")
var world: RefCounted
var lot: Dictionary
var member: Dictionary
var art_id: String
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members: resident.autonomy=false
	lot=world.state.lots.lot_1; member=world.state.families.a.members[0]
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"easel","x":9,"y":9}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	var easel: Dictionary=lot.objects[-1]
	assert(world.apply_command("a",{"type":"painting","lot_id":lot.id,"member_id":member.id,"target_id":easel.id,"action":"start","subject":"harbor","revision":0}).ok)
	_finish(member)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"art_hang","lot_id":lot.id,"source":"easel:"+str(easel.id),"revision":lot.revision,"x":8,"y":3}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	art_id=lot.artworks.keys()[0]
func _finish(resident: Dictionary) -> void:
	for tick in range(400):
		world.step(0.1)
		if resident.task.is_empty() and resident.queue.is_empty(): return
	assert(false,"The planned activity must finish")
func _intent(resident: Dictionary) -> Dictionary: return {"type":"admire_art","lot_id":lot.id,"member_id":resident.id,"target_id":art_id,"x":8,"y":3}
func _reject(owner: String,intent: Dictionary) -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Invalid orders leave the whole world unchanged")
func _run() -> void:
	_fresh()
	for change: Dictionary in [{"target_id":[]},{"target_id":"missing"},{"x":7},{"y":3.5},{"x":null},{"member_id":"b:1"},{"lot_id":"lot_2"}]:
		var bad:=_intent(member); bad.merge(change,true); _reject("a",bad)
	_reject("b",_intent(member))
	var original: Dictionary=lot.artworks[art_id].duplicate(true); var funds: int=lot.funds; var hobbies: Dictionary=member.hobbies.duplicate(true)
	member.needs.fun=20; member.needs.comfort=20
	assert(world.apply_command("a",_intent(member)).ok); _reject("a",_intent(member))
	assert(world.care_status(member,"fun")=="In progress" and world.care_status(member,"comfort")=="In progress")
	var capture: Dictionary=preload("res://game/routines.gd").capture_plan(member,lot)
	assert(capture.steps.is_empty() and capture.omitted[0].reason.contains("particular painting"))
	var saved: Dictionary=world.snapshot(); var replica:=World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(saved)),true),"An active art plan survives JSON validation")
	assert(replica.state.families.a.members[0].task.target_kind=="art")
	for tick in range(120): replica.step(0.1)
	assert(replica.state.families.a.members[0].activity_log[0].outcome=="done")
	for bad: Dictionary in [{"target_kind":"object"},{"art_x":1.2},{"art_y":null},{"target_id":"object_1"},{"automatic":true},{"elapsed":7},{"remaining":7},{"art_x":-1}]:
		var corrupt:=saved.duplicate(true); corrupt.families.a.members[0].task.merge(bad,true)
		var before: Dictionary=replica.snapshot(); assert(not replica.restore(corrupt) and replica.snapshot()==before)
	for tick in range(100):
		world.step(0.1)
		if float(member.task.get("elapsed",0))>0: break
	assert(member.x==8 and member.y in [4,5] and float(member.task.elapsed)>0)
	var status:=Status.sample(member,lot); assert(status.phase=="activity" and status.detail.contains("Fun + comfort") and status.remaining<=6)
	var pose:=Facing.activity(world.state,member); assert(pose.kind=="admire_art" and Facing.direction(pose,member,{})==Vector2.UP)
	_finish(member)
	assert(member.needs.fun>41 and member.needs.comfort>36 and member.activity_log[0].outcome=="done")
	assert(member.activity_log[0].title.contains("Quiet harbor") and lot.artworks[art_id]==original and lot.funds==funds and member.hobbies==hobbies)
	# Full needs still allow six deliberate seconds, and cancellation stays ordinary.
	member.needs.fun=100; member.needs.comfort=100
	assert(world.apply_command("a",_intent(member)).ok)
	for tick in range(45): world.step(0.1)
	assert(not member.task.is_empty()); assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	assert(member.activity_log[0].outcome=="cancelled")
	# The wall face must have a clear reachable position, not the back of the wall.
	var blocker: Dictionary=world._new_object("plant",8,4,0); lot.objects.append(blocker)
	assert(not world.admire_option("a",member.id,lot.id,art_id).ok); _reject("a",_intent(member)); lot.objects.erase(blocker)
	# Queue behind another activity, retain stable titles, then stop if the original leaves.
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":lot.id,"x":8,"y":14}).ok)
	assert(world.apply_command("a",_intent(member)).ok and member.queue.size()==1)
	var visitor: Dictionary=world.state.families.b.members[0]
	assert(world.admire_option("b",visitor.id,lot.id,art_id).message.contains("Visit"))
	assert(world.apply_command("b",{"type":"visit","member_id":visitor.id,"lot_id":lot.id}).ok)
	visitor.needs.fun=20; visitor.needs.comfort=20
	assert(world.apply_command("b",_intent(visitor)).ok)
	assert(world.apply_command("a",{"type":"mail_send","recipient":"b","note":"For your wall","gift":0,"sequence":1,"art_source":"art:"+art_id,"art_id":art_id,"revision":lot.revision}).ok)
	world.step(0.1); assert(visitor.task.is_empty() and visitor.activity_log[0].outcome=="failed" and visitor.activity_log[0].reason.contains("left"))
	_finish(member); assert(member.activity_log[0].outcome=="failed" and member.activity_log[0].title.contains("Quiet harbor"))
	assert(world.state.families.b.mailbox.items[0].art.picture==original.picture)
	# Visits enjoy the same original; starting construction safely recalls visitors.
	_fresh(); visitor=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"visit","member_id":visitor.id,"lot_id":lot.id}).ok)
	assert(world.apply_command("b",_intent(visitor)).ok); _finish(visitor)
	assert(visitor.activity_log[0].outcome=="done" and lot.artworks.size()==1)
	assert(world.apply_command("b",_intent(visitor)).ok)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(visitor.lot_id=="lot_2" and visitor.task.is_empty() and visitor.activity_log[0].outcome=="cancelled")
	_reject("a",_intent(member)); assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	# A vertical wall uses the east-facing viewing spot; no duplicate queue or full-plan bypass.
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"art_hang","lot_id":lot.id,"source":"art:"+art_id,"x":3,"y":9,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	_reject("a",_intent(member))
	var vertical:=_intent(member); vertical.x=3; vertical.y=9
	assert(world.apply_command("a",vertical).ok)
	for tick in range(100):
		world.step(0.1)
		if float(member.task.get("elapsed",0))>0: break
	assert(member.y==9 and member.x in [4,5])
	assert(Facing.direction(Facing.activity(world.state,member),member,{})==Vector2.LEFT)
	_finish(member)
	for count in range(9): assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":lot.id,"x":8,"y":14}).ok)
	_reject("a",vertical); assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"art_store","lot_id":lot.id,"source":"art:"+art_id,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok); _reject("a",vertical)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"art_hang","lot_id":lot.id,"source":"art:"+art_id,"x":8,"y":3,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	# Snapshot with a painting already gone may arrive before the next tick.
	assert(world.apply_command("a",_intent(member)).ok); lot.artworks.erase(art_id)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())))); world.step(0.1)
	assert(member.task.is_empty() and member.activity_log[0].outcome=="failed")
	print("ART_ADMIRATION_PASS"); quit()
