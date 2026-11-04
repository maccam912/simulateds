extends VBoxContainer
signal bed_requested(id: String)
signal build_requested
signal meals_requested
signal back_requested
const Overview=preload("res://game/garden_overview.gd")
const Pantry=preload("res://game/pantry.gd")
const Style=preload("res://game/style.gd")
const Catalog=preload("res://game/catalog.gd")
var home_label: Label
var stock_label: Label
var recipe_label: Label
var empty_label: Label
var beds: VBoxContainer
var bed_buttons: Dictionary={}
var build_button: Button
var meals_button: Button
var back_button: Button
var _ids: Array=[]
var _context := ""

func _ready() -> void:
	add_theme_constant_override("separation",8)
	home_label=_label(11,Style.MUTED); stock_label=_label(12,Style.GREEN); recipe_label=_label(11,Style.MUTED)
	home_label.autowrap_mode=TextServer.AUTOWRAP_OFF; home_label.clip_text=true; home_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	empty_label=_label(13,Style.TEXT)
	beds=VBoxContainer.new(); beds.add_theme_constant_override("separation",8); add_child(beds)

func _label(size_value: int,color: Color) -> Label:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.x=200; add_child(label); return label
func _button(parent: Node,text_value: String,callback: Callable) -> Button:
	var button:=Button.new(); button.text=text_value; button.custom_minimum_size.y=32; button.add_theme_font_size_override("font_size",12)
	button.pressed.connect(callback); parent.add_child(button); return button
func add_footer(parent: Node) -> void:
	build_button=_button(parent,"",func(): build_requested.emit())
	meals_button=_button(parent,"",func(): meals_requested.emit())
	back_button=_button(parent,"‹ Activities",func(): back_requested.emit())
	Soundscape.attach_controls(parent)

func refresh() -> void:
	if build_button==null: return
	var info:=Overview.inspect(Session.state,Session.profile_id)
	if info.is_empty():
		home_label.text="Your household is joining…"; beds.hide(); stock_label.hide(); recipe_label.hide(); empty_label.hide()
		build_button.disabled=true; meals_button.disabled=true; return
	for control: Control in [beds,stock_label,recipe_label]: control.show()
	home_label.text="At "+str(info.name)
	home_label.tooltip_text=home_label.text
	stock_label.text="Free · "+Pantry.summary(Session.state,Session.profile_id).trim_prefix("Pantry free · ")
	stock_label.tooltip_text=Pantry.description(Session.state,Session.profile_id)
	recipe_label.text="%d %s possible · Four portions each" % [int(info.bowls),"bowl" if int(info.bowls)==1 else "bowls"] if int(info.bowls)>0 else "A bowl uses 2 of each · Four portions"
	empty_label.visible=info.rows.is_empty()
	empty_label.text="No garden beds yet.\nAdd one on grass or floor, then choose seeds. Dry plants and ripe crops wait safely."
	var context:=str(Session.profile_id)+":"+str(Session.world_generation)
	var ids: Array=info.rows.map(func(row): return row.id)
	if ids!=_ids or context!=_context:
		var focused: Control=get_viewport().gui_get_focus_owner()
		var focused_id: String=str(focused.get_meta("garden_bed","")) if focused!=null else ""
		for child in beds.get_children(): beds.remove_child(child); child.queue_free()
		_ids=ids; _context=context; bed_buttons.clear()
		for row: Dictionary in info.rows:
			var id: String=row.id
			var button:=_button(beds,"",func(): bed_requested.emit(id)); button.custom_minimum_size.y=56
			button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.clip_text=true; button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			button.set_meta("garden_bed",id); bed_buttons[id]=button
		Soundscape.attach_controls(beds)
		if not focused_id.is_empty():
			if bed_buttons.has(focused_id): bed_buttons[focused_id].grab_focus()
			else: back_button.grab_focus()
	for row: Dictionary in info.rows:
		var button: Button=bed_buttons[row.id]
		button.text=str(row.title)+"\n"+str(row.status); button.tooltip_text=str(row.tooltip)+("\nOpen this bed to choose an activity." if row.available else "\nFinish construction to inspect this bed.")
		button.disabled=not row.available or Session.role=="joining"
	build_button.text=("Build" if info.rows.is_empty() else "Add")+" a garden bed · §%d" % int(Catalog.ITEMS.garden_bed.cost)
	build_button.tooltip_text="Open Build & buy with a garden bed selected. Your household pauses for construction; you choose where to place it."
	meals_button.text="Homegrown meals ›" if info.has_table else "Build a dining table · §%d" % int(Catalog.ITEMS.dining_table.cost)
	meals_button.tooltip_text="Open your home dining table without choosing a meal or moving a resident." if info.has_table else "Open Build & buy with a dining table selected. Your household pauses for construction."
	build_button.disabled=info.building or Session.role=="joining"; meals_button.disabled=build_button.disabled
