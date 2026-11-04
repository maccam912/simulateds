extends RefCounted
## Read-only route previews plus markers from accepted tasks, never click guesses.
const World = preload("res://game/world.gd")
var preview: Dictionary={}
var markers: Array[Dictionary]=[]
var route: Array=[]
var start := Vector2.ZERO
var _router := World.new()
var _context := ""
var _known := {}
var _recent := ""
var _recent_time := 0.0
var _preview_key := ""

func update(world: Dictionary,profile: String,member_id: String,lot_id: String,cell: Vector2i,hover: bool,plan: bool,delta: float,enabled: bool=true) -> void:
	markers.clear(); route=[]
	if not enabled or not world.get("lots",{}).has(lot_id): clear(); return
	var family: Dictionary=world.get("families",{}).get(profile,{})
	var member: Dictionary={}
	for candidate: Dictionary in family.get("members",[]):
		if candidate.id==member_id: member=candidate; break
	if member.is_empty(): clear(); return
	var lot: Dictionary=world.lots[lot_id]
	if lot.building or world.lots[family.home_lot].building: clear(); return
	_router.state=world
	var key := str([profile,member_id,lot_id])
	var changed := key!=_context
	if changed: clear(); _context=key
	_recent_time=maxf(0.0,_recent_time-maxf(delta,0.0))
	var tasks: Array=[]
	if not member.task.is_empty(): tasks.append(member.task)
	tasks.append_array(member.queue)
	var seen := {}
	for task: Dictionary in tasks:
		if task.get("type")!="move" or task.get("automatic",false): continue
		var id := str(task.get("id",""))
		if id.is_empty(): continue
		seen[id]=true
		if not changed and not _known.has(id): _recent=id; _recent_time=3.0
	_known=seen
	if not seen.has(_recent) or _recent_time<=0.0: _recent=""
	start=Vector2(float(member.x)+0.5,float(member.y)+0.5)
	if member.lot_id==lot_id:
		for index in range(tasks.size()):
			var task: Dictionary=tasks[index]
			if task.get("type")!="move" or task.get("automatic",false): continue
			var active: bool=task==member.task
			var id := str(task.get("id",""))
			if active or plan or id==_recent:
				markers.append({"id":id,"cell":Vector2i(int(task.x),int(task.y)),"active":active,"order":index+1,"recent":id==_recent})
		if (plan or hover) and member.task.get("type")=="move" and not member.task.get("automatic",false): route=member.task.get("path",[]).duplicate(true)
	if hover:
		var signature := str([key,lot.revision,member.x,member.y,member.lot_id,member.task.get("id",""),member.task.get("automatic",false),member.queue.size(),cell])
		if signature!=_preview_key:
			_preview_key=signature
			preview=_router.move_option(profile,member_id,lot_id,cell)
			preview.cell=cell
	else:
		preview={}; _preview_key=""

func clear() -> void:
	preview={}; markers.clear(); route=[]; _context=""; _known={}; _recent=""; _recent_time=0.0; _preview_key=""
