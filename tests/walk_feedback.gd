extends SceneTree
const World = preload("res://game/world.gd")
const Feedback = preload("res://game/walk_feedback.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	world.set_online("a",true)
	var member: Dictionary=world.state.families.a.members[0]
	var other: Dictionary=world.state.families.b.members[0]
	var lot: Dictionary=world.state.lots.lot_1
	member.autonomy=false
	# Every tile's visible eligibility matches a fresh host decision. Neither the
	# preview nor its copied route is allowed to alter the original state.
	for y in range(16):
		for x in range(16):
			var before: Dictionary=world.snapshot()
			var option := world.move_option("a",str(member.id),"lot_1",Vector2i(x,y))
			assert(world.snapshot()==before)
			var replica := World.new(); replica.state=before.duplicate(true)
			var result: Dictionary=replica.apply_command("a",{"type":"move","member_id":member.id,"lot_id":"lot_1","x":x,"y":y})
			assert(option.ok==result.ok,"Ground preview and host disagree at %d,%d" % [x,y])
			if option.ok: assert(replica.state.families.a.members[0].task.path==option.path)
			else: assert(result.message==option.message)
	assert(not world.move_option("a",str(other.id),"lot_1",Vector2i.ZERO).ok)
	assert(not world.move_option("a",str(member.id),"missing",Vector2i.ZERO).ok)
	assert(not world.move_option("a",str(member.id),"lot_2",Vector2i.ZERO).ok)
	assert(not world.move_option("a",str(member.id),"lot_1",Vector2i(-1,0)).ok)
	# A sealed doorway is a route failure even though the destination is free.
	lot.walls.append([8,11]); lot.doors.erase([8,11]); lot.revision+=1
	assert(not world.move_option("a",str(member.id),"lot_1",Vector2i(8,14)).ok)
	lot.walls.erase([8,11]); lot.doors.append([8,11]); lot.revision+=1
	var feedback := Feedback.new()
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i(8,14),true,false,0)
	assert(feedback.preview.ok and feedback.preview.ahead==0 and not feedback.preview.path.is_empty() and feedback.markers.is_empty())
	var before: Dictionary=world.snapshot()
	feedback.preview.path.clear()
	assert(world.snapshot()==before,"A preview owns its path, never an authoritative route")
	# A click or rejection alone cannot produce an accepted marker.
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i(8,14),false,false,0)
	assert(feedback.preview.is_empty() and feedback.markers.is_empty())
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":8,"y":14}).ok)
	var active: String=member.task.id
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i(13,14),true,false,0.1)
	assert(feedback.markers.size()==1 and feedback.markers[0].id==active and feedback.markers[0].recent and feedback.markers[0].active)
	assert(feedback.preview.ok and feedback.preview.ahead==1 and feedback.route==member.task.path)
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":13,"y":14}).ok)
	var second: String=member.queue[0].id
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i(1,14),false,false,0.1)
	assert(feedback.markers.size()==2 and feedback.markers[1].id==second and feedback.markers[1].order==2 and feedback.markers[1].recent)
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,false,false,3.1)
	assert(feedback.markers.size()==1 and feedback.route.is_empty(),"Watching keeps only the current destination; queued confirmations expire")
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,false,true,0)
	assert(feedback.markers.size()==2 and feedback.route==member.task.path,"Opening Plan reveals the accepted route and queued destinations")
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":1,"y":14}).ok)
	var third: String=member.queue[1].id
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,false,true,0)
	assert(world.apply_command("a",{"type":"reorder_action","member_id":member.id,"first_id":second,"second_id":third}).ok)
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,false,true,0)
	assert(feedback.markers[1].id==third and feedback.markers[1].order==2 and feedback.markers[2].id==second)
	assert(world.apply_command("a",{"type":"remove_action","member_id":member.id,"action_id":third}).ok)
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,false,false,0)
	assert(feedback.markers.size()==1,"Canceled queued markers disappear immediately")
	# Client replacement snapshots retain accepted identity and do not replay a flash.
	world.state=world.snapshot(); member=world.state.families.a.members[0]; lot=world.state.lots.lot_1
	before=world.snapshot()
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,false,true,0)
	assert(feedback.markers.size()==2 and not feedback.markers[1].recent and world.snapshot()==before)
	for index in range(7): assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":0,"y":index}).ok)
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i(8,14),true,false,0)
	assert(not feedback.preview.ok and "full" in feedback.preview.message)
	assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	# A direct order replaces autonomous work, so it is an immediate preview.
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":8,"y":14}).ok)
	member.task.automatic=true
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i(9,14),true,false,0)
	assert(feedback.preview.ahead==0 and feedback.markers.is_empty())
	assert(world.apply_command("a",{"type":"move","member_id":member.id,"x":9,"y":14}).ok)
	assert(member.queue.is_empty() and member.task.x==9)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,true,true,0)
	assert(feedback.preview.is_empty() and feedback.markers.is_empty())
	assert(not world.move_option("a",member.id,"lot_1",Vector2i.ZERO).ok)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)
	feedback.update(world.state,"a",member.id,"lot_1",Vector2i.ZERO,true,true,0)
	assert(not feedback.preview.ok and feedback.markers.is_empty())
	feedback.update(world.state,"a",member.id,"lot_2",Vector2i.ZERO,true,true,0,false)
	assert(feedback.preview.is_empty() and feedback.markers.is_empty() and feedback.route.is_empty(),"Menus hide every movement overlay")
	print("WALK_FEEDBACK_PASS")
	quit()
