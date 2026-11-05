extends RefCounted
## Floor-level construction diagnosis. Shared reachability serves both the
## host and the player’s overlay; no inspection mutates the draft.
const Catalog = preload("res://game/catalog.gd")
const GATE := Vector2i(8,14)
const DIRECTIONS := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]

static func inspect(lot: Dictionary, residents: Array) -> Dictionary:
	var level := int(lot.get("level",0))
	var unbuilt: bool=level>0 and lot.floors.is_empty() and lot.objects.is_empty() and lot.walls.is_empty() and lot.doors.is_empty() and residents.is_empty()
	if unbuilt: return {"ok":true,"message":"","issues":[],"reachable":{},"unreachable":[],"unbuilt":true}
	var blocked := obstacles(lot)
	var reachable := {}
	var issues: Array[Dictionary]=[]
	var entrances: Array=lot.get("entrances",[GATE])
	if level>0 and (entrances.is_empty() or entrances.all(func(at): return blocked.has(at))):
		var at := Vector2i(int(lot.floors[0][0]),int(lot.floors[0][1])) if not lot.floors.is_empty() else Vector2i(8,8)
		issues.append(_issue("connection","Stair connection",at,Vector2i.ONE,"Add stairs with clear landings connecting floor %d to the entrance." % (level+1)))
	elif level==0 and blocked.has(GATE):
		issues.append(_issue("gate","Entrance",GATE,Vector2i.ONE,"Keep the lot entrance clear."))
	else:
		for entrance: Vector2i in entrances: reachable.merge(reachable_from(blocked,entrance))
		for resident: Dictionary in residents:
			var position := Vector2i(int(resident.x),int(resident.y))
			var can_exit: bool=reachable.has(position)
			# Ordinary routing permits a legacy resident standing on an occupied
			# start tile to step out. Preserve that rule in the diagnostic too.
			if not can_exit and blocked.has(position):
				for direction: Vector2i in DIRECTIONS:
					if reachable.has(position+direction): can_exit=true; break
			if not can_exit:
				issues.append(_issue("resident:"+str(resident.id),str(resident.name),position,Vector2i.ONE,"A resident cannot reach the entrance. Add a door or clear a path."))
		for object: Dictionary in lot.objects:
			if str(Catalog.ITEMS[object.kind].need).is_empty() and object.kind!="stairs": continue
			var size := Catalog.footprint(str(object.kind),int(object.rotation))
			var usable := false
			for y in range(int(object.y),int(object.y)+size.y):
				for x in range(int(object.x),int(object.x)+size.x):
					for direction: Vector2i in DIRECTIONS:
						if reachable.has(Vector2i(x,y)+direction): usable=true; break
			if not usable:
				issues.append(_issue("object:"+str(object.id),str(Catalog.ITEMS[object.kind].name),Vector2i(int(object.x),int(object.y)),size,"Leave a clear path to the "+str(Catalog.ITEMS[object.kind].name)+"."))
	var unreachable: Array[Vector2i]=[]
	for cell: Array in lot.floors:
		var position := Vector2i(int(cell[0]),int(cell[1]))
		if not blocked.has(position) and not reachable.has(position): unreachable.append(position)
	return {"ok":issues.is_empty(),"message":"" if issues.is_empty() else str(issues[0].message),"issues":issues,"reachable":reachable,"unreachable":unreachable}

static func _issue(key: String, name: String, cell: Vector2i, footprint: Vector2i, message: String) -> Dictionary:
	return {"key":key,"name":name,"cell":cell,"footprint":footprint,"message":message,"center":Vector2(cell)+Vector2(footprint)*0.5}

static func _inside(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<16 and cell.y<16

static func obstacles(lot: Dictionary) -> Dictionary:
	var result := {}
	for cell: Array in lot.get("stairwells",[]): result[Vector2i(int(cell[0]),int(cell[1]))]=true
	if int(lot.get("level",0))>0:
		for y in range(16):
			for x in range(16):
				if [x,y] not in lot.floors: result[Vector2i(x,y)]=true
	for cell: Array in lot.get("landscape",{}).get("pools",[]): result[Vector2i(int(cell[0]),int(cell[1]))]=true
	for cell: Array in lot.walls: result[Vector2i(int(cell[0]),int(cell[1]))]=true
	for object: Dictionary in lot.objects:
		var size := Catalog.footprint(str(object.kind),int(object.rotation))
		for y in range(int(object.y),int(object.y)+size.y):
			for x in range(int(object.x),int(object.x)+size.x): result[Vector2i(x,y)]=true
	return result

static func reachable_from(blocked: Dictionary, start: Vector2i, allow_occupied_start: bool=false) -> Dictionary:
	if not _inside(start) or (blocked.has(start) and not allow_occupied_start): return {}
	var reachable := {start:true}
	var frontier: Array[Vector2i]=[start]; var cursor := 0
	while cursor<frontier.size():
		var current := frontier[cursor]; cursor+=1
		for direction: Vector2i in DIRECTIONS:
			var next := current+direction
			if _inside(next) and not blocked.has(next) and not reachable.has(next):
				reachable[next]=true; frontier.append(next)
	return reachable
