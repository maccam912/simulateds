extends SceneTree
var session: Node
var game: Control

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String, minutes: float) -> Image:
	session.state.day_minutes=minutes
	game._refresh()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(picture.save_png("res://build/daylight-"+name+".png")==OK)
	return picture

func _run() -> void:
	root.size=Vector2i(1440,900)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex")
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://build")
	var night: Image=await _capture("night",0)
	await _capture("dawn",390)
	var noon: Image=await _capture("noon",720)
	await _capture("evening",1110)
	var floor_point := Vector2i(game.lot_view.grid_point(9.25,8.75))
	var lawn_point := Vector2i(game.lot_view.grid_point(14.5,12.5))
	assert(night.get_pixelv(floor_point).get_luminance()>night.get_pixelv(lawn_point).get_luminance()*1.6,"Home stays readable against the night lawn")
	assert(night.get_pixelv(lawn_point).get_luminance()<noon.get_pixelv(lawn_point).get_luminance()*0.65,"Street and lawn actually darken")
	var hud_point := Vector2i(game.mode_button.global_position+Vector2(18,12))
	assert(night.get_pixelv(hud_point)==noon.get_pixelv(hud_point),"Lighting does not darken HUD controls")
	game._toggle_build()
	await _capture("construction-night",0)
	root.get_node("Preferences").set_value("quality","low")
	root.get_node("Preferences").set_value("ui_scale",1.25)
	root.size=Vector2i(1280,720)
	await _capture("construction-compact",0)
	assert(game.tools_box.get_parent().size.y>=80)
	print("DAYLIGHT_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait()
	quit()
