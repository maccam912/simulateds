extends SceneTree
const Finishes = preload("res://game/finishes.gd")
var game: Control
var session: Node
var suffix := ""

func _initialize() -> void: call_deferred("_run")

func _mouse(point: Vector2, click: bool=false) -> void:
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	await process_frame
	if click:
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
			root.push_input(event,true); await process_frame

func _click(button: Button) -> void:
	await process_frame
	if game.tools_box.is_ancestor_of(button): game.tools_box.get_parent().ensure_control_visible(button); await process_frame
	await _mouse(button.get_global_rect().get_center(),true)

func _find(text: String) -> Button:
	for node in game.tools_box.find_children("*","Button",true,false):
		if text in node.text: return node
	assert(false,"Missing catalog control: "+text); return null

func _tile(x: int, y: int, click: bool=true) -> void:
	await _mouse(game.lot_view.grid_point(x+0.5,y+0.5),click)

func _capture(name: String) -> void:
	game._refresh(); await create_timer(0.25).timeout; await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/finishes-"+name+suffix+".png")==OK)

func _run() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720) if compact else Vector2i(1440,900)
	if compact: suffix="-compact"; root.get_node("Preferences").set_value("ui_scale",1.25)
	session=root.get_node("Session"); session.saving_enabled=false; session.menu_paused=true
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	game=load("res://game/main.tscn").instantiate(); root.add_child(game); await process_frame
	var lot: Dictionary=session.state.lots.lot_1
	var objects: Array=lot.objects.duplicate(true)
	await _click(game.mode_button)
	await _click(_find("Floor finishes"))
	await _click(game.finish_buttons.slate)
	await _tile(9,4); await _tile(11,10,false)
	await _capture("floor-preview")
	assert(game.lot_view.preview_result.ok and game.lot_view.preview_result.cost==84 and lot.finishes.floor.is_empty(),"The area preview shows the exact cost without changing the house")
	await _tile(11,10)
	assert(lot.funds==11916 and game._paint_anchor.x<0 and lot.finishes.floor.size()==21)
	await _click(_find("Walls")); await _click(game.finish_buttons.sky)
	await _capture("wall-palette")
	var viewport: Rect2=game.tools_box.get_parent().get_global_rect()
	for button: Button in game.finish_buttons.values(): assert(viewport.encloses(button.get_global_rect()),"All six finishes fit the compact palette")
	# Click the visible elevated wall, not its projected ground tile.
	var face: Vector2=game.lot_view.grid_point(4.0,5.5)+Vector2(0,-18)*game.lot_view._cell.x/48.0
	var target: Dictionary=game.lot_view.hit_target(face)
	assert(target.get("type")=="wall" and target.x==3 and target.y==5,"Paint mode exposes the visible wall face: "+str(target))
	await _mouse(face,true)
	assert(game._paint_anchor==Vector2i(3,5),"First corner uses the wall face's true tile")
	await _mouse(face,true)
	assert(Finishes.at(lot,"wall",3,5)=="sky")
	await _click(game.finish_buttons.sage)
	await _tile(0,0); await _tile(13,13,false)
	assert(game._paint_anchor==Vector2i.ZERO)
	await _capture("wall-preview")
	var price: int=game.lot_view.preview_result.cost
	var budget: int=lot.funds
	await _tile(13,13)
	assert(lot.funds==budget-price and Finishes.at(lot,"wall",3,5)=="sage" and lot.objects==objects)
	await _click(_find("‹ Catalog")); await _click(_find("Room ·"))
	game.build_rotation=2; game._refresh()
	await _tile(3,11); await _tile(7,15)
	assert(lot.doors.has([5,11]),"A new room opens into the existing house")
	await _click(_find("Floor finishes")); await _click(game.finish_buttons.rose_carpet)
	await _tile(4,12); await _tile(6,14,false)
	await _capture("extension-preview")
	budget=int(lot.funds)
	await _tile(6,14)
	assert(lot.funds==budget-36 and Finishes.at(lot,"floor",5,13)=="rose_carpet")
	await _click(game.undo_button)
	assert(lot.funds==budget and Finishes.at(lot,"floor",5,13)=="oak")
	await _click(game.redo_button)
	assert(lot.funds==budget-36 and Finishes.at(lot,"floor",5,13)=="rose_carpet")
	await _tile(4,12)
	var key := InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; root.push_input(key,true); await process_frame
	assert(game._paint_anchor.x<0 and game.context_panel.visible,"Escape cancels the paint selection before closing the catalog")
	await _capture("decorated")
	await _click(game.mode_button)
	assert(not lot.building and lot.objects==objects)
	await _capture("live")
	session.state.day_minutes=1260.0; await _capture("night")
	print("FINISHES_RENDER_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
