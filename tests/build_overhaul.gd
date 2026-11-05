extends SceneTree
const World = preload("res://game/world.gd")
const Storeys = preload("res://game/storeys.gd")
const Landscape = preload("res://game/landscaping.gd")
var world := World.new()
var lot: Dictionary

func _initialize() -> void: call_deferred("_run")
func edit(command: Dictionary) -> Dictionary:
	command.lot_id="lot_1"; command.revision=lot.revision
	return world.apply_command("builder",command)
func require_edit(command: Dictionary) -> void:
	var result := edit(command)
	assert(result.ok,str([command,result]))

func _run() -> void:
	world.initialize(); world.ensure_family("builder","Sam"); world.set_online("builder",true)
	lot=world.state.lots.lot_1
	var resident: Dictionary=world.state.families.builder.members[0]
	for member: Dictionary in world.state.families.builder.members: member.autonomy=false
	var start := Vector2i(resident.x,resident.y)
	require_edit({"type":"build_begin"})
	assert(Vector2i(resident.x,resident.y)==start,"Entering build mode leaves residents alone")
	require_edit({"type":"place","kind":"plant","x":start.x,"y":start.y})
	assert(Vector2i(resident.x,resident.y)!=start and resident.y>=12,"Displaced resident returns to the street")
	require_edit({"type":"build_undo"})
	var before := world.snapshot()
	assert(not edit({"type":"landscape","kind":"pool","x":3,"y":3,"end_x":4,"end_y":4}).ok)
	assert(world.snapshot()==before,"Rejected pool is atomic")
	require_edit({"type":"landscape","kind":"pool","x":0,"y":10,"end_x":1,"end_y":11})
	assert(not world._walkable(lot,Vector2i(0,10)),"Pools block walking")
	var pools: Array=lot.landscape.pools.duplicate(true)
	require_edit({"type":"build_undo"}); assert(lot.landscape.pools.is_empty())
	require_edit({"type":"build_redo"}); assert(lot.landscape.pools==pools)
	require_edit({"type":"landscape","kind":"terrain_raise","x":0,"y":14,"end_x":2,"end_y":14,"radius":2})
	assert(Landscape.height(lot,1,14)>0)
	require_edit({"type":"landscape","kind":"terrain_sand","x":0,"y":14,"end_x":2,"end_y":14,"radius":2})
	var stroke := {"type":"landscape","kind":"terrain_gravel","x":13,"y":0,"end_x":13,"end_y":0,"radius":1,"points":[[13,0],[15,0],[15,2],[13,0]]}
	var quoted := Landscape.inspect(lot,stroke)
	stroke.stroke=Landscape.encode_stroke(stroke.points); stroke.erase("points")
	assert(Landscape.inspect(lot,stroke)==quoted,"A closed brush stroke keeps its full painted path")
	require_edit(stroke)
	var points: Array=[]
	for y in range(16):
		for x in range(16): points.append([x,y])
	var maximum := {"type":"command","id":9007199254740991,"intent":{"type":"landscape","lot_id":"lot_1","level":0,"revision":9007199254740991,"kind":"terrain_gravel","x":0,"y":0,"end_x":15,"end_y":15,"radius":3,"stroke":Landscape.encode_stroke(points)}}
	assert(JSON.stringify(maximum).to_utf8_buffer().size()<=1024,"Full terrain strokes fit the existing network packet limit")
	before=world.snapshot()
	assert(not edit({"type":"landscape","kind":"terrain_raise","x":0,"y":0,"end_x":1,"end_y":1,"stroke":"zz"}).ok and world.snapshot()==before)
	require_edit({"type":"landscape","kind":"diagonal_wall","x":0,"y":0,"end_x":2,"end_y":2})
	assert(lot.diagonal_walls.size()==3)
	require_edit({"type":"place","kind":"door","x":1,"y":1})
	assert(lot.diagonal_walls.has("1,1"),"Doorways retain the diagonal wall direction")
	require_edit({"type":"build_undo"}); assert(lot.diagonal_walls.has("1,1"))
	require_edit({"type":"build_cancel"})
	assert(lot.landscape.pools.is_empty() and lot.diagonal_walls.is_empty())
	# Build a two-storey fixture exclusively through the command boundary.
	lot.floors=[]; lot.walls=[]; lot.doors=[]; lot.objects=[]; lot.windows={}; lot.finishes={"floor":{},"wall":{}}
	require_edit({"type":"build_begin"})
	require_edit({"type":"place_area","kind":"floor","x":3,"y":3,"end_x":10,"end_y":10})
	require_edit({"type":"place","kind":"stairs","x":6,"y":6})
	assert(not edit({"type":"build_end"}).ok,"Stairs require an upper landing")
	require_edit({"type":"place_area","level":1,"kind":"floor","x":4,"y":4,"end_x":9,"end_y":9})
	require_edit({"type":"place","level":1,"kind":"bed","x":4,"y":4})
	require_edit({"type":"place","level":1,"kind":"floor_lamp","x":9,"y":9})
	var upper := Storeys.view(lot,1)
	assert(upper.objects.size()==2 and lot.objects.size()==1,"Separate floor occupancy")
	require_edit({"type":"build_undo"}); assert(Storeys.view(lot,1).objects.size()==1)
	require_edit({"type":"build_redo"}); assert(Storeys.view(lot,1).objects.size()==2)
	require_edit({"type":"build_end"})
	var saved := world.snapshot_for_save()
	var restored = World.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(saved))))
	assert(restored.state.lots.lot_1.storeys["1"].objects.size()==2,"Upper floors survive JSON saves")
	var corrupt := saved.duplicate(true); corrupt.lots.lot_1.storeys["1"].objects[0].id=lot.objects[0].id
	assert(not restored.restore(corrupt),"Object identities remain unique across floors")
	var result := world.apply_command("builder",{"type":"use_stairs","member_id":resident.id,"direction":1})
	assert(result.ok,str(result))
	for step in range(160): world.step(0.22)
	assert(resident.level==1 and resident.task.is_empty(),str(resident))
	var bed: Dictionary=Storeys.view(lot,1).objects[0]
	result=world.apply_command("builder",{"type":"interact","member_id":resident.id,"target_id":bed.id,"level":1})
	assert(result.ok,str(result))
	for step in range(160): world.step(0.22)
	assert(resident.needs.energy>90,"Upstairs furnishings work in live simulation")
	var table: Dictionary=world._new_object("game_table",7,4,0)
	lot.storeys["1"].objects.append(table)
	var gathering: Dictionary=world.recreation_option("builder",str(resident.id),str(lot.id),table.id,true)
	assert(gathering.ok and gathering.orders.size()==1 and gathering.orders[0].member_id==resident.id,"Upstairs recreation excludes household members on another floor")
	lot.storeys["1"].objects.erase(table)
	result=world.apply_command("builder",{"type":"use_stairs","member_id":resident.id,"direction":-1})
	assert(result.ok,str(result))
	for step in range(160): world.step(0.22)
	assert(resident.level==0,"Stairs connect in both directions")
	world.ensure_family("neighbor","Morgan")
	resident.level=1
	var travel: Dictionary=world.travel_option("builder","lot_2",[resident.id])
	assert(travel.ok)
	assert(world.apply_command("builder",{"type":"travel_household","member_id":resident.id,"lot_id":"lot_2","travelers":[resident.id],"orders":travel.orders}).ok)
	assert(resident.level==0 and resident.lot_id=="lot_2","Travelling from upstairs arrives at the destination street")
	var legacy := saved.duplicate(true); legacy.schema=2; legacy.lots.lot_1.erase("storeys")
	assert(restored.restore(legacy) and restored.state.schema==3,"Explicit v2 save migration")
	print("BUILD_OVERHAUL_PASS"); quit()
