extends SceneTree
var app: Control
var game: Control
var session: Node
var suffix := ""

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
	assert(control.is_visible_in_tree(),"Open the tray before clicking "+control.text)
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
	assert(root.get_texture().get_image().save_png("res://build/commission-feedback-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame; await process_frame

func _await_ready() -> void:
	for attempt in range(50):
		if game.notice_commission_button.is_visible_in_tree(): return
		await create_timer(0.1).timeout
	assert(false,"Newly finished commissioned art must be noticed during play")
func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	session.world.ensure_family("neighbor","Violet")
	var family: Dictionary=session.state.families[session.profile_id]; var home: Dictionary=session.state.lots[family.home_lot]
	for resident: Dictionary in family.members: resident.autonomy=false
	var first: Dictionary=family.members[0]; var second: Dictionary=family.members[1]
	var easel: Dictionary=session.world._new_object("easel",9,9,0); home.objects.append(easel)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app); game=app.game
	await create_timer(0.9).timeout; await _button(_named(app.menu_content,"Continue"))
	await _button(game.palette_button); await _button(game.commission_entry); await _button(game.commission_panel.confirm)
	var terms: Dictionary=preload("res://game/art_commissions.gd").offer(session.profile_id,family.commissions)
	await _button(game.commission_panel.confirm); await _button(game.painting_panel.buttons[terms.subject])
	assert(first.task.has("paint_action"))
	game.context_panel.hide(); await _button(game.family_box.get_child(1))
	await _button(game.neighborhood_button); await _button(game.lot_buttons.lot_2); await _button(game.visit_button)
	await _button(game.queue_label)
	assert(game.selected_member==second.id and second.lot_id=="lot_2" and game.viewed_lot=="lot_2" and game.plan_panel.visible)
	game._show_notice("Your other resident's plan is unchanged.")
	var sound: Node=root.get_node("Soundscape"); var cursor: int=sound._effect_cursor
	session.last_action_ok=false # Pure success feedback cannot inherit an old command's error cue.
	await _advance(30); await create_timer(0.7).timeout
	assert(preload("res://game/paintings.gd").finished(easel.painting))
	assert(not game.notice_commission_button.visible and game.notice_label.text=="Your other resident's plan is unchanged.","Ready feedback waits for the preceding notice")
	assert(sound._effect_cursor==cursor)
	game._notice_time=0; await _await_ready(); await _capture("ready-with-plan")
	assert(game.notice_label.text.contains(terms.client.to_lower()) and game.notice_label.text.contains("§180"))
	assert(game.palette_button.text=="•" and game.palette_button.tooltip_text.contains("1 original ready"))
	assert(root.get_visible_rect().encloses(game.notice_panel.get_global_rect()) and game.notice_panel.get_global_rect().encloses(game.notice_label.get_global_rect()))
	assert(game.notice_panel.get_global_rect().encloses(game.notice_commission_button.get_global_rect()) and not game.notice_people_button.visible)
	if sound.enabled:
		assert(sound._effect_cursor==(cursor+1)%sound._effects.size())
		var voice: AudioStreamPlayer=sound._effects[posmod(sound._effect_cursor-1,sound._effects.size())]
		assert(voice.bus=="Effects" and voice.volume_db==-8.0)
	session.last_action_ok=true; cursor=sound._effect_cursor
	await create_timer(0.8).timeout; assert(sound._effect_cursor==cursor)
	var before: Dictionary=session.world.snapshot()
	await _button(game.notice_commission_button); await _capture("originals")
	assert(game._context_page=="commissions" and game.commission_panel.review.is_empty() and game.commission_panel.review_buttons.size()==1)
	assert(game.tools_box.get_parent().get_global_rect().encloses(game.commission_panel.review_buttons.values()[0].get_global_rect()),"The first original's Review button must fit without scrolling")
	assert(game.selected_member==second.id and game.viewed_lot=="lot_2" and game.commission_panel.home_label.text.contains(home.name) and session.world.snapshot()==before and not game.notice_panel.visible,"Review originals opens the home list while preserving the visiting resident, viewed lot, and both plans")
	game.plan_panel.hide(); await _button(game.palette_button); await _capture("activities-ready")
	assert(game.commission_entry.text=="•" and game.commission_entry.get_meta("icon_id")=="art" and game.commission_entry.tooltip_text.contains(preload("res://game/paintings.gd").SUBJECTS[terms.subject]))
	before=session.world.snapshot(); await _button(game.commission_entry)
	assert(session.world.snapshot()==before and game.commission_panel.review.is_empty())
	# Save a ready request, deliver it, then load through real menus: ready remains discoverable without replay.
	var saved: Dictionary=session.save_slot("Ready art commission"); assert(saved.ok)
	await _button(game.commission_panel.review_buttons["easel:"+str(easel.id)]); await _button(game.commission_panel.confirm)
	assert(game.palette_button.text=="" and family.commissions.completed==1)
	app.open_pause(); await _button(_named(app.menu_content,"Load neighborhood"))
	app.selected_slot=saved.id; await _button(_named(app.menu_content,"Load selected")); assert(app.page=="game")
	family=session.state.families[session.profile_id]; home=session.state.lots[family.home_lot]
	first=family.members[0]; second=family.members[1]; easel=session.world._object(home,str(easel.id))
	var message: String=game.notice_label.text; cursor=sound._effect_cursor
	await create_timer(2.0).timeout
	assert(message.begins_with("Loaded") and game.notice_label.text==message and not game.notice_commission_button.visible and sound._effect_cursor==cursor)
	assert(game.palette_button.text=="•"); await _capture("loaded-quietly")
	# Menus consume readiness quietly; returning still shows the persistent mark.
	assert(session.world.apply_command(session.profile_id,preload("res://game/art_commissions.gd").candidates(session.state,session.profile_id)[0].intent).ok)
	session.state.day+=1
	var board: Dictionary=family.commissions; terms=preload("res://game/art_commissions.gd").offer(session.profile_id,board)
	assert(session.world.apply_command(session.profile_id,{"type":"commission_accept","commission_revision":board.revision,"offer":terms.id}).ok)
	assert(session.world.apply_command(session.profile_id,{"type":"painting","member_id":first.id,"target_id":easel.id,"action":"start","subject":terms.subject,"revision":easel.painting.revision}).ok)
	app.open_pause(); await _advance(30); assert(preload("res://game/paintings.gd").finished(easel.painting))
	await _button(_named(app.menu_content,"Resume")); cursor=sound._effect_cursor; game._notice_time=0; await create_timer(0.7).timeout
	assert(not game.notice_commission_button.visible and game.palette_button.text=="•" and sound._effect_cursor==cursor)
	# The next newly accepted request can notify with Effects muted; cancellation invalidates its action.
	prefs.set_value("effects_volume",0.0); game.context_panel.hide()
	assert(session.world.apply_command(session.profile_id,{"type":"commission_cancel","commission_revision":board.revision,"offer":terms.id}).ok); game._refresh()
	assert(session.world.apply_command(session.profile_id,{"type":"commission_accept","commission_revision":board.revision,"offer":terms.id}).ok); game._refresh()
	await _await_ready(); await _capture("muted-ready")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))
	assert(session.world.apply_command(session.profile_id,{"type":"commission_cancel","commission_revision":board.revision,"offer":terms.id}).ok); game._refresh()
	assert(not game.notice_panel.visible and not game.notice_commission_button.visible and game.palette_button.text=="")
	print("COMMISSION_FEEDBACK_UI_PASS")
	await sound.shutdown_and_wait(); quit()
