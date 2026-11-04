extends RefCounted
## Small, lasting rewards for deliberately spending time on an interest.
const ORDER := ["reading","gardening","cooking","painting"]
const THRESHOLDS := [0,2,5,9,14]
const DAILY_LIMIT := 2
const CATALOG := {
	"reading":{"name":"Reading","activity":"bookshelf","action":"Read a book","need":"fun","secondary":"comfort","titles":["Curious reader","Page turner","Book lover","Avid reader","Story keeper"]},
	"gardening":{"name":"Gardening","activity":"plant","action":"Tend a plant","need":"comfort","secondary":"fun","titles":["New gardener","Plant tender","Green thumb","Seasoned gardener","Master gardener"]},
	"cooking":{"name":"Cooking","activity":"fridge","action":"Make a meal","need":"hunger","secondary":"comfort","titles":["Kitchen novice","Home cook","Confident cook","Seasoned cook","Neighborhood chef"]},
	"painting":{"name":"Painting","activity":"easel","action":"Choose a painting","need":"fun","secondary":"comfort","titles":["Curious painter","Color explorer","Confident painter","Studio regular","Neighborhood artist"]}
}

static func create(day: int) -> Dictionary:
	var board := {}
	for hobby: String in ORDER: board[hobby]={"sessions":0,"day":day,"today":0}
	return board

static func for_activity(activity: String) -> String:
	for hobby: String in ORDER:
		if CATALOG[hobby].activity==activity: return hobby
	return ""

static func rank(entry: Dictionary) -> int:
	var result := 1
	for threshold: int in THRESHOLDS:
		if int(entry.get("sessions",0))>=threshold: result=THRESHOLDS.find(threshold)+1
	return result

static func title(hobby: String, entry: Dictionary) -> String:
	return str(CATALOG[hobby].titles[rank(entry)-1])

static func remaining(entry: Dictionary, day: int) -> int:
	if int(entry.get("sessions",0))>=THRESHOLDS[-1]: return 0
	return DAILY_LIMIT-(int(entry.get("today",0)) if int(entry.get("day",0))==day else 0)

static func multiplier(board: Dictionary, activity: String) -> float:
	var hobby := for_activity(activity)
	return 1.0 if hobby.is_empty() else 1.0+0.1*(rank(board.get(hobby,{}))-1)

static func record(board: Dictionary, activity: String, day: int) -> Dictionary:
	var hobby := for_activity(activity)
	if hobby.is_empty(): return {}
	var entry: Dictionary=board[hobby]
	if remaining(entry,day)<=0: return {}
	var previous := rank(entry)
	if int(entry.day)!=day: entry.day=day; entry.today=0
	entry.sessions=int(entry.sessions)+1; entry.today=int(entry.today)+1
	return {"hobby":hobby,"rank_up":rank(entry)>previous,"rank":rank(entry),"title":title(hobby,entry)}

static func benefit(hobby: String, entry: Dictionary) -> String:
	var level := rank(entry)
	var definition: Dictionary=CATALOG[hobby]
	if hobby=="painting": return "Next rank: +10% fun and extra comfort while painting." if level==1 else "+%d%% fun · Extra comfort while painting" % ((level-1)*10)
	if level==1: return "Next rank: +10% "+str(definition.need)+" and a little "+str(definition.secondary)+"."
	return "+%d%% %s · Also restores %s" % [(level-1)*10,str(definition.need),str(definition.secondary)]

static func valid(value: Variant, world_day: int) -> bool:
	if not value is Dictionary: return false
	# The only supported older shape is the complete original three-hobby board.
	var required := ORDER.duplicate()
	if not value.has("painting"): required.erase("painting")
	if value.size()!=required.size(): return false
	for hobby: String in required:
		var entry: Variant=value.get(hobby)
		if not entry is Dictionary or entry.size()!=3: return false
		if not _integer(entry.get("sessions"),0,THRESHOLDS[-1]) or not _integer(entry.get("day"),1,world_day) or not _integer(entry.get("today"),0,DAILY_LIMIT): return false
		if int(entry.today)>int(entry.sessions): return false
	return true

static func normalize(board: Dictionary,day: int) -> void:
	if not board.has("painting"): board.painting={"sessions":0,"day":day,"today":0}
	for entry: Dictionary in board.values():
		for field: String in ["sessions","day","today"]: entry[field]=int(entry[field])

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
