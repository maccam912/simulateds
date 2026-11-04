extends SceneTree
const World = preload("res://game/world.gd")
const Motion = preload("res://game/resident_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := World.new()
	world.initialize(); world.ensure_family("actor","Alex")
	var member: Dictionary=world.state.families.actor.members[0]
	var motion := Motion.new()
	motion.update(world.state,"lot_1",0.0,false)
	member.x=8
	var authoritative: Dictionary=world.snapshot()
	motion.update(world.state,"lot_1",0.05,false)
	assert(motion.position(member).x>7 and motion.position(member).x<8,"Adjacent accepted movement interpolates")
	assert(world.snapshot()==authoritative,"Presentation must never change authoritative state")
	for index in range(6): motion.update(world.state,"lot_1",0.05,false)
	assert(motion.position(member)==Vector2(8,7) and not motion.moving(str(member.id)))
	# A sparse network snapshot can omit the intermediate turn around a wall.
	var lot: Dictionary=world.state.lots.lot_1
	lot.objects=[]; lot.walls=[[1,1]]; lot.doors=[]; lot.revision+=1
	member.x=0; member.y=1
	motion.update(world.state,"lot_1",0.0,false)
	member.x=2
	for index in range(60):
		motion.update(world.state,"lot_1",0.01,false,0.42)
		var point := motion.position(member)
		assert(Vector2i(roundi(point.x),roundi(point.y))!=Vector2i(1,1),"Interpolation follows a walkable turn, not a line through a wall")
	assert(motion.position(member)==Vector2(2,1))
	member.x=3; motion.update(world.state,"lot_1",0.01,true)
	assert(motion.position(member)==Vector2(3,1) and not motion.moving(str(member.id)),"Reduced motion uses accepted positions immediately")
	member.x=14; member.y=14; motion.update(world.state,"lot_1",0.01,false)
	assert(motion.position(member)==Vector2(14,14),"Teleports do not sweep through the house")
	member.lot_id="lot_2"; motion.update(world.state,"lot_1",0.1,false)
	assert(not motion.tracks.has(member.id),"Travel clears old lot motion")
	motion.update(world.state,"lot_2",0.1,false)
	assert(motion.position(member)==Vector2(14,14),"New lot begins at accepted arrival")
	print("PRESENTATION_PASS")
	quit()
