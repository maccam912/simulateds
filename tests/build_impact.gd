extends SceneTree
const World = preload("res://game/world.gd")
const Rules = preload("res://game/build_rules.gd")
const Rooms = preload("res://game/room_plan.gd")
const Impact = preload("res://game/build_impact.gd")
var world: RefCounted
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)

func _people() -> Array: return world.state.families.a.members

func _plan(command: Dictionary) -> Dictionary:
	var positions: Array=[]
	for member: Dictionary in _people(): positions.append(Vector2i(int(member.x),int(member.y)))
	return Rooms.inspect(lot,command,positions) if command.type=="build_room" else Rules.inspect(lot,command,positions)

func _compare(command: Dictionary) -> Dictionary:
	command.lot_id=lot.id; command.revision=lot.revision
	var before: Dictionary=world.snapshot(); var plan := _plan(command)
	var impact := Impact.inspect(lot,command,plan,_people())
	assert(world.snapshot()==before,"Forecasting cannot change the draft, history, budget, identities, or residents")
	if not plan.ok:
		assert(impact.is_empty() and not world.apply_command("a",command).ok and world.snapshot()==before)
		return impact
	assert(world.apply_command("a",command).ok,"Warnings do not forbid unfinished draft edits")
	var actual: Dictionary=world.build_access(lot)
	# The temporary furnishing receives its real ID only after host acceptance.
	for issue: Dictionary in actual.issues:
		if command.type=="place" and command.kind not in ["floor","wall","door"] and issue.key=="object:"+str(lot.objects[-1].id): issue.key="object:placement_preview"
	assert(impact.after==actual,"The preview report must equal the host's accepted-layout report: "+str(command))
	assert(impact.warning==not actual.ok)
	return impact

func _run() -> void:
	_fresh()
	var impact := _compare({"type":"place","kind":"game_table","x":8,"y":4,"rotation":0})
	assert(impact.introduced.size()==1 and impact.introduced[0].name=="Kitchen fridge" and impact.message.begins_with("Would block Kitchen fridge"))
	assert(impact.lost_floor.has(Vector2i(10,5)) and not world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	var table: Dictionary=lot.objects[-1]
	impact=_compare({"type":"move_object","object_id":table.id,"x":9,"y":8,"rotation":1})
	assert(impact.introduced.is_empty() and impact.resolved.size()==1 and impact.ok and impact.message=="Restores access · Ready to finish")
	assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	_fresh()
	impact=_compare({"type":"place","kind":"wall","x":8,"y":11})
	assert(impact.introduced.size()==12 and impact.message.contains("Alex") and impact.lost_floor.has(Vector2i(7,7)))
	impact=_compare({"type":"place","kind":"floor","x":0,"y":0})
	assert(impact.introduced.is_empty() and impact.resolved.is_empty() and impact.message=="Existing access issue · Alex + 11 more")
	impact=_compare({"type":"place","kind":"door","x":8,"y":11})
	assert(impact.ok and impact.resolved.size()==12 and impact.lost_floor.is_empty())
	_fresh()
	# A newly placed object can be inaccessible even when no old item loses access.
	lot.floors.append([0,0]); lot.walls.append([0,1]); lot.walls.append([1,0])
	impact=_compare({"type":"place","kind":"plant","x":0,"y":0})
	assert(impact.introduced.size()==1 and impact.introduced[0].key=="object:placement_preview" and impact.lost_floor.is_empty())
	impact=_compare({"type":"place","kind":"wall","x":8,"y":11})
	assert(impact.introduced.size()==12 and impact.after.issues.size()==13)
	impact=_compare({"type":"place","kind":"door","x":8,"y":11})
	assert(impact.introduced.is_empty() and impact.resolved.size()==12 and impact.message=="Restores access to 12 · 1 issue remains")
	_fresh(); impact=_compare({"type":"place","kind":"garden_bed","x":8,"y":14})
	assert(impact.introduced.size()==1 and impact.introduced[0].key=="gate")
	for rotation in range(4):
		_fresh()
		for index in range(2): _people()[index].x=8+index; _people()[index].y=14
		impact=_compare({"type":"build_room","x":7,"y":3,"end_x":12,"end_y":7,"rotation":rotation})
		assert(not impact.is_empty())
		assert(impact.warning==(rotation==3),"A doorway facing the bed traps the kitchen; the other orientations retain access")
	# Invalid previews must drop old consequences, including occupied or costly
	# layouts. Compare a broad range of valid edits with actual authority results.
	var rng := RandomNumberGenerator.new(); rng.seed=7213
	var kinds := ["floor","wall","door","bed","sofa","game_table","stereo","garden_bed"]
	var checked := 0
	for index in range(160):
		_fresh()
		var command := {"type":"place","kind":kinds[index%kinds.size()],"x":rng.randi_range(0,15),"y":rng.randi_range(0,15),"rotation":rng.randi_range(0,3)}
		if index%3==0:
			command.type="move_object"; command.object_id=lot.objects[index%lot.objects.size()].id
		if index%9==0: lot.funds=0
		impact=_compare(command)
		if not impact.is_empty(): checked+=1
	assert(checked>25)
	print("BUILD_IMPACT_PASS"); quit()
