extends SceneTree
const Leisure=preload("res://game/shared_leisure.gd")
const Bonds=preload("res://game/friendships.gd")
var game: Control
var session: Node
var first: Dictionary
var second: Dictionary
var lot: Dictionary
var table: Dictionary
var stereo: Dictionary
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func _mouse(point: Vector2,click: bool=true) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion:=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame
func _button(button: Button) -> void:
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(button.get_global_rect()))
	var label: String=button.text
	var clicked: Array=[false]; button.pressed.connect(func(): clicked[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(clicked[0],label)
func _object(object: Dictionary) -> void:
	game.lot_view._layout()
	var cell: Vector2=game.lot_view.object_point(object,Vector2(1,1) if object.kind=="game_table" else Vector2(0.5,0.5))
	var center: Vector2=game.lot_view.grid_point(cell.x,cell.y)
	for dx in range(-35,36,4):
		for dy in range(-55,2,4):
			var point:=center+Vector2(dx,dy)
			if game.lot_view.hit_target(point).get("id")==object.id:
				await _mouse(point); return
	assert(false,"There must be a visible furnishing click target")
func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/recreation-"+name+suffix+".png")==OK)
func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame
func _arrive(object: Dictionary,count: int=2) -> void:
	for tick in range(100):
		session.world.step(0.1); game._refresh(); await process_frame
		if Leisure.players(session.state,lot.id,object.id).size()==count: return
	assert(false,"Residents did not reach the recreation places")
func _cancel() -> void:
	for resident: Dictionary in [first,second]: assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":resident.id}).ok)
	game._refresh(); await process_frame
func _run() -> void:
	var compact: bool="--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	for owner: String in [session.profile_id,"neighbor"]:
		session.world.set_online(owner,true)
		for resident: Dictionary in session.state.families[owner].members: resident.autonomy=false; resident.needs.fun=0; resident.needs.social=0
	lot=session.state.lots.lot_1; first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]
	table=session.world._new_object("game_table",8,5,0); lot.objects.append(table)
	stereo=session.world._new_object("stereo",8,9,0); lot.objects.append(stereo)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	var before: Dictionary=session.world.snapshot()
	await _object(table); await _capture("choice")
	assert(game._context_page=="recreation" and session.world.snapshot()==before,"Inspection does not start play or affect anyone's plan")
	var panel: Control=game.recreation_panel
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.note.get_global_rect()),"The complete plan/timing explanation must fit without scrolling")
	assert(panel.household_button.text=="Call household · 2" and not panel.single_button.disabled)
	await _button(panel.household_button)
	assert(game.recreation_panel==panel and panel.household_button.has_focus() and panel.pending.is_empty())
	assert(first.task.target_id==table.id and second.task.target_id==table.id and session.state.families.neighbor==before.families.neighbor)
	await _arrive(table); await _advance(4.1); await _capture("playing")
	assert(first.action=="Playing together" and second.action=="Playing together" and panel.household_button.disabled and panel.single_button.disabled and panel.household_button.text=="Already in their plans")
	assert(Bonds.bond(session.state,first.id,second.id).today==1 and Leisure.place(first)!=Leisure.place(second))
	# Individual cancellation preserves the other participant's activity.
	await _button(game.queue_label); var other: Dictionary=second.task.duplicate(true)
	await _button(game.plan_controls[first.task.id].cancel); assert(second.task==other)
	await _cancel(); game.plan_panel.hide()
	# Adopt ongoing automatic dancing without restarting the music or timers.
	for resident: Dictionary in [first,second]:
		resident.needs.fun=0
		session.world._queue_action(resident,{"type":"interact","target_id":stereo.id,"automatic":true}); session.world._start_next(resident,lot)
	await _arrive(stereo); await _advance(2)
	await _object(stereo); panel=game.recreation_panel
	assert(panel.single_button.text=="Choose current dance")
	var times: Array=[first.task.remaining,second.task.remaining]
	await _capture("automatic"); await _button(panel.household_button)
	assert(first.task.remaining==times[0] and second.task.remaining==times[1] and Leisure.chosen_time(first.task)==0 and Leisure.chosen_time(second.task)==0)
	await _advance(3.9); assert(Bonds.bond(session.state,first.id,second.id).today==1)
	await _advance(0.2); assert(Bonds.bond(session.state,first.id,second.id).today==2); await _capture("dancing")
	# Existing plans survive; unavailable residents are visible in the preview.
	await _cancel()
	var shelf: Dictionary=session.world._object_at(lot,Vector2i(10,10))
	assert(session.world.apply_command(session.profile_id,{"type":"interact","member_id":first.id,"target_id":shelf.id}).ok)
	var task: Dictionary=first.task.duplicate(true)
	await _object(table); panel=game.recreation_panel
	assert(panel.rows[first.id].text.contains("After their plan")); await _button(panel.household_button)
	assert(first.task==task and first.queue[-1].target_id==table.id)
	await _cancel()
	assert(session.world.apply_command(session.profile_id,{"type":"visit","member_id":first.id,"lot_id":"lot_2"}).ok)
	game._refresh(); await process_frame; panel=game.recreation_panel
	assert(panel.single_button.disabled and not panel.household_button.disabled and panel.household_button.text=="Call household · 1" and panel.rows[first.id].text.contains("Away"))
	var away:=first.duplicate(true); await _capture("away"); await _button(panel.household_button); assert(first==away)
	await _cancel()
	# Correlated acknowledgement alone is insufficient until a new snapshot arrives.
	var option: Dictionary=session.world.recreation_option(session.profile_id,first.id,lot.id,table.id,true)
	var intent: Dictionary={"type":"recreation","lot_id":lot.id,"target_id":table.id,"member_id":first.id,"household":true,"revision":lot.revision,"orders":option.orders.duplicate(true)}
	panel.pending=intent.duplicate(true); panel._ack=false; panel.refresh(lot.id,table.id,first.id); assert(panel.household_button.disabled)
	var unrelated:=intent.duplicate(true); unrelated.revision+=1
	panel._completed(unrelated,false,"No"); assert(not panel.pending.is_empty())
	panel._completed(intent,true,""); assert(not panel.pending.is_empty())
	panel._completed(intent,false,"The plan changed. Review who can join."); assert(panel.pending.is_empty() and not panel.household_button.disabled and panel.feedback.visible)
	# Return home, use Activities to find the same table, and test long names.
	assert(session.world.apply_command(session.profile_id,{"type":"go_home","member_id":first.id}).ok)
	first.name="Alexandria Longfirstname"; second.name="Robin Longfamilyname"
	await _button(game.palette_button); await process_frame
	var found: Button
	for child: Node in game.tools_box.get_children():
		if child is Button and child.text.begins_with("Game table"): found=child
	assert(found!=null); await _button(found); panel=game.recreation_panel
	await _capture("long-names"); assert(panel.rows[first.id].tooltip_text.contains(first.name))
	await _button(panel.single_button); assert(first.task.target_id==table.id and second.task.is_empty())
	# Four participants with long names cannot push the timing explanation away.
	await _button(panel.household_button)
	for resident: Dictionary in session.state.families.neighbor.members:
		resident.name="Violet Longneighborname" if resident.id=="neighbor_1" else "Cameron Longneighborname"
		assert(session.world.apply_command("neighbor",{"type":"visit","member_id":resident.id,"lot_id":lot.id}).ok)
	var visiting: Dictionary=session.world.recreation_option("neighbor","neighbor_1",lot.id,table.id,true)
	assert(session.world.apply_command("neighbor",{"type":"recreation","member_id":"neighbor_1","lot_id":lot.id,"target_id":table.id,"household":true,"revision":lot.revision,"orders":visiting.orders}).ok)
	await _arrive(table,4); await _capture("four-players")
	assert(panel.company.tooltip_text.contains("Violet Longneighborname") and panel.company.tooltip_text.contains("Cameron Longneighborname"))
	assert(game.tools_box.get_parent().get_global_rect().encloses(panel.note.get_global_rect()),"Long visiting names preserve the visible controls and explanation")
	print("RECREATION_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
