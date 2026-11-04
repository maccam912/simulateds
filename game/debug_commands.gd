extends RefCounted
## Explicit development commands. Never evaluate script, shell, paths, or RPC text.
const WorldModel = preload("res://game/world.gd")
const MAX_MONEY := 10000000
const HELP := "help · stats · rosebud (+1,000) · motherlode (+50,000)\nmoney <0..10000000> · needs [all|hunger|energy|hygiene|bladder|fun|social|comfort] [0..100]\ntime HH:MM · speed <0..8> · teleport <x> <y> · cancel\nconstruction cancel · save\nWorld changes are available on the host or in local play. Funds and needs are saved; speed resets when a world is loaded."

static func execute(session: Node, line: String, member_id: String = "") -> Dictionary:
	if line.length() > 256:
		return _result(false,"Command is too long (256 characters maximum).")
	var parts := line.strip_edges().to_lower().replace("\t"," ").split(" ",false)
	if parts.is_empty():
		return _result(false,"Type help for developer commands.")
	var command := parts[0]
	if command == "help" and parts.size() == 1:
		return _result(true,HELP)
	if command == "stats" and parts.size() == 1:
		return _result(true,"Role: %s | Families: %d | Peers: %d | Day %d, %02d:%02d\nTick: %d | Speed: %.2f× | Menu paused: %s | Snapshots: %d\nSave: %s" % [session.role,session.state.families.size(),session.players.size(),session.state.day,int(session.state.day_minutes)/60,int(session.state.day_minutes)%60,session.state.tick,session.debug_speed,str(session.menu_paused and session.role=="offline"),session.snapshots_received,session.save_path])
	if not command in ["rosebud","motherlode","money","needs","time","speed","teleport","cancel","save","construction"]:
		return _result(false,"Unknown command “%s”. Type help." % command)
	if not session.is_authority():
		return _result(false,"Only the host can change a shared world with developer commands. Use help or stats here.")
	var family: Dictionary = session.state.families.get(session.profile_id,{})
	if family.is_empty():
		return _result(false,"No local household is available.")
	var lot: Dictionary = session.state.lots[family.home_lot]
	match command:
		"rosebud", "motherlode", "money":
			if lot.building:
				return _result(false,"Finish or discard construction before changing household funds.")
			var amount: int = int(lot.funds) + (1000 if command=="rosebud" else 50000)
			if command=="money":
				if parts.size()!=2 or not _integer(parts[1],0,MAX_MONEY): return _result(false,"Usage: money <0..10000000>")
				amount = int(parts[1])
			elif parts.size()!=1:
				return _result(false,"Usage: " + command)
			if amount>MAX_MONEY: return _result(false,"Developer money limit is 10,000,000.")
			lot.funds=amount
			return _changed(session,"Household funds: § %d" % amount)
		"needs":
			if parts.size()>3: return _result(false,"Usage: needs [all|need] [0..100]")
			var need := "all"
			var value := 100.0
			if parts.size()>=2:
				need=parts[1]
			if parts.size()==3:
				if not _number(parts[2],0,100): return _result(false,"Need values must be between 0 and 100.")
				value=float(parts[2])
			if need!="all" and not need in WorldModel.NEEDS: return _result(false,"Unknown need. Type help for the list.")
			for member: Dictionary in family.members:
				for key: String in WorldModel.NEEDS:
					if need=="all" or key==need: member.needs[key]=value
			return _changed(session,"Household %s needs set to %.1f." % [need,value])
		"time":
			if parts.size()!=2: return _result(false,"Usage: time HH:MM")
			var clock: PackedStringArray=parts[1].split(":")
			if clock.size()!=2 or not _integer(clock[0],0,23) or not _integer(clock[1],0,59): return _result(false,"Usage: time HH:MM (00:00 to 23:59)")
			session.state.day_minutes=float(int(clock[0])*60+int(clock[1]))
			return _changed(session,"Time set to %02d:%02d; day and allowance are unchanged." % [int(clock[0]),int(clock[1])])
		"speed":
			if parts.size()!=2 or not _number(parts[1],0,8): return _result(false,"Usage: speed <0..8>; 0 pauses simulation, 1 is normal.")
			session.set_clock_rate(float(parts[1]))
			return _result(true,"Simulation speed: %.1f×. Networking remains active." % session.debug_speed)
		"teleport":
			if parts.size()!=3 or not _integer(parts[1],0,15) or not _integer(parts[2],0,15): return _result(false,"Usage: teleport <x> <y>, coordinates 0 to 15.")
			var member := _member(family,member_id)
			if member.is_empty(): return _result(false,"Select one of your own residents first.")
			var destination: Dictionary=session.state.lots[member.lot_id]
			if lot.building or destination.building: return _result(false,"Finish construction before moving residents.")
			var point:=Vector2i(int(parts[1]),int(parts[2]))
			if not session.world._walkable(destination,point) or session.world._resident_at(str(member.lot_id),point): return _result(false,"Choose an unoccupied walkable tile.")
			if session.world._path(destination,Vector2i(int(member.x),int(member.y)),[point]).is_empty(): return _result(false,"The selected tile is not reachable.")
			session.world._clear_member(member,"Moved by developer console","Moved by developer console.")
			member.x=point.x; member.y=point.y
			return _changed(session,"%s moved to (%d, %d)." % [member.name,point.x,point.y])
		"cancel":
			if parts.size()!=1: return _result(false,"Usage: cancel")
			for member: Dictionary in family.members: session.world._clear_member(member,"Taking it easy","Plan cleared by developer console.")
			return _changed(session,"Cleared your household’s action queues.")
		"construction":
			if parts.size()!=2 or parts[1]!="cancel": return _result(false,"Usage: construction cancel")
			var result: Dictionary=session.world.apply_command(session.profile_id,{"type":"build_cancel","lot_id":family.home_lot})
			if result.ok: return _changed(session,str(result.message))
			return result
		"save":
			if parts.size()!=1: return _result(false,"Usage: save")
			if not session.save_world(): return _result(false,"Could not save. " + str(session.status))
			return _result(true,"Current neighborhood saved.")
	return _result(false,"Type help for developer commands.")

static func _member(family: Dictionary, id: String) -> Dictionary:
	if id.is_empty(): return family.members[0]
	for member: Dictionary in family.members:
		if member.id==id: return member
	return {}

static func _number(value: String, minimum: float, maximum: float) -> bool:
	return value.is_valid_float() and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum

static func _integer(value: String, minimum: int, maximum: int) -> bool:
	return value.is_valid_int() and _number(value,float(minimum),float(maximum))

static func _changed(session: Node, message: String) -> Dictionary:
	session.world._event("Developer: " + message)
	session.world_changed.emit()
	session._snapshot_clock=0.5
	return _result(true,message)

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
