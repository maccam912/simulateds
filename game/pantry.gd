extends RefCounted
## Household stock is independent of construction. Reservations come from accepted plans.
const Gardens=preload("res://game/gardens.gd")
const Meals=preload("res://game/meals.gd")
const CAPACITY := 12

static func create() -> Dictionary: return {"radish":0,"tomato":0}

static func ingredients(recipe: String) -> Dictionary:
	return Meals.RECIPES.get(recipe,{}).get("produce",{})

static func cost_label(recipe: String) -> String:
	var parts: PackedStringArray=[]
	for crop: String in ingredients(recipe): parts.append("%d %s" % [int(ingredients(recipe)[crop]),str(Gardens.CROPS[crop].name).to_lower()])
	return " + ".join(parts)

static func stock(world: Dictionary,owner: String,except_action: String="") -> Dictionary:
	var family: Dictionary=world.families.get(owner,{})
	var stored: Dictionary=family.get("pantry",create())
	var reserved:=create(); var incoming:=create()
	var home: Dictionary=world.lots.get(family.get("home_lot",""),{})
	for member: Dictionary in family.get("members",[]):
		if member.lot_id!=home.get("id"): continue
		var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
		for task: Dictionary in tasks:
			if task.is_empty() or task.get("id","")==except_action: continue
			if task.get("meal_action")=="prepare":
				var table:=_object(home,str(task.meal_table))
				if table.get("kind")!="dining_table" or int(table.meal.batch)!=int(task.meal_batch): continue
				for crop: String in ingredients(str(task.meal_recipe)): reserved[crop]+=int(ingredients(str(task.meal_recipe))[crop])
			elif task.get("garden_action")=="keep":
				var bed:=_object(home,str(task.target_id))
				if bed.get("kind")!="garden_bed" or int(bed.garden.revision)!=int(task.garden_revision) or not Gardens.ripe(bed.garden): continue
				incoming[bed.garden.crop]+=Gardens.HARVEST_COUNT
	var result: Dictionary={}
	for crop: String in Gardens.CROPS:
		result[crop]={"stored":int(stored[crop]),"reserved":int(reserved[crop]),"incoming":int(incoming[crop]),"available":int(stored[crop])-int(reserved[crop]),"space":CAPACITY-int(stored[crop])-int(incoming[crop])}
	return result

static func can_keep(world: Dictionary,owner: String,crop: String,except_action: String="") -> Dictionary:
	var amount: Dictionary=stock(world,owner,except_action)[crop]
	if int(amount.space)<Gardens.HARVEST_COUNT:
		return {"ok":false,"message":"The pantry holds up to %d %s. Use some or cancel a planned harvest before keeping %d more." % [CAPACITY,str(Gardens.CROPS[crop].name).to_lower(),Gardens.HARVEST_COUNT]}
	return {"ok":true,"message":"Keep %d %s for homegrown meals. No sale income." % [Gardens.HARVEST_COUNT,str(Gardens.CROPS[crop].name).to_lower()]}

static func can_cook(world: Dictionary,owner: String,recipe: String,except_action: String="") -> Dictionary:
	var required:=ingredients(recipe)
	if required.is_empty(): return {"ok":true,"message":""}
	var available:=stock(world,owner,except_action); var missing: PackedStringArray=[]
	for crop: String in required:
		var shortfall:=int(required[crop])-int(available[crop].available)
		if shortfall>0: missing.append("%d more %s" % [shortfall,str(Gardens.CROPS[crop].name).to_lower()])
	if not missing.is_empty(): return {"ok":false,"reason":"pantry","message":"Need "+" and ".join(missing)+" free in the pantry. Keep ripe crops from your garden; other meal plans reserve their ingredients."}
	return {"ok":true,"message":cost_label(recipe)+" reserved · Used only when served"}

static func keep(family: Dictionary,crop: String) -> void:
	family.pantry[crop]+=Gardens.HARVEST_COUNT

static func consume(family: Dictionary,recipe: String) -> void:
	for crop: String in ingredients(recipe): family.pantry[crop]-=int(ingredients(recipe)[crop])

static func summary(world: Dictionary,owner: String) -> String:
	var amounts:=stock(world,owner)
	return "Pantry free · %d radishes · %d tomatoes" % [int(amounts.radish.available),int(amounts.tomato.available)]

static func description(world: Dictionary,owner: String) -> String:
	var amounts:=stock(world,owner); var lines: PackedStringArray=[]
	for crop: String in Gardens.CROPS:
		var amount: Dictionary=amounts[crop]
		lines.append("%s: %d stored · %d reserved for meals · %d in planned harvests" % [str(Gardens.CROPS[crop].name),int(amount.stored),int(amount.reserved),int(amount.incoming)])
	return "\n".join(lines)+"\nUp to %d of each crop. Stored produce keeps while you are away." % CAPACITY

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=Gardens.CROPS.size(): return false
	for crop: String in Gardens.CROPS:
		if not Gardens._integer(value.get(crop),0,CAPACITY): return false
	return true

static func valid_reservations(world: Dictionary) -> bool:
	var ids := {}
	for owner: String in world.families:
		for member: Dictionary in world.families[owner].members:
			var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
			for task: Dictionary in tasks:
				if task.get("garden_action")!="keep" and not task.has("meal_action"): continue
				var prefix:=str(member.id)+":"; var id: String=task.get("id",""); var counter:=id.trim_prefix(prefix)
				if not id.begins_with(prefix) or not counter.is_valid_int() or str(int(counter))!=counter or int(counter)<1 or int(counter)>=int(member.next_action) or ids.has(id): return false
				ids[id]=true
		for amount: Dictionary in stock(world,owner).values():
			if int(amount.available)<0 or int(amount.space)<0: return false
	return true

static func normalize(value: Dictionary) -> void:
	for crop: String in Gardens.CROPS: value[crop]=int(value[crop])

static func _object(lot: Dictionary,id: String) -> Dictionary:
	for object: Dictionary in lot.get("objects",[]):
		if object.id==id: return object
	return {}
