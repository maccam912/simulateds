extends RefCounted
## A lot owns one budget and revision; each storey owns its surfaces and furniture.
const HEIGHT := 2.64
const MAX_LEVEL := 2
const FIELDS := ["floors","walls","doors","objects","finishes","windows","artworks","diagonal_walls"]
const Catalog = preload("res://game/catalog.gd")

static func empty() -> Dictionary:
	return {"floors":[],"walls":[],"doors":[],"objects":[],"finishes":{"floor":{},"wall":{}},"windows":{},"artworks":{},"diagonal_walls":{}}

static func view(lot: Dictionary,level: int) -> Dictionary:
	if lot.is_empty() or level==0: return lot
	var result := lot.duplicate()
	var layer: Dictionary=lot.get("storeys",{}).get(str(level),empty())
	for field: String in FIELDS: result[field]=layer[field]
	result.level=level
	result.landscape={"heights":{},"paints":{},"pools":[]}
	result.entrances=[]; result.stairwells=[]
	for stair: Dictionary in stairs(lot,level-1):
		var dimensions := Catalog.footprint("stairs",int(stair.rotation))
		for y in range(int(stair.y),int(stair.y)+dimensions.y):
			for x in range(int(stair.x),int(stair.x)+dimensions.x): result.stairwells.append([x,y])
		var at := landing(stair,true)
		if [at.x,at.y] in result.floors: result.entrances.append(at)
	return result

static func commit(lot: Dictionary,layer: Dictionary,level: int) -> void:
	if not lot.has("storeys"): lot.storeys={}
	var saved := {}
	for field: String in FIELDS: saved[field]=layer[field]
	lot.storeys[str(level)]=saved
	lot.funds=layer.funds; lot.revision=layer.revision

static func stairs(lot: Dictionary,level: int) -> Array:
	var objects: Array=lot.get("objects",[]) if level==0 else lot.get("storeys",{}).get(str(level),{}).get("objects",[])
	return objects.filter(func(object): return object.kind=="stairs")

static func landing(stair: Dictionary,upper: bool) -> Vector2i:
	var x := int(stair.x); var y := int(stair.y)
	var top: Array[Vector2i]=[Vector2i(x,y-1),Vector2i(x+3,y),Vector2i(x,y+3),Vector2i(x-1,y)]
	var bottom: Array[Vector2i]=[Vector2i(x,y+3),Vector2i(x-1,y),Vector2i(x,y-1),Vector2i(x+3,y)]
	return top[int(stair.rotation)] if upper else bottom[int(stair.rotation)]

static func display_world(world: Dictionary,lot_id: String,level: int) -> Dictionary:
	# Shallow references are read-only. Filtered family arrays are new containers.
	var shown := world.duplicate(); shown.lots=world.get("lots",{}).duplicate()
	if not shown.lots.has(lot_id): return shown
	shown.lots[lot_id]=view(world.lots[lot_id],level)
	shown.families={}
	for id: String in world.get("families",{}):
		var family: Dictionary=world.families[id].duplicate()
		family.members=family.members.filter(func(member): return member.lot_id!=lot_id or int(member.get("level",0))==level)
		shown.families[id]=family
	return shown
