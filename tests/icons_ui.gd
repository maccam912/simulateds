extends SceneTree
## Exercise language-light navigation through real input and preserve world authority.
const Icons = preload("res://game/ui_icons.gd")
var app: Control
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _click(button: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(button)
	await process_frame; await process_frame
	assert(button.is_visible_in_tree() and not button.disabled)
	assert(root.get_visible_rect().encloses(button.get_global_rect()),button.accessibility_name+" must fit")
	var point := button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _capture(name: String) -> void:
	await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/icons-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	suffix="-compact" if compact else ""
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("first_day_guide",false)
	if compact: prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for id: String in Icons.PATHS: assert(Icons.texture(id)!=null)
	for id: String in preload("res://game/build_catalog.gd").ORDER+preload("res://game/build_catalog.gd").CATEGORIES.keys():
		assert(Icons.has_icon(id),"Catalog entries and categories should have a recognizable pictogram: "+id)
	assert(Icons.texture("future_catalog_item")!=null,"New entries remain usable before bespoke art is added")
	session.saving_enabled=true
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout; game=app.game; session.saving_enabled=false
	for button: Button in app.menu_content.find_children("*","Button",true,false):
		assert(button.icon!=null and button.text.is_empty() and not button.accessibility_name.is_empty())
		assert(root.get_visible_rect().encloses(button.get_global_rect()))
	assert(root.gui_get_focus_owner() is Button and root.gui_get_focus_owner().accessibility_name=="Continue","Menus focus their primary icon")
	await _capture("main")
	app.show_game(); session.menu_paused=true; await process_frame
	var before: Dictionary=session.world.snapshot()
	var nav := [game.mode_button,game.palette_button,game.more_button,game.needs_toggle,game.queue_label,game.neighborhood_button]
	for button: Button in nav:
		assert(button.icon!=null and not button.accessibility_name.is_empty(),"Navigation needs an icon and accessible name: "+button.text)
		assert(button.size.x>=44 and button.size.y>=44,"Icon controls retain touch targets")
	await _capture("day")
	await _click(game.more_button)
	for button: Button in [game.mail_button,game.people_button,game.household_button,game.wishes_button,game.hobbies_button,game.visit_button,game.home_button,game.together_button]:
		assert(button.icon!=null and not button.accessibility_name.is_empty(),"Navigation needs an icon and accessible name: "+button.text)
		assert(game.more_panel.get_global_rect().encloses(button.get_global_rect()))
	game.mail_button.grab_focus(); game._refresh()
	assert(not game.help_label.text.is_empty(),"Keyboard focus reveals the explanation")
	await _capture("more")
	game.more_panel.hide()
	await _click(game.needs_toggle)
	for button: Button in game.need_buttons.values(): assert(not button.accessibility_name.is_empty())
	await _capture("needs")
	await _click(game.needs_toggle)
	assert(session.world.snapshot()==before,"Reading icons, needs and menus sends no world commands")
	await _click(game.mode_button)
	assert(session.state.lots.lot_1.building and game.mode_button.get_meta("icon_id")=="check")
	assert(game.palette_button.get_meta("icon_id")=="catalog" and game.palette_button.text.is_empty())
	for button: Button in game.catalog_buttons.values():
		assert(button.icon!=null or (button.has_node("Picture") and button.get_node("Picture").texture!=null),"Catalog choices retain a pictogram or model thumbnail")
	await _capture("catalog")
	await _click(game.catalog_category)
	assert(game.catalog_category.get_popup().visible)
	await _capture("categories")
	game.catalog_category.get_popup().hide()
	game.context_panel.hide(); await _click(game.palette_button)
	assert(game.context_panel.visible,"The book icon reopens the catalog directly from the dock")
	game.palette_button.grab_focus()
	for pressed: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=KEY_SPACE; event.pressed=pressed
		root.push_input(event,true); await process_frame
	assert(not game.context_panel.visible,"Keyboard activation toggles the catalog")
	await _click(game.mode_button)
	assert(not session.state.lots.lot_1.building and game.mode_button.get_meta("icon_id")=="build")
	session.state.day_minutes=1320.0; game._refresh(); get_root().gui_release_focus()
	await _capture("night")
	app.open_pause(); await _capture("pause")
	print("ICONS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
