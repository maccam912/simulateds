extends SceneTree
const Browse = preload("res://game/build_catalog.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _key(code: int, character: int=0, ctrl: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.unicode=character; event.pressed=pressed; event.ctrl_pressed=ctrl
		root.push_input(event,true); await process_frame

func _type(value: String) -> void:
	for character: String in value: await _key(character.to_upper().unicode_at(0),character.unicode_at(0))

func _mouse(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true); await process_frame

func _click(control: Control) -> void:
	await process_frame
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control); await process_frame
	var rect := control.get_global_rect()
	assert(root.get_visible_rect().encloses(rect),"Catalog control must be on screen")
	if game.tools_box.is_ancestor_of(control): assert(game.tools_box.get_parent().get_global_rect().encloses(rect),"Item must fit within the catalog scroll area")
	await _mouse(rect.get_center())

func _capture(name: String) -> void:
	game._refresh(); await process_frame
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/catalog-"+name+suffix+".png")==OK)

func _filter(category: String) -> void:
	# PopupMenu consumes native window input before Viewport.push_input. Exercise
	# the selection callback here; the native mouse/keyboard playtest covers its menu.
	game.catalog_category.select(Browse.CATEGORIES.keys().find(category))
	game.catalog_category.item_selected.emit(game.catalog_category.selected)
	await process_frame

func _search(value: String) -> void:
	await _key(KEY_F,0,true)
	assert(game.catalog_search.has_focus() and game.context_panel.visible)
	await _type(value)
	assert(game.catalog_search.text==value,"Typing retains the search field and caret")

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact: suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame
	var lot: Dictionary=session.state.lots.lot_1
	var ground_clicks: Array=[]; game.lot_view.tile_clicked.connect(func(cell): ground_clicks.append(cell))
	await _click(game.mode_button)
	assert(lot.building and game.catalog_filters.visible and game.catalog_buttons.size()==Browse.ORDER.size())
	for kind: String in preload("res://game/catalog.gd").ITEMS: assert(game.catalog_buttons.has(kind),"Every available furnishing must be discoverable in the catalog")
	await _capture("browse")
	var untouched: Dictionary=session.world.snapshot()
	var field_id: int=game.catalog_search.get_instance_id()
	await _search("bed")
	assert(game.catalog_buttons.keys()==["bed","garden_bed","furniture_color"] and lot.building and game.build_rotation==0,"Beds and bedding colors are discoverable without search typing changing modes or rotation")
	for index in range(5): game._refresh(); await process_frame
	assert(game.catalog_search.has_focus() and game.catalog_search.get_instance_id()==field_id)
	assert(session.world.state==untouched and ground_clicks.is_empty(),"Browsing and typing cannot purchase or click through into the house")
	await _capture("search")
	await _key(KEY_ENTER)
	assert(game.selected_tool=="bed" and not game.catalog_search.has_focus())
	await _key(KEY_R)
	assert(game.build_rotation==1 and "2×1" in game.context_box.get_child(1).text,"Rotation works after selecting an item and updates its footprint")
	await _search("zzzzzz")
	assert(game.catalog_buttons.is_empty())
	await _capture("empty")
	await _click(game.tools_box.get_child(1))
	assert(game.catalog_buttons.size()==Browse.ORDER.size() and game.catalog_search.text.is_empty() and game.selected_tool=="bed","Show everything clears filters while retaining the chosen tool")
	await _filter("kitchen")
	assert(game.catalog_buttons.keys()==["fridge","dining_table"],"Kitchen includes individual food and the shared-meal table")
	await _search("read")
	assert(game.catalog_buttons.is_empty(),"Search is scoped to the chosen category")
	await _filter("living")
	assert(game.catalog_buttons.keys()==["bookshelf"] and game.catalog_search.text=="read")
	await _capture("category")
	await _click(game.catalog_search)
	await _key(KEY_ESCAPE)
	assert(game.catalog_search.text.is_empty() and game.context_panel.visible and game.catalog_search.has_focus(),"Escape first clears a focused search")
	await _key(KEY_ESCAPE)
	assert(not game.catalog_search.has_focus() and not game.context_panel.visible,"Escape from an empty search closes the catalog")
	await _key(KEY_F,0,true)
	assert(game.context_panel.visible and game.catalog_search.has_focus())
	await _filter("all"); game.catalog_search.release_focus()
	# Furnish a usable addition through the actual catalog and world controls.
	await _click(game.catalog_buttons.room)
	game.build_rotation=2; game._refresh(); await process_frame
	await _mouse(game.lot_view.grid_point(3.5,11.5)); await _mouse(game.lot_view.grid_point(7.5,15.5))
	assert(lot.doors.has([5,11]) and lot.floors.has([5,13]))
	var room_funds: int=lot.funds
	game.build_rotation=0
	for item: Array in [["sleep","bed",4,12,450],["book","bookshelf",6,12,160],["garden","plant",6,14,45]]:
		await _search(str(item[0]))
		assert(game.catalog_buttons.has(item[1]))
		await _key(KEY_ENTER)
		assert(game.selected_tool==item[1])
		var funds: int=lot.funds
		await _mouse(game.lot_view.grid_point(float(item[2])+0.5,float(item[3])+0.5))
		assert(lot.funds==funds-int(item[4]) and session.world._object_at(lot,Vector2i(int(item[2]),int(item[3]))).kind==item[1])
	assert(lot.funds==room_funds-655)
	await _capture("furnished")
	await _click(game.undo_button)
	assert(lot.funds==room_funds-610 and session.world._object_at(lot,Vector2i(6,14)).is_empty())
	await _click(game.redo_button)
	assert(lot.funds==room_funds-655)
	var actual_funds: int=lot.funds; lot.funds=100
	await _search("bed"); await _key(KEY_ENTER)
	assert("Need §350 more" in game.context_box.get_child(1).text and "Over budget" in game.catalog_buttons.bed.tooltip_text)
	await _capture("budget")
	lot.funds=actual_funds; game._refresh()
	game._clear_catalog_filters(); await process_frame
	await _click(game.catalog_buttons.finish_floor)
	assert(not game.catalog_filters.visible and game.finish_buttons.size()==6)
	await _capture("finishes")
	await _key(KEY_F,0,true)
	assert(game.catalog_filters.visible and game.catalog_search.has_focus(),"Find returns from the paint palette to the item catalog")
	game.catalog_search.release_focus(); await _click(game.mode_button)
	assert(not lot.building and not game.catalog_filters.visible,"Furnished room remains usable when construction ends")
	await _capture("live")
	print("CATALOG_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
