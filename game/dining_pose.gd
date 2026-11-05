extends RefCounted
## Original procedural dining props and pose, derived from a consumed portion.
## The accepted cell owns the place. No seat search, reservation or world writes.
const Catalog = preload("res://game/catalog.gd")

static func place(member: Dictionary, table: Dictionary) -> Dictionary:
	var task: Dictionary = member.get("task",{})
	var meal: Dictionary = table.get("meal",{})
	if table.get("kind")!="dining_table" or not task.get("meal_taken",false) or task.get("meal_batch")!=meal.get("batch") or task.get("meal_recipe")!=meal.get("recipe"): return {}
	var size := Catalog.footprint("dining_table",int(table.rotation))
	var cell := Vector2i(int(member.x),int(member.y))
	var start := Vector2i(int(table.x),int(table.y))
	var end := start+size
	var facing := Vector2.ZERO
	if cell.x>=start.x and cell.x<end.x:
		if cell.y==start.y-1: facing=Vector2.DOWN
		elif cell.y==end.y: facing=Vector2.UP
	elif cell.y>=start.y and cell.y<end.y:
		if cell.x==start.x-1: facing=Vector2.RIGHT
		elif cell.x==end.x: facing=Vector2.LEFT
	if facing==Vector2.ZERO: return {}
	return {"facing":facing,"cell":Vector2(cell)+Vector2(0.5,0.5)}

static func apply(scene: Node3D, resident: Node3D, member: Dictionary, table: Dictionary, time: float, reduced: bool) -> bool:
	var slot := place(member,table)
	if slot.is_empty(): return false
	var model := resident.get_node("Body") as Node3D
	var scale := model.scale.y
	var table_node: Node3D = scene.object_nodes.get(str(table.id))
	if table_node==null: return false
	var floor_y := table_node.position.y
	# The seat and a child's footrest support the unchanged body proportions.
	var seat := maxf(0.49,0.95-0.48*scale)
	model.position.y=seat-0.72*scale
	var shoulder_y := model.position.y+1.20*scale
	var hand_y := 0.89
	var arm_angle := -acos(clampf((shoulder_y-hand_y)/(0.53*scale),-1,1))
	var reach := sin(-arm_angle)*0.53*scale
	# Plate stays inside the table edge; each cell retains its own lateral lane.
	var inward := 0.5+0.23-reach
	var at: Vector2 = slot.cell+slot.facing*inward
	resident.position=Vector3(at.x,floor_y,at.y)
	resident.rotation.y=atan2(slot.facing.x,slot.facing.y)
	for side: String in ["L","R"]:
		var leg := model.get_node("Leg_"+side) as Node3D
		leg.rotation=Vector3(-PI/2,0,0)
		leg.get_node("Knee_"+side).rotation=Vector3(PI/2,0,0)
		var arm := model.get_node("Arm_"+side) as Node3D
		# One quiet scooping motion, driven by paused/speed-scaled presentation time.
		var gesture := 0.0 if reduced or side=="L" else (sin(time*2.0+float(posmod(str(member.id).hash(),9)))+1.0)*0.045
		arm.rotation=Vector3(arm_angle-gesture,0,0)
	var props := resident.get_node_or_null("DiningPlace") as Node3D
	var key := str([scale,model.get_node("Arm_R").position.x,table.meal.recipe])
	if props!=null and props.get_meta("key","")!=key:
		resident.remove_child(props); props.queue_free(); props=null
	if props==null:
		props=Node3D.new(); props.name="DiningPlace"; resident.add_child(props); props.set_meta("key",key)
		var wood := Color("b8946b")
		scene._box(props,Vector3(0,seat-0.045,0),Vector3(0.48,0.09,0.44),wood)
		for x in [-0.18,0.18]:
			for z in [-0.16,0.16]: scene._box(props,Vector3(x,(seat-0.09)*0.5,z),Vector3(0.055,seat-0.09,0.055),wood.darkened(0.12))
		var feet := seat-0.41*scale
		if feet>0.13:
			scene._box(props,Vector3(0,feet-0.025,0.31*scale+0.04),Vector3(0.43,0.05,0.25),wood)
			for x in [-0.18,0.18]: scene._box(props,Vector3(x,feet*0.5,0.31*scale+0.10),Vector3(0.045,feet,0.045),wood.darkened(0.12))
		var plate := Node3D.new(); plate.name="Plate"; props.add_child(plate)
		# Offset under the right hand; adjacent diners remain a whole cell apart.
		var arm := model.get_node("Arm_R") as Node3D
		plate.position=Vector3(arm.position.x*scale,0.855,reach)
		var dish := CylinderMesh.new(); dish.top_radius=0.15; dish.bottom_radius=0.14; dish.height=0.018; dish.radial_segments=24
		var mesh := MeshInstance3D.new(); mesh.mesh=dish; mesh.material_override=scene._material(Color("eee8d8")); plate.add_child(mesh)
		var rim := TorusMesh.new(); rim.inner_radius=0.135; rim.outer_radius=0.153; rim.rings=24; rim.ring_segments=6
		mesh=MeshInstance3D.new(); mesh.mesh=rim; mesh.position.y=0.012; mesh.material_override=scene._material(Color("eee8d8")); plate.add_child(mesh)
		if table.meal.recipe=="sandwiches": scene._box(plate,Vector3(0,0.025,0),Vector3(0.18,0.035,0.14),Color("d9b87d"))
		else:
			for index in range(5): scene._sphere(plate,Vector3(sin(index*2)*0.06,0.025,cos(index*2)*0.06),Vector3(0.055,0.025,0.045),Color("729958"))
			if table.meal.recipe=="homegrown":
				for x in [-0.05,0.05]: scene._sphere(plate,Vector3(x,0.045,0),Vector3(0.035,0.025,0.03),Color("bf6452"))
		# Keep the plate anchor but batch the solid stool/food by material.
		scene._character_model._merge_parts(props)
	props.visible=true
	for mesh: MeshInstance3D in scene._meshes(props): mesh.visible=true
	return true

static func clear(scene: Node3D, resident: Node3D) -> void:
	var props := resident.get_node_or_null("DiningPlace") as Node3D
	if props==null: return
	props.visible=false
	# Picking traverses descendant meshes, so explicitly hide the geometry too.
	for mesh: MeshInstance3D in scene._meshes(props): mesh.visible=false
