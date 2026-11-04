extends RefCounted
## Named save snapshots. IDs are opaque leaf names, never caller-supplied paths.
const Persistence = preload("res://game/persistence.gd")
const WorldModel = preload("res://game/world.gd")
const FORMAT := 1
const MAX_SLOTS := 256

static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64 or id == "autosave":
		return false
	for character in id:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true

static func _path(directory: String, id: String) -> String:
	return directory.path_join(id + ".json")

static func _read(path: String, id: String) -> Dictionary:
	var result: Dictionary = Persistence.read_json(path)
	if not result.ok:
		return {"ok":false, "message":str(result.message)}
	var envelope: Dictionary = result.data
	if envelope.get("format") != FORMAT or envelope.get("id") != id or not envelope.get("name") is String or str(envelope.name).strip_edges().is_empty() or str(envelope.name).length() > 48 or not envelope.get("world") is Dictionary:
		return {"ok":false, "message":"Save metadata is invalid or from an unsupported version."}
	for key in ["created", "modified"]:
		var value: Variant = envelope.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0:
			return {"ok":false, "message":"Save timestamp is invalid."}
	var candidate = WorldModel.new()
	if not candidate.restore(envelope.world):
		return {"ok":false, "message":"World data is invalid or from an unsupported version."}
	return {"ok":true, "message":"Save is ready.", "data":envelope, "world":candidate.snapshot(), "name":envelope.name}

static func read_slot(directory: String, id: String) -> Dictionary:
	if not valid_id(id):
		return {"ok":false, "message":"Invalid save identifier."}
	var result := _read(_path(directory,id),id)
	if result.ok:
		return result
	var backup := _read(_path(directory,id) + ".bak",id)
	if backup.ok:
		backup.message = "Recovered the previous saved version from its backup."
		backup.recovered = true
		return backup
	return result

static func list_slots(directory: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return result
	var files := dir.get_files()
	files.sort()
	for filename: String in files:
		if not filename.ends_with(".json"):
			continue
		var id := filename.trim_suffix(".json")
		if not valid_id(id):
			continue
		var saved := read_slot(directory,id)
		var summary := {"id":id, "name":id, "day":0, "minutes":0.0, "modified":FileAccess.get_modified_time(_path(directory,id)), "valid":false, "message":str(saved.message)}
		if saved.ok:
			summary.name = saved.name
			summary.day = int(saved.world.day)
			summary.minutes = float(saved.world.day_minutes)
			summary.modified = int(saved.data.modified)
			summary.valid = true
		result.append(summary)
	result.sort_custom(func(a,b): return int(a.modified) > int(b.modified))
	return result

static func write_slot(directory: String, name: String, world: Dictionary, id: String = "") -> Dictionary:
	name = name.strip_edges()
	if name.is_empty() or name.length() > 48:
		return {"ok":false, "message":"Choose a save name between 1 and 48 characters."}
	var candidate = WorldModel.new()
	if not candidate.restore(world):
		return {"ok":false, "message":"The current world is not valid and was not saved."}
	var previous: Dictionary = {}
	if id.is_empty():
		if list_slots(directory).size() >= MAX_SLOTS:
			return {"ok":false, "message":"The save library is full. Choose an existing slot to overwrite."}
		id = "slot_" + Crypto.new().generate_random_bytes(12).hex_encode()
	elif not valid_id(id):
		return {"ok":false, "message":"Invalid save identifier."}
	else:
		var old := read_slot(directory,id)
		if not old.ok:
			return {"ok":false, "message":"That slot is missing or damaged. Save a new copy instead."}
		previous = old.data
	var now := int(Time.get_unix_time_from_system())
	var envelope := {"format":FORMAT, "id":id, "name":name, "created":int(previous.get("created",now)), "modified":now, "world":world}
	if not Persistence.write_json(_path(directory,id),envelope,previous):
		return {"ok":false, "message":"Could not write the save. Check disk space and folder permissions."}
	return {"ok":true, "message":"Saved “%s”." % name, "id":id}
