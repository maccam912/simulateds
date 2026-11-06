extends SceneTree
## Android's Back notification must share the existing draft/tray/menu priority.
const Navigation = preload("res://tests/hud_navigation.gd")
var app: Control
var session: Node

func _initialize() -> void: call_deferred("_run")

func _back() -> void:
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame; await process_frame; await process_frame

func _capture(label: String) -> void:
	await process_frame; await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/android-navigation-"+label+".png")==OK)

func _field_bottom(field: Control, bottom: Vector2) -> Vector2:
	var window := field.get_window()
	if window!=root:
		return root.get_screen_transform()*(Vector2(window.position)+field.get_global_transform_with_canvas()*bottom)
	return root.get_screen_transform()*field.get_global_transform_with_canvas()*bottom

func _keyboard_field(field: Control, layer: Node) -> void:
	field.grab_focus()
	await process_frame; await process_frame
	var original := Vector2(layer.position)
	var bottom := Vector2(0,field.size.y)
	if field is TextEdit: bottom=field.get_caret_draw_pos()+Vector2(0,field.get_line_height())
	var top: float=_field_bottom(field,bottom).y-60.0
	var world: Dictionary=session.world.snapshot()
	var camera: Dictionary=app.game.lot_view.saved_framing()
	for repeat in range(3):
		app._avoid_keyboard(top)
		assert(_field_bottom(field,bottom).y<=top-15.0,"The active text/caret stays above the keyboard without drift")
	app._avoid_keyboard(-1)
	assert(Vector2(layer.position)==original,"Hiding the keyboard restores the original UI targets")
	assert(session.world.snapshot()==world and app.game.lot_view.saved_framing()==camera,"Keyboard avoidance cannot pan the world or change a draft")

func _run() -> void:
	session=root.get_node("Session")
	session.saving_enabled=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	var prefs: Node=root.get_node("Preferences")
	assert(prefs.reset_defaults())
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout
	assert(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back")))
	await _back(); assert(app.page=="main","Back on the main menu never silently quits")
	app.show_game()
	var game: Control=app.game
	var view: Control=game.lot_view
	for compact: bool in [false,true]:
		root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
		assert(prefs.set_value("ui_scale",1.25 if compact else 1.0))
		await process_frame; await process_frame
		for night: bool in [false,true]:
			session.state.day_minutes=60.0 if night else 720.0
			var before: Dictionary=session.world.snapshot()
			view.zoom=1.0; view.pan=Vector2(80,60)
			await Navigation._press(game.zoom_in_button)
			assert(is_equal_approx(view.zoom,1.1) and view.pan==Vector2(80,60))
			await Navigation._press(game.zoom_out_button)
			assert(is_equal_approx(view.zoom,1.0))
			assert(game.zoom_in_button.get_global_rect().size.x>=44 and game.zoom_out_button.get_global_rect().size.y>=44)
			view.zoom_by(20); assert(is_equal_approx(view.zoom,1.8))
			view.zoom_by(-20); assert(is_equal_approx(view.zoom,0.65))
			game._home_overview()
			assert(session.world.snapshot()==before,"Camera controls cannot change positions, plans or saves")
			await _capture(("compact" if compact else "normal")+("-night" if night else "-day"))
	# Back dismisses the current layer, not the app or an unrelated activity.
	var before: Dictionary=session.world.snapshot()
	await Navigation._press(game.more_button)
	await _back(); assert(app.page=="game" and not game.more_panel.visible)
	game._open_context_menu({"type":"ground","x":8,"y":14},Vector2(700,300))
	assert(game.radial_menu.visible)
	await _back(); assert(not game.radial_menu.visible and app.page=="game")
	game._open_routines()
	game.routine_editor.edit_buttons.routine_1.pressed.emit()
	await _back(); assert(game.routine_panel.visible and game.routine_editor.draft.is_empty())
	await _back(); assert(not game.routine_panel.visible and game.plan_panel.visible)
	app._open_console(); assert(app.console.is_open())
	await _back(); assert(not app.console.is_open() and game.plan_panel.visible)
	await _back(); assert(not game.plan_panel.visible and app.page=="game")
	await _back(); assert(app.page=="pause" and session.menu_paused)
	app.open_settings(); await process_frame
	app.binding_action="rotate"
	await _back(); assert(app.page=="settings" and app.binding_action.is_empty())
	await _back(); assert(app.page=="pause")
	await _back(); assert(app.page=="game" and not session.menu_paused)
	app.open_household()
	await process_frame; await process_frame
	var studio: Control=app.household_editor.studio
	var yaw: float=studio.yaw
	var point := studio.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new(); touch.position=point; touch.pressed=true
	root.push_input(touch,true)
	var mouse := InputEventMouseButton.new(); mouse.position=point; mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=true; mouse.device=InputEvent.DEVICE_ID_EMULATION
	root.push_input(mouse,true)
	var drag := InputEventScreenDrag.new(); drag.position=point+Vector2(40,0); drag.relative=Vector2(40,0)
	root.push_input(drag,true)
	var motion := InputEventMouseMotion.new(); motion.position=drag.position; motion.relative=drag.relative; motion.device=InputEvent.DEVICE_ID_EMULATION
	root.push_input(motion,true)
	touch.position=drag.position; touch.pressed=false; root.push_input(touch,true)
	mouse.position=drag.position; mouse.pressed=false; root.push_input(mouse,true)
	await process_frame
	assert(is_equal_approx(studio.yaw-yaw,0.36),"A touch drag turns the preview once, ignoring duplicate mouse emulation")
	assert(not studio._dragging,"Emulated presses cannot leave a mouse drag latched")
	app.household_editor.member_names[0].text="Private draft"
	app.household_editor.member_names[0].grab_focus()
	await _keyboard_field(app.household_editor.member_names[0],app.menu_root)
	await _back(); assert(app.page=="household" and app.household_discard.visible)
	await _back(); assert(app.page=="household" and not app.household_discard.visible)
	await _back(); app._discard_household()
	assert(app.page=="game" and session.world.snapshot()==before,"Back must not commit a private household draft")
	app.open_saves("save"); await process_frame
	app.slot_name.grab_focus()
	await _keyboard_field(app.slot_name,app.menu_root)
	await _back(); assert(app.page=="pause","Back leaves Save even when the name field has focus")
	await _back(); assert(app.page=="game")
	game._open_connection(); await process_frame
	await _keyboard_field(game.code_input,game.connection_dialog.get_child(0))
	await _back(); assert(not game.connection_dialog.visible and app.page=="game","Back closes the multiplayer window")
	game._toggle_build(); await process_frame
	await _keyboard_field(game.catalog_search,game.hud)
	app._open_console(); await process_frame
	var console_field: LineEdit=app.console.find_children("*","LineEdit",true,false)[0]
	await _keyboard_field(console_field,app.console)
	app.console.close()
	print("ANDROID_NAVIGATION_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
