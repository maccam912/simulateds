extends SceneTree
const World=preload("res://game/world.gd")
const Clear=preload("res://game/clear_lot.gd")
const Catalog=preload("res://game/catalog.gd")
const Art=preload("res://game/wall_art.gd")
var world: RefCounted
var lot: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet"); world.set_online("a",true)
	lot=world.state.lots.lot_1
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
func _intent() -> Dictionary: return {"type":"clear_lot","lot_id":lot.id,"revision":lot.revision,"refund":Clear.inspect(lot).refund}
func _edit(type: String) -> Dictionary: return world.apply_command("a",{"type":type,"lot_id":lot.id,"revision":lot.revision})
func _reject(command: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); assert(not world.apply_command(owner,command).ok and world.snapshot()==before)
func _run() -> void:
	_fresh(); var before: Dictionary=world.snapshot(); var plan:=Clear.inspect(lot)
	assert(plan.ok and plan.refund==2997 and plan.furniture_refund==1632 and plan.structure_refund==1257 and plan.window_refund==108 and world.snapshot()==before,str(plan))
	var intent:=_intent(); _reject(intent,"b")
	for change: Dictionary in [{"revision":-1},{"revision":0.5},{"refund":null},{"refund":2997.5},{"refund":2998}]:
		var bad:=intent.duplicate(); bad.merge(change,true); _reject(bad)
	assert(world.apply_command("a",intent).ok and Clear.empty(lot) and lot.funds==14997 and lot.build_undo==1)
	assert(world.state.next_object==before.next_object and world.state.families==before.families and lot.building)
	_reject(intent); _reject(_intent())
	assert(_edit("build_undo").ok and lot.objects==before.lots.lot_1.objects and lot.funds==12000)
	assert(_edit("build_redo").ok and Clear.empty(lot) and lot.funds==14997)
	# Allowance and external money survive undo and draft recovery exactly once.
	world.state.day_minutes=1439.5; world.step(1.0)
	assert(lot.funds==15597 and _edit("build_undo").ok and lot.funds==12600)
	assert(_edit("build_redo").ok and lot.funds==15597)
	var disk: Dictionary=world.snapshot_for_save(); var restored:=World.new(); assert(restored.restore(JSON.parse_string(JSON.stringify(disk))))
	assert(restored.state.lots.lot_1.objects==before.lots.lot_1.objects and restored.state.lots.lot_1.funds==12600)
	assert(_edit("build_cancel").ok and lot.objects==before.lots.lot_1.objects and lot.funds==12600)
	assert(not Clear.inspect(lot).ok); _reject(_intent())
	# Original wall art and finished canvases go to the collection; unfinished work blocks clearing.
	_fresh()
	var easel: Dictionary=world._new_object("easel",9,8,0); lot.objects.append(easel)
	easel.painting={"subject":"meadow","progress":12.0,"artists":[{"id":world.state.families.a.members[0].id,"name":"Alex"}],"day":1,"revision":1}
	plan=Clear.inspect(lot); assert(not plan.ok and plan.unfinished.size()==1); _reject(_intent())
	easel.painting.progress=24.0; easel.painting.revision=2
	var picture: Dictionary=easel.painting.duplicate(true); var art_id: String=Art.source(lot,"easel:"+str(easel.id)).art_id
	assert(world.apply_command("a",{"type":"art_hang","lot_id":lot.id,"source":"easel:"+str(easel.id),"x":7,"y":3,"revision":lot.revision}).ok)
	easel.painting=picture.duplicate(true); easel.painting.revision=4
	var on_easel: String=Art.source(lot,"easel:"+str(easel.id)).art_id
	plan=Clear.inspect(lot); assert(plan.ok and plan.stored==1 and plan.paintings.size()==1)
	before=world.snapshot(); assert(world.apply_command("a",_intent()).ok)
	assert(lot.artworks.size()==2 and lot.artworks[art_id]=={"picture":picture,"x":-1,"y":-1} and lot.artworks[on_easel].picture.revision==4)
	assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(_edit("build_undo").ok and lot.artworks==before.lots.lot_1.artworks and lot.objects==before.lots.lot_1.objects)
	assert(_edit("build_redo").ok and lot.artworks.size()==2)
	assert(_edit("build_cancel").ok and lot.artworks.is_empty(),"Discard restores the committed house, including draft-only paintings")
	# Existing artwork remains in the committed crash save and returns on Discard.
	_fresh(); easel=world._new_object("easel",9,8,0); easel.painting=picture.duplicate(true); lot.objects.append(easel)
	assert(_edit("build_end").ok and _edit("build_begin").ok)
	var committed: Dictionary=lot.duplicate(true)
	assert(world.apply_command("a",_intent()).ok and lot.artworks.size()==1)
	assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(restored.state.lots.lot_1.objects==committed.objects and restored.state.lots.lot_1.artworks==committed.artworks)
	assert(_edit("build_cancel").ok and lot.objects==committed.objects and lot.artworks==committed.artworks)
	# No collection overflow, duplicate original, or lost refund can be partially applied.
	_fresh(); easel=world._new_object("easel",9,8,0); easel.painting=picture.duplicate(true); lot.objects.append(easel)
	for index in range(Art.LIMIT): lot.artworks["art_object_"+str(index+1000)+"_1"]={"picture":picture.duplicate(true),"x":-1,"y":-1}
	_reject(_intent()); assert(Clear.inspect(lot).message.contains("collection"))
	lot.artworks={}; lot.funds=1000000000; _reject(_intent())
	lot.funds=1000000000-int(Clear.inspect(lot).refund); assert(world.apply_command("a",_intent()).ok and lot.funds==1000000000)
	# Review names the lost consumables. Undo restores those exact servings and crops.
	_fresh(); world.state.families.a.members[1].y=13; var table: Dictionary=world._new_object("dining_table",8,6,0); lot.objects.append(table)
	table.meal={"recipe":"salad","servings":3,"batch":2,"cook":world.state.families.a.members[0].id,"cook_name":"Alex","day":1}
	var garden: Dictionary=world._new_object("garden_bed",0,0,0); lot.objects.append(garden); garden.garden.crop="radish"; garden.garden.water=60.0; garden.garden.growth=30.0; garden.garden.revision=1
	plan=Clear.inspect(lot); assert(plan.ok and plan.portions==3 and plan.crops==1)
	before=world.snapshot(); assert(world.apply_command("a",_intent()).ok and _edit("build_undo").ok and lot.objects==before.lots.lot_1.objects)
	assert(world.apply_command("a",_intent()).ok and _edit("build_end").ok and not lot.building)
	assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(Clear.empty(restored.state.lots.lot_1))
	# A saved room remains available to rebuild directly on the cleared lot.
	_fresh(); assert(world.apply_command("a",{"type":"blueprint_save","lot_id":lot.id,"source_x":7,"source_y":7,"revision":lot.revision,"library_revision":0,"name":"Starter home"}).ok)
	var library: Dictionary=world.state.families.a.room_library.duplicate(true)
	assert(world.apply_command("a",_intent()).ok and world.state.families.a.room_library==library)
	assert(world.apply_command("a",{"type":"place_blueprint","lot_id":lot.id,"blueprint_id":"room_1","library_revision":1,"x":3,"y":3,"rotation":0,"revision":lot.revision}).ok)
	assert(_edit("build_end").ok and lot.objects.size()==11)
	print("CLEAR_LOT_PASS"); quit()
