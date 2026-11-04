extends SceneTree
const World = preload("res://game/world.gd")
var session: Node
var seed: Dictionary

func _initialize() -> void: call_deferred("_run")

func _reset() -> void:
	assert(session.world.restore(seed,true))
	session.role="offline"; session._dedicated=false; session.menu_paused=false
	session.set_clock_rate(1.0)

func _advance(seconds: float,fps: int=60) -> void:
	for frame in range(roundi(seconds*fps)): session._advance_simulation(1.0/fps)

func _run() -> void:
	session=root.get_node("Session"); session.set_physics_process(false); session.saving_enabled=false
	session.world.initialize(); session.world.ensure_family(session.profile_id,"Alex"); session.world.set_online(session.profile_id,true)
	var family: Dictionary=session.state.families[session.profile_id]
	for member: Dictionary in family.members:
		member.autonomy=false
		for need: String in member.needs: member.needs[need]=30.0
		assert(session.world.apply_command(session.profile_id,{"type":"run_routine","member_id":member.id,"routine_id":"routine_1","revision":family.routines.revision}).ok)
	seed=session.world.snapshot()
	var reference := World.new(); assert(reference.restore(seed,true))
	for tick in range(400): reference.step(0.1)
	# Same simulated time produces identical positions, needs, tasks, rewards,
	# random choices, and counters regardless of speed or render/physics cadence.
	for speed in [1,2,4]:
		for fps in [30,60,120]:
			_reset(); assert(session.set_play_speed(speed).ok)
			_advance(40.0/speed,fps)
			assert(session.world.snapshot()==reference.snapshot(),"Fixed-step result differs at %d× / %d fps" % [speed,fps])
			assert(is_zero_approx(session._simulation_clock))
	assert(reference.state.families[session.profile_id].members[0].needs.hygiene>50)
	# Pause discards fractional debt and permits planning with no world progress.
	_reset(); session._advance_simulation(0.05)
	assert(session.state.tick==0 and session._simulation_clock>0)
	assert(session.set_play_speed(0).ok and session._simulation_clock==0)
	var member: Dictionary=session.state.families[session.profile_id].members[0]
	var before: Dictionary=session.world.snapshot(); _advance(4)
	assert(session.world.snapshot()==before and session.effective_speed()==0)
	session.command({"type":"move","member_id":member.id,"x":0,"y":15})
	assert(session.last_action_ok and member.queue[-1].type=="move")
	before=session.world.snapshot(); _advance(2); assert(session.world.snapshot()==before)
	assert(session.set_play_speed(4).ok); _advance(0.25); assert(session.state.tick==10)
	assert(session.toggle_play_pause().ok and session.debug_speed==0)
	assert(session.toggle_play_pause().ok and session.debug_speed==4)
	# A menu pauses locally without replacing the user's selected pace.
	session.menu_paused=true; before=session.world.snapshot(); _advance(2)
	assert(session.world.snapshot()==before and session.debug_speed==4 and session.effective_speed()==0)
	session.menu_paused=false; _advance(0.25); assert(session.state.tick==20)
	assert(session.set_play_speed(0).ok); session.menu_paused=true; session.menu_paused=false
	_advance(2); assert(session.state.tick==20,"Closing a menu must not resume a deliberately paused world")
	# Bad requests cannot change pace or discard fractional work.
	_reset(); session._advance_simulation(0.05)
	for value: Variant in [null,true,"2",{},[],NAN,INF,-1,0.5,3,8]:
		assert(not session.set_play_speed(value).ok and session.debug_speed==1 and is_equal_approx(session._simulation_clock,0.05))
	for invalid: float in [NAN,INF,-1,0]: session._advance_simulation(invalid)
	assert(session.state.tick==0)
	# Stalls are bounded, with no unbounded catch-up on the next frame.
	session.set_play_speed(4); session._advance_simulation(60)
	assert(session.state.tick==10 and session._simulation_clock<0.1)
	session._advance_simulation(0.025); assert(session.state.tick==11)
	_reset(); assert(session.execute_debug("speed 8").ok)
	session._advance_simulation(60); assert(session.state.tick==20 and session._simulation_clock<0.1)
	_reset(); assert(session.execute_debug("speed 0.5").ok)
	_advance(2); assert(session.state.tick==10 and session.speed_label()=="0.5×")
	# Ordinary controls cannot affect shared time, including a host playing alone.
	for role: String in ["host","joining","client"]:
		_reset(); session.role=role; before=session.world.snapshot()
		for value: int in [0,1,2,4]: assert(not session.set_play_speed(value).ok)
		assert(not session.toggle_play_pause().ok and session.debug_speed==1 and session.world.snapshot()==before and session._requests.is_empty())
	_reset(); session._dedicated=true
	assert(not session.set_play_speed(4).ok); session._dedicated=false
	_reset(); session.role="host"; session.menu_paused=true; session._advance_simulation(0.2)
	assert(session.state.tick==2 and session.effective_speed()==1,"Shared menus keep their common clock running")
	assert(session.execute_debug("speed 0").ok); session._advance_simulation(1)
	assert(session.state.tick==2,"An explicit authority debug override remains available")
	# Leaving or a failed join cannot carry a paused/fast private clock forward.
	_reset(); session.set_play_speed(4); session.leave()
	assert(session.debug_speed==1 and session._resume_speed==1 and session._simulation_clock==0)
	assert(session.set_play_speed(0).ok); assert(not session.join("invalid"))
	assert(session.role=="offline" and session.debug_speed==1)
	# World stepping itself preserves fractional walking time and route corners.
	var walk := World.new(); walk.initialize(); walk.ensure_family("walker","Alex")
	member=walk.state.families.walker.members[0]; member.autonomy=false; member.x=0; member.y=0
	assert(walk.apply_command("walker",{"type":"move","member_id":member.id,"x":5,"y":0}).ok)
	walk.step(1.0); assert(member.x==4 and is_equal_approx(member.walk_clock,0.12))
	walk.step(0.1); assert(member.x==5 and is_zero_approx(member.walk_clock))
	print("PLAY_CLOCK_PASS"); quit()
