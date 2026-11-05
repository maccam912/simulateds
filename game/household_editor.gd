extends VBoxContainer
## Dedicated household creator. This entire mode edits a private draft.
const Style = preload("res://game/style.gd")
const Pastimes = preload("res://game/pastimes.gd")
const Appearance = preload("res://game/appearance.gd")
const Profile = preload("res://game/character_profile.gd")
const Household = preload("res://game/household_profile.gd")
const Studio = preload("res://game/character_studio.gd")
var draft: Dictionary
var family_name: LineEdit
var member_names: Array[LineEdit]=[]
var context_key := ""
var selected := 0
var occasion := "casual"
var section := 0
var studio: Control
var fields: VBoxContainer
var roster: HBoxContainer
var tabs: OptionButton
var scroll: ScrollContainer
var detail_panel: PanelContainer
var hidden_fields: Control
var name_label: Label
var age_label: Label
var add_button: Button
var status: Label
var controls := {}
var swatches: Array[Dictionary]=[]
var original_count := 0
var pending := false
var _copy_source := ""
const SECTIONS := ["Identity", "Face & hair", "Body & voice", "Outfits", "Personality", "Family"]

func setup(family: Dictionary, context: String) -> void:
	draft=family.duplicate(true); context_key=context; original_count=draft.members.size()
	draft.relations=draft.get("relations",[]).duplicate(true)
	size_flags_vertical=Control.SIZE_EXPAND_FILL; size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	var heading := HBoxContainer.new(); heading.add_theme_constant_override("separation",16); add_child(heading)
	heading.add_child(_label("Edit household",26,Style.TEXT))
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(spacer)
	heading.add_child(_label("Household",13))
	family_name=LineEdit.new(); family_name.text=str(draft.name); family_name.max_length=64
	family_name.custom_minimum_size.x=240; family_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(family_name)
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation",14); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(body)
	var preview_column := VBoxContainer.new(); preview_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(preview_column)
	var preview_panel := PanelContainer.new(); preview_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL; preview_column.add_child(preview_panel)
	preview_panel.add_theme_stylebox_override("panel",Style.box(Color("c8c4ae"),8))
	studio=Studio.new(); studio.custom_minimum_size=Vector2(180,220); preview_panel.add_child(studio)
	var view_controls := HBoxContainer.new(); preview_column.add_child(view_controls)
	view_controls.add_theme_constant_override("separation",6)
	view_controls.add_child(_button("↶",func(): studio.yaw-=PI/4,"Turn left"))
	view_controls.add_child(_button("↷",func(): studio.yaw+=PI/4,"Turn right"))
	var framing := OptionButton.new(); framing.add_item("Full body"); framing.add_item("Face")
	framing.item_selected.connect(func(value): studio.set_close_up(value==1)); view_controls.add_child(framing); controls.framing=framing
	var lighting := OptionButton.new(); lighting.add_item("Daylight"); lighting.add_item("Evening")
	lighting.item_selected.connect(func(value): studio.set_night(value==1)); view_controls.add_child(lighting); controls.lighting=lighting
	var animate := CheckButton.new(); animate.text="Idle"; animate.button_pressed=true
	animate.toggled.connect(func(value): studio.paused=not value); view_controls.add_child(animate)
	var identity := HBoxContainer.new(); preview_column.add_child(identity)
	name_label=_label("",21,Style.TEXT); name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; identity.add_child(name_label)
	age_label=_label("",13); identity.add_child(age_label)
	var roster_scroll := ScrollContainer.new(); roster_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; roster_scroll.custom_minimum_size.y=56; preview_column.add_child(roster_scroll)
	roster=HBoxContainer.new(); roster.add_theme_constant_override("separation",6); roster_scroll.add_child(roster)
	var hint := _label("Drag to turn · Scroll to zoom",12); preview_column.add_child(hint)
	detail_panel=PanelContainer.new(); detail_panel.custom_minimum_size.x=380; body.add_child(detail_panel)
	detail_panel.add_theme_stylebox_override("panel",Style.box(Color("20353b"),6,Style.EDGE))
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,14)
	detail_panel.add_child(margin)
	var detail := VBoxContainer.new(); detail.add_theme_constant_override("separation",12); margin.add_child(detail)
	tabs=OptionButton.new(); tabs.custom_minimum_size.y=44
	for title: String in SECTIONS: tabs.add_item(title)
	tabs.item_selected.connect(select_section); detail.add_child(tabs)
	scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus=true; detail.add_child(scroll)
	fields=VBoxContainer.new(); fields.add_theme_constant_override("separation",10); fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(fields)
	status=_label("",13,Style.GOLD); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.add_child(status)
	hidden_fields=Control.new(); hidden_fields.hide(); add_child(hidden_fields)
	for member: Dictionary in draft.members: _prepare_member(member)
	resized.connect(_responsive)
	_refresh_roster(); _build_fields(); _preview(); _responsive()
	Soundscape.attach_controls(self)

func _prepare_member(member: Dictionary) -> void:
	member.appearance=Appearance.of(member).duplicate(true)
	member.favorite=Pastimes.of(member)
	member.character=Profile.of(member).duplicate(true)
	var field := LineEdit.new(); field.text=str(member.name); field.max_length=32
	field.placeholder_text="Resident name"; field.custom_minimum_size.y=42
	var index := member_names.size()
	field.text_changed.connect(func(value):
		draft.members[index].name=value
		_refresh_identity(); _refresh_roster())
	member_names.append(field); hidden_fields.add_child(field)

func _responsive() -> void:
	if detail_panel!=null: detail_panel.custom_minimum_size.x=clampf(size.x*0.34,300,440)

func _label(value: String, font_size: int=14, color: Color=Style.MUTED) -> Label:
	var label := Label.new(); label.text=value; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); return label

func _note(value: String) -> void:
	var label := _label(value,13); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; fields.add_child(label)

func _heading(value: String) -> void:
	fields.add_child(_label(value,18,Style.TEXT))

func _button(value: String, action: Callable, tooltip: String="") -> Button:
	var button := Button.new(); button.text=value; button.tooltip_text=tooltip; button.custom_minimum_size.y=44; button.pressed.connect(action); return button

func _profile() -> Dictionary:
	return draft.members[selected].character

func select_member(index: int) -> void:
	if pending: return
	selected=index; _copy_source=""; status.text=""; _refresh_roster(); _build_fields(); _preview()

func select_section(index: int) -> void:
	section=index; tabs.select(index); _copy_source=""; status.text=""; _build_fields()

func _refresh_identity() -> void:
	name_label.text=member_names[selected].text
	name_label.tooltip_text=name_label.text
	age_label.text=Profile.AGES[int(_profile().age)]

func _refresh_roster() -> void:
	for child in roster.get_children(): roster.remove_child(child); child.queue_free()
	for index in range(draft.members.size()):
		var title := member_names[index].text if index<member_names.size() else str(draft.members[index].name)
		var button := _button(title,select_member.bind(index)); button.custom_minimum_size.x=90; button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		button.text=title.left(15); button.tooltip_text=title+" · "+Profile.AGES[int(draft.members[index].character.age)]
		button.toggle_mode=true; button.button_pressed=index==selected; button.disabled=pending
		if index==selected: button.add_theme_color_override("font_color",Style.GREEN)
		roster.add_child(button)
	add_button=_button("+ Resident",add_member,"Add a resident to this draft (up to eight)")
	add_button.disabled=pending or draft.members.size()>=Profile.MAX_MEMBERS; roster.add_child(add_button)

func add_member() -> void:
	if pending or draft.members.size()>=Profile.MAX_MEMBERS: return
	var member := {"id":Household.new_id(draft,draft.members.size()),"name":"New resident"}
	draft.members.append(member); _prepare_member(member); select_member(draft.members.size()-1)
	select_section(0); member_names[selected].grab_focus(); member_names[selected].select_all()

func remove_draft_member() -> void:
	if pending or selected<original_count: return
	var removed: String=draft.members[selected].id
	member_names[selected].queue_free(); member_names.remove_at(selected); draft.members.remove_at(selected)
	draft.relations=draft.relations.filter(func(link): return link.a!=removed and link.b!=removed)
	# Rebuild new IDs and callbacks after removal; established IDs never change.
	for index in range(original_count,draft.members.size()):
		var old: String=draft.members[index].id; var next := Household.new_id(draft,index)
		draft.members[index].id=next
		for link: Dictionary in draft.relations:
			if link.a==old: link.a=next
			if link.b==old: link.b=next
	for field: LineEdit in member_names:
		if field.get_parent()!=hidden_fields: field.reparent(hidden_fields)
		field.queue_free()
	member_names.clear()
	for member: Dictionary in draft.members: _prepare_member(member)
	select_member(maxi(0,selected-1))

func _build_fields() -> void:
	for field: LineEdit in member_names:
		if field.get_parent()!=hidden_fields: field.reparent(hidden_fields)
	for child in fields.get_children(): fields.remove_child(child); child.queue_free()
	controls.clear(); swatches.clear(); scroll.scroll_vertical=0
	match section:
		0: _identity_fields()
		1: _look_fields()
		2: _body_fields()
		3: _outfit_fields()
		4: _personality_fields()
		5: _family_fields()
	Soundscape.attach_controls(fields)
	if pending: _set_controls_pending(fields,true)

func _identity_fields() -> void:
	_heading("Meet your resident")
	fields.add_child(_label("Name")); member_names[selected].reparent(fields)
	_option("Pronouns",Profile.PRONOUNS,int(_profile().pronouns),func(value): _set_profile("pronouns",value),"pronouns")
	_option("Life stage",Profile.AGES,int(_profile().age),func(value): _set_profile("age",value),"age")
	_note("Choose their stage of life. Residents keep this age until you change it here.")
	if int(_profile().age)==0: _note("Babies rest in a bassinet at home. Their needs stay comfortable; hands-on baby care is not part of this mode yet.")
	_option("Favorite pastime",Pastimes.ORDER.map(func(key): return Pastimes.LABELS[key]),Pastimes.ORDER.find(draft.members[selected].favorite),func(value): _choose_pastime(selected,value),"favorite")
	if selected>=original_count: fields.add_child(_button("Remove new resident",remove_draft_member))

func _look_fields() -> void:
	_heading("Face & hair")
	_palette("Skin tone","skin",Appearance.SKIN,Appearance.LABELS.skin,int(draft.members[selected].appearance.skin),func(value): _choose(selected,"skin",value))
	_palette("Eye color","eyes",Profile.EYES,Profile.EYE_NAMES,int(_profile().eyes),func(value): _set_profile("eyes",value))
	_option("Hair style",Profile.HAIRSTYLES,int(_profile().hairstyle),func(value): _set_profile("hairstyle",value),"hairstyle")
	_palette("Hair color","hair",Appearance.HAIR,Appearance.LABELS.hair,int(draft.members[selected].appearance.hair),func(value): _choose(selected,"hair",value))
	_slider("Face width","face","Narrow","Broad")
	_slider("Nose shape","nose","Small","Full")

func _body_fields() -> void:
	_heading("Shape & stature")
	_slider("Height","height","Short","Tall")
	_slider("Body fullness","build","Slender","Full")
	_slider("Shoulders","shoulders","Narrow","Broad")
	_slider("Hips","hips","Narrow","Broad")
	_heading("Voice")
	_option("Voice character",Profile.VOICES,int(_profile().voice),func(value): _set_profile("voice",value),"voice")
	_slider("Pitch","pitch","Low","High")
	fields.add_child(_button("▶ Hear voice",func(): studio.preview_voice()))
	_note("An original, wordless greeting.")

func _outfit_fields() -> void:
	_heading("A wardrobe for every day")
	_option("Occasion",Profile.OCCASION_NAMES,Profile.OCCASIONS.find(occasion),func(value): occasion=Profile.OCCASIONS[value]; _copy_source=""; _build_fields(); _preview(),"occasion")
	var outfit: Dictionary=_profile().outfits[occasion]
	_option("Top",Profile.TOPS,int(outfit.top),func(value): _set_outfit("top",value),"top")
	_palette("Top color","top_color",Profile.COLORS,Profile.COLOR_NAMES,int(outfit.top_color),func(value): _set_outfit("top_color",value))
	_option("Bottom",Profile.BOTTOMS,int(outfit.bottom),func(value): _set_outfit("bottom",value),"bottom")
	_palette("Bottom color","bottom_color",Profile.COLORS,Profile.COLOR_NAMES,int(outfit.bottom_color),func(value): _set_outfit("bottom_color",value))
	_option("Shoes",Profile.SHOES,int(outfit.shoes),func(value): _set_outfit("shoes",value),"shoes")
	_palette("Shoe color","shoe_color",Profile.COLORS,Profile.COLOR_NAMES,int(outfit.shoe_color),func(value): _set_outfit("shoe_color",value))
	_option("Accessory",Profile.ACCESSORIES,int(outfit.accessory),func(value): _set_outfit("accessory",value),"accessory")
	_palette("Accent color","accessory_color",Profile.COLORS,Profile.COLOR_NAMES,int(outfit.accessory_color),func(value): _set_outfit("accessory_color",value))
	_option("Fabric detail",Profile.PATTERNS,int(outfit.pattern),func(value): _set_outfit("pattern",value),"pattern")
	var wearing := CheckButton.new(); wearing.text="Wear this in the neighborhood"; wearing.button_pressed=_profile().wearing==occasion
	wearing.toggled.connect(func(value):
		if value: _profile().wearing=occasion
		else: wearing.set_pressed_no_signal(true))
	fields.add_child(wearing); controls.wearing=wearing
	_note("Each occasion keeps its own outfit. Choose which one to wear when you return home.")
	_option("Copy an outfit from",["Choose an occasion"]+Profile.OCCASION_NAMES,0,func(value): _copy_source="" if value==0 else Profile.OCCASIONS[value-1],"copy_source")
	fields.add_child(_button("Copy into this occasion",func():
		if _copy_source.is_empty(): status.text="Choose an occasion to copy first."; return
		_profile().outfits[occasion]=_profile().outfits[_copy_source].duplicate(true)
		_copy_source=""; status.text="Outfit copied into "+Profile.OCCASION_NAMES[Profile.OCCASIONS.find(occasion)]+"."; _build_fields(); _preview()))

func _personality_fields() -> void:
	_heading("Personality")
	_note("Pick up to three traits. Traits and interests gently guide everyday choices; your plans and urgent needs come first.")
	var count := _label("%d / 3 traits" % _profile().traits.size(),14,Style.GREEN); fields.add_child(count); controls.trait_count=count
	for trait_name: String in Profile.TRAITS:
		var check := CheckBox.new(); check.text=trait_name; check.button_pressed=trait_name in _profile().traits; check.custom_minimum_size.y=34
		check.toggled.connect(func(value):
			var traits: Array=_profile().traits
			if value and traits.size()>=3: check.set_pressed_no_signal(false); status.text="Choose up to three traits."; return
			if value: traits.append(trait_name)
			else: traits.erase(trait_name)
			count.text="%d / 3 traits" % traits.size(); status.text="")
		fields.add_child(check); controls["trait_"+trait_name]=check
	_heading("Likes & dislikes")
	for interest: String in Profile.INTERESTS:
		var choice := 1 if interest in _profile().likes else 2 if interest in _profile().dislikes else 0
		_option(interest,["Neutral","Like","Dislike"],choice,func(value):
			_profile().likes.erase(interest); _profile().dislikes.erase(interest)
			if value==1: _profile().likes.append(interest)
			elif value==2: _profile().dislikes.append(interest),"interest_"+interest)

func _family_fields() -> void:
	_heading("Family connections")
	_note("Set how "+member_names[selected].text+" relates to each housemate. Partners are adults; a parent or grandparent must be in an older life stage.")
	for index in range(draft.members.size()):
		if index==selected: continue
		var other: Dictionary=draft.members[index]
		var value := 0
		for link: Dictionary in draft.relations:
			if link.a==draft.members[selected].id and link.b==other.id: value=int(link.kind)
			elif link.b==draft.members[selected].id and link.a==other.id: value=Profile.REVERSE[int(link.kind)]
		_option("With "+member_names[index].text,Profile.RELATIONS,value,func(choice): _set_relation(index,choice),"relation_"+str(index))
	_note("Family ties are saved together. Friendship still grows through time spent together.")
	fields.add_child(_button("+ Add a resident",add_member))

func _set_relation(other: int, kind: int) -> void:
	var a: String=draft.members[selected].id; var b: String=draft.members[other].id
	draft.relations=draft.relations.filter(func(link): return not ((link.a==a and link.b==b) or (link.b==a and link.a==b)))
	if kind>0: draft.relations.append({"a":a,"b":b,"kind":kind})
	status.text="" if Profile.relations_valid(draft.relations,draft.members) else "This family connection conflicts with their ages or another relationship. Change it before saving."

func _option(title: String, choices: Array, value: int, changed: Callable, key: String) -> void:
	fields.add_child(_label(title))
	var option := OptionButton.new(); option.fit_to_longest_item=false; option.custom_minimum_size.y=44
	option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for choice: String in choices: option.add_item(choice)
	option.select(value); option.item_selected.connect(changed); fields.add_child(option); controls[key]=option

func _slider(title: String, key: String, low: String, high: String) -> void:
	var row := HBoxContainer.new(); fields.add_child(row)
	var caption := _label(title); caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(caption)
	var value := _label(str(int(_profile()[key])),13,Style.TEXT); row.add_child(value)
	var slider := HSlider.new(); slider.min_value=0; slider.max_value=100; slider.step=1; slider.value=_profile()[key]; slider.custom_minimum_size.y=30
	slider.value_changed.connect(func(number): value.text=str(int(number)); _set_profile(key,int(number)))
	fields.add_child(slider); controls[key]=slider
	var ends := HBoxContainer.new(); fields.add_child(ends)
	var left := _label(low,11); left.size_flags_horizontal=Control.SIZE_EXPAND_FILL; ends.add_child(left); ends.add_child(_label(high,11))

func _palette(title: String, key: String, colors: Array, names: Array, selected_color: int, changed: Callable) -> void:
	var label := _label(title+" · "+str(names[selected_color])); fields.add_child(label)
	var grid := GridContainer.new(); grid.columns=6; grid.add_theme_constant_override("h_separation",5); grid.add_theme_constant_override("v_separation",5); fields.add_child(grid)
	var buttons: Array[Button]=[]
	for index in range(colors.size()):
		var button := Button.new(); button.custom_minimum_size=Vector2(44,44); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.tooltip_text=str(names[index]); button.text="✓" if index==selected_color else ""
		var box := Style.box(colors[index],4,Style.TEXT if index==selected_color else colors[index].darkened(0.3)); box.set_border_width_all(2)
		button.add_theme_stylebox_override("normal",box); button.add_theme_stylebox_override("hover",Style.box(colors[index].lightened(0.12),4,Style.TEXT))
		button.add_theme_color_override("font_color",Style.INK if Color(colors[index]).get_luminance()>0.4 else Style.TEXT)
		buttons.append(button); grid.add_child(button)
		button.pressed.connect(func():
			changed.call(index); label.text=title+" · "+str(names[index])
			for cursor in range(buttons.size()):
				buttons[cursor].text="✓" if cursor==index else ""
				var updated := Style.box(colors[cursor],4,Style.TEXT if cursor==index else colors[cursor].darkened(0.3)); updated.set_border_width_all(2); buttons[cursor].add_theme_stylebox_override("normal",updated))
		swatches.append({"button":button,"member":selected,"key":key,"choice":index,"color":colors[index],"names":names,"label":label,"title":title})

func _refresh_swatches() -> void:
	for entry: Dictionary in swatches:
		var key: String=entry.key
		var value: int=int(draft.members[selected].appearance[key]) if key in ["skin","hair"] else int(_profile().eyes) if key=="eyes" else int(_profile().outfits[occasion][key])
		entry.button.text="✓" if value==int(entry.choice) else ""
		entry.label.text=entry.title+" · "+str(entry.names[value])
		var box := Style.box(entry.color,4,Style.TEXT if value==int(entry.choice) else entry.color.darkened(0.3)); box.set_border_width_all(2)
		entry.button.add_theme_stylebox_override("normal",box)

func _set_profile(key: String, value: Variant) -> void:
	if pending: return
	_profile()[key]=value
	if controls.has(key):
		if controls[key] is OptionButton: controls[key].select(int(value))
		elif controls[key] is Slider: controls[key].set_value_no_signal(value)
	# The small 2D People portrait uses the closest of the four legacy silhouettes.
	if key=="hairstyle": draft.members[selected].appearance.style=[0,1,2,3,1,0,0,2,1,3][int(value)]
	_refresh_swatches(); _preview()
	if key=="age": _refresh_roster(); _build_fields()

func _set_outfit(key: String, value: int) -> void:
	if pending: return
	_profile().outfits[occasion][key]=value
	if controls.has(key) and controls[key] is OptionButton: controls[key].select(value)
	if key=="top_color" and occasion=="casual": draft.members[selected].appearance.shirt=mini(value,7)
	_refresh_swatches(); _preview()

func _choose(index: int, key: String, choice: int) -> void:
	if pending: return
	draft.members[index].appearance[key]=choice
	if key=="style": draft.members[index].character.hairstyle=choice
	if key=="shirt": draft.members[index].character.outfits.casual.top_color=choice
	if index==selected: _refresh_swatches(); _preview()

func _choose_pastime(index: int, choice: int) -> void:
	draft.members[index].favorite=Pastimes.ORDER[choice]

func _preview() -> void:
	_refresh_identity(); studio.show_member(draft.members[selected],occasion)

func payload() -> Dictionary:
	var members: Array=[]
	for index in range(draft.members.size()):
		var member: Dictionary=draft.members[index]
		members.append({"id":member.id,"name":member_names[index].text,"appearance":member.appearance.duplicate(true),"favorite":member.favorite,"character":member.character.duplicate(true)})
	return {"type":"household_edit","name":family_name.text,"members":members,"relations":draft.relations.duplicate(true),"revision":int(draft.get("identity_revision",0))}

func set_pending(value: bool) -> void:
	pending=value; family_name.editable=not pending
	for field in member_names: field.editable=not pending
	_set_controls_pending(self,pending)

func _set_controls_pending(node: Node, value: bool) -> void:
	for child in node.get_children():
		if child is BaseButton: child.disabled=value
		if child is Slider: child.editable=not value
		_set_controls_pending(child,value)
