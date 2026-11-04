extends SceneTree
const World=preload("res://game/world.gd")
const Bonds=preload("res://game/friendships.gd")
const Feedback=preload("res://game/friendship_feedback.gd")
var world: RefCounted
var tracker: RefCounted
var first: Dictionary
var second: Dictionary
var neighbor: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh() -> void:
	world=World.new(); world.initialize(); tracker=Feedback.new()
	world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	first=world.state.families.a.members[0]; second=world.state.families.a.members[1]; neighbor=world.state.families.b.members[0]
	assert(_sample(0).is_empty())
func _sample(now: int,active: bool=true,generation: int=0,allowed: bool=true) -> Dictionary:
	var before: Dictionary=world.snapshot()
	var result: Dictionary=tracker.sample(world.state,"a",generation,now,active,str(first.id),allowed)
	assert(before==world.snapshot(),"Feedback cannot mutate accepted progress or rewards")
	return result
func _gain(a: Dictionary,b: Dictionary,activity: String="game_table") -> void:
	world.state.tick+=1; Bonds.record(world.state,a.id,b.id,world.state.tick,activity)
func _run() -> void:
	for activity: String in ["chat","game_table","stereo","dining_table"]:
		_fresh(); _gain(first,second,activity); assert(_sample(100).is_empty())
		assert(_sample(699).is_empty()); var notice:=_sample(700)
		assert(notice.pairs.size()==1 and notice.sound=="company" and notice.message.contains("caught up") and notice.message.contains("Friendship grew") and notice.resident==first.id and notice.person==second.id)
		if activity=="game_table": assert(notice.message.contains("over a game"))
		if activity=="stereo": assert(notice.message.contains("while dancing"))
		if activity=="dining_table": assert(notice.message.contains("over a meal"))
		assert(_sample(5000).is_empty() and _sample(9000).is_empty(),"Repeated snapshots never replay notices")
		_gain(first,second,activity); assert(_sample(9100).is_empty())
		notice=_sample(9700); assert(notice.message.contains("now friends") and notice.sound=="confirm")
		_gain(first,second,activity); assert(_sample(13000).is_empty() and _sample(15000).is_empty(),"No gain at the daily cap means no celebration")
	# A genuinely new relationship is noticed; a newly loaded one is a baseline.
	_fresh(); _gain(first,neighbor); _sample(100)
	var notice:=_sample(700); assert(notice.message.contains("got to know each other") and notice.sound=="confirm")
	tracker=Feedback.new(); assert(_sample(800).is_empty() and _sample(4000).is_empty())
	# The People target always starts with an owned resident, regardless of pair ordering.
	_fresh(); var visitor_feedback:=Feedback.new()
	assert(visitor_feedback.sample(world.state,"b",0,0,true,first.id).is_empty())
	_gain(first,neighbor); visitor_feedback.sample(world.state,"b",0,100,true,first.id)
	notice=visitor_feedback.sample(world.state,"b",0,700,true,first.id)
	assert(notice.resident==neighbor.id and notice.person==first.id)
	_gain(second,neighbor); tracker.reset(); _sample(800)
	_gain(first,neighbor); _gain(second,neighbor)
	tracker.sample(world.state,"a",0,900,true,second.id)
	notice=tracker.sample(world.state,"a",0,1500,true,second.id)
	assert(notice.resident==second.id and notice.person==neighbor.id and notice.pairs.size()==2,"Equal milestones prefer the selected owned resident")
	# Foreign households and new starting housemate bonds do not create local notices.
	_fresh(); _gain(neighbor,world.state.families.b.members[1]); _sample(100)
	world.ensure_family("c","Rowan"); assert(_sample(700).is_empty())
	# Simultaneous pairs become one notice, with milestones taking priority.
	_gain(first,second); _gain(first,neighbor); _sample(800)
	notice=_sample(1400); assert(notice.pairs.size()==2 and notice.message.contains("got to know each other") and notice.message.contains("1 more friendship grew"))
	assert(notice.detail.contains("caught up over a game") and notice.detail.contains("Violet"))
	_gain(first,second); _sample(1500); assert(_sample(2100).is_empty(),"The quiet interval prevents a chorus")
	notice=_sample(3900); assert(notice.message.contains("now friends") and notice.pairs.size()==1)
	# Changes behind menus are consumed quietly, including a pending announcement.
	_fresh(); _gain(first,second); _sample(100); assert(_sample(300,false).is_empty())
	assert(_sample(900).is_empty()); _gain(first,second); _sample(1000,false); assert(_sample(1800).is_empty())
	# Loading, reconnecting, changing owner, and rewinding cannot replay old progress.
	_fresh(); _gain(first,second); _sample(100)
	assert(_sample(700,true,1).is_empty() and _sample(1400,true,1).is_empty())
	world.state.tick=0; assert(_sample(1500,true,1).is_empty())
	assert(tracker.sample(world.state,"b",1,2200).is_empty())
	assert(_sample(3000,true,1).is_empty())
	# Fresh progress after a reset still works, including the 70 and 100 milestones.
	for score: int in [64,92]:
		_fresh(); world.state.friendships[Bonds.key(first.id,second.id)].score=score
		_sample(0,true,1); _gain(first,second); _sample(100,true,1)
		notice=_sample(700,true,1); assert(notice.sound=="confirm" and notice.message.contains("now "+("good friends" if score==64 else "close friends")))
	# Protect recent command feedback, but do not leave an old success in a backlog.
	_fresh(); _gain(first,second); _sample(100)
	assert(_sample(1000,true,0,false).is_empty()); assert(not _sample(2100).is_empty())
	_fresh(); _gain(first,second); _sample(100)
	assert(_sample(8200,true,0,false).is_empty() and _sample(9000).is_empty())
	print("FRIENDSHIP_FEEDBACK_PASS"); quit()
