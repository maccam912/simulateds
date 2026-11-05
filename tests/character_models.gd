extends SceneTree
const Model = preload("res://game/character_model.gd")
const Profile = preload("res://game/character_profile.gd")
const Appearance = preload("res://game/appearance.gd")
var largest := 0
var meshes := 0
var world_largest := 0

func _initialize() -> void:
	var generator := Model.new()
	var member := {"id":"model-review","name":"Rowan","appearance":Appearance.defaults({})}
	member.character=Profile.defaults(member)
	for detail in [true,false]:
		generator=Model.new(); generator.high_detail=detail
		for age in range(Profile.AGES.size()):
			for style in range(Profile.HAIRSTYLES.size()):
				member.character.age=age; member.character.hairstyle=style
				member.character.height=100 if style%2==0 else 0
				member.character.build=100 if style%3==0 else 0
				member.character.shoulders=0 if style%2==0 else 100
				member.character.hips=100 if style%2==0 else 0
				var occasion: String=Profile.OCCASIONS[style%Profile.OCCASIONS.size()]
				var original := JSON.stringify(member)
				var model := generator.build(member,occasion)
				assert(JSON.stringify(member)==original,"Geometry production is a read-only projection of choices")
				for pivot: String in ["Torso","Head","Arm_L","Arm_R","Leg_L","Leg_R"]: assert(model.has_node(pivot))
				meshes=0
				var result := _inspect(model,Transform3D.IDENTITY)
				assert(result.triangles>1000 and result.triangles< (36000 if detail else 14000) and meshes<=10,"Bounded true geometry at both camera detail levels")
				assert(result.bounds.size.y>0.5 and result.bounds.size.y<2.3)
				assert(absf(result.bounds.position.y)<0.015,"Feet meet the floor at every age and height")
				if detail: largest=maxi(largest,result.triangles)
				else: world_largest=maxi(world_largest,result.triangles)
				model.free()
	var legacy := {"id":"legacy-review","appearance":{"skin":5,"hair":4,"shirt":7,"style":3}}
	var original_legacy := JSON.stringify(legacy)
	var legacy_model := generator.build(legacy)
	assert(legacy_model.has_node("Head/Eye_L") and legacy_model.has_node("Head/Eye_R"),"Old saves receive the same sculpted face")
	assert(JSON.stringify(legacy)==original_legacy,"Rendering cannot add a character profile to a legacy save")
	legacy_model.free()
	var voice := preload("res://game/character_voice.gd").sample(member.character)
	assert(voice.get_length()>1.0 and voice.get_length()<1.5)
	print("CHARACTER_MODELS_PASS studio_max_triangles=",largest," world_max_triangles=",world_largest)
	quit()

func _inspect(node: Node3D, parent: Transform3D) -> Dictionary:
	assert(not node is Sprite3D)
	var pose := parent*node.transform
	var result := {"triangles":0,"bounds":AABB()}; var found := false
	if node is MeshInstance3D:
		meshes+=1
		result.bounds=pose*node.mesh.get_aabb(); found=true
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			result.triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: assert(normal.is_finite())
	for child: Node in node.get_children():
		if child is Node3D:
			var next := _inspect(child,pose)
			result.triangles+=next.triangles
			if next.triangles>0:
				result.bounds=result.bounds.merge(next.bounds) if found else next.bounds; found=true
	return result
