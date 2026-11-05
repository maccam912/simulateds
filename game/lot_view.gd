extends Control
## 3D neighborhood presentation with isometric camera and screen-space feedback.
## All world mutations still travel through the authoritative command interface.
signal tile_clicked(cell: Vector2i)
signal area_selected(first: Vector2i, last: Vector2i)
signal hovered(cell: Vector2i)
signal rotation_changed(value: int)
signal catalog_dropped(kind: String, cell: Vector2i)
signal entity_clicked(target: Dictionary)
signal context_requested(target: Dictionary, position: Vector2)

const Catalog = preload("res://game/catalog.gd")
const Meals = preload("res://game/meals.gd")
const MealArt = preload("res://game/meal_art.gd")
const WallArt = preload("res://game/wall_art.gd")
const Paintings = preload("res://game/paintings.gd")
const Gardens = preload("res://game/gardens.gd")
const Landscaping = preload("res://game/landscaping.gd")
const BuildArea = preload("res://game/build_area.gd")
const ClearLot = preload("res://game/clear_lot.gd")
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
const Projection3D = preload("res://game/lot_projection.gd")
var projection = Projection3D.new()
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
var brush_size := 1
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
var _furniture_gesture: Dictionary={}
var _area_context: Array = []
var _area_origin := Vector2.ZERO
var _area_first := Vector2i(-1,-1)
var _area_finger := -1
var _area_moved := false
var _area_plan: Dictionary = {}
var _brush_stroke: Array=[]
var area_pending := false
var _cell := Vector2(48, 24)
var _origin := Vector2.ZERO
var _font: Font
var _time := 0.0
var _hit_regions: Array = []
var _drawing_target: Dictionary = {}
var _art_object: Dictionary = {}
var hover_target: Dictionary = {}
var _pointer := Vector2(-10000,-10000)
const CONTEXT_HOLD_SECONDS := 0.5
const CONTEXT_DRAG_DISTANCE := 14.0
var _touch_index := -1
var _touch_origin := Vector2.ZERO
var _touch_elapsed := 0.0
var _touch_cancelled := false
var _touch_fired := false
var _touch_lot := ""
var _touch_building := false
var _touch_target: Dictionary={}
var _touch_generation := -1
var _touch_profile := ""
var _touch_role := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	_layout()
	projection.setup(self)
	mouse_exited.connect(func(): hover_cell = Vector2i(-1, -1); hover_target = {}; _pointer = Vector2(-10000,-10000); queue_redraw())

func _process(delta: float) -> void:
	if not _area_context.is_empty() and _area_context!=_area_identity(): _area_context.clear()
	_update_context_touch(delta)
	var simulation_delta := delta*Session.effective_speed()
	_time+=simulation_delta
	motion.update(world,lot_id,simulation_delta,bool(Preferences.values.get("reduced_motion",false)),0.42 if Session.role=="client" else 0.22)
	_update_activity_audio(delta)
	_layout()
	light=Daylight.sample(float(world.get("day_minutes",480)))
	projection.sync(simulation_delta)
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
				residents.append({"id":str(member.id),"cell":cell,"position":get_global_transform_with_canvas()*point,"kind":sound_kind,"task":str(task.get("id","")),"elapsed":float(task.get("elapsed",0.0)),"walking":motion.moving(str(member.id)) or not task.get("path",[]).is_empty(),"indoors":[roundi(cell.x),roundi(cell.y)] in lot.floors,"voice":member.get("character",{})})
				sources[str(member.id)]={"position":get_global_transform_with_canvas()*point,"task":str(task.get("id",""))}
	Soundscape.update_world_sources(sources)
	for event: Dictionary in activity_audio.sample(key,residents,delta,active): Soundscape.play_world(event)

func _exit_tree() -> void:
	Soundscape.stop_world()

func _layout() -> void:
	# The camera frames the house, not a panel. Ground continues behind the HUD.
	var play_height: float = maxf(360.0, size.y - 160.0)
	_cell = _cell_size()
	var focus := Vector2(size.x * 0.5, play_height * 0.53)
	_origin = focus - Vector2(_cell.x * 0.25, _cell.y * 7.75) + pan
	projection.update_camera()

func _cell_size() -> Vector2:
	var play_height := maxf(360.0,size.y-160.0)
	return Vector2(48,24)*minf(size.x/1000.0,play_height/510.0)*zoom

func stop_camera_motion() -> void:
	if _camera_tween!=null:
		_camera_tween.kill(); _camera_tween=null

func center_lot() -> void:
	stop_camera_motion()
	zoom=1.0; pan=Vector2.ZERO
	_layout(); queue_redraw()

func saved_framing() -> Dictionary:
	var cell := _cell_size()
	var offset := pan/cell if cell.x>0.0 else Vector2.ZERO
	return {"zoom":zoom,"pan_x":offset.x,"pan_y":offset.y}

func restore_framing(view: Dictionary) -> void:
	stop_camera_motion()
	motion.tracks.clear()
	zoom=float(view.get("zoom",1.0))
	_layout()
	pan=Vector2(float(view.get("pan_x",0.0)),float(view.get("pan_y",0.0)))*_cell
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
	if projection.camera!=null:
		var ground: Vector2=projection.ground_at(point)
		return Vector2i(floori(ground.x),floori(ground.y))
	var v := point - _origin
	return Vector2i(floori(v.x / _cell.x + v.y / _cell.y), floori(v.y / _cell.y - v.x / _cell.x))

func _input(event: InputEvent) -> void:
	if not _furniture_gesture.is_empty() and _furniture_input(event): return
	# An overlay can receive the release even when the drag began on the lawn.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		_dragging = false
	if not _area_context.is_empty() and _area_input(event): return
	if _touch_index<0: return
	if event is InputEventKey and event.pressed:
		_touch_cancelled=true
	elif event is InputEventScreenTouch:
		if event.index!=_touch_index:
			# A second finger is never a second command or a context hold.
			_touch_cancelled=true
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			var local := make_input_local(event) as InputEventScreenTouch
			var activate: bool=not event.canceled and not _touch_cancelled and not _touch_fired and _touch_origin.distance_to(local.position)<=CONTEXT_DRAG_DISTANCE and _touch_context_unchanged() and _point_available(local.position)
			_touch_index=-1
			if activate: _primary_click(local.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==_touch_index:
		var local := make_input_local(event) as InputEventScreenDrag
		if _touch_origin.distance_to(local.position)>CONTEXT_DRAG_DISTANCE: _touch_cancelled=true
		# Dragging pans, while a completed hold owns the remainder of its gesture.
		if _touch_cancelled and not _touch_fired and _touch_context_unchanged() and _point_available(local.position):
			stop_camera_motion(); pan+=local.relative
		get_viewport().set_input_as_handled()

func _area_identity() -> Array:
	var revision: int = world.get("lots",{}).get(lot_id,{}).get("revision",-1)
	return [Session.world_generation,Session.profile_id,Session.role,lot_id,revision,building,build_kind,finish_selection,finish_choice,build_rotation,access_inspecting,area_pending]

func _area_cell(point: Vector2) -> Vector2i:
	if build_kind=="finish_wall":
		var target := hit_target(point)
		if target.get("type") in ["wall","wall_art"]: return Vector2i(int(target.x),int(target.y))
	return cell_at(point)

func _start_area(point: Vector2, finger: int = -1) -> bool:
	if not building or access_inspecting or _dragging or not _point_available(point): return false
	if build_kind not in Landscaping.TOOLS and build_kind not in ["floor","wall","erase","room","finish_floor","finish_wall"]: return false
	if build_kind=="finish_floor" and finish_selection=="room": return false
	var cell := _area_cell(point)
	if not _in_bounds(cell): return false
	stop_camera_motion()
	_area_context=_area_identity()
	_area_first=cell
	_brush_stroke=[[cell.x,cell.y]]
	_area_origin=point
	_area_finger=finger
	_area_moved=false
	_pointer=point
	hover_cell=cell
	return true

func _area_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		_area_context.clear()
		get_viewport().set_input_as_handled()
		return true
	var release := false
	var point: Vector2
	if _area_finger>=0:
		if event is InputEventScreenTouch:
			if event.index!=_area_finger or event.canceled:
				_area_context.clear()
				get_viewport().set_input_as_handled()
				return true
			if event.pressed: return false
			release=true
		elif not event is InputEventScreenDrag or event.index!=_area_finger: return false
	else:
		if event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION:
			if event.button_index!=MOUSE_BUTTON_LEFT:
				_area_context.clear()
				if event.button_index!=MOUSE_BUTTON_RIGHT: return false
				get_viewport().set_input_as_handled()
				return true
			if event.pressed: return false
			release=true
		elif not event is InputEventMouseMotion: return false
	point=make_input_local(event).position
	var same_context := _area_context==_area_identity()
	var available := same_context and _point_available(point)
	var cell := _area_cell(point) if available else Vector2i(-1,-1)
	_pointer=point
	hover_cell=cell
	if build_kind.begins_with("terrain_") and _in_bounds(cell) and (_brush_stroke.is_empty() or _brush_stroke.back()!=[cell.x,cell.y]):
		if _brush_stroke.size()==256: _brush_stroke[-1]=[cell.x,cell.y]
		else: _brush_stroke.append([cell.x,cell.y])
	if point.distance_to(_area_origin)>4.0 and cell!=_area_first: _area_moved=true
	if release:
		_area_context.clear()
		if available:
			if _area_moved:
				if _in_bounds(cell) and (cell!=_area_first or build_kind.begins_with("terrain_")): area_selected.emit(_area_first,cell)
			else: _primary_click(point)
	elif not same_context: _area_context.clear()
	get_viewport().set_input_as_handled()
	return true

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: _area_context.clear()

func _touch_context_unchanged() -> bool:
	return _touch_lot==lot_id and _touch_building==building and _touch_generation==Session.world_generation and _touch_profile==Session.profile_id and _touch_role==Session.role

func _point_available(point: Vector2) -> bool:
	if not is_visible_in_tree() or not show_cues or mouse_filter==Control.MOUSE_FILTER_IGNORE or not Rect2(Vector2.ZERO,size).has_point(point): return false
	for rect: Rect2 in overlay_rects:
		if rect.has_point(point): return false
	return true

func _update_context_touch(delta: float) -> void:
	if _touch_index<0 or _touch_cancelled or _touch_fired: return
	if not _touch_context_unchanged() or not _point_available(_touch_origin):
		_touch_cancelled=true; return
	_touch_elapsed+=delta
	if not building and _touch_elapsed>=CONTEXT_HOLD_SECONDS:
		_touch_fired=true
		# The menu takes ownership of the release. Do not retain a finger whose
		# remaining events are now consumed by that overlay.
		_touch_index=-1
		if not _touch_target.is_empty(): _request_context(_touch_origin,_touch_target)

func _context_target(point: Vector2) -> Dictionary:
	var target := hit_target(point).duplicate(true)
	if target.get("type")=="care":
		# A care bubble belongs to its resident, not to a separate world object.
		target["type"]="member"
	if target.is_empty():
		var cell := cell_at(point)
		if not _in_bounds(cell): return {}
		target={"type":"ground","x":cell.x,"y":cell.y}
	return target

func _request_context(point: Vector2, original_target: Dictionary={}) -> void:
	if building or not _point_available(point): return
	stop_camera_motion()
	# Preserve the resident/object first touched even if it moves during a hold.
	# The menu resolves that identity again against the current snapshot.
	var target := original_target if not original_target.is_empty() else _context_target(point)
	if target.is_empty(): return
	context_requested.emit(target,point)

func _primary_click(point: Vector2, double_click: bool=false) -> void:
	if double_click and Time.get_ticks_msec()-_last_care_click<500 and not building: return
	var target := hit_target(point)
	var cell := cell_at(point)
	if building and access_inspecting:
		if target.get("type")=="access": entity_clicked.emit(target)
		return
	if building and build_kind in ["finish_wall","door","erase","window","wall_art"] and target.get("type") in ["wall","wall_art"]: cell=Vector2i(int(target.x),int(target.y))
	if building and build_kind=="wall_art" and art_source.is_empty() and target.get("type")=="wall_art":
		entity_clicked.emit(target)
	elif building and build_kind=="move" and build_object_id.is_empty() and target.get("type")=="object":
		entity_clicked.emit(target)
	elif building and build_kind=="furniture_color" and target.get("type")=="object": entity_clicked.emit(target)
	elif not building and not target.is_empty():
		if target.get("type")=="care": _last_care_click=Time.get_ticks_msec()
		entity_clicked.emit(target)
	elif building and build_kind=="erase" and target.get("type")=="object":
		tile_clicked.emit(Vector2i(int(target.x),int(target.y)))
	elif _in_bounds(cell): tile_clicked.emit(cell)

func _gui_input(event: InputEvent) -> void:
	_layout()
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index<0 and _point_available(event.position):
			if _start_area(event.position,event.index):
				accept_event()
				return
			_touch_index=event.index; _touch_origin=event.position; _touch_elapsed=0.0
			_touch_cancelled=false; _touch_fired=false; _touch_lot=lot_id; _touch_building=building
			_touch_target=_context_target(event.position)
			_touch_generation=Session.world_generation; _touch_profile=Session.profile_id; _touch_role=Session.role
		accept_event(); return
	if event is InputEventMouseButton:
		# Handle touch explicitly so emulated mouse-down cannot walk/use furniture
		# before the player has had time to hold for the radial menu.
		if event.device==InputEvent.DEVICE_ID_EMULATION:
			accept_event(); return
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
				if not _start_furniture(event.position,false) and not _start_area(event.position): _primary_click(event.position,event.double_click)
			elif event.button_index==MOUSE_BUTTON_RIGHT:
				if not _start_furniture(event.position,true): _request_context(event.position)
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
		if not region.get("geometry",false) and Geometry2D.is_point_in_polygon(point,region.polygon): return region.target
	return projection.hit(point)

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
	projection.feedback.diamond(x,y,w,d,color,outline,0.065+z*0.002,1.0/(_cell.x/sqrt(2.0)))

func _block(x: float, y: float, w: float, d: float, height: float, color: Color, z: float = 0) -> void:
	var pixels_per_height: float=_cell.x/sqrt(2.0)*cos(PI/6.0)
	projection.feedback.box(x,y,w,d,height/pixels_per_height,color,0.04+z/pixels_per_height)

func _draw() -> void:
	projection.feedback.begin()
	_hit_regions.clear()
	preview_label_rect=Rect2()
	leisure_report={}; leisure_markers.clear()
	resident_labels.clear()
	access_markers.clear()
	impact_markers.clear(); placement_impact={}
	_drawing_target = {}
	_layout()
	light=Daylight.sample(float(world.get("day_minutes",480)))
	if not world.has("lots") or not world.lots.has(lot_id):
		draw_string(_font, Vector2(40,80), "Preparing your neighborhood…", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("34514c"))
		projection.feedback.finish()
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
	var area_preview := _show_area_preview()
	if area_preview:
		_update_area_preview(lot)
		placement_impact=_area_plan.get("impact",{})
	elif building and not access_inspecting and _in_bounds(hover_cell):
		if build_kind=="room" and _room_start().x>=0 and not room_pending:
			_update_room_preview(lot); placement_impact=preview_result.get("impact",{})
		elif Catalog.ITEMS.has(build_kind) or (build_kind=="move" and not build_object_id.is_empty()):
			_update_preview(lot); placement_impact=preview_result.get("impact",{})
	_update_window_preview(lot)
	window_regions.clear(); art_regions.clear(); art_preview={}
	if building and build_kind=="wall_art" and not access_inspecting and not art_pending and _in_bounds(hover_cell):
		art_preview=WallArt.inspect(lot,{"type":"art_hang","source":art_source,"x":hover_cell.x,"y":hover_cell.y})
	# Models, floors, architecture, planting and lighting are rendered by the 3D viewport.
	projection.sync(0.0)
	_hit_regions.assign(projection.register_targets())
	if building:
		_diamond(0,0,16,16,Color.TRANSPARENT,0,Color(0.95,0.97,0.78,0.65))
		for y in range(16):
			for x in range(16): _diamond(x,y,1,1,Color.TRANSPARENT,0,Color(0.30,0.41,0.24,0.25))
	if building and build_kind=="finish_floor" and finish_selection=="room" and not access_inspecting: _draw_room_finish_ground()
	if building and access_visible: _draw_access_ground(lot)
	_draw_impact_ground()
	_draw_walk_ground(scale_factor)
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
	_draw_resident_overlays(entities,scale_factor)
	if building and access_visible and (placement_impact.is_empty() or access_inspecting): _draw_access_issues(scale_factor)
	hover_target = hit_target(_pointer)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (not building and not hover_target.is_empty()) or (building and access_inspecting and hover_target.get("type")=="access") else Control.CURSOR_ARROW
	if building and access_inspecting: pass
	elif area_preview: _draw_area_preview()
	elif building and build_kind=="clear_lot": _draw_clear_review(lot)
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
	projection.feedback.finish()

func _walk_line(cells: Array,start_cell: Vector2,color: Color) -> void:
	var previous := Vector3(start_cell.x,0.078,start_cell.y)
	for cell: Array in cells:
		var point := Vector3(float(cell[0])+0.5,0.078,float(cell[1])+0.5)
		projection.feedback.line(previous,point,color,2.0/(_cell.x/sqrt(2.0)))
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

func _room_start() -> Vector2i:
	return _area_first if _selecting_area() else room_anchor

func _selecting_area() -> bool:
	return not _area_context.is_empty() and _area_moved and _in_bounds(hover_cell) and _point_available(_pointer)

func _show_area_preview() -> bool:
	return (_selecting_area() and build_kind in ["floor","wall","erase"]) or (building and not access_inspecting and build_kind in Landscaping.TOOLS and _in_bounds(hover_cell))

func _update_area_preview(lot: Dictionary) -> void:
	var people := _build_residents()
	if build_kind in Landscaping.TOOLS:
		var first := _area_first if not _area_context.is_empty() else hover_cell
		_area_plan=Landscaping.inspect(lot,{"kind":build_kind,"x":first.x,"y":first.y,"end_x":hover_cell.x,"end_y":hover_cell.y,"radius":brush_size,"points":_brush_stroke if not _area_context.is_empty() and build_kind.begins_with("terrain_") else [[first.x,first.y],[hover_cell.x,hover_cell.y]]})
		return
	var command := {"type":"place_area","kind":build_kind,"x":_area_first.x,"y":_area_first.y,"end_x":hover_cell.x,"end_y":hover_cell.y}
	var signature := str(["area",Session.world.get_instance_id(),lot_id,lot.revision,lot.funds,command,people])
	if signature==_preview_signature: return
	_preview_signature=signature
	if build_kind=="erase":
		_area_plan=ClearLot.inspect(lot,BuildArea.bounds(command))
		return
	var residents: Array=[]
	for person: Dictionary in people: residents.append(Vector2i(person.x,person.y))
	_area_plan=BuildArea.inspect(lot,command,residents)
	_area_plan.impact=BuildImpact.inspect(lot,command,_area_plan,people)

func _draw_area_preview() -> void:
	if build_kind in Landscaping.TOOLS:
		var valid: bool=_area_plan.get("ok",false)
		var tone := Color("d8f1b2") if valid else Color("ffab8f")
		for cell: Array in _area_plan.get("cells",[]):
			_diamond(int(cell[0]),int(cell[1]),1,1,Color(tone,0.27),1,tone)
		_draw_preview_label(str(_area_plan.message),valid,tone)
		return
	var low := _area_first.min(hover_cell)
	var dimensions := (_area_first-hover_cell).abs()+Vector2i.ONE
	var valid: bool=_area_plan.ok and not area_pending
	var tone := Color("ffab8f") if build_kind=="erase" or not valid else Color("d8f1b2")
	if placement_impact.get("warning",false): tone=Color("efc77d")
	var message := str(_area_plan.message)
	projection.feedback.diamond(low.x,low.y,dimensions.x,dimensions.y,Color.TRANSPARENT if build_kind=="wall" else Color(tone,0.24),tone,0.075,0.065)
	if area_pending: message="Waiting for the previous edit…"
	elif build_kind=="erase":
		if not _area_plan.unfinished.is_empty(): message="An unfinished canvas is in the selection.\nFinish it or sell the easel individually."
		for object: Dictionary in _area_plan.objects:
			var footprint := Catalog.footprint(str(object.kind),int(object.rotation))
			_diamond(int(object.x),int(object.y),footprint.x,footprint.y,Color(tone,0.26),5,tone)
		if valid:
			var tiles: int=_area_plan.floors+_area_plan.walls+_area_plan.doors
			message="Release to clear · +§%d refund" % _area_plan.refund
			var notes := PackedStringArray(["Tiles %d · Windows %d · Furnishings %d" % [tiles,_area_plan.windows,_area_plan.furnishings]])
			var paintings: int=_area_plan.stored+_area_plan.paintings.size()
			if paintings>0: notes.append("Paintings stored %d" % paintings)
			if _area_plan.portions>0: notes.append("Meal portions discarded %d" % _area_plan.portions)
			if _area_plan.crops>0: notes.append("Planted beds removed %d" % _area_plan.crops)
			message+="\n"+"\n".join(notes)
	elif valid:
		message="Release to build · "+message
		if build_kind=="wall":
			for cell: Array in _area_plan.cells:
				_block(int(cell[0]),int(cell[1]),1,1,14*_cell.x/48.0,Color(tone,0.38))
		if not placement_impact.get("message","").is_empty(): message+="\n"+str(placement_impact.message)
		_draw_impact_badges()
	_draw_preview_label(message,valid,tone)

func _update_room_preview(lot: Dictionary) -> void:
	var anchor := _room_start()
	var people := _build_residents()
	var signature := str(["room",Session.world.get_instance_id(),lot_id,lot.revision,lot.funds,hover_cell,anchor,build_rotation,people])
	if signature==_preview_signature: return
	_preview_signature=signature
	var residents: Array=[]
	for member: Dictionary in people: residents.append(Vector2i(member.x,member.y))
	var command := {"type":"build_room","x":anchor.x,"y":anchor.y,"end_x":hover_cell.x,"end_y":hover_cell.y,"rotation":build_rotation}
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
			detail=Leisure.summary(report)+" · Click to choose recreation"
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
	if hover_target.type=="object":
		var family: Dictionary=world.families.get(Session.profile_id,{})
		var actor: Dictionary={}
		for resident: Dictionary in family.get("members",[]):
			if resident.id==selected_member: actor=resident; break
		# Keep live descriptive details, but give every primary click explicit intent.
		var descriptions := PackedStringArray()
		for line: String in detail.split("\n"):
			descriptions.append(line.split(" · Click")[0])
		detail="\n".join(descriptions)+"\n"+preload("res://game/context_actions.gd").primary_hint(str(hover_target.kind),actor,detail.contains("In use by"))
		detail+="\nRight-click / hold: review actions"
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

func resident_head(member: Dictionary) -> Vector2:
	var node: Node3D=projection.scene.resident_nodes.get(str(member.id))
	if node!=null:
		var head := node.find_child("Head",true,false) as Node3D
		if head!=null: return projection.project(projection.Scene3D.bounds(head).get_center())
		return projection.project(node.global_position+Vector3(0,1.6,0))
	return resident_anchor(member)+Vector2(0,-47)*_cell.x/48.0

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
		var head := resident_head(member)
		occupied.append(Rect2(head-Vector2(11,10)*s,Vector2(22,22)*s))
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
		var box := ResidentCues.fit(Rect2(at+Vector2(-13.5,-77)*s,Vector2(27,16)*s),bounds,occupied)
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
		var head := resident_head(member)
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


func _update_finish_preview(lot: Dictionary) -> void:
	_paint_cells.clear(); _preview_finish=""
	if not building or access_inspecting or not build_kind in ["finish_floor","finish_wall"]: return
	var plan: Dictionary={}
	if paint_pending: plan=paint_plan
	elif _in_bounds(hover_cell):
		var anchor := _finish_start()
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

func _finish_start() -> Vector2i:
	if finish_selection=="room": return hover_cell
	if _selecting_area(): return _area_first
	return hover_cell if paint_anchor.x<0 else paint_anchor

func _draw_finish_preview() -> void:
	if paint_pending:
		_draw_preview_label("Decorating…",true); return
	if not _in_bounds(hover_cell): return
	if finish_selection=="room":
		var valid := bool(preview_result.get("ok",false))
		var unchanged: bool=preview_result.get("reason")=="unchanged"
		_draw_preview_label(("Click to fill room · " if valid else "")+str(preview_result.get("message","")),valid or unchanged)
		return
	var anchor := _finish_start()
	var low := Vector2i(mini(anchor.x,hover_cell.x),mini(anchor.y,hover_cell.y))
	var high := Vector2i(maxi(anchor.x,hover_cell.x),maxi(anchor.y,hover_cell.y))
	var valid := bool(preview_result.get("ok",false))
	_diamond(low.x,low.y,high.x-low.x+1,high.y-low.y+1,Color.TRANSPARENT if valid else Color(0.94,0.36,0.3,0.22),3,Color("d8f1b2") if valid else Color("ffab8f"))
	var hint := "Release to apply · " if _selecting_area() else "Drag or click first corner · " if paint_anchor.x<0 else "Click to apply · "
	_draw_preview_label((hint if valid else "")+str(preview_result.get("message","")),valid)

func _draw_room_finish_ground() -> void:
	if not paint_pending and not _in_bounds(hover_cell): return
	var plan: Dictionary=paint_plan if paint_pending else preview_result
	var cells := {}
	for cell: Array in plan.get("area",[]): cells[Vector2i(int(cell[0]),int(cell[1]))]=true
	var valid: bool=plan.get("ok",false) or plan.get("reason")=="unchanged"
	var color := Color("d8f1b2") if valid else Color("ffab8f")
	for cell: Vector2i in cells:
		if not valid: _diamond(cell.x,cell.y,1,1,Color(0.94,0.36,0.3,0.16),2)
		for edge: Array in [[Vector2i.UP,Vector2i.ZERO,Vector2i.RIGHT],[Vector2i.RIGHT,Vector2i.RIGHT,Vector2i.ONE],[Vector2i.DOWN,Vector2i.ONE,Vector2i.DOWN],[Vector2i.LEFT,Vector2i.DOWN,Vector2i.ZERO]]:
			if cells.has(cell+edge[0]): continue
			var start: Vector2i=cell+edge[1]; var end: Vector2i=cell+edge[2]
			projection.feedback.line(Vector3(start.x,0.078,start.y),Vector3(end.x,0.078,end.y),color,1.8/(_cell.x/sqrt(2.0)))

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
	var anchor := _room_start()
	if anchor.x<0:
		_diamond(hover_cell.x,hover_cell.y,1,1,Color(0.85,0.94,0.65,0.2),3,Color("f8edb7"))
		_draw_preview_label("Room · Drag or click the first corner",true)
		return
	_update_room_preview(lot)
	var low := Vector2i(mini(anchor.x,hover_cell.x),mini(anchor.y,hover_cell.y))
	var high := Vector2i(maxi(anchor.x,hover_cell.x),maxi(anchor.y,hover_cell.y))
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
	_diamond(anchor.x,anchor.y,1,1,Color(1,0.94,0.65,0.25),4,Color("fff0ba"))
	_draw_impact_badges()
	var message := str(preview_result.get("message",""))
	if _selecting_area(): message=message.replace("Click to build","Release to build")
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
	var height: float=z/(_cell.x/sqrt(2.0)*cos(PI/6.0))
	return projection.project(Vector3(x+u,height,y+0.64) if along else Vector3(x+0.64,height,y+u))

func _window_quad(x: int,y: int,along: bool,left: float,right: float,bottom: float,top: float) -> Array:
	return [_window_face(x,y,along,left,bottom),_window_face(x,y,along,right,bottom),_window_face(x,y,along,right,top),_window_face(x,y,along,left,top)]

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

func _draw_clear_review(lot: Dictionary) -> void:
	if lot.objects.is_empty() and lot.floors.is_empty() and lot.walls.is_empty() and lot.doors.is_empty(): return
	var color:=Color("eda58e")
	_diamond(0,0,16,16,Color.TRANSPARENT,3,color)
	for object: Dictionary in lot.objects:
		var footprint:=Catalog.footprint(object.kind,int(object.rotation))
		_diamond(int(object.x),int(object.y),footprint.x,footprint.y,Color(color,0.1),2,color)

func _can_drop_data(at: Vector2,data: Variant) -> bool:
	if not data is Dictionary or not data.get("build_catalog_kind") is String: return false
	return building and _point_available(at) and _in_bounds(cell_at(at))

func _drop_data(at: Vector2,data: Variant) -> void:
	if _can_drop_data(at,data): catalog_dropped.emit(str(data.build_catalog_kind),cell_at(at))

func _start_furniture(at: Vector2,rotate: bool) -> bool:
	if not building or access_inspecting or area_pending: return false
	var target := hit_target(at)
	if rotate:
		if not (Catalog.ITEMS.has(build_kind) and build_kind not in ["floor","wall","door"]) and not (build_kind=="move" and not build_object_id.is_empty()): return false
	else:
		if build_kind!="move" or not build_object_id.is_empty() or target.get("type")!="object": return false
		entity_clicked.emit(target)
	_furniture_gesture={"origin":at,"rotation":build_rotation,"rotate":rotate,"moved":false,"cell":hover_cell,"lot":lot_id,"generation":Session.world_generation,"revision":world.lots[lot_id].revision}
	return true

func _furniture_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		_furniture_gesture.clear(); return false
	if not building or _furniture_gesture.lot!=lot_id or _furniture_gesture.generation!=Session.world_generation or _furniture_gesture.revision!=world.lots[lot_id].revision:
		_furniture_gesture.clear(); return false
	if event is InputEventMouseMotion:
		var local := make_input_local(event) as InputEventMouseMotion
		var delta: Vector2=local.position-_furniture_gesture.origin
		if delta.length()>5: _furniture_gesture.moved=true
		if _furniture_gesture.rotate:
			var next := posmod(int(_furniture_gesture.rotation)+roundi(delta.x/45.0),4)
			if next!=build_rotation: rotation_changed.emit(next)
			hover_cell=_furniture_gesture.cell
		else:
			_pointer=local.position; hover_cell=cell_at(local.position)
		get_viewport().set_input_as_handled(); return true
	if event is InputEventMouseButton and not event.pressed:
		var button := MOUSE_BUTTON_RIGHT if _furniture_gesture.rotate else MOUSE_BUTTON_LEFT
		if event.button_index!=button: return false
		var local := make_input_local(event) as InputEventMouseButton
		var place: bool=not _furniture_gesture.rotate and _furniture_gesture.moved and _point_available(local.position) and _in_bounds(cell_at(local.position))
		_furniture_gesture.clear()
		if place: tile_clicked.emit(cell_at(local.position))
		get_viewport().set_input_as_handled(); return true
	return false
