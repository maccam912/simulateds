extends SceneTree
var game: Control
var session: Node
var suffix := ""
var heard: Array[String]=[]

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
	await process_frame; await process_frame
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
	assert(root.get_texture().get_image().save_png("res://build/wall-art-"+name+suffix+".png")==OK)

func _wall_point(x: int,y: int) -> Vector2:
	for region: Dictionary in game.lot_view._hit_regions:
		if not region.target.get("type") in ["wall","wall_art"] or region.target.get("x")!=x or region.target.get("y")!=y: continue
		var point := Vector2.ZERO
		for corner: Vector2 in region.polygon: point+=corner
		point/=region.polygon.size()
		var hit: Dictionary=game.lot_view.hit_target(point)
		if hit.get("x")==x and hit.get("y")==y and not game.lot_view.overlay_rects.any(func(rect): return rect.has_point(point)): return point
	assert(false,"The wall needs a visible picking surface"); return Vector2.ZERO

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
	for resident: Dictionary in session.state.families[session.profile_id].members: resident.autonomy=false
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.easel); await _tile(9,9,true)
	var lot: Dictionary=session.state.lots.lot_1; var easel: Dictionary=lot.objects[-1]; var easel_id: String=easel.id
	await _button(game.mode_button); await _mouse(_point(easel_id),true)
	assert(not game.painting_panel.hang_button.visible)
	await _button(game.painting_panel.buttons.harbor); await _advance(30); await _capture("finished")
	assert(game.painting_panel.hang_button.visible and not game.painting_panel.hang_button.disabled)
	var original: Dictionary=easel.painting.duplicate(true); var funds: int=lot.funds
	# Build entry waits for the accepted state, not an unrelated or early reply.
	var entry := {"type":"build_begin","lot_id":str(lot.id)}
	game._art_entry={"lot_id":str(lot.id),"source":"easel:"+easel_id}; game._refresh()
	assert(game.painting_panel.hang_button.disabled)
	session.command_completed.emit({"type":"cancel"},false,"Unrelated")
	assert(not game._art_entry.is_empty())
	session.command_completed.emit(entry,false,"Cannot enter yet")
	assert(game._art_entry.is_empty() and not game.painting_panel.hang_button.disabled)
	game._art_entry={"lot_id":str(lot.id),"source":"easel:"+easel_id}; game._refresh()
	session.command_completed.emit(entry,true,"Construction accepted")
	assert(not game._art_entry.is_empty() and not lot.building and game.painting_panel.hang_button.disabled)
	game._art_entry.clear(); game._refresh()
	await _button(game.painting_panel.hang_button); await _capture("choose-wall")
	assert(lot.building and game.selected_tool=="wall_art" and game._art_source=="easel:"+easel_id)
	var before: Dictionary=session.world.snapshot()
	await _mouse(_wall_point(8,3)); await _capture("preview")
	assert(game.lot_view.art_preview.ok and session.world.snapshot()==before and game.lot_view.preview_label_rect.has_area())
	await _mouse(_wall_point(5,3)); await _capture("window-blocked")
	assert(not game.lot_view.art_preview.ok and game.lot_view.art_preview.message.contains("window") and session.world.snapshot()==before)
	var hang := {"type":"art_hang","lot_id":str(lot.id),"source":"easel:"+easel_id,"x":8,"y":3,"revision":int(lot.revision)}
	var request := {"intent":hang.duplicate(true),"plan":preload("res://game/wall_art.gd").inspect(lot,hang)}
	game._art_request=request.duplicate(true); game._refresh()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated")
	assert(not game._art_request.is_empty() and game.wall_art_panel.picker.disabled)
	session.command_completed.emit(hang,false,"The draft changed")
	assert(game._art_request.is_empty() and not game.wall_art_panel.picker.disabled)
	game._art_request=request.duplicate(true); game._refresh()
	session.command_completed.emit(hang,true,"Accepted")
	assert(not game._art_request.is_empty() and lot.artworks.is_empty())
	# Another accepted edit may advance revision without applying this transfer.
	assert(session.world.apply_command(session.profile_id,{"type":"recolor","lot_id":lot.id,"object_id":easel_id,"style":"sage","revision":lot.revision}).ok)
	game._refresh(); assert(not game._art_request.is_empty())
	game._art_request.clear(); game._refresh()
	await _mouse(_wall_point(8,3),true); await _capture("hung")
	var id: String=lot.artworks.keys()[0]
	assert(lot.artworks[id].picture==original and easel.painting.subject=="" and lot.funds==funds and game._art_request.is_empty())
	var tray: Rect2=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.wall_art_panel.store_button.get_global_rect()) and tray.encloses(game.wall_art_panel.return_button.get_global_rect()),"Keep both collection actions visible without scrolling")
	await _button(game.undo_button); assert(lot.artworks.is_empty())
	easel=session.world._object(lot,easel_id); assert(easel.painting==original)
	await _button(game.redo_button); easel=session.world._object(lot,easel_id); assert(easel.painting.subject=="" and lot.artworks[id].picture==original)
	# Reselect through the actual source picker, then move to another wall.
	game.wall_art_panel.picker.select(1); game.wall_art_panel.picker.item_selected.emit(1); await process_frame; await process_frame
	await _mouse(_wall_point(3,8),true); await _capture("moved")
	assert(lot.artworks.size()==1 and lot.artworks[id].x==3 and lot.artworks[id].y==8)
	await _button(game.wall_art_panel.store_button); await _capture("stored")
	assert(lot.artworks[id].x==-1 and lot.artworks[id].picture==original)
	await _mouse(_wall_point(8,3),true)
	await _button(game.mode_button); await _capture("live")
	assert(not lot.building and game.lot_view.art_regions.has(id))
	await _mouse(_wall_point(8,3),true); await _capture("inspect")
	assert(game._context_page=="wall_art_inspect" and game.wall_art_panel.credit.text=="By Alex" and game.wall_art_panel.arrange_button.visible)
	await _button(game.wall_art_panel.arrange_button)
	# A window safely stores the original painting, and Undo rehangs it.
	await _button(_named(game.context_box,"‹ Catalog")); await _button(game.catalog_buttons.window)
	await _mouse(_wall_point(8,3)); await _capture("window-stores-art")
	assert(game.lot_view.preview_result.message.contains("collection"))
	await _mouse(_wall_point(8,3),true); assert(lot.artworks[id].x==-1 and lot.artworks[id].picture==original)
	await _button(game.undo_button); assert(lot.artworks[id].x==8)
	await _button(_named(game.tools_box,"‹ Catalog")); await _button(game.catalog_buttons.wall_art)
	game.wall_art_panel.picker.select(1); game.wall_art_panel.picker.item_selected.emit(1); await process_frame; await process_frame
	# Native front-wall placement remains visible when walls cut away in live play.
	await _mouse(_wall_point(9,11),true); await _button(game.mode_button); await _capture("cutaway")
	assert(game.lot_view.art_regions.has(id))
	await _mouse(_wall_point(9,11),true); await _button(game.wall_art_panel.arrange_button)
	await _button(game.wall_art_panel.return_button); await _capture("returned")
	easel=session.world._object(lot,easel_id)
	assert(lot.artworks.is_empty() and easel.painting.subject==original.subject and easel.painting.artists==original.artists)
	await _button(game.mode_button); await _mouse(_point(easel_id),true)
	assert(game.painting_panel.hang_button.visible)
	original=easel.painting.duplicate(true)
	await _button(game.painting_panel.hang_button); await _mouse(_wall_point(8,3),true); await _button(game.mode_button)
	id=lot.artworks.keys()[0]
	# Empty easel starts a new independent canvas while the first stays displayed.
	await _mouse(_point(easel_id),true); await _button(game.painting_panel.buttons.flowers); await _advance(30)
	assert(lot.artworks[id].picture==original and easel.painting.subject=="flowers")
	await _capture("new-canvas")
	var saved: Dictionary=session.world.snapshot(); assert(session.world.restore(saved,true)); game._refresh(); await process_frame; await process_frame
	assert(session.state.lots.lot_1.artworks[id].picture==original)
	# Neighbor inspection exposes the picture and credit without ownership controls.
	session.world.ensure_family("violet","Violet")
	var neighbor: Dictionary=session.state.lots.lot_2
	neighbor.artworks={id:{"picture":original.duplicate(true),"x":8,"y":3}}
	game._select_lot("lot_2"); await process_frame; await process_frame
	await _mouse(_wall_point(8,3),true); await _capture("visitor")
	assert(game.wall_art_panel.credit.text=="By Alex" and not game.wall_art_panel.arrange_button.visible and not game.wall_art_panel.picker.visible and not game.wall_art_panel.store_button.visible and not game.wall_art_panel.return_button.visible)
	before=session.world.snapshot(); game._open_art("art:"+id); assert(session.world.snapshot()==before and game._art_entry.is_empty())
	print("WALL_ART_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()

