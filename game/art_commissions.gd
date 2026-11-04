extends RefCounted
## Optional household goals. Offers wait; only reviewed delivery pays or removes art.
const Art=preload("res://game/wall_art.gd")
const Paintings=preload("res://game/paintings.gd")
const Text=preload("res://game/activity_log.gd")
const MAX_REVISION := 1000000000
const HISTORY_LIMIT := 4
## Published terms are immutable; add new IDs for future offer versions.
const ORDER := ["reading_room_1","canal_cafe_1","garden_club_1"]
const OFFERS := {
	"reading_room_1":{"client":"The reading room","subject":"meadow","reward":180,"request":"A calm meadow for the corner beside our books."},
	"canal_cafe_1":{"client":"The canal café","subject":"harbor","reward":180,"request":"A little harbor scene for our coffee nook."},
	"garden_club_1":{"client":"The garden club","subject":"flowers","reward":180,"request":"Flowers to brighten the meeting room."}
}

static func create() -> Dictionary:
	return {"revision":0,"active":{},"completed":0,"completed_day":0,"history":[]}

static func offer_id(owner: String,completed: int) -> String:
	return ORDER[posmod(owner.hash()+completed,ORDER.size())]

static func offer(owner: String,board: Dictionary) -> Dictionary:
	var id:=offer_id(owner,int(board.completed))
	var result: Dictionary=OFFERS[id].duplicate(); result.id=id
	return result

static func accept_status(board: Dictionary,day: int) -> String:
	if not board.active.is_empty(): return "This commission is already accepted."
	if int(board.revision)>=MAX_REVISION-1: return "This commission book has reached its limit."
	if int(board.completed_day)>=day: return "A new commission will be available tomorrow."
	return ""

static func delivery_option(world: Dictionary,owner: String,command: Dictionary) -> Dictionary:
	var family: Dictionary=world.families[owner]; var board: Dictionary=family.commissions
	if not _matches(board,command): return _no("The commission changed. Review the current request.")
	if board.active.is_empty() or command.get("offer")!=board.active.offer: return _no("Accept this household's commission before delivering a painting.")
	if int(board.completed_day)>=int(world.day): return _no("Your household already delivered a commission today.")
	if command.get("lot_id",family.home_lot)!=family.home_lot: return _no("Choose an original from your own home.")
	var plan:=Art.transfer_option(world,owner,command)
	if not plan.ok: return plan
	var terms: Dictionary=OFFERS[board.active.offer]
	if plan.art.picture.subject!=terms.subject: return _no("This commission needs “"+str(Paintings.SUBJECTS[terms.subject])+"”. Choose a matching original.")
	if int(world.lots[family.home_lot].funds)+int(terms.reward)>1000000000: return _no("Make room in the household budget before delivering. The painting and commission will wait.")
	plan.reward=int(terms.reward); plan.offer=str(board.active.offer)
	return plan

static func apply(world: Dictionary,owner: String,command: Dictionary,adjust_funds: Callable) -> Dictionary:
	var family: Dictionary=world.families[owner]; var board: Dictionary=family.commissions
	if not _matches(board,command): return _no("The commission changed. Review the current request.")
	if command.get("lot_id",family.home_lot)!=family.home_lot: return _no("Commissions belong to your own household.")
	var terms:=offer(owner,board)
	if command.get("offer")!=terms.id: return _no("Choose the current commission offer.")
	match command.type:
		"commission_accept":
			var reason:=accept_status(board,int(world.day))
			if not reason.is_empty(): return _no(reason)
			board.active={"offer":terms.id,"day":int(world.day)}; board.revision+=1
			return _yes("Commission accepted · “"+str(Paintings.SUBJECTS[terms.subject])+"” for §%d. No deadline." % int(terms.reward))
		"commission_cancel":
			if board.active.is_empty(): return _no("There is no active commission to put aside.")
			board.active={}; board.revision+=1
			return _yes("Commission put aside. Your paintings stay; the same request remains available.")
		"commission_deliver":
			var plan:=delivery_option(world,owner,command)
			if not plan.ok: return plan
			if not adjust_funds.call(str(family.home_lot),int(plan.reward)): return _no("The household budget cannot receive this payment. Your painting stays.")
			Art.detach(world,plan)
			board.history.push_front({"offer":str(plan.offer),"day":int(world.day),"art_id":str(plan.art.id),"credit":Paintings.credit(plan.art.picture)})
			if board.history.size()>HISTORY_LIMIT: board.history.resize(HISTORY_LIMIT)
			board.completed+=1; board.completed_day=int(world.day); board.active={}; board.revision+=1
			return _yes("Delivered to "+str(terms.client)+" · §%d paid. A new request arrives tomorrow." % int(plan.reward))
	return _no("Choose a commission action.")

static func candidates(world: Dictionary,owner: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var family: Dictionary=world.families.get(owner,{})
	if family.is_empty() or family.commissions.active.is_empty(): return result
	var terms: Dictionary=OFFERS[family.commissions.active.offer]
	var home: Dictionary=world.lots[family.home_lot]
	for key: String in Art.sources(home):
		var chosen:=Art.source(home,key)
		if chosen.picture.subject!=terms.subject: continue
		var intent: Dictionary={"type":"commission_deliver","lot_id":str(home.id),"offer":str(family.commissions.active.offer),"commission_revision":int(family.commissions.revision),"revision":int(home.revision),"art_source":key,"art_id":str(chosen.art_id)}
		var option:=delivery_option(world,owner,intent)
		result.append({"intent":intent,"picture":chosen.picture.duplicate(true),"location":str(chosen.location),"available":bool(option.ok),"message":str(option.get("message",""))})
	return result

## Derived presentation state; availability always uses the authority's transfer checks.
static func availability(world: Dictionary,owner: String) -> Dictionary:
	var family: Dictionary=world.get("families",{}).get(owner,{})
	var board: Dictionary=family.get("commissions",{})
	if board.get("active",{}).is_empty(): return {}
	var terms: Dictionary=OFFERS[board.active.offer]
	var ready: Array[String]=[]
	var choices:=candidates(world,owner)
	for choice: Dictionary in choices:
		if choice.available: ready.append(str(choice.intent.art_id))
	ready.sort()
	return {"offer":str(board.active.offer),"revision":int(board.revision),"client":str(terms.client),"subject":str(Paintings.SUBJECTS[terms.subject]),"reward":int(terms.reward),"matching":choices.size(),"ready":ready}

static func valid(value: Variant,owner: String,day: int) -> bool:
	if not value is Dictionary or value.size()!=5 or not _integer(value.get("revision"),0,MAX_REVISION) or not _integer(value.get("completed"),0,mini(day,MAX_REVISION/2)) or not _integer(value.get("completed_day"),0,day): return false
	if not value.get("active") is Dictionary or not value.get("history") is Array or value.history.size()!=mini(int(value.completed),HISTORY_LIMIT): return false
	if (int(value.completed)==0)!=(int(value.completed_day)==0): return false
	if int(value.revision)<int(value.completed)*2+(0 if value.active.is_empty() else 1): return false
	if not value.active.is_empty():
		if value.active.size()!=2 or value.active.get("offer")!=offer_id(owner,int(value.completed)) or not _integer(value.active.get("day"),int(value.completed_day)+1,day) or int(value.revision)>=MAX_REVISION: return false
	var previous_day:=int(value.completed_day)+1; var seen: Dictionary={}
	for index in range(value.history.size()):
		var entry: Variant=value.history[index]
		if not entry is Dictionary or entry.size()!=4 or entry.get("offer")!=offer_id(owner,int(value.completed)-index-1) or not _integer(entry.get("day"),1,previous_day-1) or not Art.valid_id(entry.get("art_id")) or not Text.valid_text(entry.get("credit"),80): return false
		if index==0 and int(entry.day)!=int(value.completed_day): return false
		if seen.has(entry.art_id): return false
		seen[entry.art_id]=true; previous_day=int(entry.day)
	return true

static func normalize(board: Dictionary) -> void:
	for field: String in ["revision","completed","completed_day"]: board[field]=int(board[field])
	if not board.active.is_empty(): board.active.day=int(board.active.day)
	for entry: Dictionary in board.history: entry.day=int(entry.day)

static func valid_receipts(world: Dictionary) -> bool:
	var delivered: Dictionary={}
	for family: Dictionary in world.families.values():
		for entry: Dictionary in family.get("commissions",{}).get("history",[]):
			if delivered.has(entry.art_id): return false
			delivered[entry.art_id]=true
	if delivered.is_empty(): return true
	for lot: Dictionary in world.lots.values():
		for entry: Dictionary in Art.sources(lot).values():
			if delivered.has(entry.art_id): return false
	for family: Dictionary in world.families.values():
		for entry: Dictionary in family.get("mailbox",{}).get("items",[]):
			if entry.has("art") and not entry.claimed and delivered.has(entry.art.id): return false
	return true

static func _matches(board: Dictionary,command: Dictionary) -> bool:
	return _integer(command.get("commission_revision"),0,MAX_REVISION-1) and int(command.commission_revision)==int(board.revision)
static func _integer(value: Variant,low: int,high: int) -> bool:
	return Art._integer(value) and float(value)>=low and float(value)<=high
static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
static func _yes(message: String) -> Dictionary: return {"ok":true,"message":message}
