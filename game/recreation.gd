extends RefCounted
## A household recreation choice binds to the plans the player actually saw.
const Plans=preload("res://game/household_travel.gd")
const KINDS := ["game_table","stereo"]
static func stamp(member: Dictionary,action: String) -> Dictionary:
	var result:=Plans.stamp(member); result.action=action; return result
static func matches(value: Variant,expected: Array) -> bool:
	if not value is Array or value.size()!=expected.size(): return false
	for index in range(expected.size()):
		var row: Variant=value[index]; var wanted: Dictionary=expected[index]
		if not row is Dictionary or row.size()!=6 or not row.get("action") is String or row.action!=wanted.action: return false
		var plan: Dictionary=row.duplicate(); var expected_plan:=wanted.duplicate()
		plan.erase("action"); expected_plan.erase("action")
		if not Plans.matches([plan],[expected_plan]): return false
	return true
static func valid_choice(task: Dictionary,active: bool) -> bool:
	if not task.has("leisure_chosen_at"): return true
	var chosen: Variant=task.leisure_chosen_at; var elapsed: Variant=task.get("elapsed")
	return active and task.type=="interact" and task.get("target_kind","object")=="object" and not task.get("automatic",false) and (chosen is int or chosen is float) and (elapsed is int or elapsed is float) and is_finite(float(chosen)) and is_finite(float(elapsed)) and float(chosen)>=0.0 and float(chosen)<=float(elapsed)
