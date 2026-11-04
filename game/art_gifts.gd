extends RefCounted
## Transfer one original through mail escrow. Claimed cards are receipts only.
const Art=preload("res://game/wall_art.gd")
const Paintings=preload("res://game/paintings.gd")

static func send_option(world: Dictionary,owner: String,command: Dictionary) -> Dictionary:
	var home: Dictionary=world.lots[world.families[owner].home_lot]
	if home.building: return _no("Finish construction before sending a painting. Your draft stays intact.")
	if not command.get("art_source") is String or not command.get("art_id") is String: return _no("Choose a finished painting to send.")
	if not Art._integer(command.get("revision")) or int(command.revision)!=int(home.revision): return _no("Your home changed. Review the painting and choose it again.")
	var chosen := Art.source(home,command.art_source)
	if chosen.is_empty() or chosen.art_id!=command.art_id: return _no("That picture changed or is no longer here. Choose a finished painting again.")
	if not str(chosen.object_id).is_empty():
		if int(chosen.picture.revision)>=Paintings.MAX_REVISION: return _no("This easel has reached its activity limit.")
		for member: Dictionary in world.families[owner].members:
			if member.lot_id!=home.id: continue
			var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
			for task: Dictionary in tasks:
				if task.get("target_id")==chosen.object_id and task.has("paint_action"): return _no("This painting is already in "+str(member.name)+"'s plan. Cancel that activity before gifting it.")
	return {"ok":true,"lot_id":str(home.id),"source":str(command.art_source),"object_id":str(chosen.object_id),"art":{"id":str(chosen.art_id),"picture":chosen.picture.duplicate(true)}}

static func detach(world: Dictionary,plan: Dictionary) -> void:
	var home: Dictionary=world.lots[plan.lot_id]
	if str(plan.object_id).is_empty(): home.artworks.erase(plan.art.id)
	else:
		for object: Dictionary in home.objects:
			if object.id==plan.object_id:
				var revision := int(object.painting.revision)+1
				object.painting=Paintings.create(); object.painting.revision=revision; break
	home.revision+=1

static func claim_option(world: Dictionary,owner: String,art: Dictionary) -> Dictionary:
	var home: Dictionary=world.lots[world.families[owner].home_lot]
	if home.building: return _no("Finish construction before collecting this painting. It will keep waiting here.")
	if home.get("artworks",{}).size()>=Art.LIMIT: return _no("Your collection holds 64 paintings. Make room; this gift will keep waiting.")
	if home.get("artworks",{}).has(art.id): return _no("This painting is already in your collection.")
	return {"ok":true,"message":"The original painting will move into your household collection."}

static func collect(world: Dictionary,owner: String,art: Dictionary) -> void:
	var home: Dictionary=world.lots[world.families[owner].home_lot]
	if not home.has("artworks"): home.artworks={}
	home.artworks[art.id]={"picture":art.picture.duplicate(true),"x":-1,"y":-1}; home.revision+=1

static func valid_payload(value: Variant,day: int) -> bool:
	return value is Dictionary and value.size()==2 and Art.valid_id(value.get("id")) and Paintings.valid(value.get("picture"),day) and Paintings.finished(value.picture)

static func valid_custody(world: Dictionary) -> bool:
	var held := {}
	for lot: Dictionary in world.lots.values():
		for entry: Dictionary in Art.sources(lot).values():
			if held.has(entry.art_id): return false
			held[entry.art_id]=true
	for family: Dictionary in world.families.values():
		for entry: Dictionary in family.get("mailbox",{}).get("items",[]):
			if not entry.has("art") or entry.claimed: continue
			if held.has(entry.art.id): return false
			held[entry.art.id]=true
	return true

static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
