extends RefCounted
## Shared, symmetric bonds. No absence decay and no autonomous progress farming.
const GAIN := 12
const DAILY_CHATS := 2
const MAX_BONDS := 28 # Eight residents, one record per unordered pair.

static func key(first: String, second: String) -> String:
	return JSON.stringify([first,second] if first<second else [second,first])

static func bond(world: Dictionary, first: String, second: String) -> Dictionary:
	return world.get("friendships",{}).get(key(first,second),{})

static func _new(first: String, second: String, day: int, score: int=0) -> Dictionary:
	return {"a":first if first<second else second,"b":second if first<second else first,"score":score,"day":day,"today":0,"last_chat_day":0,"last_tick":-1}

static func ensure_housemates(world: Dictionary, family: Dictionary) -> void:
	var first: String=family.members[0].id; var second: String=family.members[1].id
	var id := key(first,second)
	if not world.friendships.has(id): world.friendships[id]=_new(first,second,int(world.day),20)

static func record(world: Dictionary, first: String, second: String, started_tick: int) -> Dictionary:
	var id := key(first,second)
	var entry: Dictionary=world.friendships.get(id,_new(first,second,int(world.day)))
	# Opposite directed tasks can be the same conversation. Count overlapping
	# sessions once, including when they finish on opposite sides of midnight.
	if started_tick<=int(entry.last_tick): return {"gain":0}
	if int(entry.day)!=int(world.day): entry.day=int(world.day); entry.today=0
	var before := int(entry.score)
	entry.last_chat_day=int(world.day); entry.last_tick=int(world.tick)
	if int(entry.today)<DAILY_CHATS and before<100:
		entry.score=mini(100,before+GAIN); entry.today+=1
	world.friendships[id]=entry
	var milestone := ""
	if before==0 and int(entry.score)>0: milestone="met"
	elif before<40 and int(entry.score)>=40: milestone="friends"
	elif before<70 and int(entry.score)>=70: milestone="good friends"
	elif before<100 and int(entry.score)==100: milestone="close friends"
	return {"gain":int(entry.score)-before,"milestone":milestone}

static func title(entry: Dictionary) -> String:
	var score := int(entry.get("score",0))
	if score>=100: return "Close friends"
	if score>=70: return "Good friends"
	if score>=40: return "Friends"
	if score>=20: return "Acquaintances"
	return "Getting acquainted" if score>0 else "Not met yet"

static func remaining(entry: Dictionary, day: int) -> int:
	if int(entry.get("score",0))>=100: return 0
	return DAILY_CHATS-(int(entry.get("today",0)) if int(entry.get("day",0))==day else 0)

static func valid(value: Variant, members: Dictionary, day: int, tick: int) -> bool:
	if not value is Dictionary or value.size()>MAX_BONDS: return false
	for id: Variant in value:
		var entry: Variant=value[id]
		if not id is String or not entry is Dictionary: return false
		if not entry.get("a") is String or not entry.get("b") is String or entry.a>=entry.b or not members.has(entry.a) or not members.has(entry.b) or id!=key(entry.a,entry.b): return false
		for spec in [["score",0,100],["day",1,day],["today",0,DAILY_CHATS],["last_chat_day",0,day],["last_tick",-1,tick]]:
			var number: Variant=entry.get(spec[0])
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)) or float(number)<float(spec[1]) or float(number)>float(spec[2]): return false
	return true

static func normalize(world: Dictionary) -> void:
	if not world.has("friendships"): world.friendships={}
	for entry: Dictionary in world.friendships.values():
		for field: String in ["score","day","today","last_chat_day","last_tick"]: entry[field]=int(entry[field])
	for family: Dictionary in world.families.values(): ensure_housemates(world,family)
