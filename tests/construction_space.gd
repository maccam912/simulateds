extends SceneTree
const World=preload("res://game/world.gd")
const Space=preload("res://game/construction_space.gd")
const Access=preload("res://game/build_access.gd")
const Rules=preload("res://game/build_rules.gd")
var world: RefCounted
var lot: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh(begin: bool=true) -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet"); world.set_online("a",true); world.set_online("b",true)
	lot=world.state.lots.lot_1
	if begin: assert(_edit("build_begin").ok)
func _edit(type: String,extra: Dictionary={}) -> Dictionary:
	var command: Dictionary={"type":type,"lot_id":lot.id,"revision":lot.revision}; command.merge(extra,true)
	return world.apply_command("a",command)
func _intent() -> Dictionary: return {"type":"construction_space","lot_id":lot.id,"revision":lot.revision,"orders":Space.request(world.state,"a",lot.id).orders}
func _reject(command: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot(); assert(not world.apply_command(owner,command).ok and world.snapshot()==before)
func _safe() -> void:
	var seen: Array=[]
	for member: Dictionary in world.state.families.a.members:
		if member.lot_id!=lot.id: continue
		var at:=Vector2i(member.x,member.y)
		assert(not seen.has(at) and world._walkable(lot,at)); seen.append(at)
		assert(absi(at.x-Access.GATE.x)+absi(at.y-Access.GATE.y)<=Space.MAX_DISTANCE)
func _run() -> void:
	_fresh(); var initial: Dictionary=world.snapshot(); var command:=_intent()
	assert(Space.request(world.state,"a",lot.id).ok and command.orders.size()==2)
	assert(Rules.inspect(lot,{"type":"place","kind":"plant","x":7,"y":7},[Vector2i(7,7),Vector2i(8,7)]).ok)
	assert(world.apply_command("a",JSON.parse_string(JSON.stringify(command))).ok); _safe(); _reject(command)
	assert(world.state.lots==initial.lots and world.state.families.b==initial.families.b and world.state.next_object==initial.next_object)
	for index in range(2):
		var old: Dictionary=initial.families.a.members[index]; var current: Dictionary=world.state.families.a.members[index]
		for key: String in old:
			if key not in ["x","y","next_action"]: assert(current[key]==old[key],key+" changed while moving aside")
		assert(current.next_action==old.next_action+1)
	assert(Rules.inspect(lot,{"type":"place","kind":"plant","x":7,"y":7},world.state.families.a.members.map(func(member): return Vector2i(member.x,member.y))).ok)
	var positions: Array=world.state.families.a.members.map(func(member): return [member.x,member.y])
	assert(world.apply_command("a",_intent()).ok and positions==world.state.families.a.members.map(func(member): return [member.x,member.y]),"Repeated use never swaps the residents")
	var saved:=World.new(); assert(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(saved.state.lots.lot_1.objects==initial.lots.lot_1.objects)
	for resident: Dictionary in saved.state.families.a.members: assert(saved._walkable(saved.state.lots.lot_1,Vector2i(resident.x,resident.y)))
	_fresh()
	for change: Dictionary in [{"revision":-1},{"revision":null},{"orders":[]},{"orders":{}},{"lot_id":"missing"},{"lot_id":null},{"lot_id":1}]:
		command=_intent(); command.merge(change,true); _reject(command)
	for change: Dictionary in [{"x":-1},{"x":7.5},{"next_action":0},{"next_action":NAN},{"member_id":"b_1"},{"extra":true}]:
		command=_intent(); command.orders[0].merge(change,true); _reject(command)
	command=_intent(); command.orders[1]=command.orders[0].duplicate(); _reject(command)
	_reject(_intent(),"b")
	_reject(_intent(),"unknown")
	command=_intent(); command.erase("lot_id"); assert(world.apply_command("a",command).ok,"Omitted lot defaults safely to the owner's home")
	assert(_edit("build_end").ok); _reject(_intent())
	# Undo, redo and Discard cannot put a furnishing on someone just moved aside.
	for source: String in ["undo","redo","committed"]:
		_fresh(); assert(_edit("place",{"kind":"floor","x":9,"y":14}).ok)
		assert(_edit("place",{"kind":"plant","x":9,"y":14}).ok)
		if source=="committed": assert(_edit("build_end").ok and _edit("build_begin").ok)
		if source=="redo": assert(_edit("build_undo").ok)
		else: assert(_edit("erase",{"x":9,"y":14}).ok)
		var house: Dictionary=lot.duplicate(true); var history: Dictionary=world._build_history.duplicate(true)
		assert(world.apply_command("a",_intent()).ok); _safe()
		assert(lot==house and world._build_history==history)
		for member: Dictionary in world.state.families.a.members: assert(Vector2i(member.x,member.y)!=Vector2i(9,14))
		assert(_edit("build_redo" if source=="redo" else "build_cancel" if source=="committed" else "build_undo").ok); _safe()
	# A visiting relative retains their exact location and plan.
	_fresh(false)
	assert(world.apply_command("a",{"type":"visit","lot_id":"lot_2","member_id":"a_1"}).ok)
	assert(world.apply_command("a",{"type":"move","lot_id":"lot_2","member_id":"a_1","x":1,"y":14}).ok)
	assert(_edit("build_begin").ok)
	var away: Dictionary=world.state.families.a.members[0].duplicate(true)
	assert(Space.request(world.state,"a",lot.id).orders.size()==1 and world.apply_command("a",_intent()).ok)
	assert(world.state.families.a.members[0]==away); _safe()
	world.state.families.a.members[1].lot_id="lot_2"; assert(not Space.request(world.state,"a",lot.id).ok); _reject(_intent())
	_fresh(); world.state.families.a.members[1].next_action=9007199254740000; _reject(_intent())
	# Current entrance obstruction rejects everyone atomically.
	_fresh(); assert(_edit("place",{"kind":"floor","x":8,"y":14}).ok and _edit("place",{"kind":"plant","x":8,"y":14}).ok)
	_reject(_intent())
	# Even after clearing the lot, old edits can reserve every entrance-side spot.
	_fresh()
	for y in range(16):
		for x in range(16):
			if absi(x-8)+absi(y-14)>Space.MAX_DISTANCE or lot.walls.has([x,y]) or lot.doors.has([x,y]): continue
			if not lot.floors.has([x,y]): assert(_edit("place",{"kind":"floor","x":x,"y":y}).ok)
			assert(_edit("place",{"kind":"plant","x":x,"y":y}).ok)
	assert(_edit("clear_lot",{"refund":preload("res://game/clear_lot.gd").inspect(lot).refund}).ok)
	_reject(_intent())
	assert(_edit("build_end").ok and _edit("build_begin").ok and world.apply_command("a",_intent()).ok); _safe()
	print("CONSTRUCTION_SPACE_PASS"); quit()
