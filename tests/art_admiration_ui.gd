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
	await preload("res://tests/hud_navigation.gd").reveal(control)
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
	assert(root.get_texture().get_image().save_png("res://build/art-admiration-"+name+suffix+".png")==OK)

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

func _mount(owner: String,subject: String) -> String:
	var lot: Dictionary=session.state.lots[session.state.families[owner].home_lot]
	var resident: Dictionary=session.state.families[owner].members[0]
	assert(session.world.apply_command(owner,{"type":"build_begin","lot_id":lot.id}).ok)
	assert(session.world.apply_command(owner,{"type":"place","lot_id":lot.id,"kind":"easel","x":9,"y":9}).ok)
	assert(session.world.apply_command(owner,{"type":"build_end","lot_id":lot.id}).ok)
	var easel: Dictionary=lot.objects[-1]
	assert(session.world.apply_command(owner,{"type":"painting","lot_id":lot.id,"member_id":resident.id,"target_id":easel.id,"action":"start","subject":subject,"revision":0}).ok)
	for tick in range(350): session.world.step(0.1)
	assert(session.world.apply_command(owner,{"type":"build_begin","lot_id":lot.id}).ok)
	assert(session.world.apply_command(owner,{"type":"art_hang","lot_id":lot.id,"source":"easel:"+str(easel.id),"x":8,"y":3,"revision":lot.revision}).ok)
	assert(session.world.apply_command(owner,{"type":"build_end","lot_id":lot.id}).ok)
	return str(lot.artworks.keys()[0])

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=false; session.set_physics_process(false)
	session.world.initialize()
	for owner: String in [session.profile_id,"violet"]:
		session.world.ensure_family(owner,"Alex" if owner==session.profile_id else "Violet"); session.world.set_online(owner,true)
		for resident: Dictionary in session.state.families[owner].members: resident.autonomy=false
	var own_id := _mount(session.profile_id,"harbor"); var neighbor_id := _mount("violet","flowers")
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	member.needs.fun=30; member.needs.comfort=30
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	await _mouse(_wall_point(8,3),true); await _capture("inspect")
	assert(game._context_page=="wall_art_inspect" and not game.wall_art_panel.admire_button.disabled)
	var tray: Rect2=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.wall_art_panel.admire_button.get_global_rect()) and tray.encloses(game.wall_art_panel.admire_hint.get_global_rect()) and tray.encloses(game.wall_art_panel.arrange_button.get_global_rect()),"Both actions and benefit stay visible at the compact layout")
	# A result for another command cannot clear this resident's pending request.
	var panel: Control=game.wall_art_panel
	var intent := {"type":"admire_art","lot_id":"lot_1","member_id":member.id,"target_id":own_id,"x":8,"y":3}
	panel.admire_pending=intent.duplicate(true); panel._admire_next=int(member.next_action); game._refresh()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated")
	assert(not panel.admire_pending.is_empty() and panel.admire_button.disabled)
	session.command_completed.emit(intent,true,"Accepted before snapshot")
	assert(not panel.admire_pending.is_empty() and member.task.is_empty())
	session.command_completed.emit(intent,false,"The picture changed")
	assert(panel.admire_pending.is_empty() and panel.admire_hint.text=="The picture changed")
	await _button(panel.admire_button); await _button(game.queue_label)
	assert(member.task.target_kind=="art" and member.task.target_id==own_id and panel.admire_pending.is_empty())
	for tick in range(100):
		session.world.step(0.1)
		if float(member.task.get("elapsed",0))>0: break
	game._refresh(); await _capture("enjoying")
	assert(game._plan_detail.text.contains("Fun + comfort") and game.lot_view._activity_pose(member).kind=="admire_art")
	assert(panel.admire_button.disabled and panel.admire_hint.text.contains("plan"))
	await _advance(7); assert(member.activity_log[0].outcome=="done" and member.needs.fun>50)
	await _button(game.recent_button); await _capture("recent")
	assert(member.activity_log[0].title.contains("Quiet harbor"))
	# The same action becomes available after a real visit; ownership controls stay local.
	game.plan_panel.hide(); game._select_lot("lot_2"); await process_frame; await process_frame
	await _mouse(_wall_point(8,3),true); await _capture("visit-first")
	assert(game.wall_art_panel.admire_button.disabled and game.wall_art_panel.admire_hint.text.contains("Visit"))
	assert(not game.wall_art_panel.arrange_button.visible)
	await _button(game.visit_button); await _mouse(_wall_point(8,3),true)
	assert(member.lot_id=="lot_2" and not game.wall_art_panel.admire_button.disabled)
	await _button(game.wall_art_panel.admire_button); await _advance(4); await _capture("visiting")
	assert(member.task.get("target_id")==neighbor_id)
	assert(session.world.apply_command("violet",{"type":"build_begin","lot_id":"lot_2"}).ok)
	game._refresh(); await process_frame; await _capture("construction")
	assert(member.lot_id=="lot_1" and member.task.is_empty() and member.activity_log[0].outcome=="cancelled")
	assert(session.world.apply_command("violet",{"type":"build_end","lot_id":"lot_2"}).ok)
	# A furnishing in front of the visible face gives a useful disabled explanation.
	game._select_lot("lot_1"); await process_frame; await process_frame
	var lot: Dictionary=session.state.lots.lot_1
	await _mouse(_wall_point(8,3),true)
	lot.objects.append(session.world._new_object("plant",8,4,0))
	game._refresh(); await _capture("blocked")
	assert(game.wall_art_panel.admire_button.disabled and game.wall_art_panel.admire_hint.text.contains("clear space"))
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait()
	print("ART_ADMIRATION_UI_PASS"); quit()
