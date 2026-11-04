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
	print("BUILD_HISTORY_PASS")
	quit()
