extends SceneTree
const World=preload("res://game/world.gd")
const Overview=preload("res://game/garden_overview.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var world:=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	var home: Dictionary=world.state.lots.lot_1; var family: Dictionary=world.state.families.a
	assert(Overview.inspect(world.state,"missing").is_empty())
	assert(Overview.inspect(world.state,"a").rows.is_empty() and not Overview.inspect(world.state,"a").has_table)
	var bed: Dictionary=world._new_object("garden_bed",5,13,0); home.objects.append(bed)
	var second: Dictionary=world._new_object("garden_bed",10,13,0); home.objects.append(second)
	var before: Dictionary=world.snapshot(); var info:=Overview.inspect(world.state,"a")
	assert(info.rows.size()==2 and info.rows[0].id==bed.id and info.rows[0].status=="Choose seeds" and world.snapshot()==before)
	bed.garden={"crop":"radish","growth":90.0,"water":0.0,"revision":1,"harvests":0}
	second.garden={"crop":"tomato","growth":80.0,"water":0.0,"revision":1,"harvests":0}
	info=Overview.inspect(world.state,"a")
	assert(info.rows[0].status=="Ready · Sell or keep" and info.rows[1].status=="Needs water")
	family.pantry={"radish":12,"tomato":4}; info=Overview.inspect(world.state,"a")
	assert(info.rows[0].status=="Ready · Pantry needs room" and info.bowls==2)
	var guest: Dictionary=world.state.families.b.members[0]
	assert(world.apply_command("b",{"type":"visit","member_id":guest.id,"lot_id":home.id}).ok)
	assert(world.apply_command("b",{"type":"garden","member_id":guest.id,"lot_id":home.id,"target_id":second.id,"action":"water","crop":"","revision":1}).ok)
	info=Overview.inspect(world.state,"a"); assert(info.rows[1].plan.name==guest.name and info.rows[1].plan.action=="water")
	var duplicate: Dictionary=world.snapshot(); duplicate.families.b.members[0].task.garden_revision=0
	assert(Overview.inspect(duplicate,"a").rows[1].plan.is_empty(),"A stale task does not claim a garden bed")
	assert(Overview.inspect(world.state,"b").rows.is_empty(),"The overview only lists the chosen household's garden")
	assert(world.apply_command("a",{"type":"build_begin","lot_id":home.id}).ok)
	info=Overview.inspect(world.state,"a"); assert(info.building and info.rows.all(func(row): return not row.available and row.status.contains("paused") and row.plan.is_empty()))
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":home.id}).ok)
	second=world._object(home,second.id); second.garden.water=60.0
	info=Overview.inspect(world.state,"a"); assert(info.rows[1].status=="Growing 44% · Water 50%")
	before=world.snapshot(); info.rows[0].title="local presentation"; info.stock.radish.available=0
	assert(world.snapshot()==before,"Presentation dictionaries cannot mutate stored crops or pantry totals")
	print("GARDEN_OVERVIEW_PASS"); quit()
