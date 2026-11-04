extends SceneTree
const World = preload("res://game/world.gd")
const Actions = preload("res://game/context_actions.gd")
var world: RefCounted
var lot: Dictionary
var member: Dictionary
var other: Dictionary

func _initialize() -> void: call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize()
	for profile: String in ["a","b"]:
		world.ensure_family(profile,profile); world.set_online(profile,true)
		for resident: Dictionary in world.state.families[profile].members: resident.autonomy=false
	lot=world.state.lots.lot_1; member=world.state.families.a.members[0]; other=world.state.families.a.members[1]

func _entries(target: Dictionary, profile: String="a", selected: String="a_1") -> Array:
	var before: Dictionary=world.snapshot()
	var result := Actions.options(world,profile,selected,lot.id,target)
	assert(world.snapshot()==before,"Opening a context menu cannot change plans, needs, funds or identities")
	return result.entries

func _find(entries: Array, id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.id==id: return entry
	assert(false,"Missing radial action: "+id)
	return {}

func _run() -> void:
	_fresh()
	for object: Dictionary in lot.objects:
		var use := _find(_entries({"type":"object","id":object.id}),"use")
		assert(not use.disabled and use.command.target_id==object.id and use.command.member_id==member.id)
	var shower: Dictionary=world._object_at(lot,Vector2i(11,6))
	var use := _find(_entries({"type":"object","id":shower.id}),"use")
	assert(world.apply_command("a",use.command).ok and member.task.target_id==shower.id)
	var walk := _find(_entries({"type":"ground","x":7,"y":6}),"walk")
	assert(walk.label=="Queue walk" and world.apply_command("a",walk.command).ok and member.queue[0].type=="move")
	assert(_find(_entries({"type":"ground","x":11,"y":6}),"walk").disabled)
	assert(_find(_entries({"type":"object","id":shower.id},"b","b_1"),"use").disabled)
	_fresh()
	var own := _entries({"type":"member","id":other.id})
	assert(_find(own,"select").member_id==other.id and _find(own,"needs").member_id==other.id)
	assert(not _find(own,"chat").disabled)
	assert(world.apply_command("a",_find(own,"chat").command).ok)
	assert(_find(_entries({"type":"member","id":other.id}),"chat").disabled)
	var neighbor: Dictionary=world.state.families.b.members[0]; neighbor.lot_id=lot.id; neighbor.x=9; neighbor.y=7
	var social := _entries({"type":"member","id":neighbor.id})
	assert(social.all(func(entry): return not entry.has("member_id") and not entry.get("navigate","") in ["select","needs","plan","wishes","hobbies"]))
	assert(_find(social,"chat").command.member_id==member.id)
	for kind: String in ["game_table","stereo","garden_bed","easel","dining_table"]:
		_fresh()
		var object: Dictionary=world._new_object(kind,8,5,0); lot.objects.append(object)
		var choices := _entries({"type":"object","id":object.id})
		var key: String={"game_table":"call","stereo":"play","garden_bed":"radish","easel":"meadow","dining_table":"salad"}[kind]
		var entry := _find(choices,key)
		assert(not entry.disabled,kind+": "+entry.tooltip)
		assert(world.apply_command("a",entry.command).ok,kind+" sends a valid existing command")
		assert(_find(_entries({"type":"object","id":object.id}),key).disabled,kind+" reflects accepted planned work")
		_fresh(); object=world._new_object(kind,8,5,0); lot.objects.append(object)
		entry=_find(_entries({"type":"object","id":object.id}),key)
		if kind in ["game_table","stereo"]: lot.revision+=1
		elif kind=="garden_bed": object.garden.revision+=1
		elif kind=="easel": object.painting.revision+=1
		else: object.meal.batch+=1
		var before: Dictionary=world.snapshot()
		assert(not world.apply_command("a",entry.command).ok and world.snapshot()==before,kind+" rejects an obsolete radial choice atomically")
		var guest := _entries({"type":"object","id":object.id},"b","b_1")
		assert(_find(guest,key).disabled,kind+" cannot direct a resident who has not visited")
	_fresh()
	var table: Dictionary=world._new_object("dining_table",8,5,0); lot.objects.append(table)
	table.meal={"recipe":"salad","servings":4,"batch":1,"cook":member.id,"cook_name":member.name,"day":1}
	var food := _entries({"type":"object","id":table.id})
	for key: String in ["eat","call","clear"]: assert(not _find(food,key).disabled)
	assert(world.apply_command("a",_find(food,"call").command).ok)
	assert(member.task.meal_action=="eat" and other.task.meal_action=="eat")
	lot.building=true
	assert(_find(_entries({"type":"object","id":table.id}),"eat").disabled)
	# Joining follows the exact companion activity that was shown.
	for kind: String in ["game_table","stereo","dining_table"]:
		_fresh(); table=world._new_object(kind,8,5,0); lot.objects.append(table)
		if kind=="dining_table":
			table.meal={"recipe":"salad","servings":4,"batch":1,"cook":member.id,"cook_name":member.name,"day":1}
			assert(world.apply_command("a",_find(_entries({"type":"object","id":table.id},"a",other.id),"eat").command).ok)
		else: assert(world.apply_command("a",_find(_entries({"type":"object","id":table.id},"a",other.id),"play").command).ok)
		var join := _find(_entries({"type":"member","id":other.id}),"join")
		assert(not join.disabled and join.command.activity_id==other.task.id)
		assert(world.apply_command("a",join.command).ok)
		assert(_find(_entries({"type":"member","id":other.id}),"join").disabled)
	_fresh()
	lot.artworks.context_picture={"x":8,"y":3,"picture":{"subject":"harbor","progress":24.0,"revision":1,"artists":[{"id":member.id,"name":member.name}],"day":1}}
	var painting := _entries({"type":"wall_art","id":"context_picture"})
	var admire := _find(painting,"admire")
	assert(not admire.disabled and admire.command.x==8 and admire.command.y==3)
	assert(_find(painting,"hang").source=="art:context_picture")
	lot.artworks.context_picture.x=7
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command("a",admire.command).ok and world.snapshot()==before,"Moved paintings reject the old viewing spot")
	print("CONTEXT_ACTIONS_PASS")
	quit()
