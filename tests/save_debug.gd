extends SceneTree
## Developer commands and menu/save operations must preserve authority and data.
const WorldModel = preload("res://game/world.gd")
const SaveLibrary = preload("res://game/save_library.gd")
var session: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session=root.get_node("Session")
	session.set_physics_process(false)
	var base: String=session.save_path.get_basename()+"-suite-"+str(Time.get_ticks_usec())
	session.save_path=base+".json"
	session.slots_path=base+"-slots"
	session._previous_saved={}
	session.saving_enabled=true
	session.world.initialize()
	session.world.ensure_family(session.profile_id,"Debug")
	session.world.set_online(session.profile_id,true)
	var home: String=session.home_lot()
	var member_id: String=session.state.families[session.profile_id].members[0].id
	assert(session.execute_debug("help").ok)
	assert(session.execute_debug("stats").ok)
	assert(session.execute_debug("rosebud").ok)
	assert(session.state.lots[home].funds==13000)
	assert(session.execute_debug("motherlode").ok)
	assert(session.state.lots[home].funds==63000)
	assert(session.execute_debug("money 42000").ok)
	assert(session.execute_debug("needs all 22").ok)
	for member in session.state.families[session.profile_id].members:
		for need in WorldModel.NEEDS: assert(member.needs[need]==22)
	assert(session.execute_debug("needs fun 88").ok)
	assert(session.execute_debug("time 12:34").ok)
	assert(session.state.day_minutes==754)
	assert(session.execute_debug("teleport 7 6",member_id).ok)
	assert(session.state.families[session.profile_id].members[0].y==6)
	var before: String=JSON.stringify(session.state)
	for invalid in ["money nan", "money -1", "money 1e99", "money 12.5", "money 10000001", "rosebud extra", "needs all inf", "needs unknown 12", "needs all 101", "time 24:00", "time 12:60", "time 1", "speed NaN", "speed -1", "speed 9", "teleport 4.2 2", "teleport 99 1", "eval print(1)", "save /tmp/other", "construction destroy", "cancel other"]:
		assert(not session.execute_debug(invalid,member_id).ok,invalid)
	assert(JSON.stringify(session.state)==before,"Malformed debug command mutated world")
	assert(not session.execute_debug("teleport 7 5","foreign_member").ok)
	assert(session.world.apply_command(session.profile_id,{"type":"build_begin","lot_id":home}).ok)
	assert(not session.execute_debug("rosebud").ok,"Cheat money bypassed draft budget")
	assert(session.execute_debug("construction cancel").ok)
	assert(not session.state.lots[home].building)
	var tick: int=session.state.tick
	session.menu_paused=true
	session._physics_process(0.2)
	assert(session.state.tick==tick,"Local menu did not pause time")
	session.role="host"
	session._physics_process(0.2)
	assert(session.state.tick>tick,"Host menu incorrectly paused shared time")
	assert(session.execute_debug("speed 0").ok)
	tick=session.state.tick
	session._physics_process(0.2)
	assert(session.state.tick==tick,"Debug zero speed did not pause simulation")
	assert(session.execute_debug("speed 2").ok)
	session.role="offline"
	session.menu_paused=false
	var minutes: float=session.state.day_minutes
	session._physics_process(0.2)
	assert(is_equal_approx(session.state.day_minutes-minutes,1.2),"Debug speed failed to scale simulation")
	session.execute_debug("speed 1")
	session.role="client"
	before=JSON.stringify(session.state)
	for command in ["rosebud","motherlode","money 1","needs","time 01:00","speed 0","teleport 1 1","cancel","save","construction cancel"]:
		assert(not session.execute_debug(command,member_id).ok,"Client accepted "+command)
	assert(session.execute_debug("help").ok and session.execute_debug("stats").ok)
	assert(not session.save_slot("Remote copy").ok)
	assert(not session.new_world().ok)
	assert(not session.load_slot("autosave").ok)
	assert(JSON.stringify(session.state)==before,"Client command changed shared state")
	session.role="offline"
	assert(session.execute_debug("money 42000").ok)
	var saved: Dictionary=session.save_slot("First house")
	assert(saved.ok)
	var id: String=saved.id
	assert(SaveLibrary.valid_id(id))
	assert(session.execute_debug("money 77000").ok)
	assert(session.save_slot("First house revised",id).ok)
	var updated: Dictionary=SaveLibrary.read_slot(session.slots_path,id)
	assert(updated.ok and updated.world.lots[home].funds==77000)
	# Damaged primary falls back to the previous validated named snapshot.
	_write(session.slots_path.path_join(id+".json"),"{broken")
	var recovered: Dictionary=SaveLibrary.read_slot(session.slots_path,id)
	assert(recovered.ok and recovered.get("recovered",false))
	assert(recovered.world.lots[home].funds==42000)
	assert(session.execute_debug("money 1234").ok)
	assert(session.set_play_speed(0).ok)
	assert(session.load_slot(id).ok)
	assert(session.state.lots[home].funds==42000)
	assert(session.debug_speed==0 and session._resume_speed==1 and session._simulation_clock==0,"Loading pauses the private clock before the first tick")
	var copies: Array=session.list_saves()
	assert(copies.size()>=3,"Loading did not retain current world recovery copy and autosave")
	var safety_found:=false
	for row in copies:
		if str(row.name).begins_with("Before loading"):
			var safety: Dictionary=SaveLibrary.read_slot(session.slots_path,str(row.id))
			assert(safety.ok and safety.world.lots[home].funds==1234)
			safety_found=true
	assert(safety_found,"Previous world was not preserved before load")
	_write(session.slots_path.path_join(id+".json.bak"),"{also broken")
	before=JSON.stringify(session.state)
	assert(not session.load_slot(id).ok)
	assert(not session.load_slot("../escape").ok)
	assert(not session.save_slot("Path attack","../escape").ok)
	assert(JSON.stringify(session.state)==before,"Invalid load replaced current state")
	var invalid_found:=false
	for row in session.list_saves():
		if row.id==id: invalid_found=not row.valid
	assert(invalid_found,"Damaged save was hidden or marked valid")
	# Full neighborhoods owned by other identities cannot consume the caller's world.
	var foreign=WorldModel.new()
	foreign.initialize()
	for index in range(4): foreign.ensure_family("foreign_"+str(index),"Other")
	var foreign_slot: Dictionary=SaveLibrary.write_slot(session.slots_path,"Other profiles",foreign.snapshot_for_save())
	assert(foreign_slot.ok)
	assert(not session.load_slot(foreign_slot.id).ok)
	assert(JSON.stringify(session.state)==before)
	assert(session.set_play_speed(4).ok)
	assert(session.new_world("New Linden Grove").ok)
	assert(session.state.lots[session.home_lot()].funds==12000)
	assert(session.state.neighborhood_name=="New Linden Grove")
	assert(session.debug_speed==1.0)
	var model=WorldModel.new()
	assert(model.restore(session.world.snapshot_for_save()),"Operations left an invalid world")
	assert(session.execute_debug("save").ok)
	print("SAVE_DEBUG_PASS")
	session.saving_enabled=false
	quit()

func _write(path: String, data: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(data)
	file.close()
