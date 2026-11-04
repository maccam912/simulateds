extends RefCounted
## A construction relocation is separate from paid edits and their Undo history.
const MAX_DISTANCE := 3
const Access=preload("res://game/build_access.gd")
const Text=preload("res://game/activity_log.gd")
static func request(state: Dictionary,owner: String,lot_id: String) -> Dictionary:
	var result: Dictionary={"ok":false,"message":"Build on your own lot to move the family aside.","orders":[],"names":[]}
	var family: Dictionary=state.get("families",{}).get(owner,{})
	var lot: Dictionary=state.get("lots",{}).get(lot_id,{})
	if family.is_empty() or lot.get("owner")!=owner or family.get("home_lot")!=lot_id or not lot.get("building",false): return result
	for member: Dictionary in family.members:
		if member.lot_id!=lot_id: continue
		if int(member.next_action)>=9007199254740000: result.message="A resident has reached their action limit."; return result
		result.orders.append({"member_id":str(member.id),"x":int(member.x),"y":int(member.y),"next_action":int(member.next_action)})
		result.names.append(str(member.name))
	if result.orders.is_empty(): result.message="Nobody from your household is on this lot. Visiting residents stay where they are."; return result
	result.ok=true; result.message="Move "+", ".join(result.names)+" to clear entrance-side spaces. Free; the house and Undo history stay the same."
	return result
static func matches(value: Variant,expected: Array) -> bool:
	if not value is Array or value.size()!=expected.size(): return false
	for index in range(expected.size()):
		var row: Variant=value[index]; var wanted: Dictionary=expected[index]
		if not row is Dictionary or row.size()!=4 or not row.get("member_id") is String or row.member_id!=wanted.member_id: return false
		for key: String in ["x","y","next_action"]:
			if not Text._integer(row.get(key),1 if key=="next_action" else 0,9007199254740000 if key=="next_action" else 15) or int(row[key])!=int(wanted[key]): return false
	return true
static func places(lot: Dictionary,orders: Array,stationary: Array,history: Array,committed: Dictionary) -> Dictionary:
	var blocked:=Access.obstacles(lot)
	var reachable:=Access.reachable_from(blocked,Access.GATE)
	if reachable.is_empty(): return {"ok":false,"message":"Clear the lot entrance first. Access can help you find the obstruction."}
	# All reversible layouts must leave the new positions physically free.
	var reserved:=blocked.duplicate()
	for layout: Dictionary in history: reserved.merge(Access.obstacles(layout))
	var home_routes:=reachable
	if not committed.is_empty():
		var home_blocked:=Access.obstacles(committed); reserved.merge(home_blocked)
		home_routes=Access.reachable_from(home_blocked,Access.GATE)
	for cell: Vector2i in stationary: reserved[cell]=true
	var candidates: Array[Vector2i]=[]
	# Flood insertion order is nearest-first from the lot entrance.
	for cell: Vector2i in reachable:
		if absi(cell.x-Access.GATE.x)+absi(cell.y-Access.GATE.y)<=MAX_DISTANCE and not reserved.has(cell) and home_routes.has(cell): candidates.append(cell)
		if candidates.size()==orders.size(): break
	if candidates.size()!=orders.size(): return {"ok":false,"message":"Not enough space stays clear through Undo and Discard. Finish a reachable layout, then reopen Build & buy."}
	# Keep an already well-placed resident in their spot rather than swapping them.
	var positions: Array[Vector2i]=[]; var claimed: Array[Vector2i]=[]
	for row: Dictionary in orders:
		var cell:=Vector2i(int(row.x),int(row.y))
		if candidates.has(cell) and not claimed.has(cell): positions.append(cell); claimed.append(cell)
		else: positions.append(Vector2i(-1,-1))
	for index in range(positions.size()):
		if positions[index].x>=0: continue
		for cell: Vector2i in candidates:
			if not claimed.has(cell): positions[index]=cell; claimed.append(cell); break
	return {"ok":true,"places":positions}
