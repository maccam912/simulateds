extends RefCounted
## One non-mutating placement check serves host commands and local previews.
const Catalog = preload("res://game/catalog.gd")

static func inspect(lot: Dictionary, command: Dictionary, residents: Array) -> Dictionary:
	if not _coordinate(command.get("x")) or not _coordinate(command.get("y")):
		return _no("Choose a tile inside the lot.")
	var cell := Vector2i(int(command.x),int(command.y))
	var moving: bool = command.get("type") == "move_object"
	var object: Dictionary = {}
	if moving:
		if not command.get("object_id") is String: return _no("Choose furniture to move.")
		for item: Dictionary in lot.objects:
			if item.id == command.object_id: object=item; break
		if object.is_empty(): return _no("That furnishing is no longer here.")
	var kind: Variant = object.get("kind") if moving else command.get("kind")
	if not kind is String or not Catalog.ITEMS.has(kind): return _no("Choose a catalog item.")
	var rotation: Variant = command.get("rotation",0)
	if not _integer(rotation) or int(rotation)<0 or int(rotation)>3: return _no("Invalid rotation.")
	var definition: Dictionary = Catalog.ITEMS[kind]
	var cost := 0 if moving else int(definition.cost)
	if int(lot.funds)<cost: return _no("Need § %d more." % (cost-int(lot.funds)))
	if moving and int(object.x)==cell.x and int(object.y)==cell.y and int(object.rotation)==int(rotation):
		return _no("Already here. Choose a new tile or rotate.")
	if kind in ["floor","wall","door"]:
		var key: String={"floor":"floors","wall":"walls","door":"doors"}[kind]
		if lot[key].has([cell.x,cell.y]): return _no("That tile is already placed.")
		if kind!="floor":
			if residents.has(cell) or _furniture_at(lot,cell,""): return _no("Leave space for furniture and residents.")
			if cell==Vector2i(8,14): return _no("Keep the lot entrance clear.")
	else:
		var footprint := Catalog.footprint(kind,int(rotation))
		for y in range(cell.y,cell.y+footprint.y):
			for x in range(cell.x,cell.x+footprint.x):
				var tile := Vector2i(x,y)
				if x<0 or y<0 or x>=16 or y>=16: return _no("Keep the whole furnishing inside the lot.")
				if not lot.floors.has([x,y]): return _no("Place floor beneath the whole furnishing.")
				if lot.walls.has([x,y]) or lot.doors.has([x,y]): return _no("Leave walls and doorways clear.")
				if residents.has(tile): return _no("A resident is standing here.")
				if _furniture_at(lot,tile,str(object.get("id",""))): return _no("Another furnishing is in the way.")
	return {"ok":true,"message":str(definition.name)+( " · No cost" if moving else " · § %d" % cost),"kind":kind,"cost":cost,"rotation":int(rotation)}

static func _furniture_at(lot: Dictionary, cell: Vector2i, ignore_id: String) -> bool:
	for object: Dictionary in lot.objects:
		if object.id==ignore_id: continue
		var size := Catalog.footprint(str(object.kind),int(object.rotation))
		if cell.x>=int(object.x) and cell.x<int(object.x)+size.x and cell.y>=int(object.y) and cell.y<int(object.y)+size.y: return true
	return false

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))

static func _coordinate(value: Variant) -> bool:
	return _integer(value) and float(value)>=0 and float(value)<16

static func _no(message: String) -> Dictionary:
	return {"ok":false,"message":message}
