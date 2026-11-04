extends SceneTree
var game: Control
var view: Control
var session: Node
var prefs: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _key(code: int, character: int=0, ctrl: bool=false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.unicode=character; event.pressed=pressed; event.ctrl_pressed=ctrl
		root.push_input(event,true); await process_frame

func _button(control: Control) -> void:
	await process_frame
	assert(root.get_visible_rect().encloses(control.get_global_rect()),"Camera controls must remain on screen")
	var received := [false]
	var label := str(control.text)
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true)
	await process_frame
	control.pressed.connect(func(): received[0]=true,CONNECT_ONE_SHOT)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	assert(received[0],"Button did not receive input: "+label)

func _mouse(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.position=view.camera_focus_point(); event.button_index=button; event.pressed=pressed
	root.push_input(event,true); await process_frame

func _settle() -> void:
	await create_timer(0.3).timeout
	view._layout()

func _centered(member: Dictionary) -> bool:
	view._layout()
	return view.resident_anchor(member).distance_to(view.camera_focus_point())<0.1

func _capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/camera-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	prefs=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true)
	for family: Dictionary in session.state.families.values():
		for resident: Dictionary in family.members: resident.autonomy=false
	var family: Dictionary=session.state.families[session.profile_id]
	var first: Dictionary=family.members[0]; var second: Dictionary=family.members[1]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await process_frame; await process_frame
	var before: Dictionary=session.world.snapshot()
	view.pan=Vector2(4000,3000); view.zoom=1.4
	await _key(KEY_F); await _settle()
	assert(_centered(first) and is_equal_approx(view.zoom,1.4),"F finds the selected resident without resetting zoom")
	assert(session.world.snapshot()==before,"Finding a resident cannot move or command them")
	await _capture("found")
	# Selecting a visible resident leaves the chosen composition alone. Clicking
	# that same name again explicitly centers them, even without a keyboard.
	view.center_lot(); view.pan=Vector2(13,7); view._layout()
	assert(view.resident_in_view(second))
	await _button(game.family_box.get_child(1)); await _settle()
	assert(game.selected_member==second.id and view.pan==Vector2(13,7))
	await _button(game.family_box.get_child(1)); await _settle()
	assert(_centered(second))
	view.pan=Vector2(-4000,-3000)
	await _button(game.family_box.get_child(0)); await _settle()
	assert(_centered(first),"Selecting an offscreen household member brings them into view")
	# Plan remains useful with a long name and the new control at compact scale.
	first.name="A very long resident name here"; family.identity_revision+=1; game._refresh()
	await _button(game.queue_label)
	view.pan=Vector2(2000,1000)
	await _button(game.find_button); await _settle(); assert(_centered(first))
	await _capture("plan")
	game.plan_panel.hide()
	# Manual camera input takes over before the focus tween completes.
	view.pan=Vector2(500,400); game._find_resident()
	await _mouse(MOUSE_BUTTON_MIDDLE,true)
	var drag := InputEventMouseMotion.new(); drag.position=view.camera_focus_point(); drag.relative=Vector2(70,45); drag.button_mask=MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(drag,true); await process_frame
	await _mouse(MOUSE_BUTTON_MIDDLE,false)
	var manual: Vector2=view.pan
	await _settle(); assert(view.pan==manual and not view._dragging,"A pending tween cannot pull back after a drag")
	game._find_resident(); await _mouse(MOUSE_BUTTON_WHEEL_UP,true)
	await _mouse(MOUSE_BUTTON_WHEEL_UP,false)
	manual=view.pan; await _settle(); assert(view.pan==manual,"Zoom also cancels focus motion")
	game._find_resident(); view.center_lot(); await _settle()
	assert(view.pan==Vector2.ZERO and view.zoom==1.0,"Center stops any tween and resets both camera controls")
	prefs.set_value("reduced_motion",true); view.pan=Vector2(2000,1000); game._find_resident()
	assert(_centered(first),"Reduced motion centers immediately")
	# Household buttons must resolve fresh snapshots instead of captured member
	# dictionaries. A resident visiting another lot is found on that current lot.
	session.world.state=session.world.snapshot()
	first=session.state.families[session.profile_id].members[0]
	first.lot_id="lot_2"; first.x=5; first.y=6
	view.zoom=1.3
	await _capture("before-visit")
	await _button(game.family_box.get_child(0))
	assert(game.viewed_lot=="lot_2" and view.lot_id=="lot_2" and _centered(first) and is_equal_approx(view.zoom,1.3),"Visitor focus: lot=%s view=%s centered=%s zoom=%s" % [game.viewed_lot,view.lot_id,_centered(first),view.zoom])
	await _capture("visiting")
	game._select_lot("lot_1")
	assert(view.pan==Vector2.ZERO and is_equal_approx(view.zoom,1.3),"Switching lots restores framing but preserves preferred zoom")
	# A custom key works, while the former key and modified search key do not.
	assert(prefs.bind_action("focus_resident",KEY_G).ok)
	view.pan=Vector2(800,600); manual=view.pan
	await _key(KEY_F); assert(view.pan==manual)
	await _key(KEY_G); assert(game.viewed_lot=="lot_2" and _centered(first))
	game.hud.hide(); view.pan=Vector2(800,600); manual=view.pan
	await _key(KEY_G); assert(view.pan==manual,"Menus do not operate the hidden game camera")
	game.hud.show(); game._select_lot("lot_1"); game._toggle_build()
	view.pan=Vector2(80,60); manual=view.pan
	await _key(KEY_F,0,true)
	assert(game.catalog_search.has_focus() and view.pan==manual,"Ctrl/Cmd+F still opens catalog search")
	await _key(KEY_G,103); assert(game.catalog_search.text=="g" and view.pan==manual,"Typing the rebound key cannot move the camera")
	await _capture("typing")
	print("CAMERA_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
