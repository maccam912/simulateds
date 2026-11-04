extends VBoxContainer
signal command_requested(command: Dictionary)
signal meals_requested
const Gardens = preload("res://game/gardens.gd")
const Pantry = preload("res://game/pantry.gd")
const Style = preload("res://game/style.gd")
var summary: Label
var growth: ProgressBar
var water: ProgressBar
var water_label: Label
var pantry_label: Label
var meals_button: Button
var note: Label
var feedback: Label
var buttons: Dictionary={}
var pending: Dictionary={}
var _acknowledged := false
var _next_action := 0
var _context := ""
var _lot := ""
var _object := ""
var _member := ""
var _options := {}
var _revision := -1
var _reply_error := ""

func _ready() -> void:
	add_theme_constant_override("separation",8)
	summary=_label("",14,Style.GOLD)
	growth=_bar(Style.GREEN); water_label=_label("",12,Style.MUTED); water=_bar(Color("8cbbb7"))
	pantry_label=_label("",11,Style.GREEN)
	for key: String in ["radish","tomato","water","harvest","keep"]:
		var button := Button.new(); button.custom_minimum_size.y=38; button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func(): _request(key)); add_child(button); buttons[key]=button
	note=_label("",12,Style.MUTED); feedback=_label("",12,Style.GOLD)
	Session.command_completed.connect(_completed)
	Soundscape.attach_controls(self)

func add_footer(parent: Node) -> void:
	meals_button=Button.new(); meals_button.custom_minimum_size.y=32; meals_button.add_theme_font_size_override("font_size",12)
	meals_button.pressed.connect(func(): meals_requested.emit()); parent.add_child(meals_button); Soundscape.attach_controls(parent)

func _label(text: String,size_value: int,color: Color) -> Label:
	var label := Label.new(); label.text=text; label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new(); bar.custom_minimum_size.y=10; bar.show_percentage=false
	bar.add_theme_stylebox_override("background",Style.box(Style.INK,3)); bar.add_theme_stylebox_override("fill",Style.box(color,3))
	add_child(bar); return bar

func refresh(lot_id: String,object_id: String,member_id: String) -> void:
	_lot=lot_id; _object=object_id; _member=member_id
	var context := str([Session.role,Session.profile_id,lot_id,object_id,member_id])
	if context!=_context: pending={}; _acknowledged=false; feedback.text=""; _reply_error=""; _context=context; _revision=-1
	var lot: Dictionary=Session.state.lots.get(lot_id,{})
	var object: Dictionary=Session.world._object(lot,object_id) if not lot.is_empty() else {}
	var family: Dictionary=Session.state.families.get(Session.profile_id,{})
	var member: Dictionary=Session.world._member(family,member_id) if not family.is_empty() else {}
	if _acknowledged and not pending.is_empty() and int(member.get("next_action",0))>_next_action:
		pending={}; _acknowledged=false
	var exists: bool=object.get("kind")=="garden_bed"
	if meals_button!=null: meals_button.visible=exists
	for button: Button in buttons.values(): button.visible=exists
	for control: Control in [growth,water,water_label,note,pantry_label]: control.visible=exists
	if not exists: summary.text="This garden bed is no longer here."; return
	var bed: Dictionary=object.garden
	if int(bed.revision)!=_revision:
		if pending.is_empty(): _reply_error=""
		_revision=int(bed.revision)
	var planted: bool=not str(bed.crop).is_empty()
	summary.text=Gardens.summary(bed)
	growth.visible=planted; growth.value=float(bed.growth)/float(Gardens.CROPS[bed.crop].seconds)*100.0 if planted else 0.0
	water.visible=planted and not Gardens.ripe(bed); water_label.visible=water.visible
	water.value=float(bed.water)/Gardens.WATER_CAP*100.0
	water_label.text="Water · %d%%" % ceili(water.value)
	pantry_label.visible=lot.owner==Session.profile_id
	if pantry_label.visible:
		pantry_label.text=Pantry.summary(Session.state,Session.profile_id); pantry_label.tooltip_text=Pantry.description(Session.state,Session.profile_id)
	if meals_button!=null:
		meals_button.visible=pantry_label.visible
		var has_table: bool=Session.state.lots[family.home_lot].objects.any(func(furnishing): return furnishing.kind=="dining_table")
		meals_button.text="Homegrown meals ›" if has_table else "Build a dining table · §%d" % int(preload("res://game/catalog.gd").ITEMS.dining_table.cost)
		meals_button.disabled=not pending.is_empty() or Session.role=="joining" or bool(Session.state.lots[family.home_lot].building)
		meals_button.tooltip_text="Open the home table without choosing a recipe or moving a resident." if has_table else "Open Build & buy with a dining table selected. Your household pauses for construction."
	note.text="Dry plants wait; ripe crops keep.\nHarvests from this bed: %d" % int(bed.harvests)
	if Gardens.ripe(bed): note.text="Sell for funds, or keep %d for homegrown meals.\nHarvests from this bed: %d" % [Gardens.HARVEST_COUNT,int(bed.harvests)]
	if not planted: note.text="Seeds are paid for when planting finishes.\nRadishes: 4½ hours · Tomatoes: 9 hours of watered growth."
	if lot.owner!=Session.profile_id: note.text="Visitors can help water. Planting and harvesting belong to this household."
	_options.clear()
	for key: String in buttons:
		var action := "plant" if Gardens.CROPS.has(key) else key
		var crop := key if action=="plant" else ""
		var button: Button=buttons[key]
		button.visible=not planted if action=="plant" else planted and (not Gardens.ripe(bed) if action=="water" else Gardens.ripe(bed))
		var option: Dictionary=Session.world.garden_option(Session.profile_id,member_id,lot_id,object_id,action,crop)
		_options[key]=option
		button.text="Plant "+str(Gardens.CROPS[key].name).to_lower()+" · §%d" % int(Gardens.CROPS[key].seed_cost) if action=="plant" else "Water crop" if key=="water" else "Keep harvest · %d for pantry" % Gardens.HARVEST_COUNT if key=="keep" else "Harvest & sell · §%d" % int(Gardens.CROPS.get(bed.crop,{}).get("harvest_value",0))
		button.disabled=not option.ok or not pending.is_empty() or Session.role=="joining"
		button.tooltip_text=str(option.message) if not option.ok else str(option.label)+" · Queues for "+str(member.get("name","your resident"))
		if action=="plant" and option.ok: button.tooltip_text+="\nHarvest value: §%d" % int(Gardens.CROPS[key].harvest_value)
	if pending.is_empty():
		feedback.text=_reply_error
		for household: Dictionary in Session.state.families.values():
			for resident: Dictionary in household.members:
				if resident.lot_id!=lot_id: continue
				var tasks: Array=resident.queue.duplicate(); tasks.append(resident.task)
				for task: Dictionary in tasks:
					if task.get("target_id")==object_id and task.has("garden_action"):
						feedback.text=str(resident.name)+" · "+Gardens.label(str(task.garden_action),str(task.crop) if task.garden_action=="plant" else str(bed.crop))
	feedback.visible=not feedback.text.is_empty()

func _request(key: String) -> void:
	if not pending.is_empty() or not _options.get(key,{}).get("ok",false): return
	var action := "plant" if Gardens.CROPS.has(key) else key
	pending={"type":"garden","lot_id":_lot,"target_id":_object,"member_id":_member,"action":action,"crop":key if action=="plant" else "","revision":_options[key].revision}
	var family: Dictionary=Session.state.families[Session.profile_id]
	_next_action=int(Session.world._member(family,_member).next_action); _acknowledged=false; _reply_error=""
	feedback.text="Waiting for the neighborhood…"
	refresh(_lot,_object,_member)
	command_requested.emit(pending.duplicate(true))

func _completed(intent: Dictionary,ok: bool,message: String) -> void:
	if pending.is_empty() or pending!=intent: return
	feedback.text=message
	if ok: _acknowledged=true
	else: pending={}; _acknowledged=false; _reply_error=message
	refresh(_lot,_object,_member)
