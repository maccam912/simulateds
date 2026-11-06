extends SceneTree
const World = preload("res://game/world.gd")
const Art = preload("res://game/paintings.gd")
const Status = preload("res://game/activity_status.gd")
var world: RefCounted
var lot: Dictionary
var easel: Dictionary
var member: Dictionary

func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members: resident.autonomy=false
	lot=world.state.lots.lot_1; member=world.state.families.a.members[0]
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"easel","x":9,"y":9,"rotation":0}).ok)
	easel=lot.objects[-1]
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	# Exact progress assertions start at the canvas-side interaction cell.
	member.x=9; member.y=10

func _order(action: Variant,subject: Variant="",resident: Dictionary={}) -> Dictionary:
	if resident.is_empty(): resident=member
	return world.apply_command("a",{"type":"painting","lot_id":lot.id,"target_id":easel.id,"member_id":resident.id,"action":action,"subject":subject,"revision":easel.painting.revision})

func _finish(resident: Dictionary={}) -> void:
	if resident.is_empty(): resident=member
	for index in range(400):
		world.step(0.1)
		if resident.task.is_empty() and resident.queue.is_empty(): return
	assert(false,"Painting plan should finish")

func _run() -> void:
	_fresh()
	var funds: int=lot.funds
	var initial: Dictionary=world.snapshot()
	for args: Array in [["start","bad"],["start",[]],["resume",""],["sell",""],[null,""]]:
		assert(not _order(args[0],args[1]).ok and world.snapshot()==initial)
	assert(not world.apply_command("a",{"type":"interact","lot_id":lot.id,"member_id":member.id,"target_id":easel.id}).ok)
	member.needs.fun=100.0; member.needs.comfort=100.0
	assert(_order("start","meadow").ok)
	assert(not _order("start","flowers").ok,"Duplicate requests cannot replace or double-book a canvas")
	world.step(1.0)
	assert(easel.painting.subject=="meadow" and easel.painting.progress==1.0 and easel.painting.artists[0].id==member.id)
	assert(Status.sample(member,lot).remaining>20.0,"Full needs cannot shorten creative work")
	for index in range(6): world.step(1.0)
	assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	var unfinished: Dictionary=easel.painting.duplicate(true)
	assert(unfinished.progress==7.0 and lot.funds==funds and member.wishes.journal.is_empty())
	for index in range(20): world.step(1.0)
	assert(easel.painting==unfinished,"Unattended canvases wait")
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.lots.lot_1.objects[-1].painting==unfinished)
	var housemate: Dictionary=world.state.families.a.members[1]
	housemate.needs.fun=10.0; housemate.needs.comfort=10.0
	assert(_order("resume","",housemate).ok); _finish(housemate)
	assert(Art.finished(easel.painting) and easel.painting.artists.size()==2 and easel.painting.day==world.state.day)
	assert(housemate.needs.fun>80 and housemate.needs.comfort>30,"Creative work restores both promised needs")
	assert(housemate.wishes.journal.size()==1 and housemate.wishes.journal[0].text.contains("Morning meadow"))
	assert(lot.funds==funds and not _order("start","harbor").ok and not _order("resume").ok)
	var finished: Dictionary=easel.painting.duplicate(true)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(replica.state.lots.lot_1.objects[-1].painting==finished)
	# Movement, colors, history, and discard retain the original artwork.
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(not _order("sell").ok)
	assert(world.apply_command("a",{"type":"move_object","lot_id":lot.id,"object_id":easel.id,"x":5,"y":9,"rotation":1,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"recolor","lot_id":lot.id,"object_id":easel.id,"style":"sage","revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"build_redo","lot_id":lot.id,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":lot.id}).ok)
	easel=world._object(lot,str(easel.id)); assert(easel.painting==finished and easel.x==9 and easel.y==9)
	# Visitors can inspect but cannot act on someone else's painting.
	var guest: Dictionary=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":lot.id}).ok)
	assert(not world.apply_command("b",{"type":"painting","member_id":guest.id,"lot_id":lot.id,"target_id":easel.id,"action":"sell","revision":easel.painting.revision}).ok)
	assert(not world.apply_command("b",{"type":"painting","member_id":member.id,"lot_id":lot.id,"target_id":easel.id,"action":"sell","revision":easel.painting.revision}).ok)
	assert(_order("sell").ok); world.step(0.1)
	assert(world.task_activity(member.task,str(lot.id))=="" and world.care_status(member,"fun")=="","Packing a picture does not promise need restoration")
	member.needs.fun=10.0
	assert(preload("res://game/resident_cues.gd").need(member,lot,world.state).need=="fun","Packing cannot suppress an unmet-need cue")
	assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	assert(easel.painting==finished and lot.funds==funds,"Canceling a sale keeps the picture and pays nothing")
	lot.funds=1000000000; assert(_order("sell").ok); _finish()
	assert(easel.painting==finished and lot.funds==1000000000,"A rejected payment must keep the picture")
	lot.funds=funds
	assert(_order("sell").ok); _finish()
	assert(easel.painting.subject=="" and lot.funds==funds+Art.VALUE)
	assert(not _order("sell").ok,"A completed sale cannot pay twice")
	for subject: String in ["harbor","flowers"]:
		assert(_order("start",subject).ok); _finish()
		assert(Art.finished(easel.painting) and easel.painting.subject==subject)
		assert(_order("sell").ok); _finish()
	# Saving while active preserves the picture, but never restores a paid task.
	assert(_order("start","flowers").ok)
	for index in range(80):
		world.step(0.1)
		if float(easel.painting.progress)>2: break
	assert(float(easel.painting.progress)>2)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(replica.state.families.a.members[0].task.paint_action=="resume")
	for change: Dictionary in [{"automatic":true},{"paint_revision":-1},{"paint_action":"unknown"},{"subject":"harbor"}]:
		var corrupt: Dictionary=world.snapshot(); corrupt.families.a.members[0].task.merge(change,true)
		assert(not replica.restore(corrupt))
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.families.a.members[0].task.is_empty() and is_equal_approx(replica.state.lots.lot_1.objects[-1].painting.progress,easel.painting.progress))
	world.set_online("a",false); unfinished=easel.painting.duplicate(true)
	for index in range(200): world.step(0.1)
	assert(easel.painting==unfinished,"Absent families do not create or sell artwork")
	world.set_online("a",true)
	var old_revision: int=easel.painting.revision
	assert(not world.apply_command("a",{"type":"painting","member_id":member.id,"lot_id":lot.id,"target_id":easel.id,"action":"resume","revision":old_revision-1}).ok)
	# Corrupted persistent data is rejected atomically.
	for bad: Variant in [null,{},[],{"subject":"unknown","progress":4.0,"artists":[],"day":0,"revision":1}]:
		var corrupt: Dictionary=world.snapshot(); corrupt.lots.lot_1.objects[-1].painting=bad
		var before: Dictionary=replica.snapshot(); assert(not replica.restore(corrupt) and replica.snapshot()==before)
	for change: Dictionary in [{"progress":-1.0},{"progress":25.0},{"progress":NAN},{"day":999},{"artists":[{"id":"a","name":"bad\nname"}]},{"revision":-1}]:
		var corrupt: Dictionary=world.snapshot(); corrupt.lots.lot_1.objects[-1].painting.merge(change,true)
		assert(not replica.restore(corrupt))
	# Copies create new blank canvases, never duplicate art or its resale reward.
	_fresh(); assert(_order("start","meadow").ok); _finish()
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	var copied: Dictionary=preload("res://game/room_copy.gd").capture(lot,Vector2i(9,9))
	assert(copied.ok and copied.art)
	for object: Dictionary in copied.objects: assert(not object.has("painting"))
	var fresh: Dictionary=world._new_object("easel",0,0,0); assert(fresh.painting==Art.create())
	for rotation in range(4):
		_fresh(); assert(_order("start","harbor").ok); _finish()
		var original: Dictionary=easel.duplicate(true)
		lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.objects=[]; lot.windows={}; lot.finishes={"floor":{},"wall":{}}
		assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
		assert(world.apply_command("a",{"type":"build_room","lot_id":lot.id,"x":0,"y":0,"end_x":3,"end_y":3,"revision":lot.revision}).ok)
		original.x=1; original.y=1; original.color_style="sage"; lot.objects.append(original)
		assert(world.apply_command("a",{"type":"copy_room","lot_id":lot.id,"source_x":1,"source_y":1,"x":10,"y":6,"rotation":rotation,"revision":lot.revision}).ok)
		assert(lot.objects[0]==original and lot.objects[-1].id!=original.id and lot.objects[-1].painting==Art.create() and lot.objects[-1].color_style=="sage")
		assert(world.apply_command("a",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok and lot.objects==[original])
		assert(world.apply_command("a",{"type":"build_redo","lot_id":lot.id,"revision":lot.revision}).ok and lot.objects[-1].painting==Art.create())
		assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
		assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	_fresh()
	for cell: Array in [[8,9],[10,9],[9,8],[9,10]]: lot.walls.append(cell)
	var inaccessible: Dictionary=world.snapshot()
	assert(not _order("start","meadow").ok and world.snapshot()==inaccessible,"An unreachable easel cannot acquire a canvas or plan")
	var legacy := World.new(); legacy.initialize(); legacy.ensure_family("old","Old")
	assert(replica.restore(legacy.snapshot()),"Old homes without an easel still load")
	print("PAINTINGS_PASS"); quit()
