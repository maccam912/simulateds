extends RefCounted
## Shared rectangle and placement quote for the build preview and host.
const Rules = preload("res://game/build_rules.gd")
const Catalog = preload("res://game/catalog.gd")

static func bounds(command: Dictionary) -> Rect2i:
	for key: String in ["x","y","end_x","end_y"]:
		if not Rules._coordinate(command.get(key)): return Rect2i()
	var first := Vector2i(int(command.x),int(command.y))
	var last := Vector2i(int(command.end_x),int(command.end_y))
	return Rect2i(first.min(last), (last-first).abs()+Vector2i.ONE)

static func inspect(lot: Dictionary, command: Dictionary, residents: Array) -> Dictionary:
	# Sheltered residents never veto a construction transaction. The host moves
	# anyone displaced by an accepted edit back to a safe entrance position.
	if lot.get("building",false): residents=[]
	var kind: Variant = command.get("kind")
	if kind not in ["floor","wall"]: return Rules._no("Choose floors or walls to build an area.")
	var rect := bounds(command)
	if not rect.has_area(): return Rules._no("Keep both corners inside the lot.")
	var key := "floors" if kind=="floor" else "walls"
	var cells: Array = []
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if kind=="wall" and x!=rect.position.x and x!=rect.end.x-1 and y!=rect.position.y and y!=rect.end.y-1: continue
			var cell := [x,y]
			if cell in lot.get("landscape",{}).get("pools",[]): return Rules._no("Fill the pool before building here.")
			if not Rules.flat_ground(lot,Vector2i(x,y)): return Rules._no("Flatten the terrain before building here.")
			if cell in lot[key] or (kind=="wall" and cell in lot.doors): continue
			cells.append(cell)
	if cells.is_empty(): return Rules._no("Already built. No charge.")
	var cost: int = cells.size()*int(Catalog.ITEMS[kind].cost)
	if cost>int(lot.funds): return Rules._no("Costs §%d · Need §%d more." % [cost,cost-int(lot.funds)])
	if kind=="wall":
		for cell: Array in cells:
			if cell in lot.get("stairwells",[]): return Rules._no("Keep the stairwell opening clear.")
			var position := Vector2i(cell[0],cell[1])
			if position==Vector2i(8,14): return Rules._no("Keep the lot entrance clear.")
			if position in residents or Rules._furniture_at(lot,position,""):
				return Rules._no("The wall crosses furniture or a resident.")
	var tiles := "tile" if cells.size()==1 else "tiles"
	return {"ok":true,"key":key,"cells":cells,"cost":cost,"message":"%d %s %s · §%d" % [cells.size(),kind,tiles,cost]}

static func apply(lot: Dictionary, plan: Dictionary) -> void:
	lot[plan.key].append_array(plan.cells)
	lot.funds-=plan.cost
	lot.revision+=1
