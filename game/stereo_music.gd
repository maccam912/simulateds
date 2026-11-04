extends RefCounted
## Choose one visible, actually playing stereo; snapshot refreshes do not restart it.
const Leisure = preload("res://game/shared_leisure.gd")

static func source(world: Dictionary, lot_id: String, selected: String, positions: Dictionary) -> Dictionary:
	var lot: Dictionary=world.get("lots",{}).get(lot_id,{})
	if lot.get("building",false): return {}
	var candidates: Array[Dictionary]=[]
	for object: Dictionary in lot.get("objects",[]):
		if object.kind!="stereo" or not positions.has(object.id): continue
		var dancers := Leisure.players(world,lot_id,str(object.id))
		if dancers.is_empty(): continue
		var choice := {"id":str(object.id),"position":positions[object.id],"selected":false}
		for member: Dictionary in dancers:
			if member.id==selected: choice.selected=true
		candidates.append(choice)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.selected if a.selected!=b.selected else str(a.id)<str(b.id))
	return {} if candidates.is_empty() else candidates[0]
