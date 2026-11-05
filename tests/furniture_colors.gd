extends SceneTree
const World = preload("res://game/world.gd")
const Colors = preload("res://game/furniture_colors.gd")
const Copy = preload("res://game/room_copy.gd")
const Catalog = preload("res://game/catalog.gd")
var world: RefCounted
var lot: Dictionary
var object: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh(kind: String="bed") -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	lot=world.state.lots.lot_1; lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.windows={}; lot.finishes={"floor":{},"wall":{}}
	for y in range(16):
		for x in range(16): lot.floors.append([x,y])
	object=world._new_object(kind,4,4,0); lot.objects=[object]
	if kind=="stairs":
		lot.storeys={"1":preload("res://game/storeys.gd").empty()}
		lot.storeys["1"].floors=[[4,3]]
	if kind=="garden_bed": object.garden.crop="radish"; object.garden.growth=12.0; object.garden.water=60.0; object.garden.revision=1
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)

func _intent(style: Variant="rose") -> Dictionary:
	return {"type":"recolor","lot_id":lot.id,"object_id":object.id,"style":style,"revision":lot.revision}

func _reject(intent: Dictionary, owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Rejected recoloring cannot change color, funds, IDs, or history")

func _run() -> void:
	for kind: String in Catalog.ITEMS:
		if kind in ["floor","wall","door"]: continue
		assert(Colors.MATERIALS.has(kind),"All furnishings have an explicit recolorable material")
		_fresh(kind)
		var source := object.duplicate(true); var funds: int=lot.funds; var next_id: int=world.state.next_object
		for style: String in ["sage","sky","rose","honey","ink","original"]:
			var previous: Dictionary=object.duplicate(true); var before: Dictionary=world.snapshot(); var intent := _intent(style)
			assert(Colors.inspect(lot,intent).ok and world.snapshot()==before,"Hover preview is pure")
			assert(world.apply_command("a",intent).ok and Colors.at(object)==style and lot.funds==funds and world.state.next_object==next_id)
			var expected := source.duplicate(true); Colors.set_style(expected,style)
			assert(object==expected,"Only the material choice changes; planted crops and stable identity are preserved")
			_reject(intent); _reject(_intent(style))
			assert(world.apply_command("a",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok)
			object=lot.objects[0]; assert(object==previous and lot.funds==funds)
			assert(world.apply_command("a",{"type":"build_redo","lot_id":lot.id,"revision":lot.revision}).ok)
			object=lot.objects[0]; assert(object==expected)
		assert(not object.has("color_style"),"Original restores sparse legacy appearance")
		assert(world.apply_command("a",_intent("ink")).ok)
		var loaded := World.new()
		assert(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
		assert(Colors.at(loaded.state.lots.lot_1.objects[0])=="original","Unfinished color changes obey the existing committed-save boundary")
		assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
		assert(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
		assert(Colors.at(loaded.state.lots.lot_1.objects[0])=="ink")
	_fresh(); _reject(_intent(),"b")
	for style: Variant in [null,3,[],{},"#ff0000","missing"]: _reject(_intent(style))
	for changes: Dictionary in [{"object_id":null},{"object_id":"missing"},{"revision":-1},{"revision":0.5}]:
		var intent := _intent(); intent.merge(changes,true); _reject(intent)
	lot.funds=0; assert(world.apply_command("a",_intent()).ok and lot.funds==0,"Colors are available without a household budget")
	var id: String=object.id
	assert(world.apply_command("a",{"type":"move_object","lot_id":lot.id,"object_id":id,"x":6,"y":6,"rotation":1}).ok)
	assert(Colors.at(object)=="rose" and object.id==id and object.rotation==1)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":lot.id}).ok)
	assert(Colors.at(lot.objects[0])=="original" and lot.objects[0].x==4)
	_reject(_intent())
	# Legacy saves still render their exact original colors; invalid new metadata
	# fails restoration atomically instead of changing a live world.
	_fresh(); var legacy: Dictionary=world.snapshot(); var loaded := World.new()
	assert(loaded.restore(legacy,true))
	assert(Colors.material({},"92aaa6")==Color("92aaa6") and Colors.material({"color_style":"original"},"be7c57",0.2)==Color("be7c57"))
	for style: Variant in [null,7,[],{},"invalid"]:
		var broken := legacy.duplicate(true); broken.lots.lot_1.objects[0].color_style=style
		var previous: Dictionary=loaded.snapshot(); assert(not loaded.restore(broken,true) and loaded.snapshot()==previous)
	# Rotated copies carry only the chosen design, retaining fresh identities.
	for rotation in range(4):
		_fresh(); lot.floors=[]; lot.objects=[]
		assert(world.apply_command("a",{"type":"build_room","lot_id":lot.id,"x":0,"y":0,"end_x":4,"end_y":4,"rotation":0,"revision":lot.revision}).ok)
		assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"sofa","x":1,"y":1}).ok)
		object=lot.objects[0]; assert(world.apply_command("a",_intent("honey")).ok)
		var intent := {"type":"copy_room","lot_id":lot.id,"source_x":2,"source_y":2,"x":9,"y":6,"rotation":rotation,"revision":lot.revision}
		var plan := Copy.inspect(lot,intent,[])
		assert(plan.ok and Colors.at(plan.objects[0])=="honey")
		assert(world.apply_command("a",intent).ok and Copy.is_applied(lot,plan))
		assert(Colors.at(lot.objects[-1])=="honey" and lot.objects[0].id!=lot.objects[-1].id)
	print("FURNITURE_COLORS_PASS"); quit()
