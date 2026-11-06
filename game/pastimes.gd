extends RefCounted
## A modest autonomous preference, independent of learned hobby progress.
const Character = preload("res://game/character_profile.gd")
const ORDER := ["variety", "reading", "television", "gardening", "tea", "games", "dancing"]
const LABELS := {"variety":"A little of everything", "reading":"Reading", "television":"Television", "gardening":"Gardening", "tea":"Tea & company", "games":"Tabletop games", "dancing":"Music & dancing"}
const ACTIVITIES := {"reading":"bookshelf", "television":"tv", "gardening":"plant", "tea":"table", "games":"game_table", "dancing":"stereo"}
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

static func affinity_detail(member: Dictionary, activity: String) -> String:
	# Describe saved affinities, not a fabricated explanation of a past decision.
	var parts: Array[String]=[]
	if matches(member,activity): parts.append("Favorite: "+label(member))
	var profile: Dictionary=member.get("character",{})
	for trait_name: String in profile.get("traits",[]):
		if Character.TRAIT_KINDS.get(trait_name)==activity: parts.append(trait_name)
	var index: int=Character.INTEREST_KINDS.find(activity)
	if index>=0:
		var interest: String=Character.INTERESTS[index]
		if interest in profile.get("likes",[]): parts.append("Likes "+interest.to_lower())
		if interest in profile.get("dislikes",[]): parts.append("Dislikes "+interest.to_lower())
	return " · ".join(parts)
