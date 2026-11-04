extends Control
## Isometric presentation. All mutations are sent as commands by the HUD.
signal tile_clicked(cell: Vector2i)
signal hovered(cell: Vector2i)
signal entity_clicked(target: Dictionary)

const Catalog = preload("res://game/catalog.gd")
const BuildRules = preload("res://game/build_rules.gd")
var world: Dictionary = {}
var lot_id := "lot_1"
var selected_member := ""
var build_kind := "floor"
var build_rotation := 0
var build_object_id := ""
var preview_result: Dictionary = {}
var _preview_signature := ""
var building := false
var zoom := 1.0
var pan := Vector2.ZERO
var hover_cell := Vector2i(-1, -1)
var _dragging := false
var _cell := Vector2(48, 24)
var _origin := Vector2.ZERO
var _font: Font
var _time := 0.0
var _hit_regions: Array = []
var _drawing_target: Dictionary = {}
var hover_target: Dictionary = {}
var _pointer := Vector2(-10000,-10000)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	mouse_exited.connect(func(): hover_cell = Vector2i(-1, -1); hover_target = {}; _pointer = Vector2(-10000,-10000); queue_redraw())

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _layout() -> void:
	# The camera frames the house, not a panel. Ground continues behind the HUD.
	var play_height: float = maxf(360.0, size.y - 160.0)
	var scale_factor: float = minf(size.x / 1000.0, play_height / 510.0) * zoom
	_cell = Vector2(48, 24) * scale_factor
	var focus := Vector2(size.x * 0.5, play_height * 0.53)
	_origin = focus - Vector2(_cell.x * 0.25, _cell.y * 7.75) + pan

func grid_point(x: float, y: float) -> Vector2:
	return _origin + Vector2((x - y) * _cell.x * 0.5, (x + y) * _cell.y * 0.5)

func cell_at(point: Vector2) -> Vector2i:
	var v := point - _origin
	return Vector2i(floori(v.x / _cell.x + v.y / _cell.y), floori(v.y / _cell.y - v.x / _cell.x))

func _input(event: InputEvent) -> void:
	# An overlay can receive the release even when the drag began on the lawn.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		_dragging = false

func _gui_input(event: InputEvent) -> void:
	_layout()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom = minf(1.8, zoom + 0.1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom = maxf(0.65, zoom - 0.1)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var target := hit_target(event.position)
				var cell := cell_at(event.position)
				if building and build_kind=="move" and build_object_id.is_empty() and target.get("type")=="object":
					entity_clicked.emit(target)
				elif not building and not target.is_empty():
					entity_clicked.emit(target)
				elif building and build_kind == "erase" and target.get("type") == "object":
					tile_clicked.emit(Vector2i(int(target.x),int(target.y)))
				elif _in_bounds(cell):
					tile_clicked.emit(cell)
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			pan += event.relative
		_pointer = event.position
		hover_cell = cell_at(event.position)
		hover_target = hit_target(event.position)
		hovered.emit(hover_cell)

func hit_target(point: Vector2) -> Dictionary:
	# Reverse paint order matches what is visibly on top, including elevated
	# surfaces that project onto a completely different floor tile.
	for index in range(_hit_regions.size()-1,-1,-1):
		var region: Dictionary = _hit_regions[index]
		if Geometry2D.is_point_in_polygon(point,region.polygon): return region.target
	return {}

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 16 and cell.y >= 0 and cell.y < 16

func _poly(points: Array, color: Color, outline: Color = Color.TRANSPARENT) -> void:
	var polygon := PackedVector2Array(points)
	if not _drawing_target.is_empty(): _hit_regions.append({"polygon":polygon,"target":_drawing_target})
	draw_colored_polygon(polygon, color)
	if outline.a > 0:
		polygon.append(polygon[0])
		draw_polyline(polygon, outline, 1.0, true)

func _diamond(x: float, y: float, w: float, d: float, color: Color, z: float = 0, outline: Color = Color.TRANSPARENT) -> void:
	var up := Vector2(0, -z)
	_poly([grid_point(x,y)+up, grid_point(x+w,y)+up, grid_point(x+w,y+d)+up, grid_point(x,y+d)+up], color, outline)

func _block(x: float, y: float, w: float, d: float, height: float, color: Color, z: float = 0) -> void:
	var base := Vector2(0, -z)
	var top := Vector2(0, -height-z)
	var a := grid_point(x,y)
	var b := grid_point(x+w,y)
	var c := grid_point(x+w,y+d)
	var e := grid_point(x,y+d)
	_poly([e+top,c+top,c+base,e+base], color.darkened(0.23))
	_poly([c+top,b+top,b+base,c+base], color.darkened(0.38))
	_poly([a+top,b+top,c+top,e+top], color.lightened(0.12), color.darkened(0.12))

func _draw() -> void:
	_hit_regions.clear()
	_drawing_target = {}
	_layout()
	_draw_neighborhood_ground()
	if not world.has("lots") or not world.lots.has(lot_id):
		draw_string(_font, Vector2(40,80), "Preparing your neighborhood…", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("34514c"))
		return
	var lot: Dictionary = world.lots[lot_id]
	var scale_factor := _cell.x / 48.0
	var floors: Dictionary = {}
	var walls: Dictionary = {}
	var doors: Dictionary = {}
	for cell in lot.get("floors", []): floors[Vector2i(int(cell[0]),int(cell[1]))] = true
	for cell in lot.get("walls", []): walls[Vector2i(int(cell[0]),int(cell[1]))] = true
	for cell in lot.get("doors", []): doors[Vector2i(int(cell[0]),int(cell[1]))] = true
	# A property lives in the neighborhood, rather than on an isolated plinth.
	# Lawn is continuous; only construction exposes the editable grid.
	if building:
		_diamond(0,0,16,16,Color(0.89,0.96,0.72,0.045),0,Color(0.95,0.97,0.78,0.65))
	for depth in range(31):
		for x in range(16):
			var y := depth-x
			if y < 0 or y > 15: continue
			var cell := Vector2i(x,y)
			if building:
				_diamond(x,y,1,1,Color.TRANSPARENT,0,Color(0.30,0.41,0.24,0.30))
			# A garden path leads from the front door to the public sidewalk.
			if x == 8 and y >= 11:
				_diamond(x,y,1,1,Color("c5c4a5"),0,Color("b1b496"))
			if floors.has(cell):
				var floor_color := Color("d9bd93") if (x+y)%2==0 else Color("d5b58c")
				_diamond(x,y,1,1,floor_color,1,Color("b59b7c"))
				var a := grid_point(x+0.5,y)+Vector2(0,-1)
				var b := grid_point(x+0.5,y+1)+Vector2(0,-1)
				draw_line(a,b,Color("c6a880"),0.7,true)
	# Planting sits along the property edges without boxing the entire view in.
	for y in [1,3,5,7,9,11]:
		_bush(0.35,float(y),scale_factor)
	for x in [4,7,10,13]:
		_bush(float(x),0.35,scale_factor)
	if Preferences.values.get("quality","high")=="high":
		for location in [Vector2(-3,2), Vector2(2,-3), Vector2(10,-4), Vector2(17,1), Vector2(-3,11)]:
			_tree(location.x,location.y,scale_factor)
	# Paint rear walls first. Near walls use a low cutaway for readable interiors.
	for depth in range(31):
		for x in range(16):
			var y := depth-x
			if y < 0 or y > 15: continue
			var cell := Vector2i(x,y)
			if walls.has(cell):
				var h := (39.0 if y <= 3 or x <= 3 else 8.0)*scale_factor
				_block(x,y,1,1,h,Color("e6e2c6"))
				if h > 20*scale_factor:
					_diamond(x+0.04,y+0.04,0.92,0.92,Color("f6efd7"),h)
			if doors.has(cell):
				_diamond(x,y,1,1,Color("8f6c50"),2*scale_factor)
				_block(x,y,0.12,0.12,33*scale_factor,Color("c7a376"))
	var entities: Array = []
	for obj in lot.get("objects", []):
		entities.append({"depth":float(obj.x)+float(obj.y)+0.5,"object":obj})
	for family in world.get("families", {}).values():
		for member in family.get("members", []):
			if member.lot_id == lot_id:
				entities.append({"depth":float(member.x)+float(member.y)+0.8,"member":member,"family":family})
	entities.sort_custom(func(a,b): return a.depth < b.depth)
	for entity in entities:
		if entity.has("object"):
			_furnishing(entity.object,scale_factor)
		else:
			_resident(entity.member, entity.family,scale_factor)
	hover_target = hit_target(_pointer)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not building and not hover_target.is_empty() else Control.CURSOR_ARROW
	if _in_bounds(hover_cell) and (building or hover_target.is_empty()):
		var tint := Color(0.96,0.99,0.81,0.32)
		var outline := Color("f8f3c7")
		var footprint := Vector2i.ONE
		var preview_cell := hover_cell
		if building and build_kind!="erase" and (build_kind!="move" or not build_object_id.is_empty()):
			_update_preview(lot)
			var kind := build_kind
			if build_kind=="move":
				for object: Dictionary in lot.objects:
					if object.id==build_object_id: kind=str(object.kind)
			footprint=Catalog.footprint(kind,build_rotation)
			tint=Color(0.62,0.88,0.49,0.42) if preview_result.get("ok",false) else Color(0.93,0.32,0.26,0.45)
			outline=Color("d8f1b2") if preview_result.get("ok",false) else Color("ffab8f")
			_draw_preview_label(str(preview_result.get("message","")),bool(preview_result.get("ok",false)))
		elif building and build_kind in ["erase","move"] and hover_target.get("type")=="object":
			preview_cell=Vector2i(int(hover_target.x),int(hover_target.y))
			footprint=Catalog.footprint(str(hover_target.kind),int(hover_target.rotation))
			var item: Dictionary=Catalog.ITEMS[hover_target.kind]
			if build_kind=="erase":
				tint=Color(0.94,0.4,0.3,0.35)
				_draw_preview_label("Sell " + str(item.name) + " · § %d" % int(float(item.cost)*0.6),false)
			else: _draw_preview_label("Move " + str(item.name) + " · Click to select",true)
		elif building and build_kind=="erase": tint=Color(0.94,0.4,0.3,0.35)
		_diamond(preview_cell.x,preview_cell.y,footprint.x,footprint.y,tint,4,outline)
	if not building and not hover_target.is_empty(): _draw_hover()
	if lot.building:
		var badge := Rect2(Vector2(size.x*0.5-150,22),Vector2(300,34))
		draw_style_box(preload("res://game/style.gd").box(Color("eac88c"),17),badge)
		draw_string(_font,badge.position+Vector2(25,23),"UNDER CONSTRUCTION  ·  Lot paused",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("5d4a2d"))


func _update_preview(lot: Dictionary) -> void:
	var signature := str([lot_id,lot.revision,lot.funds,hover_cell,build_kind,build_rotation,build_object_id])
	if signature==_preview_signature: return
	_preview_signature=signature
	var residents: Array=[]
	for family: Dictionary in world.families.values():
		for member: Dictionary in family.members:
			if member.lot_id==lot_id: residents.append(Vector2i(int(member.x),int(member.y)))
	var command := {"type":"move_object" if build_kind=="move" else "place","kind":build_kind,"object_id":build_object_id,"x":hover_cell.x,"y":hover_cell.y,"rotation":build_rotation}
	preview_result=BuildRules.inspect(lot,command,residents)

func _draw_preview_label(message: String, valid: bool) -> void:
	var width := _font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+24
	var position := Vector2(clampf(_pointer.x+16,8,size.x-width-8),clampf(_pointer.y-40,8,size.y-220))
	draw_style_box(preload("res://game/style.gd").box(Color("1c2a2f"),6),Rect2(position,Vector2(width,30)))
	draw_string(_font,position+Vector2(12,20),message,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d8f1b2") if valid else Color("ffab8f"))

func _draw_hover() -> void:
	var title := str(hover_target.get("name",""))
	var detail := "Click to select" if hover_target.get("owner") == Session.profile_id else "Click to chat"
	if hover_target.type == "object":
		var item: Dictionary = Catalog.ITEMS[hover_target.kind]
		title = str(item.name)
		detail = str(item.need).capitalize() + " · Click to use"
		if bool(item.get("exclusive",false)):
			for family: Dictionary in world.families.values():
				for resident: Dictionary in family.members:
					if resident.lot_id == lot_id and resident.task.get("target_id") == hover_target.id:
						detail = "In use by " + str(resident.name) + " · Click to queue"
		var dimensions := Catalog.footprint(str(hover_target.kind),int(hover_target.rotation))
		_diamond(float(hover_target.x),float(hover_target.y),dimensions.x,dimensions.y,Color(0.95,0.95,0.75,0.14),2,Color("fff2bd"))
	var width := maxf(_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x,_font.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x) + 24
	var position := Vector2(clampf(_pointer.x+18,8,size.x-width-8),clampf(_pointer.y-62,8,size.y-220))
	var badge := Rect2(position,Vector2(width,52))
	draw_style_box(preload("res://game/style.gd").box(Color("1c2a2f"),6,Color("71877b")),badge)
	draw_string(_font,position+Vector2(12,20),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f4eedf"))
	draw_string(_font,position+Vector2(12,39),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("bdd89e"))

func _draw_neighborhood_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("8ba36d"))
	# Project the viewport corners back into the map so terrain never ends while
	# panning or zooming. Broad mowing stripes replace the old board-game grid.
	var corners := [cell_at(Vector2(-120,-120)), cell_at(Vector2(size.x+120,-120)), cell_at(size+Vector2(120,120)), cell_at(Vector2(-120,size.y+120))]
	var low_x := 0; var high_x := 0; var low_y := 0; var high_y := 0
	for corner in corners:
		low_x=mini(low_x,corner.x); high_x=maxi(high_x,corner.x)
		low_y=mini(low_y,corner.y); high_y=maxi(high_y,corner.y)
	for x in range(low_x-1,high_x+2):
		var stripe := Color("8ba36d") if posmod(floori(float(x)/3.0),2)==0 else Color("87a169")
		_diamond(x,low_y-1,1,high_y-low_y+3,stripe)
	# The street and pavement extend beyond the parcel along its front edge.
	_diamond(low_x-1,16.1,high_x-low_x+3,1.15,Color("c1bfa8"),0,Color("a2a48e"))
	_diamond(low_x-1,17.25,high_x-low_x+3,3.8,Color("737a70"))
	_diamond(low_x-1,21.05,high_x-low_x+3,1.15,Color("c1bfa8"))
	for x in range(low_x-1,high_x+2):
		draw_line(grid_point(x,16.15),grid_point(x,17.2),Color("aeb09a"),1,true)
		if posmod(x,3)==0:
			_diamond(x,19.1,1.4,0.06,Color("d4cda8"))
	# Small clusters are tied to world coordinates and remain still as the camera moves.
	for x in range(low_x,high_x+1,2):
		for y in range(low_y,high_y+1,2):
			if (x>=0 and x<16 and y>=0 and y<16) or (y>=16 and y<=22): continue
			var seed_value := absi(x*37+y*17)
			if seed_value%5!=0: continue
			var p := grid_point(x+0.37,y+0.62)
			var scale_factor := _cell.x/48.0
			draw_line(p,p+Vector2(-1,-3)*scale_factor,Color(0.36,0.48,0.28,0.40),1,true)
			draw_line(p+Vector2(3,1)*scale_factor,p+Vector2(4,-2)*scale_factor,Color(0.41,0.53,0.31,0.40),1,true)

func _tree(x: float, y: float, s: float) -> void:
	var p := grid_point(x+0.5,y+0.5)
	draw_set_transform(p+Vector2(12,2)*s,0,Vector2(1,0.45))
	draw_circle(Vector2.ZERO,29*s,Color(0.19,0.30,0.17,0.17))
	draw_set_transform(Vector2.ZERO)
	draw_line(p,p+Vector2(0,-45)*s,Color("76654b"),7*s,true)
	draw_circle(p+Vector2(0,-61)*s,27*s,Color("587c4a"))
	draw_circle(p+Vector2(-15,-56)*s,20*s,Color("62864e"))
	draw_circle(p+Vector2(13,-65)*s,21*s,Color("70945a"))
	draw_circle(p+Vector2(-5,-78)*s,18*s,Color("7c9c61"))

func _bush(x: float,y: float,s: float) -> void:
	var p := grid_point(x+0.4,y+0.4)
	draw_set_transform(p,0,Vector2(1,0.45))
	draw_circle(Vector2.ZERO,13*s,Color(0.15,0.25,0.16,0.14))
	draw_set_transform(Vector2.ZERO)
	draw_circle(p+Vector2(0,-9*s),11*s,Color("527c51"))
	draw_circle(p+Vector2(-4,-12)*s,7*s,Color("71985c"))
	draw_circle(p+Vector2(5,-11)*s,5*s,Color("88a96c"))

func _furnishing(obj: Dictionary,s: float) -> void:
	var kind := str(obj.kind)
	var item: Dictionary = Catalog.ITEMS.get(kind,{})
	var dimensions: Array = item.get("size",[1,1])
	var w := float(dimensions[0]); var d := float(dimensions[1])
	if int(obj.get("rotation",0))%2==1:
		var swap := w; w=d; d=swap
	var x := float(obj.x); var y := float(obj.y)
	var color := Color(str(item.get("color","bd9878")))
	_diamond(x+0.12,y+0.2,w,d,Color(0.18,0.17,0.13,0.13))
	_drawing_target = {"type":"object","id":obj.id,"kind":kind,"x":obj.x,"y":obj.y,"rotation":obj.get("rotation",0)}
	match kind:
		"bed":
			_block(x+0.05,y+0.05,w-0.1,d-0.1,10*s,Color("785648"))
			_block(x+0.08,y+0.08,w-0.16,d-0.16,6*s,Color("e9e4cd"),10*s)
			_block(x+0.09,y+d*0.36,w-0.18,d*0.60,3*s,Color("92aaa6"),16*s)
			_block(x+0.16,y+0.13,w-0.32,d*0.18,3*s,Color("faf2d9"),16*s)
			_block(x+0.02,y+0.02,w-0.04,0.12,24*s,Color("967259"))
		"sofa":
			_block(x+0.06,y+0.08,w-0.12,d-0.16,12*s,Color("be7c57"))
			_block(x+0.08,y+0.06,w-0.16,0.2,25*s,Color("d5996e"))
			_block(x+0.08,y+0.29,w-0.16,d-0.4,4*s,Color("e0a576"),12*s)
			_block(x+0.03,y+0.2,0.16,d-0.25,21*s,Color("cb9066"))
			_block(x+w-0.19,y+0.2,0.16,d-0.25,21*s,Color("cb9066"))
		"fridge":
			_block(x+0.1,y+0.1,w-0.2,d-0.2,39*s,Color("cee0d5"))
			var p := grid_point(x+w-0.08,y+d*0.7)
			draw_line(p+Vector2(0,-14*s),p+Vector2(0,-29*s),Color("718c86"),2*s)
		"shower":
			_block(x+0.06,y+0.06,w-0.12,d-0.12,5*s,Color("e4e7da"))
			_block(x+0.06,y+0.06,w-0.12,0.12,42*s,Color("a4c7c3"))
			var p := grid_point(x+0.5,y+0.2)
			draw_line(p+Vector2(0,-33*s),p+Vector2(6,-36)*s,Color("edf0df"),3*s)
		"toilet":
			_block(x+0.22,y+0.1,w-0.44,0.25,22*s,Color("e6e4d3"))
			_block(x+0.22,y+0.35,w-0.44,d-0.45,10*s,Color("eaeada"))
			var p := grid_point(x+0.5,y+0.63)+Vector2(0,-11*s)
			draw_set_transform(p,0,Vector2(1,0.6))
			draw_circle(Vector2.ZERO,8*s,Color("f5f3e4"))
			draw_circle(Vector2.ZERO,4*s,Color("8ca9a4"))
			draw_set_transform(Vector2.ZERO)
		"tv":
			_block(x+0.08,y+0.1,w-0.16,d-0.2,9*s,Color("87674e"))
			_block(x+0.14,y+0.18,w-0.28,d-0.36,23*s,Color("34494d"),9*s)
			var p := grid_point(x+0.55,y+d-0.17)+Vector2(0,-20*s)
			draw_circle(p,6*s,Color("9bc9b0"))
		"bookshelf":
			_block(x+0.08,y+0.1,w-0.16,d-0.2,35*s,Color("987256"))
			for i in range(5):
				var p := grid_point(x+0.2+float(i)*0.12,y+d-0.08)
				draw_line(p+Vector2(0,-12*s),p+Vector2(0,-29*s),[Color("b3c3a2"),Color("d8a06e"),Color("edd8a1")][i%3],4*s)
		"plant":
			var foliage := grid_point(x+0.5,y+0.5)
			_hit_regions.append({"polygon":PackedVector2Array([foliage+Vector2(-13,-34)*s,foliage+Vector2(13,-34)*s,foliage+Vector2(13,-8)*s,foliage+Vector2(-13,-8)*s]),"target":_drawing_target})
			_block(x+0.3,y+0.3,0.4,0.4,10*s,Color("bf8665"))
			var p := grid_point(x+0.5,y+0.5)+Vector2(0,-11*s)
			draw_line(p,p+Vector2(0,-20*s),Color("466f4b"),3*s)
			for i in range(4):
				draw_circle(p+Vector2((-1 if i%2==0 else 1)*6,-8-i*3)*s,6*s,Color("71985e"))
		"table":
			_block(x+0.2,y+0.2,0.14,0.14,18*s,Color("806550"))
			_block(x+w-0.34,y+d-0.34,0.14,0.14,18*s,Color("806550"))
			_block(x+0.04,y+0.04,w-0.08,d-0.08,4*s,Color("ccaa78"),18*s)
		_:
			_block(x+0.1,y+0.1,w-0.2,d-0.2,16*s,color)

	_drawing_target = {}

func _resident(member: Dictionary, family: Dictionary,s: float) -> void:
	var p := grid_point(float(member.x)+0.5,float(member.y)+0.5)
	var body := PackedVector2Array([p+Vector2(-11,-38)*s,p+Vector2(11,-38)*s,p+Vector2(11,1)*s,p+Vector2(-11,1)*s])
	_hit_regions.append({"polygon":body,"target":{"type":"member","id":member.id,"name":member.name,"owner":family.id}})
	var selected := str(member.id)==selected_member
	var bob := 0.0 if bool(Preferences.values.get("reduced_motion",false)) else sin(_time*4.0+float(str(member.id).hash()%10))*0.5*s
	draw_set_transform(p,0,Vector2(1,0.45))
	draw_circle(Vector2.ZERO,9*s,Color(0.12,0.20,0.15,0.22))
	if selected: draw_arc(Vector2.ZERO,12*s,0,TAU,32,Color("fff2bd"),2*s,true)
	draw_set_transform(Vector2.ZERO)
	var shirt := Color("557e8b") if str(family.id)==str(Session.profile_id) else Color("be795b")
	if str(member.name).hash()%2==0: shirt=Color("ad9975")
	draw_line(p+Vector2(-3,-5)*s,p+Vector2(-4,-14)*s,Color("424f54"),4*s,true)
	draw_line(p+Vector2(3,-5)*s,p+Vector2(4,-14)*s,Color("424f54"),4*s,true)
	draw_line(p+Vector2(0,-13)*s,p+Vector2(0,-24)*s+Vector2(0,bob),shirt,12*s,true)
	draw_line(p+Vector2(-7,-23)*s,p+Vector2(-9,-14)*s,Color("d3a27e"),3*s,true)
	draw_line(p+Vector2(7,-23)*s,p+Vector2(9,-14)*s,Color("d3a27e"),3*s,true)
	draw_circle(p+Vector2(0,-31)*s+Vector2(0,bob),6*s,Color("e1b58a"))
	draw_arc(p+Vector2(0,-32)*s,5.5*s,PI,TAU+0.4,12,Color("625346"),3*s,true)
	if selected:
		var q := p+Vector2(0,-47)*s
		_poly([q+Vector2(0,-7)*s,q+Vector2(4,0)*s,q+Vector2(0,7)*s,q+Vector2(-4,0)*s],Color("e9d695"),Color("fff3b4"))
		var text := str(member.name)
		var text_width := _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		draw_string(_font,p+Vector2(-text_width*0.5,18*s),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("263f36"))
