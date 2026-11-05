extends SceneTree
const World = preload("res://game/world.gd")
const RoomPlan = preload("res://game/room_plan.gd")
var world: RefCounted
var lot: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("owner","Alex"); world.ensure_family("neighbor","Violet")
	lot=world.state.lots.lot_1
	lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.windows={}; lot.objects=[]
	assert(world.apply_command("owner",{"type":"build_begin","lot_id":"lot_1"}).ok)

func _room(rotation: int=0) -> Dictionary:
	return {"type":"build_room","lot_id":"lot_1","x":0,"y":0,"end_x":3,"end_y":3,"rotation":rotation,"revision":lot.revision}

func _run() -> void:
	_fresh()
	var original: Dictionary=world.snapshot()
	var command := _room()
	var plan: Dictionary=RoomPlan.inspect(lot,command,[])
	assert(plan.ok and plan.cost==577 and plan.floors.size()==16 and plan.walls.size()==11 and plan.doors==[[1,3]])
	assert(world.snapshot()==original,"A preview cannot change world state or budget")
	assert(world.apply_command("owner",command).ok)
	assert(lot.funds==12000-577 and lot.build_undo==1 and lot.build_redo==0)
	assert(RoomPlan.is_applied(lot,plan))
	var accepted: Dictionary=world.snapshot()
	assert(not world.apply_command("owner",command).ok and world.snapshot()==accepted,"Stale/replayed room revision cannot charge twice")
	assert(not world.apply_command("owner",_room()).ok and world.snapshot()==accepted,"Already built room is a no-op")
	assert(not world.apply_command("neighbor",_room()).ok and world.snapshot()==accepted,"Other household cannot build a room")
	assert(world.apply_command("owner",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok)
	assert(lot.floors.is_empty() and lot.walls.is_empty() and lot.doors.is_empty() and lot.funds==12000,"One undo restores all pieces and the exact price")
	assert(world.apply_command("owner",{"type":"build_redo","lot_id":lot.id,"revision":lot.revision}).ok)
	assert(RoomPlan.is_applied(lot,plan) and lot.funds==12000-577)
	assert(world.apply_command("owner",{"type":"build_end","lot_id":lot.id}).ok)
	var loaded := World.new()
	assert(loaded.restore(world.snapshot()) and RoomPlan.is_applied(loaded.state.lots.lot_1,plan),"Published room survives a save round-trip")
	for rotation in range(4):
		_fresh(); command=_room(rotation)
		var reversed := command.duplicate(); reversed.x=3; reversed.y=3; reversed.end_x=0; reversed.end_y=0
		assert(RoomPlan.inspect(lot,command,[])==RoomPlan.inspect(lot,reversed,[]),"Either corner order produces the same room")
		assert(world.apply_command("owner",command).ok)
		assert(lot.doors.has([[1,3],[3,1],[1,0],[0,1]][rotation]),"Rotate selects the expected doorway side")
	_fresh()
	lot.doors.append([0,1]); lot.floors.append([0,1])
	plan=RoomPlan.inspect(lot,_room(),[])
	assert(plan.ok and plan.cost==535 and not plan.walls.has([0,1]),"Existing floors and doors are preserved and not charged again")
	assert(world.apply_command("owner",_room()).ok and lot.doors.has([0,1]) and lot.doors.has([1,3]))
	_fresh()
	for bad in [{"end_x":16},{"x":-1},{"y":0.5},{"rotation":4},{"end_x":1},{"end_y":"3"}]:
		command=_room(); command.merge(bad,true)
		original=world.snapshot()
		assert(not world.apply_command("owner",command).ok and world.snapshot()==original,"Malformed rooms fail atomically")
	lot.funds=100
	original=world.snapshot()
	assert(not world.apply_command("owner",_room()).ok and world.snapshot()==original,"Insufficient money cannot partially build")
	_fresh()
	lot.objects.append(world._new_object("plant",0,0,0)); original=world.snapshot()
	assert(not world.apply_command("owner",_room()).ok and world.snapshot()==original,"An obstructed final edge cannot leave partial floors")
	_fresh()
	var member: Dictionary=world.state.families.owner.members[0]
	member.x=0; member.y=0; original=world.snapshot()
	assert(world.apply_command("owner",_room()).ok and Vector2i(member.x,member.y)!=Vector2i.ZERO,"Room building moves sheltered residents aside")
	_fresh(); command=_room(); command.x=7; command.y=12; command.end_x=9; command.end_y=14
	original=world.snapshot()
	assert(not world.apply_command("owner",command).ok and world.snapshot()==original,"Lot entrance stays clear")
	print("ROOMS_PASS")
	quit()
