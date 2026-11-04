extends VBoxContainer
signal command_requested(command: Dictionary)
const Leisure=preload("res://game/shared_leisure.gd")
const Recreation=preload("res://game/recreation.gd")
const Style=preload("res://game/style.gd")
const Catalog=preload("res://game/catalog.gd")
var title: Label
var places: Label
var company: Label
var people: VBoxContainer
var rows := {}
var single_button: Button
var household_button: Button
var note: Label
var feedback: Label
var pending: Dictionary={}
var _ack := false
var _context := ""
var _lot := ""
var _object := ""
var _member := ""
var _single: Dictionary={}
var _household: Dictionary={}
var _error := ""
func _ready() -> void:
	add_theme_constant_override("separation",6)
	title=_label(14,Style.GOLD); places=_label(12,Style.GREEN); company=_label(12,Style.MUTED)
	people=VBoxContainer.new(); people.add_theme_constant_override("separation",6); add_child(people)
	single_button=_button(func(): _request(false)); household_button=_button(func(): _request(true))
	note=_label(12,Style.MUTED); feedback=_label(12,Style.GOLD)
	Session.command_completed.connect(_completed); Soundscape.attach_controls(self)
func _label(font_size: int,color: Color) -> Label:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label
func _button(callback: Callable) -> Button:
	var button:=Button.new(); button.custom_minimum_size.y=34; button.add_theme_font_size_override("font_size",12)
	button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; button.pressed.connect(callback); add_child(button); return button
func refresh(lot_id: String,object_id: String,member_id: String) -> void:
	_lot=lot_id; _object=object_id; _member=member_id
	add_theme_constant_override("separation",4 if get_viewport_rect().size.y<800 else 6)
	var context:=str([Session.role,Session.profile_id,lot_id,object_id,member_id])
	if context!=_context: _context=context; pending={}; _ack=false; _error=""
	var lot: Dictionary=Session.state.lots.get(lot_id,{})
	var object: Dictionary=Session.world._object(lot,object_id) if not lot.is_empty() else {}
	var family: Dictionary=Session.state.families.get(Session.profile_id,{})
	var member: Dictionary=Session.world._member(family,member_id) if not family.is_empty() else {}
	if _ack and not pending.is_empty():
		if pending.orders.all(func(order): return int(Session.world._member(family,str(order.member_id)).get("next_action",0))>int(order.next_action)): pending={}; _ack=false
	var exists: bool=object.get("kind") in Recreation.KINDS
	for control: Control in [places,company,people,single_button,household_button,note,feedback]: control.visible=exists
	if not exists: title.text="This furnishing is no longer here."; return
	var dance: bool=object.kind=="stereo"
	title.text=str(Catalog.ITEMS[object.kind].name); title.tooltip_text="Fun restored · Company also restores social"
	var spaces:=Leisure.spaces(Session.state,lot,object,member)
	places.text=Leisure.summary(spaces); places.tooltip_text=Leisure.layout_text(spaces)
	var players: Array=Leisure.players(Session.state,lot_id,object_id,false)
	var names: PackedStringArray=[]
	for player: Dictionary in players: names.append(str(player.name))
	company.visible=not names.is_empty(); company.text="Taking part: "+", ".join(names)
	company.tooltip_text=company.text; company.max_lines_visible=1; company.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_single=Session.world.recreation_option(Session.profile_id,member_id,lot_id,object_id,false)
	_household=Session.world.recreation_option(Session.profile_id,member_id,lot_id,object_id,true)
	var visible_ids: Array=[]
	for row: Dictionary in _household.rows:
		var id: String=row.id; visible_ids.append(id)
		if not rows.has(id):
			var label:=Label.new(); label.add_theme_font_size_override("font_size",12); label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			people.add_child(label); rows[id]=label
		rows[id].text=str(row.name)+"\n"+str(row.detail).split(" · ")[0]
		rows[id].tooltip_text=str(row.name)+": "+str(row.detail)
		rows[id].add_theme_color_override("font_color",Style.TEXT if not str(row.action).is_empty() else Style.MUTED)
		people.move_child(rows[id],visible_ids.size()-1)
	for id: String in rows.keys():
		if not visible_ids.has(id): rows[id].queue_free(); rows.erase(id)
	var choosing: bool=_single.ok and _single.orders[0].action=="choose"
	single_button.text=("Choose current dance" if dance else "Choose current game") if choosing else ("Dance · " if dance else "Play · ")+str(member.get("name","Resident"))
	household_button.text="Call household · %d" % _household.orders.size()
	if _household.orders.is_empty(): household_button.text="Already in their plans" if not _household.rows.is_empty() and _household.rows.all(func(row): return str(row.detail).begins_with("Already")) else "Nobody to call here"
	for entry: Array in [[single_button,_single],[household_button,_household]]:
		entry[0].disabled=not entry[1].ok or not pending.is_empty() or Session.role=="joining"; entry[0].tooltip_text=str(entry[1].message)
	note.text="Plans first · Arrivals may differ.\nChosen company: 12 min for friendship."
	note.tooltip_text="Only your household here. Existing plans stay first; different arrival times may mean playing separately. Both residents must choose 12 game minutes together to build friendship."
	if choosing: note.text="Keep your place and time.\nOnly new company builds friendship."
	if not choosing:
		for resident: Dictionary in family.get("members",[]):
			if resident.lot_id==lot_id and resident.task.get("target_id")==object_id and float(resident.needs.fun)>=99.0 and Leisure.chosen_time(resident.task)>=4.0 and Leisure.company_window(Session.state,resident).hold:
				note.text="Making time for chosen company.\nLeave freely · Plans follow next."
				note.tooltip_text="Chosen companions already playing or on their way get a brief shared moment before a full fun bar ends play. The natural activity timer still applies. You can cancel, travel, or leave at any time."
				break
	feedback.text="Waiting for the neighborhood…" if not pending.is_empty() else _error if not _error.is_empty() else str(_household.message) if _household.rows.is_empty() else ""
	feedback.visible=not feedback.text.is_empty()
func _request(household: bool) -> void:
	var option: Dictionary=_household if household else _single
	if not pending.is_empty() or not option.get("ok",false): return
	pending={"type":"recreation","lot_id":_lot,"target_id":_object,"member_id":_member,"household":household,"revision":int(option.revision),"orders":option.orders.duplicate(true)}
	_ack=false; _error=""; refresh(_lot,_object,_member); command_requested.emit(pending.duplicate(true))
func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or intent!=pending: return
	if ok: _ack=true
	else: pending={}; _ack=false; _error=message
	refresh(_lot,_object,_member)
