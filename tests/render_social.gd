extends SceneTree
const Friendships = preload("res://game/friendships.gd")
var game: Control
var session: Node
var neighbor: Dictionary
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _click(button: Button) -> void:
	await preload("res://tests/hud_navigation.gd").reveal(button)
	await process_frame
	if game.tools_box.is_ancestor_of(button):
		game.tools_box.get_parent().ensure_control_visible(button)
		await process_frame
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	game._refresh()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/social-"+name+suffix+".png")==OK)

func _finish_chat() -> void:
	for index in range(350):
		session.world.step(0.1)
		if game._member().task.is_empty() and game._member().queue.is_empty(): return
	assert(false,"Social-panel chat did not complete")

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact:
		suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true); session.world.set_online("neighbor",true)
	for family: Dictionary in session.state.families.values():
		for member: Dictionary in family.members: member.autonomy=false
	neighbor=session.state.families.neighbor.members[0]
	neighbor.appearance={"skin":2,"hair":1,"shirt":3,"style":1}
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://build")
	await _click(game.people_button)
	await _capture("people")
	assert(game.social_buttons.size()==3)
	await _click(game.social_buttons[neighbor.id])
	assert(game._member().lot_id=="lot_2" and game.viewed_lot=="lot_2")
	await _click(game.social_buttons[neighbor.id])
	assert(game.social_buttons[neighbor.id].disabled)
	await _capture("chat")
	_finish_chat(); await _capture("met")
	assert(Friendships.bond(session.state,str(game.selected_member),str(neighbor.id)).score==12)
	game._social_action(str(neighbor.id)); _finish_chat(); game._refresh()
	await _capture("caught-up")
	session.state.day+=1
	for index in range(2):
		game._social_action(str(neighbor.id)); _finish_chat(); game._refresh()
	await _capture("friends")
	assert(Friendships.bond(session.state,str(game.selected_member),str(neighbor.id)).score==48)
	assert("friends" in game.notice_label.text)
	assert(session.world.apply_command("neighbor",{"type":"build_begin","lot_id":"lot_2"}).ok)
	await _capture("construction")
	assert(game.social_buttons[neighbor.id].disabled and game.social_buttons[neighbor.id].text=="Under construction")
	session.world.apply_command("neighbor",{"type":"build_cancel","lot_id":"lot_2"})
	session.world.set_online("neighbor",false)
	await _capture("away")
	print("SOCIAL_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
