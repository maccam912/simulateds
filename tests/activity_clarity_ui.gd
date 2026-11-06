extends SceneTree
const Meals=preload("res://game/meals.gd")
const Gardens=preload("res://game/gardens.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for frame in range(5): await process_frame
func capture(name: String) -> void:
	game._refresh(); await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/activity-clarity-"+name+suffix+".png")==OK)
func click(button: Button) -> void:
	game.tools_box.get_parent().ensure_control_visible(button); await settle()
	assert(root.get_visible_rect().encloses(button.get_global_rect()) and not button.disabled)
	var at:=button.get_global_rect().get_center()
	if DisplayServer.get_name()!="headless": root.grab_focus(); Input.warp_mouse(at); await settle()
	var motion:=InputEventMouseMotion.new(); motion.position=at; root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await settle()

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs:=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=false; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]
	var lot: Dictionary=session.state.lots[family.home_lot]
	var first: Dictionary=family.members[0]; var second: Dictionary=family.members[1]
	var third: Dictionary=second.duplicate(true); third.id=str(session.profile_id)+"_3"; third.name="June"; third.character=preload("res://game/character_profile.gd").defaults(third); third.character.age=2; family.members.append(third)
	for member: Dictionary in family.members:
		member.autonomy=false
		for need: String in member.needs: member.needs[need]=100.0
	first.wishes={"day":1,"round":0,"wishes":[{"id":"show","done":false},{"id":"company","done":false},{"id":"story","done":false}],"journal":[]}
	var bed: Dictionary=session.world._new_object("garden_bed",5,13,0); lot.objects.append(bed)
	var table: Dictionary=session.world._new_object("dining_table",8,6,0); lot.objects.append(table)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await settle()
	var before: Dictionary=session.world.snapshot()
	game._open_wishes(); await capture("wishes-day")
	assert(session.world.snapshot()==before)
	assert(game.wish_buttons.show.text.contains("Watching television") and game.wish_buttons.show.text.contains(first.name) and game.wish_buttons.show.text.contains("Free") and game.wish_buttons.show.text.contains("game min"))
	assert(game.wish_buttons.company.text.contains("Chat with"))
	await click(game.wish_buttons.show)
	assert(not first.task.is_empty() and not first.wishes.wishes[0].done)
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	# A paused dry crop never claims wall-clock readiness; a faster game has the same remaining game time.
	Gardens.apply(bed.garden,"plant","tomato"); Gardens.grow(bed.garden,45)
	session.debug_speed=0.0
	game._interact(str(bed.id)); await capture("dry-paused")
	assert(game.garden_panel.readiness.text.contains("Paused") and game.garden_panel.readiness.text.contains("Needs water") and game.garden_panel.readiness.text.contains("6 game h 45 min"))
	Gardens.apply(bed.garden,"water",""); session.debug_speed=1.0; game._refresh()
	var estimate: String=game.garden_panel.readiness.text
	session.debug_speed=4.0; game._refresh()
	assert(game.garden_panel.readiness.text==estimate and estimate.contains("if kept watered"))
	session.state.day_minutes=1320.0; await capture("watered-night")
	# Three accepted reservations at distinct progress stages; refresh cannot take food.
	table.meal={"recipe":"salad","servings":4,"batch":1,"cook":first.id,"cook_name":first.name,"day":1}
	first.x=7; first.y=6; second.x=8; second.y=5; third.x=0; third.y=14
	for member: Dictionary in family.members:
		assert(session.world.apply_command(session.profile_id,{"type":"meal","member_id":member.id,"lot_id":lot.id,"target_id":table.id,"action":"eat","recipe":"","batch":1}).ok)
	session.world.step(0.1)
	game._interact(str(table.id)); before=session.world.snapshot(); await capture("meal-three-night")
	assert(session.world.snapshot()==before)
	assert(game.meal_panel.diners.text.contains("June · Walking") and game.meal_panel.diners.text.contains("Eating"))
	assert(game.meal_panel.status.text.contains("1 available") and game.meal_panel.diners.text.contains("Portion reserved"))
	game.tools_box.get_parent().ensure_control_visible(game.meal_panel.diners); await capture("meal-roster-night")
	assert(root.get_visible_rect().encloses(game.meal_panel.diners.get_global_rect()))
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":third.id}).ok)
	game._refresh(); assert(not game.meal_panel.diners.text.contains("June") and Meals.available(session.state,lot,table)==2)
	# All portions taken remains a meal with named diners, not a new recipe picker.
	for member: Dictionary in [first,second]:
		member.task.meal_taken=true; member.task.path=[]; member.task.elapsed=1.0; member.task.remaining=9.0
	table.meal.servings=0
	game._refresh(); assert(game.meal_panel.status.text.contains("0 available") and game.meal_panel.status.text.contains("4 taken") and not game.meal_panel.buttons.salad.visible)
	session.state.day_minutes=600.0; await capture("meal-last-day")
	game.queue_free(); await process_frame; await root.get_node("Soundscape").shutdown_and_wait()
	print("ACTIVITY_CLARITY_UI_PASS"); quit()
