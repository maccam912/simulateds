extends RefCounted
## Sparse surface finishes, shared by host validation and visual previews.
const Rules = preload("res://game/build_rules.gd")
const DEFAULTS := {"floor":"oak","wall":"cream"}
const COST := {"floor":4,"wall":3}
const PALETTES := {
	"floor":{
		"oak":{"name":"Warm oak","color":"d9bd93","pattern":"boards"},
		"walnut":{"name":"Walnut boards","color":"9a765a","pattern":"boards"},
		"slate":{"name":"Slate tiles","color":"7d969b","pattern":"tiles"},
		"sage_tile":{"name":"Sage & cream","color":"acbaa0","pattern":"checkers"},
		"rose_carpet":{"name":"Rose carpet","color":"c3958d","pattern":"carpet"},
		"blue_carpet":{"name":"Blue carpet","color":"8babc0","pattern":"carpet"}
	},
	"wall":{
		"cream":{"name":"Warm cream","color":"e6e2c6"},
		"sage":{"name":"Garden sage","color":"a3b694"},
		"sky":{"name":"Morning blue","color":"a4bdcb"},
		"rose":{"name":"Dusty rose","color":"d2a8a1"},
		"clay":{"name":"Terracotta","color":"c98f72"},
		"ink":{"name":"Deep teal","color":"527f80"}
	}
}

static func key(x: int, y: int) -> String:
	return "%d,%d" % [x,y]

static func create() -> Dictionary:
	return {"floor":{},"wall":{}}

static func at(lot: Dictionary, surface: String, x: int, y: int) -> String:
	return str(lot.get("finishes",{}).get(surface,{}).get(key(x,y),DEFAULTS.get(surface,"")))

static func inspect(lot: Dictionary, command: Dictionary) -> Dictionary:
	var surface: Variant=command.get("surface")
	var finish: Variant=command.get("finish")
	if not surface is String or not PALETTES.has(surface): return _no("Choose floors or walls to decorate.")
	if not finish is String or not PALETTES[surface].has(finish): return _no("Choose a finish from the palette.")
	var selection: Variant=command.get("selection","area")
	if not selection is String or not selection in ["area","room"]: return _no("Choose an area or a room to finish.")
	if selection=="room" and surface!="floor": return _no("Room fill is for floors. Choose an area to paint walls.")
	for field: String in (["x","y"] if selection=="room" else ["x","y","end_x","end_y"]):
		if not Rules._coordinate(command.get(field)): return _no("Keep both painting corners inside the lot.")
	var low := Vector2i(int(command.x),int(command.y)); var high := low
	var area: Array=[]
	if selection=="room":
		area=room_cells(lot,low)
		if area.is_empty(): return _no("Choose floor inside a room, away from walls and doorways.")
		for cell: Array in area:
			low=Vector2i(mini(low.x,int(cell[0])),mini(low.y,int(cell[1])))
			high=Vector2i(maxi(high.x,int(cell[0])),maxi(high.y,int(cell[1])))
	else:
		low=Vector2i(mini(int(command.x),int(command.end_x)),mini(int(command.y),int(command.end_y)))
		high=Vector2i(maxi(int(command.x),int(command.end_x)),maxi(int(command.y),int(command.end_y)))
		for cell: Array in lot["floors" if surface=="floor" else "walls"]:
			if int(cell[0])>=low.x and int(cell[0])<=high.x and int(cell[1])>=low.y and int(cell[1])<=high.y: area.append(cell.duplicate())
	if area.is_empty(): return _no("No "+("floors" if surface=="floor" else "walls")+" in this area. Build them first.")
	var cells: Array=[]
	for cell: Array in area:
		if at(lot,surface,int(cell[0]),int(cell[1]))!=finish: cells.append(cell.duplicate())
	var cost: int=cells.size()*int(COST[surface])
	var plan := {"ok":true,"surface":surface,"finish":finish,"selection":selection,"area":area,"cells":cells,"cost":cost,"low":low,"high":high,"message":"%s · %d tiles · § %d" % [PALETTES[surface][finish].name,cells.size(),cost]}
	if cells.is_empty():
		plan.ok=false; plan.reason="unchanged"; plan.message="This "+("room" if selection=="room" else "area")+" already has that finish. No charge."
	elif cost>int(lot.funds):
		plan.ok=false; plan.reason="funds"; plan.message="Finish costs § %d · Need § %d more." % [cost,cost-int(lot.funds)]
	return plan

static func room_cells(lot: Dictionary, seed: Vector2i) -> Array:
	# Decorate under furniture and residents. Architecture, missing floor, and
	# door thresholds bound the region; occupants are not room dividers.
	var floors := {}; var edges := {}
	for cell: Array in lot.floors: floors[Vector2i(int(cell[0]),int(cell[1]))]=true
	for kind: String in ["walls","doors"]:
		for cell: Array in lot[kind]: edges[Vector2i(int(cell[0]),int(cell[1]))]=true
	if not floors.has(seed) or edges.has(seed): return []
	var reached := {seed:true}; var frontier: Array[Vector2i]=[seed]; var cursor := 0
	while cursor<frontier.size():
		var current := frontier[cursor]; cursor+=1
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next := current+direction
			if floors.has(next) and not edges.has(next) and not reached.has(next): reached[next]=true; frontier.append(next)
	var result: Array=[]
	for cell: Array in lot.floors:
		if reached.has(Vector2i(int(cell[0]),int(cell[1]))): result.append(cell.duplicate())
	return result

static func apply(lot: Dictionary, plan: Dictionary) -> void:
	if not lot.has("finishes"): lot.finishes=create()
	for cell: Array in plan.cells:
		var id:=key(int(cell[0]),int(cell[1]))
		if plan.finish==DEFAULTS[plan.surface]: lot.finishes[plan.surface].erase(id)
		else: lot.finishes[plan.surface][id]=str(plan.finish)
	lot.funds-=int(plan.cost); lot.revision+=1

static func is_applied(lot: Dictionary, plan: Dictionary) -> bool:
	for cell: Array in plan.cells:
		if at(lot,str(plan.surface),int(cell[0]),int(cell[1]))!=plan.finish: return false
	return true

static func remove(lot: Dictionary, surface: String, x: int, y: int) -> void:
	if lot.has("finishes") and lot.finishes.has(surface): lot.finishes[surface].erase(key(x,y))

static func valid(lot: Dictionary) -> bool:
	if not lot.has("finishes"): return true
	var data: Variant=lot.finishes
	if not data is Dictionary or data.size()!=2: return false
	for surface: String in DEFAULTS:
		if not data.get(surface) is Dictionary or data[surface].size()>256: return false
		var existing := {}
		for cell: Array in lot["floors" if surface=="floor" else "walls"]: existing[key(int(cell[0]),int(cell[1]))]=true
		for id: Variant in data[surface]:
			if not id is String or not data[surface][id] is String or not PALETTES[surface].has(data[surface][id]): return false
			var parts: PackedStringArray=id.split(",")
			if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
			var x:=int(parts[0]); var y:=int(parts[1])
			if key(x,y)!=id or not existing.has(id): return false
	return true

static func _no(message: String) -> Dictionary:
	return {"ok":false,"message":message}
