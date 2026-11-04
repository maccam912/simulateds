extends VBoxContainer
signal command_requested(command: Dictionary)
signal easel_requested
signal back_requested
const Jobs=preload("res://game/art_commissions.gd")
const Paintings=preload("res://game/paintings.gd")
const Style=preload("res://game/style.gd")
const Catalog=preload("res://game/catalog.gd")
var home_label: Label
var heading: Label
var subject: Label
var preview: Control
var detail: Label
var note: Label
var feedback: Label
var originals: VBoxContainer
var history: VBoxContainer
var cancel_button: Button
var confirm: Button
var back: Button
var review_buttons := {}
var review := {}
var pending := {}
var _ack := false
var _error := ""
var _signature := ""
var _context := ""
var _board := {}
var _terms := {}
var _has_easel := false

func _ready() -> void:
	add_theme_constant_override("separation",6)
	home_label=_label(self,11,Style.MUTED); heading=_label(self,14,Style.TEXT); subject=_label(self,14,Style.GOLD)
	preview=preload("res://game/painting_preview.gd").new(); preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(preview)
	detail=_label(self,12,Style.MUTED); note=_label(self,12,Style.MUTED); feedback=_label(self,12,Style.GOLD)
	originals=VBoxContainer.new(); originals.add_theme_constant_override("separation",8); add_child(originals)
	cancel_button=_button(self,"Put commission aside",func(): _request("commission_cancel"))
	cancel_button.tooltip_text="No fee. Your artwork stays, and the same request remains available."
	history=VBoxContainer.new(); add_child(history)
	Session.command_completed.connect(_completed); Soundscape.attach_controls(self)

func add_footer(parent: Node) -> void:
	confirm=_button(parent,"Accept commission",_confirm)
	back=_button(parent,"‹ Activities",func():
		if not leave_review(): back_requested.emit())
	Soundscape.attach_controls(parent)

func _label(parent: Node,font_size: int,color: Color) -> Label:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; parent.add_child(label); return label
func _button(parent: Node,text_value: String,action: Callable) -> Button:
	var button:=Button.new(); button.text=text_value; button.custom_minimum_size.y=32; button.add_theme_font_size_override("font_size",12)
	button.pressed.connect(action); parent.add_child(button); return button
func _clear(parent: Node) -> void:
	for child: Node in parent.get_children(): parent.remove_child(child); child.queue_free()

func refresh() -> void:
	if confirm==null: return
	var context:=str(Session.profile_id)+":"+str(Session.world_generation)
	if context!=_context: _context=context; review={}; pending={}; _ack=false; _error=""; _signature=""
	var family: Dictionary=Session.state.families.get(Session.profile_id,{})
	if family.is_empty(): return
	var home: Dictionary=Session.state.lots[family.home_lot]
	_board=family.commissions; _terms=Jobs.offer(Session.profile_id,_board)
	if _ack and not pending.is_empty() and int(_board.revision)>int(pending.commission_revision):
		pending={}; _ack=false; review={}
	var rows:=Jobs.candidates(Session.state,Session.profile_id)
	_has_easel=home.objects.any(func(object): return object.kind=="easel")
	var signature:=str([_board,home.revision,home.building,home.name,home.funds,rows,review,pending,_error,Session.state.day,Session.role,_has_easel])
	if signature==_signature: return
	_signature=signature
	var active: bool=not _board.active.is_empty(); var busy:=not pending.is_empty(); var reviewing:=not review.is_empty()
	var finished_today: bool=not active and int(_board.completed_day)==int(Session.state.day)
	home_label.text="For "+str(home.name)
	heading.text=str(_terms.client)
	subject.text=str(Paintings.SUBJECTS[_terms.subject])+" · §%d" % int(_terms.reward)
	preview.visible=reviewing or (not active and not finished_today); preview.custom_minimum_size.y=66 if get_viewport_rect().size.y<800 else 100
	preview.picture=review.picture if reviewing else {"subject":_terms.subject,"progress":Paintings.DURATION}; preview.queue_redraw()
	detail.text=Paintings.credit(review.picture)+"\n"+str(review.location) if reviewing else str(_terms.request)
	note.text="This original leaves your home.\nDelivery cannot be undone." if reviewing else "No deadline · No fee.\nExisting originals welcome."
	if finished_today:
		var delivered: Dictionary=Jobs.OFFERS[_board.history[0].offer]
		heading.text=str(delivered.client); subject.text="Delivered · §%d earned" % int(delivered.reward)
		detail.text="Your original has a new home."
		note.text="Today's commission is complete.\nA new request is available tomorrow."
	var option:=Jobs.delivery_option(Session.state,Session.profile_id,review.intent) if reviewing else {}
	feedback.text="Waiting for the neighborhood…" if busy else str(option.message) if reviewing and not option.ok else _error
	feedback.visible=not feedback.text.is_empty()
	_clear(originals); review_buttons.clear(); _clear(history)
	if active and not reviewing:
		var caption:=_label(originals,12,Style.GREEN); caption.text="Matching originals · %d" % rows.size()
		if rows.is_empty():
			var empty:=_label(originals,12,Style.MUTED); empty.text="No finished original at home yet. Either housemate can paint this subject."
		for row: Dictionary in rows:
			var card:=VBoxContainer.new(); originals.add_child(card)
			var info:=_label(card,11,Style.MUTED); info.text=Paintings.credit(row.picture)+"\n"+str(row.location)
			var button:=_button(card,"Review this original",func(): _review(row))
			button.disabled=busy or not row.available or Session.role=="joining"; button.tooltip_text=str(row.message)
			review_buttons[row.intent.art_source]=button
	cancel_button.visible=active and not reviewing; cancel_button.disabled=busy or Session.role=="joining"
	if not reviewing and not _board.history.is_empty():
		var label:=_label(history,11,Style.MUTED); label.text="RECENT DELIVERIES"
		for entry: Dictionary in _board.history:
			var terms: Dictionary=Jobs.OFFERS[entry.offer]
			var receipt:=_label(history,11,Style.MUTED); receipt.text="Day %d · %s · §%d\n%s" % [int(entry.day),str(terms.client),int(terms.reward),str(entry.credit)]
	confirm.text="Waiting…" if busy else "Deliver original · §%d" % int(_terms.reward) if reviewing else "View home easel" if active and _has_easel else "Build an easel · §%d" % int(Catalog.ITEMS.easel.cost) if active else "More tomorrow" if finished_today else "Accept commission · §%d" % int(_terms.reward)
	confirm.disabled=busy or Session.role=="joining" or (not option.ok if reviewing else bool(home.building) if active else not Jobs.accept_status(_board,int(Session.state.day)).is_empty())
	confirm.tooltip_text="Finish construction to use the easel." if active and not reviewing and home.building else "Opens the easel without choosing a painting." if active and not reviewing and _has_easel else "Opens Build & buy with the easel selected." if active and not reviewing else Jobs.accept_status(_board,int(Session.state.day)) if not active else ""
	back.text="‹ Keep this painting" if reviewing else "‹ Activities"; back.disabled=busy

func _review(row: Dictionary) -> void:
	if not pending.is_empty(): return
	review=row.duplicate(true); _error=""; refresh(); call_deferred("_top")
func leave_review() -> bool:
	if review.is_empty() or not pending.is_empty(): return false
	review={}; _error=""; refresh(); call_deferred("_top"); return true
func _top() -> void:
	await get_tree().process_frame
	var scroll:=get_parent().get_parent() as ScrollContainer
	if scroll!=null: scroll.scroll_vertical=0
func _confirm() -> void:
	if confirm.disabled or not pending.is_empty(): return
	if not review.is_empty(): _request("commission_deliver")
	elif not _board.active.is_empty(): easel_requested.emit()
	else: _request("commission_accept")
func _request(type: String) -> void:
	if not pending.is_empty(): return
	pending=review.intent.duplicate(true) if type=="commission_deliver" and not review.is_empty() else {"type":type,"commission_revision":int(_board.revision),"offer":str(_terms.id)}
	_ack=false; _error=""; refresh(); command_requested.emit(pending.duplicate(true))
func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or pending!=intent: return
	if ok: _ack=true
	else: pending={}; _ack=false
	_error="" if ok else message; refresh()
