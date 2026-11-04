extends RefCounted
## Presentation events derived from visible movement and accepted task progress.
## Nothing here advances a task, changes a need, or stores gameplay state.
const ACTIVITIES := {
	"meal_prepare":["meal",4.0], "meal_eat":["tea",5.0],
	"garden_plant":["page",0.0], "garden_water":["water",4.0], "garden_harvest":["page",0.0],
	"painting_sale":["fabric",0.0], "easel":["page",5.0], "bookshelf":["page",5.0], "plant":["water",4.0], "table":["tea",5.0], "game_table":["game_piece",5.0],
	"fridge":["meal",4.0], "shower":["shower",4.0], "toilet":["water",0.0],
	"bed":["fabric",0.0], "sofa":["fabric",0.0], "tv":["television",6.0], "chat":["chat",5.0]
}
var tracks: Dictionary={}
var _context := ""
var _gap := 0.0

func reset() -> void:
	tracks.clear(); _gap=0.0

func sample(context: String, residents: Array[Dictionary], delta: float, active: bool) -> Array[Dictionary]:
	if not active or context!=_context:
		reset(); _context=context
	if not active: return []
	_gap=maxf(0.0,_gap-maxf(0.0,delta))
	var seen := {}
	var activities: Array[Dictionary]=[]
	var steps: Array[Dictionary]=[]
	for resident: Dictionary in residents:
		var id: String=resident.id
		seen[id]=true
		if not tracks.has(id):
			tracks[id]={"cell":resident.cell,"task":resident.task,"kind":resident.kind,"elapsed":resident.elapsed,"walked":0.0,"cooldown":0.0,"count":0,"onset":false}
			continue # Opening a lot or resuming is silent; no catch-up chorus.
		var track: Dictionary=tracks[id]
		track.cooldown=maxf(0.0,float(track.cooldown)-maxf(0.0,delta))
		var distance: float=Vector2(track.cell).distance_to(resident.cell)
		if distance>2.0: track.walked=0.0 # Teleports and snaps have no footsteps.
		elif distance>0.001:
			track.walked+=distance
			if float(track.walked)>=1.2 and float(track.cooldown)<=0.0:
				steps.append(_event(resident,"step_wood" if resident.indoors else "step_grass",track))
		elif not resident.walking: track.walked=0.0
		var kind: String=resident.kind
		var elapsed: float=resident.elapsed
		if track.task!=resident.task or track.kind!=kind or resident.walking or elapsed<=0.0: track.onset=false
		if ACTIVITIES.has(kind) and elapsed>0.0 and not resident.walking:
			var interval: float=ACTIVITIES[kind][1]
			var started: bool=track.task!=resident.task or track.kind!=kind or float(track.elapsed)<=0.0
			var progressed: bool=interval>0.0 and floorf(elapsed/interval)>floorf(float(track.elapsed)/interval)
			if started: track.onset=true
			# Keep one onset through the short mix gap, only while this exact task
			# remains active. Short activities otherwise lose their only texture.
			if track.onset or progressed: activities.append(_event(resident,str(ACTIVITIES[kind][0]),track))
		track.cell=resident.cell; track.task=resident.task; track.kind=kind; track.elapsed=elapsed
	for id: String in tracks.keys():
		if not seen.has(id): tracks.erase(id)
	if _gap>0.0: return []
	var candidates := activities if not activities.is_empty() else steps
	if candidates.is_empty(): return []
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return int(tracks[a.member].count)<int(tracks[b.member].count))
	var event: Dictionary=candidates[0]
	var track: Dictionary=tracks[event.member]
	track.count+=1; track.cooldown=0.42; track.walked=0.0; track.onset=false
	_gap=0.18
	return [event] # Sparse mix, bounded across all residents; never queue old cues.

func _event(resident: Dictionary, sound: String, track: Dictionary) -> Dictionary:
	return {"member":resident.id,"task":resident.task,"sound":sound,"position":resident.position,"pitch":0.97+float(posmod((str(resident.id)+str(track.count)).hash(),7))*0.01}
