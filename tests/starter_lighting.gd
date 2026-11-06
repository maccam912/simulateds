extends SceneTree
## Starter layout, fixture lifecycle, save compatibility and matched native review.
const World = preload("res://game/world.gd")
var session: Node
var game: Control
var view: Control
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _settle() -> void:
	for frame in range(4): await process_frame

func _capture(label: String) -> void:
	await _settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/starter-light-"+label+suffix+".png")==OK)

func _edit(command: Dictionary) -> void:
	command.lot_id="lot_1"; command.revision=session.state.lots.lot_1.revision
	var result: Dictionary=session.world.apply_command(session.profile_id,command)
	assert(result.ok,result.message)
	game._refresh()
	await _settle()

func _shade(model: Node3D) -> StandardMaterial3D:
	for mesh: MeshInstance3D in view.projection.scene._meshes(model):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source==null or source.resource_name!="custom_lamp_shade": continue
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			assert(material!=source and not source.emission_enabled,"Shared imported materials stay unchanged")
			assert(material.emission_enabled and material.emission==material.albedo_color,"The lit shade retains its fabric hue")
			return material
	assert(false,"The real lamp includes a linen shade")
	return null

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	var prefs := root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	if compact: prefs.set_value("ui_scale",1.25); suffix="-compact"
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for lot: Dictionary in session.state.lots.values():
		assert(lot.funds==12000 and session.world.build_access(lot).ok,"Starter furnishings keep the budget and every care activity reachable")
		assert(lot.objects.filter(func(item): return item.kind=="floor_lamp").size()==1)
	var home: Dictionary=session.state.lots.lot_1
	var lamp: Dictionary=home.objects.filter(func(item): return item.kind=="floor_lamp")[0]
	var original: Dictionary=session.world.snapshot_for_save()
	var restored := World.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(original))))
	assert(restored.state.lots.lot_1.objects==home.objects,"A saved lamp keeps its identity and location")
	# Old saves and deliberately removed lamps are never refurnished on load.
	var legacy: Dictionary=original.duplicate(true)
	for lot: Dictionary in legacy.lots.values():
		lot.objects=lot.objects.filter(func(item): return item.kind!="floor_lamp")
	assert(restored.restore(JSON.parse_string(JSON.stringify(legacy))))
	for id: String in legacy.lots:
		assert(restored.state.lots[id].objects==legacy.lots[id].objects)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _settle()
	_shade(view.projection.scene.object_nodes[lamp.id])
	for sample: Array in [[720,"day"],[1080,"dusk"],[0,"night"]]:
		session.state.day_minutes=sample[0]; game._refresh(); await _settle()
		var before: Dictionary=session.world.snapshot()
		var fixture: OmniLight3D=view.projection.scene.object_nodes[lamp.id].get_node("Light")
		assert(fixture.shadow_enabled and fixture.light_energy>0 and fixture.global_position.distance_to(Vector3(lamp.x+0.5,1.49,lamp.y+0.5))<0.01)
		fixture.visible=false; await _capture("unlit-"+sample[1])
		fixture.visible=true; await _capture("lit-"+sample[1])
		assert(session.world.snapshot()==before,"Lighting and native review never alter clock, paths, money or saves")
	prefs.set_value("quality","low"); await _capture("night-low")
	assert(view.projection.scene.furnishing_lights.size()==1,"Low scenery retains the actual indoor fixture")
	# The light follows ordinary accepted edits, with no stale illumination.
	await _edit({"type":"build_begin"})
	for style: String in preload("res://game/furniture_colors.gd").PALETTE:
		if style!="original": await _edit({"type":"recolor","object_id":lamp.id,"style":style})
		_shade(view.projection.scene.object_nodes[lamp.id])
		await _capture("shade-"+style)
	await _edit({"type":"move_object","object_id":lamp.id,"x":6,"y":10,"rotation":1})
	var moved: Node3D=view.projection.scene.object_nodes[lamp.id]
	assert(moved.get_node("Light").global_position.distance_to(Vector3(6.5,1.49,10.5))<0.01)
	await _capture("moved")
	await _edit({"type":"erase","x":6,"y":10})
	assert(view.projection.scene.furnishing_lights.is_empty() and not view.projection.scene.object_nodes.has(lamp.id))
	await _edit({"type":"build_undo"})
	assert(view.projection.scene.furnishing_lights.size()==1)
	await _edit({"type":"build_cancel"})
	assert(home.objects==original.lots.lot_1.objects and home.funds==12000)
	print("STARTER_LIGHTING_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
