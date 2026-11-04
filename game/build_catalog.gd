extends RefCounted
## Presentation metadata and search; the simulation's Catalog remains authoritative.
const Catalog = preload("res://game/catalog.gd")
const Finishes = preload("res://game/finishes.gd")
const CATEGORIES := {"all":"All","structure":"Build","bedroom":"Sleep","kitchen":"Kitchen","bathroom":"Bath","living":"Living","garden":"Garden","finishes":"Finishes"}
const ORDER := ["room","floor","wall","door","bed","fridge","shower","toilet","sofa","tv","bookshelf","table","plant","finish_floor","finish_wall"]
const GROUPS := {"room":"structure","floor":"structure","wall":"structure","door":"structure","bed":"bedroom","fridge":"kitchen","shower":"bathroom","toilet":"bathroom","sofa":"living","tv":"living","bookshelf":"living","table":"living","plant":"garden","finish_floor":"finishes","finish_wall":"finishes"}
const USES := {"bed":"Energy + comfort","fridge":"Hunger · Cooking","shower":"Hygiene","toilet":"Bladder","sofa":"Comfort","tv":"Fun","bookshelf":"Fun · Reading","table":"Social","plant":"Comfort · Gardening"}
const KEYWORDS := {"room":"house extension rectangle doorway", "bed":"rest sleep bedroom", "fridge":"eat food cook meal kitchen", "shower":"wash clean bathroom", "toilet":"loo wc bathroom", "sofa":"relax couch rest living", "tv":"watch television recreation", "bookshelf":"read book story leisure recreation", "table":"tea chat company dining", "plant":"green garden gardening outdoors recreation", "finish_floor":"paint decorate wood oak walnut slate tile carpet color", "finish_wall":"paint decorate wallpaper cream sage sky rose clay ink color"}

static func entry(kind: String) -> Dictionary:
	if kind=="room": return {"name":"Room · two corners","price":"Preview price","use":"Floors + walls + a door","description":"Draw two opposite corners. Preview the total before building.","category":"structure"}
	if kind.begins_with("finish_"):
		var floor_finish := kind=="finish_floor"
		return {"name":"Floor finishes" if floor_finish else "Wall finishes","price":"§%d / tile" % int(Finishes.COST["floor" if floor_finish else "wall"]),"use":"Wood, tile & carpet" if floor_finish else "Six wall colors","description":"Choose a finish, then two corners to decorate existing surfaces.","category":"finishes"}
	var item: Dictionary=Catalog.ITEMS[kind]
	var footprint := Catalog.footprint(kind)
	return {"name":str(item.name),"price":"§%d" % int(item.cost),"use":str(USES.get(kind,"Build one tile")),"description":str(item.description),"category":GROUPS[kind],"size":"%d×%d" % [footprint.x,footprint.y],"cost":int(item.cost)}

static func results(category: String, query: String) -> Array[String]:
	var found: Array[String]=[]
	var terms := query.to_lower().strip_edges().split(" ",false)
	for kind: String in ORDER:
		if category!="all" and GROUPS[kind]!=category: continue
		var item := entry(kind)
		var searchable := (kind+" "+str(item.name)+" "+str(item.use)+" "+str(item.description)+" "+str(item.category)+" "+str(KEYWORDS.get(kind,""))).to_lower()
		var matches := true
		for term: String in terms:
			if not searchable.contains(term): matches=false; break
		if matches: found.append(kind)
	return found
