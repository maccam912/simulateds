extends SceneTree
const World = preload("res://game/world.gd")
const Tabletop = preload("res://game/tabletop.gd")
var world: RefCounted
var member: Dictionary
var companion: Dictionary
var table: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b","c"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false; resident.needs.fun=0.0
	member=world.state.families.a.members[0]; companion=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(world.apply_command("b",{"type":"place","lot_id":"lot_2","kind":"game_table","x":8,"y":5}).ok)
	assert(world.apply_command("b",{"type":"build_end","lot_id":"lot_2"}).ok)
	for object: Dictionary in world.state.lots.lot_2.objects:
		if object.kind=="game_table": table=object
	assert(world.apply_command("b",{"type":"interact","member_id":companion.id,"lot_id":"lot_2","target_id":table.id}).ok)

func _visit() -> void:
	assert(world.apply_command("a",{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)

func _intent() -> Dictionary:
	return {"type":"join_game","member_id":member.id,"lot_id":"lot_2","companion_id":companion.id,"activity_id":companion.task.id}

func _reject(intent: Dictionary, owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Rejected join must leave every plan and resident untouched")

func _run() -> void:
	_fresh()
	var option: Dictionary=world.tabletop_option(member,str(companion.id))
	assert(not option.available and option.label=="Visit to join" and "1/4" in option.summary)
	_reject(_intent())
	_visit()
	var before: Dictionary=world.snapshot()
	option=world.tabletop_option(member,str(companion.id))
	assert(option.available and option.target_id==table.id and world.snapshot()==before,"Discovery is read-only and follows a real active game")
	for key: String in ["companion_id","activity_id"]:
		for invalid: Variant in [null,{},[],12,"missing"]:
			var bad := _intent(); bad[key]=invalid; _reject(bad)
	_reject(_intent(),"b")
	var self_join := _intent(); self_join.companion_id=member.id; _reject(self_join)
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":"lot_2","x":0,"y":14}).ok)
	var current: Dictionary=member.task.duplicate(true); var other_plan: Dictionary=companion.duplicate(true)
	assert(world.apply_command("a",_intent()).ok)
	assert(member.task==current and member.queue.size()==1 and member.queue[0].target_id==table.id and companion==other_plan,"Joining appends to the selected resident's plan without altering a companion")
	assert(world.tabletop_option(member,str(companion.id)).label=="In your plan")
	_reject(_intent())
	for tick in range(110):
		world.step(0.1)
		if member.action=="Playing together": break
	assert(Tabletop.is_shared(world.state,member),"The appended plan actually reaches shared recreation")
	assert(world.tabletop_option(member,str(companion.id)).label=="Playing here")
	_fresh(); _visit()
	var stale := _intent()
	world.apply_command("b",{"type":"cancel","member_id":companion.id})
	assert(world.tabletop_option(member,str(companion.id)).is_empty()); _reject(stale)
	world.apply_command("b",{"type":"interact","member_id":companion.id,"lot_id":"lot_2","target_id":table.id})
	_reject(stale)
	# Four reserved approaches still allow a deliberate waiting order.
	for owner: String in ["b","c"]:
		for resident: Dictionary in world.state.families[owner].members:
			if resident.id==companion.id: continue
			world.apply_command(owner,{"type":"visit","member_id":resident.id,"lot_id":"lot_2"})
			assert(world.apply_command(owner,{"type":"interact","member_id":resident.id,"lot_id":"lot_2","target_id":table.id}).ok)
	assert(world.tabletop_option(member,str(companion.id)).label=="Queue game")
	assert(world.apply_command("a",_intent()).ok and member.task.is_empty() and member.queue.size()==1)
	var pending: String=member.queue[0].id
	world.apply_command("c",{"type":"cancel","member_id":world.state.families.c.members[0].id}); world.step(0.1)
	assert(member.task.id==pending,"The same waiting action acquires a released place")
	_fresh(); _visit()
	for index in range(World.MAX_QUEUE+1): assert(world.apply_command("a",{"type":"move","member_id":member.id,"lot_id":"lot_2","x":0,"y":14}).ok)
	assert(world.tabletop_option(member,str(companion.id)).label=="Plan full"); _reject(_intent())
	_fresh(); _visit()
	for cell: Vector2i in world._interaction_cells(world.state.lots.lot_2,table):
		world.state.lots.lot_2.walls.append([cell.x,cell.y])
	assert(world.tabletop_option(member,str(companion.id)).label=="No path to game"); _reject(_intent())
	_fresh(); _visit(); stale=_intent()
	assert(world.apply_command("b",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(world.tabletop_option(member,str(companion.id)).is_empty()); _reject(stale)
	print("JOIN_GAME_PASS")
	quit()
