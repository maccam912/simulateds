extends RefCounted
## Read-only choices for an exact world target. Commands still belong to the host.
const Catalog = preload("res://game/catalog.gd")
const Gardens = preload("res://game/gardens.gd")
const Paintings = preload("res://game/paintings.gd")
const Meals = preload("res://game/meals.gd")
const WallArt = preload("res://game/wall_art.gd")
const Friendships = preload("res://game/friendships.gd")
const USE_LABELS := {"bed":"Sleep", "fridge":"Have a bite", "shower":"Take a shower", "toilet":"Use bathroom", "sofa":"Relax", "tv":"Watch TV", "bookshelf":"Read a book", "plant":"Tend plant", "table":"Have some tea"}

static func options(world: RefCounted, profile_id: String, member_id: String, lot_id: String, target: Dictionary) -> Dictionary:
	var result := {"title":"Choose an action", "subtitle":"", "entries":[]}
	var family: Dictionary = world.state.get("families",{}).get(profile_id,{})
	var lot: Dictionary = world.state.get("lots",{}).get(lot_id,{})
	if family.is_empty() or lot.is_empty(): return result
	var member: Dictionary = world._member(family,member_id)
	result.subtitle = "For " + str(member.get("name","your resident"))
	var entries: Array = result.entries
	match str(target.get("type","")):
		"object":
			var object: Dictionary = world._object(lot,str(target.get("id","")))
			if object.is_empty(): return result
			result.title = str(Catalog.ITEMS.get(object.kind,{}).get("name","Furnishing"))
			match str(object.kind):
				"game_table", "stereo": _recreation(entries,world,profile_id,member_id,lot,object)
				"dining_table": _meals(entries,world,profile_id,member_id,lot,object)
				"garden_bed": _garden(entries,world,profile_id,member_id,lot,object)
				"easel": _painting(entries,world,profile_id,member_id,lot,object)
				_:
					var option := _basic_option(world,family,member,lot)
					if option.ok and not world._can_reach_object(lot,world._position(member),object): option={"ok":false,"message":"There is no path to use this furnishing."}
					if option.ok: option.message=str(Catalog.ITEMS.get(object.kind,{}).get("description","")) + " Adds to " + str(member.name) + "'s plan."
					_add(entries,"use",str(USE_LABELS.get(object.kind,"Use furnishing")),option,{"type":"interact","member_id":member_id,"lot_id":lot_id,"target_id":str(object.id)})
			_nav(entries,"inspect","Details","inspect")
		"wall_art":
			var art_id := str(target.get("id",""))
			var source := "art:"+art_id
			var art := WallArt.source(lot,source)
			if art.is_empty(): return result
			result.title = str(Paintings.SUBJECTS.get(art.picture.subject,"Painting"))
			var option: Dictionary = world.admire_option(profile_id,member_id,lot_id,art_id)
			_add(entries,"admire","Admire painting",option,{"type":"admire_art","lot_id":lot_id,"member_id":member_id,"target_id":art_id,"x":int(option.get("x",-1)),"y":int(option.get("y",-1))})
			if lot.owner==profile_id:
				_nav(entries,"hang","Arrange artwork","hang",{"source":source},"Enter build mode to arrange this original.")
			_nav(entries,"inspect","Picture & artist","inspect")
		"member", "care":
			var other: Dictionary = world._find_member(str(target.get("id","")))
			if other.is_empty() or other.lot_id!=lot_id: return result
			result.title = str(other.name)
			_resident(entries,world,profile_id,family,member,lot,other)
		"ground":
			result.title="Here"
			var cell := Vector2i(int(target.get("x",-1)),int(target.get("y",-1)))
			var option: Dictionary = world.move_option(profile_id,member_id,lot_id,cell)
			_add(entries,"walk","Queue walk" if int(option.get("ahead",0))>0 else "Walk here",option,{"type":"move","member_id":member_id,"lot_id":lot_id,"x":cell.x,"y":cell.y})
	return result

static func _add(entries: Array, id: String, label: String, option: Dictionary, command: Dictionary) -> void:
	entries.append({"id":id,"label":label,"disabled":not bool(option.get("ok",false)),"tooltip":str(option.get("message","")),"command":command})

static func _nav(entries: Array, id: String, label: String, destination: String, data: Dictionary={}, tooltip: String="") -> void:
	var entry := {"id":id,"label":label,"disabled":false,"tooltip":tooltip,"navigate":destination}
	entry.merge(data)
	entries.append(entry)

static func _basic_option(world: RefCounted, family: Dictionary, member: Dictionary, lot: Dictionary) -> Dictionary:
	if member.is_empty(): return {"ok":false,"message":"Choose one of your own residents."}
	if bool(lot.building) or bool(world.state.lots[family.home_lot].building): return {"ok":false,"message":"Finish construction before directing your family."}
	if member.lot_id!=lot.id: return {"ok":false,"message":"Visit this lot first."}
	if member.queue.size()>=8: return {"ok":false,"message":"The plan is full. Make room in Plan."}
	if int(member.next_action)>=9007199254740000: return {"ok":false,"message":"This resident has reached the activity limit."}
	return {"ok":true,"message":"Adds to this resident's plan."}

static func _recreation(entries: Array, world: RefCounted, profile: String, member: String, lot: Dictionary, object: Dictionary) -> void:
	for household: bool in [false,true]:
		var option: Dictionary = world.recreation_option(profile,member,str(lot.id),str(object.id),household)
		var choosing: bool = option.ok and not household and option.orders[0].action=="choose"
		var label := "Call household" if household else "Choose current dance" if choosing and object.kind=="stereo" else "Choose current game" if choosing else "Dance" if object.kind=="stereo" else "Play a game"
		_add(entries,"call" if household else "play",label,option,{"type":"recreation","lot_id":str(lot.id),"target_id":str(object.id),"member_id":member,"household":household,"revision":int(option.revision),"orders":option.orders.duplicate(true)})

static func _garden(entries: Array, world: RefCounted, profile: String, member: String, lot: Dictionary, object: Dictionary) -> void:
	var bed: Dictionary = object.garden
	var keys: Array = ["radish","tomato"] if str(bed.crop).is_empty() else ["harvest","keep"] if Gardens.ripe(bed) else ["water"]
	for key: String in keys:
		var action := "plant" if Gardens.CROPS.has(key) else key
		var crop := key if action=="plant" else ""
		var option: Dictionary = world.garden_option(profile,member,str(lot.id),str(object.id),action,crop)
		var label := "Plant " + str(Gardens.CROPS[key].name).to_lower() + " · §%d" % int(Gardens.CROPS[key].seed_cost) if action=="plant" else "Water crop" if key=="water" else "Keep harvest · 4" if key=="keep" else "Harvest & sell · §%d" % int(Gardens.CROPS.get(bed.crop,{}).get("harvest_value",0))
		_add(entries,key,label,option,{"type":"garden","lot_id":str(lot.id),"target_id":str(object.id),"member_id":member,"action":action,"crop":crop,"revision":int(option.get("revision",bed.revision))})

static func _painting(entries: Array, world: RefCounted, profile: String, member: String, lot: Dictionary, object: Dictionary) -> void:
	var picture: Dictionary = object.painting
	var keys: Array = Paintings.SUBJECTS.keys() if str(picture.subject).is_empty() else ["sell"] if Paintings.finished(picture) else ["resume"]
	for key: String in keys:
		var action := "start" if Paintings.SUBJECTS.has(key) else key
		var subject := key if action=="start" else ""
		var option: Dictionary = world.painting_option(profile,member,str(lot.id),str(object.id),action,subject)
		var label := "Paint " + str(Paintings.SUBJECTS[key]).to_lower() if action=="start" else "Continue painting" if action=="resume" else "Sell painting · §%d" % Paintings.VALUE
		_add(entries,key,label,option,{"type":"painting","lot_id":str(lot.id),"target_id":str(object.id),"member_id":member,"action":action,"subject":subject,"revision":int(option.get("revision",picture.revision))})
	if Paintings.finished(picture) and lot.owner==profile:
		_nav(entries,"hang","Hang on wall","hang",{"source":"easel:"+str(object.id)},"Enter build mode to hang this original.")
		# The existing art entry validates a planned sale before transferring it.
		var planned := false
		for household: Dictionary in world.state.families.values():
			for resident: Dictionary in household.members:
				if resident.lot_id!=lot.id: continue
				var tasks: Array=resident.queue.duplicate(); tasks.append(resident.task)
				if tasks.any(func(task): return task.get("target_id")==object.id and task.has("paint_action")): planned=true
		if planned: entries[-1].disabled=true; entries[-1].tooltip="Finish or cancel the planned painting activity first."

static func _meals(entries: Array, world: RefCounted, profile: String, member: String, lot: Dictionary, object: Dictionary) -> void:
	var meal: Dictionary = object.meal
	var ready: bool = not str(meal.recipe).is_empty() and int(meal.servings)>0
	var plans := Meals.plans(world.state,str(lot.id),str(object.id))
	var dining: bool = plans.any(func(plan): return plan.task.meal_action=="eat" and plan.task.meal_batch==meal.batch and plan.task.meal_recipe==meal.recipe)
	var choice: Dictionary = world.meal_option(profile,member,str(lot.id),str(object.id),"choose")
	var keys: Array = ["eat","call","clear"] if ready else ["eat","call"] if dining else Meals.RECIPES.keys()
	for key: String in keys:
		if key=="call":
			var call: Dictionary = world.meal_call_option(profile,member,str(lot.id),str(object.id))
			_add(entries,"call","Call household",call,{"type":"meal_call","action":"call","lot_id":str(lot.id),"target_id":str(object.id),"member_id":member,"batch":int(call.get("batch",meal.batch)),"orders":call.orders.duplicate(true)})
			continue
		var action := "prepare" if Meals.RECIPES.has(key) else "choose" if key=="eat" and choice.ok else key
		var option: Dictionary = choice if action=="choose" else world.meal_option(profile,member,str(lot.id),str(object.id),action,key if action=="prepare" else "")
		var label := "Prepare " + str(Meals.RECIPES[key].name).to_lower() + " · §%d" % int(Meals.RECIPES[key].cost) if action=="prepare" else "Choose this meal" if action=="choose" else "Eat a portion" if action=="eat" else "Clear leftovers"
		if key=="homegrown": label="Homegrown bowl · 2 each"
		var command := {"type":"meal","lot_id":str(lot.id),"target_id":str(object.id),"member_id":member,"action":action,"recipe":key if action=="prepare" else "","batch":int(option.get("batch",meal.batch))}
		if action=="choose": command.activity_id=str(option.activity_id)
		_add(entries,key,label,option,command)

static func _resident(entries: Array, world: RefCounted, profile: String, family: Dictionary, member: Dictionary, lot: Dictionary, other: Dictionary) -> void:
	var own: bool = not world._member(family,str(other.id)).is_empty()
	if not member.is_empty() and other.id!=member.id:
		var option := _basic_option(world,family,member,lot)
		var status: String = world.chat_status(member,str(other.id))
		if not status.is_empty(): option={"ok":false,"message":status+" · This conversation is already planned."}
		if option.ok:
			var cells: Array = world._social_cells(lot,other)
			if not cells.has(world._position(member)) and world._path(lot,world._position(member),cells).is_empty(): option={"ok":false,"message":"There is no path to chat with this resident."}
		if option.ok: option.message="Chat with "+str(other.name)+". Your existing plan stays first."
		_add(entries,"chat","Queue chat" if world._chat_busy(other,member) else "Chat",option,{"type":"interact","member_id":str(member.id),"lot_id":str(lot.id),"target_id":str(other.id)})
		var leisure: Dictionary = world.leisure_option(member,str(other.id))
		if not leisure.is_empty():
			var command := {"type":"join_dance" if leisure.kind=="stereo" else "join_meal" if leisure.kind=="dining_table" else "join_game","member_id":str(member.id),"lot_id":str(lot.id),"companion_id":str(other.id),"activity_id":str(leisure.activity_id)}
			if not str(leisure.get("own_activity_id","")).is_empty(): command.own_activity_id=str(leisure.own_activity_id)
			_add(entries,"join",str(leisure.label),{"ok":leisure.available,"message":leisure.detail},command)
		_nav(entries,"person","Relationship","person",{"target_id":str(other.id)},Friendships.title(Friendships.bond(world.state,str(member.id),str(other.id))))
	if not own: return
	if member.get("id")!=other.id: _nav(entries,"select","Select resident","select",{"member_id":str(other.id)})
	for key: String in ["needs","plan","wishes","hobbies"]:
		_nav(entries,key,{"needs":"Needs & care","plan":"Plan","wishes":"Wishes","hobbies":"Hobbies"}[key],key,{"member_id":str(other.id)})
	_nav(entries,"people","People","people",{"member_id":str(other.id)})
	if not other.task.is_empty() or not other.queue.is_empty():
		_add(entries,"cancel","Cancel actions",{"ok":true,"message":"Clear "+str(other.name)+"'s current action and plan."},{"type":"cancel","member_id":str(other.id)})
