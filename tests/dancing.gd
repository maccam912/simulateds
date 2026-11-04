extends SceneTree
const World = preload("res://game/world.gd")
const Leisure = preload("res://game/shared_leisure.gd")
const Tabletop = preload("res://game/tabletop.gd")
const Music = preload("res://game/stereo_music.gd")
const Routines = preload("res://game/routines.gd")
const Status = preload("res://game/activity_status.gd")
const Cues = preload("res://game/resident_cues.gd")
const Browse = preload("res://game/build_catalog.gd")
var world: RefCounted
var stereo: Dictionary
var first: Dictionary
var second: Dictionary
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")

func _setup() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b","c"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for member: Dictionary in world.state.families[owner].members:
			member.autonomy=false; member.needs.fun=0.0; member.needs.social=10.0
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":"lot_1","kind":"stereo","x":8,"y":5}).ok)
	lot=world.state.lots.lot_1; stereo=lot.objects[-1]
	assert(lot.funds==11740)
	assert(world.apply_command("a",{"type":"build_end","lot_id":"lot_1"}).ok)
	first=world.state.families.a.members[0]; second=world.state.families.b.members[0]

func _dance(owner: String,member: Dictionary) -> void:
	if member.lot_id!="lot_1": assert(world.apply_command(owner,{"type":"visit","lot_id":"lot_1","member_id":member.id}).ok)
	assert(world.apply_command(owner,{"type":"interact","lot_id":"lot_1","member_id":member.id,"target_id":stereo.id}).ok)

func _arrive(count: int) -> void:
	for tick in range(120):
		world.step(0.1)
		if Leisure.players(world.state,"lot_1",stereo.id).size()==count: world.step(0.1); return
	assert(false,"Dancers did not arrive")

func _reject(owner: String,intent: Dictionary) -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before)

func _run() -> void:
	assert(Browse.results("living","dance")==["stereo"] and Browse.entry("stereo").size=="1×1")
	_setup(); _dance("a",first); _arrive(1)
	assert(first.action=="Dancing" and first.needs.fun>0 and Tabletop.activity(world.state,first).is_empty())
	var social: float=first.needs.social; world.step(0.5)
	assert(first.needs.social<social and world.care_status(first,"social").is_empty() and Cues.need(first,lot,world.state).need=="social")
	var option: Dictionary=world.leisure_option(second,first.id)
	assert(not option.available and option.label=="Visit to join" and option.kind=="stereo")
	assert(world.apply_command("b",{"type":"visit","lot_id":"lot_1","member_id":second.id}).ok)
	var join := {"type":"join_dance","lot_id":"lot_1","member_id":second.id,"companion_id":first.id,"activity_id":first.task.id}
	assert(world.leisure_option(second,first.id).label=="Join dance")
	_reject("a",join)
	var wrong_kind := join.duplicate(); wrong_kind.type="join_game"; _reject("b",wrong_kind)
	assert(world.apply_command("b",join).ok); _reject("b",join)
	assert(Leisure.place(first)!=Leisure.place(second)); _arrive(2)
	assert(first.action=="Dancing together" and second.action=="Dancing together" and world.leisure_option(second,first.id).label=="Dancing here")
	assert("Fun + social" in Status.sample(first,lot).detail and world.care_status(first,"social")=="In progress")
	assert(Cues.need(first,lot,world.state).is_empty())
	var bystander: Dictionary=world.state.families.a.members[1]
	var old_social := [first.needs.social,second.needs.social,bystander.needs.social]
	world.step(0.5)
	assert(first.needs.social>old_social[0] and second.needs.social>old_social[1] and bystander.needs.social<old_social[2] and bystander.task.is_empty())
	assert(Routines.capture_plan(first,lot).steps==["stereo"],"Dancing is reusable in household routines")
	var positions := {str(stereo.id):Vector2(200,300)}
	assert(Music.source(world.state,"lot_1",first.id,positions).id==stereo.id)
	assert(Music.source(world.state,"lot_1",first.id,{}).is_empty(),"Offscreen stereos do not play")
	var replica := World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(Leisure.players(replica.state,"lot_1",stereo.id).size()==2)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(Leisure.players(replica.state,"lot_1",stereo.id,false).is_empty() and replica.state.lots.lot_1.objects[-1].kind=="stereo")
	var partner_task: String=second.task.id
	assert(world.apply_command("a",{"type":"cancel","member_id":first.id}).ok)
	world.step(0.2)
	assert(second.task.id==partner_task and second.action=="Dancing" and not Leisure.is_shared(world.state,second))
	_reject("b",join)
	world.set_online("b",false)
	assert(second.lot_id=="lot_2" and Music.source(world.state,"lot_1",first.id,positions).is_empty())
	# Four independent spots and a waiting fifth, with release on construction.
	_setup(); var dancers: Array=[]
	for owner: String in ["a","b","c"]:
		for member: Dictionary in world.state.families[owner].members:
			if dancers.size()==5: break
			_dance(owner,member); dancers.append(member)
	assert(Leisure.players(world.state,"lot_1",stereo.id,false).size()==4)
	var places: Array=[]
	for index in range(4):
		var place := Leisure.place(dancers[index]); assert(not places.has(place)); places.append(place)
	assert(dancers[4].task.is_empty() and dancers[4].queue.size()==1 and dancers[4].action.begins_with("Waiting for a place"))
	var waiting: String=dancers[4].queue[0].id
	assert(world.apply_command("a",{"type":"cancel","member_id":dancers[0].id}).ok)
	world.step(0.1)
	assert(dancers[4].task.id==waiting)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(Leisure.players(world.state,"lot_1",stereo.id,false).is_empty())
	for owner: String in ["b","c"]:
		for member: Dictionary in world.state.families[owner].members: assert(member.lot_id==world.state.families[owner].home_lot and member.task.is_empty())
	# Neighboring shared objects also reserve future destinations against each other.
	_setup(); lot.objects=[]; lot.walls=[]; lot.doors=[]
	var left: Dictionary=world._new_object("stereo",8,5,0); var right: Dictionary=world._new_object("stereo",8,7,0)
	lot.objects=[left,right]; first.x=7; first.y=6
	var housemate: Dictionary=world.state.families.a.members[1]; housemate.x=6; housemate.y=6
	stereo=left; _dance("a",first); stereo=right; _dance("a",housemate)
	assert(Leisure.place(first)!=Leisure.place(housemate),"Adjacent music corners cannot reserve the same future spot")
	for tick in range(30): world.step(0.1)
	positions={str(left.id):Vector2(200,300),str(right.id):Vector2(400,300)}
	assert(Music.source(world.state,"lot_1",first.id,positions).id==left.id and Music.source(world.state,"lot_1",housemate.id,positions).id==right.id)
	var fallback := Music.source(world.state,"lot_1","",positions)
	var reordered: Dictionary=world.snapshot(); reordered.lots.lot_1.objects.reverse()
	assert(Music.source(reordered,"lot_1","",positions)==fallback,"The fallback source stays stable when snapshots reorder furnishings")
	print("DANCING_PASS")
	quit()
