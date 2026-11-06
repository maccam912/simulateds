extends SceneTree
## Matched storeys expose floor edges, lower shells and daylight shadow seams.
const Storeys = preload("res://game/storeys.gd")
var game: Control
var session: Node
var suffix := ""
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for frame in range(12): await process_frame
func capture(label: String) -> void:
	await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/floor-wall-"+label+suffix+".png")==OK)
func floor_at(point: Vector2) -> bool:
	if DisplayServer.get_name()=="headless":
		# The dummy rendering server discards MultiMesh instance transforms.
		# Check authored bounds here; native runs below check emitted instances.
		var layer: Dictionary=game._view_lot()
		var cells := {}
		for cell: Array in layer.floors: cells[Vector2i(cell[0],cell[1])]=true
		for at: Vector2i in cells:
			if [at.x,at.y] in layer.get("stairwells",[]): continue
			if game.lot_view.projection.scene._floor_bounds(layer,at,cells).has_point(point): return true
		return false
	# Probe the actual rendered box instances, including the finish and substrate.
	var batch: MultiMeshInstance3D=game.lot_view.projection.scene.architecture.get_node("BatchedArchitecture")
	for index in range(batch.multimesh.instance_count):
		var bounds: AABB=batch.multimesh.get_instance_transform(index)*AABB(-batch.multimesh.mesh.size*0.5,batch.multimesh.mesh.size)
		if bounds.has_point(Vector3(point.x,0.025,point.y)): return true
	return false
func check_geometry(level: int) -> void:
	for point: Vector2 in [Vector2(3.39,7.5),Vector2(12.61,7.5),Vector2(7.5,3.39),Vector2(7.5,11.61),Vector2(3.39,3.39),Vector2(12.61,11.61)]:
		assert(floor_at(point),"Floor reaches every exterior wall face and corner: "+str(point))
	for point: Vector2 in [Vector2(3.2,7.5),Vector2(12.8,7.5),Vector2(7.5,3.2),Vector2(7.5,11.8)]:
		assert(not floor_at(point),"Interior flooring must not form an exterior ledge: "+str(point))
	var scene: Node3D=game.lot_view.projection.scene
	var covered := false
	for mesh: MeshInstance3D in scene._meshes(scene.architecture):
		if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if not mesh.mesh is BoxMesh: continue
		var bounds: AABB=mesh.transform*AABB(-mesh.mesh.size*0.5,mesh.mesh.size)
		if bounds.position.y>=2.09 and bounds.position.y<=2.135 and bounds.has_point(Vector3(3.5,2.125,3.5)): covered=true
	assert(covered,"Ceiling shadow closes the wall corner at wall-top height")
	if level==0: return
	var supports := false
	for mesh: MeshInstance3D in scene._meshes(scene.lower_floors):
		if not mesh.mesh is BoxMesh: continue
		var bounds: AABB=mesh.global_transform*AABB(-mesh.mesh.size*0.5,mesh.mesh.size)
		if bounds.has_point(Vector3(12.5,-0.053,7.5)): supports=true
	assert(supports,"Lower wall meets upper slab underside without a horizontal gap")
func check_open_edges() -> void:
	var scene: Node3D=game.lot_view.projection.scene
	var layer := Storeys.empty()
	layer.floors=[[3,3],[4,3],[5,3]]; layer.walls=[[3,3],[4,3]]
	var floors := {Vector2i(3,3):true,Vector2i(4,3):true,Vector2i(5,3):true}
	assert(scene._floor_bounds(layer,Vector2i(5,3),floors)==Rect2(5,3,1,1),"Open decks keep their full tile")
	assert(scene._floor_bounds(layer,Vector2i(3,3),floors)==Rect2(3,3,1,1),"A wall end retains support beneath its full length")
	layer.diagonal_walls={"3,3":45}
	assert(scene._floor_bounds(layer,Vector2i(3,3),floors)==Rect2(3,3,1,1),"Diagonal walls retain their supporting tile")
func _run() -> void:
	root.size=Vector2i(1440,900)
	var prefs: Node=root.get_node("Preferences"); prefs.reset_defaults(); prefs.set_value("reduced_motion",true)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	for member: Dictionary in session.state.families[session.profile_id].members: member.autonomy=false
	var lot: Dictionary=session.state.lots.lot_1
	# Deliberately identical architecture makes floor-to-floor comparisons meaningful.
	var upper := Storeys.empty()
	for field: String in Storeys.FIELDS: upper[field]=lot[field].duplicate(true)
	upper.objects=[]; upper.artworks={}
	lot.storeys={"1":upper}
	game=load("res://game/main.tscn").instantiate(); root.add_child(game)
	await settle()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-tag="): suffix="-"+arg.trim_prefix("--capture-tag=")
	for level in [0,1]:
		game._set_view_level(level)
		for minutes in [720,0]:
			session.state.day_minutes=minutes; game._refresh()
			var before: Dictionary=session.world.snapshot()
			await capture("floor%d-%s" % [level+1,"day" if minutes==720 else "night"])
			check_geometry(level)
			assert(before==session.world.snapshot(),"Presentation cannot mutate world state")
	check_open_edges()
	root.size=Vector2i(1280,720); prefs.set_value("ui_scale",1.25)
	session.state.day_minutes=720; game._refresh(); await capture("floor2-compact")
	# A real accepted stair placement must keep the second-floor opening clear.
	game._toggle_build()
	var result: Dictionary=session.world.apply_command(session.profile_id,{"type":"place","kind":"stairs","lot_id":lot.id,"revision":lot.revision,"x":8,"y":4,"level":0})
	assert(result.ok,str(result)); game._set_view_level(1); game._refresh(); await settle()
	for point: Vector2 in [Vector2(8.5,4.5),Vector2(8.5,5.5),Vector2(8.5,6.5)]:
		assert(not floor_at(point),"Trimming floors cannot fill the stair opening")
	game._show_tray(game.context_panel,false); await capture("floor2-stairs")
	print("FLOOR_WALL_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
