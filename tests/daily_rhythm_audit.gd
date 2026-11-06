extends SceneTree
## Reproducible 24-hour observations; writes only to an explicitly named report.
const World = preload("res://game/world.gd")
const Character = preload("res://game/character_profile.gd")

func _initialize() -> void: call_deferred("_run")

func _observe(count: int, mode: String) -> Dictionary:
	var world := World.new(); world.initialize(); world.ensure_family("audit","Alex"); world.set_online("audit",mode!="away")
	var family: Dictionary=world.state.families.audit
	while family.members.size()<count:
		var index: int=family.members.size()+1
		family.members.append(world._create_resident(family,"audit_"+str(index),"Resident "+str(index)))
	var result := {"size":count,"mode":mode,"starts":{},"idle_minutes":0.0,"minimum_need":100.0,"residents":[],"timeline":[]}
	var previous := {}; var idle := {}; var longest := {}
	for index in range(count):
		var member: Dictionary=family.members[index]
		member.autonomy=mode!="off"
		member.favorite=["reading","tea","television"][index%3]
		member.character=Character.defaults(member)
		member.character.traits=[["Bookworm"],["Outgoing"],["Homebody"]][index%3]
		previous[member.id]=""; idle[member.id]=0.0; longest[member.id]=0.0
		result.residents.append({"name":member.name,"favorite":member.favorite,"traits":member.character.traits})
	var routine_sent := false
	for tick in range(4800): # 0.1 seconds = 0.3 neighborhood minutes.
		if mode=="routine" and not routine_sent and float(world.state.day_minutes)>=1200.0:
			assert(world.apply_command("audit",{"type":"run_routine","member_id":family.members[0].id,"routine_id":"routine_2","revision":family.routines.revision}).ok)
			routine_sent=true
		world.step(0.1)
		for member: Dictionary in family.members:
			for need: String in member.needs: result.minimum_need=minf(result.minimum_need,float(member.needs[need]))
			if member.task.is_empty():
				result.idle_minutes+=0.3; idle[member.id]+=0.3; longest[member.id]=maxf(longest[member.id],idle[member.id])
			else: idle[member.id]=0.0
			var id := str(member.task.get("id",""))
			if not id.is_empty() and id!=previous[member.id]:
				var kind: String=world.task_activity(member.task,member.lot_id)
				result.starts[kind]=int(result.starts.get(kind,0))+1
				result.timeline.append({"day":world.state.day,"minute":snappedf(world.state.day_minutes,0.1),"resident":member.name,"activity":kind,"automatic":member.task.get("automatic",false)})
			previous[member.id]=id
	result.idle_minutes=snappedf(result.idle_minutes/count,0.1)
	result.minimum_need=snappedf(result.minimum_need,0.1)
	result.longest_idle_minutes=longest
	result.funds=world.state.lots.lot_1.funds
	return result

func _run() -> void:
	var report: Array=[]
	for count in [2,3,8]:
		for mode in ["on","off","routine","away"]:
			var result := _observe(count,mode)
			report.append(result)
			var summary: Dictionary=result.duplicate(); summary.erase("timeline")
			print(JSON.stringify(summary))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			assert(file!=null); file.store_string(JSON.stringify(report,"\t"))
	print("DAILY_RHYTHM_AUDIT_PASS")
	quit()
