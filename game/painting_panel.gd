extends VBoxContainer
signal command_requested(command: Dictionary)
signal display_requested(source: String)
const Paintings = preload("res://game/paintings.gd")
const Style = preload("res://game/style.gd")
var summary: Label
var artist: Label
var preview: Control
var progress: ProgressBar
var note: Label
var feedback: Label
var buttons: Dictionary={}
var hang_button: Button
var display_pending := false
var pending: Dictionary={}
var _acknowledged := false
var _next_action := 0
var _context := ""
var _lot := ""
var _object := ""
var _member := ""
var _options := {}
var _reply_error := ""
var _preview_subject := ""

func _ready() -> void:
	add_theme_constant_override("separation",6)
	summary=_label("",14,Style.GOLD); artist=_label("",12,Style.MUTED)
	preview=preload("res://game/painting_preview.gd").new(); preview.custom_minimum_size=Vector2(200,120); preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(preview)
	progress=ProgressBar.new(); progress.custom_minimum_size.y=10; progress.show_percentage=false
	progress.add_theme_stylebox_override("background",Style.box(Style.INK,3)); progress.add_theme_stylebox_override("fill",Style.box(Style.GREEN,3)); add_child(progress)
	for key: String in ["meadow","harbor","flowers","resume","sell"]:
		var button := Button.new(); button.custom_minimum_size.y=36; button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func(): _request(key))
		if Paintings.SUBJECTS.has(key):
			button.mouse_entered.connect(func(): _preview_subject=key; refresh(_lot,_object,_member))
			button.mouse_exited.connect(func(): _preview_subject=""; refresh(_lot,_object,_member))
			button.focus_entered.connect(func(): _preview_subject=key; refresh(_lot,_object,_member))
			button.focus_exited.connect(func(): _preview_subject=""; refresh(_lot,_object,_member))
		add_child(button); buttons[key]=button
	hang_button=Button.new(); hang_button.text="Hang on wall · Build mode"; hang_button.add_theme_font_size_override("font_size",12); hang_button.custom_minimum_size.y=32; add_child(hang_button)
	hang_button.pressed.connect(func(): display_requested.emit("easel:"+_object))
	note=_label("",12,Style.MUTED); feedback=_label("",12,Style.GOLD)
	Session.command_completed.connect(_completed); Soundscape.attach_controls(self)

func _label(text: String,font_size: int,color: Color) -> Label:
	var label := Label.new(); label.text=text; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label

func refresh(lot_id: String,object_id: String,member_id: String) -> void:
	_lot=lot_id; _object=object_id; _member=member_id
	var context := str([Session.role,Session.profile_id,lot_id,object_id,member_id])
	if context!=_context: pending={}; _acknowledged=false; _reply_error=""; _preview_subject=""; _context=context
	var lot: Dictionary=Session.state.lots.get(lot_id,{})
	var object: Dictionary=Session.world._object(lot,object_id) if not lot.is_empty() else {}
	var family: Dictionary=Session.state.families.get(Session.profile_id,{})
	var member: Dictionary=Session.world._member(family,member_id) if not family.is_empty() else {}
	if _acknowledged and not pending.is_empty() and int(member.get("next_action",0))>_next_action: pending={}; _acknowledged=false
	var exists: bool=object.get("kind")=="easel"
	for control: Control in [artist,preview,progress,note,feedback,hang_button]: control.visible=exists
	for button: Button in buttons.values(): button.visible=exists
	if not exists: summary.text="This easel is no longer here."; return
	var compact := get_viewport_rect().size.y<800
	preview.custom_minimum_size.y=82 if compact else 120
	for button: Button in buttons.values(): button.custom_minimum_size.y=32 if compact else 36
	var picture: Dictionary=object.painting
	var blank: bool=str(picture.subject).is_empty()
	var finished := Paintings.finished(picture)
	summary.text=Paintings.summary(picture)
	artist.text=Paintings.credit(picture); artist.visible=not artist.text.is_empty()
	preview.picture=picture
	if blank and Paintings.SUBJECTS.has(_preview_subject):
		preview.picture={"subject":_preview_subject,"progress":Paintings.DURATION}; summary.text="Preview · "+str(Paintings.SUBJECTS[_preview_subject])
	preview.queue_redraw()
	progress.visible=not blank and not finished; progress.value=float(picture.progress)/Paintings.DURATION*100.0
	note.text="Free supplies · 72 game minutes\nRestores fun and comfort." if blank else "Unfinished work keeps. Either resident in this household can continue it." if not finished else "Finished on day %d. Keep it here, hang it on a wall, or sell it for a fresh canvas." % int(picture.day)
	if lot.owner!=Session.profile_id: note.text="You can enjoy your neighbor's artwork. Only their household can paint or sell it."
	_options.clear()
	var unavailable := ""
	for key: String in buttons:
		var action := "start" if Paintings.SUBJECTS.has(key) else key
		var button: Button=buttons[key]
		button.visible=blank if action=="start" else not blank and (finished if action=="sell" else not finished)
		var option: Dictionary=Session.world.painting_option(Session.profile_id,member_id,lot_id,object_id,action,key if action=="start" else "")
		_options[key]=option
		button.text="Paint "+str(Paintings.SUBJECTS[key]).to_lower() if action=="start" else "Continue painting" if action=="resume" else "Sell painting · §%d" % Paintings.VALUE
		button.disabled=not option.ok or not pending.is_empty() or Session.role=="joining"
		button.tooltip_text=str(option.message) if not option.ok else str(option.label)+" · Queues for "+str(member.get("name","your resident"))
		if button.visible and not option.ok: unavailable=str(option.message)
	hang_button.visible=finished and lot.owner==Session.profile_id
	var planned := false
	for resident: Dictionary in family.get("members",[]):
		if resident.lot_id!=lot_id: continue
		var tasks: Array=resident.queue.duplicate(); tasks.append(resident.task)
		for task: Dictionary in tasks:
			if task.get("target_id")==object_id and task.has("paint_action"): planned=true
	hang_button.disabled=display_pending or not pending.is_empty() or planned or Session.role=="joining"
	hang_button.text="Entering build mode…" if display_pending else "Hang on wall · Build mode"
	hang_button.tooltip_text="Enter build mode to hang this picture. Your household pauses; the transfer is free and undoable."
	feedback.text="Waiting for the neighborhood…" if display_pending or not pending.is_empty() else _reply_error if not _reply_error.is_empty() else unavailable
	feedback.visible=not feedback.text.is_empty()

func _request(key: String) -> void:
	if not pending.is_empty() or not _options.get(key,{}).get("ok",false): return
	var action := "start" if Paintings.SUBJECTS.has(key) else key
	pending={"type":"painting","lot_id":_lot,"target_id":_object,"member_id":_member,"action":action,"subject":key if action=="start" else "","revision":_options[key].revision}
	_next_action=int(Session.world._member(Session.state.families[Session.profile_id],_member).next_action); _acknowledged=false; _reply_error=""
	refresh(_lot,_object,_member); command_requested.emit(pending.duplicate(true))

func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or pending!=intent: return
	if ok: _acknowledged=true
	else: pending={}; _acknowledged=false; _reply_error=message
	refresh(_lot,_object,_member)
