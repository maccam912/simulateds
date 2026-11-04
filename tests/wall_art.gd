extends SceneTree
const World = preload("res://game/world.gd")
const Art = preload("res://game/wall_art.gd")
const Paintings = preload("res://game/paintings.gd")
var world: RefCounted
var lot: Dictionary
var easel: Dictionary
var member: Dictionary

func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet"); world.set_online("a",true)
	lot=world.state.lots.lot_1; member=world.state.families.a.members[0]
	for resident: Dictionary in world.state.families.a.members: resident.autonomy=false
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"easel","x":9,"y":9}).ok)
	easel=lot.objects[-1]
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"painting","lot_id":lot.id,"member_id":member.id,"target_id":easel.id,"action":"start","subject":"flowers","revision":0}).ok)
	for step in range(350):
		world.step(0.1)
		if Paintings.finished(easel.painting): break
	assert(Paintings.finished(easel.painting))
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)

func _intent(source: String="",x: int=8,y: int=3) -> Dictionary:
	return {"type":"art_hang","lot_id":lot.id,"source":"easel:"+str(easel.id) if source.is_empty() else source,"x":x,"y":y,"revision":lot.revision}

func _apply(intent: Dictionary) -> Dictionary:
	var before: Dictionary=world.snapshot(); var plan := Art.inspect(lot,intent)
	assert(plan.ok and before==world.snapshot(),str(plan))
	var result: Dictionary=world.apply_command("a",intent)
	assert(result.ok and Art.is_applied(lot,plan),str(result))
	return plan

func _reject(intent: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Rejected transfers cannot lose or duplicate a picture")

func _history(redo: bool=false) -> void:
	assert(world.apply_command("a",{"type":"build_redo" if redo else "build_undo","lot_id":lot.id,"revision":lot.revision}).ok)
	easel=world._object(lot,str(easel.id))

func _run() -> void:
	_fresh()
	var picture: Dictionary=easel.painting.duplicate(true); var funds: int=lot.funds
	for change: Dictionary in [{"x":0},{"x":16},{"x":0.5},{"source":[]},{"source":"art:missing"},{"revision":-1}]:
		var bad := _intent(); bad.merge(change,true); _reject(bad)
	_reject(_intent(),"b")
	var window_cell: PackedStringArray=str(lot.windows.keys()[0]).split(",")
	_reject(_intent("",int(window_cell[0]),int(window_cell[1])))
	var intent := _intent(); var plan := _apply(intent); var id: String=plan.art_id
	assert(lot.artworks.size()==1 and lot.artworks[id].picture==picture and easel.painting.subject=="" and lot.funds==funds)
	_reject(intent); _reject(_intent()); _reject(_intent("art:"+id))
	# An unfinished construction save contains the old canvas, not its draft wall.
	var replica := World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.lots.lot_1.artworks.is_empty() and replica.state.lots.lot_1.objects[-1].painting==picture)
	_history(); assert(lot.artworks.is_empty() and easel.painting==picture and lot.funds==funds)
	_history(true); assert(lot.artworks[id].picture==picture and easel.painting.subject=="")
	_apply(_intent("art:"+id,3,8)); assert(lot.artworks.size()==1 and Art.at(lot,8,3)=="" and Art.at(lot,3,8)==id)
	_history(); assert(Art.at(lot,8,3)==id)
	_apply({"type":"art_store","lot_id":lot.id,"source":"art:"+id,"revision":lot.revision})
	assert(lot.artworks[id].x==-1 and lot.artworks[id].picture==picture)
	_reject({"type":"art_store","lot_id":lot.id,"source":"art:"+id,"revision":lot.revision})
	_apply(_intent("art:"+id,8,3))
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.lots.lot_1.artworks==lot.artworks)
	_reject(_intent("art:"+id,3,8))
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	# Wall removal, a doorway, and fitting a window store art rather than deleting it.
	for command: Dictionary in [{"type":"erase","x":8,"y":3},{"type":"place","kind":"door","x":8,"y":3},{"type":"set_window","style":"picture","x":8,"y":3}]:
		command.lot_id=lot.id; command.revision=lot.revision
		var result: Dictionary=world.apply_command("a",command)
		assert(result.ok and result.message.contains("collection") and lot.artworks[id].x==-1 and lot.artworks[id].picture==picture)
		assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
		_history(); assert(Art.at(lot,8,3)==id and lot.artworks[id].picture==picture)
	# Return preserves the picture while advancing the destination canvas revision.
	var revision: int=easel.painting.revision
	_apply({"type":"art_return","lot_id":lot.id,"source":"art:"+id,"target_id":easel.id,"revision":lot.revision})
	assert(lot.artworks.is_empty() and easel.painting.subject==picture.subject and easel.painting.artists==picture.artists and easel.painting.revision==revision+1)
	_history(); assert(Art.at(lot,8,3)==id and easel.painting.subject=="")
	# A new canvas on the original easel cannot be replaced by returning old art.
	easel.painting=picture.duplicate(true); easel.painting.revision=revision+5
	_reject({"type":"art_return","lot_id":lot.id,"source":"art:"+id,"target_id":easel.id,"revision":lot.revision})
	_reject(_intent("",8,3))
	# A full collection still permits moving, storing, and returning earned work.
	var kept: Dictionary=lot.artworks.duplicate(true)
	for index in range(1,Art.LIMIT): lot.artworks["art_object_%d_2" % (1000+index)]={"picture":picture.duplicate(true),"x":-1,"y":-1}
	assert(Art.valid(lot,world.state.day))
	_reject(_intent("",3,8))
	_apply(_intent("art:"+id,3,8)); _apply({"type":"art_store","lot_id":lot.id,"source":"art:"+id,"revision":lot.revision})
	lot.artworks=kept; easel.painting=Paintings.create()
	_apply({"type":"art_return","lot_id":lot.id,"source":"art:"+id,"target_id":easel.id,"revision":lot.revision})
	assert(lot.artworks.is_empty())
	# Discarding a later draft restores the committed wall and empty easel together.
	_fresh(); plan=_apply(_intent()); id=plan.art_id
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	var committed: Dictionary=lot.artworks.duplicate(true)
	var blank: Dictionary=easel.painting.duplicate(true)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	_apply({"type":"art_return","lot_id":lot.id,"source":"art:"+id,"target_id":easel.id,"revision":lot.revision})
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":lot.id}).ok)
	easel=world._object(lot,str(easel.id))
	assert(lot.artworks==committed and easel.painting==blank and not lot.building)
	# Actual room copies omit all earned art, in every orientation.
	for rotation in range(4):
		_fresh(); picture=easel.painting.duplicate(true)
		lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.objects=[easel]; lot.windows={}; lot.finishes={"floor":{},"wall":{}}
		easel.x=1; easel.y=1
		assert(world.apply_command("a",{"type":"build_room","lot_id":lot.id,"x":0,"y":0,"end_x":3,"end_y":3,"revision":lot.revision}).ok)
		plan=_apply(_intent("",1,0)); id=plan.art_id
		assert(world.apply_command("a",{"type":"copy_room","lot_id":lot.id,"source_x":1,"source_y":1,"x":10,"y":6,"rotation":rotation,"revision":lot.revision}).ok)
		assert(lot.artworks.size()==1 and lot.artworks[id].picture==picture and lot.objects[-1].painting.subject=="")
		_history(); _history(true); assert(lot.artworks.size()==1)
	# Bad save entries are rejected atomically, including floating JSON coordinates.
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	for bad: Variant in [null,[],{"bad":{}},{id:{"picture":picture,"x":1,"y":1}},{id:{"picture":picture,"x":-1,"y":0}}]:
		var corrupt: Dictionary=world.snapshot(); corrupt.lots.lot_1.artworks=bad
		var before: Dictionary=replica.snapshot(); assert(not replica.restore(corrupt,true) and replica.snapshot()==before)
	var corrupt: Dictionary=world.snapshot(); corrupt.lots.lot_1.artworks[id].picture.progress=2.0
	assert(not replica.restore(corrupt,true))
	for position: Array in [[1.5,0],[-1,0],[16,0]]:
		corrupt=world.snapshot(); corrupt.lots.lot_1.artworks[id].x=position[0]; corrupt.lots.lot_1.artworks[id].y=position[1]
		assert(not replica.restore(corrupt,true))
	corrupt=world.snapshot(); corrupt.lots.lot_1.artworks["art_object_999_2"]=corrupt.lots.lot_1.artworks[id].duplicate(true)
	assert(not replica.restore(corrupt,true),"Two frames cannot share a wall")
	corrupt=world.snapshot()
	for index in range(Art.LIMIT): corrupt.lots.lot_1.artworks["art_object_%d_2" % (1000+index)]={"picture":picture.duplicate(true),"x":-1,"y":-1}
	assert(not replica.restore(corrupt,true),"Saved collections must respect the same capacity")
	# Loading old saves adds an empty collection without changing their homes.
	var legacy: Dictionary=world.snapshot()
	for home: Dictionary in legacy.lots.values(): home.erase("artworks")
	assert(replica.restore(legacy,true) and replica.state.lots.lot_1.artworks.is_empty())
	print("WALL_ART_PASS"); quit()
