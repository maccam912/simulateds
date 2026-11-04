extends RefCounted
## Ordinary owned tasks reserve places; no shared activity controls another family.
const Catalog = preload("res://game/catalog.gd")
const Access = preload("res://game/build_access.gd")
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

## Layout capacity and temporary occupation are separate. The same available
## destinations drive accepted tasks, People, and the read-only world overlay.
## Construction calls with an empty world/member to ignore sheltered residents.
static func spaces(world: Dictionary, lot: Dictionary, object: Dictionary, member: Dictionary={}) -> Dictionary:
	var blocked := Access.obstacles(lot)
	var local_member: bool=not member.is_empty() and member.get("lot_id")==lot.id
	var origin := Vector2i(int(member.x),int(member.y)) if local_member else Access.GATE
	var reachable := Access.reachable_from(blocked,origin,local_member)
	var reserved := {}; var occupied := {}
	var users := players(world,str(lot.id),str(object.id),false)
	var others := 0
	var own_activity := activity(world,member) if local_member else {}
	for user: Dictionary in users:
		if user.id!=member.get("id",""): others+=1
	for family: Dictionary in world.get("families",{}).values():
		for other: Dictionary in family.members:
			if other.lot_id!=lot.id or other.id==member.get("id",""): continue
			occupied[Vector2i(int(other.x),int(other.y))]=str(other.name)
			if not activity(world,other).is_empty(): reserved[place(other)]=str(other.name)
	var extent := Catalog.footprint(str(object.kind),int(object.get("rotation",0)))
	var bounds := Rect2i(Vector2i(int(object.x),int(object.y)),extent)
	var seen := {}; var cells: Array=[]; var available: Array=[]; var usable := 0
	var maximum := int(KINDS[object.kind].capacity)
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			for direction: Vector2i in Access.DIRECTIONS:
				var cell := Vector2i(x,y)+direction
				if bounds.has_point(cell) or seen.has(cell) or not Access._inside(cell): continue
				seen[cell]=true
				var status := "blocked" if blocked.has(cell) else "unreachable" if not reachable.has(cell) else "open"
				var name := ""
				if status=="open":
					usable+=1
					if reserved.has(cell): status="reserved"; name=reserved[cell]
					elif occupied.has(cell): status="occupied"; name=occupied[cell]
					elif others<maximum: available.append(cell)
				if not own_activity.is_empty() and place(member)==cell:
					status="reserved"; name=str(member.name)
				cells.append({"cell":cell,"status":status,"name":name})
	return {"cells":cells,"capacity":mini(maximum,usable),"maximum":maximum,"available":available,"reserved":users.size(),"full":others>=maximum}

static func layout_text(report: Dictionary) -> String:
	var count := int(report.capacity)
	return "Room for %d · %s" % [count,"Solo only" if count==1 else "No path" if count==0 else "Up to %d together" % count]

static func summary(report: Dictionary) -> String:
	return "%d of %d %s reserved" % [int(report.reserved),int(report.capacity),"place" if int(report.capacity)==1 else "places"]

static func waiting_reason(report: Dictionary) -> String:
	if int(report.capacity)==0: return "No reachable place. Clear a path."
	if report.full or int(report.reserved)>=int(report.capacity):
		return "Only one usable place; it is reserved." if int(report.capacity)==1 else "All %d usable places are reserved." % int(report.capacity)
	if report.cells.any(func(cell): return cell.status=="reserved"): return "Places are occupied or reserved nearby."
	return "Someone is standing in the available places."
