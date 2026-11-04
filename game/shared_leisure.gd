extends RefCounted
## Ordinary owned tasks reserve places; no shared activity controls another family.
const KINDS := {
	"game_table":{"capacity":4,"social_rate":5.0,"noun":"game","title":"Tabletop game","place":"table","together":"Playing together","present":"Playing here"},
	"stereo":{"capacity":4,"social_rate":4.0,"noun":"dance","title":"Music & dancing","place":"stereo","together":"Dancing together","present":"Dancing here"}
}

static func activity(world: Dictionary, member: Dictionary, kind: String="") -> Dictionary:
	var task: Dictionary=member.get("task",{})
	if task.get("type")!="interact" or task.get("target_kind","object")!="object": return {}
	var lot: Dictionary=world.get("lots",{}).get(member.get("lot_id",""),{})
	if lot.get("building",false): return {}
	for object: Dictionary in lot.get("objects",[]):
		if object.id==task.get("target_id") and KINDS.has(object.kind) and (kind.is_empty() or object.kind==kind): return object
	return {}

static func is_shared(world: Dictionary, member: Dictionary, kind: String="") -> bool:
	var task: Dictionary=member.get("task",{})
	if not task.get("path",[]).is_empty() or float(task.get("elapsed",0.0))<=0.0: return false
	var object := activity(world,member,kind)
	return not object.is_empty() and players(world,str(member.lot_id),str(object.id)).size()>1

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
