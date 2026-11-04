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
	assert(root.get_texture().get_image().save_png("res://build/company-time-"+name+suffix+".png")==OK)
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
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	lot=session.state.lots.lot_1; first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]
	for resident: Dictionary in [first,second]: resident.autonomy=false; resident.needs.fun=95; resident.needs.social=30
	first.x=7; first.y=5; second.x=0; second.y=15
	table=session.world._new_object("game_table",8,5,0); lot.objects.append(table)
	stereo=session.world._new_object("stereo",8,9,0); lot.objects.append(stereo)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _object(table); await _button(game.recreation_panel.household_button)
	# A ground click appends a real next action; companionship cannot remove it.
	await _mouse(game.lot_view.grid_point(1.5,14.5)); assert(first.queue.size()==1 and first.queue[0].type=="move")
	var next_id: String=first.queue[0].id
	await _button(game.queue_label); await _advance(4.1); await _capture("shared-full-fun")
	assert(first.needs.fun>=99 and first.task.get("target_id")==table.id and first.queue[0].id==next_id)
	assert(game._plan_detail.text.contains("Time for company") and game._plan_progress.visible and game._plan_progress.value>0 and game._plan_progress.value<1)
	assert(game.recreation_panel.note.text.contains("Making time for chosen company"))
	assert(game.tools_box.get_parent().get_global_rect().encloses(game.recreation_panel.note.get_global_rect()))
	var before: Dictionary=session.world.snapshot(); var detail: String=game._plan_detail.text; var progress: float=game._plan_progress.value
	await create_timer(0.3).timeout; game._refresh()
	assert(session.world.snapshot()==before and game._plan_detail.text==detail and game._plan_progress.value==progress,"Paused presentation cannot advance the shared moment")
	for tick in range(180):
		session.world.step(0.1); game._refresh(); await process_frame
		if first.task.get("id")==next_id: break
	assert(first.task.get("id")==next_id and Bonds.bond(session.state,first.id,second.id).today==1)
	await _capture("plan-continues")
	# Cancelling the companion releases a full-fun dancer on the next authority step.
	await _cancel(); game.plan_panel.hide()
	first.x=7; first.y=9; second.x=0; second.y=15
	for resident: Dictionary in [first,second]: resident.needs.fun=95; resident.needs.social=30
	await _object(stereo); await _button(game.recreation_panel.household_button)
	await _button(game.queue_label); await _advance(4.1); await _capture("dance-company")
	assert(game._plan_detail.text.contains("Time for company") and first.task.get("target_id")==stereo.id)
	await _button(game.family_box.get_child(1)); await process_frame
	assert(not second.task.is_empty()); await _button(game.plan_controls[second.task.id].cancel)
	await _button(game.family_box.get_child(0)); await _advance(0.1); await _capture("leave-freely")
	assert(first.task.is_empty() and second.task.is_empty() and Bonds.bond(session.state,first.id,second.id).today==1)
	print("COMPANY_TIME_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
