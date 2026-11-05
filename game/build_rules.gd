extends RefCounted
## One non-mutating placement check serves host commands and local previews.
const Catalog = preload("res://game/catalog.gd")
const Windows = preload("res://game/windows.gd")

static func inspect(lot: Dictionary, command: Dictionary, residents: Array) -> Dictionary:
	# Sheltered residents never veto a construction transaction. The host moves
	# anyone displaced by an accepted edit back to a safe entrance position.
	if lot.get("building",false): residents=[]
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
	if [cell.x,cell.y] in lot.get("landscape",{}).get("pools",[]): return _no("Fill the pool before building here.")
	if not definition.get("outdoor",kind=="garden_bed") and not flat_ground(lot,cell): return _no("Flatten the terrain before building here.")
	if kind=="stairs":
		if int(lot.get("level",0))>=2: return _no("This is the top floor.")
		var stair := {"x":cell.x,"y":cell.y,"rotation":int(rotation)}
		for upper: bool in [false,true]:
			var landing := preload("res://game/storeys.gd").landing(stair,upper)
			if not _coordinate(landing.x) or not _coordinate(landing.y): return _no("Keep both stair landings inside the lot.")
		var above: Dictionary=lot.get("storeys",{}).get(str(int(lot.get("level",0))+1),{"objects":[],"walls":[],"doors":[]})
		var extent := Catalog.footprint("stairs",int(rotation))
		for y in range(cell.y,cell.y+extent.y):
			for x in range(cell.x,cell.x+extent.x):
				if _furniture_at(above,Vector2i(x,y),"") or [x,y] in above.walls or [x,y] in above.doors: return _no("Clear space for the stairwell on the floor above.")
	var cost := 0 if moving else int(definition.cost)
	var refund := Windows.resale(lot,cell.x,cell.y) if not moving and kind=="door" else 0
	cost-=refund
	if int(lot.funds)<cost: return _no("Need § %d more." % (cost-int(lot.funds)))
	if moving and int(object.x)==cell.x and int(object.y)==cell.y and int(object.rotation)==int(rotation):
		return _no("Already here. Choose a new tile or rotate.")
	if kind in ["floor","wall","door"]:
		var key: String={"floor":"floors","wall":"walls","door":"doors"}[kind]
		if lot[key].has([cell.x,cell.y]): return _no("That tile is already placed.")
		if kind!="floor":
			if [cell.x,cell.y] in lot.get("stairwells",[]): return _no("Keep the stairwell opening clear.")
			if residents.has(cell) or _furniture_at(lot,cell,""): return _no("Leave space for furniture and residents.")
			if cell==Vector2i(8,14): return _no("Keep the lot entrance clear.")
	else:
		var footprint := Catalog.footprint(kind,int(rotation))
		for y in range(cell.y,cell.y+footprint.y):
			for x in range(cell.x,cell.x+footprint.x):
				var tile := Vector2i(x,y)
				if [x,y] in lot.get("landscape",{}).get("pools",[]): return _no("Keep furnishings out of the pool.")
				if x<0 or y<0 or x>=16 or y>=16: return _no("Keep the whole furnishing inside the lot.")
				if not definition.get("outdoor",kind=="garden_bed") and not lot.floors.has([x,y]): return _no("Place floor beneath the whole furnishing.")
				if [x,y] in lot.get("stairwells",[]): return _no("Keep the stairwell opening clear.")
				if lot.walls.has([x,y]) or lot.doors.has([x,y]): return _no("Leave walls and doorways clear.")
				if residents.has(tile): return _no("A resident is standing here.")
				if _furniture_at(lot,tile,str(object.get("id",""))): return _no("Another furnishing is in the way.")
	return {"ok":true,"message":str(definition.name)+( " · No cost" if moving else " · § %d" % cost)+(" after §%d window trade-in" % refund if refund>0 else ""),"kind":kind,"cost":cost,"rotation":int(rotation)}

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

static func flat_ground(lot: Dictionary,cell: Vector2i) -> bool:
	for y in range(cell.y-1,cell.y+2):
		for x in range(cell.x-1,cell.x+2):
			if float(lot.get("landscape",{}).get("heights",{}).get("%d,%d" % [x,y],0))!=0: return false
	return true
