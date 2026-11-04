extends RefCounted
## Derive attention from accepted activities. Nothing here changes the world.
const Catalog = preload("res://game/catalog.gd")
const REST := Vector2(0.70710678,0.70710678)

static func project(direction: Vector2) -> Vector2:
	return Vector2(direction.x-direction.y,(direction.x+direction.y)*0.5)/sqrt(2.0)

static func activity(world: Dictionary, member: Dictionary) -> Dictionary:
	var lot: Dictionary=world.get("lots",{}).get(member.lot_id,{})
	if lot.is_empty() or lot.get("building",false): return {}
	var task: Dictionary=member.get("task",{})
	if _started(task):
		if task.has("meal_action"):
			var target: String=task.meal_table if task.meal_action=="eat" or task.get("meal_phase")=="serve" else task.target_id
			for object: Dictionary in lot.objects:
				if object.id==target: return {"kind":"meal_"+str(task.meal_action),"object":object}

		if task.get("target_kind")=="member":
			var partner := _member(world,str(task.get("target_id","")))
			if _near(member,partner) and _available(partner,member): return {"kind":"chat","partner":partner}
		elif task.get("target_kind")=="art":
			if preload("res://game/art_admiration.gd").current(lot,task): return {"kind":"admire_art","art":lot.artworks[task.target_id]}
		else:
			for object: Dictionary in lot.objects:
				if object.id==task.get("target_id"): return {"kind":object.kind,"object":object}
	elif task.is_empty() and member.get("queue",[]).is_empty():
		for family: Dictionary in world.get("families",{}).values():
			for other: Dictionary in family.members:
				var other_task: Dictionary=other.get("task",{})
				if _started(other_task) and other_task.get("target_kind")=="member" and other_task.get("target_id")==member.id and _near(member,other):
					return {"kind":"chat","partner":other}
	return {}

static func direction(pose: Dictionary, member: Dictionary, positions: Dictionary) -> Vector2:
	var here := _position(member,positions)+Vector2(0.5,0.5)
	if pose.has("art"): return (Vector2(float(pose.art.x)+0.5,float(pose.art.y)+0.5)-here).normalized()
	if pose.has("partner"):
		return (_position(pose.partner,positions)+Vector2(0.5,0.5)-here).normalized()
	if pose.has("object"):
		var object: Dictionary=pose.object
		if object.kind in ["sofa","bed"]: return Vector2.DOWN.rotated(int(object.get("rotation",0))*PI*0.5)
		var size := Vector2(Catalog.footprint(str(object.kind),int(object.get("rotation",0))))
		return (Vector2(float(object.x),float(object.y))+size*0.5-here).normalized()
	return Vector2.ZERO

static func _position(member: Dictionary, positions: Dictionary) -> Vector2:
	return positions.get(member.id,{}).get("position",Vector2(float(member.x),float(member.y)))

static func _started(task: Dictionary) -> bool:
	return task.get("type")=="interact" and task.get("path",[]).is_empty() and float(task.get("elapsed",0))>0

static func _near(a: Dictionary,b: Dictionary) -> bool:
	return not b.is_empty() and a.id!=b.id and a.lot_id==b.lot_id and Vector2(float(a.x),float(a.y)).distance_to(Vector2(float(b.x),float(b.y)))<=2.0

static func _available(partner: Dictionary, member: Dictionary) -> bool:
	var task: Dictionary=partner.get("task",{})
	return task.is_empty() or (task.get("target_kind")=="member" and task.get("target_id")==member.id and task.get("path",[]).is_empty())

static func _member(world: Dictionary,id: String) -> Dictionary:
	for family: Dictionary in world.get("families",{}).values():
		for member: Dictionary in family.members:
			if member.id==id: return member
	return {}
