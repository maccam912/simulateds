extends SceneTree
const Profile = preload("res://game/character_profile.gd")
var app: Control
var editor: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")
func _settle() -> void:
	for frame in range(5): await process_frame

func _capture(label: String) -> void:
	await _settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/creator-"+label+suffix+".png")==OK)

func _choose(key: String, index: int) -> void:
	var control: OptionButton=editor.controls[key]
	control.select(index); control.item_selected.emit(index)
	await _settle()

func _click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=control.get_global_rect().get_center(); root.push_input(event,true)
		await process_frame

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var preferences := root.get_node("Preferences"); preferences.reset_defaults()
	if compact: suffix="-compact"; preferences.set_value("ui_scale",1.25)
	if "--low" in OS.get_cmdline_user_args(): suffix+="-low"; preferences.set_value("quality","low")
	session=root.get_node("Session"); session.saving_enabled=false; session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	session.set_physics_process(false)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app)
	await create_timer(0.9).timeout
	app.show_game(); app.open_household(); editor=app.household_editor
	await _settle()
	var before: Dictionary=session.world.snapshot()
	var center: Vector2=editor.studio.get_global_rect().get_center()
	var press := InputEventMouseButton.new(); press.position=center; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; root.push_input(press,true)
	var drag := InputEventMouseMotion.new(); drag.position=center+Vector2(50,0); drag.relative=Vector2(50,0); drag.button_mask=MOUSE_BUTTON_MASK_LEFT
	var yaw: float=editor.studio.yaw; root.push_input(drag,true)
	press.pressed=false; press.position=drag.position; root.push_input(press,true)
	assert(editor.studio.yaw!=yaw,"Dragging the model rotates the preview")
	editor.studio.yaw=-0.16
	assert(editor.studio.viewport.own_world_3d and session.menu_paused)
	assert(editor.studio.size.y>250 and editor.studio.size.x>350,"Creator devotes most of the mode to a large live model")
	assert(app.household_apply.get_global_rect().end.y<=root.get_visible_rect().size.y)
	editor.family_name.text="The Linden family"
	editor.member_names[0].text="Rowan"; editor.member_names[0].text_changed.emit("Rowan")
	editor._choose(0,"skin",3); editor._choose(0,"hair",2)
	editor._set_profile("hairstyle",4); editor._set_profile("build",64); editor._set_profile("shoulders",43); editor._set_profile("eyes",3)
	await _capture("identity-day")
	editor.studio.camera.size=1.9; editor._choose(0,"hair",2)
	assert(is_equal_approx(editor.studio.camera.size,1.9),"Recoloring preserves the chosen preview zoom")
	editor.studio.set_close_up(false)
	var first_head: Vector3=editor.studio.model.get_node("Head").rotation
	await create_timer(0.3).timeout
	assert(editor.studio.model.get_node("Head").rotation!=first_head,"Creator has live idle motion")
	assert(session.world.snapshot()==before,"Preview animation and customization cannot mutate authority")
	preferences.set_value("reduced_motion",true); await _settle()
	var still: Vector3=editor.studio.model.get_node("Head").rotation
	await create_timer(0.1).timeout
	assert(editor.studio.model.get_node("Head").rotation==still)
	preferences.set_value("reduced_motion",false)
	editor.select_section(1); editor.studio.set_close_up(true)
	await _capture("face-day")
	editor.studio.set_night(true); await _capture("face-night")
	editor.studio.yaw=PI; await _capture("hair-back")
	editor.studio.yaw=-0.16; editor.studio.set_close_up(false); editor.studio.set_night(false)
	editor.select_section(3); await _choose("occasion",1); await _choose("top",4)
	editor._set_outfit("top_color",10); editor._set_outfit("bottom",4); editor._set_outfit("bottom_color",10); editor._set_outfit("accessory",3)
	var formal: Dictionary=editor._profile().outfits.formal.duplicate(true)
	await _capture("formal-day")
	await _choose("occasion",2); editor._set_outfit("top_color",11); editor._set_outfit("pattern",1)
	assert(editor._profile().outfits.formal==formal,"Each outfit slot is independent")
	await _capture("pjs")
	await _choose("occasion",3); await _capture("swimming")
	await _choose("occasion",4); await _capture("athletic")
	await _choose("occasion",0)
	editor.select_section(4)
	editor.controls["trait_Creative"].button_pressed=true; editor.controls["trait_Gentle"].button_pressed=true; editor.controls["trait_Bookworm"].button_pressed=true
	editor.controls["trait_Playful"].button_pressed=true
	assert(editor._profile().traits.size()==3 and not editor.controls["trait_Playful"].button_pressed)
	await _choose("interest_Reading",1); await _choose("interest_Television",2)
	await _capture("personality")
	editor.select_section(2); await _choose("voice",2); editor.controls.pitch.value=37
	editor.studio.preview_voice()
	await _capture("body-voice")
	# Build a family through the mode, retaining residents and independent outfits.
	editor.select_member(1); editor.member_names[1].text="Robin"; editor._set_profile("age",4)
	editor.add_member(); editor.member_names[2].text="Juniper"; editor._set_profile("age",2); editor._set_profile("hairstyle",8)
	await _capture("child")
	editor.add_member(); editor.member_names[3].text="Pip"; editor._set_profile("age",0)
	await _capture("baby")
	editor.add_member(); editor.member_names[4].text="Mara"; editor._set_profile("age",6); editor._choose(4,"hair",5)
	await _capture("elder")
	editor.select_member(0); editor.select_section(5); editor._set_relation(1,1); editor._set_relation(2,4); editor._set_relation(3,4)
	editor.select_member(4); editor.select_section(5); editor._set_relation(0,4); editor._set_relation(2,6)
	assert(Profile.relations_valid(editor.draft.relations,editor.draft.members))
	await _capture("family")
	# Draft member removal preserves all other links and stable established IDs.
	editor.add_member(); editor.remove_draft_member()
	assert(editor.draft.members.size()==5 and Profile.relations_valid(editor.draft.relations,editor.draft.members))
	editor.select_member(0); editor.select_section(0)
	var command: Dictionary=editor.payload()
	assert(Profile.valid(command.members[0].character))
	await _click(app.household_apply)
	assert(app.page=="game" and session.state.families[session.profile_id].members.size()==5)
	assert(session.state.families[session.profile_id].members[0].character.outfits.formal==formal)
	assert(session.state.families[session.profile_id].members[0].character.voice==2)
	session.menu_paused=true; app.game.lot_view.center_lot(); app.game.lot_view.zoom=1.6
	# Put the cast on distinct clear home tiles using existing commands.
	var family: Dictionary=session.state.families[session.profile_id]
	for index in range(family.members.size()):
		var member: Dictionary=family.members[index]
		if not Profile.is_baby(member):
			assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":member.id,"x":6+index,"y":7}).ok)
	for index in range(100): session.world.step(0.1)
	app.game._refresh(); await _capture("world-day")
	session.world.state.day_minutes=1320; app.game._refresh(); await _capture("world-night")
	var loaded: RefCounted = load("res://game/world.gd").new()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(session.world.snapshot()))))
	assert(loaded.state.families[session.profile_id].members[0].character==family.members[0].character)
	app.open_household(); editor=app.household_editor
	assert(editor._profile().outfits.formal==formal and editor.draft.relations==command.relations)
	var before_cancel: Dictionary=session.world.snapshot()
	editor._set_profile("eyes",7); app._back()
	assert(session.world.snapshot()==before_cancel,"Cancel discards detailed changes")
	# A submitted draft has exactly one pending result. An unrelated reply or
	# Escape cannot pretend to cancel an already-sent save; rejection restores it.
	session.role="client"; session._welcomed=true; app.open_household(); editor=app.household_editor
	app._apply_household()
	assert(not app._pending_household.is_empty() and app.household_cancel.disabled)
	var pending: Dictionary=app._pending_household.duplicate(true)
	app._household_result({"type":"move"},false,"Another action failed")
	app._back(); assert(app.page=="household" and app._pending_household==pending)
	app._household_result(pending,false,"Choose a valid family tie")
	assert(app._pending_household.is_empty() and not app.household_apply.disabled and not app.household_cancel.disabled)
	app._apply_household(); session.role="offline"; app._session_status("Disconnected")
	assert(app._pending_household.is_empty() and app.household_apply.disabled and not app.household_cancel.disabled)
	session._requests.clear(); session._welcomed=false; app._back()
	print("CHARACTER_CREATOR_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
