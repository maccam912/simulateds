extends Control
var recipe := "salad"
var portions := 4
func _draw() -> void:
	preload("res://game/meal_art.gd").draw(self,size*0.5,minf(size.x/44.0,size.y/24.0),recipe,portions)
