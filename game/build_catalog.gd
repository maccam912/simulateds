extends RefCounted
## Presentation metadata and search; the simulation's Catalog remains authoritative.
const Catalog = preload("res://game/catalog.gd")
const Finishes = preload("res://game/finishes.gd")
const CATEGORIES := {"all":"All","structure":"Build","bedroom":"Sleep","kitchen":"Kitchen","bathroom":"Bath","living":"Living","seating":"Seating","lighting":"Lighting","garden":"Garden","finishes":"Finishes"}
const ORDER := ["room","copy_room","saved_rooms","floor","wall","door","window","bed","fridge","dining_table","shower","toilet","sofa","tv","bookshelf","table","game_table","stereo","easel","wall_art","plant","garden_bed","armchair","loveseat","long_sofa","wood_chair","garden_bench","floor_lamp","arc_lamp","globe_lamp","pendant_lamp","garden_lantern","lamp_post","linden_tree","hedge","flowers","picket_fence","boulder","stairs","diagonal_wall","pool","terrain_raise","terrain_lower","terrain_flatten","terrain_grass","terrain_dirt","terrain_sand","terrain_gravel","furniture_color","finish_floor","finish_wall","clear_lot"]
const GROUPS := {"clear_lot":"structure","saved_rooms":"structure","dining_table":"kitchen","wall_art":"finishes","easel":"living","furniture_color":"finishes","copy_room":"structure","room":"structure","floor":"structure","wall":"structure","door":"structure","window":"structure","bed":"bedroom","fridge":"kitchen","shower":"bathroom","toilet":"bathroom","sofa":"living","tv":"living","bookshelf":"living","table":"living","game_table":"living","stereo":"living","plant":"garden","garden_bed":"garden","finish_floor":"finishes","finish_wall":"finishes","armchair":"seating","loveseat":"seating","long_sofa":"seating","wood_chair":"seating","garden_bench":"seating","floor_lamp":"lighting","arc_lamp":"lighting","globe_lamp":"lighting","pendant_lamp":"lighting","garden_lantern":"lighting","lamp_post":"lighting","linden_tree":"garden","hedge":"garden","flowers":"garden","picket_fence":"garden","boulder":"garden","stairs":"structure","pool":"garden","terrain_raise":"garden","terrain_lower":"garden","terrain_flatten":"garden","terrain_grass":"garden","terrain_dirt":"garden","terrain_sand":"garden","terrain_gravel":"garden","diagonal_wall":"structure"}
const USES := {"dining_table":"Meals · Hunger + company","easel":"Painting · Fun + comfort","bed":"Energy + comfort","fridge":"Hunger · Cooking","shower":"Hygiene","toilet":"Bladder","sofa":"Comfort","tv":"Fun","bookshelf":"Fun · Reading","table":"Social","game_table":"Fun · Social together","stereo":"Fun · Social together","garden_bed":"Plant · Water · Harvest","plant":"Comfort · Gardening"}
const KEYWORDS := {"clear_lot":"bulldoze demolition demolish clear lot rebuild sell house remove all","saved_rooms":"library design blueprint saved save room reuse","dining_table":"food eat meal meals dinner lunch breakfast salad sandwiches portions cooking kitchen together pantry homegrown produce vegetables","wall_art":"painting picture gallery canvas hang display collection artwork art frame","easel":"paint canvas art artist creative recreation picture meadow harbor flowers","furniture_color":"color colour recolor repaint upholstery bedding enamel wood stain palette swatch furniture decorate","copy_room":"duplicate clone furnished room layout architecture blueprint repeat","stereo":"music dance dancing hi-fi radio speakers recreation together party","garden_bed":"grow crops seeds soil water vegetable radish tomato gardening harvest outdoors recreation pantry homegrown produce","window":"glass panes cottage picture shutters architecture wall","room":"house extension rectangle doorway", "bed":"rest sleep bedroom", "fridge":"eat food cook meal kitchen", "shower":"wash clean bathroom", "toilet":"loo wc bathroom", "sofa":"relax couch rest living", "tv":"watch television recreation", "bookshelf":"read book story leisure recreation", "table":"tea chat company dining", "game_table":"board chess checkers puzzle play games together friends recreation", "plant":"green garden gardening outdoors recreation", "finish_floor":"paint decorate wood oak walnut slate tile carpet color", "finish_wall":"paint decorate wallpaper cream sage sky rose clay ink color"}

static func entry(kind: String) -> Dictionary:
	if kind=="diagonal_wall": return {"name":"Diagonal walls","price":"§30 / tile","use":"Drag a 45° wall","description":"Drag between two points to draw a diagonal wall. Doorways can replace its tiles.","category":"structure"}
	if kind=="pool": return {"name":"Swimming pool","price":"§90 / tile","use":"Drag a water area","description":"Drag a rectangle on clear, level ground to dig a pool. Residents walk around the water; swimming is not an activity yet.","category":"garden"}
	if kind.begins_with("terrain_"):
		var action := kind.trim_prefix("terrain_")
		return {"name":action.capitalize()+" terrain","price":"§2 / tile","use":"Drag a round brush","description":"Brush the garden. Choose a brush size below. Buildings and pools keep their level foundations. One Undo restores the whole stroke.","category":"garden"}
	if kind=="wall_art": return {"name":"Wall art","price":"Free","use":"Display your paintings","description":"Hang a finished canvas on a solid wall. Move or store art, or return it to an empty easel. Undo restores the transfer; room copies leave artwork in the original home.","category":"finishes"}
	if kind=="furniture_color": return {"name":"Furniture colors","price":"Free","use":"Bedding, upholstery & more","description":"Choose a color and hover over furniture to preview its material. Click to apply. Original restores its first look; one Undo restores the previous color.","category":"finishes"}
	if kind=="clear_lot": return {"name":"Clear lot…","price":"Review refund","use":"Make room to rebuild","description":"Review the whole lot before clearing. Finished paintings move into the collection; unfinished canvases stay protected. Undo restores the entire edit.","category":"structure"}
	if kind=="saved_rooms": return {"name":"Saved rooms","price":"Your library","use":"Place a favorite design again","description":"Save up to four rooms with their furnishings, colors, finishes and windows. Placing pays the previewed price. One Undo restores the whole edit.","category":"structure"}
	if kind=="copy_room": return {"name":"Copy room","price":"Preview total","use":"Furnishings, finishes & windows","description":"Choose an enclosed room, then clear space for its copy. Rotate before placing. Fresh furnishings; crops, artwork, and residents stay in place. One Undo restores the whole placement.","category":"structure"}
	if kind=="window": return {"name":"Windows","price":"From §60","use":"Three wall-mounted styles","description":"Choose a style and an existing wall. Windows keep the wall solid. Replacements credit 60% of the old window price.","category":"structure"}
	if kind=="room": return {"name":"Room","price":"Preview price","use":"Floors + walls + a door","description":"Drag or click two opposite corners. Preview the total before building.","category":"structure"}
	if kind.begins_with("finish_"):
		var floor_finish := kind=="finish_floor"
		return {"name":"Floor finishes" if floor_finish else "Wall finishes","price":"§%d / tile" % int(Finishes.COST["floor" if floor_finish else "wall"]),"use":"Wood, tile & carpet" if floor_finish else "Six wall colors","description":"Choose a finish, then drag or click two corners to decorate existing surfaces.","category":"finishes"}
	var item: Dictionary=Catalog.ITEMS[kind]
	var footprint := Catalog.footprint(kind)
	var entry := {"name":str(item.name),"price":"§%d" % int(item.cost),"use":str(USES.get(kind,"Comfort · Seating" if item.need=="comfort" else "Warm light" if item.has("light") else "Connect floors" if kind=="stairs" else "Outdoor decoration" if item.get("outdoor",false) else "Build one tile")),"description":str(item.description),"category":GROUPS[kind],"size":"%d×%d" % [footprint.x,footprint.y],"cost":int(item.cost)}
	if kind in ["floor","wall"]:
		entry.price+=" / tile"
		entry.use="Drag to fill" if kind=="floor" else "Drag an outline"
		entry.description+=" Click for one tile or drag for an area."
	return entry

static func results(category: String, query: String) -> Array[String]:
	var found: Array[String]=[]
	var terms := query.to_lower().strip_edges().split(" ",false)
	for kind: String in ORDER:
		if category=="seating":
			if kind not in ["sofa","armchair","loveseat","long_sofa","wood_chair","garden_bench"]: continue
		elif category!="all" and GROUPS[kind]!=category and not (category=="living" and GROUPS[kind] in ["seating","lighting"]): continue
		var item := entry(kind)
		var searchable := (kind+" "+str(item.name)+" "+str(item.use)+" "+str(item.description)+" "+str(item.category)+" "+str(KEYWORDS.get(kind,""))).to_lower()
		var matches := true
		for term: String in terms:
			if not searchable.contains(term): matches=false; break
		if matches: found.append(kind)
	if not terms.is_empty():
		# Stable catalog order breaks ties; whole names/category words outrank
		# incidental substrings such as table in vegetable.
		found.sort_custom(func(a,b):
			var left := search_rank(a,query); var right := search_rank(b,query)
			return ORDER.find(a)<ORDER.find(b) if left==right else left>right)
	return found

static func search_rank(kind: String, query: String) -> int:
	var item := entry(kind)
	var name := str(item.name).to_lower()
	var words := (kind.replace("_"," ")+" "+name).split(" ",false)
	var category := (str(item.category)+" "+str(CATEGORIES[item.category])).to_lower().split(" ",false)
	var score := 1000 if query.strip_edges().to_lower() in [name,kind.replace("_"," ")] else 0
	for term: String in query.to_lower().strip_edges().split(" ",false):
		if term in words: score+=100
		elif name.contains(term): score+=50
		elif term in category: score+=30
		elif str(KEYWORDS.get(kind,"")).split(" ",false).has(term): score+=10
	if query.strip_edges().to_lower() in ["floor","wall"] and kind in ["floor","wall","finish_floor","finish_wall"]: score+=200
	return score

static func match_hint(kind: String, query: String) -> String:
	if query.strip_edges().is_empty() or search_rank(kind,query)>=30: return ""
	var item := entry(kind)
	var words := (str(item.use)+" "+str(item.description)+" "+str(KEYWORDS.get(kind,""))).to_lower().replace(".","").split(" ",false)
	for term: String in query.to_lower().strip_edges().split(" ",false):
		for word: String in words:
			if word.contains(term): return "Matches “%s” in “%s”" % [term,word]
	return "Related use: "+str(item.use)

static func requirement(kind: String) -> String:
	if not Catalog.ITEMS.has(kind): return ""
	if kind in ["floor","wall","door"]: return "Level ground · Inside lot"
	if Catalog.ITEMS[kind].get("outdoor",kind=="garden_bed"): return "Outdoors · Inside lot"
	if kind=="stairs": return "Floor below · Clear landings & upper opening"
	if kind=="easel": return "Floor beneath · Clear canvas side"
	return "Floor beneath entire footprint"
