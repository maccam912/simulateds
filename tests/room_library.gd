extends SceneTree
const World=preload("res://game/world.gd")
const Library=preload("res://game/room_library.gd")
const Copy=preload("res://game/room_copy.gd")
var world: RefCounted
var lot: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	lot=world.state.lots.lot_1
	lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.objects=[]; lot.windows={}; lot.finishes={"floor":{},"wall":{}}
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"build_room","lot_id":lot.id,"x":0,"y":0,"end_x":3,"end_y":4,"rotation":0,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"bed","x":1,"y":1}).ok)
	assert(world.apply_command("a",{"type":"recolor","lot_id":lot.id,"object_id":lot.objects[0].id,"style":"rose","revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"plant","x":2,"y":1}).ok)
	assert(world.apply_command("a",{"type":"paint","lot_id":lot.id,"surface":"floor","selection":"room","finish":"blue_carpet","x":2,"y":2,"revision":lot.revision}).ok)
	assert(world.apply_command("a",{"type":"set_window","lot_id":lot.id,"style":"shutters","x":0,"y":2,"revision":lot.revision}).ok)
func _board() -> Dictionary: return world.state.families.a.room_library
func _save() -> Dictionary: return {"type":"blueprint_save","lot_id":lot.id,"source_x":2,"source_y":2,"name":"Quiet room","revision":lot.revision,"library_revision":_board().revision}
func _place(rotation: int=0) -> Dictionary: return {"type":"place_blueprint","lot_id":lot.id,"blueprint_id":_board().entries[0].id,"library_revision":_board().revision,"x":9,"y":6,"rotation":rotation,"revision":lot.revision}
func _reject(command: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); var result: Dictionary=world.apply_command(owner,command)
	assert(not result.ok and world.snapshot()==before,str(result))
func _run() -> void:
	for rotation in range(4):
		_fresh(); var before: Dictionary=world.snapshot(); var save:=_save()
		assert(world.apply_command("a",save).ok and Library.valid(_board()))
		assert(lot==before.lots.lot_1 and world.state.next_object==before.next_object and _board().entries.size()==1)
		_reject(save); _reject(_save(),"b")
		var design: Dictionary=_board().entries[0].layout.duplicate(true)
		assert(design.objects[0].color_style=="rose" and not design.objects[0].has("id"))
		var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
		assert(replica.state.families.a.room_library==_board())
		var saved_during_draft:=World.new(); assert(saved_during_draft.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
		assert(saved_during_draft.state.lots.lot_1.objects.is_empty() and saved_during_draft.state.families.a.room_library==_board(),"Saving during a draft keeps the design and the committed house")
		# Removing the original room does not erase the separately saved design.
		assert(world.apply_command("a",{"type":"build_cancel","lot_id":lot.id}).ok)
		assert(lot.objects.is_empty() and _board().entries[0].layout==design)
		assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
		var intent:=_place(rotation); var plan:=Copy.inspect_source(lot,intent,[],Library.source(design)); assert(plan.ok,str(plan))
		var funds: int=lot.funds; var objects: int=world.state.next_object
		assert(world.apply_command("a",intent).ok and Copy.is_applied(lot,plan) and lot.funds==funds-plan.cost and world.state.next_object==objects+2)
		assert(lot.objects[0].color_style=="rose" and _board().entries[0].layout==design)
		_reject(intent); _reject(_place(rotation),"b")
		assert(world.apply_command("a",{"type":"build_undo","lot_id":lot.id,"revision":lot.revision}).ok and lot.objects.is_empty() and lot.funds==funds)
		assert(world.apply_command("a",{"type":"build_redo","lot_id":lot.id,"revision":lot.revision}).ok and Copy.is_applied(lot,plan))
		assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
		assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
		assert(replica.state.families.a.room_library==_board() and Copy.is_applied(replica.state.lots.lot_1,plan))
	_fresh()
	for change: Dictionary in [{"name":""},{"name":"Bad\nName"},{"name":"a".repeat(33)},{"source_x":null},{"source_x":0,"source_y":0},{"revision":-1},{"library_revision":-1},{"blueprint_id":"room_1"}]:
		var bad:=_save(); bad.merge(change,true); _reject(bad)
	assert(world.apply_command("a",_save()).ok)
	for change: Dictionary in [{"library_revision":0},{"blueprint_id":[]},{"blueprint_id":"missing"},{"rotation":4},{"rotation":0.5},{"x":16},{"x":0,"y":0}]:
		var bad:=_place(); bad.merge(change,true); _reject(bad)
	var placed:=_place(); var rename: Dictionary={"type":"blueprint_rename","blueprint_id":"room_1","library_revision":_board().revision,"name":"Rose bedroom"}
	assert(world.apply_command("a",rename).ok and _board().entries[0].name=="Rose bedroom"); _reject(rename); _reject(placed)
	var whole: Dictionary=world.snapshot()
	for changes: Dictionary in [{"width":17},{"width":4.5},{"seed":[0,0]},{"objects":[{"kind":"bed","x":1,"y":1,"rotation":0,"id":"forged"}]},{"walls":[[0,0],[0,0]]},{"windows":{"1,1":"shutters"}},{"finishes":{"floor":{"1,1":"unknown"},"wall":{}}},{"extra":true}]:
		var corrupt:=whole.duplicate(true); corrupt.families.a.room_library.entries[0].layout.merge(changes,true)
		var replica:=World.new(); replica.initialize(); var original: Dictionary=replica.snapshot()
		assert(not replica.restore(corrupt,true) and replica.snapshot()==original)
	for index in range(3): assert(world.apply_command("a",_save()).ok)
	assert(_board().entries.size()==Library.MAX_ROOMS); _reject(_save())
	var remove: Dictionary={"type":"blueprint_delete","blueprint_id":"room_1","library_revision":_board().revision}
	var original_lot: Dictionary=lot.duplicate(true)
	assert(world.apply_command("a",remove).ok and lot==original_lot); _reject(remove)
	assert(world.apply_command("a",_save()).ok and _board().entries[-1].id=="room_5")
	var legacy: Dictionary=world.snapshot(); legacy.families.a.erase("room_library")
	var loaded:=World.new(); assert(loaded.restore(JSON.parse_string(JSON.stringify(legacy)),true)); assert(loaded.state.families.a.room_library==Library.create())
	# Canonical JSON validation does not count float spellings as extra library bytes.
	assert(Library.valid(JSON.parse_string(JSON.stringify(_board()))))
	_fresh(); assert(world.apply_command("a",_save()).ok)
	lot.funds=1; _reject(_place())
	lot.funds=12000; world.state.families.a.members[0].x=10; world.state.families.a.members[0].y=7; _reject(_place())
	# Saved recipes contain no meal portions, crops, canvas progress, or wall originals.
	for kind: String in ["dining_table","garden_bed","easel"]:
		_fresh(); lot.objects.clear()
		var object: Dictionary=world._new_object(kind,1,1,0); lot.objects.append(object)
		if kind=="dining_table": object.meal={"recipe":"salad","servings":4,"batch":1,"cook":world.state.families.a.members[0].id,"cook_name":"Alex","day":1}
		elif kind=="garden_bed": object.garden={"crop":"radish","growth":90.0,"water":60.0,"revision":1,"harvests":3}
		else: object.painting={"subject":"meadow","progress":24.0,"artists":[{"id":world.state.families.a.members[0].id,"name":"Alex"}],"day":1,"revision":2}
		var live: Dictionary=object.duplicate(true)
		assert(world.apply_command("a",_save()).ok)
		assert(_board().entries[0].layout.objects==[{"kind":kind,"x":1,"y":1,"rotation":0}])
		assert(world.apply_command("a",_place()).ok and lot.objects[0]==live)
		if kind=="dining_table": assert(lot.objects[-1].meal==preload("res://game/meals.gd").create())
		elif kind=="garden_bed": assert(lot.objects[-1].garden==preload("res://game/gardens.gd").create())
		else: assert(lot.objects[-1].painting==preload("res://game/paintings.gd").create())
	_fresh(); lot.objects.clear()
	var easel: Dictionary=world._new_object("easel",1,1,0); lot.objects.append(easel)
	easel.painting={"subject":"meadow","progress":24.0,"artists":[{"id":world.state.families.a.members[0].id,"name":"Alex"}],"day":1,"revision":2}
	assert(world.apply_command("a",{"type":"art_hang","lot_id":lot.id,"source":"easel:"+str(easel.id),"x":0,"y":1,"revision":lot.revision}).ok)
	var originals: Dictionary=lot.artworks.duplicate(true)
	assert(not originals.is_empty() and world.apply_command("a",_save()).ok and world.apply_command("a",_place()).ok)
	assert(lot.artworks==originals and not _board().entries[0].layout.has("artworks"))
	# Four households with large, varied libraries remain within the existing wire bounds.
	_fresh(); world.ensure_family("c","Casey"); world.ensure_family("d","Drew")
	var large: Dictionary={"floors":[],"walls":[],"doors":[[7,15]],"windows":{},"objects":[],"finishes":{"floor":{},"wall":{}}}
	var colors: Array=preload("res://game/furniture_colors.gd").PALETTE.keys()
	var floor_styles: Array=preload("res://game/finishes.gd").PALETTES.floor.keys()
	for y in range(16):
		for x in range(16):
			large.floors.append([x,y]); large.finishes.floor["%d,%d" % [x,y]]=floor_styles[(x*13+y*7)%floor_styles.size()]
			if x in [0,15] or y in [0,15]:
				if not large.doors.has([x,y]): large.walls.append([x,y])
			else:
				var furnishing: Dictionary={"kind":"plant","x":x,"y":y,"rotation":(x+y)%4}
				preload("res://game/furniture_colors.gd").set_style(furnishing,str(colors[(x*17+y*3)%colors.size()])); large.objects.append(furnishing)
	var capture:=Copy.capture(large,Vector2i(1,1)); assert(capture.ok)
	var board:=Library.create()
	for index in range(4):
		var next: Dictionary=board.duplicate(true); next.entries.append({"id":"room_"+str(index+1),"name":"Large room "+str(index),"layout":Library.layout(capture)}); next.next_id=index+2
		if not Library.valid(next): assert(JSON.stringify(next).to_utf8_buffer().size()>Library.MAX_BYTES); break
		board=next
	assert(not board.entries.is_empty() and JSON.stringify(board).to_utf8_buffer().size()>16000)
	for family: Dictionary in world.state.families.values(): family.room_library=board.duplicate(true)
	var raw:=JSON.stringify(world.snapshot()).to_utf8_buffer(); var compressed:=raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var session: Node=root.get_node("Session")
	assert(raw.size()<session.MAX_SNAPSHOT_BYTES and compressed.size()<session.MAX_COMPRESSED_BYTES)
	var restored:=World.new(); var started:=Time.get_ticks_usec()
	assert(restored.restore(JSON.parse_string(raw.get_string_from_utf8()),true))
	print("ROOM_LIBRARY_BUDGET raw=%d compressed=%d restore_ms=%.2f" % [raw.size(),compressed.size(),(Time.get_ticks_usec()-started)/1000.0])
	print("ROOM_LIBRARY_PASS"); quit()
