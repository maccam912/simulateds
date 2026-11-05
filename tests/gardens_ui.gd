extends SceneTree
const Gardens = preload("res://game/gardens.gd")
var game: Control
var session: Node
var member: Dictionary
var bed: Dictionary
var suffix := ""
var heard: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2,click: bool=true) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame

func _button(button: Button) -> void:
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(button.get_global_rect()) and not button.disabled)
	var pressed := [false]; button.pressed.connect(func(): pressed[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(pressed[0])

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/garden-"+name+suffix+".png")==OK)

func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame

func _start() -> void:
	for tick in range(500):
		session.world.step(0.1); await process_frame
		if member.task.get("path",[]).is_empty() and float(member.task.get("elapsed",0))>0: break
	assert(member.task.has("garden_action"))
	game._refresh(); await create_timer(0.25).timeout

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults()
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=false; session.set_physics_process(false); session.menu_paused=false
	root.get_node("Soundscape").world_sound_started.connect(func(sound: String,_point: Vector2): heard.append(sound))
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.ensure_family("violet","Violet"); session.world.set_online(session.profile_id,true)
	for family: Dictionary in session.state.families.values():
		for resident: Dictionary in family.members:
			resident.autonomy=false
			for wish: Dictionary in resident.wishes.wishes: wish.done=true
	member=session.state.families[session.profile_id].members[0]
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	await _button(game.mode_button); await _button(game.catalog_buttons.garden_bed)
	await _mouse(game.lot_view.grid_point(6.5,13.5),false); await _capture("placement")
	assert(game.lot_view.preview_result.ok)
	await _mouse(game.lot_view.grid_point(6.5,13.5))
	var lot: Dictionary=session.state.lots.lot_1; bed=lot.objects[-1]
	assert(bed.kind=="garden_bed" and bed.garden==Gardens.create() and not lot.floors.has([6,13]))
	await _button(game.mode_button)
	var point: Vector2=game.lot_view.object_point(bed,Vector2(1,0.5))
	point=game.lot_view.grid_point(point.x,point.y)+Vector2(0,-7)*game.lot_view._cell.x/48.0
	assert(game.lot_view.hit_target(point).get("id")==bed.id)
	await _mouse(point); await _capture("empty")
	assert(game._context_page=="garden" and game.garden_panel.buttons.radish.visible and game.garden_panel.buttons.tomato.visible)
	var budget: int=lot.funds; lot.funds=5; game._refresh()
	assert(game.garden_panel.buttons.radish.disabled and "Need §5" in game.garden_panel.buttons.radish.tooltip_text)
	lot.funds=budget; game._refresh()
	await _button(game.garden_panel.buttons.radish)
	assert(member.task.garden_action=="plant" and bed.garden.crop=="" and lot.funds==budget and game.garden_panel.pending.is_empty())
	await _start(); await _capture("planting")
	assert(game.lot_view._activity_pose(member).get("kind")=="garden_bed")
	await _button(game.queue_label); await _capture("plan")
	assert("Plant radishes" in game._plan_detail.text and "Gardening finishes" in game._plan_detail.tooltip_text)
	game.plan_panel.hide(); await _mouse(point) # Reopen the garden after inspecting Plan.
	await _advance(8); await _capture("seedlings")
	assert(bed.garden.crop=="radish" and lot.funds==budget-10 and not game.garden_panel.buttons.radish.visible)
	assert(game.garden_panel.feedback.text.is_empty(),"Completed planting clears the old queue acknowledgement")
	await _advance(50); await _capture("dry")
	assert("Needs water" in game.garden_panel.summary.text and not game.garden_panel.buttons.water.disabled and game.garden_panel.buttons.harvest.disabled)
	var before: Dictionary=bed.garden.duplicate(true); await _advance(5); assert(bed.garden==before)
	await _button(game.garden_panel.buttons.water); await _start(); await _capture("watering")
	assert("Alex" in game.garden_panel.feedback.text and "Water" in game.garden_panel.feedback.text)
	await _advance(6); await _advance(50); await _capture("ripe")
	assert(Gardens.ripe(bed.garden) and not game.garden_panel.buttons.harvest.disabled and game.garden_panel.buttons.water.disabled)
	await _button(game.garden_panel.buttons.harvest); await _start(); await _capture("harvesting")
	await _advance(6); await _capture("harvested")
	assert(bed.garden.crop=="" and bed.garden.harvests==1 and lot.funds==budget+35)
	await _button(game.garden_panel.buttons.tomato); await _start(); await _advance(8)
	await _advance(45); await _button(game.garden_panel.buttons.water); await _start(); await _advance(6)
	await _advance(100); await _capture("tomatoes")
	await _button(game.garden_panel.buttons.water); await _start(); await _advance(6); await _advance(35)
	await _capture("tomatoes-ripe"); assert(Gardens.ripe(bed.garden))
	# Saving/replacing accepted state leaves the displayed crop and actions intact.
	var saved: Dictionary=session.world.snapshot(); session.world.state=saved; game._refresh(); await _capture("snapshot")
	bed=session.state.lots.lot_1.objects[-1]; member=session.state.families[session.profile_id].members[0]
	assert(not game.garden_panel.buttons.harvest.disabled and session.world.snapshot()==saved)
	# Rotating/moving a ripe bed preserves its crop and visible picking surface.
	assert(session.world.apply_command(session.profile_id,{"type":"build_begin","lot_id":"lot_1"}).ok)
	for rotation in [1,2,3]:
		assert(session.world.apply_command(session.profile_id,{"type":"move_object","lot_id":"lot_1","object_id":bed.id,"x":6,"y":13,"rotation":rotation}).ok)
		await _capture("rotation-"+str(rotation))
		point=game.lot_view.object_point(bed,Vector2(1,0.5)); point=game.lot_view.grid_point(point.x,point.y)+Vector2(0,-7)*game.lot_view._cell.x/48.0
		assert(game.lot_view.hit_target(point).get("id")==bed.id and Gardens.ripe(bed.garden))
	assert(session.world.apply_command(session.profile_id,{"type":"build_cancel","lot_id":"lot_1"}).ok)
	bed=session.world._object(session.state.lots.lot_1,str(bed.id)); game._refresh(); await process_frame
	# Correlated acknowledgements wait for the actor's accepted action counter.
	var panel: VBoxContainer=game.garden_panel
	var intent := {"type":"garden","lot_id":"lot_1","target_id":bed.id,"member_id":member.id,"action":"harvest","crop":"","revision":bed.garden.revision}
	panel.pending=intent.duplicate(true); panel._next_action=member.next_action; game._refresh()
	session.command_completed.emit({"type":"cancel"},false,"Unrelated"); assert(not panel.pending.is_empty())
	session.command_completed.emit(intent,false,"The garden changed")
	assert(panel.pending.is_empty() and not panel.buttons.harvest.disabled and panel.feedback.text=="The garden changed")
	panel.pending=intent.duplicate(true); panel._reply_error=""; game._refresh()
	session.command_completed.emit(intent,true,"Queued"); assert(not panel.pending.is_empty() and panel.buttons.harvest.disabled)
	assert(session.world.apply_command(session.profile_id,intent).ok); game._refresh(); assert(panel.pending.is_empty())
	await _advance(8)
	# A neighbor's garden can be inspected, with planting/harvesting ownership clear.
	assert(session.world.apply_command("violet",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(session.world.apply_command("violet",{"type":"place","lot_id":"lot_2","kind":"garden_bed","x":6,"y":13,"rotation":1}).ok)
	assert(session.world.apply_command("violet",{"type":"build_end","lot_id":"lot_2"}).ok)
	assert(session.world.apply_command(session.profile_id,{"type":"visit","member_id":member.id,"lot_id":"lot_2"}).ok)
	game._select_lot("lot_2"); game._interact(str(session.state.lots.lot_2.objects[-1].id)); await _capture("visitor")
	assert(game.garden_panel.buttons.radish.disabled and "Only this household" in game.garden_panel.buttons.radish.tooltip_text)
	assert("Visitors can help water" in game.garden_panel.note.text)
	if root.get_node("Soundscape").enabled: assert(heard.has("page") and heard.has("water"),"Gardening emits its planting/harvest rustle and watering cue through the live mixer")
	print("GARDENS_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
