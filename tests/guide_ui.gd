extends SceneTree
var app: Control
var session: Node
var prefs: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _point(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true); await process_frame

func _click(control: Control) -> void:
	await process_frame
	var parent := control.get_parent()
	var scrolls: Array[ScrollContainer]=[]
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(control); scrolls.append(parent)
		parent=parent.get_parent()
	await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()),"Guide actions remain on screen")
	for scroll: ScrollContainer in scrolls: assert(scroll.get_global_rect().encloses(control.get_global_rect()),"Guide action must be visible inside its scrolling page")
	await _point(control.get_global_rect().get_center())

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _find(text: String) -> Button:
	for button: Button in app.menu_content.find_children("*","Button",true,false):
		if (button.text==text or button.accessibility_name==text) and button.is_visible_in_tree(): return button
	assert(false,"Missing guide/menu control: "+text); return null

func _tab(index: int) -> void:
	await process_frame
	var bar: TabBar=app.guide_panel.tabs.get_tab_bar()
	await _point(bar.get_global_position()+bar.get_tab_rect(index).get_center())
	assert(app.guide_panel.tabs.current_tab==index)

func _action(id: String, tab: int=0) -> void:
	await _tab(tab)
	await _click(app.guide_panel.action_buttons[id][0])

func _capture(name: String) -> void:
	await process_frame
	assert(root.get_visible_rect().encloses(app.menu_panel.get_global_rect()) or app.page=="game","Guide/menu must fit within the window")
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/guide-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	prefs=root.get_node("Preferences"); assert(prefs.reset_defaults())
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.debug_speed=0; session.saving_enabled=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app); await create_timer(0.9).timeout
	assert(app.page=="main","Help never interrupts startup or an existing save")
	await _capture("main")
	var before: Dictionary=session.world.snapshot()
	await _click(_find("Guide & controls"))
	assert(app.page=="guide" and session.menu_paused)
	await _capture("first-day")
	await _tab(1); await _capture("building")
	await _tab(2); await _capture("neighbors")
	await _tab(3); await _capture("controls")
	assert(session.world.state==before,"Reading help never alters the neighborhood")
	assert(app.guide_panel.binding_values.rotate.text=="R")
	assert("backtick" in app.guide_panel.binding_values.console.text and "F1" in app.guide_panel.binding_values.console.text)
	assert(prefs.bind_action("play_pause",KEY_O).ok)
	assert(prefs.bind_action("console",KEY_F2).ok and prefs.bind_action("pause",KEY_P).ok)
	assert(app.guide_panel.binding_values.console.text=="F2 / F1" and app.guide_panel.binding_values.pause.text=="P / Escape","Live binding refresh includes the always-available rescue keys")
	await _click(app.guide_panel.action_buttons.bindings[0])
	assert(app.page=="settings" and app.previous_page=="guide")
	await _click(app.binding_buttons.rotate); await _key(KEY_T)
	await _click(_find("Back"))
	assert(app.page=="guide" and app.guide_panel.tabs.current_tab==3 and app.guide_panel.binding_values.rotate.text=="T","Guide returns to Controls and reflects rebound keys")
	await _capture("rebound")
	await _key(KEY_ESCAPE)
	assert(app.page=="main","Guide returns to the menu that opened it")
	await _click(_find("New neighborhood"))
	assert(_find("Show the first-day guide").button_pressed)
	await _click(_find("Create neighborhood"))
	assert(app.page=="guide" and app._guide_welcome and session.menu_paused,"New neighborhood can open the optional welcome guide")
	await _capture("welcome")
	await _click(_find("Start your day")); assert(app.page=="game" and not session.menu_paused)
	# Every family link enters its real UI; no simulated completions or rewards.
	app.open_pause(); await _click(_find("Guide & controls")); await _action("household")
	assert(app.page=="household"); await _key(KEY_ESCAPE); assert(app.page=="game")
	for id: String in ["care","wishes","hobbies"]:
		app.open_guide(); await _action(id)
		assert(app.page=="game" and app.game.context_panel.visible and app.game._context_page==id,"Guide link "+id+" should open its tray: "+app.page+" / "+app.game._context_page)
		app.game.context_panel.hide()
	session.world.ensure_family("guide_neighbor","Violet")
	app.game.viewed_lot="lot_2"; app.game._refresh()
	app.open_guide(); await _action("build")
	var home: String=session.home_lot()
	assert(app.page=="game" and session.state.lots[home].building and app.game.selected_tool=="room")
	assert(app.game.viewed_lot==home and not session.state.lots.lot_2.building,"Guide construction targets the player's own home, even while viewing a neighbor")
	app.open_pause(); app.open_guide(); await _capture("construction")
	for id: String in ["care","wishes","hobbies","people"]: assert(app.guide_panel.action_buttons[id][0].disabled)
	before=session.world.snapshot(); app._guide_action("care")
	assert(app.page=="guide" and session.world.state==before,"Blocked guide links cannot direct a frozen family")
	await _tab(1)
	before=session.world.snapshot()
	for label: Label in app.guide_panel.find_children("*","Label",true,false):
		if label.text=="Your first upstairs · checklist":
			app.guide_panel.tabs.get_child(1).ensure_control_visible(label)
			await _capture("upstairs-checklist")
	assert(session.world.snapshot()==before,"Reading the upstairs checklist never purchases or edits")
	await _action("move",1)
	assert(app.page=="game" and session.state.lots[home].building and app.game.selected_tool=="move","Build links preserve an existing draft instead of toggling it off")
	app.open_guide(); await _action("decorate",1)
	assert(app.page=="game" and app.game._catalog_category=="finishes" and app.game.catalog_buttons.has("finish_floor"))
	app.open_guide(); await _action("catalog",1)
	assert(app.page=="game" and app.game._catalog_category=="all")
	app.open_guide(); await _action("garden")
	assert(app.page=="game" and session.state.lots[home].building and app.game.selected_tool=="garden_bed")
	app.game._send({"type":"build_cancel","lot_id":home})
	app.open_guide(); await _action("people",2)
	assert(app.page=="game" and app.game._context_page=="people")
	app.open_guide(); await _action("mail",2)
	assert(app.page=="mail"); await _key(KEY_ESCAPE)
	app.open_guide(); await _action("save",1)
	assert(app.page=="save"); app.show_game()
	app.open_guide(); await _action("connect",2)
	assert(app.page=="game" and app.game.connection_dialog.visible and session.role=="offline","Play together opens connection choices without starting a host or joining anyone")
	app.game.connection_dialog.hide()
	app.open_guide(); before=session.world.snapshot()
	app._guide_action("unknown"); assert(app.page=="guide" and session.world.state==before)
	# Exercise the session's existing shared-clock policy with the guide open.
	session.debug_speed=1; session.role="host"
	var tick: int=session.state.tick
	session._physics_process(0.2)
	assert(session.state.tick>tick and session.menu_paused,"A host keeps simulating while reading help")
	session.debug_speed=0; session.role="client"; app._refresh_guide_context()
	assert(app.guide_panel.action_buttons.save[0].disabled)
	app._guide_action("save"); assert(app.page=="guide","A guest cannot open a host-only save through help")
	session.role="joining"; app._refresh_guide_context()
	assert(app.guide_panel.action_buttons.build[0].disabled)
	session.role="offline"; app._refresh_guide_context()
	app.show_main(); app._new_game_menu()
	await _click(_find("Show the first-day guide")); assert(not _find("Show the first-day guide").button_pressed)
	await _click(_find("Create neighborhood"))
	assert(app.page=="game" and not prefs.values.first_day_guide,"Opting out starts directly in the world")
	prefs.load_and_apply(); assert(not prefs.values.first_day_guide,"Guide preference survives reload")
	app.show_main(); await _click(_find("Guide & controls")); assert(app.page=="guide","Dismissed help remains available")
	await _key(KEY_ESCAPE); assert(app.page=="main")
	assert(prefs.reset_defaults())
	print("GUIDE_UI_PASS")
	await session.quit_application()
