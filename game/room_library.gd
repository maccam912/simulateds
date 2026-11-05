extends RefCounted
## Bounded, host-captured design recipes. No live objects, rewards, or residents.
const Copy=preload("res://game/room_copy.gd")
const Profile=preload("res://game/household_profile.gd")
const Catalog=preload("res://game/catalog.gd")
const Finishes=preload("res://game/finishes.gd")
const Windows=preload("res://game/windows.gd")
const Colors=preload("res://game/furniture_colors.gd")
const MAX_ROOMS := 4
const MAX_BYTES := 32768
const MAX_NUMBER := 9007199254739999

static func create() -> Dictionary: return {"revision":0,"next_id":1,"entries":[]}
static func find(board: Dictionary,id: String) -> Dictionary:
	for entry: Dictionary in board.get("entries",[]):
		if entry.id==id: return entry
	return {}
static func layout(source: Dictionary) -> Dictionary:
	return {"width":source.extent.x,"height":source.extent.y,"seed":source.interior[0].duplicate(),"floors":source.floors.duplicate(true),"walls":source.walls.duplicate(true),"doors":source.doors.duplicate(true),"finishes":source.finishes.duplicate(true),"windows":source.windows.duplicate(true),"objects":source.objects.duplicate(true),"diagonal_walls":source.get("diagonal_walls",{}).duplicate(true)}
static func source(design: Dictionary) -> Dictionary:
	return Copy.capture(design,Vector2i(int(design.seed[0]),int(design.seed[1])))
static func summary(design: Dictionary) -> String:
	return "%d × %d · %d furnishings" % [int(design.width),int(design.height),design.objects.size()]
static func revision_matches(board: Dictionary,value: Variant) -> bool:
	return _integer(value,0,MAX_NUMBER) and int(value)==int(board.revision)
static func valid_id(value: Variant) -> bool:
	if not value is String or not value.begins_with("room_") or value.length()>32: return false
	var tail: String=value.trim_prefix("room_")
	return tail.is_valid_int() and int(tail)>0 and str(int(tail))==tail
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3 or not _integer(value.get("revision"),0,MAX_NUMBER) or not _integer(value.get("next_id"),1,MAX_NUMBER): return false
	if not value.get("entries") is Array or value.entries.size()>MAX_ROOMS: return false
	var seen := {}
	for entry: Variant in value.entries:
		if not entry is Dictionary or entry.size()!=3 or not valid_id(entry.get("id")) or seen.has(entry.id) or int(str(entry.id).trim_prefix("room_"))>=int(value.next_id): return false
		if not Profile.valid_name(entry.get("name"),32) or not valid_layout(entry.get("layout")): return false
		seen[entry.id]=true
	var canonical: Dictionary=value.duplicate(true); normalize(canonical)
	return JSON.stringify(canonical).to_utf8_buffer().size()<=MAX_BYTES
static func valid_layout(value: Variant) -> bool:
	if not value is Dictionary or value.size() not in [9,10] or not _integer(value.get("width"),3,16) or not _integer(value.get("height"),3,16) or not _cell(value.get("seed"),value): return false
	var cells := {}
	for kind: String in ["floors","walls","doors"]:
		if not value.get(kind) is Array or value[kind].size()>256: return false
		var seen := {}
		for cell: Variant in value[kind]:
			if not _cell(cell,value): return false
			var point:=Vector2i(int(cell[0]),int(cell[1]))
			if seen.has(point) or (kind=="doors" and cells.has(point)): return false
			seen[point]=true
		if kind=="walls": cells=seen.duplicate()
		elif kind=="doors": cells.merge(seen)
	if not preload("res://game/landscaping.gd").valid(value): return false
	if not Finishes.valid(value) or not Windows.valid(value) or not value.has("finishes") or not value.has("windows"): return false
	if not value.get("objects") is Array or value.objects.size()>256: return false
	for object: Variant in value.objects:
		if not object is Dictionary or object.size()!=(5 if object.has("color_style") else 4): return false
		if not object.get("kind") is String or not Catalog.ITEMS.has(object.kind) or object.kind in ["floor","wall","door"]: return false
		if not _integer(object.get("rotation"),0,3) or not _cell([object.get("x"),object.get("y")],value) or not Colors.valid(object): return false
		var size:=Catalog.footprint(object.kind,int(object.rotation))
		for y in range(int(object.y),int(object.y)+size.y):
			for x in range(int(object.x),int(object.x)+size.x):
				var point:=Vector2i(x,y)
				if x>=int(value.width) or y>=int(value.height) or cells.has(point): return false
				cells[point]=true
	var canonical: Dictionary=value.duplicate(true); _normalize_layout(canonical)
	var captured:=source(canonical)
	return captured.ok and captured.low==Vector2i.ZERO and captured.extent==Vector2i(int(value.width),int(value.height)) and layout(captured)==canonical
static func normalize(board: Dictionary) -> void:
	board.revision=int(board.revision); board.next_id=int(board.next_id)
	for entry: Dictionary in board.entries: _normalize_layout(entry.layout)
static func _normalize_layout(design: Dictionary) -> void:
	if not design.has("diagonal_walls"): design.diagonal_walls={}
	design.width=int(design.width); design.height=int(design.height)
	for cell: Array in [design.seed]+design.floors+design.walls+design.doors: cell[0]=int(cell[0]); cell[1]=int(cell[1])
	for object: Dictionary in design.objects:
		for key: String in ["x","y","rotation"]: object[key]=int(object[key])
static func edit(family: Dictionary,command: Dictionary,captured: Dictionary={}) -> Dictionary:
	var board: Dictionary=family.room_library
	if not revision_matches(board,command.get("library_revision")): return _no("Saved rooms changed. Review the current library and try again.")
	if int(board.revision)>=MAX_NUMBER or int(board.next_id)>=MAX_NUMBER: return _no("This room library has reached its edit limit.")
	var id: Variant=command.get("blueprint_id","")
	if not id is String: return _no("Choose a saved room.")
	var existing:=find(board,id)
	var next: Dictionary=board.duplicate(true)
	if command.type=="blueprint_delete":
		if existing.is_empty(): return _no("That room is no longer saved.")
		next.entries.remove_at(board.entries.find(existing))
	elif command.type=="blueprint_rename":
		if existing.is_empty() or not Profile.valid_name(command.get("name"),32): return _no("Name a saved room with 1 to 32 characters on one line.")
		next.entries[board.entries.find(existing)].name=str(command.name).strip_edges()
	else:
		if not id.is_empty() or not captured.get("ok",false): return _no("Choose a room in your home to save as a new design.")
		if board.entries.size()>=MAX_ROOMS: return _no("Keep up to four room designs. Remove one before saving another.")
		if not Profile.valid_name(command.get("name"),32): return _no("Name this room with 1 to 32 characters on one line.")
		next.entries.append({"id":"room_"+str(int(board.next_id)),"name":str(command.name).strip_edges(),"layout":layout(captured)}); next.next_id+=1
	next.revision+=1
	if not valid(next): return _no("This design exceeds the room library limit. Save a smaller room or remove a design.")
	family.room_library=next
	return {"ok":true,"message":"Room design removed. Built rooms stay in place." if command.type=="blueprint_delete" else "Room renamed." if command.type=="blueprint_rename" else "Room design saved. It stays in your library if you discard the building draft."}
static func _cell(value: Variant,design: Dictionary) -> bool:
	return value is Array and value.size()==2 and _integer(value[0],0,int(design.width)-1) and _integer(value[1],0,int(design.height)-1)
static func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
