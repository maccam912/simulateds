extends RefCounted
## Copy a room's design from the accepted lot, never a client-supplied object
## payload. Preview and authority share capture, rotation, price, and access.
const Rules = preload("res://game/build_rules.gd")
const Catalog = preload("res://game/catalog.gd")
const Finishes = preload("res://game/finishes.gd")
const Windows = preload("res://game/windows.gd")
const Access = preload("res://game/build_access.gd")
const FurnitureColors = preload("res://game/furniture_colors.gd")

static func capture(lot: Dictionary, seed: Vector2i) -> Dictionary:
	var interior := Finishes.room_cells(lot,seed)
	if interior.is_empty(): return _no("Choose floor inside an enclosed room.")
	var inside := {}; var edges := {}
	for cell: Array in interior: inside[Vector2i(int(cell[0]),int(cell[1]))]=true
	for kind: String in ["walls","doors"]:
		for cell: Array in lot[kind]: edges[Vector2i(int(cell[0]),int(cell[1]))]=kind
	var region := inside.duplicate()
	for cell: Vector2i in inside:
		for direction: Vector2i in Access.DIRECTIONS:
			if not inside.has(cell+direction) and not edges.has(cell+direction): return _no("This floor is open. Enclose the room with walls and a doorway first.")
		for y in range(-1,2):
			for x in range(-1,2):
				var neighbor := cell+Vector2i(x,y)
				if edges.has(neighbor): region[neighbor]=true
	var low := seed; var high := seed
	for cell: Vector2i in region:
		low=Vector2i(mini(low.x,cell.x),mini(low.y,cell.y)); high=Vector2i(maxi(high.x,cell.x),maxi(high.y,cell.y))
	var result := {"ok":true,"low":low,"extent":high-low+Vector2i.ONE,"interior":[],"floors":[],"walls":[],"doors":[],"finishes":{"floor":{},"wall":{}},"windows":{},"objects":[],"garden":false,"art":false,"food":false}
	for cell: Array in interior: result.interior.append([int(cell[0])-low.x,int(cell[1])-low.y])
	for kind: String in ["floors","walls","doors"]:
		for cell: Array in lot[kind]:
			var position := Vector2i(int(cell[0]),int(cell[1]))
			if not region.has(position): continue
			var relative := position-low
			result[kind].append([relative.x,relative.y])
			if kind in ["floors","walls"]:
				var surface := "floor" if kind=="floors" else "wall"
				result.finishes[surface][Finishes.key(relative.x,relative.y)]=Finishes.at(lot,surface,position.x,position.y)
			if kind=="walls" and not Windows.at(lot,position.x,position.y).is_empty(): result.windows[Windows.key(relative.x,relative.y)]=Windows.at(lot,position.x,position.y)
	if result.doors.is_empty(): return _no("Add a doorway before copying this room.")
	for object: Dictionary in lot.objects:
		var size := Catalog.footprint(str(object.kind),int(object.rotation)); var count := 0
		for y in range(int(object.y),int(object.y)+size.y):
			for x in range(int(object.x),int(object.x)+size.x):
				if inside.has(Vector2i(x,y)): count+=1
		if count==0: continue
		if count!=size.x*size.y: return _no("A furnishing crosses the room boundary. Move it fully inside first.")
		var furnishing := {"kind":str(object.kind),"x":int(object.x)-low.x,"y":int(object.y)-low.y,"rotation":int(object.rotation)}
		FurnitureColors.set_style(furnishing,FurnitureColors.at(object)); result.objects.append(furnishing)
		result.garden=result.garden or object.kind=="garden_bed"
		result.art=result.art or object.kind=="easel"
		result.food=result.food or object.kind=="dining_table"
	result.message="%d × %d room · %d furnishings · Click to select" % [result.extent.x,result.extent.y,result.objects.size()]
	return result

static func rotate_cell(cell: Vector2i, extent: Vector2i, rotation: int) -> Vector2i:
	match rotation:
		1: return Vector2i(extent.y-1-cell.y,cell.x)
		2: return extent-Vector2i.ONE-cell
		3: return Vector2i(cell.y,extent.x-1-cell.x)
	return cell

static func inspect(lot: Dictionary, command: Dictionary, residents: Array) -> Dictionary:
	for key: String in ["source_x","source_y","x","y"]:
		if not Rules._coordinate(command.get(key)): return _no("Choose a source room and a position inside this lot.")
	if not Rules._integer(command.get("rotation",0)) or int(command.get("rotation",0))<0 or int(command.get("rotation",0))>3: return _no("Choose a valid rotation.")
	var source := capture(lot,Vector2i(int(command.source_x),int(command.source_y)))
	if not source.ok: return source
	return inspect_source(lot,command,residents,source)

static func inspect_source(lot: Dictionary,command: Dictionary,residents: Array,source: Dictionary) -> Dictionary:
	for key: String in ["x","y"]:
		if not Rules._coordinate(command.get(key)): return _no("Keep the saved room inside this lot.")
	if not Rules._integer(command.get("rotation",0)) or int(command.get("rotation",0))<0 or int(command.get("rotation",0))>3: return _no("Choose a valid rotation.")
	if not source.get("ok",false): return _no("Choose a valid room design.")
	var rotation := int(command.get("rotation",0)); var at := Vector2i(int(command.x),int(command.y))
	var extent: Vector2i=Vector2i(source.extent.y,source.extent.x) if rotation%2 else source.extent
	var plan := {"ok":true,"source":source,"low":at,"extent":extent,"interior":[],"floors":[],"walls":[],"doors":[],"objects":[],"finishes":{"floor":{},"wall":{}},"windows":{},"structure_cost":0,"furniture_cost":0,"finish_cost":0,"window_cost":0,"cost":0,"garden":source.garden,"art":source.art,"food":source.food}
	if at.x+extent.x>16 or at.y+extent.y>16: return _reject(plan,"Keep the whole copied room inside the lot.")
	for kind: String in ["interior","floors","walls","doors"]:
		for cell: Array in source[kind]:
			var point := at+rotate_cell(Vector2i(int(cell[0]),int(cell[1])),source.extent,rotation)
			plan[kind].append([point.x,point.y])
	var touched := {}
	for kind: String in ["interior","floors","walls","doors"]:
		for cell: Array in plan[kind]: touched[Vector2i(int(cell[0]),int(cell[1]))]=true
	for cell: Vector2i in touched:
		if lot.walls.has([cell.x,cell.y]) or lot.doors.has([cell.x,cell.y]) or Rules._furniture_at(lot,cell,""): return _reject(plan,"Choose clear space. Existing walls, doorways, and furniture stay in place.")
	for kind: String in ["walls","doors"]:
		for cell: Array in plan[kind]:
			if Vector2i(int(cell[0]),int(cell[1]))==Access.GATE: return _reject(plan,"Keep the lot entrance clear.")
			if residents.has(Vector2i(int(cell[0]),int(cell[1]))): return _reject(plan,"A resident is standing on the copied room edge.")
	for item: Dictionary in source.objects:
		var object := item.duplicate(true)
		var size := Catalog.footprint(str(item.kind),int(item.rotation)); var low := Vector2i(16,16)
		for y in range(int(item.y),int(item.y)+size.y):
			for x in range(int(item.x),int(item.x)+size.x):
				var point := at+rotate_cell(Vector2i(x,y),source.extent,rotation)
				if residents.has(point): return _reject(plan,"A resident is standing where copied furniture would go.")
				low=Vector2i(mini(low.x,point.x),mini(low.y,point.y))
		object.x=low.x; object.y=low.y; object.rotation=(int(item.rotation)+rotation)%4
		object.id="copy_preview_%d" % plan.objects.size()
		plan.objects.append(object); plan.furniture_cost+=int(Catalog.ITEMS[object.kind].cost)
	for kind: String in ["floors","walls","doors"]:
		for cell: Array in plan[kind]:
			if not lot[kind].has(cell): plan.structure_cost+=int(Catalog.ITEMS[{"floors":"floor","walls":"wall","doors":"door"}[kind]].cost)
	for surface: String in ["floor","wall"]:
		for key: String in source.finishes[surface]:
			var parts := key.split(","); var point := at+rotate_cell(Vector2i(int(parts[0]),int(parts[1])),source.extent,rotation)
			var finish: String=source.finishes[surface][key]
			plan.finishes[surface][Finishes.key(point.x,point.y)]=finish
			if Finishes.at(lot,surface,point.x,point.y)!=finish: plan.finish_cost+=int(Finishes.COST[surface])
	for key: String in source.windows:
		var parts := key.split(","); var point := at+rotate_cell(Vector2i(int(parts[0]),int(parts[1])),source.extent,rotation)
		var style: String=source.windows[key]
		plan.windows[Windows.key(point.x,point.y)]=style; plan.window_cost+=int(Windows.STYLES[style].cost)
	plan.cost=int(plan.structure_cost)+int(plan.furniture_cost)+int(plan.finish_cost)+int(plan.window_cost)
	if plan.cost>int(lot.funds): return _reject(plan,"Copy costs §%d · Need §%d more." % [plan.cost,int(plan.cost)-int(lot.funds)])
	var draft := lot.duplicate(true)
	apply_surfaces(draft,plan); draft.objects.append_array(plan.objects)
	var people: Array=[]
	for position: Vector2i in residents: people.append({"id":str(position),"name":"Resident","x":position.x,"y":position.y})
	plan.access=Access.inspect(draft,people)
	if not plan.access.ok: return _reject(plan,"Access needs work: "+str(plan.access.message))
	plan.message="%d × %d room copy · %d furnishings · §%d · Click to place" % [extent.x,extent.y,plan.objects.size(),plan.cost]
	return plan

static func apply_surfaces(lot: Dictionary, plan: Dictionary) -> void:
	for kind: String in ["floors","walls","doors"]:
		for cell: Array in plan[kind]:
			if not lot[kind].has(cell): lot[kind].append(cell.duplicate())
	if not lot.has("finishes"): lot.finishes=Finishes.create()
	for surface: String in ["floor","wall"]:
		for key: String in plan.finishes[surface]:
			if plan.finishes[surface][key]==Finishes.DEFAULTS[surface]: lot.finishes[surface].erase(key)
			else: lot.finishes[surface][key]=plan.finishes[surface][key]
	if not lot.has("windows"): lot.windows={}
	lot.windows.merge(plan.windows,true)

static func is_applied(lot: Dictionary, plan: Dictionary) -> bool:
	for kind: String in ["floors","walls","doors"]:
		for cell: Array in plan[kind]:
			if not lot[kind].has(cell): return false
	for surface: String in ["floor","wall"]:
		for key: String in plan.finishes[surface]:
			var parts := key.split(",")
			if Finishes.at(lot,surface,int(parts[0]),int(parts[1]))!=plan.finishes[surface][key]: return false
	for key: String in plan.windows:
		if lot.get("windows",{}).get(key)!=plan.windows[key]: return false
	for object: Dictionary in plan.objects:
		if not lot.objects.any(func(item): return item.kind==object.kind and int(item.x)==int(object.x) and int(item.y)==int(object.y) and int(item.rotation)==int(object.rotation) and FurnitureColors.at(item)==FurnitureColors.at(object)): return false
	return true

static func _reject(plan: Dictionary, message: String) -> Dictionary:
	plan.ok=false; plan.message=message; return plan

static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
