extends Node3D
## Read-only presentation of the authoritative tile simulation in world space.
## One tile is one metre. Model origins are centered, Y is up, and +Z is front.
const Catalog = preload("res://game/catalog.gd")
const Finishes = preload("res://game/finishes.gd")
const Windows = preload("res://game/windows.gd")
const FurnitureColors = preload("res://game/furniture_colors.gd")
const Character = preload("res://game/character_profile.gd")
const CharacterModel = preload("res://game/character_model.gd")
var _character_model = CharacterModel.new()
const Appearance = preload("res://game/appearance.gd")
const Gardens = preload("res://game/gardens.gd")
const Storeys = preload("res://game/storeys.gd")
const Landscaping = preload("res://game/landscaping.gd")
const Daylight = preload("res://game/daylight.gd")

var object_nodes: Dictionary = {}
var resident_nodes: Dictionary = {}
var window_nodes: Dictionary = {}
var pick_nodes: Array[Node3D] = []
var lower_floors: Node3D
var architecture: Node3D
var neighborhood: Node3D
var residents: Node3D
var ghost: Node3D
var room_ghost: Node3D
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var environment: Environment
var home_light: OmniLight3D
var _lamps: Array[OmniLight3D] = []
var furnishing_lights: Array[OmniLight3D] = []
var daylight_windows: Array[SpotLight3D] = []
var _scenes: Dictionary = {}
var _missing: Dictionary = {}
var _materials: Dictionary = {}
var _paintings: Dictionary = {}
var _signature := ""
var _scenery_quality := ""
var _ghost_key := ""
var _room_ghost_key := ""
var _boxes: Array = []
var _object_state: Dictionary = {}

func _ready() -> void:
	_character_model.high_detail=false
	name = "LindenGrove3D"
	lower_floors=Node3D.new(); lower_floors.name="LowerStoreys"; add_child(lower_floors)
	architecture = Node3D.new(); architecture.name = "House"; add_child(architecture)
	neighborhood = Node3D.new(); neighborhood.name = "Neighborhood"; add_child(neighborhood)
	residents = Node3D.new(); residents.name = "Residents"; add_child(residents)
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("92ae80")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6d9e1")
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = environment; add_child(world_environment)
	sun = DirectionalLight3D.new(); sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-52,-32,0)
	sun.light_color = Color("fff1dc"); sun.light_energy = 0.68
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.8; sun.shadow_bias = 0.04; add_child(sun)
	fill = DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-38,140,0)
	fill.light_color = Color("c5d3df"); fill.light_energy = 0.12; add_child(fill)
	home_light = OmniLight3D.new(); home_light.position = Vector3(8,4,7)
	home_light.light_color = Color("ffe1aa"); home_light.omni_range = 12.0
	home_light.omni_attenuation = 0.65; add_child(home_light)

func sync(view: Control, _delta: float) -> void:
	if not is_node_ready(): return
	var quality := str(Preferences.values.get("quality","high"))
	if quality != _scenery_quality:
		_scenery_quality = quality; _build_neighborhood(quality == "high")
	var lot: Dictionary = view.world.get("lots",{}).get(view.lot_id,{})
	var full_walls: bool = view.building and view.build_kind in ["window","wall_art","wall","door","diagonal_wall","finish_wall"] and not view.access_inspecting
	var structure: Array = []
	for object: Dictionary in lot.get("objects",[]):
		structure.append([object.id,object.kind,object.x,object.y,object.rotation,object.get("color_style","original")])
	var signature := str([view.lot_id,lot.get("level",0),lot.get("storeys",{}),lot.get("floors",[]),lot.get("walls",[]),lot.get("doors",[]),lot.get("finishes",{}),lot.get("windows",{}),lot.get("artworks",{}),lot.get("landscape",{}),lot.get("diagonal_walls",{}),structure,full_walls,view._paint_cells,view._preview_finish,view.color_preview,view.art_preview,view.hover_cell if view.build_kind=="window" else Vector2i(-1,-1),view.window_style if view.build_kind=="window" else "",view.preview_result if view.build_kind=="window" else {}]).sha256_text()
	if signature != _signature:
		_signature = signature; _build_house(lot,full_walls,view)
		_build_lower_floors(view,lot)
	# Quantized visual state avoids rebuilding growing plants every frame, while
	# edits and changed meals remain immediately visible even when paused.
	for object: Dictionary in lot.get("objects",[]): _update_object(object)
	_update_residents(view)
	_update_ghost(view)
	_update_room_ghost(view)
	_update_light(view)

func _update_light(view: Control) -> void:
	var light := Daylight.sample(float(view.world.get("day_minutes",480)))
	var night := float(light.night)
	sun.light_energy = lerpf(0.68,0.11,night)
	sun.light_color = Color("fff1dc").lerp(Color("a5b9ed"),night)
	fill.light_energy = lerpf(0.12,0.07,night)
	environment.ambient_light_color = Color("d1dce3").lerp(Color("8198c5"),night)
	environment.ambient_light_energy = lerpf(0.38,0.29,night)
	home_light.light_energy = night * 0.18
	for lamp: OmniLight3D in furnishing_lights: lamp.light_energy=float(lamp.get_meta("energy",1.0))*(0.65+0.35*night)
	for window: SpotLight3D in daylight_windows: window.light_energy=(1.0-night)*1.0
	for lamp: OmniLight3D in _lamps: lamp.light_energy = night * 2.4

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child); child.queue_free()

func _model(kind: String) -> Node3D:
	var path := "res://assets/models/" + kind + ".glb"
	if not _scenes.has(kind):
		if not ResourceLoader.exists(path):
			if not _missing.has(kind): push_error("Missing 3D model: "+path+". Run git lfs pull and import the project."); _missing[kind]=true
			return Node3D.new()
		_scenes[kind] = load(path)
	return (_scenes[kind] as PackedScene).instantiate() as Node3D

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var key := color.to_html() + str(metallic)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color; material.roughness = 0.82; material.metallic = metallic
		_materials[key] = material
	return _materials[key]

func _box(parent: Node3D, position: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = dimensions
	instance.mesh = mesh; instance.position = position; instance.material_override = _material(color)
	parent.add_child(instance); return instance

func _batch_box(position: Vector3, dimensions: Vector3, color: Color) -> void:
	_boxes.append([Transform3D(Basis.from_scale(dimensions),position),color])

func _finish_boxes(parent: Node3D) -> void:
	if _boxes.is_empty(): return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true; material.roughness = 0.88
	var mesh := BoxMesh.new(); mesh.size = Vector3.ONE; mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D; multimesh.use_colors = true
	multimesh.mesh = mesh; multimesh.instance_count = _boxes.size()
	for index in _boxes.size():
		multimesh.set_instance_transform(index,_boxes[index][0])
		multimesh.set_instance_color(index,_boxes[index][1])
	var instance := MultiMeshInstance3D.new(); instance.multimesh = multimesh
	if parent==neighborhood: instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.name = "BatchedArchitecture"; parent.add_child(instance); _boxes.clear()

func _build_neighborhood(high: bool) -> void:
	_clear(neighborhood); _lamps.clear(); _boxes.clear()
	# Leave a real opening for the editable ground and pool excavation.
	for patch: Rect2 in [Rect2(-500,-500,500,1000),Rect2(16,-500,484,1000),Rect2(0,-500,16,500),Rect2(0,16,16,484)]:
		_batch_box(Vector3(patch.get_center().x,-0.09,patch.get_center().y),Vector3(patch.size.x,0.12,patch.size.y),Color("8ea873"))
	for stripe in range(-24,25):
		if stripe>=0 and stripe<=5: continue
		_batch_box(Vector3(stripe*3,-0.022,0),Vector3(3,0.015,140),Color("88a16d") if posmod(stripe,2)==0 else Color("8ca572"))
	_batch_box(Vector3(0,-0.005,16.66),Vector3(180,0.08,1.13),Color("c9c7b5"))
	_batch_box(Vector3(0,-0.014,19.15),Vector3(180,0.03,3.82),Color("6d7876"))
	_batch_box(Vector3(0,-0.005,21.62),Vector3(180,0.08,1.13),Color("c9c7b5"))
	for x in range(-65,66):
		_batch_box(Vector3(x,0.039,16.67),Vector3(0.014,0.004,1.12),Color("aaa99b"))
		_batch_box(Vector3(x,0.039,21.62),Vector3(0.014,0.004,1.12),Color("aaa99b"))
		if x%3==0: _batch_box(Vector3(x,0.006,19.15),Vector3(1.4,0.008,0.07),Color("d9d3b2"))
	for z in range(11,16):
		_batch_box(Vector3(8.5,0.015,z+0.5),Vector3(0.94,0.055,0.94),Color("c1c1aa"))
	_finish_boxes(neighborhood)
	for position: Vector2 in [Vector2(0.35,1),Vector2(0.35,3),Vector2(0.35,5),Vector2(0.35,7),Vector2(0.35,9),Vector2(0.35,11),Vector2(4,0.35),Vector2(7,0.35),Vector2(10,0.35),Vector2(13,0.35)]:
		var shrub := _model("shrub"); shrub.position = Vector3(position.x,0,position.y)
		shrub.rotation.y = float(position.x+position.y)*0.8; neighborhood.add_child(shrub)
	if high:
		for position: Vector2 in [Vector2(-3,2),Vector2(2,-3),Vector2(10,-4),Vector2(18,1),Vector2(-4,11),Vector2(21,-7),Vector2(-9,-5),Vector2(25,11)]:
			var tree := _model("tree_linden"); tree.position = Vector3(position.x,0,position.y)
			tree.rotation.y = position.x*0.9; tree.scale *= 0.88 + fposmod(position.x*0.13,0.3)
			neighborhood.add_child(tree)
		for position: Vector2 in [Vector2(-1,8),Vector2(15,2),Vector2(16,10),Vector2(3,-1),Vector2(12,-1)]:
			var flowers := _model("flower_patch"); flowers.position = Vector3(position.x,0,position.y); neighborhood.add_child(flowers)
	for x: float in [-2,18]:
		var lamp := _model("streetlamp"); lamp.position = Vector3(x,0.04,16.65); neighborhood.add_child(lamp)
		var pool := OmniLight3D.new(); pool.position = Vector3(x,2.7,16.65)
		pool.light_color = Color("ffdfa7"); pool.omni_range = 5.5; pool.omni_attenuation = 1.2
		neighborhood.add_child(pool); _lamps.append(pool)
	var mailbox := _model("mailbox"); mailbox.position = Vector3(9.8,0,15.5); neighborhood.add_child(mailbox)

func _wall_footprint(at: Vector2i, connected: Dictionary, along_x: bool, mounted: bool, width: float) -> Array[Rect2]:
	var half := width*0.5
	var left := connected.has(at+Vector2i.LEFT)
	var right := connected.has(at+Vector2i.RIGHT)
	var up := connected.has(at+Vector2i.UP)
	var down := connected.has(at+Vector2i.DOWN)
	if not (left or right) or not (up or down):
		var straight: Array[Rect2]=[Rect2(-0.5,-half,1.0,width) if along_x else Rect2(-half,-0.5,width,1.0)]
		return straight
	# Use one shared center and extend only toward adjoining walls. A mounted
	# window or picture still needs its original full-width supporting face.
	var start := -0.5 if left or (mounted and along_x) else -half
	var end := 0.5 if right or (mounted and along_x) else half
	var parts: Array[Rect2]=[Rect2(start,-half,end-start,width)]
	if up or (mounted and not along_x): parts.append(Rect2(-half,-0.5,width,0.5-half))
	if down or (mounted and not along_x): parts.append(Rect2(-half,half,width,0.5-half))
	return parts

func _wall_boxes(center: Vector3, parts: Array[Rect2], height: float, color: Color) -> void:
	for part: Rect2 in parts:
		var middle := part.get_center()
		_batch_box(center+Vector3(middle.x,0,middle.y),Vector3(part.size.x,height,part.size.y),color)

func _build_house(lot: Dictionary, full_walls: bool, view: Control) -> void:
	_clear(architecture); object_nodes.clear(); window_nodes.clear(); pick_nodes.clear(); _object_state.clear(); _boxes.clear(); furnishing_lights.clear(); daylight_windows.clear()
	if int(lot.get("level",0))==0: _build_ground(lot)
	var floors := {}
	for cell: Array in lot.get("floors",[]): floors[Vector2i(int(cell[0]),int(cell[1]))] = true
	for cell: Array in lot.get("floors",[]):
		if cell in lot.get("stairwells",[]): continue
		var x := int(cell[0]); var z := int(cell[1])
		var finish: Dictionary = Finishes.PALETTES.floor[view._surface_finish(lot,"floor",x,z)]
		var color := Color(finish.color)
		_batch_box(Vector3(x+0.5,-0.012,z+0.5),Vector3(1,0.08,1),color.darkened(0.19))
		if finish.pattern == "boards":
			for plank in range(4):
				var shade := color.lightened(float(posmod(x*17+z*7+plank*3,7)-3)*0.018)
				_batch_box(Vector3(x+0.125+plank*0.25,0.025,z+0.5),Vector3(0.244,0.012,0.992),shade)
		elif finish.pattern in ["tiles","checkers"]:
			for xx in range(2):
				for zz in range(2):
					var shade := color if finish.pattern=="tiles" or (xx+zz)%2==0 else Color("e6e0ca")
					_batch_box(Vector3(x+0.25+xx*0.5,0.025,z+0.25+zz*0.5),Vector3(0.488,0.012,0.488),shade)
		else: _batch_box(Vector3(x+0.5,0.025,z+0.5),Vector3(0.998,0.012,0.998),color)
	for cell: Array in lot.get("floors",[]):
		var at := Vector2i(int(cell[0]),int(cell[1]))
		if cell in lot.walls or cell in lot.doors or cell in lot.get("stairwells",[]): continue
		if not (floors.has(at+Vector2i.LEFT) and floors.has(at+Vector2i.RIGHT) and floors.has(at+Vector2i.UP) and floors.has(at+Vector2i.DOWN)): continue
		var roof := _box(architecture,Vector3(at.x+0.5,2.48,at.y+0.5),Vector3(1,0.05,1),Color("e4dac2"))
		roof.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var connected := {}
	for key: String in ["walls","doors"]:
		for cell: Array in lot.get(key,[]): connected[Vector2i(int(cell[0]),int(cell[1]))]=true
	var art_walls := {}
	for entry: Dictionary in lot.get("artworks",{}).values():
		if int(entry.x)>=0: art_walls[Vector2i(int(entry.x),int(entry.y))]=true
	if view.art_preview.get("ok",false): art_walls[Vector2i(int(view.art_preview.x),int(view.art_preview.y))]=true
	for cell: Array in lot.get("walls",[]):
		var x := int(cell[0]); var z := int(cell[1]); var at := Vector2i(x,z)
		var rear: bool = (floors.has(at+Vector2i.RIGHT) and not floors.has(at+Vector2i.LEFT)) or (floors.has(at+Vector2i.DOWN) and not floors.has(at+Vector2i.UP))
		var height := 2.1 if rear or full_walls else 0.28
		var along := Windows.along_x(lot,x,z)
		var window_style := Windows.at(lot,x,z)
		var previewing: bool = view.building and view.build_kind=="window" and not view.access_inspecting and not view.window_pending and view.hover_cell==at and view.preview_result.get("ok",false)
		if previewing: window_style=view.window_style
		var mounted := not window_style.is_empty() or art_walls.has(at)
		var body := _wall_footprint(at,connected,along,mounted,0.24)
		var trim := _wall_footprint(at,connected,along,mounted,0.265)
		var center := Vector3(x+0.5,0,z+0.5)
		var wall_finish: Dictionary=Finishes.PALETTES.wall[view._surface_finish(lot,"wall",x,z)]
		var color := Color(wall_finish.color)
		var diagonal := int(lot.get("diagonal_walls",{}).get("%d,%d" % [x,z],0))
		if diagonal!=0 and not window_style.is_empty() and height>1:
			along=true
			var mount := Node3D.new(); mount.position=center; mount.rotation.y=-diagonal*PI/4; architecture.add_child(mount)
			_window_wall(Vector3.ZERO,true,height,color,mount)
			for side in [-1,1]: _box(mount,Vector3(side*0.6035,height*0.5,0),Vector3(0.207,height,0.24),color)
		elif diagonal!=0:
			var part := _box(architecture,center+Vector3.UP*(height*0.5+0.035),Vector3(1.414,height,0.24),color)
			part.rotation.y=-diagonal*PI/4
		elif not window_style.is_empty() and height>1:
			_window_wall(center,along,height,color)
		else: _wall_boxes(center+Vector3.UP*(height*0.5+0.035),body,height,color)
		if diagonal==0: _wallpaper(center,body,height,wall_finish)
		if height<1:
			var shadow := Node3D.new(); architecture.add_child(shadow)
			if window_style.is_empty():
				for part: Rect2 in body:
					var middle := part.get_center()
					var blocker := _box(shadow,center+Vector3(middle.x,1.1,middle.y),Vector3(part.size.x,2.2,part.size.y),color)
					blocker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			else:
				_window_wall(center,along,2.1,color,shadow)
				for mesh: MeshInstance3D in _meshes(shadow): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if diagonal==0:
			_wall_boxes(center+Vector3.UP*0.11,trim,0.16,Color("f0e5ca"))
			_wall_boxes(center+Vector3.UP*(height+0.04),trim,0.06,color.lightened(0.11))
		else:
			var cap := _box(architecture,center+Vector3.UP*(height+0.04),Vector3(1.414,0.06,0.265),color.lightened(0.11)); cap.rotation.y=-diagonal*PI/4
			body=[Rect2(-0.707,-0.12,1.414,0.24)]
		var wall := Node3D.new(); wall.name = "Wall_%d_%d" % [x,z]; wall.position = center
		wall.set_meta("target",{"type":"wall","x":x,"y":z})
		if diagonal!=0: wall.rotation.y=-diagonal*PI/4
		var pick_parts: Array[AABB]=[]
		for part: Rect2 in body:
			pick_parts.append(AABB(Vector3(part.position.x,0,part.position.y),Vector3(part.size.x,height+0.08,part.size.y)))
		var bounds := pick_parts[0]
		for box: AABB in pick_parts: bounds=bounds.merge(box)
		wall.set_meta("pick_aabb",bounds)
		wall.set_meta("pick_parts",pick_parts)
		architecture.add_child(wall); pick_nodes.append(wall)
		if not window_style.is_empty():
			var window := _model("window_"+window_style)
			window.position = Vector3(0,0.035 if height>1 else 0.02,0.135)
			if not along: window.position = Vector3(0.135,0.035 if height>1 else 0.02,0); window.rotation.y = PI/2
			if height<1: window.scale.y=0.18
			window.set_meta("style",window_style); window.set_meta("cutaway",height<1); window.set_meta("preview",previewing); window.set_meta("along_x",along)
			wall.add_child(window)
			for mesh: MeshInstance3D in _meshes(window):
				for surface in mesh.mesh.get_surface_count():
					var source := mesh.get_active_material(surface) as StandardMaterial3D
					if source!=null and (source.resource_name.contains("glass") or source.resource_name.contains("reflection")):
						var glass := source.duplicate() as StandardMaterial3D
						glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; glass.albedo_color=Color(0.7,0.85,0.9,0.14)
						mesh.set_surface_override_material(surface,glass); mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var daylight := SpotLight3D.new(); daylight.name="WindowDaylight"
			var inward := Vector3(0,0,1) if along else Vector3(1,0,0)
			if diagonal!=0: inward=inward.rotated(Vector3.UP,-diagonal*PI/4)
			if not floors.has(at+Vector2i(roundi(inward.x),roundi(inward.z))): inward=-inward
			architecture.add_child(daylight); daylight.position=center+Vector3.UP*1.45+inward*0.18
			daylight.look_at(daylight.position+inward+Vector3.DOWN*0.35)
			daylight.light_color=Color("e3ecf7"); daylight.spot_range=5.5; daylight.spot_angle=53; daylight.shadow_enabled=true
			daylight_windows.append(daylight)
			window_nodes["%d,%d" % [x,z]]=window
	for cell: Array in lot.get("doors",[]):
		var x := int(cell[0]); var z := int(cell[1])
		_batch_box(Vector3(x+0.5,0.035,z+0.5),Vector3(1,0.05,1),Color("a48b69"))
		var frame := _model("door_frame"); frame.position = Vector3(x+0.5,0.04,z+0.5)
		if lot.get("diagonal_walls",{}).has("%d,%d" % [x,z]): frame.rotation.y=-int(lot.diagonal_walls["%d,%d" % [x,z]])*PI/4
		elif not Windows.along_x(lot,x,z): frame.rotation.y = PI/2
		# Doorways remain open and do not block the host's walkable threshold.
		architecture.add_child(frame)
	_finish_boxes(architecture)
	for object: Dictionary in lot.get("objects",[]):
		var model := _model(str(object.kind)); model.name = str(object.id)
		var dimensions := Catalog.footprint(str(object.kind),int(object.rotation))
		model.position = Vector3(float(object.x)+dimensions.x*0.5,0.04+ground_height(lot,Vector2(float(object.x)+dimensions.x*0.5,float(object.y)+dimensions.y*0.5)),float(object.y)+dimensions.y*0.5)
		model.rotation.y = -int(object.rotation)*PI/2
		model.set_meta("target",{"type":"object","id":object.id,"kind":object.kind,"x":object.x,"y":object.y,"rotation":object.rotation})
		architecture.add_child(model); object_nodes[str(object.id)] = model; pick_nodes.append(model)
		var drawn := object
		if view.color_preview.get("ok",false) and view.color_preview.object_id==object.id:
			drawn=object.duplicate(true); FurnitureColors.set_style(drawn,str(view.color_preview.style))
		_recolor(model,drawn)
		var illumination: Array=Catalog.ITEMS[object.kind].get("light",[])
		if not illumination.is_empty():
			for mesh: MeshInstance3D in _meshes(model): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var lamp := OmniLight3D.new(); lamp.name="Light"
			lamp.position=Vector3(0,float(illumination[0]),0); lamp.omni_range=float(illumination[1]); lamp.omni_attenuation=1.1
			lamp.light_color=Color(illumination[3]); lamp.shadow_enabled=true; lamp.shadow_bias=0.05
			lamp.set_meta("energy",float(illumination[2])); model.add_child(lamp); furnishing_lights.append(lamp)
		_update_object(object)
	for id: String in lot.get("artworks",{}):
		var entry: Dictionary = lot.artworks[id]
		if int(entry.x)<0: continue
		var art := Node3D.new(); art.name = id
		art.position = Vector3(float(entry.x)+0.5,1.12,float(entry.y)+0.64)
		if not Windows.along_x(lot,int(entry.x),int(entry.y)):
			art.position = Vector3(float(entry.x)+0.64,1.12,float(entry.y)+0.5); art.rotation.y = PI/2
		art.set_meta("target",{"type":"wall_art","id":id,"x":entry.x,"y":entry.y})
		architecture.add_child(art); pick_nodes.append(art)
		_box(art,Vector3.ZERO,Vector3(0.82,0.92,0.06),Color("9f7e58"))
		var canvas := _box(art,Vector3(0,0,0.035),Vector3(0.72,0.82,0.018),Color.WHITE)
		canvas.material_override = _painting_material(entry.picture)
	if view.art_preview.get("ok",false):
		var entry: Dictionary=view.art_preview
		var art := Node3D.new(); art.name="ArtPreview"
		art.position=Vector3(float(entry.x)+0.5,1.12,float(entry.y)+0.64)
		if not Windows.along_x(lot,int(entry.x),int(entry.y)):
			art.position=Vector3(float(entry.x)+0.64,1.12,float(entry.y)+0.5); art.rotation.y=PI/2
		architecture.add_child(art)
		_box(art,Vector3.ZERO,Vector3(0.82,0.92,0.06),Color("bad59c"))
		var canvas := _box(art,Vector3(0,0,0.035),Vector3(0.72,0.82,0.018),Color.WHITE)
		canvas.material_override=_painting_material(entry.picture)

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child: Node in node.get_children(): result.append_array(_meshes(child))
	return result

func _recolor(node: Node3D, object: Dictionary) -> void:
	var style := FurnitureColors.at(object)
	if style == "original": return
	for mesh: MeshInstance3D in _meshes(node):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null or not source.resource_name.begins_with("custom_"): continue
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_color = Color(FurnitureColors.PALETTE[style].color).lightened((source.albedo_color.get_luminance()-0.45)*0.32)
			mesh.set_surface_override_material(surface,material)

func _update_object(object: Dictionary) -> void:
	if not object_nodes.has(str(object.id)): return
	var model: Node3D = object_nodes[str(object.id)]
	var garden_state: Dictionary=object.get("garden",{})
	var painting_state: Dictionary=object.get("painting",{})
	var state := str([garden_state.get("crop",""),floorf(float(garden_state.get("growth",0))/5),float(garden_state.get("water",0))>0,object.get("meal",{}),painting_state.get("subject",""),floorf(float(painting_state.get("progress",0))/3)])
	if _object_state.get(str(object.id),"") == state: return
	_object_state[str(object.id)] = state
	var details := model.get_node_or_null("LiveDetails") as Node3D
	if details == null: details = Node3D.new(); details.name = "LiveDetails"; model.add_child(details)
	_clear(details)
	if object.kind == "garden_bed":
		var garden: Dictionary = object.get("garden",Gardens.create())
		for mesh: MeshInstance3D in _meshes(model):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface)
				if material != null and material.resource_name == "soil": mesh.set_surface_override_material(surface,_material(Color("624b36") if float(garden.water)>0 else Color("a38660")))
		if not str(garden.crop).is_empty():
			var growth := clampf(float(garden.growth)/float(Gardens.CROPS[garden.crop].seconds),0,1)
			for x in range(3):
				for z in range(2):
					var crop := _model("crop_"+str(garden.crop)); crop.position = Vector3(-0.62+x*0.62,0.36,-0.21+z*0.42)
					crop.scale = Vector3.ONE*lerpf(0.25,0.85,growth); details.add_child(crop)
					if not Gardens.ripe(garden):
						for mesh: MeshInstance3D in _meshes(crop):
							for surface in mesh.mesh.get_surface_count():
								var material := mesh.mesh.surface_get_material(surface)
								if material != null and material.resource_name == "fruit": mesh.set_surface_override_material(surface,_material(Color("9aaa5b")))
	elif object.kind == "dining_table":
		var meal: Dictionary = object.get("meal",{})
		var servings := int(meal.get("servings",0))
		if servings > 0:
			for portion in servings:
				var location := Vector3(-0.22+(portion%2)*0.4,0.86,-0.22+(portion/2)*0.4)
				_box(details,location,Vector3(0.31,0.035,0.27),Color("ede8d6"))
				if str(meal.get("recipe","")).contains("salad"):
					for leaf in range(5): _sphere(details,location+Vector3(sin(leaf*2)*0.075,0.045,cos(leaf*2)*0.07),Vector3(0.065,0.032,0.052),Color("6f9559"))
				else: _box(details,location+Vector3(0,0.04,0),Vector3(0.21,0.06,0.17),Color("d9b87d"))
	elif object.kind == "easel":
		for mesh: MeshInstance3D in _meshes(model):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface)
				if material != null and material.resource_name == "canvas": mesh.set_surface_override_material(surface,_painting_material(object.get("painting",{})))

func _sphere(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius = 1; mesh.height = 2; mesh.radial_segments = 12; mesh.rings = 6
	var instance := MeshInstance3D.new(); instance.mesh = mesh; instance.scale = size; instance.position = position
	instance.material_override = _material(color); parent.add_child(instance); return instance

func _painting_material(picture: Dictionary) -> StandardMaterial3D:
	var subject := str(picture.get("subject","")); var progress := float(picture.get("progress",0))/24.0
	var stage := 0 if progress<=0 else 1 if progress<0.25 else 2 if progress<0.55 else 3 if progress<1 else 4
	var key := subject+str(stage)
	if _paintings.has(key): return _paintings[key]
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for yy in range(128):
		for xx in range(128):
			var u := float(xx)/127; var v := float(yy)/127; var color := Color("f4e8ca")
			if stage>0 and not subject.is_empty() and u>0.04 and u<0.96 and v>0.04 and v<0.96:
				color = Color("b8d2c5") if subject=="meadow" else Color("b3c9d4") if subject=="harbor" else Color("d6b8ac")
				if stage>=2:
					if subject=="meadow":
						if Vector2(u-0.76,v-0.25).length()<0.12: color=Color("edd291")
						if v>0.55+sin(u*9)*0.09: color=Color("83a783")
						if stage>=3 and v>0.73+sin(u*7)*0.06: color=Color("587d68")
					elif subject=="harbor":
						if v>0.52: color=Color("698f9a")
						if Vector2(u-0.23,v-0.26).length()<0.09: color=Color("edcf9b")
						if stage>=3:
							if v>0.7 and v<0.81 and u>0.35+(v-0.7)*0.7 and u<0.79-(v-0.7)*0.7: color=Color("6e615d")
							if u>0.33 and u<0.55 and v>0.31+(0.55-u)*1.6 and v<0.66: color=Color("f3e7ca")
							if absf(u-0.58)<0.012 and v>0.28 and v<0.71: color=Color("66564d")
					else:
						if v>0.79: color=Color("ad8872")
						if v>0.52 and v<0.81 and absf(u-0.505)<0.155-(v-0.52)*0.2: color=Color("628b86")
						if stage>=3:
							for bloom in range(3):
								var center := Vector2(0.29+bloom*0.21,0.32-0.12*(bloom%2))
								if Vector2(u,v).distance_to(center)<0.105: color=Color("e2a17f") if bloom%2 else Color("e9cf8c")
								if Vector2(u,v).distance_to(center)<0.028: color=Color("8d7656")
			image.set_pixel(xx,yy,color)
	var material := StandardMaterial3D.new(); material.albedo_texture = ImageTexture.create_from_image(image); material.roughness = 1.0
	_paintings[key] = material; return material

func _update_residents(view: Control) -> void:
	var seen := {}
	for family: Dictionary in view.world.get("families",{}).values():
		for member: Dictionary in family.get("members",[]):
			if member.lot_id != view.lot_id: continue
			var id := str(member.id); seen[id] = true
			var look := Appearance.of(member); var look_key := str([look,member.get("character",{})])
			var resident: Node3D = resident_nodes.get(id)
			if resident != null and resident.get_meta("look","") != look_key:
				pick_nodes.erase(resident); resident.get_parent().remove_child(resident); resident.queue_free(); resident = null
			if resident == null:
				resident = Node3D.new(); resident.name = id; residents.add_child(resident)
				# Legacy appearance choices project through the same art direction without
				# adding a character profile to a save or changing authoritative state.
				var model: Node3D=_character_model.build(member)
				if Character.is_baby(member): resident.add_child(_character_model.bassinet())
				model.name = "Body"; resident.add_child(model)
				resident.set_meta("look",look_key)
				var ring := MeshInstance3D.new(); ring.name = "Selection"
				var torus := TorusMesh.new(); torus.inner_radius = 0.27; torus.outer_radius = 0.30; torus.rings = 32; torus.ring_segments = 6
				ring.mesh = torus; ring.material_override = _material(Color("f1d394")); ring.position.y = 0.035; ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				resident.add_child(ring); resident_nodes[id] = resident
			resident.set_meta("target",{"type":"member","id":id,"name":member.name,"owner":family.id})
			if not pick_nodes.has(resident): pick_nodes.append(resident)
			var display: Vector2 = view.motion.position(member)+Vector2(0.5,0.5)
			var pose: Dictionary = view._activity_pose(member); var kind := str(pose.get("kind",""))
			var direction: Vector2 = view.motion.direction(member)
			resident.position = Vector3(display.x,0.04+ground_height(view.world.lots[view.lot_id],display),display.y)
			resident.rotation = Vector3(0,atan2(direction.x,direction.y),0)
			var model := resident.get_node("Body") as Node3D
			model.position = Vector3.ZERO; model.rotation = Vector3.ZERO
			var reduced := bool(Preferences.values.get("reduced_motion",false))
			var stride: float = view.motion.stride(id) if view.motion.moving(id) and not reduced else 0.0
			var phase: float = view._time*TAU/0.6+float(posmod(id.hash(),7))*0.4
			var dancing := kind=="stereo" and not reduced
			if dancing: stride=sin(phase)
			var arm_left := model.find_child("Arm_L",true,false) as Node3D
			var arm_right := model.find_child("Arm_R",true,false) as Node3D
			var leg_left := model.find_child("Leg_L",true,false) as Node3D
			var leg_right := model.find_child("Leg_R",true,false) as Node3D
			if arm_left != null: arm_left.rotation = Vector3(stride*0.32,0,0.15)
			if arm_right != null: arm_right.rotation = Vector3(-stride*0.32,0,-0.15)
			if leg_left != null: leg_left.rotation = Vector3(-stride*0.40,0,0)
			if leg_right != null: leg_right.rotation = Vector3(stride*0.40,0,0)
			model.position.y = absf(stride)*0.028
			if kind in ["bed","sofa"]:
				var object: Dictionary = pose.object
				var size: Array = Catalog.ITEMS[object.kind].size
				var local := Vector2(float(size[0])*0.5,float(size[1])*(0.75 if kind=="sofa" else 0.95))
				var point: Vector2 = view.object_point(object,local)
				resident.position = Vector3(point.x,0.04,point.y); resident.rotation.y = -int(object.rotation)*PI/2
				if kind=="bed": model.rotation.x = -PI/2; model.position.y = 0.83
				else:
					model.position.y = -0.17
					if leg_left != null: leg_left.rotation.x = -PI/2
					if leg_right != null: leg_right.rotation.x = -PI/2
			elif kind=="stereo":
				model.rotation.z = stride*0.08
				if arm_left != null: arm_left.rotation = Vector3(-0.65,0,0.65+stride*0.18)
				if arm_right != null: arm_right.rotation = Vector3(-0.65,0,-0.65+stride*0.18)
			elif kind in ["chat","bookshelf","table","game_table","easel","garden_bed","meal_eat","meal_prepare","admire_art"]:
				var gesture := 0.0 if reduced else sin(view._time*3.5)*0.08
				if arm_left != null: arm_left.rotation.x = -0.7+gesture
				if arm_right != null: arm_right.rotation.x = -0.9-gesture
				if kind=="garden_bed": model.rotation.x = 0.25
			if Character.is_baby(member):
				model.rotation=Vector3(-PI/2,0,0); model.position=Vector3(0,0.67,0.35)
				if leg_left!=null: leg_left.rotation.x=-0.35
				if leg_right!=null: leg_right.rotation.x=-0.35
				if arm_left!=null: arm_left.rotation=Vector3(-0.65,0,0.5)
				if arm_right!=null: arm_right.rotation=Vector3(-0.65,0,-0.5)
			resident.get_node("Selection").visible = id==view.selected_member and view.show_cues
	for id: String in resident_nodes.keys():
		if not seen.has(id):
			var resident: Node3D = resident_nodes[id]; pick_nodes.erase(resident); resident.get_parent().remove_child(resident); resident.queue_free(); resident_nodes.erase(id)

func _update_ghost(view: Control) -> void:
	var kind: String = view.build_kind
	if kind=="move" and not str(view.build_object_id).is_empty():
		for object: Dictionary in view.world.get("lots",{}).get(view.lot_id,{}).get("objects",[]):
			if object.id==view.build_object_id: kind=str(object.kind); break
	var enabled: bool = view.building and not view.access_inspecting and Catalog.ITEMS.has(kind) and kind not in ["floor","wall","door"] and view.hover_cell.x>=0 and view.hover_cell.y>=0 and view.hover_cell.x<16 and view.hover_cell.y<16
	var key := kind if enabled else ""
	if key != _ghost_key:
		_ghost_key = key
		if ghost != null: remove_child(ghost); ghost.queue_free(); ghost = null
		if enabled:
			ghost = _model(kind); ghost.name = "PlacementPreview"; add_child(ghost)
			for mesh: MeshInstance3D in _meshes(ghost): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ghost == null: return
	var dimensions := Catalog.footprint(kind,int(view.build_rotation))
	ghost.position = Vector3(view.hover_cell.x+dimensions.x*0.5,0.07,view.hover_cell.y+dimensions.y*0.5)
	ghost.rotation.y = -int(view.build_rotation)*PI/2
	var valid: bool = view.preview_result.get("ok",false)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.70,0.88,0.55,0.45) if valid else Color(0.93,0.46,0.35,0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh: MeshInstance3D in _meshes(ghost): mesh.material_override = material

static func bounds(node: Node3D) -> AABB:
	var result := AABB(); var found := false
	if node.has_meta("pick_aabb"): result = node.global_transform * (node.get_meta("pick_aabb") as AABB); found=true
	if node is MeshInstance3D:
		result=node.global_transform*node.get_aabb(); found=true
	for child: Node in node.get_children():
		if not child is Node3D or not child.visible: continue
		var child_bounds := bounds(child)
		if child_bounds.size.is_zero_approx(): continue
		result = result.merge(child_bounds) if found else child_bounds; found=true
	return result

func _update_room_ghost(view: Control) -> void:
	var plan: Dictionary = view.copy_plan if view.copy_pending else view.copy_preview
	var enabled: bool = view.building and not view.access_inspecting and view.build_kind=="copy_room" and plan.get("ok",false) and plan.has("objects") and (view.copy_source.x>=0 or not view.copy_design.is_empty())
	var key := str(plan) if enabled else ""
	if key == _room_ghost_key: return
	_room_ghost_key = key
	if room_ghost != null: remove_child(room_ghost); room_ghost.queue_free(); room_ghost=null
	if not enabled: return
	room_ghost=Node3D.new(); room_ghost.name="RoomCopyPreview"; add_child(room_ghost)
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(0.70,0.88,0.55,0.45); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for object: Dictionary in plan.objects:
		var model := _model(str(object.kind)); var dimensions := Catalog.footprint(str(object.kind),int(object.rotation))
		model.position=Vector3(float(object.x)+dimensions.x*0.5,0.07,float(object.y)+dimensions.y*0.5)
		model.rotation.y=-int(object.rotation)*PI/2; room_ghost.add_child(model)
		for mesh: MeshInstance3D in _meshes(model):
			mesh.material_override=material; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func vertex_height(lot: Dictionary,x: int,z: int) -> float:
	var value := 0.0
	for dz in [-1,0]:
		for dx in [-1,0]: value+=Landscaping.height(lot,x+dx,z+dz)
	return value*0.25

static func ground_height(lot: Dictionary,at: Vector2) -> float:
	var x := floori(at.x); var z := floori(at.y)
	return lerpf(lerpf(vertex_height(lot,x,z),vertex_height(lot,x+1,z),at.x-x),lerpf(vertex_height(lot,x,z+1),vertex_height(lot,x+1,z+1),at.x-x),at.y-z)

func _build_ground(lot: Dictionary) -> void:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(16):
		for x in range(16):
			if Landscaping.pooled(lot,x,z):
				_batch_box(Vector3(x+0.5,-0.65,z+0.5),Vector3(1,0.06,1),Color("619aa7"))
				var water := _box(architecture,Vector3(x+0.5,-0.10,z+0.5),Vector3(1,0.025,1),Color("78b6c1"))
				water.name="PoolWater"
				var material := _material(Color("78b6c1")).duplicate() as StandardMaterial3D
				material.roughness=0.18; material.metallic=0.15; water.material_override=material
				for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if Landscaping.pooled(lot,x+direction.x,z+direction.y): continue
					var at := Vector3(x+0.5+direction.x*0.48,0.02,z+0.5+direction.y*0.48)
					var size := Vector3(0.12,0.08,1.02) if direction.x!=0 else Vector3(1.02,0.08,0.12)
					_batch_box(at,size,Color("e4d9bc"))
					_batch_box(at+Vector3.DOWN*0.33,Vector3(size.x,0.65,size.z),Color("8fb4b8"))
				continue
			var paint: String=lot.get("landscape",{}).get("paints",{}).get(Landscaping.key(x,z),"grass")
			var color := Color(Landscaping.PAINTS[paint]).lightened(float(posmod(x*7+z*11,5)-2)*0.012)
			for point: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				surface.set_color(color); surface.add_vertex(Vector3(x+point.x,vertex_height(lot,x+point.x,z+point.y)-0.025,z+point.y))
	surface.generate_normals()
	var ground := MeshInstance3D.new(); ground.name="EditableGround"; ground.mesh=surface.commit()
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.cull_mode=BaseMaterial3D.CULL_DISABLED; mat.roughness=1.0
	ground.material_override=mat; architecture.add_child(ground)

func _window_wall(center: Vector3,along: bool,height: float,color: Color,parent: Node3D=null) -> void:
	var root := architecture if parent==null else parent
	# Four solid pieces around an actual 0.72 × 0.92m aperture.
	for data: Array in [[Vector3(0,0.45,0),Vector3(1,0.9,0.24)],[Vector3(0,(1.82+height)*0.5,0),Vector3(1,maxf(0.01,height-1.82),0.24)],[Vector3(-0.43,1.36,0),Vector3(0.14,0.92,0.24)],[Vector3(0.43,1.36,0),Vector3(0.14,0.92,0.24)]]:
		var offset: Vector3=data[0]; var dimensions: Vector3=data[1]
		if not along: offset=Vector3(offset.z,offset.y,offset.x); dimensions=Vector3(dimensions.z,dimensions.y,dimensions.x)
		_box(root,center+offset,dimensions,color)

func _wallpaper(center: Vector3,parts: Array[Rect2],height: float,finish: Dictionary) -> void:
	var pattern := str(finish.get("pattern",""))
	if pattern.is_empty(): return
	var color := Color(finish.color)
	for part: Rect2 in parts:
		var along := part.size.x>part.size.y
		var length := part.size.x if along else part.size.y
		var start := part.position.x if along else part.position.y
		if pattern=="panel":
			_wall_boxes(center+Vector3.UP*minf(0.43,height*0.5),[part],minf(0.8,height),Color("af8c65"))
			_wall_boxes(center+Vector3.UP*minf(0.85,height),[part.grow(0.014)],0.045,Color("896c4c"))
		else:
			for i in range(maxi(1,ceili(length/0.16))):
				var offset := Vector3(start+(i+0.5)*0.16,height*0.5,0) if along else Vector3(0,height*0.5,start+(i+0.5)*0.16)
				if pattern=="stripes":
					_batch_box(center+offset,Vector3(0.035,height,0.248) if along else Vector3(0.248,height,0.035),color.darkened(0.15))
				else:
					for row in range(maxi(1,floori(height/0.3))):
						offset.y=0.16+row*0.3
						_batch_box(center+offset,Vector3(0.045,0.07,0.248) if along else Vector3(0.248,0.07,0.045),Color("a7867f"))

func _build_lower_floors(view: Control,lot: Dictionary) -> void:
	_clear(lower_floors)
	var level := int(lot.get("level",0))
	neighborhood.position.y=-level*Storeys.HEIGHT
	if level==0: return
	var root: Dictionary=Session.state.get("lots",{}).get(view.lot_id,{})
	for index in range(level):
		var layer := Storeys.view(root,index)
		var shell := Node3D.new(); lower_floors.add_child(shell); shell.position.y=(index-level)*Storeys.HEIGHT
		for cell: Array in layer.floors:
			_box(shell,Vector3(float(cell[0])+0.5,0,float(cell[1])+0.5),Vector3(1,0.1,1),Color("b6a386"))
		if index==0:
			var active := architecture; architecture=shell; _build_ground(root); _finish_boxes(shell); architecture=active
		for cell: Array in layer.walls:
			var x := int(cell[0]); var z := int(cell[1]); var center := Vector3(x+0.5,0,z+0.5)
			var along := Windows.along_x(layer,x,z)
			var color := Color(Finishes.PALETTES.wall[Finishes.at(layer,"wall",x,z)].color)
			var window_style := Windows.at(layer,x,z)
			if window_style.is_empty():
				var wall := _box(shell,center+Vector3.UP*1.1,Vector3(1,2.2,0.24) if along else Vector3(0.24,2.2,1),color)
				var diagonal := int(layer.get("diagonal_walls",{}).get("%d,%d" % [x,z],0))
				if diagonal!=0: wall.scale.x=1.414; wall.rotation.y=-diagonal*PI/4
			else:
				_window_wall(center,along,2.1,color,shell)
				var window := _model("window_"+window_style); window.position=center+Vector3(0,0.035,0.135) if along else center+Vector3(0.135,0.035,0)
				if not along: window.rotation.y=PI/2
				shell.add_child(window)
		for cell: Array in layer.doors:
			var door := _model("door_frame"); door.position=Vector3(float(cell[0])+0.5,0.04,float(cell[1])+0.5)
			if not Windows.along_x(layer,int(cell[0]),int(cell[1])): door.rotation.y=PI/2
			shell.add_child(door)
		for object: Dictionary in layer.objects:
			if object.kind=="stairs": continue
			var model := _model(str(object.kind)); var size := Catalog.footprint(str(object.kind),int(object.rotation))
			model.position=Vector3(float(object.x)+size.x*0.5,0.04,float(object.y)+size.y*0.5); model.rotation.y=-int(object.rotation)*PI/2
			shell.add_child(model); _recolor(model,object)
		for stair: Dictionary in Storeys.stairs(root,index):
			var model := _model("stairs"); var size := Catalog.footprint("stairs",int(stair.rotation))
			model.position=Vector3(float(stair.x)+size.x*0.5,0.04,float(stair.y)+size.y*0.5); model.rotation.y=-int(stair.rotation)*PI/2; shell.add_child(model)
