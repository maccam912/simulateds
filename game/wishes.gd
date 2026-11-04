extends RefCounted
## Optional personal goals. No expiry, streaks, or unattended reward farming.
const REWARD := 40
const SET_BONUS := 80
const MAX_JOURNAL := 12
const STARTER_ORDER := ["story","greenery","tea","show","company","rest"]
const ORDER := ["story","greenery","tea","show","company","rest","homemade","meal_together"]
const MEALS := ["homemade","meal_together"]
const CATALOG := {
	"story":{"title":"Get lost in a story","activity":"bookshelf","description":"Finish a reading session at a bookshelf."},
	"greenery":{"title":"A little green company","activity":"plant","description":"Spend a moment tending a plant."},
	"tea":{"title":"Make time for tea","activity":"table","description":"Enjoy a quiet tea break at a table."},
	"show":{"title":"Something wonderfully silly","activity":"tv","description":"Settle in for a little television."},
	"company":{"title":"A proper catch-up","activity":"chat","description":"Finish a conversation with another resident."},
	"rest":{"title":"Put your feet up","activity":"sofa","description":"Take a relaxing break on a sofa."},
	"homemade":{"title":"Something homemade","activity":"meal_prepare","description":"Serve four portions of salad or sandwiches at home. Ingredients are paid when served."},
	"meal_together":{"title":"Share a meal","activity":"meal_company","description":"Both residents choose their meal, then eat together for 12 game minutes. Each player directs their own diners."}
}

static func create(member_id: String, day: int, round_number: int = 0, journal: Array = []) -> Dictionary:
	var wishes: Array=[]
	var pool: Array=STARTER_ORDER if round_number==0 else ORDER
	var offset := posmod(member_id.hash()+round_number*3,pool.size())
	for index in range(3): wishes.append({"id":pool[(offset+index)%pool.size()],"done":false})
	return {"day":day,"round":round_number,"wishes":wishes,"journal":journal.duplicate(true)}

static func completed(board: Dictionary) -> int:
	var count := 0
	for wish: Dictionary in board.get("wishes",[]):
		if wish.get("done",false): count+=1
	return count

static func can_renew(board: Dictionary, day: int) -> bool:
	return completed(board)==3 and day>int(board.day) and int(board.round)<1000000000

static func record(board: Dictionary, activity: String, day: int) -> Dictionary:
	for wish: Dictionary in board.wishes:
		if not wish.done and CATALOG[wish.id].activity==activity:
			wish.done=true
			var finished := completed(board)==3
			var reward := REWARD+(SET_BONUS if finished else 0)
			var title: String=CATALOG[wish.id].title
			var entry := title + " · § %d" % reward
			if finished: entry += " (includes set bonus)"
			board.journal.push_front({"day":day,"text":entry})
			if board.journal.size()>MAX_JOURNAL: board.journal.resize(MAX_JOURNAL)
			return {"reward":reward,"title":title,"finished":finished}
	return {"reward":0}

static func valid(value: Variant, world_day: int) -> bool:
	if not value is Dictionary: return false
	if not _integer(value.get("day"),1,world_day) or not _integer(value.get("round"),0,1000000000): return false
	if not value.get("wishes") is Array or value.wishes.size()!=3 or not value.get("journal") is Array or value.journal.size()>MAX_JOURNAL: return false
	var seen := {}
	for wish: Variant in value.wishes:
		if not wish is Dictionary or not wish.get("id") is String or not CATALOG.has(wish.id) or seen.has(wish.id) or not wish.get("done") is bool: return false
		seen[wish.id]=true
	for entry: Variant in value.journal:
		if not entry is Dictionary or not _integer(entry.get("day"),1,world_day) or not entry.get("text") is String or str(entry.text).length()>160: return false
	return true

static func normalize(board: Dictionary) -> void:
	board.day=int(board.day); board.round=int(board.round)
	for entry: Dictionary in board.journal: entry.day=int(entry.day)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
