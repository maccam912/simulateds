extends SceneTree
const World = preload("res://game/world.gd")
const Storeys = preload("res://game/storeys.gd")
var world := World.new()
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")
func edit(command: Dictionary) -> void:
	command.lot_id=lot.id; command.revision=lot.revision
	var result := world.apply_command("a",command)
	assert(result.ok,str([command,result]))
func rejected() -> Dictionary:
	var before := world.snapshot()
	var report := world.home_access(lot,2)
	var result := world.apply_command("a",{"type":"build_end","lot_id":lot.id})
	assert(not result.ok and result.message==report.message and before==world.snapshot(),"Access and Finish share a read-only decision across every floor")
	return report
func _run() -> void:
	world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1
	for member: Dictionary in world.state.families.a.members: member.autonomy=false
	edit({"type":"build_begin"})
	for level in [1,2]:
		var before := world.snapshot()
		assert(world.build_access(Storeys.view(lot,level)).ok)
		assert(world.home_access(lot,level).unbuilt and world.home_access(lot,level).ok)
		assert(before==world.snapshot(),"Viewing an empty level creates no storey")
	edit({"type":"build_end"})
	edit({"type":"build_begin"})
	edit({"type":"place_area","kind":"floor","level":1,"x":4,"y":3,"end_x":10,"end_y":9})
	var report := rejected()
	assert(report.issues[0].level==1 and report.issues[0].name=="Stair connection")
	edit({"type":"place","kind":"stairs","x":8,"y":4})
	assert(world.home_access(lot).ok,str(world.home_access(lot).issues))
	# Correct upper/lower targets, including a missing landing on an unbuilt floor.
	edit({"type":"place","kind":"stairs","level":1,"x":7,"y":4})
	report=rejected()
	assert(report.issues.any(func(issue): return issue.name=="Upper landing" and issue.level==2 and issue.cell==Vector2i(7,3)))
	edit({"type":"place_area","kind":"floor","level":2,"x":4,"y":3,"end_x":10,"end_y":9})
	assert(world.home_access(lot).ok,str(world.home_access(lot).issues))
	for entry: Array in [[0,8,7,"Lower landing"],[1,8,3,"Upper landing"]]:
		edit({"type":"place","kind":"wall","level":entry[0],"x":entry[1],"y":entry[2]})
		report=rejected()
		assert(report.issues.any(func(issue): return issue.name==entry[3] and issue.level==entry[0] and issue.cell==Vector2i(entry[1],entry[2])))
		edit({"type":"build_undo"}); assert(world.home_access(lot).ok,str(world.home_access(lot).issues))
		edit({"type":"build_redo"}); rejected()
		edit({"type":"build_undo"})
	edit({"type":"place","kind":"bed","level":2,"x":4,"y":4})
	for cell: Vector2i in [Vector2i(4,3),Vector2i(5,4),Vector2i(5,5),Vector2i(4,6)]:
		edit({"type":"place","kind":"wall","level":2,"x":cell.x,"y":cell.y})
	report=rejected()
	assert(report.issues.any(func(issue): return issue.name=="Cloud bed" and issue.level==2))
	for i in range(4): edit({"type":"build_undo"})
	var resident: Dictionary=world.state.families.a.members[0]
	resident.level=2; resident.x=15; resident.y=15
	report=world.build_access(Storeys.view(lot,2))
	assert(report.issues.any(func(issue): return issue.key=="resident:"+str(resident.id)))
	assert(world.home_access(lot).ok,"Sheltered residents never veto finishing an otherwise valid home")
	edit({"type":"build_end"})
	assert(resident.level==0 and resident.y>=12,"Finish moves a trapped resident safely to the street")
	var restored := World.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(restored.home_access(restored.state.lots.lot_1).ok)
	var before := world.snapshot()
	assert(world.stair_option(resident,lot,1).ok and not world.stair_option(resident,lot,-1).ok and before==world.snapshot())
	assert(world.apply_command("a",{"type":"use_stairs","member_id":resident.id,"lot_id":lot.id,"direction":1}).ok)
	for step in range(160): world.step(0.22)
	assert(resident.level==1)
	edit({"type":"build_begin"})
	edit({"type":"place","kind":"wall","level":1,"x":8,"y":3})
	rejected(); edit({"type":"build_cancel"})
	assert(world.home_access(lot).ok,"Discard restores access across floors")
	# An upper corridor may legitimately reconnect two downstairs regions.
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1; lot.walls=[]; lot.doors=[]; lot.objects=[]
	edit({"type":"build_begin"})
	for x in [4,10]: edit({"type":"place","kind":"stairs","x":x,"y":5})
	edit({"type":"place_area","kind":"floor","level":1,"x":3,"y":3,"end_x":12,"end_y":10})
	edit({"type":"place_area","kind":"wall","x":7,"y":0,"end_x":7,"end_y":15})
	edit({"type":"place","kind":"fridge","x":4,"y":9})
	assert(world.home_access(lot).ok,"Access follows stair links in both directions")
	edit({"type":"build_end"})
	print("STOREY_ACCESS_PASS"); quit()
