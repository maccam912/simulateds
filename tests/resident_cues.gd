extends SceneTree
const Cues = preload("res://game/resident_cues.gd")
const World = preload("res://game/world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := World.new(); world.initialize(); world.ensure_family("a","Alex")
	var member: Dictionary=world.state.families.a.members[0]
	var lot: Dictionary=world.state.lots.lot_1
	for need: String in World.NEEDS:
		for key: String in member.needs: member.needs[key]=100.0
		member.needs[need]=15.0
		var before: Dictionary=world.snapshot()
		assert(Cues.need(member,lot).need==need and world.snapshot()==before,"Every cue is derived without mutating a resident")
		member.needs[need]=30.0
		assert(Cues.need(member,lot).is_empty(),"Comfortable-enough residents do not carry constant labels")
	member.needs.hunger=10.0; member.needs.energy=12.0; member.needs.comfort=14.0
	assert(Cues.need(member,lot).need=="hunger")
	var fridge: Dictionary={}; var bed: Dictionary={}
	for object: Dictionary in lot.objects:
		if object.kind=="fridge": fridge=object
		if object.kind=="bed": bed=object
	member.task={"type":"interact","target_id":fridge.id,"automatic":true}
	assert(Cues.need(member,lot).need=="energy","Autonomous care is already covering its need")
	member.queue=[{"type":"interact","target_id":bed.id}]
	assert(Cues.need(member,lot).is_empty(),"Queued sleep covers both energy and secondary comfort")
	lot.objects.erase(fridge)
	assert(Cues.need(member,lot).need=="hunger","A vanished furnishing cannot hide a need")
	var bounds := Rect2(8,8,624,344)
	for corner: Vector2 in [Vector2.ZERO,Vector2(600,0),Vector2(0,340),Vector2(600,340)]:
		var occupied: Array[Rect2]=[]
		for index in range(2):
			var rect := Cues.fit(Rect2(corner,Vector2(230,30)),bounds,occupied)
			assert(rect.has_area() and bounds.encloses(rect))
			for other: Rect2 in occupied: assert(not rect.intersects(other),"Clustered labels remain separate even near viewport edges")
			occupied.append(rect)
	# UI routing uses the ordinary owned care command and preserves manual plans.
	var session: Node=root.get_node("Session"); session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]
	for resident: Dictionary in family.members: resident.autonomy=false
	var game: Control=load("res://game/main.tscn").instantiate(); root.add_child(game)
	var second: Dictionary=family.members[1]
	session.command({"type":"move","member_id":second.id,"lot_id":second.lot_id,"x":0,"y":0})
	var action: String=second.task.id
	game._entity_clicked({"type":"care","owner":session.profile_id,"id":second.id,"need":"energy"})
	assert(game.selected_member==second.id and second.task.id==action and second.queue.size()==1,"A cue selects the right resident and adds care after their existing order")
	assert(session.world.task_activity(second.queue[0],str(second.lot_id))=="bed" and family.members[0].task.is_empty())
	var before: Dictionary=session.world.snapshot()
	game._entity_clicked({"type":"care","owner":"neighbor","id":second.id,"need":"hunger"})
	game._entity_clicked({"type":"care","owner":session.profile_id,"id":session.state.families.neighbor.members[0].id,"need":"hunger"})
	game._entity_clicked({"type":"care","owner":session.profile_id,"id":second.id,"need":"money"})
	assert(session.world.snapshot()==before,"Foreign, stale, and unsupported cue targets do nothing")
	print("RESIDENT_CUES_PASS")
	quit()
