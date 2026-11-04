extends RefCounted
## Participation is derived from ordinary owned tasks; no shared task takes over
## a resident, and no seat lock survives cancellation, travel, or disconnect.
const CAPACITY := 4
const SOCIAL_RATE := 5.0

static func is_shared(world: Dictionary, member: Dictionary) -> bool:
	var task: Dictionary=member.get("task",{})
	if not task.get("path",[]).is_empty() or float(task.get("elapsed",0.0))<=0.0: return false
	var lot: Dictionary=world.get("lots",{}).get(member.get("lot_id",""),{})
	for object: Dictionary in lot.get("objects",[]):
		if object.id==task.get("target_id") and object.kind=="game_table":
			return players(world,str(lot.id),str(object.id)).size()>1
	return false

static func players(world: Dictionary, lot_id: String, object_id: String, arrived_only: bool=true) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for family: Dictionary in world.get("families",{}).values():
		for member: Dictionary in family.members:
			var task: Dictionary=member.get("task",{})
			if member.lot_id!=lot_id or task.get("type")!="interact" or task.get("target_kind","object")!="object" or task.get("target_id")!=object_id: continue
			if arrived_only and (not task.get("path",[]).is_empty() or float(task.get("elapsed",0.0))<=0.0): continue
			result.append(member)
	return result

static func place(member: Dictionary) -> Vector2i:
	var path: Array=member.get("task",{}).get("path",[])
	if not path.is_empty(): return Vector2i(int(path[-1][0]),int(path[-1][1]))
	return Vector2i(int(member.x),int(member.y))
