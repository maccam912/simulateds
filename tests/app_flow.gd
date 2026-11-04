extends SceneTree
var app: Control
var session: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session=root.get_node("Session")
	session.world.initialize()
	session.world.ensure_family(session.profile_id,"Alex")
	session.world.set_online(session.profile_id,true)
	session.saving_enabled=true
	app=load("res://game/app.tscn").instantiate()
	root.add_child(app)
	await create_timer(0.9).timeout
	assert(app.page=="main" and session.menu_paused,"Startup opens main menu with solo simulation paused")
	app.show_game()
	assert(app.page=="game" and not session.menu_paused,"Continue resumes simulation")
	await _key(KEY_ESCAPE)
	assert(app.page=="pause" and session.menu_paused,"Escape opens pause")
	app.open_settings()
	assert(app.page=="settings","Settings open")
	app.binding_action="rotate"
	await _key(KEY_T)
	assert(root.get_node("Preferences").action_label("rotate")=="T","Settings captures a new binding")
	app._back()
	assert(app.page=="pause","Settings returns to pause")
	app.show_game()
	await _key(KEY_T)
	assert(app.game.build_rotation==1,"Rebound rotate reaches gameplay")
	await _key(KEY_F1)
	assert(app.console.is_open() and session.menu_paused,"Console pauses solo game")
	var lot:Dictionary=session.state.lots[session.home_lot()]
	var funds:int=lot.funds
	app.console.submit_command("rosebud")
	assert(lot.funds==funds+1000,"Console command reaches current household")
	await _key(KEY_ESCAPE)
	assert(not app.console.is_open() and app.page=="game" and not session.menu_paused,"Escape closes console without opening pause")
	app.open_saves("save")
	app.slot_name.text="Menu flow test"
	app._perform_save("")
	assert(app.message_label.text.length()>0,"Save menu reports result")
	var id:=""
	for row in session.list_saves():
		if row.name=="Menu flow test" and row.valid: id=row.id
	assert(not id.is_empty(),"Named save appears in menu library")
	lot.funds+=987
	app.open_saves("load")
	app.selected_slot=id
	app._perform_load()
	assert(app.page=="game" and session.state.lots[session.home_lot()].funds==funds+1000,"Load menu restores named world")
	root.get_node("Preferences").reset_defaults()
	print("APP_FLOW_PASS")
	await session.quit_application()

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event,true)
		await process_frame
