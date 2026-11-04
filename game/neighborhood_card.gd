extends Button
const Style=preload("res://game/style.gd")
var title: Label
var status: Label
var roster: Label
var _selected := false
func _ready() -> void:
	custom_minimum_size=Vector2(0,72)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var margin:=MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side: String in ["left","right"]: margin.add_theme_constant_override("margin_"+side,10)
	for side: String in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,7)
	var column:=VBoxContainer.new(); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_theme_constant_override("separation",2); margin.add_child(column)
	title=_label(column,14,Style.TEXT); status=_label(column,12,Style.MUTED); roster=_label(column,12,Style.MUTED)
func _label(parent: Node,font_size: int,color: Color) -> Label:
	var label:=Label.new(); label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.clip_text=true; label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label); return label
func refresh(data: Dictionary,selected: bool) -> void:
	title.text=str(data.name); status.text=str(data.status); roster.text=str(data.roster); tooltip_text=str(data.tooltip)
	status.add_theme_color_override("font_color",Style.GOLD if data.building else Style.GREEN if data.playing or data.guest_players>0 else Style.MUTED)
	if selected!=_selected:
		_selected=selected
		if selected: add_theme_stylebox_override("normal",Style.box(Color("3b514b"),4,Style.GREEN))
		else: remove_theme_stylebox_override("normal")
