extends Node
## One reusable studio viewport photographs the shipped geometry, then sleeps.
## Images live only in memory; shopping never writes assets or simulation state.
signal completed(kind: String, texture: Texture2D)
const Scene3D = preload("res://game/lot_scene_3d.gd")
var cache: Dictionary = {}
var pending: Array[String] = []
var busy := false
var studio: SubViewport
var camera: Camera3D
var stage: Node3D

func request(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	if DisplayServer.get_name()=="headless" or not ResourceLoader.exists("res://assets/models/"+kind+".glb"): return null
	if kind not in pending: pending.append(kind)
	if not busy: call_deferred("_render_next")
	return null

func _setup() -> void:
	studio=SubViewport.new(); studio.size=Vector2i(160,120)
	studio.own_world_3d=true; studio.transparent_bg=true
	studio.msaa_3d=Viewport.MSAA_4X; studio.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(studio)
	stage=Node3D.new(); studio.add_child(stage)
	var env := WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("e9e4d8"); env.environment.ambient_light_energy=0.7
	studio.add_child(env)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-28,0)
	light.light_energy=0.85; studio.add_child(light)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	studio.add_child(camera)

func _render_next() -> void:
	if busy or pending.is_empty(): return
	busy=true
	if studio==null: _setup()
	var kind: String=pending.pop_front()
	var model := (load("res://assets/models/"+kind+".glb") as PackedScene).instantiate() as Node3D
	stage.add_child(model)
	var bounds := Scene3D.bounds(model)
	var center := bounds.get_center()
	camera.position=center+Vector3(4,3.1,5); camera.look_at(center)
	camera.size=maxf(1.1,maxf(bounds.size.y*1.4,(bounds.size.x+bounds.size.z)*0.78))
	studio.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(studio.get_texture().get_image())
	cache[kind]=texture
	studio.render_target_update_mode=SubViewport.UPDATE_DISABLED
	stage.remove_child(model); model.queue_free()
	completed.emit(kind,texture)
	busy=false
	if not pending.is_empty(): call_deferred("_render_next")
