extends SceneTree
const World = preload("res://game/world.gd")
const Friendships = preload("res://game/friendships.gd")
var world: RefCounted
var first: Dictionary
var second: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize()
	world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	world.set_online("a",true); world.set_online("b",true)
	for family: Dictionary in world.state.families.values():
		for member: Dictionary in family.members:
			member.autonomy=false
			member.wishes.wishes=[{"id":"story","done":false},{"id":"greenery","done":false},{"id":"rest","done":false}]
	first=world.state.families.a.members[0]; second=world.state.families.b.members[0]
	second.lot_id="lot_1"; first.x=7; first.y=7; second.x=8; second.y=7

func _order(owner: String, member: Dictionary, target: Dictionary) -> Dictionary:
	return world.apply_command(owner,{"type":"interact","member_id":member.id,"lot_id":member.lot_id,"target_id":target.id})

func _finish(member: Dictionary) -> void:
	for index in range(300):
		world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false,"Conversation did not finish")

func _bond() -> Dictionary:
	return Friendships.bond(world.state,str(first.id),str(second.id))

func _run() -> void:
	_fresh()
	assert(_bond().is_empty())
	assert(_order("a",first,second).ok)
	assert(not _order("a",first,second).ok,"Duplicate chat orders are rejected")
	assert(_bond().is_empty(),"Queuing a conversation earns nothing")
	_finish(first)
	assert(_bond().score==12 and _bond().today==1 and first.wishes.journal.size()==1 and second.wishes.journal.size()==1)
	assert(_order("b",second,first).ok); _finish(second)
	assert(_bond().score==24 and _bond().today==2,"Both directions share the daily limit")
	assert(_order("a",first,second).ok); _finish(first)
	assert(_bond().score==24,"Extra catch-ups cannot farm friendship")
	world.state.day+=1; world.state.day_minutes=0.0
	assert(_order("a",first,second).ok); _finish(first)
	assert(_order("a",first,second).ok); _finish(first)
	assert(_bond().score==48 and Friendships.title(_bond())=="Friends")
	assert("friends" in str(first.wishes.journal[0].text),"Friendship milestones enter both journals")
	var saved: Dictionary=world.snapshot_for_save()
	var loaded := World.new()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(saved))))
	assert(Friendships.bond(loaded.state,str(first.id),str(second.id)).score==48)
	world.state.families.a.online=false; world.state.families.b.online=false
	var before: Dictionary=world.state.friendships.duplicate(true)
	for index in range(1500): world.step(1.0)
	assert(world.state.friendships==before,"Time away never decays or farms friendship")
	var malformed: Dictionary=saved.duplicate(true)
	malformed.friendships[Friendships.key(str(first.id),str(second.id))].score=101
	assert(not loaded.restore(malformed),"Corrupt affinity is rejected")
	malformed=saved.duplicate(true)
	malformed.friendships[Friendships.key(str(first.id),str(second.id))].b="missing"
	assert(not loaded.restore(malformed),"Unknown resident references are rejected")
	var legacy: Dictionary=saved.duplicate(true); legacy.erase("friendships")
	assert(loaded.restore(legacy) and loaded.state.friendships.size()==2,"Old saves gain housemate bonds without invented meetings")
	_fresh()
	assert(_order("a",first,second).ok and _order("b",second,first).ok)
	_finish(first); _finish(second)
	assert(_bond().score==12 and _bond().today==1,"Simultaneous reciprocal orders count one conversation")
	_fresh()
	assert(_order("a",first,second).ok); world.step(0.5)
	assert(world.apply_command("b",{"type":"move","member_id":second.id,"lot_id":"lot_1","x":9,"y":7}).ok)
	world.step(0.1)
	assert(first.task.is_empty() and _bond().is_empty(),"A partner's own order wins and interrupted chat earns nothing")
	_fresh()
	world.state.families.b.online=false
	assert(_order("a",first,second).ok); _finish(first)
	assert(_bond().is_empty(),"An absent household cannot be farmed for friendship")
	_fresh()
	var bed: Dictionary=world.state.lots.lot_1.objects[0]
	assert(world.apply_command("b",{"type":"interact","member_id":second.id,"lot_id":"lot_1","target_id":bed.id}).ok)
	assert(_order("a",first,second).ok)
	assert(first.task.is_empty() and first.queue.size()==1 and str(first.action).begins_with("Waiting"),"Chat queues behind a busy resident")
	world.apply_command("b",{"type":"cancel","member_id":second.id})
	_finish(first)
	assert(_bond().score==12)
	for day in range(int(world.state.day)+1,int(world.state.day)+8):
		world.state.day=day
		for count in range(2):
			assert(_order("a",first,second).ok); _finish(first)
	assert(_bond().score==100 and Friendships.title(_bond())=="Close friends","Friendship stays bounded")
	print("FRIENDSHIPS_PASS")
	quit()
