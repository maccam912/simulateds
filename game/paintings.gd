extends RefCounted
## A single persistent canvas per easel. Only accepted, deliberate work advances it.
const Text = preload("res://game/activity_log.gd")
const SUBJECTS := {"meadow":"Morning meadow","harbor":"Quiet harbor","flowers":"Flowers for home"}
const DURATION := 24.0
const SELL_TIME := 4.0
const VALUE := 60
const MAX_REVISION := 1000000000

static func front_cell(easel: Dictionary) -> Vector2i:
	# Match the model's +Z canvas side through its four quarter turns.
	return Vector2i(int(easel.x),int(easel.y))+[Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT][int(easel.rotation)]

static func create() -> Dictionary:
	return {"subject":"","progress":0.0,"artists":[],"day":0,"revision":0}

static func finished(picture: Dictionary) -> bool: return float(picture.progress)>=DURATION

static func label(action: String,subject: String) -> String:
	return "Packing painting for sale" if action=="sell" else "Paint "+str(SUBJECTS.get(subject,"a picture")).to_lower()

static func summary(picture: Dictionary) -> String:
	if str(picture.subject).is_empty(): return "A blank canvas"
	return str(SUBJECTS[picture.subject])+" · "+("Finished" if finished(picture) else "%d%%" % floori(float(picture.progress)/DURATION*100.0))

static func credit(picture: Dictionary) -> String:
	var names: PackedStringArray=[]
	for artist: Dictionary in picture.artists: names.append(str(artist.name))
	return "By "+" & ".join(names) if not names.is_empty() else ""

static func inspect(picture: Dictionary,action: Variant,subject: Variant,owner: bool) -> Dictionary:
	if not owner: return _no("This household's artwork is theirs to paint and sell.")
	if not action is String or not action in ["start","resume","sell"] or not subject is String: return _no("Choose a painting activity.")
	if int(picture.revision)>=MAX_REVISION-2: return _no("This easel has reached its activity limit.")
	if action=="start":
		if not SUBJECTS.has(subject): return _no("Choose a painting subject.")
		if not str(picture.subject).is_empty(): return _no("Finish this canvas and keep or sell it before starting another.")
	else:
		if not subject.is_empty(): return _no("Choose a subject only for a new canvas.")
		if str(picture.subject).is_empty(): return _no("Choose a subject for the blank canvas first.")
		if action=="resume" and finished(picture): return _no("This painting is finished. Keep it on display or sell it.")
		if action=="sell" and not finished(picture): return _no("Finish the painting before selling it.")
	return {"ok":true,"message":"","label":label(action,subject if action=="start" else str(picture.subject)),"seconds":SELL_TIME if action=="sell" else DURATION-float(picture.progress),"revision":int(picture.revision)}

static func contribute(picture: Dictionary,member: Dictionary,work: float) -> void:
	# Integer milliseconds survive JSON exactly. Difference of rounded canvas
	# progress avoids accumulating rounding error across small simulation steps.
	var milliseconds := roundi((float(picture.progress)+work)*1000.0)-roundi(float(picture.progress)*1000.0)
	for artist: Dictionary in picture.artists:
		if artist.id==member.id:
			artist.work_ms=mini(int(DURATION*1000),int(artist.get("work_ms",0))+milliseconds); return
	if picture.artists.size()<2: picture.artists.append({"id":str(member.id),"name":Text.clean(str(member.name),32),"work_ms":milliseconds})

static func work_by(picture: Dictionary,member_id: String) -> float:
	for artist: Dictionary in picture.artists:
		if artist.id==member_id: return float(artist.get("work_ms",0))/1000.0
	return 0.0

static func normalize(picture: Dictionary) -> void:
	for key: String in ["day","revision"]: picture[key]=int(picture[key])
	for artist: Dictionary in picture.artists:
		if artist.has("work_ms"): artist.work_ms=int(artist.work_ms)

static func valid(value: Variant,day: int) -> bool:
	if not value is Dictionary or value.size()!=5 or not value.get("subject") is String: return false
	if not _integer(value.get("revision"),0,MAX_REVISION) or not _integer(value.get("day"),0,day): return false
	if not _number(value.get("progress")) or float(value.progress)<0 or float(value.progress)>DURATION: return false
	if not value.get("artists") is Array or value.artists.size()>2: return false
	var seen := {}; var work := 0
	for artist: Variant in value.artists:
		if not artist is Dictionary or artist.size()!=(3 if artist.has("work_ms") else 2) or not Text.valid_text(artist.get("id"),160) or not Text.valid_text(artist.get("name"),32) or seen.has(artist.id): return false
		if artist.has("work_ms"):
			if not _integer(artist.work_ms,0,int(DURATION*1000)): return false
			work+=int(artist.work_ms)
		seen[artist.id]=true
	if work>roundi(float(value.progress)*1000.0): return false
	if value.subject=="": return float(value.progress)==0 and value.artists.is_empty() and int(value.day)==0
	return SUBJECTS.has(value.subject) and float(value.progress)>0 and not value.artists.is_empty() and int(value.revision)>0 and (int(value.day)>0 if finished(value) else int(value.day)==0)

static func valid_task(task: Dictionary) -> bool:
	return task.get("type")=="interact" and task.get("target_kind","object")=="object" and not task.get("automatic",false) and task.get("paint_action") in ["start","resume","sell"] and _integer(task.get("paint_revision"),0,MAX_REVISION) and task.get("subject") is String and (SUBJECTS.has(task.subject) if task.paint_action=="start" else task.subject=="")

static func _number(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
static func _integer(value: Variant,low: int,high: int) -> bool: return _number(value) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
