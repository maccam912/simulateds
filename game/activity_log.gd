extends RefCounted
## Bounded, host-owned outcomes for deliberate activities. Presentation is read-only.
const LIMIT := 8
const OUTCOMES := {"done":"Done", "cancelled":"Cancelled", "failed":"Interrupted"}
const FIELDS := ["id","title","outcome","reason","day","minute","tick","routine"]

static func clean(value: String, limit: int) -> String:
	var result := ""
	for character: String in value:
		result += " " if character.unicode_at(0)<32 or character.unicode_at(0)==127 else character
	return result.strip_edges().left(limit)

static func valid_text(value: Variant, limit: int, empty: bool = false) -> bool:
	return value is String and (empty or not value.is_empty()) and value.length()<=limit and clean(value,limit)==value

static func record(member: Dictionary, task: Dictionary, title: String, outcome: String, reason: String, state: Dictionary) -> void:
	if task.get("automatic",false) or str(task.get("id","")).is_empty(): return
	if not member.has("activity_log"): member.activity_log=[]
	# A repeated completion must never crowd out another result.
	for entry: Dictionary in member.activity_log:
		if entry.id==task.id: return
	member.activity_log.push_front({"id":str(task.id),"title":clean(title,100),"outcome":outcome,"reason":clean(reason,160),"day":int(state.day),"minute":int(state.day_minutes),"tick":int(state.tick),"routine":clean(str(task.get("routine_name","")),32)})
	if member.activity_log.size()>LIMIT: member.activity_log.resize(LIMIT)

static func normalize(member: Dictionary) -> void:
	if not member.has("activity_log"): member.activity_log=[]
	for entry: Dictionary in member.activity_log:
		for key: String in ["day","minute","tick"]: entry[key]=int(entry[key])

static func valid(value: Variant, day: int, tick: int) -> bool:
	if not value is Array or value.size()>LIMIT: return false
	var seen := {}; var previous_tick := tick
	for entry: Variant in value:
		if not entry is Dictionary or entry.size()!=FIELDS.size(): return false
		for key: String in FIELDS:
			if not entry.has(key): return false
		if not entry.id is String or entry.id.is_empty() or entry.id.length()>180 or seen.has(entry.id): return false
		if not valid_text(entry.title,100) or not valid_text(entry.reason,160) or not valid_text(entry.routine,32,true): return false
		if not entry.outcome is String or not OUTCOMES.has(entry.outcome): return false
		if not _integer(entry.day,1,day) or not _integer(entry.minute,0,1439) or not _integer(entry.tick,0,previous_tick): return false
		seen[entry.id]=true; previous_tick=int(entry.tick)
	return true

static func timestamp(entry: Dictionary) -> String:
	return "Day %d · %02d:%02d" % [int(entry.day),int(entry.minute)/60,int(entry.minute)%60]

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=minimum and float(value)<=maximum
