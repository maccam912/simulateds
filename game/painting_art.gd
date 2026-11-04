extends RefCounted
## Original, code-drawn miniatures shared by the canvas in the house and its tray.
static func draw(canvas: CanvasItem,picture: Dictionary) -> void:
	canvas.draw_rect(Rect2(0,0,1,1),Color("f4e8ca"))
	var amount := float(picture.get("progress",0.0))/24.0
	var subject := str(picture.get("subject",""))
	if subject.is_empty() or amount<=0: return
	var sky := Color("b8d2c5") if subject=="meadow" else Color("b3c9d4") if subject=="harbor" else Color("d6b8ac")
	canvas.draw_rect(Rect2(0.04,0.04,0.92,0.92),Color("f4e8ca").lerp(sky,minf(1,amount*4)))
	if amount<0.25: return
	match subject:
		"meadow":
			canvas.draw_circle(Vector2(0.76,0.25),0.12,Color("edd291"))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.04,0.6),Vector2(0.3,0.43),Vector2(0.6,0.62),Vector2(0.96,0.4),Vector2(0.96,0.96),Vector2(0.04,0.96)]),Color("83a783"))
			if amount>=0.55:
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.04,0.78),Vector2(0.4,0.62),Vector2(0.96,0.76),Vector2(0.96,0.96),Vector2(0.04,0.96)]),Color("587d68"))
				for index in range(5): canvas.draw_circle(Vector2(0.15+index*0.16,0.79+0.08*(index%2)),0.022,Color("e9bd8c"))
		"harbor":
			canvas.draw_rect(Rect2(0.04,0.52,0.92,0.44),Color("698f9a"))
			canvas.draw_circle(Vector2(0.23,0.26),0.09,Color("edcf9b"))
			if amount>=0.55:
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.35,0.7),Vector2(0.79,0.7),Vector2(0.7,0.81),Vector2(0.43,0.81)]),Color("6e615d"))
				canvas.draw_line(Vector2(0.58,0.28),Vector2(0.58,0.71),Color("66564d"),0.025,true)
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.55,0.31),Vector2(0.55,0.66),Vector2(0.33,0.66)]),Color("f3e7ca"))
		"flowers":
			canvas.draw_rect(Rect2(0.04,0.79,0.92,0.17),Color("ad8872"))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.35,0.52),Vector2(0.66,0.52),Vector2(0.6,0.81),Vector2(0.41,0.81)]),Color("628b86"))
			if amount>=0.55:
				for index in range(3):
					var bloom := Vector2(0.29+index*0.21,0.32-0.12*(index%2))
					canvas.draw_line(Vector2(0.5,0.58),bloom,Color("5a7d63"),0.025,true)
					for petal in range(5): canvas.draw_circle(bloom+Vector2(0.07,0).rotated(petal*TAU/5),0.065,Color("e2a17f") if index%2 else Color("e9cf8c"))
					canvas.draw_circle(bloom,0.035,Color("8d7656"))
	if amount>=1:
		canvas.draw_line(Vector2(0.8,0.9),Vector2(0.84,0.85),Color("675c51"),0.012,true)
		canvas.draw_line(Vector2(0.82,0.89),Vector2(0.91,0.89),Color("675c51"),0.012,true)
