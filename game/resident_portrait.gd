extends Control
const Appearance = preload("res://game/appearance.gd")
var look := {"skin":2,"hair":1,"shirt":0,"style":0}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(100,104)

func _draw() -> void:
	var s := minf(size.y/48.0,size.x/55.0)
	var p := Vector2(size.x*0.5,size.y*0.94)
	draw_style_box(preload("res://game/style.gd").box(Color("253d40"),6),Rect2(Vector2.ZERO,size))
	draw_circle(Vector2(size.x*0.5,size.y*0.47),size.y*0.4,Color("3d5650"))
	var skin: Color=Appearance.SKIN[int(look.skin)]
	var shirt: Color=Appearance.SHIRT[int(look.shirt)]
	draw_line(p+Vector2(-3,-1)*s,p+Vector2(-4,-14)*s,Color("424f54"),4*s,true)
	draw_line(p+Vector2(3,-1)*s,p+Vector2(4,-14)*s,Color("424f54"),4*s,true)
	draw_line(p+Vector2(0,-13)*s,p+Vector2(0,-24)*s,shirt,12*s,true)
	draw_line(p+Vector2(-7,-23)*s,p+Vector2(-9,-14)*s,skin,3*s,true)
	draw_line(p+Vector2(7,-23)*s,p+Vector2(9,-14)*s,skin,3*s,true)
	Appearance.draw_head(self,p+Vector2(0,-31)*s,s,look)
