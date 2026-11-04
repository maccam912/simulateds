extends RefCounted
## Presentation metadata and search; the simulation's Catalog remains authoritative.
const Catalog = preload("res://game/catalog.gd")
const Finishes = preload("res://game/finishes.gd")
const CATEGORIES := {"all":"All","structure":"Build","bedroom":"Sleep","kitchen":"Kitchen","bathroom":"Bath","living":"Living","garden":"Garden","finishes":"Finishes"}
const ORDER := ["room","copy_room","saved_rooms","floor","wall","door","window","bed","fridge","dining_table","shower","toilet","sofa","tv","bookshelf","table","game_table","stereo","easel","wall_art","plant","garden_bed","furniture_color","finish_floor","finish_wall"]
const GROUPS := {"saved_rooms":"structure","dining_table":"kitchen","wall_art":"finishes","easel":"living","furniture_color":"finishes","copy_room":"structure","room":"structure","floor":"structure","wall":"structure","door":"structure","window":"structure","bed":"bedroom","fridge":"kitchen","shower":"bathroom","toilet":"bathroom","sofa":"living","tv":"living","bookshelf":"living","table":"living","game_table":"living","stereo":"living","plant":"garden","garden_bed":"garden","finish_floor":"finishes","finish_wall":"finishes"}
const USES := {"dining_table":"Meals · Hunger + company","easel":"Painting · Fun + comfort","bed":"Energy + comfort","fridge":"Hunger · Cooking","shower":"Hygiene","toilet":"Bladder","sofa":"Comfort","tv":"Fun","bookshelf":"Fun · Reading","table":"Social","game_table":"Fun · Social together","stereo":"Fun · Social together","garden_bed":"Plant · Water · Harvest","plant":"Comfort · Gardening"}
const KEYWORDS := {"saved_rooms":"library design blueprint saved save room reuse","dining_table":"food eat meal meals dinner lunch breakfast salad sandwiches portions cooking kitchen together","wall_art":"painting picture gallery canvas hang display collection artwork art frame","easel":"paint canvas art artist creative recreation picture meadow harbor flowers","furniture_color":"color colour recolor repaint upholstery bedding enamel wood stain palette swatch furniture decorate","copy_room":"duplicate clone furnished room layout architecture blueprint repeat","stereo":"music dance dancing hi-fi radio speakers recreation together party","garden_bed":"grow crops seeds soil water vegetable radish tomato gardening harvest outdoors recreation","window":"glass panes cottage picture shutters architecture wall","room":"house extension rectangle doorway", "bed":"rest sleep bedroom", "fridge":"eat food cook meal kitchen", "shower":"wash clean bathroom", "toilet":"loo wc bathroom", "sofa":"relax couch rest living", "tv":"watch television recreation", "bookshelf":"read book story leisure recreation", "table":"tea chat company dining", "game_table":"board chess checkers puzzle play games together friends recreation", "plant":"green garden gardening outdoors recreation", "finish_floor":"paint decorate wood oak walnut slate tile carpet color", "finish_wall":"paint decorate wallpaper cream sage sky rose clay ink color"}

static func entry(kind: String) -> Dictionary:
	if kind=="wall_art": return {"name":"Wall art","price":"Free","use":"Display your paintings","description":"Hang a finished canvas on a solid wall. Move or store art, or return it to an empty easel. Undo restores the transfer; room copies leave artwork in the original home.","category":"finishes"}
	if kind=="furniture_color": return {"name":"Furniture colors","price":"Free","use":"Bedding, upholstery & more","description":"Choose a color and hover over furniture to preview its material. Click to apply. Original restores its first look; one Undo restores the previous color.","category":"finishes"}
	if kind=="saved_rooms": return {"name":"Saved rooms","price":"Your library","use":"Place a favorite design again","description":"Save up to four rooms with their furnishings, colors, finishes and windows. Placing pays the previewed price. One Undo restores the whole edit.","category":"structure"}
	if kind=="copy_room": return {"name":"Copy room","price":"Preview total","use":"Furnishings, finishes & windows","description":"Choose an enclosed room, then clear space for its copy. Rotate before placing. Fresh furnishings; crops, artwork, and residents stay in place. One Undo restores the whole placement.","category":"structure"}
	if kind=="window": return {"name":"Windows","price":"From §60","use":"Three wall-mounted styles","description":"Choose a style and an existing wall. Windows keep the wall solid. Replacements credit 60% of the old window price.","category":"structure"}
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
