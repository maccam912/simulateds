extends Control
## Isometric presentation. All mutations are sent as commands by the HUD.
signal tile_clicked(cell: Vector2i)
signal hovered(cell: Vector2i)
signal entity_clicked(target: Dictionary)

const Catalog = preload("res://game/catalog.gd")
const BuildRules = preload("res://game/build_rules.gd")
const RoomPlan = preload("res://game/room_plan.gd")
const Finishes = preload("res://game/finishes.gd")
const ResidentMotion = preload("res://game/resident_motion.gd")
const ActivityAudio = preload("res://game/activity_audio.gd")
const Appearance = preload("res://game/appearance.gd")
const Daylight = preload("res://game/daylight.gd")
var motion = ResidentMotion.new()
var activity_audio = ActivityAudio.new()
var _audio_tick := -1
var light: Dictionary = Daylight.sample(480)
var world: Dictionary = {}
var lot_id := "lot_1"
var selected_member := ""
var build_kind := "floor"
var build_rotation := 0
var build_object_id := ""
var room_anchor := Vector2i(-1,-1)
var room_pending := false
var paint_anchor := Vector2i(-1,-1)
var paint_pending := false
var paint_plan: Dictionary = {}
var finish_choice := ""
var _paint_cells: Dictionary = {}
var _preview_finish := ""
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
var _art_object: Dictionary = {}
var hover_target: Dictionary = {}
var _pointer := Vector2(-10000,-10000)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	mouse_exited.connect(func(): hover_cell = Vector2i(-1, -1); hover_target = {}; _pointer = Vector2(-10000,-10000); queue_redraw())

func _process(delta: float) -> void:
	if not Session.menu_paused: _time += delta
	motion.update(world,lot_id,delta,bool(Preferences.values.get("reduced_motion",false)),0.42 if Session.role=="client" else 0.22)
	_update_activity_audio(delta)
	queue_redraw()

func _update_activity_audio(delta: float) -> void:
	var lot: Dictionary=world.get("lots",{}).get(lot_id,{})
	var key := Session.role+":"+lot_id+":"+str(lot.get("revision",0))
	var active: bool=Soundscape.enabled and is_visible_in_tree() and Soundscape.context=="live" and not Session.menu_paused and not lot.is_empty() and not lot.get("building",false)
	active=active and (Session.role=="client" or Session.debug_speed>0.0) and float(Preferences.values.effects_volume)>0.0 and float(Preferences.values.master_volume)>0.0
	if int(world.get("tick",0))<_audio_tick: activity_audio.reset(); Soundscape.stop_world()
	_audio_tick=int(world.get("tick",0))
	Soundscape.sync_world(active,key)
	var residents: Array[Dictionary]=[]
	var sources := {}
	if active:
		_layout()
		for family: Dictionary in world.get("families",{}).values():
			for member: Dictionary in family.members:
				if member.lot_id!=lot_id: continue
				var point := resident_anchor(member)
				if not Rect2(Vector2.ZERO,size).has_point(point): continue
				var cell := motion.position(member)
				var task: Dictionary=member.get("task",{})
				residents.append({"id":str(member.id),"cell":cell,"position":get_global_transform_with_canvas()*point,"kind":str(_activity_pose(member).get("kind","")),"task":str(task.get("id","")),"elapsed":float(task.get("elapsed",0.0)),"walking":motion.moving(str(member.id)) or not task.get("path",[]).is_empty(),"indoors":[roundi(cell.x),roundi(cell.y)] in lot.floors})
				sources[str(member.id)]={"position":get_global_transform_with_canvas()*point,"task":str(task.get("id",""))}
	Soundscape.update_world_sources(sources)
	for event: Dictionary in activity_audio.sample(key,residents,delta,active): Soundscape.play_world(event)

func _exit_tree() -> void:
	Soundscape.stop_world()

func _layout() -> void:
	# The camera frames the house, not a panel. Ground continues behind the HUD.
	var play_height: float = maxf(360.0, size.y - 160.0)
	var scale_factor: float = minf(size.x / 1000.0, play_height / 510.0) * zoom
	_cell = Vector2(48, 24) * scale_factor
	var focus := Vector2(size.x * 0.5, play_height * 0.53)
	_origin = focus - Vector2(_cell.x * 0.25, _cell.y * 7.75) + pan

func object_point(object: Dictionary, local: Vector2) -> Vector2:
	var dimensions: Array=Catalog.ITEMS[object.kind].size
	var w := float(dimensions[0]); var d := float(dimensions[1])
	match int(object.get("rotation",0)):
		1: local=Vector2(d-local.y,local.x)
		2: local=Vector2(w-local.x,d-local.y)
		3: local=Vector2(local.y,w-local.x)
	return Vector2(float(object.x),float(object.y))+local

func grid_point(x: float, y: float) -> Vector2:
	if not _art_object.is_empty():
		var rotated := object_point(_art_object,Vector2(x-float(_art_object.x),y-float(_art_object.y)))
		x=rotated.x; y=rotated.y
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
				if building and build_kind=="finish_wall" and target.get("type")=="wall": cell=Vector2i(int(target.x),int(target.y))
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
		if building and build_kind=="finish_wall" and hover_target.get("type")=="wall": hover_cell=Vector2i(int(hover_target.x),int(hover_target.y))
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
	var corners := [a,b,c,e]
	var middle_y := (a.y+b.y+c.y+e.y)*0.25
	for index in range(4):
		var left: Vector2=corners[index]
		var right: Vector2=corners[(index+1)%4]
		if (left.y+right.y)*0.5>middle_y:
			var edge := right-left
			_poly([left+top,right+top,right+base,left+base],color.darkened(0.23 if edge.x*edge.y>0 else 0.38))
	_poly([a+top,b+top,c+top,e+top], color.lightened(0.12), color.darkened(0.12))

func _draw() -> void:
	_hit_regions.clear()
	_drawing_target = {}
	_layout()
	light=Daylight.sample(float(world.get("day_minutes",480)))
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
	_update_finish_preview(lot)
	# Planting sits along the property edges without boxing the entire view in.
	for y in [1,3,5,7,9,11]:
		_bush(0.35,float(y),scale_factor)
	for x in [4,7,10,13]:
		_bush(float(x),0.35,scale_factor)
	if Preferences.values.get("quality","high")=="high":
		for location in [Vector2(-3,2), Vector2(2,-3), Vector2(10,-4), Vector2(17,1), Vector2(-3,11)]:
			_tree(location.x,location.y,scale_factor)
	draw_rect(Rect2(Vector2.ZERO,size),light.overlay)
	# A property lives in the neighborhood, rather than on an isolated plinth.
	# Lawn is continuous; only construction exposes the editable grid.
	if building:
		_diamond(0,0,16,16,Color(0.89,0.96,0.72,lerpf(0.045,0.12,float(light.night))),0,Color(0.95,0.97,0.78,0.65))
	for depth in range(31):
		for x in range(16):
			var y := depth-x
			if y < 0 or y > 15: continue
			var cell := Vector2i(x,y)
			if building:
				_diamond(x,y,1,1,Color.TRANSPARENT,0,Color(0.30,0.41,0.24,0.30).lerp(Color(0.85,0.87,0.62,0.45),float(light.night)))
			# A garden path leads from the front door to the public sidewalk.
			if x == 8 and y >= 11:
				_diamond(x,y,1,1,Daylight.outside(Color("c5c4a5"),light),0,Daylight.outside(Color("b1b496"),light))
			if floors.has(cell):
				_draw_floor_finish(x,y,Finishes.PALETTES.floor[_surface_finish(lot,"floor",x,y)])
	# Paint rear walls first. Near walls use a low cutaway for readable interiors.
	for depth in range(31):
		for x in range(16):
			var y := depth-x
			if y < 0 or y > 15: continue
			var cell := Vector2i(x,y)
			if walls.has(cell):
				var rear := (floors.has(cell+Vector2i.RIGHT) and not floors.has(cell+Vector2i.LEFT)) or (floors.has(cell+Vector2i.DOWN) and not floors.has(cell+Vector2i.UP))
				var h := (39.0 if rear else 8.0)*scale_factor
				var color := Color(Finishes.PALETTES.wall[_surface_finish(lot,"wall",x,y)].color).lerp(Color("f3dfb6"),float(light.night)*0.22)
				if building and build_kind=="finish_wall": _drawing_target={"type":"wall","x":x,"y":y}
				_block(x,y,1,1,h,color)
				if h > 20*scale_factor:
					_diamond(x+0.04,y+0.04,0.92,0.92,color.lightened(0.12),h)
				_drawing_target={}
			if doors.has(cell):
				_diamond(x,y,1,1,Color("8f6c50"),2*scale_factor)
				_block(x,y,0.12,0.12,33*scale_factor,Color("c7a376"))
	var entities: Array = []
	for obj in lot.get("objects", []):
		entities.append({"depth":float(obj.x)+float(obj.y)+0.5,"object":obj})
	for family in world.get("families", {}).values():
		for member in family.get("members", []):
			if member.lot_id == lot_id:
				var display := motion.position(member)
				var pose := _activity_pose(member)
				var depth := display.x+display.y+0.8
				if pose.get("kind","") in ["bed","sofa"]: depth=float(pose.object.x)+float(pose.object.y)+0.95
				entities.append({"depth":depth,"member":member,"family":family})
	entities.sort_custom(func(a,b): return a.depth < b.depth)
	for entity in entities:
		if entity.has("object"):
			_furnishing(entity.object,scale_factor)
		else:
			_resident(entity.member, entity.family,scale_factor)
	_draw_street_lights(scale_factor)
	hover_target = hit_target(_pointer)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not building and not hover_target.is_empty() else Control.CURSOR_ARROW
	if building and build_kind=="room":
		_draw_room_preview(lot)
	elif building and build_kind in ["finish_floor","finish_wall"]: _draw_finish_preview()
	elif _in_bounds(hover_cell) and (building or hover_target.is_empty()):
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
	_art_object=obj
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
	_art_object = {}

func _resident(member: Dictionary, family: Dictionary,s: float) -> void:
	var pose := _activity_pose(member)
	var p := resident_anchor(member)
	if pose.get("kind")=="bed":
		_sleeping_resident(member,family,pose.object,s)
		return
	var sitting: bool=pose.get("kind")=="sofa"
	var body := PackedVector2Array([p+Vector2(-11,-38)*s,p+Vector2(11,-38)*s,p+Vector2(11,1)*s,p+Vector2(-11,1)*s])
	_hit_regions.append({"polygon":body,"target":{"type":"member","id":member.id,"name":member.name,"owner":family.id}})
	var selected := str(member.id)==selected_member
	var reduced := bool(Preferences.values.get("reduced_motion",false))
	var walking: bool=motion.moving(str(member.id)) and not reduced
	var stride: float=motion.stride(str(member.id)) if walking else 0.0
	var bob := absf(stride)*1.2*s if walking else 0.0 if reduced else sin(_time*3.0+float(str(member.id).hash()%10))*0.35*s
	draw_set_transform(p,0,Vector2(1,0.45))
	draw_circle(Vector2.ZERO,9*s,Color(0.12,0.20,0.15,0.22))
	if selected: draw_arc(Vector2.ZERO,12*s,0,TAU,32,Color("fff2bd"),2*s,true)
	draw_set_transform(Vector2.ZERO)
	var look := Appearance.of(member)
	var shirt: Color=Appearance.SHIRT[int(look.shirt)]
	var skin: Color=Appearance.SKIN[int(look.skin)]
	if sitting:
		draw_line(p+Vector2(-4,-16)*s,p+Vector2(-8,-9)*s,Color("424f54"),4*s,true)
		draw_line(p+Vector2(4,-16)*s,p+Vector2(9,-9)*s,Color("424f54"),4*s,true)
	else:
		draw_line(p+Vector2(-3-stride*3,-5+stride*2)*s,p+Vector2(-4,-14)*s,Color("424f54"),4*s,true)
		draw_line(p+Vector2(3+stride*3,-5-stride*2)*s,p+Vector2(4,-14)*s,Color("424f54"),4*s,true)
	draw_line(p+Vector2(0,-13)*s,p+Vector2(0,-24)*s+Vector2(0,bob),shirt,12*s,true)
	draw_line(p+Vector2(-7,-23)*s,p+Vector2(-9+stride*3,-14)*s,skin,3*s,true)
	draw_line(p+Vector2(7,-23)*s,p+Vector2(9-stride*3,-14)*s,skin,3*s,true)
	Appearance.draw_head(self,p+Vector2(0,-31)*s+Vector2(0,bob),s,look)
	_activity_prop(p,str(pose.get("kind","")),s,reduced)
	if selected:
		var q := p+Vector2(0,-47)*s
		_poly([q+Vector2(0,-7)*s,q+Vector2(4,0)*s,q+Vector2(0,7)*s,q+Vector2(-4,0)*s],Color("e9d695"),Color("fff3b4"))
		var text := str(member.name)
		var text_width := _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		_resident_name(p+Vector2(-text_width*0.5,18*s),text)

func _activity_pose(member: Dictionary) -> Dictionary:
	if motion.moving(str(member.id)): return {}
	var task: Dictionary=member.get("task",{})
	if task.get("type")=="interact" and task.get("path",[]).is_empty() and float(task.get("elapsed",0))>0:
		if task.get("target_kind")=="member": return {"kind":"chat"}
		for object: Dictionary in world.lots[lot_id].objects:
			if object.id==task.get("target_id"): return {"kind":object.kind,"object":object}
	if task.is_empty() and str(member.get("action","")).begins_with("Chatting"): return {"kind":"chat"}
	return {}

func resident_anchor(member: Dictionary) -> Vector2:
	var display := motion.position(member)+Vector2(0.5,0.5)
	var pose := _activity_pose(member)
	if pose.get("kind","") in ["bed","sofa"]:
		var object: Dictionary=pose.object
		var size: Array=Catalog.ITEMS[object.kind].size
		display=object_point(object,Vector2(float(size[0])*0.5,float(size[1])*(0.75 if object.kind=="sofa" else 0.5)))
	return grid_point(display.x,display.y)

func _sleeping_resident(member: Dictionary,family: Dictionary,object: Dictionary,s: float) -> void:
	var head_cell := object_point(object,Vector2(0.5,0.32))
	var feet_cell := object_point(object,Vector2(0.5,1.6))
	var head := grid_point(head_cell.x,head_cell.y)+Vector2(0,-22)*s
	var feet := grid_point(feet_cell.x,feet_cell.y)+Vector2(0,-20)*s
	var torso := head.lerp(feet,0.28)
	draw_line(torso,feet,Color("97b8b1"),14*s,true)
	Appearance.draw_head(self,head,s,Appearance.of(member))
	var target := {"type":"member","id":member.id,"name":member.name,"owner":family.id}
	var box := Rect2(head,Vector2.ZERO).expand(feet).grow(9*s)
	_hit_regions.append({"polygon":PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]),"target":target})
	var float_y := 0.0 if Preferences.values.reduced_motion else sin(_time*1.5)*2.0
	draw_string(_font,head+Vector2(8,-15+float_y)*s,"z z",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f5efd8"))
	if str(member.id)==selected_member:
		draw_arc(head,10*s,0,TAU,24,Color("fff2bd"),1.5*s,true)
		var width := _font.get_string_size(str(member.name),HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		_resident_name(feet+Vector2(-width*0.5,20*s),str(member.name))

func _activity_prop(p: Vector2,kind: String,s: float,reduced: bool) -> void:
	match kind:
		"bookshelf":
			_poly([p+Vector2(-10,-20)*s,p+Vector2(0,-17)*s,p+Vector2(0,-9)*s,p+Vector2(-10,-12)*s],Color("ead9aa"),Color("8b6950"))
			_poly([p+Vector2(0,-17)*s,p+Vector2(10,-20)*s,p+Vector2(10,-12)*s,p+Vector2(0,-9)*s],Color("faf1d6"),Color("8b6950"))
		"table", "fridge":
			draw_rect(Rect2(p+Vector2(4,-20)*s,Vector2(7,7)*s),Color("f4e5cb"))
			draw_arc(p+Vector2(12,-17)*s,3*s,-PI*0.5,PI*0.5,10,Color("f4e5cb"),1.5*s,true)
			if kind=="table": draw_line(p+Vector2(7,-24)*s,p+Vector2(8,-29)*s,Color(1,0.98,0.86,0.7),1*s,true)
		"plant":
			draw_circle(p+Vector2(9,-17)*s,5*s,Color("719b91"))
			draw_line(p+Vector2(12,-18)*s,p+Vector2(19,-13)*s,Color("719b91"),3*s,true)
			for index in range(3):
				var fall := float(index)*4.0 if reduced else fmod(_time*14+float(index)*5,15.0)
				draw_circle(p+Vector2(18+index*2,-12+fall)*s,1*s,Color("cee6dd"))
		"shower":
			for index in range(4):
				var fall := float(index)*5.0 if reduced else fmod(_time*22+index*9,30.0)
				draw_line(p+Vector2(-13+index*8,-40+fall)*s,p+Vector2(-14+index*8,-35+fall)*s,Color(0.72,0.9,0.94,0.8),1.3*s,true)
		"chat":
			var q := p+Vector2(18,-45)*s
			draw_style_box(preload("res://game/style.gd").box(Color("f2e7c7"),5),Rect2(q,Vector2(27,16)*s))
			for index in range(3):
				var rise := 0.0 if reduced else sin(_time*4.0+index)*1.2
				draw_circle(q+Vector2(6+index*7,8+rise)*s,1.5*s,Color("57736a"))
		"tv":
			var q := p+Vector2(13,-43)*s
			draw_style_box(preload("res://game/style.gd").box(Color("304b4f"),3),Rect2(q,Vector2(18,14)*s))
			draw_line(q+Vector2(5,5)*s,q+Vector2(14,5)*s,Color("b9d69f"),2*s,true)

func _resident_name(position: Vector2, text: String) -> void:
	if float(light.night)>0.4:
		draw_string_outline(_font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,Color("26363b"))
		draw_string(_font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff1ce"))
	else:
		draw_string(_font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("263f36"))

func _draw_street_lights(s: float) -> void:
	var night := float(light.night)
	for x in [2.0,13.0]:
		var p := grid_point(x,16.65)
		if night>0.01:
			draw_set_transform(p,0,Vector2(1,0.48))
			for ring in range(24,0,-1):
				draw_circle(Vector2.ZERO,float(ring)*2.5*s,Color(1.0,0.78,0.39,night*0.007))
			draw_set_transform(Vector2.ZERO)
		draw_line(p,p+Vector2(0,-49)*s,Daylight.outside(Color("58665c"),light),3*s,true)
		draw_line(p+Vector2(0,-49)*s,p+Vector2(8,-49)*s,Daylight.outside(Color("58665c"),light),3*s,true)
		var bulb := p+Vector2(8,-46)*s
		if night>0.01:
			for ring in range(12,0,-1):
				draw_circle(bulb,float(ring)*1.33*s,Color(1.0,0.86,0.55,night*0.014))
		draw_rect(Rect2(bulb-Vector2(4,2)*s,Vector2(8,5)*s),Color("fbe5a3") if night>0.2 else Color("a4ae91"))

func _update_finish_preview(lot: Dictionary) -> void:
	_paint_cells.clear(); _preview_finish=""
	if not building or not build_kind in ["finish_floor","finish_wall"]: return
	var plan: Dictionary={}
	if paint_pending: plan=paint_plan
	elif _in_bounds(hover_cell):
		var anchor := hover_cell if paint_anchor.x<0 else paint_anchor
		var signature := str(["finish",lot_id,lot.revision,lot.funds,anchor,hover_cell,build_kind,finish_choice])
		if signature!=_preview_signature:
			_preview_signature=signature
			preview_result=Finishes.inspect(lot,{"surface":build_kind.trim_prefix("finish_"),"finish":finish_choice,"x":anchor.x,"y":anchor.y,"end_x":hover_cell.x,"end_y":hover_cell.y})
		plan=preview_result
	if plan.get("ok",false):
		_preview_finish=str(plan.finish)
		for cell: Array in plan.cells: _paint_cells[Finishes.key(int(cell[0]),int(cell[1]))]=true

func _surface_finish(lot: Dictionary, surface: String, x: int, y: int) -> String:
	if build_kind=="finish_"+surface and _paint_cells.has(Finishes.key(x,y)): return _preview_finish
	return Finishes.at(lot,surface,x,y)

func _draw_floor_finish(x: int, y: int, definition: Dictionary) -> void:
	var color := Color(definition.color)
	if definition.pattern=="checkers" and (x+y)%2==1: color=Color("e4dfca")
	elif (x+y)%2==1: color=color.darkened(0.02)
	color=color.lerp(Color("e8c38c"),float(light.night)*0.18)
	var edge := color.darkened(0.10 if definition.pattern=="carpet" else 0.17)
	_diamond(x,y,1,1,color,1,edge)
	if definition.pattern=="boards":
		draw_line(grid_point(x+0.5,y)+Vector2(0,-1),grid_point(x+0.5,y+1)+Vector2(0,-1),edge,0.7,true)
	elif definition.pattern=="tiles":
		_diamond(x+0.05,y+0.05,0.9,0.9,color.lightened(0.04),1)
	elif definition.pattern=="carpet":
		for offset: Vector2 in [Vector2(0.25,0.25),Vector2(0.75,0.75)]:
			draw_circle(grid_point(x+offset.x,y+offset.y)+Vector2(0,-1),0.5*_cell.x/48.0,edge)

func _draw_finish_preview() -> void:
	if paint_pending:
		_draw_preview_label("Decorating…",true); return
	if not _in_bounds(hover_cell): return
	var anchor := hover_cell if paint_anchor.x<0 else paint_anchor
	var low := Vector2i(mini(anchor.x,hover_cell.x),mini(anchor.y,hover_cell.y))
	var high := Vector2i(maxi(anchor.x,hover_cell.x),maxi(anchor.y,hover_cell.y))
	var valid := bool(preview_result.get("ok",false))
	_diamond(low.x,low.y,high.x-low.x+1,high.y-low.y+1,Color.TRANSPARENT if valid else Color(0.94,0.36,0.3,0.22),3,Color("d8f1b2") if valid else Color("ffab8f"))
	var hint := "Click first corner · " if paint_anchor.x<0 else "Click to apply · "
	_draw_preview_label((hint if valid else "")+str(preview_result.get("message","")),valid)

func _draw_room_preview(lot: Dictionary) -> void:
	if not _in_bounds(hover_cell): return
	if room_pending:
		_draw_preview_label("Building room…",true)
		return
	if room_anchor.x<0:
		_diamond(hover_cell.x,hover_cell.y,1,1,Color(0.85,0.94,0.65,0.2),3,Color("f8edb7"))
		_draw_preview_label("Room · Click the first corner",true)
		return
	var signature := str(["room",lot_id,lot.revision,lot.funds,hover_cell,room_anchor,build_rotation])
	if signature!=_preview_signature:
		_preview_signature=signature
		var residents: Array=[]
		for family: Dictionary in world.families.values():
			for member: Dictionary in family.members:
				if member.lot_id==lot_id: residents.append(Vector2i(int(member.x),int(member.y)))
		preview_result=RoomPlan.inspect(lot,{"x":room_anchor.x,"y":room_anchor.y,"end_x":hover_cell.x,"end_y":hover_cell.y,"rotation":build_rotation},residents)
	var low := Vector2i(mini(room_anchor.x,hover_cell.x),mini(room_anchor.y,hover_cell.y))
	var high := Vector2i(maxi(room_anchor.x,hover_cell.x),maxi(room_anchor.y,hover_cell.y))
	var valid := bool(preview_result.get("ok",false))
	var tint := Color(0.64,0.9,0.49,0.23) if valid else Color(0.94,0.36,0.3,0.3)
	var outline := Color("d8f1b2") if valid else Color("ffab8f")
	_diamond(low.x,low.y,high.x-low.x+1,high.y-low.y+1,tint,3,outline)
	if valid:
		var s := _cell.x/48.0
		for cell: Array in preview_result.walls:
			_block(int(cell[0]),int(cell[1]),1,1,14*s,Color(0.68,0.88,0.54,0.36))
		for cell: Array in preview_result.doors:
			_diamond(int(cell[0]),int(cell[1]),1,1,Color(1.0,0.81,0.4,0.75),5,Color("fff0ba"))
	_diamond(room_anchor.x,room_anchor.y,1,1,Color(1,0.94,0.65,0.25),4,Color("fff0ba"))
	_draw_preview_label(str(preview_result.get("message","")),valid)
