extends SceneTree
## Two real processes share only an isolated save, profile and expectations.
const World = preload("res://game/world.gd")
const Disk = preload("res://game/persistence.gd")
const Library = preload("res://game/save_library.gd")
const Jobs = preload("res://game/art_commissions.gd")
const Paintings = preload("res://game/paintings.gd")
const WallArt = preload("res://game/wall_art.gd")

var session: Node
var app: Control
var game: Control
var profile: String
var home: String
var review := false
var compact := false

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	session=root.get_node("Session"); session.set_physics_process(false)
	profile=session.profile_id; home=session.home_lot()
	review="--capture-continuity" in OS.get_cmdline_user_args()
	compact="--compact" in OS.get_cmdline_user_args()
	if review:
		root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
		if compact: root.get_node("Preferences").set_value("ui_scale",1.25)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await process_frame
	app.show_game(); game=app.game
	if "--continuity-write" in OS.get_cmdline_user_args():
		await _write_fixture()
	else:
		await _check_continuation()

func _command(type: String, fields: Dictionary = {}) -> void:
	var command := {"type":type}
	command.merge(fields)
	var result: Dictionary=session.world.apply_command(profile,command)
	assert(result.ok,str([command,result]))

func _write_fixture() -> void:
	var world: RefCounted=session.world
	var lot: Dictionary=session.state.lots[home]
	var other_lot: String=world.ensure_family("other","Neighbors")
	var family: Dictionary=session.state.families[profile]
	family.name="The Linden Grove Reading and Kitchen Garden Household"
	var alex: Dictionary=family.members[0]; var robin: Dictionary=family.members[1]
	var june: Dictionary=world._create_resident(family,profile+"_3","June")
	june.character=preload("res://game/character_profile.gd").defaults(june)
	june.character.age=2
	family.members.append(june)
	preload("res://game/friendships.gd").ensure_housemates(session.state,family)
	for household: Dictionary in session.state.families.values():
		for resident: Dictionary in household.members: resident.autonomy=false
	_command("build_begin")
	_command("place",{"kind":"stairs","x":8,"y":4})
	_command("place_area",{"kind":"floor","x":6,"y":3,"end_x":11,"end_y":7,"level":1,"revision":lot.revision})
	_command("place",{"kind":"bed","x":6,"y":4,"level":1})
	_command("place",{"kind":"easel","x":9,"y":9})
	_command("build_end")
	var offer: Dictionary=Jobs.offer(profile,family.commissions)
	_command("commission_accept",{"commission_revision":family.commissions.revision,"offer":offer.id})
	var easel: Dictionary=lot.objects.filter(func(item): return item.kind=="easel")[0]
	_paint(alex,easel,offer.subject)
	var source: String="easel:"+str(easel.id)
	_command("commission_deliver",{"commission_revision":family.commissions.revision,"offer":offer.id,
		"revision":lot.revision,"art_source":source,"art_id":WallArt.source(lot,source).art_id})
	_paint(alex,easel,"flowers")
	family.pantry.radish=6
	_command("visit",{"member_id":alex.id,"lot_id":other_lot})
	_command("move",{"member_id":alex.id,"lot_id":other_lot,"x":8,"y":10})
	world.set_online("other",true)
	var neighbor: Dictionary=session.state.families.other.members[0]
	assert(world.apply_command("other",{"type":"visit","member_id":neighbor.id,"lot_id":home}).ok)
	_command("use_stairs",{"member_id":robin.id,"direction":1})
	for tick in range(80): world.step(0.1)
	assert(robin.level==1 and alex.lot_id==other_lot and alex.y==10)
	var bed: Dictionary=lot.storeys["1"].objects[0]
	robin.needs.energy=30.0
	_command("interact",{"member_id":robin.id,"target_id":bed.id,"level":1})
	_command("move",{"member_id":robin.id,"x":10,"y":3,"level":1})
	var shelf: Dictionary=lot.objects.filter(func(item): return item.kind=="bookshelf")[0]
	june.x=10; june.y=9; june.needs.fun=30.0
	# Let the real autonomy chooser start Reading; another resident has the
	# deliberate queued order, which won't replace June's activity.
	june.autonomy=true; june.idle_clock=2.0
	for tick in range(7): world.step(0.1)
	assert(june.action=="Reading" and june.task.automatic and june.task.target_id==shelf.id and is_equal_approx(june.task.remaining,11.3))
	assert(robin.queue.size()==1 and world._object_user(home,bed).id==robin.id)
	session.state.day=3; session.state.day_minutes=285.0
	assert(session.set_play_speed(4).ok and session.set_play_speed(0).ok)
	game.selected_member=june.id; game.viewed_lot=home; game.view_level=1; game._refresh()
	game.lot_view.restore_framing({"zoom":1.45,"pan_x":-1.4,"pan_y":1.2})
	assert(Disk.write_json(session.save_path+".expected",world.snapshot_for_save()))
	await _key(KEY_F5)
	assert(FileAccess.file_exists(session.save_path),"F5 wrote the solo autosave")
	app.open_pause(); app._request_quit()
	print("SAVE_CONTINUITY_WRITE_PASS")
	app._confirm_action.call()

func _paint(member: Dictionary, easel: Dictionary, subject: String) -> void:
	_command("painting",{"member_id":member.id,"target_id":easel.id,"action":"start","subject":subject,"revision":easel.painting.revision})
	for tick in range(350):
		session.world.step(0.1)
		if member.task.is_empty(): break
	assert(Paintings.finished(easel.painting))

func _check_continuation() -> void:
	var expected := World.new()
	var fixture: Dictionary=Disk.read_json(session.save_path+".expected")
	assert(fixture.ok and expected.restore_saved(fixture.data))
	var start: Dictionary=session.state.families[profile]
	var alex: Dictionary=start.members[0]; var robin: Dictionary=start.members[1]; var june: Dictionary=start.members[2]
	var night: Dictionary=session.state.lots[home]
	assert(start.members==expected.state.families[profile].members,"Restart preserves exact locations, task clocks, queues, and needs")
	assert(june.action=="Reading" and robin.level==1 and alex.lot_id!=home)
	var guest: Dictionary=session.state.families.other.members[0]
	assert(not session.state.families.other.online and guest.lot_id==home)
	assert(session.world._position(guest)==expected._position(expected.state.families.other.members[0]))
	assert(session.state.tick==expected.state.tick and session.state.day_minutes==285.0)
	assert(night==expected.state.lots[home] and start.commissions==expected.state.families[profile].commissions)
	assert(start.pantry.radish==6 and start.commissions.completed==1)
	assert(not session.state.has("solo_view"),"Presentation stays out of authoritative snapshots")
	_assert_view(june.id)
	assert(session.debug_speed==0 and session._resume_speed==4 and not session.menu_paused)
	session._advance_simulation(1.0)
	assert(session.state.tick==expected.state.tick,"Continue stays paused until explicitly resumed")
	await _capture("night")
	app.open_saves("save")
	app.slot_name.text="Day Three Reading at Clover Cottage and Upstairs"
	app._perform_save("")
	var slot_id: String=app.selected_slot
	assert(not slot_id.is_empty())
	await _capture("save")
	app._confirm_overwrite()
	await _capture("overwrite")
	app._back()
	# Change both the active home and the view before replacing it.
	night.funds+=987
	session.state.day_minutes=760.0
	game.selected_member=alex.id; game.viewed_lot=alex.lot_id; game.view_level=0; game._refresh()
	game.lot_view.center_lot()
	var previous: Dictionary=session.world.snapshot_for_save()
	app.open_saves("load",slot_id)
	app._perform_load()
	assert(session.state.families[profile].members==expected.state.families[profile].members)
	_assert_view(june.id)
	assert(session.debug_speed==0 and session._resume_speed==4 and game.notice_recovery_button.visible)
	await _capture("loaded")
	var reading: Dictionary=session.state.families[profile].members[2]
	assert(session.toggle_play_pause().ok and session.debug_speed==4.0)
	session._advance_simulation(0.1)
	assert(reading.action=="Reading" and is_equal_approx(reading.task.remaining,10.9))
	assert(session.set_play_speed(0).ok)
	game.notice_recovery_button.pressed.emit()
	assert(app.page=="load" and app.selected_slot==app._recovery.id)
	await _capture("recovery")
	app._perform_load()
	assert(session.state.lots[home].funds==previous.lots[home].funds and session.state.day_minutes==760.0)
	assert(game.selected_member==alex.id and game.viewed_lot==alex.lot_id and game.lot_view.zoom==1.0)
	assert(Library.read_slot(session.slots_path,slot_id).world.lots[home].funds==expected.state.lots[home].funds)
	await _capture("day")

	# A stale target and one unsafe position recover independently. The valid
	# upstairs task/queue and its exclusive bed reservation still continue.
	var stale := expected.snapshot()
	var residents: Array=stale.families[profile].members
	var stale_lot: Dictionary=stale.lots[home]
	for item: Dictionary in stale_lot.objects.duplicate():
		if item.kind=="bookshelf": stale_lot.objects.erase(item)
	residents[0].x=4; residents[0].y=4 # Inside a bed on the visited lot.
	var stale_model := World.new()
	assert(stale_model.restore_saved(stale))
	assert(stale_model.apply_command(profile,{"type":"use_stairs","member_id":robin.id,"direction":-1}).ok)
	var bad: Dictionary=Library.write_slot(session.slots_path,"Blocked spot and missing shelf",stale_model.snapshot_for_save())
	assert(bad.ok)
	app.open_saves("load",bad.id); app._perform_load()
	start=session.state.families[profile]
	assert(start.members[0].lot_id==home and session.world._walkable(session.state.lots[home],session.world._position(start.members[0])))
	assert(start.members[2].task.is_empty() and start.members[2].x==june.x and start.members[2].y==june.y)
	assert("returned home" in game.notice_label.text and "2 unfinished activities stopped" in game.notice_label.text)
	assert("no longer here" in game.notice_label.tooltip_text and "Go downstairs" in game.notice_label.tooltip_text)
	var kept: Dictionary=start.members[1]
	var bed: Dictionary=session.state.lots[home].storeys["1"].objects[0]
	assert(kept.task==robin.task and kept.queue==robin.queue and session.world._object_user(home,bed).id==kept.id)
	assert(kept.activity_log[0].title=="Go downstairs")
	var time: float=kept.task.remaining
	assert(session.toggle_play_pause().ok and session.debug_speed==1.0,"Slots without view metadata resume at 1×")
	for tick in range(25): session.world.step(0.1)
	assert(kept.task.remaining<time,"The restored task advances normally")
	for tick in range(260): session.world.step(0.1)
	assert(kept.task.is_empty() and kept.queue.is_empty() and kept.level==1 and kept.x==10 and kept.y==3)
	assert(session.world._object_user(home,bed).is_empty(),"Completion releases the same reservation")
	print("SAVE_CONTINUITY_READ_PASS")
	await session.quit_application()

func _assert_view(member_id: String) -> void:
	var framing: Dictionary=game.lot_view.saved_framing()
	assert(game.selected_member==member_id and game.viewed_lot==home and game.view_level==1)
	assert(is_equal_approx(framing.zoom,1.45) and is_equal_approx(framing.pan_x,-1.4) and is_equal_approx(framing.pan_y,1.2))

func _key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	if not review or DisplayServer.get_name()=="headless": return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/save-continuity-"+name+("-compact" if compact else "")+".png")==OK)
