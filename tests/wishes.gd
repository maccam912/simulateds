extends SceneTree
const World = preload("res://game/world.gd")
const Wishes = preload("res://game/wishes.gd")
var world = World.new()
var member: Dictionary
var family: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _request(id: String) -> Dictionary:
	return world.apply_command("wish",{"type":"pursue_wish","member_id":member.id,"wish_id":id})

func _finish_activity() -> void:
	for index in range(350):
		world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false,"Directed activity did not finish")

func _run() -> void:
	world.initialize(); world.ensure_family("wish","Alex"); world.set_online("wish",true)
	family=world.state.families.wish
	member=family.members[0]
	for resident: Dictionary in family.members: resident.autonomy=false
	member.wishes={"day":1,"round":0,"wishes":[{"id":"story","done":false},{"id":"greenery","done":false},{"id":"tea","done":false}],"journal":[]}
	var lot: Dictionary=world.state.lots.lot_1
	var funds: int=lot.funds
	for need: String in member.needs: member.needs[need]=100.0
	var before: Dictionary=world.snapshot()
	var suggestion: Dictionary=world.wish_option("wish",member.id,"story")
	assert(suggestion.available and suggestion.label.contains("Reading") and suggestion.commitment.contains(member.name))
	assert(world.snapshot()==before,"Previewing a wish cannot order or reward it")
	assert(not world.apply_command("wish",{"type":"pursue_wish","member_id":member.id,"wish_id":"story","target_id":"stale"}).ok)
	assert(world.snapshot()==before,"A changed preview cannot switch targets or complete a wish")
	assert(_request("story").ok)
	# Even at full fun, a directed leisure session lasts long enough to read.
	for index in range(10): world.step(0.1)
	assert(Wishes.completed(member.wishes)==0,"A wish is earned on completion, not queued")
	assert(not _request("story").ok,"An activity already in the plan is not duplicated")
	_finish_activity()
	assert(Wishes.completed(member.wishes)==1 and lot.funds==funds+40)
	assert(member.wishes.journal.size()==1)
	assert(not _request("story").ok,"Completed wishes cannot pay twice")
	assert(_request("greenery").ok); _finish_activity()
	assert(_request("tea").ok); _finish_activity()
	assert(Wishes.completed(member.wishes)==3 and lot.funds==funds+200,"Three modest rewards plus one set bonus")
	assert(member.wishes.journal.size()==3)
	assert(not world.apply_command("wish",{"type":"renew_wishes","member_id":member.id}).ok,"No same-day reward loop")
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(replica.state.families.wish.members[0].wishes==member.wishes,"Wishes and journal replicate with JSON")
	var saved: Dictionary=world.snapshot_for_save()
	assert(replica.restore(JSON.parse_string(JSON.stringify(saved))))
	assert(replica.state.lots.lot_1.funds==lot.funds and Wishes.completed(replica.state.families.wish.members[0].wishes)==3,"Rewards survive save/load once")
	world.state.day_minutes=1439.5; world.step(1.0)
	assert(world.apply_command("wish",{"type":"renew_wishes","member_id":member.id}).ok)
	assert(Wishes.completed(member.wishes)==0 and int(member.wishes.day)==2 and member.wishes.journal.size()==3)
	var unfinished: Dictionary=member.wishes.duplicate(true)
	world.set_online("wish",false)
	var offline_funds: int=lot.funds
	for index in range(1100): world.step(1.0)
	assert(member.wishes==unfinished,"Unfinished wishes never expire while absent")
	assert(lot.funds==offline_funds+1200,"Absence earns only existing living allowances, no wish rewards")
	world.set_online("wish",true)
	# Explicit cancellation never completes a wish.
	var id: String=member.wishes.wishes[0].id
	assert(_request(id).ok)
	world.apply_command("wish",{"type":"cancel","member_id":member.id})
	assert(Wishes.completed(member.wishes)==0)
	world.ensure_family("other","Violet")
	assert(not world.apply_command("other",{"type":"pursue_wish","member_id":member.id,"wish_id":id}).ok)
	# Autonomous completion must not earn the directed-play rewards.
	var bookshelf: Dictionary={}
	for object: Dictionary in lot.objects:
		if object.kind=="bookshelf": bookshelf=object
	member.wishes.wishes=[{"id":"story","done":false},{"id":"company","done":false},{"id":"rest","done":false}]
	member.x=9; member.y=10; member.needs.fun=0.0
	world._queue_action(member,{"type":"interact","target_id":bookshelf.id,"automatic":true})
	_finish_activity()
	assert(Wishes.completed(member.wishes)==0,"Autonomy cannot farm wishes")
	# An idle conversation partner stays engaged, but their own commands win.
	var companion: Dictionary=family.members[1]
	world._clear_member(member); world._clear_member(companion)
	member.x=7; member.y=7; companion.x=8; companion.y=7; companion.autonomy=true
	assert(_request("company").ok)
	world.step(0.5)
	assert(companion.task.is_empty() and str(companion.action).begins_with("Chatting"))
	assert(world.apply_command("wish",{"type":"move","member_id":companion.id,"lot_id":"lot_1","x":9,"y":7}).ok)
	assert(companion.task.type=="move","Conversation never overrides a player's order")
	world._clear_member(member); world._clear_member(companion)
	member.x=7; member.y=7; companion.x=8; companion.y=7
	assert(_request("company").ok); _finish_activity()
	assert(Wishes.completed(member.wishes)==1,"A completed conversation fulfills its initiator's wish")
	var malformed: Dictionary=world.snapshot()
	malformed.families.wish.members[0].wishes.wishes[0].id="unknown"
	assert(not replica.restore(malformed),"Unknown wish save rejected atomically")
	var legacy: Dictionary=world.snapshot()
	for household: Dictionary in legacy.families.values():
		for resident: Dictionary in household.members: resident.erase("wishes")
	assert(replica.restore(legacy),"Old saves receive personal wishes")
	assert(replica.state.families.wish.members[0].wishes.wishes.size()==3)
	var board := Wishes.create("journal",1)
	for day in range(1,20):
		board=Wishes.create("journal",day,day,board.journal)
		for wish: Dictionary in board.wishes: Wishes.record(board,str(Wishes.CATALOG[wish.id].activity),day)
	assert(board.journal.size()==Wishes.MAX_JOURNAL and Wishes.valid(board,20),"Journal remains bounded over many sets")
	print("WISHES_PASS")
	quit()
