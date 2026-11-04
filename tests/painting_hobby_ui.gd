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
	if node is Button and node.text==title: return node
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
	assert(root.get_texture().get_image().save_png("res://build/painting-hobby-"+name+suffix+".png")==OK)

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
	var alex: Dictionary=session.state.families[session.profile_id].members[0]
	var robin: Dictionary=session.state.families[session.profile_id].members[1]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	game._open_hobbies("painting"); await _capture("needs-easel")
	assert(game.hobby_buttons.painting.disabled and game.hobby_buttons.painting.text=="Easel needed")
	await _button(game.mode_button); await _button(game.catalog_buttons.easel); await _tile(9,9,true)
	var lot: Dictionary=session.state.lots.lot_1; var easel: Dictionary=lot.objects[-1]; var id: String=easel.id
	await _button(game.mode_button); await _button(game.hobbies_button)
	var before: Dictionary=session.world.snapshot()
	await _button(game.hobby_buttons.painting); await _capture("choose-subject")
	assert(game._context_page=="painting" and session.world.snapshot()==before and game.painting_panel.hobby_button.text.contains("Rank 1"))
	await _button(game.painting_panel.buttons.meadow); await _advance(8)
	await _button(_named(game,"Cancel actions"))
	assert(float(easel.painting.progress)>=4 and alex.hobbies.painting.sessions==0)
	await _capture("contribution")
	assert(game.painting_panel.practice.visible and game.painting_panel.practice.text.contains("Finish this canvas"))
	await _button(_named(game,"○  Robin"))
	await _button(game.hobbies_button); await _button(game.hobby_buttons.painting)
	assert(game.painting_panel.buttons.resume.visible)
	await _button(game.painting_panel.buttons.resume); await _advance(28); await _capture("shared-finished")
	assert(alex.hobbies.painting.sessions==1 and robin.hobbies.painting.sessions==1)
	await _button(game.painting_panel.hobby_button); await _capture("shared-progress")
	assert(game._context_page=="hobbies")
	var tray: Rect2=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.hobby_buttons.painting.get_global_rect()),"Opening progress at the easel must reveal the painting action")
	before=session.world.snapshot(); await _button(game.hobby_buttons.painting)
	assert(session.world.snapshot()==before and game.painting_panel.hang_button.visible)
	# A second finished painting reaches the first lasting milestone.
	await _button(game.painting_panel.buttons.sell); await _advance(10)
	await _button(game.painting_panel.buttons.harbor); await _advance(30)
	assert(robin.hobbies.painting.sessions==2 and game.painting_panel.hobby_button.text.contains("Rank 2"))
	await _button(game.painting_panel.hobby_button); await _capture("rank-two")
	assert(robin.wishes.journal.any(func(entry): return entry.text.contains("Color explorer")))
	assert(game.hobby_buttons.painting.text=="See your finished painting")
	# A camera on another lot still opens the selected resident's own easel.
	session.world.ensure_family("violet","Violet"); game._select_lot("lot_2")
	await _button(game.hobbies_button); before=session.world.snapshot()
	await _button(game.hobby_buttons.painting); await _capture("own-easel")
	assert(game.viewed_lot=="lot_1" and game._selected_object==id and session.world.snapshot()==before)
	assert(session.world.apply_command(session.profile_id,{"type":"visit","member_id":robin.id,"lot_id":"lot_2"}).ok)
	game._refresh(); await _button(game.hobbies_button); game._focus_hobby("painting"); await _capture("visitor")
	assert(game.hobby_buttons.painting.disabled and game.hobby_buttons.painting.text=="At your own home")
	# Restored progress appears immediately and stays associated with its resident.
	var saved: Dictionary=session.world.snapshot(); assert(session.world.restore(saved,true)); game._refresh()
	assert(session.state.families[session.profile_id].members[0].hobbies.painting.sessions==1 and session.state.families[session.profile_id].members[1].hobbies.painting.sessions==2)
	print("PAINTING_HOBBY_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
