extends RefCounted
## Review and authority share the same resale quote. Original paintings are stored.
const Catalog=preload("res://game/catalog.gd")
const Windows=preload("res://game/windows.gd")
const Finishes=preload("res://game/finishes.gd")
const Art=preload("res://game/wall_art.gd")
const Paintings=preload("res://game/paintings.gd")
static func inspect(lot: Dictionary) -> Dictionary:
	var plan: Dictionary={"ok":true,"message":"One Undo restores the whole lot and its contents.","revision":int(lot.revision),"refund":0,"furniture_refund":0,"structure_refund":0,"window_refund":0,"furnishings":lot.objects.size(),"floors":lot.floors.size(),"walls":lot.walls.size(),"doors":lot.doors.size(),"windows":lot.get("windows",{}).size(),"portions":0,"crops":0,"unfinished":[],"paintings":[],"stored":0,"new_balance":int(lot.funds)}
	for key: String in ["floors","walls","doors"]:
		plan.structure_refund+=lot[key].size()*int(Catalog.ITEMS[{"floors":"floor","walls":"wall","doors":"door"}[key]].cost*0.6)
	for style: String in lot.get("windows",{}).values(): plan.window_refund+=int(Windows.STYLES[style].cost*0.6)
	for entry: Dictionary in lot.get("artworks",{}).values():
		if int(entry.x)>=0: plan.stored+=1
	for object: Dictionary in lot.objects:
		plan.furniture_refund+=int(Catalog.ITEMS[object.kind].cost*0.6)
		if object.kind=="dining_table": plan.portions+=int(object.meal.servings)
		elif object.kind=="garden_bed" and not str(object.garden.crop).is_empty(): plan.crops+=1
		elif object.kind=="easel" and not str(object.painting.subject).is_empty():
			if Paintings.finished(object.painting):
				var original:=Art.source(lot,"easel:"+str(object.id)); plan.paintings.append(original)
			else: plan.unfinished.append({"id":str(object.id),"x":int(object.x),"y":int(object.y),"subject":str(object.painting.subject)})
	plan.refund=plan.furniture_refund+plan.structure_refund+plan.window_refund
	plan.new_balance=int(lot.funds)+int(plan.refund)
	if not lot.building: return _reject(plan,"Enter construction mode before clearing your lot.")
	if plan.furnishings+plan.floors+plan.walls+plan.doors+plan.windows==0: return _reject(plan,"The lot is already clear. Choose a saved design or build a room.")
	if not plan.unfinished.is_empty(): return _reject(plan,"%d unfinished canvas%s. Finish the painting before clearing, or remove the easel yourself. Your work stays safe here." % [plan.unfinished.size(),"" if plan.unfinished.size()==1 else "es"])
	if lot.get("artworks",{}).size()+plan.paintings.size()>Art.LIMIT: return _reject(plan,"The collection needs %d more space%s for finished paintings. Make room before clearing." % [lot.artworks.size()+plan.paintings.size()-Art.LIMIT,"" if lot.artworks.size()+plan.paintings.size()-Art.LIMIT==1 else "s"])
	for original: Dictionary in plan.paintings:
		if lot.get("artworks",{}).has(original.art_id): return _reject(plan,"A painting identity conflicts with the collection. The lot has not changed.")
	if plan.new_balance>1000000000: return _reject(plan,"This refund would exceed the household budget limit. Spend or give some funds first.")
	return plan
static func matches(command: Dictionary,plan: Dictionary) -> bool:
	return Art._integer(command.get("refund")) and int(command.refund)==int(plan.refund)
static func apply(lot: Dictionary,plan: Dictionary) -> void:
	if not lot.has("artworks"): lot.artworks={}
	for original: Dictionary in plan.paintings: lot.artworks[original.art_id]={"picture":original.picture.duplicate(true),"x":-1,"y":-1}
	for entry: Dictionary in lot.artworks.values(): entry.x=-1; entry.y=-1
	for key: String in ["floors","walls","doors","objects"]: lot[key]=[]
	lot.windows={}; lot.finishes=Finishes.create(); lot.funds+=int(plan.refund); lot.revision+=1
static func empty(lot: Dictionary) -> bool:
	return lot.get("floors",[]).is_empty() and lot.get("walls",[]).is_empty() and lot.get("doors",[]).is_empty() and lot.get("objects",[]).is_empty() and lot.get("windows",{}).is_empty()
static func _reject(plan: Dictionary,message: String) -> Dictionary:
	plan.ok=false; plan.message=message; return plan
