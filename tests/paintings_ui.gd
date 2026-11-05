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
	# Pick a visible portion of the real model, not a guessed floor cell.
	game.lot_view.projection.register_targets()
	for pick: Dictionary in game.lot_view.projection.picks:
		if pick.target.get("id")!=id: continue
		var bounds := Rect2(pick.polygon[0],Vector2.ZERO)
		for point: Vector2 in pick.polygon: bounds=bounds.expand(point)
		for x in range(1,10):
			for y in range(1,10):
				var point := bounds.position+bounds.size*Vector2(float(x)/10.0,float(y)/10.0)
				if game.lot_view.hit_target(point).get("id")==id and game.lot_view._point_available(point): return point
	assert(false,"No exposed model surface for "+id)
	return Vector2.ZERO

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
	assert(root.get_texture().get_image().save_png("res://build/paintings-"+name+suffix+".png")==OK)

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
	root.get_node("Soundscape").world_sound_started.connect(func(sound: String,_point: Vector2): heard.append(sound))
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for resident: Dictionary in session.state.families[session.profile_id].members: resident.autonomy=false
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.easel)
	await _tile(9,9); await _capture("placement"); assert(game.lot_view.preview_result.ok and game.lot_view.placement_impact.ok)
	await _tile(9,9,true)
	var lot: Dictionary=session.state.lots.lot_1; var easel: Dictionary=lot.objects[-1]; var id: String=easel.id
	assert(easel.kind=="easel" and easel.painting.subject=="")
	await _button(game.mode_button); await _mouse(_point(id),true); await _capture("blank")
	assert(game._context_page=="painting" and game.painting_panel.buttons.meadow.visible)
	var tray: Rect2=game.tools_box.get_parent().get_global_rect()
	assert(tray.encloses(game.painting_panel.summary.get_global_rect()))
	for key: String in ["meadow","harbor","flowers"]: assert(tray.encloses(game.painting_panel.buttons[key].get_global_rect()),"All subjects should be visible together")
	var before: Dictionary=session.world.snapshot()
	await _mouse(game.painting_panel.buttons.harbor.get_global_rect().get_center())
	if DisplayServer.get_name()=="headless": game.painting_panel.buttons.harbor.grab_focus()
	await _capture("subject-preview")
	assert(game.painting_panel.preview.picture.subject=="harbor",str([game.painting_panel.preview.picture,game.painting_panel.buttons.harbor.get_global_rect(),game.tools_box.get_parent().scroll_vertical]))
	assert(session.world.snapshot()==before,"Subject preview cannot begin a painting")
	await _button(game.painting_panel.buttons.meadow)
	assert(member.task.has("paint_action") and game.painting_panel.pending.is_empty())
	await _advance(8); await _capture("in-progress")
	assert(float(easel.painting.progress)>0 and float(easel.painting.progress)<24 and game.lot_view._activity_pose(member).kind=="easel")
	await _button(game.queue_label); await _capture("plan")
	assert(game._plan_detail.text.contains("Paint morning meadow") and game._plan_detail.tooltip_text.contains("Painting finishes"))
	await _button(game.plan_controls[member.task.id].cancel); game.plan_panel.hide(); game._refresh(); await process_frame; await process_frame; await _mouse(_point(id),true)
	var partial: Dictionary=easel.painting.duplicate(true)
	await _advance(3); assert(easel.painting==partial and not game.painting_panel.buttons.resume.disabled)
	await _capture("paused-canvas")
	await _button(game.painting_panel.buttons.resume)
	# Hold a navigation press across completion. It cannot turn into a sale or
	# navigate a replacement canvas, even when its button moves under the pointer.
	var held_button: Button=game.painting_panel.hobby_button
	held_button.grab_focus()
	var held := InputEventMouseButton.new(); held.button_index=MOUSE_BUTTON_LEFT; held.position=held_button.get_global_rect().get_center(); held.pressed=true
	root.push_input(held,true); await process_frame
	await _advance(30)
	assert(held_button==game.painting_panel.hobby_button and held_button.has_focus(),"Completion preserves navigation identity and focus")
	var finished_state: Dictionary=session.world.snapshot()
	held.pressed=false; root.push_input(held,true); await process_frame
	assert(session.world.snapshot()==finished_state and game._context_page=="painting","A held click across completion cannot become a sale or a different action")
	await _capture("finished-meadow")
	assert(preload("res://game/paintings.gd").finished(easel.painting) and game.painting_panel.artist.text=="By Alex")
	assert(not game.painting_panel.buttons.sell.disabled and not game.painting_panel.buttons.meadow.visible)
	# Keyboard activation also binds to the generation at key-down.
	game.painting_panel.buttons.sell.grab_focus()
	var held_key := InputEventKey.new(); held_key.keycode=KEY_SPACE; held_key.physical_keycode=KEY_SPACE; held_key.pressed=true
	root.push_input(held_key,true); await process_frame
	session.world_generation+=1
	var replacement_state: Dictionary=session.world.snapshot()
	held_key.pressed=false; root.push_input(held_key,true); await process_frame
	assert(session.world.snapshot()==replacement_state,"A key released after world replacement cannot sell a reused target ID")
	var finished: Dictionary=easel.painting.duplicate(true)
	await _button(game.mode_button)
	var budget_before: int=lot.funds
	await _button(_named(game.context_box,"Sell")); await _mouse(_point(id)); await _capture("sell-easel")
	await _mouse(_point(id),true); assert(session.world._object(lot,id).is_empty() and lot.funds==budget_before+132)
	await _button(game.undo_button); easel=session.world._object(lot,id)
	assert(easel.painting==finished and lot.funds==budget_before,"Undo restores the whole easel and its artwork")
	for rotation in range(1,4):
		assert(session.world.apply_command(session.profile_id,{"type":"move_object","lot_id":lot.id,"object_id":id,"x":9,"y":9,"rotation":rotation}).ok)
		await _capture("rotation-"+str(rotation)); assert(game.lot_view.hit_target(_point(id)).id==id and easel.painting==finished)
	await _button(game.mode_button); await _mouse(_point(id),true)
	# Correlated acknowledgements wait for an authoritative plan counter.
	var panel: VBoxContainer=game.painting_panel
	var intent := {"type":"painting","lot_id":lot.id,"target_id":id,"member_id":member.id,"action":"sell","subject":"","revision":easel.painting.revision}
	panel.pending=intent.duplicate(true); panel._next_action=member.next_action; game._refresh()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated"); assert(not panel.pending.is_empty())
	session.command_completed.emit(intent,false,"The canvas changed")
	assert(panel.pending.is_empty() and panel.feedback.text=="The canvas changed" and not panel.buttons.sell.disabled)
	panel.pending=intent.duplicate(true); panel._reply_error=""; game._refresh()
	session.command_completed.emit(intent,true,"Queued"); assert(not panel.pending.is_empty() and panel.buttons.sell.disabled)
	var funds: int=lot.funds
	assert(session.world.apply_command(session.profile_id,intent).ok); game._refresh(); assert(panel.pending.is_empty())
	await _advance(2); await _capture("selling")
	await _advance(6); assert(easel.painting.subject=="" and lot.funds==funds+60)
	for subject: String in ["harbor","flowers"]:
		await _button(game.painting_panel.buttons[subject]); await _advance(30); await _capture("finished-"+subject)
		assert(easel.painting.subject==subject and preload("res://game/paintings.gd").finished(easel.painting))
		if subject=="harbor": await _button(game.painting_panel.buttons.sell); await _advance(8)
	var saved: Dictionary=session.world.snapshot()
	assert(session.world.restore(saved,true)); game._refresh(); await _capture("restored")
	assert(game.painting_panel.preview.picture.subject=="flowers" and game.painting_panel.artist.text=="By Alex")
	# Inspect a neighbor's work without enabling their creative or sale actions.
	session.world.ensure_family("violet","Violet")
	assert(session.world.apply_command("violet",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(session.world.apply_command("violet",{"type":"place","lot_id":"lot_2","kind":"easel","x":9,"y":9}).ok)
	assert(session.world.apply_command("violet",{"type":"build_end","lot_id":"lot_2"}).ok)
	assert(session.world.apply_command(session.profile_id,{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)
	game._select_lot("lot_2"); game._interact(str(session.state.lots.lot_2.objects[-1].id)); await _capture("visitor")
	assert(game.painting_panel.buttons.meadow.disabled and game.painting_panel.note.text.contains("Only their household"))
	if root.get_node("Soundscape").enabled: assert(heard.has("page") and heard.has("fabric"),"Painting and packing play their sparse cues through the live mixer")
	print("PAINTINGS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()

