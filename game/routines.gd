extends RefCounted
## Small reusable activity recipes, shared by the household, not tied to objects.
const Profile = preload("res://game/household_profile.gd")
const MAX_ROUTINES := 4
const MAX_STEPS := 6
const ACTIVITIES := ["toilet","shower","fridge","bookshelf","tv","table","plant","game_table","sofa","bed","stereo"]

static func create() -> Dictionary:
	return {"revision":0,"next_id":3,"entries":[
		{"id":"routine_1","name":"Morning care","steps":["toilet","shower","fridge"]},
		{"id":"routine_2","name":"Wind down","steps":["table","bookshelf","bed"]}]}

static func find(board: Dictionary,id: String) -> Dictionary:
	for entry: Dictionary in board.get("entries",[]):
		if entry.id==id: return entry
	return {}

static func capture_plan(member: Dictionary, lot: Dictionary) -> Dictionary:
	# A local draft of accepted work, never a mutation or a new simulation order.
	# Keep every reusable step, including repeats. The editor handles the limit.
	var result := {"resident":str(member.get("name","Resident")),"steps":[],"omitted":[]}
	var tasks: Array=[]
	if not member.get("task",{}).is_empty(): tasks.append(member.task)
	tasks.append_array(member.get("queue",[]))
	var furnishings := {}
	for object: Dictionary in lot.get("objects",[]): furnishings[str(object.id)]=str(object.kind)
	for index in range(tasks.size()):
		var task: Dictionary=tasks[index]
		var reason := ""
		var kind: String=furnishings.get(str(task.get("target_id","")),"")
		if task.get("automatic",false): reason="Chosen autonomously, not part of your deliberate plan."
		elif task.get("type")=="move": reason="Walking destinations are specific to this lot."
		elif task.get("target_kind")=="member": reason="Conversations need a particular resident."
		elif task.has("garden_action") or kind=="garden_bed": reason="Garden work depends on the crop and its current condition."
		elif not kind in ACTIVITIES: reason="This furnishing is no longer available."
		if reason.is_empty(): result.steps.append(kind)
		else: result.omitted.append({"position":index+1,"title":str(task.get("title",task.get("label","Activity"))),"reason":reason})
	return result

static func valid_steps(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size()>MAX_STEPS: return false
	for step: Variant in value:
		if not step is String or not step in ACTIVITIES: return false
	return true

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3 or not _integer(value.get("revision"),0) or not _integer(value.get("next_id"),1): return false
	if not value.get("entries") is Array or value.entries.size()>MAX_ROUTINES: return false
	var seen := {}
	for entry: Variant in value.entries:
		if not entry is Dictionary or entry.size()!=3 or not valid_id(entry.get("id")) or seen.has(entry.id): return false
		if int(str(entry.id).trim_prefix("routine_"))>=int(value.next_id): return false
		if not Profile.valid_name(entry.get("name"),32) or not valid_steps(entry.get("steps")): return false
		seen[entry.id]=true
	return true

static func valid_id(value: Variant) -> bool:
	if not value is String or value.length()>32 or not value.begins_with("routine_"): return false
	var number: String=value.trim_prefix("routine_")
	return number.is_valid_int() and int(number)>0 and str(int(number))==number

static func normalize(board: Dictionary) -> void:
	board.revision=int(board.revision); board.next_id=int(board.next_id)

static func edit(family: Dictionary,command: Dictionary) -> Dictionary:
	var board: Dictionary=family.routines
	if not revision_matches(board,command.get("revision")): return _no("Routines changed. Reopen the library to see the latest version.")
	if int(board.revision)>=9007199254739999: return _no("This routine library has reached its edit limit.")
	var id: Variant=command.get("routine_id")
	if not id is String: return _no("Choose a household routine.")
	var existing := find(board,id)
	if command.type=="routine_delete":
		if existing.is_empty(): return _no("That routine is no longer saved.")
		board.entries.erase(existing); board.revision+=1
		return {"ok":true,"message":"Routine removed. Activities already in a plan will continue."}
	if not id.is_empty() and existing.is_empty(): return _no("That routine is no longer saved.")
	if id.is_empty() and board.entries.size()>=MAX_ROUTINES: return _no("Keep up to four household routines. Edit or remove one first.")
	if not Profile.valid_name(command.get("name"),32): return _no("Give this routine a name of 1 to 32 characters on one line.")
	if not valid_steps(command.get("steps")): return _no("Choose one to six care or recreation activities.")
	var entry := {"id":id,"name":str(command.name).strip_edges(),"steps":command.steps.duplicate()}
	if id.is_empty():
		if int(board.next_id)>=9007199254739999: return _no("This routine library has reached its creation limit.")
		entry.id="routine_"+str(int(board.next_id)); board.next_id+=1; board.entries.append(entry)
	else: board.entries[board.entries.find(existing)]=entry
	board.revision+=1
	return {"ok":true,"message":"Household routine saved."}

static func revision_matches(board: Dictionary,value: Variant) -> bool:
	return _integer(value,0) and int(value)==int(board.get("revision",0))

static func _integer(value: Variant,minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=minimum and float(value)<9007199254740000

static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
