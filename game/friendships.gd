extends RefCounted
## Shared, symmetric bonds. No absence decay and no autonomous progress farming.
const GAIN := 12
const DAILY_SESSIONS := 2
const SHARED_TIME := 4.0
const ACTIVITIES := ["chat","game_table","stereo","dining_table"]
const MAX_BONDS := 496 # Four households of eight, one record per unordered pair.

static func key(first: String, second: String) -> String:
	return JSON.stringify([first,second] if first<second else [second,first])

static func bond(world: Dictionary, first: String, second: String) -> Dictionary:
	return world.get("friendships",{}).get(key(first,second),{})

static func _new(first: String, second: String, day: int, score: int=0) -> Dictionary:
	return {"a":first if first<second else second,"b":second if first<second else first,"score":score,"day":day,"today":0,"last_chat_day":0,"last_tick":-1,"last_social_day":0,"last_activity":""}

static func ensure_housemates(world: Dictionary, family: Dictionary) -> void:
	for a in range(family.members.size()):
		for b in range(a+1,family.members.size()):
			var first: String=family.members[a].id; var second: String=family.members[b].id
			var id := key(first,second)
			if not world.friendships.has(id): world.friendships[id]=_new(first,second,int(world.day),20)

static func record(world: Dictionary, first: String, second: String, started_tick: int, activity: String="chat") -> Dictionary:
	if not activity in ACTIVITIES: return {"gain":0}
	var id := key(first,second)
	var entry: Dictionary=world.friendships.get(id,_new(first,second,int(world.day)))
	# A pair can report the same encounter in both directions or on several
	# ticks. Count its overlap once, including across midnight.
	if started_tick<=int(entry.last_tick): return {"gain":0}
	if int(entry.day)!=int(world.day): entry.day=int(world.day); entry.today=0
	var before := int(entry.score)
	if activity=="chat": entry.last_chat_day=int(world.day)
	entry.last_social_day=int(world.day); entry.last_activity=activity; entry.last_tick=int(world.tick)
	if int(entry.today)<DAILY_SESSIONS and before<100:
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
	return DAILY_SESSIONS-(int(entry.get("today",0)) if int(entry.get("day",0))==day else 0)

static func valid(value: Variant, members: Dictionary, day: int, tick: int) -> bool:
	if not value is Dictionary or value.size()>MAX_BONDS: return false
	for id: Variant in value:
		var entry: Variant=value[id]
		if not id is String or not entry is Dictionary: return false
		if not entry.get("a") is String or not entry.get("b") is String or entry.a>=entry.b or not members.has(entry.a) or not members.has(entry.b) or id!=key(entry.a,entry.b): return false
		if entry.has("last_social_day") or entry.has("last_activity"):
			var social_day: Variant=entry.get("last_social_day")
			if not (social_day is int or social_day is float) or not is_finite(float(social_day)) or float(social_day)!=floorf(float(social_day)) or float(social_day)<0 or float(social_day)>day: return false
			if (int(social_day)==0 and entry.get("last_activity")!="") or (int(social_day)>0 and not entry.get("last_activity") in ACTIVITIES): return false
		for spec in [["score",0,100],["day",1,day],["today",0,DAILY_SESSIONS],["last_chat_day",0,day],["last_tick",-1,tick]]:
			var number: Variant=entry.get(spec[0])
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)) or float(number)<float(spec[1]) or float(number)>float(spec[2]): return false
		if entry.has("last_social_day") and (int(entry.last_social_day)<int(entry.last_chat_day) or (entry.last_activity=="chat" and int(entry.last_social_day)!=int(entry.last_chat_day))): return false
	return true

static func normalize(world: Dictionary) -> void:
	if not world.has("friendships"): world.friendships={}
	for entry: Dictionary in world.friendships.values():
		for field: String in ["score","day","today","last_chat_day","last_tick"]: entry[field]=int(entry[field])
		entry.last_social_day=int(entry.get("last_social_day",entry.last_chat_day))
		entry.last_activity=str(entry.get("last_activity","chat" if int(entry.last_chat_day)>0 else ""))
	for family: Dictionary in world.families.values(): ensure_housemates(world,family)

static func recent(entry: Dictionary, day: int) -> String:
	var last := int(entry.get("last_social_day",entry.get("last_chat_day",0)))
	var activity := str(entry.get("last_activity","chat" if last>0 else ""))
	var result: String={"chat":"Last chat","game_table":"Played together","stereo":"Danced together","dining_table":"Shared a meal"}.get(activity,"")
	if last>0: result+=" · Day %d" % last
	var left := remaining(entry,day)
	if left==0: return result+("\n" if not result.is_empty() else "")+"Caught up today · More tomorrow"
	return result+("\n" if not result.is_empty() else "")+"%d %s left today" % [left,"catch-up" if left==1 else "catch-ups"]
