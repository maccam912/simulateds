extends VBoxContainer
signal command_requested(command: Dictionary)
const Style=preload("res://game/style.gd")
var destination: Label
var note: Label
var feedback: Label
var confirm: Button
var choices := {}
var details := {}
var pending := {}
var _ack := false
var _error := ""
var _context := ""
var _lot := ""
var _member := ""
var _option := {}
var _chosen := {}
func _ready() -> void:
	add_theme_constant_override("separation",6)
	destination=_label(14,Style.GOLD)
	for resident: Dictionary in Session.state.families.get(Session.profile_id,{}).get("members",[]):
		var id: String=resident.id
		var button:=CheckBox.new(); button.custom_minimum_size.y=32; button.add_theme_font_size_override("font_size",13)
		button.add_theme_color_override("font_disabled_color",Style.MUTED); button.clip_text=true; button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; add_child(button); choices[id]=button
		button.toggled.connect(func(on): _chosen[id]=on; _error=""; refresh(_lot,_member))
		details[id]=_label(12,Style.MUTED)
	note=_label(12,Style.MUTED); note.text="Stops their current actions.\nClears their planned activities."
	confirm=Button.new(); confirm.custom_minimum_size.y=36; confirm.pressed.connect(_request); add_child(confirm)
	feedback=_label(12,Style.GOLD)
	Session.command_completed.connect(_completed); Soundscape.attach_controls(self)
func _label(font_size: int,color: Color) -> Label:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label
func refresh(lot_id: String,member_id: String) -> void:
	_lot=lot_id; _member=member_id
	var family: Dictionary=Session.state.families.get(Session.profile_id,{})
	var context:=str([Session.role,Session.profile_id,lot_id])
	if context!=_context:
		_context=context; pending={}; _ack=false; _error=""; _chosen.clear()
		for resident: Dictionary in family.get("members",[]): _chosen[resident.id]=resident.lot_id!=lot_id
	var lot: Dictionary=Session.state.lots.get(lot_id,{})
	destination.text="To "+str(lot.get("name","this home"))
	if _ack and not pending.is_empty():
		var arrived: bool=pending.orders.all(func(order):
			var resident: Dictionary=Session.world._member(family,str(order.member_id))
			return resident.get("lot_id")==pending.lot_id and int(resident.get("next_action",0))>int(order.next_action))
		if arrived: pending={}; _ack=false; _error="Arrived. Choose an activity together."
	var travelers: Array=[]
	for resident: Dictionary in family.get("members",[]):
		var id: String=resident.id
		if not choices.has(id): continue
		var here: bool=resident.lot_id==lot_id
		if here: _chosen[id]=false
		var button: CheckBox=choices[id]
		button.text=str(resident.name); button.tooltip_text=str(resident.name); button.set_pressed_no_signal(bool(_chosen.get(id,false)))
		button.disabled=here or not pending.is_empty() or Session.role=="joining"
		if button.button_pressed: travelers.append(id)
		var current: String=Session.state.lots.get(resident.lot_id,{}).get("name","Away")
		var task: Dictionary=resident.task
		var count: int=resident.queue.size()+(0 if task.is_empty() or task.get("automatic",false) else 1)
		details[id].text="Already here · Keep their plan" if here else current+(" · %d planned" % count if count>0 else " · Acting freely" if task.get("automatic",false) else " · Free time")
		details[id].tooltip_text=current+"\n"+(Session.world._activity_title(resident,task)+"\n" if not task.is_empty() else "")+str(resident.queue.size())+" upcoming actions"
	_option=Session.world.travel_option(Session.profile_id,lot_id,travelers)
	confirm.text=("Go home" if lot_id==str(family.get("home_lot","")) else "Visit")+" · %d" % travelers.size()
	if travelers.is_empty(): confirm.text="Everyone is here" if family.get("members",[]).all(func(resident): return resident.lot_id==lot_id) else "Choose residents"
	note.visible=not travelers.is_empty()
	confirm.disabled=not _option.ok or not pending.is_empty() or Session.role=="joining"
	feedback.text="Waiting for the neighborhood…" if not pending.is_empty() else _error if not _error.is_empty() else str(_option.message) if not _option.ok else ""
	feedback.visible=not feedback.text.is_empty()
func _request() -> void:
	if not pending.is_empty() or not _option.get("ok",false): return
	pending={"type":"travel_household","lot_id":_lot,"member_id":_member,"travelers":_option.orders.map(func(order): return str(order.member_id)),"orders":_option.orders.duplicate(true)}
	_ack=false; _error=""; refresh(_lot,_member); command_requested.emit(pending.duplicate(true))
func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or intent!=pending: return
	if ok: _ack=true
	else: pending={}; _ack=false; _error=message
	refresh(_lot,_member)
