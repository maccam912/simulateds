extends RefCounted
## Quiet recreation at the visible face of an original, mounted painting.
const Art = preload("res://game/wall_art.gd")
const Windows = preload("res://game/windows.gd")
const Paintings = preload("res://game/paintings.gd")
const DURATION := 6.0
const RATES := {"fun":4.0,"comfort":3.0}

static func cells(lot: Dictionary,entry: Dictionary,walkable: Callable) -> Array:
	if int(entry.get("x",-1))<0: return []
	var wall := Vector2i(int(entry.x),int(entry.y))
	var front := Vector2i.DOWN if Windows.along_x(lot,wall.x,wall.y) else Vector2i.RIGHT
	var result: Array=[]
	# Match the renderer's positive-facing wall surface. Never look through a wall
	# or furniture to reach a more distant viewing position.
	for distance: int in [1,2]:
		var cell := wall+front*distance
		if not walkable.call(lot,cell): break
		result.append(cell)
	return result

static func current(lot: Dictionary,task: Dictionary) -> bool:
	var entry: Dictionary=lot.get("artworks",{}).get(task.get("target_id",""),{})
	return not entry.is_empty() and int(entry.x)>=0 and int(entry.x)==int(task.get("art_x",-1)) and int(entry.y)==int(task.get("art_y",-1))

static func title(entry: Dictionary) -> String:
	return "Admire “"+str(Paintings.SUBJECTS.get(entry.get("picture",{}).get("subject",""),"painting"))+"”"

static func valid_task(task: Dictionary,active: bool) -> bool:
	if task.get("type")!="interact" or not Art.valid_id(task.get("target_id")) or task.get("automatic",false): return false
	for key: String in ["art_x","art_y"]:
		var value: Variant=task.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or float(value)<0 or float(value)>=16: return false
	for key: String in ["paint_action","garden_action","routine_id","social_started"]:
		if task.has(key): return false
	if active:
		for key: String in ["elapsed","remaining"]:
			var value: Variant=task.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0 or float(value)>DURATION+0.000001: return false
	return true
