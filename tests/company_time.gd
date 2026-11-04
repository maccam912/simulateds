extends SceneTree
const World=preload("res://game/world.gd")
const Leisure=preload("res://game/shared_leisure.gd")
const Bonds=preload("res://game/friendships.gd")
const Status=preload("res://game/activity_status.gd")
const Catalog=preload("res://game/catalog.gd")
var world: RefCounted
var lot: Dictionary
var object: Dictionary
var first: Dictionary
var second: Dictionary
func _initialize() -> void: call_deferred("_run")
func _fresh(kind: String="game_table",visitor: bool=false) -> void:
	world=World.new(); world.initialize()
	for owner: String in ["a","b"]:
		world.ensure_family(owner,owner.to_upper()); world.set_online(owner,true)
		for resident: Dictionary in world.state.families[owner].members:
			resident.autonomy=false
			for need: String in resident.needs: resident.needs[need]=70.0
			resident.needs.fun=95.0; resident.needs.social=30.0
	lot=world.state.lots.lot_1; first=world.state.families.a.members[0]
	second=world.state.families.b.members[0] if visitor else world.state.families.a.members[1]
	object=world._new_object(kind,8,5 if kind=="game_table" else 9,0); lot.objects.append(object)
	if visitor: assert(world.apply_command("b",{"type":"visit","member_id":second.id,"lot_id":lot.id}).ok)
func _play(resident: Dictionary) -> void:
	assert(world.apply_command("a" if str(resident.id).begins_with("a_") else "b",{"type":"interact","member_id":resident.id,"lot_id":lot.id,"target_id":object.id}).ok)
func _call() -> void:
	var option: Dictionary=world.recreation_option("a",first.id,lot.id,object.id,true)
	assert(world.apply_command("a",{"type":"recreation","member_id":first.id,"lot_id":lot.id,"target_id":object.id,"household":true,"revision":lot.revision,"orders":option.orders}).ok)
func _advance(seconds: float,delta: float=0.1) -> void:
	for tick in range(roundi(seconds/delta)): world.step(delta)
func _bond() -> Dictionary: return Bonds.bond(world.state,first.id,second.id)
func _held() -> Dictionary:
	for resident: Dictionary in [first,second]:
		if not resident.task.is_empty() and Leisure.chosen_time(resident.task)>=4.0 and resident.needs.fun>=99.0 and Leisure.company_window(world.state,resident).hold: return resident
	return {}
func _run() -> void:
	# The actual starter positions used to yield only 3.6–3.7 seconds together.
	for kind: String in ["game_table","stereo"]:
		_fresh(kind); _call(); var saw_hold:=false
		for tick in range(200):
			var before: Dictionary=world.snapshot(); var windows:=Leisure.company_windows(world.state)
			assert(world.snapshot()==before,"The shared completion forecast is read-only")
			var resident:=_held()
			if not resident.is_empty():
				saw_hold=true; var status:=Status.sample(resident,lot,world.state)
				assert((status.detail.contains("Time for company") or status.detail=="Finishing up" and status.remaining<=0.1) and status.remaining>0 and status.remaining<=resident.task.remaining)
			world.step(0.1)
			if first.task.is_empty() and second.task.is_empty(): break
		assert(saw_hold and first.task.is_empty() and second.task.is_empty() and _bond().today==1 and _bond().score==32)
		assert(first.activity_log[0].outcome=="done" and second.activity_log[0].outcome=="done")
		# A long incoming walk can hold the current player, but preserves their next order.
		_fresh(kind); first.x=7; first.y=5 if kind=="game_table" else 9; second.x=0; second.y=15
		_call(); assert(world.apply_command("a",{"type":"move","member_id":first.id,"lot_id":lot.id,"x":1,"y":14}).ok)
		var next_id: String=first.queue[0].id
		var held_time:=0.0; var duration: float=Catalog.ITEMS[kind].duration
		for tick in range(250):
			world.step(0.1)
			if first.task.get("target_id")==object.id:
				held_time=maxf(held_time,float(first.task.elapsed)); assert(float(first.task.remaining)+float(first.task.elapsed)<=duration+0.000001)
			if first.task.get("id")==next_id: break
		assert(_bond().today==1 and held_time>4 and held_time<=duration and first.task.get("id")==next_id)
		# A later third reservation gets a shared moment with both earlier arrivals.
		_fresh(kind); first.x=7; first.y=5 if kind=="game_table" else 9
		second.x=0; second.y=15; _call(); _advance(2.0)
		var third: Dictionary=world.state.families.b.members[0]
		assert(world.apply_command("b",{"type":"visit","member_id":third.id,"lot_id":lot.id}).ok)
		third.x=15; third.y=15; _play(third)
		assert(not third.task.is_empty(),"The third person reserves a place, rather than waiting in a queue")
		for tick in range(250):
			world.step(0.1)
			for resident: Dictionary in [first,second,third]:
				if resident.task.get("target_id")==object.id:
					assert(float(resident.task.remaining)+float(resident.task.elapsed)<=duration+0.000001)
			if first.task.is_empty() and second.task.is_empty() and third.task.is_empty(): break
		assert(_bond().today==1)
		for resident: Dictionary in [first,second]:
			var entry:=Bonds.bond(world.state,resident.id,third.id)
			assert(entry.get("today")==1 and entry.get("score")==12,"Every deliberately overlapping pair earns one catch-up")
		assert(first.task.is_empty() and second.task.is_empty() and third.task.is_empty())
		# All members are sampled before ticking, independent of family order and step size.
		for delta: float in [0.1,0.25,1.0]:
			for reverse in [false,true]:
				_fresh(kind,true)
				if reverse: world.state.families={"b":world.state.families.b,"a":world.state.families.a}
				_play(first); _play(second); _advance(30,delta)
				assert(first.task.is_empty() and second.task.is_empty() and _bond().today==1 and _bond().score==12)
		# No incoming chosen reservation means the ordinary solo completion remains.
		for condition: String in ["solo","automatic","away","other_object","queued"]:
			_fresh(kind); first.x=7; first.y=5 if kind=="game_table" else 9; _play(first)
			if condition!="solo":
				if condition=="other_object":
					var other: Dictionary=world._new_object("stereo",11,10,0); lot.objects.append(other)
					assert(world.apply_command("a",{"type":"interact","member_id":second.id,"target_id":other.id}).ok)
				elif condition=="queued":
					assert(world.apply_command("a",{"type":"interact","member_id":second.id,"target_id":world._object_at(lot,Vector2i(10,10)).id}).ok); _play(second)
				else:
					_play(second)
					if condition=="automatic": second.task.automatic=true
					else: world.state.families.a.online=false
			assert(not Leisure.company_window(world.state,first).hold)
			_advance(4.1); assert(first.task.is_empty(),condition+" cannot hold the resident")
		# Cancellation, travel and disconnect release the hold without forcing a friend to stay.
		for interruption: String in ["cancel","travel","disconnect","construction"]:
			_fresh(kind,true); first.x=7; first.y=5 if kind=="game_table" else 9; second.x=0; second.y=15
			_play(first); _play(second); _advance(4.1); assert(not first.task.is_empty() and Leisure.company_window(world.state,first).hold)
			if interruption=="cancel": assert(world.apply_command("b",{"type":"cancel","member_id":second.id}).ok)
			elif interruption=="travel": assert(world.apply_command("b",{"type":"go_home","member_id":second.id}).ok)
			elif interruption=="disconnect": world.set_online("b",false)
			else: assert(world.apply_command("a",{"type":"build_begin","lot_id":lot.id}).ok)
			world.step(0.1); assert(first.task.is_empty() and _bond().is_empty())
		# Chosen automatic play keeps its natural deadline even with a waiting companion.
		_fresh(kind)
		for resident: Dictionary in [first,second]: _play(resident); resident.task.automatic=true
		for tick in range(50):
			world.step(0.1)
			if Leisure.players(world.state,lot.id,object.id).size()==2: break
		for resident: Dictionary in [first,second]: resident.task.elapsed=13.5; resident.task.remaining=0.5
		_call(); var before: Dictionary=world.snapshot()
		var replica:=World.new(); assert(replica.restore(JSON.parse_string(JSON.stringify(before)),true))
		assert(Leisure.company_windows(replica.state)==Leisure.company_windows(world.state))
		_advance(0.7); assert(first.task.is_empty() and second.task.is_empty() and _bond().today==0)
		# The brief moment is for company even when today's friendship reward is exhausted.
		_fresh(kind); world.state.friendships[Bonds.key(first.id,second.id)].today=2; _call(); _advance(12)
		assert(_bond().today==2 and _bond().score==20 and first.task.is_empty() and second.task.is_empty())
	# A table with only one usable place must hand off normally; a queue is no hold.
	_fresh("stereo"); object.x=7; object.y=6; lot.walls.append_array([[6,6],[7,5],[8,6]])
	first.x=7; first.y=7; second.x=8; second.y=7; _call()
	assert(not first.task.is_empty() and second.task.is_empty() and second.queue.size()==1)
	var queued_id: String=second.queue[0].id; assert(not Leisure.company_window(world.state,first).hold)
	_advance(4.6); assert(first.task.get("target_id")!=object.id and second.task.get("id")==queued_id)
	print("COMPANY_TIME_PASS"); quit()
