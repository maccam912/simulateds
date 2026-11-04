extends Control

signal pause_requested
signal save_menu_requested
signal household_requested
signal mail_requested

const Style = preload("res://game/style.gd")
const Catalog = preload("res://game/catalog.gd")
const BuildCatalog = preload("res://game/build_catalog.gd")
const RoomPlan = preload("res://game/room_plan.gd")
const Wishes = preload("res://game/wishes.gd")
const Hobbies = preload("res://game/hobbies.gd")
const Friendships = preload("res://game/friendships.gd")
const Portrait = preload("res://game/resident_portrait.gd")
const HomeNews = preload("res://game/home_news.gd")
const Pastimes = preload("res://game/pastimes.gd")
const Appearance = preload("res://game/appearance.gd")
const Wellbeing = preload("res://game/wellbeing.gd")
const ActivityStatus = preload("res://game/activity_status.gd")
const Finishes = preload("res://game/finishes.gd")
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
var household_button: Button
var mail_button: Button
var lots_box: VBoxContainer
var tools_box: VBoxContainer
var catalog_filters: HBoxContainer
var catalog_category: OptionButton
var catalog_search: LineEdit
var catalog_buttons: Dictionary = {}
var catalog_detail: Label
var _catalog_category := "all"
var _catalog_query := ""
var context_box: VBoxContainer
var activity_label: Label
var needs_title: Label
var wishes_button: Button
var hobbies_button: Button
var hobby_buttons: Dictionary = {}
var _hobby_options: Dictionary = {}
var _hobby_seen: Dictionary = {}
var people_button: Button
var social_buttons: Dictionary = {}
var _social_focus := ""
var _friend_seen: Dictionary = {}
var _context_page := "activities"
var _wish_seen: Dictionary = {}
var queue_label: Button
var plan_panel: PanelContainer
var plan_box: VBoxContainer
var plan_scroll: ScrollContainer
var plan_controls: Dictionary = {}
var plan_titles: Dictionary = {}
var _plan_detail: Label
var _plan_progress: ProgressBar
var plan_title: Label
var autonomy_button: Button
var find_button: Button
var pastime_label: Label
var _plan_signature := ""
var need_bars: Dictionary = {}
var need_values: Dictionary = {}
var need_buttons: Dictionary = {}
var mood_button: Button
var care_buttons: Dictionary = {}
var care_values: Dictionary = {}
var _care_options: Dictionary = {}
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
var _room_anchor := Vector2i(-1,-1)
var _room_request: Dictionary = {}
var _paint_anchor := Vector2i(-1,-1)
var _paint_request: Dictionary = {}
var finish_choice := {"floor":"walnut","wall":"sage"}
var finish_buttons: Dictionary = {}

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
	lot_subtitle.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; lot_subtitle.clip_text=true
	location_box.add_child(lot_subtitle)
	var location_actions := HBoxContainer.new(); location_box.add_child(location_actions)
	location_actions.add_child(_button("Neighborhood",func(): _show_tray(neighborhood_panel,not neighborhood_panel.visible)))
	var center := _button("Center",func(): lot_view.center_lot()); center.tooltip_text="Center view · Reset pan and zoom"; location_actions.add_child(center)
	mail_button=_button("Mail",func(): mail_requested.emit()); location_actions.add_child(mail_button)

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
	var family_head := HBoxContainer.new(); family_column.add_child(family_head)
	var family_label := _label("HOUSEHOLD",11,Style.MUTED); family_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; family_head.add_child(family_label)
	household_button=_button("Edit",func(): household_requested.emit())
	household_button.add_theme_font_size_override("font_size",11)
	var edit_style := Style.box(Style.PANEL,3,Style.EDGE); edit_style.content_margin_top=2; edit_style.content_margin_bottom=2; edit_style.content_margin_left=8; edit_style.content_margin_right=8
	household_button.add_theme_stylebox_override("normal",edit_style)
	household_button.tooltip_text="Household names, appearance, and favorite pastimes"; family_head.add_child(household_button)
	family_box = _vbox(family_column,5)

	var needs_panel := _hud_panel(Rect2(228,-164,600,148),Vector2(0,1))
	needs_panel.anchor_right = 1.0
	needs_panel.offset_right = -300
	var needs := _vbox(needs_panel,9)
	var needs_head := HBoxContainer.new(); needs.add_child(needs_head)
	needs_title = _label("Alex · Taking it easy",15); needs_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; needs_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; needs_head.add_child(needs_title)
	wishes_button = _button("Wishes",_open_wishes); wishes_button.add_theme_font_size_override("font_size",12); needs_head.add_child(wishes_button)
	hobbies_button = _button("Hobbies",_open_hobbies); hobbies_button.add_theme_font_size_override("font_size",12); needs_head.add_child(hobbies_button)
	queue_label = _button("Plan",func(): _show_tray(plan_panel,not plan_panel.visible))
	queue_label.add_theme_font_size_override("font_size",12); needs_head.add_child(queue_label)
	plan_panel = _hud_panel(Rect2(16,-480,408,300),Vector2(0,1))
	plan_panel.hide()
	var plan := _vbox(plan_panel,8)
	var plan_head := HBoxContainer.new(); plan.add_child(plan_head)
	plan_title = _label("Your day",18); plan_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; plan_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; plan_head.add_child(plan_title)
	plan_head.add_child(_button("×",func(): plan_panel.hide()))
	autonomy_button = _button("Autonomy: on",func(): _send({"type":"autonomy","member_id":selected_member,"enabled":not bool(_member().get("autonomy",true))}))
	autonomy_button.tooltip_text="When on, this resident tends their own needs between your orders. Your orders always take priority."
	var plan_actions := HBoxContainer.new(); plan.add_child(plan_actions)
	autonomy_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; plan_actions.add_child(autonomy_button)
	find_button=_button("Find resident",_find_resident); plan_actions.add_child(find_button)
	pastime_label=_label("",13,Style.MUTED); plan.add_child(pastime_label)
	pastime_label.tooltip_text="Change this in Household. A favorite nudges free-time choices; urgent needs and your orders come first."
	plan_scroll = ScrollContainer.new(); plan_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; plan_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; plan.add_child(plan_scroll)
	plan_box = _vbox(plan_scroll,5); plan_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var bars := HBoxContainer.new(); bars.add_theme_constant_override("separation",12); needs.add_child(bars)
	for need: String in Wellbeing.ORDER:
		var button := _button("",func(): _care_need(need)); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.custom_minimum_size=Vector2(54,42); bars.add_child(button); need_buttons[need]=button
		for state_name: String in ["normal","disabled","hover","focus"]:
			var surface := Style.box(Color.TRANSPARENT if state_name in ["normal","disabled","focus"] else Style.PANEL,3,Style.GREEN if state_name in ["hover","focus"] else Color.TRANSPARENT)
			surface.content_margin_left=0; surface.content_margin_right=0; surface.content_margin_top=0; surface.content_margin_bottom=0
			button.add_theme_stylebox_override(state_name,surface)
		var column := _vbox(button,4); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); column.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new(); row.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(row)
		var label := _label(str(need).capitalize(),11,Style.MUTED); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
		var value := _label("100",11); value.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(value); need_values[need]=value
		var bar := ProgressBar.new(); bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; bar.show_percentage=false; bar.custom_minimum_size.y=10; column.add_child(bar); need_bars[need]=bar
	var wellbeing_row := HBoxContainer.new(); needs.add_child(wellbeing_row)
	mood_button=_button("Content · Care",func(): _context_page="care"; _refresh(); _show_tray(context_panel,true)); mood_button.add_theme_font_size_override("font_size",11); wellbeing_row.add_child(mood_button)
	mood_button.add_theme_color_override("font_pressed_color",Style.TEXT)
	for state_name: String in ["normal","hover","pressed","disabled"]:
		var surface := Style.box(Style.PANEL if state_name!="hover" else Style.EDGE,3,Style.EDGE); surface.content_margin_top=2; surface.content_margin_bottom=2; surface.content_margin_left=6; surface.content_margin_right=6
		mood_button.add_theme_stylebox_override(state_name,surface)
	help_label = _label("Click to walk or use furniture · Scroll to zoom · Middle-drag to pan",11,Style.MUTED)
	help_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; help_label.clip_text=true; help_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; wellbeing_row.add_child(help_label)

	var actions_panel := _hud_panel(Rect2(-288,-164,272,148),Vector2(1,1))
	var actions := _vbox(actions_panel,7)
	var mode_row := HBoxContainer.new(); actions.add_child(mode_row)
	mode_button = _button("Build & furnish",_toggle_build,true); mode_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; mode_row.add_child(mode_button)
	palette_button = _button("Activities",func():
		var was_activities := _context_page=="activities"
		_context_page="activities"; _refresh(); _show_tray(context_panel,not context_panel.visible if was_activities else true)); mode_row.add_child(palette_button)
	var travel_row := HBoxContainer.new(); actions.add_child(travel_row)
	visit_button = _button("Visit lot",_visit); visit_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; travel_row.add_child(visit_button)
	home_button = _button("Go home",_go_home); home_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; travel_row.add_child(home_button)
	var social_row := HBoxContainer.new(); actions.add_child(social_row)
	people_button=_button("People",_open_people); people_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; social_row.add_child(people_button)
	var cancel := _button("Cancel actions",func(): _send({"type":"cancel","member_id":selected_member})); cancel.add_theme_font_size_override("font_size",12); social_row.add_child(cancel)
	cancel.tooltip_text="Clear the selected resident’s current action and plan."

	# Only the requested catalog/activity tray is visible; it never resizes the world.
	context_panel = _hud_panel(Rect2(-288,146,272,400),Vector2(1,0))
	context_panel.anchor_bottom = 1.0
	context_panel.offset_bottom = -180
	context_panel.visible = false
	var context := _vbox(context_panel,8)
	var context_head := HBoxContainer.new(); context.add_child(context_head)
	activity_label = _label("Activities",15); activity_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; activity_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; context_head.add_child(activity_label)
	context_head.add_child(_button("×",func(): context_panel.hide()))
	catalog_filters=HBoxContainer.new(); catalog_filters.add_theme_constant_override("separation",6); context.add_child(catalog_filters)
	catalog_category=OptionButton.new(); catalog_category.custom_minimum_size.x=88; catalog_category.fit_to_longest_item=false; catalog_category.add_theme_font_size_override("font_size",12)
	for category: String in BuildCatalog.CATEGORIES: catalog_category.add_item(str(BuildCatalog.CATEGORIES[category]))
	catalog_category.item_selected.connect(func(index): _catalog_category=BuildCatalog.CATEGORIES.keys()[index]; _refresh(); call_deferred("_reset_catalog_scroll"))
	catalog_category.tooltip_text="Browse a room or building category"; _compact_control(catalog_category); catalog_filters.add_child(catalog_category)
	catalog_search=LineEdit.new(); catalog_search.placeholder_text="Search"; catalog_search.max_length=64; catalog_search.clear_button_enabled=true; catalog_search.expand_to_text_length=false; catalog_search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; catalog_search.add_theme_font_size_override("font_size",12)
	catalog_search.tooltip_text="Find by name or use in this category · Ctrl/Cmd+F\nEnter selects the first result · Escape clears search"
	_compact_control(catalog_search); catalog_filters.add_child(catalog_search)
	catalog_search.text_changed.connect(func(value): _catalog_query=value; _refresh(); call_deferred("_reset_catalog_scroll"))
	catalog_search.text_submitted.connect(func(_value):
		var matches := BuildCatalog.results(_catalog_category,_catalog_query)
		if not matches.is_empty(): _select_build_tool(matches[0]); catalog_search.release_focus())
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; context.add_child(scroll)
	tools_box = _vbox(scroll,5); tools_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	context_box = _vbox(context,6)

	notice_panel = _hud_panel(Rect2(-340,-222,680,42),Vector2(0.5,1))
	notice_panel.grow_vertical=Control.GROW_DIRECTION_BEGIN
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.hide()
	notice_label = _label("",13,Style.TEXT)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.add_child(notice_label)

func _process(delta: float) -> void:
	if lot_view == null: return
	lot_view.show_cues=hud.is_visible_in_tree()
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
		_moving_object = ""; _move_request.clear(); _wish_seen.clear(); _friend_seen.clear(); _hobby_seen.clear(); _room_anchor=Vector2i(-1,-1); _room_request.clear()
		_paint_anchor=Vector2i(-1,-1); _paint_request.clear()
	if viewed_lot.is_empty() or not state.get("lots",{}).has(viewed_lot):
		viewed_lot = str(family.get("home_lot","lot_1"))
	if selected_member.is_empty() and not family.get("members",[]).is_empty():
		selected_member = str(family.members[0].id)
	var member := _member()
	if member.is_empty() and not family.get("members",[]).is_empty():
		selected_member=str(family.members[0].id); member=_member()
	find_button.disabled=member.is_empty() or Session.role=="joining"
	find_button.tooltip_text="Center on the selected resident · "+Preferences.action_label("focus_resident")+" · Middle-drag to pan again"
	var lot: Dictionary = state.get("lots",{}).get(viewed_lot,{})
	household_button.disabled=family.is_empty() or Session.role=="joining"
	mail_button.disabled=family.is_empty() or Session.role=="joining"
	var unread := preload("res://game/mailbox.gd").unread(family.get("mailbox",{}))
	var news_pending := HomeNews.pending(family)
	mail_button.text="Mail · %d" % unread if unread>0 else "Mail · news" if news_pending else "Mail"
	mail_button.tooltip_text="Postcards and gifts"+(" · A return recap is waiting in Home news" if news_pending else " · Home news keeps your return recap")
	mail_button.add_theme_color_override("font_color",Style.GOLD if unread>0 or news_pending else Style.TEXT)
	var mine := str(lot.get("owner",""))==str(Session.profile_id)
	var building := bool(lot.get("building",false))
	if not building:
		_moving_object=""; _move_request.clear()
	elif not _move_request.is_empty() and int(lot.revision)>int(_move_request.revision):
		for object: Dictionary in lot.objects:
			if object.id==_move_request.object_id and int(object.x)==int(_move_request.x) and int(object.y)==int(_move_request.y) and int(object.rotation)==int(_move_request.rotation):
				_moving_object=""; _move_request.clear(); break
	if not building or not mine or selected_tool!="room":
		_room_anchor=Vector2i(-1,-1); _room_request.clear()
	elif not _room_request.is_empty() and int(lot.revision)>int(_room_request.revision) and RoomPlan.is_applied(lot,_room_request.plan):
		_room_anchor=Vector2i(-1,-1); _room_request.clear()
	lot_view.room_anchor=_room_anchor
	lot_view.room_pending=not _room_request.is_empty()
	if not building or not mine or _paint_surface().is_empty():
		_paint_anchor=Vector2i(-1,-1); _paint_request.clear()
	elif not _paint_request.is_empty() and int(lot.revision)>int(_paint_request.revision) and Finishes.is_applied(lot,_paint_request.plan):
		_paint_anchor=Vector2i(-1,-1); _paint_request.clear()
	lot_view.paint_anchor=_paint_anchor; lot_view.paint_pending=not _paint_request.is_empty()
	lot_view.paint_plan=_paint_request.get("plan",{})
	lot_view.finish_choice=str(finish_choice.get(_paint_surface(),""))
	lot_view.world=state; lot_view.lot_id=viewed_lot; lot_view.selected_member=selected_member
	lot_view.build_object_id=_moving_object
	lot_view.building=building and mine; lot_view.build_kind=selected_tool; lot_view.build_rotation=build_rotation
	lot_title.text=str(lot.get("name","Linden Grove"))
	lot_subtitle.text=str(state.get("families",{}).get(str(lot.get("owner","")),{}).get("name","Neighbor’s home"))
	if building: lot_subtitle.text="Under construction · "+lot_subtitle.text
	lot_subtitle.tooltip_text=lot_subtitle.text
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
	clock_label.tooltip_text=preload("res://game/daylight.gd").sample(minutes).phase+" · The neighborhood shares one clock."
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
	var family_signature := selected_member+str(family.get("name",""))+str(family.get("identity_revision",0))+str(family.get("members",[]).size())
	if family_signature!=_family_signature:
		_family_signature=family_signature; _clear(family_box)
		for resident in family.get("members",[]):
			var b := _button(("●  " if str(resident.id)==selected_member else "○  ")+str(resident.name),func(): _select_resident(str(resident.id)))
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.clip_text=true; b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; b.tooltip_text=str(resident.name)+" · Unwinds with: "+Pastimes.label(resident)+" · Click again to find this resident"; family_box.add_child(b)
	if not member.is_empty():
		needs_title.text=str(member.name)+"  /  "+str(member.get("action","Enjoying the day"))
		queue_label.text="Plan · %d" % (member.get("queue",[]).size() + (0 if member.get("task",{}).is_empty() else 1))
		_refresh_plan(member)
		wishes_button.text="Wishes · %d/3" % Wishes.completed(member.get("wishes",{}))
		_announce_wishes(family)
		_announce_friendships(family)
		_announce_hobbies(family)
		var mood := Wellbeing.mood(member.needs)
		mood_button.text=str(mood.label)+" · Care"
		mood_button.add_theme_color_override("font_color",_mood_color(str(mood.tone)))
		mood_button.tooltip_text="How "+str(member.name)+" feels · Open care suggestions"
		_care_options.clear()
		for need in need_bars:
			var value := float(member.get("needs",{}).get(need,100))
			need_bars[need].value=value; need_values[need].text=str(int(value))
			var color := Style.GREEN if value>=60 else Style.GOLD if value>=30 else Color("df8d79")
			need_bars[need].add_theme_stylebox_override("fill",Style.box(color,4))
			var option: Dictionary=Session.world.care_option(member,need)
			_care_options[need]=option
			need_buttons[need].tooltip_text=str(need).capitalize()+" · "+str(int(value))+"\n"+("Click: "+str(option.label)+"\n" if option.available else "")+str(option.detail)
			need_buttons[need].disabled=bool(state.lots[family.home_lot].building)
			if care_values.has(need) and is_instance_valid(care_values[need]): care_values[need].text=str(need).capitalize()+" · %d" % int(value)
	var build_mode := building and mine
	catalog_filters.visible=build_mode and _paint_surface().is_empty()
	wishes_button.disabled=build_mode or member.is_empty()
	hobbies_button.disabled=bool(state.lots.get(family.get("home_lot",""),{}).get("building",false)) or member.is_empty()
	people_button.disabled=build_mode or member.is_empty()
	mood_button.disabled=bool(state.lots.get(family.get("home_lot",""),{}).get("building",false)) or member.is_empty()
	if build_mode != _last_build_mode:
		_last_build_mode = build_mode
		_show_tray(context_panel,build_mode)
		if build_mode: plan_panel.hide()
		if hud.visible: Soundscape.set_context("build" if build_mode else "live")
	palette_button.text = "Catalog" if build_mode else "Activities"
	var tools_signature := str(building and mine)+selected_tool+_moving_object+str(_move_request.is_empty())+_selected_object+str(build_rotation)+viewed_lot+str(lot.get("revision",0))+_context_page+selected_member+str(_room_anchor)+str(_room_request.is_empty())
	if build_mode: tools_signature+=_catalog_category+":"+_catalog_query+":"+str(lot.get("funds",0))
	tools_signature+=str(_paint_anchor)+str(_paint_request.is_empty())+str(finish_choice)
	if _context_page=="wishes" and not build_mode:
		tools_signature+=str(member.get("wishes",{}))+str(day)+str(member.get("task",{}).get("id",""))+str(member.get("queue",[]))
	if _context_page=="people" and not build_mode:
		tools_signature+=str(state.get("friendships",{}))+str(day)+str(member.get("task",{}).get("id",""))+str(member.get("queue",[]))
		for household: Dictionary in state.families.values():
			tools_signature+=str(household.get("identity_revision",0))+str(household.online)+str(state.lots[household.home_lot].building)
			for resident: Dictionary in household.members: tools_signature+=str([resident.id,resident.lot_id,resident.task.get("id",""),resident.action])
	if _context_page=="hobbies" and not build_mode:
		_hobby_options.clear()
		if not member.is_empty():
			for hobby: String in Hobbies.ORDER: _hobby_options[hobby]=Session.world.hobby_option(member,hobby)
		tools_signature+=str(member.get("hobbies",{}))+str(day)+str(_hobby_options)
	if _context_page=="care" and not build_mode: tools_signature+=str(_care_options)+str(Wellbeing.mood(member.get("needs",{})))
	if tools_signature!=_tools_signature:
		_tools_signature=tools_signature
		_rebuild_context(building and mine,lot)
	help_label.text="Click to place · " + Preferences.action_label("rotate") + " rotates · Ctrl/Cmd+Z undoes" if building and mine else "Click a need to care for it · Click the ground to walk"
	if building and mine and selected_tool=="room": help_label.text="Click two opposite corners · " + Preferences.action_label("rotate") + " changes door side · Escape cancels"
	if building and mine and not _paint_surface().is_empty(): help_label.text="Click two corners to decorate · Same tile twice for one · Escape cancels"
	help_label.tooltip_text=help_label.text
	if room_label!=null:
		room_label.text=Session.status+("\nRoom code: "+Rooms.code if not Rooms.code.is_empty() else "")
		if Session.role=="host": ticket_input.text=Session.ticket()
	_layout_notice()
	notice_panel.visible = _notice_time > 0.0

func _layout_notice() -> void:
	if notice_panel==null: return
	var left := -minf(340.0,size.x*0.5-16.0)
	if plan_panel.visible: left=maxf(left,plan_panel.get_rect().end.x+16.0-size.x*0.5)
	notice_panel.offset_left=left
	notice_panel.offset_right=minf(340.0,size.x*0.5-16.0)
	notice_panel.offset_top=-222.0; notice_panel.offset_bottom=-180.0

func _refresh_plan(member: Dictionary) -> void:
	plan_title.text = str(member.name) + "’s day"
	pastime_label.text="Unwinds with: "+Pastimes.label(member)
	autonomy_button.text = "Autonomy: " + ("on" if member.get("autonomy",true) else "off")
	var tasks: Array = []
	if not member.task.is_empty(): tasks.append(member.task)
	tasks.append_array(member.queue)
	var signature := selected_member + Pastimes.of(member) + str(member.get("autonomy",true)) + str(member.task.get("id","")) + (str(member.action) if member.task.is_empty() else "")
	for task: Dictionary in tasks: signature += str(task.get("id",""))
	if signature == _plan_signature:
		_update_plan_feedback(member); return
	_plan_signature = signature
	var focus_action := ""; var focus_control := ""
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null and plan_box.is_ancestor_of(focused):
		focus_action=str(focused.get_meta("plan_action","")); focus_control=str(focused.get_meta("plan_control",""))
	var scroll_position := plan_scroll.scroll_vertical
	_clear(plan_box)
	plan_controls.clear()
	plan_titles.clear(); _plan_detail=null; _plan_progress=null
	if tasks.is_empty():
		var empty := _label(str(ActivityStatus.sample(member,Session.state.lots[member.lot_id]).detail),13,Style.MUTED)
		empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; empty.custom_minimum_size.x=270; plan_box.add_child(empty)
	for task: Dictionary in tasks:
		var row := HBoxContainer.new(); plan_box.add_child(row)
		var current: bool = task == member.task
		var title := _task_title(task,member)
		var waiting: bool = member.task.is_empty() and task == member.queue[0] and str(member.action).begins_with("Waiting")
		var favorite: bool=bool(task.get("automatic",false)) and Pastimes.matches(member,Session.world.task_activity(task,str(member.lot_id)))
		var suffix := " · auto · favorite" if favorite else " · auto" if task.get("automatic",false) else ""
		var label := _label(("NOW  " if current else "WAIT  " if waiting else "NEXT  ") + title + suffix,13,Style.GREEN if current else Style.TEXT)
		var content := _vbox(row,4); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; label.tooltip_text=title+(" · A favorite pastime, chosen autonomously." if favorite else ""); content.add_child(label)
		var action_id := str(task.get("id",""))
		plan_titles[action_id]=label
		if current or waiting:
			_plan_detail=_label("",12,Style.MUTED); _plan_detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; content.add_child(_plan_detail)
			_plan_progress=ProgressBar.new(); _plan_progress.max_value=1.0; _plan_progress.show_percentage=false; _plan_progress.custom_minimum_size.y=4; _plan_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
			for part: String in ["background","fill"]:
				var track := StyleBoxFlat.new(); track.bg_color=Style.INK if part=="background" else Style.GREEN; track.set_corner_radius_all(2)
				_plan_progress.add_theme_stylebox_override(part,track)
			content.add_child(_plan_progress)
		plan_controls[action_id]={}
		if not current:
			var index: int=member.queue.find(task)
			for direction: int in [-1,1]:
				var neighbor := index+direction
				var available: bool=neighbor>=0 and neighbor<member.queue.size()
				var first_id := str(member.queue[mini(index,neighbor)].id) if available else ""
				var second_id := str(member.queue[maxi(index,neighbor)].id) if available else ""
				var key := "earlier" if direction<0 else "later"
				var reorder := _button("↑" if direction<0 else "↓",func(): _send({"type":"reorder_action","member_id":str(member.id),"first_id":first_id,"second_id":second_id}))
				reorder.disabled=not available; reorder.tooltip_text="Move "+title+" "+key+" in the upcoming plan. The current activity continues."
				reorder.set_meta("plan_action",action_id); reorder.set_meta("plan_control",key)
				row.add_child(reorder); plan_controls[action_id][key]=reorder
		var cancel := _button("×",func(): _send({"type":"remove_action","member_id":str(member.id),"action_id":action_id}))
		cancel.tooltip_text="Cancel " + title; row.add_child(cancel)
		cancel.set_meta("plan_action",action_id); cancel.set_meta("plan_control","cancel"); plan_controls[action_id].cancel=cancel
	_update_plan_feedback(member)
	call_deferred("_restore_plan_view",selected_member,focus_action,focus_control,scroll_position)

func _update_plan_feedback(member: Dictionary) -> void:
	if _plan_detail==null or _plan_progress==null: return
	var status := ActivityStatus.sample(member,Session.state.lots[member.lot_id])
	_plan_detail.text=str(status.detail)
	_plan_detail.tooltip_text=str(status.detail)+( "\nEstimated time on the neighborhood clock. A fulfilled need can shorten an activity." if status.phase=="activity" else "")
	_plan_progress.visible=float(status.progress)>=0.0
	if _plan_progress.visible: _plan_progress.value=float(status.progress)

func _restore_plan_view(member_id: String, action_id: String, control_key: String, scroll_position: int) -> void:
	if member_id!=selected_member: return
	plan_scroll.scroll_vertical=scroll_position
	if not plan_panel.visible or not plan_controls.has(action_id) or get_viewport().gui_get_focus_owner()!=null: return
	var controls: Dictionary=plan_controls[action_id]
	var target: Button=controls.get(control_key)
	if target==null or target.disabled:
		target=controls.get("later" if control_key=="earlier" else "earlier",controls.cancel)
		if target.disabled: target=controls.cancel
	target.grab_focus()
	plan_scroll.ensure_control_visible(target)

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
	var follow_social := false
	if _context_page=="people" and social_buttons.has(_social_focus) and is_instance_valid(social_buttons[_social_focus]):
		var card: Control=social_buttons[_social_focus].get_parent().get_parent()
		follow_social=tools_box.get_parent().get_global_rect().intersects(card.get_global_rect())
	_clear(tools_box); _clear(context_box)
	if building:
		activity_label.text="Build & buy"
		if _paint_surface().is_empty(): _build_catalog()
		else: _build_finish_palette(_paint_surface())
		_build_edit_controls(lot)
	elif _context_page=="wishes":
		_rebuild_wishes()
	elif _context_page=="people":
		_rebuild_people()
		if follow_social: call_deferred("_follow_social",_social_focus)
	elif _context_page=="care": _rebuild_care()
	elif _context_page=="hobbies": _rebuild_hobbies()
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

func _open_wishes() -> void:
	_context_page="wishes"; _refresh(); _show_tray(context_panel,true)

func _rebuild_wishes() -> void:
	var member := _member()
	if member.is_empty(): return
	var board: Dictionary=member.get("wishes",{})
	activity_label.text=str(member.name)+"’s wishes"
	for wish: Dictionary in board.get("wishes",[]):
		var definition: Dictionary=Wishes.CATALOG[wish.id]
		var status: String=Session.world.wish_status(member,str(definition.activity))
		var detail := "Complete" if wish.done else (status if not status.is_empty() else "Try this")+" · § %d" % Wishes.REWARD
		var button := _button(("✓ " if wish.done else "♡ ")+str(definition.title)+"\n"+detail,func(): _send({"type":"pursue_wish","member_id":selected_member,"wish_id":str(wish.id)}))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.add_theme_font_size_override("font_size",12)
		button.custom_minimum_size.y=60; button.disabled=bool(wish.done) or not status.is_empty(); button.tooltip_text=str(definition.description)
		if wish.done: button.add_theme_color_override("font_disabled_color",Style.GREEN)
		tools_box.add_child(button)
	var bonus := _label("All three: § %d extra" % Wishes.SET_BONUS,12,Style.GOLD); tools_box.add_child(bonus)
	if not board.get("journal",[]).is_empty():
		tools_box.add_child(_label("LITTLE MOMENTS",11,Style.MUTED))
		for entry: Dictionary in board.journal:
			var line := _label("Day %d · %s" % [int(entry.day),str(entry.text)],12,Style.MUTED)
			line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; line.custom_minimum_size.x=200; tools_box.add_child(line)
	var renew := _button("A fresh set of wishes",func(): _send({"type":"renew_wishes","member_id":selected_member}))
	renew.disabled=not Wishes.can_renew(board,int(Session.state.day)); context_box.add_child(renew)
	var hint := _label("No rush: wishes never expire. Finish this set, then start another on a new day.",12,Style.MUTED)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.custom_minimum_size.x=200; context_box.add_child(hint)

func _announce_wishes(family: Dictionary) -> void:
	for resident: Dictionary in family.get("members",[]):
		var count := Wishes.completed(resident.get("wishes",{}))
		if _wish_seen.has(resident.id) and count>int(_wish_seen[resident.id]) and hud.visible:
			notice_label.text=str(resident.name)+( " finished all three wishes!" if count==3 else " fulfilled a wish!")+" See Wishes for their journal."
			_notice_time=7.0; notice_panel.show(); Soundscape.play_ui("confirm")
		_wish_seen[resident.id]=count

func _select_lot(id: String) -> void:
	_paint_anchor=Vector2i(-1,-1); _paint_request.clear()
	viewed_lot=id; _selected_object=""; _room_anchor=Vector2i(-1,-1); _room_request.clear(); neighborhood_panel.hide(); _refresh()

func _select_resident(id: String) -> void:
	var same := selected_member==id
	selected_member=id
	# Resolve the current member; button callbacks can outlive a client snapshot.
	var member := _member()
	if member.is_empty(): return
	var changed_lot := viewed_lot!=str(member.lot_id)
	if changed_lot: _select_lot(str(member.lot_id))
	else: _refresh()
	if same or changed_lot or not lot_view.resident_in_view(member): lot_view.focus_resident(member)

func _find_resident() -> void:
	if Session.role=="joining": return
	var member := _member()
	if member.is_empty(): return
	if viewed_lot!=str(member.lot_id): _select_lot(str(member.lot_id))
	lot_view.focus_resident(member)

func _send(command: Dictionary) -> void:
	if command.get("type")=="move_object":
		_move_request=command.duplicate()
		_move_request.revision=Session.state.lots[viewed_lot].revision
	Session.command(command)
	if Session.is_authority() and Session.last_action_ok and command.get("type") in ["place","build_room","paint"]: Soundscape.play_ui("build")
	_refresh()

func _entity_clicked(target: Dictionary) -> void:
	if target.get("type")=="care":
		if target.get("owner")!=Session.profile_id or not target.get("need") in Wellbeing.ORDER: return
		for resident: Dictionary in _family().get("members",[]):
			if resident.id==target.get("id") and resident.lot_id==viewed_lot:
				selected_member=str(resident.id); _care_need(str(target.need)); return
		return
	if lot_view.building and selected_tool=="move" and target.get("type")=="object":
		_select_moving_object(str(target.id)); return
	if target.get("type") == "object":
		_selected_object=str(target.id)
		_interact(str(target.id))
	elif target.get("owner") == Session.profile_id:
		selected_member=str(target.id); _refresh()
	else:
		_send({"type":"interact","member_id":selected_member,"lot_id":viewed_lot,"target_id":str(target.id)})

func _select_build_tool(kind: String) -> void:
	var reset_scroll := kind.begins_with("finish_") or not _paint_surface().is_empty()
	selected_tool=kind; _moving_object=""; _move_request.clear()
	_paint_anchor=Vector2i(-1,-1); _paint_request.clear()
	_room_anchor=Vector2i(-1,-1); _room_request.clear(); _refresh()
	if reset_scroll: call_deferred("_reset_catalog_scroll")

func _reset_catalog_scroll() -> void:
	await get_tree().process_frame
	tools_box.get_parent().scroll_vertical=0

func _select_moving_object(id: String) -> void:
	for object: Dictionary in Session.state.lots[viewed_lot].objects:
		if object.id==id:
			_moving_object=id; build_rotation=int(object.rotation); _refresh(); return

func _tile_clicked(cell: Vector2i) -> void:
	var lot: Dictionary=Session.state.get("lots",{}).get(viewed_lot,{})
	if lot.is_empty(): return
	if bool(lot.building) and str(lot.owner)==str(Session.profile_id):
		if not _paint_surface().is_empty():
			if not _paint_request.is_empty(): return
			if _paint_anchor.x<0: _paint_anchor=cell; _refresh(); return
			var surface := _paint_surface()
			var command := {"type":"paint","lot_id":viewed_lot,"surface":surface,"finish":finish_choice[surface],"x":_paint_anchor.x,"y":_paint_anchor.y,"end_x":cell.x,"end_y":cell.y,"revision":lot.revision}
			var plan := Finishes.inspect(lot,command)
			if not plan.ok: _notice(str(plan.message)); Soundscape.play_ui("error"); return
			_paint_request={"revision":lot.revision,"plan":plan}; _send(command)
			return
		if selected_tool=="room":
			if not _room_request.is_empty(): return
			if _room_anchor.x<0:
				_room_anchor=cell; _refresh(); return
			var command := {"type":"build_room","lot_id":viewed_lot,"x":_room_anchor.x,"y":_room_anchor.y,"end_x":cell.x,"end_y":cell.y,"rotation":build_rotation,"revision":lot.revision}
			var residents: Array=[]
			for family: Dictionary in Session.state.families.values():
				for member: Dictionary in family.members:
					if member.lot_id==viewed_lot: residents.append(Vector2i(int(member.x),int(member.y)))
			var plan := RoomPlan.inspect(lot,command,residents)
			if not plan.ok:
				_notice(str(plan.message)); Soundscape.play_ui("error"); return
			_room_request={"revision":lot.revision,"plan":plan}
			_send(command)
			return
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
	if not _paint_surface().is_empty(): return
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
	_layout_notice()
	if show_panel and not bool(Preferences.values.reduced_motion):
		panel.modulate.a=0
		create_tween().tween_property(panel,"modulate:a",1.0,0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else: panel.modulate.a=1

func _unhandled_key_input(event: InputEvent) -> void:
	if hud==null or not hud.visible: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return
	if event is InputEventKey and event.pressed and not event.echo:
		if lot_view.building and (event.ctrl_pressed or event.meta_pressed) and event.keycode==KEY_F:
			if not _paint_surface().is_empty(): _select_build_tool("floor")
			_show_tray(context_panel,true); catalog_search.grab_focus(); catalog_search.select_all()
		elif lot_view.building and (event.ctrl_pressed or event.meta_pressed) and event.keycode in [KEY_Z,KEY_Y]:
			_build_history(event.shift_pressed or event.keycode==KEY_Y)
		elif event.is_action_pressed("pause") or event.keycode==KEY_ESCAPE:
			if _paint_anchor.x>=0 and _paint_request.is_empty():
				_paint_anchor=Vector2i(-1,-1); _refresh()
			elif _room_anchor.x>=0 and _room_request.is_empty():
				_room_anchor=Vector2i(-1,-1); _refresh()
			elif not _moving_object.is_empty() and _move_request.is_empty():
				_moving_object=""; _refresh()
			elif neighborhood_panel.visible or context_panel.visible or plan_panel.visible:
				neighborhood_panel.hide(); context_panel.hide(); plan_panel.hide()
			else: _request_pause()
		elif event.is_action_pressed("rotate"): _rotate()
		elif event.is_action_pressed("neighborhood"): _show_tray(neighborhood_panel,not neighborhood_panel.visible)
		elif event.is_action_pressed("build"): _toggle_build()
		elif event.is_action_pressed("home"): _go_home()
		elif event.is_action_pressed("focus_resident") and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed: _find_resident()
		elif event.is_action_pressed("cancel"): _send({"type":"cancel","member_id":selected_member})
		else: return
		get_viewport().set_input_as_handled()

func _notice(message: String) -> void:
	if notice_label!=null:
		notice_label.text=message
		_notice_time=7.0
		notice_panel.show()
		if not Session.last_action_ok:
			_move_request.clear(); _room_request.clear()
			_paint_request.clear()
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

func _open_people() -> void:
	_context_page="people"; _refresh(); _show_tray(context_panel,true)

func _paint_surface() -> String:
	return selected_tool.trim_prefix("finish_") if selected_tool in ["finish_floor","finish_wall"] else ""

func _build_finish_palette(surface: String) -> void:
	activity_label.text=surface.capitalize()+" finishes"
	finish_buttons.clear()
	var tabs := HBoxContainer.new(); tools_box.add_child(tabs)
	tabs.add_theme_constant_override("separation",4)
	var back := _button("‹ Catalog",func(): _select_build_tool("floor")); tabs.add_child(back)
	for layer: String in ["floor","wall"]:
		var tab := _button(layer.capitalize()+"s",func(): _select_build_tool("finish_"+layer),surface==layer); tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tabs.add_child(tab)
	for tab: Button in tabs.get_children():
		tab.add_theme_font_size_override("font_size",11)
		for part: String in ["normal","hover","pressed","disabled"]:
			var style := tab.get_theme_stylebox(part).duplicate(); style.content_margin_left=6; style.content_margin_right=6; style.content_margin_top=6; style.content_margin_bottom=6; tab.add_theme_stylebox_override(part,style)
	tools_box.add_child(_label("§%d per changed %s tile" % [Finishes.COST[surface],surface],11,Style.MUTED))
	var swatches := GridContainer.new(); swatches.columns=2; swatches.add_theme_constant_override("h_separation",6); swatches.add_theme_constant_override("v_separation",6); tools_box.add_child(swatches)
	for id: String in Finishes.PALETTES[surface]:
		var definition: Dictionary=Finishes.PALETTES[surface][id]
		var title: String=definition.name; var split := title.rfind(" ")
		if split>=0: title=title.substr(0,split)+"\n"+title.substr(split+1)
		var button := _button(title,func(): finish_choice[surface]=id; _paint_anchor=Vector2i(-1,-1); _refresh(),finish_choice[surface]==id)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.add_theme_font_size_override("font_size",12)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.custom_minimum_size.y=50
		for part: String in ["normal","hover","pressed","disabled"]:
			var style := button.get_theme_stylebox(part).duplicate(); style.content_margin_left=6; style.content_margin_right=6; style.content_margin_top=5; style.content_margin_bottom=5; button.add_theme_stylebox_override(part,style)
		button.disabled=not _paint_request.is_empty(); button.tooltip_text="§%d per changed tile · Choose two corners" % int(Finishes.COST[surface])
		var swatch := Image.create(14,24,false,Image.FORMAT_RGBA8); swatch.fill(Color(definition.color))
		button.icon=ImageTexture.create_from_image(swatch); swatches.add_child(button); finish_buttons[id]=button

func _mood_color(tone: String) -> Color:
	return Color("df9785") if tone=="low" else Style.GOLD if tone=="warm" else Style.GREEN

func _care_need(need: String) -> void:
	var member := _member()
	if member.is_empty(): return
	viewed_lot=str(member.lot_id)
	_send({"type":"care","member_id":selected_member,"need":need})
	if not Session.last_action_ok and Session.is_authority():
		_context_page="care"; _refresh(); _show_tray(context_panel,true)

func _rebuild_care() -> void:
	activity_label.text="A little care"
	care_buttons.clear(); care_values.clear()
	var member := _member()
	if member.is_empty(): return
	var mood := Wellbeing.mood(member.needs)
	var summary := _label(str(member.name)+" · "+str(mood.label),14,_mood_color(str(mood.tone)))
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; summary.custom_minimum_size.x=200; tools_box.add_child(summary)
	for need: String in Wellbeing.ORDER:
		var option: Dictionary=_care_options.get(need,{})
		if option.is_empty(): continue
		var label := _label(need.capitalize()+" · %d" % int(member.needs[need]),12,Style.MUTED); tools_box.add_child(label); care_values[need]=label
		var button := _button(str(option.label),func(): _care_need(need)); button.disabled=not option.available; button.tooltip_text=str(option.detail); button.clip_text=true; button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		tools_box.add_child(button); care_buttons[need]=button
		if not option.available and str(option.status)=="Unavailable here":
			var reason := _label(str(option.detail),11,Style.GOLD); reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; reason.custom_minimum_size.x=200; tools_box.add_child(reason)
	var note := _label("Choose a break for any need, or click its bar below. Your existing plan stays in order.",12,Style.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size.x=200; context_box.add_child(note)

func _rebuild_people() -> void:
	var member := _member()
	if member.is_empty(): return
	activity_label.text=str(member.name)+"’s people"
	social_buttons.clear()
	var rows: Array=[]
	for family: Dictionary in Session.state.families.values():
		for other: Dictionary in family.members:
			if other.id==member.id: continue
			rows.append({"member":other,"family":family,"bond":Friendships.bond(Session.state,str(member.id),str(other.id))})
	rows.sort_custom(func(a,b):
		var a_here: bool=a.member.lot_id==member.lot_id; var b_here: bool=b.member.lot_id==member.lot_id
		if a_here!=b_here: return a_here
		if int(a.bond.get("score",0))!=int(b.bond.get("score",0)): return int(a.bond.get("score",0))>int(b.bond.get("score",0))
		return str(a.member.name)<str(b.member.name))
	for row: Dictionary in rows:
		var other: Dictionary=row.member; var family: Dictionary=row.family; var bond: Dictionary=row.bond
		var card := PanelContainer.new(); tools_box.add_child(card)
		var card_style := Style.box(Style.PANEL,5,Style.EDGE); card_style.content_margin_left=8; card_style.content_margin_right=8; card_style.content_margin_top=8; card_style.content_margin_bottom=8
		card.add_theme_stylebox_override("panel",card_style)
		var body := _vbox(card,5)
		var head := HBoxContainer.new(); body.add_child(head)
		var portrait := Portrait.new(); portrait.look=Appearance.of(other).duplicate(); head.add_child(portrait); portrait.custom_minimum_size=Vector2(42,64)
		var info := _vbox(head,3); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var name := _label(str(other.name),14); name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; name.clip_text=true; name.tooltip_text=str(other.name); info.add_child(name)
		info.add_child(_label(Friendships.title(bond),12,Style.GREEN if int(bond.get("score",0))>=40 else Style.MUTED))
		var place := _label("Here" if other.lot_id==member.lot_id else str(Session.state.lots[other.lot_id].name),11,Style.MUTED)
		place.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; place.clip_text=true; info.add_child(place)
		var bar := ProgressBar.new(); bar.show_percentage=false; bar.value=int(bond.get("score",0)); bar.custom_minimum_size.y=7; body.add_child(bar)
		for part: String in ["background","fill"]:
			var bar_style := Style.box(Style.GREEN if part=="fill" else Style.INK,3)
			bar_style.content_margin_top=0; bar_style.content_margin_bottom=0
			bar.add_theme_stylebox_override(part,bar_style)
		var status: String=Session.world.chat_status(member,str(other.id))
		var here: bool=other.lot_id==member.lot_id
		var building: bool=Session.state.lots[other.lot_id].building
		var text := "Under construction" if building else status if not status.is_empty() else ("Queue chat" if Session.world._chat_busy(other,member) else "Chat") if here else "Visit"
		var button := _button(text,func(): _social_action(str(other.id)))
		button.disabled=building or not status.is_empty(); body.add_child(button); social_buttons[other.id]=button
		var detail := ""
		if not family.online: detail="Household away · Progress waits"
		elif int(bond.get("score",0))>=100: detail="A lasting friendship"
		elif Friendships.remaining(bond,int(Session.state.day))==0: detail="Caught up today · More tomorrow"
		elif int(bond.get("last_chat_day",0))>0: detail="Last catch-up: day %d" % int(bond.last_chat_day)
		if not detail.is_empty():
			var hint := _label(detail,11,Style.MUTED); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.custom_minimum_size.x=200; body.add_child(hint)
	var note := _label("Two catch-ups a day. No decay while away.",12,Style.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size.x=200; context_box.add_child(note)

func _social_action(target_id: String) -> void:
	_social_focus=target_id
	var other := Session.world._find_member(target_id)
	var member := _member()
	if other.is_empty() or member.is_empty(): return
	if other.lot_id==member.lot_id:
		_send({"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":target_id})
	else:
		_send({"type":"visit","member_id":member.id,"lot_id":other.lot_id})
		viewed_lot=str(other.lot_id); _refresh()

func _announce_friendships(family: Dictionary) -> void:
	var own_ids: Array=[]
	for member: Dictionary in family.get("members",[]): own_ids.append(str(member.id))
	for id: String in Session.state.get("friendships",{}):
		var bond: Dictionary=Session.state.friendships[id]
		if not own_ids.has(bond.a) and not own_ids.has(bond.b): continue
		var before := int(_friend_seen.get(id,bond.score))
		_friend_seen[id]=int(bond.score)
		if not hud.visible: continue
		if (before<40 and int(bond.score)>=40) or (before<70 and int(bond.score)>=70) or (before<100 and int(bond.score)==100):
			var first := Session.world._find_member(str(bond.a)); var second := Session.world._find_member(str(bond.b))
			notice_label.text=str(first.get("name","A resident"))+" and "+str(second.get("name","a neighbor"))+" are now "+Friendships.title(bond).to_lower()+"."
			_notice_time=7.0; notice_panel.show(); Soundscape.play_ui("confirm")

func _follow_social(target_id: String) -> void:
	await get_tree().process_frame
	if _context_page!="people" or target_id!=_social_focus or not context_panel.visible: return
	if social_buttons.has(target_id) and is_instance_valid(social_buttons[target_id]):
		tools_box.get_parent().ensure_control_visible(social_buttons[target_id].get_parent().get_parent())

func _build_catalog() -> void:
	catalog_buttons.clear()
	var matches := BuildCatalog.results(_catalog_category,_catalog_query)
	activity_label.text="Catalog · %d" % matches.size()
	var previous_group := ""
	var funds := int(Session.state.lots[viewed_lot].funds)
	for kind: String in matches:
		var item := BuildCatalog.entry(kind)
		if _catalog_category=="all" and _catalog_query.strip_edges().is_empty() and item.category!=previous_group:
			previous_group=str(item.category)
			tools_box.add_child(_label(str(BuildCatalog.CATEGORIES[previous_group]).to_upper(),10,Style.MUTED))
		var detail := str(item.price)+" · "+str(item.get("size",item.use))
		if item.has("size"): detail+=" · "+str(item.use)
		var button := _button(str(item.name)+"\n"+detail,func(): _select_build_tool(kind),selected_tool==kind)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.add_theme_font_size_override("font_size",12); button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; button.clip_text=true
		button.tooltip_text=str(item.description)+"\n"+str(item.use)+("\nOver budget: need §%d more." % (int(item.cost)-funds) if int(item.get("cost",0))>funds else "")
		if int(item.get("cost",0))>funds and selected_tool!=kind: button.add_theme_color_override("font_color",Style.GOLD)
		_compact_control(button,selected_tool==kind); tools_box.add_child(button); catalog_buttons[kind]=button
	if matches.is_empty():
		var empty := _label("Nothing matches here. Try a shorter search or browse All.",12,Style.MUTED)
		empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; empty.custom_minimum_size.x=200; tools_box.add_child(empty)
		tools_box.add_child(_button("Show everything",_clear_catalog_filters))

func _clear_catalog_filters() -> void:
	_catalog_category="all"; _catalog_query=""; catalog_category.select(0); catalog_search.text=""; _refresh(); call_deferred("_reset_catalog_scroll")

func _compact_control(control: Control, accent: bool=false) -> void:
	for state_name: String in (["normal","focus"] if control is LineEdit else ["normal","hover","pressed","disabled"]):
		var color := Style.INK if control is LineEdit else Style.GREEN if accent or state_name=="pressed" else Style.EDGE if state_name=="hover" else Style.PANEL
		var surface := Style.box(color,4,Style.GREEN if state_name in ["hover","focus"] else Style.EDGE)
		surface.content_margin_top=5; surface.content_margin_bottom=5; surface.content_margin_left=8; surface.content_margin_right=8
		control.add_theme_stylebox_override(state_name,surface)

func _edit_button(text: String, action: Callable, parent: Node, tooltip: String="") -> Button:
	var button := _button(text,action)
	button.add_theme_font_size_override("font_size",11); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.tooltip_text=tooltip; _compact_control(button); parent.add_child(button)
	return button

func _build_edit_controls(lot: Dictionary) -> void:
	var painting := not _paint_surface().is_empty()
	if not painting:
		var title := ""
		var detail := ""
		var hint := ""
		if BuildCatalog.ORDER.has(selected_tool):
			var item := BuildCatalog.entry(selected_tool)
			title=str(item.name)+" · "+str(item.price)
			detail=str(item.use)
			if item.has("size"):
				var footprint := Catalog.footprint(selected_tool,build_rotation)
				detail="%d×%d · " % [footprint.x,footprint.y]+detail
			hint=str(item.description)
			if int(item.get("cost",0))>int(lot.funds): detail="Need §%d more · Preview available" % (int(item.cost)-int(lot.funds))
		elif selected_tool=="move":
			title="Move furniture · Free"; detail="Choose furniture, then its new spot"; hint="Rotate before placing. Escape cancels the selection."
		else:
			title="Sell & demolish"; detail="Furniture returns 60% of its price"; hint="Click furniture or a tile. Undo restores the exact purchase."
		catalog_detail=_label(title,12,Style.GOLD); catalog_detail.clip_text=true; catalog_detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; catalog_detail.tooltip_text=title+"\n"+hint; context_box.add_child(catalog_detail)
		var subtitle := _label(detail,11,Style.MUTED); subtitle.clip_text=true; subtitle.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; subtitle.tooltip_text=detail+"\n"+hint; context_box.add_child(subtitle)
		var editing := HBoxContainer.new(); editing.add_theme_constant_override("separation",5); context_box.add_child(editing)
		var move := _edit_button("Cancel move" if not _moving_object.is_empty() else "Move",func(): _select_build_tool("move"),editing,"Choose furniture to rearrange at no cost.")
		move.disabled=not _move_request.is_empty()
		_edit_button("Sell",func(): _select_build_tool("erase"),editing,"Demolish tiles or sell furniture for 60% of its price.")
		_edit_button("Door %d" % (build_rotation+1) if selected_tool=="room" else "%d° ↻" % (build_rotation*90),_rotate,editing,("Change doorway side" if selected_tool=="room" else "Rotate furnishing")+" · "+Preferences.action_label("rotate"))
	var history := HBoxContainer.new(); history.add_theme_constant_override("separation",5); context_box.add_child(history)
	undo_button=_edit_button("Undo",func(): _build_history(false),history,"Undo the last edit and its price · Ctrl/Cmd+Z")
	redo_button=_edit_button("Redo",func(): _build_history(true),history,"Redo a building edit · Ctrl/Cmd+Shift+Z or Ctrl+Y")
	undo_button.disabled=int(lot.get("build_undo",0))==0; redo_button.disabled=int(lot.get("build_redo",0))==0
	if not painting: _edit_button("Discard draft",func(): _send({"type":"build_cancel","lot_id":viewed_lot}),history,"Restore the whole house and budget from before construction.")
	else:
		var finish := HBoxContainer.new(); finish.add_theme_constant_override("separation",5); context_box.add_child(finish)
		var cancel := _edit_button("Cancel area",func(): _paint_anchor=Vector2i(-1,-1); _refresh(),finish,"Cancel the first painting corner · Escape")
		cancel.disabled=_paint_anchor.x<0 or not _paint_request.is_empty()
		_edit_button("Discard draft",func(): _send({"type":"build_cancel","lot_id":viewed_lot}),finish,"Restore the whole house and budget from before construction.")

func _input(event: InputEvent) -> void:
	if catalog_search==null or not catalog_search.has_focus() or not catalog_filters.is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if not _catalog_query.is_empty(): catalog_search.clear(); _catalog_query=""; _refresh(); call_deferred("_reset_catalog_scroll")
		else:
			catalog_search.release_focus()
			_unhandled_key_input(event)
		get_viewport().set_input_as_handled()

func _open_hobbies() -> void:
	_context_page="hobbies"; _refresh(); _show_tray(context_panel,true)

func _rebuild_hobbies() -> void:
	hobby_buttons.clear()
	var member := _member()
	if member.is_empty(): return
	activity_label.text=str(member.name)+"’s hobbies"
	for hobby: String in Hobbies.ORDER:
		var definition: Dictionary=Hobbies.CATALOG[hobby]
		var entry: Dictionary=member.hobbies[hobby]
		var level := Hobbies.rank(entry)
		var card := PanelContainer.new(); tools_box.add_child(card)
		var card_style := Style.box(Style.PANEL,5,Style.EDGE)
		card_style.content_margin_left=8; card_style.content_margin_right=8; card_style.content_margin_top=8; card_style.content_margin_bottom=8
		card.add_theme_stylebox_override("panel",card_style)
		var body := _vbox(card,4)
		var head := HBoxContainer.new(); body.add_child(head)
		var name := _label(str(definition.name),14); name.size_flags_horizontal=Control.SIZE_EXPAND_FILL; head.add_child(name)
		head.add_child(_label("Rank %d / 5" % level,11,Style.GOLD))
		body.add_child(_label(Hobbies.title(hobby,entry),12,Style.GREEN))
		var progress := "Mastered · Yours to enjoy"
		if level<5:
			var current: int=int(entry.sessions)-int(Hobbies.THRESHOLDS[level-1])
			var needed: int=int(Hobbies.THRESHOLDS[level])-int(Hobbies.THRESHOLDS[level-1])
			progress="%d / %d practices to next rank" % [current,needed]
			if Hobbies.remaining(entry,int(Session.state.day))==0: progress="Two practices today · More tomorrow"
		body.add_child(_label(progress,11,Style.MUTED))
		var benefit := _label(Hobbies.benefit(hobby,entry),11,Style.MUTED)
		benefit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; benefit.custom_minimum_size.x=200; body.add_child(benefit)
		var option: Dictionary=_hobby_options.get(hobby,{"available":false,"status":"Unavailable here","detail":""})
		var button := _button(str(definition.action) if option.available else str(option.status),func(): _send({"type":"practice_hobby","member_id":selected_member,"hobby":hobby}))
		button.disabled=not option.available; button.tooltip_text=str(option.detail); button.add_theme_font_size_override("font_size",12); body.add_child(button); hobby_buttons[hobby]=button
		if not option.available and option.status=="Unavailable here":
			var reason := _label(str(option.detail),11,Style.GOLD); reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; reason.custom_minimum_size.x=200; body.add_child(reason)
	var note := _label("Finish activities you choose. Two practices per hobby each day; progress stays while away.",12,Style.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size.x=200; context_box.add_child(note)

func _announce_hobbies(family: Dictionary) -> void:
	for member: Dictionary in family.get("members",[]):
		for hobby: String in Hobbies.ORDER:
			var entry: Dictionary=member.hobbies[hobby]
			var key := str(member.id)+":"+hobby
			var level := Hobbies.rank(entry)
			if _hobby_seen.has(key) and level>int(_hobby_seen[key]) and hud.visible:
				notice_label.text=str(member.name)+" became a "+Hobbies.title(hobby,entry).to_lower()+"! "+str(Hobbies.CATALOG[hobby].name)+" rank %d." % level
				_notice_time=7.0; notice_panel.show(); Soundscape.play_ui("confirm")
			_hobby_seen[key]=level
