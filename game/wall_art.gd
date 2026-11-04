extends RefCounted
## Earned artwork moves between one easel and one collection entry; never copied.
const Paintings = preload("res://game/paintings.gd")
const LIMIT := 64

static func at(lot: Dictionary,x: int,y: int) -> String:
	for id: String in lot.get("artworks",{}):
		var entry: Dictionary=lot.artworks[id]
		if int(entry.x)==x and int(entry.y)==y: return id
	return ""

static func source(lot: Dictionary,key: String) -> Dictionary:
	if key.begins_with("easel:"):
		for object: Dictionary in lot.objects:
			if object.id==key.trim_prefix("easel:") and object.kind=="easel" and Paintings.finished(object.painting):
				return {"picture":object.painting,"object_id":str(object.id),"art_id":"art_"+str(object.id)+"_"+str(int(object.painting.revision)),"location":"On easel · %d, %d" % [object.x,object.y]}
	elif key.begins_with("art:"):
		var id := key.trim_prefix("art:")
		if lot.get("artworks",{}).has(id):
			var entry: Dictionary=lot.artworks[id]
			return {"picture":entry.picture,"object_id":"","art_id":id,"location":"In collection" if int(entry.x)<0 else "On wall · %d, %d" % [entry.x,entry.y],"x":int(entry.x),"y":int(entry.y)}
	return {}

static func sources(lot: Dictionary) -> Dictionary:
	var result := {}
	for object: Dictionary in lot.objects:
		var key := "easel:"+str(object.id)
		if object.kind=="easel" and Paintings.finished(object.painting): result[key]=source(lot,key)
	for id: String in lot.get("artworks",{}): result["art:"+id]=source(lot,"art:"+id)
	return result

static func inspect(lot: Dictionary,command: Dictionary) -> Dictionary:
	if not command.get("source") is String: return _no("Choose a finished painting.")
	var chosen := source(lot,command.source)
	if chosen.is_empty(): return _no("That finished painting is no longer here. Choose from the current collection.")
	var type: String=command.get("type","")
	var plan := {"ok":true,"type":type,"source":str(command.source),"art_id":str(chosen.art_id),"object_id":str(chosen.object_id),"picture":chosen.picture.duplicate(true),"x":-1,"y":-1,"message":""}
	if type=="art_hang":
		if not _coordinate(command.get("x")) or not _coordinate(command.get("y")): return _no("Choose a wall inside the lot.")
		plan.x=int(command.x); plan.y=int(command.y)
		if not lot.walls.has([plan.x,plan.y]): return _no("Hang paintings on an existing solid wall.")
		if lot.get("windows",{}).has("%d,%d" % [plan.x,plan.y]): return _no("Choose a wall without a window.")
		var occupied := at(lot,plan.x,plan.y)
		if not occupied.is_empty(): return _no("This painting is already here." if occupied==plan.art_id else "A painting already hangs here. Choose another wall.")
		if not chosen.object_id.is_empty() and lot.get("artworks",{}).size()>=LIMIT: return _no("The collection holds 64 paintings. Return one to an empty easel to sell it first.")
		if not chosen.object_id.is_empty() and int(chosen.picture.revision)>=Paintings.MAX_REVISION: return _no("This easel has reached its activity limit.")
		plan.message="Hang “"+str(Paintings.SUBJECTS[plan.picture.subject])+"” · Free"
	elif type=="art_store":
		if not chosen.object_id.is_empty() or int(chosen.get("x",-1))<0: return _no("Choose a painting hanging on a wall.")
		plan.message="Store painting · Wall stays · Free"
	elif type=="art_return":
		if not chosen.object_id.is_empty(): return _no("This painting is already on an easel.")
		if not command.get("target_id") is String: return _no("Choose an empty easel.")
		var target := {}
		for object: Dictionary in lot.objects:
			if object.id==command.target_id and object.kind=="easel": target=object; break
		if target.is_empty() or not str(target.painting.subject).is_empty(): return _no("Choose an empty easel. Existing canvases stay in place.")
		if int(target.painting.revision)>=Paintings.MAX_REVISION: return _no("This easel has reached its activity limit.")
		plan.target_id=str(target.id); plan.picture.revision=int(target.painting.revision)+1
		plan.message="Return painting to easel · Free"
	else: return _no("Choose where to display this painting.")
	return plan

static func apply(lot: Dictionary,plan: Dictionary) -> void:
	if not lot.has("artworks"): lot.artworks={}
	if plan.type=="art_return":
		for object: Dictionary in lot.objects:
			if object.id==plan.target_id: object.painting=plan.picture.duplicate(true); break
		lot.artworks.erase(plan.art_id)
	else:
		lot.artworks[plan.art_id]={"picture":plan.picture.duplicate(true),"x":int(plan.x),"y":int(plan.y)}
		if not plan.object_id.is_empty():
			for object: Dictionary in lot.objects:
				if object.id==plan.object_id:
					var revision := int(object.painting.revision)+1
					object.painting=Paintings.create(); object.painting.revision=revision; break
	lot.revision+=1

static func reconcile(lot: Dictionary) -> int:
	var stored := 0
	for entry: Dictionary in lot.get("artworks",{}).values():
		if int(entry.x)<0: continue
		if not lot.walls.has([int(entry.x),int(entry.y)]) or lot.get("windows",{}).has("%d,%d" % [entry.x,entry.y]):
			entry.x=-1; entry.y=-1; stored+=1
	return stored

static func is_applied(lot: Dictionary,plan: Dictionary) -> bool:
	if plan.type=="art_return":
		if lot.get("artworks",{}).has(plan.art_id): return false
		for object: Dictionary in lot.objects:
			if object.id==plan.target_id: return object.painting==plan.picture
		return false
	if lot.get("artworks",{}).get(plan.art_id)!={"picture":plan.picture,"x":int(plan.x),"y":int(plan.y)}: return false
	if not plan.object_id.is_empty():
		for object: Dictionary in lot.objects:
			if object.id==plan.object_id: return str(object.painting.subject).is_empty() and int(object.painting.revision)==int(plan.picture.revision)+1
		return false
	return true

static func valid(lot: Dictionary,day: int) -> bool:
	if not lot.has("artworks"): return true
	if not lot.artworks is Dictionary or lot.artworks.size()>LIMIT: return false
	var occupied := {}; var walls := {}
	for cell: Array in lot.walls: walls["%d,%d" % [int(cell[0]),int(cell[1])]]=true
	for id: Variant in lot.artworks:
		if not id is String or id.length()>64 or not id.begins_with("art_object_"): return false
		var parts: PackedStringArray=str(id).trim_prefix("art_object_").split("_")
		if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or int(parts[0])<1 or int(parts[1])<1 or str(int(parts[0]))!=parts[0] or str(int(parts[1]))!=parts[1]: return false
		var entry: Variant=lot.artworks[id]
		if not entry is Dictionary or entry.size()!=3 or not Paintings.valid(entry.get("picture"),day) or not Paintings.finished(entry.picture): return false
		if _integer(entry.get("x")) and _integer(entry.get("y")) and int(entry.x)==-1 and int(entry.y)==-1: continue
		if not _coordinate(entry.get("x")) or not _coordinate(entry.get("y")): return false
		var key := "%d,%d" % [entry.x,entry.y]
		if occupied.has(key) or not walls.has(key) or lot.get("windows",{}).has(key): return false
		occupied[key]=true
	return true

static func _integer(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))
static func _coordinate(value: Variant) -> bool: return _integer(value) and float(value)>=0 and float(value)<16
static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
