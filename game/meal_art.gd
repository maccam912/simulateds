extends RefCounted
## The same original platter artwork appears in the house and in the meal tray.
static func draw(canvas: CanvasItem,center: Vector2,scale_value: float,recipe: String,portions: int) -> void:
	canvas.draw_set_transform(center,0,Vector2(scale_value,scale_value*0.52))
	canvas.draw_circle(Vector2(0,2),17,Color("9d917b"))
	canvas.draw_circle(Vector2.ZERO,17,Color("f6ebd3"))
	canvas.draw_arc(Vector2.ZERO,14,0,TAU,32,Color("c4b99a"),1.0,true)
	for index in range(clampi(portions,0,4)):
		var p: Vector2=[Vector2(-6,-5),Vector2(6,-5),Vector2(-6,5),Vector2(6,5)][index]
		if recipe=="sandwiches":
			canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-4),p+Vector2(5,-4),p+Vector2(5,4)]),Color("b18b52"))
			canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-6),p+Vector2(5,-6),p+Vector2(5,2)]),Color("e8c98d"))
			canvas.draw_line(p+Vector2(0,0),p+Vector2(5,3),Color("799757"),1.8,true)
		else:
			for leaf: Vector2 in [Vector2(-3,-1),Vector2(2,-2),Vector2(0,3)]: canvas.draw_circle(p+leaf,4,Color("87a761") if leaf.x<0 else Color("adc279"))
			canvas.draw_circle(p+Vector2(2,1),2,Color("d48761"))
			if recipe=="homegrown":
				canvas.draw_circle(p+Vector2(-3,1),2.5,Color("d78c91"))
				canvas.draw_circle(p+Vector2(-3,1),1.3,Color("fae4ce"))
				canvas.draw_circle(p+Vector2(3,-2),2.2,Color("d67954"))
	canvas.draw_set_transform(Vector2.ZERO)
