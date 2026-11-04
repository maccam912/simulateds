extends RefCounted
## Bounded facts about simulated absence. No wall clock, catch-up, or rewards.
const MAX_NUMBER := 9007199254740000
const FIELDS := ["minutes","allowance","postcards","gifts"]

static func create() -> Dictionary:
	return {"seen":false,"minutes":0.0,"allowance":0,"postcards":0,"gifts":0,"construction":false,"sequence":0,"report":{}}

static func pending(family: Dictionary) -> bool:
	return bool(family.get("home_news",{}).get("report",{}).get("pending",false))

static func away(family: Dictionary) -> bool:
	return not family.online and bool(family.home_news.seen)

static func departure(family: Dictionary, construction: bool) -> void:
	if not family.online: return # Repeated cleanup must preserve an ongoing absence.
	var news: Dictionary=family.home_news
	for key: String in FIELDS: news[key]=0
	news.construction=construction

static func arrival(family: Dictionary) -> void:
	if family.online: return
	var news: Dictionary=family.home_news
	if news.seen and (float(news.minutes)>=30.0 or int(news.allowance)>0 or int(news.postcards)>0 or news.construction):
		var report: Dictionary=news.report.duplicate(true) if pending(family) else {"minutes":0,"allowance":0,"postcards":0,"gifts":0,"construction":false}
		for key: String in FIELDS: report[key]=mini(MAX_NUMBER,int(report[key])+int(news[key]))
		report.construction=bool(report.construction) or bool(news.construction)
		news.sequence=mini(MAX_NUMBER,int(news.sequence)+1)
		report.id=news.sequence; report.pending=true; news.report=report
	news.seen=true

static func read(family: Dictionary, revision: Variant) -> Dictionary:
	var report: Dictionary=family.home_news.report
	if not _integer(revision) or report.is_empty() or int(revision)!=int(report.id):
		return {"ok":false,"message":"Home news changed. Review the latest recap first."}
	report.pending=false
	return {"ok":true,"message":"Home news marked as read. The recap stays here."}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=8 or not value.get("seen") is bool or not value.get("construction") is bool or not _integer(value.get("sequence")) or not value.get("report") is Dictionary: return false
	for key: String in FIELDS:
		if key=="minutes":
			var number: Variant=value.get(key)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)<0 or float(number)>MAX_NUMBER: return false
		elif not _integer(value.get(key)): return false
	var report: Dictionary=value.report
	if report.is_empty(): return int(value.sequence)==0
	if report.size()!=7 or not _integer(report.get("id")) or int(report.id)<1 or int(report.id)!=int(value.sequence) or not report.get("pending") is bool or not report.get("construction") is bool or not value.seen: return false
	for key: String in FIELDS:
		if not _integer(report.get(key)): return false
	return true

static func normalize(family: Dictionary) -> void:
	if not family.has("home_news"):
		family.home_news=create(); family.home_news.seen=bool(family.online)
	var news: Dictionary=family.home_news
	news.minutes=float(news.minutes); news.sequence=int(news.sequence)
	for key: String in ["allowance","postcards","gifts"]: news[key]=int(news[key])
	if not news.report.is_empty():
		news.report.id=int(news.report.id)
		for key: String in FIELDS: news.report[key]=int(news.report[key])

static func elapsed(minutes: int) -> String:
	if minutes<1: return "Less than a neighborhood minute"
	var days := minutes/1440
	var hours := (minutes%1440)/60
	var rest := minutes%60
	var parts := PackedStringArray()
	if days>0: parts.append("%d day%s" % [days,"" if days==1 else "s"])
	if hours>0: parts.append("%d hour%s" % [hours,"" if hours==1 else "s"])
	if rest>0: parts.append("%d minute%s" % [rest,"" if rest==1 else "s"])
	return ", ".join(parts)+" of neighborhood time"

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)<=MAX_NUMBER and float(value)==floorf(float(value))
