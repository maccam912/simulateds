extends VBoxContainer
var level := 0
signal command_requested(command: Dictionary)
signal place_requested(id: String, revision: int)
const Library=preload("res://game/room_library.gd")
const Copy=preload("res://game/room_copy.gd")
const Thumbnail=preload("res://game/room_thumbnail.gd")
const Profile=preload("res://game/household_profile.gd")
const Style=preload("res://game/style.gd")
var name_input: LineEdit
var submit: Button
var cancel: Button
var form: VBoxContainer
var form_title: Label
var feedback: Label
var description: Label
var rows: VBoxContainer
var buttons := {}
var pending := {}
var _ack := false
var _error := ""
var _lot := ""
var _source := Vector2i(-1,-1)
var _capture := {}
var _capture_key := ""
var _saved_key := ""
var _row_signature := ""
var _edit_id := ""
var _edit_kind := ""
var _edit_revision := -1
func _ready() -> void:
	add_theme_constant_override("separation",8)
	description=_label("Keep up to four room designs. Saving is free; placing pays for the room.",12,Style.MUTED,self)
	form=VBoxContainer.new(); add_child(form)
	form_title=_label("",13,Style.GOLD,form)
	name_input=LineEdit.new(); name_input.max_length=32; name_input.placeholder_text="Name this room"; name_input.custom_minimum_size=Vector2(200,34); form.add_child(name_input)
	name_input.text_changed.connect(func(_value): _refresh_controls())
	name_input.text_submitted.connect(func(_value): _submit())
	var actions:=HBoxContainer.new(); form.add_child(actions)
	submit=_button("Save design",_submit,actions); cancel=_button("Cancel",_cancel_edit,actions)
	feedback=_label("",12,Style.GOLD,self)
	rows=VBoxContainer.new(); rows.add_theme_constant_override("separation",12); add_child(rows)
	Session.command_completed.connect(_completed); Soundscape.attach_controls(self)
func _label(value: String,font_size: int,color: Color,parent: Node) -> Label:
	var label:=Label.new(); label.text=value; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=150; parent.add_child(label); return label
func _button(value: String,action: Callable,parent: Node) -> Button:
	var button:=Button.new(); button.text=value; button.add_theme_font_size_override("font_size",12); button.custom_minimum_size.y=32; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(button)
	for key: String in ["normal","hover","pressed","disabled","focus"]:
		var box: StyleBox=button.get_theme_stylebox(key).duplicate(); box.content_margin_left=7; box.content_margin_right=7; button.add_theme_stylebox_override(key,box)
	button.pressed.connect(action); return button
func _board() -> Dictionary: return Session.state.families.get(Session.profile_id,{}).get("room_library",Library.create())
func refresh(lot_id: String,source: Vector2i,selected: String) -> void:
	_lot=lot_id; _source=source
	var lot: Dictionary=preload("res://game/storeys.gd").view(Session.state.lots.get(lot_id,{}),level)
	_capture=Copy.capture(lot,source) if source.x>=0 else {}
	var key:=str([lot_id,source,lot.get("revision",0)]) if source.x>=0 else ""
	if key!=_capture_key:
		_capture_key=key
		if _edit_id.is_empty(): name_input.text=""
	if _ack and not pending.is_empty() and int(_board().revision)>int(pending.library_revision):
		if pending.type=="blueprint_save": _saved_key=str([pending.lot_id,Vector2i(pending.source_x,pending.source_y),pending.revision])
		pending={}; _ack=false; _edit_id=""; _edit_kind=""; _error="Design saved." if not _saved_key.is_empty() and _saved_key==_capture_key else "Library updated."
	var signature:=str(_board())
	if signature!=_row_signature:
		_row_signature=signature
		for child: Node in rows.get_children(): rows.remove_child(child); child.queue_free()
		buttons.clear()
		if _board().entries.is_empty(): _label("No saved rooms yet. Choose Copy room in the catalog, select an enclosed room, then Save room…",13,Style.MUTED,rows)
		for entry: Dictionary in _board().entries:
			var id: String=entry.id
			var card:=VBoxContainer.new(); rows.add_child(card)
			var top:=HBoxContainer.new(); top.add_theme_constant_override("separation",8); card.add_child(top)
			var thumbnail:=Thumbnail.new(); thumbnail.design=entry.layout; top.add_child(thumbnail)
			var words:=VBoxContainer.new(); words.size_flags_horizontal=Control.SIZE_EXPAND_FILL; top.add_child(words)
			_label(entry.name,14,Style.TEXT,words); _label(Library.summary(entry.layout),11,Style.MUTED,words)
			var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",4); card.add_child(actions)
			buttons[id]={"place":_button("Place",func(): place_requested.emit(id,int(_board().revision)),actions),"rename":_button("Rename",func(): _edit(id,"blueprint_rename"),actions),"remove":_button("Remove",func(): _edit(id,"blueprint_delete"),actions)}
		Soundscape.attach_controls(rows)
	for id: String in buttons:
		buttons[id].place.text="Selected" if id==selected else "Place"
		for button: Button in buttons[id].values(): button.disabled=not pending.is_empty() or Session.role=="joining"
	_refresh_controls()
func _refresh_controls() -> void:
	var editing:=not _edit_id.is_empty()
	var captured: bool=_capture.get("ok",false)
	form.visible=editing or (captured and _saved_key!=_capture_key)
	form_title.text="Remove “"+str(Library.find(_board(),_edit_id).get("name","this design"))+"”?\nBuilt rooms stay." if _edit_kind=="blueprint_delete" else "Rename room" if editing else "Save this room · Free"
	name_input.visible=_edit_kind!="blueprint_delete"; name_input.editable=pending.is_empty()
	submit.text="Remove design" if _edit_kind=="blueprint_delete" else "Rename" if editing else "Saved" if _saved_key==_capture_key and not _capture_key.is_empty() else "Save design"
	cancel.visible=editing; cancel.disabled=not pending.is_empty()
	var stale:=editing and _edit_revision!=int(_board().revision)
	submit.disabled=not pending.is_empty() or Session.role=="joining" or stale or (_edit_kind!="blueprint_delete" and not Profile.valid_name(name_input.text,32)) or (not editing and (not captured or _board().entries.size()>=Library.MAX_ROOMS or _saved_key==_capture_key))
	feedback.text="Waiting for the neighborhood…" if not pending.is_empty() else "The library changed. Cancel, then review the room again." if stale else "Library full. Remove a design to save this room." if captured and not editing and _board().entries.size()>=Library.MAX_ROOMS and _saved_key!=_capture_key else _error
	feedback.visible=not feedback.text.is_empty()
	description.text="%d / 4 designs · Free to save\nFresh furnishings; food, crops and original art stay behind." % _board().entries.size()
	description.tooltip_text="Keeps the layout, furniture colors, finishes and windows. Placing charges the previewed price. Saved designs survive discarding a building draft."
	if captured and _saved_key!=_capture_key: description.text+="\nSaved designs survive discarding a draft."
func _edit(id: String,kind: String) -> void:
	if not pending.is_empty(): return
	_edit_id=id; _edit_kind=kind; _edit_revision=int(_board().revision); _error=""
	name_input.text=str(Library.find(_board(),id).get("name","")); _refresh_controls()
	call_deferred("_focus_form")
func _focus_form() -> void:
	var scroll:=get_parent().get_parent() as ScrollContainer
	if scroll!=null: scroll.ensure_control_visible(form)
	if name_input.visible: name_input.grab_focus(); name_input.select_all()
	else: submit.grab_focus()
func _cancel_edit() -> void:
	_edit_id=""; _edit_kind=""; _error=""; name_input.text=""; _refresh_controls()
func _submit() -> void:
	if submit.disabled or not form.visible: return
	pending={"type":_edit_kind if not _edit_id.is_empty() else "blueprint_save","lot_id":_lot,"level":level,"library_revision":_edit_revision if not _edit_id.is_empty() else int(_board().revision)}
	if _edit_id.is_empty(): pending.merge({"source_x":_source.x,"source_y":_source.y,"revision":Session.state.lots[_lot].revision,"name":name_input.text.strip_edges()})
	else:
		pending.blueprint_id=_edit_id
		if _edit_kind=="blueprint_rename": pending.name=name_input.text.strip_edges()
	_ack=false; _error=""; _refresh_controls(); command_requested.emit(pending.duplicate(true))
func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or intent!=pending: return
	if ok: _ack=true
	else: pending={}; _ack=false; _error=message
	refresh(_lot,_source,"")
