extends SceneTree
const World = preload("res://game/world.gd")
const Leisure = preload("res://game/shared_leisure.gd")
var world: RefCounted
var lot: Dictionary
var stereo: Dictionary
var first: Dictionary
var second: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1; lot.objects=[]; lot.walls=[]; lot.doors=[]; lot.windows={}
	stereo=world._new_object("stereo",8,5,0); lot.objects.append(stereo)
	first=world.state.families.a.members[0]; second=world.state.families.a.members[1]
	for member: Dictionary in [first,second]: member.autonomy=false; member.needs.fun=0.0
	first.x=8; first.y=6; second.x=8; second.y=8

func _states(report: Dictionary, status: String) -> Array:
	return report.cells.filter(func(cell): return cell.status==status)

func _run() -> void:
	_fresh()
	var before: Dictionary=world.snapshot()
	var layout := Leisure.spaces({},lot,stereo)
	assert(layout.capacity==4 and layout.available.size()==4 and world.snapshot()==before)
	lot.walls=[[7,5],[9,5],[8,4]]
	layout=Leisure.spaces({},lot,stereo)
	assert(layout.capacity==1 and _states(layout,"blocked").size()==3 and Leisure.layout_text(layout).contains("Solo only"))
	assert(world.apply_command("a",{"type":"interact","member_id":first.id,"lot_id":lot.id,"target_id":stereo.id}).ok)
	var report := Leisure.spaces(world.state,lot,stereo,second)
	assert(report.capacity==1 and report.reserved==1 and report.available.is_empty())
	assert(_states(report,"reserved").size()==1 and Leisure.waiting_reason(report).contains("Only one usable place"))
	assert(world.leisure_option(second,first.id).label=="Queue dance" and world.leisure_option(second,first.id).summary.contains("1 of 1"))
	assert(world.apply_command("a",{"type":"join_dance","member_id":second.id,"lot_id":lot.id,"companion_id":first.id,"activity_id":first.task.id}).ok)
	assert(second.task.is_empty() and second.action.contains("Only one usable place"))
	var pending: String=second.queue[0].id
	# Cancelling releases a reservation, but a resident standing there still uses space.
	assert(world.apply_command("a",{"type":"cancel","member_id":first.id}).ok)
	report=Leisure.spaces(world.state,lot,stereo,second)
	assert(report.reserved==0 and report.available.is_empty() and _states(report,"occupied").size()==1)
	world.step(0.1); assert(second.action.contains("Someone is standing"))
	assert(world.apply_command("a",{"type":"move","member_id":first.id,"lot_id":lot.id,"x":6,"y":7}).ok)
	for tick in range(12): world.step(0.1)
	assert(second.task.id==pending and second.task.target_id==stereo.id)
	# Selected participants also see their own place marked as reserved.
	report=Leisure.spaces(world.state,lot,stereo,second)
	assert(_states(report,"reserved").size()==1)
	var replica := World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(Leisure.spaces(replica.state,replica.state.lots.lot_1,replica.state.lots.lot_1.objects[0],replica.state.families.a.members[1])==report)
	# A floor tile is not a usable place when a wall separates it from the entrance.
	_fresh(); lot.walls=[[7,4],[8,3],[9,4]]
	layout=Leisure.spaces({},lot,stereo)
	assert(layout.capacity==3 and _states(layout,"unreachable").size()==1)
	# Layout ignores sheltered residents during construction, and rotations follow footprints.
	for kind: String in Leisure.KINDS:
		for rotation in range(4):
			_fresh(); stereo.kind=kind; stereo.rotation=rotation
			before=world.snapshot(); report=Leisure.spaces(world.state,lot,stereo,second)
			for cell: Dictionary in report.cells:
				var reachable: bool=world._walkable(lot,cell.cell) and (cell.cell==Vector2i(second.x,second.y) or not world._path(lot,Vector2i(second.x,second.y),[cell.cell]).is_empty())
				assert(reachable==(cell.status in ["open","reserved","occupied"]))
			assert(world.snapshot()==before)
	# Adjacent activities reserve future places before either participant arrives.
	_fresh(); var other: Dictionary=world._new_object("stereo",8,7,0); lot.objects.append(other)
	first.x=7; first.y=6
	assert(world.apply_command("a",{"type":"interact","member_id":first.id,"lot_id":lot.id,"target_id":stereo.id}).ok)
	assert(world.apply_command("a",{"type":"interact","member_id":second.id,"lot_id":lot.id,"target_id":other.id}).ok)
	report=Leisure.spaces(world.state,lot,stereo)
	assert(Leisure.place(first)!=Leisure.place(second) and _states(report,"reserved").size()>=1)
	print("SHARED_SPACES_PASS"); quit()
