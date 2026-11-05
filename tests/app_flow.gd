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
	app.game.household_requested.emit()
	assert(app.page=="household" and session.menu_paused,"Household editor opens over the world and pauses solo life")
	var family: Dictionary=session.state.families[session.profile_id]
	var before: Dictionary=family.duplicate(true)
	app.household_editor.family_name.text="The Gardeners"
	app.household_editor.member_names[1].text="Violet"
	app.household_editor._choose(1,"shirt",3)
	assert(family==before,"Editor previews do not mutate the household")
	await _key(KEY_ESCAPE)
	assert(app.page=="game","Escape closes the household editor")
	assert(family.name==before.name and family.members[1].name==before.members[1].name and family.members[1].appearance==before.members[1].appearance,"Cancel discards identity preview changes while simulation resumes")
	app.open_household()
	app.household_editor.family_name.text="The Gardeners"
	app.household_editor.member_names[1].text="Violet"
	app.household_editor._choose(1,"shirt",3)
	app._apply_household()
	assert(app.page=="game" and family.name=="The Gardeners" and family.members[1].name=="Violet" and family.members[1].appearance.shirt==3,"Apply updates both identity and appearance through the command path")
	app.open_household(); app.household_editor.member_names[0].text=""
	app._apply_household()
	assert(app.page=="household" and not app.household_apply.disabled and not app.message_label.text.is_empty(),"Invalid names leave an editable form with feedback")
	app._back()
	# Mail drafts remain local; explicit delivery/collection changes saved state.
	session.world.ensure_family("mail_neighbor","Violet")
	app.game.mail_requested.emit()
	assert(app.page=="mail" and session.menu_paused)
	app.mail_panel.write_button.pressed.emit()
	app.mail_panel.note_input.text="Tea on the porch next time?"
	app.mail_panel.note_input.text_changed.emit(app.mail_panel.note_input.text)
	assert(not app.mail_panel.send_button.disabled and session.state.families.mail_neighbor.mailbox.items.is_empty())
	app.mail_panel.send_button.pressed.emit()
	assert(session.state.families.mail_neighbor.mailbox.items.size()==1 and app.mail_panel.pending.is_empty())
	assert(session.world.apply_command("mail_neighbor",{"type":"mail_send","recipient":session.profile_id,"note":"Yes please! A little something for the garden.","gift":100,"sequence":1}).ok)
	session.world_changed.emit(); app.game._refresh()
	assert(app.game.mail_button.text=="1")
	var mail_id: String=family.mailbox.items[0].id
	app.mail_panel.open_buttons[mail_id].pressed.emit()
	assert(family.mailbox.items[0].read and app.mail_panel.archive_button.disabled)
	var mail_funds: int=session.state.lots[family.home_lot].funds
	app.mail_panel.claim_button.pressed.emit()
	assert(session.state.lots[family.home_lot].funds==mail_funds+100 and not app.mail_panel.archive_button.disabled)
	app.mail_panel.archive_button.pressed.emit()
	assert(family.mailbox.items.is_empty() and app.mail_panel.view=="inbox")
	app.mail_panel.write_button.pressed.emit(); app.mail_panel.note_input.grab_focus()
	await _key(KEY_ESCAPE)
	assert(app.page=="game","Escape closes Mail even with keyboard focus in the note field")
	app.game._open_routines()
	app.game.routine_editor.edit_buttons.routine_1.pressed.emit()
	assert(app.game.routine_editor.name_field.has_focus())
	await _key(KEY_ESCAPE)
	assert(app.page=="game" and app.game.routine_panel.visible and app.game.routine_editor.draft.is_empty(),"Escape backs out of a routine draft before pausing")
	await _key(KEY_F1)
	assert(app.console.is_open())
	await _key(KEY_ESCAPE)
	assert(not app.console.is_open() and app.game.routine_panel.visible,"The debug console keeps Escape priority over an open routine library")
	await _key(KEY_ESCAPE)
	assert(not app.game.routine_panel.visible and app.game.plan_panel.visible and app.page=="game")
	app.game.plan_panel.hide()
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
	var previous_ids: Array=[]
	for row: Dictionary in session.list_saves(): previous_ids.append(str(row.id))
	app.slot_name.text="Menu flow test"
	app._perform_save("")
	assert(app.message_label.text.length()>0,"Save menu reports result")
	var id:=""
	for row in session.list_saves():
		if row.name=="Menu flow test" and row.valid and not previous_ids.has(str(row.id)): id=row.id
	assert(not id.is_empty(),"Named save appears in menu library")
	assert(app.selected_slot==id and app.slot_name.text=="Menu flow test")
	var selected: Button
	for button: Button in app.menu_content.find_children("*","Button",true,false):
		if button.button_pressed and button.text.begins_with("Menu flow test"): selected=button
	assert(is_instance_valid(selected) and selected.tooltip_text.contains(" UTC"),"New save is visibly selected, with exact UTC in details")
	var timestamp:=Time.get_unix_time_from_datetime_string("2026-11-05T02:01:00")
	var date:=preload("res://game/save_library.gd").display_time(timestamp,-360)
	assert(date.local=="2026-11-04 20:01 UTC−06:00" and date.utc=="2026-11-05 02:01:00 UTC")
	app.slot_name.text="   "
	app._confirm_overwrite()
	assert(app.page=="confirm" and app.menu_content.find_children("*","Label",true,false).any(func(label): return "“Menu flow test”" in label.text))
	app._confirm_action.call()
	assert(app.page=="save" and app.selected_slot==id and app.slot_name.text=="   ")
	assert("Choose a save name" in app.message_label.text,"A rejected overwrite preserves the selected target and draft")
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
