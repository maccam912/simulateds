extends Control
## Isometric presentation. All mutations are sent as commands by the HUD.
signal tile_clicked(cell: Vector2i)
signal hovered(cell: Vector2i)
signal entity_clicked(target: Dictionary)

const Catalog = preload("res://game/catalog.gd")
const Meals = preload("res://game/meals.gd")
const MealArt = preload("res://game/meal_art.gd")
const WallArt = preload("res://game/wall_art.gd")
const Paintings = preload("res://game/paintings.gd")
const Gardens = preload("res://game/gardens.gd")
const BuildRules = preload("res://game/build_rules.gd")
const BuildImpact = preload("res://game/build_impact.gd")
const RoomPlan = preload("res://game/room_plan.gd")
const RoomCopy = preload("res://game/room_copy.gd")
const FurnitureColors = preload("res://game/furniture_colors.gd")
const Finishes = preload("res://game/finishes.gd")
const Windows = preload("res://game/windows.gd")
const WalkFeedback = preload("res://game/walk_feedback.gd")
const ResidentFacing = preload("res://game/resident_facing.gd")
const ResidentMotion = preload("res://game/resident_motion.gd")
const ActivityAudio = preload("res://game/activity_audio.gd")
const Appearance = preload("res://game/appearance.gd")
const Daylight = preload("res://game/daylight.gd")
const ResidentCues = preload("res://game/resident_cues.gd")
const Leisure = preload("res://game/shared_leisure.gd")
const StereoMusic = preload("res://game/stereo_music.gd")
var motion = ResidentMotion.new()
var walking = WalkFeedback.new()
var show_plan_routes := false
var activity_audio = ActivityAudio.new()
var _audio_tick := -1
var light: Dictionary = Daylight.sample(480)
var world: Dictionary = {}
var lot_id := "lot_1":
	set(value):
		if lot_id!=value:
			stop_camera_motion()
			pan=Vector2.ZERO
			motion.tracks.clear()
		lot_id=value
var selected_member := ""
var show_cues := true
var resident_labels: Dictionary={}
var _last_care_click := -1000
var build_kind := "floor"
var build_rotation := 0
var build_object_id := ""
var room_anchor := Vector2i(-1,-1)
var room_pending := false
var copy_design: Dictionary={}
var copy_source := Vector2i(-1,-1)
var copy_pending := false
var copy_plan: Dictionary={}
var _copy_preview_key := ""
var copy_preview: Dictionary={}
var art_source := ""
var art_pending := false
var art_preview: Dictionary={}
var art_regions: Dictionary={}
var furniture_color := "original"
var color_request: Dictionary={}
var color_preview: Dictionary={}
var paint_anchor := Vector2i(-1,-1)
var paint_pending := false
var paint_plan: Dictionary = {}
var finish_choice := ""
var finish_selection := "area"
var window_style := "cottage"
var window_pending := false
var window_regions: Dictionary={}
var overlay_rects: Array[Rect2]=[]
var preview_label_rect := Rect2()
var _paint_cells: Dictionary = {}
var _preview_finish := ""
var preview_result: Dictionary = {}
var _preview_signature := ""
var _preview_spaces: Dictionary={}
var placement_impact: Dictionary={}
var impact_markers: Dictionary={}
var leisure_report: Dictionary={}
var leisure_markers: Array=[]
var _leisure_key := ""
var _leisure_cached: Dictionary={}
var building := false
var access_report: Dictionary={}
var access_visible := false
var access_inspecting := false
var access_focus := ""
var access_markers: Dictionary={}
var zoom := 1.0
var pan := Vector2.ZERO
var _camera_tween: Tween
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
	var simulation_delta := delta*Session.effective_speed()
	_time+=simulation_delta
	motion.update(world,lot_id,simulation_delta,bool(Preferences.values.get("reduced_motion",false)),0.42 if Session.role=="client" else 0.22)
	_update_activity_audio(delta)
	_layout()
	var ground_hover := Rect2(Vector2.ZERO,size).has_point(_pointer) and hit_target(_pointer).is_empty() and not _dragging
	walking.update(world,str(Session.profile_id),selected_member,lot_id,cell_at(_pointer),ground_hover and _in_bounds(cell_at(_pointer)),show_plan_routes,delta,show_cues and not building and Session.role!="joining")
	queue_redraw()

func _update_activity_audio(delta: float) -> void:
	var lot: Dictionary=world.get("lots",{}).get(lot_id,{})
	var key := Session.role+":"+lot_id+":"+str(lot.get("revision",0))
	var active: bool=Soundscape.enabled and is_visible_in_tree() and Soundscape.context=="live" and not Session.menu_paused and not lot.is_empty() and not lot.get("building",false)
	active=active and (Session.role=="client" or Session.debug_speed>0.0) and float(Preferences.values.master_volume)>0.0
	if int(world.get("tick",0))<_audio_tick: activity_audio.reset(); Soundscape.stop_world()
	_audio_tick=int(world.get("tick",0))
	Soundscape.sync_world(active,key)
	var stereo_positions := {}
	if active:
		_layout()
		for object: Dictionary in lot.get("objects",[]):
			if object.kind!="stereo": continue
			var point := grid_point(float(object.x)+0.5,float(object.y)+0.5)
			if Rect2(Vector2.ZERO,size).has_point(point): stereo_positions[str(object.id)]=get_global_transform_with_canvas()*point
	var stereo := StereoMusic.source(world,lot_id,selected_member,stereo_positions) if active else {}
	Soundscape.sync_dance(key+":"+str(stereo.id) if not stereo.is_empty() else "",stereo.get("position",Vector2.ZERO))
	active=active and float(Preferences.values.effects_volume)>0.0
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
				var sound_kind := str(_activity_pose(member).get("kind",""))
				if sound_kind=="easel" and task.get("paint_action")=="sell": sound_kind="painting_sale"
				if sound_kind=="garden_bed": sound_kind="garden_"+str(task.get("garden_action","water"))
				residents.append({"id":str(member.id),"cell":cell,"position":get_global_transform_with_canvas()*point,"kind":sound_kind,"task":str(task.get("id","")),"elapsed":float(task.get("elapsed",0.0)),"walking":motion.moving(str(member.id)) or not task.get("path",[]).is_empty(),"indoors":[roundi(cell.x),roundi(cell.y)] in lot.floors})
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

func stop_camera_motion() -> void:
	if _camera_tween!=null:
		_camera_tween.kill(); _camera_tween=null

func center_lot() -> void:
	stop_camera_motion()
	zoom=1.0; pan=Vector2.ZERO
	_layout(); queue_redraw()

func camera_focus_point() -> Vector2:
	# Leave room for the bottom household HUD and the resident's name above them.
	return Vector2(size.x*0.56,maxf(360.0,size.y-160.0)*0.53+35.0)

func resident_in_view(member: Dictionary) -> bool:
	if member.is_empty() or member.get("lot_id")!=lot_id: return false
	_layout()
	var safe := Rect2(Vector2(70,125),Vector2(maxf(1,size.x-140),maxf(1,size.y-330)))
	return safe.has_point(resident_anchor(member))

func focus_resident(member: Dictionary) -> bool:
	if member.is_empty() or member.get("lot_id")!=lot_id: return false
	stop_camera_motion(); _layout()
	var destination := pan+camera_focus_point()-resident_anchor(member)
	if bool(Preferences.values.reduced_motion): pan=destination
	else:
		_camera_tween=create_tween()
		_camera_tween.tween_property(self,"pan",destination,0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_layout(); queue_redraw()
	return true

func focus_cell(cell: Vector2) -> void:
	stop_camera_motion(); _layout()
	var destination := pan+camera_focus_point()-grid_point(cell.x,cell.y)
	if bool(Preferences.values.reduced_motion): pan=destination
	else:
		_camera_tween=create_tween()
		_camera_tween.tween_property(self,"pan",destination,0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_layout(); queue_redraw()

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
			if event.pressed: stop_camera_motion()
			_dragging = event.pressed
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				stop_camera_motion()
				zoom = minf(1.8, zoom + 0.1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				stop_camera_motion()
				zoom = maxf(0.65, zoom - 0.1)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.double_click and Time.get_ticks_msec()-_last_care_click<500 and not building:
					accept_event(); return
				var target := hit_target(event.position)
				var cell := cell_at(event.position)
				if building and access_inspecting:
					if target.get("type")=="access": entity_clicked.emit(target)
					accept_event(); return
				if building and build_kind in ["finish_wall","door","erase","window","wall_art"] and target.get("type") in ["wall","wall_art"]: cell=Vector2i(int(target.x),int(target.y))
				if building and build_kind=="wall_art" and art_source.is_empty() and target.get("type")=="wall_art":
					entity_clicked.emit(target)
				elif building and build_kind=="move" and build_object_id.is_empty() and target.get("type")=="object":
					entity_clicked.emit(target)
				elif building and build_kind=="furniture_color" and target.get("type")=="object": entity_clicked.emit(target)
				elif not building and not target.is_empty():
					if target.get("type")=="care": _last_care_click=Time.get_ticks_msec()
					entity_clicked.emit(target)
				elif building and build_kind == "erase" and target.get("type") == "object":
					tile_clicked.emit(Vector2i(int(target.x),int(target.y)))
				elif _in_bounds(cell):
					tile_clicked.emit(cell)
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			stop_camera_motion()
			pan += event.relative
		_pointer = event.position
		hover_cell = cell_at(event.position)
		hover_target = hit_target(event.position)
		if building and build_kind in ["finish_wall","door","erase","window","wall_art"] and hover_target.get("type") in ["wall","wall_art"]: hover_cell=Vector2i(int(hover_target.x),int(hover_target.y))
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
	preview_label_rect=Rect2()
	leisure_report={}; leisure_markers.clear()
	resident_labels.clear()
	access_markers.clear()
	impact_markers.clear(); placement_impact={}
	_drawing_target = {}
	_layout()
	light=Daylight.sample(float(world.get("day_minutes",480)))
	_draw_neighborhood_ground()
	if not world.has("lots") or not world.lots.has(lot_id):
		draw_string(_font, Vector2(40,80), "Preparing your neighborhood…", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("34514c"))
		return
	var lot: Dictionary = world.lots[lot_id]
	color_preview={}
	if building and build_kind=="furniture_color" and not access_inspecting:
		color_preview=FurnitureColors.inspect(lot,color_request if not color_request.is_empty() else {"object_id":str(hover_target.get("id","")),"style":furniture_color})
	var scale_factor := _cell.x / 48.0
	var floors: Dictionary = {}
	var walls: Dictionary = {}
	var doors: Dictionary = {}
	for cell in lot.get("floors", []): floors[Vector2i(int(cell[0]),int(cell[1]))] = true
	for cell in lot.get("walls", []): walls[Vector2i(int(cell[0]),int(cell[1]))] = true
	for cell in lot.get("doors", []): doors[Vector2i(int(cell[0]),int(cell[1]))] = true
	_update_finish_preview(lot)
	if building and not access_inspecting and _in_bounds(hover_cell):
		if build_kind=="room" and room_anchor.x>=0 and not room_pending:
			_update_room_preview(lot); placement_impact=preview_result.get("impact",{})
		elif Catalog.ITEMS.has(build_kind) or (build_kind=="move" and not build_object_id.is_empty()):
			_update_preview(lot); placement_impact=preview_result.get("impact",{})
	_update_window_preview(lot)
	window_regions.clear(); art_regions.clear(); art_preview={}
	if building and build_kind=="wall_art" and not access_inspecting and not art_pending and _in_bounds(hover_cell):
		art_preview=WallArt.inspect(lot,{"type":"art_hang","source":art_source,"x":hover_cell.x,"y":hover_cell.y})
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
	if building and build_kind=="finish_floor" and finish_selection=="room" and not access_inspecting: _draw_room_finish_ground()
	if building and access_visible: _draw_access_ground(lot)
	_draw_impact_ground()
	_draw_walk_ground(scale_factor)
	# Paint rear walls first. Near walls use a low cutaway for readable interiors.
	for depth in range(31):
		for x in range(16):
			var y := depth-x
			if y < 0 or y > 15: continue
			var cell := Vector2i(x,y)
			if walls.has(cell):
				var rear := (floors.has(cell+Vector2i.RIGHT) and not floors.has(cell+Vector2i.LEFT)) or (floors.has(cell+Vector2i.DOWN) and not floors.has(cell+Vector2i.UP))
				var h := (39.0 if rear or (building and build_kind in ["window","wall_art"] and not access_inspecting) else 8.0)*scale_factor
				var color := Color(Finishes.PALETTES.wall[_surface_finish(lot,"wall",x,y)].color).lerp(Color("f3dfb6"),float(light.night)*0.22)
				if building and build_kind in ["finish_wall","door","erase","window","wall_art"]: _drawing_target={"type":"wall","x":x,"y":y}
				_block(x,y,1,1,h,color)
				if h > 20*scale_factor:
					_diamond(x+0.04,y+0.04,0.92,0.92,color.lightened(0.12),h)
				var window := Windows.at(lot,x,y)
				var previewing: bool=building and build_kind=="window" and not access_inspecting and not window_pending and hover_cell==cell and preview_result.get("ok",false)
				if previewing: window=window_style
				if not window.is_empty(): _draw_window(lot,x,y,h,window,scale_factor,previewing)
				if previewing and window.is_empty(): _diamond(x,y,1,1,Color(0.94,0.4,0.3,0.18),h,Color("ffab8f"))
				_drawing_target={}
				var art_id := WallArt.at(lot,x,y)
				if not art_id.is_empty(): _draw_wall_art(lot,x,y,lot.artworks[art_id].picture,scale_factor,art_id)
				if art_preview.get("ok",false) and int(art_preview.x)==x and int(art_preview.y)==y: _draw_wall_art(lot,x,y,art_preview.picture,scale_factor,"",true)
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
			var drawn: Dictionary=entity.object
			if color_preview.get("ok",false) and color_preview.object_id==drawn.id:
				drawn=drawn.duplicate(true); FurnitureColors.set_style(drawn,str(color_preview.style))
			_furnishing(drawn,scale_factor)
		else:
			_resident(entity.member, entity.family,scale_factor)
	_draw_street_lights(scale_factor)
	_draw_resident_overlays(entities,scale_factor)
	if building and access_visible and (placement_impact.is_empty() or access_inspecting): _draw_access_issues(scale_factor)
	hover_target = hit_target(_pointer)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (not building and not hover_target.is_empty()) or (building and access_inspecting and hover_target.get("type")=="access") else Control.CURSOR_ARROW
	if building and access_inspecting: pass
	elif building and build_kind=="furniture_color": _draw_furniture_color()
	elif building and build_kind=="copy_room": _draw_room_copy(lot)
	elif building and build_kind=="room":
		_draw_room_preview(lot)
	elif building and build_kind in ["finish_floor","finish_wall"]: _draw_finish_preview()
	elif building and build_kind=="window": _draw_window_preview()
	elif building and build_kind=="wall_art": _draw_art_preview()
	elif building and _in_bounds(hover_cell):
		var tint := Color(0.96,0.99,0.81,0.32)
		var outline := Color("f8f3c7")
		var footprint := Vector2i.ONE
		var preview_cell := hover_cell
		var hint_message := ""
		var hint_valid := false
		var hint_tone := Color.TRANSPARENT
		if building and build_kind!="erase" and (build_kind!="move" or not build_object_id.is_empty()):
			_update_preview(lot)
			var kind := build_kind
			if build_kind=="move":
				for object: Dictionary in lot.objects:
					if object.id==build_object_id: kind=str(object.kind)
			footprint=Catalog.footprint(kind,build_rotation)
			tint=Color(0.62,0.88,0.49,0.42) if preview_result.get("ok",false) else Color(0.93,0.32,0.26,0.45)
			outline=Color("d8f1b2") if preview_result.get("ok",false) else Color("ffab8f")
			if placement_impact.get("warning",false):
				outline=Color("efc77d"); tint=Color(outline,0.30)
			var message := str(preview_result.get("message",""))
			if build_kind=="door" and not WallArt.at(lot,hover_cell.x,hover_cell.y).is_empty(): message+="\nPainting moves safely into the collection"
			if not placement_impact.get("message","").is_empty(): message+="\n"+str(placement_impact.message)
			if not _preview_spaces.is_empty():
				_draw_leisure_places(_preview_spaces)
				message+="\n"+Leisure.layout_text(_preview_spaces)+" · ○ Open  × Blocked / no path"
			hint_message=message; hint_valid=bool(preview_result.get("ok",false))
			if placement_impact.get("warning",false): hint_tone=Color("efc77d")
		elif building and build_kind in ["erase","move"] and hover_target.get("type")=="object":
			preview_cell=Vector2i(int(hover_target.x),int(hover_target.y))
			footprint=Catalog.footprint(str(hover_target.kind),int(hover_target.rotation))
			var item: Dictionary=Catalog.ITEMS[hover_target.kind]
			if build_kind=="erase":
				tint=Color(0.94,0.4,0.3,0.35)
				hint_message="Sell " + str(item.name) + " · § %d" % int(float(item.cost)*0.6)
				if hover_target.kind=="dining_table": hint_message+="\nIncludes remaining food · Undo restores both"
				if hover_target.kind=="easel": hint_message+="\nIncludes its canvas · Undo restores both"
			else:
				var message := "Move " + str(item.name) + " · Click to select"
				if Leisure.KINDS.has(hover_target.kind):
					var report := _leisure_spaces(lot,hover_target,true)
					_draw_leisure_places(report); message+="\n"+Leisure.layout_text(report)+" · ○ Open  × Blocked / no path"
				hint_message=message; hint_valid=true
		elif building and build_kind=="erase":
			tint=Color(0.94,0.4,0.3,0.35)
			if not WallArt.at(lot,hover_cell.x,hover_cell.y).is_empty(): hint_message="Remove wall · Painting moves into the collection"
			if not Windows.at(lot,hover_cell.x,hover_cell.y).is_empty(): hint_message="Remove window · Refund §%d · Wall stays" % Windows.resale(lot,hover_cell.x,hover_cell.y)
		_diamond(preview_cell.x,preview_cell.y,footprint.x,footprint.y,tint,4,outline)
		_draw_impact_badges()
		if not hint_message.is_empty(): _draw_preview_label(hint_message,hint_valid,hint_tone)
	if not building and not hover_target.is_empty(): _draw_hover()
	elif not walking.preview.is_empty(): _draw_walk_hint()
	if lot.building:
		var badge := Rect2(Vector2(size.x*0.5-150,22),Vector2(300,34))
		draw_style_box(preload("res://game/style.gd").box(Color("eac88c"),17),badge)
		draw_string(_font,badge.position+Vector2(25,23),"UNDER CONSTRUCTION  ·  Lot paused",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("5d4a2d"))

func _walk_line(cells: Array,start_cell: Vector2,color: Color) -> void:
	var previous := grid_point(start_cell.x,start_cell.y)+Vector2(0,-1)
	for cell: Array in cells:
		var point := grid_point(float(cell[0])+0.5,float(cell[1])+0.5)+Vector2(0,-1)
		draw_line(previous,point,color,2.0,true)
		draw_circle(point,2.0,color)
		previous=point

func _walk_marker(cell: Vector2i,color: Color,s: float,label: String="") -> void:
	var point := grid_point(cell.x+0.5,cell.y+0.5)+Vector2(0,-2)
	draw_set_transform(point,0,Vector2(1,0.5))
	draw_arc(Vector2.ZERO,9*s,0,TAU,24,Color("283e38"),4*s,true)
	draw_arc(Vector2.ZERO,9*s,0,TAU,24,color,2*s,true)
	draw_set_transform(Vector2.ZERO)
	if not label.is_empty():
		var font_size := maxi(10,roundi(10*s))
		var width := _font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var at := point+Vector2(-width*0.5,-s)
		draw_style_box(preload("res://game/style.gd").box(Color("23373b"),5),Rect2(at+Vector2(-4,-font_size),Vector2(width+8,font_size+4)))
		draw_string(_font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw_walk_ground(s: float) -> void:
	if not show_cues or building: return
	var current := Color("c6d6a4")
	var route_start: Vector2=walking.start
	var displayed_route: Array=[]
	if not walking.route.is_empty():
		var track: Dictionary=motion.tracks.get(selected_member,{})
		route_start=Vector2(track.get("position",walking.start-Vector2(0.5,0.5)))+Vector2(0.5,0.5)
		for point: Vector2 in track.get("route",[]): displayed_route.append([roundi(point.x),roundi(point.y)])
		displayed_route.append_array(walking.route)
	_walk_line(displayed_route,route_start,Color(0.78,0.85,0.65,0.6))
	var destinations := {}
	for marker: Dictionary in walking.markers:
		if not destinations.has(marker.cell): destinations[marker.cell]={"active":false,"orders":[]}
		var entry: Dictionary=destinations[marker.cell]
		entry.active=entry.active or marker.active
		if not marker.active: entry.orders.append(str(marker.order))
	for cell: Vector2i in destinations:
		var entry: Dictionary=destinations[cell]
		_walk_marker(cell,current if entry.active else Color("e9c987"),s," · ".join(entry.orders))
	var preview: Dictionary=walking.preview
	if preview.is_empty(): return
	var cell: Vector2i=preview.cell
	var good: bool=preview.ok
	var queued: bool=good and int(preview.get("ahead",0))>0
	var color := Color("e9c987") if queued else Color("d8edb4") if good else Color("e8a18a")
	if good and not queued: _walk_line(preview.path,walking.start,Color(0.85,0.93,0.71,0.8))
	_diamond(cell.x,cell.y,1,1,Color(color,0.13),1,color)
	_walk_marker(cell,color,s)
	if not good:
		var at := grid_point(cell.x+0.5,cell.y+0.5)+Vector2(0,-3)
		draw_line(at+Vector2(-4,-2)*s,at+Vector2(4,2)*s,color,2*s,true)
		draw_line(at+Vector2(-4,2)*s,at+Vector2(4,-2)*s,color,2*s,true)

func _draw_walk_hint() -> void:
	var preview: Dictionary=walking.preview
	var title := str(preview.message)
	var detail := "Click to add to the plan"
	if not preview.ok: detail="Choose another spot or review the resident's Plan"
	elif int(preview.ahead)>0: detail="The route is chosen when this walk starts"
	elif preview.here: detail="Already here"
	else: detail="%d %s · Click to walk" % [preview.path.size(),"step" if preview.path.size()==1 else "steps"]
	var width := maxf(_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x,_font.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)+24
	var at := Vector2(clampf(_pointer.x+18,8,size.x-width-8),clampf(_pointer.y-62,8,size.y-220))
	draw_style_box(preload("res://game/style.gd").box(Color("1c2a2f"),6,Color("71877b")),Rect2(at,Vector2(width,52)))
	draw_string(_font,at+Vector2(12,20),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f4eedf"))
	draw_string(_font,at+Vector2(12,39),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("bdd89e") if preview.ok else Color("e8a18a"))

func _draw_access_ground(lot: Dictionary) -> void:
	var report: Dictionary=placement_impact.get("after",access_report)
	var reachable: Dictionary=report.get("reachable",{})
	for tile: Array in lot.floors:
		var cell := Vector2i(int(tile[0]),int(tile[1]))
		if reachable.has(cell): _diamond(cell.x,cell.y,1,1,Color(0.52,0.79,0.61,0.25),1)
	for cell: Vector2i in report.get("unreachable",[]):
		_diamond(cell.x,cell.y,1,1,Color(0.89,0.40,0.32,0.30),1,Color("efab91"))
	_diamond(8,14,1,1,Color(0.93,0.79,0.55,0.45),2,Color("ffe3a2"))
	var gate := grid_point(8.5,14.5)+Vector2(0,18)
	draw_string(_font,gate-Vector2(27,0),"Entrance",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0bf"))

func _draw_access_issues(s: float) -> void:
	var index := 0
	var occupied: Array[Rect2]=[]
	var bounds := Rect2(Vector2(8,64),Vector2(size.x-16,maxf(32,size.y-240)))
	for issue: Dictionary in access_report.get("issues",[]):
		index+=1
		var selected: bool=str(issue.key)==access_focus
		_diamond(issue.cell.x,issue.cell.y,issue.footprint.x,issue.footprint.y,Color(0.90,0.35,0.27,0.30),4,Color("ffe3a2") if selected else Color("ffae92"))
		var point := grid_point(issue.center.x,issue.center.y)+Vector2(0,-43*s)
		var rect := ResidentCues.fit(Rect2(point-Vector2(14,14),Vector2(28,28)),bounds,occupied)
		if not rect.has_area(): continue
		occupied.append(rect); access_markers[str(issue.key)]=rect
		draw_line(grid_point(issue.center.x,issue.center.y)+Vector2(0,-12*s),rect.get_center(),Color("f3c6a3"),1.5,true)
		draw_style_box(preload("res://game/style.gd").box(Color("f2d1b4"),5,Color("ffe7a0") if selected else Color("b76b55")),rect)
		var width := _font.get_string_size(str(index),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_string(_font,rect.get_center()+Vector2(-width*0.5,5),str(index),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("643b32"))
		if access_inspecting:
			_hit_regions.append({"polygon":PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),"target":{"type":"access","id":str(issue.key)}})

func _build_residents() -> Array:
	var residents: Array=[]
	for family: Dictionary in world.families.values():
		for member: Dictionary in family.members:
			if member.lot_id==lot_id: residents.append({"id":str(member.id),"name":str(member.name),"x":int(member.x),"y":int(member.y)})
	return residents

func _update_preview(lot: Dictionary) -> void:
	var people := _build_residents()
	var signature := str([Session.world.get_instance_id(),lot_id,lot.revision,lot.funds,hover_cell,build_kind,build_rotation,build_object_id,people])
	if signature==_preview_signature: return
	_preview_signature=signature
	var residents: Array=[]
	for member: Dictionary in people: residents.append(Vector2i(member.x,member.y))
	var command := {"type":"move_object" if build_kind=="move" else "place","kind":build_kind,"object_id":build_object_id,"x":hover_cell.x,"y":hover_cell.y,"rotation":build_rotation}
	preview_result=BuildRules.inspect(lot,command,residents)
	preview_result.impact=BuildImpact.inspect(lot,command,preview_result,people)
	_preview_spaces={}
	if preview_result.get("ok",false) and Leisure.KINDS.has(preview_result.kind):
		var draft := lot.duplicate(true)
		if build_kind=="move":
			draft.objects=draft.objects.filter(func(object): return object.id!=build_object_id)
		var candidate := {"id":"preview","kind":preview_result.kind,"x":hover_cell.x,"y":hover_cell.y,"rotation":build_rotation}
		draft.objects.append(candidate)
		_preview_spaces=Leisure.spaces({},draft,candidate)

func _update_room_preview(lot: Dictionary) -> void:
	var people := _build_residents()
	var signature := str(["room",Session.world.get_instance_id(),lot_id,lot.revision,lot.funds,hover_cell,room_anchor,build_rotation,people])
	if signature==_preview_signature: return
	_preview_signature=signature
	var residents: Array=[]
	for member: Dictionary in people: residents.append(Vector2i(member.x,member.y))
	var command := {"type":"build_room","x":room_anchor.x,"y":room_anchor.y,"end_x":hover_cell.x,"end_y":hover_cell.y,"rotation":build_rotation}
	preview_result=RoomPlan.inspect(lot,command,residents)
	preview_result.impact=BuildImpact.inspect(lot,command,preview_result,people)

func _fit_inspection(preferred: Rect2) -> Rect2:
	var bounds := Rect2(Vector2(8,8),size-Vector2(16,16))
	var avoid: Array[Rect2]=overlay_rects.duplicate()
	for marker: Rect2 in impact_markers.values(): avoid.append(marker.grow(6))
	if not leisure_markers.is_empty():
		var places := Rect2(leisure_markers[0].point,Vector2.ONE)
		for marker: Dictionary in leisure_markers: places=places.expand(marker.point)
		places=places.grow(14)
		places.position.y-=42; places.size.y+=42
		avoid.append(places)
	var fitted := ResidentCues.fit(preferred,bounds,avoid)
	# Keep the explanation available when the compact HUD leaves no alternative.
	return fitted if fitted.has_area() else ResidentCues.fit(preferred,bounds,overlay_rects)

func _draw_preview_label(message: String, valid: bool, tone: Color=Color.TRANSPARENT) -> void:
	var lines := message.split("\n")
	var width := 0.0
	for line: String in lines: width=maxf(width,_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+24)
	width=minf(width,size.x-16)
	var position := Vector2(clampf(_pointer.x+16,8,size.x-width-8),clampf(_pointer.y-40,8,size.y-220))
	preview_label_rect=_fit_inspection(Rect2(position,Vector2(width,12+18*lines.size())))
	if not preview_label_rect.has_area(): return
	position=preview_label_rect.position
	draw_style_box(preload("res://game/style.gd").box(Color("1c2a2f"),6),preview_label_rect)
	for index in range(lines.size()):
		draw_string(_font,position+Vector2(12,20+18*index),lines[index],HORIZONTAL_ALIGNMENT_LEFT,width-24,12,tone if tone.a>0 else Color("d8f1b2") if valid else Color("ffab8f"))

func _leisure_spaces(lot: Dictionary, object: Dictionary, layout_only: bool=false) -> Dictionary:
	var reservations: Array=[]
	if not layout_only:
		for family: Dictionary in world.families.values():
			for resident: Dictionary in family.members:
				if resident.lot_id==lot_id: reservations.append([resident.id,resident.x,resident.y,resident.task.get("id",""),Leisure.place(resident)])
	var key := str([lot_id,lot.revision,selected_member,object,layout_only,reservations])
	if key!=_leisure_key:
		_leisure_key=key
		var member: Dictionary={}
		if not layout_only:
			for family: Dictionary in world.families.values():
				for resident: Dictionary in family.members:
					if resident.id==selected_member: member=resident; break
		_leisure_cached=Leisure.spaces({} if layout_only else world,lot,object,member)
	return _leisure_cached

func _draw_leisure_places(report: Dictionary) -> void:
	leisure_report=report
	for place: Dictionary in report.cells:
		var cell: Vector2i=place.cell
		var point := grid_point(cell.x+0.5,cell.y+0.5)+Vector2(0,-3)
		var status: String=place.status
		var color := Color("bddd9e") if status=="open" else Color("efc77d") if status=="reserved" else Color("c6d1cf") if status=="occupied" else Color("f0a28d")
		_diamond(cell.x+0.14,cell.y+0.14,0.72,0.72,Color(color,0.16),2,Color(color,0.70))
		draw_circle(point,7,Color("243736"))
		if status=="open": draw_arc(point,4,0,TAU,20,color,1.5,true)
		elif status=="reserved": draw_circle(point,4,color)
		elif status=="occupied": draw_line(point-Vector2(4,0),point+Vector2(4,0),color,2,true)
		else:
			draw_line(point-Vector2(3,3),point+Vector2(3,3),color,1.5,true)
			draw_line(point+Vector2(-3,3),point+Vector2(3,-3),color,1.5,true)
		leisure_markers.append({"cell":cell,"status":status,"point":point})

func _draw_hover() -> void:
	var title := str(hover_target.get("name",""))
	var detail := "Click to select" if hover_target.get("owner") == Session.profile_id else "Click to chat"
	if hover_target.type=="care": detail="Click to plan care · Your existing orders keep priority"
	if hover_target.type=="wall_art":
		var chosen := WallArt.source(world.lots[lot_id],"art:"+str(hover_target.id))
		if chosen.is_empty(): return
		title=str(Paintings.SUBJECTS[chosen.picture.subject]); detail=Paintings.credit(chosen.picture)+" · Click to inspect"
	if hover_target.type == "object":
		var item: Dictionary = Catalog.ITEMS[hover_target.kind]
		title = str(item.name)
		detail = str(item.need).capitalize() + " · Click to use"
		if Leisure.KINDS.has(hover_target.kind):
			var report := _leisure_spaces(world.lots[lot_id],hover_target)
			_draw_leisure_places(report)
			detail=Leisure.summary(report)+" · Click to "+("queue" if report.available.is_empty() or report.reserved>=report.capacity else "join")
			if report.available.is_empty(): detail+="\n"+Leisure.waiting_reason(report)
			detail+="\n○ Open  ● Reserved  — Occupied  × Blocked / no path"
		if bool(item.get("exclusive",false)) and not hover_target.kind in ["garden_bed","easel"]:
			for family: Dictionary in world.families.values():
				for resident: Dictionary in family.members:
					if resident.lot_id == lot_id and resident.task.get("target_id") == hover_target.id:
						detail = "In use by " + str(resident.name) + " · Click to queue"
		if hover_target.kind=="dining_table":
			for object: Dictionary in world.lots[lot_id].objects:
				if object.id==hover_target.id: detail=Meals.summary(object.meal)+" · Click to choose a meal\n"+Leisure.summary(_leisure_spaces(world.lots[lot_id],hover_target)); break
		if hover_target.kind=="easel":
			for object: Dictionary in world.lots[lot_id].objects:
				if object.id==hover_target.id: detail=Paintings.summary(object.painting)+" · Click to inspect"; break
		if hover_target.kind=="garden_bed":
			for object: Dictionary in world.lots[lot_id].objects:
				if object.id==hover_target.id: detail=Gardens.summary(object.garden)+" · Click to inspect"; break
		var dimensions := Catalog.footprint(str(hover_target.kind),int(hover_target.rotation))
		_diamond(float(hover_target.x),float(hover_target.y),dimensions.x,dimensions.y,Color(0.95,0.95,0.75,0.14),2,Color("fff2bd"))
	var lines := detail.split("\n")
	var width := _font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+24
	for line: String in lines: width=maxf(width,_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+24)
	width=minf(width,size.x-16)
	var position := Vector2(clampf(_pointer.x+18,8,size.x-width-8),clampf(_pointer.y-62,8,size.y-220))
	var badge := _fit_inspection(Rect2(position,Vector2(width,34+18*lines.size())))
	if not badge.has_area(): return
	position=badge.position
	draw_style_box(preload("res://game/style.gd").box(Color("1c2a2f"),6,Color("71877b")),badge)
	draw_string(_font,position+Vector2(12,20),title,HORIZONTAL_ALIGNMENT_LEFT,width-24,14,Color("f4eedf"))
	for index in range(lines.size()):
		draw_string(_font,position+Vector2(12,39+18*index),lines[index],HORIZONTAL_ALIGNMENT_LEFT,width-24,12,Color("bdd89e"))

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
		"easel": _easel_furnishing(obj,s)
		"garden_bed": _garden_furnishing(obj,s)
		"bed":
			_block(x+0.05,y+0.05,w-0.1,d-0.1,10*s,Color("785648"))
			_block(x+0.08,y+0.08,w-0.16,d-0.16,6*s,Color("e9e4cd"),10*s)
			_block(x+0.09,y+d*0.36,w-0.18,d*0.60,3*s,FurnitureColors.material(obj,"92aaa6",0),16*s)
			_block(x+0.16,y+0.13,w-0.32,d*0.18,3*s,Color("faf2d9"),16*s)
			_block(x+0.02,y+0.02,w-0.04,0.12,24*s,Color("967259"))
		"sofa":
			_block(x+0.06,y+0.08,w-0.12,d-0.16,12*s,FurnitureColors.material(obj,"be7c57",-0.12))
			_block(x+0.08,y+0.06,w-0.16,0.2,25*s,FurnitureColors.material(obj,"d5996e",0.05))
			_block(x+0.08,y+0.29,w-0.16,d-0.4,4*s,FurnitureColors.material(obj,"e0a576",0.12),12*s)
			_block(x+0.03,y+0.2,0.16,d-0.25,21*s,FurnitureColors.material(obj,"cb9066",0))
			_block(x+w-0.19,y+0.2,0.16,d-0.25,21*s,FurnitureColors.material(obj,"cb9066",0))
		"fridge":
			_block(x+0.1,y+0.1,w-0.2,d-0.2,39*s,FurnitureColors.material(obj,"cee0d5",0.16))
			var p := grid_point(x+w-0.08,y+d*0.7)
			draw_line(p+Vector2(0,-14*s),p+Vector2(0,-29*s),Color("718c86"),2*s)
		"shower":
			_block(x+0.06,y+0.06,w-0.12,d-0.12,5*s,Color("e4e7da"))
			_block(x+0.06,y+0.06,w-0.12,0.12,42*s,FurnitureColors.material(obj,"a4c7c3",0.12))
			var p := grid_point(x+0.5,y+0.2)
			draw_line(p+Vector2(0,-33*s),p+Vector2(6,-36)*s,Color("edf0df"),3*s)
		"toilet":
			_block(x+0.22,y+0.1,w-0.44,0.25,22*s,FurnitureColors.material(obj,"e6e4d3",0.18))
			_block(x+0.22,y+0.35,w-0.44,d-0.45,10*s,FurnitureColors.material(obj,"eaeada",0.24))
			var p := grid_point(x+0.5,y+0.63)+Vector2(0,-11*s)
			draw_set_transform(p,0,Vector2(1,0.6))
			draw_circle(Vector2.ZERO,8*s,FurnitureColors.material(obj,"f5f3e4",0.32))
			draw_circle(Vector2.ZERO,4*s,Color("8ca9a4"))
			draw_set_transform(Vector2.ZERO)
		"tv":
			_block(x+0.08,y+0.1,w-0.16,d-0.2,9*s,FurnitureColors.material(obj,"87674e",-0.12))
			_block(x+0.14,y+0.18,w-0.28,d-0.36,23*s,Color("34494d"),9*s)
			var p := grid_point(x+0.55,y+d-0.17)+Vector2(0,-20*s)
			draw_circle(p,6*s,Color("9bc9b0"))
		"stereo":
			_block(x+0.08,y+0.16,w-0.16,d-0.32,9*s,FurnitureColors.material(obj,"967450",-0.08))
			_block(x+0.12,y+0.20,w-0.24,d-0.40,13*s,Color("35484a"),9*s)
			for offset: float in [0.27,0.73]:
				var speaker := grid_point(x+offset,y+d-0.18)+Vector2(0,-16*s)
				draw_circle(speaker,5.3*s,Color("192c30")); draw_circle(speaker,2.8*s,Color("677d78"))
			var display := grid_point(x+0.5,y+d-0.18)+Vector2(0,-20*s)
			draw_line(display-Vector2(3,0)*s,display+Vector2(3,0)*s,Color("b9dc8e"),2*s,true)
			if not building and not Leisure.players(world,lot_id,str(obj.get("id",""))).is_empty():
				var pulse := 0.0 if Preferences.values.reduced_motion else sin(_time*TAU/0.6)*1.5
				draw_string(_font,display+Vector2(12,-12+pulse)*s,"♪",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,roundi(17*s)),Color("edc98b"))
		"bookshelf":
			_block(x+0.08,y+0.1,w-0.16,d-0.2,35*s,FurnitureColors.material(obj,"987256",-0.08))
			for i in range(5):
				var p := grid_point(x+0.2+float(i)*0.12,y+d-0.08)
				draw_line(p+Vector2(0,-12*s),p+Vector2(0,-29*s),[Color("b3c3a2"),Color("d8a06e"),Color("edd8a1")][i%3],4*s)
		"plant":
			var foliage := grid_point(x+0.5,y+0.5)
			_hit_regions.append({"polygon":PackedVector2Array([foliage+Vector2(-13,-34)*s,foliage+Vector2(13,-34)*s,foliage+Vector2(13,-8)*s,foliage+Vector2(-13,-8)*s]),"target":_drawing_target})
			_block(x+0.3,y+0.3,0.4,0.4,10*s,FurnitureColors.material(obj,"bf8665",0))
			var p := grid_point(x+0.5,y+0.5)+Vector2(0,-11*s)
			draw_line(p,p+Vector2(0,-20*s),Color("466f4b"),3*s)
			for i in range(4):
				draw_circle(p+Vector2((-1 if i%2==0 else 1)*6,-8-i*3)*s,6*s,Color("71985e"))
		"table", "game_table", "dining_table":
			_block(x+0.2,y+0.2,0.14,0.14,18*s,FurnitureColors.material(obj,"806550",-0.22))
			_block(x+w-0.34,y+d-0.34,0.14,0.14,18*s,FurnitureColors.material(obj,"806550",-0.22))
			_block(x+0.04,y+0.04,w-0.08,d-0.08,4*s,FurnitureColors.material(obj,"ccaa78",0.12),18*s)
			if kind=="dining_table":
				_diamond(x+0.2,y+0.2,1.6,1.6,Color("e8e0c7"),22.5*s)
				for place: Vector2 in [Vector2(0.35,0.7),Vector2(1.65,1.3),Vector2(0.7,1.65),Vector2(1.3,0.35)]:
					MealArt.draw(self,grid_point(x+place.x,y+place.y)+Vector2(0,-23*s),0.24*s,"",0)
				if str(obj.get("meal",{}).get("recipe",""))!="": MealArt.draw(self,grid_point(x+1,y+1)+Vector2(0,-25*s),0.58*s,str(obj.meal.recipe),int(obj.meal.servings))
			if kind=="game_table":
				for board_y in range(4):
					for board_x in range(4):
						_diamond(x+0.24+board_x*0.38,y+0.24+board_y*0.38,0.38,0.38,Color("4f7776") if (board_x+board_y)%2==0 else Color("eee4c5"),22.5*s)
				for index in range(4):
					var place: Vector2=[Vector2(0.43,0.43),Vector2(1.57,1.57),Vector2(0.81,1.19),Vector2(1.19,0.81)][index]
					var piece := grid_point(x+place.x,y+place.y)+Vector2(0,-25*s)
					draw_circle(piece,3.4*s,Color("dc916f") if index%2==0 else Color("20383d"))
					draw_circle(piece+Vector2(0,-1.2*s),2.5*s,Color("efb38d") if index%2==0 else Color("527d80"))
		_:
			_block(x+0.1,y+0.1,w-0.2,d-0.2,16*s,color)

	_drawing_target = {}
	_art_object = {}

func _easel_furnishing(object: Dictionary,s: float) -> void:
	var x: float=object.x; var y: float=object.y
	var wood := FurnitureColors.material(object,"ae8259")
	var top := grid_point(x+0.5,y+0.5)+Vector2(0,-49*s)
	for foot: Vector2 in [Vector2(0.08,0.9),Vector2(0.92,0.9),Vector2(0.5,0.05)]:
		draw_line(grid_point(x+foot.x,y+foot.y),top,wood,3*s,true)
	var left := grid_point(x+0.08,y+0.65)+Vector2(0,-43*s)
	var right := grid_point(x+0.92,y+0.65)+Vector2(0,-43*s)
	var down := Vector2(0,27*s)
	var corners := PackedVector2Array([left,right,right+down,left+down])
	_poly([left-Vector2(0,2*s),right-Vector2(0,2*s),right+down+Vector2(0,3*s),left+down+Vector2(0,3*s)],wood,wood.darkened(0.2))
	draw_set_transform_matrix(Transform2D(right-left,down,left))
	preload("res://game/painting_art.gd").draw(self,object.get("painting",Paintings.create()))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_hit_regions.append({"polygon":corners,"target":_drawing_target})

func _garden_furnishing(object: Dictionary,s: float) -> void:
	var x: float=object.x; var y: float=object.y
	var bed: Dictionary=object.get("garden",Gardens.create())
	_block(x+0.04,y+0.04,1.92,0.92,7*s,FurnitureColors.material(object,"906e50",-0.12))
	_diamond(x+0.15,y+0.15,1.7,0.7,Color("68533c") if float(bed.water)>0 else Color("9a805b"),7.5*s)
	for row in range(2):
		for column in range(3):
			var p := grid_point(x+0.38+column*0.6,y+0.32+row*0.36)+Vector2(0,-8*s)
			if str(bed.crop).is_empty():
				draw_line(p+Vector2(-5,0)*s,p+Vector2(5,0)*s,Color("776045"),2*s,true); continue
			var progress := clampf(float(bed.growth)/float(Gardens.CROPS[bed.crop].seconds),0.0,1.0)
			var tall := 4.0+progress*(20.0 if bed.crop=="tomato" else 8.0)
			var top := p+Vector2(0,-tall*s)
			draw_line(p,top,Color("496f40"),2*s,true)
			for leaf in range(3):
				draw_circle(top+Vector2((-1 if leaf%2==0 else 1)*(2+progress*3),leaf*3)*s,(2+progress*2)*s,Color("729858"))
			if progress>0.65:
				var fruit: Color=Color(str(Gardens.CROPS[bed.crop].color)) if Gardens.ripe(bed) else Color("91ad59")
				draw_circle(top+Vector2(4,7)*s,(2.2+progress)*s,fruit)
				if bed.crop=="tomato": draw_circle(top+Vector2(-3,12)*s,2.7*s,fruit)
			var hit := Rect2(top-Vector2(8,5)*s,Vector2(16,tall+8)*s)
			_hit_regions.append({"polygon":PackedVector2Array([hit.position,Vector2(hit.end.x,hit.position.y),hit.end,Vector2(hit.position.x,hit.end.y)]),"target":_drawing_target})
	if not str(bed.crop).is_empty() and (Gardens.ripe(bed) or float(bed.water)<=0.000001):
		var p := grid_point(x+1,y+0.5)+Vector2(0,-40*s)
		draw_circle(p,8*s,Color("edc98b")); draw_string(_font,p+Vector2(-3,4)*s,"✓" if Gardens.ripe(bed) else "!",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(10,roundi(12*s)),Color("142329"))

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
	var dancing: bool=pose.get("kind")=="stereo"
	var dance_phase := _time*TAU/0.6+float(posmod(str(member.id).hash(),7))*0.4
	if dancing and not reduced: stride=sin(dance_phase)
	var bob := absf(stride)*1.2*s if walking else 0.0 if reduced else absf(cos(dance_phase))*1.4*s if dancing else sin(_time*3.0+float(str(member.id).hash()%10))*0.35*s
	draw_set_transform(p,0,Vector2(1,0.45))
	draw_circle(Vector2.ZERO,9*s,Color(0.12,0.20,0.15,0.22))
	if selected: draw_arc(Vector2.ZERO,12*s,0,TAU,32,Color("fff2bd"),2*s,true)
	draw_set_transform(Vector2.ZERO)
	var look := Appearance.of(member)
	var shirt: Color=Appearance.SHIRT[int(look.shirt)]
	var skin: Color=Appearance.SKIN[int(look.skin)]
	var direction: Vector2=motion.direction(member)
	var forward := ResidentFacing.project(direction)
	var lateral := ResidentFacing.project(Vector2(direction.y,-direction.x))
	var facing := forward.normalized()
	var kind := str(pose.get("kind",""))
	if member.get("task",{}).get("meal_action")=="prepare" and member.task.get("meal_phase")=="serve": kind="meal_prepare"
	if kind=="easel" and member.get("task",{}).get("paint_action")=="sell": kind="painting_sale"
	if kind=="garden_bed": kind="garden_"+str(member.get("task",{}).get("garden_action","water"))
	var behind: bool=facing.y< -0.2 and kind not in ["chat","tv","shower"]
	if behind: _activity_prop(p+forward*6*s,kind,s,reduced,facing,skin)
	for side: float in [-1.0,1.0]:
		var hip := p+(Vector2(0,-14)+lateral*side*3)*s
		var foot := p+(Vector2(0,-4)+lateral*side*3.5+forward*stride*side*4)*s
		if sitting: foot=p+(Vector2(0,-8)+lateral*side*3.5+forward*9)*s
		draw_line(hip,foot,Color("424f54"),4*s,true)
	var far_side := -1.0 if lateral.y>=0.0 else 1.0
	_resident_arm(p,s,lateral,forward,far_side,stride,skin,dancing)
	draw_line(p+Vector2(0,-13)*s,p+Vector2(0,-24)*s+Vector2(0,bob),shirt,lerpf(8.0,12.0,absf(lateral.x))*s,true)
	# A quiet collar makes the body turn legible without enlarging the resident.
	if facing.y> -0.2:
		draw_line(p+(Vector2(0,-25)+forward*2-lateral*2)*s+Vector2(0,bob),p+(Vector2(0,-25)+forward*2+lateral*2)*s+Vector2(0,bob),shirt.lightened(0.22),1.5*s,true)
	_resident_arm(p,s,lateral,forward,-far_side,stride,skin,dancing,kind=="admire_art")
	Appearance.draw_head(self,p+Vector2(0,-31)*s+Vector2(0,bob),s,look,facing)
	if not behind: _activity_prop(p+forward*6*s,kind,s,reduced,facing,skin)

func _resident_arm(p: Vector2,s: float,lateral: Vector2,forward: Vector2,side: float,stride: float,skin: Color,dancing: bool=false,admiring: bool=false) -> void:
	var shoulder := p+(Vector2(0,-23)+lateral*side*6)*s
	var hand := p+(Vector2(0,-14)+lateral*side*7-forward*stride*side*3)*s
	if admiring:
		var elbow := p+(Vector2(0,-18)+lateral*side*8+forward*4)*s
		hand=p+(Vector2(0,-29)+forward*5+lateral*side*2)*s
		draw_line(shoulder,elbow,skin,3*s,true); draw_line(elbow,hand,skin,3*s,true)
	elif dancing:
		var elbow := p+(Vector2(0,-22)+lateral*side*9+forward*stride*side*2)*s
		hand=p+(Vector2(0,-29-absf(stride)*3)+lateral*side*8)*s
		draw_line(shoulder,elbow,skin,3*s,true); draw_line(elbow,hand,skin,3*s,true)
	else: draw_line(shoulder,hand,skin,3*s,true)

func _activity_pose(member: Dictionary) -> Dictionary:
	if motion.moving(str(member.id)): return {}
	return ResidentFacing.activity(world,member)

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
	draw_line(torso,feet,FurnitureColors.material(object,"97b8b1",0.08),14*s,true)
	Appearance.draw_head(self,head,s,Appearance.of(member))
	var target := {"type":"member","id":member.id,"name":member.name,"owner":family.id}
	var box := Rect2(head,Vector2.ZERO).expand(feet).grow(9*s)
	_hit_regions.append({"polygon":PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]),"target":target})
	var float_y := 0.0 if Preferences.values.reduced_motion else sin(_time*1.5)*2.0
	draw_string(_font,head+Vector2(8,-15+float_y)*s,"z z",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f5efd8"))
	if str(member.id)==selected_member:
		draw_arc(head,10*s,0,TAU,24,Color("fff2bd"),1.5*s,true)

func _activity_prop(p: Vector2,kind: String,s: float,reduced: bool,facing: Vector2=Vector2.DOWN,skin: Color=Color("e0bb94")) -> void:
	draw_set_transform(p,0,Vector2(-1.0 if facing.x< -0.2 else 1.0,1))
	p=Vector2.ZERO
	match kind:
		"meal_prepare", "meal_eat":
			# A small bowl and utensil; carry is visible during the serving walk too.
			draw_arc(p+Vector2(5,-19)*s,7*s,0,PI,16,Color("eee3c7"),4*s,true)
			var lift := 0.0 if reduced else sin(_time*3.0)*2.0
			draw_line(p+Vector2(10,-20)*s,p+Vector2(12,-28+lift)*s,Color("b8c2bb"),1.5*s,true)
		"painting_sale":
			draw_rect(Rect2(p+Vector2(-9,-25)*s,Vector2(18,15)*s),Color("9b7954"))
			draw_rect(Rect2(p+Vector2(-7,-23)*s,Vector2(14,11)*s),Color("dfccac"))
			draw_line(p+Vector2(0,-23)*s,p+Vector2(0,-12)*s,Color("ba9c73"),1*s,true)
		"easel":
			var lift := 0.0 if reduced else sin(_time*3.5)*2.0
			draw_line(p+Vector2(5,-23)*s,p+Vector2(13,-26+lift)*s,skin,3*s,true)
			draw_line(p+Vector2(13,-26+lift)*s,p+Vector2(18,-33+lift)*s,Color("ac8158"),1.5*s,true)
			draw_circle(p+Vector2(18,-34+lift)*s,1.5*s,Color("87a98d"))
			draw_circle(p+Vector2(-7,-19)*s,4*s,Color("d9bd88"))
		"game_table":
			var lift := 0.0 if reduced else sin(_time*3.0)*1.5
			draw_line(p+Vector2(7,-23)*s,p+Vector2(14,-19+lift)*s,skin,3*s,true)
			draw_circle(p+Vector2(15,-20+lift)*s,3*s,Color("df9c79"))
		"bookshelf":
			_poly([p+Vector2(-10,-20)*s,p+Vector2(0,-17)*s,p+Vector2(0,-9)*s,p+Vector2(-10,-12)*s],Color("ead9aa"),Color("8b6950"))
			_poly([p+Vector2(0,-17)*s,p+Vector2(10,-20)*s,p+Vector2(10,-12)*s,p+Vector2(0,-9)*s],Color("faf1d6"),Color("8b6950"))
		"table", "fridge":
			draw_rect(Rect2(p+Vector2(4,-20)*s,Vector2(7,7)*s),Color("f4e5cb"))
			draw_arc(p+Vector2(12,-17)*s,3*s,-PI*0.5,PI*0.5,10,Color("f4e5cb"),1.5*s,true)
			if kind=="table": draw_line(p+Vector2(7,-24)*s,p+Vector2(8,-29)*s,Color(1,0.98,0.86,0.7),1*s,true)
		"plant", "garden_water":
			draw_circle(p+Vector2(9,-17)*s,5*s,Color("719b91"))
			draw_line(p+Vector2(12,-18)*s,p+Vector2(19,-13)*s,Color("719b91"),3*s,true)
			for index in range(3):
				var fall := float(index)*4.0 if reduced else fmod(_time*14+float(index)*5,15.0)
				draw_circle(p+Vector2(18+index*2,-12+fall)*s,1*s,Color("cee6dd"))
		"garden_plant":
			var lift := 0.0 if reduced else sin(_time*4.0)*2.0
			draw_line(p+Vector2(7,-21)*s,p+Vector2(15,-14+lift)*s,Color("ac8158"),3*s,true)
			_poly([p+Vector2(12,-14+lift)*s,p+Vector2(18,-17+lift)*s,p+Vector2(20,-10+lift)*s],Color("9caaa3"))
		"garden_harvest":
			draw_arc(p+Vector2(12,-16)*s,7*s,PI,TAU,12,Color("b68e60"),2*s,true)
			draw_rect(Rect2(p+Vector2(4,-15)*s,Vector2(16,9)*s),Color("bd9868"))
			for index in range(3): draw_circle(p+Vector2(7+index*5,-15)*s,3*s,Color("d67954"))
		"shower":
			for index in range(4):
				var fall := float(index)*5.0 if reduced else fmod(_time*22+index*9,30.0)
				draw_line(p+Vector2(-13+index*8,-40+fall)*s,p+Vector2(-14+index*8,-35+fall)*s,Color(0.72,0.9,0.94,0.8),1.3*s,true)
	draw_set_transform(Vector2.ZERO)

func _trim_label(text: String, maximum: float) -> String:
	if _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=maximum: return text
	while not text.is_empty() and _font.get_string_size(text+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x>maximum: text=text.left(text.length()-1)
	return text+"…"

func _draw_resident_overlays(entities: Array, s: float) -> void:
	if not show_cues or building or world.lots[lot_id].building or Session.role=="joining": return
	var occupied: Array[Rect2]=[]
	var bounds := Rect2(Vector2(8,8),size-Vector2(16,16))
	# Labels must not hide another resident's face or intercept their body click.
	for entity: Dictionary in entities:
		if not entity.has("member"): continue
		var member: Dictionary=entity.member
		var pose := _activity_pose(member)
		if pose.get("kind")=="bed":
			var point := object_point(pose.object,Vector2(0.5,0.32))
			var head := grid_point(point.x,point.y)+Vector2(0,-22)*s
			occupied.append(Rect2(head-Vector2(10,10)*s,Vector2(20,20)*s))
		else: occupied.append(Rect2(resident_anchor(member)+Vector2(-12,-40)*s,Vector2(24,42)*s))
	# Shared chat bubbles sit above the pair, never over either face. Reserve
	# their space before placing name/need labels, just like the residents' bodies.
	var conversations := {}
	for entity: Dictionary in entities:
		if not entity.has("member"): continue
		var member: Dictionary=entity.member
		var pose := _activity_pose(member)
		var kind := str(pose.get("kind",""))
		if kind not in ["chat","tv"]: continue
		var at := resident_anchor(member)
		if not Rect2(Vector2.ZERO,size).has_point(at): continue
		if kind=="chat":
			var pair := [str(member.id),str(pose.partner.id)]; pair.sort()
			var key := str(pair)
			if conversations.has(key): continue
			conversations[key]=true
			var partner_at := resident_anchor(pose.partner)
			if not Rect2(Vector2.ZERO,size).has_point(partner_at): continue
			at=Vector2((at.x+partner_at.x)*0.5,minf(at.y,partner_at.y))
		var box := ResidentCues.fit(Rect2(at+Vector2(-13.5,-61)*s,Vector2(27,16)*s),bounds,occupied)
		if not box.has_area(): continue
		occupied.append(box)
		draw_style_box(preload("res://game/style.gd").box(Color("f2e7c7") if kind=="chat" else Color("304b4f"),4),box)
		if kind=="chat":
			for index in range(3):
				var rise := 0.0 if Preferences.values.reduced_motion else sin(_time*4.0+index)*1.2
				draw_circle(box.position+Vector2(6+index*7,8+rise)*s,1.5*s,Color("57736a"))
		else: draw_line(box.position+Vector2(7,6)*s,box.position+Vector2(20,6)*s,Color("b9d69f"),2*s,true)
	for entity: Dictionary in entities:
		if not entity.has("member") or entity.family.id!=Session.profile_id or world.lots[entity.family.home_lot].building: continue
		var member: Dictionary=entity.member
		var anchor := resident_anchor(member)
		if not Rect2(Vector2.ZERO,size).has_point(anchor): continue
		var head := anchor+Vector2(0,-31)*s
		var pose := _activity_pose(member)
		if pose.get("kind")=="bed":
			var point := object_point(pose.object,Vector2(0.5,0.32))
			head=grid_point(point.x,point.y)+Vector2(0,-22)*s
		var selected: bool=str(member.id)==selected_member
		if selected:
			var q := head+Vector2(0,-16)*s
			_poly([q+Vector2(0,-7)*s,q+Vector2(4,0)*s,q+Vector2(0,7)*s,q+Vector2(-4,0)*s],Color("e9d695"),Color("fff3b4"))
		var cue := ResidentCues.need(member,world.lots[lot_id],world)
		if cue.is_empty() and not selected: continue
		var caption := _trim_label(str(member.name),180.0)
		if not cue.is_empty(): caption=_trim_label(str(member.name),90.0)+" · "+str(cue.label)
		caption=_trim_label(caption,240.0)
		var width := _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+(36.0 if not cue.is_empty() else 18.0)
		var dimensions := Vector2(width,30.0 if not cue.is_empty() else 24.0)
		var center := head+Vector2(0,-42)*s if not cue.is_empty() else anchor+Vector2(0,18)*s
		var box := ResidentCues.fit(Rect2(center-dimensions*0.5,dimensions),bounds,occupied)
		if not box.has_area(): continue
		occupied.append(box)
		var color := Color("f4e8cd") if not cue.is_empty() else Color("203339")
		var edge := Color("c58670") if not cue.is_empty() else Color("c6d6a4")
		if not cue.is_empty():
			var tail := Vector2(clampf(head.x,box.position.x+8,box.end.x-8),box.end.y)
			draw_circle(head.lerp(tail,0.45),2.0,color)
			draw_circle(head.lerp(tail,0.72),3.0,color)
		draw_style_box(preload("res://game/style.gd").box(color,6,edge),box)
		var text_point := box.position+Vector2(28,20) if not cue.is_empty() else box.position+Vector2(9,17)
		draw_string(_font,text_point,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("30423b") if not cue.is_empty() else Color("f4eedf"))
		var target := {"type":"member","id":member.id,"owner":entity.family.id,"name":member.name}
		if not cue.is_empty():
			_draw_need_icon(box.position+Vector2(14,15),str(cue.need))
			target.type="care"; target.need=cue.need; target.name=str(member.name)+" · "+str(cue.label)
		var polygon := PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
		_hit_regions.append({"polygon":polygon,"target":target})
		resident_labels[str(member.id)]={"rect":box,"need":str(cue.get("need","")),"text":caption}

func _draw_need_icon(at: Vector2, need: String) -> void:
	var ink := Color("405b50")
	match need:
		"hunger":
			draw_arc(at+Vector2(0,-2),6,0,PI,12,ink,2,true)
			draw_line(at+Vector2(-6,-2),at+Vector2(6,-2),ink,2,true)
			draw_line(at+Vector2(-2,-6),at+Vector2(-1,-4),ink,1,true)
		"energy":
			draw_rect(Rect2(at+Vector2(-7,-3),Vector2(14,6)),Color("80a99a"))
			draw_rect(Rect2(at+Vector2(-6,-3),Vector2(4,4)),Color("f7f0da"))
			for x in [-7,7]: draw_line(at+Vector2(x,-5),at+Vector2(x,6),ink,1.5,true)
		"hygiene":
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(-5,2),at+Vector2(0,6),at+Vector2(5,2)]),Color("63918c"))
			draw_circle(at+Vector2(-1,2),1.2,Color("e2f0df"))
		"bladder":
			draw_rect(Rect2(at+Vector2(2,-6),Vector2(5,9)),Color("91a59b"))
			draw_arc(at+Vector2(-1,0),5,0,PI,12,ink,2,true)
			draw_line(at+Vector2(-6,0),at+Vector2(4,0),ink,2,true)
			draw_line(at+Vector2(0,4),at+Vector2(0,7),ink,2,true)
		"fun":
			var points := PackedVector2Array()
			for index in range(10): points.append(at+Vector2.from_angle(-PI/2+float(index)*PI/5)*(7.0 if index%2==0 else 3.2))
			draw_colored_polygon(points,Color("bb8b3e"))
		"social":
			draw_circle(at+Vector2(-2,-2),5,Color("779d85")); draw_circle(at+Vector2(4,3),3,ink)
			draw_line(at+Vector2(-3,1),at+Vector2(-6,5),Color("779d85"),2,true)
		"comfort":
			draw_rect(Rect2(at+Vector2(-5,-7),Vector2(10,8)),Color("ae8260"))
			draw_rect(Rect2(at+Vector2(-7,0),Vector2(14,5)),Color("ae8260"))
			for x in [-5,5]: draw_line(at+Vector2(x,4),at+Vector2(x,7),ink,1.5,true)


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
	if not building or access_inspecting or not build_kind in ["finish_floor","finish_wall"]: return
	var plan: Dictionary={}
	if paint_pending: plan=paint_plan
	elif _in_bounds(hover_cell):
		var anchor := hover_cell if paint_anchor.x<0 or finish_selection=="room" else paint_anchor
		var signature := str(["finish",lot_id,lot.revision,lot.funds,anchor,hover_cell,build_kind,finish_choice,finish_selection])
		if signature!=_preview_signature:
			_preview_signature=signature
			preview_result=Finishes.inspect(lot,{"surface":build_kind.trim_prefix("finish_"),"finish":finish_choice,"selection":finish_selection,"x":anchor.x,"y":anchor.y,"end_x":hover_cell.x,"end_y":hover_cell.y})
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
	if finish_selection=="room":
		var valid := bool(preview_result.get("ok",false))
		var unchanged: bool=preview_result.get("reason")=="unchanged"
		_draw_preview_label(("Click to fill room · " if valid else "")+str(preview_result.get("message","")),valid or unchanged)
		return
	var anchor := hover_cell if paint_anchor.x<0 else paint_anchor
	var low := Vector2i(mini(anchor.x,hover_cell.x),mini(anchor.y,hover_cell.y))
	var high := Vector2i(maxi(anchor.x,hover_cell.x),maxi(anchor.y,hover_cell.y))
	var valid := bool(preview_result.get("ok",false))
	_diamond(low.x,low.y,high.x-low.x+1,high.y-low.y+1,Color.TRANSPARENT if valid else Color(0.94,0.36,0.3,0.22),3,Color("d8f1b2") if valid else Color("ffab8f"))
	var hint := "Click first corner · " if paint_anchor.x<0 else "Click to apply · "
	_draw_preview_label((hint if valid else "")+str(preview_result.get("message","")),valid)

func _draw_room_finish_ground() -> void:
	if not paint_pending and not _in_bounds(hover_cell): return
	var plan: Dictionary=paint_plan if paint_pending else preview_result
	var cells := {}
	for cell: Array in plan.get("area",[]): cells[Vector2i(int(cell[0]),int(cell[1]))]=true
	var valid: bool=plan.get("ok",false) or plan.get("reason")=="unchanged"
	var color := Color("d8f1b2") if valid else Color("ffab8f")
	var offset := Vector2(0,-3)
	for cell: Vector2i in cells:
		if not valid: _diamond(cell.x,cell.y,1,1,Color(0.94,0.36,0.3,0.16),2)
		for edge: Array in [[Vector2i.UP,Vector2i.ZERO,Vector2i.RIGHT],[Vector2i.RIGHT,Vector2i.RIGHT,Vector2i.ONE],[Vector2i.DOWN,Vector2i.ONE,Vector2i.DOWN],[Vector2i.LEFT,Vector2i.DOWN,Vector2i.ZERO]]:
			if cells.has(cell+edge[0]): continue
			var start: Vector2i=cell+edge[1]; var end: Vector2i=cell+edge[2]
			draw_line(grid_point(start.x,start.y)+offset,grid_point(end.x,end.y)+offset,color,1.8,true)

func _draw_room_copy(lot: Dictionary) -> void:
	if not _in_bounds(hover_cell) and not copy_pending: return
	var residents: Array=[]
	for family: Dictionary in world.families.values():
		for member: Dictionary in family.members:
			if member.lot_id==lot_id: residents.append(Vector2i(int(member.x),int(member.y)))
	var key := str([lot_id,lot.revision,lot.funds,copy_source,copy_design,hover_cell,build_rotation,residents])
	if key!=_copy_preview_key:
		_copy_preview_key=key
		copy_preview=RoomCopy.inspect_source(lot,{"x":hover_cell.x,"y":hover_cell.y,"rotation":build_rotation},residents,copy_design) if not copy_design.is_empty() else RoomCopy.capture(lot,hover_cell) if copy_source.x<0 else RoomCopy.inspect(lot,{"source_x":copy_source.x,"source_y":copy_source.y,"x":hover_cell.x,"y":hover_cell.y,"rotation":build_rotation},residents)
	var plan: Dictionary=copy_plan if copy_pending else copy_preview
	var source: Dictionary=plan if copy_source.x<0 else plan.get("source",{})
	if source.get("ok",false) and copy_design.is_empty():
		for cell: Array in source.interior: _diamond(int(cell[0])+source.low.x,int(cell[1])+source.low.y,1,1,Color(0.55,0.78,0.88,0.22),2,Color("a9d6dd"))
	if copy_source.x<0 and copy_design.is_empty():
		_draw_preview_label(str(plan.message),bool(plan.ok)); return
	var valid: bool=plan.get("ok",false)
	var color := Color("b9de99") if valid else Color("eda58e")
	if plan.has("extent"):
		_diamond(plan.low.x,plan.low.y,plan.extent.x,plan.extent.y,Color(color,0.18),3,color)
	if valid:
		var scale := _cell.x/48.0
		for cell: Array in plan.floors:
			var finish: String=plan.finishes.floor.get(Finishes.key(int(cell[0]),int(cell[1])),"oak")
			_draw_floor_finish(int(cell[0]),int(cell[1]),Finishes.PALETTES.floor[finish])
		for cell: Array in plan.walls:
			var finish: String=plan.finishes.wall.get(Finishes.key(int(cell[0]),int(cell[1])),"cream")
			_block(int(cell[0]),int(cell[1]),1,1,16*scale,Color(Finishes.PALETTES.wall[finish].color))
			var style: String=plan.windows.get(Windows.key(int(cell[0]),int(cell[1])),"")
			if not style.is_empty(): _draw_window(plan,int(cell[0]),int(cell[1]),16*scale,style,scale,true)
		for cell: Array in plan.doors: _diamond(int(cell[0]),int(cell[1]),1,1,Color("dfbb7d"),3,Color("fff0b9"))
		var ordered: Array=plan.objects.duplicate()
		ordered.sort_custom(func(a,b): return int(a.x)+int(a.y)<int(b.x)+int(b.y))
		for item: Dictionary in ordered:
			var object := item.duplicate(true)
			if object.kind=="garden_bed": object.garden=Gardens.create()
			if object.kind=="easel": object.painting=Paintings.create()
			if object.kind=="dining_table": object.meal=Meals.create()
			var hits := _hit_regions.size(); _furnishing(object,scale); _hit_regions.resize(hits)
		_diamond(plan.low.x,plan.low.y,plan.extent.x,plan.extent.y,Color.TRANSPARENT,3,color)
	var message := "Copying room…" if copy_pending else str(plan.message)
	if valid:
		message+="\nStructure §%d · Furniture §%d · Finishes §%d · Windows §%d" % [plan.structure_cost,plan.furniture_cost,plan.finish_cost,plan.window_cost]
		if plan.get("food",false): message+="\nDining tables start empty. Meals are not copied."
		if plan.get("art",false): message+="\nCopied easels start blank; earned art stays here."
		if plan.garden: message+="\nGarden beds start empty. Crops are not copied."
	_draw_preview_label(message,valid)

func _draw_room_preview(lot: Dictionary) -> void:
	if not _in_bounds(hover_cell): return
	if room_pending:
		_draw_preview_label("Building room…",true)
		return
	if room_anchor.x<0:
		_diamond(hover_cell.x,hover_cell.y,1,1,Color(0.85,0.94,0.65,0.2),3,Color("f8edb7"))
		_draw_preview_label("Room · Click the first corner",true)
		return
	_update_room_preview(lot)
	var low := Vector2i(mini(room_anchor.x,hover_cell.x),mini(room_anchor.y,hover_cell.y))
	var high := Vector2i(maxi(room_anchor.x,hover_cell.x),maxi(room_anchor.y,hover_cell.y))
	var valid := bool(preview_result.get("ok",false))
	var tint := Color(0.64,0.9,0.49,0.23) if valid else Color(0.94,0.36,0.3,0.3)
	var outline := Color("d8f1b2") if valid else Color("ffab8f")
	if placement_impact.get("warning",false): outline=Color("efc77d"); tint=Color(outline,0.23)
	_diamond(low.x,low.y,high.x-low.x+1,high.y-low.y+1,tint,3,outline)
	if valid:
		var s := _cell.x/48.0
		for cell: Array in preview_result.walls:
			_block(int(cell[0]),int(cell[1]),1,1,14*s,Color(0.68,0.88,0.54,0.36))
		for cell: Array in preview_result.doors:
			_diamond(int(cell[0]),int(cell[1]),1,1,Color(1.0,0.81,0.4,0.75),5,Color("fff0ba"))
	_diamond(room_anchor.x,room_anchor.y,1,1,Color(1,0.94,0.65,0.25),4,Color("fff0ba"))
	_draw_impact_badges()
	var message := str(preview_result.get("message",""))
	if not placement_impact.get("message","").is_empty(): message+="\n"+str(placement_impact.message)
	_draw_preview_label(message,valid,Color("efc77d") if placement_impact.get("warning",false) else Color.TRANSPARENT)


func _update_window_preview(lot: Dictionary) -> void:
	if not building or build_kind!="window" or access_inspecting or window_pending or not _in_bounds(hover_cell): return
	var signature := str(["window",lot_id,lot.revision,lot.funds,hover_cell,window_style])
	if signature!=_preview_signature:
		_preview_signature=signature
		preview_result=Windows.inspect(lot,{"x":hover_cell.x,"y":hover_cell.y,"style":window_style})

func _draw_window_preview() -> void:
	if window_pending: _draw_preview_label("Fitting window…",true); return
	if not _in_bounds(hover_cell): return
	var valid: bool=preview_result.get("ok",false)
	var unchanged: bool=preview_result.get("reason")=="unchanged"
	if not valid and not unchanged: _diamond(hover_cell.x,hover_cell.y,1,1,Color(0.94,0.4,0.3,0.2),3,Color("ffab8f"))
	_draw_preview_label(("Click · " if valid else "")+str(preview_result.get("message","")),valid or unchanged)

func _window_face(x: int,y: int,along: bool,u: float,z: float) -> Vector2:
	return (grid_point(x+u,y+1.015) if along else grid_point(x+1.015,y+u))+Vector2(0,-z)

func _window_quad(x: int,y: int,along: bool,left: float,right: float,bottom: float,top: float) -> Array:
	return [_window_face(x,y,along,left,bottom),_window_face(x,y,along,right,bottom),_window_face(x,y,along,right,top),_window_face(x,y,along,left,top)]

func _draw_window(lot: Dictionary,x: int,y: int,height: float,style: String,s: float,previewing: bool=false) -> void:
	var along := Windows.along_x(lot,x,y)
	var definition: Dictionary=Windows.STYLES[style]
	var frame := Color(definition.frame).lerp(Color("e5bc88"),float(light.night)*0.22)
	var glass := Color(definition.glass).lerp(Color("efd19b"),float(light.night)*0.70)
	if not along: frame=frame.darkened(0.10); glass=glass.darkened(0.08)
	var cutaway := height<20*s
	var bottom := 11*s if not cutaway else 2*s
	var top := 33*s if not cutaway else 7*s
	var left := 0.12 if style!="shutters" else 0.25
	var right := 0.88 if style!="shutters" else 0.75
	var outline := Color("d8f1b2") if previewing else Color("4c6565")
	var polygon := _window_quad(x,y,along,left-0.04,right+0.04,bottom-2*s,top+2*s)
	window_regions[Windows.key(x,y)]={"polygon":PackedVector2Array(polygon),"cutaway":cutaway,"style":style,"preview":previewing,"along_x":along}
	_poly(polygon,frame,outline if previewing else frame.darkened(0.27))
	_poly(_window_quad(x,y,along,left,right,bottom,top),glass,glass.darkened(0.25))
	if not cutaway:
		# A pale upper reflection and a quiet diagonal make the panes read as glass.
		_poly(_window_quad(x,y,along,left+0.02,right-0.02,top-6*s,top-1*s),glass.lightened(0.12))
		draw_line(_window_face(x,y,along,left+0.08,bottom+3*s),_window_face(x,y,along,left+0.26,top-2*s),Color(0.94,0.98,0.91,0.48),maxf(1,1.4*s),true)
		if style=="cottage":
			draw_line(_window_face(x,y,along,0.5,bottom),_window_face(x,y,along,0.5,top),frame,2*s,true)
			draw_line(_window_face(x,y,along,left,(top+bottom)*0.5),_window_face(x,y,along,right,(top+bottom)*0.5),frame,2*s,true)
		if style=="shutters":
			for limits: Array in [[0.04,0.20],[0.80,0.96]]:
				_poly(_window_quad(x,y,along,limits[0],limits[1],bottom,top),Color("72917b").lerp(Color("758773"),float(light.night)),Color("526f61"))
				for z in [15,20,25,30]: draw_line(_window_face(x,y,along,limits[0]+0.02,z*s),_window_face(x,y,along,limits[1]-0.02,z*s),Color("97b098"),maxf(0.7,s),true)
	# The sill stays readable when near walls are cut down during normal play.
	draw_line(_window_face(x,y,along,left-0.06,bottom-2*s),_window_face(x,y,along,right+0.06,bottom-2*s),frame.lightened(0.12),2*s,true)

func _draw_furniture_color() -> void:
	if color_preview.is_empty(): return
	if color_preview.has("object_id"):
		var size := Catalog.footprint(str(color_preview.kind),int(color_preview.rotation))
		_diamond(int(color_preview.x),int(color_preview.y),size.x,size.y,Color.TRANSPARENT,2,Color("b9de99"))
	if not _in_bounds(hover_cell) and color_request.is_empty(): return
	_draw_preview_label("Applying color…" if not color_request.is_empty() else str(color_preview.message),bool(color_preview.ok) or color_preview.get("reason")=="unchanged")

func _draw_impact_ground() -> void:
	for cell: Vector2i in placement_impact.get("lost_floor",[]):
		_diamond(cell.x,cell.y,1,1,Color(0.93,0.66,0.32,0.27),2,Color(0.94,0.73,0.41,0.55))

func _draw_impact_badges() -> void:
	if not placement_impact.get("warning",false): return
	var issues: Array=placement_impact.introduced if not placement_impact.introduced.is_empty() else placement_impact.after.issues
	var occupied: Array[Rect2]=overlay_rects.duplicate()
	var bounds := Rect2(Vector2(8,8),size-Vector2(16,16))
	var s := _cell.x/48.0
	for index in range(mini(6,issues.size())):
		var issue: Dictionary=issues[index]
		_diamond(issue.cell.x,issue.cell.y,issue.footprint.x,issue.footprint.y,Color(0.93,0.66,0.32,0.18),4,Color("efc77d"))
		var point := grid_point(issue.center.x,issue.center.y)+Vector2(0,-43*s)
		var rect := ResidentCues.fit(Rect2(point-Vector2(12,12),Vector2(24,24)),bounds,occupied)
		if not rect.has_area(): continue
		occupied.append(rect); impact_markers[str(issue.key)]=rect
		draw_line(grid_point(issue.center.x,issue.center.y)+Vector2(0,-12*s),rect.get_center(),Color("efc77d"),1.5,true)
		draw_style_box(preload("res://game/style.gd").box(Color("efc77d"),4,Color("ffe9b5")),rect)
		draw_string(_font,rect.get_center()+Vector2(-2,5),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("503a27"))


func _draw_art_preview() -> void:
	if art_pending: _draw_preview_label("Arranging artwork…",true); return
	if not _in_bounds(hover_cell): return
	var message := str(art_preview.get("message","Choose a finished painting."))
	if art_preview.get("ok",false):
		message+="\n"+Paintings.credit(art_preview.picture)
		if art_source.begins_with("easel:"): message+="\nThe easel gets a fresh canvas · Undo restores both"
	else: _diamond(hover_cell.x,hover_cell.y,1,1,Color(0.94,0.4,0.3,0.18),3,Color("ffab8f"))
	_draw_preview_label(message,bool(art_preview.get("ok",false)))

func _draw_wall_art(lot: Dictionary,x: int,y: int,picture: Dictionary,s: float,id: String,previewing: bool=false) -> void:
	var along := Windows.along_x(lot,x,y)
	var left := _window_face(x,y,along,0.14,33*s)
	var right := _window_face(x,y,along,0.86,33*s)
	var down := Vector2(0,21*s)
	var frame := _window_quad(x,y,along,0.09,0.91,10*s,35*s)
	_poly(frame,Color("967450"),Color("d8f1b2") if previewing else Color("6f5947"))
	draw_set_transform_matrix(Transform2D(right-left,down,left))
	preload("res://game/painting_art.gd").draw(self,picture)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if previewing: return
	art_regions[id]={"polygon":PackedVector2Array(frame),"x":x,"y":y,"along_x":along}
	var target := {"type":"wall_art","id":id,"x":x,"y":y}
	if building and build_kind!="wall_art": target={"type":"wall","x":x,"y":y}
	_hit_regions.append({"polygon":PackedVector2Array(frame),"target":target})
