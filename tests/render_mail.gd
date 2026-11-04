extends SceneTree
var app: Control
var session: Node
var suffix := ""

func _initialize() -> void:
	call_deferred("_run")

func _click(control: Control) -> void:
	await process_frame
	var point := control.get_global_rect().get_center()
	assert(root.get_visible_rect().has_point(point),"Mailbox controls must be on screen")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		root.push_input(event,true)
		await process_frame

func _capture(name: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/mail-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact: suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout; app.show_game()
	await _click(app.game.mail_button)
	assert(app.page=="mail"); await _capture("empty")
	await _click(app.mail_panel.write_button)
	app.mail_panel.note_input.text="The garden looks lovely. Come over for tea when you are back!"
	app.mail_panel.note_input.text_changed.emit(app.mail_panel.note_input.text)
	app.mail_panel.gift_input.select(1); app.mail_panel.gift_input.item_selected.emit(1)
	await _capture("compose")
	await _click(app.mail_panel.send_button)
	assert(session.state.families.neighbor.mailbox.items.size()==1 and session.state.lots.lot_1.funds==11900)
	assert(session.world.apply_command("neighbor",{"type":"mail_send","recipient":session.profile_id,"note":"Thank you! Saving you a seat by the window. A little something for your next room.","gift":250,"sequence":1}).ok)
	session.world_changed.emit()
	await _capture("inbox")
	var id: String=session.state.families[session.profile_id].mailbox.items[0].id
	await _click(app.mail_panel.open_buttons[id])
	await _capture("postcard")
	assert(app.mail_panel.archive_button.disabled)
	await _click(app.mail_panel.claim_button)
	await _capture("collected")
	assert(session.state.lots.lot_1.funds==12150 and not app.mail_panel.archive_button.disabled)
	await _click(app.mail_panel.archive_button)
	assert(session.state.families[session.profile_id].mailbox.items.is_empty())
	await _click(app.mail_panel.write_button)
	assert(app.mail_panel.send_button.disabled and "today" in app.mail_panel.compose_hint.text)
	await _capture("daily-limit")
	app._back(); app.game._refresh()
	assert(app.page=="game" and app.game.hud.visible,"Back from Mail returns directly to the neighborhood")
	await _capture("hud")
	print("MAIL_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
