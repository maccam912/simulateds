extends RefCounted
## Read-only viewing geometry. Only World assigns the resulting task reservation.
const Catalog = preload("res://game/catalog.gd")
const Access = preload("res://game/build_access.gd")
const SEATS := ["sofa","armchair","loveseat","long_sofa","wood_chair","garden_bench"]

static func front(object: Dictionary) -> Vector2:
	return Vector2.DOWN.rotated(int(object.rotation)*PI/2).snapped(Vector2.ONE)

static func center(object: Dictionary) -> Vector2:
	return Vector2(object.x,object.y)+Vector2(Catalog.footprint(object.kind,int(object.rotation)))*0.5

static func object(lot: Dictionary, id: String) -> Dictionary:
	for item: Dictionary in lot.objects:
		if item.id==id: return item
	return {}

static func obstacles(lot: Dictionary) -> Dictionary:
	# Snapshot validation precedes World's number normalization. JSON coordinates
	# are floats; Access's upper-floor membership needs canonical integer arrays.
	if int(lot.get("level",0))==0: return Access.obstacles(lot)
	var layer := lot.duplicate()
	layer.floors=[]
	for cell: Array in lot.floors: layer.floors.append([int(cell[0]),int(cell[1])])
	return Access.obstacles(layer)

static func visible_from(lot: Dictionary, tv: Dictionary, at: Vector2, seat: Dictionary={}) -> bool:
	var offset := at-center(tv)
	if offset.length()<0.8 or offset.length()>4.5 or offset.normalized().dot(front(tv))<0.65: return false
	# Conservative tile sight line: do not watch through walls or other furniture.
	var blocked := obstacles(lot)
	for ignored: Dictionary in [tv,seat]:
		if ignored.is_empty(): continue
		var size := Catalog.footprint(ignored.kind,int(ignored.rotation))
		for y in range(ignored.y,ignored.y+size.y):
			for x in range(ignored.x,ignored.x+size.x): blocked.erase(Vector2i(x,y))
	for step in range(1,41):
		var point := center(tv).lerp(at,float(step)/40.0)
		if blocked.has(Vector2i(floori(point.x),floori(point.y))): return false
	return true

static func seat_cells(lot: Dictionary, tv: Dictionary, seat: Dictionary) -> Array:
	if seat.get("kind") not in SEATS: return []
	var toward := (center(tv)-center(seat)).normalized()
	if toward.dot(front(seat))<0.85 or not visible_from(lot,tv,center(seat),seat): return []
	var size := Catalog.footprint(seat.kind,int(seat.rotation))
	var bounds := Rect2i(Vector2i(seat.x,seat.y),size)
	var blocked := obstacles(lot)
	var cells: Array=[]
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var cell := Vector2i(x,y)+Vector2i(front(seat))
			if not bounds.has_point(cell) and Access._inside(cell) and not blocked.has(cell): cells.append(cell)
	return cells

static func user(state: Dictionary, lot: Dictionary, seat_id: String, except_id: String="") -> Dictionary:
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.id==except_id or member.lot_id!=lot.id or int(member.get("level",0))!=int(lot.get("level",0)): continue
			var task: Dictionary=member.task
			if task.get("type")=="interact" and task.get("target_kind","object")=="object" and (task.get("target_id")==seat_id or task.get("tv_seat")==seat_id): return member
	return {}

static func choose(state: Dictionary, lot: Dictionary, member: Dictionary, tv: Dictionary, path: Callable) -> Dictionary:
	var occupied := {}
	for family: Dictionary in state.families.values():
		for other: Dictionary in family.members:
			if other.id==member.id or other.lot_id!=lot.id or int(other.get("level",0))!=int(member.get("level",0)): continue
			occupied[Vector2i(other.x,other.y)]=true
			var route: Array=other.task.get("path",[])
			if not route.is_empty(): occupied[Vector2i(route[-1][0],route[-1][1])]=true
	var start := Vector2i(member.x,member.y)
	var seats: Array=lot.objects.filter(func(item): return item.kind in SEATS)
	seats.sort_custom(func(a,b):
		var da := center(a).distance_squared_to(center(tv)); var db := center(b).distance_squared_to(center(tv))
		return str(a.id)<str(b.id) if is_equal_approx(da,db) else da<db)
	for seat: Dictionary in seats:
		if not user(state,lot,str(seat.id),str(member.id)).is_empty(): continue
		for cell: Vector2i in seat_cells(lot,tv,seat):
			if occupied.has(cell): continue
			if cell==start or not path.call(lot,start,[cell]).is_empty(): return {"tv_seat":seat.id,"tv_place":[cell.x,cell.y]}
	# Standing viewers use distinct reachable places on the screen's front side.
	var blocked := obstacles(lot)
	for distance in range(1,4):
		for lateral in [0,-1,1]:
			var at: Vector2 = center(tv)+front(tv)*distance+front(tv).orthogonal()*lateral
			var cell := Vector2i(floori(at.x),floori(at.y))
			if not Access._inside(cell) or blocked.has(cell) or occupied.has(cell) or not visible_from(lot,tv,at): continue
			if cell==start or not path.call(lot,start,[cell]).is_empty(): return {"tv_seat":"","tv_place":[cell.x,cell.y]}
	return {}

static func current(lot: Dictionary, task: Dictionary) -> bool:
	if not task.has("tv_place"): return false
	var tv := object(lot,str(task.target_id))
	if tv.get("kind")!="tv": return false
	var cell := Vector2i(task.tv_place[0],task.tv_place[1])
	if str(task.tv_seat).is_empty(): return not obstacles(lot).has(cell) and visible_from(lot,tv,Vector2(cell)+Vector2(0.5,0.5))
	return seat_cells(lot,tv,object(lot,str(task.tv_seat))).has(cell)

static func valid_task(task: Dictionary, active: bool) -> bool:
	if not task.has("tv_seat") and not task.has("tv_place"): return true
	if not active or task.type!="interact" or task.get("target_kind","object")!="object" or not task.get("tv_seat") is String or task.tv_seat.length()>160: return false
	if not task.get("tv_place") is Array or task.tv_place.size()!=2: return false
	for value: Variant in task.tv_place:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(value) or value<0 or value>=16: return false
	return true

static func valid_reservations(state: Dictionary) -> bool:
	var places := {}
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			var task: Dictionary=member.task
			if not task.has("tv_place"): continue
			var lot: Dictionary=preload("res://game/storeys.gd").view(state.lots[member.lot_id],int(member.get("level",0)))
			if lot.building or not current(lot,task): return false
			var route: Array=task.path
			var destination: Array=route[-1] if not route.is_empty() else [member.x,member.y]
			if Vector2i(destination[0],destination[1])!=Vector2i(task.tv_place[0],task.tv_place[1]): return false
			var key := str([lot.id,int(member.get("level",0)),Vector2i(task.tv_place[0],task.tv_place[1])])
			if places.has(key): return false
			places[key]=true
			if not str(task.tv_seat).is_empty() and not user(state,lot,str(task.tv_seat),str(member.id)).is_empty(): return false
	return true
