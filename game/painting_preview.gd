extends Control
var picture: Dictionary={}
func _draw() -> void:
	var height := minf(110,size.y-10)
	var width := height*1.4
	var rect := Rect2(Vector2((size.x-width)*0.5,5),Vector2(width,height))
	draw_style_box(preload("res://game/style.gd").box(Color("997957"),3),rect.grow(4))
	draw_set_transform_matrix(Transform2D(Vector2(rect.size.x,0),Vector2(0,rect.size.y),rect.position))
	preload("res://game/painting_art.gd").draw(self,picture)
	draw_set_transform_matrix(Transform2D.IDENTITY)
