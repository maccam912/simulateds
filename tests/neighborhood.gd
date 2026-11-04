extends SceneTree
const World=preload("res://game/world.gd")
const Neighborhood=preload("res://game/neighborhood.gd")
var world: RefCounted
func _initialize() -> void: call_deferred("_run")
func _card(id: String) -> Dictionary:
	for card: Dictionary in Neighborhood.cards(world.state,"a"):
		if card.id==id: return card
	return {}
func _run() -> void:
	world=World.new(); world.initialize()
	assert(Neighborhood.cards(world.state,"a").size()==4)
	assert(_card("lot_1").status=="Available lot" and _card("lot_1").roster=="No household yet")
	for owner: String in ["a","b","c"]:
		world.ensure_family(owner,{"a":"Alex","b":"Violet","c":"Cedar"}[owner])
		for member: Dictionary in world.state.families[owner].members: member.autonomy=false
	world.set_online("a",true); world.set_online("b",true)
	var before: Dictionary=world.snapshot(); var cards:=Neighborhood.cards(world.state,"a")
	assert(world.snapshot()==before,"Browsing the neighborhood is read-only")
	assert(cards[0].status=="Your home · Playing" and cards[0].people.size()==2)
	assert(cards[1].status=="Owner playing" and cards[1].roster=="2 here · Violet, Robin")
	assert(cards[2].status=="Owner away · Caretaker" and cards[2].people.size()==2 and not cards[2].playing)
	var first: Dictionary=world.state.families.a.members[0]
	assert(world.apply_command("a",{"type":"visit","member_id":first.id,"lot_id":"lot_2"}).ok)
	var visitor_card:=_card("lot_2")
	assert(visitor_card.people.size()==3 and visitor_card.people[0].id=="b_1" and visitor_card.people[1].id=="b_2" and visitor_card.people[2].id=="a_1")
	assert(visitor_card.people[0].home and not visitor_card.people[2].home and visitor_card.tooltip.contains("Alex household · Visiting"))
	assert(_card("lot_1").tooltip.contains("Alex · Willow House") and _card("lot_1").people.size()==1)
	for member: Dictionary in world.state.families.b.members: assert(world.apply_command("b",{"type":"visit","member_id":member.id,"lot_id":"lot_3"}).ok)
	assert(_card("lot_2").playing and _card("lot_2").people.size()==1 and _card("lot_2").people[0].id==first.id)
	assert(_card("lot_3").guest_players==1 and _card("lot_3").status=="Owner away · Guests playing" and _card("lot_3").tooltip.contains("Visiting · Player playing"))
	assert(_card("lot_2").tooltip.contains("Violet · Juniper Place") and _card("lot_3").people.size()==4 and not _card("lot_3").playing,"Player availability belongs to the household, not its visitors")
	assert(world.apply_command("a",{"type":"go_home","member_id":first.id}).ok)
	assert(_card("lot_2").roster=="Nobody here" and _card("lot_2").status=="Owner playing")
	world.set_online("b",false)
	assert(_card("lot_2").people.size()==2 and _card("lot_2").status=="Owner away · Caretaker" and _card("lot_3").people.size()==2)
	world.set_online("b",true)
	assert(world.apply_command("a",{"type":"visit","member_id":first.id,"lot_id":"lot_2"}).ok)
	assert(world.apply_command("b",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(_card("lot_2").status=="Under construction · Closed" and _card("lot_2").people.size()==2 and first.lot_id=="lot_1")
	assert(_card("lot_2").tooltip.contains("Visits are closed"))
	assert(world.apply_command("b",{"type":"build_cancel","lot_id":"lot_2"}).ok)
	world.state.families.b.name="Violet's very long household name"
	world.state.families.b.members[0].name="Violet Longsurname"
	world.state.lots.lot_2.name="A newly named home"
	assert(_card("lot_2").name=="A newly named home" and _card("lot_2").roster.contains("Violet Longsurname") and _card("lot_2").tooltip.contains(world.state.families.b.name))
	cards=Neighborhood.cards(world.state,"a")
	world.state.tick+=1; world.state.families.b.members[0].action="A different activity"
	assert(Neighborhood.cards(world.state,"a")==cards,"Unrelated activity changes do not change presence")
	var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(Neighborhood.cards(replica.state,"a")==cards)
	print("NEIGHBORHOOD_PASS"); quit()
