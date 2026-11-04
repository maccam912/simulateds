extends VBoxContainer
## A local draft over replicated mail. Success is established by accepted state.
signal arrange_requested(source: String)
const HomeNews = preload("res://game/home_news.gd")
const Mailbox = preload("res://game/mailbox.gd")
const Art = preload("res://game/wall_art.gd")
const ArtGifts = preload("res://game/art_gifts.gd")
const Paintings = preload("res://game/paintings.gd")
const Style = preload("res://game/style.gd")
var view := "inbox"
var selected := ""
var draft := ""
var recipient := ""
var gift := 0
var art_source := ""
var art_id := ""
var pending: Dictionary = {}
var _acknowledged := false
var inbox_button: Button
var write_button: Button
var news_button: Button
var news_read_button: Button
var news_inbox_button: Button
var action_row: HBoxContainer
var recipient_input: OptionButton
var note_input: LineEdit
var gift_input: OptionButton
var send_button: Button
var claim_button: Button
var archive_button: Button
var arrange_button: Button
var gift_hint: Label
var art_preview: Control
var art_credit: Label
var art_row: HBoxContainer
var open_buttons: Dictionary = {}
var body: VBoxContainer
var feedback: Label
var compose_hint: Label
var action_hint: Label
var _signature := ""
var _context := ""
var _blocked := false

func _ready() -> void:
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	_context=_context_key()
	if HomeNews.pending(_family()): view="news"
	var navigation := HBoxContainer.new(); add_child(navigation)
	inbox_button=_button("Inbox",func(): view="inbox"; _build()); navigation.add_child(inbox_button)
	write_button=_button("Write a postcard",func(): view="compose"; _build()); navigation.add_child(write_button)
	news_button=_button("Home news",func(): view="news"; _build()); navigation.add_child(news_button)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	body=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",10); scroll.add_child(body)
	action_hint=_label("",13,Style.MUTED); add_child(action_hint); action_hint.hide()
	action_row=HBoxContainer.new(); add_child(action_row); action_row.hide()
	feedback=_label("",13,Style.GOLD); add_child(feedback)
	Session.world_changed.connect(refresh)
	Session.status_changed.connect(func(_status): refresh())
	Session.command_completed.connect(_completed)
	_build(); refresh()

func _context_key() -> String:
	return str(Session.role)+":"+str(Session.profile_id)+":"+str(Session.state.families.get(Session.profile_id,{}).get("home_lot",""))

func _family() -> Dictionary:
	return Session.state.families.get(Session.profile_id,{})

func _box() -> Dictionary:
	return _family().get("mailbox",{})

func _label(text: String, font_size: int=14, color: Color=Style.TEXT) -> Label:
	var label := Label.new(); label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new(); button.text=text; button.pressed.connect(action)
	Soundscape.attach_controls(button)
	return button

func _build() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	for child in action_row.get_children(): action_row.remove_child(child); child.queue_free()
	action_row.hide()
	action_hint.hide(); action_hint.text=""; compose_hint=null
	open_buttons.clear(); note_input=null; recipient_input=null; gift_input=null; send_button=null; claim_button=null; archive_button=null; news_read_button=null; news_inbox_button=null
	arrange_button=null; gift_hint=null; art_preview=null; art_credit=null; art_row=null
	if view=="news": _news()
	elif view=="compose": _compose()
	elif view=="read": _read()
	else: _inbox()
	_update_controls()

func _inbox() -> void:
	var entries: Array=_box().get("items",[])
	if entries.is_empty():
		body.add_child(_label("A quiet mailbox",24,Style.GOLD))
		body.add_child(_label("Postcards from your neighbors will wait here, even when you play at different times."))
		body.add_child(_label("Leave a little hello",17))
		body.add_child(_label("Write a postcard to another household. Add a small gift if you like, or just send a friendly note.",14,Style.MUTED))
	else:
		body.add_child(_label("%d of %d postcards · Archive read mail to make room." % [entries.size(),Mailbox.CAPACITY],12,Style.MUTED))
		for entry: Dictionary in entries:
			var card := PanelContainer.new(); body.add_child(card)
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); card.add_child(row)
			var info := VBoxContainer.new(); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(info)
			info.add_child(_label(("NEW · " if not entry.read else "")+str(Session.state.families[entry.from].name),15,Style.GOLD if not entry.read else Style.TEXT))
			var waiting := " · Painting waiting" if entry.has("art") else " · §%d gift waiting" % int(entry.gift)
			info.add_child(_label("Day %d%s" % [int(entry.day),waiting if not entry.claimed else ""],12,Style.MUTED))
			var open := _button("Open",func(): selected=str(entry.id); view="read"; _build(); _request({"type":"mail_read","id":selected}))
			open_buttons[entry.id]=open; row.add_child(open)

func _compose() -> void:
	var fields:=HBoxContainer.new(); fields.add_theme_constant_override("separation",12); body.add_child(fields)
	var to:=VBoxContainer.new(); to.size_flags_horizontal=Control.SIZE_EXPAND_FILL; to.add_theme_constant_override("separation",6); fields.add_child(to)
	var gifts:=VBoxContainer.new(); gifts.size_flags_horizontal=Control.SIZE_EXPAND_FILL; gifts.add_theme_constant_override("separation",6); fields.add_child(gifts)
	to.add_child(_label("To a neighbor",16))
	recipient_input=OptionButton.new(); recipient_input.fit_to_longest_item=false; to.add_child(recipient_input)
	recipient_input.item_selected.connect(func(index): recipient=str(recipient_input.get_item_metadata(index)); _update_controls())
	body.add_child(_label("Your note",16))
	note_input=LineEdit.new(); note_input.max_length=Mailbox.NOTE_LIMIT; note_input.placeholder_text="Lovely seeing your house take shape. Tea soon?"; note_input.text=draft; body.add_child(note_input)
	note_input.text_changed.connect(func(value): draft=value; _update_controls())
	gifts.add_child(_label("A little something",16))
	gift_input=OptionButton.new(); gift_input.fit_to_longest_item=false; gifts.add_child(gift_input)
	gift_input.item_selected.connect(func(index):
		var choice: Dictionary=gift_input.get_item_metadata(index)
		if choice.is_empty(): return
		gift=int(choice.get("gift",0)); art_source=str(choice.get("source","")); art_id=str(choice.get("art_id","")); _update_controls())
	art_row=HBoxContainer.new(); art_row.add_theme_constant_override("separation",16); body.add_child(art_row)
	art_preview=preload("res://game/painting_preview.gd").new(); art_preview.custom_minimum_size=Vector2(140,86); art_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; art_row.add_child(art_preview)
	art_credit=_label("",13,Style.MUTED); art_credit.size_flags_horizontal=Control.SIZE_EXPAND_FILL; art_credit.size_flags_vertical=Control.SIZE_SHRINK_CENTER; art_row.add_child(art_credit)
	_refresh_gifts()
	compose_hint=action_hint; compose_hint.show()
	send_button=_button("Send postcard",_send); send_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; action_row.add_child(send_button); action_row.show()
	write_button.tooltip_text="One postcard to each household per day. Recipients can read it and collect a gift whenever they return."
	_refresh_recipients()

func _refresh_gifts() -> void:
	if not is_instance_valid(gift_input): return
	gift_input.clear()
	for amount: int in Mailbox.GIFTS:
		gift_input.add_item("Just the postcard · Free" if amount==0 else "§%d household gift" % amount,amount)
		gift_input.set_item_metadata(gift_input.item_count-1,{"gift":amount})
	var home: Dictionary=Session.state.lots.get(_family().get("home_lot",""),{})
	var entries := Art.sources(home) if not home.is_empty() else {}
	var selected_index := Mailbox.GIFTS.find(gift) if art_source.is_empty() else -1
	for key: String in entries:
		var chosen: Dictionary=entries[key]; var index := gift_input.item_count
		gift_input.add_item(str(Paintings.SUBJECTS[chosen.picture.subject])+" · "+str(chosen.location))
		gift_input.set_item_metadata(index,{"gift":0,"source":key,"art_id":str(chosen.art_id)})
		if key==art_source and chosen.art_id==art_id: selected_index=index
	if selected_index<0:
		selected_index=gift_input.item_count; gift_input.add_item("Selected painting changed · Choose again"); gift_input.set_item_metadata(selected_index,{})
	gift_input.select(selected_index)

func _refresh_recipients() -> void:
	if not is_instance_valid(recipient_input): return
	recipient_input.clear()
	for id: String in Session.state.families:
		if id==Session.profile_id: continue
		var index := recipient_input.item_count
		recipient_input.add_item(str(Session.state.families[id].name)); recipient_input.set_item_metadata(index,id)
		if id==recipient: recipient_input.select(index)
	if recipient_input.item_count>0:
		if not Session.state.families.has(recipient) or recipient==Session.profile_id or recipient.is_empty(): recipient_input.select(0)
		recipient=str(recipient_input.get_item_metadata(recipient_input.selected))
	else: recipient=""

func _read() -> void:
	var entry := Mailbox.item(_box(),selected)
	if entry.is_empty(): view="inbox"; _inbox(); return
	var paper := PanelContainer.new()
	var paper_style := Style.box(Color("eee6cf"),5,Color("ad9e76")); paper_style.content_margin_left=24; paper_style.content_margin_right=24; paper_style.content_margin_top=20; paper_style.content_margin_bottom=20
	paper.add_theme_stylebox_override("panel",paper_style); body.add_child(paper)
	var lines := VBoxContainer.new(); lines.add_theme_constant_override("separation",16); paper.add_child(lines)
	lines.add_child(_label("LINDEN GROVE  /  NEIGHBORHOOD POST",11,Color("64735b")))
	lines.add_child(_label("From "+str(Session.state.families[entry.from].name),20,Style.INK))
	if entry.has("art"):
		lines.add_theme_constant_override("separation",10)
		var artwork := HBoxContainer.new(); artwork.add_theme_constant_override("separation",16); lines.add_child(artwork)
		var preview := preload("res://game/painting_preview.gd").new(); preview.picture=entry.art.picture; preview.custom_minimum_size=Vector2(140,82); preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; artwork.add_child(preview)
		var caption := VBoxContainer.new(); caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL; caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER; artwork.add_child(caption)
		caption.add_child(_label(str(Paintings.SUBJECTS[entry.art.picture.subject]),17,Style.INK))
		caption.add_child(_label(Paintings.credit(entry.art.picture),13,Color("64735b")))
	lines.add_child(_label(str(entry.note),22,Color("3c4940")))
	lines.add_child(_label("Day %d" % int(entry.day),12,Color("64735b")))
	if entry.has("art"):
		if entry.claimed:
			action_hint.text="Painting collected · Yours to keep, hang, or give onward."; action_hint.show()
			var home: Dictionary=Session.state.lots[_family().home_lot]
			if home.get("artworks",{}).has(entry.art.id):
				arrange_button=_button("Hang this painting · Build mode",func(): arrange_requested.emit("art:"+str(entry.art.id))); action_row.add_child(arrange_button)
		else:
			gift_hint=action_hint; gift_hint.show()
			claim_button=_button("Collect painting",func(): _request({"type":"mail_claim","id":selected})); action_row.add_child(claim_button)
	elif int(entry.gift)>0:
		if entry.claimed: body.add_child(_label("§%d gift collected. Thank you, neighbor." % int(entry.gift),14,Style.GREEN))
		else:
			claim_button=_button("Collect §%d gift" % int(entry.gift),func(): _request({"type":"mail_claim","id":selected})); action_row.add_child(claim_button)
	archive_button=_button("Archive postcard",func(): _request({"type":"mail_archive","id":selected})); action_row.add_child(archive_button); action_row.show()
	archive_button.tooltip_text="Read the postcard and collect its gift first. Archived postcards are removed."

func _send() -> void:
	if not pending.is_empty() or _blocked: return
	var intent := {"type":"mail_send","recipient":recipient,"note":draft,"gift":gift,"sequence":int(_box().get("next_sent",1))}
	if not art_source.is_empty(): intent.art_source=art_source; intent.art_id=art_id; intent.revision=Session.state.lots[_family().home_lot].revision
	_request(intent)

func _request(command: Dictionary) -> void:
	if not pending.is_empty() or _blocked: return
	pending=command.duplicate(true); _acknowledged=false; feedback.text="Waiting for the neighborhood…"; _update_controls()
	Session.command(command)
	refresh()

func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or pending!=intent: return
	feedback.text=message
	if not ok: pending.clear(); _acknowledged=false; _update_controls()
	else: _acknowledged=true; refresh()

func refresh() -> void:
	if _context_key()!=_context:
		_blocked=true; feedback.text="The session changed. Close and reopen Mail."; _update_controls(); return
	if not pending.is_empty() and _acknowledged:
		var entry := Mailbox.item(_box(),str(pending.get("id","")))
		var done := false
		match pending.type:
			"mail_send": done=int(_box().get("next_sent",1))>int(pending.sequence)
			"mail_read": done=not entry.is_empty() and entry.read
			"mail_claim": done=not entry.is_empty() and entry.claimed
			"mail_archive": done=entry.is_empty()
			"news_read": done=int(_family().home_news.report.get("id",0))==int(pending.revision) and not HomeNews.pending(_family())
		if done:
			if pending.type=="mail_send": draft=""; gift=0; art_source=""; art_id=""; view="inbox"; feedback.text="Postcard delivered. It will be waiting when they return."
			if pending.type=="mail_read": feedback.text="Postcard opened."
			if pending.type=="mail_claim": feedback.text="Painting added to your collection. Thank you, neighbor." if entry.has("art") else "Collected §%d. Thank you, neighbor." % int(entry.get("gift",0))
			if pending.type=="news_read": feedback.text="Home news marked as read. The recap stays here."
			if pending.type=="mail_archive": view="inbox"; feedback.text="Postcard archived."
			pending.clear(); _acknowledged=false; _signature=""; Soundscape.play_ui("confirm")
	var signature := str(_box())+str(Session.state.day)+str(_family().get("home_news",{}).get("report",{}))
	for family: Dictionary in Session.state.families.values():
		signature+=str([family.id,family.name,family.mailbox.items.size(),Session.state.lots[family.home_lot].funds,Session.state.lots[family.home_lot].building])
	var home: Dictionary=Session.state.lots.get(_family().get("home_lot",""),{})
	if not home.is_empty(): signature+=str(Art.sources(home))+str(home.revision)
	if signature!=_signature:
		_signature=signature
		if view=="compose": _refresh_recipients(); _refresh_gifts()
		else: _build()
	_update_controls()

func _update_controls() -> void:
	var busy := _blocked or not pending.is_empty()
	inbox_button.text="Inbox · %d" % Mailbox.unread(_box())
	inbox_button.disabled=busy; write_button.disabled=busy; news_button.disabled=busy
	news_button.text="Home news · new" if HomeNews.pending(_family()) else "Home news"
	if is_instance_valid(news_inbox_button): news_inbox_button.disabled=busy
	if is_instance_valid(news_read_button): news_read_button.disabled=busy or not HomeNews.pending(_family())
	for button: Button in open_buttons.values(): button.disabled=busy
	if is_instance_valid(arrange_button): arrange_button.disabled=busy or Session.role=="joining"
	if is_instance_valid(claim_button): claim_button.disabled=busy or not Mailbox.item(_box(),selected).get("read",false)
	if is_instance_valid(gift_hint):
		var option := ArtGifts.claim_option(Session.state,Session.profile_id,Mailbox.item(_box(),selected).art)
		gift_hint.text=str(option.message)
		claim_button.disabled=claim_button.disabled or not option.ok
	if is_instance_valid(archive_button):
		var entry := Mailbox.item(_box(),selected)
		archive_button.disabled=busy or not entry.get("read",false) or not entry.get("claimed",false)
	if not is_instance_valid(note_input): return
	note_input.editable=not busy; recipient_input.disabled=busy or recipient_input.item_count==0; gift_input.disabled=busy
	var reason := ""
	var home: Dictionary=Session.state.lots.get(_family().get("home_lot",""),{})
	var art_option := ArtGifts.send_option(Session.state,Session.profile_id,{"art_source":art_source,"art_id":art_id,"revision":home.get("revision",0)}) if not art_source.is_empty() else {}
	var chosen := Art.source(home,art_source) if not art_source.is_empty() else {}
	art_preview.visible=not chosen.is_empty() and chosen.art_id==art_id; art_credit.visible=art_preview.visible; art_row.visible=art_preview.visible
	if art_preview.visible:
		art_preview.picture=chosen.picture; art_preview.queue_redraw()
		art_credit.text=str(Paintings.SUBJECTS[chosen.picture.subject])+"\n"+Paintings.credit(chosen.picture)+"\n"+str(chosen.location)
	if recipient.is_empty(): reason="Another household needs to join before you can send mail."
	elif Mailbox.sent_today(_box(),recipient,int(Session.state.day)): reason="A postcard is already waiting from you today. More tomorrow."
	elif Session.state.families[recipient].mailbox.items.size()>=Mailbox.CAPACITY: reason="Their mailbox is full. Wait for them to archive a read postcard."
	elif gift>0 and home.get("building",false): reason="Finish construction before sending a gift. A plain postcard is free."
	elif gift>int(home.get("funds",0)): reason="Choose a gift your household can afford."
	elif not art_source.is_empty() and not art_option.ok: reason=str(art_option.message)
	elif not Mailbox.valid_note(draft): reason="Write a short note to send."
	compose_hint.text=reason if not reason.is_empty() else "%d / %d characters · Gift charged when sent" % [draft.length(),Mailbox.NOTE_LIMIT] if gift>0 else "%d / %d characters · Free delivery" % [draft.length(),Mailbox.NOTE_LIMIT]
	if reason.is_empty() and not art_source.is_empty(): compose_hint.text="%d / %d characters · The original painting leaves your home when sent." % [draft.length(),Mailbox.NOTE_LIMIT]
	send_button.disabled=busy or not reason.is_empty()

func _news() -> void:
	var report: Dictionary=_family().get("home_news",{}).get("report",{})
	if report.is_empty():
		body.add_child(_label("A place to catch up",24,Style.GOLD))
		body.add_child(_label("After time away, your household’s recap will wait here. It records neighborhood time, allowance received, and postcards delivered."))
		body.add_child(_label("The host needs to stay running for time to pass. If the whole neighborhood stops, it waits for you.",14,Style.MUTED))
		return
	body.add_child(_label("While you were away",24,Style.GOLD))
	body.add_child(_label(HomeNews.elapsed(int(report.minutes)),17))
	body.add_child(_label("Recorded while your household was away." if report.pending else "Your most recent recap · already read",12,Style.MUTED))
	body.add_child(_label("§%d allowance received" % int(report.allowance),19,Style.GREEN))
	body.add_child(_label("Already included in your household funds. Gifts are separate.",13,Style.MUTED))
	if int(report.postcards)>0:
		body.add_child(_label("%d postcard%s delivered during your time away" % [int(report.postcards),"" if int(report.postcards)==1 else "s"],16))
		if int(report.gifts)>0: body.add_child(_label("Those postcards included §%d in gifts. Collect unclaimed gifts in the Inbox." % int(report.gifts),13,Style.MUTED))
	else: body.add_child(_label("No postcards arrived during this time away.",14,Style.MUTED))
	if report.construction: body.add_child(_label("An unfinished building draft was discarded when you left. Your last committed home was kept.",14,Style.GOLD))
	body.add_child(_label("Your household used caretaker rules. Wishes, learned hobbies, and friendships were kept.",14,Style.MUTED))
	var waiting := Mailbox.unread(_box())
	var gifts := 0
	var paintings := 0
	for entry: Dictionary in _box().get("items",[]):
		if not entry.claimed: gifts+=int(entry.gift)
		if not entry.claimed and entry.has("art"): paintings+=1
	body.add_child(_label("Waiting now: %d unread postcard%s · §%d uncollected gifts" % [waiting,"" if waiting==1 else "s",gifts],14))
	if paintings>0: body.add_child(_label("%d painting%s waiting to collect" % [paintings,"" if paintings==1 else "s"],14,Style.GREEN))
	action_row.show()
	news_inbox_button=_button("Open Inbox",func(): view="inbox"; _build()); action_row.add_child(news_inbox_button)
	news_read_button=_button("Mark recap as read",func(): _request({"type":"news_read","revision":int(report.id)})); action_row.add_child(news_read_button)
