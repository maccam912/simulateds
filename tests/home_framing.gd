extends SceneTree

var game: Control
var view: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame; await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/home-framing-"+label+suffix+".png")==OK)

func _click(button: Button) -> void:
	await process_frame
	assert(root.get_visible_rect().encloses(button.get_global_rect()))
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	var prefs := root.get_node("Preferences"); prefs.reset_defaults()
	if compact: prefs.set_value("ui_scale",1.25); suffix="-compact"
	prefs.set_value("reduced_motion",true)
	session=root.get_node("Session"); session.menu_paused=true; session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	session.world.ensure_family("neighbor","Violet")
	session.world.set_online(session.profile_id,true)
	session.solo_view={}; session.solo_view_generation=session.world_generation
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await process_frame; await process_frame
	print("HOME_FRAMING_VIEWPORT ",root.size," logical ",root.get_visible_rect().size," scale ",root.content_scale_factor)
	var before: Dictionary=session.world.snapshot()
	assert(view.zoom>1.05,"Fresh house framing improves on the old fixed overview")
	assert(view.overview_rect().grow(1).encloses(view.house_bounds()),"House envelope fits between the fixed HUD rows")
	var initial: Dictionary=view.saved_framing()
	game._refresh(); await process_frame
	assert(view.saved_framing()==initial,"Snapshots cannot continuously refit the camera")
	game._home_overview()
	assert(session.world.snapshot()==before,"Initial framing and explicit overview are read-only")
	for sample: Array in [[720,"day"],[1080,"dusk"],[0,"night"]]:
		session.state.day_minutes=sample[0]
		game._refresh()
		view.center_lot(); await _capture("before-"+sample[1])
		game._home_overview(); await _capture("after-"+sample[1])
	# Manual framing is retained exactly by ordinary refresh and save restoration.
	view.zoom=1.7; view.pan=Vector2(53,-21); view._layout()
	var manual: Dictionary=view.saved_framing()
	game._refresh(); assert(view.saved_framing()==manual)
	session.solo_view=game._capture_solo_view()
	game._home_overview(); game._applied_solo_view=-1; game._refresh()
	assert(view.pan.distance_to(Vector2(53,-21))<0.01 and is_equal_approx(view.zoom,1.7))
	# Home is a camera action even when the selected resident is visiting upstairs.
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	member.lot_id="lot_2"; member.level=1
	session.state.lots.lot_2.storeys["1"]=preload("res://game/storeys.gd").empty()
	game._find_resident(); assert(game.viewed_lot=="lot_2" and game.view_level==1 and view.zoom==1.7)
	before=session.world.snapshot()
	await _click(game.more_button); await _capture("overview-menu")
	await _click(game.overview_button)
	assert(game.viewed_lot==session.state.families[session.profile_id].home_lot and game.view_level==0)
	assert(game.selected_member==member.id and not game.more_panel.visible)
	assert(session.world.snapshot()==before,"Overview cannot change positions, paths, tasks, funds, clock or saves")
	var fitted_zoom: float=view.zoom
	game._find_resident(); assert(game.viewed_lot=="lot_2" and game.view_level==1 and view.zoom==fitted_zoom)
	assert(view.resident_anchor(member).distance_to(view.camera_focus_point())<0.1)
	game._home_overview()
	# Fit off-center and full-lot homes from accepted geometry, not a starter constant.
	var home: Dictionary=session.state.lots[game.viewed_lot]
	for cells: Array in [[[1,1],[1,4],[4,1],[4,4]],[[0,0],[0,15],[15,0],[15,15]]]:
		home.floors=cells; home.walls=[]; home.doors=[]; home.objects=[]
		game._refresh(); game._home_overview()
		assert(view.overview_rect().grow(1).encloses(view.house_bounds()))
		assert(view.house_bounds().get_center().distance_to(view.overview_rect().get_center())<0.1)
		var point: Vector2=view.grid_point(4.5,4.5)
		assert(view.cell_at(point)==Vector2i(4,4),"Ground picking tracks the fitted camera")
	home.floors=[]; game._refresh(); game._home_overview()
	assert(view.zoom==1.0 and view.pan==Vector2.ZERO,"An empty home keeps the whole-lot fallback")
	print("HOME_FRAMING_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
