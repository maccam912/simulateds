extends Node3D
## Dynamic build/route feedback shares the world's depth buffer. Ground marks
## remain below furniture and residents instead of painting across their bodies.
var _vertices := PackedVector3Array()
var _colors := PackedColorArray()
var _mesh := ArrayMesh.new()
var _instance: MeshInstance3D
var _material: StandardMaterial3D

func _ready() -> void:
	_ensure_surface()

func _ensure_surface() -> void:
	if _instance != null: return
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	_material.roughness = 1.0
	_instance = MeshInstance3D.new()
	_instance.name = "GroundFeedbackGeometry"
	_instance.mesh = _mesh
	_instance.material_override = _material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instance)

func begin() -> void:
	_vertices.clear()
	_colors.clear()

func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	if color.a <= 0.0: return
	_vertices.append(a); _vertices.append(b); _vertices.append(c)
	_colors.append(color); _colors.append(color); _colors.append(color)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(a,b,c,color)
	_triangle(a,c,d,color)

func diamond(x: float, z: float, w: float, d: float, color: Color,
		outline: Color = Color.TRANSPARENT, y: float = 0.065, width: float = 0.018) -> void:
	var a := Vector3(x,y,z)
	var b := Vector3(x+w,y,z)
	var c := Vector3(x+w,y,z+d)
	var e := Vector3(x,y,z+d)
	_quad(a,e,c,b,color)
	if outline.a > 0.0:
		# A slight lift keeps coincident fill/outline edges stable at every zoom.
		var lift := Vector3(0,0.002,0)
		line(a+lift,b+lift,outline,width)
		line(b+lift,c+lift,outline,width)
		line(c+lift,e+lift,outline,width)
		line(e+lift,a+lift,outline,width)

func line(from: Vector3, to: Vector3, color: Color, width: float = 0.018) -> void:
	var direction := to-from
	if direction.length_squared() < 0.00000001 or color.a <= 0.0 or width <= 0.0: return
	var side := Vector3.UP.cross(direction)
	if side.length_squared() < 0.00000001: side = Vector3.RIGHT
	side = side.normalized()*width*0.5
	_quad(from-side,to-side,to+side,from+side,color)

func box(x: float, z: float, w: float, d: float, height: float,
		color: Color, base: float = 0.04) -> void:
	var a := Vector3(x,base,z)
	var b := Vector3(x+w,base,z)
	var c := Vector3(x+w,base,z+d)
	var e := Vector3(x,base,z+d)
	var up := Vector3(0,height,0)
	_quad(a+up,e+up,c+up,b+up,color)
	_quad(a,b,b+up,a+up,color)
	_quad(b,c,c+up,b+up,color)
	_quad(c,e,e+up,c+up,color)
	_quad(e,a,a+up,e+up,color)

func finish() -> void:
	_ensure_surface()
	_mesh.clear_surfaces()
	if _vertices.is_empty(): return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
