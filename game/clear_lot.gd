extends RefCounted
## Review and authority share the same resale quote. Original paintings are stored.
const Catalog=preload("res://game/catalog.gd")
const Windows=preload("res://game/windows.gd")
const Finishes=preload("res://game/finishes.gd")
const Art=preload("res://game/wall_art.gd")
const Paintings=preload("res://game/paintings.gd")
const STRUCTURE := {"floors":"floor","walls":"wall","doors":"door"}

static func inspect(lot: Dictionary, area: Rect2i = Rect2i(0,0,16,16)) -> Dictionary:
	var plan: Dictionary={"ok":true,"message":"One Undo restores the entire edit and its contents.","revision":int(lot.revision),"refund":0,"furniture_refund":0,"structure_refund":0,"window_refund":0,"furnishings":0,"floors":0,"walls":0,"doors":0,"windows":0,"portions":0,"crops":0,"unfinished":[],"paintings":[],"stored":0,"new_balance":int(lot.funds),"tiles":{},"objects":[]}
	plan.pools=lot.get("landscape",{}).get("pools",[]).filter(func(cell): return area.has_point(Vector2i(int(cell[0]),int(cell[1]))))
	plan.structure_refund+=plan.pools.size()*54
	for key: String in STRUCTURE:
		var tiles: Array=lot[key].filter(func(cell): return area.has_point(Vector2i(int(cell[0]),int(cell[1]))))
		plan.tiles[key]=tiles
		plan[key]=tiles.size()
		plan.structure_refund+=tiles.size()*int(Catalog.ITEMS[STRUCTURE[key]].cost*0.6)
	for cell: Array in plan.tiles.walls:
		var refund := Windows.resale(lot,int(cell[0]),int(cell[1]))
		if refund>0:
			plan.windows+=1
			plan.window_refund+=refund
	for entry: Dictionary in lot.get("artworks",{}).values():
		if area.has_point(Vector2i(int(entry.x),int(entry.y))): plan.stored+=1
	for object: Dictionary in lot.objects:
		var footprint := Catalog.footprint(str(object.kind),int(object.rotation))
		if not area.intersects(Rect2i(Vector2i(int(object.x),int(object.y)),footprint)): continue
		plan.objects.append(object)
		plan.furnishings+=1
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
	if plan.furnishings+plan.floors+plan.walls+plan.doors+plan.windows+plan.pools.size()==0: return _reject(plan,"There is nothing to clear here.")
	if not plan.unfinished.is_empty(): return _reject(plan,"%d unfinished canvas%s. Finish the painting before clearing, or remove the easel yourself. Your work stays safe here." % [plan.unfinished.size(),"" if plan.unfinished.size()==1 else "es"])
	if lot.get("artworks",{}).size()+plan.paintings.size()>Art.LIMIT: return _reject(plan,"The collection needs %d more space%s for finished paintings. Make room before clearing." % [lot.artworks.size()+plan.paintings.size()-Art.LIMIT,"" if lot.artworks.size()+plan.paintings.size()-Art.LIMIT==1 else "s"])
	for original: Dictionary in plan.paintings:
		if lot.get("artworks",{}).has(original.art_id): return _reject(plan,"A painting identity conflicts with the collection.")
	if plan.new_balance>1000000000: return _reject(plan,"This refund would exceed the household budget limit. Spend or give some funds first.")
	return plan
static func matches(command: Dictionary,plan: Dictionary) -> bool:
	return Art._integer(command.get("refund")) and int(command.refund)==int(plan.refund)
static func apply(lot: Dictionary,plan: Dictionary) -> void:
	if lot.has("landscape"):
		for cell: Array in plan.get("pools",[]): lot.landscape.pools.erase(cell)
	for cell: Array in plan.tiles.walls+plan.tiles.doors: lot.get("diagonal_walls",{}).erase("%d,%d" % [int(cell[0]),int(cell[1])])
	if not lot.has("artworks"): lot.artworks={}
	for original: Dictionary in plan.paintings: lot.artworks[original.art_id]={"picture":original.picture.duplicate(true),"x":-1,"y":-1}
	for cell: Array in plan.tiles.walls:
		Windows.remove(lot,int(cell[0]),int(cell[1]))
		Finishes.remove(lot,"wall",int(cell[0]),int(cell[1]))
	for cell: Array in plan.tiles.floors:
		Finishes.remove(lot,"floor",int(cell[0]),int(cell[1]))
	for key: String in STRUCTURE:
		lot[key]=lot[key].filter(func(cell): return cell not in plan.tiles[key])
	lot.objects=lot.objects.filter(func(object): return object not in plan.objects)
	Art.reconcile(lot)
	lot.funds+=int(plan.refund)
	lot.revision+=1
static func empty(lot: Dictionary) -> bool:
	return lot.get("landscape",{}).get("pools",[]).is_empty() and lot.get("floors",[]).is_empty() and lot.get("walls",[]).is_empty() and lot.get("doors",[]).is_empty() and lot.get("objects",[]).is_empty() and lot.get("windows",{}).is_empty()
static func _reject(plan: Dictionary,message: String) -> Dictionary:
	plan.ok=false; plan.message=message; return plan
