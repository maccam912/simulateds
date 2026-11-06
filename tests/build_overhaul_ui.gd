extends SceneTree
var game: Control
var view: Control
var session: Node
var lot: Dictionary
var last_pointer := Vector2.ZERO

func _initialize() -> void: call_deferred("_run")
func settle(frames: int=5) -> void:
	for frame in range(frames): await process_frame
func edit(command: Dictionary) -> void:
	command.lot_id="lot_1"; command.revision=lot.revision
	var result: Dictionary=session.world.apply_command(session.profile_id,command)
	assert(result.ok,str([command,result])); game._refresh()
func capture(name: String) -> void:
	await settle(8)
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/overhaul-"+name+".png")==OK)
func mouse(at: Vector2,button: int,pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.position=at; event.global_position=at; event.button_index=button; event.pressed=pressed
	event.button_mask=(MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	root.push_input(event,true); await process_frame
func motion(at: Vector2,mask: int=0) -> void:
	root.warp_mouse(at)
	var event := InputEventMouseMotion.new(); event.position=at; event.global_position=at; event.button_mask=mask; event.relative=at-last_pointer; last_pointer=at
	root.push_input(event,true); await process_frame
func _run() -> void:
	root.size=Vector2i(1440,900)
	root.get_node("Preferences").reset_defaults(); root.get_node("Preferences").set_value("reduced_motion",true)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	lot=session.state.lots.lot_1
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await settle()
	game._toggle_build(); await settle()
	assert(not view.projection.picks.any(func(pick): return pick.target.get("type")=="member"),"Paused residents cannot intercept building clicks")
	edit({"type":"place","kind":"floor_lamp","x":9,"y":7})
	edit({"type":"place","kind":"globe_lamp","x":6,"y":10})
	edit({"type":"place","kind":"garden_lantern","x":13,"y":12})
	edit({"type":"place","kind":"armchair","x":9,"y":9})
	edit({"type":"place","kind":"hedge","x":14,"y":8})
	edit({"type":"place","kind":"flowers","x":14,"y":9})
	edit({"type":"landscape","kind":"pool","x":0,"y":10,"end_x":1,"end_y":13})
	edit({"type":"landscape","kind":"terrain_raise","x":13,"y":0,"end_x":14,"end_y":1,"radius":2})
	edit({"type":"landscape","kind":"terrain_sand","x":13,"y":0,"end_x":14,"end_y":1,"radius":2})
	edit({"type":"landscape","kind":"diagonal_wall","x":0,"y":0,"end_x":2,"end_y":2})
	edit({"type":"paint","surface":"wall","finish":"sage_stripe","x":3,"y":3,"end_x":12,"end_y":3})
	game._catalog_category="seating"; game._select_build_tool("move"); game._show_tray(game.context_panel,true)
	await settle(180)
	assert(game.catalog_buttons.has("sofa") and game.catalog_buttons.has("armchair") and game.catalog_buttons.size()==6)
	if DisplayServer.get_name()!="headless": assert(game.catalog_thumbnails.cache.has("armchair"))
	await capture("shopping-day")
	assert(view.projection.scene.furnishing_lights.size()==4)
	assert(view.projection.scene.daylight_windows.size()==3)
	# Pointer drag rotation changes only the pending furnishing until placement.
	game._select_build_tool("wood_chair"); await settle()
	var at: Vector2=view.grid_point(7.5,9.5)
	await motion(at); await mouse(at,MOUSE_BUTTON_RIGHT,true)
	await motion(at+Vector2(90,0),MOUSE_BUTTON_MASK_RIGHT)
	await mouse(at+Vector2(90,0),MOUSE_BUTTON_RIGHT,false)
	assert(game.build_rotation==2,"Right drag rotates two quarter turns")
	await motion(at); await mouse(at,MOUSE_BUTTON_LEFT,true); await mouse(at,MOUSE_BUTTON_LEFT,false)
	assert(session.world._object_at(lot,Vector2i(7,9)).get("rotation")==2)
	# Actual catalog drag/drop and furniture pickup preserve one purchase and ID.
	game._catalog_category="seating"; game._select_build_tool("move"); await settle()
	var card: Control=game.catalog_buttons.armchair
	var origin := card.get_global_rect().get_center()
	var drop: Vector2=view.grid_point(6.5,7.5)
	var count: int=lot.objects.size()
	await motion(origin); await mouse(origin,MOUSE_BUTTON_LEFT,true)
	await motion(origin+Vector2(-25,0),MOUSE_BUTTON_MASK_LEFT); await settle()
	assert(root.gui_is_dragging(),"Pointer motion starts native catalog dragging")
	await motion(drop,MOUSE_BUTTON_MASK_LEFT)
	await mouse(drop,MOUSE_BUTTON_LEFT,false); await settle()
	# The headless display has no OS cursor for Godot's native drop hit-test.
	# Native runs above use the actual cursor; headless checks the same drop handler.
	if DisplayServer.get_name()=="headless": view._drop_data(drop,{"build_catalog_kind":"armchair"}); await settle()
	var purchased: Dictionary=session.world._object_at(lot,Vector2i(6,7))
	assert(lot.objects.size()==count+1 and purchased.get("kind")=="armchair","Dragging the furniture photo buys at the drop location")
	game._select_build_tool("move"); await settle()
	var pick: Vector2=view.grid_point(6.5,7.5)-Vector2(0,20)
	assert(view.hit_target(pick).get("id")==purchased.id,"Pick the chair's visible geometry")
	var destination: Vector2=view.grid_point(6.5,9.5)
	await motion(pick); await mouse(pick,MOUSE_BUTTON_LEFT,true)
	await motion(destination,MOUSE_BUTTON_MASK_LEFT); await mouse(destination,MOUSE_BUTTON_LEFT,false); await settle()
	assert(purchased.x==6 and purchased.y==9 and lot.objects.size()==count+1,"Dragging a placed furnishing moves its existing identity")
	await motion(Vector2(30,400))
	session.state.day_minutes=0; game._catalog_category="lighting"; game._refresh()
	await settle(100); await capture("lighting-night")
	for light: OmniLight3D in view.projection.scene.furnishing_lights: assert(light.shadow_enabled and light.light_energy>0)
	session.state.day_minutes=720; game._select_build_tool("window"); await capture("windows-daylight")
	root.size=Vector2i(1280,720); game._select_build_tool("finish_wall")
	await capture("wallpaper-compact")
	# Upper-storey editing shares the budget and history while drawing a new floor.
	edit({"type":"place","kind":"stairs","x":9,"y":4,"rotation":0})
	edit({"type":"place_area","level":1,"kind":"floor","x":4,"y":3,"end_x":10,"end_y":9})
	edit({"type":"place","level":1,"kind":"loveseat","x":5,"y":5})
	edit({"type":"place","level":1,"kind":"floor_lamp","x":8,"y":5})
	game._set_view_level(1); game._catalog_category="seating"; game._select_build_tool("move")
	assert(view.world.lots.lot_1.objects.size()==2 and game._view_lot().objects.size()==2)
	session.state.day_minutes=720; await capture("upstairs-compact")
	var snapshot: Dictionary=session.world.snapshot(); await settle(20)
	assert(session.world.snapshot()==snapshot,"Thumbnails, floors, light and previews cannot mutate the world")
	# Native model review uses the actual game camera and renderer, including all
	# new meshes together at daylight, night and the compact window size.
	lot.objects=[]; lot.walls=[]; lot.doors=[]; lot.windows={}; lot.diagonal_walls={}; lot.storeys={}; lot.floors=[]
	lot.finishes=preload("res://game/finishes.gd").create(); lot.landscape=preload("res://game/landscaping.gd").empty()
	for y in range(2,14):
		for x in range(2,13): lot.floors.append([x,y])
	for entry: Array in [["armchair",3,3],["loveseat",5,3],["long_sofa",8,3],["wood_chair",3,6],["garden_bench",0,8],["floor_lamp",5,6],["arc_lamp",7,6],["globe_lamp",9,6],["pendant_lamp",11,6],["garden_lantern",13,6],["lamp_post",14,9],["linden_tree",0,0],["hedge",0,4],["flowers",1,6],["picket_fence",13,2],["boulder",13,12],["stairs",10,9]]:
		lot.objects.append(session.world._new_object(entry[0],entry[1],entry[2],0))
	lot.revision+=1; game._set_view_level(0); game._catalog_category="garden"; game._select_build_tool("move")
	root.size=Vector2i(1440,900); session.state.day_minutes=720; game._refresh(); await capture("models-day")
	session.state.day_minutes=0; game._refresh(); await capture("models-night")
	root.size=Vector2i(1280,720); session.state.day_minutes=720; game._refresh(); await capture("models-compact")
	print("BUILD_OVERHAUL_UI_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
