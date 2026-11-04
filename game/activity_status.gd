extends RefCounted
## Read-only feedback from accepted simulation state. No presentation clock.
const World = preload("res://game/world.gd")
const Catalog = preload("res://game/catalog.gd")

static func sample(member: Dictionary, lot: Dictionary) -> Dictionary:
	var task: Dictionary=member.get("task",{})
	var action := str(member.get("action",""))
	if bool(lot.get("building",false)): return _plain("paused","The household waits while you build.")
	if action.begins_with("Waiting"): return _plain("waiting",action)
	if task.is_empty():
		if action.begins_with("Chatting"): return _plain("company",action+". Your own plans still come first.")
		return _plain("idle","A little free time. Choose an activity or click something in the house.")
	if not task.get("path",[]).is_empty(): return _plain("travel","On the way")
	if task.get("type")=="move": return _plain("travel","Arriving")
	var elapsed := maxf(0.0,float(task.get("elapsed",0.0)))
	var remaining := maxf(0.0,float(task.get("remaining",0.0)))
	var label := "Having a chat"
	if task.get("target_kind")!="member":
		var kind := ""
		for object: Dictionary in lot.get("objects",[]):
			if object.id==task.get("target_id"): kind=str(object.kind); break
		if not Catalog.ITEMS.has(kind): return _plain("unavailable","This activity is no longer available.")
		var definition: Dictionary=Catalog.ITEMS[kind]
		var need := str(definition.need)
		var rate := float(World.personal_activity_rates(member,kind).get(need,0.0))-float(World.DECAY.get(need,0.0))
		var until_full := maxf(0.0,99.0-float(member.get("needs",{}).get(need,0.0)))/maxf(0.01,rate)
		var minimum := 0.0 if task.get("automatic",false) else World.MIN_ACTIVITY_TIME
		if kind!="garden_bed": remaining=minf(remaining,maxf(until_full,maxf(0.0,minimum-elapsed)))
		label=str(World.ACTION_NAMES.get(kind,"Enjoying home"))
		if kind=="garden_bed": label=str(task.get("label","Gardening"))
		if kind=="game_table" and action=="Playing together": label="Playing together · Fun + social"
	var minutes := maxi(1,ceili(remaining*World.MINUTES_PER_SECOND))
	var detail := label+" · ~%d min left" % minutes if remaining>0.1 else "Finishing up"
	return {"phase":"activity","detail":detail,"progress":clampf(elapsed/maxf(0.001,elapsed+remaining),0.0,1.0),"remaining":remaining}

static func _plain(phase: String, detail: String) -> Dictionary:
	return {"phase":phase,"detail":detail,"progress":-1.0,"remaining":-1.0}
