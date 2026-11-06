extends RefCounted
## A real orthographic 3D camera with screen-space UI kept in the same tile frame.
const Scene3D = preload("res://game/lot_scene_3d.gd")
const GroundFeedback = preload("res://game/ground_feedback_3d.gd")
var feedback: Node3D
var viewport: SubViewport
var camera: Camera3D
var scene: Node3D
var surface: TextureRect
var view: Control
var picks: Array[Dictionary] = []

func setup(owner: Control) -> void:
	view=owner
	viewport=SubViewport.new()
	viewport.name="Neighborhood3D"
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.size=Vector2i(1440,900)
	view.add_child(viewport)
	scene=Scene3D.new(); viewport.add_child(scene)
	feedback=GroundFeedback.new(); feedback.name="GroundFeedback"; scene.add_child(feedback)
	camera=Camera3D.new(); camera.name="IsometricCamera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.1; camera.far=180.0
	viewport.add_child(camera); camera.current=true
	surface=TextureRect.new(); surface.name="World3DSurface"
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.texture=viewport.get_texture()
	surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	surface.show_behind_parent=true
	view.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	update_camera()

func update_camera() -> void:
	if camera==null or view.size.x<1 or view.size.y<1: return
	viewport.size=Vector2i(view.size)
	var pixels_per_meter: float=view._cell.x/sqrt(2.0)
	camera.size=view.size.y/pixels_per_meter
	camera.position=Vector3(30.0,24.49489743,30.0)
	camera.look_at(Vector3.ZERO)
	camera.position+=camera.basis.x*(view.size.x*0.5-view._origin.x)/pixels_per_meter
	camera.position+=camera.basis.y*(view._origin.y-view.size.y*0.5)/pixels_per_meter
	# Orthographic directional shadows use the camera's far plane. The old 180m
	# volume wasted shadow texels behind this small lot. Cover the visible ground
	# down to the terrain minimum, plus a margin, including zoom/pan/resize.
	var level := int(view.world.get("lots",{}).get(view.lot_id,{}).get("level",0))
	var terrain_y := -1.0-level*Scene3D.Storeys.HEIGHT
	var farthest := 0.0
	for corner: Vector2 in [Vector2.ZERO,Vector2(view.size.x,0),view.size,Vector2(0,view.size.y)]:
		var ray := camera.project_ray_origin(corner)
		var direction := camera.project_ray_normal(corner)
		var ground := ray+direction*((terrain_y-ray.y)/direction.y)
		farthest=maxf(farthest,-camera.to_local(ground).z)
	# Whole eight-metre steps avoid refitting the shadow map for every pan pixel.
	camera.far=maxf(64.0,ceilf((farthest+8.0)/8.0)*8.0)
	viewport.msaa_3d=Viewport.MSAA_4X if Preferences.values.get("quality","high")=="high" else Viewport.MSAA_DISABLED

func sync(delta: float) -> void:
	update_camera()
	scene.sync(view,delta)

func project(point: Vector3) -> Vector2:
	return camera.unproject_position(point)

func ground_at(point: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var ground := origin-direction*(origin.y/direction.y)
	for iteration in range(5):
		var height := Scene3D.ground_height(view.world.get("lots",{}).get(view.lot_id,{}),Vector2(ground.x,ground.z))
		ground=origin+direction*((height-origin.y)/direction.y)
	return Vector2(ground.x,ground.z)

func _meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.visible and node.mesh!=null: result.append(node)
	for child in node.get_children(): _meshes(child,result)

func _polygon(box: AABB, transform: Transform3D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(8): points.append(project(transform*box.get_endpoint(index)))
	return Geometry2D.convex_hull(points)

func register_targets() -> Array[Dictionary]:
	picks.clear()
	var regions: Array[Dictionary]=[]
	for node: Node3D in scene.pick_nodes:
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		var target: Dictionary=node.get_meta("target",{})
		if view.building and target.get("type")=="member": continue
		if target.get("type")=="wall" and (not view.building or view.build_kind not in ["finish_wall","door","erase","window","wall_art"]): continue
		if target.get("type")=="wall_art" and view.building and view.build_kind!="wall_art": target={"type":"wall","x":target.x,"y":target.y}
		var pieces: Array[Dictionary]=[]
		if node.has_meta("pick_parts"):
			for box: AABB in node.get_meta("pick_parts"):
				pieces.append({"box":box,"transform":node.global_transform})
		else:
			var meshes: Array[MeshInstance3D]=[]
			_meshes(node,meshes)
			for mesh: MeshInstance3D in meshes:
				if not mesh.mesh.has_meta("pick_triangles"):
					mesh.mesh.set_meta("pick_triangles",mesh.mesh.generate_triangle_mesh())
				pieces.append({"box":mesh.get_aabb(),"transform":mesh.global_transform,"triangles":mesh.mesh.get_meta("pick_triangles")})
		for piece: Dictionary in pieces:
			var polygon := _polygon(piece.box,piece.transform)
			if polygon.size()<3: continue
			var depth: float=camera.global_position.distance_squared_to(piece.transform*piece.box.get_center())
			regions.append({"polygon":polygon,"target":target,"geometry":true,"depth":depth})
			picks.append({"box":piece.box,"transform":piece.transform,"polygon":polygon,"target":target,"triangles":piece.get("triangles")})
	view.window_regions.clear(); view.art_regions.clear()
	for key: String in scene.window_nodes:
		var window: Node3D=scene.window_nodes[key]
		var box: AABB=Scene3D.bounds(window)
		view.window_regions[key]={"polygon":_polygon(box,Transform3D.IDENTITY),"cutaway":window.get_meta("cutaway",false),"style":window.get_meta("style",""),"preview":window.get_meta("preview",false),"along_x":window.get_meta("along_x",true)}
	for node: Node3D in scene.pick_nodes:
		var target: Dictionary=node.get_meta("target",{})
		if target.get("type")!="wall_art": continue
		view.art_regions[str(target.id)]={"polygon":_polygon(Scene3D.bounds(node),Transform3D.IDENTITY),"x":target.x,"y":target.y,"along_x":preload("res://game/windows.gd").along_x(view.world.lots[view.lot_id],int(target.x),int(target.y))}
	regions.sort_custom(func(a,b): return a.depth>b.depth)
	return regions

func hit(point: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var closest := INF
	var target := {}
	for pick: Dictionary in picks:
		if not Geometry2D.is_point_in_polygon(point,pick.polygon): continue
		var inverse: Transform3D=pick.transform.affine_inverse()
		var intersection: Variant=pick.box.intersects_ray(inverse*origin,inverse.basis*direction)
		if intersection==null: continue
		if pick.triangles!=null:
			var face: Dictionary=pick.triangles.intersect_ray(inverse*origin,(inverse.basis*direction).normalized())
			if face.is_empty(): continue
			intersection=face.position
		var distance := origin.distance_squared_to(pick.transform*intersection)
		if distance<closest: closest=distance; target=pick.target
	return target
