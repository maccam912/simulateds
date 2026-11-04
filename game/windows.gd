extends RefCounted
## Wall-mounted decoration; walls remain the authority for collision and rooms.
const STYLES := {
	"cottage":{"name":"Cottage panes","cost":60,"frame":"eee5c9","glass":"a9cdd2"},
	"picture":{"name":"Picture window","cost":80,"frame":"947252","glass":"98c5cf"},
	"shutters":{"name":"Garden shutters","cost":90,"frame":"e4dabc","glass":"b2d3d2"}
}

static func key(x: int,y: int) -> String: return "%d,%d" % [x,y]

static func at(lot: Dictionary,x: int,y: int) -> String:
	return str(lot.get("windows",{}).get(key(x,y),""))

static func resale(lot: Dictionary,x: int,y: int) -> int:
	var style := at(lot,x,y)
	return int(int(STYLES[style].cost)*0.6) if STYLES.has(style) else 0

static func inspect(lot: Dictionary,command: Dictionary) -> Dictionary:
	if not _coordinate(command.get("x")) or not _coordinate(command.get("y")): return _no("Choose a wall inside the lot.")
	var x := int(command.x); var y := int(command.y)
	var style: Variant=command.get("style")
	if not style is String or (not style.is_empty() and not STYLES.has(style)): return _no("Choose a window style.")
	if not lot.walls.has([x,y]): return _no("Windows fit existing solid walls. Build a wall first.")
	var previous := at(lot,x,y)
	if previous==style: return _no("There is no window here to remove." if style.is_empty() else "This wall already has that window. No charge.","unchanged")
	var price := 0 if style.is_empty() else int(STYLES[style].cost)
	var refund := resale(lot,x,y)
	var cost := price-refund
	var message := "Remove window · Refund §%d · Wall stays" % refund if style.is_empty() else str(STYLES[style].name)+" · §%d" % cost
	if not style.is_empty() and not preload("res://game/wall_art.gd").at(lot,x,y).is_empty(): message+=" · Painting moves into collection"
	if refund>0 and not style.is_empty(): message+=" after §%d trade-in" % refund
	var plan := {"ok":true,"style":style,"previous":previous,"x":x,"y":y,"price":price,"refund":refund,"cost":cost,"message":message}
	if cost>int(lot.funds): plan.ok=false; plan.reason="funds"; plan.message="Window costs §%d · Need §%d more." % [cost,cost-int(lot.funds)]
	elif int(lot.funds)-cost>1000000000: plan.ok=false; plan.reason="funds"; plan.message="The household budget is at its limit."
	return plan

static func apply(lot: Dictionary,plan: Dictionary) -> void:
	if not lot.has("windows"): lot.windows={}
	if plan.style.is_empty(): remove(lot,int(plan.x),int(plan.y))
	else: lot.windows[key(int(plan.x),int(plan.y))]=str(plan.style)
	lot.funds-=int(plan.cost); lot.revision+=1

static func remove(lot: Dictionary,x: int,y: int) -> void:
	if lot.has("windows"): lot.windows.erase(key(x,y))

static func is_applied(lot: Dictionary,plan: Dictionary) -> bool:
	return at(lot,int(plan.x),int(plan.y))==plan.style

static func along_x(lot: Dictionary,x: int,y: int) -> bool:
	# Follow the wall run automatically, including neighboring door thresholds.
	var horizontal := 0; var vertical := 0
	for cells: Array in [lot.walls,lot.doors]:
		for offset in [-1,1]:
			if cells.has([x+offset,y]): horizontal+=1
			if cells.has([x,y+offset]): vertical+=1
	if horizontal!=vertical: return horizontal>vertical
	# A short/isolated wall faces the nearest floor when its run is ambiguous.
	var side_floor := int(lot.floors.has([x-1,y]))+int(lot.floors.has([x+1,y]))
	var end_floor := int(lot.floors.has([x,y-1]))+int(lot.floors.has([x,y+1]))
	return end_floor>=side_floor

static func valid(lot: Dictionary) -> bool:
	if not lot.has("windows"): return true
	if not lot.windows is Dictionary or lot.windows.size()>256: return false
	var walls := {}
	for cell: Array in lot.walls: walls[key(int(cell[0]),int(cell[1]))]=true
	for id: Variant in lot.windows:
		if not id is String or not walls.has(id) or not lot.windows[id] is String or not STYLES.has(lot.windows[id]): return false
	return true

static func _coordinate(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<16

static func _no(message: String,reason: String="invalid") -> Dictionary: return {"ok":false,"message":message,"reason":reason}
