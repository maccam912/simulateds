extends RefCounted
## One clear step after completed shared recreation; never an eviction or a
## standing order. The resident's own queue and direct commands take priority.
const Leisure = preload("res://game/shared_leisure.gd")
const Access = preload("res://game/build_access.gd")
const Catalog = preload("res://game/catalog.gd")

static func destination(world: Dictionary, lot: Dictionary, member: Dictionary, object: Dictionary, route: Callable) -> Dictionary:
	if not Leisure.KINDS.has(object.get("kind")) or lot.get("building",false) or not member.task.is_empty() or not member.queue.is_empty(): return {}
	var here := Vector2i(int(member.x),int(member.y))
	var waiting: Dictionary={}
	var approaches: Array=[]
	for family: Dictionary in world.families.values():
		if not family.online or world.lots[family.home_lot].building: continue
		for other: Dictionary in family.members:
			if other.id==member.id or other.lot_id!=lot.id or not other.task.is_empty() or other.queue.is_empty(): continue
			var next: Dictionary=other.queue[0]
			if next.get("type")!="interact" or next.get("target_kind","object")!="object" or next.get("target_id")!=object.id: continue
			var spaces := Leisure.spaces(world,lot,object,other)
			if spaces.available.is_empty() and spaces.cells.any(func(cell): return cell.cell==here and cell.status=="occupied"):
				if waiting.is_empty(): waiting=other
				approaches.append_array(route.call(lot,Vector2i(int(other.x),int(other.y)),[here]))
	if waiting.is_empty(): return {}
	var blocked := traffic(world,lot,str(member.id))
	for tile: Array in approaches: blocked[Vector2i(int(tile[0]),int(tile[1]))]=true
	# A courtesy step must leave every shared activity's places clear. Doorways
	# and the entrance remain passages; occupied tiles and accepted paths win.
	for tile: Array in lot.doors: blocked[Vector2i(int(tile[0]),int(tile[1]))]=true
	blocked[Access.GATE]=true
	for furnishing: Dictionary in lot.objects:
		if not Leisure.KINDS.has(furnishing.kind): continue
		var size := Catalog.footprint(str(furnishing.kind),int(furnishing.rotation))
		for y in range(int(furnishing.y),int(furnishing.y)+size.y):
			for x in range(int(furnishing.x),int(furnishing.x)+size.x):
				for direction: Vector2i in Access.DIRECTIONS: blocked[Vector2i(x,y)+direction]=true
	var center := Vector2(float(object.x),float(object.y))+Vector2(Catalog.footprint(str(object.kind),int(object.rotation)))*0.5
	var chosen := Vector2i(-1,-1); var distance := -1.0
	for direction: Vector2i in Access.DIRECTIONS:
		var cell := here+direction
		if not Access._inside(cell) or blocked.has(cell): continue
		var score := (Vector2(cell)+Vector2(0.5,0.5)).distance_squared_to(center)
		if score>distance: chosen=cell; distance=score
	if chosen.x<0: return {}
	return {"cell":chosen,"name":str(waiting.name)}

static func traffic(world: Dictionary, lot: Dictionary, except_member: String) -> Dictionary:
	var blocked := Access.obstacles(lot)
	for family: Dictionary in world.families.values():
		for other: Dictionary in family.members:
			if other.id==except_member or other.lot_id!=lot.id: continue
			blocked[Vector2i(int(other.x),int(other.y))]=true
			for tile: Array in other.task.get("path",[]): blocked[Vector2i(int(tile[0]),int(tile[1]))]=true
	return blocked
