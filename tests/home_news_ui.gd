extends SceneTree
var session: Node
var app: Control
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _click(control: Control) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(control)
	await process_frame; await process_frame
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			await process_frame; await process_frame
			assert(parent.get_global_rect().encloses(control.get_global_rect()),"Clicked control fits inside its scrolling viewport")
		parent=parent.get_parent()
	var position := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=position
		root.push_input(event,true); await process_frame

func _capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/home-news-"+name+suffix+".png")==OK)

func _text(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label else ""
	for child in node.get_children(): result+=_text(child)
	return result

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact: suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.world.initialize()
	session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	session.world.ensure_family("neighbor","Violet"); session.world.ensure_family("friend","Sam")
	var family: Dictionary=session.state.families[session.profile_id]
	assert(session.world.apply_command(session.profile_id,{"type":"build_begin","lot_id":family.home_lot}).ok)
	assert(session.world.apply_command(session.profile_id,{"type":"place","lot_id":family.home_lot,"kind":"floor","x":0,"y":0}).ok)
	session.world.set_online(session.profile_id,false)
	session.state.day_minutes=1439.0
	for tick in range(60): session.world.step(1.0)
	for neighbor: String in ["neighbor","friend"]:
		assert(session.world.apply_command(neighbor,{"type":"mail_send","recipient":session.profile_id,"sequence":1,"note":"Welcome home. The garden missed you!","gift":250 if neighbor=="neighbor" else 100}).ok)
	session.world.set_online(session.profile_id,true)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout
	assert(app.page=="main","A pending recap never forces a startup popup")
	app.show_game(); session.menu_paused=true
	assert(app.page=="game" and family.home_news.report.pending and app.game.mail_button.text.ends_with("2"))
	assert("Home news" in app.game.mail_button.tooltip_text)
	await _capture("badge")
	await _click(app.game.mail_button)
	assert(app.page=="mail" and app.mail_panel.view=="news" and family.home_news.report.pending,"Opening Mail shows pending news without marking it read")
	var panel: Control=app.mail_panel
	var text := _text(panel.body)
	assert("3 hours of neighborhood time" in text and "§600 allowance received" in text)
	assert("2 postcards delivered" in text and "§350 in gifts" in text and "building draft was discarded" in text)
	assert("2 unread postcards · §350 uncollected gifts" in text)
	await process_frame; await process_frame
	assert(app.menu_panel.get_global_rect().encloses(panel.news_read_button.get_global_rect()),"The recap action stays visible without scrolling")
	await _capture("recap")
	var funds: int=session.state.lots[family.home_lot].funds
	await _click(panel.news_read_button)
	assert(not family.home_news.report.pending and panel.pending.is_empty() and session.state.lots[family.home_lot].funds==funds)
	assert(family.mailbox.items.all(func(entry): return not entry.read and not entry.claimed),"Reading news does not open postcards or collect gifts")
	assert(panel.news_read_button.disabled and "already read" in _text(panel.body))
	await _capture("read")
	await _click(panel.news_inbox_button)
	assert(panel.view=="inbox" and panel.open_buttons.size()==2)
	var card_id: String=family.mailbox.items[0].id
	await _click(panel.open_buttons[card_id]); await _click(panel.claim_button)
	assert(session.state.lots[family.home_lot].funds==funds+100)
	await _click(panel.news_button)
	assert("1 unread postcard · §250 uncollected gifts" in _text(panel.body) and "§350 in gifts" in _text(panel.body),"Current waiting gifts update while the historical recap stays accurate")
	var event := InputEventKey.new(); event.keycode=KEY_ESCAPE; event.physical_keycode=KEY_ESCAPE; event.pressed=true
	root.push_input(event,true); await process_frame
	assert(app.page=="game","Escape leaves the recap without opening pause")
	session.menu_paused=true
	# Quiet absence, no mail: the existing Mail control carries the news badge.
	session.world.set_online(session.profile_id,false)
	for tick in range(10): session.world.step(1.0)
	session.world.set_online(session.profile_id,true)
	for entry: Dictionary in family.mailbox.items: entry.read=true
	app.game._refresh()
	assert(app.game.mail_button.text.ends_with("•"))
	await _capture("quiet-badge")
	session.command({"type":"build_begin","lot_id":family.home_lot})
	app.game._refresh()
	assert(app.page=="game" and session.state.lots[family.home_lot].building,"Pending news never interrupts construction")
	await _click(app.game.mail_button)
	assert(app.mail_panel.view=="news")
	await _click(app.mail_panel.news_read_button)
	assert(session.state.lots[family.home_lot].building,"Reading news preserves the building draft")
	var replica := preload("res://game/world.gd").new()
	assert(replica.restore(JSON.parse_string(FileAccess.get_file_as_string(session.save_path))))
	assert(not replica.state.families[session.profile_id].home_news.report.pending,"Read state is immediately durable")
	print("HOME_NEWS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
