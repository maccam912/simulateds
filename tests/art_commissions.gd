extends SceneTree
const World=preload("res://game/world.gd")
const Jobs=preload("res://game/art_commissions.gd")
const Art=preload("res://game/wall_art.gd")
const Paintings=preload("res://game/paintings.gd")
var world: RefCounted
var home: Dictionary
var member: Dictionary
var easel: Dictionary
var board: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]: world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
	for family: Dictionary in world.state.families.values():
		for resident: Dictionary in family.members: resident.autonomy=false
	home=world.state.lots.lot_1; member=world.state.families.a.members[0]; board=world.state.families.a.commissions
	easel=world._new_object("easel",9,9,0); home.objects.append(easel)
func _intent(type: String) -> Dictionary:
	return {"type":type,"commission_revision":board.revision,"offer":Jobs.offer("a",board).id}
func _paint(subject: String) -> void:
	assert(world.apply_command("a",{"type":"painting","member_id":member.id,"target_id":easel.id,"action":"start","subject":subject,"revision":easel.painting.revision}).ok)
	for tick in range(400):
		world.step(0.1)
		if member.task.is_empty(): break
	assert(Paintings.finished(easel.painting))
func _delivery(source: String="") -> Dictionary:
	if source.is_empty(): source="easel:"+str(easel.id)
	var intent:=_intent("commission_deliver")
	intent.merge({"art_source":source,"art_id":Art.source(home,source).get("art_id",""),"revision":home.revision})
	return intent
func _reject(intent: Dictionary,owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Rejected commissions cannot pay, consume artwork, or change progress")
func _run() -> void:
	_fresh(); assert(Jobs.valid(board,"a",1))
	var original: Dictionary=world.snapshot(); var preview:=Jobs.offer("a",board)
	assert(Jobs.candidates(world.state,"a").is_empty() and world.snapshot()==original)
	for change: Dictionary in [{"commission_revision":-1},{"commission_revision":0.5},{"commission_revision":NAN},{"offer":"missing"},{"lot_id":"lot_2"}]:
		var bad:=_intent("commission_accept"); bad.merge(change,true); _reject(bad)
	var stale:=_intent("commission_accept"); assert(world.apply_command("a",stale).ok); _reject(stale)
	assert(board.active.offer==preview.id and home.funds==12000)
	# Cancellation is free and cannot reroll the offer or consume a delivery day.
	assert(world.apply_command("a",_intent("commission_cancel")).ok)
	assert(Jobs.offer("a",board)==preview and board.completed==0 and board.completed_day==0)
	assert(world.apply_command("a",_intent("commission_accept")).ok)
	# Accepted terms wait during absence, across days, and through save/reconnect restore.
	world.set_online("a",false); var accepted: Dictionary=board.duplicate(true)
	for tick in range(600): world.step(1.0)
	assert(board==accepted and int(world.state.day)>1)
	var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.families.a.commissions==accepted)
	world.set_online("a",true)
	var wrong_subject: String="flowers" if preview.subject!="flowers" else "meadow"
	_paint(wrong_subject); _reject(_delivery())
	assert(Jobs.candidates(world.state,"a").is_empty(),"Only the requested subject is offered for review")
	assert(world.apply_command("a",{"type":"painting","member_id":member.id,"target_id":easel.id,"action":"sell","revision":easel.painting.revision}).ok)
	for tick in range(100): world.step(0.1)
	_paint(preview.subject)
	var before_funds: int=home.funds; var picture: Dictionary=easel.painting.duplicate(true)
	var receipt_id: String=Art.source(home,"easel:"+str(easel.id)).art_id
	var choices:=Jobs.candidates(world.state,"a"); assert(choices.size()==1 and choices[0].available and choices[0].picture==picture)
	assert(choices[0].findable and choices[0].location=="Daydream easel · Ground floor" and choices[0].location_detail.contains("9, 9"))
	var delivery:=_delivery()
	for change: Dictionary in [{"art_id":"wrong"},{"art_source":[]},{"revision":-1},{"revision":0.5},{"lot_id":"lot_2"},{"commission_revision":0}]:
		var bad:=delivery.duplicate(true); bad.merge(change,true); _reject(bad)
	_reject(delivery,"b")
	# A planned sale and construction each preserve the original and request.
	assert(world.apply_command("a",{"type":"painting","member_id":member.id,"target_id":easel.id,"action":"sell","subject":"","revision":easel.painting.revision}).ok)
	_reject(delivery); assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":home.id}).ok); _reject(_delivery())
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":home.id}).ok); easel=world._object(home,str(easel.id)); delivery=_delivery()
	home.funds=1000000000; _reject(delivery); home.funds=before_funds
	var hobbies: Dictionary=member.hobbies.duplicate(true); var next_action: int=member.next_action
	assert(world.apply_command("a",delivery).ok); _reject(delivery)
	assert(home.funds==before_funds+180 and easel.painting.subject=="" and board.completed==1 and board.active.is_empty())
	assert(board.history[0].art_id==receipt_id and board.history[0].credit==Paintings.credit(picture) and member.hobbies==hobbies and member.next_action==next_action)
	assert(not Jobs.accept_status(board,int(world.state.day)).is_empty()); _reject(_intent("commission_accept"))
	var paid: Dictionary=world.snapshot_for_save(); assert(replica.restore(JSON.parse_string(JSON.stringify(paid))))
	assert(replica.state.families.a.commissions==board and replica.state.lots.lot_1.funds==home.funds)
	# A delivery receipt cannot coexist with the original at home or in live mail escrow.
	var corrupt:=paid.duplicate(true); corrupt.lots.lot_1.objects[-1].painting=picture; assert(not replica.restore(corrupt))
	# A mounted original is reviewed and removed without demolishing the wall.
	world.state.day+=1; assert(world.apply_command("a",_intent("commission_accept")).ok); preview=Jobs.offer("a",board); _paint(preview.subject)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":home.id}).ok)
	assert(world.apply_command("a",{"type":"art_hang","lot_id":home.id,"source":"easel:"+str(easel.id),"x":8,"y":3,"revision":home.revision}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":home.id}).ok)
	assert(Jobs.candidates(world.state,"a")[0].location=="Hanging on a wall · Ground floor" and Jobs.candidates(world.state,"a")[0].findable)
	var art_id: String=home.artworks.keys()[0]; var walls: Array=home.walls.duplicate(true)
	assert(world.apply_command("a",_delivery("art:"+art_id)).ok and home.artworks.is_empty() and home.walls==walls)
	assert(not world.apply_command("a",{"type":"build_undo","lot_id":home.id}).ok)
	# Further commissions stay bounded and retain only four receipts.
	for count in range(5):
		world.state.day+=1; assert(world.apply_command("a",_intent("commission_accept")).ok); preview=Jobs.offer("a",board)
		_paint(preview.subject); assert(world.apply_command("a",_delivery()).ok)
	assert(board.completed==7 and board.history.size()==4 and Jobs.valid(board,"a",int(world.state.day)))
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	# Additive migration preserves every pre-commission save field and creates no reward.
	var legacy: Dictionary=world.snapshot_for_save(); legacy.families.a.erase("commissions"); legacy.families.b.erase("commissions")
	assert(replica.restore(legacy) and replica.state.families.a.commissions==Jobs.create() and replica.state.lots.lot_1.funds==home.funds)
	for invalid: Variant in [null,{},[],{"revision":0,"active":{},"completed":1,"completed_day":0,"history":[]}]:
		corrupt=paid.duplicate(true); corrupt.families.a.commissions=invalid; assert(not replica.restore(corrupt))
	for field: String in ["revision","completed","completed_day"]:
		for value: Variant in [-1,0.5,NAN,INF,1000000001]:
			corrupt=paid.duplicate(true); corrupt.families.a.commissions[field]=value; assert(not replica.restore(corrupt))
	corrupt=paid.duplicate(true); corrupt.families.a.commissions.history[0].credit="Bad\ncredit"; assert(not replica.restore(corrupt))
	corrupt=paid.duplicate(true); corrupt.families.a.commissions.history[0].offer="missing"; assert(not replica.restore(corrupt))
	# A received original may be delivered from the collection, keeping the actual artist's credit.
	_fresh(); assert(world.apply_command("a",_intent("commission_accept")).ok)
	var neighbor: Dictionary=world.state.lots.lot_2; var artist: Dictionary=world.state.families.b.members[0]
	var other_easel: Dictionary=world._new_object("easel",9,9,0); neighbor.objects.append(other_easel)
	assert(world.apply_command("b",{"type":"painting","member_id":artist.id,"target_id":other_easel.id,"action":"start","subject":Jobs.offer("a",board).subject,"revision":0}).ok)
	for tick in range(400): world.step(0.1)
	assert(Paintings.finished(other_easel.painting))
	var gift_id: String=Art.source(neighbor,"easel:"+str(other_easel.id)).art_id
	assert(world.apply_command("b",{"type":"mail_send","recipient":"a","note":"For your community request.","gift":0,"sequence":1,"art_source":"easel:"+str(other_easel.id),"art_id":gift_id,"revision":neighbor.revision}).ok)
	var card: Dictionary=world.state.families.a.mailbox.items[0]
	assert(world.apply_command("a",{"type":"mail_read","id":card.id}).ok)
	assert(world.apply_command("a",{"type":"mail_claim","id":card.id}).ok)
	assert(Jobs.candidates(world.state,"a")[0].location=="In your collection" and not Jobs.candidates(world.state,"a")[0].findable)
	assert(world.apply_command("a",_delivery("art:"+gift_id)).ok and home.artworks.is_empty())
	assert(board.history[0].credit=="By B" and member.hobbies.painting.sessions==0 and card.claimed)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))),"A claimed mail receipt may remember an original that was subsequently delivered")
	corrupt=world.snapshot_for_save(); corrupt.families.a.mailbox.items[0].claimed=false
	assert(not replica.restore(corrupt),"Delivered originals cannot be reclaimed from mail escrow")
	var packet: Dictionary={"type":"command","id":2147483647,"intent":{"type":"commission_deliver","lot_id":"lot_4","offer":"reading_room_1","commission_revision":999999999,"revision":9007199254740000,"art_source":"art:art_object_9007199254740000_1000000000","art_id":"art_object_9007199254740000_1000000000"}}
	assert(JSON.stringify(packet).to_utf8_buffer().size()<=1024)
	print("ART_COMMISSIONS_PASS"); quit()
