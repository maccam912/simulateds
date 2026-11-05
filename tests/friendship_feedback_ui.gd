extends SceneTree
const Leisure=preload("res://game/shared_leisure.gd")
const Bonds=preload("res://game/friendships.gd")
var app: Control
var game: Control
var session: Node
var first: Dictionary
var second: Dictionary
var lot: Dictionary
var table: Dictionary
var stereo: Dictionary
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func _mouse(point: Vector2,click: bool=true) -> void:
	if DisplayServer.get_name()!="headless":
		root.grab_focus(); Input.warp_mouse(point); await process_frame; await process_frame
	var motion:=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	if click:
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true); await process_frame
	await process_frame
func _button(button: Button) -> void:
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button)
	await process_frame; await process_frame
	assert(root.get_visible_rect().encloses(button.get_global_rect()))
	var label: String=button.text
	var clicked: Array=[false]; button.pressed.connect(func(): clicked[0]=true,CONNECT_ONE_SHOT)
	await _mouse(button.get_global_rect().get_center()); assert(clicked[0],label)
func _object(object: Dictionary) -> void:
	game.lot_view._layout()
	var cell: Vector2=game.lot_view.object_point(object,Vector2(1,1) if object.kind=="game_table" else Vector2(0.5,0.5))
	var center: Vector2=game.lot_view.grid_point(cell.x,cell.y)
	for dx in range(-35,36,4):
		for dy in range(-55,2,4):
			var point:=center+Vector2(dx,dy)
			if game.lot_view.hit_target(point).get("id")==object.id:
				await _mouse(point); return
	assert(false,"There must be a visible furnishing click target")
func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.2).timeout
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/friendship-feedback-"+name+suffix+".png")==OK)
func _advance(seconds: float) -> void:
	for tick in range(roundi(seconds*10)): session.world.step(0.1)
	game._refresh(); await process_frame
func _arrive(object: Dictionary,count: int=2) -> void:
	for tick in range(100):
		session.world.step(0.1); game._refresh(); await process_frame
		if Leisure.players(session.state,lot.id,object.id).size()==count: return
	assert(false,"Residents did not reach the recreation places")
func _cancel() -> void:
	for resident: Dictionary in [first,second]: assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":resident.id}).ok)
	game._refresh(); await process_frame
func _find_button(node: Node,label: String) -> Button:
	if node is Button and (node.text==label or node.accessibility_name==label): return node
	for child: Node in node.get_children():
		var found:=_find_button(child,label)
		if found!=null: return found
	return null
func _notice_contains(value: String) -> void:
	for attempt in range(50):
		if game.notice_label.text.contains(value) and game.notice_panel.visible: return
		await create_timer(0.1).timeout
	assert(false,"Accepted progress did not produce its notice: "+value)
func _catch_up(score: int) -> void:
	for tick in range(160):
		session.world.step(0.1); game._refresh(); await process_frame
		if int(Bonds.bond(session.state,first.id,second.id).score)==score: return
	assert(false,"Chosen recreation did not earn its expected progress")
func _run() -> void:
	var compact: bool="--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: suffix="-compact"; prefs.set_value("ui_scale",1.25)
	DirAccess.make_dir_recursive_absolute("res://build")
	session=root.get_node("Session"); session.saving_enabled=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	lot=session.state.lots.lot_1; first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]
	for resident: Dictionary in [first,second]: resident.autonomy=false; resident.needs.fun=95; resident.needs.social=30
	table=session.world._new_object("game_table",8,5,0); lot.objects.append(table)
	app=load("res://game/app.tscn").instantiate(); root.add_child(app); game=app.game
	await create_timer(0.9).timeout
	await _button(_find_button(app.menu_content,"Play starter household" if session.started_fresh else "Continue")); assert(app.page=="game")
	await _object(table); await _button(game.recreation_panel.household_button)
	var sound: Node=root.get_node("Soundscape"); var cursor: int=sound._effect_cursor
	session.last_action_ok=false # An old rejected command cannot turn this success into an error cue.
	await _catch_up(32); await _notice_contains("caught up over a game")
	assert(game.notice_label.text.contains("Alex and Robin") and game.notice_label.text.contains("Friendship grew"))
	session.last_action_ok=true
	if sound.enabled:
		assert(sound._effect_cursor==(cursor+1)%sound._effects.size(),"One accepted catch-up has one UI cue")
		var voice: AudioStreamPlayer=sound._effects[posmod(sound._effect_cursor-1,sound._effects.size())]
		assert(voice.bus=="Effects" and voice.volume_db==-8.0)
	await _capture("first-catch-up")
	var text: String=game.notice_label.text; cursor=sound._effect_cursor
	await create_timer(1.0).timeout; assert(game.notice_label.text==text and sound._effect_cursor==cursor,"Unchanged snapshots do not repeat sound or notices")
	var before: Dictionary=session.world.snapshot()
	await _button(game.notice_people_button)
	assert(game.social_buttons.has(second.id) and game._social_focus==second.id and game._context_page=="people" and not game.notice_panel.visible and session.world.snapshot()==before,"The notice opens the relevant relationship without directing anyone")
	# Long names and an open Plan must still leave the full notice above the HUD.
	await _cancel(); game.context_panel.hide()
	first.name="Alexandra Juniper Meadowbrook"; second.name="Robin Willow Winterbourne"; session.state.families[session.profile_id].identity_revision+=1
	session.state.day+=1
	var bond: Dictionary=Bonds.bond(session.state,first.id,second.id); bond.day=session.state.day; bond.today=0; bond.score=52
	game._friend_feedback.reset(); game._refresh()
	for resident: Dictionary in [first,second]: resident.needs.fun=95; resident.needs.social=30
	await _object(table); await _button(game.recreation_panel.household_button); await _button(game.queue_label)
	await _catch_up(64); await _notice_contains("caught up over a game"); await _capture("long-names")
	assert(game.notice_label.text.contains(first.name) and game.notice_label.text.contains(second.name))
	assert(root.get_visible_rect().encloses(game.notice_panel.get_global_rect()) and game.notice_panel.get_global_rect().encloses(game.notice_label.get_global_rect()))
	assert(game.notice_panel.get_global_rect().end.y<game.family_box.global_position.y)
	assert(game.notice_panel.get_global_rect().encloses(game.notice_people_button.get_global_rect()))
	# Loading a newer saved bond through actual menus must not replay its catch-up.
	await _cancel(); game.plan_panel.hide(); game.context_panel.hide()
	var saved: Dictionary=session.save_slot("Company feedback checkpoint"); assert(saved.ok)
	bond.score=20; game._friend_feedback.reset(); game._refresh()
	var generation: int=session.world_generation
	app.open_pause(); await _button(_find_button(app.menu_content,"Load neighborhood"))
	app.selected_slot=saved.id; await _button(_find_button(app.menu_content,"Load selected"))
	assert(app.page=="game" and session.world_generation>generation)
	first=session.state.families[session.profile_id].members[0]; second=session.state.families[session.profile_id].members[1]; lot=session.state.lots.lot_1
	assert(Bonds.bond(session.state,first.id,second.id).score==64)
	text=game.notice_label.text; assert(text.begins_with("Loaded")); cursor=sound._effect_cursor
	await create_timer(3.0).timeout
	assert(game.notice_label.text==text and sound._effect_cursor==cursor and game.notice_label.tooltip_text.is_empty(),"Loading keeps the load result and never celebrates restored gains")
	await _capture("loaded-quietly")
	# New chosen progress still announces after loading; effects mute keeps text.
	prefs.set_value("effects_volume",0.0)
	for resident: Dictionary in [first,second]: resident.needs.fun=95; resident.needs.social=30
	table=session.world._object_at(lot,Vector2i(8,5))
	await _object(table); await _button(game.recreation_panel.household_button)
	await _catch_up(76); await _notice_contains("now good friends")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))
	await _capture("muted-milestone")
	# A three-person gathering yields one notice/cue, including both owned residents.
	await _cancel(); session.world.ensure_family("neighbor","Violet"); session.world.set_online("neighbor",true)
	for resident: Dictionary in session.state.families.neighbor.members: resident.autonomy=false
	var guest: Dictionary=session.state.families.neighbor.members[0]
	assert(session.world.apply_command("neighbor",{"type":"visit","member_id":guest.id,"lot_id":lot.id}).ok)
	first.name="Alex"; second.name="Robin"; session.state.families[session.profile_id].identity_revision+=1
	first.x=7; first.y=5; second.x=8; second.y=4; guest.x=9; guest.y=4
	session.state.day+=1
	for resident: Dictionary in [first,second,guest]: resident.needs.fun=95; resident.needs.social=30
	game._refresh(); await _object(table); await _button(game.recreation_panel.household_button)
	assert(session.world.apply_command("neighbor",{"type":"interact","member_id":guest.id,"lot_id":lot.id,"target_id":table.id}).ok)
	cursor=sound._effect_cursor; await _catch_up(88); await _notice_contains("2 more friendships grew")
	assert(game.notice_people_button.tooltip_text.contains("Alex and Robin") and game.notice_people_button.tooltip_text.contains("Violet"))
	if sound.enabled: assert(sound._effect_cursor==(cursor+1)%sound._effects.size(),"A group shares a single cue")
	await _capture("three-person-company")
	before=session.world.snapshot(); await _button(game.notice_people_button)
	assert(game.selected_member==first.id and game._social_focus==guest.id and session.world.snapshot()==before)
	# Switching sessions clears a displayed old relationship as well as pending gains.
	game._show_notice("Old company"); game._notice_people={"resident":first.id,"person":guest.id,"generation":session.world_generation}; game.notice_people_button.show()
	session.leave(); game._refresh(); assert(not game.notice_panel.visible and not game.notice_people_button.visible)
	print("FRIENDSHIP_FEEDBACK_UI_PASS")
	await sound.shutdown_and_wait(); quit()
