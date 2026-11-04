extends SceneTree
const ModelPoints = preload("res://tests/model_test_points.gd")
var game: Control
var session: Node
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func _mouse(point: Vector2,click: bool=true) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion:=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; root.push_input(event,true); await process_frame
	await process_frame; await process_frame
func _button(button: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(button)
	await process_frame; await process_frame
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(not button.disabled and root.get_visible_rect().encloses(button.get_global_rect()))
	var pressed: Array=[false]; button.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(pressed[0])
func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/travel-"+name+suffix+".png")==OK)
func _select(id: String) -> void:
	game._select_lot(id); await process_frame; await process_frame; await _button(game.together_button)
func _run() -> void:
	var compact:= "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=false
	session.world.initialize()
	for owner: String in [session.profile_id,"violet"]:
		session.world.ensure_family(owner,"Alex" if owner==session.profile_id else "Violet"); session.world.set_online(owner,true)
		for resident: Dictionary in session.state.families[owner].members: resident.autonomy=false
	var first: Dictionary=session.state.families[session.profile_id].members[0]; var second: Dictionary=session.state.families[session.profile_id].members[1]
	for resident: Dictionary in [first,second]: assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":resident.id,"lot_id":"lot_1","x":0,"y":0}).ok)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	await _select("lot_2"); var panel: Control=game.travel_panel
	assert(panel.confirm.text=="Visit · 2" and panel.details[first.id].text.contains("1 planned") and panel.note.text.contains("Clears"))
	await _capture("preview")
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.note.get_global_rect()) and game.tools_box.get_parent().get_global_rect().encloses(panel.confirm.get_global_rect()),"The cancellation rule and departure button stay visible")
	var names: Array=[first.name,second.name]; first.name="Alexandria Longsurname"; second.name="Robin Longsurname"
	game._refresh(); await process_frame; await process_frame
	assert(panel.choices[first.id].tooltip_text==first.name and root.get_visible_rect().encloses(panel.choices[first.id].get_global_rect()))
	first.name=names[0]; second.name=names[1]; game._refresh()
	var option: Dictionary=session.world.travel_option(session.profile_id,"lot_2",[first.id,second.id])
	var intent: Dictionary={"type":"travel_household","lot_id":"lot_2","member_id":first.id,"travelers":[first.id,second.id],"orders":option.orders.duplicate(true)}
	panel.pending=intent.duplicate(true); game._refresh()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated"); assert(not panel.pending.is_empty())
	session.command_completed.emit(intent,true,"Early acceptance"); assert(not panel.pending.is_empty())
	first.next_action+=1; game._refresh(); assert(not panel.pending.is_empty()); first.next_action-=1
	session.command_completed.emit(intent,false,"Plans changed"); assert(panel.pending.is_empty() and panel.feedback.text=="Plans changed")
	var neighbor: Dictionary=session.state.families.violet.duplicate(true)
	await _button(panel.confirm); await _capture("arrived")
	assert(first.lot_id=="lot_2" and second.lot_id=="lot_2" and Vector2i(first.x,first.y)!=Vector2i(second.x,second.y) and panel.pending.is_empty())
	assert(first.task.is_empty() and second.task.is_empty() and first.activity_log[0].outcome=="cancelled" and session.state.families.violet==neighbor)
	assert(panel.choices[first.id].disabled and panel.confirm.disabled and panel.confirm.text=="Everyone is here" and game.visit_button.disabled)
	for resident: Dictionary in [second,first]:
		var torso := ModelPoints.resident_part(game.lot_view,resident,"Torso")
		assert(game.lot_view.hit_target(torso).get("id")==resident.id,"Each arrival must stay directly selectable")
		await _mouse(torso); assert(game.selected_member==resident.id)
	# Choose only one resident to return, leaving the other housemate's plan intact.
	assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":second.id,"lot_id":"lot_2","x":4,"y":14}).ok)
	var unchanged: Dictionary=second.duplicate(true)
	await _select("lot_1"); panel=game.travel_panel
	await _button(panel.choices[second.id]); await _capture("return-one")
	assert(panel.confirm.text=="Go home · 1")
	await _button(panel.confirm); assert(first.lot_id=="lot_1" and second==unchanged)
	# Rejoining keeps a resident already there unchanged, even if they have work planned.
	await _select("lot_2"); panel=game.travel_panel
	assert(panel.confirm.text=="Visit · 1" and panel.choices[second.id].disabled and panel.details[second.id].text.contains("Keep their plan"))
	await _button(panel.confirm); assert(first.lot_id=="lot_2" and second==unchanged)
	assert(session.world.apply_command("violet",{"type":"build_begin","lot_id":"lot_2"}).ok)
	game._refresh(); await _capture("construction")
	assert(first.lot_id=="lot_1" and second.lot_id=="lot_1" and Vector2i(first.x,first.y)!=Vector2i(second.x,second.y))
	panel=game.travel_panel; assert(panel.confirm.disabled and panel.feedback.text.contains("construction"))
	await _select("lot_3"); assert(game.travel_panel.confirm.disabled and game.travel_panel.feedback.text.contains("Nobody lives"))
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait(); print("HOUSEHOLD_TRAVEL_UI_PASS"); quit()
