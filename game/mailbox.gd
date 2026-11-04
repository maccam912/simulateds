extends RefCounted
## Bounded household postcards. Gifts remain in escrow until explicitly collected.
const HomeNews = preload("res://game/home_news.gd")
const CAPACITY := 24
const NOTE_LIMIT := 120
const GIFTS := [0,100,250]
const MAX_SEQUENCE := 1000000000

static func create(day: int) -> Dictionary:
	return {"items":[],"next_sent":1,"sent_day":day,"sent_to":[]}

static func unread(box: Dictionary) -> int:
	var count := 0
	for item: Dictionary in box.get("items",[]):
		if not item.read: count+=1
	return count

static func item(box: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in box.get("items",[]):
		if entry.id==id: return entry
	return {}

static func sent_today(box: Dictionary, recipient: String, day: int) -> bool:
	return int(box.get("sent_day",0))==day and box.get("sent_to",[]).has(recipient)

static func valid_note(value: Variant) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length()>NOTE_LIMIT: return false
	for index in range(value.length()):
		if value.unicode_at(index)<32 or value.unicode_at(index)==127: return false
	return true

static func apply(world: Dictionary, owner: String, command: Dictionary, adjust_funds: Callable) -> Dictionary:
	var family: Dictionary=world.families[owner]
	var box: Dictionary=family.mailbox
	if command.type=="mail_send":
		var recipient: Variant=command.get("recipient")
		if not recipient is String or recipient==owner or not world.families.has(recipient): return _result(false,"Choose another household in this neighborhood.")
		if not _integer(command.get("sequence"),1,MAX_SEQUENCE-1) or int(command.sequence)!=int(box.next_sent): return _result(false,"This postcard was already sent or the mailbox changed. Reopen Mail to review it.")
		if not valid_note(command.get("note")): return _result(false,"Write a postcard of 1 to 120 characters on one line.")
		if not _integer(command.get("gift"),0,250) or not GIFTS.has(int(command.gift)): return _result(false,"Choose no gift, §100, or §250.")
		if sent_today(box,recipient,int(world.day)): return _result(false,"You already left this household a postcard today. Send another tomorrow.")
		var inbox: Dictionary=world.families[recipient].mailbox
		if inbox.items.size()>=CAPACITY: return _result(false,"Their mailbox is full. They need to archive a read postcard first.")
		var gift := int(command.gift)
		if gift>0 and world.lots[family.home_lot].building: return _result(false,"Finish construction before sending a money gift. A postcard on its own is free.")
		if gift>0 and not adjust_funds.call(str(family.home_lot),-gift): return _result(false,"Your household cannot afford that gift.")
		if int(box.sent_day)!=int(world.day): box.sent_day=int(world.day); box.sent_to.clear()
		box.sent_to.append(recipient)
		var sequence := int(box.next_sent); box.next_sent+=1
		inbox.items.push_front({"id":owner+":"+str(sequence),"from":owner,"sequence":sequence,"day":int(world.day),"note":str(command.note).strip_edges(),"gift":gift,"read":false,"claimed":gift==0})
		var recipient_family: Dictionary=world.families[recipient]
		if HomeNews.away(recipient_family):
			recipient_family.home_news.postcards+=1; recipient_family.home_news.gifts+=gift
		return _result(true,"Postcard delivered. It will be waiting when they return.")
	var id: Variant=command.get("id")
	if not id is String: return _result(false,"Choose a postcard from your mailbox.")
	var entry := item(box,id)
	if entry.is_empty(): return _result(false,"That postcard is not in your mailbox.")
	match command.type:
		"mail_read":
			entry.read=true
			return _result(true,"Postcard opened.")
		"mail_claim":
			if not entry.read: return _result(false,"Open the postcard before collecting its gift.")
			if entry.claimed: return _result(true,"This gift was already collected.")
			if not adjust_funds.call(str(family.home_lot),int(entry.gift)): return _result(false,"Your household has reached the funds limit. The gift will keep waiting.")
			entry.claimed=true
			return _result(true,"Collected §%d. A little something from your neighbor." % int(entry.gift))
		"mail_archive":
			if not entry.read or not entry.claimed: return _result(false,"Read the postcard and collect its gift before archiving it.")
			box.items.erase(entry)
			return _result(true,"Postcard archived.")
	return _result(false,"Unknown mailbox action.")

static func valid(world: Dictionary) -> bool:
	var seen := {}
	# Validate all box shapes first: a postcard may reference a later household.
	for family: Dictionary in world.families.values():
		if not family.has("mailbox"): continue
		var box: Variant=family.mailbox
		if not box is Dictionary or not box.get("items") is Array or box.items.size()>CAPACITY or not _integer(box.get("next_sent"),1,MAX_SEQUENCE) or not _integer(box.get("sent_day"),1,int(world.day)) or not box.get("sent_to") is Array or box.sent_to.size()>3: return false
	for owner: String in world.families:
		var family: Dictionary=world.families[owner]
		if not family.has("mailbox"): continue # Saves from before postcards.
		var box: Variant=family.mailbox
		var recipients := {}
		for recipient: Variant in box.sent_to:
			if not recipient is String or not world.families.has(recipient) or recipient==owner or recipients.has(recipient): return false
			recipients[recipient]=true
		for entry: Variant in box.items:
			if not entry is Dictionary or not entry.get("id") is String or seen.has(entry.id) or not entry.get("from") is String or entry.from==owner or not world.families.has(entry.from): return false
			var sender: Dictionary=world.families[entry.from].get("mailbox",{})
			if not _integer(entry.get("sequence"),1,MAX_SEQUENCE-1) or int(entry.sequence)>=int(sender.get("next_sent",1)) or entry.id!=str(entry.from)+":"+str(int(entry.sequence)): return false
			if not _integer(entry.get("day"),1,int(world.day)) or not valid_note(entry.get("note")) or not _integer(entry.get("gift"),0,250) or not GIFTS.has(int(entry.gift)): return false
			if not entry.get("read") is bool or not entry.get("claimed") is bool: return false
			if (int(entry.gift)==0 and not entry.claimed) or (int(entry.gift)>0 and entry.claimed and not entry.read): return false
			seen[entry.id]=true
	return true

static func normalize(world: Dictionary) -> void:
	for family: Dictionary in world.families.values():
		if not family.has("mailbox"): family.mailbox=create(int(world.day))
		var box: Dictionary=family.mailbox
		box.next_sent=int(box.next_sent); box.sent_day=int(box.sent_day)
		for entry: Dictionary in box.items:
			for field: String in ["sequence","day","gift"]: entry[field]=int(entry[field])

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
