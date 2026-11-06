extends VBoxContainer
## Reopenable help that leads into ordinary controls; never mutates a world.
signal action_requested(action: String)
const Icons = preload("res://game/ui_icons.gd")
const Style = preload("res://game/style.gd")
var tabs: TabContainer
var action_buttons: Dictionary = {}
var binding_values: Dictionary = {}
var context_hint: Label

func _ready() -> void:
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	tabs=TabContainer.new(); tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(tabs)
	var first := _page("First day")
	var legend := HFlowContainer.new(); first.add_child(legend)
	for entry: Array in [["needs","Needs"],["plan","Plan"],["more","More"],["household","Edit household"],["visit","Visit lot"]]:
		var row := HBoxContainer.new(); legend.add_child(row)
		var icon := TextureRect.new(); icon.texture=Icons.texture(entry[0]); icon.custom_minimum_size=Vector2(24,24); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(icon)
		row.add_child(_text(entry[1]+"  ",12))
	_card(first,"01 · Meet your household","Select a resident at the lower left; click their name again to find them in the world. More → Edit household gives each resident a name, a look, and a favorite pastime.",[["household","Meet your household"]])
	_card(first,"02 · A little care","Open Needs, then select a need bar to review the resident and proposed care. Choose the named activity to add it to Plan. A resident’s thought cue can also plan care. Plan's arrows reorder upcoming activities; the current activity continues. Your orders take priority over autonomy. Plan → Routines saves care and leisure sequences for household members.",[["care","Open care suggestions"]])
	_card(first,"03 · Something to enjoy","Wishes offer small goals and a journal. Reading, gardening, cooking, and painting develop lasting hobbies. Nothing expires while you are away.",[["wishes","See wishes"],["hobbies","Find a hobby"]])
	_card(first,"04 · Make it home","Move furniture for free, decorate a room, or build an addition. Your household waits safely while you build.",[["build","Open build mode"]])
	_card(first,"Set your pace","The clock controls pause solo life or play at 1×, 2×, and 4×. While paused, you can still queue activities and build. Pause again resumes your chosen pace. Shared neighborhoods keep one running clock; hosting or joining returns it to normal speed.",[])
	_card(first,"Grow something","A kitchen garden bed fits on the lawn or a floor. Choose radishes or tomatoes, water them as they grow, then sell the harvest or keep four vegetables in the pantry. The pantry holds twelve of each crop. Homegrown meals at a dining table use two of each for four portions. Dry plants wait safely and ripe crops keep. Visitors can help water; planting and harvesting belong to the household.",[["garden","Choose a garden bed"]])
	_card(first,"Make something personal","A Daydream easel offers three painting subjects. Unfinished canvases keep when you stop; household members old enough to paint can help. Finished pictures keep their artists’ names. Hang on wall enters build mode and frees the easel. Sell painting packs it for §60 instead. Each housemate who contributes 12 game minutes earns practice when the canvas finishes, up to twice daily. The rank link opens painting progress.",[])
	_card(first,"A meal together","Buy a Gathering dining table from Kitchen. Choose purchased salad or sandwiches, or a homegrown bowl using two radishes and two tomatoes from your pantry; your resident prepares food at the fridge and carries four portions to the table. Pantry ingredients are reserved by your plan; ingredients and funds are used when served. Cancelling releases reserved produce. Choose Eat a portion, or People → Join meal. Hungry housemates eat available portions with autonomy on. Choose this meal or People → Join meal makes current dining chosen shared time without taking another portion. Guests choose their own diners. Food stays untouched by caretakers while you are away. Leftovers keep; Clear leftovers removes them without a refund.",[])
	var building := _page("Building")
	_card(building,"Start with a room","Choose Room and click two opposite corners. The preview includes floors, walls, a doorway, and the price. Rotate changes the door side.",[["build","Open build mode"]])
	_card(building,"Your first upstairs · checklist","1. Enter Build and place a straight staircase on flooring downstairs. Leave a clear tile at each end for its lower and upper landings. Rotate before placing if needed.\n2. View Floor 2 with +. Lay connected flooring at the upper landing and beneath every upstairs furnishing. The stair opening stays open automatically; keep walls and furniture out of it. This prototype does not require supporting walls below upper flooring.\n3. Use Access to check every floor. Find locates missing connections, blocked landings and unreachable furnishings. Add doors or clear paths; Undo and Discard remain available.\n4. Finish returns to your selected resident. View controls only move the camera between floors; Go upstairs/downstairs adds a stair order to that resident’s Plan. Repeat for Floor 3, the top floor. Reading this checklist buys nothing.",[])
	_card(building,"Another room like this one","Copy room selects an enclosed room with a doorway. Point to clear space, rotate the furnished preview, then place it for the shown total. Finishes and windows come along; garden beds, easels, and dining tables start empty. Earned artwork stays with the original. One Undo restores the whole placement.",[])
	_card(building,"Find a place for everything","Search by a name or use: sleep, meal, book. Green previews keep access clear. Amber names a blocked furnishing or resident; drafts allow the edit, but restore access before finishing. Red means placement is unavailable. Access helps locate and repair problems.",[["catalog","Browse the catalog"],["move","Rearrange furniture"]])
	_card(building,"Your own colors","Floor and wall finishes decorate existing surfaces. Area uses two corners; Room fills connected floor with one click, stopping at walls and doorways. Preview the exact price; only changed tiles cost money. One Undo restores the edit.",[["decorate","Browse finishes"]])
	_card(building,"Furniture with personality","Furniture colors offers Original, Sage, Sky, Rose, Honey, and Ink at no charge. Choose a swatch, hover over a furnishing to preview its material, then click to apply. Undo restores its previous color. Choices follow furniture through moves, room copies, and saves.",[])
	_card(building,"Let the daylight in","Choose Windows in the catalog, then a style and an existing solid wall. Hover previews the exact price. Replacements credit the old window’s resale value; Remove window leaves the wall in place. Windows keep rooms and routes intact.",[])
	_card(building,"Art made at home","Wall art lists finished canvases and your household collection. Choose a picture, then a solid wall without a window. Hanging and moving are free; Undo restores the whole transfer. Store a picture or return it to an empty easel. Removing its wall safely stores it.",[])
	_card(building,"Change your mind","Undo restores an edit and its exact cost; Redo reapplies it. Discard draft restores the whole house. Finish building checks that the home remains usable.",[])
	_card(building,"Keep a neighborhood","The host owns shared saves. Saved games keep the last finished house; an unfinished construction draft is discarded when you leave.",[["save","Save neighborhood"]])
	var neighbors := _page("Neighbors")
	_card(neighbors,"Together, at your own pace","Host or join from More → Play together. Each household has its own lot. One person can build while another cares for their family.",[["connect","Play together"]])
	_card(neighbors,"Drop in for a catch-up","Open Neighborhood to view a home without moving anyone. Available lots have no household and cannot be visited yet. Choose an occupied, open home, then More → Visit lot to send the selected resident. When viewing another lot, Find resident returns the view to their actual location without changing their plan. More → Together… chooses several residents; Go home returns the selected resident. People also offers visits. Chats build friendships. If an owner starts construction, visitors return home safely.",[["people","Find your neighbors"]])
	_card(neighbors,"Leave a little kindness","Mail carries a postcard with money or a finished painting for someone to find later. A gifted painting leaves your home and keeps its artist credit. Collect it, then choose Hang this painting. Finish construction before sending or collecting artwork. Home news shows gifts still waiting.",[["mail","Open the mailbox"]])
	_card(neighbors,"The neighborhood clock","The host must stay running for life to continue. Away households get forgiving care and keep their wishes, hobbies, and friendships. If the entire host stops, the world waits. Shared menus never pause everyone else.",[])
	var controls := _page("Controls")
	_card(controls,"Touch controls","Tap to select a resident, walk, or use furniture. Hold furniture or a resident briefly to review actions; release, then tap a choice. Drag the world to pan; use − / + beside the lot name to zoom. Tap a selected household name again to find them. In Build, select a card then tap a destination; Move selects a furnishing then its new position, and Rotate turns the selected piece. Floor and wall tools also accept a rectangle drag. Android Back closes the current choice or tray before opening the game menu; edited households still ask before discarding.",[])
	controls.add_child(_text("YOUR KEY BINDINGS",12,Style.GOLD))
	var grid := GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",22); grid.add_theme_constant_override("v_separation",9); controls.add_child(grid)
	for action: String in Preferences.ACTION_NAMES:
		var label := _text(str(Preferences.ACTION_NAMES[action]),14); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_child(label)
		var key := _text("",14,Style.GREEN); grid.add_child(key); binding_values[action]=key
	_action_row(controls,[["bindings","Edit key bindings"]])
	_card(controls,"Mouse & building shortcuts","Right-click furniture or residents for an action wheel; on touch, hold briefly. Shift+F10 opens the selected resident’s wheel; Tab/arrows and Enter choose. Escape or an outside click dismisses it. More holds household, travel and activity tools; Needs expands care bars. Left-click: walk, use furniture, or place the selected item. Hover ground to preview a route or queued walk; Plan shows numbered destinations. Scroll: zoom. Middle-drag: pan. Click a selected household name again to find them, or use Find resident in Plan. More → Home overview shows your home’s ground floor and fits the house without moving residents. Find resident keeps your zoom and locates them on their actual lot and floor. Scroll or middle-drag to adjust either view. Ctrl/Cmd+F: search the catalog; Enter: select its first result. Ctrl/Cmd+Z: undo. Ctrl/Cmd+Shift+Z or Ctrl+Y: redo.",[])
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
