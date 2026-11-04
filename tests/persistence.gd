extends SceneTree
## Corruption recovery must preserve both the world and reconnect identity.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node("Session")
	session.set_physics_process(false)
	var base: String = session.save_path + ".recovery-test"
	session.save_path = base
	session._previous_saved = {}
	session.world.initialize()
	session.world.ensure_family(session.profile_id, "Recovery")
	assert(session.save_world())
	var home: String = session.home_lot()
	var original_funds: int = session.state.lots[home].funds
	session.state.lots[home].funds += 123
	assert(session.save_world())
	_write(base, "{corrupted primary")
	session._load_world()
	assert(session.saving_enabled, "Valid backup was not recovered")
	assert(session.state.lots[home].funds == original_funds, "Backup did not restore last validated state")
	assert(FileAccess.get_file_as_string(base) == "{corrupted primary", "Load overwrote damaged primary")
	_write(base + ".bak", "{corrupted backup")
	session._load_world()
	assert(not session.saving_enabled, "Unrecoverable save enabled writes")
	assert(not session.save_world(), "Damaged save was overwritten")
	assert(FileAccess.get_file_as_string(base) == "{corrupted primary")
	assert(FileAccess.get_file_as_string(base + ".bak") == "{corrupted backup")
	var original_profile: String = session.profile_path
	var damaged_profile := original_profile + ".recovery-test"
	_write(damaged_profile, "{broken credential file")
	# Tests may run repeatedly, so an existing recovered profile is valid evidence.
	session.profile_path = damaged_profile
	session._load_profile()
	var recovered_id: String = session.profile_id
	assert(session.profile_path == damaged_profile + ".recovered")
	session.profile_path = damaged_profile
	session._load_profile()
	assert(session.profile_id == recovered_id, "Recovered profile changed on next launch")
	assert(FileAccess.get_file_as_string(damaged_profile) == "{broken credential file", "Damaged profile was overwritten")
	print("PERSISTENCE_PASS")
	quit()

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()
