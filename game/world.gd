extends RefCounted
## Pure host-owned simulation: no networking, Nodes, clocks, or filesystem access.
## Commands are the only external mutations; the whole state is JSON-compatible.
const Catalog = preload("res://game/catalog.gd")
const GRID_SIZE := 16
const SCHEMA := 1
const MAX_FAMILIES := 4
const MAX_QUEUE := 8
const NEEDS := ["hunger", "energy", "hygiene", "bladder", "fun", "social", "comfort"]
const DECAY := {"hunger":0.13, "energy":0.08, "hygiene":0.10, "bladder":0.15, "fun":0.12, "social":0.09, "comfort":0.07}
const ACTION_NAMES := {"bed":"Sleeping", "fridge":"Making a meal", "shower":"Showering", "toilet":"Using the bathroom", "sofa":"Relaxing", "tv":"Watching television", "bookshelf":"Reading", "plant":"Tending plants", "table":"Having tea"}
const DIRECTIONS := [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
var state: Dictionary = {}
var _build_backups: Dictionary = {}

func initialize() -> void:
	state = {"schema":SCHEMA, "tick":0, "day":1, "day_minutes":480.0, "lots":{}, "families":{}, "events":[], "next_object":1}
	_build_backups.clear()
	var names := ["Clover Cottage", "Willow House", "Juniper Place", "Maple Corner"]
	for index in range(MAX_FAMILIES):
		var id := "lot_%d" % (index + 1)
		var lot := {"id":id, "name":names[index], "owner":"", "funds":12000, "building":false, "revision":0, "floors":[], "walls":[], "doors":[], "objects":[]}
		for y in range(3, 12):
			for x in range(3, 13):
				lot.floors.append([x,y])
				if x == 3 or x == 12 or y == 3 or y == 11:
					if x == 8 and y == 11:
						lot.doors.append([x,y])
					else:
						lot.walls.append([x,y])
		for item in [["bed",4,4], ["bed",6,4], ["fridge",10,4], ["shower",11,6], ["toilet",11,8], ["sofa",4,8], ["tv",4,10], ["bookshelf",10,10], ["plant",10,6], ["table",7,8]]:
			lot.objects.append(_new_object(str(item[0]), int(item[1]), int(item[2]), 0))
		state.lots[id] = lot

func ensure_family(profile_id: String, display_name: String) -> String:
	if profile_id.is_empty() or profile_id.length() > 128:
		return ""
	if state.families.has(profile_id):
		return str(state.families[profile_id].home_lot)
	for lot_id: String in state.lots:
		var lot: Dictionary = state.lots[lot_id]
		if not str(lot.owner).is_empty():
			continue
		var clean_name := display_name.strip_edges().left(24)
		if clean_name.is_empty():
			clean_name = "Neighbor"
		lot.owner = profile_id
		var members: Array = []
		for index in range(2):
			var needs := {}
			for need: String in NEEDS:
				needs[need] = 70.0 + index * 8.0
			members.append({"id":profile_id + "_" + str(index + 1), "name":clean_name if index == 0 else "Robin", "lot_id":lot_id, "x":7 + index, "y":7, "needs":needs, "action":"Taking it easy", "queue":[], "task":{}, "walk_clock":0.0, "idle_clock":float(index) * 2.0})
		state.families[profile_id] = {"id":profile_id, "name":clean_name + " household", "home_lot":lot_id, "online":false, "members":members}
		_event(clean_name + " moved into " + str(lot.name) + ".")
		return lot_id
	return ""

func set_online(profile_id: String, online: bool) -> void:
	if not state.families.has(profile_id):
		return
	var family: Dictionary = state.families[profile_id]
	family.online = online
	if not online:
		var lot: Dictionary = state.lots[family.home_lot]
		if lot.building:
			if _build_backups.has(str(lot.id)):
				_restore_build(lot)
			lot.building = false
			lot.revision += 1
			_event(str(lot.name) + " left construction mode while its owner was away.")
		for member: Dictionary in family.members:
			_send_home(family, member)

func apply_command(profile_id: String, command: Dictionary) -> Dictionary:
	if not state.families.has(profile_id):
		return _result(false, "Join a household first.")
	var type: Variant = command.get("type")
	if not type is String:
		return _result(false, "Unknown action.")
	var family: Dictionary = state.families[profile_id]
	if type == "rename_family":
		var value: Variant = command.get("name")
		if not value is String or value.strip_edges().is_empty() or value.length() > 24:
			return _result(false, "Choose a name between 1 and 24 characters.")
		var clean_name: String = value.strip_edges()
		family.name = clean_name + " household"
		family.members[0].name = clean_name
		return _result(true, "Welcome home, " + clean_name + ".")
	var lot_id: Variant = command.get("lot_id", family.home_lot)
	if not lot_id is String or not state.lots.has(lot_id):
		return _result(false, "That lot does not exist.")
	var lot: Dictionary = state.lots[lot_id]
	if type in ["build_begin", "build_end", "build_cancel", "place", "erase"]:
		if lot.owner != profile_id:
			return _result(false, "Only the owner can build on this lot.")
		if type == "build_begin":
			if lot.building:
				return _result(true, "Already in construction mode.")
			_build_backups[lot_id] = lot.duplicate(true)
			lot.building = true
			lot.revision += 1
			for other: Dictionary in state.families.values():
				for member: Dictionary in other.members:
					if member.lot_id == lot_id:
						if other.id != profile_id:
							_send_home(other, member)
						else:
							_clear_member(member, "Waiting for construction")
			_event(str(lot.name) + " is under construction. Visitors have gone home.")
			return _result(true, "Construction started. Your family is paused; neighbors keep living.")
		if not lot.building:
			return _result(false, "Enter construction mode first.")
		if type == "build_cancel":
			if _build_backups.has(lot_id):
				_restore_build(lot)
			lot.building = false
			lot.revision += 1
			return _result(true, "Construction canceled. Your previous home and funds are restored.")
		if type == "build_end":
			var issue := _layout_issue(lot)
			if not issue.is_empty():
				return _result(false, issue)
			lot.building = false
			lot.revision += 1
			_build_backups.erase(lot_id)
			_event(str(lot.name) + " is open for visitors again.")
			return _result(true, "Welcome home. Your family is living again.")
		return _build(lot, command)
	var member_id: Variant = command.get("member_id", "")
	if not member_id is String:
		return _result(false, "Choose a household member.")
	var member := _member(family, member_id)
	if member.is_empty():
		return _result(false, "You can only direct your own family.")
	if type == "cancel":
		_clear_member(member)
		return _result(true, "Action queue cleared.")
	if bool(state.lots[family.home_lot].building):
		return _result(false, "Finish construction before directing your family.")
	if type in ["visit", "go_home"]:
		var destination: Dictionary = state.lots[family.home_lot] if type == "go_home" else lot
		if destination.building:
			return _result(false, "This home is under construction. Visit again soon.")
		if type == "visit" and str(destination.owner).is_empty():
			return _result(false, "Nobody lives here yet.")
		_clear_member(member)
		member.lot_id = destination.id
		var entry := _free_entry(destination)
		member.x = entry.x
		member.y = entry.y
		_event(str(member.name) + " arrived at " + str(destination.name) + ".")
		return _result(true, "Arrived at " + str(destination.name) + ".")
	if member.lot_id != lot_id:
		return _result(false, "Visit this lot before using it.")
	if lot.building:
		return _result(false, "This lot is under construction.")
	if member.queue.size() >= MAX_QUEUE:
		return _result(false, "The action queue is full (8 actions).")
	if type == "move":
		if not _valid_coord(command.get("x")) or not _valid_coord(command.get("y")):
			return _result(false, "Choose a tile inside the lot.")
		var goal := Vector2i(int(command.x), int(command.y))
		if not _walkable(lot, goal):
			return _result(false, "That tile is occupied.")
		if _path(lot, _position(member), [goal]).is_empty() and _position(member) != goal:
			return _result(false, "There is no path to that tile.")
		member.queue.append({"type":"move", "x":goal.x, "y":goal.y})
	elif type == "interact":
		var target_id: Variant = command.get("target_id", "")
		if not target_id is String:
			return _result(false, "Choose a furnishing.")
		var object := _object(lot, target_id)
		if object.is_empty():
			var neighbor := _find_member(target_id)
			if neighbor.is_empty() or neighbor.id == member.id or neighbor.lot_id != member.lot_id:
				return _result(false, "Choose another resident on this lot or a furnishing.")
			var goals := _social_cells(lot, neighbor)
			if not goals.has(_position(member)) and _path(lot, _position(member), goals).is_empty():
				return _result(false, "There is no path to chat with that resident.")
			member.queue.append({"type":"interact", "target_id":target_id, "target_kind":"member"})
		else:
			if not _can_reach_object(lot, _position(member), object):
				return _result(false, "There is no path to use that furnishing.")
			member.queue.append({"type":"interact", "target_id":target_id})
	else:
		return _result(false, "Unknown action.")
	# A direct order interrupts an autonomous task, but preserves player-queued work.
	if bool(member.task.get("automatic", false)):
		member.task = {}
	if member.task.is_empty():
		_start_next(member, lot)
	return _result(true, "Action queued.")

func _build(lot: Dictionary, command: Dictionary) -> Dictionary:
	if not _valid_coord(command.get("x")) or not _valid_coord(command.get("y")):
		return _result(false, "Choose a tile inside the lot.")
	var cell := Vector2i(int(command.x), int(command.y))
	if command.type == "erase":
		for object: Dictionary in lot.objects:
			if _object_cells(object).has(cell):
				lot.objects.erase(object)
				lot.funds += int(Catalog.ITEMS[object.kind].cost * 0.6)
				lot.revision += 1
				return _result(true, "Furnishing sold for 60% of its price.")
		for kind: String in ["wall", "door", "floor"]:
			var list: Array = lot[_tile_key(kind)]
			if list.has([cell.x, cell.y]):
				list.erase([cell.x, cell.y])
				lot.funds += int(Catalog.ITEMS[kind].cost * 0.6)
				lot.revision += 1
				return _result(true, "Tile removed.")
		return _result(false, "There is nothing to remove here.")
	var kind: Variant = command.get("kind")
	if not kind is String or not Catalog.ITEMS.has(kind):
		return _result(false, "Unknown catalog item.")
	var rotation_value: Variant = command.get("rotation", 0)
	if not _integer(rotation_value) or int(rotation_value) < 0 or int(rotation_value) > 3:
		return _result(false, "Invalid rotation.")
	var rotation := int(rotation_value)
	var definition: Dictionary = Catalog.ITEMS[kind]
	if lot.funds < definition.cost:
		return _result(false, "Your household cannot afford this yet.")
	var existing := [cell.x, cell.y]
	if kind in ["floor", "wall", "door"]:
		if lot[_tile_key(kind)].has(existing):
			return _result(false, "That tile is already placed.")
		if kind != "floor":
			if not _object_at(lot, cell).is_empty() or _resident_at(str(lot.id), cell):
				return _result(false, "Move the furnishing or choose an empty tile.")
			if cell == Vector2i(8,14):
				return _result(false, "Keep the lot entrance clear.")
			if kind == "wall":
				lot.doors.erase(existing)
			else:
				lot.walls.erase(existing)
		lot[_tile_key(kind)].append(existing)
	else:
		var size := Catalog.footprint(kind, rotation)
		for y in range(cell.y, cell.y + size.y):
			for x in range(cell.x, cell.x + size.x):
				var tile := Vector2i(x,y)
				if not _inside(tile) or not lot.floors.has([x,y]) or not _walkable(lot, tile) or _resident_at(str(lot.id), tile) or lot.doors.has([x,y]):
					return _result(false, "Furniture needs clear floor space, away from doors and residents.")
		lot.objects.append(_new_object(kind, cell.x, cell.y, rotation))
	lot.funds -= int(definition.cost)
	lot.revision += 1
	return _result(true, str(definition.name) + " placed.")

func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or state.is_empty():
		return
	delta = minf(delta, 1.0)
	state.tick += 1
	state.day_minutes += delta * 3.0
	if state.day_minutes >= 1440.0:
		state.day_minutes -= 1440.0
		state.day += 1
		for family: Dictionary in state.families.values():
			state.lots[family.home_lot].funds += 600
		_event("A new day. Each household received a $600 living allowance.")
	for family: Dictionary in state.families.values():
		if state.lots[family.home_lot].building:
			continue
		for member: Dictionary in family.members:
			var lot: Dictionary = state.lots[member.lot_id]
			for need: String in NEEDS:
				var floor_value := 0.0 if family.online else 55.0
				member.needs[need] = clampf(float(member.needs[need]) - float(DECAY[need]) * delta, floor_value, 100.0)
			_tick_member(member, lot, delta)

func _tick_member(member: Dictionary, lot: Dictionary, delta: float) -> void:
	if member.task.is_empty():
		if not member.queue.is_empty():
			_start_next(member, lot)
		else:
			member.idle_clock += delta
			if member.idle_clock >= 2.0:
				member.idle_clock = 0.0
				_choose_autonomy(member, lot)
	if member.task.is_empty():
		member.action = "Taking it easy"
		return
	var task: Dictionary = member.task
	if not task.path.is_empty():
		member.action = "Walking" + (" · " + str(task.get("label", "")) if task.type == "interact" else "")
		member.walk_clock += delta
		if member.walk_clock >= 0.22:
			member.walk_clock = 0.0
			var next: Array = task.path.pop_front()
			if not _walkable(lot, Vector2i(int(next[0]), int(next[1]))):
				_clear_member(member, "Path changed")
				return
			member.x = int(next[0])
			member.y = int(next[1])
		return
	if task.type == "move":
		member.task = {}
		return
	if task.get("target_kind", "object") == "member":
		var neighbor := _find_member(str(task.target_id))
		if neighbor.is_empty() or neighbor.lot_id != member.lot_id or _position(member).distance_to(_position(neighbor)) > 2.0:
			member.task = {}
			member.action = "They moved away"
			return
		member.action = "Chatting with " + str(neighbor.name)
		member.needs.social = minf(100.0, float(member.needs.social) + 7.0 * delta)
		neighbor.needs.social = minf(100.0, float(neighbor.needs.social) + 7.0 * delta)
		task.remaining -= delta
		if task.remaining <= 0.0:
			member.task = {}
		return
	var object := _object(lot, str(task.get("target_id", "")))
	if object.is_empty():
		member.task = {}
		return
	var definition: Dictionary = Catalog.ITEMS[object.kind]
	member.action = ACTION_NAMES.get(object.kind, "Enjoying home")
	var need: String = definition.need
	member.needs[need] = minf(100.0, float(member.needs[need]) + float(definition.rate) * delta)
	if object.kind == "bed" or object.kind == "sofa":
		member.needs.comfort = minf(100.0, float(member.needs.comfort) + 2.0 * delta)
	if object.kind == "table":
		for family: Dictionary in state.families.values():
			for companion: Dictionary in family.members:
				if companion.id != member.id and companion.lot_id == member.lot_id and _position(companion).distance_to(_position(member)) <= 4.0:
					companion.needs.social = minf(100.0, float(companion.needs.social) + 2.0 * delta)
	task.remaining -= delta
	if task.remaining <= 0.0 or float(member.needs[need]) >= 99.0:
		member.task = {}

func _choose_autonomy(member: Dictionary, lot: Dictionary) -> void:
	# A missing bathroom must not prevent eating or sleeping. Score every useful,
	# reachable affordance instead of repeatedly retrying one unsatisfiable need.
	var best: Dictionary = {}
	var best_score := 100000.0
	for object: Dictionary in lot.objects:
		var need: String = Catalog.ITEMS[object.kind].need
		var value := float(member.needs[need])
		if value >= 78.0 or not _can_reach_object(lot, _position(member), object):
			continue
		var distance := _position(member).distance_to(Vector2i(int(object.x), int(object.y)))
		var score := value + distance * 0.2
		if score < best_score:
			best = object
			best_score = score
	if not best.is_empty():
		member.queue.append({"type":"interact", "target_id":best.id, "automatic":true})
		_start_next(member, lot)

func _start_next(member: Dictionary, lot: Dictionary) -> void:
	if member.queue.is_empty():
		return
	var task: Dictionary = member.queue.pop_front()
	var goals: Array = []
	if task.type == "move":
		goals = [Vector2i(int(task.x), int(task.y))]
	elif task.get("target_kind", "object") == "member":
		var neighbor := _find_member(str(task.target_id))
		if neighbor.is_empty() or neighbor.lot_id != member.lot_id:
			return
		goals = _social_cells(lot, neighbor)
		task.remaining = 10.0
		task.label = "Chat with " + str(neighbor.name)
	else:
		var object := _object(lot, str(task.target_id))
		if object.is_empty():
			return
		goals = _interaction_cells(lot, object)
		task.remaining = float(Catalog.ITEMS[object.kind].duration)
		task.label = str(Catalog.ITEMS[object.kind].name)
	var route := _path(lot, _position(member), goals)
	if route.is_empty() and not goals.has(_position(member)):
		member.action = "Cannot reach destination"
		return
	task.path = route
	member.task = task
	member.walk_clock = 0.0

func _layout_issue(lot: Dictionary) -> String:
	var gate := Vector2i(8,14)
	if not _walkable(lot, gate):
		return "Keep the lot entrance clear."
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id == lot.id and _path(lot, _position(member), [gate]).is_empty() and _position(member) != gate:
				return "A resident cannot reach the entrance. Add a door or clear a path."
	for object: Dictionary in lot.objects:
		if not _can_reach_object(lot, gate, object):
			return "Leave a clear path to the " + str(Catalog.ITEMS[object.kind].name) + "."
	return ""

func _restore_build(lot: Dictionary) -> void:
	var original: Dictionary = _build_backups[lot.id]
	for key: String in ["floors", "walls", "doors", "objects", "funds"]:
		lot[key] = original[key].duplicate(true) if original[key] is Array else original[key]
	_build_backups.erase(lot.id)

func _send_home(family: Dictionary, member: Dictionary) -> void:
	var lot: Dictionary = state.lots[family.home_lot]
	member.lot_id = family.home_lot
	var entry := _free_entry(lot)
	member.x = entry.x
	member.y = entry.y
	_clear_member(member)

func _free_entry(lot: Dictionary) -> Vector2i:
	if _walkable(lot, Vector2i(8,14)):
		return Vector2i(8,14)
	for y in range(GRID_SIZE - 1, -1, -1):
		for x in range(GRID_SIZE):
			if _walkable(lot, Vector2i(x,y)):
				return Vector2i(x,y)
	return Vector2i(8,14)

func _clear_member(member: Dictionary, label: String = "Taking it easy") -> void:
	member.queue = []
	member.task = {}
	member.action = label
	member.walk_clock = 0.0
	member.idle_clock = 0.0

func _new_object(kind: String, x: int, y: int, rotation: int) -> Dictionary:
	var id := "object_%d" % int(state.next_object)
	state.next_object += 1
	return {"id":id, "kind":kind, "x":x, "y":y, "rotation":rotation}

func _tile_key(kind: String) -> String:
	return {"floor":"floors", "wall":"walls", "door":"doors"}.get(kind, "")

func _member(family: Dictionary, id: String) -> Dictionary:
	for member: Dictionary in family.members:
		if member.id == id:
			return member
	return {}

func _find_member(id: String) -> Dictionary:
	for family: Dictionary in state.families.values():
		var member := _member(family, id)
		if not member.is_empty():
			return member
	return {}

func _social_cells(lot: Dictionary, neighbor: Dictionary) -> Array:
	var cells: Array = []
	for direction: Vector2i in DIRECTIONS:
		var position := _position(neighbor) + direction
		if _walkable(lot, position):
			cells.append(position)
	return cells

func _object(lot: Dictionary, id: String) -> Dictionary:
	for object: Dictionary in lot.objects:
		if object.id == id:
			return object
	return {}

func _object_at(lot: Dictionary, cell: Vector2i) -> Dictionary:
	for object: Dictionary in lot.objects:
		if _object_cells(object).has(cell):
			return object
	return {}

func _resident_at(lot_id: String, cell: Vector2i) -> bool:
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			if member.lot_id == lot_id and _position(member) == cell:
				return true
	return false

func _position(member: Dictionary) -> Vector2i:
	return Vector2i(int(member.x), int(member.y))

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

func _walkable(lot: Dictionary, cell: Vector2i) -> bool:
	return _inside(cell) and not lot.walls.has([cell.x,cell.y]) and _object_at(lot, cell).is_empty()

func _object_cells(object: Dictionary) -> Array:
	var result: Array = []
	var size := Catalog.footprint(str(object.kind), int(object.rotation))
	for y in range(int(object.y), int(object.y) + size.y):
		for x in range(int(object.x), int(object.x) + size.x):
			result.append(Vector2i(x,y))
	return result

func _interaction_cells(lot: Dictionary, object: Dictionary) -> Array:
	var result: Array = []
	for tile: Vector2i in _object_cells(object):
		for direction: Vector2i in DIRECTIONS:
			var neighbor := tile + direction
			if _walkable(lot, neighbor) and not result.has(neighbor):
				result.append(neighbor)
	return result

func _can_reach_object(lot: Dictionary, start: Vector2i, object: Dictionary) -> bool:
	var goals := _interaction_cells(lot, object)
	return goals.has(start) or not _path(lot, start, goals).is_empty()

func _path(lot: Dictionary, start: Vector2i, goals: Array) -> Array:
	if goals.is_empty() or goals.has(start):
		return []
	# Construct the occupancy set once; BFS does not rescan furniture on each tile.
	var blocked := {}
	for tile: Array in lot.walls:
		blocked[Vector2i(int(tile[0]), int(tile[1]))] = true
	for object: Dictionary in lot.objects:
		for cell: Vector2i in _object_cells(object):
			blocked[cell] = true
	var previous := {start:start}
	var frontier: Array = [start]
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if not _inside(next) or blocked.has(next) or previous.has(next):
				continue
			previous[next] = current
			if goals.has(next):
				var result: Array = []
				while next != start:
					result.push_front([next.x,next.y])
					next = previous[next]
				return result
			frontier.append(next)
	return []

func snapshot() -> Dictionary:
	return state.duplicate(true)

func snapshot_for_save() -> Dictionary:
	# Save only committed buildings. A crash must not strand residents in a draft.
	var saved := snapshot()
	for lot_id: String in _build_backups:
		var source: Dictionary = _build_backups[lot_id]
		for key: String in ["floors", "walls", "doors", "objects", "funds"]:
			saved.lots[lot_id][key] = source[key].duplicate(true) if source[key] is Array else source[key]
	for lot: Dictionary in saved.lots.values():
		lot.building = false
	return saved

func restore(data: Dictionary, preserve_runtime: bool = false) -> bool:
	# Reject foreign/future/corrupt worlds atomically; never partially adopt a save.
	if not _valid_state(data):
		return false
	state = data.duplicate(true)
	_normalize_numbers()
	_build_backups.clear()
	if preserve_runtime:
		return true
	for lot: Dictionary in state.lots.values():
		lot.building = false
	for family: Dictionary in state.families.values():
		family.online = false
		for member: Dictionary in family.members:
			_clear_member(member)
			if not _walkable(state.lots[member.lot_id], _position(member)):
				_send_home(family, member)
	return true

func _normalize_numbers() -> void:
	# JSON has one numeric type. Tile-array equality in Godot distinguishes floats
	# from ints, so restore the canonical integer representation before simulation.
	for key: String in ["tick", "day", "next_object"]:
		state[key] = int(state[key])
	for lot: Dictionary in state.lots.values():
		lot.funds = int(lot.funds)
		lot.revision = int(lot.revision)
		for key: String in ["floors", "walls", "doors"]:
			for tile: Array in lot[key]:
				tile[0] = int(tile[0])
				tile[1] = int(tile[1])
		for object: Dictionary in lot.objects:
			for key: String in ["x", "y", "rotation"]:
				object[key] = int(object[key])
	for family: Dictionary in state.families.values():
		for member: Dictionary in family.members:
			member.x = int(member.x)
			member.y = int(member.y)
			var tasks: Array = member.queue.duplicate()
			if not member.task.is_empty():
				tasks.append(member.task)
			for task: Dictionary in tasks:
				if task.type == "move":
					task.x = int(task.x)
					task.y = int(task.y)
				for tile: Array in task.get("path", []):
					tile[0] = int(tile[0])
					tile[1] = int(tile[1])

func _valid_state(data: Dictionary) -> bool:
	if data.get("schema") != SCHEMA or not data.get("lots") is Dictionary or data.lots.size() != MAX_FAMILIES or not data.get("families") is Dictionary or data.families.size() > MAX_FAMILIES:
		return false
	if not _integer(data.get("tick")) or not _integer(data.get("day")) or not _number(data.get("day_minutes")) or float(data.day_minutes) < 0.0 or float(data.day_minutes) >= 1440.0 or not _integer(data.get("next_object")):
		return false
	if float(data.tick) < 0 or float(data.tick) > 9007199254740991 or float(data.day) < 1 or float(data.day) > 1000000000 or float(data.next_object) < 1 or float(data.next_object) > 9007199254740991:
		return false
	if not data.get("events") is Array or data.events.size() > 24:
		return false
	for event: Variant in data.events:
		if not event is String or event.length() > 200:
			return false
	var object_ids := {}
	for index in range(MAX_FAMILIES):
		var id := "lot_%d" % (index + 1)
		if not data.lots.get(id) is Dictionary:
			return false
		var lot: Dictionary = data.lots[id]
		if lot.get("id") != id or not lot.get("name") is String or str(lot.name).length() > 64 or not lot.get("owner") is String or str(lot.owner).length() > 128 or not _integer(lot.get("funds")) or float(lot.funds) < 0 or float(lot.funds) > 1000000000 or not lot.get("building") is bool or not _integer(lot.get("revision")):
			return false
		for key: String in ["floors", "walls", "doors"]:
			if not lot.get(key) is Array or lot[key].size() > GRID_SIZE * GRID_SIZE:
				return false
			var seen := {}
			for cell: Variant in lot[key]:
				if not cell is Array or cell.size() != 2 or not _valid_coord(cell[0]) or not _valid_coord(cell[1]):
					return false
				var position := Vector2i(int(cell[0]), int(cell[1]))
				if seen.has(position):
					return false
				seen[position] = true
		if float(lot.revision) < 0 or float(lot.revision) > 9007199254740991:
			return false
		if not lot.get("objects") is Array or lot.objects.size() > GRID_SIZE * GRID_SIZE:
			return false
		var occupied := {}
		var floor_cells := {}
		for cell: Array in lot.floors:
			floor_cells[Vector2i(int(cell[0]), int(cell[1]))] = true
		for cell: Array in lot.walls:
			occupied[Vector2i(int(cell[0]), int(cell[1]))] = true
		for cell: Array in lot.doors:
			var position := Vector2i(int(cell[0]), int(cell[1]))
			if occupied.has(position):
				return false
			occupied[position] = true
		for object: Variant in lot.objects:
			if not object is Dictionary or not object.get("id") is String or str(object.id).length() > 64 or object_ids.has(object.id) or not Catalog.ITEMS.has(object.get("kind")) or object.kind in ["floor", "wall", "door"] or not _valid_coord(object.get("x")) or not _valid_coord(object.get("y")) or not _integer(object.get("rotation")) or int(object.rotation) < 0 or int(object.rotation) > 3:
				return false
			if not str(object.id).begins_with("object_") or not str(object.id).trim_prefix("object_").is_valid_int() or int(str(object.id).trim_prefix("object_")) >= int(data.next_object):
				return false
			object_ids[object.id] = true
			for cell: Vector2i in _object_cells(object):
				if not _inside(cell) or occupied.has(cell) or not floor_cells.has(cell):
					return false
				occupied[cell] = true
	var members_seen := {}
	for profile_id: Variant in data.families:
		if not profile_id is String or profile_id.is_empty() or profile_id.length() > 128 or not data.families[profile_id] is Dictionary:
			return false
		var family: Dictionary = data.families[profile_id]
		if family.get("id") != profile_id or not family.get("name") is String or str(family.name).length() > 64 or not data.lots.has(family.get("home_lot")) or data.lots[family.home_lot].owner != profile_id or not family.get("online") is bool or not family.get("members") is Array or family.members.size() != 2:
			return false
		for member: Variant in family.members:
			if not member is Dictionary or not member.get("id") is String or str(member.id).length() > 160 or members_seen.has(member.id) or not member.get("name") is String or str(member.name).length() > 32 or not data.lots.has(member.get("lot_id")) or not _valid_coord(member.get("x")) or not _valid_coord(member.get("y")) or not member.get("needs") is Dictionary:
				return false
			members_seen[member.id] = true
			if not member.get("action") is String or str(member.action).length() > 100 or not member.get("queue") is Array or member.queue.size() > MAX_QUEUE or not member.get("task") is Dictionary or not _number(member.get("walk_clock")) or not _number(member.get("idle_clock")):
				return false
			if float(member.walk_clock) < 0 or float(member.walk_clock) > 60 or float(member.idle_clock) < 0 or float(member.idle_clock) > 60:
				return false
			for task: Variant in member.queue:
				if not _valid_task(task, false):
					return false
			if not member.task.is_empty() and not _valid_task(member.task, true):
				return false
			for need: String in NEEDS:
				if not _number(member.needs.get(need)) or float(member.needs[need]) < 0 or float(member.needs[need]) > 100:
					return false
	for lot: Dictionary in data.lots.values():
		if not str(lot.owner).is_empty() and not data.families.has(lot.owner):
			return false
	return true

func _valid_task(value: Variant, active: bool) -> bool:
	if not value is Dictionary or not value.get("type") in ["move", "interact"]:
		return false
	if value.has("automatic") and not value.automatic is bool:
		return false
	if value.has("target_kind") and not value.target_kind in ["member", "object"]:
		return false
	if value.type == "move":
		if not _valid_coord(value.get("x")) or not _valid_coord(value.get("y")):
			return false
	else:
		if not value.get("target_id") is String or str(value.target_id).length() > 160:
			return false
		if active and (not _number(value.get("remaining")) or not value.get("label") is String or str(value.label).length() > 100):
			return false
	if active:
		if value.type == "interact" and (float(value.remaining) <= 0 or float(value.remaining) > 120):
			return false
		if not value.get("path") is Array or value.path.size() > GRID_SIZE * GRID_SIZE:
			return false
		for tile: Variant in value.path:
			if not tile is Array or tile.size() != 2 or not _valid_coord(tile[0]) or not _valid_coord(tile[1]):
				return false
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floorf(float(value))

func _valid_coord(value: Variant) -> bool:
	return _integer(value) and float(value) >= 0 and float(value) < GRID_SIZE

func _event(message: String) -> void:
	state.events.push_front(message.left(200))
	if state.events.size() > 24:
		state.events.resize(24)

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok, "message":message}
