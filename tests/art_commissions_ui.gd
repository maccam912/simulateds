extends SceneTree
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
	# Keep native enter/exit events aligned with the injected viewport input.
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _button(control: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(control)
	await process_frame; await process_frame
	assert(control.is_visible_in_tree(),"Open the tray before clicking "+control.text)
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(pressed[0])

func _named(node: Node,title: String) -> Button:
	if node is Button and (node.text==title or node.accessibility_name==title): return node
	for child in node.get_children():
		var found := _named(child,title)
		if found!=null: return found
	return null

func _point(id: String) -> Vector2:
	for region: Dictionary in game.lot_view._hit_regions:
		if region.target.get("type")!="object" or region.target.get("id")!=id: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		if game.lot_view.hit_target(point).get("id")==id and not game.lot_view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"Furnishing must have a visible click surface"); return Vector2.ZERO

func _tile(x: int,y: int,click: bool=false) -> void: await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/commissions-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame; await process_frame

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]; var home: Dictionary=session.state.lots[family.home_lot]
	for resident: Dictionary in family.members: resident.autonomy=false
	var member: Dictionary=family.members[0]; member.name="Alexandra Marigold Montgomery"
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var before: Dictionary=session.world.snapshot()
	await _button(game.palette_button)
	await _button(_named(game.tools_box,"Art commissions")); await _capture("offer")
	assert(session.world.snapshot()==before and game._context_page=="commissions","Reading an offer cannot accept or start painting")
	var panel: VBoxContainer=game.commission_panel
	var terms: Dictionary=preload("res://game/art_commissions.gd").offer(session.profile_id,family.commissions)
	assert(panel.confirm.text.contains("Accept commission") and panel.note.text.contains("No deadline"))
	await _button(panel.confirm); await _capture("accepted")
	assert(home.funds==12000 and not family.commissions.active.is_empty() and panel.pending.is_empty())
	assert(member.task.is_empty() and panel.confirm.text.contains("Build an easel"))
	await _button(panel.confirm); await _capture("find-easel")
	assert(home.building and game.selected_tool=="easel" and game.catalog_search.text=="easel")
	await _tile(9,9,true)
	var easel: Dictionary=home.objects[-1]; assert(easel.kind=="easel")
	await _button(game.mode_button); await _mouse(_point(easel.id),true)
	await _button(game.painting_panel.commission_button)
	panel=game.commission_panel; assert(panel.confirm.text=="View home easel")
	before=session.world.snapshot(); await _button(panel.confirm)
	assert(game._context_page=="painting" and session.world.snapshot()==before,"Easel navigation never chooses a subject")
	assert(game.painting_panel.commission_button.text.contains(preload("res://game/paintings.gd").SUBJECTS[terms.subject]))
	await _button(game.painting_panel.buttons[terms.subject]); await _advance(8)
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":member.id}).ok)
	var partial: Dictionary=easel.painting.duplicate(true)
	await _button(game.painting_panel.commission_button); panel=game.commission_panel
	assert(panel.review_buttons.is_empty() and family.commissions.active.offer==terms.id)
	await _advance(4); assert(easel.painting==partial)
	await _button(panel.confirm); await _button(game.painting_panel.buttons.resume); await _advance(30)
	assert(preload("res://game/paintings.gd").finished(easel.painting))
	await _button(game.painting_panel.commission_button); panel=game.commission_panel
	var source: String="easel:"+str(easel.id)
	assert(panel.review_buttons.size()==1)
	before=session.world.snapshot(); await _button(panel.review_buttons[source]); await _capture("review")
	assert(session.world.snapshot()==before and panel.preview.picture==easel.painting)
	assert(panel.detail.text.contains(member.name) and panel.note.text.contains("cannot be undone"))
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.note.get_global_rect()),"The removal consequence must be visible without scrolling")
	assert(game.context_panel.get_global_rect().encloses(panel.confirm.get_global_rect()))
	await _button(panel.back); assert(panel.review.is_empty() and session.world.snapshot()==before)
	await _button(panel.review_buttons[source]); await _key(KEY_ESCAPE)
	assert(panel.review.is_empty() and game.context_panel.visible and session.world.snapshot()==before)
	await _button(panel.review_buttons[source])
	# A changed original invalidates an open quote; it never silently substitutes another.
	easel.painting.revision+=1; game._refresh(); await _capture("changed-original")
	assert(panel.confirm.disabled and not panel.review.is_empty())
	await _button(panel.back); await _button(panel.review_buttons[source])
	var intent: Dictionary=panel.review.intent.duplicate(true)
	panel.pending=intent.duplicate(true); panel.refresh()
	session.command_completed.emit({"type":"cancel"},true,"Other activity")
	assert(not panel.pending.is_empty() and panel.confirm.disabled)
	session.command_completed.emit(intent,false,"The neighborhood declined this delivery.")
	assert(panel.pending.is_empty() and not panel.review.is_empty() and panel.feedback.text.contains("declined"))
	# A successful reply alone cannot imply the authoritative snapshot arrived.
	panel.pending=intent.duplicate(true); panel._error=""; panel.refresh()
	session.command_completed.emit(intent,true,"Delivered")
	assert(not panel.pending.is_empty() and panel.confirm.disabled and not panel.leave_review())
	panel.pending={}; panel._ack=false; panel.refresh()
	var funds: int=home.funds
	await _button(panel.confirm); await _capture("delivered")
	assert(home.funds==funds+180 and easel.painting.subject=="" and panel.pending.is_empty() and panel.review.is_empty())
	assert(family.commissions.completed==1 and family.commissions.history[0].credit.contains(member.name))
	assert(panel.heading.tooltip_text==terms.request,"The delivered recipient keeps its own request wording, not tomorrow's offer")
	assert(panel.confirm.disabled and panel.note.text.contains("tomorrow") and panel.history.get_child_count()==2)
	assert(not session.world.apply_command(session.profile_id,intent).ok and home.funds==funds+180)
	var saved: Dictionary=session.world.snapshot_for_save()
	assert(session.world.restore(JSON.parse_string(JSON.stringify(saved)),true)); game._refresh(); await _capture("restored")
	assert(session.state.families[session.profile_id].commissions.history==family.commissions.history)
	# Session replacement clears a local review rather than carrying a quote into another home.
	session.world_generation+=1; panel.review={"old":true}; panel.pending={"old":true}; panel.refresh()
	assert(panel.review.is_empty() and panel.pending.is_empty())
	print("ART_COMMISSIONS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
