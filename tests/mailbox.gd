extends SceneTree
const World = preload("res://game/world.gd")
const Mailbox = preload("res://game/mailbox.gd")
var world: RefCounted

func _initialize() -> void:
	call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize()
	world.ensure_family("a","Alex"); world.ensure_family("b","Violet"); world.ensure_family("c","Sam")
	world.set_online("a",true)

func _send(to: String="b", gift: int=100, note: String="Your new room looks lovely!") -> Dictionary:
	return {"type":"mail_send","recipient":to,"gift":gift,"note":note,"sequence":world.state.families.a.mailbox.next_sent}

func _command(owner: String, type: String, id: String) -> Dictionary:
	return world.apply_command(owner,{"type":type,"id":id})

func _run() -> void:
	_fresh()
	var command := _send()
	assert(world.apply_command("a",command).ok)
	var inbox: Dictionary=world.state.families.b.mailbox
	assert(not world.state.families.b.online and inbox.items.size()==1 and Mailbox.unread(inbox)==1,"Mail reaches absent households")
	assert(world.state.lots.lot_1.funds==11900 and world.state.lots.lot_2.funds==12000,"Gifts are debited into escrow")
	var id: String=inbox.items[0].id
	var before: Dictionary=world.snapshot()
	assert(not world.apply_command("a",command).ok and world.state==before,"Repeating a sent sequence is atomic and cannot charge twice")
	assert(not world.apply_command("a",_send()).ok,"One postcard per neighbor per day")
	assert(world.apply_command("a",_send("c",0)).ok,"Other neighbors have their own daily allowance")
	assert(not _command("a","mail_claim",id).ok and not _command("c","mail_read",id).ok,"Only the recipient owns their inbox")
	assert(not _command("b","mail_archive",id).ok and not _command("b","mail_claim",id).ok)
	assert(_command("b","mail_read",id).ok and Mailbox.unread(inbox)==0)
	assert(not _command("b","mail_archive",id).ok,"Unread gifts cannot be discarded")
	assert(_command("b","mail_claim",id).ok and world.state.lots.lot_2.funds==12100)
	assert(_command("b","mail_claim",id).ok and world.state.lots.lot_2.funds==12100,"Gift collection is idempotent")
	var saved: Dictionary=world.snapshot_for_save()
	var loaded := World.new()
	assert(loaded.restore(JSON.parse_string(JSON.stringify(saved))))
	assert(loaded.apply_command("b",{"type":"mail_claim","id":id}).ok and loaded.state.lots.lot_2.funds==12100,"Reload cannot claim a gift twice")
	assert(_command("b","mail_archive",id).ok and inbox.items.is_empty())
	assert(not world.apply_command("a",command).ok,"Archiving cannot make an old send repeatable")
	world.state.day+=1
	assert(world.apply_command("a",_send("b",250)).ok)
	assert(inbox.items[0].id!=id and inbox.items[0].day==2)
	_fresh()
	for patch in [{"recipient":"a"},{"recipient":"missing"},{"gift":-100},{"gift":99},{"gift":100.5},{"gift":"100"},{"note":" "},{"note":"Line\nbreak"},{"note":"x".repeat(121)},{"sequence":2},{"sequence":0},{"sequence":"1"}]:
		command=_send(); command.merge(patch,true); before=world.snapshot()
		assert(not world.apply_command("a",command).ok and world.state==before,"Malformed postcards must not debit or consume a send")
	world.state.lots.lot_1.funds=99; before=world.snapshot()
	assert(not world.apply_command("a",_send()).ok and world.state==before)
	_fresh()
	for day in range(1,Mailbox.CAPACITY+1):
		world.state.day=day; assert(world.apply_command("a",_send("b",0)).ok)
	world.state.day+=1; before=world.snapshot()
	assert(not world.apply_command("a",_send()).ok and world.state==before,"A full mailbox never drops old unread postcards or charges sender")
	id=world.state.families.b.mailbox.items[-1].id
	assert(_command("b","mail_read",id).ok and _command("b","mail_archive",id).ok)
	assert(world.apply_command("a",_send()).ok)
	# Receiving during a reversible building edit changes every budget exactly once.
	_fresh(); assert(world.apply_command("a",_send()).ok)
	id=world.state.families.b.mailbox.items[0].id
	assert(world.apply_command("b",{"type":"build_begin","lot_id":"lot_2"}).ok)
	assert(world.apply_command("b",{"type":"place","lot_id":"lot_2","kind":"floor","x":1,"y":1}).ok)
	var price: int=12000-int(world.state.lots.lot_2.funds)
	assert(_command("b","mail_read",id).ok and _command("b","mail_claim",id).ok)
	assert(world.state.lots.lot_2.funds==12100-price)
	assert(world.apply_command("b",{"type":"build_undo","lot_id":"lot_2","revision":world.state.lots.lot_2.revision}).ok and world.state.lots.lot_2.funds==12100)
	assert(world.apply_command("b",{"type":"build_redo","lot_id":"lot_2","revision":world.state.lots.lot_2.revision}).ok and world.state.lots.lot_2.funds==12100-price)
	saved=world.snapshot_for_save(); assert(saved.lots.lot_2.funds==12100 and loaded.restore(saved))
	assert(loaded.apply_command("b",{"type":"mail_claim","id":id}).ok and loaded.state.lots.lot_2.funds==12100)
	assert(world.apply_command("b",{"type":"build_cancel","lot_id":"lot_2"}).ok and world.state.lots.lot_2.funds==12100)
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(not world.apply_command("a",_send("c")).ok)
	assert(world.apply_command("a",_send("c",0)).ok,"A free postcard is still possible while building")
	# Old saves normalize empty mailboxes; hostile references fail without changing the live world.
	var legacy: Dictionary=saved.duplicate(true)
	for family: Dictionary in legacy.families.values(): family.erase("mailbox")
	assert(loaded.restore(legacy) and loaded.state.families.b.mailbox.items.is_empty())
	for field: String in ["from","id","gift","note","read","sequence"]:
		var bad: Dictionary=saved.duplicate(true)
		bad.families.b.mailbox.items[0][field]={"from":"missing","id":"forged","gift":500,"note":"bad\nline","read":1,"sequence":999}[field]
		before=loaded.snapshot(); assert(not loaded.restore(bad) and loaded.state==before)
	var bad: Dictionary=saved.duplicate(true); bad.families.a.mailbox=[]
	assert(not loaded.restore(bad),"Malformed sender records cannot crash reference validation")
	_fresh(); world.state.lots.lot_2.funds=1000000000
	assert(world.apply_command("a",_send()).ok); id=world.state.families.b.mailbox.items[0].id
	assert(_command("b","mail_read",id).ok); before=world.snapshot()
	assert(not _command("b","mail_claim",id).ok and world.state==before,"A full balance does not lose an unclaimed gift")
	var packet := {"type":"command","id":2147483647,"intent":{"type":"mail_send","recipient":"x".repeat(128),"note":"🌿".repeat(Mailbox.NOTE_LIMIT),"gift":250,"sequence":999999999}}
	assert(JSON.stringify(packet).to_utf8_buffer().size()<=1024,"The longest postcard fits an Iroh command packet")
	print("MAILBOX_PASS")
	quit()
