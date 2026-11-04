extends VBoxContainer
signal source_selected(source: String)
signal command_requested(command: Dictionary)
signal arrange_requested(source: String)
signal admire_requested(command: Dictionary)
const Art = preload("res://game/wall_art.gd")
const Paintings = preload("res://game/paintings.gd")
const Style = preload("res://game/style.gd")
var picker: OptionButton
var summary: Label
var credit: Label
var preview: Control
var note: Label
var store_button: Button
var easels: OptionButton
var return_button: Button
var arrange_button: Button
var admire_button: Button
var admire_hint: Label
var admire_pending: Dictionary={}
var _admire_ack := false
var _admire_next := 0
var _admire_error := ""
var _member := ""
var _building := false
var _pending := false
var _admire_option := {}
var actions: HBoxContainer
var _sources: Array[String]=[]
var _empty_easels: Array[String]=[]
var _source := ""
var _lot: Dictionary={}
var _list_key := ""
var _easel_key := ""

func _ready() -> void:
	add_theme_constant_override("separation",6)
	picker=OptionButton.new(); picker.fit_to_longest_item=false; picker.custom_minimum_size=Vector2(200,34); picker.add_theme_font_size_override("font_size",12); add_child(picker)
	picker.item_selected.connect(func(index): source_selected.emit(_sources[index]))
	summary=_label(14,Style.GOLD); credit=_label(12,Style.MUTED)
	preview=preload("res://game/painting_preview.gd").new(); preview.custom_minimum_size=Vector2(200,82); preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(preview)
	note=_label(12,Style.MUTED)
	admire_button=_button("Admire painting",_admire)
	admire_hint=_label(12,Style.MUTED)
	easels=OptionButton.new(); easels.fit_to_longest_item=false; easels.custom_minimum_size.y=32; easels.add_theme_font_size_override("font_size",12); add_child(easels)
	actions=HBoxContainer.new(); actions.add_theme_constant_override("separation",6); add_child(actions)
	store_button=_button("Store",func(): _request("art_store")); store_button.reparent(actions)
	store_button.tooltip_text="Keep this painting in the household collection. The wall stays in place."
	return_button=_button("Return to easel",func(): _request("art_return")); return_button.reparent(actions); return_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	arrange_button=_button("Arrange artwork · Build mode",func(): arrange_requested.emit(_source))
	Session.command_completed.connect(_admire_completed)
	Soundscape.attach_controls(self)

func _label(font_size: int,color: Color) -> Label:
	var label := Label.new(); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label

func _button(title: String,callback: Callable) -> Button:
	var button := Button.new(); button.text=title; button.add_theme_font_size_override("font_size",12); button.custom_minimum_size.y=32; button.pressed.connect(callback); add_child(button); return button

func refresh(lot: Dictionary,source: String,pending: bool,building: bool,member_id: String="") -> void:
	if _member!=member_id or _source!=source or _lot.get("id")!=lot.id: admire_pending={}; _admire_ack=false; _admire_error=""
	_lot=lot; _source=source; _member=member_id; _building=building; _pending=pending
	var entries := Art.sources(lot)
	var key := str(entries)
	if key!=_list_key:
		_list_key=key; picker.clear(); _sources.assign([""]); picker.add_item("Choose a finished painting")
		for id: String in entries:
			_sources.append(id); picker.add_item(str(Paintings.SUBJECTS[entries[id].picture.subject])+" · "+str(entries[id].location))
	picker.select(maxi(0,_sources.find(source))); picker.disabled=pending; picker.visible=building
	var chosen := Art.source(lot,source)
	var exists := not chosen.is_empty()
	var compact := building and get_viewport_rect().size.y<800
	summary.text=str(Paintings.SUBJECTS[chosen.picture.subject]) if exists else "Choose a finished canvas" if not entries.is_empty() else "Your collection starts at an easel"
	summary.visible=not compact or not exists
	credit.text=Paintings.credit(chosen.picture) if exists else ""; credit.visible=exists
	preview.visible=exists; preview.picture=chosen.get("picture",{}); preview.queue_redraw()
	preview.custom_minimum_size.y=48 if compact else 64 if get_viewport_rect().size.y<800 else 82
	var wall_source := exists and source.begins_with("art:")
	note.text="Choose a finished painting, then click a solid wall. Windows and other pictures keep their space."
	if exists: note.text=str(chosen.location)+" · Day %d\n" % int(chosen.picture.day)+("Click a clear wall to hang it. Free; one Undo restores the transfer." if building else "This picture belongs to the household.")
	if exists and compact: note.text="Day %d · Click a clear wall\nFree · Undo restores the transfer" % int(chosen.picture.day)
	elif entries.is_empty(): note.text="Finish a picture at a Daydream easel, then bring it here to hang. Room copies do not copy artwork."
	if exists and not building and get_viewport_rect().size.y<800: note.text=str(chosen.location)+" · Day %d" % int(chosen.picture.day)
	if not building and lot.building:
		summary.text="This home is under construction"
		note.text="Visitors return home while the house changes. Come back when construction is finished."
	if pending: note.text="Waiting for the neighborhood…"
	store_button.visible=building and wall_source and int(chosen.get("x",-1))>=0
	store_button.disabled=pending
	var empty := {}
	for object: Dictionary in lot.objects:
		if object.kind=="easel" and str(object.painting.subject).is_empty(): empty[str(object.id)]="Empty easel · %d, %d" % [object.x,object.y]
	var empty_key := str(empty)
	if empty_key!=_easel_key:
		var old := _empty_easels[easels.selected] if easels.selected>=0 and easels.selected<_empty_easels.size() else ""
		_easel_key=empty_key; _empty_easels.assign(empty.keys()); easels.clear()
		for id: String in _empty_easels: easels.add_item(empty[id])
		if not _empty_easels.is_empty(): easels.select(maxi(0,_empty_easels.find(old)))
	easels.visible=building and wall_source and empty.size()>1; easels.disabled=pending
	actions.visible=building and wall_source
	return_button.visible=building and wall_source; return_button.disabled=pending or empty.is_empty()
	return_button.tooltip_text="Place an empty easel first. Existing canvases are never replaced." if empty.is_empty() else "Return this picture to "+str(empty[_empty_easels[maxi(0,easels.selected)]]).to_lower()+". Keep or sell it in live mode."
	var family: Dictionary=Session.state.families.get(Session.profile_id,{})
	var member: Dictionary=Session.world._member(family,_member) if not family.is_empty() else {}
	if _admire_ack and not admire_pending.is_empty() and int(member.get("next_action",0))>_admire_next: admire_pending={}; _admire_ack=false
	admire_button.visible=not building and wall_source and int(chosen.get("x",-1))>=0
	admire_hint.visible=admire_button.visible
	_admire_option=Session.world.admire_option(Session.profile_id,_member,str(lot.id),str(chosen.get("art_id","")))
	admire_button.disabled=not _admire_option.ok or not admire_pending.is_empty() or pending or Session.role=="joining"
	admire_button.text="Waiting for the neighborhood…" if not admire_pending.is_empty() else "Admire painting"
	admire_button.tooltip_text="Queues for "+str(member.get("name","your resident"))+" · "+str(_admire_option.message)
	admire_hint.text=_admire_error if not _admire_error.is_empty() else str(_admire_option.message)
	if _admire_option.ok and _admire_error.is_empty(): admire_hint.text=str(member.name)+" · "+str(_admire_option.message)
	arrange_button.visible=not building and exists and lot.owner==Session.profile_id
	arrange_button.disabled=pending or Session.role=="joining"

func _request(type: String) -> void:
	var intent := {"type":type,"lot_id":str(_lot.id),"source":_source,"revision":int(_lot.revision)}
	if type=="art_return":
		if easels.selected<0 or easels.selected>=_empty_easels.size(): return
		intent.target_id=_empty_easels[easels.selected]
	command_requested.emit(intent)

func _admire() -> void:
	if not admire_pending.is_empty() or not _admire_option.get("ok",false): return
	admire_pending={"type":"admire_art","lot_id":str(_lot.id),"member_id":_member,"target_id":_source.trim_prefix("art:"),"x":int(_admire_option.x),"y":int(_admire_option.y)}
	_admire_next=int(Session.world._member(Session.state.families[Session.profile_id],_member).next_action)
	_admire_ack=false; _admire_error=""
	refresh(_lot,_source,_pending,_building,_member); admire_requested.emit(admire_pending.duplicate(true))

func _admire_completed(intent: Dictionary,ok: bool,message: String) -> void:
	if admire_pending.is_empty() or admire_pending!=intent: return
	if ok: _admire_ack=true
	else: admire_pending={}; _admire_ack=false; _admire_error=message
	refresh(_lot,_source,_pending,_building,_member)
