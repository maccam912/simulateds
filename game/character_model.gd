extends RefCounted
## Original parametric solid geometry, shared by the dressing room and live world.
## This editable source is the asset master. No image planes or external assets.
const Profile = preload("res://game/character_profile.gd")
const Appearance = preload("res://game/appearance.gd")
var _materials := {}
var high_detail := true
var _sphere: SphereMesh
var _smooth_sphere: SphereMesh

func build(member: Dictionary, occasion: String="") -> Node3D:
	var profile := Profile.of(member)
	var look := Appearance.of(member)
	var outfit: Dictionary=profile.outfits[profile.wearing if occasion.is_empty() else occasion]
	var skin: Color=Appearance.SKIN[int(look.skin)]
	var hair: Color=Appearance.HAIR[int(look.hair)]
	var top: Color=Profile.COLORS[int(outfit.top_color)]
	var bottom: Color=Profile.COLORS[int(outfit.bottom_color)]
	var shoe: Color=Profile.COLORS[int(outfit.shoe_color)]
	var trim: Color=Profile.COLORS[int(outfit.accessory_color)]
	var body := Node3D.new(); body.name="Body"
	var broad := lerpf(0.82,1.22,float(profile.shoulders)/100.0)
	var build_value := lerpf(0.78,1.40,float(profile.build)/100.0)
	var hip := lerpf(0.83,1.25,float(profile.hips)/100.0)
	var torso := _pivot(body,"Torso",Vector3(0,1.02,0))
	var shoulders := 0.205*broad*lerpf(0.94,1.12,float(profile.build)/100)
	var waist := 0.155*build_value
	var hips := 0.176*hip*lerpf(0.95,1.10,float(profile.build)/100)
	var depth := 0.116*build_value
	# A continuous tailored silhouette, with separate neckline and seams.
	var hem := 0.77 if int(outfit.top) in [3,4] else 0.83
	_loft(torso,Vector3(0,-1.02,0),[[hem,hips,depth],[0.88,waist,depth],[1.02,waist*1.04,depth*1.03],[1.17,shoulders,depth],[1.23,shoulders*0.87,depth*0.88],[1.265,0.076,0.067]],top)
	_ellipsoid(torso,Vector3(0,0.27,0),Vector3(0.069,0.093,0.065),skin)
	if int(outfit.top) in [1,3,4,6]:
		for side in [-1,1]:
			var collar := _ellipsoid(torso,Vector3(side*0.063,0.209,0.108),Vector3(0.061,0.045,0.014),trim if int(outfit.top)==4 else top.lightened(0.18))
			collar.rotation.z=side*0.52
		for yy in [0.15,0.07,-0.01,-0.09]: _ellipsoid(torso,Vector3(0,yy,depth+0.004),Vector3(0.008,0.008,0.004),trim)
	if int(outfit.top) in [3,4]:
		for side in [-1,1]:
			_rod(torso,Vector3(side*0.035,0.17,depth),Vector3(side*0.07,-0.20,depth),0.007,trim)
			_rod(torso,Vector3(side*waist*0.4,-0.08,depth),Vector3(side*waist*0.85,-0.075,depth),0.007,top.darkened(0.22))
	if int(outfit.pattern)==1:
		for yy in [0.91,0.98,1.05,1.12]:
			_loft(torso,Vector3(0,-1.02,0),[[yy,waist*1.06,depth*1.05],[yy+0.018,waist*1.07,depth*1.05]],trim)
	elif int(outfit.pattern)==2:
		_loft(torso,Vector3(0,-1.02,0),[[hem,hips*1.01,depth*1.01],[hem+0.028,hips*1.01,depth*1.01]],trim)
	# Waistband and real skirt volume; legs remain articulated underneath.
	_loft(torso,Vector3(0,-1.02,0),[[0.73,hips*0.98,depth*0.95],[0.81,hips,depth*0.99]],bottom)
	if int(outfit.bottom) in [3,4]:
		var length := 0.39 if int(outfit.bottom)==3 else 0.15
		_loft(torso,Vector3(0,-1.02,0),[[length,hips*1.48,depth*1.4],[0.62,hips*1.14,depth*1.15],[0.80,hips,depth]],bottom)
		for side in [-1,1]: _rod(torso,Vector3(side*hips*1.3,length-1.02,depth*0.52),Vector3(side*hips*0.9,-0.24,depth*0.54),0.004,bottom.lightened(0.13))
	for side in [-1,1]:
		var suffix := "L" if side==-1 else "R"
		var shoulder_x: float = side*(shoulders+0.035)
		var arm := _pivot(body,"Arm_"+suffix,Vector3(shoulder_x,1.20,0))
		var thickness := 0.062*lerpf(0.85,1.2,float(profile.build)/100)
		_rod(arm,Vector3.ZERO,Vector3(side*0.023,-0.25,0.008),thickness,skin)
		_ellipsoid(arm,Vector3(side*0.023,-0.25,0.008),Vector3.ONE*thickness,skin)
		_rod(arm,Vector3(side*0.023,-0.25,0.008),Vector3(side*0.018,-0.43,0.025),thickness*0.81,skin)
		var sleeve_length := 0.15 if int(outfit.top) in [0,1] else 0.44
		if int(outfit.top) not in [5,7]:
			_loft(arm,Vector3.ZERO,[[-sleeve_length,thickness*1.18,thickness*1.18,side*0.018,0.02],[-sleeve_length*0.56,thickness*1.28,thickness*1.28,side*0.02,0.008],[-0.09,thickness*1.26,thickness*1.32,side*0.006,0.002],[0.015,thickness*1.08,thickness*1.14],[0.045,thickness*0.3,thickness*0.4]],top)
			if int(outfit.pattern)==2: _loft(arm,Vector3.ZERO,[[-sleeve_length,thickness*1.14,thickness*1.14],[-sleeve_length+0.025,thickness*1.14,thickness*1.14]],trim)
		_ellipsoid(arm,Vector3(side*0.018,-0.47,0.027),Vector3(0.045,0.058,0.029),skin)
		for finger in range(4):
			_ellipsoid(arm,Vector3(side*0.018+(finger-1.5)*0.018,-0.525+absf(finger-1.5)*0.006,0.035),Vector3(0.011,0.034,0.013),skin)
		_ellipsoid(arm,Vector3(side*-0.027,-0.466,0.044),Vector3(0.017,0.034,0.019),skin)
		var lx: float = side*0.09*hip
		var leg := _pivot(body,"Leg_"+suffix,Vector3(lx,0.755,0))
		var leg_width := 0.076*lerpf(0.85,1.25,float(profile.build)/100)
		var bare := int(outfit.bottom) in [2,3,4,7]
		_loft(leg,Vector3.ZERO,[[-0.64,leg_width*0.63,leg_width*0.70],[-0.42,leg_width*0.85,leg_width*0.94],[-0.31,leg_width*0.79,leg_width*0.90],[-0.12,leg_width*1.15,leg_width*1.12],[0.035,leg_width*1.16,leg_width*1.22]],skin if bare else bottom)
		if int(outfit.bottom) in [2,7]: _loft(leg,Vector3.ZERO,[[-0.27,leg_width*1.20,leg_width*1.20],[0.035,leg_width*1.23,leg_width*1.25]],bottom)
		var shoe_kind := int(outfit.shoes)
		_ellipsoid(leg,Vector3(0,-0.683,0.049),Vector3(0.077,0.066,0.147),skin if shoe_kind in [4,6] else shoe)
		if shoe_kind!=6:
			_ellipsoid(leg,Vector3(0,-0.730,0.052),Vector3(0.081,0.025,0.153),Color("d3c6ad") if shoe_kind==0 else shoe.darkened(0.2))
			if shoe_kind==2: _loft(leg,Vector3.ZERO,[[-0.69,0.077,0.085],[-0.46,0.078,0.077]],shoe)
			if shoe_kind in [0,1]:
				for zz in [0.025,0.055,0.085]: _rod(leg,Vector3(-0.035,-0.62,zz),Vector3(0.035,-0.62,zz+0.01),0.004,trim)
			if shoe_kind==4:
				for zz in [0.04,0.11]: _ellipsoid(leg,Vector3(0,-0.642,zz),Vector3(0.077,0.016,0.014),shoe)
	var head := _pivot(body,"Head",Vector3(0,1.30,0))
	var face_width := lerpf(0.155,0.193,float(profile.face)/100)
	_ellipsoid(head,Vector3(0,0.205,0),Vector3(face_width,0.213,0.153),skin,true)
	for side in [-1,1]:
		_ellipsoid(head,Vector3(side*face_width,0.19,-0.007),Vector3(0.029,0.048,0.026),skin)
		_ellipsoid(head,Vector3(side*(face_width+0.009),0.191,0.009),Vector3(0.014,0.027,0.012),skin.darkened(0.12))
		var eye := _pivot(head,"Eye_"+("L" if side==-1 else "R"),Vector3(side*0.063,0.227,0.136))
		_ellipsoid(eye,Vector3.ZERO,Vector3(0.030,0.020,0.020),Color("f2ebdc"))
		_ellipsoid(eye,Vector3(0,0,0.017),Vector3(0.013,0.015,0.005),Profile.EYES[int(profile.eyes)])
		_ellipsoid(eye,Vector3(0,0,0.021),Vector3(0.006,0.009,0.003),Color("242622"))
		_ellipsoid(eye,Vector3(-0.004,0.006,0.024),Vector3(0.003,0.003,0.002),Color("fff9ec"))
		_rod(head,Vector3(side*0.063-0.028,0.254,0.142),Vector3(side*0.063+0.025,0.260,0.140),0.007,hair)
		if int(profile.age)==6:
			_rod(head,Vector3(side*0.095,0.208,0.124),Vector3(side*0.12,0.201,0.112),0.0025,skin.darkened(0.2))
	var nose_size := lerpf(0.80,1.30,float(profile.nose)/100)
	_ellipsoid(head,Vector3(0,0.194,0.140),Vector3(0.022*nose_size,0.042,0.029*nose_size),skin)
	_ellipsoid(head,Vector3(0,0.166,0.168),Vector3(0.029*nose_size,0.022,0.023*nose_size),skin)
	_ellipsoid(head,Vector3(0,0.112,0.136),Vector3(0.035,0.010,0.009),skin.darkened(0.25).lerp(Color("a96562"),0.22))
	_ellipsoid(head,Vector3(0,0.102,0.135),Vector3(0.028,0.008,0.008),skin.darkened(0.13).lerp(Color("c28476"),0.25))
	_hair(head,int(profile.hairstyle),hair)
	var accessory := int(outfit.accessory)
	if accessory in [1,2]:
		for side in [-1,1]:
			if accessory==1: _ring(head,Vector3(side*0.064,0.227,0.165),0.036,0.0035,trim)
			else:
				for yy in [0.201,0.251]: _rod(head,Vector3(side*0.064-0.034,yy,0.164),Vector3(side*0.064+0.034,yy,0.164),0.0035,trim)
				for xx in [-0.034,0.034]: _rod(head,Vector3(side*0.064+xx,0.201,0.164),Vector3(side*0.064+xx,0.251,0.164),0.0035,trim)
			_rod(head,Vector3(side*0.098,0.235,0.162),Vector3(side*face_width,0.236,0),0.0035,trim)
		_rod(head,Vector3(-0.029,0.231,0.167),Vector3(0.029,0.231,0.167),0.0035,trim)
	elif accessory==3:
		for side in [-1,1]: _rod(torso,Vector3(side*0.073,0.22,0.096),Vector3(0,0.08,depth+0.01),0.003,trim)
		_ellipsoid(torso,Vector3(0,0.075,depth+0.014),Vector3(0.017,0.022,0.008),trim)
	elif accessory==4:
		for side in [-1,1]: _ellipsoid(head,Vector3(side*face_width,0.158,0.020),Vector3(0.010,0.011,0.008),trim)
	# Children have age-specific proportions, not just miniature adult bodies.
	var age := int(profile.age)
	if age<=2:
		head.scale=Vector3.ONE*(1.25 if age<=1 else 1.10)
	if age==6: head.rotation.x=0.035; torso.rotation.x=0.025
	body.scale=Vector3.ONE*Profile.height_scale(profile)
	body.set_meta("age",age)
	# Merge static surfaces per material under each articulated part. Eyes stay
	# separate for blinks; limb pivots remain compatible with activity animation.
	_merge_parts(body)
	return body

func _pivot(parent: Node3D, label: String, position: Vector3) -> Node3D:
	var node := Node3D.new(); node.name=label; node.position=position; parent.add_child(node); return node

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new(); material.albedo_color=color; material.roughness=0.82
		_materials[key]=material
	return _materials[key]

func _mesh(parent: Node3D, mesh: Mesh, color: Color, position: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh=mesh; node.material_override=_material(color); node.position=position; parent.add_child(node); return node

func _ellipsoid(parent: Node3D, position: Vector3, size: Vector3, color: Color, detailed: bool=false) -> MeshInstance3D:
	if _sphere==null:
		_sphere=SphereMesh.new(); _sphere.radius=1; _sphere.height=2; _sphere.radial_segments=16 if high_detail else 12; _sphere.rings=8 if high_detail else 6
	if detailed and _smooth_sphere==null:
		_smooth_sphere=SphereMesh.new(); _smooth_sphere.radius=1; _smooth_sphere.height=2; _smooth_sphere.radial_segments=32 if high_detail else 20; _smooth_sphere.rings=20 if high_detail else 12
	var node := _mesh(parent,_smooth_sphere if detailed else _sphere,color,position); node.scale=size; return node

func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=start.distance_to(end); mesh.radial_segments=10; mesh.rings=1
	var node := _mesh(parent,mesh,color,(start+end)*0.5)
	node.quaternion=Quaternion(Vector3.UP,(end-start).normalized())

func _loft(parent: Node3D, offset: Vector3, rings: Array, color: Color) -> void:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 24 if high_detail else 16
	for row in range(rings.size()-1):
		for segment in range(segments):
			var a := float(segment)*TAU/segments; var b := float(segment+1)*TAU/segments
			var low: Array=rings[row]; var high: Array=rings[row+1]
			var points := [Vector3(cos(a)*low[1],low[0],sin(a)*low[2]),Vector3(cos(b)*low[1],low[0],sin(b)*low[2]),Vector3(cos(a)*high[1],high[0],sin(a)*high[2]),Vector3(cos(b)*high[1],high[0],sin(b)*high[2])]
			for index in [0,1,2,1,3,2]:
				var ring: Array=low if index<2 else high
				var center := Vector3(float(ring[3]) if ring.size()>3 else 0.0,0,float(ring[4]) if ring.size()>4 else 0.0)
				tool.add_vertex(points[index]+offset+center)
	# Cap both ends so wardrobe silhouettes remain solid from above and below.
	for edge in [0,rings.size()-1]:
		var ring: Array=rings[edge]
		for segment in range(segments):
			var a := float(segment)*TAU/segments; var b := float(segment+1)*TAU/segments
			var points := [Vector3(0,ring[0],0),Vector3(cos(a)*ring[1],ring[0],sin(a)*ring[2]),Vector3(cos(b)*ring[1],ring[0],sin(b)*ring[2])]
			var center := Vector3(float(ring[3]) if ring.size()>3 else 0.0,0,float(ring[4]) if ring.size()>4 else 0.0)
			for index in ([0,2,1] if edge==0 else [0,1,2]): tool.add_vertex(points[index]+offset+center)
	tool.generate_normals(); _mesh(parent,tool.commit(),color)

func _hair(parent: Node3D, style: int, color: Color) -> void:
	if style==9: return
	_ellipsoid(parent,Vector3(0,0.351,-0.022),Vector3(0.183,0.091,0.161),color)
	# Fitted scalp shell: a raised hairline in front, coverage behind the ears.
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3]=[]
	for row in range(13):
		for column in range(33):
			var angle := float(column)*TAU/32
			var extent := lerpf(2.08,1.06,maxf(0,sin(angle)))
			var polar := float(row)/12.0*extent
			points.append(Vector3(cos(angle)*sin(polar)*0.181,0.21+cos(polar)*0.216,sin(angle)*sin(polar)*0.165-0.008))
	for row in range(12):
		for column in range(32):
			var index := row*33+column
			for next in [index,index+33,index+1,index+1,index+33,index+34]: tool.add_vertex(points[next])
	tool.generate_normals(); _mesh(parent,tool.commit(),color)
	match style:
		0:
			for index in range(5):
				var lock := _ellipsoid(parent,Vector3(-0.09+index*0.033,0.374+index*0.006,0.082),Vector3(0.065,0.036,0.092),color.lightened(index*0.012)); lock.rotation.z=-0.35
		1,4:
			for index in range(4):
				var fringe := _ellipsoid(parent,Vector3(-0.10+index*0.046,0.357+index*0.008,0.095),Vector3(0.066,0.036,0.078),color.lightened(index*0.008)); fringe.rotation.z=-0.3
			var length := 0.15 if style==1 else 0.36
			for index in range(11):
				var angle := PI+float(index)*PI/10
				_ellipsoid(parent,Vector3(cos(angle)*0.153,0.25-length*0.6,sin(angle)*0.125-0.012),Vector3(0.054,length,0.068),color.lightened((index%3)*0.018))
			for side in [-1,1]: _ellipsoid(parent,Vector3(side*0.166,0.19-length*0.42,0.007),Vector3(0.044,length*0.9,0.069),color)
		2,7:
			for index in range(42):
				var angle := index*2.39996
				var yy := 1.0-float(index)/42*1.35
				var radius := sqrt(1.0-yy*yy)
				var p := Vector3(cos(angle)*radius*0.181,0.21+yy*0.218,sin(angle)*radius*0.164)
				if p.z>0.06 and p.y<0.32: continue
				_ellipsoid(parent,p,Vector3.ONE*(0.054 if style==2 else 0.069),color.lightened((index%3)*0.016))
		5:
			_ellipsoid(parent,Vector3(0,0.29,-0.179),Vector3(0.083,0.075,0.062),color)
			for index in range(5): _ellipsoid(parent,Vector3(0.025*sin(index),0.26-index*0.055,-0.19-index*0.008),Vector3(0.060-index*0.006,0.068,0.045),color)
		6: _ellipsoid(parent,Vector3(0,0.40,-0.11),Vector3(0.094,0.088,0.086),color)
		8:
			for side in [-1,1]:
				for index in range(8): _ellipsoid(parent,Vector3(side*(0.159+sin(index*PI)*0.012),0.26-index*0.042,-0.05),Vector3(0.042,0.034,0.040),color.lightened((index%2)*0.03))
				_ellipsoid(parent,Vector3(side*0.16,-0.067,-0.05),Vector3(0.03,0.015,0.032),Color("c29a60"))

func _ring(parent: Node3D, position: Vector3, radius: float, thickness: float, color: Color) -> void:
	var mesh := TorusMesh.new(); mesh.inner_radius=radius-thickness; mesh.outer_radius=radius+thickness; mesh.rings=24; mesh.ring_segments=6
	var node := _mesh(parent,mesh,color,position); node.rotation.x=PI/2

func _merge_parts(parent: Node3D) -> void:
	var groups := {}
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			var material: StandardMaterial3D=child.material_override
			var key := material.albedo_color.to_html()
			if not groups.has(key):
				var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); tool.set_material(material); groups[key]=tool
			for surface in range(child.mesh.get_surface_count()): groups[key].append_from(child.mesh,surface,child.transform)
			parent.remove_child(child); child.free()
		elif child is Node3D: _merge_parts(child)
	if not groups.is_empty():
		var combined := ArrayMesh.new()
		for tool: SurfaceTool in groups.values(): tool.commit(combined)
		var instance := MeshInstance3D.new(); instance.name="Geometry"; instance.mesh=combined; parent.add_child(instance)

func bassinet() -> Node3D:
	var node := Node3D.new(); node.name="Bassinet"
	var mattress := BoxMesh.new(); mattress.size=Vector3(0.55,0.10,0.98)
	_mesh(node,mattress,Color("efe5ce"),Vector3(0,0.58,0))
	for side in [-1,1]:
		for zz in [-0.42,0.42]: _rod(node,Vector3(side*0.26,0.02,zz),Vector3(side*0.26,0.80,zz),0.025,Color("ba9870"))
		for yy in [0.57,0.78]: _rod(node,Vector3(side*0.28,yy,-0.49),Vector3(side*0.28,yy,0.49),0.024,Color("ba9870"))
		for index in range(7): _rod(node,Vector3(side*0.28,0.58,-0.42+index*0.14),Vector3(side*0.28,0.78,-0.42+index*0.14),0.012,Color("c7a882"))
		_rod(node,Vector3(-0.28,0.78,side*0.49),Vector3(0.28,0.78,side*0.49),0.025,Color("ba9870"))
	_merge_parts(node)
	return node
