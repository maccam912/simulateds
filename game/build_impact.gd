extends RefCounted
## Read-only consequences of an already validated draft edit. Placement remains
## flexible; the existing authoritative access check still guards publication.
const Access = preload("res://game/build_access.gd")
const RoomPlan = preload("res://game/room_plan.gd")

static func inspect(lot: Dictionary, command: Dictionary, plan: Dictionary, residents: Array) -> Dictionary:
	if not plan.get("ok",false) or not command.get("type") in ["place","move_object","build_room"]: return {}
	var draft := lot.duplicate(true)
	if command.type=="build_room": RoomPlan.apply(draft,plan)
	elif command.type=="move_object":
		for object: Dictionary in draft.objects:
			if object.id==command.object_id:
				object.x=int(command.x); object.y=int(command.y); object.rotation=int(plan.rotation); break
	else:
		var cell := [int(command.x),int(command.y)]
		if plan.kind in ["floor","wall","door"]:
			if plan.kind=="wall": draft.doors.erase(cell)
			elif plan.kind=="door": draft.walls.erase(cell)
			draft[{"floor":"floors","wall":"walls","door":"doors"}[plan.kind]].append(cell)
		else:
			draft.objects.append({"id":"placement_preview","kind":str(plan.kind),"x":int(command.x),"y":int(command.y),"rotation":int(plan.rotation)})
	var before := Access.inspect(lot,residents); var after := Access.inspect(draft,residents)
	var previous := {}; var current := {}
	for issue: Dictionary in before.issues: previous[issue.key]=issue
	for issue: Dictionary in after.issues: current[issue.key]=issue
	var introduced: Array=[]; var resolved: Array=[]; var lost_floor: Array=[]
	for key: String in current:
		if not previous.has(key): introduced.append(current[key])
	for key: String in previous:
		if not current.has(key): resolved.append(previous[key])
	for cell: Vector2i in after.unreachable:
		if before.reachable.has(cell): lost_floor.append(cell)
	var message := ""
	if not introduced.is_empty():
		message="Would block "+str(introduced[0].name)
		if introduced.size()>1: message+=" + %d more" % (introduced.size()-1)
		message+="\nDraft placement allowed · Restore access before finishing"
	elif not resolved.is_empty():
		message="Restores access · Ready to finish" if after.ok else "Restores access to %d · " % resolved.size()+("1 issue remains" if after.issues.size()==1 else "%d issues remain" % after.issues.size())
	elif not after.ok:
		message="Existing access issue · "+str(after.issues[0].name)
		if after.issues.size()>1: message+=" + %d more" % (after.issues.size()-1)
	return {"ok":bool(after.ok),"introduced":introduced,"resolved":resolved,"after":after,"lost_floor":lost_floor,"message":message,"warning":not after.ok}
