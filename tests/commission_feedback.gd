extends SceneTree
const World=preload("res://game/world.gd")
const Jobs=preload("res://game/art_commissions.gd")
const Feedback=preload("res://game/commission_feedback.gd")
var world: RefCounted
var tracker: RefCounted
var home: Dictionary
var member: Dictionary
var easel: Dictionary
var board: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	world.set_online("a",true)
	for family: Dictionary in world.state.families.values():
		for resident: Dictionary in family.members: resident.autonomy=false
	home=world.state.lots.lot_1; member=world.state.families.a.members[0]; board=world.state.families.a.commissions
	easel=world._new_object("easel",9,9,0); home.objects.append(easel)
	tracker=Feedback.new(); assert(_sample(0).is_empty())
func _command(type: String) -> void:
	assert(world.apply_command("a",{"type":type,"commission_revision":board.revision,"offer":Jobs.offer("a",board).id}).ok)
func _paint(subject: String="") -> void:
	if subject.is_empty(): subject=Jobs.offer("a",board).subject
	assert(world.apply_command("a",{"type":"painting","member_id":member.id,"target_id":easel.id,"action":"start","subject":subject,"revision":easel.painting.revision}).ok)
	for tick in range(400):
		world.step(0.1)
		if member.task.is_empty(): break
	assert(preload("res://game/paintings.gd").finished(easel.painting))
func _sample(now: int,active: bool=true,allowed: bool=true,context: String="a:0") -> Dictionary:
	var before: Dictionary=world.snapshot()
	var result: Dictionary=tracker.sample(Jobs.availability(world.state,"a"),context,int(world.state.tick),now,active,allowed)
	assert(world.snapshot()==before,"Readiness presentation cannot deliver art, pay, or change a resident's plan")
	return result
func _run() -> void:
	_fresh(); assert(Jobs.availability(world.state,"missing").is_empty())
	_command("commission_accept"); assert(_sample(100).is_empty())
	_paint(); var status:=Jobs.availability(world.state,"a")
	assert(status.matching==1 and status.ready.size()==1 and status.reward==180)
	assert(_sample(200).is_empty() and _sample(599).is_empty())
	var notice:=_sample(600)
	assert(notice.message.contains("An original is ready") and notice.message.contains(status.subject) and notice.detail.contains("nothing is delivered automatically"))
	assert(notice.offer==board.active.offer and notice.revision==board.revision)
	assert(_sample(5000).is_empty() and _sample(50000).is_empty(),"The same accepted request cannot keep notifying")
	# Planned sales and construction remove eligibility; removing those blocks is not a new celebration.
	assert(world.apply_command("a",{"type":"painting","member_id":member.id,"target_id":easel.id,"action":"sell","revision":easel.painting.revision}).ok)
	assert(Jobs.availability(world.state,"a").ready.is_empty()); _sample(51000)
	assert(world.apply_command("a",{"type":"cancel","member_id":member.id}).ok); assert(_sample(52000).is_empty())
	assert(world.apply_command("a",{"type":"build_begin","lot_id":home.id}).ok)
	assert(Jobs.availability(world.state,"a").ready.is_empty()); _sample(53000)
	assert(world.apply_command("a",{"type":"art_hang","lot_id":home.id,"source":"easel:"+str(easel.id),"x":8,"y":3,"revision":home.revision}).ok)
	assert(world.apply_command("a",{"type":"build_end","lot_id":home.id}).ok)
	assert(Jobs.availability(world.state,"a").ready.size()==1 and _sample(54000).is_empty())
	home.funds=1000000000; assert(Jobs.availability(world.state,"a").ready.is_empty()); _sample(55000)
	home.funds=12000; assert(_sample(56000).is_empty())
	# Another original can be found in the list without repeating the same request's announcement.
	_paint(); assert(Jobs.availability(world.state,"a").ready.size()==2 and _sample(57000).is_empty())
	# A newly accepted request with existing art can notify, but its open tray consumes that quietly.
	_fresh(); _paint(); assert(Jobs.availability(world.state,"a").is_empty())
	_command("commission_accept"); _sample(100); notice=_sample(500); assert(notice.message.contains("An original"))
	_command("commission_cancel"); _sample(600); _command("commission_accept"); _sample(700,false)
	assert(_sample(1200).is_empty() and Jobs.availability(world.state,"a").ready.size()==1)
	# Multiple qualifying originals are summarized without choosing one.
	_fresh(); _command("commission_accept"); _sample(100); _paint()
	# Face away from the starter tea table so the canvas side remains reachable.
	easel=world._new_object("easel",9,7,2); home.objects.append(easel); _paint()
	_sample(200); notice=_sample(600)
	assert(notice.message.begins_with("2 originals are ready") and notice.detail.begins_with("Open 2 matching originals"))
	# Loading/reconnecting establishes a quiet baseline; unchanged saved art still has a durable ready status.
	tracker=Feedback.new(); assert(_sample(700).is_empty() and _sample(1200).is_empty())
	assert(_sample(1300,true,true,"a:1").is_empty())
	world.state.tick=0; assert(_sample(1400,true,true,"a:1").is_empty())
	assert(_sample(1500,true,true,"b:1").is_empty())
	# A hidden menu consumes pending/new readiness without replaying it on return.
	_fresh(); _command("commission_accept"); _sample(100); _paint(); _sample(200)
	assert(_sample(300,false).is_empty() and _sample(1000).is_empty())
	_fresh(); _command("commission_accept"); _sample(100); _paint()
	assert(_sample(200,false).is_empty() and _sample(1000).is_empty())
	# Preserve the whole preceding notice; expired discoveries do not become an old backlog.
	_fresh(); _command("commission_accept"); _sample(100); _paint(); _sample(200)
	assert(_sample(7000,true,false).is_empty()); assert(not _sample(7200).is_empty())
	_fresh(); _command("commission_accept"); _sample(100); _paint(); _sample(200)
	assert(_sample(20201,true,false).is_empty() and _sample(21000).is_empty())
	# Delivery, cancellation, and session replacement each invalidate a pending discovery.
	for change: String in ["deliver","cancel","generation"]:
		_fresh(); _command("commission_accept"); _sample(100); _paint(); _sample(200)
		if change=="deliver": assert(world.apply_command("a",Jobs.candidates(world.state,"a")[0].intent).ok)
		elif change=="cancel": _command("commission_cancel")
		assert(_sample(600,true,true,"a:1" if change=="generation" else "a:0").is_empty())
		assert(_sample(1200,true,true,"a:1" if change=="generation" else "a:0").is_empty())
	# A wrong subject never claims readiness, nor does a neighboring family's original.
	_fresh(); _command("commission_accept"); _sample(100)
	_paint("meadow" if Jobs.offer("a",board).subject!="meadow" else "flowers")
	assert(Jobs.availability(world.state,"a").matching==0 and _sample(200).is_empty() and _sample(1000).is_empty())
	world.state.lots.lot_2.objects.append(easel.duplicate(true)); home.objects.erase(easel)
	assert(Jobs.availability(world.state,"a").ready.is_empty())
	print("COMMISSION_FEEDBACK_PASS"); quit()
