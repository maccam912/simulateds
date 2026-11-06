extends SceneTree
const Cues = preload("res://game/resident_cues.gd")
const Character = preload("res://game/character_profile.gd")
var session: Node
var game: Control
var view: Control
var family: Dictionary
var native := false

func _initialize() -> void: call_deferred("_run")

func _settle() -> void:
	game._refresh()
	for frame in range(5): await process_frame

func _review(label: String) -> void:
	await _settle()
	var before: Dictionary=session.world.snapshot()
	var selected: String=game.selected_member
	assert(view.resident_labels.has(selected),"Selected resident keeps a label in the crowded review")
	var boxes: Array[Rect2]=[]
	for id: String in view.resident_labels:
		var entry: Dictionary=view.resident_labels[id]
		assert(Rect2(Vector2.ZERO,view.size).encloses(entry.rect))
		for panel: Rect2 in view.overlay_rects: assert(not panel.intersects(entry.rect),"Labels remain outside the HUD and open trays")
		for member: Dictionary in family.members:
			assert(not view.resident_body_rect(member).intersects(entry.rect),"Labels cannot cover a posed body or intercept its mesh hit")
		for box: Rect2 in boxes: assert(not box.intersects(entry.rect))
		boxes.append(entry.rect)
		assert(view.hit_target(entry.rect.get_center()).get("id")==id,"Every displayed label selects its named resident")
	var stable: Dictionary=view.resident_labels.duplicate(true)
	await _settle()
	assert(view.resident_labels==stable,"A paused scene retains label placement across refreshes")
	if native:
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://build/resident-labels-"+label+".png")==OK)
	assert(session.world.snapshot()==before,"Rendering, label layout and picking preserve all authoritative state")

func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("res://build/issue4-labels")
	root.size=Vector2i(1440,900)
	root.get_node("Preferences").reset_defaults()
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]
	var positions := [Vector2i(8,6),Vector2i(9,6),Vector2i(9,7),Vector2i(10,7),Vector2i(7,9),Vector2i(8,9),Vector2i(9,9),Vector2i(8,10)]
	for index in range(8):
		if index>=family.members.size():
			var extra: Dictionary=family.members[0].duplicate(true); extra.id="crowd_%d" % index; family.members.append(extra)
		var member: Dictionary=family.members[index]
		member.name=["Alex","Robin","June","Morgan","Kit","Sam","Emery","A very long resident name"][index]
		member.autonomy=false; member.x=positions[index].x; member.y=positions[index].y
		assert(session.world._walkable(session.state.lots[family.home_lot],positions[index]),"Crowd review uses clear floor, never walls or furnishing footprints")
		member.character=Character.of(member).duplicate(true)
		member.character.age=2 if index in [2,4] else 6 if index==7 else 5
		for need: String in member.needs: member.needs[need]=100.0
		member.needs.hunger=14.0
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	game.selected_member=str(family.members[7].id)
	session.state.day_minutes=720
	await _review("day")
	assert(view.resident_labels.size()==8,"The ordinary crowded home has space for all eight needs")
	session.state.day_minutes=0; await _review("night")
	root.size=Vector2i(1280,720); root.get_node("Preferences").set_value("ui_scale",1.25)
	await _review("compact-night")
	game._show_tray(game.plan_panel,true); await _review("compact-plan")
	game._show_tray(game.plan_panel,false)
	# Content selected residents still have an identity; other content residents
	# stay quiet. Selection changes do not issue an order.
	for member: Dictionary in family.members:
		for need: String in member.needs: member.needs[need]=100.0
	game.selected_member=str(family.members[2].id)
	root.get_node("Preferences").set_value("reduced_motion",true)
	session.state.day_minutes=720; await _review("compact-child")
	assert(view.resident_labels.size()==1 and view.resident_labels[game.selected_member].need=="")
	# Panning toward a tray must relocate a name without changing the camera or
	# leaving a clickable overlay behind the panel.
	view.pan+=Vector2(-200,0); await _review("compact-edge")
	view.pan=Vector2(10000,10000); await _settle(); assert(view.resident_labels.is_empty())
	view.pan=Vector2.ZERO; game._toggle_build(); await _settle(); assert(view.resident_labels.is_empty())
	game._toggle_build(); game.hud.hide(); await _settle(); assert(view.resident_labels.is_empty())
	# A bounded search can escape a tall body and a wide HUD where the old
	# seven candidates ran out. No space means no invisible click target.
	var occupied: Array[Rect2]=[Rect2(250,150,100,160),Rect2(0,350,640,130)]
	var fitted := Cues.fit(Rect2(250,230,180,30),Rect2(8,8,624,464),occupied,true)
	assert(fitted.has_area())
	for box: Rect2 in occupied: assert(not fitted.intersects(box))
	assert(not Cues.fit(Rect2(20,20,180,30),Rect2(8,8,624,464),[Rect2(0,0,640,480)],true).has_area())
	print("RESIDENT_LABELS_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
