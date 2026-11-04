extends RefCounted
## Read-only household garden discovery; every activity still goes through its bed.
const Gardens=preload("res://game/gardens.gd")
const Pantry=preload("res://game/pantry.gd")

static func inspect(world: Dictionary,owner: String) -> Dictionary:
	var family: Dictionary=world.get("families",{}).get(owner,{})
	var home: Dictionary=world.get("lots",{}).get(family.get("home_lot",""),{})
	if home.is_empty(): return {}
	var amounts:=Pantry.stock(world,owner); var rows: Array[Dictionary]=[]
	for object: Dictionary in home.objects:
		if object.kind!="garden_bed": continue
		var bed: Dictionary=object.garden; var planted: bool=bed.crop!=""
		var title: String=(str(Gardens.CROPS[bed.crop].name)+" · Bed" if planted else "Garden bed")+" %d" % (rows.size()+1)
		var status: String=Gardens.summary(bed).split(" · ")[-1]
		var detail: String=Gardens.summary(bed)+"\nDry plants and ripe crops wait safely."
		if planted and not Gardens.ripe(bed) and float(bed.water)>0:
			status+=" · Water %d%%" % ceili(float(bed.water)/Gardens.WATER_CAP*100)
		if Gardens.ripe(bed):
			var room:=Pantry.can_keep(world,owner,str(bed.crop))
			status="Ready · Sell or keep" if room.ok else "Ready · Pantry needs room"
			detail="Keep %d %s or sell for §%d.\n" % [Gardens.HARVEST_COUNT,str(Gardens.CROPS[bed.crop].name).to_lower(),int(Gardens.CROPS[bed.crop].harvest_value)]+str(room.message)
		var plan:=_plan(world,home,object)
		if not plan.is_empty():
			status="Planned · "+str(plan.name).left(18)
			detail+="\n"+str(plan.name)+": "+Gardens.label(str(plan.action),str(plan.crop))
		if home.building: status="Construction · Growth paused"
		rows.append({"id":str(object.id),"lot_id":str(home.id),"title":title,"status":status,"tooltip":detail,"available":not home.building,"plan":plan})
	return {"home":str(home.id),"name":str(home.name),"building":bool(home.building),"rows":rows,"stock":amounts,"bowls":mini(int(amounts.radish.available)/2,int(amounts.tomato.available)/2),"has_table":home.objects.any(func(object): return object.kind=="dining_table")}

static func _plan(world: Dictionary,home: Dictionary,object: Dictionary) -> Dictionary:
	for family: Dictionary in world.families.values():
		for member: Dictionary in family.members:
			if member.lot_id!=home.id: continue
			var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
			for task: Dictionary in tasks:
				if task.get("target_id")==object.id and task.has("garden_action") and int(task.garden_revision)==int(object.garden.revision):
					return {"name":str(member.name),"action":str(task.garden_action),"crop":str(task.crop) if task.garden_action=="plant" else str(object.garden.crop)}
	return {}
