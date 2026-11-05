extends RefCounted
## Original parametric solid geometry, shared by the dressing room and live world.
## This editable source is the asset master. No image planes or external assets.
const Profile = preload("res://game/character_profile.gd")
const Appearance = preload("res://game/appearance.gd")
var _materials := {}
var high_detail := true
var _sphere: SphereMesh
var _smooth_sphere: SphereMesh
var _face_width := 0.16
const FACE_RINGS := [[0.012,0.025,0.065,0,0.018],[0.030,0.078,0.092,0,0.012],[0.070,0.118,0.113],[0.125,0.145,0.128],[0.183,0.163,0.142],[0.235,0.161,0.143],[0.290,0.156,0.139],[0.344,0.148,0.130],[0.389,0.116,0.103],[0.414,0.062,0.058],[0.422,0.001,0.001]]

func build(member: Dictionary, occasion: String="") -> Node3D:
	var profile := Profile.of(member)
	var look := Appearance.of(member)
	var outfit: Dictionary=profile.outfits[profile.wearing if occasion.is_empty() else occasion]
	var skin: Color=Appearance.SKIN[int(look.skin)]
	var hair: Color=Appearance.HAIR[int(look.hair)]
	var top: Color=Profile.COLORS[int(outfit.top_color)] if member.has("character") else Appearance.SHIRT[int(look.shirt)]
	var bottom: Color=Profile.COLORS[int(outfit.bottom_color)]
	var shoe: Color=Profile.COLORS[int(outfit.shoe_color)]
	var trim: Color=Profile.COLORS[int(outfit.accessory_color)]
	var body := Node3D.new(); body.name="Body"
	var broad := lerpf(0.82,1.22,float(profile.shoulders)/100.0)
	var build_value := lerpf(0.78,1.40,float(profile.build)/100.0)
	var hip := lerpf(0.83,1.25,float(profile.hips)/100.0)
	var torso := _pivot(body,"Torso",Vector3(0,1.02,0))
	var shoulders := 0.218*broad*lerpf(0.94,1.12,float(profile.build)/100)
	var waist := 0.164*build_value
	var hips := 0.186*hip*lerpf(0.95,1.10,float(profile.build)/100)
	var depth := 0.116*build_value
	# Soft tailoring: a shaped shoulder and open neck, with a shallow ribbed hem.
	var top_kind := int(outfit.top)
	var hem := 0.77 if top_kind in [3,4] else 0.82
	var shirt_rings := [[hem,hips,depth],[hem+0.025,hips*1.015,depth*1.02],[0.92,waist,depth],[1.06,waist*1.035,depth*1.04],[1.17,shoulders*0.92,depth],[1.22,shoulders*0.99,depth*0.91],[1.25,shoulders*0.83,depth*0.74],[1.275,0.076,0.064]]
	_loft(torso,Vector3(0,-1.02,0),shirt_rings,top)
	_loft(torso,Vector3(0,-1.02,0),[[1.248,0.063,0.053],[1.31,0.059,0.053],[1.36,0.072,0.061]],skin)
	_loft(torso,Vector3(0,-1.02,0),[[1.262,0.085,0.069],[1.275,0.078,0.067],[1.282,0.074,0.062]],top.darkened(0.16))
	_loft(torso,Vector3(0,-1.02,0),[[hem,hips*1.006,depth*1.01],[hem+0.017,hips*1.02,depth*1.03]],top.darkened(0.10))
	if top_kind in [1,3,4,6]:
		for side in [-1,1]:
			# Pointed cloth collar, rather than a pair of beads at the throat.
			_patch(torso,[Vector3(side*0.014,0.251,0.069),Vector3(side*0.070,0.248,0.069),Vector3(side*0.101,0.185,0.106),Vector3(side*0.038,0.203,0.114)],top.lightened(0.13))
		for yy in [0.14,0.06,-0.02,-0.10]: _ellipsoid(torso,Vector3(0,yy,depth+0.004),Vector3(0.005,0.005,0.003),trim)
		_rod(torso,Vector3(0,0.17,depth+0.002),Vector3(0,hem-1.02,depth+0.002),0.0025,top.darkened(0.10))
	if top_kind in [3,4]:
		for side in [-1,1]:
			_patch(torso,[Vector3(side*0.075,0.235,depth*0.77),Vector3(side*0.12,0.17,depth*0.99),Vector3(side*0.038,-0.03,depth*1.07),Vector3(side*0.025,0.16,depth*1.06)],top.lightened(0.08))
			_rod(torso,Vector3(side*waist*0.38,-0.10,depth),Vector3(side*waist*0.84,-0.095,depth),0.005,top.darkened(0.18))
	elif top_kind==0:
		# A small chest pocket gives the everyday tee a designed asymmetry.
		_patch(torso,[Vector3(-0.13,0.10,depth*0.89),Vector3(-0.065,0.10,depth*1.01),Vector3(-0.068,0.045,depth*1.025),Vector3(-0.098,0.032,depth*0.99),Vector3(-0.128,0.046,depth*0.93)],top.lightened(0.045))
	if int(outfit.pattern)==1:
		for yy in [0.91,0.98,1.05,1.12]:
			var a := _sample_rings(shirt_rings,yy)
			var b := _sample_rings(shirt_rings,yy+0.014)
			a[1]*=1.012; a[2]*=1.012; b[1]*=1.012; b[2]*=1.012
			_loft(torso,Vector3(0,-1.02,0),[a,b],trim)
	elif int(outfit.pattern)==2:
		_loft(torso,Vector3(0,-1.02,0),[[hem,hips*1.02,depth*1.035],[hem+0.025,hips*1.025,depth*1.035]],trim)
	# Waistband and real skirt volume; legs remain articulated underneath.
	_loft(torso,Vector3(0,-1.02,0),[[0.73,hips*0.98,depth*0.95],[0.81,hips,depth*0.99]],bottom)
	if int(outfit.bottom) in [3,4]:
		var length := 0.39 if int(outfit.bottom)==3 else 0.15
		_loft(torso,Vector3(0,-1.02,0),[[length,hips*1.48,depth*1.4],[0.62,hips*1.14,depth*1.15],[0.80,hips,depth]],bottom)
		for side in [-1,1]: _rod(torso,Vector3(side*hips*1.3,length-1.02,depth*0.52),Vector3(side*hips*0.9,-0.24,depth*0.54),0.004,bottom.lightened(0.13))
	for side in [-1,1]:
		var suffix := "L" if side==-1 else "R"
		var shoulder_x: float = side*(shoulders+0.015)
		var arm := _pivot(body,"Arm_"+suffix,Vector3(shoulder_x,1.20,0))
		var thickness := 0.062*lerpf(0.85,1.2,float(profile.build)/100)
		# A continuous forearm/elbow silhouette avoids the old ball-joint effect.
		var sleeve_length := 0.145 if top_kind in [0,1] else 0.435
		var arm_rings := [[-0.465,0.030,0.026,side*0.016,0.035],[-0.40,thickness*0.66,thickness*0.64,side*0.02,0.028],[-0.31,thickness*0.88,thickness*0.82,side*0.024,0.014],[-0.235,thickness*0.81,thickness*0.85,side*0.022,0.0],[-0.12,thickness*1.02,thickness*1.02,side*0.01,0],[0.005,thickness*1.04,thickness*1.08],[0.042,0.028,0.034]]
		if top_kind not in [5,7]:
			var end_ring := _sample_rings(arm_rings,-sleeve_length+0.008)
			arm_rings=arm_rings.filter(func(ring): return ring[0]<-sleeve_length+0.008)
			arm_rings.append(end_ring)
		_loft(arm,Vector3.ZERO,arm_rings,skin)
		if top_kind not in [5,7]:
			var sleeve_width := thickness*(1.13 if sleeve_length<0.2 else 0.86)
			_loft(arm,Vector3.ZERO,[[-sleeve_length,sleeve_width,sleeve_width,side*0.018,0.024],[-sleeve_length+0.024,sleeve_width*1.04,sleeve_width*1.04,side*0.018,0.02],[-0.10,thickness*1.19,thickness*1.22,0,0],[0.012,thickness*1.20,thickness*1.23,-side*0.025,0],[0.049,thickness*0.71,thickness*0.78,-side*0.034,0]],top)
			_loft(arm,Vector3.ZERO,[[-sleeve_length,sleeve_width*1.012,sleeve_width*1.012,side*0.018,0.024],[-sleeve_length+0.016,sleeve_width*1.045,sleeve_width*1.045,side*0.018,0.02]],trim if int(outfit.pattern)==2 else top.darkened(0.12))
		_loft(arm,Vector3.ZERO,[[-0.523,0.030,0.018,side*0.014,0.036],[-0.49,0.039,0.023,side*0.016,0.033],[-0.45,0.028,0.025,side*0.016,0.031]],skin)
		for finger in range(4):
			_ellipsoid(arm,Vector3(side*0.014+(finger-1.5)*0.017,-0.534+absf(finger-1.5)*0.006,0.038),Vector3(0.009,0.026,0.011),skin)
		var thumb := _ellipsoid(arm,Vector3(side*-0.021,-0.491,0.048),Vector3(0.014,0.032,0.016),skin)
		thumb.rotation.z=side*0.35
		var lx: float = side*0.09*hip
		var leg := _pivot(body,"Leg_"+suffix,Vector3(lx,0.755,0))
		var leg_width := 0.076*lerpf(0.85,1.25,float(profile.build)/100)
		var bare := int(outfit.bottom) in [2,3,4,7]
		_loft(leg,Vector3.ZERO,[[-0.64,leg_width*0.63,leg_width*0.70],[-0.42,leg_width*0.85,leg_width*0.94],[-0.31,leg_width*0.79,leg_width*0.90],[-0.12,leg_width*1.15,leg_width*1.12],[0.035,leg_width*1.16,leg_width*1.22]],skin if bare else bottom)
		if int(outfit.bottom) in [2,7]: _loft(leg,Vector3.ZERO,[[-0.27,leg_width*1.20,leg_width*1.20],[0.035,leg_width*1.23,leg_width*1.25]],bottom)
		var shoe_kind := int(outfit.shoes)
		_loft(leg,Vector3.ZERO,[[-0.746,0.067,0.130,0,0.047],[-0.72,0.077,0.145,0,0.047],[-0.685,0.073,0.133,0,0.044],[-0.657,0.061,0.098,0,0.023],[-0.624,0.048,0.055,0,0.001]],skin if shoe_kind in [4,6] else shoe)
		if shoe_kind!=6:
			_loft(leg,Vector3.ZERO,[[-0.755,0.069,0.132,0,0.047],[-0.746,0.080,0.148,0,0.047],[-0.727,0.079,0.147,0,0.047]],Color("d3c6ad") if shoe_kind==0 else shoe.darkened(0.2))
			if shoe_kind==2: _loft(leg,Vector3.ZERO,[[-0.69,0.077,0.085],[-0.46,0.078,0.077]],shoe)
			if shoe_kind in [0,1]:
				for zz in [0.025,0.055,0.085]: _rod(leg,Vector3(-0.030,-0.646-zz*0.22,zz),Vector3(0.030,-0.646-zz*0.22,zz+0.008),0.004,trim)
			if shoe_kind==4:
				for zz in [0.04,0.11]: _ellipsoid(leg,Vector3(0,-0.642,zz),Vector3(0.077,0.016,0.014),shoe)
	var head := _pivot(body,"Head",Vector3(0,1.30,0))
	_face_width=lerpf(0.147,0.177,float(profile.face)/100)
	_face(head,profile,skin,hair)
	_hair(head,int(profile.hairstyle),hair)
	var face_width := _face_width
	var accessory := int(outfit.accessory)
	if accessory in [1,2]:
		for side in [-1,1]:
			if accessory==1: _ring(head,Vector3(side*0.064,0.232,0.170),0.036,0.0035,trim)
			else:
				for yy in [0.208,0.256]: _rod(head,Vector3(side*0.064-0.034,yy,0.170),Vector3(side*0.064+0.034,yy,0.170),0.0035,trim)
				for xx in [-0.034,0.034]: _rod(head,Vector3(side*0.064+xx,0.201,0.164),Vector3(side*0.064+xx,0.251,0.164),0.0035,trim)
			_rod(head,Vector3(side*0.098,0.238,0.17),Vector3(side*face_width,0.238,0),0.0035,trim)
		_rod(head,Vector3(-0.029,0.235,0.173),Vector3(0.029,0.235,0.173),0.0035,trim)
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

# Smooth indexed surfaces carry authored normals, including the radial seam.
# All geometry remains solid mesh under the established animation pivots.
func _grid(parent: Node3D, points: Array[Vector3], rows: int, columns: int, color: Color, wrap: bool=false) -> MeshInstance3D:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows):
		for col in range(columns):
			var left := (col-1+columns-1)%(columns-1) if wrap else maxi(0,col-1)
			var right := (col+1)%(columns-1) if wrap else mini(columns-1,col+1)
			var across := points[row*columns+right]-points[row*columns+left]
			var along := points[mini(rows-1,row+1)*columns+col]-points[maxi(0,row-1)*columns+col]
			var normal := along.cross(across).normalized()
			if normal.length_squared()<0.5: normal=Vector3.UP
			tool.set_normal(normal); tool.add_vertex(points[row*columns+col])
	for row in range(rows-1):
		for col in range(columns-1):
			var at := row*columns+col
			for index in [at,at+1,at+columns,at+1,at+columns+1,at+columns]: tool.add_index(index)
	return _mesh(parent,tool.commit(),color)

func _sample_rings(rings: Array, height: float) -> Array:
	for row in range(rings.size()-1):
		if height>float(rings[row+1][0]): continue
		var t := inverse_lerp(float(rings[row][0]),float(rings[row+1][0]),height)
		var result := [height]
		for axis in range(1,5):
			var values := []
			for index in [maxi(0,row-1),row,row+1,mini(rings.size()-1,row+2)]:
				values.append(float(rings[index][axis]) if rings[index].size()>axis else 0.0)
			result.append(clampf(cubic_interpolate(values[1],values[2],values[0],values[3],t),minf(values[1],values[2]),maxf(values[1],values[2])))
		return result
	return rings.back()

func _loft(parent: Node3D, offset: Vector3, rings: Array, color: Color) -> void:
	var segments := 24 if high_detail else 16
	var steps := 3 if high_detail else 1
	var samples := []
	for row in range(rings.size()-1):
		for step in range(steps): samples.append(_sample_rings(rings,lerpf(rings[row][0],rings[row+1][0],float(step)/steps)))
	samples.append(rings.back())
	var points: Array[Vector3]=[]
	for ring: Array in samples:
		for segment in range(segments+1):
			var a := float(segment)*TAU/segments
			points.append(offset+Vector3(cos(a)*ring[1]+(float(ring[3]) if ring.size()>3 else 0.0),ring[0],sin(a)*ring[2]+(float(ring[4]) if ring.size()>4 else 0.0)))
	_grid(parent,points,samples.size(),segments+1,color,true)
	# Separate planar caps keep the rim crisp without pinching side normals.
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in [0,samples.size()-1]:
		var ring: Array=samples[edge]
		var center := offset+Vector3(float(ring[3]) if ring.size()>3 else 0.0,ring[0],float(ring[4]) if ring.size()>4 else 0.0)
		for segment in range(segments):
			tool.set_normal(Vector3.DOWN if edge==0 else Vector3.UP)
			var triangle := [center,points[edge*(segments+1)+segment],points[edge*(segments+1)+segment+1]]
			for index in ([0,1,2] if edge==0 else [0,2,1]): tool.add_vertex(triangle[index])
	_mesh(parent,tool.commit(),color)

func _patch(parent: Node3D, points: Array, color: Color) -> void:
	# Thin solid cloth detail with an edge, never a camera-facing sprite.
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1,points.size()-1):
		for at in [0,index+1,index]: tool.add_vertex(points[at])
		for at in [0,index,index+1]: tool.add_vertex(points[at]-Vector3(0,0,0.003))
	for index in range(points.size()):
		var a: Vector3=points[index]; var b: Vector3=points[(index+1)%points.size()]
		for point: Vector3 in [a,b,a-Vector3(0,0,0.003),b,b-Vector3(0,0,0.003),a-Vector3(0,0,0.003)]: tool.add_vertex(point)
	tool.generate_normals(); _mesh(parent,tool.commit(),color)

func _curve(parent: Node3D, points: Array[Vector3], widths: Array, depth: float, color: Color) -> void:
	# Elliptical swept volume for brows, eyelids, lips and sculpted hair locks.
	if not high_detail and points.size()>9:
		var sampled: Array[Vector3]=[]; var sampled_widths := []
		for index in range(0,points.size(),2): sampled.append(points[index]); sampled_widths.append(widths[index])
		if (points.size()-1)%2!=0: sampled.append(points.back()); sampled_widths.append(widths.back())
		points=sampled; widths=sampled_widths
	var segments := 10 if high_detail else 8
	var vertices: Array[Vector3]=[]
	for row in range(points.size()):
		var tangent := (points[mini(row+1,points.size()-1)]-points[maxi(row-1,0)]).normalized()
		var across := tangent.cross(Vector3.FORWARD).normalized()
		if across.length_squared()<0.5: across=Vector3.RIGHT
		var normal := across.cross(tangent).normalized()
		for col in range(segments+1):
			var angle := float(col)*TAU/segments
			vertices.append(points[row]+across*cos(angle)*float(widths[row])+normal*sin(angle)*depth*minf(1.0,float(widths[row])/0.008))
	var mesh := _grid(parent,vertices,points.size(),segments+1,color,true)
	if depth<0.008: mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _face(head: Node3D, profile: Dictionary, skin: Color, hair: Color) -> void:
	# Jaw, cheek, temple and forehead are one sculpted surface. The bridge and
	# muzzle are relief in that surface, not spheres attached to an egg.
	var shape := FACE_RINGS
	var rows := 49 if high_detail else 25
	var columns := 65 if high_detail else 33
	var vertices: Array[Vector3]=[]
	var nose := lerpf(0.83,1.24,float(profile.nose)/100)
	for row in range(rows):
		var y := lerpf(0.012,0.422,float(row)/(rows-1))
		var ring := _sample_rings(shape,y)
		for col in range(columns):
			var angle := float(col)*TAU/(columns-1)
			var x: float=cos(angle)*ring[1]*_face_width/0.162
			var front := maxf(0.0,sin(angle))
			var z: float=signf(sin(angle))*pow(absf(sin(angle)),0.65)*ring[2]+(float(ring[4]) if ring.size()>4 else 0.0)
			if front>0:
				z+=pow(front,10)*(0.023*nose*exp(-pow(x/0.023,2)-pow((y-0.208)/0.058,2))+0.022*nose*exp(-pow(x/0.036,2)-pow((y-0.176)/0.030,2))+0.010*exp(-pow(x/0.055,2)-pow((y-0.109)/0.031,2)))
				# Broad cheekbones and quiet inset sockets catch actual scene light.
				z+=0.009*exp(-pow((absf(x)-0.086)/0.040,2)-pow((y-0.18)/0.036,2))*front
				z-=0.006*exp(-pow((absf(x)-0.066)/0.037,2)-pow((y-0.239)/0.025,2))*front
			vertices.append(Vector3(x,y,z))
	_grid(head,vertices,rows,columns,skin,true)
	for side in [-1,1]:
		_ellipsoid(head,Vector3(side*(_face_width-0.003),0.193,-0.003),Vector3(0.024,0.042,0.025),skin,true)
		_ellipsoid(head,Vector3(side*(_face_width+0.002),0.195,0.018),Vector3(0.011,0.025,0.007),skin.darkened(0.13))
		_eye(head,side,Profile.EYES[int(profile.eyes)],skin,hair)
		var brow: Array[Vector3]=[]; var widths := []
		for index in range(9):
			var t := float(index)/8
			brow.append(Vector3(side*(0.032+t*0.071),0.273+sin(t*PI)*0.012-t*0.007,0.141-t*0.019))
			widths.append(0.001+sin(t*PI)*0.006)
		_curve(head,brow,widths,0.003,hair.darkened(0.13))
		if int(profile.age)==6:
			_curve(head,[Vector3(side*0.099,0.232,0.126),Vector3(side*0.114,0.228,0.120),Vector3(side*0.121,0.227,0.114)],[0.0005,0.0016,0.0005],0.001,skin.darkened(0.15))
	var mouth: Array[Vector3]=[]; var widths := []
	for index in range(13):
		var t := float(index)/12; var x := (t-0.5)*0.080
		mouth.append(Vector3(x,0.106+pow(absf(t-0.5)*2,2)*0.008,0.137-absf(x)*0.075))
		widths.append(0.0005+sin(t*PI)*0.0021)
	_curve(head,mouth,widths,0.002,skin.darkened(0.35).lerp(Color("894e49"),0.18))
	for index in range(mouth.size()): mouth[index]+=Vector3(0,-0.0045,0.0005); widths[index]*=1.5
	_curve(head,mouth,widths,0.002,skin.lerp(Color("bf7e71"),0.20))

func _eye(head: Node3D, side: int, iris: Color, skin: Color, hair: Color) -> void:
	var eye := _pivot(head,"Eye_"+("L" if side==-1 else "R"),Vector3(side*0.064,0.234,0.134))
	eye.rotation.y=side*0.22
	# Almond-shaped sclera and fitted lids replace exposed round eyeballs.
	var rows := 9; var columns := 25 if high_detail else 17
	var points: Array[Vector3]=[]
	for row in range(rows):
		var v := float(row)/(rows-1)
		for col in range(columns):
			var u := float(col)/(columns-1); var arc := pow(sin(u*PI),0.8)
			points.append(Vector3((0.5-u)*0.069,lerpf(-0.0105,0.0155,v)*arc,0.002+0.010*sin(v*PI)*arc))
	_grid(eye,points,rows,columns,Color("e8dfcc"))
	_ellipsoid(eye,Vector3(0,0.002,0.012),Vector3(0.0125,0.013,0.0025),iris)
	_ellipsoid(eye,Vector3(0,0.002,0.014),Vector3(0.0062,0.008,0.0015),iris.darkened(0.72))
	_ellipsoid(eye,Vector3(-0.003,0.0065,0.0155),Vector3(0.0025,0.0025,0.001),Color("fff3d9"))
	for upper in [true,false]:
		var lid: Array[Vector3]=[]; var widths := []
		for index in range(17):
			var u := float(index)/16; var arc := pow(sin(u*PI),0.8)
			lid.append(Vector3((u-0.5)*0.071,(0.016 if upper else -0.011)*arc,0.004))
			widths.append(0.0008+sin(u*PI)*(0.0032 if upper else 0.0025))
		_curve(eye,lid,widths,0.0025,skin.darkened(0.24) if upper else skin)

func _hair(parent: Node3D, style: int, color: Color) -> void:
	if style==9: return
	var rows := 23 if high_detail else 15
	var columns := 49 if high_detail else 33
	var points: Array[Vector3]=[]
	var long_hair := style in [1,4]
	for row in range(rows):
		var t := float(row)/(rows-1)
		for col in range(columns):
			var a := float(col)*TAU/(columns-1)
			var front := maxf(0,sin(a))
			var front_extent := 1.12+0.075*cos(a)+0.16*pow(1.0-front,2)
			var extent := lerpf(2.13,front_extent,smoothstep(0.02,0.35,front))
			var polar := (1.0-t)*extent+0.004
			var wave := 1.0+0.018*cos(a*5+polar*2)
			var y := 0.214+cos(polar)*0.230
			var skull := _sample_rings(FACE_RINGS,clampf(y-0.012,0.012,0.422))
			var x: float=cos(a)*maxf(sin(polar)*(_face_width+0.012),skull[1]*_face_width/0.162+0.008)*wave
			var z: float=signf(sin(a))*pow(absf(sin(a)),0.65)*maxf(sin(polar)*0.169,skull[2]+0.014)-0.006
			x*=smoothstep(0.0,0.18,polar); z=(z+0.006)*smoothstep(0.0,0.18,polar)-0.006
			if style==3: x*=0.98; z*=0.98; y-=0.005
			if style in [2,7]:
				var lobes := (sin(a*9.0+polar*5.0)*sin(polar*13.0)+sin(a*13.0-polar*8.0))*0.5
				var volume := 1.08 if style==2 else 1.17
				x*=volume+lobes*0.065; z*=volume+lobes*0.065; y+=sin(polar)*(0.014+lobes*0.014)
			if long_hair and sin(a)<0.10:
				var length := 0.055 if style==1 else 0.25
				y-=length*pow(1.0-t,4)*(1.0-smoothstep(-0.05,0.10,sin(a)))
				x*=1.0+0.09*pow(1.0-t,2); z-=0.020*pow(1.0-t,2)
			# Large quiet flutes read as combed masses, not individual strands.
			var flute := sin(a*13+polar*1.8)*0.0025*sin(polar)
			points.append(Vector3(x+cos(a)*flute,y,z+sin(a)*flute))
	_grid(parent,points,rows,columns,color,true)
	if style in [0,1,4,5,6]:
		# Three swept, tapered locks share one parting and a coherent hairline.
		for lock in range(3):
			var path: Array[Vector3]=[]; var widths := []
			for index in range(17):
				var t := float(index)/16
				path.append(Vector3(lerpf(0.067,-_face_width*0.96,t),0.405-lock*0.019+sin(t*PI)*0.022-t*t*0.065,0.067+lock*0.032+sin(t*PI)*0.025-t*t*0.014))
				widths.append(0.001+pow(sin(t*PI),0.6)*(0.025 if lock<2 else 0.020))
			_curve(parent,path,widths,0.014,color.lightened(lock*0.025))
	if style in [1,4]:
		for side in [-1,1]:
			var path: Array[Vector3]=[]; var widths := []
			for index in range(17):
				var t := float(index)/16; var length := 0.26 if style==1 else 0.48
				path.append(Vector3(side*(_face_width*0.92+sin(t*PI)*0.02),0.34-t*length,0.035+0.020*sin(t*TAU)))
				widths.append(0.001+pow(sin(t*PI),0.4)*0.029)
			_curve(parent,path,widths,0.035,color.lightened(0.025))
	elif style==5:
		_curve(parent,[Vector3(0,0.32,-0.145),Vector3(0,0.29,-0.21),Vector3(0.014,0.19,-0.245),Vector3(0.032,0.06,-0.23),Vector3(0.06,-0.08,-0.19),Vector3(0.065,-0.11,-0.18)],[0.025,0.052,0.053,0.041,0.022,0.001],0.04,color)
		_ellipsoid(parent,Vector3(0,0.29,-0.205),Vector3(0.055,0.014,0.047),Color("886a48"))
	elif style==6:
		_ellipsoid(parent,Vector3(0,0.366,-0.131),Vector3(0.086,0.076,0.081),color,true)
		for index in range(4):
			_curve(parent,[Vector3(-0.055,0.34+index*0.011,-0.165),Vector3(0,0.365+index*0.015,-0.206),Vector3(0.06,0.39,-0.17)],[0.001,0.006,0.001],0.003,color.lightened(0.05))
	elif style==8:
		for side in [-1,1]:
			for strand in range(3):
				var path: Array[Vector3]=[]; var widths := []
				for index in range(33):
					var t := float(index)/32; var a := t*TAU*3+strand*TAU/3
					path.append(Vector3(side*(_face_width+0.009)+sin(a)*0.018,0.25-t*0.36,-0.025+cos(a)*0.018))
					widths.append(0.001+pow(sin(t*PI),0.25)*0.017)
				_curve(parent,path,widths,0.015,color.lightened(strand*0.022))
			_ellipsoid(parent,Vector3(side*(_face_width+0.009),-0.091,-0.025),Vector3(0.029,0.012,0.026),Color("c29a60"))

func _ring(parent: Node3D, position: Vector3, radius: float, thickness: float, color: Color) -> void:
	var mesh := TorusMesh.new(); mesh.inner_radius=radius-thickness; mesh.outer_radius=radius+thickness; mesh.rings=24; mesh.ring_segments=6
	var node := _mesh(parent,mesh,color,position); node.rotation.x=PI/2

func _merge_parts(parent: Node3D) -> void:
	var groups := {}
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			var material: StandardMaterial3D=child.material_override
			# Tiny eyelids/brows must not cast oversized shadow-map artifacts.
			var casts: bool=child.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not str(parent.name).begins_with("Eye_")
			var key := material.albedo_color.to_html()+str(casts)
			if not groups.has(key):
				var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); tool.set_material(material); groups[key]={"tool":tool,"casts":casts}
			for surface in range(child.mesh.get_surface_count()): groups[key].tool.append_from(child.mesh,surface,child.transform)
			parent.remove_child(child); child.free()
		elif child is Node3D: _merge_parts(child)
	for casts in [true,false]:
		var combined := ArrayMesh.new()
		for group: Dictionary in groups.values():
			if group.casts==casts: group.tool.commit(combined)
		if combined.get_surface_count()==0: continue
		var instance := MeshInstance3D.new(); instance.name="Geometry" if casts else "FaceDetails"; instance.mesh=combined
		if not casts: instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)

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
