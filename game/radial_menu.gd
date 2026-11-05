extends Control
## A presentation-only menu: selecting an entry emits intent for its owner.

signal action_selected(id: String)
signal closed

const Style = preload("res://game/style.gd")
const Icons = preload("res://game/ui_icons.gd")
const BUTTON_SIZE := Vector2(174,56)
const RADIUS := Vector2(218,164)
const EXTENT := Vector2(280,196)
const PAGE_SIZE := 4

var entry_buttons: Dictionary = {}
var cancel_button: Button
var title_label: Label
var subtitle_label: Label
var page := 0
var _entries: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _center := Vector2.ZERO
var _anchor := Vector2.ZERO
var _center_panel: PanelContainer
var _touch_index := -1
var _touch_button: Button
var _touch_start := Vector2.ZERO
var _touch_dragged := false
var _previous_focus: WeakRef
var _default_subtitle := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	theme=Style.make_theme()
	_center_panel=PanelContainer.new()
	var surface := Style.box(Color(0.075,0.12,0.14,0.97),12,Style.GOLD.darkened(0.3))
	surface.content_margin_left=12; surface.content_margin_right=12
	surface.content_margin_top=8; surface.content_margin_bottom=8
	_center_panel.add_theme_stylebox_override("panel",surface)
	add_child(_center_panel)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",4)
	_center_panel.add_child(column)
	title_label=Label.new(); title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size",15)
	title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text=true; column.add_child(title_label)
	subtitle_label=Label.new(); subtitle_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size",11)
	subtitle_label.add_theme_color_override("font_color",Style.MUTED)
	subtitle_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.custom_minimum_size=Vector2(0,32)
	subtitle_label.max_lines_visible=4
	subtitle_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(subtitle_label)
	cancel_button=_make_button("Cancel",dismiss)
	cancel_button.custom_minimum_size=Vector2(0,44)
	column.add_child(cancel_button)
	resized.connect(_place)
	hide()

func open_menu(title: String, subtitle: String, entries: Array[Dictionary], at: Vector2) -> void:
	if not visible:
		var focused := get_viewport().gui_get_focus_owner()
		_previous_focus=weakref(focused) if focused!=null else null
	title_label.text=title; title_label.tooltip_text=title
	_default_subtitle=subtitle; _show_hint(subtitle)
	_entries=entries.duplicate(true)
	_anchor=at-global_position
	page=0; _touch_index=-1; _touch_button=null
	show(); move_to_front()
	_rebuild()

func dismiss() -> void:
	if not visible: return
	hide(); _touch_index=-1; _touch_button=null
	if _previous_focus!=null:
		var previous = _previous_focus.get_ref()
		if is_instance_valid(previous) and previous is Control and previous.is_visible_in_tree(): previous.grab_focus()
	_previous_focus=null
	closed.emit()

func _make_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text=label
	Icons.action(button,label)
	button.add_theme_font_size_override("font_size",14)
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_disabled_color",Style.MUTED.darkened(0.15))
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state_name: String in ["normal","hover","pressed","disabled","focus"]:
		var color := Style.PANEL
		if state_name=="hover": color=Color("30484d")
		elif state_name=="pressed": color=Style.GREEN
		elif state_name=="disabled": color=Color("17272c")
		elif state_name=="focus": color=Color.TRANSPARENT
		var border := Style.GREEN if state_name in ["hover","focus"] else Style.EDGE
		var surface := Style.box(color,12,border)
		surface.content_margin_left=10; surface.content_margin_right=10
		surface.content_margin_top=6; surface.content_margin_bottom=6
		button.add_theme_stylebox_override(state_name,surface)
	button.pressed.connect(callback)
	Soundscape.attach_controls(button)
	return button

func _rebuild() -> void:
	for button: Button in _buttons:
		remove_child(button); button.queue_free()
	_buttons.clear(); entry_buttons.clear()
	var shown: Array[Dictionary]=[]
	if _entries.size()<=6:
		shown.assign(_entries)
	else:
		var start := page*PAGE_SIZE
		for index in range(start,mini(start+PAGE_SIZE,_entries.size())): shown.append(_entries[index])
		if page>0: shown.append({"id":"__previous","label":"‹ Back"})
		if start+PAGE_SIZE<_entries.size(): shown.append({"id":"__next","label":"More ›"})
	for entry: Dictionary in shown:
		var id := str(entry.id)
		var button := _make_button(str(entry.get("label",id)),func(): _activate(id))
		button.disabled=bool(entry.get("disabled",false))
		var icon_id := str(entry.get("icon",""))
		if not icon_id.is_empty(): Icons.apply(button,icon_id,str(entry.label))
		button.tooltip_text=str(entry.get("label",id))+"\n"+str(entry.get("tooltip",""))
		button.mouse_entered.connect(func(): _show_hint(button.tooltip_text))
		button.focus_entered.connect(func(): _show_hint(button.tooltip_text))
		button.mouse_exited.connect(func(): _show_hint(_default_subtitle))
		button.custom_minimum_size=BUTTON_SIZE; button.size=BUTTON_SIZE
		add_child(button); _buttons.append(button); entry_buttons[id]=button
	_place()
	var first := cancel_button
	for button: Button in _buttons:
		if not button.disabled: first=button; break
	first.grab_focus()

func _place() -> void:
	if _center_panel==null: return
	var available := size
	_center=Vector2(clampf(_anchor.x,EXTENT.x+12,maxf(EXTENT.x+12,available.x-EXTENT.x-12)),clampf(_anchor.y,EXTENT.y+12,maxf(EXTENT.y+12,available.y-EXTENT.y-12)))
	_center_panel.size=Vector2(176,maxf(136,_center_panel.get_combined_minimum_size().y))
	_center_panel.position=_center-_center_panel.size/2.0
	# Use all six compass positions even on a short page; choices remain familiar.
	var slots := [0,1,2,3,4,5]
	if _buttons.size()==2: slots=[1,5]
	elif _buttons.size()==3: slots=[0,2,4]
	elif _buttons.size()==4: slots=[1,2,4,5]
	for index in range(_buttons.size()):
		var angle := -PI/2.0+float(slots[index])*TAU/6.0
		_buttons[index].position=_center+Vector2(cos(angle),sin(angle))*RADIUS-BUTTON_SIZE/2.0
	queue_redraw()

func _show_hint(text: String) -> void:
	subtitle_label.text=text if not text.is_empty() else _default_subtitle
	subtitle_label.tooltip_text=subtitle_label.text
	call_deferred("_place")

func _draw() -> void:
	if not visible: return
	var points := PackedVector2Array()
	for step in range(65):
		var angle := float(step)*TAU/64.0
		points.append(_center+Vector2(cos(angle),sin(angle))*RADIUS)
	draw_polyline(points,Color(0.06,0.10,0.11,0.78),5.0,true)
	draw_polyline(points,Color(0.65,0.73,0.65,0.55),1.0,true)

func _activate(id: String) -> void:
	if not visible: return
	if id=="__previous": page-=1; _rebuild(); return
	if id=="__next": page+=1; _rebuild(); return
	if not entry_buttons.has(id) or entry_buttons[id].disabled: return
	# The owner can resolve its selected target before the close handler clears it.
	action_selected.emit(id)
	dismiss()

func _cycle_focus(direction: int) -> void:
	var available: Array[Button]=[]
	for button: Button in _buttons:
		if not button.disabled: available.append(button)
	available.append(cancel_button)
	var current := available.find(get_viewport().gui_get_focus_owner())
	available[posmod(current+direction,available.size())].grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey:
		if event.pressed and (event.keycode==KEY_F1 or event.is_action_pressed("console") or event.is_action_pressed("fullscreen")):
			dismiss(); return
		# Keep gameplay shortcuts out of the world while choosing an action.
		get_viewport().set_input_as_handled()
		if not event.pressed or event.echo: return
		if event.keycode==KEY_ESCAPE: dismiss()
		elif event.keycode in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			_cycle_focus(-1 if event.keycode in [KEY_LEFT,KEY_UP] or event.shift_pressed else 1)
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and is_ancestor_of(focused) and not focused.disabled: focused.pressed.emit()
	elif event is InputEventScreenTouch:
		# Handle touch directly. The finger that opened this menu has no recorded
		# press here, so releasing a long press can never choose an entry.
		get_viewport().set_input_as_handled()
		if event.pressed:
			if _touch_index!=-1: return
			_touch_index=event.index; _touch_start=event.position; _touch_button=null; _touch_dragged=false
			for button: Button in _buttons+[cancel_button]:
				if button.get_global_rect().has_point(event.position): _touch_button=button; break
		elif event.index==_touch_index:
			var button := _touch_button
			_touch_index=-1; _touch_button=null
			if event.canceled or _touch_dragged or event.position.distance_to(_touch_start)>18: return
			if is_instance_valid(button):
				if button.get_global_rect().has_point(event.position):
					if button.disabled: _show_hint(button.tooltip_text)
					else: button.pressed.emit()
			elif not _center_panel.get_global_rect().has_point(event.position): dismiss()
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if event.index==_touch_index and event.position.distance_to(_touch_start)>18: _touch_dragged=true
	elif event is InputEventMouseButton:
		# Godot marks touch-emulated mouse input with device -1. Direct touch
		# handling above avoids double selection and the opening release.
		if event.device==-1 or event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			if event.pressed: dismiss()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed: dismiss()
