extends SceneTree
## One accepted user per seating furnishing, including its television reservation.
const World = preload("res://game/world.gd")
const TV = preload("res://game/television.gd")
var world: RefCounted
var lot: Dictionary
var first: Dictionary
var second: Dictionary
var seat: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh(kind: String="sofa", turn: int=0) -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	lot=world.state.lots.lot_1
	first=world.state.families.a.members[0]; second=world.state.families.a.members[1]
	for member: Dictionary in [first,second]:
		member.autonomy=false; member.needs.comfort=10.0; member.needs.fun=10.0
	seat=lot.objects.filter(func(item): return item.kind=="sofa")[0]
	if kind!="sofa" or turn!=0:
		lot.objects=[seat]; seat.kind=kind; seat.x=7; seat.y=8; seat.rotation=turn
		first.x=5; first.y=6; second.x=9; second.y=6

func _order(member: Dictionary, target: Dictionary, owner: String="a") -> void:
	var result: Dictionary=world.apply_command(owner,{"type":"interact","member_id":member.id,"lot_id":lot.id,"target_id":target.id})
	assert(result.ok,result.message)

func _cancel(member: Dictionary) -> void:
	assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)

func _arrive(member: Dictionary) -> void:
	for tick in range(100):
		world.step(0.1)
		if member.task.get("elapsed",0)>0: return
	assert(false,"The reserved seat must remain reachable")

func _run() -> void:
	for kind: String in TV.SEATS:
		for turn in range(4):
			_fresh(kind,turn)
			_order(first,seat); _order(second,seat)
			assert(not first.task.path.is_empty(),"Reserve the seat during approach")
			assert(second.task.is_empty() and second.queue.size()==1,"Two residents cannot use one seat at once")
			var waiting_id: String=second.queue[0].id
			var waiting_at := Vector2i(second.x,second.y)
			_arrive(first)
			assert(second.task.is_empty() and Vector2i(second.x,second.y)==waiting_at)
			assert(second.action=="Waiting for Alex · "+str(preload("res://game/catalog.gd").ITEMS[kind].name))
			assert(second.needs.comfort<10.0,"Waiting must not award the seat's comfort benefit")
			_cancel(first); world.step(0.1)
			assert(second.task.get("id")==waiting_id,"Cancellation releases the seat without replacing the queued order")
			_arrive(second)
			_order(first,seat)
			for tick in range(150):
				world.step(0.1)
				if first.task.get("target_id")==seat.id: break
			assert(first.task.get("target_id")==seat.id and second.task.is_empty(),"Completion releases the seat to its waiter")
	# Occupied seats are skipped by autonomy; a deliberate order still waits.
	_fresh(); _order(first,seat); second.autonomy=true
	world._choose_autonomy(second,lot)
	assert(second.task.get("target_id")!=seat.id and second.queue.is_empty())
	# TV and ordinary relaxation must agree about ownership in either order.
	for television_first: bool in [false,true]:
		_fresh()
		var tv: Dictionary=lot.objects.filter(func(item): return item.kind=="tv")[0]
		_order(first,tv if television_first else seat)
		_order(second,seat if television_first else tv)
		if television_first:
			assert(first.task.tv_seat==seat.id and second.task.is_empty() and second.queue.size()==1)
		else:
			assert(second.task.tv_seat=="","A relaxing resident keeps the sofa; the viewer stands")
	# A replicated snapshot and disk continuation retain owner and waiter.
	_fresh(); _order(first,seat); _order(second,seat); _arrive(first)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(world.snapshot_for_save()))
	var restored := World.new()
	assert(restored.restore(saved,true))
	assert(restored.restore_saved(saved))
	assert(restored.prepare_continuation("a").interrupted==0)
	assert(restored.state.families.a.members[0].task.target_id==seat.id)
	assert(restored.state.families.a.members[1].task.is_empty() and restored.state.families.a.members[1].queue.size()==1)
	# Legacy overlapping activities are revalidated, with one clear interruption.
	var legacy: Dictionary=saved.duplicate(true)
	var members: Array=legacy.families.a.members
	members[1].task=members[0].task.duplicate(true)
	members[1].task.id=members[1].queue[0].id; members[1].queue=[]
	members[1].x=members[0].x; members[1].y=members[0].y
	assert(restored.restore_saved(legacy))
	assert(restored.prepare_continuation("a").interrupted==1)
	assert(restored.state.families.a.members.filter(func(member): return not member.task.is_empty()).size()==1)
	# Cross-household visitors use the same reservation without gaining control.
	_fresh(); world.ensure_family("b","Guest"); world.set_online("b",true)
	var guest: Dictionary=world.state.families.b.members[0]; guest.autonomy=false
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":lot.id}).ok)
	_order(guest,seat,"b"); _order(first,seat)
	assert(first.task.is_empty() and first.queue.size()==1)
	assert(not world.apply_command("a",{"type":"cancel","member_id":guest.id}).ok)
	assert(world.apply_command("b",{"type":"go_home","member_id":guest.id}).ok)
	world.step(0.1); assert(first.task.get("target_id")==seat.id)
	for release: String in ["construction","disconnect"]:
		_fresh(); _order(first,seat); _order(second,seat)
		if release=="construction": assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
		else: world.set_online("a",false)
		assert(world._object_user(lot.id,seat).is_empty())
	await _review()
	print("SEAT_OCCUPANCY_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()

func _review() -> void:
	var session := root.get_node("Session")
	session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	_fresh(); session.world=world; session.profile_id="a"
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	var prefs := root.get_node("Preferences"); prefs.reset_defaults()
	if compact: prefs.set_value("ui_scale",1.25)
	_order(first,seat); _order(second,seat); _arrive(first)
	var game: Control=load("res://game/main.tscn").instantiate(); root.add_child(game)
	game.selected_member=second.id
	for sample: Array in [[720,"day"],[0,"night"]]:
		session.state.day_minutes=sample[0]; game._refresh()
		for frame in range(4): await process_frame
		var before: Dictionary=world.snapshot()
		var view: Control=game.lot_view
		assert(view._activity_pose(first).get("kind")=="sofa" and view._activity_pose(second).is_empty())
		var a: Node3D=view.projection.scene.resident_nodes[first.id]
		var b: Node3D=view.projection.scene.resident_nodes[second.id]
		assert(a.position.distance_to(b.position)>1.0,"Waiting residents do not share the visible sofa pose")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://build/seat-occupancy-"+sample[1]+("-compact" if compact else "")+".png")==OK)
		assert(world.snapshot()==before,"Rendering cannot move residents or edit reservations")
