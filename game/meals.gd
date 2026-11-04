extends RefCounted
## Portions are household property; reservations are ordinary accepted tasks.
const RECIPES := {
	"salad":{"name":"Garden salad","cost":12,"prepare":8.0,"hunger":7.0,"comfort":1.0,"color":"8eae65"},
	"sandwiches":{"name":"Sandwich platter","cost":20,"prepare":10.0,"hunger":8.0,"comfort":2.0,"color":"e2bc7c"}
}
const PORTIONS := 4
const EAT_TIME := 10.0
const SERVE_TIME := 2.0
const MAX_BATCH := 1000000000

static func create() -> Dictionary: return {"recipe":"","servings":0,"batch":0,"cook":"","cook_name":"","day":0}

static func plans(world: Dictionary,lot_id: String,table_id: String,except_action: String="") -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for family: Dictionary in world.get("families",{}).values():
		for member: Dictionary in family.members:
			if member.lot_id!=lot_id: continue
			var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
			for task: Dictionary in tasks:
				if task.has("meal_action") and task.get("meal_table")==table_id and task.get("id","")!=except_action: result.append({"member":member,"task":task})
	return result

static func available(world: Dictionary,lot: Dictionary,table: Dictionary,except_action: String="") -> int:
	var portions := int(table.meal.servings)
	for plan: Dictionary in plans(world,str(lot.id),str(table.id),except_action):
		var task: Dictionary=plan.task
		if task.meal_action=="eat" and int(task.meal_batch)==int(table.meal.batch) and not task.get("meal_taken",false): portions-=1
	return maxi(0,portions)

static func can_autoeat(world: Dictionary,lot: Dictionary,member: Dictionary) -> bool:
	var family: Dictionary=world.get("families",{}).get(lot.get("owner",""),{})
	return not lot.get("building",false) and family.get("online",false) and family.get("home_lot")==lot.id and member.get("lot_id")==lot.id and member.get("autonomy",false) and family.get("members",[]).has(member)

static func choosing(member: Dictionary,table: Dictionary) -> bool:
	var task: Dictionary=member.get("task",{})
	return task.get("automatic",false) and task.get("meal_action")=="eat" and task.get("meal_table")==table.id and task.get("meal_batch")==table.meal.batch and task.get("meal_recipe")==table.meal.recipe

static func chosen_time(task: Dictionary) -> float:
	return maxf(0.0,float(task.get("elapsed",0.0))-float(task.get("meal_chosen_at",0.0)))

static func matches_call(value: Variant,expected: Array) -> bool:
	if not value is Array or value.size()!=expected.size(): return false
	for index in range(expected.size()):
		var row: Variant=value[index]; var wanted: Dictionary=expected[index]
		if not row is Dictionary or row.size()!=5: return false
		for key: String in ["member_id","action","activity_id"]:
			if not row.get(key) is String or row[key]!=wanted[key]: return false
		if not _integer(row.get("next_action"),1,9007199254740991) or int(row.next_action)!=int(wanted.next_action): return false
		if not row.get("queue") is Array or row.queue.size()!=wanted.queue.size(): return false
		for queued in range(wanted.queue.size()):
			if not row.queue[queued] is String or row.queue[queued]!=wanted.queue[queued]: return false
	return true

static func summary(meal: Dictionary) -> String:
	if meal.recipe=="": return "Set the table for a meal"
	return str(RECIPES[meal.recipe].name)+(" · All eaten" if int(meal.servings)==0 else " · %d portions left" % int(meal.servings))

static func label(action: String,recipe: String) -> String:
	return ("Prepare " if action=="prepare" else "Eat ")+str(RECIPES.get(recipe,{}).get("name","a meal")).to_lower()

static func valid(value: Variant,day: int) -> bool:
	if not value is Dictionary or value.size()!=6 or not value.get("recipe") is String: return false
	if not _integer(value.get("servings"),0,PORTIONS) or not _integer(value.get("batch"),0,MAX_BATCH) or not _integer(value.get("day"),0,day): return false
	if not value.get("cook") is String or value.cook.length()>160 or not value.get("cook_name") is String or value.cook_name.length()>32: return false
	if value.recipe=="": return int(value.servings)==0 and value.cook=="" and value.cook_name=="" and int(value.day)==0
	return RECIPES.has(value.recipe) and int(value.batch)>0 and int(value.day)>0 and not value.cook.is_empty() and not value.cook_name.is_empty() and preload("res://game/activity_log.gd").valid_text(value.cook_name,32)

static func valid_task(task: Dictionary,active: bool) -> bool:
	if not task.get("id") is String or task.id.is_empty(): return false
	if task.get("type")!="interact" or task.get("target_kind","object")!="object": return false
	if task.get("automatic",false) and (not active or task.get("meal_action")!="eat"): return false
	if not task.get("meal_action") in ["prepare","eat"] or not RECIPES.has(task.get("meal_recipe")) or not _integer(task.get("meal_batch"),0,MAX_BATCH): return false
	if not task.get("meal_table") is String or task.meal_table.is_empty() or task.meal_table.length()>64: return false
	for key: String in ["paint_action","garden_action","routine_id"]:
		if task.has(key): return false
	if task.meal_action=="eat":
		if task.get("target_id")!=task.meal_table or task.has("meal_phase") or int(task.meal_batch)==0: return false
		if task.has("meal_taken") and (not active or not task.meal_taken is bool): return false
	elif task.has("meal_taken") or (active and not task.get("meal_phase") in ["prepare","serve"]) or (not active and task.has("meal_phase")): return false
	if active:
		var total := EAT_TIME if task.meal_action=="eat" else float(RECIPES[task.meal_recipe].prepare)+SERVE_TIME
		for key: String in ["elapsed","remaining"]:
			var value: Variant=task.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0 or float(value)>total+0.000001: return false
		if absf(float(task.elapsed)+float(task.remaining)-total)>0.00001: return false
		if task.get("meal_taken",false) and float(task.elapsed)<=0: return false
		if task.meal_action=="prepare" and task.has("social_started"): return false
	if task.has("meal_chosen_at"):
		var chosen: Variant=task.meal_chosen_at
		if not active or task.meal_action!="eat" or task.get("automatic",false) or not (chosen is int or chosen is float): return false
		if not is_finite(float(chosen)) or float(chosen)<0 or float(chosen)>float(task.elapsed): return false
	return true

static func valid_reservations(world: Dictionary) -> bool:
	var ids := {}
	for family: Dictionary in world.families.values():
		for member: Dictionary in family.members:
			var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
			for task: Dictionary in tasks:
				if not task.has("meal_action"): continue
				if task.get("automatic",false) and not can_autoeat(world,world.lots[member.lot_id],member): return false
				var prefix := str(member.id)+":"; var id: String=task.id
				var counter := id.trim_prefix(prefix)
				if not id.begins_with(prefix) or not counter.is_valid_int() or str(int(counter))!=counter or int(counter)<1 or int(counter)>=int(member.next_action) or ids.has(id): return false
				ids[id]=true
	for lot: Dictionary in world.lots.values():
		for table: Dictionary in lot.objects:
			if table.kind!="dining_table": continue
			var reserved := 0; var taken := 0; var preparations := 0
			for plan: Dictionary in plans(world,str(lot.id),str(table.id)):
				var task: Dictionary=plan.task
				if int(task.meal_batch)!=int(table.meal.batch): continue # A stale order will fail politely on its next tick.
				if task.meal_action=="prepare": preparations+=1
				else:
					if task.meal_recipe!=table.meal.recipe: return false
					if task.get("meal_taken",false): taken+=1
					else: reserved+=1
			if reserved>int(table.meal.servings) or taken>PORTIONS-int(table.meal.servings) or preparations>1: return false
			if preparations>0 and (int(table.meal.servings)>0 or reserved+taken>0): return false
	return true

static func normalize(meal: Dictionary) -> void:
	for key: String in ["servings","batch","day"]: meal[key]=int(meal[key])

static func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
