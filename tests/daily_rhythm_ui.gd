extends SceneTree
const Routines = preload("res://game/routines.gd")
const Pastimes = preload("res://game/pastimes.gd")
const Character = preload("res://game/character_profile.gd")
var game: Control
var session: Node
var family: Dictionary
var member: Dictionary
var compact := false

func _initialize() -> void: call_deferred("_run")

func _frames() -> void:
	game._refresh()
	for index in range(4): await process_frame

func _click(button: Button) -> void:
	assert(button.is_visible_in_tree() and not button.disabled)
	assert(root.get_visible_rect().encloses(button.get_global_rect()))
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await _frames()

func _capture(name: String) -> void:
	await _frames()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/issue9/"+name+("-compact" if compact else "")+".png")==OK)

func _run() -> void:
	compact="--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]; member=family.members[0]
	for resident: Dictionary in family.members: resident.autonomy=false
	member.character=Character.defaults(member); member.character.traits=["Bookworm"]; member.character.likes=["Reading"]; member.favorite="reading"
	var board: Dictionary=family.routines
	var before: Dictionary=session.world.snapshot()
	for minute in [360.0,480.0,659.9]: assert(Routines.daily_idea(board,member,minute).id=="routine_1")
	for minute in [0.0,359.9,1080.0,1320.0,1439.9]: assert(Routines.daily_idea(board,member,minute).id=="routine_2")
	assert(Routines.daily_idea(board,member,660.0).is_empty(),"No suitable saved afternoon recipe means no invented suggestion")
	assert(session.world.snapshot()==before,"Time suggestions cannot mutate state")
	var custom: Dictionary=board.duplicate(true)
	custom.entries[0].name="My own morning"; custom.entries[0].id="routine_12"
	assert(Routines.daily_idea(custom,member,480.0).name=="My own morning")
	custom.entries[0].steps=["bookshelf","table"]
	assert(Routines.daily_idea(custom,member,480.0).is_empty())
	assert(Routines.daily_idea(custom,member,720.0).id=="routine_12","Favorite ideas inspect saved steps, not names or IDs")
	custom.entries=[]; assert(Routines.daily_idea(custom,member,480.0).is_empty())
	var baby: Dictionary=member.duplicate(true); baby.character.age=0
	assert(Routines.daily_idea(board,baby,480.0).is_empty())
	assert("Bookworm" in Pastimes.affinity_detail(member,"bookshelf") and "Likes reading" in Pastimes.affinity_detail(member,"bookshelf"))
	assert(Pastimes.affinity_detail(member,"shower").is_empty())
	var neutral: Dictionary=member.duplicate(true); neutral.erase("character"); neutral.favorite="variety"
	assert(Pastimes.affinity_detail(neutral,"bookshelf").is_empty())
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	DirAccess.make_dir_recursive_absolute("res://build/issue9")
	await _frames(); await _click(game.queue_label)
	assert(game.routine_idea_button.visible and "Morning" in game.routine_idea_button.text)
	assert("Nothing starts" in game.routine_idea_button.tooltip_text)
	await _capture("morning-plan")
	before=session.world.snapshot(); var commands: int=session.actions_received
	await _click(game.routine_idea_button)
	assert(game.routine_panel.visible and game.routine_editor.run_buttons.routine_1.has_focus())
	assert(session.world.snapshot()==before and session.actions_received==commands,"Review is read-only even with autonomy off")
	await _capture("morning-review")
	# Add to plan is the existing explicit host command, after earlier orders.
	assert(session.world.apply_command(session.profile_id,{"type":"move","member_id":member.id,"x":0,"y":0}).ok)
	var active: Dictionary=member.task.duplicate(true)
	await _frames(); await _click(game.routine_editor.run_buttons.routine_1)
	assert(member.task==active and member.queue.size()==3)
	assert(session.actions_received==commands+1)
	# A held recipe edit is never replaced by opening another time suggestion.
	await _click(game.routine_editor.edit_buttons.routine_2)
	game.routine_editor.draft.name="Keep my draft"
	game._show_tray(game.plan_panel,true); session.state.day_minutes=1200.0
	await _frames(); await _click(game.routine_idea_button)
	assert(game.routine_editor.draft.name=="Keep my draft" and game.routine_editor.name_field.has_focus())
	game.routine_editor._back()
	# A missing object keeps its explanation; the suggestion cannot bypass it.
	session.world._clear_member(member)
	var lot: Dictionary=session.state.lots[member.lot_id]
	var objects: Array=lot.objects.duplicate(true)
	for object: Dictionary in lot.objects.duplicate():
		if object.kind=="bed": lot.objects.erase(object)
	game._show_tray(game.plan_panel,true); await _frames()
	assert("No reachable" in game.routine_idea_button.tooltip_text)
	before=session.world.snapshot(); await _click(game.routine_idea_button)
	assert(game.routine_editor.run_buttons.routine_2.disabled and session.world.snapshot()==before)
	await _capture("unavailable-review")
	lot.objects=objects
	# Preference text belongs only to accepted automatic work; refresh stays pure.
	for need: String in member.needs: member.needs[need]=100.0
	member.needs.fun=60.0; member.autonomy=true
	session.world._choose_autonomy(member,lot)
	assert(session.world.task_activity(member.task,member.lot_id)=="bookshelf")
	game._show_tray(game.plan_panel,true); await _frames()
	assert("Bookworm" in game.plan_titles[member.task.id].tooltip_text)
	before=session.world.snapshot()
	for minute in [480.0,720.0,1200.0,1380.0]:
		session.state.day_minutes=minute; before.day_minutes=minute
		await _frames(); assert(session.world.snapshot()==before,"Day/night UI projection never advances the world")
	await _capture("night-preferences")
	await _click(game.recent_button)
	assert(not game.routine_idea_button.visible)
	await _capture("recent")
	await _click(game.recent_button)
	# Reconnect/save round trips derive the same offer without persistent fields.
	var replica=load("res://game/world.gd").new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(session.world.snapshot())),true))
	var restored: Dictionary=replica.state.families[session.profile_id]
	assert(Routines.daily_idea(restored.routines,restored.members[0],replica.state.day_minutes)==Routines.daily_idea(board,member,session.state.day_minutes))
	game.routine_idea_button.grab_focus(); session.state.day_minutes=720.0; await _frames()
	assert(not game.routine_idea_button.visible and game.routines_button.has_focus(),"A disappearing suggestion leaves a stable keyboard route")
	print("DAILY_RHYTHM_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
