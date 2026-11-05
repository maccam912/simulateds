extends SceneTree
const World = preload("res://game/world.gd")
var world = World.new()
var lot: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _edit(type: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"type":type,"lot_id":"lot_1","revision":lot.revision}
	command.merge(extra,true)
	return world.apply_command("builder",command)

func _run() -> void:
	world.initialize(); world.ensure_family("builder","Alex"); world.set_online("builder",true)
	world.ensure_family("neighbor","Violet")
	lot=world.state.lots.lot_1
	var initial: Dictionary=lot.duplicate(true)
	assert(_edit("build_begin").ok)
	assert(_edit("place",{"kind":"floor","x":1,"y":1}).ok)
	assert(_edit("place",{"kind":"plant","x":1,"y":1}).ok)
	var object_id: String=lot.objects.back().id
	assert(lot.funds==initial.funds-57 and lot.build_undo==2)
	var revision: int=lot.revision
	assert(_edit("build_undo").ok)
	assert(world._object(lot,object_id).is_empty() and lot.funds==initial.funds-12)
	assert(not _edit("build_undo",{"revision":revision}).ok,"Stale undo must not remove another edit")
	assert(lot.build_undo==1 and lot.build_redo==1)
	assert(not _edit("place",{"kind":"floor","x":1,"y":1}).ok)
	assert(lot.build_redo==1,"Rejected edit must preserve redo")
	assert(_edit("build_redo").ok)
	assert(world._object(lot,object_id).id==object_id and lot.funds==initial.funds-57,"Redo restores exact object identity and cost")
	assert(not world.apply_command("neighbor",{"type":"build_undo","lot_id":"lot_1","revision":lot.revision}).ok)
	assert(_edit("erase",{"x":1,"y":1}).ok)
	assert(lot.funds==initial.funds-30)
	assert(_edit("build_undo").ok)
	assert(lot.funds==initial.funds-57 and not world._object(lot,object_id).is_empty(),"Undo sale reverses refund without charging retail price")
	world.state.day_minutes=1439.5
	world.step(1.0)
	assert(_edit("build_undo").ok)
	assert(lot.funds==initial.funds+600-12,"Undo preserves midnight allowance")
	assert(_edit("build_redo").ok)
	assert(lot.funds==initial.funds+600-57,"Redo preserves midnight allowance")
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(replica.state.lots.lot_1.build_undo==2,"Clients receive available history counts")
	var saved: Dictionary=world.snapshot_for_save()
	assert(saved.lots.lot_1.build_undo==0 and saved.lots.lot_1.build_redo==0)
	assert(saved.lots.lot_1.funds==initial.funds+600 and saved.lots.lot_1.objects==initial.objects,"Crash save contains committed home and allowance")
	assert(_edit("build_cancel").ok)
	assert(lot.funds==initial.funds+600 and lot.objects==initial.objects)
	assert(lot.build_undo==0 and lot.build_redo==0)
	assert(_edit("build_begin").ok)
	assert(_edit("place",{"kind":"floor","x":1,"y":1}).ok)
	assert(_edit("build_undo").ok)
	assert(_edit("place",{"kind":"floor","x":1,"y":2}).ok)
	assert(lot.build_redo==0 and not _edit("build_redo").ok,"New edit branches history")
	assert(_edit("build_cancel").ok)
	assert(_edit("build_begin").ok)
	for index in range(40):
		assert(_edit("place",{"kind":"floor","x":int(index/16),"y":index%16}).ok)
	assert(lot.build_undo==World.MAX_BUILD_HISTORY,"History is bounded")
	for index in range(World.MAX_BUILD_HISTORY): assert(_edit("build_undo").ok)
	assert(not _edit("build_undo").ok)
	assert(_edit("build_cancel").ok)
	assert(lot.floors==initial.floors and lot.funds==initial.funds+600,"Discard restores entire draft beyond history limit")
	assert(_edit("build_begin").ok)
	assert(_edit("place",{"kind":"floor","x":1,"y":1}).ok)
	assert(_edit("build_end").ok)
	assert(lot.build_undo==0 and not _edit("build_undo").ok,"History cannot undo a published house")
	# Moving is a free edit, with the same rules used by the preview.
	assert(_edit("build_begin").ok)
	var sofa: Dictionary={}
	for object: Dictionary in lot.objects:
		if object.kind=="sofa": sofa=object
	var before_move: Dictionary=sofa.duplicate()
	var funds_before: int=lot.funds
	var new_object_before: int=world.state.next_object
	assert(_edit("move_object",{"object_id":sofa.id,"x":5,"y":8,"rotation":1}).ok,"Move may overlap its own previous footprint")
	assert(lot.funds==funds_before and world.state.next_object==new_object_before,"Rearranging costs nothing and preserves identity")
	assert(int(sofa.x)==5 and int(sofa.rotation)==1)
	var snapshot_before: Dictionary=world.snapshot()
	assert(not _edit("move_object",{"object_id":sofa.id,"x":11,"y":6,"rotation":1}).ok,"Occupied move rejected")
	assert(world.snapshot()==snapshot_before,"Rejected move is atomic")
	assert(_edit("build_undo").ok)
	assert(world._object(lot,str(sofa.id))==before_move,"Undo restores original furnishing placement")
	assert(_edit("build_redo").ok)
	assert(int(world._object(lot,str(sofa.id)).rotation)==1)
	var Rules = preload("res://game/build_rules.gd")
	var preview_before: Dictionary=world.snapshot()
	assert(not Rules.inspect(lot,{"type":"place","kind":"bed","x":0,"y":0,"rotation":0},[]).ok,"Preview rejects missing floor")
	assert(not Rules.inspect(lot,{"type":"place","kind":"bed","x":15,"y":15,"rotation":0},[]).ok,"Preview rejects footprint beyond lot")
	assert(not Rules.inspect(lot,{"type":"move_object","object_id":sofa.id,"x":8,"y":11,"rotation":0},[]).ok,"Preview protects doorway")
	assert(Rules.inspect(lot,{"type":"place","kind":"plant","x":9,"y":9,"rotation":0},[Vector2i(9,9)]).ok,"Sheltered residents never block building")
	assert(Rules.inspect(lot,{"type":"place","kind":"plant","x":9,"y":9,"rotation":0},[]).ok,"Preview accepts clear floor")
	var empty_wallet: Dictionary=lot.duplicate(true); empty_wallet.funds=0
	assert(not Rules.inspect(empty_wallet,{"type":"place","kind":"plant","x":9,"y":9,"rotation":0},[]).ok,"Preview reflects household funds")
	assert(Rules.inspect(empty_wallet,{"type":"move_object","object_id":sofa.id,"x":4,"y":8,"rotation":0},[]).ok,"Moving needs no funds")
	assert(world.snapshot()==preview_before,"Preview never mutates world or budget")
	assert(not world.apply_command("neighbor",{"type":"move_object","lot_id":"lot_1","object_id":sofa.id,"x":4,"y":8,"rotation":0}).ok,"Only owner rearranges")
	assert(_edit("build_cancel").ok)
	print("BUILD_HISTORY_PASS")
	quit()
