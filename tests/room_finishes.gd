extends SceneTree
const World = preload("res://game/world.gd")
const Finishes = preload("res://game/finishes.gd")
var world: RefCounted
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	lot=world.state.lots.lot_1
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)

func _command(finish: String="slate", x: int=7, y: int=7) -> Dictionary:
	return {"type":"paint","lot_id":lot.id,"revision":lot.revision,"surface":"floor","selection":"room","finish":finish,"x":x,"y":y}

func _edit(type: String, fields: Dictionary={}) -> Dictionary:
	var command := {"type":type,"lot_id":lot.id,"revision":lot.revision}; command.merge(fields,true)
	return world.apply_command("a",command)

func _reject(command: Dictionary, owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,command).ok and world.snapshot()==before,"Rejected decoration never charges, paints, or creates history")

func _run() -> void:
	_fresh()
	var before: Dictionary=world.snapshot(); var command := _command()
	var plan := Finishes.inspect(lot,command)
	assert(plan.ok and plan.area.size()==56 and plan.cost==224 and world.snapshot()==before)
	assert([4,4] in plan.cells and [8,11] not in plan.area and [3,3] not in plan.area,"Furniture does not divide a floor; walls and doorways do")
	assert(Finishes.room_cells(lot,Vector2i(4,4))==plan.area,"Any seed in the room gives the same ordered region")
	assert(world.apply_command("a",command).ok and lot.funds==11776 and lot.finishes.floor.size()==56 and lot.build_undo==1)
	assert(Finishes.at(lot,"floor",4,4)=="slate" and Finishes.at(lot,"floor",8,11)=="oak")
	var no_change := Finishes.inspect(lot,_command())
	assert(not no_change.ok and no_change.reason=="unchanged" and no_change.cost==0 and no_change.area.size()==56)
	_reject(_command()); _reject(command)
	assert(_edit("build_undo").ok and lot.finishes.floor.is_empty() and lot.funds==12000)
	assert(_edit("build_redo").ok and lot.finishes.floor.size()==56 and lot.funds==11776)
	assert(world.snapshot_for_save().lots.lot_1.finishes.floor.is_empty(),"An unfinished room finish stays out of crash saves")
	assert(_edit("build_end").ok)
	var loaded := World.new(); assert(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(loaded.state.lots.lot_1.finishes==lot.finishes,"Committed room decoration uses ordinary compatible finish storage")
	assert(_edit("build_begin").ok)
	assert(world.apply_command("a",_command("oak")).ok and lot.finishes.floor.is_empty(),"Returning to the default finish clears sparse overrides")
	assert(_edit("build_cancel").ok and lot.finishes.floor.size()==56)
	# A connected extension is distinct until its doorway threshold is removed.
	_fresh()
	assert(_edit("build_room",{"x":3,"y":11,"end_x":7,"end_y":15,"rotation":2}).ok)
	var extension := _command("rose_carpet",5,13)
	plan=Finishes.inspect(lot,extension)
	assert(plan.ok and plan.area.size()==9 and plan.cost==36)
	assert(_edit("place",{"kind":"bed","x":4,"y":12}).ok)
	extension=_command("rose_carpet",5,13); plan=Finishes.inspect(lot,extension)
	assert(plan.area.size()==9 and [4,12] in plan.cells)
	assert(world.apply_command("a",extension).ok and Finishes.at(lot,"floor",7,7)=="oak")
	assert(_edit("erase",{"x":5,"y":11}).ok)
	plan=Finishes.inspect(lot,_command("walnut",5,13))
	assert(plan.ok and plan.area.size()==66 and plan.cost==264,"An open connection joins the visible floor regions, including its former threshold")
	var objects: Array=lot.objects.duplicate(true)
	assert(world.apply_command("a",_command("walnut",5,13)).ok and lot.objects==objects)
	# Partial matching finishes charge only the tiles that really change.
	_fresh()
	assert(_edit("paint",{"surface":"floor","finish":"slate","x":4,"y":4,"end_x":5,"end_y":5}).ok)
	plan=Finishes.inspect(lot,_command()); assert(plan.area.size()==56 and plan.cells.size()==52 and plan.cost==208)
	lot.funds=1; plan=Finishes.inspect(lot,_command())
	assert(not plan.ok and plan.reason=="funds" and plan.area.size()==56 and plan.cost==208,"An unaffordable preview retains its region and exact price")
	_reject(_command())
	_fresh()
	for patch: Dictionary in [{"selection":null},{"selection":[]},{"selection":"all"},{"surface":"wall"},{"x":-1},{"y":16},{"x":0.5},{"x":8,"y":11},{"x":3,"y":3},{"x":0,"y":0}]:
		command=_command(); command.merge(patch,true); _reject(command)
	_reject(_command(),"b")
	command=_command(); assert(_edit("place",{"kind":"floor","x":0,"y":0}).ok); _reject(command)
	# Missing floor, diagonal contact, and door cells are explicit boundaries.
	var simple := {"floors":[[0,0],[1,0],[1,1],[2,2]],"walls":[],"doors":[],"objects":[],"funds":100}
	assert(Finishes.room_cells(simple,Vector2i.ZERO)==[[0,0],[1,0],[1,1]])
	simple.doors=[[1,0]]; assert(Finishes.room_cells(simple,Vector2i.ZERO)==[[0,0]])
	simple.doors=[]; simple.floors.erase([1,0]); assert(Finishes.room_cells(simple,Vector2i.ZERO)==[[0,0]])
	var region := Finishes.room_cells(simple,Vector2i.ZERO); region[0][0]=9
	assert(simple.floors[0]==[0,0],"Preview arrays do not alias live floor geometry")
	print("ROOM_FINISHES_PASS")
	quit()
