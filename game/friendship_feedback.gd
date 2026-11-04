extends RefCounted
## Local presentation only: accepted bond gains, never commands or saved rewards.
const Bonds = preload("res://game/friendships.gd")
const GATHER_MS := 600
const QUIET_MS := 2500
const MAX_AGE_MS := 8000
var _context := ""
var _tick := -1
var _scores := {}
var _pending := {}
var _ready_at := 0
var _quiet_until := 0

func reset() -> void:
	_context=""; _tick=-1; _scores.clear(); _pending.clear(); _ready_at=0; _quiet_until=0

func sample(world: Dictionary,owner: String,generation: int,now: int,active: bool=true,selected: String="",allow_notice: bool=true) -> Dictionary:
	var context:=owner+":"+str(generation)
	var tick:=int(world.get("tick",0))
	var fresh:=context!=_context or tick<_tick
	if fresh: reset(); _context=context
	var own:=[]
	for member: Dictionary in world.get("families",{}).get(owner,{}).get("members",[]): own.append(str(member.id))
	var scores: Dictionary={}
	for id: String in world.get("friendships",{}):
		var bond: Dictionary=world.friendships[id]
		if not bond.a in own and not bond.b in own: continue
		var before:=int(_scores.get(id,0)); var after:=int(bond.score)
		scores[id]=after
		if fresh or not active or after<=before or int(bond.last_tick)<=_tick: continue
		# Newly discovered housemate bonds have no encounter; old snapshots are baselines.
		if _pending.is_empty(): _ready_at=now+GATHER_MS
		if _pending.has(id): before=int(_pending[id].before)
		_pending[id]={"id":id,"a":str(bond.a),"b":str(bond.b),"before":before,"after":after,"activity":str(bond.get("last_activity","chat")),"at":now}
	_scores=scores; _tick=tick
	if not active: _pending.clear(); _quiet_until=0; return {}
	for id: String in _pending.keys():
		if now-int(_pending[id].at)>MAX_AGE_MS: _pending.erase(id)
	if _pending.is_empty() or now<_ready_at or now<_quiet_until or not allow_notice: return {}
	var events: Array=_pending.values()
	events.sort_custom(func(a,b):
		if _milestone(a)!=_milestone(b): return _milestone(a)>_milestone(b)
		var a_selected: bool=selected in [a.a,a.b]; var b_selected: bool=selected in [b.a,b.b]
		if a_selected!=b_selected: return a_selected
		return str(a.id)<str(b.id))
	_pending.clear(); _quiet_until=now+QUIET_MS
	var names: Dictionary={}
	for family: Dictionary in world.get("families",{}).values():
		for member: Dictionary in family.members: names[str(member.id)]=str(member.name)
	var lines: PackedStringArray=[]
	for event: Dictionary in events: lines.append(_sentence(event,names))
	var message:=lines[0]
	if events.size()>1: message+="\n%d more %s grew." % [events.size()-1,"friendship" if events.size()==2 else "friendships"]
	elif _milestone(events[0])==0: message+="\nFriendship grew."
	var primary: Dictionary=events[0]
	var resident: String=selected if selected in [primary.a,primary.b] and selected in own else primary.a if primary.a in own else primary.b
	return {"message":message,"detail":"\n".join(lines)+"\nPeople shows recent company and remaining catch-ups.","sound":"confirm" if _milestone(primary)>0 else "company","pairs":events.map(func(event): return str(event.id)),"resident":resident,"person":primary.b if resident==primary.a else primary.a}

static func _milestone(event: Dictionary) -> int:
	for threshold: int in [100,70,40]:
		if int(event.before)<threshold and int(event.after)>=threshold: return threshold
	return 1 if int(event.before)==0 and int(event.after)>0 else 0

static func _sentence(event: Dictionary,names: Dictionary) -> String:
	var pair:=str(names.get(event.a,"A resident"))+" and "+str(names.get(event.b,"a neighbor"))
	var milestone:=_milestone(event)
	if milestone>=40: return pair+" are now "+Bonds.title({"score":event.after}).to_lower()+"."
	if milestone==1: return pair+" got to know each other."
	return pair+" caught up"+str({"game_table":" over a game","stereo":" while dancing","dining_table":" over a meal"}.get(event.activity,""))+"."
