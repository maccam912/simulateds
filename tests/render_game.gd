extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720) if compact else Vector2i(1440,900)
	var suffix := "-compact" if compact else ""
	if "--large-ui" in OS.get_cmdline_user_args():
		root.get_node("Preferences").set_value("ui_scale",1.25)
		suffix += "-large"
	var scene := load("res://game/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build")
	assert(root.get_texture().get_image().save_png("res://build/neighborhood" + suffix + ".png") == OK)
	game._toggle_build()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/construction" + suffix + ".png") == OK)
	var sofa_id := ""
	for object: Dictionary in root.get_node("Session").state.lots[game.viewed_lot].objects:
		if object.kind=="sofa": sofa_id=str(object.id)
	game.selected_tool="move"; game._select_moving_object(sofa_id); game.build_rotation=1; game._refresh()
	var cursor := InputEventMouseMotion.new()
	cursor.position=game.lot_view.grid_point(5.5,8.5)
	root.push_input(cursor,true)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(game.lot_view.preview_result.get("ok",false),"Moving preview allows rotated overlap with itself")
	assert(game.tools_box.get_parent().size.y>=80,"Construction catalog retains usable scroll area")
	assert(root.get_texture().get_image().save_png("res://build/move-valid" + suffix + ".png") == OK)
	cursor=InputEventMouseMotion.new(); cursor.position=game.lot_view.grid_point(0.5,0.5)
	root.push_input(cursor,true)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(not game.lot_view.preview_result.get("ok",true),"Moving preview rejects missing floor")
	assert(root.get_texture().get_image().save_png("res://build/move-invalid" + suffix + ".png") == OK)
	game._moving_object=""; game.selected_tool="floor"; game._refresh()
	game._toggle_build()
	var session := root.get_node("Session")
	game._send({"type":"cancel","member_id":game.selected_member})
	game._send({"type":"autonomy","member_id":game.selected_member,"enabled":false})
	for object: Dictionary in session.state.lots[game.viewed_lot].objects:
		if object.kind in ["fridge","tv","bookshelf"]: game._interact(str(object.id))
	session.menu_paused=true
	game._show_tray(game.plan_panel,true)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/plan" + suffix + ".png") == OK)
	var family: Dictionary=session.state.families[session.profile_id]
	var bed_id: String=session.state.lots[game.viewed_lot].objects[0].id
	for resident: Dictionary in family.members:
		game._send({"type":"cancel","member_id":resident.id})
		game._send({"type":"interact","member_id":resident.id,"lot_id":game.viewed_lot,"target_id":bed_id})
	game.selected_member=str(family.members[1].id)
	game._refresh()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/waiting" + suffix + ".png") == OK)
	game.plan_panel.hide()
	var fridge: Dictionary={}
	for object: Dictionary in session.state.lots[game.viewed_lot].objects:
		if object.kind=="fridge": fridge=object
	var motion := InputEventMouseMotion.new()
	motion.position=game.lot_view.grid_point(float(fridge.x)+0.5,float(fridge.y)+0.5)+Vector2(0,-28)*game.lot_view._cell.x/48.0
	root.push_input(motion,true)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(game.lot_view.hover_target.get("id")==fridge.id)
	assert(root.get_texture().get_image().save_png("res://build/hover" + suffix + ".png") == OK)
	for resident: Dictionary in family.members:
		session.world._clear_member(resident); resident.autonomy=false
	game._open_wishes()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/wishes" + suffix + ".png") == OK)
	var resident: Dictionary=game._member()
	for wish: Dictionary in resident.wishes.wishes:
		if wish.id!="company":
			game._send({"type":"pursue_wish","member_id":resident.id,"wish_id":wish.id}); break
	for index in range(350):
		session.world.step(0.1)
		if resident.task.is_empty() and resident.queue.is_empty(): break
	game._refresh()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(resident.wishes.journal.size()==1)
	assert(root.get_texture().get_image().save_png("res://build/wish-complete" + suffix + ".png") == OK)
	print("GAME_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
