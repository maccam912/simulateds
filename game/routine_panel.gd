extends VBoxContainer
signal closed
signal command_requested(command: Dictionary)
const Style = preload("res://game/style.gd")
const Routines = preload("res://game/routines.gd")
const Wellbeing = preload("res://game/wellbeing.gd")
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var subtitle: Label
var new_button: Button
var from_plan_button: Button
var capture_hint: Label
var source_note: Label
var draft_source: Dictionary={}
var _capture: Dictionary={}
var run_buttons: Dictionary={}
var edit_buttons: Dictionary={}
var delete_buttons: Dictionary={}
var name_field: LineEdit
var step_controls: Array[OptionButton]=[]
var step_buttons: Array[Dictionary]=[]
var add_button: Button
var save_button: Button
var back_button: Button
var draft: Dictionary={}
var pending: Dictionary={}
var _acknowledged := false
var _before_tick := 0
var _revision := 0
var _member := ""
var _context := ""
var _signature := ""
var _options := {}

func _ready() -> void:
	add_theme_constant_override("separation",9)
	var head := HBoxContainer.new(); add_child(head)
	var title := _label("Household routines",20); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; head.add_child(title)
	head.add_child(_button("×",func(): closed.emit()))
	subtitle=_label("",13,Style.MUTED); subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(subtitle)
	scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	body=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",8); scroll.add_child(body)
	status=_label("",12,Style.GOLD); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.x=400; add_child(status)
	Session.command_completed.connect(_completed)

func refresh(member_id: String) -> void:
	_member=member_id
	var family: Dictionary=Session.state.get("families",{}).get(Session.profile_id,{})
	if family.is_empty(): return
	var context := str([Session.role,Session.profile_id,family.home_lot])
	if context!=_context: _context=context; draft={}; draft_source={}; pending={}; _signature=""
	var board: Dictionary=family.routines
	var member: Dictionary={}
	for resident: Dictionary in family.members:
		if resident.id==member_id: member=resident; break
	if member.is_empty(): return
	_capture=Routines.capture_plan(member,Session.state.lots[member.lot_id])
	subtitle.text="For "+str(member.name)+" · Saved routines are shared by your household."
	_options={}
	for entry: Dictionary in board.entries: _options[entry.id]=Session.world.routine_option(Session.profile_id,member_id,str(entry.id))
	if _acknowledged and not pending.is_empty():
		var applied: bool=int(board.revision)>int(pending.revision)
		if pending.type=="run_routine":
			applied=int(Session.state.tick)>_before_tick
			var tasks: Array=member.queue.duplicate(); tasks.append(member.task)
			for task: Dictionary in tasks:
				if task.get("routine_id")==pending.routine_id: applied=true
		if applied:
			if pending.type=="routine_save": draft={}; draft_source={}
			pending={}; _acknowledged=false; _signature=""
	if not draft.is_empty():
		if pending.is_empty() and int(board.revision)!=_revision: status.text="The saved library changed. Back returns to its latest version; your draft is still here."
		_set_pending(); return
	var signature := str([board,_options,member_id,pending,_capture])
	if signature!=_signature:
		_signature=signature
		var focus_key := ""; var focus_kind := ""
		var focused := get_viewport().gui_get_focus_owner()
		if focused!=null and is_ancestor_of(focused): focus_key=str(focused.get_meta("routine_id","")); focus_kind=str(focused.get_meta("routine_control",""))
		var offset := scroll.scroll_vertical
		_library(board)
		call_deferred("_restore_focus",focus_key,focus_kind,offset)

func _library(board: Dictionary) -> void:
	_clear(); run_buttons.clear(); edit_buttons.clear(); delete_buttons.clear(); step_controls.clear(); step_buttons.clear()
	var create_row := HBoxContainer.new(); body.add_child(create_row)
	new_button=_button("New routine",func(): _edit({"id":"","name":"","steps":["fridge"]}))
	new_button.disabled=board.entries.size()>=Routines.MAX_ROUTINES or not pending.is_empty(); create_row.add_child(new_button)
	from_plan_button=_button("Use current plan",_use_current_plan); from_plan_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; create_row.add_child(from_plan_button)
	from_plan_button.disabled=new_button.disabled or _capture.get("steps",[]).is_empty()
	from_plan_button.set_meta("routine_control","capture"); new_button.set_meta("routine_control","new")
	capture_hint=_label("",12,Style.MUTED); capture_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; capture_hint.custom_minimum_size.x=360; body.add_child(capture_hint)
	if board.entries.size()>=Routines.MAX_ROUTINES: capture_hint.text="All four slots are in use. Edit or remove a routine to make space."
	elif _capture.get("steps",[]).is_empty():
		capture_hint.text="Plan some care or recreation for "+str(_capture.get("resident","this resident"))+", then copy it here."
		if not _capture.get("omitted",[]).is_empty(): capture_hint.text="This plan has no reusable activities. Walking, conversations, garden work, and automatic care are not copied."
	else: capture_hint.text="Copy %d %s from %s’s plan. Review before saving." % [_capture.steps.size(),"activity" if _capture.steps.size()==1 else "activities",str(_capture.resident)]
	from_plan_button.tooltip_text=capture_hint.text+" Current activities keep running. Walking, conversations, garden work, and automatic care are left out and explained in the draft."
	for entry: Dictionary in board.entries:
		var card := PanelContainer.new(); card.add_theme_stylebox_override("panel",Style.box(Style.PANEL,5,Style.EDGE)); body.add_child(card)
		var content := VBoxContainer.new(); content.add_theme_constant_override("separation",6); card.add_child(content)
		var title := _label(str(entry.name),16,Style.GOLD); title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; content.add_child(title)
		var steps: Array[String]=[]
		for kind: String in entry.steps: steps.append(str(Wellbeing.ACTIONS[kind]))
		var summary := _label(" → ".join(steps),12,Style.MUTED); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; summary.custom_minimum_size.x=360; content.add_child(summary)
		var option: Dictionary=_options[entry.id]
		var reason := _label(str(option.detail),12,Style.MUTED if option.available else Style.GOLD); reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; reason.custom_minimum_size.x=360; content.add_child(reason)
		var row := HBoxContainer.new(); content.add_child(row)
		var id := str(entry.id); var revision := int(board.revision)
		var run := _button("Add to plan",func(): _request({"type":"run_routine","member_id":_member,"routine_id":id,"revision":revision}))
		run.size_flags_horizontal=Control.SIZE_EXPAND_FILL; run.disabled=not option.available or not pending.is_empty(); row.add_child(run); run_buttons[id]=run
		var edit := _button("Edit",func(): _edit(entry)); edit.disabled=not pending.is_empty(); row.add_child(edit); edit_buttons[id]=edit
		var remove := _button("Remove",func(): _request({"type":"routine_delete","routine_id":id,"revision":revision})); remove.disabled=not pending.is_empty(); remove.tooltip_text="Remove the saved recipe. Activities already planned will continue."; row.add_child(remove); delete_buttons[id]=remove
		for pair: Array in [[run,"run"],[edit,"edit"],[remove,"delete"]]: pair[0].set_meta("routine_id",id); pair[0].set_meta("routine_control",pair[1])
	if board.entries.is_empty(): body.add_child(_label("Save a sequence of care and recreation to use again.",13,Style.MUTED))

func _use_current_plan() -> void:
	if not pending.is_empty(): return
	var family: Dictionary=Session.state.get("families",{}).get(Session.profile_id,{})
	if family.is_empty() or family.routines.entries.size()>=Routines.MAX_ROUTINES: refresh(_member); return
	for member: Dictionary in family.members:
		if member.id!=_member: continue
		var captured := Routines.capture_plan(member,Session.state.lots[member.lot_id])
		if captured.steps.is_empty():
			status.text="The plan changed; no reusable activities remain."; refresh(_member); return
		_edit({"id":"","name":"","steps":captured.steps},captured)
		return

func _edit(entry: Dictionary, source: Dictionary={}) -> void:
	if not pending.is_empty(): return
	draft_source=source.duplicate(true)
	draft=entry.duplicate(true); _revision=int(Session.state.families[Session.profile_id].routines.revision); status.text=""
	_editor(); name_field.grab_focus(); name_field.select_all(); scroll.scroll_vertical=0

func focus_entry() -> void:
	if not pending.is_empty(): return
	if not draft.is_empty(): name_field.grab_focus(); scroll.ensure_control_visible(name_field)
	elif is_instance_valid(new_button) and not new_button.disabled: new_button.grab_focus()

func _editor() -> void:
	_clear(); step_controls.clear(); step_buttons.clear(); source_note=null
	if not draft_source.is_empty():
		source_note=_label("Copied %d %s from %s’s plan. Current activities keep running. Review this draft, then name and save it." % [draft_source.steps.size(),"activity" if draft_source.steps.size()==1 else "activities",str(draft_source.resident)],12,Style.GREEN)
		source_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; source_note.custom_minimum_size.x=360; body.add_child(source_note)
	var name_row := HBoxContainer.new(); body.add_child(name_row); name_row.add_child(_label("Name",13))
	name_field=LineEdit.new(); name_field.max_length=32; name_field.placeholder_text="A familiar part of the day"; name_field.text=str(draft.name); name_field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name_row.add_child(name_field); name_field.text_changed.connect(func(value: String): draft.name=value)
	for index in range(draft.steps.size()):
		var row := HBoxContainer.new(); body.add_child(row); row.add_child(_label(str(index+1)+".",13,Style.MUTED))
		var choose := OptionButton.new(); choose.fit_to_longest_item=false; choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(choose)
		for kind: String in Routines.ACTIVITIES: choose.add_item(str(Wellbeing.ACTIONS[kind]))
		choose.select(Routines.ACTIVITIES.find(str(draft.steps[index]))); choose.item_selected.connect(func(choice: int): draft.steps[index]=Routines.ACTIVITIES[choice]); step_controls.append(choose)
		var up := _button("↑",func(): _move_step(index,-1)); up.disabled=index==0; up.tooltip_text="Move earlier"; row.add_child(up)
		var down := _button("↓",func(): _move_step(index,1)); down.disabled=index==draft.steps.size()-1; down.tooltip_text="Move later"; row.add_child(down)
		var remove := _button("×",func(): draft.steps.remove_at(index); _editor(); _focus_step(mini(index,draft.steps.size()-1))); remove.tooltip_text="Remove this activity"; row.add_child(remove)
		step_buttons.append({"up":up,"down":down,"remove":remove})
	add_button=_button("+ Add activity",func(): draft.steps.append("bookshelf"); _editor(); _focus_step(draft.steps.size()-1)); add_button.disabled=draft.steps.size()>=Routines.MAX_STEPS; body.add_child(add_button)
	var note := _label("One to six activities. Furnishings are chosen on the resident's current lot each time you add the routine.",12,Style.MUTED)
	if draft.steps.size()>Routines.MAX_STEPS:
		note.text="%d activities copied. Remove %d to keep at most six before saving. Nothing has been cut from the draft." % [draft.steps.size(),draft.steps.size()-Routines.MAX_STEPS]
		note.add_theme_color_override("font_color",Style.GOLD)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size.x=360; body.add_child(note)
	if not draft_source.get("omitted",[]).is_empty():
		var omitted := _label("Left out of the copied plan",13,Style.GOLD); body.add_child(omitted)
		for skipped: Dictionary in draft_source.omitted:
			var explanation := _label("%d. %s · %s" % [int(skipped.position),str(skipped.title),str(skipped.reason)],12,Style.MUTED)
			explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; explanation.custom_minimum_size.x=360; body.add_child(explanation)
	var footer := HBoxContainer.new(); body.add_child(footer)
	back_button=_button("Back",_back); footer.add_child(back_button)
	save_button=_button("Save routine",func(): _request({"type":"routine_save","routine_id":str(draft.id),"revision":_revision,"name":str(draft.name),"steps":draft.steps.duplicate()})); save_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; footer.add_child(save_button)
	_set_pending()
	Soundscape.attach_controls(self)

func _move_step(index: int,direction: int) -> void:
	var other := index+direction
	if other<0 or other>=draft.steps.size(): return
	var kind: String=draft.steps[index]; draft.steps[index]=draft.steps[other]; draft.steps[other]=kind
	_editor(); _focus_step(other)

func _focus_step(index: int) -> void:
	await get_tree().process_frame
	if index>=0 and index<step_controls.size() and is_instance_valid(step_controls[index]): step_controls[index].grab_focus(); scroll.ensure_control_visible(step_controls[index])
	elif is_instance_valid(add_button): add_button.grab_focus()

func _request(command: Dictionary) -> void:
	if not pending.is_empty(): return
	pending=command.duplicate(true); _before_tick=int(Session.state.tick); _acknowledged=false
	status.text="Waiting for the neighborhood…"; _set_pending()
	command_requested.emit(command)
	refresh(_member)

func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or intent!=pending: return
	status.text=message
	if ok: _acknowledged=true
	else: pending={}; _signature=""; _acknowledged=false
	refresh(_member)

func _set_pending() -> void:
	if draft.is_empty(): return
	var busy := not pending.is_empty()
	name_field.editable=not busy
	for index in range(step_controls.size()):
		step_controls[index].disabled=busy
		step_buttons[index].up.disabled=busy or index==0
		step_buttons[index].down.disabled=busy or index==step_controls.size()-1
		step_buttons[index].remove.disabled=busy
	add_button.disabled=busy or draft.steps.size()>=Routines.MAX_STEPS
	save_button.disabled=busy or not Routines.valid_steps(draft.steps); back_button.disabled=busy
	save_button.tooltip_text="Keep one to six activities before saving." if not Routines.valid_steps(draft.steps) else "Save this recipe without changing the current plan."

func _back() -> void:
	if not pending.is_empty(): return
	draft={}; draft_source={}; _signature=""; status.text=""; refresh(_member)

func escape() -> void:
	if not draft.is_empty() and pending.is_empty(): _back()
	else: closed.emit()

func _input(event: InputEvent) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and not is_ancestor_of(focused): return
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		escape(); get_viewport().set_input_as_handled()

func _restore_focus(id: String,kind: String,offset: int) -> void:
	if not draft.is_empty(): return
	scroll.scroll_vertical=offset
	if not is_visible_in_tree() or get_viewport().gui_get_focus_owner()!=null: return
	var target: Button=from_plan_button if kind=="capture" else new_button if kind=="new" else run_buttons.get(id) if kind=="run" else edit_buttons.get(id) if kind=="edit" else delete_buttons.get(id)
	if target==null or target.disabled: target=edit_buttons.get(id,new_button)
	if target!=null and not target.disabled: target.grab_focus()

func _clear() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()

func _label(value: String,size_value: int,color: Color=Style.TEXT) -> Label:
	var label := Label.new(); label.text=value; label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",color); return label

func _button(value: String,callback: Callable) -> Button:
	var button := Button.new(); button.text=value; button.add_theme_font_size_override("font_size",13); button.pressed.connect(callback); button.custom_minimum_size.y=32; Soundscape.attach_controls(button); return button
