extends RefCounted
## Original solid painting props and height-aware contact. Accepted state only.
const Paintings = preload("res://game/paintings.gd")
const HAND := Vector3(0.016,-0.49,0.033)
const CANVAS_Z := 0.134

static func apply(scene: Node3D, resident: Node3D, member: Dictionary, easel: Dictionary, time: float, reduced: bool) -> bool:
	var task: Dictionary=member.get("task",{})
	if task.get("paint_action") not in ["start","resume"] or task.get("paint_revision")!=easel.get("painting",{}).get("revision"): return false
	if Vector2i(int(member.x),int(member.y))!=Paintings.front_cell(easel): return false
	var furnishing: Node3D=scene.object_nodes.get(str(easel.id))
	if furnishing==null: return false
	var body := resident.get_node("Body") as Node3D
	var arm := body.get_node("Arm_R") as Node3D
	var scale := body.scale.y
	# A solid step raises smaller residents without changing their proportions.
	var lift := 1.05-arm.position.y*scale
	if lift<0.08: lift=0.0
	var stroke := 0.0 if reduced else sin(time*2.0)*0.045
	var hand_y := 1.12+stroke
	var shoulder_y := lift+arm.position.y*scale
	var length := HAND.length()*scale
	# Keep both feet and step stationary throughout a stroke. Solve the arm and
	# brush as two links so only the hand/brush move along the canvas surface.
	var reach := sqrt(pow(length+0.12,2)-pow(1.12-shoulder_y,2))
	var target := Vector2(reach,hand_y-shoulder_y)
	var distance := target.length()
	var along := (length*length-0.16*0.16+distance*distance)/(2.0*distance)
	var across := sqrt(maxf(0.0,length*length-along*along))
	var direction := target/distance
	var wrist := direction*along-Vector2(-direction.y,direction.x)*across
	# Face the real canvas; retain the accepted front cell as the routing position.
	resident.position=furnishing.position+furnishing.basis*Vector3(arm.position.x*scale-0.12,0,CANVAS_Z+reach)
	resident.rotation.y=furnishing.rotation.y+PI
	body.position.y=lift
	arm.quaternion=Quaternion(HAND.normalized(),Vector3(0,wrist.y,wrist.x).normalized())
	body.get_node("Arm_L").rotation=Vector3(-0.25,0,0.10)
	var props := resident.get_node_or_null("PaintingTools") as Node3D
	if props==null:
		props=Node3D.new(); props.name="PaintingTools"; resident.add_child(props)
		var step := Node3D.new(); step.name="Step"; props.add_child(step)
		if lift>0.001:
			var wood := Color("b8946b")
			scene._box(step,Vector3(0,lift-0.035,0.035),Vector3(0.48,0.07,0.48),wood)
			for x in [-0.19,0.19]:
				for z in [-0.15,0.22]: scene._box(step,Vector3(x,(lift-0.07)*0.5,z),Vector3(0.055,maxf(0.01,lift-0.07),0.055),wood.darkened(0.12))
			# Taller steps include a lower tread on the resident's approach side.
			if lift>0.26:
				scene._box(step,Vector3(0,lift*0.5-0.025,-0.29),Vector3(0.44,0.05,0.20),wood)
				for x in [-0.17,0.17]: scene._box(step,Vector3(x,lift*0.25-0.025,-0.30),Vector3(0.055,lift*0.5-0.05,0.055),wood.darkened(0.12))
			scene._character_model._merge_parts(step)
		var brush := Node3D.new(); brush.name="Brush"; props.add_child(brush)
		# Local +Z reaches from the hand into the canvas. Three solid material groups.
		scene._box(brush,Vector3(0,0,0.025),Vector3(0.013,0.013,0.21),Color("805b3c"))
		scene._box(brush,Vector3(0,0,0.126),Vector3(0.021,0.016,0.026),Color("b7b9af"))
		scene._box(brush,Vector3(0,0,0.150),Vector3(0.023,0.012,0.022),Color("879a69"))
		var tip := Node3D.new(); tip.name="Tip"; tip.position.z=0.16; brush.add_child(tip)
	props.visible=true
	for mesh: MeshInstance3D in scene._meshes(props): mesh.visible=true
	var brush := props.get_node("Brush") as Node3D
	brush.position=resident.to_local(arm.to_global(HAND))
	var to_canvas := target-wrist
	brush.quaternion=Quaternion(Vector3.BACK,Vector3(0,to_canvas.y,to_canvas.x).normalized())
	return true

static func clear(scene: Node3D, resident: Node3D) -> void:
	var props := resident.get_node_or_null("PaintingTools") as Node3D
	if props==null: return
	props.visible=false
	for mesh: MeshInstance3D in scene._meshes(props): mesh.visible=false
