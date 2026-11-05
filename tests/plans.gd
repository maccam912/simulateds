extends SceneTree
const World = preload("res://game/world.gd")

func _initialize() -> void: call_deferred("_run")

func _ids(queue: Array) -> Array:
	var ids: Array=[]
	for action: Dictionary in queue: ids.append(action.id)
	return ids

func _swap(world: RefCounted, member: Dictionary, first: Variant, second: Variant, owner: String="a") -> Dictionary:
	return world.apply_command(owner,{"type":"reorder_action","member_id":member.id,"first_id":first,"second_id":second})

func _reject(world: RefCounted, member: Dictionary, first: Variant, second: Variant, owner: String="a") -> void:
	var before: Dictionary=world.snapshot()
	assert(not _swap(world,member,first,second,owner).ok)
	assert(world.snapshot()==before,"Rejected plan changes are completely inert")

func _run() -> void:
	var world := World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	world.set_online("a",true); world.set_online("b",true)
	for family: Dictionary in world.state.families.values():
		for resident: Dictionary in family.members: resident.autonomy=false
	var member: Dictionary=world.state.families.a.members[0]
	for index in range(World.MAX_QUEUE+1):
		var reply := world.apply_command("a",{"type":"move","member_id":member.id,"x":index,"y":0})
		assert(reply.ok and str(member.name) in reply.message and "Walk to %d, 0" % index in reply.message)
		assert(("Starting" if index==0 else "Queued") in reply.message,"Accepted feedback distinguishes current from upcoming orders")
	assert(member.queue.size()==World.MAX_QUEUE)
	var active: Dictionary=member.task.duplicate(true)
	var original := _ids(member.queue)
	var first: String=original[0]; var second: String=original[1]
	var before: Dictionary=world.snapshot()
	assert(_swap(world,member,first,second).ok,"A full queue can be rearranged without needing a free slot")
	var expected: Dictionary=before.duplicate(true)
	var queue: Array=expected.families.a.members[0].queue
	var temporary: Dictionary=queue[0]; queue[0]=queue[1]; queue[1]=temporary
	assert(world.snapshot()==expected,"Only the requested pair changes: active task, progress, needs, rewards, IDs and other residents are preserved")
	_reject(world,member,first,second) # A repeated packet cannot undo its first swap.
	_reject(world,member,second,first,"b")
	_reject(world,member,active.id,second)
	_reject(world,member,second,original[3])
	_reject(world,member,second,second)
	for invalid: Variant in [null,0,3.5,"",[],{}]:
		_reject(world,member,invalid,first)
		_reject(world,member,second,invalid)
	assert(_swap(world,member,second,first).ok)
	# Reverse a complete plan through the same adjacent edits offered by the UI.
	for last in range(original.size()-1,0,-1):
		for index in range(last): assert(_swap(world,member,member.queue[index].id,member.queue[index+1].id).ok)
	var reversed := original.duplicate(); reversed.reverse()
	assert(_ids(member.queue)==reversed and member.task==active)
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(world.snapshot())),true))
	assert(_ids(replica.state.families.a.members[0].queue)==reversed,"Runtime snapshots retain the edited order")
	var observed: Array=[active.id]
	for tick in range(700):
		world.step(0.1)
		if not member.task.is_empty() and observed[-1]!=member.task.id: observed.append(member.task.id)
		if member.task.is_empty() and member.queue.is_empty(): break
	assert(observed==[active.id]+reversed and member.task.is_empty() and member.queue.is_empty(),"Residents execute the edited plan in order")
	_reject(world,member,reversed[0],reversed[1])
	# A busy fixture keeps an order queued. Another useful activity can move
	# ahead without stealing the fixture or canceling either resident's work.
	var busy := World.new(); busy.initialize(); busy.ensure_family("a","Alex"); busy.set_online("a",true)
	var residents: Array=busy.state.families.a.members
	for resident: Dictionary in residents: resident.autonomy=false; resident.needs.energy=10.0
	var bed: Dictionary=busy.state.lots.lot_1.objects[0]; var shelf: Dictionary={}
	for object: Dictionary in busy.state.lots.lot_1.objects:
		if object.kind=="bookshelf": shelf=object
	for resident: Dictionary in residents:
		assert(busy.apply_command("a",{"type":"interact","member_id":resident.id,"target_id":bed.id}).ok)
	assert(residents[1].task.is_empty() and residents[1].queue.size()==1)
	assert(busy.apply_command("a",{"type":"interact","member_id":residents[1].id,"target_id":shelf.id}).ok)
	var waiting_id: String=residents[1].queue[0].id; var reading_id: String=residents[1].queue[1].id
	var sleeping_id: String=residents[0].task.id
	assert(_swap(busy,residents[1],waiting_id,reading_id).ok)
	busy.step(0.1)
	assert(residents[1].task.id==reading_id and residents[1].queue[0].id==waiting_id and residents[0].task.id==sleeping_id)
	_reject(busy,residents[1],reading_id,waiting_id) # The front action started while the request was in flight.
	assert(busy._object_user("lot_1",bed).id==residents[0].id,"Reordering cannot steal an existing reservation")
	print("PLANS_PASS")
	quit()
