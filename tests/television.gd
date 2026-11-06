extends SceneTree
const World = preload("res://game/world.gd")
const TV = preload("res://game/television.gd")
var world: RefCounted
var lot: Dictionary
var first: Dictionary
var second: Dictionary
var tv: Dictionary
var sofa: Dictionary

func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1; first=world.state.families.a.members[0]; second=world.state.families.a.members[1]
	for member: Dictionary in [first,second]: member.autonomy=false; member.needs.fun=10.0
	for item: Dictionary in lot.objects:
		if item.kind=="tv": tv=item
		if item.kind=="sofa": sofa=item
func _order(member: Dictionary, target: Dictionary) -> Dictionary:
	return world.apply_command("a",{"type":"interact","member_id":member.id,"lot_id":lot.id,"target_id":target.id})
func _cancel(member: Dictionary) -> void:
	assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
func _arrive(member: Dictionary) -> void:
	for tick in range(100):
		world.step(0.1)
		if member.task.get("elapsed",0)>0: return
	assert(false,"Viewer must arrive")

func _run() -> void:
	_fresh()
	assert(_order(first,tv).ok and first.task.tv_seat==sofa.id)
	assert(not first.task.path.is_empty(),"Seat approach uses the authoritative walking path")
	assert(_order(second,sofa).ok and second.task.is_empty() and second.queue.size()==1,"Walking viewers reserve their seat against ordinary use")
	_cancel(first); world.step(0.1)
	assert(second.task.target_id==sofa.id,"Cancellation releases the seat")
	assert(_order(first,tv).ok and first.task.tv_seat=="","An occupied sofa uses a standing viewing place")
	_arrive(first); assert(first.action.ends_with("Standing"))
	_cancel(first); _cancel(second)
	assert(_order(first,tv).ok and first.task.tv_seat==sofa.id)
	_arrive(first); assert(first.action.ends_with("Seated"))
	assert(_order(second,tv).ok and second.task.tv_seat=="" and second.task.tv_place!=first.task.tv_place,"Late viewers cannot share the reserved sofa or approach cell")
	var before: Dictionary=world.snapshot()
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(before)),true),"Client snapshots carry seat reservations")
	assert(replica.state.families.a.members[0].task.tv_seat==sofa.id)
	assert(replica.restore_saved(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))),"Solo loading revalidates TV routes and seats")
	assert(replica.prepare_continuation("a").interrupted==0)
	assert(replica._valid_state(replica.snapshot()),"Loaded routes and viewing places use the same canonical numbers")
	assert(replica.state.families.a.members[0].task.tv_seat==sofa.id)
	for bad: Variant in [null,[],[1],[1,2,3],[1.5,2],[-1,2],[16,2],["1",2]]:
		var malformed: Dictionary=before.duplicate(true); malformed.families.a.members[0].task.tv_place=bad
		var held: Dictionary=replica.snapshot()
		assert(not replica.restore(malformed,true) and replica.snapshot()==held)
	var collision: Dictionary=before.duplicate(true)
	collision.families.a.members[1].task=collision.families.a.members[0].task.duplicate(true)
	assert(not replica.restore(collision,true),"Duplicate seat/approach reservations are rejected atomically")
	var stale: Dictionary=before.duplicate(true)
	stale.families.a.members[0].task.tv_seat="missing"
	assert(not replica.restore(stale,true))
	assert(replica.restore_saved(stale))
	assert(replica.prepare_continuation("a").interrupted==1,"Stale disk reservations stop with a load explanation")
	_cancel(second)
	for tick in range(140): world.step(0.1)
	assert(first.task.is_empty() and TV.user(world.state,lot,str(sofa.id)).is_empty(),"Completion releases the reservation")
	# Every seat rotation uses its front approach and screen-facing geometry.
	for turn in range(4):
		_fresh(); lot.objects=[tv,sofa]; lot.walls=[]; lot.doors=[]; lot.windows={}
		sofa.x=7; sofa.y=7; sofa.rotation=turn; tv.rotation=(turn+2)%4
		var screen := TV.center(sofa)+TV.front(sofa)*3.0
		tv.x=floori(screen.x); tv.y=floori(screen.y)
		assert(_order(first,tv).ok and first.task.tv_seat==sofa.id)
		_arrive(first)
		assert(TV.current(lot,first.task))
		sofa.x+=5
		world.step(0.1); assert(first.task.is_empty(),"Moved seating cannot drag a viewer across the room")
	_fresh(); lot.objects.erase(sofa)
	assert(_order(first,tv).ok and first.task.tv_seat=="","No seat retains a standing option")
	_cancel(first); lot.objects.append(sofa); sofa.rotation=2
	assert(_order(first,tv).ok and first.task.tv_seat=="","Backward seats are unsuitable")
	_cancel(first); sofa.rotation=0; lot.walls.append([4,9]); lot.walls.append([5,9])
	assert(TV.seat_cells(lot,tv,sofa).is_empty(),"Blocked approach/sight lines cannot claim seating")
	_fresh(); assert(_order(first,tv).ok)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(first.task.is_empty() and TV.user(world.state,lot,str(sofa.id)).is_empty())
	_fresh(); assert(_order(first,tv).ok)
	world.set_online("a",false)
	assert(first.task.is_empty(),"Disconnect releases deliberate viewing")
	# Floor-local seats and visitor ownership use the same command boundary.
	_fresh(); world.ensure_family("b","Guest"); world.set_online("b",true)
	var guest: Dictionary=world.state.families.b.members[0]; guest.autonomy=false
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":lot.id}).ok)
	assert(world.apply_command("b",{"type":"interact","member_id":guest.id,"lot_id":lot.id,"target_id":tv.id,"tv_seat":"forged","tv_place":[0,0]}).ok)
	assert(guest.task.tv_seat==sofa.id and guest.task.tv_place!=[0,0],"Clients cannot supply their own seat or route")
	assert(not world.apply_command("a",{"type":"cancel","member_id":guest.id}).ok)
	assert(world.apply_command("b",{"type":"go_home","member_id":guest.id}).ok)
	assert(TV.user(world.state,lot,str(sofa.id)).is_empty())
	var upstairs: Dictionary=preload("res://game/storeys.gd").empty()
	upstairs.floors=lot.floors.duplicate(true)
	var upper_tv: Dictionary=world._new_object("tv",4,10,2)
	var upper_seat: Dictionary=world._new_object("sofa",4,8,0)
	upstairs.objects=[upper_tv,upper_seat]; lot.storeys["1"]=upstairs
	first.level=1; first.x=7; first.y=7
	assert(_order(first,upper_tv).ok and first.task.tv_seat==upper_seat.id)
	assert(_order(second,tv).ok and second.task.tv_seat==sofa.id)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	# No visible/reachable front place rejects without losing the existing plan.
	_fresh(); tv.rotation=0
	var held: Dictionary=world.snapshot()
	assert(not _order(first,tv).ok and world.snapshot()==held)
	print("TELEVISION_PASS"); quit()
