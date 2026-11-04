extends SceneTree
const World = preload("res://game/world.gd")
const Leisure = preload("res://game/shared_leisure.gd")
const Courtesy = preload("res://game/courtesy.gd")
const Status = preload("res://game/activity_status.gd")
const Routines = preload("res://game/routines.gd")
var world: RefCounted
var lot: Dictionary
var stereo: Dictionary
var first: Dictionary
var second: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh(kind: String="stereo") -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for member: Dictionary in world.state.families[owner].members:
			member.autonomy=false; member.needs.fun=0.0
	lot=world.state.lots.lot_1; lot.objects=[]; lot.walls=[]; lot.doors=[]; lot.windows={}
	stereo=world._new_object(kind,8,5,0); lot.objects.append(stereo)
	first=world.state.families.a.members[0]; second=world.state.families.b.members[0]
	world.state.families.a.members[1].x=1; world.state.families.a.members[1].y=13
	assert(world.apply_command("b",{"type":"visit","member_id":second.id,"lot_id":lot.id}).ok)
	first.x=8; first.y=6 if kind=="stereo" else 7; second.x=8; second.y=10
	var here := Vector2i(first.x,first.y)
	for cell: Vector2i in world._interaction_cells(lot,stereo):
		if cell!=here: lot.walls.append([cell.x,cell.y])
	assert(world.apply_command("a",{"type":"interact","member_id":first.id,"lot_id":lot.id,"target_id":stereo.id}).ok)
	world.step(0.1)

func _wait() -> String:
	assert(world.apply_command("b",{"type":"interact","member_id":second.id,"lot_id":lot.id,"target_id":stereo.id}).ok)
	assert(second.task.is_empty() and second.queue.size()==1)
	return second.queue[0].id

func _finish() -> void:
	first.task.remaining=0.01; world.step(0.1)

func _run() -> void:
	for kind: String in Leisure.KINDS:
		_fresh(kind); var pending := _wait(); var previous := Vector2i(first.x,first.y)
		var log_size: int=first.activity_log.size(); _finish()
		assert(first.task.get("courtesy",false) and first.task.automatic and first.queue.is_empty())
		assert(first.action.begins_with("Making room for B") and first.task.path.size()==1 and first.task.path[0]!=[second.x,second.y])
		assert(first.activity_log.size()==log_size+1 and first.activity_log[0].outcome=="done")
		assert(Status.sample(first,lot).detail.contains("short step aside"))
		assert(Routines.capture_plan(first,lot).steps.is_empty() and Routines.capture_plan(first,lot).omitted[0].reason.contains("short step aside"))
		var target := Vector2i(first.task.x,first.task.y)
		assert(previous.distance_to(target)==1 and not world._interaction_cells(lot,stereo).has(target))
		assert(not world._path(lot,Vector2i(second.x,second.y),[previous]).has([target.x,target.y]),"The step leaves the waiter's approach clear")
		var replica := World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
		assert(replica.state.families.a.members[0].task==first.task,"Runtime replicas preserve the accepted step")
		assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
		assert(replica.state.families.a.members[0].task.is_empty() and replica.state.families.a.members[0].activity_log==first.activity_log,"Reloading cancels courtesy without a false manual result")
		var bad: Dictionary=world.snapshot(); bad.families.a.members[0].task.courtesy="yes"
		assert(not replica.restore(bad,true))
		for tick in range(20): world.step(0.1)
		assert(second.task.id==pending and second.task.target_id==stereo.id and second.task.path.is_empty())
		assert(first.task.is_empty() and Vector2i(first.x,first.y)==target and first.activity_log.size()==log_size+1)
	# Nobody waiting, no additional movement. A queued walk retains its ID/order.
	_fresh(); _finish(); assert(first.task.is_empty())
	_fresh(); _wait()
	assert(world.apply_command("a",{"type":"move","member_id":first.id,"lot_id":lot.id,"x":5,"y":8}).ok)
	var queued: String=first.queue[0].id; _finish(); assert(first.task.is_empty() and first.queue[0].id==queued)
	world.step(0.1); assert(first.task.id==queued and not first.task.get("courtesy",false))
	# Direct orders and cancellation interrupt a courtesy step even with autonomy off.
	_fresh(); _wait(); _finish()
	assert(world.apply_command("a",{"type":"move","member_id":first.id,"lot_id":lot.id,"x":5,"y":8}).ok)
	assert(not first.task.get("courtesy",false) and not first.task.get("automatic",false))
	_fresh(); _wait(); _finish(); var position := Vector2i(first.x,first.y)
	assert(world.apply_command("a",{"type":"cancel","member_id":first.id}).ok)
	world.step(0.5); assert(first.task.is_empty() and Vector2i(first.x,first.y)==position)
	# Explicitly cancelling the activity does not trigger unsolicited movement.
	_fresh(); _wait(); assert(world.apply_command("a",{"type":"cancel","member_id":first.id}).ok)
	world.step(0.5); assert(first.task.is_empty() and second.task.is_empty())
	# A blocked destination never teleports a resident or clears the waiter's plan.
	_fresh(); var pending := _wait()
	for direction: Vector2i in World.DIRECTIONS:
		var cell := Vector2i(first.x,first.y)+direction
		if cell!=Vector2i(8,7): lot.walls.append([cell.x,cell.y])
	_finish(); assert(first.task.is_empty() and second.queue[0].id==pending)
	# Recheck a newly accepted route before taking the step; do not collide.
	_fresh(); pending=_wait(); _finish()
	var destination := [first.task.x,first.task.y]
	var passer: Dictionary=world.state.families.a.members[1]
	passer.task={"type":"move","id":"passing","x":destination[0],"y":destination[1],"path":[destination]}
	world.step(0.3)
	assert(first.task.is_empty() and [first.x,first.y]!=destination and second.queue[0].id==pending)
	# Doorways are not parking places; a resident already en route takes precedence.
	_fresh(); _wait()
	lot.doors=[[7,6],[9,6]]; _finish(); assert(first.task.is_empty())
	_fresh()
	assert(world.apply_command("b",{"type":"move","member_id":second.id,"lot_id":lot.id,"x":5,"y":10}).ok)
	assert(world.apply_command("b",{"type":"interact","member_id":second.id,"lot_id":lot.id,"target_id":stereo.id}).ok)
	_finish(); assert(first.task.is_empty(),"A future plan does not make an idle resident move preemptively")
	# Simultaneous finishes use separate accepted destinations and hand off both spots.
	_fresh(); lot.walls=[]
	world.ensure_family("c","C"); world.set_online("c",true)
	var players: Array=[first]
	for owner: String in ["a","b","c"]:
		for resident: Dictionary in world.state.families[owner].members:
			if resident.id==first.id: continue
			resident.autonomy=false; resident.needs.fun=0.0
			if resident.lot_id!=lot.id: assert(world.apply_command(owner,{"type":"visit","member_id":resident.id,"lot_id":lot.id}).ok)
			assert(world.apply_command(owner,{"type":"interact","member_id":resident.id,"lot_id":lot.id,"target_id":stereo.id}).ok)
			players.append(resident)
	for tick in range(80):
		world.step(0.1)
		if Leisure.players(world.state,str(lot.id),str(stereo.id)).size()==4: break
	assert(Leisure.players(world.state,str(lot.id),str(stereo.id)).size()==4 and players[4].task.is_empty() and players[5].task.is_empty())
	for index in range(4): players[index].task.remaining=0.01
	world.step(0.1)
	var destinations: Array=[]
	for index in range(4):
		var actor: Dictionary=players[index]
		if actor.task.get("courtesy",false):
			var cell := Vector2i(actor.task.x,actor.task.y)
			assert(not destinations.has(cell)); destinations.append(cell)
	assert(not destinations.is_empty())
	for tick in range(70):
		world.step(0.1)
		if players[4].task.get("elapsed",0.0)>0.0 and players[5].task.get("elapsed",0.0)>0.0: break
	assert(players[4].task.target_id==stereo.id and players[5].task.target_id==stereo.id)
	assert(Leisure.place(players[4])!=Leisure.place(players[5]))
	# Construction and departure discard the ordinary runtime step safely.
	_fresh(); _wait(); _finish()
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(first.task.is_empty() and second.lot_id=="lot_2" and second.queue.is_empty())
	print("COURTESY_PASS"); quit()
