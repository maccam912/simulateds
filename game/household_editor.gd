extends VBoxContainer
const Style = preload("res://game/style.gd")
const Appearance = preload("res://game/appearance.gd")
const Portrait = preload("res://game/resident_portrait.gd")
var draft: Dictionary
var family_name: LineEdit
var member_names: Array[LineEdit]=[]
var portraits: Array[Control]=[]
var hair_controls: Array[OptionButton]=[]
var swatches: Array[Dictionary]=[]
var context_key := ""

func setup(family: Dictionary, context: String) -> void:
	draft=family.duplicate(true); context_key=context
	add_theme_constant_override("separation",12)
	var family_row := HBoxContainer.new(); add_child(family_row)
	family_row.add_child(_label("Household name",14))
	family_name=LineEdit.new(); family_name.text=str(draft.name); family_name.max_length=64
	family_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL; family_row.add_child(family_name)
	var cards := HBoxContainer.new(); cards.add_theme_constant_override("separation",14); add_child(cards)
	for index in range(draft.members.size()):
		var member: Dictionary=draft.members[index]
		member.appearance=Appearance.of(member).duplicate()
		var card := PanelContainer.new(); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cards.add_child(card)
		var style := Style.box(Color("1e3238"),6,Style.EDGE)
		style.content_margin_left=10; style.content_margin_right=10; style.content_margin_top=10; style.content_margin_bottom=10
		card.add_theme_stylebox_override("panel",style)
		var body := VBoxContainer.new(); body.add_theme_constant_override("separation",8); card.add_child(body)
		body.add_child(_label("RESIDENT %d" % (index+1),11))
		var name := LineEdit.new(); name.text=str(member.name); name.max_length=32
		name.placeholder_text="Resident name"; body.add_child(name); member_names.append(name)
		var portrait := Portrait.new(); portrait.look=member.appearance.duplicate(); body.add_child(portrait); portraits.append(portrait)
		var hair_row := HBoxContainer.new(); body.add_child(hair_row); hair_row.add_child(_label("Hair style",13))
		var hair := OptionButton.new(); hair_controls.append(hair); hair.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hair_row.add_child(hair)
		for label: String in Appearance.STYLES: hair.add_item(label)
		hair.select(int(member.appearance.style)); hair.item_selected.connect(func(choice): _choose(index,"style",choice))
		for key: String in ["skin","hair","shirt"]:
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation",4); body.add_child(row)
			var label := _label("Clothes" if key=="shirt" else key.capitalize(),12); label.custom_minimum_size.x=48; row.add_child(label)
			var colors: Array={"skin":Appearance.SKIN,"hair":Appearance.HAIR,"shirt":Appearance.SHIRT}[key]
			for choice in range(colors.size()):
				var button := Button.new(); button.custom_minimum_size=Vector2(25,28)
				button.tooltip_text=Appearance.LABELS[key][choice]
				button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
				button.pressed.connect(func(): _choose(index,key,choice))
				row.add_child(button)
				swatches.append({"button":button,"member":index,"key":key,"choice":choice,"color":colors[choice]})
	_refresh_swatches()
	Soundscape.attach_controls(self)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new(); label.text=text; label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Style.MUTED)
	return label

func _choose(index: int, key: String, choice: int) -> void:
	draft.members[index].appearance[key]=choice
	if key=="style": hair_controls[index].select(choice)
	portraits[index].look=draft.members[index].appearance.duplicate()
	portraits[index].queue_redraw()
	_refresh_swatches()

func _refresh_swatches() -> void:
	for entry: Dictionary in swatches:
		var selected: bool=int(draft.members[entry.member].appearance[entry.key])==int(entry.choice)
		var button: Button=entry.button
		button.text="✓" if selected else ""
		var style := Style.box(entry.color,3,Style.TEXT if selected else entry.color.darkened(0.3))
		style.set_border_width_all(2 if selected else 1)
		style.content_margin_left=1; style.content_margin_right=1; style.content_margin_top=1; style.content_margin_bottom=1
		button.add_theme_stylebox_override("normal",style)
		button.add_theme_stylebox_override("hover",style)
		for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
			button.add_theme_color_override(state,Style.INK if Color(entry.color).get_luminance()>0.4 else Style.TEXT)

func payload() -> Dictionary:
	var members: Array=[]
	for index in range(draft.members.size()):
		members.append({"id":draft.members[index].id,"name":member_names[index].text,"appearance":draft.members[index].appearance.duplicate()})
	return {"type":"household_edit","name":family_name.text,"members":members,"revision":int(draft.get("identity_revision",0))}

func set_pending(pending: bool) -> void:
	family_name.editable=not pending
	for field in member_names: field.editable=not pending
	_set_controls_pending(self,pending)

func _set_controls_pending(node: Node, pending: bool) -> void:
	for child in node.get_children():
		if child is BaseButton: child.disabled=pending
		_set_controls_pending(child,pending)
