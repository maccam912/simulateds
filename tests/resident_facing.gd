extends SceneTree
const World = preload("res://game/world.gd")
const Motion = preload("res://game/resident_motion.gd")
const Facing = preload("res://game/resident_facing.gd")
const Catalog = preload("res://game/catalog.gd")

func _initialize() -> void: call_deferred("_run")

func _same(a: Vector2,b: Vector2) -> bool: return a.distance_to(b)<0.001

func _run() -> void:
	var world := World.new(); world.initialize(); world.ensure_family("actor","Alex")
	var first: Dictionary=world.state.families.actor.members[0]
	var second: Dictionary=world.state.families.actor.members[1]
	var lot: Dictionary=world.state.lots.lot_1
	lot.objects=[]; lot.walls=[]; lot.doors=[]
	for member: Dictionary in [first,second]: member.autonomy=false; member.queue=[]; member.task={}
	var motion := Motion.new()
	first.x=5; first.y=5; second.x=8; second.y=8
	motion.update(world.state,"lot_1",0.0,false)
	assert(_same(motion.direction(first),Facing.REST))
	# Four accepted steps, gradual turns, and no idle drift or snapshot mutation.
	for direction: Vector2i in [Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN]:
		first.x+=direction.x; first.y+=direction.y
		var before: Dictionary=world.snapshot()
		var old: Vector2=motion.direction(first)
		motion.update(world.state,"lot_1",0.01,false)
		assert(absf(old.angle_to(motion.direction(first)))<=0.121,"A normal frame turns briefly instead of snapping")
		for frame in range(60): motion.update(world.state,"lot_1",0.01,false)
		assert(_same(motion.direction(first),Vector2(direction)))
		assert(world.snapshot()==before,"Facing and interpolation never write authoritative state")
		motion.update(world.state,"lot_1",1.0,false)
		assert(_same(motion.direction(first),Vector2(direction)),"Idle residents retain their last direction")
	# A sparse snapshot must face each reconstructed leg, not through the wall.
	lot.walls=[[1,1]]; lot.revision+=1; first.x=0; first.y=1
	motion.update(world.state,"lot_1",0.0,false)
	first.x=2
	var headings := {}
	for frame in range(100):
		motion.update(world.state,"lot_1",0.01,false,0.42)
		var at := motion.position(first)
		assert(Vector2i(roundi(at.x),roundi(at.y))!=Vector2i(1,1))
		headings[Vector2(motion.tracks[first.id].heading).snapped(Vector2(0.01,0.01))]=true
	assert(headings.size()>=3,"The route turns around the obstacle")
	first.y=2; motion.update(world.state,"lot_1",0.0,true)
	assert(_same(motion.direction(first),Vector2.DOWN) and not motion.moving(first.id),"Reduced motion still faces the accepted step immediately")
	# A preexisting accepted route on a new client gives an initial facing, but
	# never advances the position beyond the received snapshot.
	motion.tracks.clear(); first.task={"type":"move","path":[[3,2]],"elapsed":0.0}
	motion.update(world.state,"lot_1",0.0,false)
	assert(_same(motion.direction(first),Vector2.RIGHT) and motion.position(first)==Vector2(2,2))
	first.task={}; lot.walls=[]
	# All rotated furnishing footprints and every approach side face inward.
	for kind: String in ["fridge","bookshelf","plant","table","tv","game_table","shower","toilet"]:
		for rotation in range(4):
			var object := {"id":"fixture","kind":kind,"x":6,"y":6,"rotation":rotation}
			lot.objects=[object]; var dimensions := Catalog.footprint(kind,rotation)
			for cell: Vector2i in [Vector2i(5,6),Vector2i(6,5),Vector2i(6+dimensions.x,6),Vector2i(6,6+dimensions.y)]:
				first.x=cell.x; first.y=cell.y
				first.task={"type":"interact","target_kind":"object","target_id":"fixture","path":[],"elapsed":1.0}
				motion.update(world.state,"lot_1",0.0,true)
				var toward := Vector2(6,6)+Vector2(dimensions)*0.5-Vector2(cell)-Vector2(0.5,0.5)
				assert(_same(motion.direction(first),toward.normalized()))
	for rotation in range(4):
		lot.objects=[{"id":"fixture","kind":"sofa","x":6,"y":6,"rotation":rotation}]
		motion.update(world.state,"lot_1",0.0,true)
		assert(_same(motion.direction(first),Vector2.DOWN.rotated(rotation*PI*0.5)),"Seated facing follows the sofa's open side")
	# Actual conversation state, not action text, determines both sides' attention.
	first.x=7; first.y=7; second.x=8; second.y=7
	first.task={"type":"interact","target_kind":"member","target_id":second.id,"path":[],"elapsed":1.0}
	second.task={}; second.action="Taking it easy"
	motion.tracks.clear(); motion.update(world.state,"lot_1",0.0,false)
	assert(_same(motion.direction(first),Vector2.RIGHT) and _same(motion.direction(second),Vector2.LEFT))
	assert(Facing.activity(world.state,second).get("kind")=="chat")
	var before: Dictionary=world.snapshot()
	world.state=world.snapshot(); first=world.state.families.actor.members[0]; second=world.state.families.actor.members[1]; lot=world.state.lots.lot_1
	motion.update(world.state,"lot_1",0.1,false,0.42)
	assert(world.snapshot()==before and _same(motion.direction(second),Vector2.LEFT),"Replacement client snapshots keep the conversation without mutation")
	second.task={"type":"move","path":[[8,8]],"elapsed":0.0}
	assert(Facing.activity(world.state,first).is_empty() and Facing.activity(world.state,second).is_empty(),"A departing partner has their own route, not a stale chat pose")
	second.task={}; second.x=13
	assert(Facing.activity(world.state,first).is_empty() and Facing.activity(world.state,second).is_empty())
	second.x=8; second.lot_id="lot_2"
	assert(Facing.activity(world.state,first).is_empty())
	second.lot_id="lot_1"; first.task={}; second.action="Chatting with Alex"
	assert(Facing.activity(world.state,second).is_empty(),"Stale action text cannot summon a chat partner")
	first.task={"type":"interact","target_kind":"member","target_id":second.id,"path":[],"elapsed":1.0}
	lot.building=true
	assert(Facing.activity(world.state,first).is_empty() and Facing.activity(world.state,second).is_empty())
	first.lot_id="lot_2"; motion.update(world.state,"lot_1",0.1,false)
	assert(not motion.tracks.has(first.id))
	motion.update(world.state,"lot_2",0.0,false)
	assert(_same(motion.direction(first),Facing.REST),"Travel resets presentation on the new lot")
	print("RESIDENT_FACING_PASS")
	quit()
