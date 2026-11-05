extends Control
## A private presentation world. Draft changes never reach Session or simulation.
const Model = preload("res://game/character_model.gd")
const Profile = preload("res://game/character_profile.gd")
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D
var turntable: Node3D
var model: Node3D
var sun: DirectionalLight3D
var environment: Environment
var yaw := -0.16
var close_up := false
var night := false
var animation_time := 0.0
var paused := false
var _dragging := false
var _generator = Model.new()
var _profile: Dictionary
var _head_scale := Vector3.ONE
var _character: Dictionary
var _occasion := "casual"
var _voice: AudioStreamPlayer

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	var container := SubViewportContainer.new(); add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch=true; container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new(); viewport.own_world_3d=true
	viewport.transparent_bg=false; viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage)
	var world_environment := WorldEnvironment.new()
	environment=Environment.new(); environment.background_mode=Environment.BG_COLOR; environment.background_color=Color("c8c4ae")
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color=Color("ffffff"); environment.ambient_light_energy=0.38
	world_environment.environment=environment; stage.add_child(world_environment)
	sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-28,-32,0); sun.light_energy=0.52; sun.light_color=Color("ffffff"); sun.shadow_enabled=true; stage.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees=Vector3(-20,145,0); fill.light_energy=0.16; fill.light_color=Color("ffffff"); stage.add_child(fill)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2.15; camera.current=true; stage.add_child(camera)
	_room()
	turntable=Node3D.new(); stage.add_child(turntable)
	_voice=AudioStreamPlayer.new(); _voice.bus="Effects"; _voice.volume_db=-13; add_child(_voice)
	gui_input.connect(_input_preview)
	visibility_changed.connect(func():
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
		if not is_visible_in_tree(): _voice.stop())
	_camera()

func show_member(member: Dictionary, occasion: String="casual") -> void:
	var next_profile := Profile.of(member)
	var reframe: bool = _character.get("id")!=member.get("id") or _profile.get("age")!=next_profile.age or _profile.get("height")!=next_profile.height
	_character=member.duplicate(true); _occasion=occasion; _profile=next_profile.duplicate(true)
	if not is_node_ready(): await ready
	for child in turntable.get_children(): turntable.remove_child(child); child.queue_free()
	model=_generator.build(_character,occasion); turntable.add_child(model)
	var head := model.get_node("Head") as Node3D; _head_scale=head.scale
	if int(_profile.age)==0:
		turntable.add_child(_generator.bassinet())
		model.position=Vector3(0,0.67,0.35); model.rotation.x=-PI/2
	if reframe: _camera()

func _camera() -> void:
	if camera==null: return
	var height := 1.74*Profile.height_scale(_profile) if not _profile.is_empty() else 1.74
	var baby := not _profile.is_empty() and int(_profile.age)==0
	var target := Vector3(0,height*0.53,0)
	camera.size=maxf(1.15,height*1.27)
	if baby: target=Vector3(0,0.62,0); camera.size=1.8
	if close_up:
		target=Vector3(0,height*0.86,0.04); camera.size=maxf(0.52,height*0.43)
		if baby: target=Vector3(0,0.76,-0.19); camera.size=0.8
	camera.position=target+Vector3(0,0.14 if close_up else 0.26,4)
	if baby: camera.position=target+Vector3(0,2.5,3.7)
	camera.look_at(target)

func set_close_up(value: bool) -> void:
	close_up=value; _camera()

func set_night(value: bool) -> void:
	night=value; sun.light_energy=0.30 if night else 0.52
	sun.light_color=Color("d5dded") if night else Color("ffffff")
	environment.ambient_light_energy=0.30 if night else 0.38
	environment.ambient_light_color=Color("e3d6c7") if night else Color("ffffff")

func _process(delta: float) -> void:
	if model==null or not is_visible_in_tree(): return
	var reduced := paused or bool(Preferences.values.get("reduced_motion",false))
	if not reduced: animation_time+=delta
	turntable.rotation.y=yaw
	var t := 0.0 if reduced else animation_time
	var baby := int(_profile.age)==0
	var torso := model.get_node("Torso") as Node3D
	torso.scale.y=1.0+sin(t*1.8)*0.007
	var head := model.get_node("Head") as Node3D
	head.rotation=Vector3(sin(t*0.7)*0.024,sin(t*0.43)*0.07,sin(t*0.55)*0.018)
	head.scale=_head_scale
	for side in [-1,1]:
		var suffix := "L" if side==-1 else "R"
		var arm := model.get_node("Arm_"+suffix) as Node3D
		arm.rotation=Vector3(sin(t*1.1+side)*0.025,0,-side*(0.07+sin(t*0.8)*0.018))
		if baby: arm.rotation.x=-0.65; arm.rotation.z=-side*0.5
		var eye := head.get_node("Eye_"+suffix) as Node3D
		var blink := fmod(t,4.3)
		eye.scale.y=0.10 if not reduced and blink>4.1 else 1.0
		if baby: (model.get_node("Leg_"+suffix) as Node3D).rotation.x=-0.35+sin(t+side)*0.07
	if not baby: model.rotation.z=sin(t*0.65)*0.007

func _input_preview(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: _dragging=event.pressed; accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size=clampf(camera.size*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),0.5,3.2); accept_event()
	elif event is InputEventMouseMotion and _dragging: yaw+=event.relative.x*0.009; accept_event()
	elif event is InputEventScreenDrag: yaw+=event.relative.x*0.009; accept_event()

func preview_voice() -> void:
	if _profile.is_empty() or not Soundscape.enabled: return
	_voice.stream=preload("res://game/character_voice.gd").sample(_profile)
	_voice.play()

func _room() -> void:
	_box(Vector3(0,-0.05,0),Vector3(10,0.10,10),Color("b69b79"))
	for index in range(-8,9): _box(Vector3(index*0.34,0.005,0),Vector3(0.009,0.009,10),Color("a78d6c"))
	_box(Vector3(0,1.6,-1.2),Vector3(10,3.2,0.10),Color("d8d3bd"))
	_box(Vector3(0,0.48,-1.13),Vector3(10,0.96,0.07),Color("8c9d88"))
	_box(Vector3(0,0.97,-1.07),Vector3(10,0.045,0.08),Color("bec6a8"))
	for index in range(-10,11): _box(Vector3(index*0.32,0.48,-1.08),Vector3(0.025,0.91,0.025),Color("a0ae96"))
	var rug := CylinderMesh.new(); rug.top_radius=0.78; rug.bottom_radius=0.78; rug.height=0.018; rug.radial_segments=64
	_generator._mesh(stage,rug,Color("c7bb99"),Vector3(0,0.016,0))
	var ring := TorusMesh.new(); ring.inner_radius=0.70; ring.outer_radius=0.71; ring.rings=64; ring.ring_segments=6
	_generator._mesh(stage,ring,Color("9a8b69"),Vector3(0,0.028,0))
	# Real furniture grounds the creator in Linden Grove's domestic palette.
	var plant_scene := load("res://assets/models/plant.glb") as PackedScene
	if plant_scene!=null:
		var plant := plant_scene.instantiate() as Node3D; plant.position=Vector3(1.1,0,-0.65); plant.scale=Vector3.ONE*1.1; stage.add_child(plant)
	_box(Vector3(-1.02,1.18,-0.78),Vector3(0.52,1.85,0.09),Color("876e51"))
	_box(Vector3(-1.02,1.18,-0.72),Vector3(0.44,1.76,0.025),Color("afc4bf"))
	_box(Vector3(-1.02,0.10,-0.60),Vector3(0.59,0.15,0.42),Color("876e51"))

func _box(at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new(); mesh.size=dimensions; _generator._mesh(stage,mesh,color,at)
