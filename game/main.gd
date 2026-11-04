extends Control

signal pause_requested
signal save_menu_requested

const Style = preload("res://game/style.gd")
const Catalog = preload("res://game/catalog.gd")
const LotView = preload("res://game/lot_view.gd")
var viewed_lot := ""
var selected_member := ""
var selected_tool := "floor"
var build_rotation := 0
var lot_view: Control
var clock_label: Label
var funds_label: Label
var neighborhood_title: Label
var lot_title: Label
var lot_subtitle: Label
var mode_button: Button
var visit_button: Button
var home_button: Button
var family_box: VBoxContainer
var lots_box: VBoxContainer
var tools_box: VBoxContainer
var context_box: VBoxContainer
var activity_label: Label
var needs_title: Label
var queue_label: Button
var plan_panel: PanelContainer
var plan_box: VBoxContainer
var plan_title: Label
var autonomy_button: Button
var _plan_signature := ""
var need_bars: Dictionary = {}
var need_values: Dictionary = {}
var connection_label: Label
var notice_label: Label
var help_label: Label
var connection_dialog: Window
var code_input: LineEdit
var name_input: LineEdit
var ticket_input: TextEdit
var room_label: Label
var _refresh_clock := 0.0
var _family_signature := ""
var _lots_signature := ""
var _tools_signature := ""
var _notice_time := 0.0
var _selected_object := ""
var _view_context := ""
var hud: Control
var neighborhood_panel: PanelContainer
var context_panel: PanelContainer
var notice_panel: PanelContainer
var palette_button: Button
var _last_build_mode := false
var undo_button: Button
var redo_button: Button
var _moving_object := ""
var _move_request: Dictionary = {}

func _ready() -> void:
	if "--native-smoke" in OS.get_cmdline_user_args():
		if Session.available():
			print("NATIVE_RUNTIME_PASS")
			get_tree().quit()
		else: get_tree().quit(1)
		return
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		return
	theme = Style.make_theme()
	_build_ui()
	Session.status_changed.connect(func(_message): _refresh())
	Session.action_result.connect(_notice)
	Rooms.changed.connect(_refresh)
	_refresh()

func _label(text: String, size_value: int = 15, color: Color = Style.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",color)
	return label

func _button(text: String, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	if accent:
		button.add_theme_stylebox_override("normal",Style.box(Style.GREEN,9))
		button.add_theme_color_override("font_color",Style.INK)
		button.add_theme_color_override("font_focus_color",Style.INK)
		button.add_theme_color_override("font_hover_color",Style.INK)
		button.add_theme_stylebox_override("hover",Style.box(Style.GREEN.lightened(0.08),4))
	Soundscape.attach_controls(button)
	return button

func _vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	parent.add_child(box)
	return box

func _margin(parent: Node, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,amount)
	parent.add_child(margin)
	return margin

func _rule(parent: Node) -> void:
	var line := HSeparator.new()
	var separator := StyleBoxLine.new()
	separator.color = Style.EDGE
	separator.thickness = 1
	line.add_theme_stylebox_override("separator",separator)
	parent.add_child(line)

func _hud_panel(rect: Rect2, anchors: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	hud.add_child(panel)
	panel.anchor_left = anchors.x
	panel.anchor_right = anchors.x
	panel.anchor_top = anchors.y
	panel.anchor_bottom = anchors.y
	panel.offset_left = rect.position.x
	panel.offset_top = rect.position.y
	panel.offset_right = rect.end.x
	panel.offset_bottom = rect.end.y
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The world owns the entire viewport. No HUD container determines its size.
	lot_view = LotView.new()
	lot_view.name = "WorldView"
	add_child(lot_view)
	lot_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lot_view.tile_clicked.connect(_tile_clicked)
	lot_view.entity_clicked.connect(_entity_clicked)
	hud = Control.new()
	hud.name = "HUD"
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var location := _hud_panel(Rect2(16,16,340,114))
	var location_box := _vbox(location,3)
	var location_row := HBoxContainer.new(); location_box.add_child(location_row)
	lot_title = _label("Clover Cottage",22)
	lot_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_row.add_child(lot_title)
	lot_subtitle = _label("Your household",12,Style.MUTED)
	location_box.add_child(lot_subtitle)
	var location_actions := HBoxContainer.new(); location_box.add_child(location_actions)
	location_actions.add_child(_button("Neighborhood",func(): _show_tray(neighborhood_panel,not neighborhood_panel.visible)))
	location_actions.add_child(_button("Center view",func(): lot_view.zoom=1.0; lot_view.pan=Vector2.ZERO))

	neighborhood_panel = _hud_panel(Rect2(16,146,260,330))
	neighborhood_panel.visible = false
	var neighborhood := _vbox(neighborhood_panel,8)
	var neighborhood_head := HBoxContainer.new(); neighborhood.add_child(neighborhood_head)
	neighborhood_title = _label("Linden Grove",18); neighborhood_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; neighborhood_head.add_child(neighborhood_title)
	neighborhood_head.add_child(_button("×",func(): neighborhood_panel.hide()))
	lots_box = _vbox(neighborhood,6)

	var clock_panel := _hud_panel(Rect2(-296,16,280,114),Vector2(1,0))
	var clock_box := _vbox(clock_panel,4)
	var clock_row := HBoxContainer.new(); clock_box.add_child(clock_row)
	clock_label = _label("DAY 01 · 08:00",14); clock_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; clock_row.add_child(clock_label)
	funds_label = _label("§ 12,000",20,Style.GOLD); clock_row.add_child(funds_label)
	var session_row := HBoxContainer.new(); clock_box.add_child(session_row)
	var together := _button("Play together",_open_connection); together.size_flags_horizontal=Control.SIZE_EXPAND_FILL; session_row.add_child(together)
	var save_button := _button("Save",_request_save_menu); session_row.add_child(save_button)
	var fullscreen_button := _button("☰",_request_pause); fullscreen_button.tooltip_text="Game menu · " + Preferences.action_label("pause"); session_row.add_child(fullscreen_button)
	connection_label = _label("Local neighborhood",11,Style.MUTED); clock_box.add_child(connection_label)

	# Compact control islands float over the world, rather than enclosing it.
	var family_panel := _hud_panel(Rect2(16,-164,200,148),Vector2(0,1))
	var family_column := _vbox(family_panel,7)
	family_column.add_child(_label("HOUSEHOLD",11,Style.MUTED))
	family_box = _vbox(family_column,5)

	var needs_panel := _hud_panel(Rect2(228,-164,600,148),Vector2(0,1))
	needs_panel.anchor_right = 1.0
	needs_panel.offset_right = -300
	var needs := _vbox(needs_panel,9)
	var needs_head := HBoxContainer.new(); needs.add_child(needs_head)
	needs_title = _label("Alex · Taking it easy",15); needs_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; needs_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; needs_head.add_child(needs_title)
	queue_label = _button("Plan",func(): _show_tray(plan_panel,not plan_panel.visible))
	queue_label.add_theme_font_size_override("font_size",12); needs_head.add_child(queue_label)
	plan_panel = _hud_panel(Rect2(16,-480,408,300),Vector2(0,1))
	plan_panel.hide()
	var plan := _vbox(plan_panel,8)
	var plan_head := HBoxContainer.new(); plan.add_child(plan_head)
	plan_title = _label("Your day",18); plan_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; plan_head.add_child(plan_title)
	plan_head.add_child(_button("×",func(): plan_panel.hide()))
	autonomy_button = _button("Autonomy: on",func(): _send({"type":"autonomy","member_id":selected_member,"enabled":not bool(_member().get("autonomy",true))}))
	autonomy_button.tooltip_text="When on, this resident tends their own needs between your orders. Your orders always take priority."
	plan.add_child(autonomy_button)
	var plan_scroll := ScrollContainer.new(); plan_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; plan_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; plan.add_child(plan_scroll)
	plan_box = _vbox(plan_scroll,5); plan_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var bars := HBoxContainer.new(); bars.add_theme_constant_override("separation",12); needs.add_child(bars)
	for need in ["hunger","energy","hygiene","bladder","fun","social","comfort"]:
		var column := _vbox(bars,4); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new(); column.add_child(row)
		var label := _label(str(need).capitalize(),11,Style.MUTED); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
		var value := _label("100",11); row.add_child(value); need_values[need]=value
		var bar := ProgressBar.new(); bar.show_percentage=false; bar.custom_minimum_size.y=10; column.add_child(bar); need_bars[need]=bar
	help_label = _label("Click to walk or use furniture · Scroll to zoom · Middle-drag to pan",11,Style.MUTED)
	needs.add_child(help_label)

	var actions_panel := _hud_panel(Rect2(-288,-164,272,148),Vector2(1,1))
	var actions := _vbox(actions_panel,7)
	var mode_row := HBoxContainer.new(); actions.add_child(mode_row)
	mode_button = _button("Build & furnish",_toggle_build,true); mode_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; mode_row.add_child(mode_button)
	palette_button = _button("Activities",func(): _show_tray(context_panel,not context_panel.visible)); mode_row.add_child(palette_button)
	var travel_row := HBoxContainer.new(); actions.add_child(travel_row)
	visit_button = _button("Visit lot",_visit); visit_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; travel_row.add_child(visit_button)
	home_button = _button("Go home",_go_home); home_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; travel_row.add_child(home_button)
	var cancel := _button("Cancel current actions",func(): _send({"type":"cancel","member_id":selected_member})); cancel.add_theme_font_size_override("font_size",12); actions.add_child(cancel)

	# Only the requested catalog/activity tray is visible; it never resizes the world.
	context_panel = _hud_panel(Rect2(-288,146,272,400),Vector2(1,0))
	context_panel.anchor_bottom = 1.0
	context_panel.offset_bottom = -180
	context_panel.visible = false
	var context := _vbox(context_panel,8)
	var context_head := HBoxContainer.new(); context.add_child(context_head)
	activity_label = _label("Activities",15); activity_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; context_head.add_child(activity_label)
	context_head.add_child(_button("×",func(): context_panel.hide()))
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; context.add_child(scroll)
	tools_box = _vbox(scroll,5); tools_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	context_box = _vbox(context,6)

	notice_panel = _hud_panel(Rect2(-340,-222,680,42),Vector2(0.5,1))
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.hide()
	notice_label = _label("",13,Style.TEXT)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.add_child(notice_label)

func _process(delta: float) -> void:
	if lot_view == null: return
	_refresh_clock += delta
	_notice_time = maxf(0,_notice_time-delta)
	if _refresh_clock>=0.2:
		_refresh_clock=0
		_refresh()

func _family() -> Dictionary:
	return Session.state.get("families",{}).get(Session.profile_id,{})

func _member() -> Dictionary:
	for member in _family().get("members",[]):
		if str(member.id)==selected_member: return member
	return {}

func _refresh() -> void:
	if lot_view == null: return
	var state: Dictionary = Session.state
	neighborhood_title.text=str(state.get("neighborhood_name","Linden Grove"))
	var family := _family()
	var view_context := str(Session.role) + ":" + str(family.get("home_lot",""))
	if view_context != _view_context and Session.role != "joining" and not family.is_empty():
		_view_context = view_context
		viewed_lot = str(family.home_lot)
		_selected_object = ""
		_moving_object = ""; _move_request.clear()
	if viewed_lot.is_empty() or not state.get("lots",{}).has(viewed_lot):
		viewed_lot = str(family.get("home_lot","lot_1"))
	if selected_member.is_empty() and not family.get("members",[]).is_empty():
		selected_member = str(family.members[0].id)
	var member := _member()
	if member.is_empty() and not family.get("members",[]).is_empty():
		selected_member=str(family.members[0].id); member=_member()
	var lot: Dictionary = state.get("lots",{}).get(viewed_lot,{})
	var mine := str(lot.get("owner",""))==str(Session.profile_id)
	var building := bool(lot.get("building",false))
	if not building:
		_moving_object=""; _move_request.clear()
	elif not _move_request.is_empty() and int(lot.revision)>int(_move_request.revision):
		for object: Dictionary in lot.objects:
			if object.id==_move_request.object_id and int(object.x)==int(_move_request.x) and int(object.y)==int(_move_request.y) and int(object.rotation)==int(_move_request.rotation):
				_moving_object=""; _move_request.clear(); break
	lot_view.world=state; lot_view.lot_id=viewed_lot; lot_view.selected_member=selected_member
	lot_view.build_object_id=_moving_object
	lot_view.building=building and mine; lot_view.build_kind=selected_tool; lot_view.build_rotation=build_rotation
	lot_title.text=str(lot.get("name","Linden Grove"))
	lot_subtitle.text="Your household" if mine else ("Under construction" if building else "Neighbor’s home")
	if str(lot.get("owner","")).is_empty():
		lot_subtitle.text="Available for a new household"
	funds_label.text="§ %s" % _money(int(state.get("lots",{}).get(family.get("home_lot",""),{}).get("funds",0)))
	mode_button.disabled=not mine or Session.role=="joining"
	mode_button.text="Finish building" if building else "Build & buy"
	visit_button.disabled=mine or building or member.is_empty() or str(lot.get("owner","")).is_empty()
	home_button.disabled=member.is_empty() or str(member.get("lot_id",""))==str(family.get("home_lot",""))
	var minutes := int(float(state.get("day_minutes",480)))
	var day := int(state.get("day",1))
	clock_label.text="DAY %02d  ·  %02d:%02d" % [day,int(minutes%1440/60),minutes%60]
	connection_label.text="%s · %s" % [str(Session.role).capitalize(),Rooms.code] if not Rooms.code.is_empty() else ("Local neighborhood" if Session.role=="offline" else str(Session.status).left(32))
	var lot_signature := viewed_lot+str(state.get("lots",{}).size())
	for row in state.get("lots",{}).values():
		lot_signature+=str(row.get("owner",""))+str(row.get("building",false))
	if lot_signature!=_lots_signature:
		_lots_signature=lot_signature
		_clear(lots_box)
		for id in state.get("lots",{}):
			var other: Dictionary=state.lots[id]
			var subtitle := "Your household" if str(other.owner)==str(Session.profile_id) else "Available lot" if str(other.owner).is_empty() else "Neighbor"
			if other.building: subtitle="Under construction"
			var b := _button(str(other.name)+"\n"+subtitle,func(): _select_lot(str(id)))
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size",13)
			if str(id)==viewed_lot:
				b.add_theme_stylebox_override("normal",Style.box(Color("3b514b"),9,Style.GREEN))
			lots_box.add_child(b)
	var family_signature := selected_member+str(family.get("name",""))+str(family.get("members",[]).size())
	if family_signature!=_family_signature:
		_family_signature=family_signature; _clear(family_box)
		for resident in family.get("members",[]):
			var b := _button(("●  " if str(resident.id)==selected_member else "○  ")+str(resident.name),func(): selected_member=str(resident.id); viewed_lot=str(resident.lot_id); _refresh())
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT; family_box.add_child(b)
	if not member.is_empty():
		needs_title.text=str(member.name)+"  /  "+str(member.get("action","Enjoying the day"))
		queue_label.text="Plan · %d" % (member.get("queue",[]).size() + (0 if member.get("task",{}).is_empty() else 1))
		_refresh_plan(member)
		for need in need_bars:
			var value := float(member.get("needs",{}).get(need,100))
			need_bars[need].value=value; need_values[need].text=str(int(value))
			var color := Style.GREEN if value>=60 else Style.GOLD if value>=30 else Color("df8d79")
			need_bars[need].add_theme_stylebox_override("fill",Style.box(color,4))
	var build_mode := building and mine
	if build_mode != _last_build_mode:
		_last_build_mode = build_mode
		_show_tray(context_panel,build_mode)
		if build_mode: plan_panel.hide()
		if hud.visible: Soundscape.set_context("build" if build_mode else "live")
	palette_button.text = "Catalog" if build_mode else "Activities"
	var tools_signature := str(building and mine)+selected_tool+_moving_object+str(_move_request.is_empty())+_selected_object+str(build_rotation)+viewed_lot+str(lot.get("revision",0))
	if tools_signature!=_tools_signature:
		_tools_signature=tools_signature
		_rebuild_context(building and mine,lot)
	help_label.text="Click to place · " + Preferences.action_label("rotate") + " rotates · Ctrl/Cmd+Z undoes" if building and mine else "Click an object to use it · Click the ground to walk · Scroll to zoom"
	if room_label!=null:
		room_label.text=Session.status+("\nRoom code: "+Rooms.code if not Rooms.code.is_empty() else "")
		if Session.role=="host": ticket_input.text=Session.ticket()
	notice_panel.visible = _notice_time > 0.0

func _refresh_plan(member: Dictionary) -> void:
	plan_title.text = str(member.name) + "’s day"
	autonomy_button.text = "Autonomy: " + ("on" if member.get("autonomy",true) else "off")
	var tasks: Array = []
	if not member.task.is_empty(): tasks.append(member.task)
	tasks.append_array(member.queue)
	var signature := selected_member + str(member.get("autonomy",true)) + str(member.task.get("id","")) + (str(member.action) if member.task.is_empty() else "")
	for task: Dictionary in tasks: signature += str(task.get("id",""))
	if signature == _plan_signature: return
	_plan_signature = signature
	_clear(plan_box)
	if tasks.is_empty():
		var empty := _label("A little free time. Choose an activity or click something in the house.",13,Style.MUTED)
		empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; empty.custom_minimum_size.x=270; plan_box.add_child(empty)
	for task: Dictionary in tasks:
		var row := HBoxContainer.new(); plan_box.add_child(row)
		var current: bool = task == member.task
		var title := _task_title(task,member)
		var waiting: bool = member.task.is_empty() and task == member.queue[0] and str(member.action).begins_with("Waiting")
		var label := _label(("NOW  " if current else "WAIT  " if waiting else "NEXT  ") + title + (" · auto" if task.get("automatic",false) else ""),13,Style.GREEN if current else Style.TEXT)
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; label.tooltip_text=title; row.add_child(label)
		var action_id := str(task.get("id",""))
		var cancel := _button("×",func(): _send({"type":"remove_action","member_id":str(member.id),"action_id":action_id}))
		cancel.tooltip_text="Cancel " + title; row.add_child(cancel)

func _task_title(task: Dictionary, member: Dictionary) -> String:
	if task.get("type") == "move": return "Walk to %d, %d" % [int(task.x),int(task.y)]
	if task.get("target_kind","") == "member":
		for family: Dictionary in Session.state.families.values():
			for other: Dictionary in family.members:
				if other.id == task.get("target_id"): return "Chat with " + str(other.name)
	for object: Dictionary in Session.state.lots[member.lot_id].objects:
		if object.id == task.get("target_id"): return str(Catalog.ITEMS[object.kind].name)
	return "Activity"

func _money(value: int) -> String:
	var text := str(value)
	var result := ""
	for i in range(text.length()):
		if i>0 and (text.length()-i)%3==0: result+=","
		result+=text[i]
	return result

func _save() -> bool:
	if not Session.is_authority():
		_notice("The host saves this shared neighborhood automatically.")
		return false
	elif Session.save_world():
		_notice("Neighborhood saved.")
		return true
	else:
		_notice("Could not save. " + Session.status)
		return false

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child); child.queue_free()

func _rebuild_context(building: bool, lot: Dictionary) -> void:
	_clear(tools_box); _clear(context_box)
	if building:
		activity_label.text="Build & buy"
		for heading in ["Structure","Everyday essentials","A little recreation"]:
			tools_box.add_child(_label(heading.to_upper(),10,Style.MUTED))
			var keys: Array=[]
			match heading:
				"Structure": keys=["floor","wall","door"]
				"Everyday essentials": keys=["bed","fridge","shower","toilet"]
				_: keys=["sofa","tv","bookshelf","plant","table"]
			for kind in keys:
				var item: Dictionary=Catalog.ITEMS.get(kind,{})
				var b:=_button("%s  %s   § %d" % ["•" if selected_tool==kind else "+",item.get("name",kind),int(item.get("cost",0))],func(): selected_tool=kind; _moving_object=""; _move_request.clear(); _refresh())
				b.alignment=HORIZONTAL_ALIGNMENT_LEFT
				b.add_theme_font_size_override("font_size",12)
				b.tooltip_text=str(item.get("description",""))
				if kind==selected_tool: b.add_theme_stylebox_override("normal",Style.box(Color("3b514b"),9,Style.GREEN))
				tools_box.add_child(b)
		var edit_row := HBoxContainer.new(); context_box.add_child(edit_row)
		var move_label := "Move" if _moving_object.is_empty() else "Cancel move"
		var move_button := _button(move_label,func():
			selected_tool="move"; _moving_object=""; _move_request.clear(); _refresh(),selected_tool=="move")
		move_button.disabled=not _move_request.is_empty()
		move_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; edit_row.add_child(move_button)
		move_button.tooltip_text="Choose existing furniture to rearrange at no cost."
		var sell_button := _button("Sell",func(): selected_tool="erase"; _moving_object=""; _move_request.clear(); _refresh(),selected_tool=="erase")
		sell_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; edit_row.add_child(sell_button)
		sell_button.tooltip_text="Demolish tiles or sell furniture for 60% of its price."
		var history_row := HBoxContainer.new(); context_box.add_child(history_row)
		undo_button = _button("Undo",func(): _build_history(false)); undo_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; history_row.add_child(undo_button)
		redo_button = _button("Redo",func(): _build_history(true)); redo_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; history_row.add_child(redo_button)
		undo_button.disabled=int(lot.get("build_undo",0))==0
		redo_button.disabled=int(lot.get("build_redo",0))==0
		undo_button.tooltip_text="Undo the last building edit, including its price. Ctrl/Cmd+Z"
		redo_button.tooltip_text="Redo a building edit. Ctrl/Cmd+Shift+Z or Ctrl+Y"
		var finish_row := HBoxContainer.new(); context_box.add_child(finish_row)
		var rotation_button := _button("Rotate %d°" % (build_rotation*90),_rotate)
		rotation_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; finish_row.add_child(rotation_button)
		rotation_button.tooltip_text="Rotate furnishing · " + Preferences.action_label("rotate")
		var discard_button := _button("Discard draft",func(): _send({"type":"build_cancel","lot_id":viewed_lot}))
		discard_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; finish_row.add_child(discard_button)
		discard_button.tooltip_text="Restore the whole house and budget from before construction."
		var selected: Dictionary=Catalog.ITEMS.get(selected_tool,{})
		var help := str(selected.get("description","Remove an object or tile. A partial refund returns to your household."))
		if selected_tool=="move": help="Click furniture, then a new spot. " + Preferences.action_label("rotate") + " rotates · Escape cancels."
		var description:=_label(help,12,Style.MUTED)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; description.custom_minimum_size.x=200; context_box.add_child(description)
	else:
		activity_label.text="Activities"
		var shown: Dictionary={}
		for obj in lot.get("objects",[]):
			if shown.has(obj.kind): continue
			shown[obj.kind]=true
			var item: Dictionary=Catalog.ITEMS.get(obj.kind,{})
			if str(item.get("need","")).is_empty(): continue
			var text: String={"bed":"Get some sleep","fridge":"Have a bite to eat","shower":"Take a shower","toilet":"Use the bathroom","sofa":"Put your feet up","tv":"Watch a little TV","bookshelf":"Read a good book","plant":"Enjoy the greenery","table":"Take a seat"}.get(str(obj.kind),str(item.get("name",obj.kind)))
			var b:=_button(text,func(): _interact(str(obj.id)))
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.add_theme_font_size_override("font_size",12); tools_box.add_child(b)
		context_box.add_child(_button("Chat with family",func(): _chat_with_family()))
		context_box.add_child(_button("Clear action queue",func(): _send({"type":"cancel","member_id":selected_member})))
		var hint:=_label("Select furniture in the world to use it.",12,Style.MUTED)
		hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.custom_minimum_size.x=200; context_box.add_child(hint)

func _select_lot(id: String) -> void:
	viewed_lot=id; _selected_object=""; neighborhood_panel.hide(); _refresh()

func _send(command: Dictionary) -> void:
	if command.get("type")=="move_object":
		_move_request=command.duplicate()
		_move_request.revision=Session.state.lots[viewed_lot].revision
	Session.command(command)
	if Session.is_authority() and Session.last_action_ok and command.get("type")=="place": Soundscape.play_ui("build")
	_refresh()

func _entity_clicked(target: Dictionary) -> void:
	if lot_view.building and selected_tool=="move" and target.get("type")=="object":
		_select_moving_object(str(target.id)); return
	if target.get("type") == "object":
		_selected_object=str(target.id)
		_interact(str(target.id))
	elif target.get("owner") == Session.profile_id:
		selected_member=str(target.id); _refresh()
	else:
		_send({"type":"interact","member_id":selected_member,"lot_id":viewed_lot,"target_id":str(target.id)})

func _select_moving_object(id: String) -> void:
	for object: Dictionary in Session.state.lots[viewed_lot].objects:
		if object.id==id:
			_moving_object=id; build_rotation=int(object.rotation); _refresh(); return

func _tile_clicked(cell: Vector2i) -> void:
	var lot: Dictionary=Session.state.get("lots",{}).get(viewed_lot,{})
	if lot.is_empty(): return
	if bool(lot.building) and str(lot.owner)==str(Session.profile_id):
		if selected_tool=="move":
			if not _move_request.is_empty(): return
			if _moving_object.is_empty():
				var object: Dictionary=Session.world._object_at(lot,cell)
				if not object.is_empty(): _select_moving_object(str(object.id))
				else: _notice("Choose a furnishing to move first.")
			else:
				_send({"type":"move_object","lot_id":viewed_lot,"object_id":_moving_object,"x":cell.x,"y":cell.y,"rotation":build_rotation})
			return
		_send({"type":"erase" if selected_tool=="erase" else "place","lot_id":viewed_lot,"kind":selected_tool,"x":cell.x,"y":cell.y,"rotation":build_rotation})
		return
	for family in Session.state.get("families",{}).values():
		for member in family.members:
			if str(member.lot_id)==viewed_lot and int(member.x)==cell.x and int(member.y)==cell.y and str(family.id)==str(Session.profile_id):
				selected_member=str(member.id); _refresh(); return
	for obj in lot.get("objects",[]):
		var dimensions: Array=Catalog.ITEMS.get(obj.kind,{}).get("size",[1,1])
		var w:=int(dimensions[0]); var h:=int(dimensions[1])
		if int(obj.get("rotation",0))%2==1:
			var swap:=w; w=h; h=swap
		if cell.x>=int(obj.x) and cell.x<int(obj.x)+w and cell.y>=int(obj.y) and cell.y<int(obj.y)+h:
			_selected_object=str(obj.id); _interact(str(obj.id)); return
	_send({"type":"move","member_id":selected_member,"lot_id":viewed_lot,"x":cell.x,"y":cell.y})

func _interact(object_id: String) -> void:
	_send({"type":"interact","member_id":selected_member,"lot_id":viewed_lot,"target_id":object_id})

func _chat_with_family() -> void:
	var member:=_member()
	for family in Session.state.get("families",{}).values():
		for other in family.members:
			if str(other.id)!=selected_member and other.lot_id==member.get("lot_id",""):
				_send({"type":"interact","member_id":selected_member,"lot_id":str(member.get("lot_id","")),"target_id":str(other.id)}); return
	_notice("Bring a friend over, or visit a neighbor to chat.")

func _toggle_build() -> void:
	var lot: Dictionary=Session.state.get("lots",{}).get(viewed_lot,{})
	_send({"type":"build_end" if lot.get("building",false) else "build_begin","lot_id":viewed_lot})

func _visit() -> void:
	_send({"type":"visit","member_id":selected_member,"lot_id":viewed_lot})

func _go_home() -> void:
	_send({"type":"go_home","member_id":selected_member})
	viewed_lot=str(_family().get("home_lot",viewed_lot))

func _build_history(redo: bool) -> void:
	var lot: Dictionary=Session.state.get("lots",{}).get(viewed_lot,{})
	_send({"type":"build_redo" if redo else "build_undo","lot_id":viewed_lot,"revision":lot.get("revision",-1)})

func _rotate() -> void:
	build_rotation=(build_rotation+1)%4; _refresh()

func _toggle_fullscreen() -> void:
	Preferences.set_value("fullscreen",not bool(Preferences.values.fullscreen))

func _request_pause() -> void:
	if pause_requested.get_connections().is_empty():
		_notice("Open the application scene for the game menu.")
	else: pause_requested.emit()

func _request_save_menu() -> void:
	if save_menu_requested.get_connections().is_empty(): _save()
	else: save_menu_requested.emit()

func _show_tray(panel: Control,show_panel: bool) -> void:
	panel.visible=show_panel
	if show_panel and not bool(Preferences.values.reduced_motion):
		panel.modulate.a=0
		create_tween().tween_property(panel,"modulate:a",1.0,0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else: panel.modulate.a=1

func _unhandled_key_input(event: InputEvent) -> void:
	if hud==null or not hud.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if lot_view.building and (event.ctrl_pressed or event.meta_pressed) and event.keycode in [KEY_Z,KEY_Y]:
			_build_history(event.shift_pressed or event.keycode==KEY_Y)
		elif event.is_action_pressed("pause") or event.keycode==KEY_ESCAPE:
			if not _moving_object.is_empty() and _move_request.is_empty():
				_moving_object=""; _refresh()
			elif neighborhood_panel.visible or context_panel.visible or plan_panel.visible:
				neighborhood_panel.hide(); context_panel.hide(); plan_panel.hide()
			else: _request_pause()
		elif event.is_action_pressed("rotate"): _rotate()
		elif event.is_action_pressed("neighborhood"): _show_tray(neighborhood_panel,not neighborhood_panel.visible)
		elif event.is_action_pressed("build"): _toggle_build()
		elif event.is_action_pressed("home"): _go_home()
		elif event.is_action_pressed("cancel"): _send({"type":"cancel","member_id":selected_member})
		else: return
		get_viewport().set_input_as_handled()

func _notice(message: String) -> void:
	if notice_label!=null:
		notice_label.text=message
		_notice_time=7.0
		notice_panel.show()
		if not Session.last_action_ok:
			_move_request.clear()
			Soundscape.play_ui("error")

func _open_connection() -> void:
	if connection_dialog!=null:
		connection_dialog.popup_centered(); return
	connection_dialog=Window.new()
	connection_dialog.title="Multiplayer"
	connection_dialog.size=Vector2i(580,510)
	connection_dialog.transient=true
	connection_dialog.exclusive=true
	connection_dialog.close_requested.connect(func(): connection_dialog.hide())
	add_child(connection_dialog)
	var outer:=_margin(connection_dialog,22); outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box:=_vbox(outer,12)
	box.add_child(_label("Share your neighborhood",24))
	var info:=_label("One host keeps the neighborhood running. Each player keeps their own family and lot, even after leaving.",14,Style.MUTED)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)
	name_input=LineEdit.new(); name_input.placeholder_text="Your household name"; name_input.text=Session.display_name; box.add_child(name_input)
	var host_row:=HBoxContainer.new(); box.add_child(host_row)
	host_row.add_child(_button("Host neighborhood",func(): Session.set_display_name(name_input.text); await Rooms.host(),true))
	host_row.add_child(_button("New room code",func(): await Rooms.refresh_code()))
	room_label=_label(Session.status,13,Style.GREEN); room_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(room_label)
	var join_row:=HBoxContainer.new(); box.add_child(join_row)
	code_input=LineEdit.new(); code_input.placeholder_text="Room code or full ticket"; code_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL; join_row.add_child(code_input)
	join_row.add_child(_button("Join",func(): Session.set_display_name(name_input.text); await Rooms.join(code_input.text),true))
	box.add_child(_label("HOST TICKET  /  An alternative to the room code",11,Style.MUTED))
	ticket_input=TextEdit.new(); ticket_input.editable=false; ticket_input.custom_minimum_size.y=65; ticket_input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY; box.add_child(ticket_input)
	var bottom:=HBoxContainer.new(); box.add_child(bottom)
	bottom.add_child(_button("Copy host ticket",func(): DisplayServer.clipboard_set(Session.ticket()); _notice("Host ticket copied.")))
	bottom.add_child(_button("Leave session",func(): Session.leave(); viewed_lot=""; selected_member=""; _refresh()))
	var note:=_label("Keep this device or a dedicated server running for friends to play at different times. Joining does not replace your private neighborhood.",12,Style.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(note)
	connection_dialog.popup_centered()
