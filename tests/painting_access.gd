extends SceneTree
const World = preload("res://game/world.gd")
const Art = preload("res://game/paintings.gd")
const Access = preload("res://game/build_access.gd")
var world: RefCounted
var lot: Dictionary
var member: Dictionary
var easel: Dictionary

func _initialize() -> void: call_deferred("_run")
func _fresh(turn: int=0) -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1; lot.objects=[]; lot.walls=[]; lot.windows={}; lot.doors=[]
	member=world.state.families.a.members[0]
	for resident: Dictionary in world.state.families.a.members: resident.autonomy=false
	easel=world._new_object("easel",8,8,turn); lot.objects.append(easel)
	member.x=6; member.y=6
func _order() -> Dictionary:
	return world.apply_command("a",{"type":"painting","member_id":member.id,"lot_id":lot.id,"target_id":easel.id,"action":"start","subject":"meadow","revision":easel.painting.revision})
func _arrive() -> void:
	for tick in range(100):
		world.step(0.1)
		if member.task.get("elapsed",0)>0: return
	assert(false,"Painting must reach the canvas side")

func _run() -> void:
	for turn in range(4):
		_fresh(turn)
		var front := Art.front_cell(easel)
		assert(world._interaction_cells(lot,easel)==[front])
		assert(_order().ok and not member.task.path.is_empty())
		assert(member.task.path[-1]==[front.x,front.y],"Host routes to the rotated canvas front")
		_arrive(); assert(Vector2i(member.x,member.y)==front and easel.painting.progress>0)
		assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
		assert(world._object_user(str(lot.id),easel).is_empty(),"Cancellation releases the easel")
		_fresh(turn); front=Art.front_cell(easel)
		lot.walls.append([front.x,front.y])
		var before: Dictionary=world.snapshot()
		var result := _order()
		assert(not result.ok and result.message.contains("front") and world.snapshot()==before,"Blocked canvas side rejects without changing work or plans")
		var report := Access.inspect(lot,world.state.families.a.members)
		assert(report.issues.any(func(issue): return issue.key=="object:"+str(easel.id) and issue.message.contains("front")),"Construction access matches the host")
		lot.walls=[]; lot.objects.append(world._new_object("plant",front.x,front.y,0))
		assert(not _order().ok,"Furniture also blocks the canvas side")
	# A queued route is rechecked if its front becomes blocked before arrival.
	_fresh(); assert(_order().ok)
	var front := Art.front_cell(easel); lot.walls.append([front.x,front.y])
	for tick in range(100): world.step(0.1)
	assert(member.task.is_empty() and easel.painting==Art.create())
	# Legacy side-on active snapshots remain valid and re-route without work.
	_fresh(); assert(_order().ok); _arrive()
	member.x=7; member.y=8
	var picture: Dictionary=easel.painting.duplicate(true)
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	world=replica; lot=world.state.lots.lot_1; easel=lot.objects[0]; member=world.state.families.a.members[0]
	world.step(0.1)
	assert(easel.painting==picture and not member.task.path.is_empty() and member.task.elapsed==0,"Legacy rerouting cannot add progress or rewards")
	_arrive(); assert(Vector2i(member.x,member.y)==Art.front_cell(easel) and easel.painting.progress>picture.progress)
	member.x=7; member.y=8; front=Art.front_cell(easel); lot.walls.append([front.x,front.y]); picture=easel.painting.duplicate(true)
	world.step(0.1); assert(member.task.is_empty() and easel.painting==picture,"Blocked legacy plans stop with the original intact")
	# Physical edges and floor-local support follow the same walkability rule.
	_fresh(); easel.y=15; assert(not _order().ok)
	_fresh(); lot.level=1; lot.floors=[[8,8],[7,8]]; assert(world._interaction_cells(lot,easel).is_empty())
	lot.floors.append([8,9]); assert(world._interaction_cells(lot,easel)==[Vector2i(8,9)])
	print("PAINTING_ACCESS_PASS"); quit()
