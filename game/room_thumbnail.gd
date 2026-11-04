extends Control
## Small floor-plan swatch, using the room’s floor finishes and material colors.
const Finishes=preload("res://game/finishes.gd")
const Colors=preload("res://game/furniture_colors.gd")
const Catalog=preload("res://game/catalog.gd")
const Style=preload("res://game/style.gd")
var design := {}
func _ready() -> void:
	custom_minimum_size=Vector2(76,70); mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_style_box(Style.box(Style.INK,3,Style.EDGE),Rect2(Vector2.ZERO,size))
	if design.is_empty(): return
	var cell:=minf((size.x-12)/float(design.width),(size.y-12)/float(design.height))
	var origin: Vector2=(size-Vector2(design.width,design.height)*cell)*0.5
	for tile: Array in design.floors:
		var finish: String=design.finishes.floor.get(Finishes.key(tile[0],tile[1]),"oak")
		draw_rect(Rect2(origin+Vector2(tile[0],tile[1])*cell,Vector2.ONE*cell),Color(Finishes.PALETTES.floor[finish].color))
	for tile: Array in design.walls:
		var rect:=Rect2(origin+Vector2(tile[0],tile[1])*cell,Vector2.ONE*cell)
		draw_rect(rect,Color("d5d0bb"))
		if design.windows.has(Finishes.key(tile[0],tile[1])): draw_rect(rect.grow(-cell*0.25),Color("8cc5cc"))
	for tile: Array in design.doors: draw_rect(Rect2(origin+Vector2(tile[0],tile[1])*cell,Vector2.ONE*cell).grow(-cell*0.15),Style.GOLD)
	for object: Dictionary in design.objects:
		var footprint:=Catalog.footprint(object.kind,int(object.rotation))
		draw_rect(Rect2(origin+Vector2(object.x,object.y)*cell,Vector2(footprint)*cell).grow(-cell*0.12),Colors.material(object,"b9dc8e"))
