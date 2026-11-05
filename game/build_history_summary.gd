extends RefCounted
## Bounded descriptions of host-accepted construction transactions.
const Catalog = preload("res://game/catalog.gd")
const Storeys = preload("res://game/storeys.gd")

static func describe(command: Dictionary, before: Dictionary, after: Dictionary) -> String:
	var type := str(command.type)
	var labels := {"place":"Place", "erase":"Sell / remove", "move_object":"Move", "build_room":"Build room", "copy_room":"Copy room", "place_blueprint":"Place saved room", "clear_lot":"Clear lot", "erase_area":"Clear area", "place_area":"Build area", "landscape":"Landscape", "paint":"Apply finish", "set_window":"Fit window", "recolor":"Recolor", "art_hang":"Hang painting", "art_store":"Store painting", "art_return":"Return painting"}
	var title := str(labels.get(type,"Building edit"))
	if Catalog.ITEMS.has(command.get("kind","")): title+=" · "+str(Catalog.ITEMS[command.kind].name)
	var changed_objects := {}
	var tiles := 0
	var finishes := 0
	var windows := 0
	var paintings := 0
	for level in range(Storeys.MAX_LEVEL+1):
		var old := Storeys.view(before,level)
		var new := Storeys.view(after,level)
		var old_objects := {}; var new_objects := {}
		for object: Dictionary in old.get("objects",[]): old_objects[object.id]=object
		for object: Dictionary in new.get("objects",[]): new_objects[object.id]=object
		for id: String in old_objects:
			if old_objects[id]!=new_objects.get(id,{}): changed_objects[id]=old_objects[id]
		for id: String in new_objects:
			if new_objects[id]!=old_objects.get(id,{}): changed_objects[id]=new_objects[id]
		for field: String in ["floors","walls","doors"]:
			for cell: Array in old.get(field,[]):
				if cell not in new.get(field,[]): tiles+=1
			for cell: Array in new.get(field,[]):
				if cell not in old.get(field,[]): tiles+=1
		for surface: String in ["floor","wall"]:
			finishes+=_changed_keys(old.get("finishes",{}).get(surface,{}),new.get("finishes",{}).get(surface,{}))
		windows+=_changed_keys(old.get("windows",{}),new.get("windows",{}))
		paintings+=_changed_keys(old.get("artworks",{}),new.get("artworks",{}))
	if not changed_objects.is_empty():
		if changed_objects.size()==1 and not Catalog.ITEMS.has(command.get("kind","")):
			title+=" · "+str(Catalog.ITEMS[changed_objects.values()[0].kind].name)
		title+=" · %d furnishing%s" % [changed_objects.size(),"" if changed_objects.size()==1 else "s"]
	if tiles>0: title+=" · %d tile%s" % [tiles,"" if tiles==1 else "s"]
	if finishes>0: title+=" · %d finished tiles" % finishes
	if windows>0: title+=" · %d windows" % windows
	if paintings>0: title+=" · %d wall paintings" % paintings
	var old_land: Dictionary=before.get("landscape",{}); var new_land: Dictionary=after.get("landscape",{})
	var ground := _changed_keys(old_land.get("heights",{}),new_land.get("heights",{}))+_changed_keys(old_land.get("paints",{}),new_land.get("paints",{}))
	for cell: Array in old_land.get("pools",[]):
		if cell not in new_land.get("pools",[]): ground+=1
	for cell: Array in new_land.get("pools",[]):
		if cell not in old_land.get("pools",[]): ground+=1
	if ground>0: title+=" · %d ground changes" % ground
	return title.left(400)

static func _changed_keys(before: Dictionary, after: Dictionary) -> int:
	var keys := before.duplicate(); keys.merge(after)
	var count := 0
	for key: Variant in keys:
		if before.get(key)!=after.get(key): count+=1
	return count

static func hint(current: Dictionary, destination: Dictionary) -> String:
	var delta := int(destination.funds)-int(current.funds)
	return str(destination.get("_edit_label","Building edit"))+"\n"+("Refund §%d" % delta if delta>0 else "Cost §%d" % -delta if delta<0 else "No cost")
