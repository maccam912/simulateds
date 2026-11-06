extends SceneTree
const World = preload("res://game/world.gd")
const Status = preload("res://game/activity_status.gd")
const Catalog = preload("res://game/catalog.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _estimate(kind: String, need_value: float, automatic: bool, rank_up: bool=false) -> void:
	var world := World.new(); world.initialize(); world.ensure_family("a","Alex"); world.set_online("a",true)
	var lot: Dictionary=world.state.lots.lot_1
	var member: Dictionary=world.state.families.a.members[0]
	for resident: Dictionary in world.state.families.a.members: resident.autonomy=false
	if rank_up:
		for entry: Dictionary in member.hobbies.values(): entry.sessions=14
	var object: Dictionary={}
	if kind=="game_table": lot.objects.append(world._new_object(kind,8,5,0))
	for candidate: Dictionary in lot.objects:
		if candidate.kind==kind: object=candidate; break
	var cell: Vector2i=world._interaction_cells(lot,object)[0]
	if kind=="tv":
		var viewing: Dictionary=preload("res://game/television.gd").choose(world.state,lot,member,object,world._path)
		assert(not viewing.is_empty())
		cell=Vector2i(viewing.tv_place[0],viewing.tv_place[1])
	member.x=cell.x; member.y=cell.y
	for need: String in member.needs: member.needs[need]=100.0
	member.needs[Catalog.ITEMS[kind].need]=need_value
	world._queue_action(member,{"type":"interact","target_id":object.id,"automatic":automatic}); world._start_next(member,lot)
	assert(member.task.path.is_empty())
	var before: Dictionary=world.snapshot()
	var status := Status.sample(member,lot)
	assert(status.phase=="activity" and world.snapshot()==before)
	var estimate: float=status.remaining
	var elapsed := 0.0; var progress := 0.0
	for tick in range(200):
		world.step(0.1); elapsed+=0.1
		if member.task.is_empty(): break
		status=Status.sample(member,lot)
		assert(status.progress>=progress-0.0001 and status.progress>=0 and status.progress<=1,"Ordinary activity progress advances monotonically")
		progress=status.progress
	assert(member.task.is_empty() and absf(estimate-elapsed)<=0.11,"Estimate follows actual early completion: %s estimated %.2f actual %.2f" % [kind,estimate,elapsed])

func _capture(name: String) -> void:
	game._refresh(); await process_frame; await process_frame
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/activity-status-"+name+suffix+".png")==OK)

func _run() -> void:
	for kind: String in ["bed","fridge","shower","toilet","sofa","tv","bookshelf","plant","table","game_table"]:
		for need: float in [10.0,80.0,100.0]:
			for automatic: bool in [false,true]: _estimate(kind,need,automatic)
	for kind: String in ["bookshelf","plant","fridge"]: _estimate(kind,70.0,false,true)
	var sample := {"action":"Waiting for Robin · Kitchen fridge","task":{},"queue":[]}
	assert(Status.sample(sample,{}).phase=="waiting" and Status.sample(sample,{}).progress<0)
	sample.action="Chatting with Robin"
	assert(Status.sample(sample,{}).phase=="company")
	sample.task={"type":"move","path":[[1,1]]}; sample.action="Walking"
	assert(Status.sample(sample,{}).phase=="travel" and Status.sample(sample,{}).progress<0)
	sample.task.path=[]; assert(Status.sample(sample,{}).detail=="Arriving")
	sample.task={"type":"interact","target_id":"gone","path":[],"elapsed":2.0,"remaining":8.0}
	assert(Status.sample(sample,{}).phase=="unavailable")
	assert(Status.sample(sample,{"building":true}).phase=="paused")
	sample.task={"type":"interact","target_kind":"member","path":[],"elapsed":4.0,"remaining":6.0}
	var chat := Status.sample(sample,{})
	assert(is_equal_approx(chat.progress,0.4) and chat.remaining==6.0 and "18 min" in chat.detail,"Conversation lasts its full duration even if social is already satisfied")
	# The actual Plan updates in place: no rebuilding controls on each tick,
	# no progress while paused, and no local advancement between snapshots.
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]
	for resident: Dictionary in family.members: resident.autonomy=false; resident.needs.hunger=10.0
	var first: Dictionary=family.members[0]; var second: Dictionary=family.members[1]
	var fridge: Dictionary={}
	for object: Dictionary in session.state.lots.lot_1.objects:
		if object.kind=="fridge": fridge=object
	session.command({"type":"interact","member_id":first.id,"target_id":fridge.id})
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); game._show_tray(game.plan_panel,true)
	await _capture("travel")
	assert(game._plan_detail.text=="On the way" and not game._plan_progress.visible)
	assert(game.activity_timing.text=="On the way" and not game.activity_progress.visible)
	var cancel: Button=game.plan_controls[first.task.id].cancel
	var control_id := cancel.get_instance_id(); var detail_id: int=game._plan_detail.get_instance_id()
	cancel.grab_focus()
	for tick in range(100):
		session.world.step(0.1)
		if first.task.path.is_empty() and first.task.elapsed>=1: break
	game._refresh()
	assert(game._plan_progress.visible and game._plan_progress.value>0 and game._plan_progress.value<1)
	assert(game._plan_detail.get_instance_id()==detail_id and game.plan_controls[first.task.id].cancel.get_instance_id()==control_id and cancel.has_focus(),"Travel-to-activity updates preserve control identity and keyboard focus")
	await _capture("meal")
	var day_minutes: float=session.state.day_minutes
	session.state.day_minutes=1320; await _capture("meal-night"); session.state.day_minutes=day_minutes
	assert(game.activity_progress.visible and is_equal_approx(game.activity_progress.value,game._plan_progress.value))
	assert(game.activity_timing.text in game._plan_detail.text)
	var progress: float=game._plan_progress.value
	await create_timer(0.3).timeout; game._refresh()
	assert(game.activity_progress.value==progress and game._plan_progress.value==progress,"Presentation time cannot advance paused or stale-snapshot progress")
	var replica := World.new(); assert(replica.restore(session.world.snapshot(),true)); replica.step(0.5)
	session.world=replica; first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]
	var accepted: Dictionary=session.world.snapshot(); game._refresh()
	assert(game._plan_progress.value>progress and game._plan_detail.get_instance_id()==detail_id and session.world.snapshot()==accepted,"Replacement snapshots update the same UI without mutating the world")
	session.command({"type":"interact","member_id":second.id,"target_id":fridge.id}); game._select_resident(str(second.id))
	await _capture("waiting")
	assert("Waiting for Alex" in game._plan_detail.text and not game._plan_progress.visible)
	var waited: String=second.queue[0].id
	session.command({"type":"cancel","member_id":first.id}); session.world.step(0.1); game._refresh()
	assert(second.task.id==waited and game._plan_detail.text=="On the way" and not game._plan_progress.visible)
	# An idle conversation partner is participating, not falsely described as free.
	for resident: Dictionary in session.state.families[session.profile_id].members: session.command({"type":"cancel","member_id":resident.id})
	first.x=7; first.y=7; second.x=8; second.y=7
	session.command({"type":"interact","member_id":first.id,"target_id":second.id}); session.world.step(0.1)
	game._refresh(); await _capture("company")
	assert(game.plan_box.get_child_count()==1 and "Chatting with Alex" in game.plan_box.get_child(0).text and second.task.is_empty())
	print("ACTIVITY_STATUS_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
