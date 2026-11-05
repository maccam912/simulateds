extends SceneTree
const Art=preload("res://game/wall_art.gd")
var session: Node
var app: Control
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func _mouse(point: Vector2,click: bool=false) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion:=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; root.push_input(event,true); await process_frame
	await process_frame; await process_frame
func _click(control: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(control)
	await process_frame; await process_frame
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control); await process_frame; await process_frame
			assert(parent.get_global_rect().encloses(control.get_global_rect()))
		parent=parent.get_parent()
	var clicked: Array=[false]; control.pressed.connect(func(): clicked[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(clicked[0])
func _named(node: Node,title: String) -> Button:
	if node is Button and (node.text==title or node.accessibility_name==title): return node
	for child in node.get_children():
		var button:=_named(child,title)
		if button!=null: return button
	return null
func _capture(name: String) -> void:
	await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/art-gifts-"+name+suffix+".png")==OK)
func _text(node: Node) -> String:
	var value:=str(node.text)+"\n" if node is Label else ""
	for child in node.get_children(): value+=_text(child)
	return value
func _make_art(owner: String,subject: String) -> Dictionary:
	var home: Dictionary=session.state.lots[session.state.families[owner].home_lot]
	session.world.set_online(owner,true)
	for resident: Dictionary in session.state.families[owner].members: resident.autonomy=false
	assert(session.world.apply_command(owner,{"type":"build_begin","lot_id":home.id}).ok)
	assert(session.world.apply_command(owner,{"type":"place","lot_id":home.id,"kind":"easel","x":9,"y":9}).ok)
	var easel: Dictionary=home.objects[-1]
	assert(session.world.apply_command(owner,{"type":"build_end","lot_id":home.id}).ok)
	assert(session.world.apply_command(owner,{"type":"painting","lot_id":home.id,"target_id":easel.id,"member_id":session.state.families[owner].members[0].id,"action":"start","subject":subject,"revision":0}).ok)
	for step in range(400):
		session.world.step(0.1)
		if preload("res://game/paintings.gd").finished(easel.painting): return easel
	assert(false); return {}
func _choose_art(panel: Control,source: String) -> void:
	for index in range(panel.gift_input.item_count):
		var data: Dictionary=panel.gift_input.get_item_metadata(index)
		if data.get("source")==source:
			panel.gift_input.select(index); panel.gift_input.item_selected.emit(index); return
	assert(false,"The finished painting should be offered")
func _note(panel: Control,value: String) -> void:
	panel.note_input.text=value; panel.note_input.text_changed.emit(value)
func _wall_point() -> Vector2:
	for region: Dictionary in app.game.lot_view._hit_regions:
		if region.target.get("type")!="wall" or region.target.get("x")!=8 or region.target.get("y")!=3: continue
		var point:=Vector2.ZERO
		for vertex: Vector2 in region.polygon: point+=vertex
		point/=region.polygon.size()
		if app.game.lot_view.hit_target(point).get("x")==8: return point
	assert(false); return Vector2.ZERO
func _run() -> void:
	var compact: bool="--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("violet","Violet"); session.world.ensure_family("sam","Sam")
	var own:=_make_art(session.profile_id,"meadow"); var neighbor:=_make_art("violet","harbor")
	var original: Dictionary=own.painting.duplicate(true); var gift_picture: Dictionary=neighbor.painting.duplicate(true)
	session.world.set_online("violet",false)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app); await create_timer(0.9).timeout; app.show_game()
	await _click(app.game.mail_button); var panel: Control=app.mail_panel
	await _click(panel.write_button); _note(panel,"For your new home. Hope you like the meadow!")
	_choose_art(panel,"easel:"+str(own.id)); await _capture("compose")
	assert(panel.send_button.get_global_rect().position.y>=panel.body.get_parent().get_global_rect().end.y and app.menu_panel.get_global_rect().encloses(panel.send_button.get_global_rect()),"Send and its transfer explanation stay outside the scrolling draft")
	assert(panel.body.get_parent().get_global_rect().encloses(panel.art_preview.get_global_rect()) and panel.body.get_parent().get_global_rect().encloses(panel.art_credit.get_global_rect()),"Preview and artist credit stay visible before sending")
	assert(panel.art_preview.visible and panel.art_preview.picture==original and panel.art_credit.text.contains("By Alex") and not panel.send_button.disabled)
	var before: Dictionary=session.world.snapshot()
	panel.art_id="art_object_999_2"; panel._refresh_gifts(); panel._update_controls(); await _capture("stale-choice")
	assert(panel.send_button.disabled and not panel.art_preview.visible and session.world.snapshot()==before)
	_choose_art(panel,"easel:"+str(own.id)); await _click(panel.send_button)
	assert(own.painting.subject=="" and panel.pending.is_empty() and session.state.families.violet.mailbox.items[0].art.picture==original)
	await _capture("sent")
	# A picture can arrive while the recipient is away and starts construction later.
	session.world.set_online(session.profile_id,false)
	var chosen:=Art.source(session.state.lots.lot_2,"easel:"+str(neighbor.id))
	assert(session.world.apply_command("violet",{"type":"mail_send","recipient":session.profile_id,"note":"A harbor for your wall. Love, Violet.","gift":0,"sequence":1,"art_source":"easel:"+str(neighbor.id),"art_id":chosen.art_id,"revision":session.state.lots.lot_2.revision}).ok)
	session.world.set_online(session.profile_id,true)
	await _click(_named(app.menu_content,"Back to neighborhood")); await _click(app.game.mode_button); await _click(app.game.mail_button)
	panel=app.mail_panel; assert(panel.view=="news" and _text(panel.body).contains("1 painting waiting")); await _capture("home-news")
	await _click(panel.news_inbox_button)
	var card: Dictionary=session.state.families[session.profile_id].mailbox.items[0]; var art_id: String=card.art.id
	await _click(panel.open_buttons[card.id]); await _capture("construction-wait")
	assert(panel.claim_button.disabled and panel.gift_hint.text.contains("Finish construction") and not card.claimed and _text(panel.body).contains("By Violet"))
	await _click(_named(app.menu_content,"Back to neighborhood")); await _click(app.game.mode_button); await _click(app.game.mail_button)
	panel=app.mail_panel; await _click(panel.inbox_button); await _click(panel.open_buttons[card.id]); await _capture("received")
	assert(panel.claim_button.get_global_rect().position.y>=panel.body.get_parent().get_global_rect().end.y and app.menu_panel.get_global_rect().encloses(panel.claim_button.get_global_rect()),"Collect stays visible without scrolling the postcard")
	assert(not panel.claim_button.disabled and panel.archive_button.disabled)
	await _click(panel.claim_button); await _capture("collected")
	assert(card.claimed and session.state.lots.lot_1.artworks[art_id].picture==gift_picture and panel.pending.is_empty() and not panel.archive_button.disabled)
	await _click(panel.arrange_button); await _capture("ready-to-hang")
	assert(app.page=="game" and app.game.selected_tool=="wall_art" and app.game._art_source=="art:"+art_id)
	await _mouse(_wall_point(),true); await _click(app.game.mode_button); await _capture("hung")
	assert(session.state.lots.lot_1.artworks[art_id].x==8)
	# Exact replies and accepted state both gate a pending onward gift.
	await _click(app.game.mail_button); panel=app.mail_panel; await _click(panel.write_button)
	panel.recipient="sam"; panel._refresh_recipients(); _note(panel,"Passing along a little harbor."); _choose_art(panel,"art:"+art_id)
	var intent: Dictionary={"type":"mail_send","recipient":"sam","note":panel.draft,"gift":0,"sequence":session.state.families[session.profile_id].mailbox.next_sent,"art_source":panel.art_source,"art_id":panel.art_id,"revision":session.state.lots.lot_1.revision}
	panel.pending=intent.duplicate(true); panel._acknowledged=false; panel._update_controls()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated")
	assert(not panel.pending.is_empty() and panel.send_button.disabled)
	session.command_completed.emit(intent,false,"The picture changed")
	assert(panel.pending.is_empty() and panel.art_source=="art:"+art_id and not panel.send_button.disabled)
	panel.pending=intent.duplicate(true); panel._acknowledged=false; panel._update_controls()
	session.command_completed.emit(intent,true,"Delivered")
	assert(not panel.pending.is_empty() and session.state.lots.lot_1.artworks.has(art_id))
	assert(session.world.apply_command(session.profile_id,intent).ok); panel.refresh()
	assert(panel.pending.is_empty() and not session.state.lots.lot_1.artworks.has(art_id) and session.state.families.sam.mailbox.items[0].art.picture==gift_picture)
	var saved: Dictionary=session.world.snapshot_for_save(); assert(session.world.restore(JSON.parse_string(JSON.stringify(saved))))
	print("ART_GIFTS_UI_PASS"); await root.get_node("Soundscape").shutdown_and_wait(); quit()
