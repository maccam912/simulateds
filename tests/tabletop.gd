extends SceneTree
const World = preload("res://game/world.gd")
const Tabletop = preload("res://game/tabletop.gd")
const Browse = preload("res://game/build_catalog.gd")
const Status = preload("res://game/activity_status.gd")
const Cues = preload("res://game/resident_cues.gd")

func _initialize() -> void: call_deferred("_run")

func _fixture() -> RefCounted:
	var world := World.new(); world.initialize()
	for owner: String in ["a","b","c"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false; resident.needs.fun=0.0; resident.needs.social=10.0
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	var placed: Dictionary=world.apply_command("a",{"type":"place","lot_id":"lot_1","kind":"game_table","x":8,"y":5,"rotation":1})
	assert(placed.ok,str(placed.message))
	assert(world.state.lots.lot_1.funds==11660)
	assert(world.apply_command("a",{"type":"build_end","lot_id":"lot_1"}).ok)
	return world

func _table(world: RefCounted) -> Dictionary:
	for object: Dictionary in world.state.lots.lot_1.objects:
		if object.kind=="game_table": return object
	return {}

func _join(world: RefCounted, owner: String, member: Dictionary, table: Dictionary) -> void:
	if member.lot_id!="lot_1": assert(world.apply_command(owner,{"type":"visit","lot_id":"lot_1","member_id":member.id}).ok)
	assert(world.apply_command(owner,{"type":"interact","lot_id":"lot_1","member_id":member.id,"target_id":table.id}).ok)

func _run() -> void:
	assert(Browse.results("living","board game")==["game_table"] and Browse.entry("game_table").size=="2×2")
	var world := _fixture(); var table := _table(world)
	var first: Dictionary=world.state.families.a.members[0]; var second: Dictionary=world.state.families.b.members[0]
	var bystander: Dictionary=world.state.families.a.members[1]
	_join(world,"a",first,table)
	for tick in range(100):
		world.step(0.1)
		if Tabletop.players(world.state,"lot_1",table.id).size()==1: break
	assert(first.action=="Playing a tabletop puzzle" and first.needs.fun>0)
	assert(Cues.need(first,world.state.lots.lot_1,world.state).need=="social" and world.care_status(first,"social").is_empty(),"Solo games do not suppress a genuine need for company")
	var solo_social: float=first.needs.social; world.step(0.5)
	assert(first.needs.social<solo_social,"Solo puzzles restore fun, without inventing company")
	_join(world,"b",second,table)
	assert(Tabletop.place(first)!=Tabletop.place(second),"Players reserve separate destinations while approaching")
	for tick in range(100):
		world.step(0.1)
		if Tabletop.players(world.state,"lot_1",table.id).size()==2: break
	world.step(0.1)
	assert(first.action=="Playing together" and second.action=="Playing together")
	var first_task: String=first.task.id; var second_task: String=second.task.id
	var social := [first.needs.social,second.needs.social,bystander.needs.social]
	world.step(0.5)
	assert(first.needs.social>social[0] and second.needs.social>social[1] and bystander.needs.social<social[2],"Only actual participants receive shared social restoration")
	assert(first.task.id==first_task and second.task.id==second_task and bystander.task.is_empty())
	assert("Fun + social" in Status.sample(first,world.state.lots.lot_1).detail)
	assert(Cues.need(first,world.state.lots.lot_1,world.state).is_empty() and world.care_status(first,"social")=="In progress","Shared play covers social care without asking for a duplicate order")
	var snapshot: Dictionary=world.snapshot(); var restored := World.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(snapshot)),true))
	assert(Tabletop.players(restored.state,"lot_1",table.id).size()==2 and Tabletop.place(restored.state.families.a.members[0])!=Tabletop.place(restored.state.families.b.members[0]),"Participation and distinct places survive runtime replication")
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command("a",{"type":"interact","member_id":second.id,"lot_id":"lot_1","target_id":table.id}).ok and world.snapshot()==before)
	assert(world.apply_command("a",{"type":"cancel","member_id":first.id}).ok)
	var remaining_social: float=second.needs.social; world.step(0.2)
	assert(second.task.id==second_task and second.action=="Playing a tabletop puzzle" and second.needs.social<remaining_social,"One player leaving does not interrupt another's puzzle")
	assert(Cues.need(second,world.state.lots.lot_1,world.state).need=="social" and world.care_status(second,"social").is_empty(),"Leaving immediately restores any uncovered social cue")
	world.set_online("b",false)
	assert(Tabletop.players(world.state,"lot_1",table.id,false).is_empty() and second.lot_id=="lot_2")
	assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(not _table(restored).is_empty() and Tabletop.players(restored.state,"lot_1",table.id,false).is_empty(),"Saved tables survive; runtime reservations do not strand a reloaded household")
	# Four places, a queued fifth player, and release without a lock table.
	var crowded := _fixture(); table=_table(crowded)
	var participants: Array=[]
	for owner: String in ["a","b","c"]:
		for resident: Dictionary in crowded.state.families[owner].members:
			if participants.size()==5: break
			_join(crowded,owner,resident,table); participants.append(resident)
	assert(Tabletop.players(crowded.state,"lot_1",table.id,false).size()==4)
	var places: Array=[]
	for index in range(4):
		var place := Tabletop.place(participants[index]); assert(not place in places); places.append(place)
	assert(participants[4].task.is_empty() and participants[4].queue.size()==1 and str(participants[4].action).begins_with("Waiting for a place"))
	var waiting: String=participants[4].queue[0].id
	crowded.apply_command("a",{"type":"cancel","member_id":participants[0].id}); crowded.step(0.1)
	assert(participants[4].task.id==waiting and Tabletop.players(crowded.state,"lot_1",table.id,false).size()==4)
	var free_resident: Dictionary=crowded.state.families.c.members[1]
	assert(crowded.apply_command("c",{"type":"visit","member_id":free_resident.id,"lot_id":"lot_1"}).ok)
	for need: String in free_resident.needs: free_resident.needs[need]=100.0
	free_resident.needs.fun=60.0; free_resident.favorite="games"
	assert(crowded.care_option(free_resident,"fun").target_id!=table.id,"Care favors available recreation over a full game table")
	crowded._choose_autonomy(free_resident,crowded.state.lots.lot_1)
	assert(not free_resident.task.is_empty() and free_resident.task.target_id!=table.id,"Autonomy chooses useful free recreation instead of waiting at a full favorite table")
	assert(crowded.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(Tabletop.players(crowded.state,"lot_1",table.id,false).is_empty())
	for owner: String in ["b","c"]:
		for resident: Dictionary in crowded.state.families[owner].members: assert(resident.lot_id==crowded.state.families[owner].home_lot and resident.task.is_empty())
	# Pre-tabletop saves still load with the current catalog and schema.
	var legacy := World.new(); legacy.initialize(); legacy.ensure_family("old","Old family")
	assert(restored.restore(JSON.parse_string(JSON.stringify(legacy.snapshot_for_save()))))
	print("TABLETOP_PASS")
	quit()
