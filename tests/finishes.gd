extends SceneTree
const World = preload("res://game/world.gd")
const Finishes = preload("res://game/finishes.gd")
var world: RefCounted
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	lot=world.state.lots.lot_1
	assert(_edit("build_begin").ok)

func _edit(type: String, extra: Dictionary={}) -> Dictionary:
	var command := {"type":type,"lot_id":"lot_1","revision":lot.revision}; command.merge(extra,true)
	return world.apply_command("a",command)

func _paint(surface: String, finish: String, low: Vector2i, high: Vector2i) -> Dictionary:
	return {"surface":surface,"finish":finish,"x":low.x,"y":low.y,"end_x":high.x,"end_y":high.y}

func _run() -> void:
	_fresh()
	var command := _paint("floor","walnut",Vector2i.ZERO,Vector2i(15,15))
	var plan := Finishes.inspect(lot,command)
	assert(plan.ok and plan.cells.size()==90 and plan.cost==360,"Only existing floor tiles are charged")
	var before: Dictionary=world.snapshot()
	assert(Finishes.at(lot,"floor",4,4)=="oak" and world.state==before,"Preview never mutates the lot")
	assert(_edit("paint",command).ok and lot.funds==11640 and lot.build_undo==1)
	assert(Finishes.at(lot,"floor",4,4)=="walnut","Finishes can change beneath furniture")
	before=world.snapshot()
	assert(not _edit("paint",command).ok and world.state==before,"Repainting unchanged tiles costs nothing and creates no undo edit")
	assert(_edit("build_undo").ok and lot.funds==12000 and lot.finishes.floor.is_empty())
	assert(_edit("build_redo").ok and lot.funds==11640 and lot.finishes.floor.size()==90,"Redo restores the complete decorated area")
	var saved: Dictionary=world.snapshot_for_save()
	assert(saved.lots.lot_1.finishes.floor.is_empty() and saved.lots.lot_1.funds==12000,"An unfinished decorating draft stays out of crash saves")
	assert(_edit("build_end").ok)
	var loaded := World.new()
	saved=world.snapshot_for_save()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(saved))) and loaded.state.lots.lot_1.finishes==lot.finishes,"Committed finishes survive JSON saves")
	assert(_edit("build_begin").ok)
	assert(_edit("paint",_paint("floor","blue_carpet",Vector2i(7,8),Vector2i(5,6))).ok)
	assert(Finishes.at(lot,"floor",5,6)=="blue_carpet" and Finishes.at(lot,"floor",4,6)=="walnut","Reversed corners only affect their selected rectangle")
	assert(_edit("build_cancel").ok and lot.finishes==saved.lots.lot_1.finishes and lot.funds==11640,"Discard restores paint and funds without aliasing nested dictionaries")
	assert(_edit("build_begin").ok)
	assert(_edit("paint",_paint("floor","oak",Vector2i(3,3),Vector2i(12,11))).ok and lot.finishes.floor.is_empty(),"Default finishes use sparse storage too")
	assert(_edit("build_undo").ok and lot.finishes.floor.size()==90)
	# Painted walls are removed exactly when their geometry is removed.
	_fresh()
	assert(_edit("paint",_paint("wall","ink",Vector2i(7,3),Vector2i(7,3))).ok)
	assert(_edit("place",{"kind":"door","x":7,"y":3}).ok and not lot.finishes.wall.has("7,3"))
	assert(_edit("build_undo").ok and Finishes.at(lot,"wall",7,3)=="ink")
	assert(_edit("build_room",{"x":5,"y":1,"end_x":9,"end_y":3,"rotation":0}).ok and not lot.finishes.wall.has("7,3"),"Room doorway replacement removes obsolete paint")
	assert(_edit("build_undo").ok and Finishes.at(lot,"wall",7,3)=="ink")
	assert(_edit("erase",{"x":7,"y":3}).ok and lot.finishes.wall.is_empty())
	assert(_edit("build_undo").ok and Finishes.at(lot,"wall",7,3)=="ink")
	assert(_edit("place",{"kind":"floor","x":1,"y":1}).ok)
	assert(_edit("paint",_paint("floor","slate",Vector2i.ONE,Vector2i.ONE)).ok)
	assert(_edit("erase",{"x":1,"y":1}).ok and not lot.finishes.floor.has("1,1"))
	assert(_edit("build_undo").ok and Finishes.at(lot,"floor",1,1)=="slate")
	# Invalid/unaffordable/stale requests cannot leave partial paint or spend funds.
	_fresh()
	command=_paint("wall","sage",Vector2i(3,3),Vector2i(12,11))
	for patch in [{"surface":"roof"},{"surface":[]},{"finish":"missing"},{"finish":123},{"x":-1},{"end_y":16},{"x":1.5},{"revision":0},{"lot_id":"lot_2"}]:
		var bad: Dictionary=command.duplicate(); bad.merge(patch,true); before=world.snapshot()
		assert(not _edit("paint",bad).ok and world.state==before)
	lot.funds=1; before=world.snapshot()
	assert(not _edit("paint",command).ok and world.state==before)
	assert(not _edit("paint",_paint("floor","slate",Vector2i.ZERO,Vector2i.ONE)).ok)
	_fresh()
	assert(_edit("paint",command).ok)
	var live: Dictionary=world.snapshot()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(live)),true) and loaded.state.lots.lot_1.finishes==lot.finishes,"Clients receive draft decoration")
	world.set_online("a",false)
	assert(lot.finishes.wall.is_empty() and not lot.building,"Disconnect discards unfinished paint")
	var legacy: Dictionary=saved.duplicate(true)
	for home: Dictionary in legacy.lots.values(): home.erase("finishes")
	assert(loaded.restore(legacy) and loaded.state.lots.lot_1.finishes==Finishes.create())
	for corruption in [{"floor":{},"wall":[],},{"floor":{"3,3":"missing"},"wall":{}},{"floor":{"03,3":"slate"},"wall":{}},{"floor":{"0,0":"slate"},"wall":{}},{"floor":{},"wall":{"7,7":"ink"}},{"floor":{},"wall":{},"roof":{}}]:
		var invalid: Dictionary=saved.duplicate(true); invalid.lots.lot_1.finishes=corruption
		before=loaded.snapshot(); assert(not loaded.restore(invalid) and loaded.state==before,"Corrupt finishes must not partially replace a world")
	print("FINISHES_PASS")
	quit()
