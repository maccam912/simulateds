extends SceneTree
const World = preload("res://game/world.gd")
const Hobbies = preload("res://game/hobbies.gd")
var world = World.new()
var member: Dictionary
var lot: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _practice(hobby: Variant) -> Dictionary:
	return world.apply_command("hobby",{"type":"practice_hobby","member_id":member.id,"hobby":hobby})

func _finish() -> void:
	for index in range(400):
		world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false,"Hobby activity did not finish")

func _object(kind: String) -> Dictionary:
	for object: Dictionary in lot.objects:
		if object.kind==kind: return object
	return {}

func _run() -> void:
	world.initialize(); world.ensure_family("hobby","Alex"); world.set_online("hobby",true)
	member=world.state.families.hobby.members[0]; lot=world.state.lots.lot_1
	for resident: Dictionary in world.state.families.hobby.members: resident.autonomy=false
	for need: String in member.needs: member.needs[need]=100.0
	assert(not _practice("unknown").ok and not _practice([]).ok)
	for hobby: String in Hobbies.ORDER:
		assert(_practice(hobby).ok)
		assert(not _practice(hobby).ok,"Practice shortcut does not duplicate a planned activity")
		world.step(0.1)
		assert(member.hobbies[hobby].sessions==0,"Starting or walking does not earn practice")
		_finish(); assert(member.hobbies[hobby].sessions==1)
		assert(_practice(hobby).ok); _finish()
		assert(Hobbies.rank(member.hobbies[hobby])==2 and member.hobbies[hobby].today==2)
		assert(_practice(hobby).ok); _finish()
		assert(member.hobbies[hobby].sessions==2,"Daily limit still allows recreation and need care")
	assert(member.wishes.journal.any(func(entry): return "rank 2" in entry.text),"Rank milestones appear in the resident's journal")
	var persisted: Dictionary=member.hobbies.duplicate(true)
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(replica.state.families.hobby.members[0].hobbies==persisted)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.families.hobby.members[0].hobbies==persisted)
	world.state.day_minutes=1439.9; world.step(0.1)
	assert(_practice("reading").ok); _finish()
	assert(member.hobbies.reading.sessions==3 and member.hobbies.reading.today==1,"New game day permits practice")
	assert(_practice("reading").ok)
	world.apply_command("hobby",{"type":"cancel","member_id":member.id})
	assert(member.hobbies.reading.sessions==3,"Canceled practice earns nothing")
	# Activity perks alter real need recovery, with both novice and expert controls.
	for hobby: String in Hobbies.ORDER:
		var definition: Dictionary=Hobbies.CATALOG[hobby]
		var object := _object(str(definition.activity))
		var yields: Array=[]
		for sessions: int in [0,14]:
			world._clear_member(member); member.hobbies[hobby]={"sessions":sessions,"day":int(world.state.day),"today":0}
			var cells: Array=world._interaction_cells(lot,object)
			member.x=cells[0].x; member.y=cells[0].y
			for need: String in member.needs: member.needs[need]=10.0
			assert(_practice(hobby).ok); world.step(1.0)
			yields.append([member.needs[definition.need],member.needs[definition.secondary]])
		assert(yields[1][0]>yields[0][0]+1.0 and yields[1][1]>yields[0][1]+3.0,"A learned hobby restores more of its primary need and adds a secondary benefit")
	world._clear_member(member)
	member.hobbies=Hobbies.create(int(world.state.day))
	# Autonomous completions help needs, but cannot earn personal practice.
	member.x=9; member.y=10; member.needs.fun=0.0
	world._queue_action(member,{"type":"interact","target_id":_object("bookshelf").id,"automatic":true})
	_finish(); assert(member.hobbies.reading.sessions==0)
	world._queue_action(member,{"type":"interact","target_id":_object("bookshelf").id,"automatic":true})
	world._start_next(member,lot)
	assert(_practice("reading").ok and not member.task.get("automatic",false),"Choosing an autonomous activity turns it into deliberate practice")
	_finish(); assert(member.hobbies.reading.sessions==1)
	# A care plan retains its order; manual practice joins the end.
	assert(world.apply_command("hobby",{"type":"care","member_id":member.id,"need":"energy"}).ok)
	var first: String=member.task.id
	assert(_practice("gardening").ok and member.task.id==first and member.queue.size()==1)
	world._clear_member(member)
	world.ensure_family("other","Violet")
	assert(not world.apply_command("other",{"type":"practice_hobby","member_id":member.id,"hobby":"reading"}).ok)
	var housemate: Dictionary=world.state.families.hobby.members[1]
	assert(world.apply_command("hobby",{"type":"practice_hobby","member_id":housemate.id,"hobby":"cooking"}).ok)
	assert(_practice("cooking").ok and member.task.is_empty() and member.queue.size()==1,"An occupied fridge waits without stealing another resident's task")
	world._clear_member(member)
	var extra := world._new_object("fridge",9,6,0); lot.objects.append(extra)
	assert(_practice("cooking").ok and member.task.target_id==extra.id,"A reachable free fridge is preferred over the occupied one")
	world._clear_member(member); world._clear_member(housemate); lot.objects.erase(extra)
	for tile in [[9,4],[11,4],[10,5]]: lot.walls.append(tile)
	var blocked: Dictionary=world.snapshot()
	assert(not _practice("cooking").ok and world.state==blocked,"Blocked furnishings cannot be selected and leave the plan unchanged")
	for tile in [[9,4],[11,4],[10,5]]: lot.walls.erase(tile)
	assert(world.apply_command("hobby",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(not _practice("reading").ok)
	world.apply_command("hobby",{"type":"build_cancel","lot_id":"lot_1"})
	# Practice uses the selected resident's actual lot, even when the camera is elsewhere.
	assert(world.apply_command("hobby",{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)
	assert(_practice("gardening").ok)
	assert(world._object(world.state.lots.lot_2,str(member.task.target_id)).kind=="plant")
	world._clear_member(member); world.apply_command("hobby",{"type":"go_home","member_id":member.id})
	var removed := _object("bookshelf"); lot.objects.erase(removed)
	assert(not _practice("reading").ok and not world.hobby_option(member,"reading").available)
	lot.objects.append(removed)
	var before: Dictionary=member.hobbies.duplicate(true)
	world.set_online("hobby",false)
	for index in range(1000): world.step(1.0)
	assert(member.hobbies==before,"Absence neither farms nor removes progress")
	# Bad save data is rejected without adopting any part of the candidate world.
	for bad: Variant in [null,[],{}, {"sessions":-1,"day":1,"today":0},{"sessions":15,"day":1,"today":0},{"sessions":1.5,"day":1,"today":0},{"sessions":1,"day":1,"today":2},{"sessions":4,"day":1,"today":3},{"sessions":4,"day":99999,"today":1}]:
		var corrupt := world.snapshot(); corrupt.families.hobby.members[0].hobbies.reading=bad
		var original: Dictionary=replica.snapshot()
		assert(not replica.restore(corrupt) and replica.snapshot()==original)
	var legacy := world.snapshot()
	for family: Dictionary in legacy.families.values():
		for resident: Dictionary in family.members: resident.erase("hobbies")
	assert(replica.restore(legacy) and replica.state.families.hobby.members[0].hobbies==Hobbies.create(int(world.state.day)))
	# All five ranks are reachable; progress and journal storage stay bounded.
	var board := Hobbies.create(1)
	for day in range(1,20):
		for index in range(3):
			for hobby: String in Hobbies.ORDER: Hobbies.record(board,str(Hobbies.CATALOG[hobby].activity),day)
	for hobby: String in Hobbies.ORDER: assert(board[hobby].sessions==14 and Hobbies.rank(board[hobby])==5)
	assert(Hobbies.valid(board,20))
	print("HOBBIES_PASS")
	quit()
