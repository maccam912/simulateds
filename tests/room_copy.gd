extends SceneTree
const World = preload("res://game/world.gd")
const Copy = preload("res://game/room_copy.gd")
const Finishes = preload("res://game/finishes.gd")
const Windows = preload("res://game/windows.gd")
var world: RefCounted
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	lot=world.state.lots.lot_1
	lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.windows={}; lot.objects=[]; lot.finishes=Finishes.create()
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"build_room","lot_id":lot.id,"x":0,"y":0,"end_x":3,"end_y":4,"rotation":0,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"bed","x":1,"y":1}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"plant","x":2,"y":1}).ok)
	assert(world.apply_command("a",{"type":"paint","lot_id":lot.id,"surface":"floor","selection":"room","finish":"blue_carpet","x":2,"y":2,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"paint","lot_id":lot.id,"surface":"wall","finish":"sky","x":0,"y":0,"end_x":3,"end_y":4,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"set_window","lot_id":lot.id,"style":"shutters","x":0,"y":2,"revision":lot.revision}).ok)

func _intent(rotation: int=0) -> Dictionary:
	return {"type":"copy_room","lot_id":lot.id,"source_x":2,"source_y":2,"x":9,"y":6,"rotation":rotation,"revision":lot.revision}

func _reject(intent: Dictionary, owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"An invalid copy cannot allocate IDs, charge money, or leave partial surfaces")

func _run() -> void:
	for rotation in range(4):
		_fresh(); var source := Copy.capture(lot,Vector2i(2,2)); var original: Dictionary=world.snapshot()
		assert(source.ok and source.extent==Vector2i(4,5) and source.objects.size()==2 and source.walls.size()==13 and source.doors.size()==1)
		var intent := _intent(rotation); var plan := Copy.inspect(lot,intent,[])
		assert(plan.ok and world.snapshot()==original and plan.cost==1333 and plan.structure_cost==685 and plan.furniture_cost==495 and plan.finish_cost==63 and plan.window_cost==90,str([plan.ok,plan.message,plan.get("cost")]))
		# Independently follow every old object cell through the quarter turn.
		for index in range(lot.objects.size()):
			var old: Dictionary=lot.objects[index]; var copied: Dictionary=plan.objects[index]
			var transformed: Array=[]
			for cell: Vector2i in world._object_cells(old):
				var rotated := cell
				for turn in range(rotation): rotated=Vector2i((5 if turn%2==0 else 4)-1-rotated.y,rotated.x)
				transformed.append(rotated+Vector2i(9,6))
			for cell: Vector2i in world._object_cells(copied): assert(transformed.has(cell))
		var funds: int=lot.funds; var next_id: int=world.state.next_object; var old_objects: Array=lot.objects.duplicate(true)
		assert(world.apply_command("a",intent).ok and Copy.is_applied(lot,plan) and lot.objects.size()==4)
		assert(lot.funds==funds-plan.cost and lot.objects.slice(0,2)==old_objects and world.state.next_object==next_id+2)
		assert(lot.objects[2].id!=lot.objects[0].id and lot.objects[3].id!=lot.objects[1].id)
		_reject(intent); _reject(_intent(rotation)); _reject(_intent(rotation),"b")
		assert(world.apply_command("a",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok)
		assert(lot.funds==funds and lot.objects==old_objects and lot.floors==original.lots.lot_1.floors and lot.finishes==original.lots.lot_1.finishes and lot.windows==original.lots.lot_1.windows)
		assert(world.apply_command("a",{"type":"build_redo","lot_id":lot.id,"revision":lot.revision}).ok and Copy.is_applied(lot,plan))
		assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
		var loaded := World.new(); assert(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
		assert(Copy.is_applied(loaded.state.lots.lot_1,plan))
	_fresh()
	for changes: Dictionary in [{"rotation":4},{"rotation":0.5},{"source_x":null},{"source_y":16},{"source_x":0,"source_y":0},{"x":14},{"x":-1},{"x":0,"y":0},{"revision":-1}]:
		var intent := _intent(); intent.merge(changes,true); _reject(intent)
	lot.funds=1; _reject(_intent())
	_fresh(); lot.walls.erase([0,1]); assert(not Copy.capture(lot,Vector2i(2,2)).ok); _reject(_intent())
	_fresh(); lot.doors=[]; lot.walls.append([1,4]); assert(not Copy.capture(lot,Vector2i(2,2)).ok)
	_fresh(); world.state.families.a.members[0].x=9; world.state.families.a.members[0].y=6; assert(world.apply_command("a",_intent()).ok)
	_fresh(); world.state.families.a.members[0].x=10; world.state.families.a.members[0].y=7; assert(world.apply_command("a",_intent()).ok)
	# A copy can reuse a clear floor and only pays for missing/changed surfaces.
	_fresh(); lot.floors.append([10,7]); lot.finishes.floor["10,7"]="blue_carpet"
	var reused := Copy.inspect(lot,_intent(),[]); assert(reused.ok and reused.cost==1333-12-4)
	# Enclosing a resident or furnishing elsewhere is a rejected whole placement.
	_fresh(); lot.walls.append([10,11]); lot.walls.append([9,11]); lot.walls.append([11,11]); lot.walls.append([12,11])
	assert(not Copy.inspect(lot,_intent(),[]).ok); _reject(_intent())
	# Copying the design of a planted bed never duplicates its crop or rewards.
	_fresh(); lot.objects.clear(); var bed: Dictionary=world._new_object("garden_bed",1,1,0)
	bed.garden.crop="radish"; bed.garden.growth=90.0; bed.garden.water=60.0; bed.garden.revision=1; bed.garden.harvests=3
	lot.objects.append(bed)
	var plan := Copy.inspect(lot,_intent(),[]); assert(plan.ok and plan.garden)
	assert(world.apply_command("a",_intent()).ok and lot.objects[-1].garden.crop=="" and lot.objects[-1].garden.harvests==0 and lot.objects[0].garden.crop=="radish")
	# A concave room copies its real shape, not an enclosing rectangle of tiles.
	_fresh(); lot.objects=[]; lot.floors=[]; lot.walls=[]; lot.doors=[[1,4]]; lot.windows={}; lot.finishes=Finishes.create()
	var inside := [Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(1,2),Vector2i(1,3)]
	var edge := {}
	for cell: Vector2i in inside:
		lot.floors.append([cell.x,cell.y])
		for y in range(-1,2):
			for x in range(-1,2):
				var neighbor := cell+Vector2i(x,y)
				if not inside.has(neighbor): edge[neighbor]=true
	for cell: Vector2i in edge:
		lot.floors.append([cell.x,cell.y])
		if not lot.doors.has([cell.x,cell.y]): lot.walls.append([cell.x,cell.y])
	var irregular := _intent(); irregular.source_x=1; irregular.source_y=1
	plan=Copy.inspect(lot,irregular,[])
	assert(plan.ok and plan.interior.size()==5 and not plan.floors.has([13,10]))
	assert(world.apply_command("a",irregular).ok and Copy.is_applied(lot,plan))
	print("ROOM_COPY_PASS"); quit()
