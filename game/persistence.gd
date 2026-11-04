extends RefCounted
## Small JSON persistence boundary. Never deserialize executable Godot objects.
const MAX_BYTES := 1048576

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "exists": false, "message": "No save yet."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"ok": false, "exists": true, "message": "Save is unreadable or too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"ok": false, "exists": true, "message": "Save contains invalid JSON."}
	return {"ok": true, "exists": true, "data": parser.data}

static func _replace(path: String, data: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(temporary, absolute) == OK

static func write_json(path: String, data: Dictionary, previous_valid: Dictionary = {}) -> bool:
	# Backups come from validated memory, never from an unreadable original save.
	if not previous_valid.is_empty() and not _replace(path + ".bak", previous_valid):
		return false
	return _replace(path, data)
