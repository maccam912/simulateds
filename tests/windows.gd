extends SceneTree
const World = preload("res://game/world.gd")
const Windows = preload("res://game/windows.gd")
const Rules = preload("res://game/build_rules.gd")
const Room = preload("res://game/room_plan.gd")
const Finishes = preload("res://game/finishes.gd")
var world: RefCounted
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _command(style: Variant,x: Variant=7,y: Variant=3) -> Dictionary:
	return {"type":"set_window","lot_id":"lot_1","style":style,"x":x,"y":y,"revision":lot.revision}

func _reject(command: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,command).ok)
	assert(world.snapshot()==before,"Rejected window work cannot alter the house, funds, or history")

func _history(redo: bool=false) -> void:
	assert(world.apply_command("a",{"type":"build_redo" if redo else "build_undo","lot_id":"lot_1","revision":lot.revision}).ok)

func _run() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	lot=world.state.lots.lot_1
	assert(Windows.valid(lot) and lot.windows.size()==3)
	_reject(_command("cottage"))
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	var original: Dictionary=world.snapshot()
	var topology: Array=[lot.walls.duplicate(true),lot.floors.duplicate(true),lot.doors.duplicate(true)]
	var access: Dictionary=world.build_access(lot)
	var room: Array=Finishes.room_cells(lot,Vector2i(7,7))
	var funds: int=lot.funds
	for style: String in Windows.STYLES:
		var previous := Windows.at(lot,7,3)
		var command := _command(style)
		var before: Dictionary=world.snapshot()
		var plan := Windows.inspect(lot,command)
		assert(plan.ok and world.snapshot()==before)
		assert(world.apply_command("a",command).ok and lot.funds==funds-plan.cost)
		assert(Windows.at(lot,7,3)==style and Windows.valid(lot))
		assert([lot.walls,lot.floors,lot.doors]==topology and Finishes.room_cells(lot,Vector2i(7,7))==room and world.build_access(lot)==access,"Window styles do not change routing or room boundaries")
		assert(not world._walkable(lot,Vector2i(7,3)))
		var after: Dictionary=world.snapshot()
		_reject(_command(style)); _reject(command)
		_history(); assert(Windows.at(lot,7,3)==previous and lot.funds==funds)
		_history(true); assert(Windows.at(lot,7,3)==style and lot.funds==after.lots.lot_1.funds)
		funds=lot.funds
	var removal := Windows.inspect(lot,_command(""))
	assert(removal.ok and removal.cost==-54 and removal.refund==54)
	assert(world.apply_command("a",_command("")).ok and Windows.at(lot,7,3).is_empty() and lot.walls.has([7,3]) and lot.funds==funds+54)
	_history(); assert(Windows.at(lot,7,3)=="shutters" and lot.funds==funds)
	# Erase removes the mounted window first, keeping the structural wall.
	assert(world.apply_command("a",{"type":"erase","lot_id":"lot_1","x":7,"y":3}).ok)
	assert(Windows.at(lot,7,3).is_empty() and lot.walls.has([7,3]) and lot.funds==funds+54)
	_history()
	# Door conversion trades in the window and removes its sparse metadata.
	var doorway := {"type":"place","kind":"door","x":7,"y":3,"lot_id":"lot_1"}
	var preview := Rules.inspect(lot,doorway,[])
	assert(preview.ok and preview.cost==1)
	assert(world.apply_command("a",doorway).ok and lot.funds==funds-1 and lot.doors.has([7,3]) and Windows.at(lot,7,3).is_empty() and Windows.valid(lot))
	_history(); assert(Windows.at(lot,7,3)=="shutters" and lot.funds==funds)
	# An extension's door can replace a windowed wall in one priced history edit.
	var extension := {"type":"build_room","lot_id":"lot_1","x":6,"y":0,"end_x":8,"end_y":3,"rotation":0,"revision":lot.revision}
	var extension_plan := Room.inspect(lot,extension,[])
	assert(extension_plan.ok and extension_plan.remove_walls.has([7,3]) and extension_plan.refund==54)
	assert(world.apply_command("a",extension).ok and lot.funds==funds-extension_plan.cost and Windows.at(lot,7,3).is_empty() and Windows.valid(lot))
	_history(); assert(Windows.at(lot,7,3)=="shutters" and lot.funds==funds)
	# Repainting beneath a window preserves it, and undo keeps both layers exact.
	assert(world.apply_command("a",{"type":"paint","lot_id":"lot_1","surface":"wall","finish":"rose","x":7,"y":3,"end_x":7,"end_y":3,"revision":lot.revision}).ok)
	assert(Windows.at(lot,7,3)=="shutters" and Finishes.at(lot,"wall",7,3)=="rose")
	_history()
	for invalid: Variant in [null,{},[],3,"bogus"]: _reject(_command(invalid))
	for invalid: Variant in [null,{},"7",-1,16,0.5,NAN,INF]: _reject(_command("cottage",invalid,3))
	for position: Vector2i in [Vector2i.ZERO,Vector2i(8,11),Vector2i(7,7)]: _reject(_command("cottage",position.x,position.y))
	_reject(_command("cottage"),"b")
	var stale := _command("cottage"); stale.revision=-1; _reject(stale)
	var saved_funds: int=lot.funds; lot.funds=1
	assert(not Windows.inspect(lot,_command("picture")).ok); _reject(_command("picture"))
	lot.funds=1000000000; _reject(_command("")); lot.funds=saved_funds
	# Every wall receives a matching preview/host decision without aliasing state.
	for y in range(16):
		for x in range(16):
			var trial := World.new(); assert(trial.restore(world.snapshot(),true))
			var command := _command("picture",x,y)
			var plan := Windows.inspect(lot,command)
			assert(trial.apply_command("a",command).ok==plan.ok)
			assert(Windows.valid(trial.state.lots.lot_1))
	assert(Windows.along_x(lot,7,3) and Windows.along_x(lot,7,11) and not Windows.along_x(lot,3,6) and not Windows.along_x(lot,12,6))
	# Committed snapshots keep the old house during construction; discard and
	# disconnect restore its windows too. Live snapshots preserve draft windows.
	var draft := World.new(); assert(draft.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(draft.state.lots.lot_1.windows==lot.windows)
	var crash := World.new(); assert(crash.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(crash.state.lots.lot_1.windows==original.lots.lot_1.windows)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":"lot_1"}).ok)
	assert(lot.windows==original.lots.lot_1.windows and lot.funds==original.lots.lot_1.funds)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",_command("picture")).ok)
	world.set_online("a",false)
	assert(lot.windows==original.lots.lot_1.windows and not lot.building)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",_command("shutters")).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":"lot_1"}).ok)
	assert(crash.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(crash.state.lots.lot_1.windows==lot.windows)
	var legacy: Dictionary=world.snapshot_for_save()
	for home: Dictionary in legacy.lots.values(): home.erase("windows")
	assert(crash.restore(legacy) and crash.state.lots.lot_1.windows.is_empty(),"Old saved homes do not gain decorative purchases")
	for malformed: Variant in [null,[],{"7,3":"unknown"},{"7,7":"picture"},{"07,3":"picture"},{"7,3":{}},{7:"picture"}]:
		var data: Dictionary=world.snapshot_for_save(); data.lots.lot_1.windows=malformed
		var before: Dictionary=crash.snapshot(); assert(not crash.restore(data) and crash.snapshot()==before)
	print("WINDOWS_PASS")
	quit()
