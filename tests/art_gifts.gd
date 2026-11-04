extends SceneTree
const World=preload("res://game/world.gd")
const Paintings=preload("res://game/paintings.gd")
const Art=preload("res://game/wall_art.gd")
const Mailbox=preload("res://game/mailbox.gd")
var world: RefCounted
var lot: Dictionary
var easel: Dictionary
var member: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b","c"]: world.ensure_family(owner,owner.to_upper())
	world.set_online("a",true); lot=world.state.lots.lot_1; member=world.state.families.a.members[0]
	for resident: Dictionary in world.state.families.a.members: resident.autonomy=false
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":lot.id,"kind":"easel","x":9,"y":9}).ok)
	easel=lot.objects[-1]; assert(world.apply_command("a",{"type":"build_end","lot_id":lot.id}).ok)
	_paint("start","meadow"); _finish()
func _paint(action: String,subject: String="") -> void:
	assert(world.apply_command("a",{"type":"painting","lot_id":lot.id,"member_id":member.id,"target_id":easel.id,"action":action,"subject":subject,"revision":easel.painting.revision}).ok)
func _finish() -> void:
	for step in range(400):
		world.step(0.1)
		if member.task.is_empty() and member.queue.is_empty(): return
	assert(false)
func _send(owner: String="a",recipient: String="b",source: String="") -> Dictionary:
	var home: Dictionary=world.state.lots[world.state.families[owner].home_lot]
	if source.is_empty(): source="easel:"+str(easel.id)
	return {"type":"mail_send","recipient":recipient,"note":"A little picture for your new home.","gift":0,"sequence":world.state.families[owner].mailbox.next_sent,"art_source":source,"art_id":Art.source(home,source).get("art_id",""),"revision":home.revision}
func _reject(owner: String,intent: Dictionary) -> void:
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command(owner,intent).ok and world.snapshot()==before,"Rejected gift commands cannot move art, charge funds, or consume a postcard")
func _mail(owner: String,type: String,id: String) -> void: assert(world.apply_command(owner,{"type":type,"id":id}).ok)
func _run() -> void:
	_fresh(); var picture: Dictionary=easel.painting.duplicate(true)
	for change: Dictionary in [{"art_source":[]},{"art_source":"art:missing"},{"art_id":"wrong"},{"revision":-1},{"revision":0.5},{"gift":100},{"recipient":"missing"},{"recipient":"a"},{"sequence":2}]:
		var bad:=_send(); bad.merge(change,true); _reject("a",bad)
	var missing:=_send(); missing.erase("art_id"); _reject("a",missing)
	missing=_send(); missing.erase("revision"); _reject("a",missing)
	_reject("c",_send())
	assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok); _reject("a",_send())
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":lot.id}).ok); easel=world._object(lot,str(easel.id))
	_paint("sell"); _reject("a",_send()); assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok)
	var command:=_send(); var board: Dictionary=member.hobbies.duplicate(true); var funds: int=lot.funds
	assert(world.apply_command("a",command).ok)
	var box: Dictionary=world.state.families.b.mailbox; var card: Dictionary=box.items[0]; var art_id: String=card.art.id
	assert(not world.state.families.b.online and not card.claimed and not card.read and card.art.picture==picture)
	assert(easel.painting.subject=="" and lot.artworks.is_empty() and lot.funds==funds and member.hobbies==board)
	_reject("a",command); _reject("b",{"type":"mail_claim","id":card.id}); _reject("a",{"type":"mail_read","id":card.id})
	var escrow: Dictionary=world.snapshot_for_save(); var replica:=World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(escrow))))
	assert(replica.state.families.b.mailbox.items[0].art.picture==picture and replica.state.lots.lot_1.objects[-1].painting.subject=="")
	_mail("b","mail_read",card.id); _reject("b",{"type":"mail_archive","id":card.id})
	assert(world.apply_command("b",{"type":"build_begin","lot_id":"lot_2"}).ok)
	_reject("b",{"type":"mail_claim","id":card.id})
	assert(world.apply_command("b",{"type":"build_cancel","lot_id":"lot_2"}).ok)
	var recipient: Dictionary=world.state.lots.lot_2
	for index in range(Art.LIMIT): recipient.artworks["art_object_%d_2" % (1000+index)]={"picture":picture.duplicate(true),"x":-1,"y":-1}
	_reject("b",{"type":"mail_claim","id":card.id}); assert(not card.claimed)
	recipient.artworks.clear(); _mail("b","mail_claim",card.id)
	assert(card.claimed and recipient.artworks[art_id]=={"picture":picture,"x":-1,"y":-1})
	var accepted: Dictionary=world.snapshot(); _mail("b","mail_claim",card.id); assert(world.snapshot()==accepted)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))))
	assert(replica.state.lots.lot_2.artworks[art_id].picture==picture)
	# Received originals hang normally, then can be given onward. Receipts are not assets.
	assert(world.apply_command("b",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(world.apply_command("b",{"type":"art_hang","lot_id":"lot_2","source":"art:"+art_id,"x":8,"y":3,"revision":recipient.revision}).ok)
	assert(world.apply_command("b",{"type":"build_end","lot_id":"lot_2"}).ok)
	var onward:=_send("b","c","art:"+art_id); assert(world.apply_command("b",onward).ok)
	assert(recipient.artworks.is_empty() and card.claimed and card.art.picture==picture)
	var third: Dictionary=world.state.families.c.mailbox.items[0]
	_mail("c","mail_read",third.id); _mail("c","mail_claim",third.id)
	assert(world.state.lots.lot_3.artworks[art_id].picture==picture)
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot_for_save()))),"Multiple collected receipts cannot duplicate the original or reject a legitimate onward gift")
	_mail("b","mail_archive",card.id); _reject("b",onward)
	# Corrupt escrow cannot invent or duplicate an owned painting on restore.
	for bad: Variant in [null,{},[],{"id":"bad","picture":picture}]:
		var corrupt: Dictionary=escrow.duplicate(true); corrupt.families.b.mailbox.items[0].art=bad
		var before: Dictionary=replica.snapshot(); assert(not replica.restore(corrupt) and replica.snapshot()==before)
	var corrupt: Dictionary=escrow.duplicate(true); corrupt.families.b.mailbox.items[0].art.picture.progress=1.0
	assert(not replica.restore(corrupt))
	corrupt=escrow.duplicate(true); corrupt.lots.lot_1.objects[-1].painting=picture.duplicate(true)
	assert(not replica.restore(corrupt),"A canvas cannot exist at home and in mail escrow")
	corrupt=world.snapshot(); corrupt.lots.lot_2.artworks[art_id]=corrupt.lots.lot_3.artworks[art_id].duplicate(true)
	assert(not replica.restore(corrupt),"An original cannot belong to two homes")
	# A full inbox preserves the original and leaves the sender's allowance unused.
	_fresh(); picture=easel.painting.duplicate(true)
	for day in range(1,Mailbox.CAPACITY+1):
		world.state.day=day
		assert(world.apply_command("a",{"type":"mail_send","recipient":"b","note":"Hello","gift":0,"sequence":world.state.families.a.mailbox.next_sent}).ok)
	world.state.day+=1; _reject("a",_send()); assert(easel.painting==picture)
	var oldest: String=world.state.families.b.mailbox.items[-1].id
	_mail("b","mail_read",oldest); _mail("b","mail_archive",oldest); assert(world.apply_command("a",_send()).ok)
	# Reusing the same easel must never substitute a new picture into an old draft.
	_fresh(); command=_send(); _paint("sell"); _finish(); _paint("start","harbor"); _finish()
	_reject("a",command); assert(easel.painting.subject=="harbor")
	var packet := {"type":"command","id":2147483647,"intent":{"type":"mail_send","recipient":"x".repeat(128),"note":"🌿".repeat(Mailbox.NOTE_LIMIT),"gift":0,"sequence":999999999,"art_source":"easel:object_9007199254740000","art_id":"art_object_9007199254740000_1000000000","revision":9007199254740000}}
	assert(JSON.stringify(packet).to_utf8_buffer().size()<=1024,"Painting references fit in one existing command packet")
	print("ART_GIFTS_PASS"); quit()
