extends VBoxContainer
## Reopenable help that leads into ordinary controls; never mutates a world.
signal action_requested(action: String)
const Style = preload("res://game/style.gd")
var tabs: TabContainer
var action_buttons: Dictionary = {}
var binding_values: Dictionary = {}
var context_hint: Label

func _ready() -> void:
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	tabs=TabContainer.new(); tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(tabs)
	var first := _page("First day")
	_card(first,"01 · Meet your household","Select a resident at the lower left. Edit gives each resident a name, a look, and a favorite pastime.",[["household","Meet your household"]])
	_card(first,"02 · A little care","Click a need bar to plan a useful activity. Your orders take priority; autonomy looks after residents between your plans.",[["care","Open care suggestions"]])
	_card(first,"03 · Something to enjoy","Wishes offer small goals and a journal. Reading, gardening, and cooking develop lasting hobbies. Nothing expires while you are away.",[["wishes","See wishes"],["hobbies","Find a hobby"]])
	_card(first,"04 · Make it home","Move furniture for free, decorate a room, or build an addition. Your household waits safely while you build.",[["build","Open build mode"]])
	var building := _page("Building")
	_card(building,"Start with a room","Choose Room and click two opposite corners. The preview includes floors, walls, a doorway, and the price. Rotate changes the door side.",[["build","Open build mode"]])
	_card(building,"Find a place for everything","Search by a name or use: sleep, meal, book. Green previews are valid. Keep a route to the front gate and enough space to use each furnishing.",[["catalog","Browse the catalog"],["move","Rearrange furniture"]])
	_card(building,"Your own colors","Floor and wall finishes decorate existing surfaces. Choose two corners; only changed tiles cost money. Click the same tile twice for one tile.",[["decorate","Browse finishes"]])
	_card(building,"Change your mind","Undo restores an edit and its exact cost; Redo reapplies it. Discard draft restores the whole house. Finish building checks that the home remains usable.",[])
	_card(building,"Keep a neighborhood","The host owns shared saves. Saved games keep the last finished house; an unfinished construction draft is discarded when you leave.",[["save","Save neighborhood"]])
	var neighbors := _page("Neighbors")
	_card(neighbors,"Together, at your own pace","Host or join from Play together. Each household has its own lot. One person can build while another cares for their family.",[["connect","Play together"]])
	_card(neighbors,"Drop in for a catch-up","Visit an open lot from Neighborhood or People. Chats build friendships. If an owner starts construction, visitors return home safely.",[["people","Find your neighbors"]])
	_card(neighbors,"Leave a little kindness","Mail can hold a postcard and an optional gift for someone to find later. Delivery stays in the neighborhood until they return.",[["mail","Open the mailbox"]])
	_card(neighbors,"The neighborhood clock","The host must stay running for life to continue. Away households get forgiving care and keep their wishes, hobbies, and friendships. If the entire host stops, the world waits. Shared menus never pause everyone else.",[])
	var controls := _page("Controls")
	controls.add_child(_text("YOUR KEY BINDINGS",12,Style.GOLD))
	var grid := GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",22); grid.add_theme_constant_override("v_separation",9); controls.add_child(grid)
	for action: String in Preferences.ACTION_NAMES:
		var label := _text(str(Preferences.ACTION_NAMES[action]),14); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_child(label)
		var key := _text("",14,Style.GREEN); grid.add_child(key); binding_values[action]=key
	_action_row(controls,[["bindings","Edit key bindings"]])
	_card(controls,"Mouse & building shortcuts","Click: walk, use furniture, or place the selected item. Scroll: zoom. Middle-drag: pan. Ctrl/Cmd+F: search the catalog; Enter: select its first result. Ctrl/Cmd+Z: undo. Ctrl/Cmd+Shift+Z or Ctrl+Y: redo.",[])
	_card(controls,"Always a way back","Escape clears a search or unfinished placement before closing a tray, then opens the game menu. F1 always opens the developer console; try help or rosebud. Gameplay shortcuts wait while you type.",[])
	context_hint=_text("",12,Style.GOLD); context_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(context_hint)
	refresh_bindings()

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.name=title; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; tabs.add_child(scroll)
	var margin := MarginContainer.new(); margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(margin)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",12); margin.add_child(body)
	return body

func _text(value: String, size_value: int, color: Color=Style.TEXT) -> Label:
	var label := Label.new(); label.text=value; label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",color); return label

func _card(parent: Node, title: String, description: String, actions: Array) -> void:
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel",Style.box(Style.PANEL,4,Style.EDGE)); parent.add_child(card)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",8); card.add_child(body)
	body.add_child(_text(title,16,Style.GOLD))
	var copy := _text(description,14,Style.MUTED); copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; copy.custom_minimum_size.x=250; body.add_child(copy)
	if not actions.is_empty(): _action_row(body,actions)

func _action_row(parent: Node, actions: Array) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	for action: Array in actions:
		var id := str(action[0])
		var button := Button.new(); button.text=str(action[1]); button.custom_minimum_size.y=36; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.add_theme_font_size_override("font_size",13)
		button.pressed.connect(func(): action_requested.emit(id)); row.add_child(button); Soundscape.attach_controls(button)
		if not action_buttons.has(id): action_buttons[id]=[]
		action_buttons[id].append(button)

func refresh_bindings() -> void:
	for action: String in binding_values:
		var key := Preferences.action_label(action)
		if action=="console" and int(Preferences.values.bindings[action])!=KEY_F1: key+=" / F1"
		if action=="pause" and int(Preferences.values.bindings[action])!=KEY_ESCAPE: key+=" / Escape"
		binding_values[action].text=key

func refresh_context(has_household: bool, building: bool, joining: bool, authority: bool) -> void:
	for action: String in action_buttons:
		var reason := ""
		if action!="bindings":
			if not has_household or joining: reason="Join a household before using this control."
			elif building and action in ["care","wishes","hobbies","people"]: reason="Finish construction before directing your family."
			elif action=="save" and not authority: reason="The host saves this shared neighborhood."
		for button: Button in action_buttons[action]: button.disabled=not reason.is_empty(); button.tooltip_text=reason
	context_hint.text="Your lot is under construction. Care and visits resume when you finish." if building else "Joining a neighborhood…" if joining else ""
	context_hint.visible=not context_hint.text.is_empty()
