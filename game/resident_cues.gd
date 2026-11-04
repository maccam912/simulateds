extends RefCounted
const Wellbeing = preload("res://game/wellbeing.gd")
const Leisure = preload("res://game/shared_leisure.gd")

static func need(member: Dictionary, lot: Dictionary, world: Dictionary={}) -> Dictionary:
	var covered := {}
	if Leisure.is_shared(world,member): covered.social=true
	var tasks: Array=member.get("queue",[]).duplicate()
	if not member.get("task",{}).is_empty(): tasks.append(member.task)
	for task: Dictionary in tasks:
		if task.get("type")!="interact": continue
		var activity := "chat" if task.get("target_kind")=="member" else ""
		if activity.is_empty():
			for object: Dictionary in lot.get("objects",[]):
				if object.id==task.get("target_id"): activity=str(object.kind); break
		for key: String in Wellbeing.ORDER:
			if Wellbeing.restores(activity,key): covered[key]=true
	var result := {}
	var lowest := 30.0
	for key: String in Wellbeing.ORDER:
		var value := float(member.get("needs",{}).get(key,100.0))
		if value<lowest and not covered.has(key):
			lowest=value
			result={"need":key,"value":value,"label":Wellbeing.URGENT[key] if value<20.0 else Wellbeing.LOW[key]}
	return result

static func fit(preferred: Rect2, bounds: Rect2, occupied: Array[Rect2]) -> Rect2:
	if bounds.size.x<preferred.size.x or bounds.size.y<preferred.size.y: return Rect2()
	var gap := preferred.size.y+6.0
	for offset: Vector2 in [Vector2.ZERO,Vector2(0,-gap),Vector2(0,gap),Vector2(-preferred.size.x-6,0),Vector2(preferred.size.x+6,0),Vector2(0,-gap*2),Vector2(0,gap*2)]:
		var position := preferred.position+offset
		position.x=clampf(position.x,bounds.position.x,bounds.end.x-preferred.size.x)
		position.y=clampf(position.y,bounds.position.y,bounds.end.y-preferred.size.y)
		var candidate := Rect2(position,preferred.size)
		var overlaps := false
		for used: Rect2 in occupied:
			if candidate.grow(3).intersects(used): overlaps=true; break
		if not overlaps: return candidate
	return Rect2()
