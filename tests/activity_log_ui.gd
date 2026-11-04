extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _click(control: Button) -> void:
	await process_frame; await process_frame
	var point := control.get_global_rect().get_center()
	assert(root.get_visible_rect().has_point(point))
	var received := [false]; control.pressed.connect(func(): received[0]=true,CONNECT_ONE_SHOT)
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.pressed=pressed; event.button_index=MOUSE_BUTTON_LEFT
		root.push_input(event,true); await process_frame
	assert(received[0],"The history control must receive actual mouse input")
	await process_frame

func _capture(name: String) -> void:
	game._refresh(); await process_frame; await process_frame
	assert(game.plan_panel.get_global_rect().end.x<=root.size.x and game.plan_panel.get_global_rect().position.y>=0)
	assert(game.recent_button.get_global_rect().end.x<game.plan_panel.get_global_rect().end.x)
	assert(game.plan_scroll.size.y>45,"The history retains usable reading space at compact scale")
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/activity-log-"+name+suffix+".png")==OK)

func _finish(member: Dictionary) -> void:
	for tick in range(1200):
		session.world.step(0.1)
		if tick%20==0: game._refresh(); await process_frame
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false,"Planned activity never finished")

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]
	for resident: Dictionary in family.members: resident.autonomy=false
	var first: Dictionary=family.members[0]; var second: Dictionary=family.members[1]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _click(game.queue_label); await _click(game.recent_button)
	assert(game._plan_recent and game.recent_rows.is_empty())
	await _capture("empty")
	# One resident completes care while the other follows their own plan.
	first.needs.hunger=15.0
	session.command({"type":"care","member_id":first.id,"need":"hunger"})
	assert(session.last_action_ok)
	session.command({"type":"move","member_id":second.id,"x":0,"y":0}); assert(session.last_action_ok)
	await _finish(first)
	game._refresh(); await process_frame
	assert(game.recent_rows.size()==1 and first.activity_log[0].outcome=="done")
	assert(second.activity_log.size()==1 and second.activity_log[0].title=="Walk to 0, 0")
	assert(game.recent_rows[0].get_child(0).text.begins_with("Done · "))
	await _capture("finished")
	# Cancel with the existing Plan button, then inspect the specific result.
	await _click(game.recent_button)
	session.command({"type":"move","member_id":first.id,"x":0,"y":0})
	game._refresh(); await process_frame
	var cancelled: String=first.task.id
	await _click(game.plan_controls[cancelled].cancel)
	await _click(game.recent_button)
	assert(game.recent_rows[0].get_meta("activity_id")==cancelled and game.recent_rows[0].get_child(1).text=="Cancelled from Plan.")
	# A later host update explains a missing furnishing while preserving its name.
	var shelf: Dictionary={}
	for object: Dictionary in session.state.lots.lot_1.objects:
		if object.kind=="bookshelf": shelf=object
	session.command({"type":"interact","member_id":first.id,"target_id":shelf.id})
	var title: String=first.task.title
	session.state.lots.lot_1.objects.erase(shelf)
	await _finish(first); game._refresh(); await process_frame
	assert(game.recent_rows[0].get_child(0).text=="Interrupted · "+title)
	assert(game.recent_rows[0].get_child(1).text=="The furnishing is no longer here.")
	await _capture("outcomes")
	# Stable rows neither steal focus nor jump to top on ordinary snapshot refresh.
	for x in range(8): session.command({"type":"move","member_id":first.id,"x":x,"y":0})
	session.command({"type":"cancel","member_id":first.id})
	game._refresh(); await process_frame; await process_frame
	assert(game.recent_rows.size()==8)
	game.plan_scroll.scroll_vertical=1000; game.recent_button.grab_focus()
	await process_frame
	var scroll: int=game.plan_scroll.scroll_vertical; var row: Control=game.recent_rows[0]
	for refresh in range(5): game._refresh(); await process_frame
	assert(game.recent_rows[0]==row and game.plan_scroll.scroll_vertical==scroll and game.recent_button.has_focus())
	await _capture("full-list")
	await _click(game.family_box.get_child(1))
	assert(game._plan_recent and game.recent_rows.size()==1 and game.recent_rows[0].get_meta("activity_id")==second.activity_log[0].id,"Changing residents updates their independent history")
	await _capture("other-resident")
	# Replacing a whole state (as networking does) creates no spurious outcomes.
	var expected: Array=second.activity_log.duplicate(true)
	assert(session.world.restore(JSON.parse_string(JSON.stringify(session.world.snapshot())),true))
	game._refresh(); await process_frame
	assert(session.state.families[session.profile_id].members[1].activity_log==expected and game.recent_rows.size()==1)
	await _click(game.recent_button)
	assert(not game._plan_recent and game.plan_controls.is_empty())
	print("ACTIVITY_LOG_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
