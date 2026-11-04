extends RefCounted
## Persistent crops grow on the host's simulation clock, never wall time.
const CROPS := {
	"radish":{"name":"Radishes","seed_cost":10,"harvest_value":45,"seconds":90.0,"color":"d78c91"},
	"tomato":{"name":"Tomatoes","seed_cost":20,"harvest_value":95,"seconds":180.0,"color":"d67954"}
}
const DURATIONS := {"plant":8.0,"water":6.0,"harvest":6.0}
const WATER_CAP := 120.0
const MAX_REVISION := 1000000000

static func create() -> Dictionary:
	return {"crop":"","growth":0.0,"water":0.0,"revision":0,"harvests":0}

static func ripe(bed: Dictionary) -> bool:
	return CROPS.has(bed.get("crop")) and float(bed.growth)>=float(CROPS[bed.crop].seconds)-0.000001

static func grow(bed: Dictionary, delta: float) -> void:
	if not CROPS.has(bed.crop) or ripe(bed) or not is_finite(delta) or delta<=0: return
	var elapsed := minf(delta,minf(float(bed.water),float(CROPS[bed.crop].seconds)-float(bed.growth)))
	bed.growth=float(bed.growth)+elapsed; bed.water=maxf(0.0,float(bed.water)-elapsed)
	if ripe(bed): bed.growth=float(CROPS[bed.crop].seconds)

static func inspect(bed: Dictionary, action: Variant, crop: Variant, owner: bool, funds: int) -> Dictionary:
	if not action is String or not DURATIONS.has(action) or not crop is String: return _no("Choose a garden activity.")
	if int(bed.revision)>=MAX_REVISION: return _no("This garden bed has reached its activity limit.")
	if action!="water" and not owner: return _no("Only this household can plant or harvest. Visitors can help water.")
	var cost := 0
	if action=="plant":
		if not CROPS.has(crop): return _no("Choose radishes or tomatoes.")
		if not str(bed.crop).is_empty(): return _no("Harvest this crop before planting another.")
		cost=int(CROPS[crop].seed_cost)
	else:
		if not crop.is_empty(): return _no("Choose seeds only when planting.")
		if str(bed.crop).is_empty(): return _no("Plant a crop first.")
		if action=="water":
			if ripe(bed): return _no("Ready to harvest. No more water needed.")
			if float(bed.water)>WATER_CAP-30.0: return _no("Already watered. Let the crop grow a little.")
		elif not ripe(bed): return _no("This crop is still growing.")
		else: cost=-int(CROPS[bed.crop].harvest_value)
	if funds-cost<0: return _no("Need §%d more for seeds." % (cost-funds))
	if funds-cost>1000000000: return _no("Make room in the household budget before harvesting.")
	return {"ok":true,"message":"","cost":cost,"duration":DURATIONS[action],"label":label(action,crop if action=="plant" else str(bed.crop))}

static func apply(bed: Dictionary, action: String, crop: String) -> void:
	# The caller revalidates and transfers funds before committing this change.
	match action:
		"plant": bed.crop=crop; bed.growth=0.0; bed.water=45.0
		"water": bed.water=WATER_CAP
		"harvest": bed.crop=""; bed.growth=0.0; bed.water=0.0; bed.harvests=int(bed.harvests)+1
	bed.revision=int(bed.revision)+1

static func label(action: String,crop: String) -> String:
	return str({"plant":"Plant","water":"Water","harvest":"Harvest"}.get(action,"Tend"))+" "+str(CROPS.get(crop,{}).get("name","garden")).to_lower()

static func summary(bed: Dictionary) -> String:
	if str(bed.get("crop","")).is_empty(): return "Empty bed · Choose seeds"
	var name: String=CROPS[bed.crop].name
	if ripe(bed): return name+" · Ready to harvest"
	if float(bed.water)<=0.000001: return name+" · Needs water"
	return name+" · Growing %d%%" % floori(float(bed.growth)/float(CROPS[bed.crop].seconds)*100)

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=5 or not value.get("crop") is String: return false
	if not _integer(value.get("revision"),0,MAX_REVISION) or not _integer(value.get("harvests"),0,int(value.revision)): return false
	if not _number(value.get("growth")) or not _number(value.get("water")): return false
	if value.crop=="": return float(value.growth)==0.0 and float(value.water)==0.0
	return CROPS.has(value.crop) and float(value.growth)>=0.0 and float(value.growth)<=float(CROPS[value.crop].seconds) and float(value.water)>=0.0 and float(value.water)<=WATER_CAP and int(value.revision)>0

static func valid_task(task: Dictionary) -> bool:
	return task.get("type")=="interact" and task.get("target_kind","object")=="object" and not task.get("automatic",false) and DURATIONS.has(task.get("garden_action")) and _integer(task.get("garden_revision"),0,MAX_REVISION) and task.get("crop") is String and (CROPS.has(task.crop) if task.garden_action=="plant" else task.crop=="")

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high

static func _no(message: String) -> Dictionary: return {"ok":false,"message":message}
