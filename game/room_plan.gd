extends RefCounted
## A bounded, pure plan used by previews and the authoritative room command.
const Rules = preload("res://game/build_rules.gd")
const Catalog = preload("res://game/catalog.gd")
const Windows = preload("res://game/windows.gd")

static func inspect(lot: Dictionary, command: Dictionary, residents: Array) -> Dictionary:
	for key: String in ["x","y","end_x","end_y"]:
		if not Rules._coordinate(command.get(key)): return _no("Keep both room corners inside the lot.")
	var rotation: Variant=command.get("rotation",0)
	if not Rules._integer(rotation) or int(rotation)<0 or int(rotation)>3: return _no("Choose a valid door side.")
	var low := Vector2i(mini(int(command.x),int(command.end_x)),mini(int(command.y),int(command.end_y)))
	var high := Vector2i(maxi(int(command.x),int(command.end_x)),maxi(int(command.y),int(command.end_y)))
	var width := high.x-low.x+1; var depth := high.y-low.y+1
	if width<3 or depth<3: return _no("Rooms need at least 3 × 3 tiles, including walls.")
	var middle := Vector2i((low.x+high.x)/2,(low.y+high.y)/2)
	var entrance: Vector2i=[Vector2i(middle.x,high.y),Vector2i(high.x,middle.y),Vector2i(middle.x,low.y),Vector2i(low.x,middle.y)][int(rotation)]
	var plan := {"ok":true,"floors":[],"walls":[],"doors":[],"remove_walls":[],"cost":0,"low":low,"high":high,"entrance":entrance,"width":width,"depth":depth}
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := [x,y]
			if not lot.floors.has(cell): plan.floors.append(cell)
			if x!=low.x and x!=high.x and y!=low.y and y!=high.y: continue
			# Existing doors always survive an extension. Only the selected new
			# doorway replaces a wall; the rest of the room preserves prior work.
			if lot.doors.has(cell): continue
			var door := Vector2i(x,y)==entrance
			if not door and lot.walls.has(cell): continue
			if residents.has(Vector2i(x,y)) or Rules._furniture_at(lot,Vector2i(x,y),""):
				return _no("The room edge crosses furniture or a resident.")
			if Vector2i(x,y)==Vector2i(8,14): return _no("Keep the lot entrance clear.")
			if door:
				plan.doors.append(cell)
				if lot.walls.has(cell): plan.remove_walls.append(cell)
			else: plan.walls.append(cell)
	plan.cost=plan.floors.size()*int(Catalog.ITEMS.floor.cost)+plan.walls.size()*int(Catalog.ITEMS.wall.cost)+plan.doors.size()*int(Catalog.ITEMS.door.cost)
	var refund := 0
	for cell: Array in plan.remove_walls: refund+=Windows.resale(lot,int(cell[0]),int(cell[1]))
	plan.cost-=refund; plan.refund=refund
	if int(plan.cost)==0: return _no("This room is already built. Choose another corner.")
	if int(plan.cost)>int(lot.funds): return _no("Room costs § %d · Need § %d more." % [plan.cost,int(plan.cost)-int(lot.funds)])
	plan.message="%d × %d room · § %d · Click to build" % [width,depth,plan.cost]
	if refund>0: plan.message+=" · Includes §%d window trade-in" % refund
	return plan

static func apply(lot: Dictionary, plan: Dictionary) -> void:
	for cell: Array in plan.remove_walls:
		lot.walls.erase(cell)
		Windows.remove(lot,int(cell[0]),int(cell[1]))
		preload("res://game/finishes.gd").remove(lot,"wall",int(cell[0]),int(cell[1]))
	for key: String in ["floors","walls","doors"]:
		for cell: Array in plan[key]: lot[key].append(cell.duplicate())
	lot.funds-=int(plan.cost)
	lot.revision+=1

static func is_applied(lot: Dictionary, plan: Dictionary) -> bool:
	for key: String in ["floors","walls","doors"]:
		for cell: Array in plan[key]:
			if not lot[key].has(cell): return false
	for cell: Array in plan.remove_walls:
		if lot.walls.has(cell): return false
	return true

static func _no(message: String) -> Dictionary:
	return {"ok":false,"message":message}
