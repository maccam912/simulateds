extends RefCounted
## Ordinary owned tasks reserve places; no shared activity controls another family.
const Catalog = preload("res://game/catalog.gd")
const Access = preload("res://game/build_access.gd")
const KINDS := {
	"dining_table":{"capacity":4,"social_rate":4.0,"noun":"meal","title":"A meal together","place":"dining table","together":"Eating together","present":"Eating here"},
	"game_table":{"capacity":4,"social_rate":5.0,"noun":"game","title":"Tabletop game","place":"table","together":"Playing together","present":"Playing here"},
	"stereo":{"capacity":4,"social_rate":4.0,"noun":"dance","title":"Music & dancing","place":"stereo","together":"Dancing together","present":"Dancing here"}
}

static func activity(world: Dictionary, member: Dictionary, kind: String="") -> Dictionary:
	var task: Dictionary=member.get("task",{})
	if task.get("type")!="interact" or task.get("target_kind","object")!="object": return {}
	var lot: Dictionary=preload("res://game/storeys.gd").view(world.get("lots",{}).get(member.get("lot_id",""),{}),int(member.get("level",0)))
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
	var origin: Vector2i = Vector2i(int(member.x),int(member.y)) if local_member else lot.get("entrances",[Access.GATE])[0] if not lot.get("entrances",[Access.GATE]).is_empty() else Access.GATE
	var reachable := Access.reachable_from(blocked,origin,local_member)
	var reserved := {}; var occupied := {}
	var users := players(world,str(lot.id),str(object.id),false)
	var others := 0
	var own_activity := activity(world,member) if local_member else {}
	for user: Dictionary in users:
		if user.id!=member.get("id",""): others+=1
	for family: Dictionary in world.get("families",{}).values():
		for other: Dictionary in family.members:
			if other.lot_id!=lot.id or int(other.get("level",0))!=int(lot.get("level",0)) or other.id==member.get("id",""): continue
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

## Newly chosen participation excludes time spent in an autonomous activity.
static func chosen_time(task: Dictionary) -> float:
	return maxf(0.0,float(task.get("elapsed",0.0))-float(task.get("leisure_chosen_at",task.get("meal_chosen_at",0.0))))

## Sample all chosen participants before the authority ticks any individual.
## Only active reservations count; queued people must not deadlock a full table.
static func company_windows(world: Dictionary,delta: float=0.0) -> Dictionary:
	var groups := {}; var result := {}
	for family: Dictionary in world.get("families",{}).values():
		if not family.get("online",false) or world.lots[family.home_lot].building: continue
		for member: Dictionary in family.members:
			var task: Dictionary=member.task
			if task.is_empty() or task.get("automatic",false): continue
			var object:=activity(world,member)
			if not object.get("kind") in ["game_table","stereo"]: continue
			var key: String=str(member.lot_id)+":"+str(object.id)
			if not groups.has(key): groups[key]=[]
			groups[key].append(member)
	for participants: Array in groups.values():
		if participants.size()<2: continue
		for member: Dictionary in participants:
			var window := {"hold":false,"remaining":0.0,"waiting":false}
			for other: Dictionary in participants:
				if other.id==member.id: continue
				var needed: float=preload("res://game/friendships.gd").SHARED_TIME
				if not other.task.path.is_empty():
					needed+=maxf(0.0,other.task.path.size()*0.22-float(other.walk_clock)); window.waiting=true
				else:
					needed=maxf(0.0,needed-minf(chosen_time(member.task),chosen_time(other.task)))
					needed=maxf(0.0,needed-minf(delta,minf(float(member.task.remaining),float(other.task.remaining))))
				if needed>0.0000001: window.hold=true; window.remaining=maxf(float(window.remaining),needed)
			window.remaining=minf(float(member.task.remaining),float(window.remaining))
			result[str(member.id)]=window
	return result
static func company_window(world: Dictionary,member: Dictionary) -> Dictionary:
	return company_windows(world).get(str(member.get("id","")),{"hold":false,"remaining":0.0,"waiting":false})
