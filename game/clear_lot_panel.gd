extends VBoxContainer
var level := 0
signal command_requested(command: Dictionary)
signal tool_requested(kind: String)
signal focus_requested(cell: Vector2)
const Clear=preload("res://game/clear_lot.gd")
const Style=preload("res://game/style.gd")
var heading: Label
var quote: Label
var counts: Label
var keeps: Label
var losses: Label
var feedback: Label
var confirm: Button
var back: Button
var review: Button
var find: Button
var rebuild: HBoxContainer
var pending := {}
var plan := {}
var _lot := ""
var _ack := false
var _error := ""
func _ready() -> void:
	add_theme_constant_override("separation",8)
	heading=_label(15,Style.TEXT); quote=_label(15,Style.GOLD); counts=_label(12,Style.MUTED)
	keeps=_label(12,Style.GREEN); losses=_label(12,Color("eda58e")); feedback=_label(12,Style.GOLD)
	review=_button("Review changed lot",_review,self)
	find=_button("Find unfinished easel",func():
		if not plan.get("unfinished",[]).is_empty():
			var object: Dictionary=plan.unfinished[0]; focus_requested.emit(Vector2(object.x+0.5,object.y+0.5)),self)
	rebuild=HBoxContainer.new(); add_child(rebuild)
	_button("Saved rooms",func(): tool_requested.emit("saved_rooms"),rebuild)
	_button("Build room",func(): tool_requested.emit("room"),rebuild)
	Session.command_completed.connect(_completed); Soundscape.attach_controls(self)
func add_footer(parent: Node) -> void:
	confirm=_button("Clear lot",_request,parent)
	back=_button("‹ Keep lot / Catalog",func(): tool_requested.emit("floor"),parent)
	Soundscape.attach_controls(parent)
func _label(font_size: int,color: Color) -> Label:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label
func _button(value: String,action: Callable,parent: Node) -> Button:
	var button:=Button.new(); button.text=value; button.custom_minimum_size.y=32; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.add_theme_font_size_override("font_size",12)
	parent.add_child(button)
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var box: StyleBox=button.get_theme_stylebox(state).duplicate(); box.content_margin_top=6; box.content_margin_bottom=6; box.content_margin_left=8; box.content_margin_right=8; button.add_theme_stylebox_override(state,box)
	button.pressed.connect(action); return button
func refresh(lot_id: String) -> void:
	_lot=lot_id
	var lot: Dictionary=preload("res://game/storeys.gd").view(Session.state.lots.get(_lot,{}),level)
	if lot.is_empty() or confirm==null: return
	if _ack and not pending.is_empty() and int(lot.revision)>int(pending.revision):
		pending={}; _ack=false; plan={}; _error="Lot cleared. Undo restores the whole edit."
	if plan.is_empty(): plan=Clear.inspect(lot)
	var stale:=int(lot.revision)!=int(plan.revision)
	var empty:=Clear.empty(lot)
	var busy:=not pending.is_empty()
	heading.text="Ready to rebuild" if empty and not busy else "Clear “"+str(lot.name)+"”?"
	quote.text="Refund §"+_money(plan.refund)
	quote.tooltip_text="Balance after clearing §"+_money(int(lot.funds)+int(plan.refund))
	quote.visible=not empty or stale
	counts.text=_count(plan.floors,"floor tile")+" · "+_count(plan.walls,"wall")+" · "+_count(plan.doors,"door")+"\n"+_count(plan.windows,"window")+" · "+_count(plan.furnishings,"furnishing")
	counts.tooltip_text="Floors, walls and doors §%d · Windows §%d · Furnishings §%d. Each piece returns 60%% of its catalog price, rounded down. Decorative finishes have no separate refund." % [plan.structure_refund,plan.window_refund,plan.furniture_refund]
	counts.visible=not empty or stale
	var paintings: int=int(plan.stored)+plan.paintings.size()
	keeps.text="People & saved designs stay.\n"+_count(paintings,"painting")+" → collection" if paintings>0 else "People, collected art and saved designs stay."
	var contents: PackedStringArray=[]
	if plan.portions>0: contents.append(_count(plan.portions,"meal portion"))
	if plan.crops>0: contents.append(_count(plan.crops,"planted garden bed"))
	losses.text="Discard: "+" and ".join(contents)+"."
	losses.tooltip_text="Undo restores the exact food portions and planted crops."
	losses.visible=(plan.portions>0 or plan.crops>0) and not empty
	var current:=Clear.inspect(lot)
	feedback.text="Waiting for the neighborhood…" if busy else "This lot changed. Review its new contents before clearing." if stale else _error if not _error.is_empty() else str(current.message) if not current.ok else ""
	feedback.visible=not feedback.text.is_empty()
	review.visible=stale and not busy
	find.visible=not stale and not busy and not plan.unfinished.is_empty()
	rebuild.visible=empty and not busy
	back.text="‹ Catalog" if empty else "‹ Keep lot / Catalog"; back.disabled=busy
	confirm.text="Clearing…" if busy else "Clear lot · +§"+_money(plan.refund)
	confirm.tooltip_text=quote.tooltip_text+" · One Undo restores the whole lot and its contents."
	confirm.disabled=busy or stale or not current.ok or Session.role=="joining"
	confirm.visible=not empty or busy
func _review() -> void:
	if not pending.is_empty(): return
	plan={}; _error=""; refresh(_lot); call_deferred("_review_top")
func _review_top() -> void:
	await get_tree().process_frame
	var scroll:=get_parent().get_parent() as ScrollContainer
	if scroll!=null: scroll.scroll_vertical=0
func _request() -> void:
	if confirm.disabled or not pending.is_empty(): return
	pending={"type":"clear_lot","lot_id":_lot,"level":level,"revision":plan.revision,"refund":plan.refund}; _ack=false; _error=""
	refresh(_lot); command_requested.emit(pending.duplicate(true))
func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or intent!=pending: return
	if ok:
		_ack=true
		if is_visible_in_tree(): Soundscape.play_ui("build")
	else: pending={}; _ack=false; _error=message
	refresh(_lot)

func _count(amount: int,noun: String) -> String: return str(amount)+" "+noun+("" if amount==1 else "s")
func _money(value: int) -> String:
	var digits:=str(value); var result:=""
	for index in range(digits.length()):
		if index>0 and (digits.length()-index)%3==0: result+=","
		result+=digits[index]
	return result
