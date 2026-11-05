extends RefCounted
## Bounded, atomic brush and pool quotes shared by previews and host commands.
const Rules = preload("res://game/build_rules.gd")
const Area = preload("res://game/build_area.gd")
const PAINTS := {"grass":"8da772","dirt":"9b805e","sand":"d7c69e","gravel":"a9aaa0"}
const TOOLS := ["pool","terrain_raise","terrain_lower","terrain_flatten","terrain_grass","terrain_dirt","terrain_sand","terrain_gravel","diagonal_wall"]

static func key(x: int,y: int) -> String: return "%d,%d" % [x,y]
static func height(lot: Dictionary,x: int,y: int) -> float:
	return float(lot.get("landscape",{}).get("heights",{}).get(key(x,y),0.0))
static func pooled(lot: Dictionary,x: int,y: int) -> bool:
	return [x,y] in lot.get("landscape",{}).get("pools",[])
static func empty() -> Dictionary: return {"heights":{},"paints":{},"pools":[]}

static func encode_stroke(points: Array) -> String:
	# Two hex digits per tile keep a complete 256-point stroke within a peer packet.
	var encoded := ""
	for point: Array in points: encoded+="%x%x" % [int(point[0]),int(point[1])]
	return encoded

static func inspect(lot: Dictionary,command: Dictionary) -> Dictionary:
	var kind: String=str(command.get("kind",""))
	if kind not in TOOLS: return Rules._no("Choose a garden or wall tool.")
	var rect := Area.bounds(command)
	if not rect.has_area(): return Rules._no("Keep the stroke inside the lot.")
	if kind!="diagonal_wall" and int(lot.get("level",0))>0: return Rules._no("Garden tools belong on the ground floor.")
	var radius: Variant=command.get("radius",1)
	if not Rules._integer(radius) or int(radius)<1 or int(radius)>3: return Rules._no("Choose a brush size from 1 to 3.")
	var first := Vector2i(int(command.x),int(command.y))
	var last := Vector2i(int(command.end_x),int(command.end_y))
	var cells: Array=[]
	if kind=="pool":
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x): cells.append([x,y])
	else:
		var points: Variant=command.get("points",[[first.x,first.y],[last.x,last.y]])
		if command.has("stroke"):
			if not command.stroke is String or command.stroke.is_empty() or command.stroke.length()>512 or command.stroke.length()%2!=0: return Rules._no("Choose a valid terrain stroke.")
			for digit: String in command.stroke:
				if not "0123456789abcdef".contains(digit): return Rules._no("Choose a valid terrain stroke.")
			points=[]
			for index in range(0,command.stroke.length(),2): points.append([command.stroke.substr(index,1).hex_to_int(),command.stroke.substr(index+1,1).hex_to_int()])
		if not points is Array or points.is_empty() or points.size()>256: return Rules._no("Keep the brush stroke within 256 points.")
		for point: Variant in points:
			if not point is Array or point.size()!=2 or not Rules._coordinate(point[0]) or not Rules._coordinate(point[1]): return Rules._no("Keep the brush stroke inside the lot.")
		if kind=="diagonal_wall": points=[[first.x,first.y],[last.x,last.y]]
		if kind=="diagonal_wall" and (first==last or absi(last.x-first.x)!=absi(last.y-first.y)):
			return Rules._no("Drag equal distances across and down for a 45° wall.")
		var previous := first
		for point: Array in points:
			var next := Vector2i(int(point[0]),int(point[1]))
			var length := maxi(absi(next.x-previous.x),absi(next.y-previous.y))
			for step in range(length+1):
				var center := Vector2i(Vector2(previous).lerp(Vector2(next),float(step)/maxi(1,length)).round())
				var r := 0 if kind=="diagonal_wall" else int(radius)-1
				for y in range(maxi(0,center.y-r),mini(16,center.y+r+1)):
					for x in range(maxi(0,center.x-r),mini(16,center.x+r+1)):
						if Vector2(x,y).distance_to(Vector2(center))<=float(r)+0.3 and [x,y] not in cells: cells.append([x,y])
			previous=next

	var changes: Array=[]
	var action := kind.trim_prefix("terrain_")
	for cell: Array in cells:
		var x: int=cell[0]; var y: int=cell[1]; var at := Vector2i(x,y)
		if kind=="diagonal_wall":
			if cell in lot.walls or cell in lot.doors: continue
			if cell in lot.get("stairwells",[]) or not Rules.flat_ground(lot,at): return Rules._no("Keep the wall on level ground and clear of stairs.")
			if at==Vector2i(8,14) or Rules._furniture_at(lot,at,"") or pooled(lot,x,y): return Rules._no("Keep the wall clear of furniture, water and the entrance.")
			changes.append(cell)
		elif kind=="pool":
			if pooled(lot,x,y): continue
			if cell in lot.floors or cell in lot.walls or cell in lot.doors or Rules._furniture_at(lot,at,"") or at==Vector2i(8,14) or height(lot,x,y)!=0:
				return Rules._no("A pool needs clear, flat garden ground.")
			changes.append(cell)
		else:
			# Foundation protection includes neighboring vertices of the smooth hill.
			var protected := pooled(lot,x,y) or at==Vector2i(8,14)
			for yy in range(maxi(0,y-1),mini(16,y+2)):
				for xx in range(maxi(0,x-1),mini(16,x+2)):
					if [xx,yy] in lot.floors or [xx,yy] in lot.walls or [xx,yy] in lot.doors or pooled(lot,xx,yy): protected=true
			if protected: continue
			if PAINTS.has(action):
				if lot.get("landscape",{}).get("paints",{}).get(key(x,y),"grass")!=action: changes.append(cell)
			else:
				var before := height(lot,x,y)
				var after := 0.0 if action=="flatten" else clampf(before+(0.25 if action=="raise" else -0.25),-0.75,1.5)
				if before!=after: changes.append([x,y,after])
	if changes.is_empty(): return Rules._no("No change here. Foundations stay level; no charge.")
	var cost := changes.size()*(90 if kind=="pool" else 30 if kind=="diagonal_wall" else 2)
	var plan := {"ok":cost<=int(lot.funds),"kind":kind,"cells":changes,"cost":cost,"slope":1 if (last.x-first.x)*(last.y-first.y)>0 else -1,"message":"%d tiles · §%d" % [changes.size(),cost]}
	if not plan.ok: plan.message+=" · Need §%d more" % (cost-int(lot.funds))
	return plan

static func apply(lot: Dictionary,plan: Dictionary) -> void:
	if not lot.has("landscape"): lot.landscape=empty()
	if not lot.has("diagonal_walls"): lot.diagonal_walls={}
	for cell: Array in plan.cells:
		var id := key(int(cell[0]),int(cell[1]))
		if plan.kind=="diagonal_wall":
			lot.walls.append(cell); lot.diagonal_walls[id]=int(plan.slope)
		elif plan.kind=="pool": lot.landscape.pools.append(cell)
		elif PAINTS.has(str(plan.kind).trim_prefix("terrain_")):
			lot.landscape.paints[id]=str(plan.kind).trim_prefix("terrain_")
		elif float(cell[2])==0: lot.landscape.heights.erase(id)
		else: lot.landscape.heights[id]=float(cell[2])
	lot.funds-=int(plan.cost); lot.revision+=1

static func valid(lot: Dictionary) -> bool:
	var data: Variant=lot.get("landscape",empty())
	if not data is Dictionary or data.size()!=3 or not data.get("pools") is Array or data.pools.size()>256: return false
	var seen := {}
	for cell: Variant in data.pools:
		if not cell is Array or cell.size()!=2 or not Rules._coordinate(cell[0]) or not Rules._coordinate(cell[1]): return false
		var id := key(int(cell[0]),int(cell[1]))
		if seen.has(id): return false
		seen[id]=true
		if [int(cell[0]),int(cell[1])] in lot.floors or [int(cell[0]),int(cell[1])] in lot.walls or Rules._furniture_at(lot,Vector2i(cell[0],cell[1]),""): return false
	for field: String in ["heights","paints","diagonal_walls"]:
		var entries: Variant=lot.get(field,{}) if field=="diagonal_walls" else data.get(field)
		if not entries is Dictionary or entries.size()>256: return false
		for id: Variant in entries:
			if not id is String: return false
			var parts: PackedStringArray=id.split(",")
			if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
			var x := int(parts[0]); var y := int(parts[1])
			if not Rules._coordinate(x) or not Rules._coordinate(y) or id!=key(x,y): return false
			var value: Variant=entries[id]
			if field=="heights":
				if not (value is float or value is int) or not is_finite(float(value)) or float(value)<-0.75 or float(value)>1.5 or fmod(float(value),0.25)!=0: return false
			elif field=="paints":
				if not value is String or not PAINTS.has(value): return false
			elif value not in [-1,1] or ([x,y] not in lot.walls and [x,y] not in lot.doors): return false
	return true
