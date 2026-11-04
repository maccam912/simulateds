extends RefCounted
## A shared visual vocabulary; presentation has no authority over the simulation.

const INK := Color("142329")
const PANEL := Color("1b2d34")
const EDGE := Color("30444a")
const TEXT := Color("f4f0df")
const MUTED := Color("a4b8b8")
const GREEN := Color("b9dc8e")
const GOLD := Color("edc98b")

static func box(color: Color, radius: int = 5, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.content_margin_left = 14
	result.content_margin_right = 14
	result.content_margin_top = 10
	result.content_margin_bottom = 10
	if border.a > 0:
		result.set_border_width_all(1)
		result.border_color = border
	return result

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("63797d"))
	result.set_stylebox("normal", "Button", box(PANEL, 4, EDGE))
	result.set_stylebox("hover", "Button", box(Color("30484d"), 4, GREEN))
	result.set_stylebox("pressed", "Button", box(GREEN, 4))
	result.set_stylebox("disabled", "Button", box(Color("17272c"), 4))
	result.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 4, GREEN))
	result.set_stylebox("normal", "LineEdit", box(INK, 8, EDGE))
	result.set_stylebox("focus", "LineEdit", box(INK, 8, GREEN))
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	var menu := box(PANEL,4,EDGE)
	menu.content_margin_left=6; menu.content_margin_right=6; menu.content_margin_top=6; menu.content_margin_bottom=6
	result.set_stylebox("panel","PopupMenu",menu)
	result.set_stylebox("hover","PopupMenu",box(GREEN,3))
	result.set_color("font_color","PopupMenu",TEXT)
	result.set_color("font_hover_color","PopupMenu",INK)
	result.set_color("font_disabled_color","PopupMenu",MUTED)
	var overlay := box(Color(0.075, 0.12, 0.16, 0.92), 5, Color("647782"))
	overlay.shadow_color = Color(0, 0, 0, 0.22)
	overlay.shadow_size = 4
	overlay.shadow_offset = Vector2(0,2)
	result.set_stylebox("panel", "PanelContainer", overlay)
	result.set_stylebox("background", "ProgressBar", box(Color("0e1e24"), 4))
	result.set_stylebox("fill", "ProgressBar", box(GREEN, 4))
	result.set_constant("separation", "VBoxContainer", 4)
	result.set_constant("separation", "HBoxContainer", 10)
	result.set_stylebox("panel","TabContainer",box(PANEL,4))
	result.set_stylebox("tab_selected","TabBar",box(PANEL,4,GREEN))
	result.set_stylebox("tab_unselected","TabBar",box(INK,4,EDGE))
	result.set_stylebox("tab_hovered","TabBar",box(Color("30484d"),4,EDGE))
	result.set_color("font_selected_color","TabBar",TEXT)
	result.set_color("font_unselected_color","TabBar",MUTED)
	var track:=StyleBoxFlat.new()
	track.bg_color=INK
	track.set_corner_radius_all(3)
	track.content_margin_top=3
	track.content_margin_bottom=3
	result.set_stylebox("slider","HSlider",track)
	var fill:=track.duplicate() as StyleBoxFlat
	fill.bg_color=GREEN.darkened(0.15)
	result.set_stylebox("grabber_area","HSlider",fill)
	result.set_stylebox("grabber_area_highlight","HSlider",fill)
	return result
