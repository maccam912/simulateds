extends RefCounted
## A modest autonomous preference, independent of learned hobby progress.
const ORDER := ["variety", "reading", "television", "gardening", "tea"]
const LABELS := {"variety":"A little of everything", "reading":"Reading", "television":"Television", "gardening":"Gardening", "tea":"Tea & company"}
const ACTIVITIES := {"reading":"bookshelf", "television":"tv", "gardening":"plant", "tea":"table"}
const PREFERENCE := 6.0
const URGENT := 30.0

static func valid(value: Variant) -> bool:
	return value is String and value in ORDER

static func of(member: Dictionary) -> String:
	return str(member.get("favorite","variety"))

static func label(member: Dictionary) -> String:
	return str(LABELS.get(of(member),LABELS.variety))

static func initial(member: Dictionary) -> String:
	return ORDER[1+posmod(str(member.id).hash(),ORDER.size()-1)]

static func matches(member: Dictionary, activity: String) -> bool:
	return not activity.is_empty() and ACTIVITIES.get(of(member),"")==activity
