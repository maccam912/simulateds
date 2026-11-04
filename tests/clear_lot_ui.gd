extends SceneTree
const Clear = preload("res://game/clear_lot.gd")
const Finishes = preload("res://game/finishes.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame

func _button(control: Button) -> void:
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(control): game.tools_box.get_parent().ensure_control_visible(control)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var pressed := [false]; control.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(control.get_global_rect().get_center(),true); assert(pressed[0])

func _tile(x: int,y: int,click: bool=true) -> void:
	await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await process_frame; await process_frame

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/clear-lot-"+name+suffix+".png")==OK)

func _command(intent: Dictionary) -> void:
	intent.lot_id="lot_1"; intent.revision=session.state.lots.lot_1.revision
	var result: Dictionary=session.world.apply_command(session.profile_id,intent)
	assert(result.ok,result.message)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	var lot: Dictionary=session.state.lots.lot_1
	for index in range(2):
		session.state.families[session.profile_id].members[index].x=2; session.state.families[session.profile_id].members[index].y=12+index
	_command({"type":"build_begin"})
	_command({"type":"blueprint_save","source_x":7,"source_y":7,"library_revision":0,"name":"Starter home"})
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _button(game.catalog_buttons.clear_lot)
	var panel: VBoxContainer=game.clear_panel
	assert(panel.plan.refund==2940 and not panel.confirm.disabled and not game.catalog_filters.visible)
	var before: Dictionary=session.world.snapshot()
	await _tile(0,0); await _tile(7,7); await _tile(4,4); await _capture("review")
	assert(session.world.snapshot()==before,"Review ground and furniture clicks cannot change the lot")
	await _button(panel.back); assert(session.world.snapshot()==before and game.catalog_filters.visible)
	await _button(game.catalog_buttons.clear_lot); panel=game.clear_panel
	_command({"type":"place","kind":"floor","x":0,"y":0}); game._refresh()
	assert(panel.review.visible and panel.confirm.disabled and panel.plan.refund==2940)
	await _button(panel.review); assert(panel.plan.refund==2947 and not panel.confirm.disabled)
	_command({"type":"build_undo"}); game._refresh(); await _button(panel.review)
	await _key(KEY_ESCAPE); assert(not game.context_panel.visible and game.selected_tool=="floor" and not Clear.empty(lot))
	game._show_tray(game.context_panel,true); await _button(game.catalog_buttons.clear_lot); panel=game.clear_panel
	# Only this exact acknowledgement releases the pending review, after a newer snapshot.
	var intent: Dictionary={"type":"clear_lot","lot_id":lot.id,"revision":lot.revision,"refund":2940}
	panel.pending=intent.duplicate(); game._refresh()
	assert(game.mode_button.disabled and game.undo_button.disabled and game.clear_discard_button.disabled)
	var unrelated:=intent.duplicate(); unrelated.refund=1
	panel._completed(unrelated,false,""); assert(not panel.pending.is_empty())
	await _key(KEY_ESCAPE); assert(game._context_page=="clear_lot" and game.context_panel.visible)
	panel._completed(intent,true,""); assert(not panel.pending.is_empty())
	panel._completed(intent,false,"Review again"); assert(panel.pending.is_empty()); panel._review(); game._refresh()
	await _button(panel.confirm); await _capture("cleared")
	assert(Clear.empty(lot) and lot.funds==14940 and panel.pending.is_empty() and panel.rebuild.visible)
	await _button(game.undo_button); assert(lot.objects.size()==10 and lot.funds==12000)
	await _button(game.redo_button); assert(Clear.empty(lot) and lot.funds==14940)
	await _button(game.clear_discard_button); assert(lot.objects.size()==10 and lot.funds==12000 and not lot.building)
	assert(session.state.families[session.profile_id].room_library.entries.size()==1)
	await _button(game.mode_button); game._select_build_tool("floor")
	_command({"type":"place","kind":"easel","x":9,"y":8})
	_command({"type":"place","kind":"dining_table","x":8,"y":6})
	_command({"type":"place","kind":"garden_bed","x":0,"y":0})
	var easel: Dictionary=lot.objects[-3]; var table: Dictionary=lot.objects[-2]; var garden: Dictionary=lot.objects[-1]
	easel.painting={"subject":"meadow","progress":8.0,"artists":[{"id":session.state.families[session.profile_id].members[0].id,"name":"Alex"}],"day":1,"revision":1}
	table.meal={"recipe":"salad","servings":3,"batch":2,"cook":session.state.families[session.profile_id].members[0].id,"cook_name":"Alex","day":1}
	garden.garden.crop="radish"; garden.garden.water=60.0; garden.garden.growth=30.0; garden.garden.revision=1
	game._select_build_tool("clear_lot"); panel=game.clear_panel
	assert(panel.confirm.disabled and panel.find.visible and panel.losses.text.contains("3 meal portions"),str([panel.plan,panel.confirm.disabled,panel.find.visible,panel.losses.text,game._context_page]))
	before=session.world.snapshot(); await _button(panel.find); await _capture("unfinished")
	assert(session.world.snapshot()==before)
	easel.painting.progress=24.0; easel.painting.revision=2; lot.revision+=1
	game._refresh(); assert(panel.review.visible and panel.confirm.disabled)
	await _button(panel.review); await _capture("contents")
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.losses.get_global_rect()),"The consumable warning fits with the quote, without scrolling")
	assert(panel.plan.paintings.size()==1 and panel.losses.visible and panel.keeps.text.contains("1 painting → collection") and panel.losses.text.contains("1 planted garden bed.") and not panel.confirm.disabled)
	var refund: int=panel.plan.refund; var funds: int=lot.funds
	await _button(panel.confirm)
	assert(Clear.empty(lot) and lot.funds==funds+refund and lot.artworks.size()==1)
	await _button(panel.rebuild.get_child(0)); assert(game._context_page=="blueprints")
	await _button(game.library_panel.buttons.room_1.place); game.lot_view.center_lot(); await process_frame; await process_frame
	await _tile(3,3,false); await _capture("rebuild-preview")
	assert(game.lot_view.copy_preview.ok,str(game.lot_view.copy_preview))
	await _tile(3,3); assert(lot.objects.size()==10 and lot.artworks.size()==1)
	await _button(game.mode_button); assert(not lot.building)
	var restored:=preload("res://game/world.gd").new(); assert(restored.restore(JSON.parse_string(JSON.stringify(session.world.snapshot_for_save()))))
	assert(restored.state.lots.lot_1.objects.size()==10 and restored.state.lots.lot_1.artworks.size()==1)
	await _capture("rebuilt")
	print("CLEAR_LOT_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
