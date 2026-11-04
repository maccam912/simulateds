extends RefCounted
## A travel preview binds to each selected resident's actual location and plan.
static func stamp(member: Dictionary) -> Dictionary:
	return {"member_id":str(member.id),"lot_id":str(member.lot_id),"next_action":int(member.next_action),"activity_id":str(member.task.get("id","")),"queue":member.queue.map(func(task): return str(task.id))}

static func matches(value: Variant,expected: Array) -> bool:
	if not value is Array or value.size()!=expected.size(): return false
	for index in range(expected.size()):
		var row: Variant=value[index]; var wanted: Dictionary=expected[index]
		if not row is Dictionary or row.size()!=5: return false
		for key: String in ["member_id","lot_id","activity_id"]:
			if not row.get(key) is String or row[key]!=wanted[key]: return false
		var counter: Variant=row.get("next_action")
		if not (counter is int or counter is float) or not is_finite(float(counter)) or float(counter)!=floor(float(counter)) or float(counter)<1 or float(counter)>9007199254740000 or int(counter)!=int(wanted.next_action): return false
		if not row.get("queue") is Array or row.queue.size()!=wanted.queue.size(): return false
		for queued in range(wanted.queue.size()):
			if not row.queue[queued] is String or row.queue[queued]!=wanted.queue[queued]: return false
	return true
