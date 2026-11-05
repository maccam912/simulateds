extends SceneTree
const Character = preload("res://game/character_profile.gd")
const Dining = preload("res://game/dining_pose.gd")
const Meals = preload("res://game/meals.gd")
const ModelPoints = preload("res://tests/model_test_points.gd")
var session: Node
var game: Control
var view: Control
var family: Dictionary
var lot: Dictionary
var table: Dictionary
var native := false

func _initialize() -> void: call_deferred("_run")
func _settle() -> void:
	game._refresh()
	for frame in range(4): await process_frame
func _capture(label: String) -> void:
	if not native: return
	await _settle()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/dining-"+label+".png")==OK)
func _order(member: Dictionary, action: String, recipe: String="") -> void:
	var result: Dictionary=session.world.apply_command(session.profile_id,{"type":"meal","member_id":member.id,"lot_id":lot.id,"target_id":table.id,"action":action,"recipe":recipe,"batch":table.meal.batch})
	assert(result.ok,str(result.message))
func _prepare(recipe: String="salad") -> void:
	for member: Dictionary in family.members: session.world._clear_member(member)
	if table.meal.servings>0: _order(family.members[0],"clear")
	_order(family.members[0],"prepare",recipe)
	for tick in range(400):
		session.world.step(0.1)
		if family.members[0].task.is_empty(): break
	assert(table.meal.servings==4)
func _eat(cells: Array) -> void:
	for index in range(4):
		var member: Dictionary=family.members[index]
		member.x=cells[index].x; member.y=cells[index].y; member.needs.hunger=10.0
	for member: Dictionary in family.members: _order(member,"eat")
	for tick in range(15):
		session.world.step(0.1)
		if table.meal.servings==0: break
	view.motion.tracks.clear()
	await _settle()
	assert(table.meal.servings==0)

func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("res://build")
	root.size=Vector2i(1440,900)
	root.get_node("Preferences").reset_defaults()
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true; session.set_physics_process(false)
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	family=session.state.families[session.profile_id]; lot=session.state.lots[family.home_lot]
	for index in range(4):
		if index>=family.members.size():
			var extra: Dictionary=family.members[0].duplicate(true); extra.id="diner_%d" % index; family.members.append(extra)
		var member: Dictionary=family.members[index]
		member.name=["Alex","Robin","June","Morgan"][index]; member.autonomy=false
		member.character=Character.of(member).duplicate(true)
		member.character.age=2 if index==2 else 5
		member.character.height=[50,0,50,100][index]; member.character.build=100 if index==3 else 50
		member.x=5+index; member.y=10
	assert(session.world.apply_command(session.profile_id,{"type":"build_begin","lot_id":lot.id}).ok)
	assert(session.world.apply_command(session.profile_id,{"type":"place","lot_id":lot.id,"kind":"dining_table","x":8,"y":6}).ok)
	table=lot.objects[-1]
	assert(session.world.apply_command(session.profile_id,{"type":"build_end","lot_id":lot.id}).ok)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); view=game.lot_view
	await _settle()
	_prepare()
	var first: Dictionary=family.members[0]
	first.x=6; first.y=10; _order(first,"eat")
	await _settle()
	assert(view._activity_pose(first).is_empty())
	assert(not view.projection.scene.resident_nodes[first.id].has_node("DiningPlace"),"Approaching residents cannot display a taken portion")
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	assert(table.meal.servings==4,"Cancellation before arrival releases the portion")
	var cells := [Vector2i(8,5),Vector2i(9,5),Vector2i(10,6),Vector2i(10,7),Vector2i(9,8),Vector2i(8,8),Vector2i(7,7),Vector2i(7,6)]
	for turn in range(4):
		if turn>0: _prepare("sandwiches" if turn%2 else "salad")
		table.rotation=turn; lot.revision+=1
		var places: Array=[]
		for index in range(4): places.append(cells[(turn*2+index)%8])
		await _eat(places)
		var before: Dictionary=session.world.snapshot()
		var positions: Array[Vector3]=[]
		for member: Dictionary in family.members:
			var node: Node3D=view.projection.scene.resident_nodes[member.id]
			var body: Node3D=node.get_node("Body")
			var props: Node3D=node.get_node("DiningPlace")
			assert(view.projection.scene._meshes(props).size()<=2,"Stool and plate geometry are batched rather than adding a draw per part")
			assert(props.visible and node.basis.z.dot(Vector3(Dining.place(member,table).facing.x,0,Dining.place(member,table).facing.y))>0.999)
			for previous: Vector3 in positions: assert(previous.distance_to(node.position)>0.6,"Adjacent accepted places retain separate silhouettes")
			positions.append(node.position)
			assert(is_equal_approx(body.get_node("Leg_L/Knee_L").rotation.x,PI/2))
			assert(view.resident_anchor(member).distance_to(view.projection.project(node.global_position))<0.01)
			var plate: Node3D=props.get_node("Plate")
			assert(plate.global_position.x>table.x and plate.global_position.x<table.x+2 and plate.global_position.z>table.y and plate.global_position.z<table.y+2)
			var hand: Vector3=body.get_node("Arm_R").global_transform*Vector3(0,-0.53,0.038)
			assert(hand.distance_to(plate.global_position)<0.15,"Eating hand stays at its own plate")
			if native: ModelPoints.resident_surface(view,member)
		await _capture("day-turn-%d" % turn)
		assert(session.world.snapshot()==before,"Rendering/picking cannot change portions, places, needs, paths, funds or rewards")
	# Pausing and reduced motion retain a steady pose; speed uses the shared time.
	var body: Node3D=view.projection.scene.resident_nodes[first.id].get_node("Body")
	var arm: Node3D=body.get_node("Arm_R")
	var held: Transform3D=arm.transform
	await create_timer(0.12).timeout
	assert(held==arm.transform)
	view._time+=0.4; view.projection.sync(0.4)
	assert(held!=arm.transform)
	root.get_node("Preferences").set_value("reduced_motion",true); await _settle()
	held=arm.transform; view._time+=1; view.projection.sync(1)
	assert(held==arm.transform)
	view.zoom=1.8; view._layout(); await _capture("close")
	view.center_lot(); session.state.day_minutes=0; await _capture("night")
	root.size=Vector2i(1280,720); root.get_node("Preferences").set_value("ui_scale",1.25)
	await _capture("compact-night")
	session.state.day_minutes=720; root.get_node("Preferences").set_value("quality","low"); await _capture("compact-day-low")
	var node: Node3D=view.projection.scene.resident_nodes[first.id]
	var props: Node3D=node.get_node("DiningPlace")
	assert(session.world.apply_command(session.profile_id,{"type":"cancel","member_id":first.id}).ok)
	await _settle()
	assert(not props.visible and node.position.x==first.x+0.5 and node.position.z==first.y+0.5 and table.meal.servings==0)
	assert(body.get_node("Leg_L/Knee_L").rotation==Vector3.ZERO)
	for mesh: MeshInstance3D in view.projection.scene._meshes(props): assert(not mesh.visible)
	for tick in range(120): session.world.step(0.1)
	await _settle()
	for member: Dictionary in family.members:
		assert(member.task.is_empty() and not view.projection.scene.resident_nodes[member.id].get_node("DiningPlace").visible)
	_prepare(); await _eat(cells.slice(0,4))
	props=node.get_node("DiningPlace")
	# Changed batches, construction and missing targets cannot retain dining props.
	table.meal.batch+=1; await _settle(); assert(not props.visible); table.meal.batch-=1
	lot.building=true; await _settle(); assert(not props.visible); lot.building=false
	await _settle(); assert(props.visible)
	table.x+=4; lot.revision+=1; await _settle(); assert(not props.visible,"Moving a stale target cannot drag the diner across the lot")
	table.x-=4; lot.revision+=1; await _settle(); assert(props.visible)
	lot.objects.erase(table); lot.revision+=1; await _settle(); assert(not props.visible)
	print("DINING_POSE_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
